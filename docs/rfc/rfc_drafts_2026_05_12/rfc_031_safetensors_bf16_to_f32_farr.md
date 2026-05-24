# RFC 031 — safetensors BF16 → f32 farr reader

- **Status**: implemented (2026-05-12)
- **Date**: 2026-05-12
- **Severity**: HIGH (blocks pure-hexa BF16 ckpt inference)
- **Priority**: P0 (HEXA_NATIVE Phase 5∥ prerequisite)
- **Source convergence**: HEXA_NATIVE_INFERENCE.md Phase 5.1 → Phase 5∥ 24-layer
- **Source session**: anima Phase 1A.1 color-cosmology ckpt is BF16; current
  RFC 025 `_read_f32_farr` cannot decode it, forcing a one-shot 167 MB
  PyTorch-side F32 sidecar that does not scale to a 24-layer pure-hexa forward.

## Implementation status (2026-05-12)

**LANDED** as a single new builtin
`safetensors_mmap_read_bf16_to_f32_farr(handle, byte_off, n_elem) -> farr_id`.

- `self/runtime.c::hexa_safetensors_mmap_read_bf16_to_f32_farr` (~50 LoC,
  added directly after `hexa_safetensors_mmap_read_f32_farr`).
- `self/runtime.c::_hexa_init_fn_shims` — fn_shim registration (arity 3).
- `self/codegen_c2.hexa` — AOT dispatch entry (3-arg block at line ~4129).
- `self/hexa_full.hexa::call_builtin` — interp dispatch handler.
- Smoke: `tmp_rfc031_smoke.hexa`.

## Problem

`tool/hexa_native/` Phase 5∥ inference loop wants to mmap-load
`anima/state/anima_phase1a1_color_cosmology_2026_05_12/ckpts/ckpt_phase1a1_sft.safetensors`
directly from BF16 (the native ckpt dtype) into farr packed-double buffers
suitable for `farr_matmul` (RFC 032). RFC 025 already gives zero-copy mmap
and `_read_f32_farr` for F32 tensors, but the Phase 1A.1 ckpt is BF16 (saves
50 % disk + matches the training-time dtype). Without a BF16 reader, the
caller must either:

1. emit a separate F32 sidecar (`anima/tool/hexa_native/dump_phase1a1_f32_sidecar.py`,
   ~167 MB, lossy roundtrip noise), or
2. read raw bytes via `safetensors_mmap_read_bytes` then upcast in pure
   hexa — paying ~88 B HexaVal arena per scalar across 332 M params,
   which OOMs the interp arena.

Both block the 24-layer Phase 5∥ parity gate.

## Proposal

Add one runtime builtin parallel to `_read_f32_farr`:

```hexa
pub fn safetensors_mmap_read_bf16_to_f32_farr(h: int, byte_off: int, n_elem: int) -> int
//   returns farr_id ≥ 0 on success, -1 on shape/bounds error.
```

Semantics: read `n_elem` BF16 values (each 2 bytes, little-endian) starting
at `byte_off`, upcast each to f32 by zero-extending its 16 bits into the
HIGH 16 bits of an IEEE-754 binary32 (the canonical bf16 → f32 widening:
bf16 layout is identical to f32's sign + 8-bit exp + top-7-bit mantissa,
so `(uint32_t)u16 << 16` IS the f32 bit pattern). Promote f32 → double
and store in a fresh packed-double farr.

### Bit layout

```
IEEE-754 BF16:  s eeeeeeee mmmmmmm           (16 bits)
IEEE-754 F32:   s eeeeeeee mmmmmmm 0000000000000000   (32 bits)
                ───── identical ───── + zero-padded mantissa
```

Special values preserved exactly:

| BF16 hex | f32 value |
|---|---|
| 0x0000 | +0.0 |
| 0x8000 | -0.0 |
| 0x3F80 | +1.0 |
| 0xBF80 | -1.0 |
| 0x7F80 | +Inf |
| 0xFF80 | -Inf |
| 0x7FC0 / 0xFFC0 | NaN (quiet) |

### Memory cost

- Output farr: 8 B/elem × `n_elem` (same as `_read_f32_farr`).
- No extra mmap region. Source is the existing mmap; we just walk 2 B/elem.
- For 332 M params: ~2.66 GB farr buffers (only ONE layer's weights at a
  time in the pure-hexa forward; total resident is ≪ that).

## Falsifiers

- **F-RFC-031-OPEN-BF16**: open Phase 1A.1 ckpt, read 8 BF16 elements from
  `tok_emb.weight`, expect `farr_id ≥ 0`.
- **F-RFC-031-LEN**: `farr_len(farr_id) == 8` after the call above.
- **F-RFC-031-FINITE**: every read value `v` satisfies `v == v` and
  `abs(v) < 1e10` (no spurious NaN / overflow from bad endianness).
- **F-RFC-031-BF16-ONE**: bytes `[0x80, 0x3F]` (LE 0x3F80) ↦ `1.0`
  bit-exact.
- **F-RFC-031-BF16-NEG-ONE**: bytes `[0x80, 0xBF]` (LE 0xBF80) ↦ `-1.0`.
- **F-RFC-031-BF16-ZERO**: bytes `[0x00, 0x00]` ↦ `0.0`.
- **F-RFC-031-BOUNDS**: `byte_off + 2*n > mmap_len` returns -1, no crash.
- **F-RFC-031-MMAP-SHARED**: opening the file twice and reading the same
  slice produces identical farr contents (mmap is shared, not duplicated).
- **F-RFC-031-PYTORCH-PARITY**: read 64 BF16 weights from Phase 1A.1
  `tok_emb.weight`, compare to PyTorch's `tensor.to(torch.float32).tolist()`
  for the same slice — max |Δ| = 0 (bit-exact, since bf16 → f32 widening is
  lossless and the PyTorch path emits the same upcast).

## Risks

- Endianness: safetensors spec mandates little-endian, we compose explicitly
  byte-by-byte so big-endian hosts (none in our deploy fleet, but defensive)
  still work.
- Strict aliasing: type-pun via `union {uint32_t u; float f;}` (UB-safe in
  C11; tested on clang -O2 / -O3).
- Bounds: explicit `off + 2*n <= mmap_len` check before any read. Negative
  `off`/`n` rejected.

## Cross-RFC dependency

- RFC 025 (mmap zero-copy load) — direct extension; reuses the mmap handle
  table and farr handle table.
- RFC 032 (`farr_matmul`) — both required for Phase 5∥. RFC 031 produces
  the farr buffers RFC 032 consumes.

## Anima-side unblock

`anima/tool/hexa_native/load_phase1a1_bf16.hexa` (forthcoming) calls this
builtin per-layer, producing `farr_id`s that feed `engine_ag_nn_native.hexa`
without the F32 sidecar. Removes the 167 MB sidecar from the inference
pipeline and saves 50 % cold-start I/O.

## Implementation pointers

```c
// self/runtime.c (after hexa_safetensors_mmap_read_f32_farr)
HexaVal hexa_safetensors_mmap_read_bf16_to_f32_farr(HexaVal h_v,
                                                   HexaVal off_v,
                                                   HexaVal n_v) {
    int64_t id  = hexa_as_num(h_v);
    int64_t off = hexa_as_num(off_v);
    int64_t n   = hexa_as_num(n_v);
    if (id < 0 || id >= _hx_mmap_count) return hexa_int(-1);
    HexaMmapEntry* e = &_hx_mmap_table[id];
    if (!e->base) return hexa_int(-1);
    if (off < 0 || n < 0) return hexa_int(-1);
    if ((size_t)off + (size_t)(n * 2) > e->len) return hexa_int(-1);
    HexaVal farr_handle = hexa_farr_zeros(hexa_int(n));
    int64_t farr_id = HX_INT(farr_handle);
    HexaFarrEntry* fe = &_hx_farr_table[farr_id];
    const unsigned char* src = (const unsigned char*)e->base + off;
    for (int64_t i = 0; i < n; i++) {
        uint16_t u16 = (uint16_t)src[2*i] | ((uint16_t)src[2*i + 1] << 8);
        uint32_t u32 = ((uint32_t)u16) << 16;
        union { uint32_t u; float f; } cvt;
        cvt.u = u32;
        fe->buf[i] = (double)cvt.f;
    }
    return farr_handle;
}
```
