#!/usr/bin/env python3
"""H-CX-432: Tension = Payoff in Game Theory verification"""
import numpy as np
from sklearn.datasets import load_digits
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
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

def create_engine(hidden=32, init_scale=0.01):
    W1 = np.random.randn(n_features, hidden) * init_scale
    b1 = np.zeros(hidden)
    W2 = np.random.randn(hidden, n_classes) * init_scale
    b2 = np.zeros(n_classes)
    return [W1, b1, W2, b2]

def forward(params, X):
    W1, b1, W2, b2 = params
    h = np.maximum(0, X @ W1 + b1)
    logits = h @ W2 + b2
    probs = softmax(logits)
    return probs, h

def compute_tension(params, X, y):
    """Tension = 1 - max(softmax) averaged, represents uncertainty/confidence"""
    probs, _ = forward(params, X)
    max_probs = probs.max(axis=1)
    tension = 1.0 - max_probs.mean()
    return tension

def compute_accuracy(params, X, y):
    probs, _ = forward(params, X)
    return np.mean(np.argmax(probs, axis=1) == y)

def train_engine(params, X, y, lr=0.01, epochs=100):
    W1, b1, W2, b2 = [p.copy() for p in params]
    n = len(X)
    for ep in range(epochs):
        probs, h = forward([W1, b1, W2, b2], X)
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

print("=" * 60)
print("H-CX-432: Tension = Payoff in Game Theory")
print("=" * 60)

# Define strategies: different learning rates and init scales
strategies = {
    'S1': {'lr': 0.005, 'init': 0.005, 'label': 'Conservative'},
    'S2': {'lr': 0.01,  'init': 0.01,  'label': 'Moderate'},
    'S3': {'lr': 0.02,  'init': 0.02,  'label': 'Aggressive'},
    'S4': {'lr': 0.05,  'init': 0.01,  'label': 'Fast-learn'},
}

# Build payoff matrix: 2-player game, each chooses a strategy
# Payoff = negative tension (lower tension = higher payoff = better confidence)
strat_keys = list(strategies.keys())
n_strats = len(strat_keys)

# Tension matrix for Player A and Player B
tension_A = np.zeros((n_strats, n_strats))
tension_B = np.zeros((n_strats, n_strats))
acc_A = np.zeros((n_strats, n_strats))
acc_B = np.zeros((n_strats, n_strats))

print("\nComputing payoff matrix (4x4 strategies)...")
for i, sA in enumerate(strat_keys):
    for j, sB in enumerate(strat_keys):
        np.random.seed(42 + i * 10 + j)
        engA = create_engine(hidden=32, init_scale=strategies[sA]['init'])
        engB = create_engine(hidden=32, init_scale=strategies[sB]['init'])
        engA = train_engine(engA, X_train, y_train, lr=strategies[sA]['lr'], epochs=150)
        engB = train_engine(engB, X_train, y_train, lr=strategies[sB]['lr'], epochs=150)
        tension_A[i, j] = compute_tension(engA, X_test, y_test)
        tension_B[i, j] = compute_tension(engB, X_test, y_test)
        acc_A[i, j] = compute_accuracy(engA, X_test, y_test)
        acc_B[i, j] = compute_accuracy(engB, X_test, y_test)

# Payoff = 1 - tension (higher is better)
payoff_A = 1 - tension_A
payoff_B = 1 - tension_B

print("\n--- Bimatrix Game: Player A Payoff (1 - Tension) ---")
print(f"{'':>12}", end="")
for s in strat_keys:
    print(f" {s:>10}", end="")
print()
for i, sA in enumerate(strat_keys):
    print(f"{sA:>4}({strategies[sA]['label']:>8})", end="")
    for j in range(n_strats):
        print(f" {payoff_A[i,j]:>10.4f}", end="")
    print()

print("\n--- Bimatrix Game: Player B Payoff (1 - Tension) ---")
print(f"{'':>12}", end="")
for s in strat_keys:
    print(f" {s:>10}", end="")
print()
for i, sA in enumerate(strat_keys):
    print(f"{sA:>4}({strategies[sA]['label']:>8})", end="")
    for j in range(n_strats):
        print(f" {payoff_B[i,j]:>10.4f}", end="")
    print()

# Find Nash equilibria (pure strategy)
print("\n--- Nash Equilibrium Search (Pure Strategy) ---")
nash_eq = []
for i in range(n_strats):
    for j in range(n_strats):
        # A's best response given B plays j
        a_best = payoff_A[:, j].max() == payoff_A[i, j]
        # B's best response given A plays i
        b_best = payoff_B[i, :].max() == payoff_B[i, j]
        if a_best and b_best:
            nash_eq.append((i, j))
            print(f"  Nash Equilibrium: ({strat_keys[i]}, {strat_keys[j]}) -> "
                  f"payoff=({payoff_A[i,j]:.4f}, {payoff_B[i,j]:.4f}), "
                  f"tension=({tension_A[i,j]:.4f}, {tension_B[i,j]:.4f})")

# Find Pareto optimal
print("\n--- Pareto Optimal Points ---")
social_welfare = payoff_A + payoff_B
pareto = []
for i in range(n_strats):
    for j in range(n_strats):
        dominated = False
        for ii in range(n_strats):
            for jj in range(n_strats):
                if (payoff_A[ii,jj] >= payoff_A[i,j] and payoff_B[ii,jj] >= payoff_B[i,j] and
                    (payoff_A[ii,jj] > payoff_A[i,j] or payoff_B[ii,jj] > payoff_B[i,j])):
                    dominated = True
                    break
            if dominated:
                break
        if not dominated:
            pareto.append((i, j))
            print(f"  Pareto: ({strat_keys[i]}, {strat_keys[j]}) -> "
                  f"payoff=({payoff_A[i,j]:.4f}, {payoff_B[i,j]:.4f}), "
                  f"tension=({tension_A[i,j]:.4f}, {tension_B[i,j]:.4f}), "
                  f"social={social_welfare[i,j]:.4f}")

# Price of Anarchy
if nash_eq:
    worst_nash_welfare = min(social_welfare[i,j] for i,j in nash_eq)
    best_social = social_welfare.max()
    poa = best_social / worst_nash_welfare if worst_nash_welfare > 0 else float('inf')
    print(f"\n--- Price of Anarchy ---")
    print(f"  Best social welfare:  {best_social:.4f}")
    print(f"  Worst Nash welfare:   {worst_nash_welfare:.4f}")
    print(f"  Price of Anarchy:     {poa:.4f}")

# Golden Zone analysis
print("\n--- Golden Zone Analysis ---")
print("Checking if optimal tension falls in Golden Zone [0.2123, 0.5000], center=1/e=0.3679")
golden_lower = 0.2123
golden_upper = 0.5000
golden_center = 1/np.e

for i, j in nash_eq:
    tA = tension_A[i, j]
    tB = tension_B[i, j]
    in_gz_A = golden_lower <= tA <= golden_upper
    in_gz_B = golden_lower <= tB <= golden_upper
    print(f"  Nash ({strat_keys[i]},{strat_keys[j]}): tension_A={tA:.4f} {'[IN GZ]' if in_gz_A else '[OUT]'}, "
          f"tension_B={tB:.4f} {'[IN GZ]' if in_gz_B else '[OUT]'}")

# Inhibition sweep: vary inhibition, measure social welfare
print("\n--- Inhibition vs Social Welfare ---")
print(f"{'Inhibition':>10} | {'Tension_A':>9} | {'Tension_B':>9} | {'Social':>7} | {'In GZ':>5}")
print("-" * 55)

inh_results = []
for inh in np.arange(0.05, 0.65, 0.05):
    np.random.seed(42)
    eA = create_engine(hidden=32)
    eB = create_engine(hidden=32)
    eA = train_engine(eA, X_train, y_train, lr=0.01, epochs=150)
    eB = train_engine(eB, X_train, y_train, lr=0.01, epochs=150)
    # Apply inhibition
    eA[2] = eA[2] * (1 - inh)
    eB[2] = eB[2] * (1 - inh)
    tA = compute_tension(eA, X_test, y_test)
    tB = compute_tension(eB, X_test, y_test)
    sw = (1 - tA) + (1 - tB)
    in_gz = golden_lower <= inh <= golden_upper
    inh_results.append((inh, tA, tB, sw, in_gz))
    print(f"{inh:>10.2f} | {tA:>9.4f} | {tB:>9.4f} | {sw:>7.4f} | {'Yes' if in_gz else 'No':>5}")

# ASCII graph: Social Welfare vs Inhibition
print("\n--- ASCII Graph: Social Welfare vs Inhibition ---")
sws = [r[3] for r in inh_results]
sw_min, sw_max = min(sws), max(sws)
height = 10
for row in range(height, -1, -1):
    threshold = sw_min + (sw_max - sw_min) * row / height
    if row == height:
        line = f"{sw_max:.2f}|"
    elif row == 0:
        line = f"{sw_min:.2f}|"
    else:
        line = "     |"
    for inh, tA, tB, sw, in_gz in inh_results:
        if sw >= threshold:
            if in_gz:
                line += "#"
            else:
                line += "."
        else:
            line += " "
    print(line)
print("     +" + "-" * len(inh_results))
inhs = [r[0] for r in inh_results]
print("      " + "".join([str(int(i*10) % 10) for i in inhs]))
print("      Inhibition x10 (# = Golden Zone)")

best_inh_idx = np.argmax(sws)
best_inh = inh_results[best_inh_idx][0]
print(f"\n  Peak social welfare at I={best_inh:.2f}")
print(f"  Golden Zone center 1/e = {golden_center:.4f}")
print(f"  Distance: |{best_inh:.3f} - {golden_center:.3f}| = {abs(best_inh - golden_center):.4f}")

print("\n--- Summary ---")
print(f"  Nash Equilibria found: {len(nash_eq)}")
print(f"  Pareto Optimal points: {len(pareto)}")
if nash_eq:
    print(f"  Price of Anarchy: {poa:.4f}")
print(f"  Peak welfare inhibition: {best_inh:.2f}")
print(f"  Golden Zone prediction (1/e): {golden_center:.4f}")
print(f"  Match: {'Yes' if golden_lower <= best_inh <= golden_upper else 'No'}")
