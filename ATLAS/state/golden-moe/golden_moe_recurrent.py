#!/usr/bin/env python3
"""Hypothesis 126: Golden MoE + Recurrent (LSTM) Combination — MNIST"""

import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.utils.data import DataLoader
from torchvision import datasets, transforms
import numpy as np
import time


class RecurrentExpert(nn.Module):
    """Expert with LSTM recurrence added"""
    def __init__(self, input_dim, hidden_dim, output_dim, dropout=0.5):
        super().__init__()
        # Transform input to sequence (28×28 → 28 steps × 28 features)
        self.lstm = nn.LSTM(28, hidden_dim, batch_first=True)
        self.dropout = nn.Dropout(dropout)
        self.fc = nn.Linear(hidden_dim, output_dim)

    def forward(self, x):
        # x: (batch, 784) → (batch, 28, 28)
        x = x.view(-1, 28, 28)
        lstm_out, _ = self.lstm(x)
        last = lstm_out[:, -1, :]  # Last timestep
        return self.fc(self.dropout(last))


class SimpleExpert(nn.Module):
    """Existing feedforward Expert"""
    def __init__(self, input_dim, hidden_dim, output_dim, dropout=0.5):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(input_dim, hidden_dim),
            nn.ReLU(),
            nn.Dropout(dropout),
            nn.Linear(hidden_dim, output_dim),
        )

    def forward(self, x):
        return self.net(x)


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
        weights = weights / (weights.sum(dim=-1, keepdim=True) + 1e-8)
        return weights


class HybridMoE(nn.Module):
    """Golden MoE + Recurrence: Some Experts are LSTM"""
    def __init__(self, input_dim, hidden_dim, output_dim, n_experts=8,
                 n_recurrent=4, temperature=np.e, active_ratio=0.7, dropout=0.5):
        super().__init__()
        experts = []
        for i in range(n_experts):
            if i < n_recurrent:
                experts.append(RecurrentExpert(input_dim, hidden_dim, output_dim, dropout))
            else:
                experts.append(SimpleExpert(input_dim, hidden_dim, output_dim, dropout))
        self.experts = nn.ModuleList(experts)
        self.gate = BoltzmannGate(input_dim, n_experts, temperature, active_ratio)
        self.n_experts = n_experts

    def forward(self, x):
        weights = self.gate(x)
        expert_outputs = torch.stack([e(x) for e in self.experts], dim=1)
        output = (weights.unsqueeze(-1) * expert_outputs).sum(dim=1)
        return output


def train_eval(model, train_loader, test_loader, epochs=10, lr=0.001):
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
                pred = model(X).argmax(dim=1)
                correct += (pred == y).sum().item()
                total += y.size(0)
        acc = correct / total
        accs.append(acc)
        if (epoch + 1) % 2 == 0 or epoch == 0:
            print(f"    Epoch {epoch+1:>2}: Acc={acc*100:.1f}%")

    return accs


def main():
    print("═" * 60)
    print("  Hypothesis 126: Golden MoE + Recurrence (LSTM) — MNIST")
    print("═" * 60)

    transform = transforms.Compose([
        transforms.ToTensor(),
        transforms.Normalize((0.1307,), (0.3081,))
    ])
    train_data = datasets.MNIST('./data', train=True, download=True, transform=transform)
    test_data = datasets.MNIST('./data', train=False, transform=transform)
    train_loader = DataLoader(train_data, batch_size=128, shuffle=True)
    test_loader = DataLoader(test_data, batch_size=256)

    configs = [
        ('Golden MoE (feedforward only)', 'ff'),
        ('Golden MoE + LSTM (4/8)', 'hybrid'),
    ]

    results = {}
    for name, ctype in configs:
        print(f"\n  [{name}]")
        if ctype == 'ff':
            from golden_moe_torch import MoEModel
            model = MoEModel(784, 64, 10, n_experts=8, gate_type='boltzmann',
                           temperature=np.e, active_ratio=0.7, dropout=0.5)
        else:
            model = HybridMoE(784, 64, 10, n_experts=8, n_recurrent=4,
                            temperature=np.e, active_ratio=0.7, dropout=0.5)

        params = sum(p.numel() for p in model.parameters())
        print(f"  Parameters: {params:,}")

        start = time.time()
        accs = train_eval(model, train_loader, test_loader, epochs=10)
        elapsed = time.time() - start

        results[name] = {'acc': accs[-1], 'best': max(accs), 'time': elapsed, 'params': params}

    print(f"\n{'═' * 60}")
    print(f"  Comparison")
    print(f"{'═' * 60}")
    for name, r in results.items():
        print(f"  {name:25}: Accuracy={r['acc']*100:.1f}% (Best={r['best']*100:.1f}%), {r['time']:.0f}s, {r['params']:,} parameters")

    if len(results) == 2:
        names = list(results.keys())
        diff = results[names[1]]['best'] - results[names[0]]['best']
        print(f"\n  LSTM addition effect: {diff*100:+.1f}%")
        print(f"  Verdict: {'✅ Recurrence addition effective' if diff > 0 else '❌ No effect'}")


if __name__ == '__main__':
    main()