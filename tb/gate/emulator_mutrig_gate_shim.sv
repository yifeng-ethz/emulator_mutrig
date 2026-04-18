module emulator_mutrig #(
    parameter int FIFO_DEPTH = 64,
    parameter int CSR_ADDR_WIDTH = 4
) (
    input  logic        i_clk,
    input  logic        i_rst,
    output logic [8:0]  aso_tx8b1k_data,
    output logic        aso_tx8b1k_valid,
    output logic [3:0]  aso_tx8b1k_channel,
    output logic [2:0]  aso_tx8b1k_error,
    input  logic [8:0]  asi_ctrl_data,
    input  logic        asi_ctrl_valid,
    output logic        asi_ctrl_ready,
    input  logic        coe_inject_pulse,
    input  logic        coe_inject_masked_pulse,
    input  logic [3:0]  avs_csr_address,
    input  logic        avs_csr_read,
    input  logic        avs_csr_write,
    input  logic [31:0] avs_csr_writedata,
    output logic [31:0] avs_csr_readdata,
    output logic        avs_csr_waitrequest
);

    emulator_mutrig_syn_top u_gate (
        .clk125              (i_clk),
        .reset_n             (~i_rst),
        .asi_ctrl_data       (asi_ctrl_data),
        .asi_ctrl_valid      (asi_ctrl_valid),
        .coe_inject_pulse    (coe_inject_pulse),
        .coe_inject_masked_pulse(coe_inject_masked_pulse),
        .avs_csr_address     (avs_csr_address),
        .avs_csr_read        (avs_csr_read),
        .avs_csr_write       (avs_csr_write),
        .avs_csr_writedata   (avs_csr_writedata),
        .aso_tx8b1k_data     (aso_tx8b1k_data),
        .aso_tx8b1k_valid    (aso_tx8b1k_valid),
        .aso_tx8b1k_channel  (aso_tx8b1k_channel),
        .aso_tx8b1k_error    (aso_tx8b1k_error),
        .asi_ctrl_ready      (asi_ctrl_ready),
        .avs_csr_readdata    (avs_csr_readdata),
        .avs_csr_waitrequest (avs_csr_waitrequest)
    );

endmodule
