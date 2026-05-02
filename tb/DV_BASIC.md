# emulator_mutrig DV — Basic Functional Cases

**Companion docs:** [DV_PLAN.md](DV_PLAN.md), [DV_BASIC.md](DV_BASIC.md), [DV_EDGE.md](DV_EDGE.md), [DV_PROF.md](DV_PROF.md), [DV_ERROR.md](DV_ERROR.md), `BUG_HISTORY.md`

**Parent:** [DV_PLAN.md](DV_PLAN.md)
**ID Range:** B001-B999
**Total:** 128 cases (128 implemented / 0 waived)

This bucket covers bring-up: every CSR field, run-control decode, SIGNAL INTERNAL (Poisson and Periodic), EXTERNAL inject (CSR fire OR'd with conduit pulse), FIX and RANDOM cluster geometry with all mirror modes, and BACKGROUND IID per-channel noise. Every case in this bucket must pass before EDGE / PROF / ERROR cases are meaningful — failures here imply the front-end or back-end is structurally broken.

**Methodology key:**
- **D** = Directed (hand-crafted stimulus, deterministic)
- **R** = Constrained-random (LCG-based PRNG; no SystemVerilog `rand`)

---

## 1. Summary

| Section | Cases | ID Range | What it Proves | Current Case |
|---------|-------|----------|----------------|--------------|
| Common CSR Golden Header | 16 | B001-B016 | Validates the 7-word common Mu3e CSR header (UID/META/SCRATCH/LAST_RD_ADDR/LAST_RD_DATA/LAST_WR_ADDR/LAST_WR_DATA at 0x00..0x06). Required for any host-driven configuration of this IP. | 16/16 |
| Run-Control Decode and Gating | 16 | B017-B032 | FE run-control decoder routes the 9-bit one-hot AvST sink correctly: only RUNNING generates new hits; TERMINATING drains; SYNC/RESET clears state; global_enable is the master gate. | 16/16 |
| SIGNAL INTERNAL Poisson | 16 | B033-B048 | Internal Poisson generator launches at the configured rate, deterministically reseedable, gated by hit_mode_sig. | 16/16 |
| SIGNAL INTERNAL Periodic | 16 | B049-B064 | Internal Periodic generator: 16-bit phase accumulator with the configured rate, deterministic period, no PRNG dependence on launch timing. | 16/16 |
| SIGNAL External Inject (CSR + Conduit) | 16 | B065-B080 | Single inject port (conduit) OR'd with FIRE.fire_inject_pulse W1P; fires regardless of hit_mode_sig; gated only by global_enable. | 16/16 |
| CLUSTER_GEOM_FIX | 16 | B081-B096 | FIX cluster geometry: explicit low/high in global 0..255, cross-SMB allowed, all hits share one TCC anchor. | 16/16 |
| CLUSTER_GEOM_RANDOM (mirror modes) | 16 | B097-B112 | RANDOM cluster geometry: random center within selected SMB, mirror_mode {LEFT_ONLY, RIGHT_ONLY, MIRRORED}, mirror_offset applied only when MIRRORED, never crosses SMB boundary. | 16/16 |
| BACKGROUND IID Generator | 16 | B113-B128 | FE BACKGROUND generator: rolling per-channel scan, folded Bernoulli at configured noise_rate, lands hits on the right lane, jitters fine times, ungated by hit_mode_sig. | 16/16 |

---

## 2. Common CSR Golden Header (B001-B016)

Validates the 7-word common Mu3e CSR header (UID/META/SCRATCH/LAST_RD_ADDR/LAST_RD_DATA/LAST_WR_ADDR/LAST_WR_DATA at 0x00..0x06). Required for any host-driven configuration of this IP.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|----|--------|----------|------|----------|---------------|---------------------|
| B001 | D | UID readback | 1 | Read 0x00 after reset. | Returns ASCII 'EMUT' (0x454D5554). | TBD |
| B002 | D | UID is RO (write ignored) | 1 | Write 0xDEADBEEF to 0x00, read back. | Read still returns 0x454D5554. | TBD |
| B003 | D | META selector page 0 (VERSION) | 1 | Write 0 to 0x01, read 0x01. | Returns VERSION packed MAJOR[31:24]/MINOR[23:16]/PATCH[15:12]/BUILD[11:0]. | TBD |
| B004 | D | META selector page 1 (DATE) | 1 | Write 1 to 0x01, read 0x01. | Returns VERSION_DATE generic. | TBD |
| B005 | D | META selector page 2 (GIT) | 1 | Write 2 to 0x01, read 0x01. | Returns VERSION_GIT generic. | TBD |
| B006 | D | META selector page 3 (INSTANCE_ID) | 1 | Write 3 to 0x01, read 0x01. | Returns INSTANCE_ID generic. | TBD |
| B007 | D | SCRATCH write/read 0xDEADBEEF | 1 | Write 0xDEADBEEF to 0x02, read back. | Read returns 0xDEADBEEF; bus liveness OK. | TBD |
| B008 | D | SCRATCH write/read 0x12345678 | 1 | Write 0x12345678 to 0x02, read back. | Read returns 0x12345678. | TBD |
| B009 | D | SCRATCH reset value | 1 | Read 0x02 immediately after reset. | Returns 0x00000000. | TBD |
| B010 | D | LAST_RD_ADDR captures last read addr | 1 | Read 0x14, then read 0x03. | 0x03 returns 0x14 in [4:0]. | TBD |
| B011 | D | LAST_RD_DATA captures last read data | 1 | Read 0x00 (UID), then read 0x04. | 0x04 returns 0x454D5554. | TBD |
| B012 | D | LAST_RD_* not self-mutating | 1 | Read 0x03 twice in a row. | Both reads return the SAME captured addr (the read of 0x03 itself does not overwrite the snapshot). | TBD |
| B013 | D | LAST_WR_ADDR captures last write addr | 1 | Write 0xAA to 0x02, then read 0x05. | 0x05 returns 0x02 in [4:0]. | TBD |
| B014 | D | LAST_WR_DATA captures last write data | 1 | Write 0xBEEF to 0x02, then read 0x06. | 0x06 returns 0xBEEF. | TBD |
| B015 | D | Identity reset clears LAST_* | 1 | Assert i_rst, deassert, read 0x03/0x04/0x05/0x06. | All four return 0. | TBD |
| B016 | D | CSR address > 0x3F unmapped | 1 | Read 0x3F (max 6-bit) and 0x40 (out of range). | 0x3F returns reserved=0; 0x40 wraps or returns 0 per AVMM behavior. | TBD |

---

## 3. Run-Control Decode and Gating (B017-B032)

FE run-control decoder routes the 9-bit one-hot AvST sink correctly: only RUNNING generates new hits; TERMINATING drains; SYNC/RESET clears state; global_enable is the master gate.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|----|--------|----------|------|----------|---------------|---------------------|
| B017 | D | IDLE → RUN_PREPARE transition | 1 | Drive ctrl AvST = bit[1] one-hot. | ctrl_state_q latches; no hits generated. | TBD |
| B018 | D | RUN_PREPARE → SYNC | 1 | Drive ctrl AvST = bit[2] one-hot. | emu_rst pulses; LFSRs and FIFOs reset; no hits generated. | TBD |
| B019 | D | SYNC → RUNNING | 1 | Drive ctrl AvST = bit[3] one-hot. | run_generating asserts; engine starts launching per SIGNAL. | TBD |
| B020 | D | RUNNING → TERMINATING | 1 | Drive ctrl AvST = bit[4] one-hot. | run_generating deasserts; run_draining stays high; queued hits drain. | TBD |
| B021 | D | TERMINATING → IDLE | 1 | Drive ctrl AvST = bit[0] one-hot. | run_draining deasserts; line idles K28.5; type0 endofrun pulse asserts once per lane. | TBD |
| B022 | D | RESET state forces emu_rst | 1 | Drive ctrl AvST = bit[7] one-hot. | All FE/BE state cleared; identical to cold reset. | TBD |
| B023 | D | OUT_OF_DAQ leaves outputs idle | 1 | Drive ctrl AvST = bit[8] one-hot. | No hits generated; line idles K28.5; type0 valid low. | TBD |
| B024 | D | LINK_TEST asserts but no hits | 1 | Drive ctrl AvST = bit[5] one-hot. | run_generating low; engine silent. | TBD |
| B025 | D | SYNC_TEST asserts but no hits | 1 | Drive ctrl AvST = bit[6] one-hot. | run_generating low; engine silent. | TBD |
| B026 | D | Stale ctrl_state_q without valid | 1 | Latch RUNNING then drop ctrl AvST valid for 100 cycles. | ctrl_state_q retains RUNNING; engine keeps running. | TBD |
| B027 | D | Multi-bit one-hot rejected (illegal) | 1 | Drive bit[3] OR bit[4] simultaneously. | ctrl_state_q latches the ill word; engine response defined by table — see DV_HARNESS. | TBD |
| B028 | D | Run-control valid back-to-back | 1 | Drive RUN_PREPARE then SYNC then RUNNING in 3 consecutive cycles. | All three transitions latch; final state RUNNING; engine starts. | TBD |
| B029 | D | RUN_PREPARE alone holds frame_rst | 1 | Drive RUN_PREPARE for 200 cycles. | frame_rst high entire window; LFSRs do not free-run. | TBD |
| B030 | D | Inject during IDLE is suppressed | 1 | Pulse coe_inject_pulse while ctrl_state_q=IDLE. | No cluster launched; no L2 push; no type0 beats. | TBD |
| B031 | D | global_enable=0 gates RUNNING | 1 | Set CENTRAL.global_enable=0; drive RUNNING; pulse inject. | No hits generated; no type0 beats. | TBD |
| B032 | D | global_enable rising while RUNNING | 1 | RUNNING with global_enable=0 → set global_enable=1 mid-run. | Engine starts launching from the next cycle. | TBD |

---

## 4. SIGNAL INTERNAL Poisson (B033-B048)

Internal Poisson generator launches at the configured rate, deterministically reseedable, gated by hit_mode_sig.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|----|--------|----------|------|----------|---------------|---------------------|
| B033 | D | Smoke: hit_rate=0, expect zero hits | 10 | SIGNAL=INTERNAL, sub_mode=POISSON, RATES.hit_rate=0, RUNNING for 10000 cycles. | Zero L2 commits, zero type0 beats. | TBD |
| B034 | R | hit_rate=0x0001 → very rare | 10 | RATES.hit_rate=1, run 100k cycles, count launches. | Launches ≈ 100000/65536 ≈ 1-2. | TBD |
| B035 | R | hit_rate=0x0100 → ~1/256 | 10 | RATES.hit_rate=0x0100, run 65k cycles. | Launches ≈ 256 ± 3σ. | TBD |
| B036 | R | hit_rate=0x1000 → ~1/16 | 10 | RATES.hit_rate=0x1000, run 16k cycles. | Launches ≈ 1000 ± 3σ. | TBD |
| B037 | R | hit_rate=0x8000 → ~50% | 10 | RATES.hit_rate=0x8000, run 4096 cycles. | Launches ≈ 2048 ± 3σ. | TBD |
| B038 | R | hit_rate=0xFFFF → near 100% | 10 | RATES.hit_rate=0xFFFF, run 1024 cycles. | Launches ≈ 1024 (every cycle if engine not stalled). | TBD |
| B039 | D | PRNG seed reproducibility | 10 | Run twice with same PRNG_SEED=0xDEADBEEF. | Identical L2 hit sequence per lane. | TBD |
| B040 | D | PRNG seed change yields different sequence | 10 | Run with seed=0x1; then seed=0x2. | Different launch cycles; different hit sequences. | TBD |
| B041 | R | Launch fires at cycle N if prng[15:0]<rate | 1 | Pin PRNG to known seed; trace launches. | Each launch coincides with cycle whose prng_state[15:0] < hit_rate (golden compute). | TBD |
| B042 | R | Cluster size 1 makes one hit per launch | 10 | Poisson with FIX low=high=10, 1000 launches. | 1000 hits on lane 0 channel 10. | TBD |
| B043 | R | Cluster size 32 spans one full lane | 10 | Poisson with FIX low=0 high=31, 100 launches. | Each launch produces 32 hits across one ticket on lane 0. | TBD |
| B044 | R | Disabled lane sees no hits in Poisson | 10 | Set LANE_ENABLE bit 3 = 0; Poisson with cluster center=100 (lane 3). | Lane 3 stays idle K28.5; other lanes see hits. | TBD |
| B045 | R | Engine stalls on full lane FIFO | 10 | Poisson at hit_rate=0xFFFF with all lane consumers held off. | ticket_overflow_count increments after queue fills. | TBD |
| B046 | R | Resume after lane FIFO drains | 10 | Stall lane FIFO 1000 cycles, then release. | Engine resumes launching; no spurious hits. | TBD |
| B047 | R | Poisson with BACKGROUND off | 10 | BACKGROUND.hit_mode_bkg=0. | Only Poisson hits visible; per-channel uniform-rate test fails. | TBD |
| B048 | R | hit_mode_sig=EXTERNAL silences Poisson | 10 | Switch SIGNAL.hit_mode_sig=EXTERNAL mid-run. | Poisson stops immediately; only inject pulses produce hits. | TBD |

---

## 5. SIGNAL INTERNAL Periodic (B049-B064)

Internal Periodic generator: 16-bit phase accumulator with the configured rate, deterministic period, no PRNG dependence on launch timing.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|----|--------|----------|------|----------|---------------|---------------------|
| B049 | D | Period 1 cycle (rate=0xFFFF) | 1 | Periodic mode, hit_rate=0xFFFF. | Phase accumulator overflows every cycle; launch every cycle (subject to engine_busy). | TBD |
| B050 | D | Period 2 cycles (rate=0x8000) | 1 | Periodic, rate=0x8000. | Launch every 2 cycles. | TBD |
| B051 | D | Period 4 cycles (rate=0x4000) | 1 | Periodic, rate=0x4000. | Launch every 4 cycles. | TBD |
| B052 | D | Period 16 cycles (rate=0x1000) | 1 | Periodic, rate=0x1000. | Launch every 16 cycles ± 1 (phase-accumulator beat). | TBD |
| B053 | D | Period 256 cycles (rate=0x0100) | 1 | Periodic, rate=0x0100. | Launch every 256 cycles ± 1. | TBD |
| B054 | D | rate=0 stops Periodic | 1 | Periodic, rate=0, run 10k cycles. | Zero launches. | TBD |
| B055 | D | Phase accumulator persists across stall | 1 | Stall a lane mid-period. | Phase resumes after stall; period preserved. | TBD |
| B056 | D | emu_rst clears phase | 1 | Pulse emu_rst mid-run. | Phase reset to 0; first launch after reset is at full period. | TBD |
| B057 | D | Periodic vs Poisson selector toggle | 1 | Switch internal_sub_mode mid-run. | Periodic stream stops; Poisson takes over. | TBD |
| B058 | D | Periodic with FIX cluster | 1 | Periodic launches at FIX low=64 high=95. | Each launch produces 32 hits split across lanes 2 and 3. | TBD |
| B059 | D | Periodic with RANDOM mirrored | 1 | Periodic + RANDOM, mirror_mode=MIRRORED, size=4. | Each launch produces 4 hits per side, primary+mirror, same TCC. | TBD |
| B060 | D | Periodic period stable under load | 1 | Periodic rate=0x4000, all lanes pushing. | Inter-launch interval ±1 cycle across 100 launches. | TBD |
| B061 | D | seed independence: Periodic is not PRNG-driven | 1 | Periodic with two different PRNG_SEEDs. | Launch pattern identical (Periodic uses phase accumulator only). | TBD |
| B062 | D | Periodic fine times still PRNG-jittered | 1 | Periodic, observe T_Fine across launches. | T_Fine values vary per cluster (lane fine PRNG). | TBD |
| B063 | D | Periodic + BACKGROUND ON | 1 | Periodic + bkg_mode=ON. | Both streams visible; Periodic clean periodic spacing in TCC. | TBD |
| B064 | D | Periodic gated by global_enable | 1 | Set global_enable=0 mid-Periodic. | Stream stops; resumes on re-enable. | TBD |

---

## 6. SIGNAL External Inject (CSR + Conduit) (B065-B080)

Single inject port (conduit) OR'd with FIRE.fire_inject_pulse W1P; fires regardless of hit_mode_sig; gated only by global_enable.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|----|--------|----------|------|----------|---------------|---------------------|
| B065 | D | CSR fire alone produces 1 cluster | 1 | Write FIRE.fire_inject_pulse=1; observe. | Exactly one cluster launched; W1P bit reads back 0. | TBD |
| B066 | D | Conduit pulse alone produces 1 cluster | 1 | Pulse coe_inject_pulse for 1 cycle. | Exactly one cluster launched. | TBD |
| B067 | D | CSR + conduit same cycle = 1 cluster | 1 | Pulse both same cycle. | Exactly one cluster (OR-merged before edge-detect). | TBD |
| B068 | D | CSR + conduit adjacent cycles = 2 clusters | 1 | Pulse CSR cycle N, conduit cycle N+1. | Two clusters; edge-detect catches both edges. | TBD |
| B069 | D | Inject works in INTERNAL mode | 1 | hit_mode_sig=INTERNAL; pulse inject. | Inject cluster appears on top of internal Poisson stream. | TBD |
| B070 | D | Inject works in EXTERNAL mode | 1 | hit_mode_sig=EXTERNAL; pulse inject. | Inject cluster appears; no internal Poisson. | TBD |
| B071 | D | Inject in EXTERNAL with hit_rate>0 | 1 | hit_mode_sig=EXTERNAL; rate=0xFFFF; only inject fires. | Internal generator silent; only inject-driven clusters. | TBD |
| B072 | D | Inject gated by global_enable | 1 | global_enable=0; pulse inject. | No cluster generated. | TBD |
| B073 | D | Inject suppressed in IDLE | 1 | ctrl=IDLE; pulse inject. | No cluster (run_generating low). | TBD |
| B074 | D | Inject in TERMINATING is dropped | 1 | ctrl=TERMINATING; pulse inject. | No new cluster; existing drain continues. | TBD |
| B075 | D | Inject during SYNC dropped | 1 | ctrl=SYNC; pulse inject. | No cluster (engine reset). | TBD |
| B076 | D | Inject conduit edge-detect (level held high) | 1 | Hold coe_inject_pulse high for 100 cycles. | Exactly one cluster (only the rising edge). | TBD |
| B077 | D | Inject CSR W1P single-shot | 1 | Write FIRE=1 once; check pulse asserts for 1 cycle internally. | One cluster; subsequent reads return 0; no replay. | TBD |
| B078 | D | Inject simultaneous with internal launch | 1 | hit_mode_sig=INTERNAL Poisson at hit_rate=0xFFFF; pulse inject. | Inject wins; internal launch dropped that cycle (per §2.3 priority). | TBD |
| B079 | D | Inject FIX cluster at center | 1 | FIX low=120 high=135; pulse inject. | Cluster spans lanes 3 and 4; same TCC. | TBD |
| B080 | D | Inject RANDOM mirrored | 1 | RANDOM mirror_mode=MIRRORED, size=8; pulse inject. | Primary cluster on random side + mirror cluster on other side; same TCC. | TBD |

---

## 7. CLUSTER_GEOM_FIX (B081-B096)

FIX cluster geometry: explicit low/high in global 0..255, cross-SMB allowed, all hits share one TCC anchor.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|----|--------|----------|------|----------|---------------|---------------------|
| B081 | D | FIX low=high single channel ch0 | 1 | FIX low=0 high=0; inject. | 1 hit on lane 0 ch 0. | TBD |
| B082 | D | FIX low=high ch127 (SMB A last) | 1 | FIX low=127 high=127; inject. | 1 hit on lane 3 ch 31. | TBD |
| B083 | D | FIX low=high ch128 (SMB B first) | 1 | FIX low=128 high=128; inject. | 1 hit on lane 4 ch 0. | TBD |
| B084 | D | FIX low=high ch255 (SMB B last) | 1 | FIX low=255 high=255; inject. | 1 hit on lane 7 ch 31. | TBD |
| B085 | D | FIX size 32 within one lane | 1 | FIX low=0 high=31; inject. | 32 hits on lane 0 ch 0..31; one ticket. | TBD |
| B086 | D | FIX size 33 spans lanes 0+1 | 1 | FIX low=0 high=32; inject. | 32 hits on lane 0 + 1 hit on lane 1; two tickets; same TCC. | TBD |
| B087 | D | FIX size 64 spans lanes 0+1 | 1 | FIX low=0 high=63; inject. | 32 hits on lane 0 + 32 hits on lane 1. | TBD |
| B088 | D | FIX size 128 spans full SMB A | 1 | FIX low=0 high=127; inject. | 32 hits each on lanes 0..3; 4 tickets; same TCC. | TBD |
| B089 | D | FIX size 129 spans SMBs A and B | 1 | FIX low=0 high=128; inject. | Lanes 0..3 full + lane 4 ch 0; cross-SMB allowed in FIX. | TBD |
| B090 | D | FIX size 256 full domain | 1 | FIX low=0 high=255; inject. | All 8 lanes get full ticket; 256 hits same TCC. | TBD |
| B091 | D | FIX low>high illegal | 1 | Set FIX low=10 high=5; inject. | Engine drops launch; ticket_overflow_count unchanged; sticky-bit flag set. | TBD |
| B092 | D | FIX low=high mid-lane | 1 | FIX low=70 high=70; inject. | 1 hit on lane 2 ch 6. | TBD |
| B093 | D | FIX size 31 inside one lane (no boundary) | 1 | FIX low=33 high=63; inject. | 31 hits on lane 1 ch 1..31; one ticket. | TBD |
| B094 | D | FIX size 33 mid-domain | 1 | FIX low=63 high=95; inject. | 1 hit lane 1 ch 31 + 32 hits lane 2 ch 0..31. | TBD |
| B095 | D | FIX with disabled lane mid-cluster | 1 | Disable LANE_ENABLE bit 1; FIX low=0 high=63. | Lane 0 emits 32 hits; lane 1 idle (no ticket consumed). | TBD |
| B096 | D | FIX cluster timestamp anchor identical | 1 | FIX low=0 high=255; inject; capture TCC of every hit. | All 256 hits share one TCC anchor. | TBD |

---

## 8. CLUSTER_GEOM_RANDOM (mirror modes) (B097-B112)

RANDOM cluster geometry: random center within selected SMB, mirror_mode {LEFT_ONLY, RIGHT_ONLY, MIRRORED}, mirror_offset applied only when MIRRORED, never crosses SMB boundary.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|----|--------|----------|------|----------|---------------|---------------------|
| B097 | D | RANDOM size=1 LEFT_ONLY | 1 | RANDOM size=1, mirror_mode=LEFT_ONLY; inject. | 1 hit on side A only; 0 hits on side B. | TBD |
| B098 | D | RANDOM size=1 RIGHT_ONLY | 1 | RANDOM size=1, mirror_mode=RIGHT_ONLY; inject. | 0 hits side A; 1 hit side B. | TBD |
| B099 | D | RANDOM size=1 MIRRORED offset=0 | 1 | RANDOM size=1, MIRRORED, offset=0; inject; pin PRNG to center=10. | Hit at A:ch10 + hit at B:ch117 (=127-10); same TCC. | TBD |
| B100 | D | RANDOM size=1 MIRRORED offset=+5 | 1 | Same; offset=+5. | Hit at A:ch10 + hit at B:ch122 (=127-10+5). | TBD |
| B101 | D | RANDOM size=1 MIRRORED offset=-5 | 1 | Same; offset=-5. | Hit at A:ch10 + hit at B:ch112. | TBD |
| B102 | D | RANDOM size=8 MIRRORED offset=0 | 1 | size=8 MIRRORED; pin center=64. | Hits A:ch60..67 + B:ch60..67 (mirror of 60..67 with offset 0). | TBD |
| B103 | D | RANDOM size=128 MIRRORED full SMB | 1 | size=128 MIRRORED; any pin. | All 128 ch on both sides. | TBD |
| B104 | D | RANDOM size=64 LEFT_ONLY mid-side | 1 | size=64 LEFT_ONLY; pin center=64. | Hits A:ch32..95; no side B activity. | TBD |
| B105 | D | RANDOM size=128 LEFT_ONLY | 1 | size=128 LEFT_ONLY. | Full SMB A; SMB B silent. | TBD |
| B106 | D | RANDOM mirror_offset clamped at SMB edge | 1 | size=4 MIRRORED, offset=+200. | Mirror cluster clamped to fit within SMB B (no spillover). | TBD |
| B107 | D | RANDOM size=0 treated as size=1 | 1 | size=0; inject. | 1 hit (per normalize_cluster_size). | TBD |
| B108 | D | RANDOM center distribution uniform | 1 | size=1 LEFT_ONLY, 1000 injects. | Per-channel hit count within ±3σ of uniform 1000/128 ≈ 7.8. | TBD |
| B109 | D | RANDOM seed reproducibility | 1 | Same PRNG_SEED + same random_center_seed. | Identical center sequence across runs. | TBD |
| B110 | D | RANDOM with global_enable=0 | 1 | global_enable=0; inject RANDOM. | No hits. | TBD |
| B111 | D | RANDOM never crosses SMB boundary | 1 | size=128 LEFT_ONLY 1000 trials. | Zero hits land on side B. | TBD |
| B112 | D | RANDOM MIRRORED side_pick uniform | 1 | MIRRORED size=1, 1000 injects. | Primary-on-A vs primary-on-B counts within ±3σ of 500/500. | TBD |

---

## 9. BACKGROUND IID Generator (B113-B128)

FE BACKGROUND generator: rolling per-channel scan, folded Bernoulli at configured noise_rate, lands hits on the right lane, jitters fine times, ungated by hit_mode_sig.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|----|--------|----------|------|----------|---------------|---------------------|
| B113 | D | BKG OFF produces no noise hits | 1 | bkg_mode=OFF, signal=OFF. | Zero hits. | TBD |
| B114 | D | BKG ON noise_rate=0 | 1 | bkg_mode=ON, noise_rate=0. | Zero hits. | TBD |
| B115 | R | BKG noise_rate=0x0001 | 1 | bkg_mode=ON, noise_rate=1, 100k cycles. | ≈ 100k/65536 ≈ 1-2 hits per channel. | TBD |
| B116 | R | BKG noise_rate=0x0100 | 1 | noise_rate=0x100, 65k cycles. | ≈ 256 hits per channel ± 3σ. | TBD |
| B117 | R | BKG noise_rate=0xFFFF | 1 | noise_rate=0xFFFF, 1024 cycles. | ≈ 1024 hits per channel (folded scan saturates). | TBD |
| B118 | D | BKG hit lands on correct lane | 1 | noise_rate=0x4000, observe lane field. | Each hit's local channel is consistent with lane index = scan_pos[7:5]. | TBD |
| B119 | D | BKG fine-time has jitter | 1 | Capture 100 BKG hits on one channel. | T_Fine values span at least 4 codes. | TBD |
| B120 | D | BKG TCC monotonic per channel | 1 | Capture 100 BKG hits on one channel. | TCC sequence reflects PRBS-15 stepping; no repeats unless 32767-cycle cycle. | TBD |
| B121 | D | BKG + SIGNAL Poisson coexist | 1 | bkg=ON, signal=Poisson. | Both streams visible; per-channel counts include both populations. | TBD |
| B122 | D | BKG + SIGNAL inject coexist | 1 | bkg=ON, periodic inject every 1000 cycles. | Inject clusters distinguishable by simultaneous-ch pattern; BKG sprinkled in between. | TBD |
| B123 | D | BKG paused by ctrl != RUNNING | 1 | bkg=ON; drop to TERMINATING. | BKG stops generating new hits; queued hits drain. | TBD |
| B124 | D | BKG paused by global_enable=0 | 1 | bkg=ON; global_enable=0. | BKG stops; SIGNAL also stops. | TBD |
| B125 | D | BKG seed reproducibility | 1 | Same PRNG_SEED → identical BKG hit times. | Per-channel hit cycle sequence identical across runs. | TBD |
| B126 | R | BKG per-channel rate uniformity | 1 | Run 100k cycles; tally per-channel counts. | All 256 channel counts within ±3σ of mean. | TBD |
| B127 | D | BKG arbitration loses to SIGNAL | 1 | Same-cycle SIGNAL+BKG on same lane. | SIGNAL ticket wins; BKG ticket waits one cycle. | TBD |
| B128 | D | BKG drives all 256 channels eventually | 1 | Run 1M cycles, noise_rate=0x4000. | All 256 channels show >0 hits. | TBD |

---
