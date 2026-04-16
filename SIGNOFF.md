# Standalone Signoff: emulator_mutrig

Status: `PASS`

This signoff closes the current single-lane `emulator_mutrig` RTL against its
checked-in DV plan and standalone Quartus timing/resource targets. It does not
cover the future shared 8-lane `< 4000 ALM` architecture; that remains a later
design phase.

## Scope

- DUT: `emulator_mutrig`
- Version family: `26.0.3`
- Device: Arria V `5AGXBA7D4F31C5`
- Quartus: `18.1.0 Build 625 Standard Edition`
- Nominal byte-clock target: `125.0 MHz`
- Tightened standalone signoff clock: `137.5 MHz` (`7.273 ns`)

Supporting documents:

- [doc/RTL_PLAN.md](doc/RTL_PLAN.md)
- [doc/rtl_note.md](doc/rtl_note.md)
- [tb/DV_PLAN.md](tb/DV_PLAN.md)

## Verification Signoff

### 2026-04-16 refresh

- Directed bench rerun: `make -C tb run_all`
  - result: `40 passed, 0 failed`
  - includes the new `T09_terminate_no_new_frame` regression for the run-sequence patch
- UVM regression rerun: `make -C tb/uvm regress SEEDS=1`
  - result: `15 / 15 passed`
  - includes the new `emut_test_terminate_no_new_frame` regression plus the existing mode/inject/status coverage smoke
- Gate-level replay:
  - not rerun in this refresh pass
  - the previously recorded gate-replay evidence below remains the last checked-in gate result for this IP

### RTL regression

- Directed bench: `make -C tb clean run_all`
  - result: `39 passed, 0 failed`
  - checks include short-gap=`910`, long-gap=`1550`, CSR readback, parser-visible
    short-word semantics, long-frame packing, run control, and frame counters
- UVM closure: `make -C tb/uvm clean closure SEEDS=4`
  - result: `17 / 17 passed`
  - functional coverage: `100.00%`
  - DUT code coverage:
    - top `emulator_mutrig`: branch `100.00%`, statement `100.00%`, toggle `82.29%`
    - `u_hit_gen`: branch `97.82%`, statement `100.00%`, toggle `92.22%`
    - `u_frame_asm`: branch `92.18%`, statement `96.18%`, toggle `81.34%`

### Gate-level replay

- Post-fit functional gate replay: `make -C tb/gate run_all`
  - result: `38 passed, 0 failed`
  - replay uses the Quartus post-fit functional simulation netlist in
    `syn/quartus/gate_sim`
- Arria V / Quartus 18.1 limitation:
  - Quartus reports that the functional netlist is the only supported gate
    simulation netlist type for this device
  - no SDF timing-annotated netlist is available from this flow, so the gate
    signoff evidence is post-fit functional replay rather than post-fit timing
    simulation
- Gate-only observability note:
  - the directed bench keeps all externally visible parser checks
  - only direct internal `u_hit_gen` visibility checks are skipped under
    `EMUT_GATE_SIM`, because those internal RTL names do not exist in the netlist

## Timing Signoff

Standalone compile:

- project: `syn/quartus/emulator_mutrig_syn`
- top: `emulator_mutrig_syn_top`
- command:
  - `quartus_sh --flow compile emulator_mutrig_syn -c emulator_mutrig_syn`
- flow runtime from `output_files/emulator_mutrig_syn.flow.rpt`:
  - wall time `00:01:28`
  - total CPU time `00:02:43`

Timing summary from
[syn/quartus/output_files/emulator_mutrig_syn.sta.summary](syn/quartus/output_files/emulator_mutrig_syn.sta.summary):

| Corner | Setup Slack | Hold Slack | Min Pulse Width |
|--------|------------:|-----------:|----------------:|
| Slow 1100mV 85C | `+0.140 ns` | `+0.251 ns` | `+2.635 ns` |
| Slow 1100mV 0C | `+0.012 ns` | `+0.229 ns` | `+2.682 ns` |
| Fast 1100mV 85C | `+3.758 ns` | `+0.159 ns` | `+2.468 ns` |
| Fast 1100mV 0C | `+3.937 ns` | `+0.135 ns` | `+2.473 ns` |

Worst signoff path after the final timing fix:

- `hit_generator:u_hit_gen|prng_state[5] -> prng_state[18]`
- launch/latch clock: `clk125`
- relationship: `7.273 ns`
- data delay: `7.261 ns`
- slack: `+0.012 ns`

Interpretation:

- timing passes under the required tightened `137.5 MHz` standalone constraint
- the limiting cone remains the PRNG feedback arithmetic in `u_hit_gen`
- the delivered timing fix was to reduce the internal LCG state widths to the
  architecturally observed modulo-`2^N` ranges, which preserves the emitted hit
  sequences while removing unnecessary arithmetic width from the critical path

## Resource Signoff

Fitter summary from
[syn/quartus/output_files/emulator_mutrig_syn.fit.summary](syn/quartus/output_files/emulator_mutrig_syn.fit.summary):

| Resource | Corrected RTL_PLAN estimate | Actual | Ratio | Status |
|----------|----------------------------:|-------:|------:|:------:|
| ALMs | `450` | `443` | `0.98x` | PASS |
| Registers | `500` | `495` | `0.99x` | PASS |
| RAM blocks | `2` | `2` | `1.00x` | PASS |
| DSP blocks | `2` | `2` | `1.00x` | PASS |

Additional fitter facts:

- block memory bits: `3072`
- FIFO maps to `altsyncram` as a `64 x 48` single-clock simple dual-port RAM
  using `2` M10Ks
- the two PRNG multipliers map to `Independent 27x27` and `Independent 9x9`
  Arria V DSP instances

## Residual Limits

- This signoff is only for the current single-lane DUT.
- The future shared 8-lane area target from `tb/DV_PLAN.md`
  (`< 4000 ALMs total`) is not signed off here.

## Conclusion

The current standalone `emulator_mutrig` implementation is signed off for:

- directed RTL regression
- UVM closure against `tb/DV_PLAN.md`
- post-fit functional gate replay
- standalone Quartus timing closure at `137.5 MHz`
- standalone resource closure against the corrected `doc/RTL_PLAN.md` model
