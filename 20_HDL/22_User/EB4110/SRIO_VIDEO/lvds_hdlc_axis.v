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
// Create Date:		2021/9/4 21:02:02
// Design Name:		IR2120
// Module Name:		lvds_hdlc_top
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
module lvds_hdlc_axis #(
	/*--------------------------------------------------------------------------------------
	--P_SIMULATION_R
	---------------------------------------------------------------------------------------*/
	parameter		P_SIMULATION_R				= "FALSE"									
	)(
//==================================================================================================
//--PAD Declarations---------------------------
	/*--------------------------------------------------------------------------------------
	--Common interface
	--------------------------------------------------------------------------------------*/
	input										sys_rst_i									,
	input										sys_clk_i									,
	
	/*--------------------------------------------------------------------------------------
	--iT UP lvds data stream out for HDLC
	--------------------------------------------------------------------------------------*/
	
	output			[63:0]						it_up_lvds_axis_tdata_o						,
	output			[ 3:0]						it_up_lvds_axis_tid_o						,
	
	input										it_up_lvds_axis_tready_i					,
	
	output										it_up_lvds_axis_tvalid_o					,
	output			[ 7:0]						it_up_lvds_axis_tstrb_o						,
	output			[ 7:0]						it_up_lvds_axis_tkeep_o						,
	
	output										it_up_lvds_axis_tlast_o						,
	output			[63:0]						it_up_lvds_axis_tuser_o						,
	output			[ 3:0]						it_up_lvds_axis_tdest_o						,
	
	input			[65:0]						axis_data_fifo_dout_i						,
	input										axis_data_fifo_empty_i						,
	
	output										axis_data_fifo_ren_o						
	
	);
//==================================================================================================
//--Param defines
	/*--------------------------------------------------------------------------------------
	--AXIS State parma
	--------------------------------------------------------------------------------------*/	
	localparam		S_AXIS_IDLE_M				= 4'b0001									;
	localparam		S_AXIS_LOAD_M				= 4'b0010									;
	localparam		S_AXIS_DATA_M				= 4'b0100									;
	localparam		S_AXIS_DONE_M				= 4'b1000									;
	
	localparam		B_AXIS_IDLE_M				= 2'd0										;
	localparam		B_AXIS_LOAD_M				= 2'd1										;
	localparam		B_AXIS_DATA_M				= 2'd2										;
	localparam		B_AXIS_DONE_M				= 2'd3										;

//==================================================================================================
//--signals defines	
	/*--------------------------------------------------------------------------------------
	--AXIS S Signals
	--------------------------------------------------------------------------------------*/	
	
	reg				[ 3:0]						S_AXIS_CM									;
	reg				[ 3:0]						S_AXIS_NM									;
	
	wire			[15:0]						DSW_LEN										;	//byte
	
	wire			[15:0]						packet_len8									;	
	
	reg				[15:0]						packet_len32								;
//==================================================================================================
//--pre assign
	assign	DSW_LEN								= axis_data_fifo_dout_i[47:32]				;
	
	assign	packet_len8							= DSW_LEN + 32								;
	
	always @(posedge sys_clk_i or posedge sys_rst_i) begin
		if(sys_rst_i) begin
			packet_len32						<= 16'b0									;
		end else if(S_AXIS_NM[B_AXIS_LOAD_M]) begin
			packet_len32						<= packet_len8[1:0]!=2'b00
												?  packet_len8[15:2] + 1'b1
												:  packet_len8[15:2]						;
		end else begin
			packet_len32						<= packet_len32								;
		end
	end
	
//==================================================================================================
//--AXI Stream timing
	always @(posedge sys_clk_i or posedge sys_rst_i) begin
		if(sys_rst_i) begin
			S_AXIS_CM							<= S_AXIS_IDLE_M							;
		end else begin
			S_AXIS_CM							<= S_AXIS_NM								;
		end
	end
	
	always @(*) begin
		S_AXIS_NM								= S_AXIS_IDLE_M								;
		case(S_AXIS_CM)
			S_AXIS_IDLE_M						: begin
				if(!axis_data_fifo_empty_i) begin
					S_AXIS_NM					= S_AXIS_LOAD_M								;
				end else begin
					S_AXIS_NM					= S_AXIS_IDLE_M								;
				end
			end
			S_AXIS_LOAD_M						: begin
				S_AXIS_NM						= S_AXIS_DATA_M								;
			end
			S_AXIS_DATA_M						: begin
				if(it_up_lvds_axis_tvalid_o && it_up_lvds_axis_tready_i && it_up_lvds_axis_tlast_o) begin
					S_AXIS_NM					= S_AXIS_DONE_M								;
				end else begin
					S_AXIS_NM					= S_AXIS_DATA_M								;
				end
			end
			S_AXIS_DONE_M						: begin
				S_AXIS_NM						= S_AXIS_IDLE_M								;			
			end
			default						: begin
				S_AXIS_NM						= S_AXIS_NM									;				
			end
		endcase
	end
	
	assign	it_up_lvds_axis_tvalid_o			= S_AXIS_CM[B_AXIS_DATA_M] && ~axis_data_fifo_empty_i;
	
	assign	it_up_lvds_axis_tdata_o				= axis_data_fifo_dout_i[63:0]				;
												
	assign	it_up_lvds_axis_tlast_o				= axis_data_fifo_dout_i[65]					;
	assign	it_up_lvds_axis_tstrb_o				= 8'hff										;
	assign	it_up_lvds_axis_tkeep_o				= 8'hff										;
	assign	it_up_lvds_axis_tdest_o				= 4'b0										;
	assign	it_up_lvds_axis_tid_o				= 4'b0										;
	//assign	it_up_lvds_axis_tuser_o				= {48'b0,packet_len32}						;
		assign	it_up_lvds_axis_tuser_o				= 64'h00020001					;

	assign	axis_data_fifo_ren_o				=  S_AXIS_CM[B_AXIS_DATA_M]
												&& it_up_lvds_axis_tready_i
												&& ~axis_data_fifo_empty_i					;
	
//==================================================================================================
//--test for packet cnt
	
	reg				[31:0]						lvds_pkg_cnt								;
	
	always @(posedge sys_clk_i or posedge sys_rst_i) begin
		if(sys_rst_i) begin
			lvds_pkg_cnt						<= 32'b0									;
		end else if(it_up_lvds_axis_tready_i && it_up_lvds_axis_tvalid_o && it_up_lvds_axis_tlast_o) begin
			lvds_pkg_cnt						<= lvds_pkg_cnt + 1'b1						;
		end else begin
			lvds_pkg_cnt						<= lvds_pkg_cnt								;
		end
	end

endmodule
