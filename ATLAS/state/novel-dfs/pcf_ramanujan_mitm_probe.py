#!/usr/bin/env python3
"""PCF-MITM probe — canonical Ramanujan-Machine smart-search (Möbius integer-relation + pruning).

The brute deep probe (pcf_deep_zeta3_catalan_probe.py) measured that exact-target-match over a small
coefficient grid is UNDER-SEARCHED: it cannot even re-hit Apéry (coeffs 34/51/27 lie outside a ≤8
slice) and exhaustive depth-6 brute is Ramanujan-Machine-scale. The canonical RM mechanism (Raayoni
et al., "Generating conjectures on fundamental constants with the Ramanujan Machine", Nature 590
(2021) 67-73) does NOT brute-match a hardcoded target list. It uses TWO levers this probe implements:

  (1) MÖBIUS INTEGER-RELATION DETECTION (the "meet-in-the-middle" essence).
      A PCF rarely equals a constant c on the nose — it equals a RATIONAL FUNCTION of c. So instead
      of testing `limit == c`, detect small integers (A,B,C,D) with
            A·1 + B·c + C·L + D·(c·L) ≈ 0      ⟺   L = (A + B·c) / (-C - D·c)
      i.e. L is a Möbius transform of c. This catches 6/ζ(3), 5/ζ(2), AND novel transforms in ONE
      pass — the search no longer needs to pre-enumerate every rational multiple of every target.
  (2) EARLY-CONVERGENCE PRUNING. Most PCFs in a grid diverge or crawl. Compute convergents
      incrementally; bail the moment the value stops sharpening (or never does) — so a WIDER
      coefficient band becomes mini-feasible (you only pay full cost on the PCFs that actually
      converge geometrically, i.e. the interesting ones).

Pipeline validation: SEARCH mode A is a tight 3⁴ window straddling Apéry's exact (34,51,27,5) — the
search loop + detector MUST re-find Apéry end-to-end (not just a hardcoded sanity line). Mode B is a
coarse wide stepped sweep for novel neighbours + Catalan/ζ(2) families.

c2 honesty: a detected Möbius relation = a CONJECTURE (∀-term UNPROVEN, like the RM's). Apéry / van
der Poorten relations = classical (reference-matched). A novel non-catalogued Möbius-PCF = the
genuine-novel deliverable, flagged 🟧 for high-precision re-verify + DB match. Deterministic, exact
Fraction convergents, stdlib only. LOCAL. Bounds LOGGED (not silent-capped).
"""
import sys, itertools
from fractions import Fraction
from decimal import Decimal, getcontext

getcontext().prec = 80
PREC_DIG = 46          # a relation must hold to this many digits to count
CONV_DIG = 46          # a PCF must converge to at least this to be testable
KMAX = 90              # hard term cap (deep PCFs converge geometrically → ~20-40 terms suffice;
                       # mini-bounded so the n⁶ bignum sweep COMPLETES, not SIGTERM-killed.
                       # A wide exhaustive sweep is pool-scale — see verdict.)

# ---- high-precision constants (70+ digits) ----
PI      = Decimal("3.1415926535897932384626433832795028841971693993751058209749445923078164")
ZETA3   = Decimal("1.2020569031595942853997381615114499907649862923404988817922715553418382")
ZETA2   = Decimal("1.6449340668482264364724151666460251892189499012067984377355582293700074")
CATALAN = Decimal("0.9159655941772190150546035149323841107741493742816721342664981196217630")
LN2     = Decimal("0.6931471805599453094172321214581765680755001343602552541206800094933936")
CONSTS = {"zeta(3)": ZETA3, "zeta(2)": ZETA2, "Catalan": CATALAN, "pi": PI, "ln2": LN2}

def polyval(coef, n):
    r = 0
    for c in reversed(coef):
        r = r*n + c
    return r

def pcf_limit(acoef, bcoef, conv_dig=CONV_DIG, kmax=KMAX):
    """incremental convergent with early pruning. returns (Decimal limit, terms) or (None, reason)."""
    b0 = polyval(bcoef, 0)
    p0, p1 = Fraction(1), Fraction(b0)
    q0, q1 = Fraction(0), Fraction(1)
    prev = None
    eps = Decimal(10)**(-conv_dig)
    stable = 0
    for n in range(1, kmax+1):
        an = polyval(acoef, n); bn = polyval(bcoef, n)
        p0, p1 = p1, bn*p1 + an*p0
        q0, q1 = q1, bn*q1 + an*q0
        if q1 == 0:
            return (None, "zero-denom")
        # evaluate convergent only every few terms (cheaper) once denom is large
        if n >= 4 and (n % 2 == 0 or n > 30):
            cur = Decimal(p1.numerator*q1.denominator) / Decimal(p1.denominator*q1.numerator)
            if prev is not None:
                d = abs(cur - prev)
                if d < eps:
                    stable += 1
                    if stable >= 2:
                        return (cur, n)            # converged
                else:
                    stable = 0
                # aggressive divergence/slow guard: bail early so non-converging grid PCFs are cheap
                if n > 35 and d > Decimal(10)**(-6):
                    return (None, "slow/divergent")
            prev = cur
    return (None, "no-converge")

def mobius_relation(L, c, M=10):
    """find small ints (A,B,C,D) with A + B·c + C·L + D·c·L ≈ 0, normalized. canonical RM detector.
       returns (A,B,C,D) of the tightest relation (smallest |coef| sum) or None."""
    if L is None: return None
    cL = c*L
    eps = Decimal(10)**(-PREC_DIG)
    best = None
    # require the relation to actually involve L (C or D nonzero) and be non-degenerate
    for D in range(-M, M+1):
        for C in range(-M, M+1):
            if C == 0 and D == 0: continue
            base = C*L + D*cL
            # solve A + B·c ≈ -base for small ints A,B
            for B in range(-M, M+1):
                target = -base - B*c
                # A must be near an integer
                A = target.to_integral_value(rounding="ROUND_HALF_EVEN")
                if abs(target - A) < eps and abs(int(A)) <= M:
                    Ai = int(A)
                    if (Ai, B, C, D) == (0,0,0,0): continue
                    s = abs(Ai)+abs(B)+abs(C)+abs(D)
                    if best is None or s < best[0]:
                        best = (s, (Ai, B, C, D))
    return best[1] if best else None

def relation_str(rel, cname):
    A,B,C,D = rel
    # L = (A + B·c)/(-C - D·c)
    num = []
    if A: num.append(f"{A}")
    if B: num.append(f"{B}·{cname}")
    den = []
    if -C: den.append(f"{-C}")
    if -D: den.append(f"{-D}·{cname}")
    return f"L = ({'+'.join(num) or '0'}) / ({'+'.join(den) or '0'})"

print("=== PCF-MITM PROBE — Ramanujan-Machine Möbius-relation smart-search ===\n")

# ---------------- SANITY: detector recognizes Apéry via Möbius route ----------------
print("--- SANITY: Möbius detector on known PCFs ---")
apL, apk = pcf_limit([0,0,0,0,0,0,-1], [5,27,51,34])     # Apéry ζ(3) → 6/ζ(3)
rel = mobius_relation(apL, ZETA3) if apL else None
print(f"  Apéry ζ(3) limit={str(apL)[:20]}… (k={apk}) → rel vs ζ(3): {rel} {relation_str(rel,'ζ3') if rel else ''}")
ap2L, ap2k = pcf_limit([0,0,0,0,1], [3,11,11])           # van der Poorten ζ(2) → 5/ζ(2)
rel2 = mobius_relation(ap2L, ZETA2) if ap2L else None
print(f"  vdP ζ(2)  limit={str(ap2L)[:20]}… (k={ap2k}) → rel vs ζ(2): {rel2} {relation_str(rel2,'ζ2') if rel2 else ''}")
sane = rel is not None and rel2 is not None
print(f"  → detector reach: {'PASS (both Möbius relations detected end-to-end)' if sane else 'FAIL'}\n")

# ---------------- SEARCH ----------------
# a-families (reference-matched to RM-productive deep forms)
AFAMS = {
    "a=-n^6 (ζ3)":  [0,0,0,0,0,0,-1],
    "a=n^6 (ζ3)":   [0,0,0,0,0,0,1],
    "a=n^4 (ζ2)":   [0,0,0,0,1],
    "a=-n^4":       [0,0,0,0,-1],
    "a=n^2":        [0,0,1],
    "a=-n^2":       [0,0,-1],
}
hits = []   # (afam, acoef, bcoef, cname, rel, Lstr, terms)
tried = 0
pruned = 0

def run_search(label, acoef, b3rng, b2rng, b1rng, b0rng):
    global tried, pruned
    for b3 in b3rng:
        for b2 in b2rng:
            for b1 in b1rng:
                for b0 in b0rng:
                    bcoef = [b0,b1,b2] + ([b3] if b3rng != [None] else [])
                    if all(x==0 for x in bcoef): continue
                    tried += 1
                    L, info = pcf_limit(acoef, bcoef)
                    if L is None:
                        pruned += 1; continue
                    for cname, c in CONSTS.items():
                        rel = mobius_relation(L, c)
                        if rel is not None:
                            hits.append((label, acoef, bcoef, cname, rel, str(L)[:24], info))

# MODE A — tight 3-wide window straddling Apéry's EXACT (34,51,27,5): end-to-end pipeline validation
print("--- SEARCH mode A: tight window around Apéry (a=-n⁶, b3∈33-35 b2∈50-52 b1∈26-28 b0∈4-6) ---")
run_search("A:apery-window", AFAMS["a=-n^6 (ζ3)"], range(33,36), range(50,53), range(26,29), range(4,7))
foundA = sum(1 for h in hits if h[0]=="A:apery-window")
print(f"  mode A: {foundA} Möbius hits in window (Apéry must be among them)")

# MODE B — coarse wide STEPPED sweep for novel neighbours (cubic b, pruned). Grid stepped + bounded
# so the n⁶ bignum sweep completes on mini (bounds LOGGED, not silent-capped).
print("--- SEARCH mode B: wide stepped cubic-b sweep, a∈ζ3-families (pruned) ---")
for label, a in [("B:ζ3 a=-n^6", AFAMS["a=-n^6 (ζ3)"]), ("B:ζ3 a=n^6", AFAMS["a=n^6 (ζ3)"])]:
    run_search(label, a, range(0,42,6), range(0,60,10), range(0,40,8), range(1,7))
    print(f"  [{label}] cumulative tried={tried} pruned={pruned} hits={len(hits)}", flush=True)

# MODE C — ζ(2)/Catalan families (quartic/quadratic a, quadratic b)
print("--- SEARCH mode C: ζ(2)/Catalan families (a=±n⁴/±n², b=quadratic stepped) ---")
for label, a in [("C:ζ2 a=n^4", AFAMS["a=n^4 (ζ2)"]), ("C: a=-n^4", AFAMS["a=-n^4"]),
                 ("C: a=n^2", AFAMS["a=n^2"]), ("C: a=-n^2", AFAMS["a=-n^2"])]:
    run_search(label, a, [None], range(0,30,3), range(-12,13,3), range(1,7))   # b quadratic (no b3)
    print(f"  [{label}] cumulative tried={tried} pruned={pruned} hits={len(hits)}", flush=True)

print(f"\n--- search complete: {tried} PCFs tried, {pruned} pruned (diverge/slow), {tried-pruned} converged ---")

# ---------------- reference-match: classical vs novel ----------------
def _strip(c):
    """drop trailing-zero high-degree coeffs so [3,6,0] (=6n+3, linear) reads as degree 1."""
    c = list(c)
    while len(c) > 1 and c[-1] == 0:
        c.pop()
    return c

def is_classical(acoef, bcoef, cname, rel):
    a = _strip(acoef); b = _strip(bcoef)
    adeg = len(a)-1; bdeg = len(b)-1
    if acoef==[0,0,0,0,0,0,-1] and bcoef==[5,27,51,34] and cname=="zeta(3)":
        return ("classical","Apéry 1979 ζ(3)")
    if acoef==[0,0,0,0,1] and bcoef==[3,11,11] and cname=="zeta(2)":
        return ("classical","van der Poorten ζ(2)")
    # ln/π via a=±n² (or lower), b LINEAR = Gauss/Euler continued fraction for the logarithm /
    # arctangent (classical hypergeometric ₂F₁ CF). adeg≤2 + bdeg≤1 = elementary-class.
    if cname in ("pi","ln2") and adeg <= 2 and bdeg <= 1:
        return ("classical","elementary π/ln2 Gauss-Euler CF (₂F₁ hypergeometric, classical)")
    # any constant reached by a LINEAR a + LINEAR b (Euler/Brouncker regime) = elementary
    if adeg <= 1 and bdeg <= 1:
        return ("classical","elementary linear-a linear-b PCF (Euler/Brouncker-class)")
    return ("candidate","non-catalogued Möbius-PCF — high-precision re-verify + RM-DB/OEIS match")

seen = set()
classical = []
candidates = []
for label, a, b, cname, rel, Lstr, terms in hits:
    key = (tuple(a), tuple(b), cname, rel)
    if key in seen: continue
    seen.add(key)
    tag, why = is_classical(a, b, cname, rel)
    rec = (label, a, b, cname, rel, Lstr, terms, why)
    (classical if tag=="classical" else candidates).append(rec)

print("\n=== REFERENCE-MATCH ===")
print(f"distinct Möbius hits = {len(seen)}  ·  classical = {len(classical)}  ·  candidate = {len(candidates)}")
print("classical (reference-matched):")
for label,a,b,cname,rel,Lstr,terms,why in classical[:12]:
    print(f"  ✓ {cname:8s} a={a} b={b}  {relation_str(rel,cname[:3])}  [{why}]")
print("candidates (🟧 non-catalogued — potential novel):")
for label,a,b,cname,rel,Lstr,terms,why in candidates[:40]:
    print(f"  🟧 {cname:8s} a={a} b={b}  {relation_str(rel,cname[:3])}  L={Lstr} (k={terms})")

print(f"\n=== VERDICT ===")
print(f"DETECTOR_VALIDATED = {sane}  ·  APERY_REFOUND_IN_SEARCH = {any(h[2]==[5,27,51,34] and h[3]=='zeta(3)' for h in hits)}")
print(f"PCFS_TRIED = {tried}  ·  PRUNED = {pruned}  ·  MÖBIUS_HITS = {len(seen)}")
print(f"CLASSICAL = {len(classical)}  ·  CANDIDATES = {len(candidates)}")
if candidates:
    print(f"→ {len(candidates)} 🟧 candidate Möbius-PCF(s): re-verify at higher prec/K + match against")
    print(f"  RamanujanMachine DB / OEIS. Surviving non-catalogued = genuine UNPROVEN PCF conjecture.")
else:
    print(f"→ 0 novel in this band: the canonical RM detector + pruning re-found only catalogued forms")
    print(f"  at this (logged) bound. Frontier OPEN — wider a-form variety or PSLQ-3 (c² relations) next.")
print(f"c2: every Möbius relation is [0,K]-bounded numeric = ∀-term UNPROVEN conjecture. Bounds LOGGED.")

# ============================================================================
# MEASURED VERDICT (2026-06-28, mini stdlib, exit 0, COMPLETED):
#   DETECTOR_VALIDATED = True — the canonical RM Möbius integer-relation detector recognizes
#     Apéry ζ(3) limit 4.99144… as (6,0,0,-1) ⟺ L=6/ζ(3), and vdP ζ(2) as L=5/ζ(2),
#     end-to-end (sanity) AND through the SEARCH loop (mode A re-found Apéry: 1 hit in the
#     3⁴ window straddling b=(34,51,27,5) — pipeline validated, no spurious over-fire).
#   SEARCH: 4761 PCFs tried, 450 pruned (early divergence guard), 4311 converged.
#     2 distinct Möbius hits, BOTH classical: Apéry ζ(3) + an ln2 Gauss-Euler ₂F₁ CF
#     (a=-n², b=6n+3 → 2/ln2). CANDIDATES = 0.
#   verdict-integrity self-correction: the first run flagged the ln2 hit as a 🟧 candidate;
#     suspected the TOOL first (governance verdict-integrity) → found a classifier bug
#     (b=[3,6,0] read as degree-3 instead of linear 6n+3 because trailing-zero coeff not
#     stripped). Fixed _strip() normalization + Gauss-Euler recognition → it is correctly
#     classical. NO genuine novel survived. (Don't declare novel before ruling out artifact.)
#   FRONTIER STATUS: OPEN, mini-band UNDER-SEARCHED (same class as the brute deep probe).
#     This is the canonical RM SMART-search (Möbius detector + pruning, NOT brute target-match)
#     and it correctly re-finds catalogued deep PCFs — but a genuinely-novel survivor needs
#     either (a) a WIDER a-form variety / coefficient band (Ramanujan-Machine-scale deg-6
#     bignum sweep = POOL job, not mini — SIGTERM-killed twice at timeout here), or (b) PSLQ-3
#     (detect c² relations, not just Möbius/c¹). Honest, c2. Bounds LOGGED, not silent-capped.
# ============================================================================
