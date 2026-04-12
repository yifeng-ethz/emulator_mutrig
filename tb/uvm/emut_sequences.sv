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

  function new(string name = "emut_ctrl_seq");
    super.new(name);
  endfunction

  task body();
    emut_ctrl_item item;
    item = emut_ctrl_item::type_id::create("ctrl_item");
    start_item(item);
    item.cmd = cmd;
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
