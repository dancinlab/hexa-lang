# Phase 4-D-5-4 step 2b — Layer 2 GPU-dispatch trainer regen notes

> flame Phase 4-D-5-4 · 2026-05-17 · worktree `worktree-agent-ac0f6672f7c5a096c`
> Budget: $0 (Mac builds only — no vast.ai fire)

## Goal

Phase 4-D-5-4 wall fire #4 FAILED: trainer GPU util 0%. Root cause = the
trainer `.c` artifact (`state/flame_phase4d_20260517_102511/flame_d768_12L_corpus_test_a2.c`)
was A2-built BEFORE Phase 4-D-5-2 Layer 2 landed (commit `6e3cb5a9`), so it
carries the CPU-only `flame_proj_inline_matmul` with no GPU dispatch path.

This step produces a trainer `.c` that contains the Layer 2 dim-aware
`flame_proj_matmul_dispatch` so a `-DHEXA_CUDA` build can route large matmul
shapes to cuBLAS Dgemm.

## Path used: B (surgical patch)

Path A (A2 rebuild via `tool/flame_phase4b3_a2_build.sh`) was NOT used —
it depends on the IPCP baseline transpiler (a parallel agent's fix), and
the brief explicitly designated Path B as the honest fallback. The patch
is a deterministic, mechanical concat-replace, so Path A would not produce
a different result for the matmul block.

### Patch mechanics

The stale trainer `.c` is a concatenation: `runtime.c` include + matmul
primitive block + block_fwd/bwd primitive blocks + hexa-emitted trainer body.
The matmul block is `tool/flame_phase4b3_matmul_primitives.c` content
concat'd verbatim at build time.

- Stale matmul block: lines **3-143** (header comment through the close of
  `flame_grad_accum_T16_d32x64_primitive`).
- Replacement: the full Layer 2 `tool/flame_phase4b3_matmul_primitives.c`
  (243 lines) — identical d=32 primitive shape signatures, plus the new
  `FLAME_MATMUL_GPU_THRESHOLD` (8192), `flame_proj_gpu_matmul`
  (`#ifdef HEXA_CUDA` cuBLAS route via `hexa_farr_matmul_gpu`), and
  `flame_proj_matmul_dispatch` (dim-aware: `M·K > 8192` → GPU, else CPU).

Construction: `head -2` (the `runtime.c` include) + Layer 2 block +
`tail -n +144` (block_fwd primitive onward, unchanged).

Result: `flame_d768_12L_corpus_test_a2_layer2.c`
- 3463 lines (was 3362; +101 = 243 new − 141 old block − 1 join)
- `flame_proj_matmul_dispatch`: 9 occurrences (1 def + 8 callers across
  4 fwd + 4 bwd primitives — every primitive now routes through dispatch).

## IMPORTANT — artifact / filename mismatch (honest caveat)

Despite the `d768_12L` filename, the trainer `.c` was built from the
**d=32·3L** source (`flame_d32_corpus_test.hexa`), NOT
`stdlib/flame/flame_d768_12L_corpus_test.hexa`. Evidence:
- Matmul primitives are `d32x32` / `d16x32` / `d64x32` / `d32x64`.
- Embedded comments explicitly reference "d=32·3L flame_d32_corpus_test".
- The real d768 source uses `decoder_lib` / `nn_lib` runtime APIs with
  T=1024, d=768, n_layer=12 — different shapes entirely.

Consequence for this fire: with d=32 shapes the matmul `M·K` values are
{512, 1024, 2048} — all ≤ 8192 threshold → `flame_proj_matmul_dispatch`
keeps them on the CPU inline path even with `-DHEXA_CUDA`. So this trainer
will STILL show ~0% GPU util on the matmul primitives.

The Layer 2 swap is still the correct deliverable for this step (it makes
the trainer dispatch-capable and removes the pre-Layer-2 staleness), but
**a genuine d=768 GPU-util fire requires a real d768 A2 trainer build**
whose primitives carry d=768 shapes (`M·K = 589824 > 8192`). That is a
separate artifact-regen task gated on the A2 build pipeline supporting
the d768 config — the A2 build script (`flame_phase4b3_a2_build.sh`) is
currently hard-coded to the `d32_nh4_nkv2_h64` block. This caveat is
flagged here so re-fire #5 is interpreted honestly: at d=32 shapes it is
a build-tier + dispatch-presence verification, not a GPU-saturation proof.

## Verification (Mac, $0)

| Check | Result |
|-------|--------|
| `flame_proj_matmul_dispatch` present | YES — 9 occurrences |
| `flame_proj_gpu_matmul` + `hexa_farr_matmul_gpu` (cuBLAS) present | YES — under `#ifdef HEXA_CUDA` |
| `FLAME_MATMUL_GPU_THRESHOLD` (8192) present | YES |
| All 8 primitives route through dispatch | YES — no primitive calls `flame_proj_inline_matmul` directly |
| Mac no-CUDA compile (`clang -O2 -I self -lm`) | PASS — 592KB arm64 Mach-O, no warnings |
| HEXA_CUDA syntax-check (`clang -DHEXA_CUDA -fsyntax-only`) | PASS — clean (`hexa_farr_matmul_gpu` resolves via runtime.c:10874) |

No-CUDA build correctness: with `HEXA_CUDA` undefined, `flame_proj_gpu_matmul`
and the GPU branch of `flame_proj_matmul_dispatch` are `#ifdef`-compiled out
entirely — the CPU inline loop is the only path, so byte-eq with the
pre-Layer-2 baseline is preserved by construction.

## Dispatch script update

`tool/dispatch_phase4d_5_4.sh`:
- `TRAINER_C` → `state/flame_phase4d_5_4_2026_05_17/flame_d768_12L_corpus_test_a2_layer2.c`
  (was the stale `state/flame_phase4d_20260517_102511/flame_d768_12L_corpus_test_a2.c`).
- `REPO_ROOT` → derived from `${BASH_SOURCE[0]}` (was hard-coded to a stale
  worktree path `agent-af7b622570209a02f`) — now worktree-portable.
- Remote upload still renames to `flame_d768_12L_corpus_test_a2.c` on the
  pod; the build step compiles that fixed remote name, so no build-step
  change was needed.

## Files produced

- `state/flame_phase4d_5_4_2026_05_17/flame_d768_12L_corpus_test_a2_layer2.c`
  — Layer 2 GPU-dispatch trainer (Path B patched)
- `state/flame_phase4d_5_4_2026_05_17/LAYER2_TRAINER_REGEN_NOTES.md` — this file
- `tool/dispatch_phase4d_5_4.sh` — TRAINER_C + REPO_ROOT updated

## Next

Re-fire #5 (gated on IPCP baseline fix + this step). Honest expectation per
the caveat above: at d=32 shapes this fire is a build-tier integration +
dispatch-presence check, not a GPU-saturation measurement. F-RFC046 wall
measurement needs a real d768-shaped A2 trainer (separate regen, gated on
the A2 build pipeline supporting the d768 block config).
