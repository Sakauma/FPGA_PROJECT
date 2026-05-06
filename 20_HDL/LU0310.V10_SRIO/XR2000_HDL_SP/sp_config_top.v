 `timescale 1ns/1ns
// ============================================================================
// 新增维护说明
// 作者          : Egor Izmaylov
// 文件职责      : 当前文件为手工维护源码，具体职责见模块名、端口和上层实例化。
// 维护边界      : 只追加说明性注释；Vivado/IP 生成物和第三方支撑代码不在此处手改。
// 修改约束      : 功能改动需同步更新仿真、综合结果和相关文档。
// ============================================================================
//////////////////////////////////////////////////////////////////////////////////
// Company:			HXZY
// Engineer:		ZYL
// Create Date:		2020/3/4 9:15:07
// Design Name:		XR2000
// Module Name:		spb_top-SrioPCIeBridge_TOP
// Project Name:
// Target Devices:	K7-V7
// Tool Versions: 	Vivado 2016.1 HDL-EDIT UltraEdit TAB=4 Consolas
// Description:
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
//////////////////////////////////////////////////////////////////////////////////
module sp_config_top #(
	/*--------------------------------------------------------------------------------------
	--P_SIMULATION_R
	---------------------------------------------------------------------------------------*/
	parameter		P_SIMULATION_R				= "FALSE"									,
	parameter		P_BIG_CACHE_R				= "FALSE"
	)(
//==================================================================================================
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
	/*--------------------------------------------------------------------------------------
	--Common Interface
	* 历史说明：原块注释编码已损坏，按当前文件头和开发文档维护。
	* 历史说明：原块注释编码已损坏，按当前文件头和开发文档维护。
	--------------------------------------------------------------------------------------*/
	input										rst											,
	input										srio_rst									,

	input										log_clk										,
	/*--------------------------------------------------------------------------------------
	--link
	--------------------------------------------------------------------------------------*/
	input										link_initialized							,
	input										port_initialized							,
	input										port_error									,
	input										mode_1x										,
	output										force_reinit								,
	/*--------------------------------------------------------------------------------------
	--Write Address Channel Signals
	--------------------------------------------------------------------------------------*/
	input			[32-1:0]					sys_axi_awaddr								,
  	input			[3-1:0]						sys_axi_awprot								,
  	input			[1-1:0]						sys_axi_awvalid								,
  	output			[1-1:0]						sys_axi_awready								,

	/*--------------------------------------------------------------------------------------
	--Write Data Channel Signals
	--------------------------------------------------------------------------------------*/
  	input			[31:0]						sys_axi_wdata								,
  	input			[ 3:0]						sys_axi_wstrb								,
  	input										sys_axi_wvalid								,
  	output										sys_axi_wready								,

	/*--------------------------------------------------------------------------------------
	--Write Response Channel Signals
	--------------------------------------------------------------------------------------*/
  	output			[ 1:0]						sys_axi_bresp								,
  	output										sys_axi_bvalid								,
  	input										sys_axi_bready								,

	/*--------------------------------------------------------------------------------------
	--Read Address Channel Signals
	--------------------------------------------------------------------------------------*/
  	input			[31:0]						sys_axi_araddr								,
  	input			[ 2:0]						sys_axi_arprot								,
  	input										sys_axi_arvalid								,
  	output	wire								sys_axi_arready								,

	/*--------------------------------------------------------------------------------------
	--Read Address Channel Signals
	--------------------------------------------------------------------------------------*/
  	output			[31:0]						sys_axi_rdata								,
  	output			[ 1:0]						sys_axi_rresp								,
  	output										sys_axi_rvalid								,
  	input										sys_axi_rready								,
//==================================================================================================
//--SIM Count
	input			[31:0]						c_sp_rx_cnt									,
	input			[31:0]						c_sp_tx_cnt									,
	
//==================================================================================================
//--BM Count
	input			[31:0]						c_bm_recv_cnt								,
	input			[31:0]						c_bm_up_cnt									,
	input			[31:0]						c_bm_lost_cnt								,
	output										c_bm_en										,	
	
//==================================================================================================
//--SRIO Reduncy Signals
	/*--------------------------------------------------------------------------------------
	* 历史说明：原块注释编码已损坏，按当前文件头和开发文档维护。
	--------------------------------------------------------------------------------------*/
	output										maintr_rst									,
	output             							maintr_awvalid								,
    input            							maintr_awready								,
    output			[31:0]  					maintr_awaddr								,
    output             							maintr_wvalid								,
    input            							maintr_wready								,
    output			[31:0]  					maintr_wdata								,
    input            							maintr_bvalid								,
    output             							maintr_bready								,
    input			[ 1:0]   					maintr_bresp								,

    output             							maintr_arvalid								,
    input            							maintr_arready								,
    output			[31:0]  					maintr_araddr								,
    input            							maintr_rvalid								,
    output             							maintr_rready								,
    input			[31:0]  					maintr_rdata								,
    input			[ 1:0]   					maintr_rresp
	);
//==================================================================================================
//--signals defines
	/*--------------------------------------------------------------------------------------
	--regfile signals output
	--------------------------------------------------------------------------------------*/	  	
	wire			[31:0]						reg_waddr									;
	wire										reg_wvalid									;
	wire			[31:0]						reg_wdata									;
	
	wire			[31:0]						reg_raddr									;
	wire			[31:0]						reg_rdata                                   ;

	wire			[31:0]						reg_srio_reset_time_c						;
	wire										reg_srio_reset_enable_c						;
	wire										reg_srio_reset_trig_c						;
	
	
	/*--------------------------------------------------------------------------------------
	* 历史说明：原块注释编码已损坏，按当前文件头和开发文档维护。
	--------------------------------------------------------------------------------------*/
	wire										c_s_m_rst									;
	
	wire			[31:0]						c_s_m_waddr									;
	wire			[31:0]						c_s_m_wdata									;
	wire										c_s_m_wstart								;
	wire										c_s_m_wdone									;
	wire			[1:0]						c_s_m_wstatus_set							;
                                                                                        	
	wire			[31:0]						c_s_m_raddr									;
	wire										c_s_m_rstart								;
	wire										c_s_m_rdone									;
	wire			[31:0]						c_s_m_rdata_set								;
	wire			[1:0]						c_s_m_rstatus_set							;

	
	sp_maintr	#(
		.P_SIMULATION_R							( P_SIMULATION_R							)
	)
	i_sp_maintr(
		.rst									( rst										),
		.log_clk								( log_clk									),

		.c_s_m_waddr							( c_s_m_waddr		    					),
		.c_s_m_wdata							( c_s_m_wdata		    					),
		.c_s_m_wstart							( c_s_m_wstart		    					),
		.c_s_m_wdone							( c_s_m_wdone		    					),
		.c_s_m_wstatus_set						( c_s_m_wstatus_set							),
		.c_s_m_raddr							( c_s_m_raddr		    					),
		.c_s_m_rstart							( c_s_m_rstart		    					),
		.c_s_m_rdone							( c_s_m_rdone		    					),
		.c_s_m_rdata_set						( c_s_m_rdata_set	    					),
		.c_s_m_rstatus_set						( c_s_m_rstatus_set							),
		
		.c_s_m_rst								( c_s_m_rst									),
		
		.maintr_rst								( maintr_rst								),
		.maintr_awvalid							( maintr_awvalid	    					),
		.maintr_awready  						( maintr_awready	    					),
		.maintr_awaddr   						( maintr_awaddr	    						),
		.maintr_wvalid   						( maintr_wvalid	    						),
		.maintr_wready   						( maintr_wready	    						),
		.maintr_wdata    						( maintr_wdata								),
		.maintr_bvalid   						( maintr_bvalid	    						),
		.maintr_bready   						( maintr_bready	    						),
		.maintr_bresp    						( maintr_bresp								),
		.maintr_arvalid  						( maintr_arvalid	    					),
		.maintr_arready  						( maintr_arready	    					),
		.maintr_araddr   						( maintr_araddr	    						),
		.maintr_rvalid   						( maintr_rvalid	    						),
		.maintr_rready   						( maintr_rready	    						),
		.maintr_rdata    						( maintr_rdata								),
		.maintr_rresp    						( maintr_rresp								)
	);

	sp_rst	#(
		.P_SIMULATION_R							( P_SIMULATION_R							)
	)
	i_sp_rst (
		.clk									( log_clk									),
		.rst									( rst										),

		.link_initialized						( link_initialized							),

		.reg_srio_reset_time_c					( reg_srio_reset_time_c						),
		.reg_srio_reset_enable_c				( reg_srio_reset_enable_c					),
		.reg_srio_reset_trig_c					( reg_srio_reset_trig_c						),

		.force_reinit							( force_reinit								)
	);
//==================================================================================================
//--zt_axi2reg Instantation
	sp_axi2reg	#(
		.P_SIMULATION_R							( P_SIMULATION_R							)
	)
	i_sp_axi2reg (
		.clk									( log_clk									),
		.rst									( rst										),
		
		.sys_axi_awaddr							( sys_axi_awaddr							),
		.sys_axi_awprot							( sys_axi_awprot							),
		.sys_axi_awvalid						( sys_axi_awvalid							),
		.sys_axi_awready						( sys_axi_awready							),
		.sys_axi_wdata							( sys_axi_wdata								),
		.sys_axi_wstrb							( sys_axi_wstrb								),
		.sys_axi_wvalid							( sys_axi_wvalid							),
		.sys_axi_wready							( sys_axi_wready							),
		.sys_axi_bresp							( sys_axi_bresp								),
		.sys_axi_bvalid							( sys_axi_bvalid							),
		.sys_axi_bready							( sys_axi_bready							),
		.sys_axi_araddr							( sys_axi_araddr							),
		.sys_axi_arprot							( sys_axi_arprot							),
		.sys_axi_arvalid						( sys_axi_arvalid							),
		.sys_axi_arready						( sys_axi_arready							),
		.sys_axi_rdata							( sys_axi_rdata								),
		.sys_axi_rresp							( sys_axi_rresp								),
		.sys_axi_rvalid							( sys_axi_rvalid							),
		.sys_axi_rready							( sys_axi_rready							),
		
		.reg_waddr								( reg_waddr									),
		.reg_wvalid								( reg_wvalid								),
		.reg_wdata								( reg_wdata									),
		.reg_raddr								( reg_raddr									),
		.reg_rdata								( reg_rdata									)
	);
//==================================================================================================
//--sp_regfile Instantation
	sp_regfile	#(
		.P_SIMULATION_R							( P_SIMULATION_R							)
	)
	i_sp_regfile (
		.rst									( rst										),
		.clk									( log_clk									),
		
		.reg_waddr								( reg_waddr									),
		.reg_wvalid								( reg_wvalid								),
		.reg_wdata								( reg_wdata									),
		.reg_raddr								( reg_raddr									),
		.reg_rdata								( reg_rdata									),
		
		.reg_srio_reset_time_c		            ( reg_srio_reset_time_c						),
		.reg_srio_reset_enable_c	            ( reg_srio_reset_enable_c					),    
		.reg_srio_reset_trig_c					( reg_srio_reset_trig_c						),

		
		.port_error								( port_error								),
		.port_initialized						( port_initialized							),
		.link_initialized						( link_initialized							),
		.mode_1x								( mode_1x									),
		
		.c_sp_tx_cnt							( c_sp_tx_cnt								),
		.c_sp_rx_cnt							( c_sp_rx_cnt								),
		
		.c_bm_recv_cnt							( c_bm_recv_cnt								),
		.c_bm_lost_cnt							( c_bm_lost_cnt								),
		.c_bm_up_cnt							( c_bm_up_cnt								),
		.c_bm_en								( c_bm_en									),
		
		.c_s_m_rst								( c_s_m_rst									),
		.c_s_m_waddr							( c_s_m_waddr								),
		.c_s_m_wdata							( c_s_m_wdata								),
		.c_s_m_wstart							( c_s_m_wstart								),
		.c_s_m_wdone							( c_s_m_wdone								),
		.c_s_m_wstatus_set						( c_s_m_wstatus_set							),
		.c_s_m_raddr							( c_s_m_raddr								),
		.c_s_m_rstart							( c_s_m_rstart								),
		.c_s_m_rdone							( c_s_m_rdone								),
		.c_s_m_rdata_set						( c_s_m_rdata_set							),
		.c_s_m_rstatus_set						( c_s_m_rstatus_set							)
	);
	
endmodule
