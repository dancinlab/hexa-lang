# mbs-revival-holevo-central-revival

> Submission to `atlas/inbox/` (one concept = one file).

## Concept

The **paper headline** of Xiang et al. 2024 (arXiv:2410.15455 / paper
Fig. 4b–c) is that the Holevo information `X_c(t)` at the central
site of a PXP-Rydberg chain — initially seeded as one bit between
`|Z2⟩` and `σ̂ˣ_c|Z2⟩` — propagates outward along a linear light
cone, **collapses** near `t ≈ T_rev_wf/2`, then **revives back to
the central site** near `t ≈ T_rev_wf` with `T_rev_wf ≈ 9.57/Ω`. The
qualitative invariant is the **dip-then-revive** structure:

    X_c(T_rev_wf / 2)   <   X_c(T_rev_wf)               (dip then revive)
                  AND   X_c(T_rev_wf)   >   ε_revive    (visible refocusing)

i.e., the central-site Holevo information at one full revival period
is greater than at half-period AND substantially nonzero (paper
Fig. 4b/c: the on-axis trace at site `c` recovers a finite-fraction
peak). This is **not** a closed-form value — it's the qualitative
collapse-and-revival structure that defines the experiment's
headline. Numerical witness at `N = 8` strict-PXP:

    X_c(0)            = 0.693147   (closed form, separate atom)
    X_c(T_rev_wf/2)   = 0.010833   (collapse — info has left site c)
    X_c(T_rev_wf)     = 0.646374   (revival — info refocused at c)
    revival fraction  = 0.646374 / 0.693147 ≈ 93.3% of initial

So `X_c(T_rev_wf) / X_c(T_rev_wf/2) ≈ 60×` — a sharp dip-then-revive
contrast. This is the time-domain analogue of the spatial light cone
in Fig. 4b/c.

## Hexa-native verification

The sim-universe `mbs-revival/module/mbs_revival.hexa` (compiled
native to `state/mbs_bin`) selftest emits the trajectory directly:

    Holevo dip/rv : X_c(T_rev/2)=0.010833, X_c(T_rev)=0.646374 (OK)

Sentinel:

    __SIM_UNIVERSE_MBS__ PASS N=8 state=selftest mode=selftest
        Ftrev=0.796511 norm_drift=0.000000

Build + run command:

    bash state/ubu-build.sh \
        mbs-revival/module/mbs_revival.hexa \
        mbs_bin --selftest

Recompute path: 2nd-order Strang–Trotter on the strict-PXP
Hamiltonian for `N_steps = 400` steps over `tmax = 1.5 T_rev_wf`,
1-site reduced density matrix via amplitude trace, closed-form 2×2
von Neumann entropy `S = −λ₊ ln λ₊ − λ₋ ln λ₋` evaluated three times
per probe time (`ρ`, `ρ'`, `(ρ+ρ')/2`).

The recompute path is **expensive** for a Stage 2 atlas verifier
(requires a 2ᴺ state-vector evolution + 4-stage Strang–Trotter
trajectory + 2×2 partial-trace at each timestep). The atlas-verifier
side therefore registers only the **qualitative structural claim**
(`X_c(T_rev_wf) > X_c(T_rev_wf/2)` with a sharp ratio); the
numerical evidence lives in the sim-universe binary selftest, NOT
in `compiler/atlas/verify/`.

## Proposed verdict

- **Tier:** 🟡 **SUPPORTED-BY-CITATION** — the dip-then-revive
  structure is a sim-universe selftest invariant carried by the
  `mbs-revival` binary (sentinel-evidenced); a Stage 2 verifier
  inside `compiler/atlas/verify/` would need to build a 2ᴺ state-
  vector engine + Strang–Trotter integrator + 2×2 partial-trace
  routine — out of scope for the atlas verifier (which is meant for
  *small closed-form recomputes*). The atom carries the inbox
  markdown as the **proof carrier** and the sim-universe binary as
  the **numerical witness**.
- **Axis:** §3 PHYS · cross-link §2 MATH (`ln 2` initial closed-form
  value lives in the sibling atom `mbs-revival-holevo-initial-
  ln2.md`).
- **Real-limit anchor (`g3`):**
  - **Xiang, Zhang, Liu et al.**, arXiv:2410.15455 (2024), Fig. 4b/c
    (Holevo light cone + central-site revival) · Eq. L301 (Holevo
    formula) · Methods L363 (Hamiltonian parameters).
  - **Turner, Michailidis, Abanin, Serbyn, Lukin**, *Weak ergodicity
    breaking from quantum many-body scars*, **Nat. Phys. 14, 745
    (2018)** · arXiv:1711.03528 — PXP scar revival period
    `T_σ ≈ 4.78/Ω` (the local-observable period; wavefunction
    return `T_rev_wf = 2 T_σ`).
- **Provenance:** sim-universe commit (mbs-revival landing) ·
  `mbs-revival/module/mbs_revival.hexa::_run_holevo` · AGENTS.tape
  `@D g11` · `@X x_xiang_mbs`.

## Falsifiers (pre-registered, ≥5)

1. **`F1_no_dip`** — if `X_c(T_rev_wf/2) > X_c(T_rev_wf)`, the
   information is leaving the central site monotonically (no
   revival). Selftest must report a strict dip: `X_c(T_rev_wf/2)`
   substantially less than `X_c(T_rev_wf)`. If the inequality
   reverses, the model does not show the paper's headline phenomenon
   — falsified.
2. **`F2_no_revival`** — if `X_c(T_rev_wf) ≤ X_c(T_rev_wf/2) + 0.05`
   (small tolerance), no detectable refocus at the centre. Selftest
   demands `0.646374 ≈ 60× the 0.010833 dip value`. A ratio < 5
   falsifies the revival.
3. **`F3_wrong_period`** — replace `T_rev_wf = 9.57/Ω` with
   `T_rev_wf = 4.78/Ω` (the local-observable period). The
   wavefunction returns to `|Z2⟩` at *twice* that — at `4.78/Ω` the
   wavefunction is at `|Z2'⟩` (the partner state), so the Holevo
   *DOES NOT* refocus at the central site (it sits at the partner).
   Atom must use `T_rev_wf = 2 T_σ`. If the verifier uses `T_σ`
   directly and still reports a revival at `4.78/Ω`, falsified.
4. **`F4_full_rydberg_vs_pxp`** — repeat the selftest with the full
   Rydberg engine (`--otoc` without `--pxp`) at the paper's
   parameters `V_NN/Ω = 6, V_NNN/Ω = 0.11`. The revival should
   persist (the PXP projection is the strong-blockade limit), but
   slightly weaker. If the full-Rydberg `X_c(T_rev_wf)` is *zero*
   while strict-PXP is `0.65`, the dynamics is dominated by NNN
   leakage and the PXP picture is misleading — falsified for the
   "PXP-scar mechanism" interpretation.
5. **`F5_thermal_initial_state`** — replace the `|Z2⟩` initial state
   with `|0⟩ = |↓↓…↓⟩` (Néel-trivial, thermal-eigenstate subspace).
   The paper (Fig. 3g–k) shows `|0⟩` decays rapidly inside a
   *linear* light cone with **no revivals**. If the verifier reports
   a revival from `|0⟩`, the scar selection rule is broken —
   falsified for the "scar revival" interpretation.
6. **`F6_finite_size_scaling`** — the revival amplitude
   `X_c(T_rev_wf)` is finite-N-dependent. At `N = 6` strict-PXP it's
   one value, at `N = 8` another (the witness here), at `N = 10`
   another. The atom registers the *qualitative dip-then-revive
   structure*, NOT a specific numerical value. If a reviewer
   interprets `0.646374` as the thermodynamic-limit answer, that's
   wrong: the `L → ∞` limit strictly decays (Turner et al. 2018;
   Khemani-Laumann-Chandran 2019). The finite-N witness here is
   honest; over-claiming `L → ∞` survival is falsified by the
   theory anchor.

## Open questions / risks

- **Atlas Stage 2 implementability.** A clean atlas verifier for this
  atom would need a small (N = 4 or 6) strict-PXP Strang–Trotter
  engine inside `compiler/atlas/verify/`. That's a non-trivial
  ~200-LoC addition. Deferred — the sim-universe binary IS the
  authoritative witness, the inbox markdown carries the claim. This
  is the same pattern as `qdarwin-touil-2022-route-AB-six-decimal-
  identity.md` which was 🟡 SUPPORTED-BY-CITATION until the
  classical-limit closed form was extracted to Stage 1 in 7dec53d4.
  A future "central-site Holevo dip-revive in a closed-form limit"
  reduction would upgrade this atom.
- **Definition of "revival."** Paper uses "collapse-and-revival" for
  both the OTOC and Holevo lights cones. Here we register the Holevo
  half. The OTOC half (`F_{c,c}(T_rev/2) < F_{c,c}(T_rev)`) is the
  sister invariant — could be a separate atom.

## Reviewer checklist

- [ ] Tier (🟡 SUPPORTED-BY-CITATION recommended, with sim-universe
      binary as numerical proof carrier).
- [ ] Axis (§3 PHYS).
- [ ] Falsifiers ≥5 (six pre-registered above).
- [ ] Real-limit anchor (g3) verified — Xiang 2024 + Turner 2018.
- [ ] Merge to `atlas/MAIN.tape § PHYS` with the sim-universe binary
      sentinel as the proof carrier (mirrors the qdarwin pre-7dec53d4
      pattern).

---

Submitter: claude-opus-4-7 (sim-universe absorption cycle, 2026-05-16).
Origin: sim-universe `mbs-revival/`.
