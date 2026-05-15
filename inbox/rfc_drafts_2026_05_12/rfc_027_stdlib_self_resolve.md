# RFC 027 — stdlib internal imports self-resolve (when caller is inside stdlib/)

- **Status**: draft
- **Date**: 2026-05-12
- **Severity**: MEDIUM (resolver UX)
- **Priority**: P2
- **Source convergence**: HEXA_NATIVE_INFERENCE.md Phase 1.2
- **Source session**: safetensors.hexa → imports stdlib/bytes → not found

## Problem

`stdlib/safetensors.hexa` contains `import "stdlib/bytes"`. When loaded, resolver searches `HEXA_LANG/stdlib/bytes`, `HEXA_STDLIB_ROOT/bytes`, etc. — but **does NOT try `caller_dir/../bytes`** even though caller is `.../stdlib/safetensors.hexa`.

This makes stdlib-internal imports fragile to env state. RFC 026 (env passthrough) is the broader fix; this RFC is a narrower correctness/safety patch.

## Falsifier

- F-027-1: load `stdlib/safetensors.hexa` with all HEXA_* env unset → still resolves internal `import "stdlib/bytes"`
- F-027-2: no false positives — user script `import "stdlib/bytes"` from a non-stdlib path does NOT accidentally resolve from another tree's stdlib

## Proposal

Augment resolver fallback order:

```
1. (existing) HEXA_LANG
2. (existing) HEXA_STDLIB_ROOT
3. (existing) project_root
4. (existing) caller_dir/<import>
5. (NEW) if caller_dir matches `**/stdlib/*` AND import starts with `stdlib/`:
         strip the `stdlib/` prefix and check caller_dir/<import_tail>
         (caller is already in stdlib/, so its siblings ARE the stdlib namespace)
6. (existing) FATAL
```

Concrete:

- caller_dir = `/home/aiden/core/hexa-lang/stdlib`
- import = `stdlib/bytes`
- new step 5: caller_dir matches `**/stdlib`? yes
  - import starts with `stdlib/`? yes (`stdlib/bytes`)
  - strip prefix → `bytes`, check `/home/aiden/core/hexa-lang/stdlib/bytes.hexa` → found ✓

## Risks

- **Ambiguity if user script lives in own `stdlib/`**: if user creates `~/proj/stdlib/foo.hexa` and imports `stdlib/bytes`, the new rule would prefer `~/proj/stdlib/bytes.hexa`. This is the desired behavior (project-local stdlib shadow), and matches Python's `sys.path` ordering.

## Migration

- Pure additive — adds one fallback step, never removes existing resolution paths
- Doc: clarify in `doc/import_resolution.md`
- No flag needed (default-on)
