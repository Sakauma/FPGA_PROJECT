`timescale 1ns/1ns
//////////////////////////////////////////////////////////////////////////////////
// Company:			ZHTY
// Engineer:		ZYL
// Create Date:		2018/5/11 13:24:01
// Design Name:		EC1300
// Module Name:		rs422_rx
// Project Name:
// Target Devices:	K7-V7
// Tool Versions: 	Vivado 2016.1 HDL-EDIT UltraEdit TAB=4 Consolas
// Description:
//		模块实现AXI Master的发送
// Dependencies:
//		V1.0 开发版本	2020/2/18 16:00:46
//		V1.2-解决STOP进入Start的问题，当STOP直接进入Start时，增加一个状态，使得
//波特率计数器归零	2020/2/18 16:00:48
// Revision:
// Revision 0.01 - File Created
//////////////////////////////////////////////////////////////////////////////////
module rs422_rx #(
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
	(*MARK_DEBUG="TRUE"*)	input										rx_fifo_rst											,	
	/*--------------------------------------------------------------------------------------
	--AXI_LITE模块接口
	--------------------------------------------------------------------------------------*/	
	input			[31:0]						c_rs422_baud_rate							,	//波特率配置寄存器
	input										c_rs422_parity_en							,	//奇偶校验位使能
	input										c_rs422_parity_sel							,	//奇偶校验选择=0，奇校验
	
	/*--------------------------------------------------------------------------------------
	--RS422信号定义
	--------------------------------------------------------------------------------------*/
	(*mark_debug="TRUE"*)
	input										rs422_rx									,
	/*--------------------------------------------------------------------------------------
	--TX数据FIFO写入
	--------------------------------------------------------------------------------------*/	
	input										rx_fifo_ren									,
	output			[31:0]						rx_fifo_dout								,
	output										rx_fifo_empty								,
	output	reg		[31:0]						rx_fifo_status
	
	);
//==================================================================================================
//--Parameter Define
	/*--------------------------------------------------------------------------------------
	--RS422 RX接收状态机参数定义
	--------------------------------------------------------------------------------------*/	
	localparam		S_RX_IDLE_M					= 12'b0000_0000_0001						;
	localparam		S_RX_START_M				= 12'b0000_0000_0010						;
	localparam		S_RX_PRE_M					= 12'b0000_0000_0100						;
	localparam		S_RX_DATA_PRE_M				= 12'b0000_0000_1000						;
	localparam		S_RX_DATA_H_M				= 12'b0000_0001_0000						;
	localparam		S_RX_DATA_L_M				= 12'b0000_0010_0000						;
	localparam		S_RX_DATA_M					= 12'b0000_0100_0000						;
	localparam		S_RX_PARITY_M				= 12'b0000_1000_0000						;
	localparam		S_RX_PARITY_H_M     	    = 12'b0001_0000_0000						;
	localparam		S_RX_PARITY_L_M				= 12'b0010_0000_0000						;
	localparam		S_RX_STOP_M					= 12'b0100_0000_0000						;
	localparam		S_RX_START_PRE_M			= 12'b1000_0000_0000						;

//==================================================================================================
//--信号定义
	/*--------------------------------------------------------------------------------------
	--状态机信号
	--------------------------------------------------------------------------------------*/
	(*MARK_DEBUG="TRUE"*)	reg				[11:0]						S_RX_M										;
	
	reg				[31:0]						baud_cnt									;
	reg											baud_cnt_arrive								;
	reg				[ 2:0]						bit_cnt										;
	
	wire										bit_parity_odd								;
	wire										bit_parity_even								;
	wire										bit_parity_odd_result						;
	wire										bit_parity_even_result						;
	
	wire										bit_parity_data								;	

	wire										bit_parity									;
	
	reg				[ 7:0]						rx_d										;
	
	/*--------------------------------------------------------------------------------------
	--起始标志采集
	--------------------------------------------------------------------------------------*/
	reg											rs422_rx_q1									;
	reg											rs422_rx_q2									;
	wire										rx_fe										;	//RS422 RX下降沿
	wire										rx_re										;	//RS422 RX上升安
	reg				[31:0]						rx_l_cnt									;	//低电平计数器
	reg				[31:0]						rx_h_cnt									;	//高电平计数器
	
	reg				[31:0]						baud_3_4									;	//baud 3/4的计数值
	reg				[31:0]						baud_1_2									;	//baud 1/2的计数值
	
	/*--------------------------------------------------------------------------------------
	--RX_FIFO写入
	--------------------------------------------------------------------------------------*/	
	reg				[31:0]						rx_fifo_din									;
	reg											rx_fifo_wen									;
	wire										rx_fifo_full								;
//==================================================================================================


	(*MARK_DEBUG="TRUE"*) wire rst_2;


assign rst_2 =  rst|rx_fifo_rst;


//--提前信号处理
	/*--------------------------------------------------------------------------------------
	--RX信号同步以及信号下降沿检测
	--------------------------------------------------------------------------------------*/
	always @(posedge clk or posedge rst_2) begin
		if(rst_2) begin
			rs422_rx_q1							<= 1'b1										;
			rs422_rx_q2							<= 1'b1										;
		end else begin
			rs422_rx_q1							<= rs422_rx									;
			rs422_rx_q2							<= rs422_rx_q1								;
		end
	end
	
	assign	rx_fe								= ~rs422_rx_q1 && rs422_rx_q2				;	//下降沿检测
	assign	rx_re								= rs422_rx_q1 && ~rs422_rx_q2				;	//上升沿检测
	
	/*--------------------------------------------------------------------------------------
	--3/4波特率计数器值
	--------------------------------------------------------------------------------------*/
	always @ (posedge clk or posedge rst_2) begin
		if(rst_2) begin
			baud_1_2							<= 32'b0									;
			baud_3_4							<= 32'b0									;
		end else begin
			baud_1_2							<= {1'b0,c_rs422_baud_rate[31:1]}			;
			baud_3_4							<= {1'b0,c_rs422_baud_rate[31:1]}
												+  {2'b0,c_rs422_baud_rate[31:2]}			;
		end
	end
	
//==================================================================================================
//--接收实现	
	/*--------------------------------------------------------------------------------------
	--接收状态机流程
	--------------------------------------------------------------------------------------*/
	always @(posedge clk or posedge rst_2) begin
		if(rst_2) begin
			S_RX_M								<= S_RX_IDLE_M								;
			rx_h_cnt							<= 32'b0									;
			rx_l_cnt							<= 32'b0									;
			bit_cnt								<= 3'b000									;
			rx_d								<= 8'h00									;
		end else begin
			case(S_RX_M)
				S_RX_IDLE_M						: begin
					if(rx_fe) begin
						S_RX_M					<= S_RX_START_M								;
					end else begin
						S_RX_M					<= S_RX_IDLE_M								;
					end
					rx_h_cnt					<= 32'b0									;
					rx_l_cnt					<= 32'b0									;
					bit_cnt						<= 3'b000									;
					rx_d						<= 8'h00									;
				end
				S_RX_START_M					: begin
					//--第一个数据为高电平，并且提前到达，那么提前进入DATA状态
					if(rx_l_cnt>=baud_3_4 && rx_re) begin
						S_RX_M					<= S_RX_PRE_M								;
						rx_l_cnt				<= 32'b0									;
					//--定时时间到，没有调表，并且低电平时间大于3/4，那么进入数据状态
					end else if(rx_l_cnt>=baud_3_4 && baud_cnt_arrive) begin
						S_RX_M					<= S_RX_PRE_M								;
						rx_l_cnt				<= 32'b0									;
					//--定时时间到，但是没有到达有效的低电平时间，进入IDLE状态
					end else if(rx_l_cnt<baud_3_4 && baud_cnt_arrive) begin
						S_RX_M					<= S_RX_IDLE_M								;
						rx_l_cnt				<= 32'b0									;
					end else begin
						S_RX_M					<= S_RX_START_M								;
						rx_l_cnt				<= (rs422_rx==1'b0)?rx_l_cnt+1'b1:rx_l_cnt	;
					end
					rx_h_cnt					<= 32'b0									;
					bit_cnt						<= 3'b000									;
					rx_d						<= 8'h00									;
				end
				S_RX_PRE_M						: begin
					S_RX_M						<= S_RX_DATA_PRE_M							;
					rx_h_cnt					<= 32'b0									;
					bit_cnt						<= 3'b000									;
				end
				S_RX_DATA_PRE_M					: begin
					if(rx_l_cnt>=baud_3_4 && rx_re) begin
						S_RX_M					<= S_RX_DATA_L_M							;
					end else if(rx_h_cnt>=baud_3_4 && rx_fe) begin
						S_RX_M					<= S_RX_DATA_H_M							;
					end else if(rx_l_cnt>=baud_3_4 && baud_cnt_arrive) begin
						S_RX_M					<= S_RX_DATA_L_M							;
					end else if(rx_h_cnt>=baud_3_4 && baud_cnt_arrive) begin
						S_RX_M					<= S_RX_DATA_H_M							;
					end else if(baud_cnt_arrive) begin
						if(rx_h_cnt>=rx_l_cnt) begin
							S_RX_M				<= S_RX_DATA_H_M							;
						end else begin
							S_RX_M				<= S_RX_DATA_L_M							;
						end
					end else begin
						S_RX_M					<= S_RX_DATA_PRE_M							;
					end
					rx_h_cnt					<= (rs422_rx==1'b1)?rx_h_cnt+1'b1:rx_h_cnt	;
					rx_l_cnt					<= (rs422_rx==1'b0)?rx_l_cnt+1'b1:rx_l_cnt	;
					rx_d						<= rx_d										;
				end
				S_RX_DATA_H_M					: begin
					if(bit_cnt==3'd7) begin
						if(c_rs422_parity_en) begin
							S_RX_M				<= S_RX_PARITY_M							;
						end else begin
							S_RX_M				<= S_RX_DATA_M								;
						end
					end else begin
						S_RX_M					<= S_RX_DATA_PRE_M							;
					end
					rx_h_cnt					<= 32'b0									;
					rx_l_cnt					<= 32'b0									;
					bit_cnt						<= bit_cnt + 1'b1							;
					rx_d[bit_cnt]				<= 1'b1										;
				end
				S_RX_DATA_L_M					: begin
					if(bit_cnt==3'd7) begin
						if(c_rs422_parity_en) begin
							S_RX_M				<= S_RX_PARITY_M							;
						end else begin
							S_RX_M				<= S_RX_DATA_M								;
						end
					end else begin
						S_RX_M					<= S_RX_DATA_PRE_M							;
					end
					rx_h_cnt					<= 32'b0									;
					rx_l_cnt					<= 32'b0									;
					bit_cnt						<= bit_cnt + 1'b1							;
					rx_d[bit_cnt]				<= 1'b0										;
				end
				S_RX_DATA_M						: begin
					S_RX_M						<= S_RX_STOP_M								;
				end
				S_RX_PARITY_M					: begin
					if(rx_l_cnt>=baud_3_4 && rx_re) begin
						S_RX_M					<= S_RX_PARITY_L_M							;
					end else if(rx_h_cnt>=baud_3_4 && rx_fe) begin
						S_RX_M					<= S_RX_PARITY_H_M							;
					end else if(rx_l_cnt>=baud_3_4 && baud_cnt_arrive) begin
						S_RX_M					<= S_RX_PARITY_L_M							;
					end else if(rx_h_cnt>=baud_3_4 && baud_cnt_arrive) begin
						S_RX_M					<= S_RX_PARITY_H_M							;
					end else if(baud_cnt_arrive) begin
						if(rx_h_cnt>=rx_l_cnt) begin
							S_RX_M				<= S_RX_PARITY_H_M							;
						end else begin
							S_RX_M				<= S_RX_PARITY_L_M							;
						end
					end else begin
						S_RX_M					<= S_RX_PARITY_M							;
					end
					rx_h_cnt					<= (rs422_rx==1'b1)?rx_h_cnt+1'b1:rx_h_cnt	;
					rx_l_cnt					<= (rs422_rx==1'b0)?rx_l_cnt+1'b1:rx_l_cnt	;
					bit_cnt						<= 3'b000									;
					rx_d						<= rx_d										;
				end
				S_RX_PARITY_H_M					: begin
					S_RX_M						<= S_RX_STOP_M								;
					rx_h_cnt					<= 32'b0									;
					rx_l_cnt					<= 32'b0									;
					bit_cnt						<= 3'b000									;
					rx_d						<= rx_d										;
				end
				S_RX_PARITY_L_M					: begin
					S_RX_M						<= S_RX_STOP_M								;
					rx_h_cnt					<= 32'b0									;
					rx_l_cnt					<= 32'b0									;
					bit_cnt						<= 3'b000									;
					rx_d						<= rx_d										;
				end
				S_RX_STOP_M						: begin
					if(rx_h_cnt>=baud_3_4 && rx_fe) begin
						S_RX_M					<= S_RX_START_PRE_M							;
					end else if(baud_cnt_arrive) begin
						S_RX_M					<= S_RX_IDLE_M								;
					end else begin
						S_RX_M					<= S_RX_STOP_M								;
					end
					rx_h_cnt					<= (rs422_rx==1'b1)?rx_h_cnt+1'b1:rx_h_cnt	;
					rx_l_cnt					<= 32'b0									;
					bit_cnt						<= 3'b000									;
					rx_d						<= 8'h00									;
				end
				S_RX_START_PRE_M				: begin
					S_RX_M						<= S_RX_START_M								;
				end
				default							: begin
					S_RX_M						<= S_RX_IDLE_M								;
					rx_h_cnt					<= 32'b0									;
					rx_l_cnt					<= 32'b0									;
					bit_cnt						<= 3'b000									;
					rx_d						<= 8'h00									;
				end
			endcase
		end
	end
						
	/*--------------------------------------------------------------------------------------
	--波特率计数器实现
	--------------------------------------------------------------------------------------*/
	always @(posedge clk or posedge rst_2) begin
		if(rst_2) begin
			baud_cnt							<= 32'b0									;
			baud_cnt_arrive						<= 1'b0										;
		end else begin
			case(S_RX_M)
				S_RX_IDLE_M						: begin
					baud_cnt					<= 32'b0									;
					baud_cnt_arrive				<= 1'b0										;
				end
				S_RX_PRE_M						,
				S_RX_START_PRE_M				: begin
					baud_cnt					<= 32'b0									;
					baud_cnt_arrive				<= 1'b0										;
				end
				S_RX_START_M					,
				S_RX_DATA_PRE_M					,
				S_RX_PARITY_M					,
				S_RX_STOP_M						: begin	
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
	--奇偶校验实现
	--------------------------------------------------------------------------------------*/	
	assign	bit_parity_odd						= ^rx_d[7:0]								;
	assign	bit_parity_even						= ~bit_parity_odd							;
	
	assign	bit_parity_odd_result				= (bit_parity_odd==bit_parity_data)?1'b0:1'b1;
	assign	bit_parity_even_result				= (bit_parity_even==bit_parity_data)?1'b0:1'b1;
	
	assign	bit_parity_data						= (S_RX_M==S_RX_PARITY_H_M)?1'b1
												: (S_RX_M==S_RX_PARITY_L_M)?1'b0
												: 1'b0										;
	
	
	assign	bit_parity							= (c_rs422_parity_en==1'b0)?1'b0
												: (c_rs422_parity_sel==1'b0)?bit_parity_even_result
												: bit_parity_odd_result						;	
//==================================================================================================
//--数据FIFO写入相关	
	/*--------------------------------------------------------------------------------------
	--数据FIFO写入
	--------------------------------------------------------------------------------------*/
	always @(posedge clk or posedge rst_2) begin
		if(rst_2) begin
			rx_fifo_wen							<= 1'b0										;
			rx_fifo_din							<= 32'b0									;
		end else if(S_RX_M==S_RX_DATA_M) begin	
			rx_fifo_wen							<= 1'b1										;
			rx_fifo_din							<= {1'b1,bit_parity,22'b0,rx_d[7:0]}		;
		end else if(S_RX_M==S_RX_PARITY_H_M) begin
			rx_fifo_wen							<= 1'b1										;
			rx_fifo_din							<= {1'b1,bit_parity,22'b0,rx_d[7:0]}		;
		end else if(S_RX_M==S_RX_PARITY_L_M) begin
			rx_fifo_wen							<= 1'b1										;
			rx_fifo_din							<= {1'b0,bit_parity,22'b0,rx_d[7:0]}		;
		end else begin
			rx_fifo_wen							<= 1'b0										;
			rx_fifo_din							<= 32'hdeed_beef							;
		end
	end
//==================================================================================================
//--RX_FIFO计数实现
	always @(posedge clk or posedge rst_2) begin
		if(rst_2) begin
			rx_fifo_status						<= 32'b0									;
		end else if(rx_fifo_wen && !rx_fifo_full && rx_fifo_ren && !rx_fifo_empty) begin
			rx_fifo_status						<= rx_fifo_status							;
		end else if(rx_fifo_wen && !rx_fifo_full) begin
			rx_fifo_status						<= rx_fifo_status + 1'b1					;
		end else if(rx_fifo_ren && !rx_fifo_empty) begin
			rx_fifo_status						<= rx_fifo_status - 1'b1					;
		end
	end	
	
//==================================================================================================
//--RX FIFO例化
/*	FIFO_DUALCLOCK_MACRO #(
		.ALMOST_EMPTY_OFFSET					( 9'h080									),	// Sets the almost empty threshold
		.ALMOST_FULL_OFFSET						( 9'h004									),	// Sets almost full threshold
		.DATA_WIDTH								( 16										),	// Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
		.DEVICE									( "7SERIES"									),	// Target device: "VIRTEX5", "VIRTEX6", "7SERIES"
		.FIFO_SIZE								( "36Kb"									),	// Target BRAM: "18Kb" or "36Kb"
		.FIRST_WORD_FALL_THROUGH 				( "TRUE"									)	// Sets the FIfor FWFT to "TRUE" or "FALSE"
		)
	i_rx_fifo (
		.ALMOSTEMPTY							( 											),	// 1-bit output almost empty
		.ALMOSTFULL								( 											),	// 1-bit output almost full
		.DO										( rx_fifo_dout								),	// Output data, width defined by DATA_WIDTH parameter
		.EMPTY									( rx_fifo_empty								),	// 1-bit output empty
		.FULL									( rx_fifo_full								),	// 1-bit output full
		.RDCOUNT								( 											),	// Output read count, width determined by FIfor depth
		.RDERR									( 											),	// 1-bit output read error
		.WRCOUNT								( 											),	// Output write count, width determined by FIfor depth
		.WRERR									( 											),	// 1-bit output write error
		.DI										( rx_fifo_din								),	// Input data, width defined by DATA_WIDTH parameter
		.RDCLK									( clk										),	// 1-bit input read clock
		.RDEN									( rx_fifo_ren								),	// 1-bit input read enable
		.RST									( rst_2										),	// 1-bit input reset
		.WRCLK									( clk										),	// 1-bit input write clock
		.WREN									( rx_fifo_wen								)	// 1-bit input write enable
	);
*/
fifo_16w_2048d i_rx_fifo (
  .rst(rst_2),        // input wire rst
  .wr_clk(clk),  // input wire wr_clk
  .rd_clk(clk),  // input wire rd_clk
  .din(rx_fifo_din),        // input wire [15 : 0] din
  .wr_en(rx_fifo_wen),    // input wire wr_en
  .rd_en(rx_fifo_ren),    // input wire rd_en
  .dout(rx_fifo_dout),      // output wire [15 : 0] dout
  .full(rx_fifo_full),      // output wire full
  .empty(rx_fifo_empty),
    .wr_rst_busy(),  // output wire wr_rst_busy
  .rd_rst_busy()  // output wire rd_rst_busy    // output wire empty
);
endmodule