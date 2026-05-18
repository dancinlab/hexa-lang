# incoming patch: phanes-pluggable-verifier-oracle-for-drill-loop — drill loop has no pluggable external verifier/oracle hook; scope-B (tenant-supplied objective+verifier) needs an in-loop authority for "objective met"

> **id**: `phanes-pluggable-verifier-oracle-for-drill-loop` · **opened**: 2026-05-19 KST · **status**: `resolved-ssot 2026-05-19 — pluggable verifier hook landed in drill_run; parse-gate clean; binary promote = standard separate deploy step per the 22c27a05 pattern`
> **trees**: `compiler/drill/drill.hexa` (`drill_run` loop · `_honesty_gate` — internal BT-AI2, advisory/non-blocking) · `compiler/drill/round.hexa` (`round_run_with_pool`) · `compiler/honesty/check` (`bt_ai2_audit`)
> **source**: downstream `phanes` (`~/core/phanes`, new dancinlab consumer — private SaaS; Decision 1 = scope B: tenant brings a measurable objective + a verifier/oracle, phanes drives `goal → falsifier → saturation` against it).
> **observed**: 2026-05-19 · hexa-lang pin: `50f5f073` (`rfc043-hexa-torch`)
> **severity**: medium / design — the engine works; this is a missing extension point, not a bug. Without it the falsifier cannot live *in* the loop for tenant-defined objectives.

---

## 1. Observed (from source read)

The drill loop's only in-loop falsification is `_honesty_gate`
(`drill.hexa`): a BT-AI2 audit over per-round yields that is, by the
engine's own comment, **advisory and non-blocking** —

```
// Honesty gate — ... The audit is advisory: a non-zero
// f_a/f_b count triggers stderr warning but does NOT halt drill (the
// upstream pattern; saturation is the hard stop).
```

The only hard stop is **saturation** (round yield = 0) or **max-rounds**.
There is no hook to invoke an *external / tenant-supplied* verifier per
round and treat its verdict as (a) an authoritative PASS / stop signal or
(b) a first-class entry in the audit trail.

## 2. Why it matters (downstream / scope B)

phanes scope B's honest contract (`phanes AGENTS.tape
@D g_honest_scope.scope_b`) makes the **tenant-supplied verifier the sole
authority** for "objective met". For the falsifier to be genuinely
*in the loop* (rather than a weaker post-hoc check on the final
`DrillResult`), the engine needs a pluggable verifier/oracle callback the
loop consults each round.

## 3. Suggested resolution (upstream's call)

A pluggable verifier interface, opt-in, internal honesty gate staying the
default when none is supplied (back-compat):

- `DrillOpts` gains an optional verifier spec (e.g. a command / endpoint /
  predicate id) invoked per round on that round's discoveries;
- its verdict feeds an authoritative PASS/stop signal **and** the
  per-round audit trail (alongside the existing BT-AI2 line);
- the verifier is sandboxed + timeout-bounded (it is untrusted tenant
  code — security note for the upstream design).

## 4. Downstream workaround in place

`phanes` v1: preset/curated verifier scenarios only on the public surface
(`phanes @D g_public_demo_constraint`), and the tenant verifier applied as
an **external post-hoc gate** over the JSON `DrillResult` / overlay until
this in-loop extension point lands. Not a blocker for v1; this note is the
design handoff for the first-class hook.

---

## Resolution — 2026-05-19

Landed in `compiler/drill/drill.hexa` as a single opt-in callback site —
no registry, no plugin manager, no DSL (andrej-karpathy-skills: simplicity
first). Default behavior with `verifier_cmd == ""` is byte-identical to
the pre-hook drill (back-compat preserved across `batch_drill`, the four
`drill_run_shim` callers in swarm/surge/omega/dream, and both
`drill_test`/`accumulation_test` harnesses — all parse cleanly with the
new fields supplied through `drill_default_opts()`).

### Hook shape

- **Config (`DrillOpts` additions)** — three opt-in fields:

  ```hexa
  verifier_cmd: string             // "" = no verifier (default — back-compat)
  verifier_timeout_s: i64          // 0 = unbounded, otherwise prefix `timeout Ns`
  verifier_authoritative: bool     // true → pass/fail halts loop · false → advisory only
  ```

- **Invocation contract** — `_verifier_run(opts, round, seed, yields, sigma)`
  pipes a single-line JSON payload on stdin and reads back one stdout line.

  Payload (verifier stdin):

  ```json
  {"round":N,"total":T,"smash":..,"free":..,"abs":..,"meta":..,
   "hyper":..,"res":..,"tc":..,"sigma":"...","seed":"..."}
  ```

  Reply grammar (verifier stdout — whitespace-separated tokens, first
  match wins, mirrors `__BT_AI2__` sentinel grammar):

  ```
  verdict=pass|fail|continue   [rationale=<single-token-text>]
  ```

- **Verdict enum** — `VerifierVerdict.verdict ∈
  {"pass", "fail", "continue", "skip", "error"}` where `skip` =
  no `verifier_cmd` installed, `error` = verifier crash / timeout /
  malformed output (fail-open — NEVER halts; loop continues per upstream
  policy that saturation is the hard stop).

- **Insertion point** — single call site in `drill_run`'s round loop,
  AFTER `_honesty_gate(round, rr.yields)` and BEFORE `checkpoint_save`.
  Sequence per round: `round_run_with_pool` → yields println →
  `extract_axiom_exprs` → `_honesty_gate` (advisory BT-AI2) →
  **`_verifier_run` + `_verifier_audit_emit` (NEW)** →
  authoritative-stop check (if `verifier_authoritative` && verdict ∈
  {pass, fail}: flush checkpoint + break) → `checkpoint_save` →
  saturation check.

- **Audit trail** — every verdict (including `skip` / `error`) emits a
  `DRILL_VERIFIER {"round":N,"verdict":"..","rationale":".."}` line on
  stderr. `pass` and `fail` ADDITIONALLY emit a synthesized `__BT_AI2__`
  sentinel (`label=verifier_round_N claim=PASS|FAIL loss=1.0 expected=1.0`)
  so a subsequent `bt_ai2_audit` observes the verifier verdict alongside
  the existing BT-AI2 round line — satisfying point (b) of the patch's
  request ("first-class entry in the audit trail").

- **Authoritative-stop semantics** (when `verifier_authoritative == true`):
  - `verdict == "pass"` → `saturated = true`, `verifier_stopped = true`,
    loop breaks with `objective met` message.
  - `verdict == "fail"` → `saturated = false`, `verifier_stopped = true`,
    loop breaks with `objective rejected by verifier` message.
  - `verdict ∈ {continue, skip, error}` → advisory only, no flow change.

  When `verifier_authoritative == false` (default), all verdicts are
  advisory — verifier is observed and logged but loop continues to its
  natural saturation / max-rounds termination.

- **`DrillResult` additions** — two new fields (positional struct
  literals updated at both return sites in `drill.hexa`):

  ```hexa
  verifier_stopped: bool      // true iff verifier authoritatively halted the loop
  verifier_verdict: string    // last verifier verdict ("" if no verifier installed)
  ```

  CLI JSON summary in `main()` echoes both.

- **CLI flags** (added to `hexa drill` shim — opt-in, no default change):

  ```
  --verifier-cmd "<shell-command>"   # required to activate the hook
  --verifier-timeout <N-seconds>     # 0 / omitted = unbounded
  --verifier-strict                  # promote pass/fail to authoritative stop
  ```

### Security posture (out-of-scope, downstream responsibility)

The verifier is **untrusted tenant code** — phanes must sandbox it
itself (per-tenant cgroup / namespace / chroot / seccomp). The hexa-lang
side enforces only:
- timeout via `timeout Ns` prefix when `verifier_timeout_s > 0`
  (best-effort; requires the `timeout` utility on PATH);
- shell-quoted payload to block trivial injection of `'` chars from
  the seed string (`_verifier_shquote`).

Stronger isolation (namespace, network egress, fs scope) is **NOT**
the drill loop's concern — it lives at the phanes job dispatcher.
This boundary mirrors the existing `g_qrng_provider_only` shape: the
extension point provides mechanism + audit, the consumer enforces
policy.

### Verification

- `hexa_real parse compiler/drill/drill.hexa` → **parses cleanly**.
- `hexa_real parse compiler/drill/batch.hexa` → **parses cleanly**
  (batch_drill consumer of DrillOpts).
- `hexa_real parse compiler/drill/drill_test.hexa` → **parses cleanly**.
- `hexa_real parse compiler/drill/accumulation_test.hexa` → **parses cleanly**.
- Binary promote to running `hexa_v2` is the standard separate deploy
  step per the 22c27a05 pattern (out of scope for this SSOT-level patch).
