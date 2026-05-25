# ATLAS — log

Append-only step log for the theorem-atlas upgrade campaign. Newest on top.

## 2026-05-25 — R3 re-verify-🟢 부활 (META-SIGNAL ② 해소 첫 슬라이스)

`hexa atlas reverify [--limit N]` 신규 서브커맨드 (tool/atlas_cli.hexa, +167 LOC additive). 등록 시 동결된 🟢 SUPPORTED-NUMERICAL F-노드를 **in-process로 재계산**해 verdict drift를 보고 — 동결 등록 verdict를 영원히 신뢰하지 않는다.

- 폐기된 RFC-017 §5e `retroactive_sweep`(compiler/discover/retroactive_sweep.hexa)의 경량 후계: tombstone/cascade/auto-PR 없이 **read-only** drift 리포트만. atlas 무변경.
- 각 🟢 F-노드 헤더 `@F <id> = <fn>(<args>) = <claimed>` 파싱 → 기존 `_recompute_float_register`(verify_cli float 테이블 미러) 재실행 → ε=1e-9 비교. disposition = MATCH / DRIFT / UNVERIFIABLE.
- exit 1 (drift 존재 시) → CI 게이트 가능. subprocess spawn 0 (35노드 즉시).
- 빌드 검증: bin/hexa-atlas (borrowed main-repo transpiler · `SIDECAR_NO_POOL_ROUTE=1` · HEXA_MODULE_LOADER 명시). parse-gate OK.

**발견 (실측)**: 전수 reverify 35 노드 중 **32 MATCH · 3 DRIFT**.
  - `allen_dynes_tc`(claimed=181.157 vs recompute |Δ|=1.8e-4)
  - `mcmillan_tc`(149.923 vs |Δ|=1.2e-4)
  - `bcs_gap_ratio`(3.52775 vs |Δ|=4.0e-6)
  3노드 모두 **반올림 리터럴로 등록**(6 sig fig)되어 full-precision 재계산과 ε 초과 불일치. 동결-verdict 모델이 한 번도 못 잡은 registration-hygiene drift — reverify가 정확히 surface. (재등록은 후속: 새 값이 맞으면 register 갱신.)

후속(이월): 비-F kind 재검증(L/E numerical) · 🟢 외 tier · reverify drift→자동 재등록 옵션 · in-process float 테이블 외 fn(현재 UNVERIFIABLE skip).

## 2026-05-25 — R1 fan-out 착지 (cycle-full)

`/gap full` 40-렌즈 스윕 → 8패밀리 갭 리포트 → 5-way 병렬 fan-out. 4/5 머지, 1 블록.

- [x] #948 register fold dedup(kind,id)+atomic write (embed_fold.hexa + atlas_cli.hexa)
- [x] #945 cite_missing_count audit metric — 8194 미인용 / 456 인용 (audit.hexa)
- [x] #946 atlas-consistency CI (.github/workflows/atlas-consistency.yml)
- [x] #950 static_atlas() process-cache — 파싱 9→1/proc (static_index.hexa)
- [ ] C5 drill novelty-fixpoint — 수정 작성(yields.total→overlay_lines_emitted)·parse-clean이나 `--rounds≥2` SIGSEGV(선재 의심)로 검증 막힘 → R2 이월

선행 작업: #935 RTSC supercon 13노드(10 verified @F + 3 measured-Tc @E), atlas 16088→16101.

발견: drill `--rounds≥2` SIGSEGV(seed-pool smash 경로 선재 의심) · pool-route 훅이 agent worktree에서 `hexa build` 거부.
