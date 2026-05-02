# tb_int — emulator_mutrig integration testbench

This directory holds the integration-level DV harness for the
`emulator_mutrig` 26.2.x central-trigger refresh. The integration
target is the FE SciFi datapath path inside the Mu3e
`scifi_datapath_system_v3_pipe.qsys` Qsys system at
`firmware_builds/systems/system_20260427_testplanphase5/syn/`.

This is a **separate DV scope** from the standalone `tb/` (which
proves the IP in isolation). Cases here exercise the IP only at its
Qsys boundary against the surrounding integration: run-control sink,
CSR aperture via the `sc_hub` slow-control fan-out, hit_type0
consumption by `mutrig_timestamp_processor` and the downstream
`packet_scheduler` / `ring_buffer_cam` chain.

## Layout

```
tb_int/
├── README.md           this file
├── DV_PLAN.md          integration verification plan + scope
├── DV_HARNESS.md       integration harness architecture (drivers, monitors, scoreboard)
├── DV_BASIC.md         32 directed bring-up cases (T001..T032)
├── DV_REPORT.md        integration sign-off dashboard
├── BUG_HISTORY.md      integration bug ledger
├── doc/                derived integration docs
├── script/             Makefile + helper scripts
├── uvm/                UVM agents + sequences (log -> /data3)
└── REPORT/             per-case evidence
```

## Companion docs

- Standalone DV: [`../tb/DV_PLAN.md`](../tb/DV_PLAN.md), [`../tb/DV_REPORT.md`](../tb/DV_REPORT.md)
- RTL plan: [`../doc/RTL_PLAN_central_trigger.md`](../doc/RTL_PLAN_central_trigger.md)
- Standalone synthesis: [`../syn/SYN_REPORT.md`](../syn/SYN_REPORT.md)
