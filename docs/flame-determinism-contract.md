# flame determinism contract

The flame **CLMConvMoE** training step is byte-reproducible: a given fixture
produces bit-identical weights, gradients, and loss across runs, and a fused
device kernel reproduces the un-fused host path **byte-for-byte** (`max|Δ| = 0`).
That reproducibility is not incidental — it is *locked* by a series of CPU-local
byte-eq oracles (`hexa run`, 0-GPU), each pinning the **canonical order** the
production code (and any future kernel) must preserve.

This doc is the single contributor-facing index of those locked identities. Every
invariant here traces to a verdict under `.verdicts/hexa-0pod/F-OP*-*.txt` — the
verdict is the evidence; this doc is the map. If you refactor a step phase, the
oracle named below is the one that catches a determinism break.

## the cross-cutting rule

Three facts hold across the whole step. Violate any one and byte-eq silently
breaks (the result still looks numerically "close" — it just stops being
bit-identical).

1. **Two distinct `exp` implementations are each load-bearing.** The step uses
   *different* `exp` functions, picked per phase, and they are NOT
   interchangeable. A "unify the exp" refactor would silently break byte-eq.

   | exp impl | where | source |
   |---|---|---|
   | `dt_exp` (hand-rolled scaled-Taylor, `flame_math.hexa`) | CE **backward** grad (`clm_ce_grad`) AND CE **forward** loss (`nn_ce_loss_allpos`) | F-OP11 · F-OP19 |
   | `_moe_exp` (hand-rolled scaled-Taylor, range-reduce + 14-term) | MoE router softmax | F-OP8 |

   **F-OP19 cross-platform fix (was three impls):** CE-backward `clm_ce_grad`
   formerly used the **libm `exp` builtin**. A 3-platform byte oracle
   (local + ghost arm64-macos vs aiden x86-linux, `f64_to_bytes_le` dump) MEASURED
   that the libm-exp CE-bwd grad **diverges across arch/OS** — 4/4096 grad elements
   differ by exactly **1 ULP** (libm `exp` is not correctly-rounded; glibc vs Darwin
   libm round 4 inputs differently) — while `dt_exp` is **byte-identical on all three
   platforms**. CE-bwd was therefore swapped libm `exp` → `dt_exp` (matching the
   CE-fwd path), on BOTH host and the GPU kernel (`_hx_dt_exp_dev`, the `_moe_exp_dev`
   precedent), so the step is now cross-platform reproducible. Grad change from the
   swap: max abs **2.17e-18**, max rel **≈2.0e-14** (a few ULPs). Trades
   "matches libm" for "matches across ALL platforms" — the flame reproducibility-first
   identity. (`F-OP19-CROSSPLATFORM-EXACT`.)

   **Residual libm hole (latent, not yet closed):** the **GELU** path
   (`nn_gelu_fwd`/`_nn_normal_cdf` and the bwd `_nn_normal_pdf`, plus the fused
   `_gn_gelu`) still calls the libm **`erf`** builtin (fwd) and libm `erf`+`exp` (bwd).
   By the same argument this is a cross-platform hole. It was NOT closed here because
   (a) no bit-accurate deterministic `erf` exists in-tree (`core/special.hexa erf_fn`
   is A&S 7.1.26, ~1.5e-7 off AND itself libm-`exp`-dependent), so a deterministic erf
   is a larger numeric change + a separate impl, and (b) `erf` is too new for some
   pool runtimes to even link — measured as a `hexa_math_erf`-undefined link failure on
   aiden's prebuilt runtime, so the GELU erf path could not be cross-platform measured
   there. Documented as a latent risk / follow-up.

   These are separate code paths. Swapping one for another (Taylor ↔
   `_moe_exp`) changes the bits. (The hand-rolled `sqrt` impls are
   likewise per-phase and load-bearing: `_gn_sqrt` = 40-iter Newton for GroupNorm
   — F-OP9; `_adamw_sqrt` = 24-iter Newton for the optimizer denominator —
   F-OP12; neither is libm.)

2. **Reductions are SEQUENTIAL — no tree re-association.** Every sum (softmax
   denominators, GroupNorm mean/variance, GEMM/conv contractions, the MoE
   combine) accumulates in a fixed scalar order. A warp-shuffle / tree reduction,
   or a Welford streaming mean/var, is float-non-associative against the locked
   sequential order and breaks `max|Δ| = 0`. (F-OP8, F-OP9, F-OP11.)

3. **Accumulations are ASCENDING-order.** Where order is a free choice it is
   pinned ascending: softmax denominators sum **v-ascending**; the MoE combine
   sums **e-ascending**; the CE forward loss sums **t-ascending**; the embedding
   backward scatter-add accumulates shared-token rows **position-ascending**;
   GroupNorm sums in **(t-outer, c-inner)** order; conv/GEMM contractions run
   **j-ascending** (`j = ci*K + k`). (F-OP7/8/9/11/13.)

## per-phase locked identities

Each row = one step phase, its oracle, the canonical-order invariant it locks,
and the refactor that breaks it. "Identity" is `max|Δ| = 0` (true byte-eq, no
tolerance) unless noted.

| step phase | oracle file (`.verdicts/hexa-0pod/`) | canonical order locked | what breaks it |
|---|---|---|---|
| **INPUT** — token-embedding backward (scatter-add) | F-OP13-EMBED-RESIDUAL-ORACLE | shared-token row grads accumulate **position-ascending** (i = 0..T-1, in-place); mirrors `nn_embedding_bwd_scatter` | a gather-then-grouped-sum reorder, or GPU atomic-scatter, that drops position-ascending — descending diverges ~1e-13 on repeated-token rows (honest probe) |
| **FWD conv** — forward causal-dilated conv1d | F-OP7-CONV-IM2COL-EQ | im2col + GEMM == direct sliding-window conv; contract over `Kdim` **j-ascending** (`j = ci*K + k`), ci-outer k-inner; zero-pad p<0 → 0 | reorder the im2col layout or swap the contraction axis order |
| **NORM** — conv→GroupNorm→GELU "valley" | F-OP9-LN-REDUCTION-ORACLE | **two-pass** mean/var (NOT Welford) summed **(t-outer, c-inner)** sequential; `inv = 1/_gn_sqrt(var + eps)`, **eps = 1e-5**, `_gn_sqrt` = 40-iter Newton; GELU = erf-based CDF `x·0.5·(1+erf(x/√2))` (libm `erf`) | tree/warp-shuffle reduce the mean/var, switch to Welford, drop eps, reorder (t,c), or hand-Taylor the GELU |
| **MoE** — router softmax + expert combine | F-OP8-MOE-COMBINE-EQ | two-pass form == one-pass fused; softmax with **max-subtraction ON**, denom summed **e-ascending** sequential; exp = `_moe_exp`; combine Σ_e **e-ascending** per (t,c) | tree-reduce the softmax sum or combine, drop max-subtraction, reorder the expert axis, or swap `_moe_exp` |
| **LOSS bwd** — CE + softmax fused gradient | F-OP11 · F-OP19 | `dL/dlogits[t,v] = (softmax[v] − [v==tgt])/T`; exp = **`dt_exp`** (F-OP19, was libm `exp`); per-row max-sub ON; denom **v-ascending** sequential; write `p·invT` for all v, **THEN** `dlogits[tgt] −= invT` (scale-then-subtract; do NOT refold to `(p−1)·invT`) | tree-reduce denom, drop max-sub, swap exp impl (libm exp diverges across arch/OS — F-OP19), or refold the target subtraction (the `(p−1)·invT` fold is float-different — ~1.39e-17) |
| **LOSS fwd** — mean NLL | F-OP11-CE-SOFTMAX-ORACLE | `L = (1/T) Σ_t −ln(softmax[tgt_t])`; exp = **`dt_exp`**, ln = **`dt_ln`** (Taylor, NOT libm, NOT `_moe_exp`); per-row max-sub ON; denom **v-ascending**; `p_t` clamped ≥ 1e-6; loss summed **t-ascending**; mean = total/T | swap exp/ln impl, tree-reduce the denom, drop max-sub or the ≥1e-6 clamp, or reorder the t-sum |
| **BWD dW** — backward weight-gradient GEMM (transpose-elim) | F-OP2-TRAINER-WIRE | `im2col + matmul_t` dW == `im2col_t + matmul` dW; contract over the **same t/m dimension, same ascending order** (`xcolT[j,t] == xcol[t,j]`) | reorder the contraction; on GPU the cuBLAS OP_T Dgemm is an fp-accum-order variant of OP_N (rel-RMS ~1e-14, the documented identical-tolerance lane — not a regression) |
| **OPTIMIZER** — AdamW decoupled-wd update | F-OP12-ADAMW-UPDATE-ORACLE | SSOT `_hx_farr_adamw_step_cpu`: `v = β2·v + ((1−β2)·g)·g` (**left-assoc**, NOT `(1−β2)·(g·g)`); `m̂ = m/c1` **before** `v̂ = v/c2`; `denom = √v̂ + ε` (**ε outside √**, `_adamw_sqrt` 24-iter Newton held constant); `W' = (W − lr·wd·W) − lr·(m̂/denom)` (two separate subtractions, decoupled-wd first); `c1,c2 = 1−βᵗ` by repeated-mul (not `pow`) | refold `(1−β2)·g·g` to `(1−β2)·(g·g)` (diverges ≤8.88e-16), reorder the bias-correction divides, move ε inside √, or swap the sqrt impl |

### the one known non-zero spot — B>1 conv seam

The batched step (`CLM_PROD_BATCH = B > 1`) concatenates B distinct length-`Tw`
windows into one length-`T = B·Tw` buffer and convolves the whole sequence. This
is **not** bit-exact to a per-window-segmented conv — and that is *intended*,
characterized by **F-OP10-CONV-SEAM-ORACLE**:

- **interior is bit-exact** (`max|Δ| = 0`, every non-seam position genuinely 0).
- **the seam = exactly the first `(K-1)·dil` output positions of every window
  after the first.** The seam Δ is the cross-window causal context that a
  segmented conv zeros. (`dil=1` ⇒ band `K-1`; dilated trunk convs widen it to
  `(K-1)·dil`.)

So `B>1` is reproducible run-to-run (the concat path is deterministic); it is
just not *identical* to a segmented conv at the window seams. A true
`max|Δ| = 0` batched step would need a per-window-segmented causal conv.

## step-phase map

```
  ids ──[INPUT embed gather]──> X
        (bwd scatter-add: position-ASCENDING)            F-OP13
          │
          ▼
   ┌─ trunk block (xN) ───────────────────────────────────┐
   │  [FWD conv1d]   im2col + GEMM  (j-ASCENDING contract)  │  F-OP7  (fwd)
   │       │          dW: transpose-elim, same-order sum    │  F-OP2  (bwd)
   │       ▼          (B>1 seam: first (K-1)·dil pos)        │  F-OP10
   │  [NORM]  GroupNorm two-pass mean/var (t-out,c-in)       │  F-OP9
   │       │  + _gn_sqrt(var+eps=1e-5) + erf-GELU  (valley)  │
   │       ▼                                                 │
   │  [MoE]   softmax (_moe_exp, max-sub, e-ASC denom)       │  F-OP8
   │          combine Σ_e e-ASCENDING                        │
   └────────────────────────────────────────────────────────┘
          │
          ▼
   [LOSS]  fwd: mean NLL  (dt_exp/dt_ln, t-ASC, clamp 1e-6)  F-OP11 (fwd)
           bwd: (softmax−onehot)/T  (dt_exp, v-ASC denom,   F-OP11/OP19 (bwd)
                scale-then-subtract at tgt)
          │
          ▼
   [OPTIMIZER]  AdamW: v=β2·v+((1−β2)·g)·g (left-assoc),     F-OP12
                m̂/c1 before v̂/c2, √v̂+ε (ε outside √),
                W'=(W−lr·wd·W)−lr·(m̂/denom)
```

Two exp impls live in this diagram: **`_moe_exp`** (MoE) and **`dt_exp`** (loss
fwd AND loss bwd — the latter swapped from libm `exp` in F-OP19 for cross-platform
byte-exactness). Each is load-bearing. (The GELU `erf` is a still-open libm hole —
see §1 residual.)

## what breaks the contract

A non-exhaustive checklist — any of these silently breaks `max|Δ| = 0`:

- **Unifying the exp.** Two impls (`dt_exp` / `_moe_exp`) by design. (CE-bwd was
  libm `exp` until F-OP19 swapped it to `dt_exp` for cross-platform byte-eq —
  do NOT revert it to libm `exp`: that re-opens the arch/OS divergence.)
- **Tree / warp-shuffle reductions** anywhere a sequential sum is locked.
- **Welford** streaming mean/var in GroupNorm (the locked form is two-pass).
- **Reordering an accumulation axis** away from the locked ascending order.
- **Dropping max-subtraction** in any softmax, or the eps/clamp constants
  (`eps = 1e-5` GroupNorm, `≥ 1e-6` CE-fwd clamp).
- **Refolding the CE-bwd target subtraction** (`p·invT` then `−invT`, not
  `(p−1)·invT`).
- **Refolding the AdamW squared-grad term** (`((1−β2)·g)·g`, not `(1−β2)·(g·g)`),
  or moving ε inside the √.
- **Hand-rolling `erf`/`sqrt`** where a libm builtin (`erf`, in GELU) or the specific
  Newton seed (`_gn_sqrt`, `_adamw_sqrt`) is locked — but note the GELU libm `erf` is
  itself a known cross-platform LATENT hole (F-OP19 §1 residual): on a SINGLE machine
  it is byte-eq, across arch/OS it can differ by ULPs like libm `exp` did. A
  deterministic erf is the eventual fix (a numeric change), not a regression.

## adding a new oracle

Mirror the OP-7/8/9/11/12/13 pattern: add `stdlib/flame/clm_prod_<phase>_eq.hexa`
that (a) replays the production op order byte-for-byte, (b) compares it to a
definitional / re-layout reference visiting the *same* ops in the *same* order,
gating `max|Δ| = 0` (`hexa run`, CPU, 0-GPU, $0). Write the verdict to
`.verdicts/hexa-0pod/F-OP<N>-<NAME>-ORACLE.txt` documenting the **CANONICAL
ORDER** block (exp impl + reduction/accumulation order + sqrt impl + eps
placement) and the "what breaks it" warning, then add a row to the tables above.
Honest framing (g5): a genuine reorder identity gates exactly 0 — if a tolerance
is needed, document the associativity gap as an honest probe, do not hide it.
