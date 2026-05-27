#!/usr/bin/env python3
"""Synthesize a spike-event trace for downstream falsifiers when AKD1000 is
absent. Output is whitespace-separated nanosecond timestamps + 8-byte packed
binary form (Poisson process with optional jitter from urandom).

Clearly labels evidence as 'synthetic' so F-C honesty barrier can refuse PASS
on F-L7 spike-fusion etc when consuming this trace.
"""
from __future__ import annotations
import argparse, json, os, random, struct, sys, time


def synth(n_events: int, rate_hz: float, seed: int) -> list[int]:
    rng = random.Random(seed)
    ts: list[int] = []
    t_ns = 0
    p_per_ns = rate_hz * 1e-9
    while len(ts) < n_events:
        gap = max(1, int(rng.expovariate(p_per_ns)))
        t_ns += gap
        ts.append(t_ns)
    return ts


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--n-events", type=int, default=100000)
    p.add_argument("--rate-hz", type=float, default=200.0)
    p.add_argument("--seed", type=int, default=20260507)
    p.add_argument("--out-text", default="state/akida_synth/spike_trace.txt")
    p.add_argument("--out-bin", default="state/akida_synth/spike_trace.bin")
    p.add_argument("--out-meta", default="state/akida_synth/spike_trace.meta.json")
    args = p.parse_args(argv[1:])

    os.makedirs(os.path.dirname(args.out_text), exist_ok=True)
    ev = synth(args.n_events, args.rate_hz, args.seed)
    with open(args.out_text, "w") as f:
        f.write("\n".join(str(x) for x in ev))
        f.write("\n")
    with open(args.out_bin, "wb") as f:
        for x in ev:
            f.write(struct.pack("<Q", x & 0xFFFFFFFFFFFFFFFF))
    meta = {
        "kind": "synthetic_spike_trace",
        "n_events": args.n_events,
        "rate_hz": args.rate_hz,
        "seed": args.seed,
        "generator": "spike_trace_gen.py Poisson process",
        "honesty_note": "synthetic — NOT promotion-eligible substrate evidence",
        "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "out_text": os.path.abspath(args.out_text),
        "out_bin": os.path.abspath(args.out_bin),
    }
    with open(args.out_meta, "w") as f:
        json.dump(meta, f, indent=2)
    print(json.dumps(meta, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
