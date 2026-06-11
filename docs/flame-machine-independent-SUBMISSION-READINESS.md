# Submission-readiness assessment — machine-independent bit-exact training (flame)

> **A readiness assessment, not a paper.** This document gives the user a
> go/no-go picture on publishing the HEXA-0POD machine-independence result, and
> the *exact* action to start a paper IF they choose. Per project.tape **g84**
> (PAPER OPT-IN) **no `/paper` was scaffolded** here — no `PAPER.tape`,
> `PAPER.md`, or LaTeX was created, and the paper skill was not invoked. See §6.
>
> Companion docs (the *result* itself, already landed):
> [`flame-machine-independent-training.md`](flame-machine-independent-training.md)
> (OP-26 results consolidation) and
> [`flame-determinism-contract.md`](flame-determinism-contract.md) (the
> per-phase locked-identity index). Every claim below traces to a verdict under
> `.verdicts/hexa-0pod/F-OP*-*.txt` (g5).

---

## (a) THE CLAIM — strongest current form (1 sentence)

> **flame trains a real neural network (CLMConvMoE) bit-for-bit identically
> across a 4-environment matrix — `{x86, arm64} × {linux, macos}` plus musl —
> spanning 3 distinct libm implementations (glibc · musl · Darwin), because the
> training step has *no* `libm` transcendental left: every transcendental is a
> fixed-iteration `+ − × ÷` routine that is bit-identical on any IEEE-754
> machine.**

This is *stronger* than the claim consolidated by OP-26
(`F-OP26-MACHINEINDEP-WRITEUP`), which captured only the original 2-platform
{x86-linux, arm64-macos} contrast. The evidence base has since grown:

| op | verdict | what it added | net strength |
|---|---|---|---|
| OP-19 | `F-OP19-CROSSPLATFORM-EXACT` | closed CE-bwd `libm exp` hole; 2 platforms | 2-env |
| OP-19b | `F-OP19B-DET-ERF` | closed GELU `libm erf` hole (dt_erf, branchless); 3 hosts/2 combos | 2-env |
| OP-19c | `F-OP19C-PI5-3PLATFORM` | pi5 **arm64-linux** = 3rd arch×OS cell; isolated libm split to OS/libc not arch | **3 of 4** matrix cells |
| OP-19d | `F-OP19D-4TH-ENV` | **musl** (Alpine) = 4th environment, **3rd distinct libm impl**; libm `erf` gives 4 different values, dt_* identical | **4-env, 3 libm impls** |
| OP-19e | `F-OP19E-MUSL-ENVFIX` | durable POSIX-`environ` runtime fix → the musl run is **real, not shimmed** | musl result hardened |

So the publication-grade headline is now: **4 environments, 3 distinct libm
implementations, byte-identical on the deterministic path while libm itself
diverges** — the definitive form of "no libm dependence left."

---

## (b) READINESS CHECKLIST — what is DONE vs what a PAPER would ADD

### DONE (publication-ready, every row traces to a verdict)

| component | status | evidence |
|---|---|---|
| **The core result** — whole-step run-to-run byte-eq (`max\|Δ\|=0` over 17 W + m + v + loss; neg-control distinct-seed = 0.344217) | ✅ done | `F-OP15-STEP-DETERMINISM` |
| **Per-phase oracle series** — conv, dW, MoE, GroupNorm, CE, AdamW, embedding each locked `max\|Δ\|=0` + honest refold probes | ✅ done | `F-OP{2,7,8,9,11,12,13}` |
| **4-environment cross-platform evidence** — dt_exp/dt_erf byte-identical on Darwin + glibc-x86 + glibc-arm64 + musl-x86 | ✅ done | `F-OP19, 19b, 19c, 19d` |
| **3-distinct-libm divergence** — libm `erf` gives 4 distinct values; libm split proven OS/libc not arch | ✅ done | `F-OP19c §5, 19d §5` |
| **Real (un-shimmed) musl run** — POSIX-`environ` runtime fix; native-musl `hexa run` RUN_EXIT=0, folds byte-identical | ✅ done | `F-OP19E-MUSL-ENVFIX` |
| **Threat model** — T1 libm / T2 reduction-order / T3 atomic-scatter, each mapped to a flame closure + verdict | ✅ done | OP-26 doc §2 |
| **Determinism construction recipe** — hand-rolled transcendentals, sequential reductions, ascending order, fixed foldings, deterministic init, host↔device twins | ✅ done | OP-26 doc §4 |
| **Honest limits** — dt_erf 1.38e-7 from libm by design; TF32 self-det not cross-precision; GPU scope single-machine; B>1 conv-seam; build-deferred reads | ✅ done | OP-26 doc §5 |
| **TF32 fast-mode complement** — self-byte-eq over N=100 (extended N=500 in OP-23b); loss-tracks FP64 ~1e-7 | ✅ done | `F-OP23-TF32-DRIFT`, `F-OP23B` |
| **$0 reproduction surface** — all CPU `hexa run`, free pool + local, ZERO vast / pod | ✅ done | every F-OP19* header |

### A PAPER would ADD (the delta — none of this exists yet, and per g84 it is not scaffolded)

| paper element | why it is a paper-only add | current gap size |
|---|---|---|
| **Formal abstract + intro** | the docs are an evidence dump, not a 200-word framed contribution | small (writing) |
| **Related-work survey** | no comparison written vs PyTorch determinism docs, JAX `jax.default_matmul_precision`, bit-reproducibility literature (Intel CNR, `nvidia` deterministic ops, Villa et al. FP reproducibility), correctly-rounded-libm work (CR-libm, RLIBM) | medium (lit review) |
| **Figures** | the ASCII threat-model + matrix tables would become real diagrams; a libm-divergence-vs-dt-identity bar chart | small (pgfplots; no local xelatex — defer compile, see memory) |
| **Reproducibility artifact** | a Docker image / `install.sh` bundling the 4-env harness (Alpine musl container recipe exists in OP-19d/19e but is not packaged) | medium |
| **Venue fit + positioning** | choose a venue (e.g. a reproducibility/ML-systems workshop, MLSys artifact track, or a determinism/FP-arithmetic venue) and frame to its scope | small (decision) |
| **Author/affiliation/licensing front-matter** | none exists | trivial |

---

## (c) GAP LIST — what is still needed for a *strong* submission

These are genuine gaps (honest, g5) — a paper could be submitted without them but
would be stronger with them. None is closed by this assessment.

| # | gap | status / blocker | severity for submission |
|---|---|---|---|
| G1 | **Real-corpus end-to-end training run** (not the fixed-seed micro-step) | 0-pod-maximally-closed (`F-OP24D`): the INPUT side (tokenize→pack→batch, both byte-level `F-OP28` and BPE `F-OP28b`) is **0-pod-PROVEN** byte-eq + machine-independent, and the turnkey kit (`tool/clm/build_clmprod_tf32_e2e.sh`) now **pre-gates it as step 0** (CPU, runs now). The SOLE remaining gated piece is the GPU trainer **step run** (the `clm_prod_gpu` `-DHEXA_CUDA` build, env-gated). | **high → reduced** — input reproducibility is proven + wired now; only the GPU step awaits an authorized build env. The byte-eq is proven on the step (host↔device) AND on the real-corpus input; only the live end-to-end GPU run is build-deferred |
| G2 | **A 2nd model architecture** beyond CLMConvMoE | not attempted — the whole result is one architecture; a 2nd (e.g. plain transformer block, or a CNN) would show the recipe generalizes | medium — strengthens generality |
| G3 | **The 4th matrix cell: x86-macos** | physically blocked — Apple retired Intel Macs; no pool host (`F-OP19c §4`). 3 of 4 cells confirmed + musl as a bonus 5th environment | low — honestly disclosed; the 3 confirmed cells already span both arch and both OS values |
| G4 | **Perf-vs-determinism Pareto framing** tying in TF32/BF16 fast-modes | partial — TF32 (`F-OP23/23b`) and BF16 (`F-OP25`) deterministic fast-modes exist and self-byte-eq, but no unified Pareto figure relates precision ↔ determinism ↔ the ~3× FP64 cap | medium — turns "FP64-only" into a precision-ladder story |
| G5 | **Cross-GPU-architecture byte measurement** (e.g. sm_120 vs sm_90) | out of scope — only host↔device byte-eq on one machine + cross-platform CPU byte-eq proven (`F-OP26 §5`); device twins exist but cross-GPU-arch byte-cmp not run | medium — a reviewer may probe GPU determinism scope |
| G6 | **Runtime musl ctor-ABI fix landed on the main release path** | OP-19e fix is durable via `tool/restore_frozen_seeds` post-restore patch, but a clean CI gate exercising a native-musl build would harden it | low — fix is proven + durable, just not CI-gated |

---

## (d) THE NOVELTY ARGUMENT — why this is publishable

The publishable kernel is a property mainstream stacks **measurably do not have**:

1. **PyTorch / JAX / TensorFlow do NOT give cross-platform bit-exact training.**
   They route `exp`, `erf`, `log` through the platform `libm`, which is *not*
   correctly-rounded — glibc, musl, and Darwin each round the same input
   differently in the last ULP. Their determinism guarantees (e.g.
   `torch.use_deterministic_algorithms`, JAX precision flags) are **same-machine
   run-to-run** at best; they do **not** promise the *same bytes on a different
   machine/OS/libc*.

2. **flame removes ALL libm transcendentals — measured, not claimed.** This is
   the load-bearing novelty and it is *quantified*:
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

3. **It is a constructive recipe, not just a property.** The determinism is
   reproduced by a named, fixed construction (hand-rolled transcendentals +
   sequential ascending reductions + fixed foldings + deterministic init) that
   a third party can follow — and the result is checkable with a `max|Δ|=0`
   byte oracle at $0 on commodity hardware.

The honest framing (g5) keeps it defensible: the claim is
*reproducible-everywhere*, **not** bit-equal-to-any-one-reference-libm
(`dt_erf` is 1.38e-7 from libm *by design*, ≤ the GELU training tolerance), and
the byte-exactness is an **FP64-lane** property (TF32/BF16 fast-modes are
*self*-deterministic, not cross-precision bit-equal — NN training is chaotic).

---

## READINESS DIAGRAM (ASCII)

```
  SUBMISSION-READINESS — machine-independent bit-exact training (flame)
  ════════════════════════════════════════════════════════════════════════

   RESULT CORE                         EVIDENCE BASE (4 environments)
   ┌───────────────────────────┐       ┌──────────────────────────────────┐
   │ whole-step max|Δ|=0  ✅   │       │  arm64-macos  Darwin libm   ✅    │
   │ 8 per-phase oracles  ✅   │       │  x86-linux    glibc         ✅    │
   │ threat model T1/T2/T3 ✅  │       │  arm64-linux  glibc (pi5)   ✅    │
   │ construction recipe  ✅   │       │  x86-musl     Alpine        ✅    │
   │ honest limits §5     ✅   │       │  x86-macos    (Intel Mac)   ⊘ G3  │
   └───────────────────────────┘       │  → 3 distinct libm: glibc·musl·   │
                                        │     Darwin; libm erf = 4 values, │
   PUBLICATION-READY  ████████░░ ~80%   │     dt_* identical on all   ✅    │
   (result + 4-env evidence DONE;       └──────────────────────────────────┘
    paper packaging + G1/G2/G4 GAPS)
                                        WHAT A PAPER ADDS
   GAPS TO A *STRONG* SUBMISSION         ┌────────────────────────────────┐
   ┌───────────────────────────┐         │ abstract · related-work survey │
   │ G1 real-corpus e2e (GPU)  │ HIGH    │ figures · repro Docker artifact│
   │ G2 2nd architecture       │ MED     │ venue fit · front-matter       │
   │ G4 perf↔det Pareto (TF32) │ MED     │  → NONE scaffolded (g84 OPT-IN)│
   │ G5 cross-GPU-arch byte    │ MED     └────────────────────────────────┘
   │ G3 x86-macos cell         │ LOW (blocked: no Intel-Mac host)
   │ G6 musl fix CI-gate       │ LOW
   └───────────────────────────┘

   GO / NO-GO:  the RESULT is submission-grade NOW (4-env, 3-libm, $0-repro).
                A paper mainly needs PACKAGING (abstract/related-work/figures/
                artifact). G1 (real-corpus e2e) is the one substantive gap a
                strong venue may require — and it is GPU-build-gated, not
                blocked by the science.
```

---

## (e) GOVERNANCE NOTE + THE ONE USER ACTION

**No paper was scaffolded.** Per project.tape **g84** (the PAPER OPT-IN policy),
the agent does **not** propose `/paper`, does **not** auto-scaffold on discovery,
and does **not** create `PAPER.tape` / `PAPER.md` / any LaTeX. This document is
strictly a logged-discovery readiness assessment.

> **To scaffold the actual paper, the USER runs `/paper new
> flame-machine-independent` (or similar) — the agent does NOT auto-scaffold
> per g84.**

A paper happens **only** when the user explicitly types `/paper`, which they have
not. This assessment exists so the user can make that call with a clear go/no-go
picture and the exact action in hand.
