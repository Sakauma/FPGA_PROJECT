`timescale 1ns/1ns
// ============================================================================
// –¬‘ˆŒ¨ª§Àµ√˜
// Œƒº˛÷∞‘      : µ±«∞Œƒº˛Œ™ ÷π§Œ¨ª§‘¥¬Î£¨≥–µ£±æƒ£øÈ/Ω≈±æµƒ’Ê µ µœ÷°£
// Œ¨ª§±ﬂΩÁ      : ±æ◊¢ ÕøÈΩˆ≤π≥‰Œ¨ª§Àµ√˜£¨≤ª∏ƒ–¥»Œ∫Œ‘≠”–Àµ√˜°¢¿˙ ∑◊¢ ÕªÚœ÷”–¬ﬂº≠°£
// –ﬁ∏ƒ‘º ¯      : ∫Û–¯»Á–ËºÃ–¯≤π≥‰Àµ√˜£¨÷ª‘ –Ì◊∑º”÷–Œƒ◊¢ Õ£¨≤ªµ√ÃÊªªæ…◊¢ ÕªÚ∏ƒ∂Øæ…¥˙¬Î°£
// …˙≥…πÿœµ      : »Ù¥Ê‘⁄∂‘”¶…˙≥…ŒÔ£¨”¶“‘µ±«∞ ÷π§‘¥¬ÎŒ™◊º£¨Ω˚÷π∑¥œÚ∏≤∏«±æŒƒº˛°£
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
//		1„ÄÅËßÜÈ¢ëbram„ÄÅÊü•ÊâæË°®axi4Âà∞srioÁöÑaxisÁöÑÊé•Âè£                  
//		2„ÄÅ1Ë°åËßÜÈ¢ëÂç†Áî®1‰∏™bramÂçïÂÖÉÔºåxc7z100ffg900ÊÄªÂÖ±755‰∏™ÂçïÂÖÉ    
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
/*Êé•Âè£ÊèèËø∞            
//======================================================================================
//  Input / Output Interface Description
//======================================================================================
//  Signal Name         | Êó∂ÈíüÂüü   			|  Description
//----------------------|-------------------|--------------------------------------------
//  bram_            	| clk     			| ËßÜÈ¢ëbramÁºìÂ≠òÊé•Âè£
//  V_LUT_            	| clk     			| Êü•ÊâæË°®Êé•Âè£Ôºåaxi4
//  m_srio_             | m_srio_axis_aclk  | SRIOËæìÂá∫Êé•Âè£
//--------------------------------------------------------------------------------------
//	clk					:	250MHzÔºõ
//	m_srio_axis_aclk	:	ÂΩìÂâç‰∏∫62.5MHzÔºåË∞ÉÈÄöÂêé‰ºöÊõ¥Êîπ‰∏∫125MHz„ÄÇ
*/									
////////////////////////////////////////////////////////////////////////////////////////////////////

module vbram_lutaxi4_to_axis#(
    parameter		B_RAM_WIDTH     			= 16        								,
    parameter		B_RAM_DEPTH  				= 32'h64000	  								,	// 32'h64000Ôºö200Ë°å
    parameter		P_LINE_DEPTH     			= 200											// bram‰∏≠ÂèØ‰ª•Â≠òÁöÑËßÜÈ¢ëË°åÊï∞	      		
    )(
//==================================================================================================
//--Input/Output Port--------------------------
	input										clk											,	//250M
	input										rstn										,
	// Êñ∞‰ª£Á†Å
	input			[31:0]						video_algo_ctrl								,
//==================================================================================================
//--ËßÜÈ¢ëbramÊé•Âè£--------------------------	
    input		  	[clogb2(B_RAM_DEPTH-1)-1:0] bram_line_cur_w   							,	// ÂΩìÂâçbramÂÜôÂÖ•Ë°å‰ΩçÁΩÆ 
    input      					 				bram_line_cur_w_en   						, 	//	1 :Ë°®Á§∫ÊàêÂäüÂÜôÂÖ•Á¨¨bram_line_cur_wË°åÊï∞ÊçÆÂú®bram‰∏≠
    
	output	wire	[clogb2(P_LINE_DEPTH-1):0]	bram_line_num_addr							,	// ÊØèÊÆµbramÂú∞ÂùÄÂØπÂ∫îÁöÑË°åÂè∑Âú∞ÂùÄ
    input      		[12-1:0] 					bram_line_num								,	// ÊØèÊÆµbramÂú∞ÂùÄÂØπÂ∫îÁöÑË°åÂè∑ , bram_line_num_addr*32'h0~bram_line_num_addr*32'h800ÂØπÂ∫îÁöÑË°åÂè∑,ÂÖ∑‰ΩìÂàóÂè∑ÂØπÂ∫îÂΩìÂâçË°åÁöÑ‰∏çÂêåÂú∞ÂùÄ
   
    output		  	[clogb2(B_RAM_DEPTH-1)-1:0] bram_addrb   								,	// 16bit‰ΩçÂÆΩÁöÑbramÂú∞ÂùÄ
    input		  	[B_RAM_WIDTH-1:0]           bram_doutb   								,     
//===========================================================================================
//--ÂèçÂêëÊò†Â∞ÑÊü•ÊâæË°®ÔºàLUTÔºâDDRËØªÂèñÊé•Âè£                                                         
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
//--ËæìÂá∫ÁªôSRIO--------------------------
//----------------------------------------------------------------------------------
// Êï∞ÊçÆÂÆΩÂ∫¶: 64bit
//--------------------------------------------------------------------------------
// Á¨¨1Êãç: axis0 (Ê∂àÊÅØÂ§¥)
// --------------------------------------------------------------------------------
// |  ‰ΩçÂüüËåÉÂõ¥   |   Âê´‰πâËØ¥Êòé      |
// |------------|----------------|
// | bit63~bit32 | Ê∂àÊÅØÁ±ªÂûã (RapidIO Ttype)		:32'h00600000
// | bit31~bit0  | Âú∞ÂùÄ (RapidIO Target Address):ÂèëÈÄÅÁªôSRIOÁöÑÂú∞ÂùÄÂØπÂ∫îÈ¶ñ‰∏™ÂÉèÁ¥†ÁöÑÂ≠óËäÇÂú∞ÂùÄ
//--------------------------------------------------------------------------------
// Á¨¨2~65ÊãçÂèä‰ª•Âêé: (ËßÜÈ¢ëÊï∞ÊçÆ payload)//Âõ∫ÂÆö256Â≠óËäÇ
// --------------------------------------------------------------------------------
// |  ‰ΩçÂüüËåÉÂõ¥   |   Âê´‰πâËØ¥Êòé      |
// |------------|----------------|
// | bit63~bit0  | Ë¥üËΩΩÊï∞ÊçÆ (Payload Data)
//--------------------------------------------------------------------------------
	input										m_srio_axis_aclk							,	// Â§ñÈÉ®SRIO‰∏çÂêåÊ®°ÂºèÔºåÊó∂Èíü‰∏çÂêåx2:125M,x1_62.5M
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

	// Êñ∞‰ª£Á†Å
	wire			[63:0]						raw_srio_axis_tdata							;
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

	// Êóß‰ª£Á†Å
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

