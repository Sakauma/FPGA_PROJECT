// ============================================================================
// 维护注释
//   文件职责      : 继承自 XR2000 的流处理与边带控制逻辑。
//   源码属性      : 手工维护源码，不要把修改同步到生成 IP 或网表。
//   更新要求      : 当时钟、复位、接口或数据顺序假设变化时，同步更新注释。
//   维护边界      : 注释用于说明当前实现意图，不替代接口协议文档。
// ============================================================================
//////////////////////////////////////////////////////////////////////////////////////////////////
// Company:			ZHTY
// Engineer:		ZhengYunLong
//
// Create Date:		2018/11/5 17:36:00
// Design Name:
// Module Name:		xr2000_srio_rst.v
// Project Name:	XR2000
// Target Devices:	XC7K325TFFG676-2
// Tool versions:	Vivado 2016.4
// Description:
//	XR2000项目仿真卡的SRIO复位设计，当检测到SRIO设备的Link_initiazation时，进行复位设计，
//支持寄存器复位配置。复位信号控制时钟不能用log_clk，防止锁死
// Revision:
// Revision 0.01 - File Created
// Revision 0.02 - 2018/11/14 12:44:36 
//		Add Link Reset Signals 
// Revision 0.03 -2018/11/15 18:45:44
//		Add PowerUp Reset,hold time for 300ms
//		Add PowerUP firber reset
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////////////////////
module	sp_rst	#(
	parameter									CNT_VALUE				= 37'd100000000000	,
	/*--------------------------------------------------------------------------------------
	--P_SIMULATION_R
	--------------------------------------------------------------------------------------*/
	parameter		P_Srio_CH_LANE_R			= 1											,	
	parameter		P_Srio_SPEED_R				= 2 										,
	parameter		P_SIMULATION_R				= "FALSE"
	)(
//==================================================================================================
//--Port Defines
	/*--------------------------------------------------------------------------------------
	--Common Inteface
	--------------------------------------------------------------------------------------*/
	input										clk											,
	input										rst											,

	/*--------------------------------------------------------------------------------------
	--SRIO Link Status Interface
	--------------------------------------------------------------------------------------*/
	input										link_initialized							,


	input			[31:0]						reg_srio_reset_time_c						,
	input										reg_srio_reset_enable_c						,
	input										reg_srio_reset_trig_c						,
	
	/*--------------------------------------------------------------------------------------
	--SRIO Reset Output
	--------------------------------------------------------------------------------------*/
	output	reg									force_reinit			= 1'b0
	);
//==================================================================================================
//--Parameter Defines
	localparam									S_RST_IDLE_M			= 3'b001			;
	localparam									S_RST_RST_M				= 3'b010			;
	localparam									S_RST_DONE_M			= 3'b100			;

	localparam									B_RST_RST_M				= 2'b1				;
	localparam									B_RST_DONE_M			= 2'd2				;
//	parameter									CNT_VALUE				= 37'd100000000000	;
	
	localparam	P_CLK_CYCLE_R					=(P_Srio_CH_LANE_R*P_Srio_SPEED_R==1)?640
												:(P_Srio_CH_LANE_R*P_Srio_SPEED_R==2)?320
												:(P_Srio_CH_LANE_R*P_Srio_SPEED_R==3)?256
												:(P_Srio_CH_LANE_R*P_Srio_SPEED_R==4)?160
												:(P_Srio_CH_LANE_R*P_Srio_SPEED_R==5)?160
												:(P_Srio_CH_LANE_R*P_Srio_SPEED_R==6)?128
												:(P_Srio_CH_LANE_R*P_Srio_SPEED_R==8)?80
												:(P_Srio_CH_LANE_R*P_Srio_SPEED_R==10)?80
												:(P_Srio_CH_LANE_R*P_Srio_SPEED_R==12)?64
												:(P_Srio_CH_LANE_R*P_Srio_SPEED_R==20)?40
												:(P_Srio_CH_LANE_R*P_Srio_SPEED_R==24)?32
												:320										;

//==================================================================================================
//--Signals Defines	
	reg				[2:0]						S_RST_CM				= 0					;
	reg				[2:0]						S_RST_NM				= 0					;
	
	reg				[2:0]						link_q					= 0					;
	wire										link_fe										;
	wire										link_re										;


	wire										reset_trig									;
	
	reg				[31:0]						rst_cnt				= 0						;
	reg				[36:0]						force_reinit_cnt	= 0						;
	reg											force_reinit_ing	= 1						;
	always@(posedge clk or posedge rst) begin
		if(rst)begin
			force_reinit_cnt					<= 37'd0									;
		end else begin
			force_reinit_cnt					<= force_reinit_cnt	+ (force_reinit_ing ? P_CLK_CYCLE_R :0) ;
		end
	end 
	
//==================================================================================================
//--Falling edge detect
	always @(posedge clk) begin
		link_q[2:0]								<= {link_q[1:0],link_initialized}			;
	end

	assign	link_fe								= link_q[2] && ~link_q[1]					;
	assign	link_re								= ~link_q[2] && link_q[1]					;
	assign	reset_trig							= link_fe && reg_srio_reset_enable_c		;
	
	
//==================================================================================================
//--Reset Implement
	always @(posedge clk or posedge rst) begin
		if(rst) begin
			S_RST_CM							<= S_RST_IDLE_M								;
		end else begin
			S_RST_CM							<= S_RST_NM									;
		end
	end

	always @* begin
		S_RST_NM								= S_RST_IDLE_M								;
		case(S_RST_CM)
			S_RST_IDLE_M						: begin
				if(reg_srio_reset_trig_c | reset_trig) begin
					S_RST_NM					= S_RST_RST_M								;
				end else begin
					S_RST_NM					= S_RST_IDLE_M								;
				end
			end
			S_RST_RST_M							: begin
				if(rst_cnt==reg_srio_reset_time_c) begin
					S_RST_NM					= S_RST_DONE_M								;
				end else begin
					S_RST_NM					= S_RST_RST_M								;
				end
			end
			S_RST_DONE_M						: begin
				S_RST_NM						= S_RST_IDLE_M								;
			end
			default								: begin
				S_RST_NM						= S_RST_IDLE_M								;
			end
		endcase
	end

	always@(posedge clk) begin
		force_reinit_ing						<= CNT_VALUE > force_reinit_cnt				;
	end 
	always @(posedge clk or posedge rst) begin
		if(rst) begin
			force_reinit						<= 1'b0										;
		end else if(force_reinit_ing) begin
			force_reinit						<= 1'b1										;
		end else if(S_RST_NM[B_RST_RST_M]) begin
			force_reinit						<= 1'b1										;	
		end else begin
			force_reinit						<= 1'b0										;
		end
	end

	always @(posedge clk) begin
		if(S_RST_NM[B_RST_RST_M]) begin
			rst_cnt								<= rst_cnt + 1'b1							;
		end else begin
			rst_cnt								<= 32'b0									;
		end
	end

	
endmodule
