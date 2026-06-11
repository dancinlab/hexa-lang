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

> For the consolidated *result* — the publishable
> **machine-independent bit-exact training** claim (cross-platform byte
> measurements, threat model, evidence table, honest limits) — see
> [`flame-machine-independent-training.md`](flame-machine-independent-training.md).

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

   **F-OP19b cross-platform fix (GELU erf — the last libm transcendental):** the
   **GELU** path (`nn_gelu_fwd`/`_nn_normal_cdf`, the bwd `_nn_normal_pdf`, the fused
   `_gn_gelu`, and the device + host-C-fallback twins) formerly called the libm
   **`erf`** builtin (fwd) and libm `erf`+`exp` (bwd) — the same cross-platform hole
   class. It is now swapped to **`dt_erf`** (`flame_math.hexa`): Abramowitz & Stegun
   7.1.26 rational with the exp routed through `dt_exp` — pure `+ − × ÷` + `dt_exp`,
   **no libm**, and **BRANCHLESS in z** (only the z=0 odd sign flip). The branchless
   form is load-bearing: a piecewise series-then-clamp/tail erf straddles its branch
   boundary under in-register-vs-stored-reload rounding of the GELU argument and breaks
   `max|Δ|=0`; the unconditional A&S form has no boundary to straddle. The det-erf GELU
   fwd+bwd byte fold is **byte-identical on local+ghost arm64-macos AND aiden x86-linux**
   (`F-OP19B`). Accuracy: max|dt_erf − libm erf| = **1.38e-7** (≤ the GELU tolerance) —
   trades "matches libm erf" for "matches across ALL platforms". (The libm-erf path
   couldn't even be cross-platform measured: `hexa_math_erf` is undefined on aiden's
   prebuilt runtime — link failure.) **With this + F-OP19's `dt_exp`, the step has NO
   libm transcendental left** (exp/erf/ln Taylor, sqrt Newton) → flame is FULLY
   machine-independent byte-exact. (`F-OP19B-DET-ERF`.)

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

### cross-ISA invariant: matmul = inline ascending reduction, NOT FMA-fused

> **RULE.** Any flame matmul on the determinism-critical path **must accumulate
> via inline ascending reductions** (plain `acc = acc + a*b` in hexa codegen).
> The C runtime `farr_matmul` kernel (`tensor_lib`: ikj order, FMA-fused under
> clang -O2) is **NOT cross-ISA byte-identical** and is therefore **forbidden on
> the determinism path**. (F-OP29-2ND-ARCH.)

This is the **third determinism layer** — the cross-ISA layer that sits *on top
of* the run-to-run + libm-free layers in §1. A model can be perfectly run-to-run
deterministic (a fixed sequential order, no uninit scratch) **and** libm-free
(every transcendental hand-rolled `dt_*`) and **still byte-diverge across ISAs**
if any matmul on its path routes through the FMA-fused kernel. The three layers
are independent — clearing the first two does **not** clear this one.

```
  3 INDEPENDENT determinism layers (each must hold for machine-independence):

   layer 1  RUN-TO-RUN          same machine, twice → max|Δ|=0
            (sequential order · no uninit scratch · no addr-ordered iteration)
              └ OP-2/7/8/9/11/12/13 + OP-15 capstone

   layer 2  libm-FREE           any transcendental → bit-identical on any IEEE-754
            (dt_exp/dt_erf/dt_ln/_moe_exp + Newton sqrt, NO libm)
              └ OP-19 (CE-bwd exp) · OP-19b (GELU erf)

   layer 3  cross-ISA-FMA-FREE  a*b+c contraction → same bytes on arm64 AND x86
            (inline ascending reductions, NOT the FMA-fused farr_matmul kernel)
              └ OP-29  ← THIS invariant
```

**WHY — the FMA-fusion divergence (F-OP29).** clang -O2 contracts a
multiply-then-add (`a*b + c`) into a **single fused-multiply-add** on arm64 (one
rounding) but emits a **separate `mul` then `add`** on x86 (two roundings). The
two forms produce a sub-ULP-different fp64 accumulation, so an *accumulating*
matmul returns different bytes per ISA — even on byte-identical inputs. OP-29
isolated this exactly: feeding the `farr_matmul` kernel byte-identical fp64
operands (`W` checksum `1950370123`, `xbt` checksum `527426024` on **both**
ISAs), an 8×8·8×4 matmul returned

```
   farr_matmul (FMA-fused C kernel)        inline ascending acc = acc + a*b
   ───────────────────────────────        ──────────────────────────────────
     arm64-macos  C ck = 241449363           arm64-macos  ck = 1401117690
     x86-linux    C ck = 1401117690    →      x86-linux    ck = 1401117690
            ↑ DIVERGES (FMA vs mul+add)            ↑ MATCHES (no fusion)

   arm64:  fma(a, b, c)        → 1 rounding   ┐ different fp64 result
   x86 :   add(mul(a,b), c)    → 2 roundings  ┘ → sub-ULP per-ISA divergence
```

The inline ascending dot product emits a plain `mul` + `add` in hexa codegen on
**both** ISAs — there is no `a*b+c` statement for the backend to fuse — so it
folds to the **same** `1401117690` everywhere. (A 3×3 *identity* probe matched on
both ISAs and hid the bug at first: an identity matmul has no accumulation to
fuse. The divergence only appears once a contraction sums ≥2 products.)

**SCOPE.** This is strictly the cross-ISA layer. The `farr_matmul` kernel is
still perfectly *run-to-run* deterministic (it fuses the same way every time on a
given machine) and is *libm-free* (it is pure arithmetic). It just is not
*machine-independent*. So a step that uses it can pass every layer-1 and layer-2
oracle and still fail a cross-platform byte fold — which is exactly what OP-29
observed before closing the hole (the decoder block was byte-eq run-to-run per
platform but byte-divergent arm64 vs x86 until the matmul was de-fused).

**HOW to comply.** On the determinism path, **do not call `farr_matmul`** (nor
any C kernel that lets clang fuse `a*b+c`). Re-implement the projection /
grad-accumulator as an **inline ascending-order dot product** — the same
sequential-reduction discipline §1.2/§1.3 already mandate for every other sum,
and the reason the CLMConvMoE oracles were *accidentally* cross-ISA-safe (they
never used `farr_matmul`; their conv/GEMM contractions are inline ascending
loops). OP-29 closed the decoder-block hole this way: `_db_proj_batch_farr` and
`_db_grad_accum_farr` were re-implemented as inline ascending dots (no C kernel).
If a fused C matmul is unavoidable for performance off the determinism path,
provide a **non-FMA accumulation** (e.g. force `-ffp-contract=off`, or split the
multiply and add into separate statements the backend cannot recombine) and
re-measure the cross-ISA byte fold. (F-OP29-2ND-ARCH.)

#### boundary: exact-product operands are FMA-immune

The invariant above has a **precise mathematical boundary**, measured by OP-32's
in-band FMA diagnostics on the 4th (spiking LIF) architecture. It bounds *when*
the fused kernel can diverge — it does **not** relax the rule above, which stays
the default on the determinism path.

**The MATH.** The FMA divergence exists only because one rounding can differ
from two. `fma(a, b, c)` rounds **once** (after the exact product `a·b` and the
add); `add(mul(a, b), c)` rounds **twice** (once after the product, once after
the add). The two forms can differ **iff the intermediate product `a·b` is
inexact** — i.e. iff `round(a·b) ≠ a·b`. When the product is *exactly
representable* in fp64, the first rounding is the identity and the two forms
collapse to the same bits:

```
   round(a·b + c)  ==  round(round(a·b) + c)     iff  a·b is EXACT in fp64

   exact-product operand classes (FMA-IMMUNE):     inexact product (FMA-EXPOSED):
     b ∈ {0, 1}    a·0 = 0,  a·1 = a  (exact)        b real-valued, a·b needs
     b = ±2^k      exponent shift only (exact*)       rounding → fused (1 round)
     a = 0 or ±2^k symmetric case                     ≠ unfused (2 rounds)
                                                      → sub-ULP per-ISA divergence
   (* barring under/overflow at the exponent range edges)
```

A matmul whose *every* product is exact therefore folds to the same bytes
through the FMA-fused kernel and through the inline ascending form — there is
nothing for the contraction setting to fuse *differently*. Binary `{0,1}`
operands (spikes, one-hot rows, boolean masks) are the practically important
member of this class.

**The MEASUREMENT (F-OP32-4TH-ARCH).** OP-32 fed byte-identical fp64 inputs
through the **same forbidden FMA-fused `farr_matmul` kernel** on both ISAs, in
two drives:

```
   through the SAME FMA-fused farr_matmul kernel (the forbidden one):

   DIAG-A  rate-coded REAL-VALUED drive       DIAG-B  BINARY {0,1} spike drive
   ──────────────────────────────────         ────────────────────────────────
     arm64-macos  ck = 1478294112               arm64-macos  ck = 1881150137
     x86-linux    ck = 210297454                x86-linux    ck = 1881150137
        ↑ DIVERGES (inexact products)              ↑ IDENTICAL (exact products)
```

Same kernel, same machines, same run — the only difference is whether the
operand values make every product exact. This confirms the invariant is
**precision-structural, not superstition**: divergence requires an inexact
product, and `b ∈ {0,1}` removes it. (F-OP32-4TH-ARCH, DIAG-A/DIAG-B.)

**The PRACTICAL RULE.** One-hot / boolean-mask / binary-spike matmuls are
*provably* safe through the fused kernel — but the immunity is a property of
the **operand values at run time**, not of the kernel or the call site, so it
is **conditional and fragile**:

- the moment an operand goes real-valued — plasticity updating weights,
  rate-coding, scaling, normalization, dropout-style `1/(1-p)` masks — the
  products go inexact and the blanket rule applies in full. OP-32's own arch is
  the cautionary case: its *spikes* are binary, but its traces and plastic
  weights are real-valued from the first STDP update;
- "exact today" is not "exact after the next refactor" — a mask that becomes a
  soft mask, a one-hot that becomes a distribution, silently crosses the
  boundary with **no error and no oracle failure on the original fixture**;
- therefore: **default to inline ascending**. Ride the fused kernel only when
  you can *prove* (not assume) that every product operand stays in the
  exact-product class for the lifetime of the call site — and leave a comment
  citing this boundary + F-OP32 at that call site.

**SCOPE.** This subsection is an *explanation plus a narrowly-licensed
exception*, not a loophole: the RULE block at the top of this section is
unchanged and remains the default for every determinism-path matmul. The
boundary tells you *why* the rule exists (inexact products are the entire
failure mode) and the one operand class where it provably cannot fire.
(F-OP32-4TH-ARCH.)

## per-phase locked identities

Each row = one step phase, its oracle, the canonical-order invariant it locks,
and the refactor that breaks it. "Identity" is `max|Δ| = 0` (true byte-eq, no
tolerance) unless noted.

| step phase | oracle file (`.verdicts/hexa-0pod/`) | canonical order locked | what breaks it |
|---|---|---|---|
| **INPUT** — token-embedding backward (scatter-add) | F-OP13-EMBED-RESIDUAL-ORACLE | shared-token row grads accumulate **position-ascending** (i = 0..T-1, in-place); mirrors `nn_embedding_bwd_scatter` | a gather-then-grouped-sum reorder, or GPU atomic-scatter, that drops position-ascending — descending diverges ~1e-13 on repeated-token rows (honest probe) |
| **FWD conv** — forward causal-dilated conv1d | F-OP7-CONV-IM2COL-EQ | im2col + GEMM == direct sliding-window conv; contract over `Kdim` **j-ascending** (`j = ci*K + k`), ci-outer k-inner; zero-pad p<0 → 0 | reorder the im2col layout or swap the contraction axis order |
| **NORM** — conv→GroupNorm→GELU "valley" | F-OP9-LN-REDUCTION-ORACLE | **two-pass** mean/var (NOT Welford) summed **(t-outer, c-inner)** sequential; `inv = 1/_gn_sqrt(var + eps)`, **eps = 1e-5**, `_gn_sqrt` = 40-iter Newton; GELU = erf-based CDF `x·0.5·(1+erf(x/√2))` (**`dt_erf`** — A&S 7.1.26 + `dt_exp`, branchless, NO libm; F-OP19b) | tree/warp-shuffle reduce the mean/var, switch to Welford, drop eps, reorder (t,c), or swap `dt_erf` (a piecewise/clamped erf straddles its boundary and breaks byte-eq — keep it branchless) |
| **MoE** — router softmax + expert combine | F-OP8-MOE-COMBINE-EQ | two-pass form == one-pass fused; softmax with **max-subtraction ON**, denom summed **e-ascending** sequential; exp = `_moe_exp`; combine Σ_e **e-ascending** per (t,c) | tree-reduce the softmax sum or combine, drop max-subtraction, reorder the expert axis, or swap `_moe_exp` |
| **LOSS bwd** — CE + softmax fused gradient | F-OP11 · F-OP19 | `dL/dlogits[t,v] = (softmax[v] − [v==tgt])/T`; exp = **`dt_exp`** (F-OP19, was libm `exp`); per-row max-sub ON; denom **v-ascending** sequential; write `p·invT` for all v, **THEN** `dlogits[tgt] −= invT` (scale-then-subtract; do NOT refold to `(p−1)·invT`) | tree-reduce denom, drop max-sub, swap exp impl (libm exp diverges across arch/OS — F-OP19), or refold the target subtraction (the `(p−1)·invT` fold is float-different — ~1.39e-17) |
| **LOSS fwd** — mean NLL | F-OP11-CE-SOFTMAX-ORACLE | `L = (1/T) Σ_t −ln(softmax[tgt_t])`; exp = **`dt_exp`**, ln = **`dt_ln`** (Taylor, NOT libm, NOT `_moe_exp`); per-row max-sub ON; denom **v-ascending**; `p_t` clamped ≥ 1e-6; loss summed **t-ascending**; mean = total/T | swap exp/ln impl, tree-reduce the denom, drop max-sub or the ≥1e-6 clamp, or reorder the t-sum |
| **BWD dW** — backward weight-gradient GEMM (transpose-elim) | F-OP2-TRAINER-WIRE | `im2col + matmul_t` dW == `im2col_t + matmul` dW; contract over the **same t/m dimension, same ascending order** (`xcolT[j,t] == xcol[t,j]`) | reorder the contraction; on GPU the cuBLAS OP_T Dgemm is an fp-accum-order variant of OP_N (rel-RMS ~1e-14, the documented identical-tolerance lane — not a regression) |
| **OPTIMIZER** — AdamW decoupled-wd update | F-OP12-ADAMW-UPDATE-ORACLE | SSOT `_hx_farr_adamw_step_cpu`: `v = β2·v + ((1−β2)·g)·g` (**left-assoc**, NOT `(1−β2)·(g·g)`); `m̂ = m/c1` **before** `v̂ = v/c2`; `denom = √v̂ + ε` (**ε outside √**, `_adamw_sqrt` 24-iter Newton held constant); `W' = (W − lr·wd·W) − lr·(m̂/denom)` (two separate subtractions, decoupled-wd first); `c1,c2 = 1−βᵗ` by repeated-mul (not `pow`) | refold `(1−β2)·g·g` to `(1−β2)·(g·g)` (diverges ≤8.88e-16), reorder the bias-correction divides, move ε inside √, or swap the sqrt impl |
| **SCHEDULE** — per-step LR (warmup + cosine decay) | F-OP33-LR-SCHEDULE | `opt_lr_warmup_cosine` (optim_lib): cos = **`d5_cos`** (mod-2π reduce + 14-term Taylor, the F-OP29 RoPE primitive — NOT libm `cos`); π = `d5_pi()`; fold order pinned (`prog` single-divide → `0.5·(1+c)` → `floor+(1−floor)·cosf` → `base·(...)`; warmup ramp `base·(t/warmup)`). Any per-step schedule arithmetic (lr/wd/beta/temperature ramps) must use `dt_*`/`d5_*` primitives | a libm-`cos` schedule — MEASURED divergent Darwin vs glibc: **10/500 steps differ 1–4 ULP** (t=121 180 367 381 387 391 394 407 414 433 at the OP-23b config), each handing AdamW a different lr → weights diverge from the first such step; or refolding the pinned fold order |
| **CHECKPOINT** — training-state save/restore/resume | F-OP35-CHECKPOINT | `ckpt_lib` (`"FCK\x01"` v1): **binary fp64 little-endian** via `f64_to_bytes_le`/`bytes_to_f64_le` (IEEE-754 bit-pattern reinterpret — NO text round-trip), **fixed field order** (header `t`,`n_params`; per param `[len][W][m][v]` in the pinned param order), state **COMPLETE** (every W + AdamW m,v + applied step t; resume continues at t+1). save→restore-FRESH→resume == uninterrupted **bit-for-bit** (0 bit-mismatch over W/m/v + loss bits); round-trip bit-exact on denormals/-0.0/±inf/NaN-payload; bytes platform-pinned (arm64-macos ↔ x86_64-linux: write/echo/resume files all `cmp`-identical) | a `%f`/`to_string` TEXT serialization (not shortest-round-trip — drops low mantissa bits → restore ≠ original → trajectory diverges); an **fp32** store anywhere in the path (the `.clm` int4/fp32 INFERENCE export is NOT a training checkpoint — MEASURED 1.77e-8 divergence 2 steps after an fp32-truncated resume); **omitting m, v, or the applied step t** (a reset t restarts bias-correction — MEASURED 0.042 divergence); host-endian or dict/iteration-ordered layouts |

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
          ▲
   [SCHEDULE]  lr(t) = opt_lr_warmup_cosine (d5_cos, NOT      F-OP33
               libm cos), feeds the AdamW lr scalar per step
```

Two exp impls live in this diagram: **`_moe_exp`** (MoE) and **`dt_exp`** (loss
fwd AND loss bwd — the latter swapped from libm `exp` in F-OP19 for cross-platform
byte-exactness). Each is load-bearing. (The GELU `erf` is likewise closed: it is
the deterministic **`dt_erf`** — A&S 7.1.26 branchless, built on `dt_exp`, no libm;
F-OP19b. With it the step has **no libm transcendental left** — see §1.)

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
- **Re-rolling `erf`/`sqrt`** where the deterministic impl (`dt_erf` in GELU, F-OP19b)
  or the specific Newton seed (`_gn_sqrt`, `_adamw_sqrt`) is locked. The GELU erf is
  now the branchless A&S `dt_erf` (F-OP19b closed the former libm-`erf` cross-platform
  hole); do NOT revert it to libm `erf` (re-opens the arch/OS ULP divergence) and do
  NOT make it piecewise (a series-then-clamp/tail erf straddles its boundary under
  in-register-vs-stored rounding and breaks `max|Δ|=0`).
- **Routing a determinism-path matmul through the FMA-fused C `farr_matmul`
  kernel** (or any C kernel clang -O2 can fold `a*b+c` into a single FMA). It is
  run-to-run deterministic but **cross-ISA divergent** (arm64 single-FMA vs x86
  mul+add → `241449363` vs `1401117690` on the same fp64 inputs). Use an inline
  ascending-order dot product instead — see the **cross-ISA invariant** in §1.
  (F-OP29.)
- **A libm-`cos` (or any libm-transcendental) LR/WD/beta/temperature SCHEDULE.**
  Per-step schedule arithmetic must use the `dt_*`/`d5_*` primitives — the
  canonical scheduler is `opt_lr_warmup_cosine` (optim_lib, `d5_cos`). libm `cos`
  in a warmup+cosine schedule is MEASURED divergent Darwin-arm64 vs glibc-x86:
  10/500 steps differ 1–4 ULP → a different lr enters AdamW on each platform →
  weights diverge from the first such step. (F-OP33.)
- **A lossy or incomplete CHECKPOINT.** Serializing training state through TEXT
  (`%f`/`to_string` — not shortest-round-trip; drops low mantissa bits), through
  an **fp32** store (the `.clm` int4/fp32 INFERENCE export is NOT a training
  checkpoint — an fp32-truncated resume diverges, MEASURED 1.77e-8 within 2
  steps), or **without the AdamW m/v + applied step t** (a reset t restarts
  bias-correction — MEASURED 0.042 divergence). The canonical primitive is
  `ckpt_lib` (`"FCK\x01"`: binary fp64-LE bit-pattern reinterpret, fixed field
  order, full W+m+v+t) — save→restore→resume is bit-identical to the
  uninterrupted run and the BYTES are platform-portable (arm64-macos ↔
  x86_64-linux `cmp`-equal). (F-OP35.)

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
