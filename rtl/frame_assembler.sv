// frame_assembler.sv
// MuTRiG frame assembler — produces 8b/1k parallel output
// Version : 26.1.1
// Date    : 20260417
// Change  : Start each run on a full frame interval so burst clusters are not split by an immediate post-reset frame header.
//
// Generates frames matching the MuTRiG 3 ASIC serial output format:
//   IDLE(K28.5) | K28.0(header) | frame_count[15:8] | frame_count[7:0] |
//   flags_evtcnt[15:8] | flags_evtcnt[7:0] | hit_data... | CRC[15:8] | CRC[7:0] | K28.4(trailer)
//
// Output: 9-bit {is_k, data[7:0]} at byte_clk rate
// This directly feeds the FPGA-side frame_rcv_ip (asi_rx8b1k_data).

module frame_assembler
    import emulator_mutrig_pkg::*;
#(
    parameter int MAX_EVENTS_PER_FRAME = 120  // max hits per frame (safety limit)
)(
    input  logic        clk,           // byte clock (architect target: 125 MHz)
    input  logic        rst,
    input  logic        allow_frame_start,

    // Configuration
    input  logic        cfg_short_mode,    // 1=short, 0=long
    input  logic        cfg_gen_idle,      // generate idle comma between frames
    input  logic [2:0]  cfg_tx_mode,       // tx_mode bits for flags

    // Hit FIFO interface
    output logic        fifo_rd_en,
    input  logic [47:0] fifo_data,
    input  logic [9:0]  event_count,
    input  logic        fifo_empty,
    input  logic        fifo_almost_full,

    // Frame timing
    output logic        frame_start,       // pulse at start of each frame

    // 8b/1k output (directly compatible with frame_rcv_ip input)
    output logic [8:0]  tx_data,           // {is_k, data[7:0]}
    output logic        tx_valid
);

    // ========================================
    // Frame interval counter
    // ========================================
    logic [10:0] interval_cnt;
    logic       interval_tick;
    logic [10:0] max_interval;

    assign max_interval = cfg_short_mode ? 11'(FRAME_INTERVAL_SHORT) : 11'(FRAME_INTERVAL_LONG);

    always_ff @(posedge clk) begin
        if (rst) begin
            interval_cnt  <= max_interval - 11'd1;
            interval_tick <= 1'b0;
        end else begin
            if (interval_cnt == '0) begin
                interval_tick <= 1'b1;
                interval_cnt  <= max_interval - 11'd1;
            end else begin
                interval_tick <= 1'b0;
                interval_cnt  <= interval_cnt - 11'd1;
            end
        end
    end

    // ========================================
    // FSM
    // ========================================
    typedef enum logic [3:0] {
        FS_IDLE,
        FS_HEADER,
        FS_FRAMECOUNT,
        FS_EVENTCOUNT,
        FS_PACK,
        FS_PACK_EXTRA,
        FS_DELAY,
        FS_CRC_REM,
        FS_TRAILER
    } fsm_t;

    fsm_t state;

    logic [15:0] frame_count;
    logic [9:0]  evt_cnt_latch;
    logic [9:0]  evt_remaining;  // unread hits that are not yet prefetched
    logic [9:0]  pack_evt_cnt;
    logic        last_event;
    logic [2:0]  byte_count;     // bytes remaining in current word/state
    logic [47:0] shift_reg;      // data shift register
    logic        fifo_full_latch;

    // CRC interface
    logic        crc_rst, crc_valid;
    logic [7:0]  crc_din;
    logic [15:0] crc_result;

    // Frame flags
    // [5] gen_idle, [4] fast_mode, [3] prbs_debug, [2] single_prbs, [1] fifo_full, [0] pll_lol
    logic [5:0]  frame_flags;

    assign frame_flags = {cfg_gen_idle, cfg_tx_mode[2], cfg_tx_mode[1], cfg_tx_mode[0], fifo_full_latch, 1'b0};

    // Event count extended (2 bytes: flags + count)
    logic [15:0] evt_count_ext;
    assign evt_count_ext = {frame_flags, evt_cnt_latch};

    // Output byte
    logic [7:0] out_byte;
    logic       out_isk;

    assign tx_data  = {out_isk, out_byte};
    assign tx_valid = 1'b1; // always valid once running

    // CRC input is the output byte when we're in data states
    assign crc_din = out_byte;

    // ========================================
    // CRC-16 instance
    // ========================================
    crc16_8 u_crc (
        .clk     (clk),
        .rst     (crc_rst),
        .d_valid (crc_valid),
        .din     (crc_din),
        .crc_reg (crc_result),
        .crc_8   ()
    );

    // ========================================
    // Short-mode hit packing
    // ========================================
    // In short mode, 28-bit hits are packed as:
    //   event_data_short = {channel[4:0], E_BadHit, TCC[14:0], T_Fine[4:0], E_Flag, 1'b0}
    // From the 48-bit FIFO word (which stores data in long-mode positions):
    logic [27:0] short_hit;
    assign short_hit = {fifo_data[47:43],  // channel
                        fifo_data[42],     // E_BadHit (mapped from T_BadHit position in short storage)
                        fifo_data[41:27],  // TCC
                        fifo_data[26:22],  // T_Fine
                        fifo_data[20],     // E_Flag
                        1'b0};             // pad

    // ========================================
    // Frame assembly FSM
    // ========================================
    always_ff @(posedge clk) begin
        if (rst) begin
            state           <= FS_IDLE;
            frame_count     <= '0;
            out_byte        <= K28_5;
            out_isk         <= 1'b1;
            crc_rst         <= 1'b1;
            crc_valid       <= 1'b0;
            fifo_rd_en      <= 1'b0;
            frame_start     <= 1'b0;
            evt_cnt_latch   <= '0;
            evt_remaining   <= '0;
            pack_evt_cnt    <= '0;
            last_event      <= 1'b0;
            byte_count      <= '0;
            shift_reg       <= '0;
            fifo_full_latch <= 1'b0;
        end else begin
            fifo_rd_en  <= 1'b0;  // default
            frame_start <= 1'b0;  // default

            case (state)
                // ----------------------------------------
                FS_IDLE: begin
                    out_byte <= K28_5;
                    out_isk  <= 1'b1;
                    crc_rst  <= 1'b1;
                    crc_valid <= 1'b0;

                    if (allow_frame_start && interval_tick) begin
                        frame_start     <= 1'b1;
                        evt_cnt_latch   <= event_count;
                        evt_remaining   <= event_count;
                        pack_evt_cnt    <= '0;
                        last_event      <= 1'b0;
                        fifo_full_latch <= fifo_almost_full;
                        state           <= FS_HEADER;
                    end
                end

                // ----------------------------------------
                FS_HEADER: begin
                    out_byte   <= K28_0;
                    out_isk    <= 1'b1;
                    byte_count <= 3'd2;
                    state      <= FS_FRAMECOUNT;

                end

                // ----------------------------------------
                FS_FRAMECOUNT: begin
                    crc_rst   <= 1'b0;
                    crc_valid <= 1'b1;
                    out_isk   <= 1'b0;

                    case (byte_count)
                        3'd2: begin
                            out_byte   <= frame_count[15:8];
                            byte_count <= 3'd1;
                            if (evt_cnt_latch != 10'd0) begin
                                fifo_rd_en    <= 1'b1;
                                evt_remaining <= evt_cnt_latch - 10'd1;
                            end
                        end
                        3'd1: begin
                            out_byte   <= frame_count[7:0];
                            byte_count <= 3'd2;
                            state      <= FS_EVENTCOUNT;
                        end
                        default: byte_count <= 3'd1;
                    endcase
                end

                // ----------------------------------------
                FS_EVENTCOUNT: begin
                    out_isk <= 1'b0;

                    case (byte_count)
                        3'd2: begin
                            out_byte   <= evt_count_ext[15:8];
                            byte_count <= 3'd1;
                        end
                        3'd1: begin
                            out_byte   <= evt_count_ext[7:0];
                            if (evt_cnt_latch != 10'd0) begin
                                state <= FS_PACK;
                                if (cfg_short_mode) begin
                                    shift_reg  <= {short_hit, 20'b0};
                                    byte_count <= 3'd3;
                                    if (evt_remaining != 10'd0 && !fifo_empty) begin
                                        fifo_rd_en    <= 1'b1;
                                        evt_remaining <= evt_remaining - 10'd1;
                                        last_event    <= 1'b0;
                                    end else begin
                                        last_event <= 1'b1;
                                    end
                                end else begin
                                    shift_reg  <= fifo_data;
                                    byte_count <= 3'd6;
                                    if (evt_remaining == 10'd0)
                                        last_event <= 1'b1;
                                    else
                                        last_event <= 1'b0;
                                end
                            end else begin
                                state <= FS_DELAY;
                            end
                        end
                        default: byte_count <= 3'd1;
                    endcase
                end

                // ----------------------------------------
                FS_PACK: begin
                    // Shift out MSB byte
                    out_byte  <= shift_reg[47:40];
                    out_isk   <= 1'b0;
                    shift_reg <= {shift_reg[39:0], 8'b0};
                    byte_count <= byte_count - 3'd1;

                    if (!cfg_short_mode) begin
                        if (last_event) begin
                            if (byte_count == 3'd1)
                                state <= FS_DELAY;
                        end else begin
                            if (byte_count == 3'd4 && evt_remaining != 10'd0 && !fifo_empty) begin
                                fifo_rd_en    <= 1'b1;
                                evt_remaining <= evt_remaining - 10'd1;
                            end
                            if (byte_count == 3'd1) begin
                                shift_reg  <= fifo_data;
                                byte_count <= 3'd6;
                                if (evt_remaining == 10'd0)
                                    last_event    <= 1'b1;
                                else
                                    last_event    <= 1'b0;
                            end
                        end
                    end else begin
                        if (last_event) begin
                            if (byte_count == 3'd1)
                                state <= FS_PACK_EXTRA;
                        end else begin
                            if (byte_count == 3'd1) begin
                                if (pack_evt_cnt[0] == 1'b0) begin
                                    shift_reg[47:44] <= shift_reg[39:36];  // leftover 4 bits
                                    shift_reg[43:16] <= short_hit;
                                    shift_reg[15:0]  <= 16'b0;
                                    byte_count       <= 3'd3;
                                    pack_evt_cnt     <= pack_evt_cnt + 10'd1;
                                    if (evt_remaining != 10'd0 && !fifo_empty) begin
                                        fifo_rd_en    <= 1'b1;
                                        evt_remaining <= evt_remaining - 10'd1;
                                    end
                                    if (evt_remaining == 10'd0)
                                        last_event <= 1'b1;
                                    else
                                        last_event <= 1'b0;
                                end else begin
                                    state <= FS_PACK_EXTRA;
                                end
                            end
                        end
                    end
                end

                // ----------------------------------------
                FS_PACK_EXTRA: begin
                    // Send leftover byte in short mode
                    out_byte  <= shift_reg[47:40];
                    out_isk   <= 1'b0;

                    if (last_event) begin
                        state <= FS_DELAY;
                    end else begin
                        shift_reg[47:20] <= short_hit;
                        shift_reg[19:0]  <= 20'b0;
                        byte_count       <= 3'd3;
                        pack_evt_cnt     <= pack_evt_cnt + 10'd1;
                        state            <= FS_PACK;
                        if (evt_remaining != 10'd0 && !fifo_empty) begin
                            fifo_rd_en    <= 1'b1;
                            evt_remaining <= evt_remaining - 10'd1;
                        end
                        if (evt_remaining == 10'd0)
                            last_event <= 1'b1;
                        else
                            last_event <= 1'b0;
                    end
                end

                // ----------------------------------------
                FS_DELAY: begin
                    // One cycle delay for CRC to settle
                    crc_valid  <= 1'b0;
                    byte_count <= 3'd2;
                    state      <= FS_CRC_REM;
                end

                // ----------------------------------------
                FS_CRC_REM: begin
                    out_isk <= 1'b0;
                    case (byte_count)
                        3'd2: begin
                            out_byte   <= crc_result[15:8];
                            byte_count <= 3'd1;
                        end
                        3'd1: begin
                            out_byte   <= crc_result[7:0];
                            state      <= FS_TRAILER;
                            byte_count <= 3'd2;
                        end
                        default: byte_count <= 3'd1;
                    endcase
                end

                // ----------------------------------------
                FS_TRAILER: begin
                    case (byte_count)
                        3'd2: begin
                            out_byte   <= K28_4;
                            out_isk    <= 1'b1;
                            byte_count <= 3'd1;
                        end
                        3'd1: begin
                            // Pseudo-trailer cycle (compensate CRC delay, same as real MuTRiG)
                            frame_count <= frame_count + 16'd1;
                            out_byte    <= K28_5;
                            out_isk     <= 1'b1;
                            state       <= FS_IDLE;
                        end
                        default: byte_count <= 3'd1;
                    endcase
                end

                default: state <= FS_IDLE;
            endcase
        end
    end

endmodule
