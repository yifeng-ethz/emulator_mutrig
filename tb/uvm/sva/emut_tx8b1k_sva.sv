`timescale 1ps/1ps

module emut_tx8b1k_sva (
  input logic       clk,
  input logic       rst,
  input logic [8:0] data,
  input logic       valid,
  input logic [3:0] channel,
  input logic [2:0] error
);
  property p_tx_known_when_valid;
    @(posedge clk) disable iff (rst)
      valid |-> !$isunknown({data, channel, error});
  endproperty

  property p_kchar_legal;
    @(posedge clk) disable iff (rst)
      (valid && data[8]) |-> (data[7:0] inside {8'h1C, 8'h9C, 8'hBC});
  endproperty

  assert property (p_tx_known_when_valid) else $error("TX bus unknown while valid");
  assert property (p_kchar_legal) else $error("Illegal K-character on tx8b1k");
endmodule
