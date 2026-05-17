
`timescale 1ns/1ns
//////////////////////////////////////////////////////////////////////////////////
// Company:			ZHTY
// Engineer:		ZYL
// Create Date:		2021/9/4 21:02:02
// Design Name:		IR2120
// Module Name:		srio_top
// Project Name:
// Target Devices:	K7-V7
// Tool Versions: 	Vivado 2016.1 HDL-EDIT UltraEdit TAB=4 Consolas
// Description:
//		模块实现IRAX DSW的解析，提取LVDS iPort的数据帧，将非LVDS iPort数据帧输出
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created


/*
// 双拍同步器：log_clk → gt_pcs_clk_out
reg [1:0] sync_pipe;
always @(posedge gt_pcs_clk_out or negedge rst_n) begin
    if(!rst_n)
        sync_pipe <= 2'b00;
    else
        sync_pipe <= {sync_pipe[0], signal_from_log_clk};
end

// 输出就是安全的跨域信号
wire signal_in_gt_pcs_domain = sync_pipe[1];

*/
//////////////////////////////////////////////////////////////////////////////////
module srio_v_axis_to_fifo #(
	parameter		P_srio_iport_R				= 4'h6
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
	input			[63:0]						s_axis_tdata_i								,
	output	reg									s_axis_tready_o								,
	input										s_axis_tvalid_i								,
	input										s_axis_tlast_i								,
	input			[63:0]						s_axis_tuser_i								,

	/*--------------------------------------------------------------------------------------
	--fix buf data Out
	--------------------------------------------------------------------------------------*/
	input										fix_data_clk_i								,
	output			[64:0]						fix_data_fifo_dout_o						,
	input										fix_data_fifo_ren_i							,
	output										fix_data_fifo_empty_o						,
	/*--------------------------------------------------------------------------------------
	--lvds buf data Out
	--------------------------------------------------------------------------------------*/
	input			[63:0]						srio_fifo_clk_i								,
	
	output			[63:0]						srio_data_fifo_dout_o						,
	input										srio_data_fifo_ren_i						,
	output										srio_data_fifo_empty_o						,

	output			[31:0]						srio_trn_fifo_dout_o						,
	input										srio_trn_fifo_ren_i							,
	output										srio_trn_fifo_empty_o
	);

	
    //  The following function calculates the address width based on specified RAM depth
    function integer clogb2;
        input integer depth;
        for (clogb2=0; depth>0; clogb2=clogb2+1)
            depth = depth >> 1;
    endfunction	
	
	
	reg				[9:0]						srio_trn_fifo_count			= 'b0			;
//==================================================================================================
//--Param defines
	/*--------------------------------------------------------------------------------------
	--PARSE State param
	--------------------------------------------------------------------------------------*/
	localparam		S_PARSE_IDLE_M				= 5'b0_0001									;
	localparam		S_PARSE_srio_DATA_M     	= 5'b0_0010									;
	localparam		S_PARSE_FIX_DATA_M      	= 5'b0_0100									;
	localparam		S_PARSE_LOST_M          	= 5'b0_1000									;
	localparam		S_PARSE_DONE_M          	= 5'b1_0000									;

	localparam		B_PARSE_IDLE_M				= 4'h0										;
	localparam		B_PARSE_srio_DATA_M     	= 4'h1										;
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

	reg				[127:0]						S_PARSE_CM_acii								;

	always @(*) begin
        case(S_PARSE_CM)
            S_PARSE_IDLE_M		  : S_PARSE_CM_acii<= "IDLE";
            S_PARSE_srio_DATA_M   : S_PARSE_CM_acii<= "DATA";
            S_PARSE_FIX_DATA_M    : S_PARSE_CM_acii<= "FIX";
            S_PARSE_LOST_M        : S_PARSE_CM_acii<= "LOST";
            S_PARSE_DONE_M        : S_PARSE_CM_acii<= "DONE";
            default               : S_PARSE_CM_acii<= "NULL";
        endcase
	end
	
	/*--------------------------------------------------------------------------------------
	--LVDS Data FIFO Signals
	--------------------------------------------------------------------------------------*/
	
	reg				[63:0]						srio_data_fifo_din							;
	
	reg											srio_data_fifo_wen							;
	wire										srio_data_fifo_full							;

	reg				[31:0]						srio_trn_fifo_din							;
	reg											srio_trn_fifo_wen							;
	
	/*--------------------------------------------------------------------------------------
	--FIX Data FIFO Signals
	--------------------------------------------------------------------------------------*/
	reg				[64:0]						fix_data_fifo_din							;
	
	reg											fix_data_fifo_wen							;
	wire										fix_data_fifo_full							;


//			ila_test	ila_wfifo(
//		.clk                        			( sys_clk_i								),
//		.probe0                                  ( {
		
//		srio_data_fifo_din							,
	
//						srio_data_fifo_wen							,
//							srio_data_fifo_full							,
                       
// srio_trn_fifo_din   	,
// srio_trn_fifo_wen   	

//																							})
//	);
//==================================================================================================
//--Pre assign
	wire		[7:0]	SRIO_TID				= s_axis_tdata_i[63:56]					;
	wire		[3:0]	SRIO_FTYPE				= s_axis_tdata_i[55:52]					;
	wire		[3:0]	SRIO_TTYPE				= s_axis_tdata_i[51:48]					;
	wire		[2:0]	SRIO_PRIO				= s_axis_tdata_i[46:45]					;
	wire				SRIO_CRF				= s_axis_tdata_i[44]					;
	wire		[7:0]	SRIO_SIZE				= s_axis_tdata_i[43:36]					;
	wire		[33:0]	SRIO_ADDR				= s_axis_tdata_i[33:0]					;
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
				if(s_axis_tvalid_i) begin
					if(SRIO_TID==4'ha) begin
						if(s_axis_tready_o && s_axis_tlast_i)begin
							S_PARSE_NM			= S_PARSE_IDLE_M						;	
						end else begin
							S_PARSE_NM			= S_PARSE_FIX_DATA_M						;	
						end
					end else if(SRIO_FTYPE==P_srio_iport_R & SRIO_SIZE==0) begin
						S_PARSE_NM				= S_PARSE_srio_DATA_M							;	
					end else begin
						S_PARSE_NM				= S_PARSE_LOST_M							;
					end
				end else begin
					S_PARSE_NM					= S_PARSE_IDLE_M							;
				end
			end
		
			S_PARSE_srio_DATA_M					: begin
				if(s_axis_tvalid_i && s_axis_tready_o && s_axis_tlast_i) begin
					S_PARSE_NM					= S_PARSE_DONE_M							;
				end else begin
					S_PARSE_NM					= S_PARSE_srio_DATA_M						;
				end
			end

			S_PARSE_FIX_DATA_M					: begin
				if(s_axis_tvalid_i && s_axis_tready_o && s_axis_tlast_i) begin
					S_PARSE_NM					= S_PARSE_DONE_M							;
				end else begin
					S_PARSE_NM					= S_PARSE_FIX_DATA_M						;
				end
			end
			S_PARSE_LOST_M						: begin
				if(s_axis_tvalid_i && s_axis_tready_o && s_axis_tlast_i) begin
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
//--s_axis_tready_o_o
	always @(*) begin
		if( S_PARSE_CM[B_PARSE_DONE_M]) begin
			s_axis_tready_o					= 1'b0										;
		end else if(S_PARSE_CM[B_PARSE_srio_DATA_M]) begin
			s_axis_tready_o					= ~srio_data_fifo_full						;
		end else if(S_PARSE_CM[B_PARSE_FIX_DATA_M]) begin
			s_axis_tready_o					= ~fix_data_fifo_full						;
		end else begin
			s_axis_tready_o					= 1'b1										;
		end
	end

//==================================================================================================
//--s_fix_axis_*
	always @(*) begin
		if(S_PARSE_CM[B_PARSE_IDLE_M]) begin
			fix_data_fifo_wen					= s_axis_tvalid_i && s_axis_tready_o && SRIO_FTYPE!=P_srio_iport_R;
			fix_data_fifo_din[63:0]				= s_axis_tdata_i[63:0]					;		
			fix_data_fifo_din[64]				= s_axis_tvalid_i && s_axis_tready_o && s_axis_tlast_i	;			
		end else if(S_PARSE_CM[B_PARSE_FIX_DATA_M]) begin
			fix_data_fifo_wen					= s_axis_tvalid_i && s_axis_tready_o;
			fix_data_fifo_din[63:0]				= s_axis_tdata_i[63:0]					;
			fix_data_fifo_din[64]				=  s_axis_tvalid_i && s_axis_tready_o && s_axis_tlast_i
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
//			srio_data_fifo_wen					= s_axis_tvalid_i && s_axis_tready_o && SRIO_FTYPE==P_srio_iport_R && SRIO_SIZE==0;
//			srio_data_fifo_din					= s_axis_tdata_i						;		
//		end else 
		
		if(S_PARSE_CM[B_PARSE_srio_DATA_M]) begin
			srio_data_fifo_wen					= s_axis_tvalid_i	&& s_axis_tready_o					;
			srio_data_fifo_din					= s_axis_tdata_i						;
		end else begin
			srio_data_fifo_wen					= 1'b0										;
			srio_data_fifo_din					= 64'b0										;
		end
	end


	always @(posedge sys_clk_i or posedge sys_rst_i) begin
		if(sys_rst_i) begin
			srio_trn_fifo_wen					<= 1'b0										;
			srio_trn_fifo_din					<= 32'b0									;
		end	else if(S_PARSE_CM[B_PARSE_IDLE_M] && ~srio_data_fifo_full && SRIO_FTYPE==P_srio_iport_R && SRIO_SIZE==0) begin
			srio_trn_fifo_wen				 	<= 1'b1										;
			srio_trn_fifo_din					<= {SRIO_ADDR[23:8],16'd64}					;
		end else begin
			srio_trn_fifo_wen					<= 1'b0										;
			srio_trn_fifo_din					<= 32'b0									;
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
	srio_data_fifo0	(
		.ALMOSTEMPTY							( 											),	//1-bit output almostempty
		.ALMOSTFULL								( 											),	//1-bit output almost full
		.DO										( srio_data_fifo_dout_o	[31:0]				),	//Output data,width defined by DATA_WIDTH parameter
		.EMPTY									( srio_data_fifo_empty_o					),	//1-bit output empty
		.FULL									( srio_data_fifo_full						),	//1-bit output full
		.RDCOUNT								( 											),	//Output read count,width determined by FIFO depth
		.RDERR									( 											),	//1-bit output read error
		.WRCOUNT								( 											),	//Output write count,width determined by FIFO depth
		.WRERR									( 											),	//1-bit output write error
		.DI										( srio_data_fifo_din	[31:0]				),	//Input data,width defined by DATA_WIDTH parameter
		.RDCLK									( srio_fifo_clk_i									),	//1-bit input read clock
		.RDEN									( srio_data_fifo_ren_i						),	//1-bit input read enable
		.RST									( sys_rst_i									),	//1-bit input reset
		.WRCLK									( sys_clk_i									),	//1-bit input write clock
		.WREN									( srio_data_fifo_wen						)	//1-bit input write enable
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
	srio_data_fifo1	(
		.ALMOSTEMPTY							( 											),	//1-bit output almostempty
		.ALMOSTFULL								( 											),	//1-bit output almost full
		.DO										( srio_data_fifo_dout_o	[63:32]				),	//Output data,width defined by DATA_WIDTH parameter
		.EMPTY									( 											),	//1-bit output empty
		.FULL									( 											),	//1-bit output full
		.RDCOUNT								( 											),	//Output read count,width determined by FIFO depth
		.RDERR									( 											),	//1-bit output read error
		.WRCOUNT								( 											),	//Output write count,width determined by FIFO depth
		.WRERR									( 											),	//1-bit output write error
		.DI										( srio_data_fifo_din	[63:32]				),	//Input data,width defined by DATA_WIDTH parameter
		.RDCLK									( srio_fifo_clk_i									),	//1-bit input read clock
		.RDEN									( srio_data_fifo_ren_i						),	//1-bit input read enable
		.RST									( sys_rst_i									),	//1-bit input reset
		.WRCLK									( sys_clk_i									),	//1-bit input write clock
		.WREN									( srio_data_fifo_wen						)	//1-bit input write enable
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
	srio_trn_fifo	(
		.ALMOSTEMPTY							( 											),	//1-bit output almostempty
		.ALMOSTFULL								( 											),	//1-bit output almost full
		.DO										( srio_trn_fifo_dout_o						),	//Output data,width defined by DATA_WIDTH parameter
		.EMPTY									( srio_trn_fifo_empty_o						),	//1-bit output empty
		.FULL									( 											),	//1-bit output full
		.RDCOUNT								( 											),	//Output read count,width determined by FIFO depth
		.RDERR									( 											),	//1-bit output read error
		.WRCOUNT								( 											),	//Output write count,width determined by FIFO depth
		.WRERR									( 											),	//1-bit output write error
		.DI										( srio_trn_fifo_din							),	//Input data,width defined by DATA_WIDTH parameter
		.RDCLK									( srio_fifo_clk_i									),	//1-bit input read clock
		.RDEN									( srio_trn_fifo_ren_i						),	//1-bit input read enable
		.RST									( sys_rst_i									),	//1-bit input reset
		.WRCLK									( sys_clk_i									),	//1-bit input write clock
		.WREN									( srio_trn_fifo_wen							)	//1-bit input write enable
	);
	

//	
//	always @(posedge sys_clk_i ) begin
//	        srio_trn_fifo_count[0] 				<= srio_trn_fifo_wen						;
//	end	
	
/*
仿真测试方法：
80_TB/tb_TOP.v

cd E:/WZ_WORK/complete/key/IR2120/prj/710_G/srio_SIM_PRJ/10_PRJ/00_PRJ.sim/sim_1/behav/modelsim
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
		.RDCLK									( fix_data_clk_i							),	//1-bit input read clock
		.RDEN									( fix_data_fifo_ren_i						),	//1-bit input read enable
		.RST									( sys_rst_i									),	//1-bit input reset
		.WRCLK									( sys_clk_i									),	//1-bit input write clock
		.WREN									( fix_data_fifo_wen							)	//1-bit input write enable
	);
	

endmodule