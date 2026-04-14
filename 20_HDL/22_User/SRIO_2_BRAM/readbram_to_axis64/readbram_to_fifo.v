`timescale 1ns/1ns
////////////////////////////////////////////////////////////////////////////////////////////////////
// Company			: ZHTY
// Engineer			: wangzhen
// Create Date		: 2025/7/2 13:32:38
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
/*
读取mif文件，将每行写入fifo的单个地址，不支持depth为1
*/
////////////////////////////////////////////////////////////////////////////////////////////////////

module readbram_to_fifo #(
    parameter		DATA_WIDTH     				= 65        								,
    parameter		B_RAM_WIDTH     			= 16        								,
    parameter		B_RAM_DEPTH  				= 32'h64000	  								,	// 32'h64000：200行
    parameter		P_LINE_DEPTH     			= 200											// bram中可以存的视频行数	      	
) (
	input										clk											,
	input										rst_n										,
//==================================================================================================
//--视频bram接口--------------------------	
    input		  	[clogb2(B_RAM_DEPTH-1)-1:0] bram_line_cur_w   							,	// 当前bram写入行位置 
    input      					 				bram_line_cur_w_en   						, 	//	1 :表示成功写入第bram_line_cur_w行数据在bram中,可用于触发状态机工作
    
	output	wire	[clogb2(P_LINE_DEPTH-1):0]	bram_line_num_addr							,	// 每段bram地址对应的行号地址
    input      		[12-1:0] 					bram_line_num								,	// 每段bram地址对应的行号 , bram_line_num_addr*32'h0~bram_line_num_addr*32'h800对应的行号,具体列号对应当前行的不同地址
   
    output		  	[clogb2(B_RAM_DEPTH-1)-1:0] bram_addrb   								,	// 16bit位宽的bram地址
    input		  	[B_RAM_WIDTH-1:0]           bram_doutb   								,     

    output 	reg 								fifo_wr_en									,   // FIFO写使能
    output 	reg 	[DATA_WIDTH-1:0] 			fifo_din									, 	// FIFO数据输入
    input 	wire 								fifo_almost_full       							 // FIFO满标志
);
//	data_bit16_check	check_r_wfifo(
//		.clk									( clk								),	
//        .rst                                  	( ~rst_n                                     ), 
                                                                                               
//		.rx_dat									( fifo_din			[63:0]	),	
//        //.s_axis_tuser                           ( srio_s_axis_tuser		[1*64 +: 64]		), 
//		.rx_en									( fifo_wr_en &&(~fifo_almost_full) ),	
//		.rx_last								( fifo_din    [64]	));

	reg											Video_pro_star		= 1'b0					;	// 上电后bram首次半满再开始视频处理
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin	Video_pro_star 		<= 1'b0										;
        end else  if(bram_line_cur_w_en && bram_line_cur_w>= P_LINE_DEPTH/2	)	begin	
        	Video_pro_star						<= 1'b1										;
        end else begin	
        	Video_pro_star						<= Video_pro_star							;
        end
    end

    //  The following function calculates the address width based on specified RAM depth
    function integer clogb2;
        input integer depth;
        for (clogb2=0; depth>0; clogb2=clogb2+1)
            depth = depth >> 1;
    endfunction
    // 地址计数器
    reg 			[$clog2(B_RAM_DEPTH):0] 	addr_cnt									;
    reg 			[1:0] 						addr_cnt_last2								;

    // 主状态机：IDLE和WRITE两种状态
	localparam 									S_IDLE_M  		= 4'b0001					;
    localparam	 								S_W_HEAD_M 		= 4'b0010					;
    localparam	 								S_GET_64_M 		= 4'b0100					;
    localparam	 								S_W_DATA_M 		= 4'b1000					;

    reg 			[3:0]						S_CM, S_NM	,S_LM							;

    // 状态寄存器
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin	S_CM 				<= S_IDLE_M									;
        end else 	begin	S_CM 				<= S_NM										;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin	S_LM 				<= S_IDLE_M									;
        end else 	begin	S_LM 				<= S_CM										;
        end
    end
    
    
/*
每行 2048个16bit
每包	256/8=128个16bit

每行16包
*/
    reg		  		[clogb2(B_RAM_DEPTH-1)-1:0] bram_line_star   							;	// 本次处理的行起始 

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin	
        	bram_line_star 						<= 'b0										;
        end else  if(bram_line_cur_w_en)	begin	
        	if(bram_line_cur_w>= P_LINE_DEPTH/2	)begin
        		bram_line_star 					<= bram_line_cur_w - P_LINE_DEPTH/2			;
        	end else begin
        		bram_line_star 					<= bram_line_cur_w + P_LINE_DEPTH/2			;
        	end		
        end else begin		
        	bram_line_star 						<= bram_line_star							;
        end
    end
//
//    reg		  		[clogb2(B_RAM_DEPTH-1)-1:0] bram_line_star   							;	// 本次处理的行起始 
//
////    always @(*) begin
////        	if(bram_line_cur_w>= P_LINE_DEPTH/2	)begin
////        		bram_line_star 					<= bram_line_cur_w - P_LINE_DEPTH/2			;
////        	end else begin
////        		bram_line_star 					<= bram_line_cur_w + P_LINE_DEPTH/2			;
////        	end		
////    end
//
//
//
////	assign bram_line_star 						= (bram_line_cur_w >= P_LINE_DEPTH/2) ? 
////                        							(bram_line_cur_w - P_LINE_DEPTH/2) : 
////                        							(bram_line_cur_w + P_LINE_DEPTH/2);

	
	//wire	[11:0]	video_line_star				= bram_line_num[bram_line_star*12+:12]		;

	assign			bram_line_num_addr			= bram_line_star							;
	wire	[11:0]	video_line_star				= bram_line_num								;


//	wire	[31:0]	srio_addr					= (video_line_star<<12) + (addr_cnt <<1)&32'hffff_ff00	;

	wire	[31:0]	srio_addr					= {video_line_star , addr_cnt [10:7],8'h00}		;	// 等效 (video_line_star<<12) + (addr_cnt <<1)&32'hffff_ff00	

//	assign			bram_addrb					= (bram_line_star<<11) + addr_cnt			;
	assign			bram_addrb					= {bram_line_star, addr_cnt	[10:0]	}	;
	
	
	
	reg											bram_line_cur_w_en_d1		= 'b0				;
    always @(posedge clk ) 						bram_line_cur_w_en_d1		<=bram_line_cur_w_en;	// 打一拍等待bram_line_num准备好

    // 状态转移逻辑
    always @(*) begin
        case (S_CM)
            S_IDLE_M:
                if (bram_line_cur_w_en_d1&&Video_pro_star)	S_NM 			= S_W_HEAD_M				;
                else							S_NM 			= S_IDLE_M					;
            S_W_HEAD_M:
                if ( ~fifo_almost_full)   		S_NM 			= S_GET_64_M				;
                else 							S_NM 			= S_W_HEAD_M				; 	// 保持当前状态，等待FIFO有空间
            S_GET_64_M:
                if (addr_cnt[1:0] == 2'h3)   	S_NM 			= S_W_DATA_M				;
                else 							S_NM 			= S_GET_64_M				;
            S_W_DATA_M:
                if (addr_cnt==2048 	&~fifo_almost_full)S_NM 			= S_IDLE_M					;	// 满一行
                else if (addr_cnt[6:0]==0&~fifo_almost_full)S_NM 		= S_W_HEAD_M				;	// 满一包srio
                else if (fifo_almost_full)				S_NM 			= S_W_DATA_M				; 	// 保持当前状态，等待FIFO有空间
                else 							S_NM 			= S_GET_64_M				;

            default:							S_NM 			= S_IDLE_M					;
        endcase
    end


    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fifo_wr_en 							<= 1'b0										;
            fifo_din 							<= {DATA_WIDTH{1'b0}}						;
            addr_cnt 							<= {$clog2(B_RAM_DEPTH){1'b0}}				;
            addr_cnt_last2 						<= 'b0										;
        end else begin
            case (S_CM)
                S_IDLE_M: begin
                    	fifo_wr_en 				<= 1'b0										;
                        addr_cnt 				<= {$clog2(B_RAM_DEPTH){1'b0}}				;
            			addr_cnt_last2 			<= 'b0										;
                end
                S_W_HEAD_M: begin
                	if (fifo_almost_full) begin	
                        fifo_wr_en 				<= fifo_wr_en								; 	// FIFO满时暂停写入
                        addr_cnt 				<= addr_cnt									;
            			addr_cnt_last2 			<= addr_cnt_last2							;
                    end else begin
                    	fifo_wr_en 				<= 1'b1										;
                        addr_cnt 				<= addr_cnt	+ 1								;
            			addr_cnt_last2 			<= addr_cnt[1:0]							;
                    end    
                        fifo_din 				<= {1'b0,32'h0060_2000,srio_addr} 			;
                end
            	S_GET_64_M:begin
                        fifo_wr_en 				<= 	1'b0									; 	// FIFO未满时写入数据
                        addr_cnt 				<= addr_cnt + 1'b1							;
            			addr_cnt_last2 			<= addr_cnt[1:0]							;
                        fifo_din  [(addr_cnt_last2[1:0])*16+:16]<= bram_doutb				;
                end
                S_W_DATA_M: begin
                    if (fifo_almost_full ) begin		//| addr_cnt == 2048
                        addr_cnt 				<= addr_cnt									;
            			addr_cnt_last2 			<= addr_cnt_last2							;
                        fifo_wr_en 				<= fifo_wr_en								; 	// FIFO满时暂停写入
                    end else begin
                        fifo_wr_en 				<= fifo_almost_full   ? 1'b0		:	1'b1; 	// FIFO未满时写入数据
                        addr_cnt 				<= fifo_almost_full || S_NM==S_W_HEAD_M  ? addr_cnt	:	addr_cnt + 1'b1;	//  此处根据需要修改跳转范围
            			addr_cnt_last2 			<= addr_cnt[1:0]							;
                    end 
                    
                    fifo_din  [DATA_WIDTH-1]				<= S_NM==S_W_HEAD_M  | S_NM==S_IDLE_M    ? 1'b1		: 	1'b0;                    
                    fifo_din  [addr_cnt_last2[1:0]*16+:16]	<= S_LM==S_GET_64_M ? bram_doutb	: fifo_din  [addr_cnt_last2[1:0]*16+:16]					;

                    
                end

            endcase
        end
    end


//	wire	[11:0]	video_line_star_pre3 		= bram_line_num[(bram_line_star-3)*12+:12]		;	// 通过DEBUG发现，该信号在1个时钟周期无法准备好
//	wire	[11:0]	video_line_star_pre2 		= bram_line_num[(bram_line_star-2)*12+:12]		;	// 通过DEBUG发现，该信号在1个时钟周期无法准备好
//	wire	[11:0]	video_line_star_pre1 		= bram_line_num[(bram_line_star-1)*12+:12]		;	// 通过DEBUG发现，该信号在1个时钟周期无法准备好
//
//	wire	[11:0]	video_line_star_n1 	    		= bram_line_num[(bram_line_star+1)*12+:12]		;	// 通过DEBUG发现，该信号在1个时钟周期无法准备好
//	wire	[11:0]	video_line_star_n2 	    		= bram_line_num[(bram_line_star+2)*12+:12]		;	// 通过DEBUG发现，该信号在1个时钟周期无法准备好





//		ila_test	ila_fifo_axis(
//		.clk                        			( clk								),
//		.probe0                                  ( {
//		   	addr_cnt									,
//					addr_cnt_last2								,
//	bram_line_star				,

//srio_addr				,


		
//    bram_line_cur_w   							,	// 当前bram写入行位置 
//    bram_line_cur_w_en   						, 	//	1 :表示成功写入第bram_line_cur_w行数据在bram中
//    bram_addrb   								,	// 16bit位宽的bram地址
//    bram_doutb   								,     

//    fifo_wr_en									,   // FIFO写使能
//    fifo_din									, 	// FIFO数据输入
//    fifo_almost_full       							,    // FIFO满标志
    
//    S_CM,
    
    
//    check_r_wfifo.frame_addr_err    [0]
    

//																							})//,
////	.probe1                                  (video_line_star_pre3 ),																						
////	.probe2                                  (video_line_star_pre2 ),	
////	.probe3                                  (video_line_star_pre1 ),																						
////	.probe4                                  (video_line_star 		),	
////	.probe5                                  (video_line_star_n1 	),																						
////	.probe6                                  (video_line_star_n2 	)
																						

//	);

endmodule