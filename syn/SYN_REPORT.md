# SYN Report — emulator_mutrig

**Revision:** `emulator_mutrig_bank8_syn` &nbsp; **Date:** `2026-04-17` &nbsp;
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
| Logic utilization | `3,398 / 91,680 ALMs (4%)` |
| Registers | `2,927` |
| Pins | `1 / 426` |
| Virtual pins | `459` |
| Block memory bits | `94,208 / 13,987,840` |
| RAM blocks | `16 / 1,366` |
| DSP blocks | `16 / 800` |

## Bank Breakdown

Fitter hierarchy summary:

| item | value |
|---|---|
| bank DUT ALMs needed | `3166.2` |
| top-harness overhead | about `232 ALMs` |
| shared `u_tcc_lfsr` ALMs needed | `9.2` |
| shared `u_ecc_lfsr` ALMs needed | `7.5` |

Per-lane fitted range from `emulator_mutrig_lane_shared:lane_gen[*].u_lane`:

| item | measured range |
|---|---|
| lane ALMs needed | `382.9 .. 400.9` |
| lane registers | `359 .. 363` |
| lane memory bits | `11,776` |
| lane RAM blocks | `2` |
| lane DSP blocks | `2` |

Dominant lane-local owners:

| block | ALMs needed |
|---|---|
| `hit_generator` | `215.5 .. 235.0` |
| `frame_assembler` | `147.3 .. 154.5` |

Interpretation:

- the large area consumer is still the per-lane generator/formatter logic
- the requested `256`-hit storage stays in RAM, not ALMs
- shared shell logic is small; the merge did not simply move the area problem

## Timing Summary

Target:

- clock: `clk125`
- signoff period: `7.273 ns`
- signoff frequency: `137.5 MHz`

| status | corner | setup WNS (ns) | hold WNS (ns) | slow-corner Fmax |
|:---:|---|---:|---:|---:|
| PARTIAL | Slow 1100mV 85C | `-0.544` | `+0.261` | `127.93 MHz` |
| PARTIAL | Slow 1100mV 0C | `-0.359` | `+0.243` | `131.03 MHz` |
| PASS | Fast 1100mV 85C | `+2.514` | `+0.162` | n/a |
| PASS | Fast 1100mV 0C | `+3.023` | `+0.149` | n/a |

Key conclusions:

- area target is closed
- hold timing is clean at all corners
- setup timing misses only in the slow corners
- the bank is about `9.57 MHz` short of the tightened `137.5 MHz` target in the
  worst slow corner

The fitter optimization log and the active lane hierarchy show that the hottest
cones remain inside lane-local `hit_generator` and `frame_assembler` logic. The
shared bank shell is not the critical timing owner.

## Flow Runtime

| module | elapsed | CPU time |
|---|---:|---:|
| Analysis & Synthesis | `00:00:23` | `00:00:43` |
| Fitter | `00:01:27` | `00:02:53` |
| Assembler | `00:00:12` | `00:00:11` |
| Timing Analyzer | `00:00:07` | `00:00:12` |
| Total | `00:02:09` | `00:03:59` |

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

Standalone bank8 synthesis is `PASS` for the area objective and `PARTIAL` for
the tightened timing objective.
