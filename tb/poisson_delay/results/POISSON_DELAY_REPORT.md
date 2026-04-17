# Poisson Delay Sweep

- Mode: short-mode Poisson, burst_size=1, noise=0
- Raw full-link reference: 0.285714 hits/cycle = 1 hit / 3.5 cycles
- Warmup cycles per point: 50000
- Measured cycles per point: 200000
- Drain timeout cycles: 400000

## Summary Table

| raw full % | hit_rate | accepted hits/cycle | avg occ | max occ | full cycles | queue p50/p90/p99/max | parser p50/p90/p99/max |
|---:|---:|---:|---:|---:|---:|---|---|
| 0 | 0 | 0.0000 | 0.0 | 0 | 0 | n/a/n/a/n/a/n/a | n/a/n/a/n/a/n/a |
| 10 | 1872 | 0.0285 | 14.8 | 45 | 0 | 528/837.0/903.0/912 | 537/845.0/911.0/920 |
| 20 | 3745 | 0.0571 | 31.8 | 70 | 0 | 560/847/905.8/914 | 568/855/914.0/923 |
| 40 | 7490 | 0.1143 | 73.3 | 125 | 0 | 639.0/860.0/908.0/916 | 648.0/868.0/916.0/925 |
| 60 | 11235 | 0.1714 | 125.5 | 194 | 0 | 734.0/878.0/911.0/920 | 742.0/886.0/919.0/929 |
| 80 | 14980 | 0.2286 | 187.8 | 239 | 0 | 826/898.0/917.0/932 | 834/906.0/926.0/941 |
| 90 | 16852 | 0.2553 | 222.1 | 256 | 557 | 201/571/714.0/754 | 209/580/723.0/763 |
| 95 | 17788 | 0.2626 | 236.6 | 256 | 2803 | 61.0/132.0/182.0/245 | 70.0/141.0/191.0/254 |
| 100 | 18725 | 0.2589 | 246.1 | 256 | 7561 | 22.0/70.0/109.0/157 | 27.0/78.0/117.0/166 |

## Long-Tail Buckets

| raw full % | >1 frame | >2 frames | >4 frames |
|---:|---:|---:|---:|
| 0 | 0.00% | 0.00% | 0.00% |
| 10 | 1.07% | 0.00% | 0.00% |
| 20 | 1.48% | 0.00% | 0.00% |
| 40 | 2.12% | 0.00% | 0.00% |
| 60 | 3.53% | 0.00% | 0.00% |
| 80 | 7.44% | 0.00% | 0.00% |
| 90 | 0.00% | 0.00% | 0.00% |
| 95 | 0.00% | 0.00% | 0.00% |
| 100 | 0.00% | 0.00% | 0.00% |

## Notes

- Queue delay is measured from hit enqueue into the L2 FIFO to the cycle where the FIFO pop occurs.
- Parser delay is measured from hit enqueue to parser-visible `hit_valid`.
- `full_cycles > 0` indicates the lane FIFO reached saturation during the measured window.
- At 100% of the raw 3.5-cycles/hit limit, framed overhead makes the lane slightly oversubscribed, so the tail can keep growing with longer runs.
