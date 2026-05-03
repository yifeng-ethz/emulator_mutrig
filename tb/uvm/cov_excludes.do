## cov_excludes.do -- coverage exclusions applying the locked DV scope
## Author: Yifeng Wang
## Version : 26.2.1
## Date    : 20260503
##
## Per tb/doc/FEATURE_AXES.md the standalone DV gate covers only:
##  - BYTE_STREAM_ENABLE = 0 (the type0-only build axis point)
##  - Per-lane 64-bit counter upper bits on at least ONE lane
##    (instance-level toggle policy for the saturating counters)
##
## Syntax conforms to QuestaSim 2026.1 `coverage exclude` help:
##   coverage exclude -togglenode <node_list> -scope <path_list> ...
##
## Note on BYTE_STREAM_ENABLE=1 axis: the be_mutrig_frame_assembler
## design unit is generate-gated off in this build (see
## emulator_mutrig.sv line 412), so it never appears in the coverage
## database. No `-srcfile` exclusion is needed; the waiver is purely
## a documentation matter recorded in tb/doc/FEATURE_AXES.md and the
## DV_REPORT Non-Claims block.

# Per-lane saturating-counter toggles for lanes 1..7. Lane 0 is
# preloaded by the LONG bucket (force on frame_count and hit_count)
# and proves the upper-half toggle path. Lanes 1..7 share the
# identical RTL and do not need separate preloads.
foreach lane {1 2 3 4 5 6 7} {
    coverage exclude -togglenode {frame_count hit_count} \
        -scope /tb_central_top/u_dut/lane_gen\[$lane\]/u_lane_emitter \
        -comment "FEATURE_AXES.md sec 3 -- lane 0 preload covers the path"
}
