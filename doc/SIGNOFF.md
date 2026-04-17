# Signoff — emulator_mutrig

**DUT family:** `emulator_mutrig` &nbsp; **Date:** `2026-04-17` &nbsp;
**Release under check:** `26.1.1.0417`

This is the master signoff dashboard for the compact MuTRiG refresh. Detailed DV
evidence lives in [../tb/DV_REPORT.md](../tb/DV_REPORT.md); detailed standalone
synthesis evidence lives in [../syn/SYN_REPORT.md](../syn/SYN_REPORT.md).

## Health

| status | field | value |
|:---:|---|---|
| PARTIAL | overall_signoff | compact release is functionally green and area-clean, but timing is not yet closed at `137.5 MHz` |
| PASS | area_target | `3398 ALMs < 4000 ALMs for 8 lanes` |
| PASS | directed_smoke | `49 passed, 0 failed` |
| PASS | isolated_uvm | `15 / 15 passed` |
| PASS | merged_ucdb_refresh | current isolated UCDB and text report are present |
| PASS | poisson_queue_study | short-mode FIFO knee characterized; saturation starts around `90%` of raw full rate |
| PARTIAL | tightened_timing | slow `85C` setup slack `-0.544 ns` |
| PARTIAL | cross_mode_dv | continuous-frame evidence not refreshed |
| PARTIAL | gate_level | not rerun in this refresh |

## Verification

| status | area | result | source |
|:---:|---|---|---|
| PASS | directed bench | `make -C tb run_all` -> `49 passed, 0 failed` | [../tb/DV_REPORT.md](../tb/DV_REPORT.md) |
| PASS | isolated UVM | `make -C tb/uvm regress SEEDS=1` -> `15 / 15 passed` | [../tb/DV_REPORT.md](../tb/DV_REPORT.md) |
| PASS | targeted reruns | compact-release bug fixes verified in focused reruns | [../tb/DV_REPORT.md](../tb/DV_REPORT.md) |
| PASS | Poisson queue study | short-mode delay sweep from `0%` to `100%` raw offered load captured | [../tb/poisson_delay/results/POISSON_DELAY_REPORT.md](../tb/poisson_delay/results/POISSON_DELAY_REPORT.md) |
| PARTIAL | code coverage | isolated merged UCDB refreshed, multi-mode coverage still open | [../tb/DV_COV.md](../tb/DV_COV.md) |

## Synthesis

| status | item | value |
|:---:|---|---|
| PASS | revision | `emulator_mutrig_bank8_syn` |
| PASS | device | `5AGXBA7D4F31C5` |
| PASS | signoff constraint | `137.5 MHz` / `7.273 ns` |
| PASS | fitted resources | `3398 ALMs`, `2927 regs`, `16 RAM`, `16 DSP` |
| PASS | area objective | `8` lanes are below the `4000 ALM` target |
| PARTIAL | slow 85C setup | `-0.544 ns`, Fmax `127.93 MHz` |
| PASS | hold timing | worst hold slack `+0.149 ns` or better |
| PARTIAL | harness constraints | standalone wrapper leaves many non-core I/O paths unconstrained |

## Queueing Characterization

Supplemental short-mode Poisson characterization shows:

- no L2 FIFO saturation through `80%` of the raw `1 hit / 3.5 cycles` offered
  load
- FIFO-full activity begins around `90%` raw offered load
- accepted throughput plateaus near `0.259 hits/cycle`, about
  `3.86 cycles / accepted hit`
- the raw `3.5 cycles / hit` figure is therefore slightly optimistic once frame
  overhead is included in the closed-loop service path

## Fixes In Scope

| status | class | summary |
|:---:|---|---|
| PASS | RTL | compact lane generator now uses one RAM-backed L2 FIFO instead of the old staging fabric |
| PASS | RTL | bank8 merged shell added for standalone shared-resource study |
| PASS | RTL | first post-start frame now waits a full frame interval |
| PASS | RTL | new frame starts are gated by enable in both single-lane and bank8 lane wrappers |
| PASS | Harness | reset-default UVM expectation aligned to the live cluster defaults |
| PASS | Metadata | packaged IP defaults updated to `26.1.1.0417` |

## Evidence Index

- [../tb/DV_PLAN.md](../tb/DV_PLAN.md)
- [../tb/DV_REPORT.md](../tb/DV_REPORT.md)
- [../tb/DV_COV.md](../tb/DV_COV.md)
- [../tb/poisson_delay/results/POISSON_DELAY_REPORT.md](../tb/poisson_delay/results/POISSON_DELAY_REPORT.md)
- [../syn/SYN_REPORT.md](../syn/SYN_REPORT.md)
- [RTL_PLAN.md](RTL_PLAN.md)
- [rtl_note.md](rtl_note.md)

## Verdict

Overall signoff for `26.1.1.0417` is `PARTIAL`:

- functionally, the compact lane refresh is in good shape
- for area, the merged bank closes the requested `<4000 ALM / 8 lane` target
- for short-mode queueing, the lane stays comfortable through `80%` raw offered
  load and starts to saturate near `90%`
- for tightened standalone timing, more work is still required if `137.5 MHz`
  remains the hard signoff clock
