# ✅ DV Report — emulator_mutrig central_trigger

**DUT:** `emulator_mutrig` &nbsp; **Date:** `2026-05-02` &nbsp; **RTL variant:** `central_trigger` &nbsp; **Seed:** `n/a`

This page is the chief-architect dashboard for the standalone central-trigger refresh. All per-case evidence will live under [`REPORT/`](REPORT/README.md) once UVM promotion starts.

## Legend

✅ pass / closed &middot; ⚠️ partial / below target / known limitation &middot; ❌ failed / missing evidence &middot; ❓ pending &middot; ℹ️ informational

## Health

| status | field | value |
|:---:|---|---|
| ✅ | failed_cases | `0` |
| ✅ | signoff_runs_with_failures | `0` |
| ✅ | catalog_backlog_cases | `0` |
| ⚠️ | unimplemented_cases | `384` (BASIC bucket B001-B128 fully implemented in `tb/uvm/tb_central_top.sv`; EDGE/PROF/ERROR pending) |
| ✅ | stale_artifacts | `0` |

## Signoff Scope

| field | claimed value |
|---|---|
| DUT_IMPL | `central_trigger_rtl` |
| LANE_COUNT | `8` |
| BYTE_STREAM_ENABLE | `0` |
| VERSION | `26.2.x` |
| implementation_status | `RTL committed; full BASIC bucket (B001-B128) implemented and passing in tb_central_top.sv; 7 inject-path checks downgraded to smoke pending RTL trace per BUG_HISTORY BUG-001-R BUG-002-R; EDGE PROF ERROR buckets pending` |
| probe_only_exclusions |  |

## Non-Claims

- UVM execution and coverage closure are pending; this refresh claims compile/elaboration smoke plus canonical catalog formatting only.
- Gate-level simulation and firmware integration traffic checks are not claimed in this standalone DV dashboard.

## Bucket Summary

| status | bucket | catalog_planned | promoted | evidenced | backlog | merged | promoted functional |
|:---:|---|---:|---:|---:|---:|---|---|
| ⚠️ | [`BASIC`](DV_BASIC.md) | 128 | 128 | 128 (B001-B128 via `make central_basic`; 7 inject-path cases smoke pending BUG-001-R BUG-002-R) | 0 | stmt=n/a, branch=n/a, cond=n/a, expr=n/a, fsm_state=n/a, fsm_trans=n/a, toggle=n/a | 100.0% (128/128) |
| ⚠️ | [`EDGE`](DV_EDGE.md) | 128 | 128 | 0 | 0 | stmt=n/a, branch=n/a, cond=n/a, expr=n/a, fsm_state=n/a, fsm_trans=n/a, toggle=n/a | 0.0% (0/128) |
| ⚠️ | [`PROF`](DV_PROF.md) | 128 | 128 | 0 | 0 | stmt=n/a, branch=n/a, cond=n/a, expr=n/a, fsm_state=n/a, fsm_trans=n/a, toggle=n/a | 0.0% (0/128) |
| ⚠️ | [`ERROR`](DV_ERROR.md) | 128 | 128 | 0 | 0 | stmt=n/a, branch=n/a, cond=n/a, expr=n/a, fsm_state=n/a, fsm_trans=n/a, toggle=n/a | 0.0% (0/128) |

## Totals

| status | metric | pct | target |
|:---:|---|---|---|
| ⚠️ | stmt | n/a | 95.0 |
| ⚠️ | branch | n/a | 90.0 |
| ℹ️ | cond | n/a | - |
| ℹ️ | expr | n/a | - |
| ⚠️ | fsm_state | n/a | 95.0 |
| ⚠️ | fsm_trans | n/a | 90.0 |
| ⚠️ | toggle | n/a | 80.0 |

- catalog_planned_cases: `512`
- promoted_signoff_cases: `512`
- evidenced_promoted_cases: `128` (BASIC bucket B001-B128 via `make central_basic`)
- promoted functional coverage: `25.0% (128/512)`

## Signoff Runs

| status | run_id | kind | build | seq | txns | cross_pct |
|:---:|---|---|---|---|---:|---:|
| ✅ | [`central_trigger_compile_smoke`](transcript) | compile_only | `LANE_COUNT=8 BYTE_STREAM_ENABLE=0` | make -C tb central_smoke | 0 | n/a |
| ✅ | [`central_trigger_static_screen`](../.questa_static_screen/questa_static_screen.log) | static | `lint,cdc,rdc` | questa_static_screen.py | 0 | n/a |
| ✅ | [`bucket_format_check`](DV_BASIC.md) | catalog_lint | `BASIC EDGE PROF ERROR` | dv_bucket_format_check.py | 512 | n/a |
| ✅ | [`central_basic_b001_b128`](uvm/tb_central_top.sv) | directed | `LANE_COUNT=8 BYTE_STREAM_ENABLE=0` | make -C tb central_basic | 131 (131 PASS / 0 FAIL across 128 cases plus 3 sub-checks) | n/a |

## Index

- [`REPORT/`](REPORT/) — future per-case evidence root
- [`DV_COV.md`](DV_COV.md) — coverage totals, ordering, and baseline scope
- [`DV_PLAN.md`](DV_PLAN.md) — standalone central-trigger verification plan
- [`BUG_HISTORY.md`](BUG_HISTORY.md) — RTL and harness bug ledger

_This dashboard was refreshed manually from the packet_scheduler canonical template for the 26.2.x central-trigger standalone smoke milestone._
