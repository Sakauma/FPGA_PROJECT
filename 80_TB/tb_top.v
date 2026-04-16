`timescale 1ns/1ps
// ============================================================================
// 新增维护说明
// 文件职责      : 当前文件为手工维护源码，承担本模块/脚本的真实实现。
// 维护边界      : 本注释块仅补充维护说明，不改写任何原有说明、历史注释或现有逻辑。
// 修改约束      : 后续如需继续补充说明，只允许追加中文注释，不得替换旧注释或改动旧代码。
// 生成关系      : 若存在对应生成物，应以当前手工源码为准，禁止反向覆盖本文件。
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
仿真语言需要选择mixed

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
		
//		//读485——0波特率
//		#1000
//		lbe_addr								= 32'h82b1_0000										;
//		lbe_req									= 1'b1												;
//		lbe_wr_en								= 1'b0												;
//		lbe_wdata								= 32'h0000_0000										;
//		#10
//		lbe_req									= 1'b0												;
	
	
		//写降频使能
		#1000
		lbe_addr								= 32'h8122_0000										;
		lbe_req									= 1'b1												;
		lbe_wr_en								= 1'b1												;
		lbe_wdata								= 32'h0000_0001										;
		#10	
		//写降频参数
		#1000
		lbe_addr								= 32'h8122_0008										;
		lbe_req									= 1'b1												;
		lbe_wr_en								= 1'b1												;
		lbe_wdata								= 32'h0000_0040										;
		#10			
		//写485——0波特率
		#1000
		lbe_addr								= 32'h82b1_0000										;
		lbe_req									= 1'b1												;
		lbe_wr_en								= 1'b1												;
		lbe_wdata								= 32'h0000_1000										;
		#10
		lbe_req									= 1'b0												;		

		//读485——0波特率
		#1000
		lbe_addr								= 32'h82b1_0000										;
		lbe_req									= 1'b1												;
		lbe_wr_en								= 1'b0												;
		lbe_wdata								= 32'h0000_0000										;
		#10
		lbe_req									= 1'b0												;


		//读srio
		#1000
		lbe_addr								= 32'h8400_0000										;
		lbe_req									= 1'b1												;
		lbe_wr_en								= 1'b0												;
		lbe_wdata								= 32'h0000_0000										;
		#10
		lbe_req									= 1'b0												;
		
		
		
		//读sid_DID
		#1000
		lbe_addr								= 32'h8600_0000										;
		lbe_req									= 1'b1												;
		lbe_wr_en								= 1'b0												;
		lbe_wdata								= 32'h0000_0000										;
		#10
		lbe_req									= 1'b0												;		

		//写sid_DID
		#1000
		lbe_addr								= 32'h8600_0000										;
		lbe_req									= 1'b1												;
		lbe_wr_en								= 1'b1												;
		lbe_wdata								= 32'h00aa_00cc										;
		#10
		lbe_req									= 1'b0												;	
		//读sid_DID
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


//// 模块功能：RapidIO目标端，接收NREAD请求后通过iotx端口发送响应包
//module rapidio_target_nread_response(
//    input           clk,                // RapidIO IP核时钟（建议125MHz）
//    input           rst_n,              // 异步复位（低有效）
    
//    // RapidIO Condensed I/O 接收端口（收NREAD请求）
//    input           s_axis_iorx_tvalid, // 请求有效
//    input           s_axis_iorx_tlast,  // 请求包结束
//    input  [63:0]   s_axis_iorx_tdata,  // 请求数据（含地址/头部）
//    input  [7:0]    s_axis_iorx_tkeep,  // 请求字节有效
//    input  [31:0]   s_axis_iorx_tuser,  // 请求控制信息（FTYPE/TTYPE/Device ID）
//    output          s_axis_iorx_tready, // 接收准备就绪
    
//    // RapidIO Condensed I/O 发送端口（发NREAD响应，核心iotx端口）
//    output          m_axis_iotx_tvalid, // 响应有效
//    output          m_axis_iotx_tlast,  // 响应包结束
//    output [63:0]   m_axis_iotx_tdata,  // 响应数据（含头部/载荷）
//    output [7:0]    m_axis_iotx_tkeep,  // 响应字节有效
//    output [31:0]   m_axis_iotx_tuser,  // 响应控制信息（FTYPE/TTYPE/Device ID）
//    input           m_axis_iotx_tready  // 发送准备就绪（IP核侧）
//);

//// -------------------------- 步骤1：参数定义（核心编码） --------------------------
//// NREAD响应的FTYPE/TTYPE编码（参考文档：FTYPE=0010, TTYPE=0100）
//localparam NREAD_RESP_FTYPE = 4'b0010;  // NREAD响应功能类型编码
//localparam NREAD_RESP_TTYPE = 4'b0100;  // NREAD响应事务类型编码
//localparam DEVICE_ID_TARGET = 8'h01;    // 目标端8bit Device ID（可自定义）

//// 状态机定义：处理NREAD请求→构造响应→发送响应
////typedef enum {IDLE, PARSE_REQUEST, BUILD_RESPONSE, SEND_RESPONSE} state_t;
//reg [3:0] current_state, next_state;

//// -------------------------- 步骤2：请求解析与响应缓存 --------------------------
//reg [31:0] req_addr;        // 解析出的NREAD请求地址（要读取的地址）
//reg [63:0] resp_data;       // NREAD响应数据载荷（模拟从寄存器读取）
//reg        resp_pending;    // 响应待发送标志

//// 解析NREAD请求：提取FTYPE/TTYPE/请求地址
//always @(posedge clk or negedge rst_n) begin
//    if(!rst_n) begin
//        req_addr    <= 32'd0;
//        resp_pending <= 1'b0;
//    end else if(s_axis_iorx_tvalid && s_axis_iorx_tready) begin
//        // 解析请求头部：判断是否为NREAD请求（FTYPE=0010, TTYPE=0100）
//        if((s_axis_iorx_tuser[31:28] == NREAD_RESP_FTYPE) && 
//           (s_axis_iorx_tuser[27:24] == NREAD_RESP_TTYPE)) begin
//            // 提取NREAD请求的目标地址（从tdata高32bit解析）
//            req_addr <= s_axis_iorx_tdata[63:32];
//            // 模拟：根据请求地址读取对应数据（实际项目中替换为寄存器/内存读取）
//            case(req_addr)
//                32'h00604000: resp_data <= 64'h0001020304050607; // 示例数据1
//                32'h00604008: resp_data <= 64'h08090a0b0c0d0e0f; // 示例数据2
//                default:      resp_data <= 64'hdeadbeefdeadbeef; // 无效地址返回默认值
//            endcase
//            resp_pending <= 1'b1; // 标记需要发送响应
//        end
//        // 包结束时清空待发送标志（防止重复响应）
//        if(s_axis_iorx_tlast) begin
//            resp_pending <= 1'b0;
//        end
//    end
//end

//// -------------------------- 步骤3：状态机控制 --------------------------
//// 状态机时序逻辑
//always @(posedge clk or negedge rst_n) begin
//    if(!rst_n) begin
//        current_state <= IDLE;
//    end else begin
//        current_state <= next_state;
//    end
//end

//// 状态机组合逻辑
//always @(*) begin
//    next_state = current_state;
//    case(current_state)
//        IDLE: begin
//            // 收到有效NREAD请求，进入解析阶段
//            if(s_axis_iorx_tvalid && resp_pending) begin
//                next_state = PARSE_REQUEST;
//            end
//        end
//        PARSE_REQUEST: begin
//            // 解析完成，进入响应构造阶段
//            next_state = BUILD_RESPONSE;
//        end
//        BUILD_RESPONSE: begin
//            // 响应构造完成，IP核准备就绪则发送
//            if(m_axis_iotx_tready) begin
//                next_state = SEND_RESPONSE;
//            end
//        end
//        SEND_RESPONSE: begin
//            // 响应发送完成（tlast拉高），回到空闲
//            if(m_axis_iotx_tlast) begin
//                next_state = IDLE;
//            end
//        end
//        default: next_state = IDLE;
//    endcase
//end

//// -------------------------- 步骤4：iotx端口响应发送 --------------------------
//// 1. 控制信号：tvalid（响应有效）、tlast（响应结束）
//reg tvalid_reg, tlast_reg;
//always @(posedge clk or negedge rst_n) begin
//    if(!rst_n) begin
//        tvalid_reg <= 1'b0;
//        tlast_reg  <= 1'b0;
//    end else if(current_state == SEND_RESPONSE) begin
//        tvalid_reg <= 1'b1;        // 响应有效
//        tlast_reg  <= 1'b1;        // 单beat响应，直接标记结束
//    end else begin
//        tvalid_reg <= 1'b0;
//        tlast_reg  <= 1'b0;
//    end
//end

//// 2. 响应头部：tuser（FTYPE/TTYPE/Device ID）
//reg [31:0] tuser_reg;
//always @(posedge clk or negedge rst_n) begin
//    if(!rst_n) begin
//        tuser_reg <= 32'd0;
//    end else if(current_state == BUILD_RESPONSE) begin
//        // 构造tuser：高4bit=FTYPE，次4bit=TTYPE，接下来8bit=目标Device ID
//        tuser_reg[31:28] = NREAD_RESP_FTYPE;    // [31:28] = FTYPE
//        tuser_reg[27:24] = NREAD_RESP_TTYPE;    // [27:24] = TTYPE
//        tuser_reg[23:16] = DEVICE_ID_TARGET;    // [23:16] = 8bit Device ID
//        tuser_reg[15:0]  = 16'd0;               // 保留位（可扩展事务ID）
//    end
//end

//// 3. 响应数据：tdata（头部+数据载荷）、tkeep（字节有效）
//reg [63:0] tdata_reg;
//reg [7:0]  tkeep_reg;
//always @(posedge clk or negedge rst_n) begin
//    if(!rst_n) begin
//        tdata_reg <= 64'd0;
//        tkeep_reg <= 8'd0;
//    end else if(current_state == BUILD_RESPONSE) begin
//        tdata_reg <= resp_data;    // 响应数据载荷（模拟读取的内容）
//        tkeep_reg <= 8'hff;       // 8字节全有效（64bit总线）
//    end
//end

//// -------------------------- 步骤5：端口信号赋值 --------------------------
//// 接收端口：始终准备就绪（可根据实际场景调整）
//assign s_axis_iorx_tready = 1'b1;

//// 发送端口（iotx核心）：绑定寄存器输出
//assign m_axis_iotx_tvalid = tvalid_reg;
//assign m_axis_iotx_tlast  = tlast_reg;
//assign m_axis_iotx_tdata  = tdata_reg;
//assign m_axis_iotx_tkeep  = tkeep_reg;
//assign m_axis_iotx_tuser  = tuser_reg;

//endmodule