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

## architect decision (RFC 081/082/083)

### D1 — decided 2026-05-23

- [x] RFC 081 D1 = **A** (Rust `Option<T>` + `Result<T, E>`) — naming/lane decision
- [x] RFC 082 D1 = **A** (Static only v1 monomorphization, `dyn Trait`은 follow-up)
- [x] RFC 083 D1 = **D** (system OpenSSL/SecureTransport 동적 링크 v1, vendored는 reproducible-build 시점 follow-up)

### D2+ — open (다음 architect 사이클)

- [ ] RFC 081 D2-D6 (propagation operator · nil keyword · boxed error · runtime repr · prelude policy)
- [ ] RFC 082 D2-D7 (coherence/orphan · operator-method 매핑 · derive · trait surface 등)
- [ ] RFC 083 D2-D7 (sync/async API · CA bundle · ALPN · session resume 등)

## next batch (resolved-after-decision)

- [ ] Option/Result — typechecker enum surface + `?` propagation
- [ ] Option/Result — `pop()` / `get()` / `find()` 반환채널 마이그레이션
- [ ] trait — `Add` / `Sub` / `Eq` / `Ord` 핵심 4개 dispatch
- [ ] trait — coherence / orphan rule 결정 + 검증
- [x] TLS — vendored vs system 결정 (D, system 동적 링크)
- [ ] TLS — CA bundle 배포 결정 (D2+)
