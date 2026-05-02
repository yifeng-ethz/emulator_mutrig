// emulator_mutrig_syn_top.sv
// Quartus synthesis wrapper for emulator_mutrig.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260502
// Change  : Match the central-trigger top-level interface.

module emulator_mutrig_syn_top #(
    parameter int LANE_COUNT = 8
) (
    input  logic                      clk125,
    input  logic                      reset_n,
    input  logic [8:0]                asi_ctrl_data,
    input  logic                      asi_ctrl_valid,
    input  logic                      coe_inject_pulse,
    input  logic [5:0]                avs_csr_address,
    input  logic                      avs_csr_read,
    input  logic                      avs_csr_write,
    input  logic [31:0]               avs_csr_writedata,
    output logic [LANE_COUNT*45-1:0]  aso_hit_type0_data,
    output logic [LANE_COUNT-1:0]     aso_hit_type0_valid,
    output logic [LANE_COUNT-1:0]     aso_hit_type0_startofpacket,
    output logic [LANE_COUNT-1:0]     aso_hit_type0_endofpacket,
    output logic [LANE_COUNT-1:0]     aso_hit_type0_endofrun,
    output logic [LANE_COUNT*3-1:0]   aso_hit_type0_error,
    output logic [LANE_COUNT*4-1:0]   aso_hit_type0_channel,
    output logic [LANE_COUNT*9-1:0]   aso_tx8b1k_data,
    output logic [LANE_COUNT-1:0]     aso_tx8b1k_valid,
    output logic [LANE_COUNT*3-1:0]   aso_tx8b1k_error,
    output logic [LANE_COUNT*4-1:0]   aso_tx8b1k_channel,
    output logic                      asi_ctrl_ready,
    output logic [31:0]               avs_csr_readdata,
    output logic                      avs_csr_waitrequest
);

    logic i_rst;
    logic [LANE_COUNT-1:0][44:0] hit_type0_data_bus;
    logic [LANE_COUNT-1:0][2:0]  hit_type0_error_bus;
    logic [LANE_COUNT-1:0][3:0]  hit_type0_channel_bus;
    logic [LANE_COUNT-1:0][8:0]  tx8b1k_data_bus;
    logic [LANE_COUNT-1:0][2:0]  tx8b1k_error_bus;
    logic [LANE_COUNT-1:0][3:0]  tx8b1k_channel_bus;

    assign i_rst = ~reset_n;

    genvar lane_idx;
    generate
        for (lane_idx = 0; lane_idx < LANE_COUNT; lane_idx++) begin : flatten_gen
            assign aso_hit_type0_data[(lane_idx*45) +: 45] = hit_type0_data_bus[lane_idx];
            assign aso_hit_type0_error[(lane_idx*3) +: 3] = hit_type0_error_bus[lane_idx];
            assign aso_hit_type0_channel[(lane_idx*4) +: 4] = hit_type0_channel_bus[lane_idx];
            assign aso_tx8b1k_data[(lane_idx*9) +: 9] = tx8b1k_data_bus[lane_idx];
            assign aso_tx8b1k_error[(lane_idx*3) +: 3] = tx8b1k_error_bus[lane_idx];
            assign aso_tx8b1k_channel[(lane_idx*4) +: 4] = tx8b1k_channel_bus[lane_idx];
        end
    endgenerate

    emulator_mutrig #(
        .LANE_COUNT         (LANE_COUNT),
        .BYTE_STREAM_ENABLE (1'b0)
    ) u_dut (
        .i_clk                       (clk125),
        .i_rst                       (i_rst),
        .asi_ctrl_data               (asi_ctrl_data),
        .asi_ctrl_valid              (asi_ctrl_valid),
        .asi_ctrl_ready              (asi_ctrl_ready),
        .coe_inject_pulse            (coe_inject_pulse),
        .avs_csr_address             (avs_csr_address),
        .avs_csr_read                (avs_csr_read),
        .avs_csr_write               (avs_csr_write),
        .avs_csr_writedata           (avs_csr_writedata),
        .avs_csr_readdata            (avs_csr_readdata),
        .avs_csr_waitrequest         (avs_csr_waitrequest),
        .aso_hit_type0_data          (hit_type0_data_bus),
        .aso_hit_type0_valid         (aso_hit_type0_valid),
        .aso_hit_type0_startofpacket (aso_hit_type0_startofpacket),
        .aso_hit_type0_endofpacket   (aso_hit_type0_endofpacket),
        .aso_hit_type0_endofrun      (aso_hit_type0_endofrun),
        .aso_hit_type0_error         (hit_type0_error_bus),
        .aso_hit_type0_channel       (hit_type0_channel_bus),
        .aso_tx8b1k_data             (tx8b1k_data_bus),
        .aso_tx8b1k_valid            (aso_tx8b1k_valid),
        .aso_tx8b1k_error            (tx8b1k_error_bus),
        .aso_tx8b1k_channel          (tx8b1k_channel_bus)
    );

endmodule
