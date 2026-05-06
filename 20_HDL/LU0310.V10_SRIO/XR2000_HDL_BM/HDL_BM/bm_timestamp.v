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
// Module Name:		bm_timestamp-时间戳计数器
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
module bm_timestamp #(
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
