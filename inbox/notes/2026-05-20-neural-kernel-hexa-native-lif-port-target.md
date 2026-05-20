# incoming note: neural-kernel-hexa-native-lif-port-target — `kernels/neural/lif_kernel.py` is a `.py` substrate; hexa-native LIF integrator is the future porting target

> **id**: `neural-kernel-hexa-native-lif-port-target` · **opened**: 2026-05-20 KST · **status**: `open — future porting target (no blocker; D72 structural extraction complete)`
> **trees**: `stdlib/kernels/neural/lif_kernel.py` (①a kernel — `.py` substrate) · `stdlib/brain/lif_brian2.py` (①b adapter — unchanged spawn path)
> **source**: demiurge D72 2-layer STDLIB restructure — last two kernels (`plasma`, `neural`) extracted to `stdlib/kernels/`.
> **severity**: low — no functional blocker; flagged for first-principle (hexa-first) compliance.

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
