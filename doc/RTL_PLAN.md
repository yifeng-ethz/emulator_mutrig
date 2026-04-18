# Emulator MuTRiG — RTL Plan

**IP family:** `emulator_mutrig`
**Active release:** `26.1.7.0418`
**Area-signoff vehicle:** `rtl/emulator_mutrig_bank8.sv`
**Companion reports:** [../tb/DV_PLAN.md](../tb/DV_PLAN.md), [../tb/DV_REPORT.md](../tb/DV_REPORT.md), [../syn/SYN_REPORT.md](../syn/SYN_REPORT.md), [SIGNOFF.md](SIGNOFF.md)

## 1. Scope

This refresh is driven by one requirement: fit `8` MuTRiG emulator lanes below
`4000 ALMs total` while keeping one `256`-hit L2 FIFO per lane in dedicated RAM.

The delivered architecture keeps two user-facing shapes:

- `rtl/emulator_mutrig.sv`: single-lane compatibility IP for Platform Designer
- `rtl/emulator_mutrig_bank8.sv`: standalone merged bank used for resource and
  timing study

## 2. Delivered Architecture

### 2.1 Lane-local datapath

Every lane now uses the same compact core:

- `hit_generator` writes directly into one `FIFO_DEPTH x 48` L2 FIFO
- `frame_assembler` drains that FIFO into the MuTRiG 8b/1k byte stream
- no group-local L1 staging queues remain in the live generator RTL

The FIFO stays lane-local on purpose so each MuTRiG retains the requested
`256`-hit backlog without spending ALMs.

### 2.2 Shared 8-lane shell

`emulator_mutrig_bank8` shares only the logic that is naturally global:

- run-control decode and `RUNNING` / `TERMINATING` ownership
- inject pulse fanout
- common CSR-style configuration broadcast
- shared `tcc` / `ecc` PRBS-15 coarse counters

This keeps the sharing boundary simple and audit-friendly. The bank does not
cross-couple lane FIFOs or lane frame assemblers.

## 3. Resource Model

The fitted bank8 result from [`../syn/SYN_REPORT.md`](../syn/SYN_REPORT.md)
defines the current reference model.

### 3.1 Measured bank8 totals

| item | value |
|---|---|
| top-level ALMs | `3883` |
| registers | `3545` |
| block memory bits | `98,304` |
| RAM blocks | `16` |
| DSP blocks | `0` |

### 3.2 Measured per-lane shape

The final bank8 build removes the earlier DSP-backed fine-time update path. The
remaining area is dominated by lane-local `hit_generator` and
`frame_assembler` logic plus the eight `256 x 48` M10K-backed FIFOs.

Interpretation:

- the compact FIFO move succeeded: storage is RAM-backed, not ALM-backed
- the remaining logic cost is overwhelmingly lane-local
- the PRNG rewrite eliminated all DSP usage while keeping the bank under the
  `4000 ALM` cap

## 4. Timing Model

Standalone signoff uses the tightened `137.5 MHz` clock (`7.273 ns`), matching
the `1.1 x 125 MHz` policy used elsewhere in this repo.

Current result:

- area goal: `PASS`
- tightened timing: `PASS`
- worst slow-corner setup slack: `+0.026 ns`
- worst slow-corner hold slack: `+0.260 ns`

The fitter and TimeQuest evidence show the pressure remains inside the
lane-local `hit_generator` and `frame_assembler` cones. The shared bank shell
and the shared PRBS coarse counters are not the timing limiter.

## 5. Functional Notes For This Release

The compact bank keeps the prior external lane behavior, plus three verified
release fixes:

1. run start now waits one full frame interval before opening the first frame
2. disabled lanes no longer open fresh frames
3. `asic_id` is clamped to `0..7` while hit-local channel tags stay in `0..31`
4. default long-hit timing keeps `T <= E`, uses the encoded `E` time as the
   true commit timestamp, keeps raw-compatible `E_Flag = 1`, and uses random
   Poisson fine time versus about `1 ns` cluster fine spread
5. the raw MuTRiG A/B harness now proves exact short/long collective latency
   distribution parity, channel parity, and saturation-curve parity
6. the supplemental Poisson study now checks the corrected raw-style
   `frame_start` snapshot latency plus parser-visible output tail
7. UVM reset-default checks now match the live cluster defaults

## 6. Open Items

- refresh gate-level and continuous-frame evidence if those modes become part of
  the active signoff gate
