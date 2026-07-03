# L3-M0 measurement verdict — L2 own-lint + #4088 borrow-walker over real corpus
2026-07-03 · host aiden · main worktree `~/hx-step0` @ b3eb53aa7 (#4467 branch) · #4088 worktree `~/hx-m0` @ 18618c397 (feat/borrow-checker, merge of today's main — branch head moved 51bd86168→18618c397 upstream)

## Vehicle finding (blocking, discovered first)
**Neither lint is reachable from the default ship path.** `hexa build` / `hexa run` / `hexa typecheck` all route through the gen2 hexat frontend, which emits
`[warn] unknown attribute @own ... typo or unimplemented? (silently absorbed by generic fall-through)`
and implements neither HX3012 nor HX2007/HX2008. Both lints live only in the **native frontend** (`compiler/check/types.hexa`, `compiler/check/bind.hexa`), reachable via `build/aprime_cc` (invocation gotcha: argv normalization eats the FIRST `*.hexa` token as the script name — must call `aprime_cc dummy.hexa <file> ...`). All corpus numbers below are from the native frontend; via the gen2 default path every count is 0 for both flags on every file (measured).

## (1) L2 coverage — HEXA_OWN_LINT=1, HX3012 (native aprime_cc @ b3eb53aa7)
| file | rc | HX3012 |
|---|---|---|
| stdlib/argparse.hexa | 0 | 0 |
| stdlib/bigint.hexa | 0 | 0 |
| stdlib/bytes.hexa | 0 | 0 |
| stdlib/channel.hexa | 0 | 0 |
| stdlib/alloc/json.hexa | 0 | 0 |
| stdlib/alloc/collections.hexa | 1 | 0 |
| self/ast.hexa | 0 | 0 |
| self/attrs/own.hexa | 0 | 0 |
| compiler/check/types_test.hexa | 1 | 0 |
| compiler/check/bind.hexa | 0 | 0 |

Controls: synthetic probe (`@own let x = 5; let a = x; let b = x`) → flag ON = **1 diag** (`HexaWarn [HX3012] ... use of moved value 'x'`), flag OFF = 0. Gate verified live.

**Finding: corpus `@own` adoption = 0.** `grep -rln "@own" stdlib/ self/ compiler/` hits only: `self/attrs/own.hexa` (a DIFFERENT `@own` — doc-sections attr, string/comment mentions), `compiler/check/types_test.hexa` (synthetic AST test cases + comments), catalog/harness files. Zero `@own let` in real code. **Opt-in-annotation lint coverage on an unannotated corpus is 0 by design** — L2 cannot observe any defect class on today's corpus, and even a user who writes `@own` gets nothing on the default gen2 build path.

## (2) #4088 walker — HEXA_BORROW_CHECK=1, HX2007/HX2008 (aprime_cc built from 18618c397 in ~/hx-m0, `tool/build_aprime.sh` rc=0)
Counts are **diagnostics** (raw grep lines ÷ 2: each diag = warn line + explain line; shape verified on probes). Counts are per **build closure** (imports included — e.g. `stdlib/argparse.hexa` hits cite `stdlib/alloc/argparse.hexa`; the three compiler/check builds share the compiler-tree closure, so their counts overlap heavily).

| build target | rc | HX2007 | HX2008 |
|---|---|---|---|
| stdlib/argparse.hexa | 0 | 9 | 0 |
| stdlib/bigint.hexa | 0 | 39 | 0 |
| stdlib/bytes.hexa | 0 | 13 | 0 |
| stdlib/channel.hexa | 0 | 2 | 0 |
| stdlib/alloc/json.hexa | 0 | 12 | 0 |
| stdlib/alloc/collections.hexa | 1 | 31 | 0 |
| self/ast.hexa | 0 | 1 | 0 |
| self/attrs/own.hexa | 0 | 26 | 0 |
| compiler/check/types_test.hexa | 1 | 294 | 0 |
| compiler/check/bind.hexa | 0 | 260 | 0 |
| compiler/check/borrow_check_test.hexa | 0 | 265 | 0 |

Branch's own synthetic test: `hexa run compiler/check/borrow_check_test.hexa` PASS with gate OFF **and** ON (4-case contract holds). Flag-OFF control on corpus + probes: all 0 (default-path byteeq-neutrality holds).

### Probe matrix (aprime_cc_m0, gate ON)
| probe | code fires | verdict |
|---|---|---|
| tp_move_arr (`let b = a; consume(a)`) | HX2007 ×1 | designed positive, fires |
| tp_closure2 (mut captured by 2 closures) | HX2008 ×1 | designed positive, fires |
| fp_copy_int (`let a = x; let b = x`, int) | 0 | Copy control OK |
| fp_single_closure | 0 | control OK |
| **fp_callarg** (`foo(a)` then `a[0]`, obviously fine) | **HX2007 ×1** | **FALSE POSITIVE, measured** |
| **fp_arr_alias_read** (`let b = a; print(a[0]+b[1])`) | **HX2007 ×1** | **FALSE POSITIVE, measured** |
| hz_write_alias (`let b = a; b[0]=99; print(a[0])` — the REAL hazard class) | HX2007 ×1 | flagged, but **identically shaped** to the two FPs above |

### False-positive smell on real corpus: ~saturated
Spot-checked corpus hits are the fp_callarg pattern, not bugs:
- `stdlib/bigint.hexa:85` — `a[i] < b[i]` flagged because `_nlimb(a)`/`_nlimb(b)` (pure length helpers) at lines 79-80 count as by-value moves.
- `stdlib/alloc/argparse.hexa:64` — `s[i]` flagged after `len(s)` at line 61.

Root cause is the walker's documented over-approximation: **every bare-ident call-arg is treated as a by-value move**, in a language where arrays/strings are shared handles and calls do not invalidate the caller's binding. All flagged code is shipping, working stdlib/compiler code. HX2007 volume ≈950 diags across 11 closures with (in every inspected case) zero true defects → unusable as an advisory in current shape. HX2008 never fires on real corpus (pattern absent); it is observable only in synthetic tests.

## Honest conclusion — which defect classes are observable where
| defect class | real corpus | synthetic only | note |
|---|---|---|---|
| HX3012 @own use-after-move (L2) | **not observable** (adoption 0, by design) | yes (probe, types_test) | opt-in annotation nobody uses |
| HX2007 use-after-move (#4088) | fires, but **~100% FP** in inspected sample | yes (branch test PASS) | call-arg=move over-approx drowns everything |
| HX2008 double-mut-capture (#4088) | **0 hits** | yes | pattern absent from slice |
| write-through-alias surprise mutation (census §2/§4 "highest-value slice") | flagged **only coincidentally** — indistinguishable from benign read-alias FPs | — | **neither rung actually measures this class** |

**Go/no-go feed:** the M0 measurement says the existing rungs L2 + #4088-as-is leave the one valuable defect class (shared-handle write-aliasing) without a discriminating detector, while producing either zero signal (L2) or saturating noise (#4088 HX2007). A justified L3 start is therefore NOT "revive #4088 as-is" but requires, in order: (a) call-arg move classification fixed (pure-read args must not count as moves), (b) read/write discrimination on alias uses (census M3 MIR intra-block loan pass is the shape that can do this — it sees `STMT_ASSIGN`/store vs load), and (c) a decision on the two-frontend gap — any lint that lands only in `compiler/check/*` is invisible on the default `hexa build` path, so "advisory coverage" claims must name the vehicle.

## Reproduction (aiden)
- L2: `cd ~/hx-step0 && HEXA_OWN_LINT=1 ./build/aprime_cc self.hexa <file> --emit=asm -o /tmp/x.s`
- #4088: `cd ~/hx-m0 && HEXA_BORROW_CHECK=1 ./build/aprime_cc_m0 self.hexa <file> --emit=asm -o /tmp/x.s`
- Raw logs on aiden: `~/m0_phase1_results.txt`, `~/m0_phase1b_results.txt`, `~/m0_phase2_results.txt` (gen2-path all-zero run), `~/m0_phase2b_results.txt`, `/tmp/m0_*.log`; worktree `~/hx-m0` left in place (detached 18618c397, has fresh hexat + aprime_cc_m0).

## Not verified
- `~/hx-step0/build/aprime_cc` was prebuilt (today 18:20) — assumed to match the b3eb53aa7 checkout; not rebuilt.
- Per-file HX2007 counts include imported-module diags (build-closure granularity); no dedup across the 3 compiler/check closures.
- FP verdict is from exhaustive probe controls + spot-checks of corpus hits (bigint, argparse, bytes shape) — not a hand-audit of all ~950 diags; a true-positive hiding in the flood cannot be excluded.
- anima scratch repros (mentioned in census M0) not measured — slice was stdlib/self/compiler only.
- No compile-time/perf cost measured for either flag.
