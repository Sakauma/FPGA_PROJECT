`timescale 1ns/1ps
////////////////////////////////////////////////////////////////////////////////////////////////////
// Company			: ZHTY
// Engineer			: wangzhen
// Create Date		: 2025/11/13 15:34:53
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
/*
 
 source C:/JFM_Kits/ip_patch/run.tcl
 add_hook_tcl_to_prj
 pre_synthesis_patch

cd E:/FPGA_CBB_WZ/srio_v10/10_PRJ/00_PRJ.sim/sim_1/behav/modelsim
do tb_top_compile.do
do tb_top_simulate.do
run 220us

do tb_top_compile.do
restart
run 220us
*/
module srio_test_prj_top	#(
    parameter 		P_SYS_CLK_FREQ   			= 32'd125000000        						,	//ϵͳʱ��Ƶ��
	parameter		P_Srio_PHY_LANE_R			= 4												//Physical lane number,board gtx for SRIO
)(		
	input										VP											,
	input										VN											,
`ifndef D_SEL_only_video

	input										ps_sys_clk											,

   	input 	wire	[11:00]						device_temp        							,	//DDR�¶Ƚӿ�
  	input			[31:0]						srio_v_sid_did								,
  	input										srio_v_sel_x1								,

	input										ps_video_en									,
	input			[7:0]						ps_frame_ctr								,			
//==================================================================================================
//--����ӳ����ұ�LUT��DDR��ȡ�ӿ�
	output	wire								V_LUT_AXI_clk								,
	output	wire								V_LUT_AXI_rstn								,

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
	output	wire								V_LUT_AXI_RREADY							,

	input										srio_vx1_r_axis_aclk						,

	output										srio_vx1_r_axis_tready						,
	input			[64-1:0] 					srio_vx1_r_axis_tdata						,
	input										srio_vx1_r_axis_tvalid						,
	input										srio_vx1_r_axis_tlast						, 
	input			[32-1:0] 					srio_vx1_r_axis_tuser						,	
`endif
	input										sys_clk_n									,
	input										sys_clk_p									,

	input										srio_sys_clk_p								,
	input										srio_sys_clk_n								,

//	output			[P_Srio_PHY_LANE_R-1:0]		srio_tx_disable								,

	input			[P_Srio_PHY_LANE_R-1:0]		srio_rxn0									,
	input			[P_Srio_PHY_LANE_R-1:0]		srio_rxp0									,
	output			[P_Srio_PHY_LANE_R-1:0]		srio_txn0									,
	output			[P_Srio_PHY_LANE_R-1:0]		srio_txp0									,

    inout   [63:0]     ddr3_dq             ,   //ddr3 ����
    inout   [7:0]      ddr3_dqs_n          ,   //ddr3 dqs��
    inout   [7:0]      ddr3_dqs_p          ,   //ddr3 dqs��  
    output  [14:0]     ddr3_addr           ,   //ddr3 ��ַ   
    output  [2:0]      ddr3_ba             ,   //ddr3 banck ѡ��
    output             ddr3_ras_n          ,   //ddr3 ��ѡ��
    output             ddr3_cas_n          ,   //ddr3 ��ѡ��
    output             ddr3_we_n           ,   //ddr3 ��дѡ��
    output             ddr3_reset_n        ,   //ddr3 ��λ
    output  [0:0]      ddr3_ck_p           ,   //ddr3 ʱ����
    output  [0:0]      ddr3_ck_n           ,   //ddr3 ʱ�Ӹ�
    output  [0:0]      ddr3_cke            ,   //ddr3 ʱ��ʹ��
    output  [0:0]      ddr3_cs_n           ,   //ddr3 Ƭѡ
    output  [7:0]      ddr3_dm             ,   //ddr3_dm
    output  [0:0]      ddr3_odt            //,    //ddr3_odt    

);
`ifdef D_SEL_only_video

		wire								V_LUT_AXI_rstn								;

		wire								V_LUT_AXI_clk								;
`endif

		wire								user_250m_clk ;



		localparam		P_SRIO_UP_NUM_R				= 3											;	//max:8
	localparam		P_SRIO_DN_NUM_R				= 2											;	

	wire			[P_SRIO_UP_NUM_R*1-1	: 0]	srio_s_axis_aclk						;	
	wire			[P_SRIO_UP_NUM_R*64-1 	: 0]	srio_s_axis_tdata						;	
	wire			[P_SRIO_UP_NUM_R*4-1  	: 0]	srio_s_axis_tid							;	
	wire			[P_SRIO_UP_NUM_R*1-1	: 0]	srio_s_axis_tready						;	
	wire			[P_SRIO_UP_NUM_R*1-1	: 0]	srio_s_axis_tvalid						;	
	wire			[P_SRIO_UP_NUM_R*8-1	: 0]	srio_s_axis_tstrb						;	
	wire			[P_SRIO_UP_NUM_R*8-1	: 0]	srio_s_axis_tkeep						;	
	wire			[P_SRIO_UP_NUM_R*1-1	: 0]	srio_s_axis_tlast						;	
	wire			[P_SRIO_UP_NUM_R*64-1	: 0]	srio_s_axis_tuser						;	
	wire			[P_SRIO_UP_NUM_R*4-1	: 0]	srio_s_axis_tdest						;	


	/*--------------------------------------------------------------------------------------
	--SRIOͨ������ AXI Stream�ӿ�
	--------------------------------------------------------------------------------------*/

	wire			[P_SRIO_DN_NUM_R*1-1	: 0]	srio_m_axis_aclk						;	
	wire			[P_SRIO_DN_NUM_R*64-1	: 0]	srio_m_axis_tdata						;	
	wire			[P_SRIO_DN_NUM_R*4-1	: 0]	srio_m_axis_tid							;	
	wire			[P_SRIO_DN_NUM_R*1-1	: 0]	srio_m_axis_tready						;	
	wire			[P_SRIO_DN_NUM_R*1-1	: 0]	srio_m_axis_tvalid						;	
	wire			[P_SRIO_DN_NUM_R*8-1	: 0]	srio_m_axis_tstrb						;	
	wire			[P_SRIO_DN_NUM_R*8-1	: 0]	srio_m_axis_tkeep						;	
	wire			[P_SRIO_DN_NUM_R*1-1	: 0]	srio_m_axis_tlast						;	
	wire			[P_SRIO_DN_NUM_R*64-1	: 0]	srio_m_axis_tuser						;	
	wire			[P_SRIO_DN_NUM_R*4-1	: 0]	srio_m_axis_tdest						;	

//==================================================================================================
//--Signals Define------------------------------
	reg											rst_n		= 'b0				;	
	wire											lock						;	
	wire                  clk_200m            ;      
wire                  clk_125m            ;      

  	wire				s_axis_aclk	  ; 

	assign             clk_125m            = s_axis_aclk                       ;
  clk_dcm      u_dcm(
      	.clk_out1								( clk_200m								),
    	.clk_out2								( s_axis_aclk								),
    	
     	.locked								   	( lock								    ),

    	.clk_in1								( ps_sys_clk									)//
    	//.clk_in1_n								( sys_clk_n									)
    ); 
    wire  		ddr_rst                 	= lock                                    ;
    
assign  V_LUT_AXI_clk           = s_axis_aclk                         ;

     sync_nrst i_sync_user_nrst(
        .rst_n                      			( lock                  			              ),
        .clk                        			( V_LUT_AXI_clk             				      ),
        .sync_rst_n                 			( V_LUT_AXI_rstn        				          )
    );	
    
//==================================================================================================
//ddr����ź�
	wire										ddr_sys_clk_i								;
	wire										ddr_clk_ref_i								;
	wire										ddr_init_calib_complete						; 	
        
    assign			    ddr_sys_clk_i			= clk_200m									;
    assign			    ddr_clk_ref_i			= clk_200m									;	
//==================================================================================================
//--Master AXI4д�ӿ�
	wire		[3:0]							M_AXI_AWID									;
	wire		[31:0]							M_AXI_AWADDR								;
	wire		[7:0]							M_AXI_AWLEN									;
	wire		[2:0]							M_AXI_AWSIZE								;
	wire		[1:0]							M_AXI_AWBURST								;
	wire										M_AXI_AWLOCK								;
	wire		[3:0]							M_AXI_AWCACHE								;
	wire		[2:0]							M_AXI_AWPROT								;
	wire		[3:0]							M_AXI_AWQOS									;
	wire										M_AXI_AWVALID								;
	wire										M_AXI_AWREADY								;
	wire		[63:0]							M_AXI_WDATA									;
	wire		[7:0]							M_AXI_WSTRB									;
	wire										M_AXI_WLAST									;
	wire										M_AXI_WVALID								;
	wire										M_AXI_WREADY								;
	wire		[3:0]							M_AXI_BID									;
	wire		[1:0]							M_AXI_BRESP									;
	wire										M_AXI_BVALID								;
	wire										M_AXI_BREADY								;

	wire		[ 3:0]							M_AXI_ARID									;
	wire		[31:0]							M_AXI_ARADDR								;
	wire		[ 7:0]							M_AXI_ARLEN									;
	wire		[ 2:0]							M_AXI_ARSIZE								;
	wire		[ 1:0]							M_AXI_ARBURST								;
	wire										M_AXI_ARLOCK								;
	wire		[ 3:0]							M_AXI_ARCACHE								;
	wire		[ 2:0]							M_AXI_ARPROT								;
	wire		[ 3:0]							M_AXI_ARQOS									;
	wire										M_AXI_ARVALID								;
	wire										M_AXI_ARREADY								;

	wire		[ 3:0]							M_AXI_RID									;
	wire		[63:0]							M_AXI_RDATA									;
	wire		[ 1:0]							M_AXI_RRESP									;
	wire										M_AXI_RLAST									;
	wire										M_AXI_RVALID								;
	wire										M_AXI_RREADY								;    
    
    
    reg [31:0]  time_cnt        = 'b0       ;
    
	always @(posedge s_axis_aclk ) begin
		if(time_cnt<(100*200-1)) begin
			time_cnt							<= time_cnt + 1								;
			rst_n								<= 1'b0										;	
			
					
		end else begin
			time_cnt							<= time_cnt										;
			rst_n								<= 1'b1										;			
		end
	end

//	vio_gen_tx	#(
//		.P_SYS_CLK_FREQ								( P_SYS_CLK_FREQ							),
//		.P_D_BYTES								( (64)/8								)
//	)	vio_ch0_gen_tx(
//		.clk									( s_axis_aclk								),	
//		.rst									( ~rst_n									),
//		.r_run_trig								( 1'b0											),	
						
//		.tx_tdat								( srio_m_axis_tdata		[0*64 +: 64]		),	
//		.tx_tlen								( srio_m_axis_tuser		[0*64 +: 64]		),	
//		.tx_tlast								( srio_m_axis_tlast		[0*01 +: 01]		),	
		
//		.tx_tvalid								( srio_m_axis_tvalid	[0*01 +: 01]		),	
//		.tx_tready      						( srio_m_axis_tready	[0*01 +: 01]	   	));


	assign	srio_m_axis_tvalid	[0*01 +: 01]	= 1'b0									;




//	localparam		P_SRIO_UP_NUM_R				= 3											;	//max:8
//	localparam		P_SRIO_DN_NUM_R				= 2											;	

//	wire			[P_SRIO_UP_NUM_R*1-1	: 0]	srio_s_axis_aclk						;	
//	wire			[P_SRIO_UP_NUM_R*64-1 	: 0]	srio_s_axis_tdata						;	
//	wire			[P_SRIO_UP_NUM_R*4-1  	: 0]	srio_s_axis_tid							;	
//	wire			[P_SRIO_UP_NUM_R*1-1	: 0]	srio_s_axis_tready						;	
//	wire			[P_SRIO_UP_NUM_R*1-1	: 0]	srio_s_axis_tvalid						;	
//	wire			[P_SRIO_UP_NUM_R*8-1	: 0]	srio_s_axis_tstrb						;	
//	wire			[P_SRIO_UP_NUM_R*8-1	: 0]	srio_s_axis_tkeep						;	
//	wire			[P_SRIO_UP_NUM_R*1-1	: 0]	srio_s_axis_tlast						;	
//	wire			[P_SRIO_UP_NUM_R*64-1	: 0]	srio_s_axis_tuser						;	
//	wire			[P_SRIO_UP_NUM_R*4-1	: 0]	srio_s_axis_tdest						;	


//	/*--------------------------------------------------------------------------------------
//	--SRIOͨ������ AXI Stream�ӿ�
//	--------------------------------------------------------------------------------------*/

//	wire			[P_SRIO_DN_NUM_R*1-1	: 0]	srio_m_axis_aclk						;	
//	wire			[P_SRIO_DN_NUM_R*64-1	: 0]	srio_m_axis_tdata						;	
//	wire			[P_SRIO_DN_NUM_R*4-1	: 0]	srio_m_axis_tid							;	
//	wire			[P_SRIO_DN_NUM_R*1-1	: 0]	srio_m_axis_tready						;	
//	wire			[P_SRIO_DN_NUM_R*1-1	: 0]	srio_m_axis_tvalid						;	
//	wire			[P_SRIO_DN_NUM_R*8-1	: 0]	srio_m_axis_tstrb						;	
//	wire			[P_SRIO_DN_NUM_R*8-1	: 0]	srio_m_axis_tkeep						;	
//	wire			[P_SRIO_DN_NUM_R*1-1	: 0]	srio_m_axis_tlast						;	
//	wire			[P_SRIO_DN_NUM_R*64-1	: 0]	srio_m_axis_tuser						;	
//	wire			[P_SRIO_DN_NUM_R*4-1	: 0]	srio_m_axis_tdest						;	

    assign			srio_s_axis_aclk					= {P_SRIO_UP_NUM_R{s_axis_aclk}}				;

    assign			srio_m_axis_aclk					= {P_SRIO_DN_NUM_R{s_axis_aclk}}				;


	srio_top	srio_top(
			.V_LUT_AXI_clk			    					( V_LUT_AXI_clk							),		
		.V_LUT_AXI_rstn		    					( V_LUT_AXI_rstn		    				), 	
	
		.V_LUT_AXI_ARID			    					( V_LUT_AXI_ARID							),		
		.V_LUT_AXI_ARADDR		    					( V_LUT_AXI_ARADDR		    				),		
		.V_LUT_AXI_ARLEN								( V_LUT_AXI_ARLEN							),		
		.V_LUT_AXI_ARSIZE		    					( V_LUT_AXI_ARSIZE		    				),		
		.V_LUT_AXI_ARBURST		    					( V_LUT_AXI_ARBURST		    				),		
		.V_LUT_AXI_ARLOCK		    					( V_LUT_AXI_ARLOCK		    				),		
		.V_LUT_AXI_ARCACHE		    					( V_LUT_AXI_ARCACHE		    				),		
		.V_LUT_AXI_ARPROT		    					( V_LUT_AXI_ARPROT		    				),		
		.V_LUT_AXI_ARQOS								( V_LUT_AXI_ARQOS							),		
		.V_LUT_AXI_ARVALID		    					( V_LUT_AXI_ARVALID		    				),		
		.V_LUT_AXI_ARREADY		    					( V_LUT_AXI_ARREADY		    				),		
		.V_LUT_AXI_RID			    					( V_LUT_AXI_RID			    				),		
		.V_LUT_AXI_RDATA								( V_LUT_AXI_RDATA							),		
		.V_LUT_AXI_RRESP								( V_LUT_AXI_RRESP							),		
		.V_LUT_AXI_RLAST								( V_LUT_AXI_RLAST							),		
		.V_LUT_AXI_RVALID		    					( V_LUT_AXI_RVALID		    				),		
		.V_LUT_AXI_RREADY		    					( V_LUT_AXI_RREADY		    				),		


		.srio_vx1_r_axis_aclk					( srio_vx1_r_axis_aclk						),			
		.srio_vx1_r_axis_tready					( srio_vx1_r_axis_tready					),	
		.srio_vx1_r_axis_tdata					( srio_vx1_r_axis_tdata						),		
		.srio_vx1_r_axis_tvalid					( srio_vx1_r_axis_tvalid					),	
		.srio_vx1_r_axis_tlast					( srio_vx1_r_axis_tlast						),		
		.srio_vx1_r_axis_tuser					( srio_vx1_r_axis_tuser						),	
	                                            
		.srio_v_sid_did							( srio_v_sid_did							),
	`ifdef D_SEL_only_video
		.srio_v_sel_x1							( 0								),	 
		.ps_video_en							( 1								),
		.ps_frame_ctr							( 8'h04								),
	`else
		.srio_v_sel_x1							( srio_v_sel_x1								),	 
		.ps_video_en							( ps_video_en								),
		.ps_frame_ctr							( ps_frame_ctr								),
	`endif	

		.user_250m_clk							( user_250m_clk								),

		.slave_clk								( s_axis_aclk								),	
		.pcie_clk								( s_axis_aclk								),	
		.flash_clk								( s_axis_aclk								),	

		.sys_rst_n								( rst_n										),	

		.srio_sys_clk_p							( srio_sys_clk_p							),	
		.srio_sys_clk_n							( srio_sys_clk_n							),	

		.srio_rxn0								( srio_rxn0									),	
		.srio_rxp0								( srio_rxp0									),	
		.srio_txn0								( srio_txn0									),	
		.srio_txp0								( srio_txp0									),	

		.dma_s_axis_aclk						( srio_s_axis_aclk							),	

		.dma_s_axis_tdata						( srio_s_axis_tdata							),	
		.dma_s_axis_tid							( srio_s_axis_tid							),	
		.dma_s_axis_tready						( srio_s_axis_tready						),	
		.dma_s_axis_tvalid						( srio_s_axis_tvalid						),	
		.dma_s_axis_tstrb						( srio_s_axis_tstrb							),	
		.dma_s_axis_tkeep						( srio_s_axis_tkeep							),	
		.dma_s_axis_tlast						( srio_s_axis_tlast							),	
		.dma_s_axis_tuser						( srio_s_axis_tuser							),	
		.dma_s_axis_tdest						( srio_s_axis_tdest							),	

		.dma_m_axis_aclk						( srio_m_axis_aclk							),	

		.dma_m_axis_tdata						( srio_m_axis_tdata							),	
		.dma_m_axis_tid							( srio_m_axis_tid							),	
		.dma_m_axis_tready						( srio_m_axis_tready						),	
		.dma_m_axis_tvalid						( srio_m_axis_tvalid						),	
		.dma_m_axis_tstrb						( srio_m_axis_tstrb							),	
		.dma_m_axis_tkeep						( srio_m_axis_tkeep							),	
		.dma_m_axis_tlast						( srio_m_axis_tlast							),	
		.dma_m_axis_tuser						( srio_m_axis_tuser							),	
		.dma_m_axis_tdest						( srio_m_axis_tdest							),
		
		
		.slave_axi_awaddr						(0						),
		.slave_axi_awprot						( 							),
		.slave_axi_awvalid						( 0							),
		.slave_axi_awready						( 							),
		.slave_axi_wdata						( 							),
		.slave_axi_wstrb						( 							),
		.slave_axi_wvalid						( 0							),
		.slave_axi_wready						( 							),
		.slave_axi_bresp						( 							),
		.slave_axi_bvalid						( 						),
		.slave_axi_bready						( 							),
		.slave_axi_araddr						( 							),
		.slave_axi_arprot						( 							),
		.slave_axi_arvalid						( 0							),
		.slave_axi_arready						( 							),
		.slave_axi_rdata						( 							),
		.slave_axi_rresp						( 							),
		.slave_axi_rvalid						( 						),
		.slave_axi_rready						( 1'b1							)	,
		
		
		.MLVDS_AXI_ARID							( M_AXI_ARID							),	
		.MLVDS_AXI_ARADDR						( M_AXI_ARADDR							),	
		.MLVDS_AXI_ARLEN						( M_AXI_ARLEN							),	
		.MLVDS_AXI_ARSIZE						( M_AXI_ARSIZE							),	
		.MLVDS_AXI_ARBURST						( M_AXI_ARBURST							),	
		.MLVDS_AXI_ARLOCK						( M_AXI_ARLOCK							),	
		.MLVDS_AXI_ARCACHE						( M_AXI_ARCACHE							),	
		.MLVDS_AXI_ARPROT						( M_AXI_ARPROT							),	
		.MLVDS_AXI_ARQOS						( M_AXI_ARQOS							),	
		.MLVDS_AXI_ARVALID						( M_AXI_ARVALID							),	
		.MLVDS_AXI_ARREADY						( M_AXI_ARREADY							),	
		.MLVDS_AXI_RID							( M_AXI_RID								),	
		.MLVDS_AXI_RDATA						( M_AXI_RDATA							),	
		.MLVDS_AXI_RRESP						( M_AXI_RRESP							),	
		.MLVDS_AXI_RLAST						( M_AXI_RLAST							),	
		.MLVDS_AXI_RVALID						( M_AXI_RVALID							),	
		.MLVDS_AXI_RREADY						( M_AXI_RREADY							),	

		.MLVDS_AXI_AWID							( M_AXI_AWID							),	
		.MLVDS_AXI_AWADDR						( M_AXI_AWADDR							),	
		.MLVDS_AXI_AWLEN						( M_AXI_AWLEN							),	
		.MLVDS_AXI_AWSIZE						( M_AXI_AWSIZE							),	
		.MLVDS_AXI_AWBURST						( M_AXI_AWBURST							),	
		.MLVDS_AXI_AWLOCK						( M_AXI_AWLOCK							),	
		.MLVDS_AXI_AWCACHE						( M_AXI_AWCACHE							),	
		.MLVDS_AXI_AWPROT						( M_AXI_AWPROT							),	
		.MLVDS_AXI_AWQOS						( M_AXI_AWQOS							),	
		.MLVDS_AXI_AWVALID						( M_AXI_AWVALID							),	
		.MLVDS_AXI_AWREADY						( M_AXI_AWREADY							),	
		.MLVDS_AXI_WDATA						( M_AXI_WDATA							),	
		.MLVDS_AXI_WSTRB						( M_AXI_WSTRB							),	
		.MLVDS_AXI_WLAST						( M_AXI_WLAST							),	
		.MLVDS_AXI_WVALID						( M_AXI_WVALID							),	
		.MLVDS_AXI_WREADY						( M_AXI_WREADY							),	
		.MLVDS_AXI_BID							( M_AXI_BID								),	
		.MLVDS_AXI_BRESP						( M_AXI_BRESP							),	
		.MLVDS_AXI_BVALID						( M_AXI_BVALID							),	
		.MLVDS_AXI_BREADY						( M_AXI_BREADY							)		

	);

	wire			[63:0]						srio_r0_axis_tuser		= srio_s_axis_tuser[0*64 +: 64] ;	
	wire			[63:0]						srio_r0_axis_tdata		= srio_s_axis_tdata[0*64 +: 64] ;	
	wire			[00:0]						srio_r0_axis_tvalid		= srio_s_axis_tvalid[0*01 +: 01] ;	
	wire			[00:0]						srio_r0_axis_tlast		= srio_s_axis_tlast[0*01 +: 01] ;	

	wire			[63:0]						srio_r1_axis_tuser		= srio_s_axis_tuser[1*64 +: 64] ;	
	wire			[63:0]						srio_r1_axis_tdata		= srio_s_axis_tdata[1*64 +: 64] ;	
	wire			[00:0]						srio_r1_axis_tvalid		= srio_s_axis_tvalid[1*01 +: 01] ;	
	wire			[00:0]						srio_r1_axis_tlast		= srio_s_axis_tlast[1*01 +: 01] ;	
 
	wire			[63:0]						srio_r2_axis_tuser		= srio_s_axis_tuser[2*64 +: 64] ;	
	wire			[63:0]						srio_r2_axis_tdata		= srio_s_axis_tdata[2*64 +: 64] ;	
	wire			[00:0]						srio_r2_axis_tvalid		= srio_s_axis_tvalid[2*01 +: 01] ;	
	wire			[00:0]						srio_r2_axis_tlast		= srio_s_axis_tlast[2*01 +: 01] ;	

	assign	srio_s_axis_tready	[1*01 +: 01]	= 1'b1									;
	assign	srio_s_axis_tready	[2*01 +: 01]	= 1'b1									;

//	data_bit16_check	check_r_srio0(
//		.clk									( s_axis_aclk								),	
//        .rst                                  	( ~rst_n                                     ), 
                                                                                               
//		.rx_dat									( srio_s_axis_tdata			[0*64 +: 64]	),	
//        //.s_axis_tuser                           ( srio_s_axis_tuser		[0*64 +: 64]		), 
//		.rx_en									( srio_s_axis_tvalid		[0*01 +: 01]&srio_s_axis_tready[0*01 +: 01] ),	
//		.rx_last								( srio_s_axis_tlast     [0*01 +: 01]		));

//	vio_gen_tx	#(
//			.P_SYS_CLK_FREQ								( P_SYS_CLK_FREQ							),

//		.P_D_BYTES								( (64)/8								)
//	)	vio_ch1_gen_tx(
//		.clk									( s_axis_aclk								),	
//		.rst									( ~rst_n									),
//		.r_run_trig								( 											),	
						
//		.tx_tdat								( srio_m_axis_tdata		[1*64 +: 64]		),	
//		.tx_tlen								( srio_m_axis_tuser		[1*64 +: 64]		),	
//		.tx_tlast								( srio_m_axis_tlast		[1*01 +: 01]		),	
		                                                                 
//		.tx_tvalid								( srio_m_axis_tvalid	[1*01 +: 01]		),	
//		.tx_tready      						( srio_m_axis_tready	[1*01 +: 01]	   	));

        
	assign	srio_m_axis_tvalid	[1*01 +: 01]	= 1'b0									;
	assign	srio_s_axis_tready	[0*01 +: 01]	= 1'b1									;


//		assign			srio_m_axis_tdata		[1*64 +: 64]	=	srio_s_axis_tdata			[0*64 +: 64]	;
		
//		assign			srio_m_axis_tuser		[1*64 +: 64]	=	srio_s_axis_tuser			[0*64 +: 64]	;

//		assign			srio_m_axis_tvalid		[1*01 +: 01]	=	srio_s_axis_tvalid			[0*01 +: 01]	;
//		assign			srio_m_axis_tlast		[1*01 +: 01]	=	srio_s_axis_tlast			[0*01 +: 01]	;
		
//		assign	srio_s_axis_tready	[0*01 +: 01]	= srio_m_axis_tready	[1*01 +: 01]								;


//	data_bit16_check	check_r_srio1(
//		.clk									( s_axis_aclk								),	
//        .rst                                  	( ~rst_n                                     ), 
                                                                                               
//		.rx_dat									( srio_s_axis_tdata			[1*64 +: 64]	),	
//        //.s_axis_tuser                           ( srio_s_axis_tuser		[1*64 +: 64]		), 
//		.rx_en									( srio_s_axis_tvalid		[1*01 +: 01]&srio_s_axis_tready[1*01 +: 01] ),	
//		.rx_last								( srio_s_axis_tlast     [1*01 +: 01]		));
		
//		wire	srio0_port_error							= srio_top.srio_port_error			[0* 1+: 1]		;
//		wire	srio0_port_initialized						= srio_top.srio_port_initialized		[0* 1+: 1]		;
//		wire	srio0_link_initialized						= srio_top.srio_link_initialized		[0* 1+: 1]		;
//		wire	srio0_mode_1x								= srio_top.srio_mode_1x				[0* 1+: 1]		;
                                                            
//		wire	srio1_port_error							= srio_top.srio_port_error			[1* 1+: 1]		;
//		wire	srio1_port_initialized						= srio_top.srio_port_initialized		[1* 1+: 1]		;
//		wire	srio1_link_initialized						= srio_top.srio_link_initialized		[1* 1+: 1]		;
//		wire	srio1_mode_1x								= srio_top.srio_mode_1x				[1* 1+: 1]		;


//	assign	srio_s_axis_tready	[0*01 +: 01]	= 1'b1									;
//	assign	srio_s_axis_tready	[1*01 +: 01]	= 1'b1									;
//	assign	srio_s_axis_tready	[2*01 +: 01]	= 1'b1									;

		wire	srio0_port_error							= srio_top.srio_port_error			[0* 1+: 1]		;
		wire	srio0_port_initialized						= srio_top.srio_port_initialized		[0* 1+: 1]		;
		wire	srio0_link_initialized						= srio_top.srio_link_initialized		[0* 1+: 1]		;
		wire	srio0_mode_1x								= srio_top.srio_mode_1x				[0* 1+: 1]		;
                                                            
		wire	srio1_port_error							= srio_top.srio_port_error			[1* 1+: 1]		;
		wire	srio1_port_initialized						= srio_top.srio_port_initialized		[1* 1+: 1]		;
		wire	srio1_link_initialized						= srio_top.srio_link_initialized		[1* 1+: 1]		;
		wire	srio1_mode_1x								= srio_top.srio_mode_1x				[1* 1+: 1]		;

    wire   [15:0]     fre_calu_in       ;
    wire   [31:0]     s_detect_fre      ;
    wire   [ 3:0]     vio_ctrl_clk_calc ;

//    vio_0 u_vio_clk_fre(
//        .clk                ( s_axis_aclk                     ),
//        .probe_in0          ( {srio0_port_error,srio0_port_initialized,srio0_link_initialized,srio1_port_error,srio1_port_initialized,srio1_link_initialized,srio1_mode_1x,srio0_mode_1x,s_detect_fre,ddr_init_calib_complete}                 ),     
//              .probe_in1         ( device_temp            ),
      
//        .probe_out0         ( vio_ctrl_clk_calc            )
//      );
      

//     clk_calc_mul_chan #(
//        .DETECT_CLK_FRE     ( P_SYS_CLK_FREQ                 ),//���ʱ��
//        .CLK_CHAN           ( 16                           ) //֧��ͨ����
//        )
//      u_freq_calc_top(
//        .I_rst              ( 1'b0                         ),
//        .I_clk_detect       ( s_axis_aclk                     ), //���ʱ��
//        .I_clk_in           ( {srio_top.gt_pcs_clk,srio_top.drpclk,srio_top.refclk,srio_top.phy_clk,srio_top.gt_clk,srio_top.log_clk,user_250m_clk}                  ), //������ʱ��
//        .I_fre_detect_chan  ( vio_ctrl_clk_calc[3:0]           ),//(vio_ctrl_clk_calc[3:0]       ),
//        .O_clk_cnt          ( s_detect_fre                 )
//    );
	
                                    
	MY_MEM u_mem	(
 		.device_temp_i								( device_temp									),
//===============================================================================================
//--DDR�ⲿ�ӿ�
 		.DDR3_addr								( ddr3_addr									),
		.DDR3_ba								( ddr3_ba									),
		.DDR3_cas_n								( ddr3_cas_n								),
		.DDR3_ck_n								( ddr3_ck_n									),
		.DDR3_ck_p								( ddr3_ck_p									),
		.DDR3_cke								( ddr3_cke									),
		.DDR3_cs_n								( ddr3_cs_n									),
		.DDR3_dm								( ddr3_dm									),
		.DDR3_dq								( ddr3_dq									),
		.DDR3_dqs_n								( ddr3_dqs_n								),
		.DDR3_dqs_p								( ddr3_dqs_p								),
		.DDR3_odt								( ddr3_odt									),
		.DDR3_ras_n								( ddr3_ras_n								),
		.DDR3_reset_n							( ddr3_reset_n								),
		.DDR3_we_n								( ddr3_we_n									),
    	.init_calib_complete					( ddr_init_calib_complete					),
//===============================================================================================
//--ddr�ź�
  		.ddr_sys_clk_i							( ddr_sys_clk_i								),
    	.ddr_clk_ref_i							( ddr_clk_ref_i								),

        .axi_sys_clk							( clk_125m									),
        .axi_sys_rst							( rst_n										),
        .ddr_rst								( ddr_rst										),

	//ch0
 		.S00_AXI_araddr							( M_AXI_ARADDR								),
        .S00_AXI_arburst						( M_AXI_ARBURST								),
        .S00_AXI_arcache						( M_AXI_ARCACHE								),
        .S00_AXI_arid							( M_AXI_ARID								),
        .S00_AXI_arlen							( M_AXI_ARLEN								),
        .S00_AXI_arlock							( M_AXI_ARLOCK								),
        .S00_AXI_arprot							( M_AXI_ARPROT								),
//      .S00_AXI_arqos							( M_AXI_ARQOS								),
        .S00_AXI_arready						( M_AXI_ARREADY								),
        .S00_AXI_arsize							( M_AXI_ARSIZE								),
        .S00_AXI_arvalid						( M_AXI_ARVALID								),
        .S00_AXI_rid							( M_AXI_RID									),
        .S00_AXI_rlast							( M_AXI_RLAST								),
        .S00_AXI_rready							( M_AXI_RREADY								),
        .S00_AXI_rresp							( M_AXI_RRESP								),
        .S00_AXI_rvalid							( M_AXI_RVALID								),
        .S00_AXI_rdata							( M_AXI_RDATA								),

        .S00_AXI_awaddr							( M_AXI_AWADDR								),
        .S00_AXI_awburst						( M_AXI_AWBURST								),
        .S00_AXI_awcache						( M_AXI_AWCACHE								),
        .S00_AXI_awid							( M_AXI_AWID								),
        .S00_AXI_awlen							( M_AXI_AWLEN								),
        .S00_AXI_awlock							( M_AXI_AWLOCK								),
        .S00_AXI_awprot							( M_AXI_AWPROT								),
//      .S00_AXI_awqos							( M_AXI_AWQOS								),
        .S00_AXI_awready						( M_AXI_AWREADY								),
        .S00_AXI_awsize							( M_AXI_AWSIZE								),
        .S00_AXI_awvalid						( M_AXI_AWVALID								),
        .S00_AXI_bid							( M_AXI_BID									),
        .S00_AXI_bready							( M_AXI_BREADY								),
        .S00_AXI_bresp							( M_AXI_BRESP								),
        .S00_AXI_bvalid							( M_AXI_BVALID								),
        .S00_AXI_wdata							( M_AXI_WDATA								),
        .S00_AXI_wlast							( M_AXI_WLAST								),
        .S00_AXI_wready							( M_AXI_WREADY								),
        .S00_AXI_wstrb							( M_AXI_WSTRB								),
        .S00_AXI_wvalid							( M_AXI_WVALID								)

       // .S00_AXI_arregion						( 0											),
		//.S00_AXI_awregion						( 0											),
	);
		
	
endmodule

