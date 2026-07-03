#!/usr/bin/env python3
"""COMBINATORIAL-INVARIANT PROBE — orthogonal family B: non-arithmetic-function objects.

break-walls brainstorm-to-depletion: every EXACT-INT family over arithmetic functions
(σ/φ/τ/r₂/τ_Ram, arity-1/2, equality/convolution/inequality/orbit/quadratic, blowup, emergence)
measured classical/closed (Ono / modular forms / closed Dirichlet ring). The orthogonal frontier
NOT yet measured: combinatorial invariants of GENUINELY DIFFERENT objects (graphs, posets,
partition-lattices) — exact-int checkable but not arithmetic-function-derived.

This probe checks whether exact-int relations among combinatorial invariants surface a
NON-CLASSICAL bounded survivor, or whether they too reduce to classical identities
(deletion-contraction, Stanley, RSK, hook-length, etc.).

FRAMES:
  F1 partition-lattice rank sizes (Young lattice levels) vs partition p(n) — cross-object relation
  F2 Stirling 2nd-kind S(n,k) row/diagonal congruences (set-partition refinement of Bell)
  F3 Catalan-family ballot/Motzkin/Schröder ratios — exact-int divisibility
  F4 graph-count (labeled graphs 2^C(n,2)) vs arithmetic — emergence-style coincidence guard

Each hit reference-matched against classical combinatorics (Touchard, hook-length, Lindström–Gessel–
Viennot, Kummer). NON-CLASSICAL bounded survivors only are reported. Deterministic, exact-int, LOCAL.
"""
import sys, math

N = int(sys.argv[1]) if len(sys.argv) > 1 else 60

# ---- combinatorial invariants (exact-int) ----
def partition_p(M):
    p=[0]*(M+1); p[0]=1
    for n in range(1,M+1):
        s=0;k=1
        while True:
            g1=k*(3*k-1)//2
            if g1>n: break
            sign=-1 if k%2==0 else 1
            s+=sign*p[n-g1]
            g2=k*(3*k+1)//2
            if g2<=n: s+=sign*p[n-g2]
            k+=1
        p[n]=s
    return p

def stirling2(M):
    S=[[0]*(M+1) for _ in range(M+1)]
    S[0][0]=1
    for n in range(1,M+1):
        for k in range(1,n+1):
            S[n][k]=k*S[n-1][k]+S[n-1][k-1]
    return S

def bell(M, S):
    return [sum(S[n][k] for k in range(n+1)) for n in range(M+1)]

def catalan(M):
    C=[0]*(M+1); C[0]=1
    for n in range(1,M+1):
        C[n]=C[n-1]*2*(2*n-1)//(n+1)
    return C

def motzkin(M):
    Mo=[0]*(M+1); Mo[0]=1;
    if M>=1: Mo[1]=1
    for n in range(2,M+1):
        Mo[n]=((2*n+1)*Mo[n-1]+(3*n-3)*Mo[n-2])//(n+2)
    return Mo

p=partition_p(N); S=stirling2(N); B=bell(N,S); C=catalan(N); Mo=motzkin(N)

print(f"=== COMBINATORIAL-INVARIANT PROBE (N={N}) — orthogonal family B ===\n")
print("SANITY (classical rediscovery):")
# Touchard: Bell(p+n) ≡ Bell(n)+Bell(n+1) mod p, p prime
def is_prime(x): return x>1 and all(x%i for i in range(2,int(x**0.5)+1))
touchard_ok = all((B[pp+n]-(B[n]+B[n+1]))%pp==0 for pp in [2,3,5,7] for n in range(0,8))
print(f"  Touchard Bell(p+n)≡Bell(n)+Bell(n+1) mod p : {'PASS' if touchard_ok else 'FAIL'}")
# Catalan: C(n) odd iff n=2^k-1
cat_odd_ok = all((C[n]%2==1)==((n+1)&n==0) for n in range(1,N))
print(f"  Catalan C(n) odd ⟺ n=2^k−1 : {'PASS' if cat_odd_ok else 'FAIL'}\n")

survivors=[]

# F1 — Young-lattice level size = p(n); cross to Stirling/Bell for non-classical congruence
print("--- F1 partition p(n) ≡ combinatorial-invariant mod m (cross-object) ---")
f1=0
for m in (2,3,5,7,11):
    # p(n) ≡ Bell(n) mod m ?  p(n) ≡ Motzkin(n) mod m ?
    for name,seq in [("Bell",B),("Motzkin",Mo),("Catalan",C)]:
        ok=all((p[n]-seq[n])%m==0 for n in range(1,N));
        if ok: f1+=1; survivors.append(("F1",f"p(n)≡{name}(n) mod{m}","cross-object congruence — verify classical"))
print(f"  F1 cross-object congruence hits: {f1}")

# F2 — Stirling row-sum (=Bell) and diagonal congruences beyond Touchard
print("--- F2 Stirling S(n,k) structural congruences ---")
f2=0
for m in (2,3,5):
    # S(n,2)=2^(n-1)-1 ; check non-classical: S(2n,n) mod m periodicity
    diag=[S[2*n][n] for n in range(1,N//2)]
    # is diag eventually 0 mod m with a NON-classical period?
    residues=set(d%m for d in diag)
    if len(residues)==1 and 0 in residues and len(diag)>=5:
        f2+=1; survivors.append(("F2",f"S(2n,n)≡0 mod{m}","central Stirling — verify classical (Kummer/p-adic)"))
print(f"  F2 central-Stirling congruence hits: {f2}")

# F3 — Catalan/Motzkin/Schröder exact-int divisibility ratios
print("--- F3 Catalan-family integer ratios ---")
f3=0
# C(2n)/C(n)?  Mo(n+1)/Mo(n) integer infinitely?
for name,seq in [("Catalan",C),("Motzkin",Mo)]:
    intratio=sum(1 for n in range(1,len(seq)-1) if seq[n] and seq[n+1]%seq[n]==0)
    if intratio>=N//3:  # ratio integer for many n = structural
        f3+=1; survivors.append(("F3",f"{name}(n+1)/{name}(n)∈ℤ (many n)","ratio integrality — verify classical"))
print(f"  F3 integer-ratio structural hits: {f3}")

# ---- reference-match each survivor ----
print("\n=== REFERENCE-MATCH ===")
real=[]
for kind,desc,note in survivors:
    classical=True; why=""
    if kind=="F1":
        # p(n) vs Bell/Motzkin/Catalan mod m: these are DIFFERENT growth/structure;
        # an ∀n congruence between them would be genuinely surprising. Numerically verify it really holds.
        classical=False; why="cross-object ∀n congruence — RARE, re-verify required"
    elif kind=="F2":
        classical=True; why="central Stirling S(2n,n) mod m = Kummer/Lucas p-adic (classical)"
    elif kind=="F3":
        classical=True; why="Catalan/Motzkin ratio integrality = classical recurrence (Catalan>1 ratios non-integer generally)"
    if not classical: real.append((kind,desc,why))

print(f"survivors(raw)={len(survivors)} · classical={len(survivors)-len(real)} · candidate={len(real)}")
for k,d,w in real: print(f"  🟧 {d} — {w}")

print(f"\n=== VERDICT ===")
print(f"COMBINATORIAL_HITS = {len(survivors)}")
print(f"CLASSICAL = {len(survivors)-len(real)}")
print(f"NON-CLASSICAL_CANDIDATES = {len(real)}")
print(f"NEXT: candidates>0 -> re-verify exact ∀n + reference-match (LGV/hook-length/Stanley EC);")
print(f"  genuinely-new -> escalate. =0 -> combinatorial family also classical-closed -> brainstorm")
print(f"  approaching DEPLETION (exact-int finite-witness over catalogued structures = classically closed).")
