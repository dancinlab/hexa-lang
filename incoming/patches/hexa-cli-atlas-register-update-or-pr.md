# `hexa` CLI subcommand — act on an atlas-citation signal (`update || PR`)

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
  `<repo path>` on branch `<branch>`", or to the AGENTS.md `incoming/patches/` handoff note path.)

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
