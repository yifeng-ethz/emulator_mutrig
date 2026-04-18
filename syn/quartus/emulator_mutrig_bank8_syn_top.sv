module emulator_mutrig_bank8_syn_top (
    input  logic        clk125,
    input  logic        reset_n,
    input  logic [8:0]  asi_ctrl_data,
    input  logic        asi_ctrl_valid,
    input  logic        coe_inject_pulse,
    input  logic        coe_inject_masked_pulse,
    input  logic [7:0]  cfg_enable_mask,
    input  logic [31:0] cfg_inject_channel_mask,
    input  logic [1:0]  cfg_hit_mode,
    input  logic        cfg_short_mode,
    input  logic [15:0] cfg_hit_rate,
    input  logic [15:0] cfg_noise_rate,
    input  logic [4:0]  cfg_burst_size,
    input  logic [4:0]  cfg_burst_center,
    input  logic        cfg_cluster_cross_asic,
    input  logic [7:0]  cfg_cluster_center_global,
    input  logic [3:0]  cfg_cluster_lane_count,
    input  logic [31:0] cfg_prng_seed,
    input  logic [2:0]  cfg_tx_mode,
    input  logic        cfg_gen_idle,
    output logic [71:0] aso_tx8b1k_data,
    output logic [7:0]  aso_tx8b1k_valid,
    output logic [31:0] aso_tx8b1k_channel,
    output logic [23:0] aso_tx8b1k_error,
    output logic [127:0] status_frame_count,
    output logic [79:0] status_event_count,
    output logic        asi_ctrl_ready
);

    logic i_rst;

    assign i_rst = ~reset_n;

    emulator_mutrig_bank8 u_dut (
        .i_clk                    (clk125),
        .i_rst                    (i_rst),
        .asi_ctrl_data            (asi_ctrl_data),
        .asi_ctrl_valid           (asi_ctrl_valid),
        .asi_ctrl_ready           (asi_ctrl_ready),
        .coe_inject_pulse         (coe_inject_pulse),
        .coe_inject_masked_pulse  (coe_inject_masked_pulse),
        .cfg_enable_mask          (cfg_enable_mask),
        .cfg_inject_channel_mask  (cfg_inject_channel_mask),
        .cfg_hit_mode             (cfg_hit_mode),
        .cfg_short_mode           (cfg_short_mode),
        .cfg_hit_rate             (cfg_hit_rate),
        .cfg_noise_rate           (cfg_noise_rate),
        .cfg_burst_size           (cfg_burst_size),
        .cfg_burst_center         (cfg_burst_center),
        .cfg_cluster_cross_asic   (cfg_cluster_cross_asic),
        .cfg_cluster_center_global(cfg_cluster_center_global),
        .cfg_cluster_lane_count   (cfg_cluster_lane_count),
        .cfg_prng_seed            (cfg_prng_seed),
        .cfg_tx_mode              (cfg_tx_mode),
        .cfg_gen_idle             (cfg_gen_idle),
        .aso_tx8b1k_data          (aso_tx8b1k_data),
        .aso_tx8b1k_valid         (aso_tx8b1k_valid),
        .aso_tx8b1k_channel       (aso_tx8b1k_channel),
        .aso_tx8b1k_error         (aso_tx8b1k_error),
        .status_frame_count       (status_frame_count),
        .status_event_count       (status_event_count)
    );

endmodule
