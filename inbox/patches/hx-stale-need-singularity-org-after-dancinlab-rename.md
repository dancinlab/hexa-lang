# `hx` still points at the old `need-singularity` org after the dancinlab rename

**From:** void (downstream) — 2026-05-18, during void's grid-only beta launch prep,
verifying that the README's `hx install void` actually resolves the right repo.

**One concept:** the org was renamed `need-singularity` → `dancinlab` (see void commits
`485665359` / `2f3d631cd`, and `gh repo view need-singularity/void` now reports
`url: https://github.com/dancinlab/void`). The `hx` toolchain script was not updated to
follow the rename, so name-resolution still targets the stale org:

`tool/pkg/hx` (the SSOT; `~/.hx/bin/hx` is a stale copy of it):

- **line 10** — `REGISTRY_REMOTE="https://raw.githubusercontent.com/need-singularity/hexa-lang/main/pkg/registry.tsv"`
  → the registry itself is fetched from the old org.
- **line 18** — `HX_ORGS_DEFAULT="hexa-pkg need-singularity dancinlife"`
  → probe order has `need-singularity` but **no `dancinlab`**; `dancinlife` is the git
  author handle, not the GitHub org. So `hx install void` resolves
  `github.com/need-singularity/void` and only reaches `dancinlab/void` via GitHub's
  org-rename redirect — which is not permanent (breaks if the old org is deleted or
  re-registered by anyone else).

Symptom observed: `hx where void` → `found: https://github.com/need-singularity/void`.
The same stale mapping is then frozen into `~/.hx/cache/resolve.tsv`
(`void` and `qmirror` rows both point at `need-singularity`).

**Ask:** in `tool/pkg/hx`,

1. line 10 — `need-singularity/hexa-lang` → `dancinlab/hexa-lang` for `REGISTRY_REMOTE`.
2. line 18 — `HX_ORGS_DEFAULT="hexa-pkg dancinlab need-singularity dancinlife"`
   (put `dancinlab` first so fresh resolves hit it directly; keep `need-singularity`
   as a lower-priority fallback so any not-yet-migrated assets still resolve via
   redirect rather than failing hard).
3. consider invalidating stale `~/.hx/cache/resolve.tsv` rows on an org-default change
   (e.g. bump a cache-version token, or have `hx where`/`install` re-probe when the
   cached host is an org no longer in `HX_ORGS`). Otherwise users who already resolved
   under the old default keep the frozen `need-singularity` mapping.

Downstream impact: void's README says `hx install void` (name form, by design — see
void VOID.md Decision: README install command kept as `hx install void`). That command
is only correct once `hx`'s default probe order includes `dancinlab`. Until then the
beta install path depends on a non-permanent GitHub redirect.

No void-side change; filing per the AGENTS.md hexa-lang handoff protocol. The README
stays `hx install void` per the downstream decision. Related:
`hexa-oneliner-install-should-link-source-repo.md`, `hexa-cli-help-stale-after-absorption.md`.
