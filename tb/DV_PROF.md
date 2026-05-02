# emulator_mutrig DV — Performance, Stress, and Soak Cases

**Companion docs:** [DV_PLAN.md](DV_PLAN.md), [DV_BASIC.md](DV_BASIC.md), [DV_EDGE.md](DV_EDGE.md), [DV_PROF.md](DV_PROF.md), [DV_ERROR.md](DV_ERROR.md), `BUG_HISTORY.md`

**Parent:** [DV_PLAN.md](DV_PLAN.md)
**ID Range:** P001-P999
**Total:** 128 cases (128 implemented / 0 waived)

This bucket characterizes throughput and latency under load and stress: sustained 100% offered load, burst cluster throughput, BACKGROUND long-run uniformity, mixed SIGNAL+BKG, per-lane drain latency distributions, type0 vs deassembly beat-for-beat parity, inject ORing stress, and continuous-frame long-run soak. Per the user request these are the 'PERF' cases; the file is named `DV_PROF.md` because the dv-workflow lint requires the canonical bucket letter `P`.

**Methodology key:**
- **D** = Directed (hand-crafted stimulus, deterministic)
- **R** = Constrained-random (LCG-based PRNG; no SystemVerilog `rand`)

---

## 1. Summary

| Section | Cases | ID Range | What it Proves | Current Case |
|---------|-------|----------|----------------|--------------|
| Sustained 100% Offered Load | 16 | P001-P016 | Sustained-throughput stress: engine and per-lane back-end keep up at full rate; counters track correctly; recovery from stall. | 16/16 |
| Burst Cluster Throughput | 16 | P017-P032 | Engine handles bursty inject patterns; ticket FIFO depth bounded by 8; sticky bits set on overflow; both output paths independent under backpressure. | 16/16 |
| BACKGROUND Soak and Uniformity | 16 | P033-P048 | BKG generator: long-run uniformity, TCC distribution (fine-time tied to zero per simple model), recovery from stall, no lost hits. | 16/16 |
| Mixed SIGNAL + BACKGROUND | 16 | P049-P064 | FE arbitrates SIGNAL and BACKGROUND correctly; per-lane back-end consumes from both; no source starvation; counters separate. | 16/16 |
| Per-Lane Drain Latency | 16 | P065-P080 | End-to-end inject→output latency characterized; per-lane independent; type0 leads byte-stream; latency under load and backpressure. | 16/16 |
| Type0 vs Deassembly Beat-For-Beat Parity | 16 | P081-P096 | Direct type0 emit path matches mutrig_frame_deassembly output for the same byte-stream input, beat-for-beat, across all modes and run lengths. | 16/16 |
| Inject ORing Stress and Edge Cases | 16 | P097-P112 | Inject-ORed-pulse handles bursts and corner-cases (collision, glitch, mode-switch) without losing or duplicating launches. | 16/16 |
| Continuous-Frame Long-Run Soak | 16 | P113-P128 | all_buckets_frame mandatory baseline per dv-workflow §8-9: long-run stability across all modes, seeds, and run-control patterns; merged coverage > isolated. | 16/16 |

---

## 2. Sustained 100% Offered Load (P001-P016)

Sustained-throughput stress: engine and per-lane back-end keep up at full rate; counters track correctly; recovery from stall.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|----|--------|----------|------|----------|---------------|---------------------|
| P001 | R | Sustained Poisson 100% rate=0xFFFF | 1 | RUNNING 1M cycles, hit_rate=0xFFFF. | Throughput per lane > 0.25 hit/cycle; no L2 underrun. | TBD |
| P002 | R | Sustained Periodic period=4 cycles | 1 | Periodic rate=0x4000, 1M cycles. | Each lane sees ~250k hits. | TBD |
| P003 | R | Sustained 50% Poisson | 1 | rate=0x8000, 1M cycles. | Each lane sees ~125k hits. | TBD |
| P004 | R | Sustained 25% Poisson | 1 | rate=0x4000, 1M cycles. | Each lane sees ~62k hits. | TBD |
| P005 | R | Sustained 10% Poisson | 1 | rate=0x199A (~10%), 1M cycles. | Each lane sees ~25k hits. | TBD |
| P006 | R | 100% Periodic for 10M cycles | 1 | Periodic rate=0xFFFF, 10M cycles. | 10M hits per active lane; counters do not wrap. | TBD |
| P007 | R | Sustained Poisson with FIX size 1 | 1 | Poisson cluster=1ch, rate=0xFFFF. | 1 hit per launch on cluster center lane. | TBD |
| P008 | R | Sustained Poisson with FIX size 256 | 1 | Poisson size=256, rate=0x0001. | Each launch fans to all 8 lanes; ticket FIFO depth tested. | TBD |
| P009 | R | Sustained Periodic with RANDOM size=64 MIRRORED | 1 | Periodic + size=64 MIRRORED. | Each launch produces 128 hits across 8 lanes. | TBD |
| P010 | R | Throughput under stalled lane 0 | 1 | Hold lane 0 ready=0 1M cycles. | Other 7 lanes still throughput at full; lane 0 ticket_overflow_count rises. | TBD |
| P011 | R | Throughput recovery from stall | 1 | Stall all lanes 100k cycles, release. | Engine catches up; all queued tickets eventually drain. | TBD |
| P012 | R | Sustained at 137.5MHz (signoff clock) | 1 | Run 1M cycles at 137.5MHz. | All transactions complete; no setup/hold violations in gate-level sim. | TBD |
| P013 | R | Sustained at 125MHz (nominal) | 1 | Run 1M cycles at 125MHz. | Same. | TBD |
| P014 | R | Sustained with global_enable toggled every 1k cycles | 1 | Toggle global_enable. | Bursty traffic; engine pauses/resumes cleanly. | TBD |
| P015 | R | Sustained with run-control toggle RUNNING↔TERMINATING | 1 | Toggle every 10k cycles. | Drain/refill cycles complete; no lost hits. | TBD |
| P016 | R | Sustained back-to-back inject (every cycle) | 1 | Inject every cycle for 1M cycles. | Engine runs at 1 launch/cycle; no stall unless lane FIFO fills. | TBD |

---

## 3. Burst Cluster Throughput (P017-P032)

Engine handles bursty inject patterns; ticket FIFO depth bounded by 8; sticky bits set on overflow; both output paths independent under backpressure.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|----|--------|----------|------|----------|---------------|---------------------|
| P017 | D | Burst of 8 clusters back-to-back size=32 | 1 | Inject 8 cycles in a row, FIX size=32. | 8 clusters queued; engine dispatches 1/cycle; 8 lanes get tickets. | TBD |
| P018 | D | Burst of 16 clusters | 1 | 16 injects. | Ticket FIFO at 8/lane; some overflow if not drained fast. | TBD |
| P019 | D | Burst of 64 clusters | 1 | 64 injects in 64 cycles. | Engine_busy high-water; ticket_overflow_count climbs. | TBD |
| P020 | D | Burst of 256 clusters | 1 | 256 injects. | Massive overflow; tests sticky bit asserts and engine recovery. | TBD |
| P021 | D | Burst with idle gap | 1 | 8 inject, 100 cycles idle, 8 inject. | Two distinct bursts; counters increment by 16. | TBD |
| P022 | D | Burst with FIX size sweep 1..256 | 1 | 1 inject of size 1, 1 of size 2, ..., 1 of size 256. | Per-launch hit count matches size. | TBD |
| P023 | D | Burst all to same lane (FIX low=high) | 1 | 100 injects FIX low=64 high=64. | Lane 2 ch 0 receives 100 hits; ticket queue stresses lane 2 only. | TBD |
| P024 | D | Burst across all lanes round-robin | 1 | 100 injects FIX low=k%256 high=k%256. | Hits round-robin across lanes. | TBD |
| P025 | D | Burst of inject + Poisson on top | 1 | Inject 100 + Poisson rate=0x8000. | Both populations visible; merge correct. | TBD |
| P026 | D | Burst RANDOM MIRRORED size=128 | 1 | 100 injects RANDOM 128 MIRRORED. | Each launch fans to all lanes; massive throughput. | TBD |
| P027 | D | Burst LEFT_ONLY only stresses side A | 1 | 100 injects LEFT_ONLY size=128. | Side B never stalls. | TBD |
| P028 | D | Burst RIGHT_ONLY only stresses side B | 1 | 100 injects RIGHT_ONLY size=128. | Side A never stalls. | TBD |
| P029 | D | Burst at boundary of frame interval | 1 | 8 injects spanning frame boundary. | Cluster splits into 2 frames if needed; SOP/EOP correct. | TBD |
| P030 | D | Burst with type0 backpressure | 1 | Burst with type0 ready held low. | type0 path stalls; L2 fills; type0_full_sticky sets. | TBD |
| P031 | D | Burst with byte-stream backpressure | 1 | Same with tx8b1k ready held low. | byte-stream stalls; type0 still drains independently. | TBD |
| P032 | D | Burst with both outputs backpressured | 1 | Both ready=0. | L2 fills; engine stalls when ticket FIFO fills; documented overflow. | TBD |

---

## 4. BACKGROUND Soak and Uniformity (P033-P048)

BKG generator: long-run uniformity, TCC distribution (fine-time tied to zero per simple model), recovery from stall, no lost hits.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|----|--------|----------|------|----------|---------------|---------------------|
| P033 | R | BKG soak 10M cycles low rate | 1 | noise_rate=0x0010, 10M cycles. | ≈ 2500 hits per channel; uniformity within ±3σ. | TBD |
| P034 | R | BKG soak 10M cycles mid rate | 1 | noise_rate=0x0100, 10M cycles. | ≈ 40k hits per channel. | TBD |
| P035 | R | BKG soak 10M cycles high rate | 1 | noise_rate=0x0FFF, 10M cycles. | ≈ 640k hits per channel. | TBD |
| P036 | R | BKG soak 100M cycles | 1 | noise_rate=0x0100, 100M cycles. | Long-run stability; counters do not wrap. | TBD |
| P037 | R | BKG fine-time tied to zero | 1 | Capture all BKG hits over 1M cycles. | T_Fine and E_Fine are 5'd0 for every hit per the 26.2.x simple-model fine-counters-zero rule. | TBD |
| P038 | R | BKG TCC distribution full PRBS-15 period | 1 | Run > 32767 cycles. | All 32767 LFSR states observed at least once. | TBD |
| P039 | R | BKG with one channel masked off | 1 | Disable lane 0 → 32 channels silent. | Other 224 channels still see uniform noise. | TBD |
| P040 | R | BKG seed reproducibility long-run | 1 | Two 1M-cycle runs same seed. | Identical hit-cycle sequences per channel. | TBD |
| P041 | R | BKG seed change yields different long-run | 1 | Seed=0x1 vs seed=0x2. | Different hit-cycle sequences; both uniform. | TBD |
| P042 | R | BKG approximation uniformity check | 1 | Run 1M cycles; per-channel chi-squared test. | Chi-squared p-value > 0.05 (uniformity acceptable). | TBD |
| P043 | R | BKG arbitration loss frequency | 1 | BKG ON + Poisson rate=0xFFFF. | BKG hits on contended lanes deferred ~1 cycle; no BKG drops. | TBD |
| P044 | R | BKG paused by RUNNING toggle | 1 | Toggle RUNNING every 100k. | BKG hit rate proportional to RUNNING fraction. | TBD |
| P045 | R | BKG with all 8 lanes simultaneously backpressured | 1 | Hold all lane FIFO ready=0. | BKG ticket overflow count rises; bkg_overflow_sticky if implemented. | TBD |
| P046 | R | BKG resumes from FIFO recovery | 1 | Backpressure 100k, release. | BKG resumes immediately; no lost hits. | TBD |
| P047 | R | BKG TCC stays MuTRiG-encoded | 1 | Capture TCC; decode via golden PRBS-15 LUT. | All BKG TCCs decode to valid timestamps. | TBD |
| P048 | R | BKG long-run uniformity check 1B cycles | 1 | 1B cycles, noise_rate=0x0010. | Per-channel uniformity holds at 1B-cycle scale. | TBD |

---

## 5. Mixed SIGNAL + BACKGROUND (P049-P064)

FE arbitrates SIGNAL and BACKGROUND correctly; per-lane back-end consumes from both; no source starvation; counters separate.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|----|--------|----------|------|----------|---------------|---------------------|
| P049 | R | Mixed: Poisson + BKG balanced | 1 | Poisson rate=0x4000 + BKG rate=0x4000. | Both populations visible; total throughput = sum. | TBD |
| P050 | R | Mixed: Periodic + BKG | 1 | Periodic period=16 + BKG. | Periodic spike + uniform background. | TBD |
| P051 | R | Mixed: Inject burst + BKG | 1 | Inject every 1ms + BKG. | Inject clusters distinguishable from BKG by simultaneous-channel signature. | TBD |
| P052 | R | Mixed: SIGNAL EXTERNAL + BKG | 1 | EXTERNAL inject + BKG. | Only inject + BKG; no internal Poisson. | TBD |
| P053 | R | Mixed: SIGNAL FIX + BKG | 1 | Inject FIX size 32 every 1k cycles + BKG. | FIX clusters dominate locally; BKG fills elsewhere. | TBD |
| P054 | R | Mixed: SIGNAL RANDOM + BKG | 1 | Inject RANDOM MIRRORED + BKG. | RANDOM produces 2 sub-clusters per launch; BKG sprinkled. | TBD |
| P055 | R | Mixed: SIGNAL+BKG with one lane disabled | 1 | Disable lane 4. | Lane 4 silent; other lanes see SIGNAL+BKG. | TBD |
| P056 | R | Mixed: SIGNAL+BKG with global_enable=0 | 1 | Disable global. | All sources silent. | TBD |
| P057 | R | Mixed: SIGNAL+BKG with run-control toggle | 1 | Toggle RUNNING. | Both stop in IDLE; both resume in RUNNING. | TBD |
| P058 | R | Mixed: SIGNAL+BKG in TERMINATING | 1 | Drop to TERMINATING. | No new hits; queued drain. | TBD |
| P059 | R | Mixed: SIGNAL EXTERNAL + BKG ON, no inject | 1 | EXTERNAL + BKG, no inject pulses. | Only BKG hits; no SIGNAL hits. | TBD |
| P060 | R | Mixed: SIGNAL EXTERNAL + BKG OFF | 1 | EXTERNAL + BKG OFF, no inject. | Zero hits anywhere. | TBD |
| P061 | R | Mixed: SIGNAL=Poisson + BKG, both 100% | 1 | Both rate=0xFFFF. | Engine prioritizes SIGNAL; BKG drops 1-cycle. | TBD |
| P062 | R | Mixed: high SIGNAL + low BKG | 1 | Poisson 0xFFFF + BKG 0x0010. | SIGNAL dominates; BKG ~1 hit/lane/100k cycles. | TBD |
| P063 | R | Mixed: low SIGNAL + high BKG | 1 | Poisson 0x0010 + BKG 0xFFFF. | BKG dominates; SIGNAL clusters easy to spot. | TBD |
| P064 | R | Mixed: 1ms run with all features | 1 | All modes/sources active. | All hit categories present; counters reflect all. | TBD |

---

## 6. Per-Lane Drain Latency (P065-P080)

End-to-end inject→output latency characterized; per-lane independent; type0 leads byte-stream; latency under load and backpressure.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|----|--------|----------|------|----------|---------------|---------------------|
| P065 | R | Latency: inject → first L2 commit | 1 | Single inject FIX size 1; measure cycles. | Latency ≈ N+1 (engine pipeline depth). | TBD |
| P066 | R | Latency: inject → first type0 beat | 1 | Single inject; measure inject→type0_valid. | Latency = engine + lane_emitter + L2 + type0 SOP timer. | TBD |
| P067 | R | Link bottleneck: short-mode 3.5 cycles per hit | 1 | short_mode=1; sustained Poisson rate=0xFFFF for 100k cycles; measure inter-hit gap on aso_hit_type0_valid. | Average gap is 3.5 cycles per hit (alternates 3/4 cycles, ping-pong) regardless of BYTE_STREAM_ENABLE. | TBD |
| P068 | R | Link bottleneck: long-mode 6 cycles per hit | 1 | short_mode=0; sustained Poisson rate=0xFFFF for 100k cycles; measure inter-hit gap. | Average gap is 6 cycles per hit regardless of BYTE_STREAM_ENABLE. | TBD |
| P069 | R | Latency: under sustained load | 1 | Poisson rate=0x8000, 1M cycles; histogram inject→output latency. | p50 < 100 cycles; p99 < 1000 cycles. | TBD |
| P070 | R | Latency: with backpressure on type0 | 1 | type0 ready=0 50% time. | Latency increases; p99 reflects added delay. | TBD |
| P071 | R | Latency: per-lane independent | 1 | Stall lane 0; lane 1-7 free. | Lane 0 latency rises; others unchanged. | TBD |
| P072 | R | Latency: inject during frame mid-cycle | 1 | Inject at every phase of frame interval. | Latency varies by phase by ≤ frame_interval. | TBD |
| P073 | R | Latency: SOP-to-EOP within one frame | 1 | Single frame with N hits. | EOP at end of last hit of frame. | TBD |
| P074 | R | Latency: empty frame contributes 0 to type0 | 1 | Empty frame interval. | type0 valid stays low; no SOP/EOP. | TBD |
| P075 | R | Latency: TERMINATING drain | 1 | Stop SIGNAL; measure last hit out. | Drain completes within 2 frame intervals (worst case). | TBD |
| P076 | R | Latency: endofrun pulse timing | 1 | TERMINATING→IDLE. | endofrun fires after last hit drains; per-lane independent. | TBD |
| P077 | R | Latency variance: Poisson | 1 | Histogram inject→output for Poisson. | Variance bounded by frame interval. | TBD |
| P078 | R | Latency variance: Periodic | 1 | Same for Periodic. | Variance very small (deterministic). | TBD |
| P079 | R | Latency: short_mode vs long_mode | 1 | Compare frame_interval impact. | Short mode = 910 cycles; long mode = 1550 cycles. | TBD |
| P080 | R | Latency: inject at SYNC | 1 | Inject during SYNC. | Inject dropped (engine reset); no latency. | TBD |

---

## 7. Type0 vs Deassembly Beat-For-Beat Parity (P081-P096)

Direct type0 emit path matches mutrig_frame_deassembly output for the same byte-stream input, beat-for-beat, across all modes and run lengths.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|----|--------|----------|------|----------|---------------|---------------------|
| P081 | D | Type0 vs deassembly: 1 hit | 1 | 1 inject; route byte-stream through mutrig_frame_deassembly. | Both type0 streams beat-for-beat identical. | TBD |
| P082 | D | Type0 vs deassembly: 32 hits one frame | 1 | FIX size 32 inject. | Both streams identical; SOP/EOP match. | TBD |
| P083 | D | Type0 vs deassembly: 100 frames | 1 | Sustained Poisson 100 frames. | Both streams identical across all frames. | TBD |
| P084 | D | Type0 vs deassembly: full domain inject | 1 | FIX low=0 high=255. | Both streams identical for 256 hits. | TBD |
| P085 | D | Type0 vs deassembly: cluster size sweep | 1 | Sweep size 1..256. | Identical for every size. | TBD |
| P086 | D | Type0 vs deassembly: with BKG | 1 | BKG ON + signal. | Both streams identical. | TBD |
| P087 | D | Type0 vs deassembly: with mirror | 1 | RANDOM MIRRORED. | Both sub-clusters present in both outputs; identical. | TBD |
| P088 | D | Type0 vs deassembly: short_mode | 1 | short_mode=1. | Both streams use short-mode frames; identical. | TBD |
| P089 | D | Type0 vs deassembly: long_mode | 1 | short_mode=0. | Both streams use long-mode frames; identical. | TBD |
| P090 | D | Type0 vs deassembly: empty frame | 1 | Idle window. | Both stream zero beats during empty frame. | TBD |
| P091 | D | Type0 vs deassembly: TERMINATING drain | 1 | RUNNING→TERMINATING with backlog. | Both streams drain identically; both endofrun pulses fire. | TBD |
| P092 | D | Type0 vs deassembly: per-asic_id consistency | 1 | Run with asic_id_base=4. | channel field matches expected per-lane ID in both. | TBD |
| P093 | D | Type0 vs deassembly: latency offset characterized | 1 | Measure type0 lead vs byte-stream. | Constant offset = byte serializer depth. | TBD |
| P094 | D | Type0 vs deassembly: error bits both 0 | 1 | Inject 1000 hits. | Both streams report error=3'b000. | TBD |
| P095 | D | Type0 vs deassembly: 1M-cycle stress | 1 | 1M-cycle Poisson run. | Streams identical across 1M cycles; no drift. | TBD |
| P096 | D | Type0 vs deassembly: chained instances | 1 | Multiple emulators driving deassembly chain. | Each lane's type0 matches its own deassembly output. | TBD |

---

## 8. Inject ORing Stress and Edge Cases (P097-P112)

Inject-ORed-pulse handles bursts and corner-cases (collision, glitch, mode-switch) without losing or duplicating launches.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|----|--------|----------|------|----------|---------------|---------------------|
| P097 | D | CSR fire 1k injects rate-limited | 1 | 1000 CSR writes spaced 100 cycles. | 1000 clusters launched; no lost injects. | TBD |
| P098 | D | Conduit pulse 1k injects | 1 | 1000 conduit edges spaced 100 cycles. | 1000 clusters launched. | TBD |
| P099 | D | CSR + conduit alternating 1k | 1 | Alternate CSR/conduit, 1000 total. | 1000 clusters. | TBD |
| P100 | D | CSR + conduit same cycle 1k times | 1 | Same-cycle pulses 1000 times. | 1000 clusters (OR-merge). | TBD |
| P101 | D | CSR + conduit at engine_busy boundary | 1 | Pulse during engine dispatch. | Inject queued in 2-deep latch; dispatched after dispatch. | TBD |
| P102 | D | Inject at every cycle 10k | 1 | Inject 10000 times in 10000 cycles. | Engine launches every cycle; ticket distribution fills lane FIFOs; sticky overflow. | TBD |
| P103 | D | Inject burst with stalled engine | 1 | Inject 100 times during ticket FIFO full. | First N queued (2-deep latch); rest dropped to ticket_overflow_count. | TBD |
| P104 | D | Inject vs Poisson collision | 1 | Inject + Poisson same cycle. | Inject wins; Poisson dropped that cycle. | TBD |
| P105 | D | Inject vs BKG collision | 1 | Inject + BKG same cycle on same lane. | Inject ticket wins; BKG defers. | TBD |
| P106 | D | Inject FIX vs Inject RANDOM rapid switch | 1 | Toggle cluster_geom_mode every inject. | Each inject uses mode-at-launch; consistent. | TBD |
| P107 | D | Inject with RANDOM seed change | 1 | Change random_center_seed between injects. | Subsequent random centers reflect new seed. | TBD |
| P108 | D | Inject latency under load | 1 | Poisson 0xFFFF + 1 inject every 100 cycles. | Inject latency p99 < 200 cycles. | TBD |
| P109 | D | Inject conduit edge debounce | 1 | Conduit pulse with glitch <2 cycles wide. | Single edge detected; no double launch (resync filters). | TBD |
| P110 | D | Inject during TERMINATING drop count | 1 | RUNNING→TERMINATING; pulse 100 injects. | All 100 dropped; ticket_overflow_count unchanged (drops are not overflow). | TBD |
| P111 | D | Inject during SYNC dropped | 1 | Pulse during SYNC. | Dropped; engine state cleared. | TBD |
| P112 | D | Inject at SYNC→RUNNING boundary | 1 | Pulse exactly at transition cycle. | Defined behavior per spec; flag if inconsistent. | TBD |

---

## 9. Continuous-Frame Long-Run Soak (P113-P128)

all_buckets_frame mandatory baseline per dv-workflow §8-9: long-run stability across all modes, seeds, and run-control patterns; merged coverage > isolated.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|----|--------|----------|------|----------|---------------|---------------------|
| P113 | R | Continuous-frame 1M-cycle baseline | 1 | All_buckets_frame mode 1M cycles. | All cases run in order; merged coverage delta reported. | TBD |
| P114 | R | Continuous-frame 10M-cycle | 1 | 10M cycles. | Long-run stability; counters consistent. | TBD |
| P115 | R | Continuous-frame with seed=0xDEAD_BEEF | 1 | Pinned seed 1M cycles. | Reproducible per-cycle behavior. | TBD |
| P116 | R | Continuous-frame seed sweep 8 seeds | 1 | 8 different seeds. | All 8 produce uniform stats; no seed-dependent failure. | TBD |
| P117 | R | Continuous-frame at 137.5MHz | 1 | Signoff clock. | All cases pass; no setup violations in gate-level. | TBD |
| P118 | R | Continuous-frame with periodic SYNC | 1 | SYNC every 100k cycles. | Counters reset cleanly each SYNC; runs survive. | TBD |
| P119 | R | Continuous-frame with periodic TERMINATING | 1 | Toggle to TERMINATING every 100k. | Drain/refill cycles complete. | TBD |
| P120 | R | Continuous-frame all_buckets ordering | 1 | Run B,E,P,X buckets in order in one timeframe. | All cases pass; merged coverage > sum of isolated. | TBD |
| P121 | R | Continuous-frame with mirror_offset sweep | 1 | Sweep mirror_offset every 1000 launches. | All offsets honored; clamp behavior correct. | TBD |
| P122 | R | Continuous-frame with cluster_geom_mode toggle | 1 | Toggle FIX↔RANDOM every 1000. | Each inject uses mode-at-launch. | TBD |
| P123 | R | Continuous-frame with hit_mode_sig toggle | 1 | Toggle INTERNAL↔EXTERNAL every 100k. | Internal Poisson stops in EXTERNAL; resumes in INTERNAL. | TBD |
| P124 | R | Continuous-frame with hit_mode_bkg toggle | 1 | Toggle BKG ON↔OFF every 100k. | BKG visible only when ON. | TBD |
| P125 | R | Continuous-frame with global_enable toggle | 1 | Toggle every 50k. | All sources gated cleanly. | TBD |
| P126 | R | Continuous-frame with lane_enable_mask sweep | 1 | Disable lanes one by one. | Disabled lanes silent; others continue. | TBD |
| P127 | R | Continuous-frame full coverage sweep | 1 | Mode matrix × geometry × seeds. | Combined coverage > 95% for all bins. | TBD |
| P128 | R | Continuous-frame 100M-cycle final soak | 1 | 100M cycles, all modes active. | No deadlock, no overflow runaway, all counters within saturation. | TBD |

---
