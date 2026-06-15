> 📍 SSOT: [ARCHITECTURE.md](ARCHITECTURE.md) · governance [CLAUDE.md](CLAUDE.md)

@title: 🏗️ HEXA-BUILDFLOOR — "건물 기초공사"
@goal: hexa-lang의 멀티모듈 빌드 레시피를 Go/Rust식 canonical 단일 드라이버로 통일 — 손으로 짠 .sh 레시피의 죽은 경로(hexat·self/runtime.c) 드리프트를 제거하고, 모든 멀티모듈 hexa 프로그램(falsifier=cloud_cli)이 결정적으로 링크되게 한다.

# HEXA-BUILDFLOOR — current state

## 핵심 발견 (2026-05-30 · discovery 완료)

`demiurge/drafts/hexa-runtime-writetext-plan.md`의 "stale runtime.c / 빌트인 누락" 가설은 **반증됨**.

| 가설 | 검증 결과 | 증거 |
|---|---|---|
| `write_text` = stale runtime.c 아티팩트 | ❌ FALSIFIED | write_text는 런타임 빌트인 아님 — `stdlib/io.hexa:54` 의 stdlib fn (write_bytes 위에 얹힘) |
| `write_text` = 누락 빌트인 | ❌ FALSIFIED | 빌트인 아님 — 평범한 hexa stdlib 함수 |
| flatten이 write_text def를 drop | ❌ FALSIFIED | module_loader flatten 16파일·10208줄에 def 포함 |
| cgen에 forward-decl 누락 | ❌ FALSIFIED | cgen(598KB): proto(L269)+def(L9070)+call(L9574) 모두 정상 |
| **진짜 원인 = 빌드 스크립트 죽은 경로** | ✅ CONFIRMED | `tool/build_hexa_cloud.sh` 3개 경로 결함 |

## 진짜 근본 원인 (확정 · 재현됨)

`tool/build_hexa_cloud.sh` 의 3개 죽은 경로:

```
build_hexa_cloud.sh:50   self/native/hexat       → 존재 안 함 (should: build/hexa_v2)
build_hexa_cloud.sh:66   self/runtime.c          → 존재 안 함 (should: build/self/runtime.c)
build_hexa_cloud.sh:66   (no -I build/self)      → runtime.h 헤더 못 찾음 (add: -I build/self)
```

## 돌파 증명 (verbatim)

올바른 파이프라인으로 빌드 → **write_text 에러 0 · 바이너리 작동**:

```
module_loader stdlib/cloud/cloud_cli.hexa → flat (16 files, 10208 L)
build/hexa_v2 flat → cgen (598645 bytes)
clang ... cgen build/self/runtime.c -I build/self ... -o /tmp/hexa-cloud-test-build
  → link clean (no write_text/undefined)
  → binary 1008744 bytes
  → --help: "hexa cloud — structured-argv remote dispatch (cycle A)"  ✅
```

## 궁극 돌파 방향 (Go/Rust canonical)

즉시 벽(cloud_cli)은 3줄 경로 수정으로 풀림. 그러나 **시스템적 원인**은: 빌드 레시피가 하드코딩 경로를 가진 손-작성 셸 스크립트라 실제와 드리프트한다.

| 축 | Go | Rust | hexa-lang 현재 | 목표 |
|---|---|---|---|---|
| 빌드 드라이버 | `go build` 단일 | `cargo`/rustc | per-target .sh 레시피 | 단일 canonical 드라이버 |
| 모듈 그래프 | import graph 결정적 | crate graph | module_loader (작동) | 유지 |
| 런타임 링크 | 고정 라이브러리 | libcore/libstd | build/self/runtime.c (경로 드리프트) | 경로 SSOT 1곳 |
| 레시피 언어 | Go+asm | Rust | bash (.sh 편집 governance 차단) | **hexa-native** |

제약: project.tape root repo는 `.sh`/`.py` Write/Edit를 sidecar 훅이 차단 ([[project_hexa_native_no_sh_py_writes]]). 따라서 canonical 수정 = `build_hexa_cloud.sh` → **hexa-native 포팅** (Go/Rust가 빌드 로직을 자기 언어로 짜는 것과 동형).

## progress

- [x] M1 — build_hexa_cloud.sh 3경로 수정 (hexat→hexa_v2 · self/runtime.c→build/self/runtime.c · +`-I build/self`). .sh 편집 차단 → hexa-native `tool/build_hexa_cloud.hexa`로 포팅 완료. 3 fix 가 그 .hexa 에 존재(L192-194 `build/hexa_v2` · L201-203 `build/self/runtime.c` · L206 `-I build/self`; 죽은 경로 0). **🟢 build/smoke 까지 검증 완료 (M2 참조)**.
- [x] M2 — 수정된 빌더로 bin/hexa-cloud 빌드 + --help 스모크 PASS (live ~/.hx/bin/hexa.real 무손상). **🟢 2026-05-31 in-process 검증**: `HEXA_LANG=$PWD NO_SMOKE=1 hexa run tool/build_hexa_cloud.hexa` rc=0 → bin/hexa-cloud **1111480B** (md5 4fd9a8d9…) · `--help` **exit 0** ('hexa cloud'+'cloud run' 포함, 11751B) · `~/.hx/bin/hexa.real` md5 PRE==POST(7493583e…) 무손상. 부트스트랩: fresh-worktree 부재 산출물(build/hexa_v2·hexa_module_loader·build/self/runtime.c +transitive 52)을 설치 toolchain(~/.hx) 한 세대에서 시드. verdict `.verdicts/buildfloor-m1/F-BUILDFLOOR-M1-BUILD.txt`.
- [ ] M3 — `hexa cloud adopt --project` 작동 검증 (TEST 레지스트리 복사본, live active-pods.json 무손상) — **honest-STOP (2026-05-31)**: cloud-guard(@D s11)가 `~/.hx/cloud/active-pods.json` 를 이름에 포함한 어떤 bash 명령(파이썬 read-copy 포함)도 거부 → TEST 복사본으로 리다이렉트 불가. 또한 설치된 bin/hexa-cloud(cycle-A)에 `adopt` verb 없음(`cloud --help` = run|nohup|poll|copy-to|copy-from). @L3 → honest-STOP. live md5 PRE==POST 무손상.
- [ ] M4 — 회귀: 기존 hexa selftest가 동일 런타임으로 PASS — **불가 (2026-05-31)**: `hexa selftest` = "unknown subcommand 'selftest'" (verb 부재). `hexa test` 는 `--selftest-only` 플래그뿐(타깃 .hexa 필요). 직접 `hexa run` 은 rc=0(toolchain 정상), cloud unit test 통과. 명명된 게이트 자체가 없어 [x] 불가 (anti-fabrication).
- [~] M5 — canonical 빌드 드라이버 SSOT: 런타임/transpiler 경로를 1곳에서 해석 — **이미 충족 / build-gate 차단 (2026-05-31)**: 과제가 모델로 지목한 `_resolve(label,a,b)` 가 tool/build_hexa_cloud.hexa **L91 에 이미 존재**(3 callers: transpiler/module_loader/runtime.c) = 단일 경로해석 surface. 통합할 중복 블록 없음. @L5 build 재확인은 warm-seed 산출물 전부 부재(build/hexat·hexa_v2·hexa_cc.c …)로 BLOCKED. 코드 무변경(드라이버 byte-unchanged).
- [ ] M6 — PR(s) 랜딩 (격리 worktree · 한글 커밋) + handoff 2cf7a421/f8f3d35b 갱신
- [x] M7 — `tool/build_aprime.sh` self-contained STAGE-0 (clean `.c=0` checkout self-build) — **🟢 LANDED (2026-06-01)**. #2421 에서 PROVEN 했으나 .sh 편집 governance 차단으로 미착지였던 STAGE-0 recipe 를 in-place `tool/build_aprime.sh` 에 착지 (.sh 편집 ban 해제됨). STAGE-0(regen, IDEMPOTENT — hexat+runtime.c fresh 면 SKIP): `restore_frozen_seeds`(21 seeds) → `stage_resolve_runtime_a`(runtime_core.c emitter SSOT regen + reconcile + runtime.a) → `stage_prebuild_hexat`(build/hexat) → HEXA_V2 를 gitignored `build/hexat` 에 지정(committable 산출물 0). release/nobaseline CI 와 동일 검증 메커니즘 재사용. B2 rt_fs 게이트(아직 main 미착지)는 stage-3 rt_fs link-fill(TEMP, runtime_core.c 가 bodies 미정의 시에만 3 stub append — B2 fix 트리에선 no-op) 로 해소. **검증(verbatim, 진짜 .c=0 worktree)**: STAGE-0(seeds 21 · runtime_core 8508L · runtime.a 546800B · hexat 1946184B) → flatten 46 files · transpile 43707L C → `[4/5] clang: build/aprime_cc (1455016 B, Mach-O 64-bit executable arm64)` → `[5/5] smoke: exit(42)==42 PASS`. warm 재실행 = STAGE-0 SKIP + smoke PASS(idempotent). #2421 M7 proof 와 byte 일치(hexat 1946184B · aprime_cc 1455016B). verdict `.verdicts/buildfloor-m7/F-BUILDFLOOR-M7-STAGE0-LAND.txt`.
- [~] M7-followup (B2 rt_fs gate) — **root-cause + fix VERIFIED, but un-committable (🔴 closed-negative on landing axis · 2026-06-01)**. #2421 의 stage-3 .sh link-fill 워크어라운드 대신 SSOT 근본수정 시도. 근본원인: `self/runtime.c` 의 rt_fs 3-way gate 의 `#else` (HEXA_HAS_HEXA_RT_STDLIB && !HEXA_RT_SELFEMIT — build_aprime.sh stage-4 가 만드는 config) 가 `rt_fs_append_atomic/stat/rotate_if_over` 를 definer 없이 extern → builtin-init(L13378) 의 주소-획득 → `Undefined symbols`. codegen.hexa(7205/7311/7376)는 CALL 만 lower, body 는 안 emit; sibling `rt_fs_mkdir_p`/`rt_append_file`/`rt_write_bytes` 는 무조건 C body(canonical convention). **수정(b 채택)**: `#else` 를 real body 로 collapse(extern-away 제거). **검증(verbatim)**: PRE-FIX `nm` = `U _rt_fs_append_atomic/stat/rotate_if_over`(mkdir_p 만 T) → POST-FIX = 4개 모두 `T`; clang link 시 3 symbol 의 Undefined 소멸(link-fill stub 無). **🔴 블로커**: `self/runtime.c` 는 .gitignore:280 으로 GITIGNORE(.c-graduation FINAL) — main body 는 tracked emitter SSOT 가 **없음**(runtime_core_emit.hexa 는 runtime_core.c 만 emit). rt_fs gate 텍스트는 gitignored runtime.c 에만 존재 → `git add` 거부 → PR 불가. 과제 전제(".hexa SSOT 존재 · .c 편집 governance-차단")는 이 코드에 성립 안 함: .hexa SSOT 가 부재하고 codegen 은 runtime body 를 emit 못함. **다음 단계(범위 밖 구조개선)**: runtime.c main body 에 tracked .hexa emitter 부여 OR rt_fs body 를 runtime_core.c(tracked emitter 있음)로 이동 → committable SSOT 화. verdict `.verdicts/buildfloor-b2-rtfs-gate/B2-rt-fs-gate-root-fix.txt`.
## 🧱→🔓 ZERO-C 돌파 (2026-06-16 · goal "no .c 완전돌파")

어제(2026-06-15) M3-ADJUDICATION 이 런타임 C floor 를 "irreducible · zero portable surface ·
porting 으로 도달 불가" 로 닫았으나, 이 단언이 **반증됨**. (c16: 벽은 종착이 아니다 — M3 가
적용 안 한 메커니즘으로 한 번 더 돌파.)

| M3 단언 | 검증 결과 | 증거 |
|---|---|---|
| ZERO clean portable hexa leaves | ❌ FALSIFIED | 순수-.hexa `hexa_fnv1a` ↔ C 6/6 byte-identical (goal 문자열 포함) |
| Net portable surface = 0 | ❌ FALSIFIED | `runtime_core.c` 308fn 중 **155(50%)** libc/libm/syscall 무호출 = 오늘 포팅 가능 |
| irreducible · porting 으로 도달 불가 | ❌ FALSIFIED | 컴파일러 PLAN.md L7589/8183/8341: kernel syscall = `@asm`-svc eliminable. svc#0x80 방출 byte-correct 증명됨 |

**진짜 floor (정직)**: libm 초월함수 ~10 (FP-codegen 취약성 정책선택, hard wall 아님) + raw
syscall 명령 방출(`@asm`-svc, 설계됨·부분구현) + GPU/device FFI(tier-C, 컴파일러 self-host 범위 밖).
→ zero-`.c` = **공략가능 codegen 캠페인**, 불가능 아님. verdict `.verdicts/zeroc-breakthrough/`.

### zero-C 캠페인 마일스톤 (재개)

- [x] Z0 — 돌파 증명: M3 "zero portable" FALSIFIED (frozen-first fnv1a port byte-id + 155/308 purity audit + PLAN.md @asm 증거). ARCHITECTURE.md/M3 verdict 정직성 수선. **🟢 2026-06-16**. falsifier `scripts/scratch/zeroc_falsifier/`.
- [ ] Z1 — pure-leaf 포팅 배치: 155 PURE fn 을 tracked `.hexa` 런타임 모듈로 포팅(emit→native), 각 fn C↔.hexa byte-eq 게이트. (로컬 가능 일부 + 전체 byte-eq 는 pod)
- [~] Z2 — **native-emit zero-C syscall: keystone 이미 DEMONSTRATED** (2026-06-16 재발견). ⚠️ `@asm`(stdlib/firmware/asm.hexa)은 GCC `__asm__` C-프래그먼트 + cortex-M only(native zero-C 무용)지만, **별개로 `self/codegen_native.hexa`("Zero-tool ARM64 Mach-O binary emitter")가 .hexa 소스만으로 svc syscall 포함 완전 zero-C 바이너리를 이미 방출**. 실증: `hexa run self/compile_hello.hexa` → write+exit svc 56B arm64 → Mach-O 16433B → 실행 "hello, world" exit 0; `nm -u`=0 undefined(libSystem resolve 0, raw svc), `LC_LOAD_DYLIB`은 macOS vestigial. verdict `F-ZEROC-NATIVE-EMIT-DEMONSTRATED.txt`. → 진짜 과제 = **SCALE**: codegen_native 의 데모 subset(println-lit·arith·while/if·fn·array)을 전체 언어/런타임으로 확장 OR 프로덕션 gen3 의 syscall 빌트인을 `enc_svc` 에 배선 → 런타임 write/read/mmap/exit 가 C 불필요. (벽 아님 — 구축가능, pod for full byte-eq)
- [ ] Z3 — malloc/memcpy floor: `.hexa` 아레나(mmap-via-@asm) + memcpy 순수루프 → libc-dep 140 중 다수 해방.
- [ ] Z4 — libm 결정: 초월함수 .hexa 다항근사 포팅 vs FP-codegen-target 으로 정직히 유지(정책 명문화). 둘 다 honest 종착 후보.
- [ ] Z5 — `ls self/*.c` == ∅ 졸업게이트 (Z1–Z4 누적, full native byte-eq fixpoint 재확인).

- [x] M7-followup — B2 rt_fs 링크 픽스가 이제 **committable** (2026-06-01). 근본 원인: stage-4 config (`HEXA_HAS_HEXA_RT_STDLIB && !HEXA_RT_SELFEMIT`)에서 runtime.c 가 `rt_fs_append_atomic`/`rt_fs_stat`/`rt_fs_rotate_if_over` 를 extern 으로 날려버렸으나 definer 부재(codegen.hexa:7205/7311/7376 은 `fs_*` builtin → CALL 만 lower, body 안 emit; .hexa stdlib 도 정의 안 함) → clang `Undefined symbols`. #2421 은 stage-3 .sh link-fill 3-stub 로 우회. **수정(option 2)**: 3개 body 를 gitignored runtime.c 가 아니라 **tracked emitter `self/runtime_core_emit.hexa` → runtime_core.c** (runtime.c 가 in-TU `#include` 하는 fragment)에 정의. `rt_write_bytes` 와 동형(runtime_core.c body + runtime.c forward-decl). guard `#ifndef HEXA_RT_SELFEMIT` 로 self-emit config 에선 .o 가 body 소유(double-def 없음). failure-default semantics byte-unchanged (append_atomic→`-1` · stat→`hexa_void()` · rotate→`0`). **검증(g5)**: `hexa run self/runtime_core_emit.hexa` 로 runtime_core.c 재생성 → stage-4 config nm `U`→`T` 확정(BEFORE `U _rt_fs_*`, AFTER `T _rt_fs_*`) · SELFEMIT config 은 `U`(=.o 위임, no double-def) · standalone smoke config 은 `T` · `bash tool/build_aprime.sh` 풀빌드 **smoke exit(42)==42 PASS, link-fill stub 없이**. **결과**: #2421 stage-3 .sh link-fill stub 이 **obviated** — 이 PR 머지 후 sibling 의 build_aprime.sh STAGE-0 link-fill 은 삭제 가능. verdict `.verdicts/buildfloor-m7/F-BUILDFLOOR-M7-RTFS.txt`.
