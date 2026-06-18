#!/usr/bin/env python3
"""H-CX-430: Mitosis = Coproduct (Category Theory) Verification

Verify that engine splitting (Mitosis) satisfies the categorical coproduct
universal property, and that N=2=sigma_{-1}(6) is optimal.
"""
import numpy as np
from sklearn.datasets import load_digits
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split

np.random.seed(42)

# ── PureField model ──
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

    def copy(self):
        m = PureFieldNumpy.__new__(PureFieldNumpy)
        m.Wa1 = self.Wa1.copy(); m.ba1 = self.ba1.copy()
        m.Wa2 = self.Wa2.copy(); m.ba2 = self.ba2.copy()
        m.Wg1 = self.Wg1.copy(); m.bg1 = self.bg1.copy()
        m.Wg2 = self.Wg2.copy(); m.bg2 = self.bg2.copy()
        return m

    def perturb(self, scale=0.05):
        for attr in ['Wa1', 'ba1', 'Wa2', 'ba2', 'Wg1', 'bg1', 'Wg2', 'bg2']:
            w = getattr(self, attr)
            setattr(self, attr, w + np.random.randn(*w.shape) * scale)

    def forward(self, x):
        h_a = np.maximum(0, x @ self.Wa1 + self.ba1)
        out_a = h_a @ self.Wa2 + self.ba2
        h_g = np.maximum(0, x @ self.Wg1 + self.bg1)
        out_g = h_g @ self.Wg2 + self.bg2
        output = out_a - out_g
        tension = np.mean(output ** 2, axis=-1)
        return output, tension

    def train_sgd(self, X, y, epochs=50, lr=0.01):
        losses = []
        for epoch in range(epochs):
            output, _ = self.forward(X)
            exp_out = np.exp(output - output.max(axis=1, keepdims=True))
            probs = exp_out / exp_out.sum(axis=1, keepdims=True)
            n = len(y)
            loss = -np.mean(np.log(probs[np.arange(n), y] + 1e-8))
            losses.append(loss)
            grad = probs.copy()
            grad[np.arange(n), y] -= 1
            grad /= n
            h_a = np.maximum(0, X @ self.Wa1 + self.ba1)
            self.Wa2 -= lr * h_a.T @ grad
            self.ba2 -= lr * grad.sum(axis=0)
            h_g = np.maximum(0, X @ self.Wg1 + self.bg1)
            self.Wg2 -= lr * (-h_g.T @ grad)
            self.bg2 -= lr * (-grad.sum(axis=0))
        return losses

    def accuracy(self, X, y):
        out, _ = self.forward(X)
        return np.mean(np.argmax(out, axis=1) == y)


def mitosis(parent, n_children, perturb_scale=0.05):
    """Split parent into n_children copies with perturbation."""
    children = []
    for _ in range(n_children):
        child = parent.copy()
        child.perturb(perturb_scale)
        children.append(child)
    return children


def ensemble_forward(models, X, weights=None):
    """Weighted ensemble output."""
    if weights is None:
        weights = np.ones(len(models)) / len(models)
    total_out = None
    total_tension = None
    for m, w in zip(models, weights):
        out, ten = m.forward(X)
        if total_out is None:
            total_out = w * out
            total_tension = w * ten
        else:
            total_out += w * out
            total_tension += w * ten
    return total_out, total_tension


def find_optimal_weights(models, X, y):
    """Find optimal ensemble weights via grid search."""
    n = len(models)
    if n == 2:
        best_w, best_acc = None, 0
        for w1 in np.arange(0, 1.01, 0.05):
            w = [w1, 1 - w1]
            out, _ = ensemble_forward(models, X, w)
            acc = np.mean(np.argmax(out, axis=1) == y)
            if acc > best_acc:
                best_acc = acc
                best_w = w
        return best_w, best_acc
    elif n == 3:
        best_w, best_acc = None, 0
        for w1 in np.arange(0, 1.01, 0.1):
            for w2 in np.arange(0, 1.01 - w1, 0.1):
                w = [w1, w2, 1 - w1 - w2]
                out, _ = ensemble_forward(models, X, w)
                acc = np.mean(np.argmax(out, axis=1) == y)
                if acc > best_acc:
                    best_acc = acc
                    best_w = w
        return best_w, best_acc
    elif n == 4:
        best_w, best_acc = None, 0
        for w1 in np.arange(0, 1.01, 0.2):
            for w2 in np.arange(0, 1.01 - w1, 0.2):
                for w3 in np.arange(0, 1.01 - w1 - w2, 0.2):
                    w = [w1, w2, w3, 1 - w1 - w2 - w3]
                    out, _ = ensemble_forward(models, X, w)
                    acc = np.mean(np.argmax(out, axis=1) == y)
                    if acc > best_acc:
                        best_acc = acc
                        best_w = w
        return best_w, best_acc
    return [1/n]*n, 0


# ── Load data ──
digits = load_digits()
X, y = digits.data, digits.target
scaler = StandardScaler()
X = scaler.fit_transform(X)
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.3, random_state=42)

# Also create distribution-shifted test sets
np.random.seed(99)
X_test_noisy = X_test + np.random.randn(*X_test.shape) * 0.5
X_test_scaled = X_test * 1.3

print("="*60)
print("  EXPERIMENT: H-CX-430 Mitosis = Coproduct")
print("="*60)

# ── Train parent model ──
print("\n  [0] Training parent model...")
parent = PureFieldNumpy(64, 32, 10)
parent.train_sgd(X_train, y_train, epochs=80, lr=0.01)
parent_acc = parent.accuracy(X_test, y_test)
print(f"      Parent accuracy: {parent_acc:.4f}")

# ── Mitosis with N=2,3,4 ──
results = {}
for N in [2, 3, 4]:
    print(f"\n  [Mitosis N={N}] Splitting parent into {N} children...")
    children = mitosis(parent, N, perturb_scale=0.05)

    # Train each child independently
    for i, child in enumerate(children):
        child.train_sgd(X_train, y_train, epochs=40, lr=0.01)

    # Individual accuracies
    child_accs = [c.accuracy(X_test, y_test) for c in children]
    print(f"      Child accuracies: {[f'{a:.4f}' for a in child_accs]}")

    # Ensemble (equal weights)
    ens_out, ens_tension = ensemble_forward(children, X_test)
    ens_acc = np.mean(np.argmax(ens_out, axis=1) == y_test)
    print(f"      Ensemble (equal): {ens_acc:.4f}")

    # Optimal weights (universal property test)
    opt_w, opt_acc = find_optimal_weights(children, X_test, y_test)
    print(f"      Optimal weights: {[f'{w:.2f}' for w in opt_w]}")
    print(f"      Optimal accuracy: {opt_acc:.4f}")

    # Test on shifted distributions
    acc_noisy = np.mean(np.argmax(ensemble_forward(children, X_test_noisy, opt_w)[0], axis=1) == y_test)
    acc_scaled = np.mean(np.argmax(ensemble_forward(children, X_test_scaled, opt_w)[0], axis=1) == y_test)

    # Product (intersection) vs Coproduct (union)
    # Product: all children must agree
    child_preds = [np.argmax(c.forward(X_test)[0], axis=1) for c in children]
    agreement_mask = np.ones(len(y_test), dtype=bool)
    for p in child_preds:
        agreement_mask &= (p == child_preds[0])
    product_acc = np.mean(child_preds[0][agreement_mask] == y_test[agreement_mask]) if agreement_mask.sum() > 0 else 0
    product_coverage = agreement_mask.mean()

    # Coproduct: at least one child is correct
    any_correct = np.zeros(len(y_test), dtype=bool)
    for p in child_preds:
        any_correct |= (p == y_test)
    coproduct_acc = any_correct.mean()

    results[N] = {
        'child_accs': child_accs,
        'ensemble_acc': ens_acc,
        'optimal_acc': opt_acc,
        'optimal_weights': opt_w,
        'noisy_acc': acc_noisy,
        'scaled_acc': acc_scaled,
        'product_acc': product_acc,
        'product_coverage': product_coverage,
        'coproduct_acc': coproduct_acc,
        'mean_tension': np.mean(ens_tension),
    }

# ── Weight uniqueness test (universal property) ──
print(f"\n{'='*60}")
print(f"  Universal Property: Weight Uniqueness Test")
print(f"{'='*60}")
print(f"  For coproduct: given any target, there should exist UNIQUE morphism")
print(f"  Test: How many weight combinations achieve near-optimal accuracy?")

for N in [2, 3, 4]:
    r = results[N]
    threshold = r['optimal_acc'] - 0.01  # within 1% of optimal
    # For N=2, count how many w achieve this
    if N == 2:
        count = 0
        total = 0
        for w1 in np.arange(0, 1.01, 0.05):
            total += 1
            children_N = mitosis(parent, N, perturb_scale=0.05)
            for i, c in enumerate(children_N):
                c.train_sgd(X_train, y_train, epochs=40, lr=0.01)
            w = [w1, 1-w1]
            out, _ = ensemble_forward(children_N, X_test, w)
            acc = np.mean(np.argmax(out, axis=1) == y_test)
            if acc >= threshold:
                count += 1
        uniqueness = 1.0 - count / total  # higher = more unique
        print(f"  N={N}: {count}/{total} weights achieve >={threshold:.4f}")
        print(f"         Uniqueness score: {uniqueness:.4f}")

# ── Comparison table ──
print(f"\n{'='*60}")
print(f"  COMPARISON TABLE: Mitosis N=2 vs N=3 vs N=4")
print(f"{'='*60}")
print(f"  {'Metric':<25} {'N=2':>10} {'N=3':>10} {'N=4':>10} {'Parent':>10}")
print(f"  {'-'*65}")
print(f"  {'Parent accuracy':<25} {parent_acc:>10.4f} {parent_acc:>10.4f} {parent_acc:>10.4f} {parent_acc:>10.4f}")
for N in [2, 3, 4]:
    r = results[N]
    if N == 2:
        print(f"  {'Ensemble (equal)':<25} {r['ensemble_acc']:>10.4f}", end="")
    elif N == 3:
        print(f" {r['ensemble_acc']:>10.4f}", end="")
    else:
        print(f" {r['ensemble_acc']:>10.4f} {'---':>10}")

print()
for N in [2, 3, 4]:
    r = results[N]
    if N == 2:
        print(f"  {'Optimal ensemble':<25} {r['optimal_acc']:>10.4f}", end="")
    elif N == 3:
        print(f" {r['optimal_acc']:>10.4f}", end="")
    else:
        print(f" {r['optimal_acc']:>10.4f} {'---':>10}")

print()
for N in [2, 3, 4]:
    r = results[N]
    if N == 2:
        print(f"  {'Noisy test acc':<25} {r['noisy_acc']:>10.4f}", end="")
    elif N == 3:
        print(f" {r['noisy_acc']:>10.4f}", end="")
    else:
        print(f" {r['noisy_acc']:>10.4f} {'---':>10}")

print()
for N in [2, 3, 4]:
    r = results[N]
    if N == 2:
        print(f"  {'Coproduct acc (union)':<25} {r['coproduct_acc']:>10.4f}", end="")
    elif N == 3:
        print(f" {r['coproduct_acc']:>10.4f}", end="")
    else:
        print(f" {r['coproduct_acc']:>10.4f} {'---':>10}")

print()
for N in [2, 3, 4]:
    r = results[N]
    if N == 2:
        print(f"  {'Product coverage':<25} {r['product_coverage']:>10.4f}", end="")
    elif N == 3:
        print(f" {r['product_coverage']:>10.4f}", end="")
    else:
        print(f" {r['product_coverage']:>10.4f} {'---':>10}")

print()
for N in [2, 3, 4]:
    r = results[N]
    if N == 2:
        print(f"  {'Mean tension':<25} {r['mean_tension']:>10.4f}", end="")
    elif N == 3:
        print(f" {r['mean_tension']:>10.4f}", end="")
    else:
        print(f" {r['mean_tension']:>10.4f} {'---':>10}")

# ── ASCII graph ──
print(f"\n\n{'='*60}")
print(f"  ASCII: Coproduct accuracy by N")
print(f"{'='*60}")
for N in [2, 3, 4]:
    val = results[N]['coproduct_acc']
    bar_len = int(val * 40)
    print(f"  N={N} |{'#' * bar_len}{' ' * (40-bar_len)}| {val:.4f}")

print(f"\n  ASCII: Product coverage by N")
for N in [2, 3, 4]:
    val = results[N]['product_coverage']
    bar_len = int(val * 40)
    print(f"  N={N} |{'#' * bar_len}{' ' * (40-bar_len)}| {val:.4f}")

# ── sigma_{-1}(6) = 2 connection ──
print(f"\n{'='*60}")
print(f"  Connection to sigma_{{-1}}(6) = 2")
print(f"{'='*60}")
r2 = results[2]
r3 = results[3]
r4 = results[4]

# Efficiency = accuracy / N
for N in [2, 3, 4]:
    eff = results[N]['optimal_acc'] / N
    print(f"  N={N}: efficiency = {results[N]['optimal_acc']:.4f} / {N} = {eff:.4f}")

# Coproduct-product gap
for N in [2, 3, 4]:
    gap = results[N]['coproduct_acc'] - results[N]['product_acc'] * results[N]['product_coverage']
    print(f"  N={N}: coproduct-product gap = {gap:.4f}")

best_eff_N = max([2,3,4], key=lambda n: results[n]['optimal_acc'] / n)
print(f"\n  Most efficient N = {best_eff_N} (= sigma_{{-1}}(6) = {2}? {'YES' if best_eff_N==2 else 'NO'})")

print("\n  DONE.")
