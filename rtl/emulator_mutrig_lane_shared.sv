// emulator_mutrig_lane_shared.sv
// Shared-control MuTRiG lane core used by the standalone 8-lane area bank.
// Version : 26.1.9
// Date    : 20260418
// Change  : Keep the shared-lane wrapper aligned with the compact raw-style
//           frame semantics while accepting one shared masked-offer stream so
//           the bank8 signoff shell stays below the 4k ALM target.

module emulator_mutrig_lane_shared
    import emulator_mutrig_pkg::*;
#(
    parameter int FIFO_DEPTH = RAW_FIFO_DEPTH,
    parameter bit ENABLE_LOCAL_MASKED_TRIGGER = 1'b1
)(
    input  logic        clk,
    input  logic        emu_rst,
    input  logic        frame_rst,
    input  logic        frame_start_req,
    input  logic        run_generating,
    input  logic        run_draining,
    input  logic        inject_pulse,
    input  logic        inject_masked_pulse,
    input  logic [14:0] tcc_lfsr,
    input  logic [14:0] ecc_lfsr,

    input  logic        cfg_enable,
    input  logic [1:0]  cfg_hit_mode,
    input  logic        cfg_short_mode,
    input  logic [15:0] cfg_hit_rate,
    input  logic [15:0] cfg_noise_rate,
    input  logic [4:0]  cfg_burst_size,
    input  logic [4:0]  cfg_burst_center,
    input  logic        cfg_cluster_cross_asic,
    input  logic [7:0]  cfg_cluster_center_global,
    input  logic [3:0]  cfg_cluster_lane_index,
    input  logic [3:0]  cfg_cluster_lane_count,
    input  logic [31:0] cfg_prng_seed,
    input  logic [2:0]  cfg_tx_mode,
    input  logic        cfg_gen_idle,
    input  logic [3:0]  cfg_asic_id,
    input  logic [N_CHANNELS-1:0] cfg_inject_channel_mask,
    input  logic        sim_offer_valid,
    input  logic [47:0] sim_offer_word,
    output logic        sim_offer_ready,

    output logic [8:0]  aso_tx8b1k_data,
    output logic        aso_tx8b1k_valid,
    output logic [3:0]  aso_tx8b1k_channel,
    output logic [2:0]  aso_tx8b1k_error,
    output logic [15:0] status_frame_count,
    output logic [9:0]  status_event_count
);

    logic        fifo_rd_en;
    logic [47:0] fifo_data;
    logic [9:0]  event_count;
    logic        fifo_empty;
    logic        fifo_full;
    logic        fifo_almost_full;
    logic        frame_start;
    logic [8:0]  tx_data_int;
    logic        tx_valid_int;

    hit_generator #(
        .FIFO_DEPTH                 (FIFO_DEPTH),
        .ENABLE_LOCAL_MASKED_TRIGGER(ENABLE_LOCAL_MASKED_TRIGGER)
    ) u_hit_gen (
        .clk                  (clk),
        .rst                  (emu_rst),
        .enable               (run_generating & cfg_enable),
        .cfg_hit_mode         (cfg_hit_mode),
        .cfg_hit_rate         (cfg_hit_rate),
        .cfg_burst_size       (cfg_burst_size),
        .cfg_burst_center     (cfg_burst_center),
        .cfg_cluster_cross_asic(cfg_cluster_cross_asic),
        .cfg_cluster_center_global(cfg_cluster_center_global),
        .cfg_cluster_lane_index(cfg_cluster_lane_index),
        .cfg_cluster_lane_count(cfg_cluster_lane_count),
        .cfg_noise_rate       (cfg_noise_rate),
        .cfg_prng_seed        (cfg_prng_seed),
        .cfg_short_mode       (cfg_short_mode),
        .inject_pulse         (inject_pulse),
        .inject_masked_pulse  (inject_masked_pulse),
        .cfg_inject_channel_mask(cfg_inject_channel_mask),
        .sim_offer_valid      (sim_offer_valid),
        .sim_offer_word       (sim_offer_word),
        .sim_offer_ready      (sim_offer_ready),
        .tcc_lfsr             (tcc_lfsr),
        .ecc_lfsr             (ecc_lfsr),
        .fifo_rd_en           (fifo_rd_en),
        .fifo_data            (fifo_data),
        .event_count          (event_count),
        .fifo_empty           (fifo_empty),
        .fifo_full            (fifo_full),
        .fifo_almost_full     (fifo_almost_full)
    );

    frame_assembler u_frame_asm (
        .clk              (clk),
        .rst              (frame_rst),
        .frame_start_req  (frame_start_req & run_generating & cfg_enable),
        .cfg_short_mode   (cfg_short_mode),
        .cfg_gen_idle     (cfg_gen_idle),
        .cfg_tx_mode      (cfg_tx_mode),
        .fifo_rd_en       (fifo_rd_en),
        .fifo_data        (fifo_data),
        .event_count      (event_count),
        .fifo_empty       (fifo_empty),
        .fifo_almost_full (fifo_almost_full),
        .frame_start      (frame_start),
        .tx_data          (tx_data_int),
        .tx_valid         (tx_valid_int)
    );

    always_comb begin
        if (run_draining && cfg_enable) begin
            aso_tx8b1k_data  = tx_data_int;
            aso_tx8b1k_valid = tx_valid_int;
        end else begin
            aso_tx8b1k_data  = {1'b1, K28_5};
            aso_tx8b1k_valid = 1'b1;
        end
        aso_tx8b1k_channel = cfg_asic_id;
        aso_tx8b1k_error   = 3'b000;
    end

    always_ff @(posedge clk) begin
        if (emu_rst) begin
            status_frame_count <= '0;
            status_event_count <= '0;
        end else if (frame_start) begin
            status_frame_count <= status_frame_count + 16'd1;
            status_event_count <= event_count;
        end
    end

endmodule
