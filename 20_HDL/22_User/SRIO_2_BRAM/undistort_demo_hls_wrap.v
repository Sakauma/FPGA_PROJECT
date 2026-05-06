`timescale 1ns / 1ps
// ============================================================================
// 新增维护说明
// 作者          : Egor Izmaylov
// 文件职责      : 当前文件为手工维护源码，具体职责见模块名、端口和上层实例化。
// 维护边界      : 只追加说明性注释；Vivado/IP 生成物和第三方支撑代码不在此处手改。
// 修改约束      : 功能改动需同步更新仿真、综合结果和相关文档。
// ============================================================================
////////////////////////////////////////////////////////////////////////////////////////////////////
// Company         : OpenAI
// Engineer        : Codex
// Author          : Egor Izmaylov
// Create Date     : 2026/04/15
// Module Name     : undistort_demo_hls_wrap
// Description     :
//     HLS-generated undistortion/demo processing wrapper.
//     The wrapped IP keeps the original 64-bit SRIO payload framing and only
//     inserts a visible post-process stage in the stream path.
//     新代码：Egor Izmaylov 将 Vitis HLS RTL 封装成现有工程可直接实例化的 AXIS 模块。
//     维护边界：修改算法时优先改 hls/undistort_demo/src，再重新导出 RTL。
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
