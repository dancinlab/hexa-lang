# forge — hexa-lang's GPU compute substrate

> **Status: SUBSTRATE-VERIFIED + PARADIGM-ANCHORED + ABI-LANDED
> (2026-05-19 — 일단완성 milestone).** Phase 1 substrate verified
> (RFC 040 cuBLAS Dgemm 4×, RFC 041 11-op kernels). Phase R closed
> (14 fires $2.91 — `PARADIGM.md`). RFC 050 v1 ABI Stage A landed
> (`forge_tier_v1.{h,c}`, smoke 10/10). RFC 060 new-compute-paradigm
> 100% closure measured (mega-kernel FP64 KILL → BF16 substrate
> deferred — `PARADIGM_C_RESEARCH.md`). Remaining = multi-week Stage 2
> GPU campaigns (`PLAN.md` §0.1). `forge` = SSOT 라벨 + paradigm 거점;
> `flame` stdlib 가 model shape / regime 별로 forge tier dispatch.

## Position in the stack

| Layer | What | Lives in | RFC |
|---|---|---|---|
| hexa stdlib (orchestration, compiler-only) | `flame` — Tensor / autograd / nn / optim / train | `stdlib/flame/` | RFC 043 |
| **forge — GPU compute substrate** | **device-farr alloc/copy/free · cuBLAS Dgemm · `.cu` kernels** | **`self/runtime.c` + `self/cuda/`** | **RFC 040 / 041** |
| Core farr primitive (CPU, unified) | farr mmap / matmul / reverse-mode autograd tape | `self/runtime.c` | RFC 025 / 032 / 033 / 034 |

Analogy (PyTorch): **flame:forge :: torch:ATen**. flame writes hexa; forge
writes C / CUDA. flame calls forge through compiled builtin dispatch
(`hexa_farr_matmul_gpu`, `hexa_cuda_*`, …) — never through `hexa_interp`.

## Why a name (and not just "RFC 040/041")

- Vocabulary parity with flame — symmetric SSOT pair (`FLAME.tape` ↔ `FORGE.tape`).
- Honest metaphor: **flame builds on forge** / forge powers flame. Reads in English & Korean cleanly.
- `f1` / `f2` safe — pure thermal lineage, **zero numerology / lattice claim** in the name.
- One label for the GPU layer simplifies cross-repo references (anima `state/` docs, HF model cards, upstream RFCs).

## What forge IS (concretely, today — post-PARADIGM)

### Architectural SSOT (2026-05-17 publish)

- **[`PARADIGM.md`](PARADIGM.md)** — measurement-anchored paradigm SSOT (12 sections, dual-mechanism × regime-tiered thesis). FORGE.tape §X `x_paradigm_ssot` cross-link.
- **[`PARADIGM_RESEARCH.md`](PARADIGM_RESEARCH.md)** — literature snapshot, **CUDA-paradigm only** (한국 alternatives + 글로벌 AOT-NN compilers + arxiv kernel-fusion). 가설 sources, NOT decision sources. §9 scope-note honestly flags that it only delivered half the 2026-05-16 directive.
- **[`PARADIGM_C_RESEARCH.md`](PARADIGM_C_RESEARCH.md)** — genuinely-new compute/execution-model survey (dataflow · CGRA · spatial · polyhedral · verified-scheduling · mega-kernel) — the *other* half of the directive: break past CUDA's kernel-per-op model. Verdict = mega-kernel execution model + verified rewrite-chain codegen. Scaffolds RFC 060.
- **[`FORGE.tape`](FORGE.tape)** — tape v1.2 SSOT (governance + §X cross-link + Log).
- **[`PLAN.md`](PLAN.md)** — staged roadmap (post-Phase R reframe: Phase 2 = 3 sub-tier → Phase 3 DSM → Phase 4 AOT → Phase 5+ multi-GPU).
- **`hexa-lang/inbox/rfc_drafts_2026_05_12/rfc_044_*.md`** — design SSOT (forge regime-tiered substrate, Phase R anchored, 14 falsifier).

### Substrate code (label only, no relocation per g_forge_no_relocation)

- `hexa_cuda_*` runtime functions (device alloc / copy / free / sync) — in `self/runtime.c`
- `hexa_farr_*_gpu` dispatchers — in `self/runtime.c`
- `self/cuda/runtime_cuda.c` — **cuBLAS Dgemm impl** (RFC 040, ✅ verified 4× across 2 H100 + 2 A100, 51.24 TFLOPS FP64 / 76 % H100 peak, max\|Δ\|=4.44e-15 vs CPU)
- `self/cuda/PHASE_D_H100_EVIDENCE.md` — original landing evidence
- **`hexa-lang/inbox/rfc_drafts_2026_05_12/rfc_040_*.md`** — design SSOT (device-farr + cuBLAS)
- **`hexa-lang/inbox/rfc_drafts_2026_05_12/rfc_041_*.md`** — real `.cu` kernel design (Phase 2.B substrate, SMEM-aware 구현으로 진화)

### Phase R fires (2026-05-17, paradigm anchor)

- `state/forge_phaseR_d_2026_05_17/` — D fire (H100 SXM 6 FP64 shape, $0.40). D' = within-run det FREE.
- `state/forge_phaseR_b_2026_05_17/` — B fire (H200 SXM 6 FFN shape, $0.25). B' = shape-tiered fusion.
- `state/forge_phaseR_c_2026_05_17/` — C fire (H100 SXM 5 linear fwd+bwd, $0.30). C' = redundancy 1.500× constant.
- `state/forge_phaseR_a_2026_05_17/` — A fire (H100 SXM 3 MLP, $0.40). A' = **2.24-6.07× PyTorch eager** (dispatch elimination).
- `self/cuda/experiments/{d,b,c,a}_*.{cu,py,sh}` — 9 experiment artifacts.

## What forge is NOT

- ❌ Not a hexa-source stdlib (those go in `stdlib/`; forge **today** is C / CUDA — see "Endgame" below for the hexa-native trajectory)
- ❌ Not a separate repo (toolchain ABI lockstep — `hexa-first` principle; CLAUDE.md "absorbed intrinsic over forking")
- ❌ Not itself a GPU codegen backend (hexa source → PTX is the **sibling** RFC 055 deliverable in `compiler/codegen/`, not in `self/forge/`; forge is the *consumer* of that capability)
- ❌ Not a name for the CPU farr primitive (that's core hexa, RFC 025/032/033/034 — flame uses it directly)

## Endgame — forge becomes hexa-native (RFC 055)

**Today's forge is transitional, not the final form.** The current C/CUDA
substrate exists for one reason: hexa-lang has no GPU codegen target yet, so
C/CUDA is the *only* path that produces GPU kernels. Per `AGENTS.tape` §3 `@D
g5` ("hexa-native-only" — no LLVM, no C-transpile, no third-party codegen),
the long-term destination is **every line of forge in pure hexa**, lowered to
NVPTX through hexa-lang's own codegen pipeline. The closure of `@D g5` for the
GPU lane is the closure of forge.

The named seam is **RFC 055 — hexa-src → NVPTX codegen backend**
(`inbox/rfc_drafts_2026_05_12/rfc_055_hexa_nvptx_codegen_backend.md`, design
draft 2026-05-17). Its honest scope:

| axis | today (C/CUDA forge) | after RFC 055 lands (hexa-native forge) |
|---|---|---|
| substrate language | C + `.cu` (`self/runtime.c`, `self/cuda/runtime_cuda.c`) | `.hexa` source compiled to NVPTX by `compiler/codegen/nvptx_*.hexa` |
| GPU codegen lives in | external `nvcc` + cuBLAS | `compiler/codegen/` — sibling of `arm64_darwin.hexa` / `x86_64_linux.hexa` |
| third-party deps | cuBLAS, cuDNN (NVIDIA closed binaries) | reduced to driver API + (optionally) cuBLAS for raw GEMM only; everything else hexa-native |
| `@D g5` status | partial — CPU lane self-hosted, GPU lane on C/CUDA crutch | total — both lanes hexa-emitted, no C-transpile |
| `flame:forge :: torch:ATen` analogy | applies (forge ≈ ATen) | obsolete (forge is *also* hexa; flame and forge merge into one hexa-native stack with a directory boundary, not a language boundary) |

**Why it's not on a critical chain yet (g3 honest)**: forge's Phase R fires
(`PARADIGM.md` §1) anchor that *a hand-written WMMA kernel is feasible* (C
Stage 2 Phase 3 — 41-43% Tensor Core peak), so the codegen path can emit
*correct* GPU code. It will not *beat cuBLAS on raw GEMM throughput* —
CUTLASS-level tuning is a multi-week effort. RFC 055 is therefore **P2** (not
blocking flame Phase 4-D or any current shipping fire). Sequencing: ship
flame+forge on the C/CUDA substrate; close `@D g5` for the GPU lane when the
RFC 055 backend has enough kernel coverage to substitute without regressing
forge's measured oracles (`g_blue_closed_mandate`).

**What changes inside forge when RFC 055 lands**: `self/cuda/runtime_cuda.c`
kernels get re-derived as `.hexa` files (still under `self/forge/` per
`g_forge_substrate_role` — the *directory* boundary stays, only the *language*
flips). cuBLAS Dgemm stays as a fallback (raw GEMM is a vendor-library win
that hexa-native is not expected to match). The RFC 050 `_v1` ABI is the
stable surface across the transition: flame source compiled against
`forge >= 1.0` does not change when the kernels behind the ABI flip from C/CUDA
to hexa-emitted PTX. Same dispatch, different substrate.

## Verified oracles (forge correctness floor)

### Pre-Phase R (RFC 040 / 041 substrate)

| Oracle | Fact | Source |
|---|---|---|
| cuBLAS ≡ CPU | max\|Δ\|=4.44e-15; reduction-heavy TOL_MATMUL ≈ 2e-9 (RFC 040 fp-non-assoc) | RFC 040 / `self/cuda/PHASE_D_H100_EVIDENCE.md` |
| cuBLAS perf | 51.24 TFLOPS FP64 H100 (76 % peak) · 13,526 GF/s A100 · 4× indep verify | Phase D + A100 retry + runpod 4th verify |
| Phase B2 ops ≡ boxed | `tmp_rfc040_phaseB2_smoke.hexa` 9 / 9 (matmul_t, outer, mul, silu, silu_grad, rmsnorm_bwd, adamw on no-CUDA path) | branch `rfc040-phaseB2-complete` `017b988f` |

### Phase R (2026-05-17 paradigm-anchor)

| Oracle | Fact | Source |
|---|---|---|
| D' within-run det | every FP64 Dgemm shape `default_bit_equal_within=1`, `cross_mode_bit_equal=1` (PEDANTIC ≡ DEFAULT numerically) | `state/forge_phaseR_d_2026_05_17/result.json` 6/6 shape |
| D' PEDANTIC cost | +15-33% wall time vs DEFAULT, no FP64 benefit (opt-in only) | 同 above |
| B FFN BW util | small shape 14-22%, medium 25-32%, **large (Llama-7B scale) 35.4%** (H200 4.8 TB/s peak) | `state/forge_phaseR_b_2026_05_17/result.json` |
| C linear fwd+bwd redundancy | bytes_redundancy_ratio = **1.500× CONSTANT** every shape → fused ceiling ≤ 0.667× separate (33% reduction theoretical max) | `state/forge_phaseR_c_2026_05_17/result.json` |
| **A AOT speedup** | small MLP **6.06× PyTorch eager**, medium **2.24×** (FP64, AdamW, 100 step median) | `state/forge_phaseR_a_2026_05_17/result.json` |
| A dispatch overhead | ~600 μs/step fixed (B 무관, Python+ATen+launch) — train_step ~85% on small MLP | 同 above |

모든 oracle = **g_blue_closed_mandate** + **g_forge_verify_oracle** anchor.
신규 forge kernel/AOT codegen 은 land 전 위 oracle reproduce 의무.

## Performance thesis (measurement-anchored, g1/g3/g4/f1/f2)

**Honest dual-mechanism × regime-tiered thesis** (Phase R 4 fire 위에서 anchor):

| Regime | Compute | Dispatch overhead | A win (dispatch elim) | B/C win (memory fusion) | Combined |
|---|---|---|---|---|---|
| Small (MNIST, online-RL) | < 100 μs | ~600 μs | **6×** | ~1.0× | **~6×** |
| Medium (4K wide) | ~1 ms | ~1.5 ms | **2.24×** | ~1.3× expected | **~2.9× expected** |
| Large (Llama-7B+) | ~10 ms | ~5 ms | ~1.1× expected | **1.5-2× expected** (B Stage 2) | **~2.2× expected** |

**Floor** (measured anchor):
- Raw dense GEMM = cuBLAS / NVIDIA roofline (51.24 TFLOPS FP64 H100 76% peak). forge matches.
- Within-run determinism FREE (FP64 single-process bit-equal anchored, 6/6 shape D fire).

**Forge wins** (measured anchor):
- **Mechanism 1 — Dispatch elimination (Paradigm A)**: AOT single-binary 가 Python+ATen+launch overhead 제거. 실측 small MLP 6.06× PyTorch eager (사전등록 1.2× 의 5.05× 초과).
- **Mechanism 2 — Memory fusion (Paradigm B/C)**: DSM-cluster + autograd co-emission. C redundancy 1.5× → fused ≤ 0.667× ceiling. B Llama-7B BW util 35% → 70% potential. Stage 2 fires 가 검증.

**Forbidden**:
- ❌ NO n=6 lattice numerology in perf assertion (`f1` / `f2` hard fail).
- ❌ NO universal speedup 약속 — 모든 win 은 regime-dependent.
- ❌ NO 가짜 배수 (`g3`) — anchor = Phase R 측정 only, literature 는 가설 source 만.
- Anchors = HBM bandwidth (H100 3.35 TB/s · H200 4.8 TB/s) + cuBLAS roofline + Python dispatch overhead — 모두 measured.

## Cross-references (SSOT)

### forge SSOTs (자체)

- **Paradigm decision**: [`PARADIGM.md`](PARADIGM.md) (measurement-anchored, 12 sections)
- **Literature snapshot**: [`PARADIGM_RESEARCH.md`](PARADIGM_RESEARCH.md) (가설 sources)
- **Tape SSOT**: [`FORGE.tape`](FORGE.tape) (v1.2 governance + §X + Log)
- **Roadmap**: [`PLAN.md`](PLAN.md) (post-Phase R reframe — Phase 2 sub-tier · Phase 3 DSM · Phase 4 AOT · Phase 5+ multi-GPU)

### Design RFCs

- **RFC 040** (`inbox/.../rfc_040_*.md`) — device-farr + cuBLAS Dgemm base substrate
- **RFC 041** (`inbox/.../rfc_041_*.md`) — real `.cu` kernel design (Phase 2.B substrate 흡수)
- **RFC 044** (`inbox/.../rfc_044_*.md`) — **dual-mechanism × regime-tiered substrate** (Phase R anchored, 14 falsifier)
- RFC 042 = SUBSUMED by RFC 043 (number reserved, do not reuse)
- RFC 043 = flame stdlib (consumer of forge)

### Companion / cross-repo

- Companion stdlib: `stdlib/flame/README.md` · `stdlib/flame/FLAME.tape` §X (campaign artifacts from stdlib angle)
- Cross-repo evidence: `dancinlab/anima` `state/hexad_gpu_fire_*` + `docs/anima_rfc040_phase_*` (참조만, 복제 X — g3 drift-avoidance)
- Phase R artifacts: `state/forge_phaseR_{d,b,c,a}_2026_05_17/{result.json, *_ANALYSIS.md}` + `self/cuda/experiments/`
