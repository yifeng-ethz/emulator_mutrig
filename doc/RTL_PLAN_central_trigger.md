# Emulator MuTRiG — RTL Plan (Central Trigger Engine Refresh)

**IP family:** `emulator_mutrig`
**Patch target release:** `26.2.x` (proposed)
**Active release this supersedes:** `26.1.9.0418`
**New top:** `rtl/emulator_mutrig.sv` (re-shaped as packaged 8-lane IP)
**Removed shape:** standalone `rtl/emulator_mutrig_bank8.sv` folds back into the packaged top
**Companion reports (to refresh):** [../tb/DV_PLAN.md](../tb/DV_PLAN.md), [../tb/DV_REPORT.md](../tb/DV_REPORT.md), [../syn/SYN_REPORT.md](../syn/SYN_REPORT.md), [SIGNOFF.md](SIGNOFF.md)

## 1. Patch Scope

This refresh restructures the IP around a clean **front-end / back-end
split**:

- The **front-end** is the hit-generation layer: SIGNAL auto-engine
  (Poisson / Periodic with cluster geometry, or external inject via port
  or CSR), BACKGROUND auto-engine (per-channel IID), shared CSR header
  and mode-control words, run-control decode, and the per-lane ticket
  dispatcher. The front-end is detector-agnostic and **does not scale
  with lane count** — it is one block that emits per-lane tickets on a
  shared ticket bus.
- The **back-end** is the per-lane formatter and serialiser: ticket FIFO,
  L2 hit FIFO, fine-time PRNG, MuTRiG hit-word packer,
  `frame_assembler` (8b/1k), `lane_type0_emit`, and the MuTRiG-specific
  PRBS-15 timestamp encoders. The back-end **scales linearly with lane
  count** and is detector-specific. This patch delivers the MuTRiG
  back-end; a future MuPix back-end can drop in by re-implementing the
  per-lane consumer of the same ticket bus.

The interface contract between FE and BE is the **per-lane ticket**
defined in §2.0. As long as a future back-end accepts that contract,
the front-end is fully reusable.

### 1.1 Build-time feature axes (synthesis closure)

This IP has exactly **two** elaboration-time feature axes. Synthesis
and DV closure must report results at every point on both axes.

| Axis | Parameter | Legal values | Default |
|------|-----------|--------------|---------|
| Lane count | `LANE_COUNT` | 1, 2, 4, 8 | 8 |
| Output path | `BYTE_STREAM_ENABLE` | 0 (type0 only) / 1 (type0 + 8b/1k) | 0 |

`BYTE_STREAM_ENABLE = 0` removes the `be_mutrig_frame_assembler`
instances from the netlist via `generate`-gating, saving ~`1200` ALM
across 8 lanes. `BYTE_STREAM_ENABLE = 1` keeps both outputs available;
the runtime CSR has no toggle for byte-stream because the choice is
fixed at build time.

For the 26.2.x signoff vehicle, the gated reference points are
`(LANE_COUNT=8, BYTE_STREAM_ENABLE=0)` (primary) and
`(LANE_COUNT=8, BYTE_STREAM_ENABLE=1)` (compatibility against the
deassembly path). 4-lane and 2-lane builds are reported but not
gated for this release. See §4 for the per-axis resource table.

On top of the layering and build axes, this patch also lands the
previously agreed behavioural changes:

1. **Per-lane datapath** — each of the 8 lanes owns its own ticket FIFO,
   hit-emit FSM, L2 FIFO, frame assembler, and AvST source. Drain latency is
   per-lane, matching the physical 8-lane MuTRiG readout.
2. **Central trigger engine** — one block computes physical hit clusters
   centrally and shreds them into per-lane tickets `{ch_low, ch_high,
   tcc_anchor, ecc_anchor}`. Cross-ASIC hits become two or more tickets
   automatically. Per-lane PRNG state survives only for fine-time jitter.
3. **Two orthogonal hit producers**, both feeding the same per-lane ticket
   bus through arbitration:
   - **Signal producer** (physical hit). Mode `hit_mode_sig` selects
     `INTERNAL` (engine self-launches via Poisson or Periodic) or
     `EXTERNAL` (engine launches only on conduit / CSR fire). Either way,
     the cluster shape is shared and is selected by `cluster_geom_mode`:
     - `FIX` — user-defined channel range `[hit_channel_low, hit_channel_high]`
       in the global `0..255` space. Cross-SMB allowed because the user is
       explicit about the channel set.
     - `RANDOM` — pseudo-physical particle hit. Engine picks a random center,
       generates a cluster of `cluster_size_random` channels inside one SMB,
       and **automatically mirrors** the cluster to the other SMB at
       `128 − ch` (Mu3e SciFi double-sided readout). Cluster never crosses
       the SMB boundary; mirroring always happens.
   - **Background producer** (per-channel noise). Mode `hit_mode_bkg` is
     `ON` / `OFF` and sits on top of the signal producer. When `ON`, an
     IID per-channel Bernoulli stream fires each channel at approximately
     `noise_rate` per cycle. Implemented as a single rolling-scan position
     across 256 channels with one folded-Bernoulli decision per cycle and
     a per-channel PRNG seed derivation, so cost stays linear in lanes.
4. **Configurable ECC anchor delay** — TCC and ECC PRBS-15 LFSRs run from
   independent CSR-loadable seeds. The user computes the seed offset
   offline; the emulator stores no coarse-code → time mapping.
5. **`cfg_burst_size` widens to 9 bits** (still used by `FIX` low/high spans
   internally; bumped because per-lane ticket fields cover up to 32-channel
   spans and the engine ranges are 0..255).
6. **Direct `hit_type0` emit path** — each lane exposes a second AvST source
   that mirrors the byte-stream output of `mutrig_frame_deassembly`. The
   emulator builds the 45-bit `hit_type0` word and SOP/EOP from its own
   L2 FIFO drain and frame-interval timer, so a downstream hit processor
   (timestamp processor, packet scheduler, ring-buffer CAM) can be fed
   directly **without instantiating the frame deassembly IP**. The 8b/1k
   byte stream stays available for back-compat and for true A/B against
   the deassembly path; selection is per-CSR-bit.

## 2. Architecture

### 2.0 Front-end / back-end contract

The front-end emits one ticket per affected lane. Tickets are
fire-and-forget: the front-end pushes into the per-lane back-end
ticket FIFO, the back-end drains in its own time. There is **no
inter-lane talking** on the dispatch path — the back-end of lane `i`
does not see lane `j`'s tickets.

Ticket struct (`frontend_ticket_bus_pkg.sv`, new file):

```
typedef struct packed {
    logic [4:0]  ch_low;       // local channel low (0..31)
    logic [4:0]  ch_high;      // local channel high (0..31), >= ch_low
    logic [TS_WIDTH-1:0] ts_a; // primary timestamp anchor (TCC for MuTRiG)
    logic [TS_WIDTH-1:0] ts_b; // secondary timestamp anchor (ECC for MuTRiG)
} frontend_ticket_t;
```

**Ticket carries the timestamp.** The front-end samples `tcc_lfsr` and
`ecc_lfsr` at the cycle the launch decision fires, and packs them into
`ts_a` and `ts_b` of every per-lane ticket the launch produces. The
back-end never re-samples the LFSRs when packing a hit word — every hit
produced from one ticket therefore shares one TCC/ECC pair. This is the
contract the front-end and back-end share to model the
"all hits from the same physical particle have the same timestamp"
property of a real MuTRiG cluster. The back-end pops one channel per
cycle from a ticket and emits one hit per channel, all with the same
ticket-carried `ts_a`/`ts_b`.

Per-lane signal set on the ticket bus:

```
output frontend_ticket_t  fe_ticket_data   [LANE_COUNT];
output logic              fe_ticket_valid  [LANE_COUNT];
input  logic              fe_ticket_ready  [LANE_COUNT];  // back-pressure
```

Notes on the contract:

- `TS_WIDTH` is parameterised at the package level. For the MuTRiG
  back-end it equals `15` (PRBS-15 coarse counter). For a future
  MuPix back-end it can widen to a binary timestamp without changing
  the front-end. The front-end produces the timestamps using its own
  PRNG/counter (detector-specific encoding lives in the back-end
  re-mapper if needed).
- The two anchors `ts_a` / `ts_b` are interpreted by the back-end. In
  the MuTRiG back-end they map to TCC and ECC; in a future MuPix
  back-end they may map differently or `ts_b` may be unused.
- Channel range is local-to-lane. The front-end has already done the
  global-to-lane shred for cluster splits (FIX or RANDOM with mirror).
- `fe_ticket_ready` is the only inter-layer back-pressure path. When a
  lane's back-end ticket FIFO is full, that lane's `ready` deasserts;
  the front-end stalls **only** the dispatch to that lane and continues
  serving other lanes. The front-end never drops a ticket once accepted
  on the bus; it may drop a *launch* upstream if multiple lanes are
  back-pressured at the same time (counted in
  `BANK_STATUS.ticket_overflow_count`).

### 2.1 Top-level block diagram

```
+============================== FRONT-END (one block, lane-count parameterised) =============================+
|                                                                                                            |
|   AVMM CSR ----> frontend_csr ---+---> frontend_trigger_engine --+                                         |
|                                  |       (SIGNAL: Poisson /      |                                         |
|   ctrl AvST ---> frontend_run_ctl|        Periodic / FIX /       |                                         |
|                                  |        RANDOM / inject merge) |                                         |
|   conduit ----> inject_sync -----+                               |                                         |
|   inject_pulse                   |                               +---> per-lane ticket distributor         |
|                                  +---> frontend_bkg_generator ---+        (fire-and-forget, ready/valid)   |
|                                          (BACKGROUND IID)        |                                         |
|                                                                  |                                         |
+======== ticket bus: frontend_ticket_t × LANE_COUNT ==============v=========================================+
                                                                   |
                                                                   v
+============================== BACK-END (per-lane, MuTRiG-specific) ========================================+
|   shared: PRBS-15 LFSRs (TCC seed, ECC seed) — bank-wide MuTRiG-encoded timestamps                         |
|                                                                                                            |
|   for each lane L in 0..LANE_COUNT-1:                                                                      |
|       be_mutrig_lane_emitter[L]      <-- ticket bus[L]                                                     |
|       be_mutrig_l2_fifo[L]           (256 x 48 M10K, MuTRiG long-hit word)                                 |
|       be_mutrig_lane_type0_emit[L]   --> AvST hit_type0[L]   (to hit processor, primary path)              |
|       be_mutrig_frame_assembler[L]   --> AvST tx8b1k[L]      (8b/1k MuTRiG framing, optional)              |
|                                                                                                            |
+============================================================================================================+
```

### 2.2 SMB / channel geometry assumed

```
side A (upper SMB)            side B (lower SMB)
asic 0..3, local ch 0..31     asic 4..7, local ch 0..31
global ch 0..127              global ch 128..255

mirror map (Mu3e SciFi double-sided readout):
  side-A local ch c   <->   side-B local ch (127 - c)
  global ch g         <->   global ch (255 - g)   for g in 0..127
```

The engine treats the lane → SMB mapping as fixed: lanes `0..3` are SMB A,
lanes `4..7` are SMB B. Random clusters never straddle the SMB boundary;
mirroring across the boundary is automatic and produces a second cluster
on the opposite SMB.

### 2.3 Front-end SIGNAL engine (`frontend_trigger_engine.sv`, new file)

**Layer:** front-end. Single instance regardless of `LANE_COUNT`.

Two trigger sources feed the engine, OR-merged before the launch
arbitrator. Both are gated only by `CENTRAL.global_enable`; neither
depends on `SIGNAL.hit_mode_sig`.

1. **External signal injection** — single combined pulse equal to:
   ```
   inject_pulse = edge_of(resync(coe_inject_pulse)) | W1P(FIRE.fire_inject_pulse)
   ```
   Software writes to `FIRE.fire_inject_pulse` and an external rising edge
   on `coe_inject_pulse` produce identical effects. There is exactly one
   external inject port on the IP. When `inject_pulse` fires, the engine
   launches a cluster regardless of `hit_mode_sig` — this is the
   "host-driven signal injection" path that works in both INTERNAL and
   EXTERNAL modes.

2. **Internal signal generator** — only active when
   `SIGNAL.hit_mode_sig == INTERNAL`:
   - `internal_sub_mode == POISSON`: `prng[15:0] < hit_rate`
   - `internal_sub_mode == PERIODIC`: 16-bit phase accumulator overflows
     against `hit_rate` (folded by 1, single launch per overflow)
   When `EXTERNAL`, the internal generator is silent and only
   `inject_pulse` can fire signal hits.

If both sources fire on the same cycle, `inject_pulse` wins; the
internal launch is dropped (the PRNG re-evaluates next cycle). The
masked-inject walk and its second conduit port are removed in this
patch — there is now exactly one external injection input, one CSR
fire bit, and one cluster-launch path.

When a physical-hit launch fires, the engine builds the cluster footprint
based on `cluster_geom_mode`:

**`FIX`**: just use `hit_channel_low` and `hit_channel_high` directly
(global `0..255`, must satisfy `low <= high`, span up to 256 channels,
cross-SMB allowed). One footprint, one set of per-lane tickets.

**`RANDOM`** — controlled by `cluster_size_random`, `mirror_mode`, and
`mirror_offset` (all in `CLUSTER_GEOM_RANDOM`, addr `0x0D`):
- `mirror_mode` selects how the primary side is chosen and whether a
  mirror cluster is generated:
  - `LEFT_ONLY` — primary cluster always lands on side A (lanes 0..3,
    global ch 0..127). No mirror cluster.
  - `RIGHT_ONLY` — primary cluster always lands on side B (lanes 4..7,
    global ch 128..255). No mirror cluster.
  - `MIRRORED` — primary side is picked per launch by
    `side_pick = prng[N+1]`; a second mirror cluster is generated on the
    other side. `mirror_offset` is applied to the mirror cluster center.
- `center_local = prng[N..N-7] mod 128` — random local center inside the
  selected primary SMB.
- `size = cluster_size_random` (CSR field, `1..128`).
- Primary cluster (local): `low_local = clamp(center_local − size/2, 0,
  128 − size)`; `high_local = low_local + size − 1`.
- Mirror cluster (only when `mirror_mode = MIRRORED`):
  - `mirror_center_local = clamp((128 − center_local) + mirror_offset,
    size/2, 128 − size/2)` — `mirror_offset` is signed
    `−128..+127`, default `0` (exact mirror). The clamp keeps the
    mirror cluster fully inside its SMB so it never crosses the SMB
    boundary regardless of offset value.
  - `low_mirror_local = mirror_center_local − size/2`;
    `high_mirror_local = low_mirror_local + size − 1`.
  - The `mirror_offset` knob models mechanical mis-alignment between
    the two SiPM readout sides on the SciFi detector — physical fibres
    do not always line up exactly with their geometric mirror channel.
- Convert each cluster to global channels by adding the SMB base
  (`0` for A, `128` for B).
- Engine emits per-lane tickets for the primary cluster (and the mirror
  cluster when `MIRRORED`). Same `tcc_anchor` / `ecc_anchor` for both —
  it is one physical particle.

**Lane push order: round-robin.** The engine maintains a small
rotating pointer across the `LANE_COUNT` lanes. For every cluster
launch, the lanes-touched set is dispatched in round-robin order
starting from the rotating pointer (advance by 1 after each launch).
For RANDOM mode, both primary and mirror sub-clusters drain through
the same RR pointer so neither side gets fixed-priority access. This
removes the "low-index lane gets every cluster first" bias and lets
back-end stalls distribute evenly across lanes under saturation.

Per-lane ticket build (same for FIX and RANDOM, same for primary and mirror):
```
for L in rr_order(lanes_touched, rr_ptr):
    ch_low_local  = max(0, footprint_low_global  - L*32)
    ch_high_local = min(31, footprint_high_global - L*32)
    push_ticket(L, ch_low_local, ch_high_local, tcc_lfsr, ecc_lfsr)
```

The engine takes one cycle per affected-lane push, so the worst-case
RANDOM launch (size 128, spans 5 lanes per SMB plus 5 mirrored lanes =
up to 10 ticket pushes) occupies the engine for up to 10 cycles. During
that window `engine_busy` is high and new launches are deferred. Internal
launches drop on stall (PRNG re-evaluates next cycle); external launches
queue once in a 2-deep latch and overflow into `ticket_overflow_count`.

### 2.4 Front-end BACKGROUND generator (`frontend_bkg_generator.sv`, new file)

**Layer:** front-end. Single instance regardless of `LANE_COUNT`.
SIGNAL and BACKGROUND can fire on the same cycle and target different
lanes — the per-lane ticket distributor handles both producers without
stalling either's lane unless that specific lane's ticket FIFO is full.

Implementation strategy: **rolling channel scan**, one Bernoulli decision
per cycle, fold rate by 256.

```
scan_pos (0..255)        increments every cycle
prng_bkg                 16-bit LFSR per scan_pos derived from prng_seed
threshold                folded_noise_rate = saturate(noise_rate * 256)
fire                     prng_bkg < noise_rate (per-channel rate semantics)
on fire, push 1-channel ticket(L = scan_pos[7:5], ch = scan_pos[4:0],
                                 tcc = tcc_lfsr, ecc = ecc_lfsr)
```

Active only when `hit_mode_bkg == ON`. The 256 per-channel PRNG streams
are produced by **one** 16-bit LFSR plus an XOR with `scan_pos` so the
decision behaves like 256 independent streams without paying for 256
flops. This approximation is acceptable per the architect's "approximately"
note; if true independence is needed, a 256-deep block-RAM PRNG state
table can be added later (one M10K).

Bkg ticket arbitrates against signal ticket per lane: signal wins on tie,
bkg waits one cycle. Across lanes, signal and bkg can dispense in
parallel because they target different lane FIFOs. Both producers stall
when the target lane ticket FIFO is full.

### 2.5 Per-lane back-end emitter (`be_mutrig_lane_emitter.sv`, derived from `hit_generator.sv`)

**Layer:** back-end (MuTRiG). Replicated `LANE_COUNT` times. The MuTRiG
hit-word format (5b channel + 15b TCC + 5b T_Fine + 15b ECC + 5b E_Fine
+ flags = 48b long word) is hard-coded here; a future MuPix back-end
replaces this module with a MuPix-shaped equivalent that consumes the
same `frontend_ticket_t` from the bus.

Each lane keeps:

- Ticket FIFO (`8` entries × `40` bits): `{ch_low[4:0], ch_high[4:0], tcc[14:0], ecc[14:0]}`.
- Active ticket registers + 5-bit `current_ch` walker.
- L2 FIFO (`256 × 48`, M10K-backed).
- 1-word `pending` skid slot (kept for write/read M10K port hygiene).

The lane no longer carries a fine-time PRNG. **`T_Fine` and `E_Fine`
are tied to `5'd0`** in this simple model — see the
"Fine timestamps and LFSR step rate" subsection below.

Per-cycle behaviour:

1. If active-ticket valid, build one L2 hit word for `current_ch`:
   ```
   t_fine = 5'd0
   e_fine = 5'd0
   pack_hit_long(channel=current_ch, tcc=ticket.tcc, ecc=ticket.ecc,
                 t_fine=5'd0, e_fine=5'd0, e_flag=1'b1, ...)
   ```
   Stall when L2 cannot accept; do not advance `current_ch`.
2. When `current_ch == ch_high`, mark ticket consumed; pop next from
   ticket FIFO.
3. Drain interface to local `frame_assembler` is unchanged from the
   compact bank8 lane.

#### Fine timestamps and LFSR step rate (locked 26.2.x decisions)

- **Coarse counter step rate.** The MuTRiG ASIC runs its TDC at
  `625 MHz`; the emulator runs at `125 MHz` (a 5x ratio). Both PRBS-15
  LFSRs (`u_tcc_lfsr`, `u_ecc_lfsr`) therefore advance by **exactly 5
  steps per emulator cycle** — the `STEP_COUNT` parameter of
  `prbs15_lfsr` must stay at `MUTRIG_COARSE_STEPS_PER_CYCLE = 5`. This
  is what makes the downstream `mutrig_timestamp_processor` decode
  consistent with the real ASIC's coarse counter.
- **Fine timestamps fixed at zero.** For this emulator we **do not**
  model fine-time jitter at all — `T_Fine` and `E_Fine` are tied to
  `5'd0` for every emitted hit. Rationale: the simple model already
  matches the per-cluster TCC anchor exactly, and per-channel fine
  randomness adds verification noise without exercising the real
  decoder bug surface. If a future patch needs fine modelling, it can
  be reintroduced as a per-lane PRNG with a CSR enable.
- **Ticket carries the timestamp.** The back-end never re-samples the
  LFSRs when packing a hit — every hit produced from one ticket shares
  the ticket's `ts_a`/`ts_b` (== TCC/ECC at launch cycle), per the
  §2.0 ticket contract.

The lane no longer runs Poisson/Burst/Periodic decision logic and no
scan position counter — those move to `trigger_engine` and
`bkg_generator`. The masked-inject FSM is deleted outright in this
patch (no central replacement); the only injection path is the single
`inject_pulse` cluster launch handled in §2.3.

### 2.6 Per-lane back-end direct hit_type0 emit (`be_mutrig_lane_type0_emit.sv`, new file)

**Layer:** back-end (MuTRiG). Replicated `LANE_COUNT` times. The 45-bit
`hit_type0` word and SOP/EOP semantics match the MuTRiG
`mutrig_frame_deassembly` contract exactly. A MuPix back-end would
replace this with the MuPix hit-word emit path; the FE never knows.

Each lane gets a parallel AvST source that mirrors the
`mutrig_frame_deassembly` output contract exactly, so any downstream
consumer of `aso_hit_type0_*` can be driven by the emulator without the
deassembly IP in the path. The port shape per lane matches
`frame_rcv_ip.vhd:86-99`:

```
aso_hit_type0_channel       : out std_logic_vector(3 downto 0);  -- asic_id
aso_hit_type0_startofpacket : out std_logic;
aso_hit_type0_endofpacket   : out std_logic;
aso_hit_type0_endofrun      : out std_logic;
aso_hit_type0_error         : out std_logic_vector(2 downto 0);
aso_hit_type0_data          : out std_logic_vector(44 downto 0);
aso_hit_type0_valid         : out std_logic;
```

Word layout, per `frame_rcv_ip.vhd:580-585`:

```
[44:41] asic       (4-bit ASIC ID, redundant with channel port)
[40:36] channel    (5-bit local channel from L2 word [47:43])
[35:21] T_CC       (15-bit TCC from L2 word [41:27])
[20:16] T_Fine     (5-bit T fine from L2 word [26:22])
[15:1]  E_CC       (15-bit ECC from L2 word [20:6])
[0]     E_Flag     (from L2 word [0])
```

Note: E_Fine is dropped, matching the deassembly contract.

**Tap point:** the emit block sits on the L2 FIFO drain side, not after
the frame assembler. It samples each word as it leaves the FIFO and
repacks it into the 45-bit type0 layout.

**L2-pop rate model (link bottleneck).** Even though the type0 path
bypasses the 8b/1k frame assembler, it MUST still throttle the L2 FIFO
pop rate so the downstream observer sees the **same per-hit cadence as
the real MuTRiG link**. The real link cadence is set by the MuTRiG
output bandwidth at the 125 MHz emulator boundary:

| Mode | Avg cycles per hit popped from L2 | Implementation |
|------|-----------------------------------|----------------|
| `cfg_short_mode = 1` (short-hit, 28-bit + framing) | **3.5 cycles/hit** | alternate 3 / 4 cycles per hit (ping-pong) |
| `cfg_short_mode = 0` (long-hit, 48-bit + framing)  | **6 cycles/hit**   | one hit every 6 cycles |

The pacer lives in `be_mutrig_lane_type0_emit` and gates `l2_rd_en` so
the emit asserts at most once per `(3,4,3,4,...)`-cycle stride in
short mode and once per 6-cycle stride in long mode. SOP/EOP and
`endofrun` are unaffected. This makes the type0 path a faithful link
model regardless of whether the byte-stream side is synthesised — the
downstream timestamp processor / packet scheduler / ring buffer CAM see
the same offered-rate envelope as if the byte stream were running.

**Packet boundaries:**
- The same frame-interval timer that opens a frame for `frame_assembler`
  also drives SOP/EOP for the type0 path. SOP is asserted on the first
  hit dequeued in the frame; EOP is asserted on the last hit dequeued
  before the next frame boundary.
- Empty frames produce **no** type0 beats (no SOP-only or EOP-only
  pulses). Same as the deassembly behaviour where a frame containing zero
  hits emits zero type0 beats.

**`endofrun`:** asserted for one cycle on the run-control transition
out of TERMINATING into IDLE, after the lane's L2 FIFO has drained.
Same semantics as `frame_rcv_ip.vhd:268`. Implemented per-lane so that
each AvST source is independently complete.

**`error`:** the emulator does not generate parity, CRC, or upstream
8b1k errors organically. Bits are tied to `3'b000` by default. A future
CSR-driven error injection knob (per-bit, per-lane) is captured in
section 8 as an open item.

**CSR control:** `CTRL_MODE.enable_byte_stream` selects whether the
8b/1k byte stream is also synthesised. When clear, the
`frame_assembler` instances and the AvST tx8b1k sources are still
present in the netlist but driven inert (idle K28.5, valid low). Both
paths can be active at once.

### 2.7 Front-end run-control, inject sync, idle

**Layer:** front-end. Single instance.

`run_ctl` lives in the wrapper and broadcasts `run_generating`,
`run_draining`, `emu_rst`, `frame_rst` to all lanes and the engine.
The single external inject port `coe_inject_pulse` gets a 2-FF resync
into the emulator clock, OR-merged with the W1P `FIRE.fire_inject_pulse`
bit, then edge-detected once. The `coe_inject_masked_pulse` conduit and
the masked-inject walker are removed in this patch.

### 2.8 Layer ownership summary

| Block | Layer | Replication | Detector-specific? |
|---|---|---|---|
| `frontend_csr` (golden header + mode words + cluster geom + rates + seeds + FIRE + bank counters) | FE | 1 | No |
| `frontend_run_ctl` (run-control decode, inject sync, frame-rst broadcast) | FE | 1 | No |
| `frontend_trigger_engine` (SIGNAL: Poisson, Periodic, FIX, RANDOM, mirror, inject merge) | FE | 1 | No |
| `frontend_bkg_generator` (BACKGROUND IID per-channel scan) | FE | 1 | No |
| `frontend_ticket_distributor` (per-lane fanout, fire-and-forget, ready/valid) | FE | 1 (with `LANE_COUNT` outputs) | No |
| `frontend_ticket_bus_pkg` (ticket struct typedef = FE/BE contract) | FE pkg | — | No (contract surface) |
| `be_mutrig_pkg` (MuTRiG word-format constants, helpers) | BE pkg | — | **Yes (MuTRiG)** |
| Shared PRBS-15 LFSRs (TCC seed, ECC seed) | BE | 1 (bank-shared) | **Yes (MuTRiG coarse-counter encoding)** |
| `be_mutrig_lane_emitter` (ticket consumer + fine PRNG + 48b MuTRiG word packer + L2 push) | BE | `LANE_COUNT` | **Yes** |
| `be_mutrig_l2_fifo` (256×48 M10K wrapper) | BE | `LANE_COUNT` | Yes (width is MuTRiG-specific) |
| `be_mutrig_frame_assembler` (8b/1k MuTRiG framing) | BE | `LANE_COUNT` | **Yes** |
| `be_mutrig_lane_type0_emit` (MuTRiG `hit_type0` AvST source) | BE | `LANE_COUNT` | **Yes** |

Rule of thumb: **anything that handles a ticket's payload format is
back-end; anything that decides *which lane gets a ticket* is
front-end.** When the back-end is swapped for MuPix, every "Yes" row
above is rewritten and every "No" row is reused as-is.

Per-lane idle output (`K28.5`) when `run_draining = 0` or that lane's
`lane_enable_mask` bit is clear, exactly as the current single-lane top.

## 3. Proposed CSR Map

6-bit AVMM address (64 registers). 32-bit data width.

The address widens to 6 bits to fit the per-lane block: each of the 8 lanes
exposes a 64-bit `frame_count` and a 64-bit `hit_count` (each takes 2 CSR
words for hi/lo halves), plus a status word with sticky bits and an
extra word for future per-lane fields, packed at `0x20 + lane_index*4`.

CSR ownership by layer:

- **FE-owned** (always present, detector-agnostic): `UID`, `META`,
  `SCRATCH`, `LAST_RD_*`, `LAST_WR_*`, `CENTRAL`, `SIGNAL`,
  `BACKGROUND`, `RATES`, `CLUSTER_GEOM_FIX`, `CLUSTER_GEOM_RANDOM`,
  `PRNG_SEED`, `LANE_ENABLE`, `FIRE`, `BANK_STATUS`.
- **BE-owned (MuTRiG)**: `MUTRIG_FORMAT`, `TIMEBASE_SEED`,
  `ERROR_INJECT`, the per-lane `LANE_FRAME_*` and `LANE_HIT_*` blocks
  at `0x20..0x3F`.

When swapping to a MuPix back-end, only the BE-owned register slots
change name/semantics. The FE-owned slots stay byte-compatible so
host software written against the FE keeps working.

The first two words are the **common Mu3e CSR identity header** — every
software-facing Mu3e IP exposes the same UID + META layout so the host
can blind-scan the catalog before knowing what IP it is reading. The
canonical layout follows `ring-buffer_cam/script/ring_buffer_cam_hw.tcl:90-101`.

| Addr | Name | RW | Bits | Field | Description |
|---|---|---|---|---|---|
| 0x00 | `UID` | RO | [31:0] | `ip_uid` | Software-visible IP identifier. Default ASCII `EMUT` (`0x454D5554`), integration-time overridable via the `IP_UID` HDL parameter. |
| 0x01 | `META` | RW/RO | [31:0] | `meta_mux` | Read-multiplexed metadata word. Write `0`=VERSION, `1`=DATE, `2`=GIT, `3`=INSTANCE_ID; subsequent reads return the selected word. VERSION packs as MAJOR[31:24], MINOR[23:16], PATCH[15:12], BUILD[11:0]. |
| 0x02 | `SCRATCH` | RW | [31:0] | `scratch` | General-purpose 32-bit software scratch register. Reset value `32'h0000_0000`. Used by the host as a CSR-bus liveness ping (write/read mismatch == bus broken). Mirrors `slow-control_hub`'s `SCRATCH` semantics, hoisted into the common header so every Mu3e IP exposes it at the same fixed offset. |
| 0x03 | `LAST_RD_ADDR` | RO | [4:0] | `last_rd_addr` | Word address of the most recent CSR read this slave answered (excluding reads of `LAST_RD_*` themselves so the snapshot is not self-mutating). Cleared on `i_rst`. Mirrors `slow-control_hub`'s `LAST_RD_ADDR` (`sc_hub_hw.tcl:95`). |
| | | | [31:5] | reserved | Reads 0. |
| 0x04 | `LAST_RD_DATA` | RO | [31:0] | `last_rd_data` | Data returned by the most recent CSR read (excluding reads of `LAST_RD_*`). Cleared on `i_rst`. Mirrors `slow-control_hub`'s `LAST_RD_DATA` (`sc_hub_hw.tcl:96`). |
| 0x05 | `LAST_WR_ADDR` | RO | [4:0] | `last_wr_addr` | Word address of the most recent CSR write this slave accepted. Cleared on `i_rst`. Mirrors `slow-control_hub`'s `LAST_WR_ADDR` (`sc_hub_hw.tcl:97`). |
| | | | [31:5] | reserved | Reads 0. |
| 0x06 | `LAST_WR_DATA` | RO | [31:0] | `last_wr_data` | Data accepted by the most recent CSR write. Cleared on `i_rst`. Mirrors `slow-control_hub`'s `LAST_WR_DATA` (`sc_hub_hw.tcl:98`). |
| 0x07 | `CENTRAL` | RW | [0] | `global_enable` | Master enable. Gates all lanes, the engine, and the bkg generator. |
| | | | [31:1] | reserved | Reads 0. |
| 0x08 | `SIGNAL` | RW | [0] | `hit_mode_sig` | `0` INTERNAL (engine self-launches) / `1` EXTERNAL (engine waits for conduit or CSR fire). |
| | | | [1] | `internal_sub_mode` | When `hit_mode_sig=INTERNAL`: `0` Poisson / `1` Periodic. Ignored otherwise. |
| | | | [2] | `cluster_geom_mode` | `0` FIX (user channel low/high) / `1` RANDOM (random center, mirror-mode controlled). |
| | | | [31:3] | reserved | Reads 0. |
| 0x09 | `BACKGROUND` | RW | [0] | `hit_mode_bkg` | `0` OFF / `1` ON. Per-channel IID noise on top of signal. |
| | | | [31:1] | reserved | Reads 0. |
| 0x0A | `MUTRIG_FORMAT` | RW | [0] | `short_mode` | `1` short-hit / `0` long-hit. Broadcast to all lanes. |
| | | | [1] | `gen_idle` | `frame_assembler` emits idle gap when no events. Only meaningful when the `BYTE_STREAM_ENABLE` build parameter is `1`. |
| | | | [4:2] | `tx_mode` | MuTRiG slow-control TX mode passthrough. |
| | | | [5] | `enable_type0_stream` | `1` (default) drives the per-lane `aso_hit_type0_*` AvST sources. `0` holds them inert. (Runtime gate — type0 is always synthesised.) |
| | | | [31:6] | reserved | Reads 0. (`enable_byte_stream` is no longer a CSR bit; the byte-stream output is selected at elaboration time via the `BYTE_STREAM_ENABLE` HDL parameter — see §4.) |
| 0x0B | `RATES` | RW | [15:0] | `hit_rate` | 16-bit threshold for INTERNAL signal launch (Poisson compare or Periodic phase increment). |
| | | | [31:16] | `noise_rate` | 16-bit per-channel rate target for BKG. Internally folded by 256 to drive a one-Bernoulli-per-cycle scan. |
| 0x0C | `CLUSTER_GEOM_FIX` | RW | [6:0] | `left_low` | Side A (left, lanes 0..3) low channel `0..127`. Used when `cluster_geom_mode=FIX`. |
| | | | [13:7] | `left_high` | Side A high channel `0..127`, must satisfy `left_high >= left_low`. |
| | | | [14] | `left_enable` | When `1`, emit the side-A range. When `0`, side A produces no FIX-mode hits. |
| | | | [15] | reserved | Reads 0. |
| | | | [22:16] | `right_low` | Side B (right, lanes 4..7) low channel `0..127`. Same encoding offset by 16. |
| | | | [29:23] | `right_high` | Side B high channel `0..127`, must satisfy `right_high >= right_low`. |
| | | | [30] | `right_enable` | When `1`, emit the side-B range. When `0`, side B produces no FIX-mode hits. |
| | | | [31] | reserved | Reads 0. |
| | | | -- | -- | **FIX cluster never auto-mirrors.** Both sides are independent and explicit. To emit a "manual mirror", set both halves with the desired channel ranges. To emit a one-side-only cluster, leave the other half disabled. |
| 0x0D | `CLUSTER_GEOM_RANDOM` | RW | [7:0] | `cluster_size_random` | Cluster size `1..128`. Engine picks random center inside the side selected by `mirror_mode`. |
| | | | [9:8] | `mirror_mode` | `00` LEFT_ONLY (cluster only on side A, lanes 0..3), `01` RIGHT_ONLY (cluster only on side B, lanes 4..7), `10` MIRRORED (cluster on the random-picked side AND its mirror on the other side, with `mirror_offset` applied to the mirror center), `11` MIRRORED_INV (cluster on the random-picked side AND its non-inverted copy on the other side at the same local channel — i.e. `right_local_ch = left_local_ch`, NOT `128 − left_local_ch`; `mirror_offset` still applies). Default `10` (MIRRORED). |
| | | | [10] | reserved | Reads 0. |
| | | | [18:11] | `mirror_offset` | Signed 8-bit, range `-128..+127`. Only takes effect when `mirror_mode=MIRRORED`. The mirror cluster's local center is `(128 − primary_local_center) + mirror_offset`, clamped to `[0, 128 − cluster_size_random]` so the mirror cluster never crosses the SMB boundary. Default `0` (exact mirror). Used to model mechanical mis-alignment between the two SiPM readout sides on the SciFi detector. |
| | | | [26:19] | `random_center_seed` | 8 bits added into the engine's center-pick PRNG so multiple instances can desync. |
| | | | [31:27] | reserved | Reads 0. |
| 0x0E | `PRNG_SEED` | RW | [31:0] | `prng_seed` | Master PRNG seed. Engine launch PRNG, RANDOM center PRNG, BKG PRNG, and per-lane fine PRNG are all derived from it via fixed XOR offsets. |
| 0x0F | `TIMEBASE_SEED` | RW | [14:0] | `tcc_seed` | PRBS-15 reset value for TCC. Default `15'h0001`. |
| | | | [15] | reserved | Reads 0. |
| | | | [30:16] | `ecc_seed` | PRBS-15 reset value for ECC. Default `15'h0001` (= ECC ≡ TCC). User computes seed offline to encode the desired ECC-after-TCC delay. |
| | | | [31] | reserved | Reads 0. |
| 0x10 | reserved | RO | [31:0] | reserved | Reads 0. (Was `INJECT_CHANNEL_MASK` in earlier drafts; the masked-inject walker is removed in this patch.) |
| 0x11 | reserved | RO | [31:0] | reserved | Reads 0. (Was `INJECT_LANE_MASK` in earlier drafts; removed with the masked-inject walker.) |
| 0x12 | `LANE_ENABLE` | RW | [7:0] | `lane_enable_mask` | Per-lane enable. Disabled lanes idle K28.5 and do not open new frames. Default `8'hFF`. |
| | | | [11:8] | `asic_id_base` | Downstream `aso_tx8b1k_channel` and `aso_hit_type0_channel` for lane `i` is `asic_id_base + i` (clamped per existing `clamp_asic_id`). |
| | | | [31:12] | reserved | Reads 0. |
| 0x13 | `FIRE` | RW1P | [0] | `fire_inject_pulse` | Write `1` to generate one internal cluster-inject pulse. ORed with the resynced `coe_inject_pulse` conduit input — both edge-detect into the same single-cycle pulse feeding the trigger engine. Fires regardless of `SIGNAL.hit_mode_sig` value (works in both INTERNAL and EXTERNAL); the only gate is `CENTRAL.global_enable`. Reads `0`. |
| | | | [31:1] | reserved | Reads 0. |
| 0x14 | `BANK_STATUS` | RO | [15:0] | `ticket_overflow_count` | Saturating count of trigger events dropped because a target lane ticket FIFO was full. Cleared on `emu_rst`. |
| | | | [23:16] | `engine_busy_high_water` | Max consecutive engine-busy cycles since reset (saturating). |
| | | | [31:24] | reserved | Reads 0. |
| 0x15 | `ERROR_INJECT` | RW | [2:0] | `type0_error_inject_mask` | Per-bit OR into `aso_hit_type0_error[2:0]` for the targeted lanes. Bit 0 = parity error, bit 1 = CRC error, bit 2 = upstream rx8b1k error. Asserted on every type0 beat while non-zero AND the lane is in `lane_error_target_mask`. |
| | | | [10:3] | `lane_error_target_mask` | 8-bit per-lane mask. Each set bit routes the `type0_error_inject_mask` into that lane's type0 output. Default `8'h00` (no lanes targeted). |
| | | | [31:11] | reserved | Reads 0. |
| 0x16..0x1F | reserved | RO | [31:0] | reserved | Reads 0. Reserved for future CSR growth (e.g. per-lane rate overrides, additional bank counters). |
| 0x20 + lane*4 + 0 | `LANE_FRAME_LO[lane]` | RO | [31:0] | `frame_count[31:0]` | Per-lane 64-bit saturating frame counter, low word. One block per lane (lane 0 at `0x20`, lane 7 at `0x3C`). Counts opened frames since `emu_rst`. |
| 0x20 + lane*4 + 1 | `LANE_FRAME_HI[lane]` | RO/W1C | [27:0] | `frame_count[59:32]` | High 28 bits of the per-lane frame counter (full 60-bit usable range; saturates at `2^60 − 1`, ample for any conceivable run). |
| | | | [28] | `fifo_full_sticky` | W1C. Set when this lane's L2 FIFO ever reached full since reset. |
| | | | [29] | `ticket_overflow_sticky` | W1C. Set when this lane's ticket FIFO ever stalled the engine. |
| | | | [31:30] | reserved | Reads 0. |
| 0x20 + lane*4 + 2 | `LANE_HIT_LO[lane]` | RO | [31:0] | `hit_count[31:0]` | Per-lane 64-bit saturating hit counter, low word. Counts hit words committed to the L2 FIFO since `emu_rst`. (Renamed from prior 10-bit `event_count`.) |
| 0x20 + lane*4 + 3 | `LANE_HIT_HI[lane]` | RO | [31:0] | `hit_count[63:32]` | High 32 bits of the per-lane 64-bit hit counter. |

Notes on the map:

- The address widens from 4 to 6 bits (`CSR_ADDR_WIDTH = 6`) to fit the
  full common header (7 words at `0x00..0x06`), the split mode-control
  block (`CENTRAL`, `SIGNAL`, `BACKGROUND`, `MUTRIG_FORMAT` at
  `0x07..0x0A`), the IP-specific data/status block (`0x0B..0x15`), and
  the 8-lane × 4-word counter block (`0x20..0x3F`). Reserved window
  `0x16..0x1F` covers near-term CSR growth.
- The **common Mu3e CSR header** at `0x00..0x06` mirrors the layout used
  by `slow-control_hub` (`sc_hub_hw.tcl:76-98`):
  - `UID` (`0x00`) — 32-bit ASCII tag, integration-time overridable.
  - `META` (`0x01`) — write `0`/`1`/`2`/`3` to select VERSION / DATE /
    GIT / INSTANCE_ID; read returns the selected payload.
  - `SCRATCH` (`0x02`) — general-purpose RW, used as a CSR-bus liveness
    ping before exercising IP-specific words.
  - `LAST_RD_ADDR` / `LAST_RD_DATA` (`0x03` / `0x04`) — last accepted
    read transaction. Updated on every CSR read except reads of the
    `LAST_RD_*` words themselves so the snapshot is not self-mutating.
  - `LAST_WR_ADDR` / `LAST_WR_DATA` (`0x05` / `0x06`) — last accepted
    write transaction. Updated on every CSR write.
  - The `IP_UID`, `VERSION_*`, `BUILD`, `VERSION_DATE`, `VERSION_GIT`,
    and `INSTANCE_ID` HDL parameters are required on the RTL top so
    the `_hw.tcl` packaging surface matches every other Mu3e IP.
  - Software can blind-scan via `UID` and the `META` mux without
    knowing what IP is at the address window, then sanity-check the
    bus via `SCRATCH` and `LAST_*`.
- Sticky bits in `LANE_STATUS[*]` are W1C so the host can clear between
  runs without a global reset.
- W1P `FIRE` bits read back zero so a read-modify-write cannot
  re-trigger.
- `ERROR_INJECT` (`0x15`) is **functional** in this patch as a demo of
  the future error-injection capability. When `lane_error_target_mask`
  bit `i` is set, the targeted lane `i`'s `aso_hit_type0_error[2:0]`
  bus is OR'd with `type0_error_inject_mask`. Default mask is `8'h00`
  (no lanes targeted), so the feature is opt-in per lane. The CSR slot
  and SVD entry are stable so a future patch can extend the scope
  (e.g. per-frame strobing) without a register-map break.
- The earlier `cfg_cluster_lane_index` and `cfg_cluster_center_global`
  fields disappear: the IP is the bank itself, and signal geometry is
  fully specified by either `CLUSTER_GEOM_FIX` (explicit channel range)
  or `CLUSTER_GEOM_RANDOM` (size + auto-mirror). Per-lane CSR overrides
  are out of scope for this patch and reserve `0x18..0x1F` for that
  future surface.

## 4. Resource Estimate

Reference baseline (current bank8 fitter result, from
[`../syn/SYN_REPORT.md`](../syn/SYN_REPORT.md)):

| item | current bank8 |
|---|---|
| top-level ALMs | `3856` |
| registers | `3777` |
| block memory bits | `98,304` |
| RAM blocks (M10K) | `16` |
| DSP blocks | `0` |

Per-lane M10K usage today is `2` blocks (256 × 48 = 12,288 bits in a
quad-port M10K config) → `8 × 2 = 16` total. This patch keeps the L2
FIFO geometry, so M10K count is unchanged.

### 4.1 Estimated post-patch totals

**Front-end (does not scale with `LANE_COUNT`):**

| block | qty | per-instance ALM | total ALM | per-instance M10K | total M10K |
|---|---|---|---|---|---|
| `frontend_csr` (golden header, mode words, sticky/W1C, W1P FIRE, 64-bit lane counters mux) | 1 | ~260 | ~260 | 0 | 0 |
| `frontend_run_ctl` + inject sync + 8-lane wrapper | 1 | ~150 | ~150 | 0 | 0 |
| `frontend_trigger_engine` (PRNG, center pick, mirror geometry, ticket distributor, single inject merge) | 1 | ~280 | ~280 | 0 | 0 |
| `frontend_bkg_generator` (scan + folded Bernoulli + per-lane fanout) | 1 | ~110 | ~110 | 0 | 0 |
| **front-end subtotal** | | | **~800** | | **0** |

**Back-end MuTRiG (scales linearly with `LANE_COUNT = 8`):**

| block | qty | per-instance ALM | total ALM | per-instance M10K | total M10K |
|---|---|---|---|---|---|
| `be_mutrig_lane_emitter` (ticket FIFO 8×40b MLAB + walker + fine PRNG + 48-bit MuTRiG packer + pending slot + 64-bit lane counters) | 8 | ~180 | ~1440 | 0 (FIFO is MLAB) | 0 |
| `be_mutrig_frame_assembler` | 8 | ~150 | ~1200 | 0 | 0 |
| `be_mutrig_lane_type0_emit` (45-bit repack, SOP/EOP per frame, endofrun pulse) | 8 | ~30 | ~240 | 0 | 0 |
| `be_mutrig_l2_fifo` (256×48 M10K) + control wrapper | 8 | ~30 | ~240 | 2 | 16 |
| Shared PRBS-15 LFSRs (TCC seed, ECC seed) | 1 (bank) | ~50 | ~50 | 0 | 0 |
| **back-end subtotal (MuTRiG, 8 lanes)** | | | **~3170** | | **16** |

**Estimated total: ~3970 ALM, 16 M10K.**

Front-end overhead is ~`800` ALM regardless of `LANE_COUNT`; back-end
scales at ~`395` ALM and `2` M10K per lane. Shrinking to 4 lanes drops
the back-end to ~`1585` ALM and `8` M10K (total ~`2385` ALM); growing
to 16 lanes pushes back-end to ~`6320` ALM and `32` M10K (total
~`7120` ALM, would need additional area work).

Net delta vs current bank8: about `−220 ALMs`, `0 M10K`. Drivers:

- Per-lane removes Poisson/Burst/Periodic decision logic
  (`hit_generator.sv:579-715`), removes the per-lane masked-inject FSM
  (which is deleted entirely in this patch — no central replacement
  either), and removes the per-lane scan-position counter and 16-deep
  ticket FIFO in flops. Estimate `−110 ALM/lane × 8 = −880`.
- Per-lane ticket FIFO shrinks from `16 × ~50b in flops` to `8 × 40b in MLAB`.
  Estimate `−40 ALM/lane × 8 = −320`. Adds 8 MLABs (LUTRAM), not M10K.
- New central trigger engine costs about `+330 ALM` (heavier than the
  prior central proposal because it owns the SMB-mirror geometry and
  the random center pick, plus the 2-deep external-launch latch).
- New BKG generator costs about `+110 ALM` (one PRNG, one scan counter,
  one threshold compare, per-lane arbiter taps).
- New CSR (extra mode bits, FIX/RANDOM split, sticky/W1C, W1P FIRE,
  type0/byte enables) costs about `+180 ALM` vs the prior bank8
  broadcast.
- New per-lane `lane_type0_emit` (45-bit repack + SOP/EOP latch + per-lane
  endofrun pulse) costs about `+30 ALM/lane × 8 = +240 ALM`. The cost is
  modest because the L2 word is already built; this block is largely
  bit-shuffle and a small SOP/EOP FSM.
- Wider `burst_size` / ticket-range fields contribute `~+40 ALM`.

### 4.2 Risk on the estimate

- MLAB inference for the lane ticket FIFO depends on width. `8 × 40` should
  infer one MLAB per lane comfortably; if Quartus falls back to flops, lane
  ALM rises by ~30/lane → +240 ALM. Result still inside the 4000 cap.
- BKG generator's "single LFSR XOR scan_pos" approximation may not pass the
  architect's noise-rate uniformity bar. Upgrading to 256-deep block-RAM
  PRNG state costs `+1 M10K` and `~+80 ALM`. Within budget.
- Engine ticket-dispatch may need a small bypass shift register if Quartus
  cannot meet `137.5 MHz` on the lane-broadcast push path. Worst case
  `+60 ALM`.
- ECC LFSR seed register and the parameterised reset value on `prbs15_lfsr`
  add `~10` flops each; negligible.

Nominal post-patch total is `~3970 ALM / 16 M10K`, sitting right at
the `4000 ALM` cap. With worst-case adjustments stacked
(`+380 ALM, +1 M10K`), the total is `~4350 ALM / 17 M10K`, over the
cap. Mitigations available without losing functionality:
- `generate`-gate `be_mutrig_frame_assembler` on
  `MUTRIG_FORMAT.enable_byte_stream`. Removes the 8 frame assemblers
  from the netlist when only the type0 path is needed (`−1200 ALM`),
  comfortably inside cap. Cost: byte-stream becomes a build-time
  selection, not a runtime selection.
- Shrink lane ticket FIFO depth from 8 to 4 entries (`−40 ALM × 8 = −320 ALM`).
  Cost: shallower buffering on a stalled lane during back-pressure spikes.
- Move per-lane 64-bit `frame_count` / `hit_count` accumulators into a
  shared 16-deep × 128-bit MLAB indexed by lane (`−~120 ALM`, +1 MLAB).
  Cost: 1-cycle read latency on lane-counter CSR reads.

Pick mitigations based on which back-end paths the integration
actually needs.

### 4.3 M10K and DSP

- M10K: `16` (unchanged). Worst case `17` with the optional independent
  per-channel BKG PRNG state.
- MLAB (LUTRAM): `+8` net (one ticket FIFO per lane). Off the M10K budget.
- DSP: `0` (unchanged).

## 5. Functional Notes For This Patch

1. The `cluster_lane_index` per-instance generic disappears from the public
   IP. Existing testbenches that instantiate 8 single-lane copies must move
   to the new 8-lane top.
2. **Signal vs background** are now formally orthogonal CSR knobs.
   `hit_mode_sig` selects how the signal producer fires; `hit_mode_bkg`
   independently turns IID per-channel noise on or off. Both can be active
   simultaneously and both use the same TCC/ECC LFSR samples at the
   commit cycle.
3. **FIX cluster** is exact: `hit_channel_low/high` define the global
   channel set, no clamping past the user's intent, cross-SMB allowed.
4. **RANDOM cluster** models the SciFi double-sided readout. With
   `mirror_mode = MIRRORED` (default), one physical particle fires
   `cluster_size_random` channels at a random center inside one SMB and
   the same number of channels at the mirrored locations
   (`128 − local_ch + mirror_offset`) in the other SMB. With
   `mirror_mode = LEFT_ONLY` or `RIGHT_ONLY`, only the named-side
   cluster is generated and no mirror is emitted. Cluster never crosses
   the SMB boundary regardless of `mirror_offset`.
5. **256-channel same-TCC inject** is delivered via `CLUSTER_GEOM_FIX`
   with `hit_channel_low=0`, `hit_channel_high=255` plus a fire on
   `FIRE.fire_inject_pulse` (or the conduit). One ticket per affected
   lane, all sharing the latched TCC/ECC anchor.
6. **ECC anchor delay** is realised entirely by user-chosen seeds; the
   emulator stores no LFSR step → ns mapping.
7. Ticket overflow is a real, observable failure mode now that the engine
   is central. `BANK_STATUS.ticket_overflow_count` plus per-lane sticky
   bits give the host a way to diagnose stress. Internal launches drop on
   stall (PRNG re-evaluates next cycle); external `inject_pulse` launches
   use a 2-deep latch and only count overflow if that latch is full.
8. **Direct hit_type0 path** lets a bench wire the emulator straight into
   any consumer of `mutrig_frame_deassembly`'s `aso_hit_type0_*` source —
   timestamp processor, packet scheduler, ring-buffer CAM, etc. — with
   no deassembly IP in the loop. Each lane is its own AvST source with
   its own SOP/EOP and `endofrun`. The 8b/1k byte stream stays optional
   for true A/B against the deassembly path. E_Fine is dropped on the
   type0 path per the deassembly contract (`frame_rcv_ip.vhd:580-585`).
   Error bits tie to `3'b000` in this patch; CSR-driven error injection
   is an open item.

## 6. Migration & Compatibility

- The single-lane packaged shape goes away. Any Platform Designer system
  that previously instantiated 8 copies of `emulator_mutrig` must move to
  the new 8-lane top. Update `emulator_mutrig_hw.tcl` accordingly.
- The conduit interface shrinks to a single port: `coe_inject_pulse`.
  The earlier `coe_inject_masked_pulse` port and the masked-inject
  walker are removed. The remaining inject port OR-merges with the new
  W1P `FIRE.fire_inject_pulse` bit; both sources fire signal injection
  regardless of `SIGNAL.hit_mode_sig`, gated only by
  `CENTRAL.global_enable`.
- The 9-bit `aso_tx8b1k_data` plus `aso_tx8b1k_channel` shape is unchanged
  per lane; the IP just exposes 8 of them. The 8b/1k path is **off** by
  default in this patch (`enable_byte_stream=0`); set the bit if a test
  needs the byte-stream output.
- The IP exposes 8 new `aso_hit_type0_*` AvST sources matching the
  `mutrig_frame_deassembly` contract. Existing systems that consume
  hit_type0 from the deassembly IP can connect directly to the
  emulator's per-lane source instead.
- AVMM CSR address widens to 6 bits to fit the golden header, the
  split mode-control words, and the per-lane 64-bit counter block.
- `cfg_cluster_*` fields and `cfg_burst_center` no longer exist as a CSR
  surface; their function is absorbed into `CLUSTER_GEOM_FIX` and
  `CLUSTER_GEOM_RANDOM`.

### 6.1 Folder layout (post-reorg)

The reorg per the `rtl-file-structure-organization` skill puts the
front-end / back-end split on disk:

```
emulator_mutrig/
├── README.md
├── doc/
├── model/
├── rtl/
│   ├── common/                       # cross-build packages and helpers
│   │   ├── frontend_ticket_bus_pkg.sv  # FE/BE ticket struct (the contract)
│   │   ├── prbs15_lfsr.sv              # parameterised by reset value
│   │   └── crc16_8.sv
│   ├── frontend/                     # detector-agnostic, never replicated
│   │   ├── frontend_csr.sv
│   │   ├── frontend_run_ctl.sv
│   │   ├── frontend_trigger_engine.sv
│   │   ├── frontend_bkg_generator.sv
│   │   └── frontend_ticket_distributor.sv
│   ├── backend_mutrig/               # MuTRiG-specific, replicated per lane
│   │   ├── be_mutrig_pkg.sv
│   │   ├── be_mutrig_lane_emitter.sv
│   │   ├── be_mutrig_l2_fifo.sv
│   │   ├── be_mutrig_lane_type0_emit.sv
│   │   └── be_mutrig_frame_assembler.sv
│   ├── backend_mupix/                # placeholder, future patch
│   │   └── README.md                   # describes the swap contract
│   └── emulator_mutrig.sv            # top, instantiates frontend + 8 × backend_mutrig
├── script/
│   └── emulator_mutrig_hw.tcl
├── syn/
└── tb/
```

The single-lane top stays as the file `emulator_mutrig.sv` for legacy
visibility but its body is now an 8-lane bank assembled from the
frontend and backend folders.

## 7. Verification Outline (to be detailed in `tb/DV_PLAN.md` update)

- Directed FIX: low/high spans of (1, 32, 33, 128, 129, 256). Verify per-lane
  ticket payload matches a golden split computed in the testbench.
- Directed RANDOM: pin the engine center PRNG, sweep `cluster_size_random`
  in (1, 4, 16, 32, 64, 128) crossed with `mirror_mode` in
  {LEFT_ONLY, RIGHT_ONLY, MIRRORED} and `mirror_offset` in
  {-32, -1, 0, +1, +32}. Verify:
  - LEFT_ONLY emits only side-A tickets, no side-B tickets.
  - RIGHT_ONLY emits only side-B tickets, no side-A tickets.
  - MIRRORED with offset 0 emits exact mirror at `128 − local`.
  - MIRRORED with non-zero offset emits the mirror at
    `128 − local + offset` and clamps so the mirror cluster stays
    inside its SMB.
  - All sub-clusters share TCC/ECC anchors; no cluster crosses the SMB
    boundary regardless of offset.
- Mode matrix: every combination of `hit_mode_sig × internal_sub_mode ×
  cluster_geom_mode × hit_mode_bkg`. Sanity counts per lane.
- BKG uniformity: with signal disabled and `noise_rate` set to several
  values, count per-channel hits over a long run; check the per-channel
  count distribution is within tolerance of the configured rate target.
- Stress: sustained 100% offered load with `cluster_geom_mode=RANDOM`,
  size 128, BKG ON. Watch `ticket_overflow_count` and per-lane
  `fifo_full_sticky`.
- Raw A/B parity: re-run `tb/mutrig_true_ab/sweep_true_ab.py` against one
  lane of the new top with `lane_enable_mask=8'h01` and the BKG off.
- ECC seed delay: directed test loads `tcc_seed=0x0001` and
  `ecc_seed = prbs15_step_n(0x0001, N*5)` for several `N`, then checks
  decoded ECC time lags decoded TCC time by exactly `N * 8 ns` at the
  125 MHz boundary.
- Mirror mapping at offset 0: directed RANDOM at center = 0, 63, 127 with
  size = 1 and size = 16, `mirror_offset = 0`. Verify the mirror channel
  set is exactly `128 − local`.
- Inject ORing: write `FIRE.fire_inject_pulse=1` and pulse
  `coe_inject_pulse` on the same cycle and on adjacent cycles; verify
  exactly one cluster launch per CSR-or-conduit edge, no doublets.
- Inject independence from `hit_mode_sig`: with `hit_mode_sig=EXTERNAL`
  the internal Poisson/Periodic generator must be silent and the only
  hits must come from `inject_pulse`; with `hit_mode_sig=INTERNAL` an
  inject pulse must still produce a cluster on top of the internal hits.
- Type0 vs deassembly parity: with `enable_byte_stream=1` and
  `enable_type0_stream=1` simultaneously, run the byte-stream output
  through `mutrig_frame_deassembly` and compare the resulting
  `aso_hit_type0_*` beats against the emulator's direct type0 source
  beat-for-beat. Channel, data[44:0], SOP/EOP, and `endofrun` must
  match exactly when the deassembly path is configured for a single
  asic. Latency on the type0 path will lead the deassembly path by
  the byte-serialiser depth; align via timestamp on T_CC, not cycle.
- Type0 SOP/EOP under bursty drain: directed test with one fully-
  populated frame followed by an empty frame followed by a partially
  populated frame; verify exactly one `(SOP, ..., EOP)` packet per
  non-empty frame and zero beats during the empty frame.
- Type0 endofrun: drive run-control IDLE → RUNNING → TERMINATING →
  IDLE with non-zero L2 occupancy at TERMINATING entry; verify each
  per-lane source emits exactly one `endofrun` pulse after the lane's
  last hit drains, regardless of byte-stream state.

## 8. Open Items (most resolved 2026-05-02)

Resolved:

- **CSR address widening** — DONE. `CSR_ADDR_WIDTH` widened to 6 bits
  to fit golden header + split mode words + per-lane 64-bit counters.
- **BKG PRNG approximation** — KEPT. Single 16-bit LFSR XOR'd with
  `scan_pos` is good enough; no per-channel BRAM PRNG state.
- **FIX cluster mirroring** — NO. Mirroring is strictly a RANDOM-mode
  behaviour; FIX uses the explicit user channel range only.
- **Engine push order** — Round-robin (RR) across lanes for both
  primary and mirror sub-clusters in RANDOM mode. No fixed priority.
  Implemented via a small rotating pointer in `frontend_trigger_engine`.
- **Poisson + Periodic** — Mutually exclusive via `internal_sub_mode`
  bit. Selecting one silences the other.
- **type0 error injection** — IMPLEMENTED as a demo via `ERROR_INJECT`
  (CSR `0x15`). Per-lane mask + 3-bit error word OR'd into the type0
  error bus. Default mask `8'h00` keeps it opt-in.
- **`frame_assembler` gating** — DONE. `BYTE_STREAM_ENABLE`
  elaboration-time parameter `generate`-gates the frame assemblers.
  Listed as an axis in §1.1.

Still open:

- Decide whether the RR pointer should advance once per launch or
  once per per-lane-push (sub-cluster level). Current plan: once per
  launch (pointer rotates between launches, not within a launch).
  Re-evaluate after stress runs in DV PROF bucket.
- Decide whether `ERROR_INJECT` should strobe per N frames or stay
  level-sensitive. Current plan: level-sensitive.

## 9. Future MuPix Back-end Swap

The front-end / back-end split is designed so a future MuPix variant
of this IP reuses the entire front-end (SIGNAL engine, BACKGROUND
engine, common header CSR, mode words, run-control, inject merge,
ticket distributor) and only re-implements the back-end. The contract
the new back-end must honour:

1. **Ticket struct.** Consume `frontend_ticket_t` from
   `frontend_ticket_bus_pkg.sv` per lane, with `ready/valid` handshake.
   The MuPix back-end may interpret `ts_a` / `ts_b` as a single binary
   timestamp anchor (e.g. concat into a wider counter) and ignore one
   of the two anchors if MuPix-style hits do not need a separate
   energy timestamp.
2. **Local channel range.** Honour `ch_low..ch_high` as the local hit
   set for the lane. The front-end has already done the global → lane
   shred; the back-end never sees global channel indices.
3. **Per-lane back-pressure.** Drive `fe_ticket_ready[lane]` low when
   the lane's internal queue is full. The front-end will stall just
   that lane and continue serving others.
4. **Run-control.** Consume `run_generating`, `run_draining`, `emu_rst`,
   `frame_rst` from the front-end. Frame boundary semantics may differ
   per detector — that is purely back-end business.
5. **CSR slot ownership.** The MuPix back-end may populate
   `MUTRIG_FORMAT` / `TIMEBASE_SEED` / `ERROR_INJECT` slots
   (renamed to `MUPIX_FORMAT` / `MUPIX_TIMEBASE` / `MUPIX_ERROR_INJECT`)
   with detector-appropriate fields. Slot addresses stay fixed
   (`0x0A`, `0x0F`, `0x15`) so the FE ↔ BE CSR routing is unchanged.

What the MuPix back-end specifically replaces:

- Hit-word format (MuTRiG 48b long → MuPix hit word)
- Per-lane fine-time semantics (MuTRiG 5b @ 250 ps → MuPix TDC code)
- Coarse-counter encoding (MuTRiG PRBS-15 → MuPix binary counter)
- Output AvST contracts (`hit_type0`, `tx8b1k` → MuPix equivalents)
- Per-lane L2 FIFO width (48b → MuPix word width)

What the MuPix back-end **inherits from the FE without change**:
the entire SIGNAL/BACKGROUND/RANDOM/FIX/MIRROR cluster geometry, the
inject ORing semantics, the common CSR header and bus-debug words,
the run-control decode, and the ticket distributor with its
fire-and-forget per-lane fan-out.

The folder layout in §6.1 anticipates the swap by reserving
`rtl/backend_mupix/` as a placeholder. The MuPix variant will be a
sibling top (e.g. `emulator_mupix.sv`) that instantiates the same
front-end with `LANE_COUNT` set per the MuPix system and the MuPix
back-end in place of `backend_mutrig`.
