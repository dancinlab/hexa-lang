#!/usr/bin/env python3
"""
RFC 072 P1 — PyTorch eager d=2048 12L proxy baseline (Campaign B, north-star ①).

PROXY scope (g3 honest): This script measures a SCALED-DOWN proxy for the
RFC 072 full spec (d=4096 24L batch=8 seq=2048). RTX 5070 has 12GB VRAM —
the full spec needs ~80GB+ for FP32 forward+backward+Adam, requiring an
H100 80GB on RunPod (~$5+ multi-session). This proxy at d=2048 12L still
informs the PyTorch wall trajectory at a smaller scale; F-RFC072-RATIO
closure requires the full-spec H100 measurement (separate cycle).

Configuration ladder (try in order, take first that fits):
  L1: d=2048 n_layer=12 batch=4 seq=1024 (task-spec proxy; ~32x smaller)
  L2: d=2048 n_layer=12 batch=2 seq=512  (half memory)
  L3: d=2048 n_layer=12 batch=1 seq=512  (further reduction)
  L4: d=1024 n_layer=12 batch=2 seq=512  (d-axis fallback)
  L5: d=1024 n_layer=6  batch=2 seq=512  (n_layer fallback)

Measurement protocol (per RFC 072 §3):
  - 3 warmup steps (discarded)
  - 5 timed steps via torch.cuda.Event + cuda.synchronize()
  - Report median + std of 5 timings; also raw 5 values
  - Adam optimizer (LLM-canonical); fwd + bwd + step
  - FP32, eager mode, no flash-attn, no torch.compile

Writes: result.json with all timings + host fingerprint + g3 caveats.
"""

import argparse
import json
import math
import os
import socket
import statistics
import subprocess
import sys
import time

import torch
import torch.nn as nn
import torch.nn.functional as F


CONFIG_LADDER = [
    {"label": "L1_task_spec", "d": 2048, "n_layer": 12, "batch": 4, "seq": 1024},
    {"label": "L2_half_mem",  "d": 2048, "n_layer": 12, "batch": 2, "seq": 512},
    {"label": "L3_micro",     "d": 2048, "n_layer": 12, "batch": 1, "seq": 512},
    {"label": "L4_d1024",     "d": 1024, "n_layer": 12, "batch": 2, "seq": 512},
    {"label": "L5_d1024_6L",  "d": 1024, "n_layer": 6,  "batch": 2, "seq": 512},
]

WARMUP_STEPS = 3
TIMED_STEPS = 5


class TransformerBlock(nn.Module):
    """Standard pre-LN transformer block — d_model wide, 4x FFN, MHA."""
    def __init__(self, d_model: int, n_head: int = 16):
        super().__init__()
        self.ln1 = nn.LayerNorm(d_model)
        self.attn = nn.MultiheadAttention(d_model, n_head, batch_first=True)
        self.ln2 = nn.LayerNorm(d_model)
        self.ffn = nn.Sequential(
            nn.Linear(d_model, 4 * d_model),
            nn.GELU(),
            nn.Linear(4 * d_model, d_model),
        )

    def forward(self, x):
        h = self.ln1(x)
        a, _ = self.attn(h, h, h, need_weights=False)
        x = x + a
        x = x + self.ffn(self.ln2(x))
        return x


class TinyTransformer(nn.Module):
    def __init__(self, d_model: int, n_layer: int, vocab: int = 50257):
        super().__init__()
        self.embed = nn.Embedding(vocab, d_model)
        self.blocks = nn.ModuleList([TransformerBlock(d_model) for _ in range(n_layer)])
        self.ln_f = nn.LayerNorm(d_model)
        self.head = nn.Linear(d_model, vocab, bias=False)

    def forward(self, ids):
        x = self.embed(ids)
        for b in self.blocks:
            x = b(x)
        x = self.ln_f(x)
        return self.head(x)


def try_config(cfg, device):
    """Try one config. Return (success, timings_ms, mem_peak_mib, err)."""
    d, n_layer, batch, seq = cfg["d"], cfg["n_layer"], cfg["batch"], cfg["seq"]
    print(f"[try] {cfg['label']}: d={d} n_layer={n_layer} batch={batch} seq={seq}",
          flush=True)
    try:
        torch.cuda.empty_cache()
        torch.cuda.reset_peak_memory_stats()
        model = TinyTransformer(d, n_layer).to(device, dtype=torch.float32)
        opt = torch.optim.Adam(model.parameters(), lr=1e-4)
        vocab = 50257
        # Fixed input ids (no dataloader; we measure wall not data pipeline).
        ids = torch.randint(0, vocab, (batch, seq), device=device, dtype=torch.long)
        tgt = torch.randint(0, vocab, (batch, seq), device=device, dtype=torch.long)

        # Warmup
        for _ in range(WARMUP_STEPS):
            opt.zero_grad(set_to_none=True)
            logits = model(ids)
            loss = F.cross_entropy(logits.view(-1, vocab), tgt.view(-1))
            loss.backward()
            opt.step()
        torch.cuda.synchronize()

        # Timed
        timings_ms = []
        starts = [torch.cuda.Event(enable_timing=True) for _ in range(TIMED_STEPS)]
        ends = [torch.cuda.Event(enable_timing=True) for _ in range(TIMED_STEPS)]
        for i in range(TIMED_STEPS):
            opt.zero_grad(set_to_none=True)
            starts[i].record()
            logits = model(ids)
            loss = F.cross_entropy(logits.view(-1, vocab), tgt.view(-1))
            loss.backward()
            opt.step()
            ends[i].record()
        torch.cuda.synchronize()
        for i in range(TIMED_STEPS):
            timings_ms.append(starts[i].elapsed_time(ends[i]))

        mem_peak_mib = torch.cuda.max_memory_allocated() / (1024 * 1024)
        print(f"[ok]  {cfg['label']}: timings_ms={timings_ms} peak={mem_peak_mib:.1f}MiB",
              flush=True)
        # Clear model
        del model, opt, ids, tgt
        torch.cuda.empty_cache()
        return True, timings_ms, mem_peak_mib, None
    except torch.cuda.OutOfMemoryError as e:
        torch.cuda.empty_cache()
        msg = str(e).splitlines()[0] if str(e) else "OOM"
        print(f"[oom] {cfg['label']}: {msg}", flush=True)
        return False, [], 0, f"OOM: {msg}"
    except Exception as e:
        torch.cuda.empty_cache()
        print(f"[err] {cfg['label']}: {type(e).__name__}: {e}", flush=True)
        return False, [], 0, f"{type(e).__name__}: {e}"


def main():
    if not torch.cuda.is_available():
        print("[fatal] CUDA not available", flush=True)
        sys.exit(2)

    device = torch.device("cuda:0")
    gpu_name = torch.cuda.get_device_name(0)
    torch_ver = torch.__version__
    cuda_ver = torch.version.cuda
    host = socket.gethostname()
    sm = torch.cuda.get_device_capability(0)
    sm_str = f"sm_{sm[0]}{sm[1]}"

    print(f"[host] hostname={host} gpu={gpu_name} {sm_str} torch={torch_ver} cuda={cuda_ver}",
          flush=True)

    # Honest seed — disable cudnn benchmarking for steady-state timing.
    torch.backends.cudnn.benchmark = False
    torch.manual_seed(42)

    chosen = None
    chosen_timings = []
    chosen_peak = 0
    attempts = []

    for cfg in CONFIG_LADDER:
        ok, timings, peak, err = try_config(cfg, device)
        attempts.append({
            "label": cfg["label"],
            "config": cfg,
            "ok": ok,
            "err": err,
        })
        if ok:
            chosen = cfg
            chosen_timings = timings
            chosen_peak = peak
            break

    result = {
        "rfc": "RFC-072-P1",
        "phase": "P1",
        "scope": "PROXY (NOT d=4096 24L full spec — that needs H100 80GB)",
        "honest_caveat": (
            "This is a SCALED-DOWN PROXY measurement on RTX 5070 12GB. "
            "Full RFC 072 §2 spec (d=4096 n_layer=24 batch=8 seq=2048 FP32) "
            "requires ~80GB+ VRAM (H100 80GB · multi-session $5+ budget). "
            "F-RFC072-WALL-PT-PROXY = MEASURED at the chosen ladder rung. "
            "F-RFC072-WALL-PT-FULL = DEFERRED until H100 fire cycle. "
            "F-RFC072-RATIO closure stays [ ] in GPU.md §10."
        ),
        "host": {
            "hostname": host,
            "gpu": gpu_name,
            "sm": sm_str,
            "torch_version": torch_ver,
            "cuda_version": cuda_ver,
        },
        "protocol": {
            "warmup_steps": WARMUP_STEPS,
            "timed_steps": TIMED_STEPS,
            "precision": "fp32",
            "mode": "eager",
            "optimizer": "Adam",
            "cudnn_benchmark": False,
        },
        "attempts": attempts,
    }

    if chosen is None:
        result["verdict"] = "FAIL_ALL_LADDER_OOM"
        result["g3_summary"] = (
            "All ladder rungs OOM on RTX 5070 12GB. F-RFC072-WALL-PT-PROXY "
            "DEFERRED. Cycle escalation needed (vast.ai T4 16GB or H100)."
        )
        print(json.dumps(result, indent=2))
        sys.exit(3)

    median = statistics.median(chosen_timings)
    std = statistics.stdev(chosen_timings) if len(chosen_timings) > 1 else 0.0
    std_pct = (std / median * 100) if median > 0 else 0.0

    result["chosen_config"] = chosen
    result["wall_ms"] = {
        "samples": chosen_timings,
        "median": median,
        "mean": statistics.mean(chosen_timings),
        "std": std,
        "std_pct_of_median": std_pct,
        "min": min(chosen_timings),
        "max": max(chosen_timings),
    }
    result["mem_peak_mib"] = chosen_peak
    result["verdict"] = "PASS_PROXY"
    result["variance_gate_5pct"] = "PASS" if std_pct < 5.0 else "FAIL"
    result["g3_summary"] = (
        f"PyTorch eager wall measured at PROXY config {chosen['label']} "
        f"(d={chosen['d']} n_layer={chosen['n_layer']} batch={chosen['batch']} "
        f"seq={chosen['seq']}): median 1-step wall = {median:.2f}ms over "
        f"{TIMED_STEPS} timed steps (std {std:.3f}ms = {std_pct:.2f}% of median). "
        f"Peak VRAM = {chosen_peak:.1f}MiB on RTX 5070 12GB. "
        f"This is NOT the d=4096 24L full-spec datum — that's deferred to "
        f"H100 multi-session campaign. Provides honest baseline at smaller "
        f"scale for north-star ① trajectory."
    )

    out_path = os.environ.get("R072_P1_RESULT", "result.json")
    with open(out_path, "w") as f:
        json.dump(result, f, indent=2)
    print(f"\n[done] wrote {out_path}", flush=True)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
