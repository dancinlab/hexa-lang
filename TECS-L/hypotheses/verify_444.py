#!/usr/bin/env python3
"""H-CX-444: Complete Graph K6 and Neural Architecture verification"""
import numpy as np
from sklearn.datasets import load_digits
from sklearn.neural_network import MLPClassifier
from sklearn.model_selection import train_test_split
import warnings
warnings.filterwarnings('ignore')

print("=" * 70)
print("H-CX-444: Complete Graph K6 and Neural Architecture")
print("=" * 70)
print()

# Part 1: K_n graph properties
print("PART 1: Complete Graph K_n Properties")
print("-" * 60)
print(f"{'n':>4} {'Edges':>8} {'chi':>6} {'Genus':>7} {'Aut':>12} {'Spec.Gap':>10}")
print("-" * 60)

import math

for n in range(2, 13):
    edges = n * (n - 1) // 2
    chi = n  # chromatic number of K_n
    # Genus of K_n: ceil((n-3)(n-4)/12) for n>=3
    if n >= 3:
        genus = math.ceil((n - 3) * (n - 4) / 12)
    else:
        genus = 0
    aut = math.factorial(n)
    # K_n is n-regular bipartite? No. Eigenvalues of K_n: n-1 (mult 1), -1 (mult n-1)
    # Spectral gap = (n-1) - (-1) = n
    spec_gap = n

    marker = " ◄ n=6 (perfect number)" if n == 6 else ""
    print(f"{n:>4} {edges:>8} {chi:>6} {genus:>7} {aut:>12} {spec_gap:>10}{marker}")

print()

# Special properties of K_6
print("K_6 SPECIAL PROPERTIES")
print("-" * 60)
print(f"  Vertices:        6 = first perfect number")
print(f"  Edges:           15 = C(6,2) = triangular number T(5)")
print(f"  Chromatic:       6 (smallest requiring 6 colors)")
print(f"  Genus:           1 (embeds on torus, not plane)")
print(f"  Automorphisms:   720 = 6!")
print(f"  Eigenvalues:     5 (x1), -1 (x5)")
print(f"  Spectral gap:    6 = perfect number itself")
print(f"  Edge chromatic:  5 (Vizing: Delta or Delta+1, K_6 needs Delta+1=6? No, 5)")
print(f"  Ramsey R(3,3):   6 (K_6 guarantees monochromatic triangle)")
print()

# Divisor function connections
sigma_6 = 1 + 2 + 3 + 6  # = 12
tau_6 = 4  # number of divisors
phi_6 = 2  # Euler totient

print(f"  sigma(6) = {sigma_6}, tau(6) = {tau_6}, phi(6) = {phi_6}")
print(f"  C(6,2) = 15 = sigma(6) + 3 = {sigma_6 + 3}")
print(f"  C(6,2) / phi(6) = {15 / phi_6:.1f}")
print(f"  C(6,2) / tau(6) = {15 / tau_6:.4f}")
print()

# Part 2: Neural network bottleneck experiment
print("PART 2: Neural Network Bottleneck Experiment")
print("-" * 60)

X, y = load_digits(return_X_y=True)
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
X_train = X_train / 16.0
X_test = X_test / 16.0

bottleneck_sizes = [2, 3, 4, 5, 6, 7, 8, 9, 10, 12]
results = []

for bn in bottleneck_sizes:
    accs = []
    compressions = []
    grad_norms = []

    for seed in range(3):  # 3 seeds for stability
        # Architecture: 64 -> 32 -> bn -> 32 -> 10
        mlp = MLPClassifier(
            hidden_layer_sizes=(32, bn, 32),
            max_iter=500,
            random_state=seed,
            learning_rate_init=0.001
        )
        mlp.fit(X_train, y_train)
        acc = mlp.score(X_test, y_test)
        accs.append(acc)

        # Information compression ratio: input_dim / bottleneck
        compression = 64.0 / bn
        compressions.append(compression)

        # Gradient flow: product of weight matrix norms through bottleneck
        w_norms = [np.linalg.norm(w) for w in mlp.coefs_]
        grad_flow = np.prod(w_norms)
        grad_norms.append(grad_flow)

    mean_acc = np.mean(accs)
    std_acc = np.std(accs)
    mean_grad = np.mean(grad_norms)

    # SVD of bottleneck weight matrices
    W_in = mlp.coefs_[1]  # 32 -> bn
    W_out = mlp.coefs_[2]  # bn -> 32

    svd_in = np.linalg.svd(W_in, compute_uv=False)
    svd_out = np.linalg.svd(W_out, compute_uv=False)

    # Effective rank (entropy-based)
    def effective_rank(s):
        s_norm = s / (s.sum() + 1e-10)
        s_norm = s_norm[s_norm > 1e-10]
        entropy = -np.sum(s_norm * np.log(s_norm + 1e-10))
        return np.exp(entropy)

    eff_rank_in = effective_rank(svd_in)
    eff_rank_out = effective_rank(svd_out)

    results.append({
        'bn': bn,
        'acc_mean': mean_acc,
        'acc_std': std_acc,
        'compression': 64.0 / bn,
        'grad_flow': mean_grad,
        'eff_rank_in': eff_rank_in,
        'eff_rank_out': eff_rank_out,
        'svd_ratio': svd_in[0] / (svd_in[-1] + 1e-10) if len(svd_in) > 1 else 0
    })

    print(f"  bn={bn:>2}: acc={mean_acc:.4f}+/-{std_acc:.4f}, compression={64.0/bn:.1f}x, grad_flow={mean_grad:.1f}, eff_rank={eff_rank_in:.2f}/{eff_rank_out:.2f}")

print()

# Summary
print("BOTTLENECK SIZE vs METRICS")
print("-" * 70)
print(f"{'BN':>4} {'Accuracy':>10} {'Compress':>10} {'GradFlow':>10} {'EffRank':>10} {'SVDratio':>10}")
print("-" * 70)

best_acc = max(r['acc_mean'] for r in results)
best_bn = [r['bn'] for r in results if r['acc_mean'] == best_acc][0]

for r in results:
    marker = " ◄ BEST" if r['bn'] == best_bn else ""
    marker2 = " [n=6]" if r['bn'] == 6 else ""
    print(f"{r['bn']:>4} {r['acc_mean']:>10.4f} {r['compression']:>10.1f} {r['grad_flow']:>10.1f} {r['eff_rank_in']:>10.2f} {r['svd_ratio']:>10.1f}{marker}{marker2}")

print()

# Check: is n=6 special?
r6 = [r for r in results if r['bn'] == 6][0]
rank_by_acc = sorted(results, key=lambda x: -x['acc_mean'])
n6_rank = [i for i, r in enumerate(rank_by_acc) if r['bn'] == 6][0] + 1

print(f"n=6 ANALYSIS:")
print(f"  Accuracy rank: {n6_rank}/{len(results)}")
print(f"  Accuracy: {r6['acc_mean']:.4f} (best={best_acc:.4f}, best_bn={best_bn})")
print(f"  Compression ratio: {r6['compression']:.1f}x")
print(f"  tau(6)=4 as depth? Architecture has depth 3 (layers), not 4")
print(f"  phi(6)=2 as width ratio? 32/6 = {32/6:.2f}, not 2")
print()

# Efficiency metric: accuracy per parameter
print("EFFICIENCY: Accuracy per Compression")
print("-" * 50)
for r in results:
    # acc_per_compress = accuracy * compression (higher = better efficiency)
    eff = r['acc_mean'] * r['compression']
    r['efficiency'] = eff
    marker = " ◄" if r['bn'] == 6 else ""
    print(f"  bn={r['bn']:>2}: efficiency = {eff:.2f} (acc={r['acc_mean']:.3f} x compress={r['compression']:.1f}){marker}")

best_eff = max(r['efficiency'] for r in results)
best_eff_bn = [r['bn'] for r in results if r['efficiency'] == best_eff][0]
print(f"\n  Best efficiency: bn={best_eff_bn} ({best_eff:.2f})")
print()

# ASCII Graph: accuracy vs bottleneck size
print("ASCII GRAPH: Bottleneck Size vs Accuracy")
print("-" * 60)

min_acc = min(r['acc_mean'] for r in results)
max_acc = max(r['acc_mean'] for r in results)
chart_width = 45

for r in results:
    if max_acc > min_acc:
        pos = int((r['acc_mean'] - min_acc) / (max_acc - min_acc) * chart_width)
    else:
        pos = chart_width // 2
    bar = '█' * pos + '▏'
    marker = " ◄n=6" if r['bn'] == 6 else ""
    print(f"  bn={r['bn']:>2} {bar} {r['acc_mean']:.4f}{marker}")

print(f"       {'|':>{1}}{' ' * chart_width}{'|'}")
print(f"       {min_acc:.3f}{' ' * (chart_width - 8)}{max_acc:.3f}")

print()

# ASCII Graph: efficiency
print("ASCII GRAPH: Bottleneck Size vs Efficiency (Acc * Compression)")
print("-" * 60)
min_eff = min(r['efficiency'] for r in results)
max_eff = max(r['efficiency'] for r in results)

for r in results:
    if max_eff > min_eff:
        pos = int((r['efficiency'] - min_eff) / (max_eff - min_eff) * chart_width)
    else:
        pos = chart_width // 2
    bar = '█' * pos + '▏'
    marker = " ◄n=6" if r['bn'] == 6 else ""
    print(f"  bn={r['bn']:>2} {bar} {r['efficiency']:.2f}{marker}")

print()

# IB theory connection
print("INFORMATION BOTTLENECK THEORY CONNECTION")
print("-" * 50)
print(f"  IB optimal: minimize I(X;T) while maximizing I(T;Y)")
print(f"  At bn=6: compression = {64/6:.1f}x, accuracy = {r6['acc_mean']:.4f}")
print(f"  Perfect number 6 = 1+2+3: divisors give natural decomposition")
print(f"  K_6 Ramsey property: ANY 2-coloring of K_6 has monochromatic K_3")
print(f"    -> 6-node bottleneck guarantees information triangle?")
print()
print("=" * 70)
print("DONE")
