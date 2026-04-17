# DV Report — emulator_mutrig

**DUT:** `emulator_mutrig` &nbsp; **Date:** `2026-04-17` &nbsp;
**Release under check:** `26.1.1.0417`

This is the active DV dashboard for the compact MuTRiG refresh.

## Health

| status | field | value |
|:---:|---|---|
| PASS | directed_smoke | `49 passed, 0 failed` |
| PASS | isolated_uvm | `15 / 15 passed` |
| PASS | targeted_fix_reruns | `3 / 3 passed` |
| PASS | merged_ucdb_refresh | `tb/uvm/cov/merged.ucdb` present |
| PARTIAL | continuous_frame | not rerun in this refresh |
| PARTIAL | gate_level | not rerun in this refresh |

## Executed Evidence

| status | command | result |
|:---:|---|---|
| PASS | `make -C tb run_all` | `49 passed, 0 failed` |
| PASS | `make -C tb/uvm regress SEEDS=1` | `15 / 15 passed` |
| PASS | `make -C tb/uvm clean closure SEEDS=1` | refreshed merged UCDB and text report |
| PASS | `make -C tb/uvm run TEST=emut_test_reset_defaults SEED=1` | stale reset-default expectation fixed |
| PASS | `make -C tb/uvm run TEST=emut_test_short_burst_mode SEED=1` | startup frame alignment fix verified |
| PASS | `make -C tb/uvm run TEST=emut_test_disable_and_status SEED=1` | enable-gated frame start verified |

## Release Fixes Verified

| status | area | summary |
|:---:|---|---|
| PASS | RTL | first frame after run start now waits a full interval, preventing startup burst splitting |
| PASS | RTL | fresh frame starts are gated by `csr_enable` / `cfg_enable`, so disabled lanes stay idle |
| PASS | Harness | UVM CSR2 reset-default expectation now matches live cluster defaults |
| PASS | Directed | `T09_terminate_no_new_frame` stays green with the new frame-start gating |
| PASS | Directed | `T10_cross_asic_cluster_slice` stays green after the generator compaction |

## Coverage Snapshot

Active summary from [DV_COV.md](DV_COV.md):

| instance | branch | statement | toggle |
|---|---:|---:|---:|
| `/tb_top/dut` | `100.00%` | `100.00%` | `78.34%` |
| `/tb_top/dut/u_hit_gen` | `71.08%` | `85.09%` | `85.98%` |
| `/tb_top/dut/u_frame_asm` | `93.05%` | `96.03%` | `86.27%` |

## Verdict

DV status for the compact refresh is `PASS` for the promoted directed and
isolated UVM runs, with a `PARTIAL` overall coverage/signoff label because the
continuous-frame and gate-level collateral were not refreshed in this turn.
