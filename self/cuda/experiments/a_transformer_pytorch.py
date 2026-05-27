"""
a_transformer_pytorch.py — forge Phase R / A Stage 2 Phase 2: PyTorch eager baseline.

Matches a_transformer_aot.cu architecture EXACTLY:
  - X[B, L, D]
  - RMSNorm(γ1) → Q, K, V (3 Linear(D→D, bias=False))
  - Causal scaled dot-product attention (single block, FP64)
  - Out projection (Linear(D→D, bias=False))
  - + residual
  - RMSNorm(γ2)
  - SwiGLU gate (Linear(D→Df)) + up (Linear(D→Df))
  - SwiGLU activation: SiLU(gate) * up
  - Down projection (Linear(Df→D))
  - + residual → Y[B, L, D]

Loss: MSE(Y, target).  Optimizer: AdamW(lr=1e-4, β=(0.9, 0.999), eps=1e-8, wd=1e-2).

Same configs (small / medium / large) as the AOT trainer.

Output: pytorch_result.json in CWD.
"""

import json
import math
import sys
import time

import torch
import torch.nn as nn
import torch.nn.functional as F


device = torch.device('cuda')
torch.backends.cudnn.benchmark = True
torch.set_default_dtype(torch.float64)


class RMSNorm(nn.Module):
    """Llama-style RMSNorm without bias.  out[i, j] = x[i, j] * rsqrt(mean(x^2) + eps) * gamma[j]."""

    def __init__(self, dim: int, eps: float = 1e-6):
        super().__init__()
        self.eps = eps
        self.gamma = nn.Parameter(torch.ones(dim, dtype=torch.float64))

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        rrms = torch.rsqrt(x.pow(2).mean(dim=-1, keepdim=True) + self.eps)
        return x * rrms * self.gamma


class TransformerBlock(nn.Module):
    """Single Llama-style transformer block.

    Layout note: the AOT trainer keeps Q/K/V at [N=B*L, D] in (B, L, nh, hd)
    row-major memory order, then permutes to (B, nh, L, hd) for attention.
    PyTorch's `view` + `transpose` gives the same logical reshape; eager
    autograd handles the permute strides automatically.
    """

    def __init__(self, d_model: int, n_heads: int, d_ffn: int):
        super().__init__()
        assert d_model % n_heads == 0
        self.d = d_model
        self.nh = n_heads
        self.hd = d_model // n_heads
        self.df = d_ffn
        self.norm1 = RMSNorm(d_model)
        self.norm2 = RMSNorm(d_model)
        self.wq = nn.Linear(d_model, d_model, bias=False)
        self.wk = nn.Linear(d_model, d_model, bias=False)
        self.wv = nn.Linear(d_model, d_model, bias=False)
        self.wo = nn.Linear(d_model, d_model, bias=False)
        self.w_gate = nn.Linear(d_model, d_ffn, bias=False)
        self.w_up = nn.Linear(d_model, d_ffn, bias=False)
        self.w_down = nn.Linear(d_ffn, d_model, bias=False)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        B, L, D = x.shape
        nh, hd = self.nh, self.hd

        # Attention path
        h = self.norm1(x)
        q = self.wq(h).view(B, L, nh, hd).transpose(1, 2)  # [B, nh, L, hd]
        k = self.wk(h).view(B, L, nh, hd).transpose(1, 2)
        v = self.wv(h).view(B, L, nh, hd).transpose(1, 2)

        scale = 1.0 / math.sqrt(hd)
        # scores: [B, nh, L, L]
        scores = torch.matmul(q, k.transpose(-2, -1)) * scale
        # causal mask: zero out future positions
        mask = torch.triu(torch.ones(L, L, dtype=torch.bool, device=scores.device), diagonal=1)
        scores = scores.masked_fill(mask, float('-inf'))
        p = torch.softmax(scores, dim=-1)
        attn = torch.matmul(p, v)  # [B, nh, L, hd]
        attn = attn.transpose(1, 2).contiguous().view(B, L, D)  # [B, L, D]
        attn_out = self.wo(attn)
        res1 = x + attn_out

        # FFN path
        h2 = self.norm2(res1)
        gate = self.w_gate(h2)
        up = self.w_up(h2)
        ffn_h = F.silu(gate) * up
        ffn_out = self.w_down(ffn_h)
        y = res1 + ffn_out
        return y


def main():
    preset = sys.argv[1] if len(sys.argv) > 1 else 'all'

    all_configs = [
        dict(label='small',  B=1, L=64,  D=512,  nh=8,  Df=2048,  n_warm=3, n_iter=30),
        dict(label='medium', B=1, L=128, D=2048, nh=16, Df=5632,  n_warm=3, n_iter=20),
        dict(label='large',  B=1, L=512, D=4096, nh=32, Df=11008, n_warm=2, n_iter=10),
    ]
    configs = [c for c in all_configs if preset == 'all' or c['label'] == preset]
    print(f"[PyT-T] preset={preset} · selected {len(configs)} configs")

    results = []
    for c in configs:
        print(f"\n[PyT-T] === config: {c['label']} B={c['B']} L={c['L']} D={c['D']} nh={c['nh']} hd={c['D']//c['nh']} Df={c['Df']} ===")

        model = TransformerBlock(c['D'], c['nh'], c['Df']).to(device, dtype=torch.float64)
        opt = torch.optim.AdamW(model.parameters(), lr=1e-4, betas=(0.9, 0.999), eps=1e-8, weight_decay=1e-2)

        # Deterministic inputs
        torch.manual_seed(0xDEADC0DE + (hash(c['label']) & 0xFFFF))
        X = torch.randn(c['B'], c['L'], c['D'], dtype=torch.float64, device=device) * 0.5
        target = torch.randn(c['B'], c['L'], c['D'], dtype=torch.float64, device=device) * 0.5

        # Initial loss
        opt.zero_grad(set_to_none=True)
        y0 = model(X)
        initial_loss = float(F.mse_loss(y0, target).item())

        # Warmup (includes the loss/backward/step from the call above)
        for _ in range(c['n_warm']):
            opt.zero_grad(set_to_none=True)
            y = model(X)
            loss = F.mse_loss(y, target)
            loss.backward()
            opt.step()
        torch.cuda.synchronize()

        # Time n_iter
        samples = []
        for _ in range(c['n_iter']):
            t0 = time.perf_counter()
            opt.zero_grad(set_to_none=True)
            y = model(X)
            loss = F.mse_loss(y, target)
            loss.backward()
            opt.step()
            torch.cuda.synchronize()
            samples.append((time.perf_counter() - t0) * 1000.0)
        samples.sort()
        n = len(samples)
        med = samples[n // 2]
        mn = samples[0]
        mx = samples[-1]
        mean = sum(samples) / n
        final_loss = float(loss.item())

        print(f"[PyT-T]   median={med:.4f} ms · min={mn:.4f} · max={mx:.4f} · mean={mean:.4f} · initial_loss={initial_loss:.6f} · final_loss={final_loss:.6f}")

        results.append(dict(
            label=c['label'], B=c['B'], L=c['L'], D=c['D'], nh=c['nh'],
            hd=c['D'] // c['nh'], Df=c['Df'],
            step_ms_median=med, step_ms_min=mn, step_ms_max=mx, step_ms_mean=mean,
            initial_loss=initial_loss, final_loss=final_loss,
            n_warm=c['n_warm'], n_iter=c['n_iter'],
        ))

    out = dict(
        experiment='forge_phaseR_a_transformer_pytorch',
        date='2026-05-17',
        pytorch_version=torch.__version__,
        cuda_device_name=torch.cuda.get_device_name(0),
        cuda_capability=torch.cuda.get_device_capability(0),
        dtype='float64',
        configs=results,
    )
    with open('pytorch_result.json', 'w') as f:
        json.dump(out, f, indent=2)
    print(f"\n[PyT-T] DONE — {len(results)} configs · output → ./pytorch_result.json")


if __name__ == '__main__':
    main()
