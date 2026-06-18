#!/usr/bin/env python3
"""Golden MoE Prototype — Boltzmann Router + Cusp Monitor

Design Specification (Hypothesis 008 v2 + 019 + 082):
  Expert count: 8
  Active ratio: ~70% (5~6/8)
  Router: Boltzmann soft gating (T=e)
  Dropout: 0.5
  Cusp monitor: Loss 2nd derivative monitoring
  Control group: Top-K (K=2, 25%)
"""

import numpy as np
import os

np.random.seed(42)


# ─────────────────────────────────────────
# Expert Network (Simple 2-layer MLP)
# ─────────────────────────────────────────
class Expert:
    def __init__(self, input_dim, hidden_dim, output_dim):
        self.W1 = np.random.randn(input_dim, hidden_dim) * 0.1
        self.b1 = np.zeros(hidden_dim)
        self.W2 = np.random.randn(hidden_dim, output_dim) * 0.1
        self.b2 = np.zeros(output_dim)

    def forward(self, x):
        h = np.maximum(0, x @ self.W1 + self.b1)  # ReLU
        return h @ self.W2 + self.b2

    def params(self):
        return [self.W1, self.b1, self.W2, self.b2]


# ─────────────────────────────────────────
# Router
# ─────────────────────────────────────────
class TopKRouter:
    """Traditional approach: Top-K hard gating"""
    def __init__(self, input_dim, n_experts, k):
        self.W = np.random.randn(input_dim, n_experts) * 0.1
        self.k = k

    def route(self, x):
        scores = x @ self.W
        topk_idx = np.argsort(scores)[-self.k:]
        weights = np.zeros(scores.shape[0]) if scores.ndim > 1 else np.zeros(len(scores))
        weights = np.zeros_like(scores)
        weights[topk_idx] = 1.0
        return weights, scores


class BoltzmannRouter:
    """Golden MoE: Boltzmann soft gating"""
    def __init__(self, input_dim, n_experts, temperature=np.e):
        self.W = np.random.randn(input_dim, n_experts) * 0.1
        self.temperature = temperature

    def route(self, x):
        scores = x @ self.W
        # Boltzmann probability
        exp_scores = np.exp(scores / self.temperature)
        probs = exp_scores / exp_scores.sum()
        # Top 70% probabilistic activation: sort by probability and activate top ~70%
        n_active = max(1, int(len(scores) * 0.7))  # 8×0.7 = 5~6
        topn_idx = np.argsort(probs)[-n_active:]
        weights = np.zeros_like(probs)
        weights[topn_idx] = probs[topn_idx]
        return weights, scores


# ─────────────────────────────────────────
# Cusp Monitor
# ─────────────────────────────────────────
class CuspMonitor:
    def __init__(self, window=5, threshold_sigma=2.5):
        self.losses = []
        self.window = window
        self.threshold_sigma = threshold_sigma
        self.transitions = []

    def update(self, loss):
        self.losses.append(loss)
        if len(self.losses) < 3:
            return False

        # 2nd derivative
        d2 = self.losses[-1] - 2 * self.losses[-2] + self.losses[-3]

        # Statistics of 2nd derivatives in recent window
        if len(self.losses) >= self.window + 2:
            recent_d2 = []
            for i in range(max(2, len(self.losses) - self.window), len(self.losses)):
                recent_d2.append(self.losses[i] - 2 * self.losses[i-1] + self.losses[i-2])
            sigma = np.std(recent_d2) if len(recent_d2) > 1 else 1.0
            if abs(d2) > self.threshold_sigma * max(sigma, 1e-6):
                self.transitions.append(len(self.losses) - 1)
                return True
        return False


# ─────────────────────────────────────────
# MoE Model
# ─────────────────────────────────────────
class MixtureOfExperts:
    def __init__(self, input_dim, hidden_dim, output_dim, n_experts,
                 router_type='boltzmann', k=2, temperature=np.e, dropout=0.5):
        self.experts = [Expert(input_dim, hidden_dim, output_dim) for _ in range(n_experts)]
        self.n_experts = n_experts
        self.dropout = dropout
        self.router_type = router_type

        if router_type == 'topk':
            self.router = TopKRouter(input_dim, n_experts, k)
        else:
            self.router = BoltzmannRouter(input_dim, n_experts, temperature)

        self.monitor = CuspMonitor()
        self.expert_usage = np.zeros(n_experts)
        self.active_counts = []

    def forward(self, x, training=True):
        # Routing
        weights, _ = self.router.route(x)

        # Dropout (only during training)
        if training:
            mask = np.random.binomial(1, 1 - self.dropout, size=x.shape)
            x = x * mask / (1 - self.dropout)

        # Sum expert outputs
        output = np.zeros(self.experts[0].forward(x).shape)
        active_count = 0

        for i, expert in enumerate(self.experts):
            if weights[i] > 0:
                output += weights[i] * expert.forward(x)
                active_count += 1
                self.expert_usage[i] += 1

        self.active_counts.append(active_count)

        # Weight normalization
        w_sum = weights.sum()
        if w_sum > 0:
            output /= w_sum

        return output

    def get_metrics(self):
        return {
            'avg_active': np.mean(self.active_counts) if self.active_counts else 0,
            'active_ratio': np.mean(self.active_counts) / self.n_experts if self.active_counts else 0,
            'usage_std': np.std(self.expert_usage / max(self.expert_usage.sum(), 1)),
            'usage_dist': self.expert_usage / max(self.expert_usage.sum(), 1),
            'transitions': len(self.monitor.transitions),
        }


# ─────────────────────────────────────────
# Dataset (XOR-like classification)
# ─────────────────────────────────────────
def generate_data(n_samples=1000, n_features=8, n_classes=4):
    X = np.random.randn(n_samples, n_features)
    # Nonlinear classification: different class for each quadrant
    y = np.zeros(n_samples, dtype=int)
    y[(X[:, 0] > 0) & (X[:, 1] > 0)] = 0
    y[(X[:, 0] > 0) & (X[:, 1] <= 0)] = 1
    y[(X[:, 0] <= 0) & (X[:, 1] > 0)] = 2
    y[(X[:, 0] <= 0) & (X[:, 1] <= 0)] = 3
    return X, y


def softmax(x):
    e = np.exp(x - x.max())
    return e / e.sum()


def cross_entropy_loss(pred, target, n_classes=4):
    probs = softmax(pred)
    return -np.log(probs[target] + 1e-10)


# ─────────────────────────────────────────
# Training Loop
# ─────────────────────────────────────────
def train_and_evaluate(router_type, n_epochs=50, lr=0.01):
    X_train, y_train = generate_data(800)
    X_test, y_test = generate_data(200)

    n_experts = 8
    k = 2 if router_type == 'topk' else 0

    model = MixtureOfExperts(
        input_dim=8, hidden_dim=16, output_dim=4,
        n_experts=n_experts, router_type=router_type,
        k=k, temperature=np.e, dropout=0.5
    )

    losses = []

    for epoch in range(n_epochs):
        epoch_loss = 0
        for i in range(len(X_train)):
            pred = model.forward(X_train[i], training=True)
            loss = cross_entropy_loss(pred, y_train[i])
            epoch_loss += loss

            # Simple weight update (stochastic perturbation)
            for expert in model.experts:
                for param in expert.params():
                    param -= lr * np.random.randn(*param.shape) * loss * 0.01

        avg_loss = epoch_loss / len(X_train)
        losses.append(avg_loss)
        model.monitor.update(avg_loss)

    # Test
    correct = 0
    for i in range(len(X_test)):
        pred = model.forward(X_test[i], training=False)
        if np.argmax(pred) == y_test[i]:
            correct += 1

    accuracy = correct / len(X_test)
    metrics = model.get_metrics()

    return {
        'router': router_type,
        'accuracy': accuracy,
        'final_loss': losses[-1],
        'avg_active': metrics['avg_active'],
        'active_ratio': metrics['active_ratio'],
        'usage_std': metrics['usage_std'],
        'usage_dist': metrics['usage_dist'],
        'transitions': metrics['transitions'],
        'losses': losses,
        'I_effective': 1 - metrics['active_ratio'],
    }


# ─────────────────────────────────────────
# Main
# ─────────────────────────────────────────
def main():
    print()
    print("═" * 60)
    print("   🧠 Golden MoE Prototype v1.0")
    print("═" * 60)
    print(f"  Expert: 8 │ Data: XOR-4 class │ Epochs: 50")
    print(f"  Comparison: Top-K(K=2) vs Boltzmann(T=e)")
    print("─" * 60)

    # Train both models
    results = {}
    for rtype in ['topk', 'boltzmann']:
        print(f"\n  [{rtype}] Training...", end=" ")
        results[rtype] = train_and_evaluate(rtype)
        print(f"Complete (accuracy: {results[rtype]['accuracy']*100:.1f}%)")

    # Compare
    topk = results['topk']
    boltz = results['boltzmann']

    print(f"\n{'─' * 60}")
    print(f"  Comparison Results")
    print(f"{'─' * 60}")
    print(f"  {'Metric':20} │ {'Top-K (K=2)':>12} │ {'Boltzmann (T=e)':>12} │ Winner")
    print(f"  {'─'*20}─┼─{'─'*12}─┼─{'─'*12}─┼─{'─'*8}")
    print(f"  {'Accuracy':20} │ {topk['accuracy']*100:>11.1f}% │ {boltz['accuracy']*100:>11.1f}% │ {'Boltzmann' if boltz['accuracy']>topk['accuracy'] else 'Top-K'}")
    print(f"  {'Final Loss':20} │ {topk['final_loss']:>12.4f} │ {boltz['final_loss']:>12.4f} │ {'Boltzmann' if boltz['final_loss']<topk['final_loss'] else 'Top-K'}")
    print(f"  {'Avg Active Experts':20} │ {topk['avg_active']:>12.1f} │ {boltz['avg_active']:>12.1f} │")
    print(f"  {'Active Ratio':20} │ {topk['active_ratio']*100:>11.1f}% │ {boltz['active_ratio']*100:>11.1f}% │")
    print(f"  {'Expert Usage Equality':20} │ {topk['usage_std']:>12.4f} │ {boltz['usage_std']:>12.4f} │ {'Boltzmann' if boltz['usage_std']<topk['usage_std'] else 'Top-K'}")
    print(f"  {'Cusp Transition Detect':20} │ {topk['transitions']:>12} │ {boltz['transitions']:>12} │")
    print(f"  {'Effective I (1-active)':20} │ {topk['I_effective']:>12.3f} │ {boltz['I_effective']:>12.3f} │")

    # Golden Zone determination by I value
    print(f"\n  Golden Zone Determination:")
    for name, r in results.items():
        I = r['I_effective']
        if 0.213 <= I <= 0.500:
            zone = "🎯 Golden Zone!"
        elif I < 0.213:
            zone = "⚡ Below Golden Zone"
        else:
            zone = "○ Outside Golden Zone"
        print(f"    {name:10}: I = {I:.3f}  {zone}")

    # Expert usage distribution
    print(f"\n  Expert Usage Distribution:")
    for name, r in results.items():
        print(f"    [{name}]")
        for i, usage in enumerate(r['usage_dist']):
            bar = "█" * int(usage * 80)
            print(f"      E{i}: {bar} {usage*100:.1f}%")

    # Loss trajectory
    print(f"\n  Loss Trajectory:")
    for epoch in range(0, 50, 5):
        t_loss = topk['losses'][epoch]
        b_loss = boltz['losses'][epoch]
        t_bar = "█" * int(min(t_loss, 2) / 2 * 20)
        b_bar = "▓" * int(min(b_loss, 2) / 2 * 20)
        print(f"    {epoch:>3} │ T:{t_bar:20} │ B:{b_bar:20} │ T={t_loss:.3f} B={b_loss:.3f}")
    print(f"    █=Top-K  ▓=Boltzmann")

    # Summary
    boltz_wins = 0
    if boltz['accuracy'] > topk['accuracy']:
        boltz_wins += 1
    if boltz['final_loss'] < topk['final_loss']:
        boltz_wins += 1
    if boltz['usage_std'] < topk['usage_std']:
        boltz_wins += 1

    print(f"\n{'═' * 60}")
    print(f"  Summary: Boltzmann {boltz_wins}/3 wins")
    print(f"{'═' * 60}")

    print(f"\n  Golden MoE Design Verification:")
    print(f"    Boltzmann active ratio: {boltz['active_ratio']*100:.1f}% (target: ~70%)")
    print(f"    Effective I: {boltz['I_effective']:.3f} (Golden Zone: 0.213~0.500)")
    print(f"    Expert equality: σ={boltz['usage_std']:.4f} (lower is more equal)")

    # Compare with our model predictions
    D = 0.5  # Dropout
    P = 0.85  # Training coefficient
    I = boltz['I_effective']
    G = D * P / max(I, 0.01)

    print(f"\n  Our Model Score:")
    print(f"    G = D×P/I = {D}×{P}/{I:.3f} = {G:.2f}")
    print(f"    Golden Zone: {'🎯 In!' if 0.213 <= I <= 0.500 else 'Out'}")
    print()


if __name__ == '__main__':
    main()