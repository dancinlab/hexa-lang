# 2026-05-12 — atlas absorption Phase 3 closure + interp drift blocker

> Continuation of `2026-05-12-atlas-n6-absorption-session.md`. Same calendar
> day, second session via ubu-1 (ControlMaster) after ubu-2 SSH became
> auth-blocked. Phase 1–3 landed; Phase 4 blocked on a deployed-interp bug.

**Date:** 2026-05-12 (session 2)
**Driver doc:** `doc/atlas_n6_retirement_plan.md` §0b (absorption closure)

## A. Commits this session

```
815d2354 fix(atlas): hexa atlas append-witness — shard format compatible with parser
336ed7bb feat(atlas): hexa atlas append-witness — staging shard writer (Phase 3)
```

(Phase 1 = `b55b9f92`, Phase 2 = `a7d8aaa3` from session 1.)

Phase 3 (write surface) now ships:
- `hexa atlas append-witness --kind P|C|L|E --id <id> {--raw <body> | --stdin} [--emitter <name>] [--dir <staging>]`
- Output filename: `atlas.append.witness-<ts_ms>-<safe_id>.n6`
- Shard format: 5 `//` header lines + **blank line** + body + blank line + `// EOF —` terminator
- Smoke: 3 cases pass via `ubu-1 hexa_interp`, parser round-trip verified

## B. The blank line is load-bearing — deployed interp parser drift

While dogfooding the format on a real round-trip (`append-witness → load_atlas →
lookup`), parsing returned 0 nodes from the new shard. Bisection revealed
a deployed-binary bug:

| leading `//` comments before `@C` | parse_atlas_file result |
|----------------------------------|-------------------------|
| 0 | 1 node ✓ |
| **1** | **0 nodes ✗** |
| 2 | 1 node ✓ |
| **3** | **0 nodes ✗** |
| 4 | 1 node ✓ |
| **5** | **0 nodes ✗** |
| 6 | 1 node ✓ |

Source `compiler/atlas/parser.hexa` is correct (each `_is_comment` branch
just does `i = i + 1; continue`). The bug lives in the deployed
`~/.hx/packages/hexa/build/hexa_interp` — almost certainly the same
parser-state / refcount drift recorded in
`memory/project_sh3_phase2f_interp_drift.md` ("fn-arg map TAG_MAP not
incref'd in env_define").

**Workaround in shard emit:** insert blank line between `//` header block
and the `@`-line body. Both buggy AND fixed interp accept this format.

## C. Bigger blast radius — continuation lines also corrupted (Phase 4 blocker)

After the blank-line fix made round-trip return 1 node, the *content* of
that node was wrong. For input body:

```
@C ANIMA-psi-alpha-corrected = 0.014067 :: math, consciousness [11*]
  <- sopfr, J2, e
  -> psi_constants_cluster
  => "Hc_453 / H_158 — 0.477% claimed-vs-target err …"
  == (sopfr/J₂)^e = (5/24)^e ≈ 0.014067
  |> H_158 Migration Notes Next-step #3 (2026-05-12)
```

`parse_atlas_file(...).raw` returned, after split:

```
@C ANIMA-psi-alpha-corrected = 0.014067 :: math, consciousness [11*]
  <- sopfr, J2, e
  <- sopfr, J2, e          ← DUPLICATE
  => "Hc_453 …"            ← `-> psi_constants_cluster` LOST
  => "Hc_453 …"            ← DUPLICATE
  |> H_158 …               ← `== (sopfr/J₂)^e …` LOST
  |> H_158 …               ← DUPLICATE
// EOF — hexa atlas append-witness   ← terminator pulled in as continuation
```

Pattern: odd-indexed continuation lines duplicate; even-indexed lost. Same
state-drift signature as the leading-comment count bug — but here it
affects the **data payload**, not just node existence.

### Why session 1's Phase 1 regen of 6594 nodes still produced a usable embed

Phase 1 ran `tool/atlas_embed_gen.hexa` on the full 4.2 MB atlas.n6. With
~10K continuation lines across ~6000 nodes, the drift pattern produces
some duplicate-and-skip pairs that *happen* to roughly preserve raw
*length* and *hashable bytes* in aggregate, so the smoke (`stats` →
6594 nodes, hash `663698a0…`) PASSes but individual node `raw` fields
are silently corrupted. This was not detected in session 1 because the
`hash` smoke only checks file digest, not semantic equivalence of node
content. The 6594-node embed currently shipped in
`compiler/atlas/embedded.gen.hexa` has the same corruption pattern in
every multi-line node's raw body.

## D. Phase 4–8 prerequisite

Migrating nexus writers (`witness_emit.hexa`, `omega_cycle_atlas_ingest.hexa`,
…) to emit shards through `hexa atlas append-witness`, then re-regenning
the embed, will **propagate corrupted body data** into the embedded SSOT
on every cycle. Until the interp is re-promoted from current source
(which has the `file_size` fix `150e0220` AND correct parser semantics),
Phase 4+ is unsafe.

**Required prerequisite cycle:** rebuild `~/.hx/packages/hexa/build/hexa_interp`
from current `self/hexa_full.hexa` source. This is the same `build(stage0):
re-promote hexa_interp` cycle already deferred from session 1 (see
`incoming/notes/2026-05-12-atlas-n6-absorption-session.md` §D).

## E. Session 2 cleanup state

- 1 corrupt shard was written to `~/core/nexus/n6/` during dogfood;
  **removed** via `rm` (the same ANIMA-psi-alpha-corrected data still
  exists in nexus uncommitted `M n6/atlas.n6` as the source of truth).
- No nexus repo changes committed (no atlas.n6 inline-merge removal,
  no witness_emit port, no atlas.n6 deletion).
- hexa-lang working tree: clean (4 commits ahead).

## F. Continuity hooks

- Memory entry `project_sh3_phase2f_interp_drift` already captures the
  root cause. Add cross-link to this note.
- Memory entry `project_atlas_absorption_phase4_blocked` (NEW) should
  flag this prerequisite for any future session that wants to continue
  Phase 4–8.
- Retirement plan `doc/atlas_n6_retirement_plan.md` §0b should record
  Phase 4–8 = `BLOCKED until hexa_interp re-promote`.
