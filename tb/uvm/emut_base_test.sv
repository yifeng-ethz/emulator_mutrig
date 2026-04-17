class emut_base_test extends uvm_test;
  `uvm_component_utils(emut_base_test)

  emut_env m_env;
  emut_cfg m_cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    m_cfg = emut_cfg::type_id::create("cfg");
    uvm_config_db#(emut_cfg)::set(this, "m_env", "cfg", m_cfg);
    m_env = emut_env::type_id::create("m_env", this);
  endfunction

  task automatic wait_clocks(int unsigned cycles);
    repeat (cycles)
      @(posedge m_env.m_csr_drv.vif.clk);
  endtask

  task automatic wait_for_reset_release();
    do begin
      @(posedge m_env.m_csr_drv.vif.clk);
    end while (m_env.m_csr_drv.vif.rst === 1'b1);
    wait_clocks(2);
  endtask

  task automatic csr_write(bit [3:0] addr, bit [31:0] data);
    emut_csr_write_seq seq;
    seq = emut_csr_write_seq::type_id::create($sformatf("csr_wr_%0d", addr));
    seq.addr = addr;
    seq.data = data;
    seq.start(m_env.m_csr_seqr);
  endtask

  task automatic csr_read(bit [3:0] addr, output bit [31:0] data);
    emut_csr_read_seq seq;
    seq = emut_csr_read_seq::type_id::create($sformatf("csr_rd_%0d", addr));
    seq.addr = addr;
    seq.start(m_env.m_csr_seqr);
    data = seq.data;
  endtask

  task automatic ctrl_send(logic [8:0] cmd);
    emut_ctrl_seq seq;
    seq = emut_ctrl_seq::type_id::create($sformatf("ctrl_%0h", cmd));
    seq.cmd = cmd;
    seq.start(m_env.m_ctrl_seqr);
  endtask

  task automatic ctrl_send_with_delay(logic [8:0] cmd, int unsigned delay_cycles, string state_name);
    emut_ctrl_seq seq;
    seq = emut_ctrl_seq::type_id::create($sformatf("ctrl_%s", state_name));
    seq.cmd = cmd;
    seq.post_accept_delay_cycles = delay_cycles;
    seq.state_name = state_name;
    seq.start(m_env.m_ctrl_seqr);
  endtask

  task automatic inject_pulse(int unsigned delay_cycles = 0, int unsigned phase_ps = 0, int unsigned width_ps = 12000);
    emut_inject_seq seq;
    seq = emut_inject_seq::type_id::create("inject_seq");
    seq.start_delay_cycles = delay_cycles;
    seq.phase_ps           = phase_ps;
    seq.width_ps           = width_ps;
    seq.start(m_env.m_inject_seqr);
  endtask

  task automatic csr_expect_eq(bit [3:0] addr, bit [31:0] expected, string what);
    bit [31:0] data;
    csr_read(addr, data);
    if (data !== expected)
      `uvm_error("EMUT_CSR_CHK", $sformatf("%s mismatch got=0x%08x expected=0x%08x", what, data, expected))
  endtask

  task automatic start_run();
    emut_run_start_seq seq;
    seq = emut_run_start_seq::type_id::create("run_start_seq");
    seq.run_prepare_cycles = m_cfg.run_prepare_cycles;
    seq.sync_cycles = m_cfg.sync_cycles;
    seq.running_settle_cycles = m_cfg.running_settle_cycles;
    seq.start(m_env.m_ctrl_seqr);
  endtask

  task automatic stop_run();
    emut_run_stop_seq seq;
    seq = emut_run_stop_seq::type_id::create("run_stop_quick_seq");
    seq.terminating_hold_cycles = m_cfg.quick_terminating_hold_cycles;
    seq.idle_recovery_cycles = m_cfg.idle_recovery_cycles;
    seq.start(m_env.m_ctrl_seqr);
  endtask

  task automatic stop_run_system();
    emut_run_stop_seq seq;
    seq = emut_run_stop_seq::type_id::create("run_stop_system_seq");
    seq.terminating_hold_cycles = m_cfg.system_terminating_hold_cycles;
    seq.idle_recovery_cycles = m_cfg.idle_recovery_cycles;
    seq.start(m_env.m_ctrl_seqr);
  endtask

  task automatic wait_for_tx_frames(int unsigned min_frames, int unsigned timeout_cycles = 200000);
    int unsigned waited;
    waited = 0;
    while (m_env.m_tx_mon.frame_count_seen < min_frames && waited < timeout_cycles) begin
      wait_clocks(1);
      waited++;
    end
    if (m_env.m_tx_mon.frame_count_seen < min_frames)
      `uvm_fatal("EMUT_WAIT", $sformatf("Timed out waiting for %0d tx frames (have %0d)",
        min_frames, m_env.m_tx_mon.frame_count_seen))
  endtask

  task automatic wait_for_parser_nonempty_frames(int unsigned min_frames, int unsigned timeout_cycles = 200000);
    int unsigned waited;
    waited = 0;
    while (m_env.m_parser_mon.nonempty_frame_count_seen < min_frames && waited < timeout_cycles) begin
      wait_clocks(1);
      waited++;
    end
    if (m_env.m_parser_mon.nonempty_frame_count_seen < min_frames)
      `uvm_fatal("EMUT_WAIT", $sformatf("Timed out waiting for %0d non-empty parser frames (have %0d)",
        min_frames, m_env.m_parser_mon.nonempty_frame_count_seen))
  endtask

  task automatic program_common_cfg(
    bit [1:0]  hit_mode,
    bit        short_mode,
    bit [15:0] hit_rate,
    bit [15:0] noise_rate,
    bit [4:0]  burst_size,
    bit [4:0]  burst_center,
    bit [31:0] seed,
    bit [2:0]  tx_mode,
    bit        gen_idle,
    bit [3:0]  asic_id
  );
    bit [31:0] ctrl_reg;
    bit [31:0] burst_reg;
    bit [31:0] tx_reg;

    ctrl_reg  = {28'b0, short_mode, hit_mode, 1'b1};
    burst_reg = {19'b0, burst_center, 3'b0, burst_size};
    tx_reg    = {25'b0, asic_id[2:0], gen_idle, tx_mode};

    csr_write(4'd0, ctrl_reg);
    csr_write(4'd1, {noise_rate, hit_rate});
    csr_write(4'd2, burst_reg);
    csr_write(4'd3, seed);
    csr_write(4'd4, tx_reg);
  endtask

  function void report_phase(uvm_phase phase);
    uvm_report_server srv;
    srv = uvm_report_server::get_server();
    if (srv.get_severity_count(UVM_ERROR) > 0 || srv.get_severity_count(UVM_FATAL) > 0)
      `uvm_info("EMUT_TEST", "*** TEST FAILED ***", UVM_NONE)
    else
      `uvm_info("EMUT_TEST", "*** TEST PASSED ***", UVM_NONE)
  endfunction
endclass

class emut_test_reset_defaults extends emut_base_test;
  `uvm_component_utils(emut_test_reset_defaults)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    wait_for_reset_release();

    csr_expect_eq(4'd0, 32'h0000_0001, "CSR0 default");
    csr_expect_eq(4'd1, 32'h0100_0800, "CSR1 default");
    csr_expect_eq(4'd2, 32'h0404_1004, "CSR2 default");
    csr_expect_eq(4'd3, 32'hDEAD_BEEF, "CSR3 default");
    csr_expect_eq(4'd4, 32'h0000_0008, "CSR4 default");

    wait_clocks(40);
    if (m_env.m_tx_mon.frame_count_seen != 0)
      `uvm_error("EMUT_RST", $sformatf("Expected no frames before RUNNING, saw %0d", m_env.m_tx_mon.frame_count_seen))

    phase.drop_objection(this);
  endtask
endclass

class emut_test_idle_and_runctl extends emut_base_test;
  `uvm_component_utils(emut_test_idle_and_runctl)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    int unsigned frames_before_stop;
    phase.raise_objection(this);
    wait_for_reset_release();
    program_common_cfg(2'b00, 1'b0, 16'h0800, 16'h0000, 5'd1, 5'd10, 32'h1234_5678, TX_MODE_LONG, 1'b1, 4'd1);
    start_run();
    wait_for_tx_frames(2);
    frames_before_stop = m_env.m_tx_mon.frame_count_seen;
    stop_run();
    wait_clocks(64);
    if (m_env.m_tx_mon.frame_count_seen != frames_before_stop)
      `uvm_error("EMUT_RUNCTL", "Frame count changed after stop sequence")
    phase.drop_objection(this);
  endtask
endclass

class emut_test_long_inject_single extends emut_base_test;
  `uvm_component_utils(emut_test_long_inject_single)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    wait_for_reset_release();
    program_common_cfg(2'b00, 1'b0, 16'h0000, 16'h0000, 5'd1, 5'd7, 32'hCAFE_BABE, TX_MODE_LONG, 1'b1, 4'd4);
    start_run();
    wait_clocks(16);
    inject_pulse(0, 1000, 16000);
    wait_for_parser_nonempty_frames(1);
    stop_run();
    if (m_env.m_parser_mon.last_frame.frame_len != 1)
      `uvm_error("EMUT_LONG_INJ", $sformatf("Expected single-hit long parser frame, got %0d hits",
        m_env.m_parser_mon.last_frame.frame_len))
    phase.drop_objection(this);
  endtask
endclass

class emut_test_short_inject_single extends emut_base_test;
  `uvm_component_utils(emut_test_short_inject_single)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    wait_for_reset_release();
    program_common_cfg(2'b00, 1'b1, 16'h0000, 16'h0000, 5'd1, 5'd8, 32'h1357_2468, TX_MODE_SHORT, 1'b1, 4'd5);
    start_run();
    wait_clocks(16);
    inject_pulse(0, 3000, 16000);
    wait_for_parser_nonempty_frames(1);
    stop_run();
    if (m_env.m_parser_mon.last_frame.frame_len != 1)
      `uvm_error("EMUT_SHORT_INJ", $sformatf("Expected single-hit short parser frame, got %0d hits",
        m_env.m_parser_mon.last_frame.frame_len))
    if (m_env.m_parser_mon.last_frame.hit_data.size() > 0 &&
        m_env.m_parser_mon.last_frame.hit_data[0][15:1] != 15'd0)
      `uvm_error("EMUT_SHORT_INJ", "Short frame hit carried non-zero E_CC")
    phase.drop_objection(this);
  endtask
endclass

class emut_test_long_burst_mode extends emut_base_test;
  `uvm_component_utils(emut_test_long_burst_mode)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    wait_for_reset_release();
    program_common_cfg(2'b01, 1'b0, 16'h0000, 16'h0000, 5'd4, 5'd12, 32'h2468_1357, TX_MODE_LONG, 1'b1, 4'd2);
    start_run();
    wait_for_parser_nonempty_frames(2, 400000);
    stop_run();
    if (m_env.m_parser_mon.max_frame_len_seen < 4)
      `uvm_error("EMUT_BURST_LONG", $sformatf("Expected multi-hit long burst frame, max len=%0d",
        m_env.m_parser_mon.max_frame_len_seen))
    phase.drop_objection(this);
  endtask
endclass

class emut_test_short_burst_mode extends emut_base_test;
  `uvm_component_utils(emut_test_short_burst_mode)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    wait_for_reset_release();
    program_common_cfg(2'b01, 1'b1, 16'h0000, 16'h0000, 5'd3, 5'd20, 32'h89AB_CDEF, TX_MODE_SHORT, 1'b1, 4'd6);
    start_run();
    wait_clocks(12);
    inject_pulse(0, 5000, 16000);
    wait_for_parser_nonempty_frames(1, 400000);
    stop_run();
    if (m_env.m_parser_mon.max_frame_len_seen < 3)
      `uvm_error("EMUT_BURST_SHORT", $sformatf("Expected packed short burst frame, max len=%0d",
        m_env.m_parser_mon.max_frame_len_seen))
    phase.drop_objection(this);
  endtask
endclass

class emut_test_noise_mode extends emut_base_test;
  `uvm_component_utils(emut_test_noise_mode)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    wait_for_reset_release();
    program_common_cfg(2'b10, 1'b0, 16'h0000, 16'h3000, 5'd2, 5'd5, 32'h0BAD_C0DE, TX_MODE_LONG, 1'b1, 4'd7);
    start_run();
    wait_for_parser_nonempty_frames(2, 400000);
    stop_run();
    if (m_env.m_parser_mon.max_frame_len_seen == 0)
      `uvm_error("EMUT_NOISE", "Noise mode never produced a non-empty frame")
    phase.drop_objection(this);
  endtask
endclass

class emut_test_mixed_random extends emut_base_test;
  `uvm_component_utils(emut_test_mixed_random)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    bit [1:0]  hit_mode;
    bit        short_mode;
    bit [4:0]  burst_size;
    bit [4:0]  burst_center;
    bit [15:0] hit_rate;
    bit [15:0] noise_rate;
    bit [2:0]  tx_mode;
    bit [3:0]  asic_id;
    int unsigned scenario;
    int unsigned tx_base;
    int unsigned parser_nonempty_base;

    phase.raise_objection(this);
    wait_for_reset_release();

    for (int iter = 0; iter < 12; iter++) begin
      scenario     = $urandom_range(0, 5);
      asic_id      = {1'b0, iter[2:0]};
      burst_center = 5'($urandom_range(4, 27));

      case (scenario)
        0: begin
          hit_mode   = 2'b00;
          short_mode = 1'b0;
          burst_size = 5'd1;
          hit_rate   = 16'h0000;
          noise_rate = 16'h0000;
          tx_mode    = TX_MODE_LONG;
        end
        1: begin
          hit_mode   = 2'b00;
          short_mode = 1'b1;
          burst_size = 5'd1;
          hit_rate   = 16'h0000;
          noise_rate = 16'h0000;
          tx_mode    = TX_MODE_SHORT;
        end
        2: begin
          hit_mode   = 2'b01;
          short_mode = 1'b0;
          burst_size = 5'($urandom_range(2, 3));
          hit_rate   = 16'h0000;
          noise_rate = 16'h0000;
          tx_mode    = TX_MODE_LONG;
        end
        3: begin
          hit_mode   = 2'b01;
          short_mode = 1'b1;
          burst_size = 5'($urandom_range(2, 3));
          hit_rate   = 16'h0000;
          noise_rate = 16'h0000;
          tx_mode    = TX_MODE_SHORT;
        end
        4: begin
          hit_mode   = 2'b10;
          short_mode = 1'b0;
          burst_size = 5'd2;
          hit_rate   = 16'h0000;
          noise_rate = 16'($urandom_range(16'h0008, 16'h0040));
          tx_mode    = TX_MODE_LONG;
        end
        default: begin
          hit_mode   = 2'b11;
          short_mode = 1'b0;
          burst_size = 5'd2;
          hit_rate   = 16'($urandom_range(16'h0008, 16'h0040));
          noise_rate = 16'h0000;
          tx_mode    = TX_MODE_LONG;
        end
      endcase

      `uvm_info("EMUT_MIXED_CFG", $sformatf(
        "iter=%0d scenario=%0d hit_mode=%0d short=%0d burst_size=%0d burst_center=%0d hit_rate=0x%04x noise_rate=0x%04x tx_mode=0x%0h asic_id=%0d",
        iter, scenario, hit_mode, short_mode, burst_size, burst_center, hit_rate, noise_rate, tx_mode, asic_id), UVM_LOW)

      program_common_cfg(hit_mode, short_mode, hit_rate, noise_rate, burst_size, burst_center,
        $urandom, tx_mode, 1'b1, asic_id);
      tx_base             = m_env.m_tx_mon.frame_count_seen;
      parser_nonempty_base = m_env.m_parser_mon.nonempty_frame_count_seen;

      start_run();
      wait_clocks(8);

      if (scenario inside {0, 1, 3}) begin
        inject_pulse(0, $urandom_range(0, 7999), $urandom_range(9000, 20000));
        while (m_env.m_parser_mon.nonempty_frame_count_seen < parser_nonempty_base + 1)
          wait_clocks(1);
      end else begin
        while (m_env.m_tx_mon.frame_count_seen < tx_base + 2)
          wait_clocks(1);
      end

      stop_run();
      wait_clocks(24);
    end

    if (m_env.m_tx_mon.frame_count_seen < 4)
      `uvm_error("EMUT_MIXED", $sformatf("Expected multiple frames in random test, saw %0d",
        m_env.m_tx_mon.frame_count_seen))
    phase.drop_objection(this);
  endtask
endclass

class emut_test_disable_and_status extends emut_base_test;
  `uvm_component_utils(emut_test_disable_and_status)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    wait_for_reset_release();

    csr_expect_eq(4'd5, 32'h0000_0000, "CSR5 status default");
    csr_expect_eq(4'd6, 32'h0000_0000, "CSR6 default");

    program_common_cfg(HIT_MODE_NOISE, 1'b0, 16'hF800, 16'hC000, 5'd31, 5'd31,
      32'h55AA_33CC, TX_MODE_PRBS_SAT, 1'b0, 4'hF);
    csr_write(4'd6, 32'hFFFF_FFFF);
    csr_write(4'd0, 32'h0000_0004); // disable + noise + long

    start_run();
    wait_clocks(64);
    if (m_env.m_tx_mon.frame_count_seen != 0)
      `uvm_error("EMUT_DISABLE", $sformatf("Expected no frames while disabled, saw %0d",
        m_env.m_tx_mon.frame_count_seen))
    stop_run();

    csr_expect_eq(4'd5, 32'h0000_0000, "CSR5 status disabled");
    csr_expect_eq(4'd6, 32'h0000_0000, "CSR6 default after invalid write");
    phase.drop_objection(this);
  endtask
endclass

class emut_test_high_rate_fill extends emut_base_test;
  `uvm_component_utils(emut_test_high_rate_fill)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    wait_for_reset_release();

    program_common_cfg(HIT_MODE_POISSON, 1'b0, 16'hFFFF, 16'h0000, 5'd8, 5'd4,
      32'hFACE_0FF0, TX_MODE_LONG, 1'b1, 4'd12);
    start_run();
    wait_for_tx_frames(3, 500000);
    stop_run();

    if (m_env.m_tx_mon.max_event_count_seen < 10'd32)
      `uvm_error("EMUT_FILL", $sformatf("Expected high-rate fill to exceed 31 events, saw %0d",
        m_env.m_tx_mon.max_event_count_seen))
    phase.drop_objection(this);
  endtask
endclass

class emut_test_mode_payload_sweep extends emut_base_test;
  `uvm_component_utils(emut_test_mode_payload_sweep)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task automatic run_profile(
    input bit [1:0] hit_mode,
    input bit [2:0] tx_mode,
    input bit       short_mode,
    input bit [4:0] burst_size,
    input bit [4:0] burst_center,
    input bit       gen_idle,
    input bit       do_inject,
    input bit       do_second_inject,
    input bit [3:0] asic_id,
    input int unsigned expect_min_hits,
    input int unsigned expect_max_hits
  );
    int unsigned tx_base;
    int unsigned parser_base;

    program_common_cfg(hit_mode, short_mode, 16'h0000, 16'h0000, burst_size, burst_center,
      $urandom, tx_mode, gen_idle, asic_id);
    tx_base     = m_env.m_tx_mon.frame_count_seen;
    parser_base = m_env.m_parser_mon.nonempty_frame_count_seen;

    start_run();
    wait_clocks(8);

    if (do_inject) begin
      inject_pulse(0, 2000 + (asic_id % 4) * 1200, 10000);
      if (do_second_inject)
        inject_pulse(1, 500, 3000);
      wait_for_parser_nonempty_frames(parser_base + 1, 400000);
    end else begin
      wait_for_tx_frames(tx_base + 2, 400000);
    end

    stop_run();
    wait_clocks(16);

    if (m_env.m_tx_mon.last_frame.frame_flags[4:2] != tx_mode)
      `uvm_error("EMUT_SWEEP", $sformatf("Frame flags tx_mode mismatch exp=0x%0h got=0x%0h",
        tx_mode, m_env.m_tx_mon.last_frame.frame_flags[4:2]))
  endtask

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    wait_for_reset_release();

    for (int unsigned hm = 0; hm < 4; hm++) begin
      bit [1:0] hit_mode_sel;
      bit [3:0] asic_base;
      hit_mode_sel = hm[1:0];
      asic_base    = hm[3:0];

      run_profile(hit_mode_sel, TX_MODE_LONG,     1'b0, 5'd1, 5'd6, 1'b1, 1'b0, 1'b0, asic_base,        0, 0);
      run_profile(hit_mode_sel, TX_MODE_SHORT,    1'b1, 5'd1, 5'd5, 1'b1, 1'b1, 1'b0, asic_base + 4'd4, 1, 1);
      run_profile(hit_mode_sel, TX_MODE_PRBS_1,   1'b0, 5'd3, 5'd5, 1'b1, 1'b1, 1'b0, asic_base + 4'd8, 2, 4);
      run_profile(hit_mode_sel, TX_MODE_PRBS_SAT, 1'b0, 5'd8, 5'd1, 1'b0, 1'b1, 1'b1, asic_base + 4'd12, 5, 31);
    end

    phase.drop_objection(this);
  endtask
endclass

class emut_test_inject_matrix extends emut_base_test;
  `uvm_component_utils(emut_test_inject_matrix)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    int unsigned phase_tbl[4];
    int unsigned width_tbl[3];
    bit          short_mode;
    bit [2:0]    tx_mode;
    int unsigned parser_base;

    phase_tbl[0] = 500;
    phase_tbl[1] = 2500;
    phase_tbl[2] = 4500;
    phase_tbl[3] = 6500;
    width_tbl[0] = 7800;
    width_tbl[1] = 10000;
    width_tbl[2] = 18000;

    phase.raise_objection(this);
    wait_for_reset_release();

    for (int unsigned p = 0; p < 4; p++) begin
      for (int unsigned w = 0; w < 3; w++) begin
        bit [3:0] asic_id;
        short_mode = (p + w) & 1;
        tx_mode    = short_mode ? TX_MODE_SHORT : TX_MODE_LONG;
        asic_id    = (p * 3 + w) & 7;

        program_common_cfg(HIT_MODE_POISSON, short_mode, 16'h0000, 16'h0000, 5'd1, 5'd7,
          $urandom, tx_mode, 1'b1, asic_id);
        parser_base = m_env.m_parser_mon.nonempty_frame_count_seen;

        start_run();
        wait_clocks(8);
        inject_pulse(0, phase_tbl[p], width_tbl[w]);
        wait_for_parser_nonempty_frames(parser_base + 1, 400000);
        stop_run();
        wait_clocks(16);
      end
    end

    phase.drop_objection(this);
  endtask
endclass

class emut_test_short_pack_extra_tail extends emut_base_test;
  `uvm_component_utils(emut_test_short_pack_extra_tail)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    int unsigned tx_base;
    int unsigned parser_base;

    phase.raise_objection(this);
    wait_for_reset_release();

    program_common_cfg(HIT_MODE_POISSON, 1'b1, 16'h0000, 16'h0000, 5'd3, 5'd11,
      32'h3141_5926, TX_MODE_SHORT, 1'b1, 4'd9);
    start_run();

    tx_base = m_env.m_tx_mon.frame_count_seen;
    wait_for_tx_frames(tx_base + 1, 400000);
    wait_clocks(8);

    parser_base = m_env.m_parser_mon.nonempty_frame_count_seen;
    inject_pulse(0, 1200, 12000);
    wait_for_parser_nonempty_frames(parser_base + 1, 400000);
    stop_run();

    if (m_env.m_parser_mon.last_frame.frame_len != 3)
      `uvm_error("EMUT_PACK3", $sformatf("Expected 3-hit short packed frame, got %0d hits",
        m_env.m_parser_mon.last_frame.frame_len))

    phase.drop_objection(this);
  endtask
endclass

class emut_test_auto_low_center extends emut_base_test;
  `uvm_component_utils(emut_test_auto_low_center)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    int unsigned parser_base;

    phase.raise_objection(this);
    wait_for_reset_release();

    program_common_cfg(HIT_MODE_BURST, 1'b0, 16'h0000, 16'h0000, 5'd8, 5'd1,
      32'h0F0F_A5A5, TX_MODE_LONG, 1'b1, 4'd2);
    parser_base = m_env.m_parser_mon.nonempty_frame_count_seen;
    start_run();
    wait_for_parser_nonempty_frames(parser_base + 1, 400000);
    stop_run();

    program_common_cfg(HIT_MODE_MIXED, 1'b0, 16'h0000, 16'h0000, 5'd8, 5'd1,
      32'h1234_AA55, TX_MODE_LONG, 1'b1, 4'd3);
    parser_base = m_env.m_parser_mon.nonempty_frame_count_seen;
    start_run();
    wait_for_parser_nonempty_frames(parser_base + 1, 400000);
    stop_run();

    phase.drop_objection(this);
  endtask
endclass

class emut_test_terminate_no_new_frame extends emut_base_test;
  `uvm_component_utils(emut_test_terminate_no_new_frame)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    int unsigned frames_before_stop;
    phase.raise_objection(this);
    wait_for_reset_release();

    program_common_cfg(HIT_MODE_POISSON, 1'b0, 16'h0000, 16'h0000, 5'd31, 5'd16,
      32'hC001_D00D, TX_MODE_LONG, 1'b1, 4'd10);
    start_run();
    wait_for_tx_frames(1, 600000);
    frames_before_stop = m_env.m_tx_mon.frame_count_seen;
    inject_pulse(0, 1000, 16000);
    wait_clocks(8);
    stop_run_system();

    if (m_env.m_tx_mon.frame_count_seen != frames_before_stop)
      `uvm_error("EMUT_TERM", $sformatf(
        "Observed %0d new frame(s) during TERMINATING hold (before=%0d after=%0d)",
        m_env.m_tx_mon.frame_count_seen - frames_before_stop,
        frames_before_stop,
        m_env.m_tx_mon.frame_count_seen))

    phase.drop_objection(this);
  endtask
endclass

class emut_frame_suite_base extends emut_base_test;
  `uvm_component_utils(emut_frame_suite_base)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task automatic log_case(string case_id);
    `uvm_info("EMUT_FRAME_CASE", $sformatf("Running continuous-frame case %s", case_id), UVM_LOW)
  endtask

  task automatic frame_case_idle_and_runctl();
    int unsigned frames_base;
    int unsigned frames_before_stop;

    log_case("emut_test_idle_and_runctl");
    program_common_cfg(2'b00, 1'b0, 16'h0800, 16'h0000, 5'd1, 5'd10, 32'h1234_5678, TX_MODE_LONG, 1'b1, 4'd1);
    frames_base = m_env.m_tx_mon.frame_count_seen;
    start_run();
    wait_for_tx_frames(frames_base + 2);
    frames_before_stop = m_env.m_tx_mon.frame_count_seen;
    stop_run();
    wait_clocks(64);
    if (m_env.m_tx_mon.frame_count_seen != frames_before_stop)
      `uvm_error("EMUT_RUNCTL", "Frame count changed after stop sequence")
  endtask

  task automatic frame_case_long_inject_single();
    int unsigned parser_base;

    log_case("emut_test_long_inject_single");
    program_common_cfg(2'b00, 1'b0, 16'h0000, 16'h0000, 5'd1, 5'd7, 32'hCAFE_BABE, TX_MODE_LONG, 1'b1, 4'd4);
    parser_base = m_env.m_parser_mon.nonempty_frame_count_seen;
    start_run();
    wait_clocks(16);
    inject_pulse(0, 1000, 16000);
    wait_for_parser_nonempty_frames(parser_base + 1);
    stop_run();
    if (m_env.m_parser_mon.last_frame.frame_len != 1)
      `uvm_error("EMUT_LONG_INJ", $sformatf("Expected single-hit long parser frame, got %0d hits",
        m_env.m_parser_mon.last_frame.frame_len))
    wait_clocks(16);
  endtask

  task automatic frame_case_short_inject_single();
    int unsigned parser_base;

    log_case("emut_test_short_inject_single");
    program_common_cfg(2'b00, 1'b1, 16'h0000, 16'h0000, 5'd1, 5'd8, 32'h1357_2468, TX_MODE_SHORT, 1'b1, 4'd5);
    parser_base = m_env.m_parser_mon.nonempty_frame_count_seen;
    start_run();
    wait_clocks(16);
    inject_pulse(0, 3000, 16000);
    wait_for_parser_nonempty_frames(parser_base + 1);
    stop_run();
    if (m_env.m_parser_mon.last_frame.frame_len != 1)
      `uvm_error("EMUT_SHORT_INJ", $sformatf("Expected single-hit short parser frame, got %0d hits",
        m_env.m_parser_mon.last_frame.frame_len))
    if (m_env.m_parser_mon.last_frame.hit_data.size() > 0 &&
        m_env.m_parser_mon.last_frame.hit_data[0][15:1] != 15'd0)
      `uvm_error("EMUT_SHORT_INJ", "Short frame hit carried non-zero E_CC")
    wait_clocks(16);
  endtask

  task automatic frame_case_long_burst_mode();
    int unsigned parser_base;

    log_case("emut_test_long_burst_mode");
    program_common_cfg(2'b01, 1'b0, 16'h0000, 16'h0000, 5'd4, 5'd12, 32'h2468_1357, TX_MODE_LONG, 1'b1, 4'd2);
    parser_base = m_env.m_parser_mon.nonempty_frame_count_seen;
    start_run();
    wait_for_parser_nonempty_frames(parser_base + 2, 400000);
    stop_run();
    if (m_env.m_parser_mon.max_frame_len_seen < 4)
      `uvm_error("EMUT_BURST_LONG", $sformatf("Expected multi-hit long burst frame, max len=%0d",
        m_env.m_parser_mon.max_frame_len_seen))
    wait_clocks(16);
  endtask

  task automatic frame_case_short_burst_mode();
    int unsigned parser_base;

    log_case("emut_test_short_burst_mode");
    program_common_cfg(2'b01, 1'b1, 16'h0000, 16'h0000, 5'd3, 5'd20, 32'h89AB_CDEF, TX_MODE_SHORT, 1'b1, 4'd6);
    parser_base = m_env.m_parser_mon.nonempty_frame_count_seen;
    start_run();
    wait_clocks(12);
    inject_pulse(0, 5000, 16000);
    wait_for_parser_nonempty_frames(parser_base + 1, 400000);
    stop_run();
    if (m_env.m_parser_mon.max_frame_len_seen < 3)
      `uvm_error("EMUT_BURST_SHORT", $sformatf("Expected packed short burst frame, max len=%0d",
        m_env.m_parser_mon.max_frame_len_seen))
    wait_clocks(16);
  endtask

  task automatic frame_case_noise_mode();
    int unsigned parser_base;

    log_case("emut_test_noise_mode");
    program_common_cfg(2'b10, 1'b0, 16'h0000, 16'h3000, 5'd2, 5'd5, 32'h0BAD_C0DE, TX_MODE_LONG, 1'b1, 4'd7);
    parser_base = m_env.m_parser_mon.nonempty_frame_count_seen;
    start_run();
    wait_for_parser_nonempty_frames(parser_base + 2, 400000);
    stop_run();
    if (m_env.m_parser_mon.max_frame_len_seen == 0)
      `uvm_error("EMUT_NOISE", "Noise mode never produced a non-empty frame")
    wait_clocks(16);
  endtask

  task automatic frame_case_short_pack_extra_tail();
    int unsigned tx_base;
    int unsigned parser_base;

    log_case("emut_test_short_pack_extra_tail");
    program_common_cfg(HIT_MODE_POISSON, 1'b1, 16'h0000, 16'h0000, 5'd3, 5'd11,
      32'h3141_5926, TX_MODE_SHORT, 1'b1, 4'd9);
    start_run();

    tx_base = m_env.m_tx_mon.frame_count_seen;
    wait_for_tx_frames(tx_base + 1, 400000);
    wait_clocks(8);

    parser_base = m_env.m_parser_mon.nonempty_frame_count_seen;
    inject_pulse(0, 1200, 12000);
    wait_for_parser_nonempty_frames(parser_base + 1, 400000);
    stop_run();

    if (m_env.m_parser_mon.last_frame.frame_len != 3)
      `uvm_error("EMUT_PACK3", $sformatf("Expected 3-hit short packed frame, got %0d hits",
        m_env.m_parser_mon.last_frame.frame_len))

    wait_clocks(16);
  endtask

  task automatic frame_case_auto_low_center();
    int unsigned parser_base;

    log_case("emut_test_auto_low_center");
    program_common_cfg(HIT_MODE_BURST, 1'b0, 16'h0000, 16'h0000, 5'd8, 5'd1,
      32'h0F0F_A5A5, TX_MODE_LONG, 1'b1, 4'd2);
    parser_base = m_env.m_parser_mon.nonempty_frame_count_seen;
    start_run();
    wait_for_parser_nonempty_frames(parser_base + 1, 400000);
    stop_run();

    program_common_cfg(HIT_MODE_MIXED, 1'b0, 16'h0000, 16'h0000, 5'd8, 5'd1,
      32'h1234_AA55, TX_MODE_LONG, 1'b1, 4'd3);
    parser_base = m_env.m_parser_mon.nonempty_frame_count_seen;
    start_run();
    wait_for_parser_nonempty_frames(parser_base + 1, 400000);
    stop_run();
    wait_clocks(16);
  endtask

  task automatic frame_case_terminate_no_new_frame();
    int unsigned frames_before_stop;
    int unsigned frames_base;

    log_case("emut_test_terminate_no_new_frame");
    program_common_cfg(HIT_MODE_POISSON, 1'b0, 16'h0000, 16'h0000, 5'd31, 5'd16,
      32'hC001_D00D, TX_MODE_LONG, 1'b1, 4'd10);
    start_run();
    frames_base = m_env.m_tx_mon.frame_count_seen;
    wait_for_tx_frames(frames_base + 1, 600000);
    frames_before_stop = m_env.m_tx_mon.frame_count_seen;
    inject_pulse(0, 1000, 16000);
    wait_clocks(8);
    stop_run_system();

    if (m_env.m_tx_mon.frame_count_seen != frames_before_stop)
      `uvm_error("EMUT_TERM", $sformatf(
        "Observed %0d new frame(s) during TERMINATING hold (before=%0d after=%0d)",
        m_env.m_tx_mon.frame_count_seen - frames_before_stop,
        frames_before_stop,
        m_env.m_tx_mon.frame_count_seen))
    wait_clocks(16);
  endtask

  task automatic frame_case_high_rate_fill();
    int unsigned tx_base;

    log_case("emut_test_high_rate_fill");
    program_common_cfg(HIT_MODE_POISSON, 1'b0, 16'hFFFF, 16'h0000, 5'd8, 5'd4,
      32'hFACE_0FF0, TX_MODE_LONG, 1'b1, 4'd12);
    tx_base = m_env.m_tx_mon.frame_count_seen;
    start_run();
    wait_for_tx_frames(tx_base + 3, 500000);
    stop_run();

    if (m_env.m_tx_mon.max_event_count_seen < 10'd32)
      `uvm_error("EMUT_FILL", $sformatf("Expected high-rate fill to exceed 31 events, saw %0d",
        m_env.m_tx_mon.max_event_count_seen))
    wait_clocks(16);
  endtask

  task automatic run_profile(
    input bit [1:0] hit_mode,
    input bit [2:0] tx_mode,
    input bit       short_mode,
    input bit [4:0] burst_size,
    input bit [4:0] burst_center,
    input bit       gen_idle,
    input bit       do_inject,
    input bit       do_second_inject,
    input bit [3:0] asic_id
  );
    int unsigned tx_base;
    int unsigned parser_base;

    program_common_cfg(hit_mode, short_mode, 16'h0000, 16'h0000, burst_size, burst_center,
      $urandom, tx_mode, gen_idle, asic_id);
    tx_base     = m_env.m_tx_mon.frame_count_seen;
    parser_base = m_env.m_parser_mon.nonempty_frame_count_seen;

    start_run();
    wait_clocks(8);

    if (do_inject) begin
      inject_pulse(0, 2000 + (asic_id % 4) * 1200, 10000);
      if (do_second_inject)
        inject_pulse(1, 500, 3000);
      wait_for_parser_nonempty_frames(parser_base + 1, 400000);
    end else begin
      wait_for_tx_frames(tx_base + 2, 400000);
    end

    stop_run();
    wait_clocks(16);

    if (m_env.m_tx_mon.last_frame.frame_flags[4:2] != tx_mode)
      `uvm_error("EMUT_SWEEP", $sformatf("Frame flags tx_mode mismatch exp=0x%0h got=0x%0h",
        tx_mode, m_env.m_tx_mon.last_frame.frame_flags[4:2]))
  endtask

  task automatic frame_case_mode_payload_sweep();
    log_case("emut_test_mode_payload_sweep");
    for (int unsigned hm = 0; hm < 4; hm++) begin
      bit [1:0] hit_mode_sel;
      bit [3:0] asic_base;
      hit_mode_sel = hm[1:0];
      asic_base    = hm[3:0];

      run_profile(hit_mode_sel, TX_MODE_LONG,     1'b0, 5'd1, 5'd6, 1'b1, 1'b0, 1'b0, asic_base);
      run_profile(hit_mode_sel, TX_MODE_SHORT,    1'b1, 5'd1, 5'd5, 1'b1, 1'b1, 1'b0, asic_base + 4'd4);
      run_profile(hit_mode_sel, TX_MODE_PRBS_1,   1'b0, 5'd3, 5'd5, 1'b1, 1'b1, 1'b0, asic_base + 4'd8);
      run_profile(hit_mode_sel, TX_MODE_PRBS_SAT, 1'b0, 5'd8, 5'd1, 1'b0, 1'b1, 1'b1, asic_base + 4'd12);
    end
  endtask

  task automatic frame_case_inject_matrix();
    int unsigned phase_tbl[4];
    int unsigned width_tbl[3];
    bit          short_mode;
    bit [2:0]    tx_mode;
    int unsigned parser_base;

    log_case("emut_test_inject_matrix");
    phase_tbl[0] = 500;
    phase_tbl[1] = 2500;
    phase_tbl[2] = 4500;
    phase_tbl[3] = 6500;
    width_tbl[0] = 7800;
    width_tbl[1] = 10000;
    width_tbl[2] = 18000;

    for (int unsigned p = 0; p < 4; p++) begin
      for (int unsigned w = 0; w < 3; w++) begin
        bit [3:0] asic_id;
        short_mode = (p + w) & 1;
        tx_mode    = short_mode ? TX_MODE_SHORT : TX_MODE_LONG;
        asic_id    = (p * 3 + w) & 7;

        program_common_cfg(HIT_MODE_POISSON, short_mode, 16'h0000, 16'h0000, 5'd1, 5'd7,
          $urandom, tx_mode, 1'b1, asic_id);
        parser_base = m_env.m_parser_mon.nonempty_frame_count_seen;

        start_run();
        wait_clocks(8);
        inject_pulse(0, phase_tbl[p], width_tbl[w]);
        wait_for_parser_nonempty_frames(parser_base + 1, 400000);
        stop_run();
        wait_clocks(16);
      end
    end
  endtask

  task automatic frame_case_mixed_random();
    bit [1:0]  hit_mode;
    bit        short_mode;
    bit [4:0]  burst_size;
    bit [4:0]  burst_center;
    bit [15:0] hit_rate;
    bit [15:0] noise_rate;
    bit [2:0]  tx_mode;
    bit [3:0]  asic_id;
    int unsigned scenario;
    int unsigned tx_base;
    int unsigned parser_nonempty_base;

    log_case("emut_test_mixed_random");
    for (int iter = 0; iter < 12; iter++) begin
      scenario     = $urandom_range(0, 5);
      asic_id      = {1'b0, iter[2:0]};
      burst_center = 5'($urandom_range(4, 27));

      case (scenario)
        0: begin
          hit_mode   = 2'b00;
          short_mode = 1'b0;
          burst_size = 5'd1;
          hit_rate   = 16'h0000;
          noise_rate = 16'h0000;
          tx_mode    = TX_MODE_LONG;
        end
        1: begin
          hit_mode   = 2'b00;
          short_mode = 1'b1;
          burst_size = 5'd1;
          hit_rate   = 16'h0000;
          noise_rate = 16'h0000;
          tx_mode    = TX_MODE_SHORT;
        end
        2: begin
          hit_mode   = 2'b01;
          short_mode = 1'b0;
          burst_size = 5'($urandom_range(2, 3));
          hit_rate   = 16'h0000;
          noise_rate = 16'h0000;
          tx_mode    = TX_MODE_LONG;
        end
        3: begin
          hit_mode   = 2'b01;
          short_mode = 1'b1;
          burst_size = 5'($urandom_range(2, 3));
          hit_rate   = 16'h0000;
          noise_rate = 16'h0000;
          tx_mode    = TX_MODE_SHORT;
        end
        4: begin
          hit_mode   = 2'b10;
          short_mode = 1'b0;
          burst_size = 5'd2;
          hit_rate   = 16'h0000;
          noise_rate = 16'($urandom_range(16'h0008, 16'h0040));
          tx_mode    = TX_MODE_LONG;
        end
        default: begin
          hit_mode   = 2'b11;
          short_mode = 1'b0;
          burst_size = 5'd2;
          hit_rate   = 16'($urandom_range(16'h0008, 16'h0040));
          noise_rate = 16'h0000;
          tx_mode    = TX_MODE_LONG;
        end
      endcase

      program_common_cfg(hit_mode, short_mode, hit_rate, noise_rate, burst_size, burst_center,
        $urandom, tx_mode, 1'b1, asic_id);
      tx_base              = m_env.m_tx_mon.frame_count_seen;
      parser_nonempty_base = m_env.m_parser_mon.nonempty_frame_count_seen;

      start_run();
      wait_clocks(8);

      if (scenario inside {0, 1, 3}) begin
        inject_pulse(0, $urandom_range(0, 7999), $urandom_range(9000, 20000));
        while (m_env.m_parser_mon.nonempty_frame_count_seen < parser_nonempty_base + 1)
          wait_clocks(1);
      end else begin
        while (m_env.m_tx_mon.frame_count_seen < tx_base + 2)
          wait_clocks(1);
      end

      stop_run();
      wait_clocks(24);
    end

    if (m_env.m_tx_mon.frame_count_seen < 4)
      `uvm_error("EMUT_MIXED", $sformatf("Expected multiple frames in random test, saw %0d",
        m_env.m_tx_mon.frame_count_seen))
  endtask
endclass

class emut_test_bucket_frame_basic extends emut_frame_suite_base;
  `uvm_component_utils(emut_test_bucket_frame_basic)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    wait_for_reset_release();
    frame_case_idle_and_runctl();
    frame_case_long_inject_single();
    frame_case_short_inject_single();
    frame_case_long_burst_mode();
    frame_case_short_burst_mode();
    frame_case_noise_mode();
    frame_case_short_pack_extra_tail();
    frame_case_auto_low_center();
    frame_case_terminate_no_new_frame();
    phase.drop_objection(this);
  endtask
endclass

class emut_test_all_buckets_frame extends emut_frame_suite_base;
  `uvm_component_utils(emut_test_all_buckets_frame)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    wait_for_reset_release();
    frame_case_idle_and_runctl();
    frame_case_long_inject_single();
    frame_case_short_inject_single();
    frame_case_long_burst_mode();
    frame_case_short_burst_mode();
    frame_case_noise_mode();
    frame_case_short_pack_extra_tail();
    frame_case_auto_low_center();
    frame_case_terminate_no_new_frame();
    frame_case_high_rate_fill();
    frame_case_mode_payload_sweep();
    frame_case_inject_matrix();
    frame_case_mixed_random();
    phase.drop_objection(this);
  endtask
endclass
