# MuTRiG Emulator (`emulator_mutrig`)

Compact FPGA MuTRiG output emulator for the Mu3e datapath. The packaged IP
`emulator_mutrig` remains the single-lane compatibility block; the standalone
area study for this refresh is `rtl/emulator_mutrig_bank8.sv`, which merges
eight lanes behind shared run-control, inject sync, and coarse counters.

## Active Release

- Release: `26.1.9.0418`
- Primary goal: keep `8` MuTRiG lanes below `4000 ALMs total`
- Lane storage rule: each lane keeps one `256 x 48` L2 hit FIFO in M10Ks
- Active signoff set:
  - [doc/RTL_PLAN.md](doc/RTL_PLAN.md)
  - [tb/DV_PLAN.md](tb/DV_PLAN.md)
  - [tb/DV_REPORT.md](tb/DV_REPORT.md)
  - [tb/DV_COV.md](tb/DV_COV.md)
  - [tb/mutrig_true_ab/results/TRUE_AB_REPORT.md](tb/mutrig_true_ab/results/TRUE_AB_REPORT.md)
  - [syn/SYN_REPORT.md](syn/SYN_REPORT.md)
  - [doc/SIGNOFF.md](doc/SIGNOFF.md)

## Compact Architecture

### Single lane

`emulator_mutrig` and `emulator_mutrig_lane_shared` now use the same compact
lane datapath:

- `hit_generator` emits directly into one lane-local `FIFO_DEPTH x 48` L2 FIFO
- `frame_assembler` drains that FIFO into MuTRiG-compatible 8b/1k frames
- no per-group L1 staging RAMs remain in the live generator

### Shared 8-lane bank

`emulator_mutrig_bank8` shares the parts that do not need to be replicated:

- run-control decode and run-state sequencing
- inject pulse fanout
- shared `tcc` / `ecc` PRBS-15 coarse counters
- common configuration broadcast

Each lane still keeps:

- one `hit_generator`
- one `frame_assembler`
- one `256 x 48` L2 FIFO in M10Ks
- lightweight LFSR-based fine-time PRNG state, with no DSP usage in the bank8 signoff build

## Current Results

### Functional

- Directed smoke: `make -C tb run_all` -> `61 passed, 0 failed`
- UVM isolated regression: `make -C tb/uvm clean closure SEEDS=1` -> `15 / 15 passed`
- Raw-vs-emulator A/B sweep: `python3 tb/mutrig_true_ab/sweep_true_ab.py`
- Coverage refresh: `make -C tb/uvm clean closure SEEDS=1`
- Key DUT coverage from `tb/uvm/cov/merged.txt`:
  - top `dut`: branch `100.00%`, statement `100.00%`, toggle `76.87%`
  - `u_hit_gen`: branch `77.98%`, statement `89.95%`, toggle `78.72%`
  - `u_frame_asm`: branch `91.54%`, statement `96.66%`, toggle `89.19%`
  - filtered merged total: `70.74%`

### True raw A/B parity

- Sweep report: [tb/mutrig_true_ab/results/TRUE_AB_REPORT.md](tb/mutrig_true_ab/results/TRUE_AB_REPORT.md)
- Harness shape:
  - raw side is `frame_gen + generic_dp_fifo(256)`
  - emulator side sees the exact same offered-hit stream through the DPI/TLM injector
- Signoff checks:
  - exact parsed payload parity
  - exact recovered hit-channel parity
  - exact parser output-cycle parity
  - exact collective latency histogram parity
- Measured result:
  - short mode and long mode both match from `0%` to `100%` offered load
  - every run completed with `accept_mismatch_count=0`
  - every run completed with `parser_data_mismatch_count=0`
  - every run completed with `hit_channel_mismatch_count=0`
  - every run completed with `parser_cycle_mismatch_count=0`
  - every run completed with `hist_total_abs_delta=0`, `hist_mismatch_bins=0`, and `hist_max_cdf_delta=0.0000`
- Full-load examples:
  - short mode `100%`: offered `3147`, accepted `2997`, output `2996`, latency `p50/p90/p99 = 913/931/942`
  - long mode `100%`: offered `3099`, accepted `2986`, output `2985`, latency `p50/p90/p99 = 1537/1578/1612`

### Poisson frame-marker latency characterization

- Sweep report: [tb/poisson_delay/results/POISSON_DELAY_REPORT.md](tb/poisson_delay/results/POISSON_DELAY_REPORT.md)
- Study mode: single-lane short-mode Poisson, `burst_size=1`, `noise=0`
- Raw offered-load reference: `1 hit / 3.5 cycles` per MuTRiG lane
- Timestamp contract under test:
  - default long-hit mode uses encoded `E` timestamp as the true hit commit time
  - encoded `T` timestamp is constrained to `T <= E`
  - `E_Flag` stays on the raw RTL-compatible default
- Corrected observables:
  - `true_ts -> frame_start` checks the raw MuTRiG marker-latch behavior directly
  - `true_ts -> output` adds the short-mode serializer tail
- Measured shape:
  - at `10%` raw full rate, `true_ts -> frame_start` is the expected one-frame box:
    `2.0 / 444.0 / 816.0 / 902.0 / 911.0` cycles for min / p50 / p90 / p99 / max
  - at `10%` raw full rate, `true_ts -> output` is the same box plus wrapper packing overhead:
    `40.0 / 520.0 / 854.0 / 918.0 / 951.0`
  - at `100%` raw full rate, `true_ts -> frame_start` still stays near one frame:
    `2.0 / 461.0 / 820.0 / 902.0 / 1042.0`
  - at `100%` raw full rate, `true_ts -> output` does not fill a flat `0 .. 1820` box; it clusters around one frame with a bounded tail:
    `702.0 / 903.0 / 943.0 / 990.0 / 1052.0`
- Occupancy and throughput:
  - occasional FIFO-full cycles first appear around `60%` raw full rate, but the lane still tracks the offered rate closely through the mid-load points
  - at `100%` raw full rate, accepted throughput is `0.2698 hits/cycle`, or about `3.71 cycles / accepted hit`
- Interpretation:
  - this standalone Poisson sweep is supplemental characterization; the true
    raw-vs-emulator signoff proof is the exact A/B histogram match above
  - at `100%` raw full rate, `59.0%` of surviving hits still complete inside one frame and `41.0%` land in the `1 .. 2 frame` band, with none beyond `2` frames
  - the simple “flat `0 .. 2 frame` box” intuition is therefore too loose for this Poisson source; both raw RTL and emulator are biased toward newer visible hits near saturation

### Standalone 8-lane synthesis

- Compile:
  - `quartus_sh --flow compile emulator_mutrig_bank8_syn -c emulator_mutrig_bank8_syn`
- Result:
  - `3856 ALMs`
  - `3777` registers
  - `98,304` block memory bits
  - `16` RAM blocks
  - `0` DSP blocks
- Area target:
  - `PASS`, because `3856 < 4000`
- Tightened timing target:
  - `PASS`, because slow `85C` setup slack is `+1.224 ns` at `137.5 MHz`

## Notes

- The bank8 compile is the current standalone proof vehicle for the
  architect-requested `<4000 ALM / 8 lane` target.
- The single-lane packaged IP stays in place for Platform Designer integration.
- Continuous-frame and gate-level collateral were not rerun for this compact-bank refresh.
- `doc/SIGNOFF.md` is the master review page; the root
  [SIGNOFF.md](SIGNOFF.md) is only a pointer.
