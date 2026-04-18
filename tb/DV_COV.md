# DV Coverage Summary: emulator_mutrig

**Artifact:** `tb/uvm/cov/merged.ucdb`
**Refresh command:** `make -C tb/uvm clean closure SEEDS=1`
**Report source:** `tb/uvm/cov/merged.txt`
**Status:** `partial`

## 1. Active Code Coverage Snapshot

| instance | branch | statement | toggle |
|---|---:|---:|---:|
| `/tb_top/dut` | `100.00%` | `100.00%` | `76.87%` |
| `/tb_top/dut/u_hit_gen` | `77.98%` | `89.95%` | `78.72%` |
| `/tb_top/dut/u_frame_asm` | `91.54%` | `96.66%` | `89.19%` |

Filtered total reported by `vcover` on the refreshed merged UCDB:

- by-instance total: `70.74%`

## 2. Interpretation

- top-level branch and statement coverage are closed for the isolated release run
- `u_hit_gen` still dominates the residual branch/statement holes
- toggle coverage is acceptable for the refreshed isolated pass, but not yet a
  final closure argument for all execution modes

## 3. Missing Coverage Shapes

The following evidence was not refreshed in this turn:

- `bucket_frame` UCDBs
- `all_buckets_frame` UCDBs
- gate-level coverage
- growth / checkpoint UCDBs for longer random runs

## 4. Use In Signoff

This file is the active summary for the compact `26.1.9.0418` refresh. It is
good enough to support the current isolated-DV release decision, but it does not
claim full multi-mode DV closure.
