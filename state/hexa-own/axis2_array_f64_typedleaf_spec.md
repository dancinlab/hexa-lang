# axis-② f64 typed-leaf unit — implementation spec (SSOT)

## 1. Leaf strategy — GO: (B) bit-reinterpret pair

Add `__hx_f64_bits(x:float)->int` + `__hx_bits_f64(x:int)->float`; reuse `__hx_ptr_store64/load64` for the memory move.

Why (B) over (A):
- **(A) duplicates the entire mem-access lowering** — (ptr, byte-off) addressing, reg/spill handling, and a store-from-xmm path (`movsd [base+off], xmm`) in three backends. That is exactly the surface `store64/load64` already got right and byteeq-proved; re-deriving it for xmm operands is where a silent encoder gap would hide (precedent: the x86 encoder IMUL/shift-alias misses were all in "obvious" second variants of existing forms).
- **(B) is two fixed reg↔reg moves** with no addressing mode, no width variants, no spill interaction beyond what the allocator already does for any unary leaf. The memory op stays on the proven i64 path.
- **Reusability**: an f64↔i64 bitcast is a general NaN-box/unboxing primitive (future f64 unboxing, double hashing, bit-exact serialization, the flame det byte-compare paths). (A)'s leaves are single-purpose.
- Cost: one extra reg move per push/box vs a fused `movsd` — noise next to the realloc/box/call overhead; not a lever worth the extra encoder surface. If f64 array hot loops ever matter, (A) can be added later as a peephole without changing the seed contract.

## 2. Codegen lowering (all three backends)

**bind.hexa**: add `__hx_f64_bits` / `__hx_bits_f64` to the intrinsic allowlist immediately next to the `__hx_payload_f2i`/`__hx_payload_i2f` entries (they are the closest existing float-typed leaves; the `__hx_ptr_*` entries are the arity/shape precedent).

Lowering arms go in the same per-backend leaf dispatch that handles the `__hx_ptr_load64/store64` siblings — mirror those match arms:

| Backend | `__hx_f64_bits` (float→int) | `__hx_bits_f64` (int→float) |
|---|---|---|
| aprime x86_64 (`x86_64_linux.hexa` leaf switch) | `movq r64, xmm` — `66 REX.W 0F 7E /r` (e.g. `movq rax, xmm0` = `66 48 0F 7E C0`) | `movq xmm, r64` — `66 REX.W 0F 6E /r` (`movq xmm0, rax` = `66 48 0F 6E C0`) |
| aprime arm64 | `fmov Xd, Dn` = `0x9E660000 \| Rn<<5 \| Rd` | `fmov Dd, Xn` = `0x9E670000 \| Rn<<5 \| Rd` |
| gen2 C | emit union bitcast, **not** `*(int64_t*)&x` (strict-aliasing UB): `({union{double d;long long i;}u; u.d=(x); u.i;})` — or preamble `static inline` helpers | symmetric: `u.i=(x); u.d;` |

Contrast with the existing numeric leaves so nobody "reuses" them: `__hx_payload_f2i` is `cvttsd2si` (value truncate, destroys the bit pattern); the new leaves are `movq`/`fmov` (pure reinterpret).

**2-backend path-mismatch risk (flag)**: gen2-C and aprime-native must agree bit-exactly or gen-cycle byteeq diverges (precedent: the STMT_BINOP r5 gap). Mitigation in PR-1: a probe test that round-trips a canonical set through both backends and compares raw bits — `3.14 → 0x40091EB851EB851F`, `-0.0 → 0x8000000000000000`, `+inf`, and a quiet-NaN with payload (`0x7FF8000000000001`) to prove no `cvttsd2si`/NaN-canonicalization sneaks in.

## 3. f64 seed bodies (`hexa_arr_f64_{new,push,len,box}`)

`new` and `len` are **byte-for-byte mirrors of the i64 bodies** — header layout (16B: data@0, len@8 i32, cap@12 i32) and 8-byte stride are identical; at this level `data` is untyped bytes. Copy them, rename.

`push` — i64 body with one changed line (the double-store):

```
pub fn hexa_arr_f64_push(v:HexaVal, x:float)->HexaVal {
  let a=__hx_payload_add(v,0)
  let len=__hx_ptr_load32(a,8)  let cap=__hx_ptr_load32(a,12)
  if __hx_payload_ge(len,cap) { let ncap=__hx_payload_mul(cap,2); let old=__hx_ptr_load64(a,0)
    let nd=realloc(old,__hx_payload_mul(ncap,8)); if __hx_payload_eq(nd,0){ /* write+exit, mirror i64 */ }
    __hx_ptr_store64(a,0,nd); __hx_ptr_store32(a,12,ncap) }
  let data=__hx_ptr_load64(a,0); let off=__hx_payload_mul(len,8)
  __hx_ptr_store64(data,off,__hx_f64_bits(x))     // ← THE double-store line: bitcast xmm→gpr, then proven raw i64 store
  __hx_ptr_store32(a,8,__hx_payload_add(len,1)); return v }
```

`box` — mirror the i64 box's bounds check verbatim (same `__hx_payload_*` comparison leaves — plain int ops would emit boxed `hexa_*_slow`, convergence array-core-hexa-1), then:

```
  let data=__hx_ptr_load64(a,0)
  let bits=__hx_ptr_load64(data,__hx_payload_mul(i,8))
  return hexa_float(__hx_bits_f64(bits))          // extern fn hexa_float(x:float)->HexaVal — TAG_FLOAT carrier
```

New externs for the seed: `hexa_float(x:float)->HexaVal` (carrier); everything else (`malloc/realloc/write/exit/hexa_throw/hexa_str`) is already in the file.

## 4. Wiring — recommend SEPARATE file + separate guard

**Decision: separate seed file `array_typed_leaf_f64.hexa`, separate guard `HEXA_RT_CORE_ARRAY_F64_LEAF_NATIVE`, separate resolver `resolve_native_array_f64_leaf_seed`.** Folding into the existing seed is broken for staging, not just inconvenient: the frozen `.s` would then define all 8 globals, so with I64 ON / F64 OFF, linking that object defines `hexa_arr_f64_*` **and** runtime_core.c compiles its C inline f64 bodies → duplicate-symbol link failure. Independent flip requires object-level separation, which means file-level separation.

Checklist (each step mirrors the i64 unit):
1. Seed file `stdlib/runtime/array_typed_leaf_f64.hexa` (4 fns above).
2. Emitter: add `|| defined(HEXA_RT_CORE_ARRAY_F64_LEAF_NATIVE)` sub-guard to the f64 block's `#if` at ~3049, mirroring the i64 sub-guard at 2760 (guard suppresses the C inline bodies, externs the seed symbols).
3. Resolver `resolve_native_array_f64_leaf_seed` (own-obj/frozen-.s), keyed on the new guard only.
4. `rt_arr_f64_def` def-var threading, same plumbing as the i64 def-var.
5. Regen script: add the f64 seed to the regen list; regenerate frozen `.s` for all targets incl. darwin.

## 5. Staging + walls

**PR-1 — leaves only (compiler change, guard-OFF, zero behavior change).** Two bitcasts in bind.hexa + all three backends + the dual-backend bit-pattern probe. Gate: **gen3≡gen4 byteeq 3-target GREEN** (compiler touched) + probe GREEN (incl. NaN-payload preservation).

**PR-2 — f64 seed + wiring, merge default-OFF.** Gate to merge: byteeq 3-target GREEN with guard OFF (byte-neutral). Gate to flip ON: byteeq 3-target GREEN with guard ON + shipping smoke + an f64-array behavioral smoke (push growth across a realloc boundary, box round-trip bit-exact, OOB throw).

Walls vs fixes:
- **float-param SSE ABI (the real gate, verify FIRST in PR-2)**: `hexa_arr_f64_push(HexaVal v, double x)` needs `v` in the GP pair (rdi:rsi) and `x` in xmm0 (d0 on arm64) so C call sites link unchanged. Probe before writing the seed: extern-call a trivial `pub fn probe(v:HexaVal,x:float)->float{return x}` from C with a known bit pattern. x86_64: expected-working (`__hx_payload_f2i/i2f` already move through xmm) — if mixed GP+SSE param ordering is wrong it's a codegen **fix**, not a wall. **arm64: known open fp-ABI residual (the hxlcl Route C campaign left "arm64 fp-ABI" unresolved)** — this is the one candidate genuine wall. If the probe fails on arm64, stage the flip per-target (x86_64 first), don't block the unit.
- **arm64 `fmov` encoder support**: if the encoder lacks FMOV(general), it's a small additive encoding (two fixed opcodes above) — fix, not wall.
- **darwin frozen `.s`**: regen the darwin variant and verify all 4 globals via `llvm-nm` — mechanical.
- **gen2/aprime divergence**: covered by the PR-1 probe; fix, not wall.
