# MuTRiG True RTL A/B Report

Raw MuTRiG `frame_gen + generic_dp_fifo(256)` and the emulator shared the exact same offered-hit stream.
The comparison checks bit-exact parsed payload parity, exact recovered hit channel parity, and parser output-cycle parity.

## Short Mode

| Load | RATE_CFG | Offered | Accepted | Output | Drop | Out Rate | Avg Occ | Max Occ | Lat min | p50 | p90 | p99 | max |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 0% | 0 | 0 | 0 | 0 | 0 | 0.0000 | 0.0 | 0 | - | - | - | - | - |
| 10% | 1872 | 319 | 319 | 318 | 0 | 0.0291 | 14.7 | 32 | 98 | 493 | 850 | 917 | 922 |
| 20% | 3745 | 670 | 670 | 669 | 0 | 0.0613 | 33.7 | 69 | 176 | 562 | 850 | 917 | 922 |
| 40% | 7490 | 1281 | 1281 | 1280 | 0 | 0.1172 | 78.7 | 122 | 356 | 685 | 883 | 920 | 924 |
| 60% | 11235 | 1943 | 1943 | 1942 | 0 | 0.1778 | 131.2 | 184 | 503 | 756 | 885 | 924 | 932 |
| 80% | 14980 | 2537 | 2537 | 2536 | 0 | 0.2322 | 197.5 | 236 | 660 | 851 | 915 | 934 | 943 |
| 90% | 16852 | 2862 | 2862 | 2861 | 0 | 0.2620 | 230.6 | 255 | 740 | 892 | 925 | 940 | 947 |
| 100% | 18725 | 3147 | 2997 | 2996 | 150 | 0.2744 | 246.7 | 255 | 802 | 913 | 931 | 942 | 952 |

### Latency Distribution Parity

| Load | Raw p50/p90/p99 | Emu p50/p90/p99 | Max per-id cycle delta | Histogram abs delta | Mismatched bins | Max CDF delta |
| ---: | --- | --- | ---: | ---: | ---: | ---: |
| 0% | -/-/- | -/-/- | 0 | 0 | 0 | 0.0000 |
| 10% | 493/850/917 | 493/850/917 | 0 | 0 | 0 | 0.0000 |
| 20% | 562/850/917 | 562/850/917 | 0 | 0 | 0 | 0.0000 |
| 40% | 685/883/920 | 685/883/920 | 0 | 0 | 0 | 0.0000 |
| 60% | 756/885/924 | 756/885/924 | 0 | 0 | 0 | 0.0000 |
| 80% | 851/915/934 | 851/915/934 | 0 | 0 | 0 | 0.0000 |
| 90% | 892/925/940 | 892/925/940 | 0 | 0 | 0 | 0.0000 |
| 100% | 913/931/942 | 913/931/942 | 0 | 0 | 0 | 0.0000 |

## Long Mode

| Load | RATE_CFG | Offered | Accepted | Output | Drop | Out Rate | Avg Occ | Max Occ | Lat min | p50 | p90 | p99 | max |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 0% | 0 | 0 | 0 | 0 | 0 | 0.0000 | 0.0 | 0 | - | - | - | - | - |
| 10% | 1092 | 328 | 328 | 327 | 0 | 0.0176 | 15.0 | 39 | 167 | 874 | 1388 | 1552 | 1561 |
| 20% | 2185 | 650 | 650 | 649 | 0 | 0.0349 | 33.0 | 66 | 314 | 960 | 1433 | 1545 | 1563 |
| 40% | 4369 | 1267 | 1267 | 1266 | 0 | 0.0681 | 75.9 | 122 | 570 | 1136 | 1501 | 1554 | 1566 |
| 60% | 6554 | 1888 | 1888 | 1887 | 0 | 0.1015 | 128.9 | 173 | 901 | 1258 | 1517 | 1567 | 1579 |
| 80% | 8738 | 2489 | 2489 | 2488 | 0 | 0.1338 | 189.5 | 236 | 1122 | 1412 | 1536 | 1573 | 1606 |
| 90% | 9830 | 2819 | 2809 | 2808 | 10 | 0.1510 | 226.3 | 255 | 1321 | 1501 | 1568 | 1595 | 1618 |
| 100% | 10923 | 3099 | 2986 | 2985 | 113 | 0.1605 | 245.9 | 255 | 1399 | 1537 | 1578 | 1612 | 1632 |

### Latency Distribution Parity

| Load | Raw p50/p90/p99 | Emu p50/p90/p99 | Max per-id cycle delta | Histogram abs delta | Mismatched bins | Max CDF delta |
| ---: | --- | --- | ---: | ---: | ---: | ---: |
| 0% | -/-/- | -/-/- | 0 | 0 | 0 | 0.0000 |
| 10% | 874/1388/1552 | 874/1388/1552 | 0 | 0 | 0 | 0.0000 |
| 20% | 960/1433/1545 | 960/1433/1545 | 0 | 0 | 0 | 0.0000 |
| 40% | 1136/1501/1554 | 1136/1501/1554 | 0 | 0 | 0 | 0.0000 |
| 60% | 1258/1517/1567 | 1258/1517/1567 | 0 | 0 | 0 | 0.0000 |
| 80% | 1412/1536/1573 | 1412/1536/1573 | 0 | 0 | 0 | 0.0000 |
| 90% | 1501/1568/1595 | 1501/1568/1595 | 0 | 0 | 0 | 0.0000 |
| 100% | 1537/1578/1612 | 1537/1578/1612 | 0 | 0 | 0 | 0.0000 |

## Parity Checks

- All runs completed with `accept_mismatch_count=0`.
- All runs completed with `parser_data_mismatch_count=0` and `hit_channel_mismatch_count=0`.
- All runs completed with `parser_cycle_mismatch_count=0`.
- The collective latency plots also match exactly: every run completed with `hist_total_abs_delta=0`, `hist_mismatch_bins=0`, and `hist_max_cdf_delta=0.0000`.
- `frame_mark_mismatch_count` is an internal request-vs-generated phase counter and is not used for A/B pass/fail.

