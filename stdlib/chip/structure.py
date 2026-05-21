#!/usr/bin/env python3
# structure.py - `chip + structure` producer (D72 adapter-only ·
# firmware-stub pattern · D111 cellrun-compatible · networkx module DAG).
#
# Emits chip_v1.meta.json + chip_v1.bom_graph.json + chip_v1.bom_dossier.md +
# chip_structure_<stamp>.json (4 artifacts · sscb structure.py mirror).
#
# Parses the `--rtl <path>` Verilog file via a tiny regex-based module/port
# extractor (NOT a full Verilog parser · yosys hierarchy dump would be the
# proper substrate; we keep the structure cell light to avoid spawning
# yosys here — analyze + synthesize cells are the yosys consumers).
#
# Each module → DiGraph node; each instance → directed edge from top
# to submodule. For the 5 reference chips: counter4 / pwm8 / crc8 are
# 1-module flat (just the top); uart_tx / spi_master have FSM state +
# shift_reg + baud_counter conceptual subblocks declared via internal
# `reg` arrays (we surface those as conceptual nodes for the BOM).
#
# argv:
#   chip/structure.py <output_dir> [--rtl <path>]
#
# g3: honest. Regex-based Verilog parser is best-effort — full Verilog
#     hierarchy (real submodule instantiation graphs) is a yosys hexa-native
#     job (stdlib/yosys/read_verilog.hexa). This cell is a quick BOM
#     scaffold so cockpit Models/ChipStructureRecord.swift has a typed shape.

from __future__ import annotations

import json
import platform
import re
import sys
import time
from pathlib import Path
from typing import Optional

GEOMETRY_ID = "chip_v1"

DEFAULT_RTL = "/Users/ghost/core/demiurge/archive/comb/rtl/counter4.v"

# Conceptual-subblock roster per top module (chip.demi §5-chip walkthrough
# context). For flat chips this is empty (just the top module node).
# For FSM chips we surface the conceptual subblocks (state · counter ·
# shift register) as BOM nodes since they're the natural review units.
# This is informational scaffolding — NOT a real submodule-instance parse.
CONCEPTUAL_SUBBLOCKS = {
    "counter4":   [],
    "pwm8":       [
        {"name": "duty_compare", "kind": "comb", "notes": "8-bit duty cycle comparator."},
    ],
    "uart_tx":    [
        {"name": "fsm_state",    "kind": "state",   "notes": "5-state FSM (IDLE/START/DATA/STOP/DONE)."},
        {"name": "baud_counter", "kind": "counter", "notes": "4-bit oversample-by-16 baud divider."},
        {"name": "shift_reg",    "kind": "register","notes": "8-bit LSB-first shift register."},
    ],
    "crc8":       [
        {"name": "lfsr",         "kind": "register","notes": "8-bit LFSR (CRC-8 CCITT poly 0x07)."},
        {"name": "xor_tree",     "kind": "comb",    "notes": "Combinational XOR feedback tree."},
    ],
    "spi_master": [
        {"name": "fsm_state",    "kind": "state",   "notes": "3-state FSM (IDLE/SHIFT/DONE)."},
        {"name": "shift_reg",    "kind": "register","notes": "8-bit MSB-first shift register."},
        {"name": "sck_divider",  "kind": "counter", "notes": "Programmable SCK divider."},
    ],
}


def _parse_argv(argv: list[str]) -> tuple[str, Optional[str]]:
    out_dir = "/tmp/chip_structure"
    rtl_path: Optional[str] = None
    i = 1
    positional: list[str] = []
    while i < len(argv):
        tok = argv[i]
        if tok == "--rtl" and i + 1 < len(argv):
            rtl_path = argv[i + 1]
            i += 2
            continue
        positional.append(tok)
        i += 1
    if positional:
        out_dir = positional[0]
    return out_dir, rtl_path


def _scan_rtl(rtl_path: str) -> dict:
    """Lightweight Verilog regex scan.

    Returns dict with:
      - top_module: first `module <name>` declaration
      - port_count_in / port_count_out: input / output count
      - reg_count: `reg ...` declarations (rough DFF surrogate)
      - always_count: `always @(...)` blocks
      - localparam_count: state encoding parameters (FSM hint)
      - loc: file line count
      - parse_ok: True if file readable + at least one module found
    """
    p = Path(rtl_path)
    out = {
        "top_module": p.stem,
        "port_count_in": 0,
        "port_count_out": 0,
        "reg_count": 0,
        "always_count": 0,
        "localparam_count": 0,
        "loc": 0,
        "parse_ok": False,
        "parse_error": None,
    }
    try:
        text = p.read_text(encoding="utf-8")
    except Exception as e:
        out["parse_error"] = f"read failed: {e}"
        return out
    out["loc"] = text.count("\n") + 1
    # Strip line-comments to reduce false matches.
    body = re.sub(r"//[^\n]*", "", text)
    m = re.search(r"\bmodule\s+([A-Za-z_]\w*)\s*[\(;]", body)
    if m:
        out["top_module"] = m.group(1)
        out["parse_ok"] = True
    out["port_count_in"] = len(re.findall(r"\binput\s+(?:wire|reg)?\s*(?:\[[^\]]+\])?\s*[A-Za-z_]", body))
    out["port_count_out"] = len(re.findall(r"\boutput\s+(?:wire|reg)?\s*(?:\[[^\]]+\])?\s*[A-Za-z_]", body))
    out["reg_count"] = len(re.findall(r"^\s*reg\s+(?:\[[^\]]+\])?\s*[A-Za-z_]", body, flags=re.MULTILINE))
    out["always_count"] = len(re.findall(r"\balways\s*@", body))
    out["localparam_count"] = len(re.findall(r"\blocalparam\b", body))
    return out


def _build_graph(rtl_scan: dict) -> tuple[list[dict], list[dict]]:
    """Build BOM nodes + edges from RTL scan + conceptual subblocks.

    Always emits:
      - 1 top-module node (root)
      - N conceptual subblock nodes (per CONCEPTUAL_SUBBLOCKS[top])
      - N edges from top → each subblock (mechanical_path style)
    """
    top = rtl_scan["top_module"]
    nodes = [{
        "component_id": top,
        "category": "top_module",
        "kind": "verilog_module",
        "loc": rtl_scan["loc"],
        "port_count_in": rtl_scan["port_count_in"],
        "port_count_out": rtl_scan["port_count_out"],
        "reg_count": rtl_scan["reg_count"],
        "always_count": rtl_scan["always_count"],
        "placeholder": False,
        "notes": f"Top-level Verilog module ({rtl_scan['loc']} LOC).",
    }]
    edges: list[dict] = []
    for sub in CONCEPTUAL_SUBBLOCKS.get(top, []):
        nodes.append({
            "component_id": f"{top}.{sub['name']}",
            "category": "conceptual_subblock",
            "kind": sub["kind"],
            "placeholder": True,
            "notes": sub["notes"],
        })
        edges.append({
            "src": top,
            "dst": f"{top}.{sub['name']}",
            "edge_type": "contains",
        })
    return nodes, edges


def _build_graph_and_metrics(
    nodes: list[dict], edges: list[dict]
) -> tuple[dict, dict, Optional[str]]:
    nx_version: Optional[str] = None
    try:
        import networkx as nx  # type: ignore
        nx_version = nx.__version__
    except Exception:
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
        in_degrees = {nid: g.in_degree(nid) for nid in node_ids}
        out_degrees = {nid: g.out_degree(nid) for nid in node_ids}
        is_weakly_connected = (
            nx.is_weakly_connected(g) if node_count > 0 else True
        )
    else:
        node_count = len(node_ids)
        edge_count = len(edge_pairs)
        adj: dict[str, list[str]] = {nid: [] for nid in node_ids}
        rev: dict[str, list[str]] = {nid: [] for nid in node_ids}
        for src, dst in edge_pairs:
            adj.setdefault(src, []).append(dst)
            rev.setdefault(dst, []).append(src)
        in_degrees = {nid: len(rev.get(nid, [])) for nid in node_ids}
        out_degrees = {nid: len(adj.get(nid, [])) for nid in node_ids}
        # weakly connected via undirected BFS.
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

    categories = sorted({n["category"] for n in nodes})
    category_counts = {
        c: sum(1 for n in nodes if n["category"] == c) for c in categories
    }
    placeholders = [n["component_id"] for n in nodes if n.get("placeholder")]

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
        "categories": categories,
        "category_counts": category_counts,
        "placeholders_count": len(placeholders),
        "is_weakly_connected": is_weakly_connected,
        "in_degrees": in_degrees,
        "out_degrees": out_degrees,
    }
    return graph_dump, metrics, nx_version


def main(argv: list[str]) -> int:
    out_dir, rtl_path = _parse_argv(argv)
    rtl = rtl_path or DEFAULT_RTL
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    produced_at_utc = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

    rtl_scan = _scan_rtl(rtl)
    nodes, edges = _build_graph(rtl_scan)
    graph_dump, metrics, nx_version = _build_graph_and_metrics(nodes, edges)

    citations = [
        "chip.demi [cell.structure] — chip_structure_record kind.",
        "stdlib/yosys/read_verilog.hexa (Phase A · κ-43) — full-fidelity "
        "RTLIL frontend (this Python cell uses a regex shim, NOT the full "
        "Verilog parser).",
        "stdlib/sscb/structure.py — networkx BOM mirror pattern.",
        "IEEE Std 1364-2005 — Verilog synthesizable subset.",
    ]
    scope_caveats = [
        "Verilog parser is regex-based (best-effort) — full hierarchy + "
        "submodule instantiation graph = yosys hexa-native job "
        "(stdlib/yosys/read_verilog.hexa).",
        "Conceptual subblocks (fsm_state · shift_reg · etc.) are "
        "informational scaffold from a hardcoded roster (chip.demi §5-chip "
        "walkthrough) — NOT extracted from the RTL hierarchy.",
        "absorbed=false PERMANENTLY — BOM scaffold without yosys "
        "hierarchy dump is illustrative, not absorption.",
    ]
    if nx_version is None:
        scope_caveats.append(
            "networkx import failed — fell back to dict-of-lists "
            "(networkx_version=null in meta.json).")
    if not rtl_scan["parse_ok"]:
        scope_caveats.append(
            f"RTL parse degraded: {rtl_scan.get('parse_error') or 'no module declaration found'} "
            f"— top_module fell back to filename stem.")

    d113_measurements = {
        "bom_node_count": metrics["bom_node_count"],
        "bom_edge_count": metrics["bom_edge_count"],
        "loc": rtl_scan["loc"],
        "port_count_in": rtl_scan["port_count_in"],
        "port_count_out": rtl_scan["port_count_out"],
        "reg_count": rtl_scan["reg_count"],
        "always_count": rtl_scan["always_count"],
        "localparam_count": rtl_scan["localparam_count"],
    }

    meta = {
        "ok": True,
        "geometry_id": GEOMETRY_ID,
        "produced_at_utc": produced_at_utc,
        "python_version": platform.python_version(),
        "networkx_version": nx_version,
        "gate_type": "hexa-native-absent",
        "provisional": True,
        "measurements": d113_measurements,
        "metrics": metrics,
        "rtl_path": rtl,
        "rtl_top": rtl_scan["top_module"],
        "artifacts": {
            "bom_graph": f"{GEOMETRY_ID}.bom_graph.json",
            "bom_dossier": f"{GEOMETRY_ID}.bom_dossier.md",
        },
    }
    meta_path = out / f"{GEOMETRY_ID}.meta.json"
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2, sort_keys=True)
        f.write("\n")

    graph_path = out / f"{GEOMETRY_ID}.bom_graph.json"
    with open(graph_path, "w", encoding="utf-8") as f:
        json.dump(graph_dump, f, indent=2, sort_keys=True)
        f.write("\n")

    dossier_path = out / f"{GEOMETRY_ID}.bom_dossier.md"
    dossier_lines = [
        f"# chip BOM dossier — {rtl_scan['top_module']} (structure cell template emit)",
        "",
        f"Stamp: {stamp}",
        f"RTL: {rtl}",
        f"Top module: {rtl_scan['top_module']}",
        f"networkx_version: {nx_version or '(unavailable — dict-of-lists fallback)'}",
        "",
        "## RTL scan summary",
        "",
        f"- LOC: {rtl_scan['loc']}",
        f"- Inputs: {rtl_scan['port_count_in']}",
        f"- Outputs: {rtl_scan['port_count_out']}",
        f"- `reg` declarations: {rtl_scan['reg_count']}",
        f"- `always @(...)` blocks: {rtl_scan['always_count']}",
        f"- `localparam` declarations: {rtl_scan['localparam_count']}",
        "",
        "## BOM graph summary",
        "",
        f"- nodes: {metrics['bom_node_count']}",
        f"- edges: {metrics['bom_edge_count']}",
        f"- weakly connected: {metrics['is_weakly_connected']}",
        f"- placeholders: {metrics['placeholders_count']} "
        f"of {metrics['bom_node_count']}",
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
                    f"- `{n['component_id']}` ({n['kind']}) — {n['notes']}")
        dossier_lines.append("")
    dossier_lines.extend([
        "## Honest-skip caveats (g3)",
        "",
    ])
    dossier_lines.extend(f"- {c}" for c in scope_caveats)
    dossier_lines.append("")
    dossier_path.write_text("\n".join(dossier_lines), encoding="utf-8")

    producer_tag = (
        f"chip_structure@networkx-{nx_version}"
        if nx_version else "chip_structure@dict-of-lists-fallback"
    )
    record = {
        "domain": "chip",
        "verb": "structure",
        "kind": "chip_structure_record",
        "stamp": stamp,
        "producer": producer_tag,
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,
        "scope_caveats": scope_caveats,
        "citations": citations,
        "skipped_reason": None,
        "gate_type": "hexa-native-absent",
        "provisional": True,
        "rtl_path": rtl,
        "rtl_top": rtl_scan["top_module"],
        "bom_node_count": metrics["bom_node_count"],
        "bom_edge_count": metrics["bom_edge_count"],
        "loc": rtl_scan["loc"],
        "port_count_in": rtl_scan["port_count_in"],
        "port_count_out": rtl_scan["port_count_out"],
        "reg_count": rtl_scan["reg_count"],
        "always_count": rtl_scan["always_count"],
        "localparam_count": rtl_scan["localparam_count"],
        "bom_graph_file": graph_path.name,
        "notes": (
            "Regex-based Verilog scan + conceptual subblock roster from "
            "chip.demi §5-chip walkthrough. Full hierarchy parse = "
            "stdlib/yosys/read_verilog.hexa downstream."
        ),
        "artifacts": {
            "meta": meta_path.name,
            "bom_graph": graph_path.name,
            "bom_dossier": dossier_path.name,
        },
    }
    rec_path = out / f"chip_structure_{stamp}.json"
    with open(rec_path, "w", encoding="utf-8") as f:
        json.dump(record, f, indent=2, sort_keys=True)
        f.write("\n")

    sys.stderr.write(
        f"chip_structure: wrote {rec_path} "
        f"(ok=True, top='{rtl_scan['top_module']}', "
        f"nodes={metrics['bom_node_count']}, "
        f"edges={metrics['bom_edge_count']}, "
        f"loc={rtl_scan['loc']})\n")

    summary = {
        "ok": True,
        "geometry_id": GEOMETRY_ID,
        "gate_type": "hexa-native-absent",
        "provisional": True,
        "networkx_version": nx_version,
        "rtl_top": rtl_scan["top_module"],
        "bom_node_count": metrics["bom_node_count"],
        "bom_edge_count": metrics["bom_edge_count"],
        "loc": rtl_scan["loc"],
        "artifacts": {
            "record": rec_path.name,
            "meta": meta_path.name,
            "bom_graph": graph_path.name,
            "bom_dossier": dossier_path.name,
        },
    }
    sys.stderr.write("CHIP_STRUCTURE_RESULT "
                     + json.dumps(summary, sort_keys=True) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
