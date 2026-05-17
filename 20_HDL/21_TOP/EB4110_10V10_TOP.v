`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:		XJKJ
// Engineer:	ZYL
//
// Create Date: 2021/6/15 12:27:15
// Design Name:
// Module Name: IR2120_NT_top.v
// Project Name: LTIR21_2030.V10_NT2_TOP
// Target Devices:  xc7k325tffg676-2(FDV)
// Tool Versions:	Vivado 2020.2
// Description:
//		IR2120 NT2 top
//	Interface: 1-HDLC 2-LVDS 3-RS485 4-Dual 2 Port Swtich
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// Additional Cominit_ments:
/*
问题[Common 17-576] 'use_project_ipc' is deprecated. This option is deprecated and no longer used.
  取消以上警告，先输入下一行的tcl命令，再重新编译IP。也可以选择更新到VIVADO2020.2以上版本
  set_msg_config -id {[Common 17-576]} -limit 0

 source C:/JFM_Kits/ip_patch/run.tcl
 add_hook_tcl_to_prj
 pre_synthesis_patch
 
 出现
 Not OOC IPs: MY_MEM_mig_7series_0_0 zynq_processing_system7_0_0 zynq_xadc_wiz_1_0
sourcing script D:/SRIO_ZL/EB4110_PRJ/EB4110_FPGA_20260410_2/10_PRJ/ip_patch/synthesis_pre.tcl failed
需要，reset_project
   
*/
//////////////////////////////////////////////////////////////////////////////////

module EB4110_10V10_TOP	#(
	parameter		PRJ_TIME					= 32'h20260207								,	
	parameter		PRJ_VERSION					= 32'h01000000								,	

	parameter		UP_CHANNEL					= 4											,	//max:8
	parameter		DN_CHANNEL					= 3											,	

	parameter		WEB_ZONE					= 16'h0										,	

	parameter		C_S_AXI_ID_WIDTH			= 6											,	
	parameter		C_S_AXI_ADDR_WIDTH			= 32										,	
	parameter		C_S_AXI_DATA_WIDTH			= 64											
	)(
	`ifndef    D_SEL_only_video
//==================================================================================================
//--Port declarations
	/*--------------------------------------------------------------------------------------
	--reset&clock input=================
	--------------------------------------------------------------------------------------*/
	/*--------------------------------------------------------------------------------------
	--Serdes interface
	--------------------------------------------------------------------------------------*/
	output										eMMC_RSTN									,	
	input										eMMC_DS										,	


	input										gtxrefclk110_p								,	
	input										gtxrefclk110_n								,	

	output			[2-1:0]						fc_gt_txp									,	//8 port 1000base-x
	output			[2-1:0]						fc_gt_txn									,	//
	input			[2-1:0]						fc_gt_rxp									,	//
	input			[2-1:0]						fc_gt_rxn									,	//

/*--------------------------------------------------------------------------------------
--LM75a IIC Temprature
--------------------------------------------------------------------------------------*/
	output	wire								rs422_tx_out_1								,	
    input	wire								rs422_rx_in_1 								,
	output	wire								rs422_tx_out_2								,	
    input	wire								rs422_rx_in_2 								,
	output	wire								rs422_tx_out_3								,	
    input	wire								rs422_rx_in_3 								,
	output	wire								rs422_tx_out_4								,	
    input	wire								rs422_rx_in_4								,
  
	output	wire								rs422_tx_out_5								,	
    input	wire								rs422_rx_in_5 								,   
	output	wire								rs422_tx_out_6								,	
    input	wire								rs422_rx_in_6								,   

    output	wire								rs422_ten_5								,   

    output	wire								rs422_ten_6								,   

	inout [14:0]DDR_0_addr,
  inout [2:0]DDR_0_ba,
  inout DDR_0_cas_n,
  inout DDR_0_ck_n,
  inout DDR_0_ck_p,
  inout DDR_0_cke,
  inout DDR_0_cs_n,
  inout [3:0]DDR_0_dm,
  inout [31:0]DDR_0_dq,
  inout [3:0]DDR_0_dqs_n,
  inout [3:0]DDR_0_dqs_p,
  inout DDR_0_odt,
  inout DDR_0_ras_n,
  inout DDR_0_reset_n,
  inout DDR_0_we_n,


  inout FIXED_IO_0_ddr_vrn,
  inout FIXED_IO_0_ddr_vrp,
  inout [53:0]FIXED_IO_0_mio,
  inout FIXED_IO_0_ps_clk,
  inout FIXED_IO_0_ps_porb,
  inout FIXED_IO_0_ps_srstb,
  
  inout ds18_dq0,
  inout ds18_dq1,

	inout			[2-1:0]						XP1_GPIO									,
`endif

	input										VP											,
	input										VN                                          ,
//视频srio
//	input										sys_clk_n									,
//	input										sys_clk_p									,
	
	input										gtxrefclk109_p								,	
	input										gtxrefclk109_n								,	
	
	input			[4-1:0]						video_srio_rxn0								,
	input			[4-1:0]						video_srio_rxp0								,
	output			[4-1:0]						video_srio_txn0								,
	output			[4-1:0]						video_srio_txp0								,

    inout   		[63:0]     					ddr3_dq             						,   //ddr3 数据
    inout   		[7:0]      					ddr3_dqs_n          						,   //ddr3 dqs负
    inout   		[7:0]      					ddr3_dqs_p          						,   //ddr3 dqs正  
	output			[14:0]						ddr3_addr									,	//ddr3 地址   
	output			[2:0]						ddr3_ba										,	//ddr3 banck 选择
	output										ddr3_ras_n									,	//ddr3 行选择
	output										ddr3_cas_n									,	//ddr3 列选择
	output										ddr3_we_n									,	//ddr3 读写选择
	output										ddr3_reset_n								,	//ddr3 复位
	output			[0:0]						ddr3_ck_p									,	//ddr3 时钟正
	output			[0:0]						ddr3_ck_n									,	//ddr3 时钟负
	output			[0:0]						ddr3_cke									,	//ddr3 时钟使能
	output			[0:0]						ddr3_cs_n									,	//ddr3 片选
	output			[7:0]						ddr3_dm										,	//ddr3_dm
	output			[0:0]						ddr3_odt										//,    //ddr3_odt    
	);                                       
	
	wire										srio_vx1_r_axis_aclk							;
	wire										srio_vx1_r_axis_tready								;
	wire			[64-1:0] 					srio_vx1_r_axis_tdata								;
	wire										srio_vx1_r_axis_tvalid								;
	wire										srio_vx1_r_axis_tlast								;
	wire			[32-1:0] 					srio_vx1_r_axis_tuser								;	
	
  	wire			[31:0]						srio_v_sid_did								; 
  	wire										srio_v_sel_x1								;      
    
	wire										ps_video_en									;	
	wire			[7:0]						ps_frame_ctr								;	
	
	wire			[31:0]						S_AXI_1_araddr								;
	wire			[1:0]						S_AXI_1_arburst								;
	wire			[3:0]						S_AXI_1_arcache								;
	wire			[7:0]						S_AXI_1_arlen								;
	wire			[0:0]						S_AXI_1_arlock								;
	wire			[2:0]						S_AXI_1_arprot								;
	wire			[3:0]						S_AXI_1_arqos								;
	wire										S_AXI_1_arready								;
	wire			[3:0]						S_AXI_1_arregion							;
	wire			[2:0]						S_AXI_1_arsize								;
	wire										S_AXI_1_arvalid								;
	wire			[31:0]						S_AXI_1_awaddr								;
	wire			[1:0]						S_AXI_1_awburst								;
	wire			[3:0]						S_AXI_1_awcache								;
	wire			[7:0]						S_AXI_1_awlen								;
	wire			[0:0]						S_AXI_1_awlock								;
	wire			[2:0]						S_AXI_1_awprot								;
	wire			[3:0]						S_AXI_1_awqos								;
	wire										S_AXI_1_awready								;
	wire			[3:0]						S_AXI_1_awregion							;
	wire			[2:0]						S_AXI_1_awsize								;
	wire										S_AXI_1_awvalid								;
	wire										S_AXI_1_bready								;
	wire			[1:0]						S_AXI_1_bresp								;
	wire										S_AXI_1_bvalid								;
	wire			[63:0]						S_AXI_1_rdata								;
	wire										S_AXI_1_rlast								;
	wire										S_AXI_1_rready								;
	wire			[1:0]						S_AXI_1_rresp								;
	wire										S_AXI_1_rvalid								;
	wire			[63:0]						S_AXI_1_wdata								;
	wire										S_AXI_1_wlast								;
	wire										S_AXI_1_wready								;
	wire			[7:0]						S_AXI_1_wstrb								;
	wire										S_AXI_1_wvalid								;	
	wire			[15:0]						device_temp								;
		wire										ps_sys_clk									;
wire										ps_reset								;
wire										V_LUT_AXI_clk								;
wire										V_LUT_AXI_rstn								;
	srio_test_prj_top	srio_video_loop(              
	`ifndef    D_SEL_only_video
			.device_temp					( device_temp				),
	
		.V_LUT_AXI_rstn		    					( V_LUT_AXI_rstn    				),		
		.V_LUT_AXI_clk		    					( V_LUT_AXI_clk		    				),		

		.V_LUT_AXI_ARADDR		    					( S_AXI_1_araddr		    				),		
		.V_LUT_AXI_ARLEN								( S_AXI_1_arlen							),		
		.V_LUT_AXI_ARSIZE		    					( S_AXI_1_arregion		    				),		
		.V_LUT_AXI_ARBURST		    					( S_AXI_1_arburst		    				),		
		.V_LUT_AXI_ARLOCK		    					( S_AXI_1_arlock		    				),		
		.V_LUT_AXI_ARCACHE		    					( S_AXI_1_arcache		    				),		
		.V_LUT_AXI_ARPROT		    					( S_AXI_1_arprot		    				),		
		.V_LUT_AXI_ARQOS								( S_AXI_1_arqos							),		
		.V_LUT_AXI_ARVALID		    					( S_AXI_1_arvalid		    				),		
		.V_LUT_AXI_ARREADY		    					( S_AXI_1_arready		    				),		
		.V_LUT_AXI_RDATA								( S_AXI_1_rdata							),		
		.V_LUT_AXI_RRESP								( S_AXI_1_rresp							),		
		.V_LUT_AXI_RLAST								( S_AXI_1_rlast							),		
		.V_LUT_AXI_RVALID		    					( S_AXI_1_rvalid		    				),		
		.V_LUT_AXI_RREADY		    					( S_AXI_1_rready		    				),

		.srio_vx1_r_axis_aclk						( srio_vx1_r_axis_aclk					),		
		.srio_vx1_r_axis_tready						( srio_vx1_r_axis_tready					),	
		.srio_vx1_r_axis_tdata						( srio_vx1_r_axis_tdata						),		
		.srio_vx1_r_axis_tvalid						( srio_vx1_r_axis_tvalid					),	
		.srio_vx1_r_axis_tlast						( srio_vx1_r_axis_tlast						),		
		.srio_vx1_r_axis_tuser						( srio_vx1_r_axis_tuser						),	


	
		.ps_video_en							( ps_video_en								),	
		.ps_frame_ctr							( ps_frame_ctr								),	
                                        
		.srio_v_sid_did							( srio_v_sid_did								),	
		.srio_v_sel_x1							( srio_v_sel_x1								),	                                        
                                        
  `endif
		.VP										( VP										),	
		.VN										( VN										),	

//		.sys_clk_n								( sys_clk_n									),	
//		.sys_clk_p								( sys_clk_p									),	

		.ps_sys_clk							( ps_sys_clk							),	

		.srio_sys_clk_p							( gtxrefclk109_p							),	
		.srio_sys_clk_n							( gtxrefclk109_n							),	

		.srio_rxn0								( video_srio_rxn0							),	
		.srio_rxp0								( video_srio_rxp0							),	
		.srio_txn0								( video_srio_txn0							),	
		.srio_txp0								( video_srio_txp0							),	


		.ddr3_addr								( ddr3_addr									),	
		.ddr3_ba								( ddr3_ba									),	
		.ddr3_cas_n								( ddr3_cas_n								),	
		.ddr3_ck_n								( ddr3_ck_n									),	
		.ddr3_ck_p								( ddr3_ck_p									),	
		.ddr3_cke								( ddr3_cke									),	
		.ddr3_cs_n								( ddr3_cs_n									),	
		.ddr3_dm								( ddr3_dm									),	
		.ddr3_dq								( ddr3_dq									),	
		.ddr3_dqs_n								( ddr3_dqs_n								),	
		.ddr3_dqs_p								( ddr3_dqs_p								),	
		.ddr3_odt								( ddr3_odt									),	
		.ddr3_ras_n								( ddr3_ras_n								),	
		.ddr3_reset_n							( ddr3_reset_n								),	
		.ddr3_we_n								( ddr3_we_n									)	

	);
	`ifndef    D_SEL_only_video

    assign          eMMC_RSTN       = 1'b1          ;


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
	--SRIO通道下行 AXI Stream接口
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

    assign			srio_s_axis_aclk					= {P_SRIO_UP_NUM_R{ps_sys_clk}}				;

    assign			srio_m_axis_aclk					= {P_SRIO_DN_NUM_R{ps_sys_clk}}				;

	/*--------------------------------------------------------------------------------------
	--SRIO通道下行 AXI Stream接口
	--------------------------------------------------------------------------------------*/

	wire			[1*64-1:0]					loop_m_axis_tdata							;
	wire			[1*4-1:0]					loop_m_axis_tid								;
	wire			[1*1-1:0]					loop_m_axis_tready							;
	wire			[1*1-1:0]					loop_m_axis_tvalid							;
	wire			[1*8-1:0]					loop_m_axis_tstrb							;
	wire			[1*8-1:0]					loop_m_axis_tkeep							;
	wire			[1*1-1:0]					loop_m_axis_tlast							;
	wire			[1*64-1:0]					loop_m_axis_tuser							;
	wire			[1*4-1:0]					loop_m_axis_tdest							;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//																														//
//Param                  Param defines																					//
//																														//
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//==================================================================================================
//--Internal Cross Bar for Power Loding/Initi/SNMP/Flash etc..
	/*--------------------------------------------------------------------------------------
	--axil_bus_cross output
	--------------------------------------------------------------------------------------*/
  	//---Write Address Channel Signals
	wire			[512/16-1:0]				dma_axi_awaddr								;
	wire			[48/16-1:0]					dma_axi_awprot								;
	wire			[16/16-1:0]					dma_axi_awvalid								;
	wire			[16/16-1:0]					dma_axi_awready								;
  	//---Write Data Channel Signals
	wire			[512/16-1:0]				dma_axi_wdata								;
	wire			[512/8/16-1:0]				dma_axi_wstrb								;
	wire			[16/16-1:0]					dma_axi_wvalid								;
	wire			[16/16-1:0]					dma_axi_wready								;
  	//---Write Response Channel Signals
	wire			[32/16-1:0]					dma_axi_bresp								;
	wire			[16/16-1:0]					dma_axi_bvalid								;
	wire			[16/16-1:0]					dma_axi_bready								;
  	//---Read Address Channel Signals
	wire			[512/16-1:0]				dma_axi_araddr								;
	wire			[48/16-1:0]					dma_axi_arprot								;
	wire			[16/16-1:0]					dma_axi_arvalid								;
	wire			[16/16-1:0]					dma_axi_arready								;
  	//---Read Data Channel Signals
	wire			[512/16-1:0]				dma_axi_rdata								;
	wire			[32/16-1:0]					dma_axi_rresp								;
	wire			[16/16-1:0]					dma_axi_rvalid								;
	wire			[16/16-1:0]					dma_axi_rready								;

	wire			[31:0]						S_AXI_0_araddr								;
	wire			[1:0]						S_AXI_0_arburst								;
	wire			[3:0]						S_AXI_0_arcache								;
	wire			[7:0]						S_AXI_0_arlen								;
	wire			[0:0]						S_AXI_0_arlock								;
	wire			[2:0]						S_AXI_0_arprot								;
	wire			[3:0]						S_AXI_0_arqos								;
	wire										S_AXI_0_arready								;
	wire			[3:0]						S_AXI_0_arregion							;
	wire			[2:0]						S_AXI_0_arsize								;
	wire										S_AXI_0_arvalid								;
	wire			[31:0]						S_AXI_0_awaddr								;
	wire			[1:0]						S_AXI_0_awburst								;
	wire			[3:0]						S_AXI_0_awcache								;
	wire			[7:0]						S_AXI_0_awlen								;
	wire			[0:0]						S_AXI_0_awlock								;
	wire			[2:0]						S_AXI_0_awprot								;
	wire			[3:0]						S_AXI_0_awqos								;
	wire										S_AXI_0_awready								;
	wire			[3:0]						S_AXI_0_awregion							;
	wire			[2:0]						S_AXI_0_awsize								;
	wire										S_AXI_0_awvalid								;
	wire										S_AXI_0_bready								;
	wire			[1:0]						S_AXI_0_bresp								;
	wire										S_AXI_0_bvalid								;
	wire			[63:0]						S_AXI_0_rdata								;
	wire										S_AXI_0_rlast								;
	wire										S_AXI_0_rready								;
	wire			[1:0]						S_AXI_0_rresp								;
	wire										S_AXI_0_rvalid								;
	wire			[63:0]						S_AXI_0_wdata								;
	wire										S_AXI_0_wlast								;
	wire										S_AXI_0_wready								;
	wire			[7:0]						S_AXI_0_wstrb								;
	wire										S_AXI_0_wvalid								;




	wire			[0:0]						peripheral_reset_0							;
   // uart   sys_uart_1

	wire			[31:0]						sys_uart_1_axi_awaddr						;
	wire			[2:0]						sys_uart_1_axi_awprot						;
	wire										sys_uart_1_axi_awvalid						;
	wire										sys_uart_1_axi_awready						;

     /*--------------------------------------------------------------------------------------
     --Write Data Channel Signals
     --------------------------------------------------------------------------------------*/
	wire			[31:0]						sys_uart_1_axi_wdata						;
	wire			[3:0]						sys_uart_1_axi_wstrb						;
	wire										sys_uart_1_axi_wvalid						;
	wire										sys_uart_1_axi_wready						;

     /*--------------------------------------------------------------------------------------
     --Write Response Channel Signals
     --------------------------------------------------------------------------------------*/
	wire			[1:0]						sys_uart_1_axi_bresp						;
	wire										sys_uart_1_axi_bvalid						;
	wire										sys_uart_1_axi_bready						;
     /*--------------------------------------------------------------------------------------
     --Read Address Channel Signals
     --------------------------------------------------------------------------------------*/
	wire			[31:0]						sys_uart_1_axi_araddr						;
	wire			[2:0]						sys_uart_1_axi_arprot						;
	wire										sys_uart_1_axi_arvalid						;
	wire										sys_uart_1_axi_arready						;

     /*--------------------------------------------------------------------------------------
     --Read Address Channel Signals
     --------------------------------------------------------------------------------------*/
	wire			[31:0]						sys_uart_1_axi_rdata						;
	wire			[1:0]						sys_uart_1_axi_rresp						;
	wire										sys_uart_1_axi_rvalid						;
	wire										sys_uart_1_axi_rready						;


    // uart   sys_uart_2
	wire			[31:0]						sys_uart_2_axi_awaddr						;
	wire			[2:0]						sys_uart_2_axi_awprot						;
	wire										sys_uart_2_axi_awvalid						;
	wire										sys_uart_2_axi_awready						;

     /*--------------------------------------------------------------------------------------
     --Write Data Channel Signals
     --------------------------------------------------------------------------------------*/
	wire			[31:0]						sys_uart_2_axi_wdata						;
	wire			[3:0]						sys_uart_2_axi_wstrb						;
	wire										sys_uart_2_axi_wvalid						;
	wire										sys_uart_2_axi_wready						;

     /*--------------------------------------------------------------------------------------
     --Write Response Channel Signals
     --------------------------------------------------------------------------------------*/
	wire			[1:0]						sys_uart_2_axi_bresp						;
	wire										sys_uart_2_axi_bvalid						;
	wire										sys_uart_2_axi_bready						;
     /*--------------------------------------------------------------------------------------
     --Read Address Channel Signals
     --------------------------------------------------------------------------------------*/
	wire			[31:0]						sys_uart_2_axi_araddr						;
	wire			[2:0]						sys_uart_2_axi_arprot						;
	wire										sys_uart_2_axi_arvalid						;
	wire										sys_uart_2_axi_arready						;

     /*--------------------------------------------------------------------------------------
     --Read Address Channel Signals
     --------------------------------------------------------------------------------------*/
	wire			[31:0]						sys_uart_2_axi_rdata						;
	wire			[1:0]						sys_uart_2_axi_rresp						;
	wire										sys_uart_2_axi_rvalid						;
	wire										sys_uart_2_axi_rready						;


    // uart   sys_uart_3
	wire			[31:0]						sys_uart_3_axi_awaddr						;
	wire			[2:0]						sys_uart_3_axi_awprot						;
	wire										sys_uart_3_axi_awvalid						;
	wire										sys_uart_3_axi_awready						;

     /*--------------------------------------------------------------------------------------
     --Write Data Channel Signals
     --------------------------------------------------------------------------------------*/
	wire			[31:0]						sys_uart_3_axi_wdata						;
	wire			[3:0]						sys_uart_3_axi_wstrb						;
	wire										sys_uart_3_axi_wvalid						;
	wire										sys_uart_3_axi_wready						;

     /*--------------------------------------------------------------------------------------
     --Write Response Channel Signals
     --------------------------------------------------------------------------------------*/
	wire			[1:0]						sys_uart_3_axi_bresp						;
	wire										sys_uart_3_axi_bvalid						;
	wire										sys_uart_3_axi_bready						;
     /*--------------------------------------------------------------------------------------
     --Read Address Channel Signals
     --------------------------------------------------------------------------------------*/
	wire			[31:0]						sys_uart_3_axi_araddr						;
	wire			[2:0]						sys_uart_3_axi_arprot						;
	wire										sys_uart_3_axi_arvalid						;
	wire										sys_uart_3_axi_arready						;

     /*--------------------------------------------------------------------------------------
     --Read Address Channel Signals
     --------------------------------------------------------------------------------------*/
	wire			[31:0]						sys_uart_3_axi_rdata						;
	wire			[1:0]						sys_uart_3_axi_rresp						;
	wire										sys_uart_3_axi_rvalid						;
	wire										sys_uart_3_axi_rready						;

    // uart   sys_uart_4
	wire			[31:0]						sys_uart_4_axi_awaddr						;
	wire			[2:0]						sys_uart_4_axi_awprot						;
	wire										sys_uart_4_axi_awvalid						;
	wire										sys_uart_4_axi_awready						;
	wire			[31:0]						sys_uart_4_axi_wdata						;
	wire			[3:0]						sys_uart_4_axi_wstrb						;
	wire										sys_uart_4_axi_wvalid						;
	wire										sys_uart_4_axi_wready						;
	wire			[1:0]						sys_uart_4_axi_bresp						;
	wire										sys_uart_4_axi_bvalid						;
	wire										sys_uart_4_axi_bready						;
	wire			[31:0]						sys_uart_4_axi_araddr						;
	wire			[2:0]						sys_uart_4_axi_arprot						;
	wire										sys_uart_4_axi_arvalid						;
	wire										sys_uart_4_axi_arready						;
	wire			[31:0]						sys_uart_4_axi_rdata						;
	wire			[1:0]						sys_uart_4_axi_rresp						;
	wire										sys_uart_4_axi_rvalid						;
	wire										sys_uart_4_axi_rready						;

	wire			[31:0]						sys_uart_5_axi_awaddr						;
	wire			[2:0]						sys_uart_5_axi_awprot						;
	wire										sys_uart_5_axi_awvalid						;
	wire										sys_uart_5_axi_awready						;
	wire			[31:0]						sys_uart_5_axi_wdata						;
	wire			[3:0]						sys_uart_5_axi_wstrb						;
	wire										sys_uart_5_axi_wvalid						;
	wire										sys_uart_5_axi_wready						;
	wire			[1:0]						sys_uart_5_axi_bresp						;
	wire										sys_uart_5_axi_bvalid						;
	wire										sys_uart_5_axi_bready						;
	wire			[31:0]						sys_uart_5_axi_araddr						;
	wire			[2:0]						sys_uart_5_axi_arprot						;
	wire										sys_uart_5_axi_arvalid						;
	wire										sys_uart_5_axi_arready						;
	wire			[31:0]						sys_uart_5_axi_rdata						;
	wire			[1:0]						sys_uart_5_axi_rresp						;
	wire										sys_uart_5_axi_rvalid						;
	wire										sys_uart_5_axi_rready						;
	
	wire			[31:0]						sys_uart_6_axi_awaddr						;
	wire			[2:0]						sys_uart_6_axi_awprot						;
	wire										sys_uart_6_axi_awvalid						;
	wire										sys_uart_6_axi_awready						;
	wire			[31:0]						sys_uart_6_axi_wdata						;
	wire			[3:0]						sys_uart_6_axi_wstrb						;
	wire										sys_uart_6_axi_wvalid						;
	wire										sys_uart_6_axi_wready						;
	wire			[1:0]						sys_uart_6_axi_bresp						;
	wire										sys_uart_6_axi_bvalid						;
	wire										sys_uart_6_axi_bready						;
	wire			[31:0]						sys_uart_6_axi_araddr						;
	wire			[2:0]						sys_uart_6_axi_arprot						;
	wire										sys_uart_6_axi_arvalid						;
	wire										sys_uart_6_axi_arready						;
	wire			[31:0]						sys_uart_6_axi_rdata						;
	wire			[1:0]						sys_uart_6_axi_rresp						;
	wire										sys_uart_6_axi_rvalid						;
	wire										sys_uart_6_axi_rready						;	


          // uart   sys_uart_4
	wire			[31:0]						srio_axi_awaddr								;
	wire			[2:0]						srio_axi_awprot								;
	wire										srio_axi_awvalid							;
	wire										srio_axi_awready							;
	wire			[31:0]						srio_axi_wdata								;
	wire			[3:0]						srio_axi_wstrb								;
	wire										srio_axi_wvalid								;
	wire										srio_axi_wready								;
	wire			[1:0]						srio_axi_bresp								;
	wire										srio_axi_bvalid								;
	wire										srio_axi_bready								;
	wire			[31:0]						srio_axi_araddr								;
	wire			[2:0]						srio_axi_arprot								;
	wire										srio_axi_arvalid							;
	wire										srio_axi_arready							;
	wire			[31:0]						srio_axi_rdata								;
	wire			[1:0]						srio_axi_rresp								;
	wire										srio_axi_rvalid								;
	wire										srio_axi_rready								;

          // uart   
	wire			[31:0]						USER_axi_awaddr								;
	wire			[2:0]						USER_axi_awprot								;
	wire										USER_axi_awvalid							;
	wire										USER_axi_awready							;
	wire			[31:0]						USER_axi_wdata								;
	wire			[3:0]						USER_axi_wstrb								;
	wire										USER_axi_wvalid								;
	wire										USER_axi_wready								;
	wire			[1:0]						USER_axi_bresp								;
	wire										USER_axi_bvalid								;
	wire										USER_axi_bready								;
	wire			[31:0]						USER_axi_araddr								;
	wire			[2:0]						USER_axi_arprot								;
	wire										USER_axi_arvalid							;
	wire										USER_axi_arready							;
	wire			[31:0]						USER_axi_rdata								;
	wire			[1:0]						USER_axi_rresp								;
	wire										USER_axi_rvalid								;
	wire										USER_axi_rready								;

//==================================================================================================
//--APP user logic instance
//==================================================================================================
//--app_top Instantation
	wire			[15:0]						inter_rupt									;
	wire										up_package_int								;
	
	

	wire										axi_clk										;
 	assign			axi_clk						=			ps_sys_clk						;
	wire 										rs422_int_1,rs422_int_2,rs422_int_3,rs422_int_4,rs422_int_5,rs422_int_6;
	wire			[31:0]						reg_int_test								;

	assign inter_rupt = {1'b0,reg_int_test[3:0],~rs422_int_6,~rs422_int_5,~rs422_int_4,~rs422_int_3,~rs422_int_2, ~rs422_int_1,up_package_int};



	wire			[1:0]						XP1_GPIO_tri_i								;	
	wire			[1:0]						XP1_GPIO_tri_o								;	
	wire			[1:0]						XP1_GPIO_tri_t								;	
	IOBUF	gpio_0_iobuf
       (.I(XP1_GPIO_tri_o[0]),
		.IO										( XP1_GPIO					[0]				),	
		.O										( XP1_GPIO_tri_i			[0]				),	
        .T(XP1_GPIO_tri_t[0]));

	IOBUF	gpio_1_iobuf
       (.I(XP1_GPIO_tri_o[1]),
		.IO										( XP1_GPIO					[1]				),	
		.O										( XP1_GPIO_tri_i			[1]				),	
        .T(XP1_GPIO_tri_t[1]));
	zynq	zynq_i(
		.XP1_GPIO_tri_o							( XP1_GPIO_tri_o							),	
		.XP1_GPIO_tri_i							( XP1_GPIO_tri_i							),	
		.XP1_GPIO_tri_t							( XP1_GPIO_tri_t							),	

		.DDR_0_addr								( DDR_0_addr								),
		.DDR_0_ba								( DDR_0_ba									),
		.DDR_0_cas_n							( DDR_0_cas_n								),
		.DDR_0_ck_n								( DDR_0_ck_n								),
		.DDR_0_ck_p								( DDR_0_ck_p								),
		.DDR_0_cke								( DDR_0_cke									),
		.DDR_0_cs_n								( DDR_0_cs_n								),
		.DDR_0_dm								( DDR_0_dm									),
		.DDR_0_dq								( DDR_0_dq									),
		.DDR_0_dqs_n							( DDR_0_dqs_n								),
		.DDR_0_dqs_p							( DDR_0_dqs_p								),
		.DDR_0_odt								( DDR_0_odt									),
		.DDR_0_ras_n							( DDR_0_ras_n								),
		.DDR_0_reset_n							( DDR_0_reset_n								),
		.DDR_0_we_n								( DDR_0_we_n								),

		.FCLK_CLK0_0							( ps_sys_clk								),

		.FIXED_IO_0_ddr_vrn						( FIXED_IO_0_ddr_vrn						),
		.FIXED_IO_0_ddr_vrp						( FIXED_IO_0_ddr_vrp						),
		.FIXED_IO_0_mio							( FIXED_IO_0_mio							),
		.FIXED_IO_0_ps_clk						( FIXED_IO_0_ps_clk							),
		.FIXED_IO_0_ps_porb						( FIXED_IO_0_ps_porb						),
		.FIXED_IO_0_ps_srstb					( FIXED_IO_0_ps_srstb						),

		.In0_0									( inter_rupt								),
		.M02_AXI_0_araddr						( sys_uart_1_axi_araddr						),
		.M02_AXI_0_arprot						( sys_uart_1_axi_arprot						),
		.M02_AXI_0_arready						( sys_uart_1_axi_arready					),
		.M02_AXI_0_arvalid						( sys_uart_1_axi_arvalid					),
		.M02_AXI_0_awaddr						( sys_uart_1_axi_awaddr						),
		.M02_AXI_0_awprot						( sys_uart_1_axi_awprot						),
		.M02_AXI_0_awready						( sys_uart_1_axi_awready					),
		.M02_AXI_0_awvalid						( sys_uart_1_axi_awvalid					),
		.M02_AXI_0_bready						( sys_uart_1_axi_bready						),
		.M02_AXI_0_bresp						( sys_uart_1_axi_bresp						),
		.M02_AXI_0_bvalid						( sys_uart_1_axi_bvalid						),
		.M02_AXI_0_rdata						( sys_uart_1_axi_rdata						),
		.M02_AXI_0_rready						( sys_uart_1_axi_rready						),
		.M02_AXI_0_rresp						( sys_uart_1_axi_rresp						),
		.M02_AXI_0_rvalid						( sys_uart_1_axi_rvalid						),
		.M02_AXI_0_wdata						( sys_uart_1_axi_wdata						),
		.M02_AXI_0_wready						( sys_uart_1_axi_wready						),
		.M02_AXI_0_wstrb						( sys_uart_1_axi_wstrb						),
		.M02_AXI_0_wvalid						( sys_uart_1_axi_wvalid						),


		.M03_AXI_0_araddr						( sys_uart_2_axi_araddr						),
		.M03_AXI_0_arprot						( sys_uart_2_axi_arprot						),
		.M03_AXI_0_arready						( sys_uart_2_axi_arready					),
		.M03_AXI_0_arvalid						( sys_uart_2_axi_arvalid					),
		.M03_AXI_0_awaddr						( sys_uart_2_axi_awaddr						),
		.M03_AXI_0_awprot						( sys_uart_2_axi_awprot						),
		.M03_AXI_0_awready						( sys_uart_2_axi_awready					),
		.M03_AXI_0_awvalid						( sys_uart_2_axi_awvalid					),
		.M03_AXI_0_bready						( sys_uart_2_axi_bready						),
		.M03_AXI_0_bresp						( sys_uart_2_axi_bresp						),
		.M03_AXI_0_bvalid						( sys_uart_2_axi_bvalid						),
		.M03_AXI_0_rdata						( sys_uart_2_axi_rdata						),
		.M03_AXI_0_rready						( sys_uart_2_axi_rready						),
		.M03_AXI_0_rresp						( sys_uart_2_axi_rresp						),
		.M03_AXI_0_rvalid						( sys_uart_2_axi_rvalid						),
		.M03_AXI_0_wdata						( sys_uart_2_axi_wdata						),
		.M03_AXI_0_wready						( sys_uart_2_axi_wready						),
		.M03_AXI_0_wstrb						( sys_uart_2_axi_wstrb						),
		.M03_AXI_0_wvalid						( sys_uart_2_axi_wvalid						),

		.M04_AXI_0_araddr						( sys_uart_3_axi_araddr						),
		.M04_AXI_0_arprot						( sys_uart_3_axi_arprot						),
		.M04_AXI_0_arready						( sys_uart_3_axi_arready					),
		.M04_AXI_0_arvalid						( sys_uart_3_axi_arvalid					),
		.M04_AXI_0_awaddr						( sys_uart_3_axi_awaddr						),
		.M04_AXI_0_awprot						( sys_uart_3_axi_awprot						),
		.M04_AXI_0_awready						( sys_uart_3_axi_awready					),
		.M04_AXI_0_awvalid						( sys_uart_3_axi_awvalid					),
		.M04_AXI_0_bready						( sys_uart_3_axi_bready						),
		.M04_AXI_0_bresp						( sys_uart_3_axi_bresp						),
		.M04_AXI_0_bvalid						( sys_uart_3_axi_bvalid						),
		.M04_AXI_0_rdata						( sys_uart_3_axi_rdata						),
		.M04_AXI_0_rready						( sys_uart_3_axi_rready						),
		.M04_AXI_0_rresp						( sys_uart_3_axi_rresp						),
		.M04_AXI_0_rvalid						( sys_uart_3_axi_rvalid						),
		.M04_AXI_0_wdata						( sys_uart_3_axi_wdata						),
		.M04_AXI_0_wready						( sys_uart_3_axi_wready						),
		.M04_AXI_0_wstrb						( sys_uart_3_axi_wstrb						),
		.M04_AXI_0_wvalid						( sys_uart_3_axi_wvalid						),



		.M05_AXI_0_araddr						( sys_uart_4_axi_araddr						),
		.M05_AXI_0_arprot						( sys_uart_4_axi_arprot						),
		.M05_AXI_0_arready						( sys_uart_4_axi_arready					),
		.M05_AXI_0_arvalid						( sys_uart_4_axi_arvalid					),
		.M05_AXI_0_awaddr						( sys_uart_4_axi_awaddr						),
		.M05_AXI_0_awprot						( sys_uart_4_axi_awprot						),
		.M05_AXI_0_awready						( sys_uart_4_axi_awready					),
		.M05_AXI_0_awvalid						( sys_uart_4_axi_awvalid					),
		.M05_AXI_0_bready						( sys_uart_4_axi_bready						),
		.M05_AXI_0_bresp						( sys_uart_4_axi_bresp						),
		.M05_AXI_0_bvalid						( sys_uart_4_axi_bvalid						),
		.M05_AXI_0_rdata						( sys_uart_4_axi_rdata						),
		.M05_AXI_0_rready						( sys_uart_4_axi_rready						),
		.M05_AXI_0_rresp						( sys_uart_4_axi_rresp						),
		.M05_AXI_0_rvalid						( sys_uart_4_axi_rvalid						),
		.M05_AXI_0_wdata						( sys_uart_4_axi_wdata						),
		.M05_AXI_0_wready						( sys_uart_4_axi_wready						),
		.M05_AXI_0_wstrb						( sys_uart_4_axi_wstrb						),
		.M05_AXI_0_wvalid						( sys_uart_4_axi_wvalid						),

		.M06_AXI_0_araddr						( sys_uart_5_axi_araddr						), 
		.M06_AXI_0_arprot						( sys_uart_5_axi_arprot						), 
		.M06_AXI_0_arready						( sys_uart_5_axi_arready					), 
		.M06_AXI_0_arvalid						( sys_uart_5_axi_arvalid					), 
		.M06_AXI_0_awaddr						( sys_uart_5_axi_awaddr						), 
		.M06_AXI_0_awprot						( sys_uart_5_axi_awprot						), 
		.M06_AXI_0_awready						( sys_uart_5_axi_awready					), 
		.M06_AXI_0_awvalid						( sys_uart_5_axi_awvalid					), 
		.M06_AXI_0_bready						( sys_uart_5_axi_bready						), 
		.M06_AXI_0_bresp						( sys_uart_5_axi_bresp						), 
		.M06_AXI_0_bvalid						( sys_uart_5_axi_bvalid						), 
		.M06_AXI_0_rdata						( sys_uart_5_axi_rdata						), 
		.M06_AXI_0_rready						( sys_uart_5_axi_rready						), 
		.M06_AXI_0_rresp						( sys_uart_5_axi_rresp						), 
		.M06_AXI_0_rvalid						( sys_uart_5_axi_rvalid						), 
		.M06_AXI_0_wdata						( sys_uart_5_axi_wdata						), 
		.M06_AXI_0_wready						( sys_uart_5_axi_wready						), 
		.M06_AXI_0_wstrb						( sys_uart_5_axi_wstrb						), 
		.M06_AXI_0_wvalid						( sys_uart_5_axi_wvalid						), 

		.M07_AXI_0_araddr						( sys_uart_6_axi_araddr						), 
		.M07_AXI_0_arprot						( sys_uart_6_axi_arprot						), 
		.M07_AXI_0_arready						( sys_uart_6_axi_arready					), 
		.M07_AXI_0_arvalid						( sys_uart_6_axi_arvalid					), 
		.M07_AXI_0_awaddr						( sys_uart_6_axi_awaddr						), 
		.M07_AXI_0_awprot						( sys_uart_6_axi_awprot						), 
		.M07_AXI_0_awready						( sys_uart_6_axi_awready					), 
		.M07_AXI_0_awvalid						( sys_uart_6_axi_awvalid					), 
		.M07_AXI_0_bready						( sys_uart_6_axi_bready						), 
		.M07_AXI_0_bresp						( sys_uart_6_axi_bresp						), 
		.M07_AXI_0_bvalid						( sys_uart_6_axi_bvalid						), 
		.M07_AXI_0_rdata						( sys_uart_6_axi_rdata						), 
		.M07_AXI_0_rready						( sys_uart_6_axi_rready						), 
		.M07_AXI_0_rresp						( sys_uart_6_axi_rresp						), 
		.M07_AXI_0_rvalid						( sys_uart_6_axi_rvalid						), 
		.M07_AXI_0_wdata						( sys_uart_6_axi_wdata						), 
		.M07_AXI_0_wready						( sys_uart_6_axi_wready						), 
		.M07_AXI_0_wstrb						( sys_uart_6_axi_wstrb						), 
		.M07_AXI_0_wvalid						( sys_uart_6_axi_wvalid						), 



		.M08_AXI_0_araddr						( srio_axi_araddr							),
		.M08_AXI_0_arprot						( srio_axi_arprot							),
		.M08_AXI_0_arready						( srio_axi_arready							),
		.M08_AXI_0_arvalid						( srio_axi_arvalid							),
		.M08_AXI_0_awaddr						( srio_axi_awaddr							),
		.M08_AXI_0_awprot						( srio_axi_awprot							),
		.M08_AXI_0_awready						( srio_axi_awready							),
		.M08_AXI_0_awvalid						( srio_axi_awvalid							),
		.M08_AXI_0_bready						( srio_axi_bready							),
		.M08_AXI_0_bresp						( srio_axi_bresp							),
		.M08_AXI_0_bvalid						( srio_axi_bvalid							),
		.M08_AXI_0_rdata						( srio_axi_rdata							),
		.M08_AXI_0_rready						( srio_axi_rready							),
		.M08_AXI_0_rresp						( srio_axi_rresp							),
		.M08_AXI_0_rvalid						( srio_axi_rvalid							),
		.M08_AXI_0_wdata						( srio_axi_wdata							),
		.M08_AXI_0_wready						( srio_axi_wready							),
		.M08_AXI_0_wstrb						( srio_axi_wstrb							),
		.M08_AXI_0_wvalid						( srio_axi_wvalid							),

		.M_USER_AXI_araddr						( USER_axi_araddr							),
		.M_USER_AXI_arprot						( USER_axi_arprot							),
		.M_USER_AXI_arready						( USER_axi_arready							),
		.M_USER_AXI_arvalid						( USER_axi_arvalid							),
		.M_USER_AXI_awaddr						( USER_axi_awaddr							),
		.M_USER_AXI_awprot						( USER_axi_awprot							),
		.M_USER_AXI_awready						( USER_axi_awready							),
		.M_USER_AXI_awvalid						( USER_axi_awvalid							),
		.M_USER_AXI_bready						( USER_axi_bready							),
		.M_USER_AXI_bresp						( USER_axi_bresp							),
		.M_USER_AXI_bvalid						( USER_axi_bvalid							),
		.M_USER_AXI_rdata						( USER_axi_rdata							),
		.M_USER_AXI_rready						( USER_axi_rready							),
		.M_USER_AXI_rresp						( USER_axi_rresp							),
		.M_USER_AXI_rvalid						( USER_axi_rvalid							),
		.M_USER_AXI_wdata						( USER_axi_wdata							),
		.M_USER_AXI_wready						( USER_axi_wready							),
		.M_USER_AXI_wstrb						( USER_axi_wstrb							),
		.M_USER_AXI_wvalid						( USER_axi_wvalid							),


		.DMA_AXI_araddr							( dma_axi_araddr							),
		.DMA_AXI_arprot							( dma_axi_arprot							),
		.DMA_AXI_arready						( dma_axi_arready							),
		.DMA_AXI_arvalid						( dma_axi_arvalid							),
		.DMA_AXI_awaddr							( dma_axi_awaddr							),
		.DMA_AXI_awprot							( dma_axi_awprot							),
		.DMA_AXI_awready						( dma_axi_awready							),
		.DMA_AXI_awvalid						( dma_axi_awvalid							),
		.DMA_AXI_bready							( dma_axi_bready							),
		.DMA_AXI_bresp							( dma_axi_bresp								),
		.DMA_AXI_bvalid							( dma_axi_bvalid							),
		.DMA_AXI_rdata							( dma_axi_rdata								),
		.DMA_AXI_rready							( dma_axi_rready							),
		.DMA_AXI_rresp							( dma_axi_rresp								),
		.DMA_AXI_rvalid							( dma_axi_rvalid							),
		.DMA_AXI_wdata							( dma_axi_wdata								),
		.DMA_AXI_wready							( dma_axi_wready							),
		.DMA_AXI_wstrb							( dma_axi_wstrb								),
		.DMA_AXI_wvalid							( dma_axi_wvalid							),

		.S_AXI_0_araddr							( S_AXI_0_araddr							),
		.S_AXI_0_arburst						( S_AXI_0_arburst							),
		.S_AXI_0_arcache						( S_AXI_0_arcache							),
		.S_AXI_0_arlen							( S_AXI_0_arlen								),
		.S_AXI_0_arlock							( S_AXI_0_arlock							),
		.S_AXI_0_arprot							( S_AXI_0_arprot							),
		.S_AXI_0_arqos							( S_AXI_0_arqos								),
		.S_AXI_0_arready						( S_AXI_0_arready							),
		.S_AXI_0_arregion						( S_AXI_0_arregion							),
		.S_AXI_0_arsize							( S_AXI_0_arsize							),
		.S_AXI_0_arvalid						( S_AXI_0_arvalid							),
		.S_AXI_0_awaddr							( S_AXI_0_awaddr							),
		.S_AXI_0_awburst						( S_AXI_0_awburst							),
		.S_AXI_0_awcache						( S_AXI_0_awcache							),
		.S_AXI_0_awlen							( S_AXI_0_awlen								),
		.S_AXI_0_awlock							( S_AXI_0_awlock							),
		.S_AXI_0_awprot							( S_AXI_0_awprot							),
		.S_AXI_0_awqos							( S_AXI_0_awqos								),
		.S_AXI_0_awready						( S_AXI_0_awready							),
		.S_AXI_0_awregion						( S_AXI_0_awregion							),
		.S_AXI_0_awsize							( S_AXI_0_awsize							),
		.S_AXI_0_awvalid						( S_AXI_0_awvalid							),
		.S_AXI_0_bready							( S_AXI_0_bready							),
		.S_AXI_0_bresp							( S_AXI_0_bresp								),
		.S_AXI_0_bvalid							( S_AXI_0_bvalid							),
		.S_AXI_0_rdata							( S_AXI_0_rdata								),
		.S_AXI_0_rlast							( S_AXI_0_rlast								),
		.S_AXI_0_rready							( S_AXI_0_rready							),
		.S_AXI_0_rresp							( S_AXI_0_rresp								),
		.S_AXI_0_rvalid							( S_AXI_0_rvalid							),
		.S_AXI_0_wdata							( S_AXI_0_wdata								),
		.S_AXI_0_wlast							( S_AXI_0_wlast								),
		.S_AXI_0_wready							( S_AXI_0_wready							),
		.S_AXI_0_wstrb							( S_AXI_0_wstrb								),
		.S_AXI_0_wvalid							( S_AXI_0_wvalid							),


		.S_AXI_1_rstn		    					( V_LUT_AXI_rstn    				),		
		.S_AXI_1_clk		    					( V_LUT_AXI_clk		    				),	
		.S_AXI_1_araddr							( S_AXI_1_araddr							),
		.S_AXI_1_arburst						( S_AXI_1_arburst							),
		.S_AXI_1_arcache						( S_AXI_1_arcache							),
		.S_AXI_1_arlen							( S_AXI_1_arlen								),
		.S_AXI_1_arlock							( S_AXI_1_arlock							),
		.S_AXI_1_arprot							( S_AXI_1_arprot							),
		.S_AXI_1_arqos							( S_AXI_1_arqos								),
		.S_AXI_1_arready						( S_AXI_1_arready							),
		.S_AXI_1_arregion						( S_AXI_1_arregion							),
		.S_AXI_1_arsize							( S_AXI_1_arsize							),
		.S_AXI_1_arvalid						( S_AXI_1_arvalid							),
		.S_AXI_1_awaddr							( S_AXI_1_awaddr							),
		.S_AXI_1_awburst						( S_AXI_1_awburst							),
		.S_AXI_1_awcache						( S_AXI_1_awcache							),
		.S_AXI_1_awlen							( S_AXI_1_awlen								),
		.S_AXI_1_awlock							( S_AXI_1_awlock							),
		.S_AXI_1_awprot							( S_AXI_1_awprot							),
		.S_AXI_1_awqos							( S_AXI_1_awqos								),
		.S_AXI_1_awready						( S_AXI_1_awready							),
		.S_AXI_1_awregion						( S_AXI_1_awregion							),
		.S_AXI_1_awsize							( S_AXI_1_awsize							),
		.S_AXI_1_awvalid						( S_AXI_1_awvalid							),
		.S_AXI_1_bready							( S_AXI_1_bready							),
		.S_AXI_1_bresp							( S_AXI_1_bresp								),
		.S_AXI_1_bvalid							( S_AXI_1_bvalid							),
		.S_AXI_1_rdata							( S_AXI_1_rdata								),
		.S_AXI_1_rlast							( S_AXI_1_rlast								),
		.S_AXI_1_rready							( S_AXI_1_rready							),
		.S_AXI_1_rresp							( S_AXI_1_rresp								),
		.S_AXI_1_rvalid							( S_AXI_1_rvalid							),
		.S_AXI_1_wdata							( S_AXI_1_wdata								),
		.S_AXI_1_wlast							( S_AXI_1_wlast								),
		.S_AXI_1_wready							( S_AXI_1_wready							),
		.S_AXI_1_wstrb							( S_AXI_1_wstrb								),
		.S_AXI_1_wvalid							( S_AXI_1_wvalid							),


        .peripheral_reset_0						( ps_reset									));

	user_top	i_user(
		.int_test								( reg_int_test								),

		.axi_clk								( axi_clk									),
		.ps_reset								( ps_reset									),
		.rs422_tx_out_1							( rs422_tx_out_1							),
		.rs422_rx_in_1							( rs422_rx_in_1								),
		.rs422_int_1							( rs422_int_1								),

		.sys_uart_1_axi_araddr					( sys_uart_1_axi_araddr						),
		.sys_uart_1_axi_arprot					( sys_uart_1_axi_arprot						),
		.sys_uart_1_axi_arready					( sys_uart_1_axi_arready					),
		.sys_uart_1_axi_arvalid					( sys_uart_1_axi_arvalid					),

		.sys_uart_1_axi_awaddr					( sys_uart_1_axi_awaddr						),
		.sys_uart_1_axi_awprot					( sys_uart_1_axi_awprot						),
		.sys_uart_1_axi_awready					( sys_uart_1_axi_awready					),
		.sys_uart_1_axi_awvalid					( sys_uart_1_axi_awvalid					),

		.sys_uart_1_axi_bready					( sys_uart_1_axi_bready						),
		.sys_uart_1_axi_bresp					( sys_uart_1_axi_bresp						),
		.sys_uart_1_axi_bvalid					( sys_uart_1_axi_bvalid						),

		.sys_uart_1_axi_rdata					( sys_uart_1_axi_rdata						),
		.sys_uart_1_axi_rready					( sys_uart_1_axi_rready						),
		.sys_uart_1_axi_rresp					( sys_uart_1_axi_rresp						),
		.sys_uart_1_axi_rvalid					( sys_uart_1_axi_rvalid						),

		.sys_uart_1_axi_wdata					( sys_uart_1_axi_wdata						),
		.sys_uart_1_axi_wready					( sys_uart_1_axi_wready						),
		.sys_uart_1_axi_wstrb					( sys_uart_1_axi_wstrb						),
		.sys_uart_1_axi_wvalid					( sys_uart_1_axi_wvalid						),

		.rs422_tx_out_2							( rs422_tx_out_2							),
		.rs422_rx_in_2							( rs422_rx_in_2								),
		.rs422_int_2							( rs422_int_2								),

		.sys_uart_2_axi_araddr					( sys_uart_2_axi_araddr						),
		.sys_uart_2_axi_arprot					( sys_uart_2_axi_arprot						),
		.sys_uart_2_axi_arready					( sys_uart_2_axi_arready					),
		.sys_uart_2_axi_arvalid					( sys_uart_2_axi_arvalid					),

		.sys_uart_2_axi_awaddr					( sys_uart_2_axi_awaddr						),
		.sys_uart_2_axi_awprot					( sys_uart_2_axi_awprot						),
		.sys_uart_2_axi_awready					( sys_uart_2_axi_awready					),
		.sys_uart_2_axi_awvalid					( sys_uart_2_axi_awvalid					),

		.sys_uart_2_axi_bready					( sys_uart_2_axi_bready						),
		.sys_uart_2_axi_bresp					( sys_uart_2_axi_bresp						),
		.sys_uart_2_axi_bvalid					( sys_uart_2_axi_bvalid						),

		.sys_uart_2_axi_rdata					( sys_uart_2_axi_rdata						),
		.sys_uart_2_axi_rready					( sys_uart_2_axi_rready						),
		.sys_uart_2_axi_rresp					( sys_uart_2_axi_rresp						),
		.sys_uart_2_axi_rvalid					( sys_uart_2_axi_rvalid						),

		.sys_uart_2_axi_wdata					( sys_uart_2_axi_wdata						),
		.sys_uart_2_axi_wready					( sys_uart_2_axi_wready						),
		.sys_uart_2_axi_wstrb					( sys_uart_2_axi_wstrb						),
		.sys_uart_2_axi_wvalid					( sys_uart_2_axi_wvalid						),


		.rs422_tx_out_3							( rs422_tx_out_3							),
		.rs422_rx_in_3							( rs422_rx_in_3								),
		.rs422_int_3							( rs422_int_3								),

		.sys_uart_3_axi_araddr					( sys_uart_3_axi_araddr						),
		.sys_uart_3_axi_arprot					( sys_uart_3_axi_arprot						),
		.sys_uart_3_axi_arready					( sys_uart_3_axi_arready					),
		.sys_uart_3_axi_arvalid					( sys_uart_3_axi_arvalid					),

		.sys_uart_3_axi_awaddr					( sys_uart_3_axi_awaddr						),
		.sys_uart_3_axi_awprot					( sys_uart_3_axi_awprot						),
		.sys_uart_3_axi_awready					( sys_uart_3_axi_awready					),
		.sys_uart_3_axi_awvalid					( sys_uart_3_axi_awvalid					),

		.sys_uart_3_axi_bready					( sys_uart_3_axi_bready						),
		.sys_uart_3_axi_bresp					( sys_uart_3_axi_bresp						),
		.sys_uart_3_axi_bvalid					( sys_uart_3_axi_bvalid						),

		.sys_uart_3_axi_rdata					( sys_uart_3_axi_rdata						),
		.sys_uart_3_axi_rready					( sys_uart_3_axi_rready						),
		.sys_uart_3_axi_rresp					( sys_uart_3_axi_rresp						),
		.sys_uart_3_axi_rvalid					( sys_uart_3_axi_rvalid						),

		.sys_uart_3_axi_wdata					( sys_uart_3_axi_wdata						),
		.sys_uart_3_axi_wready					( sys_uart_3_axi_wready						),
		.sys_uart_3_axi_wstrb					( sys_uart_3_axi_wstrb						),
		.sys_uart_3_axi_wvalid					( sys_uart_3_axi_wvalid						),

		.rs422_tx_out_4							( rs422_tx_out_4							),
		.rs422_rx_in_4							( rs422_rx_in_4								),
		.rs422_int_4							( rs422_int_4								),

		.sys_uart_4_axi_araddr					( sys_uart_4_axi_araddr						),
		.sys_uart_4_axi_arprot					( sys_uart_4_axi_arprot						),
		.sys_uart_4_axi_arready					( sys_uart_4_axi_arready					),
		.sys_uart_4_axi_arvalid					( sys_uart_4_axi_arvalid					),
		.sys_uart_4_axi_awaddr					( sys_uart_4_axi_awaddr						),
		.sys_uart_4_axi_awprot					( sys_uart_4_axi_awprot						),
		.sys_uart_4_axi_awready					( sys_uart_4_axi_awready					),
		.sys_uart_4_axi_awvalid					( sys_uart_4_axi_awvalid					),
		.sys_uart_4_axi_bready					( sys_uart_4_axi_bready						),
		.sys_uart_4_axi_bresp					( sys_uart_4_axi_bresp						),
		.sys_uart_4_axi_bvalid					( sys_uart_4_axi_bvalid						),
		.sys_uart_4_axi_rdata					( sys_uart_4_axi_rdata						),
		.sys_uart_4_axi_rready					( sys_uart_4_axi_rready						),
		.sys_uart_4_axi_rresp					( sys_uart_4_axi_rresp						),
		.sys_uart_4_axi_rvalid					( sys_uart_4_axi_rvalid						),
		.sys_uart_4_axi_wdata					( sys_uart_4_axi_wdata						),
		.sys_uart_4_axi_wready					( sys_uart_4_axi_wready						),
		.sys_uart_4_axi_wstrb					( sys_uart_4_axi_wstrb						),
		.sys_uart_4_axi_wvalid					( sys_uart_4_axi_wvalid						),
		
		.rs422_tx_out_5							( rs422_tx_out_5							),
		.rs422_rx_in_5							( rs422_rx_in_5								),
		.rs422_int_5							( rs422_int_5								),
		.rs422_ten_5							( rs422_ten_5								),

		.sys_uart_5_axi_araddr					( sys_uart_5_axi_araddr						),
		.sys_uart_5_axi_arprot					( sys_uart_5_axi_arprot						),
		.sys_uart_5_axi_arready					( sys_uart_5_axi_arready					),
		.sys_uart_5_axi_arvalid					( sys_uart_5_axi_arvalid					),
		.sys_uart_5_axi_awaddr					( sys_uart_5_axi_awaddr						),
		.sys_uart_5_axi_awprot					( sys_uart_5_axi_awprot						),
		.sys_uart_5_axi_awready					( sys_uart_5_axi_awready					),
		.sys_uart_5_axi_awvalid					( sys_uart_5_axi_awvalid					),
		.sys_uart_5_axi_bready					( sys_uart_5_axi_bready						),
		.sys_uart_5_axi_bresp					( sys_uart_5_axi_bresp						),
		.sys_uart_5_axi_bvalid					( sys_uart_5_axi_bvalid						),
		.sys_uart_5_axi_rdata					( sys_uart_5_axi_rdata						),
		.sys_uart_5_axi_rready					( sys_uart_5_axi_rready						),
		.sys_uart_5_axi_rresp					( sys_uart_5_axi_rresp						),
		.sys_uart_5_axi_rvalid					( sys_uart_5_axi_rvalid						),
		.sys_uart_5_axi_wdata					( sys_uart_5_axi_wdata						),
		.sys_uart_5_axi_wready					( sys_uart_5_axi_wready						),
		.sys_uart_5_axi_wstrb					( sys_uart_5_axi_wstrb						),
		.sys_uart_5_axi_wvalid					( sys_uart_5_axi_wvalid						),
		
		.rs422_tx_out_6							( rs422_tx_out_6							),
		.rs422_rx_in_6							( rs422_rx_in_6								),
		.rs422_int_6							( rs422_int_6								),
		.rs422_ten_6							( rs422_ten_6								),


		.sys_uart_6_axi_araddr					( sys_uart_6_axi_araddr						),
		.sys_uart_6_axi_arprot					( sys_uart_6_axi_arprot						),
		.sys_uart_6_axi_arready					( sys_uart_6_axi_arready					),
		.sys_uart_6_axi_arvalid					( sys_uart_6_axi_arvalid					),
		.sys_uart_6_axi_awaddr					( sys_uart_6_axi_awaddr						),
		.sys_uart_6_axi_awprot					( sys_uart_6_axi_awprot						),
		.sys_uart_6_axi_awready					( sys_uart_6_axi_awready					),
		.sys_uart_6_axi_awvalid					( sys_uart_6_axi_awvalid					),
		.sys_uart_6_axi_bready					( sys_uart_6_axi_bready						),
		.sys_uart_6_axi_bresp					( sys_uart_6_axi_bresp						),
		.sys_uart_6_axi_bvalid					( sys_uart_6_axi_bvalid						),
		.sys_uart_6_axi_rdata					( sys_uart_6_axi_rdata						),
		.sys_uart_6_axi_rready					( sys_uart_6_axi_rready						),
		.sys_uart_6_axi_rresp					( sys_uart_6_axi_rresp						),
		.sys_uart_6_axi_rvalid					( sys_uart_6_axi_rvalid						),
		.sys_uart_6_axi_wdata					( sys_uart_6_axi_wdata						),
		.sys_uart_6_axi_wready					( sys_uart_6_axi_wready						),
		.sys_uart_6_axi_wstrb					( sys_uart_6_axi_wstrb						),
		.sys_uart_6_axi_wvalid					( sys_uart_6_axi_wvalid						)		
		
		
	);

//==================================================================================================
//
	web_dma_top	//#(
//		.PRJ_TIME								( PRJ_TIME									),
//		.PRJ_VERSION							( PRJ_VERSION								),

//		.DN_CHANNEL								( DN_CHANNEL								),
//		.UP_CHANNEL								( UP_CHANNEL								),

//		.WEB_ZONE								( WEB_ZONE									),

//		.C_S_AXI_ID_WIDTH						( C_S_AXI_ID_WIDTH							),
//		.C_S_AXI_ADDR_WIDTH						( C_S_AXI_ADDR_WIDTH						),
//		.C_S_AXI_DATA_WIDTH						( C_S_AXI_DATA_WIDTH						))
		web_dma_top_u(
		.clk									( ps_sys_clk								),
	.rst_n                  (~ps_reset					),// modify by hyf
		.package_int							( up_package_int							),	
//dn
	.axis_dn_clk			({ps_sys_clk		,srio_m_axis_aclk,ps_sys_clk,ps_sys_clk}			),
	.axis_dn_tready	        ({loop_m_axis_tready,srio_m_axis_tready}					),
	.axis_dn_tdata          ({loop_m_axis_tdata	,srio_m_axis_tdata}   			),
	.axis_dn_tid            (     			),
	.axis_dn_tvalid         ({loop_m_axis_tvalid,srio_m_axis_tvalid}  			),
	.axis_dn_tstrb          (   			),
	.axis_dn_tkeep          (   			),
	.axis_dn_tlast          ({loop_m_axis_tlast	,srio_m_axis_tlast}   			),
	.axis_dn_tuser          ({loop_m_axis_tuser	,srio_m_axis_tuser}   			),
	.axis_dn_tdest          (   			),

//up
	
	.axis_up_clk			({ps_sys_clk,srio_s_axis_aclk}					),
	.axis_up_tready	    	({loop_m_axis_tready,srio_s_axis_tready}					), //axis_up_tready
	.axis_up_tdata      	({loop_m_axis_tdata	,srio_s_axis_tdata}	   			), //axis_up_tdata
	.axis_up_tid        	(  16'h0   			), //axis_up_tid
	.axis_up_tvalid     	({loop_m_axis_tvalid,srio_s_axis_tvalid}	  			), //axis_up_tvalid
	.axis_up_tstrb      	(   32'h0 			), //axis_up_tstrb
	.axis_up_tkeep      	(   	0		), //axis_up_tkeep
	.axis_up_tlast      	({loop_m_axis_tlast	,srio_s_axis_tlast}	   			), //axis_up_tlast
	.axis_up_tuser      	({loop_m_axis_tuser	,srio_s_axis_tuser}	   			), //axis_up_tuser
	.axis_up_tdest  		( 16'h0  			), //axis_up_tdest

  //axi_lite_slaver
		.axi_slite_clk							( ps_sys_clk								),
		.axi_slite_awaddr						( dma_axi_awaddr							),
		.axi_slite_awprot						( dma_axi_awprot							),
		.axi_slite_awvalid						( dma_axi_awvalid							),
		.axi_slite_awready						( dma_axi_awready							),
		//--- Write Data Channel Signals                                    				
		.axi_slite_wdata						( dma_axi_wdata								),
		.axi_slite_wstrb						( dma_axi_wstrb								),
		.axi_slite_wvalid						( dma_axi_wvalid							),
		.axi_slite_wready						( dma_axi_wready							),
		//--- Write Response Channel Signals                                				
		.axi_slite_bresp						( dma_axi_bresp								),
		.axi_slite_bvalid						( dma_axi_bvalid							),
		.axi_slite_bready						( dma_axi_bready							),
		//--- Read Address Channel Signals                                  				
		.axi_slite_araddr						( dma_axi_araddr							),
		.axi_slite_arprot						( dma_axi_arprot							),
		.axi_slite_arvalid						( dma_axi_arvalid							),
		.axi_slite_arready						( dma_axi_arready							),
		//--- Read Data Channel Signals                                     				
		.axi_slite_rdata						( dma_axi_rdata								),
		.axi_slite_rresp						( dma_axi_rresp								),
		.axi_slite_rvalid						( dma_axi_rvalid							),
		.axi_slite_rready						( dma_axi_rready							),

  // AXI write address channel signals
  
		.axi_mhp_rd_bid							( 4'h0								),
		.axi_clk								( ps_sys_clk								),
		.axi_mhp_wready							( S_AXI_0_awvalid							),
		.axi_mhp_wid							( )											,
		.axi_mhp_waddr							( S_AXI_0_awaddr							),
		.axi_mhp_wlen							( S_AXI_0_awlen								),
		.axi_mhp_wsize							( S_AXI_0_awsize							),
		.axi_mhp_wburst							( S_AXI_0_awburst							),
		.axi_mhp_wlock							( S_AXI_0_awlock							),
		.axi_mhp_wcache							( S_AXI_0_awcache							),
		.axi_mhp_wprot							( S_AXI_0_awprot							),
		.axi_mhp_wvalid							( S_AXI_0_awvalid							),
		.axi_mhp_wqos							( S_AXI_0_awqos								),

  // AXI write data channel signals
		.axi_mhp_wd_wready						( S_AXI_0_wready							),
//  .axi_mhp_wd_wid          	(      						),
		.axi_mhp_wd_data						( S_AXI_0_wdata								),
		.axi_mhp_wd_strb						( S_AXI_0_wstrb								),
		.axi_mhp_wd_last						( S_AXI_0_wlast								),
		.axi_mhp_wd_valid						( S_AXI_0_wvalid							),

  // AXI write response channel signals
		.axi_mhp_wd_bid							( 0											),
		.axi_mhp_wd_bresp						( S_AXI_0_bresp								),
		.axi_mhp_wd_bvalid						( S_AXI_0_bvalid							),
		.axi_mhp_wd_bready						( S_AXI_0_bready							),

  // AXI read address channel signals
		.axi_mhp_rready							( S_AXI_0_arready							),
		.axi_mhp_rid							( )											,
		.axi_mhp_raddr							( S_AXI_0_araddr							),
		.axi_mhp_rlen							( S_AXI_0_arlen								),
		.axi_mhp_rsize							( S_AXI_0_arsize							),
		.axi_mhp_rburst							( S_AXI_0_arburst							),


		.axi_mhp_rlock							( S_AXI_0_arlock							),
		.axi_mhp_rcache							( S_AXI_0_arcache							),
		.axi_mhp_rprot							( S_AXI_0_arprot							),
		.axi_mhp_rvalid							( S_AXI_0_arvalid							),
		.axi_mhp_rqos							( S_AXI_0_arqos								),

  // AXI read data channel signals
	//	.axi_mhp_rd_bid							( )											,
		.axi_mhp_rd_rresp						( S_AXI_0_rresp								),
		.axi_mhp_rd_rvalid						( S_AXI_0_rvalid							),
		.axi_mhp_rd_data						( S_AXI_0_rdata								),
		.axi_mhp_rd_last						( S_AXI_0_rlast								),
		.axi_mhp_rd_rready						( S_AXI_0_rready							)
	);


	xr2000_top_AT01_TOP
	u_xr2000_top_AT01_TOP (
	
			.srio_vx1_r_axis_aclk						( srio_vx1_r_axis_aclk					),		

		.srio_vx1_r_axis_tready						( srio_vx1_r_axis_tready					),	
		.srio_vx1_r_axis_tdata						( srio_vx1_r_axis_tdata						),		
		.srio_vx1_r_axis_tvalid						( srio_vx1_r_axis_tvalid					),	
		.srio_vx1_r_axis_tlast						( srio_vx1_r_axis_tlast						),		
		.srio_vx1_r_axis_tuser						( srio_vx1_r_axis_tuser						),		
	
		.slave_clk								( ps_sys_clk								),
		.pcie_clk								( ps_sys_clk								),
		.flash_clk								( ps_sys_clk								),

		.sys_rst_n								( ~ps_reset								),


		.srio_sys_clk_p							( gtxrefclk110_p							),
		.srio_sys_clk_n							( gtxrefclk110_n							),


		.srio_rxn0								( fc_gt_rxn								),
		.srio_rxp0								( fc_gt_rxp								),
		.srio_txn0								( fc_gt_txn								),
		.srio_txp0								( fc_gt_txp								),


		.slave_axi_awaddr						({12'h0, srio_axi_awaddr[19:0]}							),
		.slave_axi_awprot						( srio_axi_awprot							),
		.slave_axi_awvalid						( srio_axi_awvalid							),
		.slave_axi_awready						( srio_axi_awready							),
		.slave_axi_wdata						( srio_axi_wdata							),
		.slave_axi_wstrb						( srio_axi_wstrb							),
		.slave_axi_wvalid						( srio_axi_wvalid							),
		.slave_axi_wready						( srio_axi_wready							),
		.slave_axi_bresp						( srio_axi_bresp							),
		.slave_axi_bvalid						( srio_axi_bvalid							),
		.slave_axi_bready						( srio_axi_bready							),
		.slave_axi_araddr						( {12'h0,srio_axi_araddr [19:0]}							),
		.slave_axi_arprot						( srio_axi_arprot							),
		.slave_axi_arvalid						( srio_axi_arvalid							),
		.slave_axi_arready						( srio_axi_arready							),
		.slave_axi_rdata						( srio_axi_rdata							),
		.slave_axi_rresp						( srio_axi_rresp							),
		.slave_axi_rvalid						( srio_axi_rvalid							),
		.slave_axi_rready						( srio_axi_rready							),


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
		.dma_m_axis_tdest						( srio_m_axis_tdest							)

	);		
	wire		[31:0]							D0_18b20									;
	wire		[31:0]							D1_18b20									;

	 axil_reg_EB4110_top # (
    	.base_addr								( 32'h8600_0000								)
	)axil_reg_EB4110_top(
		.rst									( ps_reset									),
		.clk									( ps_sys_clk								),

		.data_w									( 											),
//=======================================================================
//--AXI Lite
		.sys_axi_awaddr							( USER_axi_awaddr							),
		.sys_axi_awvalid						( USER_axi_awvalid							),
		.sys_axi_awprot							( USER_axi_awprot							),
		.sys_axi_awready						( USER_axi_awready							),
		.sys_axi_wdata							( USER_axi_wdata							),
		.sys_axi_wvalid							( USER_axi_wvalid							),
		.sys_axi_wstrb    						( USER_axi_wstrb							),
		.sys_axi_wready   						( USER_axi_wready							),
		.sys_axi_bresp							( USER_axi_bresp							),
		.sys_axi_bready							( USER_axi_bready							),
		.sys_axi_bvalid   						( USER_axi_bvalid							),
		.sys_axi_araddr							( USER_axi_araddr							),
		.sys_axi_arvalid						( USER_axi_arvalid							),
		.sys_axi_arprot							( USER_axi_arprot							),
		.sys_axi_arready						( USER_axi_arready							),
		.sys_axi_rresp							( USER_axi_rresp							),
		.sys_axi_rdata							( USER_axi_rdata							),
		.sys_axi_rready							( USER_axi_rready							),
		.sys_axi_rvalid							( USER_axi_rvalid							),

		.D0_18b20								( D0_18b20									),	
		.D1_18b20								( D1_18b20									),
	
		.ps_video_en							( ps_video_en								),	
		.ps_frame_ctr							( ps_frame_ctr								),	
		.device_temp							( device_temp								),
		
		.srio_v_sid_did	    					( srio_v_sid_did	    					),
		.srio_v_sel_x1	    					( srio_v_sel_x1	        					)
	);


//	ila_axis	ila_loop(
//		.clk                        			( ps_sys_clk								),
//		.probe0                                  ( {ps_video_en,
//		ps_frame_ctr  ,
//													XP1_GPIO_tri_i						,
//													XP1_GPIO_tri_t						,
//													XP1_GPIO_tri_o						
//																							})
//	);









//	ila_axis	ila_loop(
//		.clk                        			( ps_sys_clk								),
//		.probe0                                  ( {
//													loop_m_axis_tuser						,
//													loop_m_axis_tdata						,
//													loop_m_axis_tready						,
//													loop_m_axis_tvalid						,
//													loop_m_axis_tlast
//																							})
//	);

//	ila_axis	ila_srio_m0(
//		.clk                        			( ps_sys_clk								),
//		.probe0                                  ( {
//													srio_m_axis_tuser		[0*64 +: 64]	,
//													srio_m_axis_tdata		[0*64 +: 64]	,
//													srio_m_axis_tready		[0*01 +: 01]	,
//													srio_m_axis_tvalid		[0*01 +: 01]	,
//													srio_m_axis_tlast      	[0*01 +: 01]
//																							})
//	);

//	ila_axis	ila_srio_m1(
//		.clk                        			( ps_sys_clk								),
//		.probe0                                  ( {
//													srio_m_axis_tuser		[1*64 +: 64]	,
//													srio_m_axis_tdata		[1*64 +: 64]	,
//													srio_m_axis_tready		[1*01 +: 01]	,
//													srio_m_axis_tvalid		[1*01 +: 01]	,
//													srio_m_axis_tlast      	[1*01 +: 01]
//																							})
//	);


//	ila_axis	ila_srio_s0(
//		.clk                        			( ps_sys_clk								),
//		.probe0                                  ( {
//													srio_s_axis_tuser		[0*64 +: 64]	,
//													srio_s_axis_tdata		[0*64 +: 64]	,
//													srio_s_axis_tready		[0*01 +: 01]	,
//													srio_s_axis_tvalid		[0*01 +: 01]	,
//													srio_s_axis_tlast      	[0*01 +: 01]
//																							})
//	);

//	ila_axis	ila_srio_s1(
//		.clk                        			( ps_sys_clk								),
//		.probe0                                  ( {
//													srio_s_axis_tuser		[1*64 +: 64]	,
//													srio_s_axis_tdata		[1*64 +: 64]	,
//													srio_s_axis_tready		[1*01 +: 01]	,
//													srio_s_axis_tvalid		[1*01 +: 01]	,
//													srio_s_axis_tlast      	[1*01 +: 01]
//																							})
//	);


     lu0030_dm_18b20_top i_lu0030_dm_18b20_top_0(
        .rst_n                      			( ~ps_reset                  			    ),
        .clk                        			( ps_sys_clk             				    ),

        .ds18_dq                        		( ds18_dq0             				    	),
        .ms_ls_byte                        		( D0_18b20             				      	),
        .ds18_start_flag                 		( ~ps_reset         				      	)
    );	

     lu0030_dm_18b20_top i_lu0030_dm_18b20_top_1(
        .rst_n                      			( ~ps_reset                  			    ),
        .clk                        			( ps_sys_clk             				    ),

        .ds18_dq                        		( ds18_dq1             				    	),
        .ms_ls_byte                        		( D1_18b20             				      	),
        .ds18_start_flag                 		( ~ps_reset         				      	)
    );	
`endif
endmodule