# DEFER — "Multilayer non-lift: σφ=nτ across the geometric+Hecke+Galois+L-function towers"

> **Gate test outcome: DEFERRED** (TECS-L /paper batch queue INBOX #10, item 3/3).
> **F7 + F15 + F16 + F17 unified.** This paper does NOT clear `paper_gate` because
> two of its four core-section claims (Hecke, Galois, L-function) are **non-terminal**
> (🟠 INSUFFICIENT / 🟡 CITATION). An honest DEFER, per the task's explicit gate-test
> framing — **not** a failure to hide.
>
> **This DEFER is the predicted outcome of `TECS-L/docs/f26-rfc-finite-vs-analytic.md`**
> (PR #1459): the geometric layer is finite-arithmetic (TECS-L strong, 🔵/🔴-terminal),
> while the Galois + L-function layers are analytic-infinite (TECS-L weak, 🟠), and the
> Hecke-eigenvalue (T_p) object falls in the calc-gap family #1230 (no hexa calc-path).

## Date / discipline

- 2026-05-27 · g5 verify-via-CLI-only (`/Users/ghost/.hx/bin/hexa verify --expr`) · all verdicts pasted VERBATIM in the sibling `*_layer.txt` files in this directory.

## 4-layer tier matrix (the GATE VERDICT)

| # | Layer | Claim (at n=6 / N=6) | Tier | Evidence (verbatim verdict ptr) |
|---|-------|----------------------|------|---------------------------------|
| 1 | **Geometric** | σφ=nτ ⟺ n∈{1,6}; modular-curve index tower (Γ₀→Γ₁→Γ(N)) has NO n=6 peak — closed-negative | **🔵 + 🔴 (TERMINAL)** | `geometric_layer.txt` — σ(6)=12, φ(6)=2, τ(6)=4 all 🔵; locus σφ=nτ holds {1,6}, fails n=2,7. Γ(N)-index 🔴 closed-negative cited from `.verdicts/tecs-l-f15-novel-mk10/gamma_full_level_index.txt` (10 gamma0_index/phi 🔵) |
| 2 | **Hecke** | n=6 identity does NOT lift to Hecke-eigenvalue (T_p) layer; S_k(Γ₀(6)) decomposes generically into level-1/2/3 oldforms, no n=6 peak | **🟡 CITATION / 🟠 INSUFFICIENT (NON-TERMINAL)** | `hecke_layer.txt` — modular invariants @ N=6 (gamma0_index/cusps/genus, first_cusp_form_weight) 🔵, BUT **`hecke_eigenvalue` / `hecke_ap` → 🟠 INSUFFICIENT (no calc-path)**. `dim_cusp_forms(6,2)=0`, `(6,4)=1` coincide @ small (N,k) 🔵, but `dim_cusp_forms(1,12)` returns calc=0 → **🔴 FALSIFIED** (MF4 gap: misses Δ). Builtin is NOT a sound dim-S_k computer ⇒ non-lift rests on Diamond–Shurman CITATION, not hexa verify |
| 3 | **Galois** | n=6 identity does NOT lift to Galois-representation layer; Gal(Q(ζ₆)/Q)=Z/2Z = Gal(Q(ζ₃)/Q) (ζ₆=−ζ₃ collapse) — φ-degeneracy only | **🟠 INSUFFICIENT (NON-TERMINAL)** | `galois_layer.txt` — \|Gal(Q(ζ_n)/Q)\|=φ(n) component 🔵 (φ(6)=φ(3)=φ(4)=2 ⇒ no n=6 distinction), BUT **`galois_rep_dim` / `galois_cohomology` → 🟠 INSUFFICIENT (no calc-path)**. The representation/cohomology object is structural/analytic, out-of-scope |
| 4 | **L-function** | n=6 carries NO spectral fingerprint via canonical wt-2 newform L(s,f); X₀(6) genus 0 ⇒ J₀(6) trivial ⇒ no wt-2 newform | **🟠 INSUFFICIENT / 🟡 CITATION (NON-TERMINAL)** | `lfunction_layer.txt` — genus-0 basis (`gamma0_genus(6)=0`, `dim_cusp_forms(6,2)=0`) 🔵, BUT the **L-function object itself (`l_value` / `l_function_special_value` / `lfunction_nonvanishing`) → 🟠 INSUFFICIENT (no calc-path)**. Euler products / special values / algebraicity are analytic-infinite, explicitly citation-fenced in `.verdicts/tecs-l-f17-novel-mk10/L_function_gamma_0_6_probe.txt` |

## Gate decision

`paper_gate` requires **EVERY** core section claim to be terminal (🔵 / 🟢 / 🔴). Here:

- Layer 1 (Geometric): **terminal** ✅ (🔵 components + 🔴 closed-negative).
- Layer 2 (Hecke): **NON-terminal** ❌ — load-bearing T_p object 🟠; `dim_cusp_forms` calc-gapped (🔴 on (1,12)); non-lift conclusion anchored on 🟡 citation.
- Layer 3 (Galois): **NON-terminal** ❌ — representation/cohomology object 🟠.
- Layer 4 (L-function): **NON-terminal** ❌ — L-value/special-value object 🟠 (analytic-infinite).

**3 of 4 layers are non-terminal ⇒ DO NOT SCAFFOLD. DEFERRED.**

A multilayer paper would require forcing a single thesis ("σφ=nτ does NOT lift past
the arithmetic layer") whose Hecke/Galois/L-function support is 🟡/🟠. Per
`paper_negative_ok`, a closed-negative is publishable **only when it is terminal**:
"we could not compute the analytic layer" (🟠) is precisely the non-terminal case the
RFC §8 (iii) excludes. Forcing the paper = `paper_violation` (immediate revocation).

## What WOULD lift this DEFER (calc-path requirements — INBOX, calc-gap family #1230)

1. **`hecke_eigenvalue` / T_p builtin** in `tool/verify_cli.hexa::_recompute` — a_p(f) for newform f at level N, weight k. Would move the Hecke layer from 🟡 citation to 🔵/🔴.
2. **`dim_cusp_forms` MF4 gap fix** (returns true dim S_k including Δ at (1,12)) — currently 🔴-falsifiable; until fixed the wt-4 L-function piece cannot be hexa-grounded.
3. **L-function machinery** (Euler product, special value, non-vanishing) — analytic-infinite; per RFC §3 this is the TECS-L weak axis (rational ≠ transcendental boundary), so this likely stays 🟠 indefinitely.
4. **`galois_rep_dim` / cohomology** primitive — structural/analytic; same out-of-scope class.

## Provenance / cross-links

- Geometric layer flagship (TERMINAL, already a paper): `PAPER/tecs-l-omega-zero-density/` (D(n)=σφ−nτ=0 ⟺ n∈{1,6}, 🔵).
- Hecke/Galois closed-negative coda already folded as atlas atom: `@F tecs_l_f16_hecke_galois_arithmetic_layer` (embedded.gen.hexa:35647) — but that atom self-labels its Hecke probe "BOUNDED by calc-gap, T_p builtin not in verify_cli" — i.e. the atom itself records the non-terminal status; it does not upgrade the layer to terminal.
- Companion existing paper covering the Γ₁/X(N) geometric non-lift (F7): `PAPER/tecs-l-modform-n6-nonlift/` (already shipped; its F7 finding is the 🔴 geometric closed-negative this multilayer paper would have re-used as Layer 1).
- Methodology SSOT: `TECS-L/docs/f26-rfc-finite-vs-analytic.md` — §2 table row F16/F17, §4 matrix (T_p eigenvalue → 🟡, L' → 🟠), §6 MILLENNIUM analytic-infinite scope declaration. **This DEFER is a live confirmation of that RFC's prediction.**
- Layer verdicts (verbatim): `geometric_layer.txt`, `hecke_layer.txt`, `galois_layer.txt`, `lfunction_layer.txt` (this directory).

## Final queue status (INBOX #10, 3/3 — last item)

| # | Paper | Status |
|---|-------|--------|
| 1 | ω-zero-density theorem (D(n)=σφ−nτ=0 ⟺ n∈{1,6}) — flagship | **LANDED** (`PAPER/tecs-l-omega-zero-density/`) |
| 2 | Unitary-perfect singleton at n=6 (σ\*(6)=12) | sibling agent (σ\* primitive 🔵, PR #1465) |
| 3 | **Multilayer non-lift (this item)** | **DEFERRED** — 3/4 layers non-terminal (Hecke 🟡/🟠, Galois 🟠, L-function 🟠); confirms finite-vs-analytic RFC |
