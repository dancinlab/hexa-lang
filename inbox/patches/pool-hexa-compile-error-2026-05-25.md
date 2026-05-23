---
slug: pool-hexa-compile-error-2026-05-25
status: open
severity: P1
discovered: 2026-05-25
discoverer: claude/demiurge LPA cycle 4
filed_from: demiurge (cross-domain: LPA · ISR · NOREFLOW · DAPTPGX · HERPES)
---

# pool.hexa compile error — undeclared identifier (cross-domain wall)

## Summary

`pool` CLI (top-level: `pool list` · `pool on <host> <cmd>` · etc.) currently
fails to compile at link stage. Multiple demiurge domains (LPA / ISR /
NOREFLOW / DAPTPGX / HERPES) hit this wall during `V3` numerical
simulation dispatch (per @D d7 + commons g9), forcing fallback to direct
`ssh ubu-1` / `ssh ubu-2` heredoc routes.

## Symptom

```
$ pool list
error: `hexa build /Users/ghost/.hx/packages/pool/bin/pool.hexa` failed (compile error).
  [1/2] HEXA_MEM_CAP_MB=4096 hexa_v2 ... pool.hexa
    warning: '${...}' JS template syntax not supported at line 703:17
    warning: '${...}' JS template syntax not supported at line 742:5
    warning: '${...}' JS template syntax not supported at line 921:53
  [2/2] clang -O2 ... pool.c → link failure (undeclared identifiers)
```

Other agents (LPA V3a · V3c · V3b cross-reports) consistently report:
- `pool.hexa:707/710/720` — `ks/i undeclared identifier` (per V3c agent
  trace)
- Multiple `${...}` JS-template syntax warnings cascade into clang link
  failure

## Cross-domain confirmation (4+ domains)

| Domain | Cycle | Sim agent | Fallback used |
|---|---|---|---|
| LPA | cycle 4 V3a | siRNA ODE on ubu-1 | `ssh ubu-1` ✅ 0.58s |
| LPA | cycle 4 V3b | MR/IVW MC on ubu-1 | `ssh ubu-1` ✅ 0.06s |
| LPA | cycle 4 V3c | NHIS ICER MC on ubu-2 | `ssh ubu-2` ✅ 0.054s |
| ISR | cycle 5 V3 | 3 light pipelines | `hexa cloud copy-to/run` ✅ |
| NOREFLOW | M12/V3 | 4 simulation tracks | `ssh ubu-{1,2}` ✅ |

→ **3-of-3 LPA pool agents independently hit + worked around** the same
pool.hexa compile regression in a single cycle.

## Impact

- **Direct**: `pool list` / `pool on <host>` 모두 unusable from CLI surface
- **Indirect**: forces every demiurge domain doing V3 numerical work to
  write their own ssh wrappers (DRY violation) and embed pool host names
  in plain text
- **Cross-tool consistency** (per /gap F8): `pool` and `hexa cloud` are
  the two canonical remote-exec verbs (g8 + g9) — `pool` being broken
  means g9 path is non-canonical right now

## Reproduction

```bash
hexa --version          # 0.1.0-dispatch
pool list 2>&1 | head -3
# → "error: hexa build ...pool.hexa failed (compile error)."
```

## Suggested fix paths (in priority order)

1. **P0 — Fix `${...}` template literal usages** in `pool.hexa` at lines
   703 / 742 / 921 (replace with `format("...{}", x)` per hexa-v2 warning).
   This is likely the chain-root: the JS template strings get codegen-
   replaced with placeholder symbols that fail link-stage as undeclared.
2. **P1 — Resolve `ks/i undeclared identifier`** at lines 707/710/720
   reported by V3c agent (likely related: loop iterator scope after
   template fixes).
3. **P2 — Add CI smoke test**: `pool list` (no-op verbs) should compile
   on every `hexa-lang` commit. Currently no enforcement → regression
   slipped in.

## Workaround (current standard)

Per memory `feedback_demiurge_assets_simulation_mandatory` + d7, all
demiurge V3 sim agents use direct `ssh ubu-{1,2,mini} '...'` heredoc.
Works but bypasses g9 abstraction. See LPA V3a/V3b/V3c source for
canonical pattern.

## Verification (post-fix)

Re-run any of the LPA V3 simulations via `pool` CLI:

```bash
pool on ubu-1 'python3 ~/lpa_v3a/v3a_sirna_ode.py'
# expected: same JSON output as ssh route (V3a 0.58s · V3b 0.06s · V3c 0.054s)
```

## Cross-reference

- `demiurge/LPA/verify/V3a_sirna_kinetics.md` — pool wall + ssh fallback
- `demiurge/LPA/verify/V3b_mr_ivw_mc.md` — same pattern
- `demiurge/LPA/verify/V3c_nhis_icer.md` — same pattern
- `demiurge/CLI+COCKPIT.md` — M5 synthesize surface (~) — pool partial
- `hexa-lang/inbox/patches/pool-cli-compile-errors-*.md` — ISR similar
  patch (if exists; may be duplicate of this one — please merge)
