#!/usr/bin/env python3
"""PCF-CONSTANT DISCOVERY PROBE — Ramanujan-Machine-style genuine-novel frontier.

break-walls research-gate (arxiv 2012.12692 Lynch · 2602.03027 Wang): the Ramanujan Machine
(Automated Conjecture Generator) finds polynomial-continued-fraction (PCF) representations of
transcendental constants (e, π, ζ(3), Catalan, 8/π²) — some PROVEN, some still UNPROVEN = genuine
novel conjectures. This is the frontier where machine-math-discovery REALLY produces novel results,
ORTHOGONAL to the arithmetic-function-congruence space (measured classically-closed across ~7 families).

This probe implements the canonical PCF mechanism (Raayoni et al., Nature 2021):
  PCF value = b0 + a1/(b1 + a2/(b2 + a3/(b3 + ...)))  with a(n),b(n) integer polynomials.
  Convergent recurrence: p_n = b_n·p_{n-1} + a_n·p_{n-2};  q_n = b_n·q_{n-1} + a_n·q_{n-2}.
  Search small integer poly coeffs → exact-rational convergent (fractions.Fraction) → high-precision
  Decimal compare against target constants → reference-match (known PCF vs candidate).

c2 honesty: a HIT = a PCF numerically converging to a constant to ~40 digits = a CONJECTURE (∀-term
UNPROVEN, like the Ramanujan Machine's). Rediscovered known PCFs = sanity. The discriminator =
known-catalog reference-match + the same closure philosophy (don't fabricate; report tier).
Deterministic, exact-int convergents, stdlib only (Fraction + Decimal). LOCAL.
"""
import sys, itertools
from fractions import Fraction
from decimal import Decimal, getcontext

getcontext().prec = 55
DIG = 42  # match digits required for a "hit"

# ---- target transcendental constants (50-digit hardcoded) ----
TARGETS = {
    "e":        Decimal("2.7182818284590452353602874713526624977572470937000"),
    "pi":       Decimal("3.1415926535897932384626433832795028841971693993751"),
    "4/pi":     Decimal("1.2732395447351626861510701069801148962756160017800"),
    "pi^2/6":   Decimal("1.6449340668482264364724151666460251892189499012068"),  # zeta(2)
    "zeta(3)":  Decimal("1.2020569031595942853997381615114499907649862923405"),  # Apery
    "Catalan":  Decimal("0.9159655941772190150546035149323841107741493742817"),
    "ln2":      Decimal("0.6931471805599453094172321214581765680755001343602"),
    "e-1":      Decimal("1.7182818284590452353602874713526624977572470937000"),
}

# ---- PCF convergent: a(n)=poly, b(n)=poly (degree<=2), to K terms ----
def pcf_value(acoef, bcoef, K=140):
    """acoef/bcoef = (c0,c1,c2) for c0+c1*n+c2*n². Return Decimal of convergent p_K/q_K or None."""
    def poly(c, n): return c[0] + c[1]*n + c[2]*n*n
    b0 = poly(bcoef, 0)
    p_prev, p_cur = Fraction(1), Fraction(b0)   # p_{-1}=1, p_0=b0
    q_prev, q_cur = Fraction(0), Fraction(1)    # q_{-1}=0, q_0=1
    for n in range(1, K+1):
        an = poly(acoef, n); bn = poly(bcoef, n)
        p_prev, p_cur = p_cur, bn*p_cur + an*p_prev
        q_prev, q_cur = q_cur, bn*q_cur + an*q_prev
        if q_cur == 0: return None
    try:
        val = Decimal(p_cur.numerator)/Decimal(p_cur.denominator) / (Decimal(q_cur.numerator)/Decimal(q_cur.denominator))
        return val
    except Exception:
        return None

def matches(val, target):
    if val is None: return False
    return abs(val - target) < Decimal(10)**(-DIG)

# known-PCF catalog (for reference-match sanity / classical tag) — canonical forms
KNOWN = {
    # 4/pi = 1 + 1/(2 + 9/(2 + 25/(2+...)))  Brouncker: a(n)=(2n-1)², b0=1, b(n)=2
    ("4/pi","brouncker"): "(2n-1)²/2",
    # e: a(n)=n, b(n)=n with b0=2 variants (Euler)
}

def main():
    R = range(-3, 4)  # small integer coeffs
    print(f"=== PCF-CONSTANT DISCOVERY PROBE (coeffs∈[-3,3], deg≤2-sparse, {DIG}-digit match) ===\n")

    # SANITY: Brouncker 4/π = 1 + (2n-1)²/2  → acoef for (2n-1)²=4n²-4n+1 = (1,-4,4); bcoef=(2,0,0) but b0=1
    # b0 must be 1, b(n)=2 for n>=1. Our poly b has constant b0; emulate: bcoef=(2,0,0) gives b0=2 (wrong).
    # Use a dedicated b0 override for sanity:
    def pcf_b0(acoef, bcoef, b0, K=140):
        def poly(c,n): return c[0]+c[1]*n+c[2]*n*n
        p_prev,p_cur=Fraction(1),Fraction(b0); q_prev,q_cur=Fraction(0),Fraction(1)
        for n in range(1,K+1):
            an=poly(acoef,n); bn=poly(bcoef,n)
            p_prev,p_cur=p_cur,bn*p_cur+an*p_prev
            q_prev,q_cur=q_cur,bn*q_cur+an*q_prev
            if q_cur==0: return None
        return Decimal(p_cur.numerator*q_cur.denominator)/Decimal(p_cur.denominator*q_cur.numerator)
    bp = pcf_b0((1,-4,4),(2,0,0),1)   # Brouncker 4/pi
    sane = bp is not None and abs(bp-TARGETS["4/pi"])<Decimal(10)**(-DIG)
    print(f"SANITY Brouncker 4/π=1+(2n-1)²/2 : {'PASS ('+str(bp)[:20]+'…)' if sane else 'FAIL '+str(bp)[:25]}\n")

    # SEARCH — sparse degree≤2 a/b, match to targets
    hits=[]
    tried=0
    # b0 swept separately (constant term matters most for which constant)
    for a0,a1,a2 in itertools.product(R,R,[0,1]):
        if (a0,a1,a2)==(0,0,0): continue
        for b0_,b1,b2 in itertools.product(range(0,5),R,[0,1]):
            if (b0_,b1,b2)==(0,0,0): continue
            tried+=1
            val = pcf_b0((a0,a1,a2),(b0_,b1,b2),b0_)
            if val is None: continue
            for name,t in TARGETS.items():
                if abs(val-t)<Decimal(10)**(-DIG):
                    hits.append((name,(a0,a1,a2),(b0_,b1,b2),str(val)[:24]))
    print(f"--- search: {tried} PCFs tried, {len(hits)} target-matches ---")
    seen=set()
    for name,a,b,v in hits:
        key=(name,a,b)
        if key in seen: continue
        seen.add(key)
        print(f"  {name:9s} ← a(n)={a} b(n)={b}  conv={v}")

    print(f"\n=== VERDICT ===")
    print(f"PCF_TARGET_MATCHES = {len(seen)} (distinct)")
    print(f"각 hit = PCF가 상수로 {DIG}자리 수렴 = CONJECTURE(∀-term UNPROVEN·Ramanujan Machine류).")
    print(f"reference-match 필요: 알려진 PCF(Euler/Brouncker/Apéry CF)면 classical, 미카탈로그면 🟧 candidate.")
    print(f"이 frontier는 산술합동 공간(closed)과 직교 — genuine machine-discovery가 실재하는 곳(research 확인).")
    print(f"다음: hits를 OEIS/Ramanujan-Machine DB 대조 → 미카탈로그 PCF = 진짜 novel 추측 후보(고정밀 재검증·증명탐색).")

main()
