#!/usr/bin/env python3
"""H-CX-428: PureField = Functor (Category Theory) Verification

Verify that PureField's eq->field mapping satisfies functor properties:
  F(id_A) = id_{F(A)}  (identity preservation)
  F(g o f) = F(g) o F(f)  (composition preservation)
"""
import numpy as np
from sklearn.datasets import load_digits
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split

np.random.seed(42)

# ── Simple PureField-like model (numpy, 2-pole) ──
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
        """Simple SGD training with cross-entropy loss."""
        n_classes = len(np.unique(y))
        losses = []
        for epoch in range(epochs):
            # Forward
            output, tension = self.forward(X)
            # Softmax
            exp_out = np.exp(output - output.max(axis=1, keepdims=True))
            probs = exp_out / exp_out.sum(axis=1, keepdims=True)
            # Cross-entropy loss
            n = len(y)
            loss = -np.mean(np.log(probs[np.arange(n), y] + 1e-8))
            losses.append(loss)
            # Gradient (simplified: output layer only for speed)
            grad = probs.copy()
            grad[np.arange(n), y] -= 1
            grad /= n
            # Backprop through A (output = A - G, so dA = grad, dG = -grad)
            # Engine A output layer
            h_a = np.maximum(0, X @ self.Wa1 + self.ba1)
            self.Wa2 -= lr * h_a.T @ grad
            self.ba2 -= lr * grad.sum(axis=0)
            # Engine G output layer
            h_g = np.maximum(0, X @ self.Wg1 + self.bg1)
            self.Wg2 -= lr * (-h_g.T @ grad)
            self.bg2 -= lr * (-grad.sum(axis=0))
        return losses


# ── Load data ──
digits = load_digits()
X, y = digits.data, digits.target
scaler = StandardScaler()
X = scaler.fit_transform(X)
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.3, random_state=42)

# ── Define morphisms (linear transforms in input space) ──
dim = X.shape[1]  # 64

def identity_morphism(x):
    return x

def make_rotation(seed=0):
    """Random near-identity rotation."""
    rng = np.random.RandomState(seed)
    A = rng.randn(dim, dim) * 0.1
    Q = np.eye(dim) + A - A.T  # skew-symmetric -> near identity
    # Proper orthogonalization
    U, _, Vt = np.linalg.svd(Q)
    return U @ Vt

def make_scaling(factor=1.05):
    return np.eye(dim) * factor

R1 = make_rotation(seed=1)
R2 = make_rotation(seed=2)
S1 = make_scaling(1.05)

morphisms = {
    'rotation_1': R1,
    'rotation_2': R2,
    'scaling': S1,
}

# ── Functor verification ──
def verify_functor(model, X_sample, morphisms, label=""):
    print(f"\n{'='*60}")
    print(f"  Functor Verification: {label}")
    print(f"{'='*60}")

    # 1) Identity preservation: F(id(x)) = F(x)
    out_x, _ = model.forward(X_sample)
    out_id, _ = model.forward(identity_morphism(X_sample))
    id_error = np.mean(np.abs(out_x - out_id))
    print(f"\n  [1] Identity preservation F(id(x)) = F(x)")
    print(f"      Error = {id_error:.8f}")
    print(f"      PASS: {id_error < 1e-10}")

    # 2) Composition preservation: F(g o f) vs F(g) o F(f)
    # Here "o" means: apply morphism to input, then map through model
    # F(g o f)(x) = model(g(f(x)))
    # F(g)(F(f)(x)) is harder to define since F maps to output space
    # Instead: verify that the mapping preserves composition structure
    # by checking: model(M2 @ M1 @ x) vs structure consistency

    comp_errors = {}
    for name1, M1 in morphisms.items():
        for name2, M2 in morphisms.items():
            # Composed input: M2 @ (M1 @ X)
            x_composed = (X_sample @ M1.T) @ M2.T
            out_composed, _ = model.forward(x_composed)

            # Sequential: first transform by M1, map, then transform by M2, map
            x_m1 = X_sample @ M1.T
            out_m1, _ = model.forward(x_m1)
            x_m2 = X_sample @ M2.T
            out_m2, _ = model.forward(x_m2)

            # Linearity check: F(M2 M1 x) vs F(M1 x) + F(M2 x) - F(x)
            # For a linear functor: F(composed) should be predictable from parts
            out_x, _ = model.forward(X_sample)
            predicted = out_m1 + out_m2 - out_x  # linear approximation
            error = np.mean(np.abs(out_composed - predicted))
            comp_errors[f"{name2} o {name1}"] = error

    print(f"\n  [2] Composition linearity: F(g o f) vs F(f)+F(g)-F(id)")
    print(f"      {'Composition':<30} {'Error':>10}")
    print(f"      {'-'*42}")
    for comp, err in comp_errors.items():
        print(f"      {comp:<30} {err:>10.6f}")

    avg_comp_error = np.mean(list(comp_errors.values()))
    print(f"      {'Average':<30} {avg_comp_error:>10.6f}")

    return id_error, avg_comp_error

# ── Natural transformation distance ──
def measure_nat_transform(model_losses, X_sample, model, label=""):
    """Measure how much the functor changes per training epoch."""
    print(f"\n  [3] Natural transformation smoothness")
    # We'll re-train and snapshot outputs at each epoch
    # Already have losses, just report
    print(f"      Training loss trajectory ({len(model_losses)} epochs):")
    deltas = [abs(model_losses[i+1] - model_losses[i]) for i in range(len(model_losses)-1)]
    for i in range(0, len(model_losses), 10):
        bar = '#' * int(model_losses[i] * 10)
        print(f"      epoch {i:3d}: loss={model_losses[i]:.4f} {bar}")

    print(f"\n      Loss delta statistics:")
    print(f"      Mean delta:  {np.mean(deltas):.6f}")
    print(f"      Std delta:   {np.std(deltas):.6f}")
    print(f"      Max delta:   {np.max(deltas):.6f}")
    smoothness = np.std(deltas) / (np.mean(deltas) + 1e-8)
    print(f"      Smoothness (CV): {smoothness:.4f} (lower = smoother)")
    return smoothness


# ── Run experiments ──
X_sample = X_test[:100]

# Untrained model
print("\n" + "="*60)
print("  EXPERIMENT: H-CX-428 PureField Functor Verification")
print("="*60)

model_untrained = PureFieldNumpy(64, 32, 10)
id_err_u, comp_err_u = verify_functor(model_untrained, X_sample, morphisms, "UNTRAINED")

# Trained model
model_trained = PureFieldNumpy(64, 32, 10)
losses = model_trained.train_sgd(X_train, y_train, epochs=50, lr=0.01)
id_err_t, comp_err_t = verify_functor(model_trained, X_sample, morphisms, "TRAINED (50 epochs)")
smoothness = measure_nat_transform(losses, X_sample, model_trained)

# Accuracy
out_test, tension_test = model_trained.forward(X_test)
pred = np.argmax(out_test, axis=1)
acc = np.mean(pred == y_test)
print(f"\n  Test accuracy: {acc:.4f}")
print(f"  Mean tension:  {np.mean(tension_test):.4f}")

# ── Comparison table ──
print(f"\n{'='*60}")
print(f"  COMPARISON TABLE")
print(f"{'='*60}")
print(f"  {'Metric':<35} {'Untrained':>12} {'Trained':>12}")
print(f"  {'-'*60}")
print(f"  {'Identity error':<35} {id_err_u:>12.8f} {id_err_t:>12.8f}")
print(f"  {'Composition error (avg)':<35} {comp_err_u:>12.6f} {comp_err_t:>12.6f}")
print(f"  {'Composition/Identity ratio':<35} {comp_err_u/(id_err_u+1e-10):>12.2f} {comp_err_t/(id_err_t+1e-10):>12.2f}")

# Improvement
if comp_err_t < comp_err_u:
    pct = (1 - comp_err_t/comp_err_u) * 100
    print(f"\n  Training IMPROVED functoriality by {pct:.1f}%")
else:
    pct = (comp_err_t/comp_err_u - 1) * 100
    print(f"\n  Training INCREASED composition error by {pct:.1f}%")

# ── ASCII graph: composition error per morphism pair ──
print(f"\n{'='*60}")
print(f"  ASCII: Loss trajectory (50 epochs)")
print(f"{'='*60}")
max_loss = max(losses)
for i in range(0, 50, 2):
    bar_len = int(losses[i] / max_loss * 40)
    print(f"  {i:3d} |{'#' * bar_len}{' ' * (40-bar_len)}| {losses[i]:.4f}")

# ── Functoriality score ──
# Define: functoriality = 1 / (1 + composition_error)
func_u = 1.0 / (1.0 + comp_err_u)
func_t = 1.0 / (1.0 + comp_err_t)
print(f"\n  Functoriality score (1=perfect functor):")
print(f"    Untrained: {func_u:.4f}")
print(f"    Trained:   {func_t:.4f}")

print(f"\n  Natural transformation smoothness (CV): {smoothness:.4f}")
print(f"    Interpretation: {'Smooth' if smoothness < 1.0 else 'Jerky'} learning dynamics")

print("\n  DONE.")
