#!/usr/bin/env python3
# torch_bench_step.py — HEXA-BENCH BENCH-1 PyTorch side.
#
# An EQUIVALENT CLMConvMoE train step to tool/bench/flame_bench_step.cu:
#   fwd  H = A @ W            (linear projection [B*T,D] @ [D,D]; the MoE-expert
#                             conv-projection reduced to its load-bearing GEMM)
#   glue G = gelu(groupnorm(H))   (FF-VALLEY — same per-row normalize + tanh-gelu)
#   bwd  dW = A^T @ dG        (autograd produces this from the loss)
#   opt  AdamW W'             (torch.optim.AdamW, same hyperparams as the .cu)
#
# Same shapes (D,T,B), matched dtype:
#   --dtype fp32 | tf32 | fp64
#     fp32  -> float32, set_float32_matmul_precision('highest')
#     tf32  -> float32, set_float32_matmul_precision('high') + allow_tf32 (the
#              consumer-Blackwell equivalent of the flame TF32 lane)
#     fp64  -> float64
#   --mode eager | compile     (torch.compile = inductor)
#
# Emits, machine-greppable (same key format as the .cu):
#   [RESULT] <DTYPE> mode=<m> B=<b>  ms/step=..  step/s=..  samples/s=..
# OOM is caught and reported as: [RESULT] <DTYPE> mode=<m> B=<b> OOM

import argparse, time, sys
import torch
import torch.nn as nn

def build(D, dtype, dev):
    class Step(nn.Module):
        def __init__(self):
            super().__init__()
            # MoE-expert projection reduced to a linear GEMM [D->D] (no bias, matches .cu W[D,D])
            self.proj = nn.Linear(D, D, bias=False)
            # groupnorm-ish: per-row LayerNorm over the feature dim D (matches k_valley)
            self.norm = nn.LayerNorm(D, eps=1e-5)
        def forward(self, x):                # x: [B*T, D]
            h = self.proj(x)                 # H = A @ W
            g = torch.nn.functional.gelu(self.norm(h), approximate='tanh')
            return g
    m = Step().to(dev).to(dtype)
    return m

def run(D, T, B, dtype_name, mode, iters, dev):
    if dtype_name == 'fp64':
        dtype = torch.float64
    elif dtype_name == 'bf16':
        dtype = torch.bfloat16
    else:
        dtype = torch.float32
    if dtype_name == 'tf32':
        torch.set_float32_matmul_precision('high')
        torch.backends.cuda.matmul.allow_tf32 = True
        torch.backends.cudnn.allow_tf32 = True
    elif dtype_name == 'fp32':
        torch.set_float32_matmul_precision('highest')
        torch.backends.cuda.matmul.allow_tf32 = False

    try:
        torch.manual_seed(0)
        model = build(D, dtype, dev)
        opt = torch.optim.AdamW(model.parameters(), lr=0.001, betas=(0.9,0.999),
                                eps=1e-8, weight_decay=0.01)
        x = (torch.rand(B*T, D, device=dev, dtype=dtype)-0.5)*0.1
        tgt = (torch.rand(B*T, D, device=dev, dtype=dtype)-0.5)*0.05

        def train_step():
            opt.zero_grad(set_to_none=True)
            out = model(x)
            loss = ((out - tgt)**2).mean()
            loss.backward()
            opt.step()
            return loss

        fn = torch.compile(train_step, mode='default') if mode == 'compile' else train_step

        # warmup (compile triggers here)
        for _ in range(5):
            fn()
        torch.cuda.synchronize()

        t0 = time.perf_counter()
        for it in range(iters):
            fn()
        torch.cuda.synchronize()
        t1 = time.perf_counter()
    except torch.cuda.OutOfMemoryError as e:
        print(f"[RESULT] {dtype_name.upper()} mode={mode} B={B} OOM")
        torch.cuda.empty_cache()
        return
    except RuntimeError as e:
        if 'out of memory' in str(e).lower():
            print(f"[RESULT] {dtype_name.upper()} mode={mode} B={B} OOM")
            torch.cuda.empty_cache()
            return
        raise

    ms_step = (t1-t0)/iters*1000.0
    step_s = 1000.0/ms_step
    samp_s = step_s*B
    print(f"[CFG] {dtype_name.upper()} mode={mode} GPU={torch.cuda.get_device_name(dev)} "
          f"D={D} T={T} B={B} M={B*T} iters={iters} torch={torch.__version__}")
    print(f"[RESULT] {dtype_name.upper()} mode={mode} B={B}  ms/step={ms_step:.4f}  "
          f"step/s={step_s:.4f}  samples/s={samp_s:.4f}")

if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--D', type=int, default=768)
    ap.add_argument('--T', type=int, default=256)
    ap.add_argument('--B', type=int, default=1)
    ap.add_argument('--dtype', default='fp32', choices=['fp32','tf32','fp64','bf16'])
    ap.add_argument('--mode', default='eager', choices=['eager','compile'])
    ap.add_argument('--iters', type=int, default=50)
    a = ap.parse_args()
    dev = 'cuda'
    if not torch.cuda.is_available():
        print("[ERR] no CUDA device"); sys.exit(1)
    run(a.D, a.T, a.B, a.dtype, a.mode, a.iters, dev)
