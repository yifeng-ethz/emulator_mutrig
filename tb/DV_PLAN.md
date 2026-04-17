# DV Plan: emulator_mutrig

**DUT family:** `emulator_mutrig`
**Active release:** `26.1.1.0417`
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
- standalone `emulator_mutrig_bank8` synthesis/resource evidence

Not refreshed in this turn:

- gate-level replay
- bucket-frame / all-buckets continuous-frame regressions
- dedicated bank8 functional UVM bench

## 2. Closure Commands

The active release is accepted only if these commands stay green:

1. `make -C tb run_all`
2. `make -C tb/uvm regress SEEDS=1`
3. `make -C tb/uvm clean closure SEEDS=1`
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

## 4. Current Truth After 2026-04-17 Reruns

- directed smoke passes cleanly
- isolated UVM regression passes cleanly
- coverage refresh is present and reviewable
- bank8 standalone compile meets the area target at `3398 ALMs`
- tightened `137.5 MHz` timing is still open by `0.544 ns`

## 5. Signoff Interpretation

For this release:

- functional status is `PASS` for the promoted directed and isolated UVM runs
- coverage status is `PARTIAL`, because only isolated UCDB evidence was refreshed
- standalone synthesis status is `PASS` for area and `PARTIAL` for timing

The master verdict is kept in [../doc/SIGNOFF.md](../doc/SIGNOFF.md).
