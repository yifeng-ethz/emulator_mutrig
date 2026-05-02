# emulator_mutrig DV — Verification Plan

**Companion docs:** [DV_BASIC.md](DV_BASIC.md), [DV_EDGE.md](DV_EDGE.md), [DV_PROF.md](DV_PROF.md), [DV_ERROR.md](DV_ERROR.md), [DV_HARNESS.md](DV_HARNESS.md), [DV_COV.md](DV_COV.md), [BUG_HISTORY.md](BUG_HISTORY.md), `REPORT/`

**Patch under verification:** Central trigger engine refresh — front-end / back-end split, single inject port, golden 7-word CSR header, RANDOM mirror modes, direct hit_type0 emit. See `../doc/RTL_PLAN_central_trigger.md` for the architecture.

## 1. Verification Targets

The patch restructures the IP around an explicit FE/BE layering. DV must prove:

1. **Front-end correctness.** The SIGNAL (Poisson, Periodic, FIX, RANDOM with mirror modes), BACKGROUND (per-channel IID), and EXTERNAL inject (CSR fire OR'd with conduit pulse) producers all compute the right per-lane tickets and dispatch them on the shared ticket bus per the §2.0 contract.
2. **Back-end correctness (MuTRiG).** Each per-lane back-end consumes tickets, packs hits in MuTRiG long/short word format with correct TCC/ECC/T_Fine/E_Fine semantics, and drives both the direct `hit_type0` AvST source and the optional 8b/1k byte stream.
3. **Common CSR golden header (0x00..0x06).** UID, META, SCRATCH, LAST_RD/WR_ADDR/DATA exposed exactly per the v2 template; passes `~/.codex/skills/ip-packaging/scripts/lint_csr_header.py --profile golden`.
4. **Run-control discipline.** RUNNING gates new generation, TERMINATING drains, SYNC/RESET clears state. Engine survives illegal ctrl words.
5. **Backpressure and overflow.** Per-lane ticket FIFO, per-lane L2 FIFO, type0 and byte-stream sinks all honor ready/valid; overflow paths counted and recoverable.
6. **Type0 vs deassembly parity.** Direct type0 path matches `mutrig_frame_deassembly` output beat-for-beat across all modes.
7. **ECC seed delay.** TCC and ECC LFSRs run from independent CSR-loadable seeds; user-computed offset realizes configurable ECC-after-TCC delay.

## 2. Bucket Layout (per dv-workflow §15b)

| Bucket | File | Cases | What it Proves |
|--------|------|-------|----------------|
| BASIC  | [DV_BASIC.md](DV_BASIC.md) | 128 (B001-B128) | Bring-up: golden CSR header, run-control decode, SIGNAL Poisson/Periodic, EXTERNAL inject, FIX/RANDOM cluster, BACKGROUND IID. Required to pass before other buckets are meaningful. |
| EDGE   | [DV_EDGE.md](DV_EDGE.md) | 128 (E001-E128) | Boundaries: channel range, cluster size, mirror offset clamp, SMB boundaries, lane-enable interactions, ECC seed phase sweep, frame boundary races, counter saturation, CSR aliasing/reserved bits. |
| PROF   | [DV_PROF.md](DV_PROF.md) | 128 (P001-P128) | Performance and stress: sustained 100% load, burst cluster throughput, BACKGROUND soak, mixed SIGNAL+BKG, per-lane drain latency, type0 vs deassembly parity, inject ORing stress, continuous-frame long-run soak. |
| ERROR  | [DV_ERROR.md](DV_ERROR.md) | 128 (X001-X128) | Reset/illegal/recovery: reset during activity, illegal run-control transitions, CSR access during reset, ticket FIFO overflow, L2 backpressure recovery, frame-boundary reset, CSR atomicity, run-control replay. |
| **Total** | | **512 cases** | |

Note: per the user request, the perf/stress bucket is named `DV_PROF.md` to satisfy `dv_bucket_format_check.py` (the canonical letter is `P`, not `PERF`).

## 3. Coverage Intent

Per dv-workflow §6: every case has its own isolated UCDB; merged isolated baseline is reported per delta; final closure includes statement, branch, condition, expression, FSM, and toggle merged totals. Continuous-frame `bucket_frame` and `all_buckets_frame` modes (§8-9) are mandatory baselines — see [DV_COV.md](DV_COV.md) for the running tables.

Key coverpoints (full list in [DV_HARNESS.md](DV_HARNESS.md)):

- **CSR address space:** every word in 0x00..0x3F written (where RW) and read.
- **Mode matrix:** every combination of `hit_mode_sig × internal_sub_mode × cluster_geom_mode × hit_mode_bkg × mirror_mode`.
- **Cluster size:** {1, 2, 32, 33, 64, 127, 128, 256} crossed with mirror_mode.
- **Mirror offset:** {-128, -32, -1, 0, +1, +32, +127} crossed with cluster size.
- **Per-lane:** every lane (0..7) sees at least one ticket of every type.
- **Run-control:** every legal one-hot state; every legal transition pair.
- **Backpressure:** per-lane ticket FIFO depth bins {0, 1, 4, 7, 8 (full)}, L2 FIFO {0, 64, 128, 192, 255, 256 (full)}.
- **Counters:** per-lane frame_count and hit_count cross 32-bit and 60-bit boundaries at least once.

## 4. Reference RTL

- `rtl/frontend/frontend_csr.sv`
- `rtl/frontend/frontend_run_ctl.sv`
- `rtl/frontend/frontend_trigger_engine.sv`
- `rtl/frontend/frontend_bkg_generator.sv`
- `rtl/frontend/frontend_ticket_distributor.sv`
- `rtl/common/frontend_ticket_bus_pkg.sv`  (FE/BE contract)
- `rtl/common/prbs15_lfsr.sv`
- `rtl/backend_mutrig/be_mutrig_pkg.sv`
- `rtl/backend_mutrig/be_mutrig_lane_emitter.sv`
- `rtl/backend_mutrig/be_mutrig_l2_fifo.sv`
- `rtl/backend_mutrig/be_mutrig_lane_type0_emit.sv`
- `rtl/backend_mutrig/be_mutrig_frame_assembler.sv`
- `rtl/emulator_mutrig.sv`  (top, FE + 8 × BE-MuTRiG)

## 5. Build Feature Axes (synthesis + DV matrix)

This IP has exactly **two** elaboration-time feature axes (per `../doc/RTL_PLAN_central_trigger.md` §1.1):

| Axis | Parameter | Legal values | Default |
|------|-----------|--------------|---------|
| Lane count | `LANE_COUNT` | 1, 2, 4, 8 | 8 |
| Output path | `BYTE_STREAM_ENABLE` | 0 (type0 only) / 1 (type0 + 8b/1k) | 0 |

DV gated points (must pass for signoff):

- `LANE_COUNT=8, BYTE_STREAM_ENABLE=0` — primary build, type0-only path. All 512 cases run here except those that explicitly require the byte-stream output.
- `LANE_COUNT=8, BYTE_STREAM_ENABLE=1` — compatibility build, exercises both type0 and 8b/1k for the deassembly-parity tests (P081-P096).

DV-reported but not gated for 26.2.x: `LANE_COUNT in {1,2,4}` × both byte-stream values.

Cases that explicitly require `BYTE_STREAM_ENABLE=1` are flagged in their `Stimulus` cell (search "byte-stream"). All other cases pass on either build.

## 6. Long-Run Soak Coverage Promotion (per dv-workflow §8-9)

For `bucket_frame` and `all_buckets_frame` modes, every case promotes its directed stimulus into a constrained-random profile centred on the directed value (PRNG seed varied per soak run). This is mandatory: a directed-only soak produces no coverage delta beyond a single isolated case.

A separate Claude subagent dispatch derives the per-case coverage points (covergroup bins, cross-coverage with mode-axis, lane-axis, and frame-axis state) and a `random_profile_t` struct per case. The `random_profile` is consumed by the UVM sequence layer in `bucket_frame` mode to scatter each case across its neighbourhood while the `isolated` mode keeps the directed pin.

## 7. Sign-off Gate

Per dv-workflow §17-18:

1. All 512 cases pass in isolated mode on the primary build; isolated merged coverage tables green in [DV_COV.md](DV_COV.md).
2. `bucket_frame` and `all_buckets_frame` continuous-frame modes pass on the primary build, with random-promoted profiles.
3. The compatibility build (`BYTE_STREAM_ENABLE=1`) passes the parity bucket (P081-P096) and the type0/byte-stream-coupled subset of BASIC and EDGE.
4. RTL lint passes via `rtl-linter-and-checker` skill, including formal mode (`--modes lint,cdc,rdc,formal`) with the harness-provided assertions/assumes/covers (Claude is responsible for inserting these during code review per the user's 2026-05-02 directive).
5. Synthesis at 137.5 MHz signoff clock passes on both gated build points.
6. CSR header lint passes (`lint_csr_header.py --profile golden`).
7. [BUG_HISTORY.md](BUG_HISTORY.md) and [DV_REPORT.md](DV_REPORT.md) are current and lint-clean.
8. Independent cross-check of dashboard rows passes.
9. Then and only then: signoff git tag.
