// be_mutrig_frame_assembler.sv
// Optional MuTRiG 8b/1k frame emitter.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260502
// Change  : Add generate-gated backend frame assembler for refreshed lanes.

module be_mutrig_frame_assembler
    import be_mutrig_pkg::*;
(
    input  logic        clk,
    input  logic        rst,
    input  logic        frame_start_req,

    input  logic        cfg_short_mode,
    input  logic        cfg_gen_idle,
    input  logic [2:0]  cfg_tx_mode,

    output logic        fifo_rd_en,
    input  logic [47:0] fifo_data,
    input  logic        fifo_rd_valid,
    input  logic [9:0]  event_count,
    input  logic        fifo_empty,
    input  logic        fifo_almost_full,

    output logic        frame_start,
    output logic [8:0]  tx_data,
    output logic        tx_valid
);

    typedef enum logic [3:0] {
        IDLING,
        HEADERING,
        FRAME_HI,
        FRAME_LO,
        COUNT_HI,
        COUNT_LO,
        REQUESTING,
        WAITING,
        HITTING,
        CRC_HI,
        CRC_LO,
        TRAILERING
    } state_t;

    state_t state;
    logic [15:0] frame_count;
    logic [7:0] event_latch;
    logic [7:0] event_remaining;
    logic [47:0] hit_shift;
    logic [2:0] byte_remaining;
    logic [15:0] crc_result;
    logic crc_rst;
    logic crc_dvalid;
    logic [7:0] crc_din;
    logic fifo_full_latch;
    logic [15:0] event_count_ext;
    logic [27:0] short_hit;

    assign tx_valid = 1'b1;
    assign event_count_ext = {cfg_gen_idle, cfg_tx_mode, fifo_full_latch, 1'b0, 2'b00, event_latch};
    assign short_hit = pack_hit_short(fifo_data[47:43], fifo_data[21], fifo_data[20:6], fifo_data[5:1], fifo_data[0]);

    crc16_8 u_crc (
        .clk     (clk),
        .rst     (crc_rst),
        .d_valid (crc_dvalid),
        .din     (crc_din),
        .crc_reg (crc_result),
        .crc_8   ()
    );

    always_ff @(posedge clk) begin
        if (rst) begin
            state <= IDLING;
            frame_count <= 16'h0000;
            event_latch <= 8'h00;
            event_remaining <= 8'h00;
            hit_shift <= 48'h0000_0000_0000;
            byte_remaining <= 3'h0;
            fifo_full_latch <= 1'b0;
            fifo_rd_en <= 1'b0;
            frame_start <= 1'b0;
            tx_data <= {1'b1, K28_5_CONST};
            crc_rst <= 1'b1;
            crc_dvalid <= 1'b0;
            crc_din <= 8'h00;
        end else begin
            fifo_rd_en <= 1'b0;
            frame_start <= 1'b0;
            crc_dvalid <= 1'b0;
            crc_rst <= 1'b0;

            unique case (state)
                IDLING: begin
                    tx_data <= {1'b1, K28_5_CONST};
                    crc_rst <= 1'b1;
                    if (frame_start_req) begin
                        frame_start <= 1'b1;
                        event_latch <= (event_count > 10'd255) ? 8'hFF : event_count[7:0];
                        event_remaining <= (event_count > 10'd255) ? 8'hFF : event_count[7:0];
                        fifo_full_latch <= fifo_almost_full;
                        state <= cfg_gen_idle ? HEADERING : HEADERING;
                    end
                end

                HEADERING: begin
                    tx_data <= {1'b1, K28_0_CONST};
                    state <= FRAME_HI;
                end

                FRAME_HI: begin
                    tx_data <= {1'b0, frame_count[15:8]};
                    crc_din <= frame_count[15:8];
                    crc_dvalid <= 1'b1;
                    state <= FRAME_LO;
                end

                FRAME_LO: begin
                    tx_data <= {1'b0, frame_count[7:0]};
                    crc_din <= frame_count[7:0];
                    crc_dvalid <= 1'b1;
                    state <= COUNT_HI;
                end

                COUNT_HI: begin
                    tx_data <= {1'b0, event_count_ext[15:8]};
                    crc_din <= event_count_ext[15:8];
                    crc_dvalid <= 1'b1;
                    state <= COUNT_LO;
                end

                COUNT_LO: begin
                    tx_data <= {1'b0, event_count_ext[7:0]};
                    crc_din <= event_count_ext[7:0];
                    crc_dvalid <= 1'b1;
                    state <= (event_remaining == 8'h00) ? CRC_HI : REQUESTING;
                end

                REQUESTING: begin
                    tx_data <= {1'b1, K28_5_CONST};
                    if (!fifo_empty) begin
                        fifo_rd_en <= 1'b1;
                        state <= WAITING;
                    end else begin
                        event_remaining <= 8'h00;
                        state <= CRC_HI;
                    end
                end

                WAITING: begin
                    tx_data <= {1'b1, K28_5_CONST};
                    if (fifo_rd_valid) begin
                        if (cfg_short_mode) begin
                            hit_shift <= {short_hit, 20'h00000};
                            byte_remaining <= 3'd4;
                        end else begin
                            hit_shift <= fifo_data;
                            byte_remaining <= 3'd6;
                        end
                        event_remaining <= event_remaining - 8'd1;
                        state <= HITTING;
                    end
                end

                HITTING: begin
                    tx_data <= {1'b0, hit_shift[47:40]};
                    crc_din <= hit_shift[47:40];
                    crc_dvalid <= 1'b1;
                    hit_shift <= {hit_shift[39:0], 8'h00};
                    byte_remaining <= byte_remaining - 3'd1;
                    if (byte_remaining == 3'd1) begin
                        state <= (event_remaining == 8'h00) ? CRC_HI : REQUESTING;
                    end
                end

                CRC_HI: begin
                    tx_data <= {1'b0, crc_result[15:8]};
                    state <= CRC_LO;
                end

                CRC_LO: begin
                    tx_data <= {1'b0, crc_result[7:0]};
                    state <= TRAILERING;
                end

                TRAILERING: begin
                    tx_data <= {1'b1, K28_4_CONST};
                    frame_count <= frame_count + 16'd1;
                    state <= IDLING;
                end

                default: begin
                    state <= IDLING;
                end
            endcase
        end
    end

endmodule
