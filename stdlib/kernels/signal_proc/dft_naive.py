# stdlib/kernels/signal_proc/dft_naive.py — D80 g_hexa_only pilot
# companion oracle for `dft_naive.hexa`.
#
# This is the `math`-only Python mirror of the hexa-native naive DFT.
# Same algorithm, same float ops, same convention: forward DFT uses
# exp(-2πi·k·n/N), inverse DFT uses exp(+2πi·k·n/N) and divides by N.
#
# Importantly, this file does NOT import numpy. The whole point of
# the parity test is that the substrate is the textbook closed-form
# sum, and we can run it without any third-party dep. The day a
# hexa-native FFT lands, the same companion can grow a tiny FFT mirror
# for the bigger-N substrate; for now naive O(N²) is the contract.
#
# Cross-checked against numpy.fft.fft on a separate scratch run
# (2026-05-20): identical to ~1e-15 relative for N ≤ 16 random real
# inputs. That cross-check is informational only; the parity test
# `dft_naive_test.hexa` does not depend on numpy.
#
# HONESTY (g3): The DFT IS the definition. No measurement. The
# kernel-level `absorbed=false` discipline applies regardless.

import math


def dft_naive(x):
    """Naive O(N²) discrete Fourier transform of a real input.

    Args:
        x — sequence of floats, length N.

    Returns (xr, xi) — two length-N lists, real and imaginary parts
    of X[k] = Σ_n x[n]·exp(-2πi·k·n/N).
    """
    n = len(x)
    two_pi = 2.0 * math.pi
    n_f = float(n)
    xr = []
    xi = []
    for k in range(n):
        k_f = float(k)
        acc_r = 0.0
        acc_i = 0.0
        for nn in range(n):
            theta = -two_pi * k_f * float(nn) / n_f
            acc_r += x[nn] * math.cos(theta)
            acc_i += x[nn] * math.sin(theta)
        xr.append(acc_r)
        xi.append(acc_i)
    return xr, xi


def idft_naive(xr, xi):
    """Naive O(N²) inverse DFT.

    Args:
        xr, xi — two parallel length-N lists, real and imaginary parts.

    Returns (yr, yi) — time-domain signal. For a real-input forward
    DFT, yi is ~0 (machine epsilon).
    """
    n = len(xr)
    if len(xi) != n:
        raise ValueError("xr and xi must be same length")
    two_pi = 2.0 * math.pi
    n_f = float(n)
    yr = []
    yi = []
    for nn in range(n):
        n_f2 = float(nn)
        acc_r = 0.0
        acc_i = 0.0
        for k in range(n):
            k_f = float(k)
            theta = two_pi * k_f * n_f2 / n_f
            c = math.cos(theta)
            s = math.sin(theta)
            acc_r += xr[k] * c - xi[k] * s
            acc_i += xr[k] * s + xi[k] * c
        yr.append(acc_r / n_f)
        yi.append(acc_i / n_f)
    return yr, yi


def magnitude(xr, xi):
    """Per-bin |X[k]| = sqrt(Xr² + Xi²)."""
    return [math.sqrt(r * r + i * i) for r, i in zip(xr, xi)]


def power(xr, xi):
    """Per-bin |X[k]|² (no window / no scale)."""
    return [r * r + i * i for r, i in zip(xr, xi)]


if __name__ == "__main__":
    # Smoke: real cosine at bin 1 in an N=8 frame has all energy at
    # k=1 and k=7 (N-k mirror).
    x = [math.cos(2.0 * math.pi * 1.0 * n / 8.0) for n in range(8)]
    xr, xi = dft_naive(x)
    mag = magnitude(xr, xi)
    print(f"N=8 cos(1·t) magnitudes:")
    for k, m in enumerate(mag):
        print(f"  k={k}  |X|={m:.6f}")
    # Round-trip
    yr, yi = idft_naive(xr, xi)
    err = max(abs(yr[n] - x[n]) for n in range(8))
    print(f"round-trip max |yr - x| = {err:.3e}  (expect <1e-14)")
