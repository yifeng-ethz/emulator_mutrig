// mutrig_tlm_contract_pkg.sv
// Source-derived raw MuTRiG datapath contract for emulator/UVM reference models
// Version : 26.0.3
// Date    : 20260416
// Change  : Capture the revived raw MuTRiG L1/L2/frame-generator contract in a standalone TLM package.

package mutrig_tlm_contract_pkg;

    localparam int N_CHANNELS_CONST              = 32;
    localparam int N_GROUPS_CONST                = 4;
    localparam int N_CHAN_PER_GROUP_CONST        = 8;
    localparam int L1_FIFO_DEPTH_CONST           = 256;
    localparam int L2_FIFO_DEPTH_CONST           = 256;
    localparam int FIFO_ALMOST_FULL_MARGIN_CONST = 3;
    localparam int FRAME_INTERVAL_LONG_CONST     = 1550;
    localparam int FRAME_INTERVAL_SHORT_CONST    = 910;
    localparam logic [4:0] MS_LIMITS_DEFAULT_CONST = 5'd16;

    typedef struct packed {
        logic [4:0]  channel;
        logic [14:0] tcc_master;
        logic [14:0] tcc_slave;
        logic [4:0]  t_fine;
        logic        t_badhit;
        logic [14:0] ecc_master;
        logic [14:0] ecc_slave;
        logic [4:0]  e_fine;
        logic        e_badhit;
        logic        e_flag;
    } mutrig_l1_hit_t;

    typedef struct packed {
        logic [4:0]  channel;
        logic        t_badhit;
        logic [14:0] tcc;
        logic [4:0]  t_fine;
        logic        e_badhit;
        logic        e_flag;
        logic [14:0] ecc;
        logic [4:0]  e_fine;
    } mutrig_l2_hit_t;

    function automatic logic select_master_cc(
        input logic [4:0] fine,
        input logic [4:0] limits,
        input logic       overwrite_sel
    );
        logic [4:0] fine_sub;

        fine_sub = fine - limits;
        return ~(fine_sub[4] ^ overwrite_sel);
    endfunction

    function automatic mutrig_l2_hit_t l1_to_l2(
        input mutrig_l1_hit_t l1_hit,
        input logic [4:0]     limits,
        input logic           overwrite_sel
    );
        mutrig_l2_hit_t l2_hit;

        l2_hit.channel  = l1_hit.channel;
        l2_hit.t_badhit = l1_hit.t_badhit;
        l2_hit.tcc      = select_master_cc(l1_hit.t_fine, limits, overwrite_sel) ? l1_hit.tcc_master : l1_hit.tcc_slave;
        l2_hit.t_fine   = l1_hit.t_fine;
        l2_hit.e_badhit = l1_hit.e_badhit;
        l2_hit.e_flag   = l1_hit.e_flag;
        l2_hit.ecc      = select_master_cc(l1_hit.e_fine, limits, overwrite_sel) ? l1_hit.ecc_master : l1_hit.ecc_slave;
        l2_hit.e_fine   = l1_hit.e_fine;
        return l2_hit;
    endfunction

endpackage
