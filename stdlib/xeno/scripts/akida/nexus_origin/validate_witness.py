#!/usr/bin/env python3
"""F-C: witness honesty barrier — every hardware F-* PASS verdict requires
measured_ts + raw_log_path that points to an existing file. Architectural,
runs without hardware."""
from __future__ import annotations
import json, os, sys

HARDWARE_FALSIFIERS = {
    "F-L1", "F-L1+", "F-L6", "F-L7",
    "F-M1", "F-M2", "F-M3a", "F-M3b", "F-M4",
    "F-A", "F-B",
}

def validate(path: str) -> tuple[bool, list[str]]:
    with open(path) as f:
        d = json.load(f)
    violations: list[str] = []

    fals = d.get("core_5_op_kernel", {}).get("falsifiers_preregistered", [])
    for fal in fals:
        fid = fal.get("id")
        if fid not in HARDWARE_FALSIFIERS:
            continue
        if fal.get("verdict") == "PASS":
            ts = fal.get("measured_ts")
            log = fal.get("raw_log_path")
            if not ts:
                violations.append(f"{fid}: PASS without measured_ts")
            if not log or not os.path.exists(log):
                violations.append(f"{fid}: PASS with missing raw_log_path={log!r}")

    ev = d.get("core_5_op_kernel", {}).get("tier_1_gate", {}).get("evaluation_this_cycle", {})
    for fid in HARDWARE_FALSIFIERS:
        if ev.get(fid) == "PASS":
            sibling = next((x for x in fals if x.get("id") == fid), None)
            if not sibling or not sibling.get("measured_ts") or not sibling.get("raw_log_path"):
                violations.append(f"{fid}@evaluation_this_cycle: PASS without measured evidence")

    for t in d.get("tier_1_promotions_this_cycle", []):
        gate_ids = set(t.get("gated_by_falsifiers", []))
        for fid in gate_ids & HARDWARE_FALSIFIERS:
            sibling = next((x for x in fals if x.get("id") == fid), None)
            if not sibling or sibling.get("verdict") != "PASS":
                violations.append(f"tier_1 {t.get('id')}: gate {fid} not PASS")

    fan_out = d.get("core_5_op_kernel", {}).get("fan_out", {})
    corr = fan_out.get("correlation_estimate")
    if not isinstance(corr, (int, float)) or corr >= 0.7:
        violations.append(f"correlation_estimate {corr!r} not < 0.7")
    if not fan_out.get("correlation_lt_0_7"):
        violations.append("correlation_lt_0_7 flag not true")

    axes = d.get("axes_surfaced", [])
    if len(axes) < 2:
        violations.append(f"axes_surfaced count {len(axes)} < 2")
    for a in axes:
        opts = a.get("options_considered", [])
        if len(opts) < 3:
            violations.append(f"axis {a.get('id')}: options_considered len {len(opts)} < 3")
        for opt in opts:
            if not opt.get("rejection_rationale") and opt.get("label") != a.get("decision"):
                violations.append(f"axis {a.get('id')} option {opt.get('label')}: missing rejection_rationale")

    return (len(violations) == 0, violations)


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("usage: validate_witness.py <witness.json> [--out-dir DIR]", file=sys.stderr)
        return 2
    out_dir = "state/akida_evidence"
    skip_next = False
    positional: list[str] = []
    for i, a in enumerate(argv[1:]):
        if skip_next:
            skip_next = False
            continue
        if a == "--out-dir":
            if i + 2 < len(argv):
                out_dir = argv[i + 2]
                skip_next = True
            continue
        if a.startswith("--"):
            continue
        positional.append(a)
    if not positional:
        print("usage: validate_witness.py <witness.json> [--out-dir DIR]", file=sys.stderr)
        return 2
    witness = positional[0]

    import os, time
    ok, viol = validate(witness)
    ts = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    os.makedirs(out_dir, exist_ok=True)
    log_path = os.path.join(out_dir, f"F-C_{ts.replace(':', '').replace('-', '')}.json")
    result = {
        "falsifier_id": "F-C",
        "measured_ts": ts,
        "verdict": "PASS" if ok else "FAIL",
        "measured_value": {"violations": viol, "witness_path": witness},
        "raw_log_path": os.path.abspath(log_path),
        "hardware_present": False,
        "command": " ".join(argv),
    }
    with open(log_path, "w") as f:
        json.dump(result, f, indent=2)
    print(json.dumps(result, indent=2))
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
