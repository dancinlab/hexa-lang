# RFC: HexaVal 16B → 8B value layout (NaN-box / GC64)

Status: **🧱 MEASURED-INFEASIBLE (general 8B NaN-box)** — reopenable only if hexa drops
exact-i64 semantics (it will not). Research-phase = PR #4119 (assumed-infeasible). This
section = the **implement-phase re-run** the #4119 verdict named as T3 ("i64→i48 narrow
felt-default 수용 시 LuaJIT GC64 reference 재구동"): the LuaJIT GC64 reference is now
**exactly reproduced** and the i47 tradeoff **measured** against the hexa byteeq closure.
The verdict sharpens from *assumed* to *measured* infeasible.

---

## 1. LuaJIT GC64 reference — exact bit layout (정답지 정확복제)

Source: `LuaJIT/src/lj_obj.h` v2.1 (Mike Pall). Fetched + quoted:

```
upper 13 bits  = 1   (0xfff8…)   special NaN signal
bits 47..50    = itype (4-bit)   itype(o) = (uint32_t)(o->it64 >> 47)
low 47 bits    = payload          LJ_GCVMASK = ((uint64_t)1 << 47) - 1
                                   = pointer | zero-extended 32-bit int | all-1
ordinary double = bare native IEEE-754 double (the union `lua_Number n`, zero-overhead)
```

itype tags (bitwise-NOT, so all ≥ 0xFFFF_FFF…):
```
LJ_TNIL=~0  LJ_TFALSE=~1  LJ_TTRUE=~2  LJ_TLIGHTUD=~3  LJ_TSTR=~4  LJ_TUPVAL=~5
LJ_TTHREAD=~6  LJ_TPROTO=~7  LJ_TFUNC=~8  LJ_TTRACE=~9  LJ_TCDATA=~10  LJ_TTAB=~11
LJ_TUDATA=~12  LJ_TNUMX=~13
```

Integer encoding (the load-bearing detail the task premise mis-stated):
```c
static LJ_AINLINE void setintV(TValue *o, int32_t i) {
  o->i = (uint32_t)i; setitype(o, LJ_TISNUM);   // zero-extended 32-bit, NOT 47-bit
}
```
**LuaJIT integers are 32-bit**, zero-extended. The 47-bit field is for **pointers**.
Large/64-bit integers in Lua are carried as **doubles** (LJ_TNUMX, exact only within the
f64 53-bit mantissa) or as **heap-boxed FFI `int64_t` cdata** (a GC object *outside* the
NaN-box). LuaJIT has **no unboxed 64-bit integer** in a TValue — this is the crux.

## 2. hexa HexaVal mapping that a faithful GC64 复제 would require

```
16B  {tag@0:i64, payload@8:i64}                       ← current PAIR-MODEL (frozen)
 8B  {13-bit NaN | 4-bit itype | 47-bit payload}      ← GC64 复제
itype:  TAG_INT=0  TAG_FLOAT=1  TAG_BOOL=2  TAG_STR=3  TAG_VOID=4  TAG_ARRAY=5
        TAG_MAP=6  TAG_FN=7  TAG_CHAR=8  TAG_CLOSURE=9  TAG_VALSTRUCT=10  TAG_ENUM=11
        (self/runtime_core_emit.hexa:1200-1216 — fits the 4-bit itype, 12 ≤ 16 ✓)
f64   = bare double (zero-overhead, like GC64)
ptr   = 47-bit payload (x86_64/arm64 user VA ≤ 2^47 ✓ — pointers DO fit)
i64   = **47-bit narrow** (felt-default tradeoff)  ← THE WALL
```

## 3. MEASURED i47 ceiling — full-64 i64 in the byteeq closure (miscompile sites)

The hexa **language** exposes a first-class **exact 64-bit integer** (`i64`) with full
bitwise/shift/min semantics. A 47-bit payload cannot hold these, and they appear inside the
**self-host byteeq closure** (`compiler/main.hexa` import graph, incl. `codegen/x86_64_linux.hexa`
line 49-50) — i.e. the compiler would **miscompile itself**, breaking `gen3≡gen4`:

- **`compiler/codegen/x86_64_linux.hexa:1586`** — `let imin: i64 = 1 << 63` (INT64_MIN,
  `0x8000_0000_0000_0000`). Needs bit 63. Used for float sign-flip + integer min. In closure.
- **74 × `float_to_bits` / `bits_to_float` sites** (e.g. `x86_64_linux.hexa:1127, 2277`):
  every float constant the compiler emits materializes the **full-64-bit IEEE-754 bit
  pattern as a TAG_INT HexaVal** (codegen comment 2974-2975: "INT-tagged HexaVal carrying
  the IEEE-754 BITS"). Negative / large-exponent doubles set bits 47..63 → truncated under
  i47. This runs on **every compilation**. In closure.
- **Full-64 hash constants** — `self/llm.hexa:19 let h = 14695981039346656037`
  (FNV-64 offset basis `0xCBF29CE484222325`). Measured `> 2^53` by **1631×** → not
  representable in a 47-bit payload, **nor** in LuaJIT's 32-bit slot, **nor** exactly as an
  f64 (LuaJIT's large-int fallback also fails this value). 22 high-bit-shift + 56 wide-hex
  idioms across `compiler/`+`self/`.

Honest nuance: the compiler's **hot hash path** (`map_core.hexa`, `intern_core.hexa`) uses
**32-bit** FNV (`uint32_t`) and `emerge.hexa` masks `& 0xffffffff` — those *would* fit 47
bits. The killers are narrower but unavoidable: `1<<63` + the 74 float-bit sites (every
float literal) + user-facing exact-i64 contract.

**Why LuaJIT escapes and hexa cannot:** Lua's `number` is double-first with no exact-i64
guarantee; hexa's `i64` is an exact 64-bit integer type. The GC64 tradeoff (int=32-bit,
big-int=double-carried) is **semantically incompatible with hexa's i64 contract**. The
정답지 itself does not solve full-64 i64 in 8 bytes — it sidesteps it by not having the type.

## 4. cache-density lever — already delivered, byteeq-neutral, and CORRECTLY

The only honest win a NaN-box offers (8B array stride vs 16B, half the cache traffic) is
**already opt-in available without narrowing i64**:
- **`HEXA_PACK_ARRAY`** (`x86_64_linux.hexa:1328-1430`): proven typed-prim non-escaping
  arrays stored RAW PACKED (HexaArrI64/F64, 8B/4B contiguous, NO per-element tag, NO
  NaN-signal). Stride 16→8, default-OFF, byteeq-neutral. (V8 PACKED_SMI_ELEMENTS analog.)
- **`farr32`/`farr64`** read-path packed tensors (#3641/#3643, 522× RSS lever).

These win **precisely the case where the win exists** (homogeneous typed-prim), carry NO
tag at all (strictly denser than a NaN-box, which still spends 17 bits on signal+itype),
and **keep i64 full-width** everywhere else. A *general* 8B NaN-box HexaVal would apply to
heterogeneous/dynamic `[]` too — exactly the values that carry full-64 i64 → miscompile —
while delivering no density win PACK_ARRAY doesn't already deliver correctly.

## 5. Why no opt-in flag was emitted (anti-filler honesty)

A `HEXA_NANBOX` flag cannot be byteeq-neutral **by construction**: flag-ON, the compiler
compiling its own `1<<63` / `float_to_bits` (§3) would emit a 47-bit-truncated value →
gen3-ON ≠ correct → `gen3≡gen4` cannot hold the moment the compiler is self-compiled under
the flag. The ceiling is at the **type-semantics layer**, not the codegen-mechanism layer,
so a flag that demonstrates it is a flag that miscompiles — filler, declined per
implement-to-the-wall (the wall is *measured*, not a missing feature).

**Verdict 🧱:** general 16B→8B NaN-box = MEASURED-INFEASIBLE — full-64 i64 is hexa's
contract and appears in the byteeq closure (`1<<63` + 74 float-bit sites + FNV-64 >2^53).
LuaJIT GC64 exactly reproduced; its tradeoff (int=i32, big-int=f64/heap-cdata) is the
reason it fits 8B and the reason hexa cannot adopt it. The cache-density win is already
captured correctly & byteeq-neutrally by `HEXA_PACK_ARRAY` + `farr`. Reopen only if hexa
ever drops exact-i64 (it will not). DEFAULT byteeq untouched (no code/seed edit).
