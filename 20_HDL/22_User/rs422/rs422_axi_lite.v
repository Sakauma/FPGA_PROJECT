`timescale 1ns/1ns
// ============================================================================
// 维护注释
//   文件职责      : RS422 收发与 AXI-Lite 控制逻辑。
//   源码属性      : 手工维护源码，不要把修改同步到生成 IP 或网表。
//   更新要求      : 当时钟、复位、接口或数据顺序假设变化时，同步更新注释。
//   维护边界      : 注释用于说明当前实现意图，不替代接口协议文档。
// ============================================================================
//////////////////////////////////////////////////////////////////////////////////
// Company:			ZHTY
// Engineer:		ZYL
// Create Date:		2018/5/11 13:20:10
// Design Name:		EC1300
// Module Name:		rs422_axilite
// Project Name:
// Target Devices:	K7-V7
// Tool Versions: 	Vivado 2016.1 HDL-EDIT UltraEdit TAB=4 Consolas
// Description:
//		妯″潡瀹炵幇RS422妯″潡鐨勪富鏈烘帴鍙?
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
//////////////////////////////////////////////////////////////////////////////////
module rs422_axilite #(
	/*--------------------------------------------------------------------------------------
	--SIMULATION
	---------------------------------------------------------------------------------------*/
	parameter			SIMULATION				= "FALSE"
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
	output reg 	 rx_fifo_rst                        ,
//==================================================================================================
//--AXI Lite瀵勫瓨鍣ㄦ柟鍚?
	/*--------------------------------------------------------------------------------------
	--Write Data Command Signals
	--------------------------------------------------------------------------------------*/
	input			[31:0]						sys_axi_awaddr								,
  	input			[ 2:0]						sys_axi_awprot								,
  	input										sys_axi_awvalid								,
  	output										sys_axi_awready								,

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
  	output	reg									sys_axi_bvalid						= 0		,
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
  	output	reg		[31:0]						sys_axi_rdata								,
  	output			[ 1:0]						sys_axi_rresp								,
  	output	reg									sys_axi_rvalid								,
  	input										sys_axi_rready								,

  	/*--------------------------------------------------------------------------------------
	--AXI_LITE妯″潡鎺ュ彛
	--------------------------------------------------------------------------------------*/
	output	reg		[31:0]						c_rs422_baud_rate							,	//娉㈢壒鐜囬厤缃瘎瀛樺櫒
	output	reg									c_rs422_parity_en							,	//濂囧伓鏍￠獙浣嶄娇鑳?
	output	reg									c_rs422_parity_sel							,	//濂囧伓鏍￠獙閫夋嫨=0锛屽鏍￠獙
	output	reg		[ 2:0]						c_rs422_stop_width							,	//鍋滄浣嶄綅瀹斤紝1~3,0鏃犳晥

	/*--------------------------------------------------------------------------------------
	--TX鍙戦€丗IFO淇″彿
	--------------------------------------------------------------------------------------*/
	(*mark_debug="TRUE"*)
	output	reg									tx_fifo_wen									,
	(*mark_debug="TRUE"*)
	output	reg		[31:0]						tx_fifo_din									,
	input										tx_fifo_full								,
	input			[31:0]						tx_fifo_status								,
	
	/*--------------------------------------------------------------------------------------
	--RX鎺ユ敹FIFO淇″彿
	--------------------------------------------------------------------------------------*/	
	(*mark_debug="TRUE"*)
	input										rx_fifo_empty								,
	(*mark_debug="TRUE"*)
	input			[31:0]						rx_fifo_dout								,
	(*mark_debug="TRUE"*)
	output	reg									rx_fifo_ren									,
	input			[31:0]						rx_fifo_status								,
	
	output	reg		[31:0]						int_test								
	
	);
//==================================================================================================
//--Parameter Define
	/*--------------------------------------------------------------------------------------
	--AXI Lite瀵勫瓨鍣ㄩ厤缃亸绉婚噺
	--------------------------------------------------------------------------------------*/
	localparam		OFF_RS422_BAUD				= 12'h000									;
	localparam		OFF_PARITY_EN				= 12'h004									;
	localparam		OFF_PARITY_SEL				= 12'h008									;
	localparam		OFF_STOP_WIDTH				= 12'h00C									;
                                            	                    						
	localparam		OFF_RX_FIFO_DOUT			= 12'h100									;
	localparam		OFF_RX_FIFO_STATUS			= 12'h104									;
	localparam		OFF_TX_FIFO_DIN				= 12'h200									;
	localparam		OFF_TX_FIFO_STATUS			= 12'h204									;
	localparam		OFF_RX_FIFO_RST			    = 12'h300									;	
	

	localparam		OFF_INT_TEST			    = 12'h010									;	

	/*--------------------------------------------------------------------------------------
	--榛樿鐨勬尝鐗圭巼鍙傛暟
	--------------------------------------------------------------------------------------*/	
	localparam		LP_BAUD_RATE_DEF			= (SIMULATION=="TRUE")? 32'd50:32'd10417	;	//榛樿涓?600锛屼互100Mhz涓哄噯璁℃暟
	localparam		LP_STOP_WIDTH				= 3'b001									;	//鍋滄浣嶇殑瀹藉害锛岄粯璁や负1=0
//==================================================================================================
//--Signals Define

//==================================================================================================
//--瀵勫瓨鍣ㄥ啓瀹炵幇
    reg 			[31:0]  					lite_axi_awaddr_r   			= 0			;       
    reg 			[31:0]  					lite_axi_wdata_r   				= 0			;  
    reg											lite_aw_valid					= 0			;
    reg             				   			lite_w_valid                    = 0        	;
    
	wire	WS_RS422_BAUD						= lite_axi_awaddr_r[11:0]==OFF_RS422_BAUD	;
	wire	WS_TX_FIFO_DIN						= lite_axi_awaddr_r[11:0]==OFF_TX_FIFO_DIN	;
	wire	WS_PARITY_EN						= lite_axi_awaddr_r[11:0]==OFF_PARITY_EN	;
	wire	WS_PARITY_SEL					 	= lite_axi_awaddr_r[11:0]==OFF_PARITY_SEL	;
	wire	WS_STOP_WIDTH						= lite_axi_awaddr_r[11:0]==OFF_STOP_WIDTH	;
	wire	WS_RX_FIFO_RST						= lite_axi_awaddr_r[11:0]==OFF_RX_FIFO_RST	;
	
	wire	WS_INT_TEST						= lite_axi_awaddr_r[11:0]==OFF_INT_TEST	;
	
	
	/*--------------------------------------------------------------------------------------
	--涓柇娴嬭瘯int_test
	--------------------------------------------------------------------------------------*/
	always @(posedge clk or posedge rst) begin
		if(rst) begin
			int_test					<= 32'b0							;
		end else if(lite_aw_valid && lite_w_valid && WS_INT_TEST) begin
			int_test					<= lite_axi_wdata_r[31:0]					;
		end else begin
			int_test					<=  32'b0						;
		end
	end	
	
	/*--------------------------------------------------------------------------------------
	--娉㈢壒鐜囦富鏈洪厤缃疄鐜?
	--------------------------------------------------------------------------------------*/
	always @(posedge clk or posedge rst) begin
		if(rst) begin
			c_rs422_baud_rate					<= LP_BAUD_RATE_DEF							;
		end else if(lite_aw_valid && lite_w_valid && WS_RS422_BAUD) begin
			c_rs422_baud_rate					<= lite_axi_wdata_r[31:0]					;
		end else begin
			c_rs422_baud_rate					<= c_rs422_baud_rate						;
		end
	end
	/*--------------------------------------------------------------------------------------
	--濂囧伓鏍￠獙浣胯兘閰嶇疆
	--------------------------------------------------------------------------------------*/
	always @(posedge clk or posedge rst) begin
		if(rst) begin
			c_rs422_parity_en					<= 1'b0										;
		end else if(lite_aw_valid && lite_w_valid && WS_PARITY_EN) begin
			c_rs422_parity_en					<= lite_axi_wdata_r[0]						;
		end else begin
			c_rs422_parity_en					<= c_rs422_parity_en						;
		end
	end
	/*--------------------------------------------------------------------------------------
	--濂囨牎楠屻€佸伓鏍￠獙閫夋嫨淇″彿=0-濂囨牎楠岋紝=1-鍋舵牎楠?
	--------------------------------------------------------------------------------------*/
	always @(posedge clk or posedge rst) begin
		if(rst) begin
			c_rs422_parity_sel					<= 1'b0										;
		end else if(lite_aw_valid && lite_w_valid && WS_PARITY_SEL) begin
			c_rs422_parity_sel					<= lite_axi_wdata_r[0]						;
		end else begin
			c_rs422_parity_sel					<= c_rs422_parity_sel						;
		end
	end
	/*--------------------------------------------------------------------------------------
	--缁撴潫鏍囧織浣嶅锛堟尝鐗圭巼浣嶅锛?
	--------------------------------------------------------------------------------------*/
	always @(posedge clk or posedge rst) begin
		if(rst) begin
			c_rs422_stop_width					<= LP_STOP_WIDTH							;
		end else if(lite_aw_valid && lite_w_valid && WS_STOP_WIDTH) begin
			if(lite_axi_wdata_r[1:0]==2'b00) begin
				c_rs422_stop_width				<= LP_STOP_WIDTH							;
			end else begin
				c_rs422_stop_width				<= {1'b0,lite_axi_wdata_r[1:0]}				;
			end
		end else begin
			c_rs422_stop_width					<= c_rs422_stop_width						;
		end
	end
	/*--------------------------------------------------------------------------------------
	--鎺ユ敹fifo澶嶄綅
	--------------------------------------------------------------------------------------*/
	always @(posedge clk or posedge rst) begin
		if(rst) begin
			rx_fifo_rst					<= 1'b0										;
		end else if(lite_aw_valid && lite_w_valid && WS_RX_FIFO_RST) begin
			rx_fifo_rst					<= lite_axi_wdata_r[0]						;
		end else begin
			rx_fifo_rst					<= 1'b0							;
		end
	end




	/*--------------------------------------------------------------------------------------
	--鍏跺畠淇″彿澶勭悊
	--------------------------------------------------------------------------------------*/

	assign	sys_axi_awready						= 1'b1										;
	assign	sys_axi_wready						= 1'b1										;
	assign	sys_axi_arready						= 1'b1										;
	assign	sys_axi_rresp						= 2'b00										;
	assign	sys_axi_bresp						= 2'b00										;
	
	always @(posedge clk) begin
		if(sys_axi_bvalid && sys_axi_bready) begin
			sys_axi_bvalid						<= 1'b0										;
		end else if(sys_axi_wvalid && sys_axi_wready) begin
			sys_axi_bvalid						<= 1'b1										;
		end else begin
			sys_axi_bvalid						<= sys_axi_bvalid							;
		end
	end
	
	always @(posedge clk) begin
		if(lite_w_valid==1'b1) begin
			lite_w_valid						<= 1'b0										;
		end else
		if(sys_axi_wvalid && sys_axi_wready) begin
			lite_w_valid						<= 1'b1										;
		end else begin
			lite_w_valid						<= lite_w_valid								;
		end
	end
	
	
	always @(posedge clk) begin
		if(lite_w_valid==1'b1) begin
			lite_aw_valid						<= 1'b0										;
		end else
		if(sys_axi_awvalid && sys_axi_awready) begin
			lite_aw_valid						<= 1'b1										;
		end else begin
			lite_aw_valid						<= lite_aw_valid							;
		end
	end
	
	
	always @(posedge clk) begin
		if(sys_axi_awvalid && sys_axi_awready) begin
			lite_axi_awaddr_r					<= sys_axi_awaddr							;
		end else begin
			lite_axi_awaddr_r					<= lite_axi_awaddr_r						;
		end
	end
	
	always @(posedge clk) begin
		if(sys_axi_wvalid && sys_axi_wready) begin
			lite_axi_wdata_r					<= sys_axi_wdata							;
		end else begin
			lite_axi_wdata_r					<= lite_axi_wdata_r							;
		end
	end

//==================================================================================================
//--RX鍙戦€佹暟鎹瓼IFO鍐欏叆瀹炵幇
	always @(posedge clk or posedge rst) begin
		if(rst) begin
			tx_fifo_wen							<= 1'b0										;
			tx_fifo_din							<= 32'b0									;
		end else if(lite_aw_valid && lite_w_valid && WS_TX_FIFO_DIN) begin
			tx_fifo_wen							<= 1'b1										;
			tx_fifo_din							<= lite_axi_wdata_r[31:0]					;
		end else begin
			tx_fifo_wen							<= 1'b0										;
			tx_fifo_din							<= 32'hDEED_BEEF							;
		end
	end


//==================================================================================================
//--瀵勫瓨鍣ㄨ瀹炵幇
	wire	RS_RX_FIFO_DOUT						= sys_axi_araddr[11:0]== OFF_RX_FIFO_DOUT	;
	wire	RS_RX_STATUS						= sys_axi_araddr[11:0]== OFF_RX_FIFO_STATUS	;
	wire	RS_TX_STATUS						= sys_axi_araddr[11:0]== OFF_TX_FIFO_STATUS	;
	wire	RS_BAUD_RATE						= sys_axi_araddr[11:0]== OFF_RS422_BAUD		;
	wire	RS_PARITY_EN						= sys_axi_araddr[11:0]== OFF_PARITY_EN		;
	wire	RS_PARITY_SEL						= sys_axi_araddr[11:0]== OFF_PARITY_SEL		;
	wire	RS_STOP_WIDTH						= sys_axi_araddr[11:0]== OFF_STOP_WIDTH		;
	wire	RS_TX_FIFO_DIN						= sys_axi_araddr[11:0]== OFF_TX_FIFO_DIN	;
	
	always @(posedge clk) begin
		sys_axi_rdata							<= RS_RX_FIFO_DOUT	? rx_fifo_dout[31:0]
												:  RS_RX_STATUS		? rx_fifo_status[31:0]
												:  RS_TX_STATUS		? tx_fifo_status[31:0]
												:  RS_BAUD_RATE		? c_rs422_baud_rate
												:  RS_PARITY_EN		? {31'd0,c_rs422_parity_en}
												:  RS_PARITY_SEL	? {31'd0,c_rs422_parity_sel}
												:  RS_STOP_WIDTH	? {29'd0,c_rs422_stop_width}
												:  RS_TX_FIFO_DIN	? tx_fifo_din																																			
												: {12'h422,sys_axi_araddr[19:0]}			;
	end
	/*--------------------------------------------------------------------------------------
	--鍏跺畠淇″彿澶勭悊
	--------------------------------------------------------------------------------------*/
	always @(posedge clk or posedge rst) begin
		if(rst) begin
			sys_axi_rvalid						<= 1'b0										;
		end else if(sys_axi_rvalid && sys_axi_rready) begin
			sys_axi_rvalid						<= 1'b0										;
		end else if(sys_axi_arvalid && sys_axi_arready) begin
			sys_axi_rvalid						<= 1'b1										;
		end else begin
			sys_axi_rvalid						<= sys_axi_rvalid							;
		end
	end

	assign	sys_axi_rresp						= 2'b00										;
	
//==================================================================================================
//--RX FIFO璇讳俊鍙峰疄鐜?
	always @(posedge clk or posedge rst) begin
		if(rst) begin
			rx_fifo_ren							<= 1'b0										;
		end else if(sys_axi_rvalid && sys_axi_rready && RS_RX_FIFO_DOUT) begin
			rx_fifo_ren							<= 1'b1										;
		end else begin
			rx_fifo_ren							<= 1'b0										;
		end
	end

endmodule
