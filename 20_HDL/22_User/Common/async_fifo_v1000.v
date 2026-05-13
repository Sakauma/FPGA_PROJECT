// ============================================================================
// 新增维护说明
// 作者          : Egor Izmaylov
// 文件职责      : 当前文件为手工维护源码，具体职责见模块名、端口和上层实例化。
// 维护边界      : 只追加说明性注释；Vivado/IP 生成物和第三方支撑代码不在此处手改。
// 修改约束      : 功能改动需同步更新仿真、综合结果和相关文档。
// ============================================================================
/////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2018 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : MiaoJiawang jiawang.miao@magicip.com.cn
// Create Date       : 2019-10-05  07:54:38
// Design Name       :
// Module Name       : async_fifo_v1000.v
// Project Name      :
// Target Devices    :
// Tool versions     :
// Description       :
// Editor            : Gvim, tab size (4)
// Dependencies      :
// Revision          : 1.00
//		Revision 1.00 - File Created by		: MiaoJiawang
//		Description							:
//
//		Revision 1.01 - File Modified by	:
//		Description							:
//
// Additional Comments:
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
//////////////////////////////////////////////////////////////////////////////////
//`timescale 1ns/1ps

module async_fifo#(
 	parameter   	AF          				= 1        		 							,
 	parameter   	DATA_BITS   				= 8        		 							,
 	parameter   	DEPTH_BITS  				= 8        		 							,
 	parameter   	SHOW_AHEAD  				= 0        		 							,
 	parameter   	RAM_STYLE   				= "block"
)(
	// write
	input   wire                        		wr_clk          							,
	input   wire                        		wr_rstn         							,
	input   wire                        		wr_en           							,
	input   wire    [DATA_BITS-1:0]     		din             							,
	output  reg     [DEPTH_BITS:0]      		wr_data_count ='b0  						,
	output  reg                         		prog_full     = 1'b0  						,
	output  reg                         		full          ='b0  						,

	// read
	input   wire                        		rd_clk          							,
	input   wire                        		rd_rstn         							,
	input   wire                        		rd_en           							,
	output  reg     [DATA_BITS-1:0]     		dout            ='b0        				,
	output  reg                         		valid           ='b0						,
	output  reg     [DEPTH_BITS:0]      		rd_data_count   ='b0						,
	output  wire                        		pre_empty       							,
	output  reg                         		empty			=1'b1
    );

    //------------------------Parameter----------------------
    localparam 		DEPTH 						= 1 << DEPTH_BITS							;

    //------------------------Local signal-------------------
    (* ram_extract="yes", ram_style = RAM_STYLE *)
	reg     		[DATA_BITS-1:0]     		mem [0:DEPTH-1]      						;

	integer 									ram_index									;
	initial
           for (ram_index = 0; ram_index < DEPTH; ram_index = ram_index + 1)
                    mem[ram_index] 				= {DATA_BITS{1'b0}}							;

	wire    		                    		rstn                						;
	wire    		                    		wr_sync_rstn        						;
	wire    		                    		rd_sync_rstn        						;

	reg     		[3:0]               		wr_sync_rstn_r      						;
	reg     		[3:0]               		rd_sync_rstn_r      						;

	wire    		                    		full_next           						;
	wire    		                    		empty_next          						;
	reg     		[DEPTH_BITS:0]      		wr_addr_bin         						;
	reg     		[DEPTH_BITS:0]      		rd_addr_bin         						;
	wire    		[DEPTH_BITS-1:0]    		wr_addr             						;
	wire    		[DEPTH_BITS-1:0]    		rd_addr             						;
	wire    		[DEPTH_BITS:0]      		wr_addr_bin_next    						;
	wire    		[DEPTH_BITS:0]      		rd_addr_bin_next    						;
	wire    		[DEPTH_BITS:0]      		wr_addr_gray_next   						;
	wire    		[DEPTH_BITS:0]      		rd_addr_gray_next   						;
	reg     		[DEPTH_BITS:0]      		wr_addr_gray_sync0  						;
	reg     		[DEPTH_BITS:0]      		rd_addr_gray_sync0  						;
	reg     		[DEPTH_BITS:0]      		wr_addr_gray_sync1  						;
	reg     		[DEPTH_BITS:0]      		rd_addr_gray_sync1  						;
	reg     		[DEPTH_BITS:0]      		wr_addr_gray_sync2  						;
	reg     		[DEPTH_BITS:0]      		rd_addr_gray_sync2  						;
	wire    		[DEPTH_BITS:0]      		wr_addr_bin_sync    						;
	wire    		[DEPTH_BITS:0]      		rd_addr_bin_sync    						;

`ifndef SYNTHESIS
    // 新代码：Egor Izmaylov
    // 仅用于 RTL 仿真：XSim 中主复位 always 由同步后的 reset 触发，若同步链从 X 直接进入 1，
    // 指针和计数器可能保持 X，进而把 prog_full/empty 传成 X。硬件综合不使用此初始化块。
    initial begin
        prog_full           = 1'b0;
        full                = 1'b0;
        empty               = 1'b1;
        valid               = 1'b0;
        dout                = {DATA_BITS{1'b0}};
        wr_data_count       = {DEPTH_BITS+1{1'b0}};
        rd_data_count       = {DEPTH_BITS+1{1'b0}};
        wr_sync_rstn_r      = 4'd0;
        rd_sync_rstn_r      = 4'd0;
        wr_addr_bin         = {DEPTH_BITS+1{1'b0}};
        rd_addr_bin         = {DEPTH_BITS+1{1'b0}};
        wr_addr_gray_sync0  = {DEPTH_BITS+1{1'b0}};
        wr_addr_gray_sync1  = {DEPTH_BITS+1{1'b0}};
        wr_addr_gray_sync2  = {DEPTH_BITS+1{1'b0}};
        rd_addr_gray_sync0  = {DEPTH_BITS+1{1'b0}};
        rd_addr_gray_sync1  = {DEPTH_BITS+1{1'b0}};
        rd_addr_gray_sync2  = {DEPTH_BITS+1{1'b0}};
    end
`endif

// synthesis translate_off
    initial begin
        prog_full           = 1'b0;
        full                = 1'b0;
        empty               = 1'b1;
        valid               = 1'b0;
        dout                = {DATA_BITS{1'b0}};
        wr_data_count       = {DEPTH_BITS+1{1'b0}};
        rd_data_count       = {DEPTH_BITS+1{1'b0}};
        wr_sync_rstn_r      = 4'd0;
        rd_sync_rstn_r      = 4'd0;
        wr_addr_bin         = {DEPTH_BITS+1{1'b0}};
        rd_addr_bin         = {DEPTH_BITS+1{1'b0}};
        wr_addr_gray_sync0  = {DEPTH_BITS+1{1'b0}};
        wr_addr_gray_sync1  = {DEPTH_BITS+1{1'b0}};
        wr_addr_gray_sync2  = {DEPTH_BITS+1{1'b0}};
        rd_addr_gray_sync0  = {DEPTH_BITS+1{1'b0}};
        rd_addr_gray_sync1  = {DEPTH_BITS+1{1'b0}};
        rd_addr_gray_sync2  = {DEPTH_BITS+1{1'b0}};
    end
// synthesis translate_on

   //------------------------Instantiation------------------

    //------------------------Body---------------------------

    assign  		rstn        				= wr_rstn & rd_rstn 						;

    assign  		pre_empty   				= (rd_data_count >= 'd2)?1'b0:1'b1			;
    assign  		full_next   				= (wr_addr_gray_next == (rd_addr_gray_sync2 ^ (2'b11 << (DEPTH_BITS - 1))));
    assign  		empty_next  				= (rd_addr_gray_next == wr_addr_gray_sync2);

    assign  		wr_addr     				= wr_addr_bin[DEPTH_BITS-1:0]				;
    generate
        if (SHOW_AHEAD) begin : gen_show_ahead_raddr
            assign  rd_addr  					= rd_addr_bin_next[DEPTH_BITS-1:0]			;
        end else begin : gen_normal_raddr
            assign  rd_addr  					= rd_addr_bin     [DEPTH_BITS-1:0]			;
        end
    endgenerate

    assign  		wr_addr_bin_next    		= (~full  & wr_en)? wr_addr_bin + 1'b1 : wr_addr_bin	;
    assign  		rd_addr_bin_next    		= (~empty & rd_en)? rd_addr_bin + 1'b1 : rd_addr_bin	;

    assign  		wr_addr_gray_next   		= wr_addr_bin_next ^ (wr_addr_bin_next >> 1)			;
    assign  		rd_addr_gray_next   		= rd_addr_bin_next ^ (rd_addr_bin_next >> 1)			;

    // gray to bin
    assign wr_addr_bin_sync[DEPTH_BITS] 		= wr_addr_gray_sync2[DEPTH_BITS]			;
    assign rd_addr_bin_sync[DEPTH_BITS] 		= rd_addr_gray_sync2[DEPTH_BITS]			;

    genvar i;
    generate
        for (i = 0; i < DEPTH_BITS; i = i + 1) begin : gen_gray_to_bin
            assign  wr_addr_bin_sync[i] 		= wr_addr_gray_sync2[i] ^ wr_addr_bin_sync[i+1]			;
            assign  rd_addr_bin_sync[i] 		= rd_addr_gray_sync2[i] ^ rd_addr_bin_sync[i+1]			;
        end
    endgenerate

    assign  		wr_sync_rstn        		= wr_sync_rstn_r[3]							;

    always @(posedge wr_clk or negedge rstn) begin
        if (~rstn)	wr_sync_rstn_r  			<= 4'd0 									;
        else  		wr_sync_rstn_r  			<= {wr_sync_rstn_r[2:0],1'b1}				;
    end

    // @ wr_clk domain
    // full, wr_addr_bin, wr_addr_gray_sync0, rd_addr_gray_sync1, rd_addr_gray_sync2
    always @(posedge wr_clk or negedge wr_sync_rstn) begin
        if (~wr_sync_rstn) begin
            prog_full           				<= 1'b0										;
            full                				<= 1'b0										;
            wr_addr_bin         				<= 1'b0										;
            wr_addr_gray_sync0  				<= 1'b0										;
            rd_addr_gray_sync1  				<= 1'b0										;
            rd_addr_gray_sync2  				<= 1'b0										;
        end else begin
            prog_full           				<= (wr_data_count >= (2**DEPTH_BITS -1 -AF))?1'b1:1'b0;
            full                				<= full_next								;
            wr_addr_bin         				<= wr_addr_bin_next							;
            wr_addr_gray_sync0  				<= wr_addr_gray_next						;
            rd_addr_gray_sync1  				<= rd_addr_gray_sync0						;
            rd_addr_gray_sync2  				<= rd_addr_gray_sync1						;
        end
    end

    // mem
    always @(posedge wr_clk) begin
        if (~full & wr_en) 	mem[wr_addr] 		<= din										;
    end

    // wr_data_count
    always @(posedge wr_clk or negedge wr_sync_rstn) begin
        if (~wr_sync_rstn)	wr_data_count 		<= 1'b0										;
        else				wr_data_count 		<= wr_addr_bin_next - rd_addr_bin_sync		;
    end

    assign  		rd_sync_rstn    			= rd_sync_rstn_r[3] 						;

    always @(posedge rd_clk or negedge rstn) begin
        if (~rstn)	rd_sync_rstn_r  			<= 4'd0 									;
        else 		rd_sync_rstn_r  			<= {rd_sync_rstn_r[2:0],1'b1}				;
    end

    // @ rd_clk domain
    // empty, rd_addr_bin, rd_addr_gray_sync0, wr_addr_gray_sync1, wr_addr_gray_sync2
    always @(posedge rd_clk or negedge rd_sync_rstn) begin
        if (~rd_sync_rstn) begin
            empty              					<= 1'b1										;
            rd_addr_bin        					<= 1'b0										;
            rd_addr_gray_sync0 					<= 1'b0										;
            wr_addr_gray_sync1 					<= 1'b0										;
            wr_addr_gray_sync2 					<= 1'b0										;
        end else begin
            empty              					<= empty_next								;
            rd_addr_bin        					<= rd_addr_bin_next							;
            rd_addr_gray_sync0 					<= rd_addr_gray_next						;
            wr_addr_gray_sync1 					<= wr_addr_gray_sync0						;
            wr_addr_gray_sync2 					<= wr_addr_gray_sync1						;
        end
    end

    // dout
    generate
        if (SHOW_AHEAD) begin : gen_show_ahead_q
            always @(posedge rd_clk) 	dout    <= mem[rd_addr]								;

            always @(*) 				valid   <= ~empty 									;

        end
        else begin : gen_normal_q
            always @(posedge rd_clk) begin
                if (~empty & rd_en) begin
                    dout    					<= mem[rd_addr]								;
                    valid   					<= 1'b1										;
                end else begin
                    valid   					<= 1'b0										;
                end
            end
        end
    endgenerate

    // rd_data_count
    always @(posedge rd_clk or negedge rd_sync_rstn) begin
        if (~rd_sync_rstn)	rd_data_count 		<= 1'b0										;
        else				rd_data_count 		<= wr_addr_bin_sync - rd_addr_bin_next		;
    end

endmodule

/* MagicIP fifo instance example
    async_fifo#(
        .AF                 					( 1                 						),
        .DATA_BITS          					( 8                 						),
        .DEPTH_BITS         					( 8                 						),
        .SHOW_AHEAD         					( 0                 						),
        .RAM_STYLE          					( "block"           						)
    )(
        // write
        .wr_clk             					( wr_clk            						),
        .wr_rstn            					( wr_rstn           						),
        .wr_en              					( wr_en             						),
        .din                					( din               						),
        .wr_data_count      					( wr_data_count     						),
        .prog_full          					( prog_full         						),
        .full               					( full              						),

        // read
        .rd_clk             					( rd_clk            						),
        .rd_rstn            					( rd_rstn           						),
        .rd_en              					( rd_en             						),
        .dout               					( dout              						),
        .rd_data_count      					( rd_data_count     						),
        .pre_empty          					( pre_empty         						),
        .empty              					( empty             						)
    );
*/
