`timescale 1ps/1ps

module emut_internal_sva (
  input logic       clk,
  input logic       rst,
  input logic       run_active,
  input logic       csr_enable,
  input logic       inject_pulse_clk,
  input logic       frame_start,
  input logic [15:0] status_frame_count,
  input logic [8:0] tx_data,
  input logic       tx_valid
);
  property p_idle_when_disabled;
    @(posedge clk) disable iff (rst)
      (!run_active || !csr_enable) |-> (tx_valid && tx_data == {1'b1, 8'hBC});
  endproperty

  property p_inject_single_cycle;
    @(posedge clk) disable iff (rst)
      inject_pulse_clk |=> !inject_pulse_clk;
  endproperty

  property p_frame_count_advances;
    @(posedge clk) disable iff (rst)
      frame_start |=> status_frame_count == ($past(status_frame_count) + 16'd1);
  endproperty

  assert property (p_idle_when_disabled) else $error("Output was not idle while disabled/not running");
  assert property (p_inject_single_cycle) else $error("inject_pulse_clk was wider than one cycle");
  assert property (p_frame_count_advances) else $error("status_frame_count did not advance after frame_start");
endmodule
