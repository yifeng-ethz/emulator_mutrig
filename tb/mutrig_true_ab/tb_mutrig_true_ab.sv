`timescale 1ns/1ps

module tb_mutrig_true_ab;
    import emulator_mutrig_pkg::*;

    import "DPI-C" function void emut_ab_init(input int seed);
    import "DPI-C" function longint unsigned emut_ab_next_offer(
        input int rate_cfg,
        input int short_mode,
        output int valid
    );

    localparam real CLK_PERIOD_NS = 8.0;

    typedef struct {
        longint unsigned id;
        longint unsigned offer_cycle;
        logic [47:0]     word;
        bit              measure;
    } offer_item_t;

    typedef struct {
        longint unsigned id;
        longint unsigned offer_cycle;
        logic [47:0]     word;
        longint unsigned parser_cycle;
        logic [44:0]     parser_data;
        logic [3:0]      parser_channel;
        bit              measure;
    } obs_item_t;

    string out_csv_path;
    string out_summary_path;
    int    out_csv_fd;
    int    out_summary_fd;

    int rate_cfg;
    int short_mode_cfg;
    int seed_cfg;
    int warmup_cycles;
    int measure_cycles;
    int drain_timeout_cycles;
    int asic_id_cfg;
    int trace_tx_cfg;

    logic clk;
    logic rst;
    logic short_mode;
    logic [2:0] tx_mode;
    logic [3:0] asic_id;

    logic        offer_valid;
    logic [47:0] offer_word;
    logic        common_frame_mark;

    logic        emu_offer_ready;
    logic        emu_accept_pulse;
    logic [47:0] emu_accept_word;
    logic        emu_frame_mark;
    logic [9:0]  emu_event_count;
    logic        emu_fifo_empty;
    logic        emu_fifo_full;
    logic        emu_fifo_almost_full;
    logic [8:0]  emu_tx_data;
    logic        emu_tx_valid;

    logic        raw_offer_ready;
    logic        raw_accept_pulse;
    logic        raw_fifo_rd_en;
    logic [9:0]  raw_event_count;
    logic        raw_fifo_empty;
    logic        raw_fifo_full;
    logic        raw_fifo_almost_full;
    logic [8:0]  raw_tx_data;
    logic        raw_tx_valid;

    logic        raw_parser_rst;
    logic [8:0]  raw_parser_ctrl_data;
    logic        raw_parser_ctrl_valid;
    logic        raw_parser_ctrl_ready;
    logic [1:0]  raw_parser_csr_address;
    logic        raw_parser_csr_read;
    logic        raw_parser_csr_write;
    logic [31:0] raw_parser_csr_writedata;
    logic [31:0] raw_parser_csr_readdata;
    logic        raw_parser_csr_waitrequest;
    logic [3:0]  raw_parser_hit_channel;
    logic        raw_parser_hit_sop;
    logic        raw_parser_hit_eop;
    logic [2:0]  raw_parser_hit_error;
    logic [44:0] raw_parser_hit_data;
    logic        raw_parser_hit_valid;
    logic [41:0] raw_parser_headerinfo_data;
    logic        raw_parser_headerinfo_valid;
    logic [3:0]  raw_parser_headerinfo_channel;

    logic        emu_parser_rst;
    logic [8:0]  emu_parser_ctrl_data;
    logic        emu_parser_ctrl_valid;
    logic        emu_parser_ctrl_ready;
    logic [1:0]  emu_parser_csr_address;
    logic        emu_parser_csr_read;
    logic        emu_parser_csr_write;
    logic [31:0] emu_parser_csr_writedata;
    logic [31:0] emu_parser_csr_readdata;
    logic        emu_parser_csr_waitrequest;
    logic [3:0]  emu_parser_hit_channel;
    logic        emu_parser_hit_sop;
    logic        emu_parser_hit_eop;
    logic [2:0]  emu_parser_hit_error;
    logic [44:0] emu_parser_hit_data;
    logic        emu_parser_hit_valid;
    logic [41:0] emu_parser_headerinfo_data;
    logic        emu_parser_headerinfo_valid;
    logic [3:0]  emu_parser_headerinfo_channel;

    offer_item_t raw_accept_q[$];
    offer_item_t emu_accept_q[$];
    obs_item_t   raw_obs_q[$];
    obs_item_t   emu_obs_q[$];

    longint unsigned cycle_count;
    longint unsigned offer_id_next;
    longint unsigned measure_start_cycle;
    longint unsigned measure_end_cycle;
    longint unsigned offered_total;
    longint unsigned offered_measure;
    longint unsigned raw_accepted_total;
    longint unsigned emu_accepted_total;
    longint unsigned raw_output_total;
    longint unsigned emu_output_total;
    longint unsigned raw_headers_total;
    longint unsigned emu_headers_total;
    longint unsigned raw_accept_measure;
    longint unsigned emu_accept_measure;
    longint unsigned raw_output_measure;
    longint unsigned emu_output_measure;
    longint unsigned raw_occ_sum;
    longint unsigned emu_occ_sum;
    longint unsigned occ_samples;
    longint unsigned raw_occ_max;
    longint unsigned emu_occ_max;
    int accept_mismatch_count;
    int tx_mismatch_count;
    int parser_valid_mismatch_count;
    int parser_direct_data_mismatch_count;
    int parser_direct_channel_mismatch_count;
    int output_id_mismatch_count;
    int parser_data_mismatch_count;
    int hit_channel_mismatch_count;
    int parser_cycle_mismatch_count;
    int frame_mark_mismatch_count;
    int queue_underflow_count;
    bit measure_window_active;

    logic             offer_pending_valid;
    longint unsigned  offer_pending_id;
    longint unsigned  offer_pending_cycle;
    logic [47:0]      offer_pending_word;
    bit               offer_pending_measure;

    function automatic bit measure_cycle(input longint unsigned cycle_v);
        return measure_window_active &&
               (cycle_v >= measure_start_cycle) &&
               (cycle_v <= measure_end_cycle);
    endfunction

    function automatic logic [4:0] parser_hit_channel_field(
        input logic [44:0] parser_data_v
    );
        return parser_data_v[40:36];
    endfunction

    localparam logic [8:0] CTRL_IDLE        = 9'b000000001;
    localparam logic [8:0] CTRL_RUN_PREPARE = 9'b000000010;
    localparam logic [8:0] CTRL_SYNC        = 9'b000000100;
    localparam logic [8:0] CTRL_RUNNING     = 9'b000001000;

    task automatic parser_send_run_state(
        ref logic [8:0]     ctrl_data,
        ref logic           ctrl_valid,
        input  logic        ctrl_ready,
        input  logic [8:0]  state
    );
        @(posedge clk);
        ctrl_data  = state;
        ctrl_valid = 1'b1;
        do begin
            @(posedge clk);
        end while (ctrl_ready !== 1'b1);
        ctrl_valid = 1'b0;
        ctrl_data  = CTRL_IDLE;
    endtask

    task automatic parser_prepare_for_run;
        parser_send_run_state(raw_parser_ctrl_data, raw_parser_ctrl_valid, raw_parser_ctrl_ready, CTRL_RUN_PREPARE);
        parser_send_run_state(emu_parser_ctrl_data, emu_parser_ctrl_valid, emu_parser_ctrl_ready, CTRL_RUN_PREPARE);
        parser_send_run_state(raw_parser_ctrl_data, raw_parser_ctrl_valid, raw_parser_ctrl_ready, CTRL_SYNC);
        parser_send_run_state(emu_parser_ctrl_data, emu_parser_ctrl_valid, emu_parser_ctrl_ready, CTRL_SYNC);
        parser_send_run_state(raw_parser_ctrl_data, raw_parser_ctrl_valid, raw_parser_ctrl_ready, CTRL_RUNNING);
        parser_send_run_state(emu_parser_ctrl_data, emu_parser_ctrl_valid, emu_parser_ctrl_ready, CTRL_RUNNING);
    endtask

    task automatic maybe_compare_outputs;
        obs_item_t raw_obs;
        obs_item_t emu_obs;
        logic [4:0] expected_channel;

        while ((raw_obs_q.size() != 0) && (emu_obs_q.size() != 0)) begin
            raw_obs = raw_obs_q.pop_front();
            emu_obs = emu_obs_q.pop_front();

            if (raw_obs.id != emu_obs.id)
                output_id_mismatch_count++;

            expected_channel = raw_obs.word[47:43];

            if ((raw_obs.parser_data != emu_obs.parser_data) ||
                (raw_obs.parser_channel != asic_id) ||
                (emu_obs.parser_channel != asic_id)) begin
                parser_data_mismatch_count++;
            end

            if ((parser_hit_channel_field(raw_obs.parser_data) != expected_channel) ||
                (parser_hit_channel_field(emu_obs.parser_data) != expected_channel))
                hit_channel_mismatch_count++;

            if (raw_obs.parser_cycle != emu_obs.parser_cycle)
                parser_cycle_mismatch_count++;

            if (raw_obs.measure || emu_obs.measure) begin
                $fdisplay(out_csv_fd,
                          "%0d,%0d,0x%012h,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,0x%012h,0x%012h,0x%012h",
                          raw_obs.id,
                          raw_obs.offer_cycle,
                          raw_obs.word,
                          raw_obs.measure ? 1 : 0,
                          raw_obs.parser_cycle,
                          emu_obs.parser_cycle,
                          raw_obs.parser_cycle - raw_obs.offer_cycle,
                          emu_obs.parser_cycle - emu_obs.offer_cycle,
                          parser_hit_channel_field(raw_obs.parser_data),
                          parser_hit_channel_field(emu_obs.parser_data),
                          (raw_obs.parser_cycle == emu_obs.parser_cycle) ? 1 : 0,
                          (raw_obs.parser_data == emu_obs.parser_data) ? 1 : 0,
                          raw_obs.parser_data,
                          emu_obs.parser_data,
                          {40'd0, expected_channel});
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD_NS/2.0) clk = ~clk;
    end

    initial begin
        rst = 1'b1;
        #(CLK_PERIOD_NS * 10.0);
        rst = 1'b0;
    end

    emut_frame_top_direct #(
        .FIFO_DEPTH (RAW_FIFO_DEPTH)
    ) emu_dut (
        .clk              (clk),
        .rst              (rst),
        .frame_start_req  (common_frame_mark),
        .cfg_short_mode   (short_mode),
        .cfg_gen_idle     (1'b1),
        .cfg_tx_mode      (tx_mode),
        .offer_valid      (offer_valid),
        .offer_word       (offer_word),
        .offer_ready      (emu_offer_ready),
        .accept_pulse     (emu_accept_pulse),
        .accept_word      (emu_accept_word),
        .frame_mark       (emu_frame_mark),
        .event_count      (emu_event_count),
        .fifo_empty       (emu_fifo_empty),
        .fifo_full        (emu_fifo_full),
        .fifo_almost_full (emu_fifo_almost_full),
        .tx_data          (emu_tx_data),
        .tx_valid         (emu_tx_valid)
    );

    raw_mutrig_frame_top raw_dut (
        .i_clk              (clk),
        .i_rst              (rst),
        .i_start_trans      (common_frame_mark),
        .i_short_mode       (short_mode),
        .i_gen_idle         (1'b1),
        .i_offer_valid      (offer_valid),
        .i_offer_word       (offer_word),
        .o_offer_ready      (raw_offer_ready),
        .o_accept_pulse     (raw_accept_pulse),
        .o_fifo_rd_en       (raw_fifo_rd_en),
        .o_event_count      (raw_event_count),
        .o_fifo_empty       (raw_fifo_empty),
        .o_fifo_full        (raw_fifo_full),
        .o_fifo_almost_full (raw_fifo_almost_full),
        .o_tx_data          (raw_tx_data),
        .o_tx_valid         (raw_tx_valid)
    );

    frame_rcv_ip #(
        .CHANNEL_WIDTH (4),
        .CSR_ADDR_WIDTH(2),
        .MODE_HALT     (0),
        .DEBUG_LV      (0)
    ) raw_parser (
        .asi_rx8b1k_data             (raw_tx_data),
        .asi_rx8b1k_valid            (raw_tx_valid),
        .asi_rx8b1k_error            (3'b000),
        .asi_rx8b1k_channel          (asic_id),
        .aso_hit_type0_channel       (raw_parser_hit_channel),
        .aso_hit_type0_startofpacket (raw_parser_hit_sop),
        .aso_hit_type0_endofpacket   (raw_parser_hit_eop),
        .aso_hit_type0_endofrun      (),
        .aso_hit_type0_error         (raw_parser_hit_error),
        .aso_hit_type0_data          (raw_parser_hit_data),
        .aso_hit_type0_valid         (raw_parser_hit_valid),
        .aso_headerinfo_data         (raw_parser_headerinfo_data),
        .aso_headerinfo_valid        (raw_parser_headerinfo_valid),
        .aso_headerinfo_channel      (raw_parser_headerinfo_channel),
        .avs_csr_readdata            (raw_parser_csr_readdata),
        .avs_csr_read                (raw_parser_csr_read),
        .avs_csr_address             (raw_parser_csr_address),
        .avs_csr_waitrequest         (raw_parser_csr_waitrequest),
        .avs_csr_write               (raw_parser_csr_write),
        .avs_csr_writedata           (raw_parser_csr_writedata),
        .asi_ctrl_data               (raw_parser_ctrl_data),
        .asi_ctrl_valid              (raw_parser_ctrl_valid),
        .asi_ctrl_ready              (raw_parser_ctrl_ready),
        .i_rst                       (raw_parser_rst),
        .i_clk                       (clk)
    );

    frame_rcv_ip #(
        .CHANNEL_WIDTH (4),
        .CSR_ADDR_WIDTH(2),
        .MODE_HALT     (0),
        .DEBUG_LV      (0)
    ) emu_parser (
        .asi_rx8b1k_data             (emu_tx_data),
        .asi_rx8b1k_valid            (emu_tx_valid),
        .asi_rx8b1k_error            (3'b000),
        .asi_rx8b1k_channel          (asic_id),
        .aso_hit_type0_channel       (emu_parser_hit_channel),
        .aso_hit_type0_startofpacket (emu_parser_hit_sop),
        .aso_hit_type0_endofpacket   (emu_parser_hit_eop),
        .aso_hit_type0_endofrun      (),
        .aso_hit_type0_error         (emu_parser_hit_error),
        .aso_hit_type0_data          (emu_parser_hit_data),
        .aso_hit_type0_valid         (emu_parser_hit_valid),
        .aso_headerinfo_data         (emu_parser_headerinfo_data),
        .aso_headerinfo_valid        (emu_parser_headerinfo_valid),
        .aso_headerinfo_channel      (emu_parser_headerinfo_channel),
        .avs_csr_readdata            (emu_parser_csr_readdata),
        .avs_csr_read                (emu_parser_csr_read),
        .avs_csr_address             (emu_parser_csr_address),
        .avs_csr_waitrequest         (emu_parser_csr_waitrequest),
        .avs_csr_write               (emu_parser_csr_write),
        .avs_csr_writedata           (emu_parser_csr_writedata),
        .asi_ctrl_data               (emu_parser_ctrl_data),
        .asi_ctrl_valid              (emu_parser_ctrl_valid),
        .asi_ctrl_ready              (emu_parser_ctrl_ready),
        .i_rst                       (emu_parser_rst),
        .i_clk                       (clk)
    );

    assign raw_parser_rst          = rst;
    assign emu_parser_rst          = rst;
    assign raw_parser_csr_address  = '0;
    assign raw_parser_csr_read     = 1'b0;
    assign raw_parser_csr_write    = 1'b0;
    assign raw_parser_csr_writedata = '0;
    assign emu_parser_csr_address  = '0;
    assign emu_parser_csr_read     = 1'b0;
    assign emu_parser_csr_write    = 1'b0;
    assign emu_parser_csr_writedata = '0;

    always @(negedge clk) begin : frame_mark_driver
        int frame_interval;

        if (rst) begin
            common_frame_mark <= 1'b0;
        end else begin
            frame_interval = short_mode ? FRAME_INTERVAL_SHORT : FRAME_INTERVAL_LONG;
            if (((cycle_count + 1) % frame_interval) == 0)
                common_frame_mark <= 1'b1;
            else
                common_frame_mark <= 1'b0;
        end
    end

    always @(posedge clk) begin : monitor
        offer_item_t acc_item;
        obs_item_t   obs_item;
        longint unsigned sample_cycle;
        longint unsigned offer_id_this_cycle;
        longint unsigned offer_cycle_this_cycle;
        logic [47:0]     offer_word_this_cycle;
        bit              offer_measure_this_cycle;
        bit              raw_accept_hit;
        bit              emu_accept_hit;

        if (rst) begin
            cycle_count <= 0;
            offer_id_next <= 1;
            offered_total <= 0;
            offered_measure <= 0;
            raw_accepted_total <= 0;
            emu_accepted_total <= 0;
            raw_output_total <= 0;
            emu_output_total <= 0;
            raw_headers_total <= 0;
            emu_headers_total <= 0;
            raw_accept_measure <= 0;
            emu_accept_measure <= 0;
            raw_output_measure <= 0;
            emu_output_measure <= 0;
            raw_occ_sum <= 0;
            emu_occ_sum <= 0;
            occ_samples <= 0;
            raw_occ_max <= 0;
            emu_occ_max <= 0;
            accept_mismatch_count <= 0;
            tx_mismatch_count <= 0;
            parser_valid_mismatch_count <= 0;
            parser_direct_data_mismatch_count <= 0;
            parser_direct_channel_mismatch_count <= 0;
            output_id_mismatch_count <= 0;
            parser_data_mismatch_count <= 0;
            hit_channel_mismatch_count <= 0;
            parser_cycle_mismatch_count <= 0;
            frame_mark_mismatch_count <= 0;
            queue_underflow_count <= 0;
            measure_window_active <= 1'b0;
            offer_pending_valid <= 1'b0;
            offer_pending_id <= 0;
            offer_pending_cycle <= 0;
            offer_pending_word <= '0;
            offer_pending_measure <= 1'b0;
            raw_accept_q.delete();
            emu_accept_q.delete();
            raw_obs_q.delete();
            emu_obs_q.delete();
        end else begin
            cycle_count <= cycle_count + 1;
            sample_cycle = cycle_count + 1;
            offer_id_this_cycle      = offer_id_next;
            offer_cycle_this_cycle   = sample_cycle;
            offer_word_this_cycle    = offer_word;
            offer_measure_this_cycle = measure_cycle(sample_cycle);
            raw_accept_hit           = (raw_accept_pulse == 1'b1);
            emu_accept_hit           = (emu_accept_pulse == 1'b1);

            if (emu_frame_mark != common_frame_mark)
                frame_mark_mismatch_count <= frame_mark_mismatch_count + 1;

            if (raw_tx_data != emu_tx_data)
                tx_mismatch_count <= tx_mismatch_count + 1;

            if (measure_cycle(sample_cycle)) begin
                raw_occ_sum <= raw_occ_sum + raw_event_count;
                emu_occ_sum <= emu_occ_sum + emu_event_count;
                occ_samples <= occ_samples + 1;
                if (raw_event_count > raw_occ_max)
                    raw_occ_max <= raw_event_count;
                if (emu_event_count > emu_occ_max)
                    emu_occ_max <= emu_event_count;
            end

            if (offer_pending_valid) begin
                if (raw_accept_hit != emu_accept_hit) begin
                    accept_mismatch_count <= accept_mismatch_count + 1;
                    if (trace_tx_cfg != 0) begin
                        $display("ACC_MISMATCH cyc=%0d offer_id=%0d raw_acc=%0b emu_acc=%0b raw_evt=%0d emu_evt=%0d raw_full=%0b emu_full=%0b raw_rd=%0b emu_rd=%0b raw_offer_ready=%0b emu_offer_ready=%0b word=%012h",
                                 sample_cycle,
                                 offer_pending_id,
                                 raw_accept_hit,
                                 emu_accept_hit,
                                 raw_event_count,
                                 emu_event_count,
                                 raw_fifo_full,
                                 emu_fifo_full,
                                 raw_fifo_rd_en,
                                 emu_dut.fifo_rd_en,
                                 raw_offer_ready,
                                 emu_offer_ready,
                                 offer_pending_word);
                    end
                end

                if (raw_accept_hit) begin
                    acc_item.id          = offer_pending_id;
                    acc_item.offer_cycle = offer_pending_cycle;
                    acc_item.word        = offer_pending_word;
                    acc_item.measure     = offer_pending_measure;
                    raw_accept_q.push_back(acc_item);
                    raw_accepted_total <= raw_accepted_total + 1;
                    if (acc_item.measure)
                        raw_accept_measure <= raw_accept_measure + 1;
                end

                if (emu_accept_hit) begin
                    acc_item.id          = offer_pending_id;
                    acc_item.offer_cycle = offer_pending_cycle;
                    acc_item.word        = offer_pending_word;
                    acc_item.measure     = offer_pending_measure;
                    emu_accept_q.push_back(acc_item);
                    emu_accepted_total <= emu_accepted_total + 1;
                    if (acc_item.measure)
                        emu_accept_measure <= emu_accept_measure + 1;
                end
                offer_pending_valid <= 1'b0;
            end

            if (offer_valid) begin
                offered_total <= offered_total + 1;
                if (offer_measure_this_cycle)
                    offered_measure <= offered_measure + 1;
                offer_id_next <= offer_id_next + 1;
                offer_pending_valid <= 1'b1;
                offer_pending_id <= offer_id_this_cycle;
                offer_pending_cycle <= offer_cycle_this_cycle;
                offer_pending_word <= offer_word_this_cycle;
                offer_pending_measure <= offer_measure_this_cycle;
            end

            if (raw_parser_headerinfo_valid)
                raw_headers_total <= raw_headers_total + 1;
            if (emu_parser_headerinfo_valid)
                emu_headers_total <= emu_headers_total + 1;

            if (raw_parser_hit_valid != emu_parser_hit_valid)
                parser_valid_mismatch_count <= parser_valid_mismatch_count + 1;
            if (raw_parser_hit_valid && emu_parser_hit_valid) begin
                if (raw_parser_hit_data != emu_parser_hit_data)
                    parser_direct_data_mismatch_count <= parser_direct_data_mismatch_count + 1;
                if ((raw_parser_hit_channel != asic_id) ||
                    (emu_parser_hit_channel != asic_id) ||
                    (raw_parser_hit_channel != emu_parser_hit_channel))
                    parser_direct_channel_mismatch_count <= parser_direct_channel_mismatch_count + 1;
            end

            if ((trace_tx_cfg != 0) &&
                ((raw_tx_data != emu_tx_data) ||
                 (raw_tx_data != {1'b1, K28_5}) ||
                 raw_parser_hit_valid || emu_parser_hit_valid ||
                 raw_parser_headerinfo_valid || emu_parser_headerinfo_valid)) begin
                $display("TXTRACE cyc=%0d raw_tx=%03h emu_tx=%03h raw_hdr=%0b emu_hdr=%0b raw_hit=%0b emu_hit=%0b raw_data=%012h emu_data=%012h",
                         sample_cycle, raw_tx_data, emu_tx_data,
                         raw_parser_headerinfo_valid, emu_parser_headerinfo_valid,
                         raw_parser_hit_valid, emu_parser_hit_valid,
                         {3'b000, raw_parser_hit_data}, {3'b000, emu_parser_hit_data});
                if ((sample_cycle >= 1786) && (sample_cycle <= 1793)) begin
                    $display("EMUSTATE cyc=%0d state=%0d byte_count=%0d last=%0b pack=%0d evt_rem=%0d",
                             sample_cycle,
                             emu_dut.u_frame_asm.p_state,
                             emu_dut.u_frame_asm.p_byte_count,
                             emu_dut.u_frame_asm.p_last_event,
                             emu_dut.u_frame_asm.p_pack_event_odd,
                             emu_dut.u_frame_asm.p_event_cnt_decr);
                end
            end

            if (raw_parser_hit_valid) begin
                raw_output_total <= raw_output_total + 1;
                if (raw_accept_q.size() == 0) begin
                    queue_underflow_count <= queue_underflow_count + 1;
                end else begin
                    acc_item = raw_accept_q.pop_front();
                    obs_item.id = acc_item.id;
                    obs_item.offer_cycle = acc_item.offer_cycle;
                    obs_item.word = acc_item.word;
                    obs_item.parser_cycle = sample_cycle;
                    obs_item.parser_data = raw_parser_hit_data;
                    obs_item.parser_channel = raw_parser_hit_channel;
                    obs_item.measure = acc_item.measure;
                    raw_obs_q.push_back(obs_item);
                    if (acc_item.measure)
                        raw_output_measure <= raw_output_measure + 1;
                end
            end

            if (emu_parser_hit_valid) begin
                emu_output_total <= emu_output_total + 1;
                if (emu_accept_q.size() == 0) begin
                    queue_underflow_count <= queue_underflow_count + 1;
                end else begin
                    acc_item = emu_accept_q.pop_front();
                    obs_item.id = acc_item.id;
                    obs_item.offer_cycle = acc_item.offer_cycle;
                    obs_item.word = acc_item.word;
                    obs_item.parser_cycle = sample_cycle;
                    obs_item.parser_data = emu_parser_hit_data;
                    obs_item.parser_channel = emu_parser_hit_channel;
                    obs_item.measure = acc_item.measure;
                    emu_obs_q.push_back(obs_item);
                    if (acc_item.measure)
                        emu_output_measure <= emu_output_measure + 1;
                end
            end

            maybe_compare_outputs();
        end
    end

    initial begin : runbench
        int valid_i;
        longint unsigned word_i;
        int average_raw_occ_milli;
        int average_emu_occ_milli;
        int drain_waited;

        if (!$value$plusargs("RATE_CFG=%d", rate_cfg))
            rate_cfg = 0;
        if (!$value$plusargs("SHORT_MODE=%d", short_mode_cfg))
            short_mode_cfg = 1;
        if (!$value$plusargs("SEED=%d", seed_cfg))
            seed_cfg = 1;
        if (!$value$plusargs("WARMUP_CYCLES=%d", warmup_cycles))
            warmup_cycles = 50000;
        if (!$value$plusargs("MEASURE_CYCLES=%d", measure_cycles))
            measure_cycles = 200000;
        if (!$value$plusargs("DRAIN_TIMEOUT_CYCLES=%d", drain_timeout_cycles))
            drain_timeout_cycles = 400000;
        if (!$value$plusargs("ASIC_ID=%d", asic_id_cfg))
            asic_id_cfg = 3;
        if (!$value$plusargs("TRACE_TX=%d", trace_tx_cfg))
            trace_tx_cfg = 0;
        if (!$value$plusargs("OUT_CSV=%s", out_csv_path))
            out_csv_path = "mutrig_true_ab.csv";
        if (!$value$plusargs("OUT_SUMMARY=%s", out_summary_path))
            out_summary_path = "mutrig_true_ab.summary";

        short_mode = (short_mode_cfg != 0);
        tx_mode    = short_mode ? 3'b100 : 3'b000;
        asic_id    = asic_id_cfg[3:0];

        offer_valid = 1'b0;
        offer_word  = '0;
        raw_parser_ctrl_data = CTRL_IDLE;
        raw_parser_ctrl_valid = 1'b0;
        emu_parser_ctrl_data = CTRL_IDLE;
        emu_parser_ctrl_valid = 1'b0;

        out_csv_fd = $fopen(out_csv_path, "w");
        if (out_csv_fd == 0)
            $fatal(1, "failed to open OUT_CSV=%s", out_csv_path);
        $fdisplay(out_csv_fd,
                  "offer_id,offer_cycle,word,measure_window,raw_parser_cycle,emu_parser_cycle,raw_latency,emu_latency,raw_hit_channel,emu_hit_channel,cycle_match,data_match,raw_parser_data,emu_parser_data,expected_hit_channel");

        out_summary_fd = $fopen(out_summary_path, "w");
        if (out_summary_fd == 0)
            $fatal(1, "failed to open OUT_SUMMARY=%s", out_summary_path);

        measure_start_cycle = 64'hFFFF_FFFF_FFFF_FFFF;
        measure_end_cycle   = 0;
        measure_window_active = 1'b0;

        wait (rst == 1'b0);
        repeat (5) @(posedge clk);
        parser_prepare_for_run();
        emut_ab_init(seed_cfg);

        for (int cyc = 0; cyc < warmup_cycles + measure_cycles; cyc++) begin
            @(negedge clk);
            word_i = emut_ab_next_offer(rate_cfg, short_mode_cfg, valid_i);
            offer_valid = (valid_i != 0);
            offer_word  = word_i[47:0];

            if (cyc == warmup_cycles) begin
                measure_start_cycle = cycle_count + 1;
                measure_end_cycle   = measure_start_cycle + measure_cycles - 1;
                measure_window_active = 1'b1;
            end

            if (cyc == warmup_cycles + measure_cycles - 1) begin
                @(posedge clk);
                measure_window_active = 1'b0;
                offer_valid = 1'b0;
                offer_word  = '0;
            end else begin
                @(posedge clk);
            end
        end

        offer_valid = 1'b0;
        offer_word  = '0;

        drain_waited = 0;
        while (((raw_accept_q.size() != 0) || (emu_accept_q.size() != 0) ||
                (raw_obs_q.size() != 0) || (emu_obs_q.size() != 0) ||
                (raw_event_count != 10'd0) || (emu_event_count != 10'd0)) &&
               (drain_waited < drain_timeout_cycles)) begin
            @(posedge clk);
            drain_waited++;
        end

        average_raw_occ_milli = (occ_samples == 0) ? 0 : ((raw_occ_sum * 1000) / occ_samples);
        average_emu_occ_milli = (occ_samples == 0) ? 0 : ((emu_occ_sum * 1000) / occ_samples);

        $fdisplay(out_summary_fd, "short_mode=%0d", short_mode_cfg);
        $fdisplay(out_summary_fd, "rate_cfg=%0d", rate_cfg);
        $fdisplay(out_summary_fd, "seed=%0d", seed_cfg);
        $fdisplay(out_summary_fd, "warmup_cycles=%0d", warmup_cycles);
        $fdisplay(out_summary_fd, "measure_cycles=%0d", measure_cycles);
        $fdisplay(out_summary_fd, "measure_start_cycle=%0d", measure_start_cycle);
        $fdisplay(out_summary_fd, "measure_end_cycle=%0d", measure_end_cycle);
        $fdisplay(out_summary_fd, "offered_total=%0d", offered_total);
        $fdisplay(out_summary_fd, "offered_measure=%0d", offered_measure);
        $fdisplay(out_summary_fd, "raw_accepted_total=%0d", raw_accepted_total);
        $fdisplay(out_summary_fd, "emu_accepted_total=%0d", emu_accepted_total);
        $fdisplay(out_summary_fd, "raw_output_total=%0d", raw_output_total);
        $fdisplay(out_summary_fd, "emu_output_total=%0d", emu_output_total);
        $fdisplay(out_summary_fd, "raw_accept_measure=%0d", raw_accept_measure);
        $fdisplay(out_summary_fd, "emu_accept_measure=%0d", emu_accept_measure);
        $fdisplay(out_summary_fd, "raw_output_measure=%0d", raw_output_measure);
        $fdisplay(out_summary_fd, "emu_output_measure=%0d", emu_output_measure);
        $fdisplay(out_summary_fd, "raw_headers_total=%0d", raw_headers_total);
        $fdisplay(out_summary_fd, "emu_headers_total=%0d", emu_headers_total);
        $fdisplay(out_summary_fd, "average_raw_occupancy_milli=%0d", average_raw_occ_milli);
        $fdisplay(out_summary_fd, "average_emu_occupancy_milli=%0d", average_emu_occ_milli);
        $fdisplay(out_summary_fd, "raw_occ_max=%0d", raw_occ_max);
        $fdisplay(out_summary_fd, "emu_occ_max=%0d", emu_occ_max);
        $fdisplay(out_summary_fd, "accept_mismatch_count=%0d", accept_mismatch_count);
        $fdisplay(out_summary_fd, "tx_mismatch_count=%0d", tx_mismatch_count);
        $fdisplay(out_summary_fd, "parser_valid_mismatch_count=%0d", parser_valid_mismatch_count);
        $fdisplay(out_summary_fd, "parser_direct_data_mismatch_count=%0d", parser_direct_data_mismatch_count);
        $fdisplay(out_summary_fd, "parser_direct_channel_mismatch_count=%0d", parser_direct_channel_mismatch_count);
        $fdisplay(out_summary_fd, "output_id_mismatch_count=%0d", output_id_mismatch_count);
        $fdisplay(out_summary_fd, "parser_data_mismatch_count=%0d", parser_data_mismatch_count);
        $fdisplay(out_summary_fd, "hit_channel_mismatch_count=%0d", hit_channel_mismatch_count);
        $fdisplay(out_summary_fd, "parser_cycle_mismatch_count=%0d", parser_cycle_mismatch_count);
        $fdisplay(out_summary_fd, "frame_mark_mismatch_count=%0d", frame_mark_mismatch_count);
        $fdisplay(out_summary_fd, "queue_underflow_count=%0d", queue_underflow_count);
        $fdisplay(out_summary_fd, "drain_waited_cycles=%0d", drain_waited);
        $fdisplay(out_summary_fd, "raw_event_count_remaining=%0d", raw_event_count);
        $fdisplay(out_summary_fd, "emu_event_count_remaining=%0d", emu_event_count);
        $fdisplay(out_summary_fd, "raw_accept_q_remaining=%0d", raw_accept_q.size());
        $fdisplay(out_summary_fd, "emu_accept_q_remaining=%0d", emu_accept_q.size());
        $fdisplay(out_summary_fd, "raw_obs_q_remaining=%0d", raw_obs_q.size());
        $fdisplay(out_summary_fd, "emu_obs_q_remaining=%0d", emu_obs_q.size());

        $display("SUMMARY mode=%s rate_cfg=%0d offered=%0d raw_acc=%0d emu_acc=%0d raw_out=%0d emu_out=%0d accept_mismatch=%0d data_mismatch=%0d cycle_mismatch=%0d frame_mark_mismatch=%0d",
                 short_mode ? "short" : "long", rate_cfg, offered_total, raw_accepted_total, emu_accepted_total,
                 raw_output_total, emu_output_total, accept_mismatch_count, parser_data_mismatch_count,
                 parser_cycle_mismatch_count, frame_mark_mismatch_count);

        if (tx_mismatch_count != 0)
            $fatal(1, "tx mismatch count %0d", tx_mismatch_count);
        if (parser_valid_mismatch_count != 0)
            $fatal(1, "parser valid mismatch count %0d", parser_valid_mismatch_count);
        if (parser_direct_data_mismatch_count != 0)
            $fatal(1, "parser direct data mismatch count %0d", parser_direct_data_mismatch_count);
        if (parser_direct_channel_mismatch_count != 0)
            $fatal(1, "parser direct channel mismatch count %0d", parser_direct_channel_mismatch_count);
        if (queue_underflow_count != 0)
            $fatal(1, "queue underflow count %0d", queue_underflow_count);
        if (raw_event_count != 10'd0 || emu_event_count != 10'd0)
            $fatal(1, "event_count not drained raw=%0d emu=%0d", raw_event_count, emu_event_count);

        $fclose(out_csv_fd);
        $fclose(out_summary_fd);
        $finish;
    end
endmodule
