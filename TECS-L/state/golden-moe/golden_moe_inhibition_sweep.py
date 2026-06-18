#!/usr/bin/env python3
"""Golden MoE 억제율 sweep — "37% rest(=1/e) 가 창의성 peak 인가?" 검증.
8 experts, Boltzmann gate (T=e), n_active 2..8 sweep (rest = 1 - n_active/8).
n_active=5 → rest 37.5% ≈ 1/e. peak 가 거기 오는지 측정. CIFAR-10, MLP experts."""
import torch, torch.nn as nn, torch.nn.functional as F, numpy as np, time, math
from torch.utils.data import DataLoader
from torchvision import datasets, transforms

DEV = 'cuda' if torch.cuda.is_available() else 'cpu'
N_EXPERTS, HID, EPOCHS, SEEDS = 8, 256, 12, [0, 1]
ACTIVE_SWEEP = [2, 3, 4, 5, 6, 7, 8]   # n_active; rest% = 1 - n/8

class Expert(nn.Module):
    def __init__(s, i, h, o, drop=0.5):
        super().__init__()
        s.net = nn.Sequential(nn.Linear(i, h), nn.ReLU(), nn.Dropout(drop),
                              nn.Linear(h, h), nn.ReLU(), nn.Dropout(drop), nn.Linear(h, o))
    def forward(s, x): return s.net(x)

class BoltzmannGate(nn.Module):
    def __init__(s, i, n, T=math.e, n_active=5):
        super().__init__(); s.gate = nn.Linear(i, n); s.T = T; s.na = n_active
    def forward(s, x):
        p = F.softmax(s.gate(x) / s.T, dim=-1)
        _, idx = p.topk(s.na, dim=-1)
        m = torch.zeros_like(p); m.scatter_(-1, idx, 1.0); w = p * m
        return w / (w.sum(-1, keepdim=True) + 1e-8)

class MoE(nn.Module):
    def __init__(s, i, h, o, n=8, n_active=5):
        super().__init__()
        s.experts = nn.ModuleList([Expert(i, h, o) for _ in range(n)])
        s.gate = BoltzmannGate(i, n, n_active=n_active)
    def forward(s, x):
        w = s.gate(x); outs = torch.stack([e(x) for e in s.experts], 1)
        return (w.unsqueeze(-1) * outs).sum(1)

def run(n_active, seed, tr, te):
    torch.manual_seed(seed); np.random.seed(seed)
    m = MoE(3072, HID, 10, N_EXPERTS, n_active).to(DEV)
    opt = torch.optim.Adam(m.parameters(), 1e-3); crit = nn.CrossEntropyLoss()
    best = 0.0
    for ep in range(EPOCHS):
        m.train()
        for xb, yb in tr:
            xb = xb.view(xb.size(0), -1).to(DEV); yb = yb.to(DEV)
            opt.zero_grad(); loss = crit(m(xb), yb); loss.backward(); opt.step()
        m.eval(); c = t = 0
        with torch.no_grad():
            for xb, yb in te:
                xb = xb.view(xb.size(0), -1).to(DEV); yb = yb.to(DEV)
                c += (m(xb).argmax(1) == yb).sum().item(); t += yb.size(0)
        best = max(best, c / t)
    return best

def main():
    print(f"device={DEV} experts={N_EXPERTS} epochs={EPOCHS} seeds={SEEDS}")
    tf = transforms.Compose([transforms.ToTensor(), transforms.Normalize((0.5,)*3, (0.5,)*3)])
    trd = datasets.CIFAR10('./data', train=True, download=True, transform=tf)
    ted = datasets.CIFAR10('./data', train=False, transform=tf)
    tr = DataLoader(trd, 256, shuffle=True, num_workers=2)
    te = DataLoader(ted, 512, num_workers=2)
    t0 = time.time(); rows = []
    for na in ACTIVE_SWEEP:
        accs = [run(na, s, tr, te) for s in SEEDS]
        mean = sum(accs) / len(accs); rest = 1 - na / N_EXPERTS
        rows.append((na, rest, mean, accs))
        print(f"  n_active={na} (rest={rest*100:4.1f}%)  acc={mean*100:5.2f}%  seeds={[round(a*100,1) for a in accs]}", flush=True)
    print("\n===== GOLDEN MoE 억제율 SWEEP 결과 =====")
    print(f"{'n_active':>8} {'rest%':>7} {'mean_acc%':>10}")
    for na, rest, mean, _ in rows:
        mark = "  <- rest 37.5% ≈ 1/e" if na == 5 else ""
        print(f"{na:>8} {rest*100:>6.1f} {mean*100:>10.2f}{mark}")
    best = max(rows, key=lambda r: r[2])
    print(f"\nPEAK: n_active={best[0]} rest={best[1]*100:.1f}% acc={best[2]*100:.2f}%")
    pred = 5  # 1/e prediction
    if best[0] == pred:
        print("VERDICT: 🟢 peak @ rest 37.5% (=1/e) — '37% 억제 = 창의성 peak' 지지")
    else:
        print(f"VERDICT: 🔴 peak @ rest {best[1]*100:.1f}% (n_active={best[0]}) ≠ 1/e 예측(n_active=5) — 명제 falsified at this scale")
    print(f"elapsed {time.time()-t0:.0f}s")

if __name__ == '__main__':
    main()
