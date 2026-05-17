
`timescale 1ns/1ns
//////////////////////////////////////////////////////////////////////////////////
// Company:			ZHTY
// Engineer:		ZYL
// Create Date:		2021/9/4 21:02:02
// Design Name:		IR2120
// Module Name:		lvds_top
// Project Name:
// Target Devices:	K7-V7
// Tool Versions: 	Vivado 2016.1 HDL-EDIT UltraEdit TAB=4 Consolas
// Description:
//		模块实现IRAX DSW的解析，提取LVDS iPort的数据帧，将非LVDS iPort数据帧输出
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
//////////////////////////////////////////////////////////////////////////////////
module lvds_parse_full_drop #(
	/*--------------------------------------------------------------------------------------
	--P_SIMULATION_R
	---------------------------------------------------------------------------------------*/
	parameter		P_SIMULATION_R				= "FALSE"									,
	/*--------------------------------------------------------------------------------------
	--LVDS Data iPort
	---------------------------------------------------------------------------------------*/
	parameter		P_LVDS_iport_R				= 4'h6
	)(
//==================================================================================================
//--PAD Declarations---------------------------
	/*--------------------------------------------------------------------------------------
	--Common interface
	--------------------------------------------------------------------------------------*/
	input										sys_rst_i									,
	input										sys_clk_i									,

	/*--------------------------------------------------------------------------------------
	--iT UP Stream interface
	--------------------------------------------------------------------------------------*/
	
	input			[63:0]						it_up_axis_tdata_i							,
	input			[ 3:0]						it_up_axis_tid_i							,
	
	output	reg									it_up_axis_tready_o							,
	
	input										it_up_axis_tvalid_i							,
	input			[ 7:0]						it_up_axis_tstrb_i							,
	input			[ 7:0]						it_up_axis_tkeep_i							,
	
	input										it_up_axis_tlast_i							,
	input			[63:0]						it_up_axis_tuser_i							,
	input			[ 3:0]						it_up_axis_tdest_i							,
	
	/*--------------------------------------------------------------------------------------
	--fix buf data Out
	--------------------------------------------------------------------------------------*/
	output			[64:0]						fix_data_fifo_dout_o						,
	input										fix_data_fifo_ren_i							,
	output										fix_data_fifo_empty_o						,
	
	/*--------------------------------------------------------------------------------------
	--lvds buf data Out
	--------------------------------------------------------------------------------------*/
	output			[63:0]						lvds_data_fifo_dout_o						,
	input										lvds_data_fifo_ren_i						,
	output										lvds_data_fifo_empty_o						,

	output			[31:0]						lvds_trn_fifo_dout_o						,
	input										lvds_trn_fifo_ren_i							,
	output										lvds_trn_fifo_empty_o
	);
	
	reg				[9:0]						lvds_trn_fifo_count			= 'b0			;
//==================================================================================================
//--Param defines
	/*--------------------------------------------------------------------------------------
	--PARSE State param
	--------------------------------------------------------------------------------------*/
	localparam		S_PARSE_IDLE_M				= 5'b0_0001									;
	localparam		S_PARSE_LVDS_DATA_M     	= 5'b0_0010									;
	localparam		S_PARSE_FIX_DATA_M      	= 5'b0_0100									;
	localparam		S_PARSE_LOST_M          	= 5'b0_1000									;
	localparam		S_PARSE_DONE_M          	= 5'b1_0000									;

	localparam		B_PARSE_IDLE_M				= 4'h0										;
	localparam		B_PARSE_LVDS_DATA_M     	= 4'h1										;
	localparam		B_PARSE_FIX_DATA_M      	= 4'h2										;
	localparam		B_PARSE_LOST_M          	= 4'h3										;
	localparam		B_PARSE_DONE_M          	= 4'h4										;
//==================================================================================================
//--Signals define
	/*--------------------------------------------------------------------------------------
	--parse state
	--------------------------------------------------------------------------------------*/
	
	reg				[B_PARSE_DONE_M:0]			S_PARSE_CM									;
	
	reg				[B_PARSE_DONE_M:0]			S_PARSE_NM									;
	
	/*--------------------------------------------------------------------------------------
	--LVDS Data FIFO Signals
	--------------------------------------------------------------------------------------*/
	
	reg				[63:0]						lvds_data_fifo_din							;
	
	reg											lvds_data_fifo_wen							;
	wire										lvds_data_fifo_full							;

	reg				[31:0]						lvds_trn_fifo_din							;
	reg											lvds_trn_fifo_wen							;
	
	/*--------------------------------------------------------------------------------------
	--FIX Data FIFO Signals
	--------------------------------------------------------------------------------------*/
	
	reg				[64:0]						fix_data_fifo_din							;
	
	reg											fix_data_fifo_wen							;
	wire										fix_data_fifo_full							;

//==================================================================================================
//--Pre assign

	wire		[7:0]	SRIO_TID				= it_up_axis_tdata_i[63:56]					;
	wire		[3:0]	SRIO_FTYPE				= it_up_axis_tdata_i[55:52]					;
	wire		[3:0]	SRIO_TTYPE				= it_up_axis_tdata_i[51:48]					;
	wire		[2:0]	SRIO_PRIO				= it_up_axis_tdata_i[46:45]					;
	wire				SRIO_CRF				= it_up_axis_tdata_i[44]					;
	wire		[7:0]	SRIO_SIZE				= it_up_axis_tdata_i[43:36]					;
	wire		[33:0]	SRIO_ADDR				= it_up_axis_tdata_i[33:0]					;



//==================================================================================================
//--parse state implement
	always @(posedge sys_clk_i or posedge sys_rst_i) begin
		if(sys_rst_i) begin
			S_PARSE_CM							<= S_PARSE_IDLE_M							;
		end else begin
			S_PARSE_CM							<= S_PARSE_NM								;
		end
	end

	always @(*) begin
		S_PARSE_NM								= S_PARSE_IDLE_M							;
		case(S_PARSE_CM)
			S_PARSE_IDLE_M						: begin
				if(it_up_axis_tvalid_i) begin
					if(SRIO_TID==4'ha) begin
						if(it_up_axis_tready_o && it_up_axis_tlast_i)begin
							S_PARSE_NM			= S_PARSE_IDLE_M						;	
						end else begin
							S_PARSE_NM			= S_PARSE_FIX_DATA_M						;	
						end
					end else if(SRIO_FTYPE==P_LVDS_iport_R & SRIO_SIZE==0) begin
						S_PARSE_NM				= S_PARSE_LVDS_DATA_M							;	
					end else begin
						S_PARSE_NM				= S_PARSE_LOST_M							;
					end
				end else begin
					S_PARSE_NM					= S_PARSE_IDLE_M							;
				end
			end
		
			S_PARSE_LVDS_DATA_M					: begin
				if(it_up_axis_tvalid_i && it_up_axis_tready_o && it_up_axis_tlast_i) begin
					S_PARSE_NM					= S_PARSE_DONE_M							;
				end else begin
					S_PARSE_NM					= S_PARSE_LVDS_DATA_M						;
				end
			end

			S_PARSE_FIX_DATA_M					: begin
				if(it_up_axis_tvalid_i && it_up_axis_tready_o && it_up_axis_tlast_i) begin
					S_PARSE_NM					= S_PARSE_DONE_M							;
				end else begin
					S_PARSE_NM					= S_PARSE_FIX_DATA_M						;
				end
			end
			S_PARSE_LOST_M						: begin
				if(it_up_axis_tvalid_i && it_up_axis_tready_o && it_up_axis_tlast_i) begin
					S_PARSE_NM					= S_PARSE_DONE_M							;
				end else begin
					S_PARSE_NM					= S_PARSE_LOST_M							;
				end
			end
			S_PARSE_DONE_M						: begin
				S_PARSE_NM						= S_PARSE_IDLE_M							;
			end
			default								: begin
				S_PARSE_NM						= S_PARSE_IDLE_M							;
			end
		endcase
	end

//==================================================================================================
//--it_up_axis_tready_o_o
	always @(*) begin
		if( S_PARSE_CM[B_PARSE_DONE_M]) begin
			it_up_axis_tready_o					= 1'b0										;
		end else if(S_PARSE_CM[B_PARSE_LVDS_DATA_M]) begin
			it_up_axis_tready_o					= ~lvds_data_fifo_full						;
		end else if(S_PARSE_CM[B_PARSE_FIX_DATA_M]) begin
			it_up_axis_tready_o					= ~fix_data_fifo_full						;
		end else begin
			it_up_axis_tready_o					= 1'b1										;
		end
	end

//==================================================================================================
//--it_up_fix_axis_*
	always @(*) begin
		if(S_PARSE_CM[B_PARSE_IDLE_M]) begin
			fix_data_fifo_wen					= it_up_axis_tvalid_i && it_up_axis_tready_o && SRIO_FTYPE!=P_LVDS_iport_R;
			fix_data_fifo_din[63:0]				= it_up_axis_tdata_i[63:0]					;		
			fix_data_fifo_din[64]				= it_up_axis_tvalid_i && it_up_axis_tready_o && it_up_axis_tlast_i	;			
		end else if(S_PARSE_CM[B_PARSE_FIX_DATA_M]) begin
			fix_data_fifo_wen					= it_up_axis_tvalid_i && it_up_axis_tready_o;
			fix_data_fifo_din[63:0]				= it_up_axis_tdata_i[63:0]					;
			fix_data_fifo_din[64]				=  it_up_axis_tvalid_i && it_up_axis_tready_o && it_up_axis_tlast_i
												? 1'b1:1'b0									;
		end else begin
			fix_data_fifo_wen					= 1'b0										;
			fix_data_fifo_din[63:0]				= 64'b0										;
			fix_data_fifo_din[64]				= 1'b0										;
		end
	end

	
//==================================================================================================
//--LVDS Data FIFO Write
	always @(*) begin
//		if(S_PARSE_CM[B_PARSE_IDLE_M]) begin
//			lvds_data_fifo_wen					= it_up_axis_tvalid_i && it_up_axis_tready_o && SRIO_FTYPE==P_LVDS_iport_R && SRIO_SIZE==0;
//			lvds_data_fifo_din					= it_up_axis_tdata_i						;		
//		end else 
		
		if(S_PARSE_CM[B_PARSE_LVDS_DATA_M]) begin
			lvds_data_fifo_wen					= it_up_axis_tvalid_i	&& it_up_axis_tready_o					;
			lvds_data_fifo_din					= it_up_axis_tdata_i						;
		end else begin
			lvds_data_fifo_wen					= 1'b0										;
			lvds_data_fifo_din					= 64'b0										;
		end
	end


	always @(posedge sys_clk_i or posedge sys_rst_i) begin
		if(sys_rst_i) begin
			lvds_trn_fifo_wen					<= 1'b0										;
			lvds_trn_fifo_din					<= 32'b0									;
		end	else if(S_PARSE_CM[B_PARSE_IDLE_M] && ~lvds_data_fifo_full && SRIO_FTYPE==P_LVDS_iport_R && SRIO_SIZE==0) begin
			lvds_trn_fifo_wen				 	<= 1'b1										;
			lvds_trn_fifo_din					<= {SRIO_ADDR[23:8],16'd64}					;
		end else begin
			lvds_trn_fifo_wen					<= 1'b0										;
			lvds_trn_fifo_din					<= 32'b0									;
		end
	end

//==================================================================================================
//--FIFO Instance
	/*----------------------------------------------------------------------------------------------
	--FIFO_DUALCLOCK_MACRO: DualClock First-In,First-Out(FIFO) RAM Buffer
	--7 Series
	--Xilinx HDL Language Template,version2017.4
	-----------------------------------------------------------------
	--|DATA_WIDTH	|FIFO_SIZE	|FIFO Depth	|RDCOUNT/WRCOUNT Width	|
	--|=============|===========|===========|=======================|
	--|37-72		|"36Kb"		|512		| 9-bit 				|
	--|19-36		|"36Kb"		|1024		|10-bit 				|
	--|19-36		|"18Kb"		|512		| 9-bit 				|
	--|10-18		|"36Kb"		|2048		|11-bit 				|
	--|10-18		|"18Kb"		|1024		|10-bit 				|
	--|5-9		 	|"36Kb"		|4096		|12-bit 				|
	--|5-9		 	|"18Kb"		|2048		|11-bit 				|
	--|1-4		 	|"36Kb"		|8192		|13-bit 				|
	--|1-4		 	|"18Kb"		|4096		|12-bit 				|
	----------------------------------------------------------------------------------------------*/
	FIFO_DUALCLOCK_MACRO	#(
		.DEVICE									( "7SERIES"									),	//Target Device:"7SERIES"
		.ALMOST_EMPTY_OFFSET					( 9'h006									),	//Sets the almost empty threshold
		.ALMOST_FULL_OFFSET						( 9'h004									),	//Sets almost full threshold
		.DATA_WIDTH								( 32										),	//Valid values are 1-72(37-72 only valid when FIFO_SIZE="36Kb")
		.FIFO_SIZE								( "36Kb"									),	//Target BRAM:"18Kb"or"36Kb"
		.FIRST_WORD_FALL_THROUGH				( "TRUE"									)	//Sets the FIFO FWFT to "TRUE" or "FALSE"
	)
	lvds_data_fifo0	(
		.ALMOSTEMPTY							( 											),	//1-bit output almostempty
		.ALMOSTFULL								( 											),	//1-bit output almost full
		.DO										( lvds_data_fifo_dout_o	[31:0]				),	//Output data,width defined by DATA_WIDTH parameter
		.EMPTY									( lvds_data_fifo_empty_o					),	//1-bit output empty
		.FULL									( lvds_data_fifo_full						),	//1-bit output full
		.RDCOUNT								( 											),	//Output read count,width determined by FIFO depth
		.RDERR									( 											),	//1-bit output read error
		.WRCOUNT								( 											),	//Output write count,width determined by FIFO depth
		.WRERR									( 											),	//1-bit output write error
		.DI										( lvds_data_fifo_din	[31:0]				),	//Input data,width defined by DATA_WIDTH parameter
		.RDCLK									( sys_clk_i									),	//1-bit input read clock
		.RDEN									( lvds_data_fifo_ren_i						),	//1-bit input read enable
		.RST									( sys_rst_i									),	//1-bit input reset
		.WRCLK									( sys_clk_i									),	//1-bit input write clock
		.WREN									( lvds_data_fifo_wen						)	//1-bit input write enable
	);
	/*----------------------------------------------------------------------------------------------
	--FIFO_DUALCLOCK_MACRO: DualClock First-In,First-Out(FIFO) RAM Buffer
	--7 Series
	--Xilinx HDL Language Template,version2017.4
	-----------------------------------------------------------------
	--|DATA_WIDTH	|FIFO_SIZE	|FIFO Depth	|RDCOUNT/WRCOUNT Width	|
	--|=============|===========|===========|=======================|
	--|37-72		|"36Kb"		|512		| 9-bit 				|
	--|19-36		|"36Kb"		|1024		|10-bit 				|
	--|19-36		|"18Kb"		|512		| 9-bit 				|
	--|10-18		|"36Kb"		|2048		|11-bit 				|
	--|10-18		|"18Kb"		|1024		|10-bit 				|
	--|5-9		 	|"36Kb"		|4096		|12-bit 				|
	--|5-9		 	|"18Kb"		|2048		|11-bit 				|
	--|1-4		 	|"36Kb"		|8192		|13-bit 				|
	--|1-4		 	|"18Kb"		|4096		|12-bit 				|
	----------------------------------------------------------------------------------------------*/
	FIFO_DUALCLOCK_MACRO	#(
		.DEVICE									( "7SERIES"									),	//Target Device:"7SERIES"
		.ALMOST_EMPTY_OFFSET					( 9'h006									),	//Sets the almost empty threshold
		.ALMOST_FULL_OFFSET						( 9'h004									),	//Sets almost full threshold
		.DATA_WIDTH								( 32										),	//Valid values are 1-72(37-72 only valid when FIFO_SIZE="36Kb")
		.FIFO_SIZE								( "36Kb"									),	//Target BRAM:"18Kb"or"36Kb"
		.FIRST_WORD_FALL_THROUGH				( "TRUE"									)	//Sets the FIFO FWFT to "TRUE" or "FALSE"
	)
	lvds_data_fifo1	(
		.ALMOSTEMPTY							( 											),	//1-bit output almostempty
		.ALMOSTFULL								( 											),	//1-bit output almost full
		.DO										( lvds_data_fifo_dout_o	[63:32]				),	//Output data,width defined by DATA_WIDTH parameter
		.EMPTY									( 											),	//1-bit output empty
		.FULL									( 											),	//1-bit output full
		.RDCOUNT								( 											),	//Output read count,width determined by FIFO depth
		.RDERR									( 											),	//1-bit output read error
		.WRCOUNT								( 											),	//Output write count,width determined by FIFO depth
		.WRERR									( 											),	//1-bit output write error
		.DI										( lvds_data_fifo_din	[63:32]				),	//Input data,width defined by DATA_WIDTH parameter
		.RDCLK									( sys_clk_i									),	//1-bit input read clock
		.RDEN									( lvds_data_fifo_ren_i						),	//1-bit input read enable
		.RST									( sys_rst_i									),	//1-bit input reset
		.WRCLK									( sys_clk_i									),	//1-bit input write clock
		.WREN									( lvds_data_fifo_wen						)	//1-bit input write enable
	);	
	/*----------------------------------------------------------------------------------------------
	--FIFO_DUALCLOCK_MACRO: DualClock First-In,First-Out(FIFO) RAM Buffer
	--7 Series
	--Xilinx HDL Language Template,version2017.4
	-----------------------------------------------------------------
	--|DATA_WIDTH	|FIFO_SIZE	|FIFO Depth	|RDCOUNT/WRCOUNT Width	|
	--|=============|===========|===========|=======================|
	--|37-72		|"36Kb"		|512		| 9-bit 				|
	--|19-36		|"36Kb"		|1024		|10-bit 				|
	--|19-36		|"18Kb"		|512		| 9-bit 				|
	--|10-18		|"36Kb"		|2048		|11-bit 				|
	--|10-18		|"18Kb"		|1024		|10-bit 				|
	--|5-9		 	|"36Kb"		|4096		|12-bit 				|
	--|5-9		 	|"18Kb"		|2048		|11-bit 				|
	--|1-4		 	|"36Kb"		|8192		|13-bit 				|
	--|1-4		 	|"18Kb"		|4096		|12-bit 				|
	----------------------------------------------------------------------------------------------*/
	FIFO_DUALCLOCK_MACRO	#(
		.DEVICE									( "7SERIES"									),	//Target Device:"7SERIES"
		.ALMOST_EMPTY_OFFSET					( 10'h006									),	//Sets the almost empty threshold
		.ALMOST_FULL_OFFSET						( 10'h004									),	//Sets almost full threshold
		.DATA_WIDTH								( 32										),	//Valid values are 1-72(37-72 only valid when FIFO_SIZE="36Kb")
		.FIFO_SIZE								( "18Kb"									),	//Target BRAM:"18Kb"or"36Kb"
		.FIRST_WORD_FALL_THROUGH				( "TRUE"									)	//Sets the FIFO FWFT to "TRUE" or "FALSE"
	)
	lvds_trn_fifo	(
		.ALMOSTEMPTY							( 											),	//1-bit output almostempty
		.ALMOSTFULL								( 											),	//1-bit output almost full
		.DO										( lvds_trn_fifo_dout_o						),	//Output data,width defined by DATA_WIDTH parameter
		.EMPTY									( lvds_trn_fifo_empty_o						),	//1-bit output empty
		.FULL									( 											),	//1-bit output full
		.RDCOUNT								( 											),	//Output read count,width determined by FIFO depth
		.RDERR									( 											),	//1-bit output read error
		.WRCOUNT								( 											),	//Output write count,width determined by FIFO depth
		.WRERR									( 											),	//1-bit output write error
		.DI										( lvds_trn_fifo_din							),	//Input data,width defined by DATA_WIDTH parameter
		.RDCLK									( sys_clk_i									),	//1-bit input read clock
		.RDEN									( lvds_trn_fifo_ren_i						),	//1-bit input read enable
		.RST									( sys_rst_i									),	//1-bit input reset
		.WRCLK									( sys_clk_i									),	//1-bit input write clock
		.WREN									( lvds_trn_fifo_wen							)	//1-bit input write enable
	);
	

//	
//	always @(posedge sys_clk_i ) begin
//	        lvds_trn_fifo_count[0] 				<= lvds_trn_fifo_wen						;
//	end	
	
/*
仿真测试方法：
80_TB/tb_TOP.v

cd E:/WZ_WORK/complete/key/IR2120/prj/710_G/LVDS_SIM_PRJ/10_PRJ/00_PRJ.sim/sim_1/behav/modelsim
do tb_TOP_compile.do
do tb_TOP_simulate.do
run 50us

do tb_TOP_compile.do
restart
run 200us
*/
//==================================================================================================
//--FIFO Instance
	/*----------------------------------------------------------------------------------------------
	--FIFO_DUALCLOCK_MACRO: DualClock First-In,First-Out(FIFO) RAM Buffer
	--7 Series
	--Xilinx HDL Language Template,version2017.4
	-----------------------------------------------------------------
	--|DATA_WIDTH	|FIFO_SIZE	|FIFO Depth	|RDCOUNT/WRCOUNT Width	|
	--|=============|===========|===========|=======================|
	--|37-72		|"36Kb"		|512		| 9-bit 				|
	--|19-36		|"36Kb"		|1024		|10-bit 				|
	--|19-36		|"18Kb"		|512		| 9-bit 				|
	--|10-18		|"36Kb"		|2048		|11-bit 				|
	--|10-18		|"18Kb"		|1024		|10-bit 				|
	--|5-9		 	|"36Kb"		|4096		|12-bit 				|
	--|5-9		 	|"18Kb"		|2048		|11-bit 				|
	--|1-4		 	|"36Kb"		|8192		|13-bit 				|
	--|1-4		 	|"18Kb"		|4096		|12-bit 				|
	----------------------------------------------------------------------------------------------*/
	FIFO_DUALCLOCK_MACRO	#(
		.DEVICE									( "7SERIES"									),	//Target Device:"7SERIES"
		.ALMOST_EMPTY_OFFSET					( 9'h006									),	//Sets the almost empty threshold
		.ALMOST_FULL_OFFSET						( 9'h004									),	//Sets almost full threshold
		.DATA_WIDTH								( 65										),	//Valid values are 1-72(37-72 only valid when FIFO_SIZE="36Kb")
		.FIFO_SIZE								( "36Kb"									),	//Target BRAM:"18Kb"or"36Kb"
		.FIRST_WORD_FALL_THROUGH				( "TRUE"									)	//Sets the FIFO FWFT to "TRUE" or "FALSE"
	)
	fix_data_fifo	(
		.ALMOSTEMPTY							( 											),	//1-bit output almostempty
		.ALMOSTFULL								( 											),	//1-bit output almost full
		.DO										( fix_data_fifo_dout_o						),	//Output data,width defined by DATA_WIDTH parameter
		.EMPTY									( fix_data_fifo_empty_o						),	//1-bit output empty
		.FULL									( fix_data_fifo_full						),	//1-bit output full
		.RDCOUNT								( 											),	//Output read count,width determined by FIFO depth
		.RDERR									( 											),	//1-bit output read error
		.WRCOUNT								( 											),	//Output write count,width determined by FIFO depth
		.WRERR									( 											),	//1-bit output write error
		.DI										( fix_data_fifo_din							),	//Input data,width defined by DATA_WIDTH parameter
		.RDCLK									( sys_clk_i									),	//1-bit input read clock
		.RDEN									( fix_data_fifo_ren_i						),	//1-bit input read enable
		.RST									( sys_rst_i									),	//1-bit input reset
		.WRCLK									( sys_clk_i									),	//1-bit input write clock
		.WREN									( fix_data_fifo_wen							)	//1-bit input write enable
	);
endmodule