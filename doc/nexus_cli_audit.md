# Nexus CLI → hexa-lang Compiler Mapping Audit

> Source: background discovery agent (Task #52). Captured 2026-05-09.
> Discovery only — no code changes applied.

## TL;DR

**9 / 12 (75%) of nexus atlas/check/verify/discover commands are absorbable into hexa-lang's `compiler/` tree.** RFC-018 zero-external-dependency principle is reachable for the full atlas/check workflow; only 3 commands need external dependency carry-over (lint rules, sync drift, atlas-append write policy).

## 1. Discovered nexus CLI surface

From `~/core/nexus/bin/`, `engine/nexus_cli.hexa`, and shell wrappers:

1. **atlas** — `search` / `append` (atlas.n6 query / add)
2. **check** — domain health (router → ~30 `check_*.hexa` modules)
3. **discovery** — `query` (discovery_log.jsonl)
4. **verify** — `v-const` / `sync-diff` / `atlas` (3 modes via `tool/verify.hexa`)
5. **atlas3d** — `publish` / `serve` / `watch` / `shard` / `snapshot` / `overlay` / `theorem` / `tail` / `query` / `diff` / `audit`
6. **hexa-catalog** — source-annotation extraction
7. **roadmap** — `list` / `status`
8. **bus** — `publish` / `tail` (event broadcast)
9. **drill / smash / free / lens / qmirror / bio / sim / qrng / mc** — out-of-scope today

## 2. hexa-lang `compiler/` tree existing modules

| Path | Purpose | Status |
|---|---|---|
| `compiler/atlas/static_index.hexa` | static atlas index | v0.1 (real fixture in `embedded.gen.hexa`) |
| `compiler/atlas/parser.hexa` | atlas.n6 line parser | done |
| `compiler/atlas/merger.hexa` | shard merger + lookup | done |
| `compiler/atlas/embed.hexa` | const-array embed codegen | done |
| `compiler/check/{resolve,bind,types,units,citation,annotations,equational}.hexa` | S1–S6, S8 strict lint | done |
| `compiler/discover/{discover,staging,promote,tombstone,retroactive_sweep,cascade}.hexa` | ε self-proof full cycle | done |

## 3. Mapping table — nexus → hexa CLI

| nexus command | source | role | absorbable | proposed hexa CLI | effort | priority |
|---|---|---|---|---|---|---|
| `atlas search` | `engine/nexus_cli.hexa` | grep atlas.n6 | full | `hexa atlas lookup <query>` | S | **P0** |
| `check atlas` | `tool/check_atlas.hexa` | entry counts via wc/grep | full | `hexa check atlas` | S | **P0** |
| `atlas3d audit` | `bin/atlas3d` | integrity report | full (parser only) | `hexa atlas audit` | S | **P0** |
| `atlas3d query` | `bin/atlas3d` | DSL filter | full | `hexa atlas query <expr>` | M | P1 |
| `verify atlas` | `tool/verify.hexa` | formula/orphan checks | full (atlas_health.hexa pattern) | `hexa verify atlas` | M | P1 |
| `discovery query` | `engine/nexus_cli.hexa` | scan `discovery_log.jsonl` | full | `hexa discover query <filter>` | M | P1 |
| `atlas3d publish` | `bin/atlas3d` | docs/atlas3d sync | full (mirror/version) | `hexa atlas publish --root` | M | P2 |
| `atlas3d serve` | `bin/atlas3d` | localhost:8080 | full | `hexa atlas serve --port` | S | P2 |
| `atlas3d snapshot` | `bin/atlas3d` | 3D coords JSON | full (deterministic) | `hexa atlas snapshot` | M | P2 |
| `atlas3d diff` | `bin/atlas3d` | git ref↔ref delta | full (git CLI shell-out) | `hexa atlas diff <a> <b>` | S | P2 |
| `verify v-const` | `tool/verify.hexa` | lint V-CONST rules | partial (depends on lint.hexa) | `hexa verify v-const` | M | P1 (deps carry) |
| `verify sync-diff` | `tool/verify.hexa` | hash drift | partial (sync.hexa external) | `hexa verify sync-diff` | M | P1 (deps carry) |
| `atlas append` | `engine/nexus_cli.hexa` | write JSON node/edge | partial (write policy) | `hexa atlas append --node/--edge` | L | P2 (caution) |

## 4. Implementation order

**P0 (immediate):**
1. `hexa atlas lookup <query>` — grep over `static_atlas()` index
2. `hexa check atlas` — entry counts + node-shape validation
3. `hexa atlas audit` — integrity report (hash drift, missing edges, orphan check)

**P1 (week):**
4. `hexa atlas query <expr>` — DSL filter (small parser for `kind:P AND name~/^einstein/`)
5. `hexa verify atlas` — formula soundness + orphan detection
6. `hexa discover query <filter>` — scan discovery_log.jsonl

**P2 (month):**
7. `hexa atlas publish` — docs/atlas3d/ mirror generator
8. `hexa atlas snapshot` — 3D coords (deterministic from hash)
9. `hexa atlas diff <a> <b>` — git ref-to-ref delta
10. `hexa verify {v-const,sync-diff}` — carry external deps OR migrate

## 5. Architectural shape — `hexa` CLI dispatch

`compiler/main.hexa` already accepts `--target`, `--emit`, `--opt`, etc. Subcommand dispatch model:

```
hexa <subcmd> [args...]
  build  | run  | repl    — language-level (current main.hexa)
  atlas  | check | verify | discover | catalog
                          — nexus-absorbed
```

Refactor: `compiler/cli/dispatch.hexa` (new) routes `argv[0]` subcommand to the right module. Existing `compiler/main.hexa` stays as `hexa build/run` entry; new modules `compiler/cli/{atlas,check,verify,discover}.hexa` handle the rest.

## 6. Unresolved / ambiguous

- `nexus promote` (mentioned in some places, no clear source)
- `nexus discover retroactive-sweep` (CLI surface unclear; module exists at `compiler/discover/retroactive_sweep.hexa`)
- `nexus bus publish/tail` — event broadcast layer; orthogonal to atlas/check, may stay external

## 7. Recommended first-PR scope

`hexa atlas lookup` only. Smallest possible — grep over `static_atlas()` const index (zero filesystem read, zero external dep), verifies the dispatch architecture works. Once landed, P0 #2/#3 follow same pattern.

```
$ hexa atlas lookup einstein
P[einstein-mass-energy]    physics    M·L²·T⁻²
L[einstein-equations]      physics    G_μν = κT_μν
```
