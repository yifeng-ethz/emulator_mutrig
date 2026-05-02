# Architecture

## TL;DR

The IP has two layers separated by a single per-lane ticket bus. The
front-end decides *which lanes get a ticket and what's on it*; the
back-end decides *what hit-word format the ticket becomes*. Front-end is
one block independent of `LANE_COUNT`; back-end scales linearly per lane.

## Why this exists

The legacy emulator put per-lane launch decisions in 8 copies of one
module, all relying on identical PRNG seeds to "agree" on cluster
membership. That coupling was fragile and made it impossible to swap the
hit-word format (e.g. for MuPix) without rewriting the whole thing. The
FE/BE split in 26.2.x cleanly separates "decide" from "format".

## How it works

### The ticket bus contract

Each ticket carries `{ch_low, ch_high, ts_a, ts_b}` where `ts_a` and
`ts_b` are `TS_WIDTH`-bit timestamp anchors (15 bits for MuTRiG, mapped
to TCC and ECC respectively):

```
typedef struct packed {
    logic [4:0]                ch_low;
    logic [4:0]                ch_high;
    logic [TS_WIDTH-1:0]       ts_a;
    logic [TS_WIDTH-1:0]       ts_b;
} frontend_ticket_t;
```

A ticket targets exactly one lane via the `fe_ticket_valid[lane]` /
`fe_ticket_ready[lane]` handshake. There is **no inter-lane talking** on
the dispatch side.

### Front-end blocks

| Block | What it does |
|---|---|
| `frontend_csr` | AVMM slave; golden 7-word identity header + split mode CSRs |
| `frontend_run_ctl` | Decodes the 9-bit one-hot run-control; resyncs `coe_inject_pulse`; OR-merges with `FIRE.fire_inject_pulse` W1P |
| `frontend_trigger_engine` | SIGNAL launcher (Poisson / Periodic / FIX / RANDOM with mirror modes); round-robin per-lane dispatch |
| `frontend_bkg_generator` | BACKGROUND IID per-channel scan, folded by 256, single Bernoulli per cycle |
| `frontend_ticket_distributor` | Per-lane fanout of the offer ports to the lane FIFOs (signal wins on same-cycle contention) |

### Back-end blocks (MuTRiG, replicated `LANE_COUNT` times)

| Block | What it does |
|---|---|
| `be_mutrig_lane_emitter` | 8-deep ticket FIFO (MLAB) → walk `ch_low..ch_high` → pack 48-bit MuTRiG long word → push to L2; per-lane 64-bit `frame_count`/`hit_count` saturating |
| `be_mutrig_l2_fifo` | 256×48 M10K wrapper with almost-full |
| `be_mutrig_lane_type0_emit` | Repacks the 48-bit L2 word into the 45-bit `hit_type0` AvST contract; functional `ERROR_INJECT` OR'd into error[2:0] when `lane_error_target_mask` bit set; per-lane `endofrun` on TERMINATING→IDLE |
| `be_mutrig_frame_assembler` | 8b/1k MuTRiG framing for the optional byte-stream output; only synthesised when `BYTE_STREAM_ENABLE=1` |

### Cluster geometry

- `CLUSTER_GEOM_FIX`: independent side-A and side-B channel ranges. Each
  half of the CSR word holds `{low[6:0], high[13:7], enable[14]}`. Side
  A occupies `[15:0]`, side B occupies `[31:16]`. **FIX never
  auto-mirrors**; if the user wants a manual mirror they set both
  halves with the desired channel ranges explicitly.
- `CLUSTER_GEOM_RANDOM`: random center inside one SMB (128 channels per
  side); `mirror_mode` selects `LEFT_ONLY` / `RIGHT_ONLY` / `MIRRORED` /
  `MIRRORED_INV`; in `MIRRORED` the mirror is at `128 − local_ch`, in
  `MIRRORED_INV` the mirror is at the **same** local channel
  (`right_local_ch = left_local_ch`); in both, `mirror_offset` (signed
  `−128..+127`) shifts the mirror cluster center to model SciFi
  mechanical mis-alignment.

### Ticket carries the timestamp; back-end never re-samples LFSRs

The front-end samples `tcc_lfsr` and `ecc_lfsr` at the launch cycle
and packs them into every per-lane ticket. The back-end pops one
channel per cycle from a ticket and emits one hit per channel — all
hits from one ticket share that ticket's TCC and ECC. This is what
guarantees "all hits from one physical particle have the same
timestamp" without any per-lane LFSR re-sample.

### Fine timestamps fixed at zero (simple model)

For this emulator we **do not** model fine-time jitter. `T_Fine` and
`E_Fine` are tied to `5'd0` for every emitted hit. Rationale: the
simple model already matches the per-cluster TCC anchor exactly, and
per-channel fine randomness adds verification noise without exercising
the real decoder bug surface. The per-lane fine PRNG is removed from
`be_mutrig_lane_emitter` in the 26.2.x refresh.

### Coarse counter step rate (locked at 5)

The MuTRiG ASIC runs its TDC at 625 MHz; the emulator runs at 125 MHz
(5x ratio). Both PRBS-15 LFSRs (`u_tcc_lfsr`, `u_ecc_lfsr`) advance by
**exactly 5 steps per emulator cycle** (`STEP_COUNT = 5`) so the
downstream `mutrig_timestamp_processor` decode matches the real ASIC's
coarse counter without a phase remap.

### L2-pop link bottleneck

Even when the byte-stream output is disabled (`BYTE_STREAM_ENABLE=0`)
and downstream consumers see the type0 path directly, the back-end
**still** throttles the L2 pop rate to model the real MuTRiG link
bandwidth at the 125 MHz emulator boundary:

| Mode | Avg cycles per hit popped from L2 |
|---|---|
| `cfg_short_mode = 1` (short hit) | **3.5 cycles/hit** (alternating 3/4 cycles, ping-pong) |
| `cfg_short_mode = 0` (long hit) | **6 cycles/hit** |

The pacer lives in `be_mutrig_lane_type0_emit` and gates `l2_rd_en`.
Downstream IPs see the same offered-rate envelope they would see if
the byte stream were running.

### Round-robin lane push order

The trigger engine maintains a small rotating pointer across the
`LANE_COUNT` lanes. Every launch dispatches in RR order starting from
that pointer; primary and mirror sub-clusters share one RR pointer so
neither side gets fixed-priority access.

## Interfaces and contracts

- FE/BE: per-lane `frontend_ticket_t` (read-only by BE; FE never inspects
  back-end FIFO state)
- Run-control to FE: `frontend_run_ctl` outputs `run_generating`,
  `run_draining`, `emu_rst`, `frame_rst`, `inject_pulse`, `ctrl_state_q`
- CSR to FE blocks: one canonical config bus
  (`cfg_*` plus W1P fire bit) emitted by `frontend_csr`
- BE to outputs: per-lane `aso_hit_type0_*` (always) and per-lane
  `aso_tx8b1k_*` (only when `BYTE_STREAM_ENABLE=1`)

## Where to look in the code

- Ticket struct: `rtl/common/frontend_ticket_bus_pkg.sv`
- Engine RR + cluster decode:
  `rtl/frontend/frontend_trigger_engine.sv:107-298`
- BE word pack: `rtl/backend_mutrig/be_mutrig_lane_emitter.sv:84-105`
- Type0 SOP/EOP/endofrun: `rtl/backend_mutrig/be_mutrig_lane_type0_emit.sv:60-100`
- Architecture spec: `doc/RTL_PLAN_central_trigger.md` §2

## Open questions / gotchas

- The trigger engine does the cluster footprint compute and the RR shred
  in one cycle. That's the path that fails timing at 125 MHz today; a
  follow-up patch will pipeline the footprint compute.
- The ticket struct's `ts_a`/`ts_b` are interpreted by the back-end. The
  MuTRiG back-end maps them to TCC/ECC; a future MuPix back-end may map
  differently, including ignoring `ts_b` if MuPix doesn't need an energy
  timestamp.
