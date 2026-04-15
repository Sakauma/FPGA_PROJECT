`timescale 1ns/1ns 
// ============================================================================
// 维护注释
//   文件职责      : SRIO 视频收发、解包、节流与协议辅助逻辑。
//   源码属性      : 手工维护源码，不要把修改同步到生成 IP 或网表。
//   更新要求      : 当时钟、复位、接口或数据顺序假设变化时，同步更新注释。
//   维护边界      : 注释用于说明当前实现意图，不替代接口协议文档。
// ============================================================================
////////////////////////////////////////////////////////////////////////////////////////////////////
// Company: 		ZHTY
// Engineer: 		ZYL
// 
// Create Date: 	2016/11/22 16:08:04
// Design Name: 
// Module Name: 	ic_axir_burst
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 妯″潡瀹炵幇鍩轰簬AXI4鎺ュ彛鐨凚urst璇绘搷浣?
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
/////////////////////////////////////////////////////////////////////////////////////////////////////
module zt_axi4_rb #(
	/*--------------------------------------------------------------------------------------
	--P_SIMULATION_R
	--------------------------------------------------------------------------------------*/
	parameter									P_SIMULATION_R			= "FALSE"
	)(
	/*--------------------------------------------------------------------------------------
	--Common Interface
	--------------------------------------------------------------------------------------*/	
	input										clk											,
	input										rst											,
	
	/*--------------------------------------------------------------------------------------
	--AXI4 Master Read Interface
	--------------------------------------------------------------------------------------*/	
	output	wire	[3:0]						M_AXI_ARID									,
	output	reg		[31:0]						M_AXI_ARADDR			= 0					,
	output	reg		[7:0]						M_AXI_ARLEN				= 0					,
	output	wire	[2:0]						M_AXI_ARSIZE								,
	output	wire	[1:0]						M_AXI_ARBURST								,
	output	wire								M_AXI_ARLOCK								,
	output	wire	[3:0]						M_AXI_ARCACHE								,
	output	wire	[2:0]						M_AXI_ARPROT								,
	output	wire	[3:0]						M_AXI_ARQOS									,
	output	wire								M_AXI_ARVALID								,
	input	wire								M_AXI_ARREADY								,

	/*--------------------------------------------------------------------------------------
	--璇昏姹傛帴鍙?
	--------------------------------------------------------------------------------------*/	
	input										m_axir_req									,
	output										m_axir_gnt									,
	input			[10:0]						m_axir_len64								,
	input			[31:0]						m_axir_addr
	
	);
//==================================================================================================
//--鍙傛暟瀹氫箟
	localparam		[10:0]						PARA_AXI_BURST_MAX		= 11'd64			;

//==================================================================================================
//--淇″彿瀹氫箟
	reg				[3:0]						S_AXI_NM									;
	(* fsm_safe_state	=	"reset_state"*)reg				[3:0]						S_AXI_CM									;
	
	localparam									S_AXI_IDLE_M			= 4'b0001			;
	localparam									S_AXI_SLICE_M			= 4'b0010			;
	localparam									S_AXI_AR_M				= 4'b0100			;
	localparam									S_AXI_DONE_M			= 4'b1000			;
												
	reg				[10:0]						axi_len					= 0					;
	reg											axi_last				= 0					;
//==================================================================================================
//--AXI璇绘帴鍙ｇ姸鎬佹満瀹炵幇
	always @(posedge clk or posedge rst) begin
		if(rst) begin
			S_AXI_CM							<= S_AXI_IDLE_M								;
		end else begin
			S_AXI_CM							<= S_AXI_NM									;
		end
	end
	/*--------------------------------------------------------------------------------------
	----鐘舵€佹満鐢ㄤ簬瀹炵幇AXI瀛樺偍鍣ㄦ暟鎹鍐?
	--axi_s
	--S_AXI_IDLE_M------>绌洪棽鐘舵€侊紝绛夊緟璇锋眰
	--S_AXI_SLICE_M----->鎷嗗垎璇锋眰
	--S_AXI_AR_M-------->鍙戦€佹媶鍒嗗悗鐨勮璇锋眰
	--S_AXI_DONE_M------>瀹屾垚鐘舵€?
	--------------------------------------------------------------------------------------*/
	always @(*) begin
		S_AXI_NM								= 'bx										;
		case(S_AXI_CM)
			S_AXI_IDLE_M						: begin
				if(m_axir_req) begin
					S_AXI_NM					= S_AXI_SLICE_M								;
				end else begin
					S_AXI_NM					= S_AXI_IDLE_M								;
				end
			end
			S_AXI_SLICE_M						: begin
				S_AXI_NM						= S_AXI_AR_M								;
			end
			S_AXI_AR_M							: begin
				if(M_AXI_ARREADY && M_AXI_ARVALID && axi_last) begin
					S_AXI_NM					= S_AXI_DONE_M								;
				end else if(M_AXI_ARREADY && M_AXI_ARVALID) begin
					S_AXI_NM					= S_AXI_SLICE_M								;
				end else begin
					S_AXI_NM					= S_AXI_AR_M								;
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
	--淇″彿瀹炵幇
	--------------------------------------------------------------------------------------*/	
	assign	m_axir_gnt							= (S_AXI_CM==S_AXI_DONE_M)?1'b1:1'b0		;

	/*--------------------------------------------------------------------------------------
	--axi_len涓巃xi_last淇″彿瀹炵幇
	--------------------------------------------------------------------------------------*/	
	always @(posedge clk) begin
		case(S_AXI_CM)
			S_AXI_IDLE_M	: begin
				axi_len							<= m_axir_len64								;
				axi_last						<= 1'b0										;
			end
			S_AXI_SLICE_M	: begin
				if(axi_len>PARA_AXI_BURST_MAX) begin
					axi_len						<= axi_len - PARA_AXI_BURST_MAX				;
					axi_last					<= 1'b0										;
				end else begin
					axi_len						<= axi_len									;
					axi_last					<= 1'b1										;
				end
			end
			S_AXI_DONE_M	: begin
				axi_len							<= 11'b0									;
				axi_last						<= 1'b0										;
			end
			default			: begin
				axi_len							<= axi_len									;
				axi_last						<= axi_last									;
			end
		endcase
	end
	
	/*--------------------------------------------------------------------------------------
	--M_AXI_ARADDR淇″彿瀹炵幇
	--------------------------------------------------------------------------------------*/
	always @(posedge clk) begin
		case(S_AXI_CM)
			S_AXI_IDLE_M	: begin
				M_AXI_ARADDR					<= m_axir_addr								;
			end
			S_AXI_AR_M		: begin
				if(M_AXI_ARREADY && M_AXI_ARVALID && !axi_last)begin
					M_AXI_ARADDR				<= M_AXI_ARADDR + PARA_AXI_BURST_MAX*8		;
				end else begin
					M_AXI_ARADDR				<= M_AXI_ARADDR								;
				end
			end
			S_AXI_DONE_M	: begin
				M_AXI_ARADDR					<= 32'b0									;
			end
			default			: begin
				M_AXI_ARADDR					<= M_AXI_ARADDR								;
			end
		endcase
	end
	
	/*--------------------------------------------------------------------------------------
	--M_AXI_ARLEN淇″彿瀹炵幇
	--------------------------------------------------------------------------------------*/	
	always @(posedge clk) begin
		case(S_AXI_CM)
			S_AXI_IDLE_M	: begin
				M_AXI_ARLEN						<= 8'd0										;
			end
			S_AXI_SLICE_M	: begin
				if(axi_len>PARA_AXI_BURST_MAX) begin
					M_AXI_ARLEN					<= PARA_AXI_BURST_MAX - 1'b1				;
				end else begin
					M_AXI_ARLEN					<= axi_len - 1'b1							;
				end
			end
			S_AXI_DONE_M	: begin
				M_AXI_ARLEN						<= 8'b0										;
			end
			default			: begin
				M_AXI_ARLEN						<= M_AXI_ARLEN								;
			end
		endcase
	end
	
	/*--------------------------------------------------------------------------------------
	--M_AXI_ARVALID淇″彿瀹炵幇
	--------------------------------------------------------------------------------------*/	
	assign	M_AXI_ARVALID						= (S_AXI_CM==S_AXI_AR_M)?1'b1:1'b0			;
	
	assign	M_AXI_ARSIZE						= 3'b011									;	//Burst Size==8*8=64bit
	assign	M_AXI_ARBURST						= 2'b01										;
	assign	M_AXI_ARLOCK						= 1'b0										;
	assign	M_AXI_ARCACHE						= 4'b0000									;
	assign	M_AXI_ARPROT						= 3'b000									;
	assign	M_AXI_ARQOS							= 4'b0000									;	//MIG Slave not used
	assign	M_AXI_ARID							= 4'b0000									;	//淇濊瘉椤哄簭涓€鑷存€э紝缁熶竴鐢ㄤ竴涓狝RID

endmodule
