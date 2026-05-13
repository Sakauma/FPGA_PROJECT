`timescale 1ns / 1ps
// ============================================================================
// 新增维护说明
// 作者          : Egor Izmaylov
// 文件职责      : 将 HLS 真实鱼眼去畸变 BRAM 读出核封装为现有工程 AXIS 输出模块。
// 数据流位置    : user_clk 域读取视频 BRAM，经过异步 FIFO 后进入 SRIO 发送时钟域。
// 维护边界      : 不修改 SRIO、MIG、BD/IP、XDC；HLS 逻辑来源于 hls/fisheye_remap/src。
// 修改约束      : HLS RTL 重新导出后，应同步检查本文件端口映射。
// ============================================================================

`include "../../../hls/fisheye_remap/rtl/fisheye_remap_reader_hls_kInfraredScaleQ16_ROM_AUTO_1R.v"
`include "../../../hls/fisheye_remap/rtl/fisheye_remap_reader_hls_kLaserScaleQ16_ROM_AUTO_1R.v"
`include "../../../hls/fisheye_remap/rtl/fisheye_remap_reader_hls_mac_muladd_11ns_7ns_10ns_17_4_1.v"
// 新代码：Egor Izmaylov
// 局部圆环拉平补偿引入两个 HLS 生成乘法 helper，wrapper 只同步 include，不改变底层 SRIO/BRAM 接口。
`include "../../../hls/fisheye_remap/rtl/fisheye_remap_reader_hls_mul_13ns_13ns_25_2_1.v"
`include "../../../hls/fisheye_remap/rtl/fisheye_remap_reader_hls_mul_15s_9ns_24_2_1.v"
// 新代码：Egor Izmaylov
// HLS 重新综合后预处理乘法位宽收敛为 16x12->28，RTL wrapper 必须同步 include 最新生成模块。
`include "../../../hls/fisheye_remap/rtl/fisheye_remap_reader_hls_mul_16ns_12ns_28_2_1.v"
// 旧代码保留：`include "../../../hls/fisheye_remap/rtl/fisheye_remap_reader_hls_mul_16ns_16ns_32_2_1.v"
`include "../../../hls/fisheye_remap/rtl/fisheye_remap_reader_hls_mul_17ns_11s_28_2_1.v"
`include "../../../hls/fisheye_remap/rtl/fisheye_remap_reader_hls_mul_17ns_13s_30_2_1.v"
`include "../../../hls/fisheye_remap/rtl/fisheye_remap_reader_hls_partset_65ns_65ns_16ns_6ns_65_1_1.v"
// 新代码：Egor Izmaylov
// 最新 HLS RTL 将 LUT 地址 mux 缩为 12bit 输出，保持 wrapper 与生成 RTL 一致。
`include "../../../hls/fisheye_remap/rtl/fisheye_remap_reader_hls_sparsemux_7_2_13_1_1.v"
`include "../../../hls/fisheye_remap/rtl/fisheye_remap_reader_hls_sparsemux_9_3_12_1_1.v"
// 旧代码保留：`include "../../../hls/fisheye_remap/rtl/fisheye_remap_reader_hls_sparsemux_9_3_14_1_1.v"
`include "../../../hls/fisheye_remap/rtl/fisheye_remap_reader_hls.v"

module fisheye_remap_bram_to_axis #(
    parameter       P_D_WIDTH                   = 65,
    parameter       B_RAM_WIDTH                 = 16,
    parameter       B_RAM_DEPTH                 = 32'h80000,
    // 新代码：Egor Izmaylov 默认值与当前工程 BRAM 行缓存深度保持一致；顶层仍可按需覆盖。
    parameter       P_LINE_DEPTH                = 200
)(
    input                                       bram_clk,
    input                                       bram_rstn,
    input       [clogb2(B_RAM_DEPTH-1)-1:0]     bram_line_cur_w,
    input                                       bram_line_cur_w_en,
    output wire [clogb2(P_LINE_DEPTH-1):0]      bram_line_num_addr,
    input       [11:0]                          bram_line_num,
    output wire [clogb2(B_RAM_DEPTH-1)-1:0]     bram_addrb,
    input       [B_RAM_WIDTH-1:0]               bram_doutb,
    input       [31:0]                          video_algo_ctrl,

    input                                       m_axis_aclk,
    input                                       m_axis_aresetn,
    input                                       m_axis_tready,
    output wire [63:0]                          m_axis_tdata,
    output wire                                 m_axis_tvalid,
    output wire                                 m_axis_tlast
);
    function integer clogb2;
        input integer depth;
        for (clogb2 = 0; depth > 0; clogb2 = clogb2 + 1)
            depth = depth >> 1;
    endfunction

    wire                                        fifo_wr_en;
    wire        [P_D_WIDTH-1:0]                 fifo_din;
    wire                                        fifo_almost_full;
    wire                                        fifo_ren;
    wire        [P_D_WIDTH-1:0]                 fifo_rdata;
    wire                                        fifo_empty;
    wire        [P_D_WIDTH-1:0]                 axis_word;
    wire                                        fifo_wr_en_to_fifo;
    wire        [P_D_WIDTH-1:0]                 fifo_din_to_fifo;

`ifdef FISHEYE_SIM_X_SAFE
    // 新代码：Egor Izmaylov
    // 仅 RTL 仿真启用，防止 HLS pipeline 复位释放初期的 X 写使能污染异步 FIFO。
    assign fifo_wr_en_to_fifo = (fifo_wr_en === 1'b1);
    assign fifo_din_to_fifo   = (fifo_wr_en === 1'b1) ? fifo_din : {P_D_WIDTH{1'b0}};
`else
    assign fifo_wr_en_to_fifo = fifo_wr_en;
    assign fifo_din_to_fifo   = fifo_din;
`endif

    // 新代码：Egor Izmaylov 将 AXI-Lite 控制寄存器同步到 BRAM 读出时钟域。
    // 旧代码保留：HLS 核曾直接使用 video_algo_ctrl，综合后控制位到 250MHz 逻辑路径过长。
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *)
    reg         [31:0]                          video_algo_ctrl_bram_r0;
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *)
    reg         [31:0]                          video_algo_ctrl_bram_r1;
    wire        [31:0]                          video_algo_ctrl_bram;

    always @(posedge bram_clk or negedge bram_rstn) begin
        if (!bram_rstn) begin
            video_algo_ctrl_bram_r0 <= 32'd0;
            video_algo_ctrl_bram_r1 <= 32'd0;
        end else begin
            video_algo_ctrl_bram_r0 <= video_algo_ctrl;
            video_algo_ctrl_bram_r1 <= video_algo_ctrl_bram_r0;
        end
    end

    assign video_algo_ctrl_bram = video_algo_ctrl_bram_r1;

    // 新代码：Egor Izmaylov 使用 HLS 核生成去畸变源像素 BRAM 地址和 SRIO payload。
    fisheye_remap_reader_hls u_fisheye_remap_reader_hls (
        .ap_clk                                 ( bram_clk              ),
        .ap_rst                                 ( ~bram_rstn            ),
        .bram_line_cur_w                        ( bram_line_cur_w[18:0] ),
        .bram_line_cur_w_en                     ( bram_line_cur_w_en    ),
        .bram_line_num                          ( bram_line_num         ),
        .bram_doutb                             ( bram_doutb            ),
        .fifo_almost_full                       ( fifo_almost_full      ),
        .algo_ctrl                              ( video_algo_ctrl_bram  ),
        .bram_line_num_addr                     ( bram_line_num_addr    ),
        .bram_addrb                             ( bram_addrb            ),
        .fifo_wr_en                             ( fifo_wr_en            ),
        .fifo_din                               ( fifo_din              )
    );

    async_fifo #(
        .AF                                     ( 1                     ),
        .DATA_BITS                              ( P_D_WIDTH             ),
        .DEPTH_BITS                             ( 4                     ),
        .SHOW_AHEAD                             ( 1                     ),
        .RAM_STYLE                              ( "distributed"         )
    ) u_fisheye_axis_async_fifo (
        .wr_clk                                 ( bram_clk              ),
        .wr_rstn                                ( bram_rstn             ),
        .wr_en                                  ( fifo_wr_en_to_fifo    ),
        .din                                    ( fifo_din_to_fifo      ),
        .wr_data_count                          (                       ),
        .prog_full                              ( fifo_almost_full      ),
        .full                                   (                       ),

        .valid                                  (                       ),
        .rd_clk                                 ( m_axis_aclk           ),
        .rd_rstn                                ( m_axis_aresetn        ),
        .rd_en                                  ( fifo_ren              ),
        .dout                                   ( fifo_rdata            ),
        .rd_data_count                          (                       ),
        .pre_empty                              (                       ),
        .empty                                  ( fifo_empty            )
    );

    fifo_to_axis #(
        .P_D_WIDTH                              ( P_D_WIDTH             )
    ) u_fisheye_fifo_to_axis (
        .fifo_ren                               ( fifo_ren              ),
        .fifo_rdata                             ( fifo_rdata            ),
        .fifo_empty                             ( fifo_empty            ),

        .m_axis_aclk                            ( m_axis_aclk           ),
        .m_axis_aresetn                         ( m_axis_aresetn        ),
        .m_axis_tready                          ( m_axis_tready         ),
        .m_axis_tdata                           ( axis_word             ),
        .m_axis_tvalid                          ( m_axis_tvalid         )
    );

    assign m_axis_tlast = axis_word[64];
    assign m_axis_tdata = axis_word[63:0];

`ifdef ENABLE_FISHEYE_DEBUG_TAPS
    // 新代码：Egor Izmaylov
    // 仅在调试构建中启用的稳定探针名。Vivado 综合网表会优化层级端口名，
    // 因此把关键内部信号复制到 mark_debug/keep 网线，供 Tcl 自动插入 ILA。
    (* mark_debug = "true", keep = "true" *) wire        dbg_fisheye_bram_clk           = bram_clk;
    (* mark_debug = "true", keep = "true" *) wire        dbg_fisheye_axis_clk           = m_axis_aclk;
    (* mark_debug = "true", keep = "true" *) wire [18:0] dbg_fisheye_bram_line_cur_w    = bram_line_cur_w[18:0];
    (* mark_debug = "true", keep = "true" *) wire        dbg_fisheye_bram_line_cur_w_en = bram_line_cur_w_en;
    (* mark_debug = "true", keep = "true" *) wire [8:0]  dbg_fisheye_bram_line_num_addr = bram_line_num_addr[8:0];
    (* mark_debug = "true", keep = "true" *) wire [11:0] dbg_fisheye_bram_line_num      = bram_line_num;
    (* mark_debug = "true", keep = "true" *) wire [18:0] dbg_fisheye_bram_addrb         = bram_addrb[18:0];
    (* mark_debug = "true", keep = "true" *) wire [15:0] dbg_fisheye_bram_doutb         = bram_doutb;
    (* mark_debug = "true", keep = "true" *) wire [31:0] dbg_fisheye_video_algo_ctrl    = video_algo_ctrl_bram;
    (* mark_debug = "true", keep = "true" *) wire        dbg_fisheye_fifo_wr_en         = fifo_wr_en;
    (* mark_debug = "true", keep = "true" *) wire        dbg_fisheye_fifo_almost_full   = fifo_almost_full;
    (* mark_debug = "true", keep = "true" *) wire [64:0] dbg_fisheye_fifo_din           = fifo_din;
    (* mark_debug = "true", keep = "true" *) wire        dbg_fisheye_fifo_empty         = fifo_empty;
    (* mark_debug = "true", keep = "true" *) wire        dbg_fisheye_fifo_ren           = fifo_ren;
    (* mark_debug = "true", keep = "true" *) wire [64:0] dbg_fisheye_fifo_rdata         = fifo_rdata;
    (* mark_debug = "true", keep = "true" *) wire [63:0] dbg_fisheye_m_axis_tdata       = m_axis_tdata;
    (* mark_debug = "true", keep = "true" *) wire        dbg_fisheye_m_axis_tvalid      = m_axis_tvalid;
    (* mark_debug = "true", keep = "true" *) wire        dbg_fisheye_m_axis_tready      = m_axis_tready;
    (* mark_debug = "true", keep = "true" *) wire        dbg_fisheye_m_axis_tlast       = m_axis_tlast;
`endif

endmodule
