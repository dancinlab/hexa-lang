#!/usr/bin/env python3
"""aav_vector_optimizer.py — drylab #3 · AAV vector-design budget optimizer.

Sequence-level cassette-budget optimizer: maximizes payload headroom
(headroom = cap - Σ elements) by deterministic element selection +
CAI-anchored synonymous recoding that preserves the input amino-acid
sequence exactly. Codon substitution is length-invariant, so CAI is a
literature-anchored codon-bias *annotation* only — it never changes CDS
length and is NOT an expression/transduction prediction.

This is the OPTIMIZER companion to the JUDGE
`../../_python_bridge/module/aav_cargo_capacity_check.py` (that module only
asks "does it fit?"; this one asks "select smallest sourced elements and
recode the CDS deterministically, then report headroom + dual-AAV flag").
Cross-ref the cited reverse-engineering spec: `../research/aav_vector_optimizer.md`.

═══ Real-limit anchor (g1 — ceiling is biology, NOT the n=6 lattice) ═══
  AAV ssDNA packaging wall ≈ 4.7 kb (ITR-to-ITR). Primary:
    • Wu Z, Yang H, Colosi P. Effect of Genome Size on AAV Vector
      Packaging. Mol Ther 2010;18(1):80-86. DOI 10.1038/mt.2009.255
      (packaged genomes never exceeded ~5.0-5.2 kb; >5 kb heterogeneous
      / 5'-truncated).
    • Wang D, Tai PWL, Gao G. AAV vector as a platform for gene therapy
      delivery. Nat Rev Drug Discov 2019;18:358-378 (~4.7 kb genome).
  Two 145 bp ITRs are mandatory (Wu 2010; Addgene viral-vectors-101).
  Default cap = 4650 bp = conservative effective payload below the ~4.7 kb
  wall after the ITR + packaging-efficiency margin — anchored to the cited
  Wu 2010 / Wang 2019 limit, NOT to any lattice number.

  CAI: Sharp PM, Li WH. The codon adaptation index. Nucleic Acids Res
  1987;15(3):1281-1295. PMID 3547335 (PMC340524). Log-form geometric
  mean; Met/Trp/stop excluded; w<1e-4 -> 0.01 floor (standard
  seqinr/EMBOSS convention attributing to Sharp & Li 1987).

═══ Codon-table sourcing note (g3 — NO fabricated frequencies) ═══
  Only the CANONICAL GENETIC CODE (codon -> amino-acid, a fixed biological
  constant) is embedded below. Codon-usage FREQUENCIES are NEVER embedded
  or invented. The human codon-usage table is a REQUIRED EXTERNAL INPUT
  supplied by the curator from an authoritative public database:
    • Kazusa Codon Usage Database — Homo sapiens [gbpri], taxid 9606
      (Nakamura Y, Gojobori T, Ikemura T. Nucleic Acids Res
      2000;28(1):292; http://www.kazusa.or.jp/codon/ showcodon.cgi?
      species=9606), OR
    • HIVE-CUT / CoCoPUTs (Athey J et al. BMC Bioinformatics
      2017;18:391) — RefSeq-curated, reduced redundancy.
  If the table file is absent or schema-invalid the optimizer FAILS CLOSED
  with the authoritative-source pointer above; it NEVER substitutes
  invented numbers.

═══ Honest scope (g8 / f2) ═══
  This is a SEQUENCE-BUDGET tool: it computes element lengths, headroom, a
  deterministic CAI annotation, and a dual-AAV flag. It does NOT predict
  expression level, transduction efficiency, immunogenicity, tropism,
  splicing fidelity, protein folding, or any therapeutic / clinical /
  regulatory outcome (Mauro & Chappell, Trends Mol Med 2014;20(11):604-613
  explicitly caution against equating codon optimization with improved
  therapeutic outcome). A "fits / headroom > 0" result means ONLY that the
  chosen elements sum below the cited packaging cap — NOT that the vector
  works. All AAV axes in hexa-bio are scientifically UNPROVEN at the
  wet-lab boundary (CLOSURE_RESIDUAL_BACKLOG §0; AGENTS.tape g8 / f2).

Determinism: pure Python stdlib (math, json, argparse, sys, hashlib only;
no numpy / Biopython / random / network / time). Same inputs ->
byte-identical output.

License: Apache-2.0 (hexa-bio core).
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
from typing import Dict, List, Optional, Tuple

# ══════════════════════════════════════════════════════════════════════
# §A  CANONICAL GENETIC CODE  (embeddable: fixed biological constant,
#     NOT a frequency statistic — see codon-table sourcing note above).
#     Standard genetic code (NCBI translation table 1). 64 codons.
# ══════════════════════════════════════════════════════════════════════
GENETIC_CODE: Dict[str, str] = {
    "TTT": "F", "TTC": "F", "TTA": "L", "TTG": "L",
    "CTT": "L", "CTC": "L", "CTA": "L", "CTG": "L",
    "ATT": "I", "ATC": "I", "ATA": "I", "ATG": "M",
    "GTT": "V", "GTC": "V", "GTA": "V", "GTG": "V",
    "TCT": "S", "TCC": "S", "TCA": "S", "TCG": "S",
    "CCT": "P", "CCC": "P", "CCA": "P", "CCG": "P",
    "ACT": "T", "ACC": "T", "ACA": "T", "ACG": "T",
    "GCT": "A", "GCC": "A", "GCA": "A", "GCG": "A",
    "TAT": "Y", "TAC": "Y", "TAA": "*", "TAG": "*",
    "CAT": "H", "CAC": "H", "CAA": "Q", "CAG": "Q",
    "AAT": "N", "AAC": "N", "AAA": "K", "AAG": "K",
    "GAT": "D", "GAC": "D", "GAA": "E", "GAG": "E",
    "TGT": "C", "TGC": "C", "TGA": "*", "TGG": "W",
    "CGT": "R", "CGC": "R", "CGA": "R", "CGG": "R",
    "AGT": "S", "AGC": "S", "AGA": "R", "AGG": "R",
    "GGT": "G", "GGC": "G", "GGA": "G", "GGG": "G",
}

# Synonymous-codon set S(aa) per amino acid (derived from GENETIC_CODE;
# canonical, not a frequency).
SYNONYMS: Dict[str, List[str]] = {}
for _codon, _aa in GENETIC_CODE.items():
    SYNONYMS.setdefault(_aa, []).append(_codon)
for _aa in SYNONYMS:
    SYNONYMS[_aa].sort()  # lexicographic order -> deterministic tie-break

# Single-codon amino acids + stop are excluded from CAI's L
# (Met=AUG, Trp=UGG, stop) — standard seqinr/EMBOSS convention
# attributing to Sharp & Li 1987.
CAI_EXCLUDED_AA = frozenset({"M", "W", "*"})
CAI_FLOOR = 0.01          # w < 1e-4 -> 0.01 (standard seqinr convention)
CAI_FLOOR_THRESHOLD = 1e-4

# ── Real-limit anchored default cap (Wu 2010 / Wang 2019; NOT lattice) ──
DEFAULT_CAP_BP = 4650     # conservative effective payload < ~4.7 kb wall

# ── Sourced element sizes (g3 — quoted from cited primary literature;
#    the spec's authoritative numbers, NOT the task brief's unsourced
#    figures; the unverifiable "minimal CMV" is OMITTED, not guessed). ──
ITR_BP = 145              # each, x2 — Wu/Yang/Colosi 2010 + Addgene VV-101
KOZAK_BP = 10             # GCCRCCATGG functional region — Kozak 1987

DEFAULT_PROMOTERS: Dict[str, Dict[str, object]] = {
    "cTnT_chicken": {"len": 418, "source": "Pathogens 2023;12(11):1301 (PMC10675517)"},
    "cTnT_human":   {"len": 544, "source": "Pathogens 2023;12(11):1301 (PMC10675517)"},
    "cTnT_CSCRM4":  {"len": 637, "source": "Pathogens 2023;12(11):1301 (PMC10675517)"},
    "MHCK7":        {"len": 770, "source": "Pathogens 2023;12(11):1301 (PMC10675517)"},
    "CK8":          {"len": 837, "source": "Pathogens 2023;12(11):1301 (PMC10675517)"},
    # Full CMV immediate-early promoter (Powell 2015). The precise
    # "minimal CMV" length was NOT primary-sourced -> intentionally
    # OMITTED (g3); a curator may add it later WITH a citation.
    "CMV_full":     {"len": 775, "source": "Powell, Rivera-Soto, Gray, Discov Med 2015;19(102):49-57"},
}
DEFAULT_POLYA: Dict[str, Dict[str, object]] = {
    "SV40": {"len": 135, "source": "Powell 2015"},
    "bGH":  {"len": 250, "source": "Powell 2015"},   # sourced 250, NOT brief's 225
    "SPA":  {"len": 49,  "source": "Powell 2015"},
}
DEFAULT_WPRE: Dict[str, Dict[str, object]] = {
    "none":  {"len": 0,   "source": "n/a"},
    "WPRE":  {"len": 600, "source": "Powell 2015"},
    "WPRE3": {"len": 247, "source": "Powell 2015"},
}

# Trapani 2014 dual-AAV split strategies (informational flag only — the
# optimizer does NOT simulate recombination).
DUAL_AAV_STRATEGIES = [
    {"id": "TS",     "name": "trans-splicing",
     "desc": "vector A: promoter+5'-half+splice donor; vector B: splice acceptor+3'-half+polyA"},
    {"id": "OV",     "name": "overlapping",
     "desc": "A & B share a homologous overlap; reconstitution by homologous recombination"},
    {"id": "hybrid", "name": "hybrid (AK)",
     "desc": "TS + added recombinogenic region (e.g. AK) to boost concatemerization"},
]
DUAL_AAV_CITATION = (
    "Trapani I, Colella P, Sommella A, et al. Effective delivery of large "
    "genes to the retina by dual AAV vectors. EMBO Mol Med 2014;6(2):194-211. "
    "PMID 24150896 (qualitative literature context, NOT an efficacy claim)"
)

PASS_TOKEN = "__DRYLAB_AAV_VECTOR_OPTIMIZER__"

# Authoritative pointer printed on fail-closed (g3).
_FAIL_CLOSED_MSG = (
    "FAIL-CLOSED (g3): human codon-usage table is a REQUIRED EXTERNAL INPUT "
    "and was not supplied / not schema-valid. This optimizer NEVER substitutes "
    "invented codon frequencies. Supply --codon-table pointing at a curator "
    "JSON sourced from an authoritative public database: Kazusa Codon Usage "
    "Database (Homo sapiens [gbpri], taxid 9606; Nakamura/Gojobori/Ikemura, "
    "Nucleic Acids Res 2000;28(1):292; http://www.kazusa.or.jp/codon/ "
    "showcodon.cgi?species=9606) OR HIVE-CUT / CoCoPUTs (Athey et al. BMC "
    "Bioinformatics 2017;18:391). See ../research/aav_vector_optimizer.md "
    "§codon-table-sourcing-note."
)


class CodonTableMissing(RuntimeError):
    """Raised when the required external codon-usage table is absent /
    schema-invalid. Carries the authoritative-source pointer (g3)."""


# ══════════════════════════════════════════════════════════════════════
# §B  CDS parsing / translation  (canonical genetic code only)
# ══════════════════════════════════════════════════════════════════════
def _clean_nt(seq: str) -> str:
    """Strip FASTA header(s) / whitespace; uppercase; U->T."""
    out = []
    for line in seq.splitlines():
        line = line.strip()
        if not line or line.startswith(">") or line.startswith(";"):
            continue
        out.append(line)
    s = "".join(out).upper().replace("U", "T")
    bad = set(s) - set("ACGT")
    if bad:
        raise ValueError(f"non-ACGT/U characters in CDS: {sorted(bad)}")
    return s


def parse_cds(seq: str) -> Tuple[List[str], str]:
    """Validate an in-frame CDS and translate it (canonical code).

    Returns (codons, protein) where protein includes the trailing '*'.
    Validates: divisible by 3, starts with ATG, exactly one in-frame stop
    and it is the final codon.
    """
    s = _clean_nt(seq)
    if len(s) == 0:
        raise ValueError("empty CDS")
    if len(s) % 3 != 0:
        raise ValueError(f"CDS length {len(s)} not divisible by 3")
    codons = [s[i:i + 3] for i in range(0, len(s), 3)]
    if codons[0] != "ATG":
        raise ValueError(f"CDS must start with ATG, got {codons[0]!r}")
    protein = "".join(GENETIC_CODE[c] for c in codons)
    internal_stops = protein[:-1].count("*")
    if internal_stops:
        raise ValueError(f"{internal_stops} internal in-frame stop codon(s)")
    if protein[-1] != "*":
        raise ValueError("CDS does not end with a stop codon")
    return codons, protein


def back_translate(protein: str, w_table: Dict[str, float]) -> List[str]:
    """Back-translate a one-letter AA string (no trailing '*' required;
    a trailing '*' is honored) using argmax-w synonymous choice."""
    p = protein.upper().strip()
    if not p.startswith("M"):
        raise ValueError("protein must start with M (Met)")
    if "*" not in p:
        p = p + "*"
    codons = []
    for aa in p:
        if aa not in SYNONYMS:
            raise ValueError(f"unknown amino acid {aa!r}")
        codons.append(_argmax_w_codon(aa, w_table))
    return codons


# ══════════════════════════════════════════════════════════════════════
# §C  Codon-usage table I/O  (REQUIRED external input — fail closed)
# ══════════════════════════════════════════════════════════════════════
def load_codon_table(path: Optional[str]) -> Tuple[Dict[str, float], dict]:
    """Load + schema-validate the required external codon-usage table.

    Accepted JSON schema (curator-produced; see sourcing note):
        {
          "_meta": {"source": "...", "access_date": "...", "version": "..."},
          "TTT": {"aa": "F", "count": 1234}, ... (count OR freq per codon)
        }
    Returns (f_table, meta) where f_table maps codon -> non-negative float
    (count or per-thousand frequency; only ratios within S(aa) matter).

    FAILS CLOSED (raises CodonTableMissing with the authoritative-source
    pointer) if path is None, unreadable, not JSON, or schema-invalid.
    NEVER returns a fabricated table (g3).
    """
    if not path:
        raise CodonTableMissing(_FAIL_CLOSED_MSG)
    try:
        with open(path, "r", encoding="utf-8") as fh:
            raw = json.load(fh)
    except FileNotFoundError:
        raise CodonTableMissing(_FAIL_CLOSED_MSG + f"\n  [path not found: {path}]")
    except (OSError, json.JSONDecodeError) as exc:
        raise CodonTableMissing(_FAIL_CLOSED_MSG + f"\n  [unreadable/invalid JSON: {exc}]")
    if not isinstance(raw, dict):
        raise CodonTableMissing(_FAIL_CLOSED_MSG + "\n  [top-level JSON is not an object]")
    meta = raw.get("_meta", {})
    f_table: Dict[str, float] = {}
    for codon, entry in raw.items():
        if codon == "_meta":
            continue
        cu = codon.upper().replace("U", "T")
        if cu not in GENETIC_CODE:
            raise CodonTableMissing(_FAIL_CLOSED_MSG + f"\n  [unknown codon key: {codon!r}]")
        if not isinstance(entry, dict):
            raise CodonTableMissing(_FAIL_CLOSED_MSG + f"\n  [entry for {codon!r} is not an object]")
        val = entry.get("count", entry.get("freq"))
        if not isinstance(val, (int, float)) or val < 0:
            raise CodonTableMissing(
                _FAIL_CLOSED_MSG + f"\n  [entry for {codon!r} missing non-negative count/freq]")
        f_table[cu] = float(val)
    # Require every synonymous family to have >=1 codon present, else the
    # table cannot define relative adaptiveness -> fail closed (no guessing).
    missing_families = []
    for aa, codons in SYNONYMS.items():
        if not any(c in f_table for c in codons):
            missing_families.append(aa)
    if missing_families:
        raise CodonTableMissing(
            _FAIL_CLOSED_MSG + f"\n  [table missing all codons for amino acid(s): "
            f"{sorted(missing_families)}]")
    return f_table, meta


# ══════════════════════════════════════════════════════════════════════
# §D  Relative adaptiveness w_i  +  CAI (Sharp & Li 1987, log form)
# ══════════════════════════════════════════════════════════════════════
def relative_adaptiveness(f_table: Dict[str, float]) -> Dict[str, float]:
    """w_i = f_i / max_{j in S(aa)} f_j ; floor w<1e-4 -> 0.01.

    f_table maps codon->count/freq. Codons absent from f_table get f=0
    (-> floored). Pure Sharp & Li 1987 definition.
    """
    w: Dict[str, float] = {}
    for aa, codons in SYNONYMS.items():
        fmax = max(f_table.get(c, 0.0) for c in codons)
        for c in codons:
            if fmax <= 0.0:
                wi = CAI_FLOOR
            else:
                wi = f_table.get(c, 0.0) / fmax
            if wi < CAI_FLOOR_THRESHOLD:
                wi = CAI_FLOOR
            w[c] = wi
    return w


def cai_logform(codons: List[str], w_table: Dict[str, float]) -> Tuple[float, int]:
    """CAI = exp[(1/L) Σ ln w_k], excluding Met/Trp/stop from L
    (Sharp & Li 1987; standard seqinr/EMBOSS exclusion). Returns
    (CAI, L). The numerically stable log form actually implemented."""
    ln_sum = 0.0
    L = 0
    for c in codons:
        aa = GENETIC_CODE[c]
        if aa in CAI_EXCLUDED_AA:
            continue
        wi = w_table.get(c, CAI_FLOOR)
        if wi <= 0.0:
            wi = CAI_FLOOR
        ln_sum += math.log(wi)
        L += 1
    if L == 0:
        return float("nan"), 0
    return math.exp(ln_sum / L), L


def cai_geomean(codons: List[str], w_table: Dict[str, float]) -> Tuple[float, int]:
    """CAI = (Π w_k)^(1/L) — direct geometric-mean form. Used ONLY to
    cross-check that the log form equals the geometric-mean form (the two
    are algebraically identical; the log form is implemented for numerical
    stability)."""
    prod = 1.0
    L = 0
    for c in codons:
        aa = GENETIC_CODE[c]
        if aa in CAI_EXCLUDED_AA:
            continue
        wi = w_table.get(c, CAI_FLOOR)
        if wi <= 0.0:
            wi = CAI_FLOOR
        prod *= wi
        L += 1
    if L == 0:
        return float("nan"), 0
    return prod ** (1.0 / L), L


# ══════════════════════════════════════════════════════════════════════
# §E  Deterministic CDS recoding  (argmax_w, lexicographic tie-break)
# ══════════════════════════════════════════════════════════════════════
def _argmax_w_codon(aa: str, w_table: Dict[str, float]) -> str:
    """argmax_{S(aa)} w ; ties broken by lexicographic codon order
    (SYNONYMS is pre-sorted) for byte-reproducibility."""
    best_codon = None
    best_w = -1.0
    for c in SYNONYMS[aa]:           # already lexicographically sorted
        wi = w_table.get(c, CAI_FLOOR)
        if wi > best_w:
            best_w = wi
            best_codon = c
    return best_codon


def recode_cds(codons: List[str], w_table: Dict[str, float],
                rule: str) -> List[str]:
    """Recode preserving the amino-acid sequence EXACTLY.

    rule="argmax_w": each codon -> argmax-w synonymous codon
                     (CAI-maximizing; length-invariant).
    rule="report_only": leave CDS unchanged, only score.
    """
    if rule == "report_only":
        return list(codons)
    if rule != "argmax_w":
        raise ValueError(f"unknown codon-rule {rule!r}")
    out = []
    for c in codons:
        aa = GENETIC_CODE[c]
        if aa == "*":
            out.append(c)            # preserve the exact stop codon
        else:
            out.append(_argmax_w_codon(aa, w_table))
    return out


def _translate(codons: List[str]) -> str:
    return "".join(GENETIC_CODE[c] for c in codons)


# ══════════════════════════════════════════════════════════════════════
# §F  Element accounting + headroom + dual-AAV flag
# ══════════════════════════════════════════════════════════════════════
def _inputs_hash(payload: dict) -> str:
    blob = json.dumps(payload, sort_keys=True, ensure_ascii=False).encode("utf-8")
    return hashlib.sha256(blob).hexdigest()[:16]


def optimize(
    codons: List[str],
    w_table: Dict[str, float],
    *,
    promoter: str,
    polyA: str,
    wpre: str,
    cap: int = DEFAULT_CAP_BP,
    codon_rule: str = "argmax_w",
    elements: Optional[dict] = None,
    codon_table_source: str = "(curator-supplied external table)",
) -> dict:
    """Run the deterministic sequence-budget optimization.

    Headroom is maximized by element SELECTION (caller supplies the chosen
    promoter/polyA/wpre keys from the sourced table) + length-invariant
    CAI-anchored recoding. Returns a machine-readable cassette map +
    headroom + dual-AAV flag + determinism witness row.

    NOTE (g8/f2): "fits" means ONLY that elements sum below the cited cap.
    """
    el = elements or {
        "promoters": DEFAULT_PROMOTERS, "polyA": DEFAULT_POLYA, "wpre": DEFAULT_WPRE,
    }
    if promoter not in el["promoters"]:
        raise KeyError(f"unknown promoter {promoter!r}; have {sorted(el['promoters'])}")
    if polyA not in el["polyA"]:
        raise KeyError(f"unknown polyA {polyA!r}; have {sorted(el['polyA'])}")
    if wpre not in el["wpre"]:
        raise KeyError(f"unknown wpre {wpre!r}; have {sorted(el['wpre'])}")

    recoded = recode_cds(codons, w_table, codon_rule)
    # Amino-acid sequence MUST be preserved exactly (synonymous-only).
    if _translate(recoded) != _translate(codons):
        raise AssertionError("recoding altered the amino-acid sequence (BUG)")
    if len(recoded) != len(codons):
        raise AssertionError("recoding altered codon count (BUG; must be length-invariant)")

    cai, L = cai_logform(recoded, w_table)
    cds_len = len(recoded) * 3

    prom = el["promoters"][promoter]
    pa = el["polyA"][polyA]
    wp = el["wpre"][wpre]

    cassette_map = [
        {"element": "ITR_5", "len": ITR_BP, "source": "Wu 2010 + Addgene VV-101"},
        {"element": "promoter", "key": promoter, "len": int(prom["len"]),
         "source": prom["source"]},
        {"element": "Kozak", "len": KOZAK_BP, "source": "Kozak 1987"},
        {"element": "CDS_opt", "len": cds_len,
         "cai": round(cai, 4) if cai == cai else None,
         "cai_L": L, "codon_rule": codon_rule},
    ]
    if int(wp["len"]) > 0:
        cassette_map.append(
            {"element": wpre, "len": int(wp["len"]), "source": wp["source"]})
    cassette_map.append(
        {"element": "polyA", "key": polyA, "len": int(pa["len"]),
         "source": pa["source"]})
    cassette_map.append(
        {"element": "ITR_3", "len": ITR_BP, "source": "Wu 2010 + Addgene VV-101"})

    sum_bp = sum(int(e["len"]) for e in cassette_map)
    headroom = cap - sum_bp
    fits = headroom >= 0

    result = {
        "schema": "aav_vector_optimizer_v1",
        "cassette_map": cassette_map,
        "sum_bp": sum_bp,
        "cap_bp": cap,
        "headroom_bp": headroom,
        "fits": fits,
        "dual_aav_required": not fits,
        "cai_recoded": round(cai, 6) if cai == cai else None,
        "cai_L": L,
        "codon_rule": codon_rule,
        "aa_preserved": True,
        "real_limit_citation": (
            "Wu Z, Yang H, Colosi P. Mol Ther 2010;18(1):80-86; "
            "Wang D, Tai PWL, Gao G. Nat Rev Drug Discov 2019;18:358-378"
        ),
        "cai_citation": "Sharp PM, Li WH. Nucleic Acids Res 1987;15(3):1281-1295",
        "codon_table_source": codon_table_source,
        "honesty": (
            "sequence-level budget optimizer; NOT an expression/transduction/"
            "immunogenicity/efficacy prediction (AGENTS.tape g8 / f2). 'fits' "
            "means only the chosen elements sum below the cited packaging cap."
        ),
    }
    if not fits:
        # Structural suggestion only — NOT a recombination simulation.
        mid = len(recoded) // 2
        result["dual_aav"] = {
            "strategies": DUAL_AAV_STRATEGIES,
            "citation": DUAL_AAV_CITATION,
            "structural_split_codon_index": mid,
            "structural_split_bp": mid * 3,
            "note": (
                "informational candidates + approximate midpoint split only; "
                "the optimizer does NOT simulate recombination / splicing."
            ),
        }
    result["witness"] = {
        "inputs_hash": _inputs_hash({
            "protein": _translate(codons), "promoter": promoter,
            "polyA": polyA, "wpre": wpre, "cap": cap, "codon_rule": codon_rule,
        }),
        "codon_table_source": codon_table_source,
        "element_table": "DEFAULT_v1 (sourced; see cassette_map.source)",
        "cai": result["cai_recoded"],
        "headroom_bp": headroom,
        "fits": fits,
        "dual_aav_required": not fits,
    }
    return result


# ══════════════════════════════════════════════════════════════════════
# §G  Selftest  (CAI MATH on a SYNTHETIC labeled w-vector + fail-closed)
# ══════════════════════════════════════════════════════════════════════
def _selftest() -> int:
    print("aav_vector_optimizer — drylab #3 · AAV cassette-budget optimizer\n", flush=True)
    print(f"  real-limit cap     = {DEFAULT_CAP_BP} bp (Wu 2010 / Wang 2019; NOT lattice)")
    print(f"  ITR (each, x2)     = {ITR_BP} bp (Wu 2010 + Addgene VV-101)")
    print(f"  CAI                = Sharp & Li 1987 log-form geometric mean")
    print(f"  genetic code only  = {len(GENETIC_CODE)} codons embedded; NO frequencies\n")

    ok = True

    # ── (1) SYNTHETIC test vector — explicitly labeled, NOT human freqs ──
    # This is an ARBITRARY synthetic per-codon weight set used solely to
    # exercise the CAI MATH. It is *** NOT *** a human codon-usage table
    # and does NOT claim to represent any organism's real frequencies (g3).
    SYNTHETIC_F = {  # synthetic test vector — NOT human codon frequencies
        # Phe (F): TTC favored
        "TTT": 20.0, "TTC": 80.0,
        # Leu (L): CTG favored
        "TTA": 5.0, "TTG": 10.0, "CTT": 10.0, "CTC": 15.0, "CTA": 5.0, "CTG": 55.0,
        # Lys (K): AAG favored
        "AAA": 30.0, "AAG": 70.0,
        # Gly (G): GGC favored
        "GGT": 10.0, "GGC": 60.0, "GGA": 20.0, "GGG": 10.0,
        # a deliberately tiny one to exercise the 1e-4 -> 0.01 floor:
        "ATA": 0.0,  # Ile rare member (max in family forces w(ATA) -> floor)
        "ATT": 50.0, "ATC": 50.0,  # Ile (I)
        # Met / Trp / stop (excluded from L by definition):
        "ATG": 99.0, "TGG": 99.0, "TAA": 1.0, "TAG": 1.0, "TGA": 1.0,
    }
    # Backfill every remaining codon with an arbitrary uniform synthetic
    # weight so relative_adaptiveness is fully defined for the math test
    # (still NOT a real frequency table — purely a math fixture).
    for _c in GENETIC_CODE:
        SYNTHETIC_F.setdefault(_c, 1.0)
    print('  [fixture] SYNTHETIC w-table — "synthetic test vector — NOT human '
          'codon frequencies" (g3-labeled; CAI-math only)')

    w_syn = relative_adaptiveness(SYNTHETIC_F)
    # Spot-check a known w: w(TTT)=20/80=0.25 ; w(TTC)=1.0 ; w(ATA)=floor 0.01
    assert abs(w_syn["TTC"] - 1.0) < 1e-12, w_syn["TTC"]
    assert abs(w_syn["TTT"] - 0.25) < 1e-12, w_syn["TTT"]
    assert abs(w_syn["ATA"] - CAI_FLOOR) < 1e-12, w_syn["ATA"]
    print(f"  [PASS] relative adaptiveness: w(TTC)=1.0  w(TTT)=0.25  "
          f"w(ATA)=floor {CAI_FLOOR} (Sharp&Li 1987; 1e-4->0.01 conv.)")

    # Synthetic CDS (synonymous content irrelevant to honesty — math only):
    syn_cds = "ATG" + "TTCCTGAAAGGCATCTTTCTGGGCAAG" + "TAA"
    syn_codons, syn_prot = parse_cds(syn_cds)
    cai_log, L_log = cai_logform(syn_codons, w_syn)
    cai_geo, L_geo = cai_geomean(syn_codons, w_syn)

    # ── (2) ASSERT log-form == geometric-mean form (algebraic identity) ──
    assert L_log == L_geo, (L_log, L_geo)
    assert math.isclose(cai_log, cai_geo, rel_tol=1e-12, abs_tol=1e-12), \
        f"log-form {cai_log} != geomean {cai_geo}"
    # independent hand-recompute of the geometric mean from w values:
    ws = [w_syn[c] for c in syn_codons if GENETIC_CODE[c] not in CAI_EXCLUDED_AA]
    prod = 1.0
    for x in ws:
        prod *= x
    hand_geo = prod ** (1.0 / len(ws))
    assert math.isclose(cai_log, hand_geo, rel_tol=1e-12, abs_tol=1e-12)
    print(f"  [PASS] CAI log-form == geometric-mean form  "
          f"(CAI={cai_log:.10f}, L={L_log}; |Δ|<1e-12)")

    # ── (3) Determinism — same inputs -> byte-identical output ──
    r1 = optimize(syn_codons, w_syn, promoter="cTnT_chicken", polyA="SPA",
                  wpre="WPRE3", codon_table_source="SYNTHETIC test vector (NOT human)")
    r2 = optimize(syn_codons, w_syn, promoter="cTnT_chicken", polyA="SPA",
                  wpre="WPRE3", codon_table_source="SYNTHETIC test vector (NOT human)")
    j1 = json.dumps(r1, sort_keys=True, ensure_ascii=False)
    j2 = json.dumps(r2, sort_keys=True, ensure_ascii=False)
    assert j1 == j2, "non-deterministic output"
    det_ok = j1 == j2
    print(f"  [PASS] optimizer output deterministic (byte-identical; "
          f"witness hash {r1['witness']['inputs_hash']})")

    # ── (3b) amino-acid preservation under argmax_w recoding ──
    recoded = recode_cds(syn_codons, w_syn, "argmax_w")
    aa_ok = (_translate(recoded) == _translate(syn_codons)
             and len(recoded) == len(syn_codons))
    assert aa_ok, "recoding changed the protein / length"
    print(f"  [PASS] argmax_w recoding preserves AA seq exactly + "
          f"length-invariant ({syn_prot!r})")

    # ── (4) FAIL-CLOSED — real human optimization with NO table present ──
    fail_closed_ok = False
    fc_msg = ""
    try:
        load_codon_table(None)  # request real human table; none supplied
    except CodonTableMissing as exc:
        fc_msg = str(exc)
        fail_closed_ok = (
            "FAIL-CLOSED" in fc_msg
            and "Kazusa" in fc_msg
            and "taxid 9606" in fc_msg
            and "NEVER substitutes invented" in fc_msg
        )
    assert fail_closed_ok, f"fail-closed message inadequate: {fc_msg!r}"
    # also verify a bogus path fails closed (never fabricates):
    bogus_closed = False
    try:
        load_codon_table("/tmp/__no_such_codon_table__.json")
    except CodonTableMissing:
        bogus_closed = True
    assert bogus_closed, "missing-file path did not fail closed"
    print("  [PASS] fail-closed verified: no table -> CodonTableMissing with "
          "authoritative Kazusa/taxid-9606 pointer; NEVER fabricates freqs")
    print("\n  fail-closed message (verbatim):")
    for line in fc_msg.splitlines():
        print(f"    | {line}")

    print("\n  [honesty] PASS = CAI math correct on the SYNTHETIC labeled "
          "vector + fail-closed behavior correct. It does NOT claim a real\n"
          "  human optimization happened (no real codon table is embedded; "
          "g3). Sequence-budget tool only — NOT expression/transduction/\n"
          "  efficacy prediction (g8/f2). All AAV axes UNPROVEN at the "
          "wet-lab boundary. See ../research/aav_vector_optimizer.md.")

    ok = (
        abs(w_syn["TTC"] - 1.0) < 1e-12
        and abs(w_syn["ATA"] - CAI_FLOOR) < 1e-12
        and L_log == L_geo
        and math.isclose(cai_log, cai_geo, rel_tol=1e-12, abs_tol=1e-12)
        and math.isclose(cai_log, hand_geo, rel_tol=1e-12, abs_tol=1e-12)
        and det_ok
        and aa_ok
        and fail_closed_ok
        and bogus_closed
    )
    print(f"\n{PASS_TOKEN} {'PASS' if ok else 'FAIL'}")
    return 0 if ok else 1


# ══════════════════════════════════════════════════════════════════════
# §H  CLI  (requires the external codon table — fails closed if absent)
# ══════════════════════════════════════════════════════════════════════
def _build_argparser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="AAV vector-design budget optimizer (sequence-level only; "
                    "NOT an expression/efficacy predictor — AGENTS.tape g8/f2).")
    src = p.add_mutually_exclusive_group()
    src.add_argument("--cds", help="FASTA / raw nucleotide CDS (in-frame, ATG..stop)")
    src.add_argument("--protein", help="one-letter amino-acid sequence (back-translated)")
    p.add_argument("--codon-table", help="path to REQUIRED JSON codon-usage table "
                                         "(fails closed if absent — g3)")
    p.add_argument("--promoter", default="cTnT_chicken",
                   help=f"promoter key ({sorted(DEFAULT_PROMOTERS)})")
    p.add_argument("--polyA", default="SPA",
                   help=f"polyA key ({sorted(DEFAULT_POLYA)})")
    p.add_argument("--wpre", default="WPRE3",
                   help=f"wpre key ({sorted(DEFAULT_WPRE)})")
    p.add_argument("--cap", type=int, default=DEFAULT_CAP_BP,
                   help=f"effective ssDNA payload cap (default {DEFAULT_CAP_BP}; "
                        "anchored to Wu 2010 / Wang 2019)")
    p.add_argument("--codon-rule", default="argmax_w",
                   choices=["argmax_w", "report_only"])
    p.add_argument("--selftest", action="store_true",
                   help="run the CAI-math + fail-closed selftest (no external "
                        "table required) and exit")
    return p


def main(argv: Optional[List[str]] = None) -> int:
    args = _build_argparser().parse_args(argv)
    if args.selftest or (not args.cds and not args.protein):
        return _selftest()

    # Real optimization path: REQUIRES the external sourced codon table.
    try:
        f_table, meta = load_codon_table(args.codon_table)
    except CodonTableMissing as exc:
        print(str(exc), file=sys.stderr)
        return 2

    w_table = relative_adaptiveness(f_table)
    src = meta.get("source", "(curator table; source unrecorded — record it per g3)")

    if args.cds:
        try:
            with open(args.cds, "r", encoding="utf-8") as fh:
                raw = fh.read()
        except OSError:
            raw = args.cds  # treat as a literal sequence string
        codons, _prot = parse_cds(raw)
    else:
        codons = back_translate(args.protein, w_table)

    result = optimize(
        codons, w_table,
        promoter=args.promoter, polyA=args.polyA, wpre=args.wpre,
        cap=args.cap, codon_rule=args.codon_rule, codon_table_source=src,
    )
    print(json.dumps(result, indent=2, ensure_ascii=False, sort_keys=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
