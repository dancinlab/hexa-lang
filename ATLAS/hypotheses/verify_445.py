#!/usr/bin/env python3
"""H-CX-445: Spectral Gap = Tension Gap verification"""
import numpy as np
from sklearn.datasets import load_digits
from sklearn.model_selection import train_test_split
import warnings
warnings.filterwarnings('ignore')

print("=" * 70)
print("H-CX-445: Spectral Gap = Tension Gap Correlation")
print("=" * 70)
print()

# Load data
X, y = load_digits(return_X_y=True)
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
X_train = X_train / 16.0
X_test = X_test / 16.0

# Manual MLP with epoch-by-epoch tracking
class SimpleMLP:
    def __init__(self, sizes, lr=0.01):
        self.sizes = sizes
        self.lr = lr
        self.weights = []
        self.biases = []
        # Xavier init
        for i in range(len(sizes) - 1):
            w = np.random.randn(sizes[i], sizes[i+1]) * np.sqrt(2.0 / (sizes[i] + sizes[i+1]))
            b = np.zeros(sizes[i+1])
            self.weights.append(w)
            self.biases.append(b)

    def relu(self, x):
        return np.maximum(0, x)

    def relu_deriv(self, x):
        return (x > 0).astype(float)

    def softmax(self, x):
        e = np.exp(x - x.max(axis=1, keepdims=True))
        return e / (e.sum(axis=1, keepdims=True) + 1e-10)

    def forward(self, X):
        self.activations = [X]
        self.pre_activations = []
        h = X
        for i in range(len(self.weights) - 1):
            z = h @ self.weights[i] + self.biases[i]
            self.pre_activations.append(z)
            h = self.relu(z)
            self.activations.append(h)
        # Output layer
        z = h @ self.weights[-1] + self.biases[-1]
        self.pre_activations.append(z)
        out = self.softmax(z)
        self.activations.append(out)
        return out

    def compute_tension(self, probs):
        """Tension = 1 - max(prob) + entropy_normalized"""
        max_p = np.max(probs, axis=1)
        entropy = -np.sum(probs * np.log(probs + 1e-10), axis=1) / np.log(probs.shape[1])
        tension = (1 - max_p + entropy) / 2
        return tension

    def train_epoch(self, X, y, batch_size=64):
        n = len(X)
        indices = np.random.permutation(n)
        for start in range(0, n, batch_size):
            idx = indices[start:start+batch_size]
            Xb, yb = X[idx], y[idx]

            # Forward
            probs = self.forward(Xb)

            # Backward
            one_hot = np.zeros_like(probs)
            one_hot[np.arange(len(yb)), yb] = 1

            delta = probs - one_hot  # output gradient
            grads_w = []
            grads_b = []

            for i in range(len(self.weights) - 1, -1, -1):
                gw = self.activations[i].T @ delta / len(yb)
                gb = delta.mean(axis=0)
                grads_w.insert(0, gw)
                grads_b.insert(0, gb)

                if i > 0:
                    delta = (delta @ self.weights[i].T) * self.relu_deriv(self.pre_activations[i-1])

            for i in range(len(self.weights)):
                self.weights[i] -= self.lr * grads_w[i]
                self.biases[i] -= self.lr * grads_b[i]

    def predict_proba(self, X):
        return self.forward(X)

    def accuracy(self, X, y):
        probs = self.forward(X)
        return np.mean(np.argmax(probs, axis=1) == y)

# Train with tracking
np.random.seed(42)
mlp = SimpleMLP([64, 128, 64, 10], lr=0.01)

n_epochs = 50
history = []

print("Training and tracking spectral gap + tension gap per epoch...")
print()

for epoch in range(n_epochs):
    mlp.train_epoch(X_train, y_train)

    # Spectral gaps for each layer
    spectral_gaps = []
    for i, W in enumerate(mlp.weights):
        svd = np.linalg.svd(W, compute_uv=False)
        if len(svd) >= 2:
            gap = svd[0] - svd[1]
        else:
            gap = svd[0]
        spectral_gaps.append(gap)

    # Tension per class
    probs_test = mlp.predict_proba(X_test)
    tensions = mlp.compute_tension(probs_test)

    class_tensions = {}
    for c in range(10):
        mask = y_test == c
        if mask.sum() > 0:
            class_tensions[c] = tensions[mask].mean()

    tension_gap = max(class_tensions.values()) - min(class_tensions.values())
    mean_tension = np.mean(tensions)

    acc = mlp.accuracy(X_test, y_test)

    total_spec_gap = sum(spectral_gaps)

    history.append({
        'epoch': epoch + 1,
        'acc': acc,
        'spectral_gaps': spectral_gaps,
        'total_spec_gap': total_spec_gap,
        'tension_gap': tension_gap,
        'mean_tension': mean_tension,
        'class_tensions': class_tensions,
        'max_tension_class': max(class_tensions, key=class_tensions.get),
        'min_tension_class': min(class_tensions, key=class_tensions.get),
    })

    if (epoch + 1) % 10 == 0:
        print(f"  Epoch {epoch+1:>3}: acc={acc:.4f}, spec_gap=[{', '.join(f'{g:.3f}' for g in spectral_gaps)}], "
              f"tension_gap={tension_gap:.4f}, mean_T={mean_tension:.4f}")

print()

# Correlation analysis
spec_gaps_total = np.array([h['total_spec_gap'] for h in history])
tension_gaps = np.array([h['tension_gap'] for h in history])
mean_tensions = np.array([h['mean_tension'] for h in history])
accs = np.array([h['acc'] for h in history])

# Pearson correlation
def pearson_corr(x, y):
    return np.corrcoef(x, y)[0, 1]

corr_spec_tension = pearson_corr(spec_gaps_total, tension_gaps)
corr_spec_meanT = pearson_corr(spec_gaps_total, mean_tensions)
corr_spec_acc = pearson_corr(spec_gaps_total, accs)
corr_tension_acc = pearson_corr(tension_gaps, accs)

print("CORRELATION MATRIX")
print("-" * 60)
print(f"  Spectral Gap  vs  Tension Gap:   r = {corr_spec_tension:+.4f}")
print(f"  Spectral Gap  vs  Mean Tension:  r = {corr_spec_meanT:+.4f}")
print(f"  Spectral Gap  vs  Accuracy:      r = {corr_spec_acc:+.4f}")
print(f"  Tension Gap   vs  Accuracy:      r = {corr_tension_acc:+.4f}")
print()

# Per-layer correlation
print("PER-LAYER SPECTRAL GAP vs TENSION GAP")
print("-" * 60)
n_layers = len(history[0]['spectral_gaps'])
for layer in range(n_layers):
    layer_gaps = np.array([h['spectral_gaps'][layer] for h in history])
    corr = pearson_corr(layer_gaps, tension_gaps)
    corr_acc = pearson_corr(layer_gaps, accs)
    print(f"  Layer {layer}: r(tension_gap)={corr:+.4f}, r(accuracy)={corr_acc:+.4f}")

print()

# Per-class tension at final epoch
final = history[-1]
print("FINAL EPOCH PER-CLASS TENSION")
print("-" * 50)
print(f"{'Class':>6} {'Tension':>10} {'Count':>8}")
print("-" * 30)
for c in range(10):
    mask = y_test == c
    t = final['class_tensions'][c]
    print(f"{c:>6} {t:>10.4f} {mask.sum():>8}")
print(f"  Tension gap = {final['tension_gap']:.4f}")
print(f"  Hardest class: {final['max_tension_class']}")
print(f"  Easiest class: {final['min_tension_class']}")
print()

# Spectral gap connection to Markov mixing time
print("MARKOV CHAIN CONNECTION")
print("-" * 50)
print("  In Markov chains: mixing time ~ 1/spectral_gap")
print("  If spectral_gap increases -> mixing (convergence) faster")
print("  Tension gap should decrease as network 'mixes' information better")
print(f"  Early (epoch 1): spec_gap={history[0]['total_spec_gap']:.4f}, tension_gap={history[0]['tension_gap']:.4f}")
print(f"  Final (epoch {n_epochs}): spec_gap={history[-1]['total_spec_gap']:.4f}, tension_gap={history[-1]['tension_gap']:.4f}")
print(f"  Spec gap trend: {'increasing' if history[-1]['total_spec_gap'] > history[0]['total_spec_gap'] else 'decreasing'}")
print(f"  Tension gap trend: {'increasing' if history[-1]['tension_gap'] > history[0]['tension_gap'] else 'decreasing'}")
print()

# ASCII Dual-axis graph: Epoch vs Spectral Gap and Tension Gap
print("ASCII GRAPH: Epoch vs Spectral Gap (S) and Tension Gap (T)")
print("-" * 65)

chart_height = 20
chart_width = 50
sample_epochs = np.linspace(0, len(history)-1, min(chart_width, len(history)), dtype=int)

# Normalize both to [0, chart_height]
sg_vals = [history[i]['total_spec_gap'] for i in sample_epochs]
tg_vals = [history[i]['tension_gap'] for i in sample_epochs]

sg_min, sg_max = min(sg_vals), max(sg_vals)
tg_min, tg_max = min(tg_vals), max(tg_vals)

def normalize(v, vmin, vmax, height):
    if vmax <= vmin:
        return height // 2
    return int((v - vmin) / (vmax - vmin) * (height - 1))

# Build character grid
grid = [[' ' for _ in range(len(sample_epochs))] for _ in range(chart_height)]

for col, idx in enumerate(sample_epochs):
    sg_row = chart_height - 1 - normalize(history[idx]['total_spec_gap'], sg_min, sg_max, chart_height)
    tg_row = chart_height - 1 - normalize(history[idx]['tension_gap'], tg_min, tg_max, chart_height)

    sg_row = max(0, min(chart_height-1, sg_row))
    tg_row = max(0, min(chart_height-1, tg_row))

    if sg_row == tg_row:
        grid[sg_row][col] = 'X'  # overlap
    else:
        grid[sg_row][col] = 'S'
        grid[tg_row][col] = 'T'

# Print
print(f"  S={sg_max:.2f} T={tg_max:.4f} |")
for row in range(chart_height):
    line = ''.join(grid[row])
    print(f"  {'':>20} |{line}|")
print(f"  S={sg_min:.2f} T={tg_min:.4f} |{'─' * len(sample_epochs)}|")
print(f"  {'':>20}  {'1':>{1}}{' ' * (len(sample_epochs)-4)}{n_epochs}")
print(f"  {'':>20}  S=Spectral Gap, T=Tension Gap, X=Overlap")

print()

# Scatter: spectral gap vs tension gap (ASCII)
print("ASCII SCATTER: Total Spectral Gap vs Tension Gap")
print("-" * 55)
scatter_size = 25
sg_all = [h['total_spec_gap'] for h in history]
tg_all = [h['tension_gap'] for h in history]
sg_range = max(sg_all) - min(sg_all)
tg_range = max(tg_all) - min(tg_all)

scatter_grid = [[' ' for _ in range(scatter_size)] for _ in range(scatter_size)]
for sg, tg in zip(sg_all, tg_all):
    x = int((sg - min(sg_all)) / (sg_range + 1e-10) * (scatter_size - 1))
    y = scatter_size - 1 - int((tg - min(tg_all)) / (tg_range + 1e-10) * (scatter_size - 1))
    x = max(0, min(scatter_size-1, x))
    y = max(0, min(scatter_size-1, y))
    scatter_grid[y][x] = '*'

print(f"  TG={max(tg_all):.4f} |")
for row in range(scatter_size):
    line = ''.join(scatter_grid[row])
    print(f"  {'':>13} |{line}|")
print(f"  TG={min(tg_all):.4f} |{'─' * scatter_size}|")
print(f"  {'':>13}  SG={min(sg_all):.2f}{' ' * (scatter_size-12)}SG={max(sg_all):.2f}")
print(f"  {'':>13}  r = {corr_spec_tension:+.4f}")

print()
print("=" * 70)
print("SUMMARY")
print("-" * 70)
print(f"  Spectral Gap - Tension Gap correlation: r = {corr_spec_tension:+.4f}")
strength = "STRONG" if abs(corr_spec_tension) > 0.7 else "MODERATE" if abs(corr_spec_tension) > 0.4 else "WEAK"
direction = "positive" if corr_spec_tension > 0 else "negative"
print(f"  Strength: {strength} ({direction})")
print(f"  Best correlating layer: Layer {np.argmax([abs(pearson_corr(np.array([h['spectral_gaps'][l] for h in history]), tension_gaps)) for l in range(n_layers)])}")
print()
print("=" * 70)
print("DONE")
