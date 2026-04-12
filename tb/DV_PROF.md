# DV Performance / Soak Cases — emulator_mutrig

**Purpose:** stress, throughput, latency-distribution, and soak cases for Phase 0 signoff  
**Scope notes:** control SPI is out of scope; realistic datapath timing and tunable injection-trigger timing are in scope; the 8-lane `<4k ALM` target is treated as a first-class validation concern because shared-resource optimizations must survive long-running regressions.

| ID | Scenario | Checks | Why it exists |
|---|---|---|---|
| P001 | Single-lane long mode soak 1k frames | No frame corruption over run | Basic long soak |
| P002 | Single-lane long mode soak 10k frames | Counters and CRC remain stable | Medium endurance |
| P003 | Single-lane long mode soak 100k frames | No drift or wrap anomalies | Long endurance |
| P004 | Single-lane short mode soak 1k frames | No frame corruption over run | Basic short soak |
| P005 | Single-lane short mode soak 10k frames | Counters and CRC remain stable | Medium endurance |
| P006 | Single-lane short mode soak 100k frames | No drift or wrap anomalies | Long endurance |
| P007 | Single-lane idle-only soak | No unexpected headers in long idle | Detects latent oscillation |
| P008 | Single-lane mode-switch soak | Repeated long/short switches stay clean | State endurance |
| P009 | Poisson low-rate long run | Mean/variance remain within envelope | Statistical stability |
| P010 | Poisson nominal-rate long run | Mean count tracks configured target | Statistical stability |
| P011 | Poisson high-rate long run | No frame-format collapse | Stresses generator |
| P012 | Noise low-rate long run | Rare events still legal | Statistical stability |
| P013 | Noise high-rate long run | Output remains framed/CRC-valid | Stresses generator |
| P014 | Mixed mode long run | Both contributors remain observable | Mixed-source endurance |
| P015 | Burst mode periodic run | Cluster width remains stable over time | Burst stability |
| P016 | Burst mode random-center run | Center tracking remains stable | Burst stability |
| P017 | Min-delay latency histogram | Distribution centered at timing floor | Timing profiling |
| P018 | Mid-delay latency histogram | Distribution centered at mid setting | Timing profiling |
| P019 | Max-delay latency histogram | Distribution centered at timing ceiling | Timing profiling |
| P020 | Full delay sweep histogram | Latency bins monotonic across sweep | Timing profiling |
| P021 | Long-mode trigger-to-first-hit latency run | No outliers beyond tolerance | Timing profiling |
| P022 | Short-mode trigger-to-first-hit latency run | No outliers beyond tolerance | Timing profiling |
| P023 | Per-hit offset latency run | Multi-hit offsets remain stable | Timing profiling |
| P024 | Inject phase sweep run | Sub-cycle phase knob changes distribution predictably | Realistic timing profiling |
| P025 | Back-to-back triggers at sustainable rate | No drop over extended run | Throughput ceiling |
| P026 | Triggers just below sustainable rate | Stable throughput margin | Throughput knee |
| P027 | Triggers just above sustainable rate | Drop/defer behavior matches policy | Throughput knee |
| P028 | Maximum legal long payload repeated | Sustained max long payload stays correct | Payload stress |
| P029 | Maximum legal short payload repeated | Sustained max short payload stays correct | Payload stress |
| P030 | Alternating max/min payload run | No stale length state | Payload stress |
| P031 | Alternating empty/full frames | Counters and CRC remain coherent | Payload stress |
| P032 | PRBS debug mode soak | Debug path stable over long run | Debug-path endurance |
| P033 | Single-lane reset every 100 frames | Recovery always clean | Periodic reset soak |
| P034 | Single-lane reset every 1k frames | Recovery always clean | Periodic reset soak |
| P035 | Single-lane reset at pseudo-random intervals | No hidden reset/order bug | Reset endurance |
| P036 | Stop/start every 10 frames | Counters remain coherent | Run-control endurance |
| P037 | Stop/start every 100 frames | Counters remain coherent | Run-control endurance |
| P038 | Rapid stop/start chatter run | No dead state reached | Run-control endurance |
| P039 | Enable/disable chatter run | No leakage when disabled | Gating endurance |
| P040 | Seed reload every 50 frames | Transition remains deterministic | Config-update endurance |
| P041 | 8-lane uniform low rate | All lanes drain with equal correctness | Multi-lane baseline |
| P042 | 8-lane uniform nominal rate | All lanes drain with equal correctness | Multi-lane baseline |
| P043 | 8-lane uniform high rate | Shared merge remains lossless if within spec | Multi-lane stress |
| P044 | 8-lane staggered low rate | Merge order remains deterministic | Multi-lane baseline |
| P045 | 8-lane staggered nominal rate | Merge order remains deterministic | Multi-lane baseline |
| P046 | 8-lane staggered high rate | Shared scheduler remains stable | Multi-lane stress |
| P047 | 8-lane bursty synchronized run | Simultaneous arrivals handled repeatedly | Multi-lane stress |
| P048 | 8-lane bursty desynchronized run | Independent lanes remain isolated | Multi-lane stress |
| P049 | 8-lane one-hot rotating active lane | Lane context switch stable over time | Shared-state endurance |
| P050 | 8-lane two-active rotating pair | No pair-specific corruption | Shared-state endurance |
| P051 | 8-lane four-active rotating mask | Shared merge stable under changing masks | Shared-state endurance |
| P052 | 8-lane all-active with per-lane delays | Independent delay settings preserved | Shared-state endurance |
| P053 | 8-lane all-active with per-lane seeds | Independent streams preserved | Shared-state endurance |
| P054 | 8-lane all-active with per-lane modes | Heterogeneous lane behavior preserved | Shared-state endurance |
| P055 | 8-lane all-active long-only run | Sustained merged long traffic stable | Shared-merge throughput |
| P056 | 8-lane all-active short-only run | Sustained merged short traffic stable | Shared-merge throughput |
| P057 | 8-lane mixed long/short run | Shared packetizer handles heterogeneity | Shared-merge throughput |
| P058 | 8-lane equal-timestamp repeated tie run | Tie-break remains deterministic over time | Arbiter endurance |
| P059 | 8-lane rotating tie winners | Every lane can win ties per policy | Arbiter endurance |
| P060 | 8-lane starvation-watch run | No active lane starves over long interval | Fairness endurance |
| P061 | Shared datapath single hot lane max rate | Shared implementation matches standalone throughput | Optimization proof |
| P062 | Shared datapath two hot lanes max rate | Scheduler context switch stable | Optimization proof |
| P063 | Shared datapath four hot lanes max rate | Scheduler context switch stable | Optimization proof |
| P064 | Shared datapath eight hot lanes max rate | Scheduler context switch stable | Optimization proof |
| P065 | Shared timestamp base long run | Common counter never mis-orders hits | Shared-resource proof |
| P066 | Shared timestamp wrap run | Common counter wrap remains safe | Shared-resource proof |
| P067 | Shared packetizer long run | No stale mode/length state | Shared-resource proof |
| P068 | Shared packetizer mixed-mode run | No stale mode/length state | Shared-resource proof |
| P069 | Shared lane-ID mux long run | Lane tagging remains correct | Shared-resource proof |
| P070 | Shared lane-ID mux stress run | Lane tagging remains correct | Shared-resource proof |
| P071 | Shared config fanout steady run | Lane-local cfg remains isolated | Shared-resource proof |
| P072 | Shared config fanout churn run | Lane-local cfg remains isolated under updates | Shared-resource proof |
| P073 | Delay monotonicity sweep on lane 0 | All sampled points monotonic | Timing profiling |
| P074 | Delay monotonicity sweep on lane 7 | All sampled points monotonic | Timing profiling |
| P075 | Delay monotonicity sweep all lanes | All sampled points monotonic | Timing profiling |
| P076 | Trigger phase sweep on one lane | Output latency changes predictably | Timing profiling |
| P077 | Trigger phase sweep all lanes | Shared implementation preserves predictability | Timing profiling |
| P078 | Trigger-to-merged-hit histogram low load | Distribution narrow and bounded | Shared timing profile |
| P079 | Trigger-to-merged-hit histogram nominal load | Distribution narrow and bounded | Shared timing profile |
| P080 | Trigger-to-merged-hit histogram high load | Distribution bounded by design limit | Shared timing profile |
| P081 | Downstream parser compatibility soak long | Consumer stays synchronized | System-level endurance |
| P082 | Downstream parser compatibility soak short | Consumer stays synchronized | System-level endurance |
| P083 | Downstream parser compatibility soak mixed | Consumer stays synchronized | System-level endurance |
| P084 | Downstream parser under back-to-back frames | Consumer stays synchronized | System-level endurance |
| P085 | Downstream parser under tied timestamps | Consumer still sees ordered stream | System-level endurance |
| P086 | STATUS polling while running | Software observability remains coherent | SW-facing endurance |
| P087 | STATUS polling under high load | No incoherent snapshots beyond defined semantics | SW-facing endurance |
| P088 | CSR readback sweep under load | Register reads remain stable | SW-facing endurance |
| P089 | CSR writes between frames over long run | Updates take effect cleanly | SW-facing endurance |
| P090 | CSR writes during active traffic over long run | Behavior matches staged/live-update policy | SW-facing endurance |
| P091 | Seed replay package A | Canonical regression bundle reproducible | Signoff reproducibility |
| P092 | Seed replay package B | Canonical regression bundle reproducible | Signoff reproducibility |
| P093 | Seed replay package C | Canonical regression bundle reproducible | Signoff reproducibility |
| P094 | Seed replay package D | Canonical regression bundle reproducible | Signoff reproducibility |
| P095 | Long-run CRC error watch | CRC mismatches remain zero | Integrity endurance |
| P096 | Long-run frame-structure watch | Header/trailer anomalies remain zero | Integrity endurance |
| P097 | Long-run event-count watch | Metadata/payload mismatch remains zero | Integrity endurance |
| P098 | Long-run channel-tag watch | Lane/ASIC tag mismatches remain zero | Integrity endurance |
| P099 | Long-run idle-policy watch | Idle/comma policy remains stable | Integrity endurance |
| P100 | Long-run error-sideband watch | Unexpected error bits remain zero | Integrity endurance |
| P101 | Area-signoff top functional smoke 1k frames | Exact synthesis target remains functional | Couples DV to area wrapper |
| P102 | Area-signoff top functional soak 10k frames | Exact synthesis target remains functional | Couples DV to area wrapper |
| P103 | Area-signoff top mixed-mask soak | Partial-lane populations remain functional | Couples DV to area wrapper |
| P104 | Area-signoff top mixed-mode soak | Heterogeneous modes remain functional | Couples DV to area wrapper |
| P105 | Area-signoff top delay-sweep soak | Delay model survives on exact top | Couples DV to area wrapper |
| P106 | Area-signoff top high-rate soak | Performance survives on exact top | Couples DV to area wrapper |
| P107 | Area-signoff top reset-soak | Recovery survives on exact top | Couples DV to area wrapper |
| P108 | Area-signoff top equivalence sample run | Exact top matches golden reference | Couples DV to area wrapper |
| P109 | Standalone-vs-shared equivalence long soak | Shared optimization preserves long path | Equivalence endurance |
| P110 | Standalone-vs-shared equivalence short soak | Shared optimization preserves short path | Equivalence endurance |
| P111 | Standalone-vs-shared equivalence mixed soak | Shared optimization preserves mixed path | Equivalence endurance |
| P112 | Standalone-vs-shared equivalence tie-case soak | Shared optimization preserves ordering | Equivalence endurance |
| P113 | Standalone-vs-shared equivalence reset churn | Shared optimization preserves recovery | Equivalence endurance |
| P114 | Standalone-vs-shared equivalence cfg churn | Shared optimization preserves update semantics | Equivalence endurance |
| P115 | Single-lane resource-optimized build smoke | Small-area build still functionally correct | Area-vs-function guard |
| P116 | Single-lane resource-optimized build soak | Small-area build stable over time | Area-vs-function guard |
| P117 | 8-lane resource-optimized build smoke | Area-focused RTL still functionally correct | Area-vs-function guard |
| P118 | 8-lane resource-optimized build soak | Area-focused RTL stable over time | Area-vs-function guard |
| P119 | Multi-lane fairness histogram run | Lane service histogram within acceptable envelope | Performance characterization |
| P120 | Multi-lane occupancy histogram run | Queue/merge occupancy within expected envelope | Performance characterization |
| P121 | Multi-lane latency histogram export run | Timing artifact generated for review | Signoff evidence |
| P122 | Multi-lane throughput summary export run | Rate artifact generated for review | Signoff evidence |
| P123 | Quartus ALM measurement script dry run | Report parser works before signoff | Tooling reliability |
| P124 | Quartus ALM measurement on exact top | ALM evidence captured reproducibly | Signoff evidence |
| P125 | ALM/regression paired run small config | Functional + area evidence aligned | Signoff evidence |
| P126 | ALM/regression paired run full 8-lane config | Functional + area evidence aligned | Signoff evidence |
| P127 | Final signoff seed bundle | All selected performance seeds pass together | Freeze-point confidence |
| P128 | Final signoff endurance bundle on exact top | Exact target survives the closure run | Final Phase 0 gate |
