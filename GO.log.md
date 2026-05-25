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

## 2026-05-25 · M9 — precompile HIT perf 실측 (M2 deferred measurement closure)

> M2 (PR #889) 가 release-time precompile → cmd_run 의 `_precompile_lookup(key)` HIT 으로
> cold-cache clang fork 를 회피하는 메커니즘을 ship 했으나, 실제 perf 이득은 측정을 deferred
> 했다. M9 가 그 측정을 closure — 같은 .hexa script 의 cold-cache vs precompile-HIT 실행
> wall time 을 N=5 로 직접 측정.

- [x] M9 — `tools/perf/m9_precompile_bench.hexa` 신규 (~320 line): target script 의
  cache key (`sha256(source)[0:16] + "_" + version_str()`) 계산 → **COLD** phase
  (매 샘플마다 `~/.hexa-cache` keyed entry + `release/precompile/` entry 제거 후
  `hexa run` timing) → **HIT** phase (precompile entry 1회 staging = release-time step,
  이후 N 샘플 동안 유지; `~/.hexa-cache` warm entry 는 매번 제거하여 *유일한* fast-path 가
  precompile HIT 가 되도록) → avg/p50/min/max + speedup 보고. `mono_ns()` wall delta.
  HIT phase 는 매 샘플 stderr 에 `[precompile] HIT` trace 가 실재함을 assert (probe 가
  실제로 fired 임을 증명; trace 없으면 loud-fail).
- [x] gate — `hexa parse tools/perf/m9_precompile_bench.hexa` clean (local + fresh driver 양쪽).

### 측정 결과 (mac arm64 · pool mini · fresh-built driver @ origin/main 4b32a9b · N=5)

| target | `tool/atlas_cli.hexa` (2161 line · 91 kB source · `--help` op) |
|---|---|
| cache_key | `f7a8a46fdcd1a812_0.1.0-dispatch` |
| host | Darwin arm64 (pool mini) |

| phase | avg (ms) | p50 (ms) | min (ms) | max (ms) |
|---|---|---|---|---|
| **COLD** (full clang fork) | 2986.8 | 2952.1 | 2926.8 | 3106.6 |
| **HIT** (precompile, fork skip) | 106.4 | 33.0 | 27.2 | 398.1 |

- **speedup (avg) = 28.05× · wall saved = 2880.4 ms/call**.
- HIT 의 max(398.1ms) = hit[0] 의 cold-FS first-touch 비용 (이후 hit[1..4] = 42/33/32/27 ms).
  steady-state 는 p50(33ms) 가 대표 → **p50 speedup ≈ 89×** (2952/33). 첫 호출조차
  398ms → 7.5× 빠름.
- 결론: M2 precompile 은 91 kB-class hot script 의 사용자 첫 호출 비용을 **~3.0s → ~0.03-0.4s**
  로 압축. cold-cache fork-storm 의 internal axis 가 실측으로 입증됨 (g3 over-claim 0).

### 측정 protocol / 환경 결정

- **mac local 발사 = sign-gate refuse** ("local-bound heavy invocation … needs a fresh sign-off")
  — 의도된 fork-storm 차단. → **pool mini (mac arm64) 라우팅**.
- **stale-binary 함정**: pool 호스트들의 설치된 `hexa` 바이너리는 origin/main 보다 훨씬 stale
  (mini=PR#492, M2 precompile 로직 미포함 — `grep -c "release/precompile" = 0`). 따라서
  mini 에 origin/main fresh-clone (`/tmp/m9-bench`) → `LOCAL_BUILD=1 hexa run
  tool/build_hexa_cli.hexa` 로 **fresh driver 빌드** (5/5 smoke PASS · precompile 로직
  포함 확인) → 그 driver 로 측정. ubu (x86_64) 는 [[reference_linux_transpiler_stale_build_recipe]]
  로 self-host stale → 미사용.
- **HIT trace 검증**: cmd_run 의 `HEXA_PRECOMPILE_TRACE=1` → stderr `[precompile] HIT <path>`.
  bench 가 stderr 를 `2>&1` 로 merge 캡처해 매 HIT 샘플마다 trace 실재 assert (초기 버전은
  `/tmp/m9_stderr.$$` temp-file 을 별도 exec 에서 read → `$$` mismatch 로 trace miss
  false-fail; merge-capture 로 수정).

### 부수 작업

- [x] **GO.md M1 flip** — `- [ ] M1` → `- [x] M1` (PR #887 이미 머지 · snapshot drift 해소).

### 다음 (M9 후속 후보)

- [ ] CI 에서 m9 bench 회귀 게이트 (speedup < 5× 시 fail) — release.yml Stage 3 동봉 precompile
  의 effectiveness 자동 감시.
- [ ] multi-target sweep (manifest 10 entry 전수 cold vs HIT) — per-script speedup 분포.

## 2026-05-25 · M11 — hexa daemon R2 (compile method + in-memory cache, RFC 093 Phase 2)

> M10 (PR #904) 가 R1 (socket + verb + lifecycle) 을 ship — wire 는 newline-text echo 만, 실제 compile 없음. M11 이 RFC § Phase plan **R2** ("in-memory cache + content-hash 키 + `~/.hexa-cache` 미러 + 실제 compile method") 를 구현. fork-storm *internal* axis 의 1차 closure — daemon 이 같은 source 를 **두 번째 호출부터 `hexa build` fork 없이** 즉시 캐시 히트 반환.

- [x] M11 — `self/main.hexa` daemon `compile` 메서드 + in-memory cache:
  - 신규 helper: `_daemon_cache_dir()` (cmd_run 의 `$HOME/.hexa-cache` 미러) · `_daemon_compute_key(file)` (**cmd_run 과 byte-identical** = `sha256_file(file).substring(0,16) + "_" + version_str()`) · `_daemon_key_index(keys, key)` (parallel-array 선형 스캔 — hexa_v2 codegen 의 map-literal 미지원 회피, L3459) · `_daemon_build_binary(file, tmpbin)` (cmd_run 의 `hexa build -o` + inflight rename 로직 추출).
  - accept loop 에 in-memory cache 두 parallel array (`cache_keys` / `cache_bins`) — daemon 수명 동안 유지. `COMPILE <src>` 인라인 처리 (state mutation 필요 → 순수 `_daemon_handle_line` 대신): in-memory HIT (`idx>=0 && file_exists`) → `HIT <bin>` · disk HIT (`file_exists(tmpbin)`, warm `~/.hexa-cache`) → memoize + `HIT <bin>` · MISS → `_daemon_build_binary` 1회 + memoize + `BUILT <bin>` · build fail → `ERR ...`. 중복 push 가드 (`if idx < 0`).
  - 기존 PING/ECHO/SHUTDOWN 은 `_daemon_handle_line` 순수 디스패처 유지 (R1 backward-compat — m_daemon_r1_test 무영향).
  - client: `cmd_daemon_compile(sock, file)` + `} else if sub == "compile"` 디스패치 + help/usage 갱신.
- [x] M11 — `tests/m_daemon_r2_test.hexa` 신규 e2e (3 falsifier): F-DAEMON-R2-1 (같은 source 2회 compile → 1st `BUILT`, 2nd in-memory `HIT` 동일 path · no rebuild) · F-DAEMON-R2-2 (daemon down → `compile` "not running" rc=1 + `hexa run` fork-mode 정상) · F-DAEMON-R2-3 (daemon-built binary ≡ fork-mode `hexa build` byte-identical · `cmp -s`). `nc`/`socat` 무의존.
- [x] M11 — `docs/rfc/rfc_drafts_2026_05_25/rfc_093_hexa_daemon.md` §12 implementation status 표 신규 (R1 ✅ #904 · R2 ✅ this · R3/R4 todo) + R2 honest carve-out.

### 검증 결과 (mini arm64 Mac 측정 · fresh /tmp clone)

- **3 falsifier 전부 PASS**: `[F-DAEMON-R2-2a] not-running rc=1 PASS · [F-DAEMON-R2-2b] fork-mode run PASS · [F-DAEMON-R2-1a] 1st BUILT PASS · [F-DAEMON-R2-1b] 2nd in-memory HIT same path PASS · [F-DAEMON-R2-3] daemon HIT byte-identical fork-mode slot PASS · ALL 3 FALSIFIERS PASS`.
- **R1 회귀 무**: `tests/m_daemon_r1_test.hexa` 여전히 4/4 PASS (COMPILE 인라인 추가 + cache array 도입에도 PING/ECHO/SHUTDOWN backward-compat).
- **gate**: `hexa parse self/main.hexa` + `hexa parse tests/m_daemon_r2_test.hexa` clean. `HEXA_MAC_BUILD_OK=1 hexa build self/main.hexa` clang green.
- **determinism 발견**: F-DAEMON-R2-3 의 초안 (daemon-built ≡ fresh fork-build byte-eq) 은 **falsified** — `hexa build` 가 호출마다 LC_UUID/출력경로 임베드로 같은 source 두 독립 build 가 이미 byte-diff (첫 divergence ~char 1449). 진짜 보증 = content-addressed slot identity (양쪽 같은 `~/.hexa-cache/hexa_run.<key>` → 먼저 빌드한 쪽 win → 나머지 byte-identical HIT). falsifier 재작성 후 측정 PASS (daemon HIT sha ≡ fork-mode slot sha).

### 디자인 결정 (R2)

- **cache key byte-identical 제약** — `_daemon_compute_key` 가 cmd_run / cmd_build / _batch_run_one 의 `sha256(source)[0:16] + "_" + version_str()` 와 정확히 일치해야 함. drift 시 daemon-built 와 fork-built 가 다른 슬롯 → M7 `version_str` drift-check + F-DAEMON-R2-3 determinism falsifier 가 잡음.
- **in-memory cache = binary-path 매핑까지만** (RFC §5.1 의 full atlas/lexer/parse/lower 계층 in-process 유지는 R3). R2 가 증명하는 것 = "2번째 호출부터 fork 없이 캐시 히트".
- **wire 는 여전히 newline-text** (binary u32-LE length-prefix 아님). 현 `net_read` 가 strlen 기반 → embedded NUL 미보존 → binary LE prefix 의 high zero-byte 가 truncate. NUL-preserving `net_read_raw` 빌트인 선행 필요 → R3 로 연기. `compile` 버브 자체가 R2 의 framing 업그레이드.
- **autospawn 미배선** — `hexa run` 은 R2 에서도 항상 fork-mode (행동 변화 0건). `HEXA_DAEMON_AUTOSPAWN` probe → daemon compile → exec 배선은 R3.
- **map 회피** — parallel array (`cache_keys`/`cache_bins`). hexa_v2 transpiler 가 map 리터럴 미지원 (L3459) + R1 이 같은 이유로 map 회피. 캐시는 작음 (세션당 distinct source 1 entry).

### 다음 (R3)

- [ ] R3 — (a) `hexa run` autospawn wiring (`HEXA_DAEMON_AUTOSPAWN`/socket 존재 시 daemon `compile` → 받은 binary path exec · daemon down 시 fork fallback) · (b) binary u32-LE length-prefix wire (선행: NUL-preserving `net_read_raw` 빌트인) · (c) AST/lexer/lower in-memory 유지 · (d) atlas SSOT hash flush (F-DAEMON-4) · (e) N=100 latency (F-DAEMON-2) + crash-respawn (F-DAEMON-3) + multi-uid reject.

## 2026-05-25 · M12 — hexa daemon R3 (autospawn wiring + N=100 latency + crash-respawn, RFC 093 Phase 3)

> M11 (PR #922) 가 R2 (`compile` 메서드 + in-mem cache) 를 ship — 하지만 `hexa run` 은 daemon 을 *자동으로* 안 씀 (수동 `hexa daemon compile` 만). M12 가 RFC § Phase plan **R3** 의 핵심 carve-out 3개를 닫음: (1) autospawn wiring · (2) net_read_raw 필요성 판단 (→ occam g0 skip) · (3) N=100 latency / crash-respawn 측정.

- [x] M12 — `self/main.hexa` autospawn wiring:
  - 신규 helper `_daemon_autospawn_path(file)` — `HEXA_DAEMON_AUTOSPAWN != "1"` 이면 즉시 `""` (opt-in · default 0 → 행동 변화 0건). socket probe (`_daemon_default_socket` → `HEXA_DAEMON_SOCKET` override 우선) → 없으면 detached `daemon start --idle-ttl <HEXA_DAEMON_IDLE_TTL|600>` spawn + 3s socket-appear 대기 → `_daemon_send_line(sock, "COMPILE " + file)` → 응답 파싱 (`HIT`/`BUILT <path>` → file_exists 시 path 반환 · ERR/no-reply/missing-bin → `""`). 모든 실패 = silent fork fallback (graceful degrade · NEVER abort). `HEXA_DAEMON_TRACE=1` 시 `[daemon]` stderr 트레이스.
  - `cmd_run_user_direct` 에 daemon tier 삽입 — precompile probe (M2) 와 fork-mode build 사이: `if !file_exists(tmpbin) { let _dbin = _daemon_autospawn_path(file); if len(_dbin) > 0 { tmpbin = _dbin } }`. 3-tier fallback **precompile → daemon → fork-mode** 정립. (`cmd_run` = 내부 absorbed-verb 디스패치 전용이라 autospawn 미배선 — RFC §4.3 autospawn 은 user-direct `hexa run` 전용.)
  - `_daemon_default_socket` 에 `HEXA_DAEMON_SOCKET` env override (socket isolation — 테스트가 격리 socket 타깃).
- [x] M12 — `tests/m_daemon_r3_test.hexa` 신규 e2e (3 falsifier): F-DAEMON-R3-1 (autospawn — `HEXA_DAEMON_AUTOSPAWN=1 hexa run <x>` → daemon 자동 기동 + socket 생성 + compile + exec + trace) · F-DAEMON-R3-2 (latency — warm-daemon loop vs fork-mode loop) · F-DAEMON-R3-3 (crash-respawn — daemon stop+pkill+rm socket → 다음 autospawn run 정상 rc=0). BLOCKED row 는 명시 마커 (g3 — 날조 금지).
- [x] M12 — RFC 093 §12 표 R3 ✅ landed + R3 honest carve-out 갱신 · GO.md M12 milestone.

### 검증 결과 (mini-class arm64 Mac · fresh worktree build · `/tmp/hexac` = `hexa.real` 복사)

- **R3 3 falsifier 전부 PASS** (`/tmp/m12_r3_test_bin`, HEXA_BIN=hexa-named 드라이버 복사):
  - `[F-DAEMON-R3-1a] autospawn run exec OK PASS · [F-DAEMON-R3-1b] socket auto-created PASS · [F-DAEMON-R3-1c] daemon tier fired (trace) PASS`
  - `[F-DAEMON-R3-2] warm-daemon faster PASS` (in-test N=20: warm 6462 ms vs fork 46281 ms = 7.16×)
  - `[F-DAEMON-R3-3] post-crash run succeeded (rc=0, graceful) PASS`
- **N=100 latency 측정** (별도 shell loop, 동일 드라이버):
  | mode | N=100 total | per-call | 비고 |
  |---|---|---|---|
  | warm-daemon (autospawn HIT) | **9,395 ms** | 94 ms | socket round-trip + warm in-mem HIT · fork 0 |
  | fork-mode (cold rebuild, 고유 src) | **174,933 ms** | 1,749 ms | 매 호출 `hexa build` fork |
  | **speedup** | **18.6×** | — | 165,538 ms saved · F-DAEMON-2 gate (≤1.5×) far exceeded |
- **R1/R2 회귀 무**: `m_daemon_r1_test` 4/4 PASS · `m_daemon_r2_test` 3/3 PASS (autospawn helper + socket override 추가에도 기존 verb backward-compat).
- **gate**: `hexac parse self/main.hexa` (복사본) + `hexac parse tests/m_daemon_r3_test.hexa` clean. `HEXA_MAC_BUILD_OK=1 hexac build self/main.hexa` clang green (warning만).

### 디자인 결정 (R3)

- **net_read_raw SKIP (occam g0)** — task 의 scope escape + RFC carve-out 판단대로, R3 핵심(autospawn + latency)은 binary u32-LE wire 불필요. COMPILE 응답이 `<TAG> <path>` 한 줄이고 binary path 는 NUL 미포함 → strlen-기반 `net_read` 로 온전히 round-trip. 따라서 `net_read_raw` 빌트인 + codegen 변경은 R4 로 연기 ([[codegen 변경 검증+랜딩 레시피]] 회피 = 라운드 1 serial 비용 절약).
- **autospawn = `cmd_run_user_direct` 만** — `cmd_run` (lsp/test/check/qrng/batch 등 내부 absorbed-verb 디스패치) 은 신뢰된 내부 스크립트를 같은 프로세스 안에서 반복 실행 → daemon 자동 spawn 부적절. RFC §4.3 autospawn 은 user-direct `hexa run` 전용.
- **argv0-basename dispatch 함정** — 드라이버가 argv[0] basename != `hexa*` 면 shim 으로 취급 (`unknown shim command`). 테스트는 `hexa`-named 드라이버 복사본을 HEXA_BIN 으로 줘야 함 (코드 버그 아닌 호출 규약). [[reference_hexa_basename_sigkill_workaround_2026_05_19]] 친척.

### 다음 (R4)

- [ ] R4 — (a) binary u32-LE length-prefix wire (선행 `net_read_raw` 빌트인 + codegen) · (b) AST/lexer/lower in-memory 유지 (현 R2/R3 는 binary-path 매핑까지만) · [x] (c) atlas SSOT hash flush (F-DAEMON-4) · (d) multi-uid reject + root refuse (F-DAEMON-5 · `getuid()` builtin 선행) · (e) prod ship — verb 안정화 · 문서 · `hexa init` 안내 · 10/10 falsifier closure.

## 2026-05-25 · M14 — hexa daemon R4(c) atlas SSOT hash flush (RFC 093 Phase 4 · F-DAEMON-4)

> R2/R3 (PR #922/#931) 의 in-memory cache 키는 `sha256(source)[0:16] + "_" + version_str()` — **atlas SSOT hash 를 안 봄**. atlas SSOT (`compiler/atlas/embedded.gen.hexa`) 에 노드가 fold 되면 atlas-cite 코드가 *다른* binary 로 컴파일될 수 있는데 daemon 은 직전 memoized binary 를 HIT 으로 반환 → stale 결과. R2 agent 가 "atlas SSOT hash flush" 를 R4 carve-out 으로 명시. M14 가 이걸 닫음.

- [x] M14 — `self/main.hexa` daemon atlas-flush logic (**Option B — daemon-only invalidation layer**):
  - 신규 helper `_daemon_atlas_ssot_path()` — atlas SSOT (`compiler/atlas/embedded.gen.hexa`) 를 `$HEXA_LANG > install_dir_from_argv0() > ./` precedence 로 해석 (toolchain 나머지와 동일). miss 시 `""`.
  - 신규 helper `_daemon_atlas_hash()` — SSOT content hash (`sha256_file`) 의 short-form (앞 16 hex). SSOT 부재 시 `""` (= unknown).
  - serve-loop 에 throttled flush 삽입 — COMPILE 처리 직전, 2 s throttle 윈도우당 1회 `_daemon_atlas_hash()` 호출 → 직전 `last_atlas_hash` 와 다르면 (둘 다 non-empty) `cache_keys`/`cache_bins` 전체 flush + cache_bins 의 모든 `~/.hexa-cache` disk-mirror 바이너리 `rm -f` (키 불변이라 disk HIT 도 stale → unlink 필수) → 다음 COMPILE 이 새 atlas 로 re-build. `""` current-hash = never flush (transient miss thrash 방지). 첫 관측값 = baseline 기록.
  - `daemon help` 텍스트 R2 → R2/R4 + F-DAEMON-4 설명 갱신.
- [x] M14 — throttle 는 `HEXA_DAEMON_ATLAS_THROTTLE_MS` env override (default 2000ms · 0 = 매 COMPILE 체크). 테스트가 0 으로 띄워 flush 를 wall-clock sleep 무관하게 deterministic 하게 만듦.
- [x] M14 — `tests/m_daemon_r4_atlas_flush_test.hexa` 신규 e2e (3 falsifier). 임시 `$HEXA_LANG` 에 작은 fake `compiler/atlas/embedded.gen.hexa` 를 두고 fake 파일을 rewrite 해 fold 시뮬 (10 MB 실 SSOT 안 건드림 · daemon 의 fork build 는 install_dir hexa 사용 → 실 compile 정상). 데몬은 `HEXA_DAEMON_ATLAS_THROTTLE_MS=0` 으로 spawn → 매 COMPILE atlas hash 체크. F-DAEMON-4-1 (atlas 불변 → 2nd compile HIT, 무spurious-flush) · F-DAEMON-4-2 (fake SSOT content 변경 → 다음 compile flush → re-BUILT, NOT stale HIT) · F-DAEMON-4-3 (안정화 후 → HIT 복귀 = flush 는 change-edge one-shot).
- [x] M14 — RFC 093 §12 표 R4(c) ✅ landed + R4(c) honest carve-out (Option A/B/C 비교 · flush 신호 = SSOT 파일 hash · disk unlink · throttle · "" never-flush) · GO.md M14 milestone.

### 디자인 결정 (R4(c))

- **Option B 선택** — Option A (cache key 에 `…_<atlas[0:8]>` 추가) 는 daemon 키를 `cmd_run`/`hexa build`/precompile 키와 divergence → M7 drift-guard 위반 + M2 precompile lookup 깨짐 (scope 큼, `cmd_run` 동시 수정 필요). Option B 는 키 불변 유지 + daemon-local invalidation → drift-guard/precompile 무영향 (occam g0). Option C (mtime) 는 `touch` false-positive → content hash 채택.
- **disk-mirror 도 unlink** — 키가 atlas fold 로 안 바뀌므로 in-mem flush 만으로는 다음 COMPILE 이 `~/.hexa-cache/hexa_run.<key>` disk HIT 으로 여전히 stale. flush 시 cache_bins disk 바이너리 전부 `rm -f`.
- **2 s throttle (`HEXA_DAEMON_ATLAS_THROTTLE_MS` override)** — hot-path 에서 매 COMPILE 마다 `sha256_file` (최대 10 MB) 읽기 회피. fold 감지 지연 ≤ 2 s ≪ RFC §7 F-DAEMON-4 gate "60 s 내 flush". 0 = 매 COMPILE 체크 (테스트용).
- **테스트 함정 (별개 runtime 버그 2개)** — (1) compiled `sleep_ms` 가 ~0ms no-op (mono_ns delta 측정 = 1000ns) → throttle 윈도우를 sleep 으로 못 넘김 → throttle env=0 으로 우회. (2) build-host (mini) 에서 `hexa*`-prefix argv0 SIGKILL (rc=137) — `hexac` 는 통과, `hexa-vertest` 는 kill ([[reference_hexa_basename_sigkill_workaround_2026_05_19]] 변종, 매처가 더 광범위). 둘 다 daemon 로직과 무관 — 테스트 하네스 이슈. 검증: `hexac` 드라이버 + throttle=0 으로 ALL 3 PASS.

### 검증 결과 (mini arm64 Mac · fresh worktree build)

- **R4 3 falsifier 전부 PASS** (`HEXA_BIN=/tmp/hexac` 드라이버 · `HEXA_DAEMON_ATLAS_THROTTLE_MS=0`):
  - `[F-DAEMON-4-1a] BUILT · [F-DAEMON-4-1b] atlas 불변 → HIT (무spurious-flush) PASS`
  - `[F-DAEMON-4-2] atlas fold → cache flushed → re-BUILT (no stale HIT) PASS` ← F-DAEMON-4 핵심
  - `[F-DAEMON-4-3] 안정화 후 HIT 복귀 (flush = one-shot edge) PASS`
- **daemon log 증거**: `hexa daemon: atlas SSOT changed (bb8058b8... -> 19538e40...) — flushing in-memory cache (1 entries)` (수동 repro 로그).
- **회귀 (rebased onto origin/main = M13 codegen 머지 후)**: r4_atlas_flush 3/3 · r4_codegen (M13) 3/3 · r2 3/3 · r1 4/4 PASS. **r3 R3-1b/1c 는 PRE-EXISTING FAIL** — origin/main (M14 미포함) 에서도 동일 재현 (M13 의 uid-scoped socket `/tmp/hexa-daemon-<uid>.sock` 변경이 R3 autospawn 의 고정 socket-path 기대와 충돌 → fork-mode 전환). **M14 와 무관** (M14 는 serve-loop atlas check + throttle env 만; socket path resolution 미변경). M13 follow-up 으로 추적 필요.
- **gate**: `hexa parse self/main.hexa` + `hexa parse tests/m_daemon_r4_atlas_flush_test.hexa` clean. `hexa build self/main.hexa` clang green (warning만). rebase 충돌 해소 = RFC §12 표 (M13 R4-codegen 행 + M14 R4-atlas-flush 행 공존, R5 todo 에서 (c) 제거).

### 다음 (R4 잔여)

- [ ] R4(a/b/d/e) — (a) binary u32-LE length-prefix wire (선행 `net_read_raw` 빌트인 + codegen) · (b) AST/lexer/lower in-memory 유지 · (d) multi-uid reject + root refuse (F-DAEMON-5 · `getuid()` builtin 선행) · (e) prod ship — verb 안정화 · 문서 · `hexa init` 안내 · 10/10 falsifier closure.

## 2026-05-25 · M13 — hexa daemon R4 codegen (net_read_raw + os_getuid 빌트인 + multi-uid 강화, RFC 093 § R4 carve-out)

> R3 (PR #931) 가 R4 의 codegen 의존 2개를 명시 carve-out: (a) binary wire 의 NUL-preserving reader `net_read_raw` · (b) F-DAEMON-5 multi-uid reject 의 `getuid()` builtin. 둘 다 codegen builtin 추가 → [[codegen 변경 검증+랜딩 레시피]] 상 hexa_cc.c 재생성이 mutually-conflict 라 **한 PR 묶어** serial-safe 처리.

- [x] M13 — `self/native/net.c` 2 신규 builtin:
  - `hexa_net_read_raw(fd, len)` — `hxlcl_recv` 를 정확히 `len` byte 누적할 때까지 루프 (peer close → short array) → NUL-safe `[int]` 반환. net_read_n 의 exactly-n 루프 + net_read_bytes 의 array 결과 결합. ENOTSOCK 시 `hxlcl_read` fallback (pipe/pty). EINTR retry · EAGAIN/EWOULDBLOCK → EOF.
  - `hexa_os_getuid()` — `getuid(2)` → Int. **`getuid` 가 아닌 `os_getuid` 명명** 이유: `getuid` 는 codegen `_hexa_name_is_reserved` set 이라 call-site 에서 `u_getuid` 로 mangle → dlsym extern-wrapper 경로와 충돌 (term_getppid 가 `getppid` 안 쓰고 우회하는 것과 동일 함정).
  - shim global + `_hexa_init_net_fn_shims` 등록 (interp bridge) · `self/runtime.h` forward-decl 2개 (standalone user.c compile).
- [x] M13 — `self/codegen.hexa` dispatch 3곳: 2-arg block `net_read_raw` · 0-arg block `os_getuid` · `_hexa_is_builtin_name` 2 entry.
- [x] M13 — `self/main.hexa` multi-uid 강화 (F-DAEMON-5):
  - `_daemon_default_socket` — `$USER` → 실 numeric uid (`os_getuid()`) keyed: `/tmp/hexa-daemon-<uid>.sock` (RFC §4.1). `$USER` 는 getuid 실패 시 fallback.
  - `cmd_daemon_start` — root-refuse 추가: `if os_getuid() == 0 { exit(1) }` (RFC §6.1 — daemon 은 arbitrary-code-exec 머신이라 root 거부). R1/R3 의 no-op 코멘트를 실코드로.
  - help 텍스트 socket path `$UID` 로 갱신.
- [x] M13 — `tests/m_daemon_r4_codegen_test.hexa` 3 falsifier: F-DAEMON-R4-1 (loopback proc_fork NUL round-trip) · F-DAEMON-R4-2 (os_getuid==`id -u`) · F-DAEMON-R4-3 (uid-scoped socket + non-root).
- [x] M13 — RFC 093 §12 표 R4(codegen) ✅ landed + R5 row 신설 + R4 honest carve-out · GO.md M13 milestone.

### 검증 결과 (mac arm64 · `/tmp/hexa-m13` fresh clone @ origin/main `c5d2499d` · codegen 레시피 엄수)

- **codegen regen**: `hexa cc --regen` → `lexer=ok parser=ok tc=ok cg=ok` · hexa_cc.c.new 28212 lines (+20).
- **FIXPOINT PASS** — promote 후 재-regen 한 `hexa_cc.c.new` 가 promoted `hexa_cc.c` 와 **byte-identical** (gen2≡gen3 · `diff -q` clean). 트랜스파일러가 자기 변경을 stable-point 로 재생산.
- **DIRECT transpile 검증** (`/tmp/v2tool` = 새 hexa_v2 · `hexa build` 캐시 trap 회피): probe + test → `hexa_os_getuid()` / `hexa_net_read_raw(...)` C 호출 정확 emit.
- **회귀 무** — 새 vs base(`origin/main:hexa_v2`) 트랜스파일러로 m_daemon_r1/r3 + t34_net_listen transpile+compile, clang-err new==base (WORSE 0).
- **R4 3 falsifier ALL PASS** (`/tmp/m13test`):
  - `[R4-1] PASS: net_read_raw round-tripped 7 bytes incl embedded NUL` (payload `[72,0,105,0,0,255,7]` — net_read/net_read_n 은 첫 NUL 에서 truncate, net_read_raw 는 7 byte 정확 복원)
  - `[R4-2] PASS: os_getuid()=501 matches id -u`
  - `[R4-3] PASS: non-root (uid=501) · uid-scoped socket = /tmp/hexa-daemon-501.sock`
- **main.hexa parse-gate**: 새 `/tmp/v2tool` 로 `self/main.hexa` transpile clean (`os_getuid` 2 call-site wired).

### 디자인 결정 (R4 codegen)

- **binary wire 실전환은 R5 defer (occam g0)** — net_read_raw reader primitive 만 land. 현 daemon payload (COMPILE `<TAG> <path>` · STATUS) 는 NUL-free 라 binary u32-LE framing 이득 0 · R3 가 이미 newline-text 로 작동. binary wire 가 가치 갖는 건 daemon 이 압축 binary bytes 자체를 client 로 보내는 케이스 (R5) — 그때 net_read_raw 가 reader.
- **multi-uid 은 uid-scoped path + root-refuse 까지** — socket 이 numeric-uid keyed (cross-uid 도달 차단) + root daemon refuse. **per-conn SO_PEERCRED/LOCAL_PEERCRED 는 R5 defer** (uid-scoped path 자체가 1차 방벽 · peer-cred 는 defense-in-depth).
- **shared-worktree 격리 함정** — 배정된 worktree 가 타 세션 leak 파일 (INBOX.md·RUNTIME.md·stdlib/nuclear/sim.hexa·tool/verify_cli.hexa·staged main.hexa 387L) + stale HEAD (detached @ 9b0a01a1) 상태였음. 내 2 파일만 stash → `/tmp/hexa-m13` fresh clone (github remote reset to `c5d2499d`) 에서 작업 → 타 세션 work 무손상. [[feedback_hexa_lang_shared_worktree_branch_hazard]] · [[reference_codegen_change_verify_recipe]] 의 "fresh-clone" 처방.

### 다음 (R5)

- [ ] R5 — (a) binary u32-LE length-prefix wire **실전환** (net_read_raw 사용) · (b) AST/lexer/lower in-memory 유지 · (c) atlas SSOT hash flush (F-DAEMON-4) · (d) per-connection SO_PEERCRED/LOCAL_PEERCRED peer-uid 확인 · (e) prod ship — verb 안정화 · 문서 · `hexa init` 안내 · 10/10 falsifier closure (CI sudo -u multi-uid 시뮬 포함).

## 2026-05-25 · M16 — compiled `sleep_ms` no-op fix (real libc nanosleep)

> M14 (PR #941) 가 daemon throttle 작업 중 별 runtime 버그 보고: "Compiled `sleep_ms` is effectively a no-op (mono_ns delta ≈ 1000 ns)". timing-의존 코드 전반 영향 (daemon throttle · poll loop · 모든 sleep 계열). M16 = 진짜 fix.

### 근본 원인 (1줄)

`self/runtime.c::hxlcl_nanosleep` 이 **cycle-6 no-op stub** — `req` 인자를 통째 무시 (`(void)req;`) 하고 `rt_posix_ok()` 즉시 반환. 따라서 이 위에 얹힌 **모든** sleep 빌트인 (`hexa_sleep` / `sleep_s` / `sleep_ms` / `sleep_ns`) 과 `persistent_pipe` 10 ms backoff 가 compiled path 에서 silent no-op. `sleep_ms`/`sleep_ns`/`hexa_sleep_s` 의 runtime body 와 codegen dispatch (`codegen.hexa:5789` `hexa_sleep_ms(...)`) 는 **정상** — 단 하나 공유 하단 syscall shim 만 stub 이었음. (자매 `hxlcl_clock_gettime` 은 이미 real libc 호출 → 이놈만 누락.)

- [x] M16 — `self/runtime.c::hxlcl_nanosleep` body 교체: `(void)req` no-op → `extern int nanosleep(...)` + `return nanosleep((const struct timespec*)req, (struct timespec*)rem);`. `<time.h>` 는 파일 상단 (line 14) 이미 include · darwin-arm64 raw-trap + linux 양쪽 libc 링크 (clock_gettime 동일 family) → 단일 shim 1곳 수정으로 양 플랫폼 커버.
- [x] M16 — `tests/m_sleep_ms_test.hexa` 신규 (3 falsifier · mono_ns delta 측정): sleep_ms(100) ∈ [90 ms, 200 ms] (OS jitter 관대) · sleep_ms(0) < 50 ms 즉시 반환 · sleep_ms(-5) clamp-to-0 no-crash.

### 검증 결과 (mac arm64 · DIRECT transpile compiled path · interp 아님)

- **cc --regen 불필요** — runtime.c-only fix. codegen dispatch (`hexa_sleep_ms(arg)`) 이미 존재 · hexa_v2 트랜스파일러 무변경. `~/.hexa-cache/runtime.<sha>.o` content-hash 캐시가 runtime.c 편집을 자동 fresh-object 로 반영 (`runtime.d47d56c5...o` 신규 컴파일 확인). 기존 main-repo hexa_v2 로 빌드.
- **BEFORE (stub runtime.c)**: `sleep_ms(100)` elapsed = **1000 ns** (= M14 보고 ≈1000 ns 정확 재현 · no-op) → test FAIL exit=1.
- **AFTER (libc nanosleep)**: `sleep_ms(100)` elapsed = **101,264,000 ns ≈ 101 ms** (real sleep, in [90 ms, 200 ms]) · sleep_ms(0) = 1000 ns 즉시 · sleep_ms(-5) = 0 ns clamp. **3/3 PASS exit=0**.
- 측정 요약: **전 delta ≈ 1000 ns (1 µs) → 후 delta ≈ 101 ms** (약 10만 배 증가 = 요청한 100 ms 실 sleep).

### 디자인 결정 / 함정

- **단일 shim 수정 (occam)** — sleep_ms 만 고치는 게 아니라 공유 `hxlcl_nanosleep` 을 고쳐 sleep/sleep_s/sleep_ns/persistent_pipe backoff 까지 일괄 정상화. stub 이 `rem` 을 0 으로 zero-fill 하던 (EINTR 가정) 동작도 제거 — libc 가 실제 잔여시간 채움 → 호출부 `while (...EINTR) req=rem` 루프 정상 작동.
- **shared-worktree 격리 함정 (재발)** — Read/Edit 의 기본 경로가 shared main worktree (`/Users/ghost/core/hexa-lang`, detached @ 9b0a01a1 · 타 세션 leak 파일 다수) 로 잡혀 첫 edit 이 거기 leak. `git checkout -- self/runtime.c` 로 즉시 revert 후 배정된 isolated worktree (`agent-a6a3a527795fbe3c1` @ origin/main 86e17741) 에 재적용. [[feedback_hexa_lang_shared_worktree_branch_hazard]] · [[feedback_subagent_worktree_leak_pattern]].
- **M15 와 직교** — M16 = runtime sleep_ms (self/runtime.c + test) · M15 = daemon test (test only). 영역 무중첩 · cc --regen 도 불필요 → conflict 0.

