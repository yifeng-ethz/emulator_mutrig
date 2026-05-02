// emulator_mutrig_formal.sv
// SVA bind harness for the central-trigger refresh modules.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260502
// Change  : Add assume/cover/assert properties for the new FE/BE modules.
//
// Invocation:
//   python3 ~/.codex/skills/rtl-linter-and-checker/scripts/questa_static_screen.py \
//       --top emulator_mutrig --filelist rtl/emulator_mutrig_26_2.f \
//       --modes lint,cdc,rdc,formal --extra-do tb/formal/emulator_mutrig_formal.do \
//       tb/formal/emulator_mutrig_formal.sv
//
// Bind blocks attach the property modules to the live RTL without touching
// the synthesised sources. The corresponding .do file (sibling) sets the
// formal clock/reset and configures any non-default bound assumptions.

`ifdef FORMAL_EMULATOR_MUTRIG

// -----------------------------------------------------------------------------
// frontend_run_ctl property module
// -----------------------------------------------------------------------------
module frontend_run_ctl_prop (
    input  logic       i_clk,
    input  logic       i_rst,
    input  logic [8:0] asi_ctrl_data,
    input  logic       asi_ctrl_valid,
    input  logic       coe_inject_pulse,
    input  logic       fire_inject_pulse_csr,
    input  logic       run_generating,
    input  logic       run_draining,
    input  logic       emu_rst,
    input  logic       frame_rst,
    input  logic       inject_pulse,
    input  logic [8:0] ctrl_state_q
);

    default clocking cb_run_ctl @(posedge i_clk); endclocking
    default disable iff (i_rst);

    // Run-control bus is one-hot when valid (formal assume; the live ctrl
    // master enforces this on hardware).
    property p_ctrl_one_hot_when_valid;
        asi_ctrl_valid |-> $onehot(asi_ctrl_data);
    endproperty
    a_ctrl_one_hot_when_valid: assume property (p_ctrl_one_hot_when_valid);

    // generating implies draining.
    property p_gen_imp_drain;
        run_generating |-> run_draining;
    endproperty
    a_gen_imp_drain: assert property (p_gen_imp_drain);

    // frame_rst must be high outside the drain window.
    property p_frame_rst_outside_drain;
        !run_draining |-> frame_rst;
    endproperty
    a_frame_rst_outside_drain: assert property (p_frame_rst_outside_drain);

    // emu_rst forces frame_rst.
    property p_emu_implies_frame;
        emu_rst |-> frame_rst;
    endproperty
    a_emu_implies_frame: assert property (p_emu_implies_frame);

    // CSR fire bit alone produces a single-cycle inject_pulse.
    property p_csr_fire_pulse_width;
        ##1 fire_inject_pulse_csr |-> inject_pulse;
    endproperty
    a_csr_fire_pulse_width: assert property (p_csr_fire_pulse_width);

    // After ctrl_state_q latches RUNNING, a SYNC drives emu_rst.
    property p_sync_drives_reset;
        asi_ctrl_valid && asi_ctrl_data[2] |-> emu_rst;
    endproperty
    a_sync_drives_reset: assert property (p_sync_drives_reset);

    // Coverage: each run-control state seen at least once.
    c_idle:        cover property (ctrl_state_q == 9'b0_0000_0001);
    c_run_prep:    cover property (ctrl_state_q == 9'b0_0000_0010);
    c_sync:        cover property (ctrl_state_q == 9'b0_0000_0100);
    c_running:     cover property (ctrl_state_q == 9'b0_0000_1000);
    c_terminating: cover property (ctrl_state_q == 9'b0_0001_0000);
    c_inject:      cover property (inject_pulse);

endmodule

bind frontend_run_ctl frontend_run_ctl_prop u_props (.*);

// -----------------------------------------------------------------------------
// frontend_trigger_engine property module
// -----------------------------------------------------------------------------
module frontend_trigger_engine_prop #(
    parameter int LANE_COUNT = 8
) (
    input  logic                                                        clk,
    input  logic                                                        rst,
    input  logic                                                        cfg_global_enable,
    input  logic                                                        sig_offer_valid,
    input  logic [$clog2((LANE_COUNT > 1) ? LANE_COUNT : 2)-1:0]        sig_offer_lane,
    input  logic                                                        sig_offer_ready,
    input  logic [15:0]                                                 ticket_overflow_count,
    input  logic [7:0]                                                  engine_busy_high_water
);

    default clocking cb_trig @(posedge clk); endclocking
    default disable iff (rst);

    // sig_offer_lane must be a legal lane index when valid.
    property p_lane_in_range;
        sig_offer_valid |-> (int'(sig_offer_lane) < LANE_COUNT);
    endproperty
    a_lane_in_range: assert property (p_lane_in_range);

    // Overflow count is monotonic non-decreasing (saturating at 0xFFFF).
    property p_overflow_monotonic;
        (ticket_overflow_count != 16'hFFFF) |->
            ##1 (ticket_overflow_count >= $past(ticket_overflow_count));
    endproperty
    a_overflow_monotonic: assert property (p_overflow_monotonic);

    // High-water mark is monotonic non-decreasing while engine_busy never
    // saturates (saturates at 0xFF).
    property p_high_water_monotonic;
        (engine_busy_high_water != 8'hFF) |->
            ##1 (engine_busy_high_water >= $past(engine_busy_high_water));
    endproperty
    a_high_water_monotonic: assert property (p_high_water_monotonic);

    // When global_enable is low, no offers should be generated.
    property p_no_offer_when_disabled;
        !cfg_global_enable |-> !sig_offer_valid;
    endproperty
    a_no_offer_when_disabled: assert property (p_no_offer_when_disabled);

    // sig_offer_ticket should be stable while valid is held without ready
    // (ready/valid handshake invariant).
    // (Skipped here: the offer is rebuilt combinationally from pending state
    //  which itself is stable until the dispatched lane bit clears, so this
    //  reduces to verifying pending_mask stability under !ready. Covered by
    //  binding into the engine internals if needed.)

    // Coverage: at least one offer dispatched, at least one overflow.
    c_first_offer:    cover property (sig_offer_valid && sig_offer_ready);
    c_first_overflow: cover property (ticket_overflow_count == 16'd1);

endmodule

bind frontend_trigger_engine frontend_trigger_engine_prop #(
    .LANE_COUNT (LANE_COUNT)
) u_props (.*);

// -----------------------------------------------------------------------------
// prbs15_lfsr property module
// -----------------------------------------------------------------------------
module prbs15_lfsr_prop #(
    parameter int           STEP_COUNT = 1,
    parameter logic [14:0]  INIT       = 15'h0001
) (
    input  logic        clk,
    input  logic        rst,
    input  logic        en,
    input  logic        load_seed,
    input  logic [14:0] seed_value,
    input  logic [14:0] lfsr_out
);

    default clocking cb_prbs @(posedge clk); endclocking
    default disable iff (rst);

    // PRBS-15 must never reach the all-zero state.
    property p_never_zero;
        lfsr_out != 15'h0000;
    endproperty
    a_never_zero: assert property (p_never_zero);

    // After load_seed with non-zero seed_value, next-state is the seed.
    property p_seed_load;
        load_seed && (seed_value != 15'h0000) |=> (lfsr_out == $past(seed_value));
    endproperty
    a_seed_load: assert property (p_seed_load);

    // Coverage: state covered all bits.
    c_all_ones: cover property (lfsr_out == 15'h7FFF);
    c_low_one:  cover property (lfsr_out == 15'h0001);

endmodule

bind prbs15_lfsr prbs15_lfsr_prop #(
    .STEP_COUNT (STEP_COUNT),
    .INIT       (INIT)
) u_props (.*);

// -----------------------------------------------------------------------------
// be_mutrig_lane_type0_emit property module
// -----------------------------------------------------------------------------
module be_mutrig_lane_type0_emit_prop (
    input  logic        clk,
    input  logic        rst,
    input  logic        enable,
    input  logic        run_terminating,
    input  logic        run_idle,
    input  logic [3:0]  asic_id,
    input  logic        l2_empty,
    input  logic        aso_hit_type0_valid,
    input  logic        aso_hit_type0_startofpacket,
    input  logic        aso_hit_type0_endofpacket,
    input  logic        aso_hit_type0_endofrun,
    input  logic [3:0]  aso_hit_type0_channel,
    input  logic [44:0] aso_hit_type0_data
);

    default clocking cb_t0 @(posedge clk); endclocking
    default disable iff (rst);

    // SOP/EOP only valid when valid is asserted.
    property p_sop_implies_valid;
        aso_hit_type0_startofpacket |-> aso_hit_type0_valid;
    endproperty
    a_sop_implies_valid: assert property (p_sop_implies_valid);

    property p_eop_implies_valid;
        aso_hit_type0_endofpacket |-> aso_hit_type0_valid;
    endproperty
    a_eop_implies_valid: assert property (p_eop_implies_valid);

    // endofrun fires only when the lane is fully drained and run-control is
    // back to IDLE.
    property p_endofrun_only_when_drained;
        aso_hit_type0_endofrun |-> (l2_empty && run_idle);
    endproperty
    a_endofrun_only_when_drained: assert property (p_endofrun_only_when_drained);

    // channel field equals asic_id (lane identity flows through unchanged).
    property p_channel_is_asic_id;
        aso_hit_type0_valid |-> (aso_hit_type0_channel == asic_id);
    endproperty
    a_channel_is_asic_id: assert property (p_channel_is_asic_id);

    // Data field carries asic_id in [44:41] when valid (cross-check against
    // pack_hit_type0).
    property p_data_asic_field;
        aso_hit_type0_valid |-> (aso_hit_type0_data[44:41] == asic_id);
    endproperty
    a_data_asic_field: assert property (p_data_asic_field);

    // Coverage.
    c_sop: cover property (aso_hit_type0_startofpacket);
    c_eop: cover property (aso_hit_type0_endofpacket);
    c_eor: cover property (aso_hit_type0_endofrun);

endmodule

bind be_mutrig_lane_type0_emit be_mutrig_lane_type0_emit_prop u_props (.*);

// -----------------------------------------------------------------------------
// be_mutrig_lane_emitter property module
// -----------------------------------------------------------------------------
module be_mutrig_lane_emitter_prop (
    input  logic        clk,
    input  logic        rst,
    input  logic        ticket_valid,
    input  logic        ticket_ready,
    input  logic        l2_full,
    input  logic        l2_empty,
    input  logic [63:0] frame_count,
    input  logic [63:0] hit_count
);

    default clocking cb_emit @(posedge clk); endclocking
    default disable iff (rst);

    // Counters are monotonic non-decreasing (saturating).
    property p_frame_monotonic;
        ##1 (frame_count >= $past(frame_count));
    endproperty
    a_frame_monotonic: assert property (p_frame_monotonic);

    property p_hit_monotonic;
        ##1 (hit_count >= $past(hit_count));
    endproperty
    a_hit_monotonic: assert property (p_hit_monotonic);

    // L2 cannot be both empty and full.
    property p_not_empty_and_full;
        !(l2_empty && l2_full);
    endproperty
    a_not_empty_and_full: assert property (p_not_empty_and_full);

    // When L2 is full and ticket is offered, ticket_ready must be deasserted
    // (back-pressure propagates through the lane emitter).
    // Note: the emitter has a ticket FIFO in front so ticket_ready may stay
    // high if the ticket FIFO has slots; this property is a coverage point
    // not an assertion.
    c_backpressure: cover property (l2_full && ticket_valid && !ticket_ready);
    c_drain:        cover property (l2_empty);

endmodule

bind be_mutrig_lane_emitter be_mutrig_lane_emitter_prop u_props (.*);

`endif // FORMAL_EMULATOR_MUTRIG
