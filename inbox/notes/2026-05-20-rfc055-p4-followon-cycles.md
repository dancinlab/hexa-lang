# RFC 055 §12 P4+ — named follow-on cycles (closed PRs #110/#111/#112)

## Status (2026-05-20)

§12 P4+ first-batch parallel dispatch (5 agents):

| Sub-slice | PR | Status |
|---|---|---|
| `gpu_atomic_add(addr, v)` | #108 | **MERGED** |
| `gpu_warp_shuffle(v, lane)` | #113 (v2; #109 superseded) | **MERGED** |
| `_nvptx_unroll_pass` MVP | #111 | **CLOSED → named follow-on** |
| Tensor Core MMA scaffold | #112 | **CLOSED → named follow-on** |
| Mixed-precision PTX types scaffold | #110 | **CLOSED → named follow-on** |

## Why #110/#111/#112 closed

All three agents completed their assigned work — the branches contain
correct, parse-clean, test-PASS implementations. But all 5 agents
branched off the same `origin/main` (`fb73c4b2`) in parallel; #108
atomic_add landing first added STMT_CALL handlers + a `_stmt_call_with_args`
helper + Case 8 to the same regions of `nvptx_target.hexa` and
`nvptx_lower_test.hexa` that #109/#110/#111/#112 also touched
additively. The lower_test.hexa file in particular grew 8+ overlapping
case-insert regions; the 3-way auto-merge produced syntactically
broken outputs (duplicate function definitions, intermixed fixture
bodies). Manual conflict resolution succeeded for #109 → #113 (warp
shuffle) but the remaining three would each need ~30-60 min of
careful manual placement.

Rather than burn the cycle budget on merge mechanics, the three PRs
are closed with the agent's content preserved on the branches. A
future cycle re-opens each as a v2 PR with proper rebase + manual
placement of the additions.

## Follow-on cycle handoff

For each closed PR, the agent's work lives on its branch:

- `rfc055-p4-unroll` (commit `c0a2b57b`) — `_nvptx_unroll_pass(mfn,
  factor)` opt-in pass that recognizes the canonical 3-block
  back-edge loop and clones the body N times with renumbered Locals.
  ~290 LoC across nvptx_target.hexa + nvptx_lower_test.hexa cases
  8 + 9. Closes the GEMM perf gap documented in PR #105 once wired
  into `_nvptx_lower_func`.

- `rfc055-p4-mma-scaffold` (commit `0cf0a5ba`) — `NVPTX_RKIND_FRAG`
  PReg kind + `_nvptx_wmma_mnemonic` table + STMT_CALL recognition
  for `gpu_wmma_load_a/load_b/mma/store_c`. Scaffold-only (emits
  `// scaffold` comment, not real wmma); makes the WMMA primitives
  reachable.

- `rfc055-p4-mixed-precision-scaffold` (commit `9f650776`) —
  `NVPTX_RKIND_{F16,BF16,F32}` constants + reg-name helpers
  (`%fh/%fb/%fs`) + classifier rules for `add_f16/add_bf16/add_f32`
  binop opcodes + reg-decl dispatch.

## Future cycle plan

Each closed PR's content is small + well-scoped. The v2 re-open is
manual but bounded:

1. Branch off current main (which now has #108 atomic_add + #113
   warp_shuffle).
2. Apply the agent's diff with manual placement — insert the new
   classifier rule + STMT_CALL arm + test case after the latest
   existing P4+ entries (rather than the original target line which
   has since shifted).
3. PR + admin-merge.

Estimated effort per PR: 15-30 min careful manual application + verify
9/9+ smoke tests still PASS. The substantive work is already done.

## Cross-references

- 16 RFC 055 PRs merged this session: #82, #85, #87, #90, #91, #92,
  #94, #96, #97, #98, #99, #100, #101, #105, #106, #108, #113.
- 4 PRs closed: #83 (auto-closed redundant; replaced by #85), #109
  (superseded by #113), #110/#111/#112 (named follow-on).
- `compiler/PLAN.md` — full RFC 055 progress log.
- This note: the §12 P4+ first-batch closure record.

Status: **resolved-ssot** — RFC 055 §12 P4+ first batch closed; 3
named follow-on cycles documented with branches preserved.
