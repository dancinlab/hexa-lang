# stdlib/kernels/autodiff/dual_oracle.py — D80 pilot #11 parity companion
#
# Line-by-line Python `math` libm transliteration of
# stdlib/kernels/autodiff/dual_forward_kernel.hexa. Used to generate the
# bit-exact `want` literals embedded in dual_forward_kernel_test.hexa.
#
# CLEAN-ROOM: same provenance as the .hexa kernel — no JAX / PyTorch /
# Autograd / OpenMDAO source-code inspection. The dual-number forward-
# mode AD rules are the textbook chain rule (Griewank & Walther 2008
# §3.1). math.sin / math.cos / math.exp / math.log / math.sqrt
# delegate to the same darwin-arm64 libm as the hexa runtime's
# sin / cos / exp / log / sqrt, so the per-operation IEEE-754 result is
# identical and the composed Duals are bit-identical at rel_err = 0.

import math


def dual(v, dv):           return [v, dv]
def dual_const(v):         return [v, 0.0]
def dual_var(v):           return [v, 1.0]
def d_value(a):            return a[0]
def d_tangent(a):          return a[1]


def d_add(a, b): return [a[0] + b[0], a[1] + b[1]]
def d_sub(a, b): return [a[0] - b[0], a[1] - b[1]]
def d_mul(a, b): return [a[0] * b[0], a[1] * b[0] + a[0] * b[1]]


def d_div(a, b):
    v = a[0] / b[0]
    dv = (a[1] * b[0] - a[0] * b[1]) / (b[0] * b[0])
    return [v, dv]


def d_neg(a):              return [0.0 - a[0], 0.0 - a[1]]
def d_sin(a):              return [math.sin(a[0]), math.cos(a[0]) * a[1]]
def d_cos(a):              return [math.cos(a[0]), (0.0 - math.sin(a[0])) * a[1]]


def d_exp(a):
    e_v = math.exp(a[0])
    return [e_v, e_v * a[1]]


def d_log(a):              return [math.log(a[0]), a[1] / a[0]]


def d_sqrt(a):
    s = math.sqrt(a[0])
    return [s, a[1] / (2.0 * s)]


def d_pow_int(a, n):
    if n == 0:
        return [1.0, 0.0]
    u, du = a[0], a[1]
    if n > 0:
        un_minus_1 = 1.0
        for _ in range(n - 1):
            un_minus_1 = un_minus_1 * u
        un = un_minus_1 * u
        return [un, float(n) * un_minus_1 * du]
    m = -n
    um_plus_1 = 1.0
    for _ in range(m + 1):
        um_plus_1 = um_plus_1 * u
    un = u / um_plus_1
    un_minus_1 = 1.0 / um_plus_1
    return [un, float(n) * un_minus_1 * du]


# ────────────────────────────────────────────────────────────────────
# Captured oracle dump — these are the `want` literals in the .hexa
# parity test. The reference points are:
#
#   T1: f(x) = x²                  at x = 3
#       f'(x) = 2x                 → f=9,        f'=6
#   T2: f(x) = sin(x)·cos(x)       at x = π/4
#       f'(x) = cos²−sin² = cos(2x)→ f=0.5,      f'=0    (analytic)
#   T3: f(x) = exp(x)              at x = 1
#       f'(x) = exp(x)             → f=f'=e
#   T4: f(x) = (x²+1)/(x−1)        at x = 2
#       f'(x) = (x²−2x−1)/(x−1)²   → f=5,        f'=−1
#   T5: f(x) = √(1+x²)             at x = 3
#       f'(x) = x/√(1+x²)          → f=√10,      f'=3/√10
#   T6: f(x) = log(x²+1)           at x = 2
#       f'(x) = 2x/(x²+1)          → f=log(5),   f'=4/5
#   T7: f(x) = sin(x²)             at x = √(π/2)
#       f'(x) = 2x·cos(x²)         → f=1,        f'=0   (since cos(π/2)=0)
#   T8: f(x) = x³                  at x = 4
#       f'(x) = 3x²                → f=64,       f'=48
#   T9: f(x) = 1/x  (=x^(-1))      at x = 0.5
#       f'(x) = −1/x²              → f=2,        f'=−4
#
# Plus invariants:
#   I1: d_value(dual_const(c))    == c,   d_tangent == 0
#   I2: d_value(dual_var(x))      == x,   d_tangent == 1
#   I3: d_neg + d_add identity:   d_add(a, d_neg(a)) == [0, 0]
# ────────────────────────────────────────────────────────────────────


def f_t1(x):                              # x²
    return d_pow_int(dual_var(x), 2)


def f_t2(x):                              # sin(x)·cos(x)
    xv = dual_var(x)
    return d_mul(d_sin(xv), d_cos(xv))


def f_t3(x):                              # exp(x)
    return d_exp(dual_var(x))


def f_t4(x):                              # (x²+1)/(x−1)
    xv = dual_var(x)
    num = d_add(d_pow_int(xv, 2), dual_const(1.0))
    den = d_sub(xv, dual_const(1.0))
    return d_div(num, den)


def f_t5(x):                              # √(1+x²)
    xv = dual_var(x)
    return d_sqrt(d_add(dual_const(1.0), d_pow_int(xv, 2)))


def f_t6(x):                              # log(x²+1)
    xv = dual_var(x)
    return d_log(d_add(d_pow_int(xv, 2), dual_const(1.0)))


def f_t7(x):                              # sin(x²)
    xv = dual_var(x)
    return d_sin(d_pow_int(xv, 2))


def f_t8(x):                              # x³
    return d_pow_int(dual_var(x), 3)


def f_t9(x):                              # 1/x
    return d_pow_int(dual_var(x), -1)


if __name__ == "__main__":
    cases = [
        ("T1 x²            @ x=3",                 f_t1(3.0),                 (9.0,  6.0)),
        ("T2 sin·cos       @ x=π/4",               f_t2(math.pi / 4.0),       (0.5,  0.0)),
        ("T3 exp           @ x=1",                 f_t3(1.0),                 (math.e, math.e)),
        ("T4 (x²+1)/(x−1)  @ x=2",                 f_t4(2.0),                 (5.0, -1.0)),
        ("T5 √(1+x²)       @ x=3",                 f_t5(3.0),                 (math.sqrt(10.0), 3.0 / math.sqrt(10.0))),
        ("T6 log(x²+1)     @ x=2",                 f_t6(2.0),                 (math.log(5.0), 4.0 / 5.0)),
        ("T7 sin(x²)       @ x=√(π/2)",            f_t7(math.sqrt(math.pi / 2.0)), (1.0, 0.0)),
        ("T8 x³            @ x=4",                 f_t8(4.0),                 (64.0, 48.0)),
        ("T9 1/x           @ x=0.5",               f_t9(0.5),                 (2.0, -4.0)),
    ]
    print(f"{'case':40s} | {'got_value':>22s} {'got_tangent':>22s} | {'want_value':>22s} {'want_tangent':>22s}")
    print("-" * 140)
    for name, got, want in cases:
        print(f"{name:40s} | {got[0]:22.17e} {got[1]:22.17e} | {want[0]:22.17e} {want[1]:22.17e}")
