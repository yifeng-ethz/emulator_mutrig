# emulator_mutrig IP Packaging Gap Review

Date: 2026-04-12

Current worktree note:
- The present local tree already includes a partial inject-path upgrade: `emulator_mutrig_hw.tcl` now declares an `inject` conduit, and the RTL synchronizes `coe_inject_pulse` into `hit_generator`.
- The present local tree also already bumps `set_module_property VERSION` to `26.0.1.0410`, while the numeric identity defaults still encode patch `0`.

Reviewed against:
- `/home/yifeng/.claude/skills/ip-packaging/SKILL.md`
- `histogram_statistics/histogram_statistics_v2_hw.tcl`
- `histogram_statistics/rtl/histogram_statistics_v2.vhd`
- `slow-control_hub/sc_hub_v2_hw.tcl`
- `slow-control_hub/hw_tcl/sc_hub_v2_params.tcl`

## Overall Assessment

`emulator_mutrig` is partially upgraded to the Mu3e IP packaging standard, but it is not yet 100% compliant.

What is already in good shape:
- The required four top-level tabs exist: `Configuration`, `Identity`, `Interfaces`, `Register Map`.
- The `_hw.tcl` uses the standard `add_html_text` helper and `compute_derived_values` callback pattern.
- The CSR register window is documented and all current multi-field words have field tables.
- The main streaming interface `tx8b1k` is documented with a bit table.
- The component now declares an `inject` conduit and the RTL contains a synchronized injection-pulse hook into the hit generator.

What blocks full compliance:
- Version information is not sourced from one set of constants and is currently inconsistent inside the same file.
- The packaged git stamp is not auto-populated and there is no `GIT_STAMP_OVERRIDE` toggle.
- The identity section still describes the parameters as catalog-only metadata instead of a runtime-visible common identity header.
- The RTL does not yet implement the standard `UID + META` common identity header.
- Identity parameters are not exported to HDL, so Platform Designer cannot propagate them into the live CSR space.
- The `inject` conduit exists, but it still lacks the same level of interface-tab documentation carried by the standard reference IPs.
- There is no dedicated `Debug` subgroup under `Configuration`, which the standard expects for every Mu3e IP.

## Compliance Matrix

| Area | Status | Evidence | Required upgrade |
|---|---|---|---|
| Four top-level tabs | Pass | `emulator_mutrig_hw.tcl` defines the required four tabs | None |
| HTML helper + dynamic callback updates | Pass | `add_html_text` helper and `compute_derived_values` update `hitgen_html` / `frame_html` inside `catch {}` | None |
| Single-source version constants | Fail | `set_module_property VERSION` encodes patch `1`, but the numeric defaults and Identity HTML encode patch `0` | Create `VERSION_STRING_DEFAULT_CONST` and derive all visible version text from it |
| Git stamp packaging | Fail | `VERSION_GIT_DEFAULT_CONST` is hard-coded `0` | Auto-populate from `git rev-parse --short HEAD` on the IP directory |
| Git stamp override flow | Fail | No `GIT_STAMP_OVERRIDE` parameter and no elaborate-time enable/disable logic | Add toggle and gate `VERSION_GIT` editability in `elaborate` |
| Runtime common identity header | Fail | Current CSR map starts at `CONTROL` and Identity HTML explicitly says "catalog tracking only" | Add `UID` at word `0x00` and `META` at word `0x01`; shift current CSR window by +2 |
| Identity parameters exported to RTL | Gap for full runtime-standard compliance | `IP_UID`, `VERSION_*`, `BUILD`, `VERSION_DATE`, `VERSION_GIT`, `INSTANCE_ID` are `HDL_PARAMETER false` and the Delivered Profile still describes catalog-only tracking | Once the runtime `UID + META` header is added to RTL, export these as HDL parameters and surface them live through CSR readback |
| Identity prose derived from live constants | Fail | Hard-coded stale version text in the Identity tab | Build Identity HTML from constants, as done in histogram/sc_hub |
| Configuration Debug subgroup | Fail | No `Debug` group exists under `Configuration` | Add a `Debug` subgroup with at least one packaging/debug-level parameter and notes |
| Interface coverage | Partial | `tx8b1k`, `ctrl`, and `csr` are documented; `inject` now exists as a real interface but still lacks dedicated Interfaces-tab prose | Add `inject` conduit documentation under `Data Path` or `Control Path` |
| Register map field coverage | Pass for current map | Multi-field words have field tables | Rework tables after CSR identity header insertion |
| Downstream docs/tests aligned with package | Partial | README and TB match the old CSR map, not the standard identity-header map | Update README, DV plan, and TB after CSR shift |

## Key Gaps In Detail

### 1. Version information is internally inconsistent

Inside `emulator_mutrig_hw.tcl`:
- module property version is `26.0.1.0410`
- the numeric defaults encode `26.0.0.0410`
- Identity prose says `26.0.0.0410`

This is a direct packaging violation because user-visible version text must derive from the same constants as `set_module_property VERSION`.

Recommendation:
- First resolve the intended release tag. The file currently has two competing sources of truth: the module-level VERSION string implies patch `1`, while the numeric defaults and Identity prose imply patch `0`. Repo-level badge/history currently points toward `26.0.0.0410`, but that should be confirmed explicitly before editing.
- After that decision, define:
  - `VERSION_MAJOR_DEFAULT_CONST`
  - `VERSION_MINOR_DEFAULT_CONST`
  - `VERSION_PATCH_DEFAULT_CONST`
  - `BUILD_DEFAULT_CONST`
  - `VERSION_DATE_DEFAULT_CONST`
  - `VERSION_GIT_DEFAULT_CONST`
  - `VERSION_STRING_DEFAULT_CONST`
  - `VERSION_GIT_HEX_DEFAULT_CONST`
- Drive `set_module_property VERSION` and Identity HTML from those values only.

### 2. The upgraded reference IPs expose a real common identity header; emulator_mutrig does not

The upgraded references follow the same pattern:
- word `0x00` = `UID`
- word `0x01` = `META`
- `META` write selector pages:
  - `0` = VERSION
  - `1` = DATE
  - `2` = GIT
  - `3` = INSTANCE_ID

`histogram_statistics_v2` already implements this in both packaging and RTL. `emulator_mutrig` still starts its live CSR map at `CONTROL`.

This is the main structural gap between "mostly packaged" and "100% compliant".

Recommendation:
- Add the standard identity parameters to `rtl/emulator_mutrig.sv`.
- Add a 2-bit `meta_sel` CSR register.
- Make reads from:
  - `0x00` return `IP_UID`
  - `0x01` return the selected `META` page
- Shift the existing CSR words:
  - `CONTROL` `0x00 -> 0x02`
  - `HIT_RATE` `0x01 -> 0x03`
  - `BURST_CFG` `0x02 -> 0x04`
  - `PRNG_SEED` `0x03 -> 0x05`
  - `TX_MODE` `0x04 -> 0x06`
  - `STATUS` `0x05 -> 0x07`

Impact:
- This is a software-visible and TB-visible register map change.
- `CSR_ADDR_WIDTH = 4` can stay unchanged because 8 words still fit in 4 address bits.

### 3. Identity parameters must become HDL parameters once the runtime identity header is adopted

The reference IPs do not stop at GUI metadata. Their identity parameters are exported into RTL so software can read them at runtime through `UID + META`.

For `emulator_mutrig`, the following parameters should become HDL-visible:
- `IP_UID`
- `VERSION_MAJOR`
- `VERSION_MINOR`
- `VERSION_PATCH`
- `BUILD`
- `VERSION_DATE`
- `VERSION_GIT`
- `INSTANCE_ID`

Recommendation:
- Add these parameters to `rtl/emulator_mutrig.sv` as part of the `UID + META` upgrade.
- Keep `VERSION_MAJOR`, `VERSION_MINOR`, `VERSION_PATCH`, `BUILD`, and `VERSION_DATE` GUI-disabled.
- Add `GIT_STAMP_OVERRIDE` as GUI-only.

### 4. Git stamp handling is below the new standard

The upgraded references auto-seed `VERSION_GIT` from git and allow a manual override only behind an explicit toggle.

`emulator_mutrig` currently ships with `VERSION_GIT = 0`, which loses provenance.

Recommendation:
- Mirror the `sc_hub_v2` pattern:
  - resolve the IP directory
  - run `git -C <ip_dir> rev-parse --short HEAD`
  - parse the hex string into the Tcl integer default
  - add `GIT_STAMP_OVERRIDE`
  - enable `VERSION_GIT` only when override is asserted

### 5. Configuration tab is missing the standard Debug subgroup

The packaging standard expects a dedicated `Debug` subgroup under `Configuration`.

`emulator_mutrig` currently has:
- `Overview`
- `Hit Generation`
- `Frame Assembly`

Recommendation:
- Add `Debug` under `Configuration`.
- Minimum acceptable content:
  - one GUI parameter such as `DEBUG` or `DEBUG_LEVEL` with `HDL_PARAMETER false`
  - one HTML text block describing intended bring-up / debug use
- If no actual RTL-controlled debug mode is desired, keep this parameter packaging-only and document that it does not change synthesized behavior.

### 6. Interface documentation is still incomplete

The actual interfaces are:
- `data_clock`
- `data_reset`
- `tx8b1k`
- `ctrl`
- `inject`
- `csr`

The current component now declares `inject`, but the Interfaces tab still does not describe it with the same explicit prose/detail level used for the other interfaces.

Recommendation:
- Add an interface description block for `inject`.
- Suggested wording:
  - single-bit conduit pulse
  - used to inject datapath-aligned events into the hit generator
  - asynchronous source is re-synchronized in RTL before edge detection

### 7. Downstream local collateral must move with the CSR shift

If the common identity header is inserted, at least these local files need updates:
- `emulator_mutrig/README.md`
- `emulator_mutrig/tb/tb_emulator_mutrig.sv`
- `emulator_mutrig/tb/DV_PLAN.md`

Examples of current old-map usage:
- README still lists `CONTROL` at `0x00`
- TB reads and writes the existing addresses directly

## Recommended Upgrade Todo List

### P0: Resolve packaging truth and remove stale versioning

1. Decide the intended release string: `26.0.0.0410` or `26.0.1.0410`.
2. Introduce `VERSION_STRING_DEFAULT_CONST` and `VERSION_GIT_HEX_DEFAULT_CONST`.
3. Derive:
   - `set_module_property VERSION`
   - Delivered Profile HTML
   - Versioning HTML
   from the same constants.
4. Remove all hard-coded version prose.

This is a packaging-only cleanup and should happen before any functional work.

### P1: Bring identity packaging up to standard

1. Auto-populate `VERSION_GIT_DEFAULT_CONST` from git.
2. Add `GIT_STAMP_OVERRIDE`.
3. Gate `VERSION_GIT` editability in `elaborate`.
4. Change identity parameter definitions from catalog-only to the standard runtime identity model.

This is still mostly packaging work.

### P2: Add the common identity header to RTL

1. Add RTL parameters:
   - `IP_UID`
   - `VERSION_MAJOR`
   - `VERSION_MINOR`
   - `VERSION_PATCH`
   - `BUILD`
   - `VERSION_DATE`
   - `VERSION_GIT`
   - `INSTANCE_ID`
2. Add `csr_meta_sel`.
3. Insert `UID` / `META` into the CSR map.
4. Shift the existing CSR register decode and readback by +2.
5. Update the `_hw.tcl` register map and field tables to match.

This is the only step that changes software-visible behavior and needs explicit approval before implementation.

### P3: Finish standard GUI/documentation alignment

1. Add `Configuration -> Debug`.
2. Add `inject` documentation to the Interfaces tab.
3. Consider adding a small `Performance` / `Runtime` subgroup showing:
   - long/short frame interval
   - nominal frame rate at 125 MHz
   - worst-case FIFO storage bits from `FIFO_DEPTH`

The standard says throughput/performance may be omitted if not meaningful, but for this IP it would add value and match the upgraded references better.

### P4: Repair local collateral after the RTL/register-map update

1. Update `README.md` CSR table and integration notes.
2. Update `tb/tb_emulator_mutrig.sv` address expectations.
3. Update `tb/DV_PLAN.md` register map.
4. Re-run the emulator TB after the CSR shift.

## Practical Implementation Order

Recommended order if you want the upgrade done with minimum churn:

1. Packaging-only cleanup:
   - version single-sourcing
   - git stamp auto-seed
   - git override toggle
   - debug subgroup
   - inject interface docs
2. Approval checkpoint for the CSR-visible identity-header change
3. RTL + `_hw.tcl` identity-header implementation
4. README / DV / TB updates
5. Regression run

## Bottom Line

`emulator_mutrig` is already close in GUI shape, but it is still one generation behind the current Mu3e packaging standard in identity/versioning architecture.

To reach 100% compliance, the essential upgrade is not cosmetic:
- the IP needs the same runtime `UID + META` identity header model used by `histogram_statistics_v2` and `sc_hub_v2`
- the `_hw.tcl` must stop treating identity as catalog-only metadata
- version/git text must come from one authoritative constant set

Everything else is follow-through after that.
