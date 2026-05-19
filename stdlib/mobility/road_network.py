# road_network.py — ①b domain adapter (demiurge design.md D72)
# osmnx-based road-network topology producer for `mobility + analyze`.
#
# D72 2-layer restructure: this file is now a THIN domain adapter.
# It owns ONLY the domain topology (the synthetic Manhattan grid) and
# the domain honesty caveats. The domain-agnostic graph-theoretic
# math (connectivity / diameter / centrality) is delegated to the
# shared ①a kernel `kernels/graph/networkx_kernel.py` — the same
# kernel `grid/networkx_basics.py` calls (N×M -> N+M).
#
# osmnx.basic_stats stays HERE: it is an osmnx-specific road-graph
# statistic (intersection_count, streets_per_node, edge_length), not
# a generic graph metric — so it belongs to the mobility adapter, not
# the graph kernel.
#
# Invoked by Swift's MobilityAnalyzeProducer via:
#   /opt/homebrew/bin/python3 .../stdlib/mobility/road_network.py <out_dir>
#
# What it does (honest scope — g3):
#   1. Synthesize a deterministic 10x10 Manhattan-style grid (block
#      spacing 100 m, anchored on Midtown Manhattan lat/lon for
#      coordinate plausibility). 100 intersections, 360 directed
#      edges. A *standard topology fixture*, not a fetched real road
#      network — no internet, reproducible byte-for-byte.
#   2. Run osmnx.basic_stats(G) for the osmnx-specific road-graph
#      statistics (intersection count, k_avg, edge_length totals,
#      streets_per_node distribution).
#   3. Delegate connectivity + diameter to the ①a graph kernel
#      (`topology_metrics`) — the generic graph facts.
#   4. Emit road_network.meta.json with parameters + measurements +
#      library versions so cross-host drift is visible.
#
# HONESTY (g3 — non-negotiable, domain caveats stay HERE):
#   * Graph topology measurements ARE real (osmnx.basic_stats and the
#     kernel's networkx algorithms are standard — genuine outputs for
#     the synthetic Manhattan grid topology).
#   * BUT this is *graph topology only* — NO traffic flow, NO travel
#     time, NO vehicle simulation, NO real OSM data. The synthetic
#     grid is a *topology fixture*, not "the road network of
#     Manhattan". A real mobility-analyze record (SUMO/CARLA —
#     domains/mobility.md §2) would need orders of magnitude more
#     setup; this producer stops at the topology layer to keep cohort
#     breadth-coverage tractable (g3 — honest narrow scope).
#   * measurement_gate stays GATE_OPEN ALWAYS. absorbed = false
#     ALWAYS. Real "absorbed" mobility analysis would need a real OSM
#     extract, a calibrated demand matrix, and a validated micro-sim.
#   * If osmnx/networkx/the kernel are missing OR analysis fails,
#     returns ok=false and writes the error verbatim. Silent success
#     is forbidden.

import json
import math
import os
import platform
import sys
import warnings

warnings.filterwarnings("ignore")

# --- Locate the ①a graph kernel relative to this adapter's own file
# (stdlib/mobility/ -> stdlib/kernels/graph/). The Swift spawn sets an
# arbitrary cwd, so a path relative to __file__ is the only robust
# anchor.
_KERNEL_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "kernels", "graph")
if _KERNEL_DIR not in sys.path:
    sys.path.insert(0, _KERNEL_DIR)

# --- Deterministic synthetic topology parameters (①b domain knowledge).
GEOMETRY_ID = "road_network_manhattan_grid_10x10_v1"
PLACE_LABEL = "Synthetic_Manhattan_Grid_10x10"
GRID_N = 10                  # 10 x 10 intersections
BLOCK_LENGTH_M = 100.0       # 100 m between adjacent intersections
# Coordinates plausibly anchored on Midtown Manhattan (40.7549, -73.9840)
# so a downstream map viewer renders in the right place — but NO real
# Manhattan road data is read; the grid is wholly synthetic.
ORIGIN_LAT = 40.7549
ORIGIN_LON = -73.9840


def osmnx_version() -> str:
    try:
        import osmnx
        return osmnx.__version__
    except Exception:
        return "unknown"


def build_grid_graph():
    """Build a deterministic 10x10 Manhattan grid as a MultiDiGraph
    with osmnx-compatible node attributes (x=lon, y=lat, street_count)
    and edge attributes (length in metres). Returns the MultiDiGraph
    so osmnx.basic_stats() can consume it directly. This is the ①b
    domain knowledge — the synthetic mobility topology."""
    import networkx as nx

    G = nx.MultiDiGraph()
    G.graph["crs"] = "EPSG:4326"

    # Approximate degrees-per-metre at origin latitude (good enough
    # for a 1 km x 1 km synthetic grid — NOT claimed geodesically
    # exact; only the edge_length attribute below is the true block
    # spacing in metres).
    deg_per_m_lat = 1.0 / 111000.0
    deg_per_m_lon = 1.0 / (111000.0 * math.cos(math.radians(ORIGIN_LAT)))

    def nid(i: int, j: int) -> int:
        return i * GRID_N + j

    # Nodes — i indexes north-south rows, j indexes east-west cols.
    for i in range(GRID_N):
        for j in range(GRID_N):
            y = ORIGIN_LAT + (i - GRID_N / 2) * BLOCK_LENGTH_M * deg_per_m_lat
            x = ORIGIN_LON + (j - GRID_N / 2) * BLOCK_LENGTH_M * deg_per_m_lon
            G.add_node(nid(i, j), x=x, y=y)

    # Edges — bidirectional adjacency to NSEW neighbour intersections.
    # `length` is the metric edge length osmnx.basic_stats expects.
    for i in range(GRID_N):
        for j in range(GRID_N):
            if j + 1 < GRID_N:
                G.add_edge(nid(i, j), nid(i, j + 1), length=BLOCK_LENGTH_M)
                G.add_edge(nid(i, j + 1), nid(i, j), length=BLOCK_LENGTH_M)
            if i + 1 < GRID_N:
                G.add_edge(nid(i, j), nid(i + 1, j), length=BLOCK_LENGTH_M)
                G.add_edge(nid(i + 1, j), nid(i, j), length=BLOCK_LENGTH_M)

    # osmnx.basic_stats expects each node to carry a `street_count`
    # attribute (number of distinct streets meeting at the node).
    # In a directed grid that is the number of unique adjacent
    # intersections; approximated as out-degree (correct for an
    # un-multi grid — one edge per neighbour pair).
    for n in G.nodes():
        G.nodes[n]["street_count"] = sum(1 for _ in G.successors(n))

    return G


def run_simulation(output_dir: str) -> dict:
    """Build the grid, run osmnx.basic_stats, delegate connectivity +
    diameter to the ①a graph kernel, and write a CSV of the edge
    list. Raises on import / library failure — the caller (main)
    catches and reports honest gap."""
    import osmnx as ox
    import networkx_kernel as kernel

    G = build_grid_graph()

    # osmnx-specific road-graph statistics — stay in the adapter.
    stats = ox.basic_stats(G)

    # Generic graph facts — delegated to the ①a kernel. The kernel
    # internally projects the MultiDiGraph to a simple undirected
    # graph for connectivity / diameter.
    graph_metrics = kernel.topology_metrics(G, top_n=3)
    components = 1 if graph_metrics["is_connected"] else None
    diameter = graph_metrics["diameter"]

    streets_per_node_counts = {
        str(k): int(v) for k, v in stats.get("streets_per_node_counts", {}).items()
    }

    # Write the edge list as CSV for downstream sweeps (small —
    # 360 rows × 3 cols). Geometry serialization not needed since the
    # grid is deterministic; recipients regenerate from GEOMETRY_ID.
    csv_path = os.path.join(output_dir, f"{GEOMETRY_ID}.edges.csv")
    with open(csv_path, "w", encoding="utf-8") as f:
        f.write("u,v,length_m\n")
        for u, v, data in G.edges(data=True):
            f.write(f"{u},{v},{data.get('length', '')}\n")

    return {
        "node_count": int(stats["n"]),
        "edge_count": int(stats["m"]),
        "intersection_count": int(stats["intersection_count"]),
        "k_avg": round(float(stats["k_avg"]), 6),
        "edge_length_total_m": round(float(stats["edge_length_total"]), 3),
        "edge_length_avg_m": round(float(stats["edge_length_avg"]), 3),
        "streets_per_node_avg": round(float(stats["streets_per_node_avg"]), 6),
        "streets_per_node_counts": streets_per_node_counts,
        "connected_components": int(components) if components is not None else 0,
        "diameter_undirected": int(diameter) if diameter is not None else None,
        "edges_csv_artifact": f"{GEOMETRY_ID}.edges.csv",
    }


def main(argv: list) -> int:
    if len(argv) < 2:
        sys.stderr.write("usage: road_network.py <output_dir>\n")
        return 2
    output_dir = argv[1]
    os.makedirs(output_dir, exist_ok=True)

    meta_path = os.path.join(output_dir, f"{GEOMETRY_ID}.meta.json")
    ox_v = osmnx_version()
    py_v = platform.python_version()

    # networkx version probed via the ①a kernel — single source.
    try:
        import networkx_kernel as _kernel_probe
        nx_v = _kernel_probe.networkx_version()
    except Exception:
        nx_v = "unknown"

    try:
        measurements = run_simulation(output_dir)
        ok = True
        err = None
    except Exception as exc:
        ok = False
        err = f"{type(exc).__name__}: {exc}"
        measurements = {
            "node_count": 0, "edge_count": 0, "intersection_count": 0,
            "k_avg": None, "edge_length_total_m": None,
            "edge_length_avg_m": None, "streets_per_node_avg": None,
            "streets_per_node_counts": {}, "connected_components": 0,
            "diameter_undirected": None, "edges_csv_artifact": None,
        }

    meta = {
        "ok": ok,
        "geometry_id": GEOMETRY_ID,
        "osmnx_version": ox_v,
        "networkx_version": nx_v,
        "python_version": py_v,
        "error": err,
        "place": {
            "label": PLACE_LABEL,
            "origin_lat": ORIGIN_LAT,
            "origin_lon": ORIGIN_LON,
            "is_synthetic": True,
        },
        "topology": {
            "grid_n": GRID_N,
            "block_length_m": BLOCK_LENGTH_M,
            "model": "manhattan_grid_synthetic",
        },
        "measurements": measurements,
        "artifacts": {
            "edges_csv": measurements.get("edges_csv_artifact") or "",
        },
    }

    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2, sort_keys=True)
        f.write("\n")

    sys.stderr.write(
        f"road_network: wrote {meta_path} (ok={ok}, "
        f"nodes={measurements['node_count']}, "
        f"edges={measurements['edge_count']})\n")
    if not ok:
        sys.stderr.write(f"road_network: error -> {err}\n")

    artifacts_with_meta = dict(meta["artifacts"])
    artifacts_with_meta["meta"] = f"{GEOMETRY_ID}.meta.json"
    summary = {
        "ok": ok,
        "geometry_id": GEOMETRY_ID,
        "osmnx_version": ox_v,
        "networkx_version": nx_v,
        "python_version": py_v,
        "node_count": measurements["node_count"],
        "edge_count": measurements["edge_count"],
        "intersection_count": measurements["intersection_count"],
        "k_avg": measurements["k_avg"],
        "edge_length_total_m": measurements["edge_length_total_m"],
        "diameter_undirected": measurements["diameter_undirected"],
        "artifacts": artifacts_with_meta,
    }
    sys.stderr.write("MOBILITY_ROAD_NETWORK_RESULT "
                     + json.dumps(summary, sort_keys=True) + "\n")
    sys.stderr.flush()
    return 0 if ok else 5


if __name__ == "__main__":
    sys.exit(main(sys.argv))
