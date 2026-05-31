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
- [ ] M3 — `hexa cloud adopt --project` 작동 검증 (TEST 레지스트리 복사본, live active-pods.json 무손상)
- [ ] M4 — 회귀: 기존 hexa selftest가 동일 런타임으로 PASS
- [ ] M5 — canonical 빌드 드라이버 SSOT: 런타임/transpiler 경로를 1곳에서 해석 (Go/Rust식, per-target 셸 레시피 드리프트 제거)
- [ ] M6 — PR(s) 랜딩 (격리 worktree · 한글 커밋) + handoff 2cf7a421/f8f3d35b 갱신
