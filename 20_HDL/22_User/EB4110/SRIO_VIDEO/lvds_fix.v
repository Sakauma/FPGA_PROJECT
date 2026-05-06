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
module lvds_fix #(
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
	--iT UP split LVDS Data stream out for HDLC
	--------------------------------------------------------------------------------------*/
	
	output			[63:0]						it_up_fix_axis_tdata_o						,
	output			[ 3:0]						it_up_fix_axis_tid_o						,
	
	input										it_up_fix_axis_tready_i						,
	
	output										it_up_fix_axis_tvalid_o						,
	output			[ 7:0]						it_up_fix_axis_tstrb_o						,
	output			[ 7:0]						it_up_fix_axis_tkeep_o						,
	
	output										it_up_fix_axis_tlast_o						,
	output			[63:0]						it_up_fix_axis_tuser_o						,
	output			[ 3:0]						it_up_fix_axis_tdest_o						,

	/*--------------------------------------------------------------------------------------
	--lvds buf data Out
	--------------------------------------------------------------------------------------*/
	input			[64:0]						fix_data_fifo_dout_i						,
	output										fix_data_fifo_ren_o							,
	input										fix_data_fifo_empty_i						
	);
//==================================================================================================
//--Param defines
	localparam		S_FIX_IDLE_M				= 3'b001									;
	localparam		S_FIX_DATA_M				= 3'b010									;
	localparam		S_FIX_DONE_M				= 3'b100									;
	
	localparam		B_FIX_IDLE_M				= 2'd0										;
	localparam		B_FIX_DATA_M				= 2'd1										;
	localparam		B_FIX_DONE_M				= 2'd2										;
	
//==================================================================================================
//--signals	
	reg				[ 2:0]						S_FIX_M										;

//==================================================================================================
//--implement state
	always @(posedge sys_clk_i or posedge sys_rst_i) begin
		if(sys_rst_i) begin
			S_FIX_M								<= S_FIX_IDLE_M								;
		end else begin
			case(S_FIX_M)
				S_FIX_IDLE_M					: begin
					if(!fix_data_fifo_empty_i) begin
						S_FIX_M					<= S_FIX_DATA_M								;
					end else begin
						S_FIX_M					<= S_FIX_IDLE_M								;
					end
				end
				S_FIX_DATA_M					: begin
					if(it_up_fix_axis_tvalid_o && it_up_fix_axis_tready_i && it_up_fix_axis_tlast_o) begin
						S_FIX_M					<= S_FIX_DONE_M								;
					end else begin
						S_FIX_M					<= S_FIX_DATA_M								;
					end
				end
				S_FIX_DONE_M					: begin
					S_FIX_M						<= S_FIX_IDLE_M								;
				end
				default							: begin
					S_FIX_M						<= S_FIX_IDLE_M								;
				end
			endcase
		end
	end				
						
//==================================================================================================
//--it_up_fix_axis_*

	assign	it_up_fix_axis_tvalid_o				= S_FIX_M[B_FIX_DATA_M]
												&&~fix_data_fifo_empty_i					;
	
	assign	fix_data_fifo_ren_o					= it_up_fix_axis_tvalid_o 
												&&it_up_fix_axis_tready_i					;												
	
	assign	it_up_fix_axis_tdata_o				= fix_data_fifo_dout_i[63:0]				;
	assign	it_up_fix_axis_tlast_o				= fix_data_fifo_dout_i[64]					;												
	
	assign	it_up_fix_axis_tid_o				= 4'b0										;
	assign	it_up_fix_axis_tstrb_o				= 8'hFF										;
	assign	it_up_fix_axis_tkeep_o				= 8'hFF										;
	assign	it_up_fix_axis_tuser_o				= 64'b0										;
	assign	it_up_fix_axis_tdest_o				= 4'b0										;
	
	
	reg				[31:0]						fix_pkg_cnt									;
	
	always @(posedge sys_clk_i or posedge sys_rst_i) begin
		if(sys_rst_i) begin
			fix_pkg_cnt							<= 32'b0									;
		end else if(it_up_fix_axis_tready_i && it_up_fix_axis_tvalid_o && it_up_fix_axis_tlast_o) begin
			fix_pkg_cnt							<= fix_pkg_cnt + 1'b1						;
		end else begin
			fix_pkg_cnt							<= fix_pkg_cnt								;
		end
	end
			
			
	
endmodule
