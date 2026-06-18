#!/usr/bin/env python3
"""Hypothesis 128: Scale Dependency — Golden MoE vs Top-K on CIFAR-10"""

import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.utils.data import DataLoader
from torchvision import datasets, transforms
import numpy as np
import time


class Expert(nn.Module):
    def __init__(self, input_dim, hidden_dim, output_dim, dropout=0.5):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(input_dim, hidden_dim),
            nn.ReLU(),
            nn.Dropout(dropout),
            nn.Linear(hidden_dim, hidden_dim),
            nn.ReLU(),
            nn.Dropout(dropout),
            nn.Linear(hidden_dim, output_dim),
        )

    def forward(self, x):
        return self.net(x)


class TopKGate(nn.Module):
    def __init__(self, input_dim, n_experts, k=2):
        super().__init__()
        self.gate = nn.Linear(input_dim, n_experts)
        self.k = k

    def forward(self, x):
        scores = self.gate(x)
        topk_vals, topk_idx = scores.topk(self.k, dim=-1)
        mask = torch.zeros_like(scores)
        mask.scatter_(-1, topk_idx, 1.0)
        weights = F.softmax(scores, dim=-1) * mask
        return weights / (weights.sum(dim=-1, keepdim=True) + 1e-8)


class BoltzmannGate(nn.Module):
    def __init__(self, input_dim, n_experts, temperature=np.e, active_ratio=0.7):
        super().__init__()
        self.gate = nn.Linear(input_dim, n_experts)
        self.temperature = temperature
        self.n_active = max(1, int(n_experts * active_ratio))

    def forward(self, x):
        scores = self.gate(x) / self.temperature
        probs = F.softmax(scores, dim=-1)
        topk_vals, topk_idx = probs.topk(self.n_active, dim=-1)
        mask = torch.zeros_like(probs)
        mask.scatter_(-1, topk_idx, 1.0)
        weights = probs * mask
        return weights / (weights.sum(dim=-1, keepdim=True) + 1e-8)


class MoE(nn.Module):
    def __init__(self, input_dim, hidden_dim, output_dim, n_experts=8,
                 gate_type='boltzmann', k=2, temperature=np.e, active_ratio=0.7):
        super().__init__()
        self.experts = nn.ModuleList([Expert(input_dim, hidden_dim, output_dim) for _ in range(n_experts)])
        if gate_type == 'topk':
            self.gate = TopKGate(input_dim, n_experts, k)
        else:
            self.gate = BoltzmannGate(input_dim, n_experts, temperature, active_ratio)

    def forward(self, x):
        weights = self.gate(x)
        outputs = torch.stack([e(x) for e in self.experts], dim=1)
        return (weights.unsqueeze(-1) * outputs).sum(dim=1)


def train_eval(model, train_loader, test_loader, epochs=15, lr=0.001):
    optimizer = torch.optim.Adam(model.parameters(), lr=lr)
    criterion = nn.CrossEntropyLoss()
    accs = []

    for epoch in range(epochs):
        model.train()
        for X, y in train_loader:
            X = X.view(X.size(0), -1)
            optimizer.zero_grad()
            loss = criterion(model(X), y)
            loss.backward()
            optimizer.step()

        model.eval()
        correct = total = 0
        with torch.no_grad():
            for X, y in test_loader:
                X = X.view(X.size(0), -1)
                correct += (model(X).argmax(1) == y).sum().item()
                total += y.size(0)
        acc = correct / total
        accs.append(acc)
        if (epoch + 1) % 3 == 0 or epoch == 0:
            print(f"    Epoch {epoch+1:>2}: {acc*100:.1f}%")

    return accs


def main():
    print("═" * 60)
    print("  Hypothesis 128: CIFAR-10 Scale Dependency")
    print("═" * 60)

    transform = transforms.Compose([
        transforms.ToTensor(),
        transforms.Normalize((0.5, 0.5, 0.5), (0.5, 0.5, 0.5))
    ])
    print("\n  Loading CIFAR-10...", end=" ")
    train_data = datasets.CIFAR10('./data', train=True, download=True, transform=transform)
    test_data = datasets.CIFAR10('./data', train=False, transform=transform)
    train_loader = DataLoader(train_data, batch_size=128, shuffle=True)
    test_loader = DataLoader(test_data, batch_size=256)
    print("done")

    input_dim = 3072  # 32×32×3
    hidden_dim = 128
    output_dim = 10

    configs = [
        ('Top-K (K=2)', 'topk'),
        ('Golden MoE (T=e)', 'boltzmann'),
    ]

    results = {}
    for name, gtype in configs:
        print(f"\n  [{name}]")
        model = MoE(input_dim, hidden_dim, output_dim, n_experts=8, gate_type=gtype)
        params = sum(p.numel() for p in model.parameters())
        print(f"  Parameters: {params:,}")

        start = time.time()
        accs = train_eval(model, train_loader, test_loader, epochs=15)
        elapsed = time.time() - start
        results[name] = {'acc': accs[-1], 'best': max(accs), 'time': elapsed}

    print(f"\n{'═' * 60}")
    print(f"  MNIST vs CIFAR-10 Comparison")
    print(f"{'═' * 60}")
    print(f"  MNIST:   Golden MoE 97.7% vs Top-K 97.1% = +0.6%")
    for name, r in results.items():
        print(f"  CIFAR-10 {name}: {r['best']*100:.1f}%")

    if len(results) == 2:
        names = list(results.keys())
        diff = results[names[1]]['best'] - results[names[0]]['best']
        print(f"\n  CIFAR-10 difference: {diff*100:+.1f}%")
        print(f"  MNIST difference:    +0.6%")
        print(f"  → {'Difference increases with scale' if abs(diff) > 0.006 else 'Similar regardless of scale'}")


if __name__ == '__main__':
    main()