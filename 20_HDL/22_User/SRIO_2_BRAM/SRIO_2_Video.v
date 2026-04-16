// ============================================================================
// ����ά��˵��
// �ļ�ְ��      : ��ǰ�ļ�Ϊ�ֹ�ά��Դ�룬�е���ģ��/�ű�����ʵʵ�֡�
// ά���߽�      : ��ע�Ϳ������ά��˵��������д�κ�ԭ��˵������ʷע�ͻ������߼���
// �޸�Լ��      : ���������������˵����ֻ����׷������ע�ͣ������滻��ע�ͻ�Ķ��ɴ��롣
// ���ɹ�ϵ      : �����ڶ�Ӧ�����Ӧ�Ե�ǰ�ֹ�Դ��Ϊ׼����ֹ���򸲸Ǳ��ļ���
// ============================================================================
module SRIO_2_Video#(
    parameter		A_RAM_WIDTH     			= 64        								,
    parameter		A_RAM_DEPTH     			= 256*512      								,	// bram深度参数，512每行
    parameter		B_RAM_WIDTH     			= 16        								,
    parameter		B_RAM_DEPTH     			= A_RAM_WIDTH*A_RAM_DEPTH/B_RAM_WIDTH      	,    
    parameter		RAM_OUT_REG_EN  			= "DISABLE"  								,	// ENABLE
    parameter		RAM_STYLE       			= "block"   								,
    parameter		INIT_FILE       			= ""        								,
    
    parameter		P_LINE_DEPTH     			= A_RAM_DEPTH/512								// bram中可以存的视频行数	      		

/*	
	每帧图像2049*2048*2=32'h801000字节，
	8字节地址宽度为32'h100200，为了后期减少延时，将地址信息21bit宽度，帧计数1bit宽度协同数据一起存入bram；
	总共需要86宽度bram，并行18kbram需要5个，则一行图像为512深度，实际使用最低5个18kbram，对应z7100中为2.5个bram，存储两行数据。
	
	该模块有3个bram，每存储两行需要bram资源位2.5*3=7.5个，行数对应bram消耗个数为：（Z7100总共有755个）
	2	7.5
	4	15
	8	30
	16	60
	32	120
	64	240      
	
	每帧图像2049*2048*2=32'h801000字节，第1~2048行行地址依次是：
	行地址	行地址实际	bram_64		bram_16	起始地址
	1000    0000  		 0000    	 0000      
	2000	1000		 0200    	 0800    
	3000	2000		 0400    	 1000    
	…………………………                        
	800000	7FF000		               
	
*/    
) (
//==================================================================================================
//--Input/Output Port--------------------------
	input										srio_clk									,
	input										srio_rstn_i									,  
	
	input										user_clk									,  // 采用250M时钟
	input										user_rstn_i									,  
	// 新代码
	input			[31:0]						video_algo_ctrl								,
//==================================================================================================
//--SRIO_端口
	input	wire	[63:0]						SRIO_R_axis_tdata							,
	input	wire	[31:0]						SRIO_R_axis_tuser							,
	output	wire								SRIO_R_axis_tready							,
	input	wire								SRIO_R_axis_tvalid							,
	input	wire								SRIO_R_axis_tlast							,
	
	output	wire	[63:0]						SRIO_T_axis_tdata							,
	output	wire	[31:0]						SRIO_T_axis_tuser							,
	input	wire								SRIO_T_axis_tready							,
	output	wire								SRIO_T_axis_tvalid							,
	output	wire								SRIO_T_axis_tlast							,
//==================================================================================================
//--反向映射查找表（LUT）DDR读取接口
	input	wire								V_LUT_AXI_clk							,
	input	wire								V_LUT_AXI_rstn							,

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
	output	wire								V_LUT_AXI_RREADY							
	);
	wire										user_rstn									; 
    sync_nrst i_sync_user_nrst(
        .rst_n                      			( user_rstn_i                   			),
        .clk                        			( user_clk             				      ),
                                    			                            				
        .sync_rst_n                 			( user_rstn        				          )
    );	

	wire										srio_rstn									; 
    sync_nrst i_sync_srio_nrst(
        .rst_n                      			( srio_rstn_i                   		),
        .clk                        			( srio_clk             				      ),
                                    			                            				
        .sync_rst_n                 			( srio_rstn        				          )
    );	
	
    //  The following function calculates the address width based on specified RAM depth
    function integer clogb2;
        input integer depth;
        for (clogb2=0; depth>0; clogb2=clogb2+1)
            depth = depth >> 1;
    endfunction
    wire		  	                            bram_wea     								;  
    wire		  	[clogb2(A_RAM_DEPTH-1)-1:0] bram_addra   								;  
    wire		  	[A_RAM_WIDTH-1:0]           bram_dina    								;  

    wire		  	[clogb2(B_RAM_DEPTH-1)-1:0] bram_line_cur_w   							;	// 当前bram写入行位置 
    wire      					 				bram_line_cur_w_en   						; 	//	1 :表示成功写入第bram_line_cur_w行数据在bram中
    
    
	wire		     [clogb2(P_LINE_DEPTH-1):0]	bram_line_num_addr							;	// 每段bram地址对应的行号地址
    wire      		[12-1:0] 					bram_line_num								;	// 每段bram地址对应的行号 , bram_line_num_addr*32'h0~bram_line_num_addr*32'h800对应的行号,具体列号对应当前行的不同地址
        
    wire		  	[clogb2(B_RAM_DEPTH-1)-1:0] bram_addrb   								;	// 16bit位宽的bram地址
    wire		  	[B_RAM_WIDTH-1:0]           bram_doutb   								;     
                                                                                            
	srio_v_axis_to_bram_top	#(
		.A_RAM_WIDTH 							( A_RAM_WIDTH 								),
		.A_RAM_DEPTH 							( A_RAM_DEPTH 								),
		.B_RAM_WIDTH 							( B_RAM_WIDTH 								)
	)i_srio_v_axis_to_bram_top	(
		.sys_clk_i			    				( srio_clk			    					),
		.sys_rst_i			    				( ~srio_rstn			    				),

		.s_axis_tdata_i		    				( SRIO_R_axis_tdata							),
		.s_axis_tready_o						( SRIO_R_axis_tready						),
		.s_axis_tvalid_i						( SRIO_R_axis_tvalid						),
		.s_axis_tlast_i		    				( SRIO_R_axis_tlast							),
		.s_axis_tuser_i		    				( SRIO_R_axis_tuser							),

		.bram_wea     		    				( bram_wea     		    					),
		.bram_addra   		    				( bram_addra   		    					),
		.bram_dina    		    				( bram_dina    		    					),

		.bram_clkb     		    				( user_clk     								),
		.bram_clkb_rstn     		    				( user_rstn     								),
		
		.bram_line_cur_w   	    				( bram_line_cur_w   	    				),
		.bram_line_cur_w_en   	    			( bram_line_cur_w_en   	    				),
		.bram_line_num_addr   	    			( bram_line_num_addr   	    				),
		.bram_line_num   	    				( bram_line_num   	    					)
	);

//		ila_test	ila_bram(
//		.clk                        			( user_clk								),
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

	sdp_drw_ram	#(
		.A_RAM_WIDTH        					( A_RAM_WIDTH    							),
	    .A_RAM_DEPTH        					( A_RAM_DEPTH    							),
	    .B_RAM_WIDTH        					( B_RAM_WIDTH    							),
	    .RAM_STYLE        						( RAM_STYLE      							),
	    .RAM_OUT_REG_EN     					( RAM_OUT_REG_EN 							)
	) u_video_ram(            					                							
	    .clka                					( srio_clk           						),
	                        					
	    .wea                					( bram_wea    								),
	    .addra              					( bram_addra    							),
	    .dina               					( bram_dina    								),
	                       
	    .clkb                					( user_clk                                	),
	    .rstb                					( ~user_rstn                                ),

	    .enb                					( 1'b1		                                ),	// 待修改
	    .addrb              					( bram_addrb               					),
	    .doutb              					( bram_doutb               					),
	    .regceb             					( 1'b1                                  	)
	);
	
	vbram_lutaxi4_to_axis	#(
	    .B_RAM_WIDTH        					( B_RAM_WIDTH    							),
	    .B_RAM_DEPTH        					( B_RAM_DEPTH      							),
	    .P_LINE_DEPTH        					( P_LINE_DEPTH      						)
	) u_vbram_lutaxi4_to_axis(            
	    .clk                					( user_clk           						),
	    .rstn                					( user_rstn           						),
	    // 新代码
	    .video_algo_ctrl						( video_algo_ctrl							),

	    .bram_line_cur_w   	       				( bram_line_cur_w   						),
	    
		.bram_line_cur_w_en   	    			( bram_line_cur_w_en   	    				),
		.bram_line_num_addr   	    			( bram_line_num_addr   	    				),
	    .bram_line_num		       				( bram_line_num		    					),
	    .bram_addrb   		       				( bram_addrb   		    					),
	    .bram_doutb   		       				( bram_doutb   		    					), 
	    
	    .V_LUT_AXI_ARID		       				( V_LUT_AXI_ARID							),
	    .V_LUT_AXI_ARADDR	       				( V_LUT_AXI_ARADDR	    					),
	    .V_LUT_AXI_ARLEN		   				( V_LUT_AXI_ARLEN							),
	    .V_LUT_AXI_ARSIZE	       				( V_LUT_AXI_ARSIZE	    					),
	    .V_LUT_AXI_ARBURST	       				( V_LUT_AXI_ARBURST	    					),
	    .V_LUT_AXI_ARLOCK	       				( V_LUT_AXI_ARLOCK	    					),
	    .V_LUT_AXI_ARCACHE	       				( V_LUT_AXI_ARCACHE	    					),
	    .V_LUT_AXI_ARPROT	       				( V_LUT_AXI_ARPROT	    					),
	    .V_LUT_AXI_ARQOS		   				( V_LUT_AXI_ARQOS							),
	    .V_LUT_AXI_ARVALID	       				( V_LUT_AXI_ARVALID	    					),	    
	    .V_LUT_AXI_ARREADY	       				( V_LUT_AXI_ARREADY	    					),
	    .V_LUT_AXI_RID		       				( V_LUT_AXI_RID		    					),
	    .V_LUT_AXI_RDATA		   				( V_LUT_AXI_RDATA							),
	    .V_LUT_AXI_RRESP		   				( V_LUT_AXI_RRESP							),
	    .V_LUT_AXI_RLAST		   				( V_LUT_AXI_RLAST							),
	    .V_LUT_AXI_RVALID	       				( V_LUT_AXI_RVALID	    					),
	    .V_LUT_AXI_RREADY	       				( V_LUT_AXI_RREADY	    					),
	    
	    .m_srio_axis_aclk		    			( srio_clk	    							),
	    .m_srio_axis_rstn		    			( srio_rstn	    							),
	    .m_srio_axis_tdata		    			( SRIO_T_axis_tdata	    					),
	    .m_srio_axis_tready		   				( SRIO_T_axis_tready						),
	    .m_srio_axis_tvalid		    			( SRIO_T_axis_tvalid	    				),
	    .m_srio_axis_tlast		    			( SRIO_T_axis_tlast	    					)
	);
		
		assign		SRIO_T_axis_tuser			= 32'h0001000a								;
//		ila_axis	ila_srio_s(
//		.clk                        			( srio_clk								),
//		.probe0                                  ( {
//	     SRIO_T_axis_tdata	    					,
//	     SRIO_T_axis_tready						,
//	     SRIO_T_axis_tvalid	    				,
//	     SRIO_T_axis_tlast	    					
								
//																							})
//	);
//		ila_axis	ila_srio_r(
//		.clk                        			( srio_clk								),
//		.probe0                                  ( {
//	     SRIO_R_axis_tdata	    					,
//	     SRIO_R_axis_tready						,
//	     SRIO_R_axis_tvalid	    				,
//	     SRIO_R_axis_tlast	    					
								
//																							})
//	);
	endmodule
