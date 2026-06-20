<p align="center">
  <img src="docs/logo.svg" width="140" alt="hexa-lang">
</p>

<h1 align="center">💎 hexa-lang</h1>

<p align="center"><strong>Native compiler with atlas-bound theorems</strong> — strict-lint · citation-enforced · no LLVM · self-hosting native fixpoint</p>

<p align="center">
  <a href="LICENSE"><img alt="License" src="https://img.shields.io/badge/license-MIT-blue"></a>
  <a href=".github/workflows/lint.yml"><img alt="CI" src="https://github.com/dancinlab/hexa-lang/actions/workflows/lint.yml/badge.svg"></a>
  <a href="https://doi.org/10.5281/zenodo.19404816"><img alt="DOI" src="https://zenodo.org/badge/DOI/10.5281/zenodo.19404816.svg"></a>
  <img alt="Phase" src="https://img.shields.io/badge/phase-A0%E2%80%93B5%20PASS-success">
  <img alt="M0" src="https://img.shields.io/badge/M0-PASS-success">
  <img alt="Atlas" src="https://img.shields.io/badge/atlas-hash%20pinned-informational">
  <img alt="Sibling" src="https://img.shields.io/badge/sibling-n6%20·%20hxc%20·%20n12%20·%20tape-blueviolet">
</p>

<p align="center">Atlas-bound · strict-lint · 8-stage gate · ε self-proof · n=6 perfect-number primitives · self-hosted</p>

---

`hexa-lang` is a native compiler that carries its own theorem 사전 (dictionary) inside the binary. **No LLVM anywhere** — the self-host backend lowers source through its own IR to native objects (a byte-identical `gen3 ≡ gen4` fixpoint) and links them with its own `hexa_ld`; `hexa run`/`hexa build` ship clang-free on the promoted toolchain. (Two C pieces remain by engineering necessity, not as unfinished debt: a C-transpile fallback delegate for some flows, and a libc/syscall runtime floor generated from `.hexa` emitters — the latter is **reducible**, not permanent: a 2026-06-16 falsification showed ~50% of the runtime is already portable to `.hexa` (a `.hexa` `fnv1a` is byte-identical to the C one) and zero-`.c` is an open, attackable campaign — `runtime_hi_gen.c` is now eliminated on **both** arm64-darwin and x86_64-linux via native `.s` seeds — the x86_64 backend was reworked (#3462) to carry the full HexaVal `{tag,payload}` pair like arm64 (its old "raw-int model" had dropped the tag, silently breaking native string functions; caught by a C-differential harness, fixed at the root, confirmed by all CI faithful + whole-compiler byte-eq gates green); a 2026-06-17 audit further found the `rt_str` family is already hexa-source-complete (every function has a native `.hexa` definition), so the remaining `.c` reduction is a standalone-build redesign — dropping the `#else` C-body fallbacks that duplicate the native source — not more function ports; the runtime-core port now has a symmetric pair of HexaVal leaf-intrinsics on both targets — `__hx_tag(v)` reads a value's tag and `__hx_make_val(tag, payload)` writes a `{tag, payload}` HexaVal from two raw words without boxing-tag-loss (so a payload word loaded from an array slot keeps its real element tag — verified on real x86_64: a `__hx_make_val(TAG_STR, ptr)` round-trips back as TAG_STR, not flattened to TAG_INT), unblocking native array/map element access; with that the collection-accessor read-half lane is now COMPLETE — the array (`get`/`set`/`pop`/`shift`) and map (`get`/`contains`) alloc-free primitives are ported to raw-memory `.hexa` bodies, shipping native via a frozen `.s` seed ar'd into `runtime.a` with the standalone C `#else` bodies DROPPED (the first non-string runtime-substrate `ls` byte-decrease, #3494–#3506, 13 PRs, every one preserving the `gen3≡gen4` fixpoint); the C-transpile bootstrap can't lower the raw-memory intrinsics (only the native backend can), so they enter the runtime via a native-emitted seed exactly like the `rt_str` family. The next frontier is the **alloc/write lane** (`set`/`push`/`new`), whose naive `#else`-drop is a measured NO-GO (the arena ships as C on both targets, so dropping it is a real link regression) — the live levers are an **M5 standalone-redesign** (native-compile the `self/rt/` tree so the write `#else` can finally drop) and the make_val-unlocked map construct-half — the first M5 brick already RUNs: a de-circularized multi-pool raw-memory bump arena (the allocator floor, re-shaped to address its pool table by raw pointer instead of a hexa array + `.push()`) native-emits through the shipping x86_64 backend and executes exit-0 on real hardware, non-circular (no malloc/push referenced), and that proven body is now ported into the real `self/rt/alloc.hexa` — the next blocker, located by a RAN emit, is porting `self/rt/syscall.hexa` off its P7-7 `syscall()` builtin onto the shipping `__hx_syscall6` leaf — its `__TARGET_OS__` half is already landed as a new `__hx_target_os()` const intrinsic (x86_64→linux, arm64→darwin, RUN-verified, gen3≡gen4 preserved), and all 25 of syscall.hexa's `syscall()` call sites are now rewritten to that `__hx_syscall6` leaf — the string→pointer gap is closed (a new `__hx_str_ptr` leaf) and the module-global data-slot gap too (x86_64 now emits a `.data g<id>:` slot, matching arm64 — a real parity bug fixed), so the combined alloc+syscall gate **emits + assembles + links clean**; the last blocker — the x86_64 backend had no module-global *write* path (it read `g<id>` but never stored to it) — is now FIXED (the lower's `arena_id==-999` sentinel write now emits `mov [rip+g<id>], payload`), so the combined alloc+syscall gate **runs exit-0 on real x86_64 — a C-free alloc+syscall integration proven end-to-end** (cross-pool arena grow + mark/rewind + reset, byte-exact, over fully-native syscall+alloc with no C body); the remaining work is the standalone relink — the alloc+syscall seed is now FROZEN (`self/native/alloc_syscall_{x86_64,arm64,arm64-linux}.s`, 116 native globals each) and arm64 write-parity is confirmed already-present, but the seed's pure leaves (syscall/pointer) have no C body to drop (the shipping runtime is libc-backed) and the arena is all-or-nothing (a different data structure from the C linked-block one), and the map construct-half turns out to be C memory-management orchestration (lazy-alloc + load-factor rehash + key-intern), not a pure-algorithm port — so the honest shape of the campaign is now clear: the EASY pure-algorithm reductions are exhausted (the read-half), and what remains is the **memory substrate floor** — the real next lever is porting the C arena itself to `.hexa` (linked-block allocator + RSS-hygiene, the hardest single body) — this is now underway: its address-envelope half (the part that keeps self-compile RSS bounded) is real code in `self/rt/alloc.hexa` and native-emit-verified, with the C-ABI half now DONE (linked-block alloc.hexa rewrite + seed regen, native-emit-verified, dormant; the build-wiring and arena `#ifndef` guard now in place (byteeq-inert until measured) and the ON measurement underway (it caught + fixed a stale seed, a seed-`main` clash, and confirmed whole-runtime byteeq — not standalone — is the right gate; the seed is now main-stripped so it ar's cleanly) — the whole-runtime byteeq/RSS measurement remaining) — it was scoped as: it is a linked-block rewrite (the C arena's mark is a 16-byte `{block*, used}` struct that callers pass by value, so the seed must adopt the C block-chain data structure, not the b2 pool table) — and that rewrite is now done: `self/rt/alloc.hexa` is a full HexaArenaBlock-chain arena (the `HexaArenaMark {block,used}` mark reuses the 16-byte HexaVal layout for a C-ABI-identical struct return), native-emit-verified, with the build-wiring + heapify↔envelope `#ifdef` + an x86_64 seed rodata fix now landed (byteeq-inert, OFF builds green) and the ON measurement RAN on real x86_64: the link is clean (the 16-byte mark struct-return ABI is confirmed compatible — the ABI-mismatch worry was refuted) and self-compile RSS stays bounded (~1.4 GB, the envelope reject works), but the whole-compiler transpile deterministically miscompiles on the large input because `hexa_val_heapify`'s slow-path (the loop that copies arena strings out to the heap) still walks the C arena struct, which the native seed never populates — so the heapify block-walk was wired to the native arena's block chain — and then a clean-rebuild isolation found the genuine root cause was a **C↔seed ABI mismatch** (and that the earlier "link-pass refuted the ABI worry" reading was misleading: the `mark`/`rewind` struct entries happened to match the C ABI, but every *scalar* seed entry did not): the native arena seed uses the HexaVal two-register calling convention (return value in `rdx`, tag in `rax`; an int arg as a `{tag, payload}` register pair) but the C runtime declared the seed entries as plain scalars, so it silently read the *tag* (always 0) instead of the value — making `hexa_arena_on()` report OFF and every block pointer / allocation come back null (the `tag 3 - tag 0` miscompile, and an earlier self-recursion, both trace to this); the fix is a **C-ABI bridge** that aliases each scalar seed symbol to its true HexaVal signature and wraps it (`#ifdef`-guarded, opt-in, OFF builds byte-identical), which eliminates the miscompile and drives execution *into* the native arena for the first time — exposing a deeper, pre-existing seed-codegen defect (a module-global's *tag* half is never persisted to its `.data` slot, only its payload), which is the now-narrow next blocker; after the arena, the map construct-half and the io/fmt/proc/fs/intern/math modules become genuine reductions; the honest accounting is in [ARCHITECTURE.json → Self-host status](ARCHITECTURE.json) (사람용 뷰어 `architecture.html`, `python3 serve.py`).) Every formula in your code either cites the atlas or the build refuses to start. The stricter the gate, the cleaner the code that passes.

## At a glance

```hexa
@cite(L[sigma_phi_n_tau_iff_n_eq_6])
fn perfect_at_six() -> bool {
    let n = 6
    return sigma(n) == 2 * n          // σ(6) = 12 = 2·6
        && phi(n) * tau(n) == 8       // φ(6)·τ(6) = 2·4 = 8 = σ(n)−n−φ(n)+1
}

// Untouched citation = HX8004 fatal at compile time:
//
//   error[HX8004]: formula-bearing function does not cite atlas L[*]
//     --> src/foo.hexa:14:1
//      |
//   14 | fn area_of_circle(r: f64) -> f64 {
//      | ^^^^^^^^^^^^^^^^^ formula here
//      = note: cite an atlas law via `@cite(L[id])` or declare `@grace(HX8004, until=, reason=)`
//      = help:  hexa atlas search "πr²"   →  L[circle_area]
```

The compiler stays parked unless every formula either cites the atlas, has an active `@verify`, or carries an explicit `@grace`. There is no "we'll fix it after." There is no binary.

## Why hexa-lang

LLMs answer by recombining what their weights already contain — noise from **inside** a frozen well. hexa-lang generates from **outside** the well: every compile cycle produces a primitive the previous cycle could not express, then absorbs it as a new wall (`@verify` → atlas promote → tombstone retroactive sweep). The atlas grows; hallucination is mechanically excluded because every claim must trace to a citation.

The second pillar is **enforcement at the build gate**, not at runtime. Eight strict-lint stages (S0 parse → S1 resolve → S2 bind → S3 type → S4 domain → S5 units → S6 equational `@verify` → S7 proof `@prove` → S8 citation `HX8004`) reject formula-bearing code that doesn't cite. No annotations means no formula. No formula in a non-cited function means a hard error.

Third: **n=6 perfect-number primitives**. The compiler is a 셰프 (chef) with a 4.2 MB atlas baked statically into the binary — 60,760 lines of P (primitives) / C (constants) / L (laws) / E (errors). Citing `L[sigma_phi_n_tau_iff_n_eq_6]` is one keystroke; if the law is wrong, every dependent gets a tombstone cascade with an auto-PR.

## Pipeline

```
   .hexa source
        │
        ▼
   lex ─► parse ─► resolve ─► bind ─► types ─► domain ─► units ─► citation
                    (S1)      (S2)    (S3)     (S4)     (S5)      (S8)
        │                                                            │
        │                  any fatal stage → no binary               │
        ▼                                                            ▼
   lower (HIR) ─► mono ─► MIR (SSA) ─► optimize ─► regalloc (LIR) ─► emit (asm)
        │                                                            │
        ▼                                                            ▼
                                  hexa_ld v1.1
                          ELF64 + Mach-O arm64 static
                                       │
                                       ▼
                                 native binary
```

A binary appears only when every fatal stage passes. The atlas (4.2 MB) is baked in at compile time — runtime cost: 0 ms.

* * *

## 🔥 flame · 🔧 forge · ⚡ hexa-cuda — the hexa GPU stack (train · substrate · kernel-authoring)

`stdlib/flame` is what you build *with* hexa-lang: a compiler-only neural-network training stdlib (autograd tape · layers · optimizers · tensor primitives) lowered through the same 8-stage strict-lint gate that compiles the compiler itself. No PyTorch wrapping, no ATen import, no Python in the trained binary.

`self/forge` is what flame calls into: a GPU substrate that pairs device-resident hexa arrays (`farr`) with own GEMM kernels — the FP64 and TF32 GEMM paths are **cuBLAS-free by default** (own kernels retire all 7 production `cublasDgemm`/`cublasGemmEx` calls; `HEXA_OWN_GEMM=0` / `HEXA_TF32_OWN=0` opt-OUT back to cuBLAS — measured 0.85~1.24× parity on sm_120, FP64 own bit-identical to cuBLAS) — plus 11 hand-emit `.cu` kernels covering the elementwise / reduction / norm surface, all under a byte-equal correctness contract, plus a BF16 Tensor-Core "mega-kernel" path (RFC 049/060) for the in-kernel-GEMM regime. own-GEMM is now the default device GEMM (cuBLAS is the opt-out fallback, no longer a hard dependency); the FP64 default is byte-neutral, the TF32 own path (under `HEXA_TF32_FASTMODE`) is byte-changing vs cuBLAS but confined to that already-approximate lane.

`@gpu_kernel → nvptx` (**hexa-cuda**) is how you author a GPU kernel *without leaving hexa*: annotate a function `@gpu_kernel`, write it with the device intrinsics (`gpu_thread_id_x` · `@shared let` · `gpu_barrier` · `gpu_atomic_add` · `gpu_warp_shuffle`), and `hexa build --target=nvptx` emits ptxas-clean PTX for `sm_80` / `sm_90` — no `.cu`, no `nvcc`, no CUDA-C transpile (silicon-proven: vec-add / saxpy run bit-exact on a native H100). It is the kernel-authoring primitive that **forge**'s own device kernels and your own custom kernels both share; you practice it in `hexa dojo`.

**The three pillars** (`flame:forge :: torch:ATen`, with hexa-cuda as the kernel-authoring leg both rest on):

```
              hexa source (.hexa)
                     │
   ┌─────────────────┴───────────────────┐
   │ 🔥 flame — NN training stdlib       │   ← what you TRAIN with
   │   t_* tensor · ag_tape autograd     │     (no Python in the binary)
   │   nn_lib layers · opt_* optimizer   │
   └─────────────────┬───────────────────┘
                     │  rides
                     ▼
   ┌─────────────────────────────────────┐
   │ 🔧 forge — GPU substrate            │   ← what flame CALLS INTO
   │   farr device array · own-GEMM      │     cuBLAS Dgemm + 11 .cu
   │   BF16-TC mega-kernel               │     RFC 040/041/049/060
   └─────────────────┬───────────────────┘
                     │  device kernels authored in
                     ▼
   ┌─────────────────────────────────────┐
   │ ⚡ hexa-cuda — @gpu_kernel → nvptx  │   ← how you WRITE a GPU kernel
   │   gpu_thread_id · @shared · barrier │     hexa → PTX → sm_80 / sm_90
   │   no .cu · no nvcc · compiler emits │     practice: `hexa dojo`
   └─────────────────┬───────────────────┘
                     │   hexa build (8-stage strict-lint gate)
                     ▼
              A100 / H100 native
```

### Correctness — byte-equal oracles (max\|Δ\| = 0, FMA-contraction-off recipe)

| layer | scope | measurement |
|---|---|---|
| forge substrate | RFC 040 device-farr + cuBLAS Dgemm · RFC 041 11-op `.cu` | **12 byte-equal fires** across the elementwise / reduce / GEMM surface, max\|Δ\| = 0 |
| flame layers | rmsnorm · attn-fwd · attn-bwd · silu-gate | **4 byte-equal oracle fires**, max\|Δ\| = 0 |
| flame `ag_tape` | generic autograd through the same oracles | derivation byte-equal, abstraction pays no correctness tax |

### Performance — measured (g3 / `LATTICE_POLICY`: real fires, falsifier-gated, no fabrication)

| path | measurement | note |
|---|---|---|
| **forge BF16-TC mega-kernel** (RFC 049 Stage 1, A100) | **9.67× faster than FP64 cuBLAS** @ Llama-7B FFN shape | $0.10 fire · paradigm verdict from Phase R 14-fire $2.91 campaign |
| forge Phase R / RFC 060 closure | FP64 mega-kernel **KILLED** (1.8-4.4× slower than per-op) · BF16 substrate **PASS** | RFC 060 100% closure · BF16-TC is the cuBLAS-relative wall path |
| flame `ag_tape` d=768 · 12-layer (A100) | per-step wall recorded · **PyTorch wall speedup NOT measured** | prior README "2.95× / 1.26-1.76× faster than PyTorch eager" was a unit mismatch (full-run / 1-step) — **RETRACTED** per `stdlib/flame/README.md` correction 2026-05-19 |
| **flame batch-fill SM-fill** (CLMConvMoE, H100) | **≥1.3× @B=2, 2.95× @B=32** self-speedup (byte-eq B=1 max\|Δ\|=0; B>1 causal-conv seam-only Δ) | batch FILLS the SMs (B=1 under-fills, util 1-2%); capped ~3× by the interpreted per-step glue (token-pack + CE-grad + AdamW ∝ B·Tw) — ~3x cap is STRUCTURAL (serial un-fused FP64 op-DAG); uncap = precision-change OR right-sized GPU, NOT interpreter (#2915) |
| flame vs PyTorch (matched-dtype, `F-BENCH-1`, RTX 5070) | **matched-dtype the gap is SINGLE-DIGIT: FP64 flame ties/wins (B=2 0.84× torch-eager, B=4/8 flame faster); TF32 torch 3.03× (B=1) → 7.88× (B=8)** ahead (cuBLAS-tuned GEMM vs flame's naive tiled GEMM). The old **~1656× / ~2207×** was flame-FP64-vs-torch-TF32 + a 2-point extrapolation of the **interpreted** full trainer at batch=1 — re-contextualized to single-digit by the matched-dtype `F-BENCH-1`. | honest: flame value = byte-exact · device-resident · no-LLVM, NOT step-rate; kernel-fusion (capture/replay, fwd+bwd) = ~1.0× closed-neg |

> Honest scope: flame's `ag_tape` + nn_lib + opt_* are functionally complete and byte-equal-verified; forge's `farr + cuBLAS Dgemm + 11 .cu` substrate is complete with the BF16-TC mega-kernel landing as the cuBLAS-relative wall path. End-to-end flame ↔ PyTorch wall comparison is **pending an apples-to-apples re-fire** — the substantive cuBLAS-relative win currently sits at the forge layer (BF16-TC 9.67× over FP64-cuBLAS on the FFN-shape mega-kernel).

#### flame + forge vs PyTorch + cuBLAS — the honest axis

**flame + forge is NOT three orders behind PyTorch + cuBLAS — matched-dtype the step gap is SINGLE-DIGIT, and on the axis it is built for it wins.** Measuring the **compiled** matched-dtype step (interpreter eliminated; `F-BENCH-1`, RTX 5070): at **FP64 flame TIES/WINS** (B=2 0.84× torch-eager — flame faster — and flame wins outright at B=4/B=8), and at **TF32 torch leads 3.03× (B=1) → 7.88× (B=8)** — cuBLAS-tuned GEMM vs flame's naive tiled CUDA-core GEMM. The old **~1656× (eager) / ~2207× (compile)** figure was flame-**FP64**-vs-torch-**TF32** (an unfair dtype mismatch) on the **interpreted** full trainer at batch=1, re-contextualized to single-digit by the matched-dtype `F-BENCH-1`. The hexa-owned own-GEMM reaches **parity (1.08× @D=2048, bit-exact), never a beat** — cuBLAS-TF32 is the roofline (`F-GPU-ROUTEA-KEEPBAND-MEASURE`); the own-GEMM-vs-cuBLAS-TF32 question is now SETTLED across both hardware regimes: **parity @Hopper-D2048 · own-EDGES-cuBLAS @consumer-D768 (0.95×, RTX 5070) · parity-not-beat @Hopper-large-D (~1.50× @D=4096, bit-exactness-bound — the better-single-pass-tile lever family is exhausted closed-neg)** (`F-OP54-SUMMER-OWNGEMM-TF32`, `F-OP52-TF32-GAP-CLOSE`, `F-OP55-NEWTILE-D4096`; consolidated in `docs/forge-routea-shape-adaptive.md`). **The parity result is dtype-scoped to TF32** — the FP16/BF16 own-GEMM (W14) is correct (`rel_rms ≤ 1e-2`, same-dtype) but **PARITY=NO, 11.5× off cuBLAS-FP16** (its roofline doubles), so own-GEMM ≈ cuBLAS parity holds for TF32, NOT FP16/BF16 (`F-FUSION-SM90-WGMMA-W14-FP16`; FLAME+FORGE-vs-PYTORCH+CUBLAS.md §4.1). The flame batch-fill (≥1.3× @B=2 → 2.95× @B=32) and TF32 fast-mode (4.2× @B=1) above are flame **self**-speedups, not PyTorch beats.

What flame + forge buys instead is a **different axis cuBLAS-using stacks cannot give**: **bit-exact reproducibility · machine-independence · device-residency · no-LLVM / no-Python**. The same fixed-seed step trains **byte-identically across 6 environments / 4 architecture-libc combos** (`flame-machine-independent-training.md`) — PyTorch does *not* guarantee this (libm transcendentals are not correctly-rounded, reductions are order-nondeterministic, cuBLAS DMMA order is vendor-"unspecified"). This is the same structural-ownership win as [§ *Where it beats cuBLAS-using stacks structurally*](#where-it-beats-cublas-using-stacks-structurally-whole-program-fusion--cublas-cannot-express): you pay a speed tax to buy a capability column cuBLAS leaves empty. **Use PyTorch + cuBLAS for throughput; use hexa flame + forge for bit-exact, auditable, vendor-free training.**

→ Full head-to-head with every number and source: [**`FLAME+FORGE-vs-PYTORCH+CUBLAS.md`**](FLAME+FORGE-vs-PYTORCH+CUBLAS.md).

### We now own the GEMM too — the device stack is 100 % hexa-ownable (CUDA-OWN campaign)

The substrate above used to call **cuBLAS** for the GEMM itself — the one piece forge did not own. The CUDA-OWN campaign closed that last gap: the **own-GEMM** (`HEXA_OWN_GEMM` family) now routes every matmul through a hexa-emit kernel instead of cuBLAS. **ON by default → own-GEMM is the default path**; `HEXA_OWN_GEMM=0` opt-OUT reverts to cuBLAS. The default device GEMM is hexa source — FP64 (bit-identical to cuBLAS), FP32, and a CUTLASS-grade TF32 WMMA2 tiled kernel.

```
forge GEMM dispatch (own-GEMM default-ON; HEXA_OWN_GEMM=0 == cuBLAS opt-out):
  OFF  → cuBLAS Dgemm / Sgemm                         (vendor, default)
  ON   → _hx_k_gemm (FP64)  ·  _hx_k_sgemm_cm (FP32)  ·  _hx_k_sgemm_cm_wmma2 (TF32 WMMA2)
         └─ launcher precedence WMMA2 > WMMA > TILED > naive ─┘   100 % hexa-ownable
```

**Correctness first (own-GEMM vs cuBLAS oracle):**

| own-GEMM path | shape / harness | correctness vs cuBLAS oracle | verdict |
|---|---|---|---|
| FP64 `_hx_k_gemm` (clm_prod train, cuBLAS-GEMM-free) | D1536 real-corpus train, both arms | **max\|Δ CE\| = 0.00000** @ 5-dec, CE descends 4.46624 → 3.64669 | 🟢 `F-FUSION-P1-OWN-GEMM-CORRECTNESS` |
| FP32 `_hx_k_sgemm_cm` (hxqwen14b train, cuBLAS-GEMM-free) | M=N=K=2048 R=16 GEMM-bound | **rel-RMS ~1e-6** (worst 9.70e-7) all outputs, within fp32 tol | 🟢 `F-FUSION-P1D-LLM-SGEMM` |
| TF32 `_hx_k_sgemm_cm_wmma2` (CUTLASS-grade tiled) | M=N=K=2048 + non-tile-multiple bounds | **rel-RMS 2.6e-4 ≪ 3e-3** TF32 bar, bounds-guarded | 🟢 `F-FUSION-CUTLASS-GRADE-WMMA` |

**Performance — ≈ cuBLAS-CLASS, NOT superiority (this is parity, stated plainly):**

| measurement | own-GEMM | cuBLAS | gap | verdict |
|---|---|---|---|---|
| sustained-loop GPU util (2048³, B200, nvidia-smi) | **89.9 % MEAN** / 100 % PEAK | 88.5 % MEAN / 100 % PEAK | both ~90 %, cuBLAS-class occupancy | 🟢 `F-FUSION-OWN-GEMM-UTIL` |
| GEMM-iso step-time (2048³ WMMA2 vs cuBLAS) | 0.77047 ms/iter | 0.68 ms/iter ref | **1.13× of cuBLAS** (within ~13 %) | 🟢 `F-FUSION-CUTLASS-GRADE-WMMA` |
| LLM full-step (LoRA, M=8192, shape-dispatch + split-K) | 454.9 steps/s | 565.2 steps/s | **1.24× of cuBLAS** (down from raw 2.24×) | 🟢 `F-FUSION-THRU-PARITY` · `F-FUSION-SPLITK-SKINNY` |

The full-step gap closed in two landed steps: skinny-shape dispatch (16×16 tiled) took the raw **2.24× → 1.67×** (~46 % of the gap, `F-FUSION-THRU-PARITY`), then a split-K skinny GEMM took **1.67× → 1.24×** (a further 64 % of what remained, `F-FUSION-SPLITK-SKINNY`) — cumulatively ~80 % of the original 2.24× closed.

> **⚠ ARCH CAVEAT — the 1.13× iso figure is Blackwell-sm_120-ONLY; native sm_90 H100 is a different story (`F-FUSION-WMMA2-SM90-VERIFY` #2796 · `F-FUSION-SM90-DYNSHARED-FIX`).** The WMMA2 kernel's staging is 57 344 B of shared, which **exceeds the sm_90 per-block *static* `__shared__` cap (49 152 B)** — so on **native Hopper sm_90** the kernel originally **did not launch at all** (`cudaErrorInvalidValue`); the 1.13× was measured on Blackwell sm_120, whose larger static admit absorbed it. **`F-FUSION-SM90-DYNSHARED-FIX` converts the staging to `extern __shared__` (dynamic) + `cudaFuncSetAttribute(...MaxDynamicSharedMemorySize, 57344)` — this DOES make WMMA2 LAUNCH on sm_90** (compute_cap 9.0 verified, correctness rel-RMS 4.77e-06 PASS). **But native-H100 PARITY is NOT restored**: on sm_90 the own WMMA2 GEMM measures **1.49 ms/iter @ 2048³ = 29.46× *slower* than cuBLAS** (0.0507 ms/iter), because the kernel is **register/occupancy-bound on Hopper** (REG:236/thread → ~1 block/SM). The Blackwell 1.13× **did not transfer** to native sm_90 — a separate occupancy axis, not the shared-mem launch fix.
>
> **↳ occupancy axis TESTED and RULED OUT (`F-FUSION-SM90-WARPTILE-RETUNE`, closed-negative).** A register-reduced WMMA2 variant (`_hx_k_sgemm_cm_wmma2_rr`, env `HEXA_OWN_GEMM_WMMA2_RR`, default OFF, math-identical) cut registers **236 → 128/thread** via `__launch_bounds__(256,2)` + streamed input fragments, **doubling occupancy 1 → 2 blocks/SM** — yet on native sm_90 H100 own throughput did **not** rise: **11.1 → 10.7 TFLOP/s** (-4%, the cuBLAS gap *widened* 31.4× → 32.5×; rel-RMS 4.77e-06 both). So **register/occupancy is NOT the binding constraint** — the WMMA2 own-GEMM is bound by its **inner-loop math pipeline** (per-element software `__float_to_tf32`, depth-1 cp.async prefetch, scalar epilogue), not block count. Closing the ~31× sm_90 gap needs a cuBLAS-class TC mainloop rework (deep pipelining, `ldmatrix`/`mma.sync` w/o per-element TF32 rounding, register-blocked accumulation), a multi-session pipeline rewrite — not a one-knob retune.
>
> **↳ cuBLAS-class mainloop ATTEMPTED — 3/4 levers landed, mma.sync is the ceiling (`F-FUSION-SM90-CUBLAS-MAINLOOP`, closed-negative).** A reworked own-GEMM (`_hx_k_sgemm_cm_wmma2_cb`, env `HEXA_OWN_GEMM_WMMA2_CB`, default OFF) landed three of the four cuBLAS-class levers: **L1 hardware-TF32 `mma.sync.m16n8k8`** (round fused via `cvt.rna.tf32.f32`, dropping the per-element software `__float_to_tf32` sweep), **L2 a deep multi-stage `cp.async` pipeline**, and **L4 a register-blocked epilogue** (4 D-regs/thread written straight to col-major C). The fourth, **L3 `ldmatrix`, did NOT land** — `ldmatrix.x4` is a 16-bit-element op and the TF32 operands are 32-bit (named residual: a 32-bit `ldmatrix.trans` swizzle). On native sm_90 H100 (2048³) the CB variant is **numerically exact** (rel-RMS **0.000e+00**, bit-equal to the cuBLAS-TF32 oracle on this seed) and **+3.4% faster than the parent** (11.17 → **11.55 TFLOP/s**, gap 30.4× → **29.4×** — only ~3.4% of the cuBLAS gap closed). The on-pod stage-depth sweep **saturated at 2 stages** (a second independent confirmation that global→shared latency is not the bottleneck). **Finding:** the binding constraint is the **`mma.sync` warp-level instruction class itself** — on Hopper, cuBLAS reaches TC peak via **`wgmma.mma_async`** (warpgroup-level async MMA) fed by **TMA** (`cp.async.bulk.tensor`), a different instruction class `mma.sync` cannot reach regardless of mainloop tuning. The remaining ~29× is a **wgmma + TMA rewrite** (a CUTLASS-3.x-class sm_90a kernel), not an `mma.sync` mainloop retune. Honest scope: parity-seeking, cuBLAS = roofline, no superiority claim.
>
> **↳ wgmma + TMA rewrite — FEASIBILITY PASS, layout residual (`F-FUSION-SM90-WGMMA-TMA`).** The named wgmma/TMA lever is now **build- and run-feasible on native sm_90 H100**: with `-arch=sm_90a` (nvcc 12.6), **`wgmma.mma_async` executes correctly** (f16 probe: nonzero 2048/2048, sum 1962.49 vs ref 1956.87) and the **entire Hopper async PTX surface compiles** — `cuTensorMapEncodeTiled` (TMA) + `cp.async.bulk.tensor.2d.shared::cluster.global.mbarrier::complete_tx::bytes` + `mbarrier.*`. This **converts** the prior `F-FUSION-ATTN-WGMMA-WALL` hardware-blocked closed-negative (same kernel silently NOP'd on Blackwell sm_120) into testable-on-Hopper. **The own-source emit path is NOT the blocker.** The standalone TF32 warpgroup mainloop builds + launches but is **not yet bit-correct** (rel-RMS **1.309e+00** vs 3e-3); an isolated descriptor sweep + a structured-input diagnostic proved the binding residual is the wgmma **no-swizzle 8×16B core-matrix shared-memory layout** of the operands (NOT the instruction, descriptor offsets, or the verified-correct epilogue register→C mapping). **No own GFLOP/s is reported** — g5 forbids perf on a wrong-result kernel; **parity NOT measured**. Kit: `self/native/wgmma/`. Honest scope: parity-seeking, cuBLAS = roofline, no superiority claim.
>
> **↳ swizzle wedge — residual PINNED to the B-operand K-core stride, NOT a permutation (`F-FUSION-SM90-WGMMA-SWIZZLE`, closed-negative this pass).** An on-hardware reverse-engineering (distinct-ramp operand + one-hot selector; native H200 sm_90a, nvcc 12.6, pod DESTROYED leak 0) isolated the rel-RMS 1.309 residual to **two superimposed defects in the wgmma B no-swizzle core-matrix layout**: (1) a **K-stride collapse** — for contraction index k=1..7 wgmma re-reads B's K=0 core-matrix (the decoded k′ is pinned to 0 for every K-selector), the dominant ≈√2 error; (2) an **N-octet interleave** (output col n reads logical col ≈4n within an 8-wide octet). A **>2300-config exhaustive sweep** — A/B shared layout ∈ {plain row-major, two 8-row-strip core tilings, col-major-B} × descriptor (LBO,SBO) ∈ {16…512} for both operands × 3 epilogue register-maps, fault-isolated per-process — found **no config below rel-RMS 1.36**, **deterministically ruling out** the hypothesis that the residual is a plain-layout/offset/epilogue permutation. The fix **requires the genuine CUTLASS `GMMA::Layout` core-matrix builder** (B's 8 K-values forming a contiguous 8-row core-matrix, descriptor LBO = one-core-matrix stride, swizzle field matched to the TMA `cuTensorMapEncodeTiled` swizzle mode), verified FIRST on the single-tile decode probe to k′==KSEL identity before any 2048³ run. Kit: `self/native/wgmma/{wgmma_tf32_decode,wgmma_tf32_bdecode,wgmma_tf32_full}.cu`. Still **parity-seeking, no perf number on a non-bit-correct kernel (g5)**.
>
> **↳ GMMA::Layout core-matrix builder — wgmma TF32 is now BIT-CORRECT on native sm_90a (`F-FUSION-SM90-WGMMA-GMMA-LAYOUT`, 🟢 numerical).** The swizzle is **SOLVED**. The root cause of the >2300-config dead end was a single wrong constant: a wgmma core matrix is **8 rows × 16 bytes = for TF32 (4 B/elem) 8 rows × 4 ELEMENTS**, not the **8×8 K-strip** the prior kit assumed — that 8-vs-4 mismatch **is** both pinned defects (K-stride collapse + N-octet interleave). Implementing the real CUTLASS-3.x **GMMA INTER (no-swizzle) 8×4 core-matrix layout** (`gmma_phys = (strip*2+kcore)*32 + sr*4 + kc`, descriptor `start[0,14) LBO[16,30) SBO[32,46) layout_type[62,64)=INTERLEAVE`, LBO=128 B / SBO=256 B inter-core strides) made the **single 64×64×8 wgmma tile bit-exact** (**W2 rel-RMS 0.000e+00**, native H100 SXM cc 9.0, `-arch=sm_90a`, nvcc 12.6, pod DESTROYED leak 0). Scaling to the full **2048³** GEMM revealed a second, *separate* defect — a K-loop **async-proxy ordering** bug (`wgmma` reads shared through the async proxy, which ordinary `__syncthreads` does **not** order against generic stores; non-deterministic 3e-2…1e-1 past K≈1536). Adding **`fence.proxy.async.shared::cta`** after staging makes the K-loop **bit-exact at 2048³** (**W3 own-vs-cuBLAS-TF32 & own-vs-CPU-f64 both rel-RMS 0.000e+00, deterministic**). **Parity is now MEASURABLE** (g5 satisfied): the naive single-wgmma-per-block kernel runs **20.2 TFLOP/s @ 2048³** (cuBLAS-TF32 357.5, **17.67× off**, PARITY=NO); a first pipeline tune (wide-N **TN=128**, 2 wgmma/K-step reusing A) nearly doubles it to **38.0 TFLOP/s (9.35× off)**, still bit-exact (TN=256 is slower — register/occupancy bound). **The own-GEMM is now provably CORRECT on sm_90a; the remaining gap is a pure latency-hiding residual** — a full **warp-specialized TMA multi-stage** CUTLASS mainloop (`cp.async.bulk.tensor` producer + `wgmma` consumer, deep pipeline), a multi-session build — **NOT the layout (solved) and NOT correctness (bit-exact 2048³)**. cuBLAS = roofline, no superiority claim. Kit: `self/native/wgmma/{wgmma_tf32_gmma,wgmma_tf32_gemm2048,wgmma_tf32_gemm_w5,wgmma_tf32_gemm_w5b}.cu`.
>
> **↳ sm_90a wgmma+TMA own-GEMM (Hopper) — the latency-hiding ladder W6→W10 → then the canonical-atom leap to TF32 cuBLAS-PARITY (`F-FUSION-SM90-WGMMA-OG16/OG17`, 🟢 PARITY).** With the layout solved and the kernel bit-exact, the residual is pure async-pipeline engineering, and it is now being walked down rung-by-rung on native sm_90a H100 — each rung **bit-exact** (rel-RMS **0.000e+00** vs the cuBLAS-TF32 oracle), perf reported only because the kernel is bit-correct (g5):
>
> ```
> sm_90a wgmma+TMA own-GEMM ladder (TF32, @4096³, native H100 sm_90a, bit-exact rel-RMS 0):
>   rung  lever                                   own TFLOP/s   gap vs cuBLAS-TF32 (~431)   occupancy
>   W6    async cp.async pipeline                    50.7              8.39× off               —
>   W8    HW-TMA single-elected-thread producer      66.5              6.44× off            2 CTA/SM
>   W10   composed swizzle-decode (permute-free)     70.7              6.09× off            2 CTA/SM
>   OG16  canonical-atom (global re-encode · band-free) 264.7           1.37× off            2 CTA/SM
>   OG17  + relaxed-pipeline ping-pong (S=2048)      280               1.24× off  ★ PARITY  2 CTA/SM
>   route-(a) b14 MODE 8 NST=3 PDEP=2 (@D=2048)      ~315              1.08× off ★★FRONTIER 2 CTA/SM
>   ─────────────────────────────────────────────────────────────────────────────────────────────
>   cuBLAS-TF32 ≈ 431 (@4096) / ≈342 (@D=2048) roofline — route-(a) is the @D=2048 FRONTIER (1.08×,
>   ≈93% of roofline) SUPERSEDING the OG17 1.24× rung; both bit-exact rel-RMS 0 (NOT beaten, no superiority)
>   FP16 port (OG18/OG19): own 504 TFLOP/s · 13.37×→1.64× off cuBLAS-FP16 (recipe generalizes; 2× roofline = the ceiling)
> ```
>
> W6's async pipe (50.7) gave way to **W8**'s hardware-TMA producer — a single elected thread drives `cp.async.bulk.tensor` while the TMA engine does the global→shared copy, freeing the producer warpgroup and shrinking the CTA to **2 CTA/SM** (66.5 TFLOP/s, 6.44× off, `F-FUSION-SM90-WGMMA-W8`). **W10** then composes the FP32 `SWIZZLE_128B` law with the GMMA-INTER 8×4 core packing into a software composed-decode, eliminating the per-K-step permute scratch (SASS 28 STS → 0) so the kernel stays permute-free at full 2 CTA/SM: **70.7 TFLOP/s @4096³, 6.09× off cuBLAS-TF32 (430.8), bit-exact rel-RMS 0** (`F-FUSION-SM90-WGMMA-W10`, PRs #2841/#2847). **PARITY IS NOT ACHIEVED — at 6.09× off, cuBLAS-TF32 remains the roofline and there is NO superiority claim.** This is honest parity-*seeking* progress: the win is that the wgmma+TMA own-source path is **bit-exact**, and the named residual is **async-pipeline engineering** (larger tiles / warp-specialization / ping-pong, per research note #2846) — **NOT a missing algorithm** and **NOT a correctness gap**. Kit: `self/native/wgmma/{wgmma_tf32_warpspec,wgmma_tf32_w10}.cu`.
>
> **↳ OG16→OG17 — TF32 own-GEMM CROSSES cuBLAS PARITY on native sm_90a (`F-FUSION-SM90-WGMMA-OG16/OG17`, 🟢 PARITY, PRs #2866/#2870).** The named async-pipeline residual is now CLOSED at S=2048. **OG16** found the real lever the W-ladder was missing: re-encode A/B **in global memory** into the canonical CuTe `Layout_K_SW128`/gmma-INTER atom + a no-swizzle TMA, so the SMEM tile **is** the wgmma operand (descriptor-direct) — the 32 KB in-kernel decode band is GONE, not just removed-then-decoded. That dissolved the decode-band⊥occupancy wall (OG11→OG15 had FALSIFIED a descriptor-field-only fix) and took own **70.2 → 264.7 TFLOP/s, 6.09× → 1.37×**, smem 96→64 KB @ 2 CTA/SM, bit-exact rel-RMS 0 @2048³&4096³. **OG17** then added the relaxed-`wait_group 1` ping-pong pipeline (next K-slab's wgmma issue overlaps this slab's tensor-core drain, mbarrier-ring safe, 2 CTA/SM held) → own **280 TFLOP/s, ratio 1.24× = PARITY (≤1.3×)** @ S=2048, bit-exact, ≈81 % of cuBLAS-TF32. **The 'native-H100 own-GEMM can't reach cuBLAS-TF32' wall is CLOSED.** The **route-(a) b14 MODE 8** kernel (global pre-permute, no-swizzle TMA, descriptor-direct) then **SUPERSEDES OG17** as the @D=2048 frontier — own **≈315 TFLOP/s, ratio 1.08× (≈93 % of the cuBLAS-TF32 roofline), bit-exact rel-RMS 0**, reproduced and slightly beaten vs the pre-registered ~1.10× (`F-GPU-ROUTEA-KEEPBAND-MEASURE`; this is the **1.08× headline** quoted in §"flame + forge vs PyTorch + cuBLAS" and the own-GEMM parity map). Honest residual: @4096 stays 1.50× (own ≈284 vs cuBLAS ≈427, bit-exactness-bound, the 256-tile/CTA-swizzle lever family exhausted closed-neg — `F-OP45GPU-OCCUPANCY-SWEEP`, `F-OP52-TF32-GAP-CLOSE`, `F-OP55-NEWTILE-D4096`). **OG18/OG19** port the SAME recipe to FP16/BF16 (re-derived 8×8/128B f16 atom) — own **61 → 504 TFLOP/s, 13.37× → 1.64×** off cuBLAS-FP16 (+8.2×, bit-exact rel_rms 0): the canonical-atom recipe **generalizes across dtype**, but FP16 PARITY is NOT crossed (1.56–1.64×) because cuBLAS-FP16's roofline is ~2× TF32 and the residual is occupancy/pipeline-depth on that doubled roofline. cuBLAS = roofline throughout, parity-seeking, no superiority claim. The reusable recipe (canonical-atom · relaxed-pipeline · the under-fill/saturated regime law) is folded into `commons.tape` g82 + the hexa dojo (PR #2869). Kit: `self/native/wgmma/{wgmma_tf32_og16,wgmma_tf32_og17,wgmma_fp16_og18}.cu`.

**Util is a workload-size property, not a defect** (`F-FUSION-D2-RIGHTSIZED`): the *byte-identical* D1536 own-GEMM step that under-fills an idle **H100 to ~13 % MEAN** (median 2 %) **saturates a right-sized RTX 5070 to 98.00 % MEAN** (every sample 98 %, SM 98 %, compute-bound) — the 2048³ large shape gives 99 % on the same 5070. Low util on the H100 is the H100 being too big for a D1536 model, not a codegen flaw; given a GPU sized for the workload, util is at the saturation ceiling.

**The sizing axis is now measured-exhausted on the *real full step* — util-GREEN is structural, not a knob (`F-FUSION-M3` · `F-FUSION-M5`).** Two falsifiers ran on the real `clm_prod` training step (not a standalone GEMM) on an idle H100: scaling the model **`D` 1536→4096 makes util *worse*** (MEAN 10.57 % → 6.64 %, `F-FUSION-M3`), and growing the **batch `B` 1→32** (GEMM M-dim 512→16384) leaves util **flat at ~0.45 %** (`F-FUSION-M5`, MEDIAN 0 % throughout). Neither bigger-model nor bigger-batch fills the GPU — the wall is the **serial per-step structure**: FP64-GEMM bursts separated by per-position glue idle the device *between* launches, so MEAN util is a duty-cycle invariant to workload height. The only measured lifts are a **precision change** (TF32 megakernel, +3–5 pp below) or a **right-sized GPU** (the RTX 5070 above) — *not* scale. This is the honest closure of the util-99 % north-star: on a big GPU at small `D`/`B`, 99 % is unreachable by sizing.

> Honest limits (g5): the own-GEMM is **≈ PARITY, not superiority** — it is still **1.13× (iso, Blackwell sm_120) to 1.24× (full-step) slower than cuBLAS**, never faster. **The 1.13× iso parity is sm_120-specific**: on native Hopper **sm_90** the same WMMA2 GEMM is **29.5× off cuBLAS** (occupancy-bound) and originally would not even launch — see the ARCH CAVEAT above. The README's existing honesty that *"a single huge GEMM already ties cuBLAS at roofline"* **still holds** — owning the GEMM does not change that ceiling, it just makes the ceiling hexa-owned. And the **BF16-TC 9.67×** above is a **separate dtype axis** (BF16-TC vs FP64-cuBLAS); it is **NOT** the own-vs-cuBLAS *same-dtype* comparison reported here. The win of owning the GEMM is **not speed — it is capability cuBLAS structurally cannot offer.**

#### ⭐ The trade, stated plainly — you pay a small parity tax to buy four capabilities cuBLAS cannot give

A ~13–24 % same-dtype speed tax buys a column cuBLAS leaves empty. These are **capability** wins (what is *possible*), not speed wins — and they are exactly what hexa's domains (reproducible science, byte-equal CLM/RTSC, megakernel fusion) require:

| capability you gain | own-GEMM | cuBLAS | proof / where it pays off |
|---|---|---|---|
| 🎲 **Determinism (byte-exact)** | bit-reproducible by construction — *you* fix the reduction order | DMMA accumulation order is vendor-**"unspecified"**, drifts across GPU generations, **un-matchable from outside** | the byte-eq capstone (`max\|Δ\| = 0`) · audit-grade reproducible training · clean A/B (zero GEMM noise) · multi-GPU bit-consistency |
| 🧩 **Fusion (megakernel-resident)** | callable *inside* a persistent / cooperative kernel — GEMM becomes just another resident op | **cannot be nested** in a device kernel (host library call) — forces "stop, write HBM, hand off" | whole-step megakernel (`F-FUSION-M2`) · 11-op fwd in 1 launch (`F-FUSION-LAUNCH-AMORT`) · FlashAttn-style fused attention |
| 🔢 **FP64-exact + custom epilogue** | arbitrary precision + fused epilogue in one kernel; FP64 GEMM is a byte-exact oracle | FP64 **epilogue fusion absent**; IEEE-float only | `clm_prod` FP64 train `max\|ΔCE\| = 0` (oracle baseline) · RTSC/DFT-grade FP64 science · non-IEEE dtypes (posit · n=6 lattice) |
| 🔓 **Ownership (no vendor lock)** | 100 % hexa source → PTX → SASS, no LLVM, self-host native fixpoint, single binary | closed black box, NVIDIA-only, multi-GB libtorch to ship | edge / offline single-binary deploy · SASS-level kernel research · the 💎 identity |

**Net:** *"≈ cuBLAS speed (−13–24 % tax) **+** determinism + fusion + FP64-exact + ownership that cuBLAS cannot express."* For a workload that just wants a fast standalone matmul, cuBLAS is simpler and faster. For hexa's targets — reproducible, fusible, owned, FP64-correct — the trade is decisively worth it, and the **byte-eq megakernel capstone is the existence proof**: it is *only* reachable on the own-GEMM stack.

### Where it beats cuBLAS-using stacks structurally (whole-program fusion · cuBLAS cannot express)

`cuBLAS` ships a champion *part* (the GEMM kernel itself, already at roofline), but cannot fuse adjacent ops — each op pays a separate kernel launch + a full HBM round-trip. hexa codegen sees the whole expression and emits one kernel that keeps intermediates in registers / shared memory:

```
cuBLAS-using stack (current default — 3 ops = 3 launches, 3 HBM round-trips):
  ┌──GEMM──┐         ┌──bias──┐         ┌──GeLU──┐
  │ launch │ → HBM → │ launch │ → HBM → │ launch │ → HBM
  └────────┘         └────────┘         └────────┘

hexa fusion (whole-program — one kernel, registers/shmem reused):
  ┌──── GEMM + bias + GeLU ────┐
  │  1 launch · 1 HBM write    │ → HBM            (F-FUSION-EPILOGUE-GEMM-BIAS-GELU)
  └────────────────────────────┘                  66.667 % launch + HBM-write reduction
```

The same mechanic generalises: GEMM-epilogue, norm surface, attention block, autoregressive decode chain — every place where cuBLAS forces "stop the GEMM, write to HBM, hand off to the next op" hexa can keep the value in registers.

**Owning the GEMM unblocks the whole-step megakernel — both walls are now closed, and it is realized byte-equal on the real training step.** The strongest form of the fusion above is a single persistent / cooperative kernel that holds the whole step in registers + shared memory across a grid-wide barrier. Two structural walls capped this. **Wall 1 — the cuBLAS-call wall:** a persistent kernel **cannot call cuBLAS** (you can't make a host library call from inside a running device kernel). Now that the GEMM is **our own device kernel** (`_hx_k_sgemm_cm_wmma2`, correctness-verified above), the persistent kernel **calls our GEMM in-line** — the GEMM stops being an un-fusable cuBLAS hand-off and becomes just another op the megakernel keeps resident. **Wall 2 — the GroupNorm full-Y reduction:** the GN reduction over all T·C could not previously live inside the persistent kernel without re-associating the FP64 sum (breaking byte-eq). A **grid-sync cooperative kernel** (`cudaLaunchCooperativeKernel` + `this_grid().sync()`) now closes it: the reduction stays single-thread sequential, so it is **byte-eq max|Δ|=0** vs the sequential GroupNorm oracle, deterministic (`F-FUSION-MEGAKERNEL-GN-GRIDSYNC`, #2845, A100-confirmed). **With both walls closed the whole-step glue megakernel is fully realized — 100 % hexa-owned, cuBLAS-call-free.** Honest scope (g5): closing Wall 2 is a **CLOSED-NEGATIVE on util** — its value is **ownership / structural completeness, NOT a util or throughput win**. byte-eq *forces* the reduction single-thread, so the cooperative launch buys **zero reduction-parallelism** (idle threads wait at the barrier); no util/perf superiority is claimed. Landed + measured on the real `clm_prod` step:

| megakernel realization | what is fused into ONE cooperative launch | result | verdict |
|---|---|---|---|
| **whole-step megakernel** (`F-FUSION-M2`) | fwd + ce-grad + bwd + AdamW (17 per-param AdamW launches → 1) | [FULLSTEP-FIRED], CE converges, real-step util **+3.4 pp** | 🟢 `F-FUSION-M2-FULLSTEP-MEGAKERNEL` |
| **TF32 fwd megakernel** (`F-FUSION-P1`) | all fwd GEMMs pulled in (no cuBLAS), TF32 own-GEMM | util **29.0 → 34.5 % MEAN (+5.5 pp)**, CE descends | 🟢 `F-FUSION-P1-TF32-MEGASTEP` |
| **byte-eq megakernel CAPSTONE** (`F-FUSION-P1B-a‴`) | device-resident fwd, own-GEMM, cooperative — vs eager reference | **max\|Δ\| first_ce = last_ce = 0.000000e+00** (17-digit CE bit-identical), util **+4 pp while byte-identical** | 🟢 `F-FUSION-P1B-APRIME3-ASYNCOFF` (#2792) |
| **both walls closed** (Wall 1 cuBLAS-call via own-GEMM · Wall 2 GN full-Y reduction via grid-sync) | grid-sync cooperative GroupNorm — last un-fusable op now megakernel-resident | **byte-eq max\|Δ\|=0** vs sequential GN, deterministic · CLOSED-NEG on util (win = ownership/completeness, **not** a perf lift) | 🟢 `F-FUSION-MEGAKERNEL-GN-GRIDSYNC` (#2845) |

The capstone is the payoff this section gestures at, *proven*: a +util cooperative megakernel that is **byte-equivalent to the eager reference** (`max\|Δ\| = 0`) — something **impossible with cuBLAS** twice over (cuBLAS can neither be nested in a persistent kernel **nor** bit-matched from outside, its DMMA accumulation order being vendor-"unspecified"). The five-layer hunt for the last `~1e-1` non-determinism (`F-FUSION-B6` → `P1B-a''`) closed on the true cause: an **async cross-stream race**, not a transcendental or GEMM-order issue — `F-FUSION-N1N2` proved every glue kernel is deterministic in isolation and that **`HEXA_CUDA_ASYNC=0` makes the device forward bit-reproducible** (CE `4.4662394504526679` ×5 identical). **For byte-reproducible training, set `HEXA_CUDA_ASYNC=0`** (the synchronous, single-ordered-stream path).

| finding | reduction / win | tier |
|---|---|---|
| `F-FUSION-EPILOGUE-GEMM-BIAS-GELU` | **66.667 % launch + HBM-write reduction** (3 launches → 1) @ LLaMA-7B FFN shape, ptxas-clean sm_80 | 🔵 structural-formal |
| `F-FUSION-LAUNCH-AMORT` | 5-op chain → 1 launch / 3 HBM transfers vs separate-op 5 launches / 11 transfers | 🔵 + `$0` deterministic oracle |
| `F-FUSION-AXISA-BREADTH` (norm surface) | LayerNorm 66 % · RMSNorm 59 % · Softmax 65 % · SwiGLU 63 % | 🔵 structural-formal |
| `F-FUSION-ATTENTION-FLASH` | single-kernel fused attention (Q·K · softmax · V) | 🔵 + wall ruled-out |
| §5j `Custom reductions` — LogSumExp 1-kernel (#1657) | numerically-stable max-shift + exp + log + sum in one kernel, silicon-validated rel_err 1.7e-10 | 🟢 SUPPORTED-NUMERICAL |

### 🎯 Who benefits — 7 user personas (the pain → the gain)

cuBLAS-using stacks ship a champion *part* (the GEMM kernel, already at roofline). hexa wins where **the part isn't the bottleneck — the chain around it is**. Whether that helps *you* depends on which pain you actually carry:

| persona | pain you carry | what hexa gives |
|---|---|---|
| 🧪 **LLM trainer / inference engineer** | attention · norm · decode are memory- / launch-bound — stuck on top of PyTorch | fusion strikes that region directly — 3-op chain → 1 launch + 1 HBM write (66 % ↓) · FlashAttn-style single kernel |
| 🔬 **GPU kernel researcher** | cuBLAS is a black box — wants SASS-level visibility but can't get it | source → PTX → SASS visible end-to-end · cubin lives in the repo |
| 📦 **Single-binary deployer** (edge / embedded / offline) | can't ship Python + libtorch (multi-GB) to the target | native arm64 / x86_64 single binary · no Python in the trained artifact |
| 🔢 **Non-IEEE arithmetic** (posit · interval · n=6 lattice) | cuBLAS is IEEE-float only | custom-dtype codegen — new arithmetic rides the same fusion path |
| 🧠 **Autograd debugger** | PyTorch C++ Autograd is a black box, can't step through it | `ag_tape` is all hexa source — read it line by line |
| 🎯 **Byte-equal correctness** (science · reproducibility) | PyTorch run-to-run drift is common | byte-equal oracles + FMA-contraction-off recipe, max\|Δ\| = 0 |
| ⚡ **Fast codegen iteration** | hand-CUDA hell — rewrite the fusion every time | the compiler fuses for you — one `@gpu_kernel` annotation |

```
Where does hexa's fusion gap land hardest?
                cuBLAS-using stack ─────────┐
                    │  (huge standalone GEMM is fine — can't beat)
                    ▼
  ┌────────────────────────────────────────┐
  │  Intersection where hexa fusion wins   │
  │   ① many memory-bound patterns         │  ← LLM training / inference
  │   ② Python-free deploy                 │  ← edge · embedded · offline
  │   ③ correctness OR visibility needed   │  ← research · science · repro
  │   ④ long chains (decode/optim/AdamW)   │  ← training loop
  └────────────────────────────────────────┘
```

### 🍳 Where fusion fires — memory-hierarchy asymmetry

GPU register ~1 cycle vs HBM ~600 cycles. cuBLAS writes the result to HBM after every op so the next op can read it back; fusion keeps the value in registers.

| scenario | why fusion wins | measured |
|---|---|---|
| **GEMM + elementwise epilogue** (bias · ReLU · GeLU · dropout) | GEMM output is a large tensor — next op reuses it immediately | F-FUSION-EPILOGUE 66.7 % ↓ |
| **norm surface** (LN / RMSNorm / Softmax / SwiGLU) | reduce + immediate-neighbor reuse · norm is memory-bound | AxisA LN 66 % · RMS 59 % · SM 65 % · SwiGLU 63 % |
| **Attention block** (Q·Kᵀ · softmax · V) | giant intermediate attention matrix → avoiding HBM round-trip is the win | F-FUSION-ATTENTION-FLASH 🔵 |
| **Small-op chain** (LLM autoregressive decode · AdamW step) | launch overhead dominates over compute | F-FUSION-LAUNCH-AMORT 5-op → 1 launch |

```
fusion gain  =  (chain length)  ×  (memory-bound-ness)  ×  (intermediate-tensor size)
```

Honest scope on where it *doesn't*: a single huge GEMM (already compute-bound, ties cuBLAS at roofline) · a lone op (nothing to fuse) · very small GEMMs (launch-bound is the real problem, not fusion).

**One line**: cuBLAS = a one-dish specialist (master of the stew). hexa fusion = a one-pan dinner (multiple steps in sequence on the same heat). Users whose workload's time distribution overlaps the four scenarios above land on hexa's real gap.

Detail: `stdlib/flame/README.md` (canonical perf table + RETRACTION note) · `stdlib/flame/PERF.md` · `stdlib/flame/PLAN.md` (campaign log + cycle ledger) · `self/forge/PLAN.md` · `self/forge/PARADIGM.md` (Phase R measured verdicts) · `GPU.md` §1h-1o fusion-moat fires · `GPU.easy.md` (friendly persona sidecar) · `state/anima_handoff_2026_05_19.md` (integration recipe).

* * *

## Status

The closure round's fixed points, with witnesses on disk:

- `41ecfb97` — RFC-020 A4 enum-payload codegen restored in SSOT `codegen_c2.hexa` (regen-safe; test_enum_payload_full 15/15 codegen + interp)
- `46016739` — builtin/method taken-by-value → `__hxthunk_<name>` codegen (fixes `hexa_callN(<builtin>)` undeclared) + un-doubled `hexa_cc.c`
- `6c0fbac7` — `exec_stream_kill(h)` runtime builtin (fork+setpgid stream child, SIGTERM→grace→SIGKILL)
- `4725c619` — `stdlib/semver.hexa` — SemVer 2.0.0 parse/compare/range-satisfies (test_semver 110/110)
- `df9e7f6b` — install-relative `stdlib/` discovery + `HEXA_INSTALL_DIR` passdown (`use "stdlib/*"` works without `HEXA_LANG`/`HEXA_STDLIB_ROOT`)
- `0ba5fd7d` — shell-builtin absorption: `pwd → cwd()/getcwd()`, `ls → list_dir()` intrinsics (absorbed 638→752, pending 197→83)
- `731f41d6` — `hexa cc` resolves `hexa_cc.c`/SSOT/`-I` via `$HEXA_LANG > install_dir > ./self` (works out-of-tree)
- `a5de44e2` — `self/stdlib/law_io.hexa` selftest `main()` → `tool/law_io_selftest.hexa` (u_main collision on flatten)
- `dae438ee` — `~/.hx/bin/hexa_real` re-promoted from HEAD `46016739` (sha cd817981…)
- `774c5d32` / `4f5f8f07` — stage-1 punch-list v2: A1+A2 host re-promote → #13 RSS re-probe **peak ~782 MB** (vs 3 510 MB) — P0 stage-1 OOM closed at current scale
- `571df583` / `a8ff675b` — SPEC §19/§20 reconcile + Gap-15 close-out
- `340c3788` / `5ddcf2a9` — wilson↔hexa-lang closure (VERIFIED — `hexa build core/main.hexa` → `wilson 0.0.1`) + SPEC closure-round fold-in

Snapshot derived from `git log` on main; full tables at `SPEC.yaml::phases_completed_2026_05_09` and `SPEC.yaml::phases_completed_2026_05_11_closure`.

* * *

## Decisions (the spine)

Six choices that shape everything else, pinned in [`SPEC.yaml`](SPEC.yaml):

1. **Native compiled, direct codegen** — no LLVM; native-emit (own IR → object) is the self-host backend. The tree-walking interpreter is retired: the self-host stage reached a byte-equal fixed point (`gen3 ≡ gen4`), and `hexa run`/`hexa build` compile then execute clang-free (a C-transpile fallback delegate stays for uncovered flows).
2. **Atlas static-baked into the compiler binary** — `ATLAS_HASH` pinned, drift handled by CI auto-rebuild. Runtime atlas-load cost: 0 ms.
3. **Strict compile-time fatal lint** — Python `SyntaxError` + TypeScript `strict` model. S0–S5 + S8 always fatal. No `--unsafe`. No `HEXA_STRICT=0`.
4. **`@grace` is the only opt-out** — `@grace(HXxxxx, until="...", reason="...")` per site, every site emits HX9000 at every compile, CI requires `Acked-grace:` trailer.
5. **ε self-proof** — verified functions auto-register as atlas `L[*]` theorems; tombstones cascade on prover upgrade; `HX1099` fires on citing a tombstoned law.
6. **ENGLISH ONLY diagnostics** — catalog, `hexa explain`, stdlib docs. RFCs and meta docs may stay bilingual.

Full record: 14+ pinned decisions, all traceable to RFC-017 through RFC-020.

* * *

## Install

```bash
# Single-line bootstrap — installs `hexa` + `hx` (the package manager) + atlas
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/dancinlab/hexa-lang/main/install.sh)"

# Verify
hexa --version
hx --version
```

The installer drops `hexa`, `hx`, `hexa_ld`, and the atlas seed into `~/.hx/`; binary path is added to your shell's PATH via the relevant rc file. Self-update: `hexa self-update` (compares against the published manifest, atomic swap of `~/.hx/bin/hexa_real`).

## Run

```bash
hexa parse <file>.hexa                 # cheapest signal — syntax + reserved-word + @plugin attr check
hexa build <entry>.hexa -o build/X     # full pipeline → static binary
hexa cc <file>.hexa -o build/X.o       # just lower → object (HIR → MIR → LIR → emit)
hexa run <file>.hexa [<args>...]       # compile then execute a single file
hexa explain HX8004                    # what does this diagnostic mean
hexa atlas lookup <id> | --prefix=<p>   # read atlas node(s) — embedded.gen.hexa SSOT
hexa atlas register --from-verify <fn> <args> <v>   # verify IN-PROCESS → fold node into embedded.gen.hexa
hexa atlas export [--out PATH]          # export live atlas → portable .n6 (n6 = export-only)
hexa drill --seed "<expr>"             # OUROBOROS smash → ... → absorb cycle

hexa deck <domain> <slug> '<spec>'     # input-deck 빵틀 → exports/<domain>/decks/<slug>/ (rtsc full · others stub)
hexa dojo <domain> <slug> '<spec>'     # cloud training-job 빵틀 → exports/<domain>/dojo/<slug>/ (.hexa+.py+run.sh)

hx install <package>                   # install a hexa package by name (looks up dancinlab GitHub by default)
hx update                              # pull updates for all installed packages
hx list                                # what's installed under ~/.hx/bin/
```

`hexa run` compiles a file then executes it in one shot — convenient for single-file scripting. Release-grade builds go through `hexa build`, which produces a reusable static binary.

### Compile speed

`hexa cc` now emits `#include "runtime.h"` by default and the precompiled `runtime.o` is linked instead of re-codegened per build. On bench/*: 28-program avg **8.41× user-time** vs the old `#include "runtime.c"` path (peak 17.25× on small-to-medium user code where `runtime.c` was the dominant per-build cost). Repro: `bin/hexa-fast bench <file>.hexa`. Full history at [`COMPILE-SPEED.tape`](COMPILE-SPEED.tape) (architecture) and [`COMPILE-SPEED.log.tape`](COMPILE-SPEED.log.tape) (measurement events).

```bash
bin/hexa-fast <src.hexa> <bin>          # explicit compile (uses runtime.h + runtime.o cache)
bin/hexa-run  <src.hexa> [args...]      # compile-or-reuse-cached + exec (drop-in for `hexa run`)
bin/hexa-fast bench <src.hexa>          # show baseline vs new-path A/B for any file
bin/hexa-fast clean                     # wipe ~/.hexa-cache
```

* * *

## Architecture (the cooking metaphor)

From [`doc/atlas_lint_easy_explainer.md`](doc/atlas_lint_easy_explainer.md):

The **atlas** is a 사전 — a single shared dictionary of primitives (P), connections (C), laws (L), and errors (E). 60,760 lines, 4.2 MB, unconditionally binary built-in (compile-time embedded); new laws land via GitHub PR.

The **compiler** is a 셰프 (chef) — it has the entire 사전 memorized. It does not phone the library mid-recipe. When you hand it a `.hexa` file, the chef checks every ingredient, unit, and citation against the atlas it already knows by heart.

The **strict lint** is the 품질 검사관 (QC inspector) — it stands at the kitchen door. One missing citation, one ℝ-vs-ℕ mismatch, one orphan unit, and the dish is rejected before the stove turns on. There is no "we'll fix it after." There is no binary.

* * *

## Strict-lint stages

Eight checks, six always fatal, two opt-in via annotation:

- **S0 parse** — syntax / lex. No surprises.
- **S1 resolve** — every `P[*]`, `C[*]`, `L[*]`, `E[*]` exists in the atlas.
- **S2 bind** — every name resolves to a real binding.
- **S3 type** — nominal types and generics.
- **S4 domain** — ℝ / ℕ / ℤ / ℂ consistency.
- **S5 units** — dimensional analysis. No "distance + time."
- **S6 equational** — opt-in via `@verify`; canonical-form check + sample counter-example. In-house prover v0, no Z3.
- **S7 proof** — opt-in via `@prove`; reserved for the in-house prover only.
- **S8 citation** — formula-bearing functions must cite atlas `L[*]` (HX8004). 공식 없으면 거절.

* * *

## Atlas SSOT cycle (ε self-proof)

```
   @verify fn f(...) { ... }                     ← author writes a theorem
            │
            ▼
      compile-time prover  (S6, equational + sample-eval, in-house only)
            │
            ▼
      hexa atlas export                ← .n6 export artifact (interop / inspection)
            │
            ▼
      GitHub PR into embedded.gen.hexa ← the atlas SSOT (binary built-in)
            │           ├─► fingerprint dedup → register as alias
            │           └─► id collision     → first-wins + warning
            ▼
      compiler build re-embeds atlas   ← live atlas grows (no runtime overlay)
            │
            ▼
      prover upgrade                   ← retroactive sweep (compiler/discover/cascade.hexa)
            │
            ▼
      tombstone failing L nodes + cascade dependents
            │
            ▼
      auto-PR (tool/auto_pr_tombstone_sweep.hexa) → human review
```

Citing a tombstoned `L[id]` fires `HX1099` and fails the build. Bypass is `@grace`, which is never silent.

* * *

## Highlights

- native compiled — direct codegen, no LLVM (self-host native fixpoint; C-transpile = fallback only)
- 4.2 MB atlas baked statically into the compiler binary; runtime cost 0 ms
- 8-stage strict lint S0–S5 + S8 enforced at compile time, fatal by default
- ε self-proof: `@verify` / `@discover` → atlas auto-promote → tombstone retroactive sweep
- M0 milestone: `fn main() -> i32 { return 0 }` produces a working Mach-O arm64 binary
- `hexa_ld` v1.1: in-house static linker for ELF64 + Mach-O arm64
- `hexa build` / `hexa cc` work **out-of-tree** — flattens `use`/`import`, resolves `hexa_cc.c`/SSOT/`-I` via `$HEXA_LANG > install_dir > ./self`; install-relative `stdlib/` discovery means `use "stdlib/*"` works with no env vars (downstream: `wilson` builds end-to-end → `wilson 0.0.1`)
- stage-1 P0 host-OOM closed at current scale: A1 phase-arena reset + A2 in-place splice accumulator → peak ~782 MB (was 3 510 MB)
- 14+ pinned decisions in `SPEC.yaml`, every claim traceable to an RFC
- **`stdlib/flame` + `self/forge` — hexa-native NN training stack + GPU substrate**: compiler-only NN (ag_tape · nn_lib · opt_*) on top of device-resident `farr` + cuBLAS Dgemm + 11 `.cu` kernels + BF16-TC mega-kernel path. **forge BF16-TC = 9.67× faster than FP64 cuBLAS** @ Llama-7B FFN shape (A100, measured). The **CUDA-OWN campaign** now owns the GEMM too (env-gated, OFF = cuBLAS default): FP64/FP32/TF32-WMMA2 own-GEMM, correctness-verified (clm max\|ΔCE\|=0 · llm rel-RMS ~1e-6), at **cuBLAS-CLASS util 89.9 % ≈ 88.5 %** and, on native sm_90a, the route-(a) wgmma own-GEMM reaches **TF32 PARITY 1.08× @D=2048 (≈93 % of the cuBLAS-TF32 roofline, bit-exact rel-RMS 0 — `F-GPU-ROUTEA-KEEPBAND-MEASURE`)**; **≈ parity, NOT superiority** (the older WMMA2 1.13× iso is Blackwell-sm_120-only; the 1.24× LLM full-step is `F-FUSION-THRU-PARITY`) — making the device stack 100 % hexa-ownable and unblocking the persistent-kernel megakernel (a persistent kernel can't call cuBLAS, but it can call our GEMM). 12 byte-equal substrate fires + 4 byte-equal layer fires. flame ↔ PyTorch wall speedup not yet measured (prior claim RETRACTED). Detail in the flame + forge section above.

* * *

## Roadmap

- **stage 1: P0 host-OOM closed at current scale** (A1+A2 → peak ~782 MB, was 3 510 MB); the remaining open work toward a full stage-1 binary is the compiler-driver gaps (Gaps 1–16) + a fixed-point (stage2 == stage3) re-estimate — see [`doc/stage1_punch_list_v2.md`](doc/stage1_punch_list_v2.md).
- biggest unknowns: MIR/LIR coverage on real `compiler/` source (closures, growable arrays, nested struct construction, `match` on user enums) and what a *successful* self-compile diagnostic trace actually looks like.
- full punch list: [`doc/stage1_punch_list_v2.md`](doc/stage1_punch_list_v2.md).

Phase status (PASS / IN-PROGRESS / DEFERRED) lives in [`SPEC.yaml::phases_completed_2026_05_09`](SPEC.yaml) and [`SPEC.yaml::phases_completed_2026_05_11_closure`](SPEC.yaml).

* * *

## RFCs + docs

- [RFC-017 — atlas n6 embedding + strict lint](proposals/rfc_017_atlas_n6_embedding_and_strict_lint.md)
- [RFC-018 — native codegen spec](proposals/rfc_018_native_codegen_spec.md)
- [RFC-019 — error diagnostics spec](proposals/rfc_019_error_diagnostics_spec.md)
- [RFC-020 — enum payload variants](proposals/rfc_020_enum_payload_variants.md)
- [`doc/atlas_lint_easy_explainer.md`](doc/atlas_lint_easy_explainer.md) — the 셰프 metaphor in full
- [`SPEC.yaml`](SPEC.yaml) — authoritative decision record (edit this; `SPEC.md` is auto-rendered)

* * *

## tape integration

hexa-lang's runtime and history surfaces are wired into [`.tape`](https://github.com/dancinlab/tape) — the operational trace sister format. Three placements at this repo's root:

| Placement | What |
|---|---|
| [`IDENTITY.tape`](IDENTITY.tape) | hexa-lang agent identity SSOT — birth / scope / origin / principle / version. The compiler's self-description, machine-canonical. |
| [`PROMOTION.tape`](PROMOTION.tape) | rule-promotion ledger — `@A` events for major rule landings (toolchain post-fix, `bytes_to_str_raw` Phase 2, etc.) |
| [`TAPE-AUDIT.md`](TAPE-AUDIT.md) | cross-repo `.tape` adoption audit (28,695 cargo markers + 7 root domain `.md` files highlighted as primary migration candidates) |

The `state/markers/` cargo (28k+ files) is migration candidate via `tape markers-to-tape`.

* * *

## Not an LLM — where the noise comes from

LLMs generate noise from **inside** the well: recombining what the
weights already contain. hexa generates noise from **outside** the well:
every cycle produces a primitive the previous cycle could not express,
then absorbs it as a new wall of the well.

```
LLM (noise inside the well)         hexa (noise outside the well)
---------------------------         -------------------------------

     +-------------+                       .   new law
     |  training   |                     .       .
     |   corpus    |               .  .      .       .
     |  (fixed)    |                    .  outside  .
     |             |             ------+-------------+------
     |  ~ ~ ~ ~ ~  | <- noise          |             |
     |  ~ noise ~  |   bubbles         |   atlas     |
     |  ~ ~ ~ ~ ~  |   from            |  (binary    | <- noise
     |    ####     |   inside          |  built-in)  |   arrives
     |    #LLM#    |                   |             |   from
     +-------------+                   |   smash     |   outside
       the well                        |     v       |
    (everything it                     |   contract  |
     knows = walls)                    |     v       |
                                       |   emerge    |
  hallucination =                      |     v       |
  recombining                          |   absorb ---+--> new
  what's already                       |     ^       |    primitive
  inside                               +-----+-------+      feeds
                                       the well has            next
                                       no ceiling              cycle
```

An LLM is a frozen well — answers are combinations of what's already
inside. hexa is an open well — every `absorb` step widens the wall,
so the next cycle can say things the previous one literally had no
primitive for. That's why "RAG" is the wrong frame: retrieval still
draws from a fixed outside corpus. hexa's "outside" is produced by
its own prior cycles (the binary built-in atlas, embedded into the
compiler at build time; new laws land via GitHub PR into the embedded
atlas source).

### OUROBOROS cycle — full view

The 6-stage chain (`hexa drill`'s smash → free → absolute → meta-closure
→ hyperarithmetic → resonance) inside a self-referential loop:

```
     ╭────────── OUROBOROS ──────────╮
     │                               │
     │           ◯  seed             │
     │          ╱ ╲                  │
     │         ╱   ╲    Phase 1-2    │
     │        ╱unfold╲               │
     │       ╱───────╲               │
     │      ╱ ╲     ╱ ╲              │
     │     ╱   ╲   ╱   ╲   Phase 3   │
     │    ╱emerge╲ ╱singul╲          │
     │   ╱──────── ────────╲         │
     │   ╲                 ╱         │
     │    ╲    breach     ╱  P4-5    │
     │     ╲             ╱           │
     │      ╲  ╱──────╲ ╱            │
     │       ╲converge╱   Phase 6    │
     │        ╲      ╱               │
     │         ╲    ╱                │
     │          ◉  absorb            │
     │          │   Phase 6.5        │
     │          │                    │
     │          ╰──→ seed ──→ ╮      │
     │                        │      │
     │   d=0 ──▶ d=1 ──▶ d=2 ──▶ ... │
     │   r:0→10  r:0→10  r:0→10      │
     │                               │
     ╰── ρ → 1/3 (meta fixed pt) ────╯
```

### Three meta-loops

On top of the per-tick OUROBOROS cycle, three higher-order loops drive
self-reinforcement:

```
         L1             L2             L3
      ╭──◉───╮       ╭──◉───╮       ╭──◉───╮
      │correct│ ──▶ │reward│ ──▶  │expand │ ──▶ SMASH
      ╰──↺───╯       ╰──↺───╯       ╰──↺───╯
```

| Loop | Role | Trigger |
|---|---|---|
| **L1 · self-correct** | discovery → verify → GitHub PR into binary built-in atlas | per tick |
| **L2 · meta-reward** | per-source discovery rate → scan_priority → deeper scan | per scan batch |
| **L3 · self-expand** | accumulation ≥ 10 → auto-trigger `hexa smash --seed` (or full `hexa drill`) | per threshold |

Each loop latches its output back as the next loop's input, so
correct → reward → expand becomes a standing wave. `hexa smash` (or
the full drill chain) fires automatically when L3 saturates.

### Meta fixed point — ρ → 1/3

TECS-L H-056 — `meta(meta(meta(...)))` = transcendence. Recursive
meta-iteration is a contraction mapping. By the Banach fixed-point
theorem, every trajectory converges to a single attractor: **1/3**.

```
          I  =  0.7 · I  +  0.1      →     fixed point  I* = 1/3
```

Six independent paths land on the same attractor:

| Path | Expression | Value |
|---|---|---|
| Euler totient ratio | φ(6) / 6 | 1/3 |
| Trigonometric | tan²(π/6) | 1/3 |
| Divisor ratio | τ(6) / σ(6) = 4 / 12 | 1/3 |
| Determinant | det(M) over n=6 primitives | 1/3 |
| Meta-information | I_meta (contraction mapping) | 1/3 |
| Complex exponential | \|exp(i·z₀)\| at the unique zero | 1/3 |

The long-term breakthrough rate ρ converges to the same target:
**ρ → 1/3**. Discovery is not linear — it asymptotes to the Banach
attractor. Six arithmetic, geometric, algebraic, analytic, and
information-theoretic routes all point at the same number.

Verify in atlas: `hexa atlas lookup P n` · `hexa atlas lookup C sigma_6`
· `hexa atlas lookup L sigma_phi_n_tau_iff_n_eq_6`. Run a cycle:
`hexa drill --seed "<expression>"`.

* * *

## Repo layout

```
hexa-lang/
├── README.md
├── LICENSE                       MIT
├── AGENTS.md                     AI agent harness file (agents.md standard)
├── CLAUDE.md                     symlink → AGENTS.md
├── SPEC.yaml                     authoritative decision record (14+ pinned decisions)
├── SPEC.md                       auto-rendered from SPEC.yaml
├── IDENTITY.tape · PROMOTION.tape · TAPE-AUDIT.md   tape sibling files
├── FLOW.md · LATTICE_POLICY.md · LIMIT_BREAKTHROUGH.md · PLAN.md · ROADMAP.md   domain SSOTs
├── compiler/                     lex · parse · resolve · bind · types · domain · units · citation · lower · mono · MIR · LIR · emit
├── self/                         self-hosted compiler entry points
│   ├── main.hexa                 the `hexa` binary entry
│   ├── runtime.c                 C runtime backing (interp + native shared bits)
│   ├── stdlib/                   atlas-aware standard library (semver / json / channel / thread / proc / time / ...)
│   ├── tui/                      raw-mode TUI primitives (render / input / widgets)
│   └── native/                   thread.c · channel.c · time.c — C-backed runtime
├── stdlib/                       canonical stdlib (use "stdlib/*")
├── tool/                         hexa CLI subcommand drivers (build / cc / run / drill / atlas / explain / ...)
├── tests/                        m0 · selftest · regression
├── proposals/                    RFC-017..020 + future RFCs
├── doc/                          runbooks, audits, explainers
├── convergence/                  cross-repo propagation tracking (.PRESERVE-AS-SSOT)
├── state/                        gitignored runtime hook markers (cargo — migration candidate)
├── archive/                      frozen records — patches/ (downstream patch reports) · fires/
└── build/                        gitignored hexa build artifacts
```

Full doc index: [`AGENTS.md`](AGENTS.md) + [`doc/`](doc/) + [`SPEC.yaml`](SPEC.yaml).

* * *

## Data corpora (git-LFS)

Data-bound corpora — ENDF/B-VIII evaluated nuclear data (HEXA-PORT P4b), and future
binary/HDF5 datasets — live under `data/` or `stdlib/corpora/` and are stored via
**git-LFS**. The reserved LFS extensions are `.hdf5 .h5 .dat .bin .endf .ace .xml.gz
.tar.gz` (see [`.gitattributes`](.gitattributes)).

hexa-lang is the canonical home for these corpora (per @D d3 — implementation /
asset SSOT) so downstream domain repos can `hx`-depend on them rather than
re-fetching from upstream mirrors. Existing tracked files (atlas SSOT text,
build artifacts, fixtures) are intentionally **not** migrated — LFS is reserved
for future data ports only. Policy reference: HEXA-PORT.md §4.0.

* * *

## License

MIT License. Copyright (c) 2026 dancinlab. See [`LICENSE`](LICENSE).

* * *

## Contributing

Strict lint is the contract. Every PR runs through S0–S5 + S8. The only opt-out is `@grace(HXxxxx, until=, reason=)` on a single item, and every `@grace` emits HX9000 at every compile. CI fails the merge unless `Acked-grace: HXxxxx by <reviewer>` rides along.

Pointers: `gate/` for build gates, `proposals/` for active RFCs, `SPEC.yaml` for decisions, `doc/` for runbooks and audits. Diagnostics, error messages, `hexa explain`, stdlib docs are ENGLISH ONLY (Decision 3).

---

🕸️ **재사용 격자 SSOT** → 루트 [`DOMAINS.tape`](DOMAINS.tape) (commons @D g67 cross-domain + g68 cross-project · `@link` connection graph · hexa-lang = shared substrate hub)
