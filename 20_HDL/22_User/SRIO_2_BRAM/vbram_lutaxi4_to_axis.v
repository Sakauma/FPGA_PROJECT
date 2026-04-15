`timescale 1ns/1ns
// ============================================================================
// 维护注释
//   文件职责      : BRAM 读出转 AXIS 的打包模块，也是当前视觉预处理插入点。
//   源码属性      : 手工维护源码，不要把修改同步到生成 IP 或网表。
//   更新要求      : 当时钟、复位、接口或数据顺序假设变化时，同步更新注释。
//   维护边界      : 注释用于说明当前实现意图，不替代接口协议文档。
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
//		1銆佽棰慴ram銆佹煡鎵捐〃axi4鍒皊rio鐨刟xis鐨勬帴鍙?                 
//		2銆?琛岃棰戝崰鐢?涓猙ram鍗曞厓锛寈c7z100ffg900鎬诲叡755涓崟鍏?   
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
/*鎺ュ彛鎻忚堪            
//======================================================================================
//  Input / Output Interface Description
//======================================================================================
//  Signal Name         | 鏃堕挓鍩?  			|  Description
//----------------------|-------------------|--------------------------------------------
//  bram_            	| clk     			| 瑙嗛bram缂撳瓨鎺ュ彛
//  V_LUT_            	| clk     			| 鏌ユ壘琛ㄦ帴鍙ｏ紝axi4
//  m_srio_             | m_srio_axis_aclk  | SRIO杈撳嚭鎺ュ彛
//--------------------------------------------------------------------------------------
//	clk					:	250MHz锛?
//	m_srio_axis_aclk	:	褰撳墠涓?2.5MHz锛岃皟閫氬悗浼氭洿鏀逛负125MHz銆?
*/									
////////////////////////////////////////////////////////////////////////////////////////////////////

module vbram_lutaxi4_to_axis#(
    parameter		B_RAM_WIDTH     			= 16        								,
    parameter		B_RAM_DEPTH  				= 32'h64000	  								,	// 32'h64000锛?00琛?
    parameter		P_LINE_DEPTH     			= 200											// bram涓彲浠ュ瓨鐨勮棰戣鏁?      		
    )(
//==================================================================================================
//--Input/Output Port--------------------------
	input										clk											,	//250M
	input										rstn										,
	// 鏂颁唬鐮?	input			[31:0]						video_algo_ctrl								,
//==================================================================================================
//--瑙嗛bram鎺ュ彛--------------------------	
    input		  	[clogb2(B_RAM_DEPTH-1)-1:0] bram_line_cur_w   							,	// 褰撳墠bram鍐欏叆琛屼綅缃?
    input      					 				bram_line_cur_w_en   						, 	//	1 :琛ㄧず鎴愬姛鍐欏叆绗琤ram_line_cur_w琛屾暟鎹湪bram涓?
    
	output	wire	[clogb2(P_LINE_DEPTH-1):0]	bram_line_num_addr							,	// 姣忔bram鍦板潃瀵瑰簲鐨勮鍙峰湴鍧€
    input      		[12-1:0] 					bram_line_num								,	// 姣忔bram鍦板潃瀵瑰簲鐨勮鍙?, bram_line_num_addr*32'h0~bram_line_num_addr*32'h800瀵瑰簲鐨勮鍙?鍏蜂綋鍒楀彿瀵瑰簲褰撳墠琛岀殑涓嶅悓鍦板潃
   
    output		  	[clogb2(B_RAM_DEPTH-1)-1:0] bram_addrb   								,	// 16bit浣嶅鐨刡ram鍦板潃
    input		  	[B_RAM_WIDTH-1:0]           bram_doutb   								,     
//===========================================================================================
//--鍙嶅悜鏄犲皠鏌ユ壘琛紙LUT锛塂DR璇诲彇鎺ュ彛                                                         
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
//--杈撳嚭缁橲RIO--------------------------
//----------------------------------------------------------------------------------
// 鏁版嵁瀹藉害: 64bit
//--------------------------------------------------------------------------------
// 绗?鎷? axis0 (娑堟伅澶?
// --------------------------------------------------------------------------------
// |  浣嶅煙鑼冨洿   |   鍚箟璇存槑      |
// |------------|----------------|
// | bit63~bit32 | 娑堟伅绫诲瀷 (RapidIO Ttype)		:32'h00600000
// | bit31~bit0  | 鍦板潃 (RapidIO Target Address):鍙戦€佺粰SRIO鐨勫湴鍧€瀵瑰簲棣栦釜鍍忕礌鐨勫瓧鑺傚湴鍧€
//--------------------------------------------------------------------------------
// 绗?~65鎷嶅強浠ュ悗: (瑙嗛鏁版嵁 payload)//鍥哄畾256瀛楄妭
// --------------------------------------------------------------------------------
// |  浣嶅煙鑼冨洿   |   鍚箟璇存槑      |
// |------------|----------------|
// | bit63~bit0  | 璐熻浇鏁版嵁 (Payload Data)
//--------------------------------------------------------------------------------
	input										m_srio_axis_aclk							,	// 澶栭儴SRIO涓嶅悓妯″紡锛屾椂閽熶笉鍚寈2:125M,x1_62.5M
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

	// 鏂颁唬鐮?	wire			[63:0]						raw_srio_axis_tdata							;
	wire										raw_srio_axis_tready						;
	wire										raw_srio_axis_tvalid						;
	wire										raw_srio_axis_tlast							;

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
                        
        .m_axis_tready	     					( raw_srio_axis_tready						),
        .m_axis_tdata	         				( {raw_srio_axis_tlast,raw_srio_axis_tdata}	),
        .m_axis_tvalid	         				( raw_srio_axis_tvalid	      				));

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

	// 鏃т唬鐮?//	readbram_to_axis64_top #(
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


