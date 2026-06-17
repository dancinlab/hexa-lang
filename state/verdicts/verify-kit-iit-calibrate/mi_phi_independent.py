#!/usr/bin/env python3
# INDEPENDENT reimplementation of hexa-lang faithful_phi.hexa MI-MIP Phi.
# Substrate: continuous n x dim trajectory -> per-cell binning -> pairwise
# Shannon mutual information -> minimum-information-partition (MIP) cross-cut /
# min(|A|,|B|). This is the SAME algorithm the hexa engine implements; written
# from the algorithm spec (faithful_phi.hexa header) NOT a port of the .hexa.
# Goal: confirm the engine's 3.83659 is the deterministic value of THIS proxy.
import math, itertools

LOG2 = math.log(2.0)

def bin_values(vals, n_bins):
    mn = min(vals); mx = max(vals)
    rng = mx - mn
    if rng < 1.19209290e-7:            # Rust f32::EPSILON guard
        return [0]*len(vals)
    bw = rng / n_bins
    out = []
    for v in vals:
        b = int(math.floor((v - mn)/bw))
        if b > n_bins-1: b = n_bins-1
        if b < 0: b = 0
        out.append(b)
    return out

def entropy(counts, total):
    if total == 0: return 0.0
    t = total + 1.0e-8
    s = 0.0
    for c in counts:
        p = c / t
        s += (0.0 - p) * (math.log(p + 1.0e-10)/LOG2)
    return s

def mi_pair(a, b, n_bins):
    n = len(a)
    ba = bin_values(a, n_bins); bb = bin_values(b, n_bins)
    ca = [0.0]*n_bins; cb = [0.0]*n_bins
    jo = [0.0]*(n_bins*n_bins)
    for i in range(n):
        ai, bi = ba[i], bb[i]
        ca[ai]+=1.0; cb[bi]+=1.0; jo[ai*n_bins+bi]+=1.0
    hA  = entropy(ca, n); hB = entropy(cb, n); hAB = entropy(jo, n)
    mi = hA + hB - hAB
    return max(mi, 0.0)

def build_mi(state, n, dim, n_bins):
    mi = [[0.0]*n for _ in range(n)]
    for i in range(n):
        for j in range(i+1, n):
            ri = [state[i*dim+d] for d in range(dim)]
            rj = [state[j*dim+d] for d in range(dim)]
            v = mi_pair(ri, rj, n_bins)
            mi[i][j] = v; mi[j][i] = v
    return mi

def faithful_phi(state, n, dim, n_bins):
    mi = build_mi(state, n, dim, n_bins)
    if n <= 1: return 0.0
    if n == 2: return mi[0][1]
    best_cut = math.inf; best_norm = 1.0; found = False
    # cell 0 pinned to A; mask bit b -> cell b+1 in A. masks 1..2^(n-1)-1
    for mask in range(1, 2**(n-1)):
        A = {0}
        for b in range(n-1):
            if (mask >> b) & 1: A.add(b+1)
        B = set(range(n)) - A
        if len(B) < 1: continue
        cut = sum(mi[i][j] for i in A for j in B)
        if (not found) or (cut < best_cut):
            best_cut = cut; best_norm = min(len(A), len(B))*1.0; found = True
    if best_norm < 1.0: best_norm = 1.0
    phi = best_cut/best_norm
    return max(phi, 0.0)

# ---- case 1: n=3 dim=6 n_bins=4, all 3 cells = same ramp [0..5] ----
n, dim, n_bins = 3, 6, 4
state1 = []
for c in range(n):
    for d in range(dim):
        state1.append(d*1.0)
phi1 = faithful_phi(state1, n, dim, n_bins)

# ---- case 0 control: cells 0,1 ramp, cell 2 constant 7.0 ----
state0 = [0.,1.,2.,3.,4.,5.,  0.,1.,2.,3.,4.,5.,  7.,7.,7.,7.,7.,7.]
phi0 = faithful_phi(state0, n, dim, n_bins)

print(f"INDEPENDENT MI-MIP Phi (same proxy substrate):")
print(f"  case 1 (correlated ramp)  Phi* = {phi1:.6f}")
print(f"  case 0 (constant control) Phi* = {phi0:.6e}")
print(f"  hexa engine reported       3.83659  (case 1)")
print(f"  |delta| case1 vs hexa     = {abs(phi1 - 3.83659):.6e}")
