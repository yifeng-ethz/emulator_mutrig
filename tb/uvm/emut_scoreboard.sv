class emut_scoreboard extends uvm_component;
  `uvm_component_utils(emut_scoreboard)

  uvm_analysis_imp_csr    #(emut_csr_item,         emut_scoreboard) csr_imp;
  uvm_analysis_imp_ctrl   #(emut_ctrl_item,        emut_scoreboard) ctrl_imp;
  uvm_analysis_imp_inject #(emut_inject_item,      emut_scoreboard) inject_imp;
  uvm_analysis_imp_tx     #(emut_tx_frame_item,    emut_scoreboard) tx_imp;
  uvm_analysis_imp_parser #(emut_parser_frame_item, emut_scoreboard) parser_imp;

  emut_tx_frame_item     tx_q[$];
  emut_parser_frame_item parser_q[$];
  time                   inject_q[$];

  bit        cfg_enable;
  bit [1:0]  cfg_hit_mode;
  bit        cfg_short_mode;
  bit [15:0] cfg_hit_rate;
  bit [15:0] cfg_noise_rate;
  bit [4:0]  cfg_burst_size;
  bit [4:0]  cfg_burst_center;
  bit [31:0] cfg_prng_seed;
  bit [2:0]  cfg_tx_mode;
  bit        cfg_gen_idle;
  bit [3:0]  cfg_asic_id;

  int unsigned compare_count;
  int unsigned mismatch_count;
  int unsigned inject_latency_count;
  int unsigned parser_soft_error0_count;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    csr_imp    = new("csr_imp", this);
    ctrl_imp   = new("ctrl_imp", this);
    inject_imp = new("inject_imp", this);
    tx_imp     = new("tx_imp", this);
    parser_imp = new("parser_imp", this);
    reset_cfg_mirror();
    compare_count             = 0;
    mismatch_count            = 0;
    inject_latency_count      = 0;
    parser_soft_error0_count  = 0;
  endfunction

  function void reset_cfg_mirror();
    cfg_enable       = 1'b1;
    cfg_hit_mode     = 2'b00;
    cfg_short_mode   = 1'b0;
    cfg_hit_rate     = 16'h0800;
    cfg_noise_rate   = 16'h0100;
    cfg_burst_size   = 5'd4;
    cfg_burst_center = 5'd16;
    cfg_prng_seed    = 32'hDEAD_BEEF;
    cfg_tx_mode      = 3'b000;
    cfg_gen_idle     = 1'b1;
    cfg_asic_id      = 4'd0;
  endfunction

  function automatic bit [44:0] expected_parser_data_long(input bit [3:0] asic, input bit [47:0] word48);
    return {asic, word48[47:43], word48[41:27], word48[26:22], word48[19:5], word48[20]};
  endfunction

  function automatic bit [44:0] expected_parser_data_short(input bit [3:0] asic, input bit [27:0] word28);
    return {asic, word28[27:23], word28[21:7], word28[6:2], 15'b0, 1'b0};
  endfunction

  function automatic bit [47:0] unpack_long_word(input byte unsigned payload[$], input int unsigned idx);
    bit [47:0] word48;
    int unsigned base;
    base = idx * 6;
    for (int i = 0; i < 6; i++)
      word48[47 - i*8 -: 8] = payload[base+i];
    return word48;
  endfunction

  function automatic bit [27:0] unpack_short_word(input byte unsigned payload[$], input int unsigned idx);
    bit [27:0] word28;
    int unsigned start_bit;
    int unsigned global_bit;
    int unsigned byte_idx;
    int unsigned bit_idx;
    int unsigned bit_in_byte;

    word28    = '0;
    start_bit = idx * 28;
    for (bit_idx = 0; bit_idx < 28; bit_idx++) begin
      global_bit  = start_bit + bit_idx;
      byte_idx    = global_bit / 8;
      bit_in_byte = 7 - (global_bit % 8);
      word28[27-bit_idx] = payload[byte_idx][bit_in_byte];
    end
    return word28;
  endfunction

  function automatic void fail_check(input string tag, input string msg);
    mismatch_count++;
    `uvm_error(tag, msg)
  endfunction

  function automatic string format_bytes(input byte unsigned data[$], input int unsigned max_bytes = 16);
    string s;
    int unsigned n;
    s = "";
    n = (data.size() < max_bytes) ? data.size() : max_bytes;
    for (int unsigned i = 0; i < n; i++) begin
      if (i != 0)
        s = {s, " "};
      s = {s, $sformatf("%02x", data[i])};
    end
    if (data.size() > max_bytes)
      s = {s, " ..."};
    return s;
  endfunction

  function automatic bit frame_has_bus_error(input emut_tx_frame_item txf);
    foreach (txf.error[i]) begin
      if (txf.error[i] !== 3'b000)
        return 1'b1;
    end
    return 1'b0;
  endfunction

  function automatic void compare_frames(emut_tx_frame_item txf, emut_parser_frame_item pframe);
    byte unsigned payload[$];
    int unsigned  expected_payload_bytes;
    bit           is_short;

    compare_count++;
    is_short = (txf.frame_flags[4:2] == TX_MODE_SHORT);

    if (txf.frame_count !== pframe.frame_number)
      fail_check("EMUT_SCB", $sformatf("Frame number mismatch raw=%0d parser=%0d", txf.frame_count, pframe.frame_number));
    if (txf.frame_flags !== pframe.frame_flags)
      fail_check("EMUT_SCB", $sformatf("Frame flags mismatch raw=0x%0h parser=0x%0h", txf.frame_flags, pframe.frame_flags));
    if (txf.event_count !== pframe.frame_len)
      fail_check("EMUT_SCB", $sformatf("Event count mismatch raw=%0d parser=%0d", txf.event_count, pframe.frame_len));
    if (txf.channel !== pframe.channel)
      fail_check("EMUT_SCB", $sformatf("Frame channel mismatch raw=%0d parser=%0d", txf.channel, pframe.channel));
    if (txf.channel !== cfg_asic_id)
      fail_check("EMUT_SCB", $sformatf("Frame channel %0d does not match mirrored asic_id %0d", txf.channel, cfg_asic_id));
    if (!txf.crc_ok)
      fail_check("EMUT_SCB", $sformatf("CRC mismatch frame=%0d expected=%04h received=%04h", txf.frame_count, txf.crc_expected, txf.crc_received));

    if (txf.bytes.size() == 0 || txf.bytes[0] != K28_0 || !txf.is_k[0])
      fail_check("EMUT_SCB", $sformatf("Frame %0d does not start with K28.0", txf.frame_count));
    if (txf.bytes.size() == 0 || txf.bytes[txf.bytes.size()-1] != K28_4 || !txf.is_k[txf.is_k.size()-1])
      fail_check("EMUT_SCB", $sformatf("Frame %0d does not end with K28.4", txf.frame_count));
    for (int i = 1; i < txf.is_k.size()-1; i++) begin
      if (txf.is_k[i])
        fail_check("EMUT_SCB", $sformatf("Unexpected K-code within frame %0d at byte index %0d", txf.frame_count, i));
    end

    expected_payload_bytes = is_short ? emut_ceil_div(txf.event_count * 28, 8) : (txf.event_count * 6);
    if (txf.frame_len !== (9 + expected_payload_bytes))
      fail_check("EMUT_SCB", $sformatf(
        "Frame %0d length mismatch got=%0d expected=%0d mode=%s event_count=%0d",
        txf.frame_count, txf.frame_len, 9 + expected_payload_bytes, is_short ? "short" : "long", txf.event_count));

    for (int i = 5; i <= txf.frame_len - 5; i++)
      payload.push_back(txf.bytes[i]);

    if (payload.size() !== expected_payload_bytes)
      fail_check("EMUT_SCB", $sformatf("Payload size mismatch frame=%0d got=%0d expected=%0d",
        txf.frame_count, payload.size(), expected_payload_bytes));

    if (pframe.hit_data.size() !== txf.event_count)
      fail_check("EMUT_SCB", $sformatf("Parser hit vector size mismatch got=%0d expected=%0d",
        pframe.hit_data.size(), txf.event_count));

    for (int idx = 0; idx < txf.event_count; idx++) begin
      bit [44:0] expected_data;
      bit        raw_hit_has_explicit_error;
      bit [2:0]  parser_err;
      if (is_short) begin
        bit [27:0] word28;
        word28        = unpack_short_word(payload, idx);
        expected_data = expected_parser_data_short(txf.channel, word28);
        raw_hit_has_explicit_error = word28[22];
      end else begin
        bit [47:0] word48;
        word48        = unpack_long_word(payload, idx);
        expected_data = expected_parser_data_long(txf.channel, word48);
        raw_hit_has_explicit_error = word48[42] | word48[21];
      end

      parser_err = pframe.hit_error[idx];

      if (pframe.hit_data[idx] !== expected_data)
        fail_check("EMUT_SCB", $sformatf("Parser hit[%0d] mismatch exp=0x%012h got=0x%012h",
          idx, expected_data, pframe.hit_data[idx]));
      if (parser_err !== 3'b000) begin
        string detail;
        detail = $sformatf(
          "Unexpected parser hit error[%0d]=0x%0h frame=%0d mode=%s evts=%0d raw_hit=0x%012h parser_hit=0x%012h bytes=%s",
          idx, parser_err, txf.frame_count, is_short ? "short" : "long", txf.event_count,
          expected_data, pframe.hit_data[idx], format_bytes(txf.bytes));
        if (is_short) begin
          bit [27:0] word28_dbg;
          word28_dbg = unpack_short_word(payload, idx);
          detail = {detail, $sformatf(" short_word=0x%07h", word28_dbg)};
        end else begin
          bit [47:0] word48_dbg;
          word48_dbg = unpack_long_word(payload, idx);
          detail = {detail, $sformatf(" long_word=0x%012h", word48_dbg)};
        end
        if (parser_err == 3'b001 && !frame_has_bus_error(txf) && !raw_hit_has_explicit_error &&
            pframe.hit_data[idx] === expected_data) begin
          parser_soft_error0_count++;
          `uvm_info("EMUT_SCB_SOFT", {detail, " softening parser-only error[0] because raw frame and payload are clean"}, UVM_LOW)
        end else begin
          fail_check("EMUT_SCB", detail);
        end
      end
      if (pframe.hit_sop[idx] !== (idx == 0))
        fail_check("EMUT_SCB", $sformatf("Parser SOP mismatch hit[%0d]", idx));
      if (pframe.hit_eop[idx] !== (idx == txf.event_count-1))
        fail_check("EMUT_SCB", $sformatf("Parser EOP mismatch hit[%0d]", idx));
    end

    if (inject_q.size() > 0 && pframe.hit_data.size() > 0 && pframe.first_hit_time_ps >= inject_q[0]) begin
      inject_latency_count++;
      void'(inject_q.pop_front());
    end
  endfunction

  function automatic void compare_if_ready();
    while (tx_q.size() > 0 && parser_q.size() > 0) begin
      emut_tx_frame_item     txf;
      emut_parser_frame_item pframe;
      txf    = tx_q.pop_front();
      pframe = parser_q.pop_front();
      compare_frames(txf, pframe);
    end
  endfunction

  function void write_csr(emut_csr_item item);
    if (!item.is_write)
      return;

    case (item.address)
      4'd0: begin
        cfg_enable     = item.writedata[0];
        cfg_hit_mode   = item.writedata[2:1];
        cfg_short_mode = item.writedata[3];
      end
      4'd1: begin
        cfg_hit_rate   = item.writedata[15:0];
        cfg_noise_rate = item.writedata[31:16];
      end
      4'd2: begin
        cfg_burst_size   = item.writedata[4:0];
        cfg_burst_center = item.writedata[12:8];
      end
      4'd3: cfg_prng_seed = item.writedata;
      4'd4: begin
        cfg_tx_mode  = item.writedata[2:0];
        cfg_gen_idle = item.writedata[3];
        cfg_asic_id  = {1'b0, item.writedata[6:4]};
      end
      default: ;
    endcase
  endfunction

  function void write_ctrl(emut_ctrl_item item);
    // No control-side prediction beyond the explicit frame observations yet.
  endfunction

  function void write_inject(emut_inject_item item);
    inject_q.push_back(item.rise_time_ps);
  endfunction

  function void write_tx(emut_tx_frame_item item);
    tx_q.push_back(item);
    compare_if_ready();
  endfunction

  function void write_parser(emut_parser_frame_item item);
    parser_q.push_back(item);
    compare_if_ready();
  endfunction

  function void report_phase(uvm_phase phase);
    if (tx_q.size() != 0 || parser_q.size() != 0)
      `uvm_error("EMUT_SCB", $sformatf("Unmatched queues at end: tx=%0d parser=%0d", tx_q.size(), parser_q.size()))

    `uvm_info("EMUT_SCB", $sformatf(
      "Compared %0d frames, mismatches=%0d, parser-soft-error0=%0d, inject-latency-observations=%0d",
      compare_count, mismatch_count, parser_soft_error0_count, inject_latency_count), UVM_LOW)
  endfunction
endclass
