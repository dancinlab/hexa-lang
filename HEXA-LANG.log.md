# HEXA-LANG.log — 작업 체크박스 (append-only)

> 새 작업은 `- [ ] <text>` · 완료는 `- [x] <text>` · 시작 마커는 `## <header>`.

## 2026-05-23 — domain scaffold

- [x] HEXA-LANG.md 초기 snapshot 작성 (deferred RFC 사이클 3건 등재)
- [x] HEXA-LANG.log.md scaffold

## Deferred RFC 사이클 (architect 결정 대기)

- [x] RFC 081 — Option / Result lane — design draft (`docs/rfc/rfc_drafts_2026_05_23/rfc_081_option_result_lane.md`, D1-D6 decision points)
- [x] RFC 082 — trait operator overload — design draft (`docs/rfc/rfc_drafts_2026_05_23/rfc_082_trait_operator_overload.md`, D1-D7)
- [x] RFC 083 — TLS primitive — design draft (`docs/rfc/rfc_drafts_2026_05_23/rfc_083_tls_primitive.md`, D1-D7)
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
- [x] atlas `hxc` dead-ref 정리 — `hxc_loader` dead refs + obsolete hxc smoke tests retire, `n6/atlas.n6` 단일 SSOT (PR #576)
- [x] enum 스택 PR-2.1 — 단일 enum 변종 `TAG_ENUM` emit + `to_string` synth (PR #582)
- [x] RFC 047 atom — verify float-path 부재 finding inbox 기록 (PR #577)
- [x] canonical-audit r10 — RFC 045 audit pass · long-ident truncation NOT reproducible (PR #591 archive)

## 2026-05-24 — cycle 7 batch (CHANGELOG + RFC 089 + RFC 046 audit)

- [x] CHANGELOG batch sync — 2026-05-24 session batch 기록 (phi_rs + enum stack + RFC 084-088 + atlas hxc cleanup, PR #578)
- [x] RFC 089 promote — `hexa_ld --shared` + `dlopen` 동적 링크 surface (rfc_070 승격, PR #580)
- [x] naming convention sweep — round-7 PROBE NO-OP 확정 (snake_case 통일 검증, finding only)
- [x] RFC 046 audit pass — ssh_topology Zak + Hofstadter Chern integer-only finding (verify int-path 미지원, PR #586)

## 2026-05-24 — cycle 8 batch (verify lane + enum PR-2.2 + 43 archive)

- [x] verify float recompute path — `welch_t_crit` + `wilson_hilferty` 닫음 (RFC 047/046 float-atom unblock, PR #587)
- [x] enum 스택 PR-2.2 — all-unit-variant enum `TAG_ENUM` emit (last 14 corpus failure → 0, PR #589)
- [x] RFC 046 finding land — verify int-path 미지원 정황 inbox notes (PR #586)
- [x] 43 patches archive — 해결 패치 manifest_log 이관 (cycle re-triage 중단, PR #588)

## 2026-05-24 — cycle 9 batch (atom register gate + dispatch + scope leak + r10)

- [x] atlas register 게이트 확장 — `register_from_event` 에서 🟢 NUMERICAL tier 허용 (RFC 047 atom 풀린, PR #593)
- [x] verify ssh_winding + tknn_chern integer recompute — RFC 046 atom enabler (PR #592)
- [x] integer match arm block-body scope leak — codegen 스코프 누수 surgical fix (PR #595)
- [x] canonical-audit r10 closure — P0 long-ident truncation NOT reproducible archive (PR #591)
- [x] runtime RSS poll SIGSEGV — `_hx_self_rss_bytes` unhook-safe Linux fix (F-LIVE-DISPATCH, PR #594)

## 2026-05-24 — cycle 10/11 in-flight (atom payoff + drill + CHSH)

- [x] domain init — `/domain init hexa lang` 으로 `HEXA_LANG.md` + `HEXA_LANG.log.md` (underscore) scaffold + `@goal:` 선언 (PR #596)
- [x] CHANGELOG + PROBE r14 cycle 7-11 batch sync — ~40 PR 묶음 (PR #597, rebased land)
- [x] raw string `r"..."` literal — lexer surface (PROBE r14-UUUU, PR #598)
- [x] drill `--rounds N` multi-round resume state — `hexa drill` 재진입 버그 fix (PR #599)
- [x] match as tail-expression — arm value 반환 codegen (PROBE r14-VVVV, PR #600 in-flight)
- [x] H3X DFT 6q records — h3o/h3po/h3cl/h3f/h3si Tier 2 SUPPORTED atom 등록 (PR #557)

## 2026-05-24 — domain log cycle 6-10 sync (g52 auto-log + g39 domain)

- [x] HEXA-LANG.log cycle 6-10 진행 step 동기화 — unblocker chain + atom payoff 기록 (이 PR)
