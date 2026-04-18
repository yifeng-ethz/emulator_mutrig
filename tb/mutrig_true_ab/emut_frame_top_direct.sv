`timescale 1ns/1ps

module emut_frame_top_direct
    import emulator_mutrig_pkg::*;
#(
    parameter int FIFO_DEPTH = RAW_FIFO_DEPTH
)(
    input  logic        clk,
    input  logic        rst,
    input  logic        frame_start_req,
    input  logic        cfg_short_mode,
    input  logic        cfg_gen_idle,
    input  logic [2:0]  cfg_tx_mode,
    input  logic        offer_valid,
    input  logic [47:0] offer_word,
    output logic        offer_ready,
    output logic        accept_pulse,
    output logic [47:0] accept_word,
    output logic        frame_mark,
    output logic [9:0]  event_count,
    output logic        fifo_empty,
    output logic        fifo_full,
    output logic        fifo_almost_full,
    output logic [8:0]  tx_data,
    output logic        tx_valid
);

    localparam int FIFO_PTR_WIDTH = (FIFO_DEPTH > 1) ? $clog2(FIFO_DEPTH) : 1;
    localparam int FIFO_COUNT_WIDTH = FIFO_PTR_WIDTH + 1;
    localparam int FIFO_VISIBLE_MAX = (1 << FIFO_PTR_WIDTH) - 1;
    localparam int FIFO_ALMOST_FULL_LVL =
        (FIFO_DEPTH > 3) ? (FIFO_DEPTH - 3) : FIFO_DEPTH;

    logic [47:0] fifo_mem [0:FIFO_DEPTH-1];
    logic [FIFO_PTR_WIDTH-1:0] fifo_wr_ptr;
    logic [FIFO_PTR_WIDTH-1:0] fifo_rd_ptr;
    logic [FIFO_COUNT_WIDTH-1:0] fifo_count_exact;
    logic        fifo_rd_en;
    logic [47:0] fifo_data;
    logic        fifo_write_en;
    logic        fifo_read_en;
    logic        accept_pulse_r;
    logic [47:0] accept_word_r;

    function automatic logic [FIFO_PTR_WIDTH-1:0] fifo_ptr_next(
        input logic [FIFO_PTR_WIDTH-1:0] ptr
    );
        if (ptr == FIFO_PTR_WIDTH'(FIFO_DEPTH - 1))
            return '0;
        return ptr + FIFO_PTR_WIDTH'(1);
    endfunction

    assign fifo_empty       = (fifo_count_exact == FIFO_COUNT_WIDTH'(0));
    assign fifo_full        = (fifo_count_exact == FIFO_COUNT_WIDTH'(FIFO_DEPTH));
    assign fifo_almost_full = (fifo_count_exact >= FIFO_COUNT_WIDTH'(FIFO_ALMOST_FULL_LVL));
    assign offer_ready      = !fifo_full || fifo_rd_en;
    assign fifo_write_en    = offer_valid && !fifo_full;
    assign fifo_read_en     = fifo_rd_en && !fifo_empty;
    assign event_count      =
        (fifo_count_exact > FIFO_COUNT_WIDTH'(FIFO_VISIBLE_MAX)) ? 10'(FIFO_VISIBLE_MAX) :
                                                                   10'(fifo_count_exact);
    assign accept_pulse     = accept_pulse_r;
    assign accept_word      = accept_word_r;

    always_ff @(posedge clk) begin
        if (rst) begin
            fifo_wr_ptr    <= '0;
            fifo_rd_ptr    <= '0;
            fifo_count_exact <= '0;
            fifo_data      <= '0;
            accept_pulse_r <= 1'b0;
            accept_word_r  <= '0;
        end else begin
            accept_pulse_r <= fifo_write_en;
            if (fifo_write_en)
                accept_word_r <= offer_word;

            if (fifo_write_en) begin
                fifo_mem[fifo_wr_ptr] <= offer_word;
                fifo_wr_ptr           <= fifo_ptr_next(fifo_wr_ptr);
            end

            if (fifo_read_en) begin
                fifo_data   <= fifo_mem[fifo_rd_ptr];
                fifo_rd_ptr <= fifo_ptr_next(fifo_rd_ptr);
            end

            case ({fifo_write_en, fifo_read_en})
                2'b10: fifo_count_exact <= fifo_count_exact + FIFO_COUNT_WIDTH'(1);
                2'b01: fifo_count_exact <= fifo_count_exact - FIFO_COUNT_WIDTH'(1);
                default: fifo_count_exact <= fifo_count_exact;
            endcase
        end
    end

    frame_assembler u_frame_asm (
        .clk              (clk),
        .rst              (rst),
        .frame_start_req  (frame_start_req),
        .cfg_short_mode   (cfg_short_mode),
        .cfg_gen_idle     (cfg_gen_idle),
        .cfg_tx_mode      (cfg_tx_mode),
        .fifo_rd_en       (fifo_rd_en),
        .fifo_data        (fifo_data),
        .event_count      (event_count),
        .fifo_empty       (fifo_empty),
        .fifo_almost_full (fifo_almost_full),
        .frame_start      (frame_mark),
        .tx_data          (tx_data),
        .tx_valid         (tx_valid)
    );

endmodule
