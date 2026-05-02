# tb_int DV — Integration BASIC Cases

**Companion docs:** [DV_PLAN.md](DV_PLAN.md), [DV_HARNESS.md](DV_HARNESS.md), [DV_REPORT.md](DV_REPORT.md), [BUG_HISTORY.md](BUG_HISTORY.md)

**Parent:** [DV_PLAN.md](DV_PLAN.md)
**ID Range:** INTB001-INTB999
**Total:** 32 cases (32 implemented / 0 waived)

This bucket exercises the integration boundary of the new `emulator_mutrig` 26.2.x bank inside `scifi_datapath_system_v3_pipe.qsys`. Cases test CSR window through `sc_hub`, run-control gating from `run_control_mgmt`, conduit + CSR inject paths, byte-stream feature axis, and downstream consumers (`mutrig_timestamp_processor`, `packet_scheduler`, `ring_buffer_cam`).

**Methodology key:**
- **D** = Directed (hand-crafted stimulus, deterministic)
- **R** = Constrained-random (LCG-based PRNG; no SystemVerilog rand)

---

## 1. Summary

| Section | Cases | ID Range | What it Proves | Current Case |
|---------|-------|----------|----------------|--------------|
| CSR Access and Identity (INTB001-INTB008) | 8 | INTB001-INTB008 | Read the new emulator's golden CSR header through the sc_hub aperture; confirm U | 0/8 |
| Run-Control Gating (INTB009-INTB014) | 6 | INTB009-INTB014 | The new emulator obeys the integration run-control sink at the same one-hot enco | 0/6 |
| Inject Path (INTB015-INTB020) | 6 | INTB015-INTB020 | Conduit and CSR-fire inject paths reach the new emulator through the integration | 0/6 |
| Byte Stream and MTS Downstream (INTB021-INTB024) | 4 | INTB021-INTB024 | The byte-stream feature axis and the MTS downstream consumer accept the new emul | 0/4 |
| Downstream Chain and Diagnostics (INTB025-INTB032) | 8 | INTB025-INTB032 | The downstream packet_scheduler and ring_buffer_cam path accept the emulator's t | 0/8 |

---

## 2. CSR Access and Identity (INTB001-INTB008)

Read the new emulator's golden CSR header through the sc_hub aperture; confirm UID/META/SCRATCH/LAST_* and per-lane LANE_ENABLE round-trip survive the integration bus.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|----|--------|----------|------|----------|---------------|---------------------|
| INTB001 | D | Read UID through sc_hub aperture | 1 | Issue CSR read at emulator_mutrig CSR base + 0x00 via the system slow-control bus. | Returns 0x454D5554 (ASCII EMUT). | TBD |
| INTB002 | D | Read META page 0 (VERSION) | 1 | Write 0 to base+0x01, then read. | Returns VERSION word with MAJOR=26 MINOR=2 PATCH=0 BUILD=502. | TBD |
| INTB003 | D | Read META page 1 (DATE) | 1 | Write 1 to base+0x01, then read. | Returns 20260502. | TBD |
| INTB004 | D | SCRATCH ping | 1 | Write 0xDEADBEEF to base+0x02, read back. | Read returns 0xDEADBEEF; bus liveness OK. | TBD |
| INTB005 | D | LAST_RD_ADDR captures | 1 | Read base+0x14 (BANK_STATUS), then read base+0x03. | 0x03 returns 0x14 in [4:0]. | TBD |
| INTB006 | D | LAST_WR_ADDR captures | 1 | Write 0xAA to base+0x02, read base+0x05. | 0x05 returns 0x02 in [4:0]. | TBD |
| INTB007 | D | CSR window survives sc_hub round-trip | 1 | 10 back-to-back CSR reads of UID via sc_hub. | All 10 reads return 0x454D5554; sc_hub busy_high_water below threshold. | TBD |
| INTB008 | D | CSR write to LANE_ENABLE persists | 1 | Write 0xFE to base+0x12; read back. | Read returns 0xFE in [7:0]. | TBD |

---

## 3. Run-Control Gating (INTB009-INTB014)

The new emulator obeys the integration run-control sink at the same one-hot encoding as the legacy IP.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|----|--------|----------|------|----------|---------------|---------------------|
| INTB009 | D | ctrl IDLE silences bank | 1 | Hold ctrl_state at IDLE for 10000 cycles. | Zero hit_type0 beats observed at any lane monitor. | TBD |
| INTB010 | D | ctrl RUNNING with global_enable=0 | 1 | RUNNING + cfg_global_enable=0. | Zero hit_type0 beats. | TBD |
| INTB011 | D | ctrl RUNNING with global_enable=1 internal Poisson | 1 | RUNNING + global_enable=1 + hit_mode_sig=INTERNAL + sub_mode=POISSON, hit_rate=0x4000. | Each lane monitor sees > 0 hits over 10k cycles. | TBD |
| INTB012 | D | ctrl SYNC clears emulator state | 1 | RUNNING then pulse SYNC. | Per-lane LANE_HIT_LO read after SYNC returns 0. | TBD |
| INTB013 | D | ctrl TERMINATING drains queued hits | 1 | RUNNING with backlog, drop to TERMINATING. | Type0 stream emits remaining queued hits then valid drops; one endofrun pulse per lane. | TBD |
| INTB014 | D | Run-control toggle stress | 1 | Toggle RUNNING<->IDLE every 1000 cycles for 10 cycles. | Each RUNNING window produces hits; IDLE window silent; no stuck state. | TBD |

---

## 4. Inject Path (INTB015-INTB020)

Conduit and CSR-fire inject paths reach the new emulator through the integration boundary and produce the right cluster geometry.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|----|--------|----------|------|----------|---------------|---------------------|
| INTB015 | D | Conduit inject from mutrig_injector | 1 | Drive mutrig_injector to pulse coe_inject_pulse once. | Cluster lands at the configured FIX low/high; type0 monitors see SOP/data/EOP. | TBD |
| INTB016 | D | CSR FIRE from sc_hub | 1 | Write 0x01 to base+0x13 (FIRE). | One cluster emitted; FIRE bit reads back 0. | TBD |
| INTB017 | D | Conduit + CSR fire same cycle = single launch | 1 | Drive both same cycle. | Exactly one cluster emitted (OR-merge before edge-detect). | TBD |
| INTB018 | D | Inject works in EXTERNAL hit_mode_sig | 1 | hit_mode_sig=EXTERNAL, internal hit_rate=0xFFFF, pulse inject. | Only inject-driven cluster appears; no internal Poisson hits. | TBD |
| INTB019 | D | Inject in IDLE dropped | 1 | ctrl=IDLE, pulse inject 10 times. | Zero clusters. | TBD |
| INTB020 | D | Inject FIX cluster spans all lanes | 1 | FIX low=0 high=255, pulse inject. | All 8 lane monitors see exactly 32 hits each, all sharing the same TCC anchor. | TBD |

---

## 5. Byte Stream and MTS Downstream (INTB021-INTB024)

The byte-stream feature axis and the MTS downstream consumer accept the new emulator's output; ECC seed delay propagates to decoded MTS time.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|----|--------|----------|------|----------|---------------|---------------------|
| INTB021 | D | Byte stream parity (BYTE_STREAM_ENABLE=1) | 1 | Build with BYTE_STREAM_ENABLE=1; route lane 0 through mutrig_frame_deassembly. | Beat-for-beat parity between deassembly type0 output and the emulator's direct type0 source on lane 0. | TBD |
| INTB022 | D | Byte stream silenced when build axis 0 | 1 | BYTE_STREAM_ENABLE=0; observe aso_tx8b1k. | Tx 8b1k stream reports K28.5 idle continuously; type0 stream still active. | TBD |
| INTB023 | D | MTS decoder accepts new TCC stream | 1 | Internal Poisson 100k cycles, mts_monitor captures. | MTS decoded GTS sequence is monotonic; no decoder bubble flags raised. | TBD |
| INTB024 | D | MTS sees configurable ECC delay | 1 | Set TIMEBASE_SEED.ecc_seed = prbs15_step_n(LFSR15_INIT, 5*N) for N=10; then run. | MTS decoded ECC time lags TCC by exactly N=10 cycles. | TBD |

---

## 6. Downstream Chain and Diagnostics (INTB025-INTB032)

The downstream packet_scheduler and ring_buffer_cam path accept the emulator's type1/type2 traffic, and per-lane diagnostics (counters, sticky bits, ERROR_INJECT) are reachable from the integration bus.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|----|--------|----------|------|----------|---------------|---------------------|
| INTB025 | D | Packet scheduler accepts type1 stream | 1 | Run Poisson 100k cycles; observe packet_scheduler_monitor. | Packet count > 0; no malformed-packet drops. | TBD |
| INTB026 | D | ring_buffer_cam push counter increments | 1 | Same; read CAM CSR push_count after the run. | push_count grew by approximately the lane_hit_count sum. | TBD |
| INTB027 | D | Upload monitor sees type2 packets | 1 | Same; check upload_monitor. | Final packet count matches scheduler-emitted packet count within drain latency. | TBD |
| INTB028 | D | Per-lane LANE_HIT_LO consistent with MTS hit count | 1 | Run, then read all 8 LANE_HIT_LO and tally MTS-decoded hits. | Sum LANE_HIT_LO == MTS-decoded hit count. | TBD |
| INTB029 | D | Per-lane fifo_full_sticky stays clear at nominal load | 1 | Run hit_rate=0x4000 for 100k cycles. | All 8 lanes' fifo_full_sticky == 0. | TBD |
| INTB030 | D | Per-lane fifo_full_sticky asserts under stress | 1 | Run hit_rate=0xFFFF; stall packet_scheduler. | At least one lane's fifo_full_sticky asserts within 10k cycles; W1C clears it. | TBD |
| INTB031 | D | ticket_overflow_count saturates at 0xFFFF | 1 | Force overflow > 65k via stalled lanes. | BANK_STATUS.ticket_overflow_count == 0xFFFF. | TBD |
| INTB032 | D | ERROR_INJECT routes to type0 error bits | 1 | Set base+0x15 to {error_target_lane_mask=0x01, error_inject_mask=0x07}. | Lane 0 type0_error stream reports 3'b111 on every beat; other lanes 0. | TBD |

---
