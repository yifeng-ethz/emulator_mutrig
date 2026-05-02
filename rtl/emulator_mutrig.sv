// emulator_mutrig.sv
// Packaged MuTRiG emulator bank with central trigger frontend.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260502
// Change  : Replace the legacy bank shape with the central trigger FE/BE split.

module emulator_mutrig
    import frontend_ticket_bus_pkg::*;
    import be_mutrig_pkg::*;
#(
    parameter int LANE_COUNT = 8,
    parameter bit BYTE_STREAM_ENABLE = 1'b0,
    parameter int FIFO_DEPTH = RAW_FIFO_DEPTH_CONST,
    parameter int CSR_ADDR_WIDTH = 6,
    parameter logic [31:0] IP_UID = 32'h454D_5554,
    parameter int VERSION_MAJOR = 26,
    parameter int VERSION_MINOR = 2,
    parameter int VERSION_PATCH = 0,
    parameter int BUILD = 502,
    parameter int VERSION_DATE = 20260502,
    parameter logic [31:0] VERSION_GIT = 32'h0000_0000,
    parameter logic [31:0] INSTANCE_ID = 32'h0000_0000
) (
    input  logic                         i_clk,
    input  logic                         i_rst,

    output logic [LANE_COUNT*9-1:0]      aso_tx8b1k_data,
    output logic [LANE_COUNT-1:0]        aso_tx8b1k_valid,
    output logic [LANE_COUNT*4-1:0]      aso_tx8b1k_channel,
    output logic [LANE_COUNT*3-1:0]      aso_tx8b1k_error,

    output logic [LANE_COUNT*4-1:0]      aso_hit_type0_channel,
    output logic [LANE_COUNT-1:0]        aso_hit_type0_startofpacket,
    output logic [LANE_COUNT-1:0]        aso_hit_type0_endofpacket,
    output logic [LANE_COUNT-1:0]        aso_hit_type0_endofrun,
    output logic [LANE_COUNT*3-1:0]      aso_hit_type0_error,
    output logic [LANE_COUNT*45-1:0]     aso_hit_type0_data,
    output logic [LANE_COUNT-1:0]        aso_hit_type0_valid,

    input  logic [8:0]                   asi_ctrl_data,
    input  logic                         asi_ctrl_valid,
    output logic                         asi_ctrl_ready,

    input  logic                         coe_inject_pulse,

    input  logic [CSR_ADDR_WIDTH-1:0]    avs_csr_address,
    input  logic                         avs_csr_read,
    input  logic                         avs_csr_write,
    input  logic [31:0]                  avs_csr_writedata,
    output logic [31:0]                  avs_csr_readdata,
    output logic                         avs_csr_waitrequest
);

    localparam int LANE_INDEX_WIDTH = (LANE_COUNT > 1) ? $clog2(LANE_COUNT) : 1;

    logic cfg_global_enable;
    logic cfg_hit_mode_sig;
    logic cfg_internal_sub_mode;
    logic cfg_cluster_geom_mode;
    logic cfg_hit_mode_bkg;
    logic cfg_short_mode;
    logic cfg_gen_idle;
    logic [2:0] cfg_tx_mode;
    logic cfg_enable_type0_stream;
    logic [15:0] cfg_hit_rate;
    logic [15:0] cfg_noise_rate;
    logic [7:0] cfg_hit_channel_low;
    logic [7:0] cfg_hit_channel_high;
    logic [7:0] cfg_cluster_size_random;
    logic [1:0] cfg_mirror_mode;
    logic signed [7:0] cfg_mirror_offset;
    logic [7:0] cfg_random_center_seed;
    logic [31:0] cfg_prng_seed;
    logic [14:0] cfg_tcc_seed;
    logic [14:0] cfg_ecc_seed;
    logic [LANE_COUNT-1:0] cfg_lane_enable_mask;
    logic [3:0] cfg_asic_id_base;
    logic [2:0] cfg_type0_error_inject_mask;
    logic [LANE_COUNT-1:0] cfg_lane_error_target_mask;
    logic csr_fire_inject_pulse;
    logic csr_timebase_seed_load;
    logic [8:0] run_state;
    logic run_generating;
    logic run_draining;
    logic run_terminating;
    logic run_idle;
    logic emu_rst;
    logic frame_rst;
    logic inject_pulse;
    logic [14:0] tcc_lfsr;
    logic [14:0] ecc_lfsr;
    logic [14:0] tcc_lfsr_commit;
    logic [14:0] ecc_lfsr_commit;
    logic lfsr_en;
    logic [10:0] frame_interval_cnt;
    logic [10:0] frame_interval_max;
    logic frame_start_req;
    logic sig_offer_valid;
    logic [LANE_INDEX_WIDTH-1:0] sig_offer_lane;
    frontend_ticket_t sig_offer_ticket;
    logic sig_offer_ready;
    logic bkg_offer_valid;
    logic [LANE_INDEX_WIDTH-1:0] bkg_offer_lane;
    frontend_ticket_t bkg_offer_ticket;
    logic bkg_offer_ready;
    frontend_ticket_t fe_ticket_data [LANE_COUNT];
    logic [LANE_COUNT-1:0] fe_ticket_valid;
    logic [LANE_COUNT-1:0] fe_ticket_ready;
    logic [15:0] bank_ticket_overflow_count;
    logic [7:0] bank_engine_busy_high_water;
    logic [LANE_COUNT-1:0][63:0] lane_frame_count;
    logic [LANE_COUNT-1:0][63:0] lane_hit_count;

    function automatic logic [3:0] clamp_asic_id(input logic [4:0] raw_asic_id);
        return {1'b0, raw_asic_id[2:0]};
    endfunction

    frontend_csr #(
        .LANE_COUNT    (LANE_COUNT),
        .CSR_ADDR_WIDTH(CSR_ADDR_WIDTH),
        .IP_UID        (IP_UID),
        .VERSION_MAJOR (VERSION_MAJOR),
        .VERSION_MINOR (VERSION_MINOR),
        .VERSION_PATCH (VERSION_PATCH),
        .BUILD         (BUILD),
        .VERSION_DATE  (VERSION_DATE),
        .VERSION_GIT   (VERSION_GIT),
        .INSTANCE_ID   (INSTANCE_ID)
    ) u_csr (
        .clk                         (i_clk),
        .rst                         (i_rst),
        .avs_csr_address             (avs_csr_address),
        .avs_csr_read                (avs_csr_read),
        .avs_csr_write               (avs_csr_write),
        .avs_csr_writedata           (avs_csr_writedata),
        .avs_csr_readdata            (avs_csr_readdata),
        .avs_csr_waitrequest         (avs_csr_waitrequest),
        .cfg_global_enable           (cfg_global_enable),
        .cfg_hit_mode_sig            (cfg_hit_mode_sig),
        .cfg_internal_sub_mode       (cfg_internal_sub_mode),
        .cfg_cluster_geom_mode       (cfg_cluster_geom_mode),
        .cfg_hit_mode_bkg            (cfg_hit_mode_bkg),
        .cfg_short_mode              (cfg_short_mode),
        .cfg_gen_idle                (cfg_gen_idle),
        .cfg_tx_mode                 (cfg_tx_mode),
        .cfg_enable_type0_stream     (cfg_enable_type0_stream),
        .cfg_hit_rate                (cfg_hit_rate),
        .cfg_noise_rate              (cfg_noise_rate),
        .cfg_hit_channel_low         (cfg_hit_channel_low),
        .cfg_hit_channel_high        (cfg_hit_channel_high),
        .cfg_cluster_size_random     (cfg_cluster_size_random),
        .cfg_mirror_mode             (cfg_mirror_mode),
        .cfg_mirror_offset           (cfg_mirror_offset),
        .cfg_random_center_seed      (cfg_random_center_seed),
        .cfg_prng_seed               (cfg_prng_seed),
        .cfg_tcc_seed                (cfg_tcc_seed),
        .cfg_ecc_seed                (cfg_ecc_seed),
        .cfg_lane_enable_mask        (cfg_lane_enable_mask),
        .cfg_asic_id_base            (cfg_asic_id_base),
        .cfg_type0_error_inject_mask (cfg_type0_error_inject_mask),
        .cfg_lane_error_target_mask  (cfg_lane_error_target_mask),
        .csr_fire_inject_pulse       (csr_fire_inject_pulse),
        .csr_timebase_seed_load      (csr_timebase_seed_load),
        .bank_ticket_overflow_count  (bank_ticket_overflow_count),
        .bank_engine_busy_high_water (bank_engine_busy_high_water),
        .lane_frame_count            (lane_frame_count),
        .lane_hit_count              (lane_hit_count)
    );

    frontend_run_ctl u_run_ctl (
        .clk                    (i_clk),
        .rst                    (i_rst),
        .asi_ctrl_data          (asi_ctrl_data),
        .asi_ctrl_valid         (asi_ctrl_valid),
        .asi_ctrl_ready         (asi_ctrl_ready),
        .coe_inject_pulse       (coe_inject_pulse),
        .csr_fire_inject_pulse  (csr_fire_inject_pulse),
        .cfg_global_enable      (cfg_global_enable),
        .run_state              (run_state),
        .run_generating         (run_generating),
        .run_draining           (run_draining),
        .run_terminating        (run_terminating),
        .run_idle               (run_idle),
        .emu_rst                (emu_rst),
        .frame_rst              (frame_rst),
        .inject_pulse           (inject_pulse)
    );

    assign lfsr_en = run_draining;
    assign frame_interval_max = cfg_short_mode ? 11'(FRAME_INTERVAL_SHORT_CONST) : 11'(FRAME_INTERVAL_LONG_CONST);
    assign tcc_lfsr_commit =
        lfsr_en ? prbs15_step_n(tcc_lfsr, MUTRIG_COARSE_STEPS_PER_CYCLE_CONST) : tcc_lfsr;
    assign ecc_lfsr_commit =
        lfsr_en ? prbs15_step_n(ecc_lfsr, MUTRIG_COARSE_STEPS_PER_CYCLE_CONST) : ecc_lfsr;

    always_ff @(posedge i_clk) begin
        if (frame_rst) begin
            frame_interval_cnt <= frame_interval_max - 11'd1;
            frame_start_req <= 1'b0;
        end else begin
            if (frame_interval_cnt == 11'd0) begin
                frame_interval_cnt <= frame_interval_max - 11'd1;
                frame_start_req <= 1'b1;
            end else begin
                frame_interval_cnt <= frame_interval_cnt - 11'd1;
                frame_start_req <= 1'b0;
            end
        end
    end

    prbs15_lfsr #(
        .STEP_COUNT (MUTRIG_COARSE_STEPS_PER_CYCLE_CONST),
        .INIT       (LFSR15_INIT_CONST)
    ) u_tcc_lfsr (
        .clk        (i_clk),
        .rst        (emu_rst),
        .en         (lfsr_en),
        .load_seed  (csr_timebase_seed_load),
        .seed_value (cfg_tcc_seed),
        .lfsr_out   (tcc_lfsr)
    );

    prbs15_lfsr #(
        .STEP_COUNT (MUTRIG_COARSE_STEPS_PER_CYCLE_CONST),
        .INIT       (LFSR15_INIT_CONST)
    ) u_ecc_lfsr (
        .clk        (i_clk),
        .rst        (emu_rst),
        .en         (lfsr_en),
        .load_seed  (csr_timebase_seed_load),
        .seed_value (cfg_ecc_seed),
        .lfsr_out   (ecc_lfsr)
    );

    frontend_trigger_engine #(
        .LANE_COUNT (LANE_COUNT)
    ) u_trigger_engine (
        .clk                         (i_clk),
        .rst                         (emu_rst),
        .cfg_global_enable           (cfg_global_enable),
        .run_generating              (run_generating),
        .inject_pulse                (inject_pulse),
        .cfg_hit_mode_sig            (cfg_hit_mode_sig),
        .cfg_internal_sub_mode       (cfg_internal_sub_mode),
        .cfg_cluster_geom_mode       (cfg_cluster_geom_mode),
        .cfg_hit_rate                (cfg_hit_rate),
        .cfg_hit_channel_low         (cfg_hit_channel_low),
        .cfg_hit_channel_high        (cfg_hit_channel_high),
        .cfg_cluster_size_random     (cfg_cluster_size_random),
        .cfg_mirror_mode             (cfg_mirror_mode),
        .cfg_mirror_offset           (cfg_mirror_offset),
        .cfg_random_center_seed      (cfg_random_center_seed),
        .cfg_prng_seed               (cfg_prng_seed),
        .tcc_anchor                  (tcc_lfsr_commit),
        .ecc_anchor                  (ecc_lfsr_commit),
        .sig_offer_valid             (sig_offer_valid),
        .sig_offer_lane              (sig_offer_lane),
        .sig_offer_ticket            (sig_offer_ticket),
        .sig_offer_ready             (sig_offer_ready),
        .ticket_overflow_count       (bank_ticket_overflow_count),
        .engine_busy_high_water      (bank_engine_busy_high_water)
    );

    frontend_bkg_generator #(
        .LANE_COUNT (LANE_COUNT)
    ) u_bkg_generator (
        .clk                    (i_clk),
        .rst                    (emu_rst),
        .cfg_global_enable      (cfg_global_enable),
        .run_generating         (run_generating),
        .cfg_hit_mode_bkg       (cfg_hit_mode_bkg),
        .cfg_noise_rate         (cfg_noise_rate),
        .cfg_prng_seed          (cfg_prng_seed),
        .tcc_anchor             (tcc_lfsr_commit),
        .ecc_anchor             (ecc_lfsr_commit),
        .bkg_offer_valid        (bkg_offer_valid),
        .bkg_offer_lane         (bkg_offer_lane),
        .bkg_offer_ticket       (bkg_offer_ticket),
        .bkg_offer_ready        (bkg_offer_ready)
    );

    frontend_ticket_distributor #(
        .LANE_COUNT (LANE_COUNT)
    ) u_ticket_distributor (
        .sig_offer_valid  (sig_offer_valid),
        .sig_offer_lane   (sig_offer_lane),
        .sig_offer_ticket (sig_offer_ticket),
        .sig_offer_ready  (sig_offer_ready),
        .bkg_offer_valid  (bkg_offer_valid),
        .bkg_offer_lane   (bkg_offer_lane),
        .bkg_offer_ticket (bkg_offer_ticket),
        .bkg_offer_ready  (bkg_offer_ready),
        .fe_ticket_data   (fe_ticket_data),
        .fe_ticket_valid  (fe_ticket_valid),
        .fe_ticket_ready  (fe_ticket_ready)
    );

    genvar lane_idx;
    generate
        for (lane_idx = 0; lane_idx < LANE_COUNT; lane_idx++) begin : lane_gen
            localparam logic [4:0] LANE_INDEX_CONST = lane_idx;
            localparam logic [31:0] LANE_SEED_XOR_CONST = 32'h0000_9E37 * (lane_idx + 1);
            logic lane_enable;
            logic lane_ticket_ready;
            logic [47:0] l2_rd_data;
            logic l2_rd_valid;
            logic l2_empty;
            logic l2_full;
            logic l2_almost_full;
            logic [9:0] l2_event_count;
            logic frame_fifo_rd_en;
            logic type0_fifo_rd_en;
            logic l2_rd_en;
            logic frame_start_allowed;
            logic frame_count_pulse;
            logic [8:0] tx_data_int;
            logic tx_valid_int;
            logic frame_start_int;
            logic [3:0] asic_id;

            assign lane_enable = cfg_global_enable && cfg_lane_enable_mask[lane_idx];
            assign fe_ticket_ready[lane_idx] = lane_enable && lane_ticket_ready;
            assign asic_id = clamp_asic_id({1'b0, cfg_asic_id_base} + LANE_INDEX_CONST);
            assign frame_start_allowed = lane_enable && (run_generating || (run_draining && !l2_empty));
            assign frame_count_pulse = frame_start_req && frame_start_allowed;
            assign l2_rd_en = BYTE_STREAM_ENABLE ? frame_fifo_rd_en : type0_fifo_rd_en;

            be_mutrig_lane_emitter #(
                .FIFO_DEPTH (FIFO_DEPTH)
            ) u_lane_emitter (
                .clk                    (i_clk),
                .rst                    (emu_rst),
                .enable                 (lane_enable),
                .cfg_prng_seed          (cfg_prng_seed ^ LANE_SEED_XOR_CONST),
                .frame_count_pulse      (frame_count_pulse),
                .ticket_data            (fe_ticket_data[lane_idx]),
                .ticket_valid           (fe_ticket_valid[lane_idx]),
                .ticket_ready           (lane_ticket_ready),
                .l2_rd_en               (l2_rd_en),
                .l2_rd_data             (l2_rd_data),
                .l2_rd_valid            (l2_rd_valid),
                .l2_empty               (l2_empty),
                .l2_full                (l2_full),
                .l2_almost_full         (l2_almost_full),
                .l2_event_count         (l2_event_count),
                .frame_count            (lane_frame_count[lane_idx]),
                .hit_count              (lane_hit_count[lane_idx]),
                .fifo_full_sticky       (),
                .ticket_overflow_sticky ()
            );

            be_mutrig_lane_type0_emit u_type0_emit (
                .clk                         (i_clk),
                .rst                         (emu_rst),
                .enable                      (lane_enable && cfg_enable_type0_stream),
                .own_drain                   (!BYTE_STREAM_ENABLE),
                .frame_start_req             (frame_start_req),
                .frame_start_allowed         (frame_start_allowed),
                .run_terminating             (run_terminating),
                .run_idle                    (run_idle),
                .asic_id                     (asic_id),
                .error_inject_mask           (cfg_type0_error_inject_mask),
                .error_target_lane           (cfg_lane_error_target_mask[lane_idx]),
                .l2_empty                    (l2_empty),
                .l2_level                    (l2_event_count),
                .l2_rd_en                    (type0_fifo_rd_en),
                .l2_rd_data                  (l2_rd_data),
                .l2_rd_valid                 (l2_rd_valid),
                .aso_hit_type0_channel       (aso_hit_type0_channel[(lane_idx*4) +: 4]),
                .aso_hit_type0_startofpacket (aso_hit_type0_startofpacket[lane_idx]),
                .aso_hit_type0_endofpacket   (aso_hit_type0_endofpacket[lane_idx]),
                .aso_hit_type0_endofrun      (aso_hit_type0_endofrun[lane_idx]),
                .aso_hit_type0_error         (aso_hit_type0_error[(lane_idx*3) +: 3]),
                .aso_hit_type0_data          (aso_hit_type0_data[(lane_idx*45) +: 45]),
                .aso_hit_type0_valid         (aso_hit_type0_valid[lane_idx])
            );

            if (BYTE_STREAM_ENABLE) begin : byte_stream_gen
                be_mutrig_frame_assembler u_frame_assembler (
                    .clk               (i_clk),
                    .rst               (frame_rst),
                    .frame_start_req   (frame_start_req && frame_start_allowed),
                    .cfg_short_mode    (cfg_short_mode),
                    .cfg_gen_idle      (cfg_gen_idle),
                    .cfg_tx_mode       (cfg_tx_mode),
                    .fifo_rd_en        (frame_fifo_rd_en),
                    .fifo_data         (l2_rd_data),
                    .fifo_rd_valid     (l2_rd_valid),
                    .event_count       (l2_event_count),
                    .fifo_empty        (l2_empty),
                    .fifo_almost_full  (l2_almost_full),
                    .frame_start       (frame_start_int),
                    .tx_data           (tx_data_int),
                    .tx_valid          (tx_valid_int)
                );
            end else begin : no_byte_stream_gen
                assign frame_fifo_rd_en = 1'b0;
                assign tx_data_int = {1'b1, K28_5_CONST};
                assign tx_valid_int = 1'b0;
                assign frame_start_int = 1'b0;
            end

            always_comb begin
                if (BYTE_STREAM_ENABLE && run_draining && lane_enable) begin
                    aso_tx8b1k_data[(lane_idx*9) +: 9] = tx_data_int;
                    aso_tx8b1k_valid[lane_idx] = tx_valid_int;
                end else begin
                    aso_tx8b1k_data[(lane_idx*9) +: 9] = {1'b1, K28_5_CONST};
                    aso_tx8b1k_valid[lane_idx] = 1'b0;
                end
                aso_tx8b1k_channel[(lane_idx*4) +: 4] = asic_id;
                aso_tx8b1k_error[(lane_idx*3) +: 3] = 3'b000;
            end
        end
    endgenerate

endmodule
