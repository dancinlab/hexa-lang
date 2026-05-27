#!/usr/bin/env python3
"""F-M2: Solomonoff-K approximation via gzip. Compares spike-event stream
gzip ratio to /dev/urandom baseline. PASS iff spike_ratio <= random_ratio + 0.05.

Without hardware, --simulate emits a Poisson-rate spike stream as plausibility
check (NOT promotion-eligible). Real promotion needs --spike-trace from AKD1000.
"""
from __future__ import annotations
import argparse, gzip, io, json, os, random, sys, time


def gzip_ratio(buf: bytes) -> float:
    sink = io.BytesIO()
    with gzip.GzipFile(fileobj=sink, mode="wb", compresslevel=9, mtime=0) as g:
        g.write(buf)
    return len(sink.getvalue()) / max(1, len(buf))


def simulate_spikes(n_events: int, rate_hz: float = 100.0, dt_us: float = 10.0, seed: int = 0) -> bytes:
    rng = random.Random(seed)
    out = bytearray()
    t_us = 0.0
    p_spike = rate_hz * dt_us * 1e-6
    while len(out) < n_events * 8:
        t_us += dt_us
        if rng.random() < p_spike:
            ts_ns = int(t_us * 1000) & 0xFFFFFFFFFFFFFFFF
            out.extend(ts_ns.to_bytes(8, "little"))
    return bytes(out[:n_events * 8])


def load_spikes(path: str) -> bytes:
    if path.endswith(".bin"):
        with open(path, "rb") as f:
            return f.read()
    with open(path) as f:
        events = [int(x) for x in f.read().split() if x.strip()]
    return b"".join(e.to_bytes(4, "little", signed=False) for e in events)


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--simulate", action="store_true", help="generate Poisson spikes (plausibility, NOT promotion-eligible)")
    p.add_argument("--spike-trace", default=None, help="real AKD1000 trace path (.bin or whitespace-separated ints)")
    p.add_argument("--n-events", type=int, default=1_000_000)
    p.add_argument("--out-dir", default="state/akida_evidence")
    args = p.parse_args(argv[1:])

    if not args.simulate and not args.spike_trace:
        print("ERROR: provide --simulate OR --spike-trace", file=sys.stderr)
        return 2

    if args.spike_trace:
        spike = load_spikes(args.spike_trace)
        promotion_eligible = True
    else:
        spike = simulate_spikes(args.n_events)
        promotion_eligible = False

    random_buf = os.urandom(len(spike))
    spike_r = gzip_ratio(spike)
    rand_r = gzip_ratio(random_buf)
    delta = spike_r - rand_r
    pass_ = delta <= 0.05

    ts = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    os.makedirs(args.out_dir, exist_ok=True)
    log_path = os.path.join(args.out_dir, f"F-M2_{ts.replace(':', '').replace('-', '')}.json")
    if not promotion_eligible:
        verdict = "PLAUSIBLE-PASS" if pass_ else "PLAUSIBLE-FAIL"
    else:
        verdict = "PASS" if pass_ else "FAIL"

    evidence = {
        "falsifier_id": "F-M2",
        "measured_ts": ts,
        "measured_value": {
            "spike_gzip_ratio": spike_r,
            "random_gzip_ratio": rand_r,
            "delta": delta,
            "n_bytes": len(spike),
            "promotion_eligible": promotion_eligible,
        },
        "verdict": verdict,
        "raw_log_path": os.path.abspath(log_path),
        "hardware_present": promotion_eligible,
        "command": " ".join(argv),
    }
    with open(log_path, "w") as f:
        json.dump(evidence, f, indent=2)
    print(json.dumps(evidence, indent=2))
    return 0 if pass_ else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
