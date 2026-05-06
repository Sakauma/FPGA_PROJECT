`timescale 1ns/1ns
// ============================================================================
// 新增维护说明
// 作者          : Egor Izmaylov
// 文件职责      : 当前文件为手工维护源码，具体职责见模块名、端口和上层实例化。
// 维护边界      : 只追加说明性注释；Vivado/IP 生成物和第三方支撑代码不在此处手改。
// 修改约束      : 功能改动需同步更新仿真、综合结果和相关文档。
// ============================================================================
////////////////////////////////////////////////////////////////////////////////////////////////////
// Company			: ZHTY				
// Engineer			: wangzhen			
// Create Date		: 2025/11/13 15:03:28   										
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
/*
* 历史说明：原块注释编码已损坏，按当前文件头和开发文档维护。
*/
module readbram_to_axis64_top  #(
    parameter		P_D_WIDTH     				= 65        								,

    parameter		B_RAM_WIDTH     			= 16        								,
    parameter		B_RAM_DEPTH  				= 32'h64000	  								,	// 历史说明：原尾注编码已损坏，代码含义以信号名和开发文档为准。
    parameter		P_LINE_DEPTH     			= 200											// 历史说明：原尾注编码已损坏，代码含义以信号名和开发文档为准。
) (
	input										bram_clk										,
	input										bram_rstn										,
//==================================================================================================
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
    input		  	[clogb2(B_RAM_DEPTH-1)-1:0] bram_line_cur_w   							,	// 历史说明：原尾注编码已损坏，代码含义以信号名和开发文档为准。
    input      					 				bram_line_cur_w_en   						, 	// 历史说明：原尾注编码已损坏，代码含义以信号名和开发文档为准。
    
	output	wire	[clogb2(P_LINE_DEPTH-1):0]	bram_line_num_addr							,	// 历史说明：原尾注编码已损坏，代码含义以信号名和开发文档为准。
    input      		[12-1:0] 					bram_line_num								,	// 历史说明：原尾注编码已损坏，代码含义以信号名和开发文档为准。
   
        output		  	[clogb2(B_RAM_DEPTH-1)-1:0] bram_addrb   								,	// 历史说明：原尾注编码已损坏，代码含义以信号名和开发文档为准。
    input		  	[B_RAM_WIDTH-1:0]           bram_doutb   								,     
//==================================================================================================
	/*******************axi_stream************/
	input										m_axis_aclk									,
	input										m_axis_aresetn								,
	
	input										m_axis_tready								,
	output			[P_D_WIDTH-1:0] 			m_axis_tdata								,
	output										m_axis_tvalid								
);
    //  The following function calculates the address width based on specified RAM depth
    function integer clogb2;
        input integer depth;
        for (clogb2=0; depth>0; clogb2=clogb2+1)
            depth = depth >> 1;
    endfunction
    wire 										fifo_wr_en									;   // 历史说明：原尾注编码已损坏，代码含义以信号名和开发文档为准。
    wire 			[P_D_WIDTH-1:0] 			fifo_din									; 	// 历史说明：原尾注编码已损坏，代码含义以信号名和开发文档为准。
    wire 										fifo_almost_full       						;   // 历史说明：原尾注编码已损坏，代码含义以信号名和开发文档为准。

	wire 										fifo_ren									;
	wire			[P_D_WIDTH-1:0] 			fifo_rdata									;
	wire 										fifo_empty									;
	
	readbram_to_fifo #(
	
	    .DATA_WIDTH        						( P_D_WIDTH    								),

	    .B_RAM_WIDTH        					( B_RAM_WIDTH    							),
	    .B_RAM_DEPTH        					( B_RAM_DEPTH      							),
	    .P_LINE_DEPTH        					( P_LINE_DEPTH      						)
	)readbram_to_fifo(
	    .clk   	       							( bram_clk   								),
		.rst_n   	    						( bram_rstn   	    						),

	    .bram_line_cur_w   	       				( bram_line_cur_w   						),
		.bram_line_cur_w_en   	    			( bram_line_cur_w_en   	    				),
		.bram_line_num_addr   	    			( bram_line_num_addr   	    				),
	    .bram_line_num		       				( bram_line_num		    					),
	    .bram_addrb   		       				( bram_addrb   		    					),
	    .bram_doutb   		       				( bram_doutb   		    					), 
		
		.fifo_wr_en 							( fifo_wr_en								),
		.fifo_din								( fifo_din	    							),
		.fifo_almost_full  						( fifo_almost_full     						));

    async_fifo#(
        .AF                 					( 1                 						),
        .DATA_BITS          					( P_D_WIDTH                 				),    // 历史说明：原尾注编码已损坏，代码含义以信号名和开发文档为准。
        .DEPTH_BITS         					( 4                 						),
        .SHOW_AHEAD         					( 1                 						),
        .RAM_STYLE          					( "distributed"    						)
    )async_fifo(
        // write
        .wr_clk             					( bram_clk           						),
        .wr_rstn            					( bram_rstn           						),
        .wr_en              					( fifo_wr_en        						),
        .din                					( fifo_din      							),
        .wr_data_count      					(      										),
        .prog_full          					( fifo_almost_full         					),
        .full               					(                 					        ),

        // read
        .valid          					   	(          									),
        .rd_clk             					( m_axis_aclk            					),
        .rd_rstn            					( m_axis_aresetn          					),
        .rd_en              					( fifo_ren        							),
        .dout               					( fifo_rdata     							),
        .rd_data_count      					(      										),
        .pre_empty          					(          									),
        .empty              					( fifo_empty      							));

    fifo_to_axis#(
        .P_D_WIDTH          					( P_D_WIDTH                 				) 
    )fifo_to_axis(
        // write
        .fifo_ren		         				( fifo_ren	         						),
        .fifo_rdata		         				( fifo_rdata								),
        .fifo_empty	             				( fifo_empty								),

        .m_axis_aclk		     				( m_axis_aclk               				),
        .m_axis_aresetn	                        ( m_axis_aresetn          					),      
                        
        .m_axis_tready	     					( m_axis_tready								),
        .m_axis_tdata	         				( m_axis_tdata	     						),
        .m_axis_tvalid	         				( m_axis_tvalid	      						));


//		ila_test	ila_fifo_axis(
//		.clk                        			( m_axis_aclk								),
//		.probe0                                  ( {
//		   	fifo_ren									,
//					fifo_rdata								,
//	fifo_empty				,

//m_axis_tvalid				,


		
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
//    m_axis_tdata   					


//																							})
//	);
endmodule
