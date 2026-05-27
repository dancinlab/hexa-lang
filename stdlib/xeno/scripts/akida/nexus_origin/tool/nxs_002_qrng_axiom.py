#!/usr/bin/env python3
"""Ω-saturation cycle 7: QRNG + 양자컴퓨터 시뮬 기반 axiom 후보.

Cycle 3 anti-hub plateau 0.85008 (Δ +0.018), cycle 6 ER sweet 2×200 plateau Δ +0.003.
gap to 0.9 = 0.067; classical PRNG (uniform Bernoulli) axiom 들이 도달한 천장은 ~0.85.

가설 (cycle 7): classical PRNG 가 만든 sparse graph 의 Laplacian 스펙트럼은
atlas 의 REGULAR uniform-spacing 과 isomorphic 해서 const CHAOTIC 와의 gap 을 못 깬다.
**양자 시스템 (Haar-random unitary, quantum walk) 의 spectrum 통계 (Wigner-Dyson β=2,
GUE level repulsion)** 을 graph topology 에 주입하면 const 와 더 가까워질 가능성.

후보:
  Q1 RRG-QRNG: k-matching union → k-regular random graph (Kesten-McKay 스펙트럼)
  Q2 quantum-walk: 2^n 차원 Haar U trajectory → 방문 graph (양자 walk 분산)
  Q3 Haar-kNN: Haar 직교벡터 embedding → kNN graph (random geometric in Haar space)

Entropy: os.urandom (kernel entropy pool — hardware noise 포함, QRNG 와 통계적
구분 불가능 for our composite Δ purpose). --seed-hex 로 외부 QRNG (예: ANU API)
주입 가능.
"""
import argparse, hashlib, json, os, sys, time
import numpy as np
from scipy.sparse import csr_matrix
from scipy.sparse.csgraph import connected_components
from scipy.stats import unitary_group

sys.path.insert(0, os.path.expanduser("~/core/nexus/tool"))
from nxs_002_composite import (
    build_csr_from_blowup, laplacian_eigenvalues, paircorr, unfold,
    composite_aligned, load_eig_jsonl, DEFAULT_ATLAS, DEFAULT_CONST,
)


def qrng_seed_seq(seed_hex=None, source="os_urandom"):
    if seed_hex:
        raw = bytes.fromhex(seed_hex)
        if len(raw) < 8:
            raise ValueError("seed-hex 는 최소 16 hex chars (8 bytes)")
    elif source == "os_urandom":
        raw = os.urandom(32)
    else:
        raise ValueError(f"unknown qrng source: {source}")
    h = hashlib.sha256(raw).hexdigest()
    seed_int = int.from_bytes(raw[:8], "big")
    return np.random.SeedSequence(seed_int), h, source


def coo_lists(A):
    coo = A.tocoo()
    return list(coo.row), list(coo.col)


def q1_rrg(A_base, n_base, N_new, k, ss):
    rng = np.random.default_rng(ss)
    rows, cols = coo_lists(A_base)
    new_idx = list(range(n_base, n_base + N_new))
    edge_set = set()
    for _ in range(k):
        perm = rng.permutation(N_new)
        for i in range(0, N_new - 1, 2):
            a, b = int(perm[i]), int(perm[i+1])
            edge_set.add((min(a, b), max(a, b)))
    for a, b in edge_set:
        u, v = new_idx[a], new_idx[b]
        rows.extend([u, v]); cols.extend([v, u])
    anchor = int(rng.integers(0, n_base))
    rows.extend([new_idx[0], anchor]); cols.extend([anchor, new_idx[0]])
    n_total = n_base + N_new
    A_new = csr_matrix((np.ones(len(rows)), (rows, cols)), shape=(n_total, n_total))
    A_new.sum_duplicates(); A_new.data[:] = 1.0
    return A_new, {"n_edges_added": len(edge_set)}


def q2_quantum_walk(A_base, n_base, n_qubits, n_steps, ss):
    rng = np.random.default_rng(ss)
    N = 2 ** n_qubits
    rs = np.random.RandomState(int(rng.integers(0, 2**31)))
    U = unitary_group.rvs(N, random_state=rs)
    psi = np.zeros(N, dtype=complex); psi[0] = 1.0
    rows, cols = coo_lists(A_base)
    new_idx = list(range(n_base, n_base + N))
    edge_set = set()
    prev = 0
    for _ in range(n_steps):
        psi = U @ psi
        probs = np.abs(psi) ** 2
        s = probs.sum()
        if s <= 0:
            break
        probs = probs / s
        idx = int(rng.choice(N, p=probs))
        if idx != prev:
            edge_set.add((min(prev, idx), max(prev, idx)))
        prev = idx
    for a, b in edge_set:
        u, v = new_idx[a], new_idx[b]
        rows.extend([u, v]); cols.extend([v, u])
    anchor = int(rng.integers(0, n_base))
    rows.extend([new_idx[0], anchor]); cols.extend([anchor, new_idx[0]])
    n_total = n_base + N
    A_new = csr_matrix((np.ones(len(rows)), (rows, cols)), shape=(n_total, n_total))
    A_new.sum_duplicates(); A_new.data[:] = 1.0
    return A_new, {"n_qubits": n_qubits, "n_steps": n_steps,
                   "N_states": N, "n_edges_added": len(edge_set)}


def q4_qrng_er(A_base, n_base, n_blocks, block_size, p, ss):
    """Q4: QRNG-seeded ER (cycle 6 sweet 2×200 protocol, classical entropy 만 교체).
    classical PRNG vs QRNG entropy 가 composite Δ 에 차이 주는지 검증용 control."""
    rng = np.random.default_rng(ss)
    rows, cols = coo_lists(A_base)
    cur = n_base
    for _ in range(n_blocks):
        idx = list(range(cur, cur + block_size))
        for i in range(block_size):
            for j in range(i + 1, block_size):
                if rng.random() < p:
                    rows.extend([idx[i], idx[j]]); cols.extend([idx[j], idx[i]])
        anchor = int(rng.integers(0, n_base))
        rows.extend([idx[0], anchor]); cols.extend([anchor, idx[0]])
        cur += block_size
    A_new = csr_matrix((np.ones(len(rows)), (rows, cols)), shape=(cur, cur))
    A_new.sum_duplicates(); A_new.data[:] = 1.0
    return A_new, {"n_blocks": n_blocks, "block_size": block_size, "p": p}


def q5_qwalk_fragments(A_base, n_base, n_qubits, n_steps, n_frags, ss):
    """Q5: 다중 격리 quantum walk fragment — subcritical ER 처럼 다중 component 로
    near-zero eigenvalue 다수 주입 + 각 fragment 내부는 quantum trajectory (Wigner-Dyson)."""
    rng = np.random.default_rng(ss)
    N = 2 ** n_qubits
    rows, cols = coo_lists(A_base)
    cur = n_base
    total_edges = 0
    for f in range(n_frags):
        rs = np.random.RandomState(int(rng.integers(0, 2**31)))
        U = unitary_group.rvs(N, random_state=rs)
        psi = np.zeros(N, dtype=complex); psi[0] = 1.0
        edge_set = set()
        prev = 0
        for _ in range(n_steps):
            psi = U @ psi
            probs = np.abs(psi) ** 2
            s = probs.sum()
            if s <= 0:
                break
            probs = probs / s
            idx = int(rng.choice(N, p=probs))
            if idx != prev:
                edge_set.add((min(prev, idx), max(prev, idx)))
            prev = idx
        idx_off = list(range(cur, cur + N))
        for a, b in edge_set:
            u, v = idx_off[a], idx_off[b]
            rows.extend([u, v]); cols.extend([v, u])
        anchor = int(rng.integers(0, n_base))
        rows.extend([idx_off[0], anchor]); cols.extend([anchor, idx_off[0]])
        cur += N
        total_edges += len(edge_set)
    A_new = csr_matrix((np.ones(len(rows)), (rows, cols)), shape=(cur, cur))
    A_new.sum_duplicates(); A_new.data[:] = 1.0
    return A_new, {"n_qubits": n_qubits, "n_steps_per_frag": n_steps,
                   "n_frags": n_frags, "N_per_frag": N,
                   "n_edges_added": total_edges}


def q6_rrg_fragments(A_base, n_base, frag_size, n_frags, k, ss):
    """Q6: 다중 격리 RRG fragments — multi-component + Kesten-McKay spectrum."""
    rng = np.random.default_rng(ss)
    rows, cols = coo_lists(A_base)
    cur = n_base
    total_edges = 0
    for _ in range(n_frags):
        edge_set = set()
        for _km in range(k):
            perm = rng.permutation(frag_size)
            for i in range(0, frag_size - 1, 2):
                a, b = int(perm[i]), int(perm[i + 1])
                edge_set.add((min(a, b), max(a, b)))
        idx_off = list(range(cur, cur + frag_size))
        for a, b in edge_set:
            u, v = idx_off[a], idx_off[b]
            rows.extend([u, v]); cols.extend([v, u])
        anchor = int(rng.integers(0, n_base))
        rows.extend([idx_off[0], anchor]); cols.extend([anchor, idx_off[0]])
        cur += frag_size
        total_edges += len(edge_set)
    A_new = csr_matrix((np.ones(len(rows)), (rows, cols)), shape=(cur, cur))
    A_new.sum_duplicates(); A_new.data[:] = 1.0
    return A_new, {"frag_size": frag_size, "n_frags": n_frags, "k": k,
                   "n_edges_added": total_edges}


def q3_haar_knn(A_base, n_base, N_new, emb_dim, k_nn, ss):
    rng = np.random.default_rng(ss)
    rs = np.random.RandomState(int(rng.integers(0, 2**31)))
    if N_new <= 256:
        U = unitary_group.rvs(N_new, random_state=rs)
        emb = np.real(U[:, :emb_dim])
    else:
        Z = rs.randn(N_new, emb_dim) + 1j * rs.randn(N_new, emb_dim)
        Q, _ = np.linalg.qr(Z)
        emb = np.real(Q)
    from scipy.spatial.distance import cdist
    D = cdist(emb, emb)
    np.fill_diagonal(D, np.inf)
    nn = np.argsort(D, axis=1)[:, :k_nn]
    rows, cols = coo_lists(A_base)
    new_idx = list(range(n_base, n_base + N_new))
    edge_set = set()
    for i in range(N_new):
        for j in nn[i]:
            a, b = i, int(j)
            edge_set.add((min(a, b), max(a, b)))
    for a, b in edge_set:
        u, v = new_idx[a], new_idx[b]
        rows.extend([u, v]); cols.extend([v, u])
    anchor = int(rng.integers(0, n_base))
    rows.extend([new_idx[0], anchor]); cols.extend([anchor, new_idx[0]])
    n_total = n_base + N_new
    A_new = csr_matrix((np.ones(len(rows)), (rows, cols)), shape=(n_total, n_total))
    A_new.sum_duplicates(); A_new.data[:] = 1.0
    return A_new, {"emb_dim": emb_dim, "k_nn": k_nn, "n_edges_added": len(edge_set)}


def lsr_diagnostic(vals):
    """Level Spacing Ratio: r_i = min(s_i,s_{i+1})/max(...).
    Poisson(uncorrelated): <r>≈0.386. GOE β=1: ≈0.5359. GUE β=2: ≈0.5996."""
    nz = np.sort(vals[vals > 1e-10])
    s = np.diff(nz)
    if len(s) < 2:
        return None
    r = np.minimum(s[:-1], s[1:]) / np.maximum(s[:-1], s[1:])
    return float(np.mean(r))


def measure_composite(A, R2_const, K=100, sigma=1e-3):
    vals = laplacian_eigenvalues(A, K=K, sigma=sigma)
    R2 = paircorr(unfold(vals))
    res = composite_aligned(R2, R2_const)
    n_cc, _ = connected_components(A, directed=False)
    res["n_cc"] = int(n_cc)
    res["n_total"] = int(A.shape[0])
    res["lsr_mean"] = lsr_diagnostic(vals)
    return res


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--method", choices=["q1_rrg", "q2_qwalk", "q3_haar_knn",
                                          "q4_qrng_er", "q5_qwalk_frags", "q6_rrg_frags",
                                          "all", "all_frag"], default="all")
    ap.add_argument("--n-new", type=int, default=200)
    ap.add_argument("--rrg-k", type=int, default=4)
    ap.add_argument("--qwalk-qubits", type=int, default=7)
    ap.add_argument("--qwalk-steps", type=int, default=600)
    ap.add_argument("--knn-emb-dim", type=int, default=8)
    ap.add_argument("--knn-k", type=int, default=4)
    ap.add_argument("--er-blocks", type=int, default=2)
    ap.add_argument("--er-block-size", type=int, default=200)
    ap.add_argument("--er-p", type=float, default=0.020)
    ap.add_argument("--frag-size", type=int, default=20)
    ap.add_argument("--n-frags", type=int, default=10)
    ap.add_argument("--seed-hex", default=None)
    ap.add_argument("--n-runs", type=int, default=1)
    ap.add_argument("--K", type=int, default=100)
    ap.add_argument("--sigma", type=float, default=1e-3)
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()

    t0 = time.time()
    A_base, n_base = build_csr_from_blowup(DEFAULT_ATLAS)
    R2_const = paircorr(unfold(load_eig_jsonl(DEFAULT_CONST)))
    base = measure_composite(A_base, R2_const, K=args.K, sigma=args.sigma)
    base_composite = base["composite_after"]

    out = {
        "schema": "nxs_002_qrng_axiom.v1",
        "ts": int(time.time()),
        "baseline": {
            "composite_after": round(base_composite, 5),
            "lsr_mean": base["lsr_mean"],
            "n_base": int(n_base),
        },
        "args": vars(args),
        "runs": [],
    }

    if args.method == "all":
        methods = ["q1_rrg", "q2_qwalk", "q3_haar_knn"]
    elif args.method == "all_frag":
        methods = ["q4_qrng_er", "q5_qwalk_frags", "q6_rrg_frags"]
    else:
        methods = [args.method]
    for run_i in range(args.n_runs):
        for m in methods:
            ss, seed_hash, src = qrng_seed_seq(args.seed_hex)
            t1 = time.time()
            if m == "q1_rrg":
                A, params = q1_rrg(A_base, n_base, args.n_new, args.rrg_k, ss)
            elif m == "q2_qwalk":
                A, params = q2_quantum_walk(A_base, n_base, args.qwalk_qubits, args.qwalk_steps, ss)
            elif m == "q3_haar_knn":
                A, params = q3_haar_knn(A_base, n_base, args.n_new, args.knn_emb_dim, args.knn_k, ss)
            elif m == "q4_qrng_er":
                A, params = q4_qrng_er(A_base, n_base, args.er_blocks, args.er_block_size, args.er_p, ss)
            elif m == "q5_qwalk_frags":
                A, params = q5_qwalk_fragments(A_base, n_base, args.qwalk_qubits, args.qwalk_steps, args.n_frags, ss)
            elif m == "q6_rrg_frags":
                A, params = q6_rrg_fragments(A_base, n_base, args.frag_size, args.n_frags, args.rrg_k, ss)
            res = measure_composite(A, R2_const, K=args.K, sigma=args.sigma)
            elapsed = time.time() - t1
            row = {
                "run": run_i, "method": m,
                "seed_hash": seed_hash[:16], "qrng_source": src,
                "params": params,
                "composite_after": round(res["composite_after"], 5),
                "delta_vs_baseline": round(res["composite_after"] - base_composite, 5),
                "lsr_mean": round(res["lsr_mean"], 4) if res["lsr_mean"] else None,
                "n_total": res["n_total"], "n_cc": res["n_cc"],
                "elapsed_s": round(elapsed, 2),
            }
            out["runs"].append(row)
            if not args.quiet:
                print(f"[{m}] Δ={row['delta_vs_baseline']:+.5f}  composite={row['composite_after']:.5f}  "
                      f"LSR={row['lsr_mean']}  cc={row['n_cc']}  t={row['elapsed_s']}s",
                      file=sys.stderr)

    out["total_elapsed_s"] = round(time.time() - t0, 2)
    print(json.dumps(out, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
