# UNSHADOW — log

Append-only history sister of `UNSHADOW.md`. Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.

## 2026-05-29 — #2 EXTENSION (rt_str_* string prim inline) — 🔴 CLOSED-NEGATIVE (ABI 경계 차단)

#2 hexa_int 인라인을 STRING 런타임 prim 으로 확장 시도. 결론: **rt_str_\* prim 의 body 를
codegen 콜사이트에 인라인하는 것은 `runtime.h` export 경계로 인해 구조적으로 불가** —
publishable closed-negative. milestone flip 없음(확장 로그 only). verdict 원문:
`.verdicts/unshadow-2ext-rt-str-inline/F-UNSHADOW-2EXT-RT-STR-INLINE.txt`.

- [x] prim 선정: `rt_str_starts_with` (HexaVal 2-arg · PURE · 비할당 · LIVE). 후보 조사에서 발견한 함정:
      `str_len` free-fn 경로는 dead — `cg_rt_target()=="c"` 라 `rt_str_len_v`/`rt_str_*` 분기는 도달 불가이고,
      `str_len` 빌트인은 `hexa_str_len(HexaVal)`(컴파일 불가) 를 emit하는 latent 버그 경로. 실제 작동하는
      문자열-길이 경로는 `.len()` → `hexa_int(hexa_len(...))` 로 **이미** 직접 export 콜(추가 인라인 여지 없음).
- [x] codegen 구현: 3개 `.starts_with()` 콜사이트(self/codegen.hexa) 를 GCC statement-expression 인라인으로 교체.
      DOUBLE-EVAL 가드 적용 — 두 인자 모두 `__sw_s`/`__sw_p` 로 **단 한 번** let-bind (expr 인자라 필수).
- [x] g5 격리 byte-diff: base vs inline emitted C 가 **콜사이트 라인만** 상이(나머지 byte-identical). verbatim:
      `< ...rt_str_starts_with(__hexa_sl_0, __hexa_sl_1)...`
      `> ...({ HexaVal __sw_s = (__hexa_sl_0), __sw_p = (__hexa_sl_1); (!HX_IS_STR(__sw_s)||!HX_IS_STR(__sw_p))?0:(hxlcl_strncmp(HX_STR(__sw_s),HX_STR(__sw_p),HX_STRLEN(__sw_p))==0); })...`
- [x] single-eval 가드 검증: emitted C 에서 각 인자가 정확히 1회 let-bind 됨이 육안 확인. BASE single-eval 레퍼런스
      `make_str().starts_with("hello")` → `calls=1`. 가드 **설계는 정상** — 반증은 가드가 아니라 링크 경계.
- [x] **THE WALL** (반증): inline arm 링크 실패 — `Undefined symbols: "_HX_STRLEN", referenced from _u_main` (x8).
      근본원인: `grep -c "HX_STRLEN|hxlcl_strncmp" self/runtime.h` = **0**. runtime.h 는 `<string.h>` 도 미포함,
      HexaVal-레벨 ABI 함수만 export(`rt_str_starts_with` 자체는 runtime.h:257 export). `HX_IS_STR`/`HX_STR` 는
      export 되지만 `HX_STRLEN`/`hxlcl_strncmp` 는 runtime.c amalgam 내부에만 존재 → emitted 프로그램에서 참조 불가.
- [x] **정직한 finding (ruled-out axis)**: hexa_int 가 성공한 이유 = box-literal `((HexaVal){.tag=TAG_INT,.i=N})`
      이 runtime.h-가시 struct 레이아웃 + 리터럴만 사용(내부 헬퍼 0). 모든 의미있는 rt_str_\* body 는 내부 스칼라
      헬퍼(HX_STRLEN/strncmp)를 건드려 순수-레이아웃 인라인 형태가 없음. 인라인하려면 (a) runtime.h 에 내부
      헬퍼 export(=UNSHADOW 가 없애려는 경계를 도로 넓힘) 또는 (b) 전역 emit 프리앰블에 `#include <string.h>`
      추가(콜사이트 surgical 인라인 아님 + strncmp/strlen 매크로-shadow 충돌 재유발) 필요. 둘 다 스코프 밖 → CLOSED.
- [x] 정확성 우선: silent miscompile 위험 회피 위해 codegen 변경 **revert**(인라인은 `_HX_STRLEN` 미정의로 빌드 자체 실패).
      bench/log/verdict 만 commit. UNSHADOW.md cross-layer milestone **미변경**(extension).

## 2026-05-29T00:00Z — M1 harness

- [x] A/B micro-bench 측정대 실측 완료 — `mini` (macOS arm64) 단일 호스트, 두 arm back-to-back.
- [x] arm A = `HEXA_BACKEND=native` (aprime_cc → arm64 asm) · arm B = clang -O2 (기본 C 경로) · 둘 다 동일 `self/runtime.c` 링크.
- [x] g5 정확성 게이트: 5/5 워크로드 stdout byte-diff = **IDENTICAL** (native asm 정수 의미론 ≡ clang -O2 C).
- [x] 5/5 측정 (warmup 3 · iters 7 · min_ms 기준): sieve −25.0% · fib −39.0% · hash −61.1% · collatz −10.2% · mixmul −39.6%.
- [x] **정직한 finding**: native backend 는 정확성 PASS, 속도는 5/5 전부 clang -O2 에 진다. scalar/integer hot loop 에서 clang -O2 는 roofline 근접 — 예상된 baseline, 함정 아님. 분기-bound(collatz) 일수록 격차 최소(−10.2%) = 향후 추월 단서.
- [x] 결과 fold: `UNSHADOW.bench.md` §baseline 표 + §정직한 해석 채움. 원시 JSONL verbatim 보존(mini `state/perf/unshadow_ab.jsonl`).
- [x] M1 milestone flip (`UNSHADOW.md`). cross-layer 인라인 milestone 은 sibling 브랜치 소유 — 미변경.

## 2026-05-29 — #2 cross-layer inline pilot (hexa_int integer-literal box) — 🟢 MEASURED Δ ≈ 28%

Pilot prim: `hexa_int(N)` — the small-int box (highest-frequency runtime primitive;
emitted for every integer literal). One-line codegen change in `self/codegen.hexa`
`gen2_expr` IntLit case:

```
- if k == "IntLit" { return "hexa_int(" + node.value + ")" }
+ if k == "IntLit" { return "((HexaVal){.tag=TAG_INT,.i=(" + node.value + ")})" }
```

Lowers an integer literal to a C compound literal instead of an out-of-line
`hexa_int()` call across the precompiled-runtime.o C-ABI boundary. DOUBLE-EVAL
SAFE: `node.value` is a pure literal token (never a side-effecting expression),
so the single textual expansion is the only evaluation — no fold-shadow /
double-eval class reintroduced. Byte-equivalent to runtime.c hexa_int(), which
returns exactly `{ .tag = TAG_INT, .i = n }`. No 4-surface registration needed
(no new builtin — pure inlining of an existing lowering).

- [x] correctness (g5): corpus (fib/while/array/arith) — base `hexa_int(N)` arm vs
      inlined arm → program output BYTE-IDENTICAL, same md5 `5dd08ae3b866d834b822eea5d28c0ffa`.
- [x] isolation: hexat_base vs hexat_mine emitted C on the corpus AND on codegen.hexa
      itself differs ONLY at IntLit sites (the sole non-IntLit diff lines are `}` rows
      shifted by the multi-token expansion = context noise, identical content).
- [x] determinism (fixpoint): hexat_mine ∘ codegen.hexa run twice → byte-identical.
- [x] perf (host=pool mini, macOS arm64; 1M-iter hot loop × 200 rounds + 3 warmup;
      clang -O2 compile-then-link vs SAME runtime.o; 5 interleaved trials):

      | arm                | wall (s, 5 trials)            | best  |
      |--------------------|-------------------------------|-------|
      | base (hexa_int)    | 1.83 1.84 1.83 1.83 1.83      | 1.83  |
      | mine (inlined)     | 1.31 1.32 1.31 1.31 1.27      | 1.27  |

      Δ ≈ 28% faster. Assembly (`-O2 -S`) hot() loop: `bl _hexa_int` call
      instructions 13 (base) → 5 (mine); whole file 23 → 8. The opaque C-ABI call
      blocked clang's const-fold; inlining the compound literal unblocked it.

Honesty (roofline): a REAL win, not a manufactured one. NOT redundant-vs-LTO — the
runtime is a precompiled `runtime.o` (no LTO / no cross-TU visibility), so
`hexa_int` was a genuine opaque out-of-line call. NOT bandwidth-bound — the
workload is call-overhead + box-construction bound, exactly the boundary the
UNSHADOW thesis predicts ownership unlocks. The win is the boundary removal
enabling const-fold, per UNSHADOW.easy.md.

Build note: `hexa_cc.c` is now a B9 generated artifact (`hexa_cc.c.hexanoport`
+ gitignored `.new`), NOT a committed file — the `.hexa` emitter is the only
SSOT to commit. Regen pipeline `hexa cc --regen` requires `$HEXA_LANG/self/native/
hexa_cc.c` to exist for `resolve_hxroot()` to pick the build tree (seed it from the
installed package first). The merged-smoke `compiled=no` is a PRE-EXISTING merge MVP
limitation (baseline shows it too) — verification used the DIRECT compile-then-link
path against the build tree's `.new`, not the merged smoke.

