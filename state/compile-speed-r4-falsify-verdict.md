# 컴파일속도 R4 — FALSIFY-PROFILE verdict (MEASURED · 예측 검증)

**Date:** 2026-06-26 · **Host:** summer (12c, Linux x86_64, gcc 13/14) · **HEAD:** `990136e9` (origin/main,
bsearch default-ON) · **Build:** CI-faithful `tool/release_build` (TARGET=linux-x86_64 CC=gcc
HEXA_SEED_CONVERGE=1 -O2), isolated `/tmp`, 3 runs.

R4 워크플로(`state/compile-speed-r4-lever-verdict.md`)는 PRE-bsearch 프로파일(`state/real-ci-build-hotspot-verdict.md`)
하나만 datum으로 두고 post-bsearch 병목을 **예측(전부 PREDICTION)** 했다. 이 라운드는 그 예측을 실측으로
검증한다. **결과: 핵심 예측 FALSIFIED — 단순히 #1 심볼이 틀린 정도가 아니라, 병목이 들어있던 스테이지(Stage-1
transpiler) 자체가 더 이상 병목이 아니다.**

---

## 0. 측정 confound 와 그 제거 (정직 기록)

run1(초기)은 summer 환경에 **전역 export 된 `HEXA_PREBUILT_RUNTIME=/home/summer/.hx/bin/build/runtime.a`**(스테일
공유 prebuilt)를 물어 `release_build` 의 fresh `build/runtime.a` 를 무시했다. `hexa_val_heapify` 는 **runtime.a 에서
링크**되므로(자유 클론엔 `runtime_core.c`·`hexa_cc.c`·`runtime.c` 모두 ABSENT = 빌드 중 emitter 가 생성), 스테일
runtime.a = **pre-bsearch 선형walk heapify** 가 측정됐다. → run2/run3 은 `HEXA_PREBUILT_RUNTIME="$WORK/build/runtime.a"`
로 **강제 fresh** + `nm build/hexa_v2` 로 bsearch 심볼 실재 확인(`ablk_sym_count=6` · `hexa_val_heapify` T 정의).
이 스테일-prebuilt 함정은 MEMORY `anima ING 벽=stale-prebuilt`/`QFORGE blocker=STALE prebuilt` 와 동일 계열.

**부수 이득 = bsearch A/B (동일 HEAD, runtime.a 만 스왑):**
| runtime.a | heapify | Stage-1 emit wall | emit self profile 지배 |
|---|---|---|---|
| run1 스테일 `~/.hx` | 선형 chain-walk | **~36 s** (64,093 samples) | `BLOCK_HDR` 27.5% + `__blk_data` 11.4% + `__blk_cap`(heapify child) 32% — **선형 블록walk** |
| run2/3 fresh bsearch | O(log B) `_hx_ablk_contains` | **~4.5 s** (≈8× faster) | `__blk_data`/`__blk_cap`/`BLOCK_HDR` **top 에서 소멸** |

(run1 baseline 의 runtime.a 출처는 "~/.hx 에 마지막 설치된 것"이라 통제된 OFF-빌드는 아님 — 근사 baseline 으로만 취급.)

## 1. MEASURED per-stage wall (run3 · pty `script` 라인버퍼 · 실타임스탬프)

| stage | wall | what runs | share |
|---|---|---|---|
| Stage 0b runtime.a | **5.7 s** | gcc -O2 amalgam + ar native .o | 4.3% |
| **Stage 0a-pre seed-converge** | **76.4 s** | regen-transpile + **gcc -O2 hexat(2.7MB) ×2 to fixpoint** | **57.4%** |
|   ├ pass 1 | 47.9 s | | |
|   └ pass 2 | 27.2 s | | |
| Stage 0 compile hexa_v2 | **25.9 s** | gcc -O2 `hexa_cc.c`(2.1MB) | 19.5% |
| **Stage 1 flatten+transpile→main.c** | **5.1 s** | flatten 0.6s + **hexa transpiler emit 4.5s** | **3.8%** |
| Stage 2 compile main.c | **19.9 s** | gcc -O2 generated `main.c` | 15.0% |
| **whole build** | **133.1 s** | (run2 `/usr/bin/time -v`: wall 2:13.13 · RSS 830 MB · CPU 99% single-thread) | |

**핵심:** R1 에서 Stage-1 transpiler = 154.6 s(빌드의 55%)였던 것이 지금 **~5.1 s(3.8%)** — bsearch + 누적 perf
작업으로 ~30× 붕괴. 컴파일속도 병목은 transpiler 를 **완전히 떠나** ⓐ **seed-converge 루프(76.4s · 57%)** + ⓑ
**큰 amalgam 의 gcc -O2 컴파일**(seed-converge 내 hexat ×2 + Stage0 hexa_v2 26s + Stage2 main.c 20s)로 이동했다.
순수 gcc -O2 컴파일 합 ≈ Stage0(26)+Stage2(20)+seed-converge 내 gcc 2회 ≈ **빌드의 ~70%가 gcc -O2 of large C**.

## 2. Stage-1 emit perf — post-bsearch (2 독립 샘플 · ~1% 내 일치 = robust)

`perf record -g --no-buildid-mmap -p <hexa_v2 expanded→main.c PID> -- sleep N`

**SELF (`--no-children`) — v2 / run3:**
| % self (v2) | % self (run3) | symbol |
|---|---|---|
| 16.70 | **16.91** | `rt_truthy_native` ← **새 #1 self** |
| 14.39 | 14.54 | `hexa_eq` |
| 11.65 | 11.43 | `hexa_arena_rewind` |
| 10.75 | 11.64 | `__blk_next` |
| 11.47 | 10.08 | `hexa_val_heapify` |
| 9.45 | 9.82 | `hexa_truthy` |
| 9.54 | 9.53 | `__blk_set_used` |
| ~1.4 | 2.61 | `hexa_arena_env_lo` |
| — | 2.85 | `hexa_arena_env_hi` |

**INCLUSIVE (`--children`) — run3:**
| % incl | % self | symbol |
|---|---|---|
| **64.79** | 0.11 | `__hexa_fn_arena_return` ← **새 #1 inclusive** (per-fn arena promote+rewind 드라이버) |
| 40.97 | 9.82 | `hexa_truthy` |
| 31.14 | 16.91 | `rt_truthy_native` |
| 27.01 | 14.54 | `hexa_eq` |
| 26.50 | 11.43 | `hexa_arena_rewind` |
| 24.36 | 9.53 | `__blk_set_used` |
| 15.02 | 10.08 | `hexa_val_heapify` |
| 12.51 | 11.64 | `__blk_next` |

(call-graph 은 -O2 no-fp + frozen-seed 라 부모귀속에 `[unknown] 0x0`·`0x15`·`0x21` bogus frame 다수 — **self
수치만 신뢰**. 두 샘플 self 가 ~1% 내 일치하므로 ranking 은 noise 아님. run3 emit ~4.5s 라 샘플수는 v2 16,645 보다
적음 — 그래도 top symbol 들은 각 수백~수천 sample.)

## 3. FALSIFY 판정 (예측 vs 실측)

| 예측 (R4 verdict) | 실측 | 판정 |
|---|---|---|
| `__blk_*` 79% self → **<5%** 붕괴 | heapify membership-walk 의 `__blk_data`/`__blk_cap`/`BLOCK_HDR` = **top 에서 소멸**(붕괴 ✅). 단 `__blk_next`(11.6%)+`__blk_set_used`(9.5%)는 **잔존하되 arena REWIND**(`hexa_arena_rewind`/`__hexa_fn_arena_return`)의 child 로 **재귀속** — heapify walk 아님 | **부분 confirm**: heapify walk 붕괴 O, 그러나 잔여 `__blk_*` 는 <5% 아님(다른 consumer=rewind) |
| 새 top self = `hexa_val_heapify`(~9.89%) + `hexa_add_slow`(~8.95%) | 새 top self = **`rt_truthy_native` 16.9%** + `hexa_eq` 14.5% + `hexa_arena_rewind` 11.4%. heapify 는 10%(5위 수준 잔존=예측대로), **`hexa_add_slow` 는 top-9 에서 완전 소멸** | **FALSIFIED** |
| heapify-residual 내 ~210M frozen-seed `env_lo/hi` 호출이 지배 | `env_lo`(2.6%)+`env_hi`(2.9%) = ~5.5% self of Stage-1 = **빌드 전체의 ~0.2%** | **FALSIFIED** (env-call 은 무시가능) |
| 후보: parse/flatten/gcc 가 지배? | flatten = **0.6 s**(무시가능, "44s flatten 지배" 가설 FALSIFIED). **gcc -O2 of large amalgams = 빌드의 ~70%**(seed-converge 2× + Stage0 + Stage2) — gcc 가 **실제로** 지배 | **gcc-stage 지배 = CONFIRMED** |

**한 줄:** bsearch(+누적)는 Stage-1 transpiler heapify 병목을 **풀었다**(55%→3.8%, emit 36s→4.5s). 예측이 가리킨
heapify-residual/`hexa_add_slow`/env-call 레버는 전부 **빌드의 <0.5% 짜리 죽은 레버**가 됐다. 새 병목 = seed-converge
+ gcc -O2 of large C.

## 4. rank-1 (heapify env-cache) byteeq audit — heapify-never-arena_allocs?

**감사 결과 (build-free white-box · `self/runtime_core_emit.hexa`):**
- heapify TAG_STR 경로(:5283-5286): arena 소유 문자열을 찾으면 `hexa_strbuf_dup_n(HX_STR(v), len)` 호출.
- `hexa_strbuf_dup_n`(:891) → `hexa_strbuf_alloc`(:867) → **`hexa_arena_on() ? hexa_arena_alloc(_need) : malloc(...)`**(:870).
- ∴ **heapify 는 transitive 하게 `hexa_arena_alloc` 을 호출한다** (arena-on 시 dup 자체가 arena 로 들어가 새 블록을
  append → env_hi 상승). heapify-never-arena_allocs **= FALSE**.

**Verdict (rank-1):** 예측이 명시한 조건부 hazard 가 **소스에서 CONFIRMED**. lazy env-cache(heapify-root 당 env_lo/hi
1회 snapshot)는 **byteeq-safe 아님** — 트리 중간의 dup 가 arena 를 새 high 블록으로 키우면 이후 in-tree arena 문자열이
스테일 cached env_hi 위로 떨어져 **오envelope-reject → strdup 누락 → rewind 후 dangle → byte 발산**. per-dup
무효화 또는 "heapify 중 arena-off" 증명을 선행해야 함. **게다가 perf-DEAD**(env_lo+hi = 빌드의 0.2%) → **rank-1 =
no-go (이중 기각: byteeq-hazard + 무의미한 이득).**

## 5. rank-4 (seed-converge 병렬화) — 확정 top 레버

- **이제 측정상 빌드의 57.4%(76.4s)** = 단일 최대 스테이지. R4 예측이 "가장 안전+명확한 win"으로 지목한 대로지만,
  중요도는 예측보다 훨씬 큼(Stage-1 이 붕괴해 상대비중 급등).
- **4-module 독립성 확인 (`tool/regen_cc_manual:42-50`):** `for spec in "lexer.hexa" "parser.hexa" "type_checker.hexa"
  "codegen.hexa"` 를 **순차** 트랜스파일, 주석 명시 "Each invocation is independent (no in-process exec chain)".
  12 유휴코어 중 1개만 사용. → 4-way 병렬화 = **byteeq-무관**(각자 결정적 .c 산출 · 출력 불변) · HIGH 확신.
- seed-converge 2 pass 각각 이 4-module 트랜스파일 + **gcc -O2 of 2.7MB hexat**. 병렬화는 트랜스파일부를 줄임;
  pass 당 gcc -O2(큰 단일 TU)는 별도(아래 §6).

## 6. NEW 레버 (실측이 드러낸 것) — gcc -O2 of large amalgams

빌드의 ~70%가 큰 생성 C 의 gcc -O2: seed-converge hexat(2.7MB)×2 + Stage0 hexa_v2(2.1MB·26s) + Stage2 main.c(20s).
- **bootstrap/intermediate 바이너리(hexat·hexa_v2)는 산출 ./hexa 가 아니다** → `-O1`(또는 `-O0`) 로 컴파일해도 최종
  출하물 perf 무관, seed-converge·Stage0 의 gcc 시간 대폭 절감 가능(릴리스 무결성-safe: 최종 ./hexa 만 -O2 유지).
- 또는 ccache / `-fno-FORTIFY` / split-TU 병렬 gcc. **단 byteeq·faithful-baseline 검증 필요**(seed 바이트 불변이어야).
- 우선순위는 rank-4 < 이 gcc 레버보다 낮지 않음 — 둘 다 seed-converge(57%)+Stage0(20%)를 직접 친다.

## 7. 확정 R4 top 레버 + go/no-go + 다음 impl

| rank | 레버 | 측정 share | byteeq | go/no-go |
|---|---|---|---|---|
| **#1** | **seed-converge 4-module 병렬화** (regen_cc_manual `for spec` → 4-way) | seed-converge 76s 내 트랜스파일부 | 무관(safe) | **GO** (가장 안전·HIGH) |
| **#2** | **bootstrap gcc -O1** (hexat·hexa_v2 만; 최종 ./hexa=-O2 유지) | Stage0 26s + seed-converge gcc ×2 | seed-byte 불변 검증 필요 | GO(검증 선행) |
| #3 | arena-rewind block-find 가속(`hexa_arena_rewind`/`__blk_set_used` 11%+9.5% self) | Stage-1 3.8% 내 | bsearch 계열 audit 필요 | LOW(Stage-1 자체가 3.8%라 천장 낮음) |
| ~~rank-1~~ | ~~heapify env-cache~~ | ~0.2% | **byteeq-hazard** | **NO-GO** (perf-dead + 발산위험) |
| ~~old rank-3~~ | ~~emit single-buffer (hexa_add_slow)~~ | hexa_add_slow top 소멸 | — | **NO-GO** (더 이상 hotspot 아님) |

**다음 impl 단계:**
1. `tool/regen_cc_manual` 의 4-module `for spec` 루프 → 백그라운드 `&` 4-way + `wait`(12코어). byteeq 3타깃 +
   seed 바이트 불변 확인. 측정: seed-converge wall taskset-median.
2. `tool/stage_prebuild_hexat`·`tool/stage_build_hexa` 의 **bootstrap** gcc(hexat·hexa_v2)만 `-O1` 토글(최종
   ./hexa 컴파일은 -O2 불변). seed-converge fixpoint 가 동일 바이트로 수렴하는지 확인(필수).
3. 둘 다 호스트 free + 3타깃 byteeq 후 머지. Stage-1 transpiler 레버(rank-1 등)는 **닫힘** — 더 갈 honest 다음
   단계는 transpiler 가 아니라 build-orchestration(병렬) + gcc(-O 레벨)다.

## 8. 측정 한계 (정직)
- run3 emit 윈도(~4.5s)가 짧아 그 perf.data 샘플수는 v2(16,645)보다 적음 — 그래도 두 샘플 self-ranking ~1% 내 일치.
- per-stage 는 pty(`script`) 라인버퍼로 실타임스탬프 확보(stdbuf 만으론 child 블록버퍼로 전부 build-end 로 뭉침 — run1/2
  교훈). whole-wall 은 `/usr/bin/time -v` 와 BUILD_START/END 양쪽 133s 일치.
- bsearch A/B 의 run1 baseline runtime.a 는 통제된 OFF-빌드 아님(~/.hx 설치본) — 근사치.
- 빌드는 summer pool(mini=git/gh only) · 1-SSH 준수(CI byteeq 적체 비운 뒤 IDLE 확인 후 실행).
