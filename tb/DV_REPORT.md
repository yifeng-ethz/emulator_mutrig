# DV Report — emulator_mutrig

**DUT:** `emulator_mutrig` &nbsp; **Date:** `2026-04-18` &nbsp;
**Release under check:** `26.1.5.0418`

This is the active DV dashboard for the compact MuTRiG refresh.

## Health

| status | field | value |
|:---:|---|---|
| PASS | directed_smoke | `54 passed, 0 failed` |
| PASS | isolated_uvm | `15 / 15 passed` |
| PASS | compact_contract_checks | `asic_id 0..7`, hit channel `0..31`, raw `E_Flag`, and `T <= E` checks are green in the directed bench |
| PASS | merged_ucdb_refresh | `tb/uvm/cov/merged.ucdb` present |
| PASS | poisson_delay_sweep | true `E-ts -> pop` latency measured from `0%` to `100%` of the raw full-link reference |
| PARTIAL | continuous_frame | not rerun in this refresh |
| PARTIAL | gate_level | not rerun in this refresh |

## Executed Evidence

| status | command | result |
|:---:|---|---|
| PASS | `make -C tb run_all` | `54 passed, 0 failed` |
| PASS | `make -C tb/uvm clean closure SEEDS=1` | refreshed merged UCDB and text report |
| PASS | `python3 tb/poisson_delay/sweep_poisson_delay.py` | wrote compact sweep summary and markdown report |

## Release Fixes Verified

| status | area | summary |
|:---:|---|---|
| PASS | RTL | first frame after run start now waits a full interval, preventing startup burst splitting |
| PASS | RTL | fresh frame starts are gated by `csr_enable` / `cfg_enable`, so disabled lanes stay idle |
| PASS | RTL | public `asic_id` tag is clamped to `0..7` while hit-local channel IDs stay in `0..31` |
| PASS | RTL | default long-hit timing keeps `T <= E`, commits on `E`, and keeps raw-compatible `E_Flag = 1` |
| PASS | RTL | Poisson fine counters are random; cluster fine counters stay on an about `1 ns` spread around the anchor |
| PASS | Harness | UVM CSR2 reset-default expectation now matches the live cluster defaults |

## Coverage Snapshot

Active summary from [DV_COV.md](DV_COV.md):

| instance | branch | statement | toggle |
|---|---:|---:|---:|
| `/tb_top/dut` | `100.00%` | `100.00%` | `77.92%` |
| `/tb_top/dut/u_hit_gen` | `77.35%` | `89.45%` | `88.64%` |
| `/tb_top/dut/u_frame_asm` | `93.05%` | `96.03%` | `86.27%` |

## Supplemental Poisson Timestamp Sweep

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

- the primary latency metric is true `E-ts -> pop`, because the default
  long-hit mode commits on the encoded `E` timestamp
- at `10%` raw full rate, the observed true latency spans almost one full short
  frame with a `~32` cycle floor from frame header overhead:
  `32 / 512.5 / 846.9 / 911.0 / 944.0` cycles for min / p50 / p90 / p99 / max
- occasional FIFO-full cycles first appear at `60%` raw full rate, but the lane
  still tracks the offered rate closely through the mid-load points
- at `100%` raw full rate, accepted throughput is `0.2698 hits/cycle`, about
  `3.71 cycles / accepted hit`
- at `100%` raw full rate, true `E-ts -> pop` latency stays mostly in the
  `0.8 .. 1.15` frame range:
  `793.0 / 895.0 / 936.0 / 982.0 / 1045.0` cycles for p01 / p50 / p90 / p99 / max
- the measured high-load distribution does not fill a full `0 .. 1820` cycle
  box at `<=100%` raw full rate because the short-mode packer keeps draining
  continuously inside an already-open frame

Representative points:

| raw full % | accepted hits/cycle | avg occ | max occ | full cycles | true `E-ts -> pop` p50/p90/p99/max |
|---:|---:|---:|---:|---:|---|
| 10 | `0.0310` | `16.0` | `138` | `0` | `512.5 / 846.9 / 911.0 / 944.0` |
| 60 | `0.1744` | `129.5` | `256` | `270` | `752.0 / 894.0 / 967.0 / 1057.0` |
| 100 | `0.2698` | `240.3` | `256` | `10703` | `895.0 / 936.0 / 982.0 / 1045.0` |

## Verdict

DV status for the compact refresh is `PASS` for the promoted directed and
isolated UVM runs, and the supplemental Poisson sweep now measures the requested
true timestamp semantics directly. The extended continuous-frame and gate-level
collateral were not refreshed in this turn and remain separate from the active
compact-bank release scope.
