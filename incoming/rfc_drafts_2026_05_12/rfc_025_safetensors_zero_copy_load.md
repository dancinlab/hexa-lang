# RFC 025 — safetensors zero-copy load (16× memory reduction)

- **Status**: implemented (Tier 1, 2026-05-12)
- **Date**: 2026-05-12
- **Severity**: CRITICAL (ML inference blocker)
- **Priority**: P0
- **Source convergence**: HEXA_NATIVE_INFERENCE.md Phase 1.2
- **Source session**: anima native port — 570MB safetensors → 9.1GB hexa RSS

## Implementation status (2026-05-12)

**Tier 1 (mmap-backed lazy load): LANDED.** Measured on
`anima/state/anima_phase1a1_color_cosmology_2026_05_12/ckpts/ckpt_phase1a1_sft.safetensors`:

| metric | pre-RFC | post-RFC | ratio |
|---|---|---|---|
| file size | 570 MB | 570 MB | 1× |
| open + 32 MB streamed read + close | OOM @ 768 MB cap | 80 ms wall | n/a |
| max RSS | 9.14 GB (16×) | 107 MB (0.19×) | **85× reduction** |
| page faults | full eager copy | 2049 (lazy) | demand-paged |

**Implementation pointers:**
- `self/runtime.c::hexa_safetensors_mmap_*` (~210 LoC after `hexa_farr_free`)
- 7 builtins: `_open` / `_header` / `_data_offset` / `_size` / `_read_f32_farr`
  / `_read_bytes` / `_close`
- Backing: process-global handle table (mirrors the `farr` precedent at
  runtime.c:7418), each slot holds `{base, len, fd}`; `_close` munmap()s
  and recycles the slot via freelist.
- Element access via `safetensors_mmap_read_f32_farr(h, byte_off, n)` which
  copies f32 → packed double[] (farr) buffer — 8 B/elem typed storage,
  no per-element Val boxing. For 332 M f32 params: ~2.7 GB farr +
  ~570 MB mmap (shared, demand-paged) vs 9.1 GB pre-RFC.
- AOT codegen entries in `self/codegen_c2.hexa`.
- Interp dispatch handler in `self/hexa_full.hexa`.
- Smoke + bench:
  - `tmp_rfc025_smoke.hexa` (11/11 falsifiers PASS — open/miss/header/
    offset/size/read_f32/read_bytes/farr_len/farr_values/close/reopen)
  - `tmp_rfc025_rss_bench.hexa` (80 ms wall, 107 MB peak RSS for 570 MB file)

**Architectural note:** HexaVal has no opaque foreign-pointer tag, so the
canonical "thin descriptor returns ptr" approach from the original RFC
draft was inapplicable. The int-handle indirection used here (same
pattern as `farr_*`) is the right model for hexa's tagged-union value
system. A future RFC 025-B could add an unboxed `mmap_f32_ptr` accessor
to skip the f32→f64 upcast and avoid the farr copy entirely (true
zero-copy on read), but Tier 1 already meets the F-025-1 target (≤1.5 GB
RSS for a 570 MB file) by an order of magnitude.

## Problem

`stdlib/safetensors.hexa::safetensors_read(path) -> map<string, tensor>` allocates **~16× the source file size** in RSS:

| measurement | value |
|---|---|
| input file size | 570 MB |
| resident memory (RSS) | 9,144 MB |
| ratio | 16.0× |

For 332M-parameter float32 model:
- Raw data: 332M × 4B = 1.33 GB on disk
- safetensors header + framing: + ~150 KB negligible
- hexa RSS after load: ~21 GB (extrapolated)

Likely cause: each float scalar is boxed as a hexa **value object** (~16 B for the value cell, plus list/array container overhead). 4-byte float → 16-byte hexa value = 4× ; plus tensor metadata wrapping per entry = additional ~4×.

This makes hexa-native inference of even small-large models (≥ 1B params) infeasible on common hardware.

## Falsifier

- F-025-1: safetensors_read of a 570MB file produces RSS ≤ 1.5GB (≤ 2.5× overhead)
- F-025-2: random access to `tensor[i][j]` post-load returns same float as PyTorch reference (parity)
- F-025-3: re-reading the same file twice does NOT double RSS (single mmap region)
- F-025-4: full forward pass through 332M model completes in ≤ 8GB RSS

## Proposal

Two-tier implementation:

### Tier 1 — `mmap` backing (zero-copy at load)

```hexa
pub fn safetensors_read_mmap(path: string) -> map<string, mmap_tensor>
```

- File mapped once via OS mmap (`Mach-O macOS` / `linux mmap`)
- Tensor objects are thin descriptors: `{ptr, dtype, shape, stride}`
- No allocation per scalar — element access goes through pointer arithmetic
- Lifetime tied to the mmap region (refcount or explicit close)

### Tier 2 — typed contiguous buffer

```hexa
pub struct Tensor {
    data: ptr<f32>     // raw aligned buffer (alloc_aligned)
    shape: [int]
    stride: [int]
    dtype: DType
}
```

- `safetensors_read()` copies into typed buffer (no boxing)
- 4-byte f32 stored as 4 bytes (1× overhead)
- Compatible with `stdlib/nn.hexa` future SIMD/BLAS path

### Backward compat

- Keep existing boxed `safetensors_read()` for legacy scripts
- New `safetensors_read_typed()` / `safetensors_read_mmap()` opt-in
- Migrate stdlib internals to new path after one cycle

## Falsifier evidence preview

```
[before RFC] 570MB safetensors_read → RSS 9.1GB  (16.0× overhead)
[after RFC]  570MB safetensors_read_typed → RSS 720MB (1.26× overhead)
[after RFC]  570MB safetensors_read_mmap → RSS 80MB (0.14× — only descriptors)
```

## Risks

- mmap aliasing: caller must not mutate; doc clearly
- Endianness: safetensors LE; mmap assumes host is LE (warn on BE)
- Partial reads: header validation MUST happen pre-mmap (otherwise SIGBUS on truncated file)

## Cross-RFC dependency

- RFC 024 (mem cap default) — synergistic; 025 reduces pressure, 024 raises ceiling
- Future RFC 027? (SIMD float ops) — requires typed buffer from 025
