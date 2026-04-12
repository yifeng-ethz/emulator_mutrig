`timescale 1ps/1ps

package emut_env_pkg;
  import uvm_pkg::*;
  import emulator_mutrig_pkg::*;
  `include "uvm_macros.svh"

  `uvm_analysis_imp_decl(_csr)
  `uvm_analysis_imp_decl(_ctrl)
  `uvm_analysis_imp_decl(_inject)
  `uvm_analysis_imp_decl(_tx)
  `uvm_analysis_imp_decl(_parser)

  localparam logic [8:0] CTRL_IDLE        = 9'b000000001;
  localparam logic [8:0] CTRL_RUN_PREPARE = 9'b000000010;
  localparam logic [8:0] CTRL_SYNC        = 9'b000000100;
  localparam logic [8:0] CTRL_RUNNING     = 9'b000001000;
  localparam logic [8:0] CTRL_TERMINATING = 9'b000010000;

  localparam time CLK_PERIOD_PS = 8000ps;

  function automatic int unsigned emut_ceil_div(input int unsigned num, input int unsigned den);
    return (num + den - 1) / den;
  endfunction

  class emut_cfg extends uvm_object;
    `uvm_object_utils(emut_cfg)

    int unsigned frame_timeout_cycles = 20000;

    function new(string name = "emut_cfg");
      super.new(name);
    endfunction
  endclass

  class emut_csr_item extends uvm_sequence_item;
    `uvm_object_utils(emut_csr_item)

    bit        is_write;
    bit [3:0]  address;
    bit [31:0] writedata;
    bit [31:0] readdata;
    time       complete_time_ps;

    function new(string name = "emut_csr_item");
      super.new(name);
    endfunction
  endclass

  class emut_ctrl_item extends uvm_sequence_item;
    `uvm_object_utils(emut_ctrl_item)

    logic [8:0] cmd;
    time        drive_time_ps;

    function new(string name = "emut_ctrl_item");
      super.new(name);
    endfunction
  endclass

  class emut_inject_item extends uvm_sequence_item;
    `uvm_object_utils(emut_inject_item)

    rand int unsigned start_delay_cycles;
    rand int unsigned phase_ps;
    rand int unsigned width_ps;
    time              rise_time_ps;
    time              fall_time_ps;

    constraint c_phase { phase_ps inside {[0:7999]}; }
    constraint c_width { width_ps inside {[2000:20000]}; }

    function new(string name = "emut_inject_item");
      super.new(name);
    endfunction
  endclass

  class emut_tx_frame_item extends uvm_sequence_item;
    `uvm_object_utils(emut_tx_frame_item)

    byte unsigned bytes[$];
    bit           is_k[$];
    bit [2:0]     error[$];

    bit [3:0]     channel;
    bit [15:0]    frame_count;
    bit [5:0]     frame_flags;
    bit [9:0]     event_count;
    byte unsigned delay_byte;
    bit [15:0]    crc_expected;
    bit [15:0]    crc_received;
    bit           crc_ok;
    int unsigned  frame_len;
    int unsigned  header_gap_cycles;
    time          header_time_ps;
    time          trailer_time_ps;

    function new(string name = "emut_tx_frame_item");
      super.new(name);
    endfunction
  endclass

  class emut_parser_frame_item extends uvm_sequence_item;
    `uvm_object_utils(emut_parser_frame_item)

    bit [5:0]   frame_flags;
    bit [9:0]   frame_len;
    bit [9:0]   word_count;
    bit [15:0]  frame_number;
    bit [3:0]   channel;

    bit [44:0]  hit_data[$];
    bit [2:0]   hit_error[$];
    bit         hit_sop[$];
    bit         hit_eop[$];
    time        header_time_ps;
    time        first_hit_time_ps;

    function new(string name = "emut_parser_frame_item");
      super.new(name);
    endfunction
  endclass

  `include "emut_csr_driver.sv"
  `include "emut_ctrl_driver.sv"
  `include "emut_inject_driver.sv"
  `include "emut_tx_monitor.sv"
  `include "emut_parser_monitor.sv"
  `include "emut_scoreboard.sv"
  `include "emut_coverage.sv"
  `include "emut_env.sv"
  `include "emut_sequences.sv"
  `include "emut_base_test.sv"

endpackage
