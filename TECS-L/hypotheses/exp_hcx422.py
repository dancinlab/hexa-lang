#!/usr/bin/env python3
"""H-CX-422: Pure Field = Meditation State
Measure eq contribution decay over training epochs.
Uses numpy/sklearn only (no torch).
"""

import numpy as np
from sklearn.datasets import load_digits
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
import json

np.random.seed(42)

# --- Load data ---
digits = load_digits()
X, y = digits.data, digits.target
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
scaler = StandardScaler()
X_train = scaler.fit_transform(X_train)
X_test = scaler.transform(X_test)

input_dim = X_train.shape[1]  # 64
hidden_dim = 64
output_dim = 10
n_epochs = 30
lr = 0.01

# --- Simple 2-layer network with ReLU ---
def init_network(in_d, hid_d, out_d):
    """Returns dict of weights."""
    scale_h = np.sqrt(2.0 / in_d)
    scale_o = np.sqrt(2.0 / hid_d)
    return {
        'W1': np.random.randn(in_d, hid_d) * scale_h,
        'b1': np.zeros(hid_d),
        'W2': np.random.randn(hid_d, out_d) * scale_o,
        'b2': np.zeros(out_d),
    }

def forward(net, x):
    h = x @ net['W1'] + net['b1']
    h = np.maximum(h, 0)  # ReLU
    logits = h @ net['W2'] + net['b2']
    return logits, h

def softmax(logits):
    e = np.exp(logits - logits.max(axis=1, keepdims=True))
    return e / e.sum(axis=1, keepdims=True)

def cross_entropy(probs, labels):
    n = len(labels)
    return -np.log(probs[np.arange(n), labels] + 1e-12).mean()

def accuracy(logits, labels):
    return (logits.argmax(axis=1) == labels).mean() * 100

def backward_and_update(net, x, h, probs, labels, lr):
    n = len(labels)
    # dL/dlogits
    dlogits = probs.copy()
    dlogits[np.arange(n), labels] -= 1
    dlogits /= n
    # dW2, db2
    dW2 = h.T @ dlogits
    db2 = dlogits.sum(axis=0)
    # dh
    dh = dlogits @ net['W2'].T
    dh[h <= 0] = 0  # ReLU grad
    # dW1, db1
    dW1 = x.T @ dh
    db1 = dh.sum(axis=0)
    # Update
    net['W1'] -= lr * dW1
    net['b1'] -= lr * db1
    net['W2'] -= lr * dW2
    net['b2'] -= lr * db2

# --- PureField: engine_A - engine_G (field), plus eq = (A+G)/2 ---
engine_a = init_network(input_dim, hidden_dim, output_dim)
engine_g = init_network(input_dim, hidden_dim, output_dim)

results = []

for epoch in range(n_epochs):
    # Forward
    logits_a, h_a = forward(engine_a, X_train)
    logits_g, h_g = forward(engine_g, X_train)

    # Three modes
    field_logits = logits_a - logits_g          # field only (A-G)
    eq_logits = (logits_a + logits_g) / 2       # eq only (average)
    full_logits = field_logits + 0.1 * eq_logits  # full = field + small eq

    # Test accuracies
    logits_a_t, _ = forward(engine_a, X_test)
    logits_g_t, _ = forward(engine_g, X_test)
    field_test = logits_a_t - logits_g_t
    eq_test = (logits_a_t + logits_g_t) / 2
    full_test = field_test + 0.1 * eq_test

    acc_field = accuracy(field_test, y_test)
    acc_eq = accuracy(eq_test, y_test)
    acc_full = accuracy(full_test, y_test)
    eq_contribution = acc_full - acc_field

    # Tension
    tension = np.mean(field_test ** 2)

    results.append({
        'epoch': epoch,
        'field_acc': round(acc_field, 2),
        'eq_acc': round(acc_eq, 2),
        'full_acc': round(acc_full, 2),
        'eq_contribution': round(eq_contribution, 2),
        'tension': round(tension, 4),
    })

    # Train with full model (backprop through both engines)
    probs_a = softmax(logits_a)
    probs_g = softmax(logits_g)

    # Train engine_a to maximize field output for correct class
    # Use field_logits for training
    field_probs = softmax(field_logits)
    # Gradient for field = A - G: dA = dfield, dG = -dfield
    n = len(y_train)
    dfield = field_probs.copy()
    dfield[np.arange(n), y_train] -= 1
    dfield /= n

    # Update engine_a (positive gradient)
    dW2_a = h_a.T @ dfield
    db2_a = dfield.sum(axis=0)
    dh_a = dfield @ engine_a['W2'].T
    dh_a[h_a <= 0] = 0
    dW1_a = X_train.T @ dh_a
    db1_a = dh_a.sum(axis=0)
    engine_a['W1'] -= lr * dW1_a
    engine_a['b1'] -= lr * db1_a
    engine_a['W2'] -= lr * dW2_a
    engine_a['b2'] -= lr * db2_a

    # Update engine_g (negative gradient = maximize G for divergence)
    dW2_g = h_g.T @ (-dfield)
    db2_g = (-dfield).sum(axis=0)
    dh_g = (-dfield) @ engine_g['W2'].T
    dh_g[h_g <= 0] = 0
    dW1_g = X_train.T @ dh_g
    db1_g = dh_g.sum(axis=0)
    engine_g['W1'] -= lr * dW1_g
    engine_g['b1'] -= lr * db1_g
    engine_g['W2'] -= lr * dW2_g
    engine_g['b2'] -= lr * db2_g

print("=" * 70)
print("H-CX-422: Pure Field = Meditation State")
print("=" * 70)
print(f"\n{'Epoch':>5} | {'Field%':>7} | {'Eq%':>7} | {'Full%':>7} | {'EqContrib':>9} | {'Tension':>8}")
print("-" * 60)
for r in results:
    print(f"{r['epoch']:>5} | {r['field_acc']:>7.2f} | {r['eq_acc']:>7.2f} | {r['full_acc']:>7.2f} | {r['eq_contribution']:>9.2f} | {r['tension']:>8.4f}")

# Correlation: epoch vs eq_contribution
epochs = np.array([r['epoch'] for r in results])
eq_contribs = np.array([r['eq_contribution'] for r in results])
corr = np.corrcoef(epochs, eq_contribs)[0, 1]
print(f"\nCorrelation(epoch, eq_contribution) = {corr:.4f}")
print(f"Prediction: negative (meditation deepening) = {'CONFIRMED' if corr < -0.3 else 'WEAKLY CONFIRMED' if corr < 0 else 'REJECTED'}")

# Final comparison
print(f"\nFinal field-only: {results[-1]['field_acc']:.2f}%")
print(f"Final eq-only:    {results[-1]['eq_acc']:.2f}%")
print(f"Final full:       {results[-1]['full_acc']:.2f}%")
print(f"Final eq_contribution: {results[-1]['eq_contribution']:.2f}%")

# ASCII graph
print("\n--- ASCII Graph: Accuracy over Epochs ---")
print("100|")
for level in range(100, -1, -5):
    row = f"{level:>3}|"
    for r in results:
        if abs(r['field_acc'] - level) < 2.5:
            row += "F"
        elif abs(r['eq_acc'] - level) < 2.5:
            row += "E"
        elif abs(r['full_acc'] - level) < 2.5:
            row += "*"
        else:
            row += " "
    print(row)
print("   +" + "-" * n_epochs)
print("    F=field  E=eq  *=full")

# ASCII graph: eq_contribution over time
print("\n--- ASCII Graph: EQ Contribution over Epochs ---")
max_c = max(eq_contribs.max(), 5)
min_c = min(eq_contribs.min(), -5)
rows = 15
for i in range(rows, -1, -1):
    val = min_c + (max_c - min_c) * i / rows
    row = f"{val:>6.1f}|"
    for ec in eq_contribs:
        expected_row = int((ec - min_c) / (max_c - min_c) * rows)
        if expected_row == i:
            row += "#"
        else:
            row += " "
    print(row)
print("      +" + "-" * n_epochs)
print("       Epoch 0 --> " + str(n_epochs))

# Save results
with open('/Users/ghost/Dev/TECS-L/docs/hypotheses/exp_hcx422_results.json', 'w') as f:
    json.dump({'results': results, 'correlation': corr}, f, indent=2)

print("\nResults saved to exp_hcx422_results.json")
