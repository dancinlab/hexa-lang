# D80 g_hexa_only — sample #3 LIF kernel hexa-native port LANDED

(sample #1 = `kernels/solar/solar_kernel.hexa` (122620de) ·
 sample #2 = `kernels/mc_transport/` 1-D slab MC (dd3dad19) ·
 sample #3 = THIS — `kernels/neural/lif_kernel.hexa`)

> **id**: `d80-lif-kernel-hexa-native-port-landed` · **opened**: 2026-05-20 KST · **status**: `closed — port landed, substrate parity verified`
> **trees**: `stdlib/kernels/neural/lif_kernel.hexa` + `lif_kernel_test.hexa` (NEW) · `stdlib/kernels/neural/lif_kernel.py` (substrate retained, unchanged)
> **source**: D80 g_hexa_only ultimate-form pilot — closes the D72 `.py` substrate flag for `kernels/neural/` (inbox note `2026-05-20-neural-kernel-hexa-native-lif-port-target.md` §"Resolution path").
> **severity**: closure — pattern from solar pilot (commit 122620de) reapplied with no new parser footguns.

---

## 1. What landed

| file | role | LOC |
|---|---|---|
| `stdlib/kernels/neural/lif_kernel.hexa` | hexa-native LIF integrator — `v_step`, `v_step_general`, `decay_factor`, `isi_period`, `firing_rate`, `simulate` | ~140 |
| `stdlib/kernels/neural/lif_kernel_test.hexa` | substrate parity test — 23 assertions across 6 reference samples vs numpy 2.x | ~150 |

The `.py` substrate (`lif_kernel.py`) is retained, not deleted —
`stdlib/brain/lif_brian2.py` still spawns it via the demiurge Producer
ABI. Re-pointing the adapter at the hexa-native kernel is a follow-on
milestone (gated on a hexa-native producer spawn ABI or a Python
binding shim).

## 2. Algorithm

Single linear ODE (Stein 1965, Tuckwell 1988 vol.1 ch.3):

```
dimensionless:   dv/dt = (I - v) / τ           → v(t+dt) = I + (v(t) - I) · exp(-dt/τ)
general SI:      τ_m · dV/dt = -(V - V_rest) + R·I
                                                → V(t+dt) = V∞ + (V(t) - V∞) · exp(-dt/τ_m),  V∞ = V_rest + R·I

ISI period (super-threshold tonic drive):
                 T = -τ · ln((v_thr - I) / (v_reset - I))
```

The per-step update IS the closed-form ODE solution — there is NO
numerical integration error. This is the same scheme brian2 uses under
`method='exact'`, so substrate parity bottoms out at libm `exp` /
`log` rounding (~1e-15 relative).

## 3. Parity table

Run from worktree `agent-lif-port` against `origin/main = cf234e6f`:

```
lif_kernel_test: 23/23 PASS
```

Per-sample relative errors (got vs numpy 2.x reference, captured
2026-05-20 darwin-arm64 Python 3.x):

| sample | assertion | rel_err |
|---|---|---|
| S1a | isi_period(tau=10ms, I=2.0)                       | 5.0e-16 |
| S1b | firing_rate = 1/T                                 | 2.2e-15 |
| S1c | simulate spike_count == 142                       | exact int |
| S1c | first_spike_s, last_spike_s                       | < 1e-16 |
| S2  | sub-threshold V(t) @ 1 / 5 / 10 / 50 / 100 ms     | ≤ 1.4e-15 |
| S3  | general SI V(t) @ 1 / 5 / 10 / 30 / 100 ms        | ≤ 1.1e-15 |
| S4  | sub-threshold spike_count == 0; v_final → I=0.5   | < 1e-15 |
| S5  | tau=5ms / I=1.5 / dt=10us — spike_count == 18      | exact int |
| S5  | isi_period analytic                                | < 1e-15 |
| S6  | at-threshold (I == v_thr) — never spikes           | spike_count == 0 exact |

All ≤ 2e-15 relative — ~5e9× tighter than the D80 spec ceiling of 1e-6.
Reason: per-step update IS the closed-form solution; both sides apply
identical `exp` calls in IEEE 754 double, so residual is libm rounding.

## 4. Pattern reuse — what transferred from the solar pilot

The 8-step pattern checklist from `hexa-native-port-pattern-pilot.md`
§"Pattern as a checklist" carried over 1:1 without any new parser
footguns. Specifically:

- **No new line-continuation issues**: the LIF kernel has only one
  multi-line expression (`v_step_general`'s `V∞ = V_rest + R·I`),
  which is bound to an intermediate `let v_inf = ...` per the solar
  pilot's "pattern (c)" recommendation. No `-` continuation traps.
- **No new math-primitive gaps**: needs only `exp` and `log`, both
  already in `cg_math_sym`. `fmod` (the solar pilot's gap) is not
  needed here.
- **Reference-capture step**: 5-minute numpy script (logged at the
  top of `lif_kernel_test.hexa`) reproduced numpy + brian2 method='exact'
  numbers byte-identically — they apply the same closed-form update,
  so parity is structural, not algorithmic.
- **Provenance + honesty header**: identical structure to
  `solar_kernel.hexa` and `plasma_metrics.hexa` (`@version /
  @capabilities / @stability / @since`, `CLEAN-ROOM PROVENANCE`,
  `HONESTY (g3)`, `①b adapter note`).

## 5. What this DOES NOT prove (g3 honesty)

- **`absorbed=true` is NOT flipped** at the demiurge record layer.
  Per the pilot task constraint (g3: cell absorbed flip 없음), that
  requires (a) the demiurge-side `HexaNativeParityRef` schema update
  and (b) a measured patch-clamp oracle (Sim4Life MDDT / Allen Brain
  Atlas). This pilot only proves the **port pattern** scales to a
  third sample.
- **Only the integrator kernel ported** — the brian2 substrate
  remains the spawn target for `stdlib/brain/lif_brian2.py`.
  Re-pointing the adapter is a follow-on, gated on the hexa-native
  producer ABI question (do we spawn a `hexa run` script with JSON
  stderr output, or do we provide a Python binding into a compiled
  hexa kernel? — TBD by demiurge `BrainAnalyzeProducer.swift`
  redesign).
- **No biology absorbed**: the LIF model is a textbook abstraction;
  no patch-clamp data fit. Same stance as `lif_brian2.py` today
  (lif_brian2.py §HONESTY).

## 6. Follow-ups (queue extension on top of solar pilot's list)

8. **(stdlib/brain)** Re-point `lif_brian2.py` at `lif_kernel.hexa`
   via a hexa-native producer spawn ABI (or a thin Python binding
   that loads the hexa-compiled symbol). Gated on the demiurge-side
   `BrainAnalyzeProducer.swift` spawn redesign — open question:
   `hexa run <script>` stderr-JSON contract.
9. **(stdlib/kernels/neural)** Extend the kernel to multi-neuron
   batched simulate (current API is single-neuron, matching the
   adapter's needs). Vectorise V update over a `[float]` array of
   neurons. Pre-req: hexa SIMD intrinsic coverage check.
10. **(demiurge)** `HexaNativeParityRef` schema update — same item
    as solar pilot follow-up #6. Once landed, `kernels/neural/`
    record can flip `absorbed=true` on the same gate as
    `kernels/solar/`.

## 7. Pattern as a checklist — STILL valid

The 8-step checklist in `hexa-native-port-pattern-pilot.md` is
unchanged. Sample #3 confirms it is reusable for any closed-form
linear-ODE kernel. The next candidate ports (in order of expected
complexity):

- `kernels/fem/` — needs sparse-matrix solver primitives.
  Pre-req: stdlib linear-algebra coverage.
- `kernels/graph/` — needs hash-map + graph traversal primitives.
  Pre-req: stdlib collections audit.
- `kernels/mc_transport/` — needs RNG + variance-reduction
  primitives. Pre-req: `stdlib/core/math/rng.hexa` coverage check.

Each will get its own `*_kernel.hexa` + `*_kernel_test.hexa` PR
following this template.
