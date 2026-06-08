# VERDICT — CaH6 bare full-basis vertex gate RE-RUN on the V_NL-bound SCF

**Goal.** The V_NL structure-factor fix (PR #2959, branch `qforge-vnl-structfac`,
`stdlib/qforge/assembler.hexa`) flipped the CaH6 SCF from UNBOUND (+2.744 Ha) to BOUND
(−5.571 Ha) at NPW=64 in the sibling V_NL-completion campaign. The 8-round screened-vertex
campaign + the bare gate (λ=4.13647, 5.47% off QE 4.376) were computed on the OLD
eigenstates. RE-RUN the **bare full-basis vertex gate** (`cah6_fullbz_xval.hexa`,
npw_cap=0, full n=645) on the NOW-PHYSICAL SCF to test if the root fix closes the accuracy
gap.

**Tier.** g5 / verbatim recompute on the V_NL-fixed engine. Host `mini` (Apple M4),
native CPU, NO pod. HONEST (d6/@L5): the real numbers are pasted; **nothing tuned toward
4.376**. Anchor pod 39610026 NOT touched.

**Worktree.** Isolated `/tmp/wt-vnl-bound-rerun` on branch `qforge-vnl-bound-rerun` (cut
from `origin/qforge-vnl-structfac` = the PR-#2959 V_NL fix). HEXA_LANG set to the worktree.

---

## THE RESULT (d6 VERBATIM — NOT tuned)

### Bare gate, npw_cap=0, n=645, q-mesh=4³ MP, BARE vertex — on the V_NL-bound SCF

```
[front-end] cell=Ca n(PW)=645 nelec=16 nocc=8 SCF-converged=true iters=32
[front-end] ecutwfc=80.0 Ry  e_band=-65.1002 Ha
── qforge_run stage trace ──
  [scf]   ok=1 witness=-10.3686 — qforge_davidson ψ,ε (Hartree+LDA-exch H)
  [dfpt]  ok=1 witness=1204.89  — qforge_phonons ω(q,ν) — 0 acoustic zero(s)
  [elph]  ok=1 witness=3.6848   — qforge_elph_g2 Σ|g|² (bare)
  [a2f]   ok=1 witness=20.0374  — qforge_a2f_from_elph → α²F(ω) (L3 assembler)
  [moments] ok=1 witness=20.0374 — eliashberg_moments [λ, ω_log, ω̄₂]
  [tc]    ok=1 witness=751.569  — Allen-Dynes f1·f2 Tc

BARE baseline λ (OLD unbound run #2768) = 4.13647   (rel-ε=5.47%)
QFORGE λ (this run, V_NL-bound SCF)      = 20.0374
QE answer-key λ                          = 4.376
rel-ε                                    = 3.57892  (357.892 %)
Δλ vs 4.137 baseline                     = +15.9009
QFORGE ω_log                             = 1107.42 K
QFORGE Tc (Allen-Dynes)                  = 751.569 K
QFORGE Tc (Eliashberg)                   = 803.351 K
GATE: NOT MET — rel-ε=357.9% > 1%
```

### nq=2 cross-check (same SCF, cheaper 2³ q-mesh) — CONFIRMS the direction

```
[front-end] cell=Ca n(PW)=645 nelec=16 nocc=8 SCF-converged=true iters=32
[front-end] ecutwfc=80.0 Ry  e_band=-65.1002 Ha  ω_log(band)=1172.54 K  (IDENTICAL to nq=4)
  [scf] witness=-10.3686 · [dfpt] witness=1204.89 · [elph] witness=3.6848
  [a2f]/[moments] witness=20.0374
QFORGE λ (this run, nq=2) = 20.0374   (BYTE-IDENTICAL to nq=4)
rel-ε                     = 3.57892  (357.892 %)
GATE: NOT MET
```

The nq=2 run reproduces nq=4 **exactly** (same bound SCF iters=32 / e_band −65.1002 Ha,
same λ=20.0374). The λ=20 is therefore NOT a q-mesh artifact — it is the converged-eigenstate
+ L3-assembler result, robust across q-mesh density. (The L3 α²F→λ assembler integrates the
per-mode coupling; the q-mesh changes only the band-sampling fineness, and both give the same
λ.)

---

## THE FINDING (HONEST, d6/@L5) — OUTCOME (3), with a sharp twist

**The V_NL-bound SCF moves the bare CaH6 λ DRAMATICALLY AWAY from QE, not toward it:**
**λ = 20.0374 vs QE 4.376 (357.9% off) — WORSE than the old 5.47%.**

This is NOT the hoped-for outcome (1) (close to ≤1%). It is a definite outcome (3)-class
result + a critical diagnosis:

1. **The bare gate driver was NEVER on the +2.744-Ha unbound state.** The +2.744→−5.571
   sign flip the sibling agent measured was on the **NPW=64 compose driver with V_NL OFF**
   (`cah6_realcell_compose_xval_vnl.hexa`). The full-basis gate driver
   (`cah6_fullbz_xval.hexa`, n=645, V_NL ON, nprojs=Ca6/H2) was **already bound** even on
   the OLD build: its OLD SCF witness was −10.4161 Ha / e_band −65.2189 Ha (a converged,
   negative-energy state). The V_NL structure-factor fix shifted that already-bound SCF only
   slightly: witness −10.4161 → **−10.3686**, e_band −65.2189 → **−65.1002** (Δ≈+0.12 Ha).

2. **That small eigenstate shift propagates catastrophically into λ.** Σ|g|² barely moved
   (3.69526 → 3.6848). ω_log dropped 1442.75 → 1107 K. But the assembled λ exploded
   4.13647 → **20.0374** (~4.8×). λ = 2∫α²F/ω is dominated by the SOFTEST phonon modes;
   the V_NL-phased eigenstates produced one or more near-soft DFPT modes whose 1/ω² weight
   blows the integral up. The mean dfpt witness even HARDENED (985.96 → 1204.89), so this is
   a single-mode-softening divergence, not a global one.

3. **Therefore the V_NL structure-factor fix does NOT close the bare gate — it OVER-corrects
   it on the full basis.** The OLD 4.137 (5.47%) was, paradoxically, the more QE-accurate
   bare number; the now-physically-more-complete V_NL eigenstates make the from-scratch bare
   |g|²/α²F worse, because the bare (un-screened) vertex amplifies the soft-mode sensitivity
   that QE's ε⁻¹-screening would damp. The accuracy axis is **NOT closed and NOT
   independently QE-grade** on the from-scratch bare path.

### what DID hold (regression-clean)

- **The hybrid xval selftest stays GREEN on the V_NL-fixed build:**
  `qforge_cah6_qe_xval_test PASS` — L3 α²F assembler vs QE λ_BZ rel-ε=**1.6524e-07**
  (≤1%; the 1.65e-7 anchor preserved). It feeds checked-in real QE el-ph bytes into the
  assembler, so it is independent of the SCF eigenstates — confirming the V_NL fix does NOT
  regress the production HYBRID path.

### honest accuracy verdict

The from-scratch bare full-basis CaH6 λ on the V_NL-bound SCF is **20.0374 (357.9% off QE
4.376)** — the bound eigenstates moved it the WRONG way. The accuracy gap is NOT closed by
the V_NL root fix. The migration gate stays **HELD**. The **HYBRID route (QE |g|² → QForge
L3 assembler, rel-ε 1.65e-7) remains the only QE-grade production accuracy path** and is
regression-clean on this build.

### the next residual (named, d2)

The blocker is now sharply re-located: it is NOT the SCF eigenstates (V_NL-complete, bound,
converged) — it is the **bare-vs-screened vertex on the full basis**. The from-scratch bare
|g|² over-weights soft DFPT modes; only the **screened ε⁻¹ vertex** (the Dyson/Anderson
dielectric-feedback fixed point, `screening_anderson.hexa` / the R7 local-field f_xc) damps
that soft-mode divergence the way QE's ε⁻¹-screened |g|² does. Re-running the **R7 ALDA
local-field screened vertex on this bound SCF** is the correct next step — but note: R7's
λ=4.1518 was computed on the OLD eigenstates; on the bound SCF the screened vertex must now
both (a) recover from the bare λ=20 over-weighting and (b) close to ≤1%. That is a larger
task than this gate re-run; the screened-vertex solver convergence on the bound SCF is the
true open residual.

## provenance

- Engine: `hexa-lang/stdlib/qforge/assembler.hexa` V_NL structure-factor fix, commits
  `61d4496b1` + `51e5bb6aa` (branch `qforge-vnl-structfac` = PR #2959, OPEN/unmerged).
- Gate driver: `stdlib/qforge/fixtures/cah6_fullbz_xval.hexa <deck> 0 <nq> 0` (bare vertex).
- Deck: `/Users/mini/dancinlab/demiurge/exports/rtsc/decks/CaH6_NC` (ONCV NC: Ca 6 proj, H 2 proj).
- QE answer-key: λ = 4.376 (CaH6 gate anchor).
- Host: `mini` (Apple M4), native CPU, NO pod. Anchor pod 39610026 NOT touched.
- Logs: `bare_gate_nq4_BOUND.log` (n=645, nq=4) · `bare_gate_nq2_BOUND.log` (n=645, nq=2) ·
  `hybrid_xval_selftest.log` (1.65e-7 PASS).
