// hit_generator.sv
// Compact MuTRiG event source with one RAM-backed L2 FIFO per lane.
// Version : 26.1.1
// Date    : 20260417
// Change  : Collapse the generator to one RAM-backed L2 FIFO per lane so the shared 8-lane bank closes the <4000 ALM area target while keeping the shared-cluster replay behavior.
//
// External behavior intentionally stays aligned with the existing emulator:
//   - frame_assembler still sees a single dequeue/data/event-count interface
//   - the directed TB compatibility mirrors hit_wr_en/hit_wr_data/fifo_* remain
//   - burst and inject handling still support the shared global cluster domain
//
// Area strategy:
//   - one 48-bit x FIFO_DEPTH lane-local L2 FIFO inferred into M10Ks
//   - no per-channel staging RAMs and no per-group L1 FIFOs
//   - one emitted hit candidate per active clock

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
    localparam int FIFO_ALMOST_FULL_LVL =
        (FIFO_DEPTH > FIFO_ALMOST_FULL_MARGIN) ? (FIFO_DEPTH - FIFO_ALMOST_FULL_MARGIN) : FIFO_DEPTH;

    localparam int PRNG1_WIDTH = 21;
    localparam int PRNG2_WIDTH = 5;
    localparam logic [PRNG1_WIDTH-1:0] PRNG1_MUL = 21'h064E6D;
    localparam logic [PRNG1_WIDTH-1:0] PRNG1_INC = 21'h003039;
    localparam logic [PRNG2_WIDTH-1:0] PRNG2_MUL = 5'h0D;
    localparam logic [PRNG2_WIDTH-1:0] PRNG2_INC = 5'h15;
    localparam logic [PRNG2_WIDTH-1:0] PRNG2_SEED_XOR = 5'h0F;

    logic [47:0] l2_fifo_mem [0:FIFO_DEPTH-1];

    logic [PRNG1_WIDTH-1:0] prng_state;
    logic [PRNG2_WIDTH-1:0] prng2_state;
    logic [GLOBAL_CHANNEL_WIDTH-1:0] scan_pos;
    logic [4:0] burst_remaining;
    logic [GLOBAL_CHANNEL_WIDTH-1:0] burst_global_ch;
    logic [7:0] burst_cooldown;
    logic inject_burst_pending;

    // Directed TB compatibility mirrors.
    logic [FIFO_PTR_WIDTH-1:0] fifo_wr_ptr;
    logic [FIFO_PTR_WIDTH-1:0] fifo_rd_ptr;
    logic [FIFO_COUNT_WIDTH-1:0] fifo_count;
    logic                     hit_wr_en;
    logic [47:0]              hit_wr_data;

    // The frame assembler always consumes the long-word layout. Short-mode
    // normalization happens later during packet assembly.
    logic unused_cfg_short_mode;
    assign unused_cfg_short_mode = cfg_short_mode;

    function automatic logic [4:0] normalized_cluster_size(input logic [4:0] size);
        if (size == 5'd0)
            return 5'd1;
        return size;
    endfunction

    function automatic int unsigned normalized_lane_count(input logic [3:0] lane_count);
        int unsigned lane_count_v;

        lane_count_v = lane_count;
        if (lane_count_v < 1)
            lane_count_v = 1;
        else if (lane_count_v > MAX_EMU_LANES)
            lane_count_v = MAX_EMU_LANES;
        return lane_count_v;
    endfunction

    function automatic int unsigned domain_channel_count(
        input logic       cross_asic,
        input logic [3:0] lane_count
    );
        if (!cross_asic)
            return N_CHANNELS;
        return normalized_lane_count(lane_count) * N_CHANNELS;
    endfunction

    function automatic int unsigned lane_base_channel(
        input logic        cross_asic,
        input logic [3:0]  lane_index,
        input logic [3:0]  lane_count
    );
        int unsigned lane_count_v;
        int unsigned lane_index_v;

        if (!cross_asic)
            return 0;

        lane_count_v = normalized_lane_count(lane_count);
        lane_index_v = lane_index;
        if (lane_index_v >= lane_count_v)
            lane_index_v = lane_count_v - 1;
        return lane_index_v * N_CHANNELS;
    endfunction

    function automatic int unsigned clamp_cluster_start(
        input int unsigned center,
        input logic [4:0]  size,
        input int unsigned domain_channels
    );
        int unsigned size_clamped;
        int unsigned half_size;
        int unsigned max_start;

        size_clamped = normalized_cluster_size(size);
        half_size    = size_clamped / 2;
        max_start    = domain_channels - size_clamped;

        if (center <= half_size)
            return 0;
        if ((center - half_size) > max_start)
            return max_start;
        return center - half_size;
    endfunction

    function automatic logic [47:0] build_l2_hit(input logic [4:0] channel);
        return pack_hit_long(
            .channel  (channel),
            .t_badhit (1'b0),
            .tcc      (tcc_lfsr),
            .t_fine   (prng_state[4:0]),
            .e_badhit (1'b0),
            .e_flag   (1'b1),
            .ecc      (ecc_lfsr),
            .e_fine   (prng2_state[4:0])
        );
    endfunction

    always_comb begin : fifo_status_comb
        integer fifo_count_v;

        fifo_empty       = (fifo_count == FIFO_COUNT_WIDTH'(0));
        fifo_full        = (fifo_count == FIFO_COUNT_WIDTH'(FIFO_DEPTH));
        fifo_almost_full = (fifo_count >= FIFO_COUNT_WIDTH'(FIFO_ALMOST_FULL_LVL));

        fifo_count_v = fifo_count;
        if (fifo_count_v > 1023)
            event_count = 10'd1023;
        else
            event_count = fifo_count_v[9:0];
    end

    always_ff @(posedge clk) begin : datapath_state
        int unsigned domain_channels_v;
        int unsigned lane_base_v;
        int unsigned configured_center_v;
        int unsigned candidate_global_ch_v;
        int unsigned candidate_local_ch_v;
        int unsigned burst_start_v;
        int unsigned cluster_size_v;
        logic [4:0] candidate_ch_v;
        logic [47:0] candidate_word_v;
        logic [PRNG1_WIDTH-1:0] prng_state_next_v;
        logic [PRNG2_WIDTH-1:0] prng2_state_next_v;
        logic [4:0] burst_remaining_next_v;
        logic [GLOBAL_CHANNEL_WIDTH-1:0] burst_global_next_v;
        logic [7:0] burst_cooldown_next_v;
        logic inject_burst_pending_next_v;
        logic consume_cluster_word_v;
        logic candidate_local_valid_v;
        logic l2_push_valid_v;
        logic l2_pop_valid_v;

        if (rst) begin
            prng_state           <= cfg_prng_seed[PRNG1_WIDTH-1:0];
            prng2_state          <= cfg_prng_seed[20:16] ^ PRNG2_SEED_XOR;
            scan_pos             <= '0;
            burst_remaining      <= '0;
            burst_global_ch      <= '0;
            burst_cooldown       <= '0;
            inject_burst_pending <= 1'b0;
            fifo_wr_ptr          <= '0;
            fifo_rd_ptr          <= '0;
            fifo_count           <= '0;
            fifo_data            <= '0;
            hit_wr_en            <= 1'b0;
            hit_wr_data          <= '0;
        end else begin
            hit_wr_en           <= 1'b0;
            l2_push_valid_v = 1'b0;

            if (enable) begin
                domain_channels_v   = domain_channel_count(cfg_cluster_cross_asic, cfg_cluster_lane_count);
                lane_base_v         = lane_base_channel(cfg_cluster_cross_asic, cfg_cluster_lane_index, cfg_cluster_lane_count);
                configured_center_v = cfg_cluster_cross_asic ? cfg_cluster_center_global : cfg_burst_center;
                cluster_size_v      = normalized_cluster_size(cfg_burst_size);

                prng_state_next_v  = prng_state * PRNG1_MUL + PRNG1_INC;
                prng2_state_next_v = prng2_state * PRNG2_MUL + PRNG2_INC;
                prng_state         <= prng_state_next_v;
                prng2_state        <= prng2_state_next_v;

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

                consume_cluster_word_v = 1'b0;
                candidate_local_valid_v = 1'b0;
                candidate_global_ch_v = 0;
                candidate_local_ch_v = 0;
                candidate_ch_v = '0;
                candidate_word_v = '0;
                burst_start_v = 0;

                case (hit_mode_t'(cfg_hit_mode))
                    HIT_MODE_POISSON: begin
                        if (inject_burst_pending_next_v && (burst_remaining == 5'd0)) begin
                            burst_start_v = clamp_cluster_start(configured_center_v, cfg_burst_size, domain_channels_v);
                            inject_burst_pending_next_v = 1'b0;
                            consume_cluster_word_v = 1'b1;
                            candidate_global_ch_v = burst_start_v;
                            burst_remaining_next_v = cluster_size_v - 1;
                            if (burst_start_v < (domain_channels_v - 1))
                                burst_global_next_v = GLOBAL_CHANNEL_WIDTH'(burst_start_v + 1);
                            else
                                burst_global_next_v = GLOBAL_CHANNEL_WIDTH'(burst_start_v);
                        end else if (burst_remaining != 5'd0) begin
                            consume_cluster_word_v = 1'b1;
                            candidate_global_ch_v = burst_global_ch;
                            burst_remaining_next_v = burst_remaining - 1;
                            if (burst_global_ch < GLOBAL_CHANNEL_WIDTH'(domain_channels_v - 1))
                                burst_global_next_v = burst_global_ch + GLOBAL_CHANNEL_WIDTH'(1);
                            else
                                burst_global_next_v = burst_global_ch;
                        end else if (prng_state[15:0] < cfg_hit_rate) begin
                            burst_start_v = clamp_cluster_start(scan_pos, cfg_burst_size, domain_channels_v);
                            consume_cluster_word_v = 1'b1;
                            candidate_global_ch_v = burst_start_v;
                            burst_remaining_next_v = cluster_size_v - 1;
                            if (burst_start_v < (domain_channels_v - 1))
                                burst_global_next_v = GLOBAL_CHANNEL_WIDTH'(burst_start_v + 1);
                            else
                                burst_global_next_v = GLOBAL_CHANNEL_WIDTH'(burst_start_v);
                        end
                    end

                    HIT_MODE_BURST: begin
                        if (inject_burst_pending_next_v && (burst_remaining == 5'd0)) begin
                            burst_start_v = clamp_cluster_start(configured_center_v, cfg_burst_size, domain_channels_v);
                            inject_burst_pending_next_v = 1'b0;
                            consume_cluster_word_v = 1'b1;
                            candidate_global_ch_v = burst_start_v;
                            burst_remaining_next_v = cluster_size_v - 1;
                            if (burst_start_v < (domain_channels_v - 1))
                                burst_global_next_v = GLOBAL_CHANNEL_WIDTH'(burst_start_v + 1);
                            else
                                burst_global_next_v = GLOBAL_CHANNEL_WIDTH'(burst_start_v);
                        end else if (burst_remaining != 5'd0) begin
                            consume_cluster_word_v = 1'b1;
                            candidate_global_ch_v = burst_global_ch;
                            burst_remaining_next_v = burst_remaining - 1;
                            if (burst_global_ch < GLOBAL_CHANNEL_WIDTH'(domain_channels_v - 1))
                                burst_global_next_v = burst_global_ch + GLOBAL_CHANNEL_WIDTH'(1);
                            else
                                burst_global_next_v = burst_global_ch;
                        end else if (burst_cooldown_next_v == 8'd0) begin
                            burst_start_v = clamp_cluster_start(configured_center_v, cfg_burst_size, domain_channels_v);
                            consume_cluster_word_v = 1'b1;
                            candidate_global_ch_v = burst_start_v;
                            burst_remaining_next_v = cluster_size_v - 1;
                            if (burst_start_v < (domain_channels_v - 1))
                                burst_global_next_v = GLOBAL_CHANNEL_WIDTH'(burst_start_v + 1);
                            else
                                burst_global_next_v = GLOBAL_CHANNEL_WIDTH'(burst_start_v);
                            burst_cooldown_next_v = 8'd200;
                        end
                    end

                    HIT_MODE_NOISE: begin
                        if (inject_burst_pending_next_v && (burst_remaining == 5'd0)) begin
                            burst_start_v = clamp_cluster_start(configured_center_v, cfg_burst_size, domain_channels_v);
                            inject_burst_pending_next_v = 1'b0;
                            consume_cluster_word_v = 1'b1;
                            candidate_global_ch_v = burst_start_v;
                            burst_remaining_next_v = cluster_size_v - 1;
                            if (burst_start_v < (domain_channels_v - 1))
                                burst_global_next_v = GLOBAL_CHANNEL_WIDTH'(burst_start_v + 1);
                            else
                                burst_global_next_v = GLOBAL_CHANNEL_WIDTH'(burst_start_v);
                        end else if (burst_remaining != 5'd0) begin
                            consume_cluster_word_v = 1'b1;
                            candidate_global_ch_v = burst_global_ch;
                            burst_remaining_next_v = burst_remaining - 1;
                            if (burst_global_ch < GLOBAL_CHANNEL_WIDTH'(domain_channels_v - 1))
                                burst_global_next_v = burst_global_ch + GLOBAL_CHANNEL_WIDTH'(1);
                            else
                                burst_global_next_v = burst_global_ch;
                        end else if (prng_state[15:0] < cfg_noise_rate) begin
                            candidate_local_valid_v = 1'b1;
                            candidate_local_ch_v = {prng_state[20:19], prng_state[4:2]};
                            candidate_ch_v = CHANNEL_WIDTH'(candidate_local_ch_v);
                        end
                    end

                    default: begin
                        if (inject_burst_pending_next_v && (burst_remaining == 5'd0)) begin
                            burst_start_v = clamp_cluster_start(configured_center_v, cfg_burst_size, domain_channels_v);
                            inject_burst_pending_next_v = 1'b0;
                            consume_cluster_word_v = 1'b1;
                            candidate_global_ch_v = burst_start_v;
                            burst_remaining_next_v = cluster_size_v - 1;
                            if (burst_start_v < (domain_channels_v - 1))
                                burst_global_next_v = GLOBAL_CHANNEL_WIDTH'(burst_start_v + 1);
                            else
                                burst_global_next_v = GLOBAL_CHANNEL_WIDTH'(burst_start_v);
                        end else if (burst_remaining != 5'd0) begin
                            consume_cluster_word_v = 1'b1;
                            candidate_global_ch_v = burst_global_ch;
                            burst_remaining_next_v = burst_remaining - 1;
                            if (burst_global_ch < GLOBAL_CHANNEL_WIDTH'(domain_channels_v - 1))
                                burst_global_next_v = burst_global_ch + GLOBAL_CHANNEL_WIDTH'(1);
                            else
                                burst_global_next_v = burst_global_ch;
                        end else if (prng_state[15:0] < cfg_hit_rate) begin
                            burst_start_v = clamp_cluster_start(scan_pos, cfg_burst_size, domain_channels_v);
                            consume_cluster_word_v = 1'b1;
                            candidate_global_ch_v = burst_start_v;
                            burst_remaining_next_v = cluster_size_v - 1;
                            if (burst_start_v < (domain_channels_v - 1))
                                burst_global_next_v = GLOBAL_CHANNEL_WIDTH'(burst_start_v + 1);
                            else
                                burst_global_next_v = GLOBAL_CHANNEL_WIDTH'(burst_start_v);
                        end else if (burst_cooldown_next_v == 8'd0) begin
                            burst_start_v = clamp_cluster_start(configured_center_v, cfg_burst_size, domain_channels_v);
                            consume_cluster_word_v = 1'b1;
                            candidate_global_ch_v = burst_start_v;
                            burst_remaining_next_v = cluster_size_v - 1;
                            if (burst_start_v < (domain_channels_v - 1))
                                burst_global_next_v = GLOBAL_CHANNEL_WIDTH'(burst_start_v + 1);
                            else
                                burst_global_next_v = GLOBAL_CHANNEL_WIDTH'(burst_start_v);
                            burst_cooldown_next_v = 8'd200;
                        end
                    end
                endcase

                if (consume_cluster_word_v) begin
                    if ((candidate_global_ch_v >= lane_base_v) &&
                        (candidate_global_ch_v < (lane_base_v + N_CHANNELS))) begin
                        candidate_local_valid_v = 1'b1;
                        candidate_local_ch_v = candidate_global_ch_v - lane_base_v;
                        candidate_ch_v = CHANNEL_WIDTH'(candidate_local_ch_v);
                    end
                end

                burst_cooldown       <= burst_cooldown_next_v;
                inject_burst_pending <= inject_burst_pending_next_v;
                burst_remaining      <= burst_remaining_next_v;
                burst_global_ch      <= burst_global_next_v;

                if (candidate_local_valid_v && !fifo_full) begin
                    candidate_word_v = build_l2_hit(candidate_ch_v);
                    l2_push_valid_v = 1'b1;
                    hit_wr_en              <= 1'b1;
                    hit_wr_data            <= candidate_word_v;
                    l2_fifo_mem[fifo_wr_ptr] <= candidate_word_v;
                    fifo_wr_ptr            <= fifo_wr_ptr + FIFO_PTR_WIDTH'(1);
                end
            end

            l2_pop_valid_v = fifo_rd_en && !fifo_empty;
            if (l2_pop_valid_v) begin
                fifo_data   <= l2_fifo_mem[fifo_rd_ptr];
                fifo_rd_ptr <= fifo_rd_ptr + FIFO_PTR_WIDTH'(1);
            end

            case ({l2_push_valid_v, l2_pop_valid_v})
                2'b10:   fifo_count <= fifo_count + FIFO_COUNT_WIDTH'(1);
                2'b01:   fifo_count <= fifo_count - FIFO_COUNT_WIDTH'(1);
                default: fifo_count <= fifo_count;
            endcase
        end
    end

endmodule
