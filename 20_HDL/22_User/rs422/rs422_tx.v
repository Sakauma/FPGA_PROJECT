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
// Create Date:		2018/5/11 13:16:20
// Design Name:		EC1300
// Module Name:		rs422_tx---
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
module rs422_tx #(
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
	input			[31:0]						c_rs422_baud_rate							,	// 历史说明：原尾注编码已损坏，代码含义以信号名和开发文档为准。
	input										c_rs422_parity_en							,	// 历史说明：原尾注编码已损坏，代码含义以信号名和开发文档为准。
	input										c_rs422_parity_sel							,	// 历史说明：原尾注编码已损坏，代码含义以信号名和开发文档为准。
	input			[2:0]						c_rs422_stop_width							,	// 历史说明：原尾注编码已损坏，代码含义以信号名和开发文档为准。
	
	
	/*--------------------------------------------------------------------------------------
	* 历史说明：原块注释编码已损坏，按当前文件头和开发文档维护。
	--------------------------------------------------------------------------------------*/
	(*mark_debug="TRUE"*)
	output	reg									rs422_tx									,
	output	reg									rs422_de			= 'b0					,
	/*--------------------------------------------------------------------------------------
	* 历史说明：原块注释编码已损坏，按当前文件头和开发文档维护。
	--------------------------------------------------------------------------------------*/	
	input										tx_fifo_wen									,
	input			[31:0]						tx_fifo_din									,
	output										tx_fifo_full								,
	output	reg		[31:0]						tx_fifo_status								
	
	);

//==================================================================================================
//--Signals Define
	
	/*--------------------------------------------------------------------------------------
	* 历史说明：原块注释编码已损坏，按当前文件头和开发文档维护。
	--------------------------------------------------------------------------------------*/
	(*mark_debug="TRUE"*)	
	wire			[31:0]						tx_fifo_dout								;
	wire										tx_fifo_empty								;
	reg											tx_fifo_ren									;

//==================================================================================================
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
	/*--------------------------------------------------------------------------------------
	* 历史说明：原块注释编码已损坏，按当前文件头和开发文档维护。
	--------------------------------------------------------------------------------------*/	
	localparam									S_TX_IDLE_M				= 6'b00_0001		;
	localparam									S_TX_START_M			= 6'b00_0010		;
	localparam									S_TX_DATA_M				= 6'b00_0100		;
	localparam									S_TX_PARITY_M			= 6'b00_1000		;
	localparam									S_TX_STOP_M				= 6'b01_0000		;
	localparam									S_TX_DONE_M				= 6'b10_0000		;

//==================================================================================================
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
	reg				[ 5:0]						S_TX_M										;
		
	reg				[31:0]						baud_cnt									;	// 历史说明：原尾注编码已损坏，代码含义以信号名和开发文档为准。
	reg											baud_cnt_arrive								;	// 历史说明：原尾注编码已损坏，代码含义以信号名和开发文档为准。
	reg				[ 2:0]						bit_cnt										;	// 历史说明：原尾注编码已损坏，代码含义以信号名和开发文档为准。
	
	wire										bit_parity_odd								;	// 历史说明：原尾注编码已损坏，代码含义以信号名和开发文档为准。
	wire										bit_parity_even								;	// 历史说明：原尾注编码已损坏，代码含义以信号名和开发文档为准。
	
	reg				[23:0]						delay_cnt	= 24'h0								;	// 历史说明：原尾注编码已损坏，代码含义以信号名和开发文档为准。
//==================================================================================================
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
	/*--------------------------------------------------------------------------------------
	* 历史说明：原块注释编码已损坏，按当前文件头和开发文档维护。
	* 历史说明：原块注释编码已损坏，按当前文件头和开发文档维护。
	* 历史说明：原块注释编码已损坏，按当前文件头和开发文档维护。
	* 历史说明：原块注释编码已损坏，按当前文件头和开发文档维护。
	* 历史说明：原块注释编码已损坏，按当前文件头和开发文档维护。
	* 历史说明：原块注释编码已损坏，按当前文件头和开发文档维护。
	* 历史说明：原块注释编码已损坏，按当前文件头和开发文档维护。
	* 历史说明：原块注释编码已损坏，按当前文件头和开发文档维护。
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
	* 历史说明：原块注释编码已损坏，按当前文件头和开发文档维护。
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
	* 历史说明：原块注释编码已损坏，按当前文件头和开发文档维护。
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
	* 历史说明：原块注释编码已损坏，按当前文件头和开发文档维护。
	--------------------------------------------------------------------------------------*/	
	assign	bit_parity_odd						= ^tx_fifo_dout[7:0]						;
	assign	bit_parity_even						= ~bit_parity_odd							;
	
//==================================================================================================
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
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
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
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
