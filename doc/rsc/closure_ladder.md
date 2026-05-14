# RSC Closure Ladder Doctrine

> Distilled from `~/core/hexa-space/verify/{falsifier_check,saturation_check,lint_numerics,run_all}.hexa`
> (MIT, hexa-space v1.0.0). Provides the project-agnostic substrate that
> `tool/rsc/` implements for hexa-lang.

---

## 1. The 0 / 33 / 67 / 100 % Closure Ladder

Every falsifier `F` carries three independent evidence tiers. The closure
percentage is the count of tiers present, rounded onto a fixed grid:

| tiers present | closure_pct | meaning                                  |
|--------------:|------------:|------------------------------------------|
| 0             |   0 %       | declared but no evidence                 |
| 1             |  33 %       | one tier — preliminary                   |
| 2             |  67 %       | two tiers — regression-locked (sat-1)    |
| 3             | 100 %       | all tiers — closure-complete             |

`closure_pct(t1, t2, t3) = round_to_grid(t1 + t2 + t3) -> {0, 33, 67, 100}`.

The grid is intentionally coarse: it surfaces tier *presence*, not tier
*quality*. Quality lives inside each tier's own pass/fail rubric.

---

## 2. Tier Definitions

### T1 — algebraic (`calc_*.hexa`)

Closed-form derivation on the project's invariant lattice. Integer or
rational arithmetic only, no floating-point. Anchors symbolic identity
(e.g. `sigma(6) = 12`, `phi^tau = 16`, BCS `2D/kTc = pi * e^(-gamma_E)`).
Cheap to run, deterministic, hash-stable.

### T2 — numerical (`numerics_*.hexa`)

Floating-point closed-form evaluation through a pure-math runtime
(`self/runtime/math_pure`). Reproduces the T1 algebraic identity in
real arithmetic and cross-checks against published values within a
tolerance band (typically +-15 %). 5-invariant lint enforces shape
(see §4).

### T3 — empirical / archival

Either:
- live hardware feed (Stage-1+ board commissioning), or
- archived pin (`pin.*` markers / cross-referenced JSON / SHA-pinned
  external data sources).

T3 is always the last tier to close, and the only one whose absence is
*expected* during a project's pre-hardware phase. Closure caps at 67 %
until T3 lands, by design.

---

## 3. Saturation Criteria (sat-1, sat-2, sat-3)

Saturation is the regression-locked floor at which a project can stop
adding evidence and start waiting for hardware. Three conjunctive
conditions, all must hold:

- **sat-1 — lint passes.** Every `numerics_*.hexa` satisfies the 5
  invariants (see §4). The numerical tier is shape-locked.
- **sat-2 — inventory >= floor.** On-disk `numerics_*.hexa` count
  meets a registry-derived floor. hexa-space used `>= 9`; the
  general substrate uses `len(registry) * 2` as a placeholder.
- **sat-3 — minimum T2 stack >= 1.** Every registered falsifier has at
  least one numerical tier script. No falsifier is left dangling at
  T1-only.

When all three hold, the substrate emits the saturation sentinel and
the loop can stop spinning iterations:

```
__HEXA_LANG_RSC_SATURATED__ PASS
```

A FAIL on this sentinel is **not** a regression — it is the *normal*
state during a project's pre-saturation ramp.

---

## 4. The 5 Numerics Invariants

Every `numerics_*.hexa` script must satisfy:

1. `use "self/runtime/math_pure"` — no raw libm.
2. `__HEXA_<PROJECT>_NUMERICS_<NAME>__ PASS` sentinel emitted last.
3. `FALSIFIERS` array declared near top (witnesses which IDs this
   script anchors).
4. Explicit `exit(0)` on the PASS path (no implicit returns).
5. `let mut RUN = 0` + `let mut FAIL = 0` counters (so the per-script
   tally is uniform across the corpus).

Plus inventory-array consistency: a declared `NUMERICS_SCRIPTS` array's
length must equal the on-disk glob count.

These invariants are mechanical and cheap to enforce; their value is
that they let the orchestrator parse any conforming script without
per-script special-casing.

---

## 5. Orchestrator Pattern

A single CLI entry walks the corpus:

```
hexa run tool/rsc/run_all.hexa
```

Sequencing:

1. Falsifier audit  — per-falsifier ladder + aggregate.
2. Numerics lint    — 5-invariant sweep.
3. Saturation probe — sat-1 ^ sat-2 ^ sat-3 gate.

Each gate returns `pass: bool` plus structured detail. The orchestrator
emits one unified sentinel: `__HEXA_LANG_RSC_RUN_ALL__ PASS|FAIL`.

---

## 6. Pairing with hexa-lang Doctrine v2

| Doctrine v2 rule                        | RSC mapping                              |
|------------------------------------------|------------------------------------------|
| Rule 2 — algorithm registration          | T1 + T2 tier scripts                      |
| Rule 5 — overlay (cross-validate)        | sat-1 ^ sat-2 ^ sat-3 saturation         |
| LATTICE_POLICY §1.2 — real-limit anchors | T2 numerical comparison vs published     |
| `update || PR` (raw#10 C3 honesty)       | T3 archival pin enforcing source-of-truth |

In short: Rule 2 furnishes the tier 1+2 evidence; Rule 5 saturates
the audit; LATTICE_POLICY scopes what counts as a *real* T2 anchor;
the honesty obligation forbids stopping at T2 and declaring the
underlying physical claim "confirmed".

---

## 7. Sentinel Naming Convention (HEXA family)

```
__HEXA_<PROJECT>_RSC_<GATE>__ PASS|FAIL
```

| project    | sentinel prefix             |
|------------|-----------------------------|
| hexa-space | `__HEXA_SPACE_RSC_*__`      |
| hexa-rtsc  | `__HEXA_RTSC_RSC_*__`       |
| hexa-cern  | `__HEXA_CERN_RSC_*__`       |
| hexa-lang  | `__HEXA_LANG_RSC_*__`       |

Gates within the RSC family:

| gate          | sentinel suffix                                     |
|---------------|-----------------------------------------------------|
| falsifier     | `__HEXA_LANG_RSC_FALSIFIER__ PASS\|FAIL — n/m at p%` |
| lint          | `__HEXA_LANG_RSC_LINT__ PASS\|FAIL — n/m`            |
| saturation    | `__HEXA_LANG_RSC_SATURATED__ PASS\|FAIL`             |
| orchestrator  | `__HEXA_LANG_RSC_RUN_ALL__ PASS\|FAIL`               |

Consumers grep for `__HEXA_LANG_RSC_` and parse the suffix-encoded
tally without per-script knowledge of the underlying registry.

---

## 8. Honesty Contract

`PASS` from any RSC gate means *bookkeeping closure*, **not**
physics-settled. The underlying claims of the project (lattice fit,
hardware feasibility, cross-domain bridges) remain UNPROVEN until the
T3 hardware tier closes for every falsifier. RSC saturation is a
self-stop signal for evidence-gathering iterations — it is not, and
must never be cited as, a settlement of the physical question.

Saturated != falsified != confirmed.
