# DV Edge Cases — emulator_mutrig

**Purpose:** corner and boundary conditions for Phase 0 signoff  
**Scope notes:** control SPI is out of scope; realistic datapath timing and tunable injection-trigger timing are in scope; cases include the current single-lane baseline first, with future shared 8-lane merged-datapath references kept as follow-on only.

| ID | Scenario | Checks | Why it exists |
|---|---|---|---|
| E001 | Minimum legal injection delay | Hit timestamp lands at exact floor | Verifies lower timing bound |
| E002 | Maximum legal injection delay | Hit timestamp lands at exact ceiling | Verifies upper timing bound |
| E003 | Delay step from min to min+1 | Observed latency increments by one unit | Catches off-by-one timing bug |
| E004 | Delay step from max-1 to max | Observed latency increments by one unit | Catches top-end saturation bug |
| E005 | Trigger one tick before frame launch | Hit assigned to correct frame | Boundary between scheduler epochs |
| E006 | Trigger exactly on frame launch | Deterministic frame assignment | Removes ambiguity at zero skew |
| E007 | Trigger one tick after frame launch | Hit assigned to next legal slot | Checks post-boundary behavior |
| E008 | Trigger during trailer emission | Hit scheduling remains deterministic | Catches trailer overlap bug |
| E009 | Trigger during header emission | Hit scheduling remains deterministic | Catches header overlap bug |
| E010 | Trigger at reset deassertion edge | No metastable/stale hit emitted | Reset/timing corner |
| E011 | Trigger immediately before reset | Pending hit handled deterministically | Reset/timing corner |
| E012 | Trigger immediately after reset | First post-reset hit modeled correctly | Bring-up boundary |
| E013 | Minimum pulse width trigger | Exactly one event captured | Edge detector corner |
| E014 | Multi-cycle wide trigger | One or documented number of events only | Prevents double-capture bug |
| E015 | Two triggers separated by one clock | Both events preserved | Throughput timing floor |
| E016 | Two triggers separated by zero idle clocks in model | DUT behavior matches defined policy | Removes undefined trigger ambiguity |
| E017 | Long mode zero-hit frame | Minimal legal long frame generated | Smallest long payload edge |
| E018 | Long mode one-hit frame | Smallest non-empty long frame correct | Packing boundary |
| E019 | Long mode max legal hits/frame | Frame length and CRC remain valid | Capacity boundary |
| E020 | Long mode max-1 hits/frame | Boundary below capacity behaves correctly | Off-by-one capacity check |
| E021 | Short mode zero-hit frame | Minimal legal short frame generated | Smallest short payload edge |
| E022 | Short mode one-hit frame | Smallest non-empty short frame correct | Packing boundary |
| E023 | Short mode odd max hit count | Final half-byte packing correct | Hardest short packing corner |
| E024 | Short mode even max hit count | Alignment remains correct | Short packing corner |
| E025 | Long-to-short switch on active frame boundary | First short frame clean | Mode-switch edge |
| E026 | Short-to-long switch on active frame boundary | First long frame clean | Mode-switch edge |
| E027 | `gen_idle` toggled between consecutive frames | Idle policy changes cleanly | Config/update boundary |
| E028 | `tx_mode` toggled between consecutive frames | New mode takes effect at correct frame | Mode-update boundary |
| E029 | `asic_id` changed while idle | Next frame uses new ID only | Config boundary |
| E030 | `asic_id` changed while active | Documented take-effect point honored | Config boundary |
| E031 | PRNG seed changed between frames | Stream changes exactly at next frame | Determinism boundary |
| E032 | PRNG seed changed mid-frame | Behavior matches documented staging rule | Config boundary |
| E033 | RUN_PREPARE repeated twice | No false activation | Run-state edge case |
| E034 | SYNC repeated twice | No false activation | Run-state edge case |
| E035 | RUNNING repeated twice | No duplicate reset/arming effect | Run-state edge case |
| E036 | TERMINATING without prior RUNNING | Output remains idle | Illegal/degenerate path |
| E037 | IDLE asserted mid-frame | Datapath shuts down per spec | Stop-path corner |
| E038 | RUNNING entered with `enable=0` | Output remains idle | Crosses gating controls |
| E039 | `enable` cleared mid-frame | Current frame completion follows defined policy | Stop-path corner |
| E040 | `enable` set mid-idle | First active frame starts cleanly | Start-path corner |
| E041 | CTRL valid pulse one cycle | State capture correct | Minimum handshake case |
| E042 | CTRL valid pulse many cycles | No duplicate state captures | Handshake edge |
| E043 | CTRL data changes while valid high | Assertion/checker catches illegal source behavior | Protocol guard |
| E044 | Ready permanently high with sparse control | No phantom transitions | Protocol stability |
| E045 | RUNNING to SYNC backstep | DUT behavior matches defined legal/illegal policy | Transition corner |
| E046 | RUNNING to RUN_PREPARE backstep | DUT behavior matches defined policy | Transition corner |
| E047 | Rapid RUNNING/IDLE chatter | No counter corruption | Run-state robustness |
| E048 | Stop immediately after first active frame | Frame count and idle recovery correct | Early-stop corner |
| E049 | CSR read lowest address | CONTROL read valid | Address-space floor |
| E050 | CSR read highest legal address | STATUS read valid | Address-space ceiling |
| E051 | CSR read first illegal address | Returns defined safe value | Address-space fencepost |
| E052 | CSR write first illegal address | No side effects | Address-space fencepost |
| E053 | CONTROL write all ones | Only defined bits take effect | Masking corner |
| E054 | HIT_RATE write all zeros | Produces no stochastic hits | Numeric floor |
| E055 | HIT_RATE write all ones | Behavior remains bounded and deterministic | Numeric ceiling |
| E056 | BURST size minimum | Single-channel burst legal | Numeric floor |
| E057 | BURST size maximum | Burst width saturates per spec | Numeric ceiling |
| E058 | BURST center minimum channel | Cluster clips/behaves per policy | Channel floor |
| E059 | BURST center maximum channel | Cluster clips/behaves per policy | Channel ceiling |
| E060 | TX_MODE reserved pattern 3'b011 | Behavior matches documented safe fallback | Enum hole |
| E061 | TX_MODE reserved pattern 3'b101 | Behavior matches documented safe fallback | Enum hole |
| E062 | TX_MODE reserved pattern 3'b110 | Behavior matches documented safe fallback | Enum hole |
| E063 | TX_MODE reserved pattern 3'b111 | Behavior matches documented safe fallback | Enum hole |
| E064 | STATUS read while frame starts | Read coherency matches defined timing | Software race corner |
| E065 | Inject pulse exactly every long frame period | One event window per frame | Period alignment edge |
| E066 | Inject pulse exactly every short frame period | One event window per frame | Period alignment edge |
| E067 | Inject pulse just below sustainable rate | No loss at near-limit rate | Throughput corner |
| E068 | Inject pulse just above sustainable rate | Behavior matches documented overflow/drop policy | Throughput corner |
| E069 | Burst-mode trigger near channel 0 | Left-edge burst handling correct | Channel edge |
| E070 | Burst-mode trigger near channel 31 | Right-edge burst handling correct | Channel edge |
| E071 | Noise mode at minimum non-zero rate | Occasional hits still legal | Probabilistic floor |
| E072 | Noise mode at very high rate | Frameing remains valid | Probabilistic ceiling |
| E073 | Mixed mode with zero burst contribution | Degenerates cleanly to Poisson-like behavior | Mode edge |
| E074 | Mixed mode with zero Poisson contribution | Degenerates cleanly to burst-like behavior | Mode edge |
| E075 | Long frame with exactly CRC-boundary payload size | CRC window remains correct | Checksum edge |
| E076 | Short frame with alternating 3/4-byte boundary at trailer | Trailer alignment remains correct | Packing edge |
| E077 | Frame counter wrap from 0xFFFF to 0 | Wrap behavior defined and correct | Counter edge |
| E078 | Event count reaches 10-bit max visible range | STATUS/readback remains correct | Counter edge |
| E079 | STATUS event_count sampled at wrap boundary | No transient invalid value | Counter edge |
| E080 | Continuous idle commas for extended time | No hidden frame starts | Long-idle stability |
| E081 | 8-lane two-lane equal timestamp tie | Lower-index lane wins | Smallest merge tie case |
| E082 | 8-lane three-lane equal timestamp tie | Order follows deterministic policy | Multi-way tie corner |
| E083 | 8-lane all-eight equal timestamp tie | Total order matches policy | Worst tie corner |
| E084 | 8-lane oldest hit on highest lane index | Arbiter still picks by timestamp, not lane | Merge correctness |
| E085 | 8-lane youngest hit on lowest lane index | Arbiter ignores lane bias when timestamp later | Merge correctness |
| E086 | 8-lane one permanently idle lane | No false starvation flags | Activity-mask corner |
| E087 | 8-lane one permanently active hot lane | Other lanes still drain when eligible | Fairness corner |
| E088 | 8-lane alternating active-lane mask | Shared resources reconfigure cleanly | Dynamic activity edge |
| E089 | 8-lane per-lane minimum delay mix | All lanes honor independent minimum settings | Config isolation edge |
| E090 | 8-lane per-lane maximum delay mix | All lanes honor independent maximum settings | Config isolation edge |
| E091 | 8-lane min/max mixed simultaneously | Merge order still correct | Timing-dispersion corner |
| E092 | 8-lane identical payloads different lanes | Lane provenance preserved | Aliasing corner |
| E093 | 8-lane identical seeds all lanes | Shared implementation avoids unintended coupling | Shared-state corner |
| E094 | 8-lane distinct seeds all lanes | Shared implementation keeps streams independent | Shared-state corner |
| E095 | 8-lane one lane reset/glitched in TB model | Isolation policy defined and enforced | Fault-containment edge |
| E096 | 8-lane lane stop during tie condition | Merge recovers without duplicate/drop | Dynamic merge corner |
| E097 | Shared datapath single active lane at max rate | Shared fabric equals standalone latency | Optimization edge |
| E098 | Shared datapath two active lanes at max rate | No scheduler starvation | Optimization edge |
| E099 | Shared datapath lane switch every cycle | Context switch correct | Time-multiplexing edge |
| E100 | Shared datapath lane switch every frame | Context switch correct | Time-multiplexing edge |
| E101 | Shared datapath common timestamp counter wrap | All lane comparisons remain correct | Shared-timebase edge |
| E102 | Shared datapath lane-local offset under wrap | Addition/compare remains correct | Shared-timebase edge |
| E103 | Shared packetizer idle after merged burst | Clean return to idle | Shared-packetizer edge |
| E104 | Shared packetizer mode mix across lanes | Mode metadata preserved through merge | Shared-packetizer edge |
| E105 | Shared packetizer long then short from different lanes | No stale packing state | Shared-packetizer edge |
| E106 | Shared packetizer short then long from different lanes | No stale packing state | Shared-packetizer edge |
| E107 | Shared datapath with disabled middle lane | Lane indexing remains contiguous/correct | Sparse-lane edge |
| E108 | Shared datapath with only highest lane active | Lane-ID decode remains correct | Sparse-lane edge |
| E109 | Shared datapath with only lowest lane active | Baseline passthrough remains correct | Sparse-lane edge |
| E110 | Shared datapath repeated same timestamp from one lane | Stable self-ordering preserved | Queue corner |
| E111 | Shared datapath repeated same timestamp across lanes | Tie policy repeated deterministically | Queue corner |
| E112 | Shared datapath maximum configured lookahead | Merge still chooses oldest legal head | Queue corner |
| E113 | Area-signoff top with one lane enabled | Functional wrapper works at smallest population | Wrapper edge |
| E114 | Area-signoff top with eight lanes enabled | Functional wrapper works at full population | Wrapper edge |
| E115 | Area-signoff top with 4 active, 4 idle | Shared gating preserves correctness | Wrapper edge |
| E116 | Area-signoff top with mixed long/short lanes | Wrapper handles heterogeneous modes | Wrapper edge |
| E117 | Area-signoff top reset all lanes simultaneously | Global reset clean | Wrapper edge |
| E118 | Area-signoff top lane-enable bitmap changes | Config fanout edge | Wrapper edge |
| E119 | Standalone vs shared one-hit equivalence | Both implementations match on minimal vector | Equivalence floor |
| E120 | Standalone vs shared max-hit equivalence | Both implementations match at payload ceiling | Equivalence ceiling |
| E121 | Standalone vs shared min-delay equivalence | Both match at timing floor | Equivalence edge |
| E122 | Standalone vs shared max-delay equivalence | Both match at timing ceiling | Equivalence edge |
| E123 | Standalone vs shared tie-case equivalence | Shared merge matches golden composition | Equivalence edge |
| E124 | Standalone vs shared idle behavior equivalence | Same idle/comma policy | Equivalence edge |
| E125 | Standalone vs shared frame-count evolution | Counters evolve consistently | Equivalence edge |
| E126 | Standalone vs shared CRC equivalence | Packet integrity preserved by optimization | Equivalence edge |
| E127 | Signoff seed set with all boundary knobs | All documented boundary knobs replay cleanly | Regression freeze case |
| E128 | Boundary-case bundle on area-signoff top | Edge regressions exercised on exact synthesis target | Final pre-implementation gate |
| E129 | `TERMINATING` edge at pending frame start | No fresh frame starts after the stop edge and the terminal boundary is handled once | Catches the exact post-stop parsing hole described in the run-sequence plan |
