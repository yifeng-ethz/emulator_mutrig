# MuTRiG Emulator (`emulator_mutrig`)

FPGA emulator of the MuTRiG 3 SiPM readout ASIC digital output. Generates
8b/1k parallel data frames bit-compatible with the real ASIC serial output
(after 8b10b decoding). Designed for FPGA-internal use, feeding `frame_rcv_ip`
directly without LVDS serialization.

## Architecture

```
                       +-----------------+
  cfg (CSR) ---------> | hit_generator   |---> hit FIFO (48-bit)
                       |  LCG PRNG       |         |
                       +-----------------+         v
  tcc_lfsr (PRBS-15) ----+          +--------------------+
  ecc_lfsr (PRBS-15) ----+--------> | frame_assembler    |---> aso_tx8b1k (9-bit)
                                    |  FSM + CRC-16      |
  run_control (AVST) ------------> +--------------------+
```

### Sub-Components

| Component | File | Description |
|-----------|------|-------------|
| `emulator_mutrig` | `rtl/emulator_mutrig.sv` | Top-level with Avalon interfaces and CSR |
| `emulator_mutrig_pkg` | `rtl/emulator_mutrig_pkg.sv` | Constants, types, pack functions |
| `hit_generator` | `rtl/hit_generator.sv` | Configurable hit pattern generation (Poisson, burst, noise, mixed) |
| `frame_assembler` | `rtl/frame_assembler.sv` | Frame assembly FSM, CRC-16, 8b/1k output |
| `prbs15_lfsr` | `rtl/prbs15_lfsr.sv` | PRBS-15 LFSR (x^15 + x^1 + 1) coarse counter |
| `crc16_8` | `rtl/crc16_8.sv` | CRC-16-ANSI byte-wise calculator |

## Interfaces

| Interface | Type | Width | Description |
|-----------|------|-------|-------------|
| `data_clock` | Clock sink | 1-bit | Byte clock (125-128 MHz) |
| `data_reset` | Reset sink | 1-bit | Synchronous reset |
| `tx8b1k` | AVST source | 9-bit data, 4-bit channel, 3-bit error | 8b/1k output to `frame_rcv_ip` |
| `ctrl` | AVST sink | 9-bit data | 9-bit one-hot run control input |
| `csr` | AVMM slave | 4-bit addr, 32-bit data | Configuration registers |

### tx8b1k Data Format

| Bit | Field | Description |
|-----|-------|-------------|
| 8 | `is_k` | K-character flag |
| 7:0 | `data` | 8-bit data byte |

### Frame Format

```
IDLE(K28.5) | K28.0(hdr) | frame_cnt[15:8] | frame_cnt[7:0] |
flags_evt[15:8] | flags_evt[7:0] | hit_data... |
CRC[15:8] | CRC[7:0] | K28.4(trailer)
```

- Long mode: 720 byte-clocks per frame (~5.6 us at 128 MHz), 48-bit hits (6 bytes each)
- Short mode: 420 byte-clocks per frame (~3.3 us at 128 MHz), 28-bit hits (3.5 bytes, alternating 3/4 byte packing)

## CSR Register Map

| Addr | Name | R/W | Description |
|------|------|-----|-------------|
| 0x00 | CONTROL | RW | `[0]` enable, `[2:1]` hit_mode, `[3]` short_mode |
| 0x01 | HIT_RATE | RW | `[15:0]` hit_rate (8.8 FP), `[31:16]` noise_rate |
| 0x02 | BURST_CFG | RW | `[4:0]` burst_size, `[12:8]` burst_center |
| 0x03 | PRNG_SEED | RW | `[31:0]` PRNG seed |
| 0x04 | TX_MODE | RW | `[2:0]` tx_mode, `[3]` gen_idle, `[7:4]` asic_id |
| 0x05 | STATUS | RO | `[15:0]` frame_count, `[25:16]` last_event_count |

### Hit Modes

| Value | Mode | Description |
|-------|------|-------------|
| 00 | Poisson | i.i.d. per-channel with configurable rate |
| 01 | Burst | Periodic cluster hits on neighbouring channels |
| 10 | Noise | Random dark-count-like hits |
| 11 | Mixed | Poisson signal + burst clusters |

## Platform Designer Integration

The `emulator_mutrig_hw.tcl` registers this IP in Platform Designer. Connect:

1. `data_clock` / `data_reset` to the datapath clock domain
2. `ctrl` to the run-control splitter output
3. `tx8b1k` to a `frame_rcv_ip` rx8b1k sink (or `mutrig_datapath_subsystem` serial input)
4. `csr` to the Avalon-MM fabric for runtime configuration

Each instance emulates one MuTRiG ASIC. Set `asic_id` (CSR 0x04, bits [7:4]) to a unique
value per instance for downstream channel identification.

## Simulation

### Unit Tests

```bash
cd tb/
make compile
make run TEST=B01    # single test
make run_all         # all tests
```

Requires Questa FSE (see top-level `CLAUDE.md` for license setup).

### System Integration

The emulator has been verified end-to-end in a full `scifi_datapath_v2_system` simulation
with 8 instances driving the complete pipeline through `frame_rcv_ip`, `mts_processor`,
`ring_buffer_cam`, `feb_frame_assembly`, to `hit_type3` output.

## References

- MuTRiG 3 ASIC digital readout: Huangshan Chen, KIP Heidelberg (kbriggl-mutrig3-c3cce8d41dcb)
- PRBS-15 polynomial: x^15 + x^1 + 1 (Galois form, init 0x7FFF, period 32767)
- CRC-16-ANSI: x^16 + x^15 + x^2 + 1

## License

Part of the Mu3e IP Cores collection. Internal use.
