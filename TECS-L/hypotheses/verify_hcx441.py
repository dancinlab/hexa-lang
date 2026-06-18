#!/usr/bin/env python3
"""H-CX-441: Dissonance = Inter-tension
Musical dissonance (complex frequency ratios) maps to inter-tension between engines.
"""
import numpy as np
from math import gcd

np.random.seed(42)

print("=" * 70)
print("H-CX-441: Dissonance = Inter-tension")
print("=" * 70)

# ============================================================
# 1. Musical intervals and dissonance measures
# ============================================================
intervals = [
    ("Unison",       1, 1),
    ("Octave",       2, 1),
    ("Perfect 5th",  3, 2),
    ("Perfect 4th",  4, 3),
    ("Major 6th",    5, 3),
    ("Major 3rd",    5, 4),
    ("Minor 3rd",    6, 5),
    ("Minor 7th",    9, 5),
    ("Major 2nd",    9, 8),
    ("Minor 2nd",   16, 15),
    ("Tritone",     45, 32),
]

def euler_gradus(a, b):
    """Euler's gradus suavitatis variant: D = a*b / gcd(a,b)^2"""
    g = gcd(a, b)
    return (a * b) / (g * g)

def plomp_levelt(a, b):
    """Simplified Plomp-Levelt roughness: based on ratio complexity"""
    ratio = a / b
    # Critical bandwidth roughness approximation
    return (a + b) / (2 * gcd(a, b))

print("\n## Musical Interval Dissonance Measures")
print(f"{'Interval':<15} {'Ratio':>7} {'Euler D':>10} {'P-L':>8} {'ln(a/b)':>10} {'GZ?':>5}")
print("-" * 60)

gz_width = np.log(4/3)
for name, a, b in intervals:
    ed = euler_gradus(a, b)
    pl = plomp_levelt(a, b)
    ln_ratio = np.log(a / b)
    in_gz = abs(ln_ratio - gz_width) < 0.05 or abs(ln_ratio) < 0.01
    marker = " ***" if name == "Perfect 4th" else ""
    print(f"{name:<15} {a}:{b:>3}   {ed:>10.2f} {pl:>8.2f} {ln_ratio:>10.4f} {'YES' if in_gz else 'no':>5}{marker}")

print(f"\n  ln(4/3) = {gz_width:.4f} (Golden Zone width)")
print(f"  Perfect 4th ratio 4:3 -> ln(4/3) = {np.log(4/3):.4f} = Golden Zone width EXACTLY")

# ============================================================
# 2. Train two networks on different data subsets
# ============================================================
print("\n## Two-Network Experiment")
n_samples = 1500
n_features = 50
n_classes = 5

X = np.random.randn(n_samples, n_features)
W_true = np.random.randn(n_features, n_classes) * 0.5
y = np.argmax(X @ W_true, axis=1)

# Split data: net1 gets even-indexed, net2 gets odd-indexed
X1, y1 = X[::2], y[::2]
X2, y2 = X[1::2], y[1::2]

# Test set
X_test = np.random.randn(500, n_features)
y_test = np.argmax(X_test @ W_true, axis=1)

def softmax(z):
    e = np.exp(z - z.max(axis=1, keepdims=True))
    return e / e.sum(axis=1, keepdims=True)

def train_network(X_tr, y_tr, n_epochs=30):
    W = np.random.randn(n_features, n_classes) * 0.1
    b = np.zeros(n_classes)
    lr = 0.05
    for _ in range(n_epochs):
        logits = X_tr @ W + b
        probs = softmax(logits)
        dlogits = probs.copy()
        dlogits[np.arange(len(y_tr)), y_tr] -= 1
        dlogits /= len(y_tr)
        W -= lr * (X_tr.T @ dlogits)
        b -= lr * dlogits.sum(axis=0)
    return W, b

W1, b1 = train_network(X1, y1)
W2, b2 = train_network(X2, y2)

# Individual accuracies
probs1 = softmax(X_test @ W1 + b1)
probs2 = softmax(X_test @ W2 + b2)
acc1 = (np.argmax(probs1, axis=1) == y_test).mean()
acc2 = (np.argmax(probs2, axis=1) == y_test).mean()
print(f"  Net1 accuracy: {acc1:.4f}")
print(f"  Net2 accuracy: {acc2:.4f}")

# ============================================================
# 3. Mix predictions at musical interval ratios
# ============================================================
mixing_ratios = [
    ("1:1 (Unison)",     1/2),
    ("2:1 (Octave)",     2/3),
    ("3:2 (Perf 5th)",   3/5),
    ("4:3 (Perf 4th)",   4/7),
    ("5:4 (Maj 3rd)",    5/9),
    ("5:3 (Maj 6th)",    5/8),
    ("6:5 (Min 3rd)",    6/11),
    ("9:8 (Maj 2nd)",    9/17),
    ("16:15 (Min 2nd)", 16/31),
    # Also test simple fractions
    ("1/4",              1/4),
    ("1/3",              1/3),
    ("1/e",              1/np.e),
    ("3/4",              3/4),
    ("ln(4/3)",          np.log(4/3)),
]

def compute_inter_tension(probs_mixed, probs_a, probs_b):
    """Inter-tension: disagreement between mixed output and individual outputs"""
    kl_a = np.sum(probs_mixed * np.log((probs_mixed + 1e-10) / (probs_a + 1e-10)), axis=1).mean()
    kl_b = np.sum(probs_mixed * np.log((probs_mixed + 1e-10) / (probs_b + 1e-10)), axis=1).mean()
    return (kl_a + kl_b) / 2

def compute_tension(probs, labels):
    return 1.0 - probs[np.arange(len(labels)), labels].mean()

print(f"\n## Mixing Ratio vs Inter-tension & Accuracy")
print(f"{'Ratio':<20} {'alpha':>7} {'Accuracy':>10} {'Tension':>10} {'Inter-T':>10} {'Euler D':>10}")
print("-" * 72)

mix_results = []
for name, alpha in mixing_ratios:
    mixed_probs = alpha * probs1 + (1 - alpha) * probs2
    acc = (np.argmax(mixed_probs, axis=1) == y_test).mean()
    tension = compute_tension(mixed_probs, y_test)
    inter_t = compute_inter_tension(mixed_probs, probs1, probs2)

    # Euler dissonance for the ratio
    # Convert alpha to a:b ratio
    if alpha > 0 and alpha < 1:
        # Find closest simple fraction
        best_a, best_b = 1, 1
        min_err = 999
        for a in range(1, 20):
            for b in range(1, 20):
                if abs(a/(a+b) - alpha) < min_err:
                    min_err = abs(a/(a+b) - alpha)
                    best_a, best_b = a, b
        ed = euler_gradus(best_a, best_b)
    else:
        ed = 0

    mix_results.append((name, alpha, acc, tension, inter_t, ed))
    print(f"{name:<20} {alpha:>7.4f} {acc:>10.4f} {tension:>10.4f} {inter_t:>10.6f} {ed:>10.2f}")

# ============================================================
# 4. Find optimal mixing ratio
# ============================================================
best_by_acc = max(mix_results, key=lambda x: x[2])
best_by_tension = min(mix_results, key=lambda x: x[3])
best_by_inter = min(mix_results, key=lambda x: x[4])

print(f"\n## Optimal Mixing Points")
print(f"  Best accuracy:     {best_by_acc[0]:<20} alpha={best_by_acc[1]:.4f} acc={best_by_acc[2]:.4f}")
print(f"  Lowest tension:    {best_by_tension[0]:<20} alpha={best_by_tension[1]:.4f} T={best_by_tension[3]:.4f}")
print(f"  Lowest inter-T:    {best_by_inter[0]:<20} alpha={best_by_inter[1]:.4f} IT={best_by_inter[4]:.6f}")

# ============================================================
# 5. Correlation: Euler dissonance vs inter-tension
# ============================================================
euler_vals = [r[5] for r in mix_results if r[5] > 0]
inter_vals = [r[4] for r in mix_results if r[5] > 0]
if len(euler_vals) > 2:
    r_corr = np.corrcoef(euler_vals, inter_vals)[0, 1]
    print(f"\n## Correlation: Euler Dissonance vs Inter-tension")
    print(f"  Pearson r = {r_corr:+.4f}")
    print(f"  {'Positive correlation: dissonance ~ inter-tension (SUPPORTS hypothesis)' if r_corr > 0.2 else ''}")
    print(f"  {'Negative correlation: consonance ~ inter-tension (CONTRADICTS hypothesis)' if r_corr < -0.2 else ''}")
    print(f"  {'Weak/no correlation (INCONCLUSIVE)' if abs(r_corr) <= 0.2 else ''}")

# ============================================================
# 6. ASCII Graph: mixing ratio vs inter-tension
# ============================================================
print("\n## ASCII Graph: Mixing Ratio vs Inter-tension")
sorted_results = sorted(mix_results, key=lambda x: x[1])

# Normalize inter-tension for display
it_vals = [r[4] for r in sorted_results]
it_min, it_max = min(it_vals), max(it_vals)

height = 15
width = len(sorted_results)

# Mark consonant intervals
consonant_names = {"1:1 (Unison)", "2:1 (Octave)", "3:2 (Perf 5th)", "4:3 (Perf 4th)", "5:4 (Maj 3rd)"}

print(f"\n  Inter-T")
for row in range(height, -1, -1):
    y_val = it_min + (it_max - it_min) * row / height
    print(f"  {y_val:.4f} |", end="")
    for i, r in enumerate(sorted_results):
        it_norm = (r[4] - it_min) / (it_max - it_min) if it_max > it_min else 0.5
        bar_height = round(it_norm * height)
        if bar_height == row:
            if r[0] in consonant_names:
                print(" C ", end="")
            elif "ln(4/3)" in r[0]:
                print(" G ", end="")
            else:
                print(" * ", end="")
        elif bar_height > row:
            print(" | ", end="")
        else:
            print("   ", end="")
    print()

print(f"          +{'---' * len(sorted_results)}")
print(f"   alpha:  ", end="")
for r in sorted_results:
    print(f"{r[1]:.1f}", end=" ")
print()
print(f"   C = Consonant interval, G = Golden Zone (ln(4/3)), * = Other")

# ============================================================
# 7. Special test: alpha = 3/4 (Perfect 4th complement)
# ============================================================
print("\n## Special Test: alpha = 3/4 and ln(4/3)")
special_alphas = [3/4, np.log(4/3), 1/np.e, 1/2, 1/3]
for alpha in special_alphas:
    mixed = alpha * probs1 + (1 - alpha) * probs2
    acc = (np.argmax(mixed, axis=1) == y_test).mean()
    tension = compute_tension(mixed, y_test)
    inter_t = compute_inter_tension(mixed, probs1, probs2)
    print(f"  alpha={alpha:.4f}: acc={acc:.4f}, tension={tension:.4f}, inter-T={inter_t:.6f}")

print(f"\n  ln(4/3) = {np.log(4/3):.4f} (Golden Zone width)")
print(f"  1/e     = {1/np.e:.4f} (Golden Zone center)")

# ============================================================
# 8. Fine-grained scan around ln(4/3)
# ============================================================
print("\n## Fine Scan: alpha around ln(4/3) = 0.2877")
scan_alphas = np.linspace(0.15, 0.45, 31)
scan_results = []
for alpha in scan_alphas:
    mixed = alpha * probs1 + (1 - alpha) * probs2
    acc = (np.argmax(mixed, axis=1) == y_test).mean()
    inter_t = compute_inter_tension(mixed, probs1, probs2)
    scan_results.append((alpha, acc, inter_t))

print(f"{'alpha':>8} {'Accuracy':>10} {'Inter-T':>10}")
print("-" * 30)
for alpha, acc, it in scan_results[::3]:  # every 3rd
    marker = " <-- ln(4/3)" if abs(alpha - np.log(4/3)) < 0.015 else \
             " <-- 1/e" if abs(alpha - 1/np.e) < 0.015 else \
             " <-- 1/3" if abs(alpha - 1/3) < 0.015 else ""
    print(f"{alpha:>8.4f} {acc:>10.4f} {it:>10.6f}{marker}")

# Find minimum inter-tension in scan
best_scan = min(scan_results, key=lambda x: x[2])
print(f"\n  Minimum inter-tension at alpha = {best_scan[0]:.4f} (inter-T = {best_scan[2]:.6f})")
print(f"  Distance from ln(4/3) = {abs(best_scan[0] - np.log(4/3)):.4f}")
print(f"  Distance from 1/e     = {abs(best_scan[0] - 1/np.e):.4f}")
print(f"  Distance from 1/3     = {abs(best_scan[0] - 1/3):.4f}")

print("\n## Summary")
print(f"  Dissonance measure: Euler gradus D(a:b) = a*b/gcd(a,b)^2")
print(f"  Key finding: Perfect 4th (4:3) -> ln(4/3) = Golden Zone width")
print(f"  Inter-tension behavior at consonant vs dissonant ratios analyzed")
print(f"  Correlation Euler D vs Inter-T: r = {r_corr:+.4f}" if 'r_corr' in dir() else "")
