# DV Plan: emulator_mutrig

**DUT:** `emulator_mutrig`
**RTL baseline:** `emulator_mutrig/rtl/emulator_mutrig.sv`
**Date:** 2026-04-12
**Methodology:** Directed smoke bench plus planned UVM 1.2 environment under the Claude `dv-workflow`
**Status:** Phase 0 planning package for signoff

## 1. Scope

This plan covers two verification targets:

1. the current **standalone single-lane baseline** in `rtl/emulator_mutrig.sv`
2. the intended future **shared 8-lane / merged-datapath MuTRiG emulator** that may share counters, packetization, merge logic, or other datapath resources

Common in-scope behavior:
- run-control timing on a 9-bit Avalon-ST sink
- CSR-visible configuration semantics
- a single-bit `inject` pulse input with realistic, tunable timing behavior
- MuTRiG-format output frames on `tx8b1k`

Explicitly out of scope:
- control SPI protocol
- analog front-end behavior
- board-level PHY / LVDS behavior

The verification target is the emulator family itself, not the full SciFi datapath system.

This plan intentionally stops at the **DV signoff gate**. No RTL-changing packaging work should start until the chief architect signs off the Phase 0 plan set listed below.

## 2. Verification Objectives

1. Prove CSR programming produces the intended run-time behavior for hit generation, framing, and channel tagging.
2. Prove the output byte stream is MuTRiG-format correct in long, short, PRBS-single, and PRBS-saturating modes.
3. Prove run-control gating prevents non-idle output outside `RUNNING`.
4. Prove the datapath timing model is realistic, not just structurally framed.
5. Prove `inject` pulses are safely re-synchronized and drive a realistic, tunable injection-trigger timing model.
6. Prove status counters and frame accounting stay coherent across start/stop windows.
7. Prove a future shared 8-lane merged datapath remains functionally equivalent to 8 golden single-lane references.
8. Treat the `< 4000 ALM` total area target for 8 lanes as a Phase 0 signoff gate.

## 3. DUT Summary

### 3.1 Major Blocks

| Block | File | Function |
|---|---|---|
| `emulator_mutrig` | `rtl/emulator_mutrig.sv` | Top-level Avalon / conduit wrapper and CSR bank |
| `hit_generator` | `rtl/hit_generator.sv` | Hit generation for Poisson, burst, noise, and mixed modes |
| `frame_assembler` | `rtl/frame_assembler.sv` | Byte-stream framing, CRC insertion, header/trailer generation |
| `prbs15_lfsr` | `rtl/prbs15_lfsr.sv` | Coarse timestamp generator |
| `crc16_8` | `rtl/crc16_8.sv` | Byte-wise CRC-16 |
| `emulator_mutrig_pkg` | `rtl/emulator_mutrig_pkg.sv` | Constants and pack helpers |

### 3.2 Interfaces

| Interface | Type | Direction | Notes |
|---|---|---|---|
| `data_clock` | clock | sink | Single synchronous byte-clock domain |
| `data_reset` | reset | sink | Synchronous reset into the byte-clock domain |
| `ctrl` | Avalon-ST | sink | 9-bit one-hot run-control bus |
| `csr` | Avalon-MM | slave | 32-bit word CSR interface |
| `inject` | conduit | sink | Single-bit pulse input re-synchronized in RTL |
| `tx8b1k` | Avalon-ST | source | 9-bit `{is_k,data[7:0]}` MuTRiG byte stream with channel/error sidebands |

### 3.3 Architectural Direction Beyond The Baseline

The chief-architect requirement is that a total of 8 MuTRiG emulator lanes should fit in **less than 4000 ALM**. This is expected to require sharing or merging datapath resources instead of instantiating 8 fully standalone replicas.

Therefore the Phase 0 plan must validate both:
- the correctness of the current standalone lane
- the equivalence and timing realism of a future shared 8-lane implementation

### 3.4 Timing Source-Of-Truth

The checked-in RTL currently uses these frame-timing constants in [emulator_mutrig_pkg.sv](/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/emulator_mutrig/rtl/emulator_mutrig_pkg.sv:24):
- long frame interval: `1550` byte clocks
- short frame interval: `910` byte clocks

Per architect correction on 2026-04-12:
- the native MuTRiG datapath runs at `625 MHz`
- this emulator boundary should model it at `125 MHz`
- the long-frame period at the emulator boundary should be `1550` byte-clock cycles
- the short-frame period at the emulator boundary should be `910` byte-clock cycles as observed on the datapath

Therefore Phase 0 now treats both `1550` and `910` byte-clock frame intervals as implemented signoff intent at the 125 MHz emulator boundary.

### 3.5 Current Directed Smoke Bench

The checked-in file [tb_emulator_mutrig.sv](/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/emulator_mutrig/tb/tb_emulator_mutrig.sv:1) already provides a useful deterministic smoke layer:
- `B01_lfsr`
- `B02_empty_frame`
- `B03_single_long`
- `B04_short_interval`
- `B05_csr`
- `T01_multi_long`
- `T06_runctl`
- `T07_frame_counter`
- `T08_asic_id`
- `E03_back2back`

That bench remains valuable as the first compile/run gate, but it is not sufficient for DV closure under the `dv-workflow` standard.

## 4. Planned Verification Architecture

The detailed harness contract is defined in [DV_HARNESS.md](/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/emulator_mutrig/tb/DV_HARNESS.md:1).

High-level architecture:

```text
CSR agent        ─┐
Run-control agent ├─> DUT emulator_mutrig ──> tx8b1k monitor ──> frame parser ──> scoreboard
Inject agent     ─┘

SVA binders observe:
- AVMM protocol
- AVST control handshake
- tx8b1k framing invariants
- internal state / counter consistency where practical
```

Two verification layers are planned:
- `tb/` directed smoke bench for deterministic bring-up and quick regression
- `tb/uvm/` UVM environment for randomized, long-running, coverage-driven verification

## 5. Phase 0 Signoff Files

This plan package is split as follows:

| File | Purpose |
|---|---|
| [DV_PLAN.md](/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/emulator_mutrig/tb/DV_PLAN.md:1) | Top-level plan, DUT scope, objectives, and signoff gate |
| [DV_HARNESS.md](/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/emulator_mutrig/tb/DV_HARNESS.md:1) | UVM architecture, agent topology, scoreboard model, SVA plan |
| [DV_BASIC.md](/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/emulator_mutrig/tb/DV_BASIC.md:1) | 128 deterministic feature-completion cases |
| [DV_EDGE.md](/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/emulator_mutrig/tb/DV_EDGE.md:1) | 128 corner/boundary cases |
| [DV_PROF.md](/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/emulator_mutrig/tb/DV_PROF.md:1) | 128 stress/performance/soak cases |
| [DV_ERROR.md](/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/emulator_mutrig/tb/DV_ERROR.md:1) | 128 reset/fault/protocol-negative cases |
| [DV_CROSS.md](/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/emulator_mutrig/tb/DV_CROSS.md:1) | Functional cross-coverage contract |

## 6. Coverage Targets

Planned closure targets:
- statement coverage: `>95%`
- branch coverage: `>90%`
- toggle coverage: `>80%` on DUT-visible state/control/output signals
- functional coverage: `>95%` for named covergroups and crosses in `DV_CROSS.md`
- SVA: zero unexpected assertion failures in clean regressions
- Quartus resource evidence showing the exact 8-lane signoff top synthesizes to **`< 4000 ALM`**

## 7. Signoff Gate

Per the Claude `dv-workflow`, implementation must stop here until the chief architect signs off:
- the split plan set
- the planned UVM harness contract
- the case taxonomy
- the coverage contract

Only after signoff may we:
1. build the UVM scaffold,
2. migrate to randomized coverage collection,
3. implement the shared 8-lane / merged-datapath resource-optimized architecture,
4. and then return to the RTL-affecting IP-packaging todo list.
