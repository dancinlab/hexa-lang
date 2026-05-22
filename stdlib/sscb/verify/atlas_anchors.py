#!/usr/bin/env python3
"""
hexa-sscb verify/atlas_anchors.py — atlas.n6 + atlas.append.* 파서.

circular-trap-free (non-traceable verification 차단) 검증 surface 의 입력 anchor
단일 진입점. nexus check 패턴 (target + formula + input values 가 서로 다른 외부
소스) 의 입력 측을 atlas anchor 에서 직접 lookup. canonical 명명: nexus calc/
alm_verify cross_prover diagonal 과 동일 가족.

Sources (read-only, parse-only):
    ~/core/canon/atlas/atlas.n6                                   본체
    ~/core/canon/atlas/atlas.append.engineering-content-mk-next-2026-05-06.n6
    ~/core/canon/atlas/atlas.append.hsscb-mk1-vendor-anchors-2026-05-06.n6

Exposes:
    load_anchors() -> dict[id -> Entry]   모든 @P/@C/@L 항목
    lookup(id) -> Entry                    단일 항목 lookup
    Entry.value (Decimal/int/str), .unit, .anchor, .cite, .domain, .grade

stdlib only (project convention).
"""
from __future__ import annotations

import os
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

# Atlas resolution order:
#   1. HSSCB_ATLAS_DIR env var (CI override / debug)
#   2. verify/atlas/ co-located with this file (repo-local, default — see verify/atlas/README.md)
#   3. ~/core/canon/atlas/ (legacy fallback; only used if the first two miss)
_REPO_LOCAL_ATLAS = Path(__file__).resolve().parent / "atlas"
_LEGACY_CANON_ATLAS = Path.home() / "core" / "canon" / "atlas"

_env_dir = os.environ.get("HSSCB_ATLAS_DIR")
if _env_dir:
    ATLAS_DIR = Path(_env_dir)
elif _REPO_LOCAL_ATLAS.exists():
    ATLAS_DIR = _REPO_LOCAL_ATLAS
else:
    ATLAS_DIR = _LEGACY_CANON_ATLAS

ATLAS_FILES = [
    "atlas.n6",
    "atlas.append.engineering-content-mk-next-2026-05-06.n6",
    "atlas.append.hsscb-mk1-vendor-anchors-2026-05-06.n6",
    "atlas.append.hsscb-mk1-spec-derived-2026-05-07.n6",
]


@dataclass
class Entry:
    type: str               # "@P" / "@C" / "@L" / ...
    id: str                 # entry id (left of `=`)
    expr: str               # raw expression (right of `=`, before `::`)
    domain: str             # after `::`
    grade: str              # bracket suffix, e.g. "[10*]"
    value: object = None    # parsed numeric (Decimal/float/int) or None
    unit: str = ""          # axis-M unit= field
    anchor: str = ""        # axis-M anchor= field (doc/sec/vintage)
    cite: str = ""          # axis-L/G cite= field
    description: list = field(default_factory=list)  # "..." prose rows
    derives: list = field(default_factory=list)      # `-> ...` arrows
    depends_on: list = field(default_factory=list)   # `<- ...` arrows
    source_file: str = ""
    source_line: int = 0


HEAD_RE = re.compile(
    r"^@(?P<type>[A-Za-z?])\s+(?P<id>[A-Za-z0-9_\-]+)"
    r"(?:\s*=\s*(?P<expr>.+?))?"
    r"\s*::\s*(?P<domain>[A-Za-z0-9_.\-]+)"
    r"\s*(?P<grade>\[[^\]]*\])?\s*$"
)

KV_RE  = re.compile(r"^\s*(?P<k>[a-z_]+)\s*=\s*(?P<v>.+)$")

# Numeric value extraction from expr.
NUM_RE = re.compile(
    r"(?P<num>[-+]?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?)"
    r"(?:\s*\*\s*(?P<mul>[a-zA-Z_][a-zA-Z0-9_]*))?$"
)
PURE_NUM_RE = re.compile(r"^[-+]?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?$")


def _parse_value(expr: str):
    """Best-effort numeric extraction from expr text. Returns Decimal-like
    (float) or original string if non-numeric.
    """
    if expr is None:
        return None
    e = expr.strip()
    # strip wrapping quotes (formula bodies)
    if e.startswith('"') and e.endswith('"'):
        return e[1:-1]
    # 4*pi*1e-7 style — leave as string (caller handles)
    if PURE_NUM_RE.match(e):
        try:
            v = float(e)
            return int(v) if v.is_integer() else v
        except ValueError:
            pass
    # try direct float
    try:
        v = float(e)
        return int(v) if v.is_integer() else v
    except ValueError:
        return e


def _parse_file(path: Path) -> dict:
    if not path.exists():
        return {}
    out = {}
    cur = None
    line_no = 0
    with path.open(encoding="utf-8") as f:
        for raw in f:
            line_no += 1
            line = raw.rstrip("\n")
            # blank / comment
            if not line.strip() or line.lstrip().startswith("#"):
                if cur is not None and not line.strip():
                    # blank ends an entry
                    out.setdefault(cur.id, cur)
                    cur = None
                continue
            # header
            m = HEAD_RE.match(line)
            if m:
                if cur is not None:
                    out.setdefault(cur.id, cur)
                cur = Entry(
                    type="@" + m.group("type"),
                    id=m.group("id"),
                    expr=(m.group("expr") or "").strip(),
                    domain=m.group("domain"),
                    grade=m.group("grade") or "",
                    value=_parse_value(m.group("expr")) if m.group("expr") else None,
                    source_file=str(path.name),
                    source_line=line_no,
                )
                continue
            if cur is None:
                continue
            t = line.strip()
            # description (quoted prose)
            if t.startswith('"') and t.endswith('"'):
                cur.description.append(t[1:-1])
                continue
            # arrow rows
            if t.startswith("<-"):
                cur.depends_on.extend([s.strip() for s in t[2:].split(",") if s.strip()])
                continue
            if t.startswith("->"):
                cur.derives.extend([s.strip() for s in t[2:].split(",") if s.strip()])
                continue
            if t.startswith("!!"):
                continue
            # axis-G / axis-L / axis-M continuation key=value
            kv = KV_RE.match(line)
            if kv:
                k = kv.group("k")
                v = kv.group("v").strip()
                if k == "unit":
                    cur.unit = v
                elif k == "anchor":
                    cur.anchor = v
                elif k == "cite":
                    cur.cite = v
                # other keys (introduced_at, vintage, ...) silently retained as desc
                continue
            # else: descriptive content — ignore
    if cur is not None:
        out.setdefault(cur.id, cur)
    return out


_CACHE = None


def load_anchors(force: bool = False) -> dict:
    """Load all entries from atlas.n6 + the 2 SSCB-relevant append shards.

    Cached on first call.
    """
    global _CACHE
    if _CACHE is not None and not force:
        return _CACHE
    merged: dict[str, Entry] = {}
    for fname in ATLAS_FILES:
        path = ATLAS_DIR / fname
        for k, v in _parse_file(path).items():
            # last-write-wins (later shards override earlier)
            merged[k] = v
    _CACHE = merged
    return merged


def lookup(entry_id: str) -> Entry:
    """Lookup a single entry by id. Raises KeyError if missing."""
    return load_anchors()[entry_id]


def value_of(entry_id: str):
    """Convenience: numeric value of an entry. Raises KeyError if missing,
    TypeError if non-numeric.
    """
    e = lookup(entry_id)
    if not isinstance(e.value, (int, float)):
        raise TypeError(
            f"{entry_id}: value is non-numeric ({type(e.value).__name__}: {e.value!r})"
        )
    return e.value


def main(argv):
    """Diagnostic mode: list entries by domain or specific id."""
    anchors = load_anchors()
    if len(argv) > 1 and argv[1] == "--list":
        domain_filter = argv[2] if len(argv) > 2 else None
        for k in sorted(anchors):
            e = anchors[k]
            if domain_filter and not e.domain.startswith(domain_filter):
                continue
            v = e.value if isinstance(e.value, (int, float)) else "(non-numeric)"
            print(f"  {e.type} {k:50s} = {v!s:25s} {e.unit:15s} {e.grade}")
        return 0
    if len(argv) > 1:
        for arg in argv[1:]:
            if arg in anchors:
                e = anchors[arg]
                print(f"id:           {e.id}")
                print(f"type:         {e.type}")
                print(f"value:        {e.value!r}")
                print(f"unit:         {e.unit!r}")
                print(f"anchor:       {e.anchor!r}")
                print(f"cite:         {e.cite!r}")
                print(f"domain:       {e.domain}")
                print(f"grade:        {e.grade}")
                print(f"depends_on:   {e.depends_on}")
                print(f"derives:      {e.derives}")
                print(f"description:  {e.description}")
                print(f"source:       {e.source_file}:{e.source_line}")
            else:
                print(f"NOT FOUND: {arg}")
        return 0
    print(f"loaded {len(anchors)} entries from {ATLAS_DIR}")
    print(f"  {sum(1 for e in anchors.values() if e.type == '@C')} @C constants")
    print(f"  {sum(1 for e in anchors.values() if e.type == '@P')} @P primitives")
    print(f"  {sum(1 for e in anchors.values() if e.type == '@L')} @L laws")
    print(f"  {sum(1 for e in anchors.values() if e.unit)} entries with axis-M unit=")
    print(f"  {sum(1 for e in anchors.values() if e.anchor)} entries with axis-M anchor=")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
