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
// Create Date:		2018/5/11 19:52:11
// Design Name:		XR2000
// Module Name:		sp_up
// Project Name:
// Target Devices:	K7-V7
// Tool Versions: 	Vivado 2016.1 HDL-EDIT UltraEdit TAB=4 Consolas
// Description:
//		文件实现SRIO冗余IP Core接收到的数据上传
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
//////////////////////////////////////////////////////////////////////////////////
module sp_cond_up #(
	/*--------------------------------------------------------------------------------------
	--P_SIMULATION_R
	---------------------------------------------------------------------------------------*/
	parameter									P_SIMULATION_R			= "FALSE"			,
	parameter									P_BIG_CACHE_R			= "FALSE"
	)(
//==================================================================================================
//--输入输出端口定义---------------------------
	/*--------------------------------------------------------------------------------------
	--Common Interface
	--|clk-->可以连接log_clk，也可以连接外部时钟，进行快速查询处理
	--|rst-->复位信号，高电平同步复位信号
	--------------------------------------------------------------------------------------*/
	input										clk											,
	input										log_clk										,
	input										rst											,
	input										srio_rst									,
	/*--------------------------------------------------------------------------------------
	--统计寄存器
	--------------------------------------------------------------------------------------*/	
	output	reg		[31:0]						c_sp_up_cnt									,
	output	reg		[31:0]						c_sp_rx_cnt									,

//==================================================================================================
//--DMA Channel Signals
	/*--------------------------------------------------------------------------------------
	--DMA Channel AXI Stream Inteface
	--------------------------------------------------------------------------------------*/
	output			[63:0]						dma_s_axis_tdata							,
	output			[ 3:0]						dma_s_axis_tid								,
	input										dma_s_axis_tready							,
	output										dma_s_axis_tvalid							,
	output			[ 7:0]						dma_s_axis_tstrb							,
	output			[ 7:0]						dma_s_axis_tkeep							,
	output										dma_s_axis_tlast							,
	output			[63:0]						dma_s_axis_tuser							,
	output			[ 3:0]						dma_s_axis_tdest							,

//==================================================================================================
//--SRIO Reduncy Signals
	/*--------------------------------------------------------------------------------------
	--USER SRIO Redundancy Interface
	--------------------------------------------------------------------------------------*/
	input										sr_iorx_tvalid								,
	output										sr_iorx_tready								,
	input										sr_iorx_tlast								,
	input			[63:0]						sr_iorx_tdata								,
	input			[ 7:0]						sr_iorx_tkeep								,
	input			[31:0]						sr_iorx_tuser
	);
//==================================================================================================
//--参数定义
	/*--------------------------------------------------------------------------------------
	--状态机参数
	--------------------------------------------------------------------------------------*/
	localparam									S_SR_IDLE_M				= 2'b01				;
	localparam									S_SR_DATA_M				= 2'b10				;
	
	/*--------------------------------------------------------------------------------------
	--DMA接口状态参数定义
	--------------------------------------------------------------------------------------*/	
	localparam									S_D_IDLE_M				= 4'b0001			;
	localparam									S_D_PRE_M				= 4'b0010			;
	localparam									S_D_DATA_M				= 4'b0100			;
	localparam									S_D_DONE_M				= 4'b1000			;
	
//==================================================================================================
//--信号定义
	/*--------------------------------------------------------------------------------------
	--SRIO RX接口处理
	--------------------------------------------------------------------------------------*/	
	reg				[ 1:0]						S_SR_NM										;
	reg				[ 1:0]						S_SR_CM										;
	
	reg				[31:0]						sr_iorx_id									;
	reg				[15:0]						sr_iorx_cnt									;
	wire			[15:0]						sr_iorx_cnt_pre								;
	
	/*--------------------------------------------------------------------------------------
	--DMA接口状态机信号定义
	--------------------------------------------------------------------------------------*/	
	reg				[ 3:0]						S_D_CM										;
	reg				[ 3:0]						S_D_NM										;
	
	reg				[15:0]						dma_cnt										;
	wire			[15:0]						dma_s_len									;
	
	/*--------------------------------------------------------------------------------------
	--数据及事务FIFO信号定义
	--------------------------------------------------------------------------------------*/	
	wire			[63:0]						data_fifo_din								;
	wire										data_fifo_wen								;
	wire										data_fifo_full								;
	
	wire			[63:0]						data_fifo_dout								;
	wire										data_fifo_ren								;
	wire										data_fifo_empty								;
	
	reg				[63:0]						trn_fifo_din								;
	reg											trn_fifo_wen								;
	
	wire			[63:0]						trn_fifo_dout								;
	wire										trn_fifo_ren								;
	wire										trn_fifo_empty								;
	wire										trn_fifo_full								;

//==================================================================================================
//--SRIO数据接收写入FIFO
	always @(posedge log_clk or posedge rst) begin
		if(rst) begin
			S_SR_CM								<= S_SR_IDLE_M								;
		end else begin
			S_SR_CM								<= S_SR_NM									;
		end
	end

	always @(*) begin		
		S_SR_NM									= 'bx										;
		case(S_SR_CM)
			S_SR_IDLE_M							: begin
				if(sr_iorx_tvalid && sr_iorx_tready && sr_iorx_tlast) begin
					S_SR_NM						= S_SR_IDLE_M								;
				end else if(sr_iorx_tvalid && sr_iorx_tready) begin
					S_SR_NM						= S_SR_DATA_M								;
				end else begin
					S_SR_NM						= S_SR_IDLE_M								;
				end
			end
			S_SR_DATA_M							: begin
				if((sr_iorx_tvalid && sr_iorx_tready && sr_iorx_tlast)|srio_rst) begin
					S_SR_NM						= S_SR_IDLE_M								;
				end else begin
					S_SR_NM						= S_SR_DATA_M								;
				end
			end
			default								: begin
				S_SR_NM							= S_SR_IDLE_M								;
			end
		endcase
	end

	always @(posedge log_clk or posedge rst) begin
		if(rst) begin
			sr_iorx_id							<= 32'b0									;
		end else begin
			case(S_SR_CM)
				S_SR_IDLE_M						: begin
					sr_iorx_id					<= sr_iorx_tuser							;
				end
				S_SR_DATA_M						: begin
					sr_iorx_id					<= sr_iorx_id								;
				end
				default							: begin
					sr_iorx_id					<= sr_iorx_id								;
				end
			endcase
		end
	end
	
	always @(posedge log_clk or posedge rst) begin
		if(rst) begin
			sr_iorx_cnt							<= 16'b0									;
		end else begin
			case(S_SR_CM)
				S_SR_IDLE_M						: begin
					if(sr_iorx_tvalid && sr_iorx_tready && sr_iorx_tlast) begin
						sr_iorx_cnt				<= 16'b0									;
					end else if(sr_iorx_tvalid && sr_iorx_tready) begin
						sr_iorx_cnt				<= sr_iorx_cnt + 1'b1						;
					end else begin
						sr_iorx_cnt				<= 16'b0									;
					end
				end
				S_SR_DATA_M						: begin
					if((sr_iorx_tvalid && sr_iorx_tready && sr_iorx_tlast) | srio_rst) begin
						sr_iorx_cnt				<= 16'b0									;
					end else if(sr_iorx_tvalid && sr_iorx_tready) begin
						sr_iorx_cnt				<= sr_iorx_cnt + 1'b1						;
					end else begin
						sr_iorx_cnt				<= sr_iorx_cnt								;
					end
				end
			endcase
		end
	end
	
	assign	sr_iorx_cnt_pre						= sr_iorx_cnt + 1'b1						;
	
	assign	data_fifo_wen						= sr_iorx_tvalid && sr_iorx_tready && ~srio_rst;
	
//	wire			[63:0]						sr_iorx_tdata_swap							;
//	assign	sr_iorx_tdata_swap					= 	{
//														sr_iorx_tdata[7:0],
//														sr_iorx_tdata[15:8],
//														sr_iorx_tdata[23:16],
//														sr_iorx_tdata[31:24],
//														sr_iorx_tdata[39:32],
//														sr_iorx_tdata[47:40],
//														sr_iorx_tdata[55:48],
//														sr_iorx_tdata[63:56]
//													}										;

//	assign	data_fifo_din						= (sr_iorx_cnt==0)?sr_iorx_tdata:sr_iorx_tdata;
	assign	data_fifo_din						= sr_iorx_tdata								;
	assign	sr_iorx_tready						= (data_fifo_full==1'b0 && trn_fifo_full==1'b0)?1'b1:1'b0;
	
	always @(posedge log_clk or posedge rst) begin
		if(rst) begin
			trn_fifo_din						<= 64'b0									;
			trn_fifo_wen						<= 1'b0										;
		end else begin
			case(S_SR_CM)
				S_SR_IDLE_M						: begin
					if(sr_iorx_tvalid && sr_iorx_tlast && sr_iorx_tready ) begin
						trn_fifo_din			<= {sr_iorx_tuser,16'h1234,16'd1}			;
						trn_fifo_wen			<= 1'b1										;
					end else begin
						trn_fifo_din			<= 64'hDEED_BEEF							;
						trn_fifo_wen			<= 1'b0										;
					end
				end
				S_SR_DATA_M						: begin
					if(sr_iorx_tvalid && sr_iorx_tlast && sr_iorx_tready) begin
						trn_fifo_din			<= {sr_iorx_id[31:0],16'h5678,sr_iorx_cnt_pre}	;
						trn_fifo_wen			<= 1'b1										;
					end else if(srio_rst) begin
						trn_fifo_din			<= {sr_iorx_id[31:0],16'h5678,sr_iorx_cnt}	;
						trn_fifo_wen			<= 1'b1										;
					end else begin
						trn_fifo_din			<= 64'hDEED_BEEF							;
						trn_fifo_wen			<= 1'b0										;
					end
				end
				default							: begin
					trn_fifo_din				<= 64'hDEED_BEEF							;
					trn_fifo_wen				<= 1'b0										;
				end
			endcase
		end
	end
	
	always @(posedge log_clk or posedge rst) begin
		if(rst) begin
			c_sp_rx_cnt							<= 32'b0									;
		end else if(sr_iorx_tvalid && sr_iorx_tlast && sr_iorx_tready) begin
			c_sp_rx_cnt							<= c_sp_rx_cnt + 1'b1						;
		end else begin
			c_sp_rx_cnt							<= c_sp_rx_cnt								;
		end
	end
	
//==================================================================================================
//--DMA信号实现
	always @(posedge clk or posedge rst) begin
		if(rst) begin
			S_D_CM								<= S_D_IDLE_M								;
		end else begin
			S_D_CM								<= S_D_NM									;
		end
	end

	always @(*) begin
		if(rst) begin
			S_D_NM								= S_D_IDLE_M								;
		end else begin
			case(S_D_CM)
				S_D_IDLE_M						: begin
					if(!trn_fifo_empty) begin
						S_D_NM					= S_D_PRE_M									;
					end else begin
						S_D_NM					= S_D_IDLE_M								;
					end
				end
				S_D_PRE_M						: begin
					if(dma_s_axis_tready) begin
						S_D_NM					= S_D_DATA_M								;
					end else begin
						S_D_NM					= S_D_PRE_M									;
					end
				end
				S_D_DATA_M						: begin
//					if(dma_cnt==trn_fifo_dout[15:0] && dma_s_axis_tready) begin
					if(dma_s_axis_tlast) begin
						S_D_NM					= S_D_DONE_M								;
					end else begin
						S_D_NM					= S_D_DATA_M								;
					end
				end
				S_D_DONE_M						: begin
					S_D_NM						= S_D_IDLE_M								;
				end
				default							: begin
					S_D_NM						= S_D_IDLE_M								;
				end
			endcase
		end
	end
	
	always @(posedge clk or posedge rst) begin
		if(rst) begin
			dma_cnt								<= 16'b0									;
		end else if(S_D_DATA_M==S_D_CM || S_D_PRE_M==S_D_CM)  begin
			if(dma_s_axis_tready) begin
				dma_cnt							<= dma_cnt + 1'b1							;
			end else begin
				dma_cnt							<= dma_cnt									;
			end
		end else begin
			dma_cnt								<= 16'b0									;
		end
	end
	
	assign	dma_s_axis_tdata					= (S_D_CM==S_D_PRE_M)
												? trn_fifo_dout:data_fifo_dout				;
	
	assign	dma_s_axis_tvalid					= ((S_D_DATA_M==S_D_CM || S_D_PRE_M==S_D_CM) && dma_s_axis_tready)
												? 1'b1:1'b0									;
	
	assign	dma_s_axis_tuser[63:0]				= {48'b0,dma_s_len[15:0]}					;

	assign	dma_s_len[15:0]						= {trn_fifo_dout[14:0],1'b0}+2'b10			;
	
	assign	dma_s_axis_tlast					= (dma_cnt==trn_fifo_dout[15:0]&& dma_s_axis_tvalid)
												? 1'b1:1'b0									;
	
	assign	data_fifo_ren						= (S_D_DATA_M==S_D_CM && dma_s_axis_tready)
												? 1'b1:1'b0									;
	
	assign	trn_fifo_ren						= (S_D_CM==S_D_DONE_M)?1'b1:1'b0			;
	
	assign	dma_s_axis_tid						= 0											;
	assign	dma_s_axis_tdest					= 0											;
	assign	dma_s_axis_tkeep					= 0											;
	assign	dma_s_axis_tstrb					= 0											;
	
	always @(posedge clk or posedge rst) begin
		if(rst) begin
			c_sp_up_cnt							<= 32'b0									;
		end else if(trn_fifo_ren) begin
			c_sp_up_cnt							<= c_sp_up_cnt + 1'b1						;
		end else begin
			c_sp_up_cnt							<= c_sp_up_cnt								;
		end
	end
	
//==================================================================================================
//--FIFO例化
generate if(P_BIG_CACHE_R=="TRUE") begin: CACHE_G
	FIFO_DUALCLOCK_MACRO #(
		.ALMOST_EMPTY_OFFSET					( 9'h080									),	// Sets the almost empty threshold
		.ALMOST_FULL_OFFSET						( 9'h004									),	// Sets almost full threshold
		.DATA_WIDTH								( 8											),	// Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
		.DEVICE									( "7SERIES"									),	// Target device: "VIRTEX5", "VIRTEX6", "7SERIES"
		.FIFO_SIZE								( "36Kb"									),	// Target BRAM: "18Kb" or "36Kb"
		.FIRST_WORD_FALL_THROUGH 				( "TRUE"									)	// Sets the FIfor FWFT to "TRUE" or "FALSE"
	)
	i0_data_fifo (
		.ALMOSTEMPTY							( 											),	// 1-bit output almost empty
		.ALMOSTFULL								( 											),	// 1-bit output almost full
		.DO										( data_fifo_dout[7:0]						),	// Output data, width defined by DATA_WIDTH parameter
		.EMPTY									( data_fifo_empty							),	// 1-bit output empty
		.FULL									( data_fifo_full 							),	// 1-bit output full
		.RDCOUNT								( 											),	// Output read count, width determined by FIfor depth
		.RDERR									( 											),	// 1-bit output read error
		.WRCOUNT								( 											),	// Output write count, width determined by FIfor depth
		.WRERR									( 											),	// 1-bit output write error
		.DI										( data_fifo_din[7:0]						),	// Input data, width defined by DATA_WIDTH parameter
		.RDCLK									( clk										),	// 1-bit input read clock
		.RDEN									( data_fifo_ren								),	// 1-bit input read enable
		.RST									( rst										),	// 1-bit input reset
		.WRCLK									( log_clk									),	// 1-bit input write clock
		.WREN									( data_fifo_wen								)	// 1-bit input write enable
	);
	
	FIFO_DUALCLOCK_MACRO #(
		.ALMOST_EMPTY_OFFSET					( 9'h080									),	// Sets the almost empty threshold
		.ALMOST_FULL_OFFSET						( 9'h004									),	// Sets almost full threshold
		.DATA_WIDTH								( 8											),	// Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
		.DEVICE									( "7SERIES"									),	// Target device: "VIRTEX5", "VIRTEX6", "7SERIES"
		.FIFO_SIZE								( "36Kb"									),	// Target BRAM: "18Kb" or "36Kb"
		.FIRST_WORD_FALL_THROUGH 				( "TRUE"									)	// Sets the FIfor FWFT to "TRUE" or "FALSE"
		)
	i1_data_fifo (
		.ALMOSTEMPTY							( 											),	// 1-bit output almost empty
		.ALMOSTFULL								( 											),	// 1-bit output almost full
		.DO										( data_fifo_dout[15:8]						),	// Output data, width defined by DATA_WIDTH parameter
		.EMPTY									( 											),	// 1-bit output empty
		.FULL									( 											),	// 1-bit output full
		.RDCOUNT								( 											),	// Output read count, width determined by FIfor depth
		.RDERR									( 											),	// 1-bit output read error
		.WRCOUNT								( 											),	// Output write count, width determined by FIfor depth
		.WRERR									( 											),	// 1-bit output write error
		.DI										( data_fifo_din[15:8]						),	// Input data, width defined by DATA_WIDTH parameter
		.RDCLK									( clk										),	// 1-bit input read clock
		.RDEN									( data_fifo_ren								),	// 1-bit input read enable
		.RST									( rst										),	// 1-bit input reset
		.WRCLK									( log_clk									),	// 1-bit input write clock
		.WREN									( data_fifo_wen								)	// 1-bit input write enable
	);
	
	FIFO_DUALCLOCK_MACRO #(
		.ALMOST_EMPTY_OFFSET					( 9'h080									),	// Sets the almost empty threshold
		.ALMOST_FULL_OFFSET						( 9'h004									),	// Sets almost full threshold
		.DATA_WIDTH								( 8											),	// Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
		.DEVICE									( "7SERIES"									),	// Target device: "VIRTEX5", "VIRTEX6", "7SERIES"
		.FIFO_SIZE								( "36Kb"									),	// Target BRAM: "18Kb" or "36Kb"
		.FIRST_WORD_FALL_THROUGH 				( "TRUE"									)	// Sets the FIfor FWFT to "TRUE" or "FALSE"
		)
	i2_data_fifo (
		.ALMOSTEMPTY							( 											),	// 1-bit output almost empty
		.ALMOSTFULL								( 											),	// 1-bit output almost full
		.DO										( data_fifo_dout[23:16]						),	// Output data, width defined by DATA_WIDTH parameter
		.EMPTY									( 											),	// 1-bit output empty
		.FULL									( 											),	// 1-bit output full
		.RDCOUNT								( 											),	// Output read count, width determined by FIfor depth
		.RDERR									( 											),	// 1-bit output read error
		.WRCOUNT								( 											),	// Output write count, width determined by FIfor depth
		.WRERR									( 											),	// 1-bit output write error
		.DI										( data_fifo_din[23:16]						),	// Input data, width defined by DATA_WIDTH parameter
		.RDCLK									( clk										),	// 1-bit input read clock
		.RDEN									( data_fifo_ren								),	// 1-bit input read enable
		.RST									( rst										),	// 1-bit input reset
		.WRCLK									( log_clk									),	// 1-bit input write clock
		.WREN									( data_fifo_wen								)	// 1-bit input write enable
	);
	
	FIFO_DUALCLOCK_MACRO #(
		.ALMOST_EMPTY_OFFSET					( 9'h080									),	// Sets the almost empty threshold
		.ALMOST_FULL_OFFSET						( 9'h004									),	// Sets almost full threshold
		.DATA_WIDTH								( 8											),	// Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
		.DEVICE									( "7SERIES"									),	// Target device: "VIRTEX5", "VIRTEX6", "7SERIES"
		.FIFO_SIZE								( "36Kb"									),	// Target BRAM: "18Kb" or "36Kb"
		.FIRST_WORD_FALL_THROUGH 				( "TRUE"									)	// Sets the FIfor FWFT to "TRUE" or "FALSE"
		)
	i3_data_fifo (
		.ALMOSTEMPTY							( 											),	// 1-bit output almost empty
		.ALMOSTFULL								( 											),	// 1-bit output almost full
		.DO										( data_fifo_dout[31:24]						),	// Output data, width defined by DATA_WIDTH parameter
		.EMPTY									( 											),	// 1-bit output empty
		.FULL									( 											),	// 1-bit output full
		.RDCOUNT								( 											),	// Output read count, width determined by FIfor depth
		.RDERR									( 											),	// 1-bit output read error
		.WRCOUNT								( 											),	// Output write count, width determined by FIfor depth
		.WRERR									( 											),	// 1-bit output write error
		.DI										( data_fifo_din[31:24]						),	// Input data, width defined by DATA_WIDTH parameter
		.RDCLK									( clk										),	// 1-bit input read clock
		.RDEN									( data_fifo_ren								),	// 1-bit input read enable
		.RST									( rst										),	// 1-bit input reset
		.WRCLK									( log_clk									),	// 1-bit input write clock
		.WREN									( data_fifo_wen								)	// 1-bit input write enable
	);
	
	FIFO_DUALCLOCK_MACRO #(
		.ALMOST_EMPTY_OFFSET					( 9'h080									),	// Sets the almost empty threshold
		.ALMOST_FULL_OFFSET						( 9'h004									),	// Sets almost full threshold
		.DATA_WIDTH								( 8											),	// Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
		.DEVICE									( "7SERIES"									),	// Target device: "VIRTEX5", "VIRTEX6", "7SERIES"
		.FIFO_SIZE								( "36Kb"									),	// Target BRAM: "18Kb" or "36Kb"
		.FIRST_WORD_FALL_THROUGH 				( "TRUE"									)	// Sets the FIfor FWFT to "TRUE" or "FALSE"
		)
	i4_data_fifo (
		.ALMOSTEMPTY							( 											),	// 1-bit output almost empty
		.ALMOSTFULL								( 											),	// 1-bit output almost full
		.DO										( data_fifo_dout[39:32]						),	// Output data, width defined by DATA_WIDTH parameter
		.EMPTY									( 											),	// 1-bit output empty
		.FULL									( 											),	// 1-bit output full
		.RDCOUNT								( 											),	// Output read count, width determined by FIfor depth
		.RDERR									( 											),	// 1-bit output read error
		.WRCOUNT								( 											),	// Output write count, width determined by FIfor depth
		.WRERR									( 											),	// 1-bit output write error
		.DI										( data_fifo_din[39:32]						),	// Input data, width defined by DATA_WIDTH parameter
		.RDCLK									( clk										),	// 1-bit input read clock
		.RDEN									( data_fifo_ren								),	// 1-bit input read enable
		.RST									( rst										),	// 1-bit input reset
		.WRCLK									( log_clk									),	// 1-bit input write clock
		.WREN									( data_fifo_wen								)	// 1-bit input write enable
	);
	
	FIFO_DUALCLOCK_MACRO #(
		.ALMOST_EMPTY_OFFSET					( 9'h080									),	// Sets the almost empty threshold
		.ALMOST_FULL_OFFSET						( 9'h004									),	// Sets almost full threshold
		.DATA_WIDTH								( 8											),	// Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
		.DEVICE									( "7SERIES"									),	// Target device: "VIRTEX5", "VIRTEX6", "7SERIES"
		.FIFO_SIZE								( "36Kb"									),	// Target BRAM: "18Kb" or "36Kb"
		.FIRST_WORD_FALL_THROUGH 				( "TRUE"									)	// Sets the FIfor FWFT to "TRUE" or "FALSE"
		)
	i5_data_fifo (
		.ALMOSTEMPTY							( 											),	// 1-bit output almost empty
		.ALMOSTFULL								( 											),	// 1-bit output almost full
		.DO										( data_fifo_dout[47:40]						),	// Output data, width defined by DATA_WIDTH parameter
		.EMPTY									( 											),	// 1-bit output empty
		.FULL									( 											),	// 1-bit output full
		.RDCOUNT								( 											),	// Output read count, width determined by FIfor depth
		.RDERR									( 											),	// 1-bit output read error
		.WRCOUNT								( 											),	// Output write count, width determined by FIfor depth
		.WRERR									( 											),	// 1-bit output write error
		.DI										( data_fifo_din[47:40]						),	// Input data, width defined by DATA_WIDTH parameter
		.RDCLK									( clk										),	// 1-bit input read clock
		.RDEN									( data_fifo_ren								),	// 1-bit input read enable
		.RST									( rst										),	// 1-bit input reset
		.WRCLK									( log_clk									),	// 1-bit input write clock
		.WREN									( data_fifo_wen								)	// 1-bit input write enable
	);
	
	FIFO_DUALCLOCK_MACRO #(
		.ALMOST_EMPTY_OFFSET					( 9'h080									),	// Sets the almost empty threshold
		.ALMOST_FULL_OFFSET						( 9'h004									),	// Sets almost full threshold
		.DATA_WIDTH								( 8											),	// Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
		.DEVICE									( "7SERIES"									),	// Target device: "VIRTEX5", "VIRTEX6", "7SERIES"
		.FIFO_SIZE								( "36Kb"									),	// Target BRAM: "18Kb" or "36Kb"
		.FIRST_WORD_FALL_THROUGH 				( "TRUE"									)	// Sets the FIfor FWFT to "TRUE" or "FALSE"
		)
	i6_data_fifo (
		.ALMOSTEMPTY							( 											),	// 1-bit output almost empty
		.ALMOSTFULL								( 											),	// 1-bit output almost full
		.DO										( data_fifo_dout[55:48]						),	// Output data, width defined by DATA_WIDTH parameter
		.EMPTY									( 											),	// 1-bit output empty
		.FULL									( 											),	// 1-bit output full
		.RDCOUNT								( 											),	// Output read count, width determined by FIfor depth
		.RDERR									( 											),	// 1-bit output read error
		.WRCOUNT								( 											),	// Output write count, width determined by FIfor depth
		.WRERR									( 											),	// 1-bit output write error
		.DI										( data_fifo_din[55:48]						),	// Input data, width defined by DATA_WIDTH parameter
		.RDCLK									( clk										),	// 1-bit input read clock
		.RDEN									( data_fifo_ren								),	// 1-bit input read enable
		.RST									( rst										),	// 1-bit input reset
		.WRCLK									( log_clk									),	// 1-bit input write clock
		.WREN									( data_fifo_wen								)	// 1-bit input write enable
	);
	
	FIFO_DUALCLOCK_MACRO #(
		.ALMOST_EMPTY_OFFSET					( 9'h080									),	// Sets the almost empty threshold
		.ALMOST_FULL_OFFSET						( 9'h004									),	// Sets almost full threshold
		.DATA_WIDTH								( 8											),	// Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
		.DEVICE									( "7SERIES"									),	// Target device: "VIRTEX5", "VIRTEX6", "7SERIES"
		.FIFO_SIZE								( "36Kb"									),	// Target BRAM: "18Kb" or "36Kb"
		.FIRST_WORD_FALL_THROUGH 				( "TRUE"									)	// Sets the FIfor FWFT to "TRUE" or "FALSE"
		)
	i7_data_fifo (
		.ALMOSTEMPTY							( 											),	// 1-bit output almost empty
		.ALMOSTFULL								( 											),	// 1-bit output almost full
		.DO										( data_fifo_dout[63:56]						),	// Output data, width defined by DATA_WIDTH parameter
		.EMPTY									( 											),	// 1-bit output empty
		.FULL									( 											),	// 1-bit output full
		.RDCOUNT								( 											),	// Output read count, width determined by FIfor depth
		.RDERR									( 											),	// 1-bit output read error
		.WRCOUNT								( 											),	// Output write count, width determined by FIfor depth
		.WRERR									( 											),	// 1-bit output write error
		.DI										( data_fifo_din[63:56]						),	// Input data, width defined by DATA_WIDTH parameter
		.RDCLK									( clk										),	// 1-bit input read clock
		.RDEN									( data_fifo_ren								),	// 1-bit input read enable
		.RST									( rst										),	// 1-bit input reset
		.WRCLK									( log_clk									),	// 1-bit input write clock
		.WREN									( data_fifo_wen								)	// 1-bit input write enable
	);
		
end else begin	
	FIFO_DUALCLOCK_MACRO #(
		.ALMOST_EMPTY_OFFSET					( 9'h080									),	// Sets the almost empty threshold
		.ALMOST_FULL_OFFSET						( 9'h004									),	// Sets almost full threshold
		.DATA_WIDTH								( 64										),	// Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
		.DEVICE									( "7SERIES"									),	// Target device: "VIRTEX5", "VIRTEX6", "7SERIES"
		.FIFO_SIZE								( "36Kb"									),	// Target BRAM: "18Kb" or "36Kb"
		.FIRST_WORD_FALL_THROUGH 				( "TRUE"									)	// Sets the FIfor FWFT to "TRUE" or "FALSE"
		)
	i_data_fifo (
		.ALMOSTEMPTY							( 											),	// 1-bit output almost empty
		.ALMOSTFULL								( 											),	// 1-bit output almost full
		.DO										( data_fifo_dout							),	// Output data, width defined by DATA_WIDTH parameter
		.EMPTY									( data_fifo_empty							),	// 1-bit output empty
		.FULL									( data_fifo_full 							),	// 1-bit output full
		.RDCOUNT								( 											),	// Output read count, width determined by FIfor depth
		.RDERR									( 											),	// 1-bit output read error
		.WRCOUNT								( 											),	// Output write count, width determined by FIfor depth
		.WRERR									( 											),	// 1-bit output write error
		.DI										( data_fifo_din								),	// Input data, width defined by DATA_WIDTH parameter
		.RDCLK									( clk										),	// 1-bit input read clock
		.RDEN									( data_fifo_ren								),	// 1-bit input read enable
		.RST									( rst										),	// 1-bit input reset
		.WRCLK									( log_clk									),	// 1-bit input write clock
		.WREN									( data_fifo_wen								)	// 1-bit input write enable
	);
end
endgenerate 
	
	FIFO_DUALCLOCK_MACRO #(
		.ALMOST_EMPTY_OFFSET					( 9'h080									),	// Sets the almost empty threshold
		.ALMOST_FULL_OFFSET						( 9'h004									),	// Sets almost full threshold
		.DATA_WIDTH								( 64										),	// Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
		.DEVICE									( "7SERIES"									),	// Target device: "VIRTEX5", "VIRTEX6", "7SERIES"
		.FIFO_SIZE								( "36Kb"									),	// Target BRAM: "18Kb" or "36Kb"
		.FIRST_WORD_FALL_THROUGH 				( "TRUE"									)	// Sets the FIfor FWFT to "TRUE" or "FALSE"
		)
	i_trn_fifo (
		.ALMOSTEMPTY							( 											),	// 1-bit output almost empty
		.ALMOSTFULL								( 											),	// 1-bit output almost full
		.DO										( trn_fifo_dout								),	// Output data, width defined by DATA_WIDTH parameter
		.EMPTY									( trn_fifo_empty							),	// 1-bit output empty
		.FULL									( trn_fifo_full								),	// 1-bit output full
		.RDCOUNT								( 											),	// Output read count, width determined by FIfor depth
		.RDERR									( 											),	// 1-bit output read error
		.WRCOUNT								( 											),	// Output write count, width determined by FIfor depth
		.WRERR									( 											),	// 1-bit output write error
		.DI										( trn_fifo_din								),	// Input data, width defined by DATA_WIDTH parameter
		.RDCLK									( clk										),	// 1-bit input read clock
		.RDEN									( trn_fifo_ren								),	// 1-bit input read enable
		.RST									( rst										),	// 1-bit input reset
		.WRCLK									( log_clk									),	// 1-bit input write clock
		.WREN									( trn_fifo_wen								)	// 1-bit input write enable
	);
	
endmodule