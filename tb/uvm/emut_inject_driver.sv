class emut_inject_driver extends uvm_driver #(emut_inject_item);
  `uvm_component_utils(emut_inject_driver)

  virtual emut_inject_if.drv vif;
  uvm_analysis_port #(emut_inject_item) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db#(virtual emut_inject_if.drv)::get(this, "", "vif", vif))
      `uvm_fatal("EMUT_INJ_DRV", "Missing emut_inject_if.drv")
  endfunction

  task run_phase(uvm_phase phase);
    emut_inject_item item;

    vif.pulse <= 1'b0;
    forever begin
      seq_item_port.get_next_item(item);
      repeat (item.start_delay_cycles)
        @(posedge vif.clk);
      #(item.phase_ps * 1ps);
      vif.pulse        <= 1'b1;
      item.rise_time_ps = $time;
      #(item.width_ps * 1ps);
      vif.pulse        <= 1'b0;
      item.fall_time_ps = $time;
      ap.write(item);
      seq_item_port.item_done();
    end
  endtask
endclass
