 `timescale 1ns/1ns
//////////////////////////////////////////////////////////////////////////////////
// Company:			HXZY
// Engineer:		ZYL
// Create Date:		2018/5/11 19:40:24
// Design Name:		XR2000
// Module Name:		bm_timestamp-时间戳计数器
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
module bm_timestamp #(
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
	
	input			[63:0]						c_bm_timestamp								,
	input										c_bm_timestamp_rf							,
	
	output	reg		[63:0]						timestamp									
	);
	
//==================================================================================================
//--Implement
	reg				[63:0]						c_bm_timestamp_q1			= 0				;
	reg				[63:0]						c_bm_timestamp_q2			= 0				;
	
	reg											c_bm_timestamp_rf_q1		= 0				;
	reg											c_bm_timestamp_rf_q2		= 0				;
	
	wire										c_bm_timestamp_rf_fe						;
	
	always @(posedge clk) begin
		c_bm_timestamp_q1						<= c_bm_timestamp							;
		c_bm_timestamp_q2						<= c_bm_timestamp_q1						;
		c_bm_timestamp_rf_q1					<= c_bm_timestamp_rf						;
		c_bm_timestamp_rf_q2					<= c_bm_timestamp_rf_q1						;
	end
	
	assign	c_bm_timestamp_rf_fe				= ~c_bm_timestamp_rf_q1 && c_bm_timestamp_rf_q2;
	
	always @(posedge clk) begin
		if(rst) begin
			timestamp							<= 64'b0									;
		end else if(c_bm_timestamp_rf_fe) begin
			timestamp							<= c_bm_timestamp_q2						;
		end else begin
			timestamp							<= timestamp + 3'd4							;
		end
	end
	
endmodule