# HEXA-LANG.log — 작업 체크박스 (append-only)

> 새 작업은 `- [ ] <text>` · 완료는 `- [x] <text>` · 시작 마커는 `## <header>`.

## 2026-05-23 — domain scaffold

- [x] HEXA-LANG.md 초기 snapshot 작성 (deferred RFC 사이클 3건 등재)
- [x] HEXA-LANG.log.md scaffold

## Deferred RFC 사이클 (architect 결정 대기)

- [ ] RFC: Option / Result lane — design draft (round-3 후속)
- [ ] RFC: trait operator overload — design draft (round-7 후속)
- [ ] RFC: TLS primitive — design draft (websocket wss:// + HTTPS 후속)
- [ ] follow-up: type_checker `type_check` pass wiring → `hexa build` 통합 또는 `hexa typecheck` verb (#453 dormant 활성화)

## next batch (resolved-after-decision)

- [ ] Option/Result — typechecker enum surface + `?` propagation
- [ ] Option/Result — `pop()` / `get()` / `find()` 반환채널 마이그레이션
- [ ] trait — `Add` / `Sub` / `Eq` / `Ord` 핵심 4개 dispatch
- [ ] trait — coherence / orphan rule 결정 + 검증
- [ ] TLS — vendored vs system 결정
- [ ] TLS — CA bundle 배포 결정
