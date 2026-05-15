# gate/commands.json — nexus reference scrub (2026-05-13)

User directive: "흡수된건 scrub" — nexus archived, absorbed verbs use hexa-native
dispatch only. Single-file edit; no commit.

## Counts

| metric                  | before | after | notes                                  |
|-------------------------|-------:|------:|----------------------------------------|
| `nexus` mentions        |    57  |   28  | survivors are `NEXUS_*` env var names  |
| `nexus` (non-env-var)   |    ~40 |    2  | both are descriptive "absorbed/archived" annotations |
| `shared/blowup` paths   |    13  |    0  | dropped (nexus-internal paths)         |
| `nexus-cli`             |     8  |    0  | replaced with hexa-native dispatch     |
| `~/.hx/bin/nexus`       |    11  |    0  | replaced with bare `hexa` on PATH      |
| lines                   |  1949  |  1939 | -10 net (insertions 81, deletions 91)  |

## Surviving `nexus`-substring matches (all intentional)

1. `NEXUS_MOLT_SKIN_FILE`, `NEXUS_MOLT_MAX`, `NEXUS_CANON`, `NEXUS_FORGE`,
   `NEXUS_MOLT`, `NEXUS_WAKE_SIGNAL_FILE`, `NEXUS_WAKE_MAX`,
   `NEXUS_WAKE_COOLDOWN_SEC`, `NEXUS_WAKE`, `NEXUS_SWARM_MAX`, `NEXUS_SWARM`,
   `NEXUS_REIGN_MAX`, `NEXUS_REIGN_K`, `NEXUS_REIGN`, `NEXUS_DREAM_MAX`,
   `NEXUS_DREAM`, `NEXUS_SURGE_MAX`, `NEXUS_SURGE`. These are environment-
   variable identifiers still consumed by absorbed code in
   `compiler/{reign,swarm,molt,wake,forge,surge,...}.hexa` (verified via grep).
   They are symbol names, not project references — renaming them would require
   a coordinated edit across `compiler/*` plus shell envs.
2. Line ~1364 (health subcommand `all`): descriptive comment
   `"atlas 헬스체크 실행 (nexus 절차는 absorbed/archived)"` — explains the scrub.
3. Line ~1683 (autonomous.execution.cli_note): dated absorption note
   `"2026-05-13: nexus 흡수, smash/free/drill/omega 등 모두 hexa 네이티브 서브커맨드."`

## bash field strategy: option (b) DROP

Each absorbed command (smash, free_dfs, autonomous.triggers.smash,
autonomous.triggers.free) had a `bash` field invoking
`shared/bin/exec_validated <verb> ... shared/blowup/<x>.hexa ...`. These
**dropped entirely** — `cli_equivalent` (always `hexa <verb> --seed ...`) is
the canonical invocation now.

Rationale:
- Path semantics differ — old bash invoked exec_validated wrapper for an
  absorbed engine path. New `hexa <verb>` is the dispatch entry; cmd_gate +
  audit are wired into the top-level dispatch in `self/main.hexa`.
- `gate/hexa_url.hexa::cmd_must_invoke` reads `execution.entry` first, then
  `execution.cli_equivalent`, then `must_invoke`. None of these is `bash`, so
  dropping `bash` does not affect dispatch.

For non-absorbed commands (status, idea.blow, autonomous.triggers.todo) where
`bash` is still useful, I **updated the path** in-place:
- `status.execution.bash`: `shared/blowup/todo.hexa` → `shared/bin/hexa todo`
- `idea.subcommands.blow.action`: `exec_validated smash ... shared/blowup/...`
  → `hexa smash --seed "{text}" --depth 3`
- `autonomous.triggers.todo.bash`: `shared/blowup/todo.hexa` → `hexa todo`

## Other notable scrubs

- `"id": "nexus-commands"` → `"hexa-commands"`
- `preflight_all_repos.applies_to` — removed `"nexus"` from projects array
- `preflight_anima_only.description` — removed `nexus/` from project list
- `health.subcommands.nexus` — entry dropped (`nexus_ensure_running.hexa` is
  archived); `health.subcommands.all` action prose updated.
- `project_todo_ssot.nexus: shared/config/core.json` — entry removed.
- `roi.project_detect` — `$NEXUS → nexus` → `$HEXA_LANG → hexa-lang`;
  `공유 shared/ 내에선 nexus` → `... 내에선 hexa-lang`
- `mem.ssot` — `-Users-ghost-Dev-nexus/memory/MEMORY.md` →
  `-Users-ghost-core-hexa-lang/memory/MEMORY.md`
- `extreme_sync.doc_url` + post viewer — `dancinlab.github.io/nexus/...` →
  `dancinlab.github.io/hexa-lang/...`
- `loop.description` — `NEXUS-6 7프로젝트` → `HEXA 프로젝트 패밀리`
- `roadmap.*` — `NEXUS 창발` → `hexa 창발` (4 occurrences)
- `surge.rules` — `engine ≠ nexus` / `engine = nexus` → `engine ≠ hexa` /
  `engine = hexa`
- `dispatch_rules.gate_policy` — `shared/bin/exec_validated 가 래핑` →
  `hexa-native dispatch ... 가 cmd_gate + audit log 래핑`
- All `cli_equivalent` parentheticals (`(nexus-cli passthrough, ...)`) — stripped.
- All `nexus <verb> --seed` / `~/.hx/bin/nexus <verb>` / `nexus-cli <verb>` —
  rewritten to `hexa <verb>`.
- For each absorbed verb (smash, free, omega, drill, canon, forge, molt, wake,
  swarm, reign, dream, surge), `execution.engine` rewritten from
  `internal — cmd_X` or `shared/blowup/...` to `compiler/<x>/<x>.hexa (...)`.

## Validation

- `python3 -c "import json; json.load(open('gate/commands.json'))"` →  pass
  (`id=hexa-commands`)
- `grep -c "nexus"` → 28 (all `NEXUS_*` env vars + 2 descriptive annotations)
- `grep -c "shared/blowup"` → 0
- `grep -c "nexus-cli"` → 0
- `git diff --stat` → 81+ / 91- (lines 1949 → 1939)

## Gate-machinery compatibility

- `gate/hexa_url.hexa::cmd_must_invoke` uses jq path
  `.commands[<name>].execution.entry // .execution.cli_equivalent // .must_invoke`.
  All three fields preserved on every command. Now they return
  `hexa <verb> --seed "{seed}" ...` instead of `nexus <verb> ...`, which is
  the correct new dispatch syntax (hexa binary on PATH at `~/.hx/bin/hexa`,
  with top-level dispatch in `self/main.hexa` recognising smash/free/drill/
  omega/swarm/reign/molt/wake/forge/canon/dream/surge).
- `gate/prompt_scan.hexa` reads `commands.json` schema-agnostic (json_parse).
  Field names unchanged. NOTE: `prompt_scan.hexa:562,567,569` still print
  `~/.hx/bin/nexus drill` / `... omega` in advisory text — left untouched per
  task constraint "Don't touch other files". User may follow up.

## Commands not cleanly scrubbed

None. Every command entry still parses + dispatches; only the cosmetic
`bash` field was dropped on absorbed commands (acceptable since `entry` /
`cli_equivalent` are the dispatch SSOTs that gate machinery reads).
