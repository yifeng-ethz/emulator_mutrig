class emut_ctrl_driver extends uvm_driver #(emut_ctrl_item);
  `uvm_component_utils(emut_ctrl_driver)

  virtual emut_ctrl_if.drv vif;
  uvm_analysis_port #(emut_ctrl_item) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db#(virtual emut_ctrl_if.drv)::get(this, "", "vif", vif))
      `uvm_fatal("EMUT_CTRL_DRV", "Missing emut_ctrl_if.drv")
  endfunction

  task run_phase(uvm_phase phase);
    emut_ctrl_item item;

    vif.data  <= CTRL_IDLE;
    vif.valid <= 1'b0;

    forever begin
      seq_item_port.get_next_item(item);
      @(posedge vif.clk);
      vif.data  <= item.cmd;
      vif.valid <= 1'b1;
      do begin
        @(posedge vif.clk);
      end while (vif.ready !== 1'b1);
      item.drive_time_ps = $time;
      vif.valid <= 1'b0;
      vif.data  <= CTRL_IDLE;
      repeat (item.post_accept_delay_cycles)
        @(posedge vif.clk);
      ap.write(item);
      seq_item_port.item_done();
    end
  endtask
endclass
