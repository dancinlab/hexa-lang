#!/usr/bin/env python3
"""H-CX-423: Dream State = Field Hyperactivation
Test 5 input conditions and measure tension regimes.
Uses numpy/sklearn only.
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

input_dim = 64
hidden_dim = 64
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

# --- Train PureField model ---
engine_a = init_network(input_dim, hidden_dim, output_dim)
engine_g = init_network(input_dim, hidden_dim, output_dim)
lr = 0.01
n_epochs = 30

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

    # Update G
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

# Check training result
logits_a_t, _ = forward(engine_a, X_test)
logits_g_t, _ = forward(engine_g, X_test)
field_test = logits_a_t - logits_g_t
train_acc = accuracy(field_test, y_test)
print(f"Trained model accuracy: {train_acc:.2f}%")

# --- 5 Input Conditions ---
n_samples = 200

def compute_tension(engine_a, engine_g, x):
    la, _ = forward(engine_a, x)
    lg, _ = forward(engine_g, x)
    field = la - lg
    tension = np.mean(field ** 2, axis=1)  # per-sample
    return tension, field

conditions = {}

# 1. Awake: real test data
x_awake = X_test[:n_samples]
t_awake, f_awake = compute_tension(engine_a, engine_g, x_awake)
conditions['awake'] = {'tension': t_awake, 'mean': t_awake.mean(), 'std': t_awake.std()}

# 2. Sleep: zero input
x_sleep = np.zeros((n_samples, input_dim))
t_sleep, f_sleep = compute_tension(engine_a, engine_g, x_sleep)
conditions['sleep'] = {'tension': t_sleep, 'mean': t_sleep.mean(), 'std': t_sleep.std()}

# 3. Dream: gaussian noise (same scale as data)
x_dream = np.random.randn(n_samples, input_dim) * X_train.std()
t_dream, f_dream = compute_tension(engine_a, engine_g, x_dream)
conditions['dream'] = {'tension': t_dream, 'mean': t_dream.mean(), 'std': t_dream.std()}

# 4. Lucid dream: noise + weak real signal
signal_strength = 0.3
x_lucid = x_dream * 0.7 + x_awake * signal_strength
t_lucid, f_lucid = compute_tension(engine_a, engine_g, x_lucid)
conditions['lucid'] = {'tension': t_lucid, 'mean': t_lucid.mean(), 'std': t_lucid.std()}

# 5. Nightmare: adversarial (gradient direction to maximize tension)
# Approximate: add noise in direction that maximizes field magnitude
x_nightmare = x_awake.copy()
la, ha = forward(engine_a, x_nightmare)
lg, hg = forward(engine_g, x_nightmare)
field = la - lg
# Move in direction of field (amplify divergence)
grad_approx = np.sign(field) @ engine_a['W2'].T  # rough gradient direction
grad_approx = grad_approx * (ha > 0)  # ReLU mask
grad_input = grad_approx @ engine_a['W1'].T
x_nightmare = x_awake + 2.0 * np.sign(grad_input)  # FGSM-like
t_nightmare, f_nightmare = compute_tension(engine_a, engine_g, x_nightmare)
conditions['nightmare'] = {'tension': t_nightmare, 'mean': t_nightmare.mean(), 'std': t_nightmare.std()}

# --- Report ---
print("=" * 70)
print("H-CX-423: Dream State = Field Hyperactivation")
print("=" * 70)
print(f"\n{'Condition':>12} | {'Mean Tension':>12} | {'Std':>8} | {'Ratio vs Awake':>14}")
print("-" * 55)
awake_mean = conditions['awake']['mean']
for name in ['awake', 'sleep', 'dream', 'lucid', 'nightmare']:
    c = conditions[name]
    ratio = c['mean'] / awake_mean if awake_mean > 0 else 0
    print(f"{name:>12} | {c['mean']:>12.4f} | {c['std']:>8.4f} | {ratio:>14.2f}x")

# Check for distinct clusters
tensions_all = {name: conditions[name]['mean'] for name in conditions}
sorted_t = sorted(tensions_all.items(), key=lambda x: x[1])
print(f"\nOrdered by tension:")
for name, t in sorted_t:
    print(f"  {name}: {t:.4f}")

# Check ratios
print(f"\nKey ratios:")
print(f"  dream/awake:     {conditions['dream']['mean']/awake_mean:.2f}x (RC-10 reference: 4.78x)")
print(f"  nightmare/awake: {conditions['nightmare']['mean']/awake_mean:.2f}x (RC-10 lucid reference: 105x)")
print(f"  sleep/awake:     {conditions['sleep']['mean']/awake_mean:.2f}x")
print(f"  lucid/awake:     {conditions['lucid']['mean']/awake_mean:.2f}x")

# Gap analysis
gap_sleep_awake = abs(conditions['sleep']['mean'] - awake_mean)
gap_awake_dream = abs(conditions['dream']['mean'] - awake_mean)
gap_dream_nightmare = abs(conditions['nightmare']['mean'] - conditions['dream']['mean'])
print(f"\nGap analysis:")
print(f"  sleep<->awake:     {gap_sleep_awake:.4f}")
print(f"  awake<->dream:     {gap_awake_dream:.4f}")
print(f"  dream<->nightmare: {gap_dream_nightmare:.4f}")

# Cluster check: are there clear separations?
values = sorted([conditions[n]['mean'] for n in conditions])
gaps = [values[i+1] - values[i] for i in range(len(values)-1)]
max_gap_idx = np.argmax(gaps)
print(f"\nCluster analysis:")
print(f"  All tensions sorted: {[f'{v:.2f}' for v in values]}")
print(f"  Gaps: {[f'{g:.2f}' for g in gaps]}")
print(f"  Largest gap between position {max_gap_idx} and {max_gap_idx+1}")

n_clusters = sum(1 for g in gaps if g > 0.3 * max(gaps)) + 1
print(f"  Estimated clusters: {n_clusters}")

# ASCII histogram
print("\n--- ASCII: Tension Distribution by Condition ---")
all_tensions = np.concatenate([conditions[n]['tension'] for n in conditions])
hist_max = np.percentile(all_tensions, 95)
hist_min = 0
n_bins = 30

for name in ['awake', 'sleep', 'dream', 'lucid', 'nightmare']:
    t = conditions[name]['tension']
    t_clipped = np.clip(t, hist_min, hist_max)
    hist, edges = np.histogram(t_clipped, bins=n_bins, range=(hist_min, hist_max))
    max_h = max(hist) if max(hist) > 0 else 1
    bar = ""
    for h in hist:
        n_chars = int(h / max_h * 20)
        bar += "#" * n_chars + " " * (20 - n_chars) + "|"
    print(f"\n  {name:>10} (mean={conditions[name]['mean']:.2f}):")
    # Simple version: just show density
    scaled = (hist / max_h * 15).astype(int)
    for row in range(15, -1, -1):
        line = "    |"
        for s in scaled:
            line += "#" if s >= row else " "
        print(line)
    print(f"    +{'=' * n_bins}")

# Save results
save_data = {}
for name in conditions:
    save_data[name] = {
        'mean_tension': float(conditions[name]['mean']),
        'std_tension': float(conditions[name]['std']),
        'ratio_vs_awake': float(conditions[name]['mean'] / awake_mean),
    }
save_data['n_clusters'] = int(n_clusters)

with open('/Users/ghost/Dev/TECS-L/docs/hypotheses/exp_hcx423_results.json', 'w') as f:
    json.dump(save_data, f, indent=2)

print("\nResults saved to exp_hcx423_results.json")
