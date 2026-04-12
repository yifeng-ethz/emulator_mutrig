class emut_tx_monitor extends uvm_monitor;
  `uvm_component_utils(emut_tx_monitor)

  virtual emut_tx_if.mon vif;
  uvm_analysis_port #(emut_tx_frame_item) ap;

  int unsigned        cycle_count;
  int unsigned        frame_count_seen;
  int unsigned        nonempty_frame_count_seen;
  int unsigned        max_event_count_seen;
  emut_tx_frame_item  last_frame;

  bit                 collecting;
  int unsigned        last_header_cycle;
  bit                 saw_header;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db#(virtual emut_tx_if.mon)::get(this, "", "vif", vif))
      `uvm_fatal("EMUT_TX_MON", "Missing emut_tx_if.mon")
  endfunction

  function automatic bit [15:0] crc16_reference(input byte unsigned data_q[$]);
    bit [15:0] crc;
    bit [15:0] nxt;
    bit [7:0]  d;

    crc = 16'hFFFF;
    foreach (data_q[i]) begin
      d = data_q[i];
      nxt[0]  = crc[15]^d[7] ^ crc[14]^d[6] ^ crc[13]^d[5] ^ crc[12]^d[4] ^
                crc[11]^d[3] ^ crc[10]^d[2] ^ crc[9]^d[1]  ^ crc[8]^d[0];
      nxt[1]  = crc[15]^d[7] ^ crc[14]^d[6] ^ crc[13]^d[5] ^ crc[12]^d[4] ^
                crc[11]^d[3] ^ crc[10]^d[2] ^ crc[9]^d[1];
      nxt[2]  = crc[9]^d[1]  ^ crc[8]^d[0];
      nxt[3]  = crc[10]^d[2] ^ crc[9]^d[1];
      nxt[4]  = crc[11]^d[3] ^ crc[10]^d[2];
      nxt[5]  = crc[12]^d[4] ^ crc[11]^d[3];
      nxt[6]  = crc[13]^d[5] ^ crc[12]^d[4];
      nxt[7]  = crc[14]^d[6] ^ crc[13]^d[5];
      nxt[8]  = crc[15]^d[7] ^ crc[14]^d[6] ^ crc[0];
      nxt[9]  = crc[15]^d[7] ^ crc[1];
      nxt[10] = crc[2];
      nxt[11] = crc[3];
      nxt[12] = crc[4];
      nxt[13] = crc[5];
      nxt[14] = crc[6];
      nxt[15] = crc[15]^d[7] ^ crc[14]^d[6] ^ crc[13]^d[5] ^ crc[12]^d[4] ^
                crc[11]^d[3] ^ crc[10]^d[2] ^ crc[9]^d[1]  ^ crc[8]^d[0] ^ crc[7];
      crc = nxt;
    end
    return ~crc;
  endfunction

  function automatic void finalize_frame(ref emut_tx_frame_item item);
    bit [15:0] tmp16;
    byte unsigned crc_bytes[$];

    item.frame_len = item.bytes.size();
    if (item.frame_len < 8)
      return;

    item.frame_count = {item.bytes[1], item.bytes[2]};
    tmp16            = {item.bytes[3], item.bytes[4]};
    item.frame_flags = tmp16[15:10];
    item.event_count = tmp16[9:0];
    item.delay_byte  = item.bytes[item.frame_len-4];
    item.crc_received = {item.bytes[item.frame_len-3], item.bytes[item.frame_len-2]};

    for (int i = 1; i <= item.frame_len - 5; i++)
      crc_bytes.push_back(item.bytes[i]);

    item.crc_expected = crc16_reference(crc_bytes);
    item.crc_ok       = (item.crc_expected == item.crc_received);
  endfunction

  function automatic void push_sample(ref emut_tx_frame_item item);
    item.bytes.push_back(vif.data[7:0]);
    item.is_k.push_back(vif.data[8]);
    item.error.push_back(vif.error);
  endfunction

  task run_phase(uvm_phase phase);
    emut_tx_frame_item frame;

    cycle_count             = 0;
    frame_count_seen        = 0;
    nonempty_frame_count_seen = 0;
    max_event_count_seen    = 0;
    collecting              = 1'b0;
    saw_header              = 1'b0;
    last_header_cycle       = 0;

    forever begin
      @(posedge vif.clk);
      cycle_count++;

      if (vif.valid !== 1'b1)
        continue;

      if (!collecting) begin
        if (vif.data == {1'b1, K28_0}) begin
          frame = emut_tx_frame_item::type_id::create($sformatf("tx_frame_%0d", frame_count_seen));
          frame.channel = vif.channel;
          frame.header_gap_cycles = saw_header ? (cycle_count - last_header_cycle) : 0;
          frame.header_time_ps    = $time;
          collecting              = 1'b1;
          saw_header              = 1'b1;
          last_header_cycle       = cycle_count;
          push_sample(frame);
        end
      end else begin
        push_sample(frame);
        if (vif.data == {1'b1, K28_4}) begin
          frame.trailer_time_ps = $time;
          finalize_frame(frame);
          frame_count_seen++;
          if (frame.event_count != 0)
            nonempty_frame_count_seen++;
          if (frame.event_count > max_event_count_seen)
            max_event_count_seen = frame.event_count;
          last_frame = frame;
          ap.write(frame);
          collecting = 1'b0;
        end
      end
    end
  endtask
endclass
