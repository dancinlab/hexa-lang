# Phase 4-B-3 extern fn integration finding (2026-05-17)

> Honest finding from POC attempt — hexa-lang's `extern fn` mechanism
> is incompatible with the boxing-elim goal of Phase 4-B-3 integration.

## What was attempted

POC: `stdlib/flame/flame_phase4b3_extern_test.hexa`

```hexa
extern fn flame_rmsnorm_d32_fwd_primitive(
    x_id: int, g_id: int, y_id: int, xn_id: int, inv_id: int
)

fn main() {
    let x = farr_zeros(d)
    // ... allocate, populate ...
    nn_rmsnorm_fwd(x, g, y_h, xn_h, inv_h, d)         // hexa wrapper
    flame_rmsnorm_d32_fwd_primitive(x, g, y_p, xn_p, inv_p)  // primitive
    // verify byte-eq
}
```

Build wrapper concats primitive C body after `#include "runtime.c"` —
same single-TU pattern proven by PHASE4B3_2_INTEGRATION.md commit
`a7d066a2`.

## What failed

clang build error:
```
error: conflicting types for 'flame_rmsnorm_d32_fwd_primitive'
  primitive (concat'd):  static inline void  (int x_id, ...)
  hexa_v2 emitted wrapper: static HexaVal   (HexaVal x_id, ...)
```

hexa_v2 always emits a FFI wrapper for extern fn declarations:

```c
static void* __ffi_sym_flame_rmsnorm_d32_fwd_primitive = NULL;
static HexaVal flame_rmsnorm_d32_fwd_primitive(HexaVal x_id, ...) {
    ((__ffi_ftyp_...)__ffi_sym_...)(
        (HX_IS_INT(x_id) ? HX_INT_U(x_id) : (int64_t)HX_FLOAT(x_id)),
        ...
    );
    return hexa_void();
}
```

The wrapper:
1. **Loads via dlopen** — `__ffi_sym_*` is initialized at startup from a
   dylib (matching python_ffi.hexa + bench_hxlayer.hexa patterns).
2. **HexaVal-mandated signature** — wrapper signature must be HexaVal-
   typed regardless of the `int` annotation in hexa source.
3. **Unboxes inside the wrapper** — args unboxed via `HX_INT_U`.

This means even if the primitive were called via `extern fn`, the
boxing happens at the wrapper boundary (every call). The boxing-elim
mechanism (boxing 4× MEASURED) requires NOT crossing a HexaVal
boundary per call.

## Implication for Phase 4-B-3 integration

The "hexa-source extern fn" integration approach (Path W1 from
PHASE4B3_2_INTEGRATION.md) is INFEASIBLE for the boxing-elim goal:

- ❌ extern fn → dlopen + HexaVal marshaling → boxing per call
- ❌ Custom build of a dylib for primitives → infrastructure cost +
  STILL boxing per call (wrapper is mandatory)
- ❌ hexa_v2 emit modification (skip wrapper for "@inline_extern" attr)
  → compiler internals work, out of Phase 4-B-3 scope

The C-source sed approach (Path W2 from PHASE4B3_2_INTEGRATION.md) is
the ONLY remaining viable path:

✅ **C-source sed**: after hexa_v2 emit, sed-rewrite the inline
   farr_get/set chains in nn_decoder_block_fwd body with primitive
   calls. Already partially implemented for the call-site level
   (commit `28cf24a6` — block_fwd call sites). For body-level the
   same sed pattern applies but identifying the inline RMSNorm /
   SwiGLU / etc. patterns within block_fwd's body is harder.

## What still works

The 5 leaf primitive byte-eq tests (commits `1da62cc1`, `9e065f89`,
`9f95621d`, `8537739e`, `fe7c1922`) remain valid — they verify
algorithm-byte-eq via standalone C testing, NOT through hexa-source
extern fn integration.

The primitive emission infrastructure (commits `0a95371b`, `f5182641`,
`28cf24a6`) is fully functional for trampoline-level integration
(block_fwd call site rewrite). Just doesn't extend to body-level
inline integration via extern fn.

## Updated Phase 4-B-3 integration plan

Revised path forward:

**(A1) C-source body sed-rewrite** — extend `tool/flame_phase4b3_build.sh`
with sed patterns that match the inline RMSNorm / SwiGLU / RoPE /
Attention farr_get/set chains in the hexa_v2-emitted block_fwd body
and replace each chunk with a primitive call.

Estimated complexity: HIGH. The inline chunks are multi-line
hexa_v2-emitted C with consistent farr_get / hexa_add / hexa_mul
calls, but identifying chunk boundaries via regex is brittle.

**(A2) Bypass block_fwd entirely** — emit a fully-primitive
`flame_block_T16_d32_..._fwd_primitive` body (~270 C lines per
PHASE4B3_BLOCK_FWD_AUDIT.md) and route block_fwd call sites to it
via the existing trampoline wire-up (commit `28cf24a6` sed).

The 5 verified leaf primitives become inline blocks within this
body. Block-level falsifier (F-RFC047-BLOCK-EMIT-BYTE-EQ-FWD)
gates correctness.

Estimated complexity: HIGH but bounded. ~270 lines hand-translation
guided by the verified leaf primitives.

**(A3) Defer integration** — ship the verification-layer + this
finding as Phase 4-B-3 milestone. Integration becomes future cycle
when ≥3× wall is required.

## Recommendation

**A2** is the clearest path forward. It uses the verified leaf
primitives as building blocks for the full block_fwd primitive,
keeping each block independently verifiable but combining them via
the trampoline wire-up that's already shipped.

Effort: 2-3 cycles for fwd body + 2-3 cycles for bwd body.

This corrects PHASE4B3_2_INTEGRATION.md's W1 (extern fn) recommendation
— W2 (C-source rewrite) is the only viable boxing-elim integration
mechanism. W2 effectively reduces to A2 (whole-block primitive emission).

## Cross-link

- PHASE4B3_2_INTEGRATION.md (commit `a7d066a2`) — W1/W2 paths design
  (W1 now confirmed infeasible)
- PHASE4B3_DESIGN_CORRECTION.md (commit `122e186d`) — block_fwd is
  INLINE not leaf-call (full-block primitive is correct path)
- PHASE4B3_BLOCK_FWD_AUDIT.md (commit `490e7b2a`) — 9-section roadmap
- hexa_v2 extern fn wrapper emission (`build/artifacts/*extern_test.c:25`
  audit source for this finding)
- python_ffi.hexa / bench_hxlayer.hexa — extern fn + dlopen pattern
  reference (working but mandates HexaVal boundary)
