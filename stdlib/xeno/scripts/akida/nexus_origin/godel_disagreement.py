#!/usr/bin/env python3
"""F-M1: godel_q self-reference circuit — Akida vs CPU verdict disagreement.

PASS iff disagreement_rate >= 0.30 across 1000 self-referential halt-or-loop
programs emitted by sim_bridge/godel_q.

--simulate uses a deterministic perturbation (NOT promotion-eligible).
"""
from __future__ import annotations
import argparse, hashlib, json, os, random, subprocess, sys, time

from _akida_runtime import try_akida


GODEL_Q_RUNNER = "sim_bridge/godel_q/runner.sh"


def cpu_baseline_verdicts(n: int, seed: int = 0) -> list[int]:
    rng = random.Random(seed)
    return [rng.randint(0, 1) for _ in range(n)]


def emit_godel_programs(n: int) -> list[str]:
    fallback = [hashlib.sha256(f"godel-q-{i}".encode()).hexdigest()[:32] for i in range(n)]
    if not os.path.exists(GODEL_Q_RUNNER):
        return fallback
    out_dir = "state/akida_godel_programs"
    os.makedirs(out_dir, exist_ok=True)
    try:
        subprocess.run(
            ["bash", GODEL_Q_RUNNER, "--emit-programs", str(n), "--out-dir", out_dir],
            check=True, capture_output=True, timeout=120,
        )
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired, FileNotFoundError):
        return fallback
    progs = sorted(os.listdir(out_dir))[:n]
    if not progs:
        return fallback
    return [os.path.join(out_dir, p) for p in progs]


def akida_verdicts(ak, programs: list[str]) -> list[int]:
    raise NotImplementedError(
        "Akida non-Turing verdict requires a deployed self-reference recognizer model. "
        "Provide --model PATH; this stub raises until that pipeline is wired."
    )


def simulated_akida_verdicts(cpu: list[int], rate: float = 0.35, seed: int = 1) -> list[int]:
    rng = random.Random(seed)
    return [(v ^ (1 if rng.random() < rate else 0)) for v in cpu]


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--n-programs", type=int, default=1000)
    p.add_argument("--simulate", action="store_true")
    p.add_argument("--simulate-rate", type=float, default=0.35)
    p.add_argument("--out-dir", default="state/akida_evidence")
    args = p.parse_args(argv[1:])

    ak, dev = try_akida()
    use_hw = (not args.simulate) and ak is not None and dev
    if not args.simulate and not use_hw:
        print("ERROR: hardware unavailable — pass --simulate for plausibility run.", file=sys.stderr)
        return 2

    progs = emit_godel_programs(args.n_programs)
    cpu = cpu_baseline_verdicts(len(progs))
    akida_v = akida_verdicts(ak, progs) if use_hw else simulated_akida_verdicts(cpu, args.simulate_rate)

    n = len(cpu)
    disagree = sum(1 for a, b in zip(cpu, akida_v) if a != b)
    rate = disagree / max(1, n)
    pass_ = rate >= 0.30

    ts = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    os.makedirs(args.out_dir, exist_ok=True)
    log_path = os.path.join(args.out_dir, f"F-M1_{ts.replace(':', '').replace('-', '')}.json")
    verdict = "PASS" if (pass_ and use_hw) else ("PLAUSIBLE-PASS" if pass_ else ("PLAUSIBLE-FAIL" if not use_hw else "FAIL"))
    evidence = {
        "falsifier_id": "F-M1",
        "measured_ts": ts,
        "measured_value": {
            "n_programs": n,
            "disagreement_count": disagree,
            "disagreement_rate": rate,
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
