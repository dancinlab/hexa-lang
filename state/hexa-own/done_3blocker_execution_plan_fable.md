세 블로커 전부 repo·CI·state 문서를 병렬 조사해 file:line 단위로 착지했다. 실행 계획 전체를 정리한다.

# TL;DR — 순서와 핵심 판정

1. **B 먼저** (오늘, aiden): merge 없는 순수 측정. rounds 1+2는 **한 번도 link-and-run 측정된 적 없음**이 문서로 확정돼 있다 (`state/hexa-own/elf_round3_harness_review_spec.md:40`). 하니스·플래그 배선은 전부 검증 완료 — run.sh 드라이버 호출은 파서와 정확히 일치, 수정 불요.
2. **C 다음** (#4679 선착지 → FLIP-6 mechanism PR → faithful RUN+leak 게이트 → default-ON flip): 마지막 reducible floor drop. 단, **실제 잔여 표면은 사용자가 생각한 것과 다르다** — `calloc/free`가 아니라 `malloc`(shim delegate) + `__libc_calloc/__libc_free`(farr carve-out)이고, 후자는 **측정된 30GB noop-free leak 때문에 일부러 reclaiming libc에 남겨둔 것**이라 native **reclaiming** allocator가 필요하다.
3. **D 마지막** (summer perf는 C와 병렬 가능): runtime.a의 mem* UND는 **이미 #4604로 드랍 완료**. 남은 flip 표면은 **최종 사용자 바이너리** 쪽(transpiler-emit bare memcpy + clang-synth)이며 SSOT가 "perf lever·NOT floor drop"으로 분류. 단 B의 round-1b(static ELF own-link, libc 없음)에 결국 필요해지므로 D의 symbol-interposition 작업은 ELF 트랙과 시너지.

⚠️ **공통 전제**: mini 로컬 체크아웃은 detached `f791fb9a5`로 **stale**하다 — ELF 하니스/round 1+2 전부 없음. 로컬 `main` ref도 `56ecc3c40`으로 stale. 모든 작업은 **origin/main tip `964642480`** 기준으로 fetch해서 시작할 것.

---

# (B) ELF rounds 1-2 REAL-verify — aiden

## 사실 확정 (조사 결과)

- 하니스는 origin/main `964642480`(#4694)에 merge됨: `test/native_build/elf_ownstart/{run.sh,exit_code.hexa,hello_str.hexa}`. **"main 964642480"은 stdout 기대값이 아니라 하니스 커밋 SHA** — 실제 assert는 exit_code=42/stdout 없음, hello_str=exit 0/stdout `"hello\n"` (byte-compare `cmp -s`, run.sh:88).
- run.sh 호출은 파서와 **정확히 일치** (run.sh:46, :66-67):
  - STEP1: `hexa run compiler/main.hexa --backend=native --emit=obj --target=x86_64-linux-gnu -o t.o src.hexa` → `readelf -h` REL 검증
  - STEP3: `strace -f -qq -e trace=execve` 하에 `--linker=hexa --emit=exec` → ET_EXEC
  - 파서 확인: `--linker=` compiler/main.hexa:446-447 · `--emit=` :440-441 · exec 시 native backend 자동flip은 **obj일 때만**(:529-533)이라 run.sh의 명시적 `--backend=native`가 load-bearing (이미 넣고 있음, OK).
  - 링커 디스패치: main.hexa:1222-1239 `link_elf_x86_64_ownstart(elf_obj_x86_holder, out_path, "main")` → system-ld exec 전에 exit(0). ELF writer는 `compiler/emit/elf_x86_64.hexa` (`link_elf_x86_64_ownstart` :884, 2-seg serializer :1384-1400, round-2 `c62ea8d38` 포함).
- 게이트: STEP4 = strace에 as/ld/gcc/clang execve 0건 (run.sh:72) · STEP5 = ET_EXEC + INTERP/DYNAMIC 없음 (:78-81) · STEP2 falsifier = `nm -u` UNDEF 0 아니면 round-1b 스코프로 SKIP (:59-63).
- 필요 환경: Linux x86_64 (아니면 자동 SKIP, run.sh:30-37) + PATH에 `hexa readelf file strace nm` + **repo root에서 실행** (드라이버가 상대경로 `compiler/main.hexa`).

## 실행 절차 (aiden)

```bash
# 1. checkout (aiden의 기존 clone에서; sidecar pool on 120s 타임아웃 → 직접 ssh+nohup)
ssh aiden
cd ~/hexa-lang   # 없으면 fresh clone
git fetch origin && git checkout 964642480   # 로컬 main ref 신뢰 금지 (stale)

# 2. hexa 빌드 — canonical 단일 진입점 (CI가 pool서 도는 것과 동일, nobaseline-gate.yml:287-318)
HEXA_CCACHE=1 TARGET=linux-x86_64 CC=gcc LIBS="-lm -ldl" \
  nohup bash tool/release_build > /tmp/relbuild.log 2>&1 &
# cloud 2-core ~13-19분 → aiden 12c/30G는 대략 5-10분. 산출: ./hexa + build/runtime.a

# 3. 하니스 실행 (repo root · 새 hexa를 PATH 앞에)
PATH="$PWD:$PATH" bash test/native_build/elf_ownstart/run.sh | tee /tmp/elf_verify.log
echo "exit=$?"
```

**~/.hx 재사용 여부**: 재사용 **불가**. run.sh:14가 명시 — stale ~/.hx hexa(< `c62ea8d38`)는 system-ld로 fallback해 STEP4를 false-RED로 만든다. `tool/release_build`가 유일한 정답이고, `HEXA_CCACHE=1`이 재빌드 단축 레버. `build_selfhost.sh`(~3.5h fixpoint)는 **불필요**.

## RED 시 root-cause 트리

| 증상 | 1차 의심 | 확인 |
|---|---|---|
| STEP1 RED (REL 아님) | obj emit 경로 미도달 | `readelf -h` 출력 캡처, target 오타 확인 |
| STEP2 SKIP (UNDEF>0) | exit_code조차 runtime UNDEF를 끌어옴 | round-1b(멀티-obj) 스코프 — **측정된 wall로 기록**, RED 아님 |
| STEP4 RED (as/ld execve) | PATH의 hexa가 stale이거나 fallback(:1256) 탄 것 | `command -v hexa && hexa --version`; main.hexa:1067 holder push 도달 여부 |
| STEP6 RED (exit/stdout) | own-start 14-byte `_start`(elf_x86_64.hexa:854-880) 또는 vaddr math | exe 보존 + `readelf -l` + `objdump -d` 캡처 |

## 착지

GREEN이면: `state/hexa-own/elf_round3_harness_review_spec.md`의 GATE-0(line 81) 해소 → state 문서에 캡처 출력과 함께 "rounds 1+2 REAL-verified GREEN (aiden, sha, date)" 기록 + CHANGELOG.jsonl → 다음 rung은 round-1b(runtime 멀티-obj link — 이때 review spec line 50의 **STB_LOCAL flat-resolver latent 결함이 live**가 되므로 round-1b 첫 rung은 local-symbol scoping) 또는 round-3(.bss/multi-obj/data-reloc, `elf_x86_round2_data_segment.md:28`).

리스크: 낮음 (read-only 측정). 유일한 함정 = stale binary/checkout으로 인한 false verdict — 위 절차가 둘 다 차단.

---

# (C) axis-② FLIP-6 WALL-2 heap family

## 사실 교정 — 잔여 표면의 실체

live nm census(summer, `state/wall2-arm-census-b.txt:2`)와 코드 기준, 지금 default 빌드는 이미:
- `hxlcl_malloc` = **mmap 4MB-chunk bump allocator** (amalgam, `self/runtime_emit_full.hexa:1207-1223`) — libc malloc 아님
- calloc seed 채택(auto)·realloc-F2 default-ON(#4620/#4621)·free는 F2 활성 시 shim의 magic-guarded 경로

**진짜 남은 reducible heap UND는 정확히 세 개**:
1. `malloc` — shim delegate (`self/runtime_core_hxlcl_shim_emit.hexa:167-176`, F2 arm조차 `malloc(want+16)` 호출)
2. `__libc_calloc` / `__libc_free` — `tool/restore_frozen_seeds:392-419`의 HXFARR carve-out. 파일 전역 `#define calloc→hxlcl_calloc`이 glibc의 distinct name을 못 잡아서가 아니라(그건 수단), **noop-free bump arena로 farr를 돌리면 decode에서 RSS 29.7-30.3GB vs reclaiming 5.2MB FLAT** (restore_frozen_seeds:381-382 측정)이라 **일부러** reclaiming libc에 남긴 것.

∴ FLIP-6의 본질 = "caller-drop 매크로 하나"가 아니라 **native reclaiming allocator** (mmap/munmap + 재사용). 이것이 "bit-changing heap round"의 정확한 의미다. #3687-계열 `HEXA_RT_ALLOC_NATIVE` arena(`self/rt/alloc.hexa`, sys_mmap bump, default-ON)는 hexa-value arena로 **별개·FLIP-6 아님** (`state/zeroc-29-remaining-flips-prep-2026-07-03.md:81` 명시) — 건드리지 말 것.

## 순서 0: #4679 strcmp default-ON 선착지 (필수)

- 브랜치 `feat/axis2-strcmp-default-on` (head `75739333f`): `tool/stage_resolve_runtime_a`에 `_rng_strcmp_def` 추가, `HEXA_RT_NATIVE_STRCMP` seed 채택 시 `-DHEXA_RT_RANGE_STRCMP_NATIVE`를 S3 standalone `runtime_core.o` 컴파일 라인에 결합.
- 선착지 이유: (a) FLIP-6과 **같은 carrier 파일**(stage_resolve_runtime_a) — 순차 착지로 충돌 회피, (b) flip discipline = 한 번에 한 family, (c) nm-UND advisory dump(nobaseline-gate.yml:320-345)에서 strcmp −1 확인이 FLIP-6의 baseline이 됨.
- 게이트: bit-changing이므로 byteeq 3-target 리컨버지 + faithful nobaseline darwin/linux (byteeq는 stage_resolve_runtime_a 변경에 path-filter로 트리거됨, #4558 교훈). seed-miss/`=0` 시 `_rng_strcmp_def` 빈 문자열 = byte-identical fallback이 이미 설계돼 있어 #4489-형 resolver-FATAL 리스크는 해소된 패턴.

## 순서 1: FLIP-6 mechanism PR (default-OFF · byte-neutral)

**메커니즘 선택: realloc-F2 pure-D 패턴** (shim TU C-emitter body + `-D` 게이트, frozen .s seed 아님). 근거:
- F2 정확 선례: `-DHEXA_RT_NATIVE_REALLOC`이 sysheaders 전-family rename(`self/runtime_core_sysheaders.h:150-159`)과 shim self-contained body를 동시에 arm — seed 없이 양 TU 도달 (`tool/stage_resolve_runtime_a:2586-2589`).
- frozen-seed 경로는 `state/zeroc-29-wall2-frozen-seed-escape-2026-07-03.md`가 밝힌 대로 calloc의 inner `bl hxlcl_malloc` 재배치 문제(whole-module asm freeze + objcopy demotion)가 있고, **SSOT(:47)가 지적한 FLIP-6 블로커 "Route-C native body = x86_64-linux-only fp-ABI"를 C-emitter body는 타깃별 컴파일로 원천 회피**한다.

정확 편집점:
1. `self/runtime_core_hxlcl_shim_emit.hexa` — 새 게이트 `-DHEXA_RT_HEAP_NATIVE` arm: `hxlcl_malloc`(:167-176)을 mmap-직행 + F2 magic 헤더(`HXLCL_ALLOC_MAGIC` :153-155, +16 헤더 ABI **유지** — F2 realloc/free와 호환 필수)로, `hxlcl_free`(:190-211)를 libc `free(base)` 대신 **native reclaim**(large=munmap, small=size-class free-list 재사용)으로, `hxlcl_calloc`(:282-303)을 native malloc+zero로.
2. `tool/restore_frozen_seeds:392-419` — HXFARR awk 패치에 `#ifdef HEXA_RT_HEAP_NATIVE` arm: `HXFARR_CALLOC/HXFARR_FREE`를 `__libc_calloc/__libc_free` 대신 native reclaiming 경로로 매핑.
3. `tool/stage_resolve_runtime_a` — tri-state `HEXA_RT_HEAP_NATIVE:-0`(첫 PR은 명시 OFF), `-D`를 `_mo_shim_def`+`_mo_rtcore_def`에 결합 (F2가 :2586-2589에서 하는 것과 동형). realloc-F2·free-seed 강제-0(:1999-2004)과의 상호작용 명시적 정리.

**핵심 설계 제약**: farr 워크로드가 leak witness이므로 free는 반드시 실제 reclaim이어야 한다. mmap-per-alloc은 farr 대형 버퍼엔 적합하나 소형 할당엔 syscall 폭풍 — bump-chunk + free-list 이원화가 최소 설계.

게이트(이 단계): OFF = preprocess-away byte-identical → byteeq trivially GREEN (조사 확인: byteeq/faithful 워크플로 어디도 `HEXA_RT_*` env를 안 세움 = default-config만 검증).

## 순서 2: flag-ON 측정 (pool) → 순서 3: default-ON flip PR

- **byteeq는 heap-family split에 구조적으로 맹목** (#4620 커밋 메시지 명시: "only a faithful RUN witnesses a heap-family split"). 따라서 flag-ON 게이트는:
  1. faithful BUILD+RUN darwin(ghost)+linux(aiden) — #4614-형 "bare libc free(base+16) mid-chunk abort" 재발 탐지. darwin은 sysheaders rename의 `__linux__&&__GLIBC__` 게이트가 dead인 것이 #4614의 root — **darwin에서도 rename이 arm되는지가 1순위 검증 항목**.
  2. **leak witness**: carve-out을 만든 바로 그 측정 재현 — farr-heavy decode를 aiden에서 flag-ON으로 돌려 RSS FLAT(≈5MB대) 확인. 이게 GREEN 아니면 flip 금지.
  3. `nm -u runtime.a`로 `malloc`·`__libc_calloc`·`__libc_free` **−3** 확인 (advisory dump는 `__libc_` prefix를 reducible 라인에서 제외하므로(:337) TOTAL 카운트로 볼 것).
- flip PR = `:-0`→`:-auto` 한 줄 + byteeq 3-target **리컨버지**(#4621/#4651 선례) + faithful 3-target + install.sh consumer smoke. ARCHITECTURE.json:4110의 sanctioned-WALL 15U 리스트에서 `__libc_calloc/__libc_free` 제거 갱신.

리스크 요약: ① darwin free-ABI mismatch(F2 magic-guard가 방어선, foreign-pointer는 `__builtin_trap()` 유지) ② F2 realloc과 새 native free의 헤더 ABI 불일치(+16/magic 유지로 회피) ③ 소형 할당 perf 회귀(free-list 설계로 회피, bench/check_regress.sh alloc_heavy로 캡처) ④ byteeq 맹점(faithful RUN 게이트로 커버).

---

# (D) memcpy/memset -fno-builtin flip

## 사실 교정 — 무엇이 이미 끝났고 무엇이 남았나

- fast body는 **merge된 emitter SSOT**: `self/runtime_emit_full.hexa:673-699`(memcpy overlapping-load dispatch, "Measured 1.3-2.0x libc for n≤64, summer clang-18" 주석이 measurement of record) · :720-739(memset) · rename `#define memcpy→hxlcl_memcpy`는 :2877-2878 + `self/runtime_core_sysheaders.h:126,129`. **runtime.a의 mem* UND는 이미 #4604로 드랍 완료** (`state/zeroc-flip-measure-2026-07-03.txt:31,40`).
- 남은 flip 표면 = **최종 사용자 바이너리** (`state/hexa-own/memleaf_flip_design_fable.md:52`): (a) transpiler가 emit하는 bare `memcpy(` 15개소(`self/build_c.hexa:3631,3655,3676,...`), (b) 사용자 TU `-O2` 컴파일의 clang-synth mem* — 컴파일 라인은 **`self/main.hexa:3815`** (`host_cc() + " -O2 " + os_clang_cflags() + ...`), 현재 -fno-builtin 없음. SSOT(:45) 분류 = "perf lever·NOT floor drop". **단 B의 round-1b(--linker=hexa static ELF, libc 부재)에서 이 심볼들이 결국 UNDEF wall이 되므로, D는 ELF 트랙의 선행 투자이기도 하다.**

## flip이 토글하는 것 (2-편집 · 단일 게이트 `HEXA_MEM_NATIVE_PROG:-0`)

1. **symbol interposition**: runtime.a에 literal `memcpy`/`memset`/`memmove` 심볼을 fast hxlcl_ dispatch body의 alias로 제공 (게이트 -D arm으로, emitter `self/runtime_emit_full.hexa`에 추가 — OFF면 심볼 부재 = runtime.a byte-identical). 이걸로 explicit·clang-synth 호출 모두 static link에서 native body에 바인딩.
2. **사용자-프로그램 CFLAGS**: `self/main.hexa` `os_clang_cflags()`(:1380-1411)에 게이트 조건부로 `-fno-builtin-memcpy -fno-builtin-memset -fno-builtin-memmove` 추가 — :3815(사용자 바이너리)·:3781(드라이버 runtime.c)·:2282(hexa_cc.o) 세 사이트가 같은 helper를 지나므로 helper 한 곳 편집이 정답. gcc 경로는 `-fno-tree-loop-distribute-patterns` 동반 필수 (`tool/stage_resolve_runtime_a:1207-1213` 측정 기록 — body 자기재귀 방지).

**linux-first로 스코프**: darwin은 libSystem 심볼 shadow가 별도 리스크 — FLIP-7 own-start처럼 Linux-guard로 시작, darwin은 후속 rung.

## summer perf 재캡처

- **갭 하나 정직 보고**: 1.3-2.0× 수치의 bench 스크립트는 **커밋돼 있지 않다** (emitter 주석 캡처만 존재). 재캡처하려면 소형-copy 마이크로벤치를 새로 authoring해야 함 — flip PR에 `bench/` 픽스처로 함께 커밋해 재현 가능하게 만들 것.
- real-workload 게이트 (summer, flag-ON vs OFF 격리 측정·back-to-back 금지):
  - `bench/check_regress.sh --threshold 1.20` + `tool/ai_native_bench.hexa` 픽스처(alloc_heavy·dict_100k·oop_heavy·matmul_256)
  - stage-1 self-compile wall median-of-3, ≤2% 예산 (`state/static-types/wall_a_endgame.md:78` 방법론 재사용)

## default-ON 조건

① byteeq 3-target 리컨버지 GREEN (interposed 심볼이 runtime.a→compiler binary에 들어가므로 bit-changing — #4621/#4651 리컨버지-flip 선례 동형) ② faithful nobaseline 3-target ③ 위 perf 2종 non-regression 캡처 ④ install.sh consumer smoke. 선례 템플릿 = strtod-tail: `tool/stage_resolve_runtime_a:707`의 `:-1` 한 줄 flip + 게이트 주석에 측정 근거 병기.

---

# 실행 순서 (pool 배치)

| 순서 | 블로커 | 호스트 | 소요 | 산출 |
|---|---|---|---|---|
| 1 | B: release_build + run.sh | aiden | 빌드 ~10분 + 초 단위 실행 | GATE GREEN/RED 판정 + state 문서 |
| 2 | C-0: #4679 착지 | CI(3-target)+pool faithful | PR 1개 | strcmp nm −1 |
| 3 | C-1: FLIP-6 mechanism (OFF) | mini 작성 → CI | PR 1개 | byte-neutral merge |
| 4 | C-2: flag-ON faithful+leak | aiden(linux)+ghost(darwin) | 반나절 | RSS FLAT + abort-free 캡처 |
| 5 | C-3: default-ON flip | CI 3-target 리컨버지 | PR 1개 | `__libc_calloc/free`+`malloc` −3 |
| ∥ | D perf 재캡처(벤치 authoring+측정) | summer (C와 병렬, 호스트 분리) | 반나절 | 1.3-2.0× 재현 + real-workload 캡처 |
| 6 | D mechanism(OFF)→flip(linux-first) | CI+summer | PR 2개 | 사용자 바이너리 mem* native |

B가 RED로 갈리면 그 root-cause가 최우선(ELF 프론티어 전체가 미검증 상태로 회귀). C 완료 시 reducible heap family 종결 → 잔여는 sanctioned floor(net-FFI·CRT·dlopen·exec)만. D는 flip 자체보다 round-1b 연결(static ELF에서 mem* 심볼 해석)이 장기 가치다.

부수 발견 2건: ⑴ `state/hexa-own/selfhost_done_criterion_dag_fable.md:48`가 "#4651은 fictitious"라 주장하나 CLAUDE.md·CHANGELOG는 #4651을 인용 — state 문서 간 불일치, 다음 문서 정리 때 reconcile 권장. ⑵ mini 워킹트리에 CHANGELOG.jsonl 1줄 삭제가 uncommitted로 남아 있음 — 이번 계획과 무관하나 다음 커밋 전 확인 필요.