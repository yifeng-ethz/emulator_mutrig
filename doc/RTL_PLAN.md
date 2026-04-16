# Emulator MuTRiG — RTL Design Plan

**IP Name:** emulator_mutrig
**Author:** Codex
**Version:** 26.0.3
**Integration Target:** Mu3e online datapath / `frame_rcv_ip` sink
**Companion Documents:** `README.md`, `tb/DV_PLAN.md`, `doc/rtl_note.md`

---

## 1. Scope

`emulator_mutrig` is a single-lane MuTRiG digital-output emulator. It models the MuTRiG packet stream at a `125 MHz` FPGA-facing byte-clock boundary while representing a native MuTRiG datapath that is effectively observed at `625 MHz`.

This plan covers standalone sign-off for the current single-lane RTL, while also documenting the delivered multi-lane cluster-domain hook that lets neighbouring emulator instances replay one shared global cluster without changing the single-lane default datapath.

The current delivered revision also closes the run-sequence timing-model gap from `RUN_SEQ_UPGRADE_PLAN.md` by preventing a fresh frame start once `RUNNING` has closed and the emulator is only draining through `TERMINATING`.

---

## 2. Sign-Off Targets

### 2.1 Device

- **FPGA family:** Arria V
- **Device:** `5AGXBA7D4F31C5`
- **Quartus edition:** Quartus Prime Standard 18.1

### 2.2 Clock Targets

- **Architectural byte clock (`F_target_MHz`):** `125.0 MHz`
- **Architectural period:** `8.000 ns`
- **Standalone sign-off clock (`F_signoff_MHz`):** `137.5 MHz`
- **Standalone sign-off period (`Tclk_signoff`):** `7.273 ns`

Hard timing gate for standalone sign-off:

- setup `WNS >= 0`
- hold slack `>= 0`
- both checked against the tightened `7.273 ns` standalone clock

### 2.3 DV Target

DV closure for the current single-lane DUT is defined by `tb/DV_PLAN.md` and the associated UVM closure run in `tb/uvm/`.

### 2.4 Area Target

There are two area references:

1. **Current standalone sign-off reference for the existing single-lane RTL**
2. **Future architectural goal** from `tb/DV_PLAN.md`: eight emulated MuTRiG lanes should fit in **< 4000 ALMs total** after datapath sharing

This plan signs off only reference (1). Reference (2) remains an explicit future architecture task.

---

## 3. RTL Architecture

### 3.1 Top-Level Blocks

`emulator_mutrig.sv`

- CSR bank and run-control decode
- two `prbs15_lfsr` instances for coarse time references
- `hit_generator`
- `frame_assembler`

`hit_generator.sv`

- modulo-equivalent reduced-width LCG PRNG datapaths
- channel scan / burst / noise mode control
- Poisson and mixed-mode cluster emission when `burst_size > 1`
- optional cross-ASIC cluster slicing via `cluster_cross_asic`, `cluster_lane_index`, and `cluster_lane_count`
- raw-style queue topology: 4 L1 FIFOs (`78` bit) plus 1 shared L2 FIFO (`48` bit)
- injection-pulse-to-burst trigger path

`frame_assembler.sv`

- frame interval counter
- framing FSM
- short/long packet packing
- CRC16 update path

### 3.2 Ownership / Register Boundaries

- CSR and run-control ownership is in `emulator_mutrig.sv`
- hit scheduling, PRNG state, FIFO write, and FIFO occupancy ownership is in `hit_generator.sv`
- frame timing, FIFO drain cadence, byte packing, and CRC ownership is in `frame_assembler.sv`

No cross-module same-cycle feedback loop should exist other than the intended FIFO show-ahead read path from `hit_generator` into `frame_assembler`.

---

## 4. Pre-Fit Synthesis Model

### 4.1 Expected Resource Mapping

| Block | Intended implementation | Notes |
|:------|:------------------------|:------|
| PRBS coarse counters | FFs + XOR | Two 15-bit LFSRs |
| CSR bank / status | FFs + small mux/compare logic | Small footprint |
| Hit PRNG and mode control | FFs + ALMs + 2 small DSP multipliers | Reduced-width LCG update datapaths and threshold compares |
| Hit FIFO (`64 x 48`) | Dedicated simple dual-port RAM | Quartus is expected to infer an `altsyncram` with pass-through logic for the read-during-write behavior |
| Frame packing / shift register | FFs + ALMs | Byte shifter and control FSM |
| CRC16 datapath | ALMs + FFs | 8-bit combinational next-state + 16-bit state register |

### 4.2 Expected Timing Bottlenecks

Primary expected setup bottlenecks:

1. `hit_generator` PRNG feedback path, where the LCG multiply/add result returns into the `prng_state` owner registers
2. `frame_assembler` short-pack / `FS_PACK` / `FS_PACK_EXTRA` control, where FIFO data selection, short-hit repacking, byte-count control, and event bookkeeping interact in one cycle
3. CRC16 next-state logic in cycles where `out_byte` is selected and fed into the CRC state update

Secondary expected bottlenecks:

1. CSR readback muxing
2. frame interval compare / reload logic

Expected hold risk is low because the design is single-clock and locally registered. The only non-clock async control is `i_rst`, which will be constrained as false-path reset in the standalone SDC.

---

## 5. Standalone Resource Estimates

These are the reference estimates for the **current single-lane implementation** at `FIFO_DEPTH=256`.

The first pre-fit model for this turn assumed the FIFO would stay in soft logic and the LCG math would stay out of DSPs. The fitted result disproved that assumption: Quartus infers the `64 x 48` FIFO as a simple dual-port `altsyncram` in `2` M10Ks and maps the two reduced-width multipliers into `2` DSP blocks. The table below is therefore the corrected sign-off reference for this delivered revision.

| Resource | Estimate | Basis |
|:---------|:---------|:------|
| ALMs | `450` | Corrected after fitter evidence; current single-lane control/data path fits well below the later `< 4000 ALM / 8 lanes` architectural goal |
| FFs | `500` | CSR, PRNG state, frame FSM/state, shift/CRC state, counters, and FIFO control |
| RAM blocks | `2` | `64 x 48` FIFO inferred as simple dual-port `altsyncram` using two M10Ks |
| DSP blocks | `2` | Two reduced-width LCG multipliers map naturally into independent Arria V DSP blocks |

Pass/fail rule for standalone resource sign-off:

- `0.5x <= actual / estimate <= 3.0x` for ALMs and FFs
- RAM blocks and DSP blocks must match the intended dedicated-resource architecture recorded above

---

## 6. Standalone Quartus Project Plan

Project location:

- `syn/quartus/`

Project strategy:

- use a thin standalone wrapper around the DUT
- keep all DUT-facing stimulus ports as wrapper top-level ports so fitter results remain representative of the DUT instead of a synthetic traffic generator
- mark all wrapper pins as virtual pins
- constrain only the real byte clock

Timing-impacting Quartus policy:

- `FITTER_EFFORT = "STANDARD FIT"`
- router timing optimization at maximum
- physical synthesis for combo logic, register duplication, and retiming enabled at normal effort
- no seed scan

---

## 7. Verification Mapping

`tb/DV_PLAN.md` is the functional closure contract for this revision. The standalone timing/resource sign-off must not invalidate that DV-closed single-lane behavior.

Specific behavioral points relevant to synthesis sign-off:

- short frame interval = `910` cycles at the `125 MHz` byte-clock boundary
- long frame interval = `1550` cycles at the `125 MHz` byte-clock boundary
- short payload semantics use `TCC/T_Fine`, not `ECC/E_Fine`
- injection pulse path must remain functional through the resynchronizer and burst trigger path
- cross-ASIC burst slicing must reduce a shared global cluster to the correct local 32-channel window when enabled

---

## 8. Open Architectural Item Not Covered By This Sign-Off

This document does **not** sign off the future shared-datapath 8-lane area-reduced implementation. When that work starts, this file must be revised with:

- the shared-lane architecture description
- new per-block resource estimates
- the explicit proof path for the `< 4000 ALM / 8 lanes` target
