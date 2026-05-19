# ARGV_DEDUP — RFC 062 구현 시도 + 정직한 재측정

> 루트 UPPERCASE.md 작업 로그. RFC 062 = ROADMAP self-host child 65 의 잔여분
> (`hexa_set_args` argv[0] 중복 삽입 제거).
> SSOT: `inbox/rfc_drafts_2026_05_12/rfc_062_argv0_dedup_args_contract.md`

## 결론 (2026-05-19) — P2 는 60+ 파일 repo-wide 마이그레이션, 기능 이득 0

RFC 062-P2 (argv[0] dedup flip) 의 실제 구현을 착수했고, 그 과정에서 **blast-radius
가 P0 추정(4파일)의 15배 = 60+ 파일**임을 측정으로 발견했다. 구현 파일은 revert
했고 (작업트리 클린), 정직한 재측정만 남긴다.

## 무엇을 했나

1. P0 audit (commit c1b08c68) — `args()[N]` regex 로 4파일 추정.
2. 실제 구현 착수 — runtime.c (hexa_set_args dedup + real_args + script_path +
   _hx_fuel) · main.hexa (dispatcher-local adapter) · module_loader · codegen_c2 ·
   ssot_mirror 수정.
3. **구현 중 전수 audit 재실행** — `args()` 가 `_args`/`argv`/`cli_args` 로
   alias 되거나 `loop-from-2` 패턴으로 소비되는 경우 P0 의 `args()[<digit>]`
   regex 가 못 잡았음을 발견.
4. 전수 결과: 위치-의존 소비처 = **60+ 파일** (아래).
5. 구현 5파일 revert — runtime dedup 을 ship 하면 60+ 파일이 조용히 깨짐.

## 측정된 진짜 blast-radius (60+ 파일)

| 그룹 | 파일 수 | 패턴 |
|------|--------|------|
| `tool/roadmap_*.hexa` 보일러플레이트 | ~25 | `_raw_argv[1]=="run"` · `argv[2]==_script_token` · `_user_start=3` |
| `stdlib/sim_universe/**` | ~25 | `_args[2]` / `[3]` / `[4]` 위치 인덱싱 |
| `self/` | 5+ | main.hexa · module_loader · codegen_c2 · build_c(`_argv[2/3]`) · edit_cli/attr_cli/fs_fuse_skel(`_ai=2`) · hexa_build(`argv[1/2]`) |
| `tool/` 기타 | 10+ | flame_phase4*(`argv[2/3]`) · ai_native_*(`argv[2]`) · jit · build · emit_esm · ssot_mirror |

P0 가 4파일로 추정한 이유: `args()[2]` 직접 인덱싱은 4곳뿐이고, 나머지는 모두
`let _args = args()` 후 `_args[2]` 또는 `_ai=2` 루프 — alias 된 이름이라 regex 회피.

## 정직한 판단

- RFC 062 §6 caveat 가 명시했듯 dedup 은 **사용자-가시 버그를 고치지 않음** —
  doubled 레이아웃은 무해한 관례. P2 는 순수 cosmetic.
- 60+ 파일 · 다중 서브시스템(roadmap tools + sim_universe 15 experiments +
  self 부트스트랩) · 각 바이너리 재빌드+재검증 = 자율 1-pass 안전 불가.
- 기능 이득 0 인 cosmetic cleanup 을 위해 60+ 파일을 마이그레이션하는 것은
  나쁜 trade. `runtime.c:5571` 작성자의 deferral 판단이 옳았다 (오히려
  "40+ sites" 도 과소추정 — 실제 60+).
- ROADMAP 65 의 가치있는 절반(canonical `script_path()`/`real_args()` API)은
  이미 shipped. dedup 자체는 **WONTFIX 권장** 또는 무기한 defer.

## 상태

- 코드 변경: **없음** (구현 5파일 revert, 작업트리 클린).
- 문서: RFC 062 §6c (corrected blast-radius) · ROADMAP 65 · PLAN.md · 이 파일.
- 결정 필요 (사용자): P2 를 WONTFIX 처리할지 / 60+ 파일을 multi-session
  캠페인으로 진행할지.

## 로그

- 2026-05-19 — 추적 파일 생성. P1/P2 실제 구현 착수.
- 2026-05-19 — 구현 중 전수 audit 으로 blast-radius = 60+ 파일 발견 (P0 의
  4파일 추정은 alias/loop 패턴을 regex 가 못 잡아 15× 과소). 구현 5파일 revert.
  RFC 062 §6c 정정 + WONTFIX 권장. 코드 무변경.
- 2026-05-19 — 커밋 `3c91cf03` (docs only). origin push 는 네트워크 다운으로
  pending — 복구 시 `git push origin rfc043-hexa-torch` 필요.
- 2026-05-19 — 사용자 "all bg go" 지시. 백그라운드 worktree 에이전트 2개
  dispatch: (A) RFC 062 60+파일 dedup 마이그레이션, (B) RFC 061-P1
  runtime_core.c 추출. 격리 worktree 라 main 툴체인 안전 — 완료 시 cherry-pick
  + runtime.c 충돌 해소 + 통합 검증 (A·B 둘 다 runtime.c 변경 → 충돌 예상).
