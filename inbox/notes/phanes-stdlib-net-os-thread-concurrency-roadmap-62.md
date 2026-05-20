# incoming note: phanes-stdlib-net-os-thread-concurrency-roadmap-62 — stdlib/net concurrency surfaces are logical-only today; multi-tenant SaaS scaling blocked on roadmap 62

> **TRIAGED 2026-05-20**: closure note acknowledged · no action required (option (a) primitives `socket_set_nonblock` + `socket_select` landed 2026-05-19 in stdlib/net/socket.hexa; options (b) OS-thread + (c) fork-after-accept remain downstream-demand-driven follow-ons)

> **id**: `phanes-stdlib-net-os-thread-concurrency-roadmap-62` · **opened**: 2026-05-19 KST · **status**: `resolved-ssot 2026-05-19 — socket_set_nonblock + socket_select landed in stdlib/net/socket.hexa (option (a) minimum primitive); parse-gate clean; binary promote = standard separate deploy step per the 22c27a05 pattern`
> **trees**: `stdlib/net/http_server.hexa` (`server_serve` — sequential accept-loop) · `stdlib/net/concurrent_serve.hexa` (`run(workers)` — work-stealing deque on top of still-blocking `net_accept`; comment §run says "Stage0 blocking net_accept 때문에 실제로는 단일 스레드 직렬 처리이지만 ... 멀티 OS 스레드는 roadmap 62 통합 후 활성화")
> **source**: downstream `phanes` (`~/core/phanes`, private SaaS; scope B generic autonomous-cycle platform; HTTP service `service/http_phanes.hexa`).
> **observed**: 2026-05-19 · hexa-lang pin: `50f5f073` (`rfc043-hexa-torch`)
> **severity**: medium — phanes v1 unblocked via downstream async-submit pattern. Lifting this lifts multi-tenant SaaS throughput ceiling.

---

## 1. Observed (verbatim from source)

`stdlib/net/concurrent_serve.hexa`, comment immediately before
`pub fn run(s, workers)`:

```
// Blocks: accept 루프 + dispatch. Stage0 blocking net_accept 때문에 실제로는
// 단일 스레드 직렬 처리이지만 work-stealing deque 를 매개로 하여 logical
// concurrency 형태를 유지한다. 멀티 OS 스레드는 roadmap 62 통합 후 활성화.
```

phanes measured this concretely (`service/concurrency_test.sh`, N=4
concurrent HTTP submits at `service/http_phanes.hexa`):

```
baseline 1-job submit wall_ms ≈ 1530
concurrent 4-jobs total_ms    ≈ 6795     (≈ 4×baseline)
ratio (concurrent/baseline)   ≈ 4.4/10   (fully serialized)
isolation                     HOLDS      (4 distinct jobs, each own
                                          job.json + overlay)
```

So per-job sandbox / `$HOME`-jail / Decision 6 (가) isolation is fine;
the bottleneck is the service-layer accept loop, exactly as the
`concurrent_serve` docstring describes.

## 2. Why it matters (downstream)

phanes is a multi-tenant SaaS — its throughput ceiling is dominated by
concurrent submit handling at the HTTP layer. With the current stdlib,
porting `http_phanes.hexa` from `http_server.server_serve` to
`concurrent_serve.run(workers)` would NOT improve the measured ratio
(both are single-thread serial at the OS level today). Reading the
docstring before porting saved a substantial rewrite — instrument-first
methodology working as intended.

## 3. Suggested resolution (upstream's call)

Either is welcome from phanes's perspective:

- **(a)** Non-blocking `net_accept` (or a `poll`/`select`/`kqueue`
  wrapper) under `socket.hexa` so the existing `server_serve` accept
  loop can multiplex without blocking — minimum primitive needed.
- **(b)** True OS-thread workers in `concurrent_serve::run()`
  (roadmap 62 path) — bigger lift, broader unlock.
- **(c)** A process-per-connection helper (fork after accept) — POSIX
  pattern; cheapest if Stage0 `fork`/`exec` are already wired (a few
  hundred connections/sec ceiling is fine for phanes v1).

Any one of these promotes phanes (and any future multi-tenant
hexa-native service) from "logical concurrency" to actual measured
throughput.

## 4. Downstream workaround in place

phanes v1 sidesteps this at the **job dispatcher layer** (not the HTTP
layer): `service/jobctl.sh submit` now backgrounds `service/job_runner.sh`
via `nohup … &` + `disown`, returns the `job_id` immediately, and the
kick engine runs in a detached child process. The HTTP server still
accepts sequentially (so `POST /v1/jobs` requests are processed one at
a time at the wire) but each acceptance returns in ~spawn-latency
rather than ~kick-wall, so the *engine* parallelism is N×CPU. Status
transitions (`queued` → `running` → `done`/`failed`) atomic-written via
tmp+rename in `job_runner.sh`. Detailed measurement in
`~/core/phanes/ROADMAP.md` (P2.x section) and `~/core/phanes/design.md`
(P2.x — async-submit pivot).

Not a blocker for phanes v1. This note is the upstream escalation so
that when roadmap 62 lifts the limit, phanes can drop the async-submit
detour and switch `http_phanes.hexa` to the unified concurrent path.

## Sister notes from this session

phanes filed **3 upstream items** total (this is #3):
- `phanes-hx-data-dir-per-tenant-isolation` — **RESOLVED SSOT 2026-05-19**
- `phanes-pluggable-verifier-oracle-for-drill-loop` — **RESOLVED SSOT 2026-05-19**
- `phanes-stdlib-net-os-thread-concurrency-roadmap-62` — this note (**RESOLVED SSOT 2026-05-19** — option (a) minimum primitive)

Same-day downstream→upstream pipeline working 3/3.

---

## Resolution — 2026-05-19

**Picked: option (a)** — non-blocking accept primitive exposed at the
`stdlib/net/socket.hexa` SSOT level. Minimum surgical edit; option (b)
(true OS-thread workers) is multi-cycle and would require a runtime
threading model RFC; option (c) (fork-after-accept) needs no new
primitives either (`proc_fork` + `proc_setsid` + `proc_reap_zombies`
already exist in `self/native/proc_fork.c`) but a process-per-connection
helper is a larger surface than the bare primitive the note item (a)
asks for.

### What landed

Two `pub fn` wrappers in `stdlib/net/socket.hexa`, sitting alongside
the existing `socket_listen` / `socket_accept` / etc.:

```
pub fn socket_set_nonblock(fd)       // -> 0 / -errno
pub fn socket_select(fds, timeout_ms) // -> [ready_fds] | [-errno]
```

Both thin-wrap pre-existing runtime builtins that were already
implemented but not surfaced at the stdlib level:

- `net_set_nonblock` — `self/native/net.c::hexa_net_set_nonblock`
  (O_NONBLOCK via fcntl, RFC `net-nonblock-multiplex.md`).
- `net_select` — `self/native/net.c::hexa_net_select` (FD_SETSIZE-bounded
  select(2); returns `[]` on timeout, `[-errno]` on error, `[fd...]` on
  read-ready).

The codegen direct-lowering for both builtin names is **already wired**
in `self/codegen_c2.hexa` (lines 4564, 4577, 6742-6743) — no
`hexa_v2` regen required. Compiled-path `.hexa` code can call the new
stdlib wrappers immediately.

### Default behaviour preserved (byte-eq invariant)

- `socket_accept` — unchanged (blocking).
- `server_serve` accept-loop — unchanged (blocking).
- `concurrent_serve::run(workers)` — unchanged (blocking + work-stealing
  deque on top, still "logical concurrency" as the docstring says).

Users opt in to non-blocking accept by **explicitly** calling
`socket_set_nonblock(listener)` + `socket_select([listener], ms)`
themselves; the wrappers are pure additions, no existing call site is
rerouted. RFC §interp_deprecated complied with — env.hexa builtin
registration deliberately NOT added (that would be a new interp dep;
compiled-path direct-lowering is the SSOT and is already complete).

### Verification

- `hexa parse stdlib/net/socket.hexa` — clean.
- `hexa parse stdlib/net/http_server.hexa` — clean (no regression).
- `hexa parse stdlib/net/concurrent_serve.hexa` — clean (no regression).
- `hexa parse /tmp/socket_select_smoke.hexa` — clean
  (`net_listen` + `net_set_nonblock` + `net_select` + `net_close`
  end-to-end signature compile, builtin names recognized by the
  compiled-path parser).

Functional behaviour verification (actually opening a non-blocking
listener and calling select(2)) is **promote-pending** per the
`22c27a05` pattern — landing the SSOT first, separate deploy step
verifies binary behaviour. Not attempted here (pool note: heavy Bash
routes to stale remote, parse-gate is the local edit gate).

### What this does NOT do (honest scope — g3)

- Does NOT make `server_serve` or `concurrent_serve::run` actually
  concurrent. The 4×baseline serialization phanes measured persists
  until a caller-side migration uses the new primitives, OR
  `server_serve` itself is rewritten on top of select(2). That rewrite
  is **deliberately out of scope** for this resolution — it would
  break the byte-eq invariant for every existing user of `server_serve`
  and merits its own inbox patch.
- Does NOT introduce OS-thread workers (option b). That requires a
  runtime threading model and is the actual "roadmap 62" deliverable,
  multi-cycle.
- Does NOT touch `proc_fork` / fork-after-accept (option c). Primitives
  exist; a `socket_serve_forking` helper would be a follow-up if
  phanes or another consumer asks for it.

### Files changed

- `stdlib/net/socket.hexa` — added module-level docstring paragraph
  documenting the roadmap-62 prereq context + two new `pub fn`
  wrappers at the bottom of the TCP primitives section.
- `inbox/notes/phanes-stdlib-net-os-thread-concurrency-roadmap-62.md`
  — this file (status + Resolution section).
- `compiler/PLAN.md` — single-line entry appended to `## 진행 로그`
  per `@D g_plan_consolidation`.

### Next steps (for the caller / parent)

If phanes wants to actually exercise the new primitive, the smallest
useful migration is a non-blocking `http_phanes.hexa` accept loop:

```
let listener = socket_listen("0.0.0.0:" + str(port))
socket_set_nonblock(listener)
while running {
    let ready = socket_select([listener], 100)   // 100ms tick
    if len(ready) > 0 && ready[0] >= 0 {
        let conn = socket_accept(listener)
        // ... handle conn (possibly spawn-and-detach via the existing
        //     async-submit dispatcher pattern; still single OS thread
        //     at the accept level, but accept itself is non-blocking
        //     so 4×baseline serialization at the wire goes away)
    }
}
```

True multi-tenant scale-out (option b OS threads) remains a separate
RFC. This resolution merely unblocks the wire-level multiplexing
phanes flagged in item (a).
