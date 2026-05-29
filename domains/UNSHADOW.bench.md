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
