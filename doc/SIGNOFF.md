# Signoff — emulator_mutrig

**DUT family:** `emulator_mutrig` &nbsp; **Date:** `2026-04-18` &nbsp;
**Release under check:** `26.1.5.0418`

This is the master signoff dashboard for the compact MuTRiG refresh. Detailed DV
evidence lives in [../tb/DV_REPORT.md](../tb/DV_REPORT.md); detailed standalone
synthesis evidence lives in [../syn/SYN_REPORT.md](../syn/SYN_REPORT.md).

## Health

| status | field | value |
|:---:|---|---|
| PASS | overall_requested_scope | compact bank release goals are closed for the active scope: area, tightened timing, directed DV, isolated UVM, and timestamp-contract checks |
| PARTIAL | full_multi_mode_signoff | continuous-frame and gate-level collateral were not rerun in this refresh |
| PASS | area_target | `3958 ALMs < 4000 ALMs for 8 lanes` |
| PASS | tightened_timing | slow `85C` setup slack `+0.139 ns` at `137.5 MHz` |
| PASS | directed_smoke | `54 passed, 0 failed` |
| PASS | isolated_uvm | `15 / 15 passed` |
| PASS | merged_ucdb_refresh | current isolated UCDB and text report are present |
| PASS | hit_contract_checks | `asic_id 0..7`, hit channel `0..31`, raw `E_Flag`, and default `T <= E` timestamp semantics verified |
| PASS | poisson_timestamp_study | true `E-ts -> pop` measured from idle to the raw full-link reference |
| PARTIAL | cross_mode_dv | continuous-frame evidence not refreshed |
| PARTIAL | gate_level | not rerun in this refresh |

## Verification

| status | area | result | source |
|:---:|---|---|---|
| PASS | directed bench | `make -C tb run_all` -> `54 passed, 0 failed` | [../tb/DV_REPORT.md](../tb/DV_REPORT.md) |
| PASS | isolated UVM | `make -C tb/uvm clean closure SEEDS=1` -> `15 / 15 passed` | [../tb/DV_REPORT.md](../tb/DV_REPORT.md) |
| PASS | targeted contract checks | directed bench covers `asic_id`, hit channel bounds, `E_Flag`, and `T <= E` semantics | [../tb/DV_REPORT.md](../tb/DV_REPORT.md) |
| PASS | Poisson timestamp study | short-mode true `E-ts -> pop` sweep from `0%` to `100%` raw offered load captured | [../tb/poisson_delay/results/POISSON_DELAY_REPORT.md](../tb/poisson_delay/results/POISSON_DELAY_REPORT.md) |
| PARTIAL | code coverage | isolated merged UCDB refreshed, multi-mode coverage still open | [../tb/DV_COV.md](../tb/DV_COV.md) |

## Synthesis

| status | item | value |
|:---:|---|---|
| PASS | revision | `emulator_mutrig_bank8_syn` |
| PASS | device | `5AGXBA7D4F31C5` |
| PASS | signoff constraint | `137.5 MHz` / `7.273 ns` |
| PASS | fitted resources | `3958 ALMs`, `3579 regs`, `16 RAM`, `0 DSP` |
| PASS | area objective | `8` lanes are below the `4000 ALM` target |
| PASS | slow 85C setup | `+0.139 ns` |
| PASS | hold timing | worst hold slack `+0.150 ns` or better |
| PARTIAL | harness constraints | standalone wrapper leaves many non-core I/O paths unconstrained |

## Queueing Characterization

Supplemental short-mode Poisson characterization shows:

- the primary latency metric is true `E-ts -> pop`, because the default long-hit
  contract commits on the encoded `E` timestamp
- at `10%` raw full rate, true `E-ts -> pop` spans almost one full short-frame
  window with a `~32` cycle floor from frame-header overhead
- at `100%` raw full rate, true `E-ts -> pop` stays mostly in the
  `0.8 .. 1.15` frame range rather than filling a full `0 .. 1820` cycle box
- occasional FIFO-full cycles begin around `60%` raw full rate, but accepted
  throughput still tracks the offered rate closely through the mid-load points
- at `100%` raw full rate, accepted throughput is `0.2698 hits/cycle`, about
  `3.71 cycles / accepted hit`

## Fixes In Scope

| status | class | summary |
|:---:|---|---|
| PASS | RTL | compact lane generator now uses one RAM-backed L2 FIFO instead of the old staging fabric |
| PASS | RTL | bank8 merged shell added for standalone shared-resource study |
| PASS | RTL | first post-start frame now waits a full frame interval |
| PASS | RTL | new frame starts are gated by enable in both single-lane and bank8 lane wrappers |
| PASS | RTL | single-lane public `asic_id` is clamped to the bank-valid `0..7` range |
| PASS | RTL | long-hit default timing now keeps `T <= E`, commits on `E`, and preserves raw-compatible `E_Flag = 1` |
| PASS | Harness | reset-default UVM expectation aligned to the live cluster defaults |
| PASS | Metadata | packaged IP defaults updated to `26.1.5.0418` |

## Evidence Index

- [../tb/DV_PLAN.md](../tb/DV_PLAN.md)
- [../tb/DV_REPORT.md](../tb/DV_REPORT.md)
- [../tb/DV_COV.md](../tb/DV_COV.md)
- [../tb/poisson_delay/results/POISSON_DELAY_REPORT.md](../tb/poisson_delay/results/POISSON_DELAY_REPORT.md)
- [../syn/SYN_REPORT.md](../syn/SYN_REPORT.md)
- [RTL_PLAN.md](RTL_PLAN.md)
- [rtl_note.md](rtl_note.md)

## Verdict

Overall signoff for `26.1.5.0418` is `PASS` for the active compact-bank scope:

- the merged bank closes the requested `<4000 ALM / 8 lane` area target
- tightened standalone timing closes at `137.5 MHz`
- directed DV, isolated UVM, and the requested timestamp-contract checks are green
- continuous-frame and gate-level collateral remain out of scope for this
  refresh and are still called out separately as not rerun
