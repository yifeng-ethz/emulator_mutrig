# WORK_LOG - emulator_mutrig central trigger RTL refresh

Date: 2026-05-02

Scope: RTL refresh only. UVM work was not started.

## Files Created

- `WORK_LOG.md`
- `emulator_mutrig_central_trigger.f`
- `emulator_mutrig_central_trigger_syn.f`
- `rtl/deprecated/README.md`

## Files Created Or Updated By The Refresh

- `rtl/backend_mupix/README.md`
- `rtl/legacy/README.md`
- `rtl/common/frontend_ticket_bus_pkg.sv`
- `rtl/common/prbs15_lfsr.sv`
- `rtl/common/crc16_8.sv`
- `rtl/frontend/frontend_csr.sv`
- `rtl/frontend/frontend_run_ctl.sv`
- `rtl/frontend/frontend_trigger_engine.sv`
- `rtl/frontend/frontend_bkg_generator.sv`
- `rtl/frontend/frontend_ticket_distributor.sv`
- `rtl/backend_mutrig/be_mutrig_pkg.sv`
- `rtl/backend_mutrig/be_mutrig_l2_fifo.sv`
- `rtl/backend_mutrig/be_mutrig_lane_emitter.sv`
- `rtl/backend_mutrig/be_mutrig_lane_type0_emit.sv`
- `rtl/backend_mutrig/be_mutrig_frame_assembler.sv`
- `rtl/emulator_mutrig.sv`
- `syn/quartus/emulator_mutrig_syn.qsf`
- `syn/quartus/emulator_mutrig_syn_top.sv`

## Tests Passed

- PASS: `vlog -work work_central_trigger_final -sv -f emulator_mutrig_central_trigger.f` with 0 errors and 5 warnings.
- PASS: `vlog -work work_central_trigger_syn_final -sv -f emulator_mutrig_central_trigger_syn.f` with 0 errors and 5 warnings.
- PASS: `git diff --check`.
- PASS: full RTL static gate, `questa_static_screen.py --top emulator_mutrig --filelist emulator_mutrig_central_trigger.f --modes lint,cdc,rdc,formal`, transcript `.questa_static_screen/central_trigger_all_final/questa_static_screen.log`.
- PASS: per-file static gate for `frontend_ticket_bus_pkg`, transcript `.questa_static_screen/per_file_frontend_ticket_bus_pkg/questa_static_screen.log`.
- PASS: per-file static gate for `be_mutrig_pkg`, transcript `.questa_static_screen/per_file_be_mutrig_pkg/questa_static_screen.log`.
- PASS: per-file static gate for `prbs15_lfsr`, transcript `.questa_static_screen/per_file_prbs15_lfsr/questa_static_screen.log`.
- PASS: per-file static gate for `crc16_8`, transcript `.questa_static_screen/per_file_crc16_8/questa_static_screen.log`.
- PASS: per-file static gate for `frontend_csr`, transcript `.questa_static_screen/per_file_frontend_csr_final/questa_static_screen.log`.
- PASS: per-file static gate for `frontend_run_ctl`, transcript `.questa_static_screen/per_file_frontend_run_ctl/questa_static_screen.log`.
- PASS: per-file static gate for `frontend_trigger_engine`, transcript `.questa_static_screen/per_file_frontend_trigger_engine/questa_static_screen.log`.
- PASS: per-file static gate for `frontend_bkg_generator`, transcript `.questa_static_screen/per_file_frontend_bkg_generator/questa_static_screen.log`.
- PASS: per-file static gate for `frontend_ticket_distributor`, transcript `.questa_static_screen/per_file_frontend_ticket_distributor/questa_static_screen.log`.
- PASS: per-file static gate for `be_mutrig_l2_fifo`, transcript `.questa_static_screen/per_file_be_mutrig_l2_fifo/questa_static_screen.log`.
- PASS: per-file static gate for `be_mutrig_lane_emitter`, transcript `.questa_static_screen/per_file_be_mutrig_lane_emitter_rerun/questa_static_screen.log`.
- PASS: per-file static gate for `be_mutrig_lane_type0_emit`, transcript `.questa_static_screen/per_file_be_mutrig_lane_type0_emit_rerun/questa_static_screen.log`.
- PASS: per-file static gate for `be_mutrig_frame_assembler`, transcript `.questa_static_screen/per_file_be_mutrig_frame_assembler_rerun/questa_static_screen.log`.
- PASS: per-file static gate for `emulator_mutrig`, transcript `.questa_static_screen/per_file_emulator_mutrig_rerun/questa_static_screen.log`.
- PASS: synthesis wrapper static gate split by mode:
  `lint` at `.questa_static_screen/syn_wrapper_lint_only_final/questa_static_screen.log`,
  `cdc` at `.questa_static_screen/syn_wrapper_cdc_only_final/questa_static_screen.log`,
  `rdc` at `.questa_static_screen/syn_wrapper_rdc_only_final/questa_static_screen.log`,
  `formal` at `.questa_static_screen/syn_wrapper_formal_only_final/questa_static_screen.log`.

## Open Issues

- `lint_ip_structure.py .` still fails because the checker conflicts with locked user decisions and existing repo layout: it rejects `rtl/emulator_mutrig.sv` at the RTL root, prefers `rtl/deprecated/` over the requested `rtl/legacy/`, rejects root `WORK_LOG.md`, and reports pre-existing root/TB Markdown layout issues plus `tb/scripts` and missing `tb/uvm/log`.
- A combined four-mode `questa_static_screen.py` run on `emulator_mutrig_syn_top` fails in `rdc` after `cdc` with `parser-341` losing the wrapper design unit. The same wrapper filelist passes `lint`, `cdc`, `rdc`, and `formal` when those modes are run separately, and the real RTL top passes all four modes in one run.
- `emulator_mutrig_hw.tcl` still describes the pre-refresh packaging/CSR surface. The RTL CSR implements the golden 0x00..0x06 header, but packaging refresh is outside this RTL-only stop point.
