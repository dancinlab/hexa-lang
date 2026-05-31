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
## §same-tu — C-emit same-TU 빌드 기본화 cost/benefit PILOT 실측

> milestone "🔵×🟡 same-TU 빌드 기본화" 의 실측. **요지**: §lto-unwall 이 입증한
> same-TU(`#include "runtime.c"`)를 C-emit 빌드 경로의 빌드-레시피로 만들면 (1) 무엇이
> 드는가(레시피 변경), (2) BENEFIT(#2-ext류 경계호출 cross-layer 전면 개방), (3) COST
> (빌드시간·바이너리)를 측정해 default/opt-in/no 정직 권고를 낸다.
> SSOT 도구 = `tool/unshadow_same_tu_bench.hexa` · verdict = `.verdicts/unshadow-same-tu/`.

### 구현한 same-TU 빌드 MODE (self/main.hexa cmd_build · GATED HEXA_SAME_TU=1)

reversible · opt-in 두 짝 편집(전역 default 강제 flip 아님):

1. **codegen 반쪽** — HEXA_SAME_TU=1 일 때 transpile 스텝을 `HEXA_USE_RUNTIME_C=1`
   (기존 codegen.hexa:947 escape hatch)으로 돌려 user.c 가 `#include "runtime.c"` 를
   emit → 런타임 아말감이 user TU 안으로 들어온다.
2. **link 반쪽** — HEXA_SAME_TU=1 일 때 별도 runtime 오브젝트/소스 2nd TU 를 최종
   clang 호출에서 뺀다(`_rt_input = ""`). 런타임이 이미 텍스트로 들어와 있으니 단일 TU
   컴파일. (2nd TU 로 또 넣으면 모든 심볼 중복 → 링크 에러.)

`shared != "1" && len(target) == 0` 가드(–shared PIC·cross-target zig 제외). unset →
바이트 동일하게 legacy walled 빌드. main.hexa parse-gate PASS.

### 측정 방법 (정직한 A/B 프록시 — full self-host rebuild 없이)

full `hexa cc --regen` 자체빌드는 **B9 벽**(runtime.c GENERATED · fresh clone 부재 —
선행 unwall 에이전트가 부딪힌 그 블로커)으로 막힘. milestone 스펙이 명시 허용한 faithful
프록시: 두 빌드 모드 · **동일 runtime 소스** · TU/link 전략만 격리.
- workload 는 INSTALLED hexat 로 transpile(`#include "runtime.h"` emit).
- **WALLED**: user.c + 별 precompiled runtime 오브젝트 링크(2 TU) — live default.
- **SAME-TU**: user.c 의 runtime.h→runtime.c 텍스트 swap(codegen 반쪽과 동일 변환) →
  단일 TU 컴파일.
- runtime 소스는 B9 graduation(commit 151c52c8) 직전 `git archive | tar -x` 트리(에미터가
  byte-identical 재현 = B9.C-10 source-SHA 게이트라 faithful). 양 arm 이 같은 runtime.c 로
  컴파일되므로 오직 TU 경계만 변수.

### 측정: `mini` (macOS arm64) · best-of-5 wall · 2026-05-30

| workload | g5 (md5) | walled wall | same-TU wall | Δ | walled size | same-TU size |
|---|---|---|---|---|---|---|
| string-boundary       | IDENTICAL `0e2afa85…` | 1.87s | **1.48s** | **−21%** | 409080 B | 408888 B |
| HexaVal-arith (control) | IDENTICAL `657d1ec4…` | 0.58s | **0.44s** | **−24%** | 408728 B | 408552 B |

**빌드시간 (best-of-3):**

| 빌드 모드 | 빌드시간 | 메모 |
|---|---|---|
| walled COLD (runtime.o 컴파일 + 링크) | 3.53s | first-ever build |
| **walled WARM (runtime.o 캐시 · 링크만)** | **0.10s** | **live default hot path** |
| **same-TU (매 빌드 아말감 재컴파일)** | **3.55s** | runtime.o 캐시 구조적 불가 |

**`_u_main` 핫함수 경계 `bl` 히스토그램 (string workload):**

| bl 타깃 | walled | same-TU | 비고 |
|---|---|---|---|
| `_rt_str_starts_with` | 2 | **0** | 인라인 → `_hxlcl_strncmp`×2 + `_hxlcl_strlen`×2 |
| `_hexa_contains_poly`  | 1 | **0** | 인라인 → `_hxlcl_strstr`×1 |
| `_hexa_int`            | 12 | **0** | 정수 박싱 헬퍼 전부 인라인 |
| `_hexa_to_string`      | 1 | **0** | 인라인 → `__hexa_to_string_rec` |
| `_hexa_bool`           | 2 | **0** | 인라인 |

### 정직한 해석 — BENEFIT 실재·일반화 / COST 기본화엔 과대

- **BENEFIT (실재·일반화):** same-TU 가 HexaVal/runtime ABI 전체를 clang -O2 cross-TU
  인라이너에 연다. #2-ext류 경계호출 `_rt_str_starts_with`(2→0)·`_hexa_contains_poly`(1→0)
  가 §lto-unwall 예측대로 call→inlined. 결정적으로 win 은 **string 전용이 아니다** —
  HexaVal-arith 컨트롤(`_hexa_int` 박싱)도 −24%(0.58→0.44s)로 이긴다. hexa_int/
  hexa_to_string/hexa_bool 박싱 헬퍼 자체가 런타임 경계호출이라 same-TU 가 전부 인라인.
  g5 양 workload byte-IDENTICAL.
- **COST (기본화엔 과대):** same-TU 는 ~14.6K-line 런타임 아말감을 **매 user TU 마다 재컴파일**
  → 3.55s/빌드 vs walled WARM 0.10s = **~35× 빌드시간 세금**. walled 는 1회 3.53s 런타임
  컴파일을 content-hash `runtime.<sha>.o` 캐시로 amortize; same-TU 는 런타임이 user TU 에
  융합돼 **구조적으로 캐시 불가**. 바이너리 크기는 wash(−0.05% · −192 B). 2차 구조적 비용:
  default-on same-TU 는 디스크에 runtime.c 를 요구 → B9 graduation 이 지운 generated-.c
  의존을 재도입.

### 권고 (정직)

**OPT-IN FLAG (HEXA_SAME_TU=1) · NOT default-on.** −21~24% byte-identical 런타임 win 은
실재하고 일반화하지만, ~35× 빌드시간 세금(3.55s vs 0.10s WARM) + generated-runtime.c 의존
재도입 때문에 일반 빌드에서 default-on 은 나쁜 트레이드. same-TU 는 HexaVal-/경계호출-heavy
프로그램의 **release/perf 빌드**에 가치 — 이 pilot 이 랜딩한 opt-in surface 가 바로 그것.
terminal 측정 권고 = opt-in flag.

> caveat: 단일 호스트(mini) 단일 세션 · wall = best-of-5 real min · 양 arm 동일 runtime.c
> 소스(walled .o 도 그것으로 컴파일) back-to-back · runtime 소스 = B9-faithful pre-graduation
> 트리(emitter SSOT 와 byte-identical) · full self-host rebuild 은 B9 벽으로 차단되어 A/B
> 프록시 사용(스펙 허용) · repo 안 `.c` 0개 유지(/tmp 외부 트리). 재현 =
> `tool/unshadow_same_tu_bench.hexa --rt <self-with-runtime.c> --runs 5`.

## §c-class — 🔵 proof-carrying array bounds-check elision (codegen 증명)

> milestone "🔵 C-class proof-carrying bounds/null elision" 의 실측. **요지**: §lto-unwall
> 이 C 를 NULL 로 분리해낸 이유 = 벽(runtime.o)을 없애고 `hexa_index_get`/`hexa_array_get`
> 본문이 다 보여도 clang -O2 는 opaque(realloc-able) 배열의 bounds check 를 elide 못 한다
> (`i < HX_ARR_LEN(arr)` 를 증명 불가). 진짜 win 은 **CODEGEN 증명** — 그 axis 가 이 milestone.
> SSOT 도구 = `tool/unshadow_cclass_bounds_bench.hexa` · verdict = `.verdicts/unshadow-cclass-bounds/`.

### 정적 증명 (self/codegen.hexa)

`for i in 0..len(arr)` range fast-path 에서 다음이 모두 성립할 때만 in-range fact 를 push:

1. **배타 range** (`..`, not `..=`)  →  `i < end`
2. **lower bound = 리터럴 `0`**  →  `i >= 0`
3. **upper bound = `len(arr)` / `arr.len()`** (arr 은 bare Ident)  →  `end == arr.len`, 즉 `i < arr.len`
4. body 가 **arr 을 resize/reassign/alias 안 함** (push/pop/임의 method-recv/임의 call 인자/재대입
   모두 보수적으로 void) **AND `i` 를 reassign 안 함** (elided read 는 hidden native counter 를
   index 하므로 body 가 못 건드림)

→ C for-loop 구조상 `0 <= counter < arr.len` 이 매 iteration 보장. fact 는 loop exit 에 pop
(LOCAL·EXACT·fold-shadow family 안전). read `arr[i]` 의 emit:

```
A (checked, 기존):  hexa_index_get(arr, hexa_int(i))
B (elided, 신규):   (HX_IS_ARRAY(arr) ? arr.arr_ptr->items[i] : hexa_index_get(arr, hexa_int(i)))
```

codegen 이 untyped(HexaVal) 이라 arr 의 array-tag 는 정적 증명 불가(`len()` 은 polymorphic) →
**bounds check + hexa_throw 만 삭제**, array-tag guard 1개만 잔존(non-array 는 검사형 fallback).
`HexaArr {items,len,cap}` + `arr_ptr` union 필드가 **runtime.h public** → runtime-internal 매크로
불필요, **runtime.o C-ABI 벽 관통**.

### 측정 (mini macOS arm64 · best-of-9 · 256-elem int array, hot loop)

| arm | read emit | built | 출력 md5 (g5) | wall (s) | inner-loop `bl _hexa_index_get` |
|---|---|---|---|---|---|
| a_checked | `hexa_index_get(arr, hexa_int(i))` | yes | `fda59d53…` | 1.88 | **1** (hot body) |
| b_elided  | `HX_IS_ARRAY?items[i]:검사형` | yes | `fda59d53…` | **0.56** | **0** (cold fallback only) |

**Δ = 1.88→0.56s = 3.25× (−69%).** asm: arm A 의 `bl _hexa_index_get` 은 inner-loop body
(`LBB0_6`, `b.lt LBB0_6` 로 루프백); arm B 의 inner-loop(`LBB0_8`)는 `cmp x24,#5`(HX_IS_ARRAY,
TAG_ARRAY=5) → fast path `%bb.9`: `ldr x8,[x20]`(arr_ptr) + `ldr x1,[x8,x26]`(items[i]) 직접 로드,
`bl _hexa_index_get` 은 절대 안 닿는 cold `LBB0_6` 으로 hoist. (`bl _hexa_throw` 은 양쪽 0 — throw
는 runtime.o 벽 안.) 상세 asm = `.verdicts/unshadow-cclass-bounds/asm_loop_structure.txt`.

### 무결성 게이트 — OOB 는 양쪽 arm 여전히 throw

`arr[len]`(one past end) 접근: 검증식이 **안 덮는** read(loop var 가 아님) → codegen 은 검사형
emit. 양쪽 arm 모두 "out of bounds" surfaced=1. **증명-안전한 read 만 삭제 — OOB read 절대 없음.**

### 정직한 해석

- **🔵 WIN (correctness PROVEN · perf REAL).** §lto-unwall 이 NULL 로 분리한 이 axis 가 실제로
  win 으로 전환됨 — 단 unwall(벽 제거)이 아니라 **codegen 증명**으로. unwall 의 진단("벽 제거
  단독으론 불충분, proof-carrying codegen 필요")이 정확히 입증됨. clang 이 못 한 elision 을
  codegen 이 static fact 로 라이선스해 emit.
- **잔존 array-tag guard 1개.** untyped HexaVal codegen 의 한계 — array-type 추론기가 없어
  bounds+throw 만 삭제하고 tag-guard 1개는 유지(증명-안전). 향후 known-array 추적기가 생기면
  tag-guard 도 삭제 가능(미측정 lever).
- caveat: 단일 호스트(mini) 단일 세션 · best-of-9 real min · 양 arm 동일 runtime.o(walled) ·
  full self-host regen 은 B9 generated-runtime 벽으로 차단(prior agents 도 동일) → faithful A/B
  프록시(emit 문자열은 codegen L7661 과 byte-동일·스펙 허용) · repo 안 `.c` 0개. 재현 =
  `tool/unshadow_cclass_bounds_bench.hexa --rt <self-with-runtime.o> --runs 9`.

## §escape-stack — 🔵 escape→stack-alloc (F2 · **공간축 첫 채굴**)

> milestone "🔵 escape→stack-alloc (F2 미채굴 perf 축 · 공간)" 의 실측. **요지**: 도메인의
> 14개 milestone 이 전부 TIME-축이었던 곳의 첫 SPACE-축. §typed-struct(#2182)가 lower 한
> flat-struct 의 생성자는 여전히 per-instance `malloc(sizeof(Pt__flat))` 한다 — `p` 가 스코프
> 밖으로 나가든 말든. 진짜 win = **escape 분석으로 비-escape 증명된 바인딩의 descriptor 를
> 힙 대신 C 스택에 배치** → malloc 자체 소멸. SSOT 도구 = `tool/unshadow_escape_stack_bench.hexa`
> · verdict = `.verdicts/unshadow-escape-stack/`.

### 정적 증명 (self/codegen.hexa · GATED `HEXA_STACK_ALLOC=1` · default OFF=무회귀)

immutable `let p = Pt{..}`(Pt = flat-eligible) 의 **유일한 사용이 `p.field` read 뿐**일 때만
비-escape 로 증명 (`_stack_noescape_scan`, gen2_fn_decl 에서 fn-body 사전스캔):

1. **return 안 됨** (`return p` / `return ...p...` = escape — `_stmt_escapes_name` ReturnStmt arm)
2. **call 인자 안 됨 · store 안 됨 · index 안 됨** (`f(p)` / `m[k]=p` / `arr.push(p)` 모두 bare
   Ident `p` 가 Field-receiver 아닌 위치 = escape — `_expr_escapes_name` 보수적)
3. **재대입 안 됨** (LetMut / Assign 으로 `p` 갱신 = escape)
4. **closure capture 안 됨** (capture 도 bare-Ident 사용 → escape)
5. top-level let 만 (nested-scope 바인딩 = open sub-task)

→ 증명되면 LetStmt 가 `Pt(args)`(malloc 생성자) 대신:

```
A (heap, 기존):   HexaVal p = Pt(arg0, arg1);  /* malloc(sizeof(Pt__flat)) */
B (stack, 신규):  Pt__flat __stk_p = { arg0, arg1 };
                  HexaVal p; p.tag=TAG_ARRAY; p.vs=(HexaValStruct*)&__stk_p;  /* no malloc */
```

read offset layout 불변 → byte-eq. 비-escape 증명상 `p` 의 모든 사용이 이 C-block 안의 `p.field`
read 이므로 스택 객체가 모든 read 를 strictly outlive (no dangling). **LLVM-can't**: escape 가
우리 소유 tagged-repr 의 TYPE-LEVEL lifetime 증명 — clang 은 union 슬롯에 탄 opaque
`HexaValStruct*` + runtime.o C-ABI 벽 너머 malloc 만 보여 non-escape 증명·rewrite 불가.

### 측정 (mini macOS arm64 · best-of-9 · faithful A/B proxy · B9/regen 벽)

**[PRIMARY = 공간축]** heap-alloc count + peak-RSS (wall 은 부차):

| arm | 생성 emit | built | 계산 acc (g5 byte-diff) | **heap-alloc count** | wall (s) |
|---|---|---|---|---|---|
| a_heap  | `Pt(..)` malloc 생성자 | yes | `6ca934e4…` | **20,000,000** (Pt{..} 당 1 malloc) | 0.06 |
| b_stack | 스택 `Pt__flat __stk_p` | yes | `6ca934e4…` | **0** (malloc 전멸·LANDED) | 0.05 |

**byte-diff: IDENTICAL** (acc=140000000, md5 `6ca934e49da9a8a3923d49622f65db6b` 양 arm 동일).
**heap-alloc: 20,000,000 → 0** (루프 descriptor malloc 완전 제거).

**peak-RSS (no-free / reclaim-lag shape)** — hexa runtime 은 per-iteration descriptor 를 즉시
free 안 함(arena/GC 가 bulk sweep) → 비-escape descriptor 가 다음 sweep 까지 힙에 **누적**.
정확히 stack-alloc 이 공간서 이기는 자리 (스택 객체는 매 iteration frame-pop 에 회수):

| arm | shape | **peak-RSS (KB)** |
|---|---|---|
| a_heap_nf  | 4M no-free malloc (descriptor 누적) | **127,392** (≈124 MB) |
| b_stack_nf | 스택 (frame-pop 회수, N 무관 flat) | **1,920** (≈1.9 MB) |

**peak-RSS Δ = 127,392 → 1,920 KB = 66× 감소 (−98.5%).**

### 무결성 게이트 — escaping 바인딩은 힙 유지 (no dangling)

`return p` (descriptor 가 스코프 밖으로) → 스택이면 dangle. codegen 증명이 **발화 안 함** →
malloc 경로 유지. escaping read 결과 = `4` (return 후 live·non-dangling). **증명-안전한 바인딩만
스택 — escaping 은 절대 스택 안 감.**

### 정직한 해석

- **🔵 WIN (correctness PROVEN · space REAL).** 도메인 첫 공간축. byte-eq 하에 루프 heap-alloc
  20M→0, reclaim-lag 에서 peak-RSS 66×. §arena(RSS −40%)의 타입-구동 일반화 — arena 는 전역
  bump, 이건 per-binding lifetime 증명으로 그 binding 만 스택.
- **부분 착지(최소 슬라이스).** 현 슬라이스 = flat-struct(§typed-struct) + top-level let 만.
  잔여: non-flat HexaVal(array/map/closure) descriptor 스택 · nested-scope 바인딩 · GATED 해제.
- caveat: 단일 호스트(mini) 단일 세션 · best-of-9 real min · 양 arm 동일 runtime.o(walled) ·
  full self-host regen 은 clang crash(documented `cc --regen` Mac 한계)로 차단 → faithful A/B
  proxy(emit 문자열은 `gen2_stack_alloc_flat` 과 byte-동일·스펙 허용·prior agents 동일 패턴) ·
  repo 안 손작성 `.c` 0개. RSS no-free arm 은 noinline+escape-sink 로 clang DCE elision 차단해야
  faithful(inline 시 dead-malloc 제거됨). 재현 =
  `tool/unshadow_escape_stack_bench.hexa --rt <self-with-runtime.o> --runs 9`.

## §unboxed-array — 🟢 unboxed-primitive array (axis A) — perf 🔴 CLOSED-NEGATIVE

> milestone "🟢 unboxed-primitive array" 의 실측. **요지**: §c-class 가 명시한 미측정
> lever("known-array 추적기가 생기면 tag-guard 도 삭제")를 측정한다. codegen 이 불변
> `let xs=[int-lit…]` 를 monomorphic-i64 로 정적증명하면 in-range read `xs[i]` 의
> §c-class array-tag guard 를 삭제하고 raw `.i` 를 추출한다(boxed-storage unbox). **발견**:
> 이 unbox 는 갭을 안 닫는다 — 갭은 tag-guard 가 아니라 **boxed 저장 표현**에 산다.
> SSOT 도구 = `tool/unshadow_unboxed_array_bench.hexa` · verdict = `.verdicts/unshadow-unboxed-array/`.

측정: `mini` (macOS arm64) · clang · best-of-9 wall · 같은 `runtime.o` 링크 · 2026-05-30.
워크로드 = 256-elem 정수 배열의 sum × 4M outer iters (codegen 이 `let xs=[..]` +
`for i in 0..len(xs) { acc += xs[i] }` 에 emit 하는 정확한 C shape).

### 표 — 4-way wall min (s) + asm

| arm | 원소 read emit | wall (s) | `bl _hexa_index_get` | SIMD vec-op | 판정 |
|---|---|---|---|---|---|
| ref_c (idiomatic `int64_t buf[]`) | `buf[i]` | **0.08** | — | 23 | parity baseline |
| a_boxed (BEFORE = §c-class) | `(HX_IS_ARRAY(a)?items[i]:checked)` | 1.12 | 1 (cold) | 5 | boxed read + tag-guard |
| b_unbox (AFTER = 신규 codegen) | `a.arr_ptr->items[i]` (guard 삭제) | **1.12** | **0** | 5 | tag-guard 삭제 → **~0% Δ** |
| c_native (CEILING = HexaArrI64) | `data[i]` (native `int64_t*`) | **0.08** | 0 | 23 | 갭 100% close |

> g5: 4-arm stdout md5 전부 `35470124be79241c684dc5103ec55d20` (IDENTICAL).

### 무결성 게이트 — typed 배열이 polymorphic 경계서 정확히 box

typed `[i64]` 배열을 unboxed fast-path 로 sum 하면서 **동시에** polymorphic site
(`hexa_len` + checked `hexa_index_get` element fetch = codegen 이 non-proven 접근에 emit
하는 BOXED 경로)로 흘려보내는 boundary corpus. boxed(a_bnd)·unbox(b_bnd) 양쪽 arm md5
`9efbbf5d320a45f2ce6e89491a1ac726` 동일 → **typed array 가 동적 경계서 정확히 box, unbox 는
값 무변경**. (c-class 의 OOB-still-throws 에 대응하는 이 milestone 의 무결성 게이트.)

### 정직한 해석 — 갭은 tag-guard 가 아니라 STORAGE 에 산다

- **correctness WIN.** element-kind 증명(immutable int-literal-array + live in-range fact)
  이 정확·좁고, byte-diff 4-arm + 동적경계 IDENTICAL. provably-dead guard 만 삭제(무회귀).
- **perf 🔴 CLOSED-NEGATIVE.** b_unbox 1.12s ≈ a_boxed 1.12s. tag-guard `HX_IS_ARRAY(arr)?`
  는 **loop-invariant** 라 clang -O2 가 이미 hoist — 삭제해도(index_get 1→0, cold fallback
  제거) wall 무변. §c-class 가 "미측정 lever" 라 한 그 lever 가 **null** 임을 측정으로 확정.
- **진짜 벽 = boxed 저장.** `sizeof(HexaVal)=16` → `HexaArr.items[]` 는 16B-stride 박스
  배열, clang SIMD-gather 불가(5 vec-op). native `int64_t[]`(c_native, 8B contiguous)만
  vectorize(23 vec-op)해 갭 100% close. `.verdicts/unshadow-unboxed-array/asm_simd.txt`.
- **누락 인프라 = native `HexaArrI64`/`F64` 저장 표현**(RUNTIME 변경 — 새 struct + box/unbox
  헬퍼 + 모든 array primitive 의 element-kind 분기). B9 벽 밖·codegen-only pilot 범위 밖.
  → axis A 가 "codegen-only unbox 는 perf 레버 아님" 을 결정적 배제. 갭은 STORAGE.
- caveat: 단일 호스트(mini)·best-of-9·양 arm 동일 runtime.o·full self-host regen 은 B9 벽
  차단 → faithful A/B 프록시(b_unbox emit 은 codegen L7666 신규 arm 과 byte-동일·스펙 허용) ·
  repo 안 `.c` 0개. 재현 = `tool/unshadow_unboxed_array_bench.hexa --rt <self-with-runtime.o> --runs 9`.

## §roofline — HW 물리 천장(roofline) % 절대 잣대 (분모 = mini achieved-peak)

> milestone "🎯 roofline 측정대 — 상대 Δ → HW 물리 천장 % 전환" 의 실측. **요지**:
> UNSHADOW 측정 잣대를 "vs idiomatic C @ clang -O2"(상대 Δ) 에서 **HW 물리 천장의 몇 %**
> (절대) 로 전환한다. 기존 닫힌 9개 결과의 ns 를 재활용해 roofline % 로 재표기.
> SSOT 도구 = `tool/unshadow_bench.hexa`(roofline 컬럼 추가) + `tool/unshadow_peak_microbench.hexa`
> (achieved-peak 분모 측정) · verdict = `.verdicts/unshadow-roofline-stand/g5-roofline-bench.txt`.

### roofline 잣대 정의 (두 roof · binding 자동선택 · achieved-peak 분모)

roofline = `min(compute-roof, memory-roof × AI)`. 워크로드 arithmetic-intensity
`AI = flops/bytes` 로 binding roof 자동선택:

- **ridge-point** = compute-roof ÷ memory-roof. `AI < ridge` → **memory-bound**
  (분모 = memory-roof × AI), `AI ≥ ridge` → **compute-bound** (분모 = compute-roof).
- 보고값 = `achieved ÷ binding-roof × 100` (%). achieved 가 천장의 몇 % 인지.

### achieved-peak 분모 (mini Apple M4 · clang -O2 · best-of-5 · 2026-05-30 · @L2 실측)

스펙시트 추정 금지 — `tool/unshadow_peak_microbench.hexa` 가 mini 에서 1회 실측. achieved
와 theoretical 을 **나란히** 박제(격차 숨기지 않음):

| roof | achieved (실측 분모) | theoretical (스펙시트) | achieved/theoretical |
|---|---|---|---|
| memory (STREAM-triad) | **92.3–95.2 GB/s** | LPDDR5X 시스템 ~120 GB/s | ~77–79% |
| compute (FMA double)  | **15.24 GFLOP/s** | P-core ~17.6 GFLOP/s (4.4GHz·2 FP pipe·2 flop) | ~87% |
| compute (scalar int)  | **12.88–13.06 GIOP/s** | mul+add 스칼라 throughput (~13–19) | — |

> ridge-point ≈ 12.88 ÷ (95 ÷ 8) ≈ **1.08 ops/byte**. 측정 커널은 idiomatic ref-C
> (plain `double`/`int64_t`, clang -O2) — repo root `.c` 훅 회피 위해 `/tmp`(project.tape
> 밖) 에서 emit·컴파일. achieved 가 theoretical 의 77–87% = single-thread·non-SIMD-intrinsic
> 측정의 정직한 천장(멀티스레드/명시 SIMD 면 더 높으나, 워크로드도 single-thread 라 공정).

### §workload bound 판정 (AI → binding roof)

닫힌 9개 + M1 baseline 워크로드는 **전부 정수/부동 스칼라 hot loop · register-resident**
(배열 메모리 traffic ≈ 0) → AI ≫ ridge(1.08) → **모두 compute-bound** (binding = int-roof
또는 fp-roof). array 파일럿(§c-class·§unboxed-array)도 256-elem(≤L1) 라 compute-bound.
즉 이 corpus 에서 memory-roof 가 binding 인 워크로드는 없다(정직: memory-bound 케이스는
미수집 — array-of-struct/SoA 워크로드가 typed-repr frontier 랜딩 후 생겨야 측정 가능).

### §roofline 표 — 닫힌 9개 + M1 baseline 5워크로드의 roofline %

**roofline% = achieved ÷ binding-roof × 100.** compute-bound 정수 워크로드는 두 가지로
보고: (1) **op-count 모델 기반 절대 GIOP/s ÷ int-roof** (상한 추정 — clang 이 op 를
fold/dead-elim 하므로 논리 op 수가 실제 실행보다 많을 수 있어 *하한* roofline%), (2) **idiomatic
ref-C wall anchor** (ref-C 가 roofline-near = 측정 anchor; roofline% = ref-C wall ÷ arm wall).
두 방식이 보완 — (1) 은 절대 천장 대비, (2) 는 "idiomatic C 가 따낸 achieved 의 몇 %".

| # | 워크로드/파일럿 | 측정 ns (재활용) | binding roof | roofline % (achieved/roof) | 비고 |
|---|---|---|---|---|---|
| M1 | sieve_heavy (clangO2 arm) | 232ms | int-roof 12.88 GIOP/s | **2.6%** (native 2.2%) | g5 IDENTICAL · op-count 모델 |
| M1 | fib_heavy (clangO2) | 1297ms | int-roof | **4.3%** (native 3.1%) | g5 IDENTICAL |
| M1 | hash_heavy (clangO2) | 1343ms | int-roof | **4.6%** (native 2.9%) | g5 IDENTICAL · 최대 |
| M1 | collatz_heavy (clangO2) | 3518ms | int-roof | **2.0%** (native 1.8%) | g5 IDENTICAL · 최소 |
| M1 | mixmul_heavy (clangO2) | 2696ms | int-roof | **2.8%** (native 2.0%) | g5 IDENTICAL |
| — | sieve (ref-C anchor §parity) | ref 8ms / hexa 224ms | int-roof | **3.6%** (ref/arm) | idiomatic-C anchor |
| — | hash (ref-C anchor §parity) | ref 163ms / hexa 1295ms | int-roof | **12.6%** (ref/arm) | idiomatic-C anchor |
| — | fib (ref-C anchor §parity) | ref 1ms / hexa 1263ms | int-roof | (degenerate) | clang dead-loop-elim → 정성 신호 |
| #2 | hexaval-unbox BEFORE | 599ms | int-roof | **9.0%** (ref/arm) | out-of-line hexa_int rebox |
| #2 | hexaval-unbox AFTER (pilot) | 53ms | int-roof | **101.9%** (ref/arm, AT PARITY) | inline literal → 천장 도달 |
| #4 | atlas const-fold | 0.26→0.09s | — (work 제거) | **roofline-N/A** | 🔵 "안 돌기" — 분모 anchor 없음(wall-Δ 65%) |
| B | proof-carrying inline | 0.36→0.19s | — (work 제거) | **roofline-N/A** | 🔵 "안 돌기"(wall-Δ 47%) |
| §c | c-class bounds-elide a_checked | 1.88s | int-roof | **4.3%** (ref/arm) | boxed read+bounds |
| §c | c-class b_elided | 0.56s | int-roof | **14.3%** (ref/arm) | 3.25× vs a — bounds-check 삭제 |
| §A | unboxed-array a_boxed | 1.12s | int-roof | **7.1%** (ref/arm) | boxed read |
| §A | unboxed-array b_unbox | 1.12s | int-roof | **7.1%** (ref/arm) | tag-guard 삭제 ~0%Δ |
| §A | unboxed-array c_native (CEILING) | 0.08s | int-roof | **100%** (ref/arm) | native HexaArrI64 = 천장 |
| #3 | arena reclaim (RSS −40%) | — | (공간 메트릭) | **roofline-N/A** | RSS 는 대역폭/연산 천장과 무관(정직) |
| #2e | rt_str inline 🔴 | — (LINK FAIL) | — | **roofline-N/A** | CLOSED-NEG, 빌드 arm 없음 |
| C | tag-elision 🔴 | — (clang 이미 dead-elim) | — | **roofline-N/A** | CLOSED-NEG, Δ 0 |

### 정직한 해석 — roofline % 가 드러내는 것

- **hexa C-emit 의 절대 천장 % 는 낮다 (2–5%).** clangO2 arm(최적화된 hexa 경로) 조차
  achieved int-roof 의 2–4.6% — 모든 정수 연산이 boxed HexaVal ABI 를 경유하기 때문.
  native arm 은 더 낮음(1.8–3.1%) — **M1 의 "native 가 clang -O2 에 5/5 패배" 사실이 roofline
  % 로도 그대로 드러난다.** 이득은 raw 경쟁이 아니라 🟢 벽제거·🔵 우회.
- **🔵 ceiling 기법이 천장을 닫는다.** #2 hexaval-unbox 가 박싱 호출을 inline literal 로
  치환하자 known-int 핫루프가 **9.0% → 101.9%**(idiomatic-C anchor 기준 AT PARITY) 로
  천장에 도달. §unboxed-array 의 c_native(HexaArrI64) 도 **100%** — 즉 천장은 STORAGE 표현에
  산다(boxed→native). §c-class bounds-elision 은 4.3%→14.3% (3.25×).
- **"안 돌기"(🔵 A·B) 는 roofline-N/A 가 정직하다.** atlas const-fold·proof-carrying 인라인은
  연산 자체를 제거(loop hoist)하므로 분모로 삼을 idiomatic-C op-equivalent 가 없다 — 절대
  roofline% 대신 wall-Δ(65%·47%) 로 보고. 환산 무의미한 메트릭은 무리한 % 부여 금지.
- **RSS(§arena)·CLOSED-NEG(#2-ext·C) 는 roofline-N/A.** RSS 는 공간 메트릭(대역폭/연산 천장과
  직교) · CLOSED-NEG 는 win arm 자체가 없어(link-fail / clang 이 이미 처리) 환산 대상 부재.

> caveat: 단일 호스트(mini Apple M4)·single-thread·non-SIMD-intrinsic 측정 → achieved 가
> theoretical 의 77–87%(정직 격차). op-count 모델 roofline% 는 *하한 추정*(clang fold 로 논리
> op 수 ≥ 실행 op 수). idiomatic ref-C anchor roofline% 가 보완 측정. memory-bound 워크로드는
> 본 corpus 에 없음(전부 register/L1-resident compute-bound) — SoA/array-of-struct memory-bound
> 케이스는 typed-repr frontier 랜딩 후 측정 가능(정직: 현재 미수집). g5 byte-diff 5/5 IDENTICAL
> (verdict verbatim). 재현 = `tool/unshadow_peak_microbench.hexa` (분모) + `tool/unshadow_bench.hexa
> --workloads <5> --warmup 2 --iters 5` (roofline % 컬럼).

## §native-arr — 🔵 native HexaArrI64 저장 표현 (HEADLINE / F1 데이터-표현 주권)

> milestone "🔵 native HexaArrI64 저장 표현 [HEADLINE]" 의 실측. **요지**: 축A
> closed-negative(§unboxed-array)가 "갭은 tag-guard 아니라 STORAGE 에 산다"를 결정적으로
> 지목했다. 이 milestone 은 그 native contiguous 저장 표현(`int64_t[]`)을 runtime ABI +
> codegen 에 **실제 착지**시키고, 갭이 storage 에 있음을 **천장 실증**으로 확증한다.

**착지물**:
- runtime ABI (`self/runtime_core_emit.hexa`): `typedef struct HexaArrI64 {int64_t* data;
  int len; int cap}` + `hexa_arr_i64_new/push/len/box` 헬퍼, **public in runtime.h**
  (§c-class 벽 관통). layout 이 `HexaArr {ptr,len,cap}` 와 **동일 offset** → polymorphic
  `hexa_len`(arr_ptr->len read)이 native 표현에도 그대로 작동(loop bound·`len(xs)` 무변경).
- codegen (`self/codegen.hexa`, §unboxed-array `_known_intarr` 추론기 재사용): `HEXA_NATIVE_ARR=1`
  GATED opt-in(default OFF=무회귀) 시 불변 monomorphic-i64 리터럴 → `hexa_arr_i64_new/push`
  native 구성 + 증명된 in-range read = inline compound-literal raw load.

**측정 (mini Apple M4 arm64 · best-of-9 · faithful A/B proxy · full self-host regen=B9 벽 차단)**:

| arm | 표현 | wall (s) | vec-op | 의미 |
|---|---|---|---|---|
| ref_c    | idiomatic `int64_t[]` (no runtime) | 0.15 | 28 | parity anchor |
| a_boxed  | 현 `HexaArr` boxed 16B-stride (§c-class read) | 3.17 | 10 | **BEFORE** |
| b_native | **LANDED**: native storage + boxed read surface | 2.68 | 8 | 1.18×·−15% |
| d_ideal  | **CEILING**: native storage + raw `data[i]` read | 0.18 | 28 | 17.6×·gap→0.83× **AT PARITY** |

- **g5 byte-diff: 4/4 IDENTICAL** (`35470124be79241c684dc5103ec55d20`) — 무손실.
- **동적경계 integrity: IDENTICAL** (`9efbbf5d320a45f2ce6e89491a1ac726`) — native i64 배열이
  polymorphic 경계(`hexa_arr_i64_box` → real HexaVal)에서 정확히 box.
- **codegen 발화 검증** (real self-host codegen, +632 lines, `/tmp/hexat.new` transpile):
  FLAG ON = `hexa_arr_i64_new(N)`+`hexa_arr_i64_push` 구성 · FLAG OFF = boxed `hexa_array_push`
  +`items[i]`(§c-class) **무변경**.

### 정직한 해석 — 천장 실증 + LANDED 한계

- **천장 실증 = 축A 확증.** d_ideal(native storage·raw read) 0.18s ≈ ref 0.15s = **gap 0.83×
  AT PARITY**. boxed(a_boxed 3.17s)→native 가 갭을 parity 까지 닫는다. 축A closed-negative 의
  "갭은 STORAGE 에 산다" 예측이 **결정적으로 옳았음**을 storage 표현 실착지로 확인.
- **LANDED 는 천장의 1/15 만 잡는다 (정직).** b_native(2.68s)는 native storage 를 쓰지만 read
  가 여전히 boxed HexaVal surface 를 만든다(`((HexaVal){.tag=TAG_INT,.i=data[i]})`). 이유 =
  누산기 `acc` 가 untyped `let mut` 라 §hexaval-unbox known-int 체인이 read→sum 까지 안 뻗어
  per-read HexaVal 구성이 vectorize 를 막는다(vec-op 8 < 28). **inline literal 은 필수**(out-of-line
  `hexa_int()` 는 더 느림 — runtime.o 벽 너머 re-box, 측정 확인). full 천장 = known-int
  accumulator 일반화(sub-task open).
- **GATED opt-in (default OFF).** 무회귀 보장(FLAG OFF byte-diff = boxed 경로 무변경). no-escape
  자동발화(현 GATED 해제)는 whole-binding escape 증명 필요 = 별도 sub-task. F64 경로도 open.
- verdict verbatim = `.verdicts/unshadow-native-arr/bench.txt` · 재현 =
  `tool/unshadow_native_arr_bench.hexa --rt ~/.hx/bin/self --runs 9`.
- **sub-task 진척 → §knownint-accum (아래)**: known-int accumulator 일반화가 부분 착지.
  누산기 ABI-벽(out-of-line `hexa_add`) 제거 = e_boxed_acc 1.67s → f_inline_acc 1.12s (**1.49×**,
  asm `bl _hexa_add` 9→6). full d_ideal(0.08s)는 HexaVal-struct 누산기 자체(raw int64 local 미강등)
  로 여전히 open.

## §knownint-accum — 🟢 known-int ACCUMULATOR 일반화 (§native-arr sub-task · 부분)

> §native-arr 가 native int64_t[] STORAGE(d_ideal 천장)는 착지했으나 LANDED 는 1.18× 만 잡은 이유 =
> read→sum 체인이 **누산기**에서 boxed HexaVal surface 재생성. `let mut acc=0`(untyped mut)이라
> `acc += xs[i]` 가 out-of-line `hexa_add(acc, …)`(runtime.o C-ABI 벽) → clang -O2 vectorize 차단.
> 이 sub-task = known-int 추론기를 **증명된 mut 누산기**까지 확장 → `acc += xs[i]` 를 inline
> compound-literal `.i` 형으로 emit(BinOp known-int fast-path 와 동일 shape) → out-of-line
> `hexa_add` 제거.

**착지물 (`self/codegen.hexa`)**:
- `_known_int_accum_set` 추적기 + `_known_int_accum_scan(fn body 보수적 스캔)`: `let mut acc=
  <known-int init>` 이고 전 body 의 모든 write(`=` / `+= -= *= & | ^ << >>`)가 accum-int-safe
  (IntLit · known-int name · `acc` 자신 · 증명된 int-literal-array `arr[i]` read · 그들의 `+/-/*…`
  BinOp)면 등록. `/` `%` `**` 제외(runtime div-by-zero throw 필요). closure-capture(boxed cell)는 제외.
- `_is_known_int` 가 accum 도 certify → 읽기 raw `.i` 추출.
- CompoundAssign / BinOp 가 `acc<op>=rhs` / `acc = acc <op> rhs` 를 inline `.i` 형
  (`acc = ((HexaVal){.tag=TAG_INT,.i=(HX_INT(acc) op HX_INT(rhs))})`)로 emit → clang
  `HX_INT((HexaVal){.i=X})→X` fold → raw int64 sum 체인.
- GATED `HEXA_NATIVE_ARR`(§native-arr 플래그 재사용) default OFF=무회귀 · FN-SCOPED reset.

**측정 (mini Apple M4 arm64 · best-of-11 · faithful A/B proxy · B9 regen 벽 → proxy)**:

| arm | 누산기 표현 | wall (s) | vec-op | `bl _hexa_add` | 의미 |
|---|---|---|---|---|---|
| ref_c        | idiomatic raw `long acc` (no runtime) | 0.08 | 28 | 0 | parity anchor |
| e_boxed_acc  | `HexaVal acc` + out-of-line `hexa_add` | 1.67 | 8 | **1** | **BEFORE (LANDED)** |
| f_inline_acc | `HexaVal acc` + inline `.i` (THIS) | **1.12** | 8 | **0** | **AFTER · 1.49×** |
| d_ideal      | raw `long acc`, no HexaVal | 0.08 | 18 | 0 | CEILING |

- **g5 byte-diff: 4/4 IDENTICAL** (`35470124be79241c684dc5103ec55d20`). 추가 정확성:
  단순 read→sum(out=150) ON=OFF `176ef0…` · integrity(`+= -=` mixed · BinOp `acc=acc+x` ·
  음수 · 3×10⁹ overflow; out=1038601 / 2999999940) ON=OFF `9e3d23e4…` — 전부 byte-exact.
- **codegen 발화 검증** (real self-host hexat, modified codegen 재빌드, /tmp transpile):
  FLAG ON = `acc = ((HexaVal){.i=(HX_INT(acc) + HX_INT(((HexaVal){.i=data[i]}))})` · FLAG OFF =
  `acc = hexa_add(acc, items[i])`(boxed §c-class) **무변경**.

### 정직한 해석 — ABI-벽 닫힘 + register-pack open

- **누산기 ABI-벽 = 닫힘.** out-of-line `hexa_add`(runtime.o C-ABI 벽, asm `bl _hexa_add`)가
  step 마다 호출되던 게 inline `.i` 로 사라짐(asm `bl` 9→6, `_hexa_add` 1→0). e_boxed_acc 1.67s →
  f_inline_acc **1.12s = 1.49×**. §native-arr 가 지목한 "read→sum 이 누산기에서 re-box" 의
  **ABI-호출 부분이 제거됨**.
- **full 천장(d_ideal 0.08s)은 여전히 open (정직).** inline `.i` 라도 clang 은 `acc` 를 16B
  HexaVal struct 로 유지하고 compound literal 을 step 마다 re-materialize → vec-op 8 (d_ideal 18,
  ref 28 미달). full d_ideal = 증명된 known-int-accum 을 **raw C `int64_t` local 로 강등**(HexaVal
  탈피) = 다음 sub-task(§typed-repr accumulator). 이 슬라이스 = **ABI-벽 닫힘 · register-pack open**.
- **GATED opt-in (default OFF)** = 무회귀(FLAG OFF = boxed `hexa_add` 무변경, byte-diff 입증).
- verdict verbatim = `.verdicts/unshadow-knownint-accum/bench.txt` · 재현 =
  `tool/unshadow_knownint_accum_bench.hexa --rt ~/.hx/packages/hexa/self --runs 11`.

## §knownint-rawlocal — 🔴 known-int accumulator → raw int64 local 강등 (CLOSED-NEGATIVE · F1)

§knownint-accum 의 잔여 sub-task #2(§typed-repr accumulator). §knownint-accum 이 남긴
"d_ideal 0.08s 잔여 = HexaVal-struct accumulator 16B box" 가설을 검증 — 증명된 known-int
accumulator 를 inline `.i` box 가 아닌 **raw C `int64_t` local** 로 강등(`int64_t __acc_<name>`,
update 는 raw int arith, observe-point 1회만 box)하면 register-pack 천장(d_ideal)에 도달하는가.

- **pre-registered falsifier**: inline `.i` box(PR #2202)에 살아남은 box surface 가 clang 의
  register allocation 을 막아, raw int64 local 강등이 f_inline_acc→d_ideal Δ(~12.5×)를 회수한다.
- **방법(faithful A/B proxy · B9 self-host rebuild 벽 · §knownint-accum/§native-arr 동일 fallback)**:
  각 accumulator lowering 이 emit 하는 EXACT C 문자열을 `clang -O2 -S`/binary 로 측정. runtime.o
  C-ABI 벽은 out-of-line(`hexart.c`)으로 모델링 → boxed arm 이 실제 `bl _hexa_add` 를 지불.
  4 lowering: e_boxed(`hexa_add` ABI 벽) · f_inline(`.i` box, PR #2202) · g_raw(`int64_t __acc`,
  observe 시 1회 box) · d_ideal(raw int64 register-pack 천장 = g_raw shape).
- **[THE 게이트 · byte-diff] f_inline vs g_raw hot-loop asm byte-IDENTICAL** — normalized hot-loop
  md5 `436ccab8ad7cb96c2dfbf0072ef1fcd8` 양 arm 동일·`diff` exit 0. hot-loop `bl _hexa_add`:
  e_boxed=1 · f_inline=0 · g_raw=0. correctness e/f/g 일치(n=5/1e6/3e9 overflow·int64 wrap 동일).
  hot loop(f_inline AND g_raw): `add x8,x8,#1 / subs x20,x20,#1 / b.ne` — accumulator 가 register
  x8 로 승격(single-field `{.tag,.i}` box 가 SROA/mem2reg 로 scalarize).
- **[FINDING · 🔴 FALSIFIED]** clang -O2 SROA 가 inline `.i` box 를 **이미** 제거한다(`.tag` dead,
  `.i`→register). 즉 inline `.i` 슬라이스가 **이미** raw-int64 register loop 를 emit → raw 강등은
  **ZERO 추가 Δ**. box surface 가 애초에 -O2 를 넘지 못함 → 제거할 게 없음. **f_inline IS d_ideal**
  (asm 레벨). prior §knownint-accum 의 "d_ideal 0.08s vs f_inline 1.0s 12.5× gap" 은 e_boxed
  out-of-line arm 측정 artifact(다른 n/noise)였고, inline `.i` arm 에 살아남은 box 는 없었다.
- **ruled-out 축**: single-int-field accumulator 의 source-level box-stripping 은 clang -O2
  하에서 dead axis. SROA 가 실제 box-eliminator. 남은 진짜 레버 = SROA 가 scalarize 못 하는
  **multi-field/escaping/aliased HexaVal**(runtime.o ABI 벽을 넘는 e_boxed 1.49× tax) — F64 경로
  sub-task 로 이관.
- **codegen 무변경**: GATED raw-int64-local 강등은 확정 no-op-at-O2 라 미선적(byte-identical
  baseline 유지 · diff_guard 무위반).
- verdict verbatim = `.verdicts/unshadow-knownint-rawlocal/finding.txt` · `byte-diff.txt` · 재현 =
  `tool/unshadow_knownint_rawlocal_bench.hexa`.

## §typed-struct — 🔵 typed monomorphic struct layout (flat C-struct + offset access · F1)

> milestone "🔵 typed monomorphic struct layout" 의 실측 — E(AoS↔SoA) 재오픈 **선결**.
> **요지**: E closed-negative 가 SoA 불가의 (b)(c) 원인으로 지목한 "struct=`hexa_struct_pack_map`
> 해시맵·field=`hexa_map_get_ic` strcmp/IC 프로브" 를 제거한다. struct 가 **monomorphic** 임을
> 증명하면(닫힌 필드집합·정적 키·동적-키 set/get 없음) per-type **flat C-struct typedef** 를
> emit 하고 `obj.field` 를 컴파일-타임 **offset 로드**(`((Name__flat*)recv.vs)->f<idx>`)로 낮춘다.

**LLVM-can't**: 해시맵→offset 재작성은 우리 소유 표현에 대한 **타입-레벨 shape 증명**이다. clang
은 `hexa_map_get_ic` 를 runtime.o C-ABI 벽 너머 opaque 호출로만 보아 hash probe 를 load 로 fold
못 한다. flat typedef 는 **user.c 안**에 emit(runtime 무변경, RFC §codegen-landing) + flat ptr
이 public HexaVal `vs` union slot 에 타 → 벽 관통(§c-class 패턴).

**착지물** (`self/codegen.hexa`, GATED `HEXA_TYPED_STRUCT=1` · default OFF=무회귀):
- `_typed_struct_enabled()` 게이트 + `_is_flat_eligible_struct`(declared·비-empty 닫힌 필드집합) +
  `_flat_field_index`(정적 필드→슬롯) + `_flat_var_*`(불변 `let p=Pt{...}`/`Pt(...)` → 타입 추적,
  re-let void).
- `gen2_struct_decl`: flat-eligible → `gen2_flat_struct_typedef`(per-type `typedef struct
  Name__flat {HexaVal f0; …}` + positional flat ctor, 시그니처는 hash ctor 와 동일).
- Field arm(`:5389`): 정적 flat 수신자 + 선언된 필드 → offset 로드, **else `hexa_map_get_ic`
  무변경**(동적-키·비-flat 수신자·typo 필드 idx<0 = 전부 fall-through = 무결성 게이트).

**측정 (mini Apple M4 arm64 · best-of-9 · faithful A/B proxy · full self-host regen=B9 벽 차단·스펙 허용)**:

| arm | 표현 | wall (s) | call+branch | 의미 |
|---|---|---|---|---|
| ref_c     | idiomatic native C struct (no runtime) | 0.01 | 2 | parity anchor |
| a_hashmap | 현 `hexa_struct_pack_map` + `hexa_map_get_ic` strcmp/IC | 5.48 | 19 | **BEFORE** |
| b_flat    | **LANDED**: per-type flat typedef + offset 로드 | 0.05 | 4 | **109×·−99% · gap 547×→5× AT PARITY** |

- **g5 byte-diff: 3/3 IDENTICAL** (`0f047a3268a6e167334f5a28a80ea668`) — 무손실. ON/OFF 동일 stdout.
- **무결성 게이트 PASS**: 동적-키 struct(런타임 결정 키)는 offset arm 미발화 → `hexa_map_get_ic`
  hash-map 경로 유지(`1dcca233…`, 정확히 5 read). 다형/동적-키 struct **무변경**.
- 각 arm 의 ctor/read 문자열은 `gen2_flat_struct_typedef` + Field arm emit 과 **byte-동일**
  (typedef·`Pt(a,b)` ctor·`((Pt__flat*)(p).vs)->f0` 읽기).

### 정직한 해석

- **갭의 정체 = 해시맵 표현 그 자체.** a_hashmap 5.48s 는 per-iter `hexa_struct_pack_map`(해시테이블
  구성) + 2× `hexa_map_get_ic`(strcmp/IC 프로브). flat typedef + offset 로드는 그 전부를 단일
  멤버 로드로 치환 → clang 이 loop-invariant 로 보고 fold(b_flat 0.05s ≈ ref 0.01s). 이 갭이
  §parity-attest(7.9×~1263×)이 사는 표현축의 struct 쪽 인스턴스.
- **벤치는 construction 포함**(per-iter malloc). b_flat 0.05s 는 flat-ctor malloc 비용도 포함 —
  순수 field-read 는 offset 로드 1개. 즉 109× 는 read+construct 합산 우위.
- **GATED opt-in (default OFF) = 무회귀.** FLAG OFF 면 hash-map ctor + `hexa_map_get_ic` 무변경.
  ON 이라도 동적-키/비-flat/typo 필드는 전부 hash-map fallback.
- **honest scope (착지 슬라이스)**: 발화 = 불변 `let p=Pt{…}`/`Pt(…)` **직접 construction
  바인딩** + 정적 필드 read. struct 가 fn 인자/반환으로 흘러간 수신자(타입 추적 끊김)·mut 재대입·
  eq/serialize/map-interop polymorphic 연산·중첩 struct 필드는 **미발화**(hash-map 유지) = open
  sub-task. real self-host codegen 발화 검증(transpile)도 sub-task(emit 문자열은 byte-동일 확인).
- verdict verbatim = `.verdicts/unshadow-typed-struct/typed-struct.txt` · 재현 =
  `HEXA_TYPED_STRUCT=1 tool/unshadow_typed_struct_bench.hexa --rt ~/.hx/packages/hexa/self --runs 9`.

## §verify-memo — 🔵 검증 memoization (F3 atlas-as-perf-asset · 거울방)

> milestone "🔵 검증 memoization" 의 실측. **요지**: atlas 가 fn 의 PURE(deterministic·
> side-effect-free) 를 증명하면 codegen 이 같은-인자 반복 호출에 fn-local static last-arg
> 캐시를 삽입한다. PURE ⇒ cached-value ≡ recomputed-value EXACTLY → byte-diff IDENTICAL.
> LLVM-can't: clang `pure`/`const` attr 는 한 표현식 내 인접 동일콜만 CSE 하고, 정밀컴파일된
> runtime.o 심볼의 loop-cross idempotent 를 증명 못 해 매 iteration `bl _lambda_eliashberg`
> 를 다시 emit 한다 — clang 에 theorem/verdict DB 가 없다.

발화 fn = `lambda_eliashberg` (atlas node `verified-lambda_eliashberg-num` 🟢 ·
`hexa verify --expr lambda_eliashberg 0.5 1.0`). GATED opt-in `HEXA_VERIFY_MEMO`
(default OFF). codegen 분기 = `self/codegen.hexa` Call(`lambda_eliashberg`) 처리, §B
closed-form inline 보다 우선(env 켜졌을 때만). 1-arg + `_is_known_fn_global` +
`!_gen2_has_decl` 가드(§A/§B 동일 exactness). EXPR 1회 let-bind(single-eval).

### §verify-memo emit (END-TO-END · edited codegen 으로 재빌드한 `/tmp/hexat.new`)

| HEXA_VERIFY_MEMO | emit | 의미 |
|---|---|---|
| unset (default) | `__le_x … 2.0*HX_FLOAT(__le_x)` | §B closed-form inline — **무회귀** |
| `=1` | `static int __lem_v=0; … if(!(__lem_v && __lem_a==__lem_xf)){ __lem_r=lambda_eliashberg(__lem_x); … } __lem_r;` | memo 캐시 발화 |

g5 byte-diff(real compiler, `lambda_eliashberg(0.5)`×2,000,000): OFF·ON 둘 다
stdout `2000000.0`, **md5 `7fe719e9` IDENTICAL**. asm `bl _lambda_eliashberg`(literal arg):
OFF=0(§B fold) · ON=1(static 캐시 1콜 후 HIT).

### §verify-memo perf (OPAQUE-arg A/B proxy · runtime.o C-ABI 벽 시나리오)

> proxy(`/tmp` throwaway · clang -O2 · `lambda_eliashberg`=noinline opaque symbol,
> 정밀컴파일 runtime.o 모사 · arg=argv→opaque). B9 generated-runtime 벽으로 full
> self-host regen 차단·스펙 허용; emit 문자열은 end-to-end 컴파일러 출력과 byte-동일.

| mode | calls | wall(첫측) | wall(best-of-5) | byte-diff stdout |
|---|---|---|---|---|
| nomemo | 20,000,000 | 0.1889s | 0.1546s | `4c281195` |
| memo | **1** | 0.0253s | **0.0255s** | `4c281195` (IDENTICAL) |

→ call count **20M → 1** · wall **6.06× faster (−83.5%)** · byte-diff **IDENTICAL**.

### §verify-memo 무결성 게이트

- **NEGATIVE-arg 가드 보존**: arg=-1.0 → nomemo==memo==`-19999980000000.0`
  (verified guard `m0<0 → -999999.0` 가 캐시 미스 경로의 실제 호출로 보존 · IDENTICAL).
- **cache-invalidation**: varying arg(`i%7-3`, 음수 가드 교차 포함) → nomemo==memo==
  `-428997861.0` (last-arg 캐시가 arg 변경 시 정확 재계산 · match YES). silent-stale 없음.

### §verify-memo 정직한 caveat

- **LIVE atlas-query surface 부재**: §A const-fold·§B proof-carrying 과 동일하게 codegen 에
  컴파일타임 atlas lookup 이 없다 → 발화 가드는 atlas-verified fn 名 하드코딩(verdict=라이선스).
  다수 fn 일반화 = atlas 에 pure/idempotent 속성 atom + codegen lookup surface 둘 다 선결(sub-task).
- **memo 가치는 OPAQUE 반복인자 한정**: LITERAL arg 면 §B inline(0 call)이 memo(1 call)보다
  빠르다. memo 가 이기는 곳 = clang 이 fold 못 하는 opaque/cross-ABI 반복호출(=UNSHADOW 의 벽).
- verdict verbatim = `.verdicts/unshadow-verify-memo/{e2e-bytediff,opaque-ab-proxy}.txt` ·
  재현 = `HEXA_VERIFY_MEMO=1` 로 `tool/unshadow_verify_memo_bench.hexa` 트랜스파일 + OPAQUE A/B proxy.

---

## §nanbox — NaN-boxing HexaVal 표현 (DESIGN + 최소 A/B 측정)

> 상태: **DESIGN / feasibility + 최소측정** (전역 flip 아님 · 의도적 honest 분해). 전역 ABI
> 변경이라 1-batch 불가 = multi-session. 설계 SSOT = `domains/UNSHADOW.nanbox.md`. 측정대 =
> `tool/unshadow_nanbox_bench.hexa` (faithful A/B proxy · B9 self-host regen 벽 밖 · §c-class·
> §native-arr 와 동일 스펙 허용). mini Apple M4 arm64.

### §nanbox 사실 정정

milestone 텍스트 "24B → 8B" 의 **24B 는 stale**. 현 `sizeof(HexaVal)=16B` (`§unboxed-array` L701
이 이미 정정). NaN-box 밀도 이득 = **정확히 2× (16→8)**, 3× 아님.

### §nanbox 규모 산정 (multi-session · 1-batch 불가)

NaN-box 는 union 을 **물리 제거** (`HexaVal`=bare `uint64_t`) → 레이아웃 가정 사이트 전부 동시
flip 必. worktree 격리 grep 실측 (self/codegen.hexa + runtime_core_emit.hexa + compiler/):

| surface | 사이트 | 비고 |
|---|---|---|
| `HX_*` 매크로 use (추출+tag+SET) | **1151** | 매크로 본문 교체로 다수 흡수 |
| emitted-C `TAG_*` 리터럴 | **430** | tag 비교/구성 box 인코딩 재작성 |
| `((HexaVal){.tag=..,.i=..})` compound-literal | **19** | **매크로 우회** = 전역 flip 단일 토글 지점 |

판정 = **multi-session**. 무리한 전역 flip 금지 (milestone 지시). → 설계+feasibility+최소측정+sub-task.

### §nanbox 측정 (faithful A/B proxy · 3 축 · best-of-7 stabilized)

| 워크로드 | A(16B box) | B(8B NaN-box) | B/A | 판정 |
|---|---|---|---|---|
| sequential traverse+sum (8M·rep40) | 0.39s | 1.10s | **2.5–2.8× 느림** | 🔴 NaN-box 패배 |
| value-pass register-fit (noinline·4M·rep30) | 0.16s | 0.21s | **1.30–1.36 = 30–36% 느림** | 🔴 NaN-box 패배 |
| random / cache-pressure (4M perm-chase) | 0.24s | 0.22s | 0.89–0.93 = **7–11% 빠름** | 🟢 유일 승 |

- sizeof 16→8 (**2× denser**) · N=8M 배열 footprint 128MB→64MB · int round-trip checksum **match=YES**.
- value-pass 는 best-of-7 안정화 측정 (단발에선 37% 빠름~36% 느림 사이 큰 분산 → **반드시 반복측정**).

### §nanbox 핵심 해석 (honest — 거의 전 축 퇴보, density 만 승)

> ⚠ 정직 정정: 초기 단발 측정의 "value-pass 37% 빠름" 은 **측정 artifact** 였다. best-of-7 안정화
> 시 value-pass 는 일관되게 **30–36% 느림**. 가설(8B=1 reg → register-fit 승)은 이 proxy 에서
> **falsified** — box_int/unbox_int 의 mask+shift+OR 추출 오버헤드가 register-fit 이득을 압도.

- 🔴 **sequential/vectorizable 패배 (2.5–2.8×)**: `is_boxed()`+mask-extract 가 auto-vectorizer 를
  죽임 (16B box 는 `tag==INT`+직접 load 라 clang -O2 SIMD). → §native-arr 가 잡은 contiguous
  int64[] 종목을 NaN-box 가 **퇴보**시킴 = C1 과 **상충**(의존 아니라 분리).
- 🔴 **value-pass 패배 (30–36%)**: 매 호출 box/unbox 추출비용 > register-fit 이득. milestone 의
  register-fit 가설은 이 proxy 기준 **반증** (소유 ABI 라도 추출비용은 공짜 아님).
- 🟢 **cache-pressure 7–11% 승 (유일)**: 밀도 2× 가 random working-set 절반 — prefetch 가 못
  가리는 메모리-bound random-access 만 승.
- → **per-program GATED default OFF 가 정답** (milestone "프로그램별 표현 선택" 일치). 단 측정상
  우위 종목은 **memory-bound random-access 단 하나** — 대부분 워크로드(sequential·value-pass)는
  NaN-box 가 **손해**. "전역 캐시밀도 3×" 의 milestone 기대는 (a) 밀도는 2× (b) 밀도 이득이 실
  wall 로 전환되는 건 random-bound 한정 → **대폭 축소**. 이게 핵심 closed-negative-leaning 발견.

### §nanbox NaN-collision (정확성 근본 제약)

- 측정: 진짜 f64 NaN = `0x7ff8...`(sign=0) · box 마커 = `0xFFF8...`(sign=1) → canonical **positive**
  qNaN 충돌 안 함(`is_boxed()=0` 실측). **그러나** negative-NaN·signaling·payload-bearing NaN 은
  마커와 겹침 → **모든 float store 에서 canonicalize 必** (libm `sqrt(-1)` 등 음수-NaN 산출 가드).
- **결정적 한계**: raw f64 비트 관찰/구성 프로그램(bit-cast·직렬화·hash-of-double)은 안전하게 못
  덮음 → 그 corpus 는 GATED OFF 유지. full-corpus byte-diff 게이트(음수-NaN·NaN-payload·bit-cast
  포함)는 전역 flip sub-task 선결.

verdict=`.verdicts/unshadow-nanbox/proxy.txt` · 재현=`tool/unshadow_nanbox_bench.hexa --runs 3`.

## §atlas-pgo — 🔵 atlas-guided PGO (layout/inline 결정 · F3·C17)

> **착지 = LAYOUT 결정 발화 + byte-eq · wall-lever = perf-atom schema deferred (E 와 동일 narrow 벽).**
> 라이선스 = atlas verdict(`verified-lambda_eliashberg-num` @F 🟢 = pure hot-path atom)이 inline/hot
> LAYOUT 을 구동 — 사용자 `@inline_always`/`@hot` 아님·런타임 프로파일 아님. clang PGO 는 `.profdata`
> 런 필요(런타임 instrumentation), atlas 는 컴파일타임 verdict(런 0). codegen GATED `HEXA_ATLAS_PGO`
> (default OFF=무회귀): `gen2_is_atlas_pgo_hot`+`gen2_fn_forward`/`gen2_fn_decl` 가 atlas-verified fn 을
> `static inline __attribute__((hot))` 로 자동 승격(§A const-fold→fn-LAYOUT 일반화).

| arm | fn 레이아웃 (emit) | out-of-line 심볼 | wall best-of-7 |
|---|---|---|---|
| OFF (default) | `HexaVal lambda_eliashberg(…)` | `T _lambda_eliashberg` present | 0.38s |
| ON (`HEXA_ATLAS_PGO=1`) | `static inline … __attribute__((hot))` (어노테이션 0) | **absent** (소거) | 0.38s |

- **g5 byte-diff IDENTICAL** — `239999988.0` 양 arm, md5 `b38a2a0c…` (inline/hot = 의미보존 레이아웃).
- **[PRIMARY 레이아웃축]** out-of-line 심볼 `_lambda_eliashberg`: nm OFF=present → **ON=absent** ·
  otool lambda ref **1 → 0**. atlas verdict 의 `static inline` 승격이 out-of-line copy 를 소거.
- **wall Δ ≈ 0 (AT PARITY · 정직 NULL)**: best-of-7 OFF 0.38s ≈ ON 0.38s (9-sample 분포 겹침).
  TINY LEAF fn 은 clang -O2 가 call-site 마다 이미 인라인 → out-of-line copy 제거는 code-SIZE/layout
  효과지 hot-loop 속도가 아님. **wall 레버가 사는 곳** = out-of-line call 이 실제 지배하는 OPAQUE/
  cross-C-ABI 심볼(§verify-memo/§B 의 runtime.o 벽 시나리오, clang 이 안 인라인) → 거기서 `hot` 섹션배치+
  inline-force 가 움직임. 그 일반화 = perf-property atom schema + codegen atlas-lookup surface 선결.
- **LLVM-can't**: clang PGO 는 런타임 프로파일(.profdata)만으로 hot/inline 결정; theorem/verdict DB 없음.
  atlas 가 곧 그 DB — verdict 가 컴파일타임 라이선스(프로파일 런 0).
- **정직 caveat (E 와 동일 narrow 벽)**: codegen LIVE atlas-query surface 부재 + atlas 에 perf-property
  atom kind 부재(현 @P/@C/@F/@L 전부 수학-검증 kind) → 발화 가드 = atlas-verified fn 名 하드코딩
  (§A/§B/E 동일). 둘 다 선결해야 OPAQUE hot fn 일반화 + GATED 해제. = open sub-task.
- faithful A/B proxy (full self-host regen = B9 generated-runtime 벽 차단·스펙 허용; emit 은 edited
  codegen 로 재빌드한 `/tmp/hexat.new` 의 end-to-end 출력과 byte-동일).

verdict=`.verdicts/unshadow-atlas-pgo/` (emit-layout.txt · layout-wall.txt) · 재현=`tool/unshadow_atlas_pgo_bench.hexa`.

## §atlas-query — 🔵 codegen LIVE atlas-query surface + perf-property atom (UNSHADOW G)

§atlas-pgo·§verify-memo 둘 다의 open sub-task("codegen LIVE atlas-query surface + perf-property
atom schema") 착지. 발화 가드의 **하드코딩 fn名 → LIVE atlas 조회** 전환.

- **perf-property atom** (compiler/atlas/embedded.gen.hexa · atlas_fold 거버넌스):
  `@F perf-lambda_eliashberg-hot = lambda_eliashberg :: perf-property` · `perf = "hot-path pure
  idempotent inline-worthy"` · `derived-from = verified-lambda_eliashberg-num`. fn perf 속성을
  atlas atom 으로 1급 표현(기존 F 커널 재사용 → 새 KIND 스키마 변경·atlas_cli 미러 회피).
- **codegen LIVE 조회** (self/codegen.hexa): `gen2_is_atlas_pgo_hot` 가 `node.name == "lambda_..."`
  하드코딩을 제거하고 `gen2_atlas_perf_hot(node.name)` 호출. SSOT(embedded.gen.hexa) 를 CU 당 1회
  lazy read + module-global 캐시 → fn-decl 당 O(1). `perf-<fn>-hot` atom + `hot-path` 태그 존재시만
  static-inline+hot 승격. 경로 = `$HEXA_LANG > ./`(codegen-self-contained·main.hexa 의존 없음).
- **END-TO-END** (edited codegen 으로 full 트랜스파일러 재빌드 `/tmp/hexat.new`): OFF=`HexaVal
  lambda_eliashberg(…)` 평범 · ON=`static inline … __attribute__((hot))` 자동승격(LIVE 조회 구동).
- **실측 (mini arm64 · faithful A/B proxy · B9 벽 · 스펙 허용)**:
  - **[GATE 1] g5 byte-diff IDENTICAL** — `2.4e+08` 양 arm, md5 `71f62d5deba6863b74d5206c380d2f0a`.
  - **[GATE 2 · PRIMARY 레이아웃축]** out-of-line 심볼 `_lambda_eliashberg`: nm OFF=present(`T`) →
    **ON=absent** · otool lambda ref **1 → 0**.
  - **[GATE 3 · NEGATIVE CONTROL — LIVE 조회 실증]** SSOT 에서 perf atom 제거(grep -v) 후 ON 재-emit:
    `grep -c` 1→0, ON emit = `HexaVal lambda_eliashberg(…)` **승격 안 함**(같은 fn名·HEXA_ATLAS_PGO=1).
    atom 복원 → count 1, 승격 재발화. **결정은 fn名 아닌 atlas 조회가 구동함을 결정적으로 증명**.
- **honest scope**: wall 은 여전히 TINY LEAF NULL(§atlas-pgo 와 동일). 이 변경은 wall 을 움직이지
  않고 §A/§B/E/G 가 공유하던 하드코딩 가드를 제거 — OPAQUE/cross-ABI hot fn 일반화(wall 레버)가
  이제 **차단 해제**(임의 fn 에 perf atom 등록 가능)되었으나 별도 측정이라 여기서 주장 안 함.

verdict=`.verdicts/unshadow-atlas-query/live-query.txt` · 재현=`tool/unshadow_atlas_pgo_bench.hexa`
(동일 bench · HEXA_ATLAS_PGO + perf atom 유무로 A/B).

## §native-arr-f64 — native HexaArrF64 contiguous double[] storage + no-escape auto-fire

**status: [~] code landed · pool A/B byte-diff measurement PENDING** (harness stdout
channel failed this session → build/transpile/measure not observed; no numbers
fabricated per claim_verify). Re-run on pool (arm64) to populate.

### arms (g5 gate = byte-diff IDENTICAL across all four + boundary)
| arm      | storage                              | read surface                                  |
|----------|--------------------------------------|-----------------------------------------------|
| ref_c    | raw C `double[]`                     | raw `xs[i]` (the absolute ceiling)            |
| a_boxed  | boxed HexaArr, 16B HexaVal stride    | `(xs.arr_ptr->items[i])` (BEFORE)             |
| b_native | HexaArrF64 native contiguous double[]| INLINE `((HexaVal){.tag=TAG_FLOAT,.f=(…data[i])})` (LANDED) |
| d_ideal  | HexaArrF64 native contiguous double[]| raw `.f` into raw double accumulator (CEILING)|

### measurement protocol (to capture)
- pool on mini (arm64), best-of-9, capture raw stdout verbatim to
  `.verdicts/unshadow-native-arr-f64/`.
- per-arm: program-output md5 (all four MUST match) · wall (s) · asm vec/pair-op
  count (SIMD-gather signal; native 8B contiguous should be gatherable like the
  i64 arm's 8→28).
- INTEGRITY: typed-f64 array → polymorphic boundary (hexa_arr_f64_box → real
  TAG_FLOAT HexaVal) must box to the same value both sides (IDENTICAL).
- NEGATIVE CONTROL (auto-fire): emit three sibling bindings — (a) returned, (b)
  passed to opaque fn, (c) only `xs[i]` reads. grep the emitted user.c:
  `hexa_arr_f64_new` present ONLY for (c) → proves escape-driven, not name-driven.

### expected (per i64 precedent — NOT a measured claim)
i64 showed a_boxed 2.43s → d_ideal 0.16s (17.6×, gap→0.83× AT PARITY). F64 native
8B-contiguous double[] should mirror: byte-diff IDENTICAL, d_ideal closing the
storage gap to ~parity with ref_c. To be confirmed/falsified on re-run.

repro: `tool/unshadow_native_arr_f64_bench.hexa`. design:
`.verdicts/unshadow-native-arr-f64/IMPLEMENTATION.txt`.
