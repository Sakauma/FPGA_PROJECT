// ============================================================================
// 新增维护说明
// 文件职责      : 当前文件为手工维护源码，承担本模块/脚本的真实实现。
// 维护边界      : 本注释块仅补充维护说明，不改写任何原有说明、历史注释或现有逻辑。
// 修改约束      : 后续如需继续补充说明，只允许追加中文注释，不得替换旧注释或改动旧代码。
// 生成关系      : 若存在对应生成物，应以当前手工源码为准，禁止反向覆盖本文件。
// ============================================================================
 `timescale 1ns/1ns
//////////////////////////////////////////////////////////////////////////////////
// Company:			HXZY
// Engineer:		ZYL
// Create Date:		2018/5/11 19:40:24
// Design Name:		XR2000
// Module Name:		bm_top-BM DMA通道
// Project Name:
// Target Devices:	K7-V7
// Tool Versions: 	Vivado 2016.1 HDL-EDIT UltraEdit TAB=4 Consolas
// Description:
//		文件为基于Xilinx SRIO IP Core的Rapid IO冗余模块顶层文件
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
//--输入输出端口定义---------------------------
	/*--------------------------------------------------------------------------------------
	--Common Interface
	--|clk-->可以连接log_clk，也可以连接外部时钟，进行快速查询处理
	--|rst-->复位信号，高电平同步复位信号
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
//--时标模块接口
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
//--参数定义                    
	/*--------------------------------------------------------------------------------------
	--状态机参数定义            
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
//--信号定义                    
	/*--------------------------------------------------------------------------------------
	--DMA控制状态机信号定义     
	--------------------------------------------------------------------------------------*/		
	reg				[ 6:0]						S_UP_CM										;
	reg				[ 6:0]						S_UP_NM										;
	                            	
	reg				[15:0]						up_cnt										;
	                            	
	/*--------------------------------------------------------------------------------------
	--仲裁信号实现                  
	--------------------------------------------------------------------------------------*/	
	reg											io_sel										;
	wire			[63:0]						data_fifo_dout								;
	wire			[63:0]						trn_fifo_dout								;
	wire										data_fifo_ren								;
	wire										trn_fifo_ren								;
	
//==================================================================================================
//--状态机实现	
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
//--up_cnt实现
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
//--DMA相关信号实现
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
													}										;	//包头+通道编号
				dma_s_axis_tvalid				=	dma_s_axis_tready						;
			end
			S_UP_HEAD2_M						: begin
				dma_s_axis_tdata				=	bm_timestamp[63:0]						;	//时标
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
//--IO Sel实现
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