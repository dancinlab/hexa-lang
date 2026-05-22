#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ribozyme_off_target_screen.py — deterministic stdlib-only Hamming-distance
off-target screen for ribozyme substrate-recognition arms.

Closes AXIS_CLOSURE_PLAN.md §3 / G26-RB-3 component (3): the "off-target screen"
stub is replaced with a real Hamming sliding-window scan against a representative
reference pool (toy 6-mRNA + (CUG)ₙ low-complexity decoy + a vendored GENCODE v47
pc-transcript subset n≈200 via `--refresh-gencode`, used by `--full-pool`); AND a
FULL GENCODE v47 pc-transcriptome screen was EXECUTED 2026-05-12 via RIsearch2 v2.1
(Alkan et al. NAR 45:e60, 2017) with the per-query summary vendored in
`ribozyme/spec/gencode_v47_offtarget_risearch2_summary.json` (see `--full-screen-results`
and `--gencode-pipeline-doc`). The MFE-port portion of G26-RB-3 (component (2)) was
already closed by `ribozyme_mfe_nussinov.py` on 2026-05-12 (R-R1).

Algorithm:
  For each substrate-recognition arm a (the 5' or 3' antisense arm of the
  ribozyme), scan every reference mRNA m in the pool with a sliding window
  of length len(a):
      hits[a] = #{ window w in m : Hamming(w, a)         ≤ seed_tolerance }
              + #{ window w in m : Hamming(w, rc(a))     ≤ seed_tolerance }
  where rc() is the reverse complement on RNA (A↔U, G↔C). Sum across the
  pool → off_target_count(a). Normalize by pool size in kb →
  off_target_per_kb(a). PASS gate: off_target_per_kb(a) ≤ MAX_PER_KB_GATE
  for each arm.

Pool (honest C3): the in-repo reference pool is a small
deterministic representative seed (~5 canonical AML-relevant human mRNA
fragments, ~100 nt each) chosen to exercise the algorithm with both
housekeeping (ACTB, GAPDH) and oncogene (MYC, KRAS, TP53) strata, PLUS one
synthetic low-complexity (CUG)ₙ triplet-repeat decoy representing the
low-complexity off-target stratum (real ASO/ribozyme off-target concern —
DMPK-style CUG expansions, CAG repeats, etc.). This is NOT a full
host-transcriptome backing — production screens use an external GenCode /
RefSeq DB. The in-repo portion closes the *algorithm + protocol*; the
full-corpus run remains out-of-repo (R5 sunset).

Deterministic: stdlib only, no network/time/random/env. Re-running on the
same inputs produces byte-identical output → §11 deductive verification
contract.
"""

from __future__ import annotations
from typing import Dict, List, Tuple
import sys


# ── Reference pool: small canonical AML-relevant seeds (deterministic) ──
# These are ~100 nt fragments lifted from canonical mRNA references; the
# *exact* sequences are intentionally small to keep the in-repo pool
# minimal. Production pool replaces this with full GenCode/RefSeq.
_POOL: List[Tuple[str, str]] = [
    ("ACTB_seed_5prime_UTR",
     "AGACGCCATCGCCCCCAGCCCCAGCCCCAGCCCGGGGCCCAACAGCCCCGGCAUCGACUUCCAUGGCCACGGCUGCUUCCAGCUCCUCCCC"),
    ("GAPDH_seed_CDS",
     "AGGUCAUCCAUGACAACUUUGGUAUCGUGGAAGGACUCAUGACCACAGUCCAUGCCAUCACUGCCACCCAGAAGACUGUGGAUGGCCCCU"),
    ("MYC_seed_3prime_UTR",
     "AGGCUUGAAAGAGAGGGGGUGGGUAUUUACUUUAAACAGCAAGGGAGCGUGCAGCGGAAACUUAGGCAUUUAUUUGUUUUUUUUUGCUCC"),
    ("KRAS_seed_CDS_codons1_30",
     "AUGACUGAAUAUAAACUUGUGGUAGUUGGAGCUGGUGGCGUAGGCAAGAGUGCCUUGACGAUACAGCUAAUUCAGAAUCAUUUUGUGGAC"),
    ("TP53_seed_DBD_codons150_180",
     "GCCGCCUGAGGUUGGCUCUGACUGUACCACCAUCCACUACAACUACAUGUGUAACAGUUCCUGCAUGGGCGGCAUGAACCGGAGGCCCAU"),
    # Synthetic low-complexity (CUG)n triplet-repeat decoy — NOT a real
    # transcript fragment; represents the low-complexity off-target stratum
    # (DMPK-style CUG expansions are a textbook ASO/ribozyme off-target trap).
    ("synth_low_complexity_CUG_repeat", "CUG" * 33 + "C"),
]


def reverse_complement(rna: str) -> str:
    table = str.maketrans("ACGU", "UGCA")
    return rna.translate(table)[::-1]


def hamming(a: str, b: str) -> int:
    if len(a) != len(b):
        raise ValueError(f"hamming: length mismatch {len(a)} vs {len(b)}")
    return sum(1 for x, y in zip(a, b) if x != y)


def _sanitize(seq: str) -> str:
    s = seq.upper().replace("T", "U")
    if not all(c in "ACGU" for c in s):
        bad = sorted({c for c in s if c not in "ACGU"})
        raise ValueError(f"non-RNA characters: {bad}")
    return s


def count_off_targets(arm: str, pool: List[Tuple[str, str]],
                      seed_tolerance: int = 1) -> Tuple[int, Dict[str, int]]:
    """Sliding-window Hamming scan of `arm` (and its reverse complement)
    against every mRNA in `pool`. Returns (total_hits, per_mrna_hits)."""
    arm = _sanitize(arm)
    rc = reverse_complement(arm)
    L = len(arm)
    total = 0
    per_mrna: Dict[str, int] = {}
    for mid, seq in pool:
        seq = _sanitize(seq)
        if len(seq) < L:
            per_mrna[mid] = 0
            continue
        c = 0
        for i in range(0, len(seq) - L + 1):
            w = seq[i:i + L]
            if hamming(w, arm) <= seed_tolerance:
                c += 1
            if rc != arm and hamming(w, rc) <= seed_tolerance:
                c += 1
        per_mrna[mid] = c
        total += c
    return total, per_mrna


def pool_size_kb(pool: List[Tuple[str, str]]) -> float:
    return sum(len(s) for _, s in pool) / 1000.0


def screen(arms_5prime_3prime: Tuple[str, str],
           pool: List[Tuple[str, str]] = None,
           seed_tolerance: int = 1,
           max_per_kb_gate: float = 4.0) -> Dict[str, object]:
    """Full screen.  Returns dict with per-arm counts, normalized rate, PASS flag."""
    if pool is None:
        pool = _POOL
    arm5, arm3 = arms_5prime_3prime
    pool_kb = pool_size_kb(pool)
    n5, by5 = count_off_targets(arm5, pool, seed_tolerance)
    n3, by3 = count_off_targets(arm3, pool, seed_tolerance)
    rate5 = n5 / pool_kb if pool_kb > 0 else 0.0
    rate3 = n3 / pool_kb if pool_kb > 0 else 0.0
    arm5_pass = rate5 <= max_per_kb_gate
    arm3_pass = rate3 <= max_per_kb_gate
    return {
        "arm_5prime": arm5,
        "arm_3prime": arm3,
        "seed_tolerance": seed_tolerance,
        "pool_kb": pool_kb,
        "pool_size_n": len(pool),
        "max_per_kb_gate": max_per_kb_gate,
        "arm_5prime_hits": n5,
        "arm_3prime_hits": n3,
        "arm_5prime_per_kb": rate5,
        "arm_3prime_per_kb": rate3,
        "arm_5prime_pass": arm5_pass,
        "arm_3prime_pass": arm3_pass,
        "overall_pass": arm5_pass and arm3_pass,
        "per_mrna_5prime": by5,
        "per_mrna_3prime": by3,
    }


# ── self-check / demo ───────────────────────────────────────────────────

_DEMO_CASES = [
    # AML FLT3-ITD-targeting hammerhead — arms complementary to FLT3 mRNA
    # junction. Arms are deliberately distinct from any pool seed so off-target
    # count should be LOW (PASS).
    ("ribozyme.aml.flt3_itd.v1",       ("CGAAUUCC", "GAACUUCG")),
    # Pan-coronavirus N-protein-targeting — same logic, distinct from pool.
    ("ribozyme.pancov.n_protein.v1",   ("UCGAUUAG", "CGUACGAU")),
    # Synthetic low-complexity arm — both arms are (CUG)n-repeat octamers, i.e.
    # complementary to the synth_low_complexity_CUG_repeat pool entry at every
    # 3rd window. Expected to FAIL the gate decisively (per-kb hits ≫ gate) —
    # demonstrates the screen actually detects off-targets, and that designing
    # a ribozyme arm against a triplet repeat is correctly flagged.
    ("ribozyme.synthetic_offtarget.demo", ("CUGCUGCU", "GCUGCUGC")),
]


def _selfcheck() -> int:
    print("ribozyme_off_target_screen — Hamming-distance off-target screen (G26-RB-3 component 3)")
    print(f"  reference pool: {len(_POOL)} mRNAs, total {pool_size_kb(_POOL):.3f} kb "
          f"(housekeeping + oncogene strata)")
    print()

    # Algorithmic sanity (deductive):
    print("  [PASS] reverse_complement involution — rc(rc(s)) == s for canonical hammerhead core")
    s = "CUGAUGAGGCCG"
    assert reverse_complement(reverse_complement(s)) == s, "rc involution failed"
    print("  [PASS] hamming triangle inequality — H(a,c) ≤ H(a,b) + H(b,c) on a 3-seq probe")
    a, b, c = "AUCG", "AUGG", "GUGG"
    assert hamming(a, c) <= hamming(a, b) + hamming(b, c), "hamming triangle failed"
    print()

    fails = 0
    for label, (a5, a3) in _DEMO_CASES:
        r = screen((a5, a3))
        verdict = "PASS" if r["overall_pass"] else "FAIL"
        emoji = "✓" if r["overall_pass"] else "✗"
        # FAIL is the EXPECTED verdict for the synthetic_offtarget demo case —
        # we WANT the screen to flag a deliberately-designed off-targeter.
        expected_pass = label != "ribozyme.synthetic_offtarget.demo"
        algorithmic_ok = r["overall_pass"] == expected_pass
        if not algorithmic_ok:
            fails += 1
        mark = "PASS" if algorithmic_ok else "FAIL"
        print(f"  [{mark}] {label:<40} 5'={a5} 3'={a3}  "
              f"hits 5'/3' = {r['arm_5prime_hits']}/{r['arm_3prime_hits']}  "
              f"per-kb 5'/3' = {r['arm_5prime_per_kb']:.2f}/{r['arm_3prime_per_kb']:.2f}  "
              f"screen_verdict={verdict}  expected={'PASS' if expected_pass else 'FAIL'}")

    # Determinism check.
    r1 = screen(("CGAAUUCC", "GAACUUCG"))
    r2 = screen(("CGAAUUCC", "GAACUUCG"))
    if r1 == r2:
        print(f"  [PASS] determinism — byte-identical re-run")
    else:
        fails += 1
        print(f"  [FAIL] determinism — output drift")

    total = len(_DEMO_CASES) + 1  # 3 cases + determinism
    print()
    if fails == 0:
        print(f"  --- summary --- {total} / {total} PASS → verdict: PASS")
        print("  scope (C3): the in-repo screen ships the deterministic Hamming algorithm + a representative pool")
        print("        (toy 6-mRNA + (CUG)ₙ low-complexity decoy; + a GENCODE v47 pc-transcript subset n≈200 via `--refresh-gencode`,")
        print("         used by `--full-pool`). The FULL ~250k-transcript GENCODE/RefSeq screen with RIsearch2-grade ΔG/accessibility")
        print("         scoring + NHH-triplet adjacency is the documented external step (`--gencode-pipeline-doc`; needs a real aligner).")
        print("        In-repo G26-RB-3 component (3): algorithm + protocol + representative pool CLOSED; full-transcriptome = external.")
        print("__RIBOZYME_OFF_TARGET_SCREEN__ PASS")
        return 0
    print(f"  --- summary --- {fails} FAIL → verdict: FAIL")
    print("__RIBOZYME_OFF_TARGET_SCREEN__ FAIL")
    return 1


# ── GENCODE v47 human transcript pool (extends the toy reference pool — G26-RB-3 §B / AXIS_CLOSURE_PLAN §12) ──
# Vendored snapshot: the first N protein-coding transcripts of GENCODE v47 (GRCh38),
# each truncated to TRUNC_NT nt — a *representative* human-transcriptome subset, NOT
# the full ~250k-transcript set.  `--refresh-gencode` rebuilds it from the live FTP;
# `--full-pool` runs the off-target screen against {core toy pool ∪ this snapshot}.
# The *full* GENCODE/RefSeq transcriptome screen with RIsearch2-grade ΔG/accessibility
# scoring + NHH-triplet adjacency is the documented external step — see
# `gencode_pipeline_doc()` below, `docs/closure_100_research_2026_05_12.md` §B.
import os as _os
_GENCODE_SNAPSHOT_REL = _os.path.join("ribozyme", "spec", "human_transcript_pool_snapshot.json")
_GENCODE_FASTA_URL = "https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_47/gencode.v47.pc_transcripts.fa.gz"
_GENCODE_N = 200          # # transcripts to keep in the vendored snapshot
_GENCODE_TRUNC_NT = 400   # truncate each transcript to this many nt


def _repo_root() -> str:
    return _os.path.abspath(_os.path.join(_os.path.dirname(__file__), "..", ".."))


def _snapshot_path() -> str:
    return _os.path.join(_repo_root(), _GENCODE_SNAPSHOT_REL)


def load_gencode_snapshot():
    """Return list of (transcript_id, RNA-sequence) for the vendored GENCODE subset, or [] if absent."""
    p = _snapshot_path()
    if not _os.path.isfile(p):
        return []
    import json as _json, io as _io
    d = _json.loads(_io.open(p, encoding="utf-8").read())
    return [(t["transcript_id"], t["seq"]) for t in d.get("transcripts", [])]


def refresh_gencode(n: int = _GENCODE_N, trunc_nt: int = _GENCODE_TRUNC_NT, timeout: float = 120.0) -> dict:
    """Download GENCODE v47 pc_transcripts FASTA, keep the first `n` records (truncated to `trunc_nt` nt),
    write the vendored snapshot. Network — NOT used in the gate."""
    import urllib.request, ssl, gzip, io as _io, json as _json
    print(f"  [gencode] downloading {_GENCODE_FASTA_URL} (~48 MB) …", flush=True)
    req = urllib.request.Request(_GENCODE_FASTA_URL, headers={"User-Agent": "Mozilla/5.0 (hexa-bio ribozyme off-target pool refresh)"})
    with urllib.request.urlopen(req, timeout=timeout, context=ssl.create_default_context()) as r:
        raw = r.read()
    txt = gzip.decompress(raw).decode("ascii", "replace")
    transcripts, cur_id, cur_gene, cur_seq, kept = [], None, None, [], 0
    for line in txt.splitlines():
        if line.startswith(">"):
            if cur_id is not None and kept < n:
                seq = "".join(cur_seq).upper().replace("T", "U")[:trunc_nt]
                if all(c in "ACGU" for c in seq) and len(seq) >= 30:
                    transcripts.append({"transcript_id": cur_id, "gene": cur_gene, "seq": seq}); kept += 1
            if kept >= n:
                cur_id = None; continue
            fields = line[1:].split("|")
            cur_id = fields[0].split(".")[0]                       # ENST… (strip version)
            cur_gene = fields[5] if len(fields) > 5 else ""        # GENCODE pipe-format gene name
            cur_seq = []
        elif cur_id is not None:
            cur_seq.append(line.strip())
    if cur_id is not None and kept < n:
        seq = "".join(cur_seq).upper().replace("T", "U")[:trunc_nt]
        if all(c in "ACGU" for c in seq) and len(seq) >= 30:
            transcripts.append({"transcript_id": cur_id, "gene": cur_gene, "seq": seq})
    snap = {"source": "GENCODE v47 (GRCh38; Frankish et al., NAR 2025) — pc_transcripts FASTA, first N records, truncated",
            "url": _GENCODE_FASTA_URL, "release": "v47", "n_transcripts": len(transcripts),
            "trunc_nt": trunc_nt, "built_at": "2026-05-12T00:00:00Z (fixed for determinism)",
            "note": "REPRESENTATIVE SUBSET, not the full ~250k-transcript transcriptome — see gencode_pipeline_doc() for the full-screen external step",
            "transcripts": transcripts}
    p = _snapshot_path(); _os.makedirs(_os.path.dirname(p), exist_ok=True)
    _io.open(p, "w", encoding="utf-8").write(_json.dumps(snap, ensure_ascii=False, indent=1))
    print(f"  [gencode] wrote {len(transcripts)} transcripts → {p}", flush=True)
    return snap


def report_full_pool() -> None:
    """Run the off-target screen for the legit demo arms against {core toy pool ∪ GENCODE snapshot}."""
    extra = load_gencode_snapshot()
    if not extra:
        print("  [full-pool] no GENCODE snapshot vendored — run `--refresh-gencode` to build "
              f"`{_GENCODE_SNAPSHOT_REL}` (the core 7-entry toy pool is what the gate's self-check uses).")
        return
    combined = list(_POOL) + extra
    pool_kb = pool_size_kb(combined)
    print(f"\n  --- full-pool screen: core toy pool ({len(_POOL)}) + GENCODE v47 pc-transcript subset ({len(extra)}) = {len(combined)} sequences, {pool_kb:.2f} kb ---")
    print(f"      (representative human-transcriptome subset — NOT the full ~250k-transcript set; full screen = external step, see `--gencode-pipeline-doc`)")
    for label, (a5, a3) in _DEMO_CASES:
        r = screen((a5, a3), pool=combined)
        v = "PASS" if r["overall_pass"] else "FAIL"
        print(f"      {label:<40} 5'={a5} 3'={a3}  hits 5'/3' = {r['arm_5prime_hits']}/{r['arm_3prime_hits']}  "
              f"per-kb 5'/3' = {r['arm_5prime_per_kb']:.3f}/{r['arm_3prime_per_kb']:.3f}  screen_verdict={v}")
    # determinism on the combined pool
    a = screen(("CGAAUUCC", "GAACUUCG"), pool=combined)
    b = screen(("CGAAUUCC", "GAACUUCG"), pool=combined)
    print(f"      [{'PASS' if a == b else 'FAIL'}] determinism on combined pool")


def gencode_pipeline_doc() -> None:
    print(__doc__.strip().splitlines()[0])
    print()
    print("FULL host-transcriptome off-target screen — documented external step (G26-RB-3 §B / docs/closure_100_research_2026_05_12.md §B):")
    print("  1. reference transcriptome:")
    print(f"       wget {_GENCODE_FASTA_URL.replace('pc_transcripts','transcripts')}    # GENCODE v47 all transcripts (~250k), GRCh38")
    print("       # (or RefSeq GCF_000001405.40_GRCh38.p14_rna.fna.gz, or Ensembl Homo_sapiens.GRCh38.cdna.all.fa.gz)")
    print("  2. aligner / interaction predictor (pick one):")
    print("       RIsearch2  (rth.dk/resources/risearch/ — suffix-array seed+extend RNA-RNA, the siRNA-off-target standard;")
    print("                   has an off-targeting-potential pipeline weighting hits by target accessibility + transcript abundance)")
    print("       Cas-OFFinder (rgenome.net/cas-offinder — genome-wide, no mismatch-count limit, allows bulges, OpenCL-accelerated)")
    print("       bowtie -v 3 / bwa  (fast near-exact short-k-mer alignment vs the transcriptome FASTA)")
    print("  3. scoring: count ≤1–2 mismatch/G·U-wobble hits per arm, weight by RIsearch2 ΔG (and RNAplfold target accessibility);")
    print("             flag complementarity blocks ≥ ~10–12 nt adjacent to an NHH triplet (NUH ∪ NCH ∪ some NAH — Kore et al. NAR 26:4116, 1998);")
    print("             refs: Alkan et al. NAR 45:e60 (2017); Damle et al. Nucleic Acid Ther. 35:249 (2025); Werner & Uhlenbeck NAR 23:2092 (1995).")
    print("  ✅ EXECUTED 2026-05-12 — RIsearch2 v2.1 (precompiled risearch2.x binary, GPLv3) against the FULL GENCODE v47 pc-transcriptome")
    print("     (gencode.v47.pc_transcripts.fa.gz; RIsearch2 SA: N=544406234 positions, K=224436 sequences incl. revcomp), -s 6 -e -22 -z t04.")
    print("     Per-query summary vendored in `ribozyme/spec/gencode_v47_offtarget_risearch2_summary.json` (see `--full-screen-results`).")
    print("     Result confirms the §B point: designed 14-nt candidate arms get few/no strong off-targets (e.g. cand_arm_A: 24 hits, 0 at ΔG≤-25 → PASS);")
    print("     a GC-rich 14-mer or a (CUG)ₙ-repeat arm floods (24.8k–1.37M interactions across thousands of genes incl. ATXN2 etc. → FAIL).")
    print("  C3: the RIsearch2 binary (156 KB GPLv3) + the ~48 MB transcriptome FASTA are NOT vendored — only the per-query summary;")
    print("             the in-repo gate ships the deterministic Hamming algorithm + a representative pool (toy 6-mRNA + (CUG)ₙ decoy + GENCODE")
    print("             v47 pc-transcript subset n≈200 via --refresh-gencode) for offline determinism; the full RIsearch2 'off-targeting-potential'")
    print("             score (+ target accessibility + transcript-abundance/TPM weighting) is the cited external tool's full pipeline.")


def print_full_screen_results() -> None:
    """Print the vendored RIsearch2 full-transcriptome screen summary."""
    import json as _json
    p = _os.path.join(_repo_root(), "ribozyme", "spec", "gencode_v47_offtarget_risearch2_summary.json")
    if not _os.path.isfile(p):
        print(f"  [full-screen-results] no vendored summary at {p} — run the RIsearch2 pipeline (`--gencode-pipeline-doc`).")
        return
    d = _json.loads(open(p, encoding="utf-8").read())
    print("  ── RIsearch2 v2.1 FULL GENCODE v47 pc-transcriptome off-target screen (executed 2026-05-12) ──")
    print(f"     tool   : {d['tool']}")
    print(f"     target : {d['target_corpus']}  ({d['target_index_stats']})")
    print(f"     params : {d['params']}")
    print(f"     {'query':<32} {'n_interactions':>14} {'n_genes':>9} {'ΔG_min':>8} {'≤-25':>8} {'≤-28':>8}  verdict")
    for qid, s in d["queries"].items():
        print(f"     {qid:<32} {s['n_interactions']:>14,} {s['n_distinct_genes']:>9,} {s['dG_min']:>8.1f} "
              f"{s['n_at_dG_le_-25']:>8,} {s['n_at_dG_le_-28']:>8,}  {s['screen_verdict']}")
    print(f"     ({d['raw_91_c3'][:200]}…)")
    print(f"     reproduce: {d['reproduce']}")


def main() -> int:
    if "--gencode-pipeline-doc" in sys.argv:
        gencode_pipeline_doc(); return 0
    if "--refresh-gencode" in sys.argv:
        refresh_gencode(); print()
    rc = _selfcheck()
    if "--full-pool" in sys.argv or load_gencode_snapshot():
        report_full_pool()
    if "--full-screen-results" in sys.argv or _os.path.isfile(_os.path.join(_repo_root(), "ribozyme", "spec", "gencode_v47_offtarget_risearch2_summary.json")):
        print()
        print_full_screen_results()
    return rc


if __name__ == "__main__":
    sys.exit(main())
