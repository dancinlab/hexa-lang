#!/usr/bin/env python3
"""H-CX-431: Nash Equilibrium = Silent Consensus verification"""
import numpy as np
from sklearn.datasets import load_digits
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from scipy.spatial.distance import cosine
import warnings
warnings.filterwarnings('ignore')

np.random.seed(42)

# Load data
digits = load_digits()
X, y = digits.data, digits.target
scaler = StandardScaler()
X = scaler.fit_transform(X)
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.3, random_state=42)

n_classes = 10
n_features = X.shape[1]

def softmax(z):
    e = np.exp(z - z.max(axis=1, keepdims=True))
    return e / e.sum(axis=1, keepdims=True)

def create_engine(hidden=32):
    W1 = np.random.randn(n_features, hidden) * 0.01
    b1 = np.zeros(hidden)
    W2 = np.random.randn(hidden, n_classes) * 0.01
    b2 = np.zeros(n_classes)
    return [W1, b1, W2, b2]

def forward(params, X):
    W1, b1, W2, b2 = params
    h = np.maximum(0, X @ W1 + b1)  # ReLU
    logits = h @ W2 + b2
    probs = softmax(logits)
    return probs, h

def accuracy(params, X, y):
    probs, _ = forward(params, X)
    return np.mean(np.argmax(probs, axis=1) == y)

def train_engine(params, X, y, lr=0.01, epochs=100):
    W1, b1, W2, b2 = params
    n = len(X)
    for ep in range(epochs):
        probs, h = forward([W1, b1, W2, b2], X)
        # Cross-entropy gradient
        dlogits = probs.copy()
        dlogits[np.arange(n), y] -= 1
        dlogits /= n
        dW2 = h.T @ dlogits
        db2 = dlogits.sum(axis=0)
        dh = dlogits @ W2.T
        dh[h <= 0] = 0
        dW1 = X.T @ dh
        db1 = dh.sum(axis=0)
        W1 -= lr * dW1
        b1 -= lr * db1
        W2 -= lr * dW2
        b2 -= lr * db2
    return [W1, b1, W2, b2]

def compute_gradient_norm(params, X, y):
    """Compute gradient norm at convergence (Nash eq tightness)"""
    W1, b1, W2, b2 = params
    n = len(X)
    probs, h = forward(params, X)
    dlogits = probs.copy()
    dlogits[np.arange(n), y] -= 1
    dlogits /= n
    dW2 = h.T @ dlogits
    db2 = dlogits.sum(axis=0)
    dh = dlogits @ W2.T
    dh[h <= 0] = 0
    dW1 = X.T @ dh
    db1 = dh.sum(axis=0)
    total_norm = np.sqrt(np.sum(dW1**2) + np.sum(db1**2) + np.sum(dW2**2) + np.sum(db2**2))
    return total_norm

def cosine_similarity_outputs(engines, X):
    """Compute pairwise cosine similarity of engine outputs"""
    outputs = []
    for eng in engines:
        probs, _ = forward(eng, X)
        outputs.append(probs.flatten())
    n = len(outputs)
    sims = []
    for i in range(n):
        for j in range(i+1, n):
            sim = 1 - cosine(outputs[i], outputs[j])
            sims.append(sim)
    return np.mean(sims)

print("=" * 60)
print("H-CX-431: Nash Equilibrium = Silent Consensus")
print("=" * 60)

# Test for N = 2, 3, 4, 6 engines
results = {}
for N in [2, 3, 4, 6]:
    engines = [create_engine(hidden=32) for _ in range(N)]
    engines = [train_engine(eng, X_train, y_train, lr=0.01, epochs=150) for eng in engines]

    accs = [accuracy(eng, X_test, y_test) for eng in engines]
    grad_norms = [compute_gradient_norm(eng, X_test, y_test) for eng in engines]
    cos_sim = cosine_similarity_outputs(engines, X_test)

    # Nash equilibrium check: perturb each engine, see if payoff improves
    nash_violations = 0
    total_checks = 0
    for i in range(N):
        base_acc = accs[i]
        for trial in range(5):
            perturbed = [p + np.random.randn(*p.shape) * 0.01 for p in engines[i]]
            perturbed_acc = accuracy(perturbed, X_test, y_test)
            if perturbed_acc > base_acc + 0.005:
                nash_violations += 1
            total_checks += 1

    nash_tightness = 1.0 - nash_violations / total_checks

    results[N] = {
        'accs': accs,
        'mean_acc': np.mean(accs),
        'grad_norms': grad_norms,
        'mean_grad': np.mean(grad_norms),
        'cos_sim': cos_sim,
        'nash_tightness': nash_tightness,
        'nash_violations': nash_violations,
        'total_checks': total_checks
    }

print("\n--- Results by Number of Engines ---")
print(f"{'N':>3} | {'Mean Acc':>8} | {'Mean Grad':>9} | {'Cos Sim':>8} | {'Nash Tight':>10} | {'Violations':>10}")
print("-" * 65)
for N in [2, 3, 4, 6]:
    r = results[N]
    print(f"{N:>3} | {r['mean_acc']:>8.4f} | {r['mean_grad']:>9.4f} | {r['cos_sim']:>8.4f} | {r['nash_tightness']:>10.3f} | {r['nash_violations']:>5}/{r['total_checks']}")

# Golden Zone check: vary inhibition (dropout-like) and find Nash eq region
print("\n--- Golden Zone Nash Equilibrium Check ---")
print("Varying inhibition rate, checking Nash tightness:")
print(f"{'Inhibition':>10} | {'Accuracy':>8} | {'Grad Norm':>9} | {'Nash Tight':>10}")
print("-" * 50)

inhibition_results = []
for inh in np.arange(0.05, 0.65, 0.05):
    eng = create_engine(hidden=32)
    eng = train_engine(eng, X_train, y_train, lr=0.01, epochs=150)
    # Apply inhibition as output scaling
    W1, b1, W2, b2 = eng
    W2_inh = W2 * (1 - inh)
    eng_inh = [W1, b1, W2_inh, b2]

    acc = accuracy(eng_inh, X_test, y_test)
    grad = compute_gradient_norm(eng_inh, X_test, y_test)

    # Nash check
    violations = 0
    checks = 10
    for _ in range(checks):
        perturbed = [p + np.random.randn(*p.shape) * 0.005 for p in eng_inh]
        if accuracy(perturbed, X_test, y_test) > acc + 0.005:
            violations += 1
    nash_t = 1.0 - violations / checks

    inhibition_results.append((inh, acc, grad, nash_t))
    print(f"{inh:>10.2f} | {acc:>8.4f} | {grad:>9.4f} | {nash_t:>10.3f}")

# ASCII graph: Nash tightness vs inhibition
print("\n--- ASCII Graph: Nash Tightness vs Inhibition ---")
print("Nash Tightness")
print("1.0 |", end="")
for inh, acc, grad, nash_t in inhibition_results:
    if nash_t >= 0.95:
        print("*", end="")
    elif nash_t >= 0.8:
        print("o", end="")
    else:
        print(".", end="")
print()
print("0.8 |", end="")
for inh, acc, grad, nash_t in inhibition_results:
    if 0.8 <= nash_t < 0.95:
        print("*", end="")
    elif nash_t >= 0.95:
        print("|", end="")
    else:
        print(" ", end="")
print()
print("0.5 |", end="")
for inh, acc, grad, nash_t in inhibition_results:
    if 0.5 <= nash_t < 0.8:
        print("*", end="")
    else:
        print(" ", end="")
print()
print("    +" + "-" * len(inhibition_results))
print("     " + "".join([f"{r[0]:.1f}"[1] for r in inhibition_results]))
print("     Inhibition (0.05 to 0.60)")
print(f"     Golden Zone: [{0.2123:.2f}, {0.5:.2f}], center=1/e={1/np.e:.4f}")

# Find optimal inhibition
best_idx = np.argmax([r[3] for r in inhibition_results])
best_inh = inhibition_results[best_idx][0]
print(f"\n     Best Nash Tightness at I={best_inh:.2f}")
print(f"     Distance from 1/e: |{best_inh:.3f} - {1/np.e:.3f}| = {abs(best_inh - 1/np.e):.4f}")

# Correlation: gradient norm vs consensus
print("\n--- Correlation: Gradient Norm vs Consensus ---")
grads_list = [results[N]['mean_grad'] for N in [2, 3, 4, 6]]
cos_list = [results[N]['cos_sim'] for N in [2, 3, 4, 6]]
correlation = np.corrcoef(grads_list, cos_list)[0, 1]
print(f"Pearson correlation (grad_norm vs cos_sim): r = {correlation:.4f}")
print(f"Interpretation: {'Negative = converged gradients → high consensus' if correlation < 0 else 'Positive = check interpretation'}")

print("\n--- Summary ---")
for N in [2, 3, 4, 6]:
    r = results[N]
    print(f"N={N}: acc={r['mean_acc']:.3f}, cos={r['cos_sim']:.4f}, nash={r['nash_tightness']:.3f}")
print(f"\nGolden Zone (1/e={1/np.e:.4f}) Nash optimality: I_best={best_inh:.2f}")
