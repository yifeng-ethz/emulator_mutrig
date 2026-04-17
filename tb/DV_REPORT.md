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
| PASS | poisson_delay_sweep | short-mode queueing knee measured; no saturation through `80%`, FIFO full events start around `90%` |
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
| PASS | `python3 tb/poisson_delay/sweep_poisson_delay.py` | wrote compact sweep summary and markdown report |

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

## Supplemental Poisson Delay Sweep

Artifacts:

- report: [poisson_delay/results/POISSON_DELAY_REPORT.md](poisson_delay/results/POISSON_DELAY_REPORT.md)
- summary CSV: [poisson_delay/results/poisson_delay_summary.csv](poisson_delay/results/poisson_delay_summary.csv)

Configuration:

- single-lane `emulator_mutrig`
- short mode, Poisson only, `burst_size=1`, `noise=0`
- raw offered-load reference: `0.285714 hits/cycle = 1 hit / 3.5 cycles`
- warmup window: `50000` cycles
- measured window: `200000` cycles

Key findings:

- through `80%` raw offered load, the lane stays below FIFO-full and accepted
  throughput tracks the target rate
- at `90%` raw offered load, the `256`-hit FIFO starts to hit full
  (`557` full cycles) and accepted throughput begins to flatten
- at `100%` raw offered load, accepted throughput is about `0.2589 hits/cycle`,
  equivalent to about `3.86 cycles / accepted hit`
- the practical short-mode service limit is therefore below the raw
  `1 hit / 3.5 cycles` reference once framing overhead is included
- the apparent latency collapse at `90%+` load is selection bias on accepted
  hits after the FIFO is already close to full, not a genuine service-speed
  improvement

Representative points:

| raw full % | accepted hits/cycle | avg occ | max occ | full cycles | parser p50/p90/p99/max |
|---:|---:|---:|---:|---:|---|
| 60 | `0.1714` | `125.5` | `194` | `0` | `742 / 886 / 919 / 929` |
| 80 | `0.2286` | `187.8` | `239` | `0` | `834 / 906 / 926 / 941` |
| 90 | `0.2553` | `222.1` | `256` | `557` | `209 / 580 / 723 / 763` |
| 100 | `0.2589` | `246.1` | `256` | `7561` | `27 / 78 / 117 / 166` |

## Verdict

DV status for the compact refresh is `PASS` for the promoted directed and
isolated UVM runs, and the supplemental Poisson sweep gives a clear saturation
knee for short-mode queueing. The overall coverage/signoff label remains
`PARTIAL` because the continuous-frame and gate-level collateral were not
refreshed in this turn.
