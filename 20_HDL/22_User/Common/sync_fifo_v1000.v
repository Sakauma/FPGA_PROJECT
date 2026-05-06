// ============================================================================
// 新增维护说明
// 作者          : Egor Izmaylov
// 文件职责      : 当前文件为手工维护源码，具体职责见模块名、端口和上层实例化。
// 维护边界      : 只追加说明性注释；Vivado/IP 生成物和第三方支撑代码不在此处手改。
// 修改约束      : 功能改动需同步更新仿真、综合结果和相关文档。
// ============================================================================
//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2018 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : MiaoJiawang jiawang.miao@magicip.com.cn
// Create Date       : 2019-10-05  08:45:31
// Design Name       :
// Module Name       : sync_fifo_v1000.v
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
//
//////////////////////////////////////////////////////////////////////////////////
//`timescale 1ns/1ps

module sync_fifo#(
	parameter   	PROG_DEPTH  				= 4             							,
	parameter   	DWIDTH      				= 8             							,
	parameter   	DEPTH       				= 256           							,
	parameter   	SHOW_AHEAD  				= 0             							,
	parameter   	RAM_STYLE   				= "block"   								,	//distirbuted
	parameter   	AWIDTH      				= log2(DEPTH)
    )(
	// system signal
	input   wire                    			clk         								,
	input   wire                    			rstn        								,
	// write
	input   wire                    			wr_en       								,
	input   wire    [DWIDTH-1:0]    			din         								,
	output  reg                     			prog_full   =0								,
	output  reg                     			full        =0								,
	// read
	input   wire                    			rd_en       								,
	output  reg                     			empty       =1								,
    output  wire                        		pre_empty       							,	
	output  wire    [DWIDTH-1:0]    			dout        								,
	output  reg                     			valid       								,
	// used words
	output  reg     [AWIDTH-1:0]    			data_count= {AWIDTH{1'b0}}
    );

    //------------------------Parameter----------------------
    //------------------------Local signal-------------------
    (* ram_extract="yes", ramstyle = RAM_STYLE *)
	reg     		[DWIDTH-1:0]    			mem[0:DEPTH-1]  							;
	reg     		[DWIDTH-1:0]    			q_buf           = {DWIDTH{1'b0}}			;
	reg     		[AWIDTH-1:0]    			waddr           = {AWIDTH{1'b0}}			;
	reg     		[AWIDTH-1:0]    			raddr           = {AWIDTH{1'b0}}			;
	wire    		[AWIDTH-1:0]    			wnext           							;
	wire    		[AWIDTH-1:0]    			rnext           							;

    //------------------------Instantiation------------------

    //------------------------Task and function--------------
    function integer log2;
        input  [ 31: 0] value;
        reg    [ 31: 0] tmp;
        begin
        tmp = value;
        for (log2 = 0; tmp > 0; log2 = log2 + 1)
            tmp = tmp >> 1;
        end
    endfunction


    //------------------------Body---------------------------

    assign wnext   = !(~full & wr_en)   	? 	waddr :
                     (waddr == DEPTH - 1) 	? 	1'b0  :
                     							waddr + 1'b1;
                     							
    assign rnext   = !(~empty & rd_en)  	? 	raddr :
                     (raddr == DEPTH - 1) 	? 	1'b0  :
                     							raddr + 1'b1;

    // waddr
    always @(posedge clk) begin
        if (~rstn)      waddr <= 1'b0;
        else            waddr <= !(~full & wr_en)   	? 	waddr 		:
                     			 (waddr == DEPTH - 1) 	? 	1'b0  		:
                     			 							waddr + 1'b1	;
    end

    // raddr
    always @(posedge clk) begin
        if (~rstn)   	raddr <= 1'b0	;
        else           	raddr <= rnext	;
    end

    // data_count
    always @(posedge clk) begin
        if (~rstn)           							data_count <= 1'b0						;
        else if ((~full & wr_en) & ~(~empty & rd_en))  	data_count <= data_count + 1'b1			;	// only write
        else if (~(~full & wr_en) & (~empty & rd_en))  	data_count <= data_count - 1'b1			;	// only read
    end

    // full
    always @(posedge clk or negedge rstn) begin
        if (~rstn)            							full 		<= 1'b0						;
        else if ((~full & wr_en) & ~(~empty & rd_en)) 	full 		<= (data_count == DEPTH - 1);	// only write
        else if (~(~full & wr_en) & (~empty & rd_en)) 	full 		<= 1'b0						;	// only read
    end

    //prog_full
    always @(posedge clk or negedge rstn) begin
        if (~rstn)           	prog_full <= 1'b0												;
        else          			prog_full <= (data_count >= DEPTH - PROG_DEPTH-1)?1'b1:1'b0		;
    end

    assign  pre_empty   = (data_count >= 'd2)?1'b0:1'b1;

    // empty
    always @(posedge clk or negedge rstn) begin
        if (~rstn)           							empty 		<= 1'b1						;
        else if ((~full & wr_en) & ~(~empty & rd_en))  	empty 		<= 1'b0						;	// only write
        else if (~(~full & wr_en) & (~empty & rd_en))  	empty 		<= (data_count == 1'b1)		;	// only read
    end

    integer a;

    initial
    for (a = 0; a < DEPTH; a = a + 1)
        mem[a] = {DWIDTH{1'b0}};

    // mem
    always @(posedge clk) begin
`ifdef SIMULATION
       	if(~rstn) begin
	            for(a=0;a<DEPTH;a=a+1)begin
 	               mem[a]  <= {DWIDTH{1'b0}};
            end
    	end else
`endif
        if (~full & wr_en)           mem[waddr] <= din;
    end

generate	if (SHOW_AHEAD) begin : gen_show_ahead_q
    reg [DWIDTH-1:0]q_tmp      					= {DWIDTH{1'b0}}							;
    reg             show_ahead					= 0											;

        assign 		dout 						= show_ahead? q_tmp : q_buf					;

        // q_buf
        always @(posedge clk) 	q_buf   		<= mem[rnext]								;
                                        		
        always @(*) 			valid   		<= ~empty 									;

        // q_tmp
        always @(posedge clk) if (~full & wr_en) q_tmp <= din								;

        // show_ahead
        always @(posedge clk) begin
            if (~rstn)				show_ahead 	<= 1'b0										;
            else if (~full & wr_en)	show_ahead 	<= (waddr == rnext)							;
            else					show_ahead 	<= 1'b0										;
        end
        
end else begin : gen_normal_q
        assign dout = q_buf;

        // q_buf
        always @(posedge clk) begin
            if (~empty & rd_en)begin
                q_buf   <= mem[raddr]	;
                valid   <= 1'b1 		;
            end else begin
                valid   <= 1'b0 		;
            end
        end
    end

    endgenerate

endmodule


/* MagicIP fifo instance example
    sync_fifo#(
        .DWIDTH             					( 				       					),
        .DEPTH              					( 		            					),
        .SHOW_AHEAD         					( 0                     					),
        .RAM_STYLE          					( ""            					)
    )mac_rx_data_fifo_136x64_inst(
        // system signal
        .clk                					(                				),
        .rstn               					(               						),
        // write
        .wr_en              					(          	),
        .din                					(          					),
        .prog_full          					( 						),
        .full               					(         					),
        // read
        .rd_en              					(          					),
        .empty              					(        					),
        .pre_empty								( 					),
        .dout               					(         						),
        .valid              					( 											),
        // used words
        .data_count         					(   								)
    );
*/
