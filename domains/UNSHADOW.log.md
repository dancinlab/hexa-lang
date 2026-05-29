# UNSHADOW — log

Append-only history sister of `UNSHADOW.md`. Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.

## 2026-05-29T02:00Z — #3 arena-reclaim 측정 (UNSHADOW item #3) — 🟢 MEASURED Δ (RSS −40% · wall −26%)

워크로드 = `self/bench/arena_reclaim_bench.hexa` (+ `bench_str` 순수 string churn 변형).
leaf fn `churn(seed)` 가 호출마다 64 transient concat string 을 만들고 int 만 반환 — 전부 dead.
생성 C 에서 `__hexa_fn_arena_enter()`/`__hexa_fn_arena_return(acc)` emit 확인.

- [x] **scope 확인**: 새 allocator 안 만듦. 기존 region-reclaim opt-in 측정 = `HEXA_VAL_ARENA`(per-fn scope rewind, default ON · `runtime_core_emit.hexa` L3831/L3933/L3755) + `HEXA_STR_ARENA`(bump concat, default ON). 별도 dormant opt-in `__HEXA_ARENA_RETURN_REGION_ON__`(region returns) 는 static int=0, env 미배선 = 휴면.
- [x] **peak RSS (주, N=400k, `/usr/bin/time -l`, raw 바이너리)**: VAL=1·STR=def **3.73GB** (−39.7%) · VAL=0·STR=1 4.97GB · STR=0 6.19GB · fully-off 6.19GB.
- [x] **wall (부, best-of-3 real)**: default 9.24s (−26.4%) · VAL=0 11.08s · VAL=1·STR=0 11.73s · fully-off 12.56s.
- [x] **scaling**: peak RSS 가 N 에 정확히 선형 (100k/200k/400k = 1×/2×/4×, 두 모드 모두) · arena-ON/OFF 비 ≈ 0.75 고정.
- [x] **g5 byte-diff**: 4 config (VAL∈{0,1}×STR∈{0,1}) stdout 전부 IDENTICAL (`total=347288960`). VERDICT verbatim = `IDENTICAL across all 4 reclaim configs`.
- [x] **정직한 finding**: reclaim 은 real win (RSS −40% + wall −26%, byte-clean) 이지만 peak RSS 를 *bound* 하지 못함 — 세 config 다 N 에 선형. rewind 가 빈 블록을 재사용은 하되 OS 반납 안 함(블록 free 경로 부재, `hexa_arena_destroy` 미정의) + leaf 반환 후 살아남는 string retention 경로 잔존 시사. constant-factor win 이지 size-class 닫힘 아님.
- [x] **분리한 blocker (후속)**: peak RSS bound = (a) rewind 시 빈 trailing 블록 OS 반납 opt-in(`HEXA_ARENA_RELEASE_BLOCKS` 류, 미배선) + (b) string retention 추적. 둘 다 runtime emitter 변경 + self-host 2-바이너리 A/B 재빌드 요구 → 본 milestone(기존 opt-in 측정) 범위 밖. 플랜의 "force 하지 말고 blocker 분리" 지침 적용.
- [x] 결과 fold: `UNSHADOW.bench.md` §arena-reclaim 신규 표(knob matrix · wall · scaling · byte-diff · 해석). milestone #3 flip (`UNSHADOW.md`) — 다른 milestone 줄 미변경(sibling 브랜치 충돌 회피).

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

