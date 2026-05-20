# incoming note: neural-kernel-hexa-native-lif-port-target — `kernels/neural/lif_kernel.py` is a `.py` substrate; hexa-native LIF integrator is the future porting target

> **id**: `neural-kernel-hexa-native-lif-port-target` · **opened**: 2026-05-20 KST · **status**: `resolved-ssot — hexa-native lif_kernel.hexa landed 2026-05-20 commit 299db935 (D80 g_hexa_only pilot #3); .py substrate retained as ①a brian2 spawn target until ①b adapter re-points (follow-on)`
> **trees**: `stdlib/kernels/neural/lif_kernel.py` (①a kernel — `.py` substrate, retained) · `stdlib/kernels/neural/lif_kernel.hexa` (①a kernel — **hexa-native, LANDED**) · `stdlib/brain/lif_brian2.py` (①b adapter — unchanged spawn path, re-point pending)
> **source**: demiurge D72 2-layer STDLIB restructure — last two kernels (`plasma`, `neural`) extracted to `stdlib/kernels/`.
> **severity**: low — no functional blocker; flagged for first-principle (hexa-first) compliance.

---

## PROGRESS 2026-05-20 (port-target marker — survey cycle)

**hexa-native LIF integrator LANDED** on origin/main as commit `299db935`
("feat(stdlib/kernels/neural): D80 g_hexa_only pilot #3 — LIF analytic
exact-update integrator (no brian2)") — third sample in the demiurge
D80 `g_hexa_only` ultimate-form pilot, after `solar_kernel` (`122620de`)
and `mc_transport` (`dd3dad19`).

Files landed at `stdlib/kernels/neural/`:
- `lif_kernel.hexa` (229 LoC) — clean-room hexa-native kernel exposing
  `v_step` / `v_step_general` / `decay_factor` / `isi_period` /
  `firing_rate` / `simulate`. No brian2 call; analytic exact per-step
  update v(t+dt) = I + (v(t) - I) · exp(-dt/τ) (same closed form
  brian2 `method='exact'` applies — Stein 1965, Tuckwell 1988 vol.1
  ch.3).
- `lif_kernel_test.hexa` (201 LoC) — 23 assertions across 6 reference
  samples vs numpy 2.x analytic update; 23/23 PASS; per-sample relative
  errors ≤ 2e-15 (machine epsilon, ~5e9× tighter than the D80 1e-6
  ceiling — both sides apply identical IEEE 754 `exp` so residual is
  libm rounding, not algorithmic divergence).
- `README.md` — points at the new hexa-native kernel.

**HONESTY (g3 — scope unchanged)**:
- Substrate parity proves the PORT PATTERN scales to a third sample. It
  does NOT flip `absorbed=true` at the demiurge record layer — that
  gate stays on (a) the demiurge-side `HexaNativeParityRef` schema
  update and (b) a measured patch-clamp oracle (Sim4Life MDDT / Allen
  Brain Atlas).
- LIF model is a textbook abstraction; no biological neuron absorbed.
  Same stance as `lif_brian2.py` §HONESTY.
- `.py` substrate **RETAINED** (still on disk + tracked) because the
  `stdlib/brain/lif_brian2.py` adapter still spawns it via the
  Producer ABI. Re-pointing the adapter at the hexa-native kernel is a
  follow-on milestone gated on the producer spawn ABI redesign (JSON
  I/O hexa-native side).
- **g_stdlib_ownership** preserved: kernel SSOT lives in
  `hexa-lang/stdlib/kernels/neural/`. demiurge points, does not copy.

**Follow-on (NOT in this cycle)**: producer spawn ABI redesign →
re-point `lif_brian2.py` adapter at `lif_kernel.hexa` → mark D72
neural-kernel `.py` substrate flag CLOSED at the demiurge record
layer.

cross-ref: commit `299db935` · sibling pilot samples
`122620de` (solar) + `dd3dad19` (mc_transport) · related note
`inbox/notes/2026-05-20-d80-lif-kernel-hexa-native-port-landed.md`
(closure record) · `inbox/notes/hexa-native-port-pattern-pilot.md`
(pilot pattern catalog).

---

## 1. Observed

The D72 restructure extracted the `neural` kernel into
`stdlib/kernels/neural/lif_kernel.py`. Unlike the `plasma` kernel
(`stdlib/kernels/plasma/plasma_metrics.hexa` — hexa-native), the
`neural` kernel is a **`.py` substrate**: it wraps brian2 2.6.0, an
EXTERNAL Python library, as the LIF ODE integrator.

The sibling kernels split the same way by upstream nature:
`kernels/graph/`, `kernels/fem/`, `kernels/mc_transport/` are `.py`
(wrap networkx / scikit-fem / particle); `kernels/circuit/`,
`kernels/noc_sim/`, `kernels/logic_synth/`, `kernels/plasma/` are
hexa-native `.hexa`.

## 2. Why it is a porting target (wilson principle #2 — hexa-first)

The LIF model is a single linear ODE:

```
dv/dt = (I - v) / tau          v_thr = 1, v_reset = 0
```

with an analytic **exact** per-timestep solution
(`v(t+dt) = I + (v(t) - I) * exp(-dt/tau)`). It is small,
well-bounded, and has zero integration error in closed form — a
natural candidate for a clean-room `.hexa` kernel, mirroring
`kernels/plasma/plasma_metrics.hexa`.

## 3. Resolution path

When a hexa-native `lif.hexa` kernel lands and passes a parity round
against this brian2 substrate (firing rate / ISI / CV byte-stable for
the textbook tonic-drive scenario), `absorbed=true` flips HERE in the
kernel — once — instead of in the `stdlib/brain/` adapter. Until then
`kernels/neural/lif_kernel.py` is the honest substrate and
`absorbed = false` ALWAYS at the record layer.

This is the same Stage-2 → Stage-4 ladder `plasma_metrics.hexa`
already walks (ABSORPTION.md §"hexa 포팅 단계"). The note is also
recorded in `stdlib/kernels/neural/README.md` §"`.py` SUBSTRATE".
