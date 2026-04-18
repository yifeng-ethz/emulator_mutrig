`timescale 1ps/1ps

module tb_top;
  import uvm_pkg::*;
  import emulator_mutrig_pkg::*;
  import emut_env_pkg::*;
  `include "uvm_macros.svh"

  logic clk = 1'b0;
  logic rst = 1'b1;

  logic [31:0] parser_csr_readdata;
  logic        parser_csr_waitrequest;
  logic        parser_ctrl_ready;
  logic        frame_idle;

  always #(CLK_PERIOD_PS/2) clk = ~clk;

  initial begin
    rst = 1'b1;
    #(10 * CLK_PERIOD_PS);
    rst = 1'b0;
  end

  emut_avmm_csr_if csr_if(.clk(clk), .rst(rst));
  emut_ctrl_if     ctrl_if(.clk(clk), .rst(rst));
  emut_inject_if   inject_if(.clk(clk), .rst(rst));
  emut_tx_if       tx_if(.clk(clk), .rst(rst));
  emut_parser_if   parser_if(.clk(clk), .rst(rst));

  emulator_mutrig #(
    .FIFO_DEPTH     (RAW_FIFO_DEPTH),
    .CSR_ADDR_WIDTH (4)
  ) dut (
    .i_clk              (clk),
    .i_rst              (rst),
    .aso_tx8b1k_data    (tx_if.data),
    .aso_tx8b1k_valid   (tx_if.valid),
    .aso_tx8b1k_channel (tx_if.channel),
    .aso_tx8b1k_error   (tx_if.error),
    .asi_ctrl_data      (ctrl_if.data),
    .asi_ctrl_valid     (ctrl_if.valid),
    .asi_ctrl_ready     (ctrl_if.ready),
    .coe_inject_pulse   (inject_if.pulse),
    .coe_inject_masked_pulse(inject_if.masked_pulse),
    .avs_csr_address    (csr_if.address),
    .avs_csr_read       (csr_if.read),
    .avs_csr_write      (csr_if.write),
    .avs_csr_writedata  (csr_if.writedata),
    .avs_csr_readdata   (csr_if.readdata),
    .avs_csr_waitrequest(csr_if.waitrequest)
  );

  frame_rcv_ip #(
    .CHANNEL_WIDTH  (4),
    .CSR_ADDR_WIDTH (2),
    .MODE_HALT      (0),
    .DEBUG_LV       (0)
  ) parser (
    .asi_rx8b1k_data             (tx_if.data),
    .asi_rx8b1k_valid            (tx_if.valid),
    .asi_rx8b1k_error            (tx_if.error),
    .asi_rx8b1k_channel          (tx_if.channel),
    .aso_hit_type0_channel       (parser_if.hit_channel),
    .aso_hit_type0_startofpacket (parser_if.hit_sop),
    .aso_hit_type0_endofpacket   (parser_if.hit_eop),
    .aso_hit_type0_endofrun      (/*unused*/),
        .aso_hit_type0_error         (parser_if.hit_error),
    .aso_hit_type0_data          (parser_if.hit_data),
    .aso_hit_type0_valid         (parser_if.hit_valid),
    .aso_headerinfo_data         (parser_if.headerinfo_data),
    .aso_headerinfo_valid        (parser_if.headerinfo_valid),
    .aso_headerinfo_channel      (parser_if.headerinfo_channel),
    .avs_csr_readdata            (parser_csr_readdata),
    .avs_csr_read                (1'b0),
    .avs_csr_address             (2'b00),
    .avs_csr_waitrequest         (parser_csr_waitrequest),
    .avs_csr_write               (1'b0),
    .avs_csr_writedata           (32'b0),
    .asi_ctrl_data               (ctrl_if.data),
    .asi_ctrl_valid              (ctrl_if.valid),
    .asi_ctrl_ready              (parser_ctrl_ready),
    .i_rst                       (rst),
    .i_clk                       (clk)
  );

  assign frame_idle = (dut.u_frame_asm.p_state == 4'd0);

  emut_avmm_sva u_avmm_sva (
    .clk        (clk),
    .rst        (rst),
    .address    (csr_if.address),
    .read       (csr_if.read),
    .write      (csr_if.write),
    .writedata  (csr_if.writedata),
    .readdata   (csr_if.readdata),
    .waitrequest(csr_if.waitrequest)
  );

  emut_ctrl_avst_sva u_ctrl_sva (
    .clk  (clk),
    .rst  (rst),
    .data (ctrl_if.data),
    .valid(ctrl_if.valid),
    .ready(ctrl_if.ready)
  );

  emut_tx8b1k_sva u_tx_sva (
    .clk    (clk),
    .rst    (rst),
    .data   (tx_if.data),
    .valid  (tx_if.valid),
    .channel(tx_if.channel),
    .error  (tx_if.error)
  );

  emut_internal_sva u_internal_sva (
    .clk              (clk),
    .rst              (rst),
    .run_generating   (dut.run_generating),
    .run_draining     (dut.run_draining),
    .frame_idle       (frame_idle),
    .csr_enable       (dut.csr_enable),
    .inject_pulse_clk (dut.inject_pulse_clk),
    .frame_start      (dut.frame_start),
    .status_frame_count(dut.status_frame_count),
    .tx_data          (tx_if.data),
    .tx_valid         (tx_if.valid)
  );

  initial begin
    uvm_config_db#(virtual emut_avmm_csr_if.drv)::set(
      null, "uvm_test_top.m_env.m_csr_drv", "vif", csr_if);
    uvm_config_db#(virtual emut_ctrl_if.drv)::set(
      null, "uvm_test_top.m_env.m_ctrl_drv", "vif", ctrl_if);
    uvm_config_db#(virtual emut_inject_if.drv)::set(
      null, "uvm_test_top.m_env.m_inject_drv", "vif", inject_if);
    uvm_config_db#(virtual emut_tx_if.mon)::set(
      null, "uvm_test_top.m_env.m_tx_mon", "vif", tx_if);
    uvm_config_db#(virtual emut_parser_if.mon)::set(
      null, "uvm_test_top.m_env.m_parser_mon", "vif", parser_if);

    run_test();
  end

  initial begin
    #(5_000_000ns);
    `uvm_fatal("TB_TOP", "Global timeout reached")
  end
endmodule
