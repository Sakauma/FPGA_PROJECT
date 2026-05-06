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
// Create Date:		2018/5/11 19:40:24
// Design Name:		XR2000
// Module Name:		sp_bm_ch
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
module bm_ch #(
	/*--------------------------------------------------------------------------------------
	--P_SIMULATION_R
	---------------------------------------------------------------------------------------*/
	parameter		P_SIMULATION_R				= "FALSE"
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
	input										srio_rst									,
//==================================================================================================
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
	input										c_bm_en										,
	
	output	reg		[31:0]						bm_recv_cnt									,
	output	reg		[31:0]						bm_up_cnt									,
	output	reg		[31:0]						bm_lost_cnt									,
	
//==================================================================================================
//--SRIO Reduncy Signals
	/*--------------------------------------------------------------------------------------
	--SRIO IP Core A Interface
	--------------------------------------------------------------------------------------*/
	input										log_clk										,
	input										axis_tvalid									,
	input										axis_tready									,
	input										axis_tlast									,
	input			[63:0]						axis_tdata									,
	input			[ 7:0]						axis_tkeep									,
	input			[31:0]						axis_tuser									,
	
	/*--------------------------------------------------------------------------------------
	--DMA BM Transmit Interface
	--------------------------------------------------------------------------------------*/	
	input										bm_data_fifo_ren							,
	output										bm_data_fifo_empty							,
	output			[63:0]						bm_data_fifo_dout							,
	
	input										bm_trn_fifo_ren								,
	output										bm_trn_fifo_empty							,
	output			[63:0]						bm_trn_fifo_dout							
	
	);
//==================================================================================================
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
	/*--------------------------------------------------------------------------------------
	* 历史说明：原块注释编码已损坏，按当前文件头和开发文档维护。
	--------------------------------------------------------------------------------------*/	
	localparam									S_B_IDLE_M				= 3'b001			;
	localparam									S_B_DATA_M				= 3'b010			;
	localparam									S_B_LOST_M				= 3'b100			;
	
//==================================================================================================
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
	/*--------------------------------------------------------------------------------------
	* 历史说明：原块注释编码已损坏，按当前文件头和开发文档维护。
	--------------------------------------------------------------------------------------*/
	reg				[ 2:0]						S_B_CM										;
	reg				[ 2:0]						S_B_NM										;
	
	reg				[31:0]						axis_tid									;
	/*--------------------------------------------------------------------------------------
	* 历史说明：原块注释编码已损坏，按当前文件头和开发文档维护。
	--------------------------------------------------------------------------------------*/
	reg											bm_data_fifo_wen							;
	reg				[63:0]						bm_data_fifo_din							;
	wire										bm_data_fifo_afull							;
	
	reg											bm_trn_fifo_wen								;
	reg				[63:0]						bm_trn_fifo_din								;
	
	reg				[15:0]						bm_data_cnt									;
	wire			[15:0]						bm_data_cnt_pre								;


//==================================================================================================
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
	always @(posedge log_clk) begin
		if(rst) begin
			S_B_CM								<= S_B_IDLE_M								;
		end else begin
			S_B_CM								<= S_B_NM									;
		end
	end
	
	always @(*) begin
		S_B_NM									= 'bx										;
		case(S_B_CM)
			S_B_IDLE_M							: begin
				if(axis_tvalid && axis_tready && axis_tlast) begin
					S_B_NM						= S_B_IDLE_M								;
				end else if(axis_tvalid && axis_tready) begin
					if(bm_data_fifo_afull || !c_bm_en) begin
						S_B_NM					= S_B_LOST_M								;
					end else begin
						S_B_NM					= S_B_DATA_M								;
					end
				end else begin
					S_B_NM						= S_B_IDLE_M								;
				end
			end
			S_B_DATA_M							: begin
				if((axis_tvalid && axis_tready && axis_tlast) | srio_rst) begin
					S_B_NM						= S_B_IDLE_M								;
				end else begin
					S_B_NM						= S_B_DATA_M								;
				end
			end
			S_B_LOST_M							: begin
				if(axis_tvalid && axis_tready && axis_tlast) begin
					S_B_NM						= S_B_IDLE_M								;
				end else begin
					S_B_NM						= S_B_LOST_M								;
				end
			end
			default								: begin
				S_B_NM							= S_B_IDLE_M								;
			end
		endcase
	end
	
//==================================================================================================
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
	always @(posedge log_clk) begin
		if(rst) begin
			bm_data_fifo_wen					<= 1'b0										;
			bm_data_fifo_din					<= 64'b0									;
		end else begin
			case(S_B_CM)
				S_B_IDLE_M						: begin
					if(axis_tvalid && axis_tlast && axis_tready && c_bm_en) begin
						bm_data_fifo_wen		<= 1'b1										;
						bm_data_fifo_din		<= axis_tdata								;
					end else if(axis_tvalid && ~bm_data_fifo_afull && c_bm_en) begin
						bm_data_fifo_wen		<= 1'b1										;
						bm_data_fifo_din		<= axis_tdata								;
					end else begin
						bm_data_fifo_wen		<= 1'b0										;
						bm_data_fifo_din		<= 64'hDEED_BEEF							;
					end
				end
				S_B_DATA_M						: begin
	                if(axis_tvalid && axis_tready && ~srio_rst) begin
	                	bm_data_fifo_wen		<= 1'b1										;
	                    bm_data_fifo_din		<= axis_tdata								;
	                end else begin          	
	                	bm_data_fifo_wen		<= 1'b0										;
	                	bm_data_fifo_din		<= axis_tdata								;
	                end
	            end
	            default							: begin
	            	bm_data_fifo_wen			<= 1'b0										;
					bm_data_fifo_din			<= 64'hDEED_BEEF							;
				end
			endcase
		end
	end
	
	always @(posedge log_clk or posedge rst) begin
		if(rst) begin
			axis_tid							<= 32'b0									;
		end else begin
			case(S_B_CM)
				S_B_IDLE_M						: begin
					axis_tid					<= axis_tuser								;
				end
				S_B_DATA_M						: begin
					axis_tid					<= axis_tid									;
				end
				default							: begin
					axis_tid					<= axis_tid									;
				end
			endcase
		end
	end
	
	
	always @(posedge log_clk or posedge rst) begin
		if(rst) begin
			bm_data_cnt							<= 16'b0									;
		end else begin
			case(S_B_CM)
				S_B_IDLE_M						: begin
					if(axis_tvalid && axis_tready && axis_tlast) begin
						bm_data_cnt				<= 16'b0									;
					end else if(axis_tvalid && axis_tready) begin
						bm_data_cnt				<= bm_data_cnt + 1'b1						;
					end else begin
						bm_data_cnt				<= 16'b0									;
					end
				end
				S_B_DATA_M						: begin
					if((axis_tvalid && axis_tready && axis_tlast)| srio_rst) begin
						bm_data_cnt				<= 16'b0									;
					end else if(axis_tvalid && axis_tready) begin
						bm_data_cnt				<= bm_data_cnt + 1'b1						;
					end else begin
						bm_data_cnt				<= bm_data_cnt								;
					end
				end
			endcase
		end
	end
	
	assign	bm_data_cnt_pre						= bm_data_cnt + 1'b1						;
		
	always @(posedge log_clk or posedge rst) begin
		if(rst) begin
			bm_trn_fifo_din						<= 64'b0									;
			bm_trn_fifo_wen						<= 1'b0										;
		end else begin
			case(S_B_CM)
				S_B_IDLE_M						: begin
					if(axis_tvalid && axis_tready && axis_tlast && c_bm_en) begin
						bm_trn_fifo_din			<= {axis_tuser,16'h1234,16'd1}				;
						bm_trn_fifo_wen			<= 1'b1										;
					end else begin
						bm_trn_fifo_din			<= 64'hDEED_BEEF							;
						bm_trn_fifo_wen			<= 1'b0										;
					end
				end
				S_B_DATA_M						: begin
					if(axis_tvalid && axis_tready && axis_tlast) begin
						bm_trn_fifo_din			<= {axis_tid[31:0],16'h5678,bm_data_cnt_pre};
						bm_trn_fifo_wen			<= 1'b1										;
					end else if(srio_rst) begin
						bm_trn_fifo_din			<= {axis_tid[31:0],16'h5678,bm_data_cnt}	;
						bm_trn_fifo_wen			<= 1'b1										;
					end else begin
						bm_trn_fifo_din			<= 64'hDEED_BEEF							;
						bm_trn_fifo_wen			<= 1'b0										;
					end
				end
				default							: begin
					bm_trn_fifo_din				<= 64'hDEED_BEEF							;
					bm_trn_fifo_wen				<= 1'b0										;
				end
			endcase
		end
	end
	
//==================================================================================================
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
	always @(posedge log_clk or posedge rst) begin
		if(rst) begin
			bm_recv_cnt							<= 32'b0									;
		end else if(axis_tvalid && axis_tready && axis_tlast) begin
			bm_recv_cnt							<= bm_recv_cnt + 1'b1						;
		end else begin
			bm_recv_cnt							<= bm_recv_cnt								;
		end
	end
	
	always @(posedge log_clk or posedge rst) begin
		if(rst) begin
			bm_up_cnt							<= 32'b0									;
		end else if(bm_trn_fifo_wen) begin
			bm_up_cnt							<= bm_up_cnt + 1'b1							;
		end else begin
			bm_up_cnt							<= bm_up_cnt								;
		end
	end
	
	always @(posedge log_clk or posedge rst) begin
		if(rst) begin
			bm_lost_cnt							<= 32'b0									;
		end else if((S_B_LOST_M==S_B_CM && axis_tvalid && axis_tready && axis_tlast) 
				 ||(S_B_IDLE_M==S_B_CM && axis_tvalid && axis_tready && axis_tlast && !c_bm_en)) begin
			bm_lost_cnt							<= bm_lost_cnt + 1'b1						;
		end else begin
			bm_lost_cnt							<= bm_lost_cnt								;
		end
	end

	
//==================================================================================================
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
	FIFO_DUALCLOCK_MACRO #(
		.ALMOST_EMPTY_OFFSET					( 9'h080									),	// Sets the almost empty threshold
		.ALMOST_FULL_OFFSET						( 9'h024									),	// Sets almost full threshold
		.DATA_WIDTH								( 64										),	// Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
		.DEVICE									( "7SERIES"									),	// Target device: "VIRTEX5", "VIRTEX6", "7SERIES"
		.FIFO_SIZE								( "36Kb"									),	// Target BRAM: "18Kb" or "36Kb"
		.FIRST_WORD_FALL_THROUGH 				( "TRUE"									)	// Sets the FIfor FWFT to "TRUE" or "FALSE"
		)
	i_data_fifo (
		.ALMOSTEMPTY							( 											),	// 1-bit output almost empty
		.ALMOSTFULL								( bm_data_fifo_afull						),	// 1-bit output almost full
		.DO										( bm_data_fifo_dout							),	// Output data, width defined by DATA_WIDTH parameter
		.EMPTY									( bm_data_fifo_empty						),	// 1-bit output empty
		.FULL									( 					 						),	// 1-bit output full
		.RDCOUNT								( 											),	// Output read count, width determined by FIfor depth
		.RDERR									( 											),	// 1-bit output read error
		.WRCOUNT								( 											),	// Output write count, width determined by FIfor depth
		.WRERR									( 											),	// 1-bit output write error
		.DI										( bm_data_fifo_din							),	// Input data, width defined by DATA_WIDTH parameter
		.RDCLK									( clk										),	// 1-bit input read clock
		.RDEN									( bm_data_fifo_ren							),	// 1-bit input read enable
		.RST									( rst										),	// 1-bit input reset
		.WRCLK									( log_clk									),	// 1-bit input write clock
		.WREN									( bm_data_fifo_wen							)	// 1-bit input write enable
	);
	
	FIFO_DUALCLOCK_MACRO #(
		.ALMOST_EMPTY_OFFSET					( 9'h080									),	// Sets the almost empty threshold
		.ALMOST_FULL_OFFSET						( 9'h024									),	// Sets almost full threshold
		.DATA_WIDTH								( 64										),	// Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
		.DEVICE									( "7SERIES"									),	// Target device: "VIRTEX5", "VIRTEX6", "7SERIES"
		.FIFO_SIZE								( "36Kb"									),	// Target BRAM: "18Kb" or "36Kb"
		.FIRST_WORD_FALL_THROUGH 				( "TRUE"									)	// Sets the FIfor FWFT to "TRUE" or "FALSE"
		)
	i_trn_fifo (
		.ALMOSTEMPTY							( 											),	// 1-bit output almost empty
		.ALMOSTFULL								( 											),	// 1-bit output almost full
		.DO										( bm_trn_fifo_dout							),	// Output data, width defined by DATA_WIDTH parameter
		.EMPTY									( bm_trn_fifo_empty							),	// 1-bit output empty
		.FULL									( 					 						),	// 1-bit output full
		.RDCOUNT								( 											),	// Output read count, width determined by FIfor depth
		.RDERR									( 											),	// 1-bit output read error
		.WRCOUNT								( 											),	// Output write count, width determined by FIfor depth
		.WRERR									( 											),	// 1-bit output write error
		.DI										( bm_trn_fifo_din							),	// Input data, width defined by DATA_WIDTH parameter
		.RDCLK									( clk										),	// 1-bit input read clock
		.RDEN									( bm_trn_fifo_ren							),	// 1-bit input read enable
		.RST									( rst										),	// 1-bit input reset
		.WRCLK									( log_clk									),	// 1-bit input write clock
		.WREN									( bm_trn_fifo_wen							)	// 1-bit input write enable
	);

endmodule
