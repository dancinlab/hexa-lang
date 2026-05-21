#!/usr/bin/env python3
# structure.py - `sscb + structure` producer (D72 adapter-only · firmware-stub
# pattern · D111 cellrun-compatible · networkx BOM tree).
#
# Emits an `sscb_v1.meta.json` (sibling meta with `measurements` block for
# D113 cellrun payload flattening / roll-up) plus three sibling artifacts:
#
#   - sscb_v1.bom_graph.json  — full DiGraph serialized (nodes[] + edges[])
#   - sscb_v1.bom_dossier.md  — human-readable BOM narrative
#   - sscb_structure_<stamp>.json — top-level record JSON (Codable mirror)
#
# This is a TEMPLATE-emit structure (no datasheet binding, no thermal/EM
# coupling) — `absorbed = false` permanently per g3. The BOM tree is an
# illustrative scaffold transcribed from `~/core/demiurge/domains/sscb.md`
# §1 + §2 ARCHITECT row + `sscb.demi` scope_caveats. Real datasheet binding
# (Wolfspeed C3M0021120K · etc.) is design verb territory.
#
# Pattern reuse: mirrors `stdlib/grid/networkx_basics.py` (①b domain
# adapter — topology is domain knowledge, graph metrics delegated; here we
# inline a minimal metric set since the SSCB BOM is a tiny DiGraph and we
# don't need the full kernels/graph/ stack).
#
# Citations (domains/sscb.md §1 + §2):
#   - sscb.md §1 "Design blueprint deliverable" — HEXA-SSCB mk1 spec
#   - sscb.md §2 ARCHITECT row — "semiconductor / mechanical-disconnect
#     topology; pure-SS vs hybrid SSHCB"
#   - sscb.demi caveats — "BOM tree (SiC switch · gate driver · snubber ·
#     busbar · enclosure) producer 미작성 · networkx component-graph가
#     candidate (GridStructure 패턴 reuse)"
#
# D61: substrate SSOT here under hexa-lang/stdlib/sscb/.
# D116: hexa-lang stdlib is the single producer SSOT (sibling repos = docs only).
# g3:  honest. BOM is spec-level placeholder · no datasheet binding ·
#      absorbed=false PERMANENTLY for this cell (a BOM scaffold without
#      measured part bind-out is illustrative, not absorption).

from __future__ import annotations

import json
import platform
import sys
import time
from pathlib import Path
from typing import Optional

GEOMETRY_ID = "sscb_v1"


# --------------------------------------------------------------------------
# BOM tree topology — the ①b domain knowledge.
# --------------------------------------------------------------------------
# Transcribed from sscb.md §1 + §2 ARCHITECT row + sscb.demi caveats.
# Each node = a (component_id, attrs) tuple. Each edge = (src, dst, attrs).
# placeholder=true on every node — no datasheet binding at the structure
# verb (that's design territory).

def _build_nodes() -> list[dict]:
    """Spec-level BOM nodes (HEXA-SSCB mk1) — 5 layers, ~10 components.

    Categories (typed):
      mechanical   — enclosure, galvanic disconnect (root)
      power_path   — SiC switch stack, busbars (DC link / input / output)
      control      — gate driver IC, snubber
      commutation  — magnetic limiter (coupled inductor)
      thermal      — liquid cold plate

    part_class values are SPEC-LEVEL (e.g. "SiC-MOSFET" not
    "Wolfspeed-C3M0021120K") — datasheet bind = design verb.
    """
    return [
        # ---- root (mechanical, layer 0) ----------------------------------
        {
            "component_id": "enclosure",
            "category": "mechanical",
            "part_class": "enclosure-with-galvanic-disconnect",
            "placeholder": True,
            "notes": "SSCB outer case + mechanical isolator (galvanic "
                     "disconnect post-trip per UL 489I requirement).",
        },
        # ---- layer 1 (power path) ----------------------------------------
        {
            "component_id": "sic_switch_stack",
            "category": "power_path",
            "part_class": "SiC-MOSFET",
            "placeholder": True,
            "notes": "Paralleled SiC MOSFET die — count TBD by design "
                     "verb (Wolfspeed C3M-class candidate, Tier-2 fan-out).",
        },
        {
            "component_id": "busbar_input",
            "category": "power_path",
            "part_class": "copper-busbar",
            "placeholder": True,
            "notes": "Line-side busbar (1500 Vdc envelope).",
        },
        {
            "component_id": "busbar_dc_link",
            "category": "power_path",
            "part_class": "copper-busbar",
            "placeholder": True,
            "notes": "Internal DC link busbar between switch stack and "
                     "magnetic limiter.",
        },
        {
            "component_id": "busbar_output",
            "category": "power_path",
            "part_class": "copper-busbar",
            "placeholder": True,
            "notes": "Load-side busbar.",
        },
        # ---- layer 2 (control) -------------------------------------------
        {
            "component_id": "gate_driver_ic",
            "category": "control",
            "part_class": "gate-driver-IC",
            "placeholder": True,
            "notes": "Isolated SiC gate driver — di/dt + dv/dt control. "
                     "Specific part (e.g. IXYS IX2127, STGAP1AS) = "
                     "design verb territory.",
        },
        {
            "component_id": "snubber",
            "category": "control",
            "part_class": "RC-snubber-with-TVS",
            "placeholder": True,
            "notes": "RC snubber + TVS clamp for transient suppression. "
                     "RC sizing = design verb territory (Tier-2 fan-out).",
        },
        # ---- layer 3 (commutation) ---------------------------------------
        {
            "component_id": "magnetic_limiter",
            "category": "commutation",
            "part_class": "ferrite-core-coupled-inductor",
            "placeholder": True,
            "notes": "Magnetic current limiter / commutation circuit. "
                     "FEMMT sizing in synthesize verb.",
        },
        # ---- layer 4 (thermal) -------------------------------------------
        {
            "component_id": "cold_plate",
            "category": "thermal",
            "part_class": "liquid-cold-plate",
            "placeholder": True,
            "notes": "Active liquid cooling — OpenFOAM CHT analyze cell "
                     "consumer (sscb.md §2 ANALYZE row).",
        },
    ]


def _build_edges() -> list[dict]:
    """BOM edges — typed by path semantics (signal / power / thermal /
    mechanical). The graph is a DiGraph (directed) — edges point downstream
    in the current-flow / control-flow / thermal-flow sense.
    """
    return [
        # ---- mechanical_path: enclosure contains everything --------------
        {"src": "enclosure", "dst": "sic_switch_stack",
         "edge_type": "mechanical_path"},
        {"src": "enclosure", "dst": "busbar_input",
         "edge_type": "mechanical_path"},
        {"src": "enclosure", "dst": "busbar_dc_link",
         "edge_type": "mechanical_path"},
        {"src": "enclosure", "dst": "busbar_output",
         "edge_type": "mechanical_path"},
        {"src": "enclosure", "dst": "gate_driver_ic",
         "edge_type": "mechanical_path"},
        {"src": "enclosure", "dst": "snubber",
         "edge_type": "mechanical_path"},
        {"src": "enclosure", "dst": "magnetic_limiter",
         "edge_type": "mechanical_path"},
        {"src": "enclosure", "dst": "cold_plate",
         "edge_type": "mechanical_path"},
        # ---- power_path: line in → switch → dc link → limiter → load -----
        {"src": "busbar_input", "dst": "sic_switch_stack",
         "edge_type": "power_path"},
        {"src": "sic_switch_stack", "dst": "busbar_dc_link",
         "edge_type": "power_path"},
        {"src": "busbar_dc_link", "dst": "magnetic_limiter",
         "edge_type": "power_path"},
        {"src": "magnetic_limiter", "dst": "busbar_output",
         "edge_type": "power_path"},
        # ---- signal_path: gate driver controls switch; snubber clamps ----
        {"src": "gate_driver_ic", "dst": "sic_switch_stack",
         "edge_type": "signal_path"},
        {"src": "snubber", "dst": "sic_switch_stack",
         "edge_type": "signal_path"},
        # ---- thermal_path: switch + busbars → cold plate -----------------
        {"src": "sic_switch_stack", "dst": "cold_plate",
         "edge_type": "thermal_path"},
        {"src": "busbar_dc_link", "dst": "cold_plate",
         "edge_type": "thermal_path"},
        {"src": "magnetic_limiter", "dst": "cold_plate",
         "edge_type": "thermal_path"},
    ]


# --------------------------------------------------------------------------
# Graph build + metrics (networkx if available, else dict-of-lists fallback)
# --------------------------------------------------------------------------

def _build_graph_and_metrics(
    nodes: list[dict], edges: list[dict]
) -> tuple[dict, dict, Optional[str]]:
    """Build a graph (networkx DiGraph if available, else dict-of-lists)
    and compute a small typed metric set.

    Returns (graph_dump, metrics, networkx_version) — graph_dump is the
    JSON-serializable nodes+edges payload; networkx_version is None when
    we fell back to dict-of-lists (g3 — surface the gap honestly).
    """
    # Attempt networkx — gracefully fall back if missing or import-broken.
    nx_version: Optional[str] = None
    try:
        import networkx as nx  # type: ignore
        nx_version = nx.__version__
    except Exception:  # pragma: no cover — local dev fallback path
        nx = None  # type: ignore

    node_ids = [n["component_id"] for n in nodes]
    edge_pairs = [(e["src"], e["dst"]) for e in edges]

    if nx is not None:
        g = nx.DiGraph()
        for n in nodes:
            attrs = {k: v for k, v in n.items() if k != "component_id"}
            g.add_node(n["component_id"], **attrs)
        for e in edges:
            attrs = {k: v for k, v in e.items() if k not in ("src", "dst")}
            g.add_edge(e["src"], e["dst"], **attrs)
        node_count = g.number_of_nodes()
        edge_count = g.number_of_edges()
        # in/out degree per node — useful structural sanity.
        in_degrees = {nid: g.in_degree(nid) for nid in node_ids}
        out_degrees = {nid: g.out_degree(nid) for nid in node_ids}
        # weakly_connected — DiGraph connectivity sanity.
        is_weakly_connected = nx.is_weakly_connected(g)
    else:
        # dict-of-lists fallback — honest gap, surfaced via nx_version=None.
        adj: dict[str, list[str]] = {nid: [] for nid in node_ids}
        rev: dict[str, list[str]] = {nid: [] for nid in node_ids}
        for src, dst in edge_pairs:
            adj.setdefault(src, []).append(dst)
            rev.setdefault(dst, []).append(src)
        node_count = len(node_ids)
        edge_count = len(edge_pairs)
        in_degrees = {nid: len(rev.get(nid, [])) for nid in node_ids}
        out_degrees = {nid: len(adj.get(nid, [])) for nid in node_ids}
        # weakly_connected via BFS on undirected projection.
        und: dict[str, set[str]] = {nid: set() for nid in node_ids}
        for src, dst in edge_pairs:
            und.setdefault(src, set()).add(dst)
            und.setdefault(dst, set()).add(src)
        seen: set[str] = set()
        if node_ids:
            stack = [node_ids[0]]
            while stack:
                cur = stack.pop()
                if cur in seen:
                    continue
                seen.add(cur)
                stack.extend(und.get(cur, set()))
        is_weakly_connected = (len(seen) == len(node_ids))

    # Category + placeholder roll-ups (always computed regardless of nx).
    categories = sorted({n["category"] for n in nodes})
    category_counts = {
        c: sum(1 for n in nodes if n["category"] == c) for c in categories
    }
    placeholders = [n["component_id"] for n in nodes if n.get("placeholder")]
    edge_types = sorted({e["edge_type"] for e in edges})
    edge_type_counts = {
        et: sum(1 for e in edges if e["edge_type"] == et) for et in edge_types
    }

    graph_dump = {
        "nodes": nodes,
        "edges": edges,
        "node_count": node_count,
        "edge_count": edge_count,
        "is_weakly_connected": is_weakly_connected,
        "directed": True,
    }
    metrics = {
        "bom_node_count": node_count,
        "bom_edge_count": edge_count,
        "categories_count": len(categories),
        "categories": categories,
        "category_counts": category_counts,
        "edge_types": edge_types,
        "edge_type_counts": edge_type_counts,
        "placeholders_count": len(placeholders),
        "is_weakly_connected": is_weakly_connected,
        "in_degrees": in_degrees,
        "out_degrees": out_degrees,
    }
    return graph_dump, metrics, nx_version


def main(out_dir: str) -> int:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    produced_at_utc = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

    nodes = _build_nodes()
    edges = _build_edges()
    graph_dump, metrics, nx_version = _build_graph_and_metrics(nodes, edges)

    citations = [
        "domains/sscb.md §1 (HEXA-SSCB mk1 spec) — demiurge repo SSOT.",
        "domains/sscb.md §2 ARCHITECT row — "
        "'semiconductor / mechanical-disconnect topology; pure-SS vs "
        "hybrid SSHCB'.",
        "domains/sscb.demi [cell.structure] scope_caveats — "
        "'BOM tree (SiC switch · gate driver · snubber · busbar · "
        "enclosure) producer · networkx component-graph candidate "
        "(GridStructure 패턴 reuse)'.",
        "stdlib/grid/networkx_basics.py — ①b domain adapter pattern "
        "(IEEE 14-bus topology · GridStructure reuse anchor).",
    ]
    scope_caveats = [
        "BOM is spec-level placeholder — datasheet binding "
        "(Wolfspeed C3M0021120K · IXYS / STGAP1AS gate driver · "
        "etc.) = design verb territory, NOT structure.",
        "networkx graph is structural ONLY — no thermal/EM coupling. "
        "Thermal/EM coupling lives in analyze (OpenFOAM CHT) + "
        "synthesize (FEMMT sweeps) cells.",
        "absorbed=false maintained PERMANENTLY — spec-level BOM is "
        "illustrative scaffold, NOT a measured / vendor-validated "
        "bind-out (mirrors specify.py g3 stance).",
        "Tier-2 fan-out (paralleled SiC die count · busbar geometry · "
        "snubber RC sizing) requires upstream Specify resolution + "
        "downstream Design exploration — NOT resolved in this cell.",
    ]
    if nx_version is None:
        scope_caveats.append(
            "networkx import failed — fell back to dict-of-lists "
            "serialization (g3 — gap surfaced via "
            "networkx_version=null in meta.json).")

    # Sibling meta.json — D113 cellrun payload flattening source.
    # cellrun looks for `<geometry_id>.meta.json` (or any *.meta.json)
    # in the run_dir and rolls `measurements` up into the envelope's
    # `payload.measurements`. The `measurements` block surfaces the
    # primary scalar metrics for downstream roll-up.
    d113_measurements = {
        "bom_node_count": metrics["bom_node_count"],
        "bom_edge_count": metrics["bom_edge_count"],
        "categories_count": metrics["categories_count"],
        "placeholders_count": metrics["placeholders_count"],
    }

    meta = {
        "ok": True,
        "geometry_id": GEOMETRY_ID,
        "produced_at_utc": produced_at_utc,
        "python_version": platform.python_version(),
        "networkx_version": nx_version,
        # G7 typed gate_type — BOM scaffold template emit; no hexa-native
        # sscb-structure kernel exists (and the BOM is a doc template,
        # not a kernel) → D80 hexa-native-absent + provisional.
        "gate_type": "hexa-native-absent",
        "provisional": True,
        # D113 — measurements roll-up source.
        "measurements": d113_measurements,
        # Full metric set (in/out degrees, edge type counts, etc.).
        "metrics": metrics,
        "artifacts": {
            "bom_graph": f"{GEOMETRY_ID}.bom_graph.json",
            "bom_dossier": f"{GEOMETRY_ID}.bom_dossier.md",
        },
    }
    meta_path = out / f"{GEOMETRY_ID}.meta.json"
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2, sort_keys=True)
        f.write("\n")

    # BOM graph dump — full DiGraph (nodes + edges with attrs).
    graph_path = out / f"{GEOMETRY_ID}.bom_graph.json"
    with open(graph_path, "w", encoding="utf-8") as f:
        json.dump(graph_dump, f, indent=2, sort_keys=True)
        f.write("\n")

    # Plain-text BOM narrative.
    dossier_path = out / f"{GEOMETRY_ID}.bom_dossier.md"
    dossier_lines = [
        "# HEXA-SSCB mk1 — BOM dossier (structure cell template emit)",
        "",
        f"Stamp: {stamp}",
        f"Source SSOT: domains/sscb.md §1 + §2 ARCHITECT row (demiurge repo)",
        f"networkx_version: {nx_version or '(unavailable — dict-of-lists fallback)'}",
        "",
        "## Graph summary",
        "",
        f"- nodes: {metrics['bom_node_count']}",
        f"- edges: {metrics['bom_edge_count']}",
        f"- weakly connected: {metrics['is_weakly_connected']}",
        f"- categories: {', '.join(metrics['categories'])}",
        f"- placeholders: {metrics['placeholders_count']} "
        f"of {metrics['bom_node_count']} (100% — spec-level scaffold)",
        "",
        "## BOM tree (by category)",
        "",
    ]
    for cat in metrics["categories"]:
        dossier_lines.append(f"### {cat}")
        dossier_lines.append("")
        for n in nodes:
            if n["category"] == cat:
                dossier_lines.append(
                    f"- `{n['component_id']}` "
                    f"({n['part_class']}) — {n['notes']}")
        dossier_lines.append("")
    dossier_lines.extend([
        "## Edges (by path type)",
        "",
    ])
    for et in metrics["edge_types"]:
        dossier_lines.append(
            f"### {et} ({metrics['edge_type_counts'][et]} edges)")
        dossier_lines.append("")
        for e in edges:
            if e["edge_type"] == et:
                dossier_lines.append(f"- {e['src']} → {e['dst']}")
        dossier_lines.append("")
    dossier_lines.extend([
        "## Honest-skip caveats (g3)",
        "",
    ])
    dossier_lines.extend(f"- {c}" for c in scope_caveats)
    dossier_lines.append("")
    dossier_path.write_text("\n".join(dossier_lines), encoding="utf-8")

    # Top-level record — `sscb_structure_record` shape declared in
    # sscb.demi `[cell.structure].record_kind`. Mirrors specify.py's
    # top-level envelope shape (domain · verb · kind · stamp · producer
    # · measurement_gate · absorbed · scope_caveats · citations).
    producer_tag = (
        f"sscb_structure@networkx-{nx_version}"
        if nx_version else "sscb_structure@dict-of-lists-fallback"
    )
    record = {
        "domain": "sscb",
        "verb": "structure",
        "kind": "sscb_structure_record",
        "stamp": stamp,
        "producer": producer_tag,
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,
        "scope_caveats": scope_caveats,
        "citations": citations,
        "skipped_reason": None,
        "gate_type": "hexa-native-absent",
        "provisional": True,
        # Scalar roll-up fields (Codable mirror on cockpit).
        "bom_node_count": metrics["bom_node_count"],
        "bom_edge_count": metrics["bom_edge_count"],
        "categories": metrics["categories"],
        "placeholders": [
            n["component_id"] for n in nodes if n.get("placeholder")
        ],
        "notes": (
            "BOM tree spec-level scaffold — transcribes sscb.md §2 "
            "ARCHITECT row into a typed DiGraph. Datasheet binding + "
            "geometric / thermal sizing = design / synthesize / analyze "
            "verb territory."
        ),
        "artifacts": {
            "meta": meta_path.name,
            "bom_graph": graph_path.name,
            "bom_dossier": dossier_path.name,
        },
        # Pointer to the sibling graph file — downstream consumers (e.g.
        # design verb) can deserialize the full DiGraph from here.
        "bom_graph_file": graph_path.name,
    }
    rec_path = out / f"sscb_structure_{stamp}.json"
    with open(rec_path, "w", encoding="utf-8") as f:
        json.dump(record, f, indent=2, sort_keys=True)
        f.write("\n")

    sys.stderr.write(
        f"sscb_structure: wrote {rec_path} "
        f"(ok=True, nodes={metrics['bom_node_count']}, "
        f"edges={metrics['bom_edge_count']}, "
        f"categories={len(metrics['categories'])}, "
        f"placeholders={metrics['placeholders_count']})\n")

    summary = {
        "ok": True,
        "geometry_id": GEOMETRY_ID,
        "gate_type": "hexa-native-absent",
        "provisional": True,
        "networkx_version": nx_version,
        "bom_node_count": metrics["bom_node_count"],
        "bom_edge_count": metrics["bom_edge_count"],
        "categories_count": metrics["categories_count"],
        "placeholders_count": metrics["placeholders_count"],
        "is_weakly_connected": metrics["is_weakly_connected"],
        "artifacts": {
            "record": rec_path.name,
            "meta": meta_path.name,
            "bom_graph": graph_path.name,
            "bom_dossier": dossier_path.name,
        },
    }
    # SSCB_STRUCTURE_RESULT marker on stderr — mirrors specify.py /
    # ngspice_breaking.py pattern; cellrun and Swift CellrunDispatch
    # consume the merged stdout+stderr stream so either is fine.
    sys.stderr.write("SSCB_STRUCTURE_RESULT "
                     + json.dumps(summary, sort_keys=True) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/sscb_structure"))
