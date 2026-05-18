# incoming patch: phanes-pluggable-verifier-oracle-for-drill-loop — drill loop has no pluggable external verifier/oracle hook; scope-B (tenant-supplied objective+verifier) needs an in-loop authority for "objective met"

> **id**: `phanes-pluggable-verifier-oracle-for-drill-loop` · **opened**: 2026-05-19 KST · **status**: `reported (downstream phanes — v1 workaround: preset verifiers + post-hoc gate)`
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
