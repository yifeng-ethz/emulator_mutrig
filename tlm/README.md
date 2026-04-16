# MuTRiG TLM Contract

This directory captures the raw MuTRiG datapath contract that now drives the `emulator_mutrig` RTL rewrite and is intended to be reused by future UVM sequencers/reference models.

## What Was Recovered

- Raw source tree used for contract extraction:
  `/home/yifeng/kbriggl-mutrig3-c3cce8d41dcb/units`
- Confirmed topology from raw RTL:
  4 L1 FIFOs, each fed by one group of 8 channels, then 1 shared L2 FIFO
- Confirmed FIFO sizing from raw RTL:
  L1 depth 256, L2 depth 256
- Confirmed backpressure rule from raw RTL:
  `almost_full` throttles upstream arbitration with a 3-slot margin
- Confirmed frame cadence from raw RTL:
  long mode `1550`, short mode `910`
- Confirmed frame-generator behavior from raw RTL:
  prefetch first word in `FS_FRAMECOUNT`, then prefetch the next long-mode word at `byte_count == 4`

## Source Anchors

- L1 topology and `almost_full` gating:
  `/home/yifeng/kbriggl-mutrig3-c3cce8d41dcb/units/group_buffer/source/rtl/vhdl/group_buffer.vhd`
- L2 arbitration:
  `/home/yifeng/kbriggl-mutrig3-c3cce8d41dcb/units/GroupMasterSelect/source/rtl/vhdl/GroupMasterSelect.vhd`
- Master/slave coarse-counter selection:
  `/home/yifeng/kbriggl-mutrig3-c3cce8d41dcb/units/MS_select/source/rtl/vhdl/MS_select.vhd`
- Frame-generator FSM and prefetch timing:
  `/home/yifeng/kbriggl-mutrig3-c3cce8d41dcb/units/frame_generator/source/rtl/vhdl/frame_generator.vhd`
- Shared constants and L1/L2 record widths:
  `/home/yifeng/kbriggl-mutrig3-c3cce8d41dcb/units/datapath_defs/source/rtl/vhdl/datapath_types.vhd`

## Raw Revival Support

The missing shared HDL dependencies are now staged under:

- `raw_support/hdlcore_lib/generic_arbitration/units/arb_selection/source/rtl/vhdl/`
- `raw_support/hdlcore_lib/generic_arbitration/units/generic_mux_chnumappend/source/rtl/vhdl/`
- `raw_support/hdlcore_lib/generic_memory/fifo_wtrig/source/rtl/vhdl/`
- `raw_support/hdlcore_lib/generic_memory/generic_dp_fifo/source/rtl/vhdl/`

These files are compatibility shims that match the legacy entity names and port
contracts closely enough to unblock compilation and contract-level replay.

Use `compile_raw_contract.do` from this directory to compile the raw sources
together with the compatibility library into a fresh Questa work library. On the
current tree that script now completes successfully through `stic3_top`.

## How To Use This Directory

- `mutrig_tlm_contract_pkg.sv` is the source-derived TLM contract for future scoreboards/sequencers.
- `compile_raw_contract.do` compiles the raw MuTRiG sources with the local compatibility shims.
- The emulator RTL now follows the same queue topology and frame-generator prefetch contract.
- The next step, if full raw revival becomes possible, is to compare the raw frame stream against the emulator frame stream cycle-by-cycle and then bind the same package into the UVM reference model.
