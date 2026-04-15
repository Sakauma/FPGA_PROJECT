`timescale 1ns/1ns
// ============================================================================
// 维护注释
//   文件职责      : SRIO 视频收发、解包、节流与协议辅助逻辑。
//   源码属性      : 手工维护源码，不要把修改同步到生成 IP 或网表。
//   更新要求      : 当时钟、复位、接口或数据顺序假设变化时，同步更新注释。
//   维护边界      : 注释用于说明当前实现意图，不替代接口协议文档。
// ============================================================================
//////////////////////////////////////////////////////////////////////////////////
// Company:			ZHTY
// Engineer:		ZYL
// Create Date:		2021/9/4 21:02:02
// Design Name:		IR2120
// Module Name:		lvds_hdlc_top
// Project Name:
// Target Devices:	K7-V7
// Tool Versions: 	Vivado 2016.1 HDL-EDIT UltraEdit TAB=4 Consolas
// Description:
//		妯″潡灏哃VDS鏁版嵁浠嶥DR涓鍑猴紝骞剁敓鎴怚T UP Stream鏃跺簭锛岄€佸線HDLC
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
//////////////////////////////////////////////////////////////////////////////////
module lvds_hdlc_top #(
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
	input										video_send_en									,	
		input										ps_video_en											,
	input			[7:0]							ps_frame_ctr											,
	
//==================================================================================================
//--PAD Declarations---------------------------
	/*--------------------------------------------------------------------------------------
	--Common interface
	--------------------------------------------------------------------------------------*/
	input										sys_rst_i									,
	input										sys_clk_i									,
	
	/*--------------------------------------------------------------------------------------
	--from cache manage
	--------------------------------------------------------------------------------------*/	
	input			[31:0]						lvds_cache_cur_waddr						,
	output			[31:0]						lvds_cache_cur_raddr						,
	
	/*--------------------------------------------------------------------------------------
	--iT UP lvds data stream out for HDLC
	--------------------------------------------------------------------------------------*/
	output			[63:0]						it_up_lvds_axis_tdata_o						,
	output			[ 3:0]						it_up_lvds_axis_tid_o						,
	input										it_up_lvds_axis_tready_i					,
	output										it_up_lvds_axis_tvalid_o					,
	output			[ 7:0]						it_up_lvds_axis_tstrb_o						,
	output			[ 7:0]						it_up_lvds_axis_tkeep_o						,
	output										it_up_lvds_axis_tlast_o						,
	output			[63:0]						it_up_lvds_axis_tuser_o						,
	output			[ 3:0]						it_up_lvds_axis_tdest_o						,

	/*--------------------------------------------------------------------------------------
	--LVDS Data DDR3 buffer Read Channel
	--------------------------------------------------------------------------------------*/
	output	wire	[3:0]						MLVDS_AXI_ARID								,
	output	wire	[31:0]						MLVDS_AXI_ARADDR							,
	output	wire	[7:0]						MLVDS_AXI_ARLEN								,
	output	wire	[2:0]						MLVDS_AXI_ARSIZE							,
	output	wire	[1:0]						MLVDS_AXI_ARBURST							,
	output	wire								MLVDS_AXI_ARLOCK							,
	output	wire	[3:0]						MLVDS_AXI_ARCACHE							,
	output	wire	[2:0]						MLVDS_AXI_ARPROT							,
	output	wire	[3:0]						MLVDS_AXI_ARQOS								,
	output	wire								MLVDS_AXI_ARVALID							,
	input	wire								MLVDS_AXI_ARREADY							,
	
	input	wire	[3:0]						MLVDS_AXI_RID								,
	input	wire	[63:0]						MLVDS_AXI_RDATA								,
	input	wire	[1:0]						MLVDS_AXI_RRESP								,
	input	wire								MLVDS_AXI_RLAST								,
	input	wire								MLVDS_AXI_RVALID							,
	output	wire								MLVDS_AXI_RREADY
	);
//==================================================================================================
//--LVDS data
	/*--------------------------------------------------------------------------------------
	--AXI鏁版嵁閫氶亾璇昏姹傛帴鍙?
	--------------------------------------------------------------------------------------*/
	wire										m_axir_req									;
	wire										m_axir_gnt									;
	wire			[10:0]						m_axir_len64								;
	wire			[31:0]						m_axir_addr									;
	
	/*--------------------------------------------------------------------------------------
	--to lvds_m_axis 
	--------------------------------------------------------------------------------------*/	
	wire			[65:0]						axis_data_fifo_dout							;
	wire										axis_data_fifo_empty						;
	wire										axis_data_fifo_ren	                        ;

//==================================================================================================
//--lvds_hdlc_axis Instantation
	lvds_hdlc_axis	#(
		.P_SIMULATION_R							( P_SIMULATION_R							)
	)
	i_lvds_hdlc_axis (
		.sys_rst_i								( sys_rst_i									),
		.sys_clk_i								( sys_clk_i									),
		
		.it_up_lvds_axis_tdata_o				( it_up_lvds_axis_tdata_o					),
		.it_up_lvds_axis_tid_o					( it_up_lvds_axis_tid_o						),
		.it_up_lvds_axis_tready_i				( it_up_lvds_axis_tready_i					),
		.it_up_lvds_axis_tvalid_o				( it_up_lvds_axis_tvalid_o					),
		.it_up_lvds_axis_tstrb_o				( it_up_lvds_axis_tstrb_o					),
		.it_up_lvds_axis_tkeep_o				( it_up_lvds_axis_tkeep_o					),
		.it_up_lvds_axis_tlast_o				( it_up_lvds_axis_tlast_o					),
		.it_up_lvds_axis_tuser_o				( it_up_lvds_axis_tuser_o					),
		.it_up_lvds_axis_tdest_o				( it_up_lvds_axis_tdest_o					),
		
		.axis_data_fifo_dout_i					( axis_data_fifo_dout						),
		.axis_data_fifo_empty_i					( axis_data_fifo_empty						),
		.axis_data_fifo_ren_o					( axis_data_fifo_ren						)
	);


//==================================================================================================
//--lvds_hdlc_read Instantation
	lvds_hdlc_read	#(
		.P_SIMULATION_R							( P_SIMULATION_R							),
		.P_LVDS_DDR3_START_ADDR_R				( P_LVDS_DDR3_START_ADDR_R					),
		.P_LVDS_DDR3_END_ADDR_R					( P_LVDS_DDR3_END_ADDR_R					),
		.P_LVDS_DDR3_BLOCK_SIZE_R				( P_LVDS_DDR3_BLOCK_SIZE_R					),
		.P_V_FRAME_DDR3_BLOCK_SIZE_R			( P_V_FRAME_DDR3_BLOCK_SIZE_R				)
		
	)
	i_lvds_hdlc_read (
			.video_send_en									( video_send_en								),
						.ps_video_en									( ps_video_en								),

			.ps_frame_ctr									( ps_frame_ctr								),
				
		.sys_rst_i								( sys_rst_i									),
		.sys_clk_i								( sys_clk_i									),

		.MLVDS_AXI_RID							( MLVDS_AXI_RID								),
		.MLVDS_AXI_RDATA						( MLVDS_AXI_RDATA							),
		.MLVDS_AXI_RRESP						( MLVDS_AXI_RRESP							),
		.MLVDS_AXI_RLAST						( MLVDS_AXI_RLAST							),
		.MLVDS_AXI_RVALID						( MLVDS_AXI_RVALID							),
		.MLVDS_AXI_RREADY						( MLVDS_AXI_RREADY							),

		.lvds_cache_cur_waddr					( lvds_cache_cur_waddr						),
		.lvds_cache_cur_raddr					( lvds_cache_cur_raddr						),

		.m_axir_req								( m_axir_req								),
		.m_axir_gnt								( m_axir_gnt								),
		.m_axir_len64							( m_axir_len64								),
		.m_axir_addr							( m_axir_addr								),
		
		.axis_data_fifo_dout_o					( axis_data_fifo_dout						),
		.axis_data_fifo_empty_o					( axis_data_fifo_empty						),
		.axis_data_fifo_ren_i					( axis_data_fifo_ren						)
	);
//==================================================================================================
//--zt_axi4_rb Instantation
	zt_axi4_rb	#(
		.P_SIMULATION_R							( P_SIMULATION_R							)
	)
	i_zt_axi4_rb (
		.clk									( sys_clk_i									),
		.rst									( sys_rst_i									),

		.M_AXI_ARID								( MLVDS_AXI_ARID							),
		.M_AXI_ARADDR							( MLVDS_AXI_ARADDR							),
		.M_AXI_ARLEN							( MLVDS_AXI_ARLEN							),
		.M_AXI_ARSIZE							( MLVDS_AXI_ARSIZE							),
		.M_AXI_ARBURST							( MLVDS_AXI_ARBURST							),
		.M_AXI_ARLOCK							( MLVDS_AXI_ARLOCK							),
		.M_AXI_ARCACHE							( MLVDS_AXI_ARCACHE							),
		.M_AXI_ARPROT							( MLVDS_AXI_ARPROT							),
		.M_AXI_ARQOS							( MLVDS_AXI_ARQOS							),
		.M_AXI_ARVALID							( MLVDS_AXI_ARVALID							),
		.M_AXI_ARREADY							( MLVDS_AXI_ARREADY							),

		.m_axir_req								( m_axir_req								),
		.m_axir_gnt								( m_axir_gnt								),
		.m_axir_len64							( m_axir_len64								),
		.m_axir_addr							( m_axir_addr								)
	);

endmodule
