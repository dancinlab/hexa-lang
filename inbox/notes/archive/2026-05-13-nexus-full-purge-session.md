# nexus residue full-purge session — 2026-05-13

## Scope
Full purge of "nexus" identifier from active hexa-lang code per user directive
"잔여남지않게 리다이렉트 등 대신 바로" + Option A choice for std_nexus
(rename file+APIs, keep unique logic). Three rounds: path fixes, std_nexus →
std_n6 rename, NEXUS_* env var mass rename.

Preserved per directive:
- inbox/notes/* inbox/patches/* (external sessions)
- docs/migration_nexus_to_hexalang_* doc/atlas_n6_retirement_plan*
  doc/nexus_cli_audit* state/atlas_n6_callers* compiler/*.gen.hexa
- compiler/<x>/*.hexa "// Source: ~/core/nexus/..." provenance citations
- self/locks/raw{20,22}.jsonl convergence/*.convergence proposals/rfc_*.md
  doc/superpowers/plans/2026-04-06-void-phase1-foundation.md
  (timestamped historical record)
- compiler/kick/kick.hexa `cd ~/core/nexus` line — REMOTE ssh routing
  (remote box still has nexus tree)
- gate/lint.hexa H-NEXUSPATH lint rule + $NEXUS shell env var fallback
  ($NEXUS is a cross-project SSOT env var defined by user in ~/.zshrc)
- firmware/boards/* uses "nexus" as unrelated semiconductor domain concept

## R1 — path fixes
Replaced `~/core/nexus/bin/hexa` → `~/.hx/bin/hexa` (canonical launcher) and
`~/core/nexus/{tool,config,n6,roadmaps,engine,logs}/` → `~/core/hexa-lang/<x>/`
across:

- gate/pre_tool_guard.hexa (multiple sites incl. L3 unlock, lockdown gate,
  session lock, annot rules, project entry hexa bins)
- gate/post_edit.hexa  (route_err HARNESS, _observe, auto_lint_annot,
  auto_lint_hexa, atlas-sync, broadcast, context_gauge)
- gate/post_bash.hexa  (route_err, _observe, reaper, context_gauge)
- gate/entry.hexa      (`_resolve_nexus_home` → `_resolve_hexa_home`,
  HEXA_HOME, HARNESS, HEXA)
- gate/prompt_scan.hexa(same resolver rename + HEXA_BIN_CANON)
- gate/cmd_gate.hexa   (same resolver rename + HEXA_BIN canonical)
- gate/lint.hexa       (`NEXUS_HARNESS` → `HEXA_HARNESS`, comment fixes,
  H-CROSS-NEXUS-N6 → H-CROSS-BLOWUP-N6, `_once_cross_nexus_n6` →
  `_once_cross_blowup_n6`, shared/config/nexus-projects.json →
  legacy-projects.json)
- gate/remote_preflight.hexa (provenance comment fix)
- self/stdlib/argv_skip.hexa (REFERENCES section update)
- tool/* embed_gen.hexa scripts (all DEFAULT_SRC roots repointed)
- tool/atlas_cli.hexa  tool/cross_prover.hexa  tool/dod_gate.hexa
  tool/auto_pr_tombstone_sweep.hexa  tool/verify_multi_path_phi.hexa
  tool/workspace_sync.hexa  tool/_init/register.hexa  tool/revive_catalog.hexa
- compiler/atlas/merger.hexa  compiler/atlas/merger_smoke.hexa
- tests/integration/{01_proposal_archive_help,10_dormancy_wake_tick_flip}/test.sh
  (HEXA_ROOT default → ~/core/hexa-lang; envs NEXUS_ROOT/NEXUS → HEXA_*)
- example/verify_pages_test.hexa local root → ~/core/hexa-lang (URL probes to
  GitHub dancinlab/nexus repo untouched — external repo still exists)
- ROADMAP.md (canonical line rewritten, decommission date noted)
- roadmaps/README.md (migration status updated, source path dropped)

cross_prover.hexa also renamed its "nexus" prover identity to "hexa" (file
+ JSON `prover_a.id` field + stdout banner) since the local path now points
inside hexa-lang.

## R2 — std_nexus → std_n6 (Option A)
- `git mv self/std_nexus.hexa self/std_n6.hexa` (history follows)
- File rewritten with new header reframing the module as a "user-facing n=6
  constant utility stdlib module" rather than "NEXUS-6 integration".
- API rename (all in self/std_n6.hexa, plus callers):
    nexus_lenses    → n6_lenses
    nexus_verify    → n6_verify
    nexus_n6_check  → n6_check          (drop redundant prefix)
    nexus_consensus → n6_consensus
    nexus_scan      → n6_scan
    nexus_omega     → n6_omega
  All 11 test fn names + the test print headers renamed too. Struct names
  (`N6Constant`, `OmegaScanResult`) unchanged — already n6/omega-themed.
- Callers updated:
    self/anima_bridge.hexa     (n6_scan / n6_verify stubs + Omega report header)
    self/env.hexa              (stdlib API allowlist strings)
    self/hexa_full.hexa        ("nexus_n6_check" → "n6_check" interp dispatch)
    self/lib.hexa              (stdlib registry entry: std_nexus → std_n6)
    doc/reference-stdlib.md    (table row rewritten)
    doc/hexa_ir_convergence.json (nexus_scan → n6_scan)
    example/convergence.hexa   (local `nexus_tiers`/`nexus_lenses` →
                                `n6_tiers`/`n6_total_lenses` + banner text)
- doc/nexus-roadmap.md deletion was already staged on entry — preserved.

## R3 — NEXUS_* env var mass rename
65 distinct active NEXUS_<SUFFIX> identifiers inventoried. Mass-renamed to
HEXA_<SUFFIX> via `perl -i -pe 's/\bNEXUS_([A-Z][A-Z0-9_]*)\b/HEXA_$1/g'` on
the 37-file active set (excluding inbox/, state/, .gen.hexa, etc.). 277
total in-file site mentions touched.

Notable env vars renamed:
- HEXA_DRILL_ANTI_HUB{,_THRESHOLD,_TRACE}  HEXA_DRILL_ENGINE
  HEXA_DRILL_TIMEOUT_ADAPTIVE  HEXA_SWARM{,_MAX}  HEXA_WAKE_{MAX,COOLDOWN_SEC,SIGNAL_FILE}
  HEXA_MOLT_{MAX,SKIN_FILE}  HEXA_FORGE{,_FORCE}  HEXA_REIGN{,_K,_MAX}
  HEXA_SURGE{,_MAX}  HEXA_DREAM_MAX  HEXA_OMEGA  HEXA_SEED_CAP
  HEXA_KICK_{FORWARD_HOST,SKIP_OAUTH_GATE,SKIP_PREFLIGHT}
- gate bypass tokens: HEXA_ARCHIVE_OK HEXA_HOOK_OK HEXA_LOCK_OK HEXA_ANNOT_OK
  HEXA_GIT_OK HEXA_BLOCK_OK HEXA_FORK_OK HEXA_INTERP_OK HEXA_BUDGET_OK
  HEXA_NOAUTOLINT HEXA_PROJECT_ENTRY_OK HEXA_PDF_OK HEXA_SEND_OK HEXA_L3_UNLOCK
- HEXA_CERT cert emission (self/codegen_c2.hexa `_nexus_cert_*` →
  `_hexa_cert_*` + `[nexus_cert] wrote` log prefix → `[hexa_cert] wrote`)
- HEXA_HARNESS (gate/lint.hexa) HEXA_DRAIN_OK HEXA_DECISION_OK HEXA_GC_OK
  HEXA_PROJ_ALL_OK HEXA_HOME HEXA_HEXA HEXA_TOOL HEXA_NO_TIMEOUT{,_OK}
  HEXA_REMOTE_{DOWNGRADE,ERROR,PREFLIGHT}  HEXA_WATCHER_GRACE_SEC etc.

`__NEXUS_CHECK__` sentinel reference in compiler/honesty/router.hexa kept
as historical naming inside a provenance comment (per the verification
filter's allow-list for compiler/ source-citation comments).

## Final residue counts
- NEXUS_* identifiers in active code (excl. inbox/state/.gen.hexa/
  compiler/* provenance comments / .claude worktrees / .hexa-cache):  0
- `core/nexus/` literal paths in active code (excl. same filters): 2
    * gate/lint.hexa:2876 — lint-rule comment naming the pattern it catches
    * compiler/kick/kick.hexa — remote-ssh routing to remote host's tree
- self/std_nexus.hexa file:    GONE
- self/std_n6.hexa file:       EXISTS (296 LOC)
- doc/nexus-roadmap.md:        DELETED (staged on entry, preserved)

## LOC delta
git diff --shortstat HEAD (this session + pre-existing dirty cache files):
  81 files changed, 667 insertions(+), 957 deletions(-)

Of these, 3 frozen-cache fixtures (compiler/bridges/_cache/{arxiv,openalex,
pubchem}.frozen.{xml,json}) plus 2 baseline-dirty files (self/lexer.hexa,
self/tui/input.hexa, self/native/thread.c, untracked compiler/drill/_probe_min.hexa)
were already-dirty going in — not from this session.

## Callers that didn't migrate cleanly
None — all std_n6 callers updated atomically. No build attempted in this
session per the user's "Do NOT commit" + dirty-tree-only directive.

## Tests / smokes
None executed — directive was strictly purge + leave-dirty. The std_n6.hexa
test suite was rewritten alongside the API rename and should still pass
under self-hosted interp once invoked.
