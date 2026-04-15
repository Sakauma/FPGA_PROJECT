// ============================================================================
// 维护注释
//   文件职责      : SRIO 输入、BRAM 暂存与 SRIO 输出之间的本地视频主路径。
//   源码属性      : 手工维护源码，不要把修改同步到生成 IP 或网表。
//   更新要求      : 当时钟、复位、接口或数据顺序假设变化时，同步更新注释。
//   维护边界      : 注释用于说明当前实现意图，不替代接口协议文档。
// ============================================================================
module SRIO_2_Video#(
    parameter		A_RAM_WIDTH     			= 64        								,
    parameter		A_RAM_DEPTH     			= 256*512      								,	// bram濞ｅ崬瀹抽崣鍌涙殶閿?12濮ｅ繗顢?
    parameter		B_RAM_WIDTH     			= 16        								,
    parameter		B_RAM_DEPTH     			= A_RAM_WIDTH*A_RAM_DEPTH/B_RAM_WIDTH      	,    
    parameter		RAM_OUT_REG_EN  			= "DISABLE"  								,	// ENABLE
    parameter		RAM_STYLE       			= "block"   								,
    parameter		INIT_FILE       			= ""        								,
    
    parameter		P_LINE_DEPTH     			= A_RAM_DEPTH/512								// bram娑擃厼褰叉禒銉ョ摠閻ㄥ嫯顫嬫０鎴ｎ攽閺?      		

/*	
	濮ｅ繐鎶氶崶鎯у剼2049*2048*2=32'h801000鐎涙濡敍?
	8鐎涙濡崷鏉挎絻鐎硅棄瀹虫稉?2'h100200閿涘奔璐熸禍鍡楁倵閺堢喎鍣虹亸鎴濇閺冭绱濈亸鍡楁勾閸р偓娣団剝浼?1bit鐎硅棄瀹抽敍灞芥姎鐠佲剝鏆?bit鐎硅棄瀹抽崡蹇撴倱閺佺増宓佹稉鈧挧宄扮摠閸忣櫒ram閿?
	閹鍙￠棁鈧憰?6鐎硅棄瀹砨ram閿涘苯鑻熺悰?8kbram闂団偓鐟?娑擃亷绱濋崚娆庣鐞涘苯娴橀崓蹇庤礋512濞ｅ崬瀹抽敍灞界杽闂勫懍濞囬悽銊︽付娴?娑?8kbram閿涘苯顕惔鏀?100娑擃厺璐?.5娑撶寵ram閿涘苯鐡ㄩ崒銊よ⒈鐞涘本鏆熼幑顔衡偓?
	
	鐠囥儲膩閸ф婀?娑撶寵ram閿涘本鐦＄€涙ê鍋嶆稉銈堫攽闂団偓鐟曚攻ram鐠у嫭绨担?.5*3=7.5娑擃亷绱濈悰灞炬殶鐎电懓绨瞓ram濞戝牐鈧ぞ閲滈弫棰佽礋閿涙熬绱橺7100閹鍙￠張?55娑擃亷绱?
	2	7.5
	4	15
	8	30
	16	60
	32	120
	64	240      
	
	濮ｅ繐鎶氶崶鎯у剼2049*2048*2=32'h801000鐎涙濡敍宀€顑?~2048鐞涘矁顢戦崷鏉挎絻娓氭繃顐奸弰顖ょ窗
	鐞涘苯婀撮崸鈧?鐞涘苯婀撮崸鈧€圭偤妾?bram_64		bram_16	鐠у嘲顫愰崷鏉挎絻
	1000    0000  		 0000    	 0000      
	2000	1000		 0200    	 0800    
	3000	2000		 0400    	 1000    
	閳ワ腹鈧腹鈧腹鈧腹鈧腹鈧腹鈧腹鈧腹鈧腹鈧?                       
	800000	7FF000		               
	
*/    
) (
//==================================================================================================
//--Input/Output Port--------------------------
	input										srio_clk									,
	input										srio_rstn_i									,  
	
	input										user_clk									,  // 闁插洨鏁?50M閺冨爼鎸?	input										user_rstn_i									,  
	// 閺傞鍞惍?	input			[31:0]						video_algo_ctrl								,
//==================================================================================================
//--SRIO_缁旑垰褰?	input	wire	[63:0]						SRIO_R_axis_tdata							,
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
//--閸欏秴鎮滈弰鐘茬殸閺屻儲澹樼悰顭掔礄LUT閿涘DR鐠囪褰囬幒銉ュ經
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

    wire		  	[clogb2(B_RAM_DEPTH-1)-1:0] bram_line_cur_w   							;	// 瑜版挸澧燽ram閸愭瑥鍙嗙悰灞肩秴缂?
    wire      					 				bram_line_cur_w_en   						; 	//	1 :鐞涖劎銇氶幋鎰閸愭瑥鍙嗙粭鐞am_line_cur_w鐞涘本鏆熼幑顔兼躬bram娑?
    
    
	wire		     [clogb2(P_LINE_DEPTH-1):0]	bram_line_num_addr							;	// 濮ｅ繑顔宐ram閸︽澘娼冪€电懓绨查惃鍕攽閸欏嘲婀撮崸鈧?
    wire      		[12-1:0] 					bram_line_num								;	// 濮ｅ繑顔宐ram閸︽澘娼冪€电懓绨查惃鍕攽閸?, bram_line_num_addr*32'h0~bram_line_num_addr*32'h800鐎电懓绨查惃鍕攽閸?閸忚渹缍嬮崚妤€褰跨€电懓绨茶ぐ鎾冲鐞涘瞼娈戞稉宥呮倱閸︽澘娼?
        
    wire		  	[clogb2(B_RAM_DEPTH-1)-1:0] bram_addrb   								;	// 16bit娴ｅ秴顔旈惃鍒am閸︽澘娼?
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

	    .enb                					( 1'b1		                                ),	// 瀵板懍鎱ㄩ弨?
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
	    // 閺傞鍞惍?	    .video_algo_ctrl						( video_algo_ctrl							),

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
