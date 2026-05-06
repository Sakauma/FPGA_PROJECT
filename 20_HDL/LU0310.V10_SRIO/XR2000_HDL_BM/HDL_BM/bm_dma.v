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
// Module Name:		bm_dma-BM DMA 通道
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
module bm_dma #(
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
	output			[31:0]						c_bm_up_cnt									,
	
//==================================================================================================
//--DMA Channel Signals
	/*--------------------------------------------------------------------------------------
	--DMA Channel AXI Stream Inteface
	--------------------------------------------------------------------------------------*/
	output	reg		[63:0]						dma_s_axis_tdata							,
	output			[ 3:0]						dma_s_axis_tid								,
	input										dma_s_axis_tready							,
	output	reg									dma_s_axis_tvalid							,
	output			[ 7:0]						dma_s_axis_tstrb							,
	output			[ 7:0]						dma_s_axis_tkeep							,
	output										dma_s_axis_tlast							,
	output			[63:0]						dma_s_axis_tuser							,
	output			[ 3:0]						dma_s_axis_tdest							,
//==================================================================================================
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
	input			[63:0]						bm_timestamp								,
//==================================================================================================
//--SRIO Reduncy Signals
	/*--------------------------------------------------------------------------------------
	--SRIO IP Core A Interface
	--------------------------------------------------------------------------------------*/	
	output										sarx_data_fifo_ren							,
	input										sarx_data_fifo_empty						,
	input			[63:0]						sarx_data_fifo_dout							,
	output										sarx_trn_fifo_ren							,
	input										sarx_trn_fifo_empty							,
	input			[63:0]						sarx_trn_fifo_dout							,
	                                                                                 	
	output										sbrx_data_fifo_ren							,
	input										sbrx_data_fifo_empty						,
	input			[63:0]						sbrx_data_fifo_dout							,
	output										sbrx_trn_fifo_ren							,
	input										sbrx_trn_fifo_empty							,
	input			[63:0]						sbrx_trn_fifo_dout							
	);                          	
//==================================================================================================
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
	/*--------------------------------------------------------------------------------------
	* 历史说明：原块注释编码已损坏，按当前文件头和开发文档维护。
	--------------------------------------------------------------------------------------*/
	localparam		S_UP_IDLE_M				= 7'b000_0001									;
	localparam		S_UP_HEAD1_M			= 7'b000_0010									;
	localparam		S_UP_HEAD2_M			= 7'b000_0100									;
	localparam		S_UP_HEAD3_M			= 7'b000_1000									;
	localparam		S_UP_HEAD4_M			= 7'b001_0000									;
	localparam		S_UP_DATA_M				= 7'b010_0000									;
	localparam		S_UP_DONE_M				= 7'b100_0000									;
	
	localparam		B_UP_DONE_M				= 3'd6											;				
                                
//==================================================================================================
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
	/*--------------------------------------------------------------------------------------
	* 历史说明：原块注释编码已损坏，按当前文件头和开发文档维护。
	--------------------------------------------------------------------------------------*/		
	reg				[ 6:0]						S_UP_CM										;
	reg				[ 6:0]						S_UP_NM										;
	                            	
	reg				[15:0]						up_cnt										;
	                            	
	/*--------------------------------------------------------------------------------------
	* 历史说明：原块注释编码已损坏，按当前文件头和开发文档维护。
	--------------------------------------------------------------------------------------*/	
	reg											io_sel										;
	wire			[63:0]						data_fifo_dout								;
	wire			[63:0]						trn_fifo_dout								;
	wire										data_fifo_ren								;
	wire										trn_fifo_ren								;
	
//==================================================================================================
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
	always @(posedge clk) begin
		if(rst) begin
			S_UP_CM								<= S_UP_IDLE_M								;
		end else begin
			S_UP_CM								<= S_UP_NM									;
		end
	end
	
	
	always @(*) begin
		S_UP_NM									= 'bx										;
		case(S_UP_CM)
			S_UP_IDLE_M							: begin
				if(	~sarx_trn_fifo_empty | ~sbrx_trn_fifo_empty) begin
					S_UP_NM						= S_UP_HEAD1_M								;
				end else begin
					S_UP_NM						= S_UP_IDLE_M								;
				end
			end
			S_UP_HEAD1_M						: begin
				if(dma_s_axis_tready) begin
					S_UP_NM						= S_UP_HEAD2_M								;
				end else begin
					S_UP_NM						= S_UP_HEAD1_M								;
				end
			end
			S_UP_HEAD2_M						: begin
				if(dma_s_axis_tready) begin
					S_UP_NM						= S_UP_HEAD3_M								;
				end else begin
					S_UP_NM						= S_UP_HEAD2_M								;
				end
			end
			S_UP_HEAD3_M						: begin
				if(dma_s_axis_tready) begin
					S_UP_NM						= S_UP_HEAD4_M								;
				end else begin
					S_UP_NM						= S_UP_HEAD3_M								;
				end
			end
			S_UP_HEAD4_M						: begin
				if(dma_s_axis_tready) begin
					S_UP_NM						= S_UP_DATA_M								;
				end else begin
					S_UP_NM						= S_UP_HEAD4_M								;
				end
			end
			S_UP_DATA_M							: begin
				if(up_cnt==trn_fifo_dout[15:0]+3'd3 && dma_s_axis_tready) begin
					S_UP_NM						= S_UP_DONE_M								;
				end else begin
					S_UP_NM						= S_UP_DATA_M								;
				end
			end
			S_UP_DONE_M							: begin
				S_UP_NM							= S_UP_IDLE_M								;
			end
			default								: begin
				S_UP_NM							= S_UP_IDLE_M								;
			end
		endcase
	end
				
//==================================================================================================
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
	always @(posedge clk) begin
		if(rst) begin
			up_cnt								<= 16'b0									;
		end else begin
			case(S_UP_CM)
				S_UP_IDLE_M						: begin
					up_cnt						<= 16'b0									;
				end
				S_UP_HEAD1_M					,
				S_UP_HEAD2_M					,
				S_UP_HEAD3_M					,
				S_UP_HEAD4_M					,
				S_UP_DATA_M						: begin
					if(dma_s_axis_tready) begin
						up_cnt					<= up_cnt + 1'b1							;
					end else begin
						up_cnt					<= up_cnt									;
					end
				end
				S_UP_DONE_M						: begin
					up_cnt						<= 16'b0									;
				end
				default							: begin
					up_cnt						<= up_cnt									;
				end
			endcase
		end
	end

//==================================================================================================
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
	always @(*) begin
		dma_s_axis_tdata						=	64'b0									;
		dma_s_axis_tvalid						= 	1'b0									;
		case(S_UP_CM)
			S_UP_IDLE_M							: begin
				dma_s_axis_tdata				=	64'b0									;
				dma_s_axis_tvalid				=	1'b0									;
			end
			S_UP_HEAD1_M						: begin
				dma_s_axis_tdata				= 	{
														2'b11,2'b0,2'b0,10'b0,
														trn_fifo_dout[15:0],
														16'b0,15'b0,io_sel
													}										;	// 历史说明：原尾注编码已损坏，代码含义以信号名和开发文档为准。
				dma_s_axis_tvalid				=	dma_s_axis_tready						;
			end
			S_UP_HEAD2_M						: begin
				dma_s_axis_tdata				=	bm_timestamp[63:0]						;	// 历史说明：原尾注编码已损坏，代码含义以信号名和开发文档为准。
				dma_s_axis_tvalid				=	dma_s_axis_tready						;
			end
			S_UP_HEAD3_M						: begin
				dma_s_axis_tdata				=	trn_fifo_dout[63:0]						;	//SID/DID
				dma_s_axis_tvalid				=	dma_s_axis_tready						;
			end
			S_UP_HEAD4_M						: begin
				dma_s_axis_tdata				=	64'hDEED_BEEF_5A5A_A5_A5				;
				dma_s_axis_tvalid				=	dma_s_axis_tready						;
			end
			S_UP_DATA_M							: begin
				dma_s_axis_tdata				=	data_fifo_dout[63:0]					;
				dma_s_axis_tvalid				=	dma_s_axis_tready						;
			end
			default								: begin
				dma_s_axis_tdata				=	64'b0									;
				dma_s_axis_tvalid				=	1'b0									;
			end
		endcase
	end
	
	assign	dma_s_axis_tlast					= (up_cnt==trn_fifo_dout[15:0]+3'd3 && dma_s_axis_tvalid)
												? 1'b1:1'b0									;
	
	assign	trn_fifo_ren						= dma_s_axis_tlast							;
	
	assign	data_fifo_ren						= (S_UP_CM==S_UP_DATA_M && dma_s_axis_tready)
												? 1'b1:1'b0									;
												
	assign	dma_s_axis_tid						= 0											;
	assign	dma_s_axis_tdest					= 0											;
	assign	dma_s_axis_tkeep					= 0											;
	assign	dma_s_axis_tstrb					= 0											;
	assign	dma_s_axis_tuser					= {trn_fifo_dout[14:0],1'b0}+4'd8			;

//==================================================================================================
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
	always @(posedge clk) begin
		if(rst) begin
			io_sel								<= 1'b0										;
		end else begin
			case(S_UP_CM)
				S_UP_IDLE_M						: begin
					casex({sarx_trn_fifo_empty,sbrx_trn_fifo_empty})
						2'b0x	:	io_sel		<= 1'b0										;
						2'b10	:	io_sel		<= 1'b1										;
						default	:	io_sel		<= 1'b0										;
					endcase
				end
				default							: begin
					io_sel						<= io_sel									;
				end
			endcase
		end
	end
	
	assign	sbrx_trn_fifo_ren					= (io_sel==1'b1)?S_UP_CM[B_UP_DONE_M]:1'b0	;
	assign	sarx_trn_fifo_ren					= (io_sel==1'b0)?S_UP_CM[B_UP_DONE_M]:1'b0	;
	                             	
	assign	sbrx_data_fifo_ren					= (io_sel==1'b1)?data_fifo_ren:1'b0			;
	assign	sarx_data_fifo_ren					= (io_sel==1'b0)?data_fifo_ren:1'b0			;
	
	assign	data_fifo_dout						= (io_sel==1'b1)?sbrx_data_fifo_dout
												: (io_sel==1'b0)?sarx_data_fifo_dout
												: 64'hDEED_BEEF								;
												
	assign	trn_fifo_dout						= (io_sel==1'b1)?sbrx_trn_fifo_dout
												: (io_sel==1'b0)?sarx_trn_fifo_dout
												: 64'hDEED_BEEF								;
endmodule
