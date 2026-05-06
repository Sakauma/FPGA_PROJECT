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
// Module Name:		srio_top
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
module srio_v_fifo_to_bram_top #(
    parameter		A_RAM_WIDTH     			= 128        								,
    parameter		A_RAM_DEPTH     			= 8192      								,
    parameter		B_RAM_WIDTH     			= 8    										,
    parameter		B_RAM_DEPTH     			= A_RAM_WIDTH*A_RAM_DEPTH/B_RAM_WIDTH      	, 
    parameter		P_LINE_DEPTH     			= A_RAM_DEPTH/512				      		
	)(
//==================================================================================================
//--PAD Declarations---------------------------
	/*--------------------------------------------------------------------------------------
	--Common interface
	--------------------------------------------------------------------------------------*/
	input										sys_rst_i									,
	input										sys_clk_i									,

	/*--------------------------------------------------------------------------------------
	--lvds buf data Out
	--------------------------------------------------------------------------------------*/
	input			[63:0]						srio_data_fifo_dout_i						,
	output										srio_data_fifo_ren_o						,
	input										srio_data_fifo_empty_i						,

	input			[31:0]						srio_trn_fifo_dout_i						,
	output										srio_trn_fifo_ren_o							,
	input										srio_trn_fifo_empty_i						,
//==================================================================================================
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
    output  wire                                bram_wea     								,   
    output  wire    [clogb2(A_RAM_DEPTH-1)-1:0] bram_addra   								,   
    output  wire    [A_RAM_WIDTH-1:0]           bram_dina    								,   
 
    input  	wire                                bram_clkb     								,  
    input  	wire                                bram_clkb_rstn     								,  
    
    output  wire    [clogb2(B_RAM_DEPTH-1)-1:0] bram_line_cur_w   							,   
    output      					 			bram_line_cur_w_en   						, 	// 历史说明：原尾注编码已损坏，代码含义以信号名和开发文档为准。
	
	input	wire	[clogb2(P_LINE_DEPTH-1):0]	bram_line_num_addr							,	// 历史说明：原尾注编码已损坏，代码含义以信号名和开发文档为准。
    output      	[12-1:0] 					bram_line_num									// 历史说明：原尾注编码已损坏，代码含义以信号名和开发文档为准。
	
	);
	    //  The following function calculates the address width based on specified RAM depth
    function integer clogb2;
        input integer depth;
        for (clogb2=0; depth>0; clogb2=clogb2+1)
            depth = depth >> 1;
    endfunction		
//==================================================================================================
//--param defines

//==================================================================================================
//--internal signals
	wire										m_axiw_req									;
	wire										m_axiw_gnt									;
	wire			[10:0]						m_axiw_len64								;
	wire			[31:0]						m_axiw_addr									;
	wire			[7:0]						m_axiw_wstrb								;	// 历史说明：原尾注编码已损坏，代码含义以信号名和开发文档为准。
	
//			ila_test	ila_wfifo(
//		.clk                        			( sys_clk_i								),
//		.probe0                                  ( {
		
//	srio_data_fifo_dout_i						,
//	srio_data_fifo_ren_o						,
//	srio_data_fifo_empty_i						,

		          
//		          srio_trn_fifo_dout_i,
//		          srio_trn_fifo_ren_o,
//		     srio_trn_fifo_empty_i,
//	m_axiw_req									,
//	m_axiw_gnt									,
//	m_axiw_len64								,
//	m_axiw_addr									,
//	m_axiw_wstrb								
//			})
//	);	
	
//==================================================================================================
//--write Instantation
	srio_v_fifo_to_bram_write	
	i_srio_v_fifo_to_bram_write (
		.sys_rst_i								( sys_rst_i									),
		.sys_clk_i								( sys_clk_i									),
		
		.srio_trn_fifo_dout_i					( srio_trn_fifo_dout_i						),
		.srio_trn_fifo_ren_o					( srio_trn_fifo_ren_o						),
		.srio_trn_fifo_empty_i					( srio_trn_fifo_empty_i						),
		
		.m_axiw_req								( m_axiw_req								),
		.m_axiw_gnt								( m_axiw_gnt								),
		.m_axiw_len64							( m_axiw_len64								),
		.m_axiw_addr							( m_axiw_addr								),
		.m_axiw_wstrb							( m_axiw_wstrb								)
	);
//==================================================================================================
//--zt_axi4_wb Instantation
	srio_v_fifo_to_bram_wb	#(
		.A_RAM_WIDTH 							( A_RAM_WIDTH 								),
		.A_RAM_DEPTH 							( A_RAM_DEPTH 								),
		.B_RAM_WIDTH 							( B_RAM_WIDTH 								)
	)i_srio_v_fifo_to_bram_wb (
		.clk									( sys_clk_i									),
		.rst									( sys_rst_i									),
		
		.m_axiw_req								( m_axiw_req								),
		.m_axiw_gnt								( m_axiw_gnt								),
		.m_axiw_len64							( m_axiw_len64								),
		.m_axiw_addr							( m_axiw_addr								),
		.m_axiw_wstrb							( m_axiw_wstrb								),
		
		.m_axiw_fifo_rdata						( srio_data_fifo_dout_i						),
		.m_axiw_fifo_empty						( srio_data_fifo_empty_i					),
		.m_axiw_fifo_rden						( srio_data_fifo_ren_o						),
		
		.bram_wea     		    				( bram_wea     		    					),
		.bram_addra   		    				( bram_addra   		    					),
		.bram_dina    		    				( bram_dina    		    					),


		.bram_line_clk									( bram_clkb									),
		.bram_line_rstn									( bram_clkb_rstn									),                                                                    		                    

		.bram_line_cur_w_o   	    				( bram_line_cur_w   	    				),
		.bram_line_cur_w_en_o   	    			( bram_line_cur_w_en   	    				),
		.bram_line_num_addr   	    			( bram_line_num_addr   	    				),
		.bram_line_num   	    				( bram_line_num   	    					)
	);

endmodule
