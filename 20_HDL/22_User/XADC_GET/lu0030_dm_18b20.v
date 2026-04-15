`timescale 1ns / 1ps
// ============================================================================
// 维护注释
//   文件职责      : 板级监控与 DS18B20/XADC 相关逻辑。
//   源码属性      : 手工维护源码，不要把修改同步到生成 IP 或网表。
//   更新要求      : 当时钟、复位、接口或数据顺序假设变化时，同步更新注释。
//   维护边界      : 注释用于说明当前实现意图，不替代接口协议文档。
// ============================================================================

module lb00ds18b20_ctrl #
(
    parameter  NS_NUM             	= 50  //1us
)
(
	input 				clk							,
	input 				rst_n						,
	
	inout 				ds18_dq						,
	
	input [15:0] 		rom_wr_cmd					,
	input 				wr_model					,
	input 				state_start_flag			,
	output reg 			convert_comp_flag			,
	output reg 			read_comp_flag				,
	output reg [31:0] 	ms_ls_byte					,
	output reg [79:0] 	debug_ds_9bytes				,
	output reg [255:0] 	debug_crc
);


localparam  INIT_IDLE              		= 6'b000001;
localparam  RESET_MASTER              	= 6'b000010;
localparam  RESET_SLAVER                = 6'b000100;
localparam  WRITE_CMD             		= 6'b001000;
localparam  WAIT_CONVERT             	= 6'b010000;
localparam  READ_CMD             		= 6'b100000;

localparam  INIT_IDLE_BIT              	= 0;
localparam  RESET_MASTER_BIT            = 1;
localparam  RESET_SLAVER_BIT            = 2;
localparam  WRITE_CMD_BIT             	= 3;
localparam  WAIT_CONVERT_BIT            = 4;
localparam  READ_CMD_BIT             	= 5;

localparam  US_NUM             		= 1023;  //1.024ms
localparam  US_NUM_2             	= 511;
//localparam  MS_NUM             	= 10'd999;

reg [5:0] cur_state;
reg [5:0] last_state;
reg [5:0] next_state;

reg [15:0] th_tl;
reg [15:0] reg_reser1;
reg [15:0] reser2;
reg [15:0] reser3_crc;

reg dq_reg;
reg dq_out_en;
reg ds18_dq_r1;
reg [15:0] ms_ls_reg;
reg [3:0] cmd_shift_cnt;
//time unit is 20ns,the count is 1us
reg [7:0] ns_count;
reg [9:0] us_count;
reg [9:0] ms_count;
always @(posedge clk) begin
	if(cur_state != next_state)
		ns_count <= 8'd0;
	else if(ns_count == NS_NUM)
		ns_count <= 8'd0;
	else begin
		case(cur_state)
		RESET_MASTER,
		RESET_SLAVER,
		WRITE_CMD,
		WAIT_CONVERT,
		READ_CMD:
			ns_count <= ns_count + 1'b1;
		default:
			ns_count <= 8'd0;
		endcase
	end
end

//time unit is 1us,the count is 1ms
always @(posedge clk) begin
	if(!rst_n)
		us_count <= 10'd0;
	//else if(us_count == US_NUM)
	//	us_count <= 10'd0;
	else if(cur_state != next_state)
		us_count <= 10'd0;
	else if(ns_count == NS_NUM)
		us_count <= us_count + 1'b1;	
end

//time unit is 1ms,the count is 1s
always @(posedge clk) begin
	if(!rst_n)
		ms_count <= 10'd0;
	else if(cur_state != next_state)
		ms_count <= 10'd0;
	else if((us_count == US_NUM) && (ns_count == NS_NUM)) //time is 1s
		ms_count <= ms_count + 1'b1;	
end

wire gain_data_comp = ms_count[2] & (us_count == US_NUM_2) & (ns_count == NS_NUM);

//state conctrl
always @(posedge clk) begin
	if(!rst_n) begin
		cur_state <= INIT_IDLE;
		last_state <= INIT_IDLE;
	end
	else begin
		cur_state <= next_state;
		last_state <= cur_state;
	end
end

always @(*) begin
	case(cur_state)
	INIT_IDLE: begin
		if(state_start_flag)
			next_state = RESET_MASTER;
		else
			next_state = INIT_IDLE;
	end
	RESET_MASTER: begin
		if(us_count == 10'd600)  //600us
			next_state = RESET_SLAVER;
		else
			next_state = RESET_MASTER;
	end
	RESET_SLAVER: begin
		if((us_count == 10'd600) && ds18_dq_r1) 
			next_state = RESET_MASTER;  //initial failt,again initial
		else 
		if(us_count == 10'd600)
		    next_state = WRITE_CMD; 
		else
			next_state = RESET_SLAVER; 
	end
	WRITE_CMD: begin
		if(ms_count[0] && wr_model) //1bit time is 64us,16bit is 1024us
			next_state = READ_CMD;
		else if(ms_count[0])
			next_state = WAIT_CONVERT;
		else
			next_state = WRITE_CMD;
	end
	WAIT_CONVERT: begin
		if(ms_count == 10'd800) //about 819ms action:800,sim:100
			next_state = INIT_IDLE;
		else
			next_state = WAIT_CONVERT;
	end
	READ_CMD: begin
		if(gain_data_comp) //gain the values of temperature
			next_state = INIT_IDLE;
		else
			next_state = READ_CMD;
	end
	default:next_state = INIT_IDLE;
	endcase
end

//state data out
always @(posedge clk) begin
	case(cur_state)
	INIT_IDLE: begin
		dq_out_en <= 1'b0;
		dq_reg <= 1'b1;
	end
	RESET_MASTER: begin
//		if(us_count == 10'd750) begin
//			dq_out_en <= 1'b0;
//			dq_reg <= 1'b1;
//		end
//		else begin
			dq_out_en <= 1'b1;
			dq_reg <= 1'b0;
//		end
	end
	RESET_SLAVER: begin
	    dq_out_en <= 1'b0;
	    dq_reg <= 1'b1;
	end
	WRITE_CMD: begin
		if(!ms_count[0] & (us_count[5:0] < 6'd10)) begin //!ms_count[0] avoid dq_out_en is 1 when ms_count[0]( although only one clock cycle)
			dq_out_en <= 1'b1;
			dq_reg <= 1'b0;
		end
		else if(us_count[5:0] >= 6'd60)begin
			dq_out_en <= 1'b0;
			dq_reg <= 1'b1;
		end
		else if(us_count[5:0] >= 6'd10) begin
			//dq_out_en <= 1'b1;
			dq_reg <= rom_wr_cmd[cmd_shift_cnt];
		end
	end
	READ_CMD: begin
		if(us_count[5:0] < 6'd3) begin
			dq_out_en <= 1'b1;
			dq_reg <= 1'b0;
		end
		else if((us_count[5:0] == 6'd11) && (ns_count == NS_NUM)) begin  //before us_count[5:0] == 6'd11 collection
			//dq_out_en <= 1'b0;
			case(ms_count[2:0])
				3'd0:ms_ls_reg[cmd_shift_cnt] <= ds18_dq_r1;
				3'd1:th_tl[cmd_shift_cnt] <= ds18_dq_r1;
				3'd2:reg_reser1[cmd_shift_cnt] <= ds18_dq_r1;
				3'd3:reser2[cmd_shift_cnt] <= ds18_dq_r1;
				3'd4:reser3_crc[cmd_shift_cnt] <= ds18_dq_r1;
				default:;
			endcase
		end
		else begin
			dq_out_en <= 1'b0;
			dq_reg <= 1'b1;
		end
	end
	default: begin
		dq_out_en <= 1'b0;
		dq_reg <= 1'b1;
	end
	endcase
end

//judge ds18b20 is or not ack(presence pulse)
always @(posedge clk) begin
	if(cur_state[RESET_SLAVER_BIT] && !ds18_dq) //  && !ds18_dq, (us_count == 10'd120),pullup:15,slaver:55;pullup:60,slaver:10
		ds18_dq_r1 <= ds18_dq;
	else if(cur_state[READ_CMD_BIT])
		ds18_dq_r1 <= ds18_dq;
	else
		ds18_dq_r1 <= ds18_dq_r1;
end

//write_cmd shift output:rom_cmd+ wr_cmd ,a total of 16 bit
always @(posedge clk) begin
	if(!rst_n)
		cmd_shift_cnt <= 4'd0;
	else if(cur_state != last_state)
		cmd_shift_cnt <= 4'd0;
	else if(cur_state[WRITE_CMD_BIT] && (us_count[5:0] == 6'd63) && (ns_count[7:0] == NS_NUM)) //pullup:15,slaver:55;pullup:60,slaver:10
		cmd_shift_cnt <= cmd_shift_cnt + 1'b1;
	else if(cur_state[READ_CMD_BIT] && (us_count[5:0] == 6'd63) && (ns_count[7:0] == NS_NUM))
		cmd_shift_cnt <= cmd_shift_cnt + 1'b1;
end

//convert temperature finish
always @(posedge clk) begin
	if(cur_state[WAIT_CONVERT_BIT] && (ms_count == 10'd800))
		convert_comp_flag <= 1'b1;
	else
		convert_comp_flag <= 1'b0;
end

//Temperature values obtained
always @(posedge clk) begin
	if(cur_state[READ_CMD_BIT] && next_state[INIT_IDLE_BIT])
		read_comp_flag <= 1'b1;
	else
		read_comp_flag <= 1'b0;
end

always @(posedge clk) begin
	if(cur_state[READ_CMD_BIT] && next_state[INIT_IDLE_BIT] && (&ms_ls_reg[15:11])) //temperature is lower than 0C
		ms_ls_byte <= {15'd0,1'b1,5'd0,~ms_ls_reg[10:0] + 1'b1}; //~ms_ls_byte[15:0] must't be 16'hffff
	else if(cur_state[READ_CMD_BIT] && next_state[INIT_IDLE_BIT])
		ms_ls_byte <= {21'd0,ms_ls_reg[10:0]};
end

assign ds18_dq = dq_out_en ? dq_reg : 1'bz;
//assign ds18_dq = dq_out_en ? dq_reg : 1'b0; //sim

/*
//*********************debug**********************************
reg [2:0] crc_num;
reg [71:0] crc_data;
wire [7:0] crc_out;
reg crc_en_flag;

always @(posedge clk) begin
	debug_ds_9bytes <={
						
						reser3_crc,
						reser2,
						reg_reser1,
						th_tl,
						ms_ls_reg
						};
end

//*******************debug **************************

always @(posedge clk) begin
	debug_crc <={
				 wr_model				,//137
				 debug_ds_9bytes[79:0]	,//57-136
				 ms_count[9:0]			,//47-56
				 us_count[9:0]			,//37-46
				 cur_state[5:0]			,//31-36
				 next_state[5:0]		,//25-30
				 last_state[5:0]		,//19-24
				 crc_out[7:0]			,//11-18
				 cmd_shift_cnt[3:0]		,//7-10
				 dq_out_en				,//6
				 dq_reg					,//5
				 gain_data_comp			,//4
				 state_start_flag		,//3
				 ds18_dq_r1				,//2
				 read_comp_flag			,//1
				 convert_comp_flag       //0
				 };
end

//***************crc section*********************
wire [7:0] crc_in;
always @(posedge clk) begin
	if(!rst_n)
		crc_en_flag <= 1'b0;
	else if(&crc_num[2:0])
		crc_en_flag <= 1'b0;
	else if(cur_state[READ_CMD_BIT] && next_state[INIT_IDLE_BIT])
		crc_en_flag <= 1'b1;
end

always @(posedge clk) begin
	if(!rst_n)
		crc_num <= 3'b0;
	else if(crc_en_flag)
		crc_num <= crc_num + 1'b1;
end

always @(posedge clk) begin
	if(!rst_n)
		crc_data <= 'b0;
	else if(cur_state[READ_CMD_BIT] && next_state[INIT_IDLE_BIT])
		crc_data <= debug_ds_9bytes[71:0];
	else if(crc_en_flag)
		crc_data <= {8'b0,crc_data[71:8]};
end

function integer bit_swap;
input integer in_data;
begin:swap
    integer i;
    for(i=0;i<8;i=i+1)
            bit_swap[i] = in_data[7-i];
end
endfunction

assign crc_in = bit_swap(crc_data[7:0]);

lb00ds18_crc8 crc8
(
	.clk 			(clk 			),
	.rst_n 			(rst_n 			),
	.data_in 		(crc_in      	),
	.crc_reset	 	(!crc_en_flag   ),
	.crc_en 		(crc_en_flag 	),
	.crc_out 		(crc_out 		)
);
*/
endmodule

