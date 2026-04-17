# Emulator MuTRiG — RTL Plan

**IP family:** `emulator_mutrig`
**Active release:** `26.1.1.0417`
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
| top-level ALMs | `3398` |
| bank DUT ALMs needed | `3166.2` |
| registers | `2927` |
| block memory bits | `94,208` |
| RAM blocks | `16` |
| DSP blocks | `16` |

### 3.2 Measured per-lane shape

From `emulator_mutrig_lane_shared:lane_gen[*].u_lane` in the fitter report:

| item | measured range |
|---|---|
| lane ALMs needed | `382.9 .. 400.9` |
| lane registers | `359 .. 363` |
| lane block memory bits | `11,776` |
| lane RAM blocks | `2` |
| lane DSP blocks | `2` |

Dominant lane owners:

| block | measured ALMs needed |
|---|---|
| `hit_generator` | `215.5 .. 235.0` |
| `frame_assembler` | `147.3 .. 154.5` |
| shared PRBS-15 counter (`tcc`) | `9.2` |
| shared PRBS-15 counter (`ecc`) | `7.5` |

Interpretation:

- the compact FIFO move succeeded: storage is RAM-backed, not ALM-backed
- the remaining logic cost is overwhelmingly lane-local
- shared shell overhead is small relative to the eight lane cores

## 4. Timing Model

Standalone signoff uses the tightened `137.5 MHz` clock (`7.273 ns`), matching
the `1.1 x 125 MHz` policy used elsewhere in this repo.

Current result:

- area goal: `PASS`
- tightened timing: `PARTIAL`
- worst slow-corner setup slack: `-0.544 ns`
- slow-corner Fmax: `127.93 MHz`

The fitter and TimeQuest evidence show the pressure remains inside the
lane-local `hit_generator` and `frame_assembler` cones. The shared bank shell is
not the timing limiter.

## 5. Functional Notes For This Release

The compact bank keeps the prior external lane behavior, plus three verified
release fixes:

1. run start now waits one full frame interval before opening the first frame
2. disabled lanes no longer open fresh frames
3. UVM reset-default checks now match the live cluster defaults

## 6. Open Items

- close the remaining `137.5 MHz` setup miss on the bank8 build
- decide whether a tighter lane-local timing pass is worth the extra effort, or
  whether the current `3398 ALM` result is sufficient for system integration
- refresh gate-level and continuous-frame evidence if those modes become part of
  the active signoff gate
