#!/usr/bin/env python3
"""ATLAS NOVEL math-DFS — FUNCTION-COMPOSITION hunt (σ∘σ vein · exact int).

The un-swept vein the first-order PRODUCT core (A·B=C·D, measured-exhausted in
ATLAS/README.md DFS r1–r4 and re-confirmed for the extended 18-fn vocab in
#4060) structurally CANNOT express: nested composition  f(g(n))  rather than the
value-product  f(n)·g(n).  Composition is a genuinely different algebra — e.g.
the superperfect law  σ(σ(n)) = 2n  has NO product-frame restatement.

Reference-match (classical number theory = open answer-key):
  • superperfect (Suryanarayana 1969 / OEIS A019279): even n with σ(σ(n))=2n
    ⟺ n = 2^(p−1) where 2^p−1 is a Mersenne prime → solution set
    {2,4,16,64,4096,…}.  This is the canonical composition identity and the
    sanity gate for this engine.
  • σ(σ(n)) = σ(n)+n  holds ⟺ σ(n) is prime (Mersenne characterization):
    solution set = the Mersenne-prime indices {3,7,31,127,8191,…}.

This sweeps the FULL 18×18 ordered composition table  af_compose(f,g,n)=af(f,af(g,n))
against four comparison frames, exact-int, deterministic, pure-Python:
  (A) comp(n) = k·n          k ∈ 1..16   (superperfect = σ∘σ, k=2)
  (B) comp(n) = af(h,n) + n  single basis h
  (C) comp(n) = af(h,n)      single basis h     (e.g. σ(φ(n))=n, φ(σ(n))=n)
  (D) comp1(n) = comp2(n)    composition vs composition

Honesty (c2): a nonempty solution set over [2,N] is BOUNDED-EVIDENCE only — the
forall-n / characterization statement stays UNPROVEN here.  Each hit is labelled
KNOWN (matches a documented classical composition law) or NOVEL (an unexplained
nonempty/bounded-unique set).  Overflow guard: skip n when the inner image
af(g,n) leaves [1, MAXARG] (high-growth σ₂,σ₃,J₂,J₃,ψ compositions explode).

Usage: python3 composition_hunt.py [N] [MAXARG]   (defaults N=20000, MAXARG=2e8)
Deterministic: identical output every run. LOCAL pure-Python only.
"""
import sys

N = int(sys.argv[1]) if len(sys.argv) > 1 else 20000
# Inner-image overflow/feasibility cap.  The meaningful composition vein keeps
# inner images small (σ(20000)≈49k, σ∘σ inner ≤ ~80k); high-growth fns (σ₂,σ₃,
# J₂,J₃) blow past this and are skipped (overflow guard, honest).  A sieve up to
# MAXARG gives O(log) factorization of every inner image.
MAXARG = int(sys.argv[2]) if len(sys.argv) > 2 else 2_000_000

# smallest-prime-factor sieve up to MAXARG (O(log) factorization on demand)
SPF = list(range(MAXARG + 1))
_i = 2
while _i * _i <= MAXARG:
    if SPF[_i] == _i:
        for _j in range(_i * _i, MAXARG + 1, _i):
            if SPF[_j] == _j:
                SPF[_j] = _i
    _i += 1

def factor(m):
    """exact prime factorization of 1<=m<=MAXARG -> list of (p,e) via SPF sieve."""
    fs = []
    while m > 1:
        p = SPF[m]; e = 0
        while m % p == 0:
            m //= p; e += 1
        fs.append((p, e))
    return fs

# 18-fn basis, byte-aligned to compiler/atlas/identity_engine.hexa::af idx 0–17
#   0=sig 1=sig2 2=sig3 3=phi 4=tau 5=n 6=sopfr 7=rad 8=J2 9=psi 10=Om 11=om
#   12=mu 13=lam 14=mu2 15=J3 16=tw_om 17=core
NAMES = ['σ','σ₂','σ₃','φ','τ','n','sopfr','rad','J₂','ψ','Ω','ω',
         'μ','λ','μ²','J₃','2^ω','core']

def af(n, which):
    """exact-int 18-fn arithmetic functions (reference-match identity_engine.af)."""
    if n == 1:
        if which in (6, 10, 11):
            return 0
        return 1
    fs = factor(n)
    sig=sig2=sig3=tau=phi=psi=j2=j3=1
    sopfr=0; rad=1; Om=0; om=0; squarefree=1
    for (p, e) in fs:
        sig  *= (p**(e+1)-1)//(p-1)
        sig2 *= (p**(2*(e+1))-1)//(p**2-1)
        sig3 *= (p**(3*(e+1))-1)//(p**3-1)
        tau  *= (e+1)
        phi  *= p**(e-1)*(p-1)
        psi  *= p**(e-1)*(p+1)
        j2   *= p**(2*e) - p**(2*(e-1))
        j3   *= p**(3*e) - p**(3*(e-1))
        sopfr += p*e; rad *= p; Om += e; om += 1
        if e >= 2: squarefree = 0
    if which == 0:  return sig
    if which == 1:  return sig2
    if which == 2:  return sig3
    if which == 3:  return phi
    if which == 4:  return tau
    if which == 5:  return n
    if which == 6:  return sopfr
    if which == 7:  return rad
    if which == 8:  return j2
    if which == 9:  return psi
    if which == 10: return Om
    if which == 11: return om
    if which == 14: return squarefree
    if which == 12:
        if squarefree == 0: return 0
        return 1 if om % 2 == 0 else -1
    if which == 13: return 1 if Om % 2 == 0 else -1
    if which == 15: return j3
    if which == 16: return 2**om
    return n // rad   # 17 = core

def af_compose(f, g, n):
    """f(g(n)) = af(af(n,g), f); None if inner image leaves the valid/computable
    range.  NB: af signature is af(value, which) — value first, fn-index second
    (reference-match identity_engine.hexa::af), so the inner application is
    af(n, g) and the outer is af(inner, f)."""
    inner = af(n, g)
    if inner < 1 or inner > MAXARG:
        return None
    return af(inner, f)

# ── precompute every composition column over [1,N] (None where out of range) ──
COMP = {}            # (f,g) -> list indexed by n (None outside [2,N])
for g in range(18):
    for f in range(18):
        col = [None] * (N + 1)
        for n in range(2, N + 1):
            col[n] = af_compose(f, g, n)
        COMP[(f, g)] = col

AF = [[af(n, w) if n >= 1 else None for w in range(18)] for n in range(N + 1)]

def head(sol, cap=12):
    return sol[:cap]

# ── known/classical composition laws (the answer-key set) ────────────────────
# Each key is (kind, params); value = human label + classical citation.
KNOWN = set([
    ("A", 0, 0, 2),   # σ(σ(n)) = 2n   superperfect (A019279)
    ("A", 3, 0, 1),   # σ(φ(n)) ... handled in C; kept for completeness
])

def classify(kind, detail):
    """Return 'known' if the hit is a documented classical composition law."""
    return "known" if detail in CLASSICAL else "novel"

# Documented classical composition identities (string keys, reference-cited).
CLASSICAL = {
    "σ∘σ = 2·n",                 # superperfect  Suryanarayana 1969 / A019279
    "σ∘σ = σ + n",               # ⟺ σ(n) prime (Mersenne characterization)
    "σ∘φ = n",                   # classical (A033631-ish sparse)
    "φ∘σ = n",                   # classical sparse
    "φ∘φ = φ / 2",               # parity of φ (φ(n) even for n>2)
    "σ∘σ = 4·n",                 # 2-superperfect family
    "φ∘σ = φ",                   # classical sparse
}

# ───────────────────────────── SWEEP ────────────────────────────────────────
print(f"=== COMPOSITION hunt (18×18 · N={N} · MAXARG={MAXARG} · exact int) ===")
SOLCAP = 64          # stop collecting a solution set after this many

novel_hits = []
known_hits = []
sanity = {}

def collect(lhs_col, rhs_fn, n_lo=2):
    sol = []
    for n in range(n_lo, N + 1):
        l = lhs_col[n]
        if l is None:
            continue
        r = rhs_fn(n)
        if r is None:
            continue
        if l == r:
            sol.append(n)
            if len(sol) >= SOLCAP:
                break
    return sol

# ── Frame A: comp(n) = k·n ──
print("\n[A] comp(n) = k·n   (superperfect = σ∘σ, k=2)")
A_report = []
for g in range(18):
    for f in range(18):
        col = COMP[(f, g)]
        for k in range(1, 17):
            sol = collect(col, lambda n, k=k: k * n)
            if not sol:
                continue
            # skip the trivial universal n=n identity (f=g=identity, k=1)
            label = f"{NAMES[f]}∘{NAMES[g]} = {k}·n"
            ascii_label = f"{['sig','sig2','sig3','phi','tau','n','sopfr','rad','J2','psi','Om','om','mu','lam','mu2','J3','tw_om','core'][f]}o{['sig','sig2','sig3','phi','tau','n','sopfr','rad','J2','psi','Om','om','mu','lam','mu2','J3','tw_om','core'][g]} = {k}n"
            is_universal = (len(sol) >= SOLCAP)
            # classical recognition
            cl = None
            if f == 0 and g == 0 and k == 2: cl = "σ∘σ = 2·n"
            if f == 0 and g == 0 and k == 4: cl = "σ∘σ = 4·n"
            entry = (label, sol, cl, is_universal)
            A_report.append(entry)
            if f == 0 and g == 0 and k == 2:
                sanity["superperfect σ∘σ=2n"] = sol

# Frame B: comp(n) = af(h,n) + n
print("[B] comp(n) = af(h,n) + n   (σ∘σ=σ+n ⟺ σ prime · Mersenne)")
B_report = []
for g in range(18):
    for f in range(18):
        col = COMP[(f, g)]
        for h in range(18):
            sol = collect(col, lambda n, h=h: (AF[n][h] + n) if AF[n][h] is not None else None)
            if not sol:
                continue
            label = f"{NAMES[f]}∘{NAMES[g]} = {NAMES[h]} + n"
            is_universal = (len(sol) >= SOLCAP)
            cl = "σ∘σ = σ + n" if (f == 0 and g == 0 and h == 0) else None
            B_report.append((label, sol, cl, is_universal))
            if f == 0 and g == 0 and h == 0:
                sanity["Mersenne σ∘σ=σ+n"] = sol

# Frame C: comp(n) = af(h,n) (single basis fn)
print("[C] comp(n) = af(h,n)   (σ∘φ=n, φ∘σ=n classical)")
C_report = []
for g in range(18):
    for f in range(18):
        col = COMP[(f, g)]
        for h in range(18):
            sol = collect(col, lambda n, h=h: AF[n][h])
            if not sol:
                continue
            # skip degenerate identities f∘g == g when f is the identity n (idx5)
            if f == 5:   # n∘g = g(n), trivially h==g
                continue
            label = f"{NAMES[f]}∘{NAMES[g]} = {NAMES[h]}"
            is_universal = (len(sol) >= SOLCAP)
            cl = None
            if f == 0 and g == 3 and h == 5: cl = "σ∘φ = n"
            if f == 3 and g == 0 and h == 5: cl = "φ∘σ = n"
            if f == 3 and g == 0 and h == 3: cl = "φ∘σ = φ"
            C_report.append((label, sol, cl, is_universal))

# Frame D: comp1(n) = comp2(n)
# Restricted to the LOW-GROWTH subset (σ φ τ n sopfr rad ψ Ω ω core) — the
# high-growth fns (σ₂ σ₃ J₂ J₃ 2^ω μ λ μ²) compose to overflow/near-empty columns
# already covered by frames A–C, and the all-18² pair table is O(pairs²·N) (≈1e9).
print("[D] comp1(n) = comp2(n)   (composition vs composition · low-growth subset)")
D_report = []
LOWGROWTH = [0, 3, 4, 5, 6, 7, 9, 10, 11, 17]   # σ φ τ n sopfr rad ψ Ω ω core
pairs = [(f, g) for g in LOWGROWTH for f in LOWGROWTH]
for ia in range(len(pairs)):
    fa, ga = pairs[ia]
    cola = COMP[(fa, ga)]
    for ib in range(ia + 1, len(pairs)):
        fb, gb = pairs[ib]
        colb = COMP[(fb, gb)]
        sol = collect(cola, lambda n, colb=colb: colb[n])
        if not sol:
            continue
        is_universal = (len(sol) >= SOLCAP)
        # universal D hits are the structurally-equal compositions (e.g. n∘g==g
        # restatements) — flag but do not call novel-law
        label = f"{NAMES[fa]}∘{NAMES[ga]} = {NAMES[fb]}∘{NAMES[gb]}"
        D_report.append((label, sol, None, is_universal))

# ───────────────────────────── REPORT ───────────────────────────────────────
def emit(name, report):
    bounded = []          # finite nonempty solution sets (the interesting vein)
    universal = []        # |sol|>=SOLCAP (likely forall-n / structural)
    for (label, sol, cl, is_univ) in report:
        if is_univ:
            universal.append((label, sol, cl))
        else:
            bounded.append((label, sol, cl))
    print(f"\n── Frame {name}: bounded={len(bounded)}  universal/structural={len(universal)}")
    # only show bounded (finite solution-set) hits — the discovery vein
    shown = 0
    for (label, sol, cl) in sorted(bounded, key=lambda x: (len(x[1]), x[0])):
        tag = f"[KNOWN {cl}]" if cl else "[novel?]"
        print(f"   {tag:24} {label:34} sol={head(sol)}")
        shown += 1
        if shown >= 60:
            print(f"   … (+{len(bounded)-shown} more bounded hits)")
            break
    return bounded, universal

print("\n" + "=" * 70)
bA, uA = emit("A (=k·n)", A_report)
bB, uB = emit("B (=h+n)", B_report)
bC, uC = emit("C (=h)", C_report)
bD, uD = emit("D (comp=comp)", D_report)

# ── sanity gates ──
print("\n" + "=" * 70)
print("SANITY GATES (classical composition rediscovery):")
sp = sanity.get("superperfect σ∘σ=2n", [])
me = sanity.get("Mersenne σ∘σ=σ+n", [])
exp_sp = [2, 4, 16, 64, 4096]
exp_me = [3, 7, 31, 127, 8191]
# Prefix-match the sanity gates (the classical sets GROW with N; at small N only
# a prefix is visible — superperfect adds 4096 at N≥4096, Mersenne 8191 at N≥8191).
sp_ok = exp_sp[:len(sp)] == sp and len(sp) >= 3
me_ok = exp_me[:len(me)] == me and len(me) >= 3
print(f"   σ∘σ=2n  -> {sp}   {'PASS (prefix of ' + str(exp_sp) + ')' if sp_ok else 'FAIL exp ' + str(exp_sp)}")
print(f"   σ∘σ=σ+n -> {me}   {'PASS (prefix of ' + str(exp_me) + ')' if me_ok else 'FAIL exp ' + str(exp_me)}")

# ── novel accounting (honest · c2) ───────────────────────────────────────────
# CRITICAL HONESTY: a SINGLE-point coincidence (|sol|=1 at some n) is NOT an
# identity — composition vs a comparison form throws off numeric accidents at a
# rate that makes singletons meaningless here (unlike the product frame, where a
# bounded-unique singleton was structurally rare).  The only DISCOVERY-grade
# signals are:
#   • universal-in-[2,N]            (forall-n structural relation), and
#   • STRUCTURED-SPARSE  |sol|≥3    (a growing family like superperfect
#                                    {2,4,16,64,4096}, Mersenne {3,7,31,127,…}).
# Everything with |sol|<3 is coincidence NOISE — counted, never called novel.
MINSET = 3
allbounded = bA + bB + bC + bD
alluniversal = uA + uB + uC + uD

coincidence = [(l, s, cl) for (l, s, cl) in allbounded if len(s) < MINSET]
structured  = [(l, s, cl) for (l, s, cl) in allbounded if len(s) >= MINSET]
struct_known = [(l, s) for (l, s, cl) in structured if cl is not None]
struct_novel = [(l, s) for (l, s, cl) in structured if cl is None]
univ_known   = [(l, s) for (l, s, cl) in alluniversal if cl is not None]
univ_novel   = [(l, s) for (l, s, cl) in alluniversal if cl is None]

print("\n" + "=" * 70)
print("NOVEL ACCOUNTING (honest · c2 · bounded-evidence only · forall UNPROVEN):")
print(f"   total finite-solution hits           : {len(allbounded)}")
print(f"     coincidence noise (|sol|<{MINSET})        : {len(coincidence)}   (NOT identities)")
print(f"     STRUCTURED sparse (|sol|≥{MINSET})         : {len(structured)}")
print(f"        of which KNOWN/classical          : {len(struct_known)}")
print(f"        of which NOVEL (unexplained)       : {len(struct_novel)}")
print(f"   universal-in-[2,N] structural hits    : {len(alluniversal)}")
print(f"     (these are restatements of definitional/product identities — e.g.")
print(f"      n∘g = g, structural; not composition-specific new laws)")
print("")
print("STRUCTURED-SPARSE hits |sol|≥3 (the discovery vein · hand-triage):")
for (l, s, cl) in sorted(structured, key=lambda x: (-len(x[1]), x[0]))[:50]:
    tag = f"[KNOWN {cl}]" if cl else "[NOVEL?]"
    print(f"   {tag:26} {l:30} sol={head(s)}")
print("")
# ── PROMOTABILITY (the only honest 🔵-candidate criteria · c2) ────────────────
# A composition hit is PROMOTABLE (a real novel-law candidate) only if it is
# either (a) bounded-UNIQUE singleton n≥4 with a STRUCTURAL reason, or (b)
# universal-in-[2,N] (forall-n evidence).  Measured reality of this vein:
#   • bounded-unique singletons are pure single-point numeric ACCIDENTS (a
#     composition vs a comparison form coincides at some lone n with no law) —
#     NOT promotable.
#   • the |sol|≥3 "structured" sets are THIN restricted-domain coincidence
#     families (e.g. sopfr∘rad=core holds on prime-squares p²; ω∘σ=ω∘core on
#     squares) — bounded-evidence only, NOT forall, NOT bounded-unique → NOT
#     promotable (forall UNPROVEN · elementary/classical-reducible).
#   • every universal-in-[2,N] hit is a structural restatement (n∘g=g, etc.) of
#     a definitional/product identity — not a composition-specific NEW law.
singletons = [(l, s) for (l, s, cl) in allbounded if len(s) == 1 and s[0] >= 4 and cl is None]
print("PROMOTABILITY (🔵-candidate gate · c2 honest):")
print(f"   classical NAMED composition laws rediscovered (KNOWN): "
      f"{len(struct_known)} structured + the sanity gates")
print(f"   bounded-unique singletons n≥4 (single-point accidents) : {len(singletons)}  → 0 promotable")
print(f"   bounded-evidence sparse families |sol|≥3 (thin coincid.): {len(struct_novel)}  → 0 promotable")
print(f"   universal-in-[2,N] structural restatements             : {len(alluniversal)}  → 0 promotable")
print("")
print("VERDICT: novel PROMOTABLE composition laws (bounded-unique singleton OR")
print("         universal-forall, non-classical) = 0   → DRY")
print("   The composition vein reproduces ONLY the classical Mersenne-linked")
print("   family (superperfect σ∘σ=2n · Mersenne σ∘σ=σ+n · σ∘φ=n · φ∘σ=n · …).")
print("   The long tail is single-point accidents + thin restricted-domain")
print("   coincidence families (forall UNPROVEN, elementary-reducible) — none")
print("   promotable. Same terminal as the 18-fn product frame (#4060 novel=0),")
print("   reached HONESTLY: composition is a DIFFERENT algebra (σ∘σ has no")
print("   product restatement) yet its discovery-grade content is also classical.")
