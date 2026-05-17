module srio_insert_doorbell (
    input               aclk,
    input               aresetn,

    // 输入 SRIO SWRITE (HELLO 模式)
    input               s_axis_tvalid,
    output           	s_axis_tready,
    input       [63:0]  s_axis_tdata,
    input               s_axis_tlast,

    // 输出 SWRITE + DOORBELL
    output           	m_axis_tvalid,
    input               m_axis_tready,
    output   	[63:0]  m_axis_tdata,
    output           	m_axis_tlast
);

    reg           	dbel_axis_tvalid = 0;
    wire              dbel_axis_tready;
    wire   	[63:0]  dbel_axis_tdata;
    wire           	dbel_axis_tlast= 1'b1;

// ==================== 配置参数（完全贴合手册）====================
localparam  TARGET_ADDR     = 34'h0000_00800f00; // 触发地址
localparam  DOORBELL_TID    = 8'h00;              // 事务ID


reg	[15:0]  	DOORBELL_INFO   = 16'h0000		;           // 自定义info（tdata[31:16]）

// ==================== Doorbell 固定帧（100% 符合手册）====================
wire	 [63:0] DOORBELL_TDATA = {
    DOORBELL_TID,    // [63:56] TID
    4'b1010,         // [55:52] FTYPE=10 (Doorbell)
    4'b0000,         // [51:48] TTYPE=0
    8'h00,           // [47:40] size=0
    8'h00,           // [39:32] 保留
    DOORBELL_INFO,   // [31:16] info（手册定义的位置）
    16'h0000         // [15:0] 保留
};

// ==================== 状态机 ====================
localparam  S_IDLE      = 0;
localparam  S_DOORBELL  = 1;

reg [1:0] cur_state;
reg [5:0] beat_cnt;
reg       addr_match;

// ==================== 地址检测 （SWRITE的地址beat）====================
always @(posedge aclk or negedge aresetn) begin
    if (!aresetn)
        addr_match <= 1'b0;
    else if (s_axis_tvalid && s_axis_tready && beat_cnt == 0)
        addr_match <= (s_axis_tdata[33:00] == TARGET_ADDR[33:0]);
        //addr_match <= (s_axis_tdata[15:00] == TARGET_ADDR[15:0]);

    else if (cur_state == S_DOORBELL)
        addr_match <= 1'b0;
end

// ==================== 包节拍计数 ====================
always @(posedge aclk or negedge aresetn) begin
    if (!aresetn)
        beat_cnt <= 0;
    else if (s_axis_tlast && s_axis_tvalid && s_axis_tready)
        beat_cnt <= 0;
    else if (s_axis_tvalid && s_axis_tready)
        beat_cnt <= beat_cnt + 1'b1;
end


	assign		dbel_axis_tready	= cur_state== S_IDLE	?	1'b0	:	m_axis_tready	;

	assign		s_axis_tready		= cur_state== S_IDLE	?	m_axis_tready	:	1'b0	;
	
	assign		m_axis_tvalid		= cur_state== S_IDLE	?	s_axis_tvalid	:	dbel_axis_tvalid	;
	
	assign		m_axis_tdata		= cur_state== S_IDLE	?	
																(beat_cnt == 0)	?   DOORBELL_INFO[0]==1 ? {s_axis_tdata[63:32],8'h80,s_axis_tdata[23:00]}:{s_axis_tdata[63:32],8'h81,s_axis_tdata[23:00]} 
																				:	s_axis_tdata	
															:	dbel_axis_tdata		;


//	assign		m_axis_tdata		= 0;	
	
	assign		m_axis_tlast		= cur_state== S_IDLE	?	s_axis_tlast	:	dbel_axis_tlast		;
	//assign		m_axis_tkeep		<= cur_state== S_IDLE	?	s_axis_tkeep	:	dbel_axis_tkeep		;
	
//                m_axis_tdata  <= s_axis_tdata[63:32];   
//                
//                if(beat_cnt == 0)begin
//                	m_axis_tdata[31:24]  <= DOORBELL_INFO==0 ? 8'h80:8'h81;   
//                end else begin	  
//                	m_axis_tdata[31:24]  <= s_axis_tdata[31:24];   
//                end	
//
//                m_axis_tdata[23:00]  <= s_axis_tdata[23:00];   	
	
	        assign        dbel_axis_tdata   = DOORBELL_TDATA;

// ==================== 主状态机 ====================
always @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
        cur_state     <= S_IDLE;
        dbel_axis_tvalid <= 1'b0;
    end else begin
        case (cur_state)
            S_IDLE: begin
                // 指定地址的SWRITE发送完成，插入Doorbell
                if (s_axis_tlast && s_axis_tvalid && s_axis_tready&addr_match) begin
	                    DOORBELL_INFO	<=~DOORBELL_INFO;
	                    dbel_axis_tvalid  <= 1'b1;
	                    cur_state     	<= S_DOORBELL;
	            end else begin
	            	    dbel_axis_tvalid <= 1'b0;
	                    cur_state <= cur_state;
	            end
            end

            // 插入Doorbell（单beat，完全符合手册）
            S_DOORBELL: begin
                dbel_axis_tvalid  <= 1'b1;

                if (dbel_axis_tready)begin
                    dbel_axis_tvalid <= 1'b0;
                    cur_state <= S_IDLE;
                end else begin
                    dbel_axis_tvalid <= 1'b1;
                    cur_state <= cur_state;
                end	     
            end

            default: cur_state <= S_IDLE;
        endcase
    end
end


endmodule


//module axis_register_slice (
//    input               aclk,
//    input               aresetn,
//
//    input               s_axis_tvalid,
//    output wire         s_axis_tready,
//    input       [63:0]  s_axis_tdata,
//    input               s_axis_tlast,
//
//    output reg          m_axis_tvalid,
//    input               m_axis_tready,
//    output reg  [63:0]  m_axis_tdata,
//    output reg          m_axis_tlast
//);
//	assign	s_axis_tready						= ~fifo_full								;
//	assign	fifo_wen							= s_axis_tvalid && s_axis_tready			;
//	assign	fifo_wdata							= s_axis_tdata								;
//
//
//	assign m_axis_tvalid 						= !fifo_empty								;
//	assign m_axis_tdata 						= fifo_rdata[64-1:0]					;
//	assign fifo_ren 							= m_axis_tvalid & m_axis_tready				;


//endmodule

/*


Hello的srio包模式，
输入为axis的swrite报文，输出为axis的swrite保温和doorbell报文；
地址为0x8000的swrite包后之间插入一包doorbell、Verilog编写
符合 AXI-Stream 标准的 SRIO 插入 Doorbell 模块 (Verilog)
我给你写工业级、可直接上板、纯 AXI-Stream 接口的代码：
输入：AXIS-Stream SRIO SWRITE 报文
输出：AXIS-Stream SRIO 报文（自动插入规则）
规则：检测到地址 = 0x8000的 SWRITE 包发送完成后，自动插入 1 包 Doorbell
协议：SRIO 2.1，64bit AXIS
一、核心功能说明
透传所有输入的 SWRITE 报文
检测包中地址 == 0x8000
该包发送完（tlast）后，自动插入 1 包 Doorbell
再继续透传后续报文
完全 AXI-Stream 握手，无数据丢失
*/