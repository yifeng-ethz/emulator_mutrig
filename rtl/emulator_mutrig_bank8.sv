// emulator_mutrig_bank8.sv
// Standalone 8-lane MuTRiG emulator bank with shared control/timebase.
// Version : 26.1.7
// Date    : 20260418
// Change  : Maintain the compact 8-lane standalone bank as the timing-closed
//           signoff vehicle for raw-compatible latency and throughput parity.

module emulator_mutrig_bank8
    import emulator_mutrig_pkg::*;
#(
    parameter int LANE_COUNT = 8,
    parameter int FIFO_DEPTH = RAW_FIFO_DEPTH
)(
    input  logic        i_clk,
    input  logic        i_rst,

    input  logic [8:0]  asi_ctrl_data,
    input  logic        asi_ctrl_valid,
    output logic        asi_ctrl_ready,
    input  logic        coe_inject_pulse,

    input  logic [LANE_COUNT-1:0] cfg_enable_mask,
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

    output logic [LANE_COUNT*9-1:0]  aso_tx8b1k_data,
    output logic [LANE_COUNT-1:0]    aso_tx8b1k_valid,
    output logic [LANE_COUNT*4-1:0]  aso_tx8b1k_channel,
    output logic [LANE_COUNT*3-1:0]  aso_tx8b1k_error,
    output logic [LANE_COUNT*16-1:0] status_frame_count,
    output logic [LANE_COUNT*10-1:0] status_event_count
);

    logic [8:0] ctrl_state_q;
    logic       run_generating;
    logic       run_draining;
    logic       emu_rst;
    logic       frame_rst;
    logic [1:0] inject_sync;
    logic       inject_pulse_clk;
    logic       lfsr_en;
    logic [14:0] tcc_lfsr;
    logic [14:0] ecc_lfsr;
    logic [14:0] tcc_lfsr_commit;
    logic [14:0] ecc_lfsr_commit;
    logic [10:0] frame_interval_cnt;
    logic [10:0] frame_interval_max;
    logic        frame_start_req;
`ifndef SYNTHESIS
    logic [47:0] true_gts_8n;
`endif

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            ctrl_state_q <= 9'b0_0000_0001;
        end else if (asi_ctrl_valid) begin
            ctrl_state_q <= asi_ctrl_data;
        end
    end

    assign asi_ctrl_ready = 1'b1;
    assign run_generating = ctrl_state_q[3];
    assign run_draining   = ctrl_state_q[3] | ctrl_state_q[4];
    assign emu_rst        = i_rst | (asi_ctrl_valid && (asi_ctrl_data[2] | asi_ctrl_data[7]));
    assign frame_rst      = emu_rst | ~run_draining;

    always_ff @(posedge i_clk) begin
        if (emu_rst)
            inject_sync <= 2'b00;
        else
            inject_sync <= {inject_sync[0], coe_inject_pulse};
    end

    assign inject_pulse_clk = inject_sync[0] & ~inject_sync[1];
    assign lfsr_en = ~emu_rst;
    assign frame_interval_max = cfg_short_mode ? 11'(FRAME_INTERVAL_SHORT) : 11'(FRAME_INTERVAL_LONG);

    always_ff @(posedge i_clk) begin
        if (frame_rst) begin
            frame_interval_cnt <= frame_interval_max - 11'd1;
            frame_start_req    <= 1'b0;
        end else begin
            if (frame_interval_cnt == '0) begin
                frame_interval_cnt <= frame_interval_max - 11'd1;
                frame_start_req    <= 1'b1;
            end else begin
                frame_interval_cnt <= frame_interval_cnt - 11'd1;
                frame_start_req    <= 1'b0;
            end
        end
    end

    prbs15_lfsr #(
        .STEP_COUNT (MUTRIG_COARSE_STEPS_PER_CYCLE)
    ) u_tcc_lfsr (
        .clk      (i_clk),
        .rst      (emu_rst),
        .en       (lfsr_en),
        .lfsr_out (tcc_lfsr)
    );

    prbs15_lfsr #(
        .STEP_COUNT (MUTRIG_COARSE_STEPS_PER_CYCLE)
    ) u_ecc_lfsr (
        .clk      (i_clk),
        .rst      (emu_rst),
        .en       (lfsr_en),
        .lfsr_out (ecc_lfsr)
    );

    assign tcc_lfsr_commit = lfsr_en ? prbs15_step_n(tcc_lfsr, MUTRIG_COARSE_STEPS_PER_CYCLE) : tcc_lfsr;
    assign ecc_lfsr_commit = lfsr_en ? prbs15_step_n(ecc_lfsr, MUTRIG_COARSE_STEPS_PER_CYCLE) : ecc_lfsr;

`ifndef SYNTHESIS
    always_ff @(posedge i_clk) begin
        if (emu_rst)
            true_gts_8n <= '0;
        else if (lfsr_en)
            true_gts_8n <= true_gts_8n + 48'd1;
    end
`endif

    genvar lane_idx;
    generate
        for (lane_idx = 0; lane_idx < LANE_COUNT; lane_idx++) begin : lane_gen
            localparam logic [3:0] LANE_INDEX_CONST = lane_idx[3:0];

            emulator_mutrig_lane_shared #(
                .FIFO_DEPTH (FIFO_DEPTH)
            ) u_lane (
                .clk                    (i_clk),
                .emu_rst                (emu_rst),
                .frame_rst              (frame_rst),
                .frame_start_req        (frame_start_req),
                .run_generating         (run_generating),
                .run_draining           (run_draining),
                .inject_pulse           (inject_pulse_clk),
                .tcc_lfsr               (tcc_lfsr_commit),
                .ecc_lfsr               (ecc_lfsr_commit),
                .cfg_enable             (cfg_enable_mask[lane_idx]),
                .cfg_hit_mode           (cfg_hit_mode),
                .cfg_short_mode         (cfg_short_mode),
                .cfg_hit_rate           (cfg_hit_rate),
                .cfg_noise_rate         (cfg_noise_rate),
                .cfg_burst_size         (cfg_burst_size),
                .cfg_burst_center       (cfg_burst_center),
                .cfg_cluster_cross_asic (cfg_cluster_cross_asic),
                .cfg_cluster_center_global(cfg_cluster_center_global),
                .cfg_cluster_lane_index (LANE_INDEX_CONST),
                .cfg_cluster_lane_count (cfg_cluster_lane_count),
                .cfg_prng_seed          (cfg_prng_seed),
                .cfg_tx_mode            (cfg_tx_mode),
                .cfg_gen_idle           (cfg_gen_idle),
                .cfg_asic_id            (LANE_INDEX_CONST),
                .aso_tx8b1k_data        (aso_tx8b1k_data[(lane_idx*9) +: 9]),
                .aso_tx8b1k_valid       (aso_tx8b1k_valid[lane_idx]),
                .aso_tx8b1k_channel     (aso_tx8b1k_channel[(lane_idx*4) +: 4]),
                .aso_tx8b1k_error       (aso_tx8b1k_error[(lane_idx*3) +: 3]),
                .status_frame_count     (status_frame_count[(lane_idx*16) +: 16]),
                .status_event_count     (status_event_count[(lane_idx*10) +: 10])
            );
        end
    endgenerate

endmodule
