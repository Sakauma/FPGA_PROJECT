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
//     Lightweight RTL integration test for the vbram -> HLS wrapper insertion point.
//     The test drives the real raw stream inside vbram_lutaxi4_to_axis and checks:
//       1. Header words pass through unchanged
//       2. Payload words match the four validated control modes
//       3. TLAST is preserved
//       4. Output data stays stable under backpressure
////////////////////////////////////////////////////////////////////////////////////////////////////

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
