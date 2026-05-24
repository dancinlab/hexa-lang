# kernels/autodiff/ — ①a Automatic-differentiation kernel (demiurge D72)

Domain-agnostic forward-mode AD kernel. **NEW kernel folder added by
D80 pilot #11** — the smallest cited slice of the (multi-month) autodiff
stack that `stdlib/scope/openmdao_sizing.py` (MDAO) and any future
gradient-based optimiser ①b adapter will eventually need.

| file | role |
|---|---|
| `dual_forward_kernel.hexa` | dual-number forward-mode AD primitives — `dual_var` / `dual_const` / arithmetic / sin / cos / exp / log / sqrt / pow_int. Given a function composed of these primitives and a seed `dual_var(x_0)`, returns `[f(x_0), f'(x_0)]` in one forward pass. |
| `dual_forward_kernel_test.hexa` | substrate parity test — 48 assertions across 9 functions × 2 oracle tiers (analytic closed-form + Python `math` libm bit-exact) + 3 invariants + 1 chain-rule cross-check + 1 linearity invariant. |
| `dual_oracle.py` | `math` libm transliteration of the kernel — used to dump captured `want` literals embedded in the test. No third-party Python deps. |

## 2-layer (ABSORPTION.md ①)

- **①a kernel** (here) — domain-independent. No spacecraft mass model,
  no PSF objective, no LCOE function — pure dual-number algebra.
- **①b adapter** — `stdlib/scope/openmdao_sizing.py` (MDAO; future).
  Owns the design-variable schema, the physical-units bookkeeping, and
  the optimiser loop; calls this kernel to evaluate `(f, ∇f)` at each
  optimiser iterate. Stays on the `.py` side until heavier AD primitives
  (reverse mode + vector seeds + a unified graph IR) land.

## API

- `dual_var(v) -> [float]` — Dual representing THE input variable
  (`dv = 1`). Canonical forward-mode seed.
- `dual_const(v) -> [float]` — Dual for a quantity that does NOT
  depend on the differentiation variable (`dv = 0`).
- `dual(v, dv) -> [float]` — explicit Dual constructor (escape hatch
  for advanced uses; not needed for the common case).
- `d_value(a) / d_tangent(a)` — accessors.
- Arithmetic: `d_add`, `d_sub`, `d_mul`, `d_div`, `d_neg`.
- Transcendentals: `d_sin`, `d_cos`, `d_exp`, `d_log`, `d_sqrt`.
- Power: `d_pow_int(a, n)` — integer-exponent power (polynomial-
  objective case; general real-exponent pow follows from
  `exp(p · log u)` and is a one-line caller composition).

## Algorithm provenance

Clean-room — no JAX / PyTorch / Autograd / OpenMDAO / Tapenade /
ADOL-C / CasADi source-code inspection. Dual-number forward-mode AD
(also called "tangent mode" or "operator-overloading AD") pre-dates
every modern AD library by decades:

- Wengert, R.E. (1964), "A simple automatic derivative evaluation
  program", Comm. ACM **7**(8), 463–464.
- Rall, L.B. (1981), *Automatic Differentiation: Techniques and
  Applications*, LNCS **120**, Springer-Verlag.
- Griewank, A. & Walther, A. (2008), *Evaluating Derivatives:
  Principles and Techniques of Algorithmic Differentiation*, 2nd
  edition, SIAM. §3.1 ("the tangent mode") is the spec we follow.

## Honesty (g3)

- **Forward mode only**. For an n-input gradient ∇f(x₁, …, xₙ) the
  caller seeds `dual_var(xᵢ)` (tangent 1) for one input and
  `dual_const(xⱼ)` (tangent 0) for the others, then runs the function
  n times. Reverse mode (one backward sweep = full gradient) is a
  follow-on pilot.
- **Scalar-in / scalar-out** in this iteration. Vector-mode (multiple
  seeds at once → directional derivatives in one pass) is mechanical
  but expands the Dual representation; queued.
- **No control-flow capture**. `if x > 0 { ... } else { ... }` returns
  whichever branch the caller's float comparison picks — no
  subdifferentials, no smoothing.
- **Integer pow only** in `d_pow_int`. Real-exponent pow is one line
  of `d_exp(d_mul(p, d_log(u)))` at the call site.
- **`absorbed = false`** at the record layer (D80 g_hexa_only) — this
  is a NEW domain in `demiurge:domains/DEPENDENCIES.demi`; the flip
  happens at the cell level when an optimiser uses this kernel, not
  in the kernel itself.

## Parity (pilot #11, 2026-05-20)

48/48 PASS at the D80 tolerance ceiling (1e-10 rel):

- **Analytic tier** — 9 elementary functions × `(f, f')` matched
  against textbook closed-form derivatives, absolute residual ≤ 1e-13
  (most ≤ 1e-15; cos²−sin² at π/4 has ~2.2e-16 abs residual, 2x·cos(x²)
  at √(π/2) has ~7e-16 abs residual; both well below the ceiling).
- **Companion tier** — 9 cases bit-identical at `rel_err = 0`
  (literal IEEE-754) against the Python `math` libm oracle
  (`dual_oracle.py`).
- **Invariants** — `dual_const`/`dual_var` constructors, `a + (-a) = 0`,
  `d_pow_int(x, 0) = [1, 0]`, `(sin x)²` via `d_mul(sin, sin)` ==
  via `d_pow_int(sin x, 2)`, linearity of `α·sin + β·cos`.

See `docs/notes/hexa-native-port-pattern-pilot.md` "Pilot #11" for
the full algorithm-choice rationale and lessons-learned.
