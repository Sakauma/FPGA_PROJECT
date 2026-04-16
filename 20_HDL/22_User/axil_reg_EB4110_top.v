`timescale 1ns / 1ps
// ============================================================================
// ĞÂÔöÎ¬»¤ËµÃ÷
// ÎÄ¼şÖ°Ôğ      : µ±Ç°ÎÄ¼şÎªÊÖ¹¤Î¬»¤Ô´Âë£¬³Ğµ£±¾Ä£¿é/½Å±¾µÄÕæÊµÊµÏÖ¡£
// Î¬»¤±ß½ç      : ±¾×¢ÊÍ¿é½ö²¹³äÎ¬»¤ËµÃ÷£¬²»¸ÄĞ´ÈÎºÎÔ­ÓĞËµÃ÷¡¢ÀúÊ·×¢ÊÍ»òÏÖÓĞÂß¼­¡£
// ĞŞ¸ÄÔ¼Êø      : ºóĞøÈçĞè¼ÌĞø²¹³äËµÃ÷£¬Ö»ÔÊĞí×·¼ÓÖĞÎÄ×¢ÊÍ£¬²»µÃÌæ»»¾É×¢ÊÍ»ò¸Ä¶¯¾É´úÂë¡£
// Éú³É¹ØÏµ      : Èô´æÔÚ¶ÔÓ¦Éú³ÉÎï£¬Ó¦ÒÔµ±Ç°ÊÖ¹¤Ô´ÂëÎª×¼£¬½ûÖ¹·´Ïò¸²¸Ç±¾ÎÄ¼ş¡£
// ============================================================================
`timescale 1ns/1ns
////////////////////////////////////////////////////////////////////////////////////////////////////
// Company			: ZHTY				
// Engineer			: wangzhen			
// Create Date		: 2023/6/26 15:06:42   										
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


module axil_reg_EB4110_top # (
	// æ–°ä»£ç 
	parameter 		P_words_w             		= 8          								,	//å¯å†™çš„wordsä¸ªæ•°   
	parameter 		P_words_r             		= 8          								,	//å¯è¯»çš„wordsä¸ªæ•°	
	// æ—§ä»£ç 
	// parameter 		P_words_w             		= 7          								,	//å¯å†™çš„wordsä¸ªæ•°   
	// parameter 		P_words_r             		= 7          								,	//å¯è¯»çš„wordsä¸ªæ•°	
	parameter		base_addr					= 32'h10060000								
)(
//=======================================================================
//--è¾“å…¥è¾“å‡ºç«¯å£å®šä¹‰---------------------------
	/*-------------------------------------------------------------------
	--Common Interface
	-------------------------------------------------------------------*/
	input										clk								,
	input										rst								,	
	
//==================================================================================================
//--å¯„å­˜å™¨
	input			[P_words_r*32-1:0]			data_init								,
	output	reg		[P_words_w*32-1:0]			data_w			= {P_words_w*32{1'b0}}	,	//	0*32+:32 åœ°å€0  1*32+:32 åœ°å€4ï¼Œä¾æ¬¡8ï¼Œc\10\4â€¦â€¦
//=======================================================================
//--AXI Liteå¯„å­˜å™¨å®šä¹‰
	/*-------------------------------------------------------------------
	--Write Data Command Signals
	-------------------------------------------------------------------*/
	input			[31:0]					sys_axi_awaddr					,
	input			[ 2:0]					sys_axi_awprot					,
	input									sys_axi_awvalid					,
	output									sys_axi_awready					,

	/*-------------------------------------------------------------------
	--Write Data Channel Signals
	-------------------------------------------------------------------*/
	input			[31:0]					sys_axi_wdata					,
	input			[ 3:0]					sys_axi_wstrb					,
	input									sys_axi_wvalid					,
	output									sys_axi_wready					,

	/*-------------------------------------------------------------------
	--Write Response Channel Signals
	-------------------------------------------------------------------*/
	output			[ 1:0]					sys_axi_bresp					,
	output	reg								sys_axi_bvalid		= 1'b0		,
	input									sys_axi_bready					,

	/*-------------------------------------------------------------------
	--Read Address Channel Signals
	-------------------------------------------------------------------*/
	input			[31:0]					sys_axi_araddr					,
	input			[ 2:0]					sys_axi_arprot					,
	input									sys_axi_arvalid					,
	output	wire							sys_axi_arready					,

	/*-------------------------------------------------------------------
	--Read Data Channel Signals
	-------------------------------------------------------------------*/
	output	reg		[31:0]					sys_axi_rdata					,
	output			[ 1:0]					sys_axi_rresp					,
	output	reg								sys_axi_rvalid					,
	input									sys_axi_rready					,


	input		[31:0]							D0_18b20									,
	input		[31:0]							D1_18b20									,


	output	reg		[31:0]						srio_v_sid_did	= 'b0					,
	output	reg									srio_v_sel_x1	= 'b0					,

   	output 	reg	    [11:00]						device_temp        							,	//DDRæ¸©åº¦æ¥å£

	output	reg									ps_video_en									,
	// æ–°ä»£ç 
	output	reg		[7:0]						ps_frame_ctr								,
	output	reg		[31:0]						video_algo_ctrl
	// æ—§ä»£ç 
	// output	reg		[7:0]						ps_frame_ctr								
  	
	);

//=======================================================================
//--Parameter Define
	/*-------------------------------------------------------------------
	--AXI Liteå¯„å­˜å™¨é…ç½®åç§»é‡
	-------------------------------------------------------------------*/
	localparam		VERSION				= 32'h20221122					;
	
	localparam		OFF_SPI_VER			= 12'h000						;


    reg 			[31:0]  			lite_axi_araddr_r   = 0			;       
    reg 			[31:0]  			lite_axi_awaddr_r   = 0			;       
    reg 			[31:0]  			lite_axi_wdata_r   	= 0			;  
    reg									lite_aw_valid		= 0			;
    reg             				   	lite_w_valid        = 0        	;
	/*-------------------------------------------------------------------
	--ç³»ç»Ÿç‰ˆæœ¬å’Œå¤ä½¿
	-------------------------------------------------------------------*/
	wire			waddr_hit					= lite_axi_awaddr_r[31:16]==base_addr[31:16]	;
	
    	
	always @(posedge clk or posedge rst) begin
		if(rst) begin
			data_w							    <= data_init					;	//åˆå§‹åŒ–å€¼
		end else if(lite_aw_valid && lite_w_valid &&waddr_hit) begin
				data_w[lite_axi_awaddr_r[15:2]*32 +: 32]<= sys_axi_wdata[31:0] 			;
		end else begin
				data_w							<= data_w								;
		end
	end		

	wire			[P_words_r*32-1:0]			data_r								;


	assign			data_r [0*32+:32]			= srio_v_sid_did						;
	always @(posedge clk or posedge rst) begin
		if(rst) begin
			srio_v_sid_did						<= 32'h0051_0061						;	//åˆå§‹åŒ–å€¼
		end else if(lite_aw_valid && lite_w_valid &&waddr_hit&&lite_axi_awaddr_r[15:00]==0) begin
			srio_v_sid_did						<= sys_axi_wdata[31:0] 					;
		end else begin
			srio_v_sid_did						<= srio_v_sid_did						;	
		end
	end		

	assign			data_r [1*32+:32]			= srio_v_sel_x1							;
	always @(posedge clk or posedge rst) begin
		if(rst) begin
			srio_v_sel_x1						<= 1'b0									;	//åˆå§‹åŒ–å€¼
		end else if(lite_aw_valid && lite_w_valid &&waddr_hit&&lite_axi_awaddr_r[15:00]==4) begin
			srio_v_sel_x1						<= sys_axi_wdata[0] 					;
		end else begin
			srio_v_sel_x1						<= srio_v_sel_x1						;	
		end
	end		

	assign			data_r [2*32+:32]			= ps_video_en							;

	always @(posedge clk or posedge rst) begin
		if(rst) begin
			ps_video_en						<= 1'b1									;	//åˆå§‹åŒ–å€¼
		end else if(lite_aw_valid && lite_w_valid &&waddr_hit&&lite_axi_awaddr_r[15:00]==8) begin
			ps_video_en						<= sys_axi_wdata[0] 					;
		end else begin
			ps_video_en						<= ps_video_en							;	
		end
	end	


	assign			data_r [3*32+:32]			= ps_frame_ctr						;
	always @(posedge clk or posedge rst) begin
		if(rst) begin
			ps_frame_ctr						<= 32'h0000_0004						;	//åˆå§‹åŒ–å€¼
		end else if(lite_aw_valid && lite_w_valid &&waddr_hit&&lite_axi_awaddr_r[15:00]==16'h000c) begin
			ps_frame_ctr						<= sys_axi_wdata[31:0] 				;
		end else begin
			ps_frame_ctr						<= ps_frame_ctr						;	
		end
	end		
	
	assign			data_r [4*32+:32]			= device_temp						;
	always @(posedge clk or posedge rst) begin
		if(rst) begin
			device_temp						<= 32'h0000_0000						;	//åˆå§‹åŒ–å€¼
		end else if(lite_aw_valid && lite_w_valid &&waddr_hit&&lite_axi_awaddr_r[15:00]==16'h0010) begin
			device_temp						<= sys_axi_wdata[31:0] 					;
		end else begin
			device_temp						<= device_temp							;	
		end
	end			
	
	// æ–°ä»£ç 
	assign			data_r [5*32+:32]			= video_algo_ctrl						;
	always @(posedge clk or posedge rst) begin
		if(rst) begin
			video_algo_ctrl					<= 32'h0000_0007						;	// é»˜è®¤å¼€å¯ç®—æ³•ä¸æ¼”ç¤º
		end else if(lite_aw_valid && lite_w_valid &&waddr_hit&&lite_axi_awaddr_r[15:00]==16'h0014) begin
			video_algo_ctrl					<= sys_axi_wdata[31:0] 					;
		end else begin
			video_algo_ctrl					<= video_algo_ctrl						;	
		end
	end

	assign			data_r [6*32+:32]			= D0_18b20								;
	assign			data_r [7*32+:32]			= D1_18b20								;
	// æ—§ä»£ç 
	// assign			data_r [5*32+:32]			= D0_18b20						;
	// assign			data_r [6*32+:32]			= D1_18b20						;
	/*-------------------------------------------------------------------
	--å…¶å®ƒä¿¡å·å¤„ç†
	-------------------------------------------------------------------*/

	assign	sys_axi_awready				= 1'b1							;
	assign	sys_axi_wready				= 1'b1							;
	assign	sys_axi_arready				= 1'b1							;
	assign	sys_axi_rresp				= 2'b00							;
	assign	sys_axi_bresp				= 2'b00							;

	
	always @(posedge clk) begin
		if(sys_axi_bvalid && sys_axi_bready) begin
			sys_axi_bvalid				<= 1'b0							;
		end else if(lite_w_valid ==1'b1 && lite_aw_valid == 1'b1) begin
			sys_axi_bvalid				<= 1'b1							;
		end else begin
			sys_axi_bvalid				<= sys_axi_bvalid				;
		end
	end
	
	always @(posedge clk) begin
		if(lite_w_valid ==1'b1 && lite_aw_valid == 1'b1) begin
			lite_w_valid				<= 1'b0							;
		end else
		if(sys_axi_wvalid && sys_axi_wready) begin
			lite_w_valid				<= 1'b1							;
		end else begin
			lite_w_valid				<= lite_w_valid					;
		end
	end
	
	
	always @(posedge clk) begin
		if(lite_w_valid ==1'b1 && lite_aw_valid == 1'b1) begin
			lite_aw_valid				<= 1'b0							;
		end else
		if(sys_axi_awvalid && sys_axi_awready) begin
			lite_aw_valid				<= 1'b1							;
		end else begin
			lite_aw_valid				<= lite_aw_valid				;
		end
	end
	
	
	always @(posedge clk) begin
		if(sys_axi_awvalid && sys_axi_awready) begin
			lite_axi_awaddr_r			<= sys_axi_awaddr				;
		end else begin
			lite_axi_awaddr_r			<= lite_axi_awaddr_r			;
		end
	end
	
	always @(posedge clk) begin
		if(sys_axi_wvalid && sys_axi_wready) begin
			lite_axi_wdata_r			<= sys_axi_wdata				;
		end else begin
			lite_axi_wdata_r			<= lite_axi_wdata_r				;
		end
	end
	
	always @(posedge clk) begin
		if(sys_axi_arvalid && sys_axi_arready) begin
			lite_axi_araddr_r			<= sys_axi_araddr				;
		end else begin
			lite_axi_araddr_r			<= lite_axi_araddr_r			;
		end
	end
		
//==================================================================================================
//--å¯„å­˜å™¨è¯»å®ç°
 	wire			raddr_hit			= sys_axi_araddr[31:16]==base_addr[31:16]	;

	
	always@(posedge clk or posedge rst) begin
		if(rst) begin
			sys_axi_rdata 				<= 32'b0						;
		end else if(sys_axi_arvalid && sys_axi_arready) begin
			sys_axi_rdata				<= data_r[sys_axi_araddr[15:2]*32 +: 32]		;
		end else begin
			sys_axi_rdata				<= sys_axi_rdata;
		end
	end



	/*--------------------------------------------------------------------------------------
	--????????	--------------------------------------------------------------------------------------*/
	always @(posedge clk or posedge rst) begin
		if(rst) begin
			sys_axi_rvalid						<= 1'b0										;
		end else if(sys_axi_rvalid && sys_axi_rready) begin
			sys_axi_rvalid						<= 1'b0										;
		end else if(sys_axi_arvalid && sys_axi_arready) begin
			sys_axi_rvalid						<= 1'b1										;
		end else begin
			sys_axi_rvalid						<= sys_axi_rvalid							;
		end
	end

//	ila_axil ila_axil_ascb (
//		.clk									( clk										),
//		.probe0									( {
//													sys_axi_awaddr							,
//													sys_axi_awvalid							,
//													sys_axi_wvalid							,
//													sys_axi_wdata							,
//		 											sys_axi_awready     					,
//		 											sys_axi_wready    						,	
		 											
//													sys_axi_araddr							,
//													sys_axi_arvalid							,
//													sys_axi_rvalid							,
//													sys_axi_rdata							,
//		 											sys_axi_arready     					,
//		 											sys_axi_rready    						
		 											
//		 											})
//	);   




endmodule
