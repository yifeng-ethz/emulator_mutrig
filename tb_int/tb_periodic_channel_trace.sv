// tb_periodic_channel_trace.sv
// Focused diagnostic for the PERIODIC single-channel injection path.
// Instantiates frontend_trigger_engine + be_mutrig_lane_emitter and the
// type0 emitter, drives the engine exactly like emulator_mutrig.sv wires it,
// and traces:
//   * N (CLUSTER_FIX low=high) -> emitted per-ASIC channel (hit_word[47:43])
//   * histogram bin = asic_id<<5 | channel
//   * periodic fire rate (hits per microsecond) for a chosen hit_rate
// This is a TB-only diagnostic; it drives nothing in any production DUT.

`timescale 1ns/1ps

import frontend_ticket_bus_pkg::*;
import be_mutrig_pkg::*;

module tb_periodic_channel_trace;

    localparam real CLK_NS = 8.0;   // 125 MHz emulator/backend clock
    logic clk = 1'b0;
    logic rst = 1'b1;
    always #(CLK_NS/2) clk = ~clk;

    // ---- engine config (mirrors emulator_mutrig.sv wiring) -------------
    logic        cfg_global_enable      = 1'b1;
    logic        run_generating         = 1'b0;
    logic        inject_pulse           = 1'b0;
    logic        cfg_hit_mode_sig       = 1'b0;   // internal
    logic        cfg_internal_sub_mode  = 1'b1;   // periodic
    logic        cfg_cluster_geom_mode  = 1'b0;   // FIXED geometry (not random)
    logic [15:0] cfg_hit_rate           = 16'h0000;
    logic [7:0]  cfg_hit_channel_low    = 8'd0;
    logic [7:0]  cfg_hit_channel_high   = 8'd0;
    logic [7:0]  cfg_cluster_size_random= 8'd1;
    logic [1:0]  cfg_mirror_mode        = 2'b00;
    logic signed [7:0] cfg_mirror_offset= 8'sd0;
    logic [7:0]  cfg_random_center_seed = 8'd0;
    logic [31:0] cfg_prng_seed          = 32'hDEAD_BEEF;
    logic [14:0] tcc_anchor             = 15'd1;
    logic [14:0] ecc_anchor             = 15'd1;

    // ---- engine <-> emitter ticket bus --------------------------------
    logic             sig_offer_valid;
    logic [0:0]       sig_offer_lane;     // LANE_COUNT=1 -> width 1 (clog2(2)=1)
    frontend_ticket_t sig_offer_ticket;
    logic             sig_offer_ready;
    logic [15:0]      ticket_overflow_count;
    logic [7:0]       engine_busy_high_water;

    frontend_trigger_engine #(.LANE_COUNT(1)) u_engine (
        .clk(clk), .rst(rst),
        .cfg_global_enable(cfg_global_enable),
        .run_generating(run_generating),
        .inject_pulse(inject_pulse),
        .cfg_hit_mode_sig(cfg_hit_mode_sig),
        .cfg_internal_sub_mode(cfg_internal_sub_mode),
        .cfg_cluster_geom_mode(cfg_cluster_geom_mode),
        .cfg_hit_rate(cfg_hit_rate),
        .cfg_hit_channel_low(cfg_hit_channel_low),
        .cfg_hit_channel_high(cfg_hit_channel_high),
        .cfg_cluster_size_random(cfg_cluster_size_random),
        .cfg_mirror_mode(cfg_mirror_mode),
        .cfg_mirror_offset(cfg_mirror_offset),
        .cfg_random_center_seed(cfg_random_center_seed),
        .cfg_prng_seed(cfg_prng_seed),
        .tcc_anchor(tcc_anchor),
        .ecc_anchor(ecc_anchor),
        .sig_offer_valid(sig_offer_valid),
        .sig_offer_lane(sig_offer_lane),
        .sig_offer_ticket(sig_offer_ticket),
        .sig_offer_ready(sig_offer_ready),
        .ticket_overflow_count(ticket_overflow_count),
        .engine_busy_high_water(engine_busy_high_water)
    );

    // ---- lane emitter (ticket -> 48b L2 hit word) ---------------------
    logic        emit_enable = 1'b1;
    logic        frame_count_pulse = 1'b0;
    logic        l2_rd_en;
    logic [47:0] l2_rd_data;
    logic        l2_rd_valid;
    logic        l2_empty, l2_full, l2_almost_full;
    logic [9:0]  l2_event_count;
    logic [3:0]  dbg_tkt_lvl;
    logic [9:0]  dbg_l2_lvl;
    logic [63:0] frame_count, hit_count;
    logic        fifo_full_sticky, ticket_overflow_sticky;

    // ticket_ready from emitter feeds engine sig_offer_ready
    logic        ticket_ready;
    assign sig_offer_ready = ticket_ready;

    be_mutrig_lane_emitter u_emitter (
        .clk(clk), .rst(rst),
        .enable(emit_enable),
        .cfg_prng_seed(cfg_prng_seed),
        .frame_count_pulse(frame_count_pulse),
        .ticket_data(sig_offer_ticket),
        .ticket_valid(sig_offer_valid),
        .ticket_ready(ticket_ready),
        .l2_rd_en(l2_rd_en),
        .l2_rd_data(l2_rd_data),
        .l2_rd_valid(l2_rd_valid),
        .l2_empty(l2_empty),
        .l2_full(l2_full),
        .l2_almost_full(l2_almost_full),
        .l2_event_count(l2_event_count),
        .debug_ticket_fifo_level(dbg_tkt_lvl),
        .debug_l2_fifo_level(dbg_l2_lvl),
        .frame_count(frame_count),
        .hit_count(hit_count),
        .clear_fifo_full_sticky(1'b0),
        .clear_ticket_overflow_sticky(1'b0),
        .fifo_full_sticky(fifo_full_sticky),
        .ticket_overflow_sticky(ticket_overflow_sticky)
    );

    // Drain the L2 FIFO continuously (model: type0 emitter pops a hit
    // whenever one is available). We capture the channel field of every
    // popped 48b word: hit_word[47:43] (== pack_hit_type0 data[40:36]).
    assign l2_rd_en = ~l2_empty;

    localparam int ASIC_ID = 0;   // single lane, asic_id_base = 0

    int unsigned emit_ch_count [0:31];
    int unsigned bin_count     [0:255];
    longint unsigned popped_total;

    // Sample popped words: l2_rd_valid is asserted the cycle AFTER l2_rd_en.
    always_ff @(posedge clk) begin
        if (rst) begin
            popped_total <= 0;
        end else if (l2_rd_valid) begin
            logic [4:0] ch;
            logic [7:0] bin;
            ch  = l2_rd_data[47:43];
            bin = (ASIC_ID << 5) | ch;
            emit_ch_count[ch] <= emit_ch_count[ch] + 1;
            bin_count[bin]    <= bin_count[bin] + 1;
            popped_total      <= popped_total + 1;
        end
    end

    // --------------------------------------------------------------------
    task automatic clear_counts();
        for (int i = 0; i < 32; i++)  emit_ch_count[i] = 0;
        for (int i = 0; i < 256; i++) bin_count[i] = 0;
        popped_total = 0;
    endtask

    // Run periodic injection for a window with CLUSTER_FIX low=high=N.
    // Returns the dominant emitted channel and its bin.
    task automatic run_one(input int n_chan, input int unsigned rate,
                           input int unsigned cycles,
                           output int dom_ch, output int dom_bin,
                           output longint unsigned tot);
        // emulator_mutrig.sv left-half mapping: left_enable=1 ->
        //   cfg_hit_channel_low/high = {1'b0, geom_fix_left_low/high[6:0]}
        // For N in 0..31 (ASIC0 channels) low=high=N.
        cfg_hit_channel_low  = n_chan[7:0];
        cfg_hit_channel_high = n_chan[7:0];
        cfg_hit_rate         = rate[15:0];
        cfg_cluster_geom_mode= 1'b0;   // fixed
        cfg_internal_sub_mode= 1'b1;   // periodic
        cfg_hit_mode_sig     = 1'b0;   // internal
        clear_counts();
        run_generating = 1'b1;
        repeat (cycles) @(posedge clk);
        run_generating = 1'b0;
        repeat (64) @(posedge clk);   // drain
        // pick dominant channel
        dom_ch = -1; dom_bin = -1; tot = popped_total;
        begin
            int best; best = 0;
            for (int i = 0; i < 32; i++) begin
                if (emit_ch_count[i] > best) begin
                    best = emit_ch_count[i];
                    dom_ch = i;
                end
            end
        end
        if (dom_ch >= 0) dom_bin = (ASIC_ID << 5) | dom_ch;
    endtask

    // Same as run_one but with geom_mode selectable (1 = RANDOM cluster).
    task automatic run_one_geom(input int n_chan, input int unsigned rate,
                                input int unsigned cycles, input bit geom_random,
                                input int unsigned size_rnd, input logic [1:0] mir_mode,
                                output int dom_ch, output int dom_bin,
                                output longint unsigned tot);
        cfg_hit_channel_low  = n_chan[7:0];
        cfg_hit_channel_high = n_chan[7:0];
        cfg_hit_rate         = rate[15:0];
        cfg_cluster_geom_mode= geom_random;
        cfg_cluster_size_random = size_rnd[7:0];
        cfg_mirror_mode      = mir_mode;
        cfg_internal_sub_mode= 1'b1;
        cfg_hit_mode_sig     = 1'b0;
        clear_counts();
        run_generating = 1'b1;
        repeat (cycles) @(posedge clk);
        run_generating = 1'b0;
        repeat (64) @(posedge clk);
        dom_ch = -1; dom_bin = -1; tot = popped_total;
        begin
            int best; best = 0;
            for (int i = 0; i < 32; i++)
                if (emit_ch_count[i] > best) begin best = emit_ch_count[i]; dom_ch = i; end
        end
        if (dom_ch >= 0) dom_bin = (ASIC_ID << 5) | dom_ch;
    endtask

    int    test_n  [0:6];
    int    res_ch  [0:6];
    int    res_bin [0:6];
    longint unsigned res_tot [0:6];
    int    n_nonzero_ch [0:6];

    initial begin
        clear_counts();
        repeat (10) @(posedge clk);
        rst = 1'b0;
        repeat (10) @(posedge clk);

        // ============ TASK A: channel -> emitted -> bin table =========
        $display("==== TASK A: N -> emitted_channel -> bin (PERIODIC, FIXED geom) ====");
        test_n[0]=0; test_n[1]=1; test_n[2]=2; test_n[3]=5;
        test_n[4]=10; test_n[5]=20; test_n[6]=31;
        for (int t = 0; t < 7; t++) begin
            int dc, db; longint unsigned tt;
            run_one(test_n[t], 16'h1000 /*rate*/, 20000, dc, db, tt);
            res_ch[t]  = dc;  res_bin[t] = db;  res_tot[t] = tt;
            n_nonzero_ch[t] = 0;
            for (int i = 0; i < 32; i++) if (emit_ch_count[i] != 0) n_nonzero_ch[t]++;
            $display("[A] N=%0d : emitted_dom_ch=%0d  bin=%0d  total_hits=%0d  nonzero_chans=%0d",
                     test_n[t], dc, db, tt, n_nonzero_ch[t]);
            // dump non-zero channels to expose any spread
            for (int i = 0; i < 32; i++)
                if (emit_ch_count[i] != 0)
                    $display("[A]      ch[%0d] = %0d hits  (bin %0d)", i, emit_ch_count[i], (ASIC_ID<<5)|i);
        end

        $display("==== TASK A SUMMARY TABLE ====");
        $display("   N  | emitted_ch | bin | nonzero_chans | bin==N?");
        for (int t = 0; t < 7; t++)
            $display("  %3d |    %3d     | %3d |      %3d      |   %s",
                     test_n[t], res_ch[t], res_bin[t], n_nonzero_ch[t],
                     (res_bin[t] == test_n[t]) ? "YES" : "NO");

        // ============ TASK B: periodic rate calibration ===============
        // Measure hits per cycle for several hit_rate values. The engine
        // fires when a 16-bit phase accumulator overflows, so the
        // steady-state fire rate = hit_rate / 65536 launches/cycle. Each
        // launch with low==high produces ONE hit. But back-pressure: a new
        // launch only happens when !engine_occupied, so the engine cannot
        // exceed ~1 hit per pipeline-drain (geom->launch->shred->offer +
        // emitter). Measure the ACTUAL achieved rate.
        $display("==== TASK B: periodic rate vs hit_rate (single channel N=10) ====");
        begin
            int unsigned rates [0:4];
            rates[0]=8; rates[1]=42; rates[2]=256; rates[3]=4096; rates[4]=16384;
            for (int r = 0; r < 5; r++) begin
                int dc, db; longint unsigned tt;
                int unsigned win;
                win = 100000;   // cycles
                run_one(10, rates[r], win, dc, db, tt);
                // hits per microsecond: win cycles @ 8ns = win*8 ns = win*8/1000 us
                $display("[B] hit_rate=%0d : hits=%0d/%0d cyc => %0.5f hits/cyc | @125MHz=%0.1f kHz @156.25MHz=%0.1f kHz | ideal@156.25=%0.1f kHz",
                         rates[r], tt, win, real'(tt)/real'(win),
                         real'(tt)/real'(win) * 125000.0,
                         real'(tt)/real'(win) * 156250.0,
                         real'(rates[r])/65536.0 * 156250.0);
            end
        end

        // ============ TASK C: RANDOM cluster geom (hypothesis for HW) ===
        // If the host set SIGNAL bit2 (cluster_geom_mode=1), the fixed
        // low/high channel is IGNORED and the engine emits a PRNG-centered
        // cluster (size from CLUSTER_RANDOM). This produces a SPREAD/offset
        // that is NOT bin==N. Run the same N values in RANDOM mode to see
        // if it reproduces the HW "10->7 / 20->nothing / saturate" signature.
        $display("==== TASK C: RANDOM cluster geom (cfg_cluster_geom_mode=1) ====");
        for (int t = 0; t < 7; t++) begin
            int dc, db; longint unsigned tt;
            // size_rnd=4 (default), mirror_mode=10b (default) per frontend_csr reset
            run_one_geom(test_n[t], 16'h1000, 20000, 1'b1, 8'd4, 2'b10, dc, db, tt);
            n_nonzero_ch[t] = 0;
            for (int i = 0; i < 32; i++) if (emit_ch_count[i] != 0) n_nonzero_ch[t]++;
            $display("[C] N=%0d (RANDOM) : dom_ch=%0d bin=%0d total=%0d nonzero_chans=%0d  -> NOT a single-channel delta",
                     test_n[t], dc, db, tt, n_nonzero_ch[t]);
            for (int i = 0; i < 32; i++)
                if (emit_ch_count[i] != 0)
                    $display("[C]      ch[%0d]=%0d", i, emit_ch_count[i]);
        end

        $display("==== DONE ====");
        $finish;
    end

    initial begin
        #50_000_000;
        $display("TIMEOUT");
        $finish;
    end

endmodule
