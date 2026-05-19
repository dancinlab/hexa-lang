# `hexa` CLI subcommand — act on an atlas-citation signal (`update || PR`)

> **Status:** partially-resolved (2026-05-19). `hexa atlas pr` is now wired and
> measured (see Resolution at the bottom). `hexa atlas register` is still STUB —
> it needs the compiler frontend (`compiler/lex/*` + `compiler/parse/parser.hexa`)
> pulled into a `tool/atlas_register.hexa` companion; the `pr` arm was scoped to
> operate on an already-staged `.n6` shard so it did not require `register`.

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
