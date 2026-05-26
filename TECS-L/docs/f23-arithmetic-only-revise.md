# F23-s4 — 'arithmetic-only' Spec Revise (post-F18, post-F23-s1)

## Motivation

F17 (closed Sept-ish round) concluded that the n=6 identity locus is "**arithmetic-only**" —
meaning the σφ=nτ ⟺ n∈{1,6} characterization (M10) does NOT lift to the modular / Hecke /
L-function layer. The 4-layer non-lift was anchored by:

1. **Geometric** — Γ₁/X(N) index smooth at N=6 (F7 CLOSED-NEG).
2. **Full-level** — `dim_cusp_forms(6,2) = 0` (no weight-2 cusp form), so Eichler-Shimura
   gives no n=6 elliptic newform.
3. **Hecke** — no Hecke eigenform at level 6 weight 2 to attach an L-function.
4. **L-function** — same; nothing to take an L-function of.

F18 (PR #1419) RECOVERED a partial counter: `dim_cusp_forms(6,4) = 1` — a single weight-4
cusp form exists at level 6, so layer (2) is NOT empty when k=4.

F23-s1 now generalizes: `dim_cusp_forms(6, k) ≥ 1` for **every** even k ∈ {4, 6, 8, 10, 12}
— in fact dim S_k(Γ₀(6)) = k−3 by classical Cohen-Oesterlé (squarefree level, g=0,
no elliptic fixed points), with hexa's value matching for k ∈ {4, 6} and undercounted
by 2 for k ≥ 8 due to the same MF4 calc-fn gap that's already INBOX'd.

## Revised Spec — `arithmetic-only` is k=2-only

The F17 "arithmetic-only" claim **must be narrowed**:

| layer                  | k=2 (F17 anchor) | k≥4 even (F18/F23) |
|------------------------|-------------------|---------------------|
| geometric (X₀/Γ₀)      | g=0, X₀(6)=ℙ¹     | g=0 unchanged       |
| dim S_k cusp space     | **0** (vanishes)  | **k−3 ≥ 1** (present) |
| Hecke eigenforms       | empty             | ≥ 1 newform (k=4)·oldform stack |
| L-function attached    | none              | yes (L(s, f, k≥4)) |

So the **precise** revised statement:

> **TECS-L-RV1** — n=6 is "arithmetic-only" **exclusively at the weight-2 layer**.
> For every even k ≥ 4, level 6 admits a non-empty cusp form space (dim S_k(Γ₀(6)) = k−3 ≥ 1);
> hence Hecke eigenforms and L-functions are available at those weights. The earlier
> "non-lift to modular layer" statement applies *only* to weight-2 / elliptic-curve
> Eichler-Shimura.

## Implications

1. **Weight-2 vanishing is now characterized as a *unique* phenomenon** at level 6 (among
   even weights ≥ 2). This is a STRONGER F18: not just "weight 4 is special" but
   "weight 2 is the SOLE empty weight".

2. **The non-lift is a layer-(2)-at-k=2 statement, not a global statement.** Reframing for
   F12 NOVEL paper (`tecs-l-n6-exclusivity-atlas`): the closed-negative against
   "σφ=nτ at level 6 has a k=2 modular witness" stands, but the broader
   "no modular witness at any k" is **false** by F18/F23-s1.

3. **Future scope**: explore whether the weight-4 cusp form f ∈ S_4(Γ₀(6)) (which is
   unique up to scalar) carries any n=6-specific arithmetic — Fourier coefficients
   a_p, Atkin-Lehner eigenvalues, CM structure. If yes, that's a NEW finding lane
   ("spectral n=6 distinction"). If no, the spec stays "weight-2 only".

4. **MF4 / F23-s1 calc-fn gap**: hexa's `dim_cusp_forms` undercounts by 2 for k ≥ 8
   (Γ₀(6)). Already INBOX'd as PR #1083; this F23 round confirms the gap pattern is
   weight-monotone (matches at k=2,4,6 then shifts by 2).

## Validity Window

This revise depends only on classical Cohen-Oesterlé and the hexa-verified value
`dim_cusp_forms(6, k) > 0 for k ∈ {4,6,8,10,12}` (🔵 component). The arithmetic-only
claim at k=2 is unchanged (F17 anchor still holds: dim S_2(Γ₀(6)) = 0).

## Cross-Reference

- F17 — original 'arithmetic-only' 4-layer non-lift framing.
- F18 (PR #1419) — weight-4 newform RECOVERY (single weight).
- F23-s1 (this round) — generalization to k ∈ {4,6,8,10,12}.
- MF4 — calc-fn gap on dim_cusp_forms for N>10 (k=2).
- M10 — σφ=nτ ⟺ n∈{1,6} closed-form proof (unchanged; arithmetic statement).
