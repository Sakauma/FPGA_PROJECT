 `timescale 1ns/1ns
//////////////////////////////////////////////////////////////////////////////////
// Company:			ZHTY
// Engineer:		ZYL
// Create Date:		2018/5/11 13:16:20
// Design Name:		EC1300
// Module Name:		rs422_tx---
// Project Name:
// Target Devices:	K7-V7
// Tool Versions: 	Vivado 2016.1 HDL-EDIT UltraEdit TAB=4 Consolas
// Description:
//		模块实现RS422的数据发送
// Dependencies:
//		
// Revision:
// Revision 0.01 - File Created
//////////////////////////////////////////////////////////////////////////////////
module rs422_tx #(
	/*--------------------------------------------------------------------------------------
	--SIMULATION
	---------------------------------------------------------------------------------------*/
	parameter									SIMULATION				= "FALSE"			
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
	
	/*--------------------------------------------------------------------------------------
	--AXI_LITE模块接口
	--------------------------------------------------------------------------------------*/	
	input			[31:0]						c_rs422_baud_rate							,	//波特率配置寄存器
	input										c_rs422_parity_en							,	//奇偶校验位使能
	input										c_rs422_parity_sel							,	//奇偶校验选择=0，奇校验
	input			[2:0]						c_rs422_stop_width							,	//停止位位宽，1~3,0无效
	
	
	/*--------------------------------------------------------------------------------------
	--RS422信号定义
	--------------------------------------------------------------------------------------*/
	(*mark_debug="TRUE"*)
	output	reg									rs422_tx									,
	output	reg									rs422_de			= 'b0					,
	/*--------------------------------------------------------------------------------------
	--TX数据FIFO写入
	--------------------------------------------------------------------------------------*/	
	input										tx_fifo_wen									,
	input			[31:0]						tx_fifo_din									,
	output										tx_fifo_full								,
	output	reg		[31:0]						tx_fifo_status								
	
	);

//==================================================================================================
//--Signals Define
	
	/*--------------------------------------------------------------------------------------
	--RS422 TX FIFO信号定义
	--------------------------------------------------------------------------------------*/
	(*mark_debug="TRUE"*)	
	wire			[31:0]						tx_fifo_dout								;
	wire										tx_fifo_empty								;
	reg											tx_fifo_ren									;

//==================================================================================================
//--参数定义
	/*--------------------------------------------------------------------------------------
	--RS422 TX发送状态机
	--------------------------------------------------------------------------------------*/	
	localparam									S_TX_IDLE_M				= 6'b00_0001		;
	localparam									S_TX_START_M			= 6'b00_0010		;
	localparam									S_TX_DATA_M				= 6'b00_0100		;
	localparam									S_TX_PARITY_M			= 6'b00_1000		;
	localparam									S_TX_STOP_M				= 6'b01_0000		;
	localparam									S_TX_DONE_M				= 6'b10_0000		;

//==================================================================================================
//--信号定义	
	reg				[ 5:0]						S_TX_M										;
		
	reg				[31:0]						baud_cnt									;	//波特率计数器
	reg											baud_cnt_arrive								;	//波特率计数器到达
	reg				[ 2:0]						bit_cnt										;	//bit位计数器
	
	wire										bit_parity_odd								;	//偶校验
	wire										bit_parity_even								;	//奇校验
	
	reg				[23:0]						delay_cnt	= 24'h0								;	//增加帧间延时
//==================================================================================================
//--发送实现	
	/*--------------------------------------------------------------------------------------
	--状态机流程
	--IDLE---->判断数据发送FIFO是否为空，数据发送为高电平
	--START--->开始标志，等待波特率计数器到达，数据发送为低电平
	--DATA---->数据位，等待数据位计数器bit_cnt与波特率计数器同时到达，数据位计数器选择TX_FIFO输出
	---------->如果c_rs422_parity_en使能，则进入奇偶校验，否则进入STOP状态
	--Parity-->根据c_rs422_parity_sel选择奇校验或者偶校验，等待波特率计数器到达，跳转
	--STOP---->结束位标志状态，根据结束位位宽计算结束位的长度
	--DONE---->一个周期的完成状态
	--------------------------------------------------------------------------------------*/	
	always @(posedge clk or posedge rst) begin
		if(rst) begin
			S_TX_M								<= S_TX_IDLE_M								;
			rs422_tx							<= 1'b1										;
			tx_fifo_ren							<= 1'b0										;
		end else begin
			case(S_TX_M)
				S_TX_IDLE_M						: begin
					if(~tx_fifo_empty) begin
						S_TX_M					<= S_TX_START_M								;
					end else begin
						S_TX_M					<= S_TX_IDLE_M								;
					end
					rs422_tx					<= 1'b1										;
					tx_fifo_ren					<= 1'b0										;
					delay_cnt                  <=   24'h0                              	;
				end
				S_TX_START_M					: begin
					if(baud_cnt_arrive) begin
						S_TX_M					<= S_TX_DATA_M								;
					end else begin
						S_TX_M					<= S_TX_START_M								;
					end
					rs422_tx					<= 1'b0										;
				end
				S_TX_DATA_M					: begin
					if(baud_cnt_arrive && bit_cnt==3'h7) begin
						if(c_rs422_parity_en) begin
							S_TX_M				<= S_TX_PARITY_M							;
						end else begin
							S_TX_M				<= S_TX_STOP_M								;
						end
					end else begin
						S_TX_M					<= S_TX_DATA_M								;
					end
					rs422_tx					<= tx_fifo_dout[bit_cnt]					;
				end
				S_TX_PARITY_M				: begin
					if(baud_cnt_arrive) begin
						S_TX_M					<= S_TX_STOP_M								;
					end else begin
						S_TX_M					<= S_TX_PARITY_M							;
					end
					rs422_tx					<= (c_rs422_parity_sel==1'b0)
												?  bit_parity_even
												:  bit_parity_odd							;
				end
				S_TX_STOP_M						: begin
					if(baud_cnt_arrive && bit_cnt==c_rs422_stop_width-1'b1) begin
						S_TX_M					<= S_TX_DONE_M								;
						tx_fifo_ren				<= 1'b1										;
						delay_cnt               <=   24'h0                              	;
					end else begin
						S_TX_M					<= S_TX_STOP_M								;
						tx_fifo_ren				<= 1'b0										;
					end
					rs422_tx					<= 1'b1										;
				end
				S_TX_DONE_M						: begin
					if(~tx_fifo_empty & delay_cnt>2) begin
						S_TX_M					<= S_TX_START_M								;
					end else begin
					   if(delay_cnt<10)   begin
						S_TX_M					<= S_TX_DONE_M								;					   
						delay_cnt                <= delay_cnt+1                             ;
					   end else begin
						S_TX_M					<= S_TX_IDLE_M								;					   
						delay_cnt                <= delay_cnt                              ;
					   end
					end
					rs422_tx					<= 1'b1										;
					tx_fifo_ren					<= 1'b0										;
				end
				default							: begin
					S_TX_M						<= S_TX_IDLE_M								;
					rs422_tx					<= 1'b1										;
					tx_fifo_ren					<= 1'b0										;
				end
			endcase
		end
	end
	always @(posedge clk or posedge rst) begin
		if(rst) begin
			rs422_de							<= 1'b0										;
		end else begin
			rs422_de							<= ~ (S_TX_M ==  S_TX_IDLE_M)	& delay_cnt< 4				;
		end	
	end		
	/*--------------------------------------------------------------------------------------
	--波特率计数器实现
	--------------------------------------------------------------------------------------*/
	always @(posedge clk or posedge rst) begin
		if(rst) begin
			baud_cnt							<= 32'b0									;
			baud_cnt_arrive						<= 1'b0										;
		end else begin
			case(S_TX_M)
				S_TX_IDLE_M,S_TX_DONE_M			: begin
					baud_cnt					<= 32'b0									;
					baud_cnt_arrive				<= 1'b0										;
				end
				S_TX_START_M					,
				S_TX_DATA_M						,
				S_TX_PARITY_M					,
				S_TX_STOP_M						: begin	
					if(baud_cnt_arrive) begin
						baud_cnt				<= 32'b0									;
					end else begin
						baud_cnt				<= baud_cnt + 1'b1							;
					end
					
					if(baud_cnt==c_rs422_baud_rate-2'b10) begin
						baud_cnt_arrive			<= 1'b1										;
					end else begin
						baud_cnt_arrive			<= 1'b0										;
					end
				end
				default							: begin
					baud_cnt					<= 32'b0									;
					baud_cnt_arrive				<= 1'b0										;
				end
			endcase
		end
	end
	
	/*--------------------------------------------------------------------------------------
	--BIT_CNT数据位计数器实现
	--------------------------------------------------------------------------------------*/	
	always @(posedge clk or posedge rst) begin
		if(rst) begin
			bit_cnt								<= 3'b000									;
		end else if(S_TX_M==S_TX_DATA_M || S_TX_M==S_TX_STOP_M) begin
			if(baud_cnt_arrive) begin
				bit_cnt							<= bit_cnt + 1'b1							;
			end else begin
				bit_cnt							<= bit_cnt									;
			end
		end else begin
			bit_cnt								<= 3'b000									;
		end
	end
	
	/*--------------------------------------------------------------------------------------
	--奇偶校验实现
	--------------------------------------------------------------------------------------*/	
	assign	bit_parity_odd						= ^tx_fifo_dout[7:0]						;
	assign	bit_parity_even						= ~bit_parity_odd							;
	
//==================================================================================================
//--发送可用空间计数器
	always @(posedge clk or posedge rst) begin
		if(rst) begin
			tx_fifo_status						<= 32'd0									;
		end else if(tx_fifo_wen && tx_fifo_ren) begin
			tx_fifo_status						<= tx_fifo_status							;
		end else if(tx_fifo_wen && !tx_fifo_full) begin
			tx_fifo_status						<= tx_fifo_status + 1'b1					;
		end else if(tx_fifo_ren && !tx_fifo_empty) begin
			tx_fifo_status						<= tx_fifo_status - 1'b1					;
		end else begin
			tx_fifo_status						<= tx_fifo_status							;
		end
	end
				

//==================================================================================================
//--TX FIFO例化
/*	FIFO_DUALCLOCK_MACRO #(
		.ALMOST_EMPTY_OFFSET					( 9'h080									),	// Sets the almost empty threshold
		.ALMOST_FULL_OFFSET						( 9'h004									),	// Sets almost full threshold
		.DATA_WIDTH								( 16										),	// Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
		.DEVICE									( "7SERIES"									),	// Target device: "VIRTEX5", "VIRTEX6", "7SERIES"
		.FIFO_SIZE								( "36Kb"									),	// Target BRAM: "18Kb" or "36Kb"
		.FIRST_WORD_FALL_THROUGH 				( "TRUE"									)	// Sets the FIfor FWFT to "TRUE" or "FALSE"
		)
	i_tx_fifo (
		.ALMOSTEMPTY							( 											),	// 1-bit output almost empty
		.ALMOSTFULL								( 											),	// 1-bit output almost full
		.DO										( tx_fifo_dout								),	// Output data, width defined by DATA_WIDTH parameter
		.EMPTY									( tx_fifo_empty								),	// 1-bit output empty
		.FULL									( tx_fifo_full								),	// 1-bit output full
		.RDCOUNT								( 											),	// Output read count, width determined by FIfor depth
		.RDERR									( 											),	// 1-bit output read error
		.WRCOUNT								( 											),	// Output write count, width determined by FIfor depth
		.WRERR									( 											),	// 1-bit output write error
		.DI										( tx_fifo_din								),	// Input data, width defined by DATA_WIDTH parameter
		.RDCLK									( clk										),	// 1-bit input read clock
		.RDEN									( tx_fifo_ren								),	// 1-bit input read enable
		.RST									( rst										),	// 1-bit input reset
		.WRCLK									( clk										),	// 1-bit input write clock
		.WREN									( tx_fifo_wen								)	// 1-bit input write enable
	);
*/
fifo_16w_2048d i_tx_fifo (
  .rst(rst),        // input wire rst
  .wr_clk(clk),  // input wire wr_clk
  .rd_clk(clk),  // input wire rd_clk
  .din(tx_fifo_din),        // input wire [15 : 0] din
  .wr_en(tx_fifo_wen),    // input wire wr_en
  .rd_en(tx_fifo_ren),    // input wire rd_en
  .dout(tx_fifo_dout),      // output wire [15 : 0] dout
  .full(tx_fifo_full),      // output wire full
  .empty(tx_fifo_empty),
    .wr_rst_busy(),  // output wire wr_rst_busy
  .rd_rst_busy()  // output wire rd_rst_busy    // output wire empty
);
endmodule