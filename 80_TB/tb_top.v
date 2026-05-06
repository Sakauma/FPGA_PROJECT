`timescale 1ns/1ps
// ============================================================================
// 新增维护说明
// 作者          : Egor Izmaylov
// 文件职责      : 当前文件为手工维护源码，具体职责见模块名、端口和上层实例化。
// 维护边界      : 只追加说明性注释；Vivado/IP 生成物和第三方支撑代码不在此处手改。
// 修改约束      : 功能改动需同步更新仿真、综合结果和相关文档。
// ============================================================================
////////////////////////////////////////////////////////////////////////////////////////////////////
// Company			: ZHTY
// Engineer			: wangzhen
// Create Date		: 2025/11/13 15:34:53
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
/*
* 历史说明：原块注释编码已损坏，按当前文件头和开发文档维护。

cd E:/FPGA_CBB_WZ/srio_v10/10_PRJ/00_PRJ.sim/sim_1/behav/modelsim
do tb_top_compile.do
do tb_top_simulate.do
run 220us

do tb_top_compile.do
restart
run 10us
*/
module tb_top(	);
  	reg				sys_clk_n	  = 0 ;			always #(2.5) 	sys_clk_n	= ~sys_clk_n;

	wire										sys_clk_p				= ~sys_clk_n		;	


  	reg				srio_sys_clk_p	  = 0 ;			always #(8	/2) 	srio_sys_clk_p	= ~srio_sys_clk_p;

	wire										srio_sys_clk_n			= ~srio_sys_clk_p	;	
//==================================================================================================
//--Signals Define------------------------------
	reg											rst_n					= 'b0				;	

 EB4110_10V10_TOP	#(
	)EB4110_10V10_TOP(
		.sys_clk_n								( sys_clk_n									),	
		.sys_clk_p								( sys_clk_p									),	

		.gtxrefclk110_p							( srio_sys_clk_p							),	
		.gtxrefclk110_n							( srio_sys_clk_n							),	

		.gtxrefclk109_p							( srio_sys_clk_p							),	
		.gtxrefclk109_n							( srio_sys_clk_n							)													
	);



	reg			                            	lbe_width_sel       						;  // 0=16bit, 1=32bit
	reg				[32-1:0]       				lbe_addr            						;
	reg			                           	 	lbe_req             						;
	reg			                            	lbe_wr_en           						;  // 1=Write, 0=Read
	reg				[31:0]                      lbe_wdata           						;
	wire 			                            lbe_ready           						;
	wire 			[31:0]                      lbe_rdata           						;	
	
initial	begin		
		force	tb_top.EB4110_10V10_TOP.zynq_i.slb_to_axil_m_0.inst.lbe_width_sel = lbe_width_sel 	;
		force	tb_top.EB4110_10V10_TOP.zynq_i.slb_to_axil_m_0.inst.lbe_addr      = lbe_addr      	;
		force	tb_top.EB4110_10V10_TOP.zynq_i.slb_to_axil_m_0.inst.lbe_req       = lbe_req       	;	
		force	tb_top.EB4110_10V10_TOP.zynq_i.slb_to_axil_m_0.inst.lbe_wr_en     = lbe_wr_en     	;
		force	tb_top.EB4110_10V10_TOP.zynq_i.slb_to_axil_m_0.inst.lbe_wdata     = lbe_wdata     	;
		
		force	lbe_ready     = tb_top.EB4110_10V10_TOP.zynq_i.slb_to_axil_m_0.inst.lbe_ready     	;		
		force	lbe_rdata     = tb_top.EB4110_10V10_TOP.zynq_i.slb_to_axil_m_0.inst.lbe_rdata     	;				
		     
		lbe_width_sel							= 1'b1												;
		
		lbe_addr								= 32'h0000_0000										;
		lbe_req									= 1'b0												;
		lbe_wr_en								= 1'b0												;
		lbe_wdata								= 32'h0000_0000										;
		
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
//		#1000
//		lbe_addr								= 32'h82b1_0000										;
//		lbe_req									= 1'b1												;
//		lbe_wr_en								= 1'b0												;
//		lbe_wdata								= 32'h0000_0000										;
//		#10
//		lbe_req									= 1'b0												;
	
	
		// 历史说明：原注释编码已损坏，已替换为中文维护说明。
		#1000
		lbe_addr								= 32'h8122_0000										;
		lbe_req									= 1'b1												;
		lbe_wr_en								= 1'b1												;
		lbe_wdata								= 32'h0000_0001										;
		#10	
		// 历史说明：原注释编码已损坏，已替换为中文维护说明。
		#1000
		lbe_addr								= 32'h8122_0008										;
		lbe_req									= 1'b1												;
		lbe_wr_en								= 1'b1												;
		lbe_wdata								= 32'h0000_0040										;
		#10			
		// 历史说明：原注释编码已损坏，已替换为中文维护说明。
		#1000
		lbe_addr								= 32'h82b1_0000										;
		lbe_req									= 1'b1												;
		lbe_wr_en								= 1'b1												;
		lbe_wdata								= 32'h0000_1000										;
		#10
		lbe_req									= 1'b0												;		

		// 历史说明：原注释编码已损坏，已替换为中文维护说明。
		#1000
		lbe_addr								= 32'h82b1_0000										;
		lbe_req									= 1'b1												;
		lbe_wr_en								= 1'b0												;
		lbe_wdata								= 32'h0000_0000										;
		#10
		lbe_req									= 1'b0												;


		// 历史说明：原注释编码已损坏，已替换为中文维护说明。
		#1000
		lbe_addr								= 32'h8400_0000										;
		lbe_req									= 1'b1												;
		lbe_wr_en								= 1'b0												;
		lbe_wdata								= 32'h0000_0000										;
		#10
		lbe_req									= 1'b0												;
		
		
		
		// 历史说明：原注释编码已损坏，已替换为中文维护说明。
		#1000
		lbe_addr								= 32'h8600_0000										;
		lbe_req									= 1'b1												;
		lbe_wr_en								= 1'b0												;
		lbe_wdata								= 32'h0000_0000										;
		#10
		lbe_req									= 1'b0												;		

		//дsid_DID
		#1000
		lbe_addr								= 32'h8600_0000										;
		lbe_req									= 1'b1												;
		lbe_wr_en								= 1'b1												;
		lbe_wdata								= 32'h00aa_00cc										;
		#10
		lbe_req									= 1'b0												;	
		// 历史说明：原注释编码已损坏，已替换为中文维护说明。
		#1000
		lbe_addr								= 32'h8600_0000										;
		lbe_req									= 1'b1												;
		lbe_wr_en								= 1'b0												;
		lbe_wdata								= 32'h0000_0000										;
		#10
		lbe_req									= 1'b0												;	

	
	end
	

//	
//	defparam 	srio_test_prj_top.srio_top.ia_sp_config_top.i_sp_rst.CNT_VALUE	= 37'd1000			;
//	defparam 	srio_test_prj_top.srio_top.ib_sp_config_top.i_sp_rst.CNT_VALUE	= 37'd1000			;


endmodule


/*

cd D:/SRIO_ZL/srio_v10_lite_loop_srio/10_PRJ/00_PRJ.sim/sim_1/behav/modelsim
do tb_top_compile.do
do tb_top_simulate.do
run 220us

do tb_top_compile.do
restart
run 10us
*/


// 历史说明：原注释编码已损坏，已替换为中文维护说明。
//module rapidio_target_nread_response(
//    input           clk,                // 历史说明：原尾注编码已损坏，代码含义以保留代码为准。
//    input           rst_n,              // 历史说明：原尾注编码已损坏，代码含义以保留代码为准。
    
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
//    input           s_axis_iorx_tvalid, // 历史说明：原尾注编码已损坏，代码含义以保留代码为准。
//    input           s_axis_iorx_tlast,  // 历史说明：原尾注编码已损坏，代码含义以保留代码为准。
//    input  [63:0]   s_axis_iorx_tdata,  // 历史说明：原尾注编码已损坏，代码含义以保留代码为准。
//    input  [7:0]    s_axis_iorx_tkeep,  // 历史说明：原尾注编码已损坏，代码含义以保留代码为准。
//    input  [31:0]   s_axis_iorx_tuser,  // 历史说明：原尾注编码已损坏，代码含义以保留代码为准。
//    output          s_axis_iorx_tready, // 历史说明：原尾注编码已损坏，代码含义以保留代码为准。
    
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
//    output          m_axis_iotx_tvalid, // 历史说明：原尾注编码已损坏，代码含义以保留代码为准。
//    output          m_axis_iotx_tlast,  // 历史说明：原尾注编码已损坏，代码含义以保留代码为准。
//    output [63:0]   m_axis_iotx_tdata,  // 历史说明：原尾注编码已损坏，代码含义以保留代码为准。
//    output [7:0]    m_axis_iotx_tkeep,  // 历史说明：原尾注编码已损坏，代码含义以保留代码为准。
//    output [31:0]   m_axis_iotx_tuser,  // 历史说明：原尾注编码已损坏，代码含义以保留代码为准。
//    input           m_axis_iotx_tready  // 历史说明：原尾注编码已损坏，代码含义以保留代码为准。
//);

// 历史说明：原注释编码已损坏，已替换为中文维护说明。
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
//localparam NREAD_RESP_FTYPE = 4'b0010;  // 历史说明：原尾注编码已损坏，代码含义以保留代码为准。
//localparam NREAD_RESP_TTYPE = 4'b0100;  // 历史说明：原尾注编码已损坏，代码含义以保留代码为准。
//localparam DEVICE_ID_TARGET = 8'h01;    // 历史说明：原尾注编码已损坏，代码含义以保留代码为准。

// 历史说明：原注释编码已损坏，已替换为中文维护说明。
////typedef enum {IDLE, PARSE_REQUEST, BUILD_RESPONSE, SEND_RESPONSE} state_t;
//reg [3:0] current_state, next_state;

// 历史说明：原注释编码已损坏，已替换为中文维护说明。
//reg [31:0] req_addr;        // 历史说明：原尾注编码已损坏，代码含义以保留代码为准。
//reg [63:0] resp_data;       // 历史说明：原尾注编码已损坏，代码含义以保留代码为准。
//reg        resp_pending;    // 历史说明：原尾注编码已损坏，代码含义以保留代码为准。

// 历史说明：原注释编码已损坏，已替换为中文维护说明。
//always @(posedge clk or negedge rst_n) begin
//    if(!rst_n) begin
//        req_addr    <= 32'd0;
//        resp_pending <= 1'b0;
//    end else if(s_axis_iorx_tvalid && s_axis_iorx_tready) begin
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
//        if((s_axis_iorx_tuser[31:28] == NREAD_RESP_FTYPE) && 
//           (s_axis_iorx_tuser[27:24] == NREAD_RESP_TTYPE)) begin
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
//            req_addr <= s_axis_iorx_tdata[63:32];
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
//            case(req_addr)
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
//            endcase
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
//        end
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
//        if(s_axis_iorx_tlast) begin
//            resp_pending <= 1'b0;
//        end
//    end
//end

// 历史说明：原注释编码已损坏，已替换为中文维护说明。
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
//always @(posedge clk or negedge rst_n) begin
//    if(!rst_n) begin
//        current_state <= IDLE;
//    end else begin
//        current_state <= next_state;
//    end
//end

// 历史说明：原注释编码已损坏，已替换为中文维护说明。
//always @(*) begin
//    next_state = current_state;
//    case(current_state)
//        IDLE: begin
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
//            if(s_axis_iorx_tvalid && resp_pending) begin
//                next_state = PARSE_REQUEST;
//            end
//        end
//        PARSE_REQUEST: begin
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
//            next_state = BUILD_RESPONSE;
//        end
//        BUILD_RESPONSE: begin
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
//            if(m_axis_iotx_tready) begin
//                next_state = SEND_RESPONSE;
//            end
//        end
//        SEND_RESPONSE: begin
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
//            if(m_axis_iotx_tlast) begin
//                next_state = IDLE;
//            end
//        end
//        default: next_state = IDLE;
//    endcase
//end

// 历史说明：原注释编码已损坏，已替换为中文维护说明。
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
//reg tvalid_reg, tlast_reg;
//always @(posedge clk or negedge rst_n) begin
//    if(!rst_n) begin
//        tvalid_reg <= 1'b0;
//        tlast_reg  <= 1'b0;
//    end else if(current_state == SEND_RESPONSE) begin
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
//    end else begin
//        tvalid_reg <= 1'b0;
//        tlast_reg  <= 1'b0;
//    end
//end

// 历史说明：原注释编码已损坏，已替换为中文维护说明。
//reg [31:0] tuser_reg;
//always @(posedge clk or negedge rst_n) begin
//    if(!rst_n) begin
//        tuser_reg <= 32'd0;
//    end else if(current_state == BUILD_RESPONSE) begin
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
//        tuser_reg[31:28] = NREAD_RESP_FTYPE;    // [31:28] = FTYPE
//        tuser_reg[27:24] = NREAD_RESP_TTYPE;    // [27:24] = TTYPE
//        tuser_reg[23:16] = DEVICE_ID_TARGET;    // [23:16] = 8bit Device ID
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
//    end
//end

// 历史说明：原注释编码已损坏，已替换为中文维护说明。
//reg [63:0] tdata_reg;
//reg [7:0]  tkeep_reg;
//always @(posedge clk or negedge rst_n) begin
//    if(!rst_n) begin
//        tdata_reg <= 64'd0;
//        tkeep_reg <= 8'd0;
//    end else if(current_state == BUILD_RESPONSE) begin
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
//    end
//end

// 历史说明：原注释编码已损坏，已替换为中文维护说明。
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
//assign s_axis_iorx_tready = 1'b1;

// 历史说明：原注释编码已损坏，已替换为中文维护说明。
//assign m_axis_iotx_tvalid = tvalid_reg;
//assign m_axis_iotx_tlast  = tlast_reg;
//assign m_axis_iotx_tdata  = tdata_reg;
//assign m_axis_iotx_tkeep  = tkeep_reg;
//assign m_axis_iotx_tuser  = tuser_reg;

//endmodule
