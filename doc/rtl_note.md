# RTL Note — emulator_mutrig

Date: `2026-04-17`
Release: `26.1.1.0417`

## Summary

This refresh moves the emulator family to a compact per-lane architecture and
adds a standalone shared bank for the `8 lane / <4000 ALM` study.

## Main RTL Changes

1. `hit_generator.sv`
   - removed the live `4 x L1 + shared L2` staging fabric
   - kept one `256 x 48` L2 FIFO per lane in M10Ks
2. `emulator_mutrig_bank8.sv`
   - added a standalone merged bank with shared run-control, inject sync, and
     shared PRBS-15 coarse counters
3. `frame_assembler.sv`
   - run start now waits a full frame interval before opening the first frame
4. `emulator_mutrig.sv` and `emulator_mutrig_lane_shared.sv`
   - fresh frame starts are now gated by enable, while drain behavior remains
     valid for an already-open frame

## Result

- functional reruns are green for the compact lane
- standalone bank8 area target passes at `3398 ALMs`
- tightened `137.5 MHz` timing remains open by `0.544 ns`

## Active Review Pages

- [../tb/DV_REPORT.md](../tb/DV_REPORT.md)
- [../tb/DV_COV.md](../tb/DV_COV.md)
- [../syn/SYN_REPORT.md](../syn/SYN_REPORT.md)
- [SIGNOFF.md](SIGNOFF.md)
