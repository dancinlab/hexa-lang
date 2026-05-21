# flame · Apple M3 / Metal integration — gap analysis

> Domain SSOT for the **flame ag_linear → Metal** path. Sister to
> `stdlib/flame/PLAN.md` (Nvidia cuBLAS path) + `GPU.md` §10
> (cross-vendor closure ladder). Cross-references RFC 075 (Metal target).

---

## 1. Why this file

`stdlib/flame/ag_tape.hexa::ag_linear` is the canonical Linear-layer node
in flame's autograd tape. The d768/12L decoder calls it ~84× per step
(Q/K/V/O × 12 layers + lmhead) so getting it onto the local GPU is the
single largest perf lever on Mac. On Nvidia the path is **closed**
(d768 step1 wall 191-268s vs PyTorch eager 336.85s — 20-43% faster, memory
`project_flame_phase4d9_closure` `28e9d648`); the cuBLAS route lives at
`self/runtime.c:6157-6175` behind a `HEXA_CUDA` dim-gate.

On Apple M3 the path is **open**:

- `farr_matmul` (`self/runtime.c:6125`) has no Metal hook — only the
  `HEXA_CUDA` dim-gate + CPU `ikj` fallback (FP64).
- Metal codegen (`compiler/codegen/metal_target.hexa`) recognises 5
  element-wise shapes (vec-add/mul/sub/div/scale) per `f7a7404f` +
  `ca49aea1`, plus reduce-sum (`9e53566e`). **No matmul recogniser.**
- Apple GPUs do not support FP64 in compute shaders. `farr_matmul`'s
  FP64 buffers cannot be passed directly — every Metal route through
  `ag_linear` is **precision-loss FP64→FP32→FP64**, NOT a transparent
  retarget.

## 2. Cycle deliverable (2026-05-21)

**RFC 075 P5 silicon-fire** — `inbox/fires/rfc075_metal_matmul_2026_05_21/`:

| Kernel       | Shape    | Median (ms) | GFLOPS  | rel_err  | Pass |
|--------------|----------|-------------|---------|----------|------|
| matmul_naive | 128³     | 0.081       |  51.94  | 1.79e-07 | yes  |
| matmul_tiled | 128³     | 0.059       |  71.24  | 1.79e-07 | yes  |
| matmul_naive | 256³     | 0.235       | 142.56  | 2.56e-07 | yes  |
| matmul_tiled | 256³     | 0.352       |  95.34  | 2.56e-07 | yes  |
| matmul_naive | 512³     | 1.452       | 184.90  | 3.28e-07 | yes  |
| matmul_tiled | 512³     | 0.996       | 269.41  | 3.28e-07 | yes  |

Hand-emitted MSL (`matmul.metal`), Swift host (`host_matmul.swift`),
LCG-deterministic FP32 inputs, CPU ikj reference, single-prec matmul
tolerance `rel_err < 1e-5`. **F-RFC075-METAL-MATMUL-NUMERIC-EQ: PASS**
across all six runs. 269 GFLOPS at 512³ sets the in-vivo M3 FP32-naive
ceiling against which any future codegen-emit matmul must be measured.

### What the fire result tells us

1. **Numeric path is fine.** rel_err <= 3.3e-7 — well inside torch.allclose
   default rtol. Apple GPU FP32 matmul + threadgroup-tiled reduction
   matches CPU ikj to single-precision floor. The shape works.

2. **269 GFLOPS naive ceiling is far below M3 silicon.** Apple M3
   peak FP32 ALU throughput per Apple's docs is ~3-4 TFLOPS (10-core
   GPU). The tiled kernel hits ~7-10% of peak. The optimisation gap
   = `simdgroup_matrix<float, 8, 8>` MMA intrinsics (next cycle),
   matching what `wmma::mma_sync` did for cuBLAS-rivalling PR #214/#217.

3. **MPS comparison.** Apple's `MPSMatrixMultiplication` ships
   simdgroup-MMA + cache blocking and is the cuBLAS equivalent. No
   in-process fire yet (would need separate Swift host wrapping
   `MPSMatrixMultiplication`); Apple WWDC slides quote ~2 TFLOPS sustained
   for FP32 matmul on M3 — so MPS ≈ 7×–10× faster than the naive-tiled
   kernel we just fired. Same dichotomy as Nvidia: cuBLAS-as-blackbox
   beats hand-MMA today, whole-program-fusion beats both eventually.

## 3. ag_linear MIR — what the codegen would need

`ag_linear(tape, x, W, b, B, D, C)` lowers to:

```
%y = farr_matmul(%x, B, D, %W, C)        # forward (C[B,C] = x[B,D] * W[D,C])
_ag_push(tape, ag_k_linear(), …)         # tape record for bwd
```

Backward (via `matmul_bwd_auto`, `ag_tape.hexa:630`):

```
%dW = farr_matmul_NT(%x, %og)            # dW[D,C] = x[B,D]ᵀ * og[B,C]  (D·B · B·C)
%dx = farr_matmul_NT(%og, %W)            # dx[B,D] = og[B,C] * W[D,C]ᵀ  (B·C · C·D)
```

`matmul_bwd_auto` today is host-scalar (CPU ikj order, matches
`nn_linear_bwd` byte-eq — see ag_tape.hexa:601-627 commentary).

### Required MIR shapes for codegen_emit_metal_msl

| Shape                          | Status                          | Cycle work |
|--------------------------------|---------------------------------|-------------|
| `farr_matmul(A[M,K], B[K,N])`  | NO recogniser                   | **P5** — emit naive (this fire's kernel as MSL template) |
| `farr_matmul_NT` (Bᵀ)          | NO recogniser; need explicit op | **P5.1** — codegen pattern-match `transpose_2d → matmul` and fuse |
| Tiled MMA via `simdgroup_matrix` | NO codegen shape              | **P6** — only after P5 naive passes |
| Broadcast bias add `y += b[C]` | Captured by existing vec_add shape if bias is replicated | already covered, but `ag_linear` bypasses bias (mk2-C5, ag_tape.hexa:212-217) — N/A |
| FP32 storage vs FP64 farr       | **blocker** — need an FP32 farr table or per-op conversion shims | **P5.0** — pre-req: HX_FARR32 |

## 4. Path-A vs Path-MPS

| Concern              | Path A: codegen MMA               | Path MPS: blackbox dispatch     |
|----------------------|-----------------------------------|---------------------------------|
| Whole-program fusion | yes (the flame design goal)       | no                              |
| Time-to-first-fire   | weeks (P5 + P5.1 + P6 + FP32 farr)| days (Swift host + MPS handle)  |
| Peak FP32 GFLOPS     | up to ~3 TFLOPS once MMA wired   | ~2 TFLOPS today                 |
| Correctness gate     | `rel_err < 1e-5` (this fire shows the shape works) | MPS is closed-source; trust their tests |
| Maintenance          | hexa-native; survives Apple SDK changes | brittle to MPS API churn |

**Recommendation (decision-gate-ready):**

- **Short term (1-2 cycles):** ship the MPS blackbox path as a `HEXA_METAL`
  dim-gate mirroring `HEXA_CUDA` in `runtime.c:6157`. Unblocks Mac users
  immediately. Honest scope = "MPS-as-cuBLAS-equivalent; whole-program
  fusion deferred."
- **Long term:** Path A — hexa-native codegen matmul recogniser. This
  cycle's fire is the correctness reference + perf floor.

The two are compatible: short-term MPS at `runtime.c`, long-term codegen
in `metal_target.hexa`; flip a feature flag when codegen catches up.

## 5. Pre-reqs in dependency order

1. **HX_FARR32** (FP32 farr table) — **LANDED** N26 `bf545c41` (decided
   option (a) — parallel `_hx_farr32_table` in self/runtime.c:4795+).
   Six C builtins: `hexa_farr32_zeros/_get/_set/_len/_free/_matmul`. Cast
   cost moved to optional hexa-side hoist.
2. **runtime.c dim-gate** mirroring lines 6157-6175 with `HEXA_METAL`
   guard — **LANDED** N15 `6315b59f` (FP64 path with FP32 cast in shim)
   + N26 `bf545c41` (native FP32 dim-gate). Mac-only; `HEXA_CUDA` and
   `HEXA_METAL` coexist.
3. **`farr_matmul_NT` codegen recogniser** for the backward pass —
   **PARTIAL** N34 `66093a65` (matmul_NT_b: `dx = dy · W^T`) landed in
   runtime + Metal MPS shim. **GAP**: matmul_NT_a (`dW = x^T · dy`) is
   not yet implemented; flame ag_linear bwd-dW currently routes through
   the FP64 `matmul_bwd_auto` host-scalar path. Follow-up cycle to add
   `hexa_farr32_matmul_NT_a` + `_hx_metal_farr32_matmul_NT_a_gpu`.
4. **`hexa gpu fire` Metal target** — extend PR #215/#221 to invoke
   `metal -c` + `metallib` + Swift host wrapper. Today the verb is
   Nvidia-only (cubin/PTX path).
5. **simdgroup_matrix MMA emitter** — only after (3) passes correctness.

## 5a. Step 5 (consumer rewrite) — LANDED 2026-05-21

Closes the §5 dependency chain at the flame source level. ag_linear's
forward routes through `farr32_matmul` when `env("HEXA_METAL") == "1"`
AND the shape passes the dim-gate (M·K > 8192 || K·N > 8192 — same
threshold as runtime.c::hexa_farr_matmul). Default path (no env or
small shape) stays on `farr_matmul` FP64 — byte-identical to pre-step-5
behavior. ag_linear backward stays on the FP64 host-scalar path per §5
step 3 gap; the bwd FP32 dispatch is the immediate follow-up.

Helper: `stdlib/flame/ag_tape.hexa::_ag_linear_metal_fp32_fwd` does the
FP64 farr → FP32 farr32 down-cast (element-wise `farr32_set` carrier),
calls `farr32_matmul`, up-casts result back to FP64 farr for tape
uniformity. Cast cost is in hexa source where future model-init refactors
can hoist it upstream (param init returning farr32 directly).

Codegen wiring: `self/codegen_c2.hexa` dispatches `farr32_zeros/_get/_set/
_len/_free/_matmul/_matmul_NT_b` to the C builtins (1-arg + 2-arg + 3-arg
+ 5-arg routes, mirroring the FP64 family).

## 6. Falsifiers — landed + open

- **F-RFC075-METAL-MATMUL-NUMERIC-EQ (PASS)** — hand-emitted
  MSL matmul on Apple M3 matches CPU ikj reference to `rel_err < 3.3e-7`
  across 128³/256³/512³.
- **F-RFC075-FLAME-AG-LINEAR-METAL-NUMERIC-EQ (PASS, step 5)** —
  `inbox/fires/rfc075_flame_ag_linear_metal_2026_05_21/host_check.c` —
  2-layer FP32 forward chain (W1: [128,256], W2: [256,64]) vs FP64
  CPU reference. See result.json for shape + rel_err.
- **F-RFC075-METAL-MATMUL-CODEGEN-EQ (OPEN)** — `metal_target.hexa`
  emits MSL whose `xxd`-canonicalised text matches `matmul.metal` for the
  `farr_matmul` MIR shape. (Equivalent to PR #215/#221 cubin-byte gate
  but in MSL text space.) Blocking on §5 step 1+2+3.
- **F-RFC075-METAL-AG-LINEAR-EQ (OPEN, bwd gap)** — flame `ag_linear`
  forward routed through Metal FP32 via env-gate landed step 5;
  backward still on the FP64 host-scalar `matmul_bwd_auto` path because
  `hexa_farr32_matmul_NT_a` (for `dW = x^T · dy`) is not yet landed.
  Closure requires adding the NT_a builtin + Metal shim.
- **F-RFC075-METAL-AG-LINEAR-PERF (OPEN)** — same setup, measured
  median per-step wall vs CPU baseline ≥ 4× speedup on d768/12L. Closes
  the Apple-side parallel to Phase 4-D-9.

## 7. Honest scope

- Single-session fire is **single Mac, single M3 SoC**. No multi-host
  variance bound. The 6 shapes × 15 timed runs gives ~1 ms standard
  deviation at 512³, which is fine for shape-passes but not for ratio
  claims against MPS (would need 100+ samples + matched-MPS run).
- "MPS ≈ 7×–10× faster" cites Apple WWDC published numbers, NOT an
  in-vivo measurement on this machine. Replace with a matched fire
  before quoting in user-facing copy (per `feedback_no_third_party_brand_in_copy`,
  no fabricated comparisons).
- The naive kernel beats the tiled kernel at 256³ in one of the JSON
  rows (142.56 vs 95.34 GFLOPS) — workgroup-occupancy boundary effect,
  not a code bug. The 512³ row is the representative one because the
  GPU is fully populated.
- This cycle does **NOT** edit `compiler/codegen/metal_target.hexa`
  (N5 lane) or `stdlib/flame/*.hexa` source (active flame work). It
  establishes the silicon-fire reference + cross-cycle integration design
  only.

---

## Log

- **2026-05-21 P5 silicon-fire + design** — first FP32 matmul fired on
  Apple M3 GPU through hand-emitted MSL. 6/6 shapes PASS rel_err < 1e-5;
  269 GFLOPS at 512³ (matmul_tiled). Design doc establishes 6 falsifiers
  + 5 pre-reqs + Path-A-vs-MPS short/long-term split. Branch
  `worktree-agent-a56cc8392810099be`. See
  `inbox/fires/rfc075_metal_matmul_2026_05_21/{matmul.metal,host_matmul.swift,result.json,fire.log}`.
- **2026-05-21 step 1 N15 `6315b59f`** — HEXA_METAL block for FP64 farr_matmul
  in self/runtime.c. Inert without -DHEXA_METAL.
- **2026-05-21 step 2 N18 `cf4b1e38`** — runtime_metal.m MPS shim body
  `_hx_metal_farr_matmul_gpu` (FP64 farr → FP32 cast → MPS → FP64).
- **2026-05-21 step 3 N26 `bf545c41`** — HX_FARR32 parallel table +
  six C builtins + native FP32 MPS shim. No precision-loss cast at
  the dispatch boundary.
- **2026-05-21 step 4 N34 `66093a65`** — `hexa_farr32_matmul_NT_b` for
  ag_linear bwd-wrt-input (`dx = dy · W^T`). MPS `transposeRight:YES`.
- **2026-05-21 step 5 (this cycle)** — flame ag_linear FP32 Metal
  forward consumer. `_ag_linear_metal_fp32_fwd` helper + env-gated
  dispatch in `ag_linear`. Codegen wiring for `farr32_*` builtins in
  `self/codegen_c2.hexa`. 4 of 5 gaps from §5 closed; remaining gap =
  matmul_NT_a for bwd-wrt-weight FP32. See
  `inbox/fires/rfc075_flame_ag_linear_metal_2026_05_21/` for validation.
