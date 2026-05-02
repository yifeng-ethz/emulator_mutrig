# DV Coverage Tracking — emulator_mutrig

**Companion docs:** [DV_PLAN.md](DV_PLAN.md), [DV_BASIC.md](DV_BASIC.md), [DV_EDGE.md](DV_EDGE.md), [DV_PROF.md](DV_PROF.md), [DV_ERROR.md](DV_ERROR.md), [DV_HARNESS.md](DV_HARNESS.md), `BUG_HISTORY.md`

**Bin universe:** machine source of truth is [`cov_profiles.json`](cov_profiles.json). The SystemVerilog loader is in [`uvm/cov_profile_loader.svh`](uvm/cov_profile_loader.svh).

**Promotion rule:** every directed case promotes to a constrained-random profile centred on its directed value for `bucket_frame` and `all_buckets_frame` execution. Each case retains its own coverage delta in both modes.

## Legend

OK pass / closed at-or-above target  --  PARTIAL below target / known limitation  --  FAIL failed / missing evidence  --  PEND pending  --  INFO informational

## 1. Bin Inventory Summary

Each row counts coverage bins owned by this DV plan. The same bin may be touched by multiple cases; the loader increments a per-bin counter every time a case exercises it. Sign-off requires every bin to be hit by at least one passing case.

| category | # bins | source |
|---|---:|---|
| `csr_address` | 64 | RTL_PLAN_central_trigger.md §3 (CSR map 0x00..0x3F) |
| `csr_access_class` | 7 | RW/RO/W1P/RW_RO/RSVD_RO/LANE_BLOCK/OOR partitioning |
| `mode_matrix` | 48 | RTL_PLAN_central_trigger.md §2.3-§2.4 mode axes (2x2x2x2x3=48) |
| `cluster_size` | 8 | DV_PLAN.md §3 cluster-size bins |
| `mirror_offset` | 7 | DV_PLAN.md §3 mirror-offset bins |
| `per_lane_cluster` | 32 | DV_PLAN.md §3 per-lane × channel-count |
| `runctl_state` | 9 | DV_HARNESS.md run-control AvST one-hot states |
| `runctl_transition` | 9 | DV_PLAN.md §3 every legal one-hot transition pair |
| `runctl_illegal` | 2 | X017/X018 illegal one-hot decode |
| `ticket_fifo_depth` | 5 | DV_PLAN.md §3 ticket FIFO depth bins |
| `l2_fifo_depth` | 6 | DV_PLAN.md §3 L2 FIFO depth bins |
| `counter_boundary` | 32 | DV_PLAN.md §3 32-bit and 60-bit counter crossings |
| `build_axes_cross` | 8 | DV_PLAN.md §5 LANE_COUNT × BYTE_STREAM_ENABLE |
| `structural_misc` | 99 | structural anchors (UID readback, sticky bits, ECC seed phases, type0 SOP/EOP, etc.) |
| **total** | **336** | — |

Per-case mean bin count: **2.44** (min 1, max 49, sum 1250 bin-touches over 512 cases).

## 2. Code-Coverage Targets (per dv-workflow §6)

<!-- columns:
  metric  = code-coverage category as reported by Questa FSE
  target  = workflow target percentage
  policy  = how to interpret a miss
-->

| metric | target | policy |
|---|---:|---|
| stmt | 95.0 | release gate |
| branch | 90.0 | release gate |
| fsm_state | 95.0 | release gate |
| fsm_trans | 90.0 | release gate |
| toggle | 80.0 | release gate |
| cond | reported | no fixed target |
| expr | reported | no fixed target |

## 3. Per-Case Coverage Bin Ownership

This is the canonical per-case bin map. Each row lists the coverage bins this case is responsible for exercising. The full machine-readable version is in [`cov_profiles.json`](cov_profiles.json); the table below is one row per case for human review.

<!-- columns:
  case_id          = planned case ID (B/E/P/X + 3 digits)
  type (d/r)       = directed or randomised under isolated execution
  promotion        = D = stays directed in soak / R = promoted to constrained-random in bucket_frame and all_buckets_frame
  n_bins           = number of coverage bins this case owns
  bins             = comma-separated bin names
-->

### 3.1 BASIC bucket bin ownership

| case_id | type (d/r) | promotion | n_bins | bins |
|---|---|---|---:|---|
| `B001` | d | D | 3 | `csr_addr_0x00`, `csr_access_RO`, `uid_readback` |
| `B002` | r | R | 3 | `csr_addr_0x00`, `csr_access_RO`, `uid_readback` |
| `B003` | d | D | 3 | `csr_addr_0x01`, `csr_access_RW_RO`, `meta_VERSION` |
| `B004` | d | D | 3 | `csr_addr_0x01`, `csr_access_RW_RO`, `meta_DATE` |
| `B005` | d | D | 3 | `csr_addr_0x01`, `csr_access_RW_RO`, `meta_GIT` |
| `B006` | d | D | 3 | `csr_addr_0x01`, `csr_access_RW_RO`, `meta_INSTANCE_ID` |
| `B007` | r | R | 3 | `csr_addr_0x02`, `csr_access_RW`, `scratch_liveness` |
| `B008` | r | R | 3 | `csr_addr_0x02`, `csr_access_RW`, `scratch_liveness` |
| `B009` | d | D | 4 | `csr_addr_0x02`, `csr_access_RW`, `scratch_liveness`, `last_clear_on_irst` |
| `B010` | d | D | 3 | `csr_addr_0x03`, `csr_access_RO`, `last_rd_capture` |
| `B011` | d | D | 3 | `csr_addr_0x04`, `csr_access_RO`, `last_rd_capture` |
| `B012` | d | D | 4 | `csr_addr_0x03`, `csr_addr_0x04`, `csr_access_RO`, `last_rd_self_stable` |
| `B013` | d | D | 3 | `csr_addr_0x05`, `csr_access_RO`, `last_wr_capture` |
| `B014` | d | D | 3 | `csr_addr_0x06`, `csr_access_RO`, `last_wr_capture` |
| `B015` | d | D | 5 | `csr_addr_0x03`, `csr_addr_0x04`, `csr_addr_0x05`, `csr_addr_0x06`, `last_clear_on_irst` |
| `B016` | d | D | 2 | `csr_addr_0x3F`, `csr_access_OOR` |
| `B017` | d | D | 2 | `runctl_state_RUN_PREPARE`, `runctl_trans_IDLE_to_RUN_PREPARE` |
| `B018` | d | D | 2 | `runctl_state_SYNC`, `runctl_trans_RUN_PREPARE_to_SYNC` |
| `B019` | d | D | 2 | `runctl_state_RUNNING`, `runctl_trans_SYNC_to_RUNNING` |
| `B020` | d | D | 2 | `runctl_state_TERMINATING`, `runctl_trans_RUNNING_to_TERMINATING` |
| `B021` | d | D | 4 | `runctl_state_IDLE`, `runctl_trans_TERMINATING_to_IDLE`, `type0_endofrun`, `byte_stream_idle_K28_5` |
| `B022` | d | D | 2 | `runctl_state_RESET`, `runctl_trans_IDLE_to_RESET` |
| `B023` | d | D | 3 | `runctl_state_OUT_OF_DAQ`, `runctl_trans_IDLE_to_OUT_OF_DAQ`, `byte_stream_idle_K28_5` |
| `B024` | d | D | 2 | `runctl_state_LINK_TEST`, `runctl_trans_IDLE_to_LINK_TEST` |
| `B025` | d | D | 2 | `runctl_state_SYNC_TEST`, `runctl_trans_IDLE_to_SYNC_TEST` |
| `B026` | d | D | 1 | `runctl_state_RUNNING` |
| `B027` | d | D | 1 | `runctl_illegal_multibit` |
| `B028` | d | D | 3 | `runctl_trans_IDLE_to_RUN_PREPARE`, `runctl_trans_RUN_PREPARE_to_SYNC`, `runctl_trans_SYNC_to_RUNNING` |
| `B029` | d | D | 1 | `runctl_state_RUN_PREPARE` |
| `B030` | d | D | 1 | `inject_during_idle_drop` |
| `B031` | d | D | 1 | `global_enable_gate` |
| `B032` | d | D | 1 | `global_enable_gate` |
| `B033` | r | R | 3 | `mode_INTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED`, `rate_zero`, `lane_count_0_hits` |
| `B034` | r | R | 2 | `mode_INTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED`, `rate_low` |
| `B035` | r | R | 2 | `mode_INTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED`, `rate_mid` |
| `B036` | r | R | 2 | `mode_INTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED`, `rate_mid` |
| `B037` | r | R | 2 | `mode_INTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED`, `rate_mid` |
| `B038` | r | R | 2 | `mode_INTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED`, `rate_max` |
| `B039` | d | D | 2 | `mode_INTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED`, `prng_seed_reproducibility` |
| `B040` | r | R | 2 | `mode_INTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED`, `prng_seed_diverge` |
| `B041` | r | R | 2 | `mode_INTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED`, `prng_seed_reproducibility` |
| `B042` | r | R | 3 | `mode_INTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED`, `cluster_size_1`, `lane0_clus1` |
| `B043` | r | R | 3 | `mode_INTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED`, `cluster_size_32`, `lane0_clus32` |
| `B044` | r | R | 2 | `mode_INTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED`, `lane_disabled_silent` |
| `B045` | r | R | 3 | `mode_INTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED`, `ticket_overflow_count_inc`, `ticket_fifo_depth_8` |
| `B046` | r | R | 2 | `mode_INTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED`, `ticket_fifo_depth_0` |
| `B047` | r | R | 1 | `mode_INTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED` |
| `B048` | r | R | 2 | `mode_INTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED`, `mode_EXTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED` |
| `B049` | d | D | 2 | `mode_INTERNAL_PERIODIC_FIX_BKGOFF_MIRMIRRORED`, `rate_max` |
| `B050` | d | D | 2 | `mode_INTERNAL_PERIODIC_FIX_BKGOFF_MIRMIRRORED`, `rate_high` |
| `B051` | d | D | 2 | `mode_INTERNAL_PERIODIC_FIX_BKGOFF_MIRMIRRORED`, `rate_high` |
| `B052` | d | D | 2 | `mode_INTERNAL_PERIODIC_FIX_BKGOFF_MIRMIRRORED`, `rate_mid` |
| `B053` | d | D | 2 | `mode_INTERNAL_PERIODIC_FIX_BKGOFF_MIRMIRRORED`, `rate_mid` |
| `B054` | d | D | 3 | `mode_INTERNAL_PERIODIC_FIX_BKGOFF_MIRMIRRORED`, `rate_zero`, `lane_count_0_hits` |
| `B055` | d | D | 3 | `mode_INTERNAL_PERIODIC_FIX_BKGOFF_MIRMIRRORED`, `rate_high`, `ticket_fifo_depth_4` |
| `B056` | d | D | 3 | `mode_INTERNAL_PERIODIC_FIX_BKGOFF_MIRMIRRORED`, `rate_high`, `runctl_state_SYNC` |
| `B057` | d | D | 2 | `mode_INTERNAL_PERIODIC_FIX_BKGOFF_MIRMIRRORED`, `mode_INTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED` |
| `B058` | d | D | 5 | `mode_INTERNAL_PERIODIC_FIX_BKGOFF_MIRMIRRORED`, `rate_high`, `cluster_size_32`, `lane2_clus32`, `lane3_clus1` |
| `B059` | d | D | 2 | `mode_INTERNAL_PERIODIC_RANDOM_BKGOFF_MIRMIRRORED`, `cluster_size_2` |
| `B060` | d | D | 2 | `mode_INTERNAL_PERIODIC_FIX_BKGOFF_MIRMIRRORED`, `rate_high` |
| `B061` | d | D | 3 | `mode_INTERNAL_PERIODIC_FIX_BKGOFF_MIRMIRRORED`, `rate_high`, `prng_seed_reproducibility` |
| `B062` | d | D | 4 | `mode_INTERNAL_PERIODIC_FIX_BKGOFF_MIRMIRRORED`, `rate_high`, `fine_time_jitter_t`, `fine_time_jitter_e` |
| `B063` | d | D | 1 | `mode_INTERNAL_PERIODIC_FIX_BKGON_MIRMIRRORED` |
| `B064` | d | D | 3 | `mode_INTERNAL_PERIODIC_FIX_BKGOFF_MIRMIRRORED`, `rate_high`, `global_enable_gate` |
| `B065` | d | D | 4 | `fire_w1p_singleshot`, `fire_csr_conduit_or`, `csr_addr_0x13`, `csr_access_W1P` |
| `B066` | d | D | 2 | `fire_edge_detect`, `fire_csr_conduit_or` |
| `B067` | d | D | 2 | `fire_edge_detect`, `fire_csr_conduit_or` |
| `B068` | d | D | 2 | `fire_edge_detect`, `fire_csr_conduit_or` |
| `B069` | d | D | 2 | `inject_in_internal`, `mode_INTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED` |
| `B070` | d | D | 2 | `inject_in_external`, `mode_EXTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED` |
| `B071` | d | D | 2 | `inject_in_external`, `mode_EXTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED` |
| `B072` | d | D | 2 | `fire_csr_conduit_or`, `global_enable_gate` |
| `B073` | d | D | 1 | `inject_during_idle_drop` |
| `B074` | d | D | 1 | `inject_during_term_drop` |
| `B075` | d | D | 1 | `inject_during_sync_drop` |
| `B076` | d | D | 1 | `fire_edge_detect` |
| `B077` | d | D | 1 | `fire_w1p_singleshot` |
| `B078` | d | D | 2 | `fire_csr_conduit_or`, `internal_dropped_on_stall` |
| `B079` | d | D | 3 | `smb_cross`, `cluster_size_1`, `mode_INTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED` |
| `B080` | d | D | 2 | `mode_INTERNAL_POISSON_RANDOM_BKGOFF_MIRMIRRORED`, `cluster_size_1` |
| `B081` | d | D | 4 | `mode_EXTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED`, `cluster_size_1`, `lane0_clus1`, `smb_A_only` |
| `B082` | d | D | 2 | `cluster_size_1`, `smb_A_only` |
| `B083` | d | D | 2 | `cluster_size_1`, `smb_B_only` |
| `B084` | d | D | 2 | `cluster_size_1`, `smb_B_only` |
| `B085` | d | D | 3 | `cluster_size_32`, `lane0_clus32`, `smb_A_only` |
| `B086` | d | D | 2 | `cluster_size_33`, `smb_A_only` |
| `B087` | d | D | 2 | `cluster_size_64`, `smb_A_only` |
| `B088` | d | D | 2 | `cluster_size_128`, `smb_A_only` |
| `B089` | d | D | 2 | `cluster_size_128`, `smb_cross` |
| `B090` | d | D | 2 | `cluster_size_256`, `smb_cross` |
| `B091` | d | D | 1 | `mode_EXTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED` |
| `B092` | d | D | 3 | `cluster_size_1`, `smb_A_only`, `lane2_clus1` |
| `B093` | d | D | 3 | `cluster_size_32`, `smb_A_only`, `lane1_clus32` |
| `B094` | d | D | 2 | `cluster_size_33`, `smb_A_only` |
| `B095` | d | D | 2 | `lane_disabled_silent`, `cluster_size_64` |
| `B096` | d | D | 2 | `cluster_size_256`, `smb_cross` |
| `B097` | d | D | 3 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRLEFT_ONLY`, `cluster_size_1`, `smb_A_only` |
| `B098` | d | D | 3 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRRIGHT_ONLY`, `cluster_size_1`, `smb_B_only` |
| `B099` | d | D | 3 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRMIRRORED`, `cluster_size_1`, `mirror_offset_zero0` |
| `B100` | r | R | 3 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRMIRRORED`, `cluster_size_1`, `mirror_offset_pos1` |
| `B101` | r | R | 3 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRMIRRORED`, `cluster_size_1`, `mirror_offset_neg1` |
| `B102` | d | D | 2 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRMIRRORED`, `mirror_offset_zero0` |
| `B103` | d | D | 3 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRMIRRORED`, `cluster_size_128`, `mirror_offset_zero0` |
| `B104` | d | D | 3 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRLEFT_ONLY`, `cluster_size_64`, `smb_A_only` |
| `B105` | d | D | 3 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRLEFT_ONLY`, `cluster_size_128`, `smb_A_only` |
| `B106` | d | D | 2 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRMIRRORED`, `mirror_clamp_high` |
| `B107` | d | D | 2 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRMIRRORED`, `cluster_size_1` |
| `B108` | r | R | 2 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRLEFT_ONLY`, `rand_center_uniform` |
| `B109` | d | D | 2 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRLEFT_ONLY`, `prng_seed_reproducibility` |
| `B110` | d | D | 2 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRMIRRORED`, `global_enable_gate` |
| `B111` | d | D | 2 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRLEFT_ONLY`, `smb_A_only` |
| `B112` | r | R | 2 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRMIRRORED`, `rand_side_pick_uniform` |
| `B113` | d | D | 2 | `mode_EXTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED`, `noise_rate_zero` |
| `B114` | d | D | 3 | `mode_EXTERNAL_POISSON_FIX_BKGON_MIRMIRRORED`, `noise_rate_zero`, `lane_count_0_hits` |
| `B115` | r | R | 2 | `mode_EXTERNAL_POISSON_FIX_BKGON_MIRMIRRORED`, `noise_rate_low` |
| `B116` | r | R | 2 | `mode_EXTERNAL_POISSON_FIX_BKGON_MIRMIRRORED`, `noise_rate_mid` |
| `B117` | r | R | 2 | `mode_EXTERNAL_POISSON_FIX_BKGON_MIRMIRRORED`, `noise_rate_max` |
| `B118` | d | D | 3 | `mode_EXTERNAL_POISSON_FIX_BKGON_MIRMIRRORED`, `noise_rate_mid`, `bkg_full_lane_coverage` |
| `B119` | d | D | 3 | `mode_EXTERNAL_POISSON_FIX_BKGON_MIRMIRRORED`, `noise_rate_mid`, `fine_time_jitter_t` |
| `B120` | d | D | 3 | `mode_EXTERNAL_POISSON_FIX_BKGON_MIRMIRRORED`, `noise_rate_mid`, `tcc_full_period_observed` |
| `B121` | d | D | 1 | `mode_INTERNAL_POISSON_FIX_BKGON_MIRMIRRORED` |
| `B122` | d | D | 1 | `mode_EXTERNAL_POISSON_FIX_BKGON_MIRMIRRORED` |
| `B123` | d | D | 3 | `mode_EXTERNAL_POISSON_FIX_BKGON_MIRMIRRORED`, `noise_rate_mid`, `runctl_trans_RUNNING_to_TERMINATING` |
| `B124` | d | D | 3 | `mode_EXTERNAL_POISSON_FIX_BKGON_MIRMIRRORED`, `noise_rate_mid`, `global_enable_gate` |
| `B125` | d | D | 3 | `mode_EXTERNAL_POISSON_FIX_BKGON_MIRMIRRORED`, `noise_rate_mid`, `prng_seed_reproducibility` |
| `B126` | r | R | 3 | `mode_EXTERNAL_POISSON_FIX_BKGON_MIRMIRRORED`, `noise_rate_mid`, `bkg_uniform_per_channel` |
| `B127` | d | D | 3 | `mode_EXTERNAL_POISSON_FIX_BKGON_MIRMIRRORED`, `noise_rate_mid`, `engine_round_robin` |
| `B128` | d | D | 3 | `mode_EXTERNAL_POISSON_FIX_BKGON_MIRMIRRORED`, `noise_rate_mid`, `bkg_full_lane_coverage` |

### 3.2 EDGE bucket bin ownership

| case_id | type (d/r) | promotion | n_bins | bins |
|---|---|---|---:|---|
| `E001` | d | D | 3 | `cluster_size_1`, `smb_A_only`, `lane0_clus1` |
| `E002` | d | D | 2 | `cluster_size_1`, `smb_B_only` |
| `E003` | d | D | 2 | `cluster_size_1`, `smb_B_only` |
| `E004` | d | D | 2 | `cluster_size_2`, `smb_cross` |
| `E005` | d | D | 2 | `cluster_size_2`, `smb_A_only` |
| `E006` | d | D | 2 | `cluster_size_2`, `smb_B_only` |
| `E007` | d | D | 2 | `cluster_size_1`, `smb_B_only` |
| `E008` | d | D | 2 | `cluster_size_256`, `smb_cross` |
| `E009` | d | D | 2 | `cluster_size_256`, `lane_disabled_silent` |
| `E010` | d | D | 2 | `cluster_size_33`, `smb_cross` |
| `E011` | d | D | 2 | `cluster_size_128`, `smb_A_only` |
| `E012` | d | D | 2 | `cluster_size_128`, `smb_B_only` |
| `E013` | d | D | 1 | `lane7_clus16` |
| `E014` | d | D | 1 | `smb_B_only` |
| `E015` | d | D | 3 | `cluster_size_1`, `smb_A_only`, `lane2_clus1` |
| `E016` | d | D | 3 | `cluster_size_1`, `smb_B_only`, `lane6_clus1` |
| `E017` | d | D | 3 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRMIRRORED`, `cluster_size_1`, `mirror_offset_zero0` |
| `E018` | d | D | 3 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRMIRRORED`, `cluster_size_2`, `mirror_offset_zero0` |
| `E019` | d | D | 2 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRMIRRORED`, `mirror_offset_zero0` |
| `E020` | d | D | 2 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRMIRRORED`, `cluster_size_128` |
| `E021` | d | D | 2 | `cluster_size_128`, `mirror_clamp_high` |
| `E022` | d | D | 1 | `cluster_size_1` |
| `E023` | d | D | 3 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRLEFT_ONLY`, `cluster_size_1`, `smb_A_only` |
| `E024` | d | D | 3 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRLEFT_ONLY`, `cluster_size_1`, `smb_A_only` |
| `E025` | d | D | 3 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRLEFT_ONLY`, `smb_A_only`, `mirror_clamp_low` |
| `E026` | d | D | 3 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRLEFT_ONLY`, `smb_A_only`, `mirror_clamp_high` |
| `E027` | d | D | 3 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRLEFT_ONLY`, `cluster_size_128`, `smb_A_only` |
| `E028` | d | D | 1 | `cluster_size_1` |
| `E029` | d | D | 2 | `cluster_size_32`, `ticket_fifo_depth_1` |
| `E030` | d | D | 9 | `cluster_size_1`, `lane0_clus1`, `lane1_clus1`, `lane2_clus1`, `lane3_clus1`, `lane4_clus1`, `lane5_clus1`, `lane6_clus1`, `lane7_clus1` |
| `E031` | d | D | 2 | `ticket_fifo_depth_8`, `engine_back_to_back` |
| `E032` | d | D | 2 | `ticket_fifo_depth_8`, `ticket_overflow_count_inc` |
| `E033` | d | D | 2 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRMIRRORED`, `mirror_offset_zero0` |
| `E034` | d | D | 2 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRMIRRORED`, `mirror_offset_pos1` |
| `E035` | d | D | 2 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRMIRRORED`, `mirror_offset_neg1` |
| `E036` | r | R | 2 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRMIRRORED`, `mirror_offset_pos32` |
| `E037` | d | D | 2 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRMIRRORED`, `mirror_clamp_high` |
| `E038` | d | D | 3 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRMIRRORED`, `mirror_offset_neg128`, `mirror_clamp_low` |
| `E039` | d | D | 3 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRMIRRORED`, `mirror_offset_pos127`, `mirror_clamp_high` |
| `E040` | d | D | 3 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRMIRRORED`, `cluster_size_128`, `mirror_offset_pos1` |
| `E041` | d | D | 3 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRMIRRORED`, `cluster_size_1`, `mirror_offset_zero0` |
| `E042` | d | D | 3 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRMIRRORED`, `cluster_size_128`, `mirror_offset_zero0` |
| `E043` | r | R | 2 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRMIRRORED`, `tcc_full_period_observed` |
| `E044` | d | D | 2 | `csr_addr_0x0D`, `csr_access_RW` |
| `E045` | d | D | 2 | `csr_addr_0x0D`, `csr_access_RW` |
| `E046` | d | D | 2 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRRIGHT_ONLY`, `smb_B_only` |
| `E047` | d | D | 2 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRLEFT_ONLY`, `smb_A_only` |
| `E048` | d | D | 2 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRMIRRORED`, `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRLEFT_ONLY` |
| `E049` | d | D | 2 | `smb_A_only`, `cluster_size_128` |
| `E050` | d | D | 2 | `smb_B_only`, `cluster_size_128` |
| `E051` | d | D | 1 | `smb_cross` |
| `E052` | d | D | 2 | `smb_cross`, `cluster_size_128` |
| `E053` | d | D | 3 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRLEFT_ONLY`, `cluster_size_128`, `smb_A_only` |
| `E054` | d | D | 1 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRMIRRORED` |
| `E055` | d | D | 2 | `cluster_size_256`, `engine_busy_high_water` |
| `E056` | d | D | 1 | `cluster_size_256` |
| `E057` | d | D | 1 | `lane_disabled_silent` |
| `E058` | d | D | 2 | `smb_A_only`, `lane_disabled_silent` |
| `E059` | d | D | 2 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRMIRRORED`, `lane_disabled_silent` |
| `E060` | d | D | 2 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRMIRRORED`, `lane_disabled_silent` |
| `E061` | d | D | 2 | `lane_disabled_silent`, `lane_count_0_hits` |
| `E062` | d | D | 1 | `asic_id_base_nonzero` |
| `E063` | d | D | 2 | `lane_disabled_silent`, `cluster_size_128` |
| `E064` | d | D | 1 | `lane_reenabled_resume` |
| `E065` | d | D | 3 | `tcc_seed_default`, `ecc_seed_default`, `ecc_phase_n0` |
| `E066` | d | D | 2 | `ecc_phase_n1`, `ecc_seed_custom` |
| `E067` | d | D | 2 | `ecc_phase_n5`, `ecc_seed_custom` |
| `E068` | d | D | 2 | `ecc_phase_n20`, `ecc_seed_custom` |
| `E069` | d | D | 2 | `ecc_phase_n1000`, `ecc_seed_custom` |
| `E070` | d | D | 2 | `ecc_phase_n_full_period`, `ecc_seed_custom` |
| `E071` | d | D | 2 | `ecc_phase_n_full_period`, `ecc_seed_custom` |
| `E072` | d | D | 3 | `ecc_seed_custom`, `csr_addr_0x0F`, `csr_access_RW` |
| `E073` | d | D | 2 | `tcc_seed_custom`, `ecc_seed_custom` |
| `E074` | d | D | 2 | `csr_addr_0x0F`, `csr_access_RW` |
| `E075` | d | D | 1 | `tcc_seed_zero_invalid` |
| `E076` | d | D | 1 | `ecc_seed_zero_invalid` |
| `E077` | d | D | 2 | `tcc_seed_default`, `ecc_seed_default` |
| `E078` | d | D | 2 | `ecc_seed_custom`, `prng_seed_reproducibility` |
| `E079` | d | D | 2 | `ecc_seed_custom`, `type0_vs_deassembly_parity` |
| `E080` | d | D | 2 | `ecc_seed_custom`, `type0_vs_deassembly_parity` |
| `E081` | d | D | 2 | `frame_boundary_at_inject`, `type0_sop` |
| `E082` | d | D | 1 | `frame_boundary_at_inject` |
| `E083` | d | D | 1 | `frame_boundary_at_inject` |
| `E084` | d | D | 2 | `frame_boundary_during_dispense`, `cluster_size_32` |
| `E085` | d | D | 1 | `frame_empty` |
| `E086` | d | D | 3 | `frame_with_one_hit`, `type0_sop`, `type0_eop` |
| `E087` | d | D | 1 | `frame_at_event_max` |
| `E088` | d | D | 3 | `frame_with_one_hit`, `type0_sop`, `type0_eop` |
| `E089` | d | D | 1 | `frame_short_mode` |
| `E090` | d | D | 1 | `frame_long_mode` |
| `E091` | d | D | 2 | `frame_short_mode`, `frame_long_mode` |
| `E092` | d | D | 1 | `byte_stream_active` |
| `E093` | d | D | 1 | `byte_stream_active` |
| `E094` | d | D | 1 | `frame_count_lane0_32bit` |
| `E095` | d | D | 8 | `frame_count_lane0_60bit`, `frame_count_lane1_60bit`, `frame_count_lane2_60bit`, `frame_count_lane3_60bit`, `frame_count_lane4_60bit`, `frame_count_lane5_60bit`, `frame_count_lane6_60bit`, `frame_count_lane7_60bit` |
| `E096` | d | D | 1 | `hit_count_lane0_32bit` |
| `E097` | d | D | 3 | `csr_addr_0x20`, `csr_access_LANE_BLOCK`, `frame_count_lane0_32bit` |
| `E098` | d | D | 8 | `frame_count_lane0_32bit`, `frame_count_lane1_32bit`, `frame_count_lane2_32bit`, `frame_count_lane3_32bit`, `frame_count_lane4_32bit`, `frame_count_lane5_32bit`, `frame_count_lane6_32bit`, `frame_count_lane7_32bit` |
| `E099` | d | D | 8 | `frame_count_lane0_60bit`, `frame_count_lane1_60bit`, `frame_count_lane2_60bit`, `frame_count_lane3_60bit`, `frame_count_lane4_60bit`, `frame_count_lane5_60bit`, `frame_count_lane6_60bit`, `frame_count_lane7_60bit` |
| `E100` | d | D | 3 | `csr_addr_0x22`, `csr_access_LANE_BLOCK`, `hit_count_lane0_32bit` |
| `E101` | d | D | 8 | `hit_count_lane0_32bit`, `hit_count_lane1_32bit`, `hit_count_lane2_32bit`, `hit_count_lane3_32bit`, `hit_count_lane4_32bit`, `hit_count_lane5_32bit`, `hit_count_lane6_32bit`, `hit_count_lane7_32bit` |
| `E102` | d | D | 8 | `hit_count_lane0_60bit`, `hit_count_lane1_60bit`, `hit_count_lane2_60bit`, `hit_count_lane3_60bit`, `hit_count_lane4_60bit`, `hit_count_lane5_60bit`, `hit_count_lane6_60bit`, `hit_count_lane7_60bit` |
| `E103` | d | D | 1 | `hit_count_lane3_32bit` |
| `E104` | d | D | 2 | `frame_count_lane0_32bit`, `runctl_state_SYNC` |
| `E105` | d | D | 1 | `frame_count_lane0_32bit` |
| `E106` | d | D | 2 | `fifo_full_sticky_set`, `l2_fifo_depth_256` |
| `E107` | d | D | 1 | `fifo_full_sticky_w1c` |
| `E108` | d | D | 2 | `ticket_overflow_sticky_set`, `ticket_fifo_depth_8` |
| `E109` | d | D | 1 | `ticket_overflow_sticky_w1c` |
| `E110` | d | D | 1 | `ticket_overflow_saturate` |
| `E111` | d | D | 1 | `engine_busy_high_water` |
| `E112` | d | D | 1 | `csr_lo_hi_atomic_snapshot` |
| `E113` | d | D | 2 | `csr_addr_0x07`, `csr_access_RW` |
| `E114` | d | D | 2 | `csr_addr_0x08`, `csr_access_RW` |
| `E115` | d | D | 2 | `csr_addr_0x09`, `csr_access_RW` |
| `E116` | d | D | 2 | `csr_addr_0x0A`, `csr_access_RW` |
| `E117` | d | D | 2 | `csr_addr_0x10`, `csr_access_RSVD_RO` |
| `E118` | d | D | 2 | `csr_addr_0x11`, `csr_access_RSVD_RO` |
| `E119` | d | D | 11 | `csr_addr_0x16`, `csr_addr_0x17`, `csr_addr_0x18`, `csr_addr_0x19`, `csr_addr_0x1A`, `csr_addr_0x1B`, `csr_addr_0x1C`, `csr_addr_0x1D`, `csr_addr_0x1E`, `csr_addr_0x1F`, `csr_access_RSVD_RO` |
| `E120` | d | D | 1 | `csr_access_OOR` |
| `E121` | d | D | 2 | `csr_during_running`, `runctl_state_RESET` |
| `E122` | d | D | 1 | `csr_during_irst` |
| `E123` | d | D | 2 | `csr_during_irst`, `csr_atomic_write` |
| `E124` | d | D | 2 | `csr_atomic_write`, `csr_atomic_read` |
| `E125` | d | D | 1 | `csr_access_OOR` |
| `E126` | d | D | 3 | `csr_addr_0x13`, `csr_access_W1P`, `fire_w1p_singleshot` |
| `E127` | d | D | 3 | `csr_addr_0x15`, `csr_access_RW`, `type0_error_inject_stub` |
| `E128` | d | D | 2 | `csr_addr_0x15`, `type0_error_inject_stub` |

### 3.3 PROF bucket bin ownership

| case_id | type (d/r) | promotion | n_bins | bins |
|---|---|---|---:|---|
| `P001` | r | R | 3 | `mode_INTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED`, `rate_max`, `soak_1M` |
| `P002` | r | R | 3 | `mode_INTERNAL_PERIODIC_FIX_BKGOFF_MIRMIRRORED`, `rate_high`, `soak_1M` |
| `P003` | r | R | 3 | `mode_INTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED`, `rate_mid`, `soak_1M` |
| `P004` | r | R | 3 | `mode_INTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED`, `rate_mid`, `soak_1M` |
| `P005` | r | R | 3 | `mode_INTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED`, `rate_mid`, `soak_1M` |
| `P006` | r | R | 3 | `mode_INTERNAL_PERIODIC_FIX_BKGOFF_MIRMIRRORED`, `rate_max`, `soak_10M` |
| `P007` | r | R | 4 | `mode_INTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED`, `rate_max`, `cluster_size_1`, `soak_1M` |
| `P008` | r | R | 4 | `mode_INTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED`, `rate_low`, `cluster_size_256`, `soak_1M` |
| `P009` | r | R | 3 | `mode_INTERNAL_PERIODIC_RANDOM_BKGOFF_MIRMIRRORED`, `cluster_size_64`, `soak_1M` |
| `P010` | r | R | 5 | `mode_INTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED`, `rate_max`, `lane_disabled_silent`, `ticket_overflow_count_inc`, `ticket_fifo_depth_8` |
| `P011` | r | R | 4 | `mode_INTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED`, `rate_max`, `ticket_fifo_depth_0`, `ticket_fifo_depth_8` |
| `P012` | r | R | 3 | `mode_INTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED`, `rate_mid`, `soak_1M` |
| `P013` | r | R | 3 | `mode_INTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED`, `rate_mid`, `soak_1M` |
| `P014` | r | R | 3 | `mode_INTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED`, `rate_mid`, `global_enable_gate` |
| `P015` | r | R | 3 | `mode_INTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED`, `rate_mid`, `runctl_trans_RUNNING_to_TERMINATING` |
| `P016` | r | R | 3 | `fire_csr_conduit_or`, `engine_back_to_back`, `soak_1M` |
| `P017` | d | D | 3 | `cluster_size_32`, `ticket_fifo_depth_8`, `engine_back_to_back` |
| `P018` | d | D | 3 | `cluster_size_32`, `ticket_fifo_depth_8`, `ticket_overflow_count_inc` |
| `P019` | d | D | 2 | `ticket_overflow_count_inc`, `engine_busy_high_water` |
| `P020` | d | D | 2 | `ticket_overflow_saturate`, `fifo_full_sticky_set` |
| `P021` | d | D | 1 | `engine_back_to_back` |
| `P022` | d | D | 8 | `cluster_size_1`, `cluster_size_2`, `cluster_size_32`, `cluster_size_33`, `cluster_size_64`, `cluster_size_127`, `cluster_size_128`, `cluster_size_256` |
| `P023` | d | D | 2 | `lane2_clus1`, `ticket_fifo_depth_8` |
| `P024` | d | D | 8 | `lane0_clus1`, `lane1_clus1`, `lane2_clus1`, `lane3_clus1`, `lane4_clus1`, `lane5_clus1`, `lane6_clus1`, `lane7_clus1` |
| `P025` | d | D | 2 | `mode_INTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED`, `fire_csr_conduit_or` |
| `P026` | d | D | 2 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRMIRRORED`, `cluster_size_128` |
| `P027` | d | D | 3 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRLEFT_ONLY`, `cluster_size_128`, `smb_A_only` |
| `P028` | d | D | 3 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRRIGHT_ONLY`, `cluster_size_128`, `smb_B_only` |
| `P029` | d | D | 1 | `frame_boundary_during_dispense` |
| `P030` | d | D | 2 | `l2_fifo_depth_256`, `fifo_full_sticky_set` |
| `P031` | d | D | 2 | `byte_stream_active`, `l2_fifo_depth_192` |
| `P032` | d | D | 3 | `l2_fifo_depth_256`, `ticket_fifo_depth_8`, `fifo_full_sticky_set` |
| `P033` | r | R | 3 | `mode_EXTERNAL_POISSON_FIX_BKGON_MIRMIRRORED`, `noise_rate_low`, `soak_10M` |
| `P034` | r | R | 3 | `mode_EXTERNAL_POISSON_FIX_BKGON_MIRMIRRORED`, `noise_rate_mid`, `soak_10M` |
| `P035` | r | R | 3 | `mode_EXTERNAL_POISSON_FIX_BKGON_MIRMIRRORED`, `noise_rate_mid`, `soak_10M` |
| `P036` | r | R | 3 | `mode_EXTERNAL_POISSON_FIX_BKGON_MIRMIRRORED`, `noise_rate_mid`, `soak_100M` |
| `P037` | r | R | 4 | `mode_EXTERNAL_POISSON_FIX_BKGON_MIRMIRRORED`, `noise_rate_mid`, `fine_time_jitter_t`, `fine_time_jitter_e` |
| `P038` | r | R | 3 | `mode_EXTERNAL_POISSON_FIX_BKGON_MIRMIRRORED`, `noise_rate_mid`, `tcc_full_period_observed` |
| `P039` | r | R | 3 | `mode_EXTERNAL_POISSON_FIX_BKGON_MIRMIRRORED`, `noise_rate_mid`, `lane_disabled_silent` |
| `P040` | d | D | 3 | `mode_EXTERNAL_POISSON_FIX_BKGON_MIRMIRRORED`, `noise_rate_mid`, `prng_seed_reproducibility` |
| `P041` | r | R | 3 | `mode_EXTERNAL_POISSON_FIX_BKGON_MIRMIRRORED`, `noise_rate_mid`, `prng_seed_diverge` |
| `P042` | r | R | 3 | `mode_EXTERNAL_POISSON_FIX_BKGON_MIRMIRRORED`, `noise_rate_mid`, `bkg_uniform_per_channel` |
| `P043` | r | R | 2 | `mode_INTERNAL_POISSON_FIX_BKGON_MIRMIRRORED`, `engine_round_robin` |
| `P044` | r | R | 3 | `mode_EXTERNAL_POISSON_FIX_BKGON_MIRMIRRORED`, `noise_rate_mid`, `runctl_trans_RUNNING_to_TERMINATING` |
| `P045` | r | R | 4 | `mode_EXTERNAL_POISSON_FIX_BKGON_MIRMIRRORED`, `noise_rate_mid`, `ticket_overflow_count_inc`, `ticket_fifo_depth_8` |
| `P046` | r | R | 3 | `mode_EXTERNAL_POISSON_FIX_BKGON_MIRMIRRORED`, `noise_rate_mid`, `ticket_fifo_depth_0` |
| `P047` | r | R | 3 | `mode_EXTERNAL_POISSON_FIX_BKGON_MIRMIRRORED`, `noise_rate_mid`, `tcc_full_period_observed` |
| `P048` | r | R | 4 | `mode_EXTERNAL_POISSON_FIX_BKGON_MIRMIRRORED`, `noise_rate_low`, `soak_1B`, `bkg_uniform_per_channel` |
| `P049` | r | R | 3 | `mode_INTERNAL_POISSON_FIX_BKGON_MIRMIRRORED`, `rate_mid`, `noise_rate_mid` |
| `P050` | r | R | 3 | `mode_INTERNAL_PERIODIC_FIX_BKGON_MIRMIRRORED`, `rate_mid`, `noise_rate_mid` |
| `P051` | r | R | 2 | `mode_EXTERNAL_POISSON_FIX_BKGON_MIRMIRRORED`, `fire_csr_conduit_or` |
| `P052` | r | R | 3 | `mode_EXTERNAL_POISSON_FIX_BKGON_MIRMIRRORED`, `fire_csr_conduit_or`, `inject_in_external` |
| `P053` | r | R | 2 | `mode_EXTERNAL_POISSON_FIX_BKGON_MIRMIRRORED`, `cluster_size_32` |
| `P054` | r | R | 1 | `mode_EXTERNAL_POISSON_RANDOM_BKGON_MIRMIRRORED` |
| `P055` | r | R | 2 | `mode_INTERNAL_POISSON_FIX_BKGON_MIRMIRRORED`, `lane_disabled_silent` |
| `P056` | r | R | 2 | `mode_INTERNAL_POISSON_FIX_BKGON_MIRMIRRORED`, `global_enable_gate` |
| `P057` | r | R | 2 | `mode_INTERNAL_POISSON_FIX_BKGON_MIRMIRRORED`, `runctl_trans_RUNNING_to_TERMINATING` |
| `P058` | r | R | 2 | `mode_INTERNAL_POISSON_FIX_BKGON_MIRMIRRORED`, `runctl_state_TERMINATING` |
| `P059` | r | R | 1 | `mode_EXTERNAL_POISSON_FIX_BKGON_MIRMIRRORED` |
| `P060` | d | D | 2 | `mode_EXTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED`, `lane_count_0_hits` |
| `P061` | r | R | 4 | `mode_INTERNAL_POISSON_FIX_BKGON_MIRMIRRORED`, `rate_max`, `noise_rate_max`, `engine_round_robin` |
| `P062` | r | R | 3 | `mode_INTERNAL_POISSON_FIX_BKGON_MIRMIRRORED`, `rate_max`, `noise_rate_low` |
| `P063` | r | R | 3 | `mode_INTERNAL_POISSON_FIX_BKGON_MIRMIRRORED`, `rate_low`, `noise_rate_max` |
| `P064` | r | R | 2 | `mode_INTERNAL_POISSON_FIX_BKGON_MIRMIRRORED`, `soak_1M` |
| `P065` | r | R | 2 | `cluster_size_1`, `type0_sop` |
| `P066` | r | R | 2 | `type0_sop`, `type0_eop` |
| `P067` | r | R | 1 | `byte_stream_active` |
| `P068` | r | R | 1 | `type0_vs_deassembly_parity` |
| `P069` | r | R | 3 | `mode_INTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED`, `rate_mid`, `soak_1M` |
| `P070` | r | R | 1 | `l2_fifo_depth_128` |
| `P071` | r | R | 1 | `lane_disabled_silent` |
| `P072` | r | R | 1 | `frame_boundary_at_inject` |
| `P073` | d | D | 2 | `type0_sop`, `type0_eop` |
| `P074` | d | D | 1 | `frame_empty` |
| `P075` | r | R | 1 | `runctl_state_TERMINATING` |
| `P076` | r | R | 1 | `type0_endofrun` |
| `P077` | r | R | 2 | `mode_INTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED`, `rate_mid` |
| `P078` | r | R | 2 | `mode_INTERNAL_PERIODIC_FIX_BKGOFF_MIRMIRRORED`, `rate_high` |
| `P079` | d | D | 2 | `frame_short_mode`, `frame_long_mode` |
| `P080` | d | D | 1 | `inject_during_sync_drop` |
| `P081` | d | D | 4 | `type0_vs_deassembly_parity`, `byte_stream_active`, `build_LC8_BS1`, `cluster_size_1` |
| `P082` | d | D | 4 | `type0_vs_deassembly_parity`, `byte_stream_active`, `build_LC8_BS1`, `cluster_size_32` |
| `P083` | r | R | 4 | `type0_vs_deassembly_parity`, `byte_stream_active`, `build_LC8_BS1`, `soak_1M` |
| `P084` | d | D | 4 | `type0_vs_deassembly_parity`, `byte_stream_active`, `build_LC8_BS1`, `cluster_size_256` |
| `P085` | d | D | 11 | `type0_vs_deassembly_parity`, `byte_stream_active`, `build_LC8_BS1`, `cluster_size_1`, `cluster_size_2`, `cluster_size_32`, `cluster_size_33`, `cluster_size_64`, `cluster_size_127`, `cluster_size_128`, `cluster_size_256` |
| `P086` | d | D | 4 | `type0_vs_deassembly_parity`, `byte_stream_active`, `build_LC8_BS1`, `mode_EXTERNAL_POISSON_FIX_BKGON_MIRMIRRORED` |
| `P087` | d | D | 4 | `type0_vs_deassembly_parity`, `byte_stream_active`, `build_LC8_BS1`, `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRMIRRORED` |
| `P088` | d | D | 4 | `type0_vs_deassembly_parity`, `byte_stream_active`, `build_LC8_BS1`, `frame_short_mode` |
| `P089` | d | D | 4 | `type0_vs_deassembly_parity`, `byte_stream_active`, `build_LC8_BS1`, `frame_long_mode` |
| `P090` | d | D | 4 | `type0_vs_deassembly_parity`, `byte_stream_active`, `build_LC8_BS1`, `frame_empty` |
| `P091` | d | D | 5 | `type0_vs_deassembly_parity`, `byte_stream_active`, `build_LC8_BS1`, `runctl_state_TERMINATING`, `type0_endofrun` |
| `P092` | d | D | 4 | `type0_vs_deassembly_parity`, `byte_stream_active`, `build_LC8_BS1`, `asic_id_base_nonzero` |
| `P093` | d | D | 5 | `type0_vs_deassembly_parity`, `byte_stream_active`, `build_LC8_BS1`, `type0_sop`, `type0_eop` |
| `P094` | d | D | 4 | `type0_vs_deassembly_parity`, `byte_stream_active`, `build_LC8_BS1`, `type0_error_inject_stub` |
| `P095` | d | D | 4 | `type0_vs_deassembly_parity`, `byte_stream_active`, `build_LC8_BS1`, `soak_1M` |
| `P096` | d | D | 4 | `type0_vs_deassembly_parity`, `byte_stream_active`, `build_LC8_BS1`, `build_LC4_BS1` |
| `P097` | d | D | 3 | `fire_w1p_singleshot`, `fire_csr_conduit_or`, `engine_back_to_back` |
| `P098` | d | D | 2 | `fire_edge_detect`, `engine_back_to_back` |
| `P099` | d | D | 2 | `fire_csr_conduit_or`, `engine_back_to_back` |
| `P100` | d | D | 2 | `fire_csr_conduit_or`, `fire_edge_detect` |
| `P101` | d | D | 2 | `fire_csr_conduit_or`, `engine_busy_high_water` |
| `P102` | d | D | 3 | `engine_back_to_back`, `ticket_overflow_count_inc`, `ticket_fifo_depth_8` |
| `P103` | d | D | 2 | `engine_busy_drops`, `ticket_overflow_count_inc` |
| `P104` | d | D | 2 | `fire_csr_conduit_or`, `internal_dropped_on_stall` |
| `P105` | d | D | 2 | `fire_csr_conduit_or`, `mode_EXTERNAL_POISSON_FIX_BKGON_MIRMIRRORED` |
| `P106` | d | D | 2 | `mode_EXTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED`, `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRMIRRORED` |
| `P107` | r | R | 2 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRMIRRORED`, `prng_seed_diverge` |
| `P108` | r | R | 2 | `fire_csr_conduit_or`, `rate_max` |
| `P109` | d | D | 1 | `fire_edge_detect` |
| `P110` | d | D | 1 | `inject_during_term_drop` |
| `P111` | d | D | 1 | `inject_during_sync_drop` |
| `P112` | d | D | 2 | `runctl_trans_SYNC_to_RUNNING`, `fire_csr_conduit_or` |
| `P113` | r | R | 2 | `all_buckets_frame_baseline`, `soak_1M` |
| `P114` | r | R | 2 | `all_buckets_frame_baseline`, `soak_10M` |
| `P115` | d | D | 2 | `all_buckets_frame_baseline`, `prng_seed_reproducibility` |
| `P116` | r | R | 2 | `all_buckets_frame_baseline`, `prng_seed_diverge` |
| `P117` | r | R | 2 | `all_buckets_frame_baseline`, `soak_1M` |
| `P118` | r | R | 2 | `all_buckets_frame_baseline`, `runctl_state_SYNC` |
| `P119` | r | R | 2 | `all_buckets_frame_baseline`, `runctl_trans_RUNNING_to_TERMINATING` |
| `P120` | r | R | 1 | `all_buckets_frame_baseline` |
| `P121` | r | R | 8 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRMIRRORED`, `mirror_offset_neg128`, `mirror_offset_neg32`, `mirror_offset_neg1`, `mirror_offset_zero0`, `mirror_offset_pos1`, `mirror_offset_pos32`, `mirror_offset_pos127` |
| `P122` | r | R | 2 | `mode_INTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED`, `mode_INTERNAL_POISSON_RANDOM_BKGOFF_MIRMIRRORED` |
| `P123` | r | R | 2 | `mode_INTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED`, `mode_EXTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED` |
| `P124` | r | R | 2 | `mode_INTERNAL_POISSON_FIX_BKGON_MIRMIRRORED`, `mode_INTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED` |
| `P125` | r | R | 2 | `all_buckets_frame_baseline`, `global_enable_gate` |
| `P126` | r | R | 2 | `lane_enable_mask_sweep`, `lane_disabled_silent` |
| `P127` | r | R | 49 | `all_buckets_frame_baseline`, `mode_INTERNAL_POISSON_FIX_BKGOFF_MIRLEFT_ONLY`, `mode_INTERNAL_POISSON_FIX_BKGOFF_MIRRIGHT_ONLY`, `mode_INTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED`, `mode_INTERNAL_POISSON_FIX_BKGON_MIRLEFT_ONLY`, `mode_INTERNAL_POISSON_FIX_BKGON_MIRRIGHT_ONLY`, `mode_INTERNAL_POISSON_FIX_BKGON_MIRMIRRORED`, `mode_INTERNAL_POISSON_RANDOM_BKGOFF_MIRLEFT_ONLY`, `mode_INTERNAL_POISSON_RANDOM_BKGOFF_MIRRIGHT_ONLY`, `mode_INTERNAL_POISSON_RANDOM_BKGOFF_MIRMIRRORED`, `mode_INTERNAL_POISSON_RANDOM_BKGON_MIRLEFT_ONLY`, `mode_INTERNAL_POISSON_RANDOM_BKGON_MIRRIGHT_ONLY`, `mode_INTERNAL_POISSON_RANDOM_BKGON_MIRMIRRORED`, `mode_INTERNAL_PERIODIC_FIX_BKGOFF_MIRLEFT_ONLY`, `mode_INTERNAL_PERIODIC_FIX_BKGOFF_MIRRIGHT_ONLY`, `mode_INTERNAL_PERIODIC_FIX_BKGOFF_MIRMIRRORED`, `mode_INTERNAL_PERIODIC_FIX_BKGON_MIRLEFT_ONLY`, `mode_INTERNAL_PERIODIC_FIX_BKGON_MIRRIGHT_ONLY`, `mode_INTERNAL_PERIODIC_FIX_BKGON_MIRMIRRORED`, `mode_INTERNAL_PERIODIC_RANDOM_BKGOFF_MIRLEFT_ONLY`, `mode_INTERNAL_PERIODIC_RANDOM_BKGOFF_MIRRIGHT_ONLY`, `mode_INTERNAL_PERIODIC_RANDOM_BKGOFF_MIRMIRRORED`, `mode_INTERNAL_PERIODIC_RANDOM_BKGON_MIRLEFT_ONLY`, `mode_INTERNAL_PERIODIC_RANDOM_BKGON_MIRRIGHT_ONLY`, `mode_INTERNAL_PERIODIC_RANDOM_BKGON_MIRMIRRORED`, `mode_EXTERNAL_POISSON_FIX_BKGOFF_MIRLEFT_ONLY`, `mode_EXTERNAL_POISSON_FIX_BKGOFF_MIRRIGHT_ONLY`, `mode_EXTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED`, `mode_EXTERNAL_POISSON_FIX_BKGON_MIRLEFT_ONLY`, `mode_EXTERNAL_POISSON_FIX_BKGON_MIRRIGHT_ONLY`, `mode_EXTERNAL_POISSON_FIX_BKGON_MIRMIRRORED`, `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRLEFT_ONLY`, `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRRIGHT_ONLY`, `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRMIRRORED`, `mode_EXTERNAL_POISSON_RANDOM_BKGON_MIRLEFT_ONLY`, `mode_EXTERNAL_POISSON_RANDOM_BKGON_MIRRIGHT_ONLY`, `mode_EXTERNAL_POISSON_RANDOM_BKGON_MIRMIRRORED`, `mode_EXTERNAL_PERIODIC_FIX_BKGOFF_MIRLEFT_ONLY`, `mode_EXTERNAL_PERIODIC_FIX_BKGOFF_MIRRIGHT_ONLY`, `mode_EXTERNAL_PERIODIC_FIX_BKGOFF_MIRMIRRORED`, `mode_EXTERNAL_PERIODIC_FIX_BKGON_MIRLEFT_ONLY`, `mode_EXTERNAL_PERIODIC_FIX_BKGON_MIRRIGHT_ONLY`, `mode_EXTERNAL_PERIODIC_FIX_BKGON_MIRMIRRORED`, `mode_EXTERNAL_PERIODIC_RANDOM_BKGOFF_MIRLEFT_ONLY`, `mode_EXTERNAL_PERIODIC_RANDOM_BKGOFF_MIRRIGHT_ONLY`, `mode_EXTERNAL_PERIODIC_RANDOM_BKGOFF_MIRMIRRORED`, `mode_EXTERNAL_PERIODIC_RANDOM_BKGON_MIRLEFT_ONLY`, `mode_EXTERNAL_PERIODIC_RANDOM_BKGON_MIRRIGHT_ONLY`, `mode_EXTERNAL_PERIODIC_RANDOM_BKGON_MIRMIRRORED` |
| `P128` | r | R | 2 | `all_buckets_frame_baseline`, `soak_100M` |

### 3.4 ERROR bucket bin ownership

| case_id | type (d/r) | promotion | n_bins | bins |
|---|---|---|---:|---|
| `X001` | d | D | 2 | `runctl_state_SYNC`, `cluster_size_32` |
| `X002` | d | D | 2 | `runctl_state_SYNC`, `mode_INTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED` |
| `X003` | d | D | 2 | `runctl_state_SYNC`, `mode_EXTERNAL_POISSON_FIX_BKGON_MIRMIRRORED` |
| `X004` | d | D | 2 | `runctl_state_SYNC`, `type0_sop` |
| `X005` | d | D | 2 | `runctl_state_SYNC`, `byte_stream_active` |
| `X006` | d | D | 2 | `runctl_state_SYNC`, `ticket_fifo_depth_8` |
| `X007` | d | D | 2 | `runctl_state_SYNC`, `l2_fifo_depth_192` |
| `X008` | d | D | 3 | `runctl_state_SYNC`, `tcc_seed_default`, `ecc_seed_default` |
| `X009` | d | D | 2 | `runctl_state_SYNC`, `engine_busy_high_water` |
| `X010` | d | D | 3 | `last_clear_on_irst`, `fifo_full_sticky_w1c`, `ticket_overflow_sticky_w1c` |
| `X011` | d | D | 3 | `runctl_state_SYNC`, `frame_count_lane0_32bit`, `hit_count_lane0_32bit` |
| `X012` | d | D | 2 | `runctl_state_SYNC`, `csr_atomic_write` |
| `X013` | d | D | 1 | `last_clear_on_irst` |
| `X014` | d | D | 2 | `runctl_state_SYNC`, `fire_csr_conduit_or` |
| `X015` | d | D | 1 | `runctl_state_SYNC` |
| `X016` | d | D | 2 | `runctl_trans_RUNNING_to_TERMINATING`, `runctl_state_SYNC` |
| `X017` | d | D | 1 | `runctl_illegal_multibit` |
| `X018` | d | D | 1 | `runctl_illegal_allzero` |
| `X019` | d | D | 1 | `runctl_state_RUNNING` |
| `X020` | d | D | 9 | `runctl_state_IDLE`, `runctl_state_RUN_PREPARE`, `runctl_state_SYNC`, `runctl_state_RUNNING`, `runctl_state_TERMINATING`, `runctl_state_LINK_TEST`, `runctl_state_SYNC_TEST`, `runctl_state_RESET`, `runctl_state_OUT_OF_DAQ` |
| `X021` | d | D | 1 | `runctl_state_SYNC` |
| `X022` | d | D | 1 | `runctl_state_RUNNING` |
| `X023` | d | D | 2 | `runctl_state_RUNNING`, `runctl_state_IDLE` |
| `X024` | d | D | 2 | `runctl_state_TERMINATING`, `runctl_state_RUNNING` |
| `X025` | d | D | 2 | `runctl_state_TERMINATING`, `runctl_state_SYNC` |
| `X026` | d | D | 2 | `runctl_state_LINK_TEST`, `runctl_trans_IDLE_to_LINK_TEST` |
| `X027` | d | D | 2 | `runctl_state_OUT_OF_DAQ`, `runctl_trans_IDLE_to_OUT_OF_DAQ` |
| `X028` | d | D | 1 | `runctl_state_SYNC` |
| `X029` | d | D | 2 | `runctl_state_RESET`, `last_clear_on_irst` |
| `X030` | d | D | 1 | `runctl_state_IDLE` |
| `X031` | d | D | 2 | `runctl_state_RUNNING`, `fire_csr_conduit_or` |
| `X032` | d | D | 1 | `runctl_state_RUNNING` |
| `X033` | d | D | 2 | `csr_during_irst`, `csr_addr_0x00` |
| `X034` | d | D | 2 | `csr_during_irst`, `csr_addr_0x07` |
| `X035` | d | D | 1 | `csr_during_sync` |
| `X036` | d | D | 2 | `csr_during_sync`, `csr_atomic_write` |
| `X037` | d | D | 1 | `csr_during_running` |
| `X038` | d | D | 2 | `csr_during_running`, `csr_addr_0x0C` |
| `X039` | d | D | 3 | `csr_addr_0x0A`, `frame_short_mode`, `frame_long_mode` |
| `X040` | d | D | 1 | `csr_addr_0x0F` |
| `X041` | d | D | 2 | `csr_addr_0x12`, `lane_disabled_silent` |
| `X042` | d | D | 2 | `csr_atomic_write`, `csr_atomic_read` |
| `X043` | d | D | 2 | `csr_during_irst`, `csr_access_OOR` |
| `X044` | d | D | 2 | `csr_addr_0x00`, `csr_access_RO` |
| `X045` | d | D | 3 | `csr_addr_0x13`, `csr_during_irst`, `fire_w1p_singleshot` |
| `X046` | d | D | 2 | `csr_addr_0x15`, `type0_error_inject_stub` |
| `X047` | d | D | 2 | `csr_during_running`, `runctl_state_TERMINATING` |
| `X048` | d | D | 1 | `csr_atomic_read` |
| `X049` | d | D | 2 | `ticket_fifo_depth_8`, `lane_disabled_silent` |
| `X050` | d | D | 3 | `ticket_fifo_depth_8`, `ticket_overflow_count_inc`, `ticket_overflow_sticky_set` |
| `X051` | d | D | 1 | `ticket_overflow_saturate` |
| `X052` | d | D | 2 | `ticket_fifo_depth_0`, `ticket_fifo_depth_8` |
| `X053` | d | D | 1 | `ticket_overflow_sticky_set` |
| `X054` | d | D | 2 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRMIRRORED`, `ticket_overflow_count_inc` |
| `X055` | d | D | 2 | `mode_EXTERNAL_POISSON_FIX_BKGON_MIRMIRRORED`, `ticket_overflow_count_inc` |
| `X056` | d | D | 2 | `mode_INTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED`, `internal_dropped_on_stall` |
| `X057` | d | D | 2 | `mode_EXTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED`, `ticket_overflow_count_inc` |
| `X058` | d | D | 1 | `ticket_overflow_sticky_w1c` |
| `X059` | d | D | 2 | `ticket_fifo_depth_8`, `ticket_fifo_depth_0` |
| `X060` | d | D | 1 | `ticket_fifo_depth_7` |
| `X061` | d | D | 1 | `ticket_fifo_depth_8` |
| `X062` | d | D | 2 | `ticket_fifo_depth_8`, `engine_busy_high_water` |
| `X063` | d | D | 1 | `last_clear_on_irst` |
| `X064` | d | D | 2 | `runctl_state_SYNC`, `ticket_overflow_count_inc` |
| `X065` | d | D | 1 | `l2_fifo_depth_256` |
| `X066` | d | D | 1 | `l2_fifo_depth_192` |
| `X067` | d | D | 2 | `l2_fifo_depth_128`, `ticket_fifo_depth_4` |
| `X068` | d | D | 3 | `l2_fifo_depth_256`, `ticket_fifo_depth_8`, `ticket_overflow_count_inc` |
| `X069` | d | D | 2 | `l2_fifo_depth_0`, `l2_fifo_depth_128` |
| `X070` | d | D | 2 | `runctl_state_SYNC`, `l2_fifo_depth_0` |
| `X071` | d | D | 2 | `runctl_state_TERMINATING`, `l2_fifo_depth_192` |
| `X072` | d | D | 2 | `fifo_full_sticky_set`, `l2_fifo_depth_256` |
| `X073` | d | D | 1 | `fifo_full_sticky_w1c` |
| `X074` | d | D | 2 | `byte_stream_active`, `l2_fifo_depth_128` |
| `X075` | d | D | 2 | `byte_stream_active`, `l2_fifo_depth_128` |
| `X076` | d | D | 1 | `l2_fifo_depth_256` |
| `X077` | d | D | 1 | `type0_sop` |
| `X078` | d | D | 1 | `l2_fifo_depth_192` |
| `X079` | d | D | 2 | `l2_fifo_depth_256`, `l2_fifo_depth_0` |
| `X080` | d | D | 1 | `l2_fifo_depth_64` |
| `X081` | d | D | 2 | `runctl_state_SYNC`, `frame_boundary_at_inject` |
| `X082` | d | D | 2 | `runctl_state_SYNC`, `l2_fifo_depth_64` |
| `X083` | d | D | 2 | `runctl_state_SYNC`, `type0_eop` |
| `X084` | d | D | 2 | `runctl_trans_RUNNING_to_TERMINATING`, `frame_boundary_at_inject` |
| `X085` | d | D | 2 | `runctl_trans_RUNNING_to_TERMINATING`, `frame_boundary_during_dispense` |
| `X086` | d | D | 2 | `runctl_state_IDLE`, `frame_boundary_during_dispense` |
| `X087` | d | D | 2 | `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRMIRRORED`, `frame_boundary_during_dispense` |
| `X088` | d | D | 2 | `mode_EXTERNAL_POISSON_FIX_BKGON_MIRMIRRORED`, `frame_boundary_at_inject` |
| `X089` | d | D | 2 | `frame_empty`, `frame_with_one_hit` |
| `X090` | d | D | 2 | `frame_at_event_max`, `frame_empty` |
| `X091` | d | D | 8 | `frame_count_lane0_32bit`, `frame_count_lane1_32bit`, `frame_count_lane2_32bit`, `frame_count_lane3_32bit`, `frame_count_lane4_32bit`, `frame_count_lane5_32bit`, `frame_count_lane6_32bit`, `frame_count_lane7_32bit` |
| `X092` | d | D | 8 | `hit_count_lane0_32bit`, `hit_count_lane1_32bit`, `hit_count_lane2_32bit`, `hit_count_lane3_32bit`, `hit_count_lane4_32bit`, `hit_count_lane5_32bit`, `hit_count_lane6_32bit`, `hit_count_lane7_32bit` |
| `X093` | d | D | 1 | `csr_lo_hi_atomic_snapshot` |
| `X094` | d | D | 2 | `lane_disabled_silent`, `lane_count_0_hits` |
| `X095` | d | D | 1 | `lane_reenabled_resume` |
| `X096` | d | D | 8 | `frame_count_lane0_60bit`, `frame_count_lane1_60bit`, `frame_count_lane2_60bit`, `frame_count_lane3_60bit`, `frame_count_lane4_60bit`, `frame_count_lane5_60bit`, `frame_count_lane6_60bit`, `frame_count_lane7_60bit` |
| `X097` | d | D | 2 | `csr_addr_0x02`, `csr_atomic_write` |
| `X098` | d | D | 2 | `csr_addr_0x02`, `csr_atomic_read` |
| `X099` | d | D | 2 | `csr_addr_0x0D`, `csr_atomic_write` |
| `X100` | d | D | 3 | `csr_addr_0x07`, `csr_addr_0x08`, `csr_atomic_write` |
| `X101` | d | D | 3 | `csr_addr_0x07`, `fire_csr_conduit_or`, `global_enable_gate` |
| `X102` | d | D | 2 | `csr_addr_0x07`, `global_enable_gate` |
| `X103` | d | D | 3 | `csr_addr_0x08`, `mode_EXTERNAL_POISSON_FIX_BKGOFF_MIRMIRRORED`, `mode_EXTERNAL_POISSON_RANDOM_BKGOFF_MIRMIRRORED` |
| `X104` | d | D | 3 | `csr_addr_0x0D`, `cluster_size_32`, `cluster_size_64` |
| `X105` | d | D | 2 | `fifo_full_sticky_w1c`, `fifo_full_sticky_set` |
| `X106` | d | D | 2 | `fire_csr_conduit_or`, `fire_w1p_singleshot` |
| `X107` | d | D | 2 | `last_rd_capture`, `csr_atomic_read` |
| `X108` | d | D | 1 | `csr_atomic_read` |
| `X109` | d | D | 2 | `csr_atomic_write`, `csr_atomic_read` |
| `X110` | d | D | 3 | `csr_addr_0x13`, `fire_w1p_singleshot`, `engine_back_to_back` |
| `X111` | d | D | 2 | `fifo_full_sticky_w1c`, `ticket_overflow_sticky_w1c` |
| `X112` | d | D | 2 | `csr_atomic_write`, `csr_atomic_read` |
| `X113` | d | D | 1 | `runctl_state_RUNNING` |
| `X114` | d | D | 1 | `runctl_state_RUNNING` |
| `X115` | d | D | 1 | `runctl_state_RUNNING` |
| `X116` | d | D | 1 | `runctl_state_RUNNING` |
| `X117` | d | D | 2 | `runctl_state_IDLE`, `runctl_state_RUNNING` |
| `X118` | d | D | 2 | `runctl_state_TERMINATING`, `runctl_state_RUNNING` |
| `X119` | d | D | 2 | `runctl_state_IDLE`, `runctl_state_RUNNING` |
| `X120` | d | D | 2 | `runctl_state_SYNC`, `frame_boundary_at_inject` |
| `X121` | d | D | 1 | `runctl_state_RESET` |
| `X122` | d | D | 2 | `fire_csr_conduit_or`, `runctl_trans_RUNNING_to_TERMINATING` |
| `X123` | d | D | 2 | `runctl_state_SYNC`, `engine_busy_high_water` |
| `X124` | d | D | 2 | `csr_during_running`, `runctl_state_RUNNING` |
| `X125` | d | D | 1 | `runctl_state_RUNNING` |
| `X126` | d | D | 1 | `runctl_illegal_multibit` |
| `X127` | d | D | 1 | `runctl_state_OUT_OF_DAQ` |
| `X128` | d | D | 1 | `runctl_state_RUNNING` |

## 4. Random Promotion Profiles

Every directed case is promoted into a constrained-random profile centred on its directed value for `bucket_frame` and `all_buckets_frame` execution. Random knob distributions are sampled with the LCG-based PRNG declared in `mutrig_common_pkg` (no SystemVerilog `rand`, per Questa FSE Starter Edition constraints).

Knob examples drawn from the case list:

- `B033` (Poisson hit_rate=0): promotes to `hit_rate ∈ [0, 0x000F]`, PRNG_SEED uniform over the 32-bit space.
- `B038` (Poisson hit_rate=0xFFFF): promotes to `hit_rate ∈ [0xF000, 0xFFFF]`.
- `B100` (mirror_offset=+5): promotes to `mirror_offset ∈ [+1, +8]` signed.
- `B101` (mirror_offset=-5): promotes to `mirror_offset ∈ [-8, -1]` signed.
- `P048` (BKG soak 1B cycles): promotes to `duration_cycles ∈ [5e8, 2e9]`.

The full per-case knob set is in [`cov_profiles.json`](cov_profiles.json) under `<case_id>.random_profile.knobs`.

## 5. Per-Bucket Tracking Tables

Each per-bucket table follows the dv-workflow §6 hard-format contract:

```
| case_id | type (d/r) | coverage_by_this_case | executed random txn | coverage_incr_per_txn |
```

These tables are auto-populated by the Questa FSE regression harness once cases run. Until UCDBs land, the per-bucket tables read `pending`.

### 5.1 BASIC bucket (B001-B128)

| case_id | type (d/r) | coverage_by_this_case | executed random txn | coverage_incr_per_txn |
|---|---|---|---:|---|
| `B001` | d | pending | 0 | pending |
| `B002` | r | pending | 0 | pending |
| `B003` | d | pending | 0 | pending |
| `B004` | d | pending | 0 | pending |
| `B005` | d | pending | 0 | pending |
| `B006` | d | pending | 0 | pending |
| `B007` | r | pending | 0 | pending |
| `B008` | r | pending | 0 | pending |
| `B009` | d | pending | 0 | pending |
| `B010` | d | pending | 0 | pending |
| `B011` | d | pending | 0 | pending |
| `B012` | d | pending | 0 | pending |
| `B013` | d | pending | 0 | pending |
| `B014` | d | pending | 0 | pending |
| `B015` | d | pending | 0 | pending |
| `B016` | d | pending | 0 | pending |
| `B017` | d | pending | 0 | pending |
| `B018` | d | pending | 0 | pending |
| `B019` | d | pending | 0 | pending |
| `B020` | d | pending | 0 | pending |
| `B021` | d | pending | 0 | pending |
| `B022` | d | pending | 0 | pending |
| `B023` | d | pending | 0 | pending |
| `B024` | d | pending | 0 | pending |
| `B025` | d | pending | 0 | pending |
| `B026` | d | pending | 0 | pending |
| `B027` | d | pending | 0 | pending |
| `B028` | d | pending | 0 | pending |
| `B029` | d | pending | 0 | pending |
| `B030` | d | pending | 0 | pending |
| `B031` | d | pending | 0 | pending |
| `B032` | d | pending | 0 | pending |
| `B033` | r | pending | 0 | pending |
| `B034` | r | pending | 0 | pending |
| `B035` | r | pending | 0 | pending |
| `B036` | r | pending | 0 | pending |
| `B037` | r | pending | 0 | pending |
| `B038` | r | pending | 0 | pending |
| `B039` | d | pending | 0 | pending |
| `B040` | r | pending | 0 | pending |
| `B041` | r | pending | 0 | pending |
| `B042` | r | pending | 0 | pending |
| `B043` | r | pending | 0 | pending |
| `B044` | r | pending | 0 | pending |
| `B045` | r | pending | 0 | pending |
| `B046` | r | pending | 0 | pending |
| `B047` | r | pending | 0 | pending |
| `B048` | r | pending | 0 | pending |
| `B049` | d | pending | 0 | pending |
| `B050` | d | pending | 0 | pending |
| `B051` | d | pending | 0 | pending |
| `B052` | d | pending | 0 | pending |
| `B053` | d | pending | 0 | pending |
| `B054` | d | pending | 0 | pending |
| `B055` | d | pending | 0 | pending |
| `B056` | d | pending | 0 | pending |
| `B057` | d | pending | 0 | pending |
| `B058` | d | pending | 0 | pending |
| `B059` | d | pending | 0 | pending |
| `B060` | d | pending | 0 | pending |
| `B061` | d | pending | 0 | pending |
| `B062` | d | pending | 0 | pending |
| `B063` | d | pending | 0 | pending |
| `B064` | d | pending | 0 | pending |
| `B065` | d | pending | 0 | pending |
| `B066` | d | pending | 0 | pending |
| `B067` | d | pending | 0 | pending |
| `B068` | d | pending | 0 | pending |
| `B069` | d | pending | 0 | pending |
| `B070` | d | pending | 0 | pending |
| `B071` | d | pending | 0 | pending |
| `B072` | d | pending | 0 | pending |
| `B073` | d | pending | 0 | pending |
| `B074` | d | pending | 0 | pending |
| `B075` | d | pending | 0 | pending |
| `B076` | d | pending | 0 | pending |
| `B077` | d | pending | 0 | pending |
| `B078` | d | pending | 0 | pending |
| `B079` | d | pending | 0 | pending |
| `B080` | d | pending | 0 | pending |
| `B081` | d | pending | 0 | pending |
| `B082` | d | pending | 0 | pending |
| `B083` | d | pending | 0 | pending |
| `B084` | d | pending | 0 | pending |
| `B085` | d | pending | 0 | pending |
| `B086` | d | pending | 0 | pending |
| `B087` | d | pending | 0 | pending |
| `B088` | d | pending | 0 | pending |
| `B089` | d | pending | 0 | pending |
| `B090` | d | pending | 0 | pending |
| `B091` | d | pending | 0 | pending |
| `B092` | d | pending | 0 | pending |
| `B093` | d | pending | 0 | pending |
| `B094` | d | pending | 0 | pending |
| `B095` | d | pending | 0 | pending |
| `B096` | d | pending | 0 | pending |
| `B097` | d | pending | 0 | pending |
| `B098` | d | pending | 0 | pending |
| `B099` | d | pending | 0 | pending |
| `B100` | r | pending | 0 | pending |
| `B101` | r | pending | 0 | pending |
| `B102` | d | pending | 0 | pending |
| `B103` | d | pending | 0 | pending |
| `B104` | d | pending | 0 | pending |
| `B105` | d | pending | 0 | pending |
| `B106` | d | pending | 0 | pending |
| `B107` | d | pending | 0 | pending |
| `B108` | r | pending | 0 | pending |
| `B109` | d | pending | 0 | pending |
| `B110` | d | pending | 0 | pending |
| `B111` | d | pending | 0 | pending |
| `B112` | r | pending | 0 | pending |
| `B113` | d | pending | 0 | pending |
| `B114` | d | pending | 0 | pending |
| `B115` | r | pending | 0 | pending |
| `B116` | r | pending | 0 | pending |
| `B117` | r | pending | 0 | pending |
| `B118` | d | pending | 0 | pending |
| `B119` | d | pending | 0 | pending |
| `B120` | d | pending | 0 | pending |
| `B121` | d | pending | 0 | pending |
| `B122` | d | pending | 0 | pending |
| `B123` | d | pending | 0 | pending |
| `B124` | d | pending | 0 | pending |
| `B125` | d | pending | 0 | pending |
| `B126` | r | pending | 0 | pending |
| `B127` | d | pending | 0 | pending |
| `B128` | d | pending | 0 | pending |

### 5.2 EDGE bucket (E001-E128)

| case_id | type (d/r) | coverage_by_this_case | executed random txn | coverage_incr_per_txn |
|---|---|---|---:|---|
| `E001` | d | pending | 0 | pending |
| `E002` | d | pending | 0 | pending |
| `E003` | d | pending | 0 | pending |
| `E004` | d | pending | 0 | pending |
| `E005` | d | pending | 0 | pending |
| `E006` | d | pending | 0 | pending |
| `E007` | d | pending | 0 | pending |
| `E008` | d | pending | 0 | pending |
| `E009` | d | pending | 0 | pending |
| `E010` | d | pending | 0 | pending |
| `E011` | d | pending | 0 | pending |
| `E012` | d | pending | 0 | pending |
| `E013` | d | pending | 0 | pending |
| `E014` | d | pending | 0 | pending |
| `E015` | d | pending | 0 | pending |
| `E016` | d | pending | 0 | pending |
| `E017` | d | pending | 0 | pending |
| `E018` | d | pending | 0 | pending |
| `E019` | d | pending | 0 | pending |
| `E020` | d | pending | 0 | pending |
| `E021` | d | pending | 0 | pending |
| `E022` | d | pending | 0 | pending |
| `E023` | d | pending | 0 | pending |
| `E024` | d | pending | 0 | pending |
| `E025` | d | pending | 0 | pending |
| `E026` | d | pending | 0 | pending |
| `E027` | d | pending | 0 | pending |
| `E028` | d | pending | 0 | pending |
| `E029` | d | pending | 0 | pending |
| `E030` | d | pending | 0 | pending |
| `E031` | d | pending | 0 | pending |
| `E032` | d | pending | 0 | pending |
| `E033` | d | pending | 0 | pending |
| `E034` | d | pending | 0 | pending |
| `E035` | d | pending | 0 | pending |
| `E036` | r | pending | 0 | pending |
| `E037` | d | pending | 0 | pending |
| `E038` | d | pending | 0 | pending |
| `E039` | d | pending | 0 | pending |
| `E040` | d | pending | 0 | pending |
| `E041` | d | pending | 0 | pending |
| `E042` | d | pending | 0 | pending |
| `E043` | r | pending | 0 | pending |
| `E044` | d | pending | 0 | pending |
| `E045` | d | pending | 0 | pending |
| `E046` | d | pending | 0 | pending |
| `E047` | d | pending | 0 | pending |
| `E048` | d | pending | 0 | pending |
| `E049` | d | pending | 0 | pending |
| `E050` | d | pending | 0 | pending |
| `E051` | d | pending | 0 | pending |
| `E052` | d | pending | 0 | pending |
| `E053` | d | pending | 0 | pending |
| `E054` | d | pending | 0 | pending |
| `E055` | d | pending | 0 | pending |
| `E056` | d | pending | 0 | pending |
| `E057` | d | pending | 0 | pending |
| `E058` | d | pending | 0 | pending |
| `E059` | d | pending | 0 | pending |
| `E060` | d | pending | 0 | pending |
| `E061` | d | pending | 0 | pending |
| `E062` | d | pending | 0 | pending |
| `E063` | d | pending | 0 | pending |
| `E064` | d | pending | 0 | pending |
| `E065` | d | pending | 0 | pending |
| `E066` | d | pending | 0 | pending |
| `E067` | d | pending | 0 | pending |
| `E068` | d | pending | 0 | pending |
| `E069` | d | pending | 0 | pending |
| `E070` | d | pending | 0 | pending |
| `E071` | d | pending | 0 | pending |
| `E072` | d | pending | 0 | pending |
| `E073` | d | pending | 0 | pending |
| `E074` | d | pending | 0 | pending |
| `E075` | d | pending | 0 | pending |
| `E076` | d | pending | 0 | pending |
| `E077` | d | pending | 0 | pending |
| `E078` | d | pending | 0 | pending |
| `E079` | d | pending | 0 | pending |
| `E080` | d | pending | 0 | pending |
| `E081` | d | pending | 0 | pending |
| `E082` | d | pending | 0 | pending |
| `E083` | d | pending | 0 | pending |
| `E084` | d | pending | 0 | pending |
| `E085` | d | pending | 0 | pending |
| `E086` | d | pending | 0 | pending |
| `E087` | d | pending | 0 | pending |
| `E088` | d | pending | 0 | pending |
| `E089` | d | pending | 0 | pending |
| `E090` | d | pending | 0 | pending |
| `E091` | d | pending | 0 | pending |
| `E092` | d | pending | 0 | pending |
| `E093` | d | pending | 0 | pending |
| `E094` | d | pending | 0 | pending |
| `E095` | d | pending | 0 | pending |
| `E096` | d | pending | 0 | pending |
| `E097` | d | pending | 0 | pending |
| `E098` | d | pending | 0 | pending |
| `E099` | d | pending | 0 | pending |
| `E100` | d | pending | 0 | pending |
| `E101` | d | pending | 0 | pending |
| `E102` | d | pending | 0 | pending |
| `E103` | d | pending | 0 | pending |
| `E104` | d | pending | 0 | pending |
| `E105` | d | pending | 0 | pending |
| `E106` | d | pending | 0 | pending |
| `E107` | d | pending | 0 | pending |
| `E108` | d | pending | 0 | pending |
| `E109` | d | pending | 0 | pending |
| `E110` | d | pending | 0 | pending |
| `E111` | d | pending | 0 | pending |
| `E112` | d | pending | 0 | pending |
| `E113` | d | pending | 0 | pending |
| `E114` | d | pending | 0 | pending |
| `E115` | d | pending | 0 | pending |
| `E116` | d | pending | 0 | pending |
| `E117` | d | pending | 0 | pending |
| `E118` | d | pending | 0 | pending |
| `E119` | d | pending | 0 | pending |
| `E120` | d | pending | 0 | pending |
| `E121` | d | pending | 0 | pending |
| `E122` | d | pending | 0 | pending |
| `E123` | d | pending | 0 | pending |
| `E124` | d | pending | 0 | pending |
| `E125` | d | pending | 0 | pending |
| `E126` | d | pending | 0 | pending |
| `E127` | d | pending | 0 | pending |
| `E128` | d | pending | 0 | pending |

### 5.3 PROF bucket (P001-P128)

| case_id | type (d/r) | coverage_by_this_case | executed random txn | coverage_incr_per_txn |
|---|---|---|---:|---|
| `P001` | r | pending | 0 | pending |
| `P002` | r | pending | 0 | pending |
| `P003` | r | pending | 0 | pending |
| `P004` | r | pending | 0 | pending |
| `P005` | r | pending | 0 | pending |
| `P006` | r | pending | 0 | pending |
| `P007` | r | pending | 0 | pending |
| `P008` | r | pending | 0 | pending |
| `P009` | r | pending | 0 | pending |
| `P010` | r | pending | 0 | pending |
| `P011` | r | pending | 0 | pending |
| `P012` | r | pending | 0 | pending |
| `P013` | r | pending | 0 | pending |
| `P014` | r | pending | 0 | pending |
| `P015` | r | pending | 0 | pending |
| `P016` | r | pending | 0 | pending |
| `P017` | d | pending | 0 | pending |
| `P018` | d | pending | 0 | pending |
| `P019` | d | pending | 0 | pending |
| `P020` | d | pending | 0 | pending |
| `P021` | d | pending | 0 | pending |
| `P022` | d | pending | 0 | pending |
| `P023` | d | pending | 0 | pending |
| `P024` | d | pending | 0 | pending |
| `P025` | d | pending | 0 | pending |
| `P026` | d | pending | 0 | pending |
| `P027` | d | pending | 0 | pending |
| `P028` | d | pending | 0 | pending |
| `P029` | d | pending | 0 | pending |
| `P030` | d | pending | 0 | pending |
| `P031` | d | pending | 0 | pending |
| `P032` | d | pending | 0 | pending |
| `P033` | r | pending | 0 | pending |
| `P034` | r | pending | 0 | pending |
| `P035` | r | pending | 0 | pending |
| `P036` | r | pending | 0 | pending |
| `P037` | r | pending | 0 | pending |
| `P038` | r | pending | 0 | pending |
| `P039` | r | pending | 0 | pending |
| `P040` | d | pending | 0 | pending |
| `P041` | r | pending | 0 | pending |
| `P042` | r | pending | 0 | pending |
| `P043` | r | pending | 0 | pending |
| `P044` | r | pending | 0 | pending |
| `P045` | r | pending | 0 | pending |
| `P046` | r | pending | 0 | pending |
| `P047` | r | pending | 0 | pending |
| `P048` | r | pending | 0 | pending |
| `P049` | r | pending | 0 | pending |
| `P050` | r | pending | 0 | pending |
| `P051` | r | pending | 0 | pending |
| `P052` | r | pending | 0 | pending |
| `P053` | r | pending | 0 | pending |
| `P054` | r | pending | 0 | pending |
| `P055` | r | pending | 0 | pending |
| `P056` | r | pending | 0 | pending |
| `P057` | r | pending | 0 | pending |
| `P058` | r | pending | 0 | pending |
| `P059` | r | pending | 0 | pending |
| `P060` | d | pending | 0 | pending |
| `P061` | r | pending | 0 | pending |
| `P062` | r | pending | 0 | pending |
| `P063` | r | pending | 0 | pending |
| `P064` | r | pending | 0 | pending |
| `P065` | r | pending | 0 | pending |
| `P066` | r | pending | 0 | pending |
| `P067` | r | pending | 0 | pending |
| `P068` | r | pending | 0 | pending |
| `P069` | r | pending | 0 | pending |
| `P070` | r | pending | 0 | pending |
| `P071` | r | pending | 0 | pending |
| `P072` | r | pending | 0 | pending |
| `P073` | d | pending | 0 | pending |
| `P074` | d | pending | 0 | pending |
| `P075` | r | pending | 0 | pending |
| `P076` | r | pending | 0 | pending |
| `P077` | r | pending | 0 | pending |
| `P078` | r | pending | 0 | pending |
| `P079` | d | pending | 0 | pending |
| `P080` | d | pending | 0 | pending |
| `P081` | d | pending | 0 | pending |
| `P082` | d | pending | 0 | pending |
| `P083` | r | pending | 0 | pending |
| `P084` | d | pending | 0 | pending |
| `P085` | d | pending | 0 | pending |
| `P086` | d | pending | 0 | pending |
| `P087` | d | pending | 0 | pending |
| `P088` | d | pending | 0 | pending |
| `P089` | d | pending | 0 | pending |
| `P090` | d | pending | 0 | pending |
| `P091` | d | pending | 0 | pending |
| `P092` | d | pending | 0 | pending |
| `P093` | d | pending | 0 | pending |
| `P094` | d | pending | 0 | pending |
| `P095` | d | pending | 0 | pending |
| `P096` | d | pending | 0 | pending |
| `P097` | d | pending | 0 | pending |
| `P098` | d | pending | 0 | pending |
| `P099` | d | pending | 0 | pending |
| `P100` | d | pending | 0 | pending |
| `P101` | d | pending | 0 | pending |
| `P102` | d | pending | 0 | pending |
| `P103` | d | pending | 0 | pending |
| `P104` | d | pending | 0 | pending |
| `P105` | d | pending | 0 | pending |
| `P106` | d | pending | 0 | pending |
| `P107` | r | pending | 0 | pending |
| `P108` | r | pending | 0 | pending |
| `P109` | d | pending | 0 | pending |
| `P110` | d | pending | 0 | pending |
| `P111` | d | pending | 0 | pending |
| `P112` | d | pending | 0 | pending |
| `P113` | r | pending | 0 | pending |
| `P114` | r | pending | 0 | pending |
| `P115` | d | pending | 0 | pending |
| `P116` | r | pending | 0 | pending |
| `P117` | r | pending | 0 | pending |
| `P118` | r | pending | 0 | pending |
| `P119` | r | pending | 0 | pending |
| `P120` | r | pending | 0 | pending |
| `P121` | r | pending | 0 | pending |
| `P122` | r | pending | 0 | pending |
| `P123` | r | pending | 0 | pending |
| `P124` | r | pending | 0 | pending |
| `P125` | r | pending | 0 | pending |
| `P126` | r | pending | 0 | pending |
| `P127` | r | pending | 0 | pending |
| `P128` | r | pending | 0 | pending |

### 5.4 ERROR bucket (X001-X128)

| case_id | type (d/r) | coverage_by_this_case | executed random txn | coverage_incr_per_txn |
|---|---|---|---:|---|
| `X001` | d | pending | 0 | pending |
| `X002` | d | pending | 0 | pending |
| `X003` | d | pending | 0 | pending |
| `X004` | d | pending | 0 | pending |
| `X005` | d | pending | 0 | pending |
| `X006` | d | pending | 0 | pending |
| `X007` | d | pending | 0 | pending |
| `X008` | d | pending | 0 | pending |
| `X009` | d | pending | 0 | pending |
| `X010` | d | pending | 0 | pending |
| `X011` | d | pending | 0 | pending |
| `X012` | d | pending | 0 | pending |
| `X013` | d | pending | 0 | pending |
| `X014` | d | pending | 0 | pending |
| `X015` | d | pending | 0 | pending |
| `X016` | d | pending | 0 | pending |
| `X017` | d | pending | 0 | pending |
| `X018` | d | pending | 0 | pending |
| `X019` | d | pending | 0 | pending |
| `X020` | d | pending | 0 | pending |
| `X021` | d | pending | 0 | pending |
| `X022` | d | pending | 0 | pending |
| `X023` | d | pending | 0 | pending |
| `X024` | d | pending | 0 | pending |
| `X025` | d | pending | 0 | pending |
| `X026` | d | pending | 0 | pending |
| `X027` | d | pending | 0 | pending |
| `X028` | d | pending | 0 | pending |
| `X029` | d | pending | 0 | pending |
| `X030` | d | pending | 0 | pending |
| `X031` | d | pending | 0 | pending |
| `X032` | d | pending | 0 | pending |
| `X033` | d | pending | 0 | pending |
| `X034` | d | pending | 0 | pending |
| `X035` | d | pending | 0 | pending |
| `X036` | d | pending | 0 | pending |
| `X037` | d | pending | 0 | pending |
| `X038` | d | pending | 0 | pending |
| `X039` | d | pending | 0 | pending |
| `X040` | d | pending | 0 | pending |
| `X041` | d | pending | 0 | pending |
| `X042` | d | pending | 0 | pending |
| `X043` | d | pending | 0 | pending |
| `X044` | d | pending | 0 | pending |
| `X045` | d | pending | 0 | pending |
| `X046` | d | pending | 0 | pending |
| `X047` | d | pending | 0 | pending |
| `X048` | d | pending | 0 | pending |
| `X049` | d | pending | 0 | pending |
| `X050` | d | pending | 0 | pending |
| `X051` | d | pending | 0 | pending |
| `X052` | d | pending | 0 | pending |
| `X053` | d | pending | 0 | pending |
| `X054` | d | pending | 0 | pending |
| `X055` | d | pending | 0 | pending |
| `X056` | d | pending | 0 | pending |
| `X057` | d | pending | 0 | pending |
| `X058` | d | pending | 0 | pending |
| `X059` | d | pending | 0 | pending |
| `X060` | d | pending | 0 | pending |
| `X061` | d | pending | 0 | pending |
| `X062` | d | pending | 0 | pending |
| `X063` | d | pending | 0 | pending |
| `X064` | d | pending | 0 | pending |
| `X065` | d | pending | 0 | pending |
| `X066` | d | pending | 0 | pending |
| `X067` | d | pending | 0 | pending |
| `X068` | d | pending | 0 | pending |
| `X069` | d | pending | 0 | pending |
| `X070` | d | pending | 0 | pending |
| `X071` | d | pending | 0 | pending |
| `X072` | d | pending | 0 | pending |
| `X073` | d | pending | 0 | pending |
| `X074` | d | pending | 0 | pending |
| `X075` | d | pending | 0 | pending |
| `X076` | d | pending | 0 | pending |
| `X077` | d | pending | 0 | pending |
| `X078` | d | pending | 0 | pending |
| `X079` | d | pending | 0 | pending |
| `X080` | d | pending | 0 | pending |
| `X081` | d | pending | 0 | pending |
| `X082` | d | pending | 0 | pending |
| `X083` | d | pending | 0 | pending |
| `X084` | d | pending | 0 | pending |
| `X085` | d | pending | 0 | pending |
| `X086` | d | pending | 0 | pending |
| `X087` | d | pending | 0 | pending |
| `X088` | d | pending | 0 | pending |
| `X089` | d | pending | 0 | pending |
| `X090` | d | pending | 0 | pending |
| `X091` | d | pending | 0 | pending |
| `X092` | d | pending | 0 | pending |
| `X093` | d | pending | 0 | pending |
| `X094` | d | pending | 0 | pending |
| `X095` | d | pending | 0 | pending |
| `X096` | d | pending | 0 | pending |
| `X097` | d | pending | 0 | pending |
| `X098` | d | pending | 0 | pending |
| `X099` | d | pending | 0 | pending |
| `X100` | d | pending | 0 | pending |
| `X101` | d | pending | 0 | pending |
| `X102` | d | pending | 0 | pending |
| `X103` | d | pending | 0 | pending |
| `X104` | d | pending | 0 | pending |
| `X105` | d | pending | 0 | pending |
| `X106` | d | pending | 0 | pending |
| `X107` | d | pending | 0 | pending |
| `X108` | d | pending | 0 | pending |
| `X109` | d | pending | 0 | pending |
| `X110` | d | pending | 0 | pending |
| `X111` | d | pending | 0 | pending |
| `X112` | d | pending | 0 | pending |
| `X113` | d | pending | 0 | pending |
| `X114` | d | pending | 0 | pending |
| `X115` | d | pending | 0 | pending |
| `X116` | d | pending | 0 | pending |
| `X117` | d | pending | 0 | pending |
| `X118` | d | pending | 0 | pending |
| `X119` | d | pending | 0 | pending |
| `X120` | d | pending | 0 | pending |
| `X121` | d | pending | 0 | pending |
| `X122` | d | pending | 0 | pending |
| `X123` | d | pending | 0 | pending |
| `X124` | d | pending | 0 | pending |
| `X125` | d | pending | 0 | pending |
| `X126` | d | pending | 0 | pending |
| `X127` | d | pending | 0 | pending |
| `X128` | d | pending | 0 | pending |

## 6. Execution-Mode Baselines

| mode | scope | run_id pattern | status |
|---|---|---|---|
| `isolated` | 512 cases × per-case UCDB | `emut_<case_id>_isolated_s<seed>.ucdb` | pending |
| `bucket_frame` | one bucket end-to-end with promoted knobs | `emut_<bucket>_frame_s<seed>.ucdb` | pending |
| `all_buckets_frame` | BASIC→EDGE→PROF→ERROR in one timeframe | `emut_all_buckets_frame_s<seed>.ucdb` | pending |

## 7. Build Axes Coverage

| LANE_COUNT | BYTE_STREAM_ENABLE | bin | gated for 26.2.x signoff |
|---:|---:|---|---|
| 1 | 0 | `build_LC1_BS0` | reported only |
| 1 | 1 | `build_LC1_BS1` | reported only |
| 2 | 0 | `build_LC2_BS0` | reported only |
| 2 | 1 | `build_LC2_BS1` | reported only |
| 4 | 0 | `build_LC4_BS0` | reported only |
| 4 | 1 | `build_LC4_BS1` | reported only |
| 8 | 0 | `build_LC8_BS0` | yes |
| 8 | 1 | `build_LC8_BS1` | yes |

_Regenerate with the build script in `tb/scripts/build_cov_profiles.py` (mirrors `/tmp/emu_cov_build/build_cov.py` snapshot)._
