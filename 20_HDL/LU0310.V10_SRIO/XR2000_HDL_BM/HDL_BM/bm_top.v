 `timescale 1ns/1ns
//////////////////////////////////////////////////////////////////////////////////
// Company:			HXZY
// Engineer:		ZYL
// Create Date:		2018/5/11 19:40:24
// Design Name:		XR2000
// Module Name:		bm_top-bus Monitor
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
module bm_top #(
	/*--------------------------------------------------------------------------------------
	--P_SIMULATION_R
	---------------------------------------------------------------------------------------*/
	parameter		P_SIMULATION_R				= "FALSE"									,
	parameter		P_Srio_CH_NUM_R				= 2
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

//==================================================================================================
//--寄存器配置
	input			[63:0]						c_bm_timestamp								,
	input										c_bm_timestamp_rf							,
	
	input			[P_Srio_CH_NUM_R* 1-1:0]	c_bm_en										,
	
	output			[31:0]						c_bm_up_cnt									,
	
	output			[P_Srio_CH_NUM_R*32-1:0]	c_bm_ch_recv_cnt							,
	output			[P_Srio_CH_NUM_R*32-1:0]	c_bm_ch_up_cnt								,
	output			[P_Srio_CH_NUM_R*32-1:0]	c_bm_ch_lost_cnt							,

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

//==================================================================================================
//--SRIO Reduncy Signals
	/*--------------------------------------------------------------------------------------
	--SRIO IP Core A Interface
	--------------------------------------------------------------------------------------*/
	input			[P_Srio_CH_NUM_R* 1-1:0]	log_clk										,
	input			[P_Srio_CH_NUM_R* 1-1:0]	rx_tvalid									,
	input			[P_Srio_CH_NUM_R* 1-1:0]	rx_tready									,
	input			[P_Srio_CH_NUM_R* 1-1:0]	rx_tlast									,
	input			[P_Srio_CH_NUM_R*64-1:0]	rx_tdata									,
	input			[P_Srio_CH_NUM_R* 8-1:0]	rx_tkeep									,
	input			[P_Srio_CH_NUM_R*32-1:0]	rx_tuser
	);
//==================================================================================================
//--信号定义
	/*--------------------------------------------------------------------------------------
	--SRIO IP Core A Interface
	--------------------------------------------------------------------------------------*/
	wire			[P_Srio_CH_NUM_R* 1-1:0]	rx_data_fifo_ren							;
	wire			[P_Srio_CH_NUM_R* 1-1:0]	rx_data_fifo_empty							;
	wire			[P_Srio_CH_NUM_R*64-1:0]	rx_data_fifo_dout							;
	wire			[P_Srio_CH_NUM_R* 1-1:0]	rx_trn_fifo_ren								;
	wire			[P_Srio_CH_NUM_R* 1-1:0]	rx_trn_fifo_empty							;
	wire			[P_Srio_CH_NUM_R*64-1:0]	rx_trn_fifo_dout							;


	/*--------------------------------------------------------------------------------------
	--Timestamp Interface
	--------------------------------------------------------------------------------------*/
	wire			[63:0]						bm_timestamp								;

//==================================================================================================
//--sp_bm_dma Instantation
	bm_dma	#(
		.P_SIMULATION_R							( P_SIMULATION_R							)
	)
	i_bm_dma (
		.clk									( clk										),
		.rst									( rst										),
		.dma_s_axis_tdata						( dma_s_axis_tdata							),
		.dma_s_axis_tid							( dma_s_axis_tid							),
		.dma_s_axis_tready						( dma_s_axis_tready							),
		.dma_s_axis_tvalid						( dma_s_axis_tvalid							),
		.dma_s_axis_tstrb						( dma_s_axis_tstrb							),
		.dma_s_axis_tkeep						( dma_s_axis_tkeep							),
		.dma_s_axis_tlast						( dma_s_axis_tlast							),
		.dma_s_axis_tuser						( dma_s_axis_tuser							),
		.dma_s_axis_tdest						( dma_s_axis_tdest							),
		.bm_timestamp							( bm_timestamp								),
		
		.c_bm_up_cnt							( c_bm_up_cnt								),
		
		.sarx_data_fifo_ren						( rx_data_fifo_ren			[0* 1+: 1]		),
		.sarx_data_fifo_empty					( rx_data_fifo_empty		[0* 1+: 1]		),
		.sarx_data_fifo_dout					( rx_data_fifo_dout			[0*64+:64]		),
		.sarx_trn_fifo_ren						( rx_trn_fifo_ren			[0* 1+: 1]		),
		.sarx_trn_fifo_empty					( rx_trn_fifo_empty			[0* 1+: 1]		),
		.sarx_trn_fifo_dout						( rx_trn_fifo_dout			[0*64+:64]		),

		.sbrx_data_fifo_ren						( rx_data_fifo_ren			[1* 1+: 1]		),
		.sbrx_data_fifo_empty					( rx_data_fifo_empty		[1* 1+: 1]		),
		.sbrx_data_fifo_dout					( rx_data_fifo_dout			[1*64+:64]		),
		.sbrx_trn_fifo_ren						( rx_trn_fifo_ren			[1* 1+: 1]		),
		.sbrx_trn_fifo_empty					( rx_trn_fifo_empty			[1* 1+: 1]		),
		.sbrx_trn_fifo_dout						( rx_trn_fifo_dout			[1*64+:64]		) 
	);
//==================================================================================================
//--bm_timestamp Instantation
	bm_timestamp	#(
		.P_SIMULATION_R							( P_SIMULATION_R							)
	)
	i_bm_timestamp (
		.clk									( clk										),
		.rst									( rst										),
		.c_bm_timestamp							( c_bm_timestamp							),
		.c_bm_timestamp_rf						( c_bm_timestamp_rf							),
		.timestamp								( bm_timestamp								)
	);

//==================================================================================================
//--bm_ch Instantation
genvar i;
generate for(i=0;i<P_Srio_CH_NUM_R;i=i+1) begin
	bm_ch	#(
		.P_SIMULATION_R							( P_SIMULATION_R							)
	)
	i_bm_rx (
		.clk									( clk										),
		.rst									( rst										),
		.srio_rst								( srio_rst									),
		
		.c_bm_en								( c_bm_en					[i* 1+: 1]		),
		.bm_recv_cnt							( c_bm_ch_recv_cnt			[i*32+:32]		),
		.bm_up_cnt								( c_bm_ch_up_cnt			[i*32+:32]		),
		.bm_lost_cnt							( c_bm_ch_lost_cnt			[i*32+:32]		),
		
		.log_clk								( log_clk					[i* 1+: 1]		),
		.axis_tvalid							( rx_tvalid					[i* 1+: 1]		),
		.axis_tready							( rx_tready					[i* 1+: 1]		),
		.axis_tlast								( rx_tlast					[i* 1+: 1]		),
		.axis_tdata								( rx_tdata					[i*64+:64]		),
		.axis_tkeep								( rx_tkeep					[i* 8+: 8]		),
		.axis_tuser								( rx_tuser					[i*32+:32]		),

		.bm_data_fifo_ren						( rx_data_fifo_ren			[i* 1+: 1]		),
		.bm_data_fifo_empty						( rx_data_fifo_empty		[i* 1+: 1]		),
		.bm_data_fifo_dout						( rx_data_fifo_dout			[i*64+:64]		),                   	
		.bm_trn_fifo_ren						( rx_trn_fifo_ren			[i* 1+: 1]		),
		.bm_trn_fifo_empty						( rx_trn_fifo_empty			[i* 1+: 1]		),
		.bm_trn_fifo_dout						( rx_trn_fifo_dout			[i*64+:64]		)
	);
end
endgenerate

endmodule