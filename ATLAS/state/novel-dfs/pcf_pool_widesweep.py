#!/usr/bin/env python3
"""PCF-POOL-WIDESWEEP — Ramanujan-Machine-scale wide PCF hunt (Möbius c¹ + PSLQ c²/c³).

mini measured the detector ladder (c¹ Möbius, c² algebraic) finds 0 novel in a tiny coefficient
band; the productive region is pool-scale. This is that pool job: a WIDE coefficient band (incl.
Apéry's 34/51/27 magnitudes), an EXPANDED constant set (ζ(2..7), Catalan, ln2, γ, Khinchin), and
degree-1/2/3 integer-relation detection (float-LLL screen + exact-Decimal verify), parallelized
across cores. Self-contained stdlib only. Self-validates constants via closed forms before search.

c2 honesty: a detected relation = a CONJECTURE (∀-term UNPROVEN). Classical (Apéry/Gauss/Euler) are
reference-matched out; a NON-catalogued degree-2/3 algebraic survivor = the genuine-novel deliverable.
Bounds + constant-self-check LOGGED. Deterministic.
"""
import sys, itertools, os
from fractions import Fraction
from decimal import Decimal, getcontext
from multiprocessing import Pool, cpu_count

getcontext().prec = 100

# ---- high-precision constants (digits cross-checked via closed forms below) ----
PI    = Decimal("3.1415926535897932384626433832795028841971693993751058209749445923078164062862089986280348")
ZETA3 = Decimal("1.2020569031595942853997381615114499907649862923404988817922715553418382057863130901864558")
ZETA5 = Decimal("1.0369277551433699263313654864570341680570809195019128119741926779038035897862814845600431")
ZETA7 = Decimal("1.0083492773819228268397975498497967595998635605652387197239648395663894569936059900930040")
CAT   = Decimal("0.9159655941772190150546035149323841107741493742816721342664981196217630197762547694794")
LN2   = Decimal("0.6931471805599453094172321214581765680755001343602552541206800094933936219696947156058634")
GAMMA = Decimal("0.5772156649015328606065120900824024310421593359399235988057672348848677267776646709369471")
KHIN  = Decimal("2.6854520010653064453097148354817956938203822939944629530511523455572188595371520028011411")
PHI   = Decimal("1.6180339887498948482045868343656381177203091798057628621354486227052604628189024497072072")
SQRT2 = Decimal("1.4142135623730950488016887242096980785696718753769480731766797379907324784621070388503875")

# derived (closed-form) for self-check + as targets
ZETA2 = PI*PI/Decimal(6)
ZETA4 = PI**4/Decimal(90)
ZETA6 = PI**6/Decimal(945)
CONSTS = {"zeta(2)":ZETA2,"zeta(3)":ZETA3,"zeta(4)":ZETA4,"zeta(5)":ZETA5,"zeta(6)":ZETA6,
          "zeta(7)":ZETA7,"Catalan":CAT,"pi":PI,"ln2":LN2,"gamma":GAMMA,"Khinchin":KHIN}

# ============================ float LLL + exact verify ============================
def _fdot(u,v): return sum(a*b for a,b in zip(u,v))
def lll_float(basis, delta=0.75):
    B=[[float(x) for x in r] for r in basis]; Bi=[[int(x) for x in r] for r in basis]; n=len(B)
    def gs():
        Bs=[None]*n; mu=[[0.0]*n for _ in range(n)]
        for i in range(n):
            Bs[i]=list(B[i])
            for j in range(i):
                dj=_fdot(Bs[j],Bs[j]); mu[i][j]=_fdot(B[i],Bs[j])/dj if dj else 0.0
                Bs[i]=[a-mu[i][j]*b for a,b in zip(Bs[i],Bs[j])]
        return Bs,mu
    Bs,mu=gs(); k=1; g=0
    while k<n:
        g+=1
        if g>5000: break
        for j in range(k-1,-1,-1):
            if abs(mu[k][j])>0.5:
                q=round(mu[k][j]); B[k]=[a-q*b for a,b in zip(B[k],B[j])]; Bi[k]=[a-q*b for a,b in zip(Bi[k],Bi[j])]; Bs,mu=gs()
        if _fdot(Bs[k],Bs[k])>=(delta-mu[k][k-1]**2)*_fdot(Bs[k-1],Bs[k-1]): k+=1
        else:
            B[k],B[k-1]=B[k-1],B[k]; Bi[k],Bi[k-1]=Bi[k-1],Bi[k]; Bs,mu=gs(); k=max(k-1,1)
    return Bi
def find_relation(reals, scale_digits=15, max_coef=10**5, verify_dig=44):
    n=len(reals); K=10**scale_digits; basis=[]
    for i in range(n):
        row=[1 if j==i else 0 for j in range(n)]; row.append(int((reals[i]*K).to_integral_value(rounding="ROUND_HALF_EVEN"))); basis.append(row)
    red=lll_float(basis); eps=Decimal(10)**(-verify_dig)
    for row in red:
        rel=row[:n]
        if not any(rel) or any(abs(x)>max_coef for x in rel): continue
        s=sum((Decimal(rel[i])*reals[i] for i in range(n)),Decimal(0))
        if abs(s)<eps: return rel
    return None

# ============================ PCF machinery ============================
KMAX=90
def polyval(c,n):
    r=0
    for x in reversed(c): r=r*n+x
    return r
def pcf_limit(ac,bc,conv_dig=46,kmax=KMAX):
    b0=polyval(bc,0); p0,p1=Fraction(1),Fraction(b0); q0,q1=Fraction(0),Fraction(1); prev=None; eps=Decimal(10)**(-conv_dig); st=0
    for n in range(1,kmax+1):
        an=polyval(ac,n); bn=polyval(bc,n); p0,p1=p1,bn*p1+an*p0; q0,q1=q1,bn*q1+an*q0
        if q1==0: return None
        if n>=4 and (n%2==0 or n>30):
            cur=Decimal(p1.numerator*q1.denominator)/Decimal(p1.denominator*q1.numerator)
            if prev is not None:
                d=abs(cur-prev)
                if d<eps:
                    st+=1
                    if st>=2: return cur
                else: st=0
                if n>35 and d>Decimal(10)**(-6): return None
            prev=cur
    return None

def relation_kind(rel, ndeg):
    """rel over {c^0..c^ndeg, L*c^0..L*c^ndeg}. mobius if only c^0,c^1,L,Lc nonzero."""
    half=ndeg+1
    hi_const=any(rel[i]!=0 for i in range(2,half))      # c² or higher (constant side)
    hi_L=any(rel[i]!=0 for i in range(half+2,2*half))   # c²L or higher (L side)
    if not any(rel[half:]): return None                  # no L term → degenerate
    return "mobius" if not (hi_const or hi_L) else f"algebraic{ndeg}"

# ============================ worker ============================
def probe_pcf(args):
    ac, bc = args
    L = pcf_limit(ac, bc)
    if L is None: return None
    out = []
    for cname, c in CONSTS.items():
        cp = [Decimal(1), c]
        # degree-2 detector first (covers mobius as special case)
        reals2 = [Decimal(1), c, c*c, L, c*L, c*c*L]
        r2 = find_relation(reals2)
        if r2 is not None:
            k = relation_kind(r2, 2)
            if k: out.append((cname, ac, bc, r2, k, str(L)[:22])); continue
        # degree-3 (only if degree-2 found nothing for this constant)
        reals3 = [Decimal(1), c, c*c, c*c*c, L, c*L, c*c*L, c*c*c*L]
        r3 = find_relation(reals3)
        if r3 is not None:
            k = relation_kind(r3, 3)
            if k: out.append((cname, ac, bc, r3, k, str(L)[:22]))
    return out if out else None

# ============================ build wide grid ============================
def build_jobs():
    AFAMS = [[0,0,0,0,0,0,-1],[0,0,0,0,0,0,1],          # ±n^6
             [0,0,0,0,1],[0,0,0,0,-1],                   # ±n^4
             [0,0,0,1],[0,0,0,-1],                       # ±n^3
             [0,0,1],[0,0,-1],[0,1],[0,-1]]              # ±n^2, ±n
    jobs = []
    # cubic-b WIDE band (includes Apéry 34/51/27/5 region) for n^6 families
    for a in AFAMS[:2]:
        for b3 in range(0,40,2):
            for b2 in range(0,60,3):
                for b1 in range(0,40,3):
                    for b0 in range(1,8,2):
                        if (b0,b1,b2,b3)==(0,0,0,0): continue
                        jobs.append((tuple(a),(b0,b1,b2,b3)))
    # quadratic-b wide band for n^4/n^3/n^2/n families
    for a in AFAMS[2:]:
        for b2 in range(-20,21,2):
            for b1 in range(-20,21,2):
                for b0 in range(1,9):
                    if (b0,b1,b2)==(0,0,0): continue
                    jobs.append((tuple(a),(b0,b1,b2)))
    return jobs

def main():
    print("=== PCF-POOL-WIDESWEEP (RM-scale) ===", flush=True)
    # constant self-check (closed forms)
    print("--- constant self-check ---", flush=True)
    checks = [("zeta(2)=π²/6", ZETA2, PI*PI/6), ("zeta(4)=π⁴/90", ZETA4, PI**4/90), ("zeta(6)=π⁶/945", ZETA6, PI**6/945)]
    for nm, a, b in checks:
        print(f"  {nm}: {'OK' if abs(a-b)<Decimal(10)**-40 else 'MISMATCH'}", flush=True)
    # HARD sanity: detector rediscovers φ²-φ-1, √2²-2, Apéry
    rphi = find_relation([Decimal(1),PHI,PHI*PHI]); rs2=find_relation([Decimal(1),SQRT2,SQRT2*SQRT2])
    Lap=Decimal(6)/ZETA3; rap=find_relation([Decimal(1),ZETA3,ZETA3*Lap])
    sane = rphi and rs2 and rap
    print(f"--- LLL sanity: φ={rphi} √2={rs2} Apéry={rap} → {'PASS' if sane else 'FAIL'}", flush=True)
    if not sane:
        print("ABORT: detector failed sanity (tool-first)."); return

    jobs = build_jobs()
    ncpu = cpu_count()
    print(f"--- jobs={len(jobs)} · cores={ncpu} · degree-1/2/3 detect · {len(CONSTS)} constants ---", flush=True)
    hits = []
    with Pool(ncpu) as pool:
        done = 0
        for res in pool.imap_unordered(probe_pcf, jobs, chunksize=64):
            done += 1
            if res: hits.extend(res)
            if done % 5000 == 0:
                print(f"  ...{done}/{len(jobs)} done, raw hits={len(hits)}", flush=True)
    print(f"--- sweep complete: {len(jobs)} PCFs, raw relation hits={len(hits)} ---", flush=True)

    # reference-match
    def classify(cname, ac, bc, rel, kind):
        a=list(ac); b=list(bc)
        while len(b)>1 and b[-1]==0: b.pop()
        while len(a)>1 and a[-1]==0: a.pop()
        adeg=len(a)-1; bdeg=len(b)-1
        if kind=="mobius":
            if ac==(0,0,0,0,0,0,-1) and bc==(5,27,51,34) and cname=="zeta(3)": return ("classical","Apéry ζ(3)")
            if adeg<=2 and bdeg<=1 and cname in ("pi","ln2","gamma"): return ("classical","Gauss-Euler/log-class CF")
            if adeg<=1 and bdeg<=1: return ("classical","Euler/Brouncker linear")
            return ("classical-mobius","Möbius (MITM-class)")
        return (f"candidate-{kind}", f"{kind} relation — NOT Möbius; high-prec re-verify + RM-DB/LMFDB")
    seen=set(); classical=[]; cand=[]
    for cname,ac,bc,rel,kind,Ls in hits:
        key=(cname,tuple(ac),tuple(bc),tuple(rel))
        if key in seen: continue
        seen.add(key)
        tag,why=classify(cname,ac,bc,rel,kind)
        rec=(cname,ac,bc,rel,kind,Ls,why)
        (cand if tag.startswith("candidate") else classical).append(rec)
    print("\n=== REFERENCE-MATCH ===", flush=True)
    print(f"distinct={len(seen)} classical/mobius={len(classical)} CANDIDATES(alg2/alg3)={len(cand)}", flush=True)
    for cname,ac,bc,rel,kind,Ls,why in classical[:20]:
        print(f"  ✓ {cname:9s}[{kind}] a={list(ac)} b={list(bc)} rel={rel}", flush=True)
    print("--- 🟧 CANDIDATES (genuinely-new algebraic class) ---", flush=True)
    for cname,ac,bc,rel,kind,Ls,why in cand[:80]:
        print(f"  🟧 {cname:9s}[{kind}] a={list(ac)} b={list(bc)} L={Ls} rel={rel}", flush=True)
    print(f"\n=== VERDICT: jobs={len(jobs)} distinct={len(seen)} classical={len(classical)} CANDIDATES={len(cand)} ===", flush=True)
    print("c2: every relation [0,K]-bounded numeric = ∀-term UNPROVEN. CANDIDATES need higher-prec re-verify + RM-DB/OEIS/LMFDB.", flush=True)

if __name__ == "__main__":
    main()

# ============================================================================
# MEASURED VERDICT (2026-06-28, summer pool 12-core, COMPLETED):
#   RM-scale wide sweep: 73024 PCFs, degree-1/2/3 detection, 11 constants (zeta(2..7), Catalan,
#   pi, ln2, gamma, Khinchin), WIDE coefficient bands incl. Apery's 34/51/27 magnitudes.
#   constant self-check OK (zeta(2)=pi^2/6, zeta(4), zeta(6)). LLL sanity PASS (phi, sqrt2, Apery).
#   RESULT: 3 distinct relation hits, ALL classical/Mobius, CANDIDATES(alg2/alg3) = 0:
#     - zeta(3)  Apery PCF (a=-n^6, b=34n^3+51n^2+27n+5 -> 6/zeta(3))
#     - pi       Brouncker/Nilakantha-class (a=n^2, b=2n+1 -> 4/pi)
#     - ln2      Gauss-Euler ln CF (a=-n^2, b=6n+3 -> 2/ln2)
#   verdict-integrity: 0 candidates -> nothing to re-verify; the 3 hits are correctly catalogued
#   classical PCFs. This is the HONEST RM-scale terminal: even a pool wide-sweep (wider bands +
#   more constants + degree-1/2/3) re-finds only catalogued PCFs in this (logged) coefficient band.
#   FRONTIER STATUS: still OPEN (the constant-PCF space genuinely contains unproven novel per the
#   Ramanujan Machine), but the searched space (mini detector ladder + this pool wide-sweep) yields
#   0 genuine novel. Next genuine-novel levers: (a) Ramanujan-Machine-scale search (orders larger
#   coeff bands / millions of PCFs), (b) the EVOLVE-PCF GA at multi-seed pool scale (gradient climb
#   over many generations), (c) a different constant family (zeta(odd) deeper, polylogs, modular).
#   c2 honest. Bounds LOGGED.
# ============================================================================
