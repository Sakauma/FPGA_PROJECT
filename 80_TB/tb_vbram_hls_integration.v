`timescale 1ns / 1ps
// ============================================================================
// 新增维护说明
// 作者          : Egor Izmaylov
// 文件职责      : 当前文件为手工维护源码，具体职责见模块名、端口和上层实例化。
// 维护边界      : 只追加说明性注释；Vivado/IP 生成物和第三方支撑代码不在此处手改。
// 修改约束      : 功能改动需同步更新仿真、综合结果和相关文档。
// ============================================================================
////////////////////////////////////////////////////////////////////////////////////////////////////
// Company         : OpenAI
// Engineer        : Codex
// Create Date     : 2026/04/15
// Module Name     : tb_vbram_hls_integration
// Description     :
//     Lightweight RTL integration test for the vbram -> SRIO AXIS insertion point.
//     The test drives the real BRAM reader inside vbram_lutaxi4_to_axis and checks:
//       1. Header words pass through unchanged
//       2. Default build restores the old stable bypass output path
//       3. TLAST is preserved
//       4. Output data stays stable under backpressure
////////////////////////////////////////////////////////////////////////////////////////////////////

`ifndef USE_OLD_AXIS_POST_HLS_TB
module tb_vbram_hls_integration;

    localparam [63:0] EXPECTED_HEADER = 64'h00602000_00000000;
    localparam [63:0] EXPECTED_BYPASS_PAYLOAD = 64'h0003_0002_0001_0000;
`ifdef ENABLE_FISHEYE_REMAP_READER
    localparam        DEFAULT_REMAP_ENABLED = 1'b1;
`else
    localparam        DEFAULT_REMAP_ENABLED = 1'b0;
`endif

    reg             clk                     = 1'b0;
    // 新代码：Egor Izmaylov
    // RTL 集成仿真从复位态启动，确保异步 FIFO 的复位同步器和计数器不会停在 X 态。
    reg             rstn                    = 1'b0;
    /*
    // 新代码：Egor Izmaylov 初始为 1，再由 apply_reset 拉低，确保异步复位逻辑看到真实下降沿。
    reg             rstn                    = 1'b1;
    */
    reg     [31:0]  video_algo_ctrl         = 32'h0000_0000;
    // 新代码：Egor Izmaylov 与工程实际 200 行缓存保持一致，半深度位置为 100。
    reg     [18:0]  bram_line_cur_w         = 19'd100;
    reg             bram_line_cur_w_en      = 1'b0;
    reg     [15:0]  bram_doutb              = 16'd0;
    reg             m_srio_axis_tready      = 1'b1;

    wire    [8:0]   bram_line_num_addr;
    // 新代码：Egor Izmaylov
    // 本 TB 只验证第 0 行协议，行号 RAM 模型固定返回 0，避免 HLS 输出地址组合反馈造成 header 行号 X。
    // 旧代码保留：wire [11:0] bram_line_num = {4'd0, bram_line_num_addr[7:0]};
    wire    [11:0]  bram_line_num           = 12'd0;
    wire    [18:0]  bram_addrb;
    wire    [63:0]  m_srio_axis_tdata;
    wire            m_srio_axis_tvalid;
    wire            m_srio_axis_tlast;

    reg     [63:0]  captured_data [0:7];
    reg             captured_last [0:7];
    integer         captured_count          = 0;
    integer         error_count             = 0;
    // 新代码：Egor Izmaylov
    // 整行协议检查器：remap 读出链路必须复刻旧 readbram_to_axis64_top 的连续 packet 节奏。
    integer         stream_word_count       = 0;
    integer         stream_header_count     = 0;
    integer         stream_payload_count    = 0;
    integer         stream_tlast_count      = 0;
    integer         stream_error_count      = 0;
    integer         stream_phase            = 0;
    integer         stream_packet           = 0;
    reg             full_line_check_en      = 1'b0;
    reg     [63:0]  expected_stream_header  = 64'd0;

    always #5 clk = ~clk;

    function [15:0] mock_bram_pixel;
        input [18:0] addr;
        begin
            mock_bram_pixel = {addr[18:11], addr[7:0]};
        end
    endfunction

    always @(posedge clk) begin
        bram_doutb <= mock_bram_pixel(bram_addrb);
    end

`ifdef DEBUG_FISHEYE_TB
`ifdef ENABLE_FISHEYE_REMAP_READER
    always @(posedge clk) begin
        if (rstn && (bram_line_cur_w_en ||
                     dut.u_fisheye_remap_bram_to_axis.fifo_wr_en ||
                     (dut.u_fisheye_remap_bram_to_axis.u_fisheye_remap_reader_hls.state != 3'd0))) begin
            $display("DBG t=%0t rstn=%0b en=%0b hls_state=%0d hls_fsm=%h fifo_af=%0b wr=%0b fifo_empty=%0b wr_sync=%0b rd_sync=%0b wr_cnt=%0d rd_cnt=%0d valid=%0b data=%016h addr=%05h",
                     $time,
                     rstn,
                     bram_line_cur_w_en,
                     dut.u_fisheye_remap_bram_to_axis.u_fisheye_remap_reader_hls.state,
                     dut.u_fisheye_remap_bram_to_axis.u_fisheye_remap_reader_hls.ap_CS_fsm,
                     dut.u_fisheye_remap_bram_to_axis.fifo_almost_full,
                     dut.u_fisheye_remap_bram_to_axis.fifo_wr_en,
                     dut.u_fisheye_remap_bram_to_axis.fifo_empty,
                     dut.u_fisheye_remap_bram_to_axis.u_fisheye_axis_async_fifo.wr_sync_rstn,
                     dut.u_fisheye_remap_bram_to_axis.u_fisheye_axis_async_fifo.rd_sync_rstn,
                     dut.u_fisheye_remap_bram_to_axis.u_fisheye_axis_async_fifo.wr_data_count,
                     dut.u_fisheye_remap_bram_to_axis.u_fisheye_axis_async_fifo.rd_data_count,
                     m_srio_axis_tvalid,
                     m_srio_axis_tdata,
                     bram_addrb);
        end
    end
`endif
`endif

    vbram_lutaxi4_to_axis #(
        .B_RAM_WIDTH            ( 16        ),
        .B_RAM_DEPTH            ( 32'h80000 ),
        .P_LINE_DEPTH           ( 200       )
    ) dut (
        .clk                    ( clk               ),
        .rstn                   ( rstn              ),
        .video_algo_ctrl        ( video_algo_ctrl   ),

        .bram_line_cur_w        ( bram_line_cur_w   ),
        .bram_line_cur_w_en     ( bram_line_cur_w_en),
        .bram_line_num_addr     ( bram_line_num_addr),
        .bram_line_num          ( bram_line_num     ),
        .bram_addrb             ( bram_addrb        ),
        .bram_doutb             ( bram_doutb        ),

        .V_LUT_AXI_ARID         (                   ),
        .V_LUT_AXI_ARADDR       (                   ),
        .V_LUT_AXI_ARLEN        (                   ),
        .V_LUT_AXI_ARSIZE       (                   ),
        .V_LUT_AXI_ARBURST      (                   ),
        .V_LUT_AXI_ARLOCK       (                   ),
        .V_LUT_AXI_ARCACHE      (                   ),
        .V_LUT_AXI_ARPROT       (                   ),
        .V_LUT_AXI_ARQOS        (                   ),
        .V_LUT_AXI_ARVALID      (                   ),
        .V_LUT_AXI_ARREADY      ( 1'b0              ),
        .V_LUT_AXI_RID          ( 4'd0              ),
        .V_LUT_AXI_RDATA        ( 64'd0             ),
        .V_LUT_AXI_RRESP        ( 2'd0              ),
        .V_LUT_AXI_RLAST        ( 1'b0              ),
        .V_LUT_AXI_RVALID       ( 1'b0              ),
        .V_LUT_AXI_RREADY       (                   ),

        .m_srio_axis_aclk       ( clk               ),
        .m_srio_axis_rstn       ( rstn              ),
        .m_srio_axis_tdata      ( m_srio_axis_tdata ),
        .m_srio_axis_tready     ( m_srio_axis_tready),
        .m_srio_axis_tvalid     ( m_srio_axis_tvalid),
        .m_srio_axis_tlast      ( m_srio_axis_tlast )
    );

    always @(posedge clk) begin
        if (!rstn) begin
            captured_count <= 0;
        end else if (m_srio_axis_tvalid && m_srio_axis_tready) begin
            if (captured_count < 8) begin
                captured_data[captured_count] <= m_srio_axis_tdata;
                captured_last[captured_count] <= m_srio_axis_tlast;
                captured_count <= captured_count + 1;
            end
        end
    end

    always @(posedge clk) begin
        if (!rstn) begin
            stream_word_count    <= 0;
            stream_header_count  <= 0;
            stream_payload_count <= 0;
            stream_tlast_count   <= 0;
            stream_error_count   <= 0;
        end else if (full_line_check_en && m_srio_axis_tvalid && m_srio_axis_tready) begin
            stream_phase = stream_word_count % 33;
            stream_packet = stream_word_count / 33;

            if (stream_packet >= 16) begin
                $display("ERROR: stream emitted more than one line, word=%0d", stream_word_count);
                stream_error_count <= stream_error_count + 1;
            end

            if (stream_phase == 0) begin
                expected_stream_header = {32'h00602000, ((stream_packet & 32'h0000000f) << 8)};
                stream_header_count <= stream_header_count + 1;
                if (m_srio_axis_tdata !== expected_stream_header || m_srio_axis_tlast !== 1'b0) begin
                    $display("ERROR: packet header mismatch packet=%0d exp=%016h got=%016h last=%0d",
                             stream_packet, expected_stream_header, m_srio_axis_tdata, m_srio_axis_tlast);
                    stream_error_count <= stream_error_count + 1;
                end
            end else begin
                stream_payload_count <= stream_payload_count + 1;
                if (stream_phase == 32) begin
                    stream_tlast_count <= stream_tlast_count + 1;
                    if (m_srio_axis_tlast !== 1'b1) begin
                        $display("ERROR: final payload missing tlast packet=%0d", stream_packet);
                        stream_error_count <= stream_error_count + 1;
                    end
                end else if (m_srio_axis_tlast !== 1'b0) begin
                    $display("ERROR: tlast asserted before final payload packet=%0d phase=%0d",
                             stream_packet, stream_phase);
                    stream_error_count <= stream_error_count + 1;
                end
            end

            stream_word_count <= stream_word_count + 1;
        end
    end

    task automatic apply_reset;
        begin
            rstn = 1'b0;
            bram_line_cur_w_en = 1'b0;
            captured_count = 0;
            repeat (8) @(posedge clk);
            rstn = 1'b1;
            repeat (8) @(posedge clk);
        end
    endtask

    task automatic pulse_line_ready;
        begin
            @(negedge clk);
            bram_line_cur_w = 19'd100;
            bram_line_cur_w_en = 1'b1;
            @(negedge clk);
            bram_line_cur_w_en = 1'b0;
        end
    endtask

    task automatic wait_for_words;
        input integer expected_count;
        input integer timeout_cycles;
        integer idx;
        begin : wait_loop
            for (idx = 0; idx < timeout_cycles; idx = idx + 1) begin
                if (captured_count >= expected_count) begin
                    disable wait_loop;
                end
                @(posedge clk);
            end
            $display("ERROR: timeout waiting for %0d words, got %0d", expected_count, captured_count);
            error_count = error_count + 1;
        end
    endtask

    task automatic wait_for_full_line;
        input integer timeout_cycles;
        integer idx;
        begin : wait_line_loop
            for (idx = 0; idx < timeout_cycles; idx = idx + 1) begin
                if (stream_word_count >= 528) begin
                    disable wait_line_loop;
                end
                @(posedge clk);
            end
            if (stream_word_count < 528) begin
                $display("ERROR: timeout waiting full line, got %0d words", stream_word_count);
                error_count = error_count + 1;
            end
        end
    endtask

    task automatic inject_output_backpressure;
        integer stall_idx;
        reg [63:0] held_data;
        reg        held_last;
        begin
            repeat (24) @(posedge clk);
            @(negedge clk);
            m_srio_axis_tready = 1'b0;
            while (!m_srio_axis_tvalid) @(posedge clk);

            @(posedge clk);
            #1;
            if (!m_srio_axis_tvalid) begin
                $display("ERROR: output valid dropped at stall entry");
                error_count = error_count + 1;
            end
            held_data = m_srio_axis_tdata;
            held_last = m_srio_axis_tlast;

            for (stall_idx = 0; stall_idx < 3; stall_idx = stall_idx + 1) begin
                @(posedge clk);
                #1;
                if (!m_srio_axis_tvalid) begin
                    $display("ERROR: output valid dropped during backpressure");
                    error_count = error_count + 1;
                end
                if (m_srio_axis_tdata !== held_data || m_srio_axis_tlast !== held_last) begin
                    $display("ERROR: output data changed during backpressure");
                    error_count = error_count + 1;
                end
            end

            @(negedge clk);
            m_srio_axis_tready = 1'b1;
        end
    endtask

    task automatic run_full_line_case;
        input [31:0] ctrl;
        input integer enable_stall;
        begin
            $display("INFO: running full-line ctrl=0x%08x", ctrl);
            video_algo_ctrl = ctrl;
            apply_reset();
            m_srio_axis_tready = 1'b1;
            stream_word_count = 0;
            stream_header_count = 0;
            stream_payload_count = 0;
            stream_tlast_count = 0;
            stream_error_count = 0;
            full_line_check_en = 1'b1;

            if (enable_stall != 0) begin
                fork
                    inject_output_backpressure();
                join_none
            end

            pulse_line_ready();
            wait_for_full_line(20000);
            repeat (8) @(posedge clk);
            full_line_check_en = 1'b0;

            if (stream_header_count != 16 ||
                stream_payload_count != 512 ||
                stream_tlast_count != 16 ||
                stream_error_count != 0) begin
                $display("ERROR: full-line protocol count mismatch headers=%0d payloads=%0d tlasts=%0d stream_errors=%0d",
                         stream_header_count, stream_payload_count, stream_tlast_count, stream_error_count);
                error_count = error_count + 1;
            end
        end
    endtask

    task automatic run_case;
        input [31:0] ctrl;
        input        expect_bypass;
        begin
            $display("INFO: running ctrl=0x%08x", ctrl);
            video_algo_ctrl = ctrl;
            apply_reset();
            pulse_line_ready();
            wait_for_words(2, 2000);

            if (captured_data[0] !== EXPECTED_HEADER || captured_last[0] !== 1'b0) begin
                $display("ERROR: header mismatch ctrl=0x%08x data=%016h last=%0d",
                         ctrl, captured_data[0], captured_last[0]);
                error_count = error_count + 1;
            end

            if (expect_bypass && !DEFAULT_REMAP_ENABLED) begin
                if (captured_data[1] !== EXPECTED_BYPASS_PAYLOAD) begin
                    $display("ERROR: bypass payload mismatch exp=%016h got=%016h",
                             EXPECTED_BYPASS_PAYLOAD, captured_data[1]);
                    error_count = error_count + 1;
                end
            end else if (!expect_bypass) begin
                if (captured_data[1] === EXPECTED_BYPASS_PAYLOAD) begin
                    $display("ERROR: remap payload did not change from bypass");
                    error_count = error_count + 1;
                end
            end

            if (captured_last[1] !== 1'b0) begin
                $display("ERROR: first payload must not assert tlast");
                error_count = error_count + 1;
            end
        end
    endtask

    initial begin
        // 新代码：Egor Izmaylov
        // 给 async_fifo 的低有效异步复位制造明确下降沿，避免 XSim 中复位同步链保持 X。
        rstn = 1'b1;
        #1 rstn = 1'b0;
        repeat (3) @(posedge clk);

        // 新代码：Egor Izmaylov
        // 先覆盖整行连续 packet 协议，再运行原有首包冒烟用例。
        run_full_line_case(32'h0000_0000, 1);
        run_full_line_case(32'h0000_0001, 0);

        run_case(32'h0000_0000, 1'b1);
        // 新代码：Egor Izmaylov 默认不定义 ENABLE_FISHEYE_REMAP_READER 时，所有控制值都应走旧稳定直通路径。
        run_case(32'h0000_0001, ~DEFAULT_REMAP_ENABLED);
        run_case(32'h0000_0007, ~DEFAULT_REMAP_ENABLED);
        // 新代码：Egor Izmaylov 覆盖自适应预处理控制位，确认 bit4/bit5 不破坏默认稳定输出。
        run_case(32'h0000_0011, ~DEFAULT_REMAP_ENABLED);
        run_case(32'h0000_0021, ~DEFAULT_REMAP_ENABLED);

        repeat (10) @(posedge clk);

        if (error_count == 0) begin
            $display("PASS: tb_vbram_hls_integration");
        end else begin
            $display("FAIL: tb_vbram_hls_integration error_count=%0d", error_count);
        end

        $finish;
    end

endmodule
`else
module tb_vbram_hls_integration;

    localparam [63:0] HDR0 = 64'h00602000_00000000;
    localparam [63:0] HDR1 = 64'h00602000_00001000;
    localparam [63:0] PAY0 = 64'h0004_0003_0002_0001;
    localparam [63:0] PAY1 = 64'h0008_0007_0006_0005;
    localparam [63:0] PAY2 = 64'h000C_000B_000A_0009;

    reg             clk                     = 1'b0;
    reg             rstn                    = 1'b0;
    reg     [31:0]  video_algo_ctrl         = 32'h0000_0000;
    reg             m_srio_axis_tready      = 1'b0;

    reg     [63:0]  force_raw_data          = 64'd0;
    reg             force_raw_valid         = 1'b0;
    reg             force_raw_last          = 1'b0;

    wire    [63:0]  m_srio_axis_tdata;
    wire            m_srio_axis_tvalid;
    wire            m_srio_axis_tlast;

    reg     [63:0]  captured_data [0:5];
    reg             captured_last [0:5];
    integer         captured_count          = 0;
    integer         error_count             = 0;

    reg     [63:0]  expected_data [0:5];
    reg             expected_last [0:5];

    reg             stall_done              = 1'b0;

    always #5 clk = ~clk;

    vbram_lutaxi4_to_axis dut (
        .clk                    ( clk               ),
        .rstn                   ( rstn              ),
        .video_algo_ctrl        ( video_algo_ctrl   ),

        .bram_line_cur_w        ( 'd0               ),
        .bram_line_cur_w_en     ( 1'b0              ),
        .bram_line_num_addr     (                   ),
        .bram_line_num          ( 12'd0             ),
        .bram_addrb             (                   ),
        .bram_doutb             ( 16'd0             ),

        .V_LUT_AXI_ARID         (                   ),
        .V_LUT_AXI_ARADDR       (                   ),
        .V_LUT_AXI_ARLEN        (                   ),
        .V_LUT_AXI_ARSIZE       (                   ),
        .V_LUT_AXI_ARBURST      (                   ),
        .V_LUT_AXI_ARLOCK       (                   ),
        .V_LUT_AXI_ARCACHE      (                   ),
        .V_LUT_AXI_ARPROT       (                   ),
        .V_LUT_AXI_ARQOS        (                   ),
        .V_LUT_AXI_ARVALID      (                   ),
        .V_LUT_AXI_ARREADY      ( 1'b0              ),
        .V_LUT_AXI_RID          ( 4'd0              ),
        .V_LUT_AXI_RDATA        ( 64'd0             ),
        .V_LUT_AXI_RRESP        ( 2'd0              ),
        .V_LUT_AXI_RLAST        ( 1'b0              ),
        .V_LUT_AXI_RVALID       ( 1'b0              ),
        .V_LUT_AXI_RREADY       (                   ),

        .m_srio_axis_aclk       ( clk               ),
        .m_srio_axis_rstn       ( rstn              ),
        .m_srio_axis_tdata      ( m_srio_axis_tdata ),
        .m_srio_axis_tready     ( m_srio_axis_tready),
        .m_srio_axis_tvalid     ( m_srio_axis_tvalid),
        .m_srio_axis_tlast      ( m_srio_axis_tlast )
    );

    initial begin
        force dut.raw_srio_axis_tdata = force_raw_data;
        force dut.raw_srio_axis_tvalid = force_raw_valid;
        force dut.raw_srio_axis_tlast = force_raw_last;
    end

    always @(posedge clk) begin
        if (!rstn) begin
            captured_count <= 0;
        end else if (m_srio_axis_tvalid && m_srio_axis_tready) begin
            if (captured_count < 6) begin
                captured_data[captured_count] <= m_srio_axis_tdata;
                captured_last[captured_count] <= m_srio_axis_tlast;
                captured_count <= captured_count + 1;
            end else begin
                $display("ERROR: captured more than 6 words");
                error_count <= error_count + 1;
            end
        end
    end

    task automatic set_expected_case;
        input [31:0] ctrl;
        begin
            expected_data[0] = HDR0;
            expected_last[0] = 1'b0;
            expected_data[2] = HDR1;
            expected_last[2] = 1'b0;
            expected_data[4] = HDR0;
            expected_last[4] = 1'b0;

            case (ctrl)
                32'h0000_0000: begin
                    expected_data[1] = PAY0;
                    expected_last[1] = 1'b1;
                    expected_data[3] = PAY1;
                    expected_last[3] = 1'b1;
                    expected_data[5] = PAY2;
                    expected_last[5] = 1'b1;
                end
                32'h0000_0001: begin
                    expected_data[1] = 64'h0013_0012_0011_0011;
                    expected_last[1] = 1'b1;
                    expected_data[3] = 64'h0017_0016_0015_0014;
                    expected_last[3] = 1'b1;
                    expected_data[5] = 64'h001B_001A_0019_0019;
                    expected_last[5] = 1'b1;
                end
                32'h0000_0003: begin
                    expected_data[1] = 64'h0000_0000_0000_0000;
                    expected_last[1] = 1'b1;
                    expected_data[3] = 64'h0000_0000_0000_0000;
                    expected_last[3] = 1'b1;
                    expected_data[5] = 64'h0000_0000_0000_0000;
                    expected_last[5] = 1'b1;
                end
                32'h0000_0007: begin
                    expected_data[1] = 64'h0000_0000_0000_0000;
                    expected_last[1] = 1'b1;
                    expected_data[3] = 64'h0000_0000_0000_0000;
                    expected_last[3] = 1'b1;
                    expected_data[5] = 64'h001B_001A_0019_0019;
                    expected_last[5] = 1'b1;
                end
                default: begin
                    expected_data[1] = 64'hDEAD_DEAD_DEAD_DEAD;
                    expected_last[1] = 1'b0;
                    expected_data[3] = 64'hDEAD_DEAD_DEAD_DEAD;
                    expected_last[3] = 1'b0;
                    expected_data[5] = 64'hDEAD_DEAD_DEAD_DEAD;
                    expected_last[5] = 1'b0;
                end
            endcase
        end
    endtask

    task automatic apply_reset;
        begin
            rstn = 1'b0;
            m_srio_axis_tready = 1'b0;
            force_raw_data = 64'd0;
            force_raw_valid = 1'b0;
            force_raw_last = 1'b0;
            stall_done = 1'b0;

            repeat (5) @(posedge clk);

            rstn = 1'b1;
            m_srio_axis_tready = 1'b1;

            repeat (4) @(posedge clk);
        end
    endtask

    task automatic send_word;
        input [63:0] data_word;
        input        last_word;
        begin : wait_accept
            @(negedge clk);
            force_raw_data = data_word;
            force_raw_last = last_word;
            force_raw_valid = 1'b1;

            while (1) begin
                @(posedge clk);
                if (dut.raw_srio_axis_tready) begin
                    disable wait_accept;
                end
            end
        end
        @(negedge clk);
        force_raw_data = 64'd0;
        force_raw_last = 1'b0;
        force_raw_valid = 1'b0;
    endtask

    task automatic wait_for_capture_count;
        input integer expected_count;
        input integer timeout_cycles;
        integer cycle_idx;
        begin : wait_done
            for (cycle_idx = 0; cycle_idx < timeout_cycles; cycle_idx = cycle_idx + 1) begin
                if (captured_count >= expected_count) begin
                    disable wait_done;
                end
                @(posedge clk);
            end

            $display("ERROR: timeout waiting for %0d captured words, got %0d", expected_count, captured_count);
            error_count = error_count + 1;
        end
    endtask

    task automatic check_captured_case;
        input [31:0] ctrl;
        integer word_idx;
        begin
            set_expected_case(ctrl);

            for (word_idx = 0; word_idx < 6; word_idx = word_idx + 1) begin
                if (captured_data[word_idx] !== expected_data[word_idx]) begin
                    $display("ERROR: ctrl=0x%08x word%0d data mismatch exp=%016h got=%016h",
                             ctrl, word_idx, expected_data[word_idx], captured_data[word_idx]);
                    error_count = error_count + 1;
                end

                if (captured_last[word_idx] !== expected_last[word_idx]) begin
                    $display("ERROR: ctrl=0x%08x word%0d last mismatch exp=%0d got=%0d",
                             ctrl, word_idx, expected_last[word_idx], captured_last[word_idx]);
                    error_count = error_count + 1;
                end
            end
        end
    endtask

    task automatic inject_output_backpressure;
        integer stall_idx;
        reg [63:0] held_data;
        reg        held_last;
        begin
            while (captured_count < 1) @(posedge clk);
            while (!m_srio_axis_tvalid) @(posedge clk);

            @(negedge clk);
            m_srio_axis_tready = 1'b0;

            @(posedge clk);
            #1;
            if (!m_srio_axis_tvalid) begin
                $display("ERROR: output valid dropped at stall entry");
                error_count = error_count + 1;
            end
            held_data = m_srio_axis_tdata;
            held_last = m_srio_axis_tlast;

            for (stall_idx = 0; stall_idx < 2; stall_idx = stall_idx + 1) begin
                @(posedge clk);
                #1;
                if (!m_srio_axis_tvalid) begin
                    $display("ERROR: output valid dropped during backpressure");
                    error_count = error_count + 1;
                end
                if (m_srio_axis_tdata !== held_data || m_srio_axis_tlast !== held_last) begin
                    $display("ERROR: output data changed during backpressure");
                    error_count = error_count + 1;
                end
            end

            @(negedge clk);
            m_srio_axis_tready = 1'b1;
            stall_done = 1'b1;
        end
    endtask

    task automatic run_case;
        input [31:0] ctrl;
        input integer enable_stall;
        begin
            $display("INFO: running ctrl=0x%08x", ctrl);
            video_algo_ctrl = ctrl;
            apply_reset();

            if (enable_stall != 0) begin
                fork
                    inject_output_backpressure();
                join_none
            end

            send_word(HDR0, 1'b0);
            send_word(PAY0, 1'b1);
            send_word(HDR1, 1'b0);
            send_word(PAY1, 1'b1);
            send_word(HDR0, 1'b0);
            send_word(PAY2, 1'b1);

            wait_for_capture_count(6, 400);
            repeat (6) @(posedge clk);

            if (enable_stall != 0 && !stall_done) begin
                $display("ERROR: planned backpressure sequence did not complete");
                error_count = error_count + 1;
            end

            check_captured_case(ctrl);
            $display("INFO: ctrl=0x%08x complete", ctrl);
        end
    endtask

    initial begin
        repeat (3) @(posedge clk);

        run_case(32'h0000_0000, 1);
        run_case(32'h0000_0001, 0);
        run_case(32'h0000_0003, 0);
        run_case(32'h0000_0007, 0);

        repeat (10) @(posedge clk);

        if (error_count == 0) begin
            $display("PASS: tb_vbram_hls_integration");
        end else begin
            $display("FAIL: tb_vbram_hls_integration error_count=%0d", error_count);
        end

        $finish;
    end

endmodule
`endif
