# DV Plan: emulator_mutrig

**DUT family:** `emulator_mutrig`
**Active release:** `26.1.7.0418`
**Primary evidence target:** compact single-lane behavior plus standalone bank8 synthesis proof
**Companion reports:** [DV_REPORT.md](DV_REPORT.md), [DV_COV.md](DV_COV.md), [../syn/SYN_REPORT.md](../syn/SYN_REPORT.md)

## 1. Scope

The active DV gate for this refresh is narrower than the earlier exploratory
plan set. The goal is to prove that the compact lane RTL is functionally
equivalent enough for Mu3e datapath use while the standalone bank8 build proves
the requested area target.

In scope:

- single-lane frame formatting and run-control behavior
- CSR-visible defaults and enable semantics
- short and long frame cadence
- burst, noise, mixed, inject, and cross-ASIC slice behavior
- raw-MuTRiG versus emulator collective latency-distribution parity in short and long mode
- raw-MuTRiG versus emulator saturation-curve parity in short and long mode
- supplemental short-mode Poisson true-timestamp latency characterization from `0%` to
  `100%` of the raw `1 hit / 3.5 cycles` offered-load target
- standalone `emulator_mutrig_bank8` synthesis/resource evidence

Not refreshed in this turn:

- gate-level replay
- bucket-frame / all-buckets continuous-frame regressions
- dedicated bank8 functional UVM bench

## 2. Closure Commands

The active release is accepted only if these commands stay green:

1. `make -C tb run_all`
2. `make -C tb/uvm clean closure SEEDS=1`
3. `python3 tb/mutrig_true_ab/sweep_true_ab.py`
4. `quartus_sh --flow compile emulator_mutrig_bank8_syn -c emulator_mutrig_bank8_syn`

## 3. Required Evidence

### 3.1 Directed smoke

The directed bench is the first functional gate. It must continue to prove:

- `910`-cycle short-frame spacing
- `1550`-cycle long-frame spacing
- run-control stop/drain behavior
- CSR readback
- cross-ASIC cluster slicing
- parser-visible framing and CRC behavior

### 3.2 UVM isolated regression

The isolated UVM suite is the main release-quality functional evidence for the
compact lane.

Priority cases for this refresh:

- `emut_test_reset_defaults`
- `emut_test_short_burst_mode`
- `emut_test_disable_and_status`
- the remaining `regress SEEDS=1` matrix

### 3.3 Coverage refresh

The merged UCDB produced by `clean closure SEEDS=1` is the active coverage
artifact for this release. Coverage is reported in [DV_COV.md](DV_COV.md).

### 3.4 Standalone bank8 synthesis

The merged architecture is accepted only if the standalone build keeps:

- `8` lanes in one bank
- one `256 x 48` L2 FIFO per lane in RAM
- total ALMs below `4000`

### 3.5 True raw A/B parity sweep

This is an active signoff gate. The goal is to drive raw MuTRiG RTL and the
emulator with the same hit stream and prove that the collective latency plots,
the accepted/output rate curve, and the decoded channels all match exactly.

Artifacts:

- bench: [mutrig_true_ab/tb_mutrig_true_ab.sv](mutrig_true_ab/tb_mutrig_true_ab.sv)
- driver: [mutrig_true_ab/sweep_true_ab.py](mutrig_true_ab/sweep_true_ab.py)
- report: [mutrig_true_ab/results/TRUE_AB_REPORT.md](mutrig_true_ab/results/TRUE_AB_REPORT.md)

Required outputs:

- exact collective latency histogram parity for short and long mode
- exact parsed payload parity
- exact recovered hit-channel parity
- exact parser output-cycle parity
- matched accepted/output saturation curve from `0%` to `100%` load

### 3.6 Supplemental Poisson delay sweep

This is characterization evidence, not a hard release gate. The goal is to
measure where the compact short-mode lane starts to saturate when driven with a
Poisson source from idle up to the raw `1 hit / 3.5 cycles` reference.

Artifacts:

- bench: [poisson_delay/tb_poisson_delay.sv](poisson_delay/tb_poisson_delay.sv)
- driver: [poisson_delay/sweep_poisson_delay.py](poisson_delay/sweep_poisson_delay.py)
- report: [poisson_delay/results/POISSON_DELAY_REPORT.md](poisson_delay/results/POISSON_DELAY_REPORT.md)

Expected outputs:

- true `E-ts -> frame_start` latency distribution
- true `E-ts -> output` latency distribution
- true `E-ts -> pop` secondary cross-check distribution
- average and peak L2 FIFO occupancy
- `full_cycles` as the saturation indicator
- accepted throughput versus the raw `1 hit / 3.5 cycles` reference

## 4. Current Truth After 2026-04-18 Reruns

- directed smoke passes cleanly at `54 passed, 0 failed`
- isolated UVM regression passes cleanly
- coverage refresh is present and reviewable (`70.74%` filtered merged total)
- raw MuTRiG A/B sweep proves exact short/long collective latency-distribution
  parity with zero payload, channel, cycle, or histogram deltas
- Poisson delay sweep is present and reports the corrected raw-style
  `true E-ts -> frame_start` and `true E-ts -> output` distributions across the
  full requested `0% .. 100%` raw-load range
- bank8 standalone compile meets the area target at `3883 ALMs`
- tightened `137.5 MHz` timing closes with slow `85C` setup slack `+0.026 ns`

## 5. Signoff Interpretation

For this release:

- functional status is `PASS` for the promoted directed and isolated UVM runs
- coverage status is `PARTIAL`, because only isolated UCDB evidence was refreshed
- standalone synthesis status is `PASS` for both area and timing
- continuous-frame and gate-level collateral remain out of the active compact
  refresh scope and are therefore still reported separately as not refreshed

The master verdict is kept in [../doc/SIGNOFF.md](../doc/SIGNOFF.md).
