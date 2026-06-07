#!/usr/bin/env python3
# clmconvmoe_torch.py — PyTorch reference of the flame CLMConvMoE training step,
# for the HEXA-FUSION vs-PyTorch+CUDA wall bench (F-FUSION-VS-PYTORCH).
#
# This mirrors the flame `clm_prod` CLMConvMoE step shape as faithfully as a
# self-contained torch model can:
#   - token embedding (V=256 byte vocab, D model dim)
#   - causal Conv1d front end (kernel K)
#   - GroupNorm + GELU
#   - E experts, each a Conv1d (the ConvMoE block), router-weighted combine
#     (per-position MoE, no attention)
#   - GroupNorm + GELU + residual
#   - readout Conv1d -> V logits, all-position cross-entropy, AdamW step
#
# It is NOT byte-eq to flame (different libs); the bench's job is the END-TO-END
# WALL — step/s + GPU util of the SAME model shape (D, T, E, K, V) under three
# runners (flame / torch eager / torch.compile). Dtype is reported honestly.
#
# Usage:
#   python3 clmconvmoe_torch.py --d 1536 --t 512 --e 2 --k 3 --steps 40 \
#       --batch 1 --dtype fp32 --mode eager|compile
#
# Emits one verbatim line:
#   [TORCH-<mode>] dtype=.. D=.. T=.. E=.. K=.. B=.. steps=N warmup=W \
#       elapsed=S.s step/s=R.r ms/step=M.m   CE_first=.. CE_last=..
import argparse, time
import torch
import torch.nn as nn
import torch.nn.functional as F


class CLMConvMoE(nn.Module):
    def __init__(self, d, e, k, v=256):
        super().__init__()
        self.d, self.e, self.k, self.v = d, e, k, v
        self.pad = k - 1  # causal
        self.embed = nn.Embedding(v, d)
        self.tc = nn.Conv1d(d, d, k)          # token-conv front end
        self.gn0 = nn.GroupNorm(1, d)
        # E expert convs (the ConvMoE block) — per-position, router-combined
        self.experts = nn.ModuleList([nn.Conv1d(d, d, k) for _ in range(e)])
        self.router = nn.Conv1d(d, e, 1)      # 1x1 routing conv -> E logits
        self.gn1 = nn.GroupNorm(1, d)
        self.readout = nn.Conv1d(d, v, k)     # -> V logits

    def _causal(self, conv, x):
        return conv(F.pad(x, (self.pad, 0)))

    def forward(self, ids):
        # ids: (B, T) long
        x = self.embed(ids).transpose(1, 2)   # (B, D, T)
        x = self._causal(self.tc, x)
        x = F.gelu(self.gn0(x))
        # ConvMoE: soft mean over experts (per-position MoE, no top-k gather —
        # matches flame's per-position router-weighted combine of E expert convs)
        rg = torch.softmax(self.router(x), dim=1)   # (B, E, T)
        ex = torch.stack([self._causal(self.experts[i], x) for i in range(self.e)], 1)  # (B,E,D,T)
        x = x + (rg.unsqueeze(2) * ex).sum(1)       # residual + MoE combine
        x = F.gelu(self.gn1(x))
        logits = self._causal(self.readout, x)      # (B, V, T)
        return logits


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--d", type=int, default=1536)
    ap.add_argument("--t", type=int, default=512)
    ap.add_argument("--e", type=int, default=2)
    ap.add_argument("--k", type=int, default=3)
    ap.add_argument("--v", type=int, default=256)
    ap.add_argument("--batch", type=int, default=1)
    ap.add_argument("--steps", type=int, default=40)
    ap.add_argument("--warmup", type=int, default=8)
    ap.add_argument("--dtype", choices=["fp32", "tf32", "bf16", "fp16"], default="fp32")
    ap.add_argument("--mode", choices=["eager", "compile"], default="eager")
    args = ap.parse_args()

    assert torch.cuda.is_available(), "CUDA required for the vs-PyTorch wall bench"
    dev = torch.device("cuda")
    torch.manual_seed(0)

    autocast_dt = None
    if args.dtype == "tf32":
        torch.backends.cuda.matmul.allow_tf32 = True
        torch.backends.cudnn.allow_tf32 = True
    elif args.dtype == "bf16":
        autocast_dt = torch.bfloat16
    elif args.dtype == "fp16":
        autocast_dt = torch.float16

    model = CLMConvMoE(args.d, args.e, args.k, args.v).to(dev)
    opt = torch.optim.AdamW(model.parameters(), lr=1e-3)

    B, T = args.batch, args.t
    g = torch.Generator(device="cpu").manual_seed(1)
    ids = torch.randint(0, args.v, (B, T), generator=g).to(dev)
    tgt = torch.randint(0, args.v, (B, T), generator=g).to(dev)

    run = model
    if args.mode == "compile":
        run = torch.compile(model, mode="max-autotune")

    def step():
        opt.zero_grad(set_to_none=True)
        if autocast_dt is not None:
            with torch.autocast("cuda", dtype=autocast_dt):
                logits = run(ids)                       # (B, V, T)
                loss = F.cross_entropy(logits, tgt)     # over V, all positions
        else:
            logits = run(ids)
            loss = F.cross_entropy(logits, tgt)
        loss.backward()
        opt.step()
        return loss

    ce_first = None
    for i in range(args.warmup):
        l = step()
        if i == 0:
            ce_first = float(l.detach())
    torch.cuda.synchronize()

    t0 = time.perf_counter()
    ce_last = None
    for i in range(args.steps):
        l = step()
        ce_last = l
    torch.cuda.synchronize()
    elapsed = time.perf_counter() - t0
    ce_last = float(ce_last.detach())

    sps = args.steps / elapsed if elapsed > 0 else 0.0
    mspstep = 1000.0 * elapsed / args.steps if args.steps else 0.0
    print(f"[TORCH-{args.mode}] dtype={args.dtype} D={args.d} T={args.t} E={args.e} "
          f"K={args.k} B={B} steps={args.steps} warmup={args.warmup} "
          f"elapsed={elapsed:.3f} step/s={sps:.3f} ms/step={mspstep:.2f}   "
          f"CE_first={ce_first:.4f} CE_last={ce_last:.4f}", flush=True)


if __name__ == "__main__":
    main()
