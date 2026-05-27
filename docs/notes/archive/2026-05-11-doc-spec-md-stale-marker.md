# doc/spec.md — stale v0.1 marker added (owner review)

Date: 2026-05-11
By: agent (3-small-tasks batch, task B)

## What

`doc/spec.md` (lowercase, tracked; also surfaced as `doc/SPEC.md` on
case-insensitive macOS — **same inode**, single tracked path) is the
original Korean-language **v0.1 language spec draft** (`# HEXA-LANG 언어
사양서 v0.1`). Last substantive touch: 2026-04-20 (`feat(#7) @depth(τ=4)`).

It is **superseded** by the repo-root `SPEC.md` (English, schema_version 1,
generated from `SPEC.yaml` the SSOT). The two have entirely different shape,
language, and currency.

## Action taken

- Added a `> **SUPERSEDED — historical v0.1 draft.**` callout block
  immediately under the H1 in `doc/spec.md`, pointing at `../SPEC.md` /
  `../SPEC.yaml`.
- **No content removed.** The file still holds the unique n=6 arithmetic
  derivation rationale (σ·φ = n·τ ⟺ n=6, the 14 design-constant tables)
  and the BT-hypothesis appendix (BT-33/39/42/54/56/58/67), which are not
  currently carried into root `SPEC.md`.

## Owner decision needed

1. Migrate the unique n=6 derivation + BT appendix into root `SPEC.md`
   (or a dedicated `doc/n6_derivation.md`), then `git rm doc/spec.md`.
   — OR —
2. Keep `doc/spec.md` as a permanent historical artifact with the marker.

Not deleted now because the n=6/BT content is not provably duplicated
elsewhere; the `@depth(τ=4)` section *is* also in
`docs/phase_beta_parser_ext_spec.ai.md`.
