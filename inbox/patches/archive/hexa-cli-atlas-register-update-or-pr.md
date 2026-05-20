# `hexa` CLI subcommand — act on an atlas-citation signal (`update || PR`)

> **Status:** resolved-ssot (2026-05-20). Both arms wired and measured. `hexa atlas pr`
> (2026-05-19) opens the PR path from an existing staging shard; `hexa atlas register
> --from-verify <fn> <n> <v> [--auto-pr]` (2026-05-20) closes the loop with the DIRECT
> path the user asked for — in-memory AtlasNode generation folded straight into
> `compiler/atlas/embedded.gen.hexa` (the binary-built-in atlas SSOT, @D
> g_atlas_binary_builtin), then `gh || api` PR. **No `.n6` intermediate at all.** The
> legacy `register <file.hexa>` mode (lex→parse a source file for `@discover`
> annotations) is still STUB and tracked separately — it needs the compiler frontend
> pulled into a `tool/atlas_register.hexa` companion. The `--from-verify` arm is the
> common path now: every closed-form `hexa verify` discovery reaches the embed in
> ONE command.

**From:** wilson (downstream) — 2026-05-13. Follow-on to two earlier notes:
`hexa-oneliner-install-should-link-source-repo.md` (the one-liner install should clone+link the
hexa-lang source repo) and `hexa-cli-help-stale-after-absorption.md` (`hexa --help` /
diagnostics should advertise the surface). This one closes the loop: there should be a CLI
verb that *acts* on the signal.

## The gap

`hexa build` / `hexa lint` emits:
- **HX8004** (Error) — a `@verify`/`@law` fn, or one whose body references `L[*]`, has no atlas
  binding. Message now says: "`@implements(L[id])` to cite an existing law, or `@discover(kind="L")`
  to register a new one (upstream = update || PR)."
- **HX8001** (Error) — `@implements(L[id])` cites an L the merged atlas doesn't have. Message:
  "fix the citation id, or register it: `@discover(kind="L")` (upstream = update || PR)."

…but **"update || PR" is currently a manual dance**: cd to the (now-linked) hexa-lang repo, run
`compiler/discover/` to produce `atlas.proposed.<date>.n6`, run `promote.hexa` to fold
proposed → live and emit `atlas.append.<date>.n6`, then either commit (if you own the repo) or
`gh pr create`. Every downstream — wilson's `governance` plugin in particular (operating
principle `hexa-first`: "fix it in hexa-lang upstream — `update || PR`") — would benefit from
this being one command.

## Proposed: `hexa atlas register` + `hexa atlas pr` (extends the existing `hexa atlas`)

`hexa atlas` already has `hash | stats | lookup [P|C|L|E] <id> | dump [P|C|L|E] [--json]`. Add:

- **`hexa atlas register <file.hexa>[#<fn>]`** — for each `@discover(kind="L")` (or `kind="C"`)
  fn in the file (or the named one): run the ε self-proof / `compiler/discover/{discover,staging}.hexa`
  → write/append `atlas.proposed.<date>.n6` *in the linked hexa-lang repo* (path from
  `hexa repo path`, per the install note). Prints the proposed node id(s) + proof hash + the
  `/tmp/_promote_manifest.<date>.txt`-style summary. Idempotent (fingerprint dedup → alias).

- **`hexa atlas promote`** — run `compiler/discover/promote.hexa`: fold `atlas.proposed.*` → live
  atlas, emit `atlas.append.<today>.n6`. Then `git -C <repo> add atlas.append.<today>.n6 &&
  git commit -m "atlas: <ids> (via hexa atlas promote)"`. This is the **`update`** arm — only
  works if you have write access to the repo (owner / a fork you control).

- **`hexa atlas pr`** — same as `register` + `promote` but instead of committing to the repo
  directly, creates a branch + commit + `gh pr create` against the hexa-lang origin (upstream).
  This is the **`PR`** arm — the fallback for non-owners. (For an *agent* with no `gh` auth /
  no repo write, this degrades to: write the shard + print "ready to PR — run `gh pr create` from
  `<repo path>` on branch `<branch>`", or to the AGENTS.md `inbox/patches/` handoff note path.)

- **`hexa atlas register --dry-run`** — produce the proposed node, print it, touch nothing.

So the downstream flow becomes: hit `HX8004` → add `@discover(kind="L")` → `hexa atlas register
mymod.hexa` → `hexa atlas promote` (if you own hexa-lang) **||** `hexa atlas pr` (else). Each
run grows the atlas (constants + formulas) — SPEC §10.

## Notes / open questions for the implementer

- Where does `register` write the `.proposed` shard — the linked source repo (needs `hexa repo
  path` from the install note), or a local staging dir that `promote`/`pr` then sync? Source-repo
  is simpler if the install reliably links it.
- `promote` needs the source repo's `compiler/discover/promote.hexa` — i.e. needs the source tree,
  not just `~/.hx/bin/`. Again leans on the install-links-the-repo note.
- Conflict handling: `register` should surface `promote.hexa`'s "id-first wins / fingerprint
  alias / new" classification rather than silently swallowing it.
- Constants (`C` nodes): the same flow, `kind="C"`. (wilson's diagnostics treat "상수, 수식" =
  C + L together.)
- Should `hexa lint` gain a `--fix` that, on an HX8004, *offers* to run `hexa atlas register`? Nice
  but separate; this note is just the `atlas register|promote|pr` verbs.

No wilson-side change; filing per the AGENTS.md hexa-lang handoff protocol. Related:
`hexa-oneliner-install-should-link-source-repo.md`, `hexa-cli-help-stale-after-absorption.md`.

---

## Resolution (2026-05-19) — `hexa atlas pr` wired; `register` still STUB

**Implemented:** `tool/atlas_cli.hexa::cmd_pr` (was a STUB that just printed manual
steps + `exit(3)`).

`hexa atlas pr --staging <file.n6> [--atlas-root <repo>] [--base <branch>]
[--branch <name>] [--title <text>]` now:

1. resolves the atlas-root (same shape as `promote` — `$HEXA_LANG` else cwd);
2. creates a fresh PR branch (`atlas-pr-<UTC-stamp>`) in that clone, so the
   append shard lands on the branch, not on whatever was checked out;
3. folds the staging shard into the live atlas by reusing the existing
   `promote_to_atlas` machinery (writes `atlas.append.<today>.n6`);
4. `git add` + `git commit` the append shard on the branch;
5. tries `gh pr create` against origin; on success prints the real PR URL.

**Honest degraded path (g3) — measured PASS, never fakes a PR:**

- *no `git` / atlas-root not a repo* → still folds the shard, prints the exact
  `git switch -c … && git add … && git commit … && gh pr create …` commands.
  Exit 0 (shard written).
- *`git` ok, `gh` absent or `gh pr create` fails (no auth / no push / offline)*
  → branch + commit succeed locally; prints `git push -u origin <branch>` +
  the exact `gh pr create` line. States plainly "**NO PR was opened**". Exit 0.
- *`gh pr create` returns 0* → and only then prints "PR opened — <url>".

`exec()` only captures stdout, so exit status is recovered with the
`( cmd ) && echo __OK__ || echo __FAIL__` marker pattern — the try-CLI-or-fallback
shape permitted by @D g5 (hexa-native-only allows shelling to `git`/`gh`).

**Measured:** parse-gate (`hexa_v2 tool/atlas_cli.hexa`) PASS; full build via
`hexa build` PASS; `pr --help` + two end-to-end dry-runs (non-git atlas-root →
degraded; real git repo → branch+commit, `gh` degrade-after-commit) all PASS.

**LIMITATION — `hexa atlas register` left STUB.** Turning a `@discover`-annotated
`.hexa` source file into a staging shard needs the compiler frontend
(`compiler/lex/*` + `compiler/parse/parser.hexa::parse` + `compiler/discover/`)
wired into a `tool/atlas_register.hexa` companion — out of scope for the `pr`
arm, which was deliberately scoped to consume an *already-staged* `.n6` shard
(e.g. one written by `hexa atlas append-witness`). The end-to-end downstream
flow `register → pr` therefore still requires the manual `append-witness` step
in place of `register`. Status: **partially-resolved-ssot**.

## Resolution part 2 — `register --from-verify` (2026-05-20)

User directive: ".n6 파일같은거 전혀안통하고 바로 PR 하도록" (no `.n6` file in the path
at all, go straight to PR) + "변환 말고 / 노드 생성 코드" (NOT a converter — node-
construction code). Implemented as the second arm of `cmd_register` in
`tool/atlas_cli.hexa`:

```
hexa atlas register --from-verify <fn> <n> <v> [--auto-pr]
hexa atlas register --from-verify <fn> <a> <b> <v> [--auto-pr]   (2-op)
                                  [--atlas-root <repo>] [--base <branch>]
                                  [--branch <name>] [--title <text>] [--id <id>]
```

Flow (zero `.n6` files anywhere):

1. **Recompute in-process.** `_recompute_register` / `_recompute2_register` mirror
   `tool/verify_cli.hexa::_recompute` over `compiler/atlas/symbolic/congruence_chain_engine`.
   Same calc, same result; refusing to register on 🔴 FALSIFIED / 🟠 INSUFFICIENT.
2. **In-memory AtlasNode struct-literal construction.** `_build_raw_F` builds the
   tape-form `@F` body (`= fn(args) = v :: formula [d=YYYY-MM-DD active]` + verified-by +
   cite + provenance). `_build_node_struct_text` then emits the EXACT struct-literal
   text that `tool/atlas_embed_gen.hexa::embed_atlas` would emit for one `AtlasNode`
   — kind / id / escaped raw / source_file / source_line / GradeInfo / EdgeInfo. This
   is the storage form. Not a `.n6` file, not a converter — the hexa-source-form
   `AtlasNode` literal that the next compile folds into the binary built-in atlas.
3. **Direct fold into the embed SSOT.** `_fold_into_embedded` reads
   `compiler/atlas/embedded.gen.hexa`, finds `pub let ATLAS_F_NODES: [AtlasNode] = [`,
   walks forward to the section's closing `]`, dedup-by-id (textual `id: "<id>"`
   scan), and splices the new line — adding a `,` to the prior trailing `}` when
   the section is non-empty. Writes back. Per @D g_atlas_binary_builtin this IS
   the canonical absorption path; the file is compile-time embedded.
4. **PR via `gh || api`.** `_branch_commit_pr` reuses the same fallback chain as
   `cmd_pr`: branch + `git add embedded.gen.hexa` + commit, then `gh pr create`,
   then the GitHub REST API (`POST /repos/<owner>/<repo>/pulls`, HTTP 201). Honest
   degrade preserved — a PR is NEVER claimed opened unless `gh` rc=0 or HTTP 201.

Status: **resolved-ssot**. The `<file.hexa>` arm of `register` remains separately
tracked; the user-asked-for direct path is closed.
