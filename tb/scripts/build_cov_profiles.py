#!/usr/bin/env python3
"""Build coverage profile JSON, DV_COV.md, and SV loader skeleton for emulator_mutrig.

Source of truth: the four DV bucket files (DV_BASIC, DV_EDGE, DV_PROF, DV_ERROR)
and the architecture in doc/RTL_PLAN_central_trigger.md. Per-case bin
assignment derived from the case scenario, NOT invented.
"""

import json
import os
from collections import OrderedDict

# ---------------------------------------------------------------------------
# Coverpoint inventory (built from architecture, not invented)
# ---------------------------------------------------------------------------

# 1. CSR address space (per CSR map §3 in RTL_PLAN_central_trigger.md):
#    0x00..0x3F. RW vs RO classification taken from the CSR table.
CSR_RW = {
    0x02: "SCRATCH",
    0x07: "CENTRAL", 0x08: "SIGNAL", 0x09: "BACKGROUND",
    0x0A: "MUTRIG_FORMAT",
    0x0B: "RATES",
    0x0C: "CLUSTER_GEOM_FIX", 0x0D: "CLUSTER_GEOM_RANDOM",
    0x0E: "PRNG_SEED", 0x0F: "TIMEBASE_SEED",
    0x12: "LANE_ENABLE", 0x15: "ERROR_INJECT",
}
CSR_W1P = {0x13: "FIRE"}
CSR_RO = {
    0x00: "UID", 0x03: "LAST_RD_ADDR", 0x04: "LAST_RD_DATA",
    0x05: "LAST_WR_ADDR", 0x06: "LAST_WR_DATA",
    0x14: "BANK_STATUS",
}
CSR_RW_RO = {0x01: "META"}  # write selects, read returns
# 0x10, 0x11, 0x16..0x1F reserved RO=0
# 0x20..0x3F per-lane LANE_FRAME_LO/HI, LANE_HIT_LO/HI; lane*4 + offset
# LANE_FRAME_HI is RO/W1C (sticky bits are W1C)


# 2. Mode matrix bins: 2*2*2*2*3 = 48
SIG_MODES = ["INTERNAL", "EXTERNAL"]
SUB_MODES = ["POISSON", "PERIODIC"]
GEOM_MODES = ["FIX", "RANDOM"]
BKG_MODES = ["OFF", "ON"]
MIRROR_MODES = ["LEFT_ONLY", "RIGHT_ONLY", "MIRRORED"]

# 3. Cluster size bins
CLUSTER_SIZE_BINS = [1, 2, 32, 33, 64, 127, 128, 256]

# 4. Mirror offset bins
MIRROR_OFFSET_BINS = [-128, -32, -1, 0, 1, 32, 127]

# 5. Per-lane channel-count crosses
LANE_CHCNT_BINS = [(L, C) for L in range(8) for C in [1, 4, 16, 32]]

# 6. Run-control legal one-hots and transitions:
#    bits[0]=IDLE, [1]=RUN_PREPARE, [2]=SYNC, [3]=RUNNING,
#    [4]=TERMINATING, [5]=LINK_TEST, [6]=SYNC_TEST,
#    [7]=RESET, [8]=OUT_OF_DAQ.
RUN_STATES = {
    "IDLE": 0, "RUN_PREPARE": 1, "SYNC": 2, "RUNNING": 3,
    "TERMINATING": 4, "LINK_TEST": 5, "SYNC_TEST": 6,
    "RESET": 7, "OUT_OF_DAQ": 8,
}
LEGAL_TRANSITIONS = [
    ("IDLE", "RUN_PREPARE"), ("RUN_PREPARE", "SYNC"),
    ("SYNC", "RUNNING"), ("RUNNING", "TERMINATING"),
    ("TERMINATING", "IDLE"), ("IDLE", "RESET"),
    ("IDLE", "OUT_OF_DAQ"), ("IDLE", "LINK_TEST"),
    ("IDLE", "SYNC_TEST"),
]

# 7. Backpressure depth bins
TICKET_FIFO_BINS = [0, 1, 4, 7, 8]   # 8 = full
L2_FIFO_BINS = [0, 64, 128, 192, 255, 256]   # 256 = full

# 8. Counter boundary crossings
COUNTER_BINS_32 = [(L, "32bit") for L in range(8)] + [(L, "32bit_hit") for L in range(8)]
COUNTER_BINS_60 = [(L, "60bit") for L in range(8)] + [(L, "60bit_hit") for L in range(8)]

# 9. Build axes
LANE_COUNT_AXIS = [1, 2, 4, 8]
BYTE_STREAM_AXIS = [0, 1]


def csr_addr_bin(addr):
    return f"csr_addr_0x{addr:02X}"


def csr_access_bin(addr):
    if addr in CSR_RW:
        return "csr_access_RW"
    if addr in CSR_RO:
        return "csr_access_RO"
    if addr in CSR_W1P:
        return "csr_access_W1P"
    if addr in CSR_RW_RO:
        return "csr_access_RW_RO"
    if 0x20 <= addr <= 0x3F:
        return "csr_access_LANE_BLOCK"
    if 0x16 <= addr <= 0x1F or addr in (0x10, 0x11):
        return "csr_access_RSVD_RO"
    return "csr_access_OOR"


def mode_bin(sig, sub, geom, bkg, mirror):
    return f"mode_{sig}_{sub}_{geom}_BKG{bkg}_MIR{mirror}"


# ---------------------------------------------------------------------------
# Build the canonical coverage-bin universe so DV_COV.md can list them all.
# ---------------------------------------------------------------------------

def all_bins():
    bins = []
    # CSR addresses (64 addresses)
    for a in range(0x40):
        bins.append(csr_addr_bin(a))
    # CSR access classes
    for c in ["RW", "RO", "W1P", "RW_RO", "LANE_BLOCK", "RSVD_RO", "OOR"]:
        bins.append(f"csr_access_{c}")
    # Mode matrix 48
    for sig in SIG_MODES:
        for sub in SUB_MODES:
            for geom in GEOM_MODES:
                for bkg in BKG_MODES:
                    for m in MIRROR_MODES:
                        bins.append(mode_bin(sig, sub, geom, bkg, m))
    # Cluster size
    for s in CLUSTER_SIZE_BINS:
        bins.append(f"cluster_size_{s}")
    # Mirror offset
    for o in MIRROR_OFFSET_BINS:
        sign = "neg" if o < 0 else "pos" if o > 0 else "zero"
        bins.append(f"mirror_offset_{sign}{abs(o)}")
    # Per-lane × cluster channel count
    for (L, C) in LANE_CHCNT_BINS:
        bins.append(f"lane{L}_clus{C}")
    # Run-control states (one-hot)
    for s in RUN_STATES:
        bins.append(f"runctl_state_{s}")
    # Run-control legal transitions
    for (a, b) in LEGAL_TRANSITIONS:
        bins.append(f"runctl_trans_{a}_to_{b}")
    # Run-control illegal markers
    bins.append("runctl_illegal_multibit")
    bins.append("runctl_illegal_allzero")
    # Backpressure ticket FIFO depth
    for d in TICKET_FIFO_BINS:
        bins.append(f"ticket_fifo_depth_{d}")
    # Backpressure L2 FIFO depth
    for d in L2_FIFO_BINS:
        bins.append(f"l2_fifo_depth_{d}")
    # Counter boundary crossings
    for L in range(8):
        bins.append(f"frame_count_lane{L}_32bit")
        bins.append(f"frame_count_lane{L}_60bit")
        bins.append(f"hit_count_lane{L}_32bit")
        bins.append(f"hit_count_lane{L}_60bit")
    # Build axes cross
    for lc in LANE_COUNT_AXIS:
        for bs in BYTE_STREAM_AXIS:
            bins.append(f"build_LC{lc}_BS{bs}")
    # Misc structural bins required by spec
    extras = [
        "uid_readback",
        "meta_VERSION", "meta_DATE", "meta_GIT", "meta_INSTANCE_ID",
        "scratch_liveness",
        "last_rd_capture", "last_wr_capture", "last_rd_self_stable",
        "last_clear_on_irst",
        "global_enable_gate", "lane_enable_mask_sweep",
        "fire_w1p_singleshot", "fire_csr_conduit_or", "fire_edge_detect",
        "ticket_overflow_count_inc", "ticket_overflow_saturate",
        "fifo_full_sticky_set", "fifo_full_sticky_w1c",
        "ticket_overflow_sticky_set", "ticket_overflow_sticky_w1c",
        "engine_busy_high_water",
        "tcc_seed_default", "ecc_seed_default",
        "tcc_seed_custom", "ecc_seed_custom",
        "ecc_phase_n0", "ecc_phase_n1", "ecc_phase_n5", "ecc_phase_n20",
        "ecc_phase_n1000", "ecc_phase_n_full_period",
        "tcc_seed_zero_invalid", "ecc_seed_zero_invalid",
        "frame_short_mode", "frame_long_mode",
        "frame_empty", "frame_with_one_hit", "frame_at_event_max",
        "type0_sop", "type0_eop", "type0_endofrun",
        "type0_vs_deassembly_parity", "type0_error_inject_stub",
        "type0_error_inject_active",
        "byte_stream_idle_K28_5", "byte_stream_active",
        "asic_id_base_zero", "asic_id_base_nonzero",
        "smb_A_only", "smb_B_only", "smb_cross",
        "mirror_clamp_high", "mirror_clamp_low",
        "rand_center_uniform", "rand_side_pick_uniform",
        "prng_seed_reproducibility", "prng_seed_diverge",
        "bkg_uniform_per_channel", "bkg_full_lane_coverage",
        "engine_round_robin", "engine_back_to_back",
        "inject_in_internal", "inject_in_external",
        "inject_during_idle_drop", "inject_during_term_drop",
        "inject_during_sync_drop",
        "internal_dropped_on_stall",
        "csr_during_irst", "csr_during_sync", "csr_during_running",
        "csr_atomic_write", "csr_atomic_read",
        "csr_lo_hi_atomic_snapshot",
        "soak_1M", "soak_10M", "soak_100M", "soak_1B",
        "all_buckets_frame_baseline",
        "lane_count_0_hits", "lane_disabled_silent",
        "lane_reenabled_resume",
        "rate_zero", "rate_low", "rate_mid", "rate_high", "rate_max",
        "noise_rate_zero", "noise_rate_low", "noise_rate_mid",
        "noise_rate_high", "noise_rate_max",
        "fine_time_jitter_t", "fine_time_jitter_e",
        "tcc_full_period_observed",
        "round_robin_pointer_advance",
        "engine_busy_drops",
        "frame_boundary_during_dispense",
        "frame_boundary_at_inject",
    ]
    for e in extras:
        bins.append(e)
    return bins


ALL_BINS = all_bins()
ASSERTED_BINS = set(ALL_BINS)


# ---------------------------------------------------------------------------
# Per-case profile generator. Each case contributes one or more bins, plus
# (when randomised in soak) a knob set centred on its directed value.
# ---------------------------------------------------------------------------

def D(knobs=None):
    return {"type": "directed", "knobs": knobs or {}}


def R(knobs):
    return {"type": "promoted", "knobs": knobs}


def lcg_seed_knob():
    return {"distribution": "uniform_int", "min": 0, "max": "0xFFFFFFFF"}


def uniform_int(lo, hi):
    if isinstance(hi, int) and hi > 0xFFFF:
        hi = f"0x{hi:X}"
    return {"distribution": "uniform_int", "min": lo, "max": hi}


def signed_uniform(lo, hi):
    return {"distribution": "uniform_int_signed", "min": lo, "max": hi}


def categorical(values):
    return {"distribution": "categorical", "values": values}


# ---- BASIC bucket -----------------------------------------------------------

CASES = OrderedDict()

# Common CSR Golden Header (B001-B016)
CASES["B001"] = (["csr_addr_0x00", "csr_access_RO", "uid_readback"], D())
CASES["B002"] = (["csr_addr_0x00", "csr_access_RO", "uid_readback"],
                 R({"PRNG_SEED": lcg_seed_knob(),
                    "write_value": uniform_int(0, 0xFFFFFFFF)}))
CASES["B003"] = (["csr_addr_0x01", "csr_access_RW_RO", "meta_VERSION"], D())
CASES["B004"] = (["csr_addr_0x01", "csr_access_RW_RO", "meta_DATE"], D())
CASES["B005"] = (["csr_addr_0x01", "csr_access_RW_RO", "meta_GIT"], D())
CASES["B006"] = (["csr_addr_0x01", "csr_access_RW_RO", "meta_INSTANCE_ID"], D())
CASES["B007"] = (["csr_addr_0x02", "csr_access_RW", "scratch_liveness"],
                 R({"scratch_value": uniform_int(0, 0xFFFFFFFF),
                    "PRNG_SEED": lcg_seed_knob()}))
CASES["B008"] = (["csr_addr_0x02", "csr_access_RW", "scratch_liveness"],
                 R({"scratch_value": uniform_int(0, 0xFFFFFFFF),
                    "PRNG_SEED": lcg_seed_knob()}))
CASES["B009"] = (["csr_addr_0x02", "csr_access_RW", "scratch_liveness",
                  "last_clear_on_irst"], D())
CASES["B010"] = (["csr_addr_0x03", "csr_access_RO", "last_rd_capture"], D())
CASES["B011"] = (["csr_addr_0x04", "csr_access_RO", "last_rd_capture"], D())
CASES["B012"] = (["csr_addr_0x03", "csr_addr_0x04", "csr_access_RO",
                  "last_rd_self_stable"], D())
CASES["B013"] = (["csr_addr_0x05", "csr_access_RO", "last_wr_capture"], D())
CASES["B014"] = (["csr_addr_0x06", "csr_access_RO", "last_wr_capture"], D())
CASES["B015"] = (["csr_addr_0x03", "csr_addr_0x04", "csr_addr_0x05",
                  "csr_addr_0x06", "last_clear_on_irst"], D())
CASES["B016"] = (["csr_addr_0x3F", "csr_access_OOR"], D())

# Run-Control Decode and Gating (B017-B032)
CASES["B017"] = (["runctl_state_RUN_PREPARE",
                  "runctl_trans_IDLE_to_RUN_PREPARE"], D())
CASES["B018"] = (["runctl_state_SYNC",
                  "runctl_trans_RUN_PREPARE_to_SYNC"], D())
CASES["B019"] = (["runctl_state_RUNNING",
                  "runctl_trans_SYNC_to_RUNNING"], D())
CASES["B020"] = (["runctl_state_TERMINATING",
                  "runctl_trans_RUNNING_to_TERMINATING"], D())
CASES["B021"] = (["runctl_state_IDLE",
                  "runctl_trans_TERMINATING_to_IDLE",
                  "type0_endofrun", "byte_stream_idle_K28_5"], D())
CASES["B022"] = (["runctl_state_RESET", "runctl_trans_IDLE_to_RESET"], D())
CASES["B023"] = (["runctl_state_OUT_OF_DAQ",
                  "runctl_trans_IDLE_to_OUT_OF_DAQ",
                  "byte_stream_idle_K28_5"], D())
CASES["B024"] = (["runctl_state_LINK_TEST",
                  "runctl_trans_IDLE_to_LINK_TEST"], D())
CASES["B025"] = (["runctl_state_SYNC_TEST",
                  "runctl_trans_IDLE_to_SYNC_TEST"], D())
CASES["B026"] = (["runctl_state_RUNNING"], D())
CASES["B027"] = (["runctl_illegal_multibit"], D())
CASES["B028"] = (["runctl_trans_IDLE_to_RUN_PREPARE",
                  "runctl_trans_RUN_PREPARE_to_SYNC",
                  "runctl_trans_SYNC_to_RUNNING"], D())
CASES["B029"] = (["runctl_state_RUN_PREPARE"], D())
CASES["B030"] = (["inject_during_idle_drop"], D())
CASES["B031"] = (["global_enable_gate"], D())
CASES["B032"] = (["global_enable_gate"], D())

# SIGNAL INTERNAL Poisson (B033-B048)
def poisson_case(rate, seed_random=True):
    bins = [mode_bin("INTERNAL", "POISSON", "FIX", "OFF", "MIRRORED"),
            "rate_zero" if rate == 0 else
            "rate_max" if rate == 0xFFFF else
            "rate_low" if rate <= 0x0010 else
            "rate_high" if rate >= 0xC000 else
            "rate_mid"]
    return bins


CASES["B033"] = (poisson_case(0) + ["lane_count_0_hits"],
                 R({"hit_rate": uniform_int(0, 0x000F),
                    "PRNG_SEED": lcg_seed_knob()}))
CASES["B034"] = (poisson_case(0x0001),
                 R({"hit_rate": uniform_int(0x0001, 0x0010),
                    "PRNG_SEED": lcg_seed_knob()}))
CASES["B035"] = (poisson_case(0x0100),
                 R({"hit_rate": uniform_int(0x0080, 0x01FF),
                    "PRNG_SEED": lcg_seed_knob()}))
CASES["B036"] = (poisson_case(0x1000),
                 R({"hit_rate": uniform_int(0x0800, 0x1FFF),
                    "PRNG_SEED": lcg_seed_knob()}))
CASES["B037"] = (poisson_case(0x8000),
                 R({"hit_rate": uniform_int(0x6000, 0x9FFF),
                    "PRNG_SEED": lcg_seed_knob()}))
CASES["B038"] = (poisson_case(0xFFFF),
                 R({"hit_rate": uniform_int(0xF000, 0xFFFF),
                    "PRNG_SEED": lcg_seed_knob()}))
CASES["B039"] = ([mode_bin("INTERNAL", "POISSON", "FIX", "OFF", "MIRRORED"),
                  "prng_seed_reproducibility"], D())
CASES["B040"] = ([mode_bin("INTERNAL", "POISSON", "FIX", "OFF", "MIRRORED"),
                  "prng_seed_diverge"],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["B041"] = ([mode_bin("INTERNAL", "POISSON", "FIX", "OFF", "MIRRORED"),
                  "prng_seed_reproducibility"],
                 R({"hit_rate": uniform_int(0x0010, 0xFFF0),
                    "PRNG_SEED": lcg_seed_knob()}))
CASES["B042"] = ([mode_bin("INTERNAL", "POISSON", "FIX", "OFF", "MIRRORED"),
                  "cluster_size_1", "lane0_clus1"],
                 R({"hit_rate": uniform_int(0x0040, 0x0400),
                    "PRNG_SEED": lcg_seed_knob()}))
CASES["B043"] = ([mode_bin("INTERNAL", "POISSON", "FIX", "OFF", "MIRRORED"),
                  "cluster_size_32", "lane0_clus32"],
                 R({"hit_rate": uniform_int(0x0040, 0x0400),
                    "PRNG_SEED": lcg_seed_knob()}))
CASES["B044"] = ([mode_bin("INTERNAL", "POISSON", "FIX", "OFF", "MIRRORED"),
                  "lane_disabled_silent"],
                 R({"hit_rate": uniform_int(0x1000, 0x4000),
                    "lane_disable_idx": uniform_int(0, 7),
                    "PRNG_SEED": lcg_seed_knob()}))
CASES["B045"] = ([mode_bin("INTERNAL", "POISSON", "FIX", "OFF", "MIRRORED"),
                  "ticket_overflow_count_inc",
                  "ticket_fifo_depth_8"],
                 R({"hit_rate": uniform_int(0xC000, 0xFFFF),
                    "PRNG_SEED": lcg_seed_knob()}))
CASES["B046"] = ([mode_bin("INTERNAL", "POISSON", "FIX", "OFF", "MIRRORED"),
                  "ticket_fifo_depth_0"],
                 R({"hit_rate": uniform_int(0x4000, 0xC000),
                    "PRNG_SEED": lcg_seed_knob()}))
CASES["B047"] = ([mode_bin("INTERNAL", "POISSON", "FIX", "OFF", "MIRRORED")],
                 R({"hit_rate": uniform_int(0x0100, 0x4000),
                    "PRNG_SEED": lcg_seed_knob()}))
CASES["B048"] = ([mode_bin("INTERNAL", "POISSON", "FIX", "OFF", "MIRRORED"),
                  mode_bin("EXTERNAL", "POISSON", "FIX", "OFF", "MIRRORED")],
                 R({"hit_rate": uniform_int(0x0100, 0xFFFF),
                    "PRNG_SEED": lcg_seed_knob()}))

# SIGNAL INTERNAL Periodic (B049-B064)
def periodic_case(rate):
    bins = [mode_bin("INTERNAL", "PERIODIC", "FIX", "OFF", "MIRRORED"),
            "rate_max" if rate == 0xFFFF else
            "rate_zero" if rate == 0 else
            "rate_high" if rate >= 0x4000 else
            "rate_mid" if rate >= 0x0100 else
            "rate_low"]
    return bins


CASES["B049"] = (periodic_case(0xFFFF), D())
CASES["B050"] = (periodic_case(0x8000), D())
CASES["B051"] = (periodic_case(0x4000), D())
CASES["B052"] = (periodic_case(0x1000), D())
CASES["B053"] = (periodic_case(0x0100), D())
CASES["B054"] = (periodic_case(0) + ["lane_count_0_hits"], D())
CASES["B055"] = (periodic_case(0x4000) + ["ticket_fifo_depth_4"], D())
CASES["B056"] = (periodic_case(0x4000) + ["runctl_state_SYNC"], D())
CASES["B057"] = ([mode_bin("INTERNAL", "PERIODIC", "FIX", "OFF", "MIRRORED"),
                  mode_bin("INTERNAL", "POISSON", "FIX", "OFF", "MIRRORED")],
                 D())
CASES["B058"] = (periodic_case(0x4000) + ["cluster_size_32",
                                           "lane2_clus32", "lane3_clus1"],
                 D())
CASES["B059"] = ([mode_bin("INTERNAL", "PERIODIC", "RANDOM", "OFF", "MIRRORED"),
                  "cluster_size_2"], D())
CASES["B060"] = (periodic_case(0x4000), D())
CASES["B061"] = (periodic_case(0x4000) + ["prng_seed_reproducibility"], D())
CASES["B062"] = (periodic_case(0x4000) + ["fine_time_jitter_t",
                                           "fine_time_jitter_e"], D())
CASES["B063"] = ([mode_bin("INTERNAL", "PERIODIC", "FIX", "ON", "MIRRORED")],
                 D())
CASES["B064"] = (periodic_case(0x4000) + ["global_enable_gate"], D())

# SIGNAL External Inject (B065-B080)
CASES["B065"] = (["fire_w1p_singleshot", "fire_csr_conduit_or",
                  "csr_addr_0x13", "csr_access_W1P"], D())
CASES["B066"] = (["fire_edge_detect", "fire_csr_conduit_or"], D())
CASES["B067"] = (["fire_edge_detect", "fire_csr_conduit_or"], D())
CASES["B068"] = (["fire_edge_detect", "fire_csr_conduit_or"], D())
CASES["B069"] = (["inject_in_internal",
                  mode_bin("INTERNAL", "POISSON", "FIX", "OFF", "MIRRORED")],
                 D())
CASES["B070"] = (["inject_in_external",
                  mode_bin("EXTERNAL", "POISSON", "FIX", "OFF", "MIRRORED")],
                 D())
CASES["B071"] = (["inject_in_external",
                  mode_bin("EXTERNAL", "POISSON", "FIX", "OFF", "MIRRORED")],
                 D())
CASES["B072"] = (["fire_csr_conduit_or", "global_enable_gate"], D())
CASES["B073"] = (["inject_during_idle_drop"], D())
CASES["B074"] = (["inject_during_term_drop"], D())
CASES["B075"] = (["inject_during_sync_drop"], D())
CASES["B076"] = (["fire_edge_detect"], D())
CASES["B077"] = (["fire_w1p_singleshot"], D())
CASES["B078"] = (["fire_csr_conduit_or", "internal_dropped_on_stall"], D())
CASES["B079"] = (["smb_cross", "cluster_size_16"
                  if False else "cluster_size_1",
                  mode_bin("INTERNAL", "POISSON", "FIX", "OFF", "MIRRORED")],
                 D())
CASES["B080"] = ([mode_bin("INTERNAL", "POISSON", "RANDOM", "OFF", "MIRRORED"),
                  "cluster_size_1"], D())

# Cluster Geom FIX (B081-B096)
CASES["B081"] = ([mode_bin("EXTERNAL", "POISSON", "FIX", "OFF", "MIRRORED"),
                  "cluster_size_1", "lane0_clus1", "smb_A_only"], D())
CASES["B082"] = (["cluster_size_1", "smb_A_only"], D())
CASES["B083"] = (["cluster_size_1", "smb_B_only"], D())
CASES["B084"] = (["cluster_size_1", "smb_B_only"], D())
CASES["B085"] = (["cluster_size_32", "lane0_clus32", "smb_A_only"], D())
CASES["B086"] = (["cluster_size_33", "smb_A_only"], D())
CASES["B087"] = (["cluster_size_64", "smb_A_only"], D())
CASES["B088"] = (["cluster_size_128", "smb_A_only"], D())
CASES["B089"] = (["cluster_size_128", "smb_cross"], D())
CASES["B090"] = (["cluster_size_256", "smb_cross"], D())
CASES["B091"] = ([mode_bin("EXTERNAL", "POISSON", "FIX", "OFF", "MIRRORED")],
                 D())
CASES["B092"] = (["cluster_size_1", "smb_A_only", "lane2_clus1"], D())
CASES["B093"] = (["cluster_size_32", "smb_A_only", "lane1_clus32"], D())
CASES["B094"] = (["cluster_size_33", "smb_A_only"], D())
CASES["B095"] = (["lane_disabled_silent", "cluster_size_64"], D())
CASES["B096"] = (["cluster_size_256", "smb_cross"], D())

# Cluster Geom RANDOM (B097-B112)
CASES["B097"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "LEFT_ONLY"),
                  "cluster_size_1", "smb_A_only"], D())
CASES["B098"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "RIGHT_ONLY"),
                  "cluster_size_1", "smb_B_only"], D())
CASES["B099"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "MIRRORED"),
                  "cluster_size_1", "mirror_offset_zero0"], D())
CASES["B100"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "MIRRORED"),
                  "cluster_size_1", "mirror_offset_pos1"],
                 R({"mirror_offset": signed_uniform(1, 8),
                    "PRNG_SEED": lcg_seed_knob()}))
CASES["B101"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "MIRRORED"),
                  "cluster_size_1", "mirror_offset_neg1"],
                 R({"mirror_offset": signed_uniform(-8, -1),
                    "PRNG_SEED": lcg_seed_knob()}))
CASES["B102"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "MIRRORED"),
                  "mirror_offset_zero0"], D())
CASES["B103"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "MIRRORED"),
                  "cluster_size_128", "mirror_offset_zero0"], D())
CASES["B104"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "LEFT_ONLY"),
                  "cluster_size_64", "smb_A_only"], D())
CASES["B105"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "LEFT_ONLY"),
                  "cluster_size_128", "smb_A_only"], D())
CASES["B106"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "MIRRORED"),
                  "mirror_clamp_high"], D())
CASES["B107"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "MIRRORED"),
                  "cluster_size_1"], D())
CASES["B108"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "LEFT_ONLY"),
                  "rand_center_uniform"],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["B109"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "LEFT_ONLY"),
                  "prng_seed_reproducibility"], D())
CASES["B110"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "MIRRORED"),
                  "global_enable_gate"], D())
CASES["B111"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "LEFT_ONLY"),
                  "smb_A_only"], D())
CASES["B112"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "MIRRORED"),
                  "rand_side_pick_uniform"],
                 R({"PRNG_SEED": lcg_seed_knob()}))

# BACKGROUND IID (B113-B128)
def bkg_case(rate):
    bins = [mode_bin("EXTERNAL", "POISSON", "FIX", "ON", "MIRRORED"),
            "noise_rate_zero" if rate == 0 else
            "noise_rate_max" if rate == 0xFFFF else
            "noise_rate_low" if rate <= 0x0010 else
            "noise_rate_high" if rate >= 0xC000 else
            "noise_rate_mid"]
    return bins


CASES["B113"] = ([mode_bin("EXTERNAL", "POISSON", "FIX", "OFF", "MIRRORED"),
                  "noise_rate_zero"], D())
CASES["B114"] = (bkg_case(0) + ["lane_count_0_hits"], D())
CASES["B115"] = (bkg_case(0x0001),
                 R({"noise_rate": uniform_int(0x0001, 0x0010),
                    "PRNG_SEED": lcg_seed_knob()}))
CASES["B116"] = (bkg_case(0x0100),
                 R({"noise_rate": uniform_int(0x0080, 0x01FF),
                    "PRNG_SEED": lcg_seed_knob()}))
CASES["B117"] = (bkg_case(0xFFFF),
                 R({"noise_rate": uniform_int(0xF000, 0xFFFF),
                    "PRNG_SEED": lcg_seed_knob()}))
CASES["B118"] = (bkg_case(0x4000) + ["bkg_full_lane_coverage"], D())
CASES["B119"] = (bkg_case(0x4000) + ["fine_time_jitter_t"], D())
CASES["B120"] = (bkg_case(0x4000) + ["tcc_full_period_observed"], D())
CASES["B121"] = ([mode_bin("INTERNAL", "POISSON", "FIX", "ON", "MIRRORED")], D())
CASES["B122"] = ([mode_bin("EXTERNAL", "POISSON", "FIX", "ON", "MIRRORED")], D())
CASES["B123"] = (bkg_case(0x4000) + ["runctl_trans_RUNNING_to_TERMINATING"], D())
CASES["B124"] = (bkg_case(0x4000) + ["global_enable_gate"], D())
CASES["B125"] = (bkg_case(0x4000) + ["prng_seed_reproducibility"], D())
CASES["B126"] = (bkg_case(0x4000) + ["bkg_uniform_per_channel"],
                 R({"noise_rate": uniform_int(0x1000, 0x8000),
                    "PRNG_SEED": lcg_seed_knob()}))
CASES["B127"] = (bkg_case(0x4000) + ["engine_round_robin"], D())
CASES["B128"] = (bkg_case(0x4000) + ["bkg_full_lane_coverage"], D())

# ---- EDGE bucket -----------------------------------------------------------

# Channel-Range Boundaries (E001-E016)
CASES["E001"] = (["cluster_size_1", "smb_A_only", "lane0_clus1"], D())
CASES["E002"] = (["cluster_size_1", "smb_B_only"], D())
CASES["E003"] = (["cluster_size_1", "smb_B_only"], D())
CASES["E004"] = (["cluster_size_2", "smb_cross"], D())
CASES["E005"] = (["cluster_size_2", "smb_A_only"], D())
CASES["E006"] = (["cluster_size_2", "smb_B_only"], D())
CASES["E007"] = (["cluster_size_1", "smb_B_only"], D())
CASES["E008"] = (["cluster_size_256", "smb_cross"], D())
CASES["E009"] = (["cluster_size_256", "lane_disabled_silent"], D())
CASES["E010"] = (["cluster_size_33", "smb_cross"], D())
CASES["E011"] = (["cluster_size_128", "smb_A_only"], D())
CASES["E012"] = (["cluster_size_128", "smb_B_only"], D())
CASES["E013"] = (["lane7_clus16"], D())
CASES["E014"] = (["smb_B_only"], D())
CASES["E015"] = (["cluster_size_1", "smb_A_only", "lane2_clus1"], D())
CASES["E016"] = (["cluster_size_1", "smb_B_only", "lane6_clus1"], D())

# Cluster Size Boundaries (E017-E032)
CASES["E017"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "MIRRORED"),
                  "cluster_size_1", "mirror_offset_zero0"], D())
CASES["E018"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "MIRRORED"),
                  "cluster_size_2", "mirror_offset_zero0"], D())
CASES["E019"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "MIRRORED"),
                  "mirror_offset_zero0"], D())
CASES["E020"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "MIRRORED"),
                  "cluster_size_128"], D())
CASES["E021"] = (["cluster_size_128", "mirror_clamp_high"], D())
CASES["E022"] = (["cluster_size_1"], D())
CASES["E023"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "LEFT_ONLY"),
                  "cluster_size_1", "smb_A_only"], D())
CASES["E024"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "LEFT_ONLY"),
                  "cluster_size_1", "smb_A_only"], D())
CASES["E025"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "LEFT_ONLY"),
                  "smb_A_only", "mirror_clamp_low"], D())
CASES["E026"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "LEFT_ONLY"),
                  "smb_A_only", "mirror_clamp_high"], D())
CASES["E027"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "LEFT_ONLY"),
                  "cluster_size_128", "smb_A_only"], D())
CASES["E028"] = (["cluster_size_1"], D())
CASES["E029"] = (["cluster_size_32", "ticket_fifo_depth_1"], D())
CASES["E030"] = (["cluster_size_1", "lane0_clus1", "lane1_clus1",
                  "lane2_clus1", "lane3_clus1", "lane4_clus1",
                  "lane5_clus1", "lane6_clus1", "lane7_clus1"], D())
CASES["E031"] = (["ticket_fifo_depth_8", "engine_back_to_back"], D())
CASES["E032"] = (["ticket_fifo_depth_8", "ticket_overflow_count_inc"], D())

# Mirror Offset and Mode Boundaries (E033-E048)
CASES["E033"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "MIRRORED"),
                  "mirror_offset_zero0"], D())
CASES["E034"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "MIRRORED"),
                  "mirror_offset_pos1"], D())
CASES["E035"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "MIRRORED"),
                  "mirror_offset_neg1"], D())
CASES["E036"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "MIRRORED"),
                  "mirror_offset_pos32"],
                 R({"mirror_offset": signed_uniform(8, 32),
                    "PRNG_SEED": lcg_seed_knob()}))
CASES["E037"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "MIRRORED"),
                  "mirror_clamp_high"], D())
CASES["E038"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "MIRRORED"),
                  "mirror_offset_neg128", "mirror_clamp_low"], D())
CASES["E039"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "MIRRORED"),
                  "mirror_offset_pos127", "mirror_clamp_high"], D())
CASES["E040"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "MIRRORED"),
                  "cluster_size_128", "mirror_offset_pos1"], D())
CASES["E041"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "MIRRORED"),
                  "cluster_size_1", "mirror_offset_zero0"], D())
CASES["E042"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "MIRRORED"),
                  "cluster_size_128", "mirror_offset_zero0"], D())
CASES["E043"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "MIRRORED"),
                  "tcc_full_period_observed"],
                 R({"mirror_offset": signed_uniform(-127, 127),
                    "PRNG_SEED": lcg_seed_knob()}))
CASES["E044"] = (["csr_addr_0x0D", "csr_access_RW"], D())
CASES["E045"] = (["csr_addr_0x0D", "csr_access_RW"], D())
CASES["E046"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "RIGHT_ONLY"),
                  "smb_B_only"], D())
CASES["E047"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "LEFT_ONLY"),
                  "smb_A_only"], D())
CASES["E048"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "MIRRORED"),
                  mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "LEFT_ONLY")],
                 D())

# SMB Boundary and Lane Enable (E049-E064)
CASES["E049"] = (["smb_A_only", "cluster_size_128"], D())
CASES["E050"] = (["smb_B_only", "cluster_size_128"], D())
CASES["E051"] = (["smb_cross"], D())
CASES["E052"] = (["smb_cross", "cluster_size_128"], D())
CASES["E053"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "LEFT_ONLY"),
                  "cluster_size_128", "smb_A_only"], D())
CASES["E054"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "MIRRORED")],
                 D())
CASES["E055"] = (["cluster_size_256", "engine_busy_high_water"], D())
CASES["E056"] = (["cluster_size_256"], D())
CASES["E057"] = (["lane_disabled_silent"], D())
CASES["E058"] = (["smb_A_only", "lane_disabled_silent"], D())
CASES["E059"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "MIRRORED"),
                  "lane_disabled_silent"], D())
CASES["E060"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "MIRRORED"),
                  "lane_disabled_silent"], D())
CASES["E061"] = (["lane_disabled_silent", "lane_count_0_hits"], D())
CASES["E062"] = (["asic_id_base_nonzero"], D())
CASES["E063"] = (["lane_disabled_silent", "cluster_size_128"], D())
CASES["E064"] = (["lane_reenabled_resume"], D())

# ECC Seed Phase / Delay Sweep (E065-E080)
CASES["E065"] = (["tcc_seed_default", "ecc_seed_default", "ecc_phase_n0"], D())
CASES["E066"] = (["ecc_phase_n1", "ecc_seed_custom"], D())
CASES["E067"] = (["ecc_phase_n5", "ecc_seed_custom"], D())
CASES["E068"] = (["ecc_phase_n20", "ecc_seed_custom"], D())
CASES["E069"] = (["ecc_phase_n1000", "ecc_seed_custom"], D())
CASES["E070"] = (["ecc_phase_n_full_period", "ecc_seed_custom"], D())
CASES["E071"] = (["ecc_phase_n_full_period", "ecc_seed_custom"], D())
CASES["E072"] = (["ecc_seed_custom", "csr_addr_0x0F", "csr_access_RW"], D())
CASES["E073"] = (["tcc_seed_custom", "ecc_seed_custom"], D())
CASES["E074"] = (["csr_addr_0x0F", "csr_access_RW"], D())
CASES["E075"] = (["tcc_seed_zero_invalid"], D())
CASES["E076"] = (["ecc_seed_zero_invalid"], D())
CASES["E077"] = (["tcc_seed_default", "ecc_seed_default"], D())
CASES["E078"] = (["ecc_seed_custom", "prng_seed_reproducibility"], D())
CASES["E079"] = (["ecc_seed_custom", "type0_vs_deassembly_parity"], D())
CASES["E080"] = (["ecc_seed_custom", "type0_vs_deassembly_parity"], D())

# Frame Boundary Race (E081-E096)
CASES["E081"] = (["frame_boundary_at_inject", "type0_sop"], D())
CASES["E082"] = (["frame_boundary_at_inject"], D())
CASES["E083"] = (["frame_boundary_at_inject"], D())
CASES["E084"] = (["frame_boundary_during_dispense", "cluster_size_32"], D())
CASES["E085"] = (["frame_empty"], D())
CASES["E086"] = (["frame_with_one_hit", "type0_sop", "type0_eop"], D())
CASES["E087"] = (["frame_at_event_max"], D())
CASES["E088"] = (["frame_with_one_hit", "type0_sop", "type0_eop"], D())
CASES["E089"] = (["frame_short_mode"], D())
CASES["E090"] = (["frame_long_mode"], D())
CASES["E091"] = (["frame_short_mode", "frame_long_mode"], D())
CASES["E092"] = (["byte_stream_active"], D())
CASES["E093"] = (["byte_stream_active"], D())
CASES["E094"] = (["frame_count_lane0_32bit"], D())
CASES["E095"] = ([f"frame_count_lane{L}_60bit" for L in range(8)], D())
CASES["E096"] = (["hit_count_lane0_32bit"], D())

# Per-Lane Counter Saturation (E097-E112)
CASES["E097"] = (["csr_addr_0x20", "csr_access_LANE_BLOCK",
                  "frame_count_lane0_32bit"], D())
CASES["E098"] = ([f"frame_count_lane{L}_32bit" for L in range(8)], D())
CASES["E099"] = ([f"frame_count_lane{L}_60bit" for L in range(8)], D())
CASES["E100"] = (["csr_addr_0x22", "csr_access_LANE_BLOCK",
                  "hit_count_lane0_32bit"], D())
CASES["E101"] = ([f"hit_count_lane{L}_32bit" for L in range(8)], D())
CASES["E102"] = ([f"hit_count_lane{L}_60bit" for L in range(8)], D())
CASES["E103"] = (["hit_count_lane3_32bit"], D())
CASES["E104"] = (["frame_count_lane0_32bit", "runctl_state_SYNC"], D())
CASES["E105"] = (["frame_count_lane0_32bit"], D())
CASES["E106"] = (["fifo_full_sticky_set", "l2_fifo_depth_256"], D())
CASES["E107"] = (["fifo_full_sticky_w1c"], D())
CASES["E108"] = (["ticket_overflow_sticky_set", "ticket_fifo_depth_8"], D())
CASES["E109"] = (["ticket_overflow_sticky_w1c"], D())
CASES["E110"] = (["ticket_overflow_saturate"], D())
CASES["E111"] = (["engine_busy_high_water"], D())
CASES["E112"] = (["csr_lo_hi_atomic_snapshot"], D())

# CSR Aliasing (E113-E128)
CASES["E113"] = (["csr_addr_0x07", "csr_access_RW"], D())
CASES["E114"] = (["csr_addr_0x08", "csr_access_RW"], D())
CASES["E115"] = (["csr_addr_0x09", "csr_access_RW"], D())
CASES["E116"] = (["csr_addr_0x0A", "csr_access_RW"], D())
CASES["E117"] = (["csr_addr_0x10", "csr_access_RSVD_RO"], D())
CASES["E118"] = (["csr_addr_0x11", "csr_access_RSVD_RO"], D())
CASES["E119"] = ([f"csr_addr_0x{a:02X}" for a in range(0x16, 0x20)] +
                 ["csr_access_RSVD_RO"], D())
CASES["E120"] = (["csr_access_OOR"], D())
CASES["E121"] = (["csr_during_running", "runctl_state_RESET"], D())
CASES["E122"] = (["csr_during_irst"], D())
CASES["E123"] = (["csr_during_irst", "csr_atomic_write"], D())
CASES["E124"] = (["csr_atomic_write", "csr_atomic_read"], D())
CASES["E125"] = (["csr_access_OOR"], D())
CASES["E126"] = (["csr_addr_0x13", "csr_access_W1P", "fire_w1p_singleshot"], D())
CASES["E127"] = (["csr_addr_0x15", "csr_access_RW",
                  "type0_error_inject_stub"], D())
CASES["E128"] = (["csr_addr_0x15", "type0_error_inject_stub"], D())

# ---- PROF bucket -----------------------------------------------------------

CASES["P001"] = (poisson_case(0xFFFF) + ["soak_1M",
                  mode_bin("INTERNAL", "POISSON", "FIX", "OFF", "MIRRORED")],
                 R({"hit_rate": uniform_int(0xF000, 0xFFFF),
                    "duration_cycles": uniform_int(500_000, 2_000_000),
                    "PRNG_SEED": lcg_seed_knob()}))
CASES["P002"] = (periodic_case(0x4000) + ["soak_1M"],
                 R({"hit_rate": uniform_int(0x2000, 0x8000),
                    "duration_cycles": uniform_int(500_000, 2_000_000),
                    "PRNG_SEED": lcg_seed_knob()}))
CASES["P003"] = (poisson_case(0x8000) + ["soak_1M"],
                 R({"hit_rate": uniform_int(0x6000, 0x9FFF),
                    "duration_cycles": uniform_int(500_000, 2_000_000),
                    "PRNG_SEED": lcg_seed_knob()}))
CASES["P004"] = (poisson_case(0x4000) + ["soak_1M"],
                 R({"hit_rate": uniform_int(0x3000, 0x5000),
                    "duration_cycles": uniform_int(500_000, 2_000_000),
                    "PRNG_SEED": lcg_seed_knob()}))
CASES["P005"] = (poisson_case(0x199A) + ["soak_1M"],
                 R({"hit_rate": uniform_int(0x1000, 0x2000),
                    "duration_cycles": uniform_int(500_000, 2_000_000),
                    "PRNG_SEED": lcg_seed_knob()}))
CASES["P006"] = (periodic_case(0xFFFF) + ["soak_10M"],
                 R({"duration_cycles": uniform_int(5_000_000, 20_000_000),
                    "PRNG_SEED": lcg_seed_knob()}))
CASES["P007"] = (poisson_case(0xFFFF) + ["cluster_size_1", "soak_1M"],
                 R({"hit_rate": uniform_int(0xC000, 0xFFFF),
                    "PRNG_SEED": lcg_seed_knob()}))
CASES["P008"] = (poisson_case(0x0001) + ["cluster_size_256", "soak_1M"],
                 R({"hit_rate": uniform_int(0x0001, 0x0010),
                    "PRNG_SEED": lcg_seed_knob()}))
CASES["P009"] = ([mode_bin("INTERNAL", "PERIODIC", "RANDOM", "OFF", "MIRRORED"),
                  "cluster_size_64", "soak_1M"],
                 R({"hit_rate": uniform_int(0x2000, 0x8000),
                    "mirror_offset": signed_uniform(-32, 32),
                    "PRNG_SEED": lcg_seed_knob()}))
CASES["P010"] = (poisson_case(0xFFFF) + ["lane_disabled_silent",
                  "ticket_overflow_count_inc", "ticket_fifo_depth_8"],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P011"] = (poisson_case(0xFFFF) + ["ticket_fifo_depth_0",
                  "ticket_fifo_depth_8"],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P012"] = (poisson_case(0x8000) + ["soak_1M"],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P013"] = (poisson_case(0x8000) + ["soak_1M"],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P014"] = (poisson_case(0x8000) + ["global_enable_gate"],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P015"] = (poisson_case(0x8000) + ["runctl_trans_RUNNING_to_TERMINATING"],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P016"] = (["fire_csr_conduit_or", "engine_back_to_back",
                  "soak_1M"],
                 R({"PRNG_SEED": lcg_seed_knob()}))

# Burst Cluster Throughput (P017-P032)
CASES["P017"] = (["cluster_size_32", "ticket_fifo_depth_8",
                  "engine_back_to_back"], D())
CASES["P018"] = (["cluster_size_32", "ticket_fifo_depth_8",
                  "ticket_overflow_count_inc"], D())
CASES["P019"] = (["ticket_overflow_count_inc", "engine_busy_high_water"], D())
CASES["P020"] = (["ticket_overflow_saturate", "fifo_full_sticky_set"], D())
CASES["P021"] = (["engine_back_to_back"], D())
CASES["P022"] = (["cluster_size_1", "cluster_size_2", "cluster_size_32",
                  "cluster_size_33", "cluster_size_64", "cluster_size_127",
                  "cluster_size_128", "cluster_size_256"], D())
CASES["P023"] = (["lane2_clus1", "ticket_fifo_depth_8"], D())
CASES["P024"] = ([f"lane{L}_clus1" for L in range(8)], D())
CASES["P025"] = ([mode_bin("INTERNAL", "POISSON", "FIX", "OFF", "MIRRORED"),
                  "fire_csr_conduit_or"], D())
CASES["P026"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "MIRRORED"),
                  "cluster_size_128"], D())
CASES["P027"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "LEFT_ONLY"),
                  "cluster_size_128", "smb_A_only"], D())
CASES["P028"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "RIGHT_ONLY"),
                  "cluster_size_128", "smb_B_only"], D())
CASES["P029"] = (["frame_boundary_during_dispense"], D())
CASES["P030"] = (["l2_fifo_depth_256", "fifo_full_sticky_set"], D())
CASES["P031"] = (["byte_stream_active", "l2_fifo_depth_192"], D())
CASES["P032"] = (["l2_fifo_depth_256", "ticket_fifo_depth_8",
                  "fifo_full_sticky_set"], D())

# BACKGROUND Soak (P033-P048)
CASES["P033"] = (bkg_case(0x0010) + ["soak_10M"],
                 R({"noise_rate": uniform_int(0x0008, 0x0020),
                    "duration_cycles": uniform_int(5_000_000, 20_000_000),
                    "PRNG_SEED": lcg_seed_knob()}))
CASES["P034"] = (bkg_case(0x0100) + ["soak_10M"],
                 R({"noise_rate": uniform_int(0x0080, 0x0200),
                    "duration_cycles": uniform_int(5_000_000, 20_000_000),
                    "PRNG_SEED": lcg_seed_knob()}))
CASES["P035"] = (bkg_case(0x0FFF) + ["soak_10M"],
                 R({"noise_rate": uniform_int(0x0800, 0x1FFF),
                    "duration_cycles": uniform_int(5_000_000, 20_000_000),
                    "PRNG_SEED": lcg_seed_knob()}))
CASES["P036"] = (bkg_case(0x0100) + ["soak_100M"],
                 R({"noise_rate": uniform_int(0x0080, 0x0200),
                    "duration_cycles": uniform_int(50_000_000, 200_000_000),
                    "PRNG_SEED": lcg_seed_knob()}))
CASES["P037"] = (bkg_case(0x4000) + ["fine_time_jitter_t",
                                      "fine_time_jitter_e"],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P038"] = (bkg_case(0x4000) + ["tcc_full_period_observed"],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P039"] = (bkg_case(0x4000) + ["lane_disabled_silent"],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P040"] = (bkg_case(0x4000) + ["prng_seed_reproducibility"], D())
CASES["P041"] = (bkg_case(0x4000) + ["prng_seed_diverge"],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P042"] = (bkg_case(0x4000) + ["bkg_uniform_per_channel"],
                 R({"noise_rate": uniform_int(0x1000, 0x8000),
                    "PRNG_SEED": lcg_seed_knob()}))
CASES["P043"] = ([mode_bin("INTERNAL", "POISSON", "FIX", "ON", "MIRRORED"),
                  "engine_round_robin"],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P044"] = (bkg_case(0x4000) + ["runctl_trans_RUNNING_to_TERMINATING"],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P045"] = (bkg_case(0x4000) + ["ticket_overflow_count_inc",
                                      "ticket_fifo_depth_8"],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P046"] = (bkg_case(0x4000) + ["ticket_fifo_depth_0"],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P047"] = (bkg_case(0x4000) + ["tcc_full_period_observed"],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P048"] = (bkg_case(0x0010) + ["soak_1B", "bkg_uniform_per_channel"],
                 R({"noise_rate": uniform_int(0x0008, 0x0020),
                    "duration_cycles": uniform_int(500_000_000, 2_000_000_000),
                    "PRNG_SEED": lcg_seed_knob()}))

# Mixed SIGNAL+BACKGROUND (P049-P064)
def mixed_case():
    return [mode_bin("INTERNAL", "POISSON", "FIX", "ON", "MIRRORED")]


CASES["P049"] = (mixed_case() + ["rate_mid", "noise_rate_mid"],
                 R({"hit_rate": uniform_int(0x2000, 0x8000),
                    "noise_rate": uniform_int(0x2000, 0x8000),
                    "PRNG_SEED": lcg_seed_knob()}))
CASES["P050"] = ([mode_bin("INTERNAL", "PERIODIC", "FIX", "ON", "MIRRORED"),
                  "rate_mid", "noise_rate_mid"],
                 R({"hit_rate": uniform_int(0x1000, 0x4000),
                    "noise_rate": uniform_int(0x0800, 0x2000),
                    "PRNG_SEED": lcg_seed_knob()}))
CASES["P051"] = ([mode_bin("EXTERNAL", "POISSON", "FIX", "ON", "MIRRORED"),
                  "fire_csr_conduit_or"],
                 R({"noise_rate": uniform_int(0x1000, 0x4000),
                    "PRNG_SEED": lcg_seed_knob()}))
CASES["P052"] = ([mode_bin("EXTERNAL", "POISSON", "FIX", "ON", "MIRRORED"),
                  "fire_csr_conduit_or", "inject_in_external"],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P053"] = ([mode_bin("EXTERNAL", "POISSON", "FIX", "ON", "MIRRORED"),
                  "cluster_size_32"],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P054"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "ON", "MIRRORED")],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P055"] = (mixed_case() + ["lane_disabled_silent"],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P056"] = (mixed_case() + ["global_enable_gate"],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P057"] = (mixed_case() + ["runctl_trans_RUNNING_to_TERMINATING"],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P058"] = (mixed_case() + ["runctl_state_TERMINATING"],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P059"] = ([mode_bin("EXTERNAL", "POISSON", "FIX", "ON", "MIRRORED")],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P060"] = ([mode_bin("EXTERNAL", "POISSON", "FIX", "OFF", "MIRRORED"),
                  "lane_count_0_hits"], D())
CASES["P061"] = (mixed_case() + ["rate_max", "noise_rate_max",
                                  "engine_round_robin"],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P062"] = (mixed_case() + ["rate_max", "noise_rate_low"],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P063"] = (mixed_case() + ["rate_low", "noise_rate_max"],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P064"] = (mixed_case() + ["soak_1M"],
                 R({"hit_rate": uniform_int(0x1000, 0xF000),
                    "noise_rate": uniform_int(0x0010, 0x4000),
                    "PRNG_SEED": lcg_seed_knob()}))

# Per-Lane Drain Latency (P065-P080)
CASES["P065"] = (["cluster_size_1", "type0_sop"],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P066"] = (["type0_sop", "type0_eop"],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P067"] = (["byte_stream_active"],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P068"] = (["type0_vs_deassembly_parity"],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P069"] = (poisson_case(0x8000) + ["soak_1M"],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P070"] = (["l2_fifo_depth_128"],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P071"] = (["lane_disabled_silent"],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P072"] = (["frame_boundary_at_inject"],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P073"] = (["type0_sop", "type0_eop"], D())
CASES["P074"] = (["frame_empty"], D())
CASES["P075"] = (["runctl_state_TERMINATING"],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P076"] = (["type0_endofrun"],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P077"] = (poisson_case(0x4000),
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P078"] = (periodic_case(0x4000),
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P079"] = (["frame_short_mode", "frame_long_mode"], D())
CASES["P080"] = (["inject_during_sync_drop"], D())

# Type0 vs Deassembly Parity (P081-P096) -- BYTE_STREAM_ENABLE=1 required
def parity_case():
    return ["type0_vs_deassembly_parity", "byte_stream_active",
            "build_LC8_BS1"]


CASES["P081"] = (parity_case() + ["cluster_size_1"], D())
CASES["P082"] = (parity_case() + ["cluster_size_32"], D())
CASES["P083"] = (parity_case() + ["soak_1M"],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P084"] = (parity_case() + ["cluster_size_256"], D())
CASES["P085"] = (parity_case() + ["cluster_size_1", "cluster_size_2",
                                   "cluster_size_32", "cluster_size_33",
                                   "cluster_size_64", "cluster_size_127",
                                   "cluster_size_128", "cluster_size_256"],
                 D())
CASES["P086"] = (parity_case() + [mode_bin("EXTERNAL", "POISSON", "FIX",
                                             "ON", "MIRRORED")], D())
CASES["P087"] = (parity_case() + [mode_bin("EXTERNAL", "POISSON", "RANDOM",
                                             "OFF", "MIRRORED")], D())
CASES["P088"] = (parity_case() + ["frame_short_mode"], D())
CASES["P089"] = (parity_case() + ["frame_long_mode"], D())
CASES["P090"] = (parity_case() + ["frame_empty"], D())
CASES["P091"] = (parity_case() + ["runctl_state_TERMINATING",
                                    "type0_endofrun"], D())
CASES["P092"] = (parity_case() + ["asic_id_base_nonzero"], D())
CASES["P093"] = (parity_case() + ["type0_sop", "type0_eop"], D())
CASES["P094"] = (parity_case() + ["type0_error_inject_stub"], D())
CASES["P095"] = (parity_case() + ["soak_1M"], D())
CASES["P096"] = (parity_case() + ["build_LC8_BS1", "build_LC4_BS1"], D())

# Inject ORing Stress (P097-P112)
CASES["P097"] = (["fire_w1p_singleshot", "fire_csr_conduit_or",
                  "engine_back_to_back"], D())
CASES["P098"] = (["fire_edge_detect", "engine_back_to_back"], D())
CASES["P099"] = (["fire_csr_conduit_or", "engine_back_to_back"], D())
CASES["P100"] = (["fire_csr_conduit_or", "fire_edge_detect"], D())
CASES["P101"] = (["fire_csr_conduit_or", "engine_busy_high_water"], D())
CASES["P102"] = (["engine_back_to_back", "ticket_overflow_count_inc",
                  "ticket_fifo_depth_8"], D())
CASES["P103"] = (["engine_busy_drops", "ticket_overflow_count_inc"], D())
CASES["P104"] = (["fire_csr_conduit_or", "internal_dropped_on_stall"], D())
CASES["P105"] = (["fire_csr_conduit_or",
                  mode_bin("EXTERNAL", "POISSON", "FIX", "ON", "MIRRORED")],
                 D())
CASES["P106"] = ([mode_bin("EXTERNAL", "POISSON", "FIX", "OFF", "MIRRORED"),
                  mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "MIRRORED")],
                 D())
CASES["P107"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "MIRRORED"),
                  "prng_seed_diverge"],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P108"] = (["fire_csr_conduit_or", "rate_max"],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P109"] = (["fire_edge_detect"], D())
CASES["P110"] = (["inject_during_term_drop"], D())
CASES["P111"] = (["inject_during_sync_drop"], D())
CASES["P112"] = (["runctl_trans_SYNC_to_RUNNING", "fire_csr_conduit_or"], D())

# Continuous-Frame Long-Run Soak (P113-P128)
CASES["P113"] = (["all_buckets_frame_baseline", "soak_1M"],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P114"] = (["all_buckets_frame_baseline", "soak_10M"],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P115"] = (["all_buckets_frame_baseline", "prng_seed_reproducibility"],
                 D())
CASES["P116"] = (["all_buckets_frame_baseline", "prng_seed_diverge"],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P117"] = (["all_buckets_frame_baseline", "soak_1M"],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P118"] = (["all_buckets_frame_baseline", "runctl_state_SYNC"],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P119"] = (["all_buckets_frame_baseline",
                  "runctl_trans_RUNNING_to_TERMINATING"],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P120"] = (["all_buckets_frame_baseline"],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P121"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "MIRRORED")] +
                 [f"mirror_offset_{'neg' if o<0 else 'pos' if o>0 else 'zero'}{abs(o)}"
                  for o in MIRROR_OFFSET_BINS],
                 R({"mirror_offset": signed_uniform(-127, 127),
                    "PRNG_SEED": lcg_seed_knob()}))
CASES["P122"] = ([mode_bin("INTERNAL", "POISSON", "FIX", "OFF", "MIRRORED"),
                  mode_bin("INTERNAL", "POISSON", "RANDOM", "OFF", "MIRRORED")],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P123"] = ([mode_bin("INTERNAL", "POISSON", "FIX", "OFF", "MIRRORED"),
                  mode_bin("EXTERNAL", "POISSON", "FIX", "OFF", "MIRRORED")],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P124"] = ([mode_bin("INTERNAL", "POISSON", "FIX", "ON", "MIRRORED"),
                  mode_bin("INTERNAL", "POISSON", "FIX", "OFF", "MIRRORED")],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P125"] = (["all_buckets_frame_baseline", "global_enable_gate"],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P126"] = (["lane_enable_mask_sweep", "lane_disabled_silent"],
                 R({"PRNG_SEED": lcg_seed_knob(),
                    "lane_enable_mask": uniform_int(0, 0xFF)}))
CASES["P127"] = (["all_buckets_frame_baseline"] +
                 [mode_bin(s, sb, g, b, m) for s in SIG_MODES for sb in SUB_MODES
                  for g in GEOM_MODES for b in BKG_MODES for m in MIRROR_MODES],
                 R({"PRNG_SEED": lcg_seed_knob()}))
CASES["P128"] = (["all_buckets_frame_baseline", "soak_100M"],
                 R({"duration_cycles": uniform_int(50_000_000, 200_000_000),
                    "PRNG_SEED": lcg_seed_knob()}))

# ---- ERROR bucket -----------------------------------------------------------

# Reset During Activity (X001-X016)
CASES["X001"] = (["runctl_state_SYNC", "cluster_size_32"], D())
CASES["X002"] = (["runctl_state_SYNC",
                  mode_bin("INTERNAL", "POISSON", "FIX", "OFF", "MIRRORED")],
                 D())
CASES["X003"] = (["runctl_state_SYNC",
                  mode_bin("EXTERNAL", "POISSON", "FIX", "ON", "MIRRORED")],
                 D())
CASES["X004"] = (["runctl_state_SYNC", "type0_sop"], D())
CASES["X005"] = (["runctl_state_SYNC", "byte_stream_active"], D())
CASES["X006"] = (["runctl_state_SYNC", "ticket_fifo_depth_8"], D())
CASES["X007"] = (["runctl_state_SYNC", "l2_fifo_depth_192"], D())
CASES["X008"] = (["runctl_state_SYNC", "tcc_seed_default", "ecc_seed_default"],
                 D())
CASES["X009"] = (["runctl_state_SYNC", "engine_busy_high_water"], D())
CASES["X010"] = (["last_clear_on_irst",
                  "fifo_full_sticky_w1c", "ticket_overflow_sticky_w1c"], D())
CASES["X011"] = (["runctl_state_SYNC",
                  "frame_count_lane0_32bit", "hit_count_lane0_32bit"], D())
CASES["X012"] = (["runctl_state_SYNC", "csr_atomic_write"], D())
CASES["X013"] = (["last_clear_on_irst"], D())
CASES["X014"] = (["runctl_state_SYNC", "fire_csr_conduit_or"], D())
CASES["X015"] = (["runctl_state_SYNC"], D())
CASES["X016"] = (["runctl_trans_RUNNING_to_TERMINATING", "runctl_state_SYNC"],
                 D())

# Run-Control Illegal (X017-X032)
CASES["X017"] = (["runctl_illegal_multibit"], D())
CASES["X018"] = (["runctl_illegal_allzero"], D())
CASES["X019"] = (["runctl_state_RUNNING"], D())
CASES["X020"] = ([f"runctl_state_{s}" for s in RUN_STATES], D())
CASES["X021"] = (["runctl_state_SYNC"], D())
CASES["X022"] = (["runctl_state_RUNNING"], D())
CASES["X023"] = (["runctl_state_RUNNING", "runctl_state_IDLE"], D())
CASES["X024"] = (["runctl_state_TERMINATING", "runctl_state_RUNNING"], D())
CASES["X025"] = (["runctl_state_TERMINATING", "runctl_state_SYNC"], D())
CASES["X026"] = (["runctl_state_LINK_TEST", "runctl_trans_IDLE_to_LINK_TEST"],
                 D())
CASES["X027"] = (["runctl_state_OUT_OF_DAQ",
                  "runctl_trans_IDLE_to_OUT_OF_DAQ"], D())
CASES["X028"] = (["runctl_state_SYNC"], D())
CASES["X029"] = (["runctl_state_RESET", "last_clear_on_irst"], D())
CASES["X030"] = (["runctl_state_IDLE"], D())
CASES["X031"] = (["runctl_state_RUNNING", "fire_csr_conduit_or"], D())
CASES["X032"] = (["runctl_state_RUNNING"], D())

# CSR Access During Reset/Activity (X033-X048)
CASES["X033"] = (["csr_during_irst", "csr_addr_0x00"], D())
CASES["X034"] = (["csr_during_irst", "csr_addr_0x07"], D())
CASES["X035"] = (["csr_during_sync"], D())
CASES["X036"] = (["csr_during_sync", "csr_atomic_write"], D())
CASES["X037"] = (["csr_during_running"], D())
CASES["X038"] = (["csr_during_running", "csr_addr_0x0C"], D())
CASES["X039"] = (["csr_addr_0x0A", "frame_short_mode", "frame_long_mode"], D())
CASES["X040"] = (["csr_addr_0x0F"], D())
CASES["X041"] = (["csr_addr_0x12", "lane_disabled_silent"], D())
CASES["X042"] = (["csr_atomic_write", "csr_atomic_read"], D())
CASES["X043"] = (["csr_during_irst", "csr_access_OOR"], D())
CASES["X044"] = (["csr_addr_0x00", "csr_access_RO"], D())
CASES["X045"] = (["csr_addr_0x13", "csr_during_irst", "fire_w1p_singleshot"],
                 D())
CASES["X046"] = (["csr_addr_0x15", "type0_error_inject_stub"], D())
CASES["X047"] = (["csr_during_running", "runctl_state_TERMINATING"], D())
CASES["X048"] = (["csr_atomic_read"], D())

# Ticket FIFO Overflow (X049-X064)
CASES["X049"] = (["ticket_fifo_depth_8", "lane_disabled_silent"], D())
CASES["X050"] = (["ticket_fifo_depth_8", "ticket_overflow_count_inc",
                  "ticket_overflow_sticky_set"], D())
CASES["X051"] = (["ticket_overflow_saturate"], D())
CASES["X052"] = (["ticket_fifo_depth_0", "ticket_fifo_depth_8"], D())
CASES["X053"] = (["ticket_overflow_sticky_set"], D())
CASES["X054"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "MIRRORED"),
                  "ticket_overflow_count_inc"], D())
CASES["X055"] = ([mode_bin("EXTERNAL", "POISSON", "FIX", "ON", "MIRRORED"),
                  "ticket_overflow_count_inc"], D())
CASES["X056"] = ([mode_bin("INTERNAL", "POISSON", "FIX", "OFF", "MIRRORED"),
                  "internal_dropped_on_stall"], D())
CASES["X057"] = ([mode_bin("EXTERNAL", "POISSON", "FIX", "OFF", "MIRRORED"),
                  "ticket_overflow_count_inc"], D())
CASES["X058"] = (["ticket_overflow_sticky_w1c"], D())
CASES["X059"] = (["ticket_fifo_depth_8", "ticket_fifo_depth_0"], D())
CASES["X060"] = (["ticket_fifo_depth_7"], D())
CASES["X061"] = (["ticket_fifo_depth_8"], D())
CASES["X062"] = (["ticket_fifo_depth_8", "engine_busy_high_water"], D())
CASES["X063"] = (["last_clear_on_irst"], D())
CASES["X064"] = (["runctl_state_SYNC", "ticket_overflow_count_inc"], D())

# L2 FIFO Backpressure (X065-X080)
CASES["X065"] = (["l2_fifo_depth_256"], D())
CASES["X066"] = (["l2_fifo_depth_192"], D())
CASES["X067"] = (["l2_fifo_depth_128", "ticket_fifo_depth_4"], D())
CASES["X068"] = (["l2_fifo_depth_256", "ticket_fifo_depth_8",
                  "ticket_overflow_count_inc"], D())
CASES["X069"] = (["l2_fifo_depth_0", "l2_fifo_depth_128"], D())
CASES["X070"] = (["runctl_state_SYNC", "l2_fifo_depth_0"], D())
CASES["X071"] = (["runctl_state_TERMINATING", "l2_fifo_depth_192"], D())
CASES["X072"] = (["fifo_full_sticky_set", "l2_fifo_depth_256"], D())
CASES["X073"] = (["fifo_full_sticky_w1c"], D())
CASES["X074"] = (["byte_stream_active", "l2_fifo_depth_128"], D())
CASES["X075"] = (["byte_stream_active", "l2_fifo_depth_128"], D())
CASES["X076"] = (["l2_fifo_depth_256"], D())
CASES["X077"] = (["type0_sop"], D())
CASES["X078"] = (["l2_fifo_depth_192"], D())
CASES["X079"] = (["l2_fifo_depth_256", "l2_fifo_depth_0"], D())
CASES["X080"] = (["l2_fifo_depth_64"], D())

# Frame-Boundary Reset and Counter Atomicity (X081-X096)
CASES["X081"] = (["runctl_state_SYNC", "frame_boundary_at_inject"], D())
CASES["X082"] = (["runctl_state_SYNC", "l2_fifo_depth_64"], D())
CASES["X083"] = (["runctl_state_SYNC", "type0_eop"], D())
CASES["X084"] = (["runctl_trans_RUNNING_to_TERMINATING",
                  "frame_boundary_at_inject"], D())
CASES["X085"] = (["runctl_trans_RUNNING_to_TERMINATING",
                  "frame_boundary_during_dispense"], D())
CASES["X086"] = (["runctl_state_IDLE", "frame_boundary_during_dispense"], D())
CASES["X087"] = ([mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "MIRRORED"),
                  "frame_boundary_during_dispense"], D())
CASES["X088"] = ([mode_bin("EXTERNAL", "POISSON", "FIX", "ON", "MIRRORED"),
                  "frame_boundary_at_inject"], D())
CASES["X089"] = (["frame_empty", "frame_with_one_hit"], D())
CASES["X090"] = (["frame_at_event_max", "frame_empty"], D())
CASES["X091"] = ([f"frame_count_lane{L}_32bit" for L in range(8)], D())
CASES["X092"] = ([f"hit_count_lane{L}_32bit" for L in range(8)], D())
CASES["X093"] = (["csr_lo_hi_atomic_snapshot"], D())
CASES["X094"] = (["lane_disabled_silent", "lane_count_0_hits"], D())
CASES["X095"] = (["lane_reenabled_resume"], D())
CASES["X096"] = ([f"frame_count_lane{L}_60bit" for L in range(8)], D())

# CSR Atomicity (X097-X112)
CASES["X097"] = (["csr_addr_0x02", "csr_atomic_write"], D())
CASES["X098"] = (["csr_addr_0x02", "csr_atomic_read"], D())
CASES["X099"] = (["csr_addr_0x0D", "csr_atomic_write"], D())
CASES["X100"] = (["csr_addr_0x07", "csr_addr_0x08", "csr_atomic_write"], D())
CASES["X101"] = (["csr_addr_0x07", "fire_csr_conduit_or",
                  "global_enable_gate"], D())
CASES["X102"] = (["csr_addr_0x07", "global_enable_gate"], D())
CASES["X103"] = (["csr_addr_0x08", mode_bin("EXTERNAL", "POISSON", "FIX",
                                              "OFF", "MIRRORED"),
                  mode_bin("EXTERNAL", "POISSON", "RANDOM", "OFF", "MIRRORED")],
                 D())
CASES["X104"] = (["csr_addr_0x0D", "cluster_size_32", "cluster_size_64"], D())
CASES["X105"] = (["fifo_full_sticky_w1c", "fifo_full_sticky_set"], D())
CASES["X106"] = (["fire_csr_conduit_or", "fire_w1p_singleshot"], D())
CASES["X107"] = (["last_rd_capture", "csr_atomic_read"], D())
CASES["X108"] = (["csr_atomic_read"], D())
CASES["X109"] = (["csr_atomic_write", "csr_atomic_read"], D())
CASES["X110"] = (["csr_addr_0x13", "fire_w1p_singleshot",
                  "engine_back_to_back"], D())
CASES["X111"] = (["fifo_full_sticky_w1c", "ticket_overflow_sticky_w1c"], D())
CASES["X112"] = (["csr_atomic_write", "csr_atomic_read"], D())

# Run-Control Replay and Edge Cases (X113-X128)
CASES["X113"] = (["runctl_state_RUNNING"], D())
CASES["X114"] = (["runctl_state_RUNNING"], D())
CASES["X115"] = (["runctl_state_RUNNING"], D())
CASES["X116"] = (["runctl_state_RUNNING"], D())
CASES["X117"] = (["runctl_state_IDLE", "runctl_state_RUNNING"], D())
CASES["X118"] = (["runctl_state_TERMINATING", "runctl_state_RUNNING"], D())
CASES["X119"] = (["runctl_state_IDLE", "runctl_state_RUNNING"], D())
CASES["X120"] = (["runctl_state_SYNC", "frame_boundary_at_inject"], D())
CASES["X121"] = (["runctl_state_RESET"], D())
CASES["X122"] = (["fire_csr_conduit_or",
                  "runctl_trans_RUNNING_to_TERMINATING"], D())
CASES["X123"] = (["runctl_state_SYNC", "engine_busy_high_water"], D())
CASES["X124"] = (["csr_during_running", "runctl_state_RUNNING"], D())
CASES["X125"] = (["runctl_state_RUNNING"], D())
CASES["X126"] = (["runctl_illegal_multibit"], D())
CASES["X127"] = (["runctl_state_OUT_OF_DAQ"], D())
CASES["X128"] = (["runctl_state_RUNNING"], D())


# ---------------------------------------------------------------------------
# Validation: every bin in every case must be in ALL_BINS, and we must have
# exactly 512 cases (B/E/P/X × 128).
# ---------------------------------------------------------------------------

def normalize(profile_entry):
    bins, profile = profile_entry
    # de-duplicate while preserving order
    seen = set()
    out = []
    for b in bins:
        if b not in seen:
            seen.add(b)
            out.append(b)
    return out, profile


for cid in list(CASES.keys()):
    CASES[cid] = normalize(CASES[cid])

# Validate counts
prefixes = {"B": 0, "E": 0, "P": 0, "X": 0}
for cid in CASES:
    prefixes[cid[0]] += 1
assert prefixes == {"B": 128, "E": 128, "P": 128, "X": 128}, prefixes
assert len(CASES) == 512

# Validate every bin exists
unknown = set()
for cid, (bins, _) in CASES.items():
    for b in bins:
        if b not in ASSERTED_BINS:
            unknown.add((cid, b))
if unknown:
    raise SystemExit(f"unknown bins: {sorted(unknown)[:20]}")


# ---------------------------------------------------------------------------
# Emit cov_profiles.json
# ---------------------------------------------------------------------------

OUT_DIR = "/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/emulator_mutrig/tb"

def to_json_value(v):
    if isinstance(v, dict):
        return {k: to_json_value(val) for k, val in v.items()}
    if isinstance(v, list):
        return [to_json_value(x) for x in v]
    return v


cov_json = OrderedDict()
for cid, (bins, prof) in CASES.items():
    cov_json[cid] = {
        "coverage_bins": bins,
        "random_profile": prof,
    }

with open(os.path.join(OUT_DIR, "cov_profiles.json"), "w") as f:
    json.dump(cov_json, f, indent=2)

print(f"wrote {OUT_DIR}/cov_profiles.json with {len(cov_json)} cases")

# ---------------------------------------------------------------------------
# Emit DV_COV.md (canonical bin-tracking format).
# ---------------------------------------------------------------------------

bins_per_case = [len(bins) for bins, _ in CASES.values()]
mean_bins = sum(bins_per_case) / len(bins_per_case)


def bucket_of(cid):
    return {"B": "BASIC", "E": "EDGE", "P": "PROF", "X": "ERROR"}[cid[0]]


# Group bins by category for the inventory table
def categorize(bin_name):
    if bin_name.startswith("csr_addr_"):
        return "csr_address"
    if bin_name.startswith("csr_access_"):
        return "csr_access_class"
    if bin_name.startswith("mode_"):
        return "mode_matrix"
    if bin_name.startswith("cluster_size_"):
        return "cluster_size"
    if bin_name.startswith("mirror_offset_"):
        return "mirror_offset"
    if bin_name.startswith("lane") and "_clus" in bin_name:
        return "per_lane_cluster"
    if bin_name.startswith("runctl_state_"):
        return "runctl_state"
    if bin_name.startswith("runctl_trans_"):
        return "runctl_transition"
    if bin_name.startswith("runctl_illegal_"):
        return "runctl_illegal"
    if bin_name.startswith("ticket_fifo_depth_"):
        return "ticket_fifo_depth"
    if bin_name.startswith("l2_fifo_depth_"):
        return "l2_fifo_depth"
    if bin_name.startswith("frame_count_") or bin_name.startswith("hit_count_"):
        return "counter_boundary"
    if bin_name.startswith("build_"):
        return "build_axes_cross"
    return "structural_misc"


cats = {}
for b in ALL_BINS:
    cats.setdefault(categorize(b), []).append(b)

cat_summary = OrderedDict()
for c in ["csr_address", "csr_access_class", "mode_matrix", "cluster_size",
          "mirror_offset", "per_lane_cluster", "runctl_state",
          "runctl_transition", "runctl_illegal", "ticket_fifo_depth",
          "l2_fifo_depth", "counter_boundary", "build_axes_cross",
          "structural_misc"]:
    cat_summary[c] = len(cats.get(c, []))


# DV_COV.md content. Format inspired by packet_scheduler/tb/DV_COV.md but
# emphasizing the bin-tracking required by the dv-workflow §6 contract.
md_lines = []
md_lines.append("# DV Coverage Tracking — emulator_mutrig")
md_lines.append("")
md_lines.append("**Companion docs:** [DV_PLAN.md](DV_PLAN.md), "
                "[DV_BASIC.md](DV_BASIC.md), [DV_EDGE.md](DV_EDGE.md), "
                "[DV_PROF.md](DV_PROF.md), [DV_ERROR.md](DV_ERROR.md), "
                "[DV_HARNESS.md](DV_HARNESS.md), `BUG_HISTORY.md`")
md_lines.append("")
md_lines.append("**Bin universe:** machine source of truth is "
                "[`cov_profiles.json`](cov_profiles.json). The SystemVerilog "
                "loader is in [`uvm/cov_profile_loader.svh`]"
                "(uvm/cov_profile_loader.svh).")
md_lines.append("")
md_lines.append("**Promotion rule:** every directed case promotes to a "
                "constrained-random profile centred on its directed value "
                "for `bucket_frame` and `all_buckets_frame` execution. "
                "Each case retains its own coverage delta in both modes.")
md_lines.append("")
md_lines.append("## Legend")
md_lines.append("")
md_lines.append("OK pass / closed at-or-above target  --  PARTIAL below "
                "target / known limitation  --  FAIL failed / missing "
                "evidence  --  PEND pending  --  INFO informational")
md_lines.append("")
md_lines.append("## 1. Bin Inventory Summary")
md_lines.append("")
md_lines.append("Each row counts coverage bins owned by this DV plan. The "
                "same bin may be touched by multiple cases; the loader "
                "increments a per-bin counter every time a case exercises "
                "it. Sign-off requires every bin to be hit by at least one "
                "passing case.")
md_lines.append("")
md_lines.append("| category | # bins | source |")
md_lines.append("|---|---:|---|")
sources = {
    "csr_address": "RTL_PLAN_central_trigger.md §3 (CSR map 0x00..0x3F)",
    "csr_access_class": "RW/RO/W1P/RW_RO/RSVD_RO/LANE_BLOCK/OOR partitioning",
    "mode_matrix": "RTL_PLAN_central_trigger.md §2.3-§2.4 mode axes "
                   "(2x2x2x2x3=48)",
    "cluster_size": "DV_PLAN.md §3 cluster-size bins",
    "mirror_offset": "DV_PLAN.md §3 mirror-offset bins",
    "per_lane_cluster": "DV_PLAN.md §3 per-lane × channel-count",
    "runctl_state": "DV_HARNESS.md run-control AvST one-hot states",
    "runctl_transition": "DV_PLAN.md §3 every legal one-hot transition pair",
    "runctl_illegal": "X017/X018 illegal one-hot decode",
    "ticket_fifo_depth": "DV_PLAN.md §3 ticket FIFO depth bins",
    "l2_fifo_depth": "DV_PLAN.md §3 L2 FIFO depth bins",
    "counter_boundary": "DV_PLAN.md §3 32-bit and 60-bit counter crossings",
    "build_axes_cross": "DV_PLAN.md §5 LANE_COUNT × BYTE_STREAM_ENABLE",
    "structural_misc": "structural anchors (UID readback, sticky bits, "
                      "ECC seed phases, type0 SOP/EOP, etc.)",
}
total_bins = 0
for c, n in cat_summary.items():
    md_lines.append(f"| `{c}` | {n} | {sources[c]} |")
    total_bins += n
md_lines.append(f"| **total** | **{total_bins}** | — |")
md_lines.append("")
md_lines.append(f"Per-case mean bin count: **{mean_bins:.2f}** "
                f"(min {min(bins_per_case)}, max {max(bins_per_case)}, "
                f"sum {sum(bins_per_case)} bin-touches over {len(CASES)} "
                "cases).")
md_lines.append("")

# Coverage targets
md_lines.append("## 2. Code-Coverage Targets (per dv-workflow §6)")
md_lines.append("")
md_lines.append("<!-- columns:")
md_lines.append("  metric  = code-coverage category as reported by Questa "
                "FSE")
md_lines.append("  target  = workflow target percentage")
md_lines.append("  policy  = how to interpret a miss")
md_lines.append("-->")
md_lines.append("")
md_lines.append("| metric | target | policy |")
md_lines.append("|---|---:|---|")
md_lines.append("| stmt | 95.0 | release gate |")
md_lines.append("| branch | 90.0 | release gate |")
md_lines.append("| fsm_state | 95.0 | release gate |")
md_lines.append("| fsm_trans | 90.0 | release gate |")
md_lines.append("| toggle | 80.0 | release gate |")
md_lines.append("| cond | reported | no fixed target |")
md_lines.append("| expr | reported | no fixed target |")
md_lines.append("")

md_lines.append("## 3. Per-Case Coverage Bin Ownership")
md_lines.append("")
md_lines.append("This is the canonical per-case bin map. Each row "
                "lists the coverage bins this case is responsible for "
                "exercising. The full machine-readable version is in "
                "[`cov_profiles.json`](cov_profiles.json); the table below "
                "is one row per case for human review.")
md_lines.append("")
md_lines.append("<!-- columns:")
md_lines.append("  case_id          = planned case ID (B/E/P/X + 3 digits)")
md_lines.append("  type (d/r)       = directed or randomised under "
                "isolated execution")
md_lines.append("  promotion        = D = stays directed in soak / R = "
                "promoted to constrained-random in bucket_frame and "
                "all_buckets_frame")
md_lines.append("  n_bins           = number of coverage bins this case "
                "owns")
md_lines.append("  bins             = comma-separated bin names")
md_lines.append("-->")
md_lines.append("")

for bucket_letter, bucket_name in [("B", "BASIC"), ("E", "EDGE"),
                                     ("P", "PROF"), ("X", "ERROR")]:
    md_lines.append(f"### 3.{['B','E','P','X'].index(bucket_letter)+1} "
                    f"{bucket_name} bucket bin ownership")
    md_lines.append("")
    md_lines.append("| case_id | type (d/r) | promotion | n_bins | bins |")
    md_lines.append("|---|---|---|---:|---|")
    for cid, (bins, prof) in CASES.items():
        if cid[0] != bucket_letter:
            continue
        promo = "R" if prof["type"] == "promoted" else "D"
        # If already R in bucket file, keep as r; else r when promotion fires
        td = "r" if (prof["type"] == "promoted") else "d"
        bin_str = ", ".join(f"`{b}`" for b in bins)
        md_lines.append(f"| `{cid}` | {td} | {promo} | {len(bins)} | "
                        f"{bin_str} |")
    md_lines.append("")

md_lines.append("## 4. Random Promotion Profiles")
md_lines.append("")
md_lines.append("Every directed case is promoted into a "
                "constrained-random profile centred on its directed value "
                "for `bucket_frame` and `all_buckets_frame` execution. "
                "Random knob distributions are sampled with the "
                "LCG-based PRNG declared in `mutrig_common_pkg` "
                "(no SystemVerilog `rand`, per Questa FSE Starter "
                "Edition constraints).")
md_lines.append("")
md_lines.append("Knob examples drawn from the case list:")
md_lines.append("")
md_lines.append("- `B033` (Poisson hit_rate=0): promotes to "
                "`hit_rate ∈ [0, 0x000F]`, PRNG_SEED uniform over the "
                "32-bit space.")
md_lines.append("- `B038` (Poisson hit_rate=0xFFFF): promotes to "
                "`hit_rate ∈ [0xF000, 0xFFFF]`.")
md_lines.append("- `B100` (mirror_offset=+5): promotes to "
                "`mirror_offset ∈ [+1, +8]` signed.")
md_lines.append("- `B101` (mirror_offset=-5): promotes to "
                "`mirror_offset ∈ [-8, -1]` signed.")
md_lines.append("- `P048` (BKG soak 1B cycles): promotes to "
                "`duration_cycles ∈ [5e8, 2e9]`.")
md_lines.append("")
md_lines.append("The full per-case knob set is in "
                "[`cov_profiles.json`](cov_profiles.json) under "
                "`<case_id>.random_profile.knobs`.")
md_lines.append("")

md_lines.append("## 5. Per-Bucket Tracking Tables")
md_lines.append("")
md_lines.append("Each per-bucket table follows the dv-workflow §6 hard-"
                "format contract:")
md_lines.append("")
md_lines.append("```")
md_lines.append("| case_id | type (d/r) | coverage_by_this_case | "
                "executed random txn | coverage_incr_per_txn |")
md_lines.append("```")
md_lines.append("")
md_lines.append("These tables are auto-populated by the Questa FSE "
                "regression harness once cases run. Until UCDBs land, "
                "the per-bucket tables read `pending`.")
md_lines.append("")

md_lines.append("### 5.1 BASIC bucket (B001-B128)")
md_lines.append("")
md_lines.append("| case_id | type (d/r) | coverage_by_this_case | "
                "executed random txn | coverage_incr_per_txn |")
md_lines.append("|---|---|---|---:|---|")
for cid, (bins, prof) in CASES.items():
    if cid[0] != "B":
        continue
    td = "r" if prof["type"] == "promoted" else "d"
    md_lines.append(f"| `{cid}` | {td} | pending | 0 | pending |")
md_lines.append("")

md_lines.append("### 5.2 EDGE bucket (E001-E128)")
md_lines.append("")
md_lines.append("| case_id | type (d/r) | coverage_by_this_case | "
                "executed random txn | coverage_incr_per_txn |")
md_lines.append("|---|---|---|---:|---|")
for cid, (bins, prof) in CASES.items():
    if cid[0] != "E":
        continue
    td = "r" if prof["type"] == "promoted" else "d"
    md_lines.append(f"| `{cid}` | {td} | pending | 0 | pending |")
md_lines.append("")

md_lines.append("### 5.3 PROF bucket (P001-P128)")
md_lines.append("")
md_lines.append("| case_id | type (d/r) | coverage_by_this_case | "
                "executed random txn | coverage_incr_per_txn |")
md_lines.append("|---|---|---|---:|---|")
for cid, (bins, prof) in CASES.items():
    if cid[0] != "P":
        continue
    td = "r" if prof["type"] == "promoted" else "d"
    md_lines.append(f"| `{cid}` | {td} | pending | 0 | pending |")
md_lines.append("")

md_lines.append("### 5.4 ERROR bucket (X001-X128)")
md_lines.append("")
md_lines.append("| case_id | type (d/r) | coverage_by_this_case | "
                "executed random txn | coverage_incr_per_txn |")
md_lines.append("|---|---|---|---:|---|")
for cid, (bins, prof) in CASES.items():
    if cid[0] != "X":
        continue
    td = "r" if prof["type"] == "promoted" else "d"
    md_lines.append(f"| `{cid}` | {td} | pending | 0 | pending |")
md_lines.append("")

md_lines.append("## 6. Execution-Mode Baselines")
md_lines.append("")
md_lines.append("| mode | scope | run_id pattern | status |")
md_lines.append("|---|---|---|---|")
md_lines.append("| `isolated` | 512 cases × per-case UCDB | "
                "`emut_<case_id>_isolated_s<seed>.ucdb` | pending |")
md_lines.append("| `bucket_frame` | one bucket end-to-end with "
                "promoted knobs | `emut_<bucket>_frame_s<seed>.ucdb` | "
                "pending |")
md_lines.append("| `all_buckets_frame` | BASIC→EDGE→PROF→ERROR in one "
                "timeframe | `emut_all_buckets_frame_s<seed>.ucdb` | "
                "pending |")
md_lines.append("")

md_lines.append("## 7. Build Axes Coverage")
md_lines.append("")
md_lines.append("| LANE_COUNT | BYTE_STREAM_ENABLE | bin | gated for "
                "26.2.x signoff |")
md_lines.append("|---:|---:|---|---|")
for lc in LANE_COUNT_AXIS:
    for bs in BYTE_STREAM_AXIS:
        gated = "yes" if (lc == 8) else "reported only"
        md_lines.append(f"| {lc} | {bs} | `build_LC{lc}_BS{bs}` | {gated} |")
md_lines.append("")

md_lines.append("_Regenerate with the build script in "
                "`tb/scripts/build_cov_profiles.py` (mirrors "
                "`/tmp/emu_cov_build/build_cov.py` snapshot)._")
md_lines.append("")

with open(os.path.join(OUT_DIR, "DV_COV.md"), "w") as f:
    f.write("\n".join(md_lines))

print(f"wrote {OUT_DIR}/DV_COV.md "
      f"(per-case mean bins {mean_bins:.2f}, "
      f"total bins defined {total_bins})")

# ---------------------------------------------------------------------------
# Emit cov_profile_loader.svh
# ---------------------------------------------------------------------------

# Build a deterministic order for hard-coded tables.
all_case_ids = list(CASES.keys())
all_bin_names = list(ALL_BINS)

# Build the unique knob name list (for the cov_promoted_value lookup).
knob_names = set()
for cid, (_, prof) in CASES.items():
    for k in prof.get("knobs", {}).keys():
        knob_names.add(k)
knob_names = sorted(knob_names)


def lcg_call(min_val, max_val):
    """Render a hard-coded LCG-based promotion expression."""
    def hexnum(v):
        if isinstance(v, str):
            return v
        return f"32'h{v & 0xFFFFFFFF:08x}"
    return f"emut_lcg_uniform_int({hexnum(min_val)}, {hexnum(max_val)})"


def signed_lcg_call(min_val, max_val):
    return (f"emut_lcg_uniform_int_signed("
            f"32'sd{int(min_val)}, 32'sd{int(max_val)})")


sv_lines = []
sv_lines.append("// SPDX-License-Identifier: BSD-3-Clause")
sv_lines.append("// emulator_mutrig DV — coverage profile loader")
sv_lines.append("//")
sv_lines.append("// Hard-coded table of per-case coverage bins and "
                "random-promotion knobs.")
sv_lines.append("// Generated from `tb/cov_profiles.json` — do NOT edit by "
                "hand; regenerate via the build script in "
                "`tb/scripts/build_cov_profiles.py`.")
sv_lines.append("//")
sv_lines.append("// Questa FSE Starter Edition constraints (per "
                "/home/yifeng/CLAUDE.md):")
sv_lines.append("//   - no `covergroup` / no `rand` / no DPI;")
sv_lines.append("//   - LCG-based PRNG provided locally;")
sv_lines.append("//   - per-bin counters in a flat `int unsigned` array.")
sv_lines.append("")
sv_lines.append("`ifndef EMUT_COV_PROFILE_LOADER_SVH")
sv_lines.append("`define EMUT_COV_PROFILE_LOADER_SVH")
sv_lines.append("")
sv_lines.append("package emut_cov_profile_pkg;")
sv_lines.append("")
sv_lines.append(f"  localparam int unsigned COV_N_CASES = {len(all_case_ids)};")
sv_lines.append(f"  localparam int unsigned COV_N_BINS  = "
                f"{len(all_bin_names)};")
sv_lines.append("")
sv_lines.append("  // Per-bin hit counters. Increment via "
                "`cov_record_bins`.")
sv_lines.append("  int unsigned cov_bin_count [COV_N_BINS];")
sv_lines.append("")
sv_lines.append("  // ---------------------------------------------------"
                "-----------------")
sv_lines.append("  // LCG state and helpers (Questa FSE: no `rand`).")
sv_lines.append("  // ---------------------------------------------------"
                "-----------------")
sv_lines.append("  bit [31:0] emut_lcg_state = 32'h1;")
sv_lines.append("")
sv_lines.append("  function automatic void emut_lcg_seed(input bit [31:0] "
                "seed);")
sv_lines.append("    emut_lcg_state = (seed == 32'h0) ? 32'h1 : seed;")
sv_lines.append("  endfunction")
sv_lines.append("")
sv_lines.append("  function automatic bit [31:0] emut_lcg_next();")
sv_lines.append("    // Numerical Recipes LCG (Park-Miller variant).")
sv_lines.append("    emut_lcg_state = emut_lcg_state * 32'h0019_660D + "
                "32'h3C6E_F35F;")
sv_lines.append("    return emut_lcg_state;")
sv_lines.append("  endfunction")
sv_lines.append("")
sv_lines.append("  function automatic bit [31:0] emut_lcg_uniform_int("
                "input bit [31:0] lo, input bit [31:0] hi);")
sv_lines.append("    bit [63:0] span;")
sv_lines.append("    bit [31:0] r;")
sv_lines.append("    if (hi <= lo) return lo;")
sv_lines.append("    span = hi - lo + 1;")
sv_lines.append("    r = emut_lcg_next();")
sv_lines.append("    return lo + bit'(r % span[31:0]);")
sv_lines.append("  endfunction")
sv_lines.append("")
sv_lines.append("  function automatic int emut_lcg_uniform_int_signed("
                "input int lo, input int hi);")
sv_lines.append("    int span;")
sv_lines.append("    bit [31:0] r;")
sv_lines.append("    if (hi <= lo) return lo;")
sv_lines.append("    span = hi - lo + 1;")
sv_lines.append("    r = emut_lcg_next();")
sv_lines.append("    return lo + int'(r % span);")
sv_lines.append("  endfunction")
sv_lines.append("")
sv_lines.append("  // ---------------------------------------------------"
                "-----------------")
sv_lines.append("  // Bin name table — index ↔ name mapping.")
sv_lines.append("  // ---------------------------------------------------"
                "-----------------")
sv_lines.append("  string cov_bin_name [COV_N_BINS];")
sv_lines.append("")
sv_lines.append("  function automatic int cov_bin_index_of(string name);")
sv_lines.append("    for (int i = 0; i < COV_N_BINS; i++) begin")
sv_lines.append("      if (cov_bin_name[i] == name) return i;")
sv_lines.append("    end")
sv_lines.append("    return -1;")
sv_lines.append("  endfunction")
sv_lines.append("")
sv_lines.append("  // Bin → case-id list is built by the case table init.")
sv_lines.append("  // For Questa FSE compactness we use a flat 2-level "
                "lookup: case-id index → list of bin-name strings, plus "
                "case-id index → list of (knob, lo, hi) tuples.")
sv_lines.append("")
sv_lines.append("  string  cov_case_id        [COV_N_CASES];")
sv_lines.append("  string  cov_case_bins      [COV_N_CASES][];")
sv_lines.append("  string  cov_case_knob_name [COV_N_CASES][];")
sv_lines.append("  bit [31:0] cov_case_knob_lo [COV_N_CASES][];")
sv_lines.append("  bit [31:0] cov_case_knob_hi [COV_N_CASES][];")
sv_lines.append("  bit        cov_case_knob_is_signed [COV_N_CASES][];")
sv_lines.append("  bit        cov_case_promoted [COV_N_CASES];")
sv_lines.append("")
sv_lines.append("  function automatic int cov_case_index_of(string id);")
sv_lines.append("    for (int i = 0; i < COV_N_CASES; i++) begin")
sv_lines.append("      if (cov_case_id[i] == id) return i;")
sv_lines.append("    end")
sv_lines.append("    return -1;")
sv_lines.append("  endfunction")
sv_lines.append("")
sv_lines.append("  // ---------------------------------------------------"
                "-----------------")
sv_lines.append("  // Public API:")
sv_lines.append("  //   cov_record_bins(case_id) — increment counters for")
sv_lines.append("  //     every bin the case owns (no-op if id unknown).")
sv_lines.append("  //   cov_promoted_value(case_id, knob_name) — return a")
sv_lines.append("  //     fresh LCG sample inside that case's knob "
                "neighbourhood.")
sv_lines.append("  //     Falls through to 0 if the knob is not declared "
                "for the case.")
sv_lines.append("  // ---------------------------------------------------"
                "-----------------")
sv_lines.append("")
sv_lines.append("  function automatic void cov_record_bins(string "
                "case_id);")
sv_lines.append("    int ci;")
sv_lines.append("    int bi;")
sv_lines.append("    ci = cov_case_index_of(case_id);")
sv_lines.append("    if (ci < 0) return;")
sv_lines.append("    for (int k = 0; k < cov_case_bins[ci].size(); k++) "
                "begin")
sv_lines.append("      bi = cov_bin_index_of(cov_case_bins[ci][k]);")
sv_lines.append("      if (bi >= 0) cov_bin_count[bi] = cov_bin_count[bi] "
                "+ 1;")
sv_lines.append("    end")
sv_lines.append("  endfunction")
sv_lines.append("")
sv_lines.append("  function automatic int unsigned cov_promoted_value("
                "string case_id, string knob_name);")
sv_lines.append("    int ci;")
sv_lines.append("    ci = cov_case_index_of(case_id);")
sv_lines.append("    if (ci < 0) return 32'h0;")
sv_lines.append("    for (int k = 0; k < cov_case_knob_name[ci].size(); "
                "k++) begin")
sv_lines.append("      if (cov_case_knob_name[ci][k] == knob_name) begin")
sv_lines.append("        if (cov_case_knob_is_signed[ci][k])")
sv_lines.append("          return bit'(emut_lcg_uniform_int_signed(")
sv_lines.append("            int'(cov_case_knob_lo[ci][k]),")
sv_lines.append("            int'(cov_case_knob_hi[ci][k])));")
sv_lines.append("        else")
sv_lines.append("          return emut_lcg_uniform_int(")
sv_lines.append("            cov_case_knob_lo[ci][k],")
sv_lines.append("            cov_case_knob_hi[ci][k]);")
sv_lines.append("      end")
sv_lines.append("    end")
sv_lines.append("    return 32'h0;")
sv_lines.append("  endfunction")
sv_lines.append("")
sv_lines.append("  function automatic bit cov_case_is_promoted("
                "string case_id);")
sv_lines.append("    int ci;")
sv_lines.append("    ci = cov_case_index_of(case_id);")
sv_lines.append("    if (ci < 0) return 1'b0;")
sv_lines.append("    return cov_case_promoted[ci];")
sv_lines.append("  endfunction")
sv_lines.append("")
sv_lines.append("  // ---------------------------------------------------"
                "-----------------")
sv_lines.append("  // Static initializer — populates bin and case tables.")
sv_lines.append("  // ---------------------------------------------------"
                "-----------------")
sv_lines.append("")
sv_lines.append("  function automatic void cov_profile_init();")
sv_lines.append("    int ci;")
sv_lines.append("    // Bin name table")
for i, b in enumerate(all_bin_names):
    sv_lines.append(f'    cov_bin_name[{i}] = "{b}";')
sv_lines.append("")
sv_lines.append("    for (int i = 0; i < COV_N_BINS; i++) "
                "cov_bin_count[i] = 0;")
sv_lines.append("")
sv_lines.append("    // Case ID table")
for i, cid in enumerate(all_case_ids):
    sv_lines.append(f'    cov_case_id[{i}] = "{cid}";')
sv_lines.append("")

# Per-case bin and knob tables
for i, cid in enumerate(all_case_ids):
    bins, prof = CASES[cid]
    promoted = prof["type"] == "promoted"
    knobs = prof.get("knobs", {}) if promoted else {}
    sv_lines.append(f"    // {cid} : {len(bins)} bins, "
                    f"{'promoted' if promoted else 'directed'}")
    sv_lines.append(f"    ci = {i};")
    sv_lines.append(f"    cov_case_promoted[ci] = "
                    f"{'1' if promoted else '0'};")
    sv_lines.append(f"    cov_case_bins[ci] = new[{len(bins)}];")
    for j, b in enumerate(bins):
        sv_lines.append(f'    cov_case_bins[ci][{j}] = "{b}";')
    n_knobs = len(knobs)
    sv_lines.append(f"    cov_case_knob_name[ci] = new[{n_knobs}];")
    sv_lines.append(f"    cov_case_knob_lo[ci] = new[{n_knobs}];")
    sv_lines.append(f"    cov_case_knob_hi[ci] = new[{n_knobs}];")
    sv_lines.append(f"    cov_case_knob_is_signed[ci] = new[{n_knobs}];")
    for j, (kname, kspec) in enumerate(knobs.items()):
        sv_lines.append(f'    cov_case_knob_name[ci][{j}] = "{kname}";')
        dist = kspec.get("distribution", "")
        is_signed = "1" if dist == "uniform_int_signed" else "0"
        lo = kspec.get("min", 0)
        hi = kspec.get("max", 0)
        # Strings like "0xFFFFFFFF" must be parsed.
        if isinstance(lo, str):
            lo_int = int(lo, 0)
        else:
            lo_int = int(lo)
        if isinstance(hi, str):
            hi_int = int(hi, 0)
        else:
            hi_int = int(hi)
        # SV 32-bit literal must fit
        lo_int = lo_int & 0xFFFFFFFF
        hi_int = hi_int & 0xFFFFFFFF
        sv_lines.append(f"    cov_case_knob_lo[ci][{j}] = "
                        f"32'h{lo_int:08x};")
        sv_lines.append(f"    cov_case_knob_hi[ci][{j}] = "
                        f"32'h{hi_int:08x};")
        sv_lines.append(f"    cov_case_knob_is_signed[ci][{j}] = "
                        f"1'b{is_signed};")

sv_lines.append("  endfunction")
sv_lines.append("")
sv_lines.append("endpackage : emut_cov_profile_pkg")
sv_lines.append("")
sv_lines.append("`endif // EMUT_COV_PROFILE_LOADER_SVH")

with open(os.path.join(OUT_DIR, "uvm", "cov_profile_loader.svh"), "w") as f:
    f.write("\n".join(sv_lines))

print(f"wrote {OUT_DIR}/uvm/cov_profile_loader.svh "
      f"(N_CASES={len(all_case_ids)}, N_BINS={len(all_bin_names)})")
