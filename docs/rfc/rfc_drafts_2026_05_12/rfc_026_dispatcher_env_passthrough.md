# RFC 026 — Cross-host dispatcher env passthrough + project `.hexarc`

- **Status**: draft
- **Date**: 2026-05-12
- **Severity**: HIGH (cross-host UX)
- **Priority**: P1
- **Source convergence**: HEXA_NATIVE_INFERENCE.md Phase 1.2
- **Source session**: Mac → aiden hexa offload — HEXA_LANG lost in transit

## Problem

When `hexa run` is invoked from Mac shell, the resource-tcp dispatcher offloads to aiden (ubu1) host. The aiden runtime then attempts to resolve `import "stdlib/safetensors.hexa"` — but `HEXA_LANG` env from Mac shell is **not forwarded**:

```
[module_loader] FATAL module not found: stdlib/bytes (from .../safetensors.hexa)
  searched:
    HEXA_LANG=<unset>
    HEXA_STDLIB_ROOT=<unset>
    project_root=<none>
    caller_dir=/home/aiden/core/hexa-lang/stdlib
    cwd=/tmp/resource-tcp-XXXX
```

Mac shell has `HEXA_LANG=/Users/ghost/core/hexa-lang` set, but the path is **Mac-local** and would be wrong on aiden anyway. So forwarding the literal value is also broken — need a smarter mechanism.

## Falsifier

- F-026-1: `hexa run` from Mac with no env → aiden side resolves stdlib imports without `HEXA_LANG` workaround
- F-026-2: project-level `.hexarc` (TOML/JSON) at repo root specifies stdlib path per-host
- F-026-3: env passthrough whitelist (HEXA_*, ANIMA, NEXUS, etc.) auto-forwarded by resource-tcp

## Proposal

Three complementary mechanisms:

### Mechanism 1 — `.hexarc` project config

At project root (where `git rev-parse --show-toplevel` ends), look for `.hexarc`:

```toml
# .hexarc — anima project hexa config
[lang]
stdlib_path = "$HEXA_HOME/core/hexa-lang/stdlib"  # host-aware var expansion
project_imports = ["./stdlib", "./tool"]

[mem]
default_cap_mb = 8000  # ML workload

[dispatcher]
prefer_local = true  # don't offload trivial scripts
```

### Mechanism 2 — env whitelist passthrough

Resource-tcp dispatcher forwards env matching whitelist:

```
allow_env: HEXA_*, ANIMA, NEXUS, BEDROCK_*, PYTHONPATH
```

Translated (not literal) — `HEXA_LANG=/Users/ghost/X` becomes `HEXA_LANG=/home/aiden/X` if a translation map is configured.

### Mechanism 3 — Auto-detect stdlib path

If `HEXA_LANG` unset, hexa runtime walks up from `caller_dir` searching for `stdlib/` sibling. For our case:

```
caller_dir=/home/aiden/core/hexa-lang/stdlib/safetensors.hexa
  → check ../stdlib/  → SAME → fallback: caller_dir IS already stdlib
  → import "stdlib/bytes" → check ./bytes.hexa → found
```

## Acceptance

All three together remove ALL workarounds from the 본 cycle session:

```
# before
ssh ubu1 'cd ... && HEXA_LANG=... HEXA_MEM_UNLIMITED=1 hexa run ...'

# after
hexa run tool/hexa_native/safetensors_smoke.hexa   # works from Mac
```

## Implementation notes

- `.hexarc` parsed once at hexa.real startup
- Variable expansion: `$HOME`, `$HEXA_HOME`, `$ANIMA` (limited whitelist)
- Resource-tcp side: minimal change — accept new env from connection setup payload

## Migration

- `.hexarc` optional (no breaking change)
- Env passthrough opt-in via `[dispatcher] env_passthrough = true`
- Auto-detect stdlib is fallback-only (env explicit wins)
