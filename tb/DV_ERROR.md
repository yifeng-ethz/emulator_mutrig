# emulator_mutrig DV — Error, Reset, and Recovery Cases

**Companion docs:** [DV_PLAN.md](DV_PLAN.md), [DV_BASIC.md](DV_BASIC.md), [DV_EDGE.md](DV_EDGE.md), [DV_PROF.md](DV_PROF.md), [DV_ERROR.md](DV_ERROR.md), `BUG_HISTORY.md`

**Parent:** [DV_PLAN.md](DV_PLAN.md)
**ID Range:** X001-X999
**Total:** 128 cases (128 implemented / 0 waived)

This bucket exercises faults and recovery: reset during activity, illegal/skipped/backwards run-control transitions, CSR access during reset, ticket FIFO overflow, L2 FIFO backpressure recovery, frame-boundary reset, CSR atomicity and race conditions, and run-control replay edge cases. The IP must survive every case without deadlock or undefined state.

**Methodology key:**
- **D** = Directed (hand-crafted stimulus, deterministic)
- **R** = Constrained-random (LCG-based PRNG; no SystemVerilog `rand`)

---

## 1. Summary

| Section | Cases | ID Range | What it Proves | Current Case |
|---------|-------|----------|----------------|--------------|
| Reset During Activity | 16 | X001-X016 | i_rst and SYNC clear engine/back-end state cleanly; no half-finished frames; CSR config preserved; sticky bits clear on i_rst only. | 16/16 |
| Run-Control Illegal Transitions | 16 | X017-X032 | Engine survives illegal/skipped/backwards run-control sequences without deadlock or undefined state. | 16/16 |
| CSR Access During Reset and Activity | 16 | X033-X048 | CSR access decoupled from run-control; reads/writes work in any state; LAST_* snapshots only update on legitimate accepted accesses. | 16/16 |
| Ticket FIFO Overflow | 16 | X049-X064 | Per-lane ticket FIFO depth bounded; overflow counted only on EXTERNAL launches; sticky bits set per-lane; recovery clean. | 16/16 |
| L2 FIFO Backpressure and Recovery | 16 | X065-X080 | Per-lane L2 FIFO honors backpressure; type0 and byte-stream paths independent; sticky bits track overflow; clean recovery. | 16/16 |
| Frame-Boundary Reset and Counter Atomicity | 16 | X081-X096 | Frame boundary handles SYNC/TERMINATING gracefully; per-lane counters atomic; lo-before-hi read snapshot consistent. | 16/16 |
| CSR Atomicity and Race Conditions | 16 | X097-X112 | CSR writes atomic at word level; race conditions defined; LAST_* snapshots consistent; rapid W1P/W1C work. | 16/16 |
| Run-Control Replay and Edge Cases | 16 | X113-X128 | Run-control AvST sink robust to repeated/sustained/illegal/async words; engine never deadlocks; line stays well-defined. | 16/16 |

---

## 2. Reset During Activity (X001-X016)

i_rst and SYNC clear engine/back-end state cleanly; no half-finished frames; CSR config preserved; sticky bits clear on i_rst only.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|----|--------|----------|------|----------|---------------|---------------------|
| X001 | D | Reset during inject mid-dispense | 1 | Inject FIX size 32; pulse SYNC mid-cluster. | All in-flight tickets cleared; no partial L2 commits. | TBD |
| X002 | D | Reset during Poisson run | 1 | Pulse SYNC during Poisson at rate=0xFFFF. | PRNG reseeds; new launches start clean. | TBD |
| X003 | D | Reset during BKG scan | 1 | Pulse SYNC during BKG. | scan_pos resets to 0; LFSR reseeds. | TBD |
| X004 | D | Reset during type0 SOP | 1 | Pulse SYNC after SOP, before EOP. | type0 valid drops; partial frame discarded; endofrun does NOT fire (no clean termination). | TBD |
| X005 | D | Reset during byte-stream packet | 1 | Pulse SYNC during 8b/1k packet. | byte-stream returns to K28.5 idle; partial bytes discarded. | TBD |
| X006 | D | Reset clears ticket FIFO | 1 | Fill ticket FIFO; pulse SYNC. | Ticket FIFO empties; no spurious dispatch after reset. | TBD |
| X007 | D | Reset clears L2 FIFO | 1 | Fill L2 to almost-full; pulse SYNC. | L2 empties; counters reset. | TBD |
| X008 | D | Reset clears LFSRs | 1 | Run 1k cycles; pulse SYNC. | Both PRBS-15 LFSRs reload from CSR seeds. | TBD |
| X009 | D | Reset clears engine_busy | 1 | Inject during engine dispatch; pulse SYNC. | engine_busy clears immediately; no stuck state. | TBD |
| X010 | D | Reset clears all sticky bits | 1 | Set all sticky bits; pulse i_rst. | All sticky bits clear (i_rst, not just SYNC). | TBD |
| X011 | D | Reset clears LANE_FRAME/HIT counters | 1 | Run 1k frames; pulse SYNC. | Counters return to 0. | TBD |
| X012 | D | Reset does NOT clear CSR config | 1 | Configure mode words; pulse SYNC. | CSR config preserved; only run-state cleared. | TBD |
| X013 | D | Reset clears LAST_RD/WR_* | 1 | Read/write CSR; pulse i_rst. | LAST_RD/WR_* cleared per §3. | TBD |
| X014 | D | Reset during inject queued in 2-deep latch | 1 | Queue inject; pulse SYNC before dispatch. | Queued inject dropped. | TBD |
| X015 | D | Reset back-to-back (multiple SYNC) | 1 | Pulse SYNC twice in 5 cycles. | Both processed; engine stable. | TBD |
| X016 | D | Reset during run-control transition | 1 | RUNNING→TERMINATING + SYNC same cycle. | SYNC wins; engine reset; TERMINATING latch overwritten. | TBD |

---

## 3. Run-Control Illegal Transitions (X017-X032)

Engine survives illegal/skipped/backwards run-control sequences without deadlock or undefined state.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|----|--------|----------|------|----------|---------------|---------------------|
| X017 | D | Illegal multi-bit ctrl one-hot (RUNNING+TERMINATING) | 1 | Drive bits[3] OR bit[4]. | Defined behavior per spec; engine takes one of the two consistently. | TBD |
| X018 | D | Illegal all-zero ctrl word | 1 | Drive 9'h000. | ctrl_state_q latches 0; engine treats as IDLE. | TBD |
| X019 | D | ctrl AvST valid without ready behavior | 1 | asi_ctrl_ready=1 always; drive valid mid-cycle. | Latch on first valid+ready; subsequent ignored if not held. | TBD |
| X020 | D | ctrl word changes every cycle | 1 | Toggle through all 9 states 1 cycle each. | Latch latest each cycle; engine stable. | TBD |
| X021 | D | Skip RUN_PREPARE: IDLE→SYNC direct | 1 | Drive IDLE then SYNC. | engine resets; behavior per spec; flag if undocumented. | TBD |
| X022 | D | Skip SYNC: IDLE→RUNNING direct | 1 | Drive IDLE then RUNNING. | Engine starts without SYNC reset; PRNG/LFSR carry stale state from previous run; flag warning. | TBD |
| X023 | D | Backwards transition: RUNNING→IDLE | 1 | Direct. | engine stops; queued hits NOT drained (no TERMINATING). | TBD |
| X024 | D | Backwards: TERMINATING→RUNNING | 1 | Direct. | Defined behavior; engine resumes. | TBD |
| X025 | D | Backwards: TERMINATING→SYNC | 1 | Direct. | Engine resets; queued hits flushed. | TBD |
| X026 | D | LINK_TEST during inject | 1 | Drive LINK_TEST during active inject. | Inject dropped; engine silent. | TBD |
| X027 | D | OUT_OF_DAQ during inject | 1 | Drive OUT_OF_DAQ during inject. | Inject dropped; engine silent. | TBD |
| X028 | D | Multiple SYNC pulses in 10 cycles | 1 | 5 SYNC pulses. | Each processed; engine stable; LFSRs re-seed each. | TBD |
| X029 | D | RESET state vs i_rst signal | 1 | Compare ctrl=RESET vs hardware i_rst. | RESET state acts as soft reset; i_rst is hard reset (clears CSR LAST_*). | TBD |
| X030 | D | ctrl ready=0 holds incoming | 1 | Drive ready=0; pulse valid. | Word not latched; ctrl_state_q unchanged. | TBD |
| X031 | D | ctrl backpressure during inject | 1 | Inject + ctrl backpressure. | Inject still works; ctrl latch deferred. | TBD |
| X032 | D | ctrl AvST disconnect | 1 | Disconnect ctrl AvST source. | ctrl_state_q stays at last latched value; engine continues per current state. | TBD |

---

## 4. CSR Access During Reset and Activity (X033-X048)

CSR access decoupled from run-control; reads/writes work in any state; LAST_* snapshots only update on legitimate accepted accesses.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|----|--------|----------|------|----------|---------------|---------------------|
| X033 | D | CSR read during i_rst | 1 | Assert i_rst; read 0x00. | Returns reset value or last-pre-reset; no hang. | TBD |
| X034 | D | CSR write during i_rst | 1 | Assert i_rst; write to 0x07. | Write accepted; effective on rst deassert. | TBD |
| X035 | D | CSR read during SYNC | 1 | Drive SYNC; read CSR. | CSR responds normally. | TBD |
| X036 | D | CSR write during SYNC | 1 | Drive SYNC; write CSR. | Write accepted. | TBD |
| X037 | D | CSR read while engine_busy | 1 | engine_busy=1; read CSR. | CSR responds in same cycle (independent of engine). | TBD |
| X038 | D | CSR write while inject active | 1 | Mid-inject; write to CLUSTER_GEOM_FIX. | Write accepted; affects next inject only (not current ticket). | TBD |
| X039 | D | CSR write to MUTRIG_FORMAT mid-frame | 1 | Toggle short_mode mid-frame. | Frame interval changes at next frame_start_req boundary. | TBD |
| X040 | D | CSR write to TIMEBASE_SEED mid-run | 1 | Write new seed during RUNNING. | Current run unaffected; takes effect at next SYNC. | TBD |
| X041 | D | CSR write to LANE_ENABLE mid-cluster | 1 | Mid-dispense disable target lane. | Lane silences at next frame boundary. | TBD |
| X042 | D | CSR back-to-back write/read | 1 | write 0x07; read 0x07. | Read returns just-written value. | TBD |
| X043 | D | CSR address out of range during reset | 1 | Read 0x40 with i_rst. | Returns 0; no hang. | TBD |
| X044 | D | CSR write to read-only UID/META snapshot | 1 | Write to 0x00, 0x03..0x06. | Writes ignored; no side effect. | TBD |
| X045 | D | CSR write to FIRE during reset | 1 | Write FIRE during i_rst. | FIRE bit asserted but inject suppressed (gated by global_enable=0 default). | TBD |
| X046 | D | CSR write to ERROR_INJECT stub | 1 | Write 0xFFFFFFFF to 0x15. | Returns last-written within field bounds; type0 error stays 0. | TBD |
| X047 | D | CSR write while in TERMINATING | 1 | Mid-drain CSR write. | Accepted; no effect on current drain. | TBD |
| X048 | D | CSR back-to-back read of same address | 1 | Read 0x00 twice. | Both return same value. | TBD |

---

## 5. Ticket FIFO Overflow (X049-X064)

Per-lane ticket FIFO depth bounded; overflow counted only on EXTERNAL launches; sticky bits set per-lane; recovery clean.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|----|--------|----------|------|----------|---------------|---------------------|
| X049 | D | Ticket FIFO fill 8 deep | 1 | Stall lane 0; inject 8 times. | Lane 0 ticket FIFO at 8/8; subsequent inject overflow. | TBD |
| X050 | D | Ticket overflow first count | 1 | Stall lane 0; inject 9 times. | 1 overflow; ticket_overflow_count=1; ticket_overflow_sticky[lane 0]=1. | TBD |
| X051 | D | Ticket overflow saturates at 0xFFFF | 1 | Force 65540 overflows. | ticket_overflow_count saturates. | TBD |
| X052 | D | Ticket overflow recovery on lane release | 1 | Stall+overflow, then release lane. | Queued tickets dispatched; new inject works. | TBD |
| X053 | D | Ticket overflow per-lane independent | 1 | Stall lane 0; lane 1-7 free. | Lane 0 ticket_overflow_sticky=1; others=0. | TBD |
| X054 | D | Ticket overflow on RANDOM MIRRORED both sides | 1 | Stall all lanes; inject MIRRORED. | Both primary and mirror stall; engine queues until 2-deep latch full; then drops. | TBD |
| X055 | D | Ticket overflow during BKG | 1 | BKG ON + stalled lane. | BKG ticket dropped; bkg_overflow if separate counter. | TBD |
| X056 | D | Ticket overflow with internal Poisson | 1 | Poisson + stalled lane. | Internal launch dropped silently (PRNG re-eval); no overflow count for internal. | TBD |
| X057 | D | Ticket overflow with EXTERNAL inject | 1 | EXTERNAL + stalled lane + inject. | Inject queued in 2-deep latch then dropped → ticket_overflow_count++. | TBD |
| X058 | D | Ticket overflow sticky W1C clears | 1 | Force overflow; W1C bit; verify clear. | Bit clears; new overflow re-sets. | TBD |
| X059 | D | Ticket FIFO drain after release | 1 | Fill 8 tickets; release; observe drain. | All 8 dispatch within 8 cycles. | TBD |
| X060 | D | Ticket FIFO at exactly 7 (not full) | 1 | Stall; inject 7. | No overflow; 8th inject would be the boundary. | TBD |
| X061 | D | Ticket FIFO depth boundary 8 vs 9 | 1 | Inject 8 (no stall) then 1 more. | All 9 succeed in steady state if dispatch keeps up. | TBD |
| X062 | D | Engine stall blocks all sources | 1 | Fill all 8 lanes' ticket FIFOs. | Engine_busy high; new launches deferred or dropped. | TBD |
| X063 | D | ticket_overflow_count reset on i_rst | 1 | Force 100 overflows; pulse i_rst. | Counter back to 0. | TBD |
| X064 | D | ticket_overflow_count NOT reset on SYNC | 1 | 100 overflows; pulse SYNC. | Counter cleared on emu_rst (which SYNC drives) per §3 note. | TBD |

---

## 6. L2 FIFO Backpressure and Recovery (X065-X080)

Per-lane L2 FIFO honors backpressure; type0 and byte-stream paths independent; sticky bits track overflow; clean recovery.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|----|--------|----------|------|----------|---------------|---------------------|
| X065 | D | L2 FIFO fill to 256 | 1 | Stall type0+byte-stream; inject 256 hits. | L2 fills to 256. | TBD |
| X066 | D | L2 FIFO almost-full margin | 1 | Inject up to FIFO_ALMOST_FULL_MARGIN below max. | almost_full asserts at threshold. | TBD |
| X067 | D | L2 backpressure stalls lane_emitter | 1 | Hold L2 ready=0; inject. | lane_emitter stalls; ticket FIFO fills. | TBD |
| X068 | D | L2 backpressure + ticket FIFO fill | 1 | L2 ready=0 + inject burst. | Ticket FIFO overflow follows L2 backpressure. | TBD |
| X069 | D | L2 backpressure recovery | 1 | Stall 1k cycles; release. | Drain begins immediately; type0 catches up. | TBD |
| X070 | D | L2 backpressure with SYNC | 1 | Stall L2; pulse SYNC. | L2 cleared; backpressure irrelevant after reset. | TBD |
| X071 | D | L2 backpressure during TERMINATING | 1 | TERMINATING with stalled L2. | Drain stalls; endofrun deferred. | TBD |
| X072 | D | L2 fifo_full_sticky sets | 1 | Force L2 to full. | fifo_full_sticky[lane]=1. | TBD |
| X073 | D | L2 fifo_full_sticky W1C clears | 1 | Set then W1C. | Bit clears. | TBD |
| X074 | D | type0 backpressure independent of byte-stream | 1 | Stall type0; byte-stream free. | byte-stream still drains; type0 stalls. | TBD |
| X075 | D | byte-stream backpressure independent of type0 | 1 | Stall byte-stream; type0 free. | type0 still drains; byte-stream stalls. | TBD |
| X076 | D | Both outputs stalled fills L2 | 1 | Both ready=0. | L2 fills; back-pressure propagates to lane_emitter, then engine. | TBD |
| X077 | D | Type0 ready glitch <1 cycle | 1 | Glitch type0 ready. | Type0 honors ready (sync FF); no spurious data. | TBD |
| X078 | D | Lane_emitter pending slot under backpressure | 1 | L2 ready=0 with pending slot occupied. | lane_emitter stalls; pending preserved. | TBD |
| X079 | D | L2 wraparound at 256-th word | 1 | Fill 256, drain 1, push 1. | Pointer wraps cleanly; word at index 0 OK. | TBD |
| X080 | D | L2 drain rate matches frame_assembler consumption | 1 | Sustained inject + frame_assembler drain. | L2 stays at low water mark; no overflow. | TBD |

---

## 7. Frame-Boundary Reset and Counter Atomicity (X081-X096)

Frame boundary handles SYNC/TERMINATING gracefully; per-lane counters atomic; lo-before-hi read snapshot consistent.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|----|--------|----------|------|----------|---------------|---------------------|
| X081 | D | SYNC at exact frame boundary | 1 | Pulse SYNC at frame_start cycle. | Frame discarded; new frame opens after SYNC. | TBD |
| X082 | D | SYNC mid-frame with hits queued | 1 | Pulse SYNC with L2 occupied. | L2 cleared; type0 valid drops; partial frame lost. | TBD |
| X083 | D | SYNC during EOP cycle | 1 | SYNC at the EOP cycle. | EOP not emitted; partial packet. | TBD |
| X084 | D | RUNNING→TERMINATING at frame boundary | 1 | Transition at frame_start. | New frame opens for drain; EOP at end. | TBD |
| X085 | D | RUNNING→TERMINATING mid-frame | 1 | Transition mid-frame. | Current frame completes its drain; endofrun follows. | TBD |
| X086 | D | RUNNING→IDLE mid-frame (illegal skip) | 1 | Direct transition. | Frame discarded; no drain; flag warning. | TBD |
| X087 | D | Frame boundary during RANDOM mirror dispense | 1 | Mirror cluster mid-dispense at frame boundary. | Dispense continues; SOP/EOP correct for both frames. | TBD |
| X088 | D | Frame boundary during BKG ticket dispatch | 1 | BKG hit at frame boundary. | Hit lands in correct frame per its TCC. | TBD |
| X089 | D | Empty frame followed by full frame | 1 | Idle then inject burst. | First frame: 0 type0 beats; second: all hits. | TBD |
| X090 | D | Full frame followed by empty frame | 1 | Inject burst then idle. | First frame: all hits with EOP; second: 0 beats. | TBD |
| X091 | D | frame_count atomic with frame_start | 1 | Sample LANE_FRAME_LO across many frames. | Increments by exactly 1 per frame. | TBD |
| X092 | D | hit_count atomic with L2 commit | 1 | Sample LANE_HIT_LO across hits. | Increments by exactly 1 per L2 push. | TBD |
| X093 | D | Counter snapshot during fast read | 1 | Read LO and HI back-to-back. | Atomic snapshot via lo-read latches hi. | TBD |
| X094 | D | Disabled lane frame_count stays 0 | 1 | Disable lane; run. | frame_count for disabled lane stays 0. | TBD |
| X095 | D | Re-enabled lane resumes counting | 1 | Disable then re-enable. | Counter resumes from previous value. | TBD |
| X096 | D | Counter wrap after re-enable | 1 | Force counter near sat; re-enable; run more. | Counter saturates. | TBD |

---

## 8. CSR Atomicity and Race Conditions (X097-X112)

CSR writes atomic at word level; race conditions defined; LAST_* snapshots consistent; rapid W1P/W1C work.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|----|--------|----------|------|----------|---------------|---------------------|
| X097 | D | CSR write atomic (full 32-bit) | 1 | Write 0xDEADBEEF to SCRATCH. | All 32 bits update in one cycle. | TBD |
| X098 | D | CSR read atomic | 1 | Read SCRATCH after write. | Returns full 32-bit value. | TBD |
| X099 | D | CSR write to multi-field word atomic | 1 | Write CLUSTER_GEOM_RANDOM with all fields. | All fields update simultaneously. | TBD |
| X100 | D | CSR write order: CTRL_MODE before SIGNAL | 1 | Sequence: CENTRAL=enable, then SIGNAL=Poisson. | Both effective; order doesn't matter for steady state. | TBD |
| X101 | D | CSR write race: enable+inject same cycle | 1 | Write CENTRAL.global_enable=1; inject same cycle. | Inject takes effect (gated by enable, which is just-set). | TBD |
| X102 | D | CSR write race: disable+inject same cycle | 1 | Write enable=0; inject same cycle. | Inject suppressed (enable=0 wins). | TBD |
| X103 | D | CSR write race: change cluster mode mid-cluster | 1 | Write FIX→RANDOM during dispense. | Current cluster keeps FIX; next inject uses RANDOM. | TBD |
| X104 | D | CSR write race: change cluster size mid-cluster | 1 | Write size during dispense. | Current cluster keeps old size; next uses new. | TBD |
| X105 | D | CSR sticky bit W1C race | 1 | Set sticky; W1C and force again same cycle. | Sticky stays asserted (force wins or both ordered per spec). | TBD |
| X106 | D | CSR FIRE bit during inject | 1 | Pulse FIRE during current inject dispense. | Second inject queued in 2-deep latch; dispatched after first. | TBD |
| X107 | D | CSR LAST_RD/WR_* update atomicity | 1 | Read 0x00 followed by read of 0x03 same cycle. | 0x03 captures 0x00 read; LAST_RD_DATA captures UID. | TBD |
| X108 | D | CSR readdata pipeline | 1 | Read CSR; check readdata cycle. | 1-cycle read latency; waitrequest=0. | TBD |
| X109 | D | CSR write/read same address one cycle apart | 1 | Write then read. | Read returns just-written. | TBD |
| X110 | D | CSR write to FIRE rapid succession | 1 | Pulse 100 times in 100 cycles. | 100 W1P pulses; engine sees 100 launches (subject to overflow). | TBD |
| X111 | D | CSR write to multi-W1C word | 1 | Set 2 sticky bits; W1C both same write. | Both clear. | TBD |
| X112 | D | CSR concurrent read+write same addr (illegal AVMM) | 1 | If supported. | Per spec; write may complete before read or vice versa. | TBD |

---

## 9. Run-Control Replay and Edge Cases (X113-X128)

Run-control AvST sink robust to repeated/sustained/illegal/async words; engine never deadlocks; line stays well-defined.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|----|--------|----------|------|----------|---------------|---------------------|
| X113 | D | Run-control replay: same word twice | 1 | Drive RUNNING twice in 5 cycles. | ctrl_state_q stays RUNNING; engine continues. | TBD |
| X114 | D | Run-control word valid 1-cycle pulse | 1 | Pulse asi_ctrl_valid 1 cycle. | Word latched; engine state updates. | TBD |
| X115 | D | Run-control word valid 100-cycle hold | 1 | Hold valid+word for 100 cycles. | Latched once; subsequent re-latches no-op (same word). | TBD |
| X116 | D | Run-control valid no ready (asi_ctrl_ready=0) | 1 | If implemented. | Word not latched; sender must retry. | TBD |
| X117 | D | Run-control IDLE after long RUNNING | 1 | RUNNING 1M cycles → IDLE. | Engine stops; queued L2 NOT drained (no TERMINATING). | TBD |
| X118 | D | Run-control TERMINATING then re-RUNNING | 1 | TERMINATING 100 cycles → RUNNING. | Drain interrupted; new RUNNING starts; old hits may finish drain. | TBD |
| X119 | D | Run-control fast IDLE↔RUNNING cycle | 1 | Toggle every 10 cycles. | Engine starts/stops cleanly; no stuck state. | TBD |
| X120 | D | Run-control SYNC every frame | 1 | Pulse SYNC at every frame_start. | Frame discards; LFSRs reseed every frame; no hits emitted. | TBD |
| X121 | D | Run-control RESET state vs hardware i_rst | 1 | Drive RESET 100 cycles. | Engine fully reset; CSR LAST_* preserved (RESET state, not i_rst). | TBD |
| X122 | D | Run-control during inject | 1 | Inject 1000 hits + RUNNING/TERMINATING toggle. | Inject hits land per state at inject cycle. | TBD |
| X123 | D | Run-control with pending engine_busy | 1 | Engine_busy 1M cycle simulated; SYNC. | engine_busy clears immediately; queued tickets discarded. | TBD |
| X124 | D | Run-control while CSR is being written | 1 | Write CSR + drive RUNNING. | Both effective; no contention. | TBD |
| X125 | D | Run-control AvST sink ready=1 forever | 1 | Default. | Latch every word the source sends. | TBD |
| X126 | D | Run-control word with all 9 bits set | 1 | Drive 9'h1FF. | Treated as illegal multi-bit; engine takes defined path. | TBD |
| X127 | D | Run-control word OUT_OF_DAQ for 10M cycles | 1 | Hold OUT_OF_DAQ. | Engine silent throughout; line K28.5 idle; no counters increment. | TBD |
| X128 | D | Run-control transition at clock-domain boundary | 1 | If async ctrl AvST source. | Resync FFs in run_ctl prevent metastability; output stable. | TBD |

---
