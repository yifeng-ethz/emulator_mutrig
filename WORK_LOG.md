# WORK_LOG - emulator_mutrig central trigger RTL refresh

Date: 2026-05-02

## Files Created Or Rewritten

- `rtl/legacy/README.md` - legacy RTL deprecation note.
- `rtl/backend_mupix/README.md` - placeholder for the future MuPix backend.
- `rtl/common/frontend_ticket_bus_pkg.sv` - FE/BE ticket bus package.
- `rtl/common/prbs15_lfsr.sv` - PRBS-15 LFSR with parameterized reset seed.
- `rtl/common/crc16_8.sv` - common CRC-16/8 module moved out of legacy.
- `rtl/frontend/frontend_csr.sv` - golden-header CSR bank and mode/status map.
- `rtl/frontend/frontend_run_ctl.sv` - run-control decode and inject merge.
- `rtl/frontend/frontend_trigger_engine.sv` - central SIGNAL engine and RR dispatch.
- `rtl/frontend/frontend_bkg_generator.sv` - folded IID background generator.
- `rtl/frontend/frontend_ticket_distributor.sv` - signal/background arbitration onto per-lane ticket bus.
- `rtl/backend_mutrig/be_mutrig_pkg.sv` - MuTRiG constants, PRBS helpers, and packers.
- `rtl/backend_mutrig/be_mutrig_l2_fifo.sv` - 256x48 per-lane L2 FIFO wrapper.
- `rtl/backend_mutrig/be_mutrig_lane_emitter.sv` - ticket FIFO, hit packer, L2 writer, and counters.
- `rtl/backend_mutrig/be_mutrig_lane_type0_emit.sv` - direct 45-bit type0 AvST source.
- `rtl/backend_mutrig/be_mutrig_frame_assembler.sv` - optional 8b/1k frame assembler.
- `rtl/emulator_mutrig.sv` - refreshed central-trigger top.
- `rtl/emulator_mutrig_26_2.f` - RTL static-screen filelist for the refreshed tree.
- `WORK_LOG.md` - this status log.

## Static Gate Results

Final integrated gate:

- PASS: `python3 ~/.codex/skills/rtl-linter-and-checker/scripts/questa_static_screen.py --top emulator_mutrig --filelist rtl/emulator_mutrig_26_2.f --modes lint,cdc,rdc,formal ...`
- Transcript: `.questa_static_screen/emulator_mutrig_final_after_abi/questa_static_screen.log`

Per-file/module evidence:

- PASS: `frontend_ticket_bus_pkg`, transcript `.questa_static_screen/frontend_ticket_bus_pkg/questa_static_screen.log`
- PASS: `prbs15_lfsr`, transcript `.questa_static_screen/prbs15_lfsr/questa_static_screen.log`
- PASS: `crc16_8`, transcript `.questa_static_screen/crc16_8/questa_static_screen.log`
- PASS: `frontend_csr`, transcript `.questa_static_screen/frontend_csr/questa_static_screen.log`
- PASS: `frontend_run_ctl`, transcript `.questa_static_screen/per_file_frontend_run_ctl/questa_static_screen.log`
- PASS: `frontend_trigger_engine`, transcript `.questa_static_screen/frontend_trigger_engine/questa_static_screen.log`
- PASS: `frontend_bkg_generator`, transcript `.questa_static_screen/per_file_frontend_bkg_generator/questa_static_screen.log`
- PASS: `frontend_ticket_distributor`, transcript `.questa_static_screen/frontend_ticket_distributor_current/questa_static_screen.log`
- PASS: `be_mutrig_pkg`, transcript `.questa_static_screen/be_mutrig_pkg/questa_static_screen.log`
- PASS: `be_mutrig_l2_fifo`, transcript `.questa_static_screen/per_file_be_mutrig_l2_fifo/questa_static_screen.log`
- PASS: `be_mutrig_lane_emitter`, transcript `.questa_static_screen/be_mutrig_lane_emitter_current_clean/questa_static_screen.log`
- PASS: `be_mutrig_lane_type0_emit`, transcript `.questa_static_screen/be_mutrig_lane_type0_emit_current/questa_static_screen.log`
- PASS: `be_mutrig_frame_assembler`, transcript `.questa_static_screen/be_mutrig_frame_assembler_current/questa_static_screen.log`
- PASS: `emulator_mutrig`, transcript `.questa_static_screen/emulator_mutrig_final_after_abi/questa_static_screen.log`

Resolved failed attempts:

- FAIL then PASS: `.questa_static_screen/frontend_bkg_generator/questa_static_screen.log` failed while `frontend_csr.sv` was not yet present; rerun passed at `.questa_static_screen/per_file_frontend_bkg_generator/questa_static_screen.log`.
- FAIL then PASS: `.questa_static_screen/frontend_run_ctl/questa_static_screen.log` reported an early CDC primary-port issue; rerun passed at `.questa_static_screen/per_file_frontend_run_ctl/questa_static_screen.log`.
- FAIL then PASS: `.questa_static_screen/be_mutrig_lane_emitter_current/questa_static_screen.log` hit stale qverify package-library state; rerun after clearing generated `work/` passed at `.questa_static_screen/be_mutrig_lane_emitter_current_clean/questa_static_screen.log`.

Additional checks:

- PASS: `git diff --check`
- FAIL: `python3 ~/.codex/skills/ip-packaging/scripts/lint_csr_header.py --profile golden emulator_mutrig_hw.tcl`
- FAIL: `python3 ~/.codex/skills/rtl-file-structure-organization/scripts/lint_ip_structure.py .`

## Open Issues

- `emulator_mutrig_hw.tcl` still describes the pre-refresh CSR map and does not pass the golden CSR packaging lint. The RTL CSR implements the golden header; packaging refresh is a separate follow-up.
- The repo-wide structure checker conflicts with the user-requested layout by flagging `rtl/emulator_mutrig.sv` at the RTL root and preferring `rtl/deprecated/` over the requested `rtl/legacy/`; it also reports pre-existing root and `tb/` Markdown layout issues.
- UVM/regression work was not started in this session by request.
