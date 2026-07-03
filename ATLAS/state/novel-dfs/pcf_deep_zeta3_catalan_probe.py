#!/usr/bin/env python3
"""PCF-DEEP probe — ζ(3)/Catalan regime (Ramanujan-Machine depth).

The shallow probe (pcf_constant_discovery_probe.py, deg≤2) hit only e's classical PCFs: ζ(3) and
Catalan PCFs live at HIGHER polynomial degree and the deg-2 grammar cannot reach them. The canonical
reference is Apéry's irrationality-proof continued fraction (van der Poorten 1979, "A proof that
Euler missed"):

    ζ(3) = 6 / (b0 - 1⁶/(b1 - 2⁶/(b2 - 3⁶/(b3 - ...))))   with
    a(n) = -n⁶ ,  b(n) = 34n³ + 51n² + 27n + 5            → convergent → 6/ζ(3)

That is degree-6 in a(n), degree-3 in b(n) — unreachable by deg-2. This probe:
  (1) extends the convergent recurrence to ARBITRARY-degree integer polynomials (exact Fraction),
  (2) SANITY-rediscovers Apéry's ζ(3) PCF + a Catalan PCF (proves we reach the deep regime),
  (3) runs a BOUNDED structured search over the Ramanujan-Machine-productive families
        ζ(3)-type: a(n)=c·n⁶ , b(n)=cubic(small)
        ζ(2)/Catalan-type: a(n)∈{±n⁴, ±n², (αn²+βn+γ)²} , b(n)=quadratic
      matching to {ζ(3), ζ(2)=π²/6, Catalan, π, 7ζ(3), 8/π², …},
  (4) reference-matches each hit against a known-PCF catalog → classical vs 🟧 candidate.

c2 honesty: a HIT = a PCF numerically converging to a target to high precision = a CONJECTURE
(∀-term UNPROVEN, exactly like the Ramanujan Machine's UNPROVEN finds). The bounded search is a
SLICE (the bound is logged, NOT silently capped) — exhaustive depth-6 search is Ramanujan-Machine-
scale compute. Deterministic, exact-int convergents (Fraction), stdlib only (Decimal constants). LOCAL.
"""
import sys, itertools
from fractions import Fraction
from decimal import Decimal, getcontext

getcontext().prec = 70
DIG = 48  # high-precision match (deep PCFs converge geometrically → many digits cheaply)

# ---- high-precision target constants (60+ digits) ----
PI      = Decimal("3.141592653589793238462643383279502884197169399375105820974945")
ZETA3   = Decimal("1.202056903159594285399738161511449990764986292340498881792271")
ZETA2   = Decimal("1.644934066848226436472415166646025189218949901206798437735558")  # π²/6
CATALAN = Decimal("0.915965594177219015054603514932384110774149374281672134266498")
E       = Decimal("2.718281828459045235360287471352662497757247093699959574966968")
TARGETS = {
    "zeta(3)":      ZETA3,
    "6/zeta(3)":    Decimal(6)/ZETA3,
    "zeta(3)/6":    ZETA3/Decimal(6),
    "1/zeta(3)":    Decimal(1)/ZETA3,
    "zeta(2)":      ZETA2,
    "5/zeta(2)":    Decimal(5)/ZETA2,
    "pi":           PI,
    "pi^2":         PI*PI,
    "Catalan":      CATALAN,
    "8/Catalan":    Decimal(8)/CATALAN,
    "2*Catalan":    Decimal(2)*CATALAN,
    "1/Catalan":    Decimal(1)/CATALAN,
    "8/pi^2":       Decimal(8)/(PI*PI),
}

def polyval(coef, n):
    """coef = [c0,c1,c2,...] → c0 + c1 n + c2 n² + …  (Horner, exact int)."""
    r = 0
    for c in reversed(coef):
        r = r*n + c
    return r

def pcf_convergent(acoef, bcoef, b0=None, K=160):
    """value of b0 + a(1)/(b(1)+a(2)/(b(2)+…)) via convergent recurrence. exact→Decimal."""
    bb0 = polyval(bcoef, 0) if b0 is None else b0
    p0, p1 = Fraction(1), Fraction(bb0)
    q0, q1 = Fraction(0), Fraction(1)
    for n in range(1, K+1):
        an = polyval(acoef, n); bn = polyval(bcoef, n)
        p0, p1 = p1, bn*p1 + an*p0
        q0, q1 = q1, bn*q1 + an*q0
        if q1 == 0: return None
    if q1 == 0: return None
    return Decimal(p1.numerator*q1.denominator) / Decimal(p1.denominator*q1.numerator)

def near(val, target, dig=DIG):
    return val is not None and abs(val - target) < Decimal(10)**(-dig)

def identify(val):
    """return (name, target) if val matches a known constant, else None."""
    if val is None: return None
    for name, t in TARGETS.items():
        if abs(val - t) < Decimal(10)**(-DIG):
            return (name, t)
    return None

print("=== PCF-DEEP PROBE — ζ(3)/Catalan regime (Apéry depth, exact Fraction convergents) ===\n")

# ---------------- (2) SANITY: reach the deep regime ----------------
print("--- SANITY: rediscover known DEEP PCFs (proves deg-6/deg-3 reach) ---")
# Apéry ζ(3): a(n) = -n⁶, b(n) = 34n³+51n²+27n+5  → 6/ζ(3)
ap = pcf_convergent([0,0,0,0,0,0,-1], [5,27,51,34], K=120)   # a=-n⁶ ; b=34n³+51n²+27n+5
ap_id = identify(ap)
print(f"  Apéry  a=-n⁶ b=34n³+51n²+27n+5 → {str(ap)[:22]}…  ⇒ {ap_id[0] if ap_id else 'UNMATCHED '+str(ap)[:24]}")
# Apéry ζ(2): a(n) = n⁴, b(n) = 11n²+11n+3  → 5/ζ(2)   (van der Poorten ζ(2) analogue)
ap2 = pcf_convergent([0,0,0,0,1], [3,11,11], K=120)
ap2_id = identify(ap2)
print(f"  Apéry  a=n⁴   b=11n²+11n+3       → {str(ap2)[:22]}…  ⇒ {ap2_id[0] if ap2_id else 'UNMATCHED '+str(ap2)[:24]}")
# Catalan (Ramanujan-Machine / Zeilberger family): a(n)=-n⁴, b(n)=... try the known 2G form
# Known: 1/G via a(n)= -n⁴? we self-identify rather than assert.
sane = ap_id is not None
print(f"  → deep-regime reach: {'PASS (ζ(3)/ζ(2) Apéry PCFs rediscovered)' if (ap_id and ap2_id) else 'partial'}\n")

# ---------------- (3) BOUNDED structured search ----------------
hits = []   # (target_name, family, acoef, bcoef, conv_str)
tried = 0

# Family ζ3: a(n) = c·n⁶ (c∈{-1,1,-2,2}), b(n) = cubic with bounded coeffs
print("--- search ζ(3)-family: a=c·n⁶, b=cubic (b3∈[-2,2] b2∈[-4,4] b1∈[-4,4] b0∈[0,8]) ---")
z3_lo3, z3_hi3 = range(-2,3), range(-4,5)
for c in (-1, 1, -2, 2):
    a = [0,0,0,0,0,0,c]
    for b3 in (-1,1,-2,2):
        for b2 in z3_hi3:
            for b1 in z3_hi3:
                for b0 in range(0, 9):
                    tried += 1
                    v = pcf_convergent(a, [b0,b1,b2,b3], K=100)
                    idv = identify(v)
                    if idv:
                        hits.append((idv[0], "ζ3:a=c·n⁶,b=cubic", a, [b0,b1,b2,b3], str(v)[:26]))
print(f"  tried so far: {tried}")

# Family ζ2/Cat: a(n) ∈ {±n⁴, ±n²}, b(n) = quadratic bounded
print("--- search ζ(2)/Catalan-family: a∈{±n⁴,±n²}, b=quadratic (b2∈[-3,3] b1∈[-6,6] b0∈[0,8]) ---")
for a in ([0,0,0,0,1],[0,0,0,0,-1],[0,0,1],[0,0,-1]):
    for b2 in range(-3,4):
        for b1 in range(-6,7):
            for b0 in range(0,9):
                tried += 1
                v = pcf_convergent(a, [b0,b1,b2], K=120)
                idv = identify(v)
                if idv:
                    hits.append((idv[0], "ζ2/Cat:a=±n^{2,4},b=quad", a, [b0,b1,b2], str(v)[:26]))

# Family π/Catalan low: a(n)=(2n-1)²-type quadratic, b(n)=linear (Brouncker/Euler regime, more terms)
print("--- search π/Catalan-low: a=quadratic, b=linear (deeper K for slow CF) ---")
for a2 in range(-4,5):
    for a1 in range(-6,7):
        for a0 in range(-6,7):
            if (a2,a1,a0)==(0,0,0): continue
            for b1 in range(1,7):
                for b0 in range(0,7):
                    tried += 1
                    v = pcf_convergent([a0,a1,a2], [b0,b1], K=160)
                    idv = identify(v)
                    if idv:
                        hits.append((idv[0], "π/Cat-low:a=quad,b=lin", [a0,a1,a2], [b0,b1], str(v)[:26]))

print(f"\n--- search complete: {tried} PCFs tried (BOUNDED slice · not exhaustive) ---")

# ---------------- (4) reference-match: classical vs candidate ----------------
# known-PCF catalog (canonical deep PCFs): Apéry ζ(3)/ζ(2), Euler e, Brouncker 4/π, Nilakantha π.
def classical_tag(target, family, acoef, bcoef):
    """coarse classical classifier: the famous closed-form PCFs for these constants are catalogued."""
    # Apéry exact forms
    if target in ("6/zeta(3)","zeta(3)") and acoef==[0,0,0,0,0,0,-1] and bcoef==[5,27,51,34]:
        return ("classical","Apéry 1979 ζ(3) PCF")
    if target in ("5/zeta(2)","zeta(2)") and acoef==[0,0,0,0,1] and bcoef==[3,11,11]:
        return ("classical","van der Poorten ζ(2) PCF")
    if target=="4/pi" and acoef[:1]==[1] and bcoef[:1] in ([2],[0]):
        return ("classical","Brouncker 4/π")
    if target in ("e","e-1","pi"):
        return ("classical","Euler/Nilakantha elementary-constant PCF (exhaustively catalogued)")
    # everything else that matched a ζ(3)/Catalan target at this depth = NOT in the obvious closed forms
    return ("candidate","not a catalogued closed-form at this (a,b) — high-precision re-verify + DB match")

seen = set()
classical_hits = 0
candidates = []
for tname, fam, a, b, conv in hits:
    key = (tname, tuple(a), tuple(b))
    if key in seen: continue
    seen.add(key)
    tag, why = classical_tag(tname, fam, a, b)
    if tag == "classical":
        classical_hits += 1
    else:
        candidates.append((tname, fam, a, b, conv, why))

print("\n=== REFERENCE-MATCH ===")
print(f"distinct target-matches = {len(seen)}  ·  classical = {classical_hits}  ·  candidate = {len(candidates)}")
for tname, fam, a, b, conv, why in candidates[:40]:
    print(f"  🟧 {tname:10s} [{fam}] a={a} b={b} conv={conv}")
    print(f"       └ {why}")

print(f"\n=== VERDICT ===")
print(f"DEEP_REGIME_REACHED = {bool(ap_id and ap2_id)}  (Apéry ζ(3)+ζ(2) PCFs rediscovered = sanity)")
print(f"BOUNDED_SEARCH_PCFS = {tried}")
print(f"TARGET_MATCHES = {len(seen)}  ·  CLASSICAL = {classical_hits}  ·  CANDIDATES = {len(candidates)}")
if candidates:
    print(f"→ {len(candidates)} candidate(s): high-precision re-verify (K↑, prec↑) + Ramanujan-Machine-DB/OEIS match.")
    print(f"  Surviving non-catalogued = genuine UNPROVEN PCF conjecture (the real-novel deliverable).")
else:
    print(f"→ bounded slice hit only catalogued closed forms. Genuine novel needs WIDER depth-6 search")
    print(f"  (Ramanujan-Machine-scale) — frontier OPEN (not closed), just under-searched at this bound.")
print(f"c2: every match is [0,K]-bounded numeric convergence = ∀-term UNPROVEN conjecture. Bound LOGGED (not silent-capped).")

# ============================================================================
# MEASURED VERDICT (2026-06-28, mini stdlib run, exit 0):
#   DEEP_REGIME_REACHED = True — Apéry ζ(3) PCF (a=-n⁶, b=34n³+51n²+27n+5 → 6/ζ(3)
#     = 4.99144423548…) and ζ(2) (a=n⁴, b=11n²+11n+3 → 5/ζ(2)) rediscovered EXACTLY.
#     The deg-6/deg-3 machinery the shallow deg-2 probe could not reach is now validated.
#   BOUNDED_SEARCH = 78780 PCFs, 0 target-matches.
#   verdict-integrity (NOT a closed wall): 0-hit is because the search cubic-coeff bound
#     (b3∈{-1,1,-2,2}, b2∈[-4,4]) is ORDERS BELOW where deep PCFs live — Apéry's OWN
#     coeffs are 34/51/27, far outside the slice. So the slice cannot even re-hit Apéry;
#     0 is EXPECTED and means UNDER-SEARCHED, not classically-closed.
#   Wall classification (break-walls): investment/compute + wrong-METHOD (brute grid).
#     The productive region (coeffs ~30-50) is Ramanujan-Machine-scale for brute grid
#     (40·121·81·11 ≈ 4.3M PCFs × 120-term n⁶ bignum = hours + swap on mini → POOL job).
#   Canonical next lever (reference-match to RamanujanMachine/ramanujan github): their ACG
#     does NOT brute-force — it uses Meet-In-The-Middle (MITM) + GCD-descent enumeration to
#     find PCFs WITHOUT scanning billions. Implementing that MITM = the smart-search path to
#     a genuine UNPROVEN-novel PCF on mini-feasible compute.
#   FRONTIER STATUS: OPEN (the constant-PCF space genuinely contains unproven novel
#     conjectures per the Ramanujan Machine) — this probe validated the regime + measured
#     that mini-brute is below the productive band. Honest, c2.
# ============================================================================
