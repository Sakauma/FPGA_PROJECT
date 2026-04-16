`timescale 1ns / 1ps
// ============================================================================
// 新增维护说明
// 文件职责      : 当前文件为手工维护源码，承担本模块/脚本的真实实现。
// 维护边界      : 本注释块仅补充维护说明，不改写任何原有说明、历史注释或现有逻辑。
// 修改约束      : 后续如需继续补充说明，只允许追加中文注释，不得替换旧注释或改动旧代码。
// 生成关系      : 若存在对应生成物，应以当前手工源码为准，禁止反向覆盖本文件。
// ============================================================================
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 2016/09/27 13:34:27
// Design Name:
// Module Name: axi_lite_regs
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////
module axi_lite_no_used#(
	parameter		P_num						= 1		
)(	input  										reg_cfg_aclk		 						,
	input  										reg_cfg_aresetn                             ,
	input  			[P_num*32-1:0] 				reg_cfg_awaddr		                        ,
	input  			[P_num* 1-1:0]				reg_cfg_awvalid                             ,
	output			[P_num* 1-1:0]				reg_cfg_awready                             ,
	input  			[P_num*32-1:0] 				reg_cfg_wdata                               ,
	input  			[P_num* 4-1:0] 				reg_cfg_wstrb                               ,
	input  			[P_num* 1-1:0]				reg_cfg_wvalid		                        ,
	output			[P_num* 1-1:0]				reg_cfg_wready                              ,
	output			[P_num* 2-1:0] 				reg_cfg_bresp                               ,
	output 			[P_num* 1-1:0]				reg_cfg_bvalid		                        ,
	input  			[P_num* 1-1:0]				reg_cfg_bready                              ,
	input  			[P_num*32-1:0] 				reg_cfg_araddr		                        ,
	input  			[P_num* 1-1:0]				reg_cfg_arvalid                             ,
	output 			[P_num* 1-1:0]				reg_cfg_arready                             ,
	output 			[P_num*32-1:0]				reg_cfg_rdata                               ,
	output 			[P_num* 2-1:0] 				reg_cfg_rresp                               ,
	output 			[P_num* 1-1:0]				reg_cfg_rvalid                              ,
	input  			[P_num* 1-1:0]				reg_cfg_rready
    );                       
	reg				[P_num* 1-1:0]				axi_noused_rvalid							; 
	reg				[P_num* 1-1:0]				axi_noused_bvalid							; 
	reg				[P_num*32-1:0]				axi_noused_data								; 
    
    genvar			i			;    
generate		for(i=0;i<P_num;i=i+1)	begin
	always @( posedge reg_cfg_aclk )begin
		axi_noused_data		[i*32 +:32]<= 		!reg_cfg_aresetn				?	32'hffffffff					:
												reg_cfg_wvalid	[i* 1 +: 1]		?	reg_cfg_wdata		[i*32 +:32] :
																					axi_noused_data		[i*32 +:32]	;

	   	axi_noused_bvalid	[i* 1 +: 1]<= 		!reg_cfg_aresetn				?	1'b0 							:
	   											reg_cfg_wvalid	[i* 1 +: 1]		?	1'b1 							:
	   											reg_cfg_bready	[i* 1 +: 1]		?	1'b0							:
	   																				axi_noused_bvalid	[i* 1 +: 1]	;

	   	axi_noused_rvalid	[i* 1 +: 1]<= 		!reg_cfg_aresetn				?	1'b0 							:
	   											reg_cfg_arvalid	[i* 1 +: 1]		?	1'b1 							:
	   											reg_cfg_rready	[i* 1 +: 1]		?	1'b0							:
	   																				axi_noused_rvalid	[i* 1 +: 1]	;
	 end
	assign	reg_cfg_awready	[i* 1 +: 1]			= 1'b1										;
	assign	reg_cfg_wready	[i* 1 +: 1]			= 1'b1										;
	assign	reg_cfg_bresp	[i* 2 +: 2]			= 2'b0										;
	assign	reg_cfg_bvalid	[i* 1 +: 1]			= axi_noused_bvalid	[i* 1 +: 1]				;
	assign	reg_cfg_arready	[i* 1 +: 1]			= 1'b1										;

	assign	reg_cfg_rdata	[i*32 +:32]			= axi_noused_data	[i*32 +:32]				;
	assign	reg_cfg_rresp	[i* 2 +: 2]			= 2'b0										;
	assign	reg_cfg_rvalid	[i* 1 +: 1]			= axi_noused_rvalid	[i* 1 +: 1]				;
end endgenerate	

endmodule