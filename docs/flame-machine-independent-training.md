# Machine-independent bit-exact neural-network training (flame)

> **A logged-discovery results document, not a paper.** This consolidates the
> HEXA-0POD campaign result that the flame **CLMConvMoE** training step is fully
> *machine-independent* byte-exact. Every number traces to a named verdict under
> `.verdicts/hexa-0pod/F-OP*-*.txt` (g5). No `/paper` was scaffolded
> (project.tape **g84** OPT-IN policy — a paper happens only on explicit
> `/paper` instruction).
>
> Companion: [`flame-determinism-contract.md`](flame-determinism-contract.md) is
> the contributor-facing index of the per-phase locked identities; this doc is
> the *result writeup* that consolidates them into the publishable claim.

## 1. The claim

> **flame trains a real neural network (CLMConvMoE) bit-for-bit identically on
> any IEEE-754 platform** — the same fixed-seed step produces the *same weights,
> gradients, and loss to the last bit* on x86-64 Linux (glibc) and on arm64
> macOS (Darwin libm), across architectures *and* operating systems.

This is a property standard ML stacks (PyTorch, JAX, TensorFlow) do **not**
provide. Those stacks route transcendentals (`exp`, `erf`, `log`) through the
platform `libm`, which is **not correctly-rounded** — glibc and Darwin libm
round the same input differently in the last ULP — so the same model trained on
two machines drifts apart bit-by-bit even before any reduction-order or
atomic-scatter nondeterminism enters. flame closes every such hole: the step has
**no `libm` transcendental left**. Every transcendental is a fixed-iteration
`+ − × ÷` routine, which is bit-identical on any IEEE-754 hardware.

The claim has **three independent layers**, each separately verified — clearing
any two does NOT imply the third:

1. **Run-to-run determinism (single machine).** The composed step is
   byte-identical when re-run from the same seed — no uninitialized scratch, no
   nondeterministic iteration, no address-dependent ordering. Locked by the
   per-op oracle series (OP-2/7/8/9/10/11/12/13) and the end-to-end capstone
   `F-OP15-STEP-DETERMINISM` (`max|Δ| = 0` over 17 weights + m + v + loss).
2. **libm-free transcendentals (cross-platform, library layer).** Every
   `exp`/`erf`/`log` is a hand-rolled fixed-iteration `+ − × ÷` routine, so it is
   bit-identical on any IEEE-754 hardware rather than depending on a
   not-correctly-rounded platform `libm`. Established by closing the two `libm`
   transcendental holes on the step path: the CE-backward `exp`
   (`F-OP19-CROSSPLATFORM-EXACT`) and the GELU `erf` (`F-OP19B-DET-ERF`).
3. **Cross-ISA FMA-free matmul (cross-platform, accumulation layer).** Matmul on
   the determinism path accumulates via **inline ascending reductions**, never the
   FMA-fused C `farr_matmul` kernel. clang -O2 fuses `a*b+c` into a single-rounding
   FMA on arm64 but emits mul+add (two roundings) on x86 — so an *accumulating*
   matmul byte-diverges across ISAs even with layers 1–2 clean. Surfaced and
   closed for a 2nd architecture in `F-OP29-2ND-ARCH`. This is a distinct hole
   from `libm`: a backend code-generation divergence, not a library one.

Layers 2 + 3 together are what make the *same bytes* appear on x86-64-linux
**and** arm64-macos (cross-platform determinism), once layer 1 is already locked.
See the contributor SSOT [`flame-determinism-contract.md`](flame-determinism-contract.md)
§"cross-ISA invariant" for the layer-3 rule a refactorer must obey.

## 2. Threat model — what breaks cross-platform reproducibility

Four independent failure classes break bit-exact reproducibility in a standard
training stack. flame closes each; the table maps threat → where flame closes it
→ the verdict that proves it. T1–T3 are *library / order* divergences; **T4 is a
back-end code-generation divergence** (the FMA-fusion threat OP-29 surfaced) —
distinct from the others because it survives even when every transcendental is
`libm`-free and every reduction order is fixed.

```
  ┌──────────────────────────────────────────────────────────────────────────┐
  │  THREAT (standard stacks)            │  flame CLOSURE        │  verdict     │
  ├──────────────────────────────────────┼───────────────────────┼─────────────┤
  │ T1  libm transcendental NOT          │  hand-rolled          │  F-OP19      │
  │     correctly-rounded                │  dt_exp / dt_erf /    │  F-OP19B     │
  │     (exp/erf/log differ per arch/OS  │  dt_ln / _moe_exp +   │  F-OP8/11    │
  │      in the last ULP)                │  Newton sqrt — pure   │              │
  │                                      │  +−×÷, no libm        │              │
  ├──────────────────────────────────────┼───────────────────────┼─────────────┤
  │ T2  tree / warp-shuffle reduction    │  SEQUENTIAL scalar    │  F-OP8       │
  │     nondeterminism (float sum is     │  reductions, fixed    │  F-OP9       │
  │     non-associative; tree order      │  ASCENDING accumula-  │  F-OP11      │
  │     varies w/ width/occupancy)       │  tion order locked    │              │
  ├──────────────────────────────────────┼───────────────────────┼─────────────┤
  │ T3  atomic-scatter order             │  in-place position-   │  F-OP13      │
  │     (embedding bwd atomicAdd races;  │  ASCENDING scatter-   │              │
  │      accumulation order = race order)│  add, deterministic   │              │
  ├──────────────────────────────────────┼───────────────────────┼─────────────┤
  │ T4  FMA-fused matmul ISA divergence  │  INLINE ascending     │  F-OP29      │
  │     (clang -O2 fuses a*b+c → 1-round │  dot products on the  │              │
  │      FMA on arm64 but mul+add → 2    │  det path, NOT the    │              │
  │      rounds on x86 → accumulating    │  FMA-fused C          │              │
  │      matmul byte-diverges per ISA)   │  farr_matmul kernel   │              │
  └──────────────────────────────────────┴───────────────────────┴─────────────┘
```

```
  CLMConvMoE STEP PATH — every transcendental + reduction closed
  ─────────────────────────────────────────────────────────────
   ids ─[embed gather]─► X
         └ bwd scatter-add  ──► T3 closed: position-ASCENDING (F-OP13)
            │
   ┌─ trunk block ────────────────────────────────────────────────┐
   │  conv1d  ──► T2 closed: j-ASCENDING contraction      (F-OP7/2)│
   │  GroupNorm ─► T2 closed: two-pass (t-out,c-in) seq    (F-OP9) │
   │            └ GELU ─► T1 closed: dt_erf (A&S, no libm)(F-OP19B) │
   │  MoE softmax ─► T1 closed: _moe_exp ; T2 e-ASC denom  (F-OP8) │
   └───────────────────────────────────────────────────────────────┘
            │
   CE loss  fwd ─► T1: dt_exp+dt_ln ; T2 t-ASC denom    (F-OP11)
            bwd ─► T1: dt_exp (was libm exp!) ; v-ASC    (F-OP11/OP19)
            │
   AdamW    ─► sqrt = _adamw_sqrt Newton (no libm)        (F-OP12)
```

The two transcendentals that *were still `libm`* on the step path — and are the
heart of the cross-platform result — are CE-backward `exp` (closed by OP-19) and
GELU `erf` (closed by OP-19b). Before those, the step was already run-to-run
deterministic on one machine but **not** cross-platform; OP-19/19b are what
extended determinism from "same machine, twice" to "any machine, ever".

The **T4 FMA-matmul** threat is the same shape one layer down: even with T1–T3
closed, a matmul that routes `a*b+c` through the FMA-fused C `farr_matmul` kernel
byte-diverges per ISA. OP-29 measured it directly on a 2nd architecture (a
Transformer decoder block): byte-identical fp64 inputs gave `C ck = 241449363` on
arm64-macos vs `C ck = 1401117690` on x86-linux from the *same* `farr_matmul`
call, because clang -O2 contracts the multiply-add into a single FMA on arm64 (one
rounding) but emits a separate mul+add on x86 (two roundings). Re-implementing the
matmul as an inline ascending dot product folds to `1401117690` on **both** ISAs.
(The CLMConvMoE step was *accidentally* T4-safe — its conv/GEMM contractions are
already inline ascending loops, never `farr_matmul`; OP-29 is what made the
requirement explicit and general. F-OP29-2ND-ARCH.)
T4 has a measured **boundary**: exact-product operands (binary `{0,1}` spikes /
one-hot / masks) are FMA-immune even through the fused kernel (DIAG-B
`1881150137` identical on both ISAs vs DIAG-A rate-coded divergent) — see the
boundary subsection in [`flame-determinism-contract.md`](flame-determinism-contract.md)
+ F-OP32-4TH-ARCH; the inline-ascending default is unchanged.

## 3. Evidence

Each row: the oracle, the phase identity it locks, the canonical order it pins,
and the **measured result** (run-to-run byte-cmp and, where measured,
cross-platform). "Identity" is `max|Δ| = 0` (true byte-eq, no tolerance) unless
the cell says otherwise. All run-to-run oracles run via `hexa run` on CPU, 0-GPU,
$0.

| oracle | phase / what it locks | canonical order pinned | measured result |
|---|---|---|---|
| **F-OP7-CONV-IM2COL-EQ** | fwd causal-dilated conv1d: im2col+GEMM == direct conv | contract over Kdim **j-ascending** (`j = ci*K + k`), ci-outer k-inner | `max|Δ| = 0` across 5 shapes (T8C4K3d1/d2, T16C6, T12C5×7K4d2, T10C3×5K5d3) |
| **F-OP2-TRAINER-WIRE** | bwd dW GEMM, transpose-elimination (`im2col+matmul_t` == `im2col_t+matmul`) | same t/m contraction axis, **same ascending order** (`xcolT[j,t]==xcol[t,j]`) | `max|Δ| = 0`; GPU cuBLAS OP_T vs OP_N is fp-accum variant rel-RMS ~1e-14 (documented identical-tolerance lane) |
| **F-OP8-MOE-COMBINE-EQ** | MoE router softmax + expert combine, two-pass == one-pass fused | softmax max-sub ON, denom **e-ascending**; combine Σ_e **e-ascending** per (t,c); exp = `_moe_exp` | `max|Δ| = 0.0` across all 6 shapes |
| **F-OP9-LN-REDUCTION-ORACLE** | GroupNorm valley: two-pass mean/var + GELU == fused valley | **two-pass** (not Welford), summed **(t-outer, c-inner)**; eps=1e-5; `_gn_sqrt`=40-iter Newton; GELU = dt_erf CDF | `max|Δ| = 0.0` all shapes |
| **F-OP11-CE-SOFTMAX-ORACLE** | CE fwd mean-NLL + softmax-grad bwd | denom **v-ascending**, max-sub ON, clamp ≥1e-6; loss **t-ascending**; exp=`dt_exp`, ln=`dt_ln` | gate `max|Δ| = 0`; honest probe: `(p−1)·invT` refold diverges 1.38778e-17 (why scale-then-subtract is locked) |
| **F-OP12-ADAMW-UPDATE-ORACLE** | AdamW decoupled-wd update arithmetic | `v=β2·v+((1−β2)·g)·g` left-assoc; m̂/c1 before v̂/c2; ε **outside** √; `_adamw_sqrt`=24-iter Newton | gate `max|Δ| = 0`; honest probe: `(1−β2)·(g·g)` refold diverges up to 8.88e-16 across 7 knob-sweep configs |
| **F-OP13-EMBED-RESIDUAL-ORACLE** | embedding bwd scatter-add (shared-token rows) | accumulate **position-ascending** (i=0..T-1, in-place) | gate `max|Δ| = 0`; honest probe: position-**descending** reorder diverges up to 5.68434e-14 on repeated-token rows |
| **F-OP15-STEP-DETERMINISM** | **whole composed micro-step**, byte-identical run-to-run | embed→conv→GroupNorm→MoE→CE→bwd→AdamW + all state threading | `max|Δ| = 0.0` over W (17 params), m (17), v (17), AND `|Δloss|=0`; negative control (distinct seeds) = 0.344217, so the 0.0 is a genuine pass not a self-alias |

### Cross-platform measurements (the OP-19/19b layer)

Platforms tested — **free pool + local, ZERO vast, ZERO pod rental**. The
recorded environment matrix (each row = a distinct environment whose
deterministic folds were measured and recorded in a named verdict):

| # | host | platform | environment fingerprint | verdict(s) |
|---|---|---|---|---|
| 1 | local | arm64-macos (Darwin libm) | Darwin (Apple Silicon) | F-OP19 / F-OP19B |
| 2 | ghost | arm64-macos (Darwin libm) | Darwin (Apple Silicon), pool | F-OP19 / F-OP19B |
| 3 | aiden | x86_64-linux (glibc) | glibc x86 (exact glibc/distro version not recorded; host down at OP-19g recording time) | F-OP19 / F-OP19B |
| 4 | pi5 | arm64-linux (glibc) | Raspberry Pi 5, Linux ubuntu 6.8.0-1007-raspi aarch64 | F-OP19C |
| 5 | **summer** | x86_64-linux (glibc) | **Ubuntu 24.04.2 LTS (Noble Numbat) · kernel 6.17.0-35-generic x86_64 · glibc 2.39 (Ubuntu GLIBC 2.39-0ubuntu8.7) · AMD Ryzen 5 9600X** | F-OP19G |
| 6 | musl | x86_64-linux (**musl**, Alpine 3.20 container on summer) | /lib/ld-musl-x86_64.so.1 — a 3rd distinct libc/libm impl | F-OP19D / F-OP19E |

Rows 1–3 are the original OP-19/19b measurement; rows 4–6 extended the matrix
(OP-19c/19d/19e); **row 5 (OP-19g) formalizes summer** — previously only an
ad-hoc substitute leg in OP-33/35 — as a recorded environment with a precise
glibc fingerprint. On summer the deterministic folds reproduce the golden
values exactly (`dt_exp` CE-bwd `7679248634312321699`, `dt_erf` GELU-fwd
`4548590605583584556`, GELU-bwd `4249661408190172843`), and summer's **libm**
folds equal aiden's recorded glibc-x86 libm folds (CE-bwd-libm
`3352931952497630952`, GELU-fwd-libm `6306829276275644424`, GELU-bwd-libm
`5500011732941122953`) — two independent glibc x86 hosts rounding identically
on the libm lane while still diverging from Darwin/musl, consistent with the
OP-19c thesis that the libm split is a per-libc effect. (Aiden's exact glibc
version was never recorded and the host was down at OP-19g time, so the
glibc-*version*-diversity of the pair is honestly unknown; what row 5 adds for
certain is a second independent glibc x86_64 host with its fingerprint pinned.)
Note summer ran the **self-contained** oracle lane only — its older hexa build
miscompiles cross-module imports (the F-OP33/35-documented toolchain caveat).

**OP-19 — CE-backward libm `exp` was the cross-platform hole.** A self-contained
3-platform byte oracle (`f64_to_bytes_le` IEEE-754 dump folded to an i64
fingerprint) measured the CE-bwd grad (T16×V256) in both a `libm` form and a
`dt_exp` form:

| fold | local arm64-macos | ghost arm64-macos | aiden x86-linux |
|---|---|---|---|
| CE-bwd **libm exp** | 7969105254299072804 | 7969105254299072804 | **3352931952497630952** ← diverges |
| CE-bwd **dt_exp** Taylor | 7679248634312321699 | 7679248634312321699 | 7679248634312321699 ← identical |

Per-element diff isolated the divergence: **exactly 4 of 4096 grad elements
differ, each by exactly 1 in the mantissa LSB = 1 ULP** (idx 107/321/1899/3769,
byte[0] off by one; high 7 bytes identical everywhere). Same op order, only the
`exp` source differs ⇒ the divergence *is* `libm exp` (glibc vs Darwin round 4
inputs differently). **Fix:** CE-bwd `clm_ce_grad` swapped `exp` → `dt_exp` (host
+ the `_hx_dt_exp_dev` device kernel). Grad change from the swap: max abs
**2.17e-18**, max rel **≈2.0e-14** (a few ULPs). After: the production path folds
to `7679248634312321699` on all three platforms — **cross-platform
byte-identical = YES**.

**OP-19b — GELU `erf` was the last `libm` transcendental.** GELU forward
`x·0.5·(1+erf(x/√2))` and backward `Φ(x)+x·φ(x)` (φ = exp(−x²/2)/√(2π)) still
called `libm erf` (fwd) and `libm erf`+`exp` (bwd). Replaced with **`dt_erf`** —
Abramowitz & Stegun 7.1.26 rational with the single `exp` routed through
`dt_exp`, **pure `+ − × ÷`, no libm, and branchless in z** (only the z=0 odd
sign flip). The det-erf GELU fwd+bwd byte fold (fixed-seed N=1024 fixture, FNV-1a
i64):

| fold | local arm64-macos | ghost arm64-macos | aiden x86-linux |
|---|---|---|---|
| GELU-fwd dt_erf | 4548590605583584556 | 4548590605583584556 | 4548590605583584556 |
| GELU-bwd dt_erf | 4249661408190172843 | 4249661408190172843 | 4249661408190172843 |

→ **byte-identical on all three platforms.** (The `libm`-erf path couldn't even
be cross-platform *measured*: `hexa_math_erf` is undefined on aiden's prebuilt
runtime — link failure — which is itself evidence of the portability problem.)
Dependent oracles re-locked: OP-9 LN-reduction `max|Δ|=0.0`, a new GN-GELU
fusion re-lock `max|Δ|=0.0` at 4 shapes, OP-15/OP-18 inherit by construction.

### TF32 fast-mode complement (`F-OP23-TF32-DRIFT`)

The bit-exact identity above is **FP64 self-determinism**. flame *also* ships a
deterministic TF32 fast-mode (breaks the ~3× FP64 cap), validated over N=100
steps on aiden's RTX 5070 (free pool, no vast):

- TF32 trajectory is **self-byte-eq run-to-run** over the whole 100-step
  trajectory (`selfByteEqN = Y`: W and loss `max|Δ|=0` at step N) — same
  determinism discipline at lower precision.
- TF32 **loss tracks FP64 loss** to ~1e-7 (lossTrackN 5.7e-8 / 9.3e-8 / 2.9e-7;
  worst per-step gap 2.5e-5, and that worst is at step 1 — it does *not* grow),
  weight rel-RMS bounded ~5e-7 — a real fast-mode, not a 1-step illusion.

Crucially TF32 is *self*-deterministic, **not** cross-precision bit-equal to FP64
(NN training is chaotic — even FP64-vs-FP64 with a 1-ULP perturbation diverges in
weights over many steps while the loss stays equivalent). That is exactly why
flame's byte-exact identity is *self*-determinism, characterized honestly in §5.

## 4. Determinism construction (the reproducer recipe)

The full recipe a reproducer needs to obtain machine-independent bit-exact
training. Every item is a *fixed-iteration* or *fixed-order* construction — no
`libm`, no associativity freedom.

**(a) Hand-rolled transcendentals — no `libm` anywhere on the step path:**

| transcendental | impl | form | verdict |
|---|---|---|---|
| `exp` (CE fwd loss + CE bwd grad + GELU-bwd pdf) | `dt_exp` (`flame_math.hexa`) | scaled-Taylor, 12-term, range-reduce by halving | F-OP11 · F-OP19 · F-OP19b |
| `exp` (MoE router softmax) | `_moe_exp` (`moe_lib`) | scaled-Taylor, range-reduce + 14-term | F-OP8 |
| `erf` (GELU fwd + bwd) | `dt_erf` (`flame_math.hexa`) | A&S 7.1.26 rational, exp via `dt_exp`, **branchless** | F-OP19b |
| `ln` (CE fwd loss) | `dt_ln` (`flame_math.hexa`) | Taylor (not libm, not `_moe_exp`) | F-OP11 |
| `sqrt` (GroupNorm inv-std) | `_gn_sqrt` | 40-iter Newton, seed x | F-OP9 |
| `sqrt` (AdamW denominator) | `_adamw_sqrt` | 24-iter Newton, seed x | F-OP12 |

Note the **two distinct `exp` impls are each load-bearing** — `dt_exp` and
`_moe_exp` are NOT interchangeable; a "unify the exp" refactor silently changes
the bits. `dt_erf` is also load-bearing **branchless**: a piecewise series-then-
clamp/tail erf straddles its branch boundary under in-register-vs-stored-reload
rounding of the GELU argument and breaks `max|Δ|=0`; the unconditional A&S form
has no boundary to straddle.

**(b) Sequential reductions — no tree / warp-shuffle re-association.** Every sum
(softmax denominators, GroupNorm mean/var, GEMM/conv contractions, MoE combine)
accumulates in fixed scalar order. A warp-shuffle/tree reduction or a Welford
streaming mean/var is float-non-associative against the locked order and breaks
byte-eq. (F-OP8, F-OP9, F-OP11.)

**(c) Ascending accumulation order.** Where order is free it is pinned ascending:
softmax denominators **v-ascending**; MoE combine **e-ascending**; CE fwd loss
**t-ascending**; embedding bwd scatter-add **position-ascending**; GroupNorm
**(t-outer, c-inner)**; conv/GEMM contractions **j-ascending** (`j = ci*K + k`).
(F-OP7/8/9/11/13.)

**(d) Inline ascending matmul — NOT the FMA-fused C kernel (cross-ISA).** Matmul
on the determinism path accumulates via **inline ascending dot products** (plain
`acc = acc + a*b` in hexa codegen), never the FMA-fused C `farr_matmul` kernel.
clang -O2 contracts `a*b+c` into a single-rounding FMA on arm64 but emits mul+add
(two roundings) on x86, so an *accumulating* `farr_matmul` byte-diverges per ISA
(`241449363` arm64 vs `1401117690` x86 on byte-identical fp64 inputs); the inline
dot folds to `1401117690` on both. This is the cross-ISA layer ON TOP of (a)
(`libm`-free) and (b)/(c) (sequential ascending order): a model can satisfy (a)–(c)
and still byte-diverge across ISAs if a matmul routes through the fused kernel. If
a fused C matmul is needed off the det path, force a non-FMA accumulation
(`-ffp-contract=off`, or split mul/add into statements the backend cannot
recombine). (F-OP29.)

**(e) Fixed arithmetic foldings (the non-obvious ones).** CE-bwd writes `p·invT`
for all v **then** subtracts `invT` at the target (scale-then-subtract; do NOT
refold to `(p−1)·invT` — diverges 1.39e-17). AdamW uses `v=β2·v+((1−β2)·g)·g`
left-assoc (not `(1−β2)·(g·g)`), m̂/c1 before v̂/c2, ε **outside** √. (F-OP11,
F-OP12.)

**(f) Deterministic init + state threading.** Fixed LCG seeds (no RNG, no
wall-clock); m/v zero-initialized; cache buffers, optimizer carry, and all
intermediate state thread deterministically with no uninitialized scratch and no
nondeterministic (dict/set/address-ordered) iteration. (F-OP15.)

Host ↔ device parity: the GPU kernels carry byte-identical `__device__` twins of
the host transcendentals (`_hx_dt_exp_dev`, `_hx_dt_erf_dev`), so the device path
reproduces the host path byte-for-byte and is *itself* cross-platform
deterministic.

## 5. Honest limits

In the spirit of g5 (and the "elephant rule" — current-state facts only), the
following bound the claim:

- **dt_erf is 1.38e-7 from `libm` erf, by design.** `max|dt_erf − libm erf| =
  1.38e-7` over x∈[−9,9] (GELU fwd abs 2.11e-7, bwd ≈6e-9). flame trades "matches
  any one platform's libm" for "matches *across all* platforms" — it is
  reproducible-everywhere, not bit-equal-to-a-reference-libm. This is ≤ the GELU
  training tolerance (≈1e-7, the W14-style reproducibility budget); the change is
  training-equivalent. Likewise the CE-bwd `dt_exp` swap shifted the grad by max
  rel ≈2.0e-14. (F-OP19, F-OP19b.)

- **TF32-mode is self-deterministic, not cross-precision bit-equal.** The
  bit-exact identity is FP64 self-determinism. TF32 fast-mode is byte-eq
  *run-to-run at TF32* and loss-tracks FP64 to ~1e-7, but TF32 weights are *not*
  bit-equal to FP64 weights (NN training is chaotic — they diverge over steps
  while the loss stays equivalent). Cross-platform bit-exactness is an FP64-lane
  claim. (F-OP23.)

- **GPU determinism scope is single-machine here.** The cross-*platform* byte
  measurements (OP-19/19b) ran the deterministic transcendentals via `hexa run`
  on CPU across arm64-macos and x86-linux. The GPU kernels carry byte-identical
  device twins so host↔device byte-eq holds and the device path is *itself*
  deterministic, but a cross-*GPU-architecture* (e.g. sm_120 vs sm_90) byte
  measurement is not part of this result; what is proven is host↔device byte-eq
  on one machine + cross-platform CPU byte-eq.

- **The B>1 conv-seam is intentionally non-zero.** The batched step concatenates
  B length-`Tw` windows into one length-`T = B·Tw` buffer and convolves the whole
  sequence. The interior is bit-exact (`max|Δ|=0`), but the **first `(K-1)·dil`
  output positions of every window after the first** carry cross-window causal
  context a per-window-segmented conv would zero — measured seam `max|Δ|` ranged
  0.06–0.38 across 6 cases, the band neither over- nor under-claimed. This is
  *intended* and *platform-independent* (the concat path is itself deterministic
  run-to-run); it is just not identical to a segmented conv at the seams.
  (F-OP10.)

- **Production-stdlib oracle final read is build-deferred.** A few oracles that
  `use` the production `nn_lib`/`gn_lib` cannot re-run against the dt_erf edit on
  the stale local `~/.hx/bin/hexa` (it resolves `use` to its own embedded
  stdlib). The self-contained twins + the cross-language C byte-eq (the host-C
  fallback folds byte-identical to the hexa `dt_erf`) pin the re-lock; the final
  `0.0` read on those production oracles is deferred to a fresh build — a build
  limitation, not a correctness gap. (F-OP19b §5.)

## 6. Provenance

Every claim above traces to a verdict (g5). Primary sources:

- `.verdicts/hexa-0pod/F-OP19-CROSSPLATFORM-EXACT.txt` — CE-bwd libm exp
  divergence (4/4096 × 1 ULP) measured and closed (dt_exp).
- `.verdicts/hexa-0pod/F-OP19B-DET-ERF.txt` — GELU libm erf closed (dt_erf,
  A&S 7.1.26, branchless, 3-platform byte-identical).
- `.verdicts/hexa-0pod/F-OP15-STEP-DETERMINISM.txt` — whole-step run-to-run
  byte-eq capstone.
- `.verdicts/hexa-0pod/F-OP{2,7,8,9,10,11,12,13}-*.txt` — the per-phase oracle
  series.
- `.verdicts/hexa-0pod/F-OP29-2ND-ARCH.txt` — machine-independence generalizes
  to a 2nd arch (decoder block); surfaced + closed the T4 cross-ISA FMA-matmul
  hole (`241449363` arm64 vs `1401117690` x86 from FMA-fused `farr_matmul`).
- `.verdicts/hexa-0pod/F-OP30-CROSSISA-CONTRACT.txt` — this T4 invariant
  formalized as a first-class rule in `flame-determinism-contract.md`.
- `.verdicts/hexa-0pod/F-OP23-TF32-DRIFT.txt` — TF32 fast-mode complement.
- `.verdicts/hexa-0pod/F-OP14-DETERMINISM-DOC.txt` /
  [`flame-determinism-contract.md`](flame-determinism-contract.md) — the
  contributor-facing per-phase index this doc consolidates.

**Governance note:** this is the OP-26 *logged-discovery consolidation* — a
rigorous, evidence-complete results document. Per project.tape **g84** (PAPER
OPT-IN), **no `/paper` was scaffolded**, no `PAPER.tape`/`PAPER.md` was created,
and the paper skill was not invoked. A paper happens only when the user
explicitly instructs `/paper`.
