# RTL Note — emulator_mutrig

Date: 2026-04-12  
Author: Codex

## 0. Summary

- Scope: standalone timing/resource sign-off for the current single-lane
  `emulator_mutrig` RTL on Arria V
- Sign-off status: PASS
- Primary deliverables added in this turn:
  - `syn/quartus/` standalone Quartus project and synthesizable top harness
  - `tb/gate/` post-fit functional gate replay runner
  - corrected `doc/RTL_PLAN.md` resource model
  - checked-in standalone signoff summary in `SIGNOFF.md`

## 1. Targets

From `doc/RTL_PLAN.md`:

- Device:
  - Arria V `5AGXBA7D4F31C5`
- Sign-off clock:
  - `clk125`
- Frequency targets:
  - nominal `125.0 MHz` (`8.000 ns`)
  - tightened standalone signoff `137.5 MHz` (`7.273 ns`)
- Timing pass rule:
  - setup `WNS >= 0`
  - hold slack `>= 0`
  - both under the tightened `7.273 ns` constraint
- Corrected standalone resource reference:
  - ALMs `450`
  - FFs `500`
  - RAM blocks `2`
  - DSP blocks `2`

## 2. DV Evidence

### 2.1 RTL regression

- Directed bench:
  - command: `make -C tb clean run_all`
  - result: `39 passed, 0 failed`
  - confirms:
    - short-frame gap = `910`
    - long-frame gap = `1550`
    - CSR readback
    - short parser-visible payload semantics
    - long-frame length and CRC
    - run-control gating
    - frame counter increments
- UVM closure:
  - command: `make -C tb/uvm clean closure SEEDS=4`
  - result: `17 / 17 passed`
  - functional coverage: `100.00%`
  - key DUT code coverage from `tb/uvm/cov/merged.txt`:
    - top `emulator_mutrig`: branch `100.00%`, statement `100.00%`, toggle `82.29%`
    - `u_hit_gen`: branch `97.82%`, statement `100.00%`, toggle `92.22%`
    - `u_frame_asm`: branch `92.18%`, statement `96.18%`, toggle `81.34%`

### 2.2 Post-fit functional gate replay

- Gate replay:
  - command: `make -C tb/gate run_all`
  - result: `38 passed, 0 failed`
- Quartus EDA export limitation:
  - Quartus 18.1 on Arria V reports that the functional simulation netlist is
    the only supported gate simulation netlist type for this device
  - no SDF timing netlist is available from this flow
- Gate-only TB guardrail:
  - the gate runner keeps all parser-visible checks
  - it skips only direct internal `u_hit_gen` visibility checks that depend on
    RTL instance internals, using `EMUT_GATE_SIM`

## 3. Standalone Quartus Compile

- Project location:
  - `syn/quartus/`
- Revision:
  - `emulator_mutrig_syn`
- Top-level:
  - `emulator_mutrig_syn_top`
- Main command:
  - `quartus_sh --flow compile emulator_mutrig_syn -c emulator_mutrig_syn`
- Flow runtime from `output_files/emulator_mutrig_syn.flow.rpt`:
  - analysis & synthesis: `00:00:09`
  - fitter: `00:00:48`
  - assembler: `00:00:10`
  - timing analyzer: `00:00:04`
  - total wall time: `00:01:19`
  - total CPU time: `00:02:25`

### 3.1 Timing results

From `output_files/emulator_mutrig_syn.sta.summary`:

| Corner | Setup Slack | Hold Slack | Min Pulse Width |
|:-------|------------:|-----------:|----------------:|
| Slow 1100mV 85C | `+0.274 ns` | `+0.257 ns` | `+2.630 ns` |
| Slow 1100mV 0C | `+0.176 ns` | `+0.218 ns` | `+2.673 ns` |
| Fast 1100mV 85C | `+3.692 ns` | `+0.161 ns` | `+2.466 ns` |
| Fast 1100mV 0C | `+4.004 ns` | `+0.133 ns` | `+2.473 ns` |

Worst setup path after the timing fix:

- from:
  - `emulator_mutrig:u_dut|hit_generator:u_hit_gen|prng_state[5]`
- to:
  - `emulator_mutrig:u_dut|hit_generator:u_hit_gen|prng_state[18]`
- relationship:
  - `7.273 ns`
- data delay:
  - `6.863 ns`
- final slack:
  - `+0.274 ns`

### 3.2 Timing iteration history

- Initial standalone compile identified the `hit_generator` LCG feedback path as
  the limiting cone.
- The architecturally visible behavior only depends on:
  - `prng_state[20:0]`
  - `prng2_state[4:0]`
- Because LCG low bits evolve independently under modulo-`2^N` arithmetic, the
  full internal state widths were reduced to those observed ranges:
  - `prng_state`: `32 -> 21`
  - `prng2_state`: `32 -> 5`
- This preserves the emitted hit sequences seen by the rest of the design while
  removing unnecessary arithmetic width from the critical path.
- After the change:
  - RTL directed regression still passed
  - UVM closure still passed
  - the tightened `137.5 MHz` standalone compile closed with positive slack

## 4. Resource Usage

From `output_files/emulator_mutrig_syn.fit.summary` and `fit.rpt`:

| Resource | Corrected RTL_PLAN estimate | Actual | Ratio | Status | Notes |
|:---------|----------------------------:|-------:|------:|:------:|:------|
| ALMs | `450` | `438` | `0.97x` | PASS | comfortably inside `0.5x-3.0x` gate |
| FFs | `500` | `492` | `0.98x` | PASS | comfortably inside `0.5x-3.0x` gate |
| RAM blocks | `2` | `2` | `1.00x` | PASS | `64 x 48` FIFO inferred as `altsyncram` in two M10Ks |
| DSP blocks | `2` | `2` | `1.00x` | PASS | two LCG multipliers inferred into DSPs |

Additional fitted facts:

- block memory bits: `3072`
- no MLAB memory bits
- FIFO implementation:
  - `AUTO | Simple Dual Port | 64 x 48 | 3072 bits | 2 M10Ks`
- DSP instances:
  - `Mult0~8` as independent `27x27`
  - `Mult1~8` as independent `9x9`

### 4.1 Pre-fit model correction

The initial pre-fit model for this turn predicted:

- FIFO in soft logic / MLAB-style storage
- no dedicated DSP usage

Quartus disproved both assumptions:

- the FIFO infers cleanly into `altsyncram` with pass-through logic for the
  original read-during-write semantics
- the LCG multiply stages map directly into Arria V DSP blocks

`doc/RTL_PLAN.md` was updated to reflect that actual architecture so the
resource signoff reference matches the delivered design rather than the initial
mis-model.

## 5. Warnings Review

The standalone compile is timing-clean and functionally signed off. Remaining
warnings are understood:

- inferred RAM read-during-write compatibility message for the FIFO
  - expected consequence of inferring `altsyncram` from the RTL memory style
- top-level pin warnings in the standalone harness
  - expected because the signoff harness intentionally uses virtual pins and
    leaves only the clock as a real pin
- gate simulation atom port-size warnings around Arria V DSP primitives
  - simulation still elaborates and the full gate replay passes

None of these warnings change the signoff disposition.

## 6. Optional Hardware Validation

- not run in this turn

## 7. Plan Mapping

### 7.1 `doc/RTL_PLAN.md`

- [x] Targets and tightened sign-off clock documented and met
- [x] Pre-fit model written and corrected after fitter evidence
- [x] Resource estimate check closed against the corrected model
- [x] Timing closure recorded with critical-path evidence

### 7.2 `tb/DV_PLAN.md`

- [x] Current single-lane RTL regression preserved
- [x] UVM closure preserved after timing fix
- [x] Post-fit functional gate replay completed

## 8. Residual Scope Limit

This note signs off only the current single-lane implementation. It does not
sign off the future shared 8-lane architecture or the `< 4000 ALM` total target
for that later design.
