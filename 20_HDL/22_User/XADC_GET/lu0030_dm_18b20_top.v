`timescale 1ns / 1ps
// ============================================================================
// 新增维护说明
// 作者          : Egor Izmaylov
// 文件职责      : 当前文件为手工维护源码，具体职责见模块名、端口和上层实例化。
// 维护边界      : 只追加说明性注释；Vivado/IP 生成物和第三方支撑代码不在此处手改。
// 修改约束      : 功能改动需同步更新仿真、综合结果和相关文档。
// ============================================================================

module lu0030_dm_18b20_top  #
(
    parameter  NS_NUM             	= 50  //1us
) 
(	
	input 				clk					,
	input 				rst_n				,
	
	input 				ds18_start_flag		,
	inout 				ds18_dq				,
	//input 				temp_comp_ack		,
	//output reg 			temp_comp_req		,
	output [31:0] 		ms_ls_byte			,
	output [79:0] 		debug_ds_9bytes		,
	
	output [255:0] 		debug_crc			,
	output reg [15:0]  	ds_top_debug		
);

localparam  INIT              		= 3'b001;
localparam  WRITE              		= 3'b010;
localparam  READ               		= 3'b100;

localparam  INIT_BIT              	= 0;
localparam  WRITE_BIT            	= 1;
localparam  READ_BIT           		= 2;

//localparam  NS_NUM             	= 6'd50;  //1us
localparam  US_NUM             	= 10'd1000;  //1.024ms
localparam  S_NUM             	= 4'd5;  

reg [2:0] cur_state;
reg [2:0] last_state;
reg [2:0] next_state;

reg [15:0] rom_wr_cmd;
reg wr_model;
reg state_start_flag;
wire convert_comp_flag;
wire read_comp_flag;

//state conctrl
always @(posedge clk) begin
	if(!rst_n) begin
		cur_state <= INIT;
		last_state <= INIT;
	end
	else begin
		cur_state <= next_state;
		last_state <= cur_state;
	end
end

always @(*) begin
	case(cur_state)
	INIT: begin
		if(ds18_start_flag)
			next_state = WRITE;
		else
			next_state = INIT;
	end
	WRITE: begin
		if(convert_comp_flag)
			next_state = READ;
		else
			next_state = WRITE;
	end
	READ: begin
		if(read_comp_flag) //temp_comp_req & temp_comp_ack
			next_state = INIT;
		else
			next_state = READ;
	end
	default: next_state = INIT;
    endcase
end

always @(posedge clk) begin
	if(!rst_n) begin
		rom_wr_cmd <= 16'd0;
		state_start_flag <= 1'b0;
		wr_model <= 1'b0;
	end
	else if(cur_state[WRITE_BIT] && last_state[INIT_BIT]) begin
		rom_wr_cmd <= 16'h44_cc;
		state_start_flag <= 1'b1;
		wr_model <= 1'b0;
	end
	else if(cur_state[READ_BIT] && last_state[WRITE_BIT]) begin
		rom_wr_cmd <= 16'hbe_cc;
		state_start_flag <= 1'b1;
		wr_model <= 1'b1;
	end
	else begin
		rom_wr_cmd <= rom_wr_cmd;
		state_start_flag <= 1'b0;
		wr_model <= wr_model;
	end
end

lb00ds18b20_ctrl #
(
    .NS_NUM    (NS_NUM)
)
ds18b20_control_u
(	
	.clk			    (clk 				),
	.rst_n				(rst_n 				),

	.ds18_dq			(ds18_dq 			),

	.rom_wr_cmd			(rom_wr_cmd 		),
	.wr_model			(wr_model 			),
	.state_start_flag	(state_start_flag	),
	.convert_comp_flag	(convert_comp_flag	),
	.read_comp_flag		(read_comp_flag 	),
	.ms_ls_byte         (ms_ls_byte 		),
	.debug_ds_9bytes    (debug_ds_9bytes	),
	.debug_crc          (debug_crc			)
);

/*
always @(posedge clk) begin
	ds_top_debug <= {
					 cur_state[2:0] 	, //12-14
					 last_state[2:0]	, //9-11
					 next_state[2:0]	, //6-8
					 wr_model			, //5
					 state_start_flag	, //4
					 convert_comp_flag	, //3
					 ds18_run_keep		, //2
					 temp_comp_req		, //1
					 temp_comp_ack		  //0
					};
end
*/
endmodule
