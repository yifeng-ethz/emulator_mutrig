// frontend_ticket_distributor.sv
// Ticket bus contract surface for emulator_mutrig frontend dispatch.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260502
// Change  : Add wire-only frontend ticket distributor.

module frontend_ticket_distributor
    import frontend_ticket_bus_pkg::*;
#(
    parameter int LANE_COUNT = 8
) (
    input  logic                              i_clk,
    input  logic                              i_rst,

    input  frontend_ticket_t                  fe_ticket_data_in  [LANE_COUNT],
    input  logic                              fe_ticket_valid_in [LANE_COUNT],
    input  logic                              fe_ticket_ready_in [LANE_COUNT],

    output frontend_ticket_t                  fe_ticket_data_out [LANE_COUNT],
    output logic                              fe_ticket_valid_out[LANE_COUNT],
    output logic                              fe_ticket_ready_out[LANE_COUNT]
);

    logic unused_clk;
    logic unused_rst;

    assign unused_clk          = i_clk;
    assign unused_rst          = i_rst;
    assign fe_ticket_data_out  = fe_ticket_data_in;
    assign fe_ticket_valid_out = fe_ticket_valid_in;
    assign fe_ticket_ready_out = fe_ticket_ready_in;

endmodule
