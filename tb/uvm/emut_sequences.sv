class emut_csr_write_seq extends uvm_sequence #(emut_csr_item);
  `uvm_object_utils(emut_csr_write_seq)

  bit [3:0]  addr;
  bit [31:0] data;

  function new(string name = "emut_csr_write_seq");
    super.new(name);
  endfunction

  task body();
    emut_csr_item item;
    item = emut_csr_item::type_id::create("csr_wr");
    start_item(item);
    item.is_write  = 1'b1;
    item.address   = addr;
    item.writedata = data;
    finish_item(item);
  endtask
endclass

class emut_csr_read_seq extends uvm_sequence #(emut_csr_item);
  `uvm_object_utils(emut_csr_read_seq)

  bit [3:0]  addr;
  bit [31:0] data;

  function new(string name = "emut_csr_read_seq");
    super.new(name);
  endfunction

  task body();
    emut_csr_item item;
    item = emut_csr_item::type_id::create("csr_rd");
    start_item(item);
    item.is_write  = 1'b0;
    item.address   = addr;
    item.writedata = '0;
    finish_item(item);
    data = item.readdata;
  endtask
endclass

class emut_ctrl_seq extends uvm_sequence #(emut_ctrl_item);
  `uvm_object_utils(emut_ctrl_seq)

  logic [8:0] cmd;
  int unsigned post_accept_delay_cycles = 0;
  string       state_name = "";

  function new(string name = "emut_ctrl_seq");
    super.new(name);
  endfunction

  task body();
    emut_ctrl_item item;
    item = emut_ctrl_item::type_id::create("ctrl_item");
    start_item(item);
    item.cmd = cmd;
    item.post_accept_delay_cycles = post_accept_delay_cycles;
    item.state_name = state_name;
    finish_item(item);
  endtask
endclass

class emut_run_start_seq extends uvm_sequence #(emut_ctrl_item);
  `uvm_object_utils(emut_run_start_seq)

  int unsigned run_prepare_cycles = 5;
  int unsigned sync_cycles = 5;
  int unsigned running_settle_cycles = 4;

  function new(string name = "emut_run_start_seq");
    super.new(name);
  endfunction

  task body();
    emut_ctrl_item item;

    item = emut_ctrl_item::type_id::create("ctrl_prepare");
    start_item(item);
    item.cmd = CTRL_RUN_PREPARE;
    item.state_name = "RUN_PREPARE";
    item.post_accept_delay_cycles = run_prepare_cycles;
    finish_item(item);

    item = emut_ctrl_item::type_id::create("ctrl_sync");
    start_item(item);
    item.cmd = CTRL_SYNC;
    item.state_name = "SYNC";
    item.post_accept_delay_cycles = sync_cycles;
    finish_item(item);

    item = emut_ctrl_item::type_id::create("ctrl_running");
    start_item(item);
    item.cmd = CTRL_RUNNING;
    item.state_name = "RUNNING";
    item.post_accept_delay_cycles = running_settle_cycles;
    finish_item(item);
  endtask
endclass

class emut_run_stop_seq extends uvm_sequence #(emut_ctrl_item);
  `uvm_object_utils(emut_run_stop_seq)

  int unsigned terminating_hold_cycles = 5;
  int unsigned idle_recovery_cycles = 5;

  function new(string name = "emut_run_stop_seq");
    super.new(name);
  endfunction

  task body();
    emut_ctrl_item item;

    item = emut_ctrl_item::type_id::create("ctrl_terminating");
    start_item(item);
    item.cmd = CTRL_TERMINATING;
    item.state_name = "TERMINATING";
    item.post_accept_delay_cycles = terminating_hold_cycles;
    finish_item(item);

    item = emut_ctrl_item::type_id::create("ctrl_idle");
    start_item(item);
    item.cmd = CTRL_IDLE;
    item.state_name = "IDLE";
    item.post_accept_delay_cycles = idle_recovery_cycles;
    finish_item(item);
  endtask
endclass

class emut_inject_seq extends uvm_sequence #(emut_inject_item);
  `uvm_object_utils(emut_inject_seq)

  int unsigned start_delay_cycles = 0;
  int unsigned phase_ps           = 0;
  int unsigned width_ps           = 12000;

  function new(string name = "emut_inject_seq");
    super.new(name);
  endfunction

  task body();
    emut_inject_item item;
    item = emut_inject_item::type_id::create("inject_item");
    start_item(item);
    item.start_delay_cycles = start_delay_cycles;
    item.phase_ps           = phase_ps;
    item.width_ps           = width_ps;
    finish_item(item);
  endtask
endclass
