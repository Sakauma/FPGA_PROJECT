// ============================================================================
// 新增维护说明
// 作者          : Egor Izmaylov
// 文件职责      : 当前文件为手工维护源码，具体职责见模块名、端口和上层实例化。
// 维护边界      : 只追加说明性注释；Vivado/IP 生成物和第三方支撑代码不在此处手改。
// 修改约束      : 功能改动需同步更新仿真、综合结果和相关文档。
// ============================================================================
//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2020 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : MiaoJiawang jiawang.miao@magicip.com.cn
// Create Date       : 2020-01-04  16:38:48
// Design Name       :
// Module Name       : axis_async_fifo.v
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
//		Revision 1.01 - File Modified by	: wangzhen
//		Description							:
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
// Additional Comments:
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
//////////////////////////////////////////////////////////////////////////////////
//`timescale 1ns/1ps

module axis_sync_fifo#(
	parameter       C_FIFO_MODE 				= "TRUE"    								,
	parameter       DW          				= 64    									,
	parameter       UW          				= 16    									,
	parameter       FIFO_SIZE 					= 512										,
	parameter   	RAM_STYLE   				= "block"   								
)(
	input             							sys_clk 									,
	input             							sys_rst  									,

	input       	[DW     -1:0]       		wr_axis_tdata   							,
	input       	[DW/8   -1:0]       		wr_axis_tkeep   							,
	input   wire    [UW     -1:0]       		wr_axis_tuser   							,
	input                               		wr_axis_tvalid  							,
	input                               		wr_axis_tlast								,
	output                              		wr_axis_tready								,
    // FIFO read domain
	output wire 	[DW     -1:0]       		rd_axis_tdata								,
	output wire 	[DW/8   -1:0]       		rd_axis_tkeep								,
	output wire     [UW     -1:0]       		rd_axis_tuser   							,
	output wire                         		rd_axis_tvalid								,
	output wire                         		rd_axis_tlast								,
	input                               		rd_axis_tready								,

	output  wire    [clogb2(FIFO_SIZE)  :0]     axis_data_count
);
    reg                     					wr_axis_tlast_r    = 1'b0 					;

    wire                    					rd_axis_tlast_w     						;

    wire                    					sync_fifo_wea      	 						;
    wire     		[(DW+DW/8+UW+1)-1:0]        sync_fifo_din       						;
    wire                    					sync_fifo_full      						;

    wire                    					sync_fifo_rea       						;
    wire    		[(DW+DW/8+1)+UW-1:0]        sync_fifo_dout      						;
    wire                    					sync_fifo_empty     						;

    wire                    					frm_plus            						;
    wire                    					frm_delt            						;
    wire                    					frm_rdy             						;
    reg     		[clogb2(FIFO_SIZE)  :0]     frm_cnt            = 0  					;

    assign      	sync_fifo_wea       		=   C_FIFO_MODE!="TRUE"?  wr_axis_tlast_r|wr_axis_tvalid  : wr_axis_tvalid;

    assign      	sync_fifo_din       		= { C_FIFO_MODE!="TRUE"? wr_axis_tlast_r | wr_axis_tlast  : wr_axis_tlast
     											  ,wr_axis_tuser    [0*UW   +: UW	]
                	                    		  ,wr_axis_tkeep    [0*DW/8 +: DW/8	]
                	                    		  ,wr_axis_tdata    [0*DW	+: DW	]	};

    assign      	sync_fifo_rea       		= 	C_FIFO_MODE=="TRUE" ?rd_axis_tready & frm_rdy :   rd_axis_tready;

    assign      	rd_axis_tdata       		= sync_fifo_dout    [0      		+: DW	];
    assign      	rd_axis_tkeep       		= sync_fifo_dout    [0+DW   		+: DW/8	];
    assign      	rd_axis_tuser       		= sync_fifo_dout    [0+DW+DW/8   	+: UW	];
    assign      	rd_axis_tlast_w     		= sync_fifo_dout    [0+DW+DW/8+UW	+: 1	];

    assign      	wr_axis_tready      		= ~sync_fifo_full   						;


generate if (C_FIFO_MODE=="TRUE")	begin
    assign			rd_axis_tlast               = rd_axis_tlast_w & rd_axis_tvalid 					;//&rd_axis_tready;
    assign			rd_axis_tvalid              = (~sync_fifo_empty) & frm_rdy						;// & rd_axis_tready     ;

    assign			frm_rdy                     = (frm_cnt != 0) ? 1'b1:1'b0						;

    assign			frm_plus                    = wr_axis_tlast & wr_axis_tvalid & wr_axis_tready   ;
    assign			frm_delt                    = rd_axis_tlast & rd_axis_tvalid & rd_axis_tready   ;
    always@(posedge sys_clk or posedge sys_rst)                                               
        if(sys_rst)								frm_cnt     		<= 16'd0				; 
        else if(frm_plus & (~frm_delt))			frm_cnt     		<= frm_cnt + 1'b1   	; 
        else if(frm_delt & (~frm_plus))			frm_cnt     		<= frm_cnt - 1'b1   	; 

    //assign  		axis_data_count 			= frm_cnt											;
    always@(posedge sys_clk or posedge sys_rst)
        if		(sys_rst)						wr_axis_tlast_r     <= 1'b0 				;
        else if(wr_axis_tlast & sync_fifo_full)	wr_axis_tlast_r     <= 1'b1 				;
        else if(~sync_fifo_full)				wr_axis_tlast_r     <= 1'b0 				;

end else begin
    assign			rd_axis_tvalid              = ~sync_fifo_empty							;// & rd_axis_tready     ;
    assign			rd_axis_tlast               = rd_axis_tlast_w & rd_axis_tvalid 			;//&rd_axis_tready;

//    assign			frm_plus                    = wr_axis_tvalid & wr_axis_tready   		;
//    assign			frm_delt                    = rd_axis_tvalid & rd_axis_tready   		;
//
//    assign			axis_data_count 			= frm_cnt									;
end endgenerate

    sync_fifo#(
        .DWIDTH             					( (DW+DW/8+1 +UW)       					),
        .DEPTH              					( FIFO_SIZE             					),
        .SHOW_AHEAD         					( 1                     					),
        .RAM_STYLE          					( RAM_STYLE               					)
    )u1_sync_inst(
        // system signal
        .clk                					( sys_clk               					),
        .rstn               					( ~sys_rst              					),
        // write
        .wr_en              					( sync_fifo_wea         					),
        .din                					( sync_fifo_din         					),
        .prog_full          					( 											),
        .full               					( sync_fifo_full        					),
        // read
        .rd_en              					( sync_fifo_rea         					),
        .empty              					( sync_fifo_empty       					),
        .dout               					( sync_fifo_dout        					),
        .valid              					( 											),
        // used words
        .data_count         					( axis_data_count  							)
    );

    //  The following function calculates the address width based on specified RAM depth
    function integer clogb2;
        input integer depth;
        for (clogb2=0; depth>0; clogb2=clogb2+1)
            depth = depth >> 1;
    endfunction

endmodule
