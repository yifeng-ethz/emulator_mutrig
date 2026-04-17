# MuTRiG Emulator (`emulator_mutrig`)

Compact FPGA MuTRiG output emulator for the Mu3e datapath. The packaged IP
`emulator_mutrig` remains the single-lane compatibility block; the standalone
area study for this refresh is `rtl/emulator_mutrig_bank8.sv`, which merges
eight lanes behind shared run-control, inject sync, and coarse counters.

## Active Release

- Release: `26.1.1.0417`
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
- two DSP-backed PRNG multiply paths

## Current Results

### Functional

- Directed smoke: `make -C tb run_all` -> `49 passed, 0 failed`
- UVM isolated regression: `make -C tb/uvm regress SEEDS=1` -> `15 / 15 passed`
- Coverage refresh: `make -C tb/uvm clean closure SEEDS=1`
- Key DUT coverage from `tb/uvm/cov/merged.txt`:
  - top `dut`: branch `100.00%`, statement `100.00%`, toggle `78.34%`
  - `u_hit_gen`: branch `71.08%`, statement `85.09%`, toggle `85.98%`
  - `u_frame_asm`: branch `93.05%`, statement `96.03%`, toggle `86.27%`

### Poisson delay characterization

- Sweep report: [tb/poisson_delay/results/POISSON_DELAY_REPORT.md](tb/poisson_delay/results/POISSON_DELAY_REPORT.md)
- Study mode: single-lane short-mode Poisson, `burst_size=1`, `noise=0`
- Raw offered-load reference: `1 hit / 3.5 cycles` per MuTRiG lane
- Measured knee:
  - no FIFO saturation through `80%` raw offered load
  - saturation starts around `90%` raw offered load
- Sustained accepted rate near saturation:
  - about `0.259 hits/cycle`
  - about `3.86 cycles / accepted hit`
- Interpretation:
  - the apparent latency drop above `90%` is not a real service-speed gain
  - once the FIFO stays near full, the measured distribution is biased toward
    the hits that still get accepted

### Standalone 8-lane synthesis

- Compile:
  - `quartus_sh --flow compile emulator_mutrig_bank8_syn -c emulator_mutrig_bank8_syn`
- Result:
  - `3398 ALMs`
  - `2927` registers
  - `94,208` block memory bits
  - `16` RAM blocks
  - `16` DSP blocks
- Area target:
  - `PASS`, because `3398 < 4000`
- Tightened timing target:
  - `PARTIAL`, because slow `85C` setup slack is `-0.544 ns` at `137.5 MHz`

## Notes

- The bank8 compile is the current standalone proof vehicle for the
  architect-requested `<4000 ALM / 8 lane` target.
- The single-lane packaged IP stays in place for Platform Designer integration.
- `doc/SIGNOFF.md` is the master review page; the root
  [SIGNOFF.md](SIGNOFF.md) is only a pointer.
