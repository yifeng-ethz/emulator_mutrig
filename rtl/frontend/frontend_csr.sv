// frontend_csr.sv
// CSR bank for the emulator_mutrig central trigger frontend.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260502
// Change  : Add golden header and split frontend/backend mode registers.

module frontend_csr #(
    parameter int LANE_COUNT = 8,
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
    input  logic                          clk,
    input  logic                          rst,

    input  logic [CSR_ADDR_WIDTH-1:0]     avs_csr_address,
    input  logic                          avs_csr_read,
    input  logic                          avs_csr_write,
    input  logic [31:0]                   avs_csr_writedata,
    output logic [31:0]                   avs_csr_readdata,
    output logic                          avs_csr_waitrequest,

    output logic                          cfg_global_enable,
    output logic                          cfg_hit_mode_sig,
    output logic                          cfg_internal_sub_mode,
    output logic                          cfg_cluster_geom_mode,
    output logic                          cfg_hit_mode_bkg,
    output logic                          cfg_short_mode,
    output logic                          cfg_gen_idle,
    output logic [2:0]                    cfg_tx_mode,
    output logic                          cfg_enable_type0_stream,
    output logic [15:0]                   cfg_hit_rate,
    output logic [15:0]                   cfg_noise_rate,
    output logic [7:0]                    cfg_hit_channel_low,
    output logic [7:0]                    cfg_hit_channel_high,
    output logic [7:0]                    cfg_cluster_size_random,
    output logic [1:0]                    cfg_mirror_mode,
    output logic signed [7:0]             cfg_mirror_offset,
    output logic [7:0]                    cfg_random_center_seed,
    output logic [31:0]                   cfg_prng_seed,
    output logic [14:0]                   cfg_tcc_seed,
    output logic [14:0]                   cfg_ecc_seed,
    output logic [LANE_COUNT-1:0]         cfg_lane_enable_mask,
    output logic [3:0]                    cfg_asic_id_base,
    output logic [2:0]                    cfg_type0_error_inject_mask,
    output logic [LANE_COUNT-1:0]         cfg_lane_error_target_mask,
    output logic                          csr_fire_inject_pulse,
    output logic                          csr_timebase_seed_load,

    input  logic [15:0]                   bank_ticket_overflow_count,
    input  logic [7:0]                    bank_engine_busy_high_water,
    input  logic [LANE_COUNT-1:0][63:0]   lane_frame_count,
    input  logic [LANE_COUNT-1:0][63:0]   lane_hit_count
);

    localparam logic [CSR_ADDR_WIDTH-1:0] ADDR_UID_CONST = CSR_ADDR_WIDTH'(16'h00);
    localparam logic [CSR_ADDR_WIDTH-1:0] ADDR_META_CONST = CSR_ADDR_WIDTH'(16'h01);
    localparam logic [CSR_ADDR_WIDTH-1:0] ADDR_SCRATCH_CONST = CSR_ADDR_WIDTH'(16'h02);
    localparam logic [CSR_ADDR_WIDTH-1:0] ADDR_LAST_RD_ADDR_CONST = CSR_ADDR_WIDTH'(16'h03);
    localparam logic [CSR_ADDR_WIDTH-1:0] ADDR_LAST_RD_DATA_CONST = CSR_ADDR_WIDTH'(16'h04);
    localparam logic [CSR_ADDR_WIDTH-1:0] ADDR_LAST_WR_ADDR_CONST = CSR_ADDR_WIDTH'(16'h05);
    localparam logic [CSR_ADDR_WIDTH-1:0] ADDR_LAST_WR_DATA_CONST = CSR_ADDR_WIDTH'(16'h06);
    localparam logic [CSR_ADDR_WIDTH-1:0] ADDR_CENTRAL_CONST = CSR_ADDR_WIDTH'(16'h07);
    localparam logic [CSR_ADDR_WIDTH-1:0] ADDR_SIGNAL_CONST = CSR_ADDR_WIDTH'(16'h08);
    localparam logic [CSR_ADDR_WIDTH-1:0] ADDR_BACKGROUND_CONST = CSR_ADDR_WIDTH'(16'h09);
    localparam logic [CSR_ADDR_WIDTH-1:0] ADDR_MUTRIG_FORMAT_CONST = CSR_ADDR_WIDTH'(16'h0A);
    localparam logic [CSR_ADDR_WIDTH-1:0] ADDR_RATES_CONST = CSR_ADDR_WIDTH'(16'h0B);
    localparam logic [CSR_ADDR_WIDTH-1:0] ADDR_CLUSTER_FIX_CONST = CSR_ADDR_WIDTH'(16'h0C);
    localparam logic [CSR_ADDR_WIDTH-1:0] ADDR_CLUSTER_RANDOM_CONST = CSR_ADDR_WIDTH'(16'h0D);
    localparam logic [CSR_ADDR_WIDTH-1:0] ADDR_PRNG_SEED_CONST = CSR_ADDR_WIDTH'(16'h0E);
    localparam logic [CSR_ADDR_WIDTH-1:0] ADDR_TIMEBASE_SEED_CONST = CSR_ADDR_WIDTH'(16'h0F);
    localparam logic [CSR_ADDR_WIDTH-1:0] ADDR_LANE_ENABLE_CONST = CSR_ADDR_WIDTH'(16'h12);
    localparam logic [CSR_ADDR_WIDTH-1:0] ADDR_FIRE_CONST = CSR_ADDR_WIDTH'(16'h13);
    localparam logic [CSR_ADDR_WIDTH-1:0] ADDR_BANK_STATUS_CONST = CSR_ADDR_WIDTH'(16'h14);
    localparam logic [CSR_ADDR_WIDTH-1:0] ADDR_ERROR_INJECT_CONST = CSR_ADDR_WIDTH'(16'h15);
    localparam logic [CSR_ADDR_WIDTH-1:0] ADDR_LANE_COUNTER_BASE_CONST = CSR_ADDR_WIDTH'(16'h18);
    localparam logic [7:0] VERSION_MAJOR_VALUE_CONST = VERSION_MAJOR;
    localparam logic [7:0] VERSION_MINOR_VALUE_CONST = VERSION_MINOR;
    localparam logic [3:0] VERSION_PATCH_VALUE_CONST = VERSION_PATCH;
    localparam logic [11:0] BUILD_VALUE_CONST = BUILD;
    localparam logic [31:0] VERSION_DATE_VALUE_CONST = VERSION_DATE;

    logic [1:0]  meta_page;
    logic [31:0] scratch;
    logic [CSR_ADDR_WIDTH-1:0] last_rd_addr;
    logic [31:0] last_rd_data;
    logic [CSR_ADDR_WIDTH-1:0] last_wr_addr;
    logic [31:0] last_wr_data;
    logic [31:0] read_data;
    logic [31:0] meta_data;
    logic [31:0] version_data;

    assign avs_csr_waitrequest = 1'b0;
    assign avs_csr_readdata = read_data;
    assign version_data = {
        VERSION_MAJOR_VALUE_CONST,
        VERSION_MINOR_VALUE_CONST,
        VERSION_PATCH_VALUE_CONST,
        BUILD_VALUE_CONST
    };

    always_comb begin
        unique case (meta_page)
            2'd0: meta_data = version_data;
            2'd1: meta_data = VERSION_DATE_VALUE_CONST;
            2'd2: meta_data = VERSION_GIT;
            2'd3: meta_data = INSTANCE_ID;
            default: meta_data = version_data;
        endcase
    end

    always_comb begin
        int lane_idx;
        int lane_word;
        int lane_addr;

        read_data = 32'h0000_0000;
        lane_addr = int'(avs_csr_address) - int'(ADDR_LANE_COUNTER_BASE_CONST);
        lane_idx = lane_addr >> 2;
        lane_word = lane_addr & 2'h3;

        unique case (avs_csr_address)
            ADDR_UID_CONST: read_data = IP_UID;
            ADDR_META_CONST: read_data = meta_data;
            ADDR_SCRATCH_CONST: read_data = scratch;
            ADDR_LAST_RD_ADDR_CONST: read_data = {{(32-CSR_ADDR_WIDTH){1'b0}}, last_rd_addr};
            ADDR_LAST_RD_DATA_CONST: read_data = last_rd_data;
            ADDR_LAST_WR_ADDR_CONST: read_data = {{(32-CSR_ADDR_WIDTH){1'b0}}, last_wr_addr};
            ADDR_LAST_WR_DATA_CONST: read_data = last_wr_data;
            ADDR_CENTRAL_CONST: read_data = {31'b0, cfg_global_enable};
            ADDR_SIGNAL_CONST: read_data = {29'b0, cfg_cluster_geom_mode, cfg_internal_sub_mode, cfg_hit_mode_sig};
            ADDR_BACKGROUND_CONST: read_data = {31'b0, cfg_hit_mode_bkg};
            ADDR_MUTRIG_FORMAT_CONST: begin
                read_data = {26'b0, cfg_enable_type0_stream, cfg_tx_mode, cfg_gen_idle, cfg_short_mode};
            end
            ADDR_RATES_CONST: read_data = {cfg_noise_rate, cfg_hit_rate};
            ADDR_CLUSTER_FIX_CONST: read_data = {16'b0, cfg_hit_channel_high, cfg_hit_channel_low};
            ADDR_CLUSTER_RANDOM_CONST: begin
                read_data = {
                    5'b0,
                    cfg_random_center_seed,
                    cfg_mirror_offset,
                    1'b0,
                    cfg_mirror_mode,
                    cfg_cluster_size_random
                };
            end
            ADDR_PRNG_SEED_CONST: read_data = cfg_prng_seed;
            ADDR_TIMEBASE_SEED_CONST: read_data = {1'b0, cfg_ecc_seed, 1'b0, cfg_tcc_seed};
            ADDR_LANE_ENABLE_CONST: begin
                read_data = {{(28-LANE_COUNT){1'b0}}, cfg_asic_id_base, cfg_lane_enable_mask};
            end
            ADDR_FIRE_CONST: read_data = 32'h0000_0000;
            ADDR_BANK_STATUS_CONST: read_data = {8'b0, bank_engine_busy_high_water, bank_ticket_overflow_count};
            ADDR_ERROR_INJECT_CONST: begin
                read_data = {
                    {(21 + (8-LANE_COUNT)){1'b0}},
                    cfg_lane_error_target_mask,
                    cfg_type0_error_inject_mask
                };
            end
            default: begin
                if ((lane_addr >= 0) && (lane_idx < LANE_COUNT)) begin
                    unique case (lane_word)
                        0: read_data = lane_frame_count[lane_idx][31:0];
                        1: read_data = lane_frame_count[lane_idx][63:32];
                        2: read_data = lane_hit_count[lane_idx][31:0];
                        3: read_data = lane_hit_count[lane_idx][63:32];
                        default: read_data = 32'h0000_0000;
                    endcase
                end
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            meta_page <= 2'd0;
            scratch <= 32'h0000_0000;
            last_rd_addr <= '0;
            last_rd_data <= 32'h0000_0000;
            last_wr_addr <= '0;
            last_wr_data <= 32'h0000_0000;
            cfg_global_enable <= 1'b1;
            cfg_hit_mode_sig <= 1'b0;
            cfg_internal_sub_mode <= 1'b0;
            cfg_cluster_geom_mode <= 1'b0;
            cfg_hit_mode_bkg <= 1'b0;
            cfg_short_mode <= 1'b0;
            cfg_gen_idle <= 1'b1;
            cfg_tx_mode <= 3'b000;
            cfg_enable_type0_stream <= 1'b1;
            cfg_hit_rate <= 16'h0800;
            cfg_noise_rate <= 16'h0100;
            cfg_hit_channel_low <= 8'd0;
            cfg_hit_channel_high <= 8'd3;
            cfg_cluster_size_random <= 8'd4;
            cfg_mirror_mode <= 2'b10;
            cfg_mirror_offset <= 8'sd0;
            cfg_random_center_seed <= 8'h00;
            cfg_prng_seed <= 32'hDEAD_BEEF;
            cfg_tcc_seed <= 15'h0001;
            cfg_ecc_seed <= 15'h0001;
            cfg_lane_enable_mask <= {LANE_COUNT{1'b1}};
            cfg_asic_id_base <= 4'd0;
            cfg_type0_error_inject_mask <= 3'b000;
            cfg_lane_error_target_mask <= '0;
            csr_fire_inject_pulse <= 1'b0;
            csr_timebase_seed_load <= 1'b0;
        end else begin
            csr_fire_inject_pulse <= 1'b0;
            csr_timebase_seed_load <= 1'b0;

            if (avs_csr_read &&
                (avs_csr_address != ADDR_LAST_RD_ADDR_CONST) &&
                (avs_csr_address != ADDR_LAST_RD_DATA_CONST)) begin
                last_rd_addr <= avs_csr_address;
                last_rd_data <= read_data;
            end

            if (avs_csr_write) begin
                last_wr_addr <= avs_csr_address;
                last_wr_data <= avs_csr_writedata;

                unique case (avs_csr_address)
                    ADDR_META_CONST: meta_page <= avs_csr_writedata[1:0];
                    ADDR_SCRATCH_CONST: scratch <= avs_csr_writedata;
                    ADDR_CENTRAL_CONST: cfg_global_enable <= avs_csr_writedata[0];
                    ADDR_SIGNAL_CONST: begin
                        cfg_hit_mode_sig <= avs_csr_writedata[0];
                        cfg_internal_sub_mode <= avs_csr_writedata[1];
                        cfg_cluster_geom_mode <= avs_csr_writedata[2];
                    end
                    ADDR_BACKGROUND_CONST: cfg_hit_mode_bkg <= avs_csr_writedata[0];
                    ADDR_MUTRIG_FORMAT_CONST: begin
                        cfg_short_mode <= avs_csr_writedata[0];
                        cfg_gen_idle <= avs_csr_writedata[1];
                        cfg_tx_mode <= avs_csr_writedata[4:2];
                        cfg_enable_type0_stream <= avs_csr_writedata[5];
                    end
                    ADDR_RATES_CONST: begin
                        cfg_hit_rate <= avs_csr_writedata[15:0];
                        cfg_noise_rate <= avs_csr_writedata[31:16];
                    end
                    ADDR_CLUSTER_FIX_CONST: begin
                        cfg_hit_channel_low <= avs_csr_writedata[7:0];
                        cfg_hit_channel_high <= avs_csr_writedata[15:8];
                    end
                    ADDR_CLUSTER_RANDOM_CONST: begin
                        cfg_cluster_size_random <= avs_csr_writedata[7:0];
                        cfg_mirror_mode <= avs_csr_writedata[9:8];
                        cfg_mirror_offset <= avs_csr_writedata[18:11];
                        cfg_random_center_seed <= avs_csr_writedata[26:19];
                    end
                    ADDR_PRNG_SEED_CONST: cfg_prng_seed <= avs_csr_writedata;
                    ADDR_TIMEBASE_SEED_CONST: begin
                        cfg_tcc_seed <= avs_csr_writedata[14:0];
                        cfg_ecc_seed <= avs_csr_writedata[30:16];
                        csr_timebase_seed_load <= 1'b1;
                    end
                    ADDR_LANE_ENABLE_CONST: begin
                        cfg_lane_enable_mask <= avs_csr_writedata[LANE_COUNT-1:0];
                        cfg_asic_id_base <= avs_csr_writedata[11:8];
                    end
                    ADDR_FIRE_CONST: csr_fire_inject_pulse <= avs_csr_writedata[0];
                    ADDR_ERROR_INJECT_CONST: begin
                        cfg_type0_error_inject_mask <= avs_csr_writedata[2:0];
                        cfg_lane_error_target_mask <= avs_csr_writedata[3 +: LANE_COUNT];
                    end
                    default: ;
                endcase
            end
        end
    end

endmodule
