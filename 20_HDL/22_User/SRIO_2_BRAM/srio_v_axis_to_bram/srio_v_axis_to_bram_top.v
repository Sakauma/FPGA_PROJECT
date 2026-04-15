// ============================================================================
// 维护注释
//   文件职责      : SRIO 视频入口写 BRAM 的缓存组织逻辑。
//   源码属性      : 手工维护源码，不要把修改同步到生成 IP 或网表。
//   更新要求      : 当时钟、复位、接口或数据顺序假设变化时，同步更新注释。
//   维护边界      : 注释用于说明当前实现意图，不替代接口协议文档。
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
//		模块实现IRAX DSW的解析，提取LVDS iPort的数据帧，将非LVDS iPort数据帧输出
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created


/*
// 双拍同步器：log_clk → gt_pcs_clk_out
reg [1:0] sync_pipe;
always @(posedge gt_pcs_clk_out or negedge rst_n) begin
    if(!rst_n)
        sync_pipe <= 2'b00;
    else
        sync_pipe <= {sync_pipe[0], signal_from_log_clk};
end

// 输出就是安全的跨域信号
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
