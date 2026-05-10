# Blocker 1 — stage0 rebuild audit (NO-OP outcome)

> Audit by background agent #74 (2026-05-10). Conclusion: rebuild
> not needed; HEXA_F2 already PASS on deployed binary; ABI drift
> already resolved via SSOT codegen migration to `rt_*` prefix.

## TL;DR

- **HEXA_F2 PASS 20/20** on current `hexa.real` (May 7 build). No rebuild required.
- **ABI drift fixed long ago** — live SSOT codegen (`self/codegen_c2.hexa`) emits `rt_*` prefix; legacy v2 files (`codegen_c2_v2.c`, `lexer_v2.c`, `parser_v2.c`) are explicitly marked DEAD and do not enter the build chain.
- **orpheus 14 NATIVE_JSON sites unblocked** — gate condition (upstream HEXA_F2 PASS) is satisfied.
- **commit 2e144e58 selfhost-side fix is dormant** — exercised only when stage 1 native compiler self-hosts JSON. The deployed interpreter routes JSON through C builtins (`rt_json_*`), so the trk.27 fix in `runtime.c` (May 6) is what actually carries HEXA_F2.

## Evidence

### HEXA_F2 verifier output
```
__VERIFIER_HEXA_F2__ PASS N=20
```
Re-run: 2026-05-10 18:37
Witness: `/Users/ghost/core/orpheus/state/algo_research/verifiers/HEXA_F2_json_parse_parity_20260510T093614Z.jsonl`

### Deployed binaries
| Path | Size | Date | sha256 |
|------|------|------|--------|
| `/Users/ghost/core/hexa-lang/hexa.real` | 401840 | May 7 21:48 | `500e0183…3298c` |
| `/Users/ghost/core/hexa-lang/build/hexa_interp.real.real` | 4972848 | May 7 17:00 | `561fb84f…abd46` |

### Why HEXA_F2 already passes (without 2e144e58 selfhost fix)

The May 7 binary post-dates the **runtime.c trk.27 fix (May 6)** which uses `%.1f` for whole-valued floats. The deployed interp routes JSON through C builtins (`rt_json_*`), not through the selfhost path that commit `2e144e58` patched.

The selfhost-side fix in:
- `self/hexa_full.hexa::json_to_val`
- `self/rt/json.hexa::_jp_parse_number`

is **dormant** — exercised only by a future stage 1 rebuild that selfhosts JSON.

## ABI drift — already resolved

Audit of `self/codegen_c2.hexa::cg_string_sym()` lines 230–303 (live SSOT codegen):

| method | v2 (`_v` suffix) | C-direct (interp) | runtime symbol | status |
|---|---|---|---|---|
| to_upper | rt_str_to_upper_v | rt_str_to_upper | runtime.c:5227 | OK |
| to_lower | rt_str_to_lower_v | rt_str_to_lower | runtime.c:5234 | OK |
| trim | rt_str_trim_v | rt_str_trim | runtime.c | OK |
| pad_left | rt_str_pad_left_v | rt_str_pad_left | runtime_hi_gen.c | OK |
| pad_right | rt_str_pad_right_v | rt_str_pad_right | runtime_hi_gen.c | OK |
| repeat | rt_str_repeat_v | rt_str_repeat | runtime_hi_gen.c | OK |
| center | rt_str_center_v | rt_str_center | runtime_hi_gen.c | OK |
| lines | rt_str_lines_v | rt_str_lines | runtime_hi_gen.c | OK |
| starts_with | rt_str_starts_with_v | rt_str_starts_with | runtime.c | OK |
| ends_with | rt_str_ends_with_v | rt_str_ends_with | runtime.c | OK |
| contains | rt_str_contains_v | hexa_str_contains | runtime.c | OK |
| substring | rt_str_substring_v | hexa_str_substring | runtime.c | OK |
| replace | rt_str_replace_v | hexa_str_replace | runtime.c | OK |
| index_of | rt_str_index_of_v | hexa_str_index_of | runtime.c | OK |
| split | rt_str_split_v | hexa_str_split | runtime.c | OK |
| join | rt_str_join_v | hexa_str_join | runtime.c | OK |
| char_at | rt_str_char_at_v | hexa_str_char_at | runtime.c | OK |
| char_code_at | rt_str_char_code_at_v | hexa_str_char_code_at | runtime.c | OK |
| parse_int | rt_str_parse_int_v | hexa_str_parse_int | runtime.c | OK |
| parse_float | rt_str_parse_float_v | hexa_str_parse_float | runtime.c | OK |
| chars | rt_str_chars_v | hexa_str_chars | runtime.c | OK |

**Zero regression**. Stale `hexa_str_to_upper` references in `self/native/{lexer_v2,parser_v2,codegen_c2_v2}.c` are explicitly marked LEGACY (per `self/native/codegen_c2_v2.c.hexanoport`: "DO NOT EDIT. SUPERSEDED BY self/native/hexa_cc.c"). The live `self/native/hexa_cc.c` (May 9) emits `rt_str_to_upper` correctly. The "shims retired" note at `self/runtime.c:5226` confirms the migration completed.

## When a rebuild WOULD be needed

If a future change demands the May 10 selfhost-side JSON fix to fold into the deployed Mach-O (e.g., interp falls back to selfhost JSON path for some reason), invoke from the **main worktree** (not a Claude agent worktree):

```bash
cd /Users/ghost/core/hexa-lang
build/hexa_interp tool/rebuild_interp.hexa
```

Wait for any concurrent `self/hexa_full.hexa` edits to settle before rebuild.

## orpheus 14-site NATIVE_JSON migration: UNBLOCKED

Per `recovery/doc/json_native_migration_phase3_audit_2026_05_09.ai.md` §0 (orpheus side), the gate condition "upstream HEXA_F2 PASS" is satisfied with the deployed binary. Migration may proceed without further hexa-lang work.

## Decision

**No commit created** for Blocker 1 itself (no-op). This audit doc serves as the witness that the work was performed and the conclusion was "rebuild not needed at this time".
