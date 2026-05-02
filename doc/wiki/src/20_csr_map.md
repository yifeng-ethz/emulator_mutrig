# Register Layout

## TL;DR

The IP exposes a 32-word software-facing window at a 6-bit AVMM address.
Words `0x00..0x06` are the common Mu3e identity-and-debug header (UID,
META mux, SCRATCH, LAST_RD/WR_*); words `0x07..0x15` are the IP-specific
control / status / fire / counter-mux block; words `0x18..0x1F` carry
the per-lane 64-bit `frame_count` and `hit_count` snapshots.

## Why this exists

Every Mu3e IP shares the same first 7 words so a host driver can
blind-scan and identify any IP at any address window without knowing the
catalog ahead of time. The IP-specific words then encode the
central-trigger refresh: split mode CSRs, cluster geometry knobs, fire
bits, and the per-lane counter readbacks.

## How it works

### Common header (words 0x00..0x06, all IPs)

| Addr | Name | Access | Purpose |
|---|---|---|---|
| `0x00` | `UID` | RO | 32-bit ASCII tag; default `0x454D5554` (`"EMUT"`) |
| `0x01` | `META` | RW/RO | Page mux: write 0/1/2/3 → read VERSION/DATE/GIT/INSTANCE_ID |
| `0x02` | `SCRATCH` | RW | General-purpose scratch / bus liveness ping |
| `0x03` | `LAST_RD_ADDR` | RO | Address of the most recent CSR read (excluding LAST_RD_* itself) |
| `0x04` | `LAST_RD_DATA` | RO | Data returned by the most recent CSR read |
| `0x05` | `LAST_WR_ADDR` | RO | Address of the most recent CSR write |
| `0x06` | `LAST_WR_DATA` | RO | Data accepted by the most recent CSR write |

### IP-specific block (split mode CSRs, words 0x07..0x0A)

The legacy single CTRL_MODE word is split into 4 per-purpose words:

| Addr | Name | Notable fields |
|---|---|---|
| `0x07` | `CENTRAL` | `[0]` `global_enable` |
| `0x08` | `SIGNAL` | `[0]` `hit_mode_sig` (INTERNAL/EXTERNAL); `[1]` `internal_sub_mode` (Poisson/Periodic); `[2]` `cluster_geom_mode` (FIX/RANDOM) |
| `0x09` | `BACKGROUND` | `[0]` `hit_mode_bkg` (OFF/ON) |
| `0x0A` | `MUTRIG_FORMAT` | `[0]` `short_mode`; `[1]` `gen_idle`; `[4:2]` `tx_mode`; `[5]` `enable_type0_stream` |

### Geometry, rates, seeds (words 0x0B..0x0F)

| Addr | Name | Notable fields |
|---|---|---|
| `0x0B` | `RATES` | `[15:0]` `hit_rate`; `[31:16]` `noise_rate` |
| `0x0C` | `CLUSTER_GEOM_FIX` | `[7:0]` `hit_channel_low`; `[15:8]` `hit_channel_high` |
| `0x0D` | `CLUSTER_GEOM_RANDOM` | `[7:0]` `cluster_size_random` (1..128); `[9:8]` `mirror_mode`; `[18:11]` signed `mirror_offset`; `[26:19]` `random_center_seed` |
| `0x0E` | `PRNG_SEED` | 32-bit master seed for engine + bkg + per-lane fine PRNG |
| `0x0F` | `TIMEBASE_SEED` | `[14:0]` `tcc_seed`; `[30:16]` `ecc_seed` (independent PRBS-15 reset values for configurable ECC-after-TCC delay) |

### Reserved / lane control / fire / status (words 0x10..0x15)

| Addr | Name | Notable fields |
|---|---|---|
| `0x10..0x11` | reserved | (Were `INJECT_CHANNEL_MASK` and `INJECT_LANE_MASK` in earlier drafts; masked-inject path was removed.) |
| `0x12` | `LANE_ENABLE` | `[7:0]` `lane_enable_mask`; `[11:8]` `asic_id_base` |
| `0x13` | `FIRE` | `[0]` `fire_inject_pulse` (W1P, OR'd with `coe_inject_pulse`) |
| `0x14` | `BANK_STATUS` | `[15:0]` `ticket_overflow_count`; `[23:16]` `engine_busy_high_water` |
| `0x15` | `ERROR_INJECT` | `[2:0]` `type0_error_inject_mask`; `[10:3]` `lane_error_target_mask` |

### Per-lane block (words 0x18..0x1F, indexed by `0x18 + 4*lane + N`)

For each lane `i` in `0..7`:

- `0x18 + 4*i + 0` — `LANE_FRAME_LO[i]` — 64-bit saturating frame counter, low word
- `0x18 + 4*i + 1` — `LANE_FRAME_HI[i]` — high word + sticky bits (W1C `fifo_full_sticky`, `ticket_overflow_sticky`)
- `0x18 + 4*i + 2` — `LANE_HIT_LO[i]` — 64-bit saturating hit counter, low word
- `0x18 + 4*i + 3` — `LANE_HIT_HI[i]` — hit counter high word

### Common header inheritance contract

Software can blind-scan via `UID` and `META`, then sanity-check the bus
via a `SCRATCH` write/read round-trip and read `LAST_*` to debug bus
issues. This pattern is shared with every other Mu3e IP and is enforced
by `~/.codex/skills/ip-packaging/scripts/lint_csr_header.py --profile golden`.

## Interfaces and contracts

- AVMM slave: 6-bit address, 32-bit data, `waitrequest=0` (1-cycle reads).
- All RW bits readback the last value written.
- W1P bits read back 0.
- Sticky bits are W1C: write 1 to clear.

## Where to look in the code

- CSR module: `rtl/frontend/frontend_csr.sv`
- CSR address constants: search `ADDR_*_CONST` in `frontend_csr.sv`
- Source of truth for field layout: `doc/RTL_PLAN_central_trigger.md` §3
- Linter: `~/.codex/skills/ip-packaging/scripts/lint_csr_header.py --profile golden`

## Open questions / gotchas

- `ERROR_INJECT` is functional but level-sensitive: while non-zero, every
  type0 beat from the targeted lanes carries the OR'd error bits. A
  future variant may strobe per-N-frames instead.
- `0x10` and `0x11` are intentionally reserved (not removed) so a future
  mask-based inject scheme can land without an address-map break.
