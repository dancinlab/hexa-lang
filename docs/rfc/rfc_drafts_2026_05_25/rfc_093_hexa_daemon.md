---
rfc: 093
title: hexa daemon — long-running compile server (in-memory codegen cache, fork-storm internal axis)
status: draft (design-only — no implementation)
priority: medium
filed: 2026-05-25
filed_by: claude-code worktree agent-a964995ceb828e11a (GO domain M5)
target_ssot: self/main.hexa (`hexa daemon` verb · future) · self/lsp/ (Option B vector)
unblocks:
  - GO domain M5 — fork-storm internal axis (compile-loop cold restart cost)
  - IDE/multi-session N-th invocation latency (parity with cold-cache hit)
  - hexa-lsp compile capability surface (Option B convergence)
related:
  - memory [[project_hexa_run_cache]] (~/.hexa-cache · content-hashed runtime.<sha>.o, warm 21×)
  - memory [[reference_hexa_module_loader_env_2026_05_20]] (HEXA_MODULE_LOADER bootstrap state)
  - memory [[reference_hexa_basename_sigkill_workaround_2026_05_19]] (external argv-matcher SIGKILL)
  - memory [[project_compiler_native_self_host_fixpoint]] (gen1.s ≡ gen2.s — daemon must preserve)
  - pool-route v0.6.5+v0.6.6+v0.6.7 (external fork-storm axis — already handled)
  - rfc_drafts_2026_05_20/rfc_065_hexa_loop.md (long-running `hexa loop` verb precedent)
governance:
  - "@D atlas_fold — daemon must not bypass embedded.gen.hexa fold path (atlas-citing programs read SSOT)"
  - "@D external_llm — daemon must not host external LLM (only `hexa loop --dfs` may, per CLAUDE.md)"
  - "no implementation in this RFC — design-only; phase plan in §9 lists the implementation PRs"
---

# RFC 093 — hexa daemon (long-running compile server)

## §1 동기 (motivation)

`hexa run` / `hexa build` 는 현재 호출당 **fresh process** 다 — Go 의 `go run`
모델. content-hash 기반 `~/.hexa-cache` (`[[project_hexa_run_cache]]`,
warm 21×) 가 codegen artifact 의 cold-cache 비용을 한 번으로 깎아주지만,
*컴파일러 자체* 는 매 호출 fork → exec → parser/lexer/lowering/codegen
table reload → atlas SSOT TEXT-parse 를 반복한다.

### §1.1 내부 axis 와 외부 axis

fork-storm 비용은 두 축으로 갈린다:

| 축 | 위치 | 처리 | 현황 |
|---|---|---|---|
| **외부** | sub-agent fan-out → 같은 mac 호스트에서 N개 동시 hexa fork | pool-route 0.6.5+0.6.6+0.6.7 | ✅ 머지 (offload to mini/ubu-2) |
| **내부** | 단일 세션의 반복 호출 (IDE 자동저장 · LSP hover · `hexa loop --dfs` 루프) | **본 RFC — daemon** | ⛔ 미해결 |

내부 axis 는 외부 axis 로 해결되지 않는다 — pool-route 는 fork 를 **다른 호스트**
로 옮길 뿐, fork 자체를 줄이지 않는다. 단일 mac 에서 LSP completion 이 100ms
주기로 trigger 되거나 `hexa loop --dfs` 가 round 당 5-30 compile 을 fire 할 때,
**프로세스 startup + module loader bootstrap + atlas TEXT-parse** 가 매번
재실행된다 (대략 ~수십 ms · 측정 §7 P0).

### §1.2 선행 패턴

장수 컴파일 daemon 은 산업표준이다:

- **Gradle daemon** (JVM) — Unix socket · idle TTL · pinned JDK
- **Bazel server** — gRPC · `~/.bazel/server/` workspace lock
- **rust-analyzer** (LSP) — codegen 은 안 하지만 type-check state in-memory
- **mypyc-server** — Python 컴파일러 daemon (`dmypy`) 으로 type-check round-trip 10× 감소
- **TypeScript tsserver** — LSP 안에 컴파일러 host 내장 (단일 process)

hexa-lang 의 현재 SSOT 는 `compiler/atlas/embedded.gen.hexa` (TEXT-parse,
runtime served by `static_atlas`) — daemon 에 한 번 로드하면 N 호출에 걸쳐
재사용 가능. RFC 065 의 `hexa loop` verb 가 이미 **long-running 프로세스**
선례를 제공 (DFS 루프 중간상태를 process-internal 로 유지).

## §2 goal · non-goal

### §2.1 goal

1. 단일 mac 세션의 N-번째 `hexa run` / `hexa build` 호출 latency 가 N=1 fork-mode
   대비 ≤ 1.5× (§7 F-DAEMON-2 falsifier).
2. daemon 부재/crash 시 자동 fork-mode fallback (§7 F-DAEMON-1, F-DAEMON-3).
3. content-hash 일치 시 codegen artifact `~/.hexa-cache` hit 와 동등 (memory hit)
   — 즉 disk-touch 0건.
4. atlas SSOT 일관성 — daemon 이 stale atlas 를 들고 있으면 안 됨 (§5
   invalidation).
5. **구현 0건** — 본 RFC 는 설계만; 9 절의 P0–P4 가 별도 PR.

### §2.2 non-goal

- 외부 host fan-out (pool-route 영역)
- 외부 LLM 호스팅 (CLAUDE.md `@D external_llm` 위배)
- atlas 직접 fold (`@D atlas_fold` — embedded.gen.hexa via branch → commit → PR 만)
- LSP 의 모든 capability (diagnostics/hover/completion 은 Option B 의 부속, §3.2)
- multi-user shared daemon (§6 security — single-user, single-uid only)

## §3 아키텍처 옵션 — A · B · C

### §3.1 Option A — gradle-style stand-alone daemon

```
┌─────────────────┐    unix socket    ┌─────────────────┐
│ hexa run foo.hx │ ─────────────────▶│ hexa-daemon     │
│ (thin client    │ ◀─────────────────│ (long-running   │
│  ~50 LOC)       │   JSON-RPC bytes  │  compile state) │
└─────────────────┘                   └─────────────────┘
       │                                     │
       │ if daemon down →                    │ idle TTL (default 30 min)
       │ fallback to fork-mode               │ → self-exit
       ▼                                     │
┌─────────────────┐                          │
│ legacy fork path│◀─────────────────────────┘ on crash → systemd-style respawn
└─────────────────┘                            (or thin client re-spawn next call)
```

**Pros**:
- 깨끗한 separation (daemon == server, hexa CLI == client)
- idle TTL 로 메모리 자연 회수
- LSP 와 독립 — `hexa daemon` 미설치/미실행 시 자동 fork-fallback
- gradle/bazel 의 운영적 사실 (~10년) 검증된 패턴

**Cons**:
- 새 binary 1개 + 새 verb 1개 (`hexa daemon {start,stop,status,kill}`)
- socket lifecycle 직접 관리 (`/tmp/hexa-daemon-<uid>.sock` · stale socket cleanup)
- crash recovery 로직 필요 (PID file · 잠금)

### §3.2 Option B — LSP-style server (`hexa-lsp` 확장)

```
┌─────────────────┐    LSP JSON-RPC    ┌─────────────────┐
│ editor (VS Code,│ ──────────────────▶│ hexa-lsp        │
│  Helix, ...)    │ ◀──────────────────│ (existing)      │
└─────────────────┘                    │                 │
                                       │ + new method:   │
                                       │   hexa/compile  │ ─┐
                                       │   hexa/run      │  │ shells out / in-process
                                       └─────────────────┘ ─┘
       ▲
       │ CLI 도 LSP client 로
       │ (`hexa run --via-lsp`)
       │
┌─────────────────┐
│ hexa run foo.hx │
└─────────────────┘
```

**Pros**:
- 기존 `hexa-lsp` binary 재사용 — 새 process class 0개
- LSP capability 확장 (compile/run 메서드) 은 IDE 가 자동 활용
- LSP 가 이미 syntax token (memory [[project_lsp_keyword_ssot_shared_2026_05_25]])
  · semantic tokenize 등을 in-memory 로 유지 → 자연스럽게 확장

**Cons**:
- LSP 가 IDE 전용 라 CLI 의존성으로 만들기 부자연스러움
- IDE 외 단독 `hexa run` 시 LSP 가 실행 안 돼 있으면 spawn → 첫 호출 비용은 그대로
- LSP capability 가 무거워지면 hover/completion latency 에 spillover
- LSP protocol 확장 = downstream IDE plugin 변경 (외부 의존)

### §3.3 Option C — shared library (`libhexa.dylib` / `libhexa.so`)

```
┌─────────────────┐   dlopen + symbol   ┌──────────────────────┐
│ hexa run foo.hx │ ───────────────────▶│ libhexa.dylib        │
│ (thin loader)   │                     │ (compiler core +     │
│                 │ ◀───────────────────│  in-proc atlas table)│
└─────────────────┘   c-abi call        └──────────────────────┘
       │
       │ process-internal — NOT a daemon
       │ — every fork still pays bootstrap
       ▼
   (no cross-call state — 같은 process 안에서 다회 호출이면 hit)
```

**Pros**:
- 가장 단순 (RFC 070 `hexa ld dlopen shared` 인프라 재사용 가능)
- multi-session race-condition 0건 (각 process 가 자기 사본)
- security 표면 최소 (socket/permissions 0건)

**Cons**:
- **본 RFC 의 동기 (fork-storm internal axis) 를 해결 못 함** — fork 가 dlopen
  도 다시 함. process-internal 캐시는 1회 호출 후 곧 사라짐
- LSP 처럼 별도 long-running host 가 있어야 의미 있음 → Option B 의 부분집합

### §3.4 비교 표

| 축 | Option A (daemon) | Option B (lsp 확장) | Option C (.dylib) |
|---|---|---|---|
| **cold latency (1st call)** | fork + socket connect ≈ +20 ms | fork + lsp spawn ≈ +200 ms (worst) | fork + dlopen ≈ +30 ms |
| **warm latency (N-th call)** | socket round-trip ≈ 1-3 ms | lsp round-trip ≈ 1-3 ms | dlopen 미캐시 — 매번 cold |
| **memory** | 1 process (~200 MB compiler core in-mem) | 1 process (lsp + compile core) | per-call (process-local) |
| **multi-session safety** | socket lock + per-uid socket | LSP 가 multi-client native | n/a (process-local) |
| **CLI 의존성** | optional (fallback 가능) | IDE-shaped (CLI 어색) | optional |
| **crash blast radius** | daemon 만 죽음 → 재spawn | LSP 죽음 → IDE 기능 全손실 | 호출 1건 죽음 |
| **구현 비용** | medium (새 verb + socket + lifecycle) | medium-high (LSP protocol 확장 + IDE plug) | low (libhexa.so 빌드) |
| **권장 시점** | now (P0–P4 RFC 시퀀스) | follow-up (Option A 안정 후) | infra reuse 만 (A/B 내부) |

### §3.5 권장 = Option A (+ C 내부 활용)

본 RFC 권장 = **Option A** stand-alone `hexa-daemon`.

- B 의 LSP 확장은 매력적이지만 CLI / non-IDE 사용을 어색하게 만든다.
- C 의 .dylib 는 fork-storm 자체를 못 줄인다 — A 의 daemon 이 *내부적으로*
  C 의 .dylib 를 dlopen 하는 것은 합리적이지만, 그건 구현 디테일.
- A 는 graceful degrade (daemon 없어도 fork-mode 동작) 가 자연스럽다.

## §4 protocol — JSON-RPC over unix socket

### §4.1 transport

- socket path: `/tmp/hexa-daemon-$UID.sock` (per-uid · NOT `$XDG_RUNTIME_DIR` 으로
  macOS portability 우선)
- byte protocol: length-prefixed JSON (`<u32 LE length><json bytes>`) — 단순 ·
  framing 모호성 0건
- 방법론: JSON-RPC 2.0 (id · method · params · result · error)

### §4.2 method set (minimal)

```
compile  {source_path: str, env: {str: str}, target: "run"|"build"|"parse"}
         → {artifact_path: str, content_hash: str, duration_ns: u64}

run      {source_path: str, argv: [str], env: {str: str}}
         → {exit_code: i32, stdout_path: str, stderr_path: str, duration_ns: u64}

cache_query  {content_hash: str}
             → {hit: bool, artifact_path: str?}

invalidate   {paths: [str]?}
             → {invalidated: u64}

status       {}
             → {pid: u32, uptime_ns: u64, calls_served: u64, cache_size: u64}

shutdown     {}
             → {ack: true}   // graceful drain
```

### §4.3 client-side flow

```
hexa run foo.hx
   │
   ▼
1. probe /tmp/hexa-daemon-$UID.sock
   ├─ connect OK  → send `run` → wait → relay stdout/stderr → exit
   └─ connect FAIL (ENOENT, ECONNREFUSED) →
        ├─ if HEXA_DAEMON_AUTOSPAWN=1 → fork daemon, retry 1× (200ms timeout)
        └─ else                       → fall through to fork-mode (current behavior)
```

`HEXA_DAEMON_AUTOSPAWN` 기본값 = `0` (opt-in) — 사용자 명시 의도 가 있을 때만
daemon 이 자동 생성됨. CI / 한 번-쓰는 환경은 fork-mode 유지 → 행동 변화 0건.

### §4.4 stdout/stderr 처리

- daemon 은 자식 컴파일 산출물을 **memory pipe → 파일 (`/tmp/hexa-daemon-$UID/<call_id>.out`)**
  로 캡처
- client 는 응답 받은 후 해당 파일을 `cat` (작은 양) 또는 `mmap` (큰 양) 으로
  자기 stdout 으로 relay
- relay 후 daemon 이 파일 unlink (GC) — `/tmp` 누적 0건

대안 = SCM_RIGHTS 로 fd 전달; macOS 도 지원이나 구현 복잡도 ↑. P2 에서 재검토.

## §5 cache & invalidation

### §5.1 in-memory 계층 구조

```
DaemonState {
    atlas:        Arc<StaticAtlas>,           // embedded.gen.hexa load 1회
    lexer_cache:  HashMap<file_sha, Tokens>,  // path × mtime 키
    parse_cache:  HashMap<file_sha, AstId>,
    lower_cache:  HashMap<file_sha, IrId>,
    codegen_cache:HashMap<content_sha, ObjPath>,  // ~/.hexa-cache 와 미러
    module_dep:   HashMap<file_sha, [file_sha]>,  // `use` 그래프
}
```

각 cache 는 **content-hash 키**. mtime 단독은 신뢰 안 함 (clock skew · git
checkout 의 mtime touch). hash = blake3 (RFC 070 의 hexa-ld 와 일치).

### §5.2 invalidation 트리거

1. **filesystem watcher** (kqueue on mac · inotify on linux) — `use` 그래프의
   파일 변경 → 영향 받은 cache entry drop
2. **explicit `invalidate` RPC** — IDE/build-system 이 명시 호출
3. **atlas SSOT 변경** — `compiler/atlas/embedded.gen.hexa` 의 hash 변동 시
   atlas + 모든 downstream cache 전체 invalidate (atlas-cite 코드는 atlas
   바뀌면 재컴파일 필요)
4. **TTL** — 무변경이어도 24h 후 강제 evict (long-running 메모리 누수 보험)

### §5.3 ~/.hexa-cache 와의 미러

content-hash 가 같으면 daemon in-memory cache miss 라도 `~/.hexa-cache/<sha>.o`
로 fall-through (warm 21×, memory `[[project_hexa_run_cache]]`). daemon 은
disk-cache 의 in-memory 인덱스 역할.

### §5.4 atlas SSOT 일관성

daemon 이 atlas 를 **메모리에 들고 있는 동안** 에 누군가 `compiler/atlas/embedded.gen.hexa`
를 fold (branch → commit → PR 패턴) 하면 stale. 대응:

- 시작 시 atlas SSOT 파일의 mtime+hash 캐시
- 주기적 (default 60s) re-stat → hash 변동 시 atlas + 전체 cache flush
- `@D atlas_fold` 거버넌스 우회 없음 — daemon 은 atlas 를 *읽기만* 한다

## §6 security

### §6.1 single-user · single-uid

- socket: `/tmp/hexa-daemon-$UID.sock` · 권한 `0600` · owner == invoking uid
- 시작 시 `getuid()` 와 socket owner 비교 → 불일치면 reject
- multi-user host (서버) 사용: 각 uid 가 자기 daemon — shared daemon 0건
- root daemon = refuse (`if getuid() == 0: exit 1`)

### §6.2 socket abuse

- daemon 은 **임의 코드 실행 머신** — `run` RPC 가 컴파일 + exec 함
- 따라서 socket 권한 0600 + uid-match 가 보안의 전부
- non-local socket (TCP, unix-abstract) = 영원히 거부; 본 RFC 의 socket 은
  filesystem unix only

### §6.3 secret leakage

- env passthrough 시 `SECRET_*` / `*_API_KEY` / `*_TOKEN` 로그에 redact
  (`[[stdlib/cloud/preflight Secret type]]` 패턴 재사용)
- daemon stderr 에 env 풀 덤프 금지

## §7 falsifiers (5)

| # | id | claim | verify |
|---|---|---|---|
| 1 | F-DAEMON-1 (fallback) | daemon 미설치/미실행 시 `hexa run foo.hx` 가 종전 fork-mode 와 byte-eq 결과 + 종전 ± 5% latency | A/B repo 100회 반복 · exit/stdout/stderr byte-eq · wall histogram KS-test |
| 2 | F-DAEMON-2 (speedup) | daemon 활성 시 N=100 호출 wall ≤ N=1 fork-mode × 1.5 (즉 평균 호출당 ≤ 0.015× fork-cost) | shell loop fixture · `/usr/bin/time -l` 측정 |
| 3 | F-DAEMON-3 (crash fallback) | daemon kill -9 직후 다음 client call 이 자동 fork-fallback 으로 정상 종료 | pkill harness + retry assertion |
| 4 | F-DAEMON-4 (atlas consistency) | atlas SSOT 파일 hash 변경 시 daemon 이 60s 내 flush + 다음 컴파일이 새 atlas 반영 (atlas-cite 코드 결과 byte-eq with fork-mode) | atlas edit + sleep 60 + diff harness |
| 5 | F-DAEMON-5 (no privilege escalation) | non-owner uid 가 socket 접근 시 EACCES; root daemon spawn refuse | multi-uid test (CI 에서 sudo -u) |

falsifier 들은 §9 의 P3 (multi-session test) 단계에서 자동화.

## §8 open questions

### Q1 — daemon protocol versioning

JSON-RPC method/param schema 가 진화하면 old client + new daemon 또는 그 역.
대응 후보:
- (a) `version` 필드 in 모든 RPC, mismatch 시 client 가 daemon shutdown → 재spawn
- (b) semver socket path (`/tmp/hexa-daemon-$UID-v1.sock`) — 동시병행 OK
- (c) protocol 영원히 backward-compat (스트릭트 evolve 규약)

권장 = (a) — 단순 + daemon 무상태 재spawn 비용 낮음.

### Q2 — `hexa loop --dfs` 와 daemon 의 관계

`hexa loop` (RFC 065) 도 long-running process. daemon 안에서 loop 를 돌릴지,
loop 가 daemon 의 client 인지, 별개 process 인지?

권장 = **별개 process** + loop 가 daemon client. 이유: loop 는 외부 LLM
훅 (`@D external_llm`) 의 보유자, daemon 은 순수 컴파일 머신. 격리 유지.

### Q3 — Windows / 비-unix 지원

unix socket 미존재. named pipe (`\\.\pipe\hexa-daemon-$UID`) 가 대안. 본 RFC
는 mac + linux 만 scope; Windows 는 별도 RFC.

### Q4 — autospawn 정책

`HEXA_DAEMON_AUTOSPAWN=1` opt-in 이 옳은지, 명시 `hexa daemon start` 후
사용이 옳은지. 권장 = opt-in 환경변수 + `hexa init` (memory `[[a12ce564]]`)
가 user shell 에 안내 출력.

### Q5 — sub-process isolation

`run` RPC 가 daemon process 안에서 컴파일된 코드를 *실행* 하면 사용자 코드
crash 가 daemon 을 잡는다. 대안:
- (a) `run` RPC 도 자식 process fork — 컴파일은 daemon 에서, exec 는 child
- (b) daemon 은 `build` 만, `run` 은 client 가 artifact 받아서 자기가 exec

권장 = (b) — daemon = pure compiler. 실행은 client. crash blast radius 최소.

### Q6 — codegen fold table & comptime const 오염

memory `[[reference_comptime_fold_shadow_family]]` — codegen fold table 이
module-global. daemon 안에서 N 호출에 걸쳐 살아 있으면 shadow 버그 family 가
**프로세스 수명만큼 stale**. 대응 = 호출마다 fold table 초기화 (cost 측정 §7
P0) 또는 binding 단위 scope-mark (해당 family fix 와 동일).

### Q7 — hot-reload of daemon binary

daemon 이 활성인데 `~/.hx/bin/hexa-daemon` 바이너리가 업그레이드되면 stale
in-memory code. 권장 = daemon 시작 시 자기 binary mtime 캐시 → 주기 (60s) 검사
→ 변동 시 graceful shutdown (client 가 다음 call 에서 새 binary 재spawn).

## §9 phase plan (선언적 — 코드 0)

| 라운드 | scope | falsifier | 의존 |
|---|---|---|---|
| **R1** | socket protocol — `compile` / `cache_query` / `status` / `shutdown` 4 method · framing · per-uid socket | F-DAEMON-1 (fallback) · F-DAEMON-5 (privilege) | 무 |
| **R2** | in-memory cache (atlas + lexer + parse + lower + codegen) + ~/.hexa-cache 미러 + content-hash 키 | F-DAEMON-4 (atlas consistency) | R1 |
| **R3** | multi-session test — N=100 호출 latency · crash-respawn · multi-uid reject | F-DAEMON-2 (speedup) · F-DAEMON-3 (crash) | R1 + R2 |
| **R4** | prod ship — `hexa daemon {start, stop, status, kill}` verb · `HEXA_DAEMON_AUTOSPAWN` · 문서 · `hexa init` 안내 | 10/10 falsifier closure | R1 + R2 + R3 |

각 R 은 독립 PR. 머지 후 atlas 자동 흡수 후보 (daemon family).

## §10 honest carve-out

- **수치 추정값 ±50%**: §3.4 의 latency 수치 (~20ms / ~200ms / ~30ms) 는 산업
  표준값에서 외삽. **실측 0건** — F-DAEMON-2 가 closure 시 진짜 숫자.
- **메모리 누수 보장 없음**: 24h TTL + invalidate RPC + atlas hash flush 가
  안전 장치이지만 **장기 실측 부재**. R3 에서 1주일 soak 테스트 필요.
- **macOS launchd 자동시작 X**: opt-in 환경변수만 — 사용자 의도 명시 시에만.
  systemd unit / launchd plist 는 별도 RFC.
- **윈도우 미지원**: §8 Q3 — 별도 RFC.
- **본 RFC 머지 = 코드 변경 0건**. 위 R1–R4 가 land 되어야 실제 daemon 동작.
- **`@D external_llm` 준수**: daemon 은 컴파일 머신; LLM 호출 0건. `hexa loop
  --dfs` 가 daemon client 일 수는 있지만 daemon 안에 LLM 호스팅 0건.
- **`@D atlas_fold` 준수**: daemon 은 atlas 를 read-only 로 들고만 있음 ·
  `embedded.gen.hexa` direct splice 는 여전히 branch → commit → PR.

## §11 acceptance summary

- 5 falsifier 모두 PASS 시 RFC 093 closure (R4 prod ship 직전 gate)
- 본 RFC 는 **draft only — 코드 변경 0건**
- 머지 후 별도 PR 체인 (R1–R4) 으로 실제 wiring

## §12 implementation status (구현 진행)

| 라운드 | PR | status | 비고 |
|---|---|---|---|
| **R1** | #904 (GO M10) | ✅ landed | socket skeleton · `{start,start-bg,stop,status,echo}` 버브 · newline-text wire (PING/ECHO/SHUTDOWN) · idle-TTL self-exit · stale-socket cleanup · runtime.c socket primitive 복원. 4-step e2e (`tests/m_daemon_r1_test.hexa`). |
| **R2** | (this) GO M11 | ✅ landed | `compile` 메서드 + in-memory cache. `COMPILE <src>` → `HIT <bin>` (memoized) / `BUILT <bin>` / `ERR <reason>`. 캐시 키 = `sha256(source)[0:16] + "_" + version_str()` — **`hexa run` / `hexa build` 과 byte-identical** → `~/.hexa-cache/hexa_run.<key>` 슬롯 공유. 3 falsifier (`tests/m_daemon_r2_test.hexa`): R2-1 cache hit · R2-2 fork-mode fallback · R2-3 determinism. |
| **R3** | (this) GO M12 | ✅ landed | `hexa run` autospawn wiring (`HEXA_DAEMON_AUTOSPAWN=1` opt-in → socket probe → spawn-if-missing → `COMPILE` → exec returned binary). 3-tier fallback **precompile (M2) → daemon (R3) → fork-mode** in `cmd_run_user_direct`. `HEXA_DAEMON_SOCKET` env override (socket isolation). `tests/m_daemon_r3_test.hexa` 3 falsifier: **F-DAEMON-R3-1 (autospawn)** · **F-DAEMON-R3-2 (latency N=100)** · **F-DAEMON-R3-3 (crash-respawn fallback)**. 측정 (mini arm64 fresh build): **N=100 warm-daemon 9,395 ms vs fork-mode 174,933 ms = 18.6× speedup** (F-DAEMON-2 RFC gate ≤ 1.5× far exceeded). R1/R2 회귀 무 (4/4 + 3/3 PASS). |
| **R4 (codegen)** | (this) GO M13 | ✅ landed | R4 의 **codegen-bound** 부분. 2 신규 builtin: **`net_read_raw(fd, len)`** = 정확히 len byte NUL-preserving read (binary u32-LE length-prefix wire 의 reader 선행) · **`os_getuid()`** = getuid(2) wrapper (`getuid` reserved-name mangle 회피 위해 `os_getuid` 명명 — `term_getppid` 패턴). 그 위 **F-DAEMON-5 multi-uid 강화**: socket path uid-scoped (`/tmp/hexa-daemon-<uid>.sock`) + root-refuse (`os_getuid()==0 → exit 1`). codegen 레시피 (cc --regen → promote → DIRECT transpile → **fixpoint gen2≡gen3 byte-identical** → 회귀 무). `tests/m_daemon_r4_codegen_test.hexa` 3 falsifier ALL PASS: R4-1 (loopback NUL round-trip) · R4-2 (os_getuid==`id -u`) · R4-3 (uid-scoped socket + non-root). |
| **R4 (atlas flush · c)** | (this) GO M14 | ✅ landed | **atlas SSOT hash flush (F-DAEMON-4)** — daemon serve-loop 가 COMPILE 처리 전 (2 s throttle · `HEXA_DAEMON_ATLAS_THROTTLE_MS` override) `compiler/atlas/embedded.gen.hexa` content hash (`sha256_file`, $HEXA_LANG > install_dir > ./ 해석) 를 직전 값과 비교 → 다르면 in-mem cache (cache_keys/cache_bins) **전체 flush + 해당 disk-mirror 바이너리 unlink** → 다음 COMPILE 이 새 atlas 로 re-build (stale HIT 방지). **Option B (daemon-only invalidation layer)** — `cmd_run`/precompile 키 불변 → M7 drift-guard · M2 precompile 무영향. `tests/m_daemon_r4_atlas_flush_test.hexa` 3 falsifier ALL PASS (mini arm64): F-DAEMON-4-1 (atlas 불변 → HIT) · F-DAEMON-4-2 (fold → flush → re-BUILT, no stale HIT) · F-DAEMON-4-3 (안정화 후 HIT 복귀, flush = one-shot edge). R1/R2/R3 회귀 무 (4/4 + 3/3 + 3/3). |
| **R5** | (next) | ⛔ todo | R4 의 **나머지** (M13 codegen + M14 atlas flush 가 (c) 닫음): (a) binary u32-LE length-prefix wire **실전환** (net_read_raw 사용 — 현재는 builtin 만 land, daemon payload 가 NUL-free 라 occam g0 로 newline-text 유지) · (b) AST/lexer/lower in-memory 유지 (R2/R3 는 binary-path 매핑까지만) · (d) SO_PEERCRED/LOCAL_PEERCRED per-connection peer-uid 확인 (현재는 uid-scoped path + root-refuse 까지) · (e) prod ship — verb 안정화 · 문서 · `hexa init` 안내 · 10/10 falsifier closure. |

### R4 (codegen) honest carve-out

- **binary wire 는 builtin 만 land, 실전환 X** — `net_read_raw` 빌트인은 추가됐지만 daemon
  의 newline-text wire 는 그대로. occam g0: 현 daemon payload (COMPILE 응답 `<TAG> <path>`,
  STATUS 등) 은 NUL 을 안 가져 binary u32-LE framing 의 이득이 없다. binary wire 가 실제
  가치를 갖는 건 daemon 이 압축 binary bytes 자체를 client 로 전송하는 케이스 (R5) — 그때
  net_read_raw 를 reader 로 쓴다. 지금은 reader primitive 만 선반영.
- **multi-uid 은 uid-scoped path + root-refuse 까지** — socket 이 `/tmp/hexa-daemon-<uid>.sock`
  로 numeric-uid keyed (두 uid 가 절대 같은 socket 공유 안 함) + 0700 /tmp 권한 + root
  daemon refuse. **per-connection peer-uid 확인 (SO_PEERCRED on Linux / LOCAL_PEERCRED on
  macOS) 은 R5 로 연기** — uid-scoped path 자체가 cross-uid 도달을 차단하므로 peer-cred 는
  defense-in-depth (현 단계 occam g0). CI 의 sudo -u 시뮬은 R5 prod-ship 게이트에서.
- **fixpoint 검증** — codegen 변경이라 `hexa cc --regen` 후 promote 한 `hexa_cc.c` 가
  재-regen 한 `hexa_cc.c.new` 와 byte-identical (gen2≡gen3) 확인 — 트랜스파일러가 자기
  변경을 stable-point 로 재생산. 회귀: 새 vs base 트랜스파일러로 동일 test transpile+compile,
  clang-err new==base (WORSE 0).

### R4 (atlas flush) honest carve-out (F-DAEMON-4)

- **Option B 선택 (daemon-only invalidation), NOT Option A (key 에 atlas hash 포함)** —
  Option A (cache key 를 `…_<atlas[0:8]>` 로 확장) 는 daemon 키를 `cmd_run`/`hexa build`
  /precompile 키와 **divergence** 시켜 M7 drift-guard 위반 + M2 precompile lookup 깨짐
  (scope 큼 — `cmd_run` 도 동시 수정 필요). Option B 는 daemon serve-loop 안에
  자체 invalidation layer 를 두어 키 불변 유지 → drift-guard/precompile 무영향
  (occam g0). Option C (mtime) 는 no-op `touch` 에도 flush 하는 false-positive →
  content hash (`sha256_file`) 채택.
- **flush 신호 = atlas SSOT *파일* content hash, NOT 임베드된 `ATLAS_HASH` 상수** —
  F-DAEMON-4 falsifier 문구("atlas SSOT 파일 hash 변경 시")대로 daemon 이 fork 하는
  `hexa build` 가 참조하는 atlas SSOT 파일(`compiler/atlas/embedded.gen.hexa`)의 실제
  바이트가 변하면 flush. 한 fold 가 commit 되면 그 파일 hash 가 바뀌므로 daemon 이
  다음 COMPILE 에서 감지.
- **disk-mirror 도 unlink** — 키(`sha256(source)+version_str`)는 atlas fold 로 안 바뀌므로
  in-mem flush 만으로는 부족 (다음 COMPILE 이 `~/.hexa-cache/hexa_run.<key>` disk HIT
  으로 여전히 stale binary 반환). flush 시 cache_bins 의 모든 disk 바이너리를 `rm -f`
  → true re-build 강제.
- **2 s throttle (`HEXA_DAEMON_ATLAS_THROTTLE_MS` override)** — back-to-back COMPILE 마다
  `sha256_file` (잠재적으로 10 MB) 를 읽으면 hot-path 비용. 기본 2 s 윈도우당 1회로 제한 →
  fold 감지 지연 ≤ 2 s (RFC §7 F-DAEMON-4 gate "60 s 내 flush" 대비 여유). 0 = 매 COMPILE
  체크 (테스트가 사용 — flush 를 wall-clock sleep 무관하게 deterministic 하게).
- **"" current-hash = unknown → never flush** — SSOT 해석 실패(파일 부재) 시 빈 hash
  반환 → flush 안 함 (transient 해석 miss 가 cache 를 thrash 하지 않게). 첫 관측값도
  마찬가지로 baseline 으로만 기록.
- **테스트 하네스 함정 (daemon 로직과 무관)** — (1) compiled `sleep_ms` 가 사실상 no-op
  (mono_ns delta ≈ 1000 ns) → throttle 윈도우를 sleep 으로 못 넘김 → throttle env=0 으로 우회.
  (2) build-host (mini) 에서 `hexa*`-prefix argv0 SIGKILL (rc=137) — `hexac` 통과. 둘 다
  atlas-flush 로직과 무관; `hexac` 드라이버 + throttle=0 으로 ALL 3 PASS.

### R3 honest carve-out

- **autospawn 은 opt-in** — `HEXA_DAEMON_AUTOSPAWN` 기본 0 (RFC §4.3). 미설정 시
  `hexa run` 은 종전 fork-mode 그대로 (행동 변화 0건 · CI/one-shot 영향 0). daemon
  tier 는 precompile lookup (M2) 와 fork-mode 사이에 끼며, 어떤 실패(socket missing +
  spawn fail · ERR reply · connect refused · 죽은 daemon)든 silent "" 반환 → fork
  fallback (graceful degrade · F-DAEMON-R3-3).
- **wire 는 여전히 newline-text** — binary u32-LE length-prefix + `net_read_raw` 는
  R4 로 연기. R3 의 핵심(autospawn + N=100 latency)은 binary wire 불필요: COMPILE 응답이
  `<TAG> <path>` 한 줄이고 binary path 는 NUL 을 안 가져 strlen-기반 `net_read` 로도
  온전히 round-trip (occam g0 — 정말 필요할 때만).
- **F-DAEMON-R3-2 측정 방법** — warm-daemon loop (socket 상주 · src in-mem cache →
  매 호출 HIT, fork 없음) vs fork-mode loop (매 호출 고유 src → cold slot → 진짜
  `hexa build` fork). disk `~/.hexa-cache` HIT 도 build 를 건너뛰므로, daemon 의
  fork-제거 이득을 격리하려면 fork side 가 실제로 fork 해야 함 (고유 src 로 강제).
- **multi-uid reject (F-DAEMON-5) 미구현** — `getuid()` builtin 미배선 (R1 부터의
  carve-out 유지). socket 권한 0600 + per-$USER path 가 현 보안의 전부. R4 로 연기.

### R2 honest carve-out

- **R2 의 "in-memory cache" 는 binary-path 매핑까지만** — §5.1 의 full
  계층(atlas/lexer/parse/lower 까지 in-process 유지)은 R3. R2 가 증명하는 것은
  "daemon 이 같은 source 를 두 번째 호출부터 `hexa build` fork 없이 즉시 캐시
  히트 반환" — fork-storm internal axis 의 1차 closure.
- **wire 는 여전히 newline-text** — RFC §4.1 의 binary u32-LE length-prefix 는
  현 runtime 의 `net_read`(strlen 기반, NUL 미보존) 제약으로 R3 로 연기.
  `compile` 버브 자체가 R2 의 framing 업그레이드.
- **autospawn 미배선** — `hexa run` 은 R2 에서도 항상 fork-mode (행동 변화 0건).
  daemon 사용은 명시적 `hexa daemon compile` 만. R3 가 `HEXA_DAEMON_AUTOSPAWN`
  probe 를 `hexa run` 에 배선.
- **determinism = content-addressed slot identity (NOT rebuild byte-eq)** —
  R2 검증 중 발견: `hexa build` 는 호출마다 per-build LC_UUID / 임베드된 출력
  경로 때문에 **같은 source 의 두 독립 build 가 이미 byte-diff** (macOS arm64
  측정: 첫 divergence ~char 1449). 따라서 daemon vs fork-mode 동등성의 실제
  보증은 "rebuild 가 byte-identical" 이 아니라 "양쪽이 같은
  `~/.hexa-cache/hexa_run.<key>` 슬롯을 content-address → 먼저 build 한 쪽이
  이김 → 나머지는 그 동일 파일에 byte-identical HIT" 다. F-DAEMON-R2-3 가 바로
  이걸 측정 (mini arm64: daemon HIT sha ≡ fork-mode slot sha). gen1.s ≡ gen2.s
  fixpoint (`[[project_s3_fixpoint_full_closure_2026_05_20]]`) 는 별개 축 —
  compiler self-host 출력 determinism 이지 user-program build determinism 아님.

(끝.)
