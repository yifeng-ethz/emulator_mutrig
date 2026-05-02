# Interfaces

## TL;DR

Five external interface surfaces: AVMM CSR slave, run-control AvST sink,
inject conduit, per-lane `hit_type0` AvST sources, and per-lane optional
8b/1k AvST sources. The CSR and run-control surfaces follow Mu3e
conventions; the per-lane outputs match `mutrig_frame_deassembly`'s
`aso_hit_type0_*` contract beat-for-beat.

## Why this exists

Downstream Mu3e IPs (`mutrig_timestamp_processor`, `packet_scheduler`,
`ring_buffer_cam`) expect the same wire formats whether the source is a
real MuTRiG via the deassembly IP or this emulator. Documenting the
interfaces here lets a downstream owner drop the emulator into their
testbench without reading the RTL.

## How it works

### AVMM CSR slave (`avs_csr_*`)

```
input  logic [5:0]  avs_csr_address
input  logic        avs_csr_read
input  logic        avs_csr_write
input  logic [31:0] avs_csr_writedata
output logic [31:0] avs_csr_readdata
output logic        avs_csr_waitrequest    // ties to 0
```

See [CSR Map](csr_map.html) for the field layout. 1-cycle read latency,
no wait states.

### Run-control AvST sink (`asi_ctrl_*`)

```
input  logic [8:0] asi_ctrl_data    // 9-bit one-hot run-control word
input  logic       asi_ctrl_valid
output logic       asi_ctrl_ready   // ties to 1
```

One-hot encoding: `bit[0]=IDLE`, `bit[1]=RUN_PREPARE`, `bit[2]=SYNC`,
`bit[3]=RUNNING`, `bit[4]=TERMINATING`, `bit[5]=LINK_TEST`,
`bit[6]=SYNC_TEST`, `bit[7]=RESET`, `bit[8]=OUT_OF_DAQ`.

`run_generating` (gates new launches) = `bit[3]`. `run_draining` (keeps
queued L2 hits flowing) = `bit[3] | bit[4]`. `emu_rst` (clears LFSRs +
FIFOs + counters) = `i_rst | (valid && (bit[2] | bit[7]))`.

### Inject conduit (`coe_inject_pulse`)

```
input  logic coe_inject_pulse
```

Single rising-edge-triggered pulse. 2-FF resynced into the IP clock;
edge-detected once; OR-merged with the W1P `FIRE.fire_inject_pulse`
CSR bit. Either source produces one cluster launch (geometry per
`cluster_geom_mode`), regardless of `hit_mode_sig`, gated only by
`global_enable`.

### Per-lane hit_type0 AvST source (`aso_hit_type0_*[lane]`)

```
output logic [3:0]  aso_hit_type0_channel
output logic        aso_hit_type0_startofpacket
output logic        aso_hit_type0_endofpacket
output logic        aso_hit_type0_endofrun
output logic [2:0]  aso_hit_type0_error
output logic [44:0] aso_hit_type0_data
output logic        aso_hit_type0_valid
```

Word layout matches `mutrig_frame_deassembly`'s `frame_rcv_ip.vhd:578-587`:

| Bits | Field | Source |
|---|---|---|
| `[44:41]` | `asic` | `asic_id_base + lane_index` (clamped to 4 bits) |
| `[40:36]` | `channel` | local channel (0..31) |
| `[35:21]` | `T_CC` | TCC anchor from PRBS-15 LFSR at commit cycle |
| `[20:16]` | `T_Fine` | per-lane fine PRNG sample |
| `[15:1]`  | `E_CC` | ECC anchor from independent PRBS-15 LFSR |
| `[0]`     | `E_Flag` | tied to 1 (raw-RTL contract) |

`E_Fine` is **dropped** on this stream per the deassembly contract.
`error[2:0]` is 0 by default; `ERROR_INJECT` (`0x15`) ORs configured
bits when the targeted lane bit is set. SOP/EOP frame the per-frame hit
group; `endofrun` pulses once per lane after the L2 drains on
TERMINATING→IDLE.

### Per-lane 8b/1k AvST source (`aso_tx8b1k_*[lane]`, optional)

```
output logic [8:0] aso_tx8b1k_data    // {is_k, byte}
output logic       aso_tx8b1k_valid
output logic [3:0] aso_tx8b1k_channel
output logic [2:0] aso_tx8b1k_error
```

Only synthesised when `BYTE_STREAM_ENABLE=1`. Otherwise drives K28.5
idle continuously. Compatible with `mutrig_frame_deassembly`'s `rx8b1k`
sink for back-compat A/B testing.

## Interfaces and contracts

- All AvST interfaces follow standard Avalon-ST semantics: `valid`
  asserts when data is presented; the sink may hold `ready` low (if
  applicable) to back-pressure.
- `hit_type0` and `tx8b1k` per-lane sources are **independent** — both
  can be active simultaneously, both can back-pressure independently.
- The CSR slave is fully decoupled from run-control: reads and writes
  work in any state including during `i_rst`.

## Where to look in the code

- AVMM CSR: `rtl/frontend/frontend_csr.sv`
- Run-control decode + inject sync: `rtl/frontend/frontend_run_ctl.sv`
- hit_type0 emit: `rtl/backend_mutrig/be_mutrig_lane_type0_emit.sv`
- 8b/1k frame assembly: `rtl/backend_mutrig/be_mutrig_frame_assembler.sv`
- Top-level wiring: `rtl/emulator_mutrig.sv`

## Open questions / gotchas

- The hit_type0 path drops `E_Fine` entirely (matches deassembly). If a
  downstream consumer needs `E_Fine`, it must take the byte-stream
  output and run `mutrig_frame_deassembly` itself.
- `aso_tx8b1k_*` ports always exist on the module, even when
  `BYTE_STREAM_ENABLE=0` — they just drive idle K28.5. This keeps the
  port list build-axis-independent for Qsys integration.
