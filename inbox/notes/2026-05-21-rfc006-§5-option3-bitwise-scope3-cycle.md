# RFC 006 §5 Option III — bitwise scope-3 cycle (2026-05-21)

**Branch** : `rfc006-option3-bitwise-scope-3`
**Code commit** (bundled WIP carry) : `c99cadf6`
**Approach** : Iteration B (per-bit cells only, multi-bit base wire kept
              registered as alias; no buf chain from per-bit pieces back).

## Scope (user-strict, 2026-05-21)

Only 3 cells in `_rv_elab_expr`: `$xor` / `$and` / `$or`. All other cell
types (`$xnor`, `$not`, `$mux`, `$add`, `$sub`, `$eq`, `$lt`, …) deferred.

## Change (single file)

`stdlib/kernels/logic_synth/read_verilog.hexa` — `_rv_elab_expr`,
~30 lines: when `op` is `^`/`&`/`|` and `ww > 1`, emit W per-bit cells
with width-1 `<wn>__b<k>` Y wires (broadcast scalars, blast multi-bit
A/B). The multi-bit `<wn>` wire is still registered at width=ww so
downstream `abc_emit_blif` connect-emit (L327-352) propagates the
multi-bit alias by emitting W buf rows per sink.

Plus T80 falsifier + T77 re-spec (pre-Option III asserted single cell
+ Y-width=W; Option III flips that to W cells + per-cell Y-width=1).

## Selftest count (mini, arm64 build pool)

- `read_verilog.hexa` → **85/85 PASS** (was 79/79; +6 new tests in
  this worktree — T78 / T79 / T80)
- `passes.hexa`       → **37/37 PASS**
- `abc_map.hexa`      → **9/9 PASS** (D18 fail-loud, abc absent OK
  in selftest path)

## §5 area measurement (mini)

- d4 = **unmeasurable** — ABC aborts (`Abc_ObjAddFanin` assertion at
  `abcFanio.c:92`) reading the input BLIF. Output BLIF = 0 bytes.
  Baseline (without Option III change) → SAME abort. The crash is
  pre-existing in this branch's BLIF generator, NOT caused by
  Option III.
- d6 = unmeasurable (same path, never reached on this run).
- BLIF byte-identity: d4 in.blif md5 baseline `bbbfcb5c9b24e8422600c179d5aad9b3`
  = post-fix md5 `bbbfcb5c9b24e8422600c179d5aad9b3` (BYTE-IDENTICAL).
- `_const0_` count: 0 / 0 (no out.blif produced in either run; the
  previous note's 1638 was from an earlier source state where ABC
  did not abort).

## Movement?

**ZERO measurable movement on router_d4 / router_d6.** Root cause is
honest: `grep -E '[^&]&[^&=]|[^|]\|[^|=]|\\^'` on both routers
returns ZERO bitwise hits. The benchmark uses `&&` / `!` exclusively
(logical reduce, NOT in Option III scope). The 3-cell-scope change
cannot move the §5 area on this benchmark; further cycles must
broaden scope to `$add` / `$mod` / `$mux` / `$logic_and` / `$logic_not`
(the cell types passes.hexa already has lowering helpers for) or
attack the pre-existing ABC-abort regression first.

## Honest 1-sentence diagnosis (deliverable #8)

Option III scope-3 fired and selftests confirm the new code path
(T80a sees 8 `$xor` cells with `__b0..__b7` Y wires) but the
benchmark Verilog uses zero bitwise operators, so the change is a
no-op on router_d4/d6 — and the ABC abort blocking §5 area
measurement is an orthogonal pre-existing regression.

## Hazards observed

- Shared main worktree: a background WIP commit (`c99cadf6`) auto-
  bundled my edit with ~160 other in-flight changes from parallel
  sessions. Per `feedback_hexa_lang_shared_worktree_branch_hazard.md`
  + `feedback_pr_ceremony_freeze_window.md`. Created feature branch
  `rfc006-option3-bitwise-scope-3` to isolate; commit content
  remains the bundled WIP. NOT pushed.
- `timeout` not available on mini arm64 Mac shell; use direct
  invocation. `which abc` returns "abc not found" in default ssh
  PATH on mini — must `export PATH=/opt/homebrew/bin:$PATH` for
  abc to resolve.
- inbox/fires/ exclude saved minutes of rsync but `.claude/worktrees/`
  contains 22 GB of cross-session jsonl logs that DO get rsynced
  unless excluded. Recommend extending rsync excludes to
  `.claude/worktrees/`.
