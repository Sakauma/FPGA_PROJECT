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
// Module Name:		lvds_top
// Project Name:
// Target Devices:	K7-V7
// Tool Versions: 	Vivado 2016.1 HDL-EDIT UltraEdit TAB=4 Consolas
// Description:
//		妯″潡瀹炵幇涓よ矾LVDS淇″彿鐨勬暟鎹殑鎻愬彇锛屽揩杩涙參鍙戠殑DDR3缂撳瓨鍜屾祦閲忔帶鍒跺姛鑳?
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
//////////////////////////////////////////////////////////////////////////////////
module lvds_top #(
	/*--------------------------------------------------------------------------------------
	--P_SIMULATION_R
	---------------------------------------------------------------------------------------*/
	parameter		P_SIMULATION_R				= "FALSE"									,
	/*--------------------------------------------------------------------------------------
	--LVDS Cache Addr
	--------------------------------------------------------------------------------------*/
	parameter		P_LVDS_DDR3_START_ADDR_R	= 32'h4000_0000								,
	parameter		P_LVDS_DDR3_END_ADDR_R		= 32'h4200_0000								,
	parameter		P_LVDS_DDR3_BLOCK_SIZE_R	= 32'h1000									,
	
	parameter		P_V_FRAME_DDR3_BLOCK_SIZE_R	= 32'h80_1000								,

	/*--------------------------------------------------------------------------------------
	--LVDS Data iPort
	---------------------------------------------------------------------------------------*/
	parameter		P_LVDS_iport_R				= 4'h6
	)(
		input										ps_video_en											,
	input			[7:0]							ps_frame_ctr											,
	
	input										video_send_en									,	
//==================================================================================================
//--PAD Declarations---------------------------
	/*--------------------------------------------------------------------------------------
	--Common interface
	--------------------------------------------------------------------------------------*/
	input										sys_rst_i									,
	input										sys_clk_i									,

	/*--------------------------------------------------------------------------------------
	--iT UP Stream interface
	--------------------------------------------------------------------------------------*/
	input			[63:0]						it_up_axis_tdata_i							,
	input			[ 3:0]						it_up_axis_tid_i							,
	output										it_up_axis_tready_o							,
	input										it_up_axis_tvalid_i							,
	input			[ 7:0]						it_up_axis_tstrb_i							,
	input			[ 7:0]						it_up_axis_tkeep_i							,
	input										it_up_axis_tlast_i							,
	input			[63:0]						it_up_axis_tuser_i							,
	input			[ 3:0]						it_up_axis_tdest_i							,

	/*--------------------------------------------------------------------------------------
	--iT UP split LVDS Data stream out for HDLC
	--------------------------------------------------------------------------------------*/
	output			[63:0]						it_up_fix_axis_tdata_o						,
	output			[ 3:0]						it_up_fix_axis_tid_o						,
	input										it_up_fix_axis_tready_i						,
	output										it_up_fix_axis_tvalid_o						,
	output			[ 7:0]						it_up_fix_axis_tstrb_o						,
	output			[ 7:0]						it_up_fix_axis_tkeep_o						,
	output										it_up_fix_axis_tlast_o						,
	output			[63:0]						it_up_fix_axis_tuser_o						,
	output			[ 3:0]						it_up_fix_axis_tdest_o						,

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
	output	wire								MLVDS_AXI_RREADY							,

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
//--Signals define
	/*--------------------------------------------------------------------------------------
	--lvds buf data Out
	--------------------------------------------------------------------------------------*/
	wire			[63:0]						lvds_data_fifo_dout							;
	wire										lvds_data_fifo_ren							;
	wire										lvds_data_fifo_empty						;

	wire			[31:0]						lvds_trn_fifo_dout							;
	wire										lvds_trn_fifo_ren							;
	wire										lvds_trn_fifo_empty							;
	
	/*--------------------------------------------------------------------------------------
	--FIX buf data Out
	--------------------------------------------------------------------------------------*/
	wire			[64:0]						fix_data_fifo_dout							;
	wire										fix_data_fifo_ren							;
	wire										fix_data_fifo_empty							;
	
	/*--------------------------------------------------------------------------------------
	--Buf current waddr
	--------------------------------------------------------------------------------------*/
	wire			[31:0]						lvds_cache_cur_waddr						;
	wire			[31:0]						lvds_cache_cur_raddr						;



	wire										w_it_up_axis_tvalid_i					;
	wire										w_it_up_axis_tready_o						;
	                                                                                        
	wire										w_it_up_lvds_axis_tready_i					;
	wire			[63:0]						w_it_up_lvds_axis_tdata_o					;
	wire			[ 3:0]						w_it_up_lvds_axis_tid_o						;
	wire										w_it_up_lvds_axis_tvalid_o					;
	wire			[ 7:0]						w_it_up_lvds_axis_tstrb_o					;
	wire			[ 7:0]						w_it_up_lvds_axis_tkeep_o					;
	wire										w_it_up_lvds_axis_tlast_o					;
	wire			[63:0]						w_it_up_lvds_axis_tuser_o					;
	wire			[ 3:0]						w_it_up_lvds_axis_tdest_o					;


	assign			it_up_lvds_axis_tdata_o			= ps_frame_ctr ==0 && ps_video_en 	?  it_up_axis_tdata_i			: 		w_it_up_lvds_axis_tdata_o	;
	assign			it_up_lvds_axis_tid_o			= ps_frame_ctr ==0 && ps_video_en 	?  it_up_axis_tid_i	    		: 		w_it_up_lvds_axis_tid_o		;
	assign			it_up_lvds_axis_tvalid_o		= ps_frame_ctr ==0 && ps_video_en 	?  it_up_axis_tvalid_i	    	: 		w_it_up_lvds_axis_tvalid_o	;
	assign			it_up_lvds_axis_tstrb_o			= ps_frame_ctr ==0 && ps_video_en 	?  it_up_axis_tstrb_i			: 		w_it_up_lvds_axis_tstrb_o	;
	assign			it_up_lvds_axis_tkeep_o			= ps_frame_ctr ==0 && ps_video_en 	?  it_up_axis_tkeep_i			: 		w_it_up_lvds_axis_tkeep_o	;
	assign			it_up_lvds_axis_tlast_o			= ps_frame_ctr ==0 && ps_video_en 	?  it_up_axis_tlast_i			: 		w_it_up_lvds_axis_tlast_o	;
	assign			it_up_lvds_axis_tuser_o			= ps_frame_ctr ==0 && ps_video_en 	?  it_up_axis_tuser_i			: 		w_it_up_lvds_axis_tuser_o	;
	assign			it_up_lvds_axis_tdest_o			= ps_frame_ctr ==0 && ps_video_en 	?  it_up_axis_tdest_i			: 		w_it_up_lvds_axis_tdest_o	;

    assign			it_up_axis_tready_o				= ps_frame_ctr ==0 && ps_video_en 	?  it_up_lvds_axis_tready_i		: 		w_it_up_axis_tready_o		;      
    assign			w_it_up_axis_tvalid_i			= ps_frame_ctr ==0 && ps_video_en 	?  1'b0	    					: 		it_up_axis_tvalid_i			;       
	assign			w_it_up_lvds_axis_tready_i		= ps_frame_ctr ==0 && ps_video_en 	?  1'b1							: 		it_up_lvds_axis_tready_i	;   
	
	
//==================================================================================================
//--lvds_parse Instantation
	lvds_parse_full_drop	#(
		.P_SIMULATION_R							( P_SIMULATION_R							),
		.P_LVDS_iport_R							( P_LVDS_iport_R							)
	)
	i_lvds_parse (
		.sys_rst_i								( sys_rst_i									),
		.sys_clk_i								( sys_clk_i									),

		.it_up_axis_tdata_i						( it_up_axis_tdata_i						),
		.it_up_axis_tid_i						( it_up_axis_tid_i							),
		.it_up_axis_tready_o					( w_it_up_axis_tready_o						),
		.it_up_axis_tvalid_i					( w_it_up_axis_tvalid_i						),
		.it_up_axis_tstrb_i						( it_up_axis_tstrb_i						),
		.it_up_axis_tkeep_i						( it_up_axis_tkeep_i						),
		.it_up_axis_tlast_i						( it_up_axis_tlast_i						),
		.it_up_axis_tuser_i						( it_up_axis_tuser_i						),
		.it_up_axis_tdest_i						( it_up_axis_tdest_i						),
		
		.fix_data_fifo_dout_o					( fix_data_fifo_dout						),
		.fix_data_fifo_ren_i					( fix_data_fifo_ren							),
		.fix_data_fifo_empty_o					( fix_data_fifo_empty						),
		
		.lvds_data_fifo_dout_o					( lvds_data_fifo_dout						),
		.lvds_data_fifo_ren_i					( lvds_data_fifo_ren						),
		.lvds_data_fifo_empty_o					( lvds_data_fifo_empty						),

		.lvds_trn_fifo_dout_o					( lvds_trn_fifo_dout						),
		.lvds_trn_fifo_ren_i					( lvds_trn_fifo_ren							),
		.lvds_trn_fifo_empty_o					( lvds_trn_fifo_empty						)
	);

//==================================================================================================
//--lvds_fix Instantation
	lvds_fix	#(
		.P_SIMULATION_R							( P_SIMULATION_R							)
	)
	i_lvds_fix (
		.sys_rst_i								( sys_rst_i									),
		.sys_clk_i								( sys_clk_i									),
		
		.it_up_fix_axis_tdata_o					( it_up_fix_axis_tdata_o					),
		.it_up_fix_axis_tid_o					( it_up_fix_axis_tid_o						),
		.it_up_fix_axis_tready_i				( it_up_fix_axis_tready_i					),
		.it_up_fix_axis_tvalid_o				( it_up_fix_axis_tvalid_o					),
		.it_up_fix_axis_tstrb_o					( it_up_fix_axis_tstrb_o					),
		.it_up_fix_axis_tkeep_o					( it_up_fix_axis_tkeep_o					),
		.it_up_fix_axis_tlast_o					( it_up_fix_axis_tlast_o					),
		.it_up_fix_axis_tuser_o					( it_up_fix_axis_tuser_o					),
		.it_up_fix_axis_tdest_o					( it_up_fix_axis_tdest_o					),
		
		.fix_data_fifo_dout_i					( fix_data_fifo_dout						),
		.fix_data_fifo_ren_o					( fix_data_fifo_ren							),
		.fix_data_fifo_empty_i					( fix_data_fifo_empty						)
	);


//==================================================================================================
//--lvds_cache_top Instantation
	lvds_cache_top	#(
		.P_SIMULATION_R							( P_SIMULATION_R							),
		.P_LVDS_DDR3_START_ADDR_R				( P_LVDS_DDR3_START_ADDR_R					),
		.P_LVDS_DDR3_END_ADDR_R					( P_LVDS_DDR3_END_ADDR_R					),
		.P_LVDS_DDR3_BLOCK_SIZE_R				( P_LVDS_DDR3_BLOCK_SIZE_R					),
		.P_V_FRAME_DDR3_BLOCK_SIZE_R			( P_V_FRAME_DDR3_BLOCK_SIZE_R				)
	)
	i_lvds_cache_top (
		.sys_rst_i								( sys_rst_i									),
		.sys_clk_i								( sys_clk_i									),

		.lvds_data_fifo_dout_i					( lvds_data_fifo_dout						),
		.lvds_data_fifo_ren_o					( lvds_data_fifo_ren						),
		.lvds_data_fifo_empty_i					( lvds_data_fifo_empty						),

		.lvds_trn_fifo_dout_i					( lvds_trn_fifo_dout						),
		.lvds_trn_fifo_ren_o					( lvds_trn_fifo_ren							),
		.lvds_trn_fifo_empty_i					( lvds_trn_fifo_empty						),

		.lvds_cache_cur_waddr					( lvds_cache_cur_waddr						),
		.lvds_cache_cur_raddr					( lvds_cache_cur_raddr						),

		.MLVDS_AXI_AWID							( MLVDS_AXI_AWID							),
		.MLVDS_AXI_AWADDR						( MLVDS_AXI_AWADDR							),
		.MLVDS_AXI_AWLEN						( MLVDS_AXI_AWLEN							),
		.MLVDS_AXI_AWSIZE						( MLVDS_AXI_AWSIZE							),
		.MLVDS_AXI_AWBURST						( MLVDS_AXI_AWBURST							),
		.MLVDS_AXI_AWLOCK						( MLVDS_AXI_AWLOCK							),
		.MLVDS_AXI_AWCACHE						( MLVDS_AXI_AWCACHE							),
		.MLVDS_AXI_AWPROT						( MLVDS_AXI_AWPROT							),
		.MLVDS_AXI_AWQOS						( MLVDS_AXI_AWQOS							),
		.MLVDS_AXI_AWVALID						( MLVDS_AXI_AWVALID							),
		.MLVDS_AXI_AWREADY						( MLVDS_AXI_AWREADY							),
		.MLVDS_AXI_WDATA						( MLVDS_AXI_WDATA							),
		.MLVDS_AXI_WSTRB						( MLVDS_AXI_WSTRB							),
		.MLVDS_AXI_WLAST						( MLVDS_AXI_WLAST							),
		.MLVDS_AXI_WVALID						( MLVDS_AXI_WVALID							),
		.MLVDS_AXI_WREADY						( MLVDS_AXI_WREADY							),
		.MLVDS_AXI_BID							( MLVDS_AXI_BID								),
		.MLVDS_AXI_BRESP						( MLVDS_AXI_BRESP							),
		.MLVDS_AXI_BVALID						( MLVDS_AXI_BVALID							),
		.MLVDS_AXI_BREADY						( MLVDS_AXI_BREADY							)
	);


//==================================================================================================
//--lvds_hdlc_top Instantation
	lvds_hdlc_top	#(
		.P_SIMULATION_R							( P_SIMULATION_R							),
		.P_LVDS_DDR3_START_ADDR_R				( P_LVDS_DDR3_START_ADDR_R					),
		.P_LVDS_DDR3_END_ADDR_R					( P_LVDS_DDR3_END_ADDR_R					),
		.P_LVDS_DDR3_BLOCK_SIZE_R				( P_LVDS_DDR3_BLOCK_SIZE_R					),
		.P_V_FRAME_DDR3_BLOCK_SIZE_R			( P_V_FRAME_DDR3_BLOCK_SIZE_R				)
	)
	i_lvds_hdlc_top (
			.video_send_en									( video_send_en								),
			.ps_frame_ctr									( ps_frame_ctr								),
			.ps_video_en									( ps_video_en								),

		.sys_rst_i								( sys_rst_i									),
		.sys_clk_i								( sys_clk_i									),

		.lvds_cache_cur_waddr					( lvds_cache_cur_waddr						),
		.lvds_cache_cur_raddr					( lvds_cache_cur_raddr						),

		.it_up_lvds_axis_tdata_o				( w_it_up_lvds_axis_tdata_o					),
		.it_up_lvds_axis_tid_o					( w_it_up_lvds_axis_tid_o						),
		.it_up_lvds_axis_tready_i				( w_it_up_lvds_axis_tready_i					),
		.it_up_lvds_axis_tvalid_o				( w_it_up_lvds_axis_tvalid_o					),
		.it_up_lvds_axis_tstrb_o				( w_it_up_lvds_axis_tstrb_o					),
		.it_up_lvds_axis_tkeep_o				( w_it_up_lvds_axis_tkeep_o					),
		.it_up_lvds_axis_tlast_o				( w_it_up_lvds_axis_tlast_o					),
		.it_up_lvds_axis_tuser_o				( w_it_up_lvds_axis_tuser_o					),
		.it_up_lvds_axis_tdest_o				( w_it_up_lvds_axis_tdest_o					),

		.MLVDS_AXI_ARID							( MLVDS_AXI_ARID							),
		.MLVDS_AXI_ARADDR						( MLVDS_AXI_ARADDR							),
		.MLVDS_AXI_ARLEN						( MLVDS_AXI_ARLEN							),
		.MLVDS_AXI_ARSIZE						( MLVDS_AXI_ARSIZE							),
		.MLVDS_AXI_ARBURST						( MLVDS_AXI_ARBURST							),
		.MLVDS_AXI_ARLOCK						( MLVDS_AXI_ARLOCK							),
		.MLVDS_AXI_ARCACHE						( MLVDS_AXI_ARCACHE							),
		.MLVDS_AXI_ARPROT						( MLVDS_AXI_ARPROT							),
		.MLVDS_AXI_ARQOS						( MLVDS_AXI_ARQOS							),
		.MLVDS_AXI_ARVALID						( MLVDS_AXI_ARVALID							),
		.MLVDS_AXI_ARREADY						( MLVDS_AXI_ARREADY							),
		.MLVDS_AXI_RID							( MLVDS_AXI_RID								),
		.MLVDS_AXI_RDATA						( MLVDS_AXI_RDATA							),
		.MLVDS_AXI_RRESP						( MLVDS_AXI_RRESP							),
		.MLVDS_AXI_RLAST						( MLVDS_AXI_RLAST							),
		.MLVDS_AXI_RVALID						( MLVDS_AXI_RVALID							),
		.MLVDS_AXI_RREADY						( MLVDS_AXI_RREADY							)
	);



endmodule
