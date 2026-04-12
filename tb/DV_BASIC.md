# DV Basic Cases — emulator_mutrig

**Purpose:** deterministic feature-completion cases for Phase 0 signoff  
**Scope notes:** control SPI is out of scope; realistic datapath timing and tunable injection-trigger timing are in scope; cases cover the current single-lane baseline and the intended future shared 8-lane merged-datapath architecture where relevant.

| ID | Scenario | Checks | Why it exists |
|---|---|---|---|
| B001 | Reset asserted at power-up | Outputs idle/quiet, counters clear | Proves safe bring-up state |
| B002 | Reset release into IDLE | No spurious frame after reset release | Catches startup garbage emission |
| B003 | IDLE state held | Output remains comma-idle only | Proves run gating baseline |
| B004 | RUN_PREPARE pulse | No premature data frame | Separates prepare from running |
| B005 | SYNC to RUNNING transition | Data starts only after RUNNING | Validates state decode boundary |
| B006 | TERMINATING to IDLE | Output returns to idle cleanly | Proves stop behavior |
| B007 | `enable=1` in CONTROL | Datapath can emit active frames | Basic functional enable path |
| B008 | `enable=0` in CONTROL | Datapath forced to idle | Basic functional disable path |
| B009 | `hit_mode=00` | Poisson mode selected/read back | Confirms mode decode |
| B010 | Long mode power-on | Long-format path chosen | Confirms default framing mode |
| B011 | Short mode bit set | Short-format path chosen | Confirms alternate framing mode |
| B012 | `tx_mode=LONG` | Long TX path active | Baseline transmitter mode |
| B013 | `tx_mode=PRBS_1` | Single-PRBS debug frame emitted | Confirms debug path presence |
| B014 | `tx_mode=PRBS_SAT` | Saturating PRBS mode emitted | Confirms second debug path |
| B015 | `gen_idle=1` | Idle commas appear between frames | Checks inter-frame fill behavior |
| B016 | `asic_id` programmed | Channel sideband matches ID | Proves downstream tag correctness |
| B017 | CONTROL defaults | Readback matches reset defaults | Guards reset-map regression |
| B018 | HIT_RATE defaults | Rate fields match defaults | Guards probability defaults |
| B019 | BURST_CFG defaults | Burst size/center default correctly | Guards burst reset values |
| B020 | PRNG_SEED default | Seed resets as documented | Ensures deterministic startup |
| B021 | STATUS default | Status words are zero on reset | Confirms clean counters |
| B022 | Write/read CONTROL | Written control bits read back | Basic CSR integrity |
| B023 | Write/read HIT_RATE | 32-bit rate word preserved | Basic CSR integrity |
| B024 | Write/read BURST_CFG | Burst fields preserved | Basic CSR integrity |
| B025 | Write/read PRNG_SEED | Seed word preserved | Basic CSR integrity |
| B026 | Write/read TX_MODE | Mode word preserved | Basic CSR integrity |
| B027 | CONTROL reserved bits | Reserved bits read as zero | Catches stale state leakage |
| B028 | BURST_CFG reserved bits | Reserved bits read as zero | Catches packing errors |
| B029 | Invalid CSR read address | Read returns zero/default safe value | Defines out-of-range behavior |
| B030 | CSR write waitrequest handshake | Accepted write has clean waitrequest behavior | Verifies AVMM protocol |
| B031 | CSR read waitrequest handshake | Accepted read has clean waitrequest behavior | Verifies AVMM protocol |
| B032 | No simultaneous read/write | Interface rejects or ignores illegal overlap deterministically | Locks down CSR semantics |
| B033 | Long frame header | First byte is K28.0 header | Proves frame start format |
| B034 | Long frame trailer | Last byte is K28.4 trailer | Proves frame end format |
| B035 | Long empty frame | Zero-event frame length is correct | Checks no-hit baseline |
| B036 | Long one-hit frame | One-hit long frame length correct | Smallest payload case |
| B037 | Long multi-hit frame | Length scales by 6 bytes/hit | Validates long packing arithmetic |
| B038 | Long frame counter | Counter increments by one/frame | Validates state accounting |
| B039 | Long event count field | Event count matches actual hits | Proves payload metadata |
| B040 | Long frame CRC | CRC bytes match recomputed value | Catches framing corruption |
| B041 | Long hit channel field | Channel bits pack correctly | Verifies hit word layout |
| B042 | Long hit `T_BadHit` | Flag bit lands in correct position | Verifies hit word layout |
| B043 | Long hit `TCC` field | Timestamp coarse field packs correctly | Verifies timing data path |
| B044 | Long hit `T_Fine` field | Fine timestamp field packs correctly | Verifies timing data path |
| B045 | Long hit `E_BadHit` | Energy bad-hit bit packs correctly | Verifies hit word layout |
| B046 | Long hit `E_Flag` | Energy flag bit packs correctly | Verifies hit word layout |
| B047 | Long hit `ECC` field | Energy coarse field packs correctly | Verifies timing data path |
| B048 | Long hit `E_Fine` field | Energy fine field packs correctly | Verifies timing data path |
| B049 | Short frame header | First byte is K28.0 header | Proves short frame start |
| B050 | Short frame trailer | Last byte is K28.4 trailer | Proves short frame end |
| B051 | Short empty frame | Zero-event short frame legal | Checks no-hit short path |
| B052 | Short one-hit frame | One-hit short frame legal | Smallest short payload |
| B053 | Short odd-hit packing | 3/4-byte alternation handled correctly | Catches odd-count bug |
| B054 | Short even-hit packing | Even hit count packs correctly | Catches alignment bug |
| B055 | Short event count field | Event count matches actual hits | Proves metadata in short mode |
| B056 | Short frame CRC | CRC bytes match recomputed value | Catches short-path corruption |
| B057 | Short hit channel field | Channel packs correctly | Verifies short word layout |
| B058 | Short hit `E_BadHit` | Flag bit packs correctly | Verifies short word layout |
| B059 | Short hit `TCC` field | Time coarse field packs correctly | Verifies short timing data |
| B060 | Short hit `T_Fine` field | Time fine field packs correctly | Verifies short timing data |
| B061 | Short hit `E_Flag` | Flag bit packs correctly | Verifies short word layout |
| B062 | Short frame interval | Frame spacing is 910 byte clocks at 125 MHz | Confirms architect-correct short timing |
| B063 | Long frame interval | Frame spacing is 1550 byte clocks at 125 MHz | Confirms architect-correct long timing |
| B064 | Long-to-short mode switch | First frame after switch matches new mode | Catches stale mode state |
| B065 | Poisson zero rate | No random hits at zero threshold | Baseline statistical sanity |
| B066 | Poisson low rate | Sparse hits appear with low threshold | Checks low-end sensitivity |
| B067 | Poisson nominal rate | Mean count near configured nominal | Baseline probabilistic behavior |
| B068 | Poisson fixed-seed replay | Same seed reproduces same stream | Enables deterministic debug |
| B069 | Burst center channel | Burst is centered on configured channel | Verifies burst semantics |
| B070 | Burst size programming | Cluster width matches configured size | Verifies burst semantics |
| B071 | Noise mode basic | Noise-only hits emitted | Confirms dedicated mode path |
| B072 | Mixed mode basic | Poisson plus burst both observable | Confirms mixed arbitration |
| B073 | Inject min delay | Hit timestamp reflects minimum programmed delay | Verifies tunable timing floor |
| B074 | Inject mid delay | Hit timestamp reflects mid programmed delay | Verifies tunable timing middle |
| B075 | Inject max delay | Hit timestamp reflects maximum programmed delay | Verifies tunable timing ceiling |
| B076 | Inject at frame boundary | Hit lands in architecturally correct frame | Catches boundary ambiguity |
| B077 | Back-to-back inject pulses | Consecutive pulses both preserved | Verifies trigger throughput |
| B078 | Inject while disabled | No hit generated | Confirms enable gating |
| B079 | Inject while not RUNNING | No hit generated | Confirms run-state gating |
| B080 | Inject phase parameter | Phase model knob changes observed latency predictably | Proves realistic timing tunability |
| B081 | STATUS frame_count on empty frames | Counter increments even on zero-hit frames if frame emitted | Clarifies status semantics |
| B082 | STATUS last_event_count | Status reflects most recent frame occupancy | Verifies software observability |
| B083 | STATUS clears on reset | Status returns to zero after reset | Prevents stale-status bugs |
| B084 | Output channel equals `asic_id` | Sideband stable for whole frame | Downstream routing correctness |
| B085 | Error sideband in clean path | Error bits remain zero in normal operation | Guards accidental alarm |
| B086 | Idle comma before RUNNING | K28.5 emitted in inactive state | Baseline idle behavior |
| B087 | Idle comma after stop | K28.5 resumes immediately after stop | Clean shutdown behavior |
| B088 | No non-idle outside RUNNING | No header/trailer leakage when inactive | Prevents false downstream sync |
| B089 | Seed change changes stream | Different seed changes payload history | Proves seed is live |
| B090 | Same seed after reset repeats | Same seed after reset reproduces known stream | Debug reproducibility |
| B091 | `gen_idle=0` behavior | Inter-frame idle policy matches spec/intent | Resolves configurable idle semantics |
| B092 | PRBS_1 frame payload | Debug payload format correct | Validates debug mode |
| B093 | PRBS_SAT payload | Saturating debug payload correct | Validates debug mode |
| B094 | TX_MODE readback | Mode bits preserved through CSR | Basic software contract |
| B095 | `ctrl.ready` behavior | Ready remains asserted as designed | Verifies control interface contract |
| B096 | Idle-path `valid` behavior | Valid semantics in idle mode are consistent | Prevents protocol mismatch |
| B097 | 8-lane one-active passthrough | Shared datapath matches single-lane golden lane | Baseline merged reference |
| B098 | 8-lane two-active independent config | Per-lane settings stay isolated | Checks shared-state partitioning |
| B099 | 8-lane lane ID preservation | Merged output preserves source lane identity | Needed for downstream demux |
| B100 | 8-lane equal timestamps tie-break | Tie-break follows documented policy | Defines deterministic merge order |
| B101 | 8-lane staggered timestamps | Merge order follows timestamp monotonicity | Validates core merged behavior |
| B102 | 8-lane all lanes one hit | All eight hits emitted exactly once | Basic multi-lane completeness |
| B103 | 8-lane shared counter equivalence | Shared timing core matches 8 golden counters | Checks shared-timing optimization |
| B104 | 8-lane merged frame boundaries | No boundary corruption under merging | Verifies packetizer interaction |
| B105 | 8-lane per-lane delay programming | Delay settings remain lane-local | Required for realistic timing |
| B106 | 8-lane per-lane `asic_id` mapping | Each lane retains unique tagging | Prevents lane aliasing |
| B107 | 8-lane per-lane hit rate isolation | Rate change on one lane does not bleed to others | Checks shared-config hazards |
| B108 | 8-lane per-lane burst cfg isolation | Burst config remains lane-local | Checks shared-config hazards |
| B109 | 8-lane disabled lane quiet | Disabled lane contributes nothing to merge | Basic gating correctness |
| B110 | 8-lane lane stop/start | One lane can stop/start without corrupting others | Shared-arbiter safety |
| B111 | 8-lane no cross-lane corruption | Payload fields never swap lanes | Core merged-datapath correctness |
| B112 | 8-lane deterministic replay | Same multi-lane seeds replay identically | Enables regression reproducibility |
| B113 | Nominal long datapath latency | Trigger-to-first-hit latency matches model in long mode | Realistic timing signoff |
| B114 | Nominal short datapath latency | Trigger-to-first-hit latency matches model in short mode | Realistic timing signoff |
| B115 | Delay sweep coarse points | Min/mid/max latency points monotonic | Proves tunable timing surface |
| B116 | Delay sweep fine step | Adjacent delay steps shift output monotonically | Catches quantization bugs |
| B117 | Trigger-to-first-hit monitor | Measurement infrastructure records expected latency | Enables timing closure in DV |
| B118 | Trigger-to-merged-hit monitor | Shared datapath latency measured per lane | Enables merged timing closure |
| B119 | Delay register monotonicity | Larger programmed delay never yields earlier hit | Fundamental timing invariant |
| B120 | Per-hit offset model | Multi-hit frame offsets match configured/modelled spacing | Makes timing realistic, not just framing |
| B121 | Single-lane vs golden reference | Baseline output bit-exact to golden model | Foundation for all later comparisons |
| B122 | 8-lane shared vs 8x golden | Shared architecture bit-exact to 8-lane golden merge | Proves optimization preserves behavior |
| B123 | Downstream long compatibility | `frame_rcv_ip`-style parser accepts long frames | System-level contract |
| B124 | Downstream short compatibility | `frame_rcv_ip`-style parser accepts short frames | System-level contract |
| B125 | Downstream back-to-back compatibility | Consecutive frames parse without desync | System-level contract |
| B126 | 8-lane area-wrapper smoke | Functional smoke on the exact area-signoff top | Couples DV to ALM target |
| B127 | Standalone vs shared small-pattern equivalence | Small deterministic vectors match exactly | Fast regression for optimization |
| B128 | Signoff replay seed set | Canonical seed bundle reproduces signoff results | Freeze-point regression anchor |
