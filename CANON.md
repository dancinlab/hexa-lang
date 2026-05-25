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
  - [x] **M3b (파괴)** — DONE PR #943 (rebase 후 r2, CI 3-platform green). `git rm` hexa_v2(Mac)+hexa_v2_linux_x86_64(Linux, 5.2MB) · multiarch picker 제거 · `resolve_or_bootstrap_hexa_v2`(auto cmd_cc, go-build식) · build_hexa_cli Step0 amalgam 부트스트랩 · CI 3 workflow build/ 전환. `hexa_cc.c` C-시드 유지. **arch-leak 클래스 영구 종결.** ⚠ deploy 갭: 배포 hexa(~/.hx/bin)+로컬 메인트리는 M3b-前이라, origin/main pull 시 옛 dispatch가 build/ resolve 못함 → 배포 refresh 필요 (follow-up).
- [ ] **M4 — verb → canonical core + `hexa tool`** — 80+ verb(70 dispatch registry). core(run/build/test/parse/check/bench/cc/lsp/init/status/version) 유지, discovery(drill/loop/omega/…)+science(qrng/sim-universe/qmirror/calc/…)+audit(honesty/…)는 `hexa tool <x>` 하위 흡수. `hexa --help` 재편 (기능 폐기 아님 — 이동만).

## not-goal (의도적 제외)

- 기능 자체 제거 — verb는 `hexa tool` 아래로 옮길 뿐 폐기 아님 (drill/kick 등 discovery 엔진은 유지)
- stdlib 내부 `_v2.hexa` (bio·sim_universe 등) — 컴파일러 코어 밖이라 별 도메인. 본 CANON은 컴파일러 SSOT 한정.

## dependencies

- [[GO]] 도메인 (Go 모델 인프라 완전화 — 캐시 GC·precompile)과 자매. GO=런타임 캐시 축, CANON=소스/바이너리 네이밍 축.
- 공유 워킹트리 (3 에이전트 동시) — 모든 랜딩은 격리 worktree에서 stacked PR.
