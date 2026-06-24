#!/usr/bin/env python3
"""LANE B fold — emit the @F AtlasNode struct-literal for the FIRST machine-discovered
∀n true-forever identity surfaced by the census fleet:  J₂(n) = φ(n)·ψ(n).

This is the Jordan-totient identity (Jordan totient J_k at k=2; φ = Euler totient,
ψ = Dedekind psi). It is CLASSICAL — a known theorem, NOT a novel claim — so the atom
cites the classical Jordan/Dedekind multiplicative-function identity. universal_hunt.py
mechanically (re)discovered it as the UNIQUE distinct ∀n-real identity over the 12-fn
extended frame (no LLM): ∀n∈[2,N] J₂=φ·ψ (n=12→96, n=30→576, n=360→82944).

HONEST: the sweep is bounded ∀n∈[2,N] (exact integer), NOT a from-scratch proof — but the
identity itself is a classical theorem (cited), so the atom is a classical-cite @F. The
struct-literal is emitted with grade verified:false (matching EVERY existing @F atom in
embedded.gen.hexa — the 64 blue_harvest @F + the bridge @F are all verified:false); 🔵
promotion is gated ONLY on a real `hexa verify` pass on a build host (CLAUDE.md atlas rule).

Emits the ONE-LINE AtlasNode struct literal in embedded.gen.hexa's exact format. With
`--fold <path>` it splices that line into the embedded.gen.hexa @F section (idempotent on
the (kind,id) key — re-running never double-inserts). Without --fold it prints the line.

Deterministic: same input -> byte-identical struct line every run. LOCAL ONLY (pure Python).
Usage:
  python3 jordan_totient_fold.py                         # print the struct line + the n-checks
  python3 jordan_totient_fold.py --fold compiler/atlas/embedded.gen.hexa   # splice it in
"""
import sys

# ── reference-match af() (verbatim formulas from blue_harvest_12fn / universal_hunt) ──
def af(n):
    m = n
    phi = psi = J2 = 1
    p = 2
    while p * p <= m:
        if m % p == 0:
            e = 0
            while m % p == 0:
                m //= p
                e += 1
            phi *= p ** (e - 1) * (p - 1)
            psi *= p ** (e - 1) * (p + 1)
            J2 *= p ** (2 * e) - p ** (2 * (e - 1))
        p += 1
    if m > 1:  # last prime factor (e=1)
        phi *= (m - 1)
        psi *= (m + 1)
        J2 *= m * m - 1
    return phi, psi, J2


def bounded_forall(N):
    """True iff J2(n) == phi(n)*psi(n) for EVERY n in [2,N]; break on first failure."""
    for n in range(2, N + 1):
        phi, psi, J2 = af(n)
        if J2 != phi * psi:
            return False, n
    return True, None


DATE = "2026-06-25"
ATOM_KIND = "F"
ATOM_ID = "atlas-jordan-totient-J2-eq-phi-psi"
N_DISP = "3e3"  # the bounded ∀n window actually swept here (matches the universal_hunt cross-check)

# @F atom raw header + fields, matching the existing blue_harvest / bridge @F format verbatim.
RAW = "\n".join([
    "@F " + ATOM_ID + " = J2 = phi*psi (Jordan totient J_2 = Euler phi * Dedekind psi) :: formula [d=" + DATE + " active]",
    '  verified-by = "exact-int: J2(n)=phi(n)*psi(n) holds for all n in [2,' + N_DISP + '] (mechanical census-fleet (re)discovery, no LLM); spot n=12->96 n=30->576 n=360->82944"',
    '  cite = "classical Jordan-totient identity J_k(n)=prod p^{k(e-1)}(p^k-1); at k=2 J_2=phi*psi (phi Euler, psi Dedekind) · multiplicative · forall-n THEOREM (Jordan 1870 / Dedekind psi) — classical, NOT novel"',
    '  provenance = "census fleet r2 universal-hunt -> embedded.gen.hexa fold (PR · ATLAS/state/novel-dfs/jordan_totient_fold.py · generator universal_hunt.py)"',
])


def hxesc(s):
    """Match embed_fold::embed_hxesc / atlas_cli::_hxesc — escape \\ then \" then newline for the
    raw: string literal embedded in the .hexa source."""
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def struct_line():
    return (
        '    AtlasNode { kind: "' + ATOM_KIND + '", id: "' + hxesc(ATOM_ID) +
        '", raw: "' + hxesc(RAW) +
        '", source_file: "register", source_line: 0'
        ', grade: GradeInfo { value: -1, verified: false, breakthrough: false, hypothesis: false }'
        ', edges: EdgeInfo { depends_on: [], derives: [], applications: [], equivalents: [], converges: [], verified_by: [], breakthroughs: [] } }'
    )


def fold_into(path):
    line = struct_line()
    with open(path, "r") as fh:
        text = fh.read()
    # idempotent on the (kind,id) composite key — same dedup contract as embed_fold_into.
    needle = 'kind: "' + ATOM_KIND + '", id: "' + ATOM_ID + '"'
    if needle in text:
        print("SKIP: (kind=" + ATOM_KIND + ", id=" + ATOM_ID + ") already present in " + path)
        return
    lines = text.splitlines(keepends=True)
    # Insert right after the @F section opener `ATLAS_F_NODES: [AtlasNode] = [` — the canonical
    # per-kind section for @F atoms. The loader (static_index::_bucket_by_kind) buckets each node
    # by its `kind` field into the matching ATLAS_<kind>_NODES list; @F atoms belong in
    # ATLAS_F_NODES (matching `register --from-verify`). Splice after the opener.
    opener_idx = None
    for i, ln in enumerate(lines):
        if "ATLAS_F_NODES: [AtlasNode] = [" in ln:
            opener_idx = i
            break
    if opener_idx is None:
        sys.exit("ERROR: could not find `ATLAS_F_NODES: [AtlasNode] = [` opener in " + path)
    insert = line + ("\n" if not line.endswith("\n") else "")
    # the existing first node line ends with `,` — our inserted line must too (it's not last).
    insert = insert.rstrip("\n") + ",\n"
    lines.insert(opener_idx + 1, insert)
    with open(path, "w") as fh:
        fh.write("".join(lines))
    print("FOLDED @F " + ATOM_ID + " into " + path + " (after ATLAS_F_NODES opener, line " + str(opener_idx + 1) + ")")


if __name__ == "__main__":
    if len(sys.argv) >= 3 and sys.argv[1] == "--fold":
        fold_into(sys.argv[2])
    else:
        ok, fail = bounded_forall(3000)
        print("=== J2 = phi*psi — Jordan-totient identity (classical · machine-(re)discovered) ===")
        print("  bounded forall n in [2,3000]: " + ("HOLDS (no counterexample)" if ok else "FAILS at n=" + str(fail)))
        for n in (12, 30, 360):
            phi, psi, J2 = af(n)
            print("  n=%-4d  J2=%-7d  phi*psi=%-7d  %s" % (n, J2, phi * psi, "OK" if J2 == phi * psi else "MISMATCH"))
        print()
        print("--- @F AtlasNode struct line (for embedded.gen.hexa ATLAS_F_NODES) ---")
        print(struct_line())
        print()
        print("fold:  python3 ATLAS/state/novel-dfs/jordan_totient_fold.py --fold compiler/atlas/embedded.gen.hexa")
