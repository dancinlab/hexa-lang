#!/usr/bin/env python3
"""F-L6: edge-of-chaos Lyapunov sweep.

Runs identical recurrent SNN config at varying input rates, perturbs trajectory
once at t=0, measures divergence over T steps, fits log-divergence slope =
Lyapunov exponent estimate. PASS iff some rate r* in sweep yields
|lambda_max(r*)| <= 0.05.

--simulate: run on CPU SNN emulator (plausibility, NOT promotion-eligible)
default : require AKD1000 (promotion-eligible)
"""
from __future__ import annotations
import argparse, json, math, os, sys, time

import numpy as np

from _akida_runtime import try_akida


def cpu_snn_step(state: np.ndarray, w: np.ndarray, inp: np.ndarray, threshold: float = 1.0) -> np.ndarray:
    v = state * 0.9 + w @ state + inp
    v = np.clip(v, -1e6, 1e6)
    spikes = (v > threshold - 1e-9).astype(np.float32)
    out = v * (1 - spikes)
    return np.nan_to_num(out, nan=0.0, posinf=1e6, neginf=-1e6)


def trajectory_cpu(rate_hz: float, T: int, perturb_at: int, n: int = 64, seed: int = 0):
    rng = np.random.default_rng(seed)
    w = rng.normal(0, 0.05, size=(n, n)).astype(np.float32)
    np.fill_diagonal(w, 0)
    state_a = rng.normal(0, 0.01, size=n).astype(np.float32)
    state_b = state_a.copy()
    p_spike = min(0.5, rate_hz * 1e-3)
    diffs: list[float] = []
    for t in range(T):
        inp = (rng.random(n) < p_spike).astype(np.float32) * 0.1
        state_a = cpu_snn_step(state_a, w, inp)
        if t == perturb_at:
            state_b = state_a + rng.normal(0, 1e-3, size=n).astype(np.float32)
        elif t > perturb_at:
            state_b = cpu_snn_step(state_b, w, inp)
        if t > perturb_at:
            diff = state_a - state_b
            d = float(np.sqrt(np.sum(diff * diff)))
            if d > 0 and not math.isnan(d) and not math.isinf(d):
                diffs.append(math.log(d))
    return diffs


def lyapunov_estimate(log_diffs: list[float]) -> float:
    if len(log_diffs) < 10:
        return float("nan")
    x = np.arange(len(log_diffs), dtype=np.float64)
    y = np.array(log_diffs, dtype=np.float64)
    n = len(x)
    slope = (n * (x * y).sum() - x.sum() * y.sum()) / (n * (x**2).sum() - x.sum() ** 2)
    return float(slope)


def trajectory_akida(ak, rate_hz: float, T: int, perturb_at: int):
    raise NotImplementedError(
        "Akida trajectory measurement requires a deployed recurrent SNN model + "
        "spike-event capture. Provide --model PATH and capture API stub here."
    )


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--rates", default="1,3,10,30,100,300,1000",
                   help="comma-separated input rates Hz")
    p.add_argument("--steps", type=int, default=2000)
    p.add_argument("--perturb-at", type=int, default=200)
    p.add_argument("--simulate", action="store_true",
                   help="CPU emulator only (plausibility, NOT promotion-eligible)")
    p.add_argument("--out-dir", default="state/akida_evidence")
    args = p.parse_args(argv[1:])

    rates = [float(x) for x in args.rates.split(",")]
    ak, dev = try_akida()
    use_hw = (not args.simulate) and ak is not None and dev

    if not args.simulate and not use_hw:
        print(
            "ERROR: hardware not available — pass --simulate for plausibility (non-promotion) run.",
            file=sys.stderr,
        )
        return 2

    sweep: list[dict] = []
    for r in rates:
        if use_hw:
            log_diffs = trajectory_akida(ak, r, args.steps, args.perturb_at)
        else:
            log_diffs = trajectory_cpu(r, args.steps, args.perturb_at)
        lam = lyapunov_estimate(log_diffs)
        sweep.append({"rate_hz": r, "lambda_max": lam, "n_samples": len(log_diffs)})

    in_band = [s for s in sweep if not math.isnan(s["lambda_max"]) and abs(s["lambda_max"]) <= 0.05]
    pass_ = len(in_band) >= 1

    ts = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    os.makedirs(args.out_dir, exist_ok=True)
    log_path = os.path.join(args.out_dir, f"F-L6_{ts.replace(':', '').replace('-', '')}.json")
    verdict = "PASS" if (pass_ and use_hw) else ("PLAUSIBLE-PASS" if pass_ else ("PLAUSIBLE-FAIL" if not use_hw else "FAIL"))
    evidence = {
        "falsifier_id": "F-L6",
        "measured_ts": ts,
        "measured_value": {
            "sweep": sweep,
            "rates_in_edge_of_chaos_band": in_band,
            "band": "[-0.05, +0.05]",
            "promotion_eligible": use_hw,
        },
        "verdict": verdict,
        "raw_log_path": os.path.abspath(log_path),
        "hardware_present": use_hw,
        "command": " ".join(argv),
    }
    with open(log_path, "w") as f:
        json.dump(evidence, f, indent=2)
    print(json.dumps(evidence, indent=2))
    return 0 if pass_ else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
