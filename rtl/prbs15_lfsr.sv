// prbs15_lfsr.sv
// PRBS-15 LFSR coarse counter matching MuTRiG 3 ASIC TDC
//
// Polynomial: x^15 + x^1 + 1
// Feedback:   new_bit = sreg[14] XOR sreg[0]
// Init state: all 1s (15'h7FFF)
// Period:     2^15 - 1 = 32767
//
// The real MuTRiG TDC has a dual-edge coarse counter (CCM on rising, CCS on falling
// of thermometer code bit 8). For the emulator we provide a single LFSR that advances
// on each byte-clock tick, representing the coarse time reference.

module prbs15_lfsr (
    input  logic        clk,
    input  logic        rst,
    input  logic        en,       // advance LFSR by one step
    output logic [14:0] lfsr_out
);

    logic [14:0] sreg;

    assign lfsr_out = sreg;

    always_ff @(posedge clk) begin
        if (rst) begin
            sreg <= 15'h7FFF;  // all-ones init, matching MuTRiG
        end else if (en) begin
            // Galois LFSR: x^15 + x^1 + 1
            // Shift left, new LSB = bit[14] XOR bit[0]
            sreg <= {sreg[13:0], sreg[14] ^ sreg[0]};
        end
    end

endmodule
