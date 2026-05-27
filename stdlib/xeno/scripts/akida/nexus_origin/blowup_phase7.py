#!/usr/bin/env python3
"""F-A: cli/blowup phase-7 (edge-inference) energy ratio.

Runs the 9-phase pipeline twice (CPU baseline + phase-7-on-Akida) and compares
J for the phase-7 segment only.

Requires:
  - cli/blowup pipeline runnable (`hexa cli/blowup/run.hexa` or equivalent)
  - akida hardware for the phase-7 routed run
  - power source same as energy_meter.py (--power-source)
"""
from __future__ import annotations
import argparse, json, os, subprocess, sys, time

from _akida_runtime import require_akida
from energy_meter import measure_power_window


BLOWUP_BIN = "cli/blowup/run.hexa"


def run_blowup(routed: str, log_dir: str) -> dict:
    if not os.path.exists(BLOWUP_BIN):
        raise SystemExit(f"ERROR: cli/blowup/run.hexa not found at {BLOWUP_BIN}")
    os.makedirs(log_dir, exist_ok=True)
    log = os.path.join(log_dir, f"blowup_{routed}.log")
    cmd = ["hexa", BLOWUP_BIN, "--phase7-route", routed, "--profile", "--log", log]
    t0 = time.time()
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=1800)
    wall = time.time() - t0
    return {"returncode": proc.returncode, "wall": wall, "log": log, "stdout_tail": proc.stdout[-2000:]}


def parse_phase7_segment(log_path: str) -> tuple[float, float] | None:
    if not os.path.exists(log_path):
        return None
    t_start = t_end = None
    with open(log_path) as f:
        for line in f:
            if "phase=7" in line and "start_ts=" in line:
                try:
                    t_start = float(line.split("start_ts=")[1].split()[0])
                except (IndexError, ValueError):
                    pass
            elif "phase=7" in line and "end_ts=" in line:
                try:
                    t_end = float(line.split("end_ts=")[1].split()[0])
                except (IndexError, ValueError):
                    pass
    if t_start is None or t_end is None:
        return None
    return (t_start, t_end)


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--power-source", choices=["csv", "rapl", "rpi5"], default="csv")
    p.add_argument("--power-csv-baseline", default=None)
    p.add_argument("--power-csv-akida", default=None)
    p.add_argument("--out-dir", default="state/akida_evidence")
    args = p.parse_args(argv[1:])

    require_akida(need_device=True)

    log_dir = os.path.join(args.out_dir, "blowup_logs")
    base = run_blowup("cpu", log_dir)
    aki = run_blowup("akida", log_dir)
    if base["returncode"] != 0 or aki["returncode"] != 0:
        print(json.dumps({"error": "blowup run failed", "baseline": base, "akida": aki}, indent=2))
        return 4

    base_seg = parse_phase7_segment(base["log"])
    aki_seg = parse_phase7_segment(aki["log"])
    if base_seg is None or aki_seg is None:
        print(json.dumps({"error": "phase-7 segment markers missing in blowup log", "baseline_log": base["log"], "akida_log": aki["log"]}, indent=2))
        return 5

    base_w, _ = measure_power_window(args.power_source, base_seg[1] - base_seg[0], args.power_csv_baseline)
    aki_w, _ = measure_power_window(args.power_source, aki_seg[1] - aki_seg[0], args.power_csv_akida)
    j_base = base_w * (base_seg[1] - base_seg[0])
    j_aki = aki_w * (aki_seg[1] - aki_seg[0])
    ratio = j_base / max(1e-12, j_aki)
    pass_ = ratio >= 50.0

    ts = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    log_path = os.path.join(args.out_dir, f"F-A_{ts.replace(':', '').replace('-', '')}.json")
    evidence = {
        "falsifier_id": "F-A",
        "measured_ts": ts,
        "measured_value": {
            "j_phase7_baseline": j_base,
            "j_phase7_akida": j_aki,
            "ratio_baseline_over_akida": ratio,
            "threshold": ">= 50",
            "baseline_seg_seconds": base_seg[1] - base_seg[0],
            "akida_seg_seconds": aki_seg[1] - aki_seg[0],
        },
        "verdict": "PASS" if pass_ else "FAIL",
        "raw_log_path": os.path.abspath(log_path),
        "hardware_present": True,
        "command": " ".join(argv),
    }
    with open(log_path, "w") as f:
        json.dump(evidence, f, indent=2)
    print(json.dumps(evidence, indent=2))
    return 0 if pass_ else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
