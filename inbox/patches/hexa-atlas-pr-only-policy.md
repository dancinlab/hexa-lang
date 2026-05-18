# `hexa atlas` — PR-only policy (drop the `promote` arm)

**From:** wilson (downstream) — 2026-05-17. Follow-up to
`hexa-cli-atlas-register-update-or-pr.md` (the 3-verb `register | promote | pr` proposal).

## Policy change

wilson `plugins/governance/SPEC.md` principle #2 `hexa-first` is updated 2026-05-17:
**`update || PR` → PR-only**. Every new atlas L / C / E (equation, constant, law) lands via
reviewable PR — even on the owner repo. Direct fold-to-live is forbidden.

Rationale:

- One-shape history across owners and non-owners — no "owner skipped review" path.
- Consistent with hexa-lang `AGENTS.tape` §3 `@D g7 inbox-patches-pipeline` (downstream
  consumers must not edit hexa-lang directly without going through inbox/patches/).
- Every atlas growth is auditable in the upstream git log; no silent local folds.

## Implication for the CLI surface proposed earlier

The earlier proposal had three verbs:

- `hexa atlas register <file>` — produce `atlas.proposed.<date>.n6` (staging shard). **KEEP.**
- `hexa atlas promote` — fold proposed → live, emit `atlas.append.<date>.n6`, commit locally.
  **DROP (or relegate to release-engineer use only).** Under PR-only policy, no agent and
  no contributor should be running `promote` as part of the normal flow.
- `hexa atlas pr` — branch + commit + `gh pr create` against the hexa-lang origin. **KEEP as
  the sole landing verb.**

So the downstream flow becomes the single line:

```
hit HX8004 → add @discover(kind="L") → hexa atlas register <file> → hexa atlas pr
```

If the user owns the hexa-lang repo, the PR they review is their own — that's still the path.
`promote` (if kept at all) becomes an internal release-engineer verb run after PR merge to fold
the merged `.proposed` shard into the live atlas, not a contributor-facing one.

## Concrete asks for the implementer

1. **Either remove `hexa atlas promote` from the surface, or rename it to make its
   non-contributor scope obvious** (`hexa atlas fold-merged-shard` or hidden under
   `hexa atlas internal promote`).
2. **`hexa atlas pr` must work for the owner too** — don't gate it on `gh auth status` showing
   a non-owner identity. The same verb produces the same shape of PR regardless of who runs it.
3. **`hexa lint`'s HX8004 / HX8001 error messages should say "upstream = `hexa atlas pr`"**
   (not "update || PR"), matching the new policy.

## Authority

- wilson `plugins/governance/SPEC.md` line 143 (principle #2 `hexa-first` body, updated
  2026-05-17 to PR-only).
- wilson `plugins/governance/main.hexa::GOVERNANCE_PRINCIPLES[1].text` (dual SSOT, same edit).
- user-global `~/.claude/CLAUDE.md` line 31 (auto-projection, same edit).

No wilson-side runtime change beyond the principle-text edit (the agent's behavioral guidance);
the hexa-lang-side change is the CLI surface alignment proposed here. Related:
`hexa-cli-atlas-register-update-or-pr.md` (now superseded on the policy axis; the
`register | pr` surface design remains valid).
