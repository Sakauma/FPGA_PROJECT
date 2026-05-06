                                                                                                                                                                                                                                                                                                                                                                         `timescale 1ns/1ns
// ============================================================================
// 新增维护说明
// 作者          : Egor Izmaylov
// 文件职责      : 当前文件为手工维护源码，具体职责见模块名、端口和上层实例化。
// 维护边界      : 只追加说明性注释；Vivado/IP 生成物和第三方支撑代码不在此处手改。
// 修改约束      : 功能改动需同步更新仿真、综合结果和相关文档。
// ============================================================================
//////////////////////////////////////////////////////////////////////////////////
// Company:			ZHTY
// Engineer:		ZYL
// Create Date:		2018/5/11 12:08:50
// Design Name:		EC1300
// Module Name:		sr_tx_srio----SrioRedundancy_srio_ip_top
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
module rs422_top #(
	/*--------------------------------------------------------------------------------------
	--SIMULATION
	---------------------------------------------------------------------------------------*/
	parameter									SIMULATION				= "FALSE"
	)(
//==================================================================================================
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
	/*--------------------------------------------------------------------------------------
	--Common Interface
	* 历史说明：原块注释编码已损坏，按当前文件头和开发文档维护。
	* 历史说明：原块注释编码已损坏，按当前文件头和开发文档维护。
	--------------------------------------------------------------------------------------*/
	input										clk											,
	input										rst											,

	/*--------------------------------------------------------------------------------------
	* 历史说明：原块注释编码已损坏，按当前文件头和开发文档维护。
	--------------------------------------------------------------------------------------*/
	output										rs422_tx_out								,
	input										rs422_rx_in									,
	output										rs422_de							,
	
//==================================================================================================



	output										rx_fifo_empty								,
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
	/*--------------------------------------------------------------------------------------
	--Write Data Command Signals
	--------------------------------------------------------------------------------------*/
	input			[31:0]						sys_axi_awaddr								,
  	input			[2:0]						sys_axi_awprot								,
  	input										sys_axi_awvalid								,
  	output										sys_axi_awready								,

	/*--------------------------------------------------------------------------------------
	--Write Data Channel Signals
	--------------------------------------------------------------------------------------*/
  	input			[31:0]						sys_axi_wdata								,
  	input			[3:0]						sys_axi_wstrb								,
  	input										sys_axi_wvalid								,
  	output										sys_axi_wready								,

	/*--------------------------------------------------------------------------------------
	--Write Response Channel Signals
	--------------------------------------------------------------------------------------*/
  	output			[1:0]						sys_axi_bresp								,
  	output										sys_axi_bvalid								,
  	input										sys_axi_bready								,

	/*--------------------------------------------------------------------------------------
	--Read Address Channel Signals
	--------------------------------------------------------------------------------------*/
  	input			[31:0]						sys_axi_araddr								,
  	input			[2:0]						sys_axi_arprot								,
  	input										sys_axi_arvalid								,
  	output	wire								sys_axi_arready								,

	/*--------------------------------------------------------------------------------------
	--Read Address Channel Signals
	--------------------------------------------------------------------------------------*/
  	output			[31:0]						sys_axi_rdata								,
  	output			[1:0]						sys_axi_rresp								,
  	output										sys_axi_rvalid								,
  	input										sys_axi_rready                            ,
  	
	output			[31:0]						int_test								

	);
//==================================================================================================
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
	/*--------------------------------------------------------------------------------------
	* 历史说明：原块注释编码已损坏，按当前文件头和开发文档维护。
	--------------------------------------------------------------------------------------*/	
	wire			[31:0]						c_rs422_baud_rate							;	// 历史说明：原尾注编码已损坏，代码含义以信号名和开发文档为准。
	wire										c_rs422_parity_en							;	// 历史说明：原尾注编码已损坏，代码含义以信号名和开发文档为准。
	wire										c_rs422_parity_sel							;	// 历史说明：原尾注编码已损坏，代码含义以信号名和开发文档为准。
	wire			[2:0]						c_rs422_stop_width							;	// 历史说明：原尾注编码已损坏，代码含义以信号名和开发文档为准。
	
	/*--------------------------------------------------------------------------------------
	* 历史说明：原块注释编码已损坏，按当前文件头和开发文档维护。
	--------------------------------------------------------------------------------------*/	
	wire										rx_fifo_ren									;
	wire			[31:0]						rx_fifo_dout								;
//	wire										rx_fifo_empty								;
	wire			[31:0]						rx_fifo_status								;
	
	/*--------------------------------------------------------------------------------------
	* 历史说明：原块注释编码已损坏，按当前文件头和开发文档维护。
	--------------------------------------------------------------------------------------*/	
	wire										tx_fifo_wen									;
	wire			[31:0]						tx_fifo_din									;
	wire										tx_fifo_full								;
	wire			[31:0]						tx_fifo_status								;
	wire            							rx_fifo_rst									;
	

//==================================================================================================
//--rs422_axilite Instantation
	rs422_axilite	#(
		.SIMULATION								( SIMULATION								)
	)
	i_rs422_axilite (
		.int_test								( int_test										),
	
		.clk									( clk										),
		.rst									( rst										),
		.rx_fifo_rst                            (rx_fifo_rst                                ),
		
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
		
		.c_rs422_baud_rate						( c_rs422_baud_rate							),
		.c_rs422_parity_en						( c_rs422_parity_en							),
		.c_rs422_parity_sel						( c_rs422_parity_sel						),
		.c_rs422_stop_width						( c_rs422_stop_width						),
		
		.tx_fifo_wen							( tx_fifo_wen								),
		.tx_fifo_din							( tx_fifo_din								),
		.tx_fifo_full							( tx_fifo_full								),
		.tx_fifo_status							( tx_fifo_status							),
		
		.rx_fifo_empty							( rx_fifo_empty								),
		.rx_fifo_dout							( rx_fifo_dout								),
		.rx_fifo_ren							( rx_fifo_ren								),
		.rx_fifo_status							( rx_fifo_status							)
	);

//==================================================================================================
//--rs422_tx Instantation
	rs422_tx	#(
		.SIMULATION								( SIMULATION								)
	)
	i_rs422_tx (
		.clk									( clk										),
		.rst									( rst										),
		.c_rs422_baud_rate						( c_rs422_baud_rate							),
		.c_rs422_parity_en						( c_rs422_parity_en							),
		.c_rs422_parity_sel						( c_rs422_parity_sel						),
		.c_rs422_stop_width						( c_rs422_stop_width						),
		
		.rs422_tx								( rs422_tx_out								),
		
		.rs422_de								( rs422_de								   ),
				
		.tx_fifo_wen							( tx_fifo_wen								),
		.tx_fifo_din							( tx_fifo_din								),
		.tx_fifo_full							( tx_fifo_full								),
		.tx_fifo_status							( tx_fifo_status							)
	);


//==================================================================================================
//--rs422_rx Instantation
	rs422_rx	#(
		.SIMULATION								( SIMULATION								)
	)
	i_rs422_rx (
		.clk									( clk										),
		.rst									( rst										),
		.rx_fifo_rst                            (rx_fifo_rst                                ),
		
		.c_rs422_baud_rate						( c_rs422_baud_rate							),
		.c_rs422_parity_en						( c_rs422_parity_en							),
		.c_rs422_parity_sel						( c_rs422_parity_sel						),
		
		.rs422_rx								( rs422_rx_in								),
		
		.rx_fifo_ren							( rx_fifo_ren								),
		.rx_fifo_dout							( rx_fifo_dout								),
		.rx_fifo_empty							( rx_fifo_empty								),
		.rx_fifo_status							( rx_fifo_status							)
	);



endmodule
