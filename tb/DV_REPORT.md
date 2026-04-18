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
| PASS | poisson_delay_sweep | corrected frame-marker latency study measured true `E-ts -> frame_start` and `E-ts -> output` from `0%` to `100%` of the raw full-link reference |
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

- the corrected raw-style observables are `true E-ts -> frame_start` and
  `true E-ts -> output`
- at `10%` raw full rate, `true E-ts -> frame_start` is the expected one-frame
  box: `2.0 / 444.0 / 816.0 / 902.0 / 911.0` cycles for min / p50 / p90 / p99 / max
- at `10%` raw full rate, `true E-ts -> output` adds only the fixed short-mode
  packer overhead: `40.0 / 520.0 / 854.0 / 918.0 / 951.0`
- occasional FIFO-full cycles first appear at `60%` raw full rate, but the lane
  still tracks the offered rate closely through the mid-load points
- at `100%` raw full rate, accepted throughput is `0.2698 hits/cycle`, about
  `3.71 cycles / accepted hit`
- at `100%` raw full rate, `true E-ts -> output` stays bounded near one frame
  plus tail rather than flattening across `0 .. 1820`:
  `702.0 / 903.0 / 943.0 / 990.0 / 1052.0` cycles for min / p50 / p90 / p99 / max
- the simple frame-marker TLM matches the RTL frame assignment at about `99.8%`
  exact agreement; output timing stays within a few cycles of that model

Representative points:

| raw full % | accepted hits/cycle | avg occ | max occ | full cycles | true `E-ts -> frame_start` p50/p90/p99/max | true `E-ts -> output` p50/p90/p99/max |
|---:|---:|---:|---:|---:|---|---|
| 10 | `0.0310` | `16.0` | `138` | `0` | `444.0 / 816.0 / 902.0 / 911.0` | `520.0 / 854.0 / 918.0 / 951.0` |
| 60 | `0.1744` | `129.5` | `256` | `270` | `458.0 / 822.0 / 902.0 / 1011.0` | `759.0 / 901.0 / 975.0 / 1064.0` |
| 100 | `0.2698` | `240.3` | `256` | `10703` | `461.0 / 820.0 / 902.0 / 1042.0` | `903.0 / 943.0 / 990.0 / 1052.0` |

## Verdict

DV status for the compact refresh is `PASS` for the promoted directed and
isolated UVM runs, and the supplemental Poisson sweep now measures the corrected
frame-marker timestamp semantics directly. The extended continuous-frame and gate-level
collateral were not refreshed in this turn and remain separate from the active
compact-bank release scope.
