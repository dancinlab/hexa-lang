# inbox_for_bedrock — advisory for downstream `~/core/bedrock`

> Mirrored — not authoritative. The authoritative record lives in this
> repo: `SPEC.yaml` → `stdlib_evolution.inbox_protocol`.

## Status: inbox-routing retired

The internal `inbox/` staging folder has been abolished. Bedrock
workflows no longer route upstream `hexa-lang` changes through an inbox
manifest — upstream patches now flow through the **normal PR workflow**.

Cross-repo handoffs (a different mechanism — when one repo hands a gap or
request to another) are tracked by the root `INBOX` domain
(`INBOX.md` / `INBOX.log.md`) in this repo.

## Required steps (current)

1. Open an external `hexa-lang` session, ship the change to `main` as a
   single focused PR.
2. Downstream repos (orpheus, wilson, others) pull `hexa-lang` and
   unstub the consumer site that was waiting on the change.

## Quick reference — tree responsibilities

| Tree           | Current responsibility                                                |
|----------------|-----------------------------------------------------------------------|
| `stdlib/`      | shared helpers; both trees consume                                    |
| `compiler/`    | new ground-up native compiler (RFC-018); stage 0 → 3 bootstrap        |
| `self/`        | existing self-hosted toolchain; remains authoritative until stage 3   |
| `self/native/` | C bridge (`hexa_cc.c`, FFI shims) used by the existing self-host      |

## Historical record

The frozen patch manifest and append-only audit trail were rehomed
(git mv, history preserved):

- `archive/patches/PATCHES.yaml` — frozen manifest
- `archive/patches/manifest_log.jsonl` — append-only audit trail
- `archive/patches/` — patch reports and `archive/`
