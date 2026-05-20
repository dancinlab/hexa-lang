# networkx_kernel.py — ①a STDLIB kernel layer (demiurge design.md D72)
#
# Domain-agnostic graph-theoretic computation kernel. This is the
# FIRST kernel extracted under the D72 2-layer restructure: producers
# in `stdlib/<domain>/` that compute graph metrics (grid, mobility,
# and any future graph-domain) call into this single module instead
# of each re-implementing the networkx wrapping.
#
# Layer split (ABSORPTION.md ①):
#   ①a kernel  — THIS FILE. Domain-independent. No IEEE 14-bus, no
#                Manhattan grid — only "given a networkx graph,
#                compute the deterministic facts about it".
#   ①b adapter — `stdlib/grid/networkx_basics.py`,
#                `stdlib/mobility/road_network.py`. They own the
#                domain topology (geometry / parameters) and call
#                this kernel for the math.
#
# HONESTY (g3 — non-negotiable, inherited by every caller):
#   * Every value computed here IS a mathematical fact about the
#     graph topology — IEEE-754-deterministic, NOT a model
#     prediction. The honesty gate lives on the *real-world
#     interpretation* (domain caveats), which stays in the ①b
#     adapter, NOT here.
#   * absorbed = false ALWAYS at the record layer — networkx is an
#     EXTERNAL Python library, not absorbed into hexa-lang. The day a
#     hexa-native graph kernel re-computes these metrics with a
#     numerically-identical algorithm, absorbed flips — and it flips
#     HERE (one kernel) rather than in N domain adapters. That is the
#     entire point of the 2-layer restructure (N×M -> N+M).
#   * Import failure is reported verbatim by the caller; this module
#     raises rather than swallowing — silent success is forbidden.

import hashlib
from typing import Any


def networkx_version() -> str:
    """Probe the installed networkx version. Returns 'unknown' if the
    library cannot be imported — the caller decides whether that is a
    hard gap (it is, for graph producers)."""
    try:
        import networkx
        return str(networkx.__version__)
    except Exception:
        return "unknown"


def edges_sha256_16(edges: list) -> str:
    """Hash a canonical undirected edge list so cross-host drift is
    visible — same hash <-> byte-identical topology. Edges are
    normalized to (min, max) and sorted before hashing, so direction
    and ordering do not affect the digest. Truncated to 16 hex chars
    to mirror sscb_ngspice's netlist_sha256_16."""
    norm = sorted((min(a, b), max(a, b)) for a, b in edges)
    payload = ";".join(f"{a}-{b}" for a, b in norm).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()[:16]


def topology_metrics(graph: Any, top_n: int = 3) -> dict:
    """Compute the deterministic graph-theoretic metrics for a
    networkx graph. Domain-agnostic: works for power-grid topologies,
    road networks, NoC fabrics, or any graph.

    `graph` may be a Graph / DiGraph / MultiGraph / MultiDiGraph.
    Directed/multi inputs are projected to a simple undirected graph
    for the shortest-path and connectivity metrics (those quantities
    are only well-defined on the undirected simple projection).

    Returns a flat dict serializable to JSON. Shortest-path metrics
    are None when the graph is disconnected (honest — not 0)."""
    import networkx as nx

    # Undirected simple projection for path / connectivity metrics.
    if graph.is_directed() or graph.is_multigraph():
        simple = nx.Graph()
        simple.add_nodes_from(graph.nodes())
        simple.add_edges_from((u, v) for u, v in graph.to_undirected().edges())
    else:
        simple = graph

    n = graph.number_of_nodes()
    m = graph.number_of_edges()
    connected = bool(nx.is_connected(simple)) if n > 0 else False

    if connected:
        diameter = int(nx.diameter(simple))
        radius = int(nx.radius(simple))
        avg_sp = float(nx.average_shortest_path_length(simple))
        # Minimum edge-connectivity = smallest s-t cut over all node
        # pairs. The graph-theoretic surrogate for "fabric bisection"
        # — counted in LINKS, not Gbps (a domain caveat the ①b
        # adapter must surface; the kernel only counts edges).
        bisection_min_cut = int(nx.edge_connectivity(simple))
    else:
        diameter = None
        radius = None
        avg_sp = None
        bisection_min_cut = None

    density = float(nx.density(simple))
    avg_clustering = float(nx.average_clustering(simple))

    btw = nx.betweenness_centrality(simple)
    deg = nx.degree_centrality(simple)

    def _top_n(d: dict) -> list:
        # Sort by score descending, ties broken by node id ascending,
        # so the result is fully deterministic.
        items = sorted(d.items(), key=lambda kv: (-kv[1], _node_key(kv[0])))[:top_n]
        return [{"node": _json_node(k), "score": float(v)} for k, v in items]

    return {
        "node_count": int(n),
        "edge_count": int(m),
        "is_connected": connected,
        "density": density,
        "diameter": diameter,
        "radius": radius,
        "avg_shortest_path_hops": avg_sp,
        "average_clustering": avg_clustering,
        "bisection_min_cut_edges": bisection_min_cut,
        "top_betweenness": _top_n(btw),
        "top_degree": _top_n(deg),
    }


def _node_key(node: Any):
    """Sort key for a node id — int nodes sort numerically, anything
    else by string form. Keeps tie-breaking deterministic regardless
    of node-id type."""
    return (0, node) if isinstance(node, int) else (1, str(node))


def _json_node(node: Any):
    """Coerce a node id to a JSON-friendly scalar (int stays int,
    everything else becomes str)."""
    return int(node) if isinstance(node, int) else str(node)
