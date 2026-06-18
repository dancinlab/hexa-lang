#!/usr/bin/env python3
"""ATLAS 🔵 harvest — bounded-unique singleton characterizations (exact int).
For each AB=CD over the 9-fn basis with solution set = exactly one n in [2,N],
records it as a bounded-unique (🔵) characterization atom. Usage: python3 blue_harvest.py [N]."""
import itertools, sys
N = int(sys.argv[1]) if len(sys.argv) > 1 else 50000
spf = list(range(N + 1))
for i in range(2, int(N**0.5) + 1):
    if spf[i] == i:
        for j in range(i*i, N+1, i):
            if spf[j] == j: spf[j] = i
def af(n):
    if n == 1: return dict(sig=1, sig2=1, phi=1, tau=1, n=1, sopfr=0, rad=1, J2=1, psi=1)
    m=n; sig=sig2=tau=phi=psi=J2=1; sopfr=0; rad=1
    while m > 1:
        p=spf[m]; e=0
        while m % p == 0: m//=p; e+=1
        sig*=(p**(e+1)-1)//(p-1); sig2*=(p**(2*(e+1))-1)//(p**2-1)
        tau*=(e+1); phi*=p**(e-1)*(p-1); psi*=p**(e-1)*(p+1)
        J2*=p**(2*e)-p**(2*(e-1)); sopfr+=p*e; rad*=p
    return dict(sig=sig, sig2=sig2, phi=phi, tau=tau, n=n, sopfr=sopfr, rad=rad, J2=J2, psi=psi)
F = [None] + [af(n) for n in range(1, N+1)]
keys = ['sig','sig2','phi','tau','n','sopfr','rad','J2','psi']
pairs = [(a,b) for i,a in enumerate(keys) for b in keys[i:]]
sym = {'sig':'σ','sig2':'σ₂','phi':'φ','tau':'τ','n':'n','sopfr':'sopfr','rad':'rad','J2':'J₂','psi':'ψ'}
def fmt(a,b,c,d): return f"{sym[a]}·{sym[b]} = {sym[c]}·{sym[d]}"
# harvest: AB=CD with singleton solution set in [2,N]
atoms = {}  # n -> list of identity strings
for (a,b),(c,d) in itertools.combinations(pairs, 2):
    sol = []
    for n in range(2, N+1):
        if F[n][a]*F[n][b] == F[n][c]*F[n][d]:
            sol.append(n)
            if len(sol) > 1: break
    if len(sol) == 1:
        atoms.setdefault(sol[0], []).append(fmt(a,b,c,d))
total = sum(len(v) for v in atoms.values())
print(f"=== HARVEST: singleton AB=CD characterizations (N={N}) ===")
print(f"distinct target numbers: {len(atoms)} · total identities (🔵 bounded-unique): {total}")
for x in sorted(atoms):
    print(f"  n={x:>6} : {len(atoms[x])} ident — {'; '.join(atoms[x][:4])}{' …' if len(atoms[x])>4 else ''}")
