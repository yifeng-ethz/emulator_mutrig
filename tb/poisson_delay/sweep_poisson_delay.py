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
RAW_FIFO_DEPTH = 256


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
        out.append({
            "lo": lo + idx * width,
            "hi": lo + (idx + 1) * width,
            "count": count,
        })
    return out


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


def summarize_values(values):
    if not values:
        return {
            "mean": None,
            "p01": None,
            "p50": None,
            "p90": None,
            "p99": None,
            "min": None,
            "max": None,
        }
    return {
        "mean": statistics.fmean(values),
        "p01": percentile(values, 0.01),
        "p50": percentile(values, 0.50),
        "p90": percentile(values, 0.90),
        "p99": percentile(values, 0.99),
        "min": min(values),
        "max": max(values),
    }


def fmt_num(value):
    if value is None:
        return "n/a"
    if isinstance(value, float):
        return f"{value:.1f}"
    return str(value)


def parser_complete_offset(slot_index):
    base = 10 + (slot_index // 2) * 7
    if slot_index & 1:
        return base + 3
    return base


def load_hit_rows(csv_path):
    rows = []
    with open(csv_path, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            hit_efine = int(row["hit_efine"])
            commit_cycle = int(row["commit_cycle"])
            pop_cycle = int(row["pop_cycle"])
            parser_cycle = int(row["parser_cycle"])
            frame_start_cycle = int(row["frame_start_cycle"])
            true_ts = commit_cycle + (hit_efine / 32.0)
            rows.append({
                "commit_cycle": commit_cycle,
                "pop_cycle": pop_cycle,
                "parser_cycle": parser_cycle,
                "frame_start_cycle": frame_start_cycle,
                "commit_to_pop_cycles": int(row["commit_to_pop_cycles"]),
                "commit_to_parser_cycles": int(row["commit_to_parser_cycles"]),
                "frame_start_to_pop_cycles": int(row["frame_start_to_pop_cycles"]),
                "frame_start_to_parser_cycles": int(row["frame_start_to_parser_cycles"]),
                "hit_tcc": int(row["hit_tcc"], 0),
                "hit_tfine": int(row["hit_tfine"]),
                "hit_ecc": int(row["hit_ecc"], 0),
                "hit_efine": hit_efine,
                "measure_window": int(row["measure_window"]),
                "true_ts": true_ts,
                "true_ts_to_pop": pop_cycle - true_ts,
                "true_ts_to_frame_start": frame_start_cycle - true_ts,
                "true_ts_to_output": parser_cycle - true_ts,
            })
    return rows


def load_frame_rows(csv_path):
    rows = []
    with open(csv_path, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            rows.append({
                "frame_seq": int(row["frame_seq"]),
                "frame_start_cycle": int(row["frame_start_cycle"]),
                "event_count": int(row["event_count"]),
                "fifo_count": int(row["fifo_count"]),
                "pending_valid": int(row["pending_valid"]),
                "total_visible_count": int(row["total_visible_count"]),
                "fifo_almost_full": int(row["fifo_almost_full"]),
                "measure_window": int(row["measure_window"]),
            })
    rows.sort(key=lambda item: item["frame_start_cycle"])
    return rows


def build_tlm_assignments(hit_rows, frame_rows):
    if len(frame_rows) < 2:
        return {
            "assigned": {},
            "dropped": 0,
            "unassigned": len(hit_rows),
        }

    assigned = {}
    dropped = 0
    hit_idx = 0

    frame_cycles = [row["frame_start_cycle"] for row in frame_rows]
    for prev_cycle, curr_cycle in zip(frame_cycles, frame_cycles[1:]):
        window_indices = []
        while hit_idx < len(hit_rows) and hit_rows[hit_idx]["commit_cycle"] < curr_cycle:
            if hit_rows[hit_idx]["commit_cycle"] >= prev_cycle:
                window_indices.append(hit_idx)
            hit_idx += 1
        if len(window_indices) > RAW_FIFO_DEPTH:
            dropped += len(window_indices) - RAW_FIFO_DEPTH
            window_indices = window_indices[-RAW_FIFO_DEPTH:]
        for slot, row_idx in enumerate(window_indices):
            assigned[row_idx] = {
                "tlm_frame_start_cycle": curr_cycle,
                "tlm_parser_cycle": curr_cycle + parser_complete_offset(slot),
                "slot": slot,
            }

    unassigned = len(hit_rows) - len(assigned)
    return {
        "assigned": assigned,
        "dropped": dropped,
        "unassigned": unassigned,
    }


def summarize_trace(hit_csv_path, frame_csv_path):
    hit_rows = load_hit_rows(hit_csv_path)
    frame_rows = load_frame_rows(frame_csv_path)
    tlm = build_tlm_assignments(hit_rows, frame_rows)
    measured_indices = [idx for idx, row in enumerate(hit_rows) if row["measure_window"]]
    measured_rows = [hit_rows[idx] for idx in measured_indices]

    actual_frame_lat = [row["true_ts_to_frame_start"] for row in measured_rows]
    actual_output_lat = [row["true_ts_to_output"] for row in measured_rows]
    actual_pop_lat = [row["true_ts_to_pop"] for row in measured_rows]

    tlm_frame_lat = []
    tlm_output_lat = []
    frame_delta = []
    output_delta = []
    exact_frame_matches = 0
    exact_output_matches = 0
    within_one_output_matches = 0

    measured_dropped_hits = 0
    measured_unassigned_hits = 0
    for row_idx in measured_indices:
        row = hit_rows[row_idx]
        if row_idx not in tlm["assigned"]:
            measured_unassigned_hits += 1
            continue
        assignment = tlm["assigned"][row_idx]
        tlm_frame = assignment["tlm_frame_start_cycle"] - row["true_ts"]
        tlm_output = assignment["tlm_parser_cycle"] - row["true_ts"]
        frame_err = row["frame_start_cycle"] - assignment["tlm_frame_start_cycle"]
        output_err = row["parser_cycle"] - assignment["tlm_parser_cycle"]

        tlm_frame_lat.append(tlm_frame)
        tlm_output_lat.append(tlm_output)
        frame_delta.append(frame_err)
        output_delta.append(output_err)
        if frame_err == 0:
            exact_frame_matches += 1
        if output_err == 0:
            exact_output_matches += 1
        if abs(output_err) <= 1:
            within_one_output_matches += 1

    for row_idx, row in enumerate(hit_rows):
        if row["measure_window"] and row_idx not in tlm["assigned"]:
            measured_dropped_hits += 1

    actual_output_1f, actual_output_2f, actual_output_ge2 = frame_band_counts(actual_output_lat)
    actual_frame_1f, actual_frame_2f, actual_frame_ge2 = frame_band_counts(actual_frame_lat)
    tlm_output_1f, tlm_output_2f, tlm_output_ge2 = frame_band_counts(tlm_output_lat)

    assigned_count = len(tlm_frame_lat)

    return {
        "samples": len(measured_rows),
        "actual_pop": summarize_values(actual_pop_lat),
        "actual_frame": summarize_values(actual_frame_lat),
        "actual_output": summarize_values(actual_output_lat),
        "tlm_frame": summarize_values(tlm_frame_lat),
        "tlm_output": summarize_values(tlm_output_lat),
        "frame_delta": summarize_values(frame_delta),
        "output_delta": summarize_values(output_delta),
        "actual_frame_in_1f": actual_frame_1f,
        "actual_frame_in_2f_only": actual_frame_2f,
        "actual_frame_ge_2f": actual_frame_ge2,
        "actual_output_in_1f": actual_output_1f,
        "actual_output_in_2f_only": actual_output_2f,
        "actual_output_ge_2f": actual_output_ge2,
        "tlm_output_in_1f": tlm_output_1f,
        "tlm_output_in_2f_only": tlm_output_2f,
        "tlm_output_ge_2f": tlm_output_ge2,
        "tlm_assigned_hits": assigned_count,
        "tlm_dropped_hits": measured_dropped_hits,
        "tlm_unassigned_hits": measured_unassigned_hits,
        "rtl_tlm_frame_exact_pct": (100.0 * exact_frame_matches / assigned_count) if assigned_count else 0.0,
        "rtl_tlm_output_exact_pct": (100.0 * exact_output_matches / assigned_count) if assigned_count else 0.0,
        "rtl_tlm_output_within1_pct": (100.0 * within_one_output_matches / assigned_count) if assigned_count else 0.0,
        "actual_frame_hist_1f": histogram(actual_frame_lat, 0.0, FRAME_INTERVAL_SHORT, 14),
        "actual_output_hist_1f": histogram(actual_output_lat, 0.0, FRAME_INTERVAL_SHORT, 14),
        "actual_output_hist_2f": histogram(actual_output_lat, 0.0, 2 * FRAME_INTERVAL_SHORT, 14),
        "tlm_output_hist_2f": histogram(tlm_output_lat, 0.0, 2 * FRAME_INTERVAL_SHORT, 14),
    }


def write_histogram_section(handle, title, hist_rows, samples):
    handle.write(f"\n### {title}\n\n")
    handle.write("| bin | latency range (cycles) | samples | pct |\n")
    handle.write("|---:|---|---:|---:|\n")
    for idx, hist_row in enumerate(hist_rows):
        pct = 100.0 * hist_row["count"] / (samples or 1)
        handle.write(
            f"| {idx:02d} | {hist_row['lo']:.1f} .. {hist_row['hi']:.1f} | "
            f"{hist_row['count']} | {pct:.2f}% |\n"
        )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--reuse-existing",
        action="store_true",
        help="skip simulation runs and summarize the existing results directory",
    )
    args = parser.parse_args()

    if not args.reuse_existing:
        run_cmd(["make", "compile"])

    rows = []
    for frac in FRACTIONS:
        hit_rate = round(frac * FULL_LINK_HITS_PER_CYCLE * 65536.0)
        tag = f"f{int(round(frac * 100)):03d}_hr{hit_rate:05d}"
        hit_csv_path = RESULTS / f"{tag}.csv"
        frame_csv_path = RESULTS / f"{tag}.frames.csv"
        summary_path = RESULTS / f"{tag}.summary"

        if not args.reuse_existing:
            run_cmd([
                "make", "run",
                f"HIT_RATE={hit_rate}",
                f"WARMUP_CYCLES={WARMUP_CYCLES}",
                f"MEASURE_CYCLES={MEASURE_CYCLES}",
                f"DRAIN_TIMEOUT_CYCLES={DRAIN_TIMEOUT_CYCLES}",
                f"OUT_CSV={hit_csv_path}",
                f"OUT_FRAME_CSV={frame_csv_path}",
                f"OUT_SUMMARY={summary_path}",
            ])

        summary = parse_summary(summary_path)
        trace = summarize_trace(hit_csv_path, frame_csv_path)

        accepted_hits_per_cycle = summary["measured_accepted_hits"] / MEASURE_CYCLES
        row = {
            "fraction_of_raw_full": frac,
            "hit_rate_cfg": hit_rate,
            "target_hits_per_cycle": frac * FULL_LINK_HITS_PER_CYCLE,
            "accepted_hits_per_cycle": accepted_hits_per_cycle,
            "util_of_raw_full": accepted_hits_per_cycle / FULL_LINK_HITS_PER_CYCLE if FULL_LINK_HITS_PER_CYCLE else 0.0,
            "measured_hits": summary["measured_output_hits"],
            "avg_occupancy": summary["average_occupancy_milli"] / 1000.0,
            "max_occupancy": summary["max_occupancy"],
            "full_cycles": summary["full_cycles"],
            "frame_start_count": summary["frame_start_count"],
            "max_measured_outstanding": summary["max_measured_outstanding"],
            **trace,
        }
        rows.append(row)

    summary_csv = RESULTS / "poisson_delay_summary.csv"
    with open(summary_csv, "w", encoding="utf-8", newline="") as f:
        fieldnames = [
            "fraction_of_raw_full", "hit_rate_cfg", "target_hits_per_cycle",
            "accepted_hits_per_cycle", "util_of_raw_full", "measured_hits",
            "avg_occupancy", "max_occupancy", "full_cycles", "frame_start_count",
            "samples", "tlm_assigned_hits", "tlm_dropped_hits", "tlm_unassigned_hits",
            "max_measured_outstanding", "rtl_tlm_frame_exact_pct",
            "rtl_tlm_output_exact_pct", "rtl_tlm_output_within1_pct",
            "actual_frame_min", "actual_frame_p50", "actual_frame_p90", "actual_frame_p99", "actual_frame_max",
            "actual_output_min", "actual_output_p50", "actual_output_p90", "actual_output_p99", "actual_output_max",
            "tlm_frame_min", "tlm_frame_p50", "tlm_frame_p90", "tlm_frame_p99", "tlm_frame_max",
            "tlm_output_min", "tlm_output_p50", "tlm_output_p90", "tlm_output_p99", "tlm_output_max",
            "frame_delta_mean", "output_delta_mean", "output_delta_p99",
            "actual_output_in_1f", "actual_output_in_2f_only", "actual_output_ge_2f",
        ]
        writer = csv.DictWriter(f, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        for row in rows:
            writer.writerow({
                "fraction_of_raw_full": row["fraction_of_raw_full"],
                "hit_rate_cfg": row["hit_rate_cfg"],
                "target_hits_per_cycle": row["target_hits_per_cycle"],
                "accepted_hits_per_cycle": row["accepted_hits_per_cycle"],
                "util_of_raw_full": row["util_of_raw_full"],
                "measured_hits": row["measured_hits"],
                "avg_occupancy": row["avg_occupancy"],
                "max_occupancy": row["max_occupancy"],
                "full_cycles": row["full_cycles"],
                "frame_start_count": row["frame_start_count"],
                "samples": row["samples"],
                "tlm_assigned_hits": row["tlm_assigned_hits"],
                "tlm_dropped_hits": row["tlm_dropped_hits"],
                "tlm_unassigned_hits": row["tlm_unassigned_hits"],
                "max_measured_outstanding": row["max_measured_outstanding"],
                "rtl_tlm_frame_exact_pct": row["rtl_tlm_frame_exact_pct"],
                "rtl_tlm_output_exact_pct": row["rtl_tlm_output_exact_pct"],
                "rtl_tlm_output_within1_pct": row["rtl_tlm_output_within1_pct"],
                "actual_frame_min": row["actual_frame"]["min"],
                "actual_frame_p50": row["actual_frame"]["p50"],
                "actual_frame_p90": row["actual_frame"]["p90"],
                "actual_frame_p99": row["actual_frame"]["p99"],
                "actual_frame_max": row["actual_frame"]["max"],
                "actual_output_min": row["actual_output"]["min"],
                "actual_output_p50": row["actual_output"]["p50"],
                "actual_output_p90": row["actual_output"]["p90"],
                "actual_output_p99": row["actual_output"]["p99"],
                "actual_output_max": row["actual_output"]["max"],
                "tlm_frame_min": row["tlm_frame"]["min"],
                "tlm_frame_p50": row["tlm_frame"]["p50"],
                "tlm_frame_p90": row["tlm_frame"]["p90"],
                "tlm_frame_p99": row["tlm_frame"]["p99"],
                "tlm_frame_max": row["tlm_frame"]["max"],
                "tlm_output_min": row["tlm_output"]["min"],
                "tlm_output_p50": row["tlm_output"]["p50"],
                "tlm_output_p90": row["tlm_output"]["p90"],
                "tlm_output_p99": row["tlm_output"]["p99"],
                "tlm_output_max": row["tlm_output"]["max"],
                "frame_delta_mean": row["frame_delta"]["mean"],
                "output_delta_mean": row["output_delta"]["mean"],
                "output_delta_p99": row["output_delta"]["p99"],
                "actual_output_in_1f": row["actual_output_in_1f"],
                "actual_output_in_2f_only": row["actual_output_in_2f_only"],
                "actual_output_ge_2f": row["actual_output_ge_2f"],
            })

    report_md = RESULTS / "POISSON_DELAY_REPORT.md"
    with open(report_md, "w", encoding="utf-8") as f:
        f.write("# Poisson Delay Sweep\n\n")
        f.write("- Mode: short-mode Poisson, burst_size=1, noise=0\n")
        f.write(f"- Raw full-link reference: {FULL_LINK_HITS_PER_CYCLE:.6f} hits/cycle = 1 hit / 3.5 cycles\n")
        f.write(f"- Warmup cycles per point: {WARMUP_CYCLES}\n")
        f.write(f"- Measured cycles per point: {MEASURE_CYCLES}\n")
        f.write(f"- Drain timeout cycles: {DRAIN_TIMEOUT_CYCLES}\n\n")
        f.write("Corrected latency model used in this report:\n\n")
        f.write("- the true hit timestamp is the committed `E` timestamp, so `true_ts = commit_cycle + E_fine/32`\n")
        f.write("- raw MuTRiG `frame_gen` latches `i_event_counts` at frame start and only then drains that frame payload\n")
        f.write("- the frame-marker TLM therefore groups hits by frame window, keeps at most the most recent `256` hits at the marker, and emits them across the next frame with the short-mode `3/4` byte cadence\n")
        f.write("- two latency observables are reported: `true_ts -> frame_start` and `true_ts -> parser_hit_valid`\n\n")

        f.write("## Summary Table\n\n")
        f.write("| raw full % | accepted hits/cycle | avg occ | max occ | full cycles | actual true-ts -> frame-start min/p50/p90/p99/max | actual true-ts -> output min/p50/p90/p99/max |\n")
        f.write("|---:|---:|---:|---:|---:|---|---|\n")
        for row in rows:
            f.write(
                f"| {row['fraction_of_raw_full']*100:.0f} | {row['accepted_hits_per_cycle']:.4f} | "
                f"{row['avg_occupancy']:.1f} | {row['max_occupancy']} | {row['full_cycles']} | "
                f"{fmt_num(row['actual_frame']['min'])}/{fmt_num(row['actual_frame']['p50'])}/{fmt_num(row['actual_frame']['p90'])}/{fmt_num(row['actual_frame']['p99'])}/{fmt_num(row['actual_frame']['max'])} | "
                f"{fmt_num(row['actual_output']['min'])}/{fmt_num(row['actual_output']['p50'])}/{fmt_num(row['actual_output']['p90'])}/{fmt_num(row['actual_output']['p99'])}/{fmt_num(row['actual_output']['max'])} |\n"
            )

        f.write("\n## TLM Comparison\n\n")
        f.write("| raw full % | TLM assigned/dropped/unassigned | TLM true-ts -> frame-start p50/p90/p99/max | TLM true-ts -> output p50/p90/p99/max | RTL frame exact | RTL output exact | RTL output +/-1 cyc |\n")
        f.write("|---:|---:|---|---|---:|---:|---:|\n")
        for row in rows:
            f.write(
                f"| {row['fraction_of_raw_full']*100:.0f} | "
                f"{row['tlm_assigned_hits']}/{row['tlm_dropped_hits']}/{row['tlm_unassigned_hits']} | "
                f"{fmt_num(row['tlm_frame']['p50'])}/{fmt_num(row['tlm_frame']['p90'])}/{fmt_num(row['tlm_frame']['p99'])}/{fmt_num(row['tlm_frame']['max'])} | "
                f"{fmt_num(row['tlm_output']['p50'])}/{fmt_num(row['tlm_output']['p90'])}/{fmt_num(row['tlm_output']['p99'])}/{fmt_num(row['tlm_output']['max'])} | "
                f"{row['rtl_tlm_frame_exact_pct']:.2f}% | "
                f"{row['rtl_tlm_output_exact_pct']:.2f}% | "
                f"{row['rtl_tlm_output_within1_pct']:.2f}% |\n"
            )

        f.write("\n## Cross-Checks\n\n")
        f.write("| raw full % | actual true-ts -> pop p50/p90/p99/max | actual output <1f | actual output 1..2f | actual output >=2f | frame delta mean | output delta mean/p99 |\n")
        f.write("|---:|---|---:|---:|---:|---:|---|\n")
        for row in rows:
            f.write(
                f"| {row['fraction_of_raw_full']*100:.0f} | "
                f"{fmt_num(row['actual_pop']['p50'])}/{fmt_num(row['actual_pop']['p90'])}/{fmt_num(row['actual_pop']['p99'])}/{fmt_num(row['actual_pop']['max'])} | "
                f"{100.0*row['actual_output_in_1f']/(row['samples'] or 1):.2f}% | "
                f"{100.0*row['actual_output_in_2f_only']/(row['samples'] or 1):.2f}% | "
                f"{100.0*row['actual_output_ge_2f']/(row['samples'] or 1):.2f}% | "
                f"{fmt_num(row['frame_delta']['mean'])} | "
                f"{fmt_num(row['output_delta']['mean'])}/{fmt_num(row['output_delta']['p99'])} |\n"
            )

        low_row = next((row for row in rows if row["fraction_of_raw_full"] == 0.10), None)
        high_row = next((row for row in rows if row["fraction_of_raw_full"] == 1.00), None)

        if low_row is not None:
            write_histogram_section(
                f,
                "Low-Load Shape (10% raw full, actual true-ts -> frame-start, 0..1 frame)",
                low_row["actual_frame_hist_1f"],
                low_row["samples"],
            )
            write_histogram_section(
                f,
                "Low-Load Shape (10% raw full, actual true-ts -> output, 0..1 frame)",
                low_row["actual_output_hist_1f"],
                low_row["samples"],
            )
        if high_row is not None:
            write_histogram_section(
                f,
                "Full-Load Shape (100% raw full, actual true-ts -> output, 0..2 frames)",
                high_row["actual_output_hist_2f"],
                high_row["samples"],
            )
            write_histogram_section(
                f,
                "Full-Load Shape (100% raw full, TLM true-ts -> output, 0..2 frames)",
                high_row["tlm_output_hist_2f"],
                high_row["tlm_assigned_hits"],
            )

        f.write("\n## Notes\n\n")
        f.write("- `true-ts -> frame-start` is the direct check for the marker-latch model you described. Its minimum should stay near zero because hits can land immediately before the next marker.\n")
        f.write("- `true-ts -> output` adds the within-frame serialization tail. In short mode the parser completes hits at offsets `9, 12, 16, 19, ...` cycles from the frame-start pulse, which is the measured wrapper-level equivalent of the raw `3.5 cycles / hit` packing cadence.\n")
        f.write("- `actual true-ts -> pop` is kept only as a secondary cross-check because it ignores the serializer tail and was the metric that made the previous report misleading.\n")
        f.write("- `TLM dropped` counts the hits that the corrected frame-marker model would discard when more than `256` hits land between adjacent frame markers.\n")
        f.write("- `RTL frame exact` and `RTL output exact` compare the live RTL trace against that TLM assignment on a per-hit basis.\n")

    print(f"Wrote {summary_csv}")
    print(f"Wrote {report_md}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
