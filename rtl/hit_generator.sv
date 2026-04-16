// hit_generator.sv
// Raw-contract-oriented MuTRiG event source and 4xL1 + 1xL2 buffering model
// Version : 26.0.3
// Date    : 20260416
// Change  : Add an optional shared cluster domain so one emulated hit cluster can span adjacent MuTRiG instances while preserving the single-ASIC default path.
//
// This model intentionally keeps the external emulator interface unchanged:
//   - frame_assembler still sees a single L2-style dequeue interface
//   - directed TB hooks such as hit_wr_en/hit_wr_data and fifo_* compatibility
//     mirrors remain available
//
// Internal structure follows the verified raw MuTRiG datapath contract:
//   channel staging slots -> per-group round-robin -> 4x L1 FIFOs ->
//   group master select / MS select -> shared L2 FIFO -> frame generator.

module hit_generator
    import emulator_mutrig_pkg::*;
#(
    parameter int FIFO_DEPTH = RAW_FIFO_DEPTH
)(
    input  logic        clk,
    input  logic        rst,
    input  logic        enable,

    // Configuration
    input  logic [1:0]  cfg_hit_mode,
    input  logic [15:0] cfg_hit_rate,
    input  logic [4:0]  cfg_burst_size,
    input  logic [4:0]  cfg_burst_center,
    input  logic        cfg_cluster_cross_asic,
    input  logic [7:0]  cfg_cluster_center_global,
    input  logic [3:0]  cfg_cluster_lane_index,
    input  logic [3:0]  cfg_cluster_lane_count,
    input  logic [15:0] cfg_noise_rate,
    input  logic [31:0] cfg_prng_seed,
    input  logic        cfg_short_mode,
    input  logic        inject_pulse,

    // Coarse time reference
    input  logic [14:0] tcc_lfsr,
    input  logic [14:0] ecc_lfsr,

    // L2 dequeue interface to the frame assembler
    input  logic        fifo_rd_en,
    output logic [47:0] fifo_data,
    output logic [9:0]  event_count,
    output logic        fifo_empty,
    output logic        fifo_full,
    output logic        fifo_almost_full
);

    localparam int FIFO_PTR_WIDTH       = (FIFO_DEPTH > 1) ? $clog2(FIFO_DEPTH) : 1;
    localparam int FIFO_COUNT_WIDTH     = FIFO_PTR_WIDTH + 1;
    localparam int GROUP_PTR_WIDTH      = (N_GROUPS > 1) ? $clog2(N_GROUPS) : 1;
    localparam int CHAN_PTR_WIDTH       = (N_CHAN_PER_GROUP > 1) ? $clog2(N_CHAN_PER_GROUP) : 1;
    localparam int GLOBAL_CHANNELS_MAX  = MAX_EMU_LANES * N_CHANNELS;
    localparam int FIFO_ALMOST_FULL_LVL =
        (FIFO_DEPTH > FIFO_ALMOST_FULL_MARGIN) ? (FIFO_DEPTH - FIFO_ALMOST_FULL_MARGIN) : FIFO_DEPTH;

    // ========================================
    // PRNGs and compatibility debug state
    // ========================================
    localparam int PRNG1_WIDTH = 21;
    localparam int PRNG2_WIDTH = 5;
    localparam logic [PRNG1_WIDTH-1:0] PRNG1_MUL = 21'h064E6D;
    localparam logic [PRNG1_WIDTH-1:0] PRNG1_INC = 21'h003039;
    localparam logic [PRNG2_WIDTH-1:0] PRNG2_MUL = 5'h0D;
    localparam logic [PRNG2_WIDTH-1:0] PRNG2_INC = 5'h15;
    localparam logic [PRNG2_WIDTH-1:0] PRNG2_SEED_XOR = 5'h0F;

    logic [PRNG1_WIDTH-1:0]      prng_state;
    logic [PRNG2_WIDTH-1:0]      prng2_state;
    logic [GLOBAL_CHANNEL_WIDTH-1:0] scan_pos;
    logic [4:0]                  burst_remaining;
    logic [GLOBAL_CHANNEL_WIDTH-1:0] burst_global_ch;
    logic [7:0]                  burst_cooldown;
    logic                        inject_burst_pending;

    // Directed TB compatibility mirrors.
    logic [FIFO_PTR_WIDTH-1:0] fifo_wr_ptr;
    logic [FIFO_PTR_WIDTH-1:0] fifo_rd_ptr;
    logic [FIFO_COUNT_WIDTH-1:0] fifo_count;
    logic                     hit_wr_en;
    logic [47:0]              hit_wr_data;

    // ========================================
    // Raw-style channel staging and FIFOs
    // ========================================
    logic [HIT_L1_WIDTH-1:0] src_slot_data   [0:N_CHANNELS-1];
    logic                    src_slot_valid  [0:N_CHANNELS-1];

    logic [HIT_L1_WIDTH-1:0] l1_fifo_mem     [0:N_GROUPS-1][0:FIFO_DEPTH-1];
    logic [FIFO_PTR_WIDTH-1:0] l1_fifo_wr_ptr[0:N_GROUPS-1];
    logic [FIFO_PTR_WIDTH-1:0] l1_fifo_rd_ptr[0:N_GROUPS-1];
    logic [FIFO_COUNT_WIDTH-1:0] l1_fifo_count[0:N_GROUPS-1];
    logic [CHAN_PTR_WIDTH-1:0] l1_rr_ptr     [0:N_GROUPS-1];

    logic [47:0]             l2_fifo_mem     [0:FIFO_DEPTH-1];
    logic [GROUP_PTR_WIDTH-1:0] l2_rr_ptr;

    logic                    l1_push_valid_c [0:N_GROUPS-1];
    logic [HIT_L1_WIDTH-1:0] l1_push_word_c  [0:N_GROUPS-1];
    logic [4:0]              l1_pop_chan_c   [0:N_GROUPS-1];
    logic [CHAN_PTR_WIDTH-1:0] l1_rr_next_c  [0:N_GROUPS-1];
    logic                    l2_push_valid_c;
    logic [47:0]             l2_push_word_c;
    logic [GROUP_PTR_WIDTH-1:0] l2_push_group_c;

    integer                  dropped_src_slot_count;

    function automatic logic [4:0] normalized_cluster_size(input logic [4:0] size);
        if (size == 5'd0)
            return 5'd1;
        return size;
    endfunction

    function automatic int normalized_lane_count(input logic [3:0] lane_count);
        int lane_count_i;

        lane_count_i = lane_count;
        if (lane_count_i < 1)
            lane_count_i = 1;
        else if (lane_count_i > MAX_EMU_LANES)
            lane_count_i = MAX_EMU_LANES;
        return lane_count_i;
    endfunction

    function automatic int domain_channel_count(
        input logic       cross_asic,
        input logic [3:0] lane_count
    );
        if (!cross_asic)
            return N_CHANNELS;
        return normalized_lane_count(lane_count) * N_CHANNELS;
    endfunction

    function automatic int lane_base_channel(
        input logic       cross_asic,
        input logic [3:0] lane_index,
        input logic [3:0] lane_count
    );
        int lane_index_i;
        int lane_count_i;

        if (!cross_asic)
            return 0;

        lane_count_i = normalized_lane_count(lane_count);
        lane_index_i = lane_index;
        if (lane_index_i < 0)
            lane_index_i = 0;
        else if (lane_index_i >= lane_count_i)
            lane_index_i = lane_count_i - 1;
        return lane_index_i * N_CHANNELS;
    endfunction

    function automatic int clamp_cluster_start(
        input int         center,
        input logic [4:0] size,
        input int         domain_channels
    );
        int size_clamped;
        int half_size;
        int max_start;

        size_clamped = normalized_cluster_size(size);
        half_size    = size_clamped / 2;
        max_start    = domain_channels - size_clamped;

        if (center <= half_size)
            return 0;
        if ((center - half_size) > max_start)
            return max_start;
        return center - half_size;
    endfunction

    function automatic logic [HIT_L1_WIDTH-1:0] build_l1_hit(input logic [4:0] channel);
        logic [14:0] tcc_slave;
        logic [14:0] ecc_slave;

        tcc_slave = prbs15_step(tcc_lfsr);
        ecc_slave = prbs15_step(ecc_lfsr);

        return pack_hit_l1(
            .channel    (channel),
            .tcc_master (tcc_lfsr),
            .tcc_slave  (tcc_slave),
            .t_fine     (prng_state[4:0]),
            .t_badhit   (1'b0),
            .ecc_master (ecc_lfsr),
            .ecc_slave  (ecc_slave),
            .e_fine     (prng2_state[4:0]),
            .e_badhit   (1'b0),
            .e_flag     (1'b1)
        );
    endfunction

    // The directed short-mode test only checks the short payload fields derived
    // from the long-format positions, so the internal buffered representation
    // stays in raw long-word form even in short mode.
    logic unused_cfg_short_mode;
    assign unused_cfg_short_mode = cfg_short_mode;

    // ========================================
    // Arbitration / promotion intent
    // ========================================
    always_comb begin : arbitrate_comb
        int group_idx;
        int search_idx;
        int chan_idx;
        int selected_chan;
        int selected_group;

        for (group_idx = 0; group_idx < N_GROUPS; group_idx++) begin
            l1_push_valid_c[group_idx] = 1'b0;
            l1_push_word_c[group_idx]  = '0;
            l1_pop_chan_c[group_idx]   = '0;
            l1_rr_next_c[group_idx]    = l1_rr_ptr[group_idx];

            if (l1_fifo_count[group_idx] < FIFO_ALMOST_FULL_LVL) begin
                selected_chan = -1;
                for (search_idx = 0; search_idx < N_CHAN_PER_GROUP; search_idx++) begin
                    chan_idx = group_idx * N_CHAN_PER_GROUP +
                               ((l1_rr_ptr[group_idx] + search_idx) % N_CHAN_PER_GROUP);
                    if (selected_chan < 0 && src_slot_valid[chan_idx])
                        selected_chan = chan_idx;
                end

                if (selected_chan >= 0) begin
                    l1_push_valid_c[group_idx] = 1'b1;
                    l1_push_word_c[group_idx]  = src_slot_data[selected_chan];
                    l1_pop_chan_c[group_idx]   = selected_chan[4:0];
                    l1_rr_next_c[group_idx]    = CHAN_PTR_WIDTH'((selected_chan % N_CHAN_PER_GROUP) + 1);
                end
            end
        end

        l2_push_valid_c = 1'b0;
        l2_push_word_c  = '0;
        l2_push_group_c = l2_rr_ptr;

        if (fifo_count < FIFO_ALMOST_FULL_LVL) begin
            selected_group = -1;
            for (search_idx = 0; search_idx < N_GROUPS; search_idx++) begin
                group_idx = (l2_rr_ptr + search_idx) % N_GROUPS;
                if (selected_group < 0 && (l1_fifo_count[group_idx] != '0))
                    selected_group = group_idx;
            end

            if (selected_group >= 0) begin
                l2_push_valid_c = 1'b1;
                l2_push_group_c = GROUP_PTR_WIDTH'(selected_group);
                l2_push_word_c  = l1_to_l2_word(
                    l1_fifo_mem[selected_group][l1_fifo_rd_ptr[selected_group]],
                    MS_LIMITS_DEFAULT,
                    1'b0
                );
            end
        end
    end

    // ========================================
    // L2 dequeue/status view
    // ========================================
    always_comb begin
        integer fifo_count_v;

        fifo_empty       = (fifo_count == '0);
        fifo_almost_full = (fifo_count >= FIFO_ALMOST_FULL_LVL);
        fifo_full        = fifo_almost_full;

        fifo_count_v = fifo_count;
        if (fifo_count_v > 1023)
            event_count = 10'd1023;
        else
            event_count = fifo_count_v[9:0];
    end

    // ========================================
    // Datapath state
    // ========================================
    always_ff @(posedge clk) begin : datapath_state
        int group_idx;
        int chan_idx;
        int domain_channels_v;
        int lane_base_v;
        int configured_center_v;
        int candidate_global_ch_v;
        int candidate_local_ch_v;
        int burst_start_v;
        int cluster_size_v;
        logic [4:0] candidate_ch;
        logic [HIT_L1_WIDTH-1:0] candidate_l1_word;
        logic [47:0] candidate_l2_word;
        logic candidate_accept;
        logic l2_pop_valid;
        logic pop_this_group;
        logic consume_cluster_word_v;
        logic [4:0] burst_remaining_next_v;
        logic [GLOBAL_CHANNEL_WIDTH-1:0] burst_global_next_v;
        logic [7:0] burst_cooldown_next_v;
        logic inject_burst_pending_next_v;

        if (rst) begin
            prng_state            <= cfg_prng_seed[PRNG1_WIDTH-1:0];
            prng2_state           <= cfg_prng_seed[20:16] ^ PRNG2_SEED_XOR;
            scan_pos              <= '0;
            burst_remaining       <= '0;
            burst_global_ch       <= '0;
            burst_cooldown        <= '0;
            inject_burst_pending  <= 1'b0;
            fifo_wr_ptr           <= '0;
            fifo_rd_ptr           <= '0;
            fifo_count            <= '0;
            fifo_data             <= '0;
            hit_wr_en             <= 1'b0;
            hit_wr_data           <= '0;
            l2_rr_ptr             <= '0;
            dropped_src_slot_count <= 0;

            for (chan_idx = 0; chan_idx < N_CHANNELS; chan_idx++) begin
                src_slot_data[chan_idx]  <= '0;
                src_slot_valid[chan_idx] <= 1'b0;
            end

            for (group_idx = 0; group_idx < N_GROUPS; group_idx++) begin
                l1_fifo_wr_ptr[group_idx] <= '0;
                l1_fifo_rd_ptr[group_idx] <= '0;
                l1_fifo_count[group_idx]  <= '0;
                l1_rr_ptr[group_idx]      <= '0;
            end
        end else begin
            hit_wr_en <= 1'b0;

            // -------------------------------
            // Analog/frontend hit generation
            // -------------------------------
            if (enable) begin
                domain_channels_v = domain_channel_count(cfg_cluster_cross_asic, cfg_cluster_lane_count);
                lane_base_v       = lane_base_channel(cfg_cluster_cross_asic, cfg_cluster_lane_index, cfg_cluster_lane_count);
                configured_center_v = cfg_cluster_cross_asic ? cfg_cluster_center_global : cfg_burst_center;
                cluster_size_v      = normalized_cluster_size(cfg_burst_size);

                prng_state <= prng_state * PRNG1_MUL + PRNG1_INC;
                prng2_state <= prng2_state * PRNG2_MUL + PRNG2_INC;
                if (scan_pos >= GLOBAL_CHANNEL_WIDTH'(domain_channels_v - 1))
                    scan_pos <= '0;
                else
                    scan_pos <= scan_pos + GLOBAL_CHANNEL_WIDTH'(1);

                burst_cooldown_next_v       = burst_cooldown;
                inject_burst_pending_next_v = inject_burst_pending | inject_pulse;
                burst_remaining_next_v      = burst_remaining;
                burst_global_next_v         = burst_global_ch;

                if (burst_cooldown_next_v != 8'd0)
                    burst_cooldown_next_v = burst_cooldown_next_v - 8'd1;

                candidate_accept      = 1'b0;
                candidate_ch          = '0;
                candidate_l1_word     = '0;
                candidate_l2_word     = '0;
                candidate_global_ch_v = 0;
                candidate_local_ch_v  = 0;
                burst_start_v         = 0;
                consume_cluster_word_v = 1'b0;

                case (hit_mode_t'(cfg_hit_mode))
                    HIT_MODE_POISSON: begin
                        if (inject_burst_pending_next_v && (burst_remaining == 5'd0)) begin
                            burst_start_v = clamp_cluster_start(configured_center_v, cfg_burst_size, domain_channels_v);
                            inject_burst_pending_next_v = 1'b0;
                            consume_cluster_word_v = 1'b1;
                            candidate_global_ch_v = burst_start_v;
                            burst_remaining_next_v = cluster_size_v - 5'd1;
                            burst_global_next_v = GLOBAL_CHANNEL_WIDTH'((burst_start_v < (domain_channels_v - 1)) ? (burst_start_v + 1) : burst_start_v);
                        end else if (burst_remaining != 5'd0) begin
                            consume_cluster_word_v = 1'b1;
                            candidate_global_ch_v = burst_global_ch;
                            burst_remaining_next_v = burst_remaining - 5'd1;
                            burst_global_next_v = (burst_global_ch < GLOBAL_CHANNEL_WIDTH'(domain_channels_v - 1)) ?
                                (burst_global_ch + GLOBAL_CHANNEL_WIDTH'(1)) : burst_global_ch;
                        end else if (prng_state[15:0] < cfg_hit_rate) begin
                            burst_start_v = clamp_cluster_start(scan_pos, cfg_burst_size, domain_channels_v);
                            consume_cluster_word_v = 1'b1;
                            candidate_global_ch_v = burst_start_v;
                            burst_remaining_next_v = cluster_size_v - 5'd1;
                            burst_global_next_v = GLOBAL_CHANNEL_WIDTH'((burst_start_v < (domain_channels_v - 1)) ? (burst_start_v + 1) : burst_start_v);
                        end
                    end

                    HIT_MODE_BURST: begin
                        if (inject_burst_pending_next_v && (burst_remaining == 5'd0)) begin
                            burst_start_v = clamp_cluster_start(configured_center_v, cfg_burst_size, domain_channels_v);
                            inject_burst_pending_next_v = 1'b0;
                            consume_cluster_word_v = 1'b1;
                            candidate_global_ch_v = burst_start_v;
                            burst_remaining_next_v = cluster_size_v - 5'd1;
                            burst_global_next_v = GLOBAL_CHANNEL_WIDTH'((burst_start_v < (domain_channels_v - 1)) ? (burst_start_v + 1) : burst_start_v);
                        end else if (burst_remaining != 5'd0) begin
                            consume_cluster_word_v = 1'b1;
                            candidate_global_ch_v = burst_global_ch;
                            burst_remaining_next_v = burst_remaining - 5'd1;
                            burst_global_next_v = (burst_global_ch < GLOBAL_CHANNEL_WIDTH'(domain_channels_v - 1)) ?
                                (burst_global_ch + GLOBAL_CHANNEL_WIDTH'(1)) : burst_global_ch;
                        end else if (burst_cooldown_next_v == 8'd0) begin
                            burst_start_v = clamp_cluster_start(configured_center_v, cfg_burst_size, domain_channels_v);
                            consume_cluster_word_v = 1'b1;
                            candidate_global_ch_v = burst_start_v;
                            burst_remaining_next_v = cluster_size_v - 5'd1;
                            burst_global_next_v = GLOBAL_CHANNEL_WIDTH'((burst_start_v < (domain_channels_v - 1)) ? (burst_start_v + 1) : burst_start_v);
                            burst_cooldown_next_v = 8'd200;
                        end
                    end

                    HIT_MODE_NOISE: begin
                        if (inject_burst_pending_next_v && (burst_remaining == 5'd0)) begin
                            burst_start_v = clamp_cluster_start(configured_center_v, cfg_burst_size, domain_channels_v);
                            inject_burst_pending_next_v = 1'b0;
                            consume_cluster_word_v = 1'b1;
                            candidate_global_ch_v = burst_start_v;
                            burst_remaining_next_v = cluster_size_v - 5'd1;
                            burst_global_next_v = GLOBAL_CHANNEL_WIDTH'((burst_start_v < (domain_channels_v - 1)) ? (burst_start_v + 1) : burst_start_v);
                        end else if (burst_remaining != 5'd0) begin
                            consume_cluster_word_v = 1'b1;
                            candidate_global_ch_v = burst_global_ch;
                            burst_remaining_next_v = burst_remaining - 5'd1;
                            burst_global_next_v = (burst_global_ch < GLOBAL_CHANNEL_WIDTH'(domain_channels_v - 1)) ?
                                (burst_global_ch + GLOBAL_CHANNEL_WIDTH'(1)) : burst_global_ch;
                        end else if (prng_state[15:0] < cfg_noise_rate) begin
                            candidate_local_ch_v = {prng_state[20:19], prng_state[4:2]};
                            candidate_global_ch_v = lane_base_v + candidate_local_ch_v;
                        end
                    end

                    default: begin
                        if (inject_burst_pending_next_v && (burst_remaining == 5'd0)) begin
                            burst_start_v = clamp_cluster_start(configured_center_v, cfg_burst_size, domain_channels_v);
                            inject_burst_pending_next_v = 1'b0;
                            consume_cluster_word_v = 1'b1;
                            candidate_global_ch_v = burst_start_v;
                            burst_remaining_next_v = cluster_size_v - 5'd1;
                            burst_global_next_v = GLOBAL_CHANNEL_WIDTH'((burst_start_v < (domain_channels_v - 1)) ? (burst_start_v + 1) : burst_start_v);
                        end else if (burst_remaining != 5'd0) begin
                            consume_cluster_word_v = 1'b1;
                            candidate_global_ch_v = burst_global_ch;
                            burst_remaining_next_v = burst_remaining - 5'd1;
                            burst_global_next_v = (burst_global_ch < GLOBAL_CHANNEL_WIDTH'(domain_channels_v - 1)) ?
                                (burst_global_ch + GLOBAL_CHANNEL_WIDTH'(1)) : burst_global_ch;
                        end else if (prng_state[15:0] < cfg_hit_rate) begin
                            burst_start_v = clamp_cluster_start(scan_pos, cfg_burst_size, domain_channels_v);
                            consume_cluster_word_v = 1'b1;
                            candidate_global_ch_v = burst_start_v;
                            burst_remaining_next_v = cluster_size_v - 5'd1;
                            burst_global_next_v = GLOBAL_CHANNEL_WIDTH'((burst_start_v < (domain_channels_v - 1)) ? (burst_start_v + 1) : burst_start_v);
                        end else if (burst_cooldown_next_v == 8'd0) begin
                            burst_start_v = clamp_cluster_start(configured_center_v, cfg_burst_size, domain_channels_v);
                            consume_cluster_word_v = 1'b1;
                            candidate_global_ch_v = burst_start_v;
                            burst_remaining_next_v = cluster_size_v - 5'd1;
                            burst_global_next_v = GLOBAL_CHANNEL_WIDTH'((burst_start_v < (domain_channels_v - 1)) ? (burst_start_v + 1) : burst_start_v);
                            burst_cooldown_next_v = 8'd200;
                        end
                    end
                endcase

                if (consume_cluster_word_v) begin
                    if ((candidate_global_ch_v >= lane_base_v) && (candidate_global_ch_v < (lane_base_v + N_CHANNELS)))
                        candidate_local_ch_v = candidate_global_ch_v - lane_base_v;
                    else
                        candidate_local_ch_v = -1;
                end

                if (!consume_cluster_word_v && (hit_mode_t'(cfg_hit_mode) == HIT_MODE_NOISE) && (prng_state[15:0] < cfg_noise_rate)) begin
                    if (!src_slot_valid[candidate_local_ch_v]) begin
                        candidate_accept = 1'b1;
                        candidate_ch = CHANNEL_WIDTH'(candidate_local_ch_v);
                    end else begin
                        dropped_src_slot_count <= dropped_src_slot_count + 1;
                    end
                end else if (consume_cluster_word_v && (candidate_local_ch_v >= 0)) begin
                    candidate_ch = CHANNEL_WIDTH'(candidate_local_ch_v);
                    if (!src_slot_valid[candidate_ch]) begin
                        candidate_accept = 1'b1;
                    end else begin
                        dropped_src_slot_count <= dropped_src_slot_count + 1;
                    end
                end

                burst_cooldown       <= burst_cooldown_next_v;
                inject_burst_pending <= inject_burst_pending_next_v;
                burst_remaining      <= burst_remaining_next_v;
                burst_global_ch      <= burst_global_next_v;

                if (candidate_accept) begin
                    candidate_l1_word = build_l1_hit(candidate_ch);
                    candidate_l2_word = l1_to_l2_word(candidate_l1_word, MS_LIMITS_DEFAULT, 1'b0);
                    src_slot_data[candidate_ch]  <= candidate_l1_word;
                    src_slot_valid[candidate_ch] <= 1'b1;
                    hit_wr_en                    <= 1'b1;
                    hit_wr_data                  <= candidate_l2_word;
                end
            end

            // ----------------------------------------
            // Per-group arbitration into four L1 FIFOs
            // ----------------------------------------
            for (group_idx = 0; group_idx < N_GROUPS; group_idx++) begin
                pop_this_group = l2_push_valid_c && (l2_push_group_c == GROUP_PTR_WIDTH'(group_idx));

                if (l1_push_valid_c[group_idx]) begin
                    l1_fifo_mem[group_idx][l1_fifo_wr_ptr[group_idx]] <= l1_push_word_c[group_idx];
                    l1_fifo_wr_ptr[group_idx] <= l1_fifo_wr_ptr[group_idx] + FIFO_PTR_WIDTH'(1);
                    src_slot_valid[l1_pop_chan_c[group_idx]] <= 1'b0;
                    l1_rr_ptr[group_idx] <= l1_rr_next_c[group_idx];
                end

                if (pop_this_group)
                    l1_fifo_rd_ptr[group_idx] <= l1_fifo_rd_ptr[group_idx] + FIFO_PTR_WIDTH'(1);

                case ({l1_push_valid_c[group_idx], pop_this_group})
                    2'b10: l1_fifo_count[group_idx] <= l1_fifo_count[group_idx] + FIFO_COUNT_WIDTH'(1);
                    2'b01: l1_fifo_count[group_idx] <= l1_fifo_count[group_idx] - FIFO_COUNT_WIDTH'(1);
                    default: l1_fifo_count[group_idx] <= l1_fifo_count[group_idx];
                endcase
            end

            // ----------------------------------------
            // Shared L2 arbitration and FIFO push
            // ----------------------------------------
            if (l2_push_valid_c && (fifo_count < FIFO_DEPTH)) begin
                l2_fifo_mem[fifo_wr_ptr] <= l2_push_word_c;
                fifo_wr_ptr <= fifo_wr_ptr + FIFO_PTR_WIDTH'(1);
                l2_rr_ptr   <= l2_push_group_c + GROUP_PTR_WIDTH'(1);
            end

            // ----------------------------------------
            // L2 dequeue to the frame assembler
            // ----------------------------------------
            l2_pop_valid = fifo_rd_en && (fifo_count != '0);
            if (l2_pop_valid) begin
                fifo_data   <= l2_fifo_mem[fifo_rd_ptr];
                fifo_rd_ptr <= fifo_rd_ptr + FIFO_PTR_WIDTH'(1);
            end

            case ({l2_push_valid_c && (fifo_count < FIFO_DEPTH), l2_pop_valid})
                2'b10: fifo_count <= fifo_count + FIFO_COUNT_WIDTH'(1);
                2'b01: fifo_count <= fifo_count - FIFO_COUNT_WIDTH'(1);
                default: fifo_count <= fifo_count;
            endcase
        end
    end

endmodule
