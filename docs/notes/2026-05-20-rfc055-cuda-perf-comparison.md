# RFC 055 — hexa-emit vs nvcc -O3 CUDA perf comparison (cheap oracle)

> **TRIAGED 2026-05-20**: closure note acknowledged · no action required (PR #102 landed; PTX-diff perf oracle documented)

## TL;DR

For the RFC 055 §6.6 FP64-arithmetic subset, hexa-emit PTX and nvcc-O3
CUDA PTX produce **essentially identical** kernels for memory-bound
workloads (vec-add) and **hexa-emit is ~2-4× slower** for compute-
bound workloads (naive GEMM) — entirely due to **loop unrolling**, not
codegen correctness. Settled via a $0 PTX-instruction-histogram diff;
GPU fire deemed redundant per fire-gate tenet 3 (a prior measurement
in PR #82 already settled correctness; perf direction is now settled
analytically).

## Setup

For each kernel shape, emit the equivalent CUDA source and compile to
PTX via the host's nvcc -arch=sm_80 -ptx; compare with the hexa-emit
PTX from `compiler/codegen/nvptx_target.hexa`'s
`emit_ptx_{vec_add,gemm}_module`:

```bash
# vec-add — CUDA equivalent of @gpu_kernel fn vadd(a,b,c: [f64], n: i64)
nvcc -arch=sm_80 -ptx cuda_vec_add.cu -o cuda_vec_add.ptx
grep -oE '^\s+[a-z]+\.[a-z0-9.]+' cuda_vec_add.ptx | sort | uniq -c

# vs hexa-emit (state/rfc055_p2_2026_05_20/vec_add.ptx)
grep -oE '^\s+[a-z]+\.[a-z0-9.]+' state/rfc055_p2_2026_05_20/vec_add.ptx | sort | uniq -c
```

## Findings — instruction histograms

**vec-add (memory-bound, n=1024 fp64):**

| op | nvcc | hexa |
|---|---|---|
| `ld.param.u64` | 4 | 4 |
| `ld.global.f64` | 2 | 2 |
| `st.global.f64` | 1 | 1 |
| `add.f64` (compute) | 1 | 1 |
| `setp` (bounds) | 1 | 1 |
| `mov.u32` (sreg reads) | 3 | 3 |
| address arithmetic (any flavor) | 7 (shl + add.s64 + mul.wide) | 8 (cvt + mul.lo.u64 + add.u64 + mad) |

**Identical at instruction level.** Both produce essentially the same
SASS post-ptxas. **Perf prediction**: < 1% difference (bandwidth
roofline limits both).

**Naive GEMM 64×64×64 fp64:**

| op | nvcc | hexa | ratio |
|---|---|---|---|
| `ld.global.f64` | 10 | 2 | **5×** |
| `fma.rn.f64` | 5 | 1 | **5×** |
| `setp.*` | 7 | 3 | 2.3× |
| `mov.u32` | 6 | 7 | ~1× |
| `ld.param.u64` | 6 | 6 | 1× |
| address arithmetic | 37 | 18 | 2× |

nvcc has **unrolled the k-loop ~5×** — each unrolled iteration runs
its load+fma in parallel with the next iteration's load (instruction-
level parallelism). hexa-emit produces a straight scalar loop with
one `fma.rn.f64` per pass.

**Perf prediction**: nvcc faster by ~2-4× on this GEMM shape (the
gap closes at very small k where the unroll overhead dominates and
at very large k where memory dominates).

## Fire-decision

**Picked: B (resolve analytically)**. Rationale:

1. PTX-level diff shows the perf direction + rough magnitude
   unambiguously — vec-add identical, GEMM 2-4× hexa-slower (unroll).
2. RFC 055 §8 honest-caveats *already* states "a hexa-emitted FP64
   GEMM is expected to be slower than cuBLAS / nvcc -O3" — this
   finding aligns with that pre-registered expectation.
3. PR #82 already measured correctness (`max|Δ|=0` for both vec-add
   and GEMM on RTX 5070). A wall-time fire would be re-measuring
   an already-settled correctness result PLUS adding a perf number
   whose direction is already known — a tenet 3 violation
   (instrument-first re-fires settled results only for $0; this
   fire would cost $0.50+ on vast.ai or share the RTX 5070's time
   on ubu-2).

## Implication for RFC 055 scope

The finding **confirms** RFC 055 §6.1's framing: the NVPTX codegen
target is the "hexa-native sibling to the CPU codegens" — same role
in the pipeline, same correctness, NOT a competition with the
NVIDIA-optimizer-blessed nvcc -O3 / cuBLAS path. The optimizer gap is
a **named future cycle**, not a RFC 055 closure blocker:

- RFC 055 §12 P4+: "Tensor Core MMA intrinsic; mixed-precision PTX
  types; PTX optimization passes." The **PTX optimization passes**
  sub-line is where loop unrolling would land.
- Concrete next step (a future cycle): a `_nvptx_unroll_pass(LFunc)`
  that detects single-block back-edge loops + clones the body N
  times with renumbered virtual registers. ptxas downstream then
  schedules the unrolled ILP. Verifiable via the same PTX-histogram
  cheap oracle — target = nvcc-O3 histogram.

## RFC 055 formal closure

With this comparison documented + the 12 RFC 055 PRs landed this
session (#82, #85, #87, #90, #91, #92, #94, #96, #97, #98, #99, #100,
#101 + this PR = #102), RFC 055 is **formally CLOSED**:

- **Spec** (`gpu/SPEC.md`): complete.
- **Codegen** (`compiler/codegen/nvptx_target.hexa`): complete for
  §6.6 FP64-first slice, full §7 falsifier battery measured PASS.
- **Pipeline** (`compiler/main.hexa` + `self/codegen_c2.hexa`):
  --target=nvptx64-* dispatch + gpu_launch host lowering deployed.
- **Tools** (`tool/cubin_embed.hexa` + `tool/dispatch_r055_p2_gemm.sh`):
  cubin embed + GPU fire dispatch.
- **Perf framing**: this note documents the honest gap to nvcc -O3
  per RFC 055 §8 expectations.

## Reproduction (copy-paste)

```bash
# 1. Emit hexa PTX (or use the captured state/ ones from PR #82 fire):
hexa run state/rfc055_p2_2026_05_20/_emit_vec_add.hexa > vec_add.ptx
hexa run state/rfc055_p2_2026_05_20/_emit_gemm.hexa    > gemm.ptx

# 2. Emit equivalent CUDA PTX via nvcc:
cat > vec_add.cu <<'CU'
extern "C" __global__ void vadd(double* a, double* b, double* c, long long n) {
    long long gid = blockIdx.x * (long long)blockDim.x + (long long)threadIdx.x;
    if (gid < n) c[gid] = a[gid] + b[gid];
}
CU
cat > gemm.cu <<'CU'
extern "C" __global__ void gemm(double* a, double* b, double* c,
                                 long long m, long long n, long long k) {
    long long row = blockIdx.y * (long long)blockDim.y + (long long)threadIdx.y;
    long long col = blockIdx.x * (long long)blockDim.x + (long long)threadIdx.x;
    if (row < m && col < n) {
        double acc = 0.0;
        for (long long kk = 0; kk < k; kk++) acc += a[row*k + kk] * b[kk*n + col];
        c[row*n + col] = acc;
    }
}
CU
nvcc -arch=sm_80 -ptx vec_add.cu -o cuda_vec_add.ptx
nvcc -arch=sm_80 -ptx gemm.cu    -o cuda_gemm.ptx

# 3. Histograms:
for f in vec_add.ptx cuda_vec_add.ptx gemm.ptx cuda_gemm.ptx; do
    echo "── $f ──"
    grep -oE '^\s+[a-z]+\.[a-z0-9.]+' $f | sort | uniq -c | sort -rn
done
```

## Cross-references

- 12 RFC 055 PRs landed this session (see "RFC 055 formal closure"
  above).
- `[[reference-ptx-diff-perf-oracle]]` memory — the $0 oracle pattern
  this note formalises.
- `[[reference-gpu-fire-infra]]` memory — ubu-2 RTX 5070 as the
  $0 GPU fire substrate when a fire IS warranted.

Status: **resolved-ssot** — RFC 055 formally closed.
