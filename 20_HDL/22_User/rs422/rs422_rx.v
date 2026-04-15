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
// Create Date:		2018/5/11 13:24:01
// Design Name:		EC1300
// Module Name:		rs422_rx
// Project Name:
// Target Devices:	K7-V7
// Tool Versions: 	Vivado 2016.1 HDL-EDIT UltraEdit TAB=4 Consolas
// Description:
//		妯″潡瀹炵幇AXI Master鐨勫彂閫?
// Dependencies:
//		V1.0 寮€鍙戠増鏈?2020/2/18 16:00:46
//		V1.2-瑙ｅ喅STOP杩涘叆Start鐨勯棶棰橈紝褰揝TOP鐩存帴杩涘叆Start鏃讹紝澧炲姞涓€涓姸鎬侊紝浣垮緱
//娉㈢壒鐜囪鏁板櫒褰掗浂	2020/2/18 16:00:48
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
//--杈撳叆杈撳嚭绔彛瀹氫箟---------------------------
	/*--------------------------------------------------------------------------------------
	--Common Interface
	--|log_clk-->鍙互杩炴帴a锛屼篃鍙互杩炴帴澶栭儴鏃堕挓锛岃繘琛屽揩閫熸煡璇㈠鐞?
	--|rst-->澶嶄綅淇″彿锛岄珮鐢靛钩鍚屾澶嶄綅淇″彿
	--------------------------------------------------------------------------------------*/
	input										clk											,
	input										rst											,
	(*MARK_DEBUG="TRUE"*)	input										rx_fifo_rst											,	
	/*--------------------------------------------------------------------------------------
	--AXI_LITE妯″潡鎺ュ彛
	--------------------------------------------------------------------------------------*/	
	input			[31:0]						c_rs422_baud_rate							,	//娉㈢壒鐜囬厤缃瘎瀛樺櫒
	input										c_rs422_parity_en							,	//濂囧伓鏍￠獙浣嶄娇鑳?
	input										c_rs422_parity_sel							,	//濂囧伓鏍￠獙閫夋嫨=0锛屽鏍￠獙
	
	/*--------------------------------------------------------------------------------------
	--RS422淇″彿瀹氫箟
	--------------------------------------------------------------------------------------*/
	(*mark_debug="TRUE"*)
	input										rs422_rx									,
	/*--------------------------------------------------------------------------------------
	--TX鏁版嵁FIFO鍐欏叆
	--------------------------------------------------------------------------------------*/	
	input										rx_fifo_ren									,
	output			[31:0]						rx_fifo_dout								,
	output										rx_fifo_empty								,
	output	reg		[31:0]						rx_fifo_status
	
	);
//==================================================================================================
//--Parameter Define
	/*--------------------------------------------------------------------------------------
	--RS422 RX鎺ユ敹鐘舵€佹満鍙傛暟瀹氫箟
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
//--淇″彿瀹氫箟
	/*--------------------------------------------------------------------------------------
	--鐘舵€佹満淇″彿
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
	--璧峰鏍囧織閲囬泦
	--------------------------------------------------------------------------------------*/
	reg											rs422_rx_q1									;
	reg											rs422_rx_q2									;
	wire										rx_fe										;	//RS422 RX涓嬮檷娌?
	wire										rx_re										;	//RS422 RX涓婂崌瀹?
	reg				[31:0]						rx_l_cnt									;	//浣庣數骞宠鏁板櫒
	reg				[31:0]						rx_h_cnt									;	//楂樼數骞宠鏁板櫒
	
	reg				[31:0]						baud_3_4									;	//baud 3/4鐨勮鏁板€?
	reg				[31:0]						baud_1_2									;	//baud 1/2鐨勮鏁板€?
	
	/*--------------------------------------------------------------------------------------
	--RX_FIFO鍐欏叆
	--------------------------------------------------------------------------------------*/	
	reg				[31:0]						rx_fifo_din									;
	reg											rx_fifo_wen									;
	wire										rx_fifo_full								;
//==================================================================================================


	(*MARK_DEBUG="TRUE"*) wire rst_2;


assign rst_2 =  rst|rx_fifo_rst;


//--鎻愬墠淇″彿澶勭悊
	/*--------------------------------------------------------------------------------------
	--RX淇″彿鍚屾浠ュ強淇″彿涓嬮檷娌挎娴?
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
	
	assign	rx_fe								= ~rs422_rx_q1 && rs422_rx_q2				;	//涓嬮檷娌挎娴?
	assign	rx_re								= rs422_rx_q1 && ~rs422_rx_q2				;	//涓婂崌娌挎娴?
	
	/*--------------------------------------------------------------------------------------
	--3/4娉㈢壒鐜囪鏁板櫒鍊?
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
//--鎺ユ敹瀹炵幇	
	/*--------------------------------------------------------------------------------------
	--鎺ユ敹鐘舵€佹満娴佺▼
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
					//--绗竴涓暟鎹负楂樼數骞筹紝骞朵笖鎻愬墠鍒拌揪锛岄偅涔堟彁鍓嶈繘鍏ATA鐘舵€?
					if(rx_l_cnt>=baud_3_4 && rx_re) begin
						S_RX_M					<= S_RX_PRE_M								;
						rx_l_cnt				<= 32'b0									;
					//--瀹氭椂鏃堕棿鍒帮紝娌℃湁璋冭〃锛屽苟涓斾綆鐢靛钩鏃堕棿澶т簬3/4锛岄偅涔堣繘鍏ユ暟鎹姸鎬?
					end else if(rx_l_cnt>=baud_3_4 && baud_cnt_arrive) begin
						S_RX_M					<= S_RX_PRE_M								;
						rx_l_cnt				<= 32'b0									;
					//--瀹氭椂鏃堕棿鍒帮紝浣嗘槸娌℃湁鍒拌揪鏈夋晥鐨勪綆鐢靛钩鏃堕棿锛岃繘鍏DLE鐘舵€?
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
	--娉㈢壒鐜囪鏁板櫒瀹炵幇
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
	--濂囧伓鏍￠獙瀹炵幇
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
//--鏁版嵁FIFO鍐欏叆鐩稿叧	
	/*--------------------------------------------------------------------------------------
	--鏁版嵁FIFO鍐欏叆
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
//--RX_FIFO璁℃暟瀹炵幇
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
//--RX FIFO渚嬪寲
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
