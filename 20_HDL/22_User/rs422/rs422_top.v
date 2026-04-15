// ============================================================================
// 维护注释
//   文件职责      : RS422 收发与 AXI-Lite 控制逻辑。
//   源码属性      : 手工维护源码，不要把修改同步到生成 IP 或网表。
//   更新要求      : 当时钟、复位、接口或数据顺序假设变化时，同步更新注释。
//   维护边界      : 注释用于说明当前实现意图，不替代接口协议文档。
// ============================================================================
                                                                                                                                                                                                                                                                                                                                                                         `timescale 1ns/1ns
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
//		妯″潡瀹炵幇AXI Master鐨勫彂閫?
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
//--杈撳叆杈撳嚭绔彛瀹氫箟---------------------------
	/*--------------------------------------------------------------------------------------
	--Common Interface
	--|log_clk-->鍙互杩炴帴a锛屼篃鍙互杩炴帴澶栭儴鏃堕挓锛岃繘琛屽揩閫熸煡璇㈠鐞?
	--|rst-->澶嶄綅淇″彿锛岄珮鐢靛钩鍚屾澶嶄綅淇″彿
	--------------------------------------------------------------------------------------*/
	input										clk											,
	input										rst											,

	/*--------------------------------------------------------------------------------------
	--RS422淇″彿瀹氫箟
	--------------------------------------------------------------------------------------*/
	output										rs422_tx_out								,
	input										rs422_rx_in									,
	output										rs422_de							,
	
//==================================================================================================



	output										rx_fifo_empty								,
//--AXI Lite瀵勫瓨鍣ㄦ柟鍚?
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
//--淇″彿瀹氫箟
	/*--------------------------------------------------------------------------------------
	--AXI_LITE妯″潡鎺ュ彛
	--------------------------------------------------------------------------------------*/	
	wire			[31:0]						c_rs422_baud_rate							;	//娉㈢壒鐜囬厤缃瘎瀛樺櫒
	wire										c_rs422_parity_en							;	//濂囧伓鏍￠獙浣嶄娇鑳?
	wire										c_rs422_parity_sel							;	//濂囧伓鏍￠獙閫夋嫨=0锛屽鏍￠獙
	wire			[2:0]						c_rs422_stop_width							;	//鍋滄浣嶄綅瀹斤紝1~3,0鏃犳晥
	
	/*--------------------------------------------------------------------------------------
	--RX鎺ュ彛
	--------------------------------------------------------------------------------------*/	
	wire										rx_fifo_ren									;
	wire			[31:0]						rx_fifo_dout								;
//	wire										rx_fifo_empty								;
	wire			[31:0]						rx_fifo_status								;
	
	/*--------------------------------------------------------------------------------------
	--TX鎺ュ彛
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
