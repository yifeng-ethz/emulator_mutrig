# DV Plan: emulator_mutrig (MuTRiG 3 ASIC Emulator)

**DUT:** `emulator_mutrig` (Rev 1.0)
**IP source:** `mu3e-ip-cores/emulator_mutrig/rtl/emulator_mutrig.sv`
**Author:** Yifeng Wang
**Date:** 2026-04-10
**Status:** Initial

---

## 1. DUT Overview

FPGA emulator of the MuTRiG 3 SiPM readout ASIC digital output. Generates 8b/1k parallel data frames bit-compatible with the real ASIC serial output (after 8b/10b decoding). Supports configurable hit patterns, PRBS-15 LFSR timestamps, short/long hit modes, and CRC-16 frame integrity.

### Data Path

```
hit_generator (LCG PRNG → hit FIFO)
    → frame_assembler (frame FSM → 8b/1k output)
        ← prbs15_lfsr (T coarse counter)
        ← prbs15_lfsr (E coarse counter)
        ← crc16_8 (frame CRC)
```

### Sub-Components

| Component | File | Description |
|-----------|------|-------------|
| `emulator_mutrig` | `emulator_mutrig.sv` | Top-level with Avalon interfaces |
| `hit_generator` | `hit_generator.sv` | Configurable hit pattern generation |
| `frame_assembler` | `frame_assembler.sv` | Frame assembly FSM, CRC, 8b/1k output |
| `prbs15_lfsr` | `prbs15_lfsr.sv` | PRBS-15 LFSR (x^15+x^1+1) coarse counter |
| `crc16_8` | `crc16_8.sv` | CRC-16-ANSI calculator |
| `emulator_mutrig_pkg` | `emulator_mutrig_pkg.sv` | Constants, types, pack functions |

### Interfaces

| Interface | Type | Width | Description |
|-----------|------|-------|-------------|
| `tx8b1k` | AVST source | 9-bit data, 4-bit channel | 8b/1k output to frame_rcv_ip |
| `ctrl` | AVST sink | 9-bit data | Run control timing input |
| `csr` | AVMM slave | 4-bit addr, 32-bit data | Configuration registers |
| `data_clock` | clock | 1-bit | Byte clock (~125 MHz) |
| `data_reset` | reset | 1-bit | Synchronous reset |

---

## 2. CSR Register Map

| Addr | Name | R/W | Description |
|------|------|-----|-------------|
| 0 | CONTROL | RW | [0] enable, [2:1] hit_mode, [3] short_mode |
| 1 | HIT_RATE | RW | [15:0] hit_rate (8.8 FP), [31:16] noise_rate |
| 2 | BURST_CFG | RW | [4:0] burst_size, [12:8] burst_center |
| 3 | PRNG_SEED | RW | [31:0] PRNG seed |
| 4 | TX_MODE | RW | [2:0] tx_mode, [3] gen_idle, [7:4] asic_id |
| 5 | STATUS | R | [15:0] frame_count, [25:16] last_event_count |

---

## 3. Verification Targets

| ID | Feature | RTL Location | Observability |
|----|---------|-------------|---------------|
| F01 | PRBS-15 LFSR sequence | prbs15_lfsr.sv | Compare LFSR output against known sequence |
| F02 | Frame header format | frame_assembler.sv:FS_HEADER..FS_EVENTCOUNT | Check K28.0, frame_count, flags+evt_count |
| F03 | Long-hit packing (48-bit) | frame_assembler.sv:FS_PACK | Byte-align 6 bytes per event |
| F04 | Short-hit packing (28-bit) | frame_assembler.sv:FS_PACK,FS_PACK_EXTRA | Alternating 3/4 byte interleaving |
| F05 | CRC-16 integrity | crc16_8.sv + frame_assembler.sv:FS_CRC_REM | Verify CRC matches re-computed value |
| F06 | Frame trailer | frame_assembler.sv:FS_TRAILER | K28.4 trailer symbol |
| F07 | Idle comma generation | frame_assembler.sv:FS_IDLE | K28.5 between frames |
| F08 | Frame interval timing | frame_assembler.sv interval counter | 720 (long) / 420 (short) byte-clocks |
| F09 | Poisson hit generation | hit_generator.sv:S_GEN_POISSON | Statistical test of hit count distribution |
| F10 | Burst/cluster hits | hit_generator.sv:S_GEN_BURST | Verify contiguous channel hits |
| F11 | Mixed mode | hit_generator.sv | Poisson + burst combined |
| F12 | Run control reset | emulator_mutrig.sv | No output until RUNNING state |
| F13 | CSR read/write | emulator_mutrig.sv CSR block | Register access correctness |
| F14 | ASIC ID passthrough | emulator_mutrig.sv | Channel tag on AVST output |
| F15 | Empty frame | frame_assembler.sv | Header + 0 events + CRC + trailer |
| F16 | Compatibility with frame_rcv_ip | Integration | frame_rcv_ip correctly parses emulator output |

---

## 4. Test Cases

### 4.1 Basic Tests

| TC | Name | Target | Description |
|----|------|--------|-------------|
| B01 | LFSR sequence check | F01 | Run LFSR for 32767 steps, verify all states visited, verify against ROM LUT |
| B02 | Empty frame | F02,F05,F06,F07,F15 | Generate frame with 0 events, check header/trailer/CRC |
| B03 | Single long hit | F02,F03,F05 | One event in long mode, verify 6-byte packing |
| B04 | Single short hit | F02,F04,F05 | One event in short mode, verify 3.5-byte packing |
| B05 | CSR readback | F13 | Write all CSRs, read back, verify |

### 4.2 Functional Tests

| TC | Name | Target | Description |
|----|------|--------|-------------|
| T01 | Multi-hit long frame | F03,F05,F08 | Multiple events in long mode, verify packing and CRC |
| T02 | Multi-hit short frame | F04,F05,F08 | Multiple events in short mode with even/odd interleaving |
| T03 | Poisson rate accuracy | F09 | Run 1000 frames, verify mean hit count matches configured rate |
| T04 | Burst pattern | F10 | Verify burst generates contiguous channel cluster |
| T05 | Mixed mode | F11 | Verify both Poisson and burst hits appear |
| T06 | Run control gating | F12 | Verify no frames before RUNNING, frames during RUNNING, stop on non-RUNNING |
| T07 | Frame counter increment | F02 | Verify frame_count increments each frame |
| T08 | ASIC ID tag | F14 | Set asic_id, verify channel output |

### 4.3 Integration Tests

| TC | Name | Target | Description |
|----|------|--------|-------------|
| I01 | frame_rcv_ip compatibility | F16 | Connect emulator output to frame_rcv_ip, verify hit extraction |
| I02 | Short mode compatibility | F16 | Same as I01 but in short mode |

### 4.4 Edge Cases

| TC | Name | Target | Description |
|----|------|--------|-------------|
| E01 | Max events per frame | F03,F08 | Fill frame to capacity |
| E02 | FIFO overflow | F09 | High hit rate causing FIFO full condition |
| E03 | Back-to-back frames | F07,F08 | Verify continuous frame generation |

---

## 5. Coverage Goals

| Metric | Target |
|--------|--------|
| Line coverage | > 95% |
| Branch coverage | > 90% |
| FSM state coverage | 100% (all states visited) |
| FSM transition coverage | > 90% |
| LFSR period check | 100% (full period verified) |
| CRC correctness | 100% (every frame CRC verified) |
