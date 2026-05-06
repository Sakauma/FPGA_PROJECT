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
// Create Date       : 2019-10-05  17:05:21
// Design Name       : 
// Module Name       : sdp_drw_ram.v
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
module sdp_drw_ram#(
    parameter		A_RAM_WIDTH     			= 128        								,
    parameter		A_RAM_DEPTH     			= 8192      								,
    parameter		B_RAM_WIDTH     			= 8        								    ,
    parameter		B_RAM_DEPTH     			= A_RAM_WIDTH*A_RAM_DEPTH/B_RAM_WIDTH      	,
    parameter		RAM_OUT_REG_EN  			= "ENABLE"  								,
    parameter		RAM_STYLE       			= "block"   								,
    parameter		INIT_FILE       			= ""        								
)(
    input   wire                                clka     									,
    input   wire                                wea     									,
    input   wire    [clogb2(A_RAM_DEPTH-1)-1:0] addra   									,
    input   wire    [A_RAM_WIDTH-1:0]           dina    									,
    output  reg     [A_RAM_WIDTH-1:0]           douta   									,        

    input   wire                                clkb     									,
    input   wire                                rstb     									,                                                        									
    input   wire                                enb     									,
    input   wire    [clogb2(B_RAM_DEPTH-1)-1:0] addrb   									,
    input   wire                                regceb  									,
    output  wire    [B_RAM_WIDTH-1:0]           doutb   									     
);       
    reg 			[B_RAM_WIDTH-1:0] 			ram_data = {B_RAM_WIDTH{1'b0}}				;
    localparam RAMB_HWIDT   					= (A_RAM_WIDTH<B_RAM_WIDTH)    ?   clogb2(A_RAM_DEPTH) - clogb2(B_RAM_DEPTH)  
                                                                               :   clogb2(B_RAM_DEPTH) - clogb2(A_RAM_DEPTH);


    // The following code either initializes the memory values to a specified file or to all zeros to match hardware
    genvar i;

generate   if (A_RAM_WIDTH<B_RAM_WIDTH) begin
    (* ram_extract="yes", ram_style = RAM_STYLE *)
    reg 			[A_RAM_WIDTH-1:0] 			mem 	[A_RAM_DEPTH-1:0]					;   
    
        if (INIT_FILE != "") begin: use_init_file
            initial
                $readmemh(INIT_FILE, mem, 0, A_RAM_DEPTH-1);
        end else begin: init_bram_to_zero
            integer ram_index;
            initial
                for (ram_index = 0; ram_index < A_RAM_DEPTH; ram_index = ram_index + 1)
                    mem[ram_index] = {A_RAM_WIDTH{1'b0}};
        end          


        for(i=0;i<B_RAM_WIDTH/A_RAM_WIDTH;i=i+1) begin : ramb_data_out_gen
            wire    [clogb2(A_RAM_DEPTH-1)-1:0]     addrb_w    								;
            assign  addrb_w[clogb2(A_RAM_DEPTH-1)-1:RAMB_HWIDT]    = addrb 					;
            assign  addrb_w[RAMB_HWIDT-1:0]                        = i 						;
            always @(posedge clkb) begin
                if (enb)
                    ram_data[i*A_RAM_WIDTH+:A_RAM_WIDTH]    		<= mem[{addrb_w}]		;
            end
        end

      always @(posedge clka) 
      if (wea)		mem[addra] 					<= dina										;

    always @(posedge clka)
        douta   								<= mem[addra]    							;      
end else if (A_RAM_WIDTH==B_RAM_WIDTH) begin
    (* ram_extract="yes", ram_style = RAM_STYLE *)
    reg 			[A_RAM_WIDTH-1:0] 			mem 	[A_RAM_DEPTH-1:0]					;   
    
        if (INIT_FILE != "") begin: use_init_file
            initial
                $readmemh(INIT_FILE, mem, 0, A_RAM_DEPTH-1);
        end else begin: init_bram_to_zero
            integer ram_index;
            initial
                for (ram_index = 0; ram_index < A_RAM_DEPTH; ram_index = ram_index + 1)
                    mem[ram_index] = {A_RAM_WIDTH{1'b0}};
        end          



            always @(posedge clkb) begin
                if (enb)
                    ram_data  		<= mem[{addrb}]		;
            end

      always @(posedge clka) 
      if (wea)		mem[addra] 					<= dina										;

    always @(posedge clka)
        douta   								<= mem[addra]    							;      
        
        
end else begin
(* synthesis, loop_limit = 100000000 *)

    (* ram_extract="yes", ram_style = RAM_STYLE *)
    reg 			[B_RAM_WIDTH-1:0] 			mem 	[B_RAM_DEPTH-1:0]					;   
           if (INIT_FILE != "") begin: use_init_file
            initial
                $readmemh(INIT_FILE, mem, 0, B_RAM_DEPTH-1);
        end else begin: init_bram_to_zero
            integer ram_index;
            initial
                for (ram_index = 0; ram_index < B_RAM_DEPTH; ram_index = ram_index + 1)
                    mem[ram_index] = {B_RAM_WIDTH{1'b0}};
        end       



            wire    [clogb2(B_RAM_DEPTH-1)-RAMB_HWIDT-1:0]    addra_h            = addra        ;
            reg     [RAMB_HWIDT-1+1:0]                         addra_l            ;      
                        
            always @(posedge clka) begin
                if (wea) begin
                  for(addra_l=0;addra_l<(A_RAM_WIDTH/B_RAM_WIDTH);addra_l=addra_l+1)begin
                     mem[{addra_h,addra_l[RAMB_HWIDT-1:0]}]	<= dina	[addra_l*B_RAM_WIDTH+:B_RAM_WIDTH]                    ;
                  end   
                 end 
            end
			
	    always @(posedge clkb) begin
                if (enb)
                    ram_data					<= mem[addrb];
         end
end endgenerate
  

    generate
        if (RAM_OUT_REG_EN != "ENABLE") begin: no_output_register
            // The following is a 1 clock cycle read latency at the cost of a longer clock-to-out timing
            assign doutb						 = ram_data									;
            
        end else begin: output_register

            // The following is a 2 clock cycle read latency with improve clock-to-out timing

            reg [B_RAM_WIDTH-1:0] doutb_reg 	= {B_RAM_WIDTH{1'b0}}						;

            always @(posedge clkb)
                if (rstb)			doutb_reg 	<= {B_RAM_WIDTH{1'b0}}						;
                else if (regceb)	doutb_reg 	<= ram_data									;

                assign doutb 					= doutb_reg									;
        end
    endgenerate
    
    //  The following function calculates the address width based on specified RAM depth
    function integer clogb2;
        input integer depth;
        for (clogb2=0; depth>0; clogb2=clogb2+1)
            depth = depth >> 1;
    endfunction

endmodule

// The following is an instantiation template for sdp_ram
/*

	sdp_drw_ram	#(
		.A_RAM_WIDTH        					( 1             							),
	    .A_RAM_DEPTH        					( 16384         							),
	    .B_RAM_WIDTH        					( 32            							),
	    .B_RAM_DEPTH        					( 512           							),
	    .RAM_STYLE        						( "block"       							),
	    .RAM_OUT_REG_EN     					( "EABLE  									)
	) u_18k_ram(            					                							
	    .clk                					( clk           							),
	    .rst                					( rst           							),
	                        					
	    .wea                					(     	),
	    .addra              					(     	),
	    .dina               					(     	),
	                        					                                        	
	    .enb                					( 1'b1                                  	),
	    .addrb              					(                	),
	    .doutb              					(                	),
	    .regceb             					( 1'b1                                  	)
	);
    sdp_ram
    #(
        .RAM_WIDTH      ( 18            ),
        .RAM_DEPTH      ( 1024          ),
        .RAM_OUT_REG_EN ( "EABLE"       ),
        .RAM_STYLE      ( "block"       ),
        .INIT_FILE      ( ""            ) 
    )
    ux_sdp_ram 
    (
        .clk            ( clk           ), // Clock
        .rst            ( rst           ), // Output reset (does not affect memory contents)
        .wea            ( wea           ), // Byte-write enable, width determined from NB_COL
        .addra          ( addra         ), // Write address bus, width determined from RAM_DEPTH
        .dina           ( dina          ), // RAM input data, width determined from NB_COL*COL_WIDTH
        .douta          ( douta         ),
        .enb            ( enb           ), // Read Enable, for additional power savings, disable when not in use
        .addrb          ( addrb         ), // Read address bus, width determined from RAM_DEPTH
        .regceb         ( regceb        ), // Output register enable
        .doutb          ( doutb         )  // RAM output data, width determined from NB_COL*COL_WIDTH
    );
*/

