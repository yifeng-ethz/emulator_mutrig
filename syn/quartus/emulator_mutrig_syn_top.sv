module emulator_mutrig_syn_top (
    input  logic        clk125,
    input  logic        reset_n,
    input  logic [8:0]  asi_ctrl_data,
    input  logic        asi_ctrl_valid,
    input  logic        coe_inject_pulse,
    input  logic [3:0]  avs_csr_address,
    input  logic        avs_csr_read,
    input  logic        avs_csr_write,
    input  logic [31:0] avs_csr_writedata,
    output logic [8:0]  aso_tx8b1k_data,
    output logic        aso_tx8b1k_valid,
    output logic [3:0]  aso_tx8b1k_channel,
    output logic [2:0]  aso_tx8b1k_error,
    output logic        asi_ctrl_ready,
    output logic [31:0] avs_csr_readdata,
    output logic        avs_csr_waitrequest
);

    logic i_rst;

    assign i_rst = ~reset_n;

    emulator_mutrig u_dut (
        .i_clk               (clk125),
        .i_rst               (i_rst),
        .aso_tx8b1k_data     (aso_tx8b1k_data),
        .aso_tx8b1k_valid    (aso_tx8b1k_valid),
        .aso_tx8b1k_channel  (aso_tx8b1k_channel),
        .aso_tx8b1k_error    (aso_tx8b1k_error),
        .asi_ctrl_data       (asi_ctrl_data),
        .asi_ctrl_valid      (asi_ctrl_valid),
        .asi_ctrl_ready      (asi_ctrl_ready),
        .coe_inject_pulse    (coe_inject_pulse),
        .avs_csr_address     (avs_csr_address),
        .avs_csr_read        (avs_csr_read),
        .avs_csr_write       (avs_csr_write),
        .avs_csr_writedata   (avs_csr_writedata),
        .avs_csr_readdata    (avs_csr_readdata),
        .avs_csr_waitrequest (avs_csr_waitrequest)
    );

endmodule
