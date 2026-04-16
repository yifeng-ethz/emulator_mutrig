# DV Coverage Tracking: emulator_mutrig

This file is mandatory sign-off collateral. It is established at DV bring-up and must be maintained through testbench development, debug, regression, and closure.

## 1. Execution Modes

Required modes:

1. `isolated`: default; each testcase runs in a separate timeframe with a fresh DUT start
2. `bucket_frame`: each verification bucket runs in one continuous timeframe without restarting the DUT between cases
3. `all_buckets_frame`: all sign-off buckets run in one continuous timeframe without restarting the DUT between cases

Continuous-frame rules:
- directed cases execute one transaction per case
- random cases execute several transactions per case
- case order is fixed and must be maintained

Current frame-baseline order for implemented emulator UVM cases:

- `bucket_frame BASIC`: `emut_test_idle_and_runctl`, `emut_test_long_inject_single`, `emut_test_short_inject_single`, `emut_test_long_burst_mode`, `emut_test_short_burst_mode`, `emut_test_noise_mode`, `emut_test_short_pack_extra_tail`, `emut_test_auto_low_center`, `emut_test_terminate_no_new_frame`
- `bucket_frame PROF`: `emut_test_high_rate_fill`, `emut_test_mode_payload_sweep`, `emut_test_inject_matrix`
- `bucket_frame CROSS`: `emut_test_mixed_random`
- `all_buckets_frame`: `BASIC -> PROF -> CROSS` in the orders listed above

Current isolated-only cases that still depend on fresh-reset assumptions and must be repaired or split before they can join continuous-frame baselines:
- `emut_test_reset_defaults`
- `emut_test_disable_and_status`

## 2. BASIC Bucket

Current merged code coverage total:
- isolated: `stmt=pending, branch=pending, cond=pending, expr=pending, fsm=pending, toggle=pending`
- bucket_frame: `stmt=91.50, branch=87.25, cond=63.46, expr=96.70, fsm_state=100.00, fsm_trans=63.16, toggle=80.73`

Current final functional coverage total:
- bucket_frame: `mode_payload=71.9, integrity=100.0, enable=50.0, ctrl=100.0, inject=68.8`
- isolated: `pending`

| case_id | type (d/r) | coverage_by_this_case | executed random txn | coverage_incr_per_txn |
|---|---|---|---|---|
| emut_test_idle_and_runctl | d | stmt=pending, branch=pending, cond=pending, expr=pending, fsm=pending, toggle=pending | 0 | n/a |
| emut_test_long_inject_single | d | stmt=pending, branch=pending, cond=pending, expr=pending, fsm=pending, toggle=pending | 0 | n/a |
| emut_test_short_inject_single | d | stmt=pending, branch=pending, cond=pending, expr=pending, fsm=pending, toggle=pending | 0 | n/a |
| emut_test_long_burst_mode | d | stmt=pending, branch=pending, cond=pending, expr=pending, fsm=pending, toggle=pending | 0 | n/a |
| emut_test_short_burst_mode | d | stmt=pending, branch=pending, cond=pending, expr=pending, fsm=pending, toggle=pending | 0 | n/a |
| emut_test_noise_mode | d | stmt=pending, branch=pending, cond=pending, expr=pending, fsm=pending, toggle=pending | 0 | n/a |
| emut_test_short_pack_extra_tail | d | stmt=pending, branch=pending, cond=pending, expr=pending, fsm=pending, toggle=pending | 0 | n/a |
| emut_test_auto_low_center | d | stmt=pending, branch=pending, cond=pending, expr=pending, fsm=pending, toggle=pending | 0 | n/a |
| emut_test_terminate_no_new_frame | d | stmt=pending, branch=pending, cond=pending, expr=pending, fsm=pending, toggle=pending | 0 | n/a |
| emut_test_reset_defaults | d | stmt=pending, branch=pending, cond=pending, expr=pending, fsm=pending, toggle=pending | 0 | n/a |
| emut_test_disable_and_status | d | stmt=pending, branch=pending, cond=pending, expr=pending, fsm=pending, toggle=pending | 0 | n/a |

## 3. EDGE Bucket

Current merged code coverage total:
- isolated: `stmt=pending, branch=pending, cond=pending, expr=pending, fsm=pending, toggle=pending`
- bucket_frame: `stmt=pending, branch=pending, cond=pending, expr=pending, fsm=pending, toggle=pending`

Current final functional coverage total:
- `pending`

| case_id | type (d/r) | coverage_by_this_case | executed random txn | coverage_incr_per_txn |
|---|---|---|---|---|
| pending_case_population | d | stmt=pending, branch=pending, cond=pending, expr=pending, fsm=pending, toggle=pending | 0 | n/a |

## 4. PROF Bucket

Current merged code coverage total:
- isolated: `stmt=pending, branch=pending, cond=pending, expr=pending, fsm=pending, toggle=pending`
- bucket_frame: `stmt=pending, branch=pending, cond=pending, expr=pending, fsm=pending, toggle=pending`

Current final functional coverage total:
- `pending`

| case_id | type (d/r) | coverage_by_this_case | executed random txn | coverage_incr_per_txn |
|---|---|---|---|---|
| emut_test_high_rate_fill | d | stmt=pending, branch=pending, cond=pending, expr=pending, fsm=pending, toggle=pending | 0 | n/a |
| emut_test_mode_payload_sweep | d | stmt=pending, branch=pending, cond=pending, expr=pending, fsm=pending, toggle=pending | 0 | n/a |
| emut_test_inject_matrix | d | stmt=pending, branch=pending, cond=pending, expr=pending, fsm=pending, toggle=pending | 0 | n/a |

## 5. ERROR Bucket

Current merged code coverage total:
- isolated: `stmt=pending, branch=pending, cond=pending, expr=pending, fsm=pending, toggle=pending`
- bucket_frame: `stmt=pending, branch=pending, cond=pending, expr=pending, fsm=pending, toggle=pending`

Current final functional coverage total:
- `pending`

| case_id | type (d/r) | coverage_by_this_case | executed random txn | coverage_incr_per_txn |
|---|---|---|---|---|
| pending_case_population | d | stmt=pending, branch=pending, cond=pending, expr=pending, fsm=pending, toggle=pending | 0 | n/a |

## 6. CROSS Bucket

Current merged code coverage total:
- isolated: `stmt=pending, branch=pending, cond=pending, expr=pending, fsm=pending, toggle=pending`
- bucket_frame: `stmt=pending, branch=pending, cond=pending, expr=pending, fsm=pending, toggle=pending`

Current final functional coverage total:
- `pending`

| case_id | type (d/r) | coverage_by_this_case | executed random txn | coverage_incr_per_txn |
|---|---|---|---|---|
| emut_test_mixed_random | r | stmt=pending, branch=pending, cond=pending, expr=pending, fsm=pending, toggle=pending | 12 | stmt=pending, branch=pending, cond=pending, expr=pending, fsm=pending, toggle=pending |

## 7. All-Buckets Frame Baseline

Current merged code coverage total:
- all_buckets_frame: `stmt=94.90, branch=89.26, cond=71.15, expr=96.70, fsm_state=100.00, fsm_trans=63.16, toggle=84.94`

Current final functional coverage total:
- all_buckets_frame: `mode_payload=100.0, integrity=100.0, enable=50.0, ctrl=100.0, inject=100.0`

All-buckets frame order:
- `BASIC -> PROF -> CROSS`
- case order within each bucket is fixed as listed above
- isolated-only cases are excluded until they are made frame-safe

## 8. Sign-Off Summary

Final sign-off totals:
- merged total code coverage across all sign-off buckets: `pending`
- total final functional coverage across all sign-off buckets: `pending`
- traceability to isolated, `bucket_frame`, and `all_buckets_frame` regression evidence: `partial; current baseline evidence is emulator_mutrig/tb/uvm/cov/emut_test_bucket_frame_basic_s1.ucdb and emulator_mutrig/tb/uvm/cov/emut_test_all_buckets_frame_s1.ucdb`
