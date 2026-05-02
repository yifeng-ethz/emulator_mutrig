# Open Issues

## TL;DR

Three blocking-ish items: standalone Quartus timing fails by 2.573 ns at
125 MHz, ALMs over budget by 14%, and the packaged `_hw.tcl` still
describes the legacy single-lane shape. Five smaller follow-ups around
DV closure, the formal harness invocation, the second build axis point,
the `_hw.tcl` refresh, and the integration tb_int wiring.

## Why this exists

Tracking known gaps in one place makes it easy to scope the next
patch and lets a reviewer see at a glance what is and isn't ready
for sign-off.

## How it works

### Blocking for sign-off

| # | Issue | Severity | Mitigation |
|---|---|---|---|
| 1 | Timing fails by `-2.573 ns` at 125 MHz on the primary build | <span class="tag bad">blocker</span> | Pipeline `frontend_trigger_engine` cluster decode over 2 cycles |
| 2 | ALMs `4557` (target `< 4000`) | <span class="tag warn">over by 14%</span> | Shrink lane ticket FIFO 8→4 (`-320 ALM`); share per-lane 64-bit counters via MLAB (`-120 ALM`) |
| 3 | `emulator_mutrig_hw.tcl` describes legacy single-lane shape | <span class="tag bad">blocker for Qsys integration</span> | Rewrite via the `ip-packaging` skill (next codex2 deliverable) |

### Follow-ups (non-blocking)

| # | Issue | Severity | Notes |
|---|---|---|---|
| 4 | UVM testbench not yet wired (case skeletons exist) | <span class="tag warn">required for DV evidence</span> | Codex2 dispatch queued; uses `tb/uvm/cov_profile_loader.svh` |
| 5 | SVA bind harness compiles but won't auto-fire under `qverify` static gate | <span class="tag info">documented</span> | Bind container needs UVM TB top to instantiate; no fix needed for the static gate |
| 6 | Compatibility build `(LANE_COUNT=8, BYTE_STREAM_ENABLE=1)` not compiled | <span class="tag info">pending</span> | Add second Quartus revision and rerun |
| 7 | Reduced lane-count points `LANE_COUNT in {1, 2, 4}` not compiled | <span class="tag info">informational</span> | Defer until primary point closes |
| 8 | `tb_int/` is a skeleton; no UVM wiring against `scifi_datapath_system_v3_pipe.qsys` yet | <span class="tag warn">required for integration evidence</span> | Pre-requires `_hw.tcl` refresh (issue #3) and the hardware access (currently pending) |

### Recently resolved (for context)

- `import pkg::*;` in module port-list position rejected by Quartus
  18.1 Standard (error 10170) — fixed by moving imports into module
  body and fully qualifying port types (commit `98aae1c`).
- `tb/scripts/` → `tb/script/` rename per the
  rtl-file-structure-organization linter (commit `f0fcc6d`).
- Root-level Markdown (`WORK_LOG.md`, `IP_PACKAGING_GAP_REVIEW.md`,
  `SIGNOFF.md`) moved into `doc/`.

## Interfaces and contracts

- This page is the sign-off-readiness dashboard. Anything marked
  `blocker` must clear before a release tag.
- `warn` items can ship if explicitly waived in `tb/DV_REPORT.md` and
  `syn/SYN_REPORT.md` non-claims sections.

## Where to look in the code

- Sign-off dashboard: `syn/SYN_REPORT.md`, `tb/DV_REPORT.md`
- Bug ledger: `tb/BUG_HISTORY.md`
- Plan: `doc/RTL_PLAN_central_trigger.md` §8 (open items)

## Open questions / gotchas

- The `_hw.tcl` refresh (issue #3) is the long pole for everything
  downstream that wants to consume the new IP via Qsys. Without it,
  integration systems must reference the RTL directly via QSF source
  inclusion rather than as a packaged Qsys component.
- Per the user's earlier note, the standalone DV is the gating scope
  for the current checkpoint; integration `tb_int` evidence is
  deferred until lab access opens up.
