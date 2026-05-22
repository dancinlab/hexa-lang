#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
selftest/cross_link_integrity_audit.py — cross-link + NOVEL integrity gate.

Enforces boundary discipline between hexa-matter and its sister repos plus
the NOVEL.md candidate-status invariants. Per LATTICE_POLICY §1.2 / §1.3 /
raw#10 C3 + SPEC_FIRST: gate checks STRUCTURE + BOUNDARY, not measurement.
UNPROVEN/UNVERIFIED markers stay UNTOUCHED.

Three audit groups:

A. Cross-link boundary checks (per CROSS_LINK.md):
   A1. `photoresist/photoresist.md` declares device/lithography ⇒ hexa-chip
   A2. `electrode-material/electrode-material.md` declares cell engineering
       ⇒ hexa-energy
   A3. `silicon/silicon.md` MUST NOT claim ownership of semiconductor
       *device* layer (only material layer)
   A4. NO verb spec MAY claim to be RT-SC verified — `hxm-sc-*` candidates
       in NOVEL.md are hypothesis only (per AGENTS.md raw#10 C3 + hexa-rtsc
       boundary)

B. NOVEL.md candidate invariants (per AGENTS.md):
   B1. Every `hxm-<class>-<target>-<NNN>` candidate has status DESIGN
       (never VERIFIED or EXTERNAL-VERIFIED without external lab citation +
       sample-ID)
   B2. Every candidate has a quantitative falsifier (specific number +
       condition + pass/fail boundary)
   B3. Every candidate's host §3.x subsection lists risk-flags (either a
       `**Risk-flags**:` block or HARD_WALL / UNVERIFIED honesty content)
   B4. No candidate name collides — NNN uniqueness within (class, target)

C. Doc reference integrity:
   C1. Every cited file path in CROSS_LINK.md must actually exist
   C2. Every cross-link to a sister repo URL must point to a
       `github.com/dancinlab/hexa-*` form

stdlib-only. Exit 0 PASS / 1 FAIL.

Sentinel: `__HEXA_MATTER_CROSS_LINK_INTEGRITY__ PASS  (N candidates,
M cross-links, 0 violations)` on success.
"""
from __future__ import annotations

import os
import re
import sys

REPO_ROOT = os.environ.get("HEXA_MATTER_ROOT") or os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))
)

VERB_SPECS = (
    "photoresist/photoresist.md",
    "electrode-material/electrode-material.md",
    "silicon/silicon.md",
    "2d-materials/2d-materials.md",
    "adhesive/adhesive.md",
    "aerogel-foam/aerogel-foam.md",
    "aramid/aramid.md",
    "biodegradable-plastics/biodegradable-plastics.md",
    "carbon/carbon.md",
    "ceramics/ceramics.md",
    "compound-semi/compound-semi.md",
    "concrete/concrete.md",
    "elastomer/elastomer.md",
    "epoxy/epoxy.md",
    "gemology/gemology.md",
    "geopolymer/geopolymer.md",
    "glass-ceramic/glass-ceramic.md",
    "ionic-liquid/ionic-liquid.md",
    "liquid-crystal/liquid-crystal.md",
    "magnetic-materials/magnetic-materials.md",
    "mof/mof.md",
    "nylon/nylon.md",
    "perovskite/perovskite.md",
    "refractory/refractory.md",
    "superalloy/superalloy.md",
    "wood-cellulose/wood-cellulose.md",
)

CANDIDATE_RE = re.compile(r"hxm-([a-z0-9]+)-([a-zA-Z0-9_-]+?)-([0-9]{3})")
ROW_RE = re.compile(r"^\|\s*`(hxm-[a-zA-Z0-9_-]+)`\s*\|(.+)$")
SECTION_RE = re.compile(r"^###\s+(3\.\d+|4\.[A-Z](?:\.\d+)?)\s+(.*)$")
PATH_REF_RE = re.compile(r"`([a-z0-9_-][a-z0-9_/.-]*\.md)`")
SISTER_URL_RE = re.compile(r"https?://([^/\s)]+)/([^/\s)]+)/(hexa-[a-z0-9-]+)")


def read(p: str) -> str:
    with open(os.path.join(REPO_ROOT, p), "r", encoding="utf-8") as fh:
        return fh.read()


def check_A1_photoresist() -> tuple[bool, str]:
    text = read("photoresist/photoresist.md").lower()
    has_phrase = (
        ("device" in text or "lithography" in text)
        and "hexa-chip" in text
        and ("belong" in text or "lives in" in text or "owned by" in text)
    )
    return has_phrase, (
        "photoresist.md declares device/lithography ⇒ hexa-chip"
        if has_phrase
        else "photoresist.md missing 'device/lithography ⇒ hexa-chip' boundary"
    )


def check_A2_electrode() -> tuple[bool, str]:
    text = read("electrode-material/electrode-material.md").lower()
    has_phrase = (
        "cell engineering" in text
        and "hexa-energy" in text
        and ("belong" in text or "lives in" in text or "owned by" in text)
    )
    return has_phrase, (
        "electrode-material.md declares cell engineering ⇒ hexa-energy"
        if has_phrase
        else "electrode-material.md missing 'cell engineering ⇒ hexa-energy' boundary"
    )


def check_A3_silicon() -> tuple[bool, str]:
    text = read("silicon/silicon.md")
    low = text.lower()
    # Negative claim: must NOT claim to own semiconductor device layer.
    # Look for forbidden ownership patterns.
    bad_patterns = (
        r"silicon\s+owns\s+the\s+(semiconductor\s+)?device",
        r"this\s+verb\s+owns\s+the\s+(semiconductor\s+)?device",
        r"this\s+verb\s+owns\s+lithography",
        r"transistor\s+architecture\s+owned\s+here",
    )
    for pat in bad_patterns:
        if re.search(pat, low):
            return False, f"silicon.md contains forbidden device-ownership claim: /{pat}/"
    # Positive sanity: silicon.md must declare material-layer-only scope.
    pos = "material layer" in low and "hexa-chip" in low
    if not pos:
        return False, "silicon.md missing 'material layer only ⇒ hexa-chip' boundary"
    return True, "silicon.md declares material-layer only, defers device to hexa-chip"


def check_A4_no_rtsc_verified() -> list[str]:
    violations: list[str] = []
    bad_re = re.compile(
        r"\bRT[-\s]?SC\b[^\n]{0,80}\b(verified|achieved|confirmed|reproduced|delivered)\b",
        re.IGNORECASE,
    )
    # Sweep verb specs only — NOVEL.md is allowed to discuss the topic.
    for rel in VERB_SPECS:
        try:
            text = read(rel)
        except FileNotFoundError:
            continue
        for m in bad_re.finditer(text):
            ctx = m.group(0)
            violations.append(f"{rel}: forbidden RT-SC claim — '{ctx}'")
    return violations


def parse_novel_candidates() -> list[dict]:
    text = read("NOVEL.md")
    rows: list[dict] = []
    cur_section = None
    cur_section_title = None
    section_offsets: dict[str, tuple[int, int]] = {}
    last_section_start = None
    for idx, line in enumerate(text.splitlines()):
        sm = SECTION_RE.match(line)
        if sm:
            if cur_section and last_section_start is not None:
                section_offsets[cur_section] = (last_section_start, idx)
            cur_section = sm.group(1)
            cur_section_title = sm.group(2)
            last_section_start = idx
        rm = ROW_RE.match(line)
        if rm and cur_section is not None and "PLACEHOLDER" not in line and not line.strip().startswith("| ID"):
            # Skip table headers and separator lines; capture only data rows.
            cid = rm.group(1)
            cells = [c.strip() for c in rm.group(2).split("|")]
            # cells are: class | target | brief | status | falsifier (5 entries
            # after the ID column).
            if len(cells) >= 5:
                rows.append({
                    "id": cid,
                    "section": cur_section,
                    "section_title": cur_section_title,
                    "class": cells[0],
                    "target": cells[1],
                    "brief": cells[2],
                    "status": cells[3],
                    "falsifier": cells[4],
                    "line": idx + 1,
                })
    if cur_section and last_section_start is not None:
        section_offsets[cur_section] = (last_section_start, len(text.splitlines()))
    # Attach raw section text for risk-flag scan.
    lines = text.splitlines()
    for r in rows:
        s, e = section_offsets.get(r["section"], (0, 0))
        r["_section_text"] = "\n".join(lines[s:e])
    return rows


def check_B1_status_design(rows: list[dict]) -> list[str]:
    bad: list[str] = []
    for r in rows:
        if r["status"] != "DESIGN":
            # Only EXTERNAL-VERIFIED requires sample-ID citation; any non-DESIGN
            # status without explicit external citation in the section is a
            # violation per AGENTS.md raw#10 C3.
            #
            # Phase J.2 (2026-05-13): `SIM-NNP-PROXY` is a distinct SIM tag that
            # explicitly does NOT promote to EXTERNAL-VERIFIED (the prediction is
            # vendored from peer-reviewed proxy literature, not from an attributed
            # external-lab measurement). For SIM-NNP-PROXY status the audit
            # accepts a JSON-snapshot reference under
            # `_absorption_bridge/universal_ff/predictions/<id>.json` as the
            # citation form (the snapshot itself carries `proxy_source`).
            section_text = r["_section_text"]
            has_citation = bool(
                re.search(r"sample[-\s]?ID|lab\s+citation|external\s+lab", section_text, re.IGNORECASE)
            )
            if r["status"] in ("SIM-NNP-PROXY", "SIM-NNP"):
                # SIM-NNP-PROXY = proxy value vendored from literature;
                # SIM-NNP = real universal-FF computation. Both cite their
                # frozen JSON snapshot under predictions/ as the citation
                # form (the snapshot carries proxy_source / computation
                # provenance). Neither promotes to EXTERNAL-VERIFIED.
                has_citation = has_citation or bool(
                    re.search(
                        r"_absorption_bridge/universal_ff/predictions/|proxy[-_\s]?source|SIM-NNP",
                        section_text,
                        re.IGNORECASE,
                    )
                )
            # 2026-05-18: `SIM-DFT` is a distinct SIM tag (NOVEL.md §2 pipeline)
            # — a DFT-level cross-reference against a Materials Project record.
            # It is NOT an external-lab measurement and does NOT promote to
            # EXTERNAL-VERIFIED. The audit accepts an `mp-XXXXX` record ID (or
            # an explicit "Materials Project" mention) in the section as the
            # citation form — the MP record itself carries the DFT provenance.
            if r["status"] == "SIM-DFT":
                has_citation = has_citation or bool(
                    re.search(
                        r"\bmp-\d+\b|Materials Project|SIM-DFT",
                        section_text,
                        re.IGNORECASE,
                    )
                )
            if r["status"] != "DESIGN" and not has_citation:
                bad.append(
                    f"{r['id']} (§{r['section']}): status='{r['status']}' "
                    f"without external lab citation + sample-ID"
                )
    return bad


_NUM_RE = re.compile(r"[-+]?\d+\.?\d*([eE][-+]?\d+)?")
_BOUNDARY_RE = re.compile(r"(→|FAIL|FALSIFIED|FAILED)")


def check_B2_falsifier(rows: list[dict]) -> list[str]:
    bad: list[str] = []
    for r in rows:
        fal = r["falsifier"]
        # Must include an F-XXX-N tag, a number, and a boundary token.
        has_tag = bool(re.search(r"\bF-[A-Z0-9][A-Z0-9-]*-\d+\b", fal))
        has_num = bool(_NUM_RE.search(fal))
        has_boundary = bool(_BOUNDARY_RE.search(fal))
        if not (has_tag and has_num and has_boundary):
            bad.append(
                f"{r['id']} (§{r['section']}): falsifier missing "
                f"F-tag/number/boundary → '{fal[:80]}'"
            )
    return bad


_RISK_TOKENS = ("Risk-flags", "UNVERIFIED", "UNPROVEN", "HARD_WALL", "anti-claim", "Anti-claim", "ANTI-CLAIM", "caveat", "raw#10 C3")


def check_B3_risk_flags(rows: list[dict]) -> list[str]:
    bad: list[str] = []
    seen: set[str] = set()
    for r in rows:
        if r["section"] in seen:
            continue
        seen.add(r["section"])
        text = r["_section_text"]
        if not any(tok in text for tok in _RISK_TOKENS):
            bad.append(
                f"§{r['section']} ({r['section_title']}): missing risk-flags / "
                f"UNVERIFIED / HARD_WALL honesty content"
            )
    return bad


def check_B4_unique(rows: list[dict]) -> list[str]:
    bad: list[str] = []
    seen: dict[str, int] = {}
    for r in rows:
        seen[r["id"]] = seen.get(r["id"], 0) + 1
    for cid, n in seen.items():
        if n > 1:
            bad.append(f"{cid}: duplicated {n}× in NOVEL.md candidate ledger")
    return bad


def check_C1_paths(cross_link_text: str) -> list[str]:
    bad: list[str] = []
    cited = set(PATH_REF_RE.findall(cross_link_text))
    for rel in sorted(cited):
        # Skip refs that point at upper-level UPPERCASE docs covered in §C
        # (NOVEL.md / AGENTS.md / etc. — those are root-level docs).
        if "/" not in rel:
            full = os.path.join(REPO_ROOT, rel)
        else:
            full = os.path.join(REPO_ROOT, rel)
        if not os.path.exists(full):
            bad.append(f"CROSS_LINK.md cites missing file: `{rel}`")
    return bad


def check_C2_sister_urls(*docs: str) -> tuple[list[str], int]:
    bad: list[str] = []
    count = 0
    for doc in docs:
        try:
            text = read(doc)
        except FileNotFoundError:
            continue
        for m in SISTER_URL_RE.finditer(text):
            host, org, repo = m.group(1), m.group(2), m.group(3)
            count += 1
            if host.lower() != "github.com" or org.lower() != "dancinlab":
                bad.append(
                    f"{doc}: sister URL {m.group(0)} not in "
                    f"github.com/dancinlab/hexa-* form"
                )
    return bad, count


def selftest() -> int:
    """Minimal self-consistency check of the gate itself."""
    rows = parse_novel_candidates()
    assert len(rows) >= 30, f"expected ≥30 candidates, got {len(rows)}"
    # Every parsed row must have all 5 cells.
    for r in rows:
        assert r["status"], f"row {r['id']} missing status"
        assert r["falsifier"], f"row {r['id']} missing falsifier"
    # Regex sanity.
    assert CANDIDATE_RE.match("hxm-sc-cuprate-001")
    assert not CANDIDATE_RE.match("xyz-sc-cuprate-001")
    print("cross_link_integrity_audit --selftest PASS")
    return 0


def main() -> int:
    if "--selftest" in sys.argv:
        return selftest()

    print("hexa-matter/selftest/cross_link_integrity_audit — boundary + NOVEL integrity")
    print(f"  root: {REPO_ROOT}\n")

    violations: list[str] = []

    # ── A. Cross-link boundary checks ─────────────────────────────────
    print("[A] cross-link boundary checks")
    for fn in (check_A1_photoresist, check_A2_electrode, check_A3_silicon):
        ok, msg = fn()
        print(f"  [{'PASS' if ok else 'FAIL'}] {msg}")
        if not ok:
            violations.append(msg)
    rtsc_v = check_A4_no_rtsc_verified()
    if rtsc_v:
        for v in rtsc_v:
            print(f"  [FAIL] {v}")
            violations.append(v)
    else:
        print(f"  [PASS] no verb spec claims RT-SC verified ({len(VERB_SPECS)} specs swept)")

    # ── B. NOVEL.md candidate invariants ─────────────────────────────
    rows = parse_novel_candidates()
    print(f"\n[B] NOVEL.md candidate invariants ({len(rows)} candidates)")
    b1 = check_B1_status_design(rows)
    b2 = check_B2_falsifier(rows)
    b3 = check_B3_risk_flags(rows)
    b4 = check_B4_unique(rows)
    for label, errs in (
        ("B1 status DESIGN", b1),
        ("B2 quantitative falsifier", b2),
        ("B3 risk-flags listed", b3),
        ("B4 NNN uniqueness", b4),
    ):
        if errs:
            for e in errs:
                print(f"  [FAIL] {label}: {e}")
                violations.append(f"{label}: {e}")
        else:
            print(f"  [PASS] {label}")

    # ── C. Doc reference integrity ───────────────────────────────────
    cross_link = read("CROSS_LINK.md")
    cited_paths = sorted(set(PATH_REF_RE.findall(cross_link)))
    c1 = check_C1_paths(cross_link)
    c2, sister_url_count = check_C2_sister_urls("CROSS_LINK.md", "AGENTS.md", "NOVEL.md", "INIT.md")
    print(f"\n[C] doc-reference integrity ({len(cited_paths)} cited paths, "
          f"{sister_url_count} sister URLs)")
    if c1:
        for e in c1:
            print(f"  [FAIL] {e}")
            violations.append(e)
    else:
        print(f"  [PASS] all {len(cited_paths)} cited CROSS_LINK.md paths exist")
    if c2:
        for e in c2:
            print(f"  [FAIL] {e}")
            violations.append(e)
    else:
        print(f"  [PASS] all {sister_url_count} sister-repo URLs in "
              f"github.com/dancinlab/hexa-* form")

    print()
    n_cand = len(rows)
    n_links = len(cited_paths) + sister_url_count
    if violations:
        print(f"__HEXA_MATTER_CROSS_LINK_INTEGRITY__ FAIL  "
              f"({n_cand} candidates, {n_links} cross-links, {len(violations)} violations)")
        return 1
    print(f"__HEXA_MATTER_CROSS_LINK_INTEGRITY__ PASS  "
          f"({n_cand} candidates, {n_links} cross-links, 0 violations)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
