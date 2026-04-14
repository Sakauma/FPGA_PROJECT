`timescale 1ns / 1ps
//`define loop_back_test
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 2021/3/1 12:40:55
// Design Name:
// Module Name: app_top
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//
// Dependencies:
//	iT/iC Channel List
//	iT_DN0-->PowerLoding--->Used for Initialazation
//	iT_DN1-->HDLC APP------>HDLC Adapter
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////////////////////
module	user_top #(
	parameter		L_INIT_DONE_TIME_P			= 125*1000*1500*4								//1.5s
	)(
//==================================================================================================
//--Common interface

	input										ps_reset									,	

//==================================================================================================
//--iRAX Trig
	
	output										rs422_tx_out_1								,	
	input										rs422_rx_in_1								,	
	output										rs422_tx_out_2								,	
	input										rs422_rx_in_2								,	
	output										rs422_tx_out_3								,	
	input										rs422_rx_in_3								,	
	output										rs422_tx_out_4								,	
	input										rs422_rx_in_4								,	

	output	wire								rs422_tx_out_5								,	
    input	wire								rs422_rx_in_5 								,   
	output	wire								rs422_tx_out_6								,	
    input	wire								rs422_rx_in_6								,   

    input	wire								rs422_ten_5								,   

    input	wire								rs422_ten_6								,   

//		output  wire  SFP_scl, 
//	inout wire SFP_sda,
//	output  wire [31:0]SFP_reg,	
//			output  wire  SFP_scl1, 
//	inout wire SFP_sda1,
//	output  wire [31:0]SFP_reg1,	
//(* MARK_DEBUG = "TRUE"*)    output  switch_28v_reg_1,
//						output  switch_28v_reg_2,
//							input  switch_hot_back,
//								input  switch_28v_back1,
//							input  switch_28v_back2,						
//						output  switch_28v_reg_1_1,
//						output  switch_28v_reg_2_2,
//    output                                   switch_hot,

	 
	 
	 
	input			[31:0]						sys_uart_1_axi_awaddr						,	
	input			[2:0]						sys_uart_1_axi_awprot						,	
	input										sys_uart_1_axi_awvalid						,	
	output										sys_uart_1_axi_awready						,	

     /*--------------------------------------------------------------------------------------
     --Write Data Channel Signals
     --------------------------------------------------------------------------------------*/
	input			[31:0]						sys_uart_1_axi_wdata						,	
	input			[3:0]						sys_uart_1_axi_wstrb						,	
	input										sys_uart_1_axi_wvalid						,	
	output										sys_uart_1_axi_wready						,	

     /*--------------------------------------------------------------------------------------
     --Write Response Channel Signals
     --------------------------------------------------------------------------------------*/
	output			[1:0]						sys_uart_1_axi_bresp						,	
	output										sys_uart_1_axi_bvalid						,	
	input										sys_uart_1_axi_bready						,	
     /*--------------------------------------------------------------------------------------
     --Read Address Channel Signals
     --------------------------------------------------------------------------------------*/
	input			[31:0]						sys_uart_1_axi_araddr						,	
	input			[2:0]						sys_uart_1_axi_arprot						,	
	input										sys_uart_1_axi_arvalid						,	
	output										sys_uart_1_axi_arready						,	

     /*--------------------------------------------------------------------------------------
     --Read Address Channel Signals
     --------------------------------------------------------------------------------------*/
	output			[31:0]						sys_uart_1_axi_rdata						,	
	output			[1:0]						sys_uart_1_axi_rresp						,	
	output										sys_uart_1_axi_rvalid						,	
	input										sys_uart_1_axi_rready						,	

       
    // uart   sys_uart_2
	input			[31:0]						sys_uart_2_axi_awaddr						,	
	input			[2:0]						sys_uart_2_axi_awprot						,	
	input										sys_uart_2_axi_awvalid						,	
	output										sys_uart_2_axi_awready						,	

     /*--------------------------------------------------------------------------------------
     --Write Data Channel Signals
     --------------------------------------------------------------------------------------*/
	input			[31:0]						sys_uart_2_axi_wdata						,	
	input			[3:0]						sys_uart_2_axi_wstrb						,	
	input										sys_uart_2_axi_wvalid						,	
	output										sys_uart_2_axi_wready						,	

     /*--------------------------------------------------------------------------------------
     --Write Response innnel Signals
     --------------------------------------------------------------------------------------*/
	output			[1:0]						sys_uart_2_axi_bresp						,	
	output										sys_uart_2_axi_bvalid						,	
	input										sys_uart_2_axi_bready						,	
     /*--------------------------------------------------------------------------------------
     --Read Address Channel Signals
     --------------------------------------------------------------------------------------*/
	input			[31:0]						sys_uart_2_axi_araddr						,	
	input			[2:0]						sys_uart_2_axi_arprot						,	
	input										sys_uart_2_axi_arvalid						,	
	output										sys_uart_2_axi_arready						,	

     /*--------------------------------------------------------------------------------------
     --Read Address Channel Signals
     --------------------------------------------------------------------------------------*/
	output			[31:0]						sys_uart_2_axi_rdata						,	
	output			[1:0]						sys_uart_2_axi_rresp						,	
	output										sys_uart_2_axi_rvalid						,	
	input										sys_uart_2_axi_rready						,	

       
    // uart   sys_uart_3
	input			[31:0]						sys_uart_3_axi_awaddr						,	
	input			[2:0]						sys_uart_3_axi_awprot						,	
	input										sys_uart_3_axi_awvalid						,	
	output										sys_uart_3_axi_awready						,	

     /*--------------------------------------------------------------------------------------
     --Write Data Channel Signals
     --------------------------------------------------------------------------------------*/
	input			[31:0]						sys_uart_3_axi_wdata						,	
	input			[3:0]						sys_uart_3_axi_wstrb						,	
	input										sys_uart_3_axi_wvalid						,	
	output										sys_uart_3_axi_wready						,	

     /*--------------------------------------------------------------------------------------
     --Write Response Channel Signals
     --------------------------------------------------------------------------------------*/
	output			[1:0]						sys_uart_3_axi_bresp						,	
	output										sys_uart_3_axi_bvalid						,	
	input										sys_uart_3_axi_bready						,	
     /*--------------------------------in---------------------------------------------------
     --Read Address Channel Signals
     --------------------------------------------------------------------------------------*/
	input			[31:0]						sys_uart_3_axi_araddr						,	
	input			[2:0]						sys_uart_3_axi_arprot						,	
	input										sys_uart_3_axi_arvalid						,	
	output										sys_uart_3_axi_arready						,	

     /*--------------------------------------------------------------------------------------
     --Read Address Channel Signals
     --------------------------------------------------------------------------------------*/
	output			[31:0]						sys_uart_3_axi_rdata						,	
	output			[1:0]						sys_uart_3_axi_rresp						,	
	output										sys_uart_3_axi_rvalid						,	
	input										sys_uart_3_axi_rready						,	
	
	
	input			[31:0]						sys_uart_4_axi_awaddr						,	
	input			[2:0]						sys_uart_4_axi_awprot						,	
	input										sys_uart_4_axi_awvalid						,	
	output										sys_uart_4_axi_awready						,	
	input			[31:0]						sys_uart_4_axi_wdata						,	
	input			[3:0]						sys_uart_4_axi_wstrb						,	
	input										sys_uart_4_axi_wvalid						,	
	output										sys_uart_4_axi_wready						,	
	output			[1:0]						sys_uart_4_axi_bresp						,	
	output										sys_uart_4_axi_bvalid						,	
	input										sys_uart_4_axi_bready						,	
	input			[31:0]						sys_uart_4_axi_araddr						,	
	input			[2:0]						sys_uart_4_axi_arprot						,	
	input										sys_uart_4_axi_arvalid						,	
	output										sys_uart_4_axi_arready						,	
	output			[31:0]						sys_uart_4_axi_rdata						,	
	output			[1:0]						sys_uart_4_axi_rresp						,	
	output										sys_uart_4_axi_rvalid						,	
	input										sys_uart_4_axi_rready						,	

	input			[31:0]						sys_uart_5_axi_awaddr						,	
	input			[2:0]						sys_uart_5_axi_awprot						,	
	input										sys_uart_5_axi_awvalid						,	
	output										sys_uart_5_axi_awready						,	
	input			[31:0]						sys_uart_5_axi_wdata						,	
	input			[3:0]						sys_uart_5_axi_wstrb						,	
	input										sys_uart_5_axi_wvalid						,	
	output										sys_uart_5_axi_wready						,	
	output			[1:0]						sys_uart_5_axi_bresp						,	
	output										sys_uart_5_axi_bvalid						,	
	input										sys_uart_5_axi_bready						,	
	input			[31:0]						sys_uart_5_axi_araddr						,	
	input			[2:0]						sys_uart_5_axi_arprot						,	
	input										sys_uart_5_axi_arvalid						,	
	output										sys_uart_5_axi_arready						,	
	output			[31:0]						sys_uart_5_axi_rdata						,	
	output			[1:0]						sys_uart_5_axi_rresp						,	
	output										sys_uart_5_axi_rvalid						,	
	input										sys_uart_5_axi_rready						,	
	
	input			[31:0]						sys_uart_6_axi_awaddr						,	
	input			[2:0]						sys_uart_6_axi_awprot						,	
	input										sys_uart_6_axi_awvalid						,	
	output										sys_uart_6_axi_awready						,	
	input			[31:0]						sys_uart_6_axi_wdata						,	
	input			[3:0]						sys_uart_6_axi_wstrb						,	
	input										sys_uart_6_axi_wvalid						,	
	output										sys_uart_6_axi_wready						,	
	output			[1:0]						sys_uart_6_axi_bresp						,	
	output										sys_uart_6_axi_bvalid						,	
	input										sys_uart_6_axi_bready						,	
	input			[31:0]						sys_uart_6_axi_araddr						,	
	input			[2:0]						sys_uart_6_axi_arprot						,	
	input										sys_uart_6_axi_arvalid						,	
	output										sys_uart_6_axi_arready						,	
	output			[31:0]						sys_uart_6_axi_rdata						,	
	output			[1:0]						sys_uart_6_axi_rresp						,	
	output										sys_uart_6_axi_rvalid						,	
	input										sys_uart_6_axi_rready						,		
	
	input										axi_clk										,	
      

	output										rs422_int_1									,	
	output										rs422_int_2									,	
	output										rs422_int_3									,	
	output										rs422_int_4									,	
	output										rs422_int_5									,	
	output										rs422_int_6									,	

	output			[31:0]						int_test										

	);
//==================================================================================================


	rs422_top	rs422_top_1(
 //            .clk                   (clk100m )             ,
		.int_test								( int_test									),	

		.clk									( axi_clk									),	
		.rst									( ps_reset									),	
		.rs422_tx_out							( rs422_tx_out_1							),	
		.rs422_rx_in							( rs422_rx_in_1								),	
		.rx_fifo_empty							( rs422_int_1								),	
                                                          

		.sys_axi_araddr							( sys_uart_1_axi_araddr						),	
		.sys_axi_arprot							( sys_uart_1_axi_arprot						),	
		.sys_axi_arready						( sys_uart_1_axi_arready					),	
		.sys_axi_arvalid						( sys_uart_1_axi_arvalid					),	
                                                    
		.sys_axi_awaddr							( sys_uart_1_axi_awaddr						),	
		.sys_axi_awprot							( sys_uart_1_axi_awprot						),	
		.sys_axi_awready						( sys_uart_1_axi_awready					),	
		.sys_axi_awvalid						( sys_uart_1_axi_awvalid					),	
                                                   
		.sys_axi_bready							( sys_uart_1_axi_bready						),	
		.sys_axi_bresp							( sys_uart_1_axi_bresp						),	
		.sys_axi_bvalid							( sys_uart_1_axi_bvalid						),	
                                                    
		.sys_axi_rdata							( sys_uart_1_axi_rdata						),	
		.sys_axi_rready							( sys_uart_1_axi_rready						),	
		.sys_axi_rresp							( sys_uart_1_axi_rresp						),	
		.sys_axi_rvalid							( sys_uart_1_axi_rvalid						),	
                                                    
		.sys_axi_wdata							( sys_uart_1_axi_wdata						),	
		.sys_axi_wready							( sys_uart_1_axi_wready						),	
		.sys_axi_wstrb							( sys_uart_1_axi_wstrb						),	
		.sys_axi_wvalid							( sys_uart_1_axi_wvalid						)	
      
	);




	rs422_top	rs422_top_2(
 //            .clk                   (clk100m )             ,
             
		.clk									( axi_clk									),	
		.rst									( ps_reset									),	
		.rs422_tx_out							( rs422_tx_out_2							),	
		.rs422_rx_in							( rs422_rx_in_2								),	
		.rx_fifo_empty							( rs422_int_2								),	

		.sys_axi_araddr							( sys_uart_2_axi_araddr						),	
		.sys_axi_arprot							( sys_uart_2_axi_arprot						),	
		.sys_axi_arready						( sys_uart_2_axi_arready					),	
		.sys_axi_arvalid						( sys_uart_2_axi_arvalid					),	
                                                    
		.sys_axi_awaddr							( sys_uart_2_axi_awaddr						),	
		.sys_axi_awprot							( sys_uart_2_axi_awprot						),	
		.sys_axi_awready						( sys_uart_2_axi_awready					),	
		.sys_axi_awvalid						( sys_uart_2_axi_awvalid					),	
                                                   
		.sys_axi_bready							( sys_uart_2_axi_bready						),	
		.sys_axi_bresp							( sys_uart_2_axi_bresp						),	
		.sys_axi_bvalid							( sys_uart_2_axi_bvalid						),	
                                                    
		.sys_axi_rdata							( sys_uart_2_axi_rdata						),	
		.sys_axi_rready							( sys_uart_2_axi_rready						),	
		.sys_axi_rresp							( sys_uart_2_axi_rresp						),	
		.sys_axi_rvalid							( sys_uart_2_axi_rvalid						),	
                                                    
		.sys_axi_wdata							( sys_uart_2_axi_wdata						),	
		.sys_axi_wready							( sys_uart_2_axi_wready						),	
		.sys_axi_wstrb							( sys_uart_2_axi_wstrb						),	
		.sys_axi_wvalid							( sys_uart_2_axi_wvalid						)	
      
	);



	rs422_top	rs422_top_3(
 //            .clk                   (clk100m )             ,
             
		.clk									( axi_clk									),	
		.rst									( ps_reset									),	
		.rs422_tx_out							( rs422_tx_out_3							),	
		.rs422_rx_in							( rs422_rx_in_3								),	
		.rx_fifo_empty							( rs422_int_3								),	

		.sys_axi_araddr							( sys_uart_3_axi_araddr						),	
		.sys_axi_arprot							( sys_uart_3_axi_arprot						),	
		.sys_axi_arready						( sys_uart_3_axi_arready					),	
		.sys_axi_arvalid						( sys_uart_3_axi_arvalid					),	
                                                    
		.sys_axi_awaddr							( sys_uart_3_axi_awaddr						),	
		.sys_axi_awprot							( sys_uart_3_axi_awprot						),	
		.sys_axi_awready						( sys_uart_3_axi_awready					),	
		.sys_axi_awvalid						( sys_uart_3_axi_awvalid					),	
                                                   
		.sys_axi_bready							( sys_uart_3_axi_bready						),	
		.sys_axi_bresp							( sys_uart_3_axi_bresp						),	
		.sys_axi_bvalid							( sys_uart_3_axi_bvalid						),	
                                                    
		.sys_axi_rdata							( sys_uart_3_axi_rdata						),	
		.sys_axi_rready							( sys_uart_3_axi_rready						),	
		.sys_axi_rresp							( sys_uart_3_axi_rresp						),	
		.sys_axi_rvalid							( sys_uart_3_axi_rvalid						),	
                                                    
		.sys_axi_wdata							( sys_uart_3_axi_wdata						),	
		.sys_axi_wready							( sys_uart_3_axi_wready						),	
		.sys_axi_wstrb							( sys_uart_3_axi_wstrb						),	
		.sys_axi_wvalid							( sys_uart_3_axi_wvalid						)	
      
	);



	rs422_top	rs422_top_4(
		.clk									( axi_clk									),	
		.rst									( ps_reset									),	
		.rs422_tx_out							( rs422_tx_out_4							),	
		.rs422_rx_in							( rs422_rx_in_4								),	
		.rx_fifo_empty							( rs422_int_4								),	

		.sys_axi_araddr							( sys_uart_4_axi_araddr						),	
		.sys_axi_arprot							( sys_uart_4_axi_arprot						),	
		.sys_axi_arready						( sys_uart_4_axi_arready					),	
		.sys_axi_arvalid						( sys_uart_4_axi_arvalid					),	
                                                    
		.sys_axi_awaddr							( sys_uart_4_axi_awaddr						),	
		.sys_axi_awprot							( sys_uart_4_axi_awprot						),	
		.sys_axi_awready						( sys_uart_4_axi_awready					),	
		.sys_axi_awvalid						( sys_uart_4_axi_awvalid					),	
                                                   
		.sys_axi_bready							( sys_uart_4_axi_bready						),	
		.sys_axi_bresp							( sys_uart_4_axi_bresp						),	
		.sys_axi_bvalid							( sys_uart_4_axi_bvalid						),	
                                                    
		.sys_axi_rdata							( sys_uart_4_axi_rdata						),	
		.sys_axi_rready							( sys_uart_4_axi_rready						),	
		.sys_axi_rresp							( sys_uart_4_axi_rresp						),	
		.sys_axi_rvalid							( sys_uart_4_axi_rvalid						),	
                                                    
		.sys_axi_wdata							( sys_uart_4_axi_wdata						),	
		.sys_axi_wready							( sys_uart_4_axi_wready						),	
		.sys_axi_wstrb							( sys_uart_4_axi_wstrb						),	
		.sys_axi_wvalid							( sys_uart_4_axi_wvalid						));
  
	rs422_top	rs422_top_5(                                                                    
		.clk									( axi_clk									),	
		.rst									( ps_reset									),	
		.rs422_tx_out							( rs422_tx_out_5							),	
		.rs422_rx_in							( rs422_rx_in_5								),	
		.rx_fifo_empty							( rs422_int_5								),	
                                                                                                
		.sys_axi_araddr							( sys_uart_5_axi_araddr						),	
		.sys_axi_arprot							( sys_uart_5_axi_arprot						),	
		.sys_axi_arready						( sys_uart_5_axi_arready					),	
		.sys_axi_arvalid						( sys_uart_5_axi_arvalid					),	
                                                                                                
		.sys_axi_awaddr							( sys_uart_5_axi_awaddr						),	
		.sys_axi_awprot							( sys_uart_5_axi_awprot						),	
		.sys_axi_awready						( sys_uart_5_axi_awready					),	
		.sys_axi_awvalid						( sys_uart_5_axi_awvalid					),	
                                                                                                
		.sys_axi_bready							( sys_uart_5_axi_bready						),	
		.sys_axi_bresp							( sys_uart_5_axi_bresp						),	
		.sys_axi_bvalid							( sys_uart_5_axi_bvalid						),	
                                                                                                
		.sys_axi_rdata							( sys_uart_5_axi_rdata						),	
		.sys_axi_rready							( sys_uart_5_axi_rready						),	
		.sys_axi_rresp							( sys_uart_5_axi_rresp						),	
		.sys_axi_rvalid							( sys_uart_5_axi_rvalid						),	
                                                                                                
		.sys_axi_wdata							( sys_uart_5_axi_wdata						),	
		.sys_axi_wready							( sys_uart_5_axi_wready						),	
		.sys_axi_wstrb							( sys_uart_5_axi_wstrb						),	
		.sys_axi_wvalid							( sys_uart_5_axi_wvalid						)); 


	rs422_top	rs422_top_6(                                                                    
		.clk									( axi_clk									),	
		.rst									( ps_reset									),	
		.rs422_tx_out							( rs422_tx_out_6							),	
		.rs422_rx_in							( rs422_rx_in_6								),	
		.rx_fifo_empty							( rs422_int_6								),	
                                                                                                
		.sys_axi_araddr							( sys_uart_6_axi_araddr						),	
		.sys_axi_arprot							( sys_uart_6_axi_arprot						),	
		.sys_axi_arready						( sys_uart_6_axi_arready					),	
		.sys_axi_arvalid						( sys_uart_6_axi_arvalid					),	
                                                                                                
		.sys_axi_awaddr							( sys_uart_6_axi_awaddr						),	
		.sys_axi_awprot							( sys_uart_6_axi_awprot						),	
		.sys_axi_awready						( sys_uart_6_axi_awready					),	
		.sys_axi_awvalid						( sys_uart_6_axi_awvalid					),	
                                                                                                
		.sys_axi_bready							( sys_uart_6_axi_bready						),	
		.sys_axi_bresp							( sys_uart_6_axi_bresp						),	
		.sys_axi_bvalid							( sys_uart_6_axi_bvalid						),	
                                                                                                
		.sys_axi_rdata							( sys_uart_6_axi_rdata						),	
		.sys_axi_rready							( sys_uart_6_axi_rready						),	
		.sys_axi_rresp							( sys_uart_6_axi_rresp						),	
		.sys_axi_rvalid							( sys_uart_6_axi_rvalid						),	
                                                                                                
		.sys_axi_wdata							( sys_uart_6_axi_wdata						),	
		.sys_axi_wready							( sys_uart_6_axi_wready						),	
		.sys_axi_wstrb							( sys_uart_6_axi_wstrb						),	
		.sys_axi_wvalid							( sys_uart_6_axi_wvalid						)); 
  

  
endmodule

