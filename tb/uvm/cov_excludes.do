## cov_excludes.do — coverage exclusions applying the locked DV scope
## Author: Yifeng Wang
## Version : 26.2.0
## Date    : 20260502
##
## Per tb/doc/FEATURE_AXES.md the standalone DV gate covers only:
##  - BYTE_STREAM_ENABLE = 0 (the type0-only build axis point)
##  - Per-lane 64-bit counter upper bits on at least ONE lane
##    (instance-level toggle policy for the saturating counters)
##
## We exclude the waived areas so the headline coverage number reflects
## the locked DV scope rather than counting un-instantiated logic and
## redundant per-lane counter replicas as misses.

# 1. Frame-assembler instances are generate-gated off when
#    BYTE_STREAM_ENABLE=0. They appear in the netlist as no-driver
#    nodes; exclude their coverage entirely under the waived-axis policy.
coverage exclude -src be_mutrig_frame_assembler.sv -scope /tb_central_top/u_dut/*

# 2. Per-lane counter upper-bit toggles: lane 0 is preloaded by the
#    LONG bucket and proves the path. Lanes 1-7 share the same RTL and
#    do not need separate preload runs to demonstrate the path.
foreach lane {1 2 3 4 5 6 7} {
    coverage exclude -toggle -scope /tb_central_top/u_dut/lane_gen\[$lane\]/u_lane_emitter -nodes {frame_count[63:32] hit_count[63:32]}
}

# 3. Status-only registers that are RO observation paths and never
#    written by the test set (e.g. last-write-data on lanes that have
#    no writes after reset). The bank counters are exercised by the
#    LONG bucket at lane 0.
