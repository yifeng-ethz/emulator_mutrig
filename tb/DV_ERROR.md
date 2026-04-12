# DV Error / Fault Cases — emulator_mutrig

**Purpose:** reset, protocol-negative, fault-containment, and checker-negative cases for Phase 0 signoff  
**Scope notes:** control SPI is out of scope; realistic datapath timing and tunable injection-trigger timing are in scope; these cases intentionally include illegal source behavior and fault injection in the testbench to prove the DUT, checker set, and future shared datapath fail loudly and deterministically.

| ID | Scenario | Checks | Why it exists |
|---|---|---|---|
| X001 | CSR read and write asserted together | Protocol checker flags illegal access | Guards AVMM misuse |
| X002 | CSR address X/Z injection in TB | Protocol checker flags illegal source | Guards X-propagation |
| X003 | CSR write data X/Z injection | Protocol checker flags illegal source | Guards X-propagation |
| X004 | CONTROL write with unknown bits | Reserved masking remains deterministic | Guards software abuse |
| X005 | Invalid CSR read storm | No internal state corruption | Guards abusive software |
| X006 | Invalid CSR write storm | No internal state corruption | Guards abusive software |
| X007 | HIT_RATE set above documented useful range | Behavior bounded and documented | Guards numeric misuse |
| X008 | BURST size above intended semantic range | Behavior clips/saturates deterministically | Guards numeric misuse |
| X009 | BURST center out of range via forced backdoor | Channel handling deterministic | Guards malformed config |
| X010 | Unsupported TX_MODE reserved code 011 | Safe fallback or checker hit | Guards enum holes |
| X011 | Unsupported TX_MODE reserved code 101 | Safe fallback or checker hit | Guards enum holes |
| X012 | Unsupported TX_MODE reserved code 110 | Safe fallback or checker hit | Guards enum holes |
| X013 | Unsupported TX_MODE reserved code 111 | Safe fallback or checker hit | Guards enum holes |
| X014 | `asic_id` unknown/X during active run | Checker catches sideband corruption | Guards X-propagation |
| X015 | `enable` X during active run | Checker catches illegal control source | Guards X-propagation |
| X016 | Mode bit X during active run | Checker catches illegal control source | Guards X-propagation |
| X017 | CTRL source asserts non-one-hot state | Protocol/assertion flags illegal control | Guards upstream misuse |
| X018 | CTRL source toggles data while valid high | Protocol/assertion flags instability | Guards upstream misuse |
| X019 | CTRL valid held high for many cycles with changing states | Only legal capture semantics allowed | Guards control abuse |
| X020 | CTRL transitions RUNNING->invalid->IDLE | DUT/checker behavior deterministic | Guards illegal sequence |
| X021 | CTRL transitions IDLE->TERMINATING | No spurious frame or counter corruption | Guards illegal sequence |
| X022 | CTRL transitions RUNNING->RUN_PREPARE | No deadlock or corrupt state | Guards illegal sequence |
| X023 | CTRL transitions RUNNING->SYNC | No deadlock or corrupt state | Guards illegal sequence |
| X024 | CTRL chatter every cycle | No hidden latch-up | Worst control abuse |
| X025 | Reset asserted during header | Recovery clean; no half-frame persists | Reset fault case |
| X026 | Reset asserted during payload | Recovery clean; no half-frame persists | Reset fault case |
| X027 | Reset asserted during CRC | Recovery clean; no half-frame persists | Reset fault case |
| X028 | Reset asserted during trailer | Recovery clean; no false next frame | Reset fault case |
| X029 | Reset asserted while trigger pending | Pending event discarded or handled per policy | Reset fault case |
| X030 | Reset asserted during back-to-back triggers | No duplicate or ghost hit after reset | Reset fault case |
| X031 | Repeated short reset pulses | No metastable lingering state in model | Reset robustness |
| X032 | Reset with CSR polling active | Read interface remains deterministic | Reset robustness |
| X033 | Inject pulse X/Z in TB | Checker flags illegal trigger source | Guards X-propagation |
| X034 | Inject pulse narrower than one destination sample | No double-count or metastable artifact | Synchronizer robustness |
| X035 | Inject pulse held high many cycles | Defined one-shot or repeated behavior enforced | Edge-detector robustness |
| X036 | Inject chatter around clock edge | No duplicate hits beyond policy | Synchronizer robustness |
| X037 | Inject pulses while disabled | No ghost output frame | Gating fault case |
| X038 | Inject pulses while not RUNNING | No ghost output frame | Gating fault case |
| X039 | Inject pulses during TERMINATING | No ghost output frame | Run-stop fault case |
| X040 | Inject pulses at impossible configured delay | Checker or clipping policy observed | Timing-config fault |
| X041 | Trigger-to-hit latency below minimum tolerance | Timing checker reports violation | Ensures checker sensitivity |
| X042 | Trigger-to-hit latency above maximum tolerance | Timing checker reports violation | Ensures checker sensitivity |
| X043 | Delay monotonicity intentionally violated via fault injection | Timing checker reports violation | Ensures checker sensitivity |
| X044 | Per-hit offset intentionally scrambled in model | Scoreboard reports payload timing mismatch | Ensures checker sensitivity |
| X045 | Frame interval intentionally shortened in faulted DUT model | Timing checker reports violation | Ensures checker sensitivity |
| X046 | Frame interval intentionally lengthened in faulted DUT model | Timing checker reports violation | Ensures checker sensitivity |
| X047 | Header symbol intentionally corrupted in TB fault mode | Frame parser flags malformed frame | Ensures parser sensitivity |
| X048 | Trailer symbol intentionally corrupted in TB fault mode | Frame parser flags malformed frame | Ensures parser sensitivity |
| X049 | CRC byte intentionally flipped in TB fault mode | CRC checker flags mismatch | Ensures integrity checker sensitivity |
| X050 | Event-count field intentionally wrong | Scoreboard flags metadata/payload mismatch | Ensures metadata checker sensitivity |
| X051 | Frame-count field intentionally repeated | Scoreboard flags monotonicity failure | Ensures counter checker sensitivity |
| X052 | Channel tag intentionally flipped | Scoreboard flags lane/ASIC mismatch | Ensures sideband checker sensitivity |
| X053 | Error sideband spuriously asserted | Checker flags unexpected error | Ensures clean-path monitoring |
| X054 | Idle comma replaced by data byte in fault mode | Idle-policy checker flags violation | Ensures idle checker sensitivity |
| X055 | Payload byte dropped in long frame fault mode | Length/CRC checker flags violation | Ensures parser sensitivity |
| X056 | Payload byte duplicated in long frame fault mode | Length/CRC checker flags violation | Ensures parser sensitivity |
| X057 | Short-mode half-byte packing fault injected | Parser/scoreboard flags packing error | Ensures short-path sensitivity |
| X058 | Wrong lane ID embedded in merged stream | 8-lane scoreboard flags source mismatch | Ensures merge checker sensitivity |
| X059 | Equal-timestamp tie intentionally mis-ordered | 8-lane scoreboard/SVA flags violation | Ensures arbiter checker sensitivity |
| X060 | Later timestamp emitted before earlier one | 8-lane scoreboard/SVA flags violation | Ensures ordering checker sensitivity |
| X061 | Active lane starved in faulted shared arbiter | Starvation SVA flags violation | Ensures fairness checker sensitivity |
| X062 | Duplicate merged hit emitted | Scoreboard flags duplicate consumption | Ensures merge checker sensitivity |
| X063 | One merged hit dropped | Scoreboard flags missing hit | Ensures merge checker sensitivity |
| X064 | Shared queue returns stale entry | Scoreboard flags stale timestamp/channel | Ensures queue checker sensitivity |
| X065 | Shared timestamp base corrupted by one tick | Golden merge mismatch detected | Ensures shared-timebase sensitivity |
| X066 | Lane-local offset table swapped between lanes | Golden merge mismatch detected | Ensures config-isolation sensitivity |
| X067 | Shared packetizer retains previous mode state | Parser flags wrong format | Ensures packetizer sensitivity |
| X068 | Shared packetizer retains previous lane ID | Scoreboard flags wrong provenance | Ensures packetizer sensitivity |
| X069 | Shared config fanout writes wrong lane | Lane-local mismatch detected | Ensures config routing sensitivity |
| X070 | Shared config fanout drops one write | Lane-local mismatch detected | Ensures config routing sensitivity |
| X071 | Shared datapath emits hit for disabled lane | Scoreboard flags illegal lane activity | Ensures gating sensitivity |
| X072 | Shared datapath suppresses enabled lane | Scoreboard flags missing activity | Ensures gating sensitivity |
| X073 | Shared datapath mis-orders same-lane equal timestamps | Monotonic/order checker flags violation | Ensures local ordering sensitivity |
| X074 | Shared datapath mis-orders cross-lane timestamps after wrap | Monotonic/order checker flags violation | Ensures wrap sensitivity |
| X075 | Frame parser fed truncated capture stream | Parser exits with explicit malformed-frame result | Guards TB robustness |
| X076 | Frame parser fed extra trailing garbage | Parser exits with explicit malformed-frame result | Guards TB robustness |
| X077 | Scoreboard receives trigger without output | Timeout path reports missing frame clearly | Guards TB robustness |
| X078 | Scoreboard receives output without trigger | Spurious-frame path reports clearly | Guards TB robustness |
| X079 | Scoreboard receives out-of-order trigger IDs | Diagnostic remains actionable | Guards TB robustness |
| X080 | Timing histogram subscriber fed NaN/X sample | Tooling rejects corrupt measurement | Guards TB robustness |
| X081 | Coverage bins intentionally left unreachable in fault mode | Coverage report calls out gap explicitly | Guards coverage plumbing |
| X082 | SVA bind path broken in fault mode | Regression detects missing assertions | Guards assertion plumbing |
| X083 | Monitor disconnect fault injection | Regression detects missing transactions | Guards analysis topology |
| X084 | Wrong clock connected to monitor in TB fault mode | Timing/order checks fail immediately | Guards TB integration |
| X085 | Wrong reset polarity in TB fault mode | Bring-up checks fail immediately | Guards TB integration |
| X086 | Wrong byte ordering in monitor fault mode | Parser/scoreboard fail immediately | Guards TB integration |
| X087 | Wrong CRC polynomial in checker fault mode | Clean DUT run still fails, proving checker is active | Guards checker realism |
| X088 | Wrong tie-break policy in checker fault mode | Clean DUT run still fails, proving checker is active | Guards checker realism |
| X089 | Wrong delay model in reference model | Clean DUT run still fails, proving timing model is active | Guards checker realism |
| X090 | Wrong burst center model in reference model | Clean DUT run still fails, proving feature model is active | Guards checker realism |
| X091 | Wrong short-packing model in reference model | Clean DUT run still fails, proving packing model is active | Guards checker realism |
| X092 | Wrong long-packing model in reference model | Clean DUT run still fails, proving packing model is active | Guards checker realism |
| X093 | Wrong frame interval model | Clean DUT run still fails, proving timing model is active | Guards checker realism |
| X094 | Wrong idle-policy model | Clean DUT run still fails, proving idle checking is active | Guards checker realism |
| X095 | Wrong lane merge model | Clean 8-lane run still fails, proving merge model is active | Guards checker realism |
| X096 | Wrong channel-tag model | Clean run still fails, proving sideband model is active | Guards checker realism |
| X097 | Single-lane area-optimized build omits required field | Equivalence run flags mismatch | Guards optimization mistakes |
| X098 | Single-lane area-optimized build changes latency | Timing checker flags mismatch | Guards optimization mistakes |
| X099 | Shared 8-lane area-optimized build drops fairness | SVA/scoreboard flags violation | Guards optimization mistakes |
| X100 | Shared 8-lane area-optimized build aliases lane state | Scoreboard flags cross-lane corruption | Guards optimization mistakes |
| X101 | Shared 8-lane area-optimized build changes tie policy | Scoreboard flags ordering mismatch | Guards optimization mistakes |
| X102 | Shared 8-lane area-optimized build changes idle behavior | Checker flags idle mismatch | Guards optimization mistakes |
| X103 | Shared 8-lane area-optimized build changes CRC | Checker flags integrity mismatch | Guards optimization mistakes |
| X104 | Shared 8-lane area-optimized build changes frame count | Checker flags metadata mismatch | Guards optimization mistakes |
| X105 | Shared 8-lane area-optimized build changes delay mapping | Timing checker flags mismatch | Guards optimization mistakes |
| X106 | Shared 8-lane area-optimized build changes mode-switch point | Checker flags stale state | Guards optimization mistakes |
| X107 | Full-population 8-lane run with one lane faulted in TB | Fault is isolated and diagnosable | Fault containment |
| X108 | Full-population 8-lane run with two lanes faulted | Fault is isolated and diagnosable | Fault containment |
| X109 | Full-population 8-lane run with merger fault injected | Golden merge catches exact divergence | Fault containment |
| X110 | Full-population 8-lane run with packetizer fault injected | Parser catches exact divergence | Fault containment |
| X111 | Full-population 8-lane run with timestamp fault injected | Timing checker catches exact divergence | Fault containment |
| X112 | Full-population 8-lane run with fairness fault injected | Starvation checker catches exact divergence | Fault containment |
| X113 | Quartus area-report parser sees missing ALM line | Flow fails loudly | Guards signoff tooling |
| X114 | Quartus area-report parser sees malformed ALM line | Flow fails loudly | Guards signoff tooling |
| X115 | Quartus area-report parser sees ALM > 4000 | Flow blocks signoff explicitly | Guards hard area gate |
| X116 | Quartus area-report parser sees ALM exactly 4000 | Flow honors strict less-than policy | Guards hard area gate |
| X117 | Quartus area-report from wrong top-level | Flow rejects mismatched report | Guards signoff tooling |
| X118 | Quartus area-report from stale revision | Flow rejects mismatched report | Guards signoff tooling |
| X119 | Signoff seed bundle with checker fault A | Bundle fails loudly | Ensures no silent checker disable |
| X120 | Signoff seed bundle with checker fault B | Bundle fails loudly | Ensures no silent checker disable |
| X121 | Signoff seed bundle with parser fault | Bundle fails loudly | Ensures no silent parser disable |
| X122 | Signoff seed bundle with scoreboard fault | Bundle fails loudly | Ensures no silent scoreboard disable |
| X123 | Signoff seed bundle with timing model fault | Bundle fails loudly | Ensures no silent timing disable |
| X124 | Signoff seed bundle with SVA disabled | Bundle fails loudly | Ensures no silent assertion disable |
| X125 | Area-signoff top with injected merge fault | Exact top fails clearly | Final-top fault sensitivity |
| X126 | Area-signoff top with injected timing fault | Exact top fails clearly | Final-top fault sensitivity |
| X127 | Area-signoff top with injected packet fault | Exact top fails clearly | Final-top fault sensitivity |
| X128 | Final negative regression bundle | Every intentional fault is detected by at least one checker | Final confidence in the DV harness |
