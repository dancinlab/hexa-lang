# CANON — current state

@goal: hexa 컴파일러 바이너리·소스·CLI를 Go/Rust canonical 모델로 정렬한다 — v2/버전 딱지를 전부 떼고, 컴파일러 바이너리는 git에서 완전 제거하여 빌드 산출물화(go install·cargo 모델), `_v2` 접미사 소스는 무접미사로, 트랜스파일러는 `hexa cc`로 흡수(go tool compile식 은닉), 116 verb는 canonical core + `hexa tool <x>`로 정리.

## 결정 (2026-05-25 정렬)

| 축 | 결정 | 근거 |
|---|---|---|
| 컴파일러 바이너리 | git에서 **완전 제거** (gitignore + 빌드 산출물) | 정통 Go/Rust — 소스만 SSOT |
| 부트스트랩 | release 바이너리 다운로드 또는 stage0 보관 재설계 | 첫 빌드 chicken-and-egg 해소 |
| 트랜스파일러 이름 | `hexa cc` 흡수 (별도 바이너리 X) | 기존 verb 재활용 · `hexa_cc.c` 일치 · gc/rustc 운율 |
| 진행 | 전체 플랜 · stacked PR (g4, 각 <200줄) | 비가역 단계는 단계별 검증 |

## scope

| 잔재 | 현황 | canonical 종착 |
|---|---|---|
| 컴파일러 바이너리 | 7개 git 커밋 (8.3MB) | 0개 (gitignore) |
| `_v2` 소스 접미사 | lexer_v2·parser_v2·type_checker_v2·codegen_c2_v2 (v1 없음) | 무접미사 |
| `.bak` git 잔재 | hexa_cc.c.bak.* 5개 | 0개 |
| CLI verb | 116개 | core + `hexa tool <x>` |

## milestones (open)

- [x] **M1 — 안전 잔재 제거 (코드 미사용분만)** — DONE PR #930 (merged). `hexa_v2_baseline·_test·_nobt71·_pre71·_rfc011` **5개**(~3.45MB) `git rm` + `.gitignore` 변종 재유입 차단. `.bak`는 이미 untracked(`*.bak.*` 기존 패턴)였음. `hexa_v2`(Mac) + `hexa_v2_linux_x86_64`(Linux 시드)는 코드 의존 → M3로. 검증: `hexa parse` OK · 코드참조 0.
- [x] **M2 — `_v2.c` 죽은 생성물 삭제** (rename→삭제로 전환) — DONE PR #932 (merged). 조사 결과 4개 `_v2.c`는 "LEGACY PARITY ONLY · NOT referenced" 헤더 명시 + `#include` 0건 + `runtime_c_purge.md` Phase C "완전 삭제" 등재 → rename이 아니라 **삭제**가 canonical. `lexer/parser/type_checker/codegen_c2 _v2.c` + `.hexanoport` 8개 (−7,686 LOC). dead ref 정리(`build_hexa_cli.hexa`·`codegen.hexa` 주석·purge md). 라이브=`hexa_cc.c` 무영향.
- [x] **M3 — 컴파일러 바이너리 git 제거 + Go 1.4식 C-시드 부트스트랩** (2단계 분해 · 둘 다 DONE)
  - [x] **M3a (비파괴)** — DONE PR #934. `cmd_cc` 출력 → `build/hexa_v2` · `resolve_hexa_v2` 가 build/ 우선(self/native fallback 유지). CI bootstrap green.
  - [x] **M3b (파괴)** — DONE PR #943 (rebase 후 r2, CI 3-platform green). `git rm` hexa_v2(Mac)+hexa_v2_linux_x86_64(Linux, 5.2MB) · multiarch picker 제거 · `resolve_or_bootstrap_hexa_v2`(auto cmd_cc, go-build식) · build_hexa_cli Step0 amalgam 부트스트랩 · CI 3 workflow build/ 전환. `hexa_cc.c` C-시드 유지. **arch-leak 클래스 영구 종결.** ⚠ deploy 갭: 배포 hexa(~/.hx/bin)+로컬 메인트리는 M3b-前이라, origin/main pull 시 옛 dispatch가 build/ resolve 못함 → 배포 refresh 필요. → **M5 에서 종결**(소스 dispatch 정상 확인 + refresh 절차 문서화).
- [x] **M4 — verb → canonical core + `hexa tool`** — DONE PR #964 (merged). `hexa tool [list|<verb>]` 드로어 추가: `cmd_tool_list()` family 인덱스 + `cmd_tool(av)` bare-verb re-dispatch(별칭) + main dispatch `tool` 케이스 + `hexa --help` tool 줄. bare `hexa <verb>` 전부 유지(이동 아닌 그룹화). +48 LOC `self/main.hexa`.
- [x] **M5 — M3b deploy 갭 종결** — DONE. 진단 결과 **소스 dispatch 는 정상**(origin/main `self/main.hexa` 에 `resolve_or_bootstrap_hexa_v2` 존재, auto-bootstrap e2e PASS) — 갭은 순수 **배포 측**: 배포 바이너리(`~/.hx/bin/hexa` shim → 메인트리 `hexa.real`/`hxv2`)가 M3b-前이라 `self/native/hexa_v2` 만 찾고 auto-bootstrap 안 함. 코드 변경 불요. 처방 = 아래 **배포 refresh 절차** 문서화 + 로컬 배포 바이너리 M3b+ 로 1회 refresh. fresh clone/CI 는 이미 build/ 모델이라 무영향.
- [x] **M6 — M4 polish: tool family 완성도 + `--help` 재편 마무리** — DONE PR #973 (merged). dispatch 100 verb 전수감사 → 고아 8개 발견 → 5번째 family `TOOLCHAIN` 신설(batch·typecheck·cache·daemon·convergence·tape·hxc·url·stdlib) + `n6-list`→ANNOTATOR + `loop` SCIENCE→DISCOVERY 재분류 → 5-family 전부 non-empty(고아 0·dead-entry 0). core=everyday 11개로 정리. net −5 LOC.
- [x] **M7 — `_v2` dead-ref 스윕** — DONE PR #970 (merged). 전체 grep → DEAD-REF 1건(`COMPILER.md` vestige 표의 삭제파일 2행)만 제거. 활성 코드/빌드/CI dead-ref 0(M2가 이미 청소). LIVE(`hexa_v2` 바이너리명·`build/hexa_v2`·`hexa_cc.c` 시드·stdlib `_v2.hexa`) 보존.
- [x] **M9 — 문서 surface 정확성 스윕 (M1~M8 정렬)** — DONE. README/COMPILER/RUNTIME/SPEC/GOAL/ROADMAP/CHANGELOG/INBOX/HANDOFF + `doc/**` 인벤토리 후 현재 canonical 상태와 대조. **present-tense 거짓 2건만 수정**(보수적): (1) `COMPILER.md` "vestige inventory" 표 — `self/codegen_c2.hexa`(이미 `codegen.hexa`로 rename #387)·`hexa_v2`/`hexa_cc.c`(M3b git-제거+seed 유지)·`.bak`/`_v2.c`(M1/M2 삭제) 3행에 **DONE** 주석, 미완 정공법행(aprime_cc·s4_flatc_post)은 보존. (2) `SPEC.md` L693 present-tense 설명의 `codegen_c2.hexa`→`codegen.hexa`. **보존**: README L137·SPEC L803·CHANGELOG L143·HANDOFF·RUNTIME.md cycle 로그의 `codegen_c2.hexa`/`hexa_v2`는 전부 commit-SHA 박힌 시점기록 or rename 기록이라 무손상. README 내부 링크 5/5 resolve 확인. 코드 편집 0(docs-only). net +10/−7.

**✅ M1~M9 전부 DONE — CANON @goal 4축(바이너리 git 제거 · `_v2` 종결 · `hexa cc` 흡수 · verb canonical 정리) 종결.** 남은 follow-up = `build_hexa_cli.hexa` install-step 자동화(M5 노트, pull 후 단일 verb refresh — optional polish).

## 배포 refresh 절차 (M3b post-pull)

origin/main pull 이 컴파일러 바이너리를 떨어뜨리면(M3b), **배포된 hexa 가 M3b-前 dispatch 면** 다음 빌드가 `self/native/hexa_v2 not found` 로 실패한다. 1회 refresh 로 종결:

1. **부트스트랩** — `build/hexa_v2` 를 hexa_cc.c amalgam 으로 시드 (Go 1.4 식 C-seed):
   `sed 's|#include "runtime.h"|#include "runtime.c"|' self/native/hexa_cc.c > build/_amalgam.c && clang -O2 -fbracket-depth=2048 -I . -I self build/_amalgam.c -o build/hexa_v2`
2. **드라이버 빌드** — `hexa tool/build_hexa_cli.hexa` (또는 1번이 만든 `build/hexa_v2` 로 module_loader → flatten → main 트랜스파일 → `build/hexa_cli_driver`). Mac 은 `LOCAL_BUILD=1`, pool-route 회피는 `SIDECAR_NO_POOL_ROUTE=1`.
3. **배포** — `build/hexa_cli_driver` 를 shim 이 가리키는 바이너리로 복사: 메인트리 `hxv2`(shim 우선 해석) + `hexa.real`(fallback) + `~/.hx/bin/{hxv2,hexa.real}`; Mac 은 `codesign --force --sign -`.
4. **검증** — `build/hexa_v2` 제거 후 `hexa build <tiny>.hexa <out>` → `[bootstrap] build/hexa_v2 absent — building transpiler via hexa cc` → `OK: hexa_cc rebuilt` → `OK: built` 가 뜨면 종결. (정상 dispatch 면 build/hexa_v2 가 자동 재생성됨.)

향후 자동화 후보: `build_hexa_cli.hexa` 에 install 단계(shim 타깃 복사)를 추가하면 pull 후 단일 verb 로 종결 (M3b 의 install-step 부재가 본 갭의 근인).

## not-goal (의도적 제외)

- 기능 자체 제거 — verb는 `hexa tool` 아래로 옮길 뿐 폐기 아님 (drill/kick 등 discovery 엔진은 유지)
- stdlib 내부 `_v2.hexa` (bio·sim_universe 등) — 컴파일러 코어 밖이라 별 도메인. 본 CANON은 컴파일러 SSOT 한정.

## dependencies

- [[GO]] 도메인 (Go 모델 인프라 완전화 — 캐시 GC·precompile)과 자매. GO=런타임 캐시 축, CANON=소스/바이너리 네이밍 축.
- 공유 워킹트리 (3 에이전트 동시) — 모든 랜딩은 격리 worktree에서 stacked PR.
