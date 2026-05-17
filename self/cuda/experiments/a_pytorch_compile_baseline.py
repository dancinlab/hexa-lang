"""
a_pytorch_compile_baseline.py — forge Phase R / A: PyTorch torch.compile baseline
(SOTA-strong PyTorch path: Inductor JIT compilation).

Same 3-layer MLP architecture as a_aot_trainer.cu / a_pytorch_baseline.py:
  Linear(D_in → D_hid, no bias, FP64) → ReLU
  Linear(D_hid → D_hid, no bias, FP64) → ReLU
  Linear(D_hid → D_out, no bias, FP64)
  → CrossEntropyLoss
  → AdamW(lr=1e-3, β1=0.9, β2=0.999, eps=1e-8, wd=1e-2)

Same configs as eager baseline (stage1 + stage2 expanded):
  - mnist_b32  : B=32  D_in=784  D_hid=256  D_out=10    n_warm=10 n_iter=100
  - mnist_b128 : B=128 D_in=784  D_hid=256  D_out=10    n_warm=10 n_iter=100
  - mid_b32    : B=32  D_in=4096 D_hid=4096 D_out=100   n_warm=5  n_iter=50
  - large_b128 : B=128 D_in=8192 D_hid=8192 D_out=1000  n_warm=3  n_iter=30  (Stage 2)
  - xlarge_b128: B=128 D_in=16384 D_hid=16384 D_out=1000 n_warm=3 n_iter=10  (Stage 2)

Mode comparison:
  - 'default' : torch.compile(model) — standard Inductor (fusion + codegen)
  - 'reduce-overhead' : torch.compile(model, mode='reduce-overhead') — CUDA-graphs path

CLI:
  python a_pytorch_compile_baseline.py [preset] [mode]
    preset ∈ {all, stage1, stage2}; default = all
    mode   ∈ {default, reduce-overhead}; default = default

Output JSON: ./pytorch_compile_result.json (single mode per fire).

Note: Compile cost is paid in warmup only. We extend n_warm to absorb the
JIT cost so the timed n_iter samples reflect steady-state compiled execution.
"""

import json
import sys
import time
import torch
import torch.nn as nn

device = torch.device('cuda')
torch.backends.cudnn.benchmark = True
torch.set_default_dtype(torch.float64)


class MLP3(nn.Module):
    def __init__(self, D_in, D_hid, D_out):
        super().__init__()
        self.fc1 = nn.Linear(D_in,  D_hid, bias=False)
        self.fc2 = nn.Linear(D_hid, D_hid, bias=False)
        self.fc3 = nn.Linear(D_hid, D_out, bias=False)

    def forward(self, x):
        return self.fc3(torch.relu(self.fc2(torch.relu(self.fc1(x)))))


def main():
    preset = sys.argv[1] if len(sys.argv) > 1 else 'all'
    mode   = sys.argv[2] if len(sys.argv) > 2 else 'default'
    assert mode in ('default', 'reduce-overhead', 'max-autotune'), f"unknown mode: {mode}"

    all_configs = [
        dict(label='mnist_b32',   B=32,  D_in=784,   D_hid=256,   D_out=10,   n_warm=15, n_iter=100, stage='stage1'),
        dict(label='mnist_b128',  B=128, D_in=784,   D_hid=256,   D_out=10,   n_warm=15, n_iter=100, stage='stage1'),
        dict(label='mid_b32',     B=32,  D_in=4096,  D_hid=4096,  D_out=100,  n_warm=10, n_iter=50,  stage='stage1'),
        dict(label='large_b128',  B=128, D_in=8192,  D_hid=8192,  D_out=1000, n_warm=8,  n_iter=30,  stage='stage2'),
        dict(label='xlarge_b128', B=128, D_in=16384, D_hid=16384, D_out=1000, n_warm=8,  n_iter=10,  stage='stage2'),
    ]
    configs = [c for c in all_configs if preset == 'all' or c['stage'] == preset]
    print(f"[PyT-C] preset={preset} · mode={mode} · selected {len(configs)} configs · torch={torch.__version__}")

    results = []
    compile_kwargs = {} if mode == 'default' else {'mode': mode}

    for c in configs:
        print(f"\n[PyT-C] === config: {c['label']} B={c['B']} Din={c['D_in']} Dhid={c['D_hid']} Dout={c['D_out']} mode={mode} ===")
        model = MLP3(c['D_in'], c['D_hid'], c['D_out']).to(device, dtype=torch.float64)

        # torch.compile: wrap the forward; PyTorch handles autograd graph capture & codegen.
        # Compile happens lazily on the first forward call; warmup absorbs the cost.
        t_compile_start = time.perf_counter()
        compiled = torch.compile(model, **compile_kwargs)
        # We measure compile wall as warmup-1 elapsed (proxy — compile is lazy)

        opt = torch.optim.AdamW(compiled.parameters(), lr=1e-3, betas=(0.9, 0.999), eps=1e-8, weight_decay=1e-2)
        crit = nn.CrossEntropyLoss()

        torch.manual_seed(0xDEADBEEF + hash(c['label']) & 0xFFFF)
        X = torch.randn(c['B'], c['D_in'], dtype=torch.float64, device=device) * 0.5
        y = torch.randint(0, c['D_out'], (c['B'],), device=device)

        # Warmup (1st iter triggers compile, subsequent iters reach steady-state)
        t_warm_start = time.perf_counter()
        for w_idx in range(c['n_warm']):
            opt.zero_grad(set_to_none=True)
            logits = compiled(X)
            loss = crit(logits, y)
            loss.backward()
            opt.step()
            if w_idx == 0:
                torch.cuda.synchronize()
                t_first_iter_ms = (time.perf_counter() - t_warm_start) * 1000.0
                print(f"[PyT-C]   first-iter (incl compile) = {t_first_iter_ms:.2f} ms")
        torch.cuda.synchronize()
        t_warm_total_ms = (time.perf_counter() - t_warm_start) * 1000.0
        print(f"[PyT-C]   total warmup ({c['n_warm']} iters incl compile) = {t_warm_total_ms:.2f} ms")

        # Time n_iter
        samples = []
        for _ in range(c['n_iter']):
            t0 = time.perf_counter()
            opt.zero_grad(set_to_none=True)
            logits = compiled(X)
            loss = crit(logits, y)
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

        print(f"[PyT-C]   median={med:.4f} ms · min={mn:.4f} · max={mx:.4f} · mean={mean:.4f} · final_loss={final_loss:.4f}")

        results.append(dict(
            label=c['label'], B=c['B'], D_in=c['D_in'], D_hid=c['D_hid'], D_out=c['D_out'],
            step_ms_median=med, step_ms_min=mn, step_ms_max=mx, step_ms_mean=mean,
            first_iter_ms=t_first_iter_ms,
            warmup_total_ms=t_warm_total_ms,
            final_loss=final_loss, n_warm=c['n_warm'], n_iter=c['n_iter'],
            compile_mode=mode,
        ))

    out = dict(
        experiment='forge_phaseR_a_pytorch_compile_baseline',
        date='2026-05-17',
        pytorch_version=torch.__version__,
        cuda_device_name=torch.cuda.get_device_name(0),
        cuda_capability=torch.cuda.get_device_capability(0),
        dtype='float64',
        compile_mode=mode,
        configs=results,
    )
    out_path = f'pytorch_compile_{mode.replace("-","_")}_result.json'
    with open(out_path, 'w') as f:
        json.dump(out, f, indent=2)
    print(f"\n[PyT-C] DONE — {len(results)} configs (mode={mode}) · output → ./{out_path}")


if __name__ == '__main__':
    main()
