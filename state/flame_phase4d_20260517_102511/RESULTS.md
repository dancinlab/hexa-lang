# Phase 4-D-4 GPU Dispatch — RESULTS

**Date**: 2026-05-17
**Branch**: rfc043-hexa-torch
**Pod**: uwnkt6g0605hon (A100 SXM 80GB, runpod community cloud)
**Cost incurred**: $0.40 USD (well under $20 hard cap)
**Pod runtime**: 1049 s (17.5 min wall, lifecycle: 01:40:53Z → 01:58:22Z UTC)
**Process runtime at kill**: 5 min 58 s CPU / 99.8% util / RSS 3.71 GB

---

## Falsifier Gate

**F-RFC046-EAGER-PYTORCH-MATCH** (wall ≤ 437.9s = 1.3 × 336.85s eager-PyTorch baseline)

**Result: FAIL**

At kill (10+ min wall elapsed since training launch), the training process had
**not produced a single measurable output line** beyond the initial config
banner. Expected first output marker (`init epoch gn2:`) never appeared in
~358 s of actual binary execution time. F-RFC046 gate window (≤437.9s) is
exceeded with **zero training step observed**.

**F-RFC046-LOSS-CONVERGENCE**: NOT MEASURABLE (no loss values produced).

**F-RFC046-GPU-SANITY**: N/A (binary is pure-C CPU code; no CUDA in this build).

---

## Final Loss

NOT MEASURED (training was killed before step 1 completed).

---

## What Actually Happened

### Dispatch flow (executed cleanly)

1. Pre-flight `tool/flame_phase4b3_verify_all.sh` → 23/23 PASS ✅
2. runpod auth/inventory check → A100 SXM 80GB available (stock Low) ✅
3. Local M-Mac build of `flame_d768_12L_corpus_test.hexa` → 163 KB C file + 591 KB binary ✅
4. Pod created: `uwnkt6g0605hon` (A100 SXM 80GB, community cloud, $1.39/hr) ✅
5. SSH ready after ~30 s (`root@216.249.100.66 -p 20162`) ✅
6. `apt install clang` (clang 18.1.3) ✅
7. SCP runtime sources + flame .c + corpus (~230 KB tarball) ✅
8. Remote build: `clang -O2 -D_GNU_SOURCE -D_XOPEN_SOURCE=600 -I self -lm -lpthread` →
   493 KB ELF x86_64 binary ✅
9. Smoke test (`timeout 10`) → corpus path symlinked, banner output OK ✅
10. Launched timed run (`nohup` + supervisor capturing wall) ✅
11. **Training did not produce step output within ~6 min CPU time** ❌
12. Killed process, captured state, deleted pod ✅
13. Total cost: $0.40 (balance $304.19 → $303.78)

### Root-cause for FAIL

The d=768·12L configuration is **~30 000× more compute-dense per AdamW step**
than the d=32·3L baseline (per `flame_d768_12L_corpus_test.hexa` header). The
generated binary is **single-threaded pure-C** (no CUDA, no OpenMP, no SIMD
intrinsics beyond what clang auto-vectorizes). A single A100 SXM box's 32-vCPU
parallelism does not help a single-threaded binary.

Per-step compute estimate from first principles:
- Per-layer fwd: ~7 matmuls + softmax @ T=1024, d=768
- Naive C matmul (3-nested loop, no blocking): ~1–2 GFLOPS on x86_64 with `-O2`
- 12 layers × fwd+bwd ≈ 10¹¹ flops per training step
- Single-threaded wall per step: ~100–300 s
- 20 steps: ~30 min to 1.5 hr (best case)

Observed: 6 min CPU with `init epoch gn2` not yet emitted suggests the
init+epoch-fwd phase alone exceeds the 437.9s gate window.

### What this measures

The dispatch **mechanism** worked end-to-end (auth, provisioning, SCP,
remote build, supervised launch, teardown). The **fire** confirmed the
prediction implicit in the source comment: single-threaded CPU code at
d=768·12L scale cannot meet a 437.9 s wall budget. To meet the gate, the
binary needs one of:

- Actual GPU dispatch (cuBLAS Dgemm or `.cu` kernels per RFC 040/041 forge)
- OpenMP/threading on the 32 vCPUs (~10–30× speedup if matmul-bound)
- AVX-512 SIMD primitives (~2–4× on Skylake-AVX512 CPUs)
- BLAS link (libopenblas/MKL for matmul) — likely 100× over naive

None of these are present in the current `flame_phase4b3_a2_build.sh` build
chain. The Phase 4-B-3-2-third A2 primitive uses an inline naive matmul:

```c
static inline void flame_proj_inline_matmul(...) {
    for (int i = 0; i < M; i++) for (int j = 0; j < N; j++) C[i*N+j] = 0.0;
    for (int i = 0; i < M; i++) for (int k = 0; k < K; k++) {
        double aik = A[i*K+k];
        for (int j = 0; j < N; j++) C[i*N+j] += aik * B[k*N+j];
    }
}
```

This is fine for d=32 (T=16, ~16K flops per matmul) but for d=768 (T=1024,
~600M flops per matmul × 7 per layer × 12 layers = 50G flops per fwd pass)
the wall gates aren't reachable single-threaded.

---

## Artifacts in this state dir

- `DISPATCH.md` — initial dispatch metadata
- `RESULTS.md` — this file
- `flame_d768_12L_corpus_test_a2.c` — built C source (163 KB, identical bytes
  to what shipped to pod)
- `pod.env` — pod ID, IP, port, cost, timing
- `remote_run.log` — captured training stdout from pod (banner only)
- `remote_final_state.txt` — ps snapshot at kill (etime, cputime, %CPU, RSS, VSZ)
- `remote_supervisor.log` — supervisor wrapper output (empty — process killed
  before bash supervisor `T1` line printed)

---

## Follow-up (out of scope for this fire)

1. **Forge integration**: Wire `hexa_farr_*_gpu` (cuBLAS Dgemm) into the Phase
   4-B-3-2 primitive emit path. Per RFC 040/041, this is the substrate for
   F-RFC046 gate viability.
2. **OpenMP smoke**: Add `#pragma omp parallel for` to the inline matmul as a
   cheap pre-forge measurement; expect 10–30× on 32 vCPU box (~$0.50 fire).
3. **F-RFC046 gate recalibration**: 437.9s targets eager-PyTorch (CUDA tensor
   kernels). A CPU-only flame build can never meet this gate — the falsifier
   needs a CUDA-class substrate or the gate needs an explicit CPU/GPU split.
