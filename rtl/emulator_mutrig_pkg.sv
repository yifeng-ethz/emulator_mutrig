// emulator_mutrig_pkg.sv
// MuTRiG 3 emulator constants and types
// Author: Claude / Yifeng Wang
// Date: 2026-04-10
//
// Based on the MuTRiG 3 ASIC digital readout (Huangshan Chen, KIP Heidelberg)
// Reference: kbriggl-mutrig3-c3cce8d41dcb RTL

package emulator_mutrig_pkg;

    // ========================================
    // MuTRiG physical parameters
    // ========================================
    localparam int N_CHANNELS       = 32;       // 32 SiPM channels per ASIC
    localparam int CHANNEL_WIDTH    = 5;        // ceil(log2(32))

    // ========================================
    // Clock and timing
    // ========================================
    // Serial clock: 320 MHz (dual-edge → 640 Mbps)
    // Byte clock:   128 MHz (320/2.5, or ser_clk/5 for dual-edge)
    //   Actually: byte_clk = ser_clk / 5 (dual-edge serializer uses 5:1 ratio for 10-bit symbols)
    // Frame interval counter values (in byte_clk cycles)
    localparam int FRAME_INTERVAL_LONG  = 720;  // ~5.6 µs at 128 MHz byte clock
    localparam int FRAME_INTERVAL_SHORT = 420;  // ~3.3 µs at 128 MHz byte clock

    // ========================================
    // LFSR / PRBS-15 coarse counter
    // ========================================
    // Polynomial: x^15 + x^1 + 1  (Galois form: taps at bit 14 and bit 0)
    // Feedback:   new_bit = sreg[14] XOR sreg[0]
    // Init state: all 1s (0x7FFF)
    // Period:     2^15 - 1 = 32767
    localparam int TCC_WIDTH = 15;
    localparam logic [14:0] LFSR15_INIT = 15'h7FFF;

    // ========================================
    // 8b/10b K-characters
    // ========================================
    localparam logic [7:0] K28_0 = 8'h1C;  // Header
    localparam logic [7:0] K28_4 = 8'h9C;  // Trailer
    localparam logic [7:0] K28_5 = 8'hBC;  // Comma / Idle

    // ========================================
    // TX modes (from MuTRiG slow control)
    // ========================================
    localparam logic [2:0] TX_MODE_LONG       = 3'b000;
    localparam logic [2:0] TX_MODE_PRBS_1     = 3'b001;  // single PRBS word per frame
    localparam logic [2:0] TX_MODE_PRBS_SAT   = 3'b010;  // saturating PRBS
    localparam logic [2:0] TX_MODE_SHORT      = 3'b100;  // short hit (no energy)

    // ========================================
    // Hit data record (L2 format, 48 bits)
    // ========================================
    // Long hit word (48 bits):
    //   [47:43] channel  (5)
    //   [42]    T_BadHit (1)
    //   [41:27] TCC      (15) -- LFSR-15 encoded
    //   [26:22] T_Fine   (5)
    //   [21]    E_BadHit (1)
    //   [20]    E_Flag   (1)
    //   [19:5]  ECC      (15) -- LFSR-15 encoded
    //   [4:0]   E_Fine   (5)
    localparam int HIT_LONG_WIDTH  = 48;
    localparam int HIT_SHORT_WIDTH = 28;
    // Short hit word (28 bits):
    //   [27:23] channel  (5)
    //   [22]    E_BadHit (1)
    //   [21:7]  ECC      (15)
    //   [6:2]   E_Fine   (5)
    //   [1]     E_Flag   (1)
    //   [0]     pad      (1)

    // N_BYTES_PER_WORD for frame packing
    localparam int N_BYTES_LONG  = 6;  // 48/8
    localparam int N_BYTES_SHORT = 3;  // ceil(28/8)=4, but packed 3.5 bytes → alternates 3/4

    // ========================================
    // Frame flags (6 bits in event count word)
    // ========================================
    // [5] gen_idle_signal
    // [4] fast_mode (tx_mode[2])
    // [3] prbs_debug (tx_mode[1])
    // [2] single_prbs (tx_mode[0])
    // [1] fifo_full
    // [0] pll_lol (inverted)

    // ========================================
    // Hit generator modes
    // ========================================
    typedef enum logic [1:0] {
        HIT_MODE_POISSON  = 2'b00,  // i.i.d. Poisson across channels
        HIT_MODE_BURST    = 2'b01,  // burst of correlated/cluster hits
        HIT_MODE_NOISE    = 2'b10,  // noise-like random hits
        HIT_MODE_MIXED    = 2'b11   // mixed Poisson + burst
    } hit_mode_t;

    // ========================================
    // Helper functions
    // ========================================

    // Pack a long hit word
    function automatic logic [47:0] pack_hit_long(
        input logic [4:0]  channel,
        input logic        t_badhit,
        input logic [14:0] tcc,
        input logic [4:0]  t_fine,
        input logic        e_badhit,
        input logic        e_flag,
        input logic [14:0] ecc,
        input logic [4:0]  e_fine
    );
        return {channel, t_badhit, tcc, t_fine, e_badhit, e_flag, ecc, e_fine};
    endfunction

    // Pack a short hit word
    function automatic logic [27:0] pack_hit_short(
        input logic [4:0]  channel,
        input logic        e_badhit,
        input logic [14:0] ecc,
        input logic [4:0]  e_fine,
        input logic        e_flag
    );
        return {channel, e_badhit, ecc, e_fine, e_flag, 1'b0};
    endfunction

endpackage
