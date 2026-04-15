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
// Module Name:		srio_top
// Project Name:
// Target Devices:	K7-V7
// Tool Versions: 	Vivado 2016.1 HDL-EDIT UltraEdit TAB=4 Consolas
// Description:
//		模块实现两路LVDS信号的数据的提取，快进慢发的DDR3缓存和流量控制功能
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
//--bram写接口
    output  wire                                bram_wea     								,   
    output  wire    [clogb2(A_RAM_DEPTH-1)-1:0] bram_addra   								,   
    output  wire    [A_RAM_WIDTH-1:0]           bram_dina    								,   
 
    input  	wire                                bram_clkb     								,  
    input  	wire                                bram_clkb_rstn     								,  
    
    output  wire    [clogb2(B_RAM_DEPTH-1)-1:0] bram_line_cur_w   							,   
    output      					 			bram_line_cur_w_en   						, 	//	1 :表示成功写入第bram_line_cur_w行数据在bram中
	
	input	wire	[clogb2(P_LINE_DEPTH-1):0]	bram_line_num_addr							,	// 每段bram地址对应的行号地址
    output      	[12-1:0] 					bram_line_num									// 每段bram地址对应的行号 , bram_line_num_addr*32'h0~bram_line_num_addr*32'h800对应的行号,具体列号对应当前行的不同地址
	
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
	wire			[7:0]						m_axiw_wstrb								;	//仅当最后一个64比特数据有效，用于OnlyOne模式	
	
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
