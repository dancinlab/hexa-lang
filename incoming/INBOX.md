# incoming/ — hexa-lang upstream patch 임시 도크

> **임시 메커니즘.** hexa-lang 이 self-host 트리(`self/`)에서 컴파일 버전 트리(`compiler/`)로 변신 중인 동안, upstream 언어/stdlib 변경이 **양쪽 트리에 빠짐없이 반영**되도록 하는 합류 지점. `compiler/` 가 self-host 를 byte-identical 로 대체(SPEC.md §bootstrap stage3 fixpoint)하면 이 디렉토리는 폐기 — patch 흐름이 단일 트리로 수렴하므로 더 필요 없음.
>
> 외부 세션(wilson pi-port prereq audit, anima/nexus stdlib 제안, hxa-* cross-repo blocker 등)이 hexa-lang 에 추가/변경을 요구하면 여기 등록 → 처리 → 비움.

## 디렉토리

| 파일 | 역할 |
|---|---|
| `INBOX.md` | 이 파일 — 절차 |
| `PATCHES.yaml` | 활성 patch 매니페스트 (id / source / 양쪽 트리 영향 / selftest delta / status) |
| `patches/<id>.md` | patch 별 상세 (현 상태, 구현 가이드, roadmap 초안, 테스트 포인터) |
| `patches/*.patch` | (선택) raw .patch / .diff |
| `manifest_log.jsonl` | append-only 처리 이력 |

## status enum

`pending_external` — 외부 세션이 작성 중, 아직 main 미반영
`spec` — 설계/RFC 만 있음, 구현 미시작
`in_progress` — `self/` 또는 `compiler/` 한쪽 진행 중
`synced` — 양쪽 트리(또는 해당되는 트리) 반영 완료, selftest PASS
`archived` — stable 정착, 매니페스트에서 제거 (manifest_log 에 기록 보존)

## 절차

1. **도착** — 외부 세션이 변경을 요구 → `patches/<id>.md` 작성 + `PATCHES.yaml` 엔트리 추가 (`status: pending_external` or `spec`) + `manifest_log.jsonl` append.
2. **처리** — 변경을 `self/` 에 반영 → `compiler/` 영향 매핑 적용 (RFC-020 §5 식 매핑 테이블 참조) → 양쪽 selftest. `status: in_progress` → `synced`.
3. **검증** — `tool/inbox_sync.hexa` (TODO: 미구현) 가 patch entry 의 `source` 가 main 에 실재하는지 + 양쪽 트리 정합성 검사. 미land 시 conflict 리포트.
4. **비움** — patch 가 stable → `tool/inbox_promote.hexa` (TODO) 가 매니페스트에서 `archived` 처리 + `manifest_log` 에 최종 기록. `patches/<id>.md` 는 `patches/archived/` 로 이동 가능.

## 관련

- `proposals/rfc_020_enum_payload_variants.md` — 양쪽 트리 공유 언어 기능 예시 (enum payload)
- `SPEC.yaml` §`hexa_lang_upstream_first` — fix-at-upstream 정책 (워크어라운드 금지)
- `SPEC.yaml` §`stdlib_evolution` — stdlib 변경 절차
- bedrock spec — "hexa-lang upstream 발생 시 incoming/ inbox 경유" (컴파일 버전 완성 전까지) — bedrock 쪽에 명시 예정
- `~/core/wilson/docs/hexa-lang-gap-audit.md` — wilson pi-port 가 요구하는 6개 갭 (이 inbox 의 주 source 중 하나)
