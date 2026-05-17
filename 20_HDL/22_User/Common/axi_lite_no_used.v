`timescale 1ns / 1ps
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