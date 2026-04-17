#!/usr/bin/env python3
import argparse
import csv
import math
import pathlib
import statistics
import subprocess
import sys


ROOT = pathlib.Path(__file__).resolve().parent
RESULTS = ROOT / "results"
RESULTS.mkdir(exist_ok=True)

FULL_LINK_HITS_PER_CYCLE = 1.0 / 3.5
FRACTIONS = [0.00, 0.10, 0.20, 0.40, 0.60, 0.80, 0.90, 0.95, 1.00]
WARMUP_CYCLES = 50_000
MEASURE_CYCLES = 200_000
DRAIN_TIMEOUT_CYCLES = 400_000
FRAME_INTERVAL_SHORT = 910
PRBS15_INIT = 0x7FFF
PRBS15_PERIOD = 0x7FFF


def run_cmd(cmd):
    print("+", " ".join(cmd), flush=True)
    subprocess.run(cmd, cwd=ROOT, check=True)


def parse_summary(path):
    data = {}
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or "=" not in line:
                continue
            key, value = line.split("=", 1)
            data[key] = int(value)
    return data


def percentile(values, pct):
    if not values:
        return None
    if len(values) == 1:
        return values[0]
    values = sorted(values)
    pos = (len(values) - 1) * pct
    lo = math.floor(pos)
    hi = math.ceil(pos)
    if lo == hi:
        return values[lo]
    frac = pos - lo
    return values[lo] + (values[hi] - values[lo]) * frac


def prbs15_step(state):
    return ((state << 1) & 0x7FFE) | (((state >> 14) ^ state) & 0x1)


def build_prbs15_rank():
    ranks = {}
    state = PRBS15_INIT
    for idx in range(PRBS15_PERIOD):
        ranks[state] = idx
        state = prbs15_step(state)
    return ranks


PRBS15_RANK = build_prbs15_rank()


def prbs15_delta_cycles(hit_tcc, pop_tcc):
    return (PRBS15_RANK[pop_tcc] - PRBS15_RANK[hit_tcc]) % PRBS15_PERIOD


def frame_band_counts(latencies):
    counts = [0, 0, 0]
    for latency in latencies:
        if latency < FRAME_INTERVAL_SHORT:
            counts[0] += 1
        elif latency < (2 * FRAME_INTERVAL_SHORT):
            counts[1] += 1
        else:
            counts[2] += 1
    return counts


def histogram(values, lo, hi, bins):
    if bins <= 0:
        return []
    if not values:
        return [{"lo": lo, "hi": hi, "count": 0}]
    width = (hi - lo) / bins
    if width <= 0:
        width = 1.0
    counts = [0 for _ in range(bins)]
    for value in values:
        if value < lo:
            idx = 0
        elif value >= hi:
            idx = bins - 1
        else:
            idx = int((value - lo) / width)
            if idx >= bins:
                idx = bins - 1
        counts[idx] += 1
    out = []
    for idx, count in enumerate(counts):
        bin_lo = lo + idx * width
        bin_hi = lo + (idx + 1) * width
        out.append({"lo": bin_lo, "hi": bin_hi, "count": count})
    return out


def summarize_latency(csv_path):
    commit_to_pop_latencies = []
    true_ts_pop_latencies = []
    t_ts_pop_latencies = []
    with open(csv_path, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            commit_to_pop_latencies.append(int(row["commit_to_pop_cycles"]))
            hit_tcc = int(row["hit_tcc"], 0)
            hit_tfine = int(row["hit_tfine"])
            hit_ecc = int(row["hit_ecc"], 0)
            hit_efine = int(row["hit_efine"])
            pop_tcc = int(row["pop_tcc"], 0)
            pop_ecc = int(row["pop_ecc"], 0)
            t_coarse_delta = prbs15_delta_cycles(hit_tcc, pop_tcc)
            e_coarse_delta = prbs15_delta_cycles(hit_ecc, pop_ecc)
            t_ts_pop_latencies.append(t_coarse_delta - (hit_tfine / 32.0))
            true_ts_pop_latencies.append(e_coarse_delta - (hit_efine / 32.0))

    if not commit_to_pop_latencies:
        return {
            "samples": 0,
            "commit_mean": None,
            "commit_p50": None,
            "commit_p90": None,
            "commit_p99": None,
            "commit_min": None,
            "commit_max": None,
            "true_ts_pop_mean": None,
            "true_ts_pop_p01": None,
            "true_ts_pop_p50": None,
            "true_ts_pop_p90": None,
            "true_ts_pop_p99": None,
            "true_ts_pop_min": None,
            "true_ts_pop_max": None,
            "t_ts_pop_mean": None,
            "t_ts_pop_p01": None,
            "t_ts_pop_p50": None,
            "t_ts_pop_p90": None,
            "t_ts_pop_p99": None,
            "t_ts_pop_min": None,
            "t_ts_pop_max": None,
            "in_1f": 0,
            "in_2f_only": 0,
            "ge_2f": 0,
            "hist_1f": [],
            "hist_2f": [],
        }

    in_1f, in_2f_only, ge_2f = frame_band_counts(true_ts_pop_latencies)
    return {
        "samples": len(commit_to_pop_latencies),
        "commit_mean": statistics.fmean(commit_to_pop_latencies),
        "commit_min": min(commit_to_pop_latencies),
        "commit_p50": percentile(commit_to_pop_latencies, 0.50),
        "commit_p90": percentile(commit_to_pop_latencies, 0.90),
        "commit_p99": percentile(commit_to_pop_latencies, 0.99),
        "commit_max": max(commit_to_pop_latencies),
        "true_ts_pop_mean": statistics.fmean(true_ts_pop_latencies),
        "true_ts_pop_p01": percentile(true_ts_pop_latencies, 0.01),
        "true_ts_pop_p50": percentile(true_ts_pop_latencies, 0.50),
        "true_ts_pop_p90": percentile(true_ts_pop_latencies, 0.90),
        "true_ts_pop_p99": percentile(true_ts_pop_latencies, 0.99),
        "true_ts_pop_min": min(true_ts_pop_latencies),
        "true_ts_pop_max": max(true_ts_pop_latencies),
        "t_ts_pop_mean": statistics.fmean(t_ts_pop_latencies),
        "t_ts_pop_p01": percentile(t_ts_pop_latencies, 0.01),
        "t_ts_pop_p50": percentile(t_ts_pop_latencies, 0.50),
        "t_ts_pop_p90": percentile(t_ts_pop_latencies, 0.90),
        "t_ts_pop_p99": percentile(t_ts_pop_latencies, 0.99),
        "t_ts_pop_min": min(t_ts_pop_latencies),
        "t_ts_pop_max": max(t_ts_pop_latencies),
        "in_1f": in_1f,
        "in_2f_only": in_2f_only,
        "ge_2f": ge_2f,
        "hist_1f": histogram(true_ts_pop_latencies, 0.0, FRAME_INTERVAL_SHORT, 14),
        "hist_2f": histogram(true_ts_pop_latencies, 0.0, 2 * FRAME_INTERVAL_SHORT, 14),
    }


def fmt_num(value):
    if value is None:
        return "n/a"
    if isinstance(value, float):
        return f"{value:.1f}"
    return str(value)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--reuse-existing", action="store_true",
                        help="skip simulation runs and summarize the existing results directory")
    args = parser.parse_args()

    if not args.reuse_existing:
        run_cmd(["make", "compile"])

    rows = []
    for frac in FRACTIONS:
        hit_rate = round(frac * FULL_LINK_HITS_PER_CYCLE * 65536.0)
        tag = f"f{int(round(frac * 100)):03d}_hr{hit_rate:05d}"
        csv_path = RESULTS / f"{tag}.csv"
        summary_path = RESULTS / f"{tag}.summary"

        if not args.reuse_existing:
            run_cmd([
                "make", "run",
                f"HIT_RATE={hit_rate}",
                f"WARMUP_CYCLES={WARMUP_CYCLES}",
                f"MEASURE_CYCLES={MEASURE_CYCLES}",
                f"DRAIN_TIMEOUT_CYCLES={DRAIN_TIMEOUT_CYCLES}",
                f"OUT_CSV={csv_path}",
                f"OUT_SUMMARY={summary_path}",
            ])

        summary = parse_summary(summary_path)
        latency = summarize_latency(csv_path)

        target_hits_per_cycle = frac * FULL_LINK_HITS_PER_CYCLE
        accepted_hits_per_cycle = summary["measured_accepted_hits"] / MEASURE_CYCLES
        util_of_raw_full = accepted_hits_per_cycle / FULL_LINK_HITS_PER_CYCLE if FULL_LINK_HITS_PER_CYCLE else 0.0

        row = {
            "fraction_of_raw_full": frac,
            "hit_rate_cfg": hit_rate,
            "target_hits_per_cycle": target_hits_per_cycle,
            "accepted_hits_per_cycle": accepted_hits_per_cycle,
            "util_of_raw_full": util_of_raw_full,
            "measured_hits": summary["measured_popped_hits"],
            "avg_occupancy": summary["average_occupancy_milli"] / 1000.0,
            "max_occupancy": summary["max_occupancy"],
            "full_cycles": summary["full_cycles"],
            "max_measured_outstanding": summary["max_measured_outstanding"],
            **latency,
        }
        rows.append(row)

    summary_csv = RESULTS / "poisson_delay_summary.csv"
    with open(summary_csv, "w", encoding="utf-8", newline="") as f:
        fieldnames = [
            "fraction_of_raw_full", "hit_rate_cfg",
            "target_hits_per_cycle", "accepted_hits_per_cycle", "util_of_raw_full",
            "measured_hits", "samples", "avg_occupancy", "max_occupancy", "full_cycles",
            "commit_mean", "commit_min", "commit_p50", "commit_p90", "commit_p99", "commit_max",
            "true_ts_pop_mean", "true_ts_pop_p01", "true_ts_pop_p50", "true_ts_pop_p90", "true_ts_pop_p99", "true_ts_pop_min", "true_ts_pop_max",
            "t_ts_pop_mean", "t_ts_pop_p01", "t_ts_pop_p50", "t_ts_pop_p90", "t_ts_pop_p99", "t_ts_pop_min", "t_ts_pop_max",
            "in_1f", "in_2f_only", "ge_2f", "max_measured_outstanding",
        ]
        writer = csv.DictWriter(f, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        for row in rows:
            out_row = dict(row)
            out_row.pop("hist_1f", None)
            out_row.pop("hist_2f", None)
            writer.writerow(out_row)

    report_md = RESULTS / "POISSON_DELAY_REPORT.md"
    with open(report_md, "w", encoding="utf-8") as f:
        f.write("# Poisson Delay Sweep\n\n")
        f.write(f"- Mode: short-mode Poisson, burst_size=1, noise=0\n")
        f.write(f"- Raw full-link reference: {FULL_LINK_HITS_PER_CYCLE:.6f} hits/cycle = 1 hit / 3.5 cycles\n")
        f.write(f"- Warmup cycles per point: {WARMUP_CYCLES}\n")
        f.write(f"- Measured cycles per point: {MEASURE_CYCLES}\n")
        f.write(f"- Drain timeout cycles: {DRAIN_TIMEOUT_CYCLES}\n\n")
        f.write("Default timestamp contract for this sweep:\n\n")
        f.write("- long-hit `E` timestamp is the true commit timestamp\n")
        f.write("- long-hit `T` timestamp is constrained to `T <= E`\n")
        f.write("- the primary latency metric is therefore `E-ts -> pop`\n\n")

        f.write("## Summary Table\n\n")
        f.write("| raw full % | hit_rate | accepted hits/cycle | avg occ | max occ | full cycles | true-ts -> pop min/p50/p90/p99/max | <1 frame | 1..2 frames | >=2 frames |\n")
        f.write("|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|\n")
        for row in rows:
            f.write(
                f"| {row['fraction_of_raw_full']*100:.0f} | {row['hit_rate_cfg']} | "
                f"{row['accepted_hits_per_cycle']:.4f} | {row['avg_occupancy']:.1f} | "
                f"{row['max_occupancy']} | {row['full_cycles']} | "
                f"{fmt_num(row['true_ts_pop_min'])}/{fmt_num(row['true_ts_pop_p50'])}/{fmt_num(row['true_ts_pop_p90'])}/{fmt_num(row['true_ts_pop_p99'])}/{fmt_num(row['true_ts_pop_max'])} | "
                f"{100.0*row['in_1f']/(row['samples'] or 1):.2f}% | "
                f"{100.0*row['in_2f_only']/(row['samples'] or 1):.2f}% | "
                f"{100.0*row['ge_2f']/(row['samples'] or 1):.2f}% |\n"
            )

        f.write("\n## Cross-Checks\n\n")
        f.write("| raw full % | commit-cycle -> pop p50/p90/p99/max | true-ts -> pop p01/p50/p90/p99/max | T-ts -> pop p01/p50/p90/p99/max | max measured outstanding |\n")
        f.write("|---:|---|---|---|---:|\n")
        for row in rows:
            f.write(
                f"| {row['fraction_of_raw_full']*100:.0f} | "
                f"{fmt_num(row['commit_p50'])}/{fmt_num(row['commit_p90'])}/{fmt_num(row['commit_p99'])}/{fmt_num(row['commit_max'])} | "
                f"{fmt_num(row['true_ts_pop_p01'])}/{fmt_num(row['true_ts_pop_p50'])}/{fmt_num(row['true_ts_pop_p90'])}/{fmt_num(row['true_ts_pop_p99'])}/{fmt_num(row['true_ts_pop_max'])} | "
                f"{fmt_num(row['t_ts_pop_p01'])}/{fmt_num(row['t_ts_pop_p50'])}/{fmt_num(row['t_ts_pop_p90'])}/{fmt_num(row['t_ts_pop_p99'])}/{fmt_num(row['t_ts_pop_max'])} | "
                f"{row['max_measured_outstanding']} |\n"
            )

        def write_histogram_section(title, hist_rows, samples):
            f.write(f"\n### {title}\n\n")
            f.write("| bin | latency range (cycles) | samples | pct |\n")
            f.write("|---:|---|---:|---:|\n")
            for idx, hist_row in enumerate(hist_rows):
                pct = 100.0 * hist_row["count"] / (samples or 1)
                f.write(
                    f"| {idx:02d} | {hist_row['lo']:.1f} .. {hist_row['hi']:.1f} | "
                    f"{hist_row['count']} | {pct:.2f}% |\n"
                )

        low_row = next((row for row in rows if row["fraction_of_raw_full"] == 0.10), None)
        high_row = next((row for row in rows if row["fraction_of_raw_full"] == 1.00), None)

        if low_row is not None:
            write_histogram_section("Low-Load Shape (10% of raw full rate, true-ts -> pop, 0..1 frame window)",
                                    low_row["hist_1f"], low_row["samples"])
        if high_row is not None:
            write_histogram_section("Full-Load Shape (100% of raw full rate, true-ts -> pop, 0..2 frame window)",
                                    high_row["hist_2f"], high_row["samples"])

        f.write("\n## Notes\n\n")
        f.write("- `true-ts -> pop` is reconstructed as `prbs_delta(pop_ecc, hit_ecc) - hit_efine/32`. In the default mode under test this is the true hit timestamp because the hit commits on the encoded `E` timestamp.\n")
        f.write("- `commit-cycle -> pop` is kept as a same-cycle sanity cross-check that ignores the sub-cycle fine timestamp fraction.\n")
        f.write("- `T-ts -> pop` is kept as a consistency cross-check for the `T <= E` timing contract.\n")
        f.write("- Pop is defined as the cycle where the frame assembler asserts the L2 FIFO read handshake.\n")
        f.write("- The low-load minimum is not exactly zero because the earliest eligible pop still sits behind the frame header and event-count bytes, which costs about `32` byte clocks in this wrapper.\n")
        f.write("- At `100%` of the raw `1 hit / 3.5 cycles` reference, the measured true-timestamp latency stays mostly in the `0.8 .. 1.15` frame range rather than filling a full `0 .. 2` frame box. The short-mode packer keeps draining continuously inside an already-open frame, so this regime is not a pure whole-frame-queued service model.\n")
        f.write("- The bench keeps the lane running after the main measurement window until every measured hit has popped, so pop-time coarse counters stay valid.\n")
        f.write("- `full_cycles > 0` indicates the lane FIFO reached saturation during the measured window.\n")

    print(f"Wrote {summary_csv}")
    print(f"Wrote {report_md}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
