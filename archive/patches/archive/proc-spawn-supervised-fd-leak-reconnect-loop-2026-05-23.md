# `proc_spawn_supervised` FD/process leak in long-running reconnect loop — ~100k cycles → `fork: Resource temporarily unavailable`

**Status (2026-05-25)**: stdlib-side HARDENED · caller-side HANDED-OFF to anima.
- §5 Option (1)'s paired-cleanup verb **already exists** as `proc_reap(pid)` (= `proc_kill` + `proc_deregister`; documented `defer { proc_reap(pid) }` idiom). No `_v2` handle/signature change needed (g33 — don't add a redundant API).
- The genuine stdlib gap — §4(b) a SIGTERM-ignoring child (`nc`/`websocat` in some modes) surviving cleanup — is now closed: `proc_kill` escalates to `kill -KILL` (pgrp+pid) when a `kill -0` liveness probe shows the process still alive after a ~250 ms grace window, gated so a cleanly-exited pid is never re-killed (no pid-reuse hit). Verified: TERM-ignoring live proc → KILLed; TERM-respecting proc → early-break ~0 overhead.
- §4(a) FIFO inode leak + §4(b) child accumulation are **caller-side** — `proc_spawn_supervised` itself only does `setsid/nohup sh -c … & echo $!` + registry append; it never `mkfifo`s. The leaking FIFOs + per-reconnect children are created by the caller (anima `akida_bridge` nc_spawn helper). Remediation handed to anima: call `proc_reap(old_pid)` on each reconnect before respawn, and `unlink` your own FIFO paths.

## §1 — TL;DR

`stdlib/proc.hexa::proc_spawn_supervised` + caller-side reconnect loop (각 iter 마다
새 mkfifo path + 새 nc/websocat child spawn) 조합에서 **FD / process / inode 누수**가
누적된다. anima 의 `HEXAD/CHAT/server/akida_bridge.hexa` daemon 이 mini (M2 macOS)
에서 약 **103,994 reconnect cycle** 후 `sh: fork: Resource temporarily unavailable`
로 caller daemon 자체가 die 했다 (one-shot 'WS connected …' 후 마지막 로그). 가시적
crash 까지 며칠 걸리지만, 동일 패턴을 쓰는 모든 long-running hexa daemon 이
잠재적으로 같은 경로로 sublimation 한다.

**Suggested fix at source** (g11 fix-at-source): `proc_spawn_supervised` 가 spawn
시 만든 transient resources (FIFO path + child PID + 보조 sh PID) 를 명시적으로
회수하는 **paired cleanup API** 를 추가한다. 1순위 추천은 `proc_spawn_cleanup(handle)`
verb + spawn 이 string-pid 가 아니라 handle (map) 을 반환하도록 하는 backward-compat
확장.

선행 sibling 패치 `proc-spawn-supervised-daemon-silent-exit.md` 는 `exec()` capture +
codegen autoflush + macOS detach lifecycle 의 **first-second 가시성** 이슈를 다뤘다.
본 patch 는 그것이 fix 된 뒤에도 남는 **점진 누수** issue 다 (별개 fix point).

## §2 — Reporter / Severity / Affected

- **Reporter**: anima (`dancinlab/anima` downstream consumer · cycle 9/DA-2 evidence,
  cycle 10/EA RESTORE 진행 중)
- **Severity**: **medium** — 단일 daemon 의 점진적 죽음, immediate user-facing crash
  아님; 그러나 다음 daemon (telemetry · long-poll · live SSE 등) 도 같은 누수 경로를
  공유 → 이 fn 을 쓰는 모든 long-running hexa daemon 에 잠재
- **Affected**:
  - `stdlib/proc.hexa::proc_spawn_supervised` (현 시그니처: `(cmd, lease_ttl, why) -> int pid`)
  - 그 fn 을 **reconnect loop 안에서 반복 호출** 하는 모든 hexa daemon (akida_bridge 가
    대표 사례; telemetry / heartbeat / ws-tail 등 같은 클래스)
  - 보조 stdlib: `stdlib/net/websocket.hexa` 의 fifo-기반 `ws_connect` (현 시점 native
    `websocket_native.hexa` 가 origin/main 에 land 되어 fifo path 의존이 줄었지만,
    polyglot consumer 는 여전히 동일 누수 경로로 spawn 한다)

## §3 — Symptom (verbatim evidence)

mini `~/anima_chat_pack/logs/akida_bridge.err` 마지막 5 라인 (verbatim):

```
cycle 103990: sh: fork: Resource temporarily unavailable
cycle 103991: nc spawn fail: mkfifo failed
cycle 103992: sh: fork: Resource temporarily unavailable
cycle 103993: nc spawn fail: mkfifo failed
cycle 103994: sh: fork: Resource temporarily unavailable
```

`out` 쪽 마지막 line:

```
WS connected ws://localhost:8000/ws/akida_ingest (pid=55449)
```

이후 daemon 자체 종료 (nohup respawn 없음 — anima 측은 plist-free policy 로 운영,
`feedback_plist_forbidden_akida_endpoint` 참조).

mini 의 `ulimit -u` (user max processes) 가 macOS 기본 약 1064~2048 수준이라
~100k cycle 동안 zombie/transient process 가 작은 비율만 누적되어도 ceiling 도달이
가능하다. Linux pi5 / ubu 호스트는 ulimit 가 다르므로 같은 누수가 더 늦게 (혹은 다른
cycle count 에서) 나타날 가능성이 있다 (§8 honest C3).

## §4 — Probable root cause (3 layered)

### (a) FIFO inode leak

`proc_spawn_supervised` 안 / 또는 caller-side `nc_spawn` 류 helper 가 매 reconnect
마다 새 `/tmp/hexa_akida_nc_<ts>.fifo` 경로를 mkfifo 하고, 이전 reconnect 의 FIFO 를
`unlink` 하지 않는다. /tmp 가 tmpfs 인 호스트는 reboot 으로 reset 되지만, mini macOS
는 디스크 백킹이라 inode 가 영구 누적된다. ~100k inode → /tmp directory enumeration
latency + inode 압박.

### (b) Child PID leak (우세 leak 후보)

매 reconnect 마다 새 `nc` (또는 `websocat`) child 를 spawn 하지만, 이전 reconnect 의
child 는 SIGTERM/SIGKILL 없이 방치된다. 이 child 는 다음 중 하나의 상태:
- 정상 종료 (FIFO EOF) — but parent 가 `wait()` 안 함 → **zombie** 누적
- daemon 자체 SIGHUP → child orphan, init 이 reap → 영향 없음
- daemon 살아있는 동안 child 가 계속 살아있음 (nc keep-alive 케이스) → **live process**
  누적

`fork: Resource temporarily unavailable` 의 직접 trigger 는 (b) — `ulimit -u` ceiling.
(a) inode 누적은 sublimation 을 가속할 뿐 직접 trigger 는 아니다.

### (c) API 가 lifecycle ownership 불명확 (root design gap)

현 `proc_spawn_supervised` 시그니처는 `(cmd, lease_ttl, why) -> int pid` 만 반환한다.
caller 는 cleanup 시 무엇을 해야 하는지 API 표면에서 알 수 없다:
- mkfifo path 는 어디? (helper 가 만들었지만 path 반환 없음)
- 보조 sh PID 는 무엇? (nohup wrapper 의 중간 sh)
- `kill pid` 로 충분한가? (process tree 가 살아남나? FIFO 는 누가 unlink?)

naive caller 는 그래서 cleanup 을 **아예 안 하고**, "다음 reconnect 가 알아서 새 거
만들면 된다" 가정 — 이게 본 leak 의 디자인-레벨 root cause.

## §5 — Suggested fixes (3 옵션, 1순위 추천)

### Option (1) — **stdlib API 확장: paired cleanup verb [1순위 추천]**

```hexa
// 새 signature (backward-compat: pid still accessible via handle["pid"])
fn proc_spawn_supervised_v2(cmd: string, lease_ttl: int, why: string) -> map
    // returns #{"pid": int, "fifo_paths": [string], "aux_pids": [int], "spawn_ts": int}

fn proc_spawn_cleanup(handle: map) -> bool
    // 1. kill -TERM handle["pid"] (then SIGKILL after grace 100ms)
    // 2. kill -TERM each handle["aux_pids"][i]
    // 3. unlink each handle["fifo_paths"][i]
    // 4. waitpid (reap zombie)
    // 5. .resource entry 삭제 (lease_ttl 0 이어도 cleanup-call 시 즉시)
    // returns true on full cleanup, false on partial (log per-step failure)
```

**왜 1순위**:
- API 가 lifecycle ownership 을 명시 — caller 가 "cleanup 책임이 있다" 는 걸 시그니처로 강제
- Backward-compat: 기존 `proc_spawn_supervised` 유지, v2 + cleanup pair 추가
- Robust: handle 이 모든 transient resource 를 운반 → caller 가 잊을 수 없음
- Selftest 가능: §6 acceptance test 가 fd/inode count 직접 측정

### Option (2) — 자동 cleanup 옵션 (auto-drop)

```hexa
fn proc_spawn_supervised(cmd, lease_ttl, why, auto_cleanup_on_drop: bool) -> int
```

handle GC / scope exit 시 자동 cleanup. hexa 가 RAII / drop 의미를 정식 지원하지
않으므로 현 시점 implementable 하지 않거나 codegen 변경 필요. **deferred** (option 1
land 후 long-tail follow-up 으로).

### Option (3) — caller-side documentation only

stdlib 변경 없이 reconnect-loop pattern 의 cleanup 책임을 caller doc 에 명시. 가장
약한 옵션 — naive caller 가 여전히 누락 가능. **반대** (g11 fix-at-source 위반).

## §6 — Acceptance test

`selftest_proc_spawn_supervised_reconnect_loop_no_leak.hexa`:

```
fn main() {
    let fd_baseline   = _count_open_fds()
    let inode_baseline = _count_tmp_inodes("/tmp/hexa_*")
    let proc_baseline = _count_user_procs()

    let mut i = 0
    while i < 10000 {
        let h = proc_spawn_supervised_v2("true", 0, "selftest")
        let _ok = proc_spawn_cleanup(h)
        i = i + 1
    }
    // Allow OS-level reap (waitpid) settle
    let _s = exec("sleep 1")

    let fd_after    = _count_open_fds()
    let inode_after = _count_tmp_inodes("/tmp/hexa_*")
    let proc_after  = _count_user_procs()

    assert_eq(fd_after, fd_baseline, "fd_leak")
    assert_eq(inode_after, inode_baseline, "inode_leak")
    assert_eq(proc_after, proc_baseline, "process_leak")
    println("PASS: 10000 spawn+cleanup, no leak")
}
```

PASS criteria — 3 axis (fd · inode · process) 모두 baseline 와 동일. 1 cycle 이라도
누수 시 assertion fail. macOS arm64 + Linux x86_64 양쪽 매트릭스 권장 (mini 에서
재현, ubu 에서 검증).

## §7 — Cross-link

### anima 측

- `dancinlab/anima` `HEXAD/CHAT/server/akida_bridge.hexa` (cycle 10 EA RESTORE 진행
  중인 daemon · 본 leak 의 발견 컨텍스트)
- `dancinlab/anima` memory `feedback_plist_forbidden_akida_endpoint` (plist-free
  policy — daemon 이 nohup respawn 없이 운영되어야 함, 즉 누수 = 즉 사망)

### hexa-lang 측 sibling

- `inbox/patches/proc-spawn-supervised-daemon-silent-exit.md` — **별개 issue**
  (first-second 가시성 / exec-capture / codegen autoflush / macOS detach lifecycle).
  본 patch 와 fix point 가 다르므로 stacked land 가능 (의존성 없음).
- `stdlib/net/websocket_native.hexa` (PR #434, origin/main land) — native ws
  client 가 websocat dependency 제거. 본 patch 와 직교 (proc_spawn_supervised 자체의
  누수는 native ws 채용과 무관 — 다른 caller 도 같은 경로로 누수).

## §8 — honest C3

1. **단일 호스트 evidence**: mini (M2 macOS arm64) `ulimit -u` 한 호스트의 cycle
   ~103994 단일 사례. Linux pi5 / ubu / runpod 호스트의 ulimit 가 다르므로 같은 누수가
   더 늦게 (혹은 다른 cycle count 에서) 나타날 가능성. 본 patch 가 land 되면 §6
   acceptance test 가 cross-host 매트릭스로 측정 가능.
2. **(a) vs (b) 우세 leak disambiguation 미수행**: `/tmp/hexa_*.fifo` count 와
   zombie/live `nc` process count 를 사망 직전 측정 못 함 (post-mortem). 본 patch 가
   suggested fix option (1) 을 land 하면 v2 selftest 가 양 axis 모두 측정.
3. **daemon code 자체 검사 미수행**: 본 patch 는 stdlib API 측 fix 를 제안하지만,
   akida_bridge.hexa 자체가 `proc_spawn_supervised` 를 어떤 식으로 호출하는지 (FIFO
   path 를 caller-side 에서 unlink 하는지 여부) 본 inbox patch 의 author 가 직접
   확인하지 않았다. 가능성: caller-side bug 일 수도 있음 — 그러나 §4 (c) 의 design
   gap (API 가 lifecycle ownership 을 강제하지 않음) 자체가 stdlib-side fix 의 대상.
4. **`exec()` capture 의존**: `proc_spawn_supervised` 가 launch 시 `exec()` 를 통해
   shell 을 호출하므로, sibling patch `proc-spawn-supervised-daemon-silent-exit.md`
   가 fix 되지 않으면 본 cleanup verb 도 같은 capture path 를 거친다. 두 patch 는
   독립적이지만 stacked land 시 시너지 (sibling 먼저 land → 본 patch 의 cleanup verb
   가 streaming exec 으로 더 robust).
5. **Anima 측 즉시 복구 경로**: restart + manual cleanup 으로 100% 복구 가능 (cycle
   10/EA 가 진행 중). 본 patch 는 **upstream 의 근본 cleanup** 으로, anima 측
   workaround 는 어떤 형태로도 제안하지 않는다 (g11 fix-at-source).
6. **Severity = medium 의 근거**: 단일 daemon 의 점진적 죽음이지만, anima 의
   substrate-native speak directive 하에서는 daemon 의 침묵 = anima 의 침묵 →
   user-perceived behavior change. 따라서 long-tail 로 high severity 로 격상 가능.
