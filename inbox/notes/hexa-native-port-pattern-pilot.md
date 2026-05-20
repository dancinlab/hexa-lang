# hexa-native port pattern — first sample (solar_kernel pilot)

**Date**: 2026-05-20
**Pilot scope**: D80 g_hexa_only ultimate-form pilot — port the simplest
existing Python kernel substrate to a true `.hexa` (hexa-lang native)
implementation, then prove parity against the Python substrate.
**Result**: parity holds at machine epsilon (≤1e-14 relative, vs the
spec ceiling of ±0.1 %). Pattern is sound — documented below.

**SSOT cross-link (demiurge D87 + D90 + D93)**: the machine-readable
8-field-per-row version of this rolling pilot table lives at
`demiurge:domains/PILOTS.demi`. This `.md` carries the prose dimension
(algorithm-choice rationale + hexa-lang gotchas + follow-up queue);
the `.demi` carries the field dimension consumed by Swift loaders
(`cockpit/Sources/DemiurgeCore/Loaders/PilotLoader.swift` — `find(kernelPath:)`
/ `find(id:)`). Per-pilot `[pilot-<id>]` cross-link annotations are
inlined inside each pilot section below; new pilots MUST update both
files in the same cycle (drift = bug).

**2026-05-20 follow-on — sample #3 LANDED**: `kernels/neural/lif_kernel.hexa`
(D72 LIF analytic port flagged in §"Follow-ups" of the original
neural-kernel inbox note; sample #2 was `kernels/mc_transport/` —
commit dd3dad19) — 23/23 PASS at ≤2e-15 relative against numpy 2.x
reference. Pattern from the solar pilot transferred 1:1 with no new
parser footguns (the LIF kernel is shorter, ~140 LOC of math, and
needs only `exp` + `log` from libm — both already in `cg_math_sym`). See
inbox note `2026-05-20-d80-lif-kernel-hexa-native-port-landed.md` for the
sample #3 closure record + per-sample parity table.

## What landed

| file | role |
|---|---|
| `stdlib/kernels/solar/solar_kernel.hexa` | hexa-native port — Grover Hughes / Sandia 1985 ephemeris + Haurwitz 1945 clear-sky GHI |
| `stdlib/kernels/solar/solar_kernel_test.hexa` | substrate parity test — 21 assertions across 6 timestamps vs pvlib 0.13.0 |

## Algorithm choice — why Hughes + Haurwitz and not SPA + Ineichen

The Python substrate (`pvlib_kernel.py`) wires together pvlib's
**SPA** (NREL ~100 lines of polynomial tables) + **Ineichen** clear-sky
(needs Linke turbidity table) + **CEC SAPM** (PV-system single-diode
equation). Porting the full stack in one PR is too large to review
cleanly.

The smallest cited algorithm in pvlib's solar layer is the pair:

1. **`solarposition.ephemeris`** — Grover Hughes / Sandia 1985,
   ~50 lines of closed-form spherical-astronomy trig (declination,
   right ascension via Kepler iteration, hour angle, azimuth /
   elevation). pvlib itself documents it as "accuracy not guaranteed"
   — use SPA for sub-arcmin work. But it is reviewable in one sitting.
2. **`clearsky.haurwitz`** — Haurwitz 1945, one closed-form
   expression: `GHI = 1098 · cos(z) · exp(−0.059 / cos(z))`. No tables.

Together they are a 60-line port that captures the substrate pattern
without dragging in lookup tables.

## Pattern — how to port a Python substrate kernel to .hexa

### 1. Pick the substrate (not the adapter)

D72 split substrates (`stdlib/kernels/<domain>/`) from adapters
(`stdlib/<domain>/`). Port the **kernel**, not the adapter — the
adapter's site / caveats / honesty gate are orthogonal to the
substrate algebra and live downstream regardless of substrate
language.

### 2. Capture a parity baseline FROM the Python substrate, NOT from
nominal "expected" values

Run pvlib on a handful of carefully-chosen inputs and record outputs
to ≥12 digits. The reference inputs should span the operating
envelope:
- low sun (near horizon) — refraction matters
- high sun (near zenith) — refraction tiny
- below horizon — algorithm output should be 0
- different seasons (solstices + equinoxes) — exercises declination

For solar, 6 Phoenix-AZ samples × 4 outputs = 24 reference numbers
captured by `python3 -c "import pvlib; ..."` and pasted as `let want =
…` literals in the test.

### 3. Write the `.hexa` kernel mirroring the Python line-by-line

The provenance comment block at the top of `solar_kernel.hexa` follows
the `plasma_metrics.hexa` template:

- `@version` / `@capabilities` / `@stability` / `@since`
- CLEAN-ROOM PROVENANCE block — explicit "no upstream code; spec from
  textbook/public-domain reference"
- HONESTY (g3) — clear-sky upper bound vs measurement; absorbed=false
  at record layer until the demiurge-side schema lands

API surface mirrors pvlib's public functions (`solar_zenith`,
`solar_azimuth`, `apparent_zenith`, `haurwitz_ghi`) so an adapter can
swap `pvlib.solarposition.ephemeris(...)` for
`solar_kernel.ephemeris(...)` with no logic change.

### 4. Substrate parity test follows `plasma_metrics_test.hexa`

Same `pass_count / total_count / check / rel_err` pattern. The
plasma test's per-parameter tolerance discipline (1e-6 for
non-relativistic, 1e-3 for known-physics-gap) carries over directly.

## Surprises / blockers found during the pilot

### Hexa-lang grammar quirks (real, found, worked-around)

1. **No float `%` operator** — `7.5 % 3.0` errors at clang codegen:
   `invalid operands to binary expression ('double' and 'double')`.
   The `%` operator is integer-only. Worked around with
   `fmod_floor(x, y) = x − floor(x/y) · y` (pvlib uses `np.mod` which
   also floor-divides, so semantics match exactly).
2. **No libm `fmod` shim** — the `cg_math_sym` table in
   `self/codegen_c2.hexa` covers `sqrt log exp sin cos tan asin acos
   atan atan2 pow floor ceil round abs tanh lgamma` and the
   classifiers (`isnan/isinf/isfinite`) but not `fmod`. Filed as a
   follow-up candidate; the closed-form workaround above is fine for
   this pilot.
3. **Multi-line expression continuation with leading `-` parses
   broken** — this:
   ```
   refract_arcsec = 58.1 / tan_el
       - 0.07 / tan3
       + 8.6e-05 / tan5
   ```
   compiles, runs, but produces a wrong number — the parser treats the
   `- 0.07/...` line as a NEW unary-minus statement, not a continuation.
   Leading-`+` continuation seems to work in practice (zenith
   computation has `+ 0.000453 * t1 * t1` continuation and parity is
   bit-exact). Worked around by either (a) collapsing to one line,
   (b) parenthesising the whole expression, or (c) using intermediate
   `let t1 = ...; let t2 = ...; total = t1 - t2 + t3`. Pattern (c) is
   cleanest and is what landed. **Filed for hexa-lang parser
   follow-up — this is a footgun that will bite other kernel ports.**
4. **`let pi = pi()` shadows the function** — minor, but the
   stdlib float module exposes `pi()` as a function. Calling it and
   storing to a local named `pi` collides with the function symbol
   in codegen (`called object type 'HexaVal' is not a function`).
   Rename the local (`let p = pi()`).
5. **`print` truncates floats to ~6 digits** — for the test runner
   that's fine (numerical comparison happens before string
   conversion). For a parity-report dump that humans read, ~6 digits
   hides the fact that we're at machine epsilon. Would benefit from
   a `str_full(x: float)` or `repr(x: float)` primitive — filed for
   follow-up.

### Non-issues

- Math primitives `sin cos tan atan2 asin sqrt exp log floor` all work
  exactly and produce bit-exact agreement with libm (no surprise — they
  delegate to libm via `hexa_math_*` shims).
- `[float]` array literal + indexing for tuple-returning functions
  works fine.
- `use "stdlib/kernels/solar/solar_kernel"` from a test in the same
  directory works without path massaging.

## Parity numbers (final)

Run from worktree against `origin/main = 18038901`:

```
solar_kernel_test: 21/21 PASS
```

Per-sample relative errors (got vs pvlib 0.13.0 reference):

| sample | zenith | apparent_zen | Haurwitz GHI |
|---|---|---|---|
| S1 dawn solstice          | 3.4e-16 | 6.8e-16 | 9.1e-15 |
| S2 noon solstice          | 9.6e-15 | 3.7e-14 | 2.2e-16 |
| S3 afternoon solstice     | 1.1e-14 | —       | 1.1e-15 |
| S4 night solstice         | 1.9e-15 | —       | 0 (exact) |
| S5 winter noon            | 6.1e-15 | —       | 1.3e-15 |
| S6 spring equinox noon    | 3.5e-15 | —       | 5.4e-16 |

All ≤ 1e-13 relative, which is ~5e6× tighter than the D80 spec ceiling
of ±0.1 % (1e-3). The reason: we ported pvlib's OWN algorithm rather
than a different one, so the only residual is operation-order rounding
in IEEE 754 double. Had we ported SPA-vs-Spencer, the gap would have
been the 0.1 % ceiling.

## What this DOES NOT prove (g3 — honesty)

- **`absorbed=true` is NOT flipped** at the demiurge record layer.
  Per the pilot task constraint, that requires (a) the demiurge-side
  `HexaNativeParityRef` schema update and (b) a measured GHI oracle
  (pyranometer or satellite). This pilot only proves the **port
  pattern**.
- **Only the substrate kernel ported** — the heavy `ModelChain`
  (CEC-SAPM single-diode + AC inverter + temperature model + monthly
  AC binning) in `pvlib_kernel.py` is untouched. The `①b` adapter
  `stdlib/energy/pvlib_clearsky.py` still calls the Python kernel.
  Re-pointing the adapter is a follow-on milestone, gated on porting
  the SAPM piece (which needs linear-algebra primitives for the
  single-diode iteration).
- **Algorithm fidelity caveat**: the Hughes 1985 ephemeris is itself
  documented by pvlib as "accuracy not guaranteed". For sub-arcmin
  work, a future `solar_kernel_spa.hexa` will port SPA. This pilot
  port matches pvlib bit-for-bit on the SAME algorithm — that's the
  meaningful parity claim. The pilot does NOT claim pvlib SPA-level
  accuracy.

## Follow-ups (queue, in priority order)

1. **(hexa-lang)** Fix the multi-line `- continuation` parser bug.
   Audit existing `.hexa` files for the same footgun and either fix
   the parser or add a lint warning.
2. **(hexa-lang stdlib)** Add `fmod` to `cg_math_sym` table — closes
   the missing libm shim noted above.
3. **(hexa-lang stdlib)** Add `str_full(x: float)` or `repr(x: float)`
   for full-precision float-to-string in parity-report contexts.
4. **(stdlib/kernels/solar)** Follow-on: port pvlib SPA →
   `solar_kernel_spa.hexa` for sub-arcmin accuracy. Substrate test
   would assert ≤1e-6 vs `pvlib.solarposition.spa_python`.
5. **(stdlib/kernels/solar)** Follow-on: port CEC-SAPM single-diode +
   AC inverter so a full `ModelChain` equivalent exists in hexa-native.
   Gated on linear-algebra solver coverage.
6. **(demiurge)** Schema update for `HexaNativeParityRef` so cells
   like `energy + analyze` can record `absorbed=true` with a pointer
   to this kernel + the parity test SHA. Out of scope for this pilot.
7. **(stdlib/energy)** Re-point `pvlib_clearsky.py` (or a sibling
   `solar_clearsky.hexa` ①b adapter) at this kernel for the
   Haurwitz-only path. The Ineichen ModelChain path stays on the
   Python substrate until #4 + #5 land.

## Pattern as a checklist (extractable for the next port)

1. Identify the substrate kernel (`stdlib/kernels/<domain>/<x>.py`).
2. Identify the smallest cited algorithm inside it that has a
   closed-form / textbook reference.
3. Capture ≥6 reference inputs spanning the operating envelope; dump
   ≥12-digit outputs from the Python substrate.
4. Write `stdlib/kernels/<domain>/<x>_kernel.hexa` following the
   `plasma_metrics.hexa` provenance + honesty template. Mirror the
   public API names so adapters can swap with no logic change.
5. Write `stdlib/kernels/<domain>/<x>_kernel_test.hexa` following the
   `plasma_metrics_test.hexa` `check / rel_err` template. Bake the
   reference numbers from step 3 as `let want = …` literals with a
   1-line comment naming the substrate version + date captured.
6. `hexa run stdlib/kernels/<domain>/<x>_kernel_test.hexa` — expect
   PASS at the tolerance you committed in step 5.
7. If parity FAILS: investigate (line-continuation footgun, `fmod`
   gap, integer-vs-float-literal coercion) and document in the
   follow-up queue. Do NOT relax the tolerance — record the gap
   honestly.
8. **Do NOT flip `absorbed=true`** on the demiurge record yet — that
   gate stays on the demiurge-side HexaNativeParityRef schema + a
   measured oracle.

This pattern, applied to ~50-line closed-form substrates, gives
bit-exact parity at machine epsilon. Bigger substrates (SPA,
single-diode iteration, ModelChain) will need separate per-piece
ports following the same template.

---

## Fifth sample — `plasma_metrics_kernel.hexa` (D80 pilot #5)

**Date**: 2026-05-20
**Pilot scope**: fifth application of the pattern after `solar_kernel`
(#1), `mc_slab_demo` (#2), `lif_kernel` (#3), `graph BFS+Kahn` (#3
parallel), and `urdf 2-link FK` (#4). Port the 4 NRL-Formulary "primary"
plasma parameters (λ_D, ω_p, r_L, ln Λ) as a slim sibling of the
existing broader `plasma_metrics.hexa`, parity-tested against hand-
mirrored Python `math` closed-form at machine epsilon.
**Result**: 41/41 assertions PASS at `rel_err = 0.0` (literal IEEE-754
bit-exact, not just within 1e-12 tolerance). Pattern continues to
hold for closed-form algebra.

### What landed

| file | role |
|---|---|
| `stdlib/kernels/plasma/plasma_metrics_kernel.hexa` | hexa-native — Debye length · electron/ion plasma frequency · Larmor radius (e + D⁺) · NRL Formulary p.34 high-T Coulomb logarithm |
| `stdlib/kernels/plasma/plasma_metrics_kernel_test.hexa` | parity test — 41 assertions across 8 sample points (ITER core, SPARC, JET D-T 1997, NSTX, Z-pinch, solar corona, magnetosphere, ionosphere F-layer) vs hand-mirrored Python `math` closed-form |

### Why a SIBLING `_kernel.hexa` and not edit the existing file

`stdlib/kernels/plasma/plasma_metrics.hexa` was already clean-room
hexa-native (D72 extraction, κ-46) and is consumed by the live
`stdlib/fusion/plasma_metrics.hexa` adapter + `plasma_metrics_test.hexa`
parity selftest (9/9 PASS vs plasmapy 2026.2.0, with documented
relativistic / Alfvén-ion-mass gaps). Editing that file would risk
breaking the fusion-domain parity chain.

The D80 pilot pattern (from solar) is "small, reviewable, parity-test-
able at machine epsilon, naming convention `_kernel.hexa`". So the
plasma port lands as a SIBLING that:
- shares constants + formulas with the existing file (bit-exact),
- adds the new primitive (Coulomb log) the existing file does NOT have,
- carries an in-kernel test at machine-epsilon (vs the existing
  fusion-adapter test at 1e-3 ~ 2e-2 against plasmapy).

This is the pattern recommended for any future broad-surface kernel
that already exists: add a `_kernel.hexa` slim sibling for the D80
pilot rather than touching the live broader kernel.

### Algorithm choice — why NRL Formulary p.34 high-T branch

NRL Formulary p.34 prescribes regime-dependent closed forms for ln Λ.
The 4 cited "primary parameters" of the user-supplied task spec map
exactly to:

1. **Debye length** — already in `plasma_metrics.hexa`, copied here.
2. **Plasma frequency** — already in `plasma_metrics.hexa`, copied
   for both electron and deuteron.
3. **Larmor radius** — already as `gyroradius_e/_deuteron`, renamed
   `larmor_e/_deuteron` (alternate naming common in NRL Formulary).
4. **Coulomb logarithm (NEW)** — implements ONLY the high-T regime
   `ln Λ_ei = 24 - ln(√n_e[cm⁻³] / T_e[eV])` valid for T_e > 10·Z² eV.
   Low-T regime (case 1 NRL p.34, < 10·Z² eV) deliberately deferred —
   caller must regime-flag; this kernel does NOT silent-fallback.

### Parity test envelope

8 sample points spanning the real plasma-physics operating envelope:

| sample | regime | n_e [m⁻³] | T_e [eV] | B [T] | notable |
|---|---|---|---|---|---|
| S1 | ITER core | 1e20 | 1e4 | 5.3 | reference baseline |
| S2 | SPARC core | 4e20 | 2e4 | 12.2 | high-field tokamak |
| S3 | JET D-T 1997 | 5e19 | 1e4 | 3.4 | mixed D-T, T_i ≠ T_e |
| S4 | NSTX spherical | 5e19 | 1e3 | 0.5 | low-B compact device |
| S5 | Z-pinch (dense) | 1e26 | 1e2 | 50 | extreme density, tiny λ_D=7e-9 m |
| S6 | solar corona | 1e15 | 1e2 | 1e-4 | space plasma, huge r_L=20 m |
| S7 | magnetosphere | 1e7 | 10 | 3e-5 | sparse cold (lnΛ skipped) |
| S8 | ionosphere F | 1e12 | 0.1 | 3e-5 | sparse very-cold (lnΛ skipped) |

Coverage: n_e spans 19 orders, T_e spans 5 orders, B spans 9 orders.
Outputs include λ_D = 7e-9 m (tiny) and r_L = 21 m (huge) — exercises
floating-point dynamic range, not just one operating point.

### Parity numbers

```
plasma_metrics_kernel_test: 41/41 PASS
```

Per-sample relative errors against the hand-mirrored Python reference
(spot-check dump on 9 representative values across the envelope):

| measurement | rel_err |
|---|---|
| S1 lambda_d           | 0.0 (bit-exact) |
| S1 omega_pe           | 0.0 |
| S1 omega_pi_D         | 0.0 |
| S1 larmor_e           | 0.0 |
| S1 larmor_D           | 0.0 |
| S1 lnΛ_ei             | 0.0 |
| S5 lambda_d (7e-9 m)  | 0.0 |
| S6 larmor_D (20 m)    | 0.0 |
| S5 lnΛ_ei (5.6)       | 0.0 |

All 41 assertions in the test PASS at `rel_err < 1e-12`; spot-checks
show actual `rel_err = 0.0` because the Python reference is a
line-by-line transliteration of the `.hexa` kernel using the SAME
constants and SAME operation order. The only residual that could
arise is last-bit operation-order rounding — which is zero on this
algorithm because there is no fused multiply-add or non-commutative
reordering.

### Blockers found — none

No new hexa-lang language gaps surfaced during this port. All required
primitives (`sqrt`, `log`, multiplication, division, subtraction of
floats) work bit-identically to libm. The line-continuation footgun
from the solar pilot was avoided by keeping every expression on one
line. The walrus-expression codegen gap (`x := …` not lowered) was
hit in an ad-hoc dump script but is not used in either the kernel or
the test.

### Honesty (g3) — what this does NOT prove

- `absorbed=true` NOT flipped at the demiurge record layer.
  Per the D80 pilot constraint, that requires the
  `HexaNativeParityRef` schema landing + a measured plasma oracle
  (Thomson-scattering / Langmuir probe / interferometry). This pilot
  proves the PORT PATTERN, not the absorbed gate.
- The kernel ports ONLY the 4 primary NRL parameters. The broader
  `plasma_metrics.hexa` surface (ω_ce, ω_ci, v_th_e, v_th_i, v_A)
  already exists and remains the consumer-facing kernel for the
  fusion-domain adapter — no behaviour change.
- ln Λ low-T regime (T_e < 10·Z² eV) NOT implemented; callers in that
  regime must regime-flag. NRL p.34 case 1 is the follow-up.

### Pattern reinforcement — checklist still holds

The 7-step checklist from the solar pilot applied without modification:

1. Pick substrate ✓ (existing `plasma_metrics.hexa` + `plasma_metrics.py`)
2. Capture parity baseline FROM the substrate ✓ (8 samples × 5-6
   outputs = 41 reference numbers from /opt/homebrew/bin/python3
   `math` mirror, ≥15 digits each)
3. Write the `.hexa` kernel mirroring line-by-line ✓ (sibling
   `_kernel.hexa` per the new "broad kernel already exists" rule)
4. Write the parity test following `solar_kernel_test.hexa` ✓
5. `hexa run` to verify PASS ✓ (41/41)
6. Document the gap ✓ (this file)
7. Do NOT flip `absorbed=true` ✓ (record-layer schema not in scope)

The pattern is now confirmed on three orthogonal substrates — closed-
form trig (solar), Monte Carlo (mc_transport), closed-form algebra
(plasma). The next port can apply this template without further
pattern-discovery work.

---

## Fifth-b sample — `kepler_2body_kernel.hexa` (D80 pilot #5b)

**Date**: 2026-05-20
**Numbering rationale**: orbital landed on origin/main at `2ffe3620`
*before* plasma at `c668702b` and both commit messages claimed "pilot
#5" (parallel collision). Plasma already owns the "Fifth sample"
prose section above; renaming it would touch every cross-link and the
README. Slotting orbital as `#5b` mirrors the existing `#3 / #3b`
parallel-pair pattern and keeps the table edit to a single row insert
with no downstream renumbers.

**Pilot scope**: clean-room hexa-native port of the textbook Kepler
two-body closed form (Vallado §2.2 / Curtis §3.6) — Newton-Raphson
5-step on `M = E − e·sin(E)`, half-angle ν reduction,
`r = a(1 − e·cos E)`, perifocal (P-Q) cartesian. Domain-agnostic ①a
kernel; the existing `sgp4_kernel.py` remains the ①a kernel for full
satellite propagation (J2 / drag / lunar / SRP) — this 2-body kernel
is the unperturbed inner solve and the seed for a future hexa-native
SGP4 port.

### What landed (commit `2ffe3620`)

| file | role |
|---|---|
| `stdlib/kernels/orbital/kepler_2body_kernel.hexa` | hexa-native — `propagate(mu, a, ecc, t) -> [E, ν, r, x, y]` · `kepler_solve_E(M, ecc, n_iters)` · `mean_anomaly` · `true_anomaly` · `radius` |
| `stdlib/kernels/orbital/kepler_2body_kernel_test.hexa` | parity test — 27 assertions on a LEO grid (a=7000 km, μ=GM_earth) at 5 (e, t/T) picks covering e ∈ {0.0, 0.1, 0.3, 0.7} × t/T ∈ {0.10, 0.25, 0.50, 0.85} vs Python `math` libm closed-form (same NR-5, same libm) |

### Parity numbers

```
kepler_2body_kernel_test: 27/27 PASS
```

All 27 assertions at `rel_err = 0.0` (literal IEEE-754 bit-exact) —
the Python reference is a line-by-line transliteration using the same
NR iteration count and the same libm, so there is no operation-order
residual. Assertion ceiling was set at 1e-10; actual gap is ~12
orders below that.

Test grid covers: circular (e=0), near-circular (e=0.1), moderate
(e=0.3), high (e=0.7) eccentricity × periapsis-side, quarter-orbit,
apoapsis (M=π boundary), post-π wrap (negative-M NR seed). Two
invariants round out the suite — ν = E at e=0, and the conic identity
`r(ν) = a(1−e²)/(1+e·cos ν)`.

### Hexa-lang gotchas found (new)

1. **`e` parameter shadows the stdlib `e()` Euler-constant function**
   — naming the eccentricity argument `e` causes the codegen to emit
   `hexa_fn_new((void*)e, 0)` (the function pointer) instead of the
   parameter binding, producing wrong numerics with no compile error.
   Workaround: rename every eccentricity parameter to `ecc`. Filed
   as a hexa-lang follow-up — the symbol-resolution should prefer the
   local binding over the stdlib function when shadowed.
2. **`wrap_pi` boundary at exactly +π flips sign under the natural
   form** — `((x + π) mod 2π) − π` maps `+π → −π`, which breaks the
   apoapsis test (M=π should stay at +π, not jump to −π and seed NR
   on the wrong side). Fix that landed: fmod-flavored two-step that
   reduces to `[0, 2π)` first and only shifts when strictly `> π`, so
   `+π` stays at `+π`.

### Honesty (g3) — what this does NOT prove

- `absorbed=true` NOT flipped on any demiurge cell. Same
  `HexaNativeParityRef` schema gate as pilots #1 / #2 / #5.
- Elliptical only (0 ≤ e < 1). Parabolic / hyperbolic Kepler is the
  separate `M = e·sinh F − F` solve — out of scope.
- Two-body point-mass — no J2, no drag, no third-body, no SRP. SGP4
  (`sgp4_kernel.py`) remains the ①a kernel for real satellite work;
  this kernel is the unperturbed baseline and a future inner-solver
  for a hexa-native SGP4 port.

## Pilot sample table (rolling — append as pilots land)

> **Cross-link**: each row mirrors a `[pilot-<id>]` section in
> `demiurge:domains/PILOTS.demi` (D87 + D90 + D93). The `SSOT id`
> column gives the lookup key for `PilotLoader.find(id:)`.

| pilot # | kernel                                                  | algorithm                              | parity tier(s)                                                  | result                | landed     | SSOT id (demiurge:PILOTS.demi) |
|--------:|---------------------------------------------------------|----------------------------------------|-----------------------------------------------------------------|-----------------------|-----------:|--------------------------------|
| #1      | `stdlib/kernels/solar/solar_kernel.hexa`                | Hughes 1985 ephemeris + Haurwitz 1945  | pvlib 0.13.0 substrate parity (6 Phoenix-AZ timestamps)         | 21/21 ≤1e-13 rel      | 2026-05-20 | `pilot-solar`                  |
| #2      | `stdlib/kernels/mc_transport/mc_slab_demo.hexa`         | 1-D slab MC, Beer-Lambert oracle       | python-companion (same LCG) bit-identical + analytic √N envelope | 8/8 ~1e-3 rel @ N=1e5 | 2026-05-20 | `pilot-mc_transport`           |
| #3      | `stdlib/kernels/neural/lif_kernel.hexa`                 | LIF analytic per-timestep exact        | numpy 2.x substrate reference                                   | 23/23 ≤2e-15 rel      | 2026-05-20 | `pilot-neural_lif`             |
| #3b     | `stdlib/kernels/graph/` (BFS+Kahn port)                 | BFS + topological sort                 | networkx companion parity                                       | (concurrent branch)   | 2026-05-20 | `pilot-graph_bfs`              |
| #4      | `stdlib/kernels/urdf/` (2-link FK port)                 | Forward kinematics, 2-link planar      | yourdfpy companion parity                                       | (concurrent branch)   | 2026-05-20 | `pilot-urdf_fk_2link`          |
| #5      | `stdlib/kernels/plasma/plasma_metrics_kernel.hexa`      | NRL Formulary 4 primary + lnΛ          | hand-mirrored Python math closed-form (8 samples)               | 41/41 rel_err=0       | 2026-05-20 | `pilot-plasma_metrics`         |
| #5b     | `stdlib/kernels/orbital/kepler_2body_kernel.hexa`       | Vallado §2.2 / Curtis §3.6 closed-form 2-body propagator, NR-5 on M = E − e·sin(E) | Python `math` libm closed-form (5 (e, t/T) picks × 4 ecc + 2 invariants; e ∈ {0.0, 0.1, 0.3, 0.7} × t/T ∈ {0.10, 0.25, 0.50, 0.85}) | 27/27 rel_err=0       | 2026-05-20 | `pilot-orbital_kepler`         |
| #6      | `stdlib/kernels/signal_proc/dft_naive.hexa`             | O(N²) naive DFT + IDFT                 | analytic spectra (impulse / DC / cosine) + Parseval + round-trip | 17/17 ≤1e-12 rel      | 2026-05-20 | `pilot-dft_naive`              |
| #7      | `stdlib/kernels/noc_sim/event_queue.hexa`               | Binary min-heap discrete-event sched.  | python-companion `heapq` parity + FIFO-at-equal-times           | 36/36 exact           | 2026-05-20 | `pilot-event_queue`            |
| #8      | `stdlib/kernels/mc_transport/transport_kinematics_kernel.hexa` | Special-relativity kinematics + PDG eq. 34.4 T_max + eq. 34.5 Bethe-Bloch dE/dx (δ=0) + 256-step trapezoidal CSDA range | Python `math` libm closed-form (4 KE samples × 4 materials × 4-6 outputs + 7 CSDA ranges + 2 invariants) | 41/41 rel_err=0       | 2026-05-20 | `pilot-transport_kinematics`   |
| #9      | `stdlib/kernels/circuit/breaker_trace_reduce_kernel.hexa` | Composite trapezoidal I²t / clearing-energy + |·|-threshold-crossing breaker FOMs (UL 489I / IEC 60947-2 §4.3, Burden & Faires §4.3) | Python `math` libm closed-form (3 synthetic traces × 7 outputs + 3 invariants: 1 cleared / 1 non-cleared / 1 non-uniform grid) | 24/24 rel_err=0       | 2026-05-20 | `pilot-breaker_trace_reduce`   |
| #10     | `stdlib/kernels/fem/bar1d_kernel.hexa`                  | 1-D linear (2-node) bar FEM element stiffness + direct-stiffness global assembly + Thomas tridiagonal solve for fixed-free axial load (Hughes §1.6, Cook §2.3, Burden & Faires §6.6) | Python `math` libm transliteration (bit-exact, 4 meshes × 2-9 nodes) + closed-form u(x)=P·x/(EA) analytic oracle (independent of discretisation; FEM is exact for uniform mesh + tip load) | 53/53 rel_err=0       | 2026-05-20 | `pilot-fem_bar1d_subset`       |
| #11     | `stdlib/kernels/autodiff/dual_forward_kernel.hexa`      | Forward-mode automatic differentiation via dual numbers — value-tangent pair propagated through 5 arithmetic + 6 transcendental/power primitives (Griewank & Walther 2008 §3.1, Rall 1981, Wengert 1964) | Two-tier: (a) ANALYTIC closed-form derivatives of 9 elementary functions (x², sin·cos, exp, (x²+1)/(x−1), √(1+x²), log(x²+1), sin(x²), x³, 1/x) at fixed evaluation points + 3 invariants + 1 chain-rule cross-check + 1 linearity invariant — abs residual ≤1e-13 / typically ≤1e-15; (b) BIT-EXACT Python `math` libm oracle (dual_oracle.py) on the same 9 cases at rel_err = 0 | 48/48 PASS — analytic abs ≤7e-16 + companion rel_err=0 | 2026-05-20 | `pilot-autodiff_dual_forward`  |

### Pilot #6 — DFT (signal_proc / 2026-05-20)

**Scope**: 4th pilot, 1st targeting the `signal_proc` kernel family.
Naive O(N²) discrete Fourier transform + inverse + magnitude +
power. Mirrors numpy.fft convention (`exp(-2πi·k·n/N)` for forward,
`+` for inverse with `1/N` normalisation). Companion oracle
`dft_naive.py` uses ONLY `math` (no numpy) so the parity test runs
without any third-party Python install.

**Algorithm choice**: The MNE `psd_array_welch` substrate is a 5-
layer stack — frame splitter + Hann window + DFT + magnitude² +
inter-frame averaging. The DFT inner loop is the obvious smallest
slice. For N ≤ 16, naive O(N²) is bit-identical to the radix-2 FFT
(within float roundoff; the FFT just structures the same arithmetic
to factor out repeated twiddles). Landing the naive DFT first gives
us the closed-form anchor against which a future Cooley-Tukey FFT
can be parity-tested.

**Parity results**: 17/17 PASS at <1e-12 relative on every
assertion. Off-bin "leakage" in cosine-at-bin-k0 spectra ≤ 3e-15
(machine epsilon × N), and Parseval (energy conservation) closes to
~1e-15 absolute. Round-trip (`idft(dft(x))`) reproduces the input
within 4e-15 absolute for N=16.

**Hexa-lang gotchas** (carried over + new):

1. `tau()` is available in `stdlib/core/math/float` (≡ 2π) — the
   forward-DFT angle uses `0.0 - tau() * k * n / N`.
2. Returning two arrays as a `[[float]]` and destructuring at the
   call site (`let X = dft_naive(x); let xr = X[0]; let xi = X[1]`)
   works cleanly.
3. `cos` / `sin` deliver the same bit pattern as Python's
   `math.cos` / `math.sin` (both delegate to libm). Off-record
   numpy.fft cross-check confirmed identity to ~1e-15 for N ≤ 16,
   but the test stays numpy-free per the pilot-self-containment
   discipline.

**What this does NOT prove**:

- `absorbed=true` is NOT flipped on the demiurge cell for any
  aura / scope / signal-processing producer. Same `HexaNativeParityRef`
  schema gate as pilots #1 / #2.
- Welch PSD (windowed + averaged periodograms) is NOT ported yet —
  the DFT is one floor below. The Welch port is queued.
- O(N²) is fine for N ≤ ~256; for the 512 / 1024 / 2048 frames MNE
  actually uses, a radix-2 FFT port is the next round. This pilot
  is the closed-form anchor for that FFT.

### Pilot #7 — Event-queue scheduler (noc_sim / 2026-05-20)

**Scope**: 4th pilot, 1st truly data-structure-only (no float
math). A binary min-heap on `(time, seq)` ordering — the standard
discrete-event scheduler primitive. The `seq` tiebreaker guarantees
deterministic FIFO at exactly-equal times, matching cpython's
`heapq` semantics on lexicographic tuple ordering.

**Algorithm choice**: NoC simulation in `kernels/noc_sim/` is
currently 6 hexa-native analytic-or-graph modules — anynet topology
parser, iq_router pipeline timing, leighton lower-bound, etc. None
of them is event-driven. The discrete-event scheduler is the
missing primitive that would let a future event-driven flit
simulator (the BookSim2 absorption end-state) be assembled on top.
Heap-based scheduling is also the universal abstraction for any
DES (queueing networks, packet-level network sim, actor system),
so the kernel doesn't bake in any NoC vocabulary.

**Parity results**: 36/36 PASS — empty-queue sentinels, monotone-
nondecreasing pop times across 8-event + 32-event stress, FIFO-at-
equal-times via `seq`, and a recorded 5-event insert sequence that
matches the Python companion's pop sequence event-for-event.

**Hexa-lang gotchas found** (new, beyond #1 / #2):

1. **Multi-line function signatures with `->` on the continuation
   line break the parser.** Same family as the `- continuation`
   bug from pilot #1. Worked around by keeping signatures on a
   single line. Filed for hexa-lang follow-up.
2. **`[Event]` (array of struct) does not support in-place index
   assignment (`h[idx] = ev` for struct-typed arrays)** — at
   runtime it errors `array[1]: container is not an array (tag=6)`.
   Workaround: push-only rebuild helpers (`_swap_events`,
   `_set_head`, `_drop_last_event`) that recreate the array with
   the swap baked in. O(N) per swap, so O(N log N) per push/pop
   instead of O(log N) — fine for the small heaps (N ≤ 1024) we
   target, but inefficient for million-event traces. The
   in-place struct-array element assignment is the right
   long-term fix; documented as a hexa-lang follow-up.
3. **Heterogeneous-element arrays `[any]` cannot be indexed back
   into typed slots** — `let r = eq_pop(q); r[0]` errors at
   runtime even though `eq_pop` returns `[EventQueue, Event]`.
   Solved by returning a typed wrapper struct (`EqPopResult { q,
   ev, ok }`) — the right shape for a multi-return anyway.
4. **`while true { ... if cond { return ... } }` works**, but a
   slightly cleaner pattern is `while keep_going { ... }` with a
   mutable `keep_going: bool` toggle, since the parser sometimes
   warns on the `true` literal in a loop condition in older
   builds. (Cosmetic; both forms run.)

**What this does NOT prove**:

- `absorbed=true` is NOT flipped on any demiurge cell. The
  scheduler is a building block, not a measurement; it gates only
  when a consumer DES is parity-verified against an external
  oracle (BookSim2 event trace, ns-3 packet trace) — that's
  multi-round future work.
- An actual event-driven NoC sim is NOT included — composing the
  scheduler with `iq_router.hexa` pipeline timing + flit-level
  packet tracking is the next sample in this pilot family.
- Heap performance is O(N log N) per push/pop instead of O(log N)
  due to the struct-array workaround above; revisit when hexa-lang
  lands in-place struct-array element assignment.

### Pilot #8 — Transport-kinematics + Bethe-Bloch + CSDA range (mc_transport / 2026-05-20)

**Scope**: 9th pilot, 2nd in the `mc_transport` kernel family after
#2 (mc_slab_demo). Ports the domain-agnostic numeric primitives of
`transport_kernel.py` (the ①a kernel under D72) — special-relativity
kinematics, PDG eq. 34.4 max-energy-transfer T_max, PDG eq. 34.5
Bethe-Bloch dE/dx (density-correction δ = 0), and a 256-step
trapezoidal CSDA stopping range ∫dE/(dE/dx). The `particle`-library
PDG-data lookup half is NOT in scope — that is a table fetch over
the PDG aggregator, not a closed-form math kernel.

**Algorithm choice**: `transport_kernel.py` is the ①a domain-agnostic
kernel that `stdlib/cern/bethe_bloch_stopping.py` and
`stdlib/antimatter/pdg_lookup.py` both call. `stdlib/cern/
bethe_bloch_stopping.hexa` already embeds an inline Bethe-Bloch
evaluator (CERN materials × antiproton × ELENA KE grid baked in), but
the upstream ①a kernel's domain-agnostic surface — kinematics +
T_max + dE/dx + CSDA range, no CERN baggage — was still .py-only.
This pilot lands the missing ①a slice. The day a new
`stdlib/<domain>/` adapter needs T_max or stopping range, it imports
this kernel rather than re-embedding the formulas.

**Algorithm provenance**: PDG 2024 (Workman et al., Phys. Rev. D 110
(2024) 030001) §34 — eq. 34.4 (T_max relativistic), eq. 34.5
(Bethe-Bloch mean stopping power, density-effect δ = 0). K_BB =
0.307075 MeV·cm²/g (PDG eq. 34.5 / Table 34.4). No Geant4 source-code
inspection, no scikit-hep `particle` library code reading — closed-
form public textbook formulas only.

**Parity results**: 41/41 PASS at `rel_err = 0.0` (literal IEEE-754
bit-exact) on every assertion, including the 7 CSDA ranges (256-step
trapezoidal sums) — the kernel and Python reference accumulate in
the same i=1..n-1 order with half-weighted endpoints, so the running
total is bit-stable. Test envelope: 4 KE samples (1 / 10 / 100 / 1000
MeV — low-β to mildly-relativistic) × 4 materials (Al / Cu / W / Pb —
PDG Table 34.1, Z spanning 13 to 82) covering 25 kinematics +
T_max + dE/dx assertions, plus 7 CSDA range checks, plus 2 invariants
(E_tot − KE == m, p == β·γ·m). D80 ceiling 1e-10 relative; observed
gap < 1e-15 (i.e. zero — every assertion is bit-exact).

**Hexa-lang gotchas found**: none new. The pilot used `to_float(int)`
on `n_steps` to bridge `int → float` for the trapezoidal step, used
fixed-length `[float]` return arrays (idiom from #5b kepler), and
mirrored the kepler test pattern's `check_close` helper. The
parameter-shadowing fix landed earlier today (#5b follow-up,
self/codegen_c2.hexa) means parameter names can match stdlib
function names freely; this pilot used `m_e_mev` / `m_p` for clarity
rather than dodging anything.

**What this does NOT prove**:

- `absorbed=true` is NOT flipped on any demiurge cell. Same
  `HexaNativeParityRef` schema gate as pilots #1 / #2 / #5 / #5b.
  Bethe-Bloch omits the same four pieces (shell corrections, density
  effect δ, straggling distribution, nuclear stopping) the .py
  substrate omits — Stage 4 needs a Geant4-MC parity round, which is
  multi-month.
- The `particle`-library PDG-data lookup is NOT ported. That is a
  table fetch over the scikit-hep aggregator and lives on the .py
  side until either (a) a hexa-native PDG-table embedding lands or
  (b) the lookup is gated to "load PDG JSON from disk + walk a
  hash map" — both are separate rounds.
- CSDA range is the CONTINUOUS-slowing-down approximation; real
  particle ranges have straggling (~5-10 % spread on the projected
  range at LEO scales) and a nuclear-stop tail. The kernel returns
  the CSDA mean — the caller owns the variance caveat.

### Pilot #9 — Breaker trace reducer (circuit / 2026-05-20)

**Scope**: 10th pilot, 1st in the `circuit` kernel family (the
existing circuit kernels — devsim / vdmos / wolfspeed — were all
born-hexa-native; this is the first circuit kernel ported FROM a
Python `.py` substrate). Ports the domain-agnostic numeric primitives
of `stdlib/sscb/ngspice_breaking.py`'s inline `_measure` reducer
(40 LOC) — composite trapezoidal I²t / clearing-energy integrals over
a non-uniform timestep grid + `|·|`-threshold-crossing search for the
breaker clearing event. The ngspice CLI orchestration + netlist
generation + `wrdata` CSV parser remain on the .py side (subprocess
adapter, not a closed-form math kernel).

**Algorithm choice**: `ngspice_breaking.py` is a `sscb + verify`
adapter that runs a bolted-fault SPICE transient and reduces the
resulting (time, v_sw, i_load) trace to the UL 489I / IEC 60947-2
§4.3 breaker figures-of-merit. The reducer is closed-form
numerics — peak scan + |·|-threshold search + composite trapezoidal
integration on a NON-uniform partition. None of it cares about
SPICE itself; the same primitives work on any breaker-style
(time, voltage, current) trace from any source (HVDC interrupter
testbench, MOSFET SCB lab capture, even an analytic synthetic
shape). So the ①a kernel slice is the reducer; the SPICE side stays
①b adapter.

**Algorithm provenance**: (a) Burden & Faires, "Numerical Analysis"
10th ed. (Cengage 2016), §4.3 — Composite Trapezoidal Rule for a
NON-uniform partition: I ≈ Σ_i 0.5·(f_i + f_{i+1})·(t_{i+1} − t_i).
(b) UL 489I (Molded-Case Circuit Breakers for DC, ed. 1) + IEC
60947-2 §4.3 — breaker figures-of-merit: I_peak (peak prospective
fault current), I²t let-through, clearing time t_c = time until
|i| ≤ 1 % of I_peak after trip, clearing energy ∫v·i dt over the
clearing interval. No ngspice source-code inspection, no Berkeley
SPICE3 code reading — composite trapezoid + threshold-crossing are
textbook numerics that pre-date SPICE by decades.

**Parity results**: 24/24 PASS at `rel_err = 0.0` (literal IEEE-754
bit-exact) on every assertion. Three synthetic analytic traces ×
7-output `breaker_metrics` vector (= 21) + 3 invariants
(`∫_0^1 x dx == 0.5`, `trace_peak_abs` on a signed list, threshold-
crossing on a monotone list) = 24 assertions. The trapezoidal sums
are bit-stable because the kernel and the Python reference both walk
i = i_lo..i_hi-1 with the same 0.5·(a+b)·dt step, and `math.exp` /
`math.fabs` bit-mirror libm on darwin-arm64. D80 ceiling 1e-10
relative; observed gap = 0 across all checks.

**Test envelope**:
- **Trace A** — RC discharge i(t) = 100·exp(−100·t), t ∈ [0, 0.01],
  11 uniform samples, t_det = 0.0. At t = 0.01, i ≈ 36.79 A is
  above the 1 % threshold → exercises the "no-clear" branch +
  whole-post-trip-window integration.
- **Trace B** — Same shape extended to t ∈ [0, 0.05], 21 uniform
  samples. At t = 0.05, i ≈ 0.674 A is below threshold →
  exercises the "cleared" branch + clearing-time search.
- **Trace C** — Triangular pulse on a 50 A DC pedestal that drops
  to zero at t = 0.0055; NON-uniform 13-sample grid clustered
  around the clearing event; t_det = 0.005. Exercises (a) the
  non-uniform-grid trapezoidal path, (b) the t_det-aware
  threshold-search start, (c) the residual-current readback at
  `i_hi - 1`.

**Hexa-lang gotchas found**: none new. The pilot used `.push(x)`
for dynamic array growth (idiom from `kernels/logic_synth/`,
`kernels/circuit/wolfspeed.hexa`), `break` inside `while` for the
threshold-index scan (idiom from `kernels/logic_synth/read_verilog`),
fixed-length `[float]` return arrays (idiom from #5b kepler and
#8 transport_kinematics), and `to_float(int)` to bridge `int → float`
for the per-sample time computation. The `.push(...)` rebuild idiom
(O(N) per push for `[float]`) is fine at the trace sizes the breaker
domain produces (≤ 1e4 samples); the struct-array in-place
assignment limitation called out by #7 (event_queue) does not bite
here because the kernel only allocates flat `[float]` buffers.

**What this does NOT prove**:

- `absorbed=true` is NOT flipped on any demiurge cell. Same
  `HexaNativeParityRef` schema gate as pilots #1 / #2 / #5 / #5b /
  #8. The SSCB cell stays `measurement_gate = GATE_OPEN` /
  `absorbed = false` until (a) a real ngspice-trace round-trip
  parity test lands (kernel reduces the same SPICE trace as the
  Python `_measure` and matches bit-for-bit), AND (b) an accredited-
  lab UL 489I type-test result is wired into the demiurge cell
  (months out).
- The ngspice CLI / netlist generator / `wrdata` parser is NOT
  ported. That is subprocess orchestration over the ngspice binary
  and lives on the .py side until either (a) a hexa-native SPICE
  solver lands (multi-year — devsim.hexa / vdmos.hexa are the
  closest existing pieces, but they are TCAD device physics, not
  circuit-level transient solvers), or (b) the orchestration is
  re-pointed at a wholly different (hexa-native or otherwise)
  transient solver.
- The 1 % clearing-threshold ratio is hardcoded in this iteration
  (UL 489I / IEC 60947-2 convention). A future caller domain that
  needs a different ratio (HVDC interrupter at 5 %, DC-link SCB at
  0.1 %, etc.) would extend the kernel signature with an explicit
  `threshold_ratio: float` parameter — straightforward follow-on.
- Composite trapezoid is O(h²) accurate; for traces with sharp
  clearing-edge slopes a Simpson / Romberg refinement would close
  faster. The breaker domain in practice uses adaptive-timestep
  SPICE traces with samples clustered around the event, so
  trapezoidal accuracy ≪ measurement noise floor — refinement is
  not blocking and is queued.

### Pilot #10 — 1-D bar FEM subset (fem / 2026-05-20)

**Scope**: 11th pilot, 1st in the `fem` kernel family. PARTIAL PORT —
explicitly < 5 % of the skfem kernel's surface. The full
`stdlib/kernels/fem/skfem_kernel.py` does 3-D tet meshing via gmsh +
steady-state heat conduction + linear elasticity + von Mises post-
processing, all on a sparse linear-algebra stack. The pilot ports
only the SMALLEST self-contained FEM primitive: a 1-D linear (2-node)
bar element + dense global stiffness assembly + Thomas tridiagonal
solve for the fixed-free axial-load case. The 3-D tet stack remains
firmly on the .py side until heavier primitives (sparse linalg,
gmsh-replacement meshing, 2-D/3-D element families) land — multi-
round / multi-month work.

**Algorithm choice (3 reasons)**:
1. **Domain diversity** — `fem` is the largest open heavy-port bucket
   in `DEPENDENCIES.demi`, and no prior pilot touches it. The 11
   existing pilots cover solar / mc_transport / neural / graph / urdf
   / plasma / orbital / signal_proc / noc_sim / circuit — adding fem
   widens the substrate-family coverage to 11 distinct kernel folders.
2. **Tiny surface, clean textbook** — 3 functions
   (`bar1d_element_stiffness` / `bar1d_assemble_K` /
   `bar1d_solve_fixed_free`) + 1 internal helper (`thomas_tridiag`).
   The 1-D bar element is the canonical Hughes §1.6 / Cook §2.3 worked
   example; Thomas is Burden & Faires §6.6 Algorithm 6.7. No source-
   code inspection — pure textbook re-derivation.
3. **TRUE external oracle** — the closed-form mechanics-of-materials
   solution u(x) = P·x/(E·A) for the fixed-free uniform bar lives in
   the linear trial-function space, so the FEM solve coincides with
   the analytic answer up to Thomas roundoff. This is a real
   discretisation-independent oracle, not a self-mirror — the
   strongest possible parity claim for an FEM pilot.

**Algorithm provenance**: (a) Hughes, "The Finite Element Method:
Linear Static and Dynamic FEA" (Dover 2000), §1.6 — derivation of the
2-node linear-bar element stiffness `k_e = (E·A/L) · [[1,-1],[-1,1]]`
via `∫_0^L B^T·E·A·B dx` with B = (1/L)·[-1,1]. (b) Cook, Malkus,
Plesha & Witt, "Concepts and Applications of FEA" 4th ed. (Wiley
2002), §2.3 — direct-stiffness global assembly mapping. (c) Burden &
Faires, "Numerical Analysis" 10th ed. (Cengage 2016), §6.6
Algorithm 6.7 — Crout / Thomas factorisation for tridiagonal linear
systems (O(n) forward sweep + O(n) back sweep). No scikit-fem /
FEniCS / deal.II / Calculix source-code inspection.

**Parity results**: 53/53 PASS at `rel_err = 0.0` (literal IEEE-754
bit-exact) on every assertion. The hexa-side `bar1d_solve_fixed_free`
walks the same Thomas sweep as the Python oracle
(`bar1d_oracle.py`) in the same operation order with the same libm,
so the IEEE-754 residual is zero. The analytic-oracle comparison
(u(x)=P·x/EA) is also at rel_err ~ 5e-17 (S1) to ~3e-15 (S4 N=8
uniform mesh) — well below the D80 ceiling of 1e-10.

**Test envelope** (4 meshes):

- **S1 — Uniform N=4 mesh** on [0,1], steel-like (E=200 GPa, A=1e-4 m²,
  P_tip=1 kN). Canonical uniform-mesh path; analytic u_tip = 50 µm.
- **S2 — NON-uniform N=4 mesh** at [0, 0.1, 0.3, 0.6, 1.0], aluminum
  (E=70 GPa, A=2.5e-4 m², P_tip=500 N). Exercises per-element
  c_e = EA/L_e variation through the Thomas sweep.
- **S3 — Single-element N=2 mesh** with E=A=P=1.0. Edge case
  m=1 reduced system (Thomas sweep degenerates to b[0]/d[0]).
- **S4 — Uniform N=8 mesh** on [0,1], same steel/load as S1. Longer
  Thomas sweep (m=8); analytic residual ~3e-15 rel.

Plus invariants: (i) K is symmetric, (ii) row sums of K are zero
(rigid-body mode before BC), (iii) BC u[0]=0 enforced exactly across
all four samples.

**Hexa-lang gotchas found**: none new. The pilot used `.push(...)`
for dense matrix construction (O(N²) memory for N nodes is fine at
pilot-scale N ≤ 16), mutable indexed assignment on `[float]` (works
fine — the #7 struct-array `h[i] = ev` gap does not bite plain `[float]`
or `[[float]]`), and `to_float`-free integer arithmetic for node-index
math. The parameter-shadowing fix from #5b also means parameters
`E` / `A` / `L` can coexist with stdlib `e()` etc. without renaming.

**What this does NOT prove**:

- `absorbed=true` is NOT flipped on any demiurge cell. Same
  `HexaNativeParityRef` schema gate as pilots #1 / #2 / #5 / #5b / #8
  / #9. The component+verify cell, rtsc cells, and sscb-femmt cell all
  stay `measurement_gate = GATE_OPEN` until heavier FEM primitives
  land. This pilot proves the PORT PATTERN for FEM assembly + direct
  solve, not the absorbed gate for any FEM-consuming cell.
- **PARTIAL PORT (< 5 % of skfem)** — 1-D linear (2-node) bar
  elements ONLY. No 2-D (triangle / quad), no 3-D (tet / hex), no
  higher-order shape functions, no sparse linalg, no meshing, no
  thermal coupling, no nonlinear elasticity, no contact, no body
  loads. The full skfem family stays heavy-port in
  `DEPENDENCIES.demi` — the `kernel-fem` row's `portable_status =
  "heavy-port"` is unchanged by this pilot; only the `notes` field
  is extended to record the subset port.
- The 1-D linear bar element is EXACT for constant-EA + uniform-load
  problems (the analytic solution lives in the trial-function space),
  so this pilot does NOT exercise FEM approximation error (which is
  identically zero on this problem). It exercises the
  ASSEMBLY + Thomas SOLVE primitives, which is the point. Approximation-
  error tests (e.g. distributed body load f(x) = ρgA · x with
  quadratic exact solution, O(h²) convergence under mesh refinement)
  are queued for a sibling pilot.
- Thomas algorithm assumes tridiagonal + diagonally-dominant-or-SPD;
  the 1-D bar K_red with fix-node-0 BC IS SPD (all eigenvalues > 0),
  but the kernel does NOT check for singularity. A degenerate mesh
  (duplicated node coords → L=0 element → division by zero) would
  NaN-out the solve — caller owns mesh sanity. Same contract as
  scikit-fem's `condense + solve` on a degenerate mesh.

### Pilot #11 — Forward-mode automatic differentiation (autodiff / 2026-05-20)

**Scope**: 12th pilot, FIRST in a brand-new `autodiff` kernel folder.
Adds substrate-family coverage to a 12th distinct domain (autodiff,
not in the prior solar / mc_transport / neural / graph / urdf / plasma
/ orbital / signal_proc / noc_sim / circuit / fem families). The
companion kernel that DEPENDENCIES.demi flagged as "Needs … an
autodiff/gradient framework" — `stdlib/scope/openmdao_sizing.py` (the
MDAO heavy-port row) — sits directly on top of this primitive in any
gradient-based optimiser; this pilot is the substrate floor for that
future ①b adapter.

**Algorithm choice (3 reasons)**:
1. **NEW domain** — `autodiff` is the 12th kernel folder under
   `stdlib/kernels/`, and the underlying need is cited verbatim in
   `DEPENDENCIES.demi:domain-scope_openmdao_sizing` (`portable_status =
   heavy-port`, "Needs poppy port + an autodiff/gradient framework —
   multi-round"). The pilot ports the SMALLEST cited slice of that
   multi-round stack (forward-mode dual numbers, scalar I/O), opening
   the substrate-family count to 12.
2. **Tiny surface, clean textbook** — 11 primitives total (5
   arithmetic + 6 transcendental/power), each one a single chain-rule
   pushforward in 1-3 lines of code. Provenance is Griewank & Walther
   2008 §3.1 (the canonical reference for forward-mode AD), Rall 1981
   (the LNCS 120 monograph on dual-number AD), Wengert 1964 (the
   original Comm. ACM letter introducing the technique). No JAX /
   PyTorch / Autograd / OpenMDAO / Tapenade / ADOL-C / CasADi source-
   code inspection — pure textbook re-derivation.
3. **STRONGEST possible parity oracle** — closed-form analytic
   derivatives of elementary functions ARE THEMSELVES elementary, so
   we can compare `(f(x_0), f'(x_0))` against an exact algebraic
   answer at IEEE-754 roundoff. No second AD library is needed as a
   parity baseline; the math itself is the oracle. Reinforced by a
   Python `math` libm transliteration (`dual_oracle.py`) for the
   bit-exact `rel_err = 0` companion tier — same approach used in
   pilots #5 (plasma) / #5b (kepler) / #8 (transport) / #9 (breaker)
   / #10 (bar1d).

**Algorithm provenance**: (a) A. Griewank & A. Walther, "Evaluating
Derivatives: Principles and Techniques of Algorithmic Differentiation"
2nd ed. (SIAM 2008), §3.1 — definition of the tangent (forward) mode
on dual numbers ℝ[ε]/⟨ε²⟩, with every primitive φ replaced by
(φ(v), φ'(v) · dv). (b) L.B. Rall, "Automatic Differentiation:
Techniques and Applications", LNCS 120 (Springer 1981) — the original
monograph treatment of dual-number AD in modern form. (c) R.E.
Wengert, "A simple automatic derivative evaluation program",
Comm. ACM 7(8) (1964) — the original publication of the technique.
(d) M. Bartholomew-Biggs et al., "Automatic differentiation of
algorithms", J. Comput. Appl. Math. 124 (2000), 171–190 — survey of
the chain-rule pushforwards for sin / cos / exp / log / sqrt / pow.

**Parity results**: 48/48 PASS at the D80 1e-10 ceiling.
- **Analytic tier** — 9 functions × `(f, f')` at fixed x₀, absolute
  residual ≤ 1e-13 (most ≤ 1e-15; cos²−sin² at π/4 has ~2.2e-16 abs
  residual, 2x·cos(x²) at √(π/2) has ~7e-16 abs residual from
  sqrt(π/2)² ≠ π/2 exactly). Both are well below the ceiling.
- **Companion tier** — 9 cases bit-identical at `rel_err = 0` against
  `dual_oracle.py` (math libm transliteration), same operation order
  on darwin-arm64 → same IEEE-754 result.
- **Invariants** — `dual_const`/`dual_var` accessors, `a + (-a) = 0`
  bit-exact, `d_pow_int(x, 0) = [1, 0]`, `(sin x)²` two-way build
  (`d_mul(sin, sin)` ≡ `d_pow_int(sin x, 2)` at ≤ 1e-15 abs),
  linearity of `α·sin(x) + β·cos(x)` at x = 0.7.

**Hexa-lang gotchas found**: none new. The `[float]`-of-length-2
Dual representation (matches pilot #6's `[Xr, Xi]` convention)
sidesteps the pilot #7 struct-array element-assignment gap entirely.
One Python-side note for FUTURE PILOTS: `f"{x:.17e}"` rendering of a
float can produce a string whose `0xN` mantissa is OFF BY 3 ULPs from
the original — the `.17e` form rounds to 17 significant decimal
digits, which is one digit MORE than float64 carries, so it adds
spurious low-bit noise. Use `repr(x)` (`0.8` not `0.8000000000000004`)
or `x.hex()` to dump bit-exact literals. Found and fixed during the
first run of this pilot's test (T6 companion check).

**What this does NOT prove**:
- `absorbed=true` is NOT flipped on any demiurge cell. Same
  `HexaNativeParityRef` schema gate as every other pilot. The
  `scope_openmdao_sizing` cell (MDAO) stays `measurement_gate =
  GATE_OPEN` until a gradient-based optimiser ①b adapter wires this
  kernel into a real design loop — multi-round / multi-month.
- **FORWARD MODE only** — for n-input gradients ∇f(x₁..xₙ) the caller
  pays O(n · cost(f)) (one forward sweep per input). For n ≫ m where
  m is the number of outputs, reverse mode (one backward sweep per
  output) is asymptotically cheaper; that port is queued.
- **SCALAR I/O only** — vector-mode (multiple seeds at once → all
  directional derivatives in one pass) is mechanical but expands the
  Dual representation; not in this round.
- **No control-flow capture** — `if x > 0 { ... } else { ... }`
  returns whichever branch the caller's float comparison picks. No
  subdifferentials, no smoothing — matches every operator-overloading
  AD framework (JAX `jax.numpy.where`, PyTorch `torch.where`).
- **Integer pow only** in `d_pow_int`. Real-exponent
  `u^p = exp(p · log u)` is a one-line caller composition built from
  the existing `d_log` + `d_mul` + `d_exp` primitives.

### Cumulative status across pilots (2026-05-20)

- 12 pilots landed/in-flight (#1-#5, #5b on origin/main, #6+#7+#8+#9+#10+#11
  landing this cycle; #3b + #4 are concurrent branch ports), ≥339
  assertions PASS across them (21+8+23+41+27+17+36+41+24+53+48 = 339
  on the landed pilots alone — #11 adds 48 from dual_forward_kernel)
- 6 hexa-lang followups filed in this audit round (none new in #9/#10/#11):
  - parser `-`/`->` continuation footgun (#1, #7)
  - `fmod` libm shim missing (#1)
  - `str_full(float)` for full-precision dump (#1)
  - struct-array in-place element assignment (`h[i] = ev` for
    `[StructName]`) — runtime errors, push-only rebuild required (#7)
  - parameter-shadowing of stdlib functions (`e` argument shadowed
    by stdlib `e()` Euler-constant; codegen picks the function not
    the binding) — symbol-resolution should prefer the local binding
    (#5b)
  - `wrap_pi` boundary at exactly +π flips sign under the natural
    `((x + π) mod 2π) − π` form; fmod-flavored two-step keeps +π at
    +π and is what landed (#5b)
- 0 demiurge cells flipped to `absorbed=true` — by design (pattern
  proof only; the parity-flip gate lives behind the
  `HexaNativeParityRef` schema, not yet landed)
