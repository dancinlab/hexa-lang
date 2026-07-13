# axis-② unit #5 spec — `hexa_arr_zeros_leaf` / `hexa_arr_zeros_leaf_int` typed-array reduction

SSOT target: `state/hexa-own/axis2_array_zeros_leaf_spec.md`. Reasoned entirely from the pasted facts.

## 1. ABI verdict — GO, zero wall

Both fns are `(HexaVal)->HexaVal`: pure pair-in/pair-out, no `double` param (arr-f64's shim trigger) and no `const char*` param (contains_key's trigger) — this rides the pair model as-is, **no C-shim, no ABI arm**. GO.

## 2. Seed bodies

**File:** `stdlib/runtime/arr_zeros_leaf.hexa` (same home as the deployed `map_query.hexa` seed).

Decisions baked in, per sub-question:

- **(a) reading n:** `__hx_tag(nv)` then `__hx_payload_eq(t,0)` branch. INT arm: `__hx_payload_add(nv,0)` (raw payload = the int). Else arm: **`__hx_payload_f2i(nv)`** — cvttsd2si, exact parity with C's `(int64_t)__hx_to_double(nv)` for TAG_FLOAT. Parity scope note: for tags other than INT/FLOAT, C's `__hx_to_double` coercion may differ from raw-bits f2i; call sites pass numeric n, so this is out-of-contract (record it, don't fix it).
- **(b)** `calloc(1,32)` for the descriptor — heap_water@24 zeroed for free. `calloc` joins the U-floor (sanctioned).
- **(c)** n≤0: test is inverted to avoid `!`/plain ops — `let ok = __hx_payload_ge(n,1)`, all remaining work inside `if ok { }`, single `return out` at the end. The early-return state (items=NULL, len=cap=0) is exactly the calloc'd descriptor, untouched — matches C.
- **(d)** `__hx_payload_mul(n,16)` → `malloc(bytes)`.
- **(e)** OOM: `__hx_payload_eq(items,0)` → `write(2,msg,len)` + `exit(1)`. Fixed message, no `n=%lld` (no varargs in seed — same accepted parity delta on the abort path as the arr-i64 unit). Lengths: 27 (`"OOM in hexa_arr_zeros_leaf\n"`), 31 (`_int` variant).
- **(f) loop form — plain `i = i+1` is FORBIDDEN** (emits boxed `hexa_add_slow`, miscompiles as raw offset — convergence array-core-hexa-1). Safe form: **running byte offset + countdown, both via payload leaves, constant-k compare**: `off = __hx_payload_add(off,16)`, `rem = __hx_payload_sub(rem,1)`, condition `go = __hx_payload_ge(rem,1)` recomputed at loop tail into a `let mut go` consumed by `while go`. No per-iteration multiply. Each 16B element = **two `__hx_ptr_store64`**: tag word @off, payload word (always 0) @off+8.
- **(g)** descriptor writes are **int64 @8/@16** — `store64(a,8,n)` and `store64(a,16,n)`. Do NOT copy the i64 seed's `store32 @8/@12`; the boxed HexaArr is a different struct (items@0, len i64@8, cap i64@16, heap_water@24, sizeof=32).

**Full seed text (verbatim):**

```
// arr_zeros_leaf.hexa — axis-② unit #5: boxed zeros constructors (TAG_ARRAY of 16B HexaVal)
// guard: HEXA_RT_CORE_ARRAY_ZEROS_LEAF_NATIVE

extern fn malloc(n:int)->int
extern fn calloc(cnt:int, size:int)->int
extern fn write(fd:int, buf:int, n:int)->int
extern fn exit(code:int)

pub fn hexa_arr_zeros_leaf(nv:HexaVal)->HexaVal {
  let a = calloc(1, 32)                    // zeroed boxed-HexaArr: items@0 len@8 cap@16 heap_water@24
  let out = __hx_make_val(5, a)            // TAG_ARRAY=5, payload = descriptor ptr
  let t = __hx_tag(nv)
  let is_int = __hx_payload_eq(t, 0)       // TAG_INT=0
  let mut n = 0
  if is_int {
    n = __hx_payload_add(nv, 0)            // raw payload = the count
  } else {
    n = __hx_payload_f2i(nv)               // cvttsd2si == (int64_t)double
  }
  let ok = __hx_payload_ge(n, 1)
  if ok {
    let bytes = __hx_payload_mul(n, 16)
    let items = malloc(bytes)
    let isnull = __hx_payload_eq(items, 0)
    if isnull {
      let m = "OOM in hexa_arr_zeros_leaf\n"
      let mp = __hx_payload_add(m, 0)
      write(2, mp, 27)
      exit(1)
    }
    let mut off = 0
    let mut rem = n
    let mut go = __hx_payload_ge(rem, 1)
    while go {
      __hx_ptr_store64(items, off, 1)      // tag word: TAG_FLOAT=1
      let off8 = __hx_payload_add(off, 8)
      __hx_ptr_store64(items, off8, 0)     // payload word: 0.0 bits = 0
      off = __hx_payload_add(off, 16)
      rem = __hx_payload_sub(rem, 1)
      go = __hx_payload_ge(rem, 1)
    }
    __hx_ptr_store64(a, 0, items)          // items @0
    __hx_ptr_store64(a, 8, n)              // len  int64 @8  (NOT the i64-seed i32@8)
    __hx_ptr_store64(a, 16, n)             // cap  int64 @16 (NOT i32@12)
  }
  return out
}

pub fn hexa_arr_zeros_leaf_int(nv:HexaVal)->HexaVal {
  let a = calloc(1, 32)
  let out = __hx_make_val(5, a)
  let t = __hx_tag(nv)
  let is_int = __hx_payload_eq(t, 0)
  let mut n = 0
  if is_int {
    n = __hx_payload_add(nv, 0)
  } else {
    n = __hx_payload_f2i(nv)
  }
  let ok = __hx_payload_ge(n, 1)
  if ok {
    let bytes = __hx_payload_mul(n, 16)
    let items = malloc(bytes)
    let isnull = __hx_payload_eq(items, 0)
    if isnull {
      let m = "OOM in hexa_arr_zeros_leaf_int\n"
      let mp = __hx_payload_add(m, 0)
      write(2, mp, 31)
      exit(1)
    }
    let mut off = 0
    let mut rem = n
    let mut go = __hx_payload_ge(rem, 1)
    while go {
      __hx_ptr_store64(items, off, 0)      // tag word: TAG_INT=0 — the ONLY diff vs float variant
      let off8 = __hx_payload_add(off, 8)
      __hx_ptr_store64(items, off8, 0)
      off = __hx_payload_add(off, 16)
      rem = __hx_payload_sub(rem, 1)
      go = __hx_payload_ge(rem, 1)
    }
    __hx_ptr_store64(a, 0, items)
    __hx_ptr_store64(a, 8, n)
    __hx_ptr_store64(a, 16, n)
  }
  return out
}
```

Two implementer conformance notes (both "mirror the deployed arr-i64 seed if it differs"): (1) the OOM string→raw-ptr extraction (`__hx_payload_add(m,0)`) must be byte-for-byte the idiom the deployed arr-i64 seed uses for its OOM message; (2) the `if is_int` / `while go` condition form assumes the `__hx_payload_eq/ge` leaves type as bool — if the checker wants a different condition shape, copy the exact form of arr-i64 push's len≥cap check.

## 3. Tag constant — TWO near-identical bodies, no shared helper

Confirmed: the fns differ only in the element tag word (1 vs 0) and the OOM string; the payload word is 0 in both (0.0 IEEE bits = 0), and the TAG_ARRAY=5 mint is common. **Pick: two duplicated bodies.** Rationale: the parity target has two independent C bodies; a shared `fill(nv, tagw)` helper adds (i) a third symbol into the .o with no C counterpart, (ii) an internal call frame the parity target lacks, and (iii) a plain-`int` parameter flowing into `store64`'s value slot under seed lowering — an unforced risk for ~15 saved lines. Duplication is the cleaner compile under the one-leaf-per-let discipline.

## 4. Wiring

- **(a) Emitter guard:** fold into the existing 2-arm block at ~9422 — extend the extern-arm condition to `#if defined(...SELFEMIT) || defined(...TYPED_LEAF) || defined(HEXA_RT_CORE_ARRAY_ZEROS_LEAF_NATIVE)`; `#else` keeps the C bodies. No distinct third arm — the extern arm's content is identical for all three predicates, and one guard flips both fns since the seed provides both.
- **(b) Resolver:** `resolve_native_array_zeros_leaf_seed` in `tool/stage_resolve_runtime_a` — own-obj `--isolate` primary + frozen-.s fallback; defines `HEXA_RT_CORE_ARRAY_ZEROS_LEAF_NATIVE` when active; A0 cached-shortcut gated on `[ "${HEXA_RT_OWNOBJ:-0}" = "0" ]`. Per-unit env `HEXA_RT_ZEROS_LEAF_NATIVE` (mirror the arr-i64 unit's env naming if it differs), `:-0` in PR-1.
- **(c) Def-var:** `rt_arr_zeros_def`, threaded into all **5** runtime_core.c compile lines, **preserving trailing spaces** (convergence stage-resolve-flag-space-1).
- **(d) Regen:** `tool/regen_array_zeros_leaf_native_s.sh` — `SYMS="hexa_arr_zeros_leaf hexa_arr_zeros_leaf_int"`, `NSYMS=2`, `ALLOWED_U="malloc calloc write exit"`.
- **(e) Call site:** invoke the resolver in stage_resolve_runtime_a alongside the four deployed units (map-query / valop / arr-i64 / arr-f64), same position pattern.
- **KG symbols:** `{hexa_arr_zeros_leaf, hexa_arr_zeros_leaf_int}`. **U-floor:** `{malloc, calloc, write, exit}` — calloc is the only new entrant, sanctioned.
- **Collision flag — grep is MANDATORY before flip.** The 9418 comment ("new names = no conflict with the s4 static injection") only clears the s4 static-injection lane; it says nothing about a second unconditional body elsewhere in the emitter (exactly how arr-f64 got bitten by the hidden `push_bits` body, convergence runtime-core-emit-hexa-3). PR-1 checklist item: grep the emitter source AND the generated `self/runtime_core.c` for `hexa_arr_zeros_leaf` and confirm exactly one definition site per fn (the guarded block) plus extern decls only.

## 5. Staging + walls — WALL-FREE

- **PR-1** (seed + 5-piece wiring, guard default-OFF): behavior-neutral — with the guard OFF the C bodies are emitted unchanged. Gates: gen3≡gen4 byteeq fixpoint, byteeq 3-target GREEN, duplicate-body grep clean.
- **PR-2** (flip `HEXA_RT_ZEROS_LEAF_NATIVE` default `:-0`→`:-1`, bit-changing): gates: byteeq 3-target GREEN + faithful pool build + shipping/install consumer smoke — never promote on x86-only green.

No genuine wall. The 16B boxed store is cleanly two `store64`s (no missing primitive); the int64@8/@16 descriptor offsets are a copy-paste **trap**, not a wall — pinned in §2(g); calloc in the floor is sanctioned; the tag-branch n read has an exact leaf (`__hx_payload_f2i`). The only novelties vs arr-i64 are exactly those three, all resolved above. Two documented parity deltas, both out-of-contract: (i) non-INT/FLOAT tags for `nv` bypass C's `__hx_to_double` coercion; (ii) C stores `(int)n` (truncated then widened) into int64 len/cap while the seed stores full `n` — divergent only for n≥2³¹, which needs a ≥32 GiB allocation and hits OOM first, and where C's truncation is itself a bug.
---

## Implementer corrections (validated vs deployed f64 seed origin/main + HexaVal layout probe · 2026-07-13)

Spec is GO. Three idiom corrections before authoring the seed (mirror the DEPLOYED
`stdlib/runtime/array_typed_leaf_f64.hexa`, not the draft form):

1. **OOM message char* bridge** — use `__hx_str_ptr("OOM in hexa_arr_zeros_leaf\n")` (the deployed
   idiom), NOT the draft's `let m = "..."; let mp = __hx_payload_add(m, 0)`. Deployed f64 push does
   `let msg = __hx_str_ptr("OOM in arr_f64_push\n"); write(2, msg, 20); exit(1)`. So:
   `let msg = __hx_str_ptr("OOM in hexa_arr_zeros_leaf\n"); write(2, msg, 27); exit(1)` (27 chars incl \n;
   `_int` variant = "OOM in hexa_arr_zeros_leaf_int\n" = 31).
2. **Conditions inline** — mirror deployed inline `if __hx_payload_ge(len, cap) { }` / `if __hx_payload_eq(nd, 0) { }` /
   `if __hx_payload_lt(c, 1) { }` form rather than `let ok = ...; if ok { }`. Functionally equivalent but the
   deployed seeds inline the payload-leaf predicate directly in `if`. The `while go` loop var is the one place a
   `let mut go = __hx_payload_ge(rem,1)` bound var is unavoidable (recomputed at loop tail) — that's fine, it's
   the first seed with a loop (deployed seeds are straight-line; while is standard hexa, aprime-lowerable).
3. **HexaVal memory layout CONFIRMED** (byte-store order is correct): `struct HexaVal_ { HexaTag tag; union{int64_t i;
   double f; ...}; }`. The union (8-byte-aligned via its int64/double member) sits at **offset 8**; tag at **offset 0**.
   So each 16B element store = `store64(items, off, tagword)` (tag @0) + `store64(items, off+8, 0)` (payload @8) —
   exactly the draft's order. C's `items[i] = (HexaVal){.tag=T,.f/.i=0}` zeroes tag-padding@4-7 + payload@8 too, so
   the two store64 (tagword small, payload 0) reproduce C's compound-literal bytes. No layout wall.

Everything else in §1–§5 stands. PR-1 = seed `stdlib/runtime/arr_zeros_leaf.hexa` (with these 3 fixes) + 5-piece
wiring (emitter sub-guard fold at ~9422, resolver resolve_native_array_zeros_leaf_seed mirroring
resolve_native_array_f64_leaf_seed, rt_arr_zeros_def def-var ×5 compile lines, regen_array_zeros_leaf_native_s.sh,
call site), guard-OFF byte-neutral. MANDATORY pre-flip: grep emitter + generated runtime_core.c for a second
unconditional hexa_arr_zeros_leaf{,_int} body (conv runtime-core-emit-hexa-3 — arr-f64's hidden push_bits trap).
PR-2 = .s regen on summer (aprime_cc) + flip HEXA_RT_ZEROS_LEAF_NATIVE :-0→:-1.
