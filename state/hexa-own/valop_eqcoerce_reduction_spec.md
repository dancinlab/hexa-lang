# axis-② Tier-1 #2 — valop eqtruthy/coercion reduction (Fable design)

All analysis verified against the actual carriers, the emitter SSOT, the backends, and the build wiring. Here is the implementation-ready spec.

---

# Spec: axis-② Tier-1 #2 — eqtruthy/coercion fold into `HEXA_RT_VALOP_NATIVE`

## 1. Carrier enumeration + coverage verdict

**`self/native/rtcore_eqtruthy_emit.hexa` emits exactly ONE fn** — `int hexa_truthy(HexaVal)`, verbatim mirror of the runtime_core.c inline body (`self/runtime_core.c:8264`), *including* the existing `#ifdef HEXA_RT_VALOP_NATIVE` scalar delegate. It is **not on the ship path**: its only consumers are the drop harness (`tool/zeroc_dropon_fixpoint.sh:66,216`, `tool/zeroc_flip_measure.sh:154`) plus its two regen scripts. `hexa_eq` is deliberately NOT in the carrier (touches file-local statics `_hexa_enum_display`/`hxlcl_strcmp`).

**`self/native/rtcore_valop-dispatch_emit.hexa` emits 9 dispatchers** — `hexa_add_slow · hexa_sub · hexa_mul · hexa_div · hexa_mod · hexa_cmp_{lt,gt,le,ge}`. **All 9 are already fully covered**: scalar arm → `valop_core.hexa` `rt_{add,sub,mul,div,mod,cmp_*}_native` (default-ON), fallback → `numeric.hexa` `rt_*`. This carrier is the Tier-0 A0-twin flag-flip, **out of scope for #2** — no work here.

The coercion dispatchers the roadmap names live in **`self/runtime_core_emit.hexa`** (the SSOT; `runtime_core.c` is the regen artifact):

| C dispatcher | emitter line (≈ .c line) | current release body | valop coverage today | verdict |
|---|---|---|---|---|
| `int hexa_truthy(HexaVal)` | 8664 (8264) | scalar→`rt_truthy_native` ✅; STR/ARR/MAP/VS = C | scalar tags DONE | extend: STR/ARR/VS native; **MAP = wall** |
| `HexaVal hexa_eq(a,b)` | 8919 (8513) | cross int↔float C compare; INT/FLOAT/BOOL→`rt_eq_int/float/bool` (hexa-source, routed through `hexa_cmp_le/ge` C round-trips) | none | NEW `rt_eq_scalar_native` |
| `hexa_ne` | — | **DOES NOT EXIST** (verified repo-wide; `!=` lowers to negated eq/truthy at codegen) | n/a | nothing to port |
| `HexaVal hexa_to_int(v)` | 10047 (9604) | `rt_to_int(v)` (type_of dispatch, `numeric.hexa:1723`) | none | NEW `rt_to_int_native` (INT/FLOAT); STR-parse stays delegate |
| `HexaVal hexa_to_float(v)` | 10014–10023 (9581) | `rt_to_float(hexa_float(__hx_to_double(v)))`; `__hx_to_double` (`runtime_core.c:1978`) covers int/float/bool/**str-parse**/**valstruct** | none | NEW `rt_to_float_native` (INT/FLOAT/BOOL); STR/VS stay C |
| `HexaVal hexa_abs(v)` | 9905–9919 (9478) | `rt_abs_int`/`rt_abs_float` (`numeric.hexa:15,20`) | none | NEW `rt_abs_native`; INT64_MIN pre-guard (below) |
| `HexaVal hexa_null_coal(a,b)` | 2275–2284 (2123) | `rt_null_coal(a,b)` (`numeric.hexa:1239`) | none | NEW `rt_null_coal_native` — **fully native, no wall** |

## 2. New native fns (extend `stdlib/runtime/valop_core.hexa`)

All bodies follow the file's RAW-MEM un-nested idiom (one `__hx_*` per `let`, no nesting — the #3503 clobber guard). Tag values (`self/runtime.h:39`): INT=0 FLOAT=1 BOOL=2 STR=3 VOID=4 ARRAY=5 MAP=6 FN=7 CHAR=8 CLOSURE=9 VALSTRUCT=10 ENUM=11. All required leaves verified present in **both** backends (`compiler/codegen/x86_64_linux.hexa`, `arm64_darwin.hexa`): `__hx_payload_f2i` (cvttsd2si/fcvtzs — identical to the C `(int64_t)` cast per target), `__hx_payload_i2f`, `__hx_str_ptr` (:4423), `__hx_str_byte` (:4431), `__hx_arr_len` (:4446), `__hx_payload_nz` (:4168). None emit `.LC`/rodata refs or external calls → **the seed stays fully self-contained; the simple `.s` frozen-seed path holds, no `--isolate` needed** (design Q4 confirmed).

### a) `rt_eq_scalar_native(a, b) -> HexaVal` — the scalar arm of `hexa_eq`
Called by the wrapper ONLY when `HX_TAG(a) <= TAG_BOOL && HX_TAG(b) <= TAG_BOOL`. Mirrors the C branch order (cross-coerce → tag-mismatch-false → same-tag switch):

```hexa
// int↔float cross (runtime_core.c:8518-8519): (double)int == float, as fle&&fge
fn rt_eq_scalar_native(a: HexaVal, b: HexaVal) -> HexaVal {
    let ta = __hx_tag(a)
    let tb = __hx_tag(b)
    let a_int = __hx_payload_eq(ta, 0)
    let a_flt = __hx_payload_eq(ta, 1)
    let b_int = __hx_payload_eq(tb, 0)
    let b_flt = __hx_payload_eq(tb, 1)
    let c1 = __hx_payload_and(a_int, b_flt)          // int == float
    let c2 = __hx_payload_and(a_flt, b_int)          // float == int
    let cross = __hx_payload_or(c1, c2)
    let both_f = __hx_payload_and(a_flt, b_flt)      // float == float
    let feq = __hx_payload_or(cross, both_f)
    if __hx_payload_ne(feq, 0) {
        let af = __hx_to_double(a)
        let bf = __hx_to_double(b)
        let le = __hx_payload_fle(af, bf)            // false for NaN
        let ge = __hx_payload_fge(af, bf)            // false for NaN
        let lep = __hx_payload_add(le, 0)
        let gep = __hx_payload_add(ge, 0)
        let r = __hx_payload_and(lep, gep)           // IEEE == (NaN → 0)
        return __hx_make_val(2, r)
    }
    let both_i = __hx_payload_and(a_int, b_int)      // int == int → payload eq
    if __hx_payload_ne(both_i, 0) {
        let le = __hx_payload_le(a, b)
        let ge = __hx_payload_ge(a, b)
        let lep = __hx_payload_add(le, 0)
        let gep = __hx_payload_add(ge, 0)
        let r = __hx_payload_and(lep, gep)
        return __hx_make_val(2, r)
    }
    let a_b = __hx_payload_eq(ta, 2)
    let b_b = __hx_payload_eq(tb, 2)
    let both_b = __hx_payload_and(a_b, b_b)          // bool == bool → payload eq (0/1)
    if __hx_payload_ne(both_b, 0) {
        let le = __hx_payload_le(a, b)
        let ge = __hx_payload_ge(a, b)
        let lep = __hx_payload_add(le, 0)
        let gep = __hx_payload_add(ge, 0)
        let r = __hx_payload_and(lep, gep)
        return __hx_make_val(2, r)
    }
    return __hx_make_val(2, 0)                       // bool×int / bool×float: tag mismatch → false
}
```
Parity: `le&&ge` ≡ `==` for i64 and IEEE double (NaN → both false → 0), byte-exact vs both the C legacy arms and today's `rt_eq_int/float` hexa round-trip (`(a<=b)&&(a>=b)`, `numeric.hexa:1294-1301`). Result is a TAG_BOOL image identical to `hexa_bool`'s, so the wrapper returns it directly. TAG_CHAR (8) eq is also register-only but NOT included (roadmap scope = scalar {0,1,2}; add later if wanted).

### b) `rt_truthy_native` — extend IN PLACE (STR/ARRAY/VALSTRUCT arms; R2, enables the carrier shrink)
Append before the final safety-net `return __hx_make_val(2, 1)`:

```hexa
    // TAG_STR (3): HX_STR(v) != NULL && HX_STR(v)[0] != 0  (runtime_core.c:8290)
    if __hx_payload_eq(tag, 3) {
        let p = __hx_str_ptr(v)                      // char* base as int payload
        let pnz = __hx_payload_nz(p)
        let pnzp = __hx_payload_add(pnz, 0)
        if __hx_payload_eq(pnzp, 0) { return __hx_make_val(2, 0) }
        let b0 = __hx_str_byte(v, 0)                 // movzx s[0]
        let nz = __hx_payload_ne(b0, 0)
        let nzp = __hx_payload_add(nz, 0)
        return __hx_make_val(2, nzp)
    }
    // TAG_ARRAY (5): HX_ARR_LEN(v) > 0  (runtime_core.c:8295; len is i32 ≥ 0)
    if __hx_payload_eq(tag, 5) {
        let n = __hx_arr_len(v)
        let z = __hx_make_val(0, 0)
        let gt = __hx_payload_gt(n, z)
        let gtp = __hx_payload_add(gt, 0)
        return __hx_make_val(2, gtp)
    }
    // TAG_VALSTRUCT (10): HX_VS(v) != NULL  (runtime_core.c:8306)
    if __hx_payload_eq(tag, 10) {
        let p = __hx_payload_add(v, 0)
        let nz = __hx_payload_nz(p)
        let nzp = __hx_payload_add(nz, 0)
        return __hx_make_val(2, nzp)
    }
```
**Named wall — TAG_MAP stays C**: the `__type__` probe needs `hmap_find` + `hexa_fnv1a_str` (external calls) + a string literal (breaks the zero-`.LC`/zero-extern seed contract). `hexa_truthy` therefore remains a C dispatcher whose residue = MAP arm + `default: return 1`.

### c) `rt_to_int_native(v) -> HexaVal` — tags {0,1} only
```hexa
fn rt_to_int_native(v: HexaVal) -> HexaVal {
    let tag = __hx_tag(v)
    if __hx_payload_eq(tag, 0) { return v }          // int passthrough (== rt_to_int)
    let r = __hx_payload_f2i(v)                      // (int64_t)HX_FLOAT(v) — cvttsd2si/fcvtzs
    let rp = __hx_payload_add(r, 0)
    return __hx_make_val(0, rp)
}
```
STR → `hexa_str_parse_int` stays the C delegate (wall: parser re-entry). Out-of-range doubles: `f2i` lowers to the same instruction the C cast compiles to per target — per-target byte parity holds (any x86↔arm value divergence pre-exists in C).

### d) `rt_to_float_native(v) -> HexaVal` — tags {0,1,2}
```hexa
fn rt_to_float_native(v: HexaVal) -> HexaVal {
    let tag = __hx_tag(v)
    if __hx_payload_eq(tag, 1) { return v }          // float: hexa_float(HX_FLOAT(v)) rebox == identity
    // int (0) / bool (2): payload 0/1 or i64 → (double)  == __hx_to_double arms
    let rf = __hx_payload_i2f(v)
    let rfp = __hx_payload_add(rf, 0)
    return __hx_make_val(1, rfp)
}
```
STR (float-parse via `__hexa_num_parse_float`) and VALSTRUCT (unwrap) arms of `__hx_to_double` stay C — walls.

### e) `rt_abs_native(v) -> HexaVal` — INT (non-INT64_MIN) + FLOAT
```hexa
fn rt_abs_native(v: HexaVal) -> HexaVal {
    let tag = __hx_tag(v)
    if __hx_payload_eq(tag, 0) {
        let z = __hx_make_val(0, 0)
        let lt = __hx_payload_lt(v, z)
        let ltp = __hx_payload_add(lt, 0)
        if __hx_payload_eq(ltp, 0) { return v }
        let r = __hx_payload_sub(z, v)               // 0 - v (== rt_abs_int)
        let rp = __hx_payload_add(r, 0)
        return __hx_make_val(0, rp)
    }
    let zf = __hx_to_double(0)
    let lt = __hx_payload_flt(v, zf)                 // false for NaN and -0.0
    let ltp = __hx_payload_add(lt, 0)
    if __hx_payload_eq(ltp, 0) { return v }          // NaN/-0.0 passthrough == rt_abs_float
    let rf = __hx_payload_fsub(zf, v)                // 0.0 - v
    let rfp = __hx_payload_add(rf, 0)
    return __hx_make_val(1, rfp)
}
```
Parity target = the release `rt_abs_float` behavior (`-0.0 → -0.0`, NaN → NaN), NOT the dead `#ifndef` sign-clear arm. **INT64_MIN flag**: hexa `0 - v` in `rt_abs_int` may BigInt-promote (#4161) while `payload_sub` wraps — the C wrapper pre-guards it (below) so behavior is preserved either way; add `abs(INT64_MIN)` to the parity corpus.

### f) `rt_null_coal_native(a, b) -> HexaVal` — fully native, no wall
```hexa
fn rt_null_coal_native(a: HexaVal, b: HexaVal) -> HexaVal {
    let tag = __hx_tag(a)
    if __hx_payload_eq(tag, 4) { return b }          // TAG_VOID
    if __hx_payload_eq(tag, 3) {                     // TAG_STR: NULL or lead-NUL → b
        let p = __hx_str_ptr(a)
        let pnz = __hx_payload_nz(p)
        let pnzp = __hx_payload_add(pnz, 0)
        if __hx_payload_eq(pnzp, 0) { return b }
        let b0 = __hx_str_byte(a, 0)
        let b0p = __hx_payload_add(b0, 0)
        if __hx_payload_eq(b0p, 0) { return b }
        return a
    }
    return a
}
```
Byte-faithful to the C legacy body (`runtime_core.c:2127-2131`); equivalent to the release `rt_null_coal` for every value `??` can produce (the NULL-ptr divergence is unreachable per `numeric.hexa:1233-1234`).

## 3. C-wrapper wiring (all edits in `self/runtime_core_emit.hexa`; regen `.c` follows)

New sub-guard **`HEXA_RT_VALOP_EQCOERCE_NATIVE`**, always nested under/beside `HEXA_RT_VALOP_NATIVE`. All arms are `#ifdef`-additive so guard-OFF is cpp-provably byte-identical.

1. **`hexa_eq`** (emitter ~8919, insert immediately before the cross-type ifs):
```c
#ifdef HEXA_RT_VALOP_EQCOERCE_NATIVE
    if (HX_TAG(a) <= TAG_BOOL && HX_TAG(b) <= TAG_BOOL) {
        extern HexaVal rt_eq_scalar_native(HexaVal a, HexaVal b);
        return rt_eq_scalar_native(a, b);   // TAG_BOOL image == hexa_bool's
    }
#endif
```
The existing cross-type lines + INT/FLOAT/BOOL switch arms become dead-for-scalars when ON; leave them (they still serve guard-OFF and non-scalar flow).

2. **`hexa_truthy`** (emitter 8664 block): add `case TAG_STR: case TAG_ARRAY: case TAG_VALSTRUCT:` to the delegate group under `#ifdef HEXA_RT_VALOP_EQCOERCE_NATIVE`, and wrap each of the three existing shared C arms in `#ifndef HEXA_RT_VALOP_EQCOERCE_NATIVE`. MAP + default stay unconditional C.

3. **`hexa_to_int`** (emitter 10047): inside the `HEXA_HAS_HEXA_RT_STDLIB` arm:
```c
HexaVal hexa_to_int(HexaVal v) {
#ifdef HEXA_RT_VALOP_EQCOERCE_NATIVE
    if (HX_TAG(v) <= TAG_FLOAT) { extern HexaVal rt_to_int_native(HexaVal v); return rt_to_int_native(v); }
#endif
    return rt_to_int(v);
}
```

4. **`hexa_to_float`** (emitter ~10023): same shape, eligibility `HX_TAG(v) <= TAG_BOOL`, fallback `rt_to_float(hexa_float(__hx_to_double(v)))` verbatim.

5. **`hexa_abs`** (emitter ~9919): eligibility `(HX_IS_INT(v) && HX_INT(v) != INT64_MIN) || HX_IS_FLOAT(v)` → `rt_abs_native(v)`; fallback = existing `rt_abs_int`/`rt_abs_float` delegates verbatim.

6. **`hexa_null_coal`** (emitter 2275-2284): under the sub-guard `return rt_null_coal_native(a, b);`, else existing `rt_null_coal(a, b)`.

**Retire `rtcore_eqtruthy_emit.hexa`** (independent of the truthy R2 extension — the carrier is drop-harness-only):
- Delete `self/native/rtcore_eqtruthy_emit.hexa`, `tool/regen_rtcore_eqtruthy_c.sh`, `tool/regen_rtcore_eqtruthy_native_o.sh`.
- `tool/zeroc_dropon_fixpoint.sh`: drop `-DHEXA_RT_CORE_EQTRUTHY_NATIVE=1` from `CLUSTER_DEFS` (:66) and `eqtruthy` from the stage-4c loop (:216) → `hexa_truthy` stays inline in runtime_core.o under drop (callees `hmap_find`/`hexa_fnv1a_str`/`rt_truthy_native` all resolve; no multidef since the seed `.o` is no longer built).
- `tool/zeroc_flip_measure.sh:154`: same def removal, lockstep.
- Emitter 8664: reduce the extern-guard to `#if defined(HEXA_RT_SELFEMIT)` (keep the SELFEMIT leg; the EQTRUTHY macro leg dies with the carrier).
- Lockstep contract note: with the carrier gone, the GENERATED-FAITHFUL mirror obligation (`rtcore_eqtruthy_emit.hexa:44-46`) disappears — the truthy wrapper edits in step 2 need no second-site mirror.

## 4. Regen + resolver (sealed contract)

- **`tool/regen_valop_core_native_s.sh`**: `SYMS` += `rt_eq_scalar_native rt_to_int_native rt_to_float_native rt_abs_native rt_null_coal_native`; `NSYMS=15`. Add the **sealed-contract total assert** (the macho-arm64-hexa-1 lesson — today's script only checks each listed sym ≥1; the current seeds are exactly 10/10 globl, verified): after the per-sym loop, `tot="$(grep -cE '^[[:space:]]*\.globl' "$raw")"; [ "$tot" -eq "$NSYMS" ] || fail` — total `.globl` == keeplist, no strays.
- **`tool/stage_resolve_runtime_a`** `resolve_native_valop_core_seed()` (:807-853): extend the sym list to the 15 (same stale-seed link-safety rationale), and at flip time export the sub-guard alongside: `$rt_valop_def="-DHEXA_RT_VALOP_NATIVE=1 -DHEXA_RT_VALOP_EQCOERCE_NATIVE=1"` (:1221-1225). **Single-TU/CUDA-host multidef lesson from unit #1 is auto-covered**: the def rides `$rt_valop_def`, which is already on all four runtime_core compile lines (:2606, :2611, :2647, :2663) — do NOT introduce a separate def var.
- **Frozen-blob check** (compiler/CLAUDE gotcha): confirm the 5 new `rt_*_native` names are absent from the frozen 151c52c8 symbol set before merging (they are new-namespace, expect clean).

## 5. Gating (design Q3 answered)

The valop seed is **auto-enabled default-ON** (`resolve_native_valop_core_seed` exports `HEXA_RT_VALOP_NATIVE=1` whenever the `.s` assembles), and runtime.a link pulls the whole `valop_core_native.o` member — so **regenerating the seed is inherently bit-CHANGING** even with every new C arm guard-OFF (new dead bodies land in `.text`). There is no byte-neutral path that includes the regenerated seed. Recommended staging (matches the cmp/div/mod in-place-extension precedent #3704–#3733):

- **PR-1 (extend, sub-guard OFF)**: valop_core.hexa fns + 3-target `.s` regen + emitter arms under `HEXA_RT_VALOP_EQCOERCE_NATIVE` (undefined) + regen-script/resolver updates + eqtruthy carrier retire. Behavior-neutral (new arms dead; `rt_truthy_native`'s new tag arms unreachable — the C wrapper only delegates the 4 scalar tags). Gate: byteeq 3-target fixpoint GREEN + cpp-proof of guard-OFF wrapper identity + shipping smoke.
- **PR-2 (flip)**: resolver adds the sub-guard def. Gate: byteeq 3-target + nvptx GREEN, `own-link corpus parity` + `cfallback-zero census` CI (the #1 unit's authoritative behavioral oracle — do NOT hand-build a clang+runtime.a A/B, that oracle was proven unreliable), a run-parity fuzz battery ON-vs-OFF over a HexaVal corpus for all 6 dispatchers (must include: NaN/±0.0/INT64_MIN, `2 == 2.0`, bool×int eq, lead-NUL and `""` strings for null_coal/truthy, out-of-range float→int), and shipping smoke. Merge on 3/3.

If release-integrity review insists on a zero-bit-change merge for PR-1, the fallback is a separate `valop_coerce_*.s`/`valop_coerce_native.o` seed ar'd only under an opt-in env, folded into valop_core at flip — workable but adds a second seed family; not recommended.

## 6. Named walls (stay C behind the guards)

- `hexa_truthy` TAG_MAP `__type__` probe (`hmap_find` + literal — breaks seed self-containment) — the dispatcher's C residue.
- `hexa_eq` non-scalar arms: STR intern+strcmp, ARRAY deep recursion (re-enters `hexa_eq`), MAP enum `__tag` deep-compare (snprintf + map gets), ENUM `_hexa_enum_display` (file-local static — the reason this fn was never carrier-able), FN/CLOSURE descriptor derefs.
- `hexa_to_int`/`hexa_to_float` STR arms (int-parse / float-parse re-entry) and `__hx_to_double`'s VALSTRUCT unwrap.
- `hexa_abs(INT64_MIN)` — wrapper pre-guard delegates to `rt_abs_int` (possible BigInt promotion #4161); verify item, not a blocker.

`hexa_null_coal` has **no wall** — it goes fully native. `hexa_ne` needs nothing (no such symbol; `!=` is codegen-side negation).
---

# WIRING RE-SPEC (seed-layer-corrected · supersedes §3-5 above)


Supersedes the wiring sections (§3–§5) of `valop_eqcoerce_reduction_spec.md` (on
`feat/axis2-valop-eqtruthy`). §1–§2 of the prior spec (fn bodies, walls, carrier census)
stand unchanged — the 15-sym valop_core.hexa source + 3-target .s seeds are authored and
15/15 T verified on the branch. Every claim below re-verified against the working tree.

## 0. Terrain corrections (verified against emitter/build sources)

The prompt's premise is itself half-right. The 4 coercion dispatchers split across TWO
different opt-in C-.o seeds, not one:

| dispatcher | extern-guard macro | seed emitter | opt-in env (build_aprime.sh) |
|---|---|---|---|
| `hexa_to_int` | `HEXA_RT_CORE_ARITH_COERCE_FORMAT_NATIVE` (emitter :10042) | `self/native/rtcore_arith-coerce-format_emit.hexa` | `HEXA_ZEROC_RT_CORE_ARITH_COERCE_FORMAT` (:726-752, default-OFF) |
| `hexa_null_coal` | same (emitter :2275) | same | same |
| `hexa_to_float` | **`HEXA_RT_CORE_MATH2_NATIVE`** (emitter :10020) | **`self/native/rtcore_math2_emit.hexa`** (r8 else-math, 12 fns) | `HEXA_ZEROC_RT_CORE_MATH2` (:522-548, default-OFF) |
| `hexa_abs` | **`HEXA_RT_CORE_MATH2_NATIVE`** (emitter :9916) | same | same |

- The ACF seed's 10 fns are `concat_many · fma · len · str_char_at · print · null_coal ·
  to_int · format · format_float · format_float_sci` (ACF emitter header :48-58). to_float/abs
  are NOT in it.
- Every one of these extern guards is the SHARED form
  `#if defined(HEXA_RT_SELFEMIT) || defined(<SEED>_NATIVE)` → `extern` / `#else` inline / `#endif`.
  The extern arm always wins over the inline body — this is the composition backbone (§2).
- Both seeds' bodies are the runtime_core.c `HEXA_HAS_HEXA_RT_STDLIB` delegate arms VERBATIM
  (mirror contract stated at ACF emitter :71, :87). The emitted `.c` files are untracked build
  artifacts (regen scripts `tool/regen_rtcore_{arith-coerce-format,math2}_native_o.sh`).
- Neither seed appears in `tool/stage_resolve_runtime_a` (grep: zero hits) — they are
  build_aprime/drop-harness leg-B link-de-risk opt-ins ONLY, never on the release runtime.a path.
- `hexa_truthy`: extern-guard `#if defined(HEXA_RT_SELFEMIT) || defined(HEXA_RT_CORE_EQTRUTHY_NATIVE)`
  (emitter :8664) — the eqtruthy carrier, as the prior spec had it.
- `hexa_eq`: UNCONDITIONAL definition (emitter :8919) — in no carrier. Prior spec correct.

## 1. Q3 — default-build path for the 4 coercion fns: INLINE stdlib-delegate C. Confirmed.

With all seed envs unset (the only shipped configuration — stage_resolve_runtime_a knows
neither macro), runtime_core.c compiles the inline `#else` arms:

- `hexa_to_int(v)      { return rt_to_int(v); }`                      (emitter :10047)
- `hexa_null_coal(a,b) { return rt_null_coal(a, b); }`                (emitter :2280-2282)
- `hexa_to_float(v)    { return rt_to_float(hexa_float(__hx_to_double(v))); }` (emitter :10023-10025)
- `hexa_abs(v)         { if (HX_IS_INT(v)) return rt_abs_int(v); return rt_abs_float(v); }` (emitter :9919-9922)

So the native flip IS vs the inline path. ACF/MATH2 are orthogonal measurement harnesses —
but not ignorable: the mirror contract obliges a lockstep text edit (§2), and un-mirrored
seeds would silently drop the fast path in harness runs.

## 2. Q2 — WHERE the native-scalar arm goes: Option A (+ verbatim seed-emitter mirror)

**Option B alone is WRONG-inert**: the seeds are opt-in-OFF and never linked by
stage_resolve_runtime_a, so a delegate placed only in the seed bodies would never execute on
the ship path. **Option C is rejected**: a superseding third guard would need to re-emit the
dispatcher bodies a third time → double-def/unreachable surface + byteeq churn for zero gain.

**Chosen: A+mirror** — the `#ifdef HEXA_RT_VALOP_EQCOERCE_NATIVE` fast-path goes in the
inline stdlib-delegate arm of `runtime_core_emit.hexa`, and the IDENTICAL guarded block is
mirrored into the two seed emitters (keeps the "EXACT same C" contract, ACF emitter :71).

Coherence proof against the three criteria:
- (i) guard-OFF byte-identical: every edit is `#ifdef`-additive; OFF preprocesses to today's
  token stream exactly. Seed .o regen without the def → byte-identical .o.
- (ii) composition: `#if SELFEMIT || SEED` extern-arm precedence means seed-ON removes the
  inline body from the TU entirely → no double-def ever, regardless of EQCOERCE state.
  seed-ON + EQCOERCE-ON: dispatcher comes from the seed .o, whose mirrored guard is dead
  (regen compiles def-less) → delegate semantics, identical behavior, fast-path bypassed —
  coherent. (Optional harness follow-up, NOT in scope: add the def to
  `zeroc_dropon_fixpoint.sh` CLUSTER_DEFS + the seed .o compile to light the fast path there.)
  EQCOERCE without VALOP is made impossible by a cpp tripwire (edit A1).
- (iii) byteeq-safe: same class as map-query #4913 (sub-guard additive arms; byteeq gate
  compares .text — line-number shift is the known non-issue).

## 3. Exact edits

### A. `self/runtime_core_emit.hexa` (SSOT — regen `self/runtime_core.c` after)

**A1 — tripwire** (insert after :8663, above the truthy guard, top-level):
```c
#if defined(HEXA_RT_VALOP_EQCOERCE_NATIVE) && !defined(HEXA_RT_VALOP_NATIVE)
#error "HEXA_RT_VALOP_EQCOERCE_NATIVE requires HEXA_RT_VALOP_NATIVE (both ride the valop_core seed)"
#endif
```

**A2 — `hexa_truthy`** (inline body :8667-8711, inside `#ifdef HEXA_RT_VALOP_NATIVE` case
group :8676-8679). Insert between :8678 (`case TAG_FLOAT:`) and :8679 (`case TAG_VOID: {`):
```c
#ifdef HEXA_RT_VALOP_EQCOERCE_NATIVE
        /* eqcoerce R2: STR/ARRAY/VALSTRUCT truthy go native (ptr/len probes, no
           runtime re-entry). MAP stays C — __type__ probe needs hmap_find + a
           string literal (breaks the zero-.LC/zero-extern seed contract). */
        case TAG_STR:
        case TAG_ARRAY:
        case TAG_VALSTRUCT:
#endif
```
Wrap the now-shadowed C arms: `#ifndef HEXA_RT_VALOP_EQCOERCE_NATIVE` around :8692-8697
(TAG_STR line + comment block + TAG_ARRAY line) and around :8707-8708 (rt-32-G comment +
TAG_VALSTRUCT line). TAG_MAP (:8703-8706) + `default:` (:8709) stay unconditional.
(These `#ifndef`s are safe precisely because A1 forbids EQCOERCE-without-VALOP.)

**A3 — `hexa_eq`** (:8919). Insert between :8924 (end of opening comment) and :8925
(first cross-type `if`):
```c
#ifdef HEXA_RT_VALOP_EQCOERCE_NATIVE
    /* sh-val-core #2: scalar eq (INT/FLOAT/BOOL incl. cross int<->float, incl.
       bool-vs-num tag-mismatch->false) goes native. rt_eq_scalar_native returns
       the TAG_BOOL image hexa_bool builds; non-scalars fall through to C. */
    if (HX_TAG(a) <= TAG_BOOL && HX_TAG(b) <= TAG_BOOL) {
        extern HexaVal rt_eq_scalar_native(HexaVal a, HexaVal b);
        return rt_eq_scalar_native(a, b);
    }
#endif
```

**A4 — `hexa_null_coal`** (:2280-2282, the stdlib arm inside the ACF `#else`). Body becomes:
```c
HexaVal hexa_null_coal(HexaVal a, HexaVal b) {
#ifdef HEXA_RT_VALOP_EQCOERCE_NATIVE
    extern HexaVal rt_null_coal_native(HexaVal a, HexaVal b);
    return rt_null_coal_native(a, b);
#else
    return rt_null_coal(a, b);
#endif
}
```
(`extern rt_null_coal` decl at :2279 stays — unreferenced-when-ON, emits no UND.)

**A5 — `hexa_to_int`** (:10047 one-liner, inside the ACF `#else` → stdlib arm). Becomes:
```c
HexaVal hexa_to_int(HexaVal v) {
#ifdef HEXA_RT_VALOP_EQCOERCE_NATIVE
    if (HX_TAG(v) <= TAG_FLOAT) { extern HexaVal rt_to_int_native(HexaVal v); return rt_to_int_native(v); }
#endif
    return rt_to_int(v);
}
```

**A6 — `hexa_to_float`** (:10023-10025, inside the MATH2 `#else`). Becomes:
```c
HexaVal hexa_to_float(HexaVal v) {
#ifdef HEXA_RT_VALOP_EQCOERCE_NATIVE
    if (HX_TAG(v) <= TAG_BOOL) { extern HexaVal rt_to_float_native(HexaVal v); return rt_to_float_native(v); }
#endif
    return rt_to_float(hexa_float(__hx_to_double(v)));
}
```

**A7 — `hexa_abs`** (:9919-9922, inside the MATH2 `#else`). Becomes:
```c
HexaVal hexa_abs(HexaVal v) {
#ifdef HEXA_RT_VALOP_EQCOERCE_NATIVE
    if ((HX_IS_INT(v) && HX_INT(v) != INT64_MIN) || HX_IS_FLOAT(v)) {
        extern HexaVal rt_abs_native(HexaVal v);
        return rt_abs_native(v);
    }
#endif
    if (HX_IS_INT(v)) return rt_abs_int(v);
    return rt_abs_float(v);
}
```
(INT64_MIN pre-guard: hexa-side `0 - v` may BigInt-promote #4161; delegate keeps rt_abs_int
semantics. Parity-corpus item, not a blocker.)

### B. Seed-emitter lockstep mirrors (same guarded text, verbatim)

- `self/native/rtcore_arith-coerce-format_emit.hexa` — `hexa_null_coal` body (:125-127) gets
  the A4 guard block; `hexa_to_int` (:131) gets the A5 block. Note the guard in the header
  census comment.
- `self/native/rtcore_math2_emit.hexa` — `hexa_abs` (:121) gets A7; `hexa_to_float` (:131)
  gets A6.
- The `.c` artifacts are untracked; regen scripts pick the change up. Both seed .o compiles
  pass no defs → guard dead → .o byte-identical (criterion i).

### C. `hexa_truthy` eqtruthy-carrier retire (prior spec §3, one correction)

Unchanged plan: delete `self/native/rtcore_eqtruthy_emit.hexa` +
`tool/regen_rtcore_eqtruthy_{c,native_o}.sh`; drop the def/loop entries; reduce emitter
:8664 to `#if defined(HEXA_RT_SELFEMIT)`.
**Correction**: `tool/zeroc_flip_measure.sh` has TWO sites, not one — the stage loop :113
AND the def :154 (prior spec cited only :154). `tool/zeroc_dropon_fixpoint.sh` :66 + :216
as before. If the retire is descoped, the A2 edit MUST instead be mirrored into
`rtcore_eqtruthy_emit.hexa` (it mirrors the full inline body incl. the VALOP guard).

### D. `tool/regen_valop_core_native_s.sh` (branch already at SYMS/NSYMS=15) — Q4

Two hardenings in `emit_one()`:
1. Sealed-contract total assert, after the per-sym `.globl` loop (after the `done`, ~:60):
```bash
    local tot
    tot="$(grep -cE '^[[:space:]]*\.globl[[:space:]]' "$raw" || true)"
    [ "$tot" -eq "$NSYMS" ] || { echo "[regen_valop_core] ERROR: $triple emitted $tot .globl (sealed contract: exactly $NSYMS — stray or missing)" >&2; exit 1; }
```
2. Harden the nm sanity (currently echo-only, ~:89): after computing `tcount`,
   `[ "$tcount" -eq "$NSYMS" ] || { echo "[regen_valop_core] ERROR: $triple nm T count $tcount != $NSYMS" >&2; exit 1; }`
   (keep the toolchain-missing WARN branch as-is).

If the total assert trips at 16 (e.g. a stray `_drv_unused`), that is the contract working —
fix the emit, don't relax the assert. **Q4 confirmed**: valop stays the simple self-contained
frozen-`.s` path — zero `.LC`, zero externs (regen header contract), no `--isolate`.

### E. `tool/stage_resolve_runtime_a`

- PR-1: extend the seed-safety symlist (:843-845) from 10 to the 15 syms (append
  `rt_eq_scalar_native rt_to_int_native rt_to_float_native rt_abs_native rt_null_coal_native`);
  update the adopt echo :854 `10/10` → `15/15`. Safe: the 15-sym seeds land in the same PR.
- PR-2 (the flip): :1223 →
  `rt_valop_def="-DHEXA_RT_VALOP_NATIVE=1 -DHEXA_RT_VALOP_EQCOERCE_NATIVE=1"`.
  The def rides `$rt_valop_def`, already present on all four runtime compile lines
  (:2606, :2611, :2647, :2663) — do NOT mint a separate def var (single-TU/CUDA-host
  multidef lesson, unit #1).

## 4. Q5 — staging + gen3≡gen4

- **PR-1 (extend, guard-OFF, inherently bit-changing)**: A+B+C+D + E(PR-1 part) + 3-target
  `.s` regen + `runtime_core.c` regen + frozen-151c52c8 check for the 5 new names
  (new-namespace, expect clean). Gates: byteeq 3-target fixpoint + faithful + shipping smoke +
  cpp-proof of guard-OFF wrapper identity. Bit-changing because the regenerated seed is
  auto-adopted default-ON (`resolve_native_valop_core_seed` :807-859) — new dead bodies enter
  `.text`; there is no byte-neutral path that includes the seed regen.
- **PR-2 (flip)**: the ONE def append at stage_resolve_runtime_a:1223 (single guard —
  `HEXA_RT_VALOP_EQCOERCE_NATIVE`; `HEXA_RT_VALOP_NATIVE` is already exported by the
  resolver). Gates per prior spec §5: byteeq 3-target + nvptx, own-link corpus parity +
  cfallback-zero census CI, ON-vs-OFF parity fuzz over the corpus (NaN/±0.0/INT64_MIN,
  `2 == 2.0`, bool×int eq, lead-NUL + `""` strings, out-of-range float→int), shipping smoke.
- **gen3≡gen4 unaffected — confirmed**: `tool/build_selfhost.sh:181` — the selfhost pipeline
  compiles its own rt.o "flag-free clang" and "never links the runtime.a
  stage_resolve_runtime_a" produces; the def cannot reach the fixpoint bytes. The
  `HEXA_RT_SELFEMIT` leg is likewise untouched (extern-arm precedence unchanged).
