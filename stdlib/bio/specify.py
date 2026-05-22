#!/usr/bin/env python3
# specify.py — `bio + specify` per-verb argv shim (thin in-silico ·
# D72 adapter-only · D106 illustrative-physics · D116 substrate SSOT
# under stdlib/bio/).
#
# CONTEXT: bio substrate is AXIS-organized (24 axes: 5 core + 4
# expansion-main + 15 sub) under stdlib/bio/bio.hexa root dispatcher.
# bio.demi [cell.specify] currently wires substrate=hexa →
# stdlib/bio/bio.hexa (the axis status surface). This per-verb argv
# shim is the FOLLOW-UP path flagged in bio.demi: a thin Python
# forwarder under stdlib/bio/<verb>.py that emits a bio_specify_record
# envelope honestly (illustrative target spec, NO wet-lab claim).
#
# What this shim emits (per bio.md §2 SPECIFY row):
#   - gene of interest (FASTA placeholder · UniProt id placeholder)
#   - clinical indication (placeholder if drug)
#   - target spec scaffold a real (future) AlphaFold 3 / ESMFold /
#     Boltz-1 design pipeline consumes downstream
#
# Honesty (g3 · D106 · project.tape @D d1 · bio.demi line 87):
#   - measurement_gate = GATE_OPEN permanently
#   - absorbed = false PERMANENTLY (D106 illustrative-physics ·
#     RFC 013 §6.12 anti-conflation · g3) — a target spec is
#     aspiration, NEVER a measured wet-lab oracle
#   - producer = "bio_specify@template" (NOT a wet-lab pipeline pin)
#   - scope_caveats cite bio.md §2 + wet-lab boundary (@D d1)
#
# Pattern: mirrors stdlib/firmware/specify.py + stdlib/sscb/specify.py
# D113 sibling-meta convention. Does NOT subprocess bio.hexa (avoid
# double-emit · bio.hexa axis surface is a different mode).

from __future__ import annotations

import json
import platform
import sys
import time
from pathlib import Path

GEOMETRY_ID = "bio_specify_v1"


def _build_target_spec_template() -> dict:
    """Bio target spec scaffold — gene + protein + indication + tool
    chain placeholder. Real values come from upstream (research
    triage · target validation literature · clinical priority) and
    feed downstream verbs.
    """
    return {
        "target": {
            "gene_symbol": None,        # e.g. "TP53"
            "uniprot_id": None,          # e.g. "P04637"
            "organism": "Homo sapiens",
            "fasta_path": None,           # placeholder for downstream
        },
        "modality_class": None,         # protein | mAb | small_mol | aptamer | etc.
        "indication": {
            "disease": None,
            "icd11_code": None,
            "patient_population_estimate": None,
        },
        "tool_chain_candidates": [
            "AlphaFold 3 (structure prediction)",
            "ESMFold (structure prediction · single-sequence)",
            "Boltz-1 (open structure prediction)",
            "RFdiffusion (de-novo binder design)",
            "ProteinMPNN (sequence design from backbone)",
        ],
        "notes": (
            "Target spec scaffold — IN-SILICO metadata only. "
            "Real target validation requires literature evidence + "
            "clinical priority review which lives upstream of this "
            "shim. Wet-lab confirmation (Kd · expression · in-vivo "
            "PK/PD) lives past @D d1's legitimate not-yet boundary."
        ),
    }


def main(out_dir: str) -> int:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    produced_at_utc = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

    spec = _build_target_spec_template()
    measurements: dict = {}

    citations = [
        "domains/bio.md §2 SPECIFY row — demiurge SSOT.",
        "AlphaFold 3 — Abramson et al. Nature 630, 493 (2024).",
        "ESMFold — Lin et al. Science 379, 1123 (2023).",
        "Boltz-1 — arXiv:2411.16107.",
        "UniProt (uniprot.org) — open protein sequence + annotation db.",
    ]
    scope_caveats = [
        "bio + specify is an ILLUSTRATIVE TEMPLATE emit "
        "(D106 illustrative-physics · RFC 013 §6.12 anti-conflation "
        "· g3) — target spec scaffold (gene · UniProt · indication "
        "· tool-chain placeholders) with NO wet-lab claim of any "
        "kind. NOT a binding affinity · NOT an expression-yield · "
        "NOT a therapeutic / immunogenic / efficacy / regulatory "
        "claim.",
        "absorbed = false UNREACHABLE in software (g3 · D106) — a "
        "target spec is aspiration; absorbed=true requires a "
        "measured wet-lab oracle (binding Kd · expression yield · "
        "in-vivo PK · assay readout) which lives past project.tape "
        "@D d1's legitimate not-yet wet-lab boundary.",
        "producer = bio_specify@template — adapter-only emit (D72). "
        "Per-verb argv shim implementing the FOLLOW-UP flagged in "
        "bio.demi line 86; substrate is axis-organized (24 axes "
        "under stdlib/bio/bio.hexa root dispatcher).",
        "No MeasuredOracleRef attaches to this illustrative-physics "
        "cell (D6 / D106 carve-out · cockpit invariant — illustrative "
        "cells MUST NOT carry a measurement oracle).",
        "wet-lab cells (synthesize · verify · handoff) stay honest-"
        "skip per project.tape @D d1.",
    ]

    meta = {
        "ok": True,
        "geometry_id": GEOMETRY_ID,
        "produced_at_utc": produced_at_utc,
        "python_version": platform.python_version(),
        "gate_type": "hexa-native-absent",
        "provisional": True,
        "measurements": measurements,
        "spec": spec,
        "artifacts": {
            "spec": f"{GEOMETRY_ID}.spec.json",
        },
    }
    meta_path = out / f"{GEOMETRY_ID}.meta.json"
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2, sort_keys=True)
        f.write("\n")

    spec_path = out / f"{GEOMETRY_ID}.spec.json"
    with open(spec_path, "w", encoding="utf-8") as f:
        json.dump(spec, f, indent=2, sort_keys=True)
        f.write("\n")

    record = {
        "domain": "bio",
        "verb": "specify",
        "kind": "bio_specify_record",
        "stamp": stamp,
        "producer": "bio_specify@template",
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,
        "scope_caveats": scope_caveats,
        "citations": citations,
        "skipped_reason": None,
        "gate_type": "hexa-native-absent",
        "provisional": True,
        "spec": spec,
        "artifacts": {
            "meta": meta_path.name,
            "spec": spec_path.name,
        },
    }
    rec_path = out / f"bio_specify_{stamp}.json"
    with open(rec_path, "w", encoding="utf-8") as f:
        json.dump(record, f, indent=2, sort_keys=True)
        f.write("\n")

    summary = {
        "ok": True,
        "geometry_id": GEOMETRY_ID,
        "gate_type": "hexa-native-absent",
        "provisional": True,
        "modality_class": spec["modality_class"],
        "tool_chain_count": len(spec["tool_chain_candidates"]),
        "artifacts": {
            "record": rec_path.name,
            "meta": meta_path.name,
            "spec": spec_path.name,
        },
    }
    sys.stderr.write("BIO_SPECIFY_RESULT "
                     + json.dumps(summary, sort_keys=True) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/bio_specify"))
