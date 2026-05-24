# GO — hexa-lang `hexa run/build` Go-ergonomic 정리 도메인

> 한 줄: hexa-lang 의 사용자-대면 CLI (`hexa run`/`hexa build`) 를 Go (`go run`/`go build`) 수준의 무신경(no-friction) 사용감으로 정리.

@goal: hexa-lang CLI 가 캐시·디스크·재컴파일·toolchain 발견 전반에서 사용자가 신경 쓸 게 0 인 상태가 된다 (Go `go run`/`go build` 수준).

## 진행 milestone

- [x] M1 — `~/.hexa-cache/` 자동 GC (LRU + TTL + tmp orphan sweep). default cap 2 GiB / TTL 30 일 / env override (`HEXA_CACHE_CAP_MB`, `HEXA_CACHE_TTL_DAYS`). (PR #887 머지)
- [x] M2 — `tool/build_precompile.hexa` 파이프라인 + `self/main.hexa` cmd_run lookup precompile dir 우선 probe + `tests/m_precompile_hit_test.hexa` e2e. cold-cache fork-storm 의 *내부* axis (release 시점 precompile → 사용자 첫 호출 즉시 cache HIT).
- [x] M3 — `tool/precompile.json` declarative manifest (어떤 script 가 precompile 대상). Go 의 `go install <pkg>` 패턴 mirror. demo: 2 entry (atlas_cli · build_hexa_cli).
- [x] M4 — release tarball CI 통합 (`tool/build_precompile.hexa` 자동 호출 + tar 에 `release/precompile/` 동봉) → `.github/workflows/release.yml` Stage 3 추가 (3 job), Package 에 staging+smoke assert 추가.
- [x] M5 — hexa daemon RFC draft (fork-storm internal axis · design-only · *직교* — run-time persistent process vs M2/M3 release-time precompile) → `docs/rfc/rfc_drafts_2026_05_25/rfc_093_hexa_daemon.md`. 권장 = Option A stand-alone daemon (`hexa-daemon` verb · unix socket · opt-in autospawn · fork-mode fallback).
- [x] M6 — manifest 확장 (demo 2 entry → 10 production-hot scripts) + schema 확장 (descriptions/categories sister keys, additive)
- [x] M7 — `version_str()` 자동 drift 검사 (M2/M3 builder ↔ cmd_run 동일 version 보장) → `tests/m_version_str_consistency_test.hexa` (static `return "<literal>"` extractor; drift = RC=1 with clear `DRIFT DETECTED` message; PASS = `"0.1.0-dispatch"` on both sides).
- [x] M10 — hexa daemon R1 prototype (RFC 093 Phase 1). `hexa daemon {start,start-bg,stop,status,echo}` over per-user unix socket (`/tmp/hexa-daemon-$USER.sock`) · newline-text wire (PING/ECHO/SHUTDOWN) · idle-TTL self-exit · `self/runtime.c` 소켓 primitive 복원 (cycle-61 stub → real libc) · `tests/m_daemon_r1_test.hexa` 4-step e2e PASS. NO compile logic (R2). fork-storm *internal* axis 의 첫 실코드 (M2/M3 release-time precompile 와 직교).

## cross-link

- 진척·측정값 SSOT = `GO.log.md`
- 본 파일 = "왜" 의 SSOT (north-star)
