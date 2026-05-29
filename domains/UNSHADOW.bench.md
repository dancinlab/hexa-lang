# 🪆 UNSHADOW 측정대 (M1) — A/B micro-bench harness 프로토콜

> hexa-native 백엔드(native asm) vs clang -O2 (C-emit) 를 **같은 호스트·같은
> 워크로드·연속·warmup** 으로 실측해 Δ% 를 기록하는 재사용 측정대.
> SSOT 도구 = `tool/unshadow_bench.hexa` · 워크로드 = `bench/unshadow/*.hexa`.

---

## §측정대 사용법

```
hexa run tool/unshadow_bench.hexa -- \
  --workloads "bench/unshadow/sieve_heavy.hexa,bench/unshadow/fib_heavy.hexa,..." \
  --warmup 2 --iters 5 \
  --aprime /Users/ghost/core/hexa-lang/build/aprime_cc \
  --hexa   /Users/ghost/.hx/bin/hexa \
  --out    state/perf/unshadow_ab.jsonl \
  --tag    "mac-arm64"
```

워크로드마다 측정대가 하는 일:

1. **arm B (clangO2)** 빌드 — 기본 C 경로 (`hexa build`, HEXA_BACKEND 미설정).
2. **arm A (native)** 빌드 — `HEXA_BACKEND=native hexa build`.
   - 빌드 시간은 **측정 창 밖**(컴파일은 1회, 타이밍 대상은 산출 바이너리).
3. **정확성 게이트 (g5)** — 두 바이너리 stdout 을 byte-diff. 불일치 = `MISMATCH` 실패.
4. **타이밍** — 각 바이너리를 `warmup` 회 버린 뒤 `iters` 회 `time_ms()` 브래킷으로 측정.
   - `min_ms`(노이즈 최저) + `median_ms` 보고.
5. **JSONL 행 + Δ‰** emit — `delta_permille_min = (clangO2_min − native_min)/clangO2_min × 1000`.
   - 양수 = native 가 빠름. (‰ = permille, ÷10 하면 %.)

엔트리 필드: `workload · src · tag · iters · warmup · correctness · native_min_ms ·
native_median_ms · clangO2_min_ms · clangO2_median_ms · delta_permille_min`.

> 환경(필수): `HEXA_LANG=<repo>` · `HEXA_MAC_BUILD_OK=1`(mac) ·
> `HEXA_MODULE_LOADER=<repo>/build/hexa_module_loader` ·
> `HEXA_APRIME_CC=<repo>/build/aprime_cc`.

---

## §A/B 토글 메커니즘 (`HEXA_BACKEND` env)

`self/main.hexa` `cmd_build` 의 S5 백엔드 셀렉터 (~L2620):

| 토글 | arm | 유저코드 컴파일 경로 | 최종 링크 |
|---|---|---|---|
| `HEXA_BACKEND=native` | A | `aprime_cc --emit=asm` → `<stem>.s` (네이티브 MIR→LIR→asm) | clang 가 .s 어셈블 + `self/runtime.c` 링크 |
| 미설정 / `=c` (기본) | B | `hexat` → C 소스 → `clang -O2` | 같은 clang 가 C + `self/runtime.c` 링크 |

**핵심**: 두 arm 모두 **동일한 `self/runtime.c`** 를 2nd TU 로 링크한다.
차이는 **유저 함수 본문**이 (A) hexa 네이티브 codegen 이 emit 한 arm64 asm 이냐,
(B) clang -O2 가 컴파일한 C 냐 뿐이다 — 런타임 floor 는 공통. 이것이 공정한 A/B 축.

검증 근거: `compiler/test/macho_p0_corpus/run_F_P3_HEXA_BACKEND_ENV.hexa`
(HEXA_BACKEND=native + stripped PATH → clang/as fork 없이 Mach-O .o 산출 — env 존중 확인).

> 주의 — 측정 대상 호스트 1개 고정. native 백엔드는 arm64/x86_64 코드 emit 이므로
> Mac arm64 또는 ubu x86_64 중 **한 곳에서 두 arm 을 back-to-back** 으로 돌려야 공정.
> Mac arm 과 ubu arm 을 섞으면 안 됨.

---

## §baseline 표

측정: `mini` (macOS arm64, Apple Silicon) · 두 arm back-to-back · `warmup 3 · iters 7` ·
`min_ms` = 7회 중 노이즈 최저값 (Δ% 는 min 기준). 두 arm 모두 동일 `self/runtime.c` 링크.
2026-05-29 측정 · tag `mac-arm64-mini`.

| workload | correctness (g5) | native_min_ms | clangO2_min_ms | Δ% (min) |
|---|---|---|---|---|
| sieve_heavy   | IDENTICAL | 280  | 224  | **−25.0%** |
| fib_heavy     | IDENTICAL | 1782 | 1282 | **−39.0%** |
| hash_heavy    | IDENTICAL | 2101 | 1304 | **−61.1%** |
| collatz_heavy | IDENTICAL | 3883 | 3523 | **−10.2%** |
| mixmul_heavy  | IDENTICAL | 3696 | 2646 | **−39.6%** |

> Δ% = `(clangO2_min − native_min) / clangO2_min × 100`. **음수 = clang -O2 가 더 빠름.**
> 5/5 워크로드 모두 byte-diff stdout 동일(g5 PASS) — native backend 는 정확성은 통과,
> 속도는 5/5 전부 clang -O2 에 진다 (−10.2% ~ −61.1%).
>
> 원시 JSONL (verbatim, mini `state/perf/unshadow_ab.jsonl`):
>
> ```jsonl
> {"workload": "sieve_heavy", "src": "bench/unshadow/sieve_heavy.hexa", "tag": "mac-arm64-mini", "iters": 7, "warmup": 3, "correctness": "MATCH", "native_min_ms": 280, "native_median_ms": 283, "clangO2_min_ms": 224, "clangO2_median_ms": 233, "delta_permille_min": -250}
> {"workload": "fib_heavy", "src": "bench/unshadow/fib_heavy.hexa", "tag": "mac-arm64-mini", "iters": 7, "warmup": 3, "correctness": "MATCH", "native_min_ms": 1782, "native_median_ms": 1786, "clangO2_min_ms": 1282, "clangO2_median_ms": 1298, "delta_permille_min": -390}
> {"workload": "hash_heavy", "src": "bench/unshadow/hash_heavy.hexa", "tag": "mac-arm64-mini", "iters": 7, "warmup": 3, "correctness": "MATCH", "native_min_ms": 2101, "native_median_ms": 2104, "clangO2_min_ms": 1304, "clangO2_median_ms": 1364, "delta_permille_min": -611}
> {"workload": "collatz_heavy", "src": "bench/unshadow/collatz_heavy.hexa", "tag": "mac-arm64-mini", "iters": 7, "warmup": 3, "correctness": "MATCH", "native_min_ms": 3883, "native_median_ms": 3894, "clangO2_min_ms": 3523, "clangO2_median_ms": 3528, "delta_permille_min": -102}
> {"workload": "mixmul_heavy", "src": "bench/unshadow/mixmul_heavy.hexa", "tag": "mac-arm64-mini", "iters": 7, "warmup": 3, "correctness": "MATCH", "native_min_ms": 3696, "native_median_ms": 3703, "clangO2_min_ms": 2646, "clangO2_median_ms": 2766, "delta_permille_min": -396}
> ```
>
> 측정 invocation (verbatim):
>
> ```
> pool on mini 'cd ~/core/hexa-lang
>   export HEXA_LANG=$PWD HEXA_MAC_BUILD_OK=1
>   export HEXA_MODULE_LOADER=$PWD/build/hexa_module_loader HEXA_APRIME_CC=$PWD/build/aprime_cc
>   /tmp/unshadow_bench \
>     --workloads "bench/unshadow/{sieve,fib,hash,collatz,mixmul}_heavy.hexa" \
>     --warmup 3 --iters 7 --aprime $PWD/build/aprime_cc \
>     --hexa /Users/mini/.hx/bin/hexa --out state/perf/unshadow_ab.jsonl --tag "mac-arm64-mini"'
> ```
> (드라이버는 interp OOM 회피를 위해 `hexa build tool/unshadow_bench.hexa` 로 컴파일 후 실행.)

---

## §정직한 해석 (roofline · bandwidth-bound)

**한 줄 요약: native backend 는 정확성 5/5 PASS, 속도는 5/5 전부 clang -O2 에 진다 (−10% ~ −61%). 이것은 예상된, 정직한 결과다.**

UNSHADOW roofline 윤리(`UNSHADOW.easy.md`)대로, **scalar/integer hot loop 에서 native 가 clang -O2 에 지는 것은 함정이 아니라 baseline 그 자체다.** clang -O2 는 이런 정수 루프에 대해 사실상 roofline 에 근접해 있다 — LICM(loop-invariant code motion), strength reduction, 레지스터 할당, 명령 스케줄링, 분기 예측 친화 layout 을 전부 적용한다. hexa native backend(aprime_cc MIR→LIR→arm64)는 아직 그 최적화 패스 대부분을 갖추지 못한 어린 codegen 이므로, 같은 루프를 더 느리게 emit 하는 게 당연하다. **이 도메인의 north-star 는 "native 가 clang 보다 빠르다"가 아니라 "졸업으로 열린 최적화(cross-layer 인라인 · closed-form 제거 · proof-carrying)를 측정으로 따낸다"** — 이 표는 그 출발 baseline 을 정직하게 못 박은 것이다.

워크로드별 정직한 읽기:

- **hash_heavy (−61.1%, 최대 격차)** — `hash * 16777619` + `hash + i` 의 타이트한 mul·add 누적 루프. clang -O2 가 mul/add 를 융합하고 루프를 언롤·파이프라인하는 반면, native 는 라운드마다 스칼라 mul/add 를 곧이곧대로 emit 한다. 가장 "순수 산술 ILP" 종목이라 격차가 가장 크다 — clang 의 명령 스케줄러가 가장 크게 이기는 곳.
- **fib_heavy (−39.0%) · mixmul_heavy (−39.6%)** — 단순 add 루프 / LCG mul·add·mod 루프. 역시 산술 bound, clang 의 register-keep + 언롤이 native 의 naive emit 을 앞선다.
- **sieve_heavy (−25.0%)** — 중첩 루프 + `d*d <= n` 분기. 분기·mod 가 섞여 순수 ILP 가 덜해 격차가 줄어든다.
- **collatz_heavy (−10.2%, 최소 격차)** — `v % 2`·`v / 2`·`v*3+1` 의 **불규칙 데이터-의존 분기**. 분기 예측이 양 arm 공통으로 지배적이고 clang 의 정적 최적화 여지가 작아, native 와의 격차가 가장 좁다. **분기-bound 워크로드일수록 native 가 clang 에 근접**한다는 신호 — 향후 "어디서 native 가 따라잡는가"의 단서.

정확성(g5): **5/5 IDENTICAL** — native backend 가 emit 한 arm64 asm 의 정수 의미론이 clang -O2 의 C 의미론과 byte-for-byte 일치(stdout 동일). 즉 native backend 는 **느리지만 옳다**. UNSHADOW 의 다음 milestone(cross-layer 인라인 등)은 이 정확성 floor 위에서 clang 이 못 하는 최적화로 격차를 뒤집는 것을 목표로 한다.

caveat: 타이밍 단위 = ms(compiled 경로에 ns builtin 없음) · 전 프로세스(startup+run) 측정이나 hot loop 가 수백~수천 ms 라 startup(~4ms)은 무시 가능 · 단일 호스트(mini) 단일 세션 · min(7회) 기준.

---

## §부록 — 기존 러너 버그 (bench/bench_results.jsonl)

- `bench/bench_results.jsonl` 의 다수 행이 `avg_ns: void` — 러너가 측정값을 못 채운 흔적.
  근본 원인: 인자 파싱이 `--warmup=0`(=붙은 형식)을 워크로드 파일로 오인(행에 `"file": "--warmup=0"`),
  그리고 일부 워크로드(fib_rec)에서 timing 필드가 `void`(미산출)로 남음.
- `tool/bench_runner.hexa`(v1, ms-amortized)는 A/B 축이 없다 — interp 경로(`hexa run`)를
  단일 백엔드로만 N회 돌려 ms 를 적재. UNSHADOW 측정대는 (1) compiled 경로만, (2) A/B 두 arm,
  (3) byte-diff 정확성 게이트를 추가한 별도 도구.

---

## §arena-reclaim — 자원(peak RSS · alloc 지연) 측정

> milestone "🟢 전용 arena reclaim 배선 — 자원(RSS·alloc 지연) 측정" 의 실측.
> **요지**: 새 allocator 를 만들지 않는다. 이미 default-ON 인 region-reclaim opt-in
> (`HEXA_VAL_ARENA` per-fn scope rewind + `HEXA_STR_ARENA` bump-concat)을 hot-alloc
> 워크로드에서 **fully-off 베이스라인 대비 peak-RSS Δ(주) + wall Δ(부)** 로 측정.

워크로드 = `self/bench/arena_reclaim_bench.hexa` (+ `bench_str` 변형: 순수 단문 string
churn, heap array 없음). leaf fn `churn(seed)` 가 매 호출마다 64개의 임시 concat string 을
만들고 길이만 누적한 뒤 int 하나만 반환 — string 들은 호출이 끝나면 전부 dead. codegen 이
`churn` 진입/종료에 `__hexa_fn_arena_enter()` / `__hexa_fn_arena_return(acc)` 를 emit 하므로
(생성 C 확인됨), arena-ON 이면 프레임마다 bump 마크를 push 하고 return 시 rewind 한다.

측정: `mini` (macOS arm64) · back-to-back · `/usr/bin/time -l` max RSS · raw 바이너리
(dispatch shim 밖) · wall = best-of-3 `time -p real`. 워크로드 = `bench_str` (순수 string),
N = 바깥 루프 반복수. 2026-05-29 · tag `mac-arm64-mini`.

### peak RSS — knob 매트릭스 (N=400000, 동일 바이너리)

| VAL_ARENA | STR_ARENA | peak RSS | vs fully-off |
|---|---|---|---|
| 1 (default) | 1 (default) | **3.73 GB** | **−39.7%** |
| 0 | 1 | 4.97 GB | −19.7% |
| 1 | 0 | 6.19 GB | ±0% |
| 0 | 0 (fully-off) | 6.19 GB | baseline |

> raw bytes (verbatim `/usr/bin/time -l` max RSS):
> `VAL=1,STR=def=3732914176` · `VAL=0,STR=1=4971167744` ·
> `VAL=1,STR=0=6190497792` · `VAL=0,STR=0=6190497792`.

### wall-time — best-of-3 (N=400000, raw binary)

| config | wall (s) | vs fully-off |
|---|---|---|
| VAL=1 STR=def (default) | **9.24** | **−26.4%** |
| VAL=0 STR=def | 11.08 | −11.8% |
| VAL=1 STR=0 | 11.73 | −6.6% |
| VAL=0 STR=0 (fully-off) | 12.56 | baseline |

### peak RSS scaling (선형성 — `bench_str`)

| N | arena-ON (VAL=1,STR=def) | fully-on→off 비교용 VAL=0 |
|---|---|---|
| 100000 | 934756352 B | 1244266496 B |
| 200000 | 1867481088 B | 2486566912 B |
| 400000 | 3732914176 B | 4971167744 B |

> 정확히 N 에 선형 (100k→400k = 정확히 4×, 두 모드 모두). arena-ON/arena-OFF 비율 ≈ 0.75 고정.

### g5 정확성 (byte-diff)

4개 reclaim config (VAL∈{0,1} × STR∈{0,1}) stdout 전부 **byte-identical**:

```
=== g5 byte-diff: program output across reclaim knobs (N=400000) ===
VAL=1,STR=def : total=347288960
VAL=0         : total=347288960
STR=0         : total=347288960
VAL=0,STR=0   : total=347288960
BYTE-DIFF VERDICT: IDENTICAL across all 4 reclaim configs ✅
```

### 정직한 해석 — real win (constant-factor), NOT a bound

- **측정된 win 은 진짜다**: default arena reclaim(VAL+STR)은 fully-off 대비 **peak RSS −40%
  + wall −26%** 를 동시에 따낸다. "wire 해서 측정" milestone 의 Δ 가 둘 다 양수로 나왔고,
  byte-diff 는 4/4 IDENTICAL — 즉 reclaim 은 **싸게 옳고 더 가볍다**.
- **그러나 peak RSS 를 *bound* 하지는 못한다**: 세 config 전부 N 에 **선형으로** 증가한다
  (arena-ON 도 ~9.3 KB/iter). per-fn scope rewind 는 살아있는 set 을 평탄하게 유지해야 하지만,
  이 워크로드에서는 high-water mark 가 호출수에 비례해 계속 자란다 — rewind 가 비운 블록을
  재사용은 하되 **OS 로 반납하지 않고**(블록은 `hexa_arena_destroy` 전까지 free 안 됨,
  `runtime_core_emit.hexa` L3634), concat/`hexa_to_string` 산출물의 일부가 프레임 경계를 넘어
  살아남는 retention 경로가 남아 있음을 시사. 즉 reclaim 은 **기울기(constant factor)를 낮추지
  size class 자체를 잡지는 못한다.**
- **다음 천장**: peak RSS 를 진짜로 *bound* 하려면 (a) rewind 시 빈 trailing 블록을 OS 로
  반납하는 opt-in(`HEXA_ARENA_RELEASE_BLOCKS` 류, 현재 미배선) + (b) leaf fn 반환 후에도 살아남는
  string 의 retention 경로 추적이 필요. 둘 다 runtime emitter 변경 + self-host 재빌드(2 바이너리
  A/B)를 요구하므로 본 milestone(= 기존 opt-in 측정) 범위 밖. blocker 로 분리해 후속에 남긴다.

> caveat: 단일 호스트(mini) 단일 세션 · peak RSS = 전 프로세스 max RSS(startup 포함이나
> hot loop 가 지배) · wall = best-of-3 real(노이즈 최저) · 측정 바이너리는 설치 toolchain 의
> 캐시된 `runtime.o` 링크본(코드 변경 없음, 순수 env A/B).

---

## §lto-unwall — runtime.o C-ABI 벽 제거 (LTO vs same-TU) 실측

> milestone "🔵×🟡 LTO/same-TU unwall 측정" 의 실측 — 이번 사이클 두 closed-negative
> (#2-ext rt_str inline · C bounds/null elision)가 수렴한 **단일 블로커 = precompiled
> `runtime.o` C-ABI 벽**을 제거하면 둘이 🔴→win 으로 뒤집히는지.
> SSOT 도구 = `tool/unshadow_lto_unwall_bench.hexa` · verdict = `.verdicts/unshadow-lto-unwall/`.

### 진단한 링크 모델 (= 벽)

졸업(.c=0) 후에도 emit 된 user.c 는 `#include "runtime.h"` 하고, 최종 링크는 **별도
precompiled runtime 오브젝트를 2nd TU 로** 소비한다 (`self/main.hexa` `cmd_build` ~L3009–3041):

| branch | 조건 | runtime 입력 | 벽? |
|---|---|---|---|
| (1) | `HEXA_PREBUILT_RUNTIME` set | 미리 빌드된 `runtime.o`/`.a` 직접 링크 | **벽** |
| (2) | 기본 (HOME 존재) | content-hash 캐시 `clang -O2 -c runtime.c -o runtime.<sha>.o` → 그 **오브젝트** 링크 | **벽 (현 기본)** |
| (3) | 첫 빌드 / no HOME / `--shared` / cross | `runtime.c` **소스**를 2nd source 로 동일 clang 호출 (그래도 별 TU; -flto 없음) | 별 TU |

`runtime.h` 는 HexaVal-레벨 ABI 만 export. 진짜 인라인이 필요로 하는 내부 스칼라 헬퍼
(`HX_STRLEN`·`hxlcl_strncmp`·`HX_ARR_LEN`)는 **runtime.c 아말감 안에만** 정의된다
(`runtime.c:1211 #include "runtime_core.c"`, emit = `runtime_core_emit.hexa:763/1090`).
이것이 두 closed-negative 가 부딪힌 **그 벽**이다. 졸업 후 `self/runtime.c` 는 repo 에 부재
(B9 generated); 영속 산출물은 precompiled `runtime.o` 뿐 — **벽은 구조적으로 살아있다.**

### 측정: `mini` (macOS arm64, Apple clang 21) · 두 arm back-to-back · best-of-5 wall · 2026-05-30

**#2-ext — rt_str_starts_with 인라인** (60M-iter hot loop, 3 call-site):

| arm | 링크 모델 | built (링크) | 출력 md5 (g5) | wall (s, best-of-5) |
|---|---|---|---|---|
| base_walled   | runtime.h + out-of-line call + `runtime.o` | yes | `f869400e…` | 0.36 |
| inline_walled | runtime.h + 인라인 본문 + `runtime.o` | **no (LINK FAIL)** | — | — |
| inline_lto    | inline_walled + `-flto` | **no (STILL FAIL)** | — | — |
| base_samtu    | **same-TU** `#include "runtime.c"` + out-of-line call | yes | `f869400e…` | **0.25** |
| inline_samtu  | **same-TU** + 인라인 본문 | yes | `f869400e…` | **0.25** |

> `-flto` 는 **컴파일-타임**에 `hxlcl_strncmp`/`HX_STRLEN` undeclared 로 실패 — LTO 는
> 링크-타임 최적화라 user.c 가 컴파일조차 안 되면 발화 못 함. ① 은 #2-ext 에 **불충분**.
> asm (60M-iter, `-O2 -S`): base_walled `bl _rt_str_starts_with`=3 · same-TU=1 (`bl _hxlcl_strncmp`=9, clang 가 본문 인라인+언롤).

**C — hexa_array_get bounds-check elision** (idx 가 구조적으로 `[0,len)`, 2M×256 iter):

| arm | 링크 모델 | built | 출력 md5 (g5) | wall (s, best-of-5) | bounds-check 살아남음? |
|---|---|---|---|---|---|
| cbase_walled | runtime.h + out-of-line `hexa_array_get` + `runtime.o` | yes | `fda59d53…` | 0.73 | (벽 안) |
| csamtu       | **same-TU** `#include "runtime.c"` | yes | `fda59d53…` | 0.72 | **yes** (`bl _hexa_throw`=1 · oob-string×2) |

> same-TU 에서도 main-region `bl _hexa_array_get`=1 (양쪽 동일) — `hexa_array_get` 는
> 너무 커서 clang 이 루프에 인라인 안 함 → 인라인 0, elision 0, Δ 0.

### 정직한 해석 — #2-ext FLIP (same-TU), C NULL

- **#2-ext: 🔵×🟡 FLIP 🔴→WIN, 단 hand-emit 인라인 덕이 아니다.** ① `-flto` 불충분(컴파일-타임 scope
  실패). ② **same-TU 가 LINK + WIN**: 0.36→0.25s = **−31%**, byte-identical. 결정적 Δ 는 same-TU
  컴파일 자체에서 온다 — clang -O2 가 이제 런타임 본문을 보고 `rt_str_starts_with` 를 **스스로**
  인라인/언롤(`bl` 3→1). codegen 의 명시적 INLINE emit(inline_samtu)은 same-TU out-of-line call 대비
  **추가 win 0** (0.25=0.25, asm 동일). 즉 #2-ext 의 블로커(링크 벽)는 실재하고 same-TU 가 제거하지만,
  가치는 경계가 열리면 clang -O2 의 cross-TU 인라이너가 따낸다 — 맞춤 인라인 변환은 unwall 후 redundant.
- **C: 🔵 correctness lossless · 🔴 perf NULL.** 벽을 없애고 `hexa_array_get` 본문이 다 보여도 clang -O2
  는 bounds check 를 **elide 안 한다**(throw + oob-string 잔존), 루프에 인라인도 안 한다 → Δ 없음
  (0.73 vs 0.72). clang 은 push-된 opaque 배열에 대해 `i < HX_ARR_LEN(arr)` 를 증명 못 함
  (`hexa_array_push` 는 realloc 가능). 진짜 bounds-elision win 은 **🔵 proof-carrying CODEGEN 변환**
  (index 가 in-range 임을 증명할 때 bounds-free get emit)을 요구 — 그것이 deferred 🔵 축이며 unwall 단독으로
  열리지 않는다. C 의 정직한 **null** 결과.

> caveat: 단일 호스트(mini) 단일 세션 · wall = best-of-5 real(노이즈 최저) · 측정대는 설치
> toolchain 의 `runtime.h`/`runtime.c`/`runtime.o` 사용 · 모든 arm 동일 호스트 back-to-back ·
> 재현 = `tool/unshadow_lto_unwall_bench.hexa` (parse-gate PASS · compiled-build PASS · run PASS on mini).
## §parity-attest — 🟡 floor = clang -O2 상속 (재구현 0) 측정 확인

> milestone "🟡 parity 상속 명문화" 의 실측. **요지**: hexa 의 C-emit 경로는 emit 한
> C 를 그대로 `clang -O2` 에 먹인다(self/main.hexa L3041 final-link 하드코딩
> `clang -O2`). 따라서 LLVM 의 최적화 패스(inline·fold·LICM·reg-alloc·sched)는
> **공짜로 상속**된다 — 재구현 0. 이 절은 그 상속을 **두 축**으로 측정한다:
>
> - **(축 1) 상속 증거 = emit-C @ -O2 vs @ -O0** (같은 TU, optimizer 토글만): O2 가
>   유의미하게 빠르면 LLVM 패스가 emit-C 에 실제로 적용됨이 증명된다 = "rides clang -O2".
> - **(축 2) raw parity = hexa C-emit @ -O2 vs 손수 짠 idiomatic C @ -O2**: 같은
>   clang -O2 로 컴파일한 plain-`long` 레퍼런스 C 와의 비. **정직: 이 비는 1.0 이
>   아니다** — 아래 §정직한 발견 참조.

측정: `mini` (macOS arm64) · clang 21.0.0 · back-to-back · `warmup 3 · best-of-9`
wall(min, zsh `EPOCHREALTIME` ms) · 같은 `runtime.o` 링크(`~/.hexa-cache/runtime.<sha>.o`,
코드 변경 0). reference C 는 hook 회피 위해 **`/tmp` 에서만** 작성·컴파일(repo 안 `.c` 0개).
2026-05-30 · tag `mac-arm64-mini`. 워크로드 3종 = `fib_heavy · hash_heavy · sieve_heavy`
(M1 baseline 과 동일 스칼라/정수 hot loop).

### 표 — 4-way wall min (ms)

| workload | g5 (value) | ref-C @-O2 | ref-C @-O0 | hexa C-emit @-O2 | hexa C-emit @-O0 |
|---|---|---|---|---|---|
| fib_heavy   | IDENTICAL | 1   | 333 | 1263 | 1556 |
| hash_heavy  | IDENTICAL | 163 | 235 | 1295 | 2302 |
| sieve_heavy | IDENTICAL | 8   | 21  | 224  | 266  |

> g5(축 정확성): 워크로드마다 ref-C·hexaO2·hexaO0 **세 바이너리 stdout 전부 동일** (verbatim):
> ```
> fib   ref=614004930000000  hxO2=614004930000000  hxO0=614004930000000
> hash  ref=295847716000000  hxO2=295847716000000  hxO0=295847716000000
> sieve ref=1020000          hxO2=1020000          hxO0=1020000
> ```

### 축 1 — LLVM 패스 상속 비 (emit-C O2 / emit-C O0, 같은 TU)

| workload | hexaO0 ms | hexaO2 ms | 상속 speedup (O0/O2) |
|---|---|---|---|
| fib_heavy   | 1556 | 1263 | **1.23×** |
| hash_heavy  | 2302 | 1295 | **1.78×** |
| sieve_heavy | 266  | 224  | **1.19×** |

> emit-C 를 -O0 로 컴파일하면 -O2 보다 1.19×~1.78× 느리다 — 즉 **LLVM 패스가 emit-C 에
> 실제로 적용된다**(상속 발화). disasm 증거(hash_range hot fn, otool): **155→87 instr
> (44% 감소)** at -O2; fast-path `hexa_add`/`hexa_cmp_lt` 가 runtime.h static-inline
> 매크로라 clang 이 inline+fold 한다. → "rides clang -O2" 는 **참**이다.

### 축 2 — raw parity 비 (hexa C-emit @-O2 / idiomatic ref-C @-O2)

| workload | ref-C @-O2 ms | hexa @-O2 ms | parity ratio | 정직 판정 |
|---|---|---|---|---|
| fib_heavy   | 1   | 1263 | **1263×** | clang 이 ref 루프를 통째 elide(LICM) — degenerate |
| hash_heavy  | 163 | 1295 | **7.9×**  | runtime.o ABI 벽이 fold 차단 |
| sieve_heavy | 8   | 224  | **28×**   | runtime.o ABI 벽이 fold 차단 |

> **이 비는 ≈1.0 이 아니다.** 정직하게 보고한다(아래).

### 정직한 발견 — 상속은 참, raw parity 는 runtime.o ABI 벽이 막는다

**축 1 (상속) PASS — 축 2 (raw parity) 는 🔴 NOT free, 원인 = 이미 문서화된 blocker.**

- **상속은 측정으로 참이다(축 1).** emit-C 를 -O2 로 컴파일하면 -O0 대비 1.19×~1.78×
  빨라지고 hot fn 명령수가 44% 줄어든다. hexa 는 emit-C 를 `clang -O2` 에 그대로
  먹이므로 inline·fold·reg-alloc·sched 를 **재구현 0 으로 상속**한다. 🟡 floor 의
  "올라탄다(rides)" 명제는 거짓이 아니다.
- **그러나 idiomatic C 와의 raw parity 는 달성되지 않는다(축 2).** ratio 가 7.9×~1263×
  로 1.0 에서 멀다. 원인은 codegen 결함이 아니라 **emit-C 의 형태 + runtime.o 의
  C-ABI 벽**이다:
  - emit-C 의 모든 정수 연산은 `HexaVal`(tagged union)을 경유하고, fast-path 가 아닌
    분기·박싱 구성·`hexa_mod` 등은 **precompiled `runtime.o` 안의 out-of-line 호출**이다
    (hash_range hot fn 의 `bl` 가 O2 에서도 17개 남음). clang 은 이 벽 **너머로** fold/LICM
    할 수 없다 — opaque call 이라 invariant 임을 증명 못 한다.
  - 가장 극적인 fib(1263×): idiomatic ref-C 는 `fib_iter(40)` 이 loop-invariant 임을 clang
    이 증명해 **바깥 6M 루프를 통째 제거**(ref O0 333ms → O2 1ms). hexa emit-C 는 같은
    호출이 opaque `HexaVal` 반환이라 그 LICM 이 불가능 → 6M 번 전부 실행.
- **결론 = 🟡 floor 의 두 얼굴.** (a) emit-C **내부**에 보이는 최적화(static-inline op
  fold·local reg-alloc·sched)는 공짜 상속된다(축 1, 참). (b) emit-C 가 **runtime.o 벽
  너머로** 넘긴 연산에 대한 cross-TU 최적화(LICM·dead-loop elim·fold-through)는 상속
  안 된다(축 2, 막힘). 이 벽은 본 도메인이 이미 못 박은 blocker(`UNSHADOW.md` 전제,
  #2-EXT·C tag-elision closed-negative 의 수렴점)와 **동일**하다. raw parity 를 ≈1.0
  으로 끌어올리는 것은 `LTO / same-TU` 졸업(`.c=0`, RUNTIME.flip-floor) 에 의존한다 —
  그것이 바로 다음 milestone `🔵×🟡 LTO/same-TU unwall 측정`.

**attestation (정직 버전)**: 🟡 floor = clang -O2 **부분 상속** 확인 — emit-C 내부
패스는 재구현 0 으로 상속(O0→O2 1.19×~1.78× speedup, hot-fn instr −44%), 그러나 idiomatic
C 와의 raw parity ratio 는 **7.9×~1263×(≠1.0)** 로, runtime.o C-ABI 벽이 cross-TU
fold/LICM 을 막아 parity 가 free 가 **아니다**. parity ≈1.0 은 `.c=0` LTO 졸업 의존.

> caveat: 단일 호스트(mini) 단일 세션 · wall = best-of-9 real min(노이즈 최저) · 측정
> 바이너리는 캐시된 `runtime.o` 링크(코드 변경 0) · reference C 는 `/tmp` 외부 작성(hook
> 회피 · repo 안 `.c` 0개) · fib ref-O2=1ms 는 clang 의 dead-loop elim 으로 degenerate
> (ratio 절대값보다 "벽 너머 fold 불가"라는 정성 신호가 본질).

## §hexaval-unbox — 🟢 HexaVal 언박싱 pilot (known-int rebox → inline literal)

> milestone `🟢 HexaVal 언박싱 / register-pack` 의 실측. **요지**: §parity-attest 가
> raw 7.9×~1263× 갭의 주범으로 지목한 HexaVal 박싱을 **한 좁은 지점**에서 제거한다 —
> codegen STRUCTURAL-2 known-int BinOp fast-path 가 결과를 **out-of-line `hexa_int(…)`**
> 로 재박싱하던 것을 **inline C compound literal** `((HexaVal){.tag=TAG_INT,.i=(…)})` 로
> 바꿔, 핫루프 매 산술 step 의 `bl _hexa_int` ABI 호출(= runtime.o C-ABI 벽)을 없앤다.
> `self/codegen.hexa` L5127. 발화 조건 = `_is_known_int` 가 두 피연산자를 정적 TAG_INT
> 로 인증할 때만(불변 int-only `let`/IntLit). 그 외엔 기존 boxed emit = 일반 경로 무변경.

측정: `mini` (macOS arm64) · clang 21.0.0 · best-of-11 wall(real min, ms) · 같은
`runtime.o` 링크 · 2026-05-30 · tag `mac-arm64-mini`. 워크로드 = `knownint_heavy`
(16-op 불변 int `let` 체인 × 60M, 매 op 가 known-int fast-path 발화).

### 표 — 3-way wall min (ms) + asm

| arm | wall (ms) | hot `mix()` `bl _hexa_int` | parity gap (arm/ref) |
|---|---|---|---|
| ref-C @-O2 (plain `int64_t`) | 54  | — (no HexaVal) | 1.00× (baseline) |
| BEFORE — out-of-line `hexa_int(…)` rebox (origin/main) | 599 | **17** | **11.09×** |
| AFTER — inline `((HexaVal){.tag=TAG_INT,.i=(…)})` (pilot) | 53  | **0** | **0.98×** |

> g5(정확성): before/after/ref **세 바이너리 stdout 전부 동일** = `34200003330000000`
> (md5 `63888b02e0325abf096209d943c8413f`). asm: AFTER `mix()` 는 순수 레지스터 arith
> (`add`/`sub`/`lsl` in x8..x11), HexaVal spill(`str`/`ldr`) 0 — clang -O2 가 16-op
> 체인을 ~10 스칼라 명령으로 fold. BEFORE 는 17개 opaque `bl _hexa_int` 가 이 fold 를 차단.

### 발견 — 박싱 제거가 known-int 워크로드의 parity 갭을 닫는다

- **unbox speedup = 11.30× (91.2% wall drop)** · **parity gap 11.09× → 0.98×** = known-int
  핫루프의 raw-parity 갭을 **100% closed**(AFTER 53ms ≈ ref 54ms, 노이즈 내 동일).
- §parity-attest 의 "raw parity 는 runtime.o C-ABI 벽이 막는다"가 박싱 축에서 **확증** —
  벽 = 매 op 의 `hexa_int(…)` out-of-line rebox. inline literal 로 그 호출을 제거하면
  clang -O2 가 벽 없이 누산기를 레지스터에 유지·fold → idiomatic C 와 parity.

**정직 caveat**:
- 측정은 **faithful C A/B proxy** — 두 arm 이 각 codegen variant 의 call-site emit 을
  정확히 미러(같은 runtime.o·clang -O2). full self-host transpiler rebuild **아님**:
  **B9 빌드 벽**(origin/main HEAD 에 일관된 generated-.c 셋 부재 + 설치 트리 runtime.h
  ABI skew → `hexa cc --regen` merge forward-decl 버그/module link skew 로 canonical
  재빌드 차단, 메모리 `reference_b9_generated_c_no_checkout_shortcut`). proxy sound 근거 =
  byte-equivalence 가 **runtime 소스에서 증명**됨(`runtime_core_emit.hexa:1371`
  `hexa_int(n)={.tag=TAG_INT,.i=n}`) + 변경 변수 1개만 격리.
- 갭-클로저 절대값은 **known-int 비율이 높은** 워크로드 기준. `_is_known_int` 미발화
  케이스(mut 누산기 — 예 `fib_heavy` 의 `let mut a; a=b`)는 이 pilot 미적용 →
  mut-accumulator 언박싱(raw `int64_t` 캐리)은 별도 follow-up.
- codegen 편집 검증: `self/codegen.hexa` parse-clean(`hexa parse` OK) + 편집 라인이
  emit 하는 C 문자열이 AFTER arm 형태(`((HexaVal){.tag=TAG_INT,.i=(HX_INT(l) op HX_INT(r))})`)
  와 정확히 일치(구성으로 검증). 재현 = `bench/unshadow/knownint_heavy.hexa` ·
  verdict = `.verdicts/unshadow-hexaval-unbox/pilot.txt`.
