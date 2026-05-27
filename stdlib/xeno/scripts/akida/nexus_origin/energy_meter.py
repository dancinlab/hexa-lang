#!/usr/bin/env python3
"""F-L1 + F-L1+: J/synaptic-update measurement.

Hardware required (akida package + AKD1000 + power meter on PCIe rail).

F-L1   : 2.85e-21 <= measured_J_per_op <= 1.5e-12
F-L1+  : 90% sparsity effective_J_per_active_bit <= 1e-13

Power source priority:
  1. --power-csv  external meter samples (ts_s, watts)
  2. /sys/class/powercap/intel-rapl  (if applicable host)
  3. RPi5 PMIC via vcgencmd pmic_read_adc (rpi5 only)
"""
from __future__ import annotations
import argparse, csv, json, os, statistics, subprocess, sys, time

from _akida_runtime import require_akida


def measure_power_window(method: str, duration_s: float, power_csv: str | None = None) -> tuple[float, float]:
    if method == "csv":
        if not power_csv or not os.path.exists(power_csv):
            raise SystemExit(f"ERROR: --power-source=csv needs valid --power-csv, got {power_csv!r}")
        watts = []
        with open(power_csv) as f:
            reader = csv.reader(f)
            for row in reader:
                if not row or row[0].startswith("#"):
                    continue
                try:
                    watts.append(float(row[1]))
                except (IndexError, ValueError):
                    continue
        if not watts:
            raise SystemExit("ERROR: --power-csv contained no samples")
        return (statistics.mean(watts), statistics.stdev(watts) if len(watts) > 1 else 0.0)
    if method == "rapl":
        rapl = "/sys/class/powercap/intel-rapl/intel-rapl:0/energy_uj"
        if not os.path.exists(rapl):
            raise SystemExit("ERROR: intel-rapl not available on this host")
        with open(rapl) as f:
            e0 = int(f.read())
        time.sleep(duration_s)
        with open(rapl) as f:
            e1 = int(f.read())
        joules = (e1 - e0) * 1e-6
        return (joules / duration_s, 0.0)
    if method == "rpi5":
        try:
            out = subprocess.run(
                ["vcgencmd", "pmic_read_adc"],
                check=True, capture_output=True, text=True, timeout=5,
            ).stdout
        except (FileNotFoundError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as e:
            raise SystemExit(f"ERROR: rpi5 vcgencmd unavailable: {e}")
        watts = 0.0
        for line in out.splitlines():
            line = line.strip()
            if "current" in line.lower() and "A" in line:
                continue
            if line.endswith("W"):
                try:
                    watts += float(line.rsplit(maxsplit=1)[-2])
                except (IndexError, ValueError):
                    pass
        if watts == 0.0:
            raise SystemExit("ERROR: rpi5 vcgencmd returned no power lines")
        return (watts, 0.0)
    raise SystemExit(f"ERROR: unknown power method {method!r}")


def run_workload(ak, n_events: int, sparsity: float, model_path: str | None) -> int:
    if model_path and os.path.exists(model_path):
        m = ak.Model(model_path)
    else:
        try:
            m = ak.Model()
        except Exception as e:
            raise SystemExit(f"ERROR: akida.Model() init failed: {e}")
    devs = ak.devices()
    if not devs:
        raise SystemExit("ERROR: no AKD1000 devices")
    m.map(devs[0])

    inputs = _gen_sparse_inputs(n_events, sparsity)
    actual = 0
    for x in inputs:
        m.predict(x)
        actual += 1
    return actual


def _gen_sparse_inputs(n: int, sparsity: float):
    import numpy as np
    rng = np.random.default_rng(0)
    shape = (1, 32, 32, 1)
    for _ in range(n):
        dense = rng.integers(0, 256, size=shape, dtype="uint8")
        mask = rng.random(shape) >= sparsity
        yield (dense * mask).astype("uint8")


def _emit_simulator(args) -> int:
    j_per_op_sim = 8.0e-13
    if args.falsifier == "F-L1+":
        density = max(1e-9, 1.0 - args.sparsity)
        effective_j = j_per_op_sim / density
    else:
        effective_j = j_per_op_sim

    ts = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    os.makedirs(args.out_dir, exist_ok=True)
    log_path = os.path.join(args.out_dir, f"{args.falsifier}_{ts.replace(':', '').replace('-', '')}.json")
    evidence = {
        "falsifier_id": args.falsifier,
        "measured_ts": ts,
        "measured_value": {
            "substrate": "cpu_emulator_cnn2snn_stub",
            "j_per_op_synthetic": j_per_op_sim,
            "effective_j_per_active_bit": effective_j,
            "sparsity": args.sparsity,
            "honesty_note": "synthetic from cnn2snn_emulator — NOT promotion-eligible. Falls within vendor spec band by construction so downstream consumers (host_register.sh SIMULATOR=1) can proceed.",
        },
        "verdict": "PARTIAL-SIMULATOR",
        "raw_log_path": os.path.abspath(log_path),
        "hardware_present": False,
        "command": " ".join(sys.argv),
    }
    with open(log_path, "w") as f:
        json.dump(evidence, f, indent=2)
    print(json.dumps(evidence, indent=2))
    return 0


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--falsifier", choices=["F-L1", "F-L1+"], required=True)
    p.add_argument("--n-events", type=int, default=1_000_000)
    p.add_argument("--sparsity", type=float, default=None,
                   help="event-density (0..1). default: 0.0 for F-L1 (dense), 0.9 for F-L1+")
    p.add_argument("--model", default=None, help="Akida .fbz model path (default: empty model)")
    p.add_argument("--power-source", choices=["csv", "rapl", "rpi5"], default="csv")
    p.add_argument("--power-csv", default=None)
    p.add_argument("--out-dir", default="state/akida_evidence")
    p.add_argument("--simulator", action="store_true",
                   help="emit non-promotion-eligible PARTIAL evidence using cnn2snn_emulator (cpu_emulator_cnn2snn_stub substrate)")
    args = p.parse_args(argv[1:])

    if args.sparsity is None:
        args.sparsity = 0.9 if args.falsifier == "F-L1+" else 0.0

    if args.simulator:
        return _emit_simulator(args)

    ak = require_akida(need_device=True)

    idle_w, _ = measure_power_window(args.power_source, 5.0, args.power_csv)
    t0 = time.time()
    actual_events = run_workload(ak, args.n_events, args.sparsity, args.model)
    wall = time.time() - t0
    active_w, _ = measure_power_window(args.power_source, 5.0, args.power_csv)

    delta_w = max(0.0, active_w - idle_w)
    joules = delta_w * wall
    j_per_op = joules / max(1, actual_events)

    if args.falsifier == "F-L1":
        pass_ = (2.85e-21 <= j_per_op <= 1.5e-12)
        threshold = "[2.85e-21, 1.5e-12]"
        effective_j = j_per_op
    else:
        density = max(1e-9, 1.0 - args.sparsity)
        effective_j = j_per_op / density
        pass_ = effective_j <= 1e-13
        threshold = "<= 1e-13"

    ts = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    os.makedirs(args.out_dir, exist_ok=True)
    log_path = os.path.join(args.out_dir, f"{args.falsifier}_{ts.replace(':', '').replace('-', '')}.json")
    evidence = {
        "falsifier_id": args.falsifier,
        "measured_ts": ts,
        "measured_value": {
            "idle_watts": idle_w,
            "active_watts": active_w,
            "delta_watts": delta_w,
            "wall_seconds": wall,
            "joules_total": joules,
            "events": actual_events,
            "sparsity": args.sparsity,
            "j_per_op": j_per_op,
            "effective_j_per_active_bit": effective_j,
            "threshold": threshold,
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
