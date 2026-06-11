# Submission-readiness assessment — machine-independent bit-exact training (flame)

> **A readiness assessment, not a paper.** This document gives the user a
> go/no-go picture on publishing the HEXA-0POD machine-independence result, and
> the *exact* action to start a paper IF they choose. Per project.tape **g84**
> (PAPER OPT-IN) **no `/paper` was scaffolded** here — no `PAPER.tape`,
> `PAPER.md`, or LaTeX was created, and the paper skill was not invoked. See §6.
>
> **Revision v2 (OP-26c).** The v1 assessment (OP-26b,
> `F-OP26B-SUBMISSION-READINESS`) was written against the round-5 evidence:
> ONE architecture, gap G2 ("a 2nd architecture") open, the input side of G1
> unproven. Rounds 6–8 changed that materially — **G2 is CLOSED with 4
> architectures** (OP-29 · OP-31 · OP-32), **the G1 input slice is fully proven
> against a real Qwen vocab and pre-gated** (OP-28/28b/28c · OP-24d), and the
> determinism construction is now a **formalized 3-layer model with a new,
> itself-novel cross-ISA FMA finding** (OP-30 · OP-32). This revision refreshes
> the claim, the gap list, the evidence table, and the novelty argument.
>
> Companion docs (the *result* itself, already landed):
> [`flame-machine-independent-training.md`](flame-machine-independent-training.md)
> (OP-26 results consolidation, extended by OP-30 with the 3-layer model) and
> [`flame-determinism-contract.md`](flame-determinism-contract.md) (the
> per-phase locked-identity index + the cross-ISA invariant, consistency-fixed
> by OP-30b). Every claim below traces to a verdict under
> `.verdicts/hexa-0pod/F-OP*-*.txt` (g5).

---

## (a) THE CLAIM — strongest current form

> **flame trains neural networks bit-for-bit identically across machines, and
> the determinism construction is GENERAL: it holds on 4 structurally-distinct
> architectures — conv+MoE (CLMConvMoE) · attention (Transformer decoder
> block) · dense MLP · recurrent spiking LIF with local STDP — because the
> construction satisfies a formalized 3-layer model (run-to-run · libm-free ·
> cross-ISA-FMA-free): every transcendental is a fixed-iteration `+ − × ÷`
> routine, every reduction is a sequential ascending loop, and no
> determinism-path contraction is left to the backend's FMA fusing.**

Scope of the cross-machine evidence, stated honestly (g5):

- **The flagship path (CLMConvMoE step + the dt_* primitives) is proven on a
  4-environment matrix** — `{x86, arm64} × {linux, macos}` minus the
  physically-impossible x86-macos cell, plus musl — spanning **3 distinct libm
  implementations** (glibc · musl · Darwin), with libm `erf` returning 4
  different values while the dt_* path stays byte-identical
  (`F-OP19, 19B, 19C, 19D, 19E`).
- **The 3 newer architectures (decoder block · MLP · spiking) are each proven
  byte-identical on both ISAs** — arm64-macos == x86-linux, the pair that
  exposed the FMA divergence — via self-contained cross-platform oracles
  (`F-OP29-2ND-ARCH`, `F-OP31-3RD-ARCH`, `F-OP32-4TH-ARCH`). Their twins are
  `use`-free/scp-portable, so extending them to the pi5/musl cells is
  mechanical but **not yet run** (gap G7 below).

The architecture coverage is *qualitatively* wide, not just numerically:

| arch | class | determinism surface exercised | verdict |
|---|---|---|---|
| CLMConvMoE | conv + MoE (feed-forward) | Conv1d seams, MoE router/combine, GroupNorm, CE/softmax, AdamW — the full trainer step | `F-OP15-STEP-DETERMINISM` + 8 per-op oracles |
| Transformer decoder block | attention (feed-forward) | GQA causal softmax (dt_exp), RoPE tables (dt_ln/d5_cos/d5_sin), SwiGLU, RMSNorm (dt_sqrt) | `F-OP29-2ND-ARCH` |
| Feed-forward MLP | pure dense GEMM | the matmul/reduction surface in its purest form — the cross-ISA invariant's stress point — + GELU (dt_erf) | `F-OP31-3RD-ARCH` |
| Spiking LIF + STDP | **recurrent · event-driven · non-backprop** | state threaded across T=32 steps (maximally order-sensitive), event thresholding, refractory countdown, pair-STDP + Hebbian plasticity (no loss, no gradient) | `F-OP32-4TH-ARCH` |

And the construction itself is now formalized (`F-OP30-CROSSISA-CONTRACT`) as
**3 independent layers**, each measured, where clearing any two does NOT imply
the third:

```
 layer 1  RUN-TO-RUN          same machine, twice → max|Δ|=0
          (sequential order · no uninit scratch · no addr-ordered iteration)
            └ F-OP{2,7,8,9,11,12,13} + F-OP15 capstone
 layer 2  libm-FREE           transcendental → bit-identical on any IEEE-754
          (dt_exp/dt_erf/dt_ln/_moe_exp + Newton sqrt — NO libm)
            └ F-OP19 (CE-bwd exp) · F-OP19B (GELU erf) · F-OP19C/D/E (4-env)
 layer 3  cross-ISA-FMA-FREE  a*b+c contraction → same bytes on arm64 AND x86
          (inline ascending reductions, NOT the FMA-fused farr_matmul kernel)
            └ F-OP29 (discovered) · F-OP31 (in-band demo) · F-OP32 (boundary)
```

---

## (b) READINESS CHECKLIST — what is DONE vs what a PAPER would ADD

### DONE (publication-ready, every row traces to a verdict)

| component | status | evidence |
|---|---|---|
| **The core result** — whole-step run-to-run byte-eq (`max\|Δ\|=0` over 17 W + m + v + loss; neg-control distinct-seed = 0.344217) | ✅ done | `F-OP15-STEP-DETERMINISM` |
| **Per-phase oracle series** — conv, dW, MoE, GroupNorm, CE, AdamW, embedding each locked `max\|Δ\|=0` + honest refold probes | ✅ done | `F-OP{2,7,8,9,11,12,13}` |
| **4-environment cross-platform evidence** — dt_exp/dt_erf byte-identical on Darwin + glibc-x86 + glibc-arm64 + musl-x86 | ✅ done | `F-OP19, 19B, 19C, 19D` |
| **3-distinct-libm divergence** — libm `erf` gives 4 distinct values; libm split proven OS/libc not arch | ✅ done | `F-OP19C §5, 19D §5` |
| **Real (un-shimmed) musl run** — POSIX-`environ` runtime fix; native-musl `hexa run` RUN_EXIT=0, folds byte-identical | ✅ done | `F-OP19E-MUSL-ENVFIX` |
| **2nd architecture (decoder block)** — fwd+bwd byte-eq run-to-run AND cross-ISA byte-identical; found+closed 2 holes (libm RoPE tables · FMA-fused `farr_matmul`) | ✅ done | `F-OP29-2ND-ARCH` |
| **3rd architecture (MLP)** — pure-GEMM arch byte-identical cross-ISA on the inline path, with the FMA divergence exhibited LIVE in-band (diag ck 2039553633 arm64 vs 124945498 x86 on identical inputs) | ✅ done | `F-OP31-3RD-ARCH` |
| **4th architecture (spiking LIF+STDP)** — first recurrent/event-driven/non-backprop arch; raster + plastic W + membrane byte-identical cross-ISA; libm-clean + FMA-clean by construction | ✅ done | `F-OP32-4TH-ARCH` |
| **3-layer determinism model + cross-ISA invariant formalized** — first-class contract section + threat-model row T4 + recipe item (d) | ✅ done | `F-OP30-CROSSISA-CONTRACT` |
| **FMA-immunity boundary measured** — binary {0,1} spike matvecs are byte-identical cross-ISA even THROUGH the forbidden FMA-fused kernel (1881150137 both), while rate-coded drives diverge | ✅ done | `F-OP32-4TH-ARCH` (DIAG-A/B) |
| **Input side, byte-level** — tokenize→pack→batch (V=256) byte-eq run-to-run + machine-independent (pure integer) | ✅ done | `F-OP28-CORPUS-LOADER-DET` |
| **Input side, BPE** — byte↔unicode fixed to the canonical GPT-2/Qwen `bytes_to_unicode` (256/256 round-trip, 0 collisions), pipeline byte-eq + cross-platform | ✅ done | `F-OP28B-BPE-FIX` |
| **Input side, REAL Qwen vocab** — the PRODUCTION load path verified against a real on-disk Qwen2.5 vocab (151643 entries, 151387 merges): round-trip 6/6 multilingual, deterministic load (full 151643-entry table identical across fresh loads), cross-platform byte-identical | ✅ done | `F-OP28C-VOCAB-STAGING` |
| **G1 pre-gate wired** — the turnkey GPU kit runs the OP-28/28b input oracles as STEP 0 (CPU, runs now) and STOPS before any GPU build if the input is not reproducible | ✅ done | `F-OP24D-G1-READINESS` |
| **Contract doc internally consistent** — last stale claim (pre-OP-19b "erf still open") corrected; whole-doc scan clean | ✅ done | `F-OP30B-CONTRACT-FIX` |
| **Spiking lib CPU-linkable** — OP-32's HOLE-2 packaging hole (missing `hexa_forge_dispatch_stdp_pair` CPU body) closed via the durable frozen-seed channel | ✅ done | `F-OP32B-STDP-HOST` |
| **Threat model** — T1 libm / T2 reduction-order / T3 atomic-scatter / **T4 FMA-contraction** each mapped to a flame closure + verdict | ✅ done | OP-26 doc §2 (+T4 via `F-OP30`) |
| **Determinism construction recipe** — hand-rolled transcendentals, sequential reductions, ascending order, **inline ascending matmul (not the FMA-fused C kernel)**, fixed foldings, deterministic init, host↔device twins | ✅ done | OP-26 doc §4 (+item (d) via `F-OP30`) |
| **TF32 fast-mode complement** — self-byte-eq over N=100 (extended N=500 in OP-23b); loss-tracks FP64 ~1e-7 | ✅ done | `F-OP23-TF32-DRIFT`, `F-OP23B` |
| **$0 reproduction surface** — all CPU `hexa run`, free pool + local, ZERO vast / pod | ✅ done | every F-OP19*/29/31/32 header |

### A PAPER would ADD (the delta — none of this exists yet, and per g84 it is not scaffolded)

| paper element | why it is a paper-only add | current gap size |
|---|---|---|
| **Formal abstract + intro** | the docs are an evidence dump, not a 200-word framed contribution | small (writing) |
| **Related-work survey** | no comparison written vs PyTorch determinism docs, JAX `jax.default_matmul_precision`, bit-reproducibility literature (Intel CNR, `nvidia` deterministic ops, Villa et al. FP reproducibility), correctly-rounded-libm work (CR-libm, RLIBM), **and `-ffp-contract` / FMA-contraction reproducibility notes** (the layer-3 finding needs positioning vs compiler-flag folklore — see §(d).2) | medium (lit review) |
| **Figures** | the ASCII threat-model + matrix tables would become real diagrams; a libm-divergence-vs-dt-identity bar chart; a 4-arch × 3-layer coverage matrix; the FMA DIAG-A/B contrast | small (pgfplots; no local xelatex — defer compile, see memory) |
| **Reproducibility artifact** | a Docker image / `install.sh` bundling the 4-env harness (Alpine musl container recipe exists in OP-19d/19e but is not packaged); the 3 self-contained arch oracles are already single-file scp-portable | medium |
| **Venue fit + positioning** | choose a venue (e.g. a reproducibility/ML-systems workshop, MLSys artifact track, or a determinism/FP-arithmetic venue) and frame to its scope | small (decision) |
| **Author/affiliation/licensing front-matter** | none exists | trivial |

---

## (c) GAP LIST — refreshed (v2)

These are genuine gaps (honest, g5) — a paper could be submitted without them
but would be stronger with them. **G2 is now CLOSED**; G1's input slice is
CLOSED + pre-gated. None of the remaining gaps was closed by this assessment.

| # | gap | status / blocker | severity for submission |
|---|---|---|---|
| G1 | **Real-corpus end-to-end training run** (not the fixed-seed micro-step) | **input side CLOSED + pre-gated**: tokenize→pack→batch proven byte-eq + machine-independent on BOTH the byte-level path (`F-OP28`) and the BPE path — canonical byte↔unicode (`F-OP28B`) verified against a **real on-disk Qwen2.5 vocab at full scale** (151643 entries, production `bpe_load` path, deterministic load, cross-platform — `F-OP28C`) — and the turnkey kit (`tool/clm/build_clmprod_tf32_e2e.sh`) pre-gates both oracles as step 0 (CPU, runs now; `F-OP24D`). The **SOLE remaining piece is the GPU trainer step run** (the `clm_prod_gpu` `-DHEXA_CUDA` build, env-gated — `F-OP24B`'s 31 host marshal wrappers). | **low-medium** (was high) — everything provable without a GPU is proven AND wired; one authorized GPU-build session closes it |
| G2 | **A 2nd model architecture** beyond CLMConvMoE | **CLOSED ×3-over** — the construction generalizes to a Transformer decoder block (`F-OP29`), a pure-GEMM MLP (`F-OP31`), and a recurrent spiking LIF+STDP network (`F-OP32`): 4 architectures total spanning feed-forward conv/attention/dense AND recurrent/event-driven/non-backprop classes | ~~medium~~ → **closed** |
| G3 | **The 4th matrix cell: x86-macos** | physically blocked — Apple retired Intel Macs; no pool host (`F-OP19C §4`). 3 of 4 cells confirmed + musl as a bonus 5th environment | low — honestly disclosed; the 3 confirmed cells already span both arch and both OS values |
| G4 | **Perf-vs-determinism Pareto framing** tying in TF32/BF16 fast-modes | partial — TF32 (`F-OP23/23B`) and BF16 (`F-OP25`) deterministic fast-modes exist and self-byte-eq, but no unified Pareto figure relates precision ↔ determinism ↔ the ~3× FP64 cap | medium — turns "FP64-only" into a precision-ladder story |
| G5 | **Cross-GPU-architecture byte measurement** (e.g. sm_120 vs sm_90) | out of scope — only host↔device byte-eq on one machine + cross-platform CPU byte-eq proven (`F-OP26 §5`); device twins exist but cross-GPU-arch byte-cmp not run | medium — a reviewer may probe GPU determinism scope |
| G6 | **Runtime musl ctor-ABI fix landed on the main release path** | OP-19e fix is durable via `tool/restore_frozen_seeds` post-restore patch, but a clean CI gate exercising a native-musl build would harden it | low — fix is proven + durable, just not CI-gated |
| G7 | **Archs 2–4 on the full 4-env matrix** (new, honest) | the decoder-block/MLP/spiking cross-platform proofs cover arm64-macos == x86-linux (both ISAs — the pair that exhibits the FMA divergence); the pi5 (arm64-linux) and musl cells were run only for the flagship dt_* path. The self-contained oracles are scp-portable, so this is mechanical, just not yet run | low — the ISA axis (the layer-3 risk) IS covered for all 4 archs; the libc axis is covered where libm is on the path |

---

## (d) THE NOVELTY ARGUMENT — sharpened (v2)

The publishable kernel is now TWO things: a property mainstream stacks
measurably do not have, **and a new, measured nondeterminism class found while
proving it**.

### 1. The property: cross-platform bit-exact training, constructively

1. **PyTorch / JAX / TensorFlow do NOT give cross-platform bit-exact training.**
   They route `exp`, `erf`, `log` through the platform `libm`, which is *not*
   correctly-rounded — glibc, musl, and Darwin each round the same input
   differently in the last ULP. Their determinism guarantees (e.g.
   `torch.use_deterministic_algorithms`, JAX precision flags) are **same-machine
   run-to-run** at best; they do **not** promise the *same bytes on a different
   machine/OS/libc*.

2. **flame removes ALL libm transcendentals — measured, not claimed.**
   - libm `erf` (GELU-fwd) returns **4 different values** across the 4
     environments — Darwin `1521224270287218303`, glibc-x86
     `6306829276275644424`, glibc-arm64 `3332333775004383127`, musl-x86
     `7314648833623304241` (`F-OP19D §5`). The same input, 4 answers.
   - flame's `dt_exp`/`dt_erf` collapse all 4 to **bit-identical** folds
     (`7679248634312321699` / `4548590605583584556` / `4249661408190172843`)
     across all 4 environments (`F-OP19D §4`, hardened to a real musl run in
     `F-OP19E §4c`).
   - The split is proven to be an **OS/libc effect, not an arch effect** (pi5
     arm64-linux tracks aiden x86-linux on the libm path, not the arm64-macos
     machine it shares an ISA with — `F-OP19C §5`).

3. **It is a constructive, GENERAL recipe — now proven 4-architectures wide.**
   The determinism is reproduced by a named, fixed construction (hand-rolled
   transcendentals + sequential ascending reductions + inline ascending matmul
   + fixed foldings + deterministic init) that a third party can follow — and
   the SAME construction holds on conv+MoE, attention, dense-MLP, and
   recurrent-spiking architectures (`F-OP15 · F-OP29 · F-OP31 · F-OP32`),
   including a substrate that **learns without backprop** (STDP/Hebbian).
   Every result is checkable with a `max|Δ|=0` byte oracle at $0 on commodity
   hardware.

### 2. The NEW finding: the cross-ISA FMA-contraction class (itself novel)

The OP-29→32 series surfaced and bounded a nondeterminism class that is
**distinct from libm (T1) and from reduction order (T2)** — a back-end
code-generation effect — and the measurement set is itself a contribution:

- **The class, measured.** clang -O2 contracts `a*b + c` into a single
  fused-multiply-add on arm64 (ONE rounding) but emits separate mul+add on x86
  (TWO roundings). On **byte-identical fp64 inputs**, the FMA-fused
  `farr_matmul` kernel returns **different bytes per ISA** — reproduced
  independently on three architectures: decoder-block Q-projection
  (`241449363` vs `1401117690`, `F-OP29` HOLE #2), MLP layer-1
  (`2039553633` vs `124945498`, `F-OP31` DIAG), spiking rate-coded drive
  (`1478294112` vs `210297454`, `F-OP32` DIAG-A). Crucially, a step using
  this kernel **passes every run-to-run AND libm-free oracle and still fails
  the cross-platform byte fold** — which is why the 3-layer model is needed
  (`F-OP30`).
- **The mitigation, as a contract.** Determinism-path matmul MUST be an inline
  ascending reduction (plain mul+add the backend cannot recombine), NOT a
  fused C kernel — formalized as a first-class invariant in the contributor
  SSOT with the RULE/WHY/SCOPE/HOW structure (`F-OP30-CROSSISA-CONTRACT`),
  and verified live: the inline rewrite of the SAME matmul on the SAME inputs
  is byte-identical cross-ISA in every case above.
- **The boundary, measured (new with OP-32).** Binary {0,1} operands are
  **FMA-immune**: `a·b` is exact for `b∈{0,1}`, so fused ≡ unfused —
  empirically confirmed: the binary spike-pattern matvec through the SAME
  forbidden kernel is byte-identical cross-ISA (`1881150137` on both,
  `F-OP32` DIAG-B) while the rate-coded twin diverges (DIAG-A). The invariant
  is precision-structural, not superstition — and event-coded (spiking) models
  occupy a naturally FMA-safe corner of it. (The contract's RULE is unchanged:
  the immunity is an input-value property, not a kernel property, and
  traces/weights are real-valued the moment plasticity engages.)

A reviewer can verify each leg: the divergence, the mitigation, and the
boundary are all in-band, $0, CPU-only measurements.

The honest framing (g5) keeps it defensible: the claim is
*reproducible-everywhere*, **not** bit-equal-to-any-one-reference-libm
(`dt_erf` is 1.38e-7 from libm *by design*, ≤ the GELU training tolerance), and
the byte-exactness is an **FP64-lane** property (TF32/BF16 fast-modes are
*self*-deterministic, not cross-precision bit-equal — NN training is chaotic).

---

## HONEST LIMITS (refreshed, v2)

- **The GPU trainer step run is still gated** (G1's sole remainder): the
  input side is proven + pre-gated, but no real-corpus end-to-end GPU run has
  executed (`F-OP24D` claims exactly this and no more).
- **Archs 2–4 cross-platform = 2 environments**, not the full 4-env matrix
  (G7): the ISA axis is covered; pi5/musl legs are mechanical but unrun.
- **The BPE pre-tokenizer is a simplified space-splitter**, not GPT-2's full
  regex — ids are NOT claimed equal to HF tokenizers' ids; the gate is
  round-trip + determinism, not HF-id parity (`F-OP28C`).
- **dt_erf is 1.38e-7 from libm by design** — reproducible-everywhere, not
  libm-equal (`F-OP19B`).
- **TF32/BF16 fast-modes are self-deterministic only** — not cross-precision
  bit-equal (`F-OP23/23B/25`).
- **GPU determinism scope = host↔device on one machine** (G5); cross-GPU-arch
  byte-cmp not run.
- **The spiking arch's GPU seam ships no CUDA-side host-wrapper twin yet**
  (`F-OP32B` honest residual) — the CPU path is the proven one.

---

## READINESS DIAGRAM (ASCII, v2)

```
  SUBMISSION-READINESS v2 — machine-independent bit-exact training (flame)
  ════════════════════════════════════════════════════════════════════════

   RESULT CORE (3-layer model)         ARCHITECTURES (G2 CLOSED — 4 archs)
   ┌───────────────────────────┐       ┌──────────────────────────────────┐
   │ L1 run-to-run max|Δ|=0 ✅ │       │ CLMConvMoE  conv+MoE        ✅    │
   │ L2 libm-free (dt_*)    ✅ │       │ decoder blk attention       ✅    │
   │ L3 cross-ISA-FMA-free  ✅ │       │ MLP         pure dense GEMM ✅    │
   │ threat model T1–T4     ✅ │       │ spiking LIF recurrent+STDP  ✅    │
   │ construction recipe    ✅ │       │  (event-driven · non-backprop)   │
   │ honest limits          ✅ │       └──────────────────────────────────┘
   └───────────────────────────┘
                                        ENVIRONMENTS (flagship dt_* path)
   INPUT SIDE (G1 slice CLOSED)         ┌──────────────────────────────────┐
   ┌───────────────────────────┐        │ arm64-macos  Darwin libm   ✅    │
   │ byte-level pipeline    ✅ │        │ x86-linux    glibc         ✅    │
   │ BPE canonical map      ✅ │        │ arm64-linux  glibc (pi5)   ✅    │
   │ REAL Qwen vocab 151643 ✅ │        │ x86-musl     Alpine        ✅    │
   │ turnkey kit pre-gate   ✅ │        │ x86-macos    (Intel Mac)   ⊘ G3  │
   └───────────────────────────┘        │ → 3 libm: glibc·musl·Darwin;    │
                                        │   libm erf = 4 values, dt_*     │
   PUBLICATION-READY █████████░ ~90%    │   identical on all          ✅   │
   (result + 4-arch + input DONE;       └──────────────────────────────────┘
    paper packaging + G1-GPU/G4 left)
                                        NEW NOVELTY (OP-29→32 series)
   REMAINING GAPS                       ┌──────────────────────────────────┐
   ┌───────────────────────────┐        │ cross-ISA FMA class: measured ×3 │
   │ G1 GPU step run (only)   │ LO-MED  │ mitigation contract (inline asc) │
   │ G4 perf↔det Pareto       │ MED     │ boundary: binary {0,1} operands  │
   │ G5 cross-GPU-arch byte   │ MED     │ are FMA-IMMUNE (measured)        │
   │ G3 x86-macos cell        │ LOW     └──────────────────────────────────┘
   │ G6 musl fix CI-gate      │ LOW
   │ G7 archs2-4 full matrix  │ LOW     G2 (2nd arch)  ── CLOSED ×3-over ✅
   └───────────────────────────┘        G1 input slice ── CLOSED+pre-gated ✅

   GO / NO-GO:  the RESULT is submission-grade NOW (4 archs · 4 env · 3 libm ·
                3-layer model · $0-repro), and the FMA finding adds a second,
                self-contained novelty leg. A paper mainly needs PACKAGING
                (abstract/related-work/figures/artifact). The one substantive
                remaining gap a strong venue may require is G1's GPU step run —
                GPU-build-env-gated, not blocked by the science.
```

---

## (e) GOVERNANCE NOTE + THE ONE USER ACTION

**No paper was scaffolded.** Per project.tape **g84** (the PAPER OPT-IN policy),
the agent does **not** propose `/paper`, does **not** auto-scaffold on discovery,
and does **not** create `PAPER.tape` / `PAPER.md` / any LaTeX. This document
(v2 included) is strictly a logged-discovery readiness assessment.

> **To scaffold the actual paper, the USER runs `/paper new
> flame-machine-independent` (or similar) — the agent does NOT auto-scaffold
> per g84.**

A paper happens **only** when the user explicitly types `/paper`, which they have
not. This assessment exists so the user can make that call with a clear go/no-go
picture and the exact action in hand.
