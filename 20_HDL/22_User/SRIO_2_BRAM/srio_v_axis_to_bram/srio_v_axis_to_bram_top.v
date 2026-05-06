// ============================================================================
// 新增维护说明
// 作者          : Egor Izmaylov
// 文件职责      : 当前文件为手工维护源码，具体职责见模块名、端口和上层实例化。
// 维护边界      : 只追加说明性注释；Vivado/IP 生成物和第三方支撑代码不在此处手改。
// 修改约束      : 功能改动需同步更新仿真、综合结果和相关文档。
// ============================================================================

`timescale 1ns/1ns
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


/*
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
reg [1:0] sync_pipe;
always @(posedge gt_pcs_clk_out or negedge rst_n) begin
    if(!rst_n)
        sync_pipe <= 2'b00;
    else
        sync_pipe <= {sync_pipe[0], signal_from_log_clk};
end

// 历史说明：原注释编码已损坏，已替换为中文维护说明。
wire signal_in_gt_pcs_domain = sync_pipe[1];

*/
//////////////////////////////////////////////////////////////////////////////////
module srio_v_axis_to_bram_top #(
    parameter		A_RAM_WIDTH     			= 128        								,
    parameter		A_RAM_DEPTH     			= 8192      								,
    parameter		B_RAM_WIDTH     			= 8        								    , 
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
	--iT UP Stream interface
	--------------------------------------------------------------------------------------*/
	input			[63:0]						s_axis_tdata_i								,
	output	wire								s_axis_tready_o								,
	input										s_axis_tvalid_i								,
	input										s_axis_tlast_i								,
	input			[63:0]						s_axis_tuser_i								,

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
	
	/*--------------------------------------------------------------------------------------
	--fix buf data Out
	--------------------------------------------------------------------------------------*/
	wire			[64:0]						fix_data_fifo_dout							;
	wire										fix_data_fifo_ren							;
	wire										fix_data_fifo_empty							;
	/*--------------------------------------------------------------------------------------
	--SRIO buf data Out
	--------------------------------------------------------------------------------------*/
	wire			[63:0]						srio_data_fifo_dout							;
	wire										srio_data_fifo_ren							;
	wire										srio_data_fifo_empty						;
                                                                                        	
	wire			[31:0]						srio_trn_fifo_dout							;
	wire										srio_trn_fifo_ren							;
	wire										srio_trn_fifo_empty							;
	
	srio_v_axis_to_fifo 
	i_srio_v_axis_to_fifo (
		.sys_clk_i			    				( sys_clk_i			    					),
		.sys_rst_i			    				( sys_rst_i			    					),

		.s_axis_tdata_i		    				( s_axis_tdata_i							),
		.s_axis_tready_o						( s_axis_tready_o	    					),
		.s_axis_tvalid_i						( s_axis_tvalid_i	    					),
		.s_axis_tlast_i		    				( s_axis_tlast_i							),
		.s_axis_tuser_i		    				( s_axis_tuser_i							),
		
		.fix_data_clk_i							( sys_clk_i									),

		.fix_data_fifo_dout_o					( fix_data_fifo_dout						),
		.fix_data_fifo_ren_i					( fix_data_fifo_ren							),
		.fix_data_fifo_empty_o					( fix_data_fifo_empty						),
		
		.srio_fifo_clk_i						( sys_clk_i									),

		.srio_data_fifo_dout_o					( srio_data_fifo_dout						),
		.srio_data_fifo_ren_i					( srio_data_fifo_ren						),	
		.srio_data_fifo_empty_o					( srio_data_fifo_empty						),
                                                                                              
		.srio_trn_fifo_dout_o					( srio_trn_fifo_dout						),
		.srio_trn_fifo_ren_i					( srio_trn_fifo_ren							),
		.srio_trn_fifo_empty_o					( srio_trn_fifo_empty						));	
	
	
//			ila_test	ila_wfifo(
//		.clk                        			( bram_clkb								),
//		.probe0                                  ( {
		
//		bram_addrb,
//		bram_doutb,
//	     bram_wea  ,   		    
// bram_addra   		,    
// bram_dina    		 ,   
                       
      			
// bram_line_cur_w   	,
// bram_line_cur_w_en   	

//																							})
//	);
	
	wire			[63:0]						srio_m_fix_axis_tdata_o						;
	wire			[ 3:0]						srio_m_fix_axis_tid_o						;
	
	wire										srio_m_fix_axis_tready_i					;
	
	wire										srio_m_fix_axis_tvalid_o					;
	wire			[ 7:0]						srio_m_fix_axis_tstrb_o						;
	wire			[ 7:0]						srio_m_fix_axis_tkeep_o						;
	
	wire										srio_m_fix_axis_tlast_o						;
	wire			[63:0]						srio_m_fix_axis_tuser_o						;
	wire			[ 3:0]						srio_m_fix_axis_tdest_o						;
	
	assign			srio_m_fix_axis_tready_i	= 1'b1										;
//==================================================================================================
//--srio_fix Instantation
	srio_fix	i_srio_fix (
		.sys_rst_i								( sys_rst_i									),
		.sys_clk_i								( sys_clk_i									),
		
		.srio_m_fix_axis_tdata_o				( srio_m_fix_axis_tdata_o					),
		.srio_m_fix_axis_tid_o					( srio_m_fix_axis_tid_o						),
		.srio_m_fix_axis_tready_i				( srio_m_fix_axis_tready_i					),
		.srio_m_fix_axis_tvalid_o				( srio_m_fix_axis_tvalid_o					),
		.srio_m_fix_axis_tstrb_o				( srio_m_fix_axis_tstrb_o					),
		.srio_m_fix_axis_tkeep_o				( srio_m_fix_axis_tkeep_o					),
		.srio_m_fix_axis_tlast_o				( srio_m_fix_axis_tlast_o					),
		.srio_m_fix_axis_tuser_o				( srio_m_fix_axis_tuser_o					),
		.srio_m_fix_axis_tdest_o				( srio_m_fix_axis_tdest_o					),
		
		.fix_data_fifo_dout_i					( fix_data_fifo_dout						),
		.fix_data_fifo_ren_o					( fix_data_fifo_ren							),
		.fix_data_fifo_empty_i					( fix_data_fifo_empty						));

//==================================================================================================
//--srio_cache_top Instantation
	srio_v_fifo_to_bram_top	#(
		.A_RAM_WIDTH 							( A_RAM_WIDTH 								),
		.A_RAM_DEPTH 							( A_RAM_DEPTH 								),
		.B_RAM_WIDTH 							( B_RAM_WIDTH 								)
	)i_srio_v_fifo_to_bram_top (
		.sys_rst_i								( sys_rst_i								),
		.sys_clk_i								( sys_clk_i									),
		
		.bram_clkb								( bram_clkb									),
		.bram_clkb_rstn							( bram_clkb_rstn									),
		
		.srio_data_fifo_dout_i					( srio_data_fifo_dout						),
		.srio_data_fifo_ren_o					( srio_data_fifo_ren						),
		.srio_data_fifo_empty_i					( srio_data_fifo_empty						),
         
		.srio_trn_fifo_dout_i					( srio_trn_fifo_dout						),
		.srio_trn_fifo_ren_o					( srio_trn_fifo_ren							),
		.srio_trn_fifo_empty_i					( srio_trn_fifo_empty						),

		.bram_wea     		    				( bram_wea     		    					),
		.bram_addra   		    				( bram_addra   		    					),
		.bram_dina    		    				( bram_dina    		    					),

		.bram_line_cur_w   	    				( bram_line_cur_w   	    				),
		.bram_line_cur_w_en   	    			( bram_line_cur_w_en   	    				),
		.bram_line_num_addr   	    			( bram_line_num_addr   	    				),
		.bram_line_num   	    				( bram_line_num   	    					)
	);	

endmodule
