# Signoff — emulator_mutrig

**DUT family:** `emulator_mutrig` &nbsp; **Date:** `2026-04-18` &nbsp;
**Release under check:** `26.1.7.0418`

This is the master signoff dashboard for the compact MuTRiG refresh. Detailed DV
evidence lives in [../tb/DV_REPORT.md](../tb/DV_REPORT.md); detailed standalone
synthesis evidence lives in [../syn/SYN_REPORT.md](../syn/SYN_REPORT.md).

## Health

| status | field | value |
|:---:|---|---|
| PASS | overall_requested_scope | compact bank release goals are closed for the active scope: area, tightened timing, directed DV, isolated UVM, raw true-A/B parity, and timestamp-contract checks |
| PARTIAL | full_multi_mode_signoff | continuous-frame and gate-level collateral were not rerun in this refresh |
| PASS | area_target | `3883 ALMs < 4000 ALMs for 8 lanes` |
| PASS | tightened_timing | slow `85C` setup slack `+0.026 ns` at `137.5 MHz` |
| PASS | directed_smoke | `54 passed, 0 failed` |
| PASS | isolated_uvm | `15 / 15 passed` |
| PASS | true_raw_ab_distribution | short and long mode both keep exact collective latency histograms, exact recovered channels, and exact parser output timing from `0%` to `100%` offered load |
| PASS | merged_ucdb_refresh | current isolated UCDB and text report are present |
| PASS | hit_contract_checks | `asic_id 0..7`, hit channel `0..31`, raw `E_Flag`, and default `T <= E` timestamp semantics verified |
| PASS | poisson_timestamp_study | corrected frame-marker study measures true `E-ts -> frame_start` and `E-ts -> output` from idle to the raw full-link reference |
| PARTIAL | cross_mode_dv | continuous-frame evidence not refreshed |
| PARTIAL | gate_level | not rerun in this refresh |

## Verification

| status | area | result | source |
|:---:|---|---|---|
| PASS | directed bench | `make -C tb run_all` -> `54 passed, 0 failed` | [../tb/DV_REPORT.md](../tb/DV_REPORT.md) |
| PASS | isolated UVM | `make -C tb/uvm clean closure SEEDS=1` -> `15 / 15 passed` | [../tb/DV_REPORT.md](../tb/DV_REPORT.md) |
| PASS | true raw A/B | `python3 tb/mutrig_true_ab/sweep_true_ab.py` -> exact short/long latency histograms, channel parity, payload parity, and cycle parity | [../tb/mutrig_true_ab/results/TRUE_AB_REPORT.md](../tb/mutrig_true_ab/results/TRUE_AB_REPORT.md) |
| PASS | targeted contract checks | directed bench covers `asic_id`, hit channel bounds, `E_Flag`, and `T <= E` semantics | [../tb/DV_REPORT.md](../tb/DV_REPORT.md) |
| PASS | Poisson timestamp study | short-mode corrected frame-marker sweep from `0%` to `100%` raw offered load captured | [../tb/poisson_delay/results/POISSON_DELAY_REPORT.md](../tb/poisson_delay/results/POISSON_DELAY_REPORT.md) |
| PARTIAL | code coverage | isolated merged UCDB refreshed, multi-mode coverage still open | [../tb/DV_COV.md](../tb/DV_COV.md) |

## Synthesis

| status | item | value |
|:---:|---|---|
| PASS | revision | `emulator_mutrig_bank8_syn` |
| PASS | device | `5AGXBA7D4F31C5` |
| PASS | signoff constraint | `137.5 MHz` / `7.273 ns` |
| PASS | fitted resources | `3883 ALMs`, `3545 regs`, `16 RAM`, `0 DSP` |
| PASS | area objective | `8` lanes are below the `4000 ALM` target |
| PASS | slow 85C setup | `+0.026 ns` |
| PASS | hold timing | worst hold slack `+0.132 ns` or better |
| PARTIAL | harness constraints | standalone wrapper leaves many non-core I/O paths unconstrained |

## Queueing Characterization

Supplemental short-mode Poisson characterization shows:

- exact raw-versus-emulator signoff parity is proven separately by the true-A/B
  sweep, with zero histogram delta across the promoted short/long load points
- the corrected raw-style observables are `true E-ts -> frame_start` and
  `true E-ts -> output`
- at `10%` raw full rate, `true E-ts -> frame_start` is the expected one-frame
  box: `2.0 / 444.0 / 816.0 / 902.0 / 911.0` cycles for min / p50 / p90 / p99 / max
- at `100%` raw full rate, `true E-ts -> output` stays bounded near one frame
  plus tail: `702.0 / 903.0 / 943.0 / 990.0 / 1052.0`
- occasional FIFO-full cycles begin around `60%` raw full rate, but accepted
  throughput still tracks the offered rate closely through the mid-load points
- at `100%` raw full rate, accepted throughput is `0.2698 hits/cycle`, about
  `3.71 cycles / accepted hit`
- the high-load distribution does not become a flat `0 .. 1820` cycle box; the
  surviving-hit population is biased toward newer visible hits near saturation

## Fixes In Scope

| status | class | summary |
|:---:|---|---|
| PASS | RTL | compact lane generator now uses one RAM-backed L2 FIFO instead of the old staging fabric |
| PASS | RTL | bank8 merged shell added for standalone shared-resource study |
| PASS | RTL | frame assembly now follows raw-style frozen-count drain semantics at the frame marker |
| PASS | RTL | first post-start frame now waits a full frame interval |
| PASS | RTL | new frame starts are gated by enable in both single-lane and bank8 lane wrappers |
| PASS | RTL | single-lane public `asic_id` is clamped to the bank-valid `0..7` range |
| PASS | RTL | long-hit default timing now keeps `T <= E`, commits on `E`, and preserves raw-compatible `E_Flag = 1` |
| PASS | Harness | reset-default UVM expectation aligned to the live cluster defaults |
| PASS | Metadata | packaged IP defaults updated to `26.1.7.0418` |

## Evidence Index

- [../tb/DV_PLAN.md](../tb/DV_PLAN.md)
- [../tb/DV_REPORT.md](../tb/DV_REPORT.md)
- [../tb/DV_COV.md](../tb/DV_COV.md)
- [../tb/mutrig_true_ab/results/TRUE_AB_REPORT.md](../tb/mutrig_true_ab/results/TRUE_AB_REPORT.md)
- [../tb/poisson_delay/results/POISSON_DELAY_REPORT.md](../tb/poisson_delay/results/POISSON_DELAY_REPORT.md)
- [../syn/SYN_REPORT.md](../syn/SYN_REPORT.md)
- [RTL_PLAN.md](RTL_PLAN.md)
- [rtl_note.md](rtl_note.md)

## Verdict

Overall signoff for `26.1.7.0418` is `PASS` for the active compact-bank scope:

- the merged bank closes the requested `<4000 ALM / 8 lane` area target
- tightened standalone timing closes at `137.5 MHz`
- directed DV, isolated UVM, the raw true-A/B distribution check, and the
  requested timestamp-contract checks are green
- continuous-frame and gate-level collateral remain out of scope for this
  refresh and are still called out separately as not rerun
