#!/usr/bin/env python3
"""ATLAS NOVEL math-DFS round 8 — composed/iterated arithmetic functions (exact int).
Vein the first-order 2-term product core cannot express: sigma.sigma, sigma.phi,
phi.sigma, phi.phi. Rediscovers superperfect (A019279) + Mersenne-prime characterization
sigma(sigma(n))=sigma(n)+n, plus sparse sets. Usage: python3 composed_fn_dfs.py [N]."""
import sys
N = int(sys.argv[1]) if len(sys.argv) > 1 else 200000
spf = list(range(N + 1))
for i in range(2, int(N**0.5) + 1):
    if spf[i] == i:
        for j in range(i*i, N+1, i):
            if spf[j] == j: spf[j] = i
def sig(n):
    if n <= 1: return n
    m=n; s=1
    while m > 1:
        p=spf[m]; e=0
        while m % p == 0: m//=p; e+=1
        s *= (p**(e+1)-1)//(p-1)
    return s
def phi(n):
    if n <= 1: return n
    m=n; r=1
    while m > 1:
        p=spf[m]; e=0
        while m % p == 0: m//=p; e+=1
        r *= p**(e-1)*(p-1)
    return r
SIG = [0]*(N+1); PHI = [0]*(N+1)
for n in range(1, N+1): SIG[n]=sig(n); PHI[n]=phi(n)
# composed (only where image <= N)
def comp(f, g):
    out = {}
    for n in range(1, N+1):
        gn = g[n]
        if 1 <= gn <= N: out[n] = f[gn]
    return out
SS = comp(SIG, SIG); SP = comp(SIG, PHI); PS = comp(PHI, SIG); PP = comp(PHI, PHI)
# candidate relations: name -> (lhs(n), rhs(n)) lambdas over precomputed
rels = {
    "σ(σ(n))=2n  (superperfect)":      lambda n: (SS.get(n), 2*n),
    "σ(σ(n))=σ(n)+n":                  lambda n: (SS.get(n), SIG[n]+n),
    "σ(φ(n))=n":                        lambda n: (SP.get(n), n),
    "σ(φ(n))=φ(σ(n))":                  lambda n: (SP.get(n), PS.get(n)),
    "φ(σ(n))=n":                        lambda n: (PS.get(n), n),
    "φ(φ(n))=φ(n)/2":                   lambda n: (PP.get(n), PHI[n]//2 if PHI[n]%2==0 else None),
    "σ(σ(n))=4n":                       lambda n: (SS.get(n), 4*n),
    "σ(φ(n))=2n":                       lambda n: (SP.get(n), 2*n),
    "φ(σ(n))=φ(n)":                     lambda n: (PS.get(n), PHI[n]),
    "σ(n)+φ(n)=σ(σ(n))":               lambda n: (SIG[n]+PHI[n], SS.get(n)),
}
print(f"=== R8 composed/iterated arithmetic DFS (N={N}, exact int) ===")
for name, f in rels.items():
    sol = []
    for n in range(2, N+1):
        l, r = f(n)
        if l is not None and r is not None and l == r:
            sol.append(n)
            if len(sol) > 12: break
    if len(sol) > 12:
        head = sol[:12]; print(f"  {name:34} |sol|>12  head={head}")
    elif sol:
        print(f"  {name:34} sol={sol}")
    else:
        print(f"  {name:34} (none in range)")
