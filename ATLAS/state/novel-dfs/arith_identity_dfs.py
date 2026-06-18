#!/usr/bin/env python3
"""ATLAS NOVEL 수학 DFS — 산술함수 곱 항등식 A·B = C·D 의 특이 해집합 탐색.
순수 정수연산(부동소수 없음·c2). σφ=nτ⟺{1,6} (M10) 류의 'n=6 유일 특성식'을 DFS로 확장.
함수: σ(sig)·σ₂(sig2)·φ(phi)·τ(tau)·n·sopfr·rad·J₂(Jordan)·ψ(Dedekind)."""
import itertools, sys
N = int(sys.argv[1]) if len(sys.argv) > 1 else 200000
spf = list(range(N + 1))
for i in range(2, int(N**0.5) + 1):
    if spf[i] == i:
        for j in range(i*i, N+1, i):
            if spf[j] == j: spf[j] = i
def afuncs(n):
    if n == 1: return dict(sig=1, sig2=1, phi=1, tau=1, n=1, sopfr=0, rad=1, J2=1, psi=1)
    m=n; sig=sig2=tau=phi=psi=J2=1; sopfr=0; rad=1
    while m > 1:
        p=spf[m]; e=0
        while m % p == 0: m//=p; e+=1
        sig*=(p**(e+1)-1)//(p-1); sig2*=(p**(2*(e+1))-1)//(p**2-1)
        tau*=(e+1); phi*=p**(e-1)*(p-1); psi*=p**(e-1)*(p+1)
        J2*=p**(2*e)-p**(2*(e-1)); sopfr+=p*e; rad*=p
    return dict(sig=sig, sig2=sig2, phi=phi, tau=tau, n=n, sopfr=sopfr, rad=rad, J2=J2, psi=psi)
F = {n: afuncs(n) for n in range(1, N+1)}
keys = ['sig','sig2','phi','tau','n','sopfr','rad','J2','psi']
pairs = [(a,b) for i,a in enumerate(keys) for b in keys[i:]]
target = [6]   # n=6 unique characterizations
found = []
for (a,b),(c,d) in itertools.combinations(pairs, 2):
    sol=[]
    for n in range(2, N+1):
        if F[n][a]*F[n][b] == F[n][c]*F[n][d]:
            sol.append(n)
            if sol != target[:len(sol)]: break
    if sol == target: found.append(f"{a}·{b} = {c}·{d}")
print(f"n=6 UNIQUE characterizations in [2,{N}]: {len(found)}")
for f in found: print(f"  {f}  ⟺ n=6")
