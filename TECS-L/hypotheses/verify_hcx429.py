#!/usr/bin/env python3
"""H-CX-429: Tension = Morphism Complexity Verification

Verify that tension correlates with input transformation complexity:
  - Clean inputs -> low tension
  - Noisy/adversarial inputs -> high tension
  - Jacobian norm correlates with tension
"""
import numpy as np
from sklearn.datasets import load_digits
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split

np.random.seed(42)

# ── PureField model (same as H-CX-428) ──
class PureFieldNumpy:
    def __init__(self, input_dim, hidden_dim, output_dim):
        s = 0.1
        self.Wa1 = np.random.randn(input_dim, hidden_dim) * s
        self.ba1 = np.zeros(hidden_dim)
        self.Wa2 = np.random.randn(hidden_dim, output_dim) * s
        self.ba2 = np.zeros(output_dim)
        self.Wg1 = np.random.randn(input_dim, hidden_dim) * s
        self.bg1 = np.zeros(hidden_dim)
        self.Wg2 = np.random.randn(hidden_dim, output_dim) * s
        self.bg2 = np.zeros(output_dim)

    def engine_a(self, x):
        h = np.maximum(0, x @ self.Wa1 + self.ba1)
        return h @ self.Wa2 + self.ba2

    def engine_g(self, x):
        h = np.maximum(0, x @ self.Wg1 + self.bg1)
        return h @ self.Wg2 + self.bg2

    def forward(self, x):
        out_a = self.engine_a(x)
        out_g = self.engine_g(x)
        output = out_a - out_g
        tension = np.mean(output ** 2, axis=-1)
        return output, tension

    def train_sgd(self, X, y, epochs=50, lr=0.01):
        n_classes = len(np.unique(y))
        for epoch in range(epochs):
            output, tension = self.forward(X)
            exp_out = np.exp(output - output.max(axis=1, keepdims=True))
            probs = exp_out / exp_out.sum(axis=1, keepdims=True)
            n = len(y)
            grad = probs.copy()
            grad[np.arange(n), y] -= 1
            grad /= n
            h_a = np.maximum(0, X @ self.Wa1 + self.ba1)
            self.Wa2 -= lr * h_a.T @ grad
            self.ba2 -= lr * grad.sum(axis=0)
            h_g = np.maximum(0, X @ self.Wg1 + self.bg1)
            self.Wg2 -= lr * (-h_g.T @ grad)
            self.bg2 -= lr * (-grad.sum(axis=0))

    def jacobian(self, x_single):
        """Compute Jacobian of output w.r.t. input for a single sample."""
        # output = A(x) - G(x)
        # J_output = J_A - J_G
        # For ReLU network: J = W2 @ diag(relu_mask) @ W1
        h_a_pre = x_single @ self.Wa1 + self.ba1
        mask_a = (h_a_pre > 0).astype(float)
        J_a = self.Wa2.T @ np.diag(mask_a) @ self.Wa1.T  # (output, input)

        h_g_pre = x_single @ self.Wg1 + self.bg1
        mask_g = (h_g_pre > 0).astype(float)
        J_g = self.Wg2.T @ np.diag(mask_g) @ self.Wg1.T

        J = J_a - J_g  # (output_dim, input_dim)
        return J


# ── Load data ──
digits = load_digits()
X, y = digits.data, digits.target
scaler = StandardScaler()
X = scaler.fit_transform(X)
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.3, random_state=42)

# ── Train model ──
model = PureFieldNumpy(64, 32, 10)
model.train_sgd(X_train, y_train, epochs=80, lr=0.01)

# ── Define morphism complexity levels ──
noise_levels = [0.0, 0.1, 0.3, 0.5, 1.0, 2.0, 3.0, 5.0]
X_sample = X_test[:100]

print("="*60)
print("  EXPERIMENT: H-CX-429 Tension = Morphism Complexity")
print("="*60)

# ── Experiment 1: Noise level vs Tension ──
print("\n  [1] Noise level (morphism complexity) vs Tension")
print(f"  {'Noise':>8} {'Mean Tension':>14} {'Std Tension':>12} {'Accuracy':>10}")
print(f"  {'-'*48}")

noise_tensions = []
noise_accs = []
for noise in noise_levels:
    X_noisy = X_sample + np.random.randn(*X_sample.shape) * noise
    out, tension = model.forward(X_noisy)
    pred = np.argmax(out, axis=1)
    acc = np.mean(pred == y_test[:100])
    mean_t = np.mean(tension)
    std_t = np.std(tension)
    noise_tensions.append(mean_t)
    noise_accs.append(acc)
    print(f"  {noise:>8.1f} {mean_t:>14.4f} {std_t:>12.4f} {acc:>10.2%}")

# Correlation
from numpy import corrcoef
corr_noise_tension = corrcoef(noise_levels, noise_tensions)[0, 1]
print(f"\n  Correlation(noise, tension) = {corr_noise_tension:.4f}")

# ── ASCII graph: Noise vs Tension ──
print(f"\n{'='*60}")
print(f"  ASCII: Noise level vs Mean Tension")
print(f"{'='*60}")
max_t = max(noise_tensions)
for i, noise in enumerate(noise_levels):
    bar_len = int(noise_tensions[i] / max_t * 40)
    print(f"  {noise:>4.1f} |{'#' * bar_len}{' ' * (40-bar_len)}| {noise_tensions[i]:.2f}")

# ── Experiment 2: Jacobian norm vs Tension ──
print(f"\n{'='*60}")
print(f"  [2] Jacobian norm vs Tension (per sample)")
print(f"{'='*60}")

n_jac_samples = 50
jac_norms = []
sample_tensions = []

for i in range(n_jac_samples):
    x_i = X_sample[i:i+1]
    J = model.jacobian(x_i.flatten())
    jac_norm = np.linalg.norm(J, 'fro')
    _, tension_i = model.forward(x_i)
    jac_norms.append(jac_norm)
    sample_tensions.append(tension_i[0])

corr_jac_tension = corrcoef(jac_norms, sample_tensions)[0, 1]
print(f"\n  Jacobian-Tension correlation: {corr_jac_tension:.4f}")
print(f"  Jacobian norm: mean={np.mean(jac_norms):.4f}, std={np.std(jac_norms):.4f}")
print(f"  Tension:       mean={np.mean(sample_tensions):.4f}, std={np.std(sample_tensions):.4f}")

# Bin Jacobian norms and show tension per bin
print(f"\n  Jacobian norm bins vs average tension:")
jac_arr = np.array(jac_norms)
tens_arr = np.array(sample_tensions)
percentiles = [0, 25, 50, 75, 100]
print(f"  {'Jac Norm Range':<25} {'Avg Tension':>12} {'Count':>8}")
print(f"  {'-'*48}")
for p in range(len(percentiles)-1):
    lo = np.percentile(jac_arr, percentiles[p])
    hi = np.percentile(jac_arr, percentiles[p+1])
    mask = (jac_arr >= lo) & (jac_arr <= hi)
    if mask.sum() > 0:
        avg_t = np.mean(tens_arr[mask])
        print(f"  [{lo:>6.2f}, {hi:>6.2f}]{' '*(12-1)} {avg_t:>12.4f} {mask.sum():>8}")

# ── Experiment 3: Per-class tension (digit difficulty) ──
print(f"\n{'='*60}")
print(f"  [3] Per-class tension (digit difficulty as morphism complexity)")
print(f"{'='*60}")

out_full, tension_full = model.forward(X_test)
pred_full = np.argmax(out_full, axis=1)

print(f"  {'Class':>6} {'Mean Tension':>14} {'Accuracy':>10} {'Complexity':>12}")
print(f"  {'-'*46}")
class_tensions = []
class_accs = []
for c in range(10):
    mask = y_test == c
    if mask.sum() > 0:
        mt = np.mean(tension_full[mask])
        ac = np.mean(pred_full[mask] == c)
        class_tensions.append(mt)
        class_accs.append(ac)
        # complexity = inverse accuracy (harder = more complex morphism)
        complexity = 1.0 / (ac + 0.01)
        print(f"  {c:>6} {mt:>14.4f} {ac:>10.2%} {complexity:>12.2f}")

corr_class = corrcoef(class_tensions, class_accs)[0, 1]
print(f"\n  Correlation(class_tension, class_accuracy) = {corr_class:.4f}")

# ── ASCII graph: Per-class tension ──
print(f"\n  ASCII: Per-class tension bars")
max_ct = max(class_tensions)
for c in range(10):
    bar_len = int(class_tensions[c] / max_ct * 35)
    print(f"  digit {c} |{'#' * bar_len}{' ' * (35-bar_len)}| {class_tensions[c]:.2f}")

# ── Summary ──
print(f"\n{'='*60}")
print(f"  SUMMARY")
print(f"{'='*60}")
print(f"  Noise-Tension correlation:    {corr_noise_tension:>8.4f} (expected > 0)")
print(f"  Jacobian-Tension correlation: {corr_jac_tension:>8.4f} (expected > 0)")
print(f"  Class tension-accuracy corr:  {corr_class:>8.4f} (expected < 0)")

confirmed = 0
if corr_noise_tension > 0.5:
    confirmed += 1
    print(f"  [CONFIRMED] Noise positively correlates with tension")
else:
    print(f"  [WEAK/FAIL] Noise-tension correlation below 0.5")

if corr_jac_tension > 0.3:
    confirmed += 1
    print(f"  [CONFIRMED] Jacobian norm positively correlates with tension")
else:
    print(f"  [WEAK/FAIL] Jacobian-tension correlation below 0.3")

if corr_class < -0.3:
    confirmed += 1
    print(f"  [CONFIRMED] High tension classes have lower accuracy")
else:
    print(f"  [WEAK/FAIL] Class tension-accuracy not strongly negative")

print(f"\n  Verdict: {confirmed}/3 predictions confirmed")
print("\n  DONE.")
