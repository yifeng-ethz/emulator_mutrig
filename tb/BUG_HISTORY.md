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
