`timescale 1ns/1ns
// ============================================================================
// 新增维护说明
// 作者          : Egor Izmaylov
// 文件职责      : 当前文件为手工维护源码，具体职责见模块名、端口和上层实例化。
// 维护边界      : 只追加说明性注释；Vivado/IP 生成物和第三方支撑代码不在此处手改。
// 修改约束      : 功能改动需同步更新仿真、综合结果和相关文档。
// ============================================================================
//////////////////////////////////////////////////////////////////////////////////
// Company:			ZHTY
// Engineer:		ZYL
// Create Date:		2021/9/5 16:17:20
// Design Name:		IR2120
// Module Name:		srio_cache_write
// Project Name:
// Target Devices:	K7-V7
// Tool Versions: 	Vivado 2016.1 HDL-EDIT UltraEdit TAB=4 Consolas
// Description:
//		this module write lvds data into ddr3 buffer
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
//////////////////////////////////////////////////////////////////////////////////
module srio_v_fifo_to_bram_write (
//==================================================================================================
	input										sys_rst_i									,
	input										sys_clk_i									,
	
	input			[31:0]						srio_trn_fifo_dout_i						,
	output										srio_trn_fifo_ren_o							,
	input										srio_trn_fifo_empty_i						,
	
	output	wire	[31:0]						srio_cache_cur_waddr						,
	output										m_axiw_req									,
	
	input										m_axiw_gnt									,
	output	reg		[10:0]						m_axiw_len64			= 0					,
	output	reg		[31:0]						m_axiw_addr				= 0					,
	output			[ 7:0]						m_axiw_wstrb								
	);
	
//			ila_test	ila_wfifo(
//		.clk                        			( sys_clk_i								),
//		.probe0                                  ( {
//		srio_trn_fifo_dout_i,
//		m_axiw_addr,
//	srio_trn_fifo_ren_o,
//	m_axiw_gnt,
//		srio_trn_fifo_empty_i,

//		m_axiw_len64,
//		m_axiw_addr							,
	
//						m_axiw_wstrb							,
//							S_AXIW_CM							,
                       
// m_axiw_req   	,
//sys_rst_i
//																							})
//	);	
	
//==================================================================================================
//--param defines	
	/*--------------------------------------------------------------------------------------
	--S_AXIW_State
	--------------------------------------------------------------------------------------*/
	localparam		S_AXIW_IDLE_M				= 5'b00001									;
	localparam		S_AXIW_REQ_M				= 5'b00010									;
	localparam		S_AXIW_WAIT_M				= 5'b00100									;
	localparam		S_AXIW_DONE_M				= 5'b01000									;
	localparam		S_AXIW_WAIT_READ_M			= 5'b10000									;
	
	localparam		B_AXIW_REQ_M				= 3'd1										;
	localparam		B_AXIW_WAIT_M				= 3'd2										;
	localparam		B_AXIW_DONE_M				= 3'd3										;	
	localparam		B_AXIW_WAIT_READ_M			= 3'd4										;	
//==================================================================================================
//--Signals define
	/*--------------------------------------------------------------------------------------
	--AXIW State signals
	--------------------------------------------------------------------------------------*/	
	reg				[B_AXIW_WAIT_READ_M:0]		S_AXIW_CM									;
	reg				[B_AXIW_WAIT_READ_M:0]		S_AXIW_NM									;

	reg				[127:0]						S_AXIW_CM_acii								;

	always @(*) begin
        case(S_AXIW_CM)
           S_AXIW_IDLE_M		  : S_AXIW_CM_acii<= "IDLE_M";
           S_AXIW_REQ_M		      : S_AXIW_CM_acii<= "REQ_M";
           S_AXIW_WAIT_M		  : S_AXIW_CM_acii<= "WAIT_M";
           S_AXIW_DONE_M		  : S_AXIW_CM_acii<= "DONE_M";
           S_AXIW_WAIT_READ_M	  : S_AXIW_CM_acii<= "WAIT_READ_M";
            default               : S_AXIW_CM_acii<= "defaule";
        endcase
	end
	
	/*--------------------------------------------------------------------------------------
	--length--to 64bit
	--------------------------------------------------------------------------------------*/	
	wire			[10:0]						data_len64									;
	reg				[31:0]						cur_addr									;
//==================================================================================================
//--pre assign
	wire			[31:0]	srio_addr			= {8'h00,srio_trn_fifo_dout_i [31:16],8'h00} ;

	assign	data_len64							= srio_trn_fifo_dout_i[0]==1'b1
												? srio_trn_fifo_dout_i[11:1] + 1'b1
												: srio_trn_fifo_dout_i[11:1]				;
	
		
//==================================================================================================
//--LVDS Data write to DDR3
	always @(posedge sys_clk_i or posedge sys_rst_i) begin
		if(sys_rst_i) begin
			S_AXIW_CM							<= S_AXIW_IDLE_M							;
		end else begin
			S_AXIW_CM							<= S_AXIW_NM								;
		end
	end
	
	always @(*) begin
		S_AXIW_NM								= S_AXIW_IDLE_M								;
		case(S_AXIW_CM)
			S_AXIW_IDLE_M						: begin
				if(!srio_trn_fifo_empty_i)	begin
					S_AXIW_NM					= S_AXIW_REQ_M								;
				end else begin
					S_AXIW_NM					= S_AXIW_IDLE_M								;
				end
			end
			S_AXIW_REQ_M						: begin
				S_AXIW_NM						= S_AXIW_WAIT_M								;
			end
			S_AXIW_WAIT_M						: begin
				if(m_axiw_gnt) begin
					S_AXIW_NM					= S_AXIW_DONE_M								;
				end else begin
					S_AXIW_NM					= S_AXIW_WAIT_M								;
				end
			end
			S_AXIW_DONE_M						: begin
				S_AXIW_NM						= S_AXIW_IDLE_M								;
			end
			default								: begin
				S_AXIW_NM						= S_AXIW_IDLE_M								;
			end
		endcase
	end
//==================================================================================================
//--address length	
	always @(posedge sys_clk_i or posedge sys_rst_i) begin
		if(sys_rst_i) begin
			m_axiw_len64						<= 11'b0									;
			m_axiw_addr							<= 32'b0									;
		end else if(S_AXIW_NM[B_AXIW_REQ_M]) begin
			m_axiw_len64						<= data_len64								;
			m_axiw_addr							<= srio_addr								;
		end else begin
			m_axiw_len64						<= m_axiw_len64								;
			m_axiw_addr							<= m_axiw_addr								;
		end
	end
	
	assign	m_axiw_req							= S_AXIW_CM[B_AXIW_REQ_M] 
												||S_AXIW_CM[B_AXIW_WAIT_M]					;
	assign	m_axiw_wstrb						= 8'hFF										;
//==================================================================================================
//--trn fifo read	
	assign	srio_trn_fifo_ren_o					= S_AXIW_CM[B_AXIW_DONE_M]					;
//==================================================================================================
//--Address cache
	always @(posedge sys_clk_i or posedge sys_rst_i) begin
		if(sys_rst_i) begin
			cur_addr							<= 'b0										;
		end else if(S_AXIW_NM[B_AXIW_DONE_M]) begin
			cur_addr							<= srio_addr								;
		end else begin
			cur_addr							<= cur_addr									;

		end
	end
	
	assign	srio_cache_cur_waddr				= cur_addr									;

endmodule