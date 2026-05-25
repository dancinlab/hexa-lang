# CANON — log

Append-only history sister of `CANON.md`. Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.

## 2026-05-25T15:50Z — M5 배포 갭 종결 (M3b follow-up · 문서+로컬 refresh)

격리 worktree `agent-a335d0f5c56d3f26d`. M3b 가 남긴 deploy 갭 진단·종결.

- [x] **진단** — origin/main `self/main.hexa` 에 `resolve_or_bootstrap_hexa_v2` 존재(M3b+, 7 call-site). 배포 `~/.hx/bin/hexa.real`(=메인트리 `hexa.real`, md5 `cb08a6a8`, 5/23) `strings` 에 M3b dispatch 문자열 0 → **PRE-M3b**. 실증: 배포 hexa `parse self/main.hexa` → `error: hexa_v2 transpiler binary not found` + `self/native/hexa_v2` 만 검색(build/ 아님, auto-bootstrap 안 함). 갭 = 순수 배포 측, 소스 무결.
- [x] **auto-bootstrap 재현 PASS** — 현재 소스로 드라이버 빌드(Step0 amalgam `hexa_cc.c` → `build/hexa_v2` → module_loader → flatten → main 트랜스파일 → `build/hexa_cli_driver`). `build/hexa_v2` 제거 후 `hexa build <tiny>` → `[bootstrap] build/hexa_v2 absent — building transpiler via hexa cc` → `=== Rebuilding hexa_cc ===` → `OK: hexa_cc rebuilt`(1.92MB 재생성) → `OK: built` → 산출물 실행 `M5 bootstrap reproduction OK`. `parse self/main.hexa` → `OK: parses cleanly`. (refuse-gate 회피 `LOCAL_BUILD=1`·출력 상대경로; pool-route 회피 `SIDECAR_NO_POOL_ROUTE=1`)
- [x] **로컬 배포 refresh** — shim 해석 = `~/.hx/bin/hexa` → 메인트리 `hexa` shim → `__hexa_dir`=메인트리 → `hxv2`(우선)→`hexa.real`(fallback). M3b+ 드라이버를 메인트리 `hxv2`+`hexa.real`+`~/.hx/bin/{hxv2,hexa.real}` 에 배포(codesign). pre-M3b 바이너리는 `~/.hx/bin/hexa.real.bak-pre-m3b-2026-05-25` 백업. **배포 shim e2e**: `hexa_v2` 제거 후 `~/.hx/bin/hexa build` → `[bootstrap]…` 발화 → `OK: built` → auto-bootstrap PASS.
- [x] **랜딩** — 코드 변경 불요(소스 dispatch 정상). docs-only: CANON.md M5 milestone + 배포 refresh 절차 + M3b ⚠노트 종결 표기. self/main.hexa 미수정(M6 sibling 충돌 회피).

**핵심**: M3b 갭은 dispatch 코드가 아니라 **install-step 부재** — `build_hexa_cli.hexa` 가 드라이버를 만들지만 shim 타깃으로 복사하는 단계가 없어 pull 후 배포 바이너리가 stale 잔존. 향후 자동화 = build 툴에 install 단계 추가(M5 노트의 follow-up 후보).

## 2026-05-25T05:23Z — M3b 컴파일러 바이너리 git 제거 + auto-bootstrap (PR #943 merged · 파괴)

CANON stacked PR 3/4 마지막. 격리 worktree `/tmp/canon-m3b`. **M3 완전 종결** (M3a+M3b).

- [x] **부트스트랩 게이트1·2** — Mac arm64 + Linux x86_64 양쪽 `cc hexa_cc.c runtime.c` → 동작 컴파일러. 바이너리 git 제거 가능 확정.
- [x] **편집 5축** — (1) self/main.hexa: multiarch picker(`_hexa_v2_basename`·`_pick_hexa_v2_in_dir`) 제거 · `_pick_hexa_v2_with_build` build/ 전용 · `resolve_or_bootstrap_hexa_v2` 래퍼(resolve 실패→cmd_cc 자동→재resolve, go-build식) · 5 호출부 통합 · cmd_status 경로. (2) build_hexa_cli.hexa: `_pick_hexa_v2`→build/ · Step0 amalgam cc 부트스트랩. (3-5) CI 3 workflow(bootstrap·release·docker-runner) self/native/hexa_v2→build/hexa_v2. + git rm 2 바이너리(5.2MB) + .gitignore.
- [x] **auto-bootstrap e2e** — build/hexa_v2 없는 상태 `hexa build` → `[bootstrap] build/hexa_v2 absent → hexa cc` → cmd_cc → build/hexa_v2 1.92MB 자동생성 → 실행 PASS.
- [x] **rebase 충돌 해소** — 작업 중 origin/main +6 PR(특히 #937 codegen이 hexa_v2 재생성). 충돌=delete(M3b) vs modify(main). rebase: 바이너리 삭제 유지 · main.hexa auto-merge 무손상(transpile-check 9329줄 OK) · hexa_cc.c는 main #937판 채택.
- [x] **CI green 게이트** — force-push git-guard 차단 → 새 브랜치 r2. 첫 PR #942 gh api 가 충돌(DIRTY)로 CI 미트리거 → rebase 후 #943 정상 트리거. **bootstrap 3-platform 전부 pass**(macos 38s·linux-x64 1m48s·linux-arm64 2m49s = fresh checkout clean-clone e2e) → 수동 squash 머지.

**교훈**: (1) force-push는 git-guard 차단 — rebase 후엔 새 브랜치 push. (2) 충돌(DIRTY) PR은 gh api 생성해도 CI 미트리거(merge-ref 못 만듦) → 충돌 먼저 해소. (3) CANON 같은 codegen-adjacent 작업은 origin/main 이동(타 세션 codegen PR이 hexa_v2 재생성) 때문에 base-stale 충돌 잦음.

**deploy 갭 (follow-up)**: origin/main 엔 hexa_v2 바이너리 없지만, 배포 hexa(`~/.hx/bin`)+로컬 공유 메인트리는 M3b-前 dispatch(self/native만 resolve). 메인트리 pull 시 바이너리 없어짐 → 옛 dispatch가 build/ 못 찾아 빌드 실패 가능. 처방 = 배포 hexa 를 M3b+ dispatch(resolve_or_bootstrap)로 refresh, 또는 pull 후 1회 `hexa cc`. CI/새 clone 은 무영향(이미 build/ 모델).

## 2026-05-25T04:26Z — M3a 컴파일러 빌드 산출물화 1단계 (PR #934 merged · 비파괴)

CANON stacked PR 3/4. 격리 worktree `/tmp/canon-m3a` (base origin/main `94847ab7`, M2 반영). M3을 비파괴(M3a)/파괴(M3b) 2단계로 분해 — 위험 분리.

- [x] **부트스트랩 가능성 게이트** — 게이트1 Mac arm64 `clang hexa_cc.c(amalgam) → /tmp/hexa_v2_fresh_mac`(2.08MB) + tiny transpile OK. 게이트2 Linux x86_64(ubu-1) `gcc → 2.2MB` + transpile OK. → `cc hexa_cc.c runtime.c`가 양쪽서 동작 컴파일러 생성 = 바이너리 git 제거 가능 확정.
- [x] **self/main.hexa 3변경** (29+/10−) — `cmd_cc` 출력 `self/native/hexa_v2`→`build/hexa_v2`(+mkdir) · 신규 `_pick_hexa_v2_with_build(root)`(build/ 우선·self/native fallback) · `resolve_hexa_v2` 각 probe root에서 build/ 우선.
- [x] **e2e (M3b 시뮬)** — 커밋 바이너리 2개 임시 숨김 + `build/hexa_v2`(=fresh_mac) 만 둔 채 `hexa build` → `[1/2] ./build/hexa_v2 선택` 확인 → 실행 출력 정상. 즉 커밋 바이너리 없이 build/만으로 자족 입증. (refuse-gate 회피: 출력 상대경로·`LOCAL_BUILD=1`; pool-route 회피: `SIDECAR_NO_POOL_ROUTE=1`)
- [x] **랜딩** — PR #934 merged. worktree+원격 브랜치 정리. CI bootstrap in_progress (dispatch 변경이라 결과 모니터).

**주의/교훈**: `hexa cc` verb는 pool-route가 heavy로 보고 ubu 라우팅 → Mac 로컬 worktree 검증 시 `SIDECAR_NO_POOL_ROUTE=1` 필요. `hexa build`는 Darwin refuse-gate(출력 `/tmp/` 차단·L2278 + `_mac`/`_darwin` basename 차단) → 출력 상대경로 + `LOCAL_BUILD=1` escape.

**M3b 진입 메모**: 커밋 바이너리 2개 `git rm` + picker 제거 + .gitignore. M3a로 build/ 경로·자족 이미 입증됐으므로 M3b는 실제 제거 + **fresh clean clone e2e**(새 git clone → 바이너리 0 → hexa cc → build)만 남음. 가장 비가역 — 사용자 확인 권장.

## 2026-05-25T04:16Z — M2 죽은 `_v2.c` 생성물 삭제 (PR #932 merged · rename→삭제 전환)

CANON stacked PR 2/4. 격리 worktree `/tmp/canon-m2` (base origin/main `8f93affd`, M1 반영). **계획 전환**: 원래 M2 = "무접미사 rename"이었으나 조사로 `_v2.c`가 죽은 생성물임이 드러나 삭제로 전환.

- [x] **전환 근거 확정** — `codegen_c2_v2.c` 헤더 자체 "LEGACY PARITY ONLY · NOT referenced by any build script, CI workflow, or test harness" · `#include` 0건(grep) · 라이브=`hexa_cc.c`(통합 후계) · `doc/plans/runtime_c_purge.md` Phase C(L90-93) "완전 삭제" 공식 등재 · 전제 P7-7 fixpoint(gen1≡gen2) 기 증명. → rename은 죽은 코드를 canonical 이름으로 살려두는 anti-pattern, 삭제가 정답.
- [x] **삭제 8개** — `lexer_v2.c`(758)·`parser_v2.c`(3169)·`type_checker_v2.c`(1697)·`codegen_c2_v2.c`(2062) + `.hexanoport` 짝 4개. −7,686 LOC.
- [x] **dead ref 정리** — `tool/build_hexa_cli.hexa:240` 빌드제외 목록 → `hexa_cc.c`만 남김 · `self/codegen.hexa:8620` 주석에서 `codegen_c2_v2.c` 언급 제거 · `runtime_c_purge.md` Phase C 표 ✅ 삭제됨 마킹.
- [x] **검증** — `hexa parse` codegen/build_hexa_cli/main → OK · 잔존 참조 0건. wipe-guard = `WIPE-OK:` trailer (생성물 7.7k 삭제).
- [x] **랜딩** — PR #932 merged. worktree + 원격 브랜치 정리 완료.

**M3 진입 메모**: 컴파일러 본체 바이너리 git 제거 — `hexa_v2`(Mac) + `hexa_v2_linux_x86_64`(Linux). `main.hexa:1804-1823` multiarch picker 제거 → 각 머신서 `cc hexa_cc.c self/runtime.c -I self -o build/hexa_v2` (Go 1.4 C-시드 모델, bootstrap.yml L69-71이 이미 이 방식). `hexa_cc.c`는 부트스트랩 시드로 git 유지. `hexa cc` verb가 흡수. **가장 비가역 — clean clone e2e 게이트 필수**. M1+M2와 달리 M3는 부트스트랩 건드리므로 단독 라운드 권장.

## 2026-05-25T04:05Z — M1 변종 바이너리 잔재 제거 (PR #930 merged)

CANON 도메인 stacked PR 1/4. 격리 worktree `/tmp/canon-m1` (base origin/main `7b798c24`)에서 작업.

- [x] **변종 바이너리 5개 git rm** — `hexa_v2_{baseline,test,nobt71,pre71,rfc011}` (~3.45MB). 전부 코드/CI/빌드 미사용, .md/.sh 문서 언급만 (grep 코드참조 0건 검증).
- [x] **.gitignore 재유입 차단** — 변종 5개 명시 패턴 추가. `.bak`/`.pre_`는 기존 `*.bak.*`·`hexa_v2.pre_*` 패턴으로 이미 차단됨 (git untracked 확인).
- [x] **검증** — `hexa parse self/main.hexa` → OK. flame `tool/flame_phase4b_build.sh:56`의 baseline 언급은 주석(피하라는 경고)이라 삭제가 오히려 단순화.
- [x] **랜딩** — PR #930 merged (pr-cycle 훅 자동 --admin 머지). 로컬 switch/원격삭제는 main이 타 worktree 점유로 멈춤 → 수동 `git push origin --delete` + `worktree remove`로 정리.

**M2 진입 메모**: `_v2.c` 4개 rename. 참조 3곳 (`self/codegen.hexa:8620` 주석 · `codegen_c2_v2.c:9` 자기주석 · `tool/build_hexa_cli.hexa:240` 빌드제외 목록). 짝 파일 `.hexanoport` 4개(`lexer_v2.c.hexanoport` 등)도 동반 rename 검토. rename 후 codegen 재생성 + fixpoint byte-eq 필수.

