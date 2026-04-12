class emut_csr_driver extends uvm_driver #(emut_csr_item);
  `uvm_component_utils(emut_csr_driver)

  virtual emut_avmm_csr_if.drv vif;
  uvm_analysis_port #(emut_csr_item) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db#(virtual emut_avmm_csr_if.drv)::get(this, "", "vif", vif))
      `uvm_fatal("EMUT_CSR_DRV", "Missing emut_avmm_csr_if.drv")
  endfunction

  task run_phase(uvm_phase phase);
    emut_csr_item item;

    vif.address   <= '0;
    vif.read      <= 1'b0;
    vif.write     <= 1'b0;
    vif.writedata <= '0;

    forever begin
      seq_item_port.get_next_item(item);
      if (item.is_write)
        drive_write(item);
      else
        drive_read(item);
      item.complete_time_ps = $time;
      ap.write(item);
      seq_item_port.item_done();
    end
  endtask

  task automatic drive_write(emut_csr_item item);
    @(posedge vif.clk);
    vif.address   <= item.address;
    vif.writedata <= item.writedata;
    vif.write     <= 1'b1;
    vif.read      <= 1'b0;
    @(posedge vif.clk);
    while (vif.waitrequest === 1'b1)
      @(posedge vif.clk);
    vif.write     <= 1'b0;
    vif.address   <= '0;
    vif.writedata <= '0;
  endtask

  task automatic drive_read(emut_csr_item item);
    @(posedge vif.clk);
    vif.address <= item.address;
    vif.read    <= 1'b1;
    vif.write   <= 1'b0;
    @(posedge vif.clk);
    while (vif.waitrequest === 1'b1)
      @(posedge vif.clk);
    #1step;
    item.readdata = vif.readdata;
    vif.read      <= 1'b0;
    vif.address   <= '0;
  endtask
endclass
