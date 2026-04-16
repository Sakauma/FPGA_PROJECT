`timescale 1ns/1ns
// ============================================================================
// 新增维护说明
// 文件职责      : 当前文件为手工维护源码，承担本模块/脚本的真实实现。
// 维护边界      : 本注释块仅补充维护说明，不改写任何原有说明、历史注释或现有逻辑。
// 修改约束      : 后续如需继续补充说明，只允许追加中文注释，不得替换旧注释或改动旧代码。
// 生成关系      : 若存在对应生成物，应以当前手工源码为准，禁止反向覆盖本文件。
// ============================================================================
////////////////////////////////////////////////////////////////////////////////////////////////////
// Company			: ZHTY				
// Engineer			: wangzhen			
// Create Date		: 2026/4/3 21:30:47   										
// Design Name		:                   
// Module Name		: 		       		
// Project Name		: 		            
// Target Devices	: K7-V7		        
// Tool versions	: Vivado2020		
// Description		:                   
// 										
// Dependencies		: 					
// 										
// Top File			: 					
// 										
// Inst File		: 					
// 										
// Revision			: 					
//		Revision 1.00 - File Modified by	: 						
//		Description							: 						
//		data		: 				 	
//		1	: 				 	 		
//		2	: 				 	 		
//																	
// Additional Comments:												
////////////////////////////////////////////////////////////////////////////////////////////////////

module sync_nrst#(
	parameter   	SYNC_LEVEL      			= 3
)(
	input	wire								rst_n										,
	input	wire								clk											,
	output	wire					   			sync_rst_n	
); 
	//------------------------Local signal-------------------
    reg     [SYNC_LEVEL-1:0]   sys_rst_n_r   	= {SYNC_LEVEL{1'b1}}   						;
	//------------------------Body---------------------------
    assign  		sync_rst_n  				= sys_rst_n_r[SYNC_LEVEL-1]					;

	always @(posedge clk or negedge rst_n) begin
		if (~rst_n) 	sys_rst_n_r[0]			<= 1'b0 									; 
        else 			sys_rst_n_r[0]			<= 1'b1    									;
	end
	
    genvar i;
    generate
        for(i=1;i<SYNC_LEVEL;i=i+1) begin:block_gen
    	    always @(posedge clk or negedge rst_n) begin
		        if (~rst_n) 	sys_rst_n_r[i]	<= 1'b0 									; 
                else 			sys_rst_n_r[i]	<= sys_rst_n_r[i-1]   						;
	        end
        end
    endgenerate

endmodule

/*example
    sync_nrst i_sync_nrst(
        .rst_n                      			( i_rst_n                   				),
        .clk                        			( i_x_phy_clk_0             				),
                                    			                            				
        .sync_rst_n                 			( x_phy_clk_0_srst_n        				)
    );
    
*/