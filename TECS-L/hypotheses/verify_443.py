#!/usr/bin/env python3
"""H-CX-443: Small World Coefficient in Golden Zone verification"""
import numpy as np
from sklearn.datasets import load_digits
from sklearn.neural_network import MLPClassifier
from sklearn.model_selection import train_test_split
import warnings
warnings.filterwarnings('ignore')

# Golden Zone constants
GZ_UPPER = 0.5
GZ_LOWER = 0.5 - np.log(4/3)
GZ_CENTER = 1/np.e
GZ_WIDTH = np.log(4/3)

print("=" * 70)
print("H-CX-443: Small World Coefficient in Golden Zone")
print("=" * 70)
print(f"Golden Zone: [{GZ_LOWER:.4f}, {GZ_UPPER:.4f}], center={GZ_CENTER:.4f}")
print()

# Load data
X, y = load_digits(return_X_y=True)
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
X_train = X_train / 16.0
X_test = X_test / 16.0

hidden_sizes = [32, 64, 128, 256, 512]
results = []

try:
    import networkx as nx
    HAS_NX = True
    print("[INFO] networkx available, using it for graph metrics")
except ImportError:
    HAS_NX = False
    print("[INFO] networkx not available, using manual BFS")

def compute_graph_metrics_nx(W, threshold):
    """Compute small-world metrics using networkx"""
    n = W.shape[0] + W.shape[1]
    G = nx.Graph()
    G.add_nodes_from(range(n))
    abs_W = np.abs(W)
    for i in range(W.shape[0]):
        for j in range(W.shape[1]):
            if abs_W[i, j] > threshold:
                G.add_edge(i, W.shape[0] + j, weight=abs_W[i, j])

    # Only use largest connected component
    if not nx.is_connected(G):
        largest_cc = max(nx.connected_components(G), key=len)
        G = G.subgraph(largest_cc).copy()

    if len(G) < 4:
        return None

    C = nx.average_clustering(G)
    try:
        L = nx.average_shortest_path_length(G)
    except:
        return None

    # Random graph comparison (Erdos-Renyi with same density)
    n_nodes = len(G)
    n_edges = G.number_of_edges()
    p = 2 * n_edges / (n_nodes * (n_nodes - 1)) if n_nodes > 1 else 0

    # Theoretical random graph values
    C_rand_vals = []
    L_rand_vals = []
    for _ in range(5):
        G_rand = nx.erdos_renyi_graph(n_nodes, p)
        if nx.is_connected(G_rand):
            C_rand_vals.append(nx.average_clustering(G_rand))
            L_rand_vals.append(nx.average_shortest_path_length(G_rand))

    if not C_rand_vals:
        C_rand = p  # theoretical
        L_rand = np.log(n_nodes) / np.log(n_nodes * p) if n_nodes * p > 1 else float('inf')
    else:
        C_rand = np.mean(C_rand_vals)
        L_rand = np.mean(L_rand_vals)

    if C_rand < 1e-10 or L_rand < 1e-10:
        return None

    gamma_sw = C / C_rand  # clustering ratio
    lambda_sw = L / L_rand  # path length ratio
    sigma_sw = gamma_sw / lambda_sw if lambda_sw > 0 else float('inf')

    return {
        'C': C, 'L': L, 'C_rand': C_rand, 'L_rand': L_rand,
        'gamma': gamma_sw, 'lambda': lambda_sw, 'sigma': sigma_sw,
        'n_nodes': n_nodes, 'n_edges': n_edges, 'density': p
    }

def compute_graph_metrics_manual(W, threshold):
    """Manual BFS-based computation"""
    n_in, n_out = W.shape
    n = n_in + n_out
    abs_W = np.abs(W)

    # Build adjacency list
    adj = [[] for _ in range(n)]
    edge_count = 0
    for i in range(n_in):
        for j in range(n_out):
            if abs_W[i, j] > threshold:
                adj[i].append(n_in + j)
                adj[n_in + j].append(i)
                edge_count += 1

    # BFS for shortest paths
    from collections import deque
    def bfs_distances(start):
        dist = [-1] * n
        dist[start] = 0
        q = deque([start])
        while q:
            u = q.popleft()
            for v in adj[u]:
                if dist[v] == -1:
                    dist[v] = dist[u] + 1
                    q.append(v)
        return dist

    # Find largest connected component
    visited = [False] * n
    components = []
    for s in range(n):
        if not visited[s] and len(adj[s]) > 0:
            comp = []
            q = deque([s])
            visited[s] = True
            while q:
                u = q.popleft()
                comp.append(u)
                for v in adj[u]:
                    if not visited[v]:
                        visited[v] = True
                        q.append(v)
            components.append(comp)

    if not components:
        return None
    largest = max(components, key=len)
    if len(largest) < 4:
        return None

    # Average path length
    total_dist = 0
    count = 0
    for node in largest[:min(50, len(largest))]:  # sample for speed
        dists = bfs_distances(node)
        for other in largest:
            if dists[other] > 0:
                total_dist += dists[other]
                count += 1
    L = total_dist / count if count > 0 else float('inf')

    # Clustering coefficient
    node_set = set(largest)
    cc_vals = []
    for node in largest[:min(50, len(largest))]:
        neighbors = [v for v in adj[node] if v in node_set]
        k = len(neighbors)
        if k < 2:
            cc_vals.append(0)
            continue
        triangles = 0
        nset = set(neighbors)
        for ni in neighbors:
            for nj in adj[ni]:
                if nj in nset and nj != ni:
                    triangles += 1
        cc_vals.append(triangles / (k * (k - 1)) if k > 1 else 0)
    C = np.mean(cc_vals) if cc_vals else 0

    n_nodes = len(largest)
    p = 2 * edge_count / (n * (n - 1)) if n > 1 else 0
    C_rand = p
    L_rand = np.log(n_nodes) / np.log(max(n_nodes * p, 1.01))

    if C_rand < 1e-10 or L_rand < 1e-10:
        return None

    gamma_sw = C / C_rand
    lambda_sw = L / L_rand
    sigma_sw = gamma_sw / lambda_sw if lambda_sw > 0 else float('inf')

    return {
        'C': C, 'L': L, 'C_rand': C_rand, 'L_rand': L_rand,
        'gamma': gamma_sw, 'lambda': lambda_sw, 'sigma': sigma_sw,
        'n_nodes': n_nodes, 'n_edges': edge_count, 'density': p
    }

compute_metrics = compute_graph_metrics_nx if HAS_NX else compute_graph_metrics_manual

print("--- Training and analyzing networks ---")
print()

for h in hidden_sizes:
    print(f"  Hidden size = {h}...")

    # Train
    mlp = MLPClassifier(hidden_layer_sizes=(h,), max_iter=300, random_state=42)
    mlp.fit(X_train, y_train)
    acc = mlp.score(X_test, y_test)

    # Get weight matrix (input -> hidden)
    W = mlp.coefs_[0]  # shape: (64, h)
    abs_W = np.abs(W)
    threshold = abs_W.mean() + abs_W.std()

    # Trained network metrics
    m_trained = compute_metrics(W, threshold)

    # Random (untrained) network for comparison
    W_rand = np.random.randn(*W.shape) * 0.1
    abs_Wr = np.abs(W_rand)
    thresh_r = abs_Wr.mean() + abs_Wr.std()
    m_random = compute_metrics(W_rand, thresh_r)

    results.append({
        'h': h, 'acc': acc,
        'trained': m_trained,
        'random': m_random,
        'threshold': threshold
    })

    if m_trained:
        print(f"    Accuracy: {acc:.4f}")
        print(f"    Trained: sigma={m_trained['sigma']:.4f}, C={m_trained['C']:.4f}, L={m_trained['L']:.2f}")
        print(f"    C/C_rand={m_trained['gamma']:.4f}, L/L_rand={m_trained['lambda']:.4f}")
    else:
        print(f"    Accuracy: {acc:.4f}, metrics: could not compute (graph too sparse)")
    print()

# Summary table
print("=" * 70)
print("SUMMARY TABLE")
print("=" * 70)
print(f"{'Hidden':>8} {'Acc':>6} {'sigma_SW':>10} {'C/C_rand':>10} {'L/L_rand':>10} {'In GZ?':>8}")
print("-" * 60)

sigma_values = []
for r in results:
    m = r['trained']
    if m:
        in_gz = "YES" if GZ_LOWER <= m['sigma'] <= GZ_UPPER else "no"
        if 0 < m['sigma'] < 100:
            sigma_values.append(m['sigma'])
        print(f"{r['h']:>8} {r['acc']:>6.3f} {m['sigma']:>10.4f} {m['gamma']:>10.4f} {m['lambda']:>10.4f} {in_gz:>8}")
    else:
        print(f"{r['h']:>8} {r['acc']:>6.3f} {'N/A':>10} {'N/A':>10} {'N/A':>10} {'N/A':>8}")

print()

# Trained vs Random comparison
print("TRAINED vs RANDOM (sigma_SW)")
print("-" * 50)
print(f"{'Hidden':>8} {'Trained':>10} {'Random':>10} {'Ratio':>10}")
print("-" * 50)
for r in results:
    mt = r['trained']
    mr = r['random']
    if mt and mr and mr['sigma'] > 0:
        ratio = mt['sigma'] / mr['sigma']
        print(f"{r['h']:>8} {mt['sigma']:>10.4f} {mr['sigma']:>10.4f} {ratio:>10.4f}")
    else:
        print(f"{r['h']:>8} {'N/A':>10} {'N/A':>10} {'N/A':>10}")

print()

# Check specific ratios
print("RATIO CHECKS (Connection to TECS constants)")
print("-" * 50)
for r in results:
    m = r['trained']
    if m:
        print(f"  h={r['h']:>3}: C/C_rand={m['gamma']:.4f} (vs 1/e={1/np.e:.4f}, diff={abs(m['gamma']-1/np.e):.4f})")
        print(f"         L/L_rand={m['lambda']:.4f} (vs 2={2:.4f}, diff={abs(m['lambda']-2):.4f})")

print()

# ASCII Graph
print("ASCII GRAPH: Network Size vs sigma_SW")
print("-" * 50)
valid_results = [(r['h'], r['trained']['sigma']) for r in results if r['trained'] and 0 < r['trained']['sigma'] < 100]
if valid_results:
    max_sigma = max(v[1] for v in valid_results)
    min_sigma = min(v[1] for v in valid_results)
    chart_width = 50

    # Show Golden Zone bounds
    scale_max = max(max_sigma * 1.2, GZ_UPPER * 1.2)
    scale_min = 0

    print(f"  {'':>6} 0{' ' * (chart_width-1)}|{scale_max:.2f}")

    gz_low_pos = int(GZ_LOWER / scale_max * chart_width)
    gz_up_pos = int(GZ_UPPER / scale_max * chart_width)
    gz_cen_pos = int(GZ_CENTER / scale_max * chart_width)

    # Golden Zone band
    gz_line = [' '] * (chart_width + 1)
    for i in range(gz_low_pos, min(gz_up_pos + 1, chart_width + 1)):
        gz_line[i] = '░'
    gz_line[gz_cen_pos] = '▼'
    print(f"  {'GZ':>6} {''.join(gz_line)}  [{GZ_LOWER:.3f} - {GZ_UPPER:.3f}]")

    for h, sigma in valid_results:
        pos = int(sigma / scale_max * chart_width)
        pos = min(pos, chart_width)
        bar = '─' * pos + '●'
        in_gz = " ◄GZ" if GZ_LOWER <= sigma <= GZ_UPPER else ""
        print(f"  h={h:>3} {bar}{in_gz}  ({sigma:.4f})")

    print()

    # Statistics
    sigmas = [v[1] for v in valid_results]
    print(f"  Mean sigma_SW:   {np.mean(sigmas):.4f}")
    print(f"  Std sigma_SW:    {np.std(sigmas):.4f}")
    print(f"  Min:             {min(sigmas):.4f}")
    print(f"  Max:             {max(sigmas):.4f}")
    print(f"  Golden Zone:     [{GZ_LOWER:.4f}, {GZ_UPPER:.4f}]")
    print(f"  In GZ count:     {sum(1 for s in sigmas if GZ_LOWER <= s <= GZ_UPPER)}/{len(sigmas)}")
else:
    print("  No valid sigma_SW values computed")

print()
print("=" * 70)
print("DONE")
