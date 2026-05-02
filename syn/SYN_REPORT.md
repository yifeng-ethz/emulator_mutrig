# ⚠️ SYN Report — emulator_mutrig central trigger refresh

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
- prove the front-end / back-end split fits the 4000 ALM standalone budget
  on Arria V at the 125 MHz nominal clock
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
| Logic utilization (ALMs) | `4,557 / 91,680 (5%)` | `< 4000` | ⚠️ over target by 14% |
| Total registers | `6,597` | informational | ℹ️ |
| Total block memory bits | `83,968` | informational | ℹ️ |
| Total RAM Blocks (M10K) | `16 / 1,366` | `16` | ✅ |
| Total DSP Blocks | `0 / 800` | `0` | ✅ |
| Total PLLs | `0 / 21` | `0` | ✅ |
| Compile errors | `0` | `0` | ✅ |
| Compile warnings | `146` | informational | ℹ️ |

### Timing — Slow 1100mV 85C corner, `clk125` @ 125 MHz

| field | value | target | status |
|---|---|---|---|
| Setup slack | `-2.573 ns` | `>= +0.000 ns` | ❌ fails timing |
| TNS (setup, 85C) | `-908.311 ns` | informational | ❌ |
| Effective Fmax | `~94.5 MHz` (1 / (8 + 2.573)) | `>= 125 MHz` | ❌ |
| Setup slack (Slow 0C) | `-2.453 ns` | informational | ❌ |

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
| ❌ | ALM target 4000 | over by 557 ALMs (14%) |
| ❌ | Timing 125 MHz Slow 85C | `-2.573 ns` setup slack |
| ✅ | M10K target 16 | exact match |
| ✅ | DSP target 0 | exact match |
| ✅ | Static gate (lint+CDC+RDC) | passes per `tb/formal/work_lcdr/` log |
| ⚠️ | Static gate (formal) | passes elaboration; bind harness needs UVM TB invocation to fire properties |

## Open Issues

1. **ALM over target by 14%.** Likely culprits are the per-lane 64-bit
   saturating counters, the wider RR engine dispatch, and the now-functional
   ERROR_INJECT path. Mitigation list per
   [`../doc/RTL_PLAN_central_trigger.md`](../doc/RTL_PLAN_central_trigger.md)
   §4.2: shrink lane ticket FIFO depth from 8 to 4 (`-320 ALM`), share the
   per-lane 64-bit counters via an MLAB-backed register file (`-120 ALM`).
2. **Timing fails by 2.573 ns at 125 MHz.** Worst path likely lives in the
   `frontend_trigger_engine` cluster geometry decode that combines
   `clamp_start_128`, mirror clamp, and the RR dispatch in one cycle. Fix
   options: pipeline the cluster footprint compute over 2 cycles before
   pushing into `pending_mask`, or split the per-lane shred into a
   second pipeline stage. RTL work; lands in the next patch.
3. **Compatibility build (`BYTE_STREAM_ENABLE=1`) not compiled in this
   checkpoint.** Add a second Quartus revision and rerun.
4. **Reduced lane-count points not compiled.** Informational only; defer
   to a follow-up.

## Next Steps

1. Tackle the timing failure first (RTL pipelining in trigger_engine).
2. After timing closes, recompile both axis points to confirm ALM and
   timing match the refreshed estimate.
3. Then the standalone synthesis gate is signoff-ready and the
   integration tb_int can move from skeleton to first directed run.
