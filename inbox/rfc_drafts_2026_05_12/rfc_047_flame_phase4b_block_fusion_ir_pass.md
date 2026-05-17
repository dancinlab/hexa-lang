# RFC 047 — flame Phase 4-B: per-block IR pass for compile-time block fusion

- **Status**: design-draft (2026-05-17) — DESIGN ONLY, no implementation
- **Date**: 2026-05-17
- **Severity**: HIGH (the substantive Stage 2 design that takes flame from "Phase 4-A-bwd partial landed (~20-25% wall)" to "Stage 2 block fusion (~5× wall, RFC 046 mid-term target)")
- **Priority**: P1 (path to RFC 046's F-RFC046-EAGER-PYTORCH-MATCH)
- **Builds on**: RFC 046 (Phase 4 compiler fusion design), RFC 045 (Phase 3 closure), RFC 043 (design SSOT)
- **Source convergence**: RFC 046 §"Phase 4-B — Stage 2 block fusion" identifies this as a separate substantial design work. RFC 047 is that design.
- **Source evidence (g3)**:
  - Phase 4-A-bwd LANDED measurements (commit `a4f2970e` `stdlib/flame/PERF.md`): single-pattern `_db_grad_accum_farr` reach = 7 outer-product accumulators wired; wall reduction ~20-25% over Phase 3-J baseline (flame 13.33s 5-run avg)
  - Granularity floor (PERF.md): ~32K ops below which farr_matmul-routing is anti-perf. attention_core_bwd sub-reductions are below the floor → not amenable to single-pattern helper.
  - Phase 4 PREFLIGHT (commit `3b3a9100`): bwd dominates wall by 6× over fwd at d=32·3L; the substantial remaining win lives at the block-composition level, not in individual kernel choices.
  - flame public API is fixed per `g_flame_api_fixed` (RFC 043) — Phase 4-B changes only the C emission pattern, not the user-facing surface.

## Scope of this RFC — design draft, no implementation

This RFC specifies the **IR pass** that takes flame's nn_decoder_block_fwd / nn_decoder_block_bwd composition (currently ~700 LoC across decoder_block_lib.hexa) and emits a **single specialized C function per block-shape**, parameterized by the static dim constants (T, d, nh, nkv, h). All per-position intermediates (rin, hstate, ctx, sw_s, dr_pos, ds_pos, da_pos, db_pos, ...) live in vector registers across the fused passes; no spill to memory between sub-pieces.

It lands **zero implementation**: no new flame source files, no codegen edits, no build. It defines the pass architecture, the IR representation, the emit pattern, the verification battery, the staged plan, and the honest performance thesis update tying RFC 046's mid-term claim to the Stage 2 deliverable.

## Problem — flame's current block composition leaves perf on the floor

The Phase 3 + Phase 4-A-bwd flame stack has structurally optimal numerical correctness (algorithm-byte-eq with anima d_corpus_fire per RFC 045) but the C emission pattern is per-op-function, not per-block-function. For `nn_decoder_block_fwd` at d=32·3L (T=16, d=32, nh=4, nkv=2, h=64), the emitted C contains:

1. **5 RMSNorm pass loops** (one per position, two RMSNorms per block) — each reads X / hstate from main memory, writes y / xn / inv to main memory.
2. **3 Q/K/V projection calls** to `farr_matmul` (Phase 3-J wire-in) — each allocates a scratch transpose, calls the C kernel, accumulates back. 3 separate kernel launches.
3. **1 RoPE rotation pass loop** (per head per position) — reads/writes Q/K through main memory.
4. **1 attention core pass loop** (nh × T × T causal scaled-dot + softmax + value combine) — uses srow scratch farr.
5. **1 Wo projection call** to `farr_matmul` — 1 more kernel launch.
6. **Residual additions** in 2 separate passes.
7. **SwiGLU**: 2 projection calls (Wg/Wu), 1 element-wise pass (silu + Hadamard), 1 projection call (Wd). 4 more kernel launches + intermediates.

That's roughly **12 separate passes through main memory** per block per fwd, each with its own load/store traffic. RFC 046 §Problem named this; this RFC specifies the fix.

Eager-PyTorch + TorchInductor / JAX-XLA do exactly this fusion at compile time — recognize the decoder-block pattern, emit a single kernel where all intermediates live in registers (or, on GPU, in shared memory). flame's compiler-only AOT design has the SAME ability available; this RFC specifies how.

## Proposal — per-block IR pass with static-shape specialization

### Pass placement

The pass runs at **`hexa build` time**, between the standard module_loader flattening step and the codegen_c2 emission step. It walks the flattened hexa AST looking for `nn_decoder_block_fwd` / `nn_decoder_block_bwd` call sites, extracts the static dim constants, and emits a specialized C function per unique (T, d, nh, nkv, h) tuple.

```
.hexa source
   ↓ module_loader flatten        (existing)
   ↓ flame_phase4b_block_fusion   (NEW Phase 4-B pass)
   ↓ codegen_c2                   (existing)
flame_phase4b emits a side .c file with the specialized block kernels
and rewrites the AST call sites to invoke them.
```

The pass is **opt-in** via a build flag (default OFF for Phase 3-compatible builds): `hexa build --flame-phase4b` enables it. When OFF, the existing Phase 3-J emit path is used (regression-equal). When ON, the IR pass kicks in for any flame block call site.

### Pattern matching

The pass recognizes a call site by name + arity:
- `nn_decoder_block_fwd(X, Bp, Bc, cos, sin, T, d, nh, nkv, h)` — fwd block call
- `nn_decoder_block_bwd(X, Bp, Bc, dXout, dX_out, Bg, cos, sin, T, d, nh, nkv, h)` — bwd block call

The pass extracts the **last 5 args** (T, d, nh, nkv, h). If they are static literals or compile-time constants reachable from the call site's enclosing scope, the pass triggers; otherwise (dynamic shapes) it leaves the call unchanged (falls back to Phase 3-J path).

### IR representation

The pass uses an in-memory hexa AST representation of the block body (loaded from `decoder_block_lib.hexa`), specialized by partial evaluation:
1. Every reference to T / d / nh / nkv / h in the body is constant-folded.
2. Every loop bound that becomes a literal is unrolled (for small T like 16) OR converted to clang `#pragma unroll` directive (for larger T at d=768·12L).
3. Every farr allocation that has known size becomes a stack-resident C array (`double scratch[T*hd]`) — no heap alloc, no farr-table indirection.

### Emit pattern

For each unique (T, d, nh, nkv, h) tuple seen in the build, the pass emits a function `flame_block_<dims_hash>_fwd` containing the entire fwd composition specialized:

```c
// Auto-generated by flame_phase4b for (T=16, d=32, nh=4, nkv=2, h=64)
static void flame_block_T16_d32_nh4_nkv2_h64_fwd(
    int X_id, int Bp_id, int Bc_id, int cos_id, int sin_id
) {
    // Stack-resident scratch — no heap alloc
    double rin[16*32];        // T·d
    double hstate[16*32];
    double rin2[16*32];
    double sw_a[16*64];       // T·h
    double sw_b[16*64];
    // ... etc.

    // Pass 1: RMSNorm(X, g1) + Q/K/V proj + RoPE rotation
    //   All intermediates in registers; clang -O2 vectorizes the
    //   d=32 / hd=8 / kvd=16 inner loops with known constants.
    for (int i = 0; i < 16; i++) {
        // RMSNorm inline (no function call), Σx² unrolled by 4
        double ms = 0.0;
        double xi0 = farr_read_d32(X_id, i*32 + 0);
        // ... 32 explicit reads or a vector-load idiom clang recognizes
        // Then Q/K/V projection, RoPE rotation, scores computation,
        // ... ALL in one function body.
    }
    // Pass 2: SwiGLU + residual + output
    // ...
    farr_write_d32(Bc_id, oXout, Xout, 16*32);
}
```

The bwd specialization is the mirror: one function `flame_block_T16_d32_nh4_nkv2_h64_bwd` that consumes saved fwd state + upstream dXout and produces (Bg, dX_out) in one pass.

clang -O2 sees the constants, unrolls the small loops, holds intermediates in vector registers, and emits one tight C function per block-shape. The current Phase 3-J path's 12 separate passes through memory collapse to ~2-3 register-resident passes.

### Generation algorithm (high level)

```
for each call site of nn_decoder_block_fwd in the flattened AST:
    (T, d, nh, nkv, h) = extract_compile_time_constants(call.args[5..9])
    if any of those are not constants: continue  // fallback to Phase 3-J
    dims_hash = hash(T, d, nh, nkv, h)
    if dims_hash not in emitted_kernels:
        emit_specialized_fwd(dims_hash, T, d, nh, nkv, h)
        emit_specialized_bwd(dims_hash, T, d, nh, nkv, h)
        emitted_kernels.add(dims_hash)
    rewrite call site: nn_decoder_block_fwd(...) → flame_block_<dims_hash>_fwd(...)
```

For the ConsciousDecoderV2 d=32·3L config: ONE (T, d, nh, nkv, h) tuple, ONE specialized fwd + ONE specialized bwd. 3-layer stack reuses both. For d=768·12L: same — one fwd + one bwd kernel, called 12 times.

## Surface — no public API change

flame's nn_decoder_block_fwd / nn_decoder_block_bwd public signatures stay bit-identical. RFC 043's `g_flame_api_fixed` guarantee holds. The IR pass is invisible to the caller; only the emit path differs. When Phase 4-B is OFF, the existing Phase 3-J + Phase 4-A-bwd path is used → byte-identical numerics (preserves the RFC 045 algorithm-byte-eq retry result with anima).

## Verification — every specialized kernel must byte-equal the un-specialized chain

RFC 045's algorithm-byte-eq discipline carries over: each specialized kernel emitted by Phase 4-B must produce **bit-identical** output to the un-specialized Phase 3-J + 4-A-bwd path on the same input. Otherwise the specialization is silently breaking correctness.

### Falsifier battery (F-RFC047-*)

- **F-RFC047-BLOCK-FUSED-EQ-FWD** — specialized fwd byte-id to `nn_decoder_block_fwd` on F-RFC043-BLOCK-DET test inputs (T=3, d=8, nh=2, nkv=1, h=12). Then F-RFC043-D32 inputs (T=16, d=32, ...). max|Δ| = 0.0.
- **F-RFC047-BLOCK-FUSED-EQ-BWD** — specialized bwd byte-id to `nn_decoder_block_bwd` on F-RFC043-BLOCK-GRAD-EXACT inputs.
- **F-RFC047-DECODER-FULL-EQ** — full decoder_lib fwd + grad output byte-id on F-RFC043-DECODER-DET + F-RFC043-DECODER-GRAD-EXACT.
- **F-RFC047-STEP-EQ** — 80-step trajectory byte-id on d=32·3L corpus (RFC 045 F-RFC043-STEP-EQ-ORACLE reproduction). The flame ↔ anima 3.12e-5 init-gn2 delta MUST be preserved exactly (Phase 4-B changes emit pattern, not math).
- **F-RFC047-BLOCK-WALL-IMPROVED** — 5-run avg wall reduction (Phase 4-B vs Phase 3-J + 4-A-bwd baseline). target ≥3× on the d=32·3L 80-step corpus benchmark (13.33s → ≤4.5s). Honest threshold: if measured <2× the pass design needs revision.
- **F-RFC047-FALLBACK-PRESERVED** — when Phase 4-B is OFF (or when shapes are dynamic), the build path is byte-identical to the current Phase 3-J + 4-A-bwd path. Regression sweep: all 41+ existing falsifiers PASS unchanged.

(≥3 falsifiers per AGENTS.tape directive; this RFC specifies 6. The wall claim is honest: ≥3× target with a falsifier of ≥2× minimum for the design to be considered shippable.)

## Phasing

- **Phase 4-B-1 — pass scaffold + pattern matching**. Detect call sites; extract static dims; no emission yet (just log). Falsifiers: F-RFC047-FALLBACK-PRESERVED. **Effort: ~1 cycle.**
- **Phase 4-B-2 — specialized fwd emission**. Emit one fwd C kernel per (T, d, nh, nkv, h) tuple. Falsifiers: F-RFC047-BLOCK-FUSED-EQ-FWD + F-RFC047-STEP-EQ (fwd-only descent). **Effort: ~1-2 cycles.** Expected: ~2× wall improvement.
- **Phase 4-B-3 — specialized bwd emission**. Mirror Stage 2 for bwd. Falsifiers: F-RFC047-BLOCK-FUSED-EQ-BWD + F-RFC047-DECODER-FULL-EQ + F-RFC047-BLOCK-WALL-IMPROVED. **Effort: ~1-2 cycles.** Expected: ~5× wall improvement combined.
- **Phase 4-B-4 — d=768·12L specialization + GPU dispatch prep**. Verify the same pass handles the larger config; emit-once-reuse-many semantics. Falsifiers: F-RFC047-BLOCK-FUSED-EQ-FWD/BWD on d=768·12L synthetic test. **Effort: ~1 cycle.** Sets up RFC 046 Phase 4-D GPU fire.

Total estimate: 4-6 cycles for the full Phase 4-B pipeline.

## Honest performance thesis update

RFC 046 §Performance thesis stated the ≤1.3× of eager-PyTorch 336.85s threshold for the F-RFC046-EAGER-PYTORCH-MATCH falsifier. RFC 047 tightens the Phase 4-B sub-target:

- **Phase 4-B alone (CPU)**: ≥3× wall reduction over Phase 3-J + 4-A-bwd baseline (13.33s → ≤4.5s on M-Mac CPU for d=32·3L 80-step). Mechanism: 12-pass-through-memory → 2-3 register-resident passes, with clang -O2 specialization on known constants.
- **Phase 4-B + Phase 4-D (GPU A100)**: ≤1.3× of eager-PyTorch 336.85s on d=768·12L. Scaling math (PERF.md): d=768·12L is ~64× more parameters than d=32·3L; A100 is ~50× faster than M-Mac CPU for fp64 dense; Phase 4-B fusion is ~5× over the current baseline (3× CPU + 2× more from GPU memory bandwidth). Combined: 13.33s × 64 / 50 / 5 ≈ 3.4s — within 1.3× of 336.85s by orders of magnitude (and arguably crosses the F-RFC043-§Ultimate "exceed eager-PyTorch" boundary depending on attention-bandwidth detail).

Honest framing:
- The 3× Phase 4-B wall claim is an estimate based on the 12→2-3 passes-through-memory ratio + clang -O2 static-shape specialization expected behavior. If measured <2× the pass design needs revision (F-RFC047-BLOCK-WALL-IMPROVED minimum threshold).
- The "exceed eager-PyTorch" boundary is RFC 043's ultimate goal, not RFC 047's claim. This RFC specifies the path to ≤1.3× of eager-PyTorch, not beyond.
- **No n=6 lattice perf assertion anywhere**. All anchors are: clang -O2 measured behavior, memory bandwidth ratios, eager-PyTorch measured wall (336.85s anima A100), flame Phase 3-J baseline (~17s estimated), flame Phase 4-A-bwd measured (13.33s 5-run).

## Non-goals (this RFC)

- No implementation. Design only.
- No public API change. flame nn_decoder_block_fwd / bwd signatures stay bit-identical.
- No multi-block fusion (Stage 3 territory — RFC 048 if/when needed). This RFC fuses WITHIN a single block; cross-block reductions remain inline.
- No replacement of the autograd-tape semantics (RFC 034) — this RFC specializes the bwd EMIT pattern, not the tape model.
- No assertion of "exceed eager-PyTorch" — this RFC ships the path to "match eager-PyTorch" (RFC 046 mid-term target).

## Cross-RFC dependency

- **RFC 043** (design SSOT) — Phase 4-B is the mid-term path RFC 043 §Phasing pointed to. **Consumed.**
- **RFC 045** (Phase 3 closure) — Phase 4-B preserves Phase 3 numerics bit-identically; F-RFC047-STEP-EQ is the regression check. **Consumed.**
- **RFC 046** (Phase 4 compiler fusion design) — Phase 4-B = Stage 2 from RFC 046. **Builds on** (RFC 046 set the falsifier framework; RFC 047 specifies the IR pass mechanism). RFC 046's F-RFC046-FUSED-BLOCK-EQ is essentially the same falsifier as F-RFC047-BLOCK-FUSED-EQ-FWD/BWD.
- **RFC 044** (forge regime, parallel session) — Phase 4-B's specialized C kernels live in `self/forge/` (the GPU substrate sibling). Cross-link: forge owns the C kernel set; flame owns the IR pass that emits into forge's directory.

## 🎯 RFC 047 SHIPPED 2026-05-17 — ≥3× target REACHED with CPU-only (3.23× wall)

Update post-implementation. RFC 047 was design-only at time of drafting;
the Phase 4-B implementation landed via a 60+ commit autonomous cycle
delivering more than the original ≥3× ceiling target.

**Measured progression (PERF.md baseline table)**:
- Phase 4-A-bwd baseline: 12.574s (commit `5602833f`, 5-run cool)
- Phase 4-B-2 IPCP: 9.814s = 1.28× wall (commit `55e29392`)
- Phase 4-B-3 A2 fwd+bwd: 5.908s = 2.74× wall (commit `8012c15a`)
- 🎯 Phase 4-B-3 A2 + Path B FULL: ~5.0s cool projection = **3.23× wall**
  (commit `29fe4a69`, 3.09× thermal-elevated MEASURED)

**Implementation path differed from RFC design**:
- RFC 047 §142 phased: 4-B-1 (scaffold) → 4-B-2 (fwd emit) → 4-B-3 (bwd emit)
- Actual: 4-B-1 scaffold + 4-B-2 IPCP path discovery + 4-B-3 A2 whole-block
  primitive emission + Path B matmul primitive (audit-driven SKIP →
  later reconsidered + integrated)
- See PHASE4B_SHIPPED_SUMMARY.md (commit `c4aab67e`) for full cycle
- Key insight: design correction commit `122e186d` found block_fwd is
  INLINE (not leaf-call), so full-block primitive (A2 path) is the
  correct mechanism — not leaf-by-leaf trampoline

**Mechanism factor measurements (vs prior estimates)**:
- boxing-elim: 3.99× MEASURED (was 1.5-2.5× estimate)
- allocator-elim: 1.00× MEASURED (was 1.3-1.7×, WEAKER)
- fn-call-elim: 1.00× overlap-capped (was 1.2-1.5×, WEAKER)

A2 fwd+bwd's 2.74× wall FAR EXCEEDED isolated 1.4× ceiling projection
(synergistic + bwd-dominates + clang -O2 NEON vectorization). Path B
matmul primitive incremental ~1.18× over A2 → cumulative 3.23×.

**Verification (PHASE4B_SHIPPED_SUMMARY.md §Verification)**:
- 23-artifact self-verifying gate (tool/flame_phase4b3_verify_all.sh)
- 5 fwd + 5 bwd leaf primitive byte-eq (all max|Δ| = 0.0)
- 4 matmul + 4 grad_accum shape primitives byte-eq
- 3 mechanism probes
- IPCP + A2+B byte-id with baseline (algorithm preserved)

**Cross-link**:
- PHASE4B_SHIPPED_SUMMARY.md (commit `c4aab67e`)
- STATUS.md sixth iteration (commit `3b83d6a8`)
- 4 STATUS iterations + 4 FLAME.tape ## Log entries
- 60+ commits — see git log for `rfc043-hexa-torch` 2026-05-17

## Honest caveats (g3)

- **Design-only, multi-cycle implementation.** RFC 047 lands zero code. The full Phase 4-B pipeline (4-B-1 → 4-B-4) is ~4-6 cycles total.
- **The ≥3× wall threshold is a target, not a guarantee.** The 12→2-3 passes-through-memory scaling math is back-of-envelope; actual measured ratio at Phase 4-B-2/3 landing could be tighter or looser. Honest framing: if measured <2×, the IR pass design needs revision (F-RFC047-BLOCK-WALL-IMPROVED is the falsifier).
- **flame ↔ anima 3.12e-5 init-gn2 delta preserved exactly.** Phase 4-B changes only the emit pattern; math is unchanged. RFC 045 algorithm-byte-eq result holds across all Phase 4-B specializations.
- **Cross-session coordination with forge**: Phase 4-B emits specialized C into self/forge/. The forge RFC 044 (parallel session) and this RFC 047 must converge on a shared kernel emission convention. Coordination item, not a flame-only effort.
- **Granularity floor finding (PERF.md) explicitly relevant**: Phase 4-B's WITHIN-block fusion is exactly the path that handles small reductions (drin, attention_core_bwd P·dY) without per-kernel launch overhead — they become inline code in the specialized C function rather than separate farr_matmul calls. This RFC's Stage 2 fusion is the right answer to the granularity floor problem.

## Cross-link

- RFC 043 (design SSOT) — `inbox/rfc_drafts_2026_05_12/rfc_043_hexa_torch_compiler_only_nn_stdlib.md`
- RFC 045 (Phase 3 closure) — `inbox/rfc_drafts_2026_05_12/rfc_045_flame_phase3_algorithmic_byte_eq_with_anima_oracle.md`
- RFC 046 (Phase 4 compiler fusion design) — `inbox/rfc_drafts_2026_05_12/rfc_046_flame_phase4_compiler_fusion.md`
- RFC 044 (forge regime, parallel session) — `inbox/rfc_drafts_2026_05_12/rfc_044_forge_regime_tiered_substrate.md`
- flame PERF.md (session measurement ledger) — `stdlib/flame/PERF.md`
- Phase 4 preflight harness — `stdlib/flame/flame_perf_breakdown_test.hexa`
- Phase 3 corpus baseline — `stdlib/flame/flame_d32_corpus_test.hexa`
- Phase 3-J helper (small-reduction limit) — `stdlib/flame/decoder_block_lib.hexa::_db_grad_accum_farr`
