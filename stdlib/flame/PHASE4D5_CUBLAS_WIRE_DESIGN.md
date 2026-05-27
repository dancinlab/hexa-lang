# Phase 4-D-5 cuBLAS wire-up design (2026-05-17)

> Honest follow-up to Phase 4-D-4 GPU fire FAIL (commit `48d35e72`):
> training binary is the bottleneck — A2 primitive emits naive
> single-threaded C matmul, A100 GPU box doesn't help. Next progression
> = wire RFC 040 cuBLAS Dgemm substrate into flame's matmul calls.
>
> Design only — no implementation, no cost. Prep doc for next
> user-directed Phase 4-D-5 cycle.

## Phase 4-D-4 fire RCA recap

Per `state/flame_phase4d_20260517_102511/RESULTS.md`:
- F-RFC046-EAGER-PYTORCH-MATCH FAIL (wall ≤437.9s NOT REACHED)
- 358+ s CPU on A100 SXM 80GB pod, ZERO step output
- Root cause: A2 primitive 의 matmul = **3-nested-loop naive C**, no
  SIMD/BLAS/OMP. d=768·12L (~10¹¹ flops/step) needs GPU acceleration
  OR multithreaded BLAS to fit gate.
- Cost: $0.40 / $20 cap = 2% used (well-managed)

## RFC 040 substrate audit (runtime.c, 2026-05-17)

Existing infrastructure:
- `FarrLoc` enum: `FARR_HOST | FARR_DEVICE | FARR_MIRRORED` (line 8190)
- `HexaFarrEntry.d_buf` CUDA device pointer slot (line 8186 comment)
- `hexa_cuda_available()` + `hexa_cuda_device_count()` (line 10750-10761)
- `hexa_farr_matmul` HOST-only Dgemm impl (line 9849)
- TODO[cuda] markers for GPU path:
  - Line 8186: "cuBLAS Dgemm + cudaMalloc are TODO[cuda] stubs"
  - Line 8309: "TODO[cuda] Phase A impl: cudaFree(e->d_buf)"
  - Line 10717-10718: GPU branches return -1 (honest no-fake-PASS)
  - Line 11446: "TODO[cuda] Phase B2: rank-1 update (cublasDger)"

**Current state**: RFC 040 substrate **scaffolded but not impl**.
Host path complete + device-pointer schema ready; GPU bodies are
explicit `return -1` stubs (honest no-fake-PASS pattern).

## Phase 4-D-5 scope: wire cuBLAS Dgemm into A2 matmul primitives

Three integration layers:

### Layer 1 — implement RFC 040 GPU substrate bodies (runtime.c)
- `cudaMalloc` / `cudaFree` / `cudaMemcpy` (Phase A)
- `cublasCreate` / `cublasDestroy` handles
- `cublasDgemm` wrapper matching `hexa_farr_matmul` ABI
- `hexa_farr_to_device` / `hexa_farr_from_device` (H2D/D2H)
- Auto-residence transition (FARR_HOST → FARR_MIRRORED → FARR_DEVICE)

### Layer 2 — flame A2 primitives use cuBLAS-routed matmul  ✅ LANDED (2026-05-17)
- Modified `tool/flame_phase4b3_matmul_primitives.c` — all 8 primitives
  (4 fwd `proj_batch` + 4 bwd `grad_accum`) now call a shared
  `flame_proj_matmul_dispatch()` instead of the bare inline loop.
- GPU path `flame_proj_gpu_matmul()` (under `#ifdef HEXA_CUDA`) bridges the
  stack-buffer primitive ABI to the HexaVal farr API:
  - allocates host farrs for A, B (`hexa_farr_zeros`), re-fetches `.buf`
    after each alloc (use-after-realloc hazard — same as runtime.c
    `hexa_farr_matmul`), uploads, calls `hexa_farr_matmul_gpu`, copies C
    back, frees the temporaries.
  - on any alloc/dispatch error → falls back to the CPU inline loop
    (no fake PASS).
- On the no-CUDA Mac build the GPU branch is `#ifdef`-compiled out — small
  shapes are the only path, so byte-eq is preserved by construction.
- Trade-off note (unchanged): per-matmul cuBLAS overhead vs naive-loop.
  At d=768·12L scale cuBLAS Dgemm wins; at d=32·3L scale naive wins —
  hence Layer 3 threshold below.

### Layer 3 — dim-aware dispatch (small d uses naive, large d uses cuBLAS)  ✅ LANDED (2026-05-17)
- `flame_proj_matmul_dispatch()` checks `M·K > FLAME_MATMUL_GPU_THRESHOLD`
  (default 8192). Above → `flame_proj_gpu_matmul` (cuBLAS); at/below →
  `flame_proj_inline_matmul` (CPU).
- Threshold = **8192**, chosen by config separation (not benchmark — no
  fire budget this cycle):
  - d=32·3L config — largest A2 shape M·K = 2048 (d_out=64·d_in=32 fwd,
    d_out=32·d_in=64 fwd). 8192 clears it by 4× → all 8 shapes stay CPU.
  - d=768·12L config — M·K = 768·768 = 589824, ~72× above the threshold
    → routes to cuBLAS Dgemm.
  - The two configs are separated by ~288×, so the threshold choice is
    unambiguous; a benchmark-tuned value is only meaningful for an
    intermediate config (none in scope).
- Verification (Mac, $0):
  - F-RFC040-MAC-BUILD-PRESERVED — `clang -O2` no-CUDA + `clang -O2
    -DHEXA_CUDA` both compile clean (object code; `_hx_cuda_farr_matmul_gpu`
    is the only unresolved extern, satisfied by runtime_cuda.c on a CUDA host).
  - F-RFC047-A2-PATHB-FULL-BYTE-EQ — numeric unit test: all 8 d=32·3L
    shapes byte-identical between `flame_proj_matmul_dispatch` and the
    original `flame_proj_inline_matmul` (M·K ∈ {256…2048}, all CPU).
  - F-RFC040-CUBLAS-BYTE-EQ — deferred to the d=768·12L re-fire
    (GPU path only activates at large dim; not measurable on no-CUDA Mac).

## Sub-phase breakdown (5-7 cycles autonomous + 1-2 cycles cost-bearing)

| sub-phase | what | effort | cost | falsifier |
|---|---|---|---|---|
| 4-D-5-1 | Layer 1 RFC 040 GPU body impl (runtime.c) | 2-3 cycles | $0 (local) | builds with -DHEXA_CUDA on CUDA host (remote build) |
| 4-D-5-2 | Layer 2 A2 primitives cuBLAS-route + Layer 3 dim-aware dispatch ✅ LANDED 2026-05-17 (threshold=8192 by config-separation, not benchmark) | 1-2 cycles | $0 (local d=32 falsifier preserved) | F-RFC047-A2-PATHB-FULL-BYTE-EQ unchanged at small scale (8/8 byte-id PASS); new F-RFC040-CUBLAS-BYTE-EQ deferred to d=768 re-fire |
| 4-D-5-3 | flame_d768_12L_corpus_test rebuild + smoke (HEXA_CUDA build path) | 1 cycle | $0 (build verify only, run skipped on M-Mac) | compile + link PASS with -DHEXA_CUDA on remote |
| 4-D-5-4 | **Phase 4-D-4-second fire** — CUDA-enabled binary on A100 | 1 cycle | **$5-20** | F-RFC046-EAGER-PYTORCH-MATCH wall ≤437.9s |
| 4-D-5-5 | RFC 046 ship (results + RFC update) | 1 cycle | $0 | docs only |
| **total** | — | **5-7 cycles** | **$5-20** | — |

## Verification anchors

**F-RFC040-CUBLAS-BYTE-EQ** (NEW, Phase 4-D-5-2):
- cuBLAS Dgemm output vs naive matmul on identical input
- Tolerance: RFC 040 §2.2 TOL_MATMUL class (last-ulp drift expected
  due to different reduction order between cuBLAS Tensor Cores and
  naive ijk loop). NOT max|Δ|=0.0 strict — fp-tol acceptance.

**F-RFC047-A2-PATHB-FULL-BYTE-EQ** (regression gate):
- d=32·3L path unchanged (naive matmul kept below threshold)
- A2 fwd+bwd byte-id with baseline preserved
- Currently 24/24 PASS — Layer 3 threshold dispatch must preserve

**F-RFC046-EAGER-PYTORCH-MATCH** (final gate, Phase 4-D-5-4):
- flame d=768·12L A100 wall ≤ 437.9s
- cuBLAS Dgemm-routed matmul + Phase 4-B A2 inline scalar ops
- Expected: per-step ~1-3s × 20 steps ≈ 20-60s wall (~10× under gate)

## Risks

1. **cuBLAS reduction-order drift**: Tensor Core fp64 Dgemm uses
   different reduction grid than naive ijk loop. d=32·3L byte-id may
   break if threshold dispatch fails. Mitigation: explicit threshold
   check + naive path preservation.

2. **HEXA_CUDA build complexity**: runtime.c with -DHEXA_CUDA pulls
   in CUDA toolkit + cublas dynamic libs. Build path divergence from
   default needs careful CMake / Makefile handling.

3. **Cost overrun on retry fires**: Phase 4-D-5-4 fire may need 2-3
   attempts if CUDA build issues surface on remote. Budget allocation:
   $20 cap × 3 retries = $60 max. Or tighter retry policy.

4. **Phase 4-B SHIPPED regression**: Layer 3 dispatch change to A2
   primitives must preserve d=32·3L 3.23× wall. Re-run verify_all
   24/24 PASS gate after each change.

## What this does NOT do

- Does NOT modify A2 primitive scalar code (rmsnorm/swiglu/rope/attn loops)
- Does NOT change Phase 4-B-2 IPCP path
- Does NOT touch nn_lib.hexa, decoder_lib.hexa, decoder_block_lib.hexa
- Does NOT replace farr_matmul HexaVal API surface
- Does NOT push for Phase 5 "exceed eager-PyTorch" (still Phase 4 territory)

## Cross-link

- Phase 4-D-4 fire FAIL state: `state/flame_phase4d_20260517_102511/RESULTS.md`
- Phase 4-D-4 commit: `48d35e72` (subagent ad095c52 result)
- RFC 040 device-farr + cuBLAS substrate (LANDED, scaffolded)
- RFC 041 real CUDA kernels (related)
- runtime.c lines 8186-8309 (FarrLoc schema), 9849 (host Dgemm), 10717-10761 (cuda_available)
- self/forge/ — GPU compute substrate (project CLAUDE.md §0 nn_stack)
- PHASE4D_GPU_DISPATCH_DESIGN.md (commit c5d49425) — Phase 4-D scope
- PHASE4D_DISPATCH_CLI_GUIDE.md (commit 8b93b9bd) — runpod ready

## Next user-gate

Phase 4-D-5 fire requires:
1. Explicit go for 5-7 cycle RFC 040 wire work (autonomous-able)
2. $5-20 explicit budget approval for Phase 4-D-5-4 cost-bearing fire
3. Remote CUDA build environment (runpod pod with CUDA toolkit installed)

If approved → 5-7 cycle progression → F-RFC046-EAGER-PYTORCH-MATCH gate.
If deferred → Phase 4-B SHIPPED (3.23× CPU) + Phase 4-D-4 FAIL RCA stand
as Phase 4 closure milestones (substantial delivery; GPU acceleration
queued for future cycle).
