#!/usr/bin/env python3
"""H-CX-424: Pure Field Scaling Law
Test field_advantage across 5 model sizes.
Uses numpy/sklearn only.
"""

import numpy as np
from sklearn.datasets import load_digits
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from scipy.optimize import curve_fit
import json

np.random.seed(42)

# --- Load data ---
digits = load_digits()
X, y = digits.data, digits.target
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
scaler = StandardScaler()
X_train = scaler.fit_transform(X_train)
X_test = scaler.transform(X_test)

input_dim = 64
output_dim = 10

def init_network(in_d, hid_d, out_d):
    scale_h = np.sqrt(2.0 / in_d)
    scale_o = np.sqrt(2.0 / hid_d)
    return {
        'W1': np.random.randn(in_d, hid_d) * scale_h,
        'b1': np.zeros(hid_d),
        'W2': np.random.randn(hid_d, out_d) * scale_o,
        'b2': np.zeros(out_d),
    }

def count_params(net):
    return sum(v.size for v in net.values())

def forward(net, x):
    h = x @ net['W1'] + net['b1']
    h = np.maximum(h, 0)
    logits = h @ net['W2'] + net['b2']
    return logits, h

def softmax(logits):
    e = np.exp(logits - logits.max(axis=1, keepdims=True))
    return e / e.sum(axis=1, keepdims=True)

def accuracy(logits, labels):
    return (logits.argmax(axis=1) == labels).mean() * 100

def train_purefield(hidden_dim, n_epochs=40, lr=0.01):
    """Train a PureField model with given hidden dimension."""
    engine_a = init_network(input_dim, hidden_dim, output_dim)
    engine_g = init_network(input_dim, hidden_dim, output_dim)
    total_params = count_params(engine_a) + count_params(engine_g)

    for epoch in range(n_epochs):
        logits_a, h_a = forward(engine_a, X_train)
        logits_g, h_g = forward(engine_g, X_train)
        field_logits = logits_a - logits_g
        field_probs = softmax(field_logits)

        n = len(y_train)
        dfield = field_probs.copy()
        dfield[np.arange(n), y_train] -= 1
        dfield /= n

        # Update A
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

        # Update G (negative)
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

    # Evaluate
    la_t, _ = forward(engine_a, X_test)
    lg_t, _ = forward(engine_g, X_test)
    field_test = la_t - lg_t
    eq_test = (la_t + lg_t) / 2
    full_test = field_test + 0.1 * eq_test

    acc_field = accuracy(field_test, y_test)
    acc_eq = accuracy(eq_test, y_test)
    acc_full = accuracy(full_test, y_test)

    tension = np.mean(field_test ** 2)

    return {
        'hidden_dim': hidden_dim,
        'total_params': total_params,
        'field_acc': acc_field,
        'eq_acc': acc_eq,
        'full_acc': acc_full,
        'field_advantage': acc_field - acc_full,
        'tension': tension,
    }

# --- 5 Model Sizes ---
# hidden_dim determines size: params ~ 2 * (64*h + h + h*10 + 10)
hidden_dims = [2, 8, 32, 128, 512]
# Approximate params: 2*(64*h + h + h*10 + 10) = 2*(74h + 10 + h) = 2*(75h + 10) = 150h + 20

results = []
print("=" * 70)
print("H-CX-424: Pure Field Scaling Law")
print("=" * 70)
print(f"\nTraining 5 model sizes...")

for hd in hidden_dims:
    print(f"  Training hidden_dim={hd}...", end=" ", flush=True)
    # Adjust epochs for larger models
    epochs = 40 if hd <= 128 else 30
    lr = 0.01 if hd <= 128 else 0.005
    r = train_purefield(hd, n_epochs=epochs, lr=lr)
    print(f"params={r['total_params']:>7,} | field={r['field_acc']:.1f}% | full={r['full_acc']:.1f}% | adv={r['field_advantage']:+.2f}%")
    results.append(r)

# --- Report ---
print(f"\n{'HidDim':>6} | {'Params':>8} | {'Field%':>7} | {'Eq%':>7} | {'Full%':>7} | {'FieldAdv':>8} | {'Tension':>8}")
print("-" * 70)
for r in results:
    print(f"{r['hidden_dim']:>6} | {r['total_params']:>8,} | {r['field_acc']:>7.2f} | {r['eq_acc']:>7.2f} | {r['full_acc']:>7.2f} | {r['field_advantage']:>+8.2f} | {r['tension']:>8.2f}")

# --- Curve Fitting ---
params = np.array([r['total_params'] for r in results])
field_adv = np.array([r['field_advantage'] for r in results])
log_params = np.log(params)

# Linear fit: field_adv = a * log(params) + b
try:
    coeffs_log = np.polyfit(log_params, field_adv, 1)
    pred_log = np.polyval(coeffs_log, log_params)
    ss_res_log = np.sum((field_adv - pred_log) ** 2)
    ss_tot = np.sum((field_adv - field_adv.mean()) ** 2)
    r2_log = 1 - ss_res_log / ss_tot if ss_tot > 0 else 0
except:
    r2_log = 0
    coeffs_log = [0, 0]

# Linear fit: field_adv = a * params + b
try:
    coeffs_lin = np.polyfit(params, field_adv, 1)
    pred_lin = np.polyval(coeffs_lin, params)
    ss_res_lin = np.sum((field_adv - pred_lin) ** 2)
    r2_lin = 1 - ss_res_lin / ss_tot if ss_tot > 0 else 0
except:
    r2_lin = 0
    coeffs_lin = [0, 0]

# Power law: field_adv = a * params^b (use log-log)
try:
    # Only fit where field_adv > 0 for log
    mask = field_adv > 0
    if mask.sum() >= 2:
        coeffs_pow = np.polyfit(np.log(params[mask]), np.log(field_adv[mask]), 1)
        b_pow = coeffs_pow[0]
        a_pow = np.exp(coeffs_pow[1])
        pred_pow = a_pow * params ** b_pow
        ss_res_pow = np.sum((field_adv - pred_pow) ** 2)
        r2_pow = 1 - ss_res_pow / ss_tot if ss_tot > 0 else 0
    else:
        r2_pow = -1
        b_pow = 0
        a_pow = 0
except:
    r2_pow = -1
    b_pow = 0
    a_pow = 0

print(f"\n--- Curve Fitting Results ---")
print(f"  Linear:    R2 = {r2_lin:.4f}  (field_adv = {coeffs_lin[0]:.6f} * params + {coeffs_lin[1]:.2f})")
print(f"  Log:       R2 = {r2_log:.4f}  (field_adv = {coeffs_log[0]:.4f} * log(params) + {coeffs_log[1]:.2f})")
if r2_pow >= 0:
    print(f"  Power law: R2 = {r2_pow:.4f}  (field_adv = {a_pow:.4f} * params^{b_pow:.4f})")

best_fit = max([('linear', r2_lin), ('log', r2_log), ('power', r2_pow)], key=lambda x: x[1])
print(f"\n  Best fit: {best_fit[0]} (R2={best_fit[1]:.4f})")

# Extrapolation
if best_fit[0] == 'log':
    target_params = [1e6, 1e7, 1e8, 1e9]
    print(f"\n  Extrapolation (log model):")
    for tp in target_params:
        pred = coeffs_log[0] * np.log(tp) + coeffs_log[1]
        print(f"    {tp:.0e} params -> field_advantage = {pred:+.2f}%")

# --- ASCII Graph ---
print("\n--- ASCII Graph: log(Params) vs Field Advantage ---")
min_adv = min(field_adv) - 1
max_adv = max(field_adv) + 1
rows = 15
for i in range(rows, -1, -1):
    val = min_adv + (max_adv - min_adv) * i / rows
    row = f"{val:>6.1f}|"
    for j, (lp, fa) in enumerate(zip(log_params, field_adv)):
        col = int((lp - log_params.min()) / (log_params.max() - log_params.min() + 1e-9) * 30)
        expected_row = int((fa - min_adv) / (max_adv - min_adv) * rows)
        if expected_row == i:
            row_padded = list(row + " " * 35)
            row_padded[7 + col] = "*"
            row = "".join(row_padded)
    print(row)
print("      +" + "-" * 35)
print("       log(params) -->")
print(f"       [{log_params.min():.1f} ... {log_params.max():.1f}]")

# Show point labels
for r in results:
    lp = np.log(r['total_params'])
    print(f"  * h={r['hidden_dim']}: log(p)={lp:.1f}, adv={r['field_advantage']:+.2f}%")

# Zero line
print(f"\n  Zero line (field=full): field_advantage = 0")
print(f"  Positive = field BETTER than full (eq hurts)")
print(f"  Negative = full BETTER than field (eq helps)")

# Save
save_data = {
    'results': results,
    'fits': {
        'linear_r2': r2_lin,
        'log_r2': r2_log,
        'power_r2': r2_pow if r2_pow >= 0 else None,
        'best_fit': best_fit[0],
    }
}
with open('/Users/ghost/Dev/TECS-L/docs/hypotheses/exp_hcx424_results.json', 'w') as f:
    json.dump(save_data, f, indent=2)

print("\nResults saved to exp_hcx424_results.json")
