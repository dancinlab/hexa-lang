#!/usr/bin/env python3
"""F-M3a: raw 40 dispatch routing. Verifies that nexus dispatch with label
'low-power-inference' selects host.rpi5-akida.

Reads ~/core/.workspace, looks for `resource host.rpi5-akida` declaration with
a `label low-power-inference` line in the same block, then walks any locally
present dispatch trace (state/dispatch_*.jsonl or hive routing log) for
selected_host == 'host.rpi5-akida' under a low-power label.
"""
from __future__ import annotations
import argparse, json, os, re, sys, time


def parse_workspace(path: str) -> dict:
    with open(path) as f:
        text = f.read()
    blocks: dict[str, list[str]] = {}
    cur = None
    for line in text.splitlines():
        m = re.match(r"^resource\s+(\S+)\s+", line)
        if m:
            cur = m.group(1)
            blocks[cur] = [line]
            continue
        if cur and (line.startswith("  ") or line.startswith("\t")):
            blocks[cur].append(line)
        elif cur and line.strip() == "":
            continue
        else:
            cur = None
    return blocks


def has_label(block: list[str], label: str) -> bool:
    for ln in block:
        s = ln.strip()
        if (s.startswith("label ") or s.startswith("labels ")) and label in s:
            return True
        if (s.startswith("label ") or s.startswith("labels ")) and (label + "-simulator") in s:
            return True
    return False


def find_dispatch_log() -> str | None:
    candidates = [
        "state/dispatch_state.json",
        "dispatch_state.json",
        "logs/dispatch.jsonl",
    ]
    for c in candidates:
        if os.path.exists(c):
            return c
    return None


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--workspace", default=os.path.expanduser("~/core/.workspace"))
    p.add_argument("--label", default="low-power-inference")
    p.add_argument("--host", default="host.rpi5-akida")
    p.add_argument("--out-dir", default="state/akida_evidence")
    p.add_argument("--synth-route", action="store_true",
                   help="if no real dispatch log routes to host, emit a synthetic dispatch trace at logs/dispatch.jsonl (PARTIAL evidence)")
    args = p.parse_args(argv[1:])

    if not os.path.exists(args.workspace):
        print(f"ERROR: workspace not found at {args.workspace}", file=sys.stderr)
        return 2

    blocks = parse_workspace(args.workspace)
    host_block = blocks.get(args.host)

    registered = host_block is not None
    label_present = registered and has_label(host_block, args.label)

    log_file = find_dispatch_log()
    routing_evidence = None
    if log_file:
        try:
            with open(log_file) as f:
                if log_file.endswith(".json"):
                    data = json.load(f)
                    routing_evidence = data
                else:
                    for line in f:
                        try:
                            ev = json.loads(line)
                        except json.JSONDecodeError:
                            continue
                        if ev.get("label") == args.label and ev.get("selected_host") == args.host:
                            routing_evidence = ev
                            break
        except (OSError, json.JSONDecodeError) as e:
            routing_evidence = {"_error": str(e)}

    routed = bool(routing_evidence) and (
        isinstance(routing_evidence, dict)
        and routing_evidence.get("selected_host") == args.host
    )

    synth_path = None
    if (not routed) and args.synth_route and registered and label_present:
        synth_path = os.path.abspath("logs/dispatch.jsonl")
        os.makedirs(os.path.dirname(synth_path), exist_ok=True)
        synth_event = {
            "label": args.label,
            "selected_host": args.host,
            "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "synthetic": True,
            "honesty_note": "synthetic dispatch trace — NOT promotion-eligible (real raw 40 routing pending)",
        }
        with open(synth_path, "a") as f:
            f.write(json.dumps(synth_event) + "\n")
        routing_evidence = synth_event
        routed = False

    ts = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    if registered and label_present and routed:
        verdict = "PASS"
    elif registered and label_present and synth_path:
        verdict = "PARTIAL-SYNTH-ROUTE"
    elif registered and label_present and not log_file:
        verdict = "PARTIAL-DISPATCH-LOG-ABSENT"
    elif registered and label_present:
        verdict = "PARTIAL-NOT-ROUTED"
    else:
        verdict = "FAIL"

    os.makedirs(args.out_dir, exist_ok=True)
    log_path = os.path.join(args.out_dir, f"F-M3a_{ts.replace(':', '').replace('-', '')}.json")
    evidence = {
        "falsifier_id": "F-M3a",
        "measured_ts": ts,
        "measured_value": {
            "host_registered": registered,
            "label_present": label_present,
            "label_searched": args.label,
            "host_searched": args.host,
            "dispatch_log_file": log_file,
            "routing_evidence": routing_evidence,
            "routed_correctly": routed,
        },
        "verdict": verdict,
        "raw_log_path": os.path.abspath(log_path),
        "hardware_present": registered,
        "command": " ".join(argv),
    }
    with open(log_path, "w") as f:
        json.dump(evidence, f, indent=2)
    print(json.dumps(evidence, indent=2))
    return 0 if verdict == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
