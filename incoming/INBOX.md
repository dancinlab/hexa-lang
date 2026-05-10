# incoming/ — temporary upstream-patch inbox

## Purpose

Temporary staging area for upstream `hexa-lang` patches that need to be
verified across two coexisting trees:

- `self/`     — existing self-hosted toolchain (transpiled through
                `self/native/hexa_cc.c`)
- `compiler/` — new ground-up native compiler (RFC-018 stage 0 → 3)
- `stdlib/`   — shared by both trees

Until the new native compiler binary reaches stage 3 byte-equal fixed
point and is fully self-hosted, upstream `hexa-lang` changes must be
tracked through this inbox so neither tree silently drifts. The inbox is
**not** a long-term mechanism — it retires at sunset.

## Lifecycle

A patch entry walks one of the following statuses:

- `pending_external` — change is being authored in an external session,
                       not yet on `main` of this repo
- `pending`          — commit lives on `main` (or local HEAD) but the
                       inbox entry has not been verified yet
- `applied`          — patch is on `main`, source files exist with the
                       expected layout, both trees have been checked
- `archived`         — entry has aged past the retention window and has
                       been moved into `manifest_log.jsonl` (audit trail)

## How to add a patch

1. Open the external `hexa-lang` session, ship the change to `main`
   (commit). Keep the commit small and focused.
2. Add a `PATCHES.yaml` entry pointing at the commit SHA, listing
   `source_files`, `compiler_impact`, `selftest_delta`, and the primary
   `downstream_consumer`.
3. Run `tool/inbox_sync.hexa` to verify the entry well-forms and that
   the recorded `source_files` exist. The tool reports per-entry status;
   it never modifies files.

## How to retire a patch

Once an entry has carried `status: applied` for a stable period (default
`N_DAYS = 14`), run `tool/inbox_promote.hexa`. The tool:

- moves matured entries from `PATCHES.yaml` into `manifest_log.jsonl`
  with `status: archived` and a `promoted_at` timestamp,
- leaves all files outside `incoming/` untouched.

`manifest_log.jsonl` is append-only; it is the durable audit trail.

## Sunset

This inbox retires when the new native compiler binary settles — i.e.,
`compiler/main.hexa` reaches the stage 3 self-host fixed point
(byte-equal output across two consecutive bootstrap stages, see
`SPEC.md` §bootstrap stage3 fixpoint). At that point the dual-tree
verification need disappears and upstream patches flow through the
normal PR workflow. The trigger is recorded in `SPEC.yaml` under
`stdlib_evolution.inbox_protocol.sunset_trigger`.
