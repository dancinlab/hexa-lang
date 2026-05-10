# macOS Mach-O Gate

Decision date: 2026-05-09. Status: Phase A landed (this repo). Phase B is
the user's separate session that edits `$HOME/.hx/bin/hexa`. Phase C
(strict block) is deferred until the hook layer is migrated.

## Why

A snapshot of the macOS host showed 36 live `hexa_interp.real.real`
processes consuming roughly 2.4 GB of RSS in aggregate. Of those, only
**2** were doing actual native Mach-O AOT work (the compiler running
with `--emit=asm`). The remaining **34 (~94%)** were
hooks, handlers, probes, and lints — none of which need native
codegen at all.

The takeaway: most macOS hexa invocations want the stage0 interpreter
path. A small but important minority (release builds, codegen
verification) wants native Mach-O. Today the two paths look identical
at the call site, which makes the choice implicit and easy to get
wrong.

The Mach-O gate makes the intent **explicit**.

## The flag and the env var

A macOS hexa invocation opts in to native Mach-O codegen by either:

- passing `--Mach-O` on the command line, or
- exporting `HEXA_TARGET_MACHO=1` in the shell.

If neither is present, the `$HOME/.hx/bin/hexa` wrapper emits an
`ai-native:` warning to stderr (English only) and continues. No
behaviour change otherwise. This is **warn-only** (block 0) for the
duration of Phase B.

## Phase B install (user runs in a separate session)

```sh
# 1. Take a rollback snapshot.
cp $HOME/.hx/bin/hexa $HOME/.hx/bin/hexa.bak.2026-05-09

# 2. Drop the reference wrapper into place.
cp tool/wrappers/hexa_top_wrapper.sh $HOME/.hx/bin/hexa

# 3. Make sure it's executable.
chmod +x $HOME/.hx/bin/hexa
```

Rollback if anything goes wrong:

```sh
cp $HOME/.hx/bin/hexa.bak.2026-05-09 $HOME/.hx/bin/hexa
```

## Phase A / B / C roadmap

| Phase | Where             | What                                      | Status     |
| ----- | ----------------- | ----------------------------------------- | ---------- |
| A     | repo              | reference wrapper + lint + SPEC + doc     | landed     |
| B     | user session      | actual `$HOME/.hx/bin/hexa` edit          | in flight  |
| C     | follow-up         | warn -> hard block; require explicit flag | deferred   |

Phase C is gated on the hook-layer migration: once
claude-bind hooks (and similar non-AOT call sites) all explicitly
declare their intent (interpreter vs Mach-O), the warn-only gate is
safe to promote into a strict block.

## When to actually use `--Mach-O`

- **Release binary builds** — `hexa build --emit=exec --Mach-O ...`
  produces an arm64 Mach-O binary you can ship.
- **Codegen verification** — when you want to confirm that the
  native backend is exercised end-to-end (e.g., for a benchmark or
  a regression that only manifests in compiled output).
- **AOT performance work** — anything where you actually care about
  the difference between the interpreter and the native code path.

For everything else — hooks, handlers, probes, lints, day-to-day
script-style invocation — leave the flag off. The warning is
informational, not corrective.

## Cross-references

- Reference wrapper: `tool/wrappers/hexa_top_wrapper.sh`
- Lint rule (`LINT-MACHO-1`): `tool/lint_macho_gate.hexa`
- SPEC section: `macos_machO_gate` in `SPEC.yaml`
