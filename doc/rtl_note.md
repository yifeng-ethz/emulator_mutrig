# RTL Note — emulator_mutrig

Date: `2026-04-18`
Release: `26.1.9.0418`

## Summary

This refresh moves the emulator family to a compact per-lane architecture and
adds a standalone shared bank for the `8 lane / <4000 ALM` study while closing
the tightened `137.5 MHz` standalone timing target.

## Main RTL Changes

1. `hit_generator.sv`
   - removed the live `4 x L1 + shared L2` staging fabric
   - kept one `256 x 48` L2 FIFO per lane in M10Ks
   - changed Poisson fine timing to lightweight LFSR-driven random samples
   - kept cluster fine timing on an about `1 ns` spread around the anchor
   - default long-hit timing now commits on `E` with `T <= E`
2. `emulator_mutrig_bank8.sv`
   - added a standalone merged bank with shared run-control, inject sync, and
     shared PRBS-15 coarse counters
3. `emulator_mutrig.sv`
   - public `asic_id` is clamped to `0..7` to match the banked MuTRiG lane map
4. `frame_assembler.sv`
   - run start now waits a full frame interval before opening the first frame
5. `emulator_mutrig_lane_shared.sv`
   - fresh frame starts are now gated by enable, while drain behavior remains
     valid for an already-open frame

## Result

- functional reruns are green for the compact lane
- standalone bank8 area target passes at `3856 ALMs`
- tightened `137.5 MHz` timing now passes with slow `85C` setup slack `+1.224 ns`
- the final bank8 compile uses `16` RAM blocks and `0` DSP blocks
- the raw MuTRiG A/B sweep now shows exact short/long collective latency
  histogram parity with zero payload, channel, or cycle mismatches
- the Poisson timestamp study now reports corrected raw-style
  `true E-ts -> frame_start` and `true E-ts -> output` latency directly

## Active Review Pages

- [../tb/DV_REPORT.md](../tb/DV_REPORT.md)
- [../tb/DV_COV.md](../tb/DV_COV.md)
- [../syn/SYN_REPORT.md](../syn/SYN_REPORT.md)
- [SIGNOFF.md](SIGNOFF.md)
