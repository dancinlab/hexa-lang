#!/usr/bin/env python3
"""CPU-side cnn2snn quantize emulator.

Replaces BrainChip Meta TF (akida + quantizeml + cnn2snn) when neither the
package nor the AKD1000 device is available. Provides:

  - quantize_uint8(arr): emulates 8-bit uniform quantization (Akida native dtype)
  - convert_phi_calc(fn): wraps a Phi calculator to apply uint8 round-trip
  - SubstrateMarker: every emulator-derived value carries this so honesty
    barrier (F-C) can detect non-promotion-eligible evidence.

Usage from F-M3b/M4 harnesses:
    from cnn2snn_emulator import EmulatedAkida
    em = EmulatedAkida()
    em.predict(x)              # quantize → forward → dequantize
    em.substrate == "cpu_emulator_cnn2snn_stub"   # honesty marker
"""
from __future__ import annotations
import json, hashlib, time

import numpy as np


SUBSTRATE_MARKER = "cpu_emulator_cnn2snn_stub"


def quantize_uint8(arr: "np.ndarray", scale: float | None = None) -> tuple["np.ndarray", float]:
    a = np.asarray(arr, dtype=np.float32)
    if scale is None:
        amax = float(np.max(np.abs(a))) or 1.0
        scale = amax / 127.0
    q = np.clip(np.round(a / scale), -127, 127).astype(np.int8)
    return q, scale


def dequantize(q: "np.ndarray", scale: float) -> "np.ndarray":
    return (q.astype(np.float32) * scale)


class EmulatedAkida:
    """Minimal stand-in for akida.Model when SDK absent.

    Honesty contract:
      - substrate is always SUBSTRATE_MARKER
      - hardware_present() is always False
      - predict() applies uint8 round-trip to mimic AKD1000 quantization loss
      - record() collects per-call quantization residuals so F-M3b consumers
        can decide whether emulator behaves enough like AKD1000 for plausibility
    """

    substrate = SUBSTRATE_MARKER

    def __init__(self, weights: "np.ndarray | None" = None, seed: int = 0):
        rng = np.random.default_rng(seed)
        self._w = weights if weights is not None else rng.normal(0, 0.1, size=(64, 64)).astype(np.float32)
        self._wq, self._w_scale = quantize_uint8(self._w)
        self._calls: list[dict] = []

    def hardware_present(self) -> bool:
        return False

    def predict(self, x: "np.ndarray") -> "np.ndarray":
        xq, x_scale = quantize_uint8(x)
        x_dq = dequantize(xq, x_scale)
        w_dq = dequantize(self._wq, self._w_scale)
        flat = x_dq.reshape(-1).astype(np.float32)
        if flat.size != w_dq.shape[0]:
            wsz = w_dq.shape[0]
            if flat.size > wsz:
                flat = flat[:wsz]
            else:
                flat = np.pad(flat, (0, wsz - flat.size))
        out = (w_dq @ flat).astype(np.float32)
        residual = float(np.linalg.norm(x.reshape(-1)[:flat.size] - flat))
        self._calls.append({"x_scale": x_scale, "residual": residual})
        return out

    def report(self) -> dict:
        return {
            "substrate": self.substrate,
            "hardware_present": False,
            "calls": len(self._calls),
            "mean_residual": float(np.mean([c["residual"] for c in self._calls])) if self._calls else None,
            "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "weight_hash": hashlib.sha256(self._w.tobytes()).hexdigest()[:16],
        }


if __name__ == "__main__":
    em = EmulatedAkida()
    rng = np.random.default_rng(0)
    for _ in range(10):
        em.predict(rng.normal(size=(8, 8)))
    print(json.dumps(em.report(), indent=2))
