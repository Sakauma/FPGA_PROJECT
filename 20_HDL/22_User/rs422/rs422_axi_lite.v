`timescale 1ns/1ns
// ============================================================================
// 新增维护说明
// 文件职责      : 当前文件为手工维护源码，承担本模块/脚本的真实实现。
// 维护边界      : 本注释块仅补充维护说明，不改写任何原有说明、历史注释或现有逻辑。
// 修改约束      : 后续如需继续补充说明，只允许追加中文注释，不得替换旧注释或改动旧代码。
// 生成关系      : 若存在对应生成物，应以当前手工源码为准，禁止反向覆盖本文件。
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
//		模块实现RS422模块的主机接口
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
//--输入输出端口定义---------------------------
	/*--------------------------------------------------------------------------------------
	--Common Interface
	--|log_clk-->可以连接a，也可以连接外部时钟，进行快速查询处理
	--|rst-->复位信号，高电平同步复位信号
	--------------------------------------------------------------------------------------*/
	input										clk											,
	input										rst											,
	output reg 	 rx_fifo_rst                        ,
//==================================================================================================
//--AXI Lite寄存器方向
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
	--AXI_LITE模块接口
	--------------------------------------------------------------------------------------*/
	output	reg		[31:0]						c_rs422_baud_rate							,	//波特率配置寄存器
	output	reg									c_rs422_parity_en							,	//奇偶校验位使能
	output	reg									c_rs422_parity_sel							,	//奇偶校验选择=0，奇校验
	output	reg		[ 2:0]						c_rs422_stop_width							,	//停止位位宽，1~3,0无效

	/*--------------------------------------------------------------------------------------
	--TX发送FIFO信号
	--------------------------------------------------------------------------------------*/
	(*mark_debug="TRUE"*)
	output	reg									tx_fifo_wen									,
	(*mark_debug="TRUE"*)
	output	reg		[31:0]						tx_fifo_din									,
	input										tx_fifo_full								,
	input			[31:0]						tx_fifo_status								,
	
	/*--------------------------------------------------------------------------------------
	--RX接收FIFO信号
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
	--AXI Lite寄存器配置偏移量
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
	--默认的波特率参数
	--------------------------------------------------------------------------------------*/	
	localparam		LP_BAUD_RATE_DEF			= (SIMULATION=="TRUE")? 32'd50:32'd10417	;	//默认为9600，以100Mhz为准计数
	localparam		LP_STOP_WIDTH				= 3'b001									;	//停止位的宽度，默认为1=0
//==================================================================================================
//--Signals Define

//==================================================================================================
//--寄存器写实现
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
	--中断测试int_test
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
	--波特率主机配置实现
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
	--奇偶校验使能配置
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
	--奇校验、偶校验选择信号=0-奇校验，=1-偶校验
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
	--结束标志位宽（波特率位宽）
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
	--接收fifo复位
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
	--其它信号处理
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
//--RX发送数据FIFO写入实现
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
//--寄存器读实现
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
	--其它信号处理
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
//--RX FIFO读信号实现	
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