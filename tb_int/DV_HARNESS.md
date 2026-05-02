# tb_int DV — Harness Architecture

**Companion docs:** [DV_PLAN.md](DV_PLAN.md), [DV_BASIC.md](DV_BASIC.md), [DV_REPORT.md](DV_REPORT.md)

## Topology

```
                    +-------------------------+
                    | run_control_mgmt host   |
                    +-----------+-------------+
                                | ctrl AvST
+--------------+  CSR  +--------v---------+   +--------------------+
| csr_agent    |------>| sc_hub aperture  |-->| emulator_mutrig    |
|  (AVMM)      |       +------------------+   |  v26.2.x (8 lanes) |
+--------------+                              +-+------------------+
                                                |  hit_type0 x 8 lanes
                  conduit inject_pulse          v
+--------------+  -------------------->+---------------------------+
| inject_drv   |                       | mutrig_timestamp_processor|
| (mutrig_     |                       +-------------+-------------+
|  injector)   |                                     | type1
+--------------+                                     v
                                          +--------------------+
                                          | packet_scheduler   |
                                          +-------+------------+
                                                  | type2
                                                  v
                                          +--------------------+
                                          | ring_buffer_cam    |
                                          +-------+------------+
                                                  v
                                          +--------------------+
                                          | upload_*  monitor  |
                                          +--------------------+
```

## UVM Agents

Driving agents (UVC-style, attached at Qsys boundaries):

- **`runctl_agent`**: drives `asi_ctrl_data` 9-bit one-hot run-control words to the system's run-control sink. Models the `run_control_mgmt` host.
- **`csr_agent`**: AVMM master at the `sc_hub` slow-control aperture. Generates word-level reads/writes against the emulator's CSR window.
- **`inject_agent`**: drives the `coe_inject_pulse` conduit by toggling the `mutrig_injector` charge-injection trigger.

Listening agents (sinks at Qsys boundaries):

- **`hit_type0_monitor` × 8**: passive monitor on each per-lane `aso_hit_type0_*` source from the emulator. Captures `(asic_id, channel, TCC, T_Fine, ECC, E_Flag, sop, eop, endofrun, error)`.
- **`mts_monitor`**: monitor on the `mutrig_timestamp_processor` output (`type1` stream). Captures decoded GTS for parity comparison.
- **`packet_scheduler_monitor`**: monitor on the packet-scheduler output (`type2` stream).
- **`upload_monitor`**: terminal sink with ready always asserted; counts complete packets received.

## Scoreboard

The scoreboard cross-references:

1. Each ticket published by `inject_agent` or each launch decision predicted from the CSR config (PRNG seed + hit_rate + cluster mode) → expected per-lane hit count and TCC anchor.
2. Each `hit_type0` beat seen by the per-lane monitors → recorded against the prediction.
3. Each MTS decode → recorded against the type0 stream (TCC sequence stays monotonic per the PRBS-15 epoch).
4. Each packet at the upload monitor → counted vs the bank `lane_hit_count` CSR readback.

## Run modes

- **isolated** — one case per simulation, fresh DUT start, per-case UCDB.
- **bucket_frame** — all 32 BASIC cases run in one timeframe with the `random_profile` scatter (per [`../tb/cov_profiles.json`](../tb/cov_profiles.json)) so coverage delta accumulates.
- **all_buckets_frame** — same as bucket_frame for now, since only BASIC exists.

## License setup

Per `/home/yifeng/CLAUDE.md`, this harness uses:

- **Questa FSE Starter 2022.4** at `/data1/intelFPGA_pro/23.1/questa_fse/`
- License file `LR-287689_License.dat` (primary), ETH Mentor floating server (fallback)
- No `rand`, no `covergroup`, no DPI — LCG PRNG inside `mutrig_common_pkg`
