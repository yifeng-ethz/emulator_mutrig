// emulator_mutrig_qsys8.sv
// Eight-lane Platform Designer wrapper for the rewritten MuTRiG emulator.
// Author: Yifeng Wang (yifenwan@phys.ethz.ch)
// Version : 26.3.6
// Date    : 20260520
// Change  : Version bump to carry the SIGNAL single-channel-mode core fix
//           (per-(ASIC,CH) periodic injection isolates to one histogram bin
//           via LANE_ENABLE mask + SIGNAL.single_channel). Wrapper port list
//           and topology unchanged. Prior change retained below.
//           New 8-lane top wrapper exposing eight independent asic-tagged
//           hit_type0 Avalon-ST sources (hit_type0_0..hit_type0_7), each
//           wired to the emulator core's per-lane array element [k]. Lane k
//           carries asic_id = cfg_asic_id_base + k inside the core, so each
//           of the 8 ASICs is independently injectable and the Type0
//           histogram can bin all 256 (ASIC,CH) keys. Replaces the single
//           hit_type0 source + broadcast hit_type0_fanout8 topology that
//           mimicked 8 ASICs from one real lane. One emulator core, one CSR,
//           one ctrl, one inject conduit are kept exactly as the scalar
//           emulator_mutrig_qsys_lane wrapper.

module emulator_mutrig_qsys8 #(
    parameter int FIFO_DEPTH = 64,
    parameter int CSR_ADDR_WIDTH = 4,
    parameter logic [3:0] ASIC_ID_DEFAULT = 4'd0,
    parameter logic CLUSTER_CROSS_ASIC_DEFAULT = 1'b0,
    parameter logic [7:0] CLUSTER_CENTER_GLOBAL_DEFAULT = 8'd16,
    parameter logic [3:0] CLUSTER_LANE_INDEX_DEFAULT = 4'd0,
    parameter logic [3:0] CLUSTER_LANE_COUNT_DEFAULT = 4'd8,
    parameter bit BYTE_STREAM_ENABLE = 1'b0,
    parameter logic [31:0] IP_UID = 32'h454D_5554,
    parameter int VERSION_MAJOR = 26,
    parameter int VERSION_MINOR = 3,
    parameter int VERSION_PATCH = 6,
    parameter int BUILD = 520,
    parameter int VERSION_DATE = 20260520,
    parameter logic [31:0] VERSION_GIT = 32'h0000_0000,
    parameter logic [31:0] INSTANCE_ID = 32'h0000_0000,
    parameter int DEBUG_LEVEL = 0
) (
    input  logic        i_clk,
    input  logic        i_rst,

    // ----- 8 independent asic-tagged hit_type0 Avalon-ST sources --------
    // Each lane k exposes the core's per-lane array element [k]; lane k
    // carries asic_id = cfg_asic_id_base + k inside the core.
    output logic [44:0] aso_hit_type0_0_data,
    output logic        aso_hit_type0_0_valid,
    output logic [2:0]  aso_hit_type0_0_error,
    output logic [3:0]  aso_hit_type0_0_channel,
    output logic        aso_hit_type0_0_startofpacket,
    output logic        aso_hit_type0_0_endofpacket,
    output logic        aso_hit_type0_0_endofrun,

    output logic [44:0] aso_hit_type0_1_data,
    output logic        aso_hit_type0_1_valid,
    output logic [2:0]  aso_hit_type0_1_error,
    output logic [3:0]  aso_hit_type0_1_channel,
    output logic        aso_hit_type0_1_startofpacket,
    output logic        aso_hit_type0_1_endofpacket,
    output logic        aso_hit_type0_1_endofrun,

    output logic [44:0] aso_hit_type0_2_data,
    output logic        aso_hit_type0_2_valid,
    output logic [2:0]  aso_hit_type0_2_error,
    output logic [3:0]  aso_hit_type0_2_channel,
    output logic        aso_hit_type0_2_startofpacket,
    output logic        aso_hit_type0_2_endofpacket,
    output logic        aso_hit_type0_2_endofrun,

    output logic [44:0] aso_hit_type0_3_data,
    output logic        aso_hit_type0_3_valid,
    output logic [2:0]  aso_hit_type0_3_error,
    output logic [3:0]  aso_hit_type0_3_channel,
    output logic        aso_hit_type0_3_startofpacket,
    output logic        aso_hit_type0_3_endofpacket,
    output logic        aso_hit_type0_3_endofrun,

    output logic [44:0] aso_hit_type0_4_data,
    output logic        aso_hit_type0_4_valid,
    output logic [2:0]  aso_hit_type0_4_error,
    output logic [3:0]  aso_hit_type0_4_channel,
    output logic        aso_hit_type0_4_startofpacket,
    output logic        aso_hit_type0_4_endofpacket,
    output logic        aso_hit_type0_4_endofrun,

    output logic [44:0] aso_hit_type0_5_data,
    output logic        aso_hit_type0_5_valid,
    output logic [2:0]  aso_hit_type0_5_error,
    output logic [3:0]  aso_hit_type0_5_channel,
    output logic        aso_hit_type0_5_startofpacket,
    output logic        aso_hit_type0_5_endofpacket,
    output logic        aso_hit_type0_5_endofrun,

    output logic [44:0] aso_hit_type0_6_data,
    output logic        aso_hit_type0_6_valid,
    output logic [2:0]  aso_hit_type0_6_error,
    output logic [3:0]  aso_hit_type0_6_channel,
    output logic        aso_hit_type0_6_startofpacket,
    output logic        aso_hit_type0_6_endofpacket,
    output logic        aso_hit_type0_6_endofrun,

    output logic [44:0] aso_hit_type0_7_data,
    output logic        aso_hit_type0_7_valid,
    output logic [2:0]  aso_hit_type0_7_error,
    output logic [3:0]  aso_hit_type0_7_channel,
    output logic        aso_hit_type0_7_startofpacket,
    output logic        aso_hit_type0_7_endofpacket,
    output logic        aso_hit_type0_7_endofrun,

    // ----- shared debug conduits / streams (lane 0 view, gated by DEBUG) -
    output logic [15:0] coe_debug_fifo_fill_level,
    output logic [63:0] coe_debug_hit_metadata,
    output logic        coe_debug_hit_metadata_valid,
    output logic [63:0] aso_hit_debug_data,
    output logic        aso_hit_debug_valid,
    output logic [3:0]  aso_hit_debug_channel,
    output logic        aso_hit_debug_startofpacket,
    output logic        aso_hit_debug_endofpacket,
    output logic        aso_hit_debug_endofrun,

    // ----- single shared control / inject / CSR (one emulator core) -----
    input  logic [8:0]  asi_ctrl_data,
    input  logic        asi_ctrl_valid,
    output logic        asi_ctrl_ready,

    input  logic        coe_inject_pulse,
    input  logic        coe_inject_masked_pulse,

    input  logic [CSR_ADDR_WIDTH-1:0] avs_csr_address,
    input  logic        avs_csr_read,
    input  logic        avs_csr_write,
    input  logic [31:0] avs_csr_writedata,
    output logic [31:0] avs_csr_readdata,
    output logic        avs_csr_waitrequest
);

    localparam int LANE_COUNT = 8;

    logic [LANE_COUNT-1:0][44:0] hit_type0_data;
    logic [LANE_COUNT-1:0]       hit_type0_valid;
    logic [LANE_COUNT-1:0]       hit_type0_startofpacket;
    logic [LANE_COUNT-1:0]       hit_type0_endofpacket;
    logic [LANE_COUNT-1:0]       hit_type0_endofrun;
    logic [LANE_COUNT-1:0][2:0]  hit_type0_error;
    logic [LANE_COUNT-1:0][3:0]  hit_type0_channel;
    logic [LANE_COUNT-1:0][15:0] debug_fifo_fill_level;
    logic [LANE_COUNT-1:0][63:0] hit_debug_data;
    logic [LANE_COUNT-1:0]       hit_debug_valid;
    logic [LANE_COUNT-1:0][3:0]  hit_debug_channel;
    logic [LANE_COUNT-1:0]       hit_debug_startofpacket;
    logic [LANE_COUNT-1:0]       hit_debug_endofpacket;
    logic [LANE_COUNT-1:0]       hit_debug_endofrun;
    logic [LANE_COUNT-1:0][8:0]  tx8b1k_data;
    logic [LANE_COUNT-1:0]       tx8b1k_valid;
    logic [LANE_COUNT-1:0][2:0]  tx8b1k_error;
    logic [LANE_COUNT-1:0][3:0]  tx8b1k_channel;

    // tx8b1k is permanently disabled in this package; sink the per-lane
    // outputs so the core's array ports are fully driven and read.
    logic unused_tx8b1k;
    assign unused_tx8b1k = ^{tx8b1k_data, tx8b1k_valid, tx8b1k_error, tx8b1k_channel};

    logic [5:0] csr_address_extended;

    generate
        if (CSR_ADDR_WIDTH >= 6) begin : csr_addr_truncate_gen
            assign csr_address_extended = avs_csr_address[5:0];
        end else begin : csr_addr_extend_gen
            assign csr_address_extended = {{(6 - CSR_ADDR_WIDTH){1'b0}}, avs_csr_address};
        end
    endgenerate

    // ----- per-lane hit_type0 source fan-out from the core arrays --------
    assign aso_hit_type0_0_data          = hit_type0_data[0];
    assign aso_hit_type0_0_valid         = hit_type0_valid[0];
    assign aso_hit_type0_0_error         = hit_type0_error[0];
    assign aso_hit_type0_0_channel       = hit_type0_channel[0];
    assign aso_hit_type0_0_startofpacket = hit_type0_startofpacket[0];
    assign aso_hit_type0_0_endofpacket   = hit_type0_endofpacket[0];
    assign aso_hit_type0_0_endofrun      = hit_type0_endofrun[0];

    assign aso_hit_type0_1_data          = hit_type0_data[1];
    assign aso_hit_type0_1_valid         = hit_type0_valid[1];
    assign aso_hit_type0_1_error         = hit_type0_error[1];
    assign aso_hit_type0_1_channel       = hit_type0_channel[1];
    assign aso_hit_type0_1_startofpacket = hit_type0_startofpacket[1];
    assign aso_hit_type0_1_endofpacket   = hit_type0_endofpacket[1];
    assign aso_hit_type0_1_endofrun      = hit_type0_endofrun[1];

    assign aso_hit_type0_2_data          = hit_type0_data[2];
    assign aso_hit_type0_2_valid         = hit_type0_valid[2];
    assign aso_hit_type0_2_error         = hit_type0_error[2];
    assign aso_hit_type0_2_channel       = hit_type0_channel[2];
    assign aso_hit_type0_2_startofpacket = hit_type0_startofpacket[2];
    assign aso_hit_type0_2_endofpacket   = hit_type0_endofpacket[2];
    assign aso_hit_type0_2_endofrun      = hit_type0_endofrun[2];

    assign aso_hit_type0_3_data          = hit_type0_data[3];
    assign aso_hit_type0_3_valid         = hit_type0_valid[3];
    assign aso_hit_type0_3_error         = hit_type0_error[3];
    assign aso_hit_type0_3_channel       = hit_type0_channel[3];
    assign aso_hit_type0_3_startofpacket = hit_type0_startofpacket[3];
    assign aso_hit_type0_3_endofpacket   = hit_type0_endofpacket[3];
    assign aso_hit_type0_3_endofrun      = hit_type0_endofrun[3];

    assign aso_hit_type0_4_data          = hit_type0_data[4];
    assign aso_hit_type0_4_valid         = hit_type0_valid[4];
    assign aso_hit_type0_4_error         = hit_type0_error[4];
    assign aso_hit_type0_4_channel       = hit_type0_channel[4];
    assign aso_hit_type0_4_startofpacket = hit_type0_startofpacket[4];
    assign aso_hit_type0_4_endofpacket   = hit_type0_endofpacket[4];
    assign aso_hit_type0_4_endofrun      = hit_type0_endofrun[4];

    assign aso_hit_type0_5_data          = hit_type0_data[5];
    assign aso_hit_type0_5_valid         = hit_type0_valid[5];
    assign aso_hit_type0_5_error         = hit_type0_error[5];
    assign aso_hit_type0_5_channel       = hit_type0_channel[5];
    assign aso_hit_type0_5_startofpacket = hit_type0_startofpacket[5];
    assign aso_hit_type0_5_endofpacket   = hit_type0_endofpacket[5];
    assign aso_hit_type0_5_endofrun      = hit_type0_endofrun[5];

    assign aso_hit_type0_6_data          = hit_type0_data[6];
    assign aso_hit_type0_6_valid         = hit_type0_valid[6];
    assign aso_hit_type0_6_error         = hit_type0_error[6];
    assign aso_hit_type0_6_channel       = hit_type0_channel[6];
    assign aso_hit_type0_6_startofpacket = hit_type0_startofpacket[6];
    assign aso_hit_type0_6_endofpacket   = hit_type0_endofpacket[6];
    assign aso_hit_type0_6_endofrun      = hit_type0_endofrun[6];

    assign aso_hit_type0_7_data          = hit_type0_data[7];
    assign aso_hit_type0_7_valid         = hit_type0_valid[7];
    assign aso_hit_type0_7_error         = hit_type0_error[7];
    assign aso_hit_type0_7_channel       = hit_type0_channel[7];
    assign aso_hit_type0_7_startofpacket = hit_type0_startofpacket[7];
    assign aso_hit_type0_7_endofpacket   = hit_type0_endofpacket[7];
    assign aso_hit_type0_7_endofrun      = hit_type0_endofrun[7];

    // ----- shared debug taps (lane 0 view) ------------------------------
    assign coe_debug_fifo_fill_level    = debug_fifo_fill_level[0];
    assign coe_debug_hit_metadata       = hit_debug_data[0];
    assign coe_debug_hit_metadata_valid = hit_debug_valid[0];
    assign aso_hit_debug_data           = hit_debug_data[0];
    assign aso_hit_debug_valid          = hit_debug_valid[0];
    assign aso_hit_debug_channel        = hit_debug_channel[0];
    assign aso_hit_debug_startofpacket  = hit_debug_startofpacket[0];
    assign aso_hit_debug_endofpacket    = hit_debug_endofpacket[0];
    assign aso_hit_debug_endofrun       = hit_debug_endofrun[0];

    emulator_mutrig #(
        .LANE_COUNT(LANE_COUNT),
        .BYTE_STREAM_ENABLE(BYTE_STREAM_ENABLE),
        .IP_UID(IP_UID),
        .VERSION_MAJOR(VERSION_MAJOR),
        .VERSION_MINOR(VERSION_MINOR),
        .VERSION_PATCH(VERSION_PATCH),
        .BUILD(BUILD),
        .VERSION_DATE(VERSION_DATE),
        .VERSION_GIT(VERSION_GIT),
        .INSTANCE_ID(INSTANCE_ID),
        .ASIC_ID_BASE_DEFAULT(ASIC_ID_DEFAULT),
        .DEBUG_LEVEL(DEBUG_LEVEL)
    ) u_emulator_mutrig (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .asi_ctrl_data(asi_ctrl_data),
        .asi_ctrl_valid(asi_ctrl_valid),
        .asi_ctrl_ready(asi_ctrl_ready),
        .coe_inject_pulse(coe_inject_pulse | coe_inject_masked_pulse),
        .avs_csr_address(csr_address_extended),
        .avs_csr_read(avs_csr_read),
        .avs_csr_write(avs_csr_write),
        .avs_csr_writedata(avs_csr_writedata),
        .avs_csr_readdata(avs_csr_readdata),
        .avs_csr_waitrequest(avs_csr_waitrequest),
        .aso_hit_type0_data(hit_type0_data),
        .aso_hit_type0_valid(hit_type0_valid),
        .aso_hit_type0_startofpacket(hit_type0_startofpacket),
        .aso_hit_type0_endofpacket(hit_type0_endofpacket),
        .aso_hit_type0_endofrun(hit_type0_endofrun),
        .aso_hit_type0_error(hit_type0_error),
        .aso_hit_type0_channel(hit_type0_channel),
        .coe_debug_fifo_fill_level(debug_fifo_fill_level),
        .aso_hit_debug_data(hit_debug_data),
        .aso_hit_debug_valid(hit_debug_valid),
        .aso_hit_debug_channel(hit_debug_channel),
        .aso_hit_debug_startofpacket(hit_debug_startofpacket),
        .aso_hit_debug_endofpacket(hit_debug_endofpacket),
        .aso_hit_debug_endofrun(hit_debug_endofrun),
        .aso_tx8b1k_data(tx8b1k_data),
        .aso_tx8b1k_valid(tx8b1k_valid),
        .aso_tx8b1k_error(tx8b1k_error),
        .aso_tx8b1k_channel(tx8b1k_channel)
    );

endmodule
