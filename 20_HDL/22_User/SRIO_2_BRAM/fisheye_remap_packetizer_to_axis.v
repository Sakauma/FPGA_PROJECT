`timescale 1ns / 1ps
// ============================================================================
// 新代码：Egor Izmaylov
// 文件职责：稳定版鱼眼去畸变 BRAM 读出与 SRIO AXIS 发包包装。
// 数据流位置：user_clk 域读取视频 BRAM，经异步 FIFO 输出到 SRIO 时钟域。
// 维护边界：HLS 只计算去畸变源地址；SRIO packet/header/payload/tlast 节奏固定由本 RTL 生成。
// ============================================================================

`include "../../../hls/fisheye_remap/rtl/fisheye_remap_addr_hls_kInfraredScaleQ16_ROM_AUTO_1R.v"
`include "../../../hls/fisheye_remap/rtl/fisheye_remap_addr_hls_kLaserScaleQ16_ROM_AUTO_1R.v"
`include "../../../hls/fisheye_remap/rtl/fisheye_remap_addr_hls_mul_13ns_13ns_25_2_1.v"
`include "../../../hls/fisheye_remap/rtl/fisheye_remap_addr_hls_mul_15s_9ns_24_2_1.v"
`include "../../../hls/fisheye_remap/rtl/fisheye_remap_addr_hls_mul_17ns_12s_29_2_1.v"
`include "../../../hls/fisheye_remap/rtl/fisheye_remap_addr_hls_mul_17ns_13s_30_2_1.v"
`include "../../../hls/fisheye_remap/rtl/fisheye_remap_addr_hls_sparsemux_7_2_8_1_1.v"
`include "../../../hls/fisheye_remap/rtl/fisheye_remap_addr_hls_sparsemux_7_2_11_1_1.v"
`include "../../../hls/fisheye_remap/rtl/fisheye_remap_addr_hls_sparsemux_7_2_13_1_1.v"
`include "../../../hls/fisheye_remap/rtl/fisheye_remap_addr_hls.v"

module fisheye_remap_packetizer_to_axis #(
    parameter       P_D_WIDTH                   = 65,
    parameter       B_RAM_WIDTH                 = 16,
    parameter       B_RAM_DEPTH                 = 32'h80000,
    parameter       P_LINE_DEPTH                = 256
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

    localparam [2:0] S_IDLE         = 3'd0;
    localparam [2:0] S_WAIT_LINE    = 3'd1;
    localparam [2:0] S_WRITE_HEADER = 3'd2;
    localparam [2:0] S_PACKET       = 3'd3;
    localparam [2:0] S_CAPTURE_LINE = 3'd4;

    localparam [7:0]  HALF_LINE_DEPTH = P_LINE_DEPTH / 2;
    localparam [11:0] IMAGE_WIDTH     = 12'd2048;
    localparam [6:0]  PACKET_PIXELS   = 7'd127;
    localparam [3:0]  PACKETS_PER_LINE_LAST = 4'd15;

    reg         [31:0]                          video_algo_ctrl_bram_r0;
    reg         [31:0]                          video_algo_ctrl_bram_r1;
    wire        [31:0]                          video_algo_ctrl_bram = video_algo_ctrl_bram_r1;

    always @(posedge bram_clk or negedge bram_rstn) begin
        if (!bram_rstn) begin
            video_algo_ctrl_bram_r0 <= 32'd0;
            video_algo_ctrl_bram_r1 <= 32'd0;
        end else begin
            video_algo_ctrl_bram_r0 <= video_algo_ctrl;
            video_algo_ctrl_bram_r1 <= video_algo_ctrl_bram_r0;
        end
    end

    function [7:0] calc_delayed_slot;
        input [18:0] cur_w;
        reg   [7:0]  cur_slot;
        begin
            cur_slot = cur_w[7:0];
            if (cur_slot >= HALF_LINE_DEPTH) begin
                calc_delayed_slot = cur_slot - HALF_LINE_DEPTH;
            end else begin
                calc_delayed_slot = cur_slot + HALF_LINE_DEPTH;
            end
        end
    endfunction

    // 新代码：Egor Izmaylov
    // 使用 +: 固定从 bit0 取 8 位，避免端到端参数化仿真时 XSim 对区间方向产生误判。
    wire        [7:0]                           cur_slot = bram_line_cur_w[0 +: 8];
    wire                                        line_ready = (cur_slot >= HALF_LINE_DEPTH);

    reg                                         video_started;
    reg         [2:0]                           state;
    reg         [7:0]                           out_slot;
    reg         [7:0]                           out_slot_counter;
    reg         [8:0]                           pending_line_count;
    reg         [11:0]                          out_line;
    reg         [11:0]                          out_line_counter;
    reg         [3:0]                           packet_idx;
    reg         [11:0]                          issue_pixel_idx;
    reg         [8:0]                           bram_line_num_addr_r;
    reg         [18:0]                          bram_addrb_r;
    reg                                         fifo_wr_en;
    reg         [P_D_WIDTH-1:0]                 fifo_din;
    reg                                         fifo_word_toggle;
    reg                                         fifo_word_toggle_d;
    wire                                        fifo_wr_en_qualified = fifo_wr_en;
    wire                                        fifo_wr_en_to_fifo = fifo_wr_en_qualified;
    wire        [P_D_WIDTH-1:0]                 fifo_din_to_fifo = fifo_din;

    reg                                         addr_in_valid;
    reg         [10:0]                          addr_out_x;
    reg         [6:0]                           addr_packet_pixel_idx;
    wire                                        addr_out_valid;
    wire        [8:0]                           addr_src_slot;
    wire        [10:0]                          addr_src_x;
    wire        [6:0]                           addr_packet_pixel_idx_out;

    fisheye_remap_addr_hls u_fisheye_remap_addr_hls (
        .ap_clk                                 ( bram_clk                  ),
        .ap_rst                                 ( ~bram_rstn                ),
        .in_valid                               ( addr_in_valid             ),
        .out_x                                  ( addr_out_x                ),
        .out_line                               ( out_line                  ),
        .out_slot                               ( {1'b0, out_slot}          ),
        .packet_pixel_idx                       ( addr_packet_pixel_idx     ),
        .algo_ctrl                              ( video_algo_ctrl_bram      ),
        .out_valid                              ( addr_out_valid            ),
        .src_slot                               ( addr_src_slot             ),
        .src_x                                  ( addr_src_x                ),
        .packet_pixel_idx_out                   ( addr_packet_pixel_idx_out )
    );

    reg                                         bram_data_valid;
    reg         [6:0]                           bram_packet_pixel_idx;
    reg                                         bram_data_valid_d;
    reg         [6:0]                           bram_packet_pixel_idx_d;
    reg         [63:0]                          payload_word;
    reg                                         pending_payload_valid;
    reg         [P_D_WIDTH-1:0]                 pending_payload_word;

    wire                                        fifo_almost_full;
    wire                                        fifo_ren;
    wire        [P_D_WIDTH-1:0]                 fifo_rdata;
    wire                                        fifo_empty;
    wire        [P_D_WIDTH-1:0]                 axis_word;

    assign bram_line_num_addr = bram_line_num_addr_r;
    assign bram_addrb = bram_addrb_r;

    always @(posedge bram_clk or negedge bram_rstn) begin : p_packetizer
        reg         block_issue;
        reg [8:0]   pending_line_count_next;
        reg [63:0]  next_payload_word;
        reg [64:0]  completed_payload_word;
        if (!bram_rstn) begin
            video_started          <= 1'b0;
            state                  <= S_IDLE;
            out_slot               <= 8'd0;
            out_slot_counter       <= 8'd0;
            pending_line_count     <= 9'd0;
            out_line               <= 12'd0;
            out_line_counter       <= 12'd0;
            packet_idx             <= 4'd0;
            issue_pixel_idx        <= 12'd0;
            bram_line_num_addr_r   <= 9'd0;
            bram_addrb_r           <= 19'd0;
            fifo_wr_en             <= 1'b0;
            fifo_din               <= {P_D_WIDTH{1'b0}};
            fifo_word_toggle       <= 1'b0;
            fifo_word_toggle_d     <= 1'b0;
            addr_in_valid          <= 1'b0;
            addr_out_x             <= 11'd0;
            addr_packet_pixel_idx  <= 7'd0;
            bram_data_valid        <= 1'b0;
            bram_packet_pixel_idx  <= 7'd0;
            bram_data_valid_d      <= 1'b0;
            bram_packet_pixel_idx_d <= 7'd0;
            payload_word           <= 64'd0;
            pending_payload_valid  <= 1'b0;
            pending_payload_word   <= {P_D_WIDTH{1'b0}};
        end else begin
            fifo_wr_en     <= 1'b0;
            fifo_din       <= {P_D_WIDTH{1'b0}};
            addr_in_valid  <= 1'b0;
            block_issue    = 1'b0;
            pending_line_count_next = pending_line_count;

            if (bram_line_cur_w_en && line_ready) begin
                video_started <= 1'b1;
            end
            if (bram_line_cur_w_en && (video_started || line_ready) && (pending_line_count_next != 9'h1ff)) begin
                pending_line_count_next = pending_line_count_next + 9'd1;
            end

            fifo_word_toggle_d <= fifo_word_toggle;

            if (addr_out_valid) begin
                bram_addrb_r <= {addr_src_slot[7:0], addr_src_x};
            end

            case (state)
                S_IDLE: begin
                    bram_data_valid       <= 1'b0;
                    bram_data_valid_d     <= 1'b0;
                    pending_payload_valid <= 1'b0;
                    if (pending_line_count_next != 9'd0) begin
                        pending_line_count_next = pending_line_count_next - 9'd1;
                        out_slot             <= out_slot_counter;
                        bram_line_num_addr_r <= {1'b0, out_slot_counter};
                        if (out_slot_counter == (P_LINE_DEPTH - 1)) begin
                            out_slot_counter <= 8'd0;
                        end else begin
                            out_slot_counter <= out_slot_counter + 8'd1;
                        end
                        state                <= S_WAIT_LINE;
                    end
                end

                S_WAIT_LINE: begin
                    // 新代码：Egor Izmaylov
                    // bram_line_num 来自行号 RAM，地址切换后额外等待一拍，避免 header 行号沿用上一行。
                    state                 <= S_CAPTURE_LINE;
                end

                S_CAPTURE_LINE: begin
                    // 新代码：Egor Izmaylov
                    // 输出 SRIO header 必须保持固定逻辑行序；去畸变只改变源像素地址，不改变下游包地址。
                    out_line              <= out_line_counter;
                    packet_idx            <= 4'd0;
                    issue_pixel_idx       <= 12'd0;
                    bram_data_valid       <= 1'b0;
                    bram_data_valid_d     <= 1'b0;
                    pending_payload_valid <= 1'b0;
                    payload_word          <= 64'd0;
                    state                 <= S_WRITE_HEADER;
                end

                S_WRITE_HEADER: begin
                    bram_data_valid <= 1'b0;
                    bram_data_valid_d <= 1'b0;
                    if (!fifo_almost_full) begin
                        fifo_wr_en       <= 1'b1;
                        fifo_din         <= {1'b0, 32'h0060_2000, 8'h00, out_line, packet_idx, 8'h00};
                        fifo_word_toggle <= ~fifo_word_toggle;
                        issue_pixel_idx  <= {packet_idx, 7'd0};
                        payload_word     <= 64'd0;
                        state            <= S_PACKET;
                    end
                end

                S_PACKET: begin
                    if (pending_payload_valid) begin
                        block_issue = 1'b1;
                        if (!fifo_almost_full) begin
                            fifo_wr_en             <= 1'b1;
                            fifo_din               <= pending_payload_word;
                            fifo_word_toggle       <= ~fifo_word_toggle;
                            pending_payload_valid  <= 1'b0;
                            if (pending_payload_word[64]) begin
                                if (packet_idx == PACKETS_PER_LINE_LAST) begin
                                    out_line_counter <= out_line_counter + 12'd1;
                                    state <= S_IDLE;
                                end else begin
                                    packet_idx <= packet_idx + 4'd1;
                                    state      <= S_WRITE_HEADER;
                                end
                            end
                        end
                    end else if (bram_data_valid) begin
                        next_payload_word = payload_word;
                        case (bram_packet_pixel_idx[1:0])
                            2'd0: next_payload_word[15:0]   = bram_doutb;
                            2'd1: next_payload_word[31:16]  = bram_doutb;
                            2'd2: next_payload_word[47:32]  = bram_doutb;
                            default: next_payload_word[63:48] = bram_doutb;
                        endcase

                        if (bram_packet_pixel_idx[1:0] == 2'd3) begin
                            completed_payload_word = {bram_packet_pixel_idx == PACKET_PIXELS, next_payload_word};
                            block_issue = 1'b1;
                            payload_word <= 64'd0;
                            if (!fifo_almost_full) begin
                                fifo_wr_en       <= 1'b1;
                                fifo_din         <= completed_payload_word;
                                fifo_word_toggle <= ~fifo_word_toggle;
                                if (completed_payload_word[64]) begin
                                    if (packet_idx == PACKETS_PER_LINE_LAST) begin
                                        out_line_counter <= out_line_counter + 12'd1;
                                        state <= S_IDLE;
                                    end else begin
                                        packet_idx <= packet_idx + 4'd1;
                                        state      <= S_WRITE_HEADER;
                                    end
                                end
                            end else begin
                                pending_payload_valid <= 1'b1;
                                pending_payload_word  <= completed_payload_word;
                            end
                        end else begin
                            payload_word <= next_payload_word;
                        end
                    end

                    // 新代码：Egor Izmaylov
                    // HLS 地址核输出有效后一拍，BRAM 同步读数据才稳定；延迟 packet 像素序号保持打包对齐。
                    bram_data_valid_d       <= addr_out_valid;
                    bram_packet_pixel_idx_d <= addr_packet_pixel_idx_out;
                    bram_data_valid         <= bram_data_valid_d;
                    bram_packet_pixel_idx   <= bram_packet_pixel_idx_d;

                    // 新代码：Egor Izmaylov
                    // FIFO 接近满时停止继续发起 HLS 地址请求，避免在途 BRAM 数据超过 skid 能力导致包边界错位。
                    if (!block_issue && !fifo_almost_full && (state == S_PACKET) &&
                        (issue_pixel_idx < ({1'b0, packet_idx, 7'd0} + 12'd128))) begin
                        addr_in_valid         <= 1'b1;
                        addr_out_x            <= issue_pixel_idx[10:0];
                        addr_packet_pixel_idx <= issue_pixel_idx[6:0];
                        issue_pixel_idx       <= issue_pixel_idx + 12'd1;
                    end
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
            pending_line_count <= pending_line_count_next;
        end
    end

    async_fifo #(
        .AF                                     ( 1024                  ),
        .DATA_BITS                              ( P_D_WIDTH             ),
        .DEPTH_BITS                             ( 13                    ),
        .SHOW_AHEAD                             ( 1                     ),
        .RAM_STYLE                              ( "block"               )
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
    (* mark_debug = "true", keep = "true" *) wire        dbg_fisheye_bram_clk           = bram_clk;
    (* mark_debug = "true", keep = "true" *) wire        dbg_fisheye_axis_clk           = m_axis_aclk;
    (* mark_debug = "true", keep = "true" *) wire [18:0] dbg_fisheye_bram_line_cur_w    = bram_line_cur_w[18:0];
    (* mark_debug = "true", keep = "true" *) wire        dbg_fisheye_bram_line_cur_w_en = bram_line_cur_w_en;
    (* mark_debug = "true", keep = "true" *) wire [18:0] dbg_fisheye_bram_line_cur_w_hls = {11'd0, out_slot};
    (* mark_debug = "true", keep = "true" *) wire        dbg_fisheye_bram_line_cur_w_en_hls = (state != S_IDLE);
    (* mark_debug = "true", keep = "true" *) wire [8:0]  dbg_fisheye_bram_line_num_addr = bram_line_num_addr[8:0];
    (* mark_debug = "true", keep = "true" *) wire [11:0] dbg_fisheye_bram_line_num      = bram_line_num;
    (* mark_debug = "true", keep = "true" *) wire [18:0] dbg_fisheye_bram_addrb         = bram_addrb[18:0];
    (* mark_debug = "true", keep = "true" *) wire [15:0] dbg_fisheye_bram_doutb         = bram_doutb;
    (* mark_debug = "true", keep = "true" *) wire [31:0] dbg_fisheye_video_algo_ctrl    = video_algo_ctrl_bram;
    (* mark_debug = "true", keep = "true" *) wire        dbg_fisheye_fifo_wr_en         = fifo_wr_en;
    (* mark_debug = "true", keep = "true" *) wire        dbg_fisheye_fifo_wr_en_qualified = fifo_wr_en_qualified;
    (* mark_debug = "true", keep = "true" *) wire        dbg_fisheye_fifo_wr_en_to_fifo = fifo_wr_en_to_fifo;
    (* mark_debug = "true", keep = "true" *) wire        dbg_fisheye_fifo_word_toggle   = fifo_word_toggle;
    (* mark_debug = "true", keep = "true" *) wire        dbg_fisheye_fifo_word_toggle_d = fifo_word_toggle_d;
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
