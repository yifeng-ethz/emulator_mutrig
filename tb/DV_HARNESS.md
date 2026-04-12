# DV Harness Plan: emulator_mutrig

**Target:** `emulator_mutrig`
**Phase:** Architecture definition for signoff
**Date:** 2026-04-12

## 1. Harness Goals

The harness must make these properties observable:
- CSR programming correctness
- run-control window behavior
- `inject` pulse capture and edge-use correctness
- exact `tx8b1k` frame structure
- frame-to-frame status counter coherence
- protocol correctness on Avalon-MM / Avalon-ST boundaries
- realistic trigger-to-hit timing with tunable delay parameters
- realistic trigger-to-merged-hit timing for the future shared 8-lane architecture
- functional equivalence between the future shared datapath and 8 golden single-lane references

The harness should preserve the current directed smoke test while adding a future-proof UVM layer.

It is explicitly split across:
- the current **single-lane baseline**
- the future **8-lane merged/shared datapath**

Control SPI remains out of scope. The future 8-lane implementation must be observable enough that its functional regressions can be paired with a Quartus `<4000 ALM` signoff build.

## 2. Planned Directory Layout

```text
tb/
  Makefile                  # directed smoke runner with Mentor-license gate
  tb_emulator_mutrig.sv     # existing deterministic bench retained for smoke
  DV_PLAN.md
  DV_HARNESS.md
  DV_BASIC.md
  DV_EDGE.md
  DV_PROF.md
  DV_ERROR.md
  DV_CROSS.md
  uvm/
    Makefile
    tb_top.sv
    emut_env_pkg.sv
    emut_env.sv
    emut_csr_agent/
    emut_ctrl_agent/
    emut_inject_agent/
    emut_tx8b1k_agent/
    emut_scoreboard.sv
    emut_coverage.sv
    emut_base_test.sv
    tests/
    sequences/
    sva/
      emut_avmm_sva.sv
      emut_ctrl_avst_sva.sv
      emut_tx8b1k_sva.sv
      emut_internal_sva.sv
```

## 3. Agent Model

### 3.1 CSR Agent

Protocol:
- Avalon-MM master toward the DUT `csr` slave

Responsibilities:
- apply all configuration writes
- read back status and CSR state
- model waitrequest timing correctly
- own register field abstractions for the current CSR map

Transaction content:
- address
- kind: read / write
- write data
- expected read data mask/value

### 3.2 Run-Control Agent

Protocol:
- Avalon-ST source toward `ctrl`

Responsibilities:
- drive one-hot run-state words
- create legal and illegal state sequences
- control start/stop windows for all traffic scenarios

Transaction content:
- run state value
- valid pulse spacing
- sequence label: legal path / abrupt stop / chatter / illegal overlap

### 3.3 Inject Agent

Protocol:
- single-bit conduit source toward `inject`

Responsibilities:
- generate pulse trains aligned and misaligned to the byte clock
- stress the synchronizer / edge detector behavior
- coordinate with run-control windows and CSR mode selection
- sweep realistic trigger-to-hit timing parameters across min/mid/max values

Transaction content:
- pulse count
- pulse spacing
- phase offset versus the DUT clock
- burst label: isolated / clustered / chatter
- programmed delay setting used for the pulse train

### 3.4 tx8b1k Monitor Agent

Protocol:
- passive monitor on `tx8b1k`

Responsibilities:
- reconstruct frames from `K28.0 ... K28.4`
- separate long-mode payloads from short-mode packed payloads
- capture channel and error sidebands alongside the byte stream
- publish frame transactions to scoreboard and coverage
- record first-hit and merged-hit observation timestamps for timing closure

Frame transaction fields:
- start timestamp
- frame count
- event count
- tx mode
- idle-generation expectation
- payload bytes
- CRC bytes
- trailer presence
- channel tag
- error bits
- observed trigger-to-first-hit latency
- observed trigger-to-merged-hit latency when applicable

### 3.5 Shared 8-Lane Merge Monitor

For the future resource-optimized implementation, a passive merge/output monitor must observe:
- merged timestamp order
- lane ID provenance
- lane-local configuration identity
- queue/arbiter latency behavior

This monitor allows the shared implementation to be compared against 8 parallel single-lane golden references instead of being checked only structurally.

## 4. Scoreboard Model

The scoreboard is split into four layers:

1. **CSR expectation layer**
   - mirrors programmed configuration
   - predicts mode, idle behavior, and counter expectations

2. **Frame parser layer**
   - decodes the observed `tx8b1k` stream
   - identifies headers, frame count, event count, payload, CRC, and trailer
   - flags malformed framing immediately

3. **Reference consistency layer**
   - checks CRC against a software model
   - checks frame count monotonicity during `RUNNING`
   - checks channel tag equals `asic_id`
   - checks idle-comma behavior outside active output windows
   - checks mode-dependent payload length rules

4. **Shared-datapath equivalence layer**
   - instantiates 8 golden single-lane predictors in software
   - merges their expected hit streams by timestamp
   - compares the merged hardware output against the software-merged golden stream

The scoreboard does **not** attempt to predict exact Poisson hit contents for arbitrary seeds. Instead it checks:
- structural correctness
- configuration consistency
- reproducibility for fixed-seed deterministic subsets
- legal bounds on event count and payload length
- merge-order correctness for shared-resource implementations

### 4.1 Seed Management Policy

Deterministic reproducibility is required for signoff bundles.

Baseline policy:
- the CSR-visible `PRNG_SEED` value is part of every recorded stimulus transaction
- each regression stores the explicit seed used for each test

Future shared 8-lane policy:
- each lane must have a lane-local seed identity
- the default deterministic mapping is `lane_seed = base_seed ^ lane_id`
- any alternative mapping must be documented and mirrored in the golden reference model

## 5. Planned SVA Modules

### 5.1 `emut_avmm_sva.sv`

Checks:
- no simultaneous CSR read and write from the testbench driver
- waitrequest handshake consistency
- readdata stability during accepted reads
- no X/Z on CSR-visible signals

### 5.2 `emut_ctrl_avst_sva.sv`

Checks:
- `asi_ctrl_data` stable while `valid` is asserted
- driver does not produce X/Z run-state words
- legal one-hot expectation in positive tests

### 5.3 `emut_tx8b1k_sva.sv`

Checks:
- `tx8b1k_data`, `channel`, and `error` stable when sampled with `valid`
- K characters appear only at legal framing points in clean scenarios
- trailer cannot appear before header
- output sideband widths remain known and stable

### 5.4 `emut_internal_sva.sv`

Checks:
- frame counter only increments on frame boundaries
- status event count updates only when a frame starts
- output is comma-idle when not running or disabled
- synchronizer output pulse is single-cycle wide in the destination clock

## 6. Coverage Plan

Detailed crosses live in [DV_CROSS.md](/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/emulator_mutrig/tb/DV_CROSS.md:1). The harness must expose coverage on:
- CSR programming categories
- run-state transitions
- output mode families
- long vs short payload packing
- inject pulse phase categories
- frame length / event count bins
- frame counter and status coherence
- active-lane-count bins
- timestamp tie-degree bins
- lane-tie-winner bins
- trigger-to-hit and trigger-to-merged-hit latency bins

The planned [emut_coverage.sv](/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/emulator_mutrig/tb/uvm/emut_coverage.sv) file is the collector that will own:
- the DV_CROSS coverpoints and crosses
- latency histograms for trigger-to-hit and trigger-to-merged-hit timing
- summary counters for tie winners, active-lane populations, and interval violations

## 7. Directed-to-UVM Migration Strategy

The existing directed bench remains the first gate:
1. `make compile`
2. `make run TEST=<smoke>`
3. `make run_all`

After signoff, the UVM build should come in stages:
1. `tb_top.sv` plus passive tx8b1k monitor
2. CSR active agent
3. run-control active agent
4. inject active agent
5. scoreboard and CRC reference model
6. coverage and SVA binds
7. randomized sequences mapped to `DV_BASIC`, `DV_EDGE`, `DV_PROF`, and `DV_ERROR`

## 8. Risks To Watch

1. Short-mode payload packing is the highest decode-risk area in the monitor and scoreboard.
2. Poisson / mixed modes are probabilistic, so exact-payload prediction must be limited to seeded deterministic subsets.
3. The `inject` input is asynchronous by intent, so phase-bin coverage is required rather than only synchronous pulses.
4. The future packaging-standard CSR shift (`UID + META`) will require the CSR agent and all plan references to be versioned carefully.
5. The `<4000 ALM` 8-lane target may drive aggressive resource sharing; the scoreboard and coverage model must be strong enough that area optimizations cannot hide functional regressions.

## 9. Implementation Gate

This file is architecture-only. No UVM code or RTL changes should start until the chief architect signs off the harness contract in this document together with the case files.
