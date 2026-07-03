# LANE C — escaping packed [f32] (TAG_ARRAY_F32)

Follow-on to #4158 (TAG_ARRAY_F64, commit `7fc263d28`), which explicitly deferred
f32: *"f32 (104) OUT OF SCOPE — farr32 4B-stride area"*. This lane closes f32.

SSOT memory: `project_hexa_runtime_gap_allclosure`.
Branch: `feat/escaping-packed-f32`. Default-OFF (`HEXA_PACK_ESCAPING`), byteeq-neutral.

## The anticipated 4B-stride WALL — and why it does NOT break

The prompt flagged a likely **measured wall**: f64 8B == i64 8B made #4158 a clean
homomorphic mirror; f32 is 4B-stride, so the `(ptr,len,cap)` layout-match invariant
was expected to break, forcing a distinct descriptor + a 4B push ABI.

It does **not** break. Three points pin it:

1. **Descriptor layout-match HOLDS.** `HexaArrF32 {float* data; int64_t len;
   int64_t cap}` is **still 24 bytes** (ptr@0, len@8, cap@16) — byte-identical in
   shape to `HexaArr`/`HexaArrI64`/`HexaArrF64`. The 4-byte stride is **internal to
   the `data[]` buffer**, governing only how `data[idx]` is addressed — NOT the
   descriptor. So `hexa_arr_poly_len` reads `len@8` correctly for an f32 descriptor
   exactly as for i64/f64. (self/runtime_core_emit.hexa: `typedef HexaArrF32`.)

2. **Poly-reader pair-model ABI carries no 4B element.** The poly readers take/return
   a boxed `HexaVal`. f32 get → `hexa_float((double)a->data[idx])` (widen to boxed
   double); f32 set/push → narrow a boxed double back to `(float)`. So **no 4-byte
   element ever rides the call boundary** — the pair-model ABI is unchanged.
   (self/runtime_core_emit.hexa: `hexa_arr_poly_{len,get,set,push}` TAG_ARRAY_F32
   branches.)

3. **Mint push is all-GPR, f64-bits in a GPR.** `_x86_hv_payload` lands a
   `const_float`'s **f64** IEEE-754 bits (`float_to_bits` = 64-bit double pattern)
   in `rdx` — the EXACT all-GPR ABI shape of `hexa_arr_i64_push`
   (`rdi:rsi`=descriptor, `rdx`=bits). `hexa_arr_f32_push_bits(HexaVal, int64_t bits)`
   reinterprets bits→double, then `hexa_arr_f32_push` narrows **double→float INSIDE
   the helper** before the 4B store. The 4B stride is fully internal; no xmm at the
   mint site. (x86_64_linux.hexa mint dispatch: `emk==104 → hexa_arr_f32_*`.)

**Verdict: f32 IS a homomorphic mirror at the codegen/ABI layer.** The 4B element
stride is confined to runtime `float[]` addressing and the double↔float
widen/narrow at the C boundary — it never reaches a calling-convention edge.

## Changes

### Runtime — self/runtime_core_emit.hexa
- `HexaTag += TAG_ARRAY_F32` (TRUE LAST append after TAG_ARRAY_F64; no value
  shift — #4151 append-only lesson). Enum append = object-code-neutral.
- `typedef struct HexaArrF32 { float* data; int64_t len; int64_t cap; }` (24B).
- Under `#ifdef HEXA_PACK_ESCAPING`:
  - `hexa_arr_f32_new_esc(int cap) -> TAG_ARRAY_F32`
  - `hexa_arr_f32_push(HexaVal, double x)` — native float[] grow, narrow on store
  - `hexa_arr_f32_push_bits(HexaVal, int64_t bits)` — union-pun bits→double→float
  - `hexa_arr_poly_{len,get,set,push}` each += a TAG_ARRAY_F32 branch.

### Codegen — compiler/codegen/x86_64_linux.hexa
- esc-mint lattice pass1 + pass2: propagate kind `104` (f32) alongside 101/103.
- `_x86_operand_pack_esc`: accept type_id 104.
- array_lit mint dispatch: `emk==104 → hexa_arr_f32_new_esc / hexa_arr_f32_push_bits`.

### Lowering — compiler/lower/hir_to_mir.hexa
- No change. `[f32]` already maps to type_id 104 (`_lr_array_type_id`,
  `_arru_native_enabled` element-kind stamp).

### arm64 — compiler/codegen/arm64_darwin.hexa
- No change. `_arm_operand_pack_esc` is i64-only (101/102) and never mints
  TAG_ARRAY_F32 → escaping [f32] on arm64 stays **BOXED** (no miscompile, no
  regression). The runtime poly-f32 branches are INERT on arm64 (same INERT
  property as the default-OFF build). Consistent with #4158's x86_64-only scope.
  arm64 f32 esc-mint is an honest future follow-on (the arm64 lattice is a boolean
  `==1`, not kind-carrying — would need the same `_x86_local_esc_mint_kind`
  upgrade first).

### Test — test/escaping_packed_f32_worker_buf.hexa
- f64-mirror parity test: produce → return-escape → consume (param + alias escape)
  → index/index_set/push/len through the poly readers. All values exactly
  representable in float, so f32 narrowing is lossless and the checksum equals the
  f64 mirror's hand value 239800.

## Soundness / byteeq

- All f32 runtime fns under `#ifdef HEXA_PACK_ESCAPING`. All codegen branches
  `_pack_escaping_enabled()`-gated. OFF → byte-identical emit + the enum append is
  object-code-neutral (no reader observes TAG_ARRAY_F32 in the default build).
- No new keyword / builtin / `@attr`. Frozen blob `151c52c8` untouched.

## Status

- 3-target CI byteeq (gen3≡gen4 + determinism + miscompile-zero + codegen-guard +
  faithful-nobaseline ×3) + nvptx + smoke: **PENDING** (PR). byteeq expected GREEN
  (default-OFF, byteeq-neutral).
- aiden OFF/ON parity run of the new test: **PENDING** (mini cannot build; runs on
  pool).
- DO-NOT-AUTO-MERGE: new runtime ABI — needs perf measurement + review.
