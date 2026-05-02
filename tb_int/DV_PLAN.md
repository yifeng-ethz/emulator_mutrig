# tb_int DV — emulator_mutrig integration plan

**Companion docs:** [DV_BASIC.md](DV_BASIC.md), [DV_HARNESS.md](DV_HARNESS.md), [DV_REPORT.md](DV_REPORT.md), [BUG_HISTORY.md](BUG_HISTORY.md), `REPORT/`

**Patch under verification:** central-trigger refresh 26.2.x dropped into the FE SciFi datapath Qsys system (`scifi_datapath_system_v3_pipe.qsys`), replacing the legacy 8x single-lane instances of `emulator_mutrig` 26.1.13 with one 8-lane bank instance.

## 1. Verification Targets

The integration must prove:

1. **Qsys swap-in compatibility.** The new `emulator_mutrig` 26.2.x replaces the legacy `emulator_mutrig_0..7` instances at the same Qsys ports — ctrl AvST sink, CSR AvMM slave (now consolidated into one slave at the bank level), conduit `inject_pulse`, per-lane `hit_type0` AvST source, optional per-lane `tx8b1k` AvST source.
2. **CSR aperture preserved.** The `sc_hub` mapping for the emulator slave still answers; reads of UID/META return the new IP identity (UID `0x454D5554` = `EMUT`, VERSION 26.2.0); per-lane status registers (`LANE_FRAME_*`, `LANE_HIT_*`) accessible via the same address window.
3. **Downstream consumers happy.** `mutrig_timestamp_processor` decodes the new emulator's TCC/ECC stream without a phase shift; `packet_scheduler` accepts the per-lane stream; `ring_buffer_cam` push counters increment.
4. **Run-control discipline.** RUNNING/TERMINATING/SYNC drive the bank correctly under the integration `run_control_mgmt` host; SYNC clears state on the same boundary as the rest of the system.
5. **Inject path connected.** `mutrig_injector` conduit pulse produces a cluster across all 8 lanes when `cluster_geom_mode = FIX` with low=0, high=255.
6. **Backwards-compat toggle.** Build under `BYTE_STREAM_ENABLE = 0` (type0-only) is the gated point; `BYTE_STREAM_ENABLE = 1` is reported but not gated for 26.2.x.

## 2. Bucket Layout

| Bucket | File | Cases | What it Proves |
|--------|------|-------|----------------|
| BASIC  | [DV_BASIC.md](DV_BASIC.md) | 32 (T001-T032) | Qsys swap-in compatibility, CSR aperture, run-control gating, inject path, downstream consumer integrity. |
| (later) | DV_EDGE/PROF/ERROR | 0 | Reserved for follow-up patches once basic integration is green. |

`T###` prefix is used for tb_int cases to disambiguate from standalone bucket prefixes (`B`, `E`, `P`, `X`).

## 3. Build Feature Axes

| Axis | Parameter | Gated point | Reported point |
|------|-----------|-------------|----------------|
| Lane count | `LANE_COUNT` | 8 (production) | 1, 2, 4 (informational) |
| Output path | `BYTE_STREAM_ENABLE` | 0 (type0-only, primary) | 1 (compatibility) |

Both gated points must pass DV_BASIC before the integration is considered green.

## 4. Reference IPs in the integration

- `mutrig_frame_deassembly` (consumes the optional byte-stream output if `BYTE_STREAM_ENABLE=1`)
- `mutrig_timestamp_processor` (consumes the type0 stream)
- `packet_scheduler` (downstream of timestamp processor)
- `ring_buffer_cam` (downstream of packet scheduler)
- `sc_hub` (CSR fan-out)
- `run_control_mgmt` (run-control sink)
- `mutrig_injector` (conduit inject driver)

## 5. Sign-off Gate

1. All 32 BASIC cases pass on the gated build (`LANE_COUNT=8, BYTE_STREAM_ENABLE=0`).
2. Compatibility build (`BYTE_STREAM_ENABLE=1`) passes the byte-stream subset (T021-T024).
3. Integration Quartus compile of `scifi_datapath_system_v3_pipe.qsys` with the new emulator passes timing at the system clock.
4. CSR walk via `sc_hub` returns the expected golden header (UID, META mux, SCRATCH ping, LAST_RD/WR_*).
5. Hardware soak (deferred — hardware access pending).

## 6. Open Items

- Hardware bring-up on the FEB SciFi board is **deferred** pending lab access. All gate-1 evidence here is simulation-based against the integration Qsys system.
- The `emulator_mutrig_hw.tcl` packaging file at the IP root must be refreshed to the 26.2.x port shape (8-lane bank + new CSR map) before the Qsys system can re-instantiate the new IP. This is a prerequisite for tb_int to even compile against the integration system. **Tracked separately under the ip-packaging skill deliverable.**
