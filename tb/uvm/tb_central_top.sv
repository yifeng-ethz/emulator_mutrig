// tb_central_top.sv
// Direct testbench top for the central-trigger emulator_mutrig 26.2.x.
// Author: Yifeng Wang
// Version : 26.2.1
// Date    : 20260502
//
// First-pass DV harness covering the BASIC golden-CSR-header bucket
// (B001-B009 from tb/DV_BASIC.md). UVM-class wiring is the next step;
// this file is the bring-up surface that proves the new 8-lane top
// answers AVMM CSR transactions end-to-end with the right values.

`timescale 1ns/1ps

module tb_central_top;

    localparam int LANE_COUNT = 8;

    logic clk = 1'b0;
    logic rst = 1'b1;

    logic [8:0]  ctrl_data;
    logic        ctrl_valid;
    logic        ctrl_ready;
    logic        inject_pulse = 1'b0;

    logic [5:0]  csr_addr;
    logic        csr_read;
    logic        csr_write;
    logic [31:0] csr_wdata;
    logic [31:0] csr_rdata;
    logic        csr_wait;

    logic [LANE_COUNT-1:0][44:0] hit_type0_data;
    logic [LANE_COUNT-1:0]       hit_type0_valid;
    logic [LANE_COUNT-1:0]       hit_type0_sop;
    logic [LANE_COUNT-1:0]       hit_type0_eop;
    logic [LANE_COUNT-1:0]       hit_type0_eor;
    logic [LANE_COUNT-1:0][2:0]  hit_type0_error;
    logic [LANE_COUNT-1:0][3:0]  hit_type0_channel;

    logic [LANE_COUNT-1:0][8:0]  tx8b1k_data;
    logic [LANE_COUNT-1:0]       tx8b1k_valid;
    logic [LANE_COUNT-1:0][2:0]  tx8b1k_error;
    logic [LANE_COUNT-1:0][3:0]  tx8b1k_channel;

    int unsigned passes = 0;
    int unsigned fails  = 0;

    always #4 clk = ~clk;

    emulator_mutrig #(
        .LANE_COUNT         (LANE_COUNT),
        .BYTE_STREAM_ENABLE (1'b0)
    ) u_dut (
        .i_clk              (clk),
        .i_rst              (rst),
        .asi_ctrl_data      (ctrl_data),
        .asi_ctrl_valid     (ctrl_valid),
        .asi_ctrl_ready     (ctrl_ready),
        .coe_inject_pulse   (inject_pulse),
        .avs_csr_address    (csr_addr),
        .avs_csr_read       (csr_read),
        .avs_csr_write      (csr_write),
        .avs_csr_writedata  (csr_wdata),
        .avs_csr_readdata   (csr_rdata),
        .avs_csr_waitrequest(csr_wait),
        .aso_hit_type0_data         (hit_type0_data),
        .aso_hit_type0_valid        (hit_type0_valid),
        .aso_hit_type0_startofpacket(hit_type0_sop),
        .aso_hit_type0_endofpacket  (hit_type0_eop),
        .aso_hit_type0_endofrun     (hit_type0_eor),
        .aso_hit_type0_error        (hit_type0_error),
        .aso_hit_type0_channel      (hit_type0_channel),
        .aso_tx8b1k_data            (tx8b1k_data),
        .aso_tx8b1k_valid           (tx8b1k_valid),
        .aso_tx8b1k_error           (tx8b1k_error),
        .aso_tx8b1k_channel         (tx8b1k_channel)
    );

    task automatic csr_write_word(input logic [5:0] addr, input logic [31:0] data);
        @(posedge clk);
        csr_addr  <= addr;
        csr_write <= 1'b1;
        csr_read  <= 1'b0;
        csr_wdata <= data;
        @(posedge clk);
        csr_write <= 1'b0;
        csr_addr  <= '0;
        csr_wdata <= '0;
    endtask

    task automatic csr_read_word(input logic [5:0] addr, output logic [31:0] data);
        // CSR readdata is combinational from avs_csr_address. Hold the
        // address stable, sample csr_rdata combinationally on the read
        // cycle, then deassert. Sampling happens just before the next
        // posedge so the captured value reflects the current address.
        @(posedge clk);
        csr_addr  <= addr;
        csr_read  <= 1'b1;
        csr_write <= 1'b0;
        @(posedge clk);
        data = csr_rdata;          // combinational sample on the read cycle
        @(posedge clk);
        csr_read  <= 1'b0;
        csr_addr  <= '0;
    endtask

    task automatic check(input string id, input logic [31:0] expected, input logic [31:0] actual);
        if (expected === actual) begin
            $display("[%-6s] PASS expected=0x%08x actual=0x%08x", id, expected, actual);
            passes++;
        end else begin
            $display("[%-6s] FAIL expected=0x%08x actual=0x%08x", id, expected, actual);
            fails++;
        end
    endtask

    initial begin
        logic [31:0] rdata;

        ctrl_data    = '0;
        ctrl_valid   = 1'b0;
        csr_addr     = '0;
        csr_read     = 1'b0;
        csr_write    = 1'b0;
        csr_wdata    = '0;
        inject_pulse = 1'b0;

        // Cold reset
        rst = 1'b1;
        repeat (10) @(posedge clk);
        rst = 1'b0;
        repeat (5) @(posedge clk);

        $display("=== tb_central_top: BASIC golden-CSR-header bucket ===");

        // B001 — UID readback
        csr_read_word(6'h00, rdata);
        check("B001", 32'h454D5554, rdata);

        // B002 — UID is RO; write should be ignored
        csr_write_word(6'h00, 32'hDEADBEEF);
        csr_read_word(6'h00, rdata);
        check("B002", 32'h454D5554, rdata);

        // B003 — META selector page 0 (VERSION)
        csr_write_word(6'h01, 32'h0);
        csr_read_word(6'h01, rdata);
        // VERSION packed as MAJOR[31:24]=26, MINOR[23:16]=2, PATCH[15:12]=0, BUILD[11:0]=502 (0x1F6)
        check("B003", 32'h1A02_01F6, rdata);

        // B004 — META selector page 1 (DATE)
        csr_write_word(6'h01, 32'h1);
        csr_read_word(6'h01, rdata);
        check("B004", 32'h0135_2696, rdata);  // 20260502 = 0x01352696

        // B005 — META selector page 2 (GIT) - VERSION_GIT default 0
        csr_write_word(6'h01, 32'h2);
        csr_read_word(6'h01, rdata);
        check("B005", 32'h0, rdata);

        // B006 — META selector page 3 (INSTANCE_ID) - default 0
        csr_write_word(6'h01, 32'h3);
        csr_read_word(6'h01, rdata);
        check("B006", 32'h0, rdata);

        // B007 — SCRATCH write/read 0xDEADBEEF
        csr_write_word(6'h02, 32'hDEAD_BEEF);
        csr_read_word(6'h02, rdata);
        check("B007", 32'hDEAD_BEEF, rdata);

        // B008 — SCRATCH write/read 0x12345678
        csr_write_word(6'h02, 32'h1234_5678);
        csr_read_word(6'h02, rdata);
        check("B008", 32'h1234_5678, rdata);

        // B009 — SCRATCH reset value (re-reset, then read before any write)
        rst = 1'b1;
        repeat (5) @(posedge clk);
        rst = 1'b0;
        repeat (3) @(posedge clk);
        csr_read_word(6'h02, rdata);
        check("B009", 32'h0, rdata);

        $display("=== Summary: %0d PASS, %0d FAIL ===", passes, fails);
        if (fails > 0) begin
            $error("DV BASIC: %0d failures", fails);
            $finish(1);
        end else begin
            $display("DV BASIC: all checks pass");
            $finish(0);
        end
    end

endmodule
