`timescale 1ns/1ns
`include "fisheye_remap_bram_to_axis.v"
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
// Create Date		: 2026/4/1 14:32:18   										
// Design Name		:                   
// Module Name		: 		       		
// Project Name		: 		            
// Target Devices	: K7-V7		        
// Tool versions	: Vivado2020		
// Description		: 
//		1、视频bram、查找表axi4到srio的axis的接口                  
//		2、1行视频占用1个bram单元，xc7z100ffg900总共755个单元    
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
/*接口描述            
//======================================================================================
//  Input / Output Interface Description
//======================================================================================
//  Signal Name         | 时钟域   			|  Description
//----------------------|-------------------|--------------------------------------------
//  bram_            	| clk     			| 视频bram缓存接口
//  V_LUT_            	| clk     			| 查找表接口，axi4
//  m_srio_             | m_srio_axis_aclk  | SRIO输出接口
//--------------------------------------------------------------------------------------
//	clk					:	250MHz；
//	m_srio_axis_aclk	:	当前为62.5MHz，调通后会更改为125MHz。
*/									
////////////////////////////////////////////////////////////////////////////////////////////////////

module vbram_lutaxi4_to_axis#(
    parameter		B_RAM_WIDTH     			= 16        								,
    parameter		B_RAM_DEPTH  				= 32'h64000	  								,	// 32'h64000：200行
    parameter		P_LINE_DEPTH     			= 200											// bram中可以存的视频行数	      		
    )(
//==================================================================================================
//--Input/Output Port--------------------------
	input										clk											,	//250M
	input										rstn										,
	// 新代码：Egor Izmaylov 接收算法控制字；当前仅驱动 HLS 演示核，不改 BRAM 写入路径。
	input			[31:0]						video_algo_ctrl								,
//==================================================================================================
//--视频bram接口--------------------------	
    input		  	[clogb2(B_RAM_DEPTH-1)-1:0] bram_line_cur_w   							,	// 当前bram写入行位置 
    input      					 				bram_line_cur_w_en   						, 	//	1 :表示成功写入第bram_line_cur_w行数据在bram中
    
	output	wire	[clogb2(P_LINE_DEPTH-1):0]	bram_line_num_addr							,	// 每段bram地址对应的行号地址
    input      		[12-1:0] 					bram_line_num								,	// 每段bram地址对应的行号 , bram_line_num_addr*32'h0~bram_line_num_addr*32'h800对应的行号,具体列号对应当前行的不同地址
   
    output		  	[clogb2(B_RAM_DEPTH-1)-1:0] bram_addrb   								,	// 16bit位宽的bram地址
    input		  	[B_RAM_WIDTH-1:0]           bram_doutb   								,     
//===========================================================================================
//--反向映射查找表（LUT）DDR读取接口                                                         
	output	wire	[3:0]						V_LUT_AXI_ARID								,
	output	wire	[31:0]						V_LUT_AXI_ARADDR							,
	output	wire	[7:0]						V_LUT_AXI_ARLEN								,
	output	wire	[2:0]						V_LUT_AXI_ARSIZE							,
	output	wire	[1:0]						V_LUT_AXI_ARBURST							,
	output	wire								V_LUT_AXI_ARLOCK							,
	output	wire	[3:0]						V_LUT_AXI_ARCACHE							,
	output	wire	[2:0]						V_LUT_AXI_ARPROT							,
	output	wire	[3:0]						V_LUT_AXI_ARQOS								,
	output	wire								V_LUT_AXI_ARVALID							,
	input	wire								V_LUT_AXI_ARREADY							,
	input	wire	[3:0]						V_LUT_AXI_RID								,
	input	wire	[63:0]						V_LUT_AXI_RDATA								,
	input	wire	[1:0]						V_LUT_AXI_RRESP								,
	input	wire								V_LUT_AXI_RLAST								,
	input	wire								V_LUT_AXI_RVALID							,
	output	wire								V_LUT_AXI_RREADY							,
//==================================================================================================
//--输出给SRIO--------------------------
//----------------------------------------------------------------------------------
// 数据宽度: 64bit
//--------------------------------------------------------------------------------
// 第1拍: axis0 (消息头)
// --------------------------------------------------------------------------------
// |  位域范围   |   含义说明      |
// |------------|----------------|
// | bit63~bit32 | 消息类型 (RapidIO Ttype)		:32'h00600000
// | bit31~bit0  | 地址 (RapidIO Target Address):发送给SRIO的地址对应首个像素的字节地址
//--------------------------------------------------------------------------------
// 第2~65拍及以后: (视频数据 payload)//固定256字节
// --------------------------------------------------------------------------------
// |  位域范围   |   含义说明      |
// |------------|----------------|
// | bit63~bit0  | 负载数据 (Payload Data)
//--------------------------------------------------------------------------------
	input										m_srio_axis_aclk							,	// 外部SRIO不同模式，时钟不同x2:125M,x1_62.5M
	input										m_srio_axis_rstn							,
	output	wire	[63:0]						m_srio_axis_tdata							,
	input										m_srio_axis_tready							,
	output	wire								m_srio_axis_tvalid							,
	output										m_srio_axis_tlast							
	);

    //  The following function calculates the address width based on specified RAM depth
    function integer clogb2;
        input integer depth;
        for (clogb2=0; depth>0; clogb2=clogb2+1)
            depth = depth >> 1;
    endfunction	

	// 新代码：Egor Izmaylov 将原 BRAM->AXIS 输出先命名为 raw_*，再送入 HLS 处理核。
	// 维护边界：旧的直连路径完整保留在下方注释块中，后续算法只替换 HLS/wrapper 边界。
	wire			[63:0]						raw_srio_axis_tdata							;
	wire										raw_srio_axis_tready						;
	wire										raw_srio_axis_tvalid						;
	wire										raw_srio_axis_tlast							;

`ifdef ENABLE_FISHEYE_REMAP_READER
	// 新代码：Egor Izmaylov 将算法前移到 BRAM 读出阶段，实现真实源像素重采样去畸变。
	// 维护边界：SRIO、MIG、BD/IP、XDC 和板级接口保持不变；旧 AXIS 后处理路径保留在下方宏分支。
	fisheye_remap_bram_to_axis #(
		.B_RAM_WIDTH							( B_RAM_WIDTH								),
		.B_RAM_DEPTH							( B_RAM_DEPTH								),
		.P_LINE_DEPTH							( P_LINE_DEPTH								)
	) u_fisheye_remap_bram_to_axis (
		.bram_clk								( clk										),
		.bram_rstn								( rstn										),
		.bram_line_cur_w						( bram_line_cur_w							),
		.bram_line_cur_w_en						( bram_line_cur_w_en						),
		.bram_line_num_addr						( bram_line_num_addr						),
		.bram_line_num							( bram_line_num								),
		.bram_addrb								( bram_addrb								),
		.bram_doutb								( bram_doutb								),
		.video_algo_ctrl						( video_algo_ctrl							),

		.m_axis_aclk							( m_srio_axis_aclk							),
		.m_axis_aresetn							( m_srio_axis_rstn							),
		.m_axis_tready							( m_srio_axis_tready						),
		.m_axis_tdata							( m_srio_axis_tdata							),
		.m_axis_tvalid							( m_srio_axis_tvalid						),
		.m_axis_tlast							( m_srio_axis_tlast							)
	);
`else
	// 新代码：Egor Izmaylov 默认恢复旧稳定“顺序读 BRAM -> SRIO AXIS”路径，优先恢复板上出图。
	// 旧代码保留：退役 AXIS 后处理 HLS 只在 ENABLE_RETIRED_AXIS_POST_HLS_PATH 下参与链路。
	readbram_to_axis64_top #(
	    .B_RAM_WIDTH        					( B_RAM_WIDTH    							),
	    .B_RAM_DEPTH        					( B_RAM_DEPTH      							),
	    .P_LINE_DEPTH        					( P_LINE_DEPTH      						)
	)readbram_to_axis64_top(
	    .bram_clk   	       					( clk   									),
		.bram_rstn   	    					( rstn   	    							),

	    .bram_line_cur_w   	       				( bram_line_cur_w   						),
		.bram_line_cur_w_en   	    			( bram_line_cur_w_en   	    				),
	    .bram_line_num		       				( bram_line_num		    					),
		.bram_line_num_addr   	    			( bram_line_num_addr   	    				),
	    .bram_addrb   		       				( bram_addrb   		    					),
	    .bram_doutb   		       				( bram_doutb   		    					), 
		

        .m_axis_aclk		     				( m_srio_axis_aclk               			),
        .m_axis_aresetn	                        ( m_srio_axis_rstn          				),      
                        
`ifdef ENABLE_RETIRED_AXIS_POST_HLS_PATH
        .m_axis_tready	     					( raw_srio_axis_tready						),
        .m_axis_tdata	         				( {raw_srio_axis_tlast,raw_srio_axis_tdata}	),
        .m_axis_tvalid	         				( raw_srio_axis_tvalid	      				));
`else
        .m_axis_tready	     					( m_srio_axis_tready						),
        .m_axis_tdata	         				( {m_srio_axis_tlast,m_srio_axis_tdata}		),
        .m_axis_tvalid	         				( m_srio_axis_tvalid	      				));
`endif

`ifdef ENABLE_RETIRED_AXIS_POST_HLS_PATH
	// 新代码：Egor Izmaylov 退役演示 HLS 路径仅在显式定义 ENABLE_RETIRED_AXIS_POST_HLS_PATH 时启用。
	// 新代码：Egor Izmaylov 在 SRIO 输出前插入 HLS 去畸变/演示处理。
	// 数据契约：输入输出均保持 64bit AXIS payload 和 tlast 语义，避免影响后级 SRIO 发送模块。
	undistort_demo_hls_wrap u_undistort_demo_hls_wrap(
		.clk									( m_srio_axis_aclk							),
		.rstn									( m_srio_axis_rstn							),
		.algo_ctrl								( video_algo_ctrl							),

		.s_axis_tdata							( raw_srio_axis_tdata						),
		.s_axis_tvalid							( raw_srio_axis_tvalid						),
		.s_axis_tready							( raw_srio_axis_tready						),
		.s_axis_tlast							( raw_srio_axis_tlast						),

		.m_axis_tdata							( m_srio_axis_tdata							),
		.m_axis_tvalid							( m_srio_axis_tvalid						),
		.m_axis_tready							( m_srio_axis_tready						),
		.m_axis_tlast							( m_srio_axis_tlast							)
	);
`endif
`endif

	// 旧代码
//	readbram_to_axis64_top #(
//	    .B_RAM_WIDTH        					( B_RAM_WIDTH    							),
//	    .B_RAM_DEPTH        					( B_RAM_DEPTH      							),
//	    .P_LINE_DEPTH        					( P_LINE_DEPTH      						)
//	)readbram_to_axis64_top(
//	    .bram_clk   	       					( clk   									),
//		.bram_rstn   	    					( rstn   	    							),
//
//	    .bram_line_cur_w   	       				( bram_line_cur_w   						),
//		.bram_line_cur_w_en   	    			( bram_line_cur_w_en   	    				),
//	    .bram_line_num		       				( bram_line_num		    					),
//		.bram_line_num_addr   	    			( bram_line_num_addr   	    				),
//	    .bram_addrb   		       				( bram_addrb   		    					),
//	    .bram_doutb   		       				( bram_doutb   		    					), 
//		
//
//        .m_axis_aclk		     				( m_srio_axis_aclk               			),
//        .m_axis_aresetn	                        ( m_srio_axis_rstn          				),      
//                        
//        .m_axis_tready	     					( m_srio_axis_tready						),
//        .m_axis_tdata	         				( {m_srio_axis_tlast,m_srio_axis_tdata}	    ),
//        .m_axis_tvalid	         				( m_srio_axis_tvalid	      				));
		



endmodule
