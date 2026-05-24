# RFC 024 — ML-aware default memory cap (768MB → adaptive)

- **Status**: draft
- **Date**: 2026-05-12
- **Severity**: BLOCKER (ML workloads)
- **Priority**: P1
- **Source convergence**: HEXA_NATIVE_INFERENCE.md Phase 1.2 (anima cycle 7 hexa-native lane)
- **Source session**: anima safetensors load — 570MB ckpt → 9.1GB RSS → cap exceeded

## Problem

Default `HEXA_MEM_CAP_MB=768` is reasonable for hexa scripts as scripting glue, but is **two orders of magnitude too low** for ML inference workloads:

```
[hexa-runtime] memory cap exceeded: rss=9144MB > cap=768MB
[hexa-runtime] hint: re-run with --mem-unlimited (or HEXA_MEM_UNLIMITED=1)
```

The 9GB usage comes from `safetensors_read()` loading a 570MB file — see RFC 025 for the underlying overhead. But independent of that overhead, **any non-trivial model load** exceeds 768MB.

## Falsifier

- F-024-1: hexa script that loads ≥ 1GB ckpt and runs forward → completes without `HEXA_MEM_UNLIMITED=1` workaround
- F-024-2: `HEXA_MEM_CAP_MB` not set → cap is ≥ 8GB by default
- F-024-3: ML-heavy file detected (e.g., imports `stdlib/nn.hexa` or `stdlib/safetensors.hexa`) → auto-raises cap

## Proposal

Three-tier default policy:

```
default cap = max(
    768MB,                                  # current floor (script glue)
    physical_ram * 0.5,                     # don't OOM the host
    file_total_ckpt_bytes * 4                # ML allowance per RFC 025 overhead
)
```

If `HEXA_MEM_CAP_MB` is explicitly set, honor it. Otherwise apply tiered default. Add diagnostic:

```
[hexa-runtime] mem cap auto-set to 8000MB (physical_ram=16GB * 0.5)
[hexa-runtime]   override with HEXA_MEM_CAP_MB=<N> or --mem-cap=<N>
```

## Alternatives considered

- **A**: Always uncapped — rejected: lose OOM safety on shared hosts.
- **B**: Per-import auto-raise (heuristic: if `stdlib/nn` imported, raise) — too magic; explicit beats implicit.
- **C**: Project-level `.hexarc` — orthogonal (RFC 026); good complement but doesn't solve fresh-clone UX.

## Cross-RFC dependency

- RFC 025 (safetensors_read mem overhead) — if 025 lands, 024's pressure drops 16× and 768MB might suffice for many models.
- RFC 026 (env passthrough / .hexarc) — explicit override path.

## Migration

- Backward compatible: existing scripts with explicit `HEXA_MEM_CAP_MB` keep behavior
- New default kicks in only when env is unset
- One-cycle deprecation notice in release notes (no breaking change)
