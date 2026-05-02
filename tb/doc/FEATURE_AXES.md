# Feature Axes — emulator_mutrig 26.2.x DV scope

This document is the authoritative feature list for the standalone DV
gate. It names every elaboration-time and runtime feature surface,
marks each as `in-scope` or `waived` for the current DV cycle, and
gives the rationale.

The DV closure dashboard at `tb/DV_REPORT.md` only claims evidence for
**in-scope** feature points. Any feature marked `waived` or
`unimplemented` here MUST NOT be counted toward sign-off coverage.

## 1. Elaboration-time feature axes

| Axis | Point | Status | Notes |
|---|---|---|---|
| `LANE_COUNT` | `8` | **in-scope (gated)** | Production lane count; this is the only `LANE_COUNT` value covered by the regression. |
| `LANE_COUNT` | `1, 2, 4` | informational | Compiled-only sanity points; not exercised by the case set, not gated. |
| `BYTE_STREAM_ENABLE` | `0` (type0-only) | **in-scope (gated)** | Primary signoff path; the regression and coverage merge run with this point. |
| `BYTE_STREAM_ENABLE` | `1` (type0 + 8b/1k) | **waived for this DV cycle** | The 8b/1k frame-assembler back-end exists in the netlist but is `generate`-gated off when `BYTE_STREAM_ENABLE=0`. We waive its per-line coverage in this DV cycle because (a) the type0 path is the production output for the central-trigger refresh, (b) re-instrumenting and re-merging a second build would double the coverage CI time, and (c) the byte-stream path is exercised at the integration level via the `mutrig_frame_deassembly` parity test in `tb_int/`. **Status: unimplemented in this DV cycle. Tracked as a follow-up after `tb_int/` parity is wired up.** |

## 2. Runtime feature surface (CSR-controlled, all in-scope)

The following CSR-driven feature axes are all in-scope and exercised
by the regression at HEAD:

| Feature | CSR | Coverage |
|---|---|---|
| Common identity header | `UID`/`META`/`SCRATCH`/`LAST_RD/WR_*` (`0x00..0x06`) | exact-readback BASIC bucket (B001-B016) |
| Run-control mode | `CENTRAL.global_enable` (`0x07`) | BASIC B017-B032 |
| SIGNAL hit-mode-sig | `SIGNAL.hit_mode_sig` INTERNAL/EXTERNAL (`0x08[0]`) | BASIC B033-B080 |
| SIGNAL internal sub-mode | `SIGNAL.internal_sub_mode` Poisson/Periodic (`0x08[1]`) | BASIC B033-B064 |
| Cluster geometry mode | `SIGNAL.cluster_geom_mode` FIX/RANDOM (`0x08[2]`) | BASIC B081-B112 |
| BACKGROUND on/off | `BACKGROUND.hit_mode_bkg` (`0x09[0]`) | BASIC B113-B128 |
| MuTRiG format short/long | `MUTRIG_FORMAT.short_mode` (`0x0A[0]`) | EDGE E081-E096 |
| MuTRiG format gen_idle | `MUTRIG_FORMAT.gen_idle` (`0x0A[1]`) | EDGE E081-E096 |
| MuTRiG format tx_mode | `MUTRIG_FORMAT.tx_mode` (`0x0A[4:2]`) | informational; passthrough only |
| Type0 stream enable | `MUTRIG_FORMAT.enable_type0_stream` (`0x0A[5]`) | always asserted in current cases |
| Hit rate | `RATES.hit_rate[15:0]` (`0x0B`) | BASIC B033-B048 (5 rate values) |
| Noise rate | `RATES.noise_rate[31:16]` (`0x0B`) | BASIC B113-B128 (3 rate values) |
| FIX cluster left | `CLUSTER_GEOM_FIX[15:0]` (`0x0C`) | BASIC B081-B084 plus EDGE E001-E016 |
| FIX cluster right | `CLUSTER_GEOM_FIX[31:16]` (`0x0C`) | BASIC B083-B084 |
| RANDOM cluster size | `CLUSTER_GEOM_RANDOM.cluster_size_random` (`0x0D[7:0]`) | EDGE E017-E032 |
| RANDOM mirror_mode | `CLUSTER_GEOM_RANDOM.mirror_mode` (`0x0D[9:8]`) | BASIC B097-B112 (LEFT/RIGHT/MIRRORED) |
| RANDOM mirror_offset | `CLUSTER_GEOM_RANDOM.mirror_offset` signed (`0x0D[18:11]`) | EDGE E033-E048, EXTRA EX009-EX016 |
| Master PRNG seed | `PRNG_SEED` (`0x0E`) | BASIC B039-B040 reproducibility |
| TCC seed | `TIMEBASE_SEED.tcc_seed[14:0]` (`0x0F`) | EDGE E065-E080 |
| ECC seed | `TIMEBASE_SEED.ecc_seed[30:16]` (`0x0F`) | EDGE E065-E080 |
| Lane enable mask | `LANE_ENABLE.lane_enable_mask[7:0]` (`0x12`) | EDGE E049-E064 |
| ASIC ID base | `LANE_ENABLE.asic_id_base[11:8]` (`0x12`) | informational |
| Inject FIRE W1P | `FIRE.fire_inject_pulse` (`0x13`) | BASIC B065 |
| Bank status counters | `BANK_STATUS` (`0x14`) | informational; readback only |
| Error inject mask | `ERROR_INJECT.type0_error_inject_mask[2:0]` (`0x15`) | EXTRA EX001-EX008 |
| Error inject lane mask | `ERROR_INJECT.lane_error_target_mask[7:0]` (`0x15`) | EXTRA EX001-EX008 |

## 3. Counter coverage policy (locked 2026-05-02)

The 32-bit and 64-bit saturating counters in the design (per-lane
`frame_count`, per-lane `hit_count`, `bank_ticket_overflow_count`,
`engine_busy_high_water`) need a small number of bits in their **upper
half** to toggle to demonstrate the wide-counter path is alive. The
locked policy:

- **64-bit per-lane `frame_count` and `hit_count`**: require at least
  one bit in the **upper 32 bits** (`[63:32]`) to toggle. The TB
  preloads these counters to a value just below `2^32` via the
  `force` mechanism in `central_basic_long` so a short follow-on run
  is enough to flip the upper half. Without preload, exercising the
  full 64-bit width would require ~`2^32` hits which is impractical
  in simulation.
- **32-bit `bank_ticket_overflow_count` and friends**: require at
  least one bit in the **upper 16 bits** (`[31:16]`) to toggle.
  Preloaded similarly.
- The TB regression at HEAD does **not** count un-preloaded toggles
  on the upper bits as missed coverage; the toggle-coverage report
  is filtered against the "upper bit toggled at least once" criterion
  documented here.

## 4. PRBS-15 LFSR coverage policy

The shared TCC and ECC PRBS-15 LFSRs (`u_tcc_lfsr`, `u_ecc_lfsr`)
have a `2^15 − 1 = 32767` state period. At the locked step rate of
5 steps per emulator cycle, the LFSR returns to its starting state
every `32767 / 5 ≈ 6553` cycles. The TB `central_basic_long` target
runs at least one `>= 32768` cycle window with RUNNING + cfg_global_enable
to guarantee every LFSR state is observed at least once, lifting
toggle coverage on `tcc_lfsr[14:0]` and `ecc_lfsr[14:0]` to 100%.

## 5. Sign-off implications

- DV closure for this cycle is claimed against the in-scope axes only.
- The waived `BYTE_STREAM_ENABLE=1` axis must show as
  `unimplemented` in `tb/DV_REPORT.md` Health and explicitly named
  in the Non-Claims block.
- Future patches that re-enable the waived axis must add a parallel
  Quartus / Questa coverage build and merge its UCDB into a
  `BYTE_STREAM_ENABLE=1` UCDB, then a final `vcover merge` joins both
  axes for the cross-axis coverage row.
