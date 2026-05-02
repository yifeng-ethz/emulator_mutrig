# SYN Report — emulator_mutrig central trigger refresh

**Measured revision:** `emulator_mutrig_syn` &nbsp;
**Date:** `2026-05-02` &nbsp; **Device:** `5AGXBA7D4F31C5` (Arria V) &nbsp;
**Quartus:** `18.1.0 Build 625 SJ Standard Edition`

This is the standalone synthesis dashboard for the `emulator_mutrig` 26.2.x
central-trigger refresh. The legacy bank8 dashboard is preserved at
`SYN_REPORT_legacy_bank8.md`. The patch-specific RTL plan is at
[`../doc/RTL_PLAN_central_trigger.md`](../doc/RTL_PLAN_central_trigger.md).

The measured numbers below reflect the active 26.2.x build at
`LANE_COUNT=8, BYTE_STREAM_ENABLE=0` (primary axis point) on the
Arria V board target.

## Build Intent

- replace the legacy `emulator_mutrig_bank8` standalone signoff with the new
  central-trigger top
- prove the front-end / back-end split fits the standalone area
  ceiling of `5460 ALM` (= `3640` plan-§4.1 nominal estimate × `1.5`)
  and meets timing at the **`137.5 MHz` standalone signoff clock**
  (`= 1.1 × 125 MHz`, period `7.273 ns`) at the slow-85C corner
- report both feature axis points: `BYTE_STREAM_ENABLE in {0, 1}` and
  `LANE_COUNT in {1, 2, 4, 8}` (8 is gated; 1/2/4 are informational)
- catch the parser regression that Quartus 18.1 Standard introduced for
  module-port import statements (fixed by moving imports into the body)

## Pre-Fit Model

- expected storage owners:
  - 8 × 256-deep × 48-bit M10K L2 FIFOs (one per lane)
  - per-lane 8-deep × 40-bit MLAB ticket FIFOs (LUTRAM, off the M10K budget)
  - per-lane 64-bit frame_count and hit_count saturating counters in flops
- expected critical regions:
  - `frontend_trigger_engine` round-robin lane dispatch + cluster geometry
    compute in one cycle (FIX low/high decode + RANDOM mirror_offset clamp +
    per-lane channel-range shred)
  - `frontend_csr` per-lane 64-bit counter readback mux at 6-bit address
- expected ALM range: 3210..3970 per `RTL_PLAN_central_trigger.md` §4

## Measured Standalone Points

### Primary build: `LANE_COUNT=8, BYTE_STREAM_ENABLE=0`

| field | value | target | status |
|---|---|---|---|
| Logic utilization (ALMs) | `4,274 / 91,680 (5%)` | `< 5460` (1.5 × plan-§4.1 nominal) | ✅ within ceiling, 22% headroom |
| Total registers | `6,745` | informational | ℹ️ |
| Total block memory bits | `83,968` | informational | ℹ️ |
| Total RAM Blocks (M10K) | `16 / 1,366` | `16` | ✅ |
| Total DSP Blocks | `0 / 800` | `0` | ✅ |
| Total PLLs | `0 / 21` | `0` | ✅ |
| Compile errors | `0` | `0` | ✅ |
| Compile warnings | `144` | informational | ℹ️ |

### Timing — signoff `clk125` at `137.5 MHz` (= 1.1 × 125 MHz, period 7.273 ns)

Post-pipelining measurement:
trigger engine cluster decode + per-lane shred split into staged launch,
geom, shred, and registered dispatch outputs.

| field | value | target | status |
|---|---|---|---|
| Setup slack — Slow 1100mV 85C | `+0.297 ns` | `>= 0 ns` | ✅ pass |
| Setup slack — Slow 1100mV 0C | `+0.377 ns` | `>= 0 ns` | ✅ pass |
| TNS — Slow 85C | `0.000 ns` | `0.000 ns` | ✅ |
| Hold slack — Slow 85C | `+0.253 ns` | `>= 0 ns` | ✅ pass |
| Hold slack — Slow 0C | `+0.234 ns` | `>= 0 ns` | ✅ pass |
| Restricted Fmax — Slow 0C | `145.0 MHz` | `>= 137.5 MHz` | ✅ pass |
| Restricted Fmax — Slow 85C | `~143.4 MHz` (`1 / (7.273 - 0.297)`) | `>= 137.5 MHz` | ✅ pass |
| Min pulse width — Slow 85C | `+2.626 ns` | `>= 0 ns` | ✅ |

**Closure trajectory:**

| build | Slow 85C setup slack | ALMs | notes |
|---|---|---|---|
| pre-pipeline (`9e22e27`) | `-2.573 ns` | `4,557` | original 1-stage trigger engine at 125 MHz baseline |
| post-pipeline (`81a6a59`) | `+0.297 ns` | `4,274` | launch capture, geometry clamp, shred, registered dispatch |

The tightened `137.5 MHz` (1.1× nominal) signoff clock is the
standalone gate per the `timing-performance-resources-sign-off` skill.
The Slow 85C and Slow 0C setup and hold corners now pass with zero TNS.
The compile used `create_clock -name clk125 -period 7.273` in
`syn/quartus/emulator_mutrig_syn.sdc`.

The post-fit worst setup path is now a closed geometry-clamp slice from
`geom_stage_size_random[6]` to `launch_stage_cluster0_high[2]`, slack
`+0.297 ns`.

### Compatibility build: `LANE_COUNT=8, BYTE_STREAM_ENABLE=1`

`pending` — the second build axis point has not been recompiled in the
post-fix tree. Expected delta vs primary: `+~1200 ALM` from the 8 frame
assemblers; same 16 M10K; timing likely slightly worse.

### Reduced lane counts

`pending` — `LANE_COUNT in {1, 2, 4}` builds are informational and have
not been compiled for this checkpoint.

## Closure Status

| gate | status | detail |
|:---:|---|---|
| ✅ | Compile errors | `0` errors after the 26.2.x import-position fix |
| ✅ | ALM ceiling 5460 | `4,274` ALMs, 22% headroom |
| ✅ | Timing 137.5 MHz Slow 85C | `+0.297 ns` setup slack |
| ✅ | M10K target 16 | exact match |
| ✅ | DSP target 0 | exact match |
| ✅ | Static gate (lint+CDC+RDC) | PASS via `questa_static_screen.py --modes lint,cdc,rdc` |
| ⚠️ | Static gate (formal) | passes elaboration; bind harness needs UVM TB invocation to fire properties |

## Open Issues

1. **Compatibility build (`BYTE_STREAM_ENABLE=1`) not compiled in this
   checkpoint.** Add a second Quartus revision and rerun. Expected delta
   vs primary: `+~1200 ALM` from the 8 frame assemblers (still well
   under the 5460 ceiling); same 16 M10K; timing likely slightly worse
   but should still close given the 0.297 ns headroom on the primary.
2. **Reduced lane-count points not compiled.** Informational only; defer
   to a follow-up.
3. **TB regression evidence is limited.** The legacy `tb/Makefile`
   `compile` and `run_all` targets still reference the pre-refresh
   single-lane port shape and need a TB rewrite to drive the new
   8-lane top. For this checkpoint the available regression is the
   `central_smoke` target which elaborates the full new RTL tree under
   Questa with `0` errors; the static gate (`lint+CDC+RDC`) passes
   clean; the synthesis fitter completes with the numbers above. The
   UVM testbench wiring is the next codex2 deliverable per the closure
   plan.

## Next Steps

1. Recompile the compatibility axis point with `BYTE_STREAM_ENABLE=1`.
2. Recompile reduced lane-count points if informational area scaling is needed.
3. Move the integration tb_int from skeleton to first directed run.
