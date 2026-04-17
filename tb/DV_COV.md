# DV Coverage Summary: emulator_mutrig

**Artifact:** `tb/uvm/cov/merged.ucdb`
**Refresh command:** `make -C tb/uvm clean closure SEEDS=1`
**Report source:** `tb/uvm/cov/merged.txt`
**Status:** `partial`

## 1. Active Code Coverage Snapshot

| instance | branch | statement | toggle |
|---|---:|---:|---:|
| `/tb_top/dut` | `100.00%` | `100.00%` | `77.92%` |
| `/tb_top/dut/u_hit_gen` | `77.35%` | `89.45%` | `88.64%` |
| `/tb_top/dut/u_frame_asm` | `93.05%` | `96.03%` | `86.27%` |

Filtered total reported by `vcover` on the refreshed merged UCDB:

- by-instance total: `72.26%`

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

This file is the active summary for the compact `26.1.5.0418` refresh. It is
good enough to support the current isolated-DV release decision, but it does not
claim full multi-mode DV closure.
