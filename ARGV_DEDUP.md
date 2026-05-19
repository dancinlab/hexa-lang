# ARGV_DEDUP — RFC 062 argv[0] dedup — LANDED

> 루트 UPPERCASE.md 작업 로그. RFC 062 = ROADMAP self-host child 65 의 잔여분
> (`hexa_set_args` argv[0] 중복 삽입 제거).
> SSOT: `inbox/rfc_drafts_2026_05_12/rfc_062_argv0_dedup_args_contract.md`

## 상태 (2026-05-19) — ✅ LANDED · commit `26a785af` · origin/rfc043 푸시 완료

`hexa_set_args` 의 argv[0] 중복 삽입을 제거했다. `args()` 는 이제 clean
`[exec, user-args...]` 레이아웃을 반환한다 (구 `[exec, exec, sub, ...]` 는
R7-은퇴 인터프리터 레이아웃 일치용이었음). 118 파일 마이그레이션 + 툴체인
재생성, 격리 worktree 에서 검증 후 squash-merge 로 main 랜딩.

## 검증 결과 (worktree + main)

- **args() dedup 입증** — `args()` = `[exec, a, b, c]` 4-elem (구: 5-elem
  `[exec, exec, a, b, c]`). worktree + production `hexa` 양쪽 측정 확인.
- self-host fixpoint byte-identical (regen diff 0).
- `atlas_verify_smoke` 118/118 — worktree + main 양쪽.
- hexa.real + hexa_v2 + hexa_module_loader 빌드·실행 clean.
- parse-gate 114/115 (.hexa) — token-forge 1건은 기존 EffectDecl gap (무관).
- roadmap_view 비-빌드는 base 233548a6 에서도 동일 실패 = pre-existing
  (explicit main() call codegen 거부), 내 regression 아님.

## 마이그레이션 범위 (118 파일)

- `self/runtime.c` — hexa_set_args(dedup) · hexa_real_args(start 2→1) ·
  hexa_script_path([1]→[0]) · _hx_fuel arg-dump(2→1).
- `self/main.hexa` — dispatcher-local index shim (`av` = [exec]+args(),
  ~40 dispatch 사이트 무변경 — proven 코드 보존).
- `self/module_loader.hexa` · `self/codegen_c2.hexa` — args 인덱스 −1.
- ~89 `tool/` + `stdlib/sim_universe/**` (Agent A) — `_args[N]` −1 shift.
- 25 `tool/roadmap_*.hexa` adaptive shim — `_user_start` −1.
- `self/native/{hexa_v2,hexa_cc.c}` — RFC 062 SSOT 로 재생성.

## 진행 경위

1. P0 audit (c1b08c68) — `args()[N]` regex 로 4파일 추정.
2. 백그라운드 worktree 에이전트 dispatch → idle-timeout, 89파일 partial.
3. 사용자 (B) 선택 — 인계받아 직접 완성: main.hexa/module_loader/codegen_c2
   + roadmap 25 마이그레이션, worktree 빌드·검증.
4. squash-merge → main `26a785af` → 재검증 (atlas 118/118) → hexa.real 설치
   → origin/rfc043 푸시.

## 잔여 (binary promote — standard deploy step)

- `build/hexa_module_loader` 재빌드 완료 (로컬). 다른 호스트(pool)는 미동기 —
  standard deploy 에서 자연 promote.

## 로그

- 2026-05-19 — P0 audit. 백그라운드 에이전트 dispatch.
- 2026-05-19 — Agent A idle-timeout (89파일 partial, uncommitted) → WIP
  스냅샷 `4cc8e57e`. 사용자 (B) 선택 — 직접 인계.
- 2026-05-19 — main.hexa(adapter)/module_loader/codegen_c2 + roadmap 25
  마이그레이션. worktree 빌드 (hexa_v2 후보 + hexa.real + module_loader),
  검증 8/8 (dedup·fixpoint·atlas 118/118·core CLI). worktree commit
  `0b5addd6` + `7c61ab45`.
- 2026-05-19 — squash-merge → main `26a785af` (118 파일). atlas 118/118
  재검증. hexa.real 설치 (production dedup 확인 `N=4`). origin/rfc043 푸시.
  **RFC 062 LANDED. ROADMAP 65 완결 (API + dedup 양쪽).**
