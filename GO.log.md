# GO.log — 작업 체크박스 (append-only)

> 새 작업은 `- [ ] <text>` · 완료는 `- [x] <text>` · 시작 마커는 `## <header>`.

## 2026-05-25T07:30Z — M2 + M3 결합 (declarative manifest + precompile pipeline + cmd_run lookup)

> Go 의 `go install <pkg>` 패턴 mirror — release 시점 precompile + bin/ 동봉 → 사용자 fresh-machine 첫 호출이 즉시 cache HIT (clang fork skip). cold-cache fork-storm 의 *내부* axis (외부 axis = pool-route 0.6.5/0.6.6).

- [x] M3 — `tool/precompile.json` declarative manifest 신규. `version: 1` · `scripts: [tool/build_hexa_cli.hexa, tool/atlas_cli.hexa]` (demo 2 entry).
- [x] M2 — `tool/build_precompile.hexa` 신규 (~260 line): manifest 파싱 (`"scripts"` 키 → quoted-token extract) · `sha256_file(script).substring(0,16) + "_" + version_str()` cache key 계산 · `hexa build <script> -o release/precompile/hexa_run.<key>` 발사 · staging+atomic rename · `--list` (계산만) / `--verify` (HIT/MISS 점검) 진단 모드 · 모든 entry built → exit 0.
- [x] M2 — `self/main.hexa` 패치 (+47 line, M1 의 `_hexa_cache_gc` 와 직교):
  - 신규 helper `_precompile_lookup(key)` — 2 anchor (`$HEXA_LANG/release/precompile/` → `install_dir/release/precompile/`) probe, 첫 hit 반환 / miss 시 ""
  - 3 site wire (`cmd_run_user_direct` · `cmd_run` · `_batch_run_one`): cache 키 계산 직후 probe. HIT 시 `tmpbin = _pre` 로 swap → 이후 build 단계 (`if !file_exists(tmpbin)`) fully skip · exec 만.
  - `HEXA_PRECOMPILE_TRACE=1` 시 stderr `[precompile] HIT <path>` (production 잡음 0).
- [x] M2 — `.gitignore` 에 `release/precompile/` 추가 (release-time generated artifact).
- [x] M2 — `tests/m_precompile_hit_test.hexa` e2e: 임시 fake `$HEXA_LANG` layout + sentinel-exit-42 shell script as fake "binary" → `HEXA_LANG=<tmp> HEXA_PRECOMPILE_TRACE=1 hexa run <probe>` 실행 시 rc=42 + `[precompile] HIT` trace + sentinel stdout 3-way assert.
- [x] gate — `hexa parse` 3 파일 clean (`tool/build_precompile.hexa` · `tests/m_precompile_hit_test.hexa` · `self/main.hexa`).
- [ ] M4-M6 follow-up — release tarball CI 통합 · manifest 확장 · version drift 자동 guard.

### key 디자인 결정

- cache key 포맷 = `sha256(source).substring(0,16) + "_" + version_str()` — `self/main.hexa::cmd_run` 의 기존 cache key 포맷과 byte-identical. drift 시 silent miss → M6 자동 검사 필수 (현재는 양쪽 hard-coded `"0.1.0-dispatch"` sync).
- precompile probe 순서 = `$HEXA_LANG/release/precompile/` → `install_dir/release/precompile/` → `~/.hexa-cache/` (기존 path) → build fork. dev (HEXA_LANG 설정) + release tarball install 모두 cover.
- minimum demo scope — 실제 build 발사는 Mac local fork-storm 우려로 안 함. `hexa parse` syntactic gate 만, CI 가 e2e 발사 (`tests/m_precompile_hit_test.hexa`).
- M1 의 `_hexa_cache_gc` 와 완전 직교 — GC 는 `~/.hexa-cache/` 정리, precompile 은 `release/precompile/` lookup. 같은 cmd_run 사이트들이지만 wire 위치 다름 (GC = 함수 진입 직후, precompile = key 계산 후 build 직전).

## 2026-05-25 — domain scaffold + M1 구현

- [x] GO.md / GO.log.md scaffold (north-star = Go-수준 무신경 CLI 사용감)
- [~] M1 — `~/.hexa-cache/` 자동 GC 구현 (사용자 검토 후 flip 대기)
  - 변경 위치: `self/main.hexa`
    - 신규 helper `_hexa_cache_gc(cache_dir, cap_mb, ttl_days)` + 정책 resolver `_hexa_cache_cap_mb()` / `_hexa_cache_ttl_days()` (line 2879 위쪽 신규)
    - lazy probe wire: `cmd_run_user_direct` · `cmd_run` · `_batch_run_one` · `cmd_build` (runtime.o cache miss path) 총 4 site
  - 정책: cap 2 GiB (env `HEXA_CACHE_CAP_MB`) · TTL 30 일 (env `HEXA_CACHE_TTL_DAYS`) · 60s sentinel throttle (`.gc_last`) · `*.tmp.<ns>` orphan 60min sweep
  - 메커니즘: POSIX shell (`find -mmin/-mtime`, `du -sk`, `ls -1tr`, `rm -f`) only — 외부 binary 추가 0
  - 테스트: `tests/m_cache_gc_test.hexa` — 3 시나리오 (A tmp orphan / B TTL / C LRU cap) 전부 PASS
    - `hexa parse` clean (helper + test 양쪽)
    - `hexa run tests/m_cache_gc_test.hexa` → `ALL 3 SCENARIOS PASS`
  - 측정: 현재 `~/.hexa-cache` = 32M / 69 files (cap 미초과; 후속 사이클에서 자연 누적 시 자동 prune 발동)

## 다음 후보 (사용자 결정 대기)

- [ ] M2 후보 — `hexa run` warm-cache hit 경로 측정 (fork 회수 / wall ms)
- [ ] M3 후보 — toolchain auto-discover (clang 부재 시 zig fallback 등)
