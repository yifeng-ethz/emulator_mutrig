# SYN Report — emulator_mutrig

**Revision:** `emulator_mutrig_bank8_syn` &nbsp; **Date:** `2026-04-18` &nbsp;
**Device:** `5AGXBA7D4F31C5` &nbsp; **Quartus:** `18.1.0 Build 625`

This is the detailed standalone synthesis report for the compact `8`-lane MuTRiG
emulator bank. The master signoff page is [../doc/SIGNOFF.md](../doc/SIGNOFF.md).

## Build Intent

- compile the merged `emulator_mutrig_bank8` architecture as the standalone area
  proof vehicle
- keep one `256 x 48` L2 FIFO per lane in dedicated RAM
- share only run-control, inject sync, configuration broadcast, and coarse PRBS
  counters
- target `<4000 ALMs total` for `8` lanes
- use the tightened standalone signoff clock of `137.5 MHz` (`7.273 ns`)

## Resource Summary

| item | value |
|---|---|
| Logic utilization | `3,856 / 91,680 ALMs (4%)` |
| Registers | `3,777` |
| Pins | `1 / 426` |
| Virtual pins | `492` |
| Block memory bits | `98,304 / 13,987,840` |
| RAM blocks | `16 / 1,366` |
| DSP blocks | `0 / 800` |

## Interpretation

- the large area consumer is still the per-lane generator and formatter logic
- the requested `256`-hit storage stays in RAM, not ALMs
- the final LFSR-based fine-time generator removes all DSP usage from the bank
- the bank closes the requested `<4000 ALM / 8 lanes` target with `144 ALMs`
  of margin

## Timing Summary

Target:

- clock: `clk125`
- signoff period: `7.273 ns`
- signoff frequency: `137.5 MHz`

| status | corner | setup WNS (ns) | hold WNS (ns) | slow-corner Fmax |
|:---:|---|---:|---:|---:|
| PASS | Slow 1100mV 85C | `+1.224` | `+0.254` | n/a |
| PASS | Slow 1100mV 0C | `+1.469` | `+0.237` | n/a |
| PASS | Fast 1100mV 85C | `+3.522` | `+0.156` | n/a |
| PASS | Fast 1100mV 0C | `+3.890` | `+0.142` | n/a |

Key conclusions:

- area target is closed
- hold timing is clean at all corners
- setup timing also closes at all corners under the tightened `137.5 MHz`
  standalone constraint
- the remaining critical pressure is lane-local and not in the shared bank shell

The fitter optimization log and the active timing reports show that the hottest
cones remain inside lane-local `hit_generator` and `frame_assembler` logic. The
shared bank shell and shared PRBS counters are not the critical timing owners.

## Flow Runtime

| module | elapsed | CPU time |
|---|---:|---:|
| Analysis & Synthesis | `00:00:21` | `00:00:42` |
| Fitter | `00:01:34` | `00:03:04` |
| Assembler | `00:00:11` | `00:00:12` |
| Timing Analyzer | `00:00:08` | `00:00:13` |
| Total | `00:02:14` | `00:04:11` |

## Constraint Caveat

TimeQuest reports the standalone harness as not fully constrained:

| item | value |
|---|---|
| unconstrained input ports | `91` |
| unconstrained input-port paths | `19,896` |
| unconstrained output ports | `272` |
| unconstrained output-port paths | `488` |

This is a harness-level caveat. The internal `clk125` register domain is the
relevant signoff domain for the bank study.

## Result

Standalone bank8 synthesis is `PASS` for both the area objective and the
tightened timing objective.
