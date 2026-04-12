class emut_env extends uvm_env;
  `uvm_component_utils(emut_env)

  uvm_sequencer #(emut_csr_item)    m_csr_seqr;
  uvm_sequencer #(emut_ctrl_item)   m_ctrl_seqr;
  uvm_sequencer #(emut_inject_item) m_inject_seqr;

  emut_csr_driver    m_csr_drv;
  emut_ctrl_driver   m_ctrl_drv;
  emut_inject_driver m_inject_drv;
  emut_tx_monitor    m_tx_mon;
  emut_parser_monitor m_parser_mon;
  emut_scoreboard    m_scb;
  emut_coverage      m_cov;

  emut_cfg           m_cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(emut_cfg)::get(this, "", "cfg", m_cfg))
      m_cfg = emut_cfg::type_id::create("cfg");

    m_csr_seqr   = uvm_sequencer#(emut_csr_item)::type_id::create("m_csr_seqr", this);
    m_ctrl_seqr  = uvm_sequencer#(emut_ctrl_item)::type_id::create("m_ctrl_seqr", this);
    m_inject_seqr = uvm_sequencer#(emut_inject_item)::type_id::create("m_inject_seqr", this);

    m_csr_drv    = emut_csr_driver::type_id::create("m_csr_drv", this);
    m_ctrl_drv   = emut_ctrl_driver::type_id::create("m_ctrl_drv", this);
    m_inject_drv = emut_inject_driver::type_id::create("m_inject_drv", this);
    m_tx_mon     = emut_tx_monitor::type_id::create("m_tx_mon", this);
    m_parser_mon = emut_parser_monitor::type_id::create("m_parser_mon", this);
    m_scb        = emut_scoreboard::type_id::create("m_scb", this);
    m_cov        = emut_coverage::type_id::create("m_cov", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    m_csr_drv.seq_item_port.connect(m_csr_seqr.seq_item_export);
    m_ctrl_drv.seq_item_port.connect(m_ctrl_seqr.seq_item_export);
    m_inject_drv.seq_item_port.connect(m_inject_seqr.seq_item_export);

    m_csr_drv.ap.connect(m_scb.csr_imp);
    m_ctrl_drv.ap.connect(m_scb.ctrl_imp);
    m_inject_drv.ap.connect(m_scb.inject_imp);
    m_tx_mon.ap.connect(m_scb.tx_imp);
    m_parser_mon.ap.connect(m_scb.parser_imp);

    m_csr_drv.ap.connect(m_cov.csr_imp);
    m_ctrl_drv.ap.connect(m_cov.ctrl_imp);
    m_inject_drv.ap.connect(m_cov.inject_imp);
    m_tx_mon.ap.connect(m_cov.tx_imp);
    m_parser_mon.ap.connect(m_cov.parser_imp);
  endfunction
endclass
