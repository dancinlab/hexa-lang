# HEXA-LANG.log — 작업 체크박스 (append-only)

> 새 작업은 `- [ ] <text>` · 완료는 `- [x] <text>` · 시작 마커는 `## <header>`.

## 2026-05-23 — domain scaffold

- [x] HEXA-LANG.md 초기 snapshot 작성 (deferred RFC 사이클 3건 등재)
- [x] HEXA-LANG.log.md scaffold

## Deferred RFC 사이클 (architect 결정 대기)

- [x] RFC 081 — Option / Result lane — design draft (`inbox/rfc_drafts_2026_05_23/rfc_081_option_result_lane.md`, D1-D6 decision points)
- [x] RFC 082 — trait operator overload — design draft (`inbox/rfc_drafts_2026_05_23/rfc_082_trait_operator_overload.md`, D1-D7)
- [x] RFC 083 — TLS primitive — design draft (`inbox/rfc_drafts_2026_05_23/rfc_083_tls_primitive.md`, D1-D7)
- [~] follow-up: type_checker `type_check` pass wiring — source-level wiring INFLIGHT (PR #503 · `type_check_and_emit` + `hexa typecheck` verb · regen-gated activation)

## architect decision (RFC 081/082/083 — next step)

- [ ] RFC 081 D1-D6 결정 (가장 큰 결정 = D1 Option/Result naming + ? operator · 권고: Rust 패턴 A/A)
- [ ] RFC 082 D1-D7 결정 (가장 큰 결정 = D2 dispatch model · 권고: static-only v1, dyn follow-up)
- [ ] RFC 083 D1-D7 결정 (가장 큰 결정 = D1 TLS library 선택 · 권고: system 동적 링크 D)

## next batch (resolved-after-decision)

- [ ] Option/Result — typechecker enum surface + `?` propagation
- [ ] Option/Result — `pop()` / `get()` / `find()` 반환채널 마이그레이션
- [ ] trait — `Add` / `Sub` / `Eq` / `Ord` 핵심 4개 dispatch
- [ ] trait — coherence / orphan rule 결정 + 검증
- [ ] TLS — vendored vs system 결정
- [ ] TLS — CA bundle 배포 결정
