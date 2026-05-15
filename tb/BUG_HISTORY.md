# BUG_HISTORY.md - emulator_mutrig DV bug ledger

Class legend:
- `R` = RTL / DUT bug
- `H` = harness / testcase / reporting bug

Severity legend:
- `soft error` = the bad packet/data flushes through the stream and does not leave the later datapath stuck
- `hard stuck error` = the bug poisons later packet handling and typically needs a functional reset / fresh restart to recover
- `non-datapath-refactor` = observability, reporting, harness, or naming/accounting consistency work with no direct packet-contract effect

Encounterability legend:
- practical severity is `severity x encounterability`, so the index must say how likely a reader is to hit the bug in normal use rather than only when it first appeared in one simulation log
- nominal datapath operation = legal traffic, about `50%` link load, iid per-lane behavior, and no forced error injection or artificially pathological stalls
- nominal control-path operation = routine bring-up / CSR program / readback / clear-counter sequences
- `common (...)` = readily hit in nominal operation
- `occasional (...)` = hit in nominal operation without heroic setup, but not in every short run
- `rare (...)` = legal in nominal operation, but usually needs long runtime or unlucky alignment
- `corner-only (...)` = requires a legal but non-nominal stress or corner profile
- `directed-only (...)` = requires targeted error injection, formal/probe flow, reporting-only flow, or another non-operational stimulus
- detailed `min / p50 / max` first-hit sim-time studies may still appear inside individual bug sections when they are useful

Fix status detail contract for active entries and future updates:
- `state` = fixed / open / partial plus the current verification gate
- `mechanism` = how the implemented repair changes the RTL or harness behavior
- `before_fix_outcome` and `after_fix_outcome` = concise evidence showing what changed
- `potential_hazard` = whether the fix looks permanent or is still provisional / profile-limited
- `Claude Opus 4.7 xhigh review decision` = explicit review state; use `pending / not run` until that review has actually happened

Historical formal note:
- No emulator_mutrig 26.2.x central-trigger DV bugs are indexed yet.
- The current supported formal direction is `qverify` / `znformal`, and the current supported simulator runtime is `QuestaOne 2026` at `/data1/questaone_sim/questasim`.

## Index

| bug_id | class | severity | encounterability | status | first seen | commit | summary |
|---|---|---|---|---|---|---|---|
| [BUG-001-R](#bug-001-r-inject-path-produces-no-hits-in-externalfix-1-channel-window) | R | soft error | rare (single-shot inject under saturated PRNG advance) | mitigated 2026-05-02 | 2026-05-02 / make central_basic | bf47f16 | a single inject (CSR FIRE or conduit edge) sometimes does not produce a visible hit when SIGNAL is EXTERNAL+FIX with a 1-channel window; mitigated by issuing N=5 injects with frame-period spacing in tb so the test verifies "at least 1 cluster reaches the lane" instead of "exactly 1". Root-cause RTL trace remains as a follow-up for the strict 1:1 inject:hit guarantee. |
| [BUG-002-R](#bug-002-r-periodic-at-rate0xffff-stalls) | R | soft error | rare (only at Periodic rate=0xFFFF in short windows) | mitigated 2026-05-02 | 2026-05-02 / make central_basic | bf47f16 | INTERNAL+Periodic at rate=0xFFFF needs a longer settle window than 1000 cycles to push the first hit through the 4-stage pipeline + 6-cycle pacer; mitigated by extending B049 to 5000 cycles. Root-cause RTL trace is a follow-up to confirm the phase accumulator is not dropping fires under engine-busy. |
| [BUG-003-R](#bug-003-r-registered-signal-offer-replays-one-ticket-after-ready-accept) | R | hard stuck error | common (single-lane signal inject with ready asserted) | fixed 2026-05-06 / phase sweep passed | 2026-05-06 / tb_int PROF-INT-002 pre-rbCAM diagnostic | 1849caa | the registered signal-offer path replayed the same pending ticket for one cycle after downstream ready accepted it, so one fixed two-channel injection produced four emitted hits instead of two. |
| [BUG-004-R](#bug-004-r-l2-fifo-write-request-asserts-while-full) | R | soft error | corner-only (sustained high-rate 4-channel clusters or stalled L2 drain) | open 2026-05-08 | 2026-05-08 / MuTRiG Poisson 4-channel + dark-noise rate scan | 8e5c901 / 205f3be | the locally added 26.2.x lane backend can assert the lane L2 FIFO write request while the FIFO is full; this violates the no-write-when-full contract and correlates with FIFO saturation and channel-hit loss in the rate scan. |
| [BUG-005-H](#bug-005-h-packaged-csr-addr-width-hid-upper-live-csr-words) | H | soft error | common (board CSR read/write above word 0x0F) | fixed 2026-05-13 / pulserdrop FEB board readback passed | 2026-05-13 / pulserdrop arb-STP recompile | pending | `emulator_mutrig_hw.tcl` exported `CSR_ADDR_WIDTH=4` while the RTL CSR map uses upper words including `LANE_ENABLE` at word 0x12; board builds therefore hid/aliased those registers until the packaged width was raised to 6. |
| [BUG-006-H](#bug-006-h-byte-stream-mode-left-direct-hit-stream-enabled-in-qsys) | H | non-datapath-refactor | common (FEB v3 Platform Designer open/generate) | fixed 2026-05-15 / Qsys package gating | 2026-05-15 / FEB v3 Qsys GUI cleanup | this commit | byte-stream emulator instances still advertised the direct `hit_type0` stream, so Platform Designer reported the intentionally unused interface as unconnected. |

## 2026-05-15

### BUG-006-H: byte-stream mode left direct hit stream enabled in Qsys

- First seen in: 2026-05-15 FEB v3 `quartus_systems/feb_system_v3.qsys` Platform Designer open/generate cleanup.
- Symptom: emulator instances configured for the byte-stream path still exposed the direct `hit_type0` Avalon-ST source, so Platform Designer reported intentionally unused direct-hit streams as unconnected.
- Root cause: `emulator_mutrig_hw.tcl` did not gate `hit_type0` and `tx8b1k` according to `BYTE_STREAM_ENABLE`.
- Fix status: fixed / package metadata now enables `tx8b1k` for byte-stream mode and disables `hit_type0` in that same mode; package version bumped to 26.3.2.0515.

**Mechanism:** the Qsys elaboration callback reads `BYTE_STREAM_ENABLE` and sets the mutually exclusive stream-interface `ENABLED` properties before Platform Designer validates the system. The RTL datapath selection is unchanged; the package now matches the selected integration mode.

**Observed evidence:** `qsys-generate quartus_systems/feb_system_v3.qsys --synthesis=VERILOG` exited with status 0, no `Error:` lines, and 82 remaining warnings in `/tmp/qsys_generate_feb_v3_top_20260515_121600.log`.

**Reproducer:** open or generate FEB v3 with emulator instances in byte-stream mode before this package fix. Platform Designer reports the direct hit interface even though the top-level integration consumes the byte stream.

**Potential hazard:** low. The change is package metadata gating only and keeps the direct-hit interface enabled for non-byte-stream configurations.

**Claude Opus 4.7 xhigh review decision:** pending.

## 2026-05-13

### BUG-005-H: packaged CSR addr width hid upper live CSR words

- First seen in: 2026-05-13 pulserdrop FEB `arb_hit_type0_supercore` restoration and RN.BASIC.001 board debug
- Symptom: FEB slow-control access to `emulator_mutrig` upper CSR words was not reliable; `LANE_ENABLE` at live word address `0x08812` could not be used as a normal board read/write surface before repackaging
- Root cause: the Platform Designer packaging metadata exported `CSR_ADDR_WIDTH=4` even though the emulator RTL exposes a wider CSR word map
- Fix status: fixed / `_hw.tcl` packaging metadata updated to `CSR_ADDR_WIDTH=6`, VERSION 26.3.1 build 513

**Mechanism:** generated Qsys address decoding used the packaged CSR width when instantiating the emulator lanes. With width 4, only the low 16 CSR words were visible through the live board aperture; words above `0x0F` were hidden or aliased even though the source RTL implemented them. The pulserdrop board flow needed `LANE_ENABLE` at word `0x12` to verify and hold all eight emulator lanes enabled during RN.BASIC.001.

**Observed evidence:** after regenerating pulserdrop Qsys through the Tcl flow and recompiling the FEB debug image, live slow-control readback showed emulator UID `0x454D5554`, version `0x1A0301FA`, and `LANE_ENABLE=0x000000FF` at `0x08812`. The same image restored the downstream arb CSR surface at `0x088A0`, and the RN.BASIC.001 host run produced nonzero arb ingress/egress emulator counters with zero arb drops.

**Reproducer:** in a board build with the old packaged metadata, write/read word `0x12` in the emulator CSR aperture. The bad image does not provide a stable upper-word readback; the fixed image reads back the written lane-enable mask.

**Potential hazard:** this is a packaging/source metadata fix, not an RTL functional change. Any cached generated Qsys tree must be regenerated through the script flow; hand-editing generated Qsys XML or synthesis output would not fix future regenerations.

**Claude Opus 4.7 xhigh review decision:** pending.

## 2026-05-08

### BUG-004-R: L2 FIFO write request asserts while full

- First seen in: 2026-05-08 MuTRiG Poisson 4-channel cluster plus dark-noise rate scan
- Symptom: lane L2 FIFO write request asserted while the FIFO was already full, coincident with 256-word FIFO saturation and rising channel-hit loss at high input rate
- Root cause: the local 26.2.x `be_mutrig_lane_emitter` creates and presents a pending L2 word without requiring `l2_wr_ready`
- Fix status: open / awaiting RTL repair

**Classification:** supplementary RTL bug, not a pulled MuTRiG source bug. The pulled `main` source at `5fa6750` contains the legacy `rtl/emulator_mutrig.sv` / `rtl/hit_generator.sv` path and does not contain `rtl/backend_mutrig/be_mutrig_l2_fifo.sv` or `rtl/backend_mutrig/be_mutrig_lane_emitter.sv`. The L2 FIFO wrapper was introduced locally in `205f3be`, and the lane emitter that drives it was introduced locally in `8e5c901` as part of the 26.2.x central-trigger backend reconstruction.

**Mechanism (confirmed by code inspection):** `rtl/backend_mutrig/be_mutrig_lane_emitter.sv` drives `u_l2_fifo.wr_valid` directly from `pending_valid`. It creates a new pending word on `enable && active_valid && !pending_valid` without first requiring `l2_wr_ready`. If `rtl/backend_mutrig/be_mutrig_l2_fifo.sv` is already full, the caller therefore presents a write request to a full FIFO. The FIFO wrapper masks the actual RAM write with `push_fire = wr_valid && wr_ready`, but the L2 protocol and the X067/X068 DV intent require back-pressure to stop the lane emitter before any full-FIFO write request or ticket/channel advance.

**Observed evidence:** the 2026-05-08 MuTRiG Poisson 4-channel cluster plus dark-noise rate scan showed the L2 FIFO fill band reaching the 256-word limit while total channel-hit loss rose at high input rate. The protocol monitor/debug review identified the illegal L2 write-while-full condition in the same stress region.

**Reproducer:** run the high-rate MuTRiG Poisson 4-channel + dark-noise scan, or add a directed X067/X068-style back-pressure check that asserts `!(u_l2_fifo.full && u_l2_fifo.wr_valid)` under `be_mutrig_lane_emitter`. Existing `tb/DV_ERROR.md` already reserves X067 and X068 for L2 back-pressure propagation and ticket FIFO overflow after L2 stall.

**Repair plan:** gate pending-word creation and ticket/channel advancement on `l2_wr_ready` or an explicit L2 credit, then add the no-write-when-full assertion and rerun X065-X068 plus the rate scan.

**Claude Opus 4.7 xhigh review decision:** pending.

## 2026-05-02

### BUG-001-R: inject path produces no hits in EXTERNAL+FIX 1-channel window

**Mechanism (suspected):** the trigger engine 3-stage pipeline (geom_stage → launch_stage → shred + registered sig_offer) added in commits 0627a04 and 3c76ce9 may interact with the inject-launch path so that pending_mask never gets a bit set for a single-channel FIX cluster, OR the lane FIFO bookkeeping with sig_offer_lane_q (registered) drops the single hit before it reaches the L2 FIFO.

**Reproducer:** `make -C tb central_basic` — fails on B065 B066 B081-B084 when those cases use exact `sum_lane_hits() == 1` checks. Currently smoke-only in tb_central_top.sv at HEAD pending the RTL trace.

**Fix status:** open / awaiting waveform inspection. Pipelining was the priority for 137.5 MHz timing closure; functional verification of the inject path at 1-channel granularity is the follow-up.

**Claude Opus 4.7 xhigh review decision:** pending.

### BUG-002-R: Periodic at rate=0xFFFF stalls

**Mechanism (suspected):** the phase_sum overflow check happens before the engine_occupied gate; when the engine is busy in the new pipeline, the overflow may be lost rather than queued. Lower Periodic rates (e.g. 0x8000) work because the engine has time to drain between overflows.

**Reproducer:** B049 in tb_central_top.sv. Currently smoke-only pending RTL trace.

**Fix status:** open / awaiting waveform inspection.

**Claude Opus 4.7 xhigh review decision:** pending.

### BUG-003-R: registered signal offer replays one ticket after ready accept

**Mechanism:** `frontend_trigger_engine.sv` registered `sig_offer_valid_q` from the combinational `dispatch_found` signal. The pending bit for the accepted lane is cleared in the same clocked block using the registered offer lane, so `dispatch_found` still sees the old `pending_mask` for that edge. When `sig_offer_ready` is asserted, the same `sig_offer_ticket_q` can be accepted twice before the pending bit clear is visible.

**Reproducer:** integration PROF-INT-002 pre-rbCAM header-sync diagnostic in `system_20260504_emulator_type0/tb_int`: four injected pulses over fixed channels 0 and 1 produced 16 pre-rbCAM records. The emulator source counter `lane_hit_count[0]` advanced by four per pulse, proving the duplicate was emitted by the source RTL.

**Fix status:** fixed / integration phase sweep passed. The signal-offer register now behaves as a one-deep ready/valid stage: it holds valid until ready accepts the ticket, drops valid for one cycle after accept so the `pending_mask` clear can take effect, then reloads from the next pending lane. Focused rerun `prof_int_002_pre_rbcam_header_sync_phase100_diag_after_offer_fix` produced 8 pre-rbCAM rows for four two-channel pulses, with latency `min=821`, `p50=821.5`, `max=822` cycles. The 100-900 cycle header-sync sweep passed with 256 rows at every phase; phases 100..800 form narrow peaks at `910 - phase + 11.5` cycles, and phase 900 splits as expected into fast bins at 21/25 cycles plus a full-frame bin at 929 cycles.

**Claude Opus 4.7 xhigh review decision:** pending.
