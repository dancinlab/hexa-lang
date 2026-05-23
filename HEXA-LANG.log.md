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

### D2+ — decided 2026-05-23 (전부 권고 채택)

- [x] RFC 081 D2-D6: A (Rust `?`) · A (silent-erase `nil`) · A (generic `Result<T,E>` v1, boxed alias follow-up) · A (tagged enum repr) · B (`_opt` 변종 점진 deprecate, g4 호환)
- [x] RFC 082 D2-D7: A (Rust strict orphan) · D3a NO `Index` v1 + D3b YES `*Assign` · A (`@derive`) · C (both `<T:Bound>` + where) · A (supertrait) · D7 deferred (D1=A로 vtable 미존재)
- [x] RFC 083 D2-D7: C (sync + non-blocking) · A+C (system trust store + `HEXA_TLS_CA_BUNDLE` override) · A v1 opaque handle (RFC 082 후 method-bearing follow-up) · A+B opt-in (`HEXA_TLS_INSECURE=1`) · A (PQ system 위임) · B (`stdlib/net/tls.hexa` + websocket/http 동반 이동)

### impl 진입 가능 — 이번 사이클

- [~] RFC 082 impl phase a — trait bound parser surface scaffold (INFLIGHT 이 세션)

## next batch (resolved-after-decision)

- [ ] Option/Result — typechecker enum surface + `?` propagation
- [ ] Option/Result — `pop()` / `get()` / `find()` 반환채널 마이그레이션
- [ ] trait — `Add` / `Sub` / `Eq` / `Ord` 핵심 4개 dispatch
- [ ] trait — coherence / orphan rule 결정 + 검증
- [x] TLS — vendored vs system 결정 (D, system 동적 링크)
- [ ] TLS — CA bundle 배포 결정 (D2+)

## 2026-05-24 — phi_rs closure + /cycle 1-6 머지 배치

- [x] phi_rs inbox closure — PR #530 검토 + RFC 084 promote (option A cdylib path) · RFC 036 phi_rs byte-equal smoke selftest 등록 (PR #545)
- [x] enum-to-string 스택 PR-1 — enum variant names 배열 codegen emit (additive, PR #555)
- [x] enum-to-string 스택 PR-2.0 — runtime `TAG_ENUM` 슬롯 + defense 분기 (PR #566)
- [x] enum `to_string` codegen-emit fail-honest 분해 — 단일 surgical fix 불가 확정, 스택 분해 근거 inbox notes 기록 (PR #553)
- [x] RFC 085 promote — dispatcher hygiene (env-var + `.hexarc` + `--local`, rfc_026+028 통합, PR #552)
- [x] RFC 086 promote — atlas memcap unblock (rfc_066, PR #558)
- [x] RFC 087 promote — macro-expander pass design (PR #556)
- [x] RFC 088 promote — hexa-cloud preflight + typed env-var (PR #563)
- [x] RFC drafts INDEX — 2026-05-24 초안 084-088 카탈로그 등재 (PR #564)
- [x] 27 patches archive — 해결 패치 manifest_log 이관 + PATCHES.yaml 동기화 (PR #562)
- [x] json_object no-op 사이클 finding inbox 기록 (PR #551)
- [~] atlas `hxc` dead-ref 정리 — `hxc_loader` dead refs + obsolete hxc smoke tests retire, `n6/atlas.n6` 단일 SSOT (PR #576, 진행 중)
- [~] enum 스택 PR-2.1 + RFC 047 atom (진행 중)
