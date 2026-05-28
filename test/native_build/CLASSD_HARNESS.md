# F3 class-D BEHAVIORAL JIT-EXEC HARNESS — reusable runbook

`test/native_build/classd_behavioral_harness.c` is the committed, reusable,
table-driven behavioral gate for **class-D HexaVal-returning** runtime.c /
runtime_core.c bodies that the self-emit campaign ports to hexa's own ARM64
codegen. It replaces the per-wave throwaway `/tmp/hexa_classd_test.c` that
PRs #1914 / class-D scaleout-3 / batch2 each rebuilt by hand.

## Why a *behavioral* gate (not byte-identity-vs-clang)

Class-D bodies (`HexaVal rt_<name>(...)`) return a 16-byte `HexaVal` struct in
the `x0:x1` register pair (tag in `x0` low half, the `.i`/`.f`/`.b`/`.s` union
in `x1`). clang -O2 compiles them with auto-vectorization, and-mask fusion
(`isalpha` becomes `and x8,x1,#~0x20; sub; cmp #26; cset`), inlined ctors, and
tail-calls — reproducing that byte-for-byte = reimplementing clang's optimizer
(impossible, and NOT governance-mandated; see PR #1911's VERIFICATION-MODEL
FINDING). A self-hosting compiler emits ITS OWN correct machine code; the gate
is **observable behavior at the ABI boundary** — `tag` + value match the
reference C contract for every input.

## How it links (the load-bearing detail)

Each `_rt_<name>.o` (from `emit_rt_<name>_classd_o.hexa`) declares an
UNDEFINED-external ctor callee reached by ONE `ARM64_RELOC_BRANCH26` `bl`:

| body family                          | ctor callee  | return shape          |
|--------------------------------------|--------------|-----------------------|
| range predicates (isalpha, isalnum…) | `_hexa_bool` | `{TAG_BOOL, .b∈{0,1}}`|
| 0-arg constants (pthread_noop…)      | `_hexa_int`  | `{TAG_INT,  .i}`      |
| float transforms (future)            | `_hexa_float`| `{TAG_FLOAT,.f}`      |
| string transforms (future)           | `_hexa_str`  | `{TAG_STR,  .s}`      |

The harness PROVIDES those ctors as ABI-exact stand-ins (tag in `x0` low half,
union in `x1`) + the `HX_*` accessors. `ld64` binds the `.o`'s BRANCH26 to
them. In the LIVE `HEXA_RT_SELFEMIT` runtime the *same* `bl` binds to
runtime_core.c's real ctors — identical ABI, so a PASS here is a faithful
proxy for the activated symbol path (gate (d)).

## Run it

```
# 1. emit each .o (on-PATH hexa-run; HEXA_VAL_ARENA=0 keeps interp light).
#    env var = HEXA_RT_<NAME_UPPER>_CLASSD_O ; driver = emit_rt_<name>_classd_o.hexa
HEXA_RT_ISALPHA_CLASSD_O=/tmp/rt_isalpha_classd.o HEXA_VAL_ARENA=0 \
  hexa-run test/native_build/emit_rt_isalpha_classd_o.hexa
HEXA_RT_ISALNUM_CLASSD_O=/tmp/rt_isalnum_classd.o HEXA_VAL_ARENA=0 \
  hexa-run test/native_build/emit_rt_isalnum_classd_o.hexa
HEXA_RT_PTHREAD_NOOP_CLASSD_O=/tmp/rt_pthread_noop_classd.o HEXA_VAL_ARENA=0 \
  hexa-run test/native_build/emit_rt_pthread_noop_classd_o.hexa
HEXA_RT_PTHREAD_CREATE_POLICY_CLASSD_O=/tmp/rt_pthread_create_policy_classd.o \
  HEXA_VAL_ARENA=0 hexa-run test/native_build/emit_rt_pthread_create_policy_classd_o.hexa

# 2. link the harness against all emitted .o + run
clang -arch arm64 -O0 test/native_build/classd_behavioral_harness.c \
  /tmp/rt_isalpha_classd.o /tmp/rt_isalnum_classd.o \
  /tmp/rt_pthread_noop_classd.o /tmp/rt_pthread_create_policy_classd.o \
  -o /tmp/classd_harness && /tmp/classd_harness ; echo "rc=$?"
```

`rc=0` + `RESULT: ALL BEHAVIORAL CHECKS PASS` → behavioral gate PASS. The
range predicates are swept **exhaustively over all 256 codepoints** (every
boundary byte: `/0 9 : @ A Z [ \` a z {`, space, tab, 0x80, 0xff), strictly
stronger than the prior 14 hand-picked inputs. Constant bodies are called 4×
to catch register-state leaks.

## Prove it's hexa's OWN form (not clang's) that ran

```
otool -tvV /tmp/classd_harness | sed -n '/_rt_isalpha:/,/ret/p'
#   stp x29,x30,[sp,#-0x10]! ; mov x29,sp ; cmp x1,#0x41 ; b.lt … ; bl _hexa_bool ; ret
#   (scalar range-cmp form + bound bl — NOT clang's `and x8,x1,#~0x20; … b _hexa_bool`)
```

## Add the next body (the ~557-body scale-out loop)

1. Add the emitter `fn rt_<name>_classd()` (+ `_reloc_offs`/`_reloc_kinds` +
   `test_rt_<name>_classd`) to `self/codegen/runtime_arm64.hexa`, with hexa's
   OWN scalar instruction selection (NOT clang's). Verify the bytes round-trip
   via `as -arch arm64` (a legality proof, not a byte-eq-vs-clang gate).
2. Add the emit driver `test/native_build/emit_rt_<name>_classd_o.hexa`
   (env var `HEXA_RT_<NAME_UPPER>_CLASSD_O`).
3. Add an `extern HexaVal rt_<name>(...)` + one table row to
   `classd_behavioral_harness.c`:
   - bool-return range body → `sweep_int_unary_bool("rt_<name>", rt_<name>, ref_<name>)`
     with a `ref_<name>` mirroring the runtime.c C-fallback contract.
   - 0-arg int constant → `check_int_const("rt_<name>", rt_<name>, <want>)`.
   - float/str bodies → add a parallel `sweep_*` helper (same tag+value pattern).
4. Emit + link + run. PASS → activate via the class-D 3-way guard in runtime.c
   (`#if defined(HEXA_RT_SELFEMIT) extern … #elif !defined(HEXA_HAS_HEXA_RT_STDLIB)
   <C body> #else extern … #endif`) — additive only, default build stays
   byte-identical (verify: `clang -E -P -arch arm64 -I self self/runtime.c`
   diff vs origin/main on the guarded region = EMPTY). FAIL → REVERT that one
   body; never ship an unverified FLOOR body.

## Invariants this preserves

- **Default 0-extern build byte-identical** (guard off → no change). This file
  is additive; runtime.c is untouched by adding a harness row.
- **Self-host fixpoint** structurally preserved — `runtime_arm64.hexa` stays a
  shadow emitter (`grep -rn 'use .*runtime_arm64' self/codegen compiler tool`
  = 0), so the `hexa_cc.c` regen surface never moves.
- **`.c` count unchanged at 3** — this harness is `test/` infra, not a tracked
  runtime `.c`.
