`timescale 1ns/1ns
//////////////////////////////////////////////////////////////////////////////////
// Company:			ZHTY
// Engineer:		ZYL
// Create Date:		2021/9/4 21:02:02
// Design Name:		IR2120
// Module Name:		lvds_top
// Project Name:
// Target Devices:	K7-V7
// Tool Versions: 	Vivado 2016.1 HDL-EDIT UltraEdit TAB=4 Consolas
// Description:
//		模块实现两路LVDS信号的数据的提取，快进慢发的DDR3缓存和流量控制功能
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
//////////////////////////////////////////////////////////////////////////////////
module lvds_cache_top #(
	/*--------------------------------------------------------------------------------------
	--P_SIMULATION_R
	---------------------------------------------------------------------------------------*/
	parameter		P_SIMULATION_R				= "FALSE"									,
	/*--------------------------------------------------------------------------------------
	--LVDS Cache Addr
	--------------------------------------------------------------------------------------*/
	parameter		P_LVDS_DDR3_START_ADDR_R	= 32'h4000_0000								,
	parameter		P_LVDS_DDR3_END_ADDR_R		= 32'h4200_0000								,
	parameter		P_LVDS_DDR3_BLOCK_SIZE_R	= 32'h1000                                 ,
	parameter		P_V_FRAME_DDR3_BLOCK_SIZE_R	= 32'h80_1000								

	)(
//==================================================================================================
//--PAD Declarations---------------------------
	/*--------------------------------------------------------------------------------------
	--Common interface
	--------------------------------------------------------------------------------------*/
	input										sys_rst_i									,
	input										sys_clk_i									,

	/*--------------------------------------------------------------------------------------
	--lvds buf data Out
	--------------------------------------------------------------------------------------*/
	input			[63:0]						lvds_data_fifo_dout_i						,
	output										lvds_data_fifo_ren_o						,
	input										lvds_data_fifo_empty_i						,

	input			[31:0]						lvds_trn_fifo_dout_i						,
	output										lvds_trn_fifo_ren_o							,
	input										lvds_trn_fifo_empty_i						,
	
	/*--------------------------------------------------------------------------------------
	--cur cache waddr out
	--------------------------------------------------------------------------------------*/	
	output			[31:0]						lvds_cache_cur_waddr						,
	input			[31:0]						lvds_cache_cur_raddr						,
	/*--------------------------------------------------------------------------------------
	--LVDS Data DDR3 buffer Write Channel
	--------------------------------------------------------------------------------------*/
	output	wire	[3:0]						MLVDS_AXI_AWID								,
	output	wire	[31:0]						MLVDS_AXI_AWADDR							,
	output	wire	[7:0]						MLVDS_AXI_AWLEN								,
	output	wire	[2:0]						MLVDS_AXI_AWSIZE							,
	output	wire	[1:0]						MLVDS_AXI_AWBURST							,
	output	wire								MLVDS_AXI_AWLOCK							,
	output	wire	[3:0]						MLVDS_AXI_AWCACHE							,
	output	wire	[2:0]						MLVDS_AXI_AWPROT							,
	output	wire	[3:0]						MLVDS_AXI_AWQOS								,
	output	wire								MLVDS_AXI_AWVALID							,
	input	wire								MLVDS_AXI_AWREADY							,
	output	wire	[63:0]						MLVDS_AXI_WDATA								,
	output	wire	[7:0]						MLVDS_AXI_WSTRB								,
	output	wire								MLVDS_AXI_WLAST								,
	output	wire								MLVDS_AXI_WVALID							,
	input	wire								MLVDS_AXI_WREADY							,
	input	wire	[3:0]						MLVDS_AXI_BID								,
	input	wire	[1:0]						MLVDS_AXI_BRESP								,
	input	wire								MLVDS_AXI_BVALID							,
	output	wire								MLVDS_AXI_BREADY
	);
//==================================================================================================
//--param defines

//==================================================================================================
//--internal signals
	wire										m_axiw_req									;
	wire										m_axiw_gnt									;
	wire			[10:0]						m_axiw_len64								;
	wire			[31:0]						m_axiw_addr									;
	wire			[7:0]						m_axiw_wstrb								;	//仅当最后一个64比特数据有效，用于OnlyOne模式	
	
//==================================================================================================
//--write Instantation
	lvds_cache_write	#(
		.P_SIMULATION_R							( P_SIMULATION_R							),
		.P_LVDS_DDR3_START_ADDR_R				( P_LVDS_DDR3_START_ADDR_R					),
		.P_LVDS_DDR3_END_ADDR_R					( P_LVDS_DDR3_END_ADDR_R					),
		.P_LVDS_DDR3_BLOCK_SIZE_R				( P_LVDS_DDR3_BLOCK_SIZE_R					),
		.P_V_FRAME_DDR3_BLOCK_SIZE_R			( P_V_FRAME_DDR3_BLOCK_SIZE_R				)
	)
	i_lvds_cache_write (
		.sys_rst_i								( sys_rst_i									),
		.sys_clk_i								( sys_clk_i									),
		
		.lvds_trn_fifo_dout_i					( lvds_trn_fifo_dout_i						),
		.lvds_trn_fifo_ren_o					( lvds_trn_fifo_ren_o						),
		.lvds_trn_fifo_empty_i					( lvds_trn_fifo_empty_i						),
		
		.lvds_cache_cur_waddr					( lvds_cache_cur_waddr						),	
		.lvds_cache_cur_raddr					( lvds_cache_cur_raddr						),	
		
		.m_axiw_req								( m_axiw_req								),
		.m_axiw_gnt								( m_axiw_gnt								),
		.m_axiw_len64							( m_axiw_len64								),
		.m_axiw_addr							( m_axiw_addr								),
		.m_axiw_wstrb							( m_axiw_wstrb								)
	);
//==================================================================================================
//--zt_axi4_wb Instantation
	zt_axi4_wb	#(
		.P_SIMULATION_R							( P_SIMULATION_R							)
	)
	i_zt_axi4_wb (
		.clk									( sys_clk_i									),
		.rst									( sys_rst_i									),
		
		.M_AXI_AWID								( MLVDS_AXI_AWID							),
		.M_AXI_AWADDR							( MLVDS_AXI_AWADDR							),
		.M_AXI_AWLEN							( MLVDS_AXI_AWLEN							),
		.M_AXI_AWSIZE							( MLVDS_AXI_AWSIZE							),
		.M_AXI_AWBURST							( MLVDS_AXI_AWBURST							),
		.M_AXI_AWLOCK							( MLVDS_AXI_AWLOCK							),
		.M_AXI_AWCACHE							( MLVDS_AXI_AWCACHE							),
		.M_AXI_AWPROT							( MLVDS_AXI_AWPROT							),
		.M_AXI_AWQOS							( MLVDS_AXI_AWQOS							),
		.M_AXI_AWVALID							( MLVDS_AXI_AWVALID							),
		.M_AXI_AWREADY							( MLVDS_AXI_AWREADY							),
		.M_AXI_WDATA							( MLVDS_AXI_WDATA							),
		.M_AXI_WSTRB							( MLVDS_AXI_WSTRB							),
		.M_AXI_WLAST							( MLVDS_AXI_WLAST							),
		.M_AXI_WVALID							( MLVDS_AXI_WVALID							),
		.M_AXI_WREADY							( MLVDS_AXI_WREADY							),
		.M_AXI_BID								( MLVDS_AXI_BID								),
		.M_AXI_BRESP							( MLVDS_AXI_BRESP							),
		.M_AXI_BVALID							( MLVDS_AXI_BVALID							),
		.M_AXI_BREADY							( MLVDS_AXI_BREADY							),
		
		.m_axiw_req								( m_axiw_req								),
		.m_axiw_gnt								( m_axiw_gnt								),
		.m_axiw_len64							( m_axiw_len64								),
		.m_axiw_addr							( m_axiw_addr								),
		.m_axiw_wstrb							( m_axiw_wstrb								),
		
		.m_axiw_fifo_rdata						( lvds_data_fifo_dout_i						),
		.m_axiw_fifo_empty						( lvds_data_fifo_empty_i					),
		.m_axiw_fifo_rden						( lvds_data_fifo_ren_o						)
	);

endmodule