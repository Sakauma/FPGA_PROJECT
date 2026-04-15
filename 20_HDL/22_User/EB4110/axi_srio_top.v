`timescale 1ns/1ns
// ============================================================================
// 维护注释
//   文件职责      : EB4110 板级定制的视频业务逻辑。
//   源码属性      : 手工维护源码，不要把修改同步到生成 IP 或网表。
//   更新要求      : 当时钟、复位、接口或数据顺序假设变化时，同步更新注释。
//   维护边界      : 注释用于说明当前实现意图，不替代接口协议文档。
// ============================================================================
//////////////////////////////////////////////////////////////////////////////////////////////////
// Company:			ZHTY
// Engineer:		ZhengYunLong
//
// Create Date:		2020/4/2 15:21:57
// Design Name:
// Module Name:		xr2000_top_at01_dma.v
// Project Name:	XP2000
// Target Devices:	XC7K325TFFG676-2
// Tool versions:	Vivado 2016.4
// Description:
//	This module is the top-level module for XP2000 system integration
// Revision:
// Revision 0.01 - File Created
// Revision 0.02 - 2018/11/15 19:49:32
// 		Add reset controll,firber disable Control
// Revision 0.03 - 2018/11/21 16:18:40
//		Add pcie_reset for sys_rst_n_c
// Additional Comments:
//
//	`define	ENABLE_SIM_ONLY
//	`define	ENABLE_BM_ONLY
	`define	ENABLE_BM_SIM
//////////////////////////////////////////////////////////////////////////////////////////////////
module	xr2000_top_AT01_TOP	#(
//==================================================================================================
//--parameter Instantation
	/*--------------------------------------------------------------------------------------
	--P_SIMULATION_R
	--------------------------------------------------------------------------------------*/
	parameter		P_SIMULATION_R				= "FALSE"									,

	/*--------------------------------------------------------------------------------------
	--Version Information
	--------------------------------------------------------------------------------------*/
	parameter		P_Version1_R				= 32'h2020_0426								,
	parameter		P_Version2_R				= 32'h1036_1000								,

	/*--------------------------------------------------------------------------------------
	--SRIO Config
	--------------------------------------------------------------------------------------*/
	parameter		P_Srio_ID_WTH_R				= 8										,	//=8 or 16 ID
	parameter		P_Srio_CH_NUM_R				= 2											,	//SRIO IP Core number
	parameter		P_Srio_CH_LANE_R			= 1											,	//1=1x 2=2x 4=4x per srio IP
	parameter		P_Srio_SPEED_R				= 5 										,	//1=1Gbps 2=2.5Gbps 3=3.125Gbps 5=5Gbps 6=6Gbps(not support)
	parameter		P_Srio_PHY_LANE_R			= 2											,	//Physical lane number,board gtx for SRIO
	parameter		P_Srio_BANK_R				= 1											,	//physical bank
	parameter		P_BANK_LANE_R	 			= P_Srio_PHY_LANE_R/P_Srio_BANK_R			,	//per bank has lane num
	parameter		P_BANK_CH_NUM_R				= P_Srio_CH_NUM_R/P_Srio_BANK_R				,	//per bank has channnel num
	/*--------------------------------------------------------------------------------------
	--AXI Lite Channel Config
	--------------------------------------------------------------------------------------*/
	parameter		P_AXILITE_CH_NUM_R			= P_Srio_BANK_R + 1 + 1						,	//BANK Num + PCIE Clock + FLash
	/*--------------------------------------------------------------------------------------
	--board cap register
	--------------------------------------------------------------------------------------*/
`ifdef	ENABLE_SIM_ONLY
	parameter		P_Srio_CAP_R				= 32'h0000_0000								,	//00=SIM Only;01=SIM+SRIO BM;10=GT BM;11=SRIO BM Only
`elsif	ENABLE_BM_ONLY
	parameter		P_Srio_CAP_R				= 32'h0000_0003								,
`elsif	ENABLE_BM_SIM
	parameter		P_Srio_CAP_R				= 32'h0000_0001								,
`else
	parameter		P_Srio_CAP_R				= 32'h0000_0000								,	//00=SIM Only;01=SIM+SRIO BM;10=GT BM;11=SRIO BM Only
`endif

	parameter		P_Srio_CH0_R				= FUNC_CH_CAP
												(
													P_Srio_CH_NUM_R[7:0]					,
													8'h0									,
													P_Srio_CAP_R[7:0]						,
													P_Srio_CH_LANE_R[7:0]
												)											,
	parameter		P_Srio_CH1_R				= FUNC_CH_CAP
												(
													P_Srio_CH_NUM_R[7:0]					,
													8'h1									,
													P_Srio_CAP_R[7:0]						,
													P_Srio_CH_LANE_R[7:0]
												)											,
	parameter		P_Srio_CH2_R				= FUNC_CH_CAP
												(
													P_Srio_CH_NUM_R[7:0]					,
													8'h2									,
													P_Srio_CAP_R[7:0]						,
													P_Srio_CH_LANE_R[7:0]
												)											,
	parameter		P_Srio_CH3_R				= FUNC_CH_CAP
												(
													P_Srio_CH_NUM_R[7:0]					,
													8'h3									,
													P_Srio_CAP_R[7:0]						,
													P_Srio_CH_LANE_R[7:0]
												)											,
	parameter		P_Srio_CH4_R				= FUNC_CH_CAP
												(
													P_Srio_CH_NUM_R[7:0]					,
													8'h4									,
													P_Srio_CAP_R[7:0]						,
													P_Srio_CH_LANE_R[7:0]
												)											,
	parameter		P_Srio_CH5_R				= FUNC_CH_CAP
												(
													P_Srio_CH_NUM_R[7:0]					,
													8'h5									,
													P_Srio_CAP_R[7:0]						,
													P_Srio_CH_LANE_R[7:0]
												)											,
	parameter		P_Srio_CH6_R				= FUNC_CH_CAP
												(
													P_Srio_CH_NUM_R[7:0]					,
													8'h6									,
													P_Srio_CAP_R[7:0]						,
													P_Srio_CH_LANE_R[7:0]
												)											,
	parameter		P_Srio_CH7_R				= FUNC_CH_CAP
												(
													P_Srio_CH_NUM_R[7:0]					,
													8'h7									,
													P_Srio_CAP_R[7:0]						,
													P_Srio_CH_LANE_R[7:0]
												)											,

	/*--------------------------------------------------------------------------------------
	--PCIe DMA Config.
	--------------------------------------------------------------------------------------*/
`ifdef	ENABLE_SIM_ONLY
	parameter		P_DMA_UP_NUM_R				= P_Srio_CH_NUM_R							,	//SIM ONLY DMA=SRIO Chanel
	parameter		P_DMA_DN_NUM_R				= P_Srio_CH_NUM_R							,	//SIM ONLY DMA=SRIO Chanel
`elsif	ENABLE_BM_ONLY
	parameter		P_DMA_UP_NUM_R				= 1											,	//BM ONLY DMA=BM one channel
	parameter		P_DMA_DN_NUM_R				= 1											,	//DMA DN not used
`elsif	ENABLE_BM_SIM
	parameter		P_DMA_UP_NUM_R				= P_Srio_CH_NUM_R + 1						,	//BMSIM UP + 1
	parameter		P_DMA_DN_NUM_R				= P_Srio_CH_NUM_R							,	//DN keep SRIO Channel
`else
	parameter		P_DMA_UP_NUM_R				= P_Srio_CH_NUM_R							,	//=SIM Only
	parameter		P_DMA_DN_NUM_R				= P_Srio_CH_NUM_R							,	//=SIM Only
`endif
	
	parameter		P_BM_DMA_R					= FUN_BM_DMA(
														P_Srio_CH_NUM_R[7:0]				,
														0									,
														P_Srio_CAP_R[1:0])					,
														
	/*--------------------------------------------------------------------------------------
	--zt_cross config.
	--------------------------------------------------------------------------------------*/
	parameter		P_AXI_CHANNEL_R				= P_BANK_CH_NUM_R							,	//per bank has ony croos
	parameter		P_CH_LOW_BIT_R				= 12										,
	parameter		P_CH_Start_Addr_R			= 0
	)(
	
	output										srio_vx1_r_axis_aclk								,	
	input										srio_vx1_r_axis_tready								,
	output			[64-1:0] 					srio_vx1_r_axis_tdata								,
	output										srio_vx1_r_axis_tvalid								,
	output										srio_vx1_r_axis_tlast								, 
	output			[32-1:0] 					srio_vx1_r_axis_tuser								,		
	
//==================================================================================================
//--Port Defines
	/*--------------------------------------------------------------------------------------
	--System Clock and Reset
	--------------------------------------------------------------------------------------*/
	input										sys_rst_n									,

	/*--------------------------------------------------------------------------------------
	--SRIO Link Port
	--------------------------------------------------------------------------------------*/
	input										srio_sys_clk_p								,
	input										srio_sys_clk_n								,

	output			[P_Srio_PHY_LANE_R-1:0]		srio_tx_disable								,

	input			[P_Srio_PHY_LANE_R-1:0]		srio_rxn0									,
	input			[P_Srio_PHY_LANE_R-1:0]		srio_rxp0									,
	output			[P_Srio_PHY_LANE_R-1:0]		srio_txn0									,
	output			[P_Srio_PHY_LANE_R-1:0]		srio_txp0									,

	/*--------------------------------------------------------------------------------------
	--DMA涓婅閫氶亾 AXI Stream鎺ュ彛
	--------------------------------------------------------------------------------------*/
	input			[P_DMA_UP_NUM_R*1-1  : 0]		dma_s_axis_aclk								,
	output			[P_DMA_UP_NUM_R*64-1 : 0]		dma_s_axis_tdata							,
	output			[P_DMA_UP_NUM_R*4-1  : 0]		dma_s_axis_tid								,
	input			[P_DMA_UP_NUM_R*1-1	: 0]		dma_s_axis_tready							,
	output			[P_DMA_UP_NUM_R*1-1	: 0]		dma_s_axis_tvalid							,
	output			[P_DMA_UP_NUM_R*8-1	: 0]		dma_s_axis_tstrb							,
	output			[P_DMA_UP_NUM_R*8-1	: 0]		dma_s_axis_tkeep							,
	output			[P_DMA_UP_NUM_R*1-1	: 0]		dma_s_axis_tlast							,
	output			[P_DMA_UP_NUM_R*64-1	: 0]		dma_s_axis_tuser							,
	output			[P_DMA_UP_NUM_R*4-1	: 0]		dma_s_axis_tdest							,
	
	
	/*--------------------------------------------------------------------------------------
	--DMA閫氶亾涓嬭 AXI Stream鎺ュ彛
	--------------------------------------------------------------------------------------*/
	input			[P_DMA_DN_NUM_R*1-1	: 0]		dma_m_axis_aclk								,
	input			[P_DMA_DN_NUM_R*64-1	: 0]		dma_m_axis_tdata							,
	input			[P_DMA_DN_NUM_R*4-1	: 0]		dma_m_axis_tid								,
	output			[P_DMA_DN_NUM_R*1-1	: 0]		dma_m_axis_tready							,
	input			[P_DMA_DN_NUM_R*1-1	: 0]		dma_m_axis_tvalid							,
	input			[P_DMA_DN_NUM_R*8-1	: 0]		dma_m_axis_tstrb							,
	input			[P_DMA_DN_NUM_R*8-1	: 0]		dma_m_axis_tkeep							,
	input			[P_DMA_DN_NUM_R*1-1	: 0]		dma_m_axis_tlast							,
	input			[P_DMA_DN_NUM_R*64-1	: 0]		dma_m_axis_tuser							,
	input			[P_DMA_DN_NUM_R*4-1	: 0]		dma_m_axis_tdest							,
	
//==================================================================================================
	input										slave_clk									,	
	/*--------------------------------------------------------------------------------------
	--Write Address Channel Signals
	--------------------------------------------------------------------------------------*/
	input			[32-1:0] 					slave_axi_awaddr							,
  	input			[3-1:0]						slave_axi_awprot							,
  	input			[1-1:0]						slave_axi_awvalid							,
  	output			[1-1:0]						slave_axi_awready							,

	/*--------------------------------------------------------------------------------------
	--Write Data Channel Signals
	--------------------------------------------------------------------------------------*/
  	input			[31:0]						slave_axi_wdata								,
  	input			[ 3:0]						slave_axi_wstrb								,
  	input										slave_axi_wvalid							,
  	output										slave_axi_wready							,

	/*--------------------------------------------------------------------------------------
	--Write Response Channel Signals
	--------------------------------------------------------------------------------------*/
  	output			[ 1:0]						slave_axi_bresp								,
  	output										slave_axi_bvalid							,
  	input										slave_axi_bready							,

	/*--------------------------------------------------------------------------------------
	--Read Address Channel Signals
	--------------------------------------------------------------------------------------*/
  	input			[31:0]						slave_axi_araddr							,
  	input			[ 2:0]						slave_axi_arprot							,
  	input										slave_axi_arvalid							,
  	output										slave_axi_arready							,

	/*--------------------------------------------------------------------------------------
	--Read Address Channel Signals
	--------------------------------------------------------------------------------------*/
  	output			[31:0]						slave_axi_rdata								,
  	output			[ 1:0]						slave_axi_rresp								,
  	output										slave_axi_rvalid							,
  	input										slave_axi_rready							,

	input										pcie_clk									,

	input										flash_clk									,


	inout			[3:0]						spi_0_dq									,
	inout										spi_0_ss									
	// inout			[3:0]						flash_data									,
	// output										flash_csn
	
	);
	
//	ila_axil	ila_axil_srio_all(
//		.clk                        			( pcie_clk								),
//		.probe0                                  ( {
//													slave_axi_wdata    	,
//													slave_axi_wvalid   ,
//													slave_axi_wready    	,
//													slave_axi_awaddr   ,
//													slave_axi_awvalid    	,
//													slave_axi_awready   ,
													
//slave_axi_araddr					,
//slave_axi_arvalid							, 
//slave_axi_arready							,

//	slave_axi_rdata					,
//slave_axi_rvalid							, 
//slave_axi_rready							
													
//																							})
//	);	
	
//==================================================================================================
//--Function Definitions
function	[7:0] FUN_BM_DMA;
	input	[7:0]	_ch_num;
	input	[7:0]	_ch;
	input	[1:0]	_cap;
	begin
		FUN_BM_DMA	= (_cap[1:0]==2'b00)?8'hFF		//Not support BM
					: (_cap[1:0]==2'b01)?_ch_num	//SIM+BM, use first channel for BM DMA, ch_num+1-1=ch_num
					: (_cap[1:0]==2'b10)?_ch		//GT mode occupies dedicated channel
					: 8'h00;						//Only SRIO BM, use DMA channel 0
	end
endfunction

function	[31:0] FUNC_CH_CAP;
	input	[7:0]	_ch_num;
	input	[7:0]	_ch;
	input	[7:0]	_cap;
	input	[7:0]	_x;
	reg		[7:0]	bm_dma;
	reg		[7:0]	sim_dma;
	reg		[7:0]	cap;
	begin
		bm_dma		= FUN_BM_DMA(_ch_num[7:0],_ch,_cap[1:0]);
		sim_dma		= (_ch_num>_ch)?(_cap[1]==1'b0)?_ch:8'hFF:8'hFF;	//8'h00 is DMA channel, CH1=DMA Ch1
		FUNC_CH_CAP	= (_ch_num<=_ch)?32'hFFFF_FFFF:{bm_dma[7:0],sim_dma[7:0],_x[7:0],_cap[7:0]};
	end
endfunction




//==================================================================================================
//--SRIO Signal Definitions
	/*--------------------------------------------------------------------------------------
	-- all clocks as out
	--------------------------------------------------------------------------------------*/
	wire            [P_Srio_BANK_R-1:0]			log_clk	   									;// LOG interface clock
	wire            [P_Srio_BANK_R-1:0]			phy_clk		   								;// PHY interface clock
	wire            [P_Srio_BANK_R-1:0]			gt_clk    									; // UNUSED: Only output from srio_support, never used (ERROR: connected to undefined gt_clk at line 696)
	wire            [P_Srio_BANK_R-1:0]			gt_pcs_clk									;// GT fabric interface clock
	wire            [P_Srio_BANK_R-1:0]			drpclk	    								; // UNUSED: Only output from srio_support, never used
	wire            [P_Srio_BANK_R-1:0]			refclk	    								; // UNUSED: Only output from srio_support, never used
	
	wire			[P_Srio_BANK_R-1:0]			clk_lock	  								; // UNUSED: Only output from srio_support, never used

	/*--------------------------------------------------------------------------------------
	--all resets as out
	--------------------------------------------------------------------------------------*/
	wire            [P_Srio_CH_NUM_R* 1-1:0]	srio_log_rst		   						;	// Reset for LOG clock Domain
	wire            [P_Srio_CH_NUM_R* 1-1:0]	srio_phy_rst		   						;	// Reset for PHY clock Domain
	wire            [P_Srio_CH_NUM_R* 1-1:0]	srio_buf_rst		   						;
	wire            [P_Srio_CH_NUM_R* 1-1:0]	srio_cfg_rst		   						;
	wire            [P_Srio_CH_NUM_R* 1-1:0]	srio_gt_pcs_rst								;

	/*--------------------------------------------------------------------------------------
	-- QPLL outputs
	--------------------------------------------------------------------------------------*/
	wire            [P_Srio_BANK_R-1:0]			gt0_qpll_clk	       						; // UNUSED: Only output from srio_support, never used
	wire            [P_Srio_BANK_R-1:0]			gt0_qpll_out_refclk							; // UNUSED: Only output from srio_support, never used

	wire             							sim_train_en				= 0				;	// Reduce timers for inialization for simulation
	/*--------------------------------------------------------------------------------------
	--PHY control signals
	--------------------------------------------------------------------------------------*/
	wire            [P_Srio_CH_NUM_R* 1-1:0] 	srio_force_reinit							;	// Force reinitialization	//2018/11/16 14:45:05 Link Reset
	wire            [P_Srio_CH_NUM_R* 1-1:0] 	srio_phy_mce				= 0				;	// Send MCE control symbol
	wire            [P_Srio_CH_NUM_R* 1-1:0] 	srio_phy_link_reset			= 0				;	// Send link reset control symbols

	wire            [P_Srio_CH_NUM_R* 1-1:0]	srio_phy_rcvd_mce							;	// MCE control symbol received
	wire            [P_Srio_CH_NUM_R* 1-1:0]	srio_phy_rcvd_link_reset					;	// Received 4 consecutive reset symbols
	wire     		[P_Srio_CH_NUM_R*224-1:0]	srio_phy_debug								;	// Useful debug signals
	wire            [P_Srio_CH_NUM_R* 1-1:0]	srio_gtrx_disperr_or						;	// GT disparity error (reduce ORed)
	wire            [P_Srio_CH_NUM_R* 1-1:0]	srio_gtrx_notintable_or						;	// GT not in table error (reduce ORed)

	/*--------------------------------------------------------------------------------------
	--side bank signals
	--------------------------------------------------------------------------------------*/

	wire            [P_Srio_CH_NUM_R* 1-1:0]	srio_port_error                   			;	// In Port Error State
	wire 		  	[P_Srio_CH_NUM_R*24-1:0]	srio_port_timeout                 			;	// Timeout occurred
	wire            [P_Srio_CH_NUM_R* 1-1:0]	srio_srio_host                    			;	// Endpoint is the system host
	wire            [P_Srio_CH_NUM_R* 1-1:0]	srio_port_decode_error            			;	// No valid output port for the RX transaction
	wire			[P_Srio_CH_NUM_R*16-1:0]	srio_deviceid                     			;	// Device ID
	wire            [P_Srio_CH_NUM_R* 1-1:0]	srio_idle2_selected               			;	// The PHY is operating in IDLE2 mode

	/*--------------------------------------------------------------------------------------
	--PHY Informational signals in support logic
	--------------------------------------------------------------------------------------*/
	wire			[P_Srio_CH_NUM_R* 1-1:0]	srio_port_initialized						;	// Port is intialized
	wire			[P_Srio_CH_NUM_R* 1-1:0]	srio_link_initialized						;	// Ready to transmit data
	wire            [P_Srio_CH_NUM_R* 1-1:0]	srio_idle_selected   						;	// The IDLE sequence has been selected
	wire            [P_Srio_CH_NUM_R* 1-1:0]	srio_mode_1x         						;	// Link is trained down to 1x mode

	/*--------------------------------------------------------------------------------------
	--SRIO maintr IO Port
	--------------------------------------------------------------------------------------*/

//	wire            [P_Srio_CH_NUM_R* 1-1:0] 	srio_maintr_rst								;	// Reset for maintr interface, on LOG clk domain
//
//	wire			[P_Srio_CH_NUM_R* 1-1:0]	srio_maintr_awvalid							;
//    wire	        [P_Srio_CH_NUM_R* 1-1:0]	srio_maintr_awready							;
//    wire			[P_Srio_CH_NUM_R*32-1:0]    srio_maintr_awaddr							;
//    wire	        [P_Srio_CH_NUM_R* 1-1:0]	srio_maintr_wvalid							;
//    wire	        [P_Srio_CH_NUM_R* 1-1:0]	srio_maintr_wready							;
//    wire			[P_Srio_CH_NUM_R*32-1:0] 	srio_maintr_wdata							;
//    wire	        [P_Srio_CH_NUM_R* 1-1:0]	srio_maintr_bvalid							;
//    wire	        [P_Srio_CH_NUM_R* 1-1:0]	srio_maintr_bready							;
//    wire			[P_Srio_CH_NUM_R* 2-1:0]	srio_maintr_bresp							;
//
//    wire	        [P_Srio_CH_NUM_R* 1-1:0]	srio_maintr_arvalid							;
//    wire	        [P_Srio_CH_NUM_R* 1-1:0]	srio_maintr_arready							;
//    wire			[P_Srio_CH_NUM_R*32-1:0] 	srio_maintr_araddr							;
//    wire	        [P_Srio_CH_NUM_R* 1-1:0]	srio_maintr_rvalid							;
//    wire	        [P_Srio_CH_NUM_R* 1-1:0]	srio_maintr_rready							;
//    wire			[P_Srio_CH_NUM_R*32-1:0] 	srio_maintr_rdata							;
//    wire			[P_Srio_CH_NUM_R* 2-1:0]	srio_maintr_rresp							;
    wire			[ 1-1:0]					sa_srio_maintr_rst							;
    wire			[ 1-1:0]					sa_srio_maintr_awvalid						;
    wire	        [ 1-1:0]					sa_srio_maintr_awready						;
    wire			[32-1:0]    				sa_srio_maintr_awaddr						;
    wire	        [ 1-1:0]					sa_srio_maintr_wvalid						;
    wire	        [ 1-1:0]					sa_srio_maintr_wready						;
    wire			[32-1:0] 					sa_srio_maintr_wdata						;
    wire	        [ 1-1:0]					sa_srio_maintr_bvalid						;
    wire	        [ 1-1:0]					sa_srio_maintr_bready						;
    wire			[ 2-1:0]					sa_srio_maintr_bresp						;
    wire	        [ 1-1:0]					sa_srio_maintr_arvalid						;
    wire	        [ 1-1:0]					sa_srio_maintr_arready						;
    wire			[32-1:0] 					sa_srio_maintr_araddr						;
    wire	        [ 1-1:0]					sa_srio_maintr_rvalid						;
    wire	        [ 1-1:0]					sa_srio_maintr_rready						;
    wire			[32-1:0] 					sa_srio_maintr_rdata						;
    wire			[ 2-1:0]					sa_srio_maintr_rresp						;
	wire			[ 1-1:0]					sb_srio_maintr_rst							;                                				
    wire			[ 1-1:0]					sb_srio_maintr_awvalid						;
    wire	        [ 1-1:0]					sb_srio_maintr_awready						;
    wire			[32-1:0]    				sb_srio_maintr_awaddr						;
    wire	        [ 1-1:0]					sb_srio_maintr_wvalid						;
    wire	        [ 1-1:0]					sb_srio_maintr_wready						;
    wire			[32-1:0] 					sb_srio_maintr_wdata						;
    wire	        [ 1-1:0]					sb_srio_maintr_bvalid						;
    wire	        [ 1-1:0]					sb_srio_maintr_bready						;
    wire			[ 2-1:0]					sb_srio_maintr_bresp						;
	
    wire	        [ 1-1:0]					sb_srio_maintr_arvalid						;
    wire	        [ 1-1:0]					sb_srio_maintr_arready						;
    wire			[32-1:0] 					sb_srio_maintr_araddr						;
    wire	        [ 1-1:0]					sb_srio_maintr_rvalid						;
    wire	        [ 1-1:0]					sb_srio_maintr_rready						;
    wire			[32-1:0] 					sb_srio_maintr_rdata						;
    wire			[ 2-1:0]					sb_srio_maintr_rresp						;
	/*--------------------------------------------------------------------------------------
	--SRIO IP Core Hello foramt IO Port
	--------------------------------------------------------------------------------------*/
	wire			[P_Srio_CH_NUM_R* 1-1:0]	srio_iotx_tvalid							;
	wire			[P_Srio_CH_NUM_R* 1-1:0]	srio_iotx_tready							;
	wire			[P_Srio_CH_NUM_R* 1-1:0]	srio_iotx_tlast								;
	wire			[P_Srio_CH_NUM_R*64-1:0]	srio_iotx_tdata								;
	wire			[P_Srio_CH_NUM_R* 8-1:0]	srio_iotx_tkeep								;
	wire			[P_Srio_CH_NUM_R*32-1:0]	srio_iotx_tuser								;

	wire			[P_Srio_CH_NUM_R* 1-1:0]	srio_iorx_tvalid							;
	wire			[P_Srio_CH_NUM_R* 1-1:0]	srio_iorx_tready							;
	wire			[P_Srio_CH_NUM_R* 1-1:0]	srio_iorx_tlast								;
	wire			[P_Srio_CH_NUM_R*64-1:0]	srio_iorx_tdata								;
	wire			[P_Srio_CH_NUM_R* 8-1:0]	srio_iorx_tkeep								;
	wire			[P_Srio_CH_NUM_R*32-1:0]	srio_iorx_tuser								;

	/*--------------------------------------------------------------------------------------
	--dma dn/up packet
	--------------------------------------------------------------------------------------*/
	wire			[P_Srio_CH_NUM_R*32-1:0]	c_sp_up_cnt									;
	wire			[P_Srio_CH_NUM_R*32-1:0]	c_sp_dn_cnt									;
	wire			[P_Srio_CH_NUM_R*32-1:0]	c_sp_rx_cnt									;
	wire			[P_Srio_CH_NUM_R*32-1:0]	c_sp_tx_cnt									;
//==================================================================================================
//--Register Clock Domain Crossing Signal Definitions
	wire			[P_AXILITE_CH_NUM_R*32-1:0] master_axi_awaddr							;
  	wire			[P_AXILITE_CH_NUM_R* 3-1:0]	master_axi_awprot							;
  	wire			[P_AXILITE_CH_NUM_R* 1-1:0]	master_axi_awvalid							;
  	wire			[P_AXILITE_CH_NUM_R* 1-1:0]	master_axi_awready							;

  	wire			[P_AXILITE_CH_NUM_R*32-1:0]	master_axi_wdata							;
  	wire			[P_AXILITE_CH_NUM_R* 4-1:0]	master_axi_wstrb							;
  	wire			[P_AXILITE_CH_NUM_R* 1-1:0]	master_axi_wvalid							;
  	wire			[P_AXILITE_CH_NUM_R* 1-1:0]	master_axi_wready							;

  	wire			[P_AXILITE_CH_NUM_R* 2-1:0]	master_axi_bresp							;
  	wire			[P_AXILITE_CH_NUM_R* 1-1:0]	master_axi_bvalid							;
  	wire			[P_AXILITE_CH_NUM_R* 1-1:0]	master_axi_bready							;

  	wire			[P_AXILITE_CH_NUM_R*32-1:0]	master_axi_araddr							;
  	wire			[P_AXILITE_CH_NUM_R* 3-1:0]	master_axi_arprot							;
  	wire			[P_AXILITE_CH_NUM_R* 1-1:0]	master_axi_arvalid							;
  	wire			[P_AXILITE_CH_NUM_R* 1-1:0]	master_axi_arready							;

  	wire			[P_AXILITE_CH_NUM_R*32-1:0]	master_axi_rdata							;
  	wire			[P_AXILITE_CH_NUM_R* 2-1:0]	master_axi_rresp							;
  	wire			[P_AXILITE_CH_NUM_R* 1-1:0]	master_axi_rvalid							;
  	wire			[P_AXILITE_CH_NUM_R* 1-1:0]	master_axi_rready                           ;
  	
	/*--------------------------------------------------------------------------------------
	--SRIO BM 
	--------------------------------------------------------------------------------------*/  	
	wire			[63:0]						c_bm_timestamp								;
	wire										c_bm_timestamp_rf							;

	wire										c_bm_cha_en									;
	wire										c_bm_chb_en									;

	wire			[31:0]						c_bm_up_cnt									;

	wire			[31:0]						c_bm_cha_recv_cnt							;
	wire			[31:0]						c_bm_cha_up_cnt								;
	wire			[31:0]						c_bm_cha_lost_cnt							;
	wire			[31:0]						c_bm_chb_recv_cnt							;
	wire			[31:0]						c_bm_chb_up_cnt								;
	wire			[31:0]						c_bm_chb_lost_cnt							;
	


	/*--------------------------------------------------------------------------------------
	--Clock And Reset
	--------------------------------------------------------------------------------------*/
	wire										sys_rst										;
	wire										sys_rst_n_in_c								;

	assign			sys_rst_n_in_c					= 	sys_rst_n								;

	assign	sys_rst								= ~sys_rst_n_in_c							;


//==================================================================================================
//--xr2000_axilite_top Instantation
	wire	[P_AXILITE_CH_NUM_R-1:0]			master_clk									;

	assign	master_clk							=	{
														log_clk								,
														flash_clk							,	//flash_clk
														pcie_clk
													}										;
	xr2000_axilite_top	#(
		.P_SIMULATION_R							( P_SIMULATION_R							),
		.P_AXILITE_CH_NUM_R						( P_AXILITE_CH_NUM_R						)
	)
	u_axilite_top (
		.rst									( sys_rst									),
		.slave_clk								( slave_clk									),
		.master_clk								( master_clk								),

		.slave_axi_awaddr						( slave_axi_awaddr							),
		.slave_axi_awprot						( slave_axi_awprot							),
		.slave_axi_awvalid						( slave_axi_awvalid							),
		.slave_axi_awready						( slave_axi_awready							),
		.slave_axi_wdata						( slave_axi_wdata							),
		.slave_axi_wstrb						( slave_axi_wstrb							),
		.slave_axi_wvalid						( slave_axi_wvalid							),
		.slave_axi_wready						( slave_axi_wready							),
		.slave_axi_bresp						( slave_axi_bresp							),
		.slave_axi_bvalid						( slave_axi_bvalid							),
		.slave_axi_bready						( slave_axi_bready							),
		.slave_axi_araddr						( slave_axi_araddr							),
		.slave_axi_arprot						( slave_axi_arprot							),
		.slave_axi_arvalid						( slave_axi_arvalid							),
		.slave_axi_arready						( slave_axi_arready							),
		.slave_axi_rdata						( slave_axi_rdata							),
		.slave_axi_rresp						( slave_axi_rresp							),
		.slave_axi_rvalid						( slave_axi_rvalid							),
		.slave_axi_rready						( slave_axi_rready							),

		.master_axi_awaddr						( master_axi_awaddr							),
		.master_axi_awprot						( master_axi_awprot							),
		.master_axi_awvalid						( master_axi_awvalid						),
		.master_axi_awready						( master_axi_awready						),
		.master_axi_wdata						( master_axi_wdata							),
		.master_axi_wstrb						( master_axi_wstrb							),
		.master_axi_wvalid						( master_axi_wvalid							),
		.master_axi_wready						( master_axi_wready							),
		.master_axi_bresp						( master_axi_bresp							),
		.master_axi_bvalid						( master_axi_bvalid							),
		.master_axi_bready						( master_axi_bready							),
		.master_axi_araddr						( master_axi_araddr							),
		.master_axi_arprot						( master_axi_arprot							),
		.master_axi_arvalid						( master_axi_arvalid						),
		.master_axi_arready						( master_axi_arready						),
		.master_axi_rdata						( master_axi_rdata							),
		.master_axi_rresp						( master_axi_rresp							),
		.master_axi_rvalid						( master_axi_rvalid							),
		.master_axi_rready						( master_axi_rready							)
	);
//==================================================================================================
//--SRIO_DUT instantation -----------------
	srio_support	#(
		.P_Srio_ID_WTH_R						( P_Srio_ID_WTH_R							),
		.P_Srio_CH_NUM_R						( P_Srio_CH_NUM_R							),
		.P_Srio_CH_LANE_R						( P_Srio_CH_LANE_R	        				),
		.P_Srio_SPEED_R							( P_Srio_SPEED_R		    				),
		.P_Srio_PHY_LANE_R						( P_Srio_PHY_LANE_R	        				)
	)
	i_srio_support	(
		.sys_clkp                				( srio_sys_clk_p							),
		.sys_clkn                				( srio_sys_clk_n							),
		.sys_rst                 				( sys_rst									),
      // all clocks as output in shared logic mode
		.log_clk_out             				( log_clk   								),
		.phy_clk_out             				( phy_clk   								),
		.gt_clk_out              				( gt_clk    								), // ERROR: gt_clk not defined, should be gt_clk_out
		.gt_pcs_clk_out          				( gt_pcs_clk								),
		.drpclk_out              				( drpclk    								),
		.refclk_out              				( refclk    								),
		.clk_lock_out            				( clk_lock  								),
      // all resets as output in shared logic mode
		.log_rst_out           					( srio_log_rst   							),
		.phy_rst_out           					( srio_phy_rst   							),
		.buf_rst_out           					( srio_buf_rst   							),
		.cfg_rst_out           					( srio_cfg_rst   							),
		.gt_pcs_rst_out        					( srio_gt_pcs_rst							),

//---------------------------------------------------------------
		.gt0_qpll_clk_out        				( gt0_qpll_clk	        					),
		.gt0_qpll_out_refclk_out 				( gt0_qpll_out_refclk	 					),

// //---------------------------------------------------------------
		.srio_rxn0               				( srio_rxn0									),
		.srio_rxp0               				( srio_rxp0									),
		.srio_txn0               				( srio_txn0									),
		.srio_txp0               				( srio_txp0									),

		.s_axis_iotx_tvalid            			( srio_iotx_tvalid							),
		.s_axis_iotx_tready            			( srio_iotx_tready							),
		.s_axis_iotx_tlast             			( srio_iotx_tlast							),
		.s_axis_iotx_tdata             			( srio_iotx_tdata							),
		.s_axis_iotx_tkeep             			( srio_iotx_tkeep							),
		.s_axis_iotx_tuser             			( srio_iotx_tuser							),

		.m_axis_iorx_tvalid            			( srio_iorx_tvalid							),
		.m_axis_iorx_tready            			( srio_iorx_tready							),
		.m_axis_iorx_tlast             			( srio_iorx_tlast							),
		.m_axis_iorx_tdata             			( srio_iorx_tdata							),
		.m_axis_iorx_tkeep             			( srio_iorx_tkeep							),
		.m_axis_iorx_tuser             			( srio_iorx_tuser							),

		.s_axi_maintr_rst     	         		( {sb_srio_maintr_rst		,sa_srio_maintr_rst		}),

		.s_axi_maintr_awvalid          			( {sb_srio_maintr_awvalid	,sa_srio_maintr_awvalid	}),
		.s_axi_maintr_awready          			( {sb_srio_maintr_awready	,sa_srio_maintr_awready	}),
		.s_axi_maintr_awaddr           			( {sb_srio_maintr_awaddr	,sa_srio_maintr_awaddr	}),
		.s_axi_maintr_wvalid           			( {sb_srio_maintr_wvalid	,sa_srio_maintr_wvalid	}),
		.s_axi_maintr_wready           			( {sb_srio_maintr_wready	,sa_srio_maintr_wready	}),
		.s_axi_maintr_wdata            			( {sb_srio_maintr_wdata		,sa_srio_maintr_wdata	}),
		.s_axi_maintr_bvalid           			( {sb_srio_maintr_bvalid	,sa_srio_maintr_bvalid	}),
		.s_axi_maintr_bready           			( {sb_srio_maintr_bready	,sa_srio_maintr_bready	}),
		.s_axi_maintr_bresp            			( {sb_srio_maintr_bresp		,sa_srio_maintr_bresp	}),

		.s_axi_maintr_arvalid          			( {sb_srio_maintr_arvalid	,sa_srio_maintr_arvalid	}),
		.s_axi_maintr_arready          			( {sb_srio_maintr_arready	,sa_srio_maintr_arready	}),
		.s_axi_maintr_araddr           			( {sb_srio_maintr_araddr	,sa_srio_maintr_araddr	}),
		.s_axi_maintr_rvalid           			( {sb_srio_maintr_rvalid	,sa_srio_maintr_rvalid	}),
		.s_axi_maintr_rready           			( {sb_srio_maintr_rready	,sa_srio_maintr_rready	}),
		.s_axi_maintr_rdata            			( {sb_srio_maintr_rdata		,sa_srio_maintr_rdata	}),
		.s_axi_maintr_rresp            			( {sb_srio_maintr_rresp		,sa_srio_maintr_rresp	}),

		.sim_train_en                  			( sim_train_en								),
		.phy_mce           	            		( srio_phy_mce								),
		.phy_link_reset    	            		( srio_phy_link_reset						),
		.force_reinit      	            		( srio_force_reinit							),

		.phy_rcvd_mce                  			( srio_phy_rcvd_mce       					),
		.phy_rcvd_link_reset           			( srio_phy_rcvd_link_reset					),
		.phy_debug                     			( srio_phy_debug          					),
		.gtrx_disperr_or               			( srio_gtrx_disperr_or    					),
		.gtrx_notintable_or            			( srio_gtrx_notintable_or 					),

		.port_error                    			( srio_port_error         					),
		.port_timeout                  			( srio_port_timeout       					),
		.srio_host                     			( srio_srio_host          					),
		.port_decode_error             			( srio_port_decode_error  					),
		.deviceid                      			( srio_deviceid           					),
		.idle2_selected                			( srio_idle2_selected     					),

		.phy_lcl_master_enable_out     			( 											), // these are side band output only signals
		.buf_lcl_response_only_out     			( 											),
		.buf_lcl_tx_flow_control_out   			( 											),
		.buf_lcl_phy_buf_stat_out      			( 											),
		.phy_lcl_phy_next_fm_out       			( 											),
		.phy_lcl_phy_last_ack_out      			( 											),
		.phy_lcl_phy_rewind_out        			( 											),
		.phy_lcl_phy_rcvd_buf_stat_out 			( 											),
		.phy_lcl_maint_only_out        			( 											),

		.port_initialized              			( srio_port_initialized  					),
		.link_initialized              			( srio_link_initialized  					),
		.idle_selected                 			( srio_idle_selected     					),
		.mode_1x                       			( srio_mode_1x           					)
	);

	assign	srio_tx_disable						= 0											;

//==================================================================================================
//--regfile_sim_top Instantation
	regfile_sim_top	#(
		.P_SIMULATION_R							( P_SIMULATION_R							),
		.P_Srio_CH_NUM_R						( P_Srio_CH_NUM_R							),
		.P_Srio_CAP_R							( P_Srio_CAP_R								),
		.P_Srio_ID_WTH_R						( P_Srio_ID_WTH_R							),
		.P_Srio_SPEED_R							( P_Srio_SPEED_R							),
		.P_Srio_BANK_R							( P_Srio_BANK_R-1							),	//Register allocation limitation
		.P_Srio_CH0_R							( P_Srio_CH0_R								),
		.P_Srio_CH1_R							( P_Srio_CH1_R								),
		.P_Srio_CH2_R							( P_Srio_CH2_R								),
		.P_Srio_CH3_R							( P_Srio_CH3_R								),
		.P_Srio_CH4_R							( P_Srio_CH4_R								),
		.P_Srio_CH5_R							( P_Srio_CH5_R								),
		.P_Srio_CH6_R							( P_Srio_CH6_R								),
		.P_Srio_CH7_R							( P_Srio_CH7_R								)
	)
	i_regfile_sim_top (
		.rst									( sys_rst									),
		.clk									( pcie_clk									),
		
		.c_bm_timestamp							( c_bm_timestamp							),
		.c_bm_timestamp_rf						( c_bm_timestamp_rf							),
		.c_bm_up_cnt							( c_bm_up_cnt								),
		
		.sys_axi_awaddr							( master_axi_awaddr	    	[0*32 +: 32]	),
		.sys_axi_awprot							( master_axi_awprot	    	[0* 3 +:  3]	),
		.sys_axi_awvalid						( master_axi_awvalid		[0* 1 +:  1]	),
		.sys_axi_awready						( master_axi_awready		[0* 1 +:  1]	),

		.sys_axi_wdata							( master_axi_wdata	    	[0*32 +: 32]	),
		.sys_axi_wstrb							( master_axi_wstrb	    	[0* 4 +:  4]	),
		.sys_axi_wvalid							( master_axi_wvalid	    	[0* 1 +:  1]	),
		.sys_axi_wready							( master_axi_wready	    	[0* 1 +:  1]	),

		.sys_axi_bresp							( master_axi_bresp	    	[0* 2 +:  2]	),
		.sys_axi_bvalid							( master_axi_bvalid	    	[0* 1 +:  1]	),
		.sys_axi_bready							( master_axi_bready	    	[0* 1 +:  1]	),

		.sys_axi_araddr							( master_axi_araddr	    	[0*32 +: 32]	),
		.sys_axi_arprot							( master_axi_arprot	    	[0* 3 +:  3]	),
		.sys_axi_arvalid						( master_axi_arvalid		[0* 1 +:  1]	),
		.sys_axi_arready						( master_axi_arready		[0* 1 +:  1]	),

		.sys_axi_rdata							( master_axi_rdata	    	[0*32 +: 32]	),
		.sys_axi_rresp							( master_axi_rresp	    	[0* 2 +:  2]	),
		.sys_axi_rvalid							( master_axi_rvalid	    	[0* 1 +:  1]	),
		.sys_axi_rready							( master_axi_rready     	[0* 1 +:  1]	),

		.c_sp_up_cnt							( {{{8-P_Srio_CH_NUM_R}{32'b0}},c_sp_up_cnt}),	//max 8 channel
		.c_sp_dn_cnt							( {{{8-P_Srio_CH_NUM_R}{32'b0}},c_sp_dn_cnt})
	);
//==================================================================================================
//--zt_axilite_cross Instantation
	/*--------------------------------------------------------------------------------------
	--Slave Write Data Command Signals
	--------------------------------------------------------------------------------------*/
	wire			[P_AXI_CHANNEL_R*32-1:0]	log_axi_awaddr								;
  	wire			[P_AXI_CHANNEL_R*3-1 :0]	log_axi_awprot								;
  	wire			[P_AXI_CHANNEL_R*1-1 :0]	log_axi_awvalid								;
  	wire			[P_AXI_CHANNEL_R*1-1 :0]	log_axi_awready								;
  	wire			[P_AXI_CHANNEL_R*32-1:0]	log_axi_wdata								;
  	wire			[P_AXI_CHANNEL_R*4-1 :0]	log_axi_wstrb								;
  	wire			[P_AXI_CHANNEL_R*1-1 :0]	log_axi_wvalid								;
  	wire			[P_AXI_CHANNEL_R*1-1 :0]	log_axi_wready								;
  	wire			[P_AXI_CHANNEL_R*2-1 :0]	log_axi_bresp								;
  	wire			[P_AXI_CHANNEL_R*1-1 :0]	log_axi_bvalid								;
  	wire			[P_AXI_CHANNEL_R*1-1 :0]	log_axi_bready								;
  	wire			[P_AXI_CHANNEL_R*32-1:0]	log_axi_araddr								;
  	wire			[P_AXI_CHANNEL_R*3-1 :0]	log_axi_arprot								;
  	wire			[P_AXI_CHANNEL_R*1-1 :0]	log_axi_arvalid								;
  	wire			[P_AXI_CHANNEL_R*1-1 :0]	log_axi_arready								;
  	wire			[P_AXI_CHANNEL_R*32-1:0]	log_axi_rdata								;
  	wire			[P_AXI_CHANNEL_R*2-1 :0]	log_axi_rresp								;
  	wire			[P_AXI_CHANNEL_R*1-1 :0]	log_axi_rvalid								;
  	wire			[P_AXI_CHANNEL_R*1-1 :0]	log_axi_rready                              ;
	/*--------------------------------------------------------------------------------------
	--BANK0 SRIO Base address==32'h0003_0000
	--------------------------------------------------------------------------------------*/
	zt_axilite_cross	#(
		.P_SIMULATION_R							( P_SIMULATION_R							),
		.P_AXI_CHANNEL_R						( P_AXI_CHANNEL_R							),
		.P_CH_LOW_BIT_R							( P_CH_LOW_BIT_R							),
		.P_CH_Start_Addr_R						( P_CH_Start_Addr_R							)
	)
	i_zt_axilite_cross (
		.clk									( log_clk									),
		.rst									( sys_rst				 					),
		.sys_axi_awaddr							( master_axi_awaddr		[2*32 +: 32]		),
		.sys_axi_awprot							( master_axi_awprot		[2* 3 +:  3]		),
		.sys_axi_awvalid						( master_axi_awvalid	[2* 1 +:  1]		),
		.sys_axi_awready						( master_axi_awready	[2* 1 +:  1]		),

		.sys_axi_wdata							( master_axi_wdata		[2*32 +: 32]		),
		.sys_axi_wstrb							( master_axi_wstrb		[2* 4 +:  4]		),
		.sys_axi_wvalid							( master_axi_wvalid		[2* 1 +:  1]		),
		.sys_axi_wready							( master_axi_wready		[2* 1 +:  1]		),

		.sys_axi_bresp							( master_axi_bresp		[2* 2 +:  2]		),
		.sys_axi_bvalid							( master_axi_bvalid		[2* 1 +:  1]		),
		.sys_axi_bready							( master_axi_bready		[2* 1 +:  1]		),

		.sys_axi_araddr							( master_axi_araddr		[2*32 +: 32]		),
		.sys_axi_arprot							( master_axi_arprot		[2* 3 +:  3]		),
		.sys_axi_arvalid						( master_axi_arvalid	[2* 1 +:  1]		),
		.sys_axi_arready						( master_axi_arready	[2* 1 +:  1]		),

		.sys_axi_rdata							( master_axi_rdata		[2*32 +: 32]		),
		.sys_axi_rresp							( master_axi_rresp		[2* 2 +:  2]		),
		.sys_axi_rvalid							( master_axi_rvalid		[2* 1 +:  1]		),
		.sys_axi_rready							( master_axi_rready		[2* 1 +:  1]		),

		.s_axi_awaddr							( log_axi_awaddr							),
		.s_axi_awprot							( log_axi_awprot							),
		.s_axi_awvalid							( log_axi_awvalid							),
		.s_axi_awready							( log_axi_awready							),
		.s_axi_wdata							( log_axi_wdata								),
		.s_axi_wstrb							( log_axi_wstrb								),
		.s_axi_wvalid							( log_axi_wvalid							),
		.s_axi_wready							( log_axi_wready							),
		.s_axi_bresp							( log_axi_bresp								),
		.s_axi_bvalid							( log_axi_bvalid							),
		.s_axi_bready							( log_axi_bready							),
		.s_axi_araddr							( log_axi_araddr							),
		.s_axi_arprot							( log_axi_arprot							),
		.s_axi_arvalid							( log_axi_arvalid							),
		.s_axi_arready							( log_axi_arready							),
		.s_axi_rdata							( log_axi_rdata								),
		.s_axi_rresp							( log_axi_rresp								),
		.s_axi_rvalid							( log_axi_rvalid							),
		.s_axi_rready							( log_axi_rready							)
	);
//==================================================================================================
//--bm_top Instantation
	/*--------------------------------------------------------------------------------------
	--Max support for 2x BM
	--------------------------------------------------------------------------------------*/
`ifdef	ENABLE_BM_ONLY
	bm_top	#(
		.P_SIMULATION_R							( P_SIMULATION_R							)
	)
	i_bm_top (
		.clk									( pcie_clk									),
		.rst									( sys_rst									),
		.srio_rst								( 1'b0										),
		.c_bm_timestamp							( c_bm_timestamp							),
		.c_bm_timestamp_rf						( c_bm_timestamp_rf							),
		.c_bm_en								( {c_bm_chb_en,c_bm_cha_en}					),
		.c_bm_ch_recv_cnt						( {c_bm_chb_recv_cnt,c_bm_cha_recv_cnt}		),
		.c_bm_ch_up_cnt							( {c_bm_chb_up_cnt,c_bm_cha_up_cnt}			),
		.c_bm_ch_lost_cnt						( {c_bm_chb_lost_cnt,c_bm_cha_lost_cnt}		),

		.dma_s_axis_tdata						( dma_s_axis_tdata		[P_BM_DMA_R*64+:64]	),
		.dma_s_axis_tid							( dma_s_axis_tid		[P_BM_DMA_R* 4+: 4]	),
		.dma_s_axis_tready						( dma_s_axis_tready		[P_BM_DMA_R* 1+: 1]	),
		.dma_s_axis_tvalid						( dma_s_axis_tvalid		[P_BM_DMA_R* 1+: 1]	),
		.dma_s_axis_tstrb						( dma_s_axis_tstrb		[P_BM_DMA_R* 8+: 8]	),
		.dma_s_axis_tkeep						( dma_s_axis_tkeep		[P_BM_DMA_R* 8+: 8]	),
		.dma_s_axis_tlast						( dma_s_axis_tlast		[P_BM_DMA_R* 1+: 1]	),
		.dma_s_axis_tuser						( dma_s_axis_tuser		[P_BM_DMA_R*64+:64]	),
		.dma_s_axis_tdest						( dma_s_axis_tdest		[P_BM_DMA_R* 4+: 4]	),
		
		.log_clk								( {2{log_clk}}								),
		.rx_tvalid								( srio_iorx_tvalid			[0* 1+:2* 1]	),
		.rx_tready								( srio_iorx_tready			[0* 1+:2* 1]	),
		.rx_tlast								( srio_iorx_tlast			[0* 1+:2* 1]	),
		.rx_tdata								( srio_iorx_tdata			[0*64+:2*64]	),
		.rx_tkeep								( srio_iorx_tkeep			[0* 8+:2* 8]	),
		.rx_tuser								( srio_iorx_tuser			[0*32+:2*32]	)
	);
`endif

`ifdef	ENABLE_BM_SIM
//==================================================================================================
//--bm_dma Instantation
	bm_top	#(
		.P_SIMULATION_R							( P_SIMULATION_R							)
	)
	i_bm_top (
		.clk									( pcie_clk									),
		.rst									( sys_rst									),
		.srio_rst								( 1'b0										),
		.c_bm_timestamp							( c_bm_timestamp							),
		.c_bm_timestamp_rf						( c_bm_timestamp_rf							),
		.c_bm_en								( {c_bm_chb_en,c_bm_cha_en}					),
		.c_bm_ch_recv_cnt						( {c_bm_chb_recv_cnt,c_bm_cha_recv_cnt}		),
		.c_bm_ch_up_cnt							( {c_bm_chb_up_cnt,c_bm_cha_up_cnt}			),
		.c_bm_ch_lost_cnt						( {c_bm_chb_lost_cnt,c_bm_cha_lost_cnt}		),

		.dma_s_axis_tdata						( dma_s_axis_tdata		[P_BM_DMA_R*64+:64]	),
		.dma_s_axis_tid							( dma_s_axis_tid		[P_BM_DMA_R* 4+: 4]	),
		.dma_s_axis_tready						( dma_s_axis_tready		[P_BM_DMA_R* 1+: 1]	),
		.dma_s_axis_tvalid						( dma_s_axis_tvalid		[P_BM_DMA_R* 1+: 1]	),
		.dma_s_axis_tstrb						( dma_s_axis_tstrb		[P_BM_DMA_R* 8+: 8]	),
		.dma_s_axis_tkeep						( dma_s_axis_tkeep		[P_BM_DMA_R* 8+: 8]	),
		.dma_s_axis_tlast						( dma_s_axis_tlast		[P_BM_DMA_R* 1+: 1]	),
		.dma_s_axis_tuser						( dma_s_axis_tuser		[P_BM_DMA_R*64+:64]	),
		.dma_s_axis_tdest						( dma_s_axis_tdest		[P_BM_DMA_R* 4+: 4]	),
		
		.log_clk								( {2{log_clk}}								),
		.rx_tvalid								( srio_iorx_tvalid			[0* 1+:1* 1]	),
		.rx_tready								( srio_iorx_tready			[0* 1+:1* 1]	),
		.rx_tlast								( srio_iorx_tlast			[0* 1+:1* 1]	),
		.rx_tdata								( srio_iorx_tdata			[0*64+:1*64]	),
		.rx_tkeep								( srio_iorx_tkeep			[0* 8+:1* 8]	),
		.rx_tuser								( srio_iorx_tuser			[0*32+:1*32]	)
	);
`endif

//==================================================================================================
//--SIM Channel inst
	/*--------------------------------------------------------------------------------------
	--Only in BM Only??SP Not to instance
	--------------------------------------------------------------------------------------*/

genvar i;
`ifdef	ENABLE_BM_ONLY
	assign	srio_iotx_tvalid					= 0											;
	assign	srio_iotx_tlast						= 0											;
	assign	srio_iotx_tdata						= 0											;
	assign	srio_iotx_tkeep						= 0											;
	assign	srio_iotx_tuser						= 0											;
	
	assign	srio_iorx_tready					= {{P_Srio_CH_NUM_R}{1'b1}}					;
`else
generate for(i=0;i<P_Srio_CH_NUM_R;i=i+1) begin:i_SP_COND_G
 if(i==0)begin
	sp_cond_top	#(
		.P_SIMULATION_R							( P_SIMULATION_R							)
	)
	i_sp_cond_top (
		.clk									( pcie_clk									),

		.log_clk								( log_clk									),
		.rst									( sys_rst									),
		.srio_rst								( 1'b0										),

		.dma_s_axis_tdata						( dma_s_axis_tdata			[i*64+:64]		),
		.dma_s_axis_tid							( dma_s_axis_tid			[i* 4+: 4]		),
		.dma_s_axis_tready						( dma_s_axis_tready			[i* 1+: 1]		),
		.dma_s_axis_tvalid						( dma_s_axis_tvalid			[i* 1+: 1]		),
		.dma_s_axis_tstrb						( dma_s_axis_tstrb			[i* 8+: 8]		),
		.dma_s_axis_tkeep						( dma_s_axis_tkeep			[i* 8+: 8]		),
		.dma_s_axis_tlast						( dma_s_axis_tlast			[i* 1+: 1]		),
		.dma_s_axis_tuser						( dma_s_axis_tuser			[i*64+:64]		),
		.dma_s_axis_tdest						( dma_s_axis_tdest			[i* 4+: 4]		),

		.dma_m_axis_tdata						( dma_m_axis_tdata			[i*64+:64]		),
		.dma_m_axis_tid							( dma_m_axis_tid			[i* 4+: 4]		),
		.dma_m_axis_tready						( dma_m_axis_tready			[i* 1+: 1]		),
		.dma_m_axis_tvalid						( dma_m_axis_tvalid			[i* 1+: 1]		),
		.dma_m_axis_tstrb						( dma_m_axis_tstrb			[i* 8+: 8]		),
		.dma_m_axis_tkeep						( dma_m_axis_tkeep			[i* 8+: 8]		),
		.dma_m_axis_tlast						( dma_m_axis_tlast			[i* 1+: 1]		),
		.dma_m_axis_tuser						( dma_m_axis_tuser			[i*64+:64]		),
		.dma_m_axis_tdest						( dma_m_axis_tdest			[i* 4+: 4]		),
		
		.c_sp_dn_cnt							( c_sp_dn_cnt				[i*32+:32]		),
		.c_sp_up_cnt							( c_sp_up_cnt				[i*32+:32]		),
		.c_sp_rx_cnt							( c_sp_rx_cnt				[i*32+:32]		),
		.c_sp_tx_cnt							( c_sp_tx_cnt				[i*32+:32]		),
		
		.sr_iotx_tvalid							( srio_iotx_tvalid			[i* 1+: 1]		),
		.sr_iotx_tready							( srio_iotx_tready			[i* 1+: 1]		),
		.sr_iotx_tlast							( srio_iotx_tlast			[i* 1+: 1]		),
		.sr_iotx_tdata							( srio_iotx_tdata			[i*64+:64]		),
		.sr_iotx_tkeep							( srio_iotx_tkeep			[i* 8+: 8]		),
		.sr_iotx_tuser							( srio_iotx_tuser			[i*32+:32]		),

		.sr_iorx_tvalid							( srio_iorx_tvalid			[i* 1+: 1]		),
		.sr_iorx_tready							( srio_iorx_tready			[i* 1+: 1]		),
		.sr_iorx_tlast							( srio_iorx_tlast			[i* 1+: 1]		),
		.sr_iorx_tdata							( srio_iorx_tdata			[i*64+:64]		),
		.sr_iorx_tkeep							( srio_iorx_tkeep			[i* 8+: 8]		),
		.sr_iorx_tuser							( srio_iorx_tuser			[i*32+:32]		)
	);
	end else begin
	sp_cond_top	#(
		.P_SIMULATION_R							( P_SIMULATION_R							)
	)
	i_sp_cond_top (
		.clk									( pcie_clk									),

		.log_clk								( log_clk									),
		.rst									( sys_rst									),
		.srio_rst								( 1'b0										),

		.dma_s_axis_tdata						( dma_s_axis_tdata			[i*64+:64]		),
		.dma_s_axis_tid							( dma_s_axis_tid			[i* 4+: 4]		),
		.dma_s_axis_tready						( dma_s_axis_tready			[i* 1+: 1]		),
		.dma_s_axis_tvalid						( dma_s_axis_tvalid			[i* 1+: 1]		),
		.dma_s_axis_tstrb						( dma_s_axis_tstrb			[i* 8+: 8]		),
		.dma_s_axis_tkeep						( dma_s_axis_tkeep			[i* 8+: 8]		),
		.dma_s_axis_tlast						( dma_s_axis_tlast			[i* 1+: 1]		),
		.dma_s_axis_tuser						( dma_s_axis_tuser			[i*64+:64]		),
		.dma_s_axis_tdest						( dma_s_axis_tdest			[i* 4+: 4]		),

		.dma_m_axis_tdata						( dma_m_axis_tdata			[i*64+:64]		),
		.dma_m_axis_tid							( dma_m_axis_tid			[i* 4+: 4]		),
		.dma_m_axis_tready						( dma_m_axis_tready			[i* 1+: 1]		),
		.dma_m_axis_tvalid						( dma_m_axis_tvalid			[i* 1+: 1]		),
		.dma_m_axis_tstrb						( dma_m_axis_tstrb			[i* 8+: 8]		),
		.dma_m_axis_tkeep						( dma_m_axis_tkeep			[i* 8+: 8]		),
		.dma_m_axis_tlast						( dma_m_axis_tlast			[i* 1+: 1]		),
		.dma_m_axis_tuser						( dma_m_axis_tuser			[i*64+:64]		),
		.dma_m_axis_tdest						( dma_m_axis_tdest			[i* 4+: 4]		),
		
		.c_sp_dn_cnt							( c_sp_dn_cnt				[i*32+:32]		),
		.c_sp_up_cnt							( c_sp_up_cnt				[i*32+:32]		),
		.c_sp_rx_cnt							( c_sp_rx_cnt				[i*32+:32]		),
		.c_sp_tx_cnt							( c_sp_tx_cnt				[i*32+:32]		),
		
		.sr_iotx_tvalid							( srio_iotx_tvalid			[i* 1+: 1]		),
		.sr_iotx_tready							( srio_iotx_tready			[i* 1+: 1]		),
		.sr_iotx_tlast							( srio_iotx_tlast			[i* 1+: 1]		),
		.sr_iotx_tdata							( srio_iotx_tdata			[i*64+:64]		),
		.sr_iotx_tkeep							( srio_iotx_tkeep			[i* 8+: 8]		),
		.sr_iotx_tuser							( srio_iotx_tuser			[i*32+:32]		),

		//.sr_iorx_tready							( 1'b1		),

		.sr_iorx_tvalid							( 1'b0		),
	//	.sr_iorx_tready							( srio_iorx_tready			[i* 1+: 1]		),
		.sr_iorx_tlast							( srio_iorx_tlast			[i* 1+: 1]		),
		.sr_iorx_tdata							( srio_iorx_tdata			[i*64+:64]		),
		.sr_iorx_tkeep							( srio_iorx_tkeep			[i* 8+: 8]		),
		.sr_iorx_tuser							( srio_iorx_tuser			[i*32+:32]		)
	);
	
		assign	srio_iorx_tready			[i* 1+: 1]					= 				srio_vx1_r_axis_tready	;	
		assign	srio_vx1_r_axis_tdata			= srio_iorx_tdata			[i*64+:64]							;		
		assign	srio_vx1_r_axis_tvalid			=  srio_iorx_tvalid			[i* 1+: 1]						;	
		assign	srio_vx1_r_axis_tlast			= srio_iorx_tlast			[i* 1+: 1]							;		
		assign	srio_vx1_r_axis_tuser			= srio_iorx_tuser			[i*32+:32]								;		
	                   
	    assign		srio_vx1_r_axis_aclk			=    log_clk							;         
	                   
		end
	
end
endgenerate
`endif
	
	wire			[P_Srio_CH_NUM_R*32-1:0]	c_bm_ch_recv_cnt							;
	wire			[P_Srio_CH_NUM_R*32-1:0]	c_bm_ch_lost_cnt							;
	wire			[P_Srio_CH_NUM_R*32-1:0]	c_bm_ch_up_cnt								;
	wire			[P_Srio_CH_NUM_R* 1-1:0]	c_bm_en										;
	
	assign	c_bm_ch_recv_cnt					=	{
														{{P_Srio_CH_NUM_R-2}{32'b0}}		,
														c_bm_chb_recv_cnt					,
														c_bm_cha_recv_cnt
													}										;
	
	assign	c_bm_ch_up_cnt						=	{
														{{P_Srio_CH_NUM_R-2}{32'b0}}		,
														c_bm_chb_up_cnt						, // FIXED: was c_bm_chb_lost_cnt
														c_bm_cha_up_cnt						// FIXED: was c_bm_cha_lost_cnt
													}										;
													
	assign	c_bm_ch_lost_cnt					=	{
														{{P_Srio_CH_NUM_R-2}{32'b0}}		,
														c_bm_chb_lost_cnt					,
														c_bm_cha_lost_cnt
													}										;
	assign	c_bm_cha_en							= c_bm_en[0]								;
	assign	c_bm_chb_en							= c_bm_en[1]								;
	
	



//generate for(i=0;i<P_Srio_CH_NUM_R;i=i+1) begin:i_SP_CONFIG_G
	sp_config_top	#(
		.P_SIMULATION_R							( P_SIMULATION_R							)
	)
	ia_sp_config_top (
		.log_clk								( log_clk									),
		.rst									( sys_rst									),
		.srio_rst								( 1'b0										),

		.port_error								( srio_port_error			[0* 1+: 1]		),
		.port_initialized						( srio_port_initialized		[0* 1+: 1]		),
		.link_initialized						( srio_link_initialized		[0* 1+: 1]		),
		.mode_1x								( srio_mode_1x				[0* 1+: 1]		),
		.force_reinit							( srio_force_reinit			[0* 1+: 1]		),
		
		.sys_axi_awaddr							( log_axi_awaddr			[0*32+:32]		),
		.sys_axi_awprot							( log_axi_awprot			[0* 3+: 3]		),
		.sys_axi_awvalid						( log_axi_awvalid			[0* 1+: 1]		),
		.sys_axi_awready						( log_axi_awready			[0* 1+: 1]		),
		.sys_axi_wdata							( log_axi_wdata				[0*32+:32]		),
		.sys_axi_wstrb							( log_axi_wstrb				[0* 4+: 4]		),
		.sys_axi_wvalid							( log_axi_wvalid			[0* 1+: 1]		),
		.sys_axi_wready							( log_axi_wready			[0* 1+: 1]		),
		.sys_axi_bresp							( log_axi_bresp				[0* 2+: 2]		),
		.sys_axi_bvalid							( log_axi_bvalid			[0* 1+: 1]		),
		.sys_axi_bready							( log_axi_bready			[0* 1+: 1]		),
		.sys_axi_araddr							( log_axi_araddr			[0*32+:32]		),
		.sys_axi_arprot							( log_axi_arprot			[0* 3+: 3]		),
		.sys_axi_arvalid						( log_axi_arvalid			[0* 1+: 1]		),
		.sys_axi_arready						( log_axi_arready			[0* 1+: 1]		),
		.sys_axi_rdata							( log_axi_rdata				[0*32+:32]		),
		.sys_axi_rresp							( log_axi_rresp				[0* 2+: 2]		),
		.sys_axi_rvalid							( log_axi_rvalid			[0* 1+: 1]		),
		.sys_axi_rready							( log_axi_rready			[0* 1+: 1]		),
		
		.c_sp_rx_cnt							( c_sp_rx_cnt				[0*32+:32]		),
		.c_sp_tx_cnt							( c_sp_tx_cnt				[0*32+:32]		),
		
		.c_bm_recv_cnt							( c_bm_ch_recv_cnt			[0*32+:32]		),
		.c_bm_lost_cnt							( c_bm_ch_lost_cnt			[0*32+:32]		),
		.c_bm_up_cnt							( c_bm_ch_up_cnt			[0*32+:32]		),
		.c_bm_en								( c_bm_en					[0* 1+: 1]		),
			
		.maintr_rst								( sa_srio_maintr_rst		[0* 1+: 1]		),
		.maintr_awvalid							( sa_srio_maintr_awvalid	[0* 1+: 1]		),
		.maintr_awready  						( sa_srio_maintr_awready	[0* 1+: 1]		),
		.maintr_awaddr   						( sa_srio_maintr_awaddr	    [0*32+:32]		),
		.maintr_wvalid   						( sa_srio_maintr_wvalid	    [0* 1+: 1]		),
		.maintr_wready   						( sa_srio_maintr_wready	    [0* 1+: 1]		),
		.maintr_wdata    						( sa_srio_maintr_wdata		[0*32+:32]		),
		.maintr_bvalid   						( sa_srio_maintr_bvalid	    [0* 1+: 1]		),
		.maintr_bready   						( sa_srio_maintr_bready	    [0* 1+: 1]		),
		.maintr_bresp    						( sa_srio_maintr_bresp		[0* 2+: 2]		),
		.maintr_arvalid  						( sa_srio_maintr_arvalid	[0* 1+: 1]		),
		.maintr_arready  						( sa_srio_maintr_arready	[0* 1+: 1]		),
		.maintr_araddr   						( sa_srio_maintr_araddr	    [0*32+:32]		),
		.maintr_rvalid   						( sa_srio_maintr_rvalid	    [0* 1+: 1]		),
		.maintr_rready   						( sa_srio_maintr_rready	    [0* 1+: 1]		),
		.maintr_rdata    						( sa_srio_maintr_rdata		[0*32+:32]		),
		.maintr_rresp    						( sa_srio_maintr_rresp		[0* 2+: 2]		)
	);
	
	sp_config_top	#(
		.P_SIMULATION_R							( P_SIMULATION_R							)
	)
	ib_sp_config_top (
		.log_clk								( log_clk									),
		.rst									( sys_rst									),
		.srio_rst								( 1'b0										),

		.port_error								( srio_port_error			[1* 1+: 1]		),
		.port_initialized						( srio_port_initialized		[1* 1+: 1]		),
		.link_initialized						( srio_link_initialized		[1* 1+: 1]		),
		.mode_1x								( srio_mode_1x				[1* 1+: 1]		),
		.force_reinit							( srio_force_reinit			[1* 1+: 1]		),
		
		.sys_axi_awaddr							( log_axi_awaddr			[1*32+:32]		),
		.sys_axi_awprot							( log_axi_awprot			[1* 3+: 3]		),
		.sys_axi_awvalid						( log_axi_awvalid			[1* 1+: 1]		),
		.sys_axi_awready						( log_axi_awready			[1* 1+: 1]		),
		.sys_axi_wdata							( log_axi_wdata				[1*32+:32]		),
		.sys_axi_wstrb							( log_axi_wstrb				[1* 4+: 4]		),
		.sys_axi_wvalid							( log_axi_wvalid			[1* 1+: 1]		),
		.sys_axi_wready							( log_axi_wready			[1* 1+: 1]		),
		.sys_axi_bresp							( log_axi_bresp				[1* 2+: 2]		),
		.sys_axi_bvalid							( log_axi_bvalid			[1* 1+: 1]		),
		.sys_axi_bready							( log_axi_bready			[1* 1+: 1]		),
		.sys_axi_araddr							( log_axi_araddr			[1*32+:32]		),
		.sys_axi_arprot							( log_axi_arprot			[1* 3+: 3]		),
		.sys_axi_arvalid						( log_axi_arvalid			[1* 1+: 1]		),
		.sys_axi_arready						( log_axi_arready			[1* 1+: 1]		),
		.sys_axi_rdata							( log_axi_rdata				[1*32+:32]		),
		.sys_axi_rresp							( log_axi_rresp				[1* 2+: 2]		),
		.sys_axi_rvalid							( log_axi_rvalid			[1* 1+: 1]		),
		.sys_axi_rready							( log_axi_rready			[1* 1+: 1]		),
		
		.c_sp_rx_cnt							( c_sp_rx_cnt				[1*32+:32]		),
		.c_sp_tx_cnt							( c_sp_tx_cnt				[1*32+:32]		),
		
		.c_bm_recv_cnt							( c_bm_ch_recv_cnt			[1*32+:32]		),
		.c_bm_lost_cnt							( c_bm_ch_lost_cnt			[1*32+:32]		),
		.c_bm_up_cnt							( c_bm_ch_up_cnt			[1*32+:32]		),
		.c_bm_en								( c_bm_en					[1* 1+: 1]		),
			
		.maintr_rst								( sb_srio_maintr_rst		[0* 1+: 1]		),
		.maintr_awvalid							( sb_srio_maintr_awvalid	[0* 1+: 1]		),
		.maintr_awready  						( sb_srio_maintr_awready	[0* 1+: 1]		),
		.maintr_awaddr   						( sb_srio_maintr_awaddr	    [0*32+:32]		),
		.maintr_wvalid   						( sb_srio_maintr_wvalid	    [0* 1+: 1]		),
		.maintr_wready   						( sb_srio_maintr_wready	    [0* 1+: 1]		),
		.maintr_wdata    						( sb_srio_maintr_wdata		[0*32+:32]		),
		.maintr_bvalid   						( sb_srio_maintr_bvalid	    [0* 1+: 1]		),
		.maintr_bready   						( sb_srio_maintr_bready	    [0* 1+: 1]		),
		.maintr_bresp    						( sb_srio_maintr_bresp		[0* 2+: 2]		),
		.maintr_arvalid  						( sb_srio_maintr_arvalid	[0* 1+: 1]		),
		.maintr_arready  						( sb_srio_maintr_arready	[0* 1+: 1]		),
		.maintr_araddr   						( sb_srio_maintr_araddr	    [0*32+:32]		),
		.maintr_rvalid   						( sb_srio_maintr_rvalid	    [0* 1+: 1]		),
		.maintr_rready   						( sb_srio_maintr_rready	    [0* 1+: 1]		),
		.maintr_rdata    						( sb_srio_maintr_rdata		[0*32+:32]		),
		.maintr_rresp    						( sb_srio_maintr_rresp		[0* 2+: 2]		)
	);
//end
//engenerate


//	ila_axil	ila_axil_srio_ia(
//		.clk                        			( log_clk								),
//		.probe0                                  ( {
//													ia_sp_config_top.sys_axi_awaddr	       	,
//													ia_sp_config_top.sys_axi_awvalid	   	,
//													ia_sp_config_top.sys_axi_awready	   	,
//													ia_sp_config_top.sys_axi_wdata	       	,
//													ia_sp_config_top.sys_axi_wvalid	       	,
//													ia_sp_config_top.sys_axi_wready	       	,
//													ia_sp_config_top.sys_axi_araddr	       	,
//													ia_sp_config_top.sys_axi_arvalid	   	,
//													ia_sp_config_top.sys_axi_arready	   	,
//													ia_sp_config_top.sys_axi_rdata	       	,
//													ia_sp_config_top.sys_axi_rvalid	       	,
//													ia_sp_config_top.sys_axi_rready	       	

//																							})
//	);		
	
	
//	ila_axil	ila_axil_srio_ib(
//		.clk                        			( log_clk								),
//		.probe0                                  ( {
//													ib_sp_config_top.sys_axi_awaddr	       	,
//													ib_sp_config_top.sys_axi_awvalid	   	,
//													ib_sp_config_top.sys_axi_awready	   	,
//													ib_sp_config_top.sys_axi_wdata	       	,
//													ib_sp_config_top.sys_axi_wvalid	       	,
//													ib_sp_config_top.sys_axi_wready	       	,
//													ib_sp_config_top.sys_axi_araddr	       	,
//													ib_sp_config_top.sys_axi_arvalid	   	,
//													ib_sp_config_top.sys_axi_arready	   	,
//													ib_sp_config_top.sys_axi_rdata	       	,
//													ib_sp_config_top.sys_axi_rvalid	       	,
//													ib_sp_config_top.sys_axi_rready	       	

//																							})
//	);		
		

//==================================================================================================
//--Flash
    	axi_lite_no_used	#( .P_num	( 1	)	 	 ) u_axi_nouseqspi(
		.reg_cfg_aclk							( flash_clk									),
		.reg_cfg_aresetn						( ~sys_rst_n_in_c									),
		
		.reg_cfg_awaddr							( master_axi_awaddr	    	[1*32 +: 32]	    ),
		.reg_cfg_awvalid						( master_axi_awvalid		[1* 1 +:  1]	),
		.reg_cfg_awready						( master_axi_awready		[1* 1 +:  1]	),
		.reg_cfg_wdata							( master_axi_wdata	    	[1*32 +: 32]	    ),
		.reg_cfg_wstrb							( master_axi_wstrb	    	[1* 4 +:  4]	    ),
		.reg_cfg_wvalid							( master_axi_wvalid	    	[1* 1 +:  1]	    ),
		.reg_cfg_wready							( master_axi_wready	    	[1* 1 +:  1]	    ),
		.reg_cfg_bresp							( master_axi_bresp	    	[1* 2 +:  2]	    ),
		.reg_cfg_bvalid							( master_axi_bvalid	    	[1* 1 +:  1]	    ),
		.reg_cfg_bready							( master_axi_bready	    	[1* 1 +:  1]	    ),
		.reg_cfg_araddr							( master_axi_araddr	    	[1*32 +: 32]	    ),
		.reg_cfg_arvalid						( master_axi_arvalid		[1* 1 +:  1]	),
		.reg_cfg_arready						( master_axi_arready		[1* 1 +:  1]	),
		.reg_cfg_rdata							( master_axi_rdata	    	[1*32 +: 32]	    ),
		.reg_cfg_rresp							( master_axi_rresp	    	[1* 2 +:  2]	    ),
		.reg_cfg_rvalid							( master_axi_rvalid	    	[1* 1 +:  1]	    ),
		.reg_cfg_rready							( master_axi_rready     	[1* 1 +:  1]	)
    );


endmodule
