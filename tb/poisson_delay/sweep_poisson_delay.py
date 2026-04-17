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


def bucket_counts(parser_delays):
    thresholds = [910, 1820, 3640]
    counts = [0, 0, 0, 0]
    for delay in parser_delays:
        if delay <= thresholds[0]:
            counts[0] += 1
        elif delay <= thresholds[1]:
            counts[1] += 1
        elif delay <= thresholds[2]:
            counts[2] += 1
        else:
            counts[3] += 1
    return counts


def summarize_latency(csv_path):
    queue_delays = []
    parser_delays = []
    serializer_delays = []
    with open(csv_path, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            queue_delays.append(int(row["queue_delay_cycles"]))
            parser_delays.append(int(row["parser_delay_cycles"]))
            serializer_delays.append(int(row["serializer_delay_cycles"]))

    if not parser_delays:
        return {
            "samples": 0,
            "queue_mean": None,
            "queue_p50": None,
            "queue_p90": None,
            "queue_p99": None,
            "queue_max": None,
            "parser_mean": None,
            "parser_p50": None,
            "parser_p90": None,
            "parser_p99": None,
            "parser_max": None,
            "serializer_mean": None,
            "gt_1f": 0,
            "gt_2f": 0,
            "gt_4f": 0,
        }

    b0, b1, b2, b3 = bucket_counts(parser_delays)
    return {
        "samples": len(parser_delays),
        "queue_mean": statistics.fmean(queue_delays),
        "queue_p50": percentile(queue_delays, 0.50),
        "queue_p90": percentile(queue_delays, 0.90),
        "queue_p99": percentile(queue_delays, 0.99),
        "queue_max": max(queue_delays),
        "parser_mean": statistics.fmean(parser_delays),
        "parser_p50": percentile(parser_delays, 0.50),
        "parser_p90": percentile(parser_delays, 0.90),
        "parser_p99": percentile(parser_delays, 0.99),
        "parser_max": max(parser_delays),
        "serializer_mean": statistics.fmean(serializer_delays),
        "gt_1f": b1 + b2 + b3,
        "gt_2f": b2 + b3,
        "gt_4f": b3,
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
            "measured_hits": summary["measured_parser_hits"],
            "avg_occupancy": summary["average_occupancy_milli"] / 1000.0,
            "max_occupancy": summary["max_occupancy"],
            "full_cycles": summary["full_cycles"],
            **latency,
        }
        rows.append(row)

    summary_csv = RESULTS / "poisson_delay_summary.csv"
    with open(summary_csv, "w", encoding="utf-8", newline="") as f:
        fieldnames = [
            "fraction_of_raw_full", "hit_rate_cfg",
            "target_hits_per_cycle", "accepted_hits_per_cycle", "util_of_raw_full",
            "measured_hits", "samples", "avg_occupancy", "max_occupancy", "full_cycles",
            "queue_mean", "queue_p50", "queue_p90", "queue_p99", "queue_max",
            "parser_mean", "parser_p50", "parser_p90", "parser_p99", "parser_max",
            "serializer_mean", "gt_1f", "gt_2f", "gt_4f",
        ]
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)

    report_md = RESULTS / "POISSON_DELAY_REPORT.md"
    with open(report_md, "w", encoding="utf-8") as f:
        f.write("# Poisson Delay Sweep\n\n")
        f.write(f"- Mode: short-mode Poisson, burst_size=1, noise=0\n")
        f.write(f"- Raw full-link reference: {FULL_LINK_HITS_PER_CYCLE:.6f} hits/cycle = 1 hit / 3.5 cycles\n")
        f.write(f"- Warmup cycles per point: {WARMUP_CYCLES}\n")
        f.write(f"- Measured cycles per point: {MEASURE_CYCLES}\n")
        f.write(f"- Drain timeout cycles: {DRAIN_TIMEOUT_CYCLES}\n\n")

        f.write("## Summary Table\n\n")
        f.write("| raw full % | hit_rate | accepted hits/cycle | avg occ | max occ | full cycles | queue p50/p90/p99/max | parser p50/p90/p99/max |\n")
        f.write("|---:|---:|---:|---:|---:|---:|---|---|\n")
        for row in rows:
            f.write(
                f"| {row['fraction_of_raw_full']*100:.0f} | {row['hit_rate_cfg']} | "
                f"{row['accepted_hits_per_cycle']:.4f} | {row['avg_occupancy']:.1f} | "
                f"{row['max_occupancy']} | {row['full_cycles']} | "
                f"{fmt_num(row['queue_p50'])}/{fmt_num(row['queue_p90'])}/{fmt_num(row['queue_p99'])}/{fmt_num(row['queue_max'])} | "
                f"{fmt_num(row['parser_p50'])}/{fmt_num(row['parser_p90'])}/{fmt_num(row['parser_p99'])}/{fmt_num(row['parser_max'])} |\n"
            )

        f.write("\n## Long-Tail Buckets\n\n")
        f.write("| raw full % | >1 frame | >2 frames | >4 frames |\n")
        f.write("|---:|---:|---:|---:|\n")
        for row in rows:
            samples = row["samples"] or 1
            f.write(
                f"| {row['fraction_of_raw_full']*100:.0f} | "
                f"{100.0*row['gt_1f']/samples:.2f}% | "
                f"{100.0*row['gt_2f']/samples:.2f}% | "
                f"{100.0*row['gt_4f']/samples:.2f}% |\n"
            )

        f.write("\n## Notes\n\n")
        f.write("- Queue delay is measured from hit enqueue into the L2 FIFO to the cycle where the FIFO pop occurs.\n")
        f.write("- Parser delay is measured from hit enqueue to parser-visible `hit_valid`.\n")
        f.write("- `full_cycles > 0` indicates the lane FIFO reached saturation during the measured window.\n")
        f.write("- At 100% of the raw 3.5-cycles/hit limit, framed overhead makes the lane slightly oversubscribed, so the tail can keep growing with longer runs.\n")

    print(f"Wrote {summary_csv}")
    print(f"Wrote {report_md}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
