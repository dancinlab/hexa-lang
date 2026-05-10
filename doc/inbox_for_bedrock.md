# inbox_for_bedrock — advisory for downstream `~/core/bedrock`

> Brief advisory the bedrock repo can mirror into its own spec.
> Mirrored — not authoritative. The authoritative copy of the inbox
> protocol lives in this repo: `SPEC.yaml` →
> `stdlib_evolution.inbox_protocol`.

## Purpose

Bedrock workflows that need an upstream change to `hexa-lang` (language
feature, stdlib helper, runtime fix) MUST route the patch through this
repo's `incoming/` inbox until the new native compiler binary reaches
its stage 3 fixed point. This avoids silent drift between the two
coexisting trees:

- `self/`     — existing self-host (transpiled through `hexa_cc.c`)
- `compiler/` — new ground-up native compiler (RFC-018)

The two trees share `stdlib/`. A stdlib patch landed against only one
tree's selftest matrix will pass locally but break the other on next
bootstrap.

## Required steps

1. Open an external `hexa-lang` session, ship the change to `main`
   (single focused commit).
2. Add an entry to `incoming/PATCHES.yaml` with `id`, `source_commit`,
   `source_files`, `compiler_impact`, `selftest_delta`, and the
   primary `downstream_consumer`.
3. Run `tool/inbox_sync.hexa` to verify the entry is well-formed and
   that recorded `source_files` exist on disk.
4. Downstream repos (orpheus, wilson, others) pull `hexa-lang` and
   unstub the consumer site that was waiting on the patch.

## Quick reference — tree responsibilities

| Tree           | Current responsibility                                                |
|----------------|-----------------------------------------------------------------------|
| `stdlib/`      | shared helpers; both trees consume; patches flow through inbox        |
| `compiler/`    | new ground-up native compiler (RFC-018); stage 0 → 3 bootstrap        |
| `self/`        | existing self-hosted toolchain; remains authoritative until stage 3   |
| `self/native/` | C bridge (`hexa_cc.c`, FFI shims) used by the existing self-host      |

## Sunset

This advisory and the inbox itself retire when
`compiler/main.hexa` hits the stage 3 self-host fixed point
(byte-equal output across two consecutive bootstrap stages — see
`SPEC.md` §bootstrap stage3 fixpoint). After that, upstream patches
land through the normal PR workflow and bedrock can drop the
inbox-routing requirement.

The trigger is recorded canonically at:

```
SPEC.yaml
  stdlib_evolution:
    inbox_protocol:
      sunset_trigger: stage_3_fixed_point
```

When that field flips (or the section is removed), bedrock workflows
SHOULD remove the inbox-routing requirement at the next sync.
