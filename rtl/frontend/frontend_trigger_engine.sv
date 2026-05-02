// frontend_trigger_engine.sv
// Central signal trigger engine for emulator_mutrig.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260502
// Change  : Add Poisson/Periodic signal launch, random mirror geometry, and RR lane push.

module frontend_trigger_engine
    import frontend_ticket_bus_pkg::*;
#(
    parameter int LANE_COUNT = 8
) (
    input  logic             clk,
    input  logic             rst,
    input  logic             cfg_global_enable,
    input  logic             run_generating,
    input  logic             inject_pulse,
    input  logic             cfg_hit_mode_sig,
    input  logic             cfg_internal_sub_mode,
    input  logic             cfg_cluster_geom_mode,
    input  logic [15:0]      cfg_hit_rate,
    input  logic [7:0]       cfg_hit_channel_low,
    input  logic [7:0]       cfg_hit_channel_high,
    input  logic [7:0]       cfg_cluster_size_random,
    input  logic [1:0]       cfg_mirror_mode,
    input  logic signed [7:0] cfg_mirror_offset,
    input  logic [7:0]       cfg_random_center_seed,
    input  logic [31:0]      cfg_prng_seed,
    input  logic [14:0]      tcc_anchor,
    input  logic [14:0]      ecc_anchor,

    output logic             sig_offer_valid,
    output logic [$clog2((LANE_COUNT > 1) ? LANE_COUNT : 2)-1:0] sig_offer_lane,
    output frontend_ticket_t sig_offer_ticket,
    input  logic             sig_offer_ready,

    output logic [15:0]      ticket_overflow_count,
    output logic [7:0]       engine_busy_high_water
);

    localparam int LANE_INDEX_WIDTH = (LANE_COUNT > 1) ? $clog2(LANE_COUNT) : 1;

    logic [LANE_COUNT-1:0] pending_mask;
    logic [4:0] pending_ch_low [LANE_COUNT];
    logic [4:0] pending_ch_high [LANE_COUNT];
    logic [14:0] pending_tcc;
    logic [14:0] pending_ecc;
    logic [LANE_INDEX_WIDTH-1:0] rr_ptr;
    logic [LANE_INDEX_WIDTH-1:0] dispatch_base;
    logic [15:0] prng_state;
    logic [15:0] periodic_phase;
    logic [1:0] external_pending_count;
    logic [7:0] busy_run_count;
    logic       dispatch_found;
    logic [LANE_INDEX_WIDTH-1:0] dispatch_lane;

    function automatic logic [15:0] prng16_step(input logic [15:0] value);
        logic feedback_value;

        feedback_value = value[15] ^ value[13] ^ value[12] ^ value[10];
        return {value[14:0], feedback_value};
    endfunction

    function automatic logic [15:0] prng_seed_init(input logic [31:0] seed_word);
        logic [15:0] seed_value;

        seed_value = seed_word[15:0] ^ seed_word[31:16];
        if (seed_value == 16'h0000) begin
            seed_value = 16'h0001;
        end
        return seed_value;
    endfunction

    function automatic logic [7:0] random_size_clamped(input logic [7:0] raw_size);
        if (raw_size == 8'd0) begin
            return 8'd1;
        end
        if (raw_size > 8'd128) begin
            return 8'd128;
        end
        return raw_size;
    endfunction

    function automatic logic [7:0] clamp_start_128(input int signed center_value, input int unsigned size_value);
        int signed start_value;
        int signed max_start;

        max_start = 128 - int'(size_value);
        start_value = center_value - int'(size_value >> 1);
        if (start_value < 0) begin
            start_value = 0;
        end else if (start_value > max_start) begin
            start_value = max_start;
        end
        return start_value[7:0];
    endfunction

    function automatic logic [LANE_INDEX_WIDTH-1:0] lane_ptr_next(
        input logic [LANE_INDEX_WIDTH-1:0] lane_value
    );
        if (lane_value == LANE_INDEX_WIDTH'(LANE_COUNT - 1)) begin
            return '0;
        end
        return lane_value + LANE_INDEX_WIDTH'(1);
    endfunction

    always_comb begin
        dispatch_found = 1'b0;
        dispatch_lane = dispatch_base;
        for (int offset = 0; offset < LANE_COUNT; offset++) begin
            int candidate;

            candidate = (int'(dispatch_base) + offset) % LANE_COUNT;
            if (!dispatch_found && pending_mask[candidate]) begin
                dispatch_found = 1'b1;
                dispatch_lane = LANE_INDEX_WIDTH'(candidate);
            end
        end
    end

    assign sig_offer_valid = dispatch_found;
    assign sig_offer_lane = dispatch_lane;
    assign sig_offer_ticket.ch_low = pending_ch_low[dispatch_lane];
    assign sig_offer_ticket.ch_high = pending_ch_high[dispatch_lane];
    assign sig_offer_ticket.ts_a = pending_tcc;
    assign sig_offer_ticket.ts_b = pending_ecc;

    always_ff @(posedge clk) begin
        logic [15:0] prng_next;
        logic [16:0] phase_sum;
        logic        internal_active;
        logic        internal_fire;
        logic        launch_fire;
        logic        launch_random;
        logic [7:0]  cluster0_low;
        logic [7:0]  cluster0_high;
        logic [7:0]  cluster1_low;
        logic [7:0]  cluster1_high;
        logic        cluster1_valid;
        logic [7:0]  size_value;
        logic [7:0]  center_local;
        logic [7:0]  primary_start;
        logic [7:0]  mirror_start;
        logic        primary_right;
        int signed   mirror_center;
        int          lane_base;
        int          lane_limit;
        int          overlap_low;
        int          overlap_high;

        if (rst) begin
            pending_mask <= '0;
            for (int lane_idx = 0; lane_idx < LANE_COUNT; lane_idx++) begin
                pending_ch_low[lane_idx] <= '0;
                pending_ch_high[lane_idx] <= '0;
            end
            pending_tcc <= 15'h0001;
            pending_ecc <= 15'h0001;
            rr_ptr <= '0;
            dispatch_base <= '0;
            prng_state <= prng_seed_init(cfg_prng_seed);
            periodic_phase <= 16'h0000;
            external_pending_count <= 2'd0;
            ticket_overflow_count <= 16'h0000;
            busy_run_count <= 8'h00;
            engine_busy_high_water <= 8'h00;
        end else begin
            prng_next = prng16_step(prng_state);
            phase_sum = {1'b0, periodic_phase} + {1'b0, cfg_hit_rate};
            internal_active = cfg_global_enable && run_generating && !cfg_hit_mode_sig;
            internal_fire = 1'b0;
            launch_fire = 1'b0;
            launch_random = cfg_cluster_geom_mode;
            cluster0_low = 8'h00;
            cluster0_high = 8'h00;
            cluster1_low = 8'h00;
            cluster1_high = 8'h00;
            cluster1_valid = 1'b0;
            size_value = random_size_clamped(cfg_cluster_size_random);
            center_local = prng_state[7:0] + cfg_random_center_seed;
            center_local[7] = 1'b0;
            primary_start = 8'h00;
            mirror_start = 8'h00;
            primary_right = 1'b0;
            mirror_center = 0;

            if (cfg_global_enable) begin
                prng_state <= prng_next;
            end

            if (internal_active) begin
                if (!cfg_internal_sub_mode) begin
                    internal_fire = (prng_state < cfg_hit_rate);
                end else begin
                    internal_fire = phase_sum[16];
                    periodic_phase <= phase_sum[15:0];
                end
            end

            if (pending_mask != '0) begin
                if (busy_run_count != 8'hFF) begin
                    busy_run_count <= busy_run_count + 8'd1;
                end
                if (busy_run_count > engine_busy_high_water) begin
                    engine_busy_high_water <= busy_run_count;
                end
            end else begin
                busy_run_count <= 8'h00;
            end

            if (inject_pulse && (pending_mask != '0)) begin
                if (external_pending_count != 2'd2) begin
                    external_pending_count <= external_pending_count + 2'd1;
                end else if (ticket_overflow_count != 16'hFFFF) begin
                    ticket_overflow_count <= ticket_overflow_count + 16'd1;
                end
            end

            if ((pending_mask != '0) && sig_offer_valid && sig_offer_ready) begin
                pending_mask[dispatch_lane] <= 1'b0;
            end

            if (pending_mask == '0) begin
                if (inject_pulse) begin
                    launch_fire = cfg_global_enable;
                end else if (external_pending_count != 2'd0) begin
                    launch_fire = cfg_global_enable;
                    external_pending_count <= external_pending_count - 2'd1;
                end else if (internal_fire) begin
                    launch_fire = 1'b1;
                end

                if (launch_fire) begin
                    for (int lane_idx = 0; lane_idx < LANE_COUNT; lane_idx++) begin
                        pending_mask[lane_idx] <= 1'b0;
                        pending_ch_low[lane_idx] <= '0;
                        pending_ch_high[lane_idx] <= '0;
                    end

                    if (!launch_random) begin
                        cluster0_low = cfg_hit_channel_low;
                        if (cfg_hit_channel_high < cfg_hit_channel_low) begin
                            cluster0_high = cfg_hit_channel_low;
                        end else begin
                            cluster0_high = cfg_hit_channel_high;
                        end
                    end else begin
                        unique case (cfg_mirror_mode)
                            2'b00: primary_right = 1'b0;
                            2'b01: primary_right = 1'b1;
                            2'b10: primary_right = prng_state[8];
                            default: primary_right = 1'b0;
                        endcase

                        primary_start = clamp_start_128(int'({1'b0, center_local[6:0]}), size_value);
                        cluster0_low = primary_start + (primary_right ? 8'd128 : 8'd0);
                        cluster0_high = cluster0_low + size_value - 8'd1;

                        if (cfg_mirror_mode == 2'b10) begin
                            mirror_center = 127 - int'({1'b0, center_local[6:0]}) + int'(cfg_mirror_offset);
                            mirror_start = clamp_start_128(mirror_center, size_value);
                            cluster1_low = mirror_start + (primary_right ? 8'd0 : 8'd128);
                            cluster1_high = cluster1_low + size_value - 8'd1;
                            cluster1_valid = 1'b1;
                        end
                    end

                    for (int lane_idx = 0; lane_idx < LANE_COUNT; lane_idx++) begin
                        lane_base = lane_idx * 32;
                        lane_limit = lane_base + 31;

                        if ((int'(cluster0_low) <= lane_limit) && (int'(cluster0_high) >= lane_base)) begin
                            overlap_low = (int'(cluster0_low) > lane_base) ? int'(cluster0_low) : lane_base;
                            overlap_high = (int'(cluster0_high) < lane_limit) ? int'(cluster0_high) : lane_limit;
                            pending_mask[lane_idx] <= 1'b1;
                            pending_ch_low[lane_idx] <= 5'(overlap_low - lane_base);
                            pending_ch_high[lane_idx] <= 5'(overlap_high - lane_base);
                        end

                        if (cluster1_valid &&
                            (int'(cluster1_low) <= lane_limit) &&
                            (int'(cluster1_high) >= lane_base)) begin
                            overlap_low = (int'(cluster1_low) > lane_base) ? int'(cluster1_low) : lane_base;
                            overlap_high = (int'(cluster1_high) < lane_limit) ? int'(cluster1_high) : lane_limit;
                            pending_mask[lane_idx] <= 1'b1;
                            pending_ch_low[lane_idx] <= 5'(overlap_low - lane_base);
                            pending_ch_high[lane_idx] <= 5'(overlap_high - lane_base);
                        end
                    end

                    pending_tcc <= tcc_anchor;
                    pending_ecc <= ecc_anchor;
                    dispatch_base <= rr_ptr;
                    rr_ptr <= lane_ptr_next(rr_ptr);
                end
            end
        end
    end

endmodule
