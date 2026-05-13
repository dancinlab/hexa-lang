# 2026-05-13 — Phase 2 verifier port session (A3 / A4 / A7)

Three deterministic verifiers ported from nexus into hexa-lang under the
γ-policy (return-only, no atlas/log writes). All three smoke tests pass.

## A3 — `check` (BT-AI2 honesty)

**Target:** `compiler/honesty/`

**Sources read:**
- `~/core/nexus/engine/nexus_cli.hexa` (cmd_check, bt_ai2_audit_run,
  _bt_ai2_observe, _bt_ai2_verdict, thresholds — lines ~1118–1320)
- `~/core/nexus/tool/check_router.hexa` (16-domain dispatcher)
- `~/core/nexus/tool/check_physics.hexa` (dim/cons/anchor/codata/planck/lorentz)
- `~/core/nexus/tool/check_hexalint.hexa` (delegator → tree-sitter-hexa
  `lints_via_treesitter.hexa`)

**Files:**
- `compiler/honesty/check.hexa` (239 LOC) — `bt_ai2_audit(raw) →
  Bt2Verdict`, `bt_ai2_audit_lines(lines) → Bt2Verdict`,
  `bt_ai2_falsifier_registry_size() → i64`. Mirrors the upstream
  `__BT_AI2__` sentinel parser + F-AI2-A / F-AI2-B audit. Thresholds
  pinned as `pub let` constants (0.05 / 0.01). No `eprintln`, no atlas
  append — verdict struct only.
- `compiler/honesty/physics.hexa` (170 LOC) — `physics_check() →
  PhysicsVerdict`. Ports dimensional analysis (6 tests) and
  conservation (4 tests) in-process.
- `compiler/honesty/hexalint.hexa` (214 LOC) — `hexalint_check(source)`
  + `hexalint_check_files(blobs)` grep-MVP with three rules
  (HL001 empty-body fn, HL002 unused-mut, HL003 tab/space mix).
- `compiler/honesty/router.hexa` (128 LOC) — `honesty_router_run(domains,
  source) → RouterVerdict` fan-out over the upstream 16-domain catalog.
- `compiler/honesty/check_test.hexa` (126 LOC, smoke).

**Deferred:**
- `anchor` / `codata` / `planck` / `lorentz` (physics sub-checks) —
  upstream wraps four sim_bridge / network-dependent helpers. Each
  registered as a domain name but returns SKIP; production wiring lands
  with the Phase 3 I/O capability boundary.
- `bio` / `sim` / `qrng` / `brain` / `consciousness` / `phi` / `learning`
  / `phenomenology` / `law` / `integrity` / `meta` / `atlas` / `device`
  (13 of 16 domains) — each backed by a separate `check_<dom>.hexa`
  module; pulling them in would balloon the absorption surface.
  Router registers the names; status = SKIP for all 13.
- Hexalint AST backend — current MVP is scanner-grade (3 rules). The
  upstream tree-sitter query pack is left intact in nexus; once
  `self/parser.hexa` exposes a programmatic AST-query API we can swap
  the scanner for a native walk.
- Witness emit (`atlas.append.honesty_bit-*.n6`) — γ policy. Phase 3
  absorb pipeline will materialize verdict → atlas shard.

**Smoke:** 24/24 PASS.

## A4 — `absolute` (Δ₀ verifier)

**Target:** `compiler/absolute/`

**Sources read:**
- `~/core/nexus/cli/run.hexa::cmd_absolute` (thin dispatch — line 375)
- `~/core/nexus/cli/blowup/modules/blowup_absolute.hexa` (Mk.VIII full
  algorithm — 158 LOC, the entire 5-phase pipeline)

**Files:**
- `compiler/absolute/check.hexa` (148 LOC) — `absolute_check(seed) →
  AbsoluteVerdict`, plus `is_arithmetical(expr)`,
  `verify_transitive(prop)`, `cross_axis_verify(prop)`,
  `absolute_should_promote_11(line)`. Mirrors A1/A2/A3/A4/A5 pipeline.
  D2 hexad + D4 absolute_rules registries probed for provenance count
  in the verdict struct.
- `compiler/absolute/check_test.hexa` (115 LOC, smoke).

**Deferred:**
- Atlas write on promotion (`@R [10*] → [11*]` rewrite) — γ policy.
  Verdict struct exposes `promoted: bool` + `grade: i64` for the
  absorb pipeline to action.
- The upstream `NEXUS_ENGINE_DEAD/ERROR/WARN` JSON eprintln signals
  (used by the run.hexa drill harness) — purely operational telemetry,
  not part of the verifier contract. Skipped.

**Smoke:** 23/23 PASS.

## A7 — `meta-closure` (Phase 10 fixed-point)

**Target:** `compiler/meta_closure/`

**Sources read:**
- `~/core/nexus/cli/run.hexa::cmd_meta_closure` (dispatch — line 5350)
- `~/core/nexus/cli/blowup/modules/blowup_meta_closure.hexa` (591 LOC,
  the Mk.IX algorithm — M1 param load / M2 collect / M3 trace+heuristic
  / M4 atlas flush / M5 report)
- `~/core/nexus/cli/blowup/design/phase10_meta_closure.md` (design
  spec — read for H1/H2/H3 semantics)

**Files:**
- `compiler/meta_closure/heuristics.hexa` (225 LOC) — helper surface:
  `parse_disc_line`, `find_disc_by_id`, `sector_of_id`,
  `count_distinct_sectors`, `trace_generation_path` (cycle-safe),
  `n6_invariance_preserved`, `self_at_depth`.
- `compiler/meta_closure/check.hexa` (144 LOC) — `meta_closure_check
  (discoveries) → MetaClosureVerdict`,
  `meta_closure_check_params(discoveries, params) →
  MetaClosureVerdict`, `meta_closure_default_params() →
  MetaClosureParams`. H1 (trace depth ≥ 3) + H2 (self_at_depth ≥ 3 &
  distinct sectors ≥ 2) + H3 (n=6 invariance preserved within ε=1e-9).
- `compiler/meta_closure/check_test.hexa` (135 LOC, smoke).

**Deferred:**
- M1 SSOT param JSON loader (`meta_closure.json`) — upstream reads a
  flat-key JSON via shell; hexa-lang port exposes
  `MetaClosureParams` directly and lets callers override. A JSON
  loader can be added later behind `stdlib/json` once the parser is
  wired here.
- M2 wave_out tail merge — upstream collects child-session corollaries
  from `shared/.wave_out.log.*`. The verdict accepts a pre-built
  discovery list; the tail-merge helper is a thin shell wrapper that
  belongs in the absorb pipeline.
- M4 atlas flush — γ policy. `MetaClosureVerdict.edges` exposes ready
  `MetaClosureEdge` rows (from_id / to_id / closure_depth / value /
  n6_invariant) for downstream `@E meta_self_ref` materialization.
  No file write here.

**Smoke:** 21/21 PASS.

## Totals

- 10 new files across 3 directories (3 main + 1 helper + 1 router + 2
  helpers + 3 smoke).
- 1644 LOC.
- 68 smoke checks PASS (24 + 23 + 21), 0 FAIL.

## γ-policy enforcement

- No `write_file` / `append_file` calls in any verifier module.
- No `eprintln` or stderr alert emission (upstream cmd_check / blowup_*
  modules eprintln on violation — that surface is owned by the Phase 3
  absorb pipeline).
- No `exec` shell-outs for sub-tool dispatch — upstream's
  `check_router.hexa` fans out via `hexa run` exec; the port keeps the
  dispatch table but only wires in-process backends.
- All three verdict structs carry the data the absorb pipeline needs
  (alerts list / promoted bool / edges array) so persistence is a
  pure consumer of these returns.

## Hard-constraint audit

- `self/main.hexa` untouched (git diff empty).
- `compiler/atlas/` `compiler/falsifiers/` `compiler/hexad/`
  `compiler/absolute_rules/` untouched (git diff empty).
- `tool/hexa_annot/` untouched.
- Nexus repo read-only — no edits.
- English-only code/comments throughout the new modules.
- No git commit performed.

## Phase 2 verifier status

Complete for the verifier subset (A3 / A4 / A7). All three ship with
in-process pure backends matching the upstream contract under γ policy.

## Blockers for generator BG (smash / free / hyperarithmetic)

None from this port. Notes for the next BG:

- The `MetaClosureEdge` row shape is suitable as a generator output for
  Phase 3 `@E meta_self_ref` atlas absorb. Generators producing
  candidate discoveries should emit the same tab-format string
  (`id\ttype\texpr\tconf\tvalue\taxiom\tsrc`) so they round-trip through
  `meta_closure_check`.
- `absolute_should_promote_11` is the public predicate generators
  should consult before tagging a generated rule `[11*]`.
- `bt_ai2_audit_lines` accepts a pre-split array — generator harnesses
  can stream their `__BT_AI2__` token batches without round-tripping
  through `"\n".join` then `split("\n")`.
