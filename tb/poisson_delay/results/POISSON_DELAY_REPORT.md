# Poisson Delay Sweep

- Mode: short-mode Poisson, burst_size=1, noise=0
- Raw full-link reference: 0.285714 hits/cycle = 1 hit / 3.5 cycles
- Warmup cycles per point: 50000
- Measured cycles per point: 200000
- Drain timeout cycles: 400000

Default timestamp contract for this sweep:

- long-hit `E` timestamp is the true commit timestamp
- long-hit `T` timestamp is constrained to `T <= E`
- the primary latency metric is therefore `E-ts -> pop`

## Summary Table

| raw full % | hit_rate | accepted hits/cycle | avg occ | max occ | full cycles | true-ts -> pop min/p50/p90/p99/max | <1 frame | 1..2 frames | >=2 frames |
|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|
| 0 | 0 | 0.0000 | 0.0 | 0 | 0 | n/a/n/a/n/a/n/a/n/a | 0.00% | 0.00% | 0.00% |
| 10 | 1872 | 0.0310 | 16.0 | 138 | 0 | 33.0/512.5/846.9/911.0/944.0 | 98.87% | 1.13% | 0.00% |
| 20 | 3745 | 0.0601 | 33.8 | 177 | 0 | 106.0/561.5/854.0/914.0/985.0 | 98.31% | 1.69% | 0.00% |
| 40 | 7490 | 0.1177 | 76.8 | 244 | 0 | 265.0/657.0/873.0/933.5/1103.0 | 96.94% | 3.06% | 0.00% |
| 60 | 11235 | 0.1744 | 129.5 | 256 | 270 | 393.0/752.0/894.0/967.0/1057.0 | 94.37% | 5.63% | 0.00% |
| 80 | 14980 | 0.2290 | 189.0 | 256 | 1082 | 582.0/835.0/909.0/954.0/1089.0 | 90.69% | 9.31% | 0.00% |
| 90 | 16852 | 0.2543 | 220.2 | 256 | 3081 | 663.0/874.0/923.0/981.0/1038.0 | 80.48% | 19.52% | 0.00% |
| 95 | 17788 | 0.2630 | 231.4 | 256 | 6318 | 677.0/885.0/934.0/988.0/1063.0 | 73.88% | 26.12% | 0.00% |
| 100 | 18725 | 0.2698 | 240.3 | 256 | 10703 | 695.0/895.0/936.0/982.0/1045.0 | 68.32% | 31.68% | 0.00% |

## Cross-Checks

| raw full % | commit-cycle -> pop p50/p90/p99/max | true-ts -> pop p01/p50/p90/p99/max | T-ts -> pop p01/p50/p90/p99/max | max measured outstanding |
|---:|---|---|---|---:|
| 0 | n/a/n/a/n/a/n/a | n/a/n/a/n/a/n/a/n/a | n/a/n/a/n/a/n/a/n/a | 0 |
| 10 | 511.5/845.9/910.0/943 | 91.0/512.5/846.9/911.0/944.0 | 91.0/512.5/846.9/911.0/944.0 | 138 |
| 20 | 560.5/853.0/913.0/984 | 172.0/561.5/854.0/914.0/985.0 | 172.0/561.5/854.0/914.0/985.0 | 177 |
| 40 | 656/872.0/932.5/1102 | 330.0/657.0/873.0/933.5/1103.0 | 330.0/657.0/873.0/933.5/1103.0 | 244 |
| 60 | 751.0/893.0/966.0/1056 | 483.0/752.0/894.0/967.0/1057.0 | 483.0/752.0/894.0/967.0/1057.0 | 257 |
| 80 | 834/908.0/953.0/1088 | 654.0/835.0/909.0/954.0/1089.0 | 654.0/835.0/909.0/954.0/1089.0 | 257 |
| 90 | 873/922/980.0/1037 | 735.0/874.0/923.0/981.0/1038.0 | 735.0/874.0/923.0/981.0/1038.0 | 257 |
| 95 | 884.0/933.0/987.0/1062 | 761.0/885.0/934.0/988.0/1063.0 | 761.0/885.0/934.0/988.0/1063.0 | 257 |
| 100 | 894/935.0/981.0/1044 | 793.0/895.0/936.0/982.0/1045.0 | 793.0/895.0/936.0/982.0/1045.0 | 257 |

### Low-Load Shape (10% of raw full rate, true-ts -> pop, 0..1 frame window)

| bin | latency range (cycles) | samples | pct |
|---:|---|---:|---:|
| 00 | 0.0 .. 65.0 | 7 | 0.11% |
| 01 | 65.0 .. 130.0 | 203 | 3.27% |
| 02 | 130.0 .. 195.0 | 403 | 6.50% |
| 03 | 195.0 .. 260.0 | 443 | 7.14% |
| 04 | 260.0 .. 325.0 | 493 | 7.95% |
| 05 | 325.0 .. 390.0 | 584 | 9.42% |
| 06 | 390.0 .. 455.0 | 471 | 7.59% |
| 07 | 455.0 .. 520.0 | 552 | 8.90% |
| 08 | 520.0 .. 585.0 | 560 | 9.03% |
| 09 | 585.0 .. 650.0 | 415 | 6.69% |
| 10 | 650.0 .. 715.0 | 448 | 7.22% |
| 11 | 715.0 .. 780.0 | 569 | 9.17% |
| 12 | 780.0 .. 845.0 | 426 | 6.87% |
| 13 | 845.0 .. 910.0 | 628 | 10.13% |

### Full-Load Shape (100% of raw full rate, true-ts -> pop, 0..2 frame window)

| bin | latency range (cycles) | samples | pct |
|---:|---|---:|---:|
| 00 | 0.0 .. 130.0 | 0 | 0.00% |
| 01 | 130.0 .. 260.0 | 0 | 0.00% |
| 02 | 260.0 .. 390.0 | 0 | 0.00% |
| 03 | 390.0 .. 520.0 | 0 | 0.00% |
| 04 | 520.0 .. 650.0 | 0 | 0.00% |
| 05 | 650.0 .. 780.0 | 243 | 0.45% |
| 06 | 780.0 .. 910.0 | 36622 | 67.87% |
| 07 | 910.0 .. 1040.0 | 17084 | 31.66% |
| 08 | 1040.0 .. 1170.0 | 14 | 0.03% |
| 09 | 1170.0 .. 1300.0 | 0 | 0.00% |
| 10 | 1300.0 .. 1430.0 | 0 | 0.00% |
| 11 | 1430.0 .. 1560.0 | 0 | 0.00% |
| 12 | 1560.0 .. 1690.0 | 0 | 0.00% |
| 13 | 1690.0 .. 1820.0 | 0 | 0.00% |

## Notes

- `true-ts -> pop` is reconstructed as `prbs_delta(pop_ecc, hit_ecc) - hit_efine/32`. In the default mode under test this is the true hit timestamp because the hit commits on the encoded `E` timestamp.
- `commit-cycle -> pop` is kept as a same-cycle sanity cross-check that ignores the sub-cycle fine timestamp fraction.
- `T-ts -> pop` is kept as a consistency cross-check for the `T <= E` timing contract.
- Pop is defined as the cycle where the frame assembler asserts the L2 FIFO read handshake.
- The low-load minimum is not exactly zero because the earliest eligible pop still sits behind the frame header and event-count bytes, which costs about `32` byte clocks in this wrapper.
- At `100%` of the raw `1 hit / 3.5 cycles` reference, the measured true-timestamp latency stays mostly in the `0.8 .. 1.15` frame range rather than filling a full `0 .. 2` frame box. The short-mode packer keeps draining continuously inside an already-open frame, so this regime is not a pure whole-frame-queued service model.
- The bench keeps the lane running after the main measurement window until every measured hit has popped, so pop-time coarse counters stay valid.
- `full_cycles > 0` indicates the lane FIFO reached saturation during the measured window.
