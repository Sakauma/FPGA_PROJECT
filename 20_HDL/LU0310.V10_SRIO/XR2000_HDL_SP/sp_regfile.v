 `timescale 1ns/1ns
// ============================================================================
// 新增维护说明
// 作者          : Egor Izmaylov
// 文件职责      : 当前文件为手工维护源码，具体职责见模块名、端口和上层实例化。
// 维护边界      : 只追加说明性注释；Vivado/IP 生成物和第三方支撑代码不在此处手改。
// 修改约束      : 功能改动需同步更新仿真、综合结果和相关文档。
// ============================================================================
//////////////////////////////////////////////////////////////////////////////////
// Company:			HXZY
// Engineer:		ZYL
// Create Date:		2018/5/11 19:40:24
// Design Name:		XR2000
// Module Name:		xr2000_regfile_log
// Project Name:
// Target Devices:	K7-V7
// Tool Versions: 	Vivado 2016.1 HDL-EDIT UltraEdit TAB=4 Consolas
// Description:
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
//////////////////////////////////////////////////////////////////////////////////
module sp_regfile #(
	/*--------------------------------------------------------------------------------------
	--P_SIMULATION_R
	---------------------------------------------------------------------------------------*/
	parameter		P_SIMULATION_R				= "FALSE"
	)(
//==================================================================================================
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
	/*--------------------------------------------------------------------------------------
	--Common Interface
	* 历史说明：原块注释编码已损坏，按当前文件头和开发文档维护。
	* 历史说明：原块注释编码已损坏，按当前文件头和开发文档维护。
	--------------------------------------------------------------------------------------*/
	input										rst											,
	input										clk											,
                                                                                       	
	/*--------------------------------------------------------------------------------------
	--regfile signals output
	--------------------------------------------------------------------------------------*/
	input			[31:0]						reg_waddr									,
	input										reg_wvalid									,
	input			[31:0]						reg_wdata									,

	input			[31:0]						reg_raddr									,
	output	reg		[31:0]						reg_rdata					= 0				,

	/*--------------------------------------------------------------------------------------
	--reg out
	--------------------------------------------------------------------------------------*/
	output	reg		[31:0]						reg_srio_reset_time_c		= 0				,
	output	reg									reg_srio_reset_enable_c		= 0				,
	output	reg									reg_srio_reset_trig_c		= 0				,

	/*--------------------------------------------------------------------------------------
	--Link Status
	--------------------------------------------------------------------------------------*/
	input										port_error									,
	input										port_initialized							,
	input										link_initialized							,
	input										mode_1x										,
	/*--------------------------------------------------------------------------------------
	--SP CNT
	--------------------------------------------------------------------------------------*/
	input			[31:0]						c_sp_tx_cnt									,
	input			[31:0]						c_sp_rx_cnt									,
	
	/*--------------------------------------------------------------------------------------
	--BM Count
	--------------------------------------------------------------------------------------*/

	input			[31:0]						c_bm_recv_cnt								,
	input			[31:0]						c_bm_up_cnt									,
	input			[31:0]						c_bm_lost_cnt								,
	output	reg									c_bm_en										,	
	
	/*--------------------------------------------------------------------------------------
	* 历史说明：原块注释编码已损坏，按当前文件头和开发文档维护。
	--------------------------------------------------------------------------------------*/
	(*mark_debug="TRUE"*)
	output	reg									c_s_m_rst					= 0				,
	
	(*mark_debug="TRUE"*)
	output	reg		[31:0]						c_s_m_waddr					= 0				,
	(*mark_debug="TRUE"*)
	output	reg		[31:0]						c_s_m_wdata					= 0				,
	(*mark_debug="TRUE"*)
	output	reg									c_s_m_wstart				= 0				,
	(*mark_debug="TRUE"*)
	input										c_s_m_wdone									,
	(*mark_debug="TRUE"*)
	input			[1:0]						c_s_m_wstatus_set							,
	
	(*mark_debug="TRUE"*)
	output	reg		[31:0]						c_s_m_raddr					= 0				,
	(*mark_debug="TRUE"*)
	output	reg									c_s_m_rstart				= 0				,
	(*mark_debug="TRUE"*)
	input										c_s_m_rdone									,
	(*mark_debug="TRUE"*)
	input			[31:0]						c_s_m_rdata_set								,
	(*mark_debug="TRUE"*)
	input			[1:0]						c_s_m_rstatus_set
	);
//==================================================================================================
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
	/*--------------------------------------------------------------------------------------
	* 历史说明：原块注释编码已损坏，按当前文件头和开发文档维护。
	--------------------------------------------------------------------------------------*/
	localparam		OFF_SRIO_REV				= 12'h000									;
	localparam		OFF_SRIO_RST_TIME			= 12'h010									;
	localparam		OFF_SRIO_RST_DISABLE		= 12'h014									;
	localparam		OFF_SRIO_RST_TRIG			= 12'h018									;

	localparam		OFF_SP_PORT_INI				= 12'h100									;
	localparam		OFF_SP_PORT_ERR				= 12'h104									;
	localparam		OFF_SP_LINK_INI				= 12'h108									;
	localparam		OFF_SP_MODE_1X				= 12'h10C									;

	/*--------------------------------------------------------------------------------------
	--SP TX/RX Count
	--------------------------------------------------------------------------------------*/
	localparam		OFF_SP_TX_CNT				= 12'h200									;
	localparam		OFF_SP_RX_CNT				= 12'h210									;

	/*--------------------------------------------------------------------------------------
	* 历史说明：原块注释编码已损坏，按当前文件头和开发文档维护。
	--------------------------------------------------------------------------------------*/
	localparam		OFF_S_M_WADDR				= 12'h300									;	// 历史说明：原尾注编码已损坏，代码含义以信号名和开发文档为准。
	localparam		OFF_S_M_WDATA				= 12'h304									;	// 历史说明：原尾注编码已损坏，代码含义以信号名和开发文档为准。
	localparam		OFF_S_M_WSTATUS				= 12'h308									;	// 历史说明：原尾注编码已损坏，代码含义以信号名和开发文档为准。

	localparam		OFF_S_M_RADDR				= 12'h310									;	// 历史说明：原尾注编码已损坏，代码含义以信号名和开发文档为准。
	localparam		OFF_S_M_RDATA				= 12'h314									;	// 历史说明：原尾注编码已损坏，代码含义以信号名和开发文档为准。
	localparam		OFF_S_M_RSTATUS				= 12'h318									;	// 历史说明：原尾注编码已损坏，代码含义以信号名和开发文档为准。
	
	localparam		OFF_S_RST					= 12'h320									;	//trig maintr reset
	/*--------------------------------------------------------------------------------------
	* 历史说明：原块注释编码已损坏，按当前文件头和开发文档维护。
	--------------------------------------------------------------------------------------*/	
	localparam		OFF_BM_EN					= 12'h400									;
	localparam		OFF_BM_RECV_CNT				= 12'h410									;
	localparam		OFF_BM_UP_CNT				= 12'h414									;
	localparam		OFF_BM_LOST_CNT				= 12'h418									;
//==================================================================================================
//--SRIO Reset relax
	always @(posedge clk or posedge rst) begin
		if(rst) begin
			reg_srio_reset_time_c				<= 32'd512									;
		end else if(reg_wvalid && reg_waddr[11:0]==OFF_SRIO_RST_TIME) begin
			reg_srio_reset_time_c				<= reg_wdata[31:0]							;
		end else begin
			reg_srio_reset_time_c				<= reg_srio_reset_time_c					;
		end
	end

	always @(posedge clk or posedge rst) begin
		if(rst) begin
			reg_srio_reset_enable_c				<= 1'b0										;
		end else if(reg_wvalid && reg_waddr[11:0]==OFF_SRIO_RST_DISABLE) begin
			reg_srio_reset_enable_c				<= reg_wdata[0]								;
		end else begin
			reg_srio_reset_enable_c				<= reg_srio_reset_enable_c					;
		end
	end

	always @(posedge clk or posedge rst) begin
		if(rst) begin
			reg_srio_reset_trig_c				<= 1'b0										;
		end else if(reg_wvalid && reg_waddr[11:0]==OFF_SRIO_RST_TRIG) begin
			reg_srio_reset_trig_c				<= 1'b1										;
		end else begin
			reg_srio_reset_trig_c				<= 1'b0										;
		end
	end

//==================================================================================================
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
	/*--------------------------------------------------------------------------------------
	* 历史说明：原块注释编码已损坏，按当前文件头和开发文档维护。
	--------------------------------------------------------------------------------------*/
	reg				[31:0]						c_s_m_wstatus								;

	always @(posedge clk) begin
		if(reg_wvalid && reg_waddr[11:0]==OFF_S_M_WADDR) begin
			c_s_m_waddr							<= reg_wdata[31:0]							;
		end else begin
			c_s_m_waddr							<= c_s_m_waddr								;
		end
	end

	always @(posedge clk) begin
		if(reg_wvalid && reg_waddr[11:0]==OFF_S_M_WDATA) begin
			c_s_m_wdata							<= reg_wdata[31:0]							;
			c_s_m_wstart						<= 1'b1										;
		end else begin
			c_s_m_wdata							<= c_s_m_wdata								;
			c_s_m_wstart						<= 1'b0										;
		end
	end

	always @(posedge clk) begin
		if(reg_wvalid && reg_waddr[11:0]==OFF_S_M_WSTATUS) begin
			c_s_m_wstatus						<= 32'b0									;
		end else if(c_s_m_wdone) begin
			c_s_m_wstatus						<= {1'b1,29'b0,c_s_m_wstatus_set[1:0]}		;
		end else begin
			c_s_m_wstatus						<= c_s_m_wstatus							;
		end
	end
	
	always @(posedge clk) begin
		if(reg_wvalid && reg_waddr[11:0]==OFF_S_RST) begin
			c_s_m_rst							<= 1'b1										;
		end else begin
			c_s_m_rst							<= 1'b0										;
		end
	end

//==================================================================================================
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
	/*--------------------------------------------------------------------------------------
	* 历史说明：原块注释编码已损坏，按当前文件头和开发文档维护。
	--------------------------------------------------------------------------------------*/

	reg				[31:0]						c_s_m_rstatus								;
	reg				[31:0]						c_s_m_rdata									;

	always @(posedge clk) begin
		if(reg_wvalid && reg_waddr[11:0]==OFF_S_M_RADDR) begin
			c_s_m_raddr							<= reg_wdata[31:0]							;
			c_s_m_rstart						<= 1'b1										;
		end else begin
			c_s_m_raddr							<= c_s_m_raddr								;
			c_s_m_rstart						<= 1'b0										;
		end
	end

	always @(posedge clk) begin
		if(reg_wvalid && reg_waddr[11:0]==OFF_S_M_RSTATUS) begin
			c_s_m_rdata							<= 32'b0									;
		end else if(c_s_m_rdone) begin
			c_s_m_rdata							<= c_s_m_rdata_set							;
		end else begin
			c_s_m_rdata							<= c_s_m_rdata								;
		end
	end

	always @(posedge clk) begin
		if(reg_wvalid && reg_waddr[11:0]==OFF_S_M_RSTATUS) begin
			c_s_m_rstatus						<= 32'b0									;
		end else if(c_s_m_rdone) begin
			c_s_m_rstatus						<= {1'b1,29'b0,c_s_m_rstatus_set[1:0]}		;
		end else begin
			c_s_m_rstatus						<= c_s_m_rstatus							;
		end
	end
//==================================================================================================
//--BM enable
	always @(posedge clk) begin
		if(reg_wvalid && reg_waddr[11:0]==OFF_BM_EN) begin
			c_bm_en								<= reg_wdata[0]								;
		end else begin
			c_bm_en								<= c_bm_en									;
		end
	end

//==================================================================================================
// 历史说明：原注释编码已损坏，已替换为中文维护说明。
	always @(posedge clk) begin
		case(reg_raddr[11:0])
			OFF_SRIO_REV						: begin
				reg_rdata						<= 32'h0000_0001							;
			end
			OFF_SP_PORT_INI						: begin
				reg_rdata						<=	{
														28'b0								,
														mode_1x								,
														link_initialized					,
														port_error							,
														port_initialized					
													}										;				
			end
			OFF_SP_PORT_ERR						: begin
				reg_rdata						<= {31'b0,port_error}						;
			end
			OFF_SP_LINK_INI						: begin
				reg_rdata						<= {31'b0,link_initialized}					;
			end
			OFF_SP_MODE_1X						: begin
				reg_rdata						<= {31'b0,mode_1x}							;
			end
			OFF_SP_TX_CNT						: begin
				reg_rdata						<= c_sp_tx_cnt								;
			end
			OFF_SP_RX_CNT						: begin
				reg_rdata						<= c_sp_rx_cnt								;
			end
			OFF_S_M_WADDR						: begin
				reg_rdata						<= c_s_m_waddr								;
			end
			OFF_S_M_WDATA						: begin
				reg_rdata						<= c_s_m_wdata								;
			end
			OFF_S_M_WSTATUS						: begin
				reg_rdata						<= c_s_m_wstatus							;
			end
			OFF_S_M_RADDR						: begin
				reg_rdata						<= c_s_m_raddr								;
			end
			OFF_S_M_RDATA						: begin
				reg_rdata						<= c_s_m_rdata								;
			end
			OFF_S_M_RSTATUS						: begin
				reg_rdata						<= c_s_m_rstatus							;
			end
			
			OFF_BM_LOST_CNT						: begin
				reg_rdata						<= c_bm_lost_cnt							;
			end
			OFF_BM_RECV_CNT						: begin
				reg_rdata						<= c_bm_recv_cnt							;
			end
			OFF_BM_UP_CNT						: begin
				reg_rdata						<= c_bm_up_cnt								;
			end
			
			OFF_BM_EN							: begin
				reg_rdata						<= {31'b0,c_bm_en}							;
			end
			default								: begin
				reg_rdata						<= reg_raddr								;
			end
		endcase
	end

endmodule
