# GO — hexa-lang `hexa run/build` Go-ergonomic 정리 도메인

> 한 줄: hexa-lang 의 사용자-대면 CLI (`hexa run`/`hexa build`) 를 Go (`go run`/`go build`) 수준의 무신경(no-friction) 사용감으로 정리.

@goal: hexa-lang CLI 가 캐시·디스크·재컴파일·toolchain 발견 전반에서 사용자가 신경 쓸 게 0 인 상태가 된다 (Go `go run`/`go build` 수준).

## 진행 milestone

- [ ] M1 — `~/.hexa-cache/` 자동 GC (LRU + TTL + tmp orphan sweep). default cap 2 GiB / TTL 30 일 / env override (`HEXA_CACHE_CAP_MB`, `HEXA_CACHE_TTL_DAYS`).
- [ ] M2 — `hexa run` 첫-호출 warm cost 측정 + 캐시 hit 경로 zero-fork 가시화 (TBD)
- [ ] M3 — TBD (사용자 결정 대기)
- [x] M5 — hexa daemon RFC draft (fork-storm internal axis · design-only) → `docs/rfc/rfc_drafts_2026_05_25/rfc_093_hexa_daemon.md`. 권장 = Option A stand-alone daemon (`hexa-daemon` verb · unix socket · opt-in autospawn · fork-mode fallback).

## cross-link

- 진척·측정값 SSOT = `GO.log.md`
- 본 파일 = "왜" 의 SSOT (north-star)
