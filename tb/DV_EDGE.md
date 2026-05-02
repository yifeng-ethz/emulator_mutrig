# emulator_mutrig DV — Edge and Corner Cases

**Companion docs:** [DV_PLAN.md](DV_PLAN.md), [DV_BASIC.md](DV_BASIC.md), [DV_EDGE.md](DV_EDGE.md), [DV_PROF.md](DV_PROF.md), [DV_ERROR.md](DV_ERROR.md), `BUG_HISTORY.md`

**Parent:** [DV_PLAN.md](DV_PLAN.md)
**ID Range:** E001-E999
**Total:** 128 cases (128 implemented / 0 waived)

This bucket exercises boundaries that production code can drift through silently: channel-range off-by-one, cluster-size 1/0/128/256 boundaries, mirror_offset clamp at SMB edges, SMB boundary discipline, lane-enable interactions with cluster decode, ECC seed phase sweep, frame-boundary races, per-lane counter saturation at 32-bit and 60-bit, and CSR aliasing / reserved-bit discipline.

**Methodology key:**
- **D** = Directed (hand-crafted stimulus, deterministic)
- **R** = Constrained-random (LCG-based PRNG; no SystemVerilog `rand`)

---

## 1. Summary

| Section | Cases | ID Range | What it Proves | Current Case |
|---------|-------|----------|----------------|--------------|
| Channel-Range Boundaries | 16 | E001-E016 | Off-by-one safety in channel-range decode: lane boundary, SMB boundary, full-domain boundary, disabled-lane interaction. | 16/16 |
| Cluster Size and Geometry Boundaries | 16 | E017-E032 | Cluster-size boundary: 1, 2, 3, 128, 0, >128; center boundary in RANDOM with clamp; inject queue depth boundary. | 16/16 |
| Mirror Offset and Mode Boundaries | 16 | E033-E048 | mirror_offset signed encoding, clamp behavior at SMB edges, mode-only-applies-when-MIRRORED, mode-change-mid-run. | 16/16 |
| SMB Boundary and Lane-Enable Interactions | 16 | E049-E064 | SMB boundary discipline (RANDOM never crosses; FIX may cross), lane-enable interaction with cluster decode and asic_id_base. | 16/16 |
| ECC Seed Phase / Delay Sweep | 16 | E065-E080 | Two-LFSR independent seeds realize configurable ECC-after-TCC delay; user computes seed offset offline; emulator stores no LFSR-step↔time mapping. | 16/16 |
| Frame Boundary Race Conditions | 16 | E081-E096 | Frame-interval timer correctly delineates SOP/EOP for type0; short/long mode period correct; frame_count and hit_count saturate cleanly. | 16/16 |
| Per-Lane Counter Saturation and Sticky Bits | 16 | E097-E112 | Per-lane 64-bit frame_count/hit_count saturate cleanly; sticky bits W1C; bank counters saturate; lo/hi atomic read. | 16/16 |
| CSR Aliasing, Reserved Bits, and Stub Fields | 16 | E113-E128 | All reserved bits read 0; reserved addresses read 0; CSR independent of run-control state; ERROR_INJECT stub stores but does not act. | 16/16 |

---

## 2. Channel-Range Boundaries (E001-E016)

Off-by-one safety in channel-range decode: lane boundary, SMB boundary, full-domain boundary, disabled-lane interaction.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|----|--------|----------|------|----------|---------------|---------------------|
| E001 | D | FIX boundary low=0 | 1 | FIX low=0 high=0 | 1 hit on lane 0 ch 0; no off-by-one underflow. | TBD |
| E002 | D | FIX boundary high=255 | 1 | FIX low=255 high=255 | 1 hit on lane 7 ch 31; no off-by-one overflow. | TBD |
| E003 | D | FIX boundary low=high=128 (SMB B first) | 1 | FIX low=128 high=128 | 1 hit on lane 4 ch 0; no SMB-A spillover. | TBD |
| E004 | D | FIX boundary low=127 high=128 (cross-SMB) | 1 | FIX low=127 high=128 | 1 hit lane 3 ch 31 + 1 hit lane 4 ch 0; same TCC. | TBD |
| E005 | D | FIX boundary low=31 high=32 (cross-lane within SMB A) | 1 | FIX low=31 high=32 | 1 hit lane 0 ch 31 + 1 hit lane 1 ch 0. | TBD |
| E006 | D | FIX boundary low=159 high=160 (cross-lane within SMB B) | 1 | FIX low=159 high=160 | 1 hit lane 4 ch 31 + 1 hit lane 5 ch 0. | TBD |
| E007 | D | FIX cluster at lane7 last channel | 1 | FIX low=255 high=255 | Lane 7 ch 31; no out-of-range. | TBD |
| E008 | D | FIX size = full domain (256) | 1 | FIX low=0 high=255 | All 8 lanes get full 32-ch ticket. | TBD |
| E009 | D | FIX size 256 with one lane disabled | 1 | FIX low=0 high=255, LANE_ENABLE bit 4 = 0 | 7 lanes get hits; lane 4 silent. | TBD |
| E010 | D | FIX size 33 spanning lane 3-4 | 1 | FIX low=127 high=159 | Lane 3 ch 31 + lane 4 ch 0..31. | TBD |
| E011 | D | FIX size 96 spanning lanes 1-3 | 1 | FIX low=32 high=127 | Lanes 1,2,3 full. | TBD |
| E012 | D | FIX size 96 spanning lanes 4-6 | 1 | FIX low=128 high=223 | Lanes 4,5,6 full. | TBD |
| E013 | D | FIX size 8 at lane7 boundary | 1 | FIX low=248 high=255 | Lane 7 ch 24..31. | TBD |
| E014 | D | FIX size 8 spanning lane6-7 boundary | 1 | FIX low=220 high=227 | Lane 6 ch 28..31 + lane 7 ch 0..3. | TBD |
| E015 | D | FIX boundary at SMB middle (low=64 high=64) | 1 | FIX low=64 high=64 | Lane 2 ch 0; mid-SMB-A boundary. | TBD |
| E016 | D | FIX boundary at SMB middle (low=192 high=192) | 1 | FIX low=192 high=192 | Lane 6 ch 0; mid-SMB-B boundary. | TBD |

---

## 3. Cluster Size and Geometry Boundaries (E017-E032)

Cluster-size boundary: 1, 2, 3, 128, 0, >128; center boundary in RANDOM with clamp; inject queue depth boundary.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|----|--------|----------|------|----------|---------------|---------------------|
| E017 | D | RANDOM size=1 minimum | 1 | RANDOM size=1, MIRRORED, offset=0, pin center=63. | Primary A:ch63 + mirror B:ch64. | TBD |
| E018 | D | RANDOM size=2 even-size | 1 | RANDOM size=2, MIRRORED, offset=0, pin center=63. | Primary A:ch62-63 + mirror B:ch64-65. | TBD |
| E019 | D | RANDOM size=3 odd-size | 1 | RANDOM size=3, MIRRORED, offset=0, pin center=63. | Primary A:ch62-64 + mirror B:ch63-65. | TBD |
| E020 | D | RANDOM size=128 max within SMB | 1 | RANDOM size=128, MIRRORED. | Full SMB A + full SMB B (any center clamps). | TBD |
| E021 | D | RANDOM size>128 saturates to 128 | 1 | RANDOM size=200; check actual cluster. | Cluster bounded to 128 channels per side. | TBD |
| E022 | D | RANDOM size=0 normalized to 1 | 1 | RANDOM size=0. | 1 hit per side (MIRRORED) or per side selection. | TBD |
| E023 | D | RANDOM center=0 LEFT_ONLY size=1 | 1 | Pin center=0, LEFT_ONLY size=1. | Hit at A:ch0; no other hits. | TBD |
| E024 | D | RANDOM center=127 LEFT_ONLY size=1 | 1 | Pin center=127. | Hit at A:ch127 (lane 3 ch 31). | TBD |
| E025 | D | RANDOM center=0 size=8 LEFT_ONLY | 1 | Pin center=0 size=8. | Cluster A:ch0..7 (clamped low boundary). | TBD |
| E026 | D | RANDOM center=127 size=8 LEFT_ONLY | 1 | Pin center=127 size=8. | Cluster A:ch120..127 (clamped high boundary). | TBD |
| E027 | D | RANDOM center=64 size=128 | 1 | Pin center=64 size=128. | Cluster spans full A (center clamps). | TBD |
| E028 | D | FIX low=high boundary inside cluster | 1 | FIX low=64 high=64. | 1 hit; verify single-channel ticket FSM works. | TBD |
| E029 | D | Inject during partial drain | 1 | FIX size 32; inject; immediately inject again before drain. | Two clusters queued; both eventually visible; no merge. | TBD |
| E030 | D | Cluster size 1 across all 8 lanes | 1 | FIX low=0 high=0; FIX low=32 high=32; ...; one inject each. | 8 separate clusters; each on a different lane; same TCC if same cycle. | TBD |
| E031 | D | Burst-of-clusters at engine limit | 1 | Inject 16 clusters back-to-back at engine_busy boundary. | All 16 land; engine stalls if ticket FIFO fills. | TBD |
| E032 | D | Cluster size = 9 (boundary 8→9 ticket FIFO depth) | 1 | Inject 9 clusters at FIX size 32 with stalled lane. | Ticket FIFO depth 8 limit hits; 9th inject is the overflow boundary. | TBD |

---

## 4. Mirror Offset and Mode Boundaries (E033-E048)

mirror_offset signed encoding, clamp behavior at SMB edges, mode-only-applies-when-MIRRORED, mode-change-mid-run.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|----|--------|----------|------|----------|---------------|---------------------|
| E033 | D | mirror_offset=0 exact mirror | 1 | MIRRORED size=4 offset=0 pin center=10. | Mirror at B:ch113..116 (=127-10..127-13). | TBD |
| E034 | D | mirror_offset=+1 | 1 | Same offset=+1. | Mirror at B:ch114..117. | TBD |
| E035 | D | mirror_offset=-1 | 1 | Same offset=-1. | Mirror at B:ch112..115. | TBD |
| E036 | D | mirror_offset=+10 | 1 | Same offset=+10. | Mirror at B:ch123..126 (still inside SMB). | TBD |
| E037 | D | mirror_offset=+50 clamped (would exceed) | 1 | Pin center=10 size=4 offset=+50 (mirror would land at 167+). | Clamp to keep cluster inside SMB; mirror at B:ch124..127. | TBD |
| E038 | D | mirror_offset=-127 max negative | 1 | Pin center=64 size=4 offset=-127. | Clamp to ch0..3. | TBD |
| E039 | D | mirror_offset=+127 max positive | 1 | Pin center=64 size=4 offset=+127. | Clamp to ch124..127. | TBD |
| E040 | D | mirror_offset boundary at edge sizes | 1 | size=128 offset=+1. | Mirror clamped to full SMB B (no spillover). | TBD |
| E041 | D | mirror_offset=0 size=1 verify exact | 1 | Pin center=63 offset=0 size=1. | Mirror at B:ch64 exactly. | TBD |
| E042 | D | mirror_offset=0 size=128 verify exact | 1 | Pin center=64 offset=0 size=128. | Mirror covers B:ch0..127. | TBD |
| E043 | D | mirror_offset effect on TCC anchor | 1 | Sweep offset; capture TCC. | TCC identical for primary and mirror regardless of offset. | TBD |
| E044 | D | mirror_offset CSR readback | 1 | Write +5; readback CSR 0x0D[18:11]. | Returns +5 (signed). | TBD |
| E045 | D | mirror_offset signed encoding | 1 | Write -5 (0xFB); readback. | Returns -5 with sign-extend. | TBD |
| E046 | D | mirror_mode RIGHT_ONLY ignores offset | 1 | RIGHT_ONLY size=4 offset=+10. | Single-side cluster on B; offset has no effect (only MIRRORED uses it). | TBD |
| E047 | D | mirror_mode LEFT_ONLY ignores offset | 1 | LEFT_ONLY offset=-10. | Single-side cluster on A; offset has no effect. | TBD |
| E048 | D | mirror_mode change mid-run | 1 | MIRRORED → LEFT_ONLY mid-run. | Subsequent injects use LEFT_ONLY; queued injects honor mode-at-launch. | TBD |

---

## 5. SMB Boundary and Lane-Enable Interactions (E049-E064)

SMB boundary discipline (RANDOM never crosses; FIX may cross), lane-enable interaction with cluster decode and asic_id_base.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|----|--------|----------|------|----------|---------------|---------------------|
| E049 | D | FIX cluster wholly inside SMB A | 1 | FIX low=0 high=127. | All hits side A; lanes 4..7 silent. | TBD |
| E050 | D | FIX cluster wholly inside SMB B | 1 | FIX low=128 high=255. | All hits side B; lanes 0..3 silent. | TBD |
| E051 | D | FIX cluster straddles SMB boundary | 1 | FIX low=120 high=135. | Hits on lanes 3 and 4. | TBD |
| E052 | D | FIX cluster of size 128 mid-SMB | 1 | FIX low=64 high=191. | Hits on lanes 2..5. | TBD |
| E053 | D | RANDOM never crosses SMB boundary (1000 trials) | 1 | RANDOM size=128 LEFT_ONLY 1000 injects. | Zero side-B hits ever. | TBD |
| E054 | D | RANDOM MIRRORED preserves side identity | 1 | MIRRORED 1000 trials. | Each launch produces hits on both sides; never one side only (unlike LEFT/RIGHT_ONLY). | TBD |
| E055 | D | FIX size 256 saturates engine | 1 | FIX low=0 high=255 + 8 back-to-back injects. | Engine cycles through all 8 lane pushes per inject; ticket_overflow_count increments if lanes are stalled. | TBD |
| E056 | D | FIX size 257 illegal (high=256) | 1 | FIX low=0 high=256. | Field truncates to 8 bits; treated as high=0 (low>high); launch dropped. | TBD |
| E057 | D | FIX cluster fully in disabled lane | 1 | FIX low=64 high=95; disable LANE_ENABLE bit 2. | No hits emitted; engine pushes ticket but lane consumer holds K28.5. | TBD |
| E058 | D | FIX cluster spanning 2 lanes one disabled | 1 | FIX low=63 high=64; disable lane 2. | Lane 1 ch 31 fires; lane 2 silent. | TBD |
| E059 | D | MIRRORED with side B disabled lanes | 1 | MIRRORED size=1 + LANE_ENABLE bits[7:4]=0. | Primary side A fires; mirror side B suppressed by lane enable. | TBD |
| E060 | D | MIRRORED with side A disabled lanes | 1 | MIRRORED size=1 + LANE_ENABLE bits[3:0]=0. | Mirror fires on side B; primary side A suppressed by lane enable. | TBD |
| E061 | D | MIRRORED with all lanes disabled | 1 | MIRRORED + LANE_ENABLE=0x00. | No hits anywhere; ticket pushes silently no-op. | TBD |
| E062 | D | LANE_ENABLE asic_id_base wrap | 1 | Set asic_id_base=0xC; lane 4 → asic_id 0; check clamp. | asic_id of lane i = (asic_id_base + i) clamped to 0..7. | TBD |
| E063 | D | LANE_ENABLE bit toggle mid-cluster | 1 | FIX size 128 spans lanes 0..3; toggle LANE_ENABLE bit 1 mid-drain. | Lane 1 silences mid-drain (queued frames complete). | TBD |
| E064 | D | LANE_ENABLE bit re-enable mid-frame | 1 | Disable lane 0, then re-enable mid-frame. | Lane 0 resumes at next frame boundary. | TBD |

---

## 6. ECC Seed Phase / Delay Sweep (E065-E080)

Two-LFSR independent seeds realize configurable ECC-after-TCC delay; user computes seed offset offline; emulator stores no LFSR-step↔time mapping.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|----|--------|----------|------|----------|---------------|---------------------|
| E065 | D | ecc_seed=0x0001 (default, ECC≡TCC) | 1 | tcc_seed=0x0001, ecc_seed=0x0001. | ECC value at every cycle equals TCC value. | TBD |
| E066 | D | ecc_seed=prbs15_step_n(1, 5) (1 cycle delay) | 1 | Pre-compute seed, write CSR. | ECC lags TCC by exactly 1 cycle (=8ns at 125MHz). | TBD |
| E067 | D | ecc_seed=prbs15_step_n(1, 25) (5 cycle delay) | 1 | Pre-compute seed for N=5. | ECC lags TCC by 5 cycles (=40ns). | TBD |
| E068 | D | ecc_seed=prbs15_step_n(1, 100) (20 cycle delay) | 1 | N=20. | ECC lags TCC by 20 cycles (=160ns). | TBD |
| E069 | D | ecc_seed mid-period | 1 | Pre-compute seed for N=1000. | ECC lags TCC by 1000 cycles (=8μs). | TBD |
| E070 | D | ecc_seed wraps around PRBS-15 (32767 cycle period) | 1 | N=32767 (full period). | ECC == TCC again (full LFSR period elapsed). | TBD |
| E071 | D | ecc_seed=prbs15_step_n(1, 32766) → 1-cycle lead | 1 | N = period-1. | ECC effectively leads TCC by 1 (mod period). | TBD |
| E072 | D | ecc_seed change mid-run reseeds at next emu_rst | 1 | Write new seed during RUNNING. | Current run unaffected; next SYNC re-loads with new seed. | TBD |
| E073 | D | tcc_seed=0xFEED ecc_seed=0xBEEF | 1 | Custom non-1 seeds. | Both LFSRs run from custom states; no ECC≡TCC relation. | TBD |
| E074 | D | ecc_seed CSR readback | 1 | Write 0x7FF0 to ecc_seed. | Read returns 0x7FF0. | TBD |
| E075 | D | tcc_seed=0 illegal (LFSR stuck) | 1 | Write tcc_seed=0. | RTL clamps to 0x0001 or detects invalid; check error reporting. | TBD |
| E076 | D | ecc_seed=0 illegal (LFSR stuck) | 1 | Write ecc_seed=0. | Clamps to 0x0001 or flagged. | TBD |
| E077 | D | tcc_seed default value at reset | 1 | Read TIMEBASE_SEED after cold reset. | tcc_seed=0x0001, ecc_seed=0x0001. | TBD |
| E078 | D | Two emulators with different seeds desync | 1 | Two instances, same PRNG_SEED, different ecc_seeds. | ECC streams differ; TCC identical. | TBD |
| E079 | D | ECC delay verified via downstream MTS decode | 1 | Drive type0 stream into mutrig_timestamp_processor. | Decoded MTS shows constant ECC-after-TCC delay matching configured seed offset. | TBD |
| E080 | D | ecc_seed compatible with raw MuTRiG ROM | 1 | Set seeds matching raw MuTRiG dual_port_rom_init.txt. | MTS decode succeeds with no phase remap. | TBD |

---

## 7. Frame Boundary Race Conditions (E081-E096)

Frame-interval timer correctly delineates SOP/EOP for type0; short/long mode period correct; frame_count and hit_count saturate cleanly.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|----|--------|----------|------|----------|---------------|---------------------|
| E081 | D | Inject at frame boundary cycle | 1 | Inject on the cycle frame_start_req asserts. | Cluster lands in next frame; SOP marks first hit. | TBD |
| E082 | D | Inject 1 cycle before frame boundary | 1 | Inject just before next frame. | Cluster lands in current frame if FIFO room. | TBD |
| E083 | D | Inject 1 cycle after frame boundary | 1 | Inject just after frame opens. | Cluster lands in current new frame. | TBD |
| E084 | D | Frame boundary during cluster dispense | 1 | Cluster size 32 mid-dispense; frame boundary fires. | All 32 hits emit; SOP/EOP for the multi-frame span correct. | TBD |
| E085 | D | Empty frame produces no type0 beats | 1 | RUNNING with no SIGNAL or BKG. | frame_start fires; no SOP/EOP/data; type0 valid stays low. | TBD |
| E086 | D | Frame with 1 hit | 1 | 1 inject per frame interval. | 1 SOP+EOP+data beat per frame. | TBD |
| E087 | D | Frame with N=event_count_max hits | 1 | Inject FIX size 32 multiple times. | All hits drain into one frame if FIFO room; SOP/EOP correct. | TBD |
| E088 | D | Back-to-back full frames | 1 | Inject continuously. | Frames open at every interval boundary; no missed frames. | TBD |
| E089 | D | Frame interval short_mode (910 cycles) | 1 | MUTRIG_FORMAT.short_mode=1. | frame_start_req period = 910 cycles. | TBD |
| E090 | D | Frame interval long_mode (1550 cycles) | 1 | short_mode=0. | frame_start_req period = 1550 cycles. | TBD |
| E091 | D | short_mode toggle mid-run | 1 | Toggle short_mode while RUNNING. | Behavior at boundary defined by spec; flag any race. | TBD |
| E092 | D | frame_assembler stall on FIFO empty | 1 | Drain L2 to empty mid-frame. | frame_assembler emits gen_idle bytes; no spurious data. | TBD |
| E093 | D | frame_assembler with gen_idle=0 | 1 | MUTRIG_FORMAT.gen_idle=0. | No idle bytes between hits; frame compact. | TBD |
| E094 | D | frame_count increments on every frame_start | 1 | Run 100 frames. | Per-lane LANE_FRAME_LO increments to 100. | TBD |
| E095 | D | frame_count saturating at 64-bit max | 1 | Pre-load counter near 2^60-1. | Counter saturates instead of wrapping. | TBD |
| E096 | D | hit_count increments on every L2 commit | 1 | Inject 100 size-1 clusters. | Per-lane LANE_HIT_LO increments to 100. | TBD |

---

## 8. Per-Lane Counter Saturation and Sticky Bits (E097-E112)

Per-lane 64-bit frame_count/hit_count saturate cleanly; sticky bits W1C; bank counters saturate; lo/hi atomic read.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|----|--------|----------|------|----------|---------------|---------------------|
| E097 | D | frame_count_lo readback | 1 | 100 frames; read 0x20. | Returns 0x64. | TBD |
| E098 | D | frame_count_hi readback above 2^32 | 1 | Force counter past 2^32. | Hi word increments correctly. | TBD |
| E099 | D | frame_count saturates at 2^60-1 | 1 | Force counter to 2^60-1, run more frames. | Counter holds at saturation value. | TBD |
| E100 | D | hit_count_lo readback | 1 | 100 hits; read 0x22. | Returns 0x64. | TBD |
| E101 | D | hit_count_hi readback above 2^32 | 1 | 4G+ hits. | Hi word increments. | TBD |
| E102 | D | hit_count saturates at 2^64-1 | 1 | Force counter to max. | Counter saturates. | TBD |
| E103 | D | Per-lane counter independence | 1 | Inject hits on lane 3 only. | Lane 3 counter increments; lanes 0-2,4-7 stay 0. | TBD |
| E104 | D | Counter clears on emu_rst | 1 | 100 hits; pulse SYNC. | All lane counters reset to 0. | TBD |
| E105 | D | Counter persists across IDLE→RUNNING | 1 | Pause via IDLE then resume RUNNING (no SYNC). | Counters retain pre-pause value. | TBD |
| E106 | D | fifo_full_sticky sets on first overrun | 1 | Stress until L2 full. | Bit 28 of FRAME_HI sets and stays. | TBD |
| E107 | D | fifo_full_sticky W1C clears | 1 | Set sticky; write 1 to FRAME_HI[28]. | Bit clears; further overruns set again. | TBD |
| E108 | D | ticket_overflow_sticky sets on engine stall | 1 | Stress until ticket FIFO full. | Bit 29 of FRAME_HI sets. | TBD |
| E109 | D | ticket_overflow_sticky W1C clears | 1 | Write 1 to FRAME_HI[29]. | Bit clears. | TBD |
| E110 | D | BANK_STATUS.ticket_overflow_count saturates | 1 | Force 65k+ overflows. | Field saturates at 0xFFFF. | TBD |
| E111 | D | BANK_STATUS.engine_busy_high_water tracks max | 1 | Run RANDOM size=128 MIRRORED. | High-water reflects max consecutive engine_busy cycles. | TBD |
| E112 | D | Read counters atomically (lo before hi) | 1 | Read 0x20 then 0x21. | Lo capture freezes hi; hi reflects same snapshot. | TBD |

---

## 9. CSR Aliasing, Reserved Bits, and Stub Fields (E113-E128)

All reserved bits read 0; reserved addresses read 0; CSR independent of run-control state; ERROR_INJECT stub stores but does not act.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|----|--------|----------|------|----------|---------------|---------------------|
| E113 | D | Reserved bit in CTRL_MODE/CENTRAL reads 0 | 1 | Write 0xFFFFFFFE to CENTRAL; read. | Bits[31:1] read 0. | TBD |
| E114 | D | Reserved bit in SIGNAL reads 0 | 1 | Write 0xFFFFFFF8 to SIGNAL; read. | Bits[31:3] read 0. | TBD |
| E115 | D | Reserved bit in BACKGROUND reads 0 | 1 | Write 0xFFFFFFFE to BACKGROUND; read. | Bits[31:1] read 0. | TBD |
| E116 | D | Reserved bit in MUTRIG_FORMAT reads 0 | 1 | Write 0xFFFFFF80 to MUTRIG_FORMAT; read. | Bits[31:7] read 0. | TBD |
| E117 | D | Write to CSR 0x10 (reserved INJECT_CHANNEL_MASK) reads 0 | 1 | Write 0xDEAD; read. | Read returns 0. | TBD |
| E118 | D | Write to CSR 0x11 (reserved INJECT_LANE_MASK) reads 0 | 1 | Same. | Read returns 0. | TBD |
| E119 | D | Reserved 0x16/0x17/0x18/0x19/0x1A/0x1B/0x1C/0x1D/0x1E/0x1F all read 0 | 1 | Read each. | All return 0. | TBD |
| E120 | D | Reserved 0x40+ behavior (out of 6-bit window) | 1 | Read 0x40, 0x7F. | Address wraps or returns 0; documented behavior consistent. | TBD |
| E121 | D | Read CSR while ctrl=RESET | 1 | Hold RESET; read CSR. | CSR responds normally; csr_block independent of run-control. | TBD |
| E122 | D | Read CSR while emu_rst asserted | 1 | Pulse emu_rst; read during pulse. | CSR responds; UID/META still readable. | TBD |
| E123 | D | Write CSR while emu_rst asserted | 1 | Write CENTRAL during emu_rst. | Write accepted; will apply after rst deasserts. | TBD |
| E124 | D | Back-to-back CSR write/read | 1 | Write CENTRAL then read same cycle next. | Read returns just-written value. | TBD |
| E125 | D | CSR address aliasing (mod 64) | 1 | Write to 0x07; read from 0x47 (out of range). | 0x47 returns reserved=0; 0x07 holds the write. | TBD |
| E126 | D | FIRE.fire_inject_pulse W1P read returns 0 | 1 | Write 1; read. | Read returns 0 (W1P semantics). | TBD |
| E127 | D | ERROR_INJECT stub: write/readback | 1 | Write 0x7 to ERROR_INJECT[2:0]. | Readback returns 0x7; type0_error[2:0] still ties to 0. | TBD |
| E128 | D | ERROR_INJECT stub does NOT inject | 1 | Set ERROR_INJECT=0x7; inject hits. | All type0_error[2:0] outputs are 3'b000 regardless. | TBD |

---
