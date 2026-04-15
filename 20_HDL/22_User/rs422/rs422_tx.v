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
// Create Date:		2018/5/11 13:16:20
// Design Name:		EC1300
// Module Name:		rs422_tx---
// Project Name:
// Target Devices:	K7-V7
// Tool Versions: 	Vivado 2016.1 HDL-EDIT UltraEdit TAB=4 Consolas
// Description:
//		妯″潡瀹炵幇RS422鐨勬暟鎹彂閫?
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
//--杈撳叆杈撳嚭绔彛瀹氫箟---------------------------
	/*--------------------------------------------------------------------------------------
	--Common Interface
	--|log_clk-->鍙互杩炴帴a锛屼篃鍙互杩炴帴澶栭儴鏃堕挓锛岃繘琛屽揩閫熸煡璇㈠鐞?
	--|rst-->澶嶄綅淇″彿锛岄珮鐢靛钩鍚屾澶嶄綅淇″彿
	--------------------------------------------------------------------------------------*/
	input										clk											,
	input										rst											,
	
	/*--------------------------------------------------------------------------------------
	--AXI_LITE妯″潡鎺ュ彛
	--------------------------------------------------------------------------------------*/	
	input			[31:0]						c_rs422_baud_rate							,	//娉㈢壒鐜囬厤缃瘎瀛樺櫒
	input										c_rs422_parity_en							,	//濂囧伓鏍￠獙浣嶄娇鑳?
	input										c_rs422_parity_sel							,	//濂囧伓鏍￠獙閫夋嫨=0锛屽鏍￠獙
	input			[2:0]						c_rs422_stop_width							,	//鍋滄浣嶄綅瀹斤紝1~3,0鏃犳晥
	
	
	/*--------------------------------------------------------------------------------------
	--RS422淇″彿瀹氫箟
	--------------------------------------------------------------------------------------*/
	(*mark_debug="TRUE"*)
	output	reg									rs422_tx									,
	output	reg									rs422_de			= 'b0					,
	/*--------------------------------------------------------------------------------------
	--TX鏁版嵁FIFO鍐欏叆
	--------------------------------------------------------------------------------------*/	
	input										tx_fifo_wen									,
	input			[31:0]						tx_fifo_din									,
	output										tx_fifo_full								,
	output	reg		[31:0]						tx_fifo_status								
	
	);

//==================================================================================================
//--Signals Define
	
	/*--------------------------------------------------------------------------------------
	--RS422 TX FIFO淇″彿瀹氫箟
	--------------------------------------------------------------------------------------*/
	(*mark_debug="TRUE"*)	
	wire			[31:0]						tx_fifo_dout								;
	wire										tx_fifo_empty								;
	reg											tx_fifo_ren									;

//==================================================================================================
//--鍙傛暟瀹氫箟
	/*--------------------------------------------------------------------------------------
	--RS422 TX鍙戦€佺姸鎬佹満
	--------------------------------------------------------------------------------------*/	
	localparam									S_TX_IDLE_M				= 6'b00_0001		;
	localparam									S_TX_START_M			= 6'b00_0010		;
	localparam									S_TX_DATA_M				= 6'b00_0100		;
	localparam									S_TX_PARITY_M			= 6'b00_1000		;
	localparam									S_TX_STOP_M				= 6'b01_0000		;
	localparam									S_TX_DONE_M				= 6'b10_0000		;

//==================================================================================================
//--淇″彿瀹氫箟	
	reg				[ 5:0]						S_TX_M										;
		
	reg				[31:0]						baud_cnt									;	//娉㈢壒鐜囪鏁板櫒
	reg											baud_cnt_arrive								;	//娉㈢壒鐜囪鏁板櫒鍒拌揪
	reg				[ 2:0]						bit_cnt										;	//bit浣嶈鏁板櫒
	
	wire										bit_parity_odd								;	//鍋舵牎楠?
	wire										bit_parity_even								;	//濂囨牎楠?
	
	reg				[23:0]						delay_cnt	= 24'h0								;	//澧炲姞甯ч棿寤舵椂
//==================================================================================================
//--鍙戦€佸疄鐜?
	/*--------------------------------------------------------------------------------------
	--鐘舵€佹満娴佺▼
	--IDLE---->鍒ゆ柇鏁版嵁鍙戦€丗IFO鏄惁涓虹┖锛屾暟鎹彂閫佷负楂樼數骞?
	--START--->寮€濮嬫爣蹇楋紝绛夊緟娉㈢壒鐜囪鏁板櫒鍒拌揪锛屾暟鎹彂閫佷负浣庣數骞?
	--DATA---->鏁版嵁浣嶏紝绛夊緟鏁版嵁浣嶈鏁板櫒bit_cnt涓庢尝鐗圭巼璁℃暟鍣ㄥ悓鏃跺埌杈撅紝鏁版嵁浣嶈鏁板櫒閫夋嫨TX_FIFO杈撳嚭
	---------->濡傛灉c_rs422_parity_en浣胯兘锛屽垯杩涘叆濂囧伓鏍￠獙锛屽惁鍒欒繘鍏TOP鐘舵€?
	--Parity-->鏍规嵁c_rs422_parity_sel閫夋嫨濂囨牎楠屾垨鑰呭伓鏍￠獙锛岀瓑寰呮尝鐗圭巼璁℃暟鍣ㄥ埌杈撅紝璺宠浆
	--STOP---->缁撴潫浣嶆爣蹇楃姸鎬侊紝鏍规嵁缁撴潫浣嶄綅瀹借绠楃粨鏉熶綅鐨勯暱搴?
	--DONE---->涓€涓懆鏈熺殑瀹屾垚鐘舵€?
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
	--娉㈢壒鐜囪鏁板櫒瀹炵幇
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
	--BIT_CNT鏁版嵁浣嶈鏁板櫒瀹炵幇
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
	--濂囧伓鏍￠獙瀹炵幇
	--------------------------------------------------------------------------------------*/	
	assign	bit_parity_odd						= ^tx_fifo_dout[7:0]						;
	assign	bit_parity_even						= ~bit_parity_odd							;
	
//==================================================================================================
//--鍙戦€佸彲鐢ㄧ┖闂磋鏁板櫒
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
//--TX FIFO渚嬪寲
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
