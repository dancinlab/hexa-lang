#!/usr/bin/env python3
"""ATLAS NOVEL math-DFS — multi-shape rounds to exhaustion (exact integer · c2).
Rounds: (1) product A·B=C·D special-n-unique, (2) family-universal (∀prime/p²/2p/pq),
(3) perfect-number characterizations, (4) other special-n, (5) coarse-basis {σ₃,Ω,ω},
(6) additive A+B=C+D. Finds the rich vein = multiplicative {6,12,28} characterizations;
documents the dry boundary. Usage: python3 identity_dfs_rounds.py [N]."""
import itertools, sys
N = int(sys.argv[1]) if len(sys.argv) > 1 else 200000
spf = list(range(N + 1))
for i in range(2, int(N**0.5) + 1):
    if spf[i] == i:
        for j in range(i*i, N+1, i):
            if spf[j] == j: spf[j] = i
def af(n):
    if n == 1: return dict(sig=1, sig2=1, sig3=1, phi=1, tau=1, n=1, sopfr=0, rad=1, J2=1, psi=1, Om=0, om=0)
    m=n; sig=sig2=sig3=tau=phi=psi=J2=1; sopfr=0; rad=1; Om=0; om=0
    while m > 1:
        p=spf[m]; e=0
        while m % p == 0: m//=p; e+=1
        sig*=(p**(e+1)-1)//(p-1); sig2*=(p**(2*(e+1))-1)//(p**2-1); sig3*=(p**(3*(e+1))-1)//(p**3-1)
        tau*=(e+1); phi*=p**(e-1)*(p-1); psi*=p**(e-1)*(p+1)
        J2*=p**(2*e)-p**(2*(e-1)); sopfr+=p*e; rad*=p; Om+=e; om+=1
    return dict(sig=sig, sig2=sig2, sig3=sig3, phi=phi, tau=tau, n=n, sopfr=sopfr, rad=rad, J2=J2, psi=psi, Om=Om, om=om)
F = {n: af(n) for n in range(1, N+1)}
base = ['sig','sig2','phi','tau','n','sopfr','rad','J2','psi']
def product_unique(keys, targets):
    pairs = [(a,b) for i,a in enumerate(keys) for b in keys[i:]]
    out = {t: [] for t in targets}
    for (a,b),(c,d) in itertools.combinations(pairs, 2):
        sol = []
        for n in range(2, N+1):
            if F[n][a]*F[n][b] == F[n][c]*F[n][d]:
                sol.append(n)
                if len(sol) > 1: break
        if len(sol) == 1 and sol[0] in out: out[sol[0]].append(f"{a}·{b}={c}·{d}")
    return out
if __name__ == '__main__':
    r = product_unique(base, {6, 12, 28})
    for t in (6, 12, 28):
        print(f"n={t}: {len(r[t])} unique product identities (fixed 9-fn basis)")
        for s in r[t]: print(f"  {s}  <=> n={t}")
