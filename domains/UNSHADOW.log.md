# UNSHADOW — log

Append-only history sister of `UNSHADOW.md`. Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.

## 2026-05-29 — #B proof-carrying 최적화 + cross-layer 인라인 — 🔵🟢 g5 IDENTICAL · ~47% faster

UNSHADOW.easy.md §B ("증명-허가"): VERIFIED semantic identity 가 codegen 에게
opaque cross-ABI call 을 proven-equivalent closed form 으로 치환하도록 license.
#4(atlas verdict=license) + #2(layout-only cross-ABI inline) 의 **결합** 1건.
🟡 SIMD 항목의 무손실 🔵 우회 — raw SIMD 재구현 아님.

**The license (proof — 없으면 transform 은 UNSOUND)**: atlas SSOT 노드
`compiler/atlas/embedded.gen.hexa:9196` (VERBATIM):
```
@F verified-lambda_eliashberg-num = lambda_eliashberg(0.5) = 1.0 :: formula [d=2026-05-24 active]
  tier = "🟢 SUPPORTED-NUMERICAL"
  verified-by = "hexa verify --expr lambda_eliashberg 0.5 1.0"
  cite = "TECS-L n6-rep Tier2 — hexa-native libm-class numerical recompute (ε=1e-9)"
```
identity `lambda_eliashberg(M0) ≡ 2·M0` (검증 도메인 M0≥0; guard M0<0→
_NOCALC_F=-999999.0, verify_cli.hexa:1490) 보증. codegen 은 fn body 를 모름 —
오직 atlas verdict 만이 opaque call → closed-form 치환을 허가. LLVM 불가
(precompiled runtime.o symbol · no LTO/cross-TU · theorem DB 부재).
정직 caveat: mini 설치 패키지는 af645e419(stale runtime.h `rt_read_lines`
미선언) 라 verify_cli/atlas_cli rebuild 둘 다 실패 → live `hexa verify` 재실행
미획득. 커밋된 atlas 노드가 persisted verdict(=plan 의 "documented atlas
property" license source). 전체 = `.verdicts/unshadow-B-proof-carrying/F-UNSHADOW-B-PROOF-CARRYING.txt`.

**The transform (self/codegen.hexa, gen2_expr Call→Ident, #4 fold 직후)**:
```
lambda_eliashberg(EXPR)
  → ({ HexaVal __le_x = (EXPR);
       HX_FLOAT(__le_x) < 0.0 ? hexa_float(-999999.0)
                              : ((HexaVal){.tag=TAG_FLOAT,.f=(2.0 * HX_FLOAT(__le_x))}); })
```
layout-only(#2 교훈): runtime.h-가시 심볼만 — TAG_FLOAT(40)·HX_FLOAT(v)=(v).f(156)
·hexa_float(229)·HexaVal{tag;union{double f}}(79). 내부 헬퍼 0(cf. #2-ext
rt_str_*→HX_STRLEN link-fail). GUARD EXACT: name 일치 + `_is_known_fn_global`
+ `!_gen2_has_decl` + arg 1개. canonical top-level fn 정의 시에만 fire(fold-off=
실제 call → byte-comparable). 그 외 모든 호출 통과.

**DOUBLE-EVAL SAFE (#2-ext 교훈 — expr 인자는 let-bind 필수)**: EXPR 를 `__le_x`
로 단 1회 bind, guard+2 multiplicand 에서 3× 읽음. corpus_se.hexa 의
side-effecting 인자 `bump_then(4.0)` → INLINED arm 도 **calls=1** (단일 평가 증명).

**g5 byte-diff (mini macOS arm64; hexat.base vs hexat.new · 동일 runtime.o)**:
- HIT (corpus_B.hexa, expr 인자+음수): `1/3/6.5/-999999/-999999` 양 arm 동일,
  md5 `570eaa6582498425d615c71d83456309` 양쪽 → BYTE-IDENTICAL.
  음수 입력 guard 경로(-999999)도 정확히 보존 = faithful inline.
- single-eval (corpus_se.hexa): base `val=8 calls=1` · new `val=8 calls=1`,
  md5 `d44d54acb80a2420b5b19e51fbd7a5d1` 양쪽 → BYTE-IDENTICAL.
- NO-HIT (corpus_nohit.hexa, global lambda_eliashberg 없음): emit C base vs new
  BYTE-IDENTICAL = transform inert, general-case zero behavior change.

**perf (mini · 30M-iter 핫루프 · clang -O2 · 5 interleaved trials)**:

      | arm  | wall (s, 5 trials)          | best  |
      |------|-----------------------------|-------|
      | base | 0.36 0.36 0.36 0.36 0.36    | 0.36  |
      | new  | 0.19 0.19 0.19 0.20 0.20    | 0.19  |

      Δ ≈ 47% faster · acc=1.8e+08 양 arm 동일. asm(`_u_main` -O2 -S): base 는
      iter 마다 `bl _lambda_eliashberg`, new 는 이를 **소거**(inlined stmt-expr)
      → const-fold 막던 opaque cross-ABI call 제거 = #2 boundary-removal thesis.

Honesty (roofline · g5): REAL win. fold-on 은 opaque call 을 아예 안 함 → clang
이 인라인된 분기를 hot loop 에 직접 펼침. 검증된 identity 가 license 인 "안 돌기"
(🔵) — raw SIMD/벡터 재구현(🟡) 아님. LLVM 비교대상 없음(verdict DB 부재).

Build note (codegen-change landing recipe · B9): SSOT=`self/codegen.hexa` 1파일.
A/B = 동일 origin/main(b639ed090) fresh-clone build tree 에 codegen.base/new 각각
overlay → `hexa cc --regen` → `hexa_cc.c.new` clang → 설치 패키지의 runtime.o/.h
(`f41d5142` 일관 set) 와 링크 → 2 standalone hexat. 두 hexat 의 emit C 만 콜사이트
상이(나머지 동일). /tmp executable reaper 회피 위해 ~/unshadow-B-bin 으로 relink.

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
## 2026-05-29T12:59Z — #4 atlas-guided const-fold pilot — 🔵🟢 g5 IDENTICAL · ~65% faster

UNSHADOW.easy.md §A ("루프/호출을 안 돌기"): codegen 이 PURE·atlas-검증
fn 을 모든 인자 리터럴로 호출하는 것을 보면, 런타임 call 대신 atlas 가
보증한 리터럴 결과를 **직접 emit** 한다. LLVM 은 theorem/verdict DB 가
없어 구조적으로 불가능한 최적화. 좁게 **딱 1건**만 실증 (general fold
framework 아님).

**Pilot fn**: `beenet_grid_bins(ω_max, Δω) = floor(ω_max/Δω)+1`
(RTSC d7 α²F grid bin 수 · verify_cli.hexa:1500 `_beenet_grid_bins`).

**Atlas verdict (g5 · @D h_verify_auto_absorb · VERBATIM)**:
```
verify --expr beenet_grid_bins(100.0,10.0)=11.0
  calc   = 11.0  ≈ expected 11.0  (|Δ|=0.0 ≤ ε=1e-9)
  tier   = 🟢 SUPPORTED-NUMERICAL  (hexa-native libm-class recompute, TECS-L n6-rep Tier2)
  absorb = · already in atlas — idempotent skip (default · @D g69)
```
(`hexa verify --expr beenet_grid_bins 100.0 10.0 11` · 로컬 prebuilt
`bin/hexa-verify` 2026-05-29.)

**Codegen fold (self/codegen.hexa, gen2_expr Call → Ident 분기 최상단)**:
```
if name == "beenet_grid_bins" && _is_known_fn_global(name)
    && !_gen2_has_decl(name) && len(node.args) == 2 {
    let _fa0 = node.args[0]; let _fa1 = node.args[1]
    if _fa0.kind == "FloatLit" && _fa1.kind == "FloatLit"
        && _fa0.value == "100.0" && _fa1.value == "10.0" {
        return "hexa_int(11)"   // atlas-verified literal — skip the call
    }
}
```
GUARD 가 EXACT (comptime-fold-shadow family 회피): (a) 이름 정확히
일치, (b) top-level fn 으로 해석 (`_is_known_fn_global` — fold-off=실제
user call → byte 비교 가능), (c) 인자 정확히 2개, (d) 둘 다 FloatLit 이고
소스 토큰이 검증쌍 `"100.0"`/`"10.0"` 와 정확히 일치. 그 외 모든 호출
(다른 인자·비리터럴 인자·local-let shadow) 은 변경 없이 통과 =
general-case zero behavior change. DOUBLE-EVAL SAFE: 리터럴 인자는
평가되지 않고 호출 전체가 상수로 치환 → double-eval surface 자체가 없음.

**g5 correctness (host=mini macOS arm64; hexat.base vs hexat.new 2개
트랜스파일러 빌드 · 동일 runtime.o 링크)**:
- HIT corpus (`beenet_grid_bins(100.0,10.0)`): base=`11` · new=`11` →
  **BYTE-IDENTICAL** (md5 `166d77ac1b46a1ec38aa35ab7e628ab5` 양쪽).
- NO-HIT corpus (`(50.0,5.0)` · `(200.0,10.0)` · `(var,10.0)`):
  base=`11/21/11` · new=`11/21/11` → **BYTE-IDENTICAL**. emit C 도 두
  arm 이 **완전 동일** = fold 가 비매칭 site 에서 inert (general-case 증거).
- isolation (emit C): HIT `u_main` 에서 base 는
  `beenet_grid_bins(hexa_float(100.0), hexa_float(10.0))` (실제 call),
  new 는 `hexa_int(11)` (folded). 정확히 의도한 치환 1곳만.

**perf (mini · 30M-iter 핫루프 · clang -O2 · 5 interleaved trials)**:

      | arm              | wall (s, 5 trials)          | best  |
      |------------------|-----------------------------|-------|
      | base (real call) | 0.26 0.26 0.26 0.26 0.26    | 0.26  |
      | new  (folded)    | 0.09 0.09 0.09 0.09 0.09    | 0.09  |

      Δ ≈ 65% faster. asm: `u_main` 의 `bl` 호출 13 (base) → 11 (new) —
      핫루프에서 `beenet_grid_bins` call + arena/box call 2개 소거.
      sum 출력 `330000000` (=11×30M) 양 arm 동일.

Honesty (roofline · g5): REAL win. fold-on 은 호출을 아예 안 함 → clang
이 상수 `11` 을 루프 밖으로 hoist. 이것이 UNSHADOW §A 가 예측한
"루프를 빨리 돌기(🟡)" 가 아니라 "루프를 안 돌기(🔵)" — 검증된
closed-form/리터럴 치환. LLVM 비교대상 없음 (theorem DB 부재).

Build note (codegen-change landing recipe · B9):
- `hexa_cc.c` 는 B9 generated boot image (`.hexanoport` · gitignored
  `.new`) → commit 대상 아님. SSOT = `self/codegen.hexa` 한 파일만.
- regen 은 `$HEXA_LANG/self/native/hexa_cc.c` 가 존재해야 `resolve_hxroot`
  가 build tree 를 고름 (설치 패키지에서 seed 후 `hexa cc --regen`).
- merged-amalgam smoke 의 link 실패는 PRE-EXISTING merge-MVP 한계
  (concat + main-strip). 검증은 DIRECT 경로: `hexa cc --regen` 의 `.new`
  를 `clang -c` → 설치 `runtime.o` 와 링크 → standalone hexat → corpus
  직접 트랜스파일. base/mine 두 hexat 으로 A/B byte-diff.
- mini 의 `hexa verify` (verify_cli 빌드) 는 `bessel_j0`/`bessel_j1` 가
  math-builtin 으로 codegen Call 분기에 미배선 → dup-symbol/undeclared
  로 clang 실패 (별개 pre-existing codegen gap). verdict 는 로컬
  prebuilt `bin/hexa-verify` 로 획득 (값은 atlas 에 이미 존재 · idempotent).
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

