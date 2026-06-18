#!/usr/bin/env python3
"""ATLAS 🔵 structural harvest — 12-fn basis {sig,sig2,sig3,phi,tau,n,sopfr,rad,J2,psi,Om,om}.
Singleton AB=CD characterizations with target n>=4 (excludes degenerate n=2,3). exact int.
Usage: python3 blue_harvest_12fn.py [N]."""
import itertools, sys
N = int(sys.argv[1]) if len(sys.argv) > 1 else 20000
spf = list(range(N + 1))
for i in range(2, int(N**0.5) + 1):
    if spf[i] == i:
        for j in range(i*i, N+1, i):
            if spf[j] == j: spf[j] = i
def af(n):
    if n == 1: return dict(sig=1,sig2=1,sig3=1,phi=1,tau=1,n=1,sopfr=0,rad=1,J2=1,psi=1,Om=0,om=0)
    m=n; sig=sig2=sig3=tau=phi=psi=J2=1; sopfr=0; rad=1; Om=0; om=0
    while m > 1:
        p=spf[m]; e=0
        while m % p == 0: m//=p; e+=1
        sig*=(p**(e+1)-1)//(p-1); sig2*=(p**(2*(e+1))-1)//(p**2-1); sig3*=(p**(3*(e+1))-1)//(p**3-1)
        tau*=(e+1); phi*=p**(e-1)*(p-1); psi*=p**(e-1)*(p+1)
        J2*=p**(2*e)-p**(2*(e-1)); sopfr+=p*e; rad*=p; Om+=e; om+=1
    return dict(sig=sig,sig2=sig2,sig3=sig3,phi=phi,tau=tau,n=n,sopfr=sopfr,rad=rad,J2=J2,psi=psi,Om=Om,om=om)
F = [None] + [af(n) for n in range(1, N+1)]
keys = ['sig','sig2','sig3','phi','tau','n','sopfr','rad','J2','psi','Om','om']
sym = {'sig':'σ','sig2':'σ₂','sig3':'σ₃','phi':'φ','tau':'τ','n':'n','sopfr':'sopfr','rad':'rad','J2':'J₂','psi':'ψ','Om':'Ω','om':'ω'}
pairs = [(a,b) for i,a in enumerate(keys) for b in keys[i:]]
MIN_N = 4  # exclude degenerate small n (2,3)
atoms = {}
for (a,b),(c,d) in itertools.combinations(pairs, 2):
    sol = []
    for n in range(2, N+1):
        if F[n][a]*F[n][b] == F[n][c]*F[n][d]:
            sol.append(n)
            if len(sol) > 1: break
    if len(sol) == 1 and sol[0] >= MIN_N:
        atoms.setdefault(sol[0], []).append(f"{sym[a]}·{sym[b]}={sym[c]}·{sym[d]}")
total = sum(len(v) for v in atoms.values())
print(f"=== EXPANDED 🔵 HARVEST (12-fn basis, n>={MIN_N}, N={N}) ===")
print(f"structural target numbers: {len(atoms)} · total 🔵 (bounded-unique): {total}")
for x in sorted(atoms):
    print(f"  n={x:>6} : {len(atoms[x])}")
print("STRUCTURAL_TOTAL=%d" % total)
