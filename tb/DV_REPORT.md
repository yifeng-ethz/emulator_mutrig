# DV Report — emulator_mutrig

**DUT:** `emulator_mutrig` &nbsp; **Date:** `2026-04-18` &nbsp;
**Release under check:** `26.1.9.0418`

This is the active DV dashboard for the compact MuTRiG refresh.

## Health

| status | field | value |
|:---:|---|---|
| PASS | directed_smoke | `61 passed, 0 failed` |
| PASS | isolated_uvm | `15 / 15 passed` |
| PASS | true_raw_ab | short and long mode both keep exact collective latency histograms, exact channels, and exact parser output timing from `0%` to `100%` offered load |
| PASS | compact_contract_checks | `asic_id 0..7`, hit channel `0..31`, raw `E_Flag`, and `T <= E` checks are green in the directed bench |
| PASS | merged_ucdb_refresh | `tb/uvm/cov/merged.ucdb` present |
| PASS | poisson_delay_sweep | corrected frame-marker latency study measured true `E-ts -> frame_start` and `E-ts -> output` from `0%` to `100%` of the raw full-link reference |
| PARTIAL | continuous_frame | not rerun in this refresh |
| PARTIAL | gate_level | not rerun in this refresh |

## Executed Evidence

| status | command | result |
|:---:|---|---|
| PASS | `make -C tb run_all` | `61 passed, 0 failed` |
| PASS | `make -C tb/uvm clean closure SEEDS=1` | refreshed merged UCDB and text report |
| PASS | `python3 tb/mutrig_true_ab/sweep_true_ab.py` | short/long raw RTL A/B sweep passed with zero payload, channel, cycle, or histogram deltas |
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
| `/tb_top/dut` | `100.00%` | `100.00%` | `76.87%` |
| `/tb_top/dut/u_hit_gen` | `77.98%` | `89.95%` | `78.72%` |
| `/tb_top/dut/u_frame_asm` | `91.54%` | `96.66%` | `89.19%` |

Filtered merged total from `vcover`:

- `70.74%`

## True Raw A/B Sweep

Artifacts:

- report: [mutrig_true_ab/results/TRUE_AB_REPORT.md](mutrig_true_ab/results/TRUE_AB_REPORT.md)
- driver: [mutrig_true_ab/sweep_true_ab.py](mutrig_true_ab/sweep_true_ab.py)

Configuration:

- raw side is `frame_gen + generic_dp_fifo(256)`
- emulator side consumes the exact same offered-hit stream
- checks run in both short and long mode from `0%` to `100%` offered load

Key findings:

- all runs completed with `accept_mismatch_count=0`
- all runs completed with `parser_data_mismatch_count=0`
- all runs completed with `hit_channel_mismatch_count=0`
- all runs completed with `parser_cycle_mismatch_count=0`
- all runs completed with `hist_total_abs_delta=0`
- all runs completed with `hist_mismatch_bins=0`
- all runs completed with `hist_max_cdf_delta=0.0000`

Representative full-load points:

| mode | load | offered | accepted | output | p50/p90/p99 | max |
|---|---:|---:|---:|---:|---|---:|
| short | `100%` | `3147` | `2997` | `2996` | `913 / 931 / 942` | `952` |
| long | `100%` | `3099` | `2986` | `2985` | `1537 / 1578 / 1612` | `1632` |

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
- this standalone Poisson sweep is supplemental; the exact equivalence proof is
  the raw true-A/B histogram match above

Representative points:

| raw full % | accepted hits/cycle | avg occ | max occ | full cycles | true `E-ts -> frame_start` p50/p90/p99/max | true `E-ts -> output` p50/p90/p99/max |
|---:|---:|---:|---:|---:|---|---|
| 10 | `0.0310` | `16.0` | `138` | `0` | `444.0 / 816.0 / 902.0 / 911.0` | `520.0 / 854.0 / 918.0 / 951.0` |
| 60 | `0.1744` | `129.5` | `256` | `270` | `458.0 / 822.0 / 902.0 / 1011.0` | `759.0 / 901.0 / 975.0 / 1064.0` |
| 100 | `0.2698` | `240.3` | `256` | `10703` | `461.0 / 820.0 / 902.0 / 1042.0` | `903.0 / 943.0 / 990.0 / 1052.0` |

## Verdict

DV status for the compact refresh is `PASS` for the promoted directed and
isolated UVM runs. The raw MuTRiG A/B harness now proves exact collective
latency-distribution parity, exact hit-channel parity, and exact saturation
behavior in both short and long mode. The extended continuous-frame and
gate-level collateral were not refreshed in this turn and remain separate from
the active compact-bank release scope.
