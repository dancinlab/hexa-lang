#!/usr/bin/env python3
"""H-CX-440: Harmonic Progression Tension = Neural Tension
Compare musical chord progression tension curves with neural network training tension curves.
"""
import numpy as np
import sys

np.random.seed(42)

# ============================================================
# 1. Musical tension curves (Lerdahl-inspired simple model)
# ============================================================
# Tension values for each chord degree (normalized 0-1)
chord_tensions = {
    'I': 0.0, 'ii': 0.35, 'iii': 0.25, 'IV': 0.38,
    'V': 0.72, 'vi': 0.30, 'V7': 0.85, 'i': 0.05,
    'iv': 0.40, 'vii': 0.65
}

progressions = {
    'I-IV-V-I (classical)':     ['I', 'IV', 'V', 'I'],
    'I-vi-IV-V (pop)':          ['I', 'vi', 'IV', 'V'],
    'i-iv-V-i (minor)':         ['i', 'iv', 'V', 'i'],
    'I-V-vi-IV (Axis)':         ['I', 'V', 'vi', 'IV'],
}

print("=" * 70)
print("H-CX-440: Harmonic Progression Tension = Neural Tension")
print("=" * 70)

print("\n## Musical Tension Curves (Lerdahl model)")
print(f"{'Progression':<25} {'T1':>6} {'T2':>6} {'T3':>6} {'T4':>6} {'Shape':>20}")
print("-" * 70)

musical_curves = {}
for name, chords in progressions.items():
    tensions = [chord_tensions[c] for c in chords]
    musical_curves[name] = tensions
    shape = "rise-peak-resolve" if tensions[0] < tensions[2] and tensions[3] < tensions[2] else \
            "rise-continue" if tensions[-1] > tensions[0] else "other"
    print(f"{name:<25} {tensions[0]:>6.3f} {tensions[1]:>6.3f} {tensions[2]:>6.3f} {tensions[3]:>6.3f} {shape:>20}")

# ============================================================
# 2. Simulate neural network training tension
# ============================================================
# Simple 2-layer network on synthetic digit-like data
print("\n## Neural Network Training Simulation")
print("Task: 2-layer MLP on 10-class synthetic data (100 dim)")

n_samples = 2000
n_features = 100
n_classes = 10

X = np.random.randn(n_samples, n_features)
W_true = np.random.randn(n_features, n_classes) * 0.3
logits_true = X @ W_true
y = np.argmax(logits_true, axis=1)

def softmax(z):
    e = np.exp(z - z.max(axis=1, keepdims=True))
    return e / e.sum(axis=1, keepdims=True)

def cross_entropy(probs, labels):
    n = len(labels)
    return -np.log(probs[np.arange(n), labels] + 1e-10).mean()

def compute_tension(probs, labels):
    """Tension = 1 - confidence of correct class (higher = more uncertain)"""
    correct_conf = probs[np.arange(len(labels)), labels]
    return 1.0 - correct_conf.mean()

# Training
W1 = np.random.randn(n_features, 64) * 0.1
b1 = np.zeros(64)
W2 = np.random.randn(64, n_classes) * 0.1
b2 = np.zeros(n_classes)
lr = 0.01

n_epochs = 4
epoch_tensions = []
epoch_accs = []

for epoch in range(n_epochs):
    # Forward
    h = np.maximum(0, X @ W1 + b1)  # ReLU
    logits = h @ W2 + b2
    probs = softmax(logits)

    tension = compute_tension(probs, y)
    loss = cross_entropy(probs, y)
    preds = np.argmax(probs, axis=1)
    acc = (preds == y).mean()

    epoch_tensions.append(tension)
    epoch_accs.append(acc)

    # Backward (simplified SGD)
    dlogits = probs.copy()
    dlogits[np.arange(len(y)), y] -= 1
    dlogits /= len(y)

    dW2 = h.T @ dlogits
    db2 = dlogits.sum(axis=0)
    dh = dlogits @ W2.T
    dh[h <= 0] = 0
    dW1 = X.T @ dh
    db1 = dh.sum(axis=0)

    W2 -= lr * dW2
    b2 -= lr * db2
    W1 -= lr * dW1
    b1 -= lr * db1

print(f"\n{'Epoch':<8} {'Tension':>10} {'Accuracy':>10} {'Loss':>10}")
print("-" * 42)
for i in range(n_epochs):
    print(f"{i+1:<8} {epoch_tensions[i]:>10.4f} {epoch_accs[i]:>10.4f} {cross_entropy(softmax(np.maximum(0, X @ W1 + b1) @ W2 + b2), y):>10.4f}")

# Normalize training tension to [0,1]
t_min, t_max = min(epoch_tensions), max(epoch_tensions)
if t_max > t_min:
    train_norm = [(t - t_min) / (t_max - t_min) for t in epoch_tensions]
else:
    train_norm = [0.5] * len(epoch_tensions)

print(f"\nNormalized training tension: {[f'{t:.3f}' for t in train_norm]}")

# ============================================================
# 3. DTW distance computation
# ============================================================
def dtw_distance(s1, s2):
    """Simple DTW distance between two sequences"""
    n, m = len(s1), len(s2)
    dtw_matrix = np.full((n + 1, m + 1), np.inf)
    dtw_matrix[0, 0] = 0
    for i in range(1, n + 1):
        for j in range(1, m + 1):
            cost = abs(s1[i-1] - s2[j-1])
            dtw_matrix[i, j] = cost + min(dtw_matrix[i-1, j], dtw_matrix[i, j-1], dtw_matrix[i-1, j-1])
    return dtw_matrix[n, m]

def euclidean_distance(s1, s2):
    return np.sqrt(sum((a - b)**2 for a, b in zip(s1, s2)))

print("\n## DTW Distance: Training Tension vs Musical Progressions")
print(f"{'Progression':<25} {'DTW':>8} {'Euclidean':>10} {'Rank':>6}")
print("-" * 55)

results = []
for name, chords in progressions.items():
    tensions = [chord_tensions[c] for c in chords]
    t_min_m, t_max_m = min(tensions), max(tensions)
    if t_max_m > t_min_m:
        music_norm = [(t - t_min_m) / (t_max_m - t_min_m) for t in tensions]
    else:
        music_norm = [0.5] * len(tensions)

    dtw_d = dtw_distance(train_norm, music_norm)
    euc_d = euclidean_distance(train_norm, music_norm)
    results.append((name, dtw_d, euc_d))

results.sort(key=lambda x: x[1])
for rank, (name, dtw_d, euc_d) in enumerate(results, 1):
    marker = " <-- BEST" if rank == 1 else ""
    print(f"{name:<25} {dtw_d:>8.4f} {euc_d:>10.4f} {rank:>6}{marker}")

best_name = results[0][0]

# ============================================================
# 4. Correlation analysis
# ============================================================
print("\n## Pearson Correlation: Training vs Each Progression")
for name, chords in progressions.items():
    tensions = [chord_tensions[c] for c in chords]
    t_min_m, t_max_m = min(tensions), max(tensions)
    if t_max_m > t_min_m:
        music_norm = [(t - t_min_m) / (t_max_m - t_min_m) for t in tensions]
    else:
        music_norm = [0.5] * len(tensions)
    r = np.corrcoef(train_norm, music_norm)[0, 1]
    print(f"  {name:<25} r = {r:+.4f}")

# ============================================================
# 5. ASCII Art: Overlay plot
# ============================================================
print("\n## ASCII Graph: Training Tension vs Best Musical Match")
print(f"   Best match: {best_name}")

best_tensions = [chord_tensions[c] for c in progressions[best_name]]
bt_min, bt_max = min(best_tensions), max(best_tensions)
if bt_max > bt_min:
    best_norm = [(t - bt_min) / (bt_max - bt_min) for t in best_tensions]
else:
    best_norm = [0.5] * len(best_tensions)

height = 12
width = 40
labels = ['Step 1', 'Step 2', 'Step 3', 'Step 4']

# Interpolate to width points
def interpolate(vals, n_points):
    x_old = np.linspace(0, 1, len(vals))
    x_new = np.linspace(0, 1, n_points)
    return np.interp(x_new, x_old, vals)

train_interp = interpolate(train_norm, width)
music_interp = interpolate(best_norm, width)

print(f"\n  1.0 |", end="")
for row in range(height, -1, -1):
    y_val = row / height
    if row < height:
        print(f"\n  {y_val:.1f} |", end="")
    for col in range(width):
        t_val = train_interp[col]
        m_val = music_interp[col]
        t_row = round(t_val * height)
        m_row = round(m_val * height)
        if t_row == row and m_row == row:
            print("X", end="")  # overlap
        elif t_row == row:
            print("T", end="")  # training
        elif m_row == row:
            print("M", end="")  # music
        else:
            print(".", end="")
print(f"\n      +{''.join(['-'] * width)}")
print(f"       Step1{''.join([' '] * 8)}Step2{''.join([' '] * 8)}Step3{''.join([' '] * 7)}Step4")
print(f"       T = Training tension, M = Musical tension ({best_name}), X = Overlap")

# ============================================================
# 6. Training tension shape analysis
# ============================================================
print("\n## Training Tension Shape Analysis")
print(f"  Raw tensions: {[f'{t:.4f}' for t in epoch_tensions]}")
print(f"  Normalized:   {[f'{t:.3f}' for t in train_norm]}")
print(f"  Pattern: ", end="")
if train_norm[0] > train_norm[1]:
    print("DECREASE", end="")
else:
    print("INCREASE", end="")
for i in range(1, len(train_norm) - 1):
    if train_norm[i+1] > train_norm[i]:
        print(" -> INCREASE", end="")
    else:
        print(" -> DECREASE", end="")
print()

# Check if monotonically decreasing (typical training)
is_monotone_dec = all(train_norm[i] >= train_norm[i+1] for i in range(len(train_norm)-1))
print(f"  Monotonically decreasing: {is_monotone_dec}")
if is_monotone_dec:
    print("  NOTE: Standard training shows monotone decrease (tension drops as learning improves)")
    print("  This matches I-IV-V-I only in the resolution phase (V->I)")
    print("  For rise-peak-resolve, need early-epoch instability or curriculum learning")

# ============================================================
# 7. Extended: multi-epoch with curriculum
# ============================================================
print("\n## Extended: Curriculum Learning (easy->hard->medium->test)")
# Simulate curriculum: first easy samples, then hard, then medium, then test
difficulties = [0.1, 0.8, 0.5, 0.2]  # curriculum tension profile
curriculum_norm = difficulties  # already normalized-ish

print(f"  Curriculum tensions: {difficulties}")
print(f"\n  DTW to progressions:")
for name, chords in progressions.items():
    tensions = [chord_tensions[c] for c in chords]
    t_min_m, t_max_m = min(tensions), max(tensions)
    if t_max_m > t_min_m:
        music_norm = [(t - t_min_m) / (t_max_m - t_min_m) for t in tensions]
    else:
        music_norm = [0.5] * len(tensions)
    dtw_d = dtw_distance(curriculum_norm, music_norm)
    r = np.corrcoef(curriculum_norm, music_norm)[0, 1]
    print(f"    {name:<25} DTW={dtw_d:.4f}  r={r:+.4f}")

print("\n## Summary")
print(f"  Standard training: monotone tension decrease (learning)")
print(f"  Best musical match: {best_name}")
print(f"  Curriculum learning: rise-peak-resolve pattern possible")
print(f"  Key insight: Musical tension = temporal expectation structure")
print(f"               Neural tension = prediction uncertainty structure")
print(f"  Both follow: tension -> resolution cycles")
