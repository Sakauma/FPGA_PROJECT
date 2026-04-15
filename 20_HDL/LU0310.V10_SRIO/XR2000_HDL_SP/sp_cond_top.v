// ============================================================================
// 维护注释
//   文件职责      : 继承自 XR2000 的流处理与边带控制逻辑。
//   源码属性      : 手工维护源码，不要把修改同步到生成 IP 或网表。
//   更新要求      : 当时钟、复位、接口或数据顺序假设变化时，同步更新注释。
//   维护边界      : 注释用于说明当前实现意图，不替代接口协议文档。
// ============================================================================
 `timescale 1ns/1ns
//////////////////////////////////////////////////////////////////////////////////
// Company:			HXZY
// Engineer:		ZYL
// Create Date:		2018/5/11 19:40:24
// Design Name:		XR2000
// Module Name:		spb_top-SrioPCIeBridge_TOP
// Project Name:
// Target Devices:	K7-V7
// Tool Versions: 	Vivado 2016.1 HDL-EDIT UltraEdit TAB=4 Consolas
// Description:
//		文件为基于Xilinx SRIO IP Core的Rapid IO冗余模块顶层文件
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
//////////////////////////////////////////////////////////////////////////////////
module sp_cond_top #(
	/*--------------------------------------------------------------------------------------
	--P_SIMULATION_R
	---------------------------------------------------------------------------------------*/
	parameter									P_SIMULATION_R			= "FALSE"			,
	parameter									P_BIG_CACHE_R			= "FALSE"
	)(
//==================================================================================================
//--输入输出端口定义---------------------------
	/*--------------------------------------------------------------------------------------
	--Common Interface
	--|clk-->可以连接log_clk，也可以连接外部时钟，进行快速查询处理
	--|rst-->复位信号，高电平同步复位信号
	--------------------------------------------------------------------------------------*/
	input										clk											,
	input										rst											,
	input										srio_rst									,
	
	input										log_clk										,
	output			[31:0]						c_sp_up_cnt									,
	output			[31:0]						c_sp_dn_cnt									,
	output			[31:0]						c_sp_rx_cnt									,
	output			[31:0]						c_sp_tx_cnt									,

//==================================================================================================
//--DMA Channel Signals
	/*--------------------------------------------------------------------------------------
	--DMA Channel AXI Stream Inteface
	--------------------------------------------------------------------------------------*/
	output			[64-1	:0]					dma_s_axis_tdata							,
	output			[4-1	:0]					dma_s_axis_tid								,
	input			[1-1	:0]					dma_s_axis_tready							,
	output			[1-1	:0]					dma_s_axis_tvalid							,
	output			[8-1	:0]					dma_s_axis_tstrb							,
	output			[8-1	:0]					dma_s_axis_tkeep							,
	output			[1-1	:0]					dma_s_axis_tlast							,
	output			[64-1	:0]					dma_s_axis_tuser							,
	output			[4-1	:0]					dma_s_axis_tdest							,

	input			[64-1	:0]					dma_m_axis_tdata							,
	input			[4-1	:0]					dma_m_axis_tid								,
	output			[1-1	:0]					dma_m_axis_tready							,
	input			[1-1	:0]					dma_m_axis_tvalid							,
	input			[8-1	:0]					dma_m_axis_tstrb							,
	input			[8-1	:0]					dma_m_axis_tkeep							,
	input			[1-1	:0]					dma_m_axis_tlast							,
	input			[64-1	:0]					dma_m_axis_tuser							,
	input			[4-1	:0]					dma_m_axis_tdest							,

//==================================================================================================
//--SRIO Reduncy Signals
	/*--------------------------------------------------------------------------------------
	--USER SRIO Redundancy Interface
	--------------------------------------------------------------------------------------*/
	output										sr_iotx_tvalid								,
	input										sr_iotx_tready								,
	output										sr_iotx_tlast								,
	output			[63:0]						sr_iotx_tdata								,
	output			[7:0]						sr_iotx_tkeep								,
	output			[31:0]						sr_iotx_tuser								,

	input										sr_iorx_tvalid								,
	output										sr_iorx_tready								,
	input										sr_iorx_tlast								,
	input			[63:0]						sr_iorx_tdata								,
	input			[7:0]						sr_iorx_tkeep								,
	input			[31:0]						sr_iorx_tuser
	);

//==================================================================================================
//--sp_up Instantation
	sp_cond_up	#(
		.P_SIMULATION_R							( P_SIMULATION_R							),
		.P_BIG_CACHE_R							( P_BIG_CACHE_R								)
	)
	i_sp_cond_up (
		.clk									( clk										),
		.log_clk								( log_clk									),
		.rst									( rst										),
		.c_sp_up_cnt							( c_sp_up_cnt								),
		.c_sp_rx_cnt							( c_sp_rx_cnt								),
		.srio_rst								( srio_rst									),
		
		.dma_s_axis_tdata						( dma_s_axis_tdata							),
		.dma_s_axis_tid							( dma_s_axis_tid							),
		.dma_s_axis_tready						( dma_s_axis_tready							),
		.dma_s_axis_tvalid						( dma_s_axis_tvalid							),
		.dma_s_axis_tstrb						( dma_s_axis_tstrb							),
		.dma_s_axis_tkeep						( dma_s_axis_tkeep							),
		.dma_s_axis_tlast						( dma_s_axis_tlast							),
		.dma_s_axis_tuser						( dma_s_axis_tuser							),
		.dma_s_axis_tdest						( dma_s_axis_tdest							),
		
		.sr_iorx_tvalid							( sr_iorx_tvalid							),
		.sr_iorx_tready							( sr_iorx_tready							),
		.sr_iorx_tlast							( sr_iorx_tlast								),
		.sr_iorx_tdata							( sr_iorx_tdata								),
		.sr_iorx_tkeep							( sr_iorx_tkeep								),
		.sr_iorx_tuser							( sr_iorx_tuser								)
	);


//==================================================================================================
//--spb_top Instantation
	sp_cond_dn	#(
		.P_SIMULATION_R							( P_SIMULATION_R							),
		.P_BIG_CACHE_R							( P_BIG_CACHE_R								)
	)
	i_sp_cond_dn (
		.clk									( clk										),
		.log_clk								( log_clk									),
		.rst									( rst										),
		.srio_rst								( srio_rst									),
		
		.c_sp_dn_cnt							( c_sp_dn_cnt								),
		.c_sp_tx_cnt							( c_sp_tx_cnt								),
		
		.dma_m_axis_tdata						( dma_m_axis_tdata							),
		.dma_m_axis_tid							( dma_m_axis_tid							),
		.dma_m_axis_tready						( dma_m_axis_tready							),
		.dma_m_axis_tvalid						( dma_m_axis_tvalid							),
		.dma_m_axis_tstrb						( dma_m_axis_tstrb							),
		.dma_m_axis_tkeep						( dma_m_axis_tkeep							),
		.dma_m_axis_tlast						( dma_m_axis_tlast							),
		.dma_m_axis_tuser						( dma_m_axis_tuser							),
		.dma_m_axis_tdest						( dma_m_axis_tdest							),
		
		.sr_iotx_tvalid							( sr_iotx_tvalid							),
		.sr_iotx_tready							( sr_iotx_tready							),
		.sr_iotx_tlast							( sr_iotx_tlast								),
		.sr_iotx_tdata							( sr_iotx_tdata								),
		.sr_iotx_tkeep							( sr_iotx_tkeep								),
		.sr_iotx_tuser							( sr_iotx_tuser								)
	);

endmodule
