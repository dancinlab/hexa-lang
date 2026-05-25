# VERIFY-KIT — append-only step log

> 도메인 SSOT 스냅샷 = `VERIFY-KIT.md`. 이 파일은 step-by-step 작업 이력만 누적한다.

---

## 2026-05-26 — 도메인 개시 + V2 (P0b) value-less compute mode

### 개시
- VERIFY-KIT 도메인 신설. `hexa verify` 의 계산 primitive 확장 lane. catalogue-mirror(OEIS/DLMF/ARXIV) 흡수의 공통 upstream — 흡수가 부딪힌 "측정 도구 부재" 를 푼다.
- 로드맵 V1-V10 (P0-P5) 등록. V2 가 첫 milestone.

### V2 — value-less compute mode (DONE)
- 문제: `--expr <fn> <n> <v>` 는 기대값 `<v>` 를 미리 줘야 함 → 재확인만 가능, 계산 불가. 스윕이 `σ(7)=?` 를 CLI 로 못 얻음.
- 구현: `tool/verify_cli.hexa` 의 `--expr` 핸들러 확장 (g0 Occam — 새 verb 없이 기존 verb 확장). 새 헬퍼 `cmd_expr_compute(rest, ops)` + 플래그 헬퍼 `_has_compute(rest)` 추가. 기존 3-arg verify 경로는 무손상.
- **disambiguation 규칙 (operand-count)**: compute = verify 형태에서 trailing `<v>` 를 뺀 것. 즉 operand 가 정확히 1개 적음.
  - `--expr sigma 7` (operand 1개, 후행값 없음) → COMPUTE σ(7). int 1-op 에는 0-op verify 형태가 없으므로(0-op 은 float 전용·이미 float 경로로 분기) len-3 은 모호하지 않음 → 자동 compute.
  - `--expr sigma 7 8` (operand+값) → 기존 VERIFY σ(7)==8 (무손상).
  - 다중 operand compute (`--expr sigma_k 12 1`) 는 1-op verify (`--expr <fn> <n> <v>`) 와 arg-count 충돌 → 명시 `--compute` 마커 필요 (`--expr sigma_k 12 1 --compute`). backward-compat 우선: 마커 없으면 항상 기존 verify 로 라우팅.
- 출력: `COMPUTE: sigma(7) = 8` + self-verify (recompute 2회 — 결정론 보장 → 🔵, 불일치 시 🔴 계산기버그). compute 는 read 이므로 atlas auto-absorb 미발동 (value-bearing verify 형태만 absorb).
- surgical (g34): `--expr` 핸들러 + 헬퍼 + usage 텍스트만 수정. diff = +120 / -7 (additions-only, wipe-guard clean).

### 빌드 + 검증 결과
- parse-gate: `hexa parse tool/verify_cli.hexa` → `OK: parses cleanly`.
- build: `bash tool/build_hexa_verify.sh` → **SUCCESS** (bin/hexa-verify). origin/main 에서 INBOX-언급 link blocker(static_atlas/sigma_k 미정의) 는 재현되지 않음 — 정상 빌드.
- 측정 (verbatim → `.verdicts/verify-kit-compute-mode/v2_compute.txt`):
  - `--expr sigma 7` → `COMPUTE: sigma(7) = 8` 🔵 (1+7)
  - `--expr tau 6` → `COMPUTE: tau(6) = 4` 🔵 (1,2,3,6)
  - `--expr phi 6` → `COMPUTE: phi(6) = 2` 🔵 (1,5)
  - `--expr sigma_k 12 1 --compute` → `COMPUTE: sigma_k(12,1) = 28` 🔵
  - `--expr no_such_fn 5` → 🟠 INSUFFICIENT (compute mode)
  - 회귀(verify 무손상): `--expr sigma 6 12` → 🔵, `--expr sigma 6 99` → 🔴, `--expr sigma_k 12 1 28` → 🔵
- V2 tier = 🟢 (built + tested).

### downstream
- OEIS O3 라인 cross-link: V2 compute mode 가 per-hit fresh verify unblock.
- 다음: V1 (미러 통합) · V3 (tolerance verify) · V4 (특수함수 stdlib → DLMF 재개).
