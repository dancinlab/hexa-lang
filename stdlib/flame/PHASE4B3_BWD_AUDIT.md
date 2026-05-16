# nn_decoder_block_bwd structure audit (Phase 4-B-3-3 hand-translation prep)

> Mirror of PHASE4B3_BLOCK_FWD_AUDIT.md (commit `490e7b2a`) for the
> backward pass. nn_decoder_block_bwd is 374 hexa lines (vs fwd 280) —
> larger body, but same per-section primitive emit pattern applies.

## Source: stdlib/flame/decoder_block_lib.hexa:509-(509+374)

`pub fn nn_decoder_block_bwd(X, Bp, Bc, dXout, dX_out, Bg, cos, sin, T, d, nh, nkv, h)`

bwd takes the saved fwd state (Bc) + upstream gradient (dXout) +
output gradient destination (dX_out) + parameter gradient accumulator
(Bg). Reverse-walks the 9 fwd sections in reverse order, accumulating
parameter gradients into Bg and producing input gradient in dX_out.

## Section map (REVERSE order from fwd)

| # | section (reverse) | hexa lines | est C lines | complexity | Phase 4-A-bwd already farr_matmul-routed |
|---|---|---|---|---|---|
| 9rev | residual Xout = hstate + sw_o | 10 | ~10 | trivial (dh = dXout, dsw_o = dXout) | — |
| 8rev | SwiGLU bwd | ~60 | ~80 | medium-high | YES (dWd/dWg/dWu via Phase 4-A-bwd) |
| 7rev | RMSNorm 2 bwd | ~30 | ~35 | simple (vjp) | — |
| 6rev | residual hstate bwd | 5 | ~5 | trivial | — |
| 5rev | Wo proj bwd | ~25 | ~30 | medium (dWo farr_matmul-routed) | YES (Phase 4-A-bwd partial 3) |
| 4rev | attention bwd | ~70 | ~80 | most complex (dQ, dK, dV) | — |
| 3rev | RoPE bwd | ~55 | ~60 | complex (inverse rotation, per head/pos) | — |
| 2rev | Q/K/V proj bwd | ~50 | ~60 | medium (dWq/dWk/dWv farr_matmul-routed) | YES (Phase 4-A-bwd) |
| 1rev | RMSNorm 1 bwd | ~30 | ~35 | simple (vjp) | — |
| **total** | — | **~335** | **~395** | **mid-high** | — |

C body estimate: ~395 lines (vs fwd ~270). Larger due to:
- More farr_get/set sites per section (gradient accumulation)
- Phase 4-A-bwd batched accumulators already inlined in source
- vjp formulas (especially attention bwd)

## Hand-translation order (mirror of fwd: simplest → complex)

| order | sections | rationale |
|---|---|---|
| 1 | 9rev + 6rev (residual bwd × 2) | trivial elementwise; sanity check |
| 2 | 7rev + 1rev (RMSNorm bwd × 2) | vjp algorithm; reuse byte-eq pattern |
| 3 | 5rev + 2rev (matmul bwd × 4 calls) | farr_matmul-routed already; SKIP per audit |
| 4 | 8rev (SwiGLU bwd) | silu_grad + Hadamard + matmul callbacks |
| 5 | 3rev (RoPE bwd) | inverse rotation pair-rotate |
| 6 | 4rev (attention bwd) | dQ/dK/dV — largest, Path C revert lesson |
| 7 | full bwd byte-eq + wall measure | F-RFC047-BLOCK-BWD-EMIT-BYTE-EQ |

## Per-section byte-eq verification strategy

Same as fwd: V1 section-by-section replacement. Each section ships
as own commit boundary. Composite gate via existing GRAD-EXACT
falsifier (F-RFC043-BLOCK-GRAD-EXACT on F-RFC043-BLOCK-DET inputs).

Standalone test harness pattern reuses fwd template:
- Allocate Bp/Bc with same seeded init as fwd test
- Run hexa wrapper nn_decoder_block_fwd → fills Bc cache
- Run hexa wrapper nn_decoder_block_bwd → produces baseline {dX, dWq, dWk, dWv, dg1, dg2, dWg, dWu, dWd, dWo}
- Run primitive bwd on same Bc cache → produces test outputs
- Diff: max|baseline_grad - test_grad| should be 0.0

## Risks per section (bwd-specific)

| section | risk | mitigation |
|---|---|---|
| 9rev, 6rev (residuals) | very low | trivial pattern |
| 7rev, 1rev (RMSNorm vjp) | low | vjp algorithm well-known, byte-eq template proven |
| 5rev, 2rev (matmul bwd) | SKIP | farr_matmul-routed, no boxing-elim benefit |
| 8rev (SwiGLU bwd) | mid | silu_grad + Hadamard order, Phase 4-A-bwd batched accumulators |
| 3rev (RoPE bwd) | mid | inverse rotation pair-rotate, careful with `if c < half` branch |
| 4rev (attention bwd) | mid-high | dQ/dK/dV accumulation, Path C revert lesson (commit 23705dc5) |

## Estimated effort

| step | what | effort | falsifier |
|---|---|---|---|
| 1 | PHASE4B3_BWD_AUDIT.md (THIS COMMIT) | 1 cycle | — |
| 2 | 4 leaf bwd primitives byte-eq (rmsnorm_bwd, silu_grad, rope_bwd, attn_bwd) | 2 cycles | F-RFC047-LEAF-EMIT-*-BWD |
| 3 | A2-bwd full primitive hand-translate (~395 lines) | 1-2 cycles | compile + standalone build |
| 4 | A2-bwd byte-eq verify (vs hexa wrapper grad) | 1 cycle | F-RFC047-BLOCK-BWD-EMIT-BYTE-EQ |
| 5 | A2-bwd wall measure (expected similar ~1.14× ratio) | 1 cycle | F-RFC047-BLOCK-BWD-WALL |
| 6 | A2-bwd build automation (extend a2_build.sh with bwd) | 1 cycle | F-RFC047-A2-BWD-BUILD |
| **total** | — | **7-8 cycles** | aligned with PHASE4B3 mirror estimate |

## Expected wall improvement (after A2 bwd ship)

Per Phase 4-B-3 boxing-elim measurement (commit 07cdd405, 3.99×) +
A2 fwd wall finding (commit cfbba144, 1.14× MEASURED):

- A2 fwd: ~1.14× wall improvement on fwd portion
- A2 bwd: expected similar ~1.10-1.20× (bwd is larger body but more
  matmul-helper-bound; primitive contribution might be smaller)
- Cumulative A2 fwd + bwd: ~1.20-1.30× wall improvement vs baseline
- flame:anima ratio: 10.435 / 22.13 = 0.471× → estimated 0.40× post-bwd

Still bounded by leaf-by-leaf ~1.4× ceiling. ≥3× target requires
GPU dispatch (Phase 4-D).

## Implementation infrastructure (READY)

- ✅ Build pipeline (tool/flame_phase4b3_a2_build.sh) — extensible
  with bwd primitive concat step
- ✅ Verify_all battery (tool/flame_phase4b3_verify_all.sh) —
  extensible with bwd byte-eq + build check
- ✅ Test harness pattern (5 leaf test harnesses) — reusable
- ✅ `_hx_farr_table[id].buf` ABI proven (commit 1da62cc1)
- ✅ Reverse-mode autograd verified (RFC 034)
- ✅ Phase 4-A-bwd batched accumulators in hexa source — primitive
  port should preserve same algorithm (no reduction-order change
  per Path C revert lesson)

Phase 4-B-3-3 bwd primitive implementation can start with section
9rev + 6rev (residual bwd × 2, trivial) next cycle.

## Cross-link

- PHASE4B3_BLOCK_FWD_AUDIT.md (commits 490e7b2a + e7472b1e) — fwd mirror
- PHASE4B3_DESIGN_CORRECTION.md (commit 122e186d) — block INLINE
- A2 fwd shipped (commit cfbba144) — fwd primitive byte-eq + 1.14× wall
- A2 build automation (commit 7702ff24) — reusable for bwd
- Verify_all battery (commit 13bf8b14) — extensible
- RFC 034 reverse-mode autograd verified (4-A-bwd partial commits)
- decoder_block_lib.hexa:509+ — canonical nn_decoder_block_bwd source
