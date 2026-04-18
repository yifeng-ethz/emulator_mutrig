class emut_coverage extends uvm_component;
  `uvm_component_utils(emut_coverage)

  localparam int unsigned PAYLOAD_EMPTY       = 0;
  localparam int unsigned PAYLOAD_SINGLE      = 1;
  localparam int unsigned PAYLOAD_MULTI_SMALL = 2;
  localparam int unsigned PAYLOAD_MULTI_LARGE = 3;

  localparam int unsigned INTERVAL_SHORT_OK = 0;
  localparam int unsigned INTERVAL_LONG_OK  = 1;
  localparam int unsigned INTERVAL_BAD      = 2;

  localparam int unsigned LATENCY_SHORT_OK = 0;
  localparam int unsigned LATENCY_LONG_OK  = 1;
  localparam int unsigned LATENCY_BAD      = 2;
  localparam int unsigned LATENCY_MARGIN_CYCLES = 16;

  // Parser-visible trigger latency includes synchronizer capture, hit enqueue,
  // waiting for the next eligible frame window, frame serialization, and the
  // downstream parser handoff. Clean runs can therefore span up to two frame
  // intervals even though the emitted frame cadence itself is fixed.
  localparam int unsigned LATENCY_SHORT_BOUND = (2 * FRAME_INTERVAL_SHORT) + LATENCY_MARGIN_CYCLES;
  localparam int unsigned LATENCY_LONG_BOUND  = (2 * FRAME_INTERVAL_LONG)  + LATENCY_MARGIN_CYCLES;

  uvm_analysis_imp_csr    #(emut_csr_item,          emut_coverage) csr_imp;
  uvm_analysis_imp_ctrl   #(emut_ctrl_item,         emut_coverage) ctrl_imp;
  uvm_analysis_imp_inject #(emut_inject_item,       emut_coverage) inject_imp;
  uvm_analysis_imp_tx     #(emut_tx_frame_item,     emut_coverage) tx_imp;
  uvm_analysis_imp_parser #(emut_parser_frame_item, emut_coverage) parser_imp;

  bit        cfg_enable;
  bit [1:0]  cfg_hit_mode;
  bit        cfg_short_mode;
  bit [2:0]  cfg_tx_mode;
  logic [8:0] prev_ctrl_cmd;
  int unsigned min_short_latency_cycles;
  int unsigned max_short_latency_cycles;
  int unsigned min_long_latency_cycles;
  int unsigned max_long_latency_cycles;

  time inject_time_q[$];
  int unsigned inject_phase_q[$];
  int unsigned inject_width_q[$];
  bit inject_short_mode_q[$];

  function automatic int unsigned classify_payload_kind(input int unsigned event_count);
    if (event_count == 0)
      return PAYLOAD_EMPTY;
    if (event_count == 1)
      return PAYLOAD_SINGLE;
    if (event_count <= 4)
      return PAYLOAD_MULTI_SMALL;
    return PAYLOAD_MULTI_LARGE;
  endfunction

  function automatic int unsigned classify_interval_kind(input int unsigned gap_cycles);
    if (gap_cycles == FRAME_INTERVAL_SHORT)
      return INTERVAL_SHORT_OK;
    if (gap_cycles == FRAME_INTERVAL_LONG)
      return INTERVAL_LONG_OK;
    return INTERVAL_BAD;
  endfunction

  function automatic int unsigned classify_latency_kind(input bit short_mode, input int unsigned latency_cycles);
    if (short_mode) begin
      if (latency_cycles <= LATENCY_SHORT_BOUND)
        return LATENCY_SHORT_OK;
    end else begin
      if (latency_cycles <= LATENCY_LONG_BOUND)
        return LATENCY_LONG_OK;
    end
    return LATENCY_BAD;
  endfunction

  covergroup cg_mode_payload with function sample(
    bit [1:0]  hit_mode,
    bit [2:0]  tx_mode,
    int unsigned payload_kind
  );
    option.per_instance = 1;

    cp_hit_mode : coverpoint hit_mode {
      bins poisson_legacy = {HIT_MODE_POISSON};
      bins burst          = {HIT_MODE_BURST};
      bins poisson_iid    = {HIT_MODE_POISSON_IID};
      bins periodic       = {HIT_MODE_PERIODIC};
    }

    cp_tx_mode : coverpoint tx_mode {
      bins long_tx  = {TX_MODE_LONG};
      bins prbs1    = {TX_MODE_PRBS_1};
      bins prbssat  = {TX_MODE_PRBS_SAT};
      bins short_tx = {TX_MODE_SHORT};
    }

    cp_payload_kind : coverpoint payload_kind {
      bins empty       = {PAYLOAD_EMPTY};
      bins single      = {PAYLOAD_SINGLE};
      bins multi_small = {PAYLOAD_MULTI_SMALL};
      bins multi_large = {PAYLOAD_MULTI_LARGE};
    }

    cx_hit_tx : cross cp_hit_mode, cp_tx_mode;
  endgroup

  covergroup cg_integrity with function sample(int unsigned interval_kind, bit crc_ok);
    option.per_instance = 1;

    cp_interval_kind : coverpoint interval_kind {
      bins short_910 = {INTERVAL_SHORT_OK};
      bins long_1550 = {INTERVAL_LONG_OK};
      ignore_bins unexpected = {INTERVAL_BAD};
    }

    cp_crc_ok : coverpoint crc_ok {
      bins match = {1};
      illegal_bins mismatch = {0};
    }
  endgroup

  covergroup cg_enable with function sample(bit enable_state);
    option.per_instance = 1;

    cp_enable_state : coverpoint enable_state {
      bins disabled = {0};
      bins enabled  = {1};
    }
  endgroup

  covergroup cg_ctrl with function sample(logic [8:0] prev_cmd, logic [8:0] curr_cmd);
    option.per_instance = 1;

    cp_transition : coverpoint {prev_cmd, curr_cmd} {
      bins idle_prepare = {{CTRL_IDLE, CTRL_RUN_PREPARE}};
      bins prepare_sync = {{CTRL_RUN_PREPARE, CTRL_SYNC}};
      bins sync_run     = {{CTRL_SYNC, CTRL_RUNNING}};
      bins run_term     = {{CTRL_RUNNING, CTRL_TERMINATING}};
      bins term_idle    = {{CTRL_TERMINATING, CTRL_IDLE}};
      illegal_bins other = default;
    }
  endgroup

  covergroup cg_inject with function sample(
    int unsigned phase_bin,
    int unsigned width_bin,
    int unsigned latency_kind
  );
    option.per_instance = 1;

    cp_phase : coverpoint phase_bin {
      bins q0 = {0};
      bins q1 = {1};
      bins q2 = {2};
      bins q3 = {3};
    }

    cp_width : coverpoint width_bin {
      bins width_narrow = {0};
      bins width_mid    = {1};
      bins width_wide   = {2};
    }

    cp_latency_kind : coverpoint latency_kind {
      bins short_bounded = {LATENCY_SHORT_OK};
      bins long_bounded  = {LATENCY_LONG_OK};
      ignore_bins out_of_spec = {LATENCY_BAD};
    }

    cx_phase_width : cross cp_phase, cp_width;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cg_mode_payload = new();
    cg_integrity    = new();
    cg_enable       = new();
    cg_ctrl         = new();
    cg_inject       = new();
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    csr_imp    = new("csr_imp", this);
    ctrl_imp   = new("ctrl_imp", this);
    inject_imp = new("inject_imp", this);
    tx_imp     = new("tx_imp", this);
    parser_imp = new("parser_imp", this);

    cfg_enable     = 1'b1;
    cfg_hit_mode   = HIT_MODE_POISSON;
    cfg_short_mode = 1'b0;
    cfg_tx_mode    = TX_MODE_LONG;
    prev_ctrl_cmd  = CTRL_IDLE;
    min_short_latency_cycles = '1;
    max_short_latency_cycles = 0;
    min_long_latency_cycles  = '1;
    max_long_latency_cycles  = 0;

    cg_enable.sample(1'b1);
  endfunction

  function void write_csr(emut_csr_item item);
    if (!item.is_write)
      return;

    case (item.address)
      4'd0: begin
        cfg_enable     = item.writedata[0];
        cfg_hit_mode   = item.writedata[2:1];
        cfg_short_mode = item.writedata[3];
        cg_enable.sample(cfg_enable);
      end
      4'd4: cfg_tx_mode = item.writedata[2:0];
      default: ;
    endcase
  endfunction

  function void write_ctrl(emut_ctrl_item item);
    cg_ctrl.sample(prev_ctrl_cmd, item.cmd);
    prev_ctrl_cmd = item.cmd;
  endfunction

  function void write_inject(emut_inject_item item);
    int unsigned phase_bin;
    int unsigned width_bin;

    phase_bin = (item.phase_ps >= 6000) ? 3 : (item.phase_ps / 2000);
    if (item.width_ps < 8000)
      width_bin = 0;
    else if (item.width_ps < 16000)
      width_bin = 1;
    else
      width_bin = 2;

    inject_time_q.push_back(item.rise_time_ps);
    inject_phase_q.push_back(phase_bin);
    inject_width_q.push_back(width_bin);
    inject_short_mode_q.push_back(cfg_short_mode);
  endfunction

  function void write_tx(emut_tx_frame_item item);
    int unsigned payload_kind;

    payload_kind = classify_payload_kind(item.event_count);
    cg_mode_payload.sample(cfg_hit_mode, item.frame_flags[4:2], payload_kind);

    if (item.header_gap_cycles != 0 && item.frame_count != 0)
      cg_integrity.sample(classify_interval_kind(item.header_gap_cycles), item.crc_ok);
  endfunction

  function void write_parser(emut_parser_frame_item item);
    int unsigned latency_cycles;
    int unsigned latency_kind;

    if (inject_time_q.size() == 0 || item.hit_data.size() == 0 || item.first_hit_time_ps < inject_time_q[0])
      return;

    latency_cycles = (item.first_hit_time_ps - inject_time_q[0]) / CLK_PERIOD_PS;
    latency_kind   = classify_latency_kind(inject_short_mode_q[0], latency_cycles);

    if (inject_short_mode_q[0]) begin
      if (latency_cycles < min_short_latency_cycles)
        min_short_latency_cycles = latency_cycles;
      if (latency_cycles > max_short_latency_cycles)
        max_short_latency_cycles = latency_cycles;
    end else begin
      if (latency_cycles < min_long_latency_cycles)
        min_long_latency_cycles = latency_cycles;
      if (latency_cycles > max_long_latency_cycles)
        max_long_latency_cycles = latency_cycles;
    end

    cg_inject.sample(inject_phase_q[0], inject_width_q[0], latency_kind);

    void'(inject_time_q.pop_front());
    void'(inject_phase_q.pop_front());
    void'(inject_width_q.pop_front());
    void'(inject_short_mode_q.pop_front());
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("EMUT_COV", $sformatf(
      "mode_payload=%.1f%% integrity=%.1f%% enable=%.1f%% ctrl=%.1f%% inject=%.1f%% short_lat=[%0d,%0d] long_lat=[%0d,%0d]",
      cg_mode_payload.get_coverage(), cg_integrity.get_coverage(),
      cg_enable.get_coverage(), cg_ctrl.get_coverage(), cg_inject.get_coverage(),
      (min_short_latency_cycles == '1) ? 0 : min_short_latency_cycles,
      max_short_latency_cycles,
      (min_long_latency_cycles == '1) ? 0 : min_long_latency_cycles,
      max_long_latency_cycles), UVM_LOW)
  endfunction
endclass
