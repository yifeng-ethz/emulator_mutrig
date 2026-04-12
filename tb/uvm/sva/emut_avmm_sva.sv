`timescale 1ps/1ps

module emut_avmm_sva (
  input logic        clk,
  input logic        rst,
  input logic [3:0]  address,
  input logic        read,
  input logic        write,
  input logic [31:0] writedata,
  input logic [31:0] readdata,
  input logic        waitrequest
);
  property p_no_read_write_overlap;
    @(posedge clk) disable iff (rst)
      !(read && write);
  endproperty

  property p_known_address_on_access;
    @(posedge clk) disable iff (rst)
      (read || write) |-> !$isunknown(address);
  endproperty

  property p_known_write_data;
    @(posedge clk) disable iff (rst)
      write |-> !$isunknown(writedata);
  endproperty

  property p_known_read_data;
    @(posedge clk) disable iff (rst)
      (read && !waitrequest) |-> !$isunknown(readdata);
  endproperty

  assert property (p_no_read_write_overlap) else $error("AVMM read/write overlap");
  assert property (p_known_address_on_access) else $error("AVMM address unknown during access");
  assert property (p_known_write_data) else $error("AVMM write data unknown");
  assert property (p_known_read_data) else $error("AVMM read data unknown");
endmodule
