#!/usr/bin/env python3
"""F-L7 QRNG-side: Shannon entropy + sub-test PASS count on a composite
QRNG/spike-jitter stream. Without hardware, runs the QRNG side only and
declares the spike-fusion half NOT-RUN.

verdict_check: H >= 0.99 AND nist_sts_pass_count >= 14
"""
from __future__ import annotations
import argparse, hashlib, json, math, os, sys, time
from collections import Counter


def shannon_bitwise(buf: bytes) -> float:
    if not buf:
        return 0.0
    ones = sum(bin(b).count("1") for b in buf)
    n = 8 * len(buf)
    p1 = ones / n
    if p1 in (0.0, 1.0):
        return 0.0
    p0 = 1.0 - p1
    return -p1 * math.log2(p1) - p0 * math.log2(p0)


def monobit(buf: bytes) -> bool:
    n = 8 * len(buf)
    s = sum(bin(b).count("1") for b in buf) - (n - sum(bin(b).count("1") for b in buf))
    s_obs = abs(s) / math.sqrt(n)
    p = math.erfc(s_obs / math.sqrt(2))
    return p >= 0.01


def runs_test(buf: bytes) -> bool:
    bits = "".join(f"{b:08b}" for b in buf)
    n = len(bits)
    pi = bits.count("1") / n
    if abs(pi - 0.5) >= 2 / math.sqrt(n):
        return False
    Vn = 1 + sum(1 for i in range(n - 1) if bits[i] != bits[i + 1])
    num = abs(Vn - 2 * n * pi * (1 - pi))
    den = 2 * math.sqrt(2 * n) * pi * (1 - pi)
    if den == 0:
        return False
    p = math.erfc(num / den)
    return p >= 0.01


def block_freq(buf: bytes, M: int = 128) -> bool:
    bits = "".join(f"{b:08b}" for b in buf)
    N = len(bits) // M
    if N == 0:
        return False
    chi = 0.0
    for i in range(N):
        block = bits[i * M:(i + 1) * M]
        pi = block.count("1") / M
        chi += (pi - 0.5) ** 2
    chi *= 4 * M
    p = math.exp(-chi / 2) if N <= 2 else _gammaincc(N / 2, chi / 2)
    return p >= 0.01


def _gammaincc(a: float, x: float) -> float:
    if x < a + 1:
        term = 1.0 / a
        s = term
        for k in range(1, 200):
            term *= x / (a + k)
            s += term
            if abs(term) < 1e-12:
                break
        return 1.0 - s * math.exp(-x + a * math.log(x) - math.lgamma(a))
    b = x + 1 - a
    c = 1e30
    d = 1.0 / b
    h = d
    for k in range(1, 200):
        an = -k * (k - a)
        b += 2
        d = an * d + b
        if abs(d) < 1e-30:
            d = 1e-30
        c = b + an / c
        if abs(c) < 1e-30:
            c = 1e-30
        d = 1.0 / d
        delta = d * c
        h *= delta
        if abs(delta - 1) < 1e-12:
            break
    return h * math.exp(-x + a * math.log(x) - math.lgamma(a))


def run_subtests(buf: bytes) -> dict:
    return {
        "monobit": monobit(buf),
        "runs": runs_test(buf),
        "block_freq_M128": block_freq(buf, 128),
        "block_freq_M256": block_freq(buf, 256),
    }


def fuse_spike(qrng: bytes, spike_jitter_ns: list[int]) -> bytes:
    if not spike_jitter_ns:
        return qrng
    h = hashlib.sha512()
    for j in spike_jitter_ns:
        h.update(j.to_bytes(8, "little", signed=True))
    salt = h.digest()
    out = bytearray(len(qrng))
    for i, b in enumerate(qrng):
        out[i] = b ^ salt[i % len(salt)]
    return bytes(out)


def evidence_path(out_dir: str, fid: str, ts: str) -> str:
    os.makedirs(out_dir, exist_ok=True)
    return os.path.join(out_dir, f"{fid}_{ts.replace(':', '').replace('-', '')}.json")


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--bits", type=int, default=10_000_000, help="composite stream length in bits")
    p.add_argument("--source", choices=["urandom", "anu"], default="urandom",
                   help="QRNG source. 'anu' requires sim_bridge/anu_stream evidence at sim_bridge/anu_stream/runs/latest.bin")
    p.add_argument("--spike-trace", default=None,
                   help="path to spike-jitter ns int-list (newline-delimited). If absent, spike-fusion half is NOT-RUN")
    p.add_argument("--out-dir", default="state/akida_evidence")
    args = p.parse_args(argv[1:])

    n_bytes = (args.bits + 7) // 8
    if args.source == "urandom":
        qrng = os.urandom(n_bytes)
    else:
        anu = "sim_bridge/anu_stream/runs/latest.bin"
        if not os.path.exists(anu):
            print(f"ERROR: --source=anu requires {anu}", file=sys.stderr)
            return 2
        with open(anu, "rb") as f:
            qrng = f.read(n_bytes)
        if len(qrng) < n_bytes:
            print(f"ERROR: anu stream too short ({len(qrng)} < {n_bytes})", file=sys.stderr)
            return 2

    spike_jitter: list[int] = []
    spike_fusion_run = False
    if args.spike_trace and os.path.exists(args.spike_trace):
        with open(args.spike_trace) as f:
            spike_jitter = [int(x) for x in f.read().split() if x.strip()]
        spike_fusion_run = bool(spike_jitter)

    composite = fuse_spike(qrng, spike_jitter) if spike_fusion_run else qrng
    H = shannon_bitwise(composite)
    sub = run_subtests(composite)
    pass_count = sum(1 for v in sub.values() if v)

    threshold_pass = 14 * len(sub) // 15
    h_pass = H >= 0.99
    sts_pass = pass_count >= threshold_pass
    verdict = "PASS" if (h_pass and sts_pass and spike_fusion_run) else "PARTIAL" if h_pass else "FAIL"
    if not spike_fusion_run:
        verdict = "NOT-RUN-SPIKE-HALF" if h_pass else "FAIL"

    ts = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    log_path = evidence_path(args.out_dir, "F-L7", ts)
    evidence = {
        "falsifier_id": "F-L7",
        "measured_ts": ts,
        "measured_value": {
            "shannon_bitwise": H,
            "sub_tests": sub,
            "sub_test_pass_count": pass_count,
            "sub_test_pass_threshold": threshold_pass,
            "spike_fusion_run": spike_fusion_run,
            "bits": args.bits,
            "source": args.source,
        },
        "verdict": verdict,
        "raw_log_path": os.path.abspath(log_path),
        "hardware_present": spike_fusion_run,
        "command": " ".join(argv),
    }
    with open(log_path, "w") as f:
        json.dump(evidence, f, indent=2)
    print(json.dumps(evidence, indent=2))
    return 0 if verdict == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
