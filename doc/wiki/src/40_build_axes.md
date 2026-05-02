# Build Axes

## TL;DR

The IP has exactly two elaboration-time feature axes: `LANE_COUNT`
(default 8) and `BYTE_STREAM_ENABLE` (default 0). Synthesis and DV
closure must report results at every legal point on both axes; the
`(8, 0)` point is the gated production build.

## Why this exists

Locking the feature axes makes synthesis closure honest: every "we
support 4 lanes" claim is a real fitter run, not extrapolation. It also
keeps the run-time CSR free of build-time-only choices, so a host
driver does not need to know which build it's talking to in order to
configure the runtime mode.

## How it works

### Axis 1 — Lane count

```
parameter int LANE_COUNT = 8   // legal values: 1, 2, 4, 8
```

- Replicates `be_mutrig_lane_emitter`, `be_mutrig_l2_fifo`,
  `be_mutrig_lane_type0_emit`, and `be_mutrig_frame_assembler` once per
  lane via a `genvar` loop.
- Front-end blocks (`frontend_csr`, `frontend_run_ctl`,
  `frontend_trigger_engine`, `frontend_bkg_generator`,
  `frontend_ticket_distributor`) are instantiated exactly once
  regardless of `LANE_COUNT`.
- `frontend_trigger_engine` round-robin pointer is sized to
  `clog2(LANE_COUNT)`.
- Per-lane resource scaling is roughly `+395 ALM` and `+2 M10K` per
  lane; the front-end overhead is approximately `800 ALM` flat.

### Axis 2 — Byte-stream output

```
parameter bit BYTE_STREAM_ENABLE = 0   // legal values: 0, 1
```

- `0` (default) — `be_mutrig_frame_assembler` is `generate`-removed
  from the netlist; per-lane `aso_tx8b1k_*` sources drive K28.5 idle.
  Saves ~`1200 ALM` across 8 lanes vs the `1` build.
- `1` — frame assembler is synthesised; `aso_tx8b1k_*` sources drive
  the 8b/1k MuTRiG-format byte stream and can be wired to
  `mutrig_frame_deassembly` for back-compat parity tests.

The choice is build-time, not runtime. Software cannot toggle it via
CSR (the CSR has no `enable_byte_stream` bit). This is intentional —
the byte-stream cost should not be paid by users who do not need it.

### Gated and reported points

| Axis point | Status | Gated for signoff? |
|---|---|---|
| `LANE_COUNT=8, BYTE_STREAM_ENABLE=0` | primary (production) | <span class="tag good">YES</span> |
| `LANE_COUNT=8, BYTE_STREAM_ENABLE=1` | compatibility | <span class="tag good">YES</span> (parity tests only) |
| `LANE_COUNT=4, BYTE_STREAM_ENABLE in {0,1}` | informational | <span class="tag info">REPORTED</span> |
| `LANE_COUNT=2, BYTE_STREAM_ENABLE in {0,1}` | informational | <span class="tag info">REPORTED</span> |
| `LANE_COUNT=1, BYTE_STREAM_ENABLE in {0,1}` | informational | <span class="tag info">REPORTED</span> |

### DV implications

Cases that explicitly need `BYTE_STREAM_ENABLE=1` are flagged in the
`Stimulus` cell of the per-bucket case tables (search "byte-stream").
All other cases pass on either build. The deassembly-parity bucket
(`P081..P096` in `tb/DV_PROF.md`) is the primary user of the
compatibility build.

## Interfaces and contracts

- The IP top-level port list is **identical** across all build axis
  points. `aso_tx8b1k_*` ports always exist; they just drive idle K28.5
  when `BYTE_STREAM_ENABLE=0`.
- `LANE_COUNT < 8` reduces the port-array width on `aso_hit_type0_*`
  and `aso_tx8b1k_*` accordingly.

## Where to look in the code

- Top parameters: `rtl/emulator_mutrig.sv:9-22`
- Generate gate for `frame_assembler`: `rtl/emulator_mutrig.sv` (search
  `BYTE_STREAM_ENABLE`)
- Build axes spec: `doc/RTL_PLAN_central_trigger.md` §1.1
- Standalone Quartus QSF: `syn/quartus/emulator_mutrig_syn.qsf`

## Open questions / gotchas

- `LANE_COUNT` values other than {1, 2, 4, 8} are not part of the
  legal value set. Extra values will likely elaborate but are not on
  the closure matrix.
- The 26.2.x measured numbers (`SYN_REPORT.md`) currently cover only
  the `(8, 0)` point. The other gated point (`(8, 1)`) and the
  informational points are pending.
