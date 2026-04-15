`timescale 1ns/1ns
// ============================================================================
// 维护注释
//   文件职责      : SRIO 视频入口写 BRAM 的缓存组织逻辑。
//   源码属性      : 手工维护源码，不要把修改同步到生成 IP 或网表。
//   更新要求      : 当时钟、复位、接口或数据顺序假设变化时，同步更新注释。
//   维护边界      : 注释用于说明当前实现意图，不替代接口协议文档。
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
//		模块将LVDS数据从DDR中读出，并生成IT UP Stream时序，送往HDLC
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
//////////////////////////////////////////////////////////////////////////////////
module srio_fix #(
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
	--srio
	--------------------------------------------------------------------------------------*/
	
	output			[63:0]						srio_m_fix_axis_tdata_o						,
	output			[ 3:0]						srio_m_fix_axis_tid_o						,
	
	input										srio_m_fix_axis_tready_i					,
	
	output										srio_m_fix_axis_tvalid_o					,
	output			[ 7:0]						srio_m_fix_axis_tstrb_o						,
	output			[ 7:0]						srio_m_fix_axis_tkeep_o						,
	
	output										srio_m_fix_axis_tlast_o						,
	output			[63:0]						srio_m_fix_axis_tuser_o						,
	output			[ 3:0]						srio_m_fix_axis_tdest_o						,

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
					if(srio_m_fix_axis_tvalid_o && srio_m_fix_axis_tready_i && srio_m_fix_axis_tlast_o) begin
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
//--srio_m_fix_axis_*

	assign	srio_m_fix_axis_tvalid_o				= S_FIX_M[B_FIX_DATA_M]
												&&~fix_data_fifo_empty_i					;
	
	assign	fix_data_fifo_ren_o					= srio_m_fix_axis_tvalid_o 
												&&srio_m_fix_axis_tready_i					;												
	
	assign	srio_m_fix_axis_tdata_o				= fix_data_fifo_dout_i[63:0]				;
	assign	srio_m_fix_axis_tlast_o				= fix_data_fifo_dout_i[64]					;												
	
	assign	srio_m_fix_axis_tid_o				= 4'b0										;
	assign	srio_m_fix_axis_tstrb_o				= 8'hFF										;
	assign	srio_m_fix_axis_tkeep_o				= 8'hFF										;
	assign	srio_m_fix_axis_tuser_o				= 64'b0										;
	assign	srio_m_fix_axis_tdest_o				= 4'b0										;
	
	
	reg				[31:0]						fix_pkg_cnt									;
	
	always @(posedge sys_clk_i or posedge sys_rst_i) begin
		if(sys_rst_i) begin
			fix_pkg_cnt							<= 32'b0									;
		end else if(srio_m_fix_axis_tready_i && srio_m_fix_axis_tvalid_o && srio_m_fix_axis_tlast_o) begin
			fix_pkg_cnt							<= fix_pkg_cnt + 1'b1						;
		end else begin
			fix_pkg_cnt							<= fix_pkg_cnt								;
		end
	end
			
			
	
endmodule
