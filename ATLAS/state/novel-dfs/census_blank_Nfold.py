#!/usr/bin/env python3
"""LANE 1 — @N fold prep: emit refuted/⚪ @N atom RECORDS for the closed-⚪ census cells.

The @F census grid (11 funcs, distinct unordered products, distinct cells) classifies every
cell by solution count of A*B=C*D over n in [2,N]. census_blank_classify.py proved the split
2145 = filled-🔵 64 + closed-⚪ 1654 + multi-⊞ 321 + degenerate 106. This generator reuses
af() VERBATIM from blue_harvest_12fn.py (reference-match), re-derives the SAME grid, isolates
the 1654 closed-⚪ cells (0 solutions = A*B != C*D for every n in [2,N]), and EMITS each as an
@N atom block in the embedded.gen.hexa atom TEXT format to census_Nfold_atoms.txt.

HONEST: these are BOUNDED negatives (no n in [2, 2e4]); NOT proven for all n. The atom text
says "refuted ... bounded-negative" and cites forall-n UNPROVEN (c2). Deterministic: same
N -> same grid -> same ordered atom list -> byte-identical output every run.

LOCAL ONLY (pure Python, mini). No hexa build, no embedded.gen.hexa mutation, no git commit.
Usage: python3 census_blank_Nfold.py [N]   (default N=20000)
"""
import itertools
import sys

N = int(sys.argv[1]) if len(sys.argv) > 1 else 20000
spf = list(range(N + 1))
for i in range(2, int(N ** 0.5) + 1):
    if spf[i] == i:
        for j in range(i * i, N + 1, i):
            if spf[j] == j:
                spf[j] = i


def af(n):  # verbatim from blue_harvest_12fn.py
    if n == 1:
        return dict(sig=1, sig2=1, sig3=1, phi=1, tau=1, n=1, sopfr=0, rad=1, J2=1, psi=1, Om=0, om=0)
    m = n
    sig = sig2 = sig3 = tau = phi = psi = J2 = 1
    sopfr = 0
    rad = 1
    Om = 0
    om = 0
    while m > 1:
        p = spf[m]
        e = 0
        while m % p == 0:
            m //= p
            e += 1
        sig *= (p ** (e + 1) - 1) // (p - 1)
        sig2 *= (p ** (2 * (e + 1)) - 1) // (p ** 2 - 1)
        sig3 *= (p ** (3 * (e + 1)) - 1) // (p ** 3 - 1)
        tau *= (e + 1)
        phi *= p ** (e - 1) * (p - 1)
        psi *= p ** (e - 1) * (p + 1)
        J2 *= p ** (2 * e) - p ** (2 * (e - 1))
        sopfr += p * e
        rad *= p
        Om += e
        om += 1
    return dict(sig=sig, sig2=sig2, sig3=sig3, phi=phi, tau=tau, n=n, sopfr=sopfr, rad=rad, J2=J2, psi=psi, Om=Om, om=om)


F = [None] + [af(n) for n in range(1, N + 1)]

# The 11 census functions (atom-derived vocabulary; blue_harvest's sig3 never appeared -> excluded).
keys = ['sig', 'sig2', 'phi', 'tau', 'n', 'sopfr', 'rad', 'J2', 'psi', 'Om', 'om']
products = [(a, b) for i, a in enumerate(keys) for b in keys[i:]]  # 66 unordered products A*B
MIN_N = 4

# Display / id name maps. @F atoms render sig as "sigma" in both the id and the formula body;
# keep every other function key verbatim. Mirror that for @N (reference-match).
name = {'sig': 'sigma', 'sig2': 'sig2', 'phi': 'phi', 'tau': 'tau', 'n': 'n',
        'sopfr': 'sopfr', 'rad': 'rad', 'J2': 'J2', 'psi': 'psi', 'Om': 'Om', 'om': 'om'}

DATE = "2026-06-25"
N_DISP = "2e4"  # matches @F atoms' "[2,2e4]" phrasing


def atom_block(a, b, c, d):
    A, B, C, D = name[a], name[b], name[c], name[d]
    nid = f"refuted-id-{A}-{B}-neq-{C}-{D}"
    head = f"@N {nid} = {A}*{B} != {C}*{D} :: refuted [d={DATE} active]"
    vby = (f'  verified-by = "exact-int: no n in [2,{N_DISP}] satisfies '
           f'{A}*{B}={C}*{D} (bounded-negative)"')
    cite = '  cite = "@D ATLAS-DFS · bounded-negative (forall-n UNPROVEN · c2)"'
    prov = ('  provenance = "census_blank_classify sweep -> @N fold '
            '(ATLAS/state/novel-dfs/census_blank_Nfold.py)"')
    return "\n".join([head, vby, cite, prov])


filled = degenerate = multi = closed = 0
blocks = []
for (a, b), (c, d) in itertools.combinations(products, 2):  # 2145 distinct-product cells
    sol = []
    for n in range(2, N + 1):
        if F[n][a] * F[n][b] == F[n][c] * F[n][d]:
            sol.append(n)
            if len(sol) > 2:
                break
    if len(sol) == 0:
        closed += 1
        blocks.append(atom_block(a, b, c, d))
    elif len(sol) == 1 and sol[0] >= MIN_N:
        filled += 1
    elif len(sol) == 1:
        degenerate += 1
    else:
        multi += 1

total = len(products) * (len(products) - 1) // 2

out_path = "ATLAS/state/novel-dfs/census_Nfold_atoms.txt"
with open(out_path, "w") as fh:
    fh.write("\n\n".join(blocks))
    fh.write("\n")

print(f"=== @N fold prep — closed-⚪ census cells (11 funcs, N={N}) ===")
print(f"  denominator (cells)        = {total}")
print(f"  filled-🔵 (1-sol, n>=4)     = {filled}")
print(f"  closed-⚪ (0 solutions)     = {closed}   <- @N atoms EMITTED")
print(f"  multi-⊞  (>=2 solutions)   = {multi}")
print(f"  degenerate (1-sol, n<4)    = {degenerate}")
print(f"  CHECK filled+closed+multi+degenerate = {filled + closed + multi + degenerate} (== {total})")
print(f"  @N blocks written          = {len(blocks)} -> {out_path}")
print()
print("--- 3 sample @N blocks ---")
for blk in blocks[:3]:
    print(blk)
    print()
