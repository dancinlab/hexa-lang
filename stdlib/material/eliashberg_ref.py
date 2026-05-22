#!/usr/bin/env python3
# Python reference for sim.hexa eliashberg_moments — trapezoidal α²F→(λ,ω_log,ω₂).
# Operation order matches the hexa loop verbatim for bit-level parity.
import math

def eliashberg_moments(a2f, omega):
    n = len(a2f)
    if n < 2:
        return (0.0, 0.0, 0.0)
    int_lam = 0.0; int_log = 0.0; int_w2 = 0.0
    i = 0
    while i < n - 1:
        w0 = omega[i]; w1 = omega[i + 1]
        if w0 > 0.0 and w1 > 0.0:
            dw = w1 - w0
            f0 = a2f[i];   f1 = a2f[i + 1]
            if f0 < 0.0: f0 = 0.0
            if f1 < 0.0: f1 = 0.0
            int_lam = int_lam + 0.5 * (f0 / w0 + f1 / w1) * dw
            int_log = int_log + 0.5 * (f0 * math.log(w0) / w0 + f1 * math.log(w1) / w1) * dw
            int_w2  = int_w2  + 0.5 * (f0 * w0 + f1 * w1) * dw
        i = i + 1
    lam = 2.0 * int_lam
    if lam <= 1.0e-12:
        return (lam, 0.0, 0.0)
    omega_log = math.exp((2.0 / lam) * int_log)
    w2sq = (2.0 / lam) * int_w2
    omega2 = math.sqrt(w2sq if w2sq > 0.0 else 0.0)
    return (lam, omega_log, omega2)

def fmt12(x):
    neg = x < 0.0
    v = -x if neg else x
    ip = int(v)            # truncate toward zero (positive)
    frac = v - ip
    s = ""
    for _ in range(12):
        frac = frac * 10.0
        d = int(frac)
        s += str(d)
        frac = frac - d
    return ("-" if neg else "") + str(ip) + "." + s

CASES = [
    ("T1_uniform_peak",
     [0.0,0.1,0.3,0.6,1.0,0.6,0.3,0.1,0.05,0.0],
     [10.0,20.0,30.0,40.0,50.0,60.0,70.0,80.0,90.0,100.0]),
    ("T2_constant",
     [0.5,0.5,0.5,0.5,0.5],
     [1.0,2.0,3.0,4.0,5.0]),
    ("T3_nonuniform_clamp",
     [-0.02,0.4,0.8,0.3,-0.01],
     [5.0,12.0,25.0,40.0,80.0]),
]
for name, a2f, omega in CASES:
    lam, wlog, w2 = eliashberg_moments(a2f, omega)
    print(name + " lam=" + fmt12(lam) + " wlog=" + fmt12(wlog) + " w2=" + fmt12(w2))
