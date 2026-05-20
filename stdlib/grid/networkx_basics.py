# networkx_basics.py — ①b domain adapter (demiurge design.md D72)
# NetworkX graph-topology producer for `grid + structure`.
#
# D72 2-layer restructure: this file is now a THIN domain adapter.
# It owns ONLY the domain-specific topology (the IEEE 14-bus edge
# list) and the domain honesty caveats. All graph-theoretic math is
# delegated to the shared ①a kernel `kernels/graph/networkx_kernel.py`
# (the same kernel `mobility/road_network.py` calls — N×M -> N+M).
#
# Invoked by Swift's GridStructureProducer via:
#   /usr/bin/env python3 .../stdlib/grid/networkx_basics.py <output_dir>
#
# What it does (honest scope):
#   1. Builds the IEEE 14-bus standard test topology (Christie 1962 /
#      pglib-opf canonical) as a NetworkX Graph. 14 nodes / 20 edges.
#      This — the topology — is the ①b domain knowledge.
#   2. Delegates ALL metric computation to the ①a graph kernel:
#      node/edge count, density, diameter, radius, avg shortest path,
#      clustering, bisection_min_cut_edges, top-N centrality.
#   3. Writes the graph + metrics + provenance to
#      `<output_dir>/grid_ieee14_v1.{gml,meta.json}`.
#
# HONESTY (g3 — non-negotiable, domain caveats stay HERE):
#   * producer = "networkx@<version>" — pins the library, NOT the
#     real-world fabric. IEEE 14-bus is a *published reference test
#     case* (Christie 1962, University of Washington Power Systems
#     Test Case Archive, mirrored as pglib-opf `case14`). The
#     TOPOLOGY is canonical; the *graph metrics ARE mathematical
#     facts* about it — IEEE-754-deterministic, NOT a model
#     prediction. -> measurement_gate = GATE_CLOSED_MEASURED is
#     honest (the graph IS the measurement).
#   * absorbed = false ALWAYS — networkx is EXTERNAL. The day a
#     hexa-native graph kernel re-computes these metrics, absorbed
#     flips in the ①a kernel — not in this adapter.
#   * SCOPE CAVEATS:
#       - IEEE 14-bus is a POWER-GRID reference case; the demiurge
#         `grid` domain is AI DATACENTER fabric. This producer
#         demonstrates the WIRING on a canonical measured graph —
#         NOT a real DC fat-tree from a hyperscaler manifest.
#       - bisection_min_cut_edges counts LINKS, not Gbps. No SerDes
#         channel model. The real DC bisection-bandwidth gate lives
#         in ns-3 / SST simulation (domains/grid.md §2 ANALYZE).
#       - top-N centrality is reported for N=3 — single-point, not a
#         sensitivity sweep.

import json
import os
import sys
import time

# --- Locate the ①a graph kernel relative to this adapter's own file
# (stdlib/grid/ -> stdlib/kernels/graph/). The Swift spawn sets an
# arbitrary cwd, so a path relative to __file__ is the only robust
# anchor.
_KERNEL_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "kernels", "graph")
if _KERNEL_DIR not in sys.path:
    sys.path.insert(0, _KERNEL_DIR)


# --- Topology identifier (the "geometry id" analogue for graphs)
GEOMETRY_ID = "grid_ieee14_v1"
TOP_N = 3


def build_ieee14_edges() -> list:
    """IEEE 14-bus standard test topology — 14 buses, 20 transmission
    lines / transformers, all distinct (no parallel-edge multi-graph).
    Edge list mirrors the canonical Christie 1962 / pglib-opf `case14`
    adjacency (1-indexed bus numbers).

    Source: <https://labs.ece.uw.edu/pstca/pf14/pg_tca14bus.htm> +
    pglib-opf `pglib_opf_case14_ieee.m` branch table. The TOPOLOGY is
    canonical and reproducible; this list IS the SSOT for this
    adapter — it is the ①b domain knowledge."""
    return [
        (1, 2), (1, 5),
        (2, 3), (2, 4), (2, 5),
        (3, 4),
        (4, 5), (4, 7), (4, 9),
        (5, 6),
        (6, 11), (6, 12), (6, 13),
        (7, 8), (7, 9),
        (9, 10), (9, 14),
        (10, 11),
        (12, 13),
        (13, 14),
    ]


def main(argv: list) -> int:
    if len(argv) < 2:
        sys.stderr.write("usage: networkx_basics.py <output_dir>\n")
        return 2
    output_dir = argv[1]
    os.makedirs(output_dir, exist_ok=True)

    # Import the ①a kernel — honest gap if the kernel module or
    # networkx itself is missing.
    try:
        import networkx_kernel as kernel
    except ImportError as exc:
        sys.stderr.write(
            f"networkx_basics: ①a graph kernel import failed — {exc}. "
            "Expected at stdlib/kernels/graph/networkx_kernel.py (g3 — "
            "silent success forbidden).\n")
        summary = {"ok": False, "geometry_id": GEOMETRY_ID,
                   "error": "graph_kernel_import_failed"}
        sys.stderr.write(
            "GRID_NETWORKX_RESULT " + json.dumps(summary, sort_keys=True) + "\n")
        return 3

    try:
        import networkx as nx
    except ImportError as exc:
        sys.stderr.write(
            f"networkx_basics: networkx import failed — {exc}. "
            "Install with `pip3 install --user networkx` (g3 — "
            "silent success forbidden).\n")
        summary = {"ok": False, "geometry_id": GEOMETRY_ID,
                   "error": "networkx_import_failed"}
        sys.stderr.write(
            "GRID_NETWORKX_RESULT " + json.dumps(summary, sort_keys=True) + "\n")
        return 3

    nx_version = kernel.networkx_version()

    edges = build_ieee14_edges()
    edges_hash = kernel.edges_sha256_16(edges)

    g = nx.Graph()
    g.add_nodes_from(range(1, 15))
    g.add_edges_from(edges)

    # --- Delegate ALL graph math to the ①a kernel.
    t0 = time.perf_counter()
    try:
        meas = kernel.topology_metrics(g, top_n=TOP_N)
    except Exception as exc:
        sys.stderr.write(
            f"networkx_basics: kernel metric computation failed — {exc} (g3).\n")
        summary = {"ok": False, "geometry_id": GEOMETRY_ID,
                   "edges_sha256_16": edges_hash,
                   "error": f"compute_failed: {exc}"}
        sys.stderr.write(
            "GRID_NETWORKX_RESULT " + json.dumps(summary, sort_keys=True) + "\n")
        return 4
    t_elapsed = time.perf_counter() - t0

    # Persist the graph (GML — widely-readable, NetworkX round-trip
    # safe) so downstream tools can re-load it.
    gml_path = os.path.join(output_dir, f"{GEOMETRY_ID}.gml")
    meta_path = os.path.join(output_dir, f"{GEOMETRY_ID}.meta.json")

    try:
        nx.write_gml(g, gml_path)
    except Exception as exc:
        sys.stderr.write(
            f"networkx_basics: GML write failed — {exc} (g3).\n")
        summary = {"ok": False, "geometry_id": GEOMETRY_ID,
                   "edges_sha256_16": edges_hash,
                   "error": f"gml_write_failed: {exc}"}
        sys.stderr.write(
            "GRID_NETWORKX_RESULT " + json.dumps(summary, sort_keys=True) + "\n")
        return 5

    meta = {
        "ok": True,
        "geometry_id": GEOMETRY_ID,
        "edges_sha256_16": edges_hash,
        "networkx_version": nx_version,
        "topology": {
            "name": "IEEE 14-bus",
            "source": "Christie 1962 / pglib-opf case14",
            "node_count": g.number_of_nodes(),
            "edge_count": g.number_of_edges(),
            "edges": [list(e) for e in edges],
        },
        "measurements": meas,
        "compute_elapsed_s": t_elapsed,
        "artifacts": {
            "gml": f"{GEOMETRY_ID}.gml",
        },
    }
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2, sort_keys=True)
        f.write("\n")

    sys.stderr.write(
        f"networkx_basics: wrote {meta_path} "
        f"(nodes={meas['node_count']}, edges={meas['edge_count']}, "
        f"diameter={meas['diameter']}, "
        f"bisection={meas['bisection_min_cut_edges']})\n")

    artifacts_with_meta = dict(meta["artifacts"])
    artifacts_with_meta["meta"] = f"{GEOMETRY_ID}.meta.json"
    summary = {
        "ok": True,
        "geometry_id": GEOMETRY_ID,
        "edges_sha256_16": edges_hash,
        "networkx_version": nx_version,
        "node_count": meas["node_count"],
        "edge_count": meas["edge_count"],
        "diameter": meas["diameter"],
        "avg_shortest_path_hops": meas["avg_shortest_path_hops"],
        "bisection_min_cut_edges": meas["bisection_min_cut_edges"],
        "artifacts": artifacts_with_meta,
    }
    sys.stderr.write(
        "GRID_NETWORKX_RESULT " + json.dumps(summary, sort_keys=True) + "\n")
    sys.stderr.flush()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
