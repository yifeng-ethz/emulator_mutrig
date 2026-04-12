# DV Cross Coverage — emulator_mutrig

**Purpose:** functional cross-coverage contract for Phase 0 signoff  
**Scope notes:** this file defines what the future directed and UVM regressions must prove across the current single-lane baseline and the intended shared 8-lane merged-datapath implementation.

## 1. Core Coverpoints

### 1.1 Mode / Format

| Coverpoint | Bins |
|---|---|
| `cp_hit_mode` | `poisson`, `burst`, `noise`, `mixed` |
| `cp_tx_mode` | `long`, `prbs_1`, `prbs_sat`, `short`, `reserved` |
| `cp_payload_kind` | `empty`, `single`, `multi_small`, `multi_large`, `max_payload` |
| `cp_frame_kind` | `long_frame`, `short_frame`, `debug_frame`, `idle_only` |

### 1.2 Timing

| Coverpoint | Bins |
|---|---|
| `cp_delay_cfg` | `min`, `low`, `mid`, `high`, `max` |
| `cp_delay_observed_err` | `exact`, `minus_one_tick`, `plus_one_tick`, `out_of_spec` |
| `cp_trigger_phase` | `aligned`, `early_half`, `late_half`, `boundary` |
| `cp_frame_interval` | `short_910_at_125`, `long_1550_at_125`, `unexpected` |

### 1.3 Run / Gating

| Coverpoint | Bins |
|---|---|
| `cp_run_state_transition` | `idle_prepare`, `prepare_sync`, `sync_running`, `running_terminating`, `terminating_idle`, `illegal_other` |
| `cp_enable_state` | `enabled`, `disabled` |
| `cp_idle_policy` | `gen_idle_on`, `gen_idle_off` |

### 1.4 Multi-Lane / Shared Datapath

| Coverpoint | Bins |
|---|---|
| `cp_active_lane_count` | `1`, `2`, `4`, `8` |
| `cp_lane_mask_shape` | `low_lane_only`, `high_lane_only`, `sparse`, `contiguous`, `all_on` |
| `cp_timestamp_tie_degree` | `no_tie`, `tie2`, `tie3_4`, `tie5_8` |
| `cp_tie_winner_lane` | `lane0` .. `lane7` |
| `cp_merge_latency_bin` | `fast`, `nominal`, `slow_bounded`, `out_of_spec` |

### 1.5 Integrity / Status

| Coverpoint | Bins |
|---|---|
| `cp_crc_result` | `match`, `mismatch` |
| `cp_event_count_consistency` | `match`, `mismatch` |
| `cp_frame_count_behavior` | `increment`, `repeat`, `skip` |
| `cp_status_snapshot_kind` | `idle_read`, `active_read`, `reset_edge_read` |

## 2. Mandatory Crosses

The following crosses are signoff-critical. Unless explicitly marked as error-only, every non-error bin must be hit in a clean regression.

### 2.1 Single-Lane Functional Crosses

| Cross ID | Cross | Required outcome |
|---|---|---|
| `XC01` | `cp_hit_mode x cp_payload_kind` | Every legal hit mode observed with empty, single, and multi-hit payloads |
| `XC02` | `cp_hit_mode x cp_tx_mode` | Each hit mode exercised in the legal TX modes that can carry it |
| `XC03` | `cp_tx_mode x cp_frame_interval` | Short maps to 910 at 125 MHz, long maps to 1550 at 125 MHz, debug modes remain bounded |
| `XC04` | `cp_delay_cfg x cp_delay_observed_err` | `out_of_spec` must remain empty in clean runs |
| `XC05` | `cp_trigger_phase x cp_delay_observed_err` | Timing tolerance proven across all trigger phases |
| `XC06` | `cp_run_state_transition x cp_enable_state` | No output except in legal `enabled + running` combinations |
| `XC07` | `cp_idle_policy x cp_frame_kind` | Idle/comma behavior proven for active and idle windows |
| `XC08` | `cp_crc_result x cp_frame_kind` | `mismatch` empty in clean runs across all frame kinds |
| `XC09` | `cp_event_count_consistency x cp_payload_kind` | `mismatch` empty in clean runs across payload sizes |
| `XC10` | `cp_frame_count_behavior x cp_run_state_transition` | Repeats/skips absent in legal runs |

### 2.2 Injection / Realistic Timing Crosses

| Cross ID | Cross | Required outcome |
|---|---|---|
| `XC11` | `cp_delay_cfg x cp_hit_mode` | Timing model exercised for every mode |
| `XC12` | `cp_delay_cfg x cp_payload_kind` | Delay model proven for empty/single/multi/max payload regimes |
| `XC13` | `cp_trigger_phase x cp_payload_kind` | Boundary-phase triggers proven across payload sizes |
| `XC14` | `cp_trigger_phase x cp_run_state_transition` | Trigger timing around start/stop windows covered |
| `XC15` | `cp_delay_cfg x cp_idle_policy` | Delay model coexists with both idle policies |

### 2.3 Multi-Lane / Shared-Datapath Crosses

| Cross ID | Cross | Required outcome |
|---|---|---|
| `XC16` | `cp_active_lane_count x cp_timestamp_tie_degree` | Tie behavior covered from 1 to 8 active lanes |
| `XC17` | `cp_active_lane_count x cp_merge_latency_bin` | Merge latency bounded for all active-lane populations |
| `XC18` | `cp_lane_mask_shape x cp_tie_winner_lane` | Tie policy proven for sparse and contiguous populations |
| `XC19` | `cp_delay_cfg x cp_active_lane_count` | Per-lane delay independence proven from 1 to 8 lanes |
| `XC20` | `cp_hit_mode x cp_active_lane_count` | Shared datapath proven across mode mixes and lane counts |
| `XC21` | `cp_tx_mode x cp_active_lane_count` | Shared packetizer proven across mode mixes and lane counts |
| `XC22` | `cp_lane_mask_shape x cp_merge_latency_bin` | No pathological latency for sparse or skewed masks |
| `XC23` | `cp_timestamp_tie_degree x cp_merge_latency_bin` | Tie handling stays within bounded latency |
| `XC24` | `cp_tie_winner_lane x cp_timestamp_tie_degree` | Every lane wins at least one legal tie it should win |

### 2.4 Software-Visible Crosses

| Cross ID | Cross | Required outcome |
|---|---|---|
| `XC25` | `cp_status_snapshot_kind x cp_frame_count_behavior` | Status reads remain coherent across idle/active/reset-edge sampling |
| `XC26` | `cp_status_snapshot_kind x cp_event_count_consistency` | Event-count reporting coherent across read contexts |
| `XC27` | `cp_enable_state x cp_status_snapshot_kind` | Disabled-state software view covered |

## 3. Error-Bin Expectations

The following bins are expected to remain empty in clean regressions and non-empty only in `DV_ERROR.md` runs:

| Bin | Meaning |
|---|---|
| `cp_delay_observed_err.out_of_spec` | Trigger-to-hit latency exceeded tolerance |
| `cp_crc_result.mismatch` | CRC checker observed mismatch |
| `cp_event_count_consistency.mismatch` | Metadata does not match payload |
| `cp_frame_count_behavior.repeat` | Frame count repeated unexpectedly |
| `cp_frame_count_behavior.skip` | Frame count skipped unexpectedly |
| `cp_frame_interval.unexpected` | Frame interval differs from the defined mode |
| `cp_merge_latency_bin.out_of_spec` | Shared merge latency exceeded bound |

## 4. Coverage Closure Rules

1. Every non-error bin in `cp_hit_mode`, `cp_tx_mode`, `cp_payload_kind`, `cp_delay_cfg`, `cp_trigger_phase`, `cp_active_lane_count`, and `cp_lane_mask_shape` must be hit.
2. `XC01` through `XC15` must achieve full legal-bin coverage for the single-lane baseline.
3. `XC16` through `XC24` must achieve full legal-bin coverage for the shared 8-lane architecture before the shared-datapath / area-signoff phase closes.
4. Error bins listed in Section 3 must be empty in clean regressions and intentionally hit in `DV_ERROR.md`.
5. Tie-related coverage is not complete until every lane has been observed as a legal tie winner in the shared datapath.
6. Coverage is not sufficient without the paired Quartus area gate; the shared-datapath Phase 0 close requires both functional coverage and `<4000 ALM` evidence.

## 5. Evidence Artifacts

The regression flow should archive:
- merged coverage database
- latency histogram CSV / report
- tie-winner summary
- frame interval summary
- Quartus ALM report for the exact 8-lane signoff top

These artifacts are part of the signoff package, not optional debug output.
