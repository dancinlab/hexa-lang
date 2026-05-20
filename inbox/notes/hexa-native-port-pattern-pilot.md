# hexa-native port pattern — first sample (solar_kernel pilot)

**Date**: 2026-05-20
**Pilot scope**: D80 g_hexa_only ultimate-form pilot — port the simplest
existing Python kernel substrate to a true `.hexa` (hexa-lang native)
implementation, then prove parity against the Python substrate.
**Result**: parity holds at machine epsilon (≤1e-14 relative, vs the
spec ceiling of ±0.1 %). Pattern is sound — documented below.

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
