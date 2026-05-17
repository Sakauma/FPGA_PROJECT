`timescale 1ns/1ns
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