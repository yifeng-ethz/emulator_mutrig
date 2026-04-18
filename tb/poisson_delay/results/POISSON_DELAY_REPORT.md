# Poisson Delay Sweep

- Mode: short-mode Poisson, burst_size=1, noise=0
- Raw full-link reference: 0.285714 hits/cycle = 1 hit / 3.5 cycles
- Warmup cycles per point: 50000
- Measured cycles per point: 200000
- Drain timeout cycles: 400000

Corrected latency model used in this report:

- the true hit timestamp is the committed `E` timestamp, so `true_ts = commit_cycle + E_fine/32`
- raw MuTRiG `frame_gen` latches `i_event_counts` at frame start and only then drains that frame payload
- the frame-marker TLM therefore groups hits by frame window, keeps at most the most recent `256` hits at the marker, and emits them across the next frame with the short-mode `3/4` byte cadence
- two latency observables are reported: `true_ts -> frame_start` and `true_ts -> parser_hit_valid`

## Summary Table

| raw full % | accepted hits/cycle | avg occ | max occ | full cycles | actual true-ts -> frame-start min/p50/p90/p99/max | actual true-ts -> output min/p50/p90/p99/max |
|---:|---:|---:|---:|---:|---|---|
| 0 | 0.0000 | 0.0 | 0 | 0 | n/a/n/a/n/a/n/a/n/a | n/a/n/a/n/a/n/a/n/a |
| 10 | 0.0310 | 16.0 | 138 | 0 | 2.0/444.0/816.0/902.0/911.0 | 40.0/520.0/854.0/918.0/951.0 |
| 20 | 0.0601 | 33.8 | 177 | 0 | 2.0/452.0/820.0/901.0/911.0 | 114.0/569.0/861.0/922.0/992.0 |
| 40 | 0.1177 | 76.8 | 244 | 0 | 2.0/456.0/820.0/901.0/911.0 | 273.0/665.0/881.0/941.5/1110.0 |
| 60 | 0.1744 | 129.5 | 256 | 270 | 2.0/458.0/822.0/902.0/1011.0 | 400.0/759.0/901.0/975.0/1064.0 |
| 80 | 0.2290 | 189.0 | 256 | 1082 | 2.0/457.0/821.0/902.0/1017.0 | 589.0/843.0/916.0/961.0/1097.0 |
| 90 | 0.2543 | 220.2 | 256 | 3081 | 2.0/459.0/821.0/902.0/1035.0 | 671.0/881.0/931.0/989.0/1045.0 |
| 95 | 0.2630 | 231.4 | 256 | 6318 | 2.0/460.0/819.0/901.0/1041.0 | 685.0/893.0/942.0/995.0/1070.0 |
| 100 | 0.2698 | 240.3 | 256 | 10703 | 2.0/461.0/820.0/902.0/1042.0 | 702.0/903.0/943.0/990.0/1052.0 |

## TLM Comparison

| raw full % | TLM assigned/dropped/unassigned | TLM true-ts -> frame-start p50/p90/p99/max | TLM true-ts -> output p50/p90/p99/max | RTL frame exact | RTL output exact | RTL output +/-1 cyc |
|---:|---:|---|---|---:|---:|---:|
| 0 | 0/0/0 | n/a/n/a/n/a/n/a | n/a/n/a/n/a/n/a | 0.00% | 0.00% | 0.00% |
| 10 | 6202/0/0 | 442.5/815.0/901.0/910.0 | 519.0/853.0/917.0/951.0 | 99.92% | 97.10% | 97.10% |
| 20 | 12022/0/0 | 451.0/819.0/901.0/910.0 | 568.0/860.9/921.0/992.0 | 99.90% | 94.18% | 94.18% |
| 40 | 23547/0/0 | 455.0/819.0/900.0/910.0 | 664.0/880.0/940.0/1110.0 | 99.92% | 90.91% | 90.91% |
| 60 | 34879/1/1 | 457.0/821.0/901.0/910.0 | 758.0/900.0/974.0/1064.0 | 99.90% | 83.36% | 83.36% |
| 80 | 45799/6/6 | 456.0/820.0/901.0/910.0 | 842.0/915.0/960.0/1093.0 | 99.90% | 75.37% | 75.37% |
| 90 | 50844/17/17 | 458.0/819.7/900.0/910.0 | 880.0/929.0/986.0/1036.0 | 99.87% | 61.46% | 61.46% |
| 95 | 52571/37/37 | 458.0/817.0/899.0/910.0 | 891.0/940.0/992.0/1067.0 | 99.83% | 42.19% | 42.19% |
| 100 | 53914/49/49 | 459.0/817.0/899.0/910.0 | 900.0/941.0/986.0/1047.0 | 99.80% | 28.37% | 28.37% |

## Cross-Checks

| raw full % | actual true-ts -> pop p50/p90/p99/max | actual output <1f | actual output 1..2f | actual output >=2f | frame delta mean | output delta mean/p99 |
|---:|---|---:|---:|---:|---:|---|
| 0 | n/a/n/a/n/a/n/a | 0.00% | 0.00% | 0.00% | n/a | n/a/n/a |
| 10 | 511.5/845.9/910.0/943.0 | 97.73% | 2.27% | 0.00% | 0.7 | 0.8/4.0 |
| 20 | 560.5/853.0/913.0/984.0 | 97.16% | 2.84% | 0.00% | 0.9 | 0.9/4.0 |
| 40 | 656.0/872.0/932.5/1102.0 | 95.51% | 4.49% | 0.00% | 0.8 | 0.8/4.0 |
| 60 | 751.0/893.0/966.0/1056.0 | 92.31% | 7.69% | 0.00% | 0.9 | 0.9/4.0 |
| 80 | 834.0/908.0/953.0/1088.0 | 86.71% | 13.29% | 0.00% | 0.9 | 1.0/4.0 |
| 90 | 873.0/922.0/980.0/1037.0 | 73.71% | 26.29% | 0.00% | 1.2 | 1.5/4.0 |
| 95 | 884.0/933.0/987.0/1062.0 | 66.54% | 33.46% | 0.00% | 1.5 | 2.1/4.0 |
| 100 | 894.0/935.0/981.0/1044.0 | 59.04% | 40.96% | 0.00% | 1.8 | 2.6/4.0 |

### Low-Load Shape (10% raw full, actual true-ts -> frame-start, 0..1 frame)

| bin | latency range (cycles) | samples | pct |
|---:|---|---:|---:|
| 00 | 0.0 .. 65.0 | 368 | 5.93% |
| 01 | 65.0 .. 130.0 | 461 | 7.43% |
| 02 | 130.0 .. 195.0 | 518 | 8.35% |
| 03 | 195.0 .. 260.0 | 404 | 6.51% |
| 04 | 260.0 .. 325.0 | 411 | 6.63% |
| 05 | 325.0 .. 390.0 | 489 | 7.88% |
| 06 | 390.0 .. 455.0 | 530 | 8.55% |
| 07 | 455.0 .. 520.0 | 499 | 8.05% |
| 08 | 520.0 .. 585.0 | 424 | 6.84% |
| 09 | 585.0 .. 650.0 | 385 | 6.21% |
| 10 | 650.0 .. 715.0 | 464 | 7.48% |
| 11 | 715.0 .. 780.0 | 407 | 6.56% |
| 12 | 780.0 .. 845.0 | 445 | 7.18% |
| 13 | 845.0 .. 910.0 | 397 | 6.40% |

### Low-Load Shape (10% raw full, actual true-ts -> output, 0..1 frame)

| bin | latency range (cycles) | samples | pct |
|---:|---|---:|---:|
| 00 | 0.0 .. 65.0 | 3 | 0.05% |
| 01 | 65.0 .. 130.0 | 169 | 2.72% |
| 02 | 130.0 .. 195.0 | 382 | 6.16% |
| 03 | 195.0 .. 260.0 | 465 | 7.50% |
| 04 | 260.0 .. 325.0 | 474 | 7.64% |
| 05 | 325.0 .. 390.0 | 590 | 9.51% |
| 06 | 390.0 .. 455.0 | 469 | 7.56% |
| 07 | 455.0 .. 520.0 | 550 | 8.87% |
| 08 | 520.0 .. 585.0 | 554 | 8.93% |
| 09 | 585.0 .. 650.0 | 422 | 6.80% |
| 10 | 650.0 .. 715.0 | 446 | 7.19% |
| 11 | 715.0 .. 780.0 | 553 | 8.92% |
| 12 | 780.0 .. 845.0 | 455 | 7.34% |
| 13 | 845.0 .. 910.0 | 670 | 10.80% |

### Full-Load Shape (100% raw full, actual true-ts -> output, 0..2 frames)

| bin | latency range (cycles) | samples | pct |
|---:|---|---:|---:|
| 00 | 0.0 .. 130.0 | 0 | 0.00% |
| 01 | 130.0 .. 260.0 | 0 | 0.00% |
| 02 | 260.0 .. 390.0 | 0 | 0.00% |
| 03 | 390.0 .. 520.0 | 0 | 0.00% |
| 04 | 520.0 .. 650.0 | 0 | 0.00% |
| 05 | 650.0 .. 780.0 | 155 | 0.29% |
| 06 | 780.0 .. 910.0 | 31703 | 58.75% |
| 07 | 910.0 .. 1040.0 | 22063 | 40.89% |
| 08 | 1040.0 .. 1170.0 | 42 | 0.08% |
| 09 | 1170.0 .. 1300.0 | 0 | 0.00% |
| 10 | 1300.0 .. 1430.0 | 0 | 0.00% |
| 11 | 1430.0 .. 1560.0 | 0 | 0.00% |
| 12 | 1560.0 .. 1690.0 | 0 | 0.00% |
| 13 | 1690.0 .. 1820.0 | 0 | 0.00% |

### Full-Load Shape (100% raw full, TLM true-ts -> output, 0..2 frames)

| bin | latency range (cycles) | samples | pct |
|---:|---|---:|---:|
| 00 | 0.0 .. 130.0 | 0 | 0.00% |
| 01 | 130.0 .. 260.0 | 0 | 0.00% |
| 02 | 260.0 .. 390.0 | 0 | 0.00% |
| 03 | 390.0 .. 520.0 | 0 | 0.00% |
| 04 | 520.0 .. 650.0 | 0 | 0.00% |
| 05 | 650.0 .. 780.0 | 166 | 0.31% |
| 06 | 780.0 .. 910.0 | 33432 | 62.01% |
| 07 | 910.0 .. 1040.0 | 20291 | 37.64% |
| 08 | 1040.0 .. 1170.0 | 25 | 0.05% |
| 09 | 1170.0 .. 1300.0 | 0 | 0.00% |
| 10 | 1300.0 .. 1430.0 | 0 | 0.00% |
| 11 | 1430.0 .. 1560.0 | 0 | 0.00% |
| 12 | 1560.0 .. 1690.0 | 0 | 0.00% |
| 13 | 1690.0 .. 1820.0 | 0 | 0.00% |

## Notes

- `true-ts -> frame-start` is the direct check for the marker-latch model you described. Its minimum should stay near zero because hits can land immediately before the next marker.
- `true-ts -> output` adds the within-frame serialization tail. In short mode the parser completes hits at offsets `9, 12, 16, 19, ...` cycles from the frame-start pulse, which is the measured wrapper-level equivalent of the raw `3.5 cycles / hit` packing cadence.
- `actual true-ts -> pop` is kept only as a secondary cross-check because it ignores the serializer tail and was the metric that made the previous report misleading.
- `TLM dropped` counts the hits that the corrected frame-marker model would discard when more than `256` hits land between adjacent frame markers.
- `RTL frame exact` and `RTL output exact` compare the live RTL trace against that TLM assignment on a per-hit basis.
