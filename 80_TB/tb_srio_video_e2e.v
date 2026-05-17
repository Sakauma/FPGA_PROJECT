`timescale 1ns / 1ps
// ============================================================================
// 新代码：Egor Izmaylov
// 文件职责：SRIO 图像输入到输出的端到端行为仿真平台。
// 验证范围：按原始工程 SRIO 图像包格式写入 BRAM，再检查 BRAM 读出到 SRIO_T_axis 的包协议。
// 维护边界：本 testbench 不实例化真实 SRIO IP，只用 AXIS 合约模型验证 TX 入口 keep/user/ready 条件。
// ============================================================================

module tb_srio_video_e2e;
    localparam integer A_RAM_WIDTH  = 64;
    // 新代码：Egor Izmaylov 新工程 SRIO_2_Video 默认 A_RAM_DEPTH=256*512，TB 必须与真实工程一致。
    localparam integer A_RAM_DEPTH  = 256 * 512;
    localparam integer B_RAM_WIDTH  = 16;
    localparam integer B_RAM_DEPTH  = A_RAM_WIDTH * A_RAM_DEPTH / B_RAM_WIDTH;
    localparam integer P_LINE_DEPTH = 256;
    localparam integer HALF_DEPTH   = P_LINE_DEPTH / 2;

    localparam integer PACKETS_PER_LINE = 16;
    localparam integer PAYLOADS_PER_PACKET = 32;
    localparam integer PIXELS_PER_PAYLOAD = 4;
    localparam integer PIXELS_PER_PACKET = PAYLOADS_PER_PACKET * PIXELS_PER_PAYLOAD;
    localparam integer WORDS_PER_PACKET = 1 + PAYLOADS_PER_PACKET;
    localparam integer TX_CAPTURE_DEPTH = 65536;
    localparam integer MAX_WATERMARK_LINES = 4096;
    localparam integer WATERMARK_REPEAT_THRESHOLD_PCT = 90;

    reg srio_clk = 1'b0;
    reg user_clk = 1'b0;
    always #4 srio_clk = ~srio_clk;
    always #2 user_clk = ~user_clk;

    reg srio_rstn_i = 1'b0;
    reg user_rstn_i = 1'b0;

    reg  [63:0] srio_r_axis_tdata = 64'd0;
    reg  [31:0] srio_r_axis_tuser = 32'd0;
    wire        srio_r_axis_tready;
    reg         srio_r_axis_tvalid = 1'b0;
    reg         srio_r_axis_tlast  = 1'b0;

    wire [63:0] srio_t_axis_tdata;
    wire [31:0] srio_t_axis_tuser;
    wire        srio_t_axis_tready;
    wire        srio_t_axis_tvalid;
    wire        srio_t_axis_tlast;

    wire [3:0]  v_lut_axi_arid;
    wire [31:0] v_lut_axi_araddr;
    wire [7:0]  v_lut_axi_arlen;
    wire [2:0]  v_lut_axi_arsize;
    wire [1:0]  v_lut_axi_arburst;
    wire        v_lut_axi_arlock;
    wire [3:0]  v_lut_axi_arcache;
    wire [2:0]  v_lut_axi_arprot;
    wire [3:0]  v_lut_axi_arqos;
    wire        v_lut_axi_arvalid;
    wire        v_lut_axi_rready;

    reg         tb_failed = 1'b0;
    reg         tx_ready_gate = 1'b1;
    reg         tx_ready_random_gate = 1'b1;
    reg [7:0]   tx_video_tkeep = 8'hFF;

    integer tb_lines;
    integer tb_backpressure_cycles;
    integer tb_global_timeout_cycles;
    integer tb_packet_gap_cycles;
    integer tb_backpressure_all;
    integer tb_random_ready;
    integer tb_drain_cycles;
    integer tb_strict_drain;
    integer tx_valid_seen;
    integer tx_valid_wait_count;
    integer input_word_count;
    integer tx_capture_wr;
    integer tx_capture_rd;
    integer checked_header_count;
    integer checked_payload_count;
    integer checked_tlast_count;
    integer watermark_samples;
    integer watermark_unique_count;
    integer watermark_min_line;
    integer watermark_max_line;
    integer watermark_best_period;
    integer watermark_best_matches;
    reg [31:0] tb_random_seed = 32'h1ace_b00c;
    reg [31:0] ready_lfsr;
    reg [63:0] held_tdata;
    reg        held_tlast;
    reg        holding_axis_word;
    reg [2047:0] watermark_source_seen;
    integer output_source_line [0:MAX_WATERMARK_LINES-1];

    // 新代码：Egor Izmaylov
    // 记录每一次真实 SRIO_T_axis 握手，检查任务从捕获队列读取，避免 backpressure 恢复时漏采 header。
    reg [64:0] tx_capture_fifo [0:TX_CAPTURE_DEPTH-1];

    assign srio_t_axis_tready = tx_ready_gate &&
                                tx_ready_random_gate &&
                                (tx_video_tkeep === 8'hFF) &&
                                (^srio_t_axis_tuser !== 1'bx);

    always @(posedge srio_clk) begin
        if (!srio_rstn_i || !user_rstn_i) begin
            tx_capture_wr <= 0;
        end else if (srio_t_axis_tvalid && srio_t_axis_tready) begin
            if ((tx_capture_wr - tx_capture_rd) >= TX_CAPTURE_DEPTH) begin
                $display("ERROR: capture overflow wr=%0d rd=%0d pending=%0d",
                         tx_capture_wr, tx_capture_rd, tx_capture_wr - tx_capture_rd);
                tb_failed <= 1'b1;
                $display("FAIL: tb_srio_video_e2e");
                $finish;
            end else begin
                tx_capture_fifo[tx_capture_wr[15:0]] <= {srio_t_axis_tlast, srio_t_axis_tdata};
                tx_capture_wr <= tx_capture_wr + 1;
            end
        end
    end

    always @(posedge srio_clk) begin
        if (!srio_rstn_i || !user_rstn_i || (tb_random_ready == 0)) begin
            ready_lfsr <= tb_random_seed;
            tx_ready_random_gate <= 1'b1;
        end else begin
            ready_lfsr <= {ready_lfsr[30:0],
                           ready_lfsr[31] ^ ready_lfsr[21] ^ ready_lfsr[1] ^ ready_lfsr[0]};
            tx_ready_random_gate <= (ready_lfsr[3:0] != 4'h0);
        end
    end

    SRIO_2_Video #(
        .A_RAM_WIDTH        ( A_RAM_WIDTH  ),
        .A_RAM_DEPTH        ( A_RAM_DEPTH  ),
        .B_RAM_WIDTH        ( B_RAM_WIDTH  ),
        .B_RAM_DEPTH        ( B_RAM_DEPTH  ),
        .RAM_OUT_REG_EN     ( "DISABLE"   ),
        .RAM_STYLE          ( "block"     ),
        .P_LINE_DEPTH       ( P_LINE_DEPTH )
    ) dut (
        .srio_clk           ( srio_clk             ),
        .srio_rstn_i        ( srio_rstn_i          ),
        .user_clk           ( user_clk             ),
        .user_rstn_i        ( user_rstn_i          ),
        .SRIO_R_axis_tdata  ( srio_r_axis_tdata    ),
        .SRIO_R_axis_tuser  ( srio_r_axis_tuser    ),
        .SRIO_R_axis_tready ( srio_r_axis_tready   ),
        .SRIO_R_axis_tvalid ( srio_r_axis_tvalid   ),
        .SRIO_R_axis_tlast  ( srio_r_axis_tlast    ),
        .SRIO_T_axis_tdata  ( srio_t_axis_tdata    ),
        .SRIO_T_axis_tuser  ( srio_t_axis_tuser    ),
        .SRIO_T_axis_tready ( srio_t_axis_tready   ),
        .SRIO_T_axis_tvalid ( srio_t_axis_tvalid   ),
        .SRIO_T_axis_tlast  ( srio_t_axis_tlast    ),
        .V_LUT_AXI_clk      ( user_clk             ),
        .V_LUT_AXI_rstn     ( user_rstn_i          ),
        .V_LUT_AXI_ARID     ( v_lut_axi_arid       ),
        .V_LUT_AXI_ARADDR   ( v_lut_axi_araddr     ),
        .V_LUT_AXI_ARLEN    ( v_lut_axi_arlen      ),
        .V_LUT_AXI_ARSIZE   ( v_lut_axi_arsize     ),
        .V_LUT_AXI_ARBURST  ( v_lut_axi_arburst    ),
        .V_LUT_AXI_ARLOCK   ( v_lut_axi_arlock     ),
        .V_LUT_AXI_ARCACHE  ( v_lut_axi_arcache    ),
        .V_LUT_AXI_ARPROT   ( v_lut_axi_arprot     ),
        .V_LUT_AXI_ARQOS    ( v_lut_axi_arqos      ),
        .V_LUT_AXI_ARVALID  ( v_lut_axi_arvalid    ),
        .V_LUT_AXI_ARREADY  ( 1'b1                 ),
        .V_LUT_AXI_RID      ( 4'd0                 ),
        .V_LUT_AXI_RDATA    ( 64'd0                ),
        .V_LUT_AXI_RRESP    ( 2'd0                 ),
        .V_LUT_AXI_RLAST    ( 1'b0                 ),
        .V_LUT_AXI_RVALID   ( 1'b0                 ),
        .V_LUT_AXI_RREADY   ( v_lut_axi_rready     )
    );

    function [15:0] pixel_value;
        input integer line;
        input integer x;
        begin
            // 新代码：Egor Izmaylov
            // 高 11 bit 编码源行号，低 5 bit 保留列内变化；用于检测压缩重复输出是否只来自少数源行。
            pixel_value = {line[10:0], x[4:0]};
        end
    endfunction

    function integer decode_source_line_from_pixel;
        input [15:0] pixel;
        begin
            decode_source_line_from_pixel = pixel[15:5];
        end
    endfunction

    function [63:0] payload_word;
        input integer line;
        input integer x_base;
        reg [15:0] p0;
        reg [15:0] p1;
        reg [15:0] p2;
        reg [15:0] p3;
        begin
            p0 = pixel_value(line, x_base + 0);
            p1 = pixel_value(line, x_base + 1);
            p2 = pixel_value(line, x_base + 2);
            p3 = pixel_value(line, x_base + 3);
            payload_word = {p3, p2, p1, p0};
        end
    endfunction

    function [63:0] srio_image_header;
        input integer line;
        input integer packet_idx;
        reg [33:0] srio_addr;
        begin
            srio_addr = ((line & 32'h00000fff) << 12) | ((packet_idx & 32'h0000000f) << 8);
            srio_image_header = 64'd0;
            srio_image_header[63:56] = 8'h01;
            srio_image_header[55:52] = 4'h6;
            srio_image_header[51:48] = 4'h0;
            srio_image_header[43:36] = 8'h00;
            srio_image_header[33:0]  = srio_addr;
        end
    endfunction

    function [63:0] expected_output_header;
        input integer line;
        input integer packet_idx;
        reg [31:0] srio_addr;
        begin
            srio_addr = ((line & 32'h00000fff) << 12) | ((packet_idx & 32'h0000000f) << 8);
            // 新代码：Egor Izmaylov 新工程在 SRIO_2_Video 输出端串接 srio_insert_doorbell，
            // 该模块会把 SWRITE header 的地址高字节固定改写为 8'h81。
            expected_output_header = {32'h0060_2000, 8'h81, srio_addr[23:0]};
        end
    endfunction

    task reset_watermark_stats;
        integer i;
        begin
            watermark_samples = 0;
            watermark_unique_count = 0;
            watermark_min_line = 2048;
            watermark_max_line = -1;
            watermark_best_period = 0;
            watermark_best_matches = 0;
            watermark_source_seen = 2048'd0;
            for (i = 0; i < MAX_WATERMARK_LINES; i = i + 1) begin
                output_source_line[i] = -1;
            end
        end
    endtask

    task record_source_line;
        input [255:0] case_name;
        input integer out_line;
        input integer packet_idx;
        input integer payload_idx;
        input integer lane_idx;
        input integer src_line;
        begin
            if ((src_line < 0) || (src_line > 2047)) begin
                $display("ERROR: watermark source line out of range case=%0s line=%0d packet=%0d payload=%0d lane=%0d src_line=%0d",
                         case_name, out_line, packet_idx, payload_idx, lane_idx, src_line);
                tb_failed = 1'b1;
            end else begin
                watermark_samples = watermark_samples + 1;
                if (!watermark_source_seen[src_line]) begin
                    watermark_source_seen[src_line] = 1'b1;
                    watermark_unique_count = watermark_unique_count + 1;
                end
                if (src_line < watermark_min_line) begin
                    watermark_min_line = src_line;
                end
                if (src_line > watermark_max_line) begin
                    watermark_max_line = src_line;
                end
                if ((out_line >= 0) && (out_line < MAX_WATERMARK_LINES) &&
                    (packet_idx == 0) && (payload_idx == 0) && (lane_idx == 0)) begin
                    output_source_line[out_line] = src_line;
                end
            end
        end
    endtask

    task record_watermark_word;
        input [255:0] case_name;
        input integer out_line;
        input integer packet_idx;
        input integer payload_idx;
        input [63:0] data;
        reg [15:0] p0;
        reg [15:0] p1;
        reg [15:0] p2;
        reg [15:0] p3;
        begin
            p0 = data[15:0];
            p1 = data[31:16];
            p2 = data[47:32];
            p3 = data[63:48];
            record_source_line(case_name, out_line, packet_idx, payload_idx, 0, decode_source_line_from_pixel(p0));
            record_source_line(case_name, out_line, packet_idx, payload_idx, 1, decode_source_line_from_pixel(p1));
            record_source_line(case_name, out_line, packet_idx, payload_idx, 2, decode_source_line_from_pixel(p2));
            record_source_line(case_name, out_line, packet_idx, payload_idx, 3, decode_source_line_from_pixel(p3));
        end
    endtask

    task analyze_watermark;
        input [255:0] case_name;
        input integer compare_payload;
        integer min_unique;
        integer period;
        integer line_idx;
        integer compared;
        integer repeat_matches;
        integer best_period;
        integer best_matches;
        integer best_compared;
        begin
            if (compare_payload) begin
                disable analyze_watermark;
            end

            if (watermark_samples == 0) begin
                $display("ERROR: watermark has no samples case=%0s", case_name);
                tb_failed = 1'b1;
                disable analyze_watermark;
            end

            min_unique = tb_lines / 2;
            if (min_unique < 4) begin
                min_unique = 4;
            end
            if (tb_lines < 8) begin
                min_unique = 1;
            end

            if (watermark_unique_count < min_unique) begin
                $display("ERROR: watermark source-line coverage too narrow case=%0s unique=%0d min_required=%0d min_line=%0d max_line=%0d",
                         case_name, watermark_unique_count, min_unique, watermark_min_line, watermark_max_line);
                tb_failed = 1'b1;
            end

            best_period = 0;
            best_matches = 0;
            best_compared = 0;
            if (tb_lines >= 32) begin
                for (period = 2; period <= (tb_lines / 2); period = period + 1) begin
                    compared = 0;
                    repeat_matches = 0;
                    for (line_idx = 0; line_idx < (tb_lines - period); line_idx = line_idx + 1) begin
                        if ((line_idx < MAX_WATERMARK_LINES) &&
                            ((line_idx + period) < MAX_WATERMARK_LINES) &&
                            (output_source_line[line_idx] >= 0) &&
                            (output_source_line[line_idx + period] >= 0)) begin
                            compared = compared + 1;
                            if (output_source_line[line_idx] == output_source_line[line_idx + period]) begin
                                repeat_matches = repeat_matches + 1;
                            end
                        end
                    end
                    if (repeat_matches > best_matches) begin
                        best_matches = repeat_matches;
                        best_period = period;
                        best_compared = compared;
                    end
                    if ((compared > (tb_lines / 4)) &&
                        ((repeat_matches * 100) >= (compared * WATERMARK_REPEAT_THRESHOLD_PCT))) begin
                        $display("ERROR: periodic repeated source lines case=%0s period=%0d matches=%0d compared=%0d threshold_pct=%0d",
                                 case_name, period, repeat_matches, compared, WATERMARK_REPEAT_THRESHOLD_PCT);
                        tb_failed = 1'b1;
                    end
                end
            end

            watermark_best_period = best_period;
            watermark_best_matches = best_matches;
            $display("INFO: watermark summary case=%0s samples=%0d unique=%0d min_line=%0d max_line=%0d best_period=%0d best_matches=%0d compared=%0d seed=%h",
                     case_name, watermark_samples, watermark_unique_count, watermark_min_line, watermark_max_line,
                     best_period, best_matches, best_compared, tb_random_seed);
        end
    endtask

    task check_no_extra_output;
        input [255:0] case_name;
        integer drain_idx;
        begin
            tx_ready_gate = 1'b1;
            for (drain_idx = 0; drain_idx < tb_drain_cycles; drain_idx = drain_idx + 1) begin
                @(posedge srio_clk);
                if ((tx_capture_wr > tx_capture_rd) || srio_t_axis_tvalid) begin
                    $display("INFO: extra output observed after checked frame case=%0s drain_cycle=%0d wr=%0d rd=%0d tvalid=%b tdata=%h tlast=%b strict=%0d",
                             case_name, drain_idx, tx_capture_wr, tx_capture_rd,
                             srio_t_axis_tvalid, srio_t_axis_tdata, srio_t_axis_tlast,
                             tb_strict_drain);
                    if (tb_strict_drain != 0) begin
                        tb_failed = 1'b1;
                    end
                    disable check_no_extra_output;
                end
            end
        end
    endtask

    task fail;
        input [1023:0] msg;
        begin
            tb_failed = 1'b1;
            $display("ERROR: %0s", msg);
        end
    endtask

    task reset_dut;
        begin
            srio_rstn_i = 1'b0;
            user_rstn_i = 1'b0;
            srio_r_axis_tdata = 64'd0;
            srio_r_axis_tuser = 32'd0;
            srio_r_axis_tvalid = 1'b0;
            srio_r_axis_tlast = 1'b0;
            tx_ready_gate = 1'b1;
            tx_ready_random_gate = 1'b1;
            tx_valid_seen = 0;
            tx_valid_wait_count = 0;
            input_word_count = 0;
            tx_capture_rd = 0;
            holding_axis_word = 1'b0;
            repeat (20) @(posedge srio_clk);
            srio_rstn_i = 1'b1;
            user_rstn_i = 1'b1;
            repeat (50) @(posedge srio_clk);
        end
    endtask

    task send_axis_word;
        input [63:0] data;
        input        last;
        integer wait_cycles;
        begin
            wait_cycles = 0;
            @(posedge srio_clk);
            srio_r_axis_tdata  <= data;
            srio_r_axis_tvalid <= 1'b1;
            srio_r_axis_tlast  <= last;
            while (!srio_r_axis_tready) begin
                @(posedge srio_clk);
                wait_cycles = wait_cycles + 1;
                if (wait_cycles > 20000) begin
                    $display("ERROR: timeout waiting for SRIO_R_axis_tready data=%h last=%b", data, last);
                    $display("DEBUG: input_word_count=%0d parse_state=%b srio_data_full=%b srio_data_empty=%b srio_data_ren=%b trn_empty=%b trn_ren=%b",
                             input_word_count,
                             dut.i_srio_v_axis_to_bram_top.i_srio_v_axis_to_fifo.S_PARSE_CM,
                             dut.i_srio_v_axis_to_bram_top.i_srio_v_axis_to_fifo.srio_data_fifo_full,
                             dut.i_srio_v_axis_to_bram_top.srio_data_fifo_empty,
                             dut.i_srio_v_axis_to_bram_top.srio_data_fifo_ren,
                             dut.i_srio_v_axis_to_bram_top.srio_trn_fifo_empty,
                             dut.i_srio_v_axis_to_bram_top.srio_trn_fifo_ren);
                    $display("DEBUG: write_state=%b wb_state=%b m_req=%b m_gnt=%b wvalid=%b wlast=%b bram_wea=%b bram_line_cur_w=%h bram_line_cur_w_en=%b",
                             dut.i_srio_v_axis_to_bram_top.i_srio_v_fifo_to_bram_top.i_srio_v_fifo_to_bram_write.S_AXIW_CM,
                             dut.i_srio_v_axis_to_bram_top.i_srio_v_fifo_to_bram_top.i_srio_v_fifo_to_bram_wb.S_AXI_CM,
                             dut.i_srio_v_axis_to_bram_top.i_srio_v_fifo_to_bram_top.m_axiw_req,
                             dut.i_srio_v_axis_to_bram_top.i_srio_v_fifo_to_bram_top.m_axiw_gnt,
                             dut.i_srio_v_axis_to_bram_top.i_srio_v_fifo_to_bram_top.i_srio_v_fifo_to_bram_wb.M_AXI_WVALID,
                             dut.i_srio_v_axis_to_bram_top.i_srio_v_fifo_to_bram_top.i_srio_v_fifo_to_bram_wb.M_AXI_WLAST,
                             dut.bram_wea,
                             dut.bram_line_cur_w,
                             dut.bram_line_cur_w_en);
                    tb_failed = 1'b1;
                    srio_r_axis_tvalid <= 1'b0;
                    srio_r_axis_tlast  <= 1'b0;
                    srio_r_axis_tdata  <= 64'd0;
                    $display("FAIL: tb_srio_video_e2e");
                    $finish;
                    disable send_axis_word;
                end
            end
            input_word_count = input_word_count + 1;
            @(posedge srio_clk);
            srio_r_axis_tvalid <= 1'b0;
            srio_r_axis_tlast  <= 1'b0;
            srio_r_axis_tdata  <= 64'd0;
        end
    endtask

    task send_srio_image_packet;
        input integer line;
        input integer packet_idx;
        integer payload_idx;
        integer x_base;
        integer gap_idx;
        begin
            send_axis_word(srio_image_header(line, packet_idx), 1'b0);
            for (payload_idx = 0; payload_idx < PAYLOADS_PER_PACKET; payload_idx = payload_idx + 1) begin
                x_base = packet_idx * PIXELS_PER_PACKET + payload_idx * PIXELS_PER_PAYLOAD;
                send_axis_word(payload_word(line, x_base), payload_idx == (PAYLOADS_PER_PACKET - 1));
            end
            for (gap_idx = 0; gap_idx < tb_packet_gap_cycles; gap_idx = gap_idx + 1) begin
                @(posedge srio_clk);
            end
        end
    endtask

    task send_srio_image_lines;
        input integer lines_to_send;
        integer line;
        integer packet_idx;
        begin
            for (line = 0; line < lines_to_send; line = line + 1) begin
                for (packet_idx = 0; packet_idx < PACKETS_PER_LINE; packet_idx = packet_idx + 1) begin
                    send_srio_image_packet(line, packet_idx);
                end
            end
        end
    endtask

    task check_one_output_line;
        input [255:0] case_name;
        input integer expected_line;
        input integer compare_payload;
        integer packet_idx;
        integer word_idx;
        integer x_base;
        reg [63:0] got_data;
        reg        got_last;
        begin
            for (packet_idx = 0; packet_idx < PACKETS_PER_LINE; packet_idx = packet_idx + 1) begin
                wait_output_word(got_data, got_last);
                if (got_data !== expected_output_header(expected_line, packet_idx) || got_last !== 1'b0) begin
                    $display("ERROR: bad output header line=%0d packet=%0d got=%h last=%b expected=%h",
                             expected_line, packet_idx, got_data, got_last,
                             expected_output_header(expected_line, packet_idx));
                    tb_failed = 1'b1;
                end
                checked_header_count = checked_header_count + 1;

                for (word_idx = 0; word_idx < PAYLOADS_PER_PACKET; word_idx = word_idx + 1) begin
                    wait_output_word(got_data, got_last);
                    if (got_last !== (word_idx == (PAYLOADS_PER_PACKET - 1))) begin
                        $display("ERROR: bad tlast line=%0d packet=%0d payload=%0d got=%b",
                                 expected_line, packet_idx, word_idx, got_last);
                        tb_failed = 1'b1;
                    end
                    checked_payload_count = checked_payload_count + 1;
                    if (got_last) begin
                        checked_tlast_count = checked_tlast_count + 1;
                    end
                    if (compare_payload) begin
                        x_base = packet_idx * PIXELS_PER_PACKET + word_idx * PIXELS_PER_PAYLOAD;
                        if (got_data !== payload_word(expected_line, x_base)) begin
                            $display("ERROR: bad payload line=%0d packet=%0d payload=%0d got=%h expected=%h",
                                     expected_line, packet_idx, word_idx, got_data,
                                     payload_word(expected_line, x_base));
                            tb_failed = 1'b1;
                        end
                    end else begin
                        record_watermark_word(case_name, expected_line, packet_idx, word_idx, got_data);
                    end
                end
            end
        end
    endtask

    task wait_output_word;
        output [63:0] data;
        output        last;
        integer wait_cycles;
        begin
            wait_cycles = 0;
            while (tx_capture_rd >= tx_capture_wr) begin
                @(posedge srio_clk);
                wait_cycles = wait_cycles + 1;
                if (wait_cycles > 200000) begin
                    fail("timeout waiting for SRIO_T_axis handshake");
                    data = 64'h0;
                    last = 1'b0;
                    disable wait_output_word;
                end
            end
            // 新代码：Egor Izmaylov
            // 从握手捕获队列读取，保证检查器看到的 word 顺序与 AXIS 真实传输顺序一致。
            {last, data} = tx_capture_fifo[tx_capture_rd[15:0]];
            tx_capture_rd = tx_capture_rd + 1;
        end
    endtask

    task run_case;
        input [31:0] ctrl;
        input        compare_payload;
        input        enable_long_backpressure;
        input [255:0] case_name;
        integer input_lines;
        integer check_line;
        integer expected_headers;
        integer expected_payloads;
        integer expected_tlasts;
        integer effective_backpressure;
        begin
            effective_backpressure = enable_long_backpressure || (tb_backpressure_all != 0);
            $display("INFO: start case %0s ctrl=%h compare_payload=%0d backpressure=%0d random_ready=%0d seed=%h",
                     case_name, ctrl, compare_payload, effective_backpressure, tb_random_ready, tb_random_seed);
            reset_dut();
            checked_header_count = 0;
            checked_payload_count = 0;
            checked_tlast_count = 0;
            reset_watermark_stats();
            tx_ready_gate = !effective_backpressure;
            fork
                begin
                    input_lines = HALF_DEPTH + tb_lines;
                    send_srio_image_lines(input_lines);
                end
                begin
                    if (effective_backpressure) begin
                        wait (srio_t_axis_tvalid === 1'b1);
                        repeat (tb_backpressure_cycles) @(posedge srio_clk);
                        tx_ready_gate = 1'b1;
                    end
                    for (check_line = 0; check_line < tb_lines; check_line = check_line + 1) begin
                        check_one_output_line(case_name, check_line, compare_payload);
                    end
                end
            join
            analyze_watermark(case_name, compare_payload);
            if (tb_lines >= 2048) begin
                check_no_extra_output(case_name);
            end
            expected_headers = tb_lines * PACKETS_PER_LINE;
            expected_payloads = tb_lines * PACKETS_PER_LINE * PAYLOADS_PER_PACKET;
            expected_tlasts = tb_lines * PACKETS_PER_LINE;
            if ((checked_header_count != expected_headers) ||
                (checked_payload_count != expected_payloads) ||
                (checked_tlast_count != expected_tlasts)) begin
                $display("ERROR: frame count mismatch case=%0s headers=%0d/%0d payloads=%0d/%0d tlasts=%0d/%0d",
                         case_name,
                         checked_header_count, expected_headers,
                         checked_payload_count, expected_payloads,
                         checked_tlast_count, expected_tlasts);
                tb_failed = 1'b1;
            end
            $display("INFO: frame summary case=%0s lines=%0d headers=%0d payloads=%0d tlasts=%0d",
                     case_name, tb_lines, checked_header_count,
                     checked_payload_count, checked_tlast_count);
            $display("INFO: finish case %0s", case_name);
        end
    endtask

    always @(posedge srio_clk) begin
        if (srio_t_axis_tvalid) begin
            if (tx_video_tkeep !== 8'hFF) begin
                $display("ERROR: SRIO TX keep contract violation, keep=%h", tx_video_tkeep);
                tb_failed <= 1'b1;
            end
            if (^srio_t_axis_tuser === 1'bx) begin
                $display("ERROR: SRIO TX user contract violation, tuser contains X: %h", srio_t_axis_tuser);
                tb_failed <= 1'b1;
            end
            if (!srio_t_axis_tready) begin
                if (!holding_axis_word) begin
                    held_tdata <= srio_t_axis_tdata;
                    held_tlast <= srio_t_axis_tlast;
                    holding_axis_word <= 1'b1;
                end else if (held_tdata !== srio_t_axis_tdata || held_tlast !== srio_t_axis_tlast) begin
                    $display("ERROR: AXIS data changed while tvalid=1 and tready=0 old=%h/%b new=%h/%b",
                             held_tdata, held_tlast, srio_t_axis_tdata, srio_t_axis_tlast);
                    tb_failed <= 1'b1;
                end
            end else begin
                holding_axis_word <= 1'b0;
            end
        end else begin
            holding_axis_word <= 1'b0;
        end
    end

    initial begin
        tb_lines = 8;
        tb_backpressure_cycles = 4096;
        tb_global_timeout_cycles = 8000000;
        tb_packet_gap_cycles = 64;
        tb_backpressure_all = 0;
        tb_random_ready = 0;
        tb_drain_cycles = 512;
        tb_strict_drain = 0;
        tb_random_seed = 32'h1ace_b00c;
        if (!$value$plusargs("TB_LINES=%d", tb_lines)) begin
            tb_lines = 8;
        end
        if (!$value$plusargs("TB_BACKPRESSURE_CYCLES=%d", tb_backpressure_cycles)) begin
            tb_backpressure_cycles = 4096;
        end
        if (!$value$plusargs("TB_GLOBAL_TIMEOUT_CYCLES=%d", tb_global_timeout_cycles)) begin
            tb_global_timeout_cycles = 8000000;
        end
        if (!$value$plusargs("TB_PACKET_GAP_CYCLES=%d", tb_packet_gap_cycles)) begin
            tb_packet_gap_cycles = 64;
        end
        if (!$value$plusargs("TB_BACKPRESSURE_ALL=%d", tb_backpressure_all)) begin
            tb_backpressure_all = 0;
        end
        if (!$value$plusargs("TB_RANDOM_READY=%d", tb_random_ready)) begin
            tb_random_ready = 0;
        end
        if (!$value$plusargs("TB_DRAIN_CYCLES=%d", tb_drain_cycles)) begin
            tb_drain_cycles = 512;
        end
        if (!$value$plusargs("TB_STRICT_DRAIN=%d", tb_strict_drain)) begin
            tb_strict_drain = 0;
        end
        if (!$value$plusargs("TB_RANDOM_SEED=%h", tb_random_seed)) begin
            tb_random_seed = 32'h1ace_b00c;
        end
        if (tb_lines < 1) begin
            tb_lines = 1;
        end
        if (tb_lines > MAX_WATERMARK_LINES) begin
            $display("ERROR: TB_LINES=%0d exceeds MAX_WATERMARK_LINES=%0d", tb_lines, MAX_WATERMARK_LINES);
            tb_failed = 1'b1;
            $display("FAIL: tb_srio_video_e2e");
            $finish;
        end

        fork
            begin : p_global_watchdog
                repeat (tb_global_timeout_cycles) @(posedge srio_clk);
                $display("ERROR: global timeout in tb_srio_video_e2e after %0d srio_clk cycles", tb_global_timeout_cycles);
                tb_failed = 1'b1;
                $display("FAIL: tb_srio_video_e2e");
                $finish;
            end
        join_none

        $display("INFO: tb_srio_video_e2e TB_LINES=%0d TB_BACKPRESSURE_CYCLES=%0d TB_GLOBAL_TIMEOUT_CYCLES=%0d TB_PACKET_GAP_CYCLES=%0d TB_BACKPRESSURE_ALL=%0d TB_RANDOM_READY=%0d TB_DRAIN_CYCLES=%0d TB_STRICT_DRAIN=%0d TB_RANDOM_SEED=%h",
                 tb_lines, tb_backpressure_cycles, tb_global_timeout_cycles,
                 tb_packet_gap_cycles, tb_backpressure_all, tb_random_ready,
                 tb_drain_cycles, tb_strict_drain, tb_random_seed);

`ifdef ENABLE_FISHEYE_REMAP_READER
        // 新代码：Egor Izmaylov 算法构建不接旧运行时控制端口，默认固定启用 remap；此处只验证包协议和重复检测。
        run_case(32'h0000_0001, 1'b0, 1'b1, "remap_default");
`else
        // 新代码：Egor Izmaylov 未定义算法宏时，验证新工程原始读出链路逐字旁路正确。
        run_case(32'h0000_0000, 1'b1, 1'b1, "bypass");
`endif
        if (tb_failed) begin
            $display("FAIL: tb_srio_video_e2e");
            $finish;
        end

        $display("PASS: tb_srio_video_e2e");
        $finish;
    end
endmodule
