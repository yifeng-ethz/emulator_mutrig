# Synthesis

## TL;DR

The 26.2.x standalone Quartus syn at `LANE_COUNT=8, BYTE_STREAM_ENABLE=0`
elaborates clean (0 errors, 146 warnings) on the Arria V Quartus 18.1
target but currently **fails timing** by `-2.573 ns` at 125 MHz and is
**14% over the 4000 ALM** target. The static gate (lint+CDC+RDC) passes
across the whole tree.

## Why this exists

Standalone synthesis closure is the gate that turns "the IP simulates"
into "the IP can ship". The numbers below are the first 26.2.x fitter
result and document where the bottlenecks actually are, so the next
patch's pipelining work is targeted.

## How it works

### Standalone signoff harness

- Project: `syn/quartus/emulator_mutrig_syn.qpf`
- Top wrapper: `syn/quartus/emulator_mutrig_syn_top.sv`
- QSF: `syn/quartus/emulator_mutrig_syn.qsf` (Arria V `5AGXBA7D4F31C5`,
  Quartus 18.1 SJ Standard Edition)
- SDC: `syn/quartus/emulator_mutrig_syn.sdc` (`clk125` at 8 ns period;
  setup/hold checked at Slow 1100mV 85C and Slow 1100mV 0C)
- Filelist: `rtl/emulator_mutrig_central_trigger.f`

Invocation:

```bash
cd syn/quartus
quartus_sh --flow compile emulator_mutrig_syn -c emulator_mutrig_syn
```

### Static gate (lint, CDC, RDC, formal)

```bash
python3 ~/.codex/skills/rtl-linter-and-checker/scripts/questa_static_screen.py \
    --top emulator_mutrig \
    --filelist rtl/emulator_mutrig_central_trigger.f \
    --modes lint,cdc,rdc,formal \
    --extra-do tb/formal/emulator_mutrig_formal.do \
    $(awk '/\.sv$/ {print "rtl/" $0}' rtl/emulator_mutrig_central_trigger.f) \
    tb/formal/emulator_mutrig_formal.sv
```

### Measured numbers (primary build)

| Field | Value | Target | Status |
|---|---|---|---|
| ALMs | `4,557 / 91,680 (5%)` | `< 4000` | <span class="tag warn">over target</span> |
| Registers | `6,597` | informational | <span class="tag info">info</span> |
| Block memory bits | `83,968` | informational | <span class="tag info">info</span> |
| RAM blocks (M10K) | `16` | `16` | <span class="tag good">on target</span> |
| DSP blocks | `0` | `0` | <span class="tag good">on target</span> |
| Compile errors | `0` | `0` | <span class="tag good">pass</span> |
| Setup slack (Slow 85C) | `-2.573 ns` | `>= 0` | <span class="tag bad">fails</span> |
| Effective Fmax | `~94.5 MHz` | `>= 125 MHz` | <span class="tag bad">fails</span> |

### Known critical region

The worst path lives in `frontend_trigger_engine.sv`. The single-cycle
`always_ff` block does:

1. `clamp_start_128` for the primary cluster start
2. `clamp_start_128` for the mirror cluster start (if `MIRRORED`)
3. RR pointer advance
4. Per-lane channel-range shred (8-iteration loop computing
   `pending_ch_low/high` per lane)
5. PRNG step

All in one cycle. Pipelining the cluster footprint compute over 2 cycles
before pushing into `pending_mask` should close the timing without
changing functional behaviour.

## Interfaces and contracts

- The standalone wrapper at `syn/quartus/emulator_mutrig_syn_top.sv`
  exposes the IP's external ports as virtual pins so the fitter can
  measure cone delays without pin packing dominating the result.
- Both build axis points share the same QSF; only the top-wrapper's
  `BYTE_STREAM_ENABLE` parameter differs.

## Where to look in the code

- Standalone QSF: `syn/quartus/emulator_mutrig_syn.qsf`
- Standalone wrapper: `syn/quartus/emulator_mutrig_syn_top.sv`
- Fitter summary: `syn/quartus/output_files/emulator_mutrig_syn.fit.summary`
- Timing summary: `syn/quartus/output_files/emulator_mutrig_syn.sta.summary`
- Sign-off dashboard: `syn/SYN_REPORT.md`

## Open questions / gotchas

- Quartus 18.1 Standard's parser rejects `import pkg::*;` in the
  module port-list position (error 10170). The fix in this build moves
  imports into the module body and fully qualifies the
  `frontend_ticket_t` port type. Future modules must follow the same
  pattern.
- The compatibility build (`BYTE_STREAM_ENABLE=1`) and the reduced
  lane-count points (`LANE_COUNT in {1, 2, 4}`) are not yet recompiled
  for the 26.2.x checkpoint.
