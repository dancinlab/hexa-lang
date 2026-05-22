#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
selftest/external_governance_cross_check.py — external governance
cross-reference integrity gate (hexa-bio repo).

WHY THIS EXISTS
---------------
The repo's machine-readable governance (AGENTS.tape) and the per-axis tapes
(HEXA-*.tape) cite an external dancinlab-family governance corpus through
`@X` external-citation entries — for example:

    @X x_lattice_policy := "echoes/LATTICE_POLICY.md" :: policy [...]
      url = "https://github.com/dancinlab/echoes/blob/main/LATTICE_POLICY.md"

    @X x_agents_md := "AGENTS.md (this repo)" :: doc [...]
      path = "./AGENTS.md"

    @X x_compute_portfolio := "COMPUTE_PORTFOLIO.md" :: doc [...]
      path = "./COMPUTE_PORTFOLIO.md"

These references are load-bearing — governance entries like g_inherit cite
[@x_lattice_policy], g_arch_vs_log_split cites [@x_tape_spec], and the
AGENTS.tape COEXIST hook (h1) cites [@x_agents_md] for the rationale that
AGENTS.md is retained alongside AGENTS.tape. If a path-style @X target
silently disappears from disk, the governance chain is broken even though
the .tape file still parses.

This gate closes that gap. It:

  1. Scans AGENTS.tape AND every root HEXA-*.tape for @X external-citation
     entries, extracting {entry_id, subject, kind, url-or-path} per entry.
  2. For each @X entry with a `path = "..."` body line, checks the path
     EXISTS on disk relative to the repo root (offline check).
  3. For each @X entry with a `url = "..."` body line, records the URL
     WITHOUT dereferencing it — no network access; honest SKIP per g7.
  4. Verifies the AGENTS.tape claim "AGENTS.md is RETAINED alongside
     AGENTS.tape (COEXIST pattern)" by confirming both files exist on
     disk and carry non-trivial content (a minimum byte floor).
  5. Reports a per-citation table (entry_id · subject · kind · target ·
     STATUS) and emits the sentinel:

        __EXTERNAL_GOVERNANCE_CROSS_CHECK__ PASS

     iff no path-style @X has a missing-on-disk target. URL-style @X
     entries are SKIP-not-FAIL.

GOVERNANCE (hexa-bio AGENTS.tape)
---------------------------------
  g1 real-limits-first — this gate is an honest documentation-integrity
     check; the "real limit" anchor is the filesystem itself (path either
     exists or does not). No lattice arithmetic.
  g7 skip-is-honest — URL-style @X entries are SKIP, not FAIL, because
     this gate has NO network access. A reachability check for a URL would
     require dereferencing, which this gate refuses to do. SKIP-not-FAIL
     for URLs is the honest verdict.
  g8 in-silico-only — a PASS here verifies the in-repo cross-reference
     graph is internally consistent ONLY. It is NOT a claim about the
     remote content at any cited URL.

DETERMINISM
-----------
Pure stdlib (re, os, sys). No third-party imports. No network access. No
random / wall-clock dependence. Re-running this gate on the same repo
state produces byte-identical output.

Usage:
    python3 selftest/external_governance_cross_check.py
    # exit 0 = every path-style @X target PRESENT on disk
    # exit 1 = at least one path-style @X target MISSING on disk
"""
from __future__ import annotations

import os
import re
import sys

# ── repo layout ─────────────────────────────────────────────────────────
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AGENTS_TAPE = os.path.join(REPO_ROOT, "AGENTS.tape")
AGENTS_MD = os.path.join(REPO_ROOT, "AGENTS.md")

# COEXIST floor: AGENTS.md must be at least this many bytes for the
# "non-trivial content" assertion. Anything below this would suggest an
# accidental truncation (the file alone, not a single .tape entry's worth).
COEXIST_MIN_BYTES = 1024

# verdict tokens
PRESENT = "PRESENT"
MISSING = "MISSING-PATH"
URL_SKIP = "URL-SKIP"
NEITHER = "NO-TARGET"   # @X has neither path nor url body line


# ── tape discovery ──────────────────────────────────────────────────────
def discover_tapes(repo_root):
    """Return the ordered list of tape files to scan: AGENTS.tape first,
    then every root HEXA-*.tape (excluding the .log.tape history files,
    which are append-only event histories — they may still carry @X entries
    but their architecture/declarative layer lives in HEXA-*.tape per the
    v1.2 arch-vs-log split [@D g_arch_vs_log_split]).
    """
    tapes = []
    if os.path.isfile(os.path.join(repo_root, "AGENTS.tape")):
        tapes.append(os.path.join(repo_root, "AGENTS.tape"))
    hexa = sorted(
        name for name in os.listdir(repo_root)
        if name.startswith("HEXA-")
        and name.endswith(".tape")
        and not name.endswith(".log.tape"))
    for name in hexa:
        tapes.append(os.path.join(repo_root, name))
    return tapes


# ── @X entry parser ─────────────────────────────────────────────────────
# Header form (per .tape v1.2):
#   @X <id> := "<subject>" :: <kind> [<grades>]
# Body lines are 2-space-indented; we look for `url = "..."` and
# `path = "..."` payloads.

_HEADER_RE = re.compile(
    r'^@X\s+(\S+)\s*:=\s*"([^"]*)"\s*::\s*(\S+)(?:\s+\[[^\]]*\])?\s*$')
_URL_RE = re.compile(r'^\s\s+url\s*=\s*"(.*)"\s*$')
_PATH_RE = re.compile(r'^\s\s+path\s*=\s*"(.*)"\s*$')


def parse_x_entries(tape_path):
    """Scan a .tape file for @X external-citation entries. For each one,
    pull the entry_id, subject, kind, and either a `url = "..."` or
    `path = "..."` body payload. Returns an ordered list of dicts:

        {tape, entry_id, subject, kind, url, path}

    `url` and `path` are None when not present in the body. Some @X entries
    declare a `ref = "..."` literature citation with no url/path at all;
    those round-trip with url=None, path=None and are reported NO-TARGET.
    """
    if not os.path.isfile(tape_path):
        return []
    with open(tape_path, "r", encoding="utf-8") as fh:
        lines = fh.readlines()

    found = []
    i = 0
    while i < len(lines):
        m = _HEADER_RE.match(lines[i])
        if not m:
            i += 1
            continue
        entry_id, subject, kind = m.group(1), m.group(2), m.group(3)
        # walk the 2-space-indented body until blank/non-indented.
        url_val = None
        path_val = None
        j = i + 1
        while j < len(lines):
            body = lines[j]
            if body.strip() == "" or not body.startswith("  "):
                break
            if url_val is None:
                um = _URL_RE.match(body)
                if um:
                    url_val = um.group(1)
            if path_val is None:
                pm = _PATH_RE.match(body)
                if pm:
                    path_val = pm.group(1)
            j += 1
        found.append({
            "tape": os.path.basename(tape_path),
            "entry_id": entry_id,
            "subject": subject,
            "kind": kind,
            "url": url_val,
            "path": path_val,
        })
        i = j
    return found


# ── target resolution ──────────────────────────────────────────────────
def resolve_path(repo_root, raw_path):
    """Resolve a `path = "..."` body value (e.g. './AGENTS.md',
    'AXIS/HIERARCHY.tape') to an absolute path under the repo root. Does
    not follow symlinks beyond the standard os.path.isfile semantics.
    """
    rel = raw_path.lstrip("./")
    return os.path.join(repo_root, rel)


def classify(repo_root, entry):
    """Map a parsed @X entry to (status, target_display).

    PRESENT     — path-style entry, target file exists on disk.
    MISSING-PATH— path-style entry, target file is absent.
    URL-SKIP    — URL-style entry; not dereferenced (g7 honest SKIP).
    NO-TARGET   — entry has neither path nor url (e.g. literature ref text
                  only). Counted in the table but does NOT block the
                  sentinel — many literature @X entries in HEXA-*.tape are
                  bibliographic and intentionally carry no resolvable
                  target; treating them as FAIL would be dishonest.
    """
    if entry["path"]:
        target = entry["path"]
        abs_target = resolve_path(repo_root, target)
        if os.path.exists(abs_target):
            return PRESENT, target
        return MISSING, target
    if entry["url"]:
        return URL_SKIP, entry["url"]
    return NEITHER, "(literature ref only — no url/path body)"


# ── COEXIST verification ───────────────────────────────────────────────
def verify_coexist():
    """Verify the AGENTS.tape claim that AGENTS.md is RETAINED alongside
    AGENTS.tape (COEXIST pattern, hook h1). Returns (ok, detail).

    The .tape SSOT and the .md SSOT must BOTH exist and BOTH carry
    non-trivial content (>= COEXIST_MIN_BYTES). If either is absent or
    truncated below the floor, the COEXIST contract is broken.
    """
    if not os.path.isfile(AGENTS_TAPE):
        return False, "AGENTS.tape missing on disk"
    if not os.path.isfile(AGENTS_MD):
        return False, "AGENTS.md missing on disk"
    tape_sz = os.path.getsize(AGENTS_TAPE)
    md_sz = os.path.getsize(AGENTS_MD)
    if tape_sz < COEXIST_MIN_BYTES:
        return False, (f"AGENTS.tape size {tape_sz} B below COEXIST floor "
                       f"{COEXIST_MIN_BYTES} B (truncation?)")
    if md_sz < COEXIST_MIN_BYTES:
        return False, (f"AGENTS.md size {md_sz} B below COEXIST floor "
                       f"{COEXIST_MIN_BYTES} B (truncation?)")
    return True, (f"AGENTS.tape={tape_sz} B, AGENTS.md={md_sz} B "
                  f"(both >= {COEXIST_MIN_BYTES} B floor)")


# ── reporting ──────────────────────────────────────────────────────────
def _shorten(s, width):
    if s is None:
        return ""
    s = str(s)
    return s if len(s) <= width else s[:width - 1] + "…"


def render_table(rows):
    """Render the per-citation table. Deterministic column widths."""
    # column widths
    w_tape = max([len("tape")] + [len(r["tape"]) for r in rows]) + 0
    w_id = max([len("entry_id")] + [len(r["entry_id"]) for r in rows]) + 0
    w_kind = max([len("kind")] + [len(r["kind"]) for r in rows]) + 0
    w_status = max([len("status")] + [len(r["status"]) for r in rows]) + 0
    # clamp tape column to a reasonable width
    w_tape = min(w_tape, 28)
    w_id = min(w_id, 32)
    w_kind = min(w_kind, 18)
    target_w = 60

    header = (f"  {'tape':<{w_tape}}  {'entry_id':<{w_id}}  "
              f"{'kind':<{w_kind}}  {'status':<{w_status}}  target")
    rule = ("  " + "-" * w_tape + "  " + "-" * w_id + "  "
            + "-" * w_kind + "  " + "-" * w_status + "  " + "-" * 12)
    print(header)
    print(rule)
    for r in rows:
        print(f"  {_shorten(r['tape'], w_tape):<{w_tape}}  "
              f"{_shorten(r['entry_id'], w_id):<{w_id}}  "
              f"{_shorten(r['kind'], w_kind):<{w_kind}}  "
              f"{r['status']:<{w_status}}  "
              f"{_shorten(r['target'], target_w)}")


# ── main ───────────────────────────────────────────────────────────────
def main():
    print("external_governance_cross_check — hexa-bio @X external-citation "
          "integrity gate")
    print("  scans AGENTS.tape + every root HEXA-*.tape for @X entries,")
    print("  classifies each as PRESENT / MISSING-PATH / URL-SKIP / NO-TARGET,")
    print("  verifies the AGENTS.tape↔AGENTS.md COEXIST contract.")
    print("  governance: g1 real-limits-first · g7 skip-is-honest (URLs not")
    print("              dereferenced — no network) · g8 in-silico-only\n")

    tapes = discover_tapes(REPO_ROOT)
    print(f"  scanning {len(tapes)} tape file(s):")
    for t in tapes:
        print(f"    · {os.path.basename(t)}")
    print()

    all_entries = []
    for t in tapes:
        all_entries.extend(parse_x_entries(t))

    if not all_entries:
        print("  [SKIP] no @X external-citation entries found in any "
              "scanned tape")
        print()
        coexist_ok, coexist_detail = verify_coexist()
        print(f"  COEXIST check: {'OK' if coexist_ok else 'BROKEN'} — "
              f"{coexist_detail}\n")
        if coexist_ok:
            print("__EXTERNAL_GOVERNANCE_CROSS_CHECK__ PASS")
            return 0
        print("__EXTERNAL_GOVERNANCE_CROSS_CHECK__ FAIL")
        return 1

    # classify
    rows = []
    for e in all_entries:
        status, target = classify(REPO_ROOT, e)
        rows.append({
            "tape": e["tape"],
            "entry_id": e["entry_id"],
            "subject": e["subject"],
            "kind": e["kind"],
            "status": status,
            "target": target,
        })

    # tally
    n_present = sum(1 for r in rows if r["status"] == PRESENT)
    n_missing = sum(1 for r in rows if r["status"] == MISSING)
    n_url_skip = sum(1 for r in rows if r["status"] == URL_SKIP)
    n_neither = sum(1 for r in rows if r["status"] == NEITHER)
    n_total = len(rows)

    # ── per-citation table ─────────────────────────────────────────────
    print(f"── per-citation table ({n_total} @X entries) "
          + "─" * max(1, 40 - len(str(n_total))))
    render_table(rows)
    print()

    # ── missing-path detail ────────────────────────────────────────────
    if n_missing:
        print("── MISSING-PATH details " + "─" * 50)
        for r in rows:
            if r["status"] == MISSING:
                print(f"  [{r['tape']}] {r['entry_id']}  ({r['subject']})")
                print(f"      declared path: {r['target']}")
                print(f"      resolved abs : "
                      f"{resolve_path(REPO_ROOT, r['target'])}")
                print("      verdict      : file not found on disk")
        print()

    # ── COEXIST contract ───────────────────────────────────────────────
    coexist_ok, coexist_detail = verify_coexist()
    print("── COEXIST contract " + "─" * 55)
    print(f"  AGENTS.tape ↔ AGENTS.md COEXIST pattern (hook h1):")
    print(f"    {'OK' if coexist_ok else 'BROKEN'} — {coexist_detail}")
    print()

    # ── summary ────────────────────────────────────────────────────────
    print("── summary " + "─" * 60)
    print(f"  {n_present} PRESENT · {n_missing} MISSING-PATH · "
          f"{n_url_skip} URL-SKIP · {n_neither} NO-TARGET "
          f"(of {n_total} @X rows)")
    print("  HONESTY (g7): URL-SKIP is HONEST — this gate has no network")
    print("  access, so URLs are recorded but not dereferenced. Treating an")
    print("  un-dereferenced URL as FAIL would be dishonest.")
    print("  HONESTY: NO-TARGET (e.g. a literature `ref = \"...\"` entry with")
    print("  no path/url body) does NOT block the sentinel — those are")
    print("  bibliographic citations, not file/URL references.")
    print("  HONESTY (g8): a PASS verifies the in-repo cross-reference graph")
    print("  ONLY — it is NOT a claim about the remote content at any URL.\n")

    # ── sentinel: PASS iff no path-style @X is MISSING on disk AND
    # the AGENTS.tape↔AGENTS.md COEXIST contract holds. ────────────────
    ok = (n_missing == 0) and coexist_ok
    if ok:
        print("__EXTERNAL_GOVERNANCE_CROSS_CHECK__ PASS")
        return 0
    print("__EXTERNAL_GOVERNANCE_CROSS_CHECK__ FAIL")
    return 1


if __name__ == "__main__":
    sys.exit(main())
