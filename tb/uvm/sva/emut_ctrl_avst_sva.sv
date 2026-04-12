`timescale 1ps/1ps

module emut_ctrl_avst_sva (
  input logic       clk,
  input logic       rst,
  input logic [8:0] data,
  input logic       valid,
  input logic       ready
);
  property p_ctrl_known_when_valid;
    @(posedge clk) disable iff (rst)
      valid |-> !$isunknown(data);
  endproperty

  property p_ctrl_onehot_when_valid;
    @(posedge clk) disable iff (rst)
      valid |-> $onehot(data);
  endproperty

  property p_ready_known;
    @(posedge clk) disable iff (rst)
      !$isunknown(ready);
  endproperty

  assert property (p_ctrl_known_when_valid) else $error("CTRL data unknown while valid");
  assert property (p_ctrl_onehot_when_valid) else $error("CTRL data not one-hot while valid");
  assert property (p_ready_known) else $error("CTRL ready unknown");
endmodule
