# Overview

## TL;DR

`emulator_mutrig` is a synthesisable FPGA model of one MuTRiG ASIC's digital
output, used to drive Mu3e datapath IP without a real MuTRiG. The 26.2.x
refresh splits it into a detector-agnostic front-end (hit generation) and a
swappable per-lane back-end (MuTRiG word formatter), so the same engine can
later feed a MuPix back-end without rewriting the trigger and CSR layer.

## Why this exists

Bringing up the Mu3e online datapath without 8 real MuTRiG ASICs in the
loop needs a synthesisable source that produces the same byte stream and
hit_type0 packets. The legacy emulator was 8 single-lane copies wired in a
Qsys system; that didn't model cluster geometry across SiPM channels and
duplicated the launch-decision logic 8 times. The 26.2.x refresh
consolidates the launch decision into one place, models real cluster
geometry (`FIX` and `RANDOM` with a SciFi double-sided mirror), and drops
the per-lane footprint by lifting the byte-stream output to an
elaboration-time feature axis.

## How it works

```
+---- FRONT-END (one block) ----+   ticket bus per lane   +---- BACK-END (per lane) ----+
| frontend_csr                  |  --------------------> | be_mutrig_lane_emitter      |
| frontend_run_ctl              |  fire-and-forget       | be_mutrig_l2_fifo (256x48)  |
| frontend_trigger_engine       |  ready/valid           | be_mutrig_lane_type0_emit   |
| frontend_bkg_generator        |                        | be_mutrig_frame_assembler*  |
| frontend_ticket_distributor   |                        +-----------------------------+
+-------------------------------+                        * generate-gated by BYTE_STREAM_ENABLE
```

- One AVMM CSR slave (6-bit address, golden Mu3e header at `0x00..0x06`).
- One run-control AvST sink.
- One conduit `coe_inject_pulse`.
- 8 × `aso_hit_type0_*` AvST sources (primary output).
- 8 × `aso_tx8b1k_*` AvST sources (only synthesised when
  `BYTE_STREAM_ENABLE=1`).

## Interfaces and contracts

- **CSR map:** see [CSR Map](csr_map.html).
- **Per-lane ticket bus:** see [Architecture](architecture.html) §2.0.
- **hit_type0 wire format:** matches `mutrig_frame_deassembly`'s
  `aso_hit_type0_*` contract exactly (see [Interfaces](interfaces.html)).
- **Run-control encoding:** 9-bit one-hot AvST sink, same as the rest of
  the Mu3e datapath.

## Where to look in the code

- Top: `rtl/emulator_mutrig.sv`
- Front-end: `rtl/frontend/`
- Back-end (MuTRiG): `rtl/backend_mutrig/`
- Common (packages, PRBS-15, CRC): `rtl/common/`
- RTL plan (source of truth): `doc/RTL_PLAN_central_trigger.md`

## Open questions / gotchas

- The packaged `emulator_mutrig_hw.tcl` still describes the legacy
  single-lane shape; until the packaging refresh lands, integration
  systems must reference the RTL directly via QSF rather than as a
  packaged Qsys IP.
- Synthesis at 125 MHz currently fails timing by `-2.573 ns` (see
  [Synthesis](synthesis.html)). Pipelining the `frontend_trigger_engine`
  cluster decode is a known follow-up.
