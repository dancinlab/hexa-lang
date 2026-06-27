# RFC — struct field-access typed-offset (fleet-lab b · research-gate r1)

Status: research-gate (MINI-SAFE · no build/measure · doc-only)
Frontier (🧱 prior): every `obj.field` lowers to `hexa_map_get_ic(obj, "field", &ic)`
(`self/codegen.hexa:5756-5796`) → hash-map struct + per-site inline-cache probe.
The typed-offset path (`HEXA_TYPED_STRUCT=1`) exists but is **default-OFF** and
**byteeq-impacting** (`self/codegen.hexa:5771-5789` read-arm · `11410-11557` typedef/registry).

This round: reference-match the four canonical dynamic-language "object-field → O(1)
offset" mechanisms, then judge whether a **byteeq-safe** default-viable offset path or
an opt-in monomorphic specialization is reachable.

---

## 0. KEY FINDING — hexa ALREADY ships a JSC/V8-shape inline cache

The prior fleet framed the wall as "everything is a strcmp hash probe". That is **only
true on the IC *miss* path**. The runtime already emits a monomorphic inline cache that
is structurally identical to JSC's `get_by_id` fast path:

`hexa_map_get_ic` macro (`self/runtime_core_emit.hexa:3864-3873`) + `HexaIC` slot
(`runtime_core_emit.hexa:1180-1187`):

```c
typedef struct HexaIC { void* keys_ptr; int len; int idx; ... } HexaIC;  // shape-id = (keys_ptr,len), cached offset = idx
#define hexa_map_get_ic(M, KEY, IC) \
  ({ HexaVal __ic_m = (M); HexaIC* __ic = (IC); \
     (HX_MAP_TBL(__ic_m) \
      && (void*)HX_MAP_TBL(__ic_m)->order_keys == __ic->keys_ptr \   // ← "structure check"
      && HX_MAP_TBL(__ic_m)->len == __ic->len \
      && __ic->idx < __ic->len) \
         ? HX_MAP_TBL(__ic_m)->order_vals[__ic->idx] \               // ← load at CACHED OFFSET
         : hexa_map_get_ic_slow(__ic_m, (KEY), __ic); })             // ← slow path repopulates
```

This is **exactly** the JSC idiom (see §1.4): "compare cached StructureID against the
object's structure → on match, load at cached offset → on mismatch, slow path". hexa's
"StructureID" is the `(order_keys pointer, len)` pair; hexa's "cached offset" is `idx`
into `order_vals[]`. A monomorphic call site converges to ~100% hit and is a
**pointer-compare + int-compare + array load** — NO strcmp, NO hash on the hot path
(`runtime_core_emit.hexa:3779` comment: "converges to ~100% hit rate after 1 call").

Consequence: the residual gap vs V8/JSC is NOT "we have no inline cache". It is two
narrower things (§3): (a) the IC still indirects through `HX_MAP_TBL` + carries a 2-word
shape check + per-site static slot, vs a single integer StructureID compare; (b) the
backing store is a heap `HexaMapTable` (order_keys/order_vals arrays) rather than a flat
inline C-struct, so there is a pointer-chase and a per-instance allocation the flat path
removes. The `HEXA_TYPED_STRUCT` flat path attacks (b) directly.

---

## 1. Reference-match — canonical mechanisms

### 1.1 V8 — Maps (hidden classes) + transition tree + inline caches
Source: <https://v8.dev/docs/hidden-classes> · Bynens "Shapes and Inline Caches"
<https://mathiasbynens.be/notes/shapes-ics> · mrale "What's up with monomorphism?"
<https://mrale.ph/blog/2015/01/11/whats-up-with-monomorphism.html>

Mechanism (quoted/paraphrased from v8.dev/docs/hidden-classes):
- Every object points to a **Map** (hidden class); the Map's `DescriptorArray` records
  for each property whether it is in-object (`i0,i1,…`) or in the properties backing
  store (`p0,p1`) and **its fixed offset**. "accessing any property requires only a
  fixed-offset load operation rather than a dynamic lookup."
- Adding a property **transitions** to a new Map via a **transition tree**: "Each edge
  is a property name … 'if I were to add a property with this name … what class would I
  transition to?'" Sibling Maps **share one `DescriptorArray`** when properties are added
  in the same order — this is what makes same-shape objects share a Map identity.
- **Inline cache** = two-stage: **(1) Map check** (object's Map == cached Map) → **(2)
  fixed-offset access**. TurboFan folds `m2.cost` into "load the properties backing
  store, read out the first array element" — bypassing dynamic resolution entirely.
- Key invariant: objects must get properties **in the same order** to share a Map, else
  V8 cannot optimize (the IC goes polymorphic/megamorphic).

### 1.2 PyPy — maps (from Self) + storage array, JIT folds attr→fixed array index
Source: <https://pypy.org/posts/2010/11/efficiently-implementing-python-objects-3838329944323946932.html>
(historical root: Chambers/Ungar/Lee, *An Efficient Implementation of Self*, 1989).

Mechanism:
- The instance's dict is split: a **map** object (shared, describes "what instances of
  this shape look like" = `{attrname → index}`) + a per-instance **storage** array
  holding only the values.
- "The map includes numbers after attributes that are **indexes into the storage
  array**." → "the **JIT can turn attribute access into an array field read out of the
  storage array at a fixed offset**."
- Adding an attribute → new map (same shape-sharing as V8 transitions). The map is the
  PyPy analog of a hidden class; storage is the analog of the in-object backing store.

### 1.3 LuaJIT — table = array-part + hash-part; trace specializes the slot
Source: Percona/Habr "The Anatomy of LuaJIT Tables"
<https://percona.community/blog/2020/04/29/the-anatomy-of-luajit-tables-and-whats-special-about-them/>
· LuaJIT SSA IR <https://github.com/tarantool/tarantool/wiki/LuaJIT-SSA-IR>

Mechanism:
- A Lua table has an **array part** + **hash part**. The trace-compiler records bytecode
  along the taken control-flow and emits IR: **`AREF`** (array-part ref) and **`HREFK`**
  (hash ref **specialized to the hash slot where the constant key is expected**).
- LuaJIT "**specializes on type**"; with a constant key the lookup becomes a guarded
  load of the predicted slot — i.e. a *trace-time* IC: guard the table shape, then load
  the cached slot. NOTE: this is **trace-JIT** specialization, not AOT; hexa is AOT
  C-transpile/native-emit → LuaJIT's trace lever does **not** map onto hexa's pipeline
  (no trace recorder). Useful only as evidence that "constant-key → predicted-slot guard"
  is the universal idiom; not an implementable lever here.

### 1.4 JSC — StructureID + IC caches (StructureID, offset)
Source: caiolima "Inline Cache implementation on JSC"
<https://caiolima.github.io/jsc/2020/03/12/jsc-inline-cache.html> · WebKit docs
<https://docs.webkit.org/Deep%20Dive/JSC/JavaScriptCore.html>

Mechanism (quoted):
- Each `JSCell` header carries a **StructureID** = index into the runtime
  `StructureIDTable`; a `Structure` holds "where [properties] are stored relative to the
  object".
- `get_by_id` IC caches **(StructureID, property offset)**. Generated fast path:
  ```asm
  cmp $0xfa72, (%rax)   // StructureID check
  jnz <slow>            // structure mismatch → operationGetByIdOptimize
  mov 0x10(%rax), %rax  // load directly from cached offset
  ```
- This is the tightest reference for hexa's lever: a **single integer compare** (vs
  hexa's current 2-word pointer+len compare through an extra `HX_MAP_TBL` indirection),
  then a direct offset load.

### 1.5 Cross-reference synthesis
All four converge on the **same** invariant: *object identity is a shape token; a field
access guards the shape token then loads a per-shape-fixed slot.* V8/PyPy/JSC do it AOT-
or-baseline + cached; LuaJIT does it on traces. hexa already implements the V8/JSC fast
path at the **runtime** layer (§0). The open levers are purely about making the *shape
token cheaper* and the *backing store flat*.

---

## 2. byteeq constraint (why the flat path is currently default-OFF)

gen3≡gen4 byte-identical self-host requires the emitted C source (and thus the .o) to be
identical across generations. The `HEXA_TYPED_STRUCT` path changes the **emitted C
source** in three places, all relative to the hash-map default:

1. **decl emit** (`codegen.hexa:9080-9081`): flat-eligible struct → `gen2_flat_struct_typedef`
   emits `typedef struct Pt__flat {...}` + a flat malloc constructor, INSTEAD of the
   `hexa_struct_pack_map("Pt", n, _k, _v)` ctor. Different bytes.
2. **read emit** (`codegen.hexa:5781-5789`): `p.field` → `(((Pt__flat*)(p).vs)->fN)`
   INSTEAD of `hexa_map_get_ic(p,"field",&slot)`. Different bytes.
3. **ctor-call signature** is preserved (positional HexaVal params) so call sites are
   unchanged — but the two emit-site deltas above are enough to break byte-eq.

Therefore: **flipping `HEXA_TYPED_STRUCT` default-ON unconditionally would change the
self-host fixpoint output** → would require a fresh gen3≡gen4 reconverge on all 3 targets
AND a re-pin of the frozen seed `151c52c8`. That is the "default-ON is byteeq-impacting"
wall the prior fleet recorded. It is **real**, but it is a *fixpoint-reconverge* cost, not
a *correctness* wall.

---

## 3. byteeq-safe lever verdict

### Lever A — flat-offset default-viable? **NO (not byteeq-neutral as-is) — but reconvergeable**
A flag-gated emit that changes C source per the gate is **never** byte-neutral when
flipped: byte-eq compares the OFF-vs-OFF and ON-vs-ON outputs across generations, and
DEFAULT(=OFF) shim/struct sha must stay invariant per CLAUDE.md
(`project_hexa_m8_irreducible_floor`: "DEFAULT shim.o sha 불변"). So Lever A cannot be a
silent default flip. Two honest sub-options:

- A1 (reconverge): land flat path as the new default, accept a **one-time** gen3≡gen4
  reconverge + frozen-seed re-pin on x86_64-linux · arm64-linux · darwin-arm64. Cost is
  bounded and mechanical, but it touches the release-integrity guardrail (frozen seed) —
  **gate on aiden byteeq before any flip**, and only after a measured win justifies the
  reconverge churn. This is the canonical V8/PyPy lever (flat storage + offset) but it is
  NOT free under our fixpoint discipline.
- A2 (keep opt-in): leave `HEXA_TYPED_STRUCT` as the measured-perf opt-in it already is;
  byte-neutral by construction (DEFAULT path untouched). **This is what already ships.**

→ Verdict: Lever A is **viable but not byteeq-neutral**; default-viability requires a
deliberate reconverge (A1), so it is NOT a free default flip. Honest status = the prior
"default-OFF because byteeq-impacting" framing is **correct**.

### Lever B — cheaper monomorphic IC (single-integer StructureID), opt-in? **YES — UNTRIED, byteeq-safe as opt-in**
The reference-match surfaces a lever the prior fleet did **not** name: hexa's IC shape
check is a **2-word (pointer + len) compare through an extra `HX_MAP_TBL` indirection**
(`runtime_core_emit.hexa:3866-3869`), whereas JSC/V8 guard a **single integer
StructureID** (`§1.4`). A per-`HexaMapTable` monotonic **structure id** (`uint32_t
struct_id`, assigned once at ctor from the (type_name, ordered-key-set) shape) would let
the IC fast path become a **single int compare**:
```c
// opt-in HEXA_IC_STRUCTID=1 (default-OFF → byte-neutral DEFAULT path)
HX_MAP_TBL(m)->struct_id == ic->struct_id && ic->idx < ic->len
   ? order_vals[ic->idx] : slow(...)
```
This (a) drops one pointer compare + the `order_keys` deref from the hot path, (b) is a
**runtime-only** change behind an opt-in flag → DEFAULT shim/struct sha unchanged →
**byteeq-safe**, (c) is the literal JSC reference idiom. It does NOT need the flat
typedef and does NOT touch the self-host fixpoint when default-OFF.

→ Verdict: **Lever B is the byteeq-safe, untried, reference-backed lever.** It is an
opt-in monomorphic IC tightening, exactly the JSC `(StructureID, offset)` model, landable
without a fixpoint reconverge.

### Lever C — in-object inline storage (V8 `i0..`/PyPy storage array) for flat path? deferred
The flat path stores fields as `HexaVal fN` members already inline (`gen2_flat_struct_typedef`,
`codegen.hexa:11545`) — that IS the V8 in-object layout. The only thing above it is heap
malloc of the descriptor, which `HEXA_STACK_ALLOC` (`codegen.hexa:11579`) already attacks
for non-escaping bindings. So Lever C is **already realized inside the opt-in flat path**;
no new research lever here.

---

## 4. Next round

- **r2 (implement, aiden-gated):** Lever B — add opt-in `HEXA_IC_STRUCTID=1`: emit a
  `uint32_t struct_id` on `HexaMapTable` assigned at `hexa_struct_pack_map` from a
  process-global counter keyed by `(type_name, ordered key vector)` shape; add the
  parallel int-compare fast path in the `hexa_map_get_ic` macro behind the flag. Gate:
  **(1)** DEFAULT byteeq 3-target GREEN (flag-OFF shim/struct sha invariant), **(2)**
  flag-ON `HEXA_IC_STATS=1` hit-rate parity + a measured hot-loop field-access microbench
  (reference-match the JSC single-cmp fast path: count retired instructions, not wall),
  **(3)** correctness: ON==OFF stdout on the self-test corpus. Build/measure on aiden
  (mini = git/gh only).
- **r2-alt (A1, higher-risk):** flat-offset default reconverge — only if r2 measurement
  shows the IC tightening is insufficient and the flat storage win justifies a frozen-seed
  re-pin. Must go through release-integrity (3-target byteeq + ship smoke) first.
- **🧱 if r2 measures flat:** if Lever B's single-int IC shows ratio≈1.000 (no measured
  win over the existing 2-word check — plausible if the bottleneck is the `HX_MAP_TBL`
  pointer-chase / cache miss, not the compare), record measured-wall and pivot research
  to **storage flatness** (the PyPy storage-array / V8 in-object lever = the flat typedef
  A1 path), since then the compare is not the cost — the indirection is.

## 5. Reopen conditions
This wall is reopenable. Re-research targets if r2 walls: (a) V8 *in-object vs
out-of-object* property split heuristics (how many slots stay inline) for sizing the flat
typedef; (b) JSC `StructureID` allocation/recycling (32-bit id space, watchpoint
invalidation) for the struct_id counter design; (c) Self 1989 paper map-sharing proof for
the monomorphic-eligibility predicate already in `_is_flat_eligible_struct`.

---
Citations: V8 hidden-classes <https://v8.dev/docs/hidden-classes> · JSC IC
<https://caiolima.github.io/jsc/2020/03/12/jsc-inline-cache.html> · PyPy maps
<https://pypy.org/posts/2010/11/efficiently-implementing-python-objects-3838329944323946932.html>
· LuaJIT tables <https://percona.community/blog/2020/04/29/the-anatomy-of-luajit-tables-and-whats-special-about-them/>
· hexa runtime IC `self/runtime_core_emit.hexa:1180-1187,3864-3873` · hexa codegen
`self/codegen.hexa:5756-5796,9080-9081,11410-11557`.
