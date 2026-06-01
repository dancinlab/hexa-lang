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
- [~] M7 — `tool/build_aprime.sh` self-contained STAGE-0 (clean `.c=0` checkout self-build) — **recipe PROVEN, in-place .sh edit governance-blocked (2026-06-01)**. 격리 worktree(`agent-a13393fc061677de6`, 진짜 `.c=0`: `self/runtime.c`·`self/runtime_core.c`·`self/native/hexat`·`build/hexat` 전부 ABSENT)에서 전 구간 검증. **두 blocker 확정**:
  - **B1 (artifact 부재)**: 빌드가 가정한 GENERATED·gitignored 산출물(`self/runtime.c` amalgam + `self/native/hexat`)이 clean checkout 에 없어 stage 직전 `hexat missing/not-executable` 로 즉시 실패. STAGE-0 regen (release CI 와 동일 검증된 메커니즘 재사용 — `tool/restore_frozen_seeds` → `self/runtime_core_emit.hexa` emitter regen + SSOT reconcile → `tool/stage_prebuild_hexat`) 로 해소: stages 1-3 가 clean tree 에서 통과 (flatten 46 files · transpile 43707L C).
  - **B2 (rt_fs 게이트 버그, regen 무관)**: `self/runtime.c` 의 builtin-init 가 `&rt_fs_append_atomic`/`&rt_fs_stat`/`&rt_fs_rotate_if_over` 를 무조건 취하지만(L13378-13380), 그 본문은 `HEXA_HAS_HEXA_RT_STDLIB` 게이트의 `#else extern` branch 로 사라짐 — codegen 은 `fs_append_atomic` 을 `rt_fs_*(...)` CALL 로만 lower(`self/codegen.hexa:7311`), 본문 미emit → `Undefined symbols: _rt_fs_append_atomic/_rt_fs_stat/_rt_fs_rotate_if_over` 로 stage 4 clang 실패. **이 버그는 pre-existing `build/self/runtime.c` 트리에서도 동일** (regen 탓 아님 = log STEP0b "on-disk 2026-05-26 stale vs self/runtime.h 2026-06-01" 의 실제 정체). stage 3 에 rt_fs link-fill(runtime.c `!HEXA_HAS_HEXA_RT_STDLIB` 와 동일한 failure-default stub 3개 append) 추가로 해소.
  - **검증 (verbatim, clean worktree)**: STAGE-0 regen → `restore_frozen_seeds` 21 seeds · `runtime_core.c` 8508L · `build/hexat` 1946184B → 전 recipe(STAGE-0 + rt_fs link-fill) → `[4/5] clang: build/aprime_cc (1455016 B, Mach-O 64-bit executable arm64)` → `[5/5] smoke: exit(6*7) => 42 PASS — aprime_cc OK`.
  - **honest-STOP**: in-place `tool/build_aprime.sh` 편집을 sidecar PreToolUse 훅(`project.tape` 마커, `.py/.sh/.c/...` 금지)이 거부, `tool/build_aprime.hexa` 로 재작성을 권고. 그러나 모든 caller 가 `bash tool/build_aprime.sh` 로 직접 호출(HEXA-NATIVE-ONLY.md:298 · GOAL.md · COMPILER.md · RUNTIME.md) → `.hexa` 사본은 어떤 caller 도 invoke 하지 않는 dead file (bash-executable 아님). 과제 제약("build 가 .hexa 를 invoke 함을 확인 없이 .hexa 로 silent rewrite 금지")에 따라 in-place STOP. recipe·proof 는 본 M7 에 기록 — landing 은 .sh-edit governance unblock(sign token / `.hexa` 진입점 전환) 후속.
