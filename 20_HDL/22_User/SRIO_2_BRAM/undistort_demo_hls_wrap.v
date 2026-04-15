`timescale 1ns / 1ps
// ============================================================================
// 维护注释
//   文件职责      : HLS 视觉预处理核的 RTL 包装层，用于适配现有 64 位 AXIS 数据流。
//   源码属性      : 手工维护源码，不要把修改同步到生成 IP 或网表。
//   更新要求      : 当时钟、复位、接口或数据顺序假设变化时，同步更新注释。
//   维护边界      : 注释用于说明当前实现意图，不替代接口协议文档。
// ============================================================================
//                    semantics and control-bit usage when this file changes.
// ============================================================================
////////////////////////////////////////////////////////////////////////////////////////////////////
// Company         : OpenAI
// Engineer        : Codex
// Create Date     : 2026/04/15
// Module Name     : undistort_demo_hls_wrap
// Description     :
//     HLS-generated undistortion/demo processing wrapper.
//     The wrapped IP keeps the original 64-bit SRIO payload framing and only
//     inserts a visible post-process stage in the stream path.
////////////////////////////////////////////////////////////////////////////////////////////////////

`include "../../../hls/undistort_demo/rtl/undistort_demo_hls_regslice_both.v"
`include "../../../hls/undistort_demo/rtl/undistort_demo_hls_sparsemux_7_2_16_1_1.v"
`include "../../../hls/undistort_demo/rtl/undistort_demo_hls_hls_deadlock_idx0_monitor.v"
`include "../../../hls/undistort_demo/rtl/undistort_demo_hls.v"

module undistort_demo_hls_wrap (
    input               clk,
    input               rstn,
    input       [31:0]  algo_ctrl,

    input       [63:0]  s_axis_tdata,
    input               s_axis_tvalid,
    output              s_axis_tready,
    input               s_axis_tlast,

    output      [63:0]  m_axis_tdata,
    output              m_axis_tvalid,
    input               m_axis_tready,
    output              m_axis_tlast
);

    wire [7:0] m_axis_tkeep_unused;
    wire [7:0] m_axis_tstrb_unused;

    undistort_demo_hls u_undistort_demo_hls (
        .ap_clk         ( clk               ),
        .ap_rst_n       ( rstn              ),

        .s_axis_TDATA   ( s_axis_tdata      ),
        .s_axis_TVALID  ( s_axis_tvalid     ),
        .s_axis_TREADY  ( s_axis_tready     ),
        .s_axis_TKEEP   ( 8'hFF             ),
        .s_axis_TSTRB   ( 8'hFF             ),
        .s_axis_TLAST   ( s_axis_tlast      ),

        .m_axis_TDATA   ( m_axis_tdata      ),
        .m_axis_TVALID  ( m_axis_tvalid     ),
        .m_axis_TREADY  ( m_axis_tready     ),
        .m_axis_TKEEP   ( m_axis_tkeep_unused),
        .m_axis_TSTRB   ( m_axis_tstrb_unused),
        .m_axis_TLAST   ( m_axis_tlast      ),

        .algo_ctrl      ( algo_ctrl         )
    );

endmodule

