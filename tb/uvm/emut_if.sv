`timescale 1ps/1ps

interface emut_avmm_csr_if(input logic clk, input logic rst);
  logic [3:0]  address;
  logic        read;
  logic        write;
  logic [31:0] writedata;
  logic [31:0] readdata;
  logic        waitrequest;

  modport drv (
    output address, read, write, writedata,
    input  readdata, waitrequest, clk, rst
  );

  modport mon (
    input address, read, write, writedata, readdata, waitrequest, clk, rst
  );
endinterface

interface emut_ctrl_if(input logic clk, input logic rst);
  logic [8:0] data;
  logic       valid;
  logic       ready;

  modport drv (
    output data, valid,
    input  ready, clk, rst
  );

  modport mon (
    input data, valid, ready, clk, rst
  );
endinterface

interface emut_inject_if(input logic clk, input logic rst);
  logic pulse;
  logic masked_pulse;

  modport drv (
    output pulse, masked_pulse,
    input  clk, rst
  );

  modport mon (
    input pulse, masked_pulse, clk, rst
  );
endinterface

interface emut_tx_if(input logic clk, input logic rst);
  logic [8:0] data;
  logic       valid;
  logic [3:0] channel;
  logic [2:0] error;

  modport mon (
    input data, valid, channel, error, clk, rst
  );
endinterface

interface emut_parser_if(input logic clk, input logic rst);
  logic [3:0]  hit_channel;
  logic        hit_sop;
  logic        hit_eop;
  logic [2:0]  hit_error;
  logic [44:0] hit_data;
  logic        hit_valid;

  logic [41:0] headerinfo_data;
  logic        headerinfo_valid;
  logic [3:0]  headerinfo_channel;

  modport mon (
    input hit_channel, hit_sop, hit_eop, hit_error, hit_data, hit_valid,
          headerinfo_data, headerinfo_valid, headerinfo_channel, clk, rst
  );
endinterface
