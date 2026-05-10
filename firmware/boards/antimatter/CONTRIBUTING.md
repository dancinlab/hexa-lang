# Contributing to hexa-antimatter

> **Scope reminder**: this repo is a **substrate spec**, not an experimental rig.
> No working apparatus, no anti-H synthesis, no clinical PET, no live p̄ capture
> happens here.  The verification surface is **closed-form algebra + numerical
> parity + sim-firmware + paper-feed (INSPIRE-HEP) + paper hardware spec**.

---

## §1 What kinds of contributions are welcome

| Kind | Status |
|:-----|:------:|
| Fix typos, broken cross-links, mis-rendering Korean comments | ✅ welcome |
| Cross-link to other `dancinlab/hexa-*` repos | ✅ welcome |
| Add new `verify/numerics_*.hexa` (T2 tier expansion) per recipe §2 | ✅ welcome |
| Add new `verify/empirical_*_inspire.hexa` (T3 paper-feed) for new milestones | ✅ welcome |
| Bring-up notes from real hardware (Phase E2/E3/E4 logs) | ✅ welcome (extreme value) |
| KiCad source for any of the 4 boards (Phase E1) | ✅ welcome (extreme value) |
| Fix a `.hexa` file that fails `verify/all.hexa` | ✅ welcome |
| Update `firmware/doc/board_v0_*.md` with corrected vendor SKUs | ✅ welcome |
| Add a new `state/*_LOG.hexa` fixture row from a public-domain announcement | ✅ welcome |
| Replace fixture rows in `state/*` with **fabricated** data | ❌ not welcome (raw#10 honest C3) |
| Claim empirical closure without Stage-1+ hardware | ❌ retract |
| Inflate sigma³ / sigma⁶ scaling targets without evidence | ❌ retract |

---

## §2 The RSC recipe (mandatory background)

Read `~/core/bedrock/docs/runnable_surface_recipe.md` before opening a non-trivial PR.  It describes the **closure-depth accumulation loop** that produced this repo's verification surface.  Key concepts:

- **T1 (algebraic)** — `verify/calc_*.hexa`: integer/rational closed-form derivation
- **T2 (numerical)** — `verify/numerics_*.hexa`: float math via `self/runtime/math_pure` (no raw libm), proves T1 holds under round-off
- **T3 (empirical)** — currently paper-feed via `verify/empirical_*_inspire.hexa`; closes empirically only at Stage-1+ hardware
- **META** — `verify/{falsifier_check,lint_numerics,firmware_phase_d_lint,saturation_check}.hexa`
- **sat-1** — every falsifier reaches T1 + T2 ×3
- **sat-2** — 16-script standard inventory complete + meta-lint passes
- **sat-3** — every falsifier reaches T3 ≥ 1 (paper or hardware)

When all 3 saturate, the loop self-stops with `__HEXA_ANTIMATTER_RSC_SATURATED__ STOP`.

---

## §3 Required local verification (before PR)

```bash
# 1. Top-level sweep (must report 38/38)
hexa run verify/all.hexa

# 2. The specific verifier you touched
hexa run verify/<your-script>.hexa

# 3. Cross-doc audit (catches SSOT drift)
hexa run verify/cross_doc_audit.hexa

# 4. If you added a numerics_*.hexa, the meta-lint
hexa run verify/lint_numerics.hexa

# 5. If you touched firmware/{hdl,mcu,doc}/, the Phase D lint
hexa run verify/firmware_phase_d_lint.hexa

# 6. Selftest (3 verb sentinels)
hexa run selftest/selftest.hexa

# 7. All tests
for t in tests/test_*.hexa; do hexa run "$t"; done
```

If any of these report FAIL, **do not open the PR**.  Fix it first.

---

## §4 PR guidelines

- **One chunk per PR** — per recipe §2 (one `.hexa` file or one MD or one wiring change).
- **Commit message format**:
  - `feat(verify): RSC iter N — short description`  for new verify scripts
  - `feat(firmware): Phase D — short description`  for firmware/* additions
  - `fix(<scope>): description`  for bug fixes
  - `docs(<scope>): description`  for MD updates
- **Always update CHANGELOG.md `[Unreleased]` section** with one line per chunk.
- **Cross-link to** the relevant `.roadmap.hexa_antimatter §A.x` row if applicable.
- **Honest C3 (raw#10)** — if your numerics show a gap vs published, document the gap as a falsifier rather than fitting around it.

---

## §5 Getting help

- File an issue in `dancinlab/hexa-antimatter` issue tracker
- Cross-substrate questions: `dancinlab/hexa-fusion` (sister), `dancinlab/hexa-cern` (cousin), `dancinlab/hexa-rtsc` (RT-SC magnet upstream)
- Recipe questions: `~/core/bedrock/docs/runnable_surface_recipe.md` § + `dancinlab/hexa-cern` worked example (15-iteration applied case)

---

## §6 License + DCO

All contributions are under MIT license.  By submitting a PR you agree your contribution is your own work or correctly attributed under MIT-compatible license.  No CLA — just MIT.

If you copy text from `canon/` (provenance commit `c0f1f570`), preserve the `<!-- @canonical: ... -->` header so the lineage is traceable.