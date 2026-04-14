`timescale 1ns/1ns
////////////////////////////////////////////////////////////////////////////////////////////////////
// Company			: ZHTY				
// Engineer			: wangzhen			
// Create Date		: 2026/2/5 19:16:43   										
// Design Name		:                   
// Module Name		: 		       		
// Project Name		: 		            
// Target Devices	: K7-V7		        
// Tool versions	: Vivado2020		
// Description		:                   
// 										
// Dependencies		: 					
// 										
// Top File			: 					
// 										
// Inst File		: 					
// 										
// Revision			: 					
//		Revision 1.00 - File Modified by	: 						
//		Description							: 						
//		data		: 				 	
//		1	: 				 	 		
//		2	: 				 	 		
//																	
// Additional Comments:												
////////////////////////////////////////////////////////////////////////////////////////////////////
module srio_video_frame_d_speed  #(
	parameter		P_set_lite					= 0											
) (
//==================================================================================================
//--反向映射查找表（LUT）DDR读取接口
	input	wire								V_LUT_AXI_clk							,
	input	wire								V_LUT_AXI_rstn							,

	output	wire	[3:0]						V_LUT_AXI_ARID								,
	output	wire	[31:0]						V_LUT_AXI_ARADDR							,
	output	wire	[7:0]						V_LUT_AXI_ARLEN								,
	output	wire	[2:0]						V_LUT_AXI_ARSIZE							,
	output	wire	[1:0]						V_LUT_AXI_ARBURST							,
	output	wire								V_LUT_AXI_ARLOCK							,
	output	wire	[3:0]						V_LUT_AXI_ARCACHE							,
	output	wire	[2:0]						V_LUT_AXI_ARPROT							,
	output	wire	[3:0]						V_LUT_AXI_ARQOS								,
	output	wire								V_LUT_AXI_ARVALID							,
	input	wire								V_LUT_AXI_ARREADY							,
	input	wire	[3:0]						V_LUT_AXI_RID								,
	input	wire	[63:0]						V_LUT_AXI_RDATA								,
	input	wire	[1:0]						V_LUT_AXI_RRESP								,
	input	wire								V_LUT_AXI_RLAST								,
	input	wire								V_LUT_AXI_RVALID							,
	output	wire								V_LUT_AXI_RREADY						,

	input										user_250m_clk									,	

	input										ps_video_en											,
	input			[7:0]							ps_frame_ctr											,
	// 新代码
	input			[31:0]							video_algo_ctrl										,
	
	input										video_send_en									,	

	input										clk_axis										,

	input										clk_srio										,
	input										rst_n										,
	
	output										srio_r_axis_tready								,
	input			[64-1:0] 					srio_r_axis_tdata								,
	input										srio_r_axis_tvalid								,
	input										srio_r_axis_tlast								, 
	input			[32-1:0] 					srio_r_axis_tuser								,

	input										srio_t_axis_tready								,  
	output			[64-1:0] 					srio_t_axis_tdata								,  
	output										srio_t_axis_tvalid								,  
	output										srio_t_axis_tlast								,
	output			[32-1:0] 					srio_t_axis_tuser								,  

	
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
//	srio_r srio时钟数据、srio_r_f	srio时钟、经过缓	srio_i本地时钟数
//	srio_o	本地时钟数据，srio_t_f srio时钟数据 ,srio_t srio时钟数据



	wire			[64-1:0]					srio_r_f_axis_tdata							;	
	wire			[32-1:0]					srio_r_f_axis_tuser							;	
	wire										srio_r_f_axis_tvalid						;	
	wire										srio_r_f_axis_tready						;	
	wire										srio_r_f_axis_tlast							;	

	wire			[64-1:0]					srio_i_axis_tdata							;	
	wire			[32-1:0]					srio_i_axis_tuser							;	
	wire										srio_i_axis_tvalid							;	
	wire										srio_i_axis_tready							;	
	wire										srio_i_axis_tlast							;	


	wire			[64-1:0]					srio_o_axis_tdata							;	
	wire			[32-1:0]					srio_o_axis_tuser							;	
	wire										srio_o_axis_tvalid							;	
	wire										srio_o_axis_tready							;	
	wire										srio_o_axis_tlast							;	
 
	wire			[64-1:0]					srio_t_f_axis_tdata							;	
	wire			[32-1:0]					srio_t_f_axis_tuser							;	
	wire										srio_t_f_axis_tvalid						;	
	wire										srio_t_f_axis_tready						;	
	wire										srio_t_f_axis_tlast							;	



//	axis_sync_fifo	#(
//		.C_FIFO_MODE							( "FALSE"									),	// "FALSE"- Disables Packet FIFO mode
//		.DW										( 64										),	
//		.UW										( 32										),	
//		.FIFO_SIZE								( 1024										)	
//	)	u_infifo_r(
//		.sys_clk								( clk_srio									),	
//		.sys_rst  								( ~rst_n										),
//
//		.wr_axis_tdata							( srio_r_axis_tdata							),	
//		.wr_axis_tkeep							( )											,	
//		.wr_axis_tuser							( srio_r_axis_tuser							),	
//		.wr_axis_tvalid							( srio_r_axis_tvalid						),	
//		.wr_axis_tlast							( srio_r_axis_tlast							),	
//		.wr_axis_tready							( srio_r_axis_tready						),	
//
//		.rd_axis_tdata							( srio_r_f_axis_tdata						),	
//		.rd_axis_tkeep							( )											,	
//		.rd_axis_tuser							( srio_r_f_axis_tuser						),	
//		.rd_axis_tvalid							( srio_r_f_axis_tvalid						),	
//		.rd_axis_tlast							( srio_r_f_axis_tlast						),	
//		.rd_axis_tready							( srio_r_f_axis_tready						),	
//
//		.axis_data_count						( )												
//	);
//             


//		data_bit16_check	check_s_rx(
//		.clk									( clk_srio								),	
//        .rst                                  	( ~rst_n                                     ), 
                                                                                               
//		.rx_dat									( srio_r_axis_tdata				),	
//		.rx_en									( srio_r_axis_tvalid		&srio_r_axis_tready ),	
//		.rx_last								( srio_r_axis_tlast    	));
		




	axis_clock_converter	axis_clock_converter_r(
		.s_axis_aresetn							( rst_n										),	
		.s_axis_aclk							( clk_srio									),	

//		.s_axis_tvalid							( srio_r_f_axis_tvalid						),	
//		.s_axis_tready							( srio_r_f_axis_tready						),	
//		.s_axis_tdata							( srio_r_f_axis_tdata						),	
//		.s_axis_tlast							( srio_r_f_axis_tlast						),	
//		.s_axis_tuser							( srio_r_f_axis_tuser						),	

		.s_axis_tvalid							( srio_r_axis_tvalid						),	
		.s_axis_tready							( srio_r_axis_tready						),	
		.s_axis_tdata							( srio_r_axis_tdata						),	
		.s_axis_tlast							( srio_r_axis_tlast						),	
		.s_axis_tuser							( srio_r_axis_tuser						),	

		.m_axis_aresetn							( rst_n										),	
		.m_axis_aclk							( clk_axis									),	

		.m_axis_tvalid							( srio_i_axis_tvalid						),	
		.m_axis_tready							( srio_i_axis_tready						),	
		.m_axis_tdata							( srio_i_axis_tdata							),	
		.m_axis_tlast							( srio_i_axis_tlast							),	
		.m_axis_tuser							( srio_i_axis_tuser							)	
	);
   

	axis_clock_converter	axis_clock_converter_t(
		.s_axis_aresetn							( rst_n										),	
		.s_axis_aclk							( clk_axis									),	

		.s_axis_tvalid							( srio_o_axis_tvalid						),	
		.s_axis_tready							( srio_o_axis_tready						),	
		.s_axis_tdata							( srio_o_axis_tdata							),	
		.s_axis_tlast							( srio_o_axis_tlast							),	
		.s_axis_tuser							( srio_o_axis_tuser							),	

		.m_axis_aresetn							( rst_n										),	
		.m_axis_aclk							( clk_srio									),	

		.m_axis_tvalid							( srio_t_f_axis_tvalid						),	
		.m_axis_tready							( srio_t_f_axis_tready						),	
		.m_axis_tdata							( srio_t_f_axis_tdata						),	
		.m_axis_tlast							( srio_t_f_axis_tlast						),	
		.m_axis_tuser							( srio_t_f_axis_tuser						)	
	);
//	axis_sync_fifo	#(
//		.C_FIFO_MODE							( "FALSE"									),	// "FALSE"- Disables Packet FIFO mode
//		.DW										( 64										),	
//		.UW										( 32										),	
//		.FIFO_SIZE								( 1024										)	
//	)	u_infifo_t(
//		.sys_clk								( clk_srio									),	
//		.sys_rst  								( ~rst_n										),
//
//		.wr_axis_tdata							( srio_t_f_axis_tdata						),	
//		.wr_axis_tkeep							( )											,	
//		.wr_axis_tuser							( srio_t_f_axis_tuser						),	
//		.wr_axis_tvalid							( srio_t_f_axis_tvalid						),	
//		.wr_axis_tlast							( srio_t_f_axis_tlast						),	
//		.wr_axis_tready							( srio_t_f_axis_tready						),	
//
//		.rd_axis_tdata							( srio_t_axis_tdata							),	
//		.rd_axis_tkeep							( )											,	
//		.rd_axis_tuser							( srio_t_axis_tuser							),	
//		.rd_axis_tvalid							( srio_t_axis_tvalid						),	
//		.rd_axis_tlast							( srio_t_axis_tlast							),	
//		.rd_axis_tready							( srio_t_axis_tready						),	
//
//		.axis_data_count						( )												
//	);


 	SRIO_2_Video	i_SRIO_2_Video(
 	
		.V_LUT_AXI_clk			    			( V_LUT_AXI_clk								),		
		.V_LUT_AXI_rstn		    				( V_LUT_AXI_rstn		    				), 	
	
 	
		.srio_clk								( clk_srio									),	
		.srio_rstn_i							( rst_n										),
		
 		.user_clk								( user_250m_clk									),	
		.user_rstn_i							( rst_n										),	//	待处理复位
		// 新代码
		.video_algo_ctrl						( video_algo_ctrl							),
		
		.SRIO_R_axis_tdata						( srio_t_f_axis_tdata							),	
		.SRIO_R_axis_tuser						( srio_t_f_axis_tuser							),	
		.SRIO_R_axis_tlast						( srio_t_f_axis_tlast							),	
		.SRIO_R_axis_tvalid						( srio_t_f_axis_tvalid						),	
		.SRIO_R_axis_tready      				( srio_t_f_axis_tready		   				),
		
		.SRIO_T_axis_tdata	    				( srio_t_axis_tdata	    					),	
		.SRIO_T_axis_tuser	    				( srio_t_axis_tuser	    					),	
		.SRIO_T_axis_tready	    				( srio_t_axis_tready						),	
		.SRIO_T_axis_tvalid	    				( srio_t_axis_tvalid						),	
		.SRIO_T_axis_tlast	         			( srio_t_axis_tlast	    	   				),	
			
		.V_LUT_AXI_ARID		    				( V_LUT_AXI_ARID							),	
		.V_LUT_AXI_ARADDR	    				( V_LUT_AXI_ARADDR	    					),	
		.V_LUT_AXI_ARLEN		     			( V_LUT_AXI_ARLEN			   				),		
		.V_LUT_AXI_ARSIZE	    				( V_LUT_AXI_ARSIZE	    					),	
		.V_LUT_AXI_ARBURST	    				( V_LUT_AXI_ARBURST	    					),	
		.V_LUT_AXI_ARLOCK	    				( V_LUT_AXI_ARLOCK	    					),	
		.V_LUT_AXI_ARCACHE	    				( V_LUT_AXI_ARCACHE	    					),	
		.V_LUT_AXI_ARPROT	         			( V_LUT_AXI_ARPROT	    	   				),		
		.V_LUT_AXI_ARQOS						( V_LUT_AXI_ARQOS							),	
		.V_LUT_AXI_ARVALID	    				( V_LUT_AXI_ARVALID	    					),	
		.V_LUT_AXI_ARREADY	    				( V_LUT_AXI_ARREADY	    					),	
		.V_LUT_AXI_RID		    				( V_LUT_AXI_RID		    					),	
		.V_LUT_AXI_RDATA		     			( V_LUT_AXI_RDATA			   				),
		.V_LUT_AXI_RRESP						( V_LUT_AXI_RRESP							),	
		.V_LUT_AXI_RLAST						( V_LUT_AXI_RLAST							),	
		.V_LUT_AXI_RVALID	    				( V_LUT_AXI_RVALID	    					),	
		.V_LUT_AXI_RREADY	    				( V_LUT_AXI_RREADY	    					)
	);




	/*--------------------------------------------------------------------------------------
	--P_SIMULATION_R
	---------------------------------------------------------------------------------------*/
	localparam		P_VIDEO_FRAME_NUM			=  4										;	
	localparam		P_VIDEO_FRAME_SIZE			=  32'h80_1000								;	

	localparam		P_SIMULATION_R				= "FALSE"									;	
	/*--------------------------------------------------------------------------------------
	--LVDS Cache Addr
	--------------------------------------------------------------------------------------*/	
	localparam		P_LVDS_DDR3_START_ADDR_R	= 32'h0000_0000 							;
	localparam		P_LVDS_DDR3_END_ADDR_R		= P_VIDEO_FRAME_NUM*P_VIDEO_FRAME_SIZE+	P_LVDS_DDR3_START_ADDR_R;	// 32'80_1000h*5=32'h280_5000,（32'h80_1000，32'h100_2000,32'h180_3000,32'h200_4000,）
	localparam		P_LVDS_DDR3_BLOCK_SIZE_R	= 32'h100									;
	
	/*--------------------------------------------------------------------------------------
	--LVDS Data iPort
	---------------------------------------------------------------------------------------*/
	localparam		P_LVDS_iport_R				= 4'h6									;
			
	lvds_top	#(
		.P_SIMULATION_R							( P_SIMULATION_R							),	
		.P_LVDS_DDR3_START_ADDR_R				( P_LVDS_DDR3_START_ADDR_R					),	
		.P_LVDS_DDR3_END_ADDR_R					( P_LVDS_DDR3_END_ADDR_R					),	
		.P_LVDS_DDR3_BLOCK_SIZE_R				( P_LVDS_DDR3_BLOCK_SIZE_R					),	
		.P_LVDS_iport_R							( P_LVDS_iport_R							)	
	)	i_lvds_top(
		.video_send_en								( video_send_en										),	
			.ps_frame_ctr									( ps_frame_ctr								),
			.ps_video_en									( ps_video_en								),

		.sys_rst_i								( ~rst_n									),
		.sys_clk_i								( clk_axis									),	

		.it_up_axis_tdata_i						( srio_i_axis_tdata							),	
		.it_up_axis_tid_i						( )											,	
		.it_up_axis_tready_o					( srio_i_axis_tready						),	
		.it_up_axis_tvalid_i					( srio_i_axis_tvalid						),	
		.it_up_axis_tstrb_i						( )											,	
		.it_up_axis_tkeep_i						( )											,	
		.it_up_axis_tlast_i						( srio_i_axis_tlast							),	
		.it_up_axis_tuser_i						( srio_i_axis_tuser							),	
		.it_up_axis_tdest_i						( )											,	

		.it_up_fix_axis_tdata_o					( )											,	
		.it_up_fix_axis_tid_o					( )											,	
		.it_up_fix_axis_tready_i				( 1'b1										),	
		.it_up_fix_axis_tvalid_o				( )											,	
		.it_up_fix_axis_tstrb_o					( )											,	
		.it_up_fix_axis_tkeep_o					( )											,	
		.it_up_fix_axis_tlast_o					( )											,	
		.it_up_fix_axis_tuser_o					( )											,	
		.it_up_fix_axis_tdest_o					( )											,	

		.it_up_lvds_axis_tdata_o				( srio_o_axis_tdata							),	
		.it_up_lvds_axis_tid_o					( )											,	
		.it_up_lvds_axis_tready_i				( srio_o_axis_tready						),	
		.it_up_lvds_axis_tvalid_o				( srio_o_axis_tvalid						),	
		.it_up_lvds_axis_tstrb_o				( )											,	
		.it_up_lvds_axis_tkeep_o				( )											,	
		.it_up_lvds_axis_tlast_o				( srio_o_axis_tlast							),	
		.it_up_lvds_axis_tuser_o				( srio_o_axis_tuser							),	
		.it_up_lvds_axis_tdest_o				( )											,	

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
		.MLVDS_AXI_RREADY						( MLVDS_AXI_RREADY							),	

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

//	ila_axis	ila_srio_s1(
//		.clk                        			( clk_axis								),
//		.probe0                                  ( {
//							i_lvds_top.lvds_cache_cur_raddr				,
//							i_lvds_top.lvds_cache_cur_waddr				,
//							i_lvds_top.i_lvds_hdlc_top.i_lvds_hdlc_read.S_AXIR_CM		,
//							i_lvds_top.i_lvds_hdlc_top.i_lvds_hdlc_read.picture_signal_get	,
//							i_lvds_top.i_lvds_hdlc_top.i_lvds_hdlc_read.clear		,
//							i_lvds_top.i_lvds_hdlc_top.i_lvds_hdlc_read.S_AXIR_CM		
								
//																							})
//	);
		


endmodule
