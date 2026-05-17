#!/usr/bin/env python3
"""nexus-side falsifier orchestrator. Runs eligible falsifiers (or all if
--hardware), emits a follow-up witness JSON keyed off the 2026-05-07 cycle.

Usage:
  python3 scripts/akida/runner.py --no-hardware    # F-C/L7/M2/M3a only
  python3 scripts/akida/runner.py --hardware       # all 11 + F-C
  python3 scripts/akida/runner.py --witness PATH   # validate + emit follow-up
"""
from __future__ import annotations
import argparse, json, os, subprocess, sys, time

NEXUS_FALSIFIERS_NO_HARDWARE = ["F-C", "F-L7", "F-M2", "F-M3a"]
NEXUS_FALSIFIERS_SIMULATOR = ["F-L1", "F-L1+", "F-L6", "F-M1"]
NEXUS_FALSIFIERS_HARDWARE_ONLY = ["F-A", "F-B"]
ANIMA_FALSIFIERS = ["F-M3b", "F-M4"]

HARNESS = {
    "F-C":   ["python3", "scripts/akida/validate_witness.py"],
    "F-L7":  ["python3", "scripts/akida/qrng_entropy.py", "--bits", "200000", "--spike-trace", "state/akida_synth/spike_trace.txt"],
    "F-M2":  ["python3", "scripts/akida/spike_compress.py", "--simulate"],
    "F-M3a": ["python3", "scripts/akida/dispatch_check.py", "--synth-route"],
    "F-L1":  ["python3", "scripts/akida/energy_meter.py", "--falsifier", "F-L1", "--simulator"],
    "F-L1+": ["python3", "scripts/akida/energy_meter.py", "--falsifier", "F-L1+", "--simulator"],
    "F-L6":  ["python3", "scripts/akida/lyapunov_sweep.py", "--simulate"],
    "F-M1":  ["python3", "scripts/akida/godel_disagreement.py", "--simulate", "--n-programs", "1000"],
    "F-A":   ["python3", "scripts/akida/blowup_phase7.py"],
    "F-B":   ["python3", "scripts/akida/check_loops.py"],
}


def _collect_latest(fid: str) -> dict:
    candidate_dirs = ["state/akida_evidence"]
    if fid in ("F-M3b", "F-M4"):
        candidate_dirs.insert(0, os.path.expanduser("~/core/anima/state/akida_evidence"))
    for ev_dir in candidate_dirs:
        if not os.path.isdir(ev_dir):
            continue
        matches = sorted(f for f in os.listdir(ev_dir) if f.startswith(fid + "_"))
        if not matches:
            continue
        p = os.path.join(ev_dir, matches[-1])
        try:
            with open(p) as f:
                ev = json.load(f)
        except (OSError, json.JSONDecodeError) as e:
            continue
        return {"falsifier_id": fid, "command": f"(collect-only: {p})", "returncode": 0, "wall_seconds": 0, "evidence": ev, "stderr_tail": ""}
    return {"falsifier_id": fid, "command": "(collect-only)", "returncode": None, "wall_seconds": 0, "evidence": None, "stderr_tail": "no evidence in any candidate dir"}


def run_one(fid: str, witness_path: str) -> dict:
    cmd = list(HARNESS[fid])
    if fid == "F-C":
        cmd.append(witness_path)
    t0 = time.time()
    proc = subprocess.run(cmd, capture_output=True, text=True)
    wall = time.time() - t0
    last_evidence = None
    try:
        last_evidence = json.loads(proc.stdout.splitlines()[-1])
    except (json.JSONDecodeError, IndexError):
        try:
            last_evidence = json.loads(proc.stdout)
        except json.JSONDecodeError:
            last_evidence = None
    return {
        "falsifier_id": fid,
        "command": " ".join(cmd),
        "returncode": proc.returncode,
        "wall_seconds": wall,
        "evidence": last_evidence,
        "stderr_tail": proc.stderr[-1000:] if proc.stderr else "",
    }


def emit_follow_up(witness_path: str, results: list[dict], out_path: str) -> None:
    with open(witness_path) as f:
        prior = json.load(f)
    fid_to_evidence = {r["falsifier_id"]: r["evidence"] for r in results if r["evidence"]}

    follow = {
        "topic": prior["topic"] + "-follow-up-measurement",
        "supersedes_witness": witness_path,
        "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "measurement_run_results": results,
        "falsifier_evidence_summary": {
            fid: {"verdict": ev.get("verdict"), "raw_log_path": ev.get("raw_log_path"), "measured_ts": ev.get("measured_ts")}
            for fid, ev in fid_to_evidence.items()
        },
        "tier_1_promotions_unblocked": [],
        "tier_1_promotions_still_blocked": [],
    }

    for pending in prior.get("tier_1_promotions_pending_post_measurement", []):
        gates = pending.get("gated_by_falsifiers", [])
        all_pass = True
        missing = []
        for g in gates:
            ev = fid_to_evidence.get(g)
            if not ev or ev.get("verdict") != "PASS":
                all_pass = False
                missing.append({"falsifier": g, "verdict": ev.get("verdict") if ev else "NOT-RUN"})
        bucket = "tier_1_promotions_unblocked" if all_pass else "tier_1_promotions_still_blocked"
        entry = dict(pending)
        if not all_pass:
            entry["blocked_by"] = missing
        follow[bucket].append(entry)

    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
    with open(out_path, "w") as f:
        json.dump(follow, f, indent=2)


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--witness", default="design/kick/2026-05-07_anima-nexus-akida-physical-math-limit-saturation_omega_cycle.json")
    p.add_argument("--hardware", action="store_true")
    p.add_argument("--simulator", action="store_true",
                   help="also include the 4 simulator-mode falsifiers (F-L1, F-L1+, F-L6, F-M1)")
    p.add_argument("--include-anima-stub", action="store_true",
                   help="emit anima_repo_falsifier_stubs entries pointing at anima/scripts/akida/")
    p.add_argument("--collect-only", action="store_true",
                   help="do not re-run harnesses; collect latest evidence file per F-id from state/akida_evidence/")
    p.add_argument("--out", default=None, help="follow-up witness path (default: alongside source witness with -followup suffix)")
    args = p.parse_args(argv[1:])

    ids = list(NEXUS_FALSIFIERS_NO_HARDWARE)
    if args.simulator:
        ids += NEXUS_FALSIFIERS_SIMULATOR
    if args.hardware:
        ids += NEXUS_FALSIFIERS_SIMULATOR + NEXUS_FALSIFIERS_HARDWARE_ONLY

    if args.collect_only:
        results = [_collect_latest(fid) for fid in ids]
    else:
        results = [run_one(fid, args.witness) for fid in ids]

    if args.include_anima_stub:
        for af in ANIMA_FALSIFIERS:
            if args.collect_only:
                results.append(_collect_latest(af))
            else:
                results.append({
                    "falsifier_id": af,
                    "command": f"(remote) python3 ~/core/anima/scripts/akida/runner.py --only {af}",
                    "returncode": None,
                    "wall_seconds": 0,
                    "evidence": None,
                    "stderr_tail": "ANIMA-OWNED — invoke anima runner separately",
                })

    out = args.out or args.witness.replace(".json", "_followup.json")
    emit_follow_up(args.witness, results, out)
    summary = {
        "follow_up_witness": out,
        "ran": [r["falsifier_id"] for r in results],
        "verdicts": {
            r["falsifier_id"]: (r["evidence"].get("verdict") if r["evidence"] else "NO-EVIDENCE")
            for r in results
        },
    }
    print(json.dumps(summary, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
