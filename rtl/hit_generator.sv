// hit_generator.sv
// Configurable hit pattern generator for MuTRiG emulator
//
// Generates hits continuously (like a real TDC), filling a FIFO.
// The frame assembler drains the FIFO at frame boundaries.
//
// Hit patterns:
//   - Poisson: i.i.d. per-channel with configurable rate
//   - Burst:   periodic cluster hits on neighbouring channels
//   - Noise:   random dark-count-like hits
//   - Mixed:   combination of Poisson signal + burst clusters
//
// Uses LCG-based PRNG (Questa FSE has no rand/constraint support).

module hit_generator
    import emulator_mutrig_pkg::*;
#(
    parameter int FIFO_DEPTH = 64
)(
    input  logic        clk,
    input  logic        rst,

    // Configuration
    input  logic [1:0]  cfg_hit_mode,
    input  logic [15:0] cfg_hit_rate,       // per-cycle probability threshold (higher = more hits)
    input  logic [4:0]  cfg_burst_size,
    input  logic [4:0]  cfg_burst_center,
    input  logic [15:0] cfg_noise_rate,
    input  logic [31:0] cfg_prng_seed,
    input  logic        cfg_short_mode,

    // Coarse time reference
    input  logic [14:0] tcc_lfsr,
    input  logic [14:0] ecc_lfsr,

    // FIFO read interface
    input  logic        fifo_rd_en,
    output logic [47:0] fifo_data,
    output logic [9:0]  event_count,
    output logic        fifo_empty,
    output logic        fifo_full,

    // Frame boundary
    input  logic        frame_start
);

    // ========================================
    // LCG PRNG
    // ========================================
    logic [31:0] prng_state, prng2_state;
    logic [31:0] prng_next, prng2_next;

    assign prng_next  = prng_state * 32'h41C6_4E6D + 32'h0000_3039;
    assign prng2_next = prng2_state * 32'h0019_660D + 32'h0000_0D35;

    // ========================================
    // FIFO
    // ========================================
    logic [47:0] fifo_mem [0:FIFO_DEPTH-1];
    logic [$clog2(FIFO_DEPTH):0] fifo_wr_ptr, fifo_rd_ptr, fifo_count;

    logic        hit_wr_en;
    logic [47:0] hit_wr_data;

    assign fifo_empty = (fifo_count == 0);
    assign fifo_full  = (fifo_count >= FIFO_DEPTH);
    assign fifo_data  = fifo_mem[fifo_rd_ptr[$clog2(FIFO_DEPTH)-1:0]];

    always_ff @(posedge clk) begin
        if (rst) begin
            fifo_wr_ptr <= '0;
            fifo_rd_ptr <= '0;
            fifo_count  <= '0;
        end else begin
            if (hit_wr_en && !fifo_full) begin
                fifo_mem[fifo_wr_ptr[$clog2(FIFO_DEPTH)-1:0]] <= hit_wr_data;
                fifo_wr_ptr <= fifo_wr_ptr + 1;
            end
            if (fifo_rd_en && !fifo_empty)
                fifo_rd_ptr <= fifo_rd_ptr + 1;
            case ({hit_wr_en && !fifo_full, fifo_rd_en && !fifo_empty})
                2'b10:   fifo_count <= fifo_count + 1;
                2'b01:   fifo_count <= fifo_count - 1;
                default: fifo_count <= fifo_count;
            endcase
        end
    end

    // Event count: latched at frame_start
    always_ff @(posedge clk) begin
        if (rst)
            event_count <= '0;
        else if (frame_start)
            event_count <= (fifo_count > (FIFO_DEPTH-1)) ? 10'(FIFO_DEPTH-1) : 10'(fifo_count);
    end

    // ========================================
    // Continuous hit generation
    // ========================================
    // Scan channels 0..31 repeatedly, one channel per clock.
    // For each channel, compare PRNG against rate threshold.
    // This naturally produces Poisson-distributed hits per channel.

    logic [4:0]  scan_ch;
    logic [4:0]  burst_remaining;
    logic [4:0]  burst_ch;
    logic [7:0]  burst_cooldown;  // cycles between burst events
    logic        do_burst;

    always_ff @(posedge clk) begin
        if (rst) begin
            prng_state     <= cfg_prng_seed;
            prng2_state    <= {cfg_prng_seed[15:0], cfg_prng_seed[31:16]} ^ 32'hDEAD_BEEF;
            scan_ch        <= '0;
            burst_remaining <= '0;
            burst_ch        <= '0;
            burst_cooldown  <= '0;
            hit_wr_en      <= 1'b0;
            hit_wr_data    <= '0;
        end else begin
            hit_wr_en  <= 1'b0;
            prng_state <= prng_next;
            prng2_state <= prng2_next;
            scan_ch    <= scan_ch + 1;  // wraps at 31→0

            // Burst cooldown
            if (burst_cooldown > 0)
                burst_cooldown <= burst_cooldown - 1;

            // Determine if we should generate a hit this cycle
            do_burst = 1'b0;

            case (hit_mode_t'(cfg_hit_mode))
                HIT_MODE_POISSON: begin
                    if (prng_state[15:0] < cfg_hit_rate && !fifo_full) begin
                        hit_wr_en <= 1'b1;
                        hit_wr_data <= make_hit(scan_ch);
                    end
                end

                HIT_MODE_BURST: begin
                    // Generate burst of cluster hits periodically
                    if (burst_remaining > 0 && !fifo_full) begin
                        hit_wr_en       <= 1'b1;
                        hit_wr_data     <= make_hit(burst_ch);
                        burst_ch        <= burst_ch + 1;
                        burst_remaining <= burst_remaining - 1;
                    end else if (burst_cooldown == 0 && burst_remaining == 0) begin
                        // Start new burst
                        burst_remaining <= cfg_burst_size;
                        burst_ch        <= (cfg_burst_center >= cfg_burst_size/2) ?
                                           cfg_burst_center - cfg_burst_size/2 : 5'd0;
                        burst_cooldown  <= 8'd200;  // ~200 clocks between bursts
                    end
                end

                HIT_MODE_NOISE: begin
                    if (prng_state[15:0] < cfg_noise_rate && !fifo_full) begin
                        hit_wr_en <= 1'b1;
                        hit_wr_data <= make_hit(prng_state[20:16]); // random channel
                    end
                end

                HIT_MODE_MIXED: begin
                    // Poisson signal hits
                    if (prng_state[15:0] < cfg_hit_rate && !fifo_full) begin
                        hit_wr_en <= 1'b1;
                        hit_wr_data <= make_hit(scan_ch);
                    end
                    // Periodic burst (independent of Poisson)
                    else if (burst_remaining > 0 && !fifo_full) begin
                        hit_wr_en       <= 1'b1;
                        hit_wr_data     <= make_hit(burst_ch);
                        burst_ch        <= burst_ch + 1;
                        burst_remaining <= burst_remaining - 1;
                    end else if (burst_cooldown == 0 && burst_remaining == 0) begin
                        burst_remaining <= cfg_burst_size;
                        burst_ch        <= (cfg_burst_center >= cfg_burst_size/2) ?
                                           cfg_burst_center - cfg_burst_size/2 : 5'd0;
                        burst_cooldown  <= 8'd200;
                    end
                end
            endcase
        end
    end

    // ========================================
    // Hit data packing
    // ========================================
    function automatic logic [47:0] make_hit(input logic [4:0] ch);
        if (cfg_short_mode) begin
            // Short: {channel, E_BadHit, ECC, E_Fine, E_Flag, pad, zeros}
            return {ch, 1'b0, ecc_lfsr, prng2_state[4:0], 1'b0, 1'b1, 15'b0, 5'b0};
        end else begin
            // Long: {channel, T_BadHit, TCC, T_Fine, E_BadHit, E_Flag, ECC, E_Fine}
            return pack_hit_long(
                .channel  (ch),
                .t_badhit (1'b0),
                .tcc      (tcc_lfsr),
                .t_fine   (prng_state[4:0]),
                .e_badhit (1'b0),
                .e_flag   (1'b1),
                .ecc      (ecc_lfsr),
                .e_fine   (prng2_state[4:0])
            );
        end
    endfunction

endmodule
