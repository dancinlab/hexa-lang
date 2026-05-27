"""
a_pytorch_baseline.py — forge Phase R / A: PyTorch eager baseline (compare vs AOT trainer).

Same 3-layer MLP architecture as a_aot_trainer.cu:
  Linear(D_in → D_hid, no bias, FP64) → ReLU
  Linear(D_hid → D_hid, no bias, FP64) → ReLU
  Linear(D_hid → D_out, no bias, FP64)
  → CrossEntropyLoss
  → AdamW(lr=1e-3, β1=0.9, β2=0.999, eps=1e-8, wd=1e-2)

Three configs matching a_aot_trainer.cu:
  - mnist_b32  : B=32  D_in=784  D_hid=256  D_out=10    n_warm=10 n_iter=100
  - mnist_b128 : B=128 D_in=784  D_hid=256  D_out=10    n_warm=10 n_iter=100
  - mid_b32    : B=32  D_in=4096 D_hid=4096 D_out=100   n_warm=5  n_iter=50

Times each (warmup, then n_iter steps), reports median ms per step.
Output JSON: /workspace/forge_phaseR_a/pytorch_result.json

Note: PyTorch eager dispatch path = Python + ATen + kernel launch per op.
Comparison vs single-binary CUDA AOT trainer measures eager-dispatch overhead.
"""

import json
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

import sys
preset = sys.argv[1] if len(sys.argv) > 1 else 'all'
all_configs = [
    dict(label='mnist_b32',   B=32,  D_in=784,   D_hid=256,   D_out=10,   n_warm=10, n_iter=100, stage='stage1'),
    dict(label='mnist_b128',  B=128, D_in=784,   D_hid=256,   D_out=10,   n_warm=10, n_iter=100, stage='stage1'),
    dict(label='mid_b32',     B=32,  D_in=4096,  D_hid=4096,  D_out=100,  n_warm=5,  n_iter=50,  stage='stage1'),
    dict(label='large_b128',  B=128, D_in=8192,  D_hid=8192,  D_out=1000, n_warm=3,  n_iter=30,  stage='stage2'),
    dict(label='large_b512',  B=512, D_in=8192,  D_hid=8192,  D_out=1000, n_warm=3,  n_iter=20,  stage='stage2'),
    dict(label='xlarge_b128', B=128, D_in=16384, D_hid=16384, D_out=1000, n_warm=3,  n_iter=10,  stage='stage2'),
]
configs = [c for c in all_configs if preset == 'all' or c['stage'] == preset]
print(f"[PyT] preset={preset} · selected {len(configs)} configs")

results = []
for c in configs:
    print(f"\n[PyT] === config: {c['label']} B={c['B']} Din={c['D_in']} Dhid={c['D_hid']} Dout={c['D_out']} ===")
    model = MLP3(c['D_in'], c['D_hid'], c['D_out']).to(device, dtype=torch.float64)
    opt = torch.optim.AdamW(model.parameters(), lr=1e-3, betas=(0.9, 0.999), eps=1e-8, weight_decay=1e-2)
    crit = nn.CrossEntropyLoss()

    # Deterministic inputs (avoid bench noise from randn changing per call)
    torch.manual_seed(0xDEADBEEF + hash(c['label']) & 0xFFFF)
    X = torch.randn(c['B'], c['D_in'], dtype=torch.float64, device=device) * 0.5
    y = torch.randint(0, c['D_out'], (c['B'],), device=device)

    # Warmup
    for _ in range(c['n_warm']):
        opt.zero_grad(set_to_none=True)
        logits = model(X)
        loss = crit(logits, y)
        loss.backward()
        opt.step()
    torch.cuda.synchronize()

    # Time n_iter
    samples = []
    for _ in range(c['n_iter']):
        t0 = time.perf_counter()
        opt.zero_grad(set_to_none=True)
        logits = model(X)
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

    print(f"[PyT]   median={med:.4f} ms · min={mn:.4f} · max={mx:.4f} · mean={mean:.4f} · final_loss={final_loss:.4f}")

    results.append(dict(
        label=c['label'], B=c['B'], D_in=c['D_in'], D_hid=c['D_hid'], D_out=c['D_out'],
        step_ms_median=med, step_ms_min=mn, step_ms_max=mx, step_ms_mean=mean,
        final_loss=final_loss, n_warm=c['n_warm'], n_iter=c['n_iter'],
    ))

out = dict(
    experiment='forge_phaseR_a_pytorch_baseline',
    date='2026-05-17',
    pytorch_version=torch.__version__,
    cuda_device_name=torch.cuda.get_device_name(0),
    cuda_capability=torch.cuda.get_device_capability(0),
    dtype='float64',
    configs=results,
)
with open('pytorch_result.json', 'w') as f:
    json.dump(out, f, indent=2)
print(f"\n[PyT] DONE — {len(results)} configs · output → ./pytorch_result.json")
