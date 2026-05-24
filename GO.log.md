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

## 2026-05-25 · M7 · `version_str()` drift guard (precompile silent-regression防止)

- **branch**: `go-m7-version-str-drift-check` (base `origin/main`)
- **risk closed**: M2/M3 cache key = `sha256(source)[0:16] + "_" + version_str()`.
  builder = `tool/build_precompile.hexa::_version_str()`, reader =
  `self/main.hexa::version_str()` — two independent literals. Drift = every
  shipped `release/precompile/hexa_run.<key>` 가 한 키에 저장되고 cmd_run 은
  다른 키로 lookup → precompile HIT 영구 0% (silent regression,
  individual-side internal-consistent).
- **change**: `tests/m_version_str_consistency_test.hexa` 신규 (Option A —
  static `return "<literal>"` extractor + assert).
- **measured (this commit)**:
  - `self/main.hexa            version_str() = "0.1.0-dispatch"`
  - `tool/build_precompile.hexa _version_str() = "0.1.0-dispatch"`
  - 일치 → `PASS: version_str consistent across builder + cmd_run`
  - drift 주입 (`_version_str() → "0.1.0-DRIFT"`) → RC=1 + 명확한 `DRIFT DETECTED` 메시지 + 수정 방법 안내 → 자동 되돌림 후 RC=0 회복
- **extractor**: function-header anchor (`fn version_str(` / `fn _version_str(`) →
  body bounded by next `\nfn ` → 첫 `return "<literal>"` 의 quoted payload 추출.
  순수 정적 string 매칭 (AST 의존 0), 함수 모양이 multi-statement 로 진화하면
  loud-fail (메시지에 extractor 갱신 안내 포함).
- **CI 노트**: M1/M4 패턴 따라 stand-alone smoke. `.github/workflows/` wiring 은
  M-series 전반의 공통 follow-up — 본 PR 의 scope 밖.
- **Option C (.version 파일) 미채택**: static test 가 silent-regression 의 *모든*
  머지를 cycle 전 차단하므로 runtime safety net 의 marginal value 가 낮음
  (test 가 머지를 막으면 .version 도 영원히 drift 안 함). 추후 동적 install/cross-
  host 시나리오에서 필요해지면 별도 milestone 으로 추가.

## 다음 후보 (사용자 결정 대기)

- [ ] M2 후보 — `hexa run` warm-cache hit 경로 측정 (fork 회수 / wall ms)
- [ ] M3 후보 — toolchain auto-discover (clang 부재 시 zig fallback 등)

## 2026-05-25 — M6 · precompile manifest expansion (demo 2 → production 10)

> M2+M3 (PR #889) 가 declarative manifest + precompile pipeline 을 ship 했지만 entry 는 demo 2 개 (`tool/build_hexa_cli.hexa`, `tool/atlas_cli.hexa`) 뿐 → 실제 hot scripts 가 비어있어 production 효과 ≈ 0. M6 가 그 gap 를 메운다.

- [x] M6 — `tool/precompile.json` 확장: 2 → **10 entry** (`scripts[]`).
- [x] M6 — schema 확장 (additive, 무손상): 신규 sibling 키 `descriptions{}` (per-entry 1-line 근거) + `categories{}` (coarse bucket: build/atlas/verify/inbox/install/audit) + `schema_notes` (확장 정책 문서화). 파서 (`_parse_scripts`) 는 `"scripts"` 만 읽으므로 backwards-compatible.
- [x] gate — JSON validity (python json.load) PASS · 10/10 script 디스크 존재 확인 · 3 키 (`scripts` / `descriptions` / `categories`) 완전 mirror · `_parse_scripts` 시뮬레이션 10 entry 정확 추출 · `hexa.real parse tool/build_precompile.hexa` clean.

### 선정 10 entry + 근거

| # | path | category | 근거 |
|---|---|---|---|
| 1 | `tool/build_hexa_cli.hexa`        | build   | M3 demo 유지. core CLI bootstrap. fresh-checkout 마다 발사. |
| 2 | `tool/atlas_cli.hexa`             | atlas   | M3 demo 유지. **14 commits / 3mo (top-2 churn)**. `/atlas` slash + `hexa atlas` 진입. |
| 3 | `tool/verify_cli.hexa`            | verify  | **14 commits / 3mo (top-1 churn tied)**. `/verify` slash + INBOX verify-arm 확장 사이클. |
| 4 | `tool/inbox_sync.hexa`            | inbox   | 2 commits / 3mo. weekly inbox sweep. |
| 5 | `tool/inbox_promote.hexa`         | inbox   | 2 commits / 3mo. inbox_sync 동반 발사. |
| 6 | `tool/cli_wrappers.hexa`          | install | 2 commits / 3mo. drift report 마다 발사. |
| 7 | `tool/audit_forbidden_exts.hexa`  | audit   | 2 commits / 3mo. **`.githooks/pre-commit` + CI 자동 발사**. |
| 8 | `tool/install_firmware_hook.hexa` | install | fresh-checkout 1회 발사 — 'sub-second first-call' UX 골 정확 매칭. |
| 9 | `tool/build_hexa_v2_linux.hexa`   | build   | 2 commits / 3mo. anima CLM dispatch + release-prep 발사. |
| 10| `tool/build_precompile.hexa`      | build   | self — 후속 release CI 가 자기 자신 cache HIT → bootstrap 가속. |

### 제외 후보 + 사유

- `tool/ai_native*.hexa` (3 개) — hexa_interp 의존 (build/hexa_interp 경로) → 빌드 deterministic 하지만 **runtime env 변동성** (HEXA_LANG path) 으로 cache-key sha256 변동 영향 미미하나, 사용빈도 < 월 5회 (사용자 직접 호출보다 CI bench 만).
- `tool/bench_hexa_ir.hexa` — 2 commits / 3mo 이지만 bench 성격 → wall 측정이 본질, precompile 가속이 측정에 noise 도입 위험.
- `tool/atlas_audit_full.hexa` / `tool/atlas_embed_gen.hexa` 등 atlas_* 잔여 — `atlas_cli` 가 wrapper 로 호출하는 패턴 (직접 `hexa run` 빈도 낮음).
- 모든 `tool/*.sh` — non-`.hexa` 라 manifest scope 외.
- `tool/check_grace_consent.hexa` — `.github/workflows/grace_consent.yml` 에서 `build/hexa_v2_linux` 로 직접 transpile (precompile 우회).

### 스키마 확장 결정

- **방향**: additive sister key 만 추가 (`descriptions` / `categories`). 기존 `scripts: [string...]` 그대로 유지 → 파서 (`_parse_scripts`) 무수정.
- **이유**: 객체 형식 (`{path, category, ...}`) 로 바꾸면 파서 정규식 (`"..."` 토큰 추출) 이 `category` 값 까지 script path 로 오인 → 파서 동시 수정 필요 → atomic land 어렵고 backward compat 깨짐.
- **확장 path** (M7+): `--list --verbose` 가 `descriptions` 출력 · `--category=<bucket>` 필터 · CI 가 `scripts` ↔ `descriptions` ↔ `categories` 키 일치 lint.

### gates / smoke

- `python3 -m json.tool tool/precompile.json` — VALID.
- key mirroring (set equality) — PASS.
- 10/10 script `test -f` — PASS.
- `_parse_scripts` simulated extraction — 10 entry 정확.
- `hexa.real parse tool/build_precompile.hexa` — clean.
- **Note**: `hexa run tool/build_precompile.hexa --list` e2e 발사는 현재 self-host codegen 의 `parse_int_str` builtin 미배선 (pre-existing PR #889 잔재 — manifest 변경과 무관) 으로 clang 단계 fail. parse-gate + simulated extraction 으로 대체 검증.

### 다음

- [ ] M7 — release CI 에서 `tool/build_precompile.hexa` 실제 발사 → `release/precompile/` populate → tarball 동봉. (별도 PR; `parse_int_str` builtin 배선 선결 필요.)
- [ ] M8 — `scripts` ↔ `descriptions` ↔ `categories` key consistency lint (CI / pre-commit).
- [ ] M9 — manifest 객체 형식 migration (스키마 v2) — 파서 동시 수정.

## 2026-05-25T11:00Z — M8: `parse_int_str` undefined → `.parse_int()` swap (M6 follow-up unblock)

> M6 (PR #895) 가 manifest 10 entry 확장 시 `tool/build_precompile.hexa --list` e2e 가 `parse_int_str` undefined builtin 으로 막힘. 분석 결과 `parse_int_str` 은 builtin 이 아니라 `self/main.hexa:3575` / `tests/m_cache_gc_test.hexa:34` 의 **local helper** (awk-based 우회). M2/M3 author 가 helper 정의 없이 호출. 코덱젠에는 진짜 builtin `s.parse_int()` (← `str_parse_int` → `hexa_str_parse_int`) 이 이미 존재 — trim/sign/hex 지원, 순수 digit input 에서는 byte-eq 동작.

- [x] M8 — `tool/build_precompile.hexa:256` `parse_int_str(rs)` → `rs.parse_int()` 1-line swap. occam g0 (call-site 교체 = builtin 추가/runtime 재생성 회피).
- [x] gate — `hexa.real parse tool/build_precompile.hexa` clean.
- [x] e2e — `HEXA_LANG=$(pwd) hexa-run tool/build_precompile.hexa --list` PASS (manifest=10 + 10 entry + computed key 출력, exit 0).
- [x] M6 unblock — `--list` e2e 살아남 → PR #895 의 deferred 후속 closure.

## 2026-05-25 · M10 — hexa daemon R1 prototype (RFC 093 Phase 1)

> M5 (PR #888) 가 `rfc_093_hexa_daemon.md` 설계서를 ship — 권장 = Option A stand-alone daemon (unix socket · idle TTL · fork-mode fallback). M10 이 그 RFC § Phase plan **R1** ("socket protocol skeleton + verb dispatch, no compile yet") 을 구현. fork-storm 의 *internal* axis (반복 호출 누적 비용) 의 첫 실코드. M2/M3 (release-time precompile) 와 직교 — M10 = run-time persistent process.

- [x] M10 — `self/main.hexa` daemon verb dispatch + `cmd_daemon_*` 함수군 (+387 line):
  - verb table 에 `} else if sub == "daemon"` 추가 (M8 의 builtin table 변경과 별개 영역 — verb dispatch).
  - 서브버브 6: `start` (fg) · `start-bg` (nohup detach) · `stop` · `status` · `echo` · `help`.
  - `cmd_daemon_start(sock, ttl)` — stale-socket unlink → `net_listen("unix:"+sock)` → `net_set_nonblock` + `net_select([fd],1000)` 1초 폴링 accept loop → 요청당 1 conn (R1) → idle TTL stub (무연결 N초 시 self-exit + socket unlink).
  - `_daemon_handle_line(line)` — R1 verb 디스패처 (순수함수, `[reply, shutdown]` 반환): `PING→PONG` · `ECHO <t>→ECHO <t>` (loopback) · `SHUTDOWN→BYE` (서버 종료) · unknown→`ERR unknown verb: <v>`.
  - `_daemon_send_line` — client 측 connect → write line+\n → net_read → close.
  - socket path default = `/tmp/hexa-daemon-$USER.sock` (getuid builtin 미배선 → $USER fallback; uid-hardening = R3). `--socket` / `--idle-ttl` flag override.
  - `argv0_or_hexa()` — `args()[0]` 실재 바이너리 우선 (worktree/renamed-binary 정확 재spawn) → install-dir/$HEXA_LANG/PATH `hexa` fallback. start-bg 의 self-respawn 용.
- [x] M10 — `self/runtime.c` 소켓 primitive 복원 (+39/-23):
  - **근본 발견**: cycle 61 이 `hxlcl_socket/bind/listen/accept/connect/recv/send/recvmsg/sendmsg/inet_pton/setsockopt` 를 전부 stub (return `rt_net_fail`/`rt_net_zero`) — rationale "aprime_cc 는 컴파일 중 네트워크 안 엶". 그러나 `hexa daemon` (및 모든 net-using hexa 프로그램) 은 같은 driver 바이너리에서 작동하는 소켓 필요. **기존 canonical `test/t34_net_listen_smoke.hexa` 도 이 stub 때문에 -22(-EINVAL) 로 FAIL 중이었음 (latent pre-existing 버그).**
  - cycle-66 close/pipe libc-복원 패턴 mirror — `<sys/socket.h>` + `<arpa/inet.h>` top-include 추가, 11 stub 을 real libc 호출로 교체.
  - **검증**: t34 smoke 가 이제 `listen_fd=3 close_rc=0 OK` PASS (회귀→수정). 일반 프로그램 compile+exec+println 경로 무영향.
- [x] M10 — `tests/m_daemon_r1_test.hexa` 신규 e2e (4-step skeleton): start(bg) → status PASS → echo loopback PASS → stop PASS + post-status FAIL(rc=1). `nc`/`socat` 무의존 (client+server 모두 `hexa daemon` CLI 자체로 구동). socket path = `/tmp/...` + `mono_ns()` suffix (sun_path 104B limit 회피 · $TMPDIR/var-folders 회피).

### 검증 결과 (mac arm64 측정)

- **4-step e2e**: `[1] start PASS · [2] status alive PASS · [3] echo loopback PASS · [4] stop+socket-gone+post-status=1 PASS · ALL 4 STEPS PASS`.
- **수동 lifecycle**: start/start-bg/stop/status/echo 모두 작동. PING/PONG · ECHO loopback · SHUTDOWN-BYE · idle-TTL self-exit (2s TTL → 4s 후 socket-gone rc=1) 확인.
- **회귀**: `test/t34_net_listen_smoke.hexa` -22 FAIL → `OK` PASS. 일반 compile+exec smoke 무영향.
- **gate**: `hexa parse self/main.hexa` + `hexa parse tests/m_daemon_r1_test.hexa` clean. `HEXA_MAC_BUILD_OK=1 hexa build` (main + test) 둘 다 clang green.

### 디자인 결정 (R1)

- **wire = newline-terminated text** (length-prefixed JSON-RPC 아님). R1 은 framing + lifecycle 만; R2 가 JSON-RPC 2.0 + `{compile,run,cache_query,invalidate,status}` method set 으로 업그레이드.
- **요청당 1 conn** (keepalive 없음) — R1 단순화. multi-request 스트림 = R2.
- **file_exists() 사용 금지** — socket inode (`S_ISSOCK`) 에 false 반환. `_daemon_socket_exists` 가 `test -e` shell-probe 로 대체.
- **getpid() banner 생략** — reserved POSIX 이름 (codegen 이 `u_getpid` 로 mangle) · hexa builtin 미배선. bg path 는 shell `$!` 로 PID 캡처 가능.
- **NO compile/cache/atlas logic** — R1 의 핵심. compile 은 R2.

### 다음

- [ ] **R2** — in-memory cache (atlas + lexer + parse + lower + codegen) + `~/.hexa-cache` 미러 + content-hash 키. wire 를 length-prefixed JSON-RPC 로 업그레이드 + 실제 `compile` method. falsifier F-DAEMON-4 (atlas consistency). (RFC 093 § Phase plan R2.)
- [ ] R3 — multi-session test (N=100 latency · crash-respawn · multi-uid reject + getuid 배선). F-DAEMON-2/3.
- [ ] R4 — prod ship (`hexa daemon kill` · `HEXA_DAEMON_AUTOSPAWN` opt-in · fork-fallback wire · 문서). 10/10 falsifier closure.

## 2026-05-25 · M11 — hexa daemon R2 (compile method + in-memory cache, RFC 093 Phase 2)

> M10 (PR #904) 가 R1 (socket + verb + lifecycle) 을 ship — wire 는 newline-text echo 만, 실제 compile 없음. M11 이 RFC § Phase plan **R2** ("in-memory cache + content-hash 키 + `~/.hexa-cache` 미러 + 실제 compile method") 를 구현. fork-storm *internal* axis 의 1차 closure — daemon 이 같은 source 를 **두 번째 호출부터 `hexa build` fork 없이** 즉시 캐시 히트 반환.

- [x] M11 — `self/main.hexa` daemon `compile` 메서드 + in-memory cache:
  - 신규 helper: `_daemon_cache_dir()` (cmd_run 의 `$HOME/.hexa-cache` 미러) · `_daemon_compute_key(file)` (**cmd_run 과 byte-identical** = `sha256_file(file).substring(0,16) + "_" + version_str()`) · `_daemon_key_index(keys, key)` (parallel-array 선형 스캔 — hexa_v2 codegen 의 map-literal 미지원 회피, L3459) · `_daemon_build_binary(file, tmpbin)` (cmd_run 의 `hexa build -o` + inflight rename 로직 추출).
  - accept loop 에 in-memory cache 두 parallel array (`cache_keys` / `cache_bins`) — daemon 수명 동안 유지. `COMPILE <src>` 인라인 처리 (state mutation 필요 → 순수 `_daemon_handle_line` 대신): in-memory HIT (`idx>=0 && file_exists`) → `HIT <bin>` · disk HIT (`file_exists(tmpbin)`, warm `~/.hexa-cache`) → memoize + `HIT <bin>` · MISS → `_daemon_build_binary` 1회 + memoize + `BUILT <bin>` · build fail → `ERR ...`. 중복 push 가드 (`if idx < 0`).
  - 기존 PING/ECHO/SHUTDOWN 은 `_daemon_handle_line` 순수 디스패처 유지 (R1 backward-compat — m_daemon_r1_test 무영향).
  - client: `cmd_daemon_compile(sock, file)` + `} else if sub == "compile"` 디스패치 + help/usage 갱신.
- [x] M11 — `tests/m_daemon_r2_test.hexa` 신규 e2e (3 falsifier): F-DAEMON-R2-1 (같은 source 2회 compile → 1st `BUILT`, 2nd in-memory `HIT` 동일 path · no rebuild) · F-DAEMON-R2-2 (daemon down → `compile` "not running" rc=1 + `hexa run` fork-mode 정상) · F-DAEMON-R2-3 (daemon-built binary ≡ fork-mode `hexa build` byte-identical · `cmp -s`). `nc`/`socat` 무의존.
- [x] M11 — `docs/rfc/rfc_drafts_2026_05_25/rfc_093_hexa_daemon.md` §12 implementation status 표 신규 (R1 ✅ #904 · R2 ✅ this · R3/R4 todo) + R2 honest carve-out.

### 디자인 결정 (R2)

- **cache key byte-identical 제약** — `_daemon_compute_key` 가 cmd_run / cmd_build / _batch_run_one 의 `sha256(source)[0:16] + "_" + version_str()` 와 정확히 일치해야 함. drift 시 daemon-built 와 fork-built 가 다른 슬롯 → M7 `version_str` drift-check + F-DAEMON-R2-3 determinism falsifier 가 잡음.
- **in-memory cache = binary-path 매핑까지만** (RFC §5.1 의 full atlas/lexer/parse/lower 계층 in-process 유지는 R3). R2 가 증명하는 것 = "2번째 호출부터 fork 없이 캐시 히트".
- **wire 는 여전히 newline-text** (binary u32-LE length-prefix 아님). 현 `net_read` 가 strlen 기반 → embedded NUL 미보존 → binary LE prefix 의 high zero-byte 가 truncate. NUL-preserving `net_read_raw` 빌트인 선행 필요 → R3 로 연기. `compile` 버브 자체가 R2 의 framing 업그레이드.
- **autospawn 미배선** — `hexa run` 은 R2 에서도 항상 fork-mode (행동 변화 0건). `HEXA_DAEMON_AUTOSPAWN` probe → daemon compile → exec 배선은 R3.
- **map 회피** — parallel array (`cache_keys`/`cache_bins`). hexa_v2 transpiler 가 map 리터럴 미지원 (L3459) + R1 이 같은 이유로 map 회피. 캐시는 작음 (세션당 distinct source 1 entry).

### 다음 (R3)

- [ ] R3 — (a) `hexa run` autospawn wiring (`HEXA_DAEMON_AUTOSPAWN`/socket 존재 시 daemon `compile` → 받은 binary path exec · daemon down 시 fork fallback) · (b) binary u32-LE length-prefix wire (선행: NUL-preserving `net_read_raw` 빌트인) · (c) AST/lexer/lower in-memory 유지 · (d) atlas SSOT hash flush (F-DAEMON-4) · (e) N=100 latency (F-DAEMON-2) + crash-respawn (F-DAEMON-3) + multi-uid reject.

