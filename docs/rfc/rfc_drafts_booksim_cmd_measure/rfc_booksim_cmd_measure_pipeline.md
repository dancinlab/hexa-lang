# RFC draft — `stdlib/booksim` dispatcher `cmd_measure` / `cmd_sweep` pipeline

> **Status: DRAFT — investigation report + honest blocker.**
> Author: Claude Opus 4.7 (1M context), 2026-05-19.
> This is NOT an implementation-complete RFC. It documents what is known,
> what `cmd_measure`/`cmd_sweep` *would* wire, and the **one** spec input
> that is missing and that hexa-lang must NOT invent (g3, `@D g_stdlib_ownership`).

## 1. Task

A downstream consumer — the `demiurge` / `hexa-arch[chip]` project — needs
`stdlib/booksim/` to run a measurement pipeline so it can record gate-measurement
results as an **"F1F2 record"** (the `comb` RFC 057 F1/F2 falsifier inputs).

The requested pipeline (per the dispatcher stub's own header comment, lines
105-112 of `booksim.hexa.stub`):

```
anynet_load -> wire_delay_apply -> sweep_curve -> leighton_check -> emit F1F2-record
```

## 2. What was found — current state

### 2.1 The engine modules are real, complete, and parse-clean

`stdlib/booksim/` contains six **fully-bodied** `.hexa` engine modules, each
with its own `fn main()` self-test, all of which **parse-gate cleanly** under
the pinned toolchain (verified 2026-05-19, `hexa_real parse`):

| module | key API the pipeline needs |
|---|---|
| `anynet.hexa`    | `anynet_load(path) -> AnynetTopology`, `anynet_parse`, `anynet_mesh_8x8_d4_text`, `anynet_hex_8x8_d6_text`, `anynet_diameter_hops`, `anynet_mesh_bisection(t,k)` |
| `wire_delay.hexa`| `wire_delay_profile_lookup(node) -> WireDelayProfile`, `wire_delay_apply(p,links) -> [WireLinkLatency]`, `wire_delay_into_anynet` |
| `iq_router.hexa` | `iq_router_default_config() -> IQRouterConfig`, latency formulae |
| `traffic.hexa`   | `traffic_dest(spec,src)`, `uniform / transpose / tornado` |
| `sweep.hexa`     | `sweep_curve(SweepConfig, [float]) -> SweepCurve` (latency-vs-rate + knee + ZLL) |
| `leighton.hexa`  | `leighton_check(LeightonInput, obs_bisection, obs_diameter) -> LeightonOracle` (analytic no-over-claim gate) |

The pipeline's first four stages — `anynet_load`, `wire_delay_apply`,
`sweep_curve`, `leighton_check` — are therefore **fully implementable today**
in hexa-lang with zero new engine code. `sweep.hexa::main()` already assembles
exactly this chain (`anynet_mesh_8x8_d4_text -> parse -> wire_delay 22nm ->
sweep_curve(uniform) -> leighton_check`) as its self-test (`sweep.hexa` lines
~507+, "§B reproduction harness").

### 2.2 The dispatcher is a deliberate not-yet-buildable stub

The dispatcher is **`booksim.hexa.stub`** — NOT `booksim.hexa`. The `.stub`
suffix is a deliberate signal (README §"File-naming note"): the file is not
buildable and is intentionally **not wired** into `self/main.hexa`. Its
`cmd_measure` returns `90` ("measurement gate not satisfied"), `cmd_sweep`
returns `91` ("TBD body reached"). All six engine modules also have `.stub`
siblings (the old skeletons); the real bodies are the `.hexa` files.

The README and every stub header gate the dispatcher on **"rfc_001 §8 GREEN"**.

## 3. The blocker — F1F2-record format is downstream-owned and ABSENT

The fifth and final pipeline stage — **"emit F1F2-record"** — cannot be honestly
implemented from anything in the hexa-lang repo. Findings:

1. **The RFCs the booksim README cites do not exist in hexa-lang.**
   `stdlib/booksim/README.md` references `proposals/rfc_001_booksim2_noc_absorption.md`,
   `proposals/rfc_002_f1f2_export_interface.md`, `proposals/rfc_003_booksim_native_rederivation_plan.md`.
   The actual `proposals/rfc_001..003` in this repo are unrelated
   (`popen_lines`, `map_methods`, `ansi_escape_literal`). The booksim RFC
   numbering belongs to a **different repo's** proposal tree.

2. **The F1F2-record schema SSOT is `~/core/hexa-arch/`, not hexa-lang.**
   `comb/T1A_analytical.md §8`, `comb/T1_experiment.md`, `comb/sim/README.md`
   all state the contract explicitly and consistently:
   - producer / typed-interface SSOT: `~/core/hexa-arch/proposals/rfc_002_f1f2_export_interface.md`
     (§3 schema · §4 provenance / no-over-claim required fields · §5 path
     convention · §6 semver).
   - human-readable schema doc: `~/core/hexa-arch/exports/chip/noc/f1f2/schema/v1_0.md`.
   - interface type names: `hexa-arch:chip:noc:F1F2-record` (single run) and
     `hexa-arch:chip:noc:F1F2-pair-verdict` (pair-aggregated).
   - carrier: HXC v2 byte-canonical wire (`@D g_hxc`); interim = JSON of the
     same keyset.
   - `comb` is declared the **consumer** of this contract; it explicitly does
     NOT define the schema ("comb 는 contract 의 소비자 — schema 를 정의하지
     않는다").

3. **`~/core/hexa-arch/` is not present on this machine.** The schema doc and
   `rfc_002` cannot be read. Field names, types, the exact `provenance` block,
   semver rules, and the record-id / path convention are therefore unknown.

4. **Only a partial human-rendered keyset exists in-repo** (`comb/T1A_analytical.md §8`
   "§3 RHS quantity → schema field mapping"): `wire_delay_model.{ps_per_mm,
   cycle_period_ps, rc_exponent}`, `wire_delay_model.links[].{length_mm,
   latency_cycles}`, `router_cost.{port_area_norm, port_energy_norm}`,
   `router_cost.iq_pipeline.*`, `latency_curve[]`, `saturation_throughput`,
   `leighton_oracle.{status, bisection_bound, bisection_observed,
   diameter_bound, diameter_observed}`, `verdict.{f1, f2, rationale}`,
   `provenance.{absorbed, consumer_target}`. This is a *citation*, not a typed
   schema — insufficient to emit a byte-correct record.

**Honest conclusion (g3):** the F1F2-record is a `hexa-arch`-defined artifact.
Per `@D g_stdlib_ownership` and `@D g7` (inbox-patches-pipeline / one-way
upstream flow), hexa-lang must NOT invent a downstream-owned wire format.
Emitting a self-invented JSON would be a fabricated artifact that would
silently diverge from the real `rfc_002 §3` schema. **Stage 5 is blocked on a
downstream spec input.**

## 4. What `cmd_measure` / `cmd_sweep` would wire (once unblocked)

### `cmd_sweep` (stages 1-3 — implementable today, no blocker)

```
parse flags: --topology <f> --traffic <uniform|transpose|tornado> --rate <a..b>
t    = anynet_load(topology_path)              // anynet.hexa
prof = wire_delay_profile_lookup(node)         // wire_delay.hexa  (default 22nm)
cfg  = SweepConfig { topology: t, router_cfg: iq_router_default_config(),
                     traffic: TrafficSpec{...}, packet_size:20, ... }
curve = sweep_curve(cfg, parse_rate_range(rate_arg))   // sweep.hexa
print curve.points / curve.knee_rate / curve.zero_load_lat
exit 0
```
`cmd_sweep` does NOT emit an F1F2-record (it is the curve sub-command), so it
is **not blocked** — it can be implemented and measured immediately once the
dispatcher is promoted `.hexa.stub -> .hexa`.

### `cmd_measure` (stages 1-5 — stage 5 blocked)

```
stages 1-4 : anynet_load -> wire_delay_apply -> sweep_curve -> leighton_check
             (all implementable today; LeightonOracle.pass==0 => exit 91,
              "Leighton oracle violated — record MUST NOT be emitted")
stage 5    : emit F1F2-record  <-- BLOCKED: needs hexa-arch rfc_002 §3 schema
```

## 5. Exactly what spec input is missing from the downstream

To unblock stage 5, `hexa-arch` / `demiurge` must supply (via `archive/patches/`,
per `@D g7`) ONE of:

- (preferred) the full `rfc_002 §3` typed schema — every field name, type, and
  unit of `hexa-arch:chip:noc:F1F2-record`, the `provenance` required-field set
  (§4), the record-id / path convention (§5), and the `schema_version` semver
  rule (§6); **or**
- a frozen copy of `exports/chip/noc/f1f2/schema/v1_0.md` placed in hexa-lang
  (e.g. `stdlib/booksim/F1F2_SCHEMA.md`) so the emitter has an in-repo SSOT to
  cite; **or**
- an explicit decision that the F1F2 emitter lives in `hexa-arch` itself and
  `stdlib/booksim` only exposes the typed `SweepCurve` + `LeightonOracle` +
  `WireDelayProfile` structs as the consumed surface (decoupling per
  `comb` RFC 057 §6 T1) — in which case `cmd_measure` would print those
  structs and exit, and `hexa-arch` does the record assembly.

Until then `cmd_measure` correctly exits `90` ("measurement gate not
satisfied — no 'absorbed' claim yet"), which is the stub's current behavior
and the honest state.

## 6. Recommendation

1. **Do not** invent the F1F2-record format in hexa-lang.
2. `cmd_sweep` (stages 1-3) and `cmd_measure` stages 1-4 are implementable
   today and could land in a follow-up cycle that promotes
   `booksim.hexa.stub -> booksim.hexa`, wires `self/main.hexa`, and has
   `cmd_measure` print the intermediate `SweepCurve` + `LeightonOracle` and
   exit `90` (clearly marked "F1F2-record stage pending downstream schema").
   That promotion is intentionally **out of scope of this investigation** —
   the README forbids `self/main.hexa` wiring "until rfc_001 §8 GREEN", and
   that gate is a `hexa-arch`-side decision.
3. File the missing-schema request to `hexa-arch` / `demiurge` so the
   `rfc_002 §3` schema arrives at `archive/patches/` per `@D g7`.

## 7. Honest status summary

| pipeline stage | status |
|---|---|
| `anynet_load`        | engine DONE, parse-clean. dispatcher wiring not landed (stub). |
| `wire_delay_apply`   | engine DONE, parse-clean. dispatcher wiring not landed (stub). |
| `sweep_curve`        | engine DONE, parse-clean (self-tested in `sweep.hexa::main`). dispatcher wiring not landed (stub). |
| `leighton_check`     | engine DONE, parse-clean (analytic g3 oracle). dispatcher wiring not landed (stub). |
| **emit F1F2-record** | **BLOCKED — schema is `~/core/hexa-arch/rfc_002 §3`, absent from this repo. Must NOT be invented (g3, `@D g_stdlib_ownership`).** |

`cmd_measure` returning `90` and `cmd_sweep` returning `91` is, given the open
gate, the **correct and honest** current behavior. No speculative code was
written.
