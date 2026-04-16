// ============================================================================
// 新增维护说明
// 文件职责      : 当前文件为手工维护源码，承担本模块/脚本的真实实现。
// 维护边界      : 本注释块仅补充维护说明，不改写任何原有说明、历史注释或现有逻辑。
// 修改约束      : 后续如需继续补充说明，只允许追加中文注释，不得替换旧注释或改动旧代码。
// 生成关系      : 若存在对应生成物，应以当前手工源码为准，禁止反向覆盖本文件。
// ============================================================================
 `timescale 1ns/1ns
//////////////////////////////////////////////////////////////////////////////////
// Company:			HXZY
// Engineer:		ZYL
// Create Date:		2018/5/11 19:40:24
// Design Name:		XR2000
// Module Name:		xr2000_regfile_pcie
// Project Name:
// Target Devices:	K7-V7
// Tool Versions: 	Vivado 2016.1 HDL-EDIT UltraEdit TAB=4 Consolas
// Description:
//		PCIe时钟下的寄存器读写模块
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
//////////////////////////////////////////////////////////////////////////////////
module regfile_sim_reg #(
	/*--------------------------------------------------------------------------------------
	--P_SIMULATION_R
	---------------------------------------------------------------------------------------*/
	parameter		P_SIMULATION_R				= "FALSE"									,

	parameter		P_Srio_CH_NUM_R				= 32'h0000_0002								,
	parameter		P_Srio_CAP_R				= 32'h0000_0001								,
	parameter		P_Srio_ID_WTH_R				= 32'h0000_0008								,
	parameter		P_Srio_SPEED_R				= 32'h0000_0001								,
	parameter		P_Srio_BANK_R				= 32'h0000_0000								,
	parameter		P_Board_MEM_SIZE_R			= 32'hFFFF_FFFF								,

	parameter		P_Srio_CH0_R				= 32'h0100_0001								,
	parameter		P_Srio_CH1_R				= 32'hFFFF_FFFF								,
	parameter		P_Srio_CH2_R				= 32'hFFFF_FFFF								,
	parameter		P_Srio_CH3_R				= 32'hFFFF_FFFF								,
	parameter		P_Srio_CH4_R				= 32'hFFFF_FFFF								,
	parameter		P_Srio_CH5_R				= 32'hFFFF_FFFF								,
	parameter		P_Srio_CH6_R				= 32'hFFFF_FFFF								,
	parameter		P_Srio_CH7_R				= 32'hFFFF_FFFF
	)(
//==================================================================================================
//--输入输出端口定义---------------------------
	/*--------------------------------------------------------------------------------------
	--Common Interface
	--|clk-->可以连接log_clk，也可以连接外部时钟，进行快速查询处理
	--|rst-->复位信号，高电平同步复位信号
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
	--Timestamp out
	--------------------------------------------------------------------------------------*/	
	output	reg		[63:0]						c_bm_timestamp								,
	output	reg									c_bm_timestamp_rf							,
	
	/*--------------------------------------------------------------------------------------
	--BM Count in
	--------------------------------------------------------------------------------------*/	
	input			[31:0]						c_bm_up_cnt									,
	/*--------------------------------------------------------------------------------------
	--DDR3 user for DN
	--------------------------------------------------------------------------------------*/	
	output	reg		[31:0]						reg_ch0_mem_addr_c			= 32'h0000_0000	,
	output	reg		[31:0]						reg_ch0_mem_size_c			= 32'h0400_0000	,
	output	reg		[31:0]						reg_ch1_mem_addr_c			= 32'h0400_0000	,
	output	reg		[31:0]						reg_ch1_mem_size_c			= 32'h0400_0000	,
	output	reg		[31:0]						reg_ch2_mem_addr_c			= 32'h0800_0000	,
	output	reg		[31:0]						reg_ch2_mem_size_c			= 32'h0400_0000	,
	output	reg		[31:0]						reg_ch3_mem_addr_c			= 32'h0C00_0000	,
	output	reg		[31:0]						reg_ch3_mem_size_c			= 32'h0400_0000	,
	output	reg		[31:0]						reg_ch4_mem_addr_c			= 32'h1000_0000	,
	output	reg		[31:0]						reg_ch4_mem_size_c			= 32'h0400_0000	,
	output	reg		[31:0]						reg_ch5_mem_addr_c			= 32'h1400_0000	,
	output	reg		[31:0]						reg_ch5_mem_size_c			= 32'h0400_0000	,
	output	reg		[31:0]						reg_ch6_mem_addr_c			= 32'h1800_0000	,
	output	reg		[31:0]						reg_ch6_mem_size_c			= 32'h0400_0000	,
	output	reg		[31:0]						reg_ch7_mem_addr_c			= 32'h1C00_0000	,
	output	reg		[31:0]						reg_ch7_mem_size_c			= 32'h0400_0000	,
	
	/*--------------------------------------------------------------------------------------
	--DMA Channel Cache Packet Count
	--------------------------------------------------------------------------------------*/	
	input			[8*32-1:0]					c_sp_up_cnt									,
	input			[8*32-1:0]					c_sp_dn_cnt
	);
//==================================================================================================
//--Param define
	localparam		OFF_REVERSION0				= 16'h0000									;
	localparam		OFF_REVERSION1				= 16'h0004									;
	localparam		OFF_MODULE_ID				= 16'h0010									;
	localparam		OFF_MODULE_CODE				= 16'h0014									;
	localparam		OFF_MODULE_TYPE				= 16'h0018									;
	localparam		OFF_MODULE_NAME				= 16'h0020									;
	localparam		OFF_MODULE_DATE				= 16'h0024									;
	
	/*--------------------------------------------------------------------------------------
	--BM Timestamp
	--------------------------------------------------------------------------------------*/
	localparam		OFF_TIMESTAMP_H				= 16'h0100									;
	localparam		OFF_TIMESTAMP_L				= 16'h0104									;
	/*--------------------------------------------------------------------------------------
	--BOARD Cap Registers
	--------------------------------------------------------------------------------------*/
	localparam		OFF_SRIO_CH_NUM				= 16'h1000									;
	localparam		OFF_SRIO_CAP				= 16'h1004									;
	localparam		OFF_SRIO_SPEED				= 16'h1008									;
	localparam		OFF_SRIO_ID_WTH				= 16'h100C									;
	localparam		OFF_BOARD_MEM_SIZE			= 16'h1010									;
    
	localparam		OFF_SRIO_CH0				= 16'h1100									;
	localparam		OFF_SRIO_CH1				= 16'h1110									;
	localparam		OFF_SRIO_CH2				= 16'h1120									;
	localparam		OFF_SRIO_CH3				= 16'h1130									;
	localparam		OFF_SRIO_CH4				= 16'h1140									;
	localparam		OFF_SRIO_CH5				= 16'h1150									;
	localparam		OFF_SRIO_CH6				= 16'h1160									;
	localparam		OFF_SRIO_CH7				= 16'h1170									;

	/*--------------------------------------------------------------------------------------
	--DMA通道报文个数统计
	--------------------------------------------------------------------------------------*/
	localparam		OFF_SP0_UP_CNT				= 16'h2000									;
	localparam		OFF_SP0_DN_CNT				= 16'h2004									;
	localparam		OFF_SP1_UP_CNT				= 16'h2100									;
	localparam		OFF_SP1_DN_CNT				= 16'h2104									;
	localparam		OFF_SP2_UP_CNT				= 16'h2200									;
	localparam		OFF_SP2_DN_CNT				= 16'h2204									;
	localparam		OFF_SP3_UP_CNT				= 16'h2300									;
	localparam		OFF_SP3_DN_CNT				= 16'h2304									;
	localparam		OFF_SP4_UP_CNT				= 16'h2400									;
	localparam		OFF_SP4_DN_CNT				= 16'h2404									;
	localparam		OFF_SP5_UP_CNT				= 16'h2500									;
	localparam		OFF_SP5_DN_CNT				= 16'h2504									;
	localparam		OFF_SP6_UP_CNT				= 16'h2600									;
	localparam		OFF_SP6_DN_CNT				= 16'h2604									;
	localparam		OFF_SP7_UP_CNT				= 16'h2700									;
	localparam		OFF_SP7_DN_CNT				= 16'h2704									;
	
	/*--------------------------------------------------------------------------------------
	--DN MEM Address & size manage
	--------------------------------------------------------------------------------------*/	
	localparam		OFF_CH0_DN_ADDR				= 16'h3000									;
	localparam		OFF_CH0_DN_SIZE				= 16'h3004									;
	localparam		OFF_CH1_DN_ADDR				= 16'h3100									;
	localparam		OFF_CH1_DN_SIZE				= 16'h3104									;
	localparam		OFF_CH2_DN_ADDR				= 16'h3200									;
	localparam		OFF_CH2_DN_SIZE				= 16'h3204									;
	localparam		OFF_CH3_DN_ADDR				= 16'h3300									;
	localparam		OFF_CH3_DN_SIZE				= 16'h3304									;
	localparam		OFF_CH4_DN_ADDR				= 16'h3400									;
	localparam		OFF_CH4_DN_SIZE				= 16'h3404									;
	localparam		OFF_CH5_DN_ADDR				= 16'h3500									;
	localparam		OFF_CH5_DN_SIZE				= 16'h3504									;
	localparam		OFF_CH6_DN_ADDR				= 16'h3600									;
	localparam		OFF_CH6_DN_SIZE				= 16'h3604									;
	localparam		OFF_CH7_DN_ADDR				= 16'h3700									;
	localparam		OFF_CH7_DN_SIZE				= 16'h3704									;
	
	/*--------------------------------------------------------------------------------------
	--BM PCIe Clock寄存器
	------------------------------------------------------------------	--------------------*/
	localparam		OFF_BM_UP_CNT				= 16'h4000									;
//==================================================================================================
//--Register Write Implement
	always @(posedge clk) begin
		if(reg_waddr[15:0]==OFF_CH0_DN_ADDR && reg_wvalid) begin
			reg_ch0_mem_addr_c					<= reg_wdata[31:0]							;
		end else begin
			reg_ch0_mem_addr_c					<= reg_ch0_mem_addr_c						;
		end
		
		if(reg_waddr[15:0]==OFF_CH1_DN_ADDR && reg_wvalid) begin
			reg_ch1_mem_addr_c					<= reg_wdata[31:0]							;
		end else begin
			reg_ch1_mem_addr_c					<= reg_ch1_mem_addr_c						;
		end
		
		if(reg_waddr[15:0]==OFF_CH2_DN_ADDR && reg_wvalid) begin
			reg_ch2_mem_addr_c					<= reg_wdata[31:0]							;
		end else begin
			reg_ch2_mem_addr_c					<= reg_ch2_mem_addr_c						;
		end
		
		
		if(reg_waddr[15:0]==OFF_CH3_DN_ADDR && reg_wvalid) begin
			reg_ch3_mem_addr_c					<= reg_wdata[31:0]							;
		end else begin
			reg_ch3_mem_addr_c					<= reg_ch3_mem_addr_c						;
		end
		
		if(reg_waddr[15:0]==OFF_CH4_DN_ADDR && reg_wvalid) begin
			reg_ch4_mem_addr_c					<= reg_wdata[31:0]							;
		end else begin
			reg_ch4_mem_addr_c					<= reg_ch4_mem_addr_c						;
		end
		
		if(reg_waddr[15:0]==OFF_CH5_DN_ADDR && reg_wvalid) begin
			reg_ch5_mem_addr_c					<= reg_wdata[31:0]							;
		end else begin
			reg_ch5_mem_addr_c					<= reg_ch5_mem_addr_c						;
		end
		
		if(reg_waddr[15:0]==OFF_CH6_DN_ADDR && reg_wvalid) begin
			reg_ch6_mem_addr_c					<= reg_wdata[31:0]							;
		end else begin
			reg_ch6_mem_addr_c					<= reg_ch6_mem_addr_c						;
		end
		
		if(reg_waddr[15:0]==OFF_CH7_DN_ADDR && reg_wvalid) begin
			reg_ch7_mem_addr_c					<= reg_wdata[31:0]							;
		end else begin
			reg_ch7_mem_addr_c					<= reg_ch7_mem_addr_c						;
		end
	end
	
	always @(posedge clk) begin
		if(reg_waddr[15:0]==OFF_CH0_DN_SIZE && reg_wvalid) begin
			reg_ch0_mem_size_c					<= reg_wdata[31:0]							;
		end else begin
			reg_ch0_mem_size_c					<= reg_ch0_mem_size_c						;
		end
		
		if(reg_waddr[15:0]==OFF_CH1_DN_SIZE && reg_wvalid) begin
			reg_ch1_mem_size_c					<= reg_wdata[31:0]							;
		end else begin
			reg_ch1_mem_size_c					<= reg_ch1_mem_size_c						;
		end
		
		if(reg_waddr[15:0]==OFF_CH2_DN_SIZE && reg_wvalid) begin
			reg_ch2_mem_size_c					<= reg_wdata[31:0]							;
		end else begin
			reg_ch2_mem_size_c					<= reg_ch2_mem_size_c						;
		end
		
		
		if(reg_waddr[15:0]==OFF_CH3_DN_SIZE && reg_wvalid) begin
			reg_ch3_mem_size_c					<= reg_wdata[31:0]							;
		end else begin
			reg_ch3_mem_size_c					<= reg_ch3_mem_size_c						;
		end
		
		if(reg_waddr[15:0]==OFF_CH4_DN_SIZE && reg_wvalid) begin
			reg_ch4_mem_size_c					<= reg_wdata[31:0]							;
		end else begin
			reg_ch4_mem_size_c					<= reg_ch4_mem_size_c						;
		end
		
		if(reg_waddr[15:0]==OFF_CH5_DN_SIZE && reg_wvalid) begin
			reg_ch5_mem_size_c					<= reg_wdata[31:0]							;
		end else begin
			reg_ch5_mem_size_c					<= reg_ch5_mem_size_c						;
		end
		
		if(reg_waddr[15:0]==OFF_CH6_DN_SIZE && reg_wvalid) begin
			reg_ch6_mem_size_c					<= reg_wdata[31:0]							;
		end else begin
			reg_ch6_mem_size_c					<= reg_ch6_mem_size_c						;
		end
		
		if(reg_waddr[15:0]==OFF_CH7_DN_SIZE && reg_wvalid) begin
			reg_ch7_mem_size_c					<= reg_wdata[31:0]							;
		end else begin
			reg_ch7_mem_size_c					<= reg_ch7_mem_size_c						;
		end
	end
//==================================================================================================
//--bm timestamp		
	always @(posedge clk) begin
		if(rst) begin
			c_bm_timestamp[63:32]				<= 32'b0									;
		end else if(reg_waddr[15:0]==OFF_TIMESTAMP_H && reg_wvalid) begin
			c_bm_timestamp[63:32]				<= reg_wdata[31:0]							;
		end else begin
			c_bm_timestamp[63:32]				<= c_bm_timestamp[63:32]					;
		end
	end
	always @(posedge clk) begin
		if(rst) begin
			c_bm_timestamp[31:0]				<= 32'b0									;
		end else if(reg_waddr[15:0]==OFF_TIMESTAMP_L && reg_wvalid) begin
			c_bm_timestamp[31:0]				<= reg_wdata[31:0]							;
		end else begin
			c_bm_timestamp[31:0]				<= c_bm_timestamp[31:0]						;
		end
	end

	reg											c_bm_timestamp_rf_lock						;
	always @(posedge clk) begin
		if(rst) begin
			c_bm_timestamp_rf_lock				<= 1'b0										;
		end else if(reg_waddr[15:0]==OFF_TIMESTAMP_H && reg_wvalid) begin
			c_bm_timestamp_rf_lock				<= 1'b1										;
		end else if(reg_waddr[15:0]==OFF_TIMESTAMP_L && reg_wvalid) begin
			c_bm_timestamp_rf_lock				<= 1'b0										;
		end else begin
			c_bm_timestamp_rf_lock				<= c_bm_timestamp_rf_lock					;
		end
	end

	always @(posedge clk) begin
		if(rst) begin
			c_bm_timestamp_rf					<= 1'b0										;
		end else begin
			c_bm_timestamp_rf					<= c_bm_timestamp_rf_lock					;
		end
	end
	

//==================================================================================================
//--寄存器读实现
	wire	RS_SRIO_CH_NUM						= reg_raddr[15:0]==OFF_SRIO_CH_NUM			;
	wire	RS_SRIO_CAP		    				= reg_raddr[15:0]==OFF_SRIO_CAP		        ;
	wire	RS_SRIO_SPEED						= reg_raddr[15:0]==OFF_SRIO_SPEED		    ;
	wire	RS_SRIO_ID_WTH						= reg_raddr[15:0]==OFF_SRIO_ID_WTH		    ;

	wire	RS_SRIO_CH0		    				= reg_raddr[15:0]==OFF_SRIO_CH0		        ;
	wire	RS_SRIO_CH1		    				= reg_raddr[15:0]==OFF_SRIO_CH1		        ;
	wire	RS_SRIO_CH2		    				= reg_raddr[15:0]==OFF_SRIO_CH2		        ;
	wire	RS_SRIO_CH3		    				= reg_raddr[15:0]==OFF_SRIO_CH3		        ;
	wire	RS_SRIO_CH4		    				= reg_raddr[15:0]==OFF_SRIO_CH4		        ;
	wire	RS_SRIO_CH5		    				= reg_raddr[15:0]==OFF_SRIO_CH5		        ;
	wire	RS_SRIO_CH6		    				= reg_raddr[15:0]==OFF_SRIO_CH6		        ;
	wire	RS_SRIO_CH7		    				= reg_raddr[15:0]==OFF_SRIO_CH7		        ;

	wire	RS_SP0_UP_CNT						= reg_raddr[15:0]==OFF_SP0_UP_CNT			;
	wire	RS_SP1_UP_CNT						= reg_raddr[15:0]==OFF_SP1_UP_CNT			;
	wire	RS_SP2_UP_CNT						= reg_raddr[15:0]==OFF_SP2_UP_CNT			;
	wire	RS_SP3_UP_CNT						= reg_raddr[15:0]==OFF_SP3_UP_CNT			;
	wire	RS_SP4_UP_CNT						= reg_raddr[15:0]==OFF_SP4_UP_CNT			;
	wire	RS_SP5_UP_CNT						= reg_raddr[15:0]==OFF_SP5_UP_CNT			;
	wire	RS_SP6_UP_CNT						= reg_raddr[15:0]==OFF_SP6_UP_CNT			;
	wire	RS_SP7_UP_CNT						= reg_raddr[15:0]==OFF_SP7_UP_CNT			;

	wire	RS_SP0_DN_CNT						= reg_raddr[15:0]==OFF_SP0_DN_CNT			;
	wire	RS_SP1_DN_CNT						= reg_raddr[15:0]==OFF_SP1_DN_CNT			;
	wire	RS_SP2_DN_CNT						= reg_raddr[15:0]==OFF_SP2_DN_CNT			;
	wire	RS_SP3_DN_CNT						= reg_raddr[15:0]==OFF_SP3_DN_CNT			;
	wire	RS_SP4_DN_CNT						= reg_raddr[15:0]==OFF_SP4_DN_CNT			;
	wire	RS_SP5_DN_CNT						= reg_raddr[15:0]==OFF_SP5_DN_CNT			;
	wire	RS_SP6_DN_CNT						= reg_raddr[15:0]==OFF_SP6_DN_CNT			;
	wire	RS_SP7_DN_CNT						= reg_raddr[15:0]==OFF_SP7_DN_CNT			;
	
	wire	RS_BM_UP_CNT						= reg_raddr[15:0]==OFF_BM_UP_CNT			;

	always @(posedge clk) begin
		reg_rdata								<= RS_SRIO_CH_NUM	?  {P_Srio_BANK_R[7:0],16'b0,P_Srio_CH_NUM_R[7:0]}
	                                            :  RS_SRIO_CAP		?  P_Srio_CAP_R
		                                        :  RS_SRIO_SPEED	?  P_Srio_SPEED_R
	                                            :  RS_SRIO_ID_WTH	?  P_Srio_ID_WTH_R

                                                :  RS_SRIO_CH0		?  P_Srio_CH0_R
                                                :  RS_SRIO_CH1		?  P_Srio_CH1_R
                                                :  RS_SRIO_CH2		?  P_Srio_CH2_R
                                                :  RS_SRIO_CH3		?  P_Srio_CH3_R
                                                :  RS_SRIO_CH4		?  P_Srio_CH4_R
                                                :  RS_SRIO_CH5		?  P_Srio_CH5_R
                                                :  RS_SRIO_CH6		?  P_Srio_CH6_R
                                                :  RS_SRIO_CH7		?  P_Srio_CH7_R

												:  RS_SP0_UP_CNT    ?  c_sp_up_cnt[0*32+:32]
												:  RS_SP1_UP_CNT    ?  c_sp_up_cnt[1*32+:32]
												:  RS_SP2_UP_CNT    ?  c_sp_up_cnt[2*32+:32]
												:  RS_SP3_UP_CNT    ?  c_sp_up_cnt[3*32+:32]
												:  RS_SP4_UP_CNT    ?  c_sp_up_cnt[4*32+:32]
												:  RS_SP5_UP_CNT    ?  c_sp_up_cnt[5*32+:32]
												:  RS_SP6_UP_CNT    ?  c_sp_up_cnt[6*32+:32]
												:  RS_SP7_UP_CNT    ?  c_sp_up_cnt[7*32+:32]

												:  RS_SP0_DN_CNT    ?  c_sp_dn_cnt[0*32+:32]
												:  RS_SP1_DN_CNT    ?  c_sp_dn_cnt[1*32+:32]
												:  RS_SP2_DN_CNT    ?  c_sp_dn_cnt[2*32+:32]
												:  RS_SP3_DN_CNT    ?  c_sp_dn_cnt[3*32+:32]
												:  RS_SP4_DN_CNT    ?  c_sp_dn_cnt[4*32+:32]
												:  RS_SP5_DN_CNT    ?  c_sp_dn_cnt[5*32+:32]
												:  RS_SP6_DN_CNT    ?  c_sp_dn_cnt[6*32+:32]
												:  RS_SP7_DN_CNT	?  c_sp_dn_cnt[7*32+:32]
												
												:  RS_BM_UP_CNT		?  c_bm_up_cnt
                                              	:  32'b0									;
	end

endmodule