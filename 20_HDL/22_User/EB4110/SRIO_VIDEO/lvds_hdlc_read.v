`timescale 1ns/1ns
//////////////////////////////////////////////////////////////////////////////////
// Company:			ZHTY
// Engineer:		ZYL
// Create Date:		2021/9/4 21:02:02
// Design Name:		IR2120
// Module Name:		lvds_hdlc_top
// Project Name:
// Target Devices:	K7-V7
// Tool Versions: 	Vivado 2016.1 HDL-EDIT UltraEdit TAB=4 Consolas
// Description:
//		模块将LVDS数据从DDR中读出，并生成IT UP Stream时序，送往HDLC
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
//////////////////////////////////////////////////////////////////////////////////
module lvds_hdlc_read #(
	/*--------------------------------------------------------------------------------------
	--P_SIMULATION_R
	---------------------------------------------------------------------------------------*/
	parameter		P_SIMULATION_R				= "FALSE"									,
	/*--------------------------------------------------------------------------------------
	--LVDS Cache Addr
	--------------------------------------------------------------------------------------*/
	parameter		P_LVDS_DDR3_START_ADDR_R	= 32'h4000_0000								,
	parameter		P_LVDS_DDR3_END_ADDR_R		= 32'h4200_0000								,
	parameter		P_LVDS_DDR3_BLOCK_SIZE_R	= 32'h1000									,
	parameter		P_V_FRAME_DDR3_BLOCK_SIZE_R	= 32'h80_1000								,
	
	/*--------------------------------------------------------------------------------------
	--LVDS Speed flow contro
	--------------------------------------------------------------------------------------*/
	parameter		P_LVDS_IFG_TIME_R			= 30
	)(
		input										ps_video_en											,
	input			[7:0]							ps_frame_ctr											,
	
	input										video_send_en									,		
//==================================================================================================
//--PAD Declarations---------------------------
	/*--------------------------------------------------------------------------------------
	--Common interface
	--------------------------------------------------------------------------------------*/
	input										sys_rst_i									,
	input										sys_clk_i									,

	/*--------------------------------------------------------------------------------------
	--LVDS Data DDR3 buffer Read Channel
	--------------------------------------------------------------------------------------*/
	input	wire	[3:0]						MLVDS_AXI_RID								,
	
	input	wire	[63:0]						MLVDS_AXI_RDATA								,
	input	wire	[1:0]						MLVDS_AXI_RRESP								,
	
	input	wire								MLVDS_AXI_RLAST								,
	
	input	wire								MLVDS_AXI_RVALID							,
	output	wire								MLVDS_AXI_RREADY							,

	/*--------------------------------------------------------------------------------------
	--input from cache
	--------------------------------------------------------------------------------------*/
	input			[31:0]						lvds_cache_cur_waddr						,
	output			[31:0]						lvds_cache_cur_raddr						,	
	/*--------------------------------------------------------------------------------------
	--AXI数据通道读请求接口
	--------------------------------------------------------------------------------------*/
	
	output	reg									m_axir_req					= 0				,
	
	input										m_axir_gnt									,
	
	output	reg		[10:0]						m_axir_len64				= 0				,
	
	output	reg		[31:0]						m_axir_addr					= 0				,
	
	/*--------------------------------------------------------------------------------------
	--to lvds_m_axis 
	--------------------------------------------------------------------------------------*/
	
	output			[65:0]						axis_data_fifo_dout_o						,
	output										axis_data_fifo_empty_o						,
	input										axis_data_fifo_ren_i
	);
//==================================================================================================
//--param defines
	/*--------------------------------------------------------------------------------------
	--AXIR State
	--------------------------------------------------------------------------------------*/
	localparam		S_AXIR_IDLE_M				= 9'b00000_0001								;
	localparam		S_AXIR_FRAME_STAR_M			= 9'b00000_0010								;
	localparam		S_AXIR_HREQ_M   			= 9'b00000_0100								;
	localparam		S_AXIR_HWAIT_M   			= 9'b00000_1000								;
	localparam		S_AXIR_DLOAD_M  			= 9'b00001_0000								;
	localparam		S_AXIR_DREQ_M   			= 9'b00010_0000								;
	localparam		S_AXIR_DWAIT_M  			= 9'b00100_0000								;
	localparam		S_AXIR_DONE_M   			= 9'b01000_0000								;
	localparam		S_AXIR_IFG_M				= 9'b10000_0000								;

	
	
	localparam		B_AXIR_IDLE_M				= 4'd0										;       
	localparam		B_AXIR_FRAME_STAR_M			= 4'd1										;
	localparam		B_AXIR_HREQ_M   			= 4'd2										;
	localparam		B_AXIR_HWAT_M   			= 4'd3										;
	localparam		B_AXIR_DLOAD_M  			= 4'd4										;
	localparam		B_AXIR_DREQ_M   			= 4'd5										;
	localparam		B_AXIR_DWAIT_M  			= 4'd6										;
	localparam		B_AXIR_DONE_M   			= 4'd7										;
	localparam		B_AXIR_IFG_M				= 4'd8										;

	/*--------------------------------------------------------------------------------------
	--AXIR Read back
	--------------------------------------------------------------------------------------*/
	localparam		S_RB_IDLE_M					= 4'b0001									;
	localparam		S_RB_HDATA_M   				= 4'b0010									;
	localparam		S_RB_DDATA_M   				= 4'b0100									;
	localparam		S_RB_DONE_M  				= 4'b1000									;


	localparam		B_RB_IDLE_M					= 2'd0										;
	localparam		B_RB_HDATA_M   				= 2'd1										;
	localparam		B_RB_DDATA_M   				= 2'd2										;
	localparam		B_RB_DONE_M  				= 2'd3										;


//==================================================================================================
//--Signals define
	/*--------------------------------------------------------------------------------------
	--AXIR State signals
	--------------------------------------------------------------------------------------*/
	
	reg				[B_AXIR_IFG_M:0]			S_AXIR_CM									;
	
	reg				[B_AXIR_IFG_M:0]			S_AXIR_NM									;
	reg				[31:0]						cur_raddr									;

	reg				[31:0]						ifg_cnt										;

	/*--------------------------------------------------------------------------------------
	--AXIR Read back signals
	--------------------------------------------------------------------------------------*/
	reg				[B_RB_DONE_M:0]				S_RB_CM										;
	reg				[B_RB_DONE_M:0]				S_RB_NM										;
	reg				[15:0]						rb_cnt										;
	
	
	reg				[15:0]						DSW_LEN										;	//byte
	
	wire			[15:0]						cur_len64									;
	
	wire			[15:0]						cur_real_len64								;


	/*--------------------------------------------------------------------------------------
	--AXIS data FIFO signals
	--------------------------------------------------------------------------------------*/	
	reg											axis_data_fifo_wen							;
	reg				[65:0]						axis_data_fifo_din							;
	wire										axis_data_fifo_full							;
	wire										axis_data_fifo_afull						;

	wire				[31:0]					VIO_P_LVDS_IFG_TIME_R	= 0						;
//==================================================================================================
//--AXI4 Read state
	always @(posedge sys_clk_i or posedge sys_rst_i) begin
		if(sys_rst_i) begin
			S_AXIR_CM							<= S_AXIR_IDLE_M							;
		end else begin
			S_AXIR_CM							<= S_AXIR_NM								;
		end
	end
	
	
	reg				[7:0]						wr_frame_all_cnt		= 7'h00				;	//	数据写入ddr轮询次数
	reg				[31:0]						lvds_cache_cur_waddr_d	= 'b0				;



	always @(posedge sys_clk_i  ) begin
		
		lvds_cache_cur_waddr_d					<= lvds_cache_cur_waddr						;
		if(lvds_cache_cur_waddr==32'h100&&lvds_cache_cur_waddr_d==32'h0)begin
			
			if( wr_frame_all_cnt==(ps_frame_ctr-1) && ps_video_en)begin
				wr_frame_all_cnt				<= 'b0										;
			end else begin
				wr_frame_all_cnt				<= wr_frame_all_cnt + 1						;
			end
		end else begin
			wr_frame_all_cnt					<= wr_frame_all_cnt							;
		end
		
	end

    reg             clear =0;

	always @(*) begin
		S_AXIR_NM								= S_AXIR_IDLE_M								;
		case(S_AXIR_CM)
			S_AXIR_IDLE_M						: begin
			

				if( (lvds_cache_cur_waddr==P_V_FRAME_DDR3_BLOCK_SIZE_R-32'h100)&& ps_video_en&&wr_frame_all_cnt==0&&video_send_en==1) begin//降频发送
					S_AXIR_NM					= S_AXIR_FRAME_STAR_M						;
				end else begin
					S_AXIR_NM					= S_AXIR_IDLE_M								;
				end
			end			
			S_AXIR_FRAME_STAR_M						: begin
				//if(lvds_cache_cur_waddr!=cur_raddr &&!axis_data_fifo_afull) begin
				if(!axis_data_fifo_afull) begin
					S_AXIR_NM					= S_AXIR_HREQ_M								;
				end else begin
					S_AXIR_NM					= S_AXIR_FRAME_STAR_M						;
				end
			end
			S_AXIR_HREQ_M						: begin
				if(m_axir_gnt) begin
					S_AXIR_NM					= S_AXIR_HWAIT_M							;
				end else begin
					S_AXIR_NM					= S_AXIR_HREQ_M								;
				end
			end
			S_AXIR_HWAIT_M						: begin
				if(S_RB_NM[B_RB_IDLE_M]) begin
					S_AXIR_NM					= S_AXIR_DLOAD_M							;
				end else begin
					S_AXIR_NM					= S_AXIR_HWAIT_M							;
				end
			end
			S_AXIR_DLOAD_M						: begin
				S_AXIR_NM						= S_AXIR_DREQ_M								;
			end
			S_AXIR_DREQ_M						: begin
				if(m_axir_gnt) begin
					S_AXIR_NM					= S_AXIR_DWAIT_M							;
				end else begin
					S_AXIR_NM					= S_AXIR_DREQ_M								;
				end
			end
			S_AXIR_DWAIT_M						: begin
				if(S_RB_NM[B_RB_DONE_M]) begin
					S_AXIR_NM					= S_AXIR_DONE_M								;
				end else begin
					S_AXIR_NM					= S_AXIR_DWAIT_M							;
				end
			end
			S_AXIR_DONE_M						: begin
				S_AXIR_NM						= S_AXIR_IFG_M								;
			end
			S_AXIR_IFG_M						: begin
					if(ifg_cnt==VIO_P_LVDS_IFG_TIME_R )  begin
						if(cur_raddr==P_V_FRAME_DDR3_BLOCK_SIZE_R)begin
							S_AXIR_NM			= S_AXIR_IDLE_M								;
										clear<= 1'b1;

						end else begin
							S_AXIR_NM			= S_AXIR_FRAME_STAR_M						;
						end
					end else begin
						S_AXIR_NM				= S_AXIR_IFG_M								;
					end
			end
			default								: begin
				S_AXIR_NM						= S_AXIR_IDLE_M								;
			end
		endcase
	end
//==================================================================================================
//--速率控制

	always @(posedge sys_clk_i or posedge sys_rst_i) begin
		if(sys_rst_i) begin
			ifg_cnt								<= 32'b0									;
		end else if(S_AXIR_CM[B_AXIR_IFG_M]) begin
			ifg_cnt								<= ifg_cnt + 1'b1							;
		end else begin
			ifg_cnt								<= 32'b0									;
		end
	end

//==================================================================================================
//--请求地址和长度实现
	always @(posedge sys_clk_i or posedge sys_rst_i) begin
		if(sys_rst_i) begin
			m_axir_req							<= 1'b0										;
		end else if(S_AXIR_NM[B_AXIR_HREQ_M] || S_AXIR_NM[B_AXIR_DREQ_M]) begin
			m_axir_req							<= 1'b1										;
		end else begin
			m_axir_req							<= 1'b0										;
		end
	end
	/*--------------------------------------------------------------------------------------
	--HEAD与DATA都从首地址开始读取，HEAD数据不写入FIFO
	--------------------------------------------------------------------------------------*/
	always @(posedge sys_clk_i or posedge sys_rst_i) begin
		if(sys_rst_i) begin
			m_axir_addr							<= 32'b0									;
		end else if(S_AXIR_NM[B_AXIR_HREQ_M]) begin
			m_axir_addr							<= cur_raddr								;
		end else begin
			m_axir_addr							<= m_axir_addr								;
		end
	end


	always @(posedge sys_clk_i or posedge sys_rst_i) begin
		if(sys_rst_i) begin
			m_axir_len64						<= 11'b0									;
		end else if(S_AXIR_CM[B_AXIR_DLOAD_M]) begin
			m_axir_len64						<= cur_real_len64							;
		end else if(S_AXIR_CM[B_AXIR_DREQ_M] || S_AXIR_CM[B_AXIR_DWAIT_M]) begin
			m_axir_len64						<= m_axir_len64								;
		end else begin
			m_axir_len64						<= 11'd1									;
		end
	end

//==================================================================================================
//--数据读取操作
	always @(posedge sys_clk_i or posedge sys_rst_i) begin
		if(sys_rst_i) begin
			S_RB_CM								<= S_RB_IDLE_M								;
		end else begin
			S_RB_CM								<= S_RB_NM									;
		end
	end

	always @(*) begin
		S_RB_NM									= S_RB_IDLE_M								;
		case(S_RB_CM)
			S_RB_IDLE_M							: begin
				if(S_AXIR_CM[B_AXIR_HREQ_M]) begin
					S_RB_NM						= S_RB_HDATA_M								;
				end else if(S_AXIR_CM[B_AXIR_DLOAD_M]) begin
					S_RB_NM						= S_RB_DDATA_M								;
				end else begin
					S_RB_NM						= S_RB_IDLE_M								;
				end
			end
			S_RB_HDATA_M						: begin
				if(MLVDS_AXI_RVALID) begin
					S_RB_NM						= S_RB_IDLE_M								;
				end else begin
					S_RB_NM						= S_RB_HDATA_M								;
				end
			end
			S_RB_DDATA_M						: begin
				if(rb_cnt==m_axir_len64-1'b1 && MLVDS_AXI_RVALID && MLVDS_AXI_RREADY) begin
					S_RB_NM						= S_RB_DONE_M								;
				end else begin
					S_RB_NM						= S_RB_DDATA_M								;
				end
			end
			S_RB_DONE_M							: begin
				S_RB_NM							= S_RB_IDLE_M								;
			end
			default								: begin
				S_RB_NM							= S_RB_IDLE_M								;
			end
		endcase
	end

	always @(posedge sys_clk_i or posedge sys_rst_i) begin
		if(sys_rst_i) begin
			rb_cnt								<= 16'b0									;
		end else if(S_RB_CM[B_RB_DDATA_M]) begin
			if(MLVDS_AXI_RVALID && MLVDS_AXI_RREADY) begin
				rb_cnt							<= rb_cnt + 1'b1							;
			end else begin
				rb_cnt							<= rb_cnt									;
			end
		end else begin
			rb_cnt								<= 16'b0									;
		end
	end

	/*--------------------------------------------------------------------------------------
	--cur DSW len8
	--------------------------------------------------------------------------------------*/
	always @(posedge sys_clk_i or posedge sys_rst_i) begin
		if(sys_rst_i) begin
			DSW_LEN								<= 16'b0									;
		end else if(S_RB_CM[B_RB_HDATA_M]) begin
			if(MLVDS_AXI_RVALID && MLVDS_AXI_RREADY) begin
				//DSW_LEN							<= MLVDS_AXI_RDATA[47:32]					;	//	获取帧长
				
				DSW_LEN							<= 16'h100					;	//	获取帧长
			end else begin
				DSW_LEN							<= DSW_LEN									;
			end
		end else begin
			DSW_LEN								<= DSW_LEN									;
		end
	end

	assign	cur_len64							= DSW_LEN[2:0]!=3'b0
												? {3'b0,DSW_LEN[15:3]} + 1'b1
												: {3'b0,DSW_LEN[15:3]}						;
	
	assign	cur_real_len64						= cur_len64 								;	//ADD packe head
	
	assign	MLVDS_AXI_RREADY					= ~axis_data_fifo_full						;
//==================================================================================================
//--Current BUF DDR3 Read address manage
	always @(posedge sys_clk_i or posedge sys_rst_i) begin
		if(sys_rst_i) begin
			cur_raddr							<= P_LVDS_DDR3_START_ADDR_R					;
//		end else if(cur_raddr>=P_V_FRAME_DDR3_BLOCK_SIZE_R) begin
//			cur_raddr							<= P_LVDS_DDR3_START_ADDR_R					;

		end else if(S_AXIR_NM[B_AXIR_IDLE_M]) begin
			cur_raddr							<= P_LVDS_DDR3_START_ADDR_R					;
		end else if(S_AXIR_NM[B_AXIR_DONE_M]) begin
			cur_raddr							<= cur_raddr + P_LVDS_DDR3_BLOCK_SIZE_R		;
		end else begin
			cur_raddr							<= cur_raddr								;
		end
	end
    assign          lvds_cache_cur_raddr        = cur_raddr                                 ;

//==================================================================================================
//--DDATA Write to FIFO
	always @(posedge sys_clk_i or posedge sys_rst_i) begin
		if(sys_rst_i) begin
			axis_data_fifo_wen					<= 1'b0										;
			axis_data_fifo_din[65:0]			<= 66'b0									;
			
		end else if(S_RB_CM[B_RB_HDATA_M]) begin	//增加自定义SRIO帧头
			axis_data_fifo_wen					<= MLVDS_AXI_RVALID && MLVDS_AXI_RREADY		;
			axis_data_fifo_din[63:0]			<= {32'h0060_2000,	cur_raddr-P_LVDS_DDR3_START_ADDR_R}	;
			
			axis_data_fifo_din[64]				<= 1'b1										;	//packet first flag
			axis_data_fifo_din[65]				<= 1'b0										;
			
		end else if(S_RB_CM[B_RB_DDATA_M]) begin
			axis_data_fifo_wen					<= MLVDS_AXI_RVALID && MLVDS_AXI_RREADY		;
			axis_data_fifo_din[63:0]			<= MLVDS_AXI_RDATA							;
			
//			if(rb_cnt==16'b0 && MLVDS_AXI_RVALID && MLVDS_AXI_RREADY) begin
//				axis_data_fifo_din[64]			<= 1'b1										;	//packet first flag
//			end else begin
//				axis_data_fifo_din[64]			<= 1'b0										;
//			end
				axis_data_fifo_din[64]			<= 1'b0										;

			if(rb_cnt==m_axir_len64-1'b1 && MLVDS_AXI_RVALID && MLVDS_AXI_RREADY) begin
				axis_data_fifo_din[65]			<= 1'b1										;	//packet last flag
			end else begin
				axis_data_fifo_din[65]			<= 1'b0										;
			end
		end else begin
			axis_data_fifo_wen					<= 1'b0										;
			axis_data_fifo_din[65:0]			<= 66'b0									;
		end
	end

//==================================================================================================
//--DDATA FIFO	
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
		.ALMOST_FULL_OFFSET						( 10'h204									),	//Sets almost full threshold
		.DATA_WIDTH								( 32										),	//Valid values are 1-72(37-72 only valid when FIFO_SIZE="36Kb")
		.FIFO_SIZE								( "36Kb"									),	//Target BRAM:"18Kb"or"36Kb"
		.FIRST_WORD_FALL_THROUGH				( "TRUE"									)	//Sets the FIFO FWFT to "TRUE" or "FALSE"
	)
	rx_data_fifo_0	(
		.ALMOSTEMPTY							( 											),	//1-bit output almostempty
		.ALMOSTFULL								( axis_data_fifo_afull						),	//1-bit output almost full
		.DO										( axis_data_fifo_dout_o[31:0]				),	//Output data,width defined by DATA_WIDTH parameter
		.EMPTY									( axis_data_fifo_empty_o					),	//1-bit output empty
		.FULL									( axis_data_fifo_full						),	//1-bit output full
		.RDCOUNT								( 											),	//Output read count,width determined by FIFO depth
		.RDERR									( 											),	//1-bit output read error
		.WRCOUNT								( 											),	//Output write count,width determined by FIFO depth
		.WRERR									( 											),	//1-bit output write error
		.DI										( axis_data_fifo_din[31:0]					),	//Input data,width defined by DATA_WIDTH parameter
		.RDCLK									( sys_clk_i									),	//1-bit input read clock
		.RDEN									( axis_data_fifo_ren_i						),	//1-bit input read enable
		.RST									( sys_rst_i									),	//1-bit input reset
		.WRCLK									( sys_clk_i									),	//1-bit input write clock
		.WREN									( axis_data_fifo_wen						)	//1-bit input write enable
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
		.DATA_WIDTH								( 34										),	//Valid values are 1-72(37-72 only valid when FIFO_SIZE="36Kb")
		.FIFO_SIZE								( "36Kb"									),	//Target BRAM:"18Kb"or"36Kb"
		.FIRST_WORD_FALL_THROUGH				( "TRUE"									)	//Sets the FIFO FWFT to "TRUE" or "FALSE"
	)
	rx_data_fifo_1	(
		.ALMOSTEMPTY							( 											),	//1-bit output almostempty
		.ALMOSTFULL								( 											),	//1-bit output almost full
		.DO										( axis_data_fifo_dout_o[65:32]				),	//Output data,width defined by DATA_WIDTH parameter
		.EMPTY									( 											),	//1-bit output empty
		.FULL									( 											),	//1-bit output full
		.RDCOUNT								( 											),	//Output read count,width determined by FIFO depth
		.RDERR									( 											),	//1-bit output read error
		.WRCOUNT								( 											),	//Output write count,width determined by FIFO depth
		.WRERR									( 											),	//1-bit output write error
		.DI										( axis_data_fifo_din[65:32]					),	//Input data,width defined by DATA_WIDTH parameter
		.RDCLK									( sys_clk_i									),	//1-bit input read clock
		.RDEN									( axis_data_fifo_ren_i						),	//1-bit input read enable
		.RST									( sys_rst_i									),	//1-bit input reset
		.WRCLK									( sys_clk_i									),	//1-bit input write clock
		.WREN									( axis_data_fifo_wen						)	//1-bit input write enable
	);
//	ila_axis	ila_loop(
//		.clk                        			( sys_clk_i								),
//		.probe0                                  ( {
//		lvds_cache_cur_waddr,
//		ps_video_en,
//		ps_frame_ctr  ,
//													S_AXIR_CM						
//																							})
//	);
endmodule