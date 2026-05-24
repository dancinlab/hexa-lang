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
- M5 (daemon RFC) 와도 직교 — M2/M3 = release-time pre-emit (사용자 첫 호출 비용 0), M5 = run-time persistent process (반복 호출 누적 비용 0).

## 2026-05-25T23:30:00Z — M5: hexa daemon RFC draft (design-only · code 0)

GO 도메인 M5 마일스톤 — fork-storm 의 *internal* axis 디자인 문서 신규.

외부 축 (pool-route 0.6.5+0.6.6+0.6.7) 은 이미 머지됨 — 동일 mac 호스트에서
다른 host 로 fork 를 옮기는 방식. 그러나 단일 세션의 반복 호출 (IDE/LSP
자동저장 · `hexa loop --dfs` 라운드 안의 N compile) 은 매번 fresh process →
parser/atlas TEXT-parse 재실행 → ~수십 ms 비용 누적. 본 RFC 가 그 internal
axis 의 첫 설계서.

| 산출물 | scope |
|---|---|
| RFC 093 | `docs/rfc/rfc_drafts_2026_05_25/rfc_093_hexa_daemon.md` (~416 lines · 11 절 · ASCII diagram 3 + 비교표 1 + falsifier 표 1 + phase 표 1) |
| GO.log.md | 본 도메인 로그 신규 (sister `GO.md` 는 후속) |

### 핵심 결정

- **권장 = Option A (gradle-style stand-alone daemon)** — Option B (LSP 확장)
  는 CLI 의존성으로 부자연스럽고, Option C (.dylib) 는 fork-storm 자체를
  해결 못 함 (process-local, cross-call state 없음).
- Option A 의 단점 (새 verb · socket lifecycle) 은 검증된 패턴 (gradle, bazel
  10년+).
- `HEXA_DAEMON_AUTOSPAWN=1` opt-in · 미설치/crash 시 fork-mode 자동 fallback
  (graceful degrade · F-DAEMON-1, F-DAEMON-3).
- atlas SSOT 일관성은 60s mtime+hash re-stat → 변동 시 전체 flush (`@D
  atlas_fold` 우회 0건).
- 5 falsifier (fallback · speedup · crash · atlas consistency · privilege).
- 4-라운드 phase plan (R1 socket → R2 cache → R3 multi-session test →
  R4 prod ship).

### 본 RFC 가 *안* 푸는 것 (honest carve-out)

- 외부 host fan-out (pool-route 영역)
- 외부 LLM 호스팅 (`@D external_llm` 위배)
- atlas direct fold (`@D atlas_fold` 우회)
- Windows / 비-unix host (§8 Q3 별도 RFC)
- 본 RFC 머지 = 코드 변경 0건; R1–R4 후속 PR 에서 wiring

- [x] `docs/rfc/rfc_drafts_2026_05_25/rfc_093_hexa_daemon.md` 신규 (next RFC
      number — 092 까지 사용중이라 093 채택)
- [x] GO.log.md M5 entry append (M1 entry 와 병합 유지)
- [x] PR 생성 + 자동 squash merge (pr-cycle 훅)
- [ ] M6+ — daemon implementation R1–R4 (별도 RFC 머지 후 별도 PR 체인)

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

## 2026-05-25 · M4 · `hexa cache <subverb>` 1st-class verb

- **branch**: `go-m4-hexa-cache-verb` (base `origin/main`)
- **change**: `self/main.hexa` — new `cmd_cache(args)` + dispatcher branch for `sub == "cache"` + `cmd_help()` entry.
- **subverbs**:
  - `cache stat` — entries · total size · oldest · biggest
  - `cache list [--sort=mtime|size] [--limit=N]` — per-entry name/size/mtime
  - `cache verify` — `file_exists` + `size > 0` over every entry (rc=1 if any zero-size)
  - `cache clean [--prune] [--older-than=N(days)] [--cap-mb=M]` — dry-run unless `--prune`
- **test**: `tests/integration/14_cache_verb/test.hexa` (isolated `$HOME` via `mktemp -d`, seeds 2 entries incl. zero-size bait, walks all 4 subverbs)
- **self-contained**: does NOT depend on M1's `_hexa_cache_gc` helper — uses `find` / `ls` / `stat` / `du` / `xargs` shell pipelines directly, so the M1 and M4 worktrees can land in either order without conflict.
- **parity**: closes the `go clean -cache(-n)` gap — pre-M4 users had to `ls ~/.hexa-cache/ | wc -l` + `du -sh` + `rm` by hand.

## 2026-05-25 · M4 (release tarball) · `.github/workflows/release.yml` 통합

> M2+M3 (PR #889) 가 `tool/build_precompile.hexa` + `tool/precompile.json` 으로 cold-cache 회피 메커니즘을 ship 했으나 release pipeline 에 미통합 — 새 사용자 `hx install hexa-lang` 시 tarball 에 `release/precompile/` 비어있음 → 첫 호출 여전히 clang fork. M4 가 그 갭 closure.

- **branch**: `go-m4-release-tarball-ci` (base `origin/main`)
- **change**: `.github/workflows/release.yml` — 3 release job (darwin-arm64, linux-x86_64, linux-arm64) 각각에 `Stage 3 — precompile shipped scripts` step 추가 + 각 `Package` step 에 `mkdir release/precompile` · `cp -R release/precompile/.` · tarball entry count assert 추가. +70/-3 line.
- **Stage 3** — `HEXA_LANG=$PWD` + `HEXA_MODULE_LOADER=$PWD/build/hexa_module_loader` (silent-stub link-fail trap 회피, ref [[reference_hexa_module_loader_env_2026_05_20]]) + `PATH=$PWD:$PATH` 으로 `./hexa run tool/build_precompile.hexa` 발사. manifest 2 entry → `release/precompile/hexa_run.<key>` 2 binary. 1+ entry 미충족 시 step fail.
- **Package smoke** — `tar -tzf <tarball> | grep -cE "hexa-<target>/release/precompile/[^/]+$"` 으로 tarball 내부 entry 수 assert (≥1).
- **Archive layout 헤더 코멘트** 갱신 — install.sh consumer 가 보는 새 directory 명시.
- **gate** — workflow yaml change 만; `hexa parse` 대상 없음 (Stage 3 가 호출하는 `tool/build_precompile.hexa` 는 PR #889 에서 이미 parse-gate 통과).
- **PR**: pr-cycle 훅이 `--auto --squash --delete-branch` 자동 큐, CI green 후 merge.

### key 디자인 결정

- **Stage 3 위치** — Stage 2 (`./hexa` 빌드) 직후 + Package 직전. CLI 가 존재해야 `hexa run` 호출 가능; tarball 만들기 전이어야 stage dir 에 복사 가능.
- **3 job 모두에 동일 step 중복** — workflow yaml 은 reusable workflow 분리할 만큼 복잡하지 않음. release.yml 자체가 이미 bootstrap.yml 의 verbatim copy (INDEPENDENCE clause). 3-way 중복도 같은 트레이드오프.
- **strict fail** — precompile bug 시 release pipeline 전체 fail (warn+continue 아님). cold-cache 회피가 M4 의 entire purpose 라 silent skip = M4 deliverable 위배.
- **manifest 확장** — 본 PR 은 wiring 만; 실제 hot script 전수는 M6 (별 PR). 현재 2 entry (build_hexa_cli + atlas_cli) 로 smoke 충분.

## 다음 후보 (사용자 결정 대기)

- [ ] M2 후보 — `hexa run` warm-cache hit 경로 측정 (fork 회수 / wall ms)
- [ ] M3 후보 — toolchain auto-discover (clang 부재 시 zig fallback 등)
