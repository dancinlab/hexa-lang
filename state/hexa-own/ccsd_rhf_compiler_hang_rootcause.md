# ccsd_rhf.hexa 컴파일러 hang (>2h17m) 근인 — workflow wf_6bdb8220 (3-agent) + ★실증정정

## ★★ CORRECTION (empirical·ghost sample) — 정적 3-agent 근인 FALSIFIED ★★
**실측(ghost v0.741.7·자식 hexad sample·2026-07-12)**: hang은 hexa 자체 lowering이 **아니다**. busy 자식 hexad hot frame(8760/8760 샘플):
```
main → cmd_build → _hexa_clang_capped → hexa_exec → hexa_popen_sh → poll/__wait4
```
= **`_hexa_clang_capped`(self/main.hexa:3013·:3924·:3975)가 clang(외부 C컴파일러)을 popen하고 대기**. 즉 근인 = **C-transpile 경로의 clang이 emitted-C(거대 ccrhf_iterate=456줄 1함수→거대 단일 C함수)에서 옵티마이저 blowup** (>2h·aiden 23.8%CPU=clang grind). `_hexa_clang_capped`는 **동시성 cap(cap_n=2 토큰)일 뿐 wall-clock timeout 無**("normal clang 3-4s" 가정)→clang이 안 끝나면 hexa가 영원히 poll 대기.

- **아래 3-agent 정적분석(HIR→MIR `_mir_lookup` append-only `_lr_bindings` O(N²))은 PLAUSIBLE했으나 틀림** — 정적으로 hexa lowering을 지목했지만 실측 sample은 clang을 지목. measure-first/verdict-integrity 승(sample 대상 프로세스 특정: 부모 hexa run=poll drain-wait, 자식 hexad=_hexa_clang_capped→clang wait).
- **비회귀**: ghost v0.741.7도 hang(최근 .741→.753 회귀 아님·longstanding).
- **fix 방향(정정됨)**: ①`_hexa_clang_capped`에 wall-clock timeout 추가(clang N초 초과 kill·census #4901과 별개로 컴파일러 자체 가드) ②거대 emitted-C 단일함수 -O0/분할 ③**진짜 종점=native-emit로 clang 제거**(프런티어 axis-③ L2 目). 이전 "bindings O(1) index" fix는 **무효**(잘못된 근인).
- **프런티어 연결**: 이 hang은 C-transpile fallback(hexa_cc→clang)의 병리 = 자기호스트 DONE ①(no hexa_cc.c)·③(no clang)이 제거하려는 바로 그것.

---
## (아래는 실측 前 3-agent 정적 가설 — clang 실측으로 FALSIFIED·기록 보존)

**증상**: `hexa run compiler/main.hexa --emit=obj stdlib/qforge/atoms/ccsd_rhf.hexa` HANG — 2h17m·23.8%CPU 단일스레드(OOM 아님·idle 아님)·v0.753.0. 타 코퍼스 파일은 ~1-2s, 이 파일만 wedge. #4901이 census 하니스에 per-file timeout(mitigation)만 착지, 근인은 미규명이었음.

**근인 (3-agent 수렴·file:line)**:
- **trigger construct** = `ccrhf_iterate` (ccsd_rhf.hexa:427·456줄 단일함수·409 stmt·86 local·90 while·6중첩·300+ 재대입). CCSD가 monster expression 아니라 **loop-dense 스칼라** 코드(N⁶/N⁷ tensor contraction). @cite=0(citation phase 배제).
- **primary O(N²)** = HIR→MIR lowering. `_mir_lookup`(hir_to_mir.hexa:3582)=append-only `_lr_bindings` tail→head 선형스캔+문자열비교. `_lr_bindings`는 never-pop(:3569 _rebind·:3573)이라 let/재대입마다 push→함수 내 수천 개. 참조마다 O(bindings)·재대입마다 `_lr_locals` 스캔(:5828)+`_lr_type_of_op`(:316) = O(refs×bindings). boxed-struct 배열이라 스텝=heap 포인터체이스(캐시미스)→23.8%CPU 메모리지연-bound.
- **⚠️ magnitude 뉘앙스(A3)**: 936줄/16fn에 2h17m은 순수 O(N²)(수천 bindings≈초)보다 큼 → **worse-than-quadratic/지수** 의심. 6중첩 loop의 per-body super-linear site(CFG block/edge 또는 nested lowering 내 per-stmt heapify) 가능. deep-fn family(#3709~3880·spine-deep shape)와 **다른 입력형(loop-dense)** = 미도달 site, 회귀 아닌 신규.

**fix 전 필수 = 실증 확정**(measure-first·verdict-integrity): `HEXA_CG_PROFILE=1`로 어느 phase가 안 찍히나(예측=lower_hir)·`sample <pid>`로 hot frame(예측=_mir_lookup/:3582 or :5828/:316) + N-스케일링(O(N²) vs 지수 판별). ghost(darwin·arch-무관 blowup) repro 진행중.

**fix 방향(확정 후)**: `_lr_bindings` name→latest-index 맵으로 O(1) lookup(bsearch #3952/#3956 동형). 단 magnitude가 지수면 append-only 자체(누적 재-lowering)를 봐야 함 — 확정 데이터가 fix 형태 결정.

**gold-standard 함의**: 실 워크로드(양자화학 CCSD) 파일이 컴파일 불가 = perf gold-standard 위반. 규명+fix가 프런티어 가치.

## 3-agent 원본 분석

### file-shape
FILE-SHAPE CHARACTERIZATION — stdlib/qforge/atoms/ccsd_rhf.hexa (read from origin/main)

OVERALL
- 936 LOC; 23 fns; 1 struct (CCRhfInts, 12 fields).
- 142 `while` loops total; 0 `match` arms; 0 @cite/@verify/@grace annotations; 0 large data literals (every array is `let mut x:[float]=[]` then push-filled — no huge inline literal anywhere); no long binop chain (max 15 arithmetic ops on any single line, at L812 — trivial). String literals: only `use` imports + comments.
- This is NOT the classic "one giant flat tensor-contraction expression" CCSD. It is a SCALAR LOOP-BASED CCSD: the pathology is depth+size of nested `while` blocks and live-local count inside ONE huge function, not a monster expression.
- Note: the @cite/citation phase (HX8004) can be RULED OUT — there are 0 annotations and that phase refuses/errors fast, it does not spin.

TOP 3 SUSPECT CONSTRUCTS (ranked by size/pathology)

1. fn ccrhf_iterate  (L427–881) — THE MONSTER, dominant suspect
   - 455 LOC / 409 statements / 90 `while` loops / 86 `let` local decls, all in ONE flat function body.
   - Loop-nest depth = 6 (while-indent histogram tops out at level 6, 9 loops at indent-24).
   - ~16 large array-valued intermediates (tau, taut, Fae, Fmi, Fme, Wmnij, Wmbej, Wmbje, t1n, Zmbij, ladder, R, t2n …) plus heavily-reused scalar loop vars (i,j,a,b,m,nn,e,f,f2,q,z,v), nearly all live across the entire 400-stmt body.
   - This is the exact input shape for a per-function pass that is super-linear in (statements × live-locals) or (interference-graph vars²) — liveness / borrow-region / register-allocation / SSA. Matches the observed profile: steady 23.8% single-thread grind, no OOM, 2h+. Aligns with the known "gen3 deep-fn O(n²)" compiler pathology in memory. Returns `[any]` (L880) — minor boxing, not the driver.

2. The 6-deep `while`-nest regions INSIDE ccrhf_iterate — the nesting-depth trigger
   - Deepest/widest nests (each i>j>a>b + inner loops = 6 levels): T2 unsymmetrized-R pass L773–844 (~72 LOC, one nest, indent-24 body), Wmbej L582–616, Wmbje L621–657, Wmnij L545–573, Zmbij L738–763.
   - Six sibling 6-deep nests give a very deep+wide scope/region tree. A scope-resolution or borrow-region pass that is super-linear in block-nesting depth (or that re-walks the enclosing region per inner statement) explodes here specifically.

3. fn ccrhf_build_ints  (L102–257) — second-largest fn, bisection control
   - 156 LOC / 149 statements / 32 `while` loops (8 separate 4-deep occ/virt nests) / 35 locals.
   - Same pathology class at ~1/3 scale and depth-4 (vs depth-6). Useful oracle: if a trimmed compile of this fn alone also slows super-linearly, it confirms the per-function-size quadratic; if only ccrhf_iterate wedges, the trigger is the depth-6 / 86-local combination unique to fn #1.

CONCLUSION: the blowup feeds on fn ccrhf_iterate — a single 409-statement, 86-local, 6-deep-loop function. The pathological axis is function SIZE × LIVE-LOCAL count (and secondarily loop-nest DEPTH), not any literal, expression chain, match, or citation construct. Bisect by compiling ccrhf_iterate in isolation, then halving its body (drop the T2-R pass L773–844 / the W-intermediate blocks) to confirm super-linear scaling in statement/local count.
### phase-complexity
I have the complete localization. All evidence points to one phase and mechanism.

## PHASE-COMPLEXITY LOCALIZATION — `ccrhf_iterate` triggers O(n²) in HIR→MIR lowering

### The trigger shape (input side)
`stdlib/qforge/atoms/ccsd_rhf.hexa` has 16 fns, but **one monster function**: `pub fn ccrhf_iterate(...)` at **line 427**, spanning ~427→883 (~456 lines, the entire CCSD update), with while-loops nested up to 6 deep and ~300+ scalar reassignments (`v = v + …`, `Fbe = Fbe - …`, etc.). Every other corpus file has small per-function bodies. The accumulators that blow up are **reset per-function** (`_lr_ctx_clear`, hir_to_mir.hexa:3172 → `_lr_bindings = []` / `_lr_locals = []`), so N is bounded by the *single largest function* — and `ccrhf_iterate` is an order of magnitude larger than anything in the fast-compiling corpus. That is exactly why only this file wedges.

### RANKED (phase × mechanism) hypotheses

**#1 (dominant) — `lower_hir` (HIR→MIR, `compiler/lower/hir_to_mir.hexa`): append-only `_lr_bindings`/`_lr_locals` + per-reference linear scans → O(N²), memory-latency-bound.**
- `_mir_lookup` (**hir_to_mir.hexa:3582**) is a tail-to-head **linear scan over `_lr_bindings`** doing a **string compare** (`_lr_bindings[i].name == name`) per entry.
- `_lr_bindings` is **append-only and never popped** — `_bind`/`_rebind` (3565/3569) `.push` a new shadowing entry on **every `let` and every SSA reassignment**; the comment at 3573 says "Nothing ever pops `_lr_bindings`". So within `ccrhf_iterate` it grows monotonically to thousands (every temp + every reassignment).
- Every variable *reference* → one `_mir_lookup` (O(bindings)); every *assignment* → `_mir_lookup` **plus** a second scan of `_lr_locals` at **hir_to_mir.hexa:5828** (`while li < len(_lr_locals) { if _lr_locals[li].id == existing … }`).
- Total = O(refs × bindings) = **O(N²)** where N = per-fn binding/local count. Because `_lr_bindings`/`_lr_locals` are **arrays of boxed structs**, each scan step is a heap pointer-chase (cache miss) — consistent with the observed **23.8% CPU** (memory-latency-bound, not compute-pegged), and enough per-access cost to push N² into the multi-hour range.

**#1b (same phase, additional multiplier)** — `_lr_type_of_op` (**hir_to_mir.hexa:316**), another full linear scan of `_lr_locals`, is invoked via `_lr_operand_provably_i64` on the reassign type-check (5848/5850) and, **when `_arrpk_fuse_enabled()` is on** (element-pack/unbox lane), on the general binop path (**4318**). If that gate is on, every arithmetic binop in the monster fn adds another O(locals) scan → compounds the constant (still O(N²), larger factor). Note the deep-spine O(N²) sites in this same file (4194) and in ast_to_hir (1965/2045) are already FIXED, so those are not the culprit.

**#2 (less likely) — `lower_ast_to_hir` (AST→HIR).** The deep-spine collect/flatten quadratics here were killed in r3 (ast_to_hir.hexa:1965, 2045). Only a suspect if the profile shows this mark never returning.

**#3 (check-if-frontend) — `resolve`(S1)/`type_check`(S3).** A per-node name/type rescan could be O(N²) on a huge fn; lower prior than #1. Ruled in/out purely by which profile mark stalls.

Regalloc in `compiler/codegen/x86_64_linux.hexa` is **NOT** the suspect: `_x86_compute_live_ranges` (389) was made O(1)-per-id via `id2slot` (#3712), intervals are uniform, and per-operand lookups (`_x86_rm_idx`:988) are O(1) direct-indexed. The old x86 per-stmt heapify O(N²) (1060) was also fixed.

### CONFIRM (exact command)
The compiler already ships a per-phase probe (main.hexa:399–657, #4794 sub-marks). Run with the profile env and watch the LAST `CG_PROFILE` row printed to stderr before it hangs:

```
HEXA_CG_PROFILE=1 hexa run compiler/main.hexa --emit=obj --target=x86_64-linux-gnu stdlib/qforge/atoms/ccsd_rhf.hexa
```

Marks fire in this order (main.hexa): `lex → parse → atlas_load → resolve → bind → type_check → unit_check → lower_ast_to_hir → lower_hir → mir_opt → codegen → emit_asm`. The phase whose row **never prints** is the blowup:
- prediction: all frontend rows print fast, then **`lower_hir` never prints** → confirms #1 (HIR→MIR).
- if `lower_ast_to_hir` never prints → #2; if `resolve`/`type_check` never prints → #3.

To pin the exact loop within `lower_hir`, attach `sample <pid> 5` (or `lldb`/`perf`) to the wedged process — the hot frame will be `_mir_lookup` / the `_lr_locals` scan at hir_to_mir.hexa **3582 / 5828 / 316**.

### Suspect file:line summary
- Primary O(n²): `compiler/lower/hir_to_mir.hexa:3582` (`_mir_lookup` scan of append-only `_lr_bindings`), amplified by `:5828` (assign→`_lr_locals` scan) and `:316` (`_lr_type_of_op` scan), all keyed off `_lr_bindings` being append-only (`:3569` `_rebind`, no pop).
- Trigger construct: `stdlib/qforge/atoms/ccsd_rhf.hexa:427` `ccrhf_iterate` (~456-line single fn, ~300+ reassignments, 6-deep nested loops).
### known-pathology
## VERDICT: NOVEL (undiagnosed) — a near-miss on the known deep-fn family, but the wrong input shape

### The hang is RECORDED but its root cause is explicitly DEFERRED (not diagnosed)
The exact event is already tracked in three places on `origin/main`, all pointing at the same file/measurement:
- **Commit `0cebce05c` — `#4901` "fix(L5 census): per-file timeout guard vs compiler-hang wedge"**. It quotes your numbers verbatim (`>2h17m @23.8%CPU v0.753.0 단일스레드 blowup`) and ships **only a mitigation** — a 90s per-file `timeout` wrapper (`CENSUS_FILE_TIMEOUT`) in `state/hexa-own/l5_b4_precensus_run.sh` that SKIPs the file — explicitly stating **`ccsd_rhf.hexa hang=별도 컴파일러 perf 결함(own 조사)`** = a separate, uninvestigated compiler-perf defect.
- **`ARCHITECTURE.json` node at line 5595** (L5 B4 gate spec) records it as an `infra-wall-noneval` isolated from the borrow-check FP count.
- The commit also touched `ING.jsonl`.

So there is **no prior root-cause analysis** to inherit — only a "route around it" guard.

### It does NOT match the known compiler-blowup family (checked all of it)
The only recorded compile-time blowup pathology is the **gen3 deep-fn O(n²)** family:
- `#3709`/`#3711` deep left-spine SIGSEGV→iterative flatten (`compiler/lower/ast_to_hir.hexa:1829-1990` `_hir_lower_binop_spine_deep`)
- `#3717` LIR-buffer + HExpr-literal spine (`compiler/codegen/x86_64_linux.hexa:1057-1076`)
- `#3712` regalloc `id2idx` O(locals²)→O(1) (`x86_64_linux.hexa:241,351`)
- `#3877` spine-collection O(n²)→O(n) r3; `#3880` parser left-spine `HEXA_PARSER_SPINE_NOSTAT` (r4)
- self-emit-oom round-2 CFG `O(stmts·blocks)`/`O(edges·blocks)` (`compiler/lower/hir_to_mir.hexa:3382,3432`)
- `bsearch` `#3952`/`#3956` — this is the **runtime** `HEXA_ARENA_BLOCK_BSEARCH` arena-block index, a run-time speedup, **not** a compile-time path. Irrelevant to this hang.

**Every member of that family is keyed to one input shape: a single MEGA-FUNCTION with thousands of chained binops / thousands of locals** — the "7000-binop / 7000-local `runtime_cuda_emit`" and "depth-1500 synthetic" (see the comments verbatim in `x86_64_linux.hexa:241-243, 351-353, 1057-1066`). That shape comes from self-hosting the compiler's own generated runtime.

`ccsd_rhf.hexa` is the **opposite shape** (measured on `origin/main`):
- 936 LOC, **16 functions**, 179 total `let/mut` — not thousands of locals per fn
- **max ~8 `+` per line** (worst line 812) — nowhere near a deep binop spine; the deep-fn pathology needs ~1500–7000-deep chains
- **145 `for`/`while`** — the dominant feature is deeply *nested* loops (N⁶/N⁷ tensor contractions with index arithmetic like `eri[((p*n+q)*n+r)*n+s]`), not deep *expressions*

The deep-fn fixes already compile a 7000-binop single function in practical time; a 936-line/16-fn file taking >2h17m is disproportionate. Even the residual guarded CFG quadratic (`_push_stmt_to`/`_add_edge`) is only O(stmts·blocks) ≈ 936² ≈ 1M ops = milliseconds, not 2 hours. The magnitude argues for **worse-than-quadratic (likely exponential)** behavior — which the deep-fn family never exhibited (they were all clean O(n²) with byte-eq-neutral fixes). No `ARCHITECTURE.json`/log node records any exponential, monomorphization, type-inference, or loop-nesting compile blowup.

### The one real connection (the meta-pattern, not a specific recurrence)
The deep-fn campaign has a documented "**peel the next quadratic**" cadence — each fix exposed the next site (`#3712` regalloc → `#3717` LIR buffer → self-emit-oom CFG). A *new input shape* (loop-dense rather than spine-deep) is exactly what exposes a not-yet-peeled super-linear/super-quadratic site. So this is best framed as: **same pipeline (native `--emit=obj` lower→codegen), new un-encountered input shape, a site the deep-fn work never reached** — not a regression of any fixed bug.

### Bottom line for the perf investigation
- Prior art gives you the **method and the likely locus** (the `--emit=obj` lower/codegen pipeline: `ast_to_hir` → `hir_to_mir` → `x86_64_linux`), plus the profiling precedent: the deep-fn work found ">80% wall in `hexa_val_heapify` under codegen" via `HEXA_CG_PROFILE` (`compiler/codegen/x86_64_linux.hexa:1057-1066`; `#4483` wired `HEXA_CG_PROFILE` capture).
- It does **not** give you a fix — no existing patch covers this shape, and the flag levers (`HEXA_PARSER_SPINE_NOSTAT` default-OFF, `HEXA_ARENA_BLOCK_BSEARCH`) are irrelevant here (no deep spine; bsearch is runtime).
- Recommended first cut: bisect the phase with `HEXA_CG_PROFILE`, and since it's loop-dense, suspect a per-loop-body super-linear site (CFG block/edge construction or a per-statement whole-structure heapify inside nested lowering) rather than the spine path.

Relevant files (all `origin/main`): `stdlib/qforge/atoms/ccsd_rhf.hexa`, `state/hexa-own/l5_b4_precensus_run.sh`, `compiler/lower/ast_to_hir.hexa` (1829-1990), `compiler/lower/hir_to_mir.hexa` (368, 3382, 3432, 4194), `compiler/codegen/x86_64_linux.hexa` (241-243, 351-353, 1057-1076).