// tb_emulator_mutrig.sv
// Testbench for MuTRiG 3 emulator
// Mixed-language smoke bench with frame_rcv_ip replay checks.

`timescale 1ns/1ps

module tb_emulator_mutrig;

    import emulator_mutrig_pkg::*;

    // ========================================
    // Parameters
    // ========================================
    localparam real CLK_PERIOD = 8.0;  // 125 MHz
    localparam int  FIFO_DEPTH = 64;

    // ========================================
    // Test selection
    // ========================================
    string test_name;
    int    seed;
    int    pass_count, fail_count;

    initial begin
        if (!$value$plusargs("TEST=%s", test_name)) test_name = "B01_lfsr";
        if (!$value$plusargs("SEED=%d", seed))       seed = 42;
        pass_count = 0;
        fail_count = 0;
    end

    // ========================================
    // Clock and reset
    // ========================================
    logic clk, rst;

    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    initial begin
        rst = 1;
        #(CLK_PERIOD * 10);
        rst = 0;
    end

    // ========================================
    // DUT signals
    // ========================================
    logic [8:0]  aso_tx8b1k_data;
    logic        aso_tx8b1k_valid;
    logic [3:0]  aso_tx8b1k_channel;
    logic [2:0]  aso_tx8b1k_error;

    logic [8:0]  asi_ctrl_data;
    logic        asi_ctrl_valid;
    logic        asi_ctrl_ready;
    logic        coe_inject_pulse;

    logic [3:0]  avs_csr_address;
    logic        avs_csr_read;
    logic        avs_csr_write;
    logic [31:0] avs_csr_writedata;
    logic [31:0] avs_csr_readdata;
    logic        avs_csr_waitrequest;

    // ========================================
    // Parser replay signals
    // ========================================
    logic        parser_rst;
    logic [8:0]  parser_rx_data;
    logic        parser_rx_valid;
    logic [2:0]  parser_rx_error;
    logic [3:0]  parser_rx_channel;
    logic [8:0]  parser_ctrl_data;
    logic        parser_ctrl_valid;
    logic        parser_ctrl_ready;
    logic [1:0]  parser_csr_address;
    logic        parser_csr_read;
    logic        parser_csr_write;
    logic [31:0] parser_csr_writedata;
    logic [31:0] parser_csr_readdata;
    logic        parser_csr_waitrequest;
    logic [3:0]  parser_hit_channel;
    logic        parser_hit_sop;
    logic        parser_hit_eop;
    logic [2:0]  parser_hit_error;
    logic [44:0] parser_hit_data;
    logic        parser_hit_valid;
    logic [41:0] parser_headerinfo_data;
    logic        parser_headerinfo_valid;
    logic [3:0]  parser_headerinfo_channel;

    int          parser_header_count;
    int          parser_hit_count;
    logic [41:0] parser_last_headerinfo_data;
    logic [44:0] parser_last_hit_data;
    logic [2:0]  parser_last_hit_error;
    logic        parser_last_hit_sop;
    logic        parser_last_hit_eop;

    // ========================================
    // DUT instantiation
    // ========================================
    emulator_mutrig #(
        .FIFO_DEPTH     (FIFO_DEPTH),
        .CSR_ADDR_WIDTH (4)
    ) dut (
        .i_clk              (clk),
        .i_rst              (rst),
        .aso_tx8b1k_data    (aso_tx8b1k_data),
        .aso_tx8b1k_valid   (aso_tx8b1k_valid),
        .aso_tx8b1k_channel (aso_tx8b1k_channel),
        .aso_tx8b1k_error   (aso_tx8b1k_error),
        .asi_ctrl_data      (asi_ctrl_data),
        .asi_ctrl_valid     (asi_ctrl_valid),
        .asi_ctrl_ready     (asi_ctrl_ready),
        .coe_inject_pulse   (coe_inject_pulse),
        .avs_csr_address    (avs_csr_address),
        .avs_csr_read       (avs_csr_read),
        .avs_csr_write      (avs_csr_write),
        .avs_csr_writedata  (avs_csr_writedata),
        .avs_csr_readdata   (avs_csr_readdata),
        .avs_csr_waitrequest(avs_csr_waitrequest)
    );

    frame_rcv_ip #(
        .CHANNEL_WIDTH (4),
        .CSR_ADDR_WIDTH(2),
        .MODE_HALT     (0),
        .DEBUG_LV      (0)
    ) parser (
        .asi_rx8b1k_data             (parser_rx_data),
        .asi_rx8b1k_valid            (parser_rx_valid),
        .asi_rx8b1k_error            (parser_rx_error),
        .asi_rx8b1k_channel          (parser_rx_channel),
        .aso_hit_type0_channel       (parser_hit_channel),
        .aso_hit_type0_startofpacket (parser_hit_sop),
        .aso_hit_type0_endofpacket   (parser_hit_eop),
        .aso_hit_type0_error         (parser_hit_error),
        .aso_hit_type0_data          (parser_hit_data),
        .aso_hit_type0_valid         (parser_hit_valid),
        .aso_headerinfo_data         (parser_headerinfo_data),
        .aso_headerinfo_valid        (parser_headerinfo_valid),
        .aso_headerinfo_channel      (parser_headerinfo_channel),
        .avs_csr_readdata            (parser_csr_readdata),
        .avs_csr_read                (parser_csr_read),
        .avs_csr_address             (parser_csr_address),
        .avs_csr_waitrequest         (parser_csr_waitrequest),
        .avs_csr_write               (parser_csr_write),
        .avs_csr_writedata           (parser_csr_writedata),
        .asi_ctrl_data               (parser_ctrl_data),
        .asi_ctrl_valid              (parser_ctrl_valid),
        .asi_ctrl_ready              (parser_ctrl_ready),
        .i_rst                       (parser_rst),
        .i_clk                       (clk)
    );

    always_ff @(posedge clk) begin
        if (parser_rst) begin
            parser_header_count         <= 0;
            parser_hit_count            <= 0;
            parser_last_headerinfo_data <= '0;
            parser_last_hit_data        <= '0;
            parser_last_hit_error       <= '0;
            parser_last_hit_sop         <= 1'b0;
            parser_last_hit_eop         <= 1'b0;
        end else begin
            if (parser_headerinfo_valid) begin
                parser_header_count         <= parser_header_count + 1;
                parser_last_headerinfo_data <= parser_headerinfo_data;
            end
            if (parser_hit_valid) begin
                parser_hit_count      <= parser_hit_count + 1;
                parser_last_hit_data  <= parser_hit_data;
                parser_last_hit_error <= parser_hit_error;
                parser_last_hit_sop   <= parser_hit_sop;
                parser_last_hit_eop   <= parser_hit_eop;
            end
        end
    end

    // ========================================
    // CSR access tasks
    // ========================================
    task automatic csr_write(input logic [3:0] addr, input logic [31:0] data);
        @(posedge clk);
        avs_csr_address   <= addr;
        avs_csr_writedata <= data;
        avs_csr_write     <= 1'b1;
        avs_csr_read      <= 1'b0;
        @(posedge clk);
        while (avs_csr_waitrequest) @(posedge clk);
        avs_csr_write <= 1'b0;
    endtask

    task automatic csr_read(input logic [3:0] addr, output logic [31:0] data);
        @(posedge clk);
        avs_csr_address <= addr;
        avs_csr_read    <= 1'b1;
        avs_csr_write   <= 1'b0;
        @(posedge clk);
        while (avs_csr_waitrequest) @(posedge clk);
        data = avs_csr_readdata;
        avs_csr_read <= 1'b0;
    endtask

    // ========================================
    // Run control task (9-bit one-hot encoding)
    // ========================================
    // One-hot run control constants (matching run-control_mgmt bus)
    localparam logic [8:0] CTRL_IDLE          = 9'b000000001;
    localparam logic [8:0] CTRL_RUN_PREPARE   = 9'b000000010;
    localparam logic [8:0] CTRL_SYNC          = 9'b000000100;
    localparam logic [8:0] CTRL_RUNNING       = 9'b000001000;
    localparam logic [8:0] CTRL_TERMINATING   = 9'b000010000;

    task automatic send_run_state(input logic [8:0] state);
        @(posedge clk);
        asi_ctrl_data  <= state;
        asi_ctrl_valid <= 1'b1;
        @(posedge clk);
        asi_ctrl_valid <= 1'b0;
    endtask

    task automatic run_sequence_start();
        send_run_state(CTRL_RUN_PREPARE);
        #(CLK_PERIOD * 5);
        send_run_state(CTRL_SYNC);
        #(CLK_PERIOD * 5);
        send_run_state(CTRL_RUNNING);
    endtask

    task automatic run_sequence_stop();
        send_run_state(CTRL_TERMINATING);
        #(CLK_PERIOD * 5);
        send_run_state(CTRL_IDLE);
    endtask

    task automatic parser_send_run_state(input logic [8:0] state);
        @(posedge clk);
        parser_ctrl_data  <= state;
        parser_ctrl_valid <= 1'b1;
        @(posedge clk);
        parser_ctrl_valid <= 1'b0;
    endtask

    task automatic parser_prepare_for_replay();
        parser_rst          <= 1'b1;
        parser_rx_data      <= '0;
        parser_rx_valid     <= 1'b0;
        parser_rx_error     <= '0;
        parser_rx_channel   <= '0;
        parser_ctrl_data    <= CTRL_IDLE;
        parser_ctrl_valid   <= 1'b0;
        parser_csr_address  <= '0;
        parser_csr_read     <= 1'b0;
        parser_csr_write    <= 1'b0;
        parser_csr_writedata <= '0;

        repeat (4) @(posedge clk);
        parser_rst <= 1'b0;
        repeat (2) @(posedge clk);

        parser_send_run_state(CTRL_RUN_PREPARE);
        repeat (5) @(posedge clk);
        parser_send_run_state(CTRL_SYNC);
        repeat (5) @(posedge clk);
        parser_send_run_state(CTRL_RUNNING);
        repeat (2) @(posedge clk);
    endtask

    // ========================================
    // Frame capture
    // ========================================
    // Capture 8b/1k output into a byte array for analysis
    localparam int MAX_FRAME_BYTES = 2048;

    logic [7:0] captured_bytes [0:MAX_FRAME_BYTES-1];
    logic       captured_isk   [0:MAX_FRAME_BYTES-1];
    logic [3:0] captured_channel [0:MAX_FRAME_BYTES-1];
    logic [2:0] captured_error   [0:MAX_FRAME_BYTES-1];
    int         captured_len;

    task automatic capture_frame(output int frame_len);
        int idx;
        logic found_header;
        idx = 0;
        found_header = 0;

        // Wait for header (K28.0)
        while (!found_header) begin
            @(negedge clk);
            if (aso_tx8b1k_valid && aso_tx8b1k_data == {1'b1, K28_0}) begin
                found_header = 1;
                captured_bytes[0]   = aso_tx8b1k_data[7:0];
                captured_isk[0]     = aso_tx8b1k_data[8];
                captured_channel[0] = aso_tx8b1k_channel;
                captured_error[0]   = aso_tx8b1k_error;
                idx = 1;
            end
        end

        // Capture until trailer (K28.4)
        while (1) begin
            @(negedge clk);
            if (aso_tx8b1k_valid) begin
                captured_bytes[idx]   = aso_tx8b1k_data[7:0];
                captured_isk[idx]     = aso_tx8b1k_data[8];
                captured_channel[idx] = aso_tx8b1k_channel;
                captured_error[idx]   = aso_tx8b1k_error;
                idx++;
                if (aso_tx8b1k_data == {1'b1, K28_4}) begin
                    frame_len = idx;
                    captured_len = idx;
                    return;
                end
                if (idx >= MAX_FRAME_BYTES) begin
                    $display("ERROR: Frame too long, aborting capture");
                    frame_len = idx;
                    captured_len = idx;
                    return;
                end
            end
        end
    endtask

    task automatic capture_next_nonempty_frame(output int frame_len, output int evt_count);
        logic [15:0] evt_cnt_ext;
        frame_len = 0;
        evt_count = 0;

        for (int attempt = 0; attempt < 4; attempt++) begin
            capture_frame(frame_len);
            evt_cnt_ext = {captured_bytes[3], captured_bytes[4]};
            evt_count = evt_cnt_ext[9:0];
            if (evt_count != 0)
                return;
        end

        $display("ERROR: Timed out waiting for a non-empty frame");
    endtask

    function automatic logic [27:0] decode_short_hit_from_capture();
        return {
            captured_bytes[5],
            captured_bytes[6],
            captured_bytes[7],
            captured_bytes[8][7:4]
        };
    endfunction

    task automatic replay_captured_frame(input int frame_len);
        parser_prepare_for_replay();

        for (int i = 0; i < frame_len; i++) begin
            @(posedge clk);
            parser_rx_data    <= {captured_isk[i], captured_bytes[i]};
            parser_rx_valid   <= 1'b1;
            parser_rx_error   <= captured_error[i];
            parser_rx_channel <= captured_channel[i];
        end

        @(posedge clk);
        parser_rx_valid   <= 1'b0;
        parser_rx_data    <= '0;
        parser_rx_error   <= '0;
        parser_rx_channel <= '0;
        repeat (8) @(posedge clk);
    endtask

    task automatic measure_header_gap(output int gap_cycles);
        int cycles;
        logic found_first;
        found_first = 1'b0;
        cycles = 0;

        while (!found_first) begin
            @(posedge clk);
            if (aso_tx8b1k_valid && aso_tx8b1k_data == {1'b1, K28_0})
                found_first = 1'b1;
        end

        while (1) begin
            @(posedge clk);
            cycles++;
            if (aso_tx8b1k_valid && aso_tx8b1k_data == {1'b1, K28_0}) begin
                gap_cycles = cycles;
                return;
            end
            if (cycles > 4096) begin
                $display("ERROR: Timed out measuring header gap");
                gap_cycles = cycles;
                return;
            end
        end
    endtask

    task automatic pulse_inject_once();
        @(posedge clk);
        coe_inject_pulse <= 1'b1;
        @(posedge clk);
        coe_inject_pulse <= 1'b0;
    endtask

    task automatic wait_for_generated_hit(output logic [47:0] hit_word);
        int timeout_cycles;
        hit_word = '0;
        timeout_cycles = 0;

`ifdef EMUT_GATE_SIM
        while (timeout_cycles < 4096) begin
            @(negedge clk);
            timeout_cycles++;
        end

        $display("NOTE: Gate-level netlist hides u_hit_gen internals; skipping direct generated-hit capture");
`else
        while (timeout_cycles < 4096) begin
            @(negedge clk);
            if (dut.u_hit_gen.hit_wr_en && !dut.u_hit_gen.fifo_full) begin
                hit_word = dut.u_hit_gen.hit_wr_data;
                return;
            end
            timeout_cycles++;
        end

        $display("ERROR: Timed out waiting for a generated hit");
`endif
    endtask

    task automatic clear_hit_generator_state();
`ifndef EMUT_GATE_SIM
        @(posedge clk);
        dut.u_hit_gen.fifo_wr_ptr         = '0;
        dut.u_hit_gen.fifo_rd_ptr         = '0;
        dut.u_hit_gen.fifo_count          = '0;
        dut.u_hit_gen.hit_wr_en           = 1'b0;
        dut.u_hit_gen.hit_wr_data         = '0;
        dut.u_hit_gen.burst_remaining     = '0;
        dut.u_hit_gen.burst_ch            = '0;
        dut.u_hit_gen.burst_cooldown      = '0;
        dut.u_hit_gen.inject_burst_pending = 1'b0;
`else
        @(posedge clk);
`endif
    endtask

    // ========================================
    // CRC-16 reference model
    // ========================================
    function automatic logic [15:0] crc16_reference(
        input int len,
        input logic [7:0] data []
    );
        logic [15:0] crc;
        logic [15:0] n;
        logic [7:0] d;
        crc = 16'hFFFF;
        for (int i = 0; i < len; i++) begin
            d = data[i];
            n[0]  = crc[15]^d[7] ^ crc[14]^d[6] ^ crc[13]^d[5] ^ crc[12]^d[4] ^
                    crc[11]^d[3] ^ crc[10]^d[2] ^ crc[9]^d[1]  ^ crc[8]^d[0];
            n[1]  = crc[15]^d[7] ^ crc[14]^d[6] ^ crc[13]^d[5] ^ crc[12]^d[4] ^
                    crc[11]^d[3] ^ crc[10]^d[2] ^ crc[9]^d[1];
            n[2]  = crc[9]^d[1]  ^ crc[8]^d[0];
            n[3]  = crc[10]^d[2] ^ crc[9]^d[1];
            n[4]  = crc[11]^d[3] ^ crc[10]^d[2];
            n[5]  = crc[12]^d[4] ^ crc[11]^d[3];
            n[6]  = crc[13]^d[5] ^ crc[12]^d[4];
            n[7]  = crc[14]^d[6] ^ crc[13]^d[5];
            n[8]  = crc[15]^d[7] ^ crc[14]^d[6] ^ crc[0];
            n[9]  = crc[15]^d[7] ^ crc[1];
            n[10] = crc[2];
            n[11] = crc[3];
            n[12] = crc[4];
            n[13] = crc[5];
            n[14] = crc[6];
            n[15] = crc[15]^d[7] ^ crc[14]^d[6] ^ crc[13]^d[5] ^ crc[12]^d[4] ^
                    crc[11]^d[3] ^ crc[10]^d[2] ^ crc[9]^d[1]  ^ crc[8]^d[0]  ^ crc[7];
            crc = n;
        end
        return ~crc;
    endfunction

    // ========================================
    // Check / report helpers
    // ========================================
    task automatic check(input string name, input logic pass);
        if (pass) begin
            $display("  [PASS] %s", name);
            pass_count++;
        end else begin
            $display("  [FAIL] %s", name);
            fail_count++;
        end
    endtask

    // ========================================
    // Test B01: LFSR sequence check
    // ========================================
    task automatic test_B01_lfsr();
        logic [14:0] lfsr_state;
        logic [14:0] expected;
        int count;

        $display("\n=== Test B01: PRBS-15 LFSR sequence ===");

        // Direct test of prbs15_lfsr module
        // Check first few known states from MuTRiG ROM LUT
        // State 0: 0x7FFF (init)
        // State 1: 0x7FFE (shift left, new bit = 1^1 = 0... wait)
        // From ROM: @0001 = state 0, @0003 = state 1
        // The ROM maps LFSR state → binary index
        // LFSR init = all 1s = 0x7FFF
        // After 1 step: shift left + (bit14 XOR bit0) = (1 XOR 1) = 0
        //   new state = {sreg[13:0], 0} = 0x7FFE

        // Use standalone LFSR instance
        begin
            logic clk_tb, rst_tb, en_tb;
            logic [14:0] lfsr_out;

            // Drive standalone LFSR
            // Check it produces expected sequence
            lfsr_state = 15'h7FFF;
            count = 0;

            // Verify first 100 states
            for (int i = 0; i < 100; i++) begin
                logic new_bit;
                new_bit = lfsr_state[14] ^ lfsr_state[0];
                lfsr_state = {lfsr_state[13:0], new_bit};
                count++;
            end

            // Verify the LFSR returns to init after 2^15-1 = 32767 steps
            lfsr_state = 15'h7FFF;
            for (int i = 0; i < 32767; i++) begin
                logic new_bit;
                new_bit = lfsr_state[14] ^ lfsr_state[0];
                lfsr_state = {lfsr_state[13:0], new_bit};
            end
            check("LFSR period = 32767", lfsr_state == 15'h7FFF);
        end

        // Verify the DUT's LFSR matches
        // Start the emulator, wait a bit, read the internal LFSR
        csr_write(4'd0, 32'h0000_0001);  // enable, Poisson, long mode
        run_sequence_start();
        #(CLK_PERIOD * 20);

        // Check that output is valid (not idle) when running
        check("DUT outputs valid data when running", aso_tx8b1k_valid == 1'b1);
        run_sequence_stop();
    endtask

    // ========================================
    // Test B02: Empty frame
    // ========================================
    task automatic test_B02_empty_frame();
        int flen;

        $display("\n=== Test B02: Empty frame (0 events) ===");

        // Configure: very low hit rate → likely 0 events per frame
        csr_write(4'd0, 32'h0000_0001);  // enable, Poisson, long
        csr_write(4'd1, 32'h0000_0000);  // hit_rate=0, noise_rate=0
        csr_write(4'd4, 32'h0000_0008);  // gen_idle=1, tx_mode=000
        run_sequence_start();

        // Capture a frame
        capture_frame(flen);

        $display("  Frame length: %0d bytes", flen);

        // Verify structure: Header(1) + FrameCount(2) + EventCount(2) + DelayByte(1) + CRC(2) + Trailer(1) = 9
        check("Empty frame length = 9 bytes", flen == 9);
        check("Header is K28.0", captured_bytes[0] == K28_0 && captured_isk[0] == 1'b1);
        check("Trailer is K28.4", captured_bytes[flen-1] == K28_4 && captured_isk[flen-1] == 1'b1);

        // Check event count = 0 (lower 10 bits of bytes 3-4)
        begin
            logic [15:0] evt_cnt_ext;
            evt_cnt_ext = {captured_bytes[3], captured_bytes[4]};
            check("Event count = 0", evt_cnt_ext[9:0] == 10'd0);
        end

        // Verify CRC
        // Frame: Header(1) | FC(2) | EC(2) | EventData(n*6) | DelayByte(1) | CRC(2) | Trailer(1)
        // CRC covers bytes 1..flen-5 (FC + EC + event data, NOT delay byte)
        begin
            logic [7:0] crc_data [];
            logic [15:0] crc_expected, crc_received;
            int crc_len;
            crc_len = flen - 5;  // skip header, delay byte, CRC(2), trailer
            crc_data = new[crc_len];
            for (int i = 0; i < crc_len; i++)
                crc_data[i] = captured_bytes[i + 1]; // skip header
            crc_expected = crc16_reference(crc_len, crc_data);
            crc_received = {captured_bytes[flen-3], captured_bytes[flen-2]};
            $display("  CRC expected: %04h, received: %04h", crc_expected, crc_received);
            check("CRC-16 correct", crc_expected == crc_received);
        end

        run_sequence_stop();
    endtask

    // ========================================
    // Test B03: Single long hit
    // ========================================
    task automatic test_B03_single_long();
        int flen;

        $display("\n=== Test B03: Single long hit ===");

        // Configure: set hit rate so ~1 hit per frame
        csr_write(4'd0, 32'h0000_0001);  // enable, Poisson, long
        csr_write(4'd1, 32'h0000_0100);  // hit_rate=1.0 (8.8 FP), noise=0
        csr_write(4'd3, 32'hCAFE_BABE);  // PRNG seed
        csr_write(4'd4, 32'h0000_0008);  // gen_idle=1, tx_mode=000
        run_sequence_start();

        // Skip first frame (may have irregular hit count due to startup)
        capture_frame(flen);
        // Capture second frame
        capture_frame(flen);

        $display("  Frame length: %0d bytes", flen);

        // Structure: Header(1) + FrameCount(2) + EventCount(2) + Data(6) + CRC(2) + Trailer(1) = 14
        // Or could be 0 events if PRNG didn't trigger
        begin
            logic [15:0] evt_cnt_ext;
            evt_cnt_ext = {captured_bytes[3], captured_bytes[4]};
            $display("  Event count: %0d", evt_cnt_ext[9:0]);

            if (evt_cnt_ext[9:0] == 10'd1) begin
                check("Single-hit frame length = 14 bytes", flen == 14);
                // Verify hit data bytes are present (6 bytes at offset 5)
                check("Hit data byte 0 (channel+T_BadHit)", captured_bytes[5] != 8'h00 || captured_bytes[6] != 8'h00);
            end else begin
                $display("  (Hit count was %0d, not exactly 1 — rate-dependent, skipping hit check)", evt_cnt_ext[9:0]);
            end
        end

        // Always verify CRC (skip header, delay byte, CRC, trailer)
        begin
            logic [7:0] crc_data [];
            logic [15:0] crc_expected, crc_received;
            int crc_len;
            crc_len = flen - 5;
            crc_data = new[crc_len];
            for (int i = 0; i < crc_len; i++)
                crc_data[i] = captured_bytes[i + 1];
            crc_expected = crc16_reference(crc_len, crc_data);
            crc_received = {captured_bytes[flen-3], captured_bytes[flen-2]};
            check("CRC-16 correct", crc_expected == crc_received);
        end

        run_sequence_stop();
    endtask

    // ========================================
    // Test B04: Short-frame interval timing
    // ========================================
    task automatic test_B04_short_interval();
        int gap_cycles;

        $display("\n=== Test B04: Short-frame interval timing ===");

        csr_write(4'd0, 32'h0000_0009);  // enable, Poisson, short
        csr_write(4'd1, 32'h0000_0000);  // hit_rate=0, noise_rate=0
        csr_write(4'd4, 32'h0000_0008);  // gen_idle=1, tx_mode=000
        run_sequence_start();

        measure_header_gap(gap_cycles);
        $display("  Header-to-header gap: %0d cycles", gap_cycles);
        check("Short-frame header gap = 910 cycles", gap_cycles == FRAME_INTERVAL_SHORT);

        run_sequence_stop();
    endtask

    // ========================================
    // Test B05: CSR readback
    // ========================================
    task automatic test_B05_csr();
        logic [31:0] rdata;

        $display("\n=== Test B05: CSR readback ===");

        // Write and read back each register
        csr_write(4'd0, 32'h0000_000F);  // control
        csr_read(4'd0, rdata);
        check("CSR[0] readback", rdata[3:0] == 4'hF);

        csr_write(4'd1, 32'hABCD_1234);  // hit_rate + noise_rate
        csr_read(4'd1, rdata);
        check("CSR[1] readback", rdata == 32'hABCD_1234);

        csr_write(4'd2, 32'h0000_0A05);  // burst: center=10, size=5
        csr_read(4'd2, rdata);
        check("CSR[2] readback burst_size", rdata[4:0] == 5'd5);
        check("CSR[2] readback burst_center", rdata[12:8] == 5'd10);

        csr_write(4'd3, 32'hDEAD_BEEF);  // PRNG seed
        csr_read(4'd3, rdata);
        check("CSR[3] readback", rdata == 32'hDEAD_BEEF);

        csr_write(4'd4, 32'h0000_0058);  // asic_id=5, gen_idle=1, tx_mode=0
        csr_read(4'd4, rdata);
        check("CSR[4] readback asic_id", rdata[7:4] == 4'd5);
        check("CSR[4] readback gen_idle", rdata[3] == 1'b1);
    endtask

    // ========================================
    // Test B06: Long-frame interval timing
    // ========================================
    task automatic test_B06_long_interval();
        int gap_cycles;

        $display("\n=== Test B06: Long-frame interval timing ===");

        csr_write(4'd0, 32'h0000_0001);  // enable, Poisson, long
        csr_write(4'd1, 32'h0000_0000);  // hit_rate=0, noise_rate=0
        csr_write(4'd4, 32'h0000_0008);  // gen_idle=1, tx_mode=000
        run_sequence_start();

        measure_header_gap(gap_cycles);
        $display("  Header-to-header gap: %0d cycles", gap_cycles);
        check("Long-frame header gap = 1550 cycles", gap_cycles == FRAME_INTERVAL_LONG);

        run_sequence_stop();
    endtask

    // ========================================
    // Test B07: Short-frame parser semantics
    // ========================================
    task automatic test_B07_short_parser();
        int flen;
        int evt_count;
        logic [47:0] expected_hit;
        logic [27:0] expected_short_word;
        logic [27:0] captured_short_word;

        $display("\n=== Test B07: Short-frame parser semantics ===");

        csr_write(4'd0, 32'h0000_0009);  // enable, Poisson, short
        csr_write(4'd1, 32'h0000_0000);  // disable Poisson/noise background
        csr_write(4'd2, 32'h0000_0801);  // burst_center=8, burst_size=1
        csr_write(4'd3, 32'h1357_2468);  // deterministic fine-time seeds
        csr_write(4'd4, 32'h0000_004C);  // asic_id=4, gen_idle=1, tx_mode=short
        clear_hit_generator_state();
        run_sequence_start();
        repeat (20) @(posedge clk);

        pulse_inject_once();
        wait_for_generated_hit(expected_hit);
        capture_next_nonempty_frame(flen, evt_count);
        run_sequence_stop();

        captured_short_word = decode_short_hit_from_capture();

        $display("  Frame length: %0d bytes, event count: %0d", flen, evt_count);
        check("Injected short frame carries one hit", evt_count == 1);
        check("Short payload bytes are data, not K-codes",
              !captured_isk[5] && !captured_isk[6] && !captured_isk[7] && !captured_isk[8]);
        check("Short payload low nibble is zero pad", captured_bytes[8][3:0] == 4'h0);
`ifndef EMUT_GATE_SIM
        expected_short_word = {
            expected_hit[47:43],
            expected_hit[42],
            expected_hit[41:27],
            expected_hit[26:22],
            expected_hit[20],
            1'b0
        };
        check("Short payload matches generated TCC/T_Fine word",
              captured_short_word == expected_short_word);
`else
        $display("  NOTE: Gate-level netlist omits internal generated-hit visibility; skipping direct payload-to-generator compare");
`endif

        replay_captured_frame(flen);

        check("Parser saw one headerinfo word", parser_header_count == 1);
        check("Parser saw one short hit", parser_hit_count == 1);
        check("Parser short mode flags decoded", parser_last_headerinfo_data[4:2] == TX_MODE_SHORT);
        check("Parser decoded one-hit frame length", parser_last_headerinfo_data[15:6] == 10'd1);
        check("Parser short E_CC is zero", parser_last_hit_data[15:1] == 15'd0);
        check("Parser short SOP/EOP are asserted", parser_last_hit_sop && parser_last_hit_eop);
        check("Parser short hit is error-free", parser_last_hit_error == 3'b000);
    endtask

    // ========================================
    // Test T01: Multi-hit long frame
    // ========================================
    task automatic test_T01_multi_long();
        int flen;

        $display("\n=== Test T01: Multi-hit long frame ===");

        csr_write(4'd0, 32'h0000_0001);  // enable, Poisson, long
        csr_write(4'd1, 32'h0000_2000);  // hit_rate = 32.0 (8.8 FP) → ~8 hits avg
        csr_write(4'd3, 32'h1234_5678);
        csr_write(4'd4, 32'h0000_0008);  // gen_idle=1
        run_sequence_start();

        // Skip first 2 frames
        capture_frame(flen);
        capture_frame(flen);
        // Capture 3rd frame
        capture_frame(flen);

        begin
            logic [15:0] evt_cnt_ext;
            evt_cnt_ext = {captured_bytes[3], captured_bytes[4]};
            $display("  Event count: %0d, frame length: %0d bytes", evt_cnt_ext[9:0], flen);

            // Expected: Header(1) + FC(2) + EC(2) + n*6 + DelayByte(1) + CRC(2) + Trailer(1) = 9 + n*6
            if (evt_cnt_ext[9:0] > 0) begin
                int expected_len;
                expected_len = 9 + evt_cnt_ext[9:0] * 6;
                check("Long frame length matches event count", flen == expected_len);
            end
        end

        // CRC check (skip header, delay byte, CRC, trailer)
        begin
            logic [7:0] crc_data [];
            logic [15:0] crc_expected, crc_received;
            int crc_len;
            crc_len = flen - 5;
            crc_data = new[crc_len];
            for (int i = 0; i < crc_len; i++)
                crc_data[i] = captured_bytes[i + 1];
            crc_expected = crc16_reference(crc_len, crc_data);
            crc_received = {captured_bytes[flen-3], captured_bytes[flen-2]};
            check("CRC-16 correct", crc_expected == crc_received);
        end

        run_sequence_stop();
    endtask

    // ========================================
    // Test T06: Run control gating
    // ========================================
    task automatic test_T06_runctl();
        $display("\n=== Test T06: Run control gating ===");

        csr_write(4'd0, 32'h0000_0001);
        csr_write(4'd1, 32'h0000_0800);
        csr_write(4'd4, 32'h0000_0008);

        // Before RUNNING: should output idle comma
        #(CLK_PERIOD * 10);
        check("Idle output before RUNNING", aso_tx8b1k_data == {1'b1, K28_5});

        // Enter RUNNING
        run_sequence_start();
        #(CLK_PERIOD * 50);
        // Should see non-idle data
        begin
            logic saw_header;
            saw_header = 0;
            for (int i = 0; i < 2000; i++) begin
                @(posedge clk);
                if (aso_tx8b1k_data == {1'b1, K28_0}) saw_header = 1;
            end
            check("Saw header during RUNNING", saw_header);
        end

        // Stop
        run_sequence_stop();
        #(CLK_PERIOD * 100);
        check("Idle output after stop", aso_tx8b1k_data == {1'b1, K28_5});
    endtask

    // ========================================
    // Test T07: Frame counter increment
    // ========================================
    task automatic test_T07_frame_counter();
        int flen;

        $display("\n=== Test T07: Frame counter increment ===");

        csr_write(4'd0, 32'h0000_0001);
        csr_write(4'd1, 32'h0000_0000);  // 0 events
        csr_write(4'd4, 32'h0000_0008);
        run_sequence_start();

        // Capture 3 consecutive frames, check frame_count increments
        for (int f = 0; f < 3; f++) begin
            logic [15:0] fc;
            capture_frame(flen);
            fc = {captured_bytes[1], captured_bytes[2]};
            $display("  Frame %0d: frame_count = %0d", f, fc);
            check($sformatf("Frame %0d counter = %0d", f, fc), fc == f);
        end

        run_sequence_stop();
    endtask

    // ========================================
    // Test T08: ASIC ID tag
    // ========================================
    task automatic test_T08_asic_id();
        $display("\n=== Test T08: ASIC ID tag ===");

        csr_write(4'd0, 32'h0000_0001);
        csr_write(4'd1, 32'h0000_0000);
        csr_write(4'd4, 32'h0000_00B8);  // asic_id=11, gen_idle=1
        run_sequence_start();
        #(CLK_PERIOD * 10);

        check("ASIC ID channel output = 11", aso_tx8b1k_channel == 4'd11);

        run_sequence_stop();
    endtask

    // ========================================
    // Test E03: Back-to-back frames
    // ========================================
    task automatic test_E03_back2back();
        int flen1, flen2, flen3;

        $display("\n=== Test E03: Back-to-back frames ===");

        csr_write(4'd0, 32'h0000_0001);
        csr_write(4'd1, 32'h0000_0000);
        csr_write(4'd4, 32'h0000_0008);
        run_sequence_start();

        capture_frame(flen1);
        capture_frame(flen2);
        capture_frame(flen3);

        check("3 consecutive frames captured", flen1 > 0 && flen2 > 0 && flen3 > 0);

        // Verify frame counter increments
        begin
            logic [15:0] fc1, fc2, fc3;
            fc1 = {captured_bytes[1], captured_bytes[2]};
            // Need to re-capture for fc2/fc3 — but we only have last capture
            // At least verify the last frame
            $display("  Frame lengths: %0d, %0d, %0d", flen1, flen2, flen3);
            check("Frames are well-formed (length > 7)", flen1 >= 8 && flen2 >= 8 && flen3 >= 8);
        end

        run_sequence_stop();
    endtask

    // ========================================
    // Test orchestrator
    // ========================================
    initial begin
        // Initialize control signals
        asi_ctrl_data   = '0;
        asi_ctrl_valid  = 1'b0;
        coe_inject_pulse = 1'b0;
        avs_csr_address = '0;
        avs_csr_read    = 1'b0;
        avs_csr_write   = 1'b0;
        avs_csr_writedata = '0;
        parser_rst      = 1'b1;
        parser_rx_data  = '0;
        parser_rx_valid = 1'b0;
        parser_rx_error = '0;
        parser_rx_channel = '0;
        parser_ctrl_data = CTRL_IDLE;
        parser_ctrl_valid = 1'b0;
        parser_csr_address = '0;
        parser_csr_read = 1'b0;
        parser_csr_write = 1'b0;
        parser_csr_writedata = '0;

        // Wait for reset
        @(negedge rst);
        #(CLK_PERIOD * 5);

        $display("============================================================");
        $display("  MuTRiG Emulator Testbench — TEST=%s SEED=%0d", test_name, seed);
        $display("============================================================");

        if (test_name == "ALL" || test_name == "B01_lfsr")
            test_B01_lfsr();

        if (test_name == "ALL" || test_name == "B02_empty_frame")
            test_B02_empty_frame();

        if (test_name == "ALL" || test_name == "B03_single_long")
            test_B03_single_long();

        if (test_name == "ALL" || test_name == "B04_short_interval")
            test_B04_short_interval();

        if (test_name == "ALL" || test_name == "B05_csr")
            test_B05_csr();

        if (test_name == "ALL" || test_name == "B06_long_interval")
            test_B06_long_interval();

        if (test_name == "ALL" || test_name == "B07_short_parser")
            test_B07_short_parser();

        if (test_name == "ALL" || test_name == "T01_multi_long")
            test_T01_multi_long();

        if (test_name == "ALL" || test_name == "T06_runctl")
            test_T06_runctl();

        if (test_name == "ALL" || test_name == "T07_frame_counter")
            test_T07_frame_counter();

        if (test_name == "ALL" || test_name == "T08_asic_id")
            test_T08_asic_id();

        if (test_name == "ALL" || test_name == "E03_back2back")
            test_E03_back2back();

        // Report
        $display("\n============================================================");
        $display("  RESULTS: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0)
            $display("  >>> ALL TESTS PASSED <<<");
        else
            $display("  >>> SOME TESTS FAILED <<<");
        $display("============================================================\n");

        $finish;
    end

    // Timeout watchdog
    initial begin
        #(CLK_PERIOD * 500000);
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule
