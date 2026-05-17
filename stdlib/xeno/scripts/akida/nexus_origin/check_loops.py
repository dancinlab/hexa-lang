#!/usr/bin/env python3
"""F-B: nexus check_*_verify hot-loop energy ratio.

For each c in {anima_verify, hbio_verify, hsscb_verify}: J_c_akida <= J_c_baseline / 30.
"""
from __future__ import annotations
import argparse, json, os, subprocess, sys, time

from _akida_runtime import require_akida
from energy_meter import measure_power_window


CHECK_TARGETS = {
    "anima_verify": "calc/anima_verify/run_all.hexa",
    "hbio_verify": "calc/hbio_verify/run_all.hexa",
    "hsscb_verify": "calc/hsscb_verify/run_all.hexa",
}


def run_check(check_name: str, route: str) -> tuple[float, int] | None:
    src = CHECK_TARGETS.get(check_name)
    if not src or not os.path.exists(src):
        return None
    cmd = ["hexa", src, "--inner-loop-route", route]
    t0 = time.time()
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=900)
    wall = time.time() - t0
    return (wall, proc.returncode)


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--checks", default="anima_verify,hbio_verify,hsscb_verify")
    p.add_argument("--power-source", choices=["csv", "rapl", "rpi5"], default="rapl")
    p.add_argument("--power-csv-baseline", default=None)
    p.add_argument("--power-csv-akida", default=None)
    p.add_argument("--out-dir", default="state/akida_evidence")
    args = p.parse_args(argv[1:])

    require_akida(need_device=True)

    results: dict[str, dict] = {}
    all_pass = True
    for c in args.checks.split(","):
        c = c.strip()
        base = run_check(c, "cpu")
        aki = run_check(c, "akida")
        if base is None or aki is None:
            results[c] = {"verdict": "SKIP", "reason": "check target missing"}
            all_pass = False
            continue
        if base[1] != 0 or aki[1] != 0:
            results[c] = {"verdict": "FAIL", "reason": "non-zero exit", "base_rc": base[1], "akida_rc": aki[1]}
            all_pass = False
            continue
        base_w, _ = measure_power_window(args.power_source, base[0], args.power_csv_baseline)
        aki_w, _ = measure_power_window(args.power_source, aki[0], args.power_csv_akida)
        j_base = base_w * base[0]
        j_aki = aki_w * aki[0]
        ratio = j_base / max(1e-12, j_aki)
        passed = ratio >= 30.0
        results[c] = {
            "j_base": j_base, "j_akida": j_aki, "ratio": ratio,
            "verdict": "PASS" if passed else "FAIL",
        }
        all_pass &= passed

    ts = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    os.makedirs(args.out_dir, exist_ok=True)
    log_path = os.path.join(args.out_dir, f"F-B_{ts.replace(':', '').replace('-', '')}.json")
    evidence = {
        "falsifier_id": "F-B",
        "measured_ts": ts,
        "measured_value": {"per_check": results, "threshold": "ratio >= 30 each"},
        "verdict": "PASS" if all_pass else "FAIL",
        "raw_log_path": os.path.abspath(log_path),
        "hardware_present": True,
        "command": " ".join(argv),
    }
    with open(log_path, "w") as f:
        json.dump(evidence, f, indent=2)
    print(json.dumps(evidence, indent=2))
    return 0 if all_pass else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
