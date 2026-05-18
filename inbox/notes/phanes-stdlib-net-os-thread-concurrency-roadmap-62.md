# incoming note: phanes-stdlib-net-os-thread-concurrency-roadmap-62 — stdlib/net concurrency surfaces are logical-only today; multi-tenant SaaS scaling blocked on roadmap 62

> **id**: `phanes-stdlib-net-os-thread-concurrency-roadmap-62` · **opened**: 2026-05-19 KST · **status**: `reported (downstream phanes — using async-submit downstream workaround at the job dispatcher layer)`
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
- `phanes-stdlib-net-os-thread-concurrency-roadmap-62` — this note (reported)

Same-day downstream→upstream pipeline working 2/2 so far.
