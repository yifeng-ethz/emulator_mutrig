// be_mutrig_lane_type0_emit.sv
// MuTRiG lane hit_type0 emitter.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260502
// Change  : Add direct 45-bit hit_type0 path with functional error injection.

module be_mutrig_lane_type0_emit
    import be_mutrig_pkg::*;
#(
    parameter int FIFO_COUNT_WIDTH = 10
) (
    input  logic                         clk,
    input  logic                         rst,
    input  logic                         enable,
    input  logic                         own_drain,
    input  logic                         frame_start_req,
    input  logic                         frame_start_allowed,
    input  logic                         run_terminating,
    input  logic                         run_idle,
    input  logic [3:0]                   asic_id,
    input  logic [2:0]                   error_inject_mask,
    input  logic                         error_target_lane,

    input  logic                         l2_empty,
    input  logic [FIFO_COUNT_WIDTH-1:0]  l2_level,
    output logic                         l2_rd_en,
    input  logic [47:0]                  l2_rd_data,
    input  logic                         l2_rd_valid,

    output logic [3:0]                   aso_hit_type0_channel,
    output logic                         aso_hit_type0_startofpacket,
    output logic                         aso_hit_type0_endofpacket,
    output logic                         aso_hit_type0_endofrun,
    output logic [2:0]                   aso_hit_type0_error,
    output logic [44:0]                  aso_hit_type0_data,
    output logic                         aso_hit_type0_valid
);

    logic [FIFO_COUNT_WIDTH-1:0] issue_remaining;
    logic [FIFO_COUNT_WIDTH-1:0] emit_remaining;
    logic in_packet;
    logic prev_terminating;

    assign l2_rd_en = own_drain && enable && (issue_remaining != '0) && !l2_empty;
    assign aso_hit_type0_channel = asic_id;
    assign aso_hit_type0_error = error_target_lane ? error_inject_mask : 3'b000;

    always_ff @(posedge clk) begin
        if (rst) begin
            issue_remaining <= '0;
            emit_remaining <= '0;
            in_packet <= 1'b0;
            prev_terminating <= 1'b0;
            aso_hit_type0_startofpacket <= 1'b0;
            aso_hit_type0_endofpacket <= 1'b0;
            aso_hit_type0_endofrun <= 1'b0;
            aso_hit_type0_data <= '0;
            aso_hit_type0_valid <= 1'b0;
        end else begin
            aso_hit_type0_startofpacket <= 1'b0;
            aso_hit_type0_endofpacket <= 1'b0;
            aso_hit_type0_endofrun <= 1'b0;
            aso_hit_type0_valid <= 1'b0;
            prev_terminating <= run_terminating;

            if (frame_start_req && frame_start_allowed && enable && !l2_empty) begin
                issue_remaining <= l2_level;
                emit_remaining <= l2_level;
            end

            if (l2_rd_en && (issue_remaining != '0)) begin
                issue_remaining <= issue_remaining - FIFO_COUNT_WIDTH'(1);
            end

            if (enable && l2_rd_valid && (emit_remaining != '0)) begin
                aso_hit_type0_valid <= 1'b1;
                aso_hit_type0_data <= pack_hit_type0(l2_rd_data, asic_id);
                aso_hit_type0_startofpacket <= !in_packet;
                aso_hit_type0_endofpacket <= (emit_remaining == FIFO_COUNT_WIDTH'(1));

                if (emit_remaining == FIFO_COUNT_WIDTH'(1)) begin
                    emit_remaining <= '0;
                    in_packet <= 1'b0;
                end else begin
                    emit_remaining <= emit_remaining - FIFO_COUNT_WIDTH'(1);
                    in_packet <= 1'b1;
                end
            end

            if (prev_terminating && run_idle && l2_empty && (emit_remaining == '0)) begin
                aso_hit_type0_endofrun <= 1'b1;
            end

            if (!enable) begin
                issue_remaining <= '0;
                emit_remaining <= '0;
                in_packet <= 1'b0;
            end
        end
    end

endmodule
