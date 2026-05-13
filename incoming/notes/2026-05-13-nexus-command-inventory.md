# Nexus Command Surface Inventory

```
generated_at:        2026-05-13T21:37:09Z (UTC)
source commits:
  cli/run.hexa                  c3d29567 2026-05-12
  engine/nexus_cli.hexa         c3d29567 2026-05-12
  engine/nexus_cli_spec.json    4a3a34db 2026-05-13
methodology:         grep cmd_* + sub == "X" dispatch + bash usage() headers
catalog scope:       4 entry-point layers, every verb reachable from a hexa interpreter
```

## Abstract

Five distinct command surfaces converge on the user-visible `nexus` brand: (1) `engine/nexus_cli.hexa` exposes ~32 hive-facing verbs with audit-log + caller tracking, (2) `cli/run.hexa` exposes ~50 top-level verbs with 200+ second-level branches — by far the largest internal surface, (3) seven `bin/` standalone bash/python wrappers handle launchd / app-lifecycle / Hetzner offload, (4) 28 `bin/hexa-*` scripts are pure-grep annotation extractors (clear absorption candidates), and (5) the spec sidecar `nexus_cli_spec.json` enumerates exactly **19 hive-public verbs**, leaving roughly **60+ verbs undocumented** to outside callers. Surprising findings: `nexus check` and `nexus kick` are entirely absent from the spec despite being the two most-cited recent governance entries; `nexus honesty` is dead (deprecated 2026-05-06, absorbed into `check` as BT-AI2 auto-audit); `nexus solve` is also dead (delegated to `hxq solve` in hexa-lang); `kick run` has a **hard-fail Mac fallback ban** from raw 40+42 + 2026-04-29 user directive.

---

## 0. Entry Point Layers — at a glance

| Layer | Path | LOC | Top-level verbs | Notes |
|---|---|---:|---:|---|
| L1 spec sidecar | `engine/nexus_cli_spec.json` | 903 | 19 | hive-facing SSOT (v0.4.0, schema_v2). Only public surface. |
| L2 nexus-cli engine | `engine/nexus_cli.hexa` | 1606 | 32 | bash wrapper `bin/nexus-cli`. v1 + v2 (read-only project surface). |
| L3 nexus runtime | `cli/run.hexa` | 7508 | ~50 | hx package entry: `nexus`. The deep surface. |
| L4a infra bash | `bin/{nexus-cli, nx, atlas3d, drill_htz, …}` | 7 files | 7 own verbs | launchd / app installer / hetzner offload / atlas3d publisher |
| L4b hexa-* analyzers | `bin/hexa-*` | 28 files | 28 own verbs | pure-grep annotation extractors. Trivial absorption candidates. |

**Total unique top-level verbs across L1+L2+L3:** ~70 (deduplicated).
**Verbs reachable but missing from spec:** ~50.
**Spec-exposed verbs that are pure delegations (no nexus-specific code):** `qmirror`, `sim`, `bio`, `qrng`, `mc` — all are thin shells to standalone repos.

---

## 1. Layer L1 — `engine/nexus_cli_spec.json`  (19 hive-public verbs)

Bare enumeration (full schema is in the spec; not re-quoted here):

| spec key | category | desc one-liner |
|---|---|---|
| `thinking` | reflection | anima 6-phase reflection |
| `smash` | discovery | blowup 9-phase 돌파 (gate + remote-routing) |
| `free` | discovery | compose 5-module DFS (gate + remote-routing) |
| `absolute` | discovery | Mk.VIII Δ₀-absolute Π₀¹ (remote-routing) |
| `drill` | discovery | 6-stage chain to saturation (remote-routing) |
| `meta-closure` | discovery | Phase 10 🛸16 self-ref (remote-routing) |
| `hyperarithmetic` | discovery | Mk.IX Π₀² reverse-math (remote-routing) |
| `promote` | governance | manual grade promotion (audit-log required) |
| `lens` | search | lens registry search |
| `atlas` | search/append | `search`, `append` subcmds |
| `discovery` | search | `discovery query "…"` |
| `roadmap` | read | `list`, `status` per project |
| `bus` | event | `publish`, `tail`, `history` |
| `status` | health | aggregate harness/health |
| `version` | meta | print version |
| `gap` | health | gap_monitor 1-shot |
| `projects` | meta | enumerate 7 projects |
| `qmirror` | physics | 6-subcmd CHSH/IIT/NIST/QRNG/selftest router |
| `sim` | physics | 7-subcmd sim-universe shellout |

**Plus three v2 (schema_v2) project surfaces** — `status-proj`, `roadmap-proj`, `convergence-proj`.
**Plus five `subcmds_raw99_cli_coverage`** — `raw triad`, `hexa-only`, `english-only`, `ai-config-ban`, `deprecated-ban`.
**Plus the `check` block** in `subcmds_check` — note: `check` IS in the spec but in its own block, not in the main `subcommands` map. (Caller easy-miss.)

So strictly: **19 verbs in `subcommands` + 3 in `subcmds_v2` + 5 in `raw99` + 1 (`check`) = 28 spec-documented entries**. Initial 19-count was an undercount of one section; even with this correction, ~50 additional verbs reachable via L2/L3 are undocumented.

---

## 2. Layer L2 — `engine/nexus_cli.hexa` (1606 lines, audit-log dispatcher)

Bash wrapper: `~/core/nexus/bin/nexus-cli`. Sub-routing into `subcmd_help(sub)` + main `else if` chain @ line ~1469.

### 2.1 Discovery / verification (gated, with remote_routing)

| name | dispatcher | usage | role | nested subcmds | flags | status | spec | absorption |
|---|---|---|---|---|---|---|---|---|
| `thinking` | `cmd_thinking` L181 | `nexus-cli thinking --query "..."` | anima 6-phase reflection, audit-logged | – | `--query`, `--depth` | active | ✓ | ❌ remote routing |
| `smash` | `cmd_smash` L202 | `nexus-cli smash --seed "..." [--batch] [--depth]` | blowup 9-phase, gate enforced | `single`/`batch` mode | `--seed`, `--batch`, `--depth`, `--seeds` | active | ✓ | ❌ remote routing |
| `free` | `cmd_free` L255 | `nexus-cli free --seed "..."` | compose DFS | `single`/`batch` | `--seed`, `--batch`, `--dfs` | active | ✓ | ❌ remote routing |
| `absolute` | (delegated to run.hexa) | `nexus-cli absolute [--seed]` | Δ₀-absolute Π₀¹ | – | `--seed` | active | ✓ | ❌ remote routing |
| `drill` | passthrough → `run.hexa` | `nexus-cli drill --seed "..." [--max-rounds]` | 6-stage chain | – | `--seed`, `--max-rounds` | active | ✓ | ❌ remote routing |
| `meta-closure` | passthrough → `run.hexa` | `nexus-cli meta-closure [--seed]` | Phase 10 closure | – | `--seed` | active | ✓ | ❌ remote routing |
| `hyperarithmetic` | passthrough → `run.hexa` | `nexus-cli hyperarithmetic --prop "..."` | Π₀² reverse-math | – | `--prop` | active | ✓ | ❌ remote routing |
| `promote` | passthrough → `run.hexa` | `nexus-cli promote --id ... --grade ...` | manual grade promotion | – | `--id`, `--grade`, `--audit-log` | active | ✓ | ❌ writes atlas |

### 2.2 Search / event / project read

| name | dispatcher | usage | role | nested | status | spec | absorption |
|---|---|---|---|---|---|---|---|
| `lens` | `cmd_lens` L299 | `nexus-cli lens --query "..."` | lens registry search | – | active | ✓ | ★★★★ read-only, static deps |
| `atlas` | `cmd_atlas` L335 | `nexus-cli atlas <search\|append>` | atlas.n6 search/append | `search`, `append` | active | ✓ (partial) | ❌ append writes atlas |
| `discovery` | `cmd_discovery` L395 | `nexus-cli discovery query "..."` | SQLite discovery_log query | `query` | active | ✓ | ★★★ live SQL but read-only |
| `roadmap` | `cmd_roadmap` L439 | `nexus-cli roadmap <list\|status>` | roadmap read | `list`, `status` | active | ✓ | ★★★★ static JSON read |
| `bus` | `cmd_bus` L461 | `nexus-cli bus <publish\|tail\|history>` | event bus | `publish`, `tail`, `history` | active | ✓ | ❌ publish writes shared state |
| `status` | `cmd_status` L498 | `nexus-cli status [--json]` | full harness/health aggregate | – | active | ✓ | ★★★ live state dashboard |
| `version` | `cmd_version` L713 | `nexus-cli version` | print VERSION | – | active | ✓ | ★★★★★ pure read |
| `status-proj` | `cmd_status_proj` L577 | `nexus-cli status-proj <project>` | per-project health (v2) | – | active | ✓ (v2) | ★★★★ static JSON |
| `roadmap-proj` | `cmd_roadmap_proj` L632 | `nexus-cli roadmap-proj <p> [next\|list]` | per-project roadmap | – | active | ✓ (v2) | ★★★★ static JSON |
| `convergence-proj` | `cmd_convergence_proj` L671 | `nexus-cli convergence-proj <p>` | convergence snapshot | – | active | ✓ (v2) | ★★★★ static JSON |

### 2.3 Physics-runtime delegates (thin shellouts to standalone repos)

| name | dispatcher | usage | delegates to | spec | absorption |
|---|---|---|---|---|---|
| `qmirror` | `cmd_qmirror` L924 | `nexus-cli qmirror <sub>` | `cli/qmirror.hexa` → modules/qmirror/*.hexa | ✓ | ❌ live QPU / vendor SDK |
| `sim` | `cmd_sim` L970 | `nexus-cli sim <sub>` | external `sim-universe` repo (4-tier resolution) | ✓ | ❌ external repo SSOT |
| `bio` | `cmd_bio` L947 | `nexus-cli bio <sub>` | `cli/bio.hexa` → hexa-bio standalone shellout | ✗ (in help only) | ❌ external repo SSOT |
| `qrng` | `cmd_qrng` L1021 | `nexus-cli qrng <sub>` | `cli/qrng.hexa` standalone | ✗ | ❌ live ANU calls |
| `mc` | `cmd_mc` L1039 | `nexus-cli mc <sub>` | `cli/mc.hexa` Monte-Carlo standalone | ✗ | ❌ heavy compute |

### 2.4 Governance / lint (raw 99 cross-repo)

| name | dispatcher | backend | spec | absorption |
|---|---|---|---|---|
| `raw triad` | `cmd_raw_triad` L1089 | `../hexa-lang/tool/triad_lint.hexa` | ✓ | ★★★ cross-repo |
| `hexa-only` | `cmd_hexa_only` L1096 | `../hexa-lang/tool/hexa_only_lint.hexa` | ✓ | ★★★ cross-repo |
| `english-only` | `cmd_english_only` L1101 | `../hive/tool/english_only_lint.hexa` | ✓ | ★★★ cross-repo |
| `ai-config-ban` | `cmd_ai_config_ban` L1106 | `../hive/tool/ai_config_ban_lint.hexa` | ✓ | ★★★ cross-repo |
| `deprecated-ban` | `cmd_deprecated_ban` L1111 | `../hive/tool/deprecated_ref_scanner.hexa` | ✓ | ★★★ cross-repo |

### 2.5 Special — the honesty deprecation + the `check` dispatcher

| name | dispatcher | status | spec | absorption |
|---|---|---|---|---|
| `honesty` | `cmd_honesty` L995 | **dead** — prints deprecation + `exit(0)`. Absorbed 2026-05-06 into `cmd_check` BT-AI2 audit (F-AI2-A / F-AI2-B). | ✗ | ❌ keep stub for one cycle |
| `check` | `cmd_check` L1198 | **active, master multi-domain verifier** — see §6 deep-dive | ✓ (own block) | ❌ multi-domain governance |

### 2.6 Global flag

| flag | dispatch | semantics |
|---|---|---|
| `--catalog` | `cmd_catalog` L1387 | dumps `nexus_cli_spec.json` to stdout, exits before any sub-routing |

---

## 3. Layer L3 — `cli/run.hexa` (7508 lines, the deep surface)

Main dispatcher: `fn main()` at line 7088 → sub at `a[2]`. Top-level `if sub == "X"` branches at lines 7114–7504.

### 3.1 Trivial meta (help / status / introspection)

| name | dispatcher | role | spec | absorption |
|---|---|---|---|---|
| `version` | `cmd_version` L232 | print version line | ✓ | ★★★★★ pure |
| `help` / `-h` / `--help` | `cmd_help` L236 | multi-page help | ✗ | ★★★★★ pure |
| `status` | `cmd_status` L333 | run_entry status | ✓ | ★★★ live state |
| `self-check` | `cmd_self_check` L6834 | run_entry self_check | ✗ | ★★★ live harness probe |
| `gap` | `cmd_gap` L6830 | run_entry gap_monitor | ✓ | ★★★ live state |
| `doctor` | `cmd_doctor` L7038 | `[--remote] [--all] [--host] [--timeout]` SSH probe of ubu/ubu2 dispatch hosts | ✗ | ❌ remote SSH |
| `contracts` | `cmd_contracts` L319 | dump integration_contracts.json | ✗ | ★★★★★ pure cat |
| `verify` | `cmd_verify` L323 | I1..I10 invariants | ✗ | ★★★★ static checks |
| `sync` | `cmd_sync` L327 | spec ↔ cmd_* drift detect; `--apply` writes | ✗ | ★★ writes spec |

### 3.2 Discovery engine family (L0…L11 ladder)

Authoritative grade per `cmd_help` lines 244–283.

| name | dispatcher | role (one-line) | level | key flags | absorption |
|---|---|---|---|---|---|
| `thinking` | `cmd_thinking` L343 | anima 6-phase reflection | L1 | `--query` | ❌ remote |
| `smash` | `cmd_smash` L351 | blowup 9-phase 돌파 | L1 | `--seed`, `--depth` | ❌ remote |
| `free` | `cmd_free` L363 | compose DFS 탐색 | L1 | `--seed`, `--dfs` | ❌ remote |
| `absolute` | `cmd_absolute` L375 | Mk.VIII Δ₀-absolute Π₀¹ | L2 | `--seed` | ❌ remote |
| `drill` | `cmd_drill` L3087 | 6-stage chain (smash→free→absolute→meta-closure→hyperarithmetic→resonance) | L3 | `--seed`, `--max-rounds`, `--engine mk9\|mk10`, `--preset fast\|probe\|coarse\|standard`, `--depth N\|auto`, `--smash-depth`, `--free-dfs`, `--abs-depth`, `--meta-depth`, `--hyper-depth`, `--res-depth`, `--adaptive`, `--speculate N`, `--fresh`/`--no-resume`, `--checkpoint-dir`, `--anti-hub`, `--anti-hub-threshold`, `--problem riemann\|bsd\|hodge\|navier\|pnp\|poincare\|yangmills`, `--seeds`, `--seeds-file` | ❌ remote, anti-hub axiom write |
| `drill-daemon` | `cmd_drill_daemon` L5283 | long-running daemon (FIFO /tmp/nexus_drilld.sock); E11 Phase 1 MVP | – | sub: `start`/`stop`/`status`/`send`; `--req '<json>'` for raw NDJSON | ❌ process lifecycle |
| `debate` | `cmd_debate` L383 | AQ N-variant adversarial drill (L3 axis); delegates `cli/drill/adversarial_debate.hexa` | L3 | `--seed`, `--variants N`, `--arbitrate`, `--base-depth`, `--max-rounds`, `--engine`, `--preset` | ❌ heavy compute |
| `chain` | `cmd_chain` L7058 | W cross-engine chain (nexus→anima); shim consumes /tmp/nexus_drill_last_total.txt | L3 | `--seed`, `--engines nexus,anima`, `--report <path>` | ❌ cross-engine |
| `dream` | `cmd_dream` L4373 | L5 self-seed loop, `seed_(i+1)=f(output_i)` | L5 | `--seed`, `--iterations`, plus all drill flags | ❌ heavy compute |
| `reign` | `cmd_reign` L4465 | L6 autonomous — auto-STOP on signal stagnation K=2 | L6 | `--seed`, `--max-cycles` | ❌ heavy |
| `swarm` | `cmd_swarm` L4593 | L7 ecology — N×G evaluation, top-2 elite + breeding | L7 | `--seed`, `--population`, `--generations` | ❌ heavy |
| `wake` | `cmd_wake` L4762 | L8 reality-loop — fingerprint-based external signal firing | L8 | `--seed`, `--signal-file`, `--max-cycles` | ❌ writes state |
| `molt` | `cmd_molt` L4850 | L9 self-rewrite — skin (depth × fast) sweep, best skin persisted (`NEXUS_MOLT_SKIN_FILE`) | L9 | `--seed`, `--max-cycles` | ❌ writes skin file |
| `forge` | `cmd_forge` L4985 | L10 bootstrap — synthesize seed from self-state, dispatch drill apex | L10 | `--seed`, `--max-rounds` | ❌ depends on molt skin |
| `canon` | `cmd_canon` L5080 | L11 transfinite seal — write current self-state to `state/canon_seal.jsonl` (closure of ladder) | L11 | `--seed`, `--note` | ❌ writes seal log |
| `surge` | `cmd_surge` L4176 | L4 super-orchestrator — Cartesian product (engines × variants × seeds), cap `NEXUS_SURGE_MAX=12` | L4 | drill flags + `--variants`, `--engines`, `--seeds`, `--seeds-file` | ❌ orchestration |
| `omega` | `cmd_omega` L4063 | **L_ω apex (main entry)** — apex preset (depth=auto, speculate=3, adaptive=on) + auto L3-axis dispatch | L_ω | drill flags + `--engines`, `--variants`, `--seeds`, `--seeds-file` | ❌ apex orchestrator |
| `revive` | (inline shim) | engines+maps v2 infinite loop; delegates `cli/revive/revive.hexa` | – | `--max-iter N`, `--apply`, `--quiet` | ❌ writes |
| `solve` | (inline shim) | **dead** — deprecated, delegates to `hxq solve` (hexa-lang) or prints guidance | – | `--route "<problem>"` | ❌ moved out |
| `canary` | (inline) | L1/L4 verdict direct call; delegates `tool/canary_drill.hexa` | – | passthrough | ❌ heavy probe |
| `omega-monitor` | (inline) | raw 71 falsifier monitor — `hive_test_latency` ω-cycle; delegates `tool/raw81_omega_cycle_monitor.hexa` | – | `check`/`report`/`status` | ❌ live state |
| `meta-closure` | `cmd_meta_closure` L5350 | Phase 10 closure (single-shot) | L2 | `--seed` | ❌ remote |
| `hyperarithmetic` | `cmd_hyperarithmetic` L5357 | Π₀² reverse-math (single-shot) | L2 | `--prop` | ❌ remote |
| `promote` | `cmd_promote` L5367 | manual grade promotion via atlas_health.hexa | – | `--id`, `--grade`, `--audit-log` | ❌ writes atlas |

### 3.3 Atlas + lock subsystem

| name | dispatcher | role | nested | absorption |
|---|---|---|---|---|
| `atlas` | `cmd_atlas` L5383 | atlas.n6 routing | `search`, `append --node\|--edge`, `absorb [--target nexus] [--glob] [--archive] [--dry-run]`, legacy fwd to atlas_health.hexa | search ★★★, append/absorb ❌ writes |
| `lock` | `cmd_lock_unlock` L5471 | per-file `chflags uchg` + audit ledger (raw 1 + raw 85); sets `HIVE_CLI_PARENT=1` | – | ❌ filesystem mutation |
| `unlock` | `cmd_lock_unlock` L5471 | per-file `chflags nouchg` | – | ❌ filesystem mutation |
| `lock-status` | `cmd_lock_unlock` L5471 | display chflags + recent audit entries | – | ★★★ read-only |

Lock module SSOT: `nexus/n6/file_lock.hexa`.

### 3.4 nexus check — multi-domain verifier (DEEP DIVE)

**Dispatcher:** `cmd_check` in `engine/nexus_cli.hexa` L1198 (note: lives in L2 engine, not L3 run.hexa).
**Spec status:** Documented in `subcmds_check` block of spec (not in main `subcommands` map — caller easy-miss).
**Sentinel:** `__NEXUS_CHECK__ <PASS|FAIL> math=<R> physics=<R> bio=<R> sim=<R> qrng=<R> brain=<R> consciousness=<R> phi=<R> learning=<R> phenomenology=<R> law=<R> integrity=<R> meta=<R> hexalint=<R>`
**Exit codes:** 0 (all PASS/SKIP), 1 (usage/IO), 2 (any domain FAIL).
**Backends:** `tool/check_router.hexa` (HEXA_ARGV env-pack pattern) → `tool/check_physics.hexa`, `tool/check_hexalint.hexa`.

Domain flags:

| flag | domain | backend status |
|---|---|---|
| `--math` | invariants_drift, absolute, hyperarithmetic | active |
| `--physics` | dimensional, conservation, codata, planck, anchor, lorentz | active |
| `--bio` | stub | placeholder |
| `--sim` | sim_bridge/anu_time | stub |
| `--qrng` | ANU distribution | stub |
| `--brain` | external `~/core/hexa-brain` | stub |
| `--consciousness` | AN11 11-axis | ANIMA absorption planned |
| `--phi` | phi_holo, phi_iit | ANIMA absorption planned |
| `--learning` | corpus_4gate | ANIMA absorption planned |
| `--phenomenology` | EEG cross-substrate | ANIMA absorption planned |
| `--law` | consciousness_laws | ANIMA absorption planned |
| `--integrity` | cert_gate / nexus_gate | ANIMA absorption planned |
| `--meta` | n6 honesty_triad, atlas_drift | active |
| `--hexalint` | tree-sitter-hexa lints.scm | active |
| `--all` | every domain (default) | – |

Sub-flags (within a domain): `--dimensional`, `--conservation`, `--anchor`, `--codata`, `--planck`, `--lorentz`, `--invariants`, `--honesty`, `--drift`, `--all-physics`, `--ndjson`, `--selftest`, `--quiet`, `--json`, `--caller`.

**BT-AI2 honesty auto-audit** (absorbed from `dancinlab/honesty-monitor 1.0.0` on **2026-05-06**):

| migration | old | new |
|---|---|---|
| trigger | `nexus honesty status` | runs **inline** every `nexus check` invocation |
| F-AI2-A | claimed PASS but `|loss−expected|/|expected| ≥ 0.05` | falsifier hard-coded at L1169 |
| F-AI2-B | claimed FAIL but `|loss−expected|/|expected| ≤ 0.01` | falsifier hard-coded at L1178 |
| witness emit | (none) | `n6/atlas.append.honesty_bit-<verdict>-<obs>obs-<ts>.n6` via `bt_ai2_witness_append` L1288 |
| witness format | – | `@R HONESTY_BIT_<ts> = "<verdict>" :: bt_ai2_audit [9]` |
| protocol token | – | `__BT_AI2__ label=<slug> claim=PASS\|FAIL loss=<f> expected=<f>` scanned out of router stdout |
| thresholds | env-overridable in standalone | **immutable consts** in nexus (Goodhart guard) |
| boundary | – | strict `≥ 0.05` / strict `≤ 0.01` (4.99% silent / 5.01% alerts) |

Witness emit format for the `__NEXUS_CHECK__` sentinel itself: `n6/atlas.append.check-<verdict_lc>-<dom_count>dom-<ts_flat>.n6` with `@R CHECK_<ts> = "<verdict>" :: nexus_check [9]` body.

**Remote routing:** `force-local` (HEXA_LOCAL=1 in bin/nexus-cli) — nested hexa exec patterns break under remote PATH absence.

**Recursive spec:** `n6/docs/meta_atlas_recursive.md` (Tarski strict hierarchy).
**ai-native doc:** `docs/nexus_check.ai.md`.

### 3.5 nexus kick — ω-cycle executor (DEEP DIVE)

**Dispatcher:** `cmd_kick` in `cli/run.hexa` L6607.
**Helpers:** `_kick_help` L6192, `_kick_tree` L6226, `_kick_bench` L6237, `_kick_selftest` L6263, `_kick_run` L6286, `_kick_status` L6536.
**Semantics:** `kick ≡ ω-cycle`. Canonical CLI shape: `nexus kick <topic> [flags...]`. Unknown sub treated as topic (raw 91 honest C3 transparency + raw 168 canonical shape, see L6630–6650).

Sub-command graph:

| sub | helper | role |
|---|---|---|
| `tree` | `_kick_tree` | live registry — strata / axes / backends / noise_sources (`tool/kick_tree.hexa`) |
| `bench <topic> [--backends ...]` | `_kick_bench` | cross-backend perf bench (`tool/kick_bench.hexa`) |
| `run <topic>` | `_kick_run` | legacy alias for default-run |
| `selftest [<topic>]` | `_kick_selftest` | closed-loop iter-3 — synthesize deterministic minimal-valid witness; NO subagent / NO LLM / NO OAuth (`tool/kick_dispatch.hexa --selftest`) |
| `status` | `_kick_status` L6536 | R4 ISSUE#6 holistic resource dashboard (hosts / slot-pool / cache) |
| `atlas <sub>` | → `cmd_atlas` | forwarded raw-99 alias (iter-71) |
| `lock`/`unlock`/`lock-status` | → `cmd_lock_unlock` | forwarded raw-99 alias |
| `slots` | – | **REMOVED** 2026-04-26: emits eprintln redirecting to `nexus kick status` or `hive-exec claude_slot_pick --list`, then `exit(2)` |
| `help`/`-h`/`--help` | `_kick_help` | help text |

Default-run flags (when `sub` is treated as topic):
`--stratum <s>` · `--axes a,b,c` · `--noise alpha,beta,gamma` · `--backend <slug>` · `--parent-sid <sid>` · `--dry-run` · `--selftest` (routes back to selftest helper).

Noise injection types (canonical diagram: `~/core/diagrams/llm_vs_nexus_noise.md`):
- **alpha** — absorbed-primitive sampling from `state/kick/registry/noise_sources/absorbed/`
- **beta** — QRNG byte (real ANU when `KICK_BETA_REAL_ANU=1`, urandom fallback per obs_2)
- **gamma** — empirical bridge selected by beta-byte from 16 registered bridges

**Mac fallback hard-fail (raw 40+42 + 2026-04-29 user directive, L6313–6334):**
- `uname -s == "Darwin"` ⇒ `_kick_run` mandatorily forwards over SSH to `NEXUS_KICK_FORWARD_HOST` (default: `ubu2`, since hetzner removed from fleet 2026-05-01).
- 8s `ssh BatchMode` probe; on failure → **hard-fail exit 2 + raw 66 reason trailer**. No Mac local fallback exists. No opt-in escape hatch.
- Audit append: `state/audit/kick_auto_forward.jsonl` records every forward / hard-fail.
- Remote inner: `cd ~/core/nexus && NEXUS_KICK_SKIP_OAUTH_GATE=1 NEXUS_KICK_SKIP_PREFLIGHT=1 ~/.hx/bin/hexa run cli/run.hexa <fwd-args>`.

**Authorized hive-cli fallback (raw 99 stage-3 + raw 100, L6377+):** if remote returns `__KICK_RESULT__ FAIL` AND `all-claude-slots-exhausted`, invoke `hive_kick_dispatch.hexa` as the canonical authorized internal fallback. Only fires for OAuth-saturation; other FAIL modes are not coerced.

**Sentinel:** `__KICK_RESULT__ <PASS|FAIL> witness=<path> tier1=<N> falsifier_pass=<N>` (raw 80).
**Error trailer:** `reason=<slug> fix=<directive>` (raw 66).
**Witness landing:** `design/kick/<YYYY-MM-DD>_<topic-slug>_omega_cycle.json`.
**Architecture doc:** `design/kick/2026-04-26_kick_architecture_omega_cycle.json`.

Spec exposure: **none — `kick` is entirely absent from `nexus_cli_spec.json`** despite ~100 lines of dispatcher in run.hexa.

### 3.6 universe subgraph (`cmd_universe` L5665)

21 selectable topology modes (flat | t2 | t3 | s2 | s3 | klein | blackhole | wormhole | vacuum-decay | altered | cartoon | nested | calabi6 | ads-cft | brane | inflation | de-sitter | minkowski | ca3d | big-crunch | bubble).

| sub | line | nested sub | backing script |
|---|---|---|---|
| `propagation` | L5672 | `selftest`, `run <topo> [ticks]` | `sim_bridge/anu_time/universe_propagation.hexa` |
| `pipeline` | L5695 | `selftest`, `list-topo`, `run <topo> [ticks]` | `sim_bridge/anu_time/universe_pipeline.hexa` (Stage 1-5 sequential) |
| `scale` | L5723 | `selftest`, `benchmark`, `run <ticks> <sigma2>` | `sim_bridge/anu_time/scale_universe.hexa` (Stage 5) |
| `anchor-v2` | L5749 | `selftest`, `topo <topo> [ticks]`, `compare <topo>` | `sim_bridge/anu_time/empirical_anchor_v2.hexa` (iter-27 honest baseline) |
| `anchor` | L5778 | `selftest`, `list`, `topo <topo> [ticks]` | `sim_bridge/anu_time/empirical_anchor.hexa` (Stage 4) |
| `field` | L5806 | `selftest`, `topo <topo> <mode> [ticks] [m2] [lambda]` | `sim_bridge/anu_time/field_action.hexa` (Stage 3, phi4 / ym mode) |
| `lorentz` | L5832 | `selftest`, `topo <name> [ticks] [c]` | `sim_bridge/anu_time/lorentz_metric.hexa` (Stage 2) |
| `quantum` | L5856 | `selftest`, `topo <name> [ticks]` | `sim_bridge/anu_time/quantum_universe.hexa` (Stage 1) |
| `selftest` | L5878 | – | top-level selftest |
| `topo <name> [ticks]` | L5883 | – | `sim_bridge/anu_time/topology_universe.hexa` |
| `evolve <from> <to> <at> [ticks]` | L5891 | – | topology_universe evolve mode |

Spec exposure: **none** — universe is run.hexa-only.
Absorption: ❌ all heavy sim shellouts.

### 3.7 hexa-sim subgraph (`cmd_hexa_sim` L5906) — n=6 deep-universe-simulation toolchain (HEXA-SIM)

Originating in `CANON/domains/physics/simulation-theory/`. 24 sub-commands; full inventory:

| sub | tier | role | backing |
|---|---|---|---|
| `verify [--axis NAME] [--json] [--selftest]` | – | §7 VERIFY 10-axis grid (CONSTANTS/DIMENSIONS/CROSS/SCALING/SENSITIVITY/LIMITS/CHI2/OEIS/SYMBOLIC/COUNTER) | `tool/hexa_sim_verify_grid.hexa` |
| `falsifier [--id F#]` | – | §X.4 falsifier registry runner; F1-F8 + F9 TP-8 | `tool/hexa_sim_falsifier.hexa` |
| `bridge <name>` | – | 16-bridge dispatcher (see §3.8) | `_hexa_sim_bridge_dispatch` |
| `ci [--skip N] [--only N]` | – | 19-tool selftest aggregate runner | `tool/hexa_sim_ci.hexa` |
| `search <pattern>` | Tier-1 i8 | atlas.n6 + 7 shards unified search (10033 entries) | bash, runtime-down resilient |
| `runtime-check` | Tier-1 i2 | hexa runtime health watchdog | bash |
| `provenance <id>` | Tier-2 i15 | git first/last commit hash for atlas fact id | bash |
| `diff-per-type [<commit>]` | Tier-2 i9 | atlas commit diff @type-classified | bash |
| `dashboard [--out PATH]` | Tier-2 i13 | 4-repo (nexus+n6+anima+hexa-lang) unified status | bash |
| `precommit [--install-hook]` | Tier-2 i14 | staged atlas grade-format / dup-id sanity | bash, raw 25 lock-aware |
| `collision-check` | – | cross-shard (type,id) watchdog; CONFLICT exit 76 (raw 23) | bash |
| `status-all [--brief\|--full]` | – | 5-atlas-tools page summary | – |
| `timeline-rotate [--check]` | – | `atlas_health_timeline.jsonl` size rotator (default 5000 lines) | – |
| `falsifier-health [--quiet\|--json]` | – | 24 falsifier registry CLEAN/HIT/ERROR + timeline | raw 71 report-only |
| `bridge-health [--quiet\|--json]` | – | 16-bridge `--selftest` PASS/FAIL/OFFLINE-FALLBACK + timeline | – |
| `health-check-all [--quiet]` | – | cron wrapper: falsifier + bridge + status-all | – |
| `grade-promote [--limit N]` | Tier-2 i6 | [7] heuristic entries → SUGGEST mode, manual-only (raw 71) | – |
| `bridge-aging [--bridge NAME]` | Tier-2 i10 | URL response schema drift monitor | snapshot-based |
| `index [--lookup ID]` | Tier-1 i1 | atlas (id→line, 9166 entries) O(1) lookup | bash, dedup accel |
| `falsifier-spawn` | Tier-1 i11 | high-grade atlas → F# candidate auto-spawn | suggest-only |
| `glob-since [--since DATE]` | Tier-2 i18 | witness incremental filter for omega-ingest accel | bash |
| `v2-regression [--layer N]` | Tier-2 i16 | Phase 4a serializer v1 backward-compat 4-layer | bash |
| `atlas-ingest` | – | bridge facts → `atlas.append.hexa-sim-bridges.n6` (Phase 1, 37 facts + 5 @X) | `tool/hexa_sim_atlas_ingest.hexa` |
| `omega-ingest` | – | ω-cycle witness JSON glob → per-cycle shard + atlas.n6 absorb. DEFAULT=absorb 2026-04-26 F19 flip; `--dry-run` opt-out; `--witness P` single-shot for kick auto-absorb | `tool/omega_cycle_atlas_ingest.hexa` |
| `supercycle` | – | cross-repo super-aggregator + Honesty triad 5 preconditions (Phase 3, 3-repo, nexus 5/5 + n6 5/5 + anima 4/5) | `tool/atlas_omega_supercycle.hexa` |
| `doc` | – | Korean overview README emit | – |

Absorption ratings: search ★★★★, runtime-check ★★★, provenance ★★★, dashboard ★★★, status-all ★★★, index ★★★★. All ingest / absorb / promote variants ❌ writes shared state.

### 3.8 hexa-sim bridge backends (`_hexa_sim_bridge_dispatch` L5571)

`nexus hexa-sim bridge <name>` — 16 external API bridges:

| bsub | tier | backing script (under `tool/`) | role |
|---|---|---|---|
| `codata` | T1 | `codata_bridge.hexa` | NIST CODATA 2022 α⁻¹ |
| `oeis` | T1 | `oeis_live_bridge.hexa` | OEIS A000396/A000203/A000005/A000010 live |
| `gw` | T1 | `gw_observatory_bridge.hexa` | LIGO/Virgo GWOSC GWTC catalog |
| `horizons` | T1 | `horizons_bridge.hexa` | JPL Horizons → TP-8 |
| `arxiv` | T1 | `arxiv_realtime_bridge.hexa` | arXiv Atom feed |
| `cmb` | T2 | `cmb_planck_bridge.hexa` | Planck 2018 6 cosmological params |
| `nanograv` | T2 | `nanograv_pulsar_bridge.hexa` | NANOGrav 15-yr GWB (67 pulsars) |
| `simbad` | T2 | `simbad_bridge.hexa` | SIMBAD ICRS RA/DEC |
| `icecube` | T2 | `icecube_neutrino_bridge.hexa` | IceCube 5 landmarks + GCN AMON |
| `nist_atomic` | T2 | `nist_atomic_bridge.hexa` | NIST Rydberg/Bohr/Hartree + 6 elements |
| `wikipedia` | T2 | `wikipedia_summary_bridge.hexa` | Wikipedia REST summary |
| `openalex` | T2 | `openalex_bridge.hexa` | OpenAlex citations / DOI |
| `gaia` | T2 | `gaia_bridge.hexa` | Gaia DR3 6D astrometric |
| `lhc` | T2 | `lhc_opendata_bridge.hexa` | CERN OpenData LHC datasets |
| `pubchem` | T2 | `pubchem_bridge.hexa` | PubChem molecules |
| `uniprot` | T2 | `uniprot_bridge.hexa` | UniProt proteins |

Absorption: all ❌ — live external API calls.

### 3.9 Other top-level verbs

| name | dispatcher | role | spec | absorption |
|---|---|---|---|---|
| `roadmap` | `cmd_roadmap` L5490 | forwards to `entry.hexa roadmap` | ✓ (limited) | ★★★ static JSON |
| `projects` | `cmd_projects` L6825 | run_entry projects (table / json / names) | ✓ | ★★★★ static list |
| `akida` | `cmd_akida` L6653 | neuromorphic dispatch (Akida HW probe + fallback CPU). Sub: `probe`/`chain`/`status`/`route <workload>`/`go`/`run <F-id>`/`all`/`followup`. Workloads: energy / energy-sparse / spike / lyapunov / godel / phase7 / check-loop. Honesty: every measurement carries PARTIAL-/PLAUSIBLE- prefix when hardware absent (F-C architectural barrier). | ✗ | ❌ HW-dependent |
| `qrng` (run.hexa variant) | `cmd_qrng` L6749 | nxs-002 cycle 10 — sub: `axiom` (Python), `vqe-h2`, `ouroboros`, `perturbation`, `anu-collect`, `status` | ✗ | ❌ live ANU + Python |

---

## 4. Layer L4a — standalone `bin/` scripts (7 verbs)

| script | type | own verbs | role | absorption |
|---|---|---|---|---|
| `nexus-cli` | bash | – | thin wrapper for `engine/nexus_cli.hexa`. Handles `--catalog` bypass (pure JSON, no runtime banner). | ★★ proxy |
| `nx` | bash | `install`, `uninstall`, `open`, `list`, `status`, `help` | nexus project CLI for `type=app` projects only. /Applications deployment + launchd bootout. Reads `$WS/nexus/config/projects.json`. Forces `type != "app"` to be rejected. | ❌ host-specific app installer |
| `atlas3d` | python3 | `publish`, `serve`, `watch`, `shard`, `snapshot`, `overlay`, `theorem`, `tail`, `query`, `diff`, `audit` | atlas.n6 → docs/atlas3d/ direct publisher; viewer parses client-side. Transformation=0 SSOT-mirror. | ❌ writes docs/, git commit |
| `drill_htz` | bash | – | one-liner Hetzner offload: `bin/drill_htz '<seed ≥10>' [rounds=1] [preset=probe]`. 1:1 maps to `airgenome offload htz "nexus drill --seed ..."`. Note: hetzner removed 2026-05-01; script may be stale. | ❌ remote offload |
| `health-launchd` | bash | `install`, `uninstall`, `status`, `run-now`, `logs`, `help` | LaunchAgent (30-min interval) for `health.hexa all --verbose`. Modern launchctl bootstrap/bootout/kickstart. Uses `/Users/ghost/Dev/nexus` path (legacy). | ❌ launchd / host-specific |
| `reaper-launchd` | bash | `install`, `uninstall`, `status`, `run`, `reload`, `logs` | H-NOZOMBIE LaunchAgent (5-min reaper.hexa kill_old). | ❌ launchd / host-specific |
| `hexa_rss_watchdog` | bash | – (daemon) | global 1s polling — kills `hexa_stage0.real`/`hexa_v2`/`hexa_full`/`hexa_interp.real` exceeding RSS cap (4 GiB default for Mac 24 GiB envelope). Exempts claude/WindowServer/Terminal/iTerm + ghost route.hexa + wraith vault subprocesses (interactive secrets). | ❌ system daemon |
| `exec_validated` | symlink | – | symlink to `../harness/exec_validated`. Validated exec wrapper. | ❌ harness internals |
| `hexa` | symlink | – | symlink to `../scripts/bin/hexa` — the hexa resolver itself. | ❌ resolver |

---

## 5. Layer L4b — `bin/hexa-*` annotation extractors (28 verbs)

**Uniform pattern:** all 28 are bash scripts using grep MVPs that scan `<file.hexa>` or `--dir <directory>` for `@<annotation>(...)` markers and emit JSON to stdout. Pure-read, no side effects, no remote routing, no shared state mutation. **These are the highest-confidence absorption candidates in the entire nexus ecosystem.**

Common interface (all):
- `<name> <file.hexa> [<file2>...]` or `<name> --dir <directory>`
- Output: `{"version":"0.1","source":"grep-mvp", "<annotations|tests|n6_tags|…>":[...], "summary":{...}}`

| script | annotation kinds extracted | category | absorption |
|---|---|---|---|
| `hexa-pure-check` | `@pure` fn body side-effect heuristic; `--strict` flag | source-analyzer | ★★★★★ pure-grep |
| `hexa-memo-check` | `@memo(ttl=N)` cache key schema | source-analyzer | ★★★★★ |
| `hexa-catalog` | `@cli(sub=...)`, `@flag(...)`, `@doc(...)` | source-analyzer (META) | ★★★★★ |
| `hexa-readme` | 7 kinds: `@readme`, `@changelog`, `@api_doc`, `@example`, `@deprecated`, `@since`, `@author`. Modes: `readme\|changelog\|json` | source-analyzer | ★★★★★ |
| `hexa-doc` | `@doc(section=...,body=...)` + adjacent fn signatures, grouped by section | source-analyzer | ★★★★★ |
| `hexa-codegen-hints` | `@inline`, `@no_inline`, `@cold`, `@deprecated` | source-analyzer | ★★★★★ |
| `hexa-distill` | `@distill`, `@prune`, `@lora`, `@adapter`, `@kd` | source-analyzer | ★★★★★ |
| `hexa-effect-map` | Tier 3: `@effect`, `@capability`, `@ai`, `@prove`, `@refines` | source-analyzer | ★★★★★ |
| `hexa-intent-map` | `@intent(description=...)`; project default = `$HOME/Dev/anima` | source-analyzer | ★★★★★ |
| `hexa-meta-map` | 6 kinds: `@meta`, `@reflect`, `@introspect`, `@self_model`, `@theory_of_mind`, `@qualia` | source-analyzer | ★★★★★ |
| `hexa-phi-map` | 4 kinds: `@phi`, `@consciousness`, `@channel`, `@iit`. Project default = anima. | source-analyzer | ★★★★★ |
| `hexa-struct-layout` | `@repr("c")`, `@align(N)`, `@pack` + struct fields → layout JSON | source-analyzer | ★★★★★ |
| `hexa-self-aware` | 6 kinds: `@compile_trace`, `@ast_visible`, `@codegen_mark`, `@optimizer_hint`, `@type_debug`, `@self_check` | source-analyzer (compiler) | ★★★★★ |
| `hexa-cognitive` | 25 kinds across 5 categories: vision/audio/memory/emotion/plan | source-analyzer | ★★★★★ |
| `hexa-freedom` | 10 kinds: `@free_will`, `@autonomy`, `@agency`, `@choice`, `@spontaneity`, `@volition`, `@initiative`, `@self_determined`, `@degrees_of_freedom`, `@indeterminate` | source-analyzer | ★★★★★ |
| `hexa-infer` | 5 kinds: `@infer`, `@quantize`, `@cache_kv`, `@speculate`, `@batch_continuous` | source-analyzer | ★★★★★ |
| `hexa-learn` | 5 kinds: `@learn`, `@curriculum`, `@moe`, `@chinchilla`, `@synthetic_data` | source-analyzer | ★★★★★ |
| `hexa-safety` | 6 kinds: `@interpret`, `@align`, `@adversarial_robust`, `@deploy_safe`, `@multimodal_safe`, `@model_welfare`. Anthropic Fellows 171 research baseline. | source-analyzer | ★★★★★ |
| `hexa-antivirus` | 10 kinds: `@antivirus`, `@quarantine`, `@heal`, `@integrity`, `@sandbox`, `@cve`, `@rce_guard`, `@audit`, `@canary`, `@patch` | source-analyzer | ★★★★★ |
| `hexa-serve` | 4 kinds: `@ctx_compress`, `@tool_cache`, `@session_migrate`, `@route_agent` | source-analyzer | ★★★★★ |
| `hexa-tenant` | 4 kinds: `@adapter`, `@hotswap`, `@tenant_isolate`, `@self_serve_portal` | source-analyzer | ★★★★★ |
| `hexa-eval-run` | 4 kinds: `@eval`, `@cat_adaptive`, `@judge_calibrate`, `@contamination_check` | source-analyzer | ★★★★★ |
| `hexa-n6-list` | `@n6(identity=..., domain=..., target=..., name=...)` | source-analyzer (n6 markers) | ★★★★★ |
| `hexa-test-list` | `@test`, `@bench` | source-analyzer | ★★★★★ |
| `hexa-schema` | `@schema(type="...")` + struct fields → JSON Schema | source-analyzer | ★★★★★ |
| `hexa-law-link` | `@law(ref="...")` cross-reference check against `--rules` (default `$NEXUS/shared/rules/anima.json`) | source-analyzer (governance) | ★★★★ (one static dep) |
| `hexa-harness` | 10 kinds: `@harness(phase=...)`, `@gate(rule_id=H-*,action=...)`, `@dod`, `@verify`, ... — nexus-harness annotation collector | governance | ★★★★ (governance-coupled) |
| `hexa-rule` | `@rule(kind=name\|alias\|deprecate\|scope\|stack\|schema\|conflict\|migrate\|lint\|audit\|enforce)`; supports `--mode migrate [--apply]` for alias marker rewrite (DRY-RUN by default) | governance | ★★★ (write capability with --apply) |
| `hexa-gate-register` | `@gate(rule="...")` extractor, dry-run only; `--apply` warns + exit 1 (unsupported) | governance | ★★★★ (write blocked by design) |

**Aggregate observation:** 25 of 28 are ★★★★★ pure-grep candidates. 3 (`hexa-law-link`, `hexa-harness`, `hexa-rule`, `hexa-gate-register`) couple to nexus governance state but the coupling is well-bounded (a single rules file or atomic dry-run write). All 28 could be absorbed into a single hexa-source-tooling repo with zero loss of nexus functionality.

---

## 6. Spec gap analysis

### What the spec exposes vs. what exists

| layer | verbs found | verbs in spec | coverage |
|---|---:|---:|---:|
| L1 spec keys (`subcommands` map) | 19 | 19 | 100% (definitional) |
| L1 spec keys (`subcmds_v2`) | 3 | 3 | 100% |
| L1 spec keys (`subcmds_raw99`) | 5 | 5 | 100% |
| L1 spec keys (`subcmds_check`) | 1 | 1 | 100% |
| L2 engine verbs total | 32 | 28 | 87.5% |
| L2 verbs missing from spec | 4 (`bio`, `qrng`, `mc`, `honesty`-deprecated) |
| L3 run.hexa top-level verbs | ~50 | ~13 | ~26% |
| L3 verbs missing from spec | ~37: `canon`, `forge`, `molt`, `wake`, `swarm`, `reign`, `dream`, `surge`, `omega`, `debate`, `kick`, `akida`, `qrng`, `universe`, `drill-daemon`, `chain`, `revive`, `canary`, `omega-monitor`, `solve`, `lock`, `unlock`, `lock-status`, `hexa-sim`, `atlas absorb`, `self-check`, `doctor`, `contracts`, `verify`, `sync`, `roadmap` (delegated), … | – |
| L4a bash scripts | 7 own surfaces | 0 | 0% |
| L4b hexa-* scripts | 28 own surfaces | 0 | 0% |

### Highest-impact spec gaps

1. **`nexus check`** — fully documented in its own sub-block but easy to miss because it's not in main `subcommands` map. Recommend promoting.
2. **`nexus kick`** — entirely absent. Has 200+ lines of dispatcher and the canonical ω-cycle CLI shape. Critical for raw 168 / closed-loop iter-3.
3. **The L0…L11 ladder** (`canon`, `forge`, `molt`, `wake`, `swarm`, `reign`, `dream`, `surge`, `omega`) — none documented. `omega` is described in cmd_help as **the main entry point**.
4. **`hexa-sim`** — 24-subcmd surface, the entire n=6 simulation toolchain, hidden.
5. **`universe`** — 11-sub × 21-topology grid, hidden.
6. **`atlas absorb`** — iter-70 atlas absorb pipeline, hidden (only `search`/`append` spec'd).
7. **`lock`/`unlock`/`lock-status`** — chflags governance, hidden.
8. **`bio`** — appears in L2 `cmd_help` but missing from `subcommands` map.
9. **`drill-daemon`** — E11 Phase 1 daemon, hidden.
10. **`debate`/`chain`** — L3 axis dispatch, hidden.

---

## 7. Top absorption candidates (ranked)

### ★★★★★ tier (atlas-style snapshot-able, pure read, no shared state)

1. **All 28 `bin/hexa-*` annotation extractors** — pure grep MVPs, single-file output, zero nexus dependencies (except `hexa-law-link`/`hexa-harness`/`hexa-rule`/`hexa-gate-register` which have minor static-rule dependencies at ★★★★). Direct precedent: atlas embedding RETIREMENT_PLAN §0b / RFC-017 §4.5.
2. **`nexus version`** (both L2 + L3) — pure constant emit.
3. **`nexus contracts`** — `cat convergence/integration_contracts.json`.
4. **`nexus help`** / `--catalog` — pure text/JSON emit.

### ★★★★ tier (mostly read, one or two static deps)

5. **`nexus-cli lens --query`** — lens registry lookup; static JSON.
6. **`nexus-cli roadmap list/status`**, **`nexus roadmap`** — static roadmap JSON read.
7. **`nexus-cli status-proj`** / **`roadmap-proj`** / **`convergence-proj`** — v2 project read surface.
8. **`nexus-cli atlas search`**, **`nexus hexa-sim search`** — grep-based search (read).
9. **`nexus hexa-sim index --lookup ID`** — pre-built (id→line) index, O(1) lookup.
10. **`nexus projects`** — static list.

### ★★★ tier (read with live state dep)

11. `nexus self-check`, `nexus status`, `nexus gap`, `nexus omega-monitor status`, `nexus hexa-sim status-all`, `nexus hexa-sim runtime-check`, `nexus hexa-sim provenance`, `nexus hexa-sim dashboard`, `nexus lock-status`, `nexus discovery query`.

### ★★ / ★ / ❌

Heavy compute (drill / smash / free / omega / dream / surge / swarm / reign / molt / wake / forge / canon / debate / hyperarithmetic / meta-closure), all writes (atlas append/absorb, lock/unlock, promote, sync --apply, all ingest variants), all remote routing (qmirror live QPU, sim-universe shellout, akida HW, qrng ANU, kick SSH-forward, doctor remote), and all launchd/daemon binaries (`health-launchd`, `reaper-launchd`, `hexa_rss_watchdog`, `nx`) are ❌ — fundamentally tied to nexus host or external resources.

---

## 8. Top 3 most surprising findings

1. **Spec coverage is ~26% of run.hexa surface.** The hive-public sidecar names 28 verbs but the real top-level dispatch has ~70. The `omega` apex — by cmd_help's own admission "the main entry point" — is invisible to hive. So is the entire L4-L11 ladder, `kick`, `universe`, `hexa-sim`, `lock` system, `drill-daemon`, `akida`, `debate`, `chain`, `revive`, `canary`, `omega-monitor`. Any hive integration that consumes the spec is operating on the smallest possible view of nexus.

2. **`nexus honesty` is dead but the absorption left a witness emitter.** Killed 2026-05-06, replaced by inline BT-AI2 audit inside `cmd_check`. The audit auto-emits `n6/atlas.append.honesty_bit-*.n6` shards using strict thresholds (≥0.05 / ≤0.01, hard-coded consts to defeat Goodhart drift). The token grammar (`__BT_AI2__ label=... claim=... loss=... expected=...`) is now an inline protocol that every `check_*.hexa` domain can opt into; absent tokens silently skip.

3. **`nexus kick` is a hard-fail Mac fortress.** Per 2026-04-29 user directive verbatim ("mac 이용 , mac fallback , mac 으로 우회 kick 실행 모두 관련 폐기"), kick on Darwin MUST SSH-forward (default ubu2) and hard-fails if the host is unreachable — no local opt-in escape exists. Plus an authorized hive-cli fallback at L6377 fires *only* for `all-claude-slots-exhausted` (raw 99 stage-3 + raw 100), nothing else. This is the most policy-heavy verb in the codebase, and it is entirely absent from `nexus_cli_spec.json`.

---

## 9. Verbs that resisted classification (need user input)

- **`nexus akida`** — workloads `energy / energy-sparse / spike / lyapunov / godel / phase7 / check-loop` mix sim falsifiers (F-C, F-L1, F-L1+, F-L6, F-L7, F-M1, F-M2, F-M3a, F-A, F-B) with HW probe. Is the sim path (FORCE_FALLBACK=1) absorbable? Looks ★★★ but governance-coupled to `sovereign_cli_federation.spec.yaml v1`.
- **`nexus solve`** — already deprecated to `hxq solve` but the shim is still wired. Should it be removed from L3 entirely or left for one cycle (parallel to `honesty` stub)?
- **`nexus-cli mc` / `nexus-cli bio`** — both are L2-only standalone-repo shellouts that mirror the qmirror/sim pattern. They're absent from `subcommands` map but present in `cmd_help`. Spec bug, or deliberate omission?
- **The L4a `nx` script's `type=app`** — projects.json must declare `type: "app"` for install/uninstall to work. How many projects in `$WS/nexus/config/projects.json` actually carry that type? (Out of scope for this catalog; flagged for follow-up.)
- **`atlas3d`** — Python (not bash). 11-subcmd surface (publish/serve/watch/shard/snapshot/overlay/theorem/tail/query/diff/audit). It's the only Python entry-point under `bin/`. Should it follow nexus governance or live in a separate publication pipeline?

---

## 10. Source file index

| component | path | function |
|---|---|---|
| spec sidecar | `~/core/nexus/engine/nexus_cli_spec.json` | hive-facing SSOT |
| nexus-cli engine | `~/core/nexus/engine/nexus_cli.hexa` | L2 dispatcher (~32 verbs) |
| nexus-cli bash | `~/core/nexus/bin/nexus-cli` | L2 thin wrapper |
| nexus runtime | `~/core/nexus/cli/run.hexa` | L3 dispatcher (~50 verbs) |
| kick architecture | `~/core/nexus/design/kick/2026-04-26_kick_architecture_omega_cycle.json` | kick spec |
| kick dispatch | `~/core/nexus/tool/kick_dispatch.hexa` | kick worker |
| kick tree / bench | `~/core/nexus/tool/kick_tree.hexa`, `~/core/nexus/tool/kick_bench.hexa` | registry / perf |
| check router | `~/core/nexus/tool/check_router.hexa` | multi-domain router |
| check physics | `~/core/nexus/tool/check_physics.hexa` | dim + cons + anchor + codata + planck + lorentz |
| check hexalint | `~/core/nexus/tool/check_hexalint.hexa` | tree-sitter-hexa AST rules |
| check ai-native doc | `~/core/nexus/docs/nexus_check.ai.md` | recursive Tier-3 spec |
| recursive spec | `~/core/nexus/n6/docs/meta_atlas_recursive.md` | Tarski strict hierarchy |
| atlas absorb | `~/core/nexus/n6/atlas_absorb.hexa` | absorb pipeline (chflags-locked) |
| file lock | `~/core/nexus/n6/file_lock.hexa` | per-file chflags + audit |
| atlas health | `~/core/nexus/n6/atlas_health.hexa` | append/promote backend |
| drill daemon | `~/core/nexus/cli/scripts/nexus_drilld.hexa` | E11 Phase 1 daemon |
| cross-chain | `~/core/nexus/cli/scripts/cross_chain.hexa` | nexus→anima shim |
| revive | `~/core/nexus/cli/revive/revive.hexa` | engine+map v2 infinite loop |
| adversarial debate | `~/core/nexus/cli/drill/adversarial_debate.hexa` | L3 N-variant debate |
| canary drill | `~/core/nexus/tool/canary_drill.hexa` | L1/L4 verdict single-shot |
| omega monitor | `~/core/nexus/tool/raw81_omega_cycle_monitor.hexa` | falsifier monitor |
| 16 hexa-sim bridges | `~/core/nexus/tool/{codata,oeis,gw,horizons,arxiv,cmb,nanograv,simbad,icecube,nist_atomic,wikipedia,openalex,gaia,lhc,pubchem,uniprot}_bridge.hexa` | external API |
| universe simulators | `~/core/nexus/sim_bridge/anu_time/{topology,universe_pipeline,universe_propagation,scale,empirical_anchor,empirical_anchor_v2,field_action,lorentz_metric,quantum}_universe.hexa` | 11 sim stages |
| akida runner | `~/core/nexus/scripts/akida/{runner,falsifier,dispatch}.hexa` | neuromorphic |
| forward audit | `~/core/nexus/state/audit/kick_auto_forward.jsonl` | kick SSH-forward ledger |
| canon seal log | `~/core/nexus/state/canon_seal.jsonl` | L11 transfinite seals |

```
END OF CATALOG
generator-note: this document is research-only. It modifies no nexus state.
absorption-precedent: atlas embedding (RETIREMENT_PLAN §0b, RFC-017 §4.5).
```
