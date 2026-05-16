# nn_decoder_block_fwd structure audit (Phase 4-B-3 hand-translation prep)

> Section-by-section breakdown of nn_decoder_block_fwd (decoder_block_lib.hexa:217-509)
> to prep the Phase 4-B-3-2-third REVISED-1 full block primitive C emission.
>
> Per PHASE4B3_DESIGN_CORRECTION.md (commit `122e186d`): block_fwd
> inlines all leaf logic (no leaf fn calls). Wall improvement requires
> hand-translation of the entire body, not leaf-by-leaf replacement.

## Section map (hexa source line offsets within block_fwd body)

| # | section | line range (relative) | hexa lines | est C lines | complexity |
|---|---|---|---|---|---|
| 1 | per-position RMSNorm(X, g1) | 35-58 | 24 | ~25 | **simple** (Σ + scale loops) |
| 2 | Q/K/V projections | 59-64 | 6 | ~10 | uses farr_matmul helper (already primitive) |
| 3 | RoPE rotation on Q + K | 65-146 | 82 | ~80 | **complex** (per-head pair-rotate, careful read-write order) |
| 4 | attention core (GQA + causal) | 147-214 | 68 | ~70 | **complex** (softmax + per-head per-position + value combine) |
| 5 | output projection (Wo) | 215-219 | 5 | ~10 | uses farr_matmul helper |
| 6 | residual: hstate = X + attn_out | 220-228 | 9 | ~10 | trivial elementwise add |
| 7 | per-position RMSNorm(hstate, g2) | 229-252 | 24 | ~25 | mirror of section 1 |
| 8 | SwiGLU: a, b, s=silu(a)·b, o=Wd·s | 253-271 | 19 | ~30 | inline matmul + silu + Hadamard |
| 9 | residual: Xout = hstate + sw_o | 272-279 | 8 | ~10 | trivial elementwise add |
| **total** | — | 217-279 (within body) | **245** | **~270** | mid-high overall |

The hexa body is 245 lines inside the fn (out of 279 between
declaration and closing `}`); the C primitive should land around
270 lines after adding offset constants + farr_table dereference
setup at fn entry.

## Hand-translation order (smallest → largest complexity)

| order | sections | rationale |
|---|---|---|
| 1 | 1 + 7 (both RMSNorms) | simple Σ + scale; mirror algorithms; gets verification template right |
| 2 | 6 + 9 (both residuals) | trivial elementwise; sanity check after RMSNorms |
| 3 | 2 + 5 (Q/K/V proj + Wo proj) | farr_matmul helper call — primitive form of farr_matmul exists or stays unchanged |
| 4 | 8 (SwiGLU) | inline matmul + silu/Hadamard; medium |
| 5 | 3 (RoPE) | **careful** — pair-rotate read-write order; multi-pass; bug-prone |
| 6 | 4 (attention) | **most careful** — softmax + GQA + causal + value combine; reduction order sensitive (Path C revert lesson) |

## Per-section byte-eq verification strategy

Whole-block byte-eq is the goal (F-RFC047-BLOCK-EMIT-BYTE-EQ-FWD on
F-RFC043-BLOCK-DET inputs). Per-section verification requires either:

**(V1) Section-by-section replacement** — replace one section's
inline code with primitive while keeping others HexaVal. Re-run
F-RFC047-BLOCK-EMIT-BYTE-EQ-FWD. PASS → that section is correct.
Iterate.

**(V2) Whole-body emit + diff-from-baseline** — emit the full
primitive body at once, run F-RFC047-BLOCK-EMIT-BYTE-EQ-FWD. If
FAIL, bisect via section disabling.

**Recommended: V1** — section-by-section replacement gives clear
attribution of failures. Each section ships as its own commit
boundary.

## Risks per section (from audit)

| section | risk | mitigation |
|---|---|---|
| 1, 7 (RMSNorm) | low (already verified pattern, commit `1da62cc1`) | reuse byte-eq verify template |
| 6, 9 (residuals) | very low (no reduction, no transcendentals) | none needed |
| 2, 5 (matmul) | low (farr_matmul already routes through primitive path) | preserve call form |
| 8 (SwiGLU) | mid (silu approx + Hadamard order) | careful loop order preservation |
| 3 (RoPE) | mid (pair-rotate read-write order — commented bug history in source lines 76-92) | preserve the "scratch pass + write pass" form exactly |
| 4 (attention) | mid-high (softmax reduction order; GQA n_rep grouping; causal mask) | Path C revert lesson — Phase 2 strict byte-eq required |

## Effort estimate per sub-step

| order # | what | effort | falsifier |
|---|---|---|---|
| 1 | both RMSNorms primitive (sections 1 + 7) | 1 cycle | F-RFC047-BLOCK-EMIT-PARTIAL-EQ-RMSNORM |
| 2 | both residuals (sections 6 + 9) | 0.5 cycle | F-RFC047-BLOCK-EMIT-PARTIAL-EQ-RESID |
| 3 | matmul preservation (sections 2 + 5) | 0.5 cycle | F-RFC047-BLOCK-EMIT-PARTIAL-EQ-PROJ |
| 4 | SwiGLU (section 8) | 1 cycle | F-RFC047-BLOCK-EMIT-PARTIAL-EQ-SWIGLU |
| 5 | RoPE (section 3) | 1 cycle | F-RFC047-BLOCK-EMIT-PARTIAL-EQ-ROPE |
| 6 | attention (section 4) | 1-2 cycles | F-RFC047-BLOCK-EMIT-PARTIAL-EQ-ATTN |
| 7 | full block byte-eq + wall measure | 1 cycle | F-RFC047-BLOCK-EMIT-BYTE-EQ-FWD + WALL-IMPROVED ≥3× |
| **total** | — | **5-7 cycles** | aligned with PHASE4B3_DESIGN_CORRECTION.md estimate |

## Implementation infrastructure check (already in place)

- `tool/flame_phase4b3_emit_trampoline.hexa` (commit `dcd2ed74`):
  emits primitive C bodies, appends to concat'd .c. Easy to extend
  with section-by-section primitive emit.
- `tool/flame_phase4b3_build.sh` (commit `28cf24a6`): end-to-end
  build pipeline; section progress just adds more primitive content
  to the concat step.
- `_hx_farr_table[id].buf` direct dereference ABI proven (commit
  `1da62cc1` byte-eq verify with libm reference).
- sed call-site rewrite (commit `28cf24a6`): IPCP-rewritten C's
  block_fwd call already routes through trampoline.

Phase 4-B-3-2-third REVISED-1 implementation can start immediately
with section #1 (RMSNorm 1 + 7). No new tooling required.

## Cross-link

- PHASE4B3_DESIGN_CORRECTION.md (commit `122e186d`) — the correction
  that made this audit necessary
- PHASE4B3_LEAF_PRIORITY.md (commit `725ff6bb`) — outdated framing
- PHASE4B3_EMISSION_DESIGN.md (commit `828717fb`) — original full-block
  approach now validated
- decoder_block_lib.hexa:217-509 — the canonical source to translate
- Path C revert (commit `23705dc5`) — attention section's reduction-order
  sensitivity lesson
