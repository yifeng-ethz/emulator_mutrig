# MuTRiG Emulator (`emulator_mutrig`)

Compact FPGA MuTRiG output emulator for the Mu3e datapath. The packaged IP
`emulator_mutrig` remains the single-lane compatibility block; the standalone
area study for this refresh is `rtl/emulator_mutrig_bank8.sv`, which merges
eight lanes behind shared run-control, inject sync, and coarse counters.

## Active Release

- Release: `26.1.5.0418`
- Primary goal: keep `8` MuTRiG lanes below `4000 ALMs total`
- Lane storage rule: each lane keeps one `256 x 48` L2 hit FIFO in M10Ks
- Active signoff set:
  - [doc/RTL_PLAN.md](doc/RTL_PLAN.md)
  - [tb/DV_PLAN.md](tb/DV_PLAN.md)
  - [tb/DV_REPORT.md](tb/DV_REPORT.md)
  - [tb/DV_COV.md](tb/DV_COV.md)
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

- Directed smoke: `make -C tb run_all` -> `54 passed, 0 failed`
- UVM isolated regression: `make -C tb/uvm clean closure SEEDS=1` -> `15 / 15 passed`
- Coverage refresh: `make -C tb/uvm clean closure SEEDS=1`
- Key DUT coverage from `tb/uvm/cov/merged.txt`:
  - top `dut`: branch `100.00%`, statement `100.00%`, toggle `77.92%`
  - `u_hit_gen`: branch `77.35%`, statement `89.45%`, toggle `88.64%`
  - `u_frame_asm`: branch `93.05%`, statement `96.03%`, toggle `86.27%`
  - filtered merged total: `72.26%`

### Poisson timestamp-to-pop characterization

- Sweep report: [tb/poisson_delay/results/POISSON_DELAY_REPORT.md](tb/poisson_delay/results/POISSON_DELAY_REPORT.md)
- Study mode: single-lane short-mode Poisson, `burst_size=1`, `noise=0`
- Raw offered-load reference: `1 hit / 3.5 cycles` per MuTRiG lane
- Timestamp contract under test:
  - default long-hit mode uses encoded `E` timestamp as the true hit commit time
  - encoded `T` timestamp is constrained to `T <= E`
  - `E_Flag` stays on the raw RTL-compatible default
- Measured shape:
  - at `10%` raw full rate, true `E-ts -> pop` latency spans almost one full short-frame window: `32 / 512.5 / 846.9 / 911.0 / 944.0` cycles for min / p50 / p90 / p99 / max
  - the low-load floor is about `32` cycles because the earliest read still sits behind the frame header and event-count bytes
  - at `100%` raw full rate, true `E-ts -> pop` latency stays mostly in `0.8 .. 1.15` frames: `793.0 / 895.0 / 936.0 / 982.0 / 1045.0` cycles for p01 / p50 / p90 / p99 / max
- Occupancy and throughput:
  - occasional FIFO-full cycles first appear around `60%` raw full rate, but the lane still tracks the offered rate closely through the mid-load points
  - at `100%` raw full rate, accepted throughput is `0.2698 hits/cycle`, or about `3.71 cycles / accepted hit`
- Interpretation:
  - the measured high-load distribution does not fill a full `0 .. 1820` cycle box at `<=100%` raw full rate
  - once a short frame is open, the packer keeps draining continuously inside that frame instead of behaving like a pure frame-boundary-gated queue

### Standalone 8-lane synthesis

- Compile:
  - `quartus_sh --flow compile emulator_mutrig_bank8_syn -c emulator_mutrig_bank8_syn`
- Result:
  - `3958 ALMs`
  - `3579` registers
  - `98,304` block memory bits
  - `16` RAM blocks
  - `0` DSP blocks
- Area target:
  - `PASS`, because `3958 < 4000`
- Tightened timing target:
  - `PASS`, because slow `85C` setup slack is `+0.139 ns` at `137.5 MHz`

## Notes

- The bank8 compile is the current standalone proof vehicle for the
  architect-requested `<4000 ALM / 8 lane` target.
- The single-lane packaged IP stays in place for Platform Designer integration.
- Continuous-frame and gate-level collateral were not rerun for this compact-bank refresh.
- `doc/SIGNOFF.md` is the master review page; the root
  [SIGNOFF.md](SIGNOFF.md) is only a pointer.
