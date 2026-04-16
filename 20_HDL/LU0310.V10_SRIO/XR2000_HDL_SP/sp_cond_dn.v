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
// Module Name:		spb_top-SrioPCIeBridge_TOP
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
module sp_cond_dn #(
	/*--------------------------------------------------------------------------------------
	--P_SIMULATION_R
	---------------------------------------------------------------------------------------*/
	parameter									P_SIMULATION_R			= "FALSE"			,
	parameter									P_BIG_CACHE_R			= "FLASE"
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
	
//==================================================================================================
//--DMA Channel Signals
	(*mark_debug="TRUE"*) 	
	input			[63:0]						dma_m_axis_tdata							,
	input			[ 3:0]						dma_m_axis_tid								,
	output										dma_m_axis_tready							,
	(*mark_debug="TRUE"*)
	input										dma_m_axis_tvalid							,
	input			[ 7:0]						dma_m_axis_tstrb							,
	input			[ 7:0]						dma_m_axis_tkeep							,
	(*mark_debug="TRUE"*)
	input										dma_m_axis_tlast							,
	input			[63:0]						dma_m_axis_tuser							,
	input			[ 3:0]						dma_m_axis_tdest							,

//==================================================================================================
//--统计寄存器
	output	reg		[31:0]						c_sp_dn_cnt									,
	output	reg		[31:0]						c_sp_tx_cnt									,

//==================================================================================================
//--SRIO Reduncy Signals
	/*--------------------------------------------------------------------------------------
	--USER SRIO Redundancy Interface
	--------------------------------------------------------------------------------------*/
	output										sr_iotx_tvalid								,
	input										sr_iotx_tready								,
	output										sr_iotx_tlast								,
	output			[63:0]						sr_iotx_tdata								,
	output			[ 7:0]						sr_iotx_tkeep								,
	output	reg		[31:0]						sr_iotx_tuser								
	
	// output										tx_send_flag				
	);
//==================================================================================================
//--参数定义
	/*--------------------------------------------------------------------------------------
	--SR状态机参数是
	--------------------------------------------------------------------------------------*/
	localparam									S_SR_IDLE_M				= 3'b001			;
	localparam									S_SR_ID_M				= 3'b010			;
	localparam									S_SR_DATA_M				= 3'b100			;
	
//==================================================================================================
//--信号定义
	/*--------------------------------------------------------------------------------------
	--数据FIFO信号定义
	--------------------------------------------------------------------------------------*/	
	wire			[63:0]						data_fifo_din								;
	wire										data_fifo_wen								;
	wire										data_fifo_full								;
	
	(*mark_debug="TRUE"*)
	wire			[63:0]						data_fifo_dout								;
	wire										data_fifo_empty								;
	(*mark_debug="TRUE"*)
	wire										data_fifo_ren								;
	
	/*--------------------------------------------------------------------------------------
	--SR方向状态机信号
	--------------------------------------------------------------------------------------*/	
	(*mark_debug="TRUE"*)
	reg				[ 2:0]						S_SR_NM										;
	(*mark_debug="TRUE"*)
	reg				[ 2:0]						S_SR_CM										;
	(*mark_debug="TRUE"*)
	reg				[ 7:0]						sr_iotx_len64								;
	
//==================================================================================================
//--DMA数据写入FIFO	
	assign	dma_m_axis_tready					= ~data_fifo_full							;
	assign	data_fifo_wen						= dma_m_axis_tvalid && dma_m_axis_tready	;
	assign	data_fifo_din[63:0]					= dma_m_axis_tdata							;

	
	always @(posedge clk or posedge rst) begin
		if(rst) begin
			c_sp_dn_cnt							<= 32'b0									;
		end else if(dma_m_axis_tready && dma_m_axis_tvalid && dma_m_axis_tlast) begin
			c_sp_dn_cnt							<= c_sp_dn_cnt + 1'b1						;
		end else begin
			c_sp_dn_cnt							<= c_sp_dn_cnt								;
		end
	end
//==================================================================================================
//--SRIO数据发送实现
	always @(posedge log_clk or posedge rst) begin
		if(rst) begin
			S_SR_CM								<= S_SR_IDLE_M								;
		end else if(srio_rst) begin
			S_SR_CM								<= S_SR_IDLE_M								;
		end else begin
			S_SR_CM								<= S_SR_NM									;
		end
	end
	
	always @(*) begin
		S_SR_NM									= S_SR_IDLE_M								;
		case(S_SR_CM)
			S_SR_IDLE_M							: begin
				if(!data_fifo_empty) begin
					S_SR_NM						= S_SR_ID_M									;
				end else begin
					S_SR_NM						= S_SR_IDLE_M								;
				end
			end
			S_SR_ID_M							: begin
				if(!data_fifo_empty) begin
					S_SR_NM						= S_SR_DATA_M								;
				end else begin
					S_SR_NM						= S_SR_ID_M									;
				end
			end
			S_SR_DATA_M							: begin
				if(sr_iotx_tvalid && sr_iotx_tready && sr_iotx_tlast) begin
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
			sr_iotx_tuser						<= 32'b0									;
		end else begin
			case(S_SR_NM)
				S_SR_ID_M						: begin
					sr_iotx_tuser				<= data_fifo_dout[63:32]					;
				end
				default							: begin
					sr_iotx_tuser				<= sr_iotx_tuser							;
				end
			endcase
		end
	end
	
	always @(posedge log_clk or posedge rst) begin
		if(rst) begin
			sr_iotx_len64						<= 8'b0										;
		end else if(S_SR_ID_M==S_SR_NM) begin
			sr_iotx_len64						<= data_fifo_dout[7:0]						;
		end else begin
			sr_iotx_len64						<= sr_iotx_len64							;
		end
	end
	
	(*mark_debug="TRUE"*)
	reg				[7:0]						data_cnt									;
	always @(posedge log_clk or posedge rst) begin
		if(rst) begin
			data_cnt							<= 8'b00									;
		end else if(S_SR_DATA_M==S_SR_CM) begin
			if(sr_iotx_tready && sr_iotx_tvalid) begin
				data_cnt						<= data_cnt + 1'b1							;
			end else begin
				data_cnt						<= data_cnt									;
			end
		end else begin
			data_cnt							<= 8'b00									;
		end
	end	

	assign	sr_iotx_tdata						= data_fifo_dout[63:0]						;	
	assign	sr_iotx_tvalid						= (S_SR_CM==S_SR_DATA_M)
												? ~data_fifo_empty
												: 1'b0										;
												
	assign	sr_iotx_tlast						= data_cnt==sr_iotx_len64-1 && sr_iotx_tvalid;
	
	assign	data_fifo_ren						= (((S_SR_DATA_M==S_SR_CM && sr_iotx_tready)|| S_SR_ID_M==S_SR_CM))
												? ~data_fifo_empty	
												: 1'b0										;
												
	assign	sr_iotx_tkeep						= 8'hFF										;
	
	always @(posedge log_clk or posedge rst) begin
		if(rst) begin
			c_sp_tx_cnt							<= 32'b0									;
		end else if(sr_iotx_tready && sr_iotx_tvalid && sr_iotx_tlast) begin
			c_sp_tx_cnt							<= c_sp_tx_cnt + 1'b1						;
		end else begin
			c_sp_tx_cnt							<= c_sp_tx_cnt								;
		end
	end
	
//==================================================================================================
//--DATA FIFO例化
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
		.RDCLK									( log_clk									),	// 1-bit input read clock
		.RDEN									( data_fifo_ren								),	// 1-bit input read enable
		.RST									( rst | srio_rst							),	// 1-bit input reset
		.WRCLK									( clk										),	// 1-bit input write clock
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
		.RDCLK									( log_clk									),	// 1-bit input read clock
		.RDEN									( data_fifo_ren								),	// 1-bit input read enable
		.RST									( rst | srio_rst							),	// 1-bit input reset
		.WRCLK									( clk										),	// 1-bit input write clock
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
		.RDCLK									( log_clk									),	// 1-bit input read clock
		.RDEN									( data_fifo_ren								),	// 1-bit input read enable
		.RST									( rst | srio_rst							),	// 1-bit input reset
		.WRCLK									( clk										),	// 1-bit input write clock
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
		.RDCLK									( log_clk									),	// 1-bit input read clock
		.RDEN									( data_fifo_ren								),	// 1-bit input read enable
		.RST									( rst | srio_rst							),	// 1-bit input reset
		.WRCLK									( clk										),	// 1-bit input write clock
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
		.RDCLK									( log_clk									),	// 1-bit input read clock
		.RDEN									( data_fifo_ren								),	// 1-bit input read enable
		.RST									( rst | srio_rst							),	// 1-bit input reset
		.WRCLK									( clk										),	// 1-bit input write clock
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
		.RDCLK									( log_clk									),	// 1-bit input read clock
		.RDEN									( data_fifo_ren								),	// 1-bit input read enable
		.RST									( rst | srio_rst							),	// 1-bit input reset
		.WRCLK									( clk										),	// 1-bit input write clock
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
		.RDCLK									( log_clk									),	// 1-bit input read clock
		.RDEN									( data_fifo_ren								),	// 1-bit input read enable
		.RST									( rst | srio_rst							),	// 1-bit input reset
		.WRCLK									( clk										),	// 1-bit input write clock
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
		.RDCLK									( log_clk									),	// 1-bit input read clock
		.RDEN									( data_fifo_ren								),	// 1-bit input read enable
		.RST									( rst | srio_rst							),	// 1-bit input reset
		.WRCLK									( clk										),	// 1-bit input write clock
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
		.RDCLK									( log_clk									),	// 1-bit input read clock
		.RDEN									( data_fifo_ren								),	// 1-bit input read enable
		.RST									( rst | srio_rst							),	// 1-bit input reset
		.WRCLK									( clk										),	// 1-bit input write clock
		.WREN									( data_fifo_wen								)	// 1-bit input write enable
	);
end
endgenerate
endmodule