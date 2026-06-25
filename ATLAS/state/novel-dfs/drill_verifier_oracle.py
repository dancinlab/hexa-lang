#!/usr/bin/env python3
"""drill --verifier oracle — REAL exact-integer screen for `hexa drill`/`kick` candidates.

WHY: drill/kick emits hundreds of ⚪ proposals per round but NEVER verifies them
(verifier_cmd defaults to "" → verdict "skip"; the surfaced rows are explicitly
"to-validate, NOT verified"). This oracle plugs into the existing drill `--verifier`
hook (compiler/drill/drill.hexa _verifier_run) so each round's discovery candidate
array is machine-screened with the SAME exact-integer methodology the ATLAS
`state/novel-dfs/*_hunt.py` engines use — NOT the seed-hash heuristic that drill (and,
as it turns out, the original NEXUS `ouroboros.hexa:509 verify_score`) relied on.

CONTRACT (compiler/drill/drill.hexa:56-67, :245-264):
  stdin  : one-line JSON {"round","total",...,"seed","candidates":[{id,conf,axiom,src,expr},...]}
  stdout : `verdict=pass|fail|continue [rationale=<inline>]`  (first line; other → error/skip)
    - pass     : at least one candidate is a NON-TRIVIAL, exact-int-verified identity
                 (would authoritatively halt under --verifier-strict = objective met)
    - continue : screened, nothing verifiable this round (advisory — loop proceeds)
  sidecar: appends a per-candidate screen log to $HX_DRILL_ORACLE_LOG (or
           state/novel-dfs/drill_oracle_screen.jsonl) — full audit trail, not the verdict line.

ARITHMETIC-FUNCTION BASIS — exact copy of blue_harvest_12fn.py:12-21 (reference-match,
cite file:line). 12-fn basis {sig,sig2,sig3,phi,tau,n,sopfr,rad,J2,psi,Om,om}, pure int.

Modes:
  --selftest [N]   prove the engine is a REAL verifier (sanity gates + negative controls,
                   mirrors r2-sum-two-squares_hunt.py G1..G4 / C1..C4). exit 0 iff all gates hold.
  (stdin JSON)     screen a drill round payload, emit the verdict line.
"""
import sys, json, os, re, itertools

# ── arithmetic-function table — reference-match blue_harvest_12fn.py:7-22 ──
def build_af(N):
    spf = list(range(N + 1))
    i = 2
    while i * i <= N:
        if spf[i] == i:
            for j in range(i * i, N + 1, i):
                if spf[j] == j:
                    spf[j] = i
        i += 1

    def af(n):
        if n == 1:
            return dict(sig=1, sig2=1, sig3=1, phi=1, tau=1, n=1, sopfr=0, rad=1, J2=1, psi=1, Om=0, om=0)
        m = n
        sig = sig2 = sig3 = tau = phi = psi = J2 = 1
        sopfr = 0; rad = 1; Om = 0; om = 0
        while m > 1:
            p = spf[m]; e = 0
            while m % p == 0:
                m //= p; e += 1
            sig *= (p**(e+1) - 1) // (p - 1)
            sig2 *= (p**(2*(e+1)) - 1) // (p**2 - 1)
            sig3 *= (p**(3*(e+1)) - 1) // (p**3 - 1)
            tau *= (e + 1)
            phi *= p**(e-1) * (p - 1)
            psi *= p**(e-1) * (p + 1)
            J2 *= p**(2*e) - p**(2*(e-1))
            sopfr += p * e; rad *= p; Om += e; om += 1
        return dict(sig=sig, sig2=sig2, sig3=sig3, phi=phi, tau=tau, n=n,
                    sopfr=sopfr, rad=rad, J2=J2, psi=psi, Om=Om, om=om)
    return [None] + [af(n) for n in range(1, N + 1)]

KEYS = ['sig', 'sig2', 'sig3', 'phi', 'tau', 'n', 'sopfr', 'rad', 'J2', 'psi', 'Om', 'om']
ALIASES = {'sigma': 'sig', 'σ': 'sig', 'φ': 'phi', 'τ': 'tau', 'ψ': 'psi',
           'Ω': 'Om', 'ω': 'om', 'omega': 'om', 'Omega': 'Om'}

# An identity claim is "A*B = C*D" (or longer products) where every factor is one of
# KEYS (a function of n). We verify by exact int over n in [2,N], collecting the
# solution set; bounded-unique (singleton, n>=4) is the ATLAS 🟩 fold criterion
# (excludes degenerate n=2,3 — blue_harvest_12fn.py:26).
FACTORS_RE = re.compile(r'^[A-Za-z0-9_σφτψΩωΣ.*· ]+$')

def normalize_factor(tok):
    tok = tok.strip()
    # strip CDESM-style group prefixes like "sigma.sigma_n6" → not a function-of-n → reject
    if tok in KEYS:
        return tok
    if tok in ALIASES:
        return ALIASES[tok]
    return None  # not a recognized arithmetic function of n

def parse_identity(expr):
    """Return (lhs_factors, rhs_factors) if expr is a product identity over KEYS, else None."""
    if '=' not in expr:
        return None
    # reject drill's op(a,b) ctype wrappers and constant-valued atoms outright
    if '(' in expr or any(c.isdigit() for c in expr.split('=')[0]) is None:
        pass
    parts = expr.split('=')
    if len(parts) != 2:
        return None
    def factors(side):
        side = side.replace('·', '*')
        toks = re.split(r'[*]', side)
        out = []
        for t in toks:
            f = normalize_factor(t)
            if f is None:
                return None
            out.append(f)
        return out
    lhs = factors(parts[0]); rhs = factors(parts[1])
    if lhs is None or rhs is None:
        return None
    return (lhs, rhs)

def verify_identity(F, N, lhs, rhs, min_n=4):
    """Exact-int: solution set of prod(lhs)==prod(rhs) over n in [2,N]. Returns dict."""
    sol = []
    for n in range(2, N + 1):
        l = 1
        for f in lhs:
            l *= F[n][f]
        r = 1
        for f in rhs:
            r *= F[n][f]
        if l == r:
            sol.append(n)
            if len(sol) > 4:
                break
    universal = len(sol) >= 5  # too many → likely a trivial/universal identity, not a discovery
    bounded_unique = (len(sol) == 1 and sol[0] >= min_n)
    return dict(solset=sol[:5], universal=universal, bounded_unique=bounded_unique)

# ─────────────────────────────────────────────────────────────────────────
def screen_payload(payload, N=20000):
    F = build_af(N)
    cands = payload.get('candidates', []) or []
    log = []
    n_total = len(cands)
    n_identity = 0       # parseable as arithmetic-function identity
    n_verified = 0       # bounded-unique exact-int discovery
    n_trivial = 0        # parseable but universal/degenerate
    n_nonident = 0       # not an identity at all (drill's float noise)
    for c in cands:
        expr = str(c.get('expr', ''))
        ident = parse_identity(expr)
        if ident is None:
            n_nonident += 1
            log.append({'id': c.get('id'), 'expr': expr, 'class': 'non-identity'})
            continue
        n_identity += 1
        v = verify_identity(F, N, ident[0], ident[1])
        if v['bounded_unique']:
            n_verified += 1
            log.append({'id': c.get('id'), 'expr': expr, 'class': 'VERIFIED',
                        'solset': v['solset']})
        else:
            n_trivial += 1
            log.append({'id': c.get('id'), 'expr': expr,
                        'class': 'universal' if v['universal'] else 'no-soln',
                        'solset': v['solset']})
    return dict(n_total=n_total, n_identity=n_identity, n_verified=n_verified,
                n_trivial=n_trivial, n_nonident=n_nonident, log=log,
                round=payload.get('round'), seed=payload.get('seed'))

def selftest(N=20000):
    """Prove the oracle is a REAL verifier, not a rubber stamp.
    Sanity gates (must PASS) + negative controls (must be rejected) — mirrors
    r2-sum-two-squares_hunt.py G1..G4 / C1..C4 methodology."""
    F = build_af(N)
    fails = []
    def gate(label, expr, want_unique, want_solset=None, want_parse=True):
        ident = parse_identity(expr)
        if ident is None:
            # parse-failure is the CORRECT outcome for a not-an-identity control
            tag = 'PASS' if not want_parse else 'FAIL'
            print(f"  [{tag}] {label}: '{expr}' rejected as non-identity (unparseable)")
            if want_parse:
                fails.append(label)
            return
        if not want_parse:
            print(f"  [FAIL] {label}: '{expr}' parsed but should have been rejected")
            fails.append(label); return
        v = verify_identity(F, N, ident[0], ident[1])
        ok = (v['bounded_unique'] == want_unique)
        if want_solset is not None:
            ok = ok and (v['solset'] == want_solset)
        tag = 'PASS' if ok else 'FAIL'
        print(f"  [{tag}] {label}: {expr}  → solset={v['solset']} unique={v['bounded_unique']}")
        if not ok:
            fails.append(label)
    print(f"=== drill_verifier_oracle SELFTEST (exact-int, N={N}) ===")
    print("SANITY GATES — rediscover known ATLAS @F identities (proof engine works):")
    # embedded.gen.hexa @F: phi*J2 = n*psi @ n=4 (bounded-unique)
    gate("G1 phi*J2 = n*psi  (ATLAS @F n=4)", "phi*J2 = n*psi", True, [4])
    gate("G2 phi*J2 = sopfr*psi (ATLAS @F n=4)", "phi*J2 = sopfr*psi", True, [4])
    gate("G3 phi*phi = rad*Om   (ATLAS @F n=4)", "phi*phi = rad*Om", True, [4])
    print("NEGATIVE CONTROLS — these MUST NOT be flagged as bounded-unique discoveries:")
    # a trivially-universal identity (holds for all n) must be rejected (universal, not unique)
    gate("C1 n*n = n*n  (universal → reject)", "n*n = n*n", False)
    gate("C2 sig = bogusfn  (unparseable → reject)", "sig = bogusfn", False, want_parse=False)
    gate("C3 phi*tau = sig*sig (likely no/!=1 soln)", "phi*tau = sig*sig", False)
    ok = len(fails) == 0
    print(f"\nRESULT: {'PASS — oracle is a real exact-int verifier' if ok else 'FAIL: ' + ','.join(fails)}")
    return 0 if ok else 1

def main():
    args = sys.argv[1:]
    if args and args[0] == '--selftest':
        N = int(args[1]) if len(args) > 1 else 20000
        sys.exit(selftest(N))
    # drill --verifier mode: read one-line JSON payload on stdin
    raw = sys.stdin.read().strip()
    if not raw:
        print("verdict=continue rationale=empty_payload")
        return
    try:
        payload = json.loads(raw)
    except Exception as e:
        print(f"verdict=continue rationale=unparseable_payload")
        return
    N = int(os.environ.get('HX_DRILL_ORACLE_N', '20000'))
    res = screen_payload(payload, N)
    # sidecar audit log
    logpath = os.environ.get('HX_DRILL_ORACLE_LOG',
                             os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                          'drill_oracle_screen.jsonl'))
    try:
        with open(logpath, 'a') as fh:
            fh.write(json.dumps({'round': res['round'], 'seed': res['seed'],
                                 'n_total': res['n_total'], 'n_identity': res['n_identity'],
                                 'n_verified': res['n_verified'], 'n_trivial': res['n_trivial'],
                                 'n_nonident': res['n_nonident'], 'detail': res['log'][:32]}) + '\n')
    except Exception:
        pass
    # verdict: pass only if a real bounded-unique exact-int discovery showed up
    if res['n_verified'] > 0:
        print(f"verdict=pass rationale={res['n_verified']}_verified_identity_of_{res['n_total']}_candidates")
    else:
        print(f"verdict=continue rationale=0_verified/{res['n_identity']}_identity/{res['n_nonident']}_noise_of_{res['n_total']}")

if __name__ == '__main__':
    main()
