class emut_parser_monitor extends uvm_monitor;
  `uvm_component_utils(emut_parser_monitor)

  virtual emut_parser_if.mon vif;
  uvm_analysis_port #(emut_parser_frame_item) ap;

  int unsigned           frame_count_seen;
  int unsigned           nonempty_frame_count_seen;
  int unsigned           max_frame_len_seen;
  emut_parser_frame_item last_frame;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db#(virtual emut_parser_if.mon)::get(this, "", "vif", vif))
      `uvm_fatal("EMUT_PARSER_MON", "Missing emut_parser_if.mon")
  endfunction

  task run_phase(uvm_phase phase);
    emut_parser_frame_item frame;

    frame_count_seen         = 0;
    nonempty_frame_count_seen = 0;
    max_frame_len_seen       = 0;
    frame                    = null;

    forever begin
      @(posedge vif.clk);

      if (vif.headerinfo_valid === 1'b1) begin
        if (frame != null)
          `uvm_error("EMUT_PARSER_MON", "New headerinfo arrived before previous parser frame completed")

        frame = emut_parser_frame_item::type_id::create($sformatf("parser_frame_%0d", frame_count_seen));
        frame.header_time_ps = $time;
        frame.frame_flags    = vif.headerinfo_data[5:0];
        frame.frame_len      = vif.headerinfo_data[15:6];
        frame.word_count     = vif.headerinfo_data[25:16];
        frame.frame_number   = vif.headerinfo_data[41:26];
        frame.channel        = vif.headerinfo_channel;

        if (frame.frame_len == 0) begin
          frame_count_seen++;
          last_frame = frame;
          ap.write(frame);
          frame = null;
        end
      end

      if (vif.hit_valid === 1'b1) begin
        if (frame == null) begin
          `uvm_error("EMUT_PARSER_MON", "Parser hit observed without active headerinfo frame")
        end else begin
          if (frame.hit_data.size() == 0)
            frame.first_hit_time_ps = $time;
          frame.hit_data.push_back(vif.hit_data);
          frame.hit_error.push_back(vif.hit_error);
          frame.hit_sop.push_back(vif.hit_sop);
          frame.hit_eop.push_back(vif.hit_eop);

          if (frame.hit_data.size() == frame.frame_len) begin
            frame_count_seen++;
            nonempty_frame_count_seen++;
            if (frame.frame_len > max_frame_len_seen)
              max_frame_len_seen = frame.frame_len;
            last_frame = frame;
            ap.write(frame);
            frame = null;
          end
        end
      end
    end
  endtask
endclass
