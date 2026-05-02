## emulator_mutrig_formal.do
## Questa formal/qverify constraints for the central-trigger refresh.
## Author: Yifeng Wang
## Version : 26.2.0
## Date    : 20260502
##
## Sourced via questa_static_screen.py --extra-do.
## Sets the formal clock and reset, defines the clock period, and turns on
## the FORMAL_EMULATOR_MUTRIG defines so the bind blocks elaborate.

## Compile-time defines for the SVA harness; questa_static_screen.py
## propagates VLOG_DEFINES into the vlog invocation.
set ::env(VLOG_DEFINES) "+define+FORMAL_EMULATOR_MUTRIG"

## Clock and reset are auto-discovered by qverify formal from the design's
## single i_clk / i_rst. No explicit clock/reset binding needed.
## Formal proof budget is left at the script default; the SVA harness
## binds in lightweight properties so each check completes quickly.
