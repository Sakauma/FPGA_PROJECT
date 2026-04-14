`timescale 1ns/1ns
//////////////////////////////////////////////////////////////////////////////////
// Company:			ZHTY
// Engineer:		ZhengYunLong
//
// Create Date:		2018/6/27 19:10:38
// Design Name:		
// Module Name:		ic_axiw_burst
// Project Name:
// Target Devices:	XC7k325T
// Tool Versions: 	Vivado 2016.1
// Description:
//		模块实现基于AXI4接口的Burst写操作
// Dependencies:
//		
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////
module srio_v_fifo_to_bram_wb#(
    parameter		A_RAM_WIDTH     			= 128        								,
    parameter		A_RAM_DEPTH     			= 8192      								,
    parameter		B_RAM_WIDTH     			= 8        								    , 
    parameter		B_RAM_DEPTH     			= A_RAM_WIDTH*A_RAM_DEPTH/B_RAM_WIDTH      	, 
    parameter		P_LINE_DEPTH     			= A_RAM_DEPTH/512				      		
	) (
//==================================================================================================
//--Comman Interface
	input										clk											,
	input										rst											,
//==================================================================================================
//--bram写接口
    output  wire                                bram_wea     								,   
    output  wire    [clogb2(A_RAM_DEPTH-1)-1:0] bram_addra   								,   
    output  wire    [A_RAM_WIDTH-1:0]           bram_dina    								,   
                                                   
	input										bram_line_clk								,
	input										bram_line_rstn								,

                                                                    		                    
    output  reg    [clogb2(B_RAM_DEPTH-1)-1:0]  bram_line_cur_w_o   						,   
    output  wire    					 		bram_line_cur_w_en_o   						, 	//	1 :表示成功写入第bram_line_cur_w行数据在bram中
    
	input	wire	[clogb2(P_LINE_DEPTH-1):0]	bram_line_num_addr							,	// 每段bram地址对应的行号地址
    output      	[12-1:0] 					bram_line_num								,	// 每段bram地址对应的行号 , bram_line_num_addr*32'h0~bram_line_num_addr*32'h800对应的行号,具体列号对应当前行的不同地址
//==================================================================================================
//--写请求接口
	input										m_axiw_req									,
	output	wire								m_axiw_gnt									,
	input			[10:0]						m_axiw_len64								,
	input			[31:0]						m_axiw_addr									,
	input			[7:0]						m_axiw_wstrb								,	//仅当最后一个64比特数据有效，用于OnlyOne模式
	
	input			[63:0]						m_axiw_fifo_rdata							,
	input										m_axiw_fifo_empty							,
	output										m_axiw_fifo_rden
	);
    //  The following function calculates the address width based on specified RAM depth
    function integer clogb2;
        input integer depth;
        for (clogb2=0; depth>0; clogb2=clogb2+1)
            depth = depth >> 1;
    endfunction			
	
    wire    		[clogb2(B_RAM_DEPTH-1)-1:0] bram_line_cur_w   							;   
    reg    					 					bram_line_cur_w_en   						; 	//	1 :表示成功写入第bram_line_cur_w行数据在bram中
    
   	wire    		[clogb2(B_RAM_DEPTH-1)-1:0] bram_line_cur_w_o_pre   					;

	always @(posedge bram_line_clk) begin
		bram_line_cur_w_o						<= bram_line_cur_w_o_pre					; 
	end

    async_fifo#(
        .AF                 					( 1                 						),
        .DATA_BITS          					( clogb2(B_RAM_DEPTH-1)                 	),    //但采用ip核时注意同步更新
        .DEPTH_BITS         					( 4                 						),
        .SHOW_AHEAD         					( 0                 						),
        .RAM_STYLE          					( "distributed"    							)
    )async_fifo(
        // write
        .wr_clk             					( clk           							),
        .wr_rstn            					( ~rst           							),
        .wr_en              					( bram_line_cur_w_en        				),
        .din                					( bram_line_cur_w      						),
        .wr_data_count      					(      										),
        .prog_full          					(          									),
        .full               					(                 					        ),

        // read
        .valid          					   	( bram_line_cur_w_en_o         				),
        .rd_clk             					( bram_line_clk            					),
        .rd_rstn            					( bram_line_rstn          					),
        .rd_en              					( 1'b1        								),
        .dout               					( bram_line_cur_w_o_pre     				),
        .rd_data_count      					(      										),
        .pre_empty          					(          									),
        .empty              					(       									));
	
	
	reg				[7:0]						M_AXI_AWLEN						= 0			;
	wire			[63:0]						M_AXI_WDATA									;
	wire										M_AXI_WLAST									;
	wire										M_AXI_WVALID								;
	wire										M_AXI_WREADY								;	
	
	assign			M_AXI_WREADY				= 1'b1										;
	
	
	assign			bram_dina					= M_AXI_WDATA								;
//==================================================================================================
//--参数定义
	localparam		[10:0]						PR_AXI_BURST				= 11'd64		;

//==================================================================================================
//--信号定义
	(* fsm_safe_state	=	"reset_state"*)reg				[5:0]						S_AXI_CM									;
	reg				[5:0]						S_AXI_NM									;
	
	
	reg											axi_last					= 0 			;
	reg				[10:0]						axi_cnt						= 0				;
	reg				[10:0]						axi_len						= 0				;

	localparam									S_AXI_IDLE_M				= 6'b00_0001	;
	localparam									S_AXI_SLICE_M				= 6'b00_0010	;
	localparam									S_AXI_AW_M					= 6'b00_0100	;
	localparam									S_AXI_W_M					= 6'b00_1000	;
	localparam									S_AXI_B_M					= 6'b01_0000	;
	localparam									S_AXI_DONE_M				= 6'b10_0000	;
	
	
	reg				[127:0]						S_AXI_CM_acii								;

	always @(*) begin
        case(S_AXI_CM)
           S_AXI_IDLE_M	      : S_AXI_CM_acii<= "S_AXI_IDLE_M	";
           S_AXI_SLICE_M	  : S_AXI_CM_acii<= "S_AXI_SLICE_M	";
           S_AXI_AW_M		  : S_AXI_CM_acii<= "S_AXI_AW_M		";
           S_AXI_W_M		  : S_AXI_CM_acii<= "S_AXI_W_M		";
           S_AXI_B_M		  : S_AXI_CM_acii<= "S_AXI_B_M		";      
           S_AXI_DONE_M	      : S_AXI_CM_acii<= "S_AXI_DONE_M	";
            default               : S_AXI_CM_acii<= "defaule";
        endcase
	end	
//==================================================================================================
//--状态机实现
	always @(posedge clk or posedge rst) begin
		if(rst) begin
			S_AXI_CM							<= S_AXI_IDLE_M								;
		end else begin
			S_AXI_CM							<= S_AXI_NM									;
		end
	end
	
	always @(*) begin
		S_AXI_NM								= 'bx										;
		case(S_AXI_CM)
			S_AXI_IDLE_M						: begin
				if(m_axiw_req) begin
					S_AXI_NM					= S_AXI_SLICE_M								;
				end else begin
					S_AXI_NM					= S_AXI_IDLE_M								;
				end
			end
			S_AXI_SLICE_M						: begin
				S_AXI_NM						= S_AXI_W_M								;
			end
			S_AXI_W_M							: begin
				if(M_AXI_WREADY && M_AXI_WVALID && M_AXI_WLAST) begin
					S_AXI_NM					= S_AXI_B_M									;
				end else begin
					S_AXI_NM					= S_AXI_W_M									;
				end
			end
			S_AXI_B_M							: begin
					if(axi_last) begin
						S_AXI_NM				= S_AXI_DONE_M								;
					end else begin
						S_AXI_NM				= S_AXI_SLICE_M								;
					end
			end
			S_AXI_DONE_M						: begin
				S_AXI_NM						= S_AXI_IDLE_M								;
			end
			default								: begin
				S_AXI_NM						= S_AXI_IDLE_M								;
			end
		endcase
	end
	
	/*--------------------------------------------------------------------------------------
	--AXI_LEN实现
	--------------------------------------------------------------------------------------*/	
	always @(posedge clk) begin
		case(S_AXI_CM)
			S_AXI_IDLE_M						: begin
				axi_len							<= m_axiw_len64								;
				axi_last						<= 1'b0										;
			end
			S_AXI_SLICE_M						: begin
				if(axi_len>PR_AXI_BURST) begin
					axi_len						<= axi_len - PR_AXI_BURST					;
					axi_last					<= 1'b0										;
				end else begin
					axi_len						<= axi_len									;
					axi_last					<= 1'b1										;
				end
			end
			S_AXI_DONE_M						: begin
				axi_len							<= 11'b0									;
				axi_last						<= 1'b0										;
			end
			default								: begin
				axi_len							<= axi_len									;
				axi_last						<= axi_last									;
			end
		endcase
	end
	
	/*--------------------------------------------------------------------------------------
	--AXI_CNT计数器实现
	--------------------------------------------------------------------------------------*/	
	always @(posedge clk) begin
		if(S_AXI_CM==S_AXI_W_M) begin
			if(M_AXI_WVALID && M_AXI_WREADY) begin
				axi_cnt							<= axi_cnt + 1'b1							;
			end else begin
				axi_cnt							<= axi_cnt									;
			end
		end else begin
			axi_cnt								<= 11'b0									;
		end
	end
	
//==================================================================================================
//--M_AXI_*信号实现

	
	always @(posedge clk) begin
		case(S_AXI_CM)
			S_AXI_IDLE_M						: begin
				M_AXI_AWLEN						<= 8'b0										;
			end
			S_AXI_SLICE_M						: begin
				if(axi_len>PR_AXI_BURST) begin
					M_AXI_AWLEN					<= PR_AXI_BURST - 1'b1						;
				end else begin
					M_AXI_AWLEN					<= axi_len - 1'b1							;
				end
			end
			default								: begin
				M_AXI_AWLEN						<= M_AXI_AWLEN								;
			end
		endcase
	end
	
	assign	M_AXI_AWVALID						= (S_AXI_CM==S_AXI_AW_M)?1'b1:1'b0			;
	
	assign	M_AXI_WVALID						= (S_AXI_CM==S_AXI_W_M)?~m_axiw_fifo_empty:1'b0;
	assign	M_AXI_WDATA							= m_axiw_fifo_rdata							;
	assign	M_AXI_WLAST							= M_AXI_WVALID && axi_cnt==M_AXI_AWLEN		;

	
	assign	m_axiw_fifo_rden					= M_AXI_WVALID && M_AXI_WREADY				;
	assign	m_axiw_gnt							= (S_AXI_CM==S_AXI_DONE_M)?1'b1:1'b0		;


//video_bram	
	reg				[clogb2(B_RAM_DEPTH-1)-1:0]	bram_w_line_cnt			= 'b0				;
	reg											bram_w_line_cnt_wr		= 'b0				;

	
	assign			bram_wea					= M_AXI_WVALID&M_AXI_WREADY					;
	wire		[15:0]		m_axiw_line_cur_w	= m_axiw_addr>>12							;	// 行

	wire		[15:0]		bram_w_8bytes_cnt	= (m_axiw_addr[11:0]>>3)+ axi_cnt[4:0]		;	// 列的8字节位置	

	wire		[3:0]		bram_w_srio_line_cnt= m_axiw_addr[11:8]							;	// 每列中srio包的计数
		
	assign		bram_addra						= (bram_w_line_cnt<<9) + bram_w_8bytes_cnt	;

	assign		bram_line_cur_w					= bram_w_line_cnt							;
	
	always @(posedge clk or posedge rst) begin
		if(rst) begin
			bram_w_line_cnt						<= 'b0										;
			bram_line_cur_w_en					<= 1'b0										;
			//bram_line_cur_w						<= 'b0										;
		end else if (M_AXI_WVALID&&M_AXI_WREADY&&M_AXI_WLAST&&bram_w_srio_line_cnt==15)begin
			bram_line_cur_w_en					<= 1'b1										;
			//bram_line_cur_w						<= bram_w_line_cnt							;
			if(bram_w_line_cnt<(P_LINE_DEPTH-1))begin
				bram_w_line_cnt					<= bram_w_line_cnt+1						;
			end else begin
				bram_w_line_cnt					<= 'b0										;
			end		
		end else begin
				bram_w_line_cnt					<= bram_w_line_cnt							;
				bram_line_cur_w_en				<= 1'b0										;
				//bram_line_cur_w					<= bram_line_cur_w							;
		end
	end
//genvar ii;
//generate for(ii=0;ii<P_LINE_DEPTH;ii=ii+1)
//begin : bram_line_num_write
//	always @(posedge clk or posedge rst) begin
//		if(rst) begin
//			bram_line_num[ii*12+:12]			<= 'b0										;
//		end else if (M_AXI_WVALID&&M_AXI_WREADY&&M_AXI_WLAST&&bram_w_srio_line_cnt==15&&bram_w_line_cnt==ii)begin
//			bram_line_num[ii*12+:12]			<= m_axiw_line_cur_w						;
//		end else begin
//			bram_line_num[ii*12+:12]			<= bram_line_num[ii*12+:12]					;
//		end
//	end
//end endgenerate	

	always @(posedge clk or posedge rst) begin
		if(rst) begin
			bram_w_line_cnt_wr					<= 1'b0										;
		end else if (M_AXI_WVALID&&M_AXI_WREADY&&M_AXI_WLAST&&bram_w_srio_line_cnt==14)begin
			bram_w_line_cnt_wr					<= 1'b1										;
		end else begin
			bram_w_line_cnt_wr					<= 1'b0										;
		end
	end



	sdp_drw_ram	#(
		.A_RAM_WIDTH        					( 12         								),
	    .A_RAM_DEPTH        					( P_LINE_DEPTH    							),
	    .B_RAM_WIDTH        					( 12    							       	),
	    .RAM_STYLE        						( "distributed"      						),
	    .RAM_OUT_REG_EN     					( "DISABLE" 								)
	) u_video_addr_ram(            					                							
	    .clka                					( clk           							),
	                        					
	    .wea                					( bram_w_line_cnt_wr    					),
	    .addra              					( bram_w_line_cnt    						),
	    .dina               					( m_axiw_line_cur_w    						),
	                       
	    .clkb                					( bram_line_clk                             ),
	    .rstb                					( ~bram_line_rstn                           ),

	    .enb                					( 1'b1		                                ),	// 待修改
	    .addrb              					( bram_line_num_addr               			),
	    .doutb              					( bram_line_num               				),
	    .regceb             					( 1'b1                                  	)
	);
	
	







endmodule