# stdlib/kernels/fem/bar1d_oracle.py
# D80 g_hexa_only pilot #10 — Python `math` oracle for bar1d_kernel.hexa.
#
# Hand-mirrored line-by-line transliteration of `bar1d_kernel.hexa`
# using only `math` (no numpy, no scipy, no scikit-fem). Both sides
# walk the same loops in the same operation order with the same
# floating-point operations, so IEEE-754 results are bit-stable on
# darwin-arm64.
#
# The oracle is used in two ways by the parity test
# (`bar1d_kernel_test.hexa`):
#   1. Closed-form mechanics-of-materials reference for the fixed-free
#      tip-load case: u(x_k) = P · x_k / (E·A). INDEPENDENT of the
#      discretisation — true external oracle, not a self-mirror.
#   2. Bit-exact transliteration: when the .hexa kernel and this Python
#      script execute the same operations in the same order on the
#      same inputs, the results match at rel_err = 0.0 (literal
#      IEEE-754 bit-exact).

import math


def bar1d_element_stiffness(E, A, L):
    """2×2 element stiffness — Hughes §1.6."""
    c = E * A / L
    return [[c, -c], [-c, c]]


def bar1d_assemble_K(nodes, E, A):
    """Global (n × n) dense stiffness via direct-stiffness assembly."""
    n = len(nodes)
    K = [[0.0 for _ in range(n)] for _ in range(n)]
    n_elem = n - 1
    for e in range(n_elem):
        L = nodes[e + 1] - nodes[e]
        ke = bar1d_element_stiffness(E, A, L)
        K[e][e] += ke[0][0]
        K[e][e + 1] += ke[0][1]
        K[e + 1][e] += ke[1][0]
        K[e + 1][e + 1] += ke[1][1]
    return K


def thomas_tridiag(a, d, c, b):
    """Burden & Faires §6.6 — Crout factorisation for tridiagonal."""
    m = len(d)
    cp = list(c)
    dp = list(b)
    cp[0] = c[0] / d[0]
    dp[0] = b[0] / d[0]
    for k in range(1, m):
        denom = d[k] - a[k] * cp[k - 1]
        if k < m - 1:
            cp[k] = c[k] / denom
        dp[k] = (b[k] - a[k] * dp[k - 1]) / denom
    u = [0.0] * m
    u[m - 1] = dp[m - 1]
    for j in range(m - 2, -1, -1):
        u[j] = dp[j] - cp[j] * u[j + 1]
    return u


def bar1d_solve_fixed_free(nodes, E, A, P_tip):
    n = len(nodes)
    K = bar1d_assemble_K(nodes, E, A)
    m = n - 1
    a = []
    d = []
    c = []
    b = []
    for i in range(m):
        gi = i + 1
        d.append(K[gi][gi])
        if i == 0:
            a.append(0.0)
        else:
            a.append(K[gi][gi - 1])
        if i == m - 1:
            c.append(0.0)
        else:
            c.append(K[gi][gi + 1])
        if i == m - 1:
            b.append(P_tip)
        else:
            b.append(0.0)
    u_red = thomas_tridiag(a, d, c, b)
    u = [0.0]
    for k in range(m):
        u.append(u_red[k])
    return u


# ─── dump reference numbers for the parity test ──────────────────────
if __name__ == "__main__":
    # Sample 1: uniform mesh, N=4 elements, length 1 m, steel-like
    nodes_S1 = [0.0, 0.25, 0.5, 0.75, 1.0]
    E_S1 = 200.0e9     # Young's modulus (Pa)
    A_S1 = 1.0e-4      # cross-section area (m²)
    P_S1 = 1000.0      # tip load (N)
    u_S1 = bar1d_solve_fixed_free(nodes_S1, E_S1, A_S1, P_S1)
    print("S1 u =", repr(u_S1))
    # closed-form: u(x) = P x / (E A)
    print("S1 analytic u =",
          [P_S1 * x / (E_S1 * A_S1) for x in nodes_S1])

    # Sample 2: NON-uniform mesh, N=4 elements
    nodes_S2 = [0.0, 0.10, 0.30, 0.60, 1.00]
    E_S2 = 70.0e9      # aluminum-like
    A_S2 = 2.5e-4
    P_S2 = 500.0
    u_S2 = bar1d_solve_fixed_free(nodes_S2, E_S2, A_S2, P_S2)
    print("S2 u =", repr(u_S2))
    print("S2 analytic u =",
          [P_S2 * x / (E_S2 * A_S2) for x in nodes_S2])

    # Sample 3: tiny problem N=2 (single element), used as inv check
    nodes_S3 = [0.0, 1.0]
    E_S3 = 1.0
    A_S3 = 1.0
    P_S3 = 1.0
    u_S3 = bar1d_solve_fixed_free(nodes_S3, E_S3, A_S3, P_S3)
    print("S3 u =", repr(u_S3))

    # Sample 4: larger uniform mesh, N=8 elements
    n_el = 8
    nodes_S4 = [i / n_el for i in range(n_el + 1)]
    E_S4 = 200.0e9
    A_S4 = 1.0e-4
    P_S4 = 1000.0
    u_S4 = bar1d_solve_fixed_free(nodes_S4, E_S4, A_S4, P_S4)
    print("S4 u =", repr(u_S4))

    # Element stiffness primitive dump
    print("k(E=1, A=1, L=1) =", bar1d_element_stiffness(1.0, 1.0, 1.0))
    print("k(E=2e11, A=1e-4, L=0.25) =",
          bar1d_element_stiffness(200.0e9, 1.0e-4, 0.25))
