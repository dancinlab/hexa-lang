# 2026-05-20 — RFC 055 §12 P4+ follow-on v2 closure batch

> **TRIAGED 2026-05-20**: closure note acknowledged · no action required (3 v2 PRs #117/#121/#123 admin-merged; named follow-on follow-ons deferred to RFC 067-069 drafts)

**Status:** resolved-ssot (3 PRs landed on origin/main)

## Summary

The 3 named follow-on cycles from PR #114 (`rfc055-p4-followons`) — loop
unroll, Tensor-Core MMA scaffold, mixed-precision PTX types scaffold —
are all landed via v2 re-ports onto post-batch origin/main. The v1
predecessors (#110, #111, #112) were closed by the user when the
parallel sub-agent dispatch produced auto-merge corruption against the
#108 atomic_add + #109 warp_shuffle additive landings.

## PRs landed (admin-squash, branch deleted)

| PR | Title | lower_test ratchet | nvptx_target.hexa Δ |
|---|---|---|---|
| #117 | `_nvptx_unroll_pass` MVP (v2, on current main) | 9/9 → 11/11 | +358 lines |
| #121 | Tensor Core MMA scaffold (v2, on current main) | 11/11 → 12/12 | +63 lines |
| #123 | mixed-precision PTX types scaffold (v2) | 12/12 → 13/13 | +61 lines |

Cumulative new test cases: +4 (Cases 10, 11, 12, 13).
Cumulative `nvptx_target.hexa` additions: +482 lines (3 scaffold seams +
1 working pass + helpers).

## Quality gates (all 3 PRs)

- `mir.hexa` untouched → **F-RFC055-CPU-CODEGEN-UNTOUCHED** preserved.
- CPU codegen targets (`x86_64_linux` · `arm64_darwin` ·
  `thumbv7em_eabihf`) unchanged — verified via no-grep on those paths.
- `hexa_real parse` clean on both modified files per PR.
- `@D g_commit_push_deploy` — all 3 edit `compiler/` only; no
  `self/codegen_c2.hexa` change → no bootstrap regen required.
- Regression suite (`nvptx_emit_test` + `nvptx_vec_add_test` +
  `nvptx_gemm_test`) — PASS after each landing.

## Honest scope (`@D g3` — none of the 3 PRs claim a working impl)

- **Unroll** (#117): factor=2 MVP only; recognizes one CFG shape
  (3-block back-edge `header → body → header`). Multi-exit / nested
  / non-canonical loops fall through to honest passthrough.
- **MMA scaffold** (#121): mnemonic table + STMT_CALL recognition.
  MAKES REACHABLE (not impl): fragment register-bank allocation
  (kind="frag" → tile vector), `.shared` staging area, per-fragment
  dtypes (`.f16` vs `.f32` vs `.bf16`), `.row` vs `.col` orientation,
  tile-loop integration around the 16×16 MMA tile.
- **Mixed-precision scaffold** (#123): classifier + reg-decl side
  only. MIR layer that PRODUCES `add_f16/_bf16/_f32` opcodes is a
  future hir_to_mir.hexa cycle (per-Local precision tags). Body
  lowering for the new opcodes (`add.f16 %fh<d>, %fh<a>, %fh<b>`) is
  similarly deferred.

## Pattern lesson — surgical-port-over-cherry-pick

When a predecessor was closed for auto-merge corruption, don't replay
the cherry-pick. The pattern that closed 4 PRs cleanly:

1. `git diff <orig>^ <orig> -- <path>` per affected file — extract the
   predecessor's pure-additive diff.
2. Inspect the diff to identify the seams (function names, anchor
   lines, surrounding context).
3. Locate the matching seam on current main with `grep -n`. The seams
   moved because of intervening landings — e.g., `_nvptx_lower_stmt`
   STMT_CALL branch grew an `atomic_add` handler (#108) and a
   `warp_shuffle` handler (#109) before the MMA scaffold's wmma
   handler needed to land.
4. Hand-place the snippet by `Edit` tool with sufficient before/after
   context.
5. Renumber Case N to whatever's next on current main (e.g., Case 9 in
   the predecessor's view becomes Case 12 after intervening landings).
6. Parse-gate (`hexa_real parse <file>`) per edit.
7. Build + run the test binary + regression triple → all PASS gates.
8. Commit + push + `gh pr create --body-file <file>` + `gh pr merge
   --admin --squash --delete-branch -R dancinlab/hexa-lang`.

No 3-way merge ever runs. Each PR's branch is identical-prefix to
origin/main + the surgical addition.

## What remains (RFC 055 §12 P4+ follow-on follow-ons — deferred)

These are intentionally NOT landed in the closure batch — each requires
substantial new implementation work, not a port:

1. **Real WMMA emit** — fragment register-bank machinery (tile-vector
   allocation), `.shared` staging declarations, per-fragment dtype
   threading, row/col orientation handling, tile-loop integration.
   Pre-req: a follow-on cycle that scopes the C-side runtime support.
2. **Mixed-precision MIR layer** — `hir_to_mir.hexa` per-Local
   precision tags so the lowering can emit `add_f16/_bf16/_f32`
   opcodes from real source-level FP16/BF16/F32 expressions.
3. **Mixed-precision body lowering** — emit `add.f16 %fh<d>, %fh<a>,
   %fh<b>` etc. The current scaffold leaves the body as an honest
   055-P0-style stub.
4. **Unroll factor>2** — generalize the canonical 3-block back-edge
   matcher to factor=N (loop-carried dep analysis + register renaming
   per iteration unroll).
5. **Unroll non-canonical CFG shapes** — multi-exit, nested,
   while-with-early-return, etc. Each needs a distinct pattern match.

Each item above is a Shape-B cycle (RFC + multi-cycle implementation +
falsifier battery), not a Shape-A surgical port.

## Cross-link

- compiler/PLAN.md `2026-05-20 — RFC 055 §12 P4+ scaffold batch`
- gpu/SPEC.md §10 (deferred CFG shapes) + §12 P4+ closure plan
- PR #114 (`rfc055-p4-followons`) — the predecessor batch closure note
  that listed these 3 follow-ons by name.
