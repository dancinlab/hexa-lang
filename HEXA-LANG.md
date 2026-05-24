# HEXA-LANG — 도메인 현황 스냅샷

> 현재 상태 (current-state, g15). 이력은 [HEXA-LANG.log.md](HEXA-LANG.log.md) · `CHANGELOG.md` · `git log`.

@goal: Native compiler with atlas-bound theorems — 8 strict-lint stages, citation-enforced, no LLVM, no C-transpile, self-host.

## 진행 milestone

- [x] archive/patches origin/main 0 truly-open — 모든 mechanical/agent-tractable 항목 해소
- [x] transpiler regen #454 기반 cycle-3 batch 활성화
- [x] RFC 081/082/083 design draft + D1-D7 결정 (Option/Result · trait · TLS)
- [x] atlas n6/atlas.n6 단일 SSOT — hxc 완전 퇴역 (PR #312/#314/#315/#316/#576)
- [x] enum stack — PR-1 (variant names) · PR-2.0 (TAG_ENUM 슬롯) · PR-2.1 (single variant) · PR-2.2 (all-unit) 닫음
- [x] verify lane — float (welch_t / wilson_hilferty) + integer (ssh_winding / tknn_chern) 두 path 활성화
- [x] atlas register 게이트 — `register_from_event` 🟢 NUMERICAL 허용 (RFC 047/046 atom land)
- [ ] RFC 082 impl phase a — trait bound parser surface scaffold (INFLIGHT)
- [ ] RFC 081 impl — typechecker enum surface + `?` propagation
- [ ] RFC 083 impl — TLS primitive (system OpenSSL/SecureTransport 동적 링크)
- [ ] type_checker `type_check` pass `hexa build` 통합 wiring (PR #503 follow-up)

## 정체성

native compiler with atlas-bound theorems · 8 strict-lint stages · no LLVM · no C-transpile · self-host. SSOT = `github.com/dancinlab/hexa-lang` (`hx install hexa-lang`).

## 현재 운영 상태

| 영역 | 상태 |
|---|---|
| archive/patches (origin/main) | **0 truly-open** — 모든 mechanical/agent-tractable 항목 해소 |
| transpiler (`self/native/hexa_v2`) | regen #454 기반 (cycle-3 batch 활성화) |
| local toolchain | HEAD 동기화 + 설치 완료 |
| 핵심 게이트 | atlas-bound lint · diff-guard subagent · wipe-guard hook (opt-in) · external-LLM gate (`hexa loop --dfs` only) |

## 활성 게이트 / 거버넌스

- `g11` upstream gap → `archive/patches/<slug>.md` 즉시 filing · workaround 금지
- `g4` stacked PR <200줄 · 1 logical thing
- `g5` 검증은 `hexa verify` (LLM self-judge 금지)
- `g8` rented-GPU pod → `hexa cloud {run|nohup|poll|copy-*|preflight}` canonical
- `g27` ship cycle — commit + push + reinstall local copy

전체 governance = `commons.tape` (sidecar) · `project.tape` (이 repo 루트).

## Deferred RFC 사이클 — 전체 타입시스템 / multi-week 인프라

이하는 mechanical fix 범위를 넘어선 **dedicated RFC 사이클**이 필요한 항목. 각 항목은 design RFC → 구현 사이클(들) → 검증 순서로 진행.

### RFC 후보 1 — Option / Result lane (canonical-audit round-3)

- **range**: 타입시스템 (Rust `Option<T>` / `Result<T,E>` 또는 Swift Optional)
- **trigger**: round-3 design-level — `nil` ident 무성-coerce, `[].pop()` 무성-void, error 채널 부재
- **scope**: 핵심 enum 2종 (`Option` / `Result`) + `?` propagation operator + 표준 lowering (typechecker · codegen · stdlib 핵심 helper)
- **canonical ref**: Rust `std::option` / `std::result` + `?` operator
- **blocker**: 기존 코드 광범위 영향 (pop / get / find 의 반환 채널 일괄 이동) — 마이그레이션 사이클 동반 필요

### RFC 후보 2 — trait operator overload (canonical-audit round-7)

- **range**: 타입시스템 (Rust `Add` / `Sub` / `Mul` / `Div` / `PartialEq` / `PartialOrd` trait + 연산자 dispatch)
- **trigger**: round-7 design-level — `struct + struct`, `struct == struct` 가 silent-wrong builtin 으로 떨어짐
- **scope**: `trait` 선언 surface 확장 + 연산자 → 메서드 dispatch (typechecker + codegen) + 핵심 stdlib trait (`Add` / `Sub` / `Eq` / `Ord` 등)
- **canonical ref**: Rust `std::ops::Add` 등 + Swift `protocol AdditiveArithmetic`
- **blocker**: trait system 자체의 dispatch 모델 결정 (정적 vs 동적 · coherence rule · orphan rule 등) — 별도 design RFC 선행

### RFC 후보 3 — TLS primitive (wss:// · HTTPS · secure runpod control plane)

- **range**: 런타임 / C primitive (~multi-week)
- **trigger**: `archive/patches/websocket-streaming-client-websocat-dependency` wss:// 분기 · 일반 HTTPS 호출 · 보안 control plane
- **scope**: hexa-native TLS 1.3 client (handshake · certificate validation · session resume) — libsodium 기반 또는 OpenSSL/BoringSSL 바인딩
- **canonical ref**: BoringSSL / rustls API 형태
- **blocker**: 외부 의존성 결정 (vendored sub-runtime 추가 vs system OpenSSL 링크) · 인증서 store 정책 · CA bundle 배포 방식

## 알려진 dormant 기능

- **type_checker let-immut / match-exhaustive warning** (#453) — 로직은 compile 됐으나 transpile 파이프라인이 `type_check` 호출 안 함. 사용자노출 wiring (`hexa build` 통합 또는 `hexa typecheck` verb) follow-up 필요. corpus 약 1322 warning 예상 (warn-not-error 였던 이유).

## 참고

- `RUNTIME.md` — runtime 도메인 SSOT
- `GPU.md` · `COMPILER.md` · `FLAME.md` 등 — 도메인별 spec/log split
