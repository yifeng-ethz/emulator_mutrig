// be_mutrig_pkg.sv
// MuTRiG back-end constants, types, and hit packing helpers
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260502
// Change  : Add the back-end MuTRiG package split from legacy shared constants.

package be_mutrig_pkg;

    localparam int N_CHANNELS           = 32;
    localparam int CHANNEL_WIDTH        = 5;
    localparam int N_GROUPS             = 4;
    localparam int N_CHAN_PER_GROUP     = 8;
    localparam int MAX_EMU_LANES        = 8;
    localparam int CLUSTER_LANE_WIDTH   = 4;
    localparam int GLOBAL_CHANNEL_WIDTH = 8;
    localparam int FRAME_INTERVAL_LONG  = 1550;
    localparam int FRAME_INTERVAL_SHORT = 910;
    localparam int TCC_WIDTH            = 15;
    localparam logic [14:0] LFSR15_INIT = 15'h0001;
    localparam int MUTRIG_COARSE_STEPS_PER_CYCLE = 5;
    localparam logic [7:0] K28_0 = 8'h1C;
    localparam logic [7:0] K28_4 = 8'h9C;
    localparam logic [7:0] K28_5 = 8'hBC;
    localparam logic [2:0] TX_MODE_LONG     = 3'b000;
    localparam logic [2:0] TX_MODE_PRBS_1   = 3'b001;
    localparam logic [2:0] TX_MODE_PRBS_SAT = 3'b010;
    localparam logic [2:0] TX_MODE_SHORT    = 3'b100;
    localparam int HIT_LONG_WIDTH           = 48;
    localparam int HIT_SHORT_WIDTH          = 28;
    localparam int N_BYTES_LONG             = 6;
    localparam int N_BYTES_SHORT            = 3;
    localparam int RAW_FIFO_DEPTH           = 256;
    localparam int FIFO_ALMOST_FULL_MARGIN  = 3;

    typedef enum logic [1:0] {
        HIT_MODE_POISSON     = 2'b00,
        HIT_MODE_BURST       = 2'b01,
        HIT_MODE_POISSON_IID = 2'b10,
        HIT_MODE_PERIODIC    = 2'b11
    } hit_mode_t;

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
        return {channel, t_badhit, tcc, t_fine, e_badhit, ecc, e_fine, e_flag};
    endfunction

    function automatic logic [27:0] pack_hit_short(
        input logic [4:0]  channel,
        input logic        e_badhit,
        input logic [14:0] tcc,
        input logic [4:0]  t_fine,
        input logic        e_flag
    );
        return {channel, e_badhit, tcc, t_fine, e_flag, 1'b0};
    endfunction

endpackage
