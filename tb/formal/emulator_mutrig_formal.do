## emulator_mutrig_formal.do
## Questa formal/qverify constraints for the central-trigger refresh.
## Author: Yifeng Wang
## Version : 26.2.0
## Date    : 20260502
##
## Sourced via questa_static_screen.py --extra-do.
## Sets the formal clock and reset, defines the clock period, and turns on
## the FORMAL_EMULATOR_MUTRIG defines so the bind blocks elaborate.

## Compile-time defines for the SVA harness.
set ::env(VLOG_DEFINES) "+define+FORMAL_EMULATOR_MUTRIG"

## Formal clock domain — single clock at 125 MHz nominal.
formal compile -d emulator_mutrig

formal define clock i_clk -period 8ns
formal define reset i_rst -active_high

## Limit run time per the medium reasoning effort budget.
formal verify -timeout 30m
