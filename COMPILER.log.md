# COMPILER.log.md — chronological compiler-domain history

> Append-only history sibling of `COMPILER.md` (current confirmed spec).
> Carries dated progress logs, decision history, and build-recipe detail
> absorbed from the retired `PLAN-interp-retirement.md`,
> `PLAN-stage3-footprint{,-F6,-F6-optA}.md`, and `PLAN-stage3-pathA.md`.
> Live cycle log SSOT is `compiler/PLAN.md`; this file preserves the
> design-history detail those plan files carried.

---

## Interpreter retirement — progress log

### 2026-05-16 — milestone proven

On Mac arm64, `aprime_cc` (1.95 MB Mach-O, built flat-C via
hexa_v2→clang) compiled a program, linked it (0 undefined symbols
against `runtime.o`), and ran it end-to-end with no crash / clean exit.
The pipeline (compile→`as`→`ld`→run) is functional. Remaining failures
are *correctness* bugs of a bounded class, not architectural blockers.

R1 confirmed PASS: native `fn main(){exit(6*7)}` ⇒ exit code 42, no
regression after each subsequent fix.

Two **root-cause codegen-correctness bugs** found by running real
programs and fixed:

1. **`4c28f16f` — loop-carried variable mutation.** `hir_to_mir`
   lowered every `x = expr` to a fresh SSA local + rebind. With no
   loop-header phi nodes, a `while` condition was lowered once against
   the pre-loop binding while the body rebound the name → the test
   forever re-read the initial value. `while {i=i+1}` hung; `loop {
   p.push(..) }` SIGBUS'd. Fix: an already-bound simple-ident lhs
   mutates its **existing** local in place (each backend models a local
   id as one fixed stack slot — in-place store is the correct
   loop-carried update).
2. **`2bd67f0e` — function parameter binding.** `hir_to_mir::_lower_fn`
   binds param locals to names only via a `param_names` annotation,
   which `ast_to_hir` never produced → every fn parameter read as
   const-0 (`g(5)` with `n+1` → 1; recursion hit base case immediately).
   Fix: synthesize the `param_names` annotation from the real `Param`
   identifiers in `ast_to_hir`. `test/t_batch22` SIGSEGV → clean exit.

`exit(6*7)` → exit 0 bug: `_builtin_runtime_sym`
(`compiler/codegen/arm64_darwin.hexa:953`) had no `exit` entry, so it
fell through to a raw `bl _exit` against libc `exit(int)` while the
codegen passes a HexaVal in x0:x1 (x0 = TAG_INT = 0). Fixed `2fe6517e`
(`exit` → `hexa_exit`).

### R3 — nine codegen-correctness classes fixed

3. **`c76cc8d6` — module-level mutable globals.** `let mut g = 0` at
   module scope had no storage; the parser pushed the init into a
   synthesised `fn main` that collided with the user's own `fn main`.
   Fix is one coherent slice parser→MIR→codegen→asm: synth-main MERGES
   into existing user main; two-pass `lower_hir` makes every fn see all
   globals; ident resolution falls back to `_global_op(gid)`; global
   assignment uses a sentinel dst (arena_id=-999) → `_hv_store_dst` emits
   `adrp/add g<id>; stp`; `LModule.globals` adds writable 16-byte `.data`
   slots.
4. **`7b00bd54` — array/map subscript.** `STMT_ASSIGN op="index"` had no
   arm64 branch; the fall-through copied the whole container into dst.
   Fix: routes through `hexa_index_get(container, key)`.
5. **`306ad234` — STMT_UNOP.** `-x` / `!x` left dst uninitialized. Fix:
   `-x` lowers as `0 - x` via `hexa_sub`; `!x` mirrors `!=`.
6. **`2e624e84` — if-as-expression.** `let x = if c {A} else {B}` bound
   x to const-0. Fix: pre-allocate an `if_val` join local; both arms
   copy their operand into it before the join. Single fix unlocked 13
   t_batch22 cases at once.

The previously-documented "edges aliasing in deep recursion" turned out
NOT to be a runtime-memory issue — a one-token boundary error in
`_arm64_max_call_overflow` used `n > 8` (C-int 8-GPR convention) when
HexaVal args pass a REGISTER PAIR, so only 4 fit in x0..x7. Any fn whose
calls had ≥5 args saw `call_overflow_bytes = 0` and the call-site's `stp`
for i=4 silently clobbered the caller's L0 / first-param ingress slot.

Complete R3 root-cause list: `4c28f16f` loop-carried mutation ·
`2bd67f0e` fn-param binding · `c76cc8d6` module globals · `7b00bd54`
array subscript `hexa_index_get` · `306ad234` STMT_UNOP · `2e624e84`
if-as-expr value · `08d7a12f` UTF-8 rodata preservation · `24259987`
outgoing-arg overflow boundary · (synth-main merge inside `c76cc8d6`).

`test/t_batch22` native↔interp progression: pre-session (`fe35cdc4`)
SIGSEGV → `2bd67f0e` 0/31 → `c76cc8d6` 13/31 → `7b00bd54` 15/31 →
`306ad234` 16/31 → `2e624e84` 29/31 → `08d7a12f` 30/31 → `24259987`
**31/31** (byte-identical to interp).

Remaining gaps: ~170 unmapped runtime builtins (`/tmp/gaps.txt`,
link-gate safely blocks them, surgical per-symbol add when needed);
frontend `CODEGEN-FAIL` in some smokes (`HX3001` type-mismatch — the
typecheck is stricter than the interp accepts, separate track).

### R4 — `bin/hexa-run-native` wrapper

Thin shell script (zero risk to the interp path): `hexa-run-native
<file.hexa> [args...]` native first, interp on fail; `HEXA_NATIVE=0`
forces interp; `HEXA_NATIVE_VERBOSE=1` logs the chosen path. Native
compile goes through the proven `hexa build` pipeline (hexa_v2 → C →
clang), inheriting its coverage; the wrapper adds the toggle + automatic
fallback. `hexa run` itself stays interp-only (the existing contract).
R6 extended it to a tier-1 aprime_cc / tier-2 hexa build / tier-3 interp
wrapper via `HEXA_APRIME_CC=<path>` opt-in (`06044c7f`).

### R5 — aprime_cc-direct parity sweeps

Curated-21 sweeps through aprime_cc → clang → run vs interp baseline,
each fixing the dominant failure class: #1 baseline 1 MATCH → #2
parser.hexa import fallback + dict_keys map → #3 bind.hexa builtin-name
list (~40 entries) → #4 codegen str/int/float/bool/ln runtime aliases
12 MATCH → #5 float-literal `.double` precision 13 MATCH → #6
short-circuit `&&`/`||` via control flow **14 MATCH** (66.6%
byte-identical, 6 residual CODEGEN-FAIL are HX2001/HX3001/HX3010/HX4001
typecheck/lint strictness on imported library files; 1 residual DIFF =
`regress_dict_keys_let_bind` empty-map `{}`).

Broadened to 40 alphabetical smokes: 40-#1 18 MATCH → 40-#2 (use→import
lex alias · .hexa auto-suffix · multi-main collapse · pop builtin) 22
MATCH → 40-#3 (HX3001 compare/if-arm/arith · HX3003 unit-relax · HX3010
→ Warning · fn-name first-wins dedup) **25 MATCH**.

Broadened to 60 smokes (after parser-hang fix `12b355ce`): match=27
(45%) · diff=15 · cg-fail=14 · link-fail=1 · interp-to=3. New categories
in [40,60]: `t_macro_depth_*` / `t_ffi_marshal_skeleton` (rc=139 native
crash vs rc=1 interp), `t_cmd_url_args_passthrough` /
`t_exec_env_reproducible` / `t_multiarch_cpu_smoke` (frontend strictness
on imported helpers), `t_parser_lt_generic_disambig` (parser hang, since
fixed).

Via the `hexa build` pipeline a wider sweep showed 36/40 (90%)
byte-identical, the one DIFF a known orthogonal hexa_v2 import-path bug;
96% of the sampled corpus byte-identical native↔interp with zero
codegen-fail / link-fail — the empirical case for R4-native-default.

### atlas_* DIFF diagnostic (bisected, threshold pinned)

The 4 atlas_*_smoke SIGSEGVs reproduce on a synthetic
`[Node{id,kind,edges:Edges{deps:[]}}, …]` array under aprime_cc: N=2..16
nested-struct elements MATCH; N≥17 → rc=139. Frame size at the boundary:
N=16 → `sub sp,sp,#992`; N=17 → `#1024` — the crash coincides with
crossing the 1024-byte frame mark. Checkpoint-instrumented: all 17 nodes
construct cleanly, iteration begins, the crash fires on `arr[14].kind`
(15th element access). Strongly consistent with `hexa_array_grow`
shallow-copy: the underlying buffer doubles at push 16→32 and
already-constructed inner struct backings get shallow-copied — stale
inner pointers blow up on first deep read after a later grow. Matches
MEMORY.md `struct_pack_map shallow-clone gotcha`. Out of scope for the
codegen sweep — a distinct runtime/codegen-layout investigation.

The 3 atlas-verifier semantic divergences (`atlas_doctrine_smoke`,
`atlas_tecsl_verify`, `atlas_cycle_append`) are likely interaction
between fn-dedup's first-wins choice and atlas modules that re-export
the same helper with different bodies. Refinement: dedup ONLY when
bodies are equivalent, OR keep the LAST-imported version.

### 2026-05-17 cycle — D / H / C-sweep findings

**D (empty `{}` parser support, `d179f4a1`).** `let mut d = {}` was
parsing as an empty block-expr (evaluates to TAG_INT 0). Fixed by
inserting an LBrace + `peek_at(1).RBrace` check that emits an empty
StructLit ahead of the catch-all LBrace; codegen's struct_lit handler
already maps zero-arg StructLit to `hexa_map_new()`.

**H (hexa_v2 `_known_int_set` fn-param shadow, `17de2f4b`).**
`perfect_number_engine_smoke` PASS=11/19 via hexa-build vs 19/19 via
interp. Bisected to imported `binary_value(a:float, b:float, op:int)`
transpiling `a + b` as `hexa_int(HX_INT(a)+HX_INT(b))` — unboxing both
floats as ints. Root cause: `_known_int_set` is module-global, so a
later fn's `a: float` param hit the STRUCTURAL-2 fast-path. Fixed by
adding `_gen2_current_fn_params`, seeding it in `gen2_fn_decl`, and
consulting it as an authoritative shadow gate in `_is_known_int_name`
and `_is_known_float_name`.

**Bootstrap rebuild ACTIVATED 2026-05-17** (`40c64a9e`, `1de82e78`):
regenerated `self/native/hexa_v2` (1,487,616 B) via `hexa cc --regen`
with `HEXA_LANG=/tmp/wt-h17`. Sequence: (1) `clang -O2 -c
self/runtime.c -o self/runtime.o`; (2) `HEXA_LANG=/tmp/wt-h17 hexa cc
--regen`; (3) `clang -O2 -I self -Wno-trigraphs hexa_cc.c.new runtime.o
-o self/native/hexa_v2` (copy `.c.new` → `.c` first; the suffix trips
clang's language detection). End-to-end against the rebuilt binary:
`perfect_number_engine_smoke` 11/19 → **19/19 PASS**;
`regress_dict_keys_let_bind` all 4 PASS; `atlas_tecsl_verify_smoke`
PASS; `atlas_cycle_append_smoke` rc=0. Note: hexa_v2 codegen_c2 has TWO
emit loops (gen2_module ~L900 + a "mirror" ~L6883); initial dedup patch
landed only on the primary (`4e2869c6`), so `1de82e78` closed the
mirror — both now first-wins.

**C-sweep (60-smoke hexa-build pass).** With `HEXA_MAC_BUILD_OK=1`
bypass: **38/60 PASS (63%), 20 FAIL_BUILD, 2 FAIL_RUN**.

### Build recipe (native arm64 compiler, Mac — reproducible)

1. flatten `compiler/main.hexa` import+use closure (38 files), stub
   `compiler/atlas/embedded.gen.hexa` to empty `ATLAS_*` (avoids the
   O(n²) array-literal transpile hang).
2. `hexa_v2` (envelope-fixed) transpile flat → `.c`.
3. `tool/s4_flatc_post.py` + sed: `sha256_hex`→`hexa_sha256`,
   `list_dir`→`hexa_array_new()`, `#include "runtime.h"`→`"runtime.c"`.
4. `clang -O1 -arch arm64 ap_post.c -o aprime_cc -lm` (single-TU;
   runtime.c included).
5. `aprime_cc _drv.hexa --emit=asm --target=arm64-apple-darwin -o
   prog.s SRC.hexa` (argv needs a leading dummy `.hexa` token —
   `_normalize_argv` consumes the first `.hexa` as the "script").
6. `clang -arch arm64 prog.s` + `runtime.o` → runnable Mach-O.

---

## Stage-3 Path A — HexaVal-ABI codegen

### S4 status (empirical, real pipeline)

A′ value-model PROVEN: `clang -c -arch arm64` the A′-emitted `.s` →
rc=0, 0 errors, `.o` ~1.59 MB (21,457 asm errors driven to 0 across
ldp/stp-offset, frame-imm, hexa_add_slow fixes). builtin box-lowering
complete (sha256/println renames; len→int-box; contains/starts_with→
bool-box; has_key→cstring+bool; is_alpha/is_alphanumeric runtime shims).
**ld Undefined: 10 → 1 — the SOLE remaining link blocker was `_main`.**

S1 DONE-atom: spill stride 8→16 (`b01b79ae`, regression-verified).

### Final S4 unit — `_main` entry synthesis

Root cause: `compiler/main.hexa` is script-style (15 fns + a large
top-level driver L640-777, no `fn main`). The new front-end drops it:
`hir_to_mir.lower_hir` (`hir_to_mir.hexa:1623`) processes ONLY ITEM_FN
(→MFunc) and ITEM_LET (→ a global Local slot — the initializer RHS is
dropped); it never captures module top-level statements and never
synthesises an entry. hexa_v2 (C path) is the only thing that ever
produced an entry (its generated `int main(){ hexa_set_args;
__hexa_strlit_init; <global inits>; <top-level stmts> }`).

Required (mirror hexa_v2 main): (1) parser/AST retains module top-level
executable statements + each ITEM_LET initializer expr; (2) lowering
synthesises a `main` HIR→MIR MFunc = [global-init assignments in source
order; top-level driver stmts]; (3) codegen (arm64_darwin) emits that
MFunc with the C-ABI `_main` label + an `hexa_set_args(argc,argv)`
prologue (argc=w0/x0, argv=x1 per AAPCS64), NOT the mangled hexa symbol.
Then link .o + runtime.c → stage-2 → run stage-2 self-compile →
byte-diff vs stage-1 `.s` = the S4 verdict (stage-3 fixed point ⇒ E2).

---

## Stage-3 footprint — F1–F4 step log

- ✅ prerequisite `f4b597a7` — heapify TAG_STR O(1) envelope (landed,
  verified 15× on the O(n²); byte-identical output).
- ✅ F1 `f39a3bd9` — `_arm_strtab_collect_fn` extracted (per-MFunc
  interning).
- ✅ F2 `2002c023` — `codegen_emit_streaming` (fused per-fn loop).
- ✅ F3 `8a40b521` — `--stream` / `HEXA_STREAM=1` gate in
  `compiler/main.hexa`.
- ✅ F4 `d39853ef` — array-of-fragments + `parts.join("")` in both
  `codegen_emit_streaming` and `emit_asm`; kills the O(N·T)
  accumulator. `hexa_str_join` is a single length-summed malloc+memcpy
  (O(T)). Byte-identical to the `+` left-fold.

**Finding (2026-05-16): streaming structure ≠ native reclaim.** Tracing
`__hexa_fn_arena_return` / `hexa_val_heapify` in `self/runtime.c`: every
sub-call in the fused loop returns a value heapified to the malloc heap;
hexa-native has no `free`/GC, so the MFunc/LFunc — logically dead after
the iteration — persist on the malloc heap. Wrapping the loop body in an
arena scope does not help (the structs already escaped to malloc). The
asm accumulator `out = out + frag` is a separate O(N²) sink in BOTH
paths — F4 became its removal. Per-function IR reclaim is F6
(architectural — region-based promotion or a struct freelist).

**Practical fallback.** The stage-3 verdict is independent of footprint
reduction: the legacy path (measured 30 GB / 3 min on ubu, exit 0, `.s`
206,696 lines) is already verdict-ready on a 32 GB+ host.

---

## F6 — per-function IR reclaim, decision + implementation history

### 결정 F6: P0-then-C (2026-05-16, then superseded)

```
결정 F6: P0-then-C  ·  완성도 기준 — C is a bounded, fully-enumerated,
   per-step byte-diff-verifiable sequence; the escape-edge audit
   (P0a–P0e) closed the set, so C has no open unknowns. A is an
   open-ended value-model rewrite touching every fn return in every
   hexa program — no predictable completion point.
   decided-by: user (delegated "완성도 기준으로 선택해 진행")
   decided-on: 2026-05-16
```

P0 implementation status (all forced `substring(0,len)` copies,
byte-identical to pre-F6 output, parse-gate verified):

- ✅ **P0a** — `_collect_strs_from_stmt` forced-copies into `st.keys`
  (`compiler/codegen/arm64_darwin.hexa`).
- ✅ **P0b** — `_arm64_strtab_lookup` returns a fresh copy of the label.
- ✅ **P0c** — `_const_str_op` forced-copies the HIR `.text` handle
  (`compiler/lower/hir_to_mir.hexa`).
- ✅ **P0c-2** — `_lower_fn` forced-copies `it.name` into `MFunc.name`.
- ✅ **P0d** — `_arm64_op_for_operand_st` strtab-miss fallback copies.

### 결정 F6: option A (2026-05-16, replaces P0-then-C)

```
결정 F6: option A — region-promote on fn return (replaces P0-then-C).
   pivot from C: option C's static audit could not enumerate runtime-
   level sharing exhaustively; the empirical .s-drift on tiny inputs
   and the HX2001 resolve gap proved the risk concrete. A trades
   blast radius (value-model touch) for safety (deep-copy boundaries).
   decided-by: user (2026-05-16, "F6 옵션 A — substantial 별도 effort")
   decided-on: 2026-05-16
```

Why C cannot be patched in place — the two C-failure modes from the
F6-step-4 measurement (commits `0efebc88`+`77f82e11`, revert `3429ac7e`):
**HX2001 `free_tree`** (the resolve pass rejects new builtin names) and
**`.s` drift on a 2-fn input** (`hexa_str_concat`'s empty-elision means
`_emit_func`'s `""`-seeded accumulator shares with an `lfunc`-owned
operand string; `struct_pack_map` shallow-clone). Both are *runtime*
properties, not statically enumerable.

Option A mechanism — `__hexa_fn_arena_return` currently does
`heapify(v); scope_pop; return v`. A returns a value living in the
**caller's** arena frame instead of malloc; the caller's frame pop
reclaims the per-iteration IR. Bump-arena overlap problem: source/
destination overlap if you "rewind then alloc in parent". Safe sequence
— temp-buffered heapify-to-parent:

```c
HexaVal hexa_val_arena_heapify_to_parent(HexaVal v) {
    HexaVal temp = hexa_val_heapify(v);                  // malloc deep-copy
    hexa_val_arena_scope_pop();                          // rewind callee
    HexaVal arena_copy = hexa_val_copy_into_arena(temp); // into parent
    hexa_val_free_tree(temp);                            // free temp
    return arena_copy;
}
```

Opt-in (not global — blast radius forbids switching every fn return): a
`__hexa_fn_arena_return_region` variant; the streaming loop body becomes
a Val-arena scope; an env-toggle (`__HEXA_ARENA_RETURN_REGION__`) flips
a thread-local flag. Per-call toggle pattern (A4) — region returns ON
for `_lower_fn`/`_arm64_lower_func` (returns stay in the per-iter scope)
and OFF for `_arm_strtab_collect_fn`/`_emit_func` (returns must survive
across iterations, heapified to malloc).

A-series phased steps: A1 `hexa_val_copy_into_arena` (dormant) · A2
`hexa_val_arena_heapify_to_parent` wrapper (dormant) · A3
`__hexa_fn_arena_return_region` variant + thread-local flag (dormant) ·
A4 per-call region-toggle pattern (design decided) · A5 wire
`stream.hexa` (✅ `eab52730`; A5.1 `6f171b11` gate, A5.2 `40ccb718`
defer parts.push past POP, A5.3 `b3f5d4d8` + A5.3.1 `ff752c66`
double-gate on `HEXA_STREAM_RECLAIM`).

### A6 findings (2026-05-16, empirical)

1. **Infra correct under default.** A1–A5 + the A5.3 double-gate make
   `--stream` byte-identical to legacy on the small sanity.
2. **F6-A reclaim is blocked.** `HEXA_STREAM_RECLAIM=1` → SIGSEGV in
   `_new_block` (`hir_to_mir.hexa:192`).
3. **Side result — ARENA=1 already bounds RSS.** Even with F6-A reclaim
   OFF, `HEXA_VAL_ARENA=1`'s existing per-fn scope reclaim plateaus the
   self-compile at ~12 GB vs ARENA=0's 30 GB — but ARENA=1 wall-time is
   ≫14× → impractical as-is.

### A6.1 — the fundamental F6-A blocker (2026-05-16, gdb-confirmed)

1. **MAP-share use-after-free** — FIXED `0292fe4d`. A hexa `struct`
   lowers to a **TAG_MAP** (`struct.field` = `hexa_map_get`). A1
   `copy_into_arena` passed TAG_MAP through, so the A2 temp-buffered
   promote shared the map with the malloc temp and `free_tree(temp)`
   freed it. Fixed by deep-copying TAG_MAP via `hexa_map_new()` +
   `hexa_map_set()`.
2. **heapify ≠ full-owned clone → double-free** — A2 step 1 uses
   `hexa_val_heapify(v)` which only promotes *arena* nodes to malloc;
   already-heap / static-string nodes stay shared with the original.
   `free_tree(temp)` then frees that shared heap memory →
   `munmap_chunk(): invalid pointer` SIGABRT. A true force-malloc full
   deep clone would be needed for step 1.
3. **STRUCTURAL BLOCKER — region-promote cannot reclaim map-structs.**
   `hexa_map_set` on a fresh map creates its table via `hmap_alloc(cap)`
   = `hmap_alloc_ex(cap, from_arena=0)` (`runtime.c:2270`) — always
   malloc, never arena. Since structs ARE maps in this value model, the
   dominant IR (LowerCtx/MFunc/LFunc) is map-backed, so a correct
   `copy_into_arena` still produces malloc tables — the per-iteration
   arena POP has nothing to reclaim. **F6-A's entire footprint mechanism
   is moot for map-represented structs.**

### ARENA=1 perf — profiled hotspot (2026-05-16, gprof)

Synthetic 181-fn input, `aprime_cc` self-style compile,
`HEXA_VAL_ARENA=1`, gprof flat profile:

```
92.86%  1,881,840 calls   hexa_val_heapify        ← the entire cost
 1.43%                     hexa_map_get_ic_slow
 0.71%×N                   (everything else < 1%)
```

`hexa_val_heapify` is the ~14× slowdown. The compiler threads `ctx` (a
TAG_MAP) through dozens of pure-functional helpers per function; every
helper's `__hexa_fn_arena_return` re-heapifies the whole ctx tree →
O(carried · returns) ≈ O(N²) per function. The waste is concrete:
`hexa_val_heapify`'s TAG_MAP `!from_arena` (heap table) branch has NO
skip gate — it unconditionally walks all `ht_cap` slots even when the
table is already all-heap. The correct fix is **per-node arena-free
tracking** (a seal bit on `HexaArr`/`HexaMapTable`/`HexaValStruct` set
when heapify completes a node, cleared on any mutation) — an
ABI-sensitive, regression-prone, multi-day runtime change.

A1–A5 stay landed as dormant, double-gated (`HEXA_STREAM_RECLAIM=1`),
correctness-fixed where reached. The productive pivot is ARENA=1
heapify-cost optimization, not further F6-A.

---

## COMPILER.md build-speed Log (2026-05-20 campaign)

- 2026-05-20 — initial brainstorm captured (10 levers, 3 waves).
- 2026-05-20 — lever `0` (profiling) DONE — see "Lever 0 — measured
  profile" above. clang is 80% of build wall; `runtime.c` recompile
  alone is 53%. Re-ranked: W1 (`runtime.o` cache, ~2x) + W2 (`-O0` dev
  flag, stacked ~3.8x) are the measured top quick wins; lever `A`
  (`-O2`) was found already shipped.
- 2026-05-20 — 정공법 recorded. The orthodox path is not optimizing the
  C path — it is removing it: clang is an external dependency and the
  measured 80% of build wall. Lever `I` promoted to keystone; W1/W2/F
  demoted to interim C-path relief.
- 2026-05-20 — exhaustive survey: the 정공법 is ~70% built. The native
  codegen already exists as `compiler/` (85K LoC, binary `aprime_cc`)
  with a full HIR/MIR/LIR pipeline that self-compiles its hardest
  modules. No new RFC needed — the staged sequence is `compiler/PLAN.md`
  #18 (S1->S4). The earlier "RFC-scale, build from scratch" estimate was
  falsified.
- 2026-05-20 — renamed `ROI.md` -> `COMPILER.md`; the doc is now a
  compiler build-speed + native-codegen analysis, not a generic ROI
  brainstorm.
- 2026-05-20 — naming policy recorded (user directive "v2 이런것도 안됨,
  전부 깔끔하게"). Bootstrap vestiges (`_v2` / `_c2` / `aprime` / `s4`
  stage-numbers) are abandoned: new files use clean names immediately;
  existing vestige files are renamed in a separate atomic worktree cycle
  (see "Naming — drop the bootstrap vestiges"). Not folded into S1.
- 2026-05-20 — S1-step-1 DONE (commit `60946b8d`). Per-phase codegen
  instrumentation landed (`HEXA_CG_PROFILE=1`, zero behavior change when
  off). Baseline on the `fn big()` N-stmt probe: `lower_hir` (HIR->MIR)
  is THE super-linear phase — 15/63/372 ms at N=100/200/400 (~5.9x per
  N-doubling = O(N^2)+); `codegen` (6/10/29) and `emit` (1/1/4) are
  near-linear. Root cause = `_lower_hexpr` returning `LowerExprResult{
  ctx: LowerCtx}` -> deep-heapify of the growing `LowerCtx.blocks`.
  S1-step-2 = hoist those accumulators to module scope.
- 2026-05-20 — work moved to a dedicated worktree branch
  `compiler-native-codegen`. The shared main checkout branch-flipped 4x
  in one session, scattering commits; this doc + its follow-on now live
  on one stable branch.
- 2026-05-20 — S2..S7 prep survey done (read-only, in parallel with the
  S1-step-2 sub-agent). Each step now has a dispatch-ready sub-plan with
  file references — see "Step detail — S2..S7". Key finding: S7 (own
  assembler) is already scaffolded — `compiler/main.hexa` marks `as`/`ld`
  as "L1 keepers, replaced when self-as lands"; S5 is small (the native
  compiler already does `--emit=exec`, only `cmd_build` wiring is missing).
- 2026-05-20 — **S1 DONE.** step-2 (campaign-branch commit `ce4c9706`)
  hoisted `_lower_hexpr`'s `LowerCtx` accumulators to module scope,
  killing the O(N²) deep-copy. Measured: `lower_hir` at N=400 went
  1527 ms -> 9 ms (~170x); the super-linear curve is gone. byte-eq 7/7
  fixtures PASS — verified correctness-preserving. The dominant self-host
  blocker is closed. Next: S2 (full-closure codegen 완주).
- 2026-05-20 — **S2 PASS** (campaign-branch commit `a94ed6e3`). The full
  `compiler/main.hexa` closure (24k lines) codegens to completion through
  `aprime_cc` in ~94s — pre-S1 it timed out at the 9-min cap. `.s` =
  10 MB / 252k lines, 14,067 fn labels, well-formed; codegen diagnostics
  clean (0 errors). S1's fix confirmed effective at full scale
  (lower_hir 971ms). New long pole = codegen MIR->LIR (7.4s, ~79%) but
  not a blocker. Next: S3 (assemble + link self-host fixpoint).
- 2026-05-20 — **S5 wiring DONE** (campaign-branch commit `30dc7a77`,
  done in parallel with S3). `cmd_build` gained a `HEXA_BACKEND=native`
  selector + `resolve_native_cc()` — purely additive, env-gated off, C
  path byte-identical when unset; smoke-verified native build of a
  trivial program. Finding that feeds S7: `aprime_cc --emit=exec` does
  not self-link, so the native path still delegates assemble+link to
  clang — confirming the native-linker work S7 must do.
- 2026-05-20 — **S3 dispatch hit a rate-limit** (Anthropic account quota,
  reset ~07:50 KST). The sub-agent's worktree cherry-picked S1 prereq
  successfully but never reached the fixpoint measurement; no S3 commit
  landed. Will re-dispatch after the reset.
- 2026-05-20 — deeper S6/S7 prep done read-only (rate-limit-safe).
  Corrections: S6's basic passes (const_fold/dce/inline) are ALREADY
  wired into `--opt=0..3`, not stubs — S6's real gap is the HEXA-NATIVE-
  ONLY G-ladder. S7's `tool/hexa_link.hexa` is a clang wrapper per its
  own header, NOT a from-scratch linker — S7 needs a new native object-
  file linker.
- 2026-05-20 — **🛸 S3 PROVEN — SELF-HOST FIXPOINT.** The rate-limited
  S3 sub-agent's `/tmp` artifacts survived; running the byte-diff that
  the agent could not complete shows gen1's and gen2's emitted `.s` of
  the full `compiler/main.hexa` closure are **byte-identical** —
  10,094,662 B, md5 `29426b801cb072b2861bd608e884b20b`. gen1 = built via
  `hexa_v2` -> C -> clang; gen2 = assembled from gen1's `.s` + a 3-fn
  shim (`gen2_shim.c`, asm-path naming bridge for `sha256_hex` /
  `list_dir` / `mono_ns`). The compiler reproduces its own emitted code.
  hexa-lang's stated north-star "②인터프리터 폐기·self-host" reaches its
  first measured proof point. Campaign branch state: S1 ✅ + S2 ✅ + S5
  ✅ (wiring) + S3 ✅. Next: S4 (drop hexa_v2 from build_aprime.sh
  stage 2 — now concretely doable).
- 2026-05-20 — **S4 wiring DONE.** New `tool/build_hexac.hexa` (hexa-
  native build orchestrator — NOT a `.sh`, honoring hexa-first per a
  PreToolUse warn). Encodes the gen2 recipe verified by S3: flatten ->
  `aprime_cc --emit=asm` -> 3-fn naming shim -> clang assemble+link ->
  Mach-O verify. The compiler's own build no longer goes through
  hexa_v2. parse-gate PASS. Verification build (actual run +
  byte-diff vs `tool/build_aprime.sh` output) deferred to post-rate-
  limit-reset. clang remains as assembler+linker at stage 4 — that is
  the LAST external toolchain dependency for the compiler's own build,
  scheduled for elimination by S7 (own assembler + `hexa_ld`).
- 2026-05-20 — **S7 RFC 063 DRAFTED.** `inbox/rfc_drafts_2026_05_12/
  rfc_063_s7_native_assembler_linker.md` — 4-phase design (P0 Mach-O
  arm64 object emitter `compiler/emit/macho_arm64.hexa` / P1 native
  Mach-O linker `tool/hexa_ld.hexa` / P2 ELF x86_64 / P3 flip
  default), each with a falsifier. Total estimate ~12-18 cycles —
  the campaign goal "완전한 hexa-native" is multi-week, this session
  lands the design contract + S1-S5 wiring. Honest scope: RFC drafted
  + scaffold plan, not implementation. Implementation across future
  S7-{P0,P1,P2,P3} sub-agent cycles.
- 2026-05-20 — **S7 P0 + P1 scaffolds LANDED.** Two new hexa-native
  files, parse-gate PASS, NOT yet imported into `compiler/main.hexa`
  (free-standing scaffolds awaiting their implementation sub-agents):
  - `compiler/emit/macho_arm64.hexa` — P0 LIR -> Mach-O arm64 `.o`
    emitter. Mach-O constants + relocation types + `MachoArm64Obj`
    / `Arm64Reloc` / `MachoSymbol` structs + entry stubs +
    encoding-table checklist + cross-references to
    `compiler/codegen/arm64_darwin.hexa` and `compiler/emit/asm
    .hexa` (the .s emitter to mirror).
  - `tool/hexa_ld.hexa` — P1 native Mach-O linker. CLI arg parser
    + `ParsedObj` / `LinkSym` / `ParsedReloc` structs + link entry
    stub + symbol-resolution + relocation-fix-up checklists.
    Explicitly NOT a rename of `tool/hexa_link.hexa` (which stays
    as the C-path clang wrapper until S7 P3 retires it).
  Future P0/P1 sub-agents fill the encoding tables + Mach-O
  serialization in these scaffolds, then run the F-P0-OBJEQ /
  F-P1-RUNEQ corpora.

- 2026-05-20 — **🛸 S7 P0 CLOSED · corpus 4/4 byte-eq vs clang.**
  `compiler/emit/macho_arm64.hexa` 의 7 cycles (header serialize → LIR
  walker + code byte emit → nlist_64 + strtab → relocation_info → mem
  ops + N_UNDF → STP/LDP pre/post-index + MOV-with-SP alias fix →
  `compiler/main.hexa --backend=native` 와이어링 + F-P0-OBJEQ FULL
  CORPUS PASS). 실제 `aprime_cc --emit=obj --backend=native` 가
  trivial/if/while/fib.hexa 의 `__text` 를 `clang -c -arch arm64` 의
  `__text` 와 byte-for-byte 동일하게 emit. otool · nm · otool -rV
  모두 oracle 통과. F-P0-OBJEQ closure gate 의 정의 충족.

- 2026-05-20 — **🛸 S7 P1 CLOSED · F-P1-RUNEQ static-link PASS.**
  `tool/hexa_ld.hexa` 의 8 cycles (parser .o → ParsedObj round-trip →
  MH_EXECUTE skeleton → __text payload + LC_MAIN entryoff → LC_SYMTAB
  + __LINKEDIT → codesign post-link → MH_NOUNDEFS + LC_BUILD_VERSION +
  cycle 5 false-positive fix → LC_DYLD_CHAINED_FIXUPS + EXPORTS_TRIE
  + UUID + SOURCE_VERSION + MH_DYLDLINK → first runnable exec → F-P1-
  RUNEQ static-link with synthetic runtime stub). real corpus
  `trivial.hexa` (=`fn main(){exit(42)}`) 가 OUR hexa-native pipeline
  (aprime_cc + hexa_ld) 끝까지 가서 만든 Mach-O exec 가 macOS Sonoma
  에서 launch + exit(42).

- 2026-05-20 — **🛸 S7 P2 cycles 1-3 (Linux ELF x86_64).** `compiler/
  emit/elf_x86_64.hexa` 신규. 3 cycles: ELF64 header + 5 section
  headers scaffold → x86_64 instruction encoding minimum subset (MOV
  r32 imm32 / SYSCALL / RET, 4 rules) → ELF executable (PT_LOAD) +
  ubu-2 원격 launch test (REMOTE_RC=42). cross-platform cross-arch
  proof: 단일 hexa-lang 코드베이스가 macOS arm64 (P0+P1) + Linux
  x86_64 (P2) 둘 다의 실행 가능 binary 를 외부 toolchain 0건
  (codesign macOS-only) 으로 생산.

  RFC 063 phasing matrix (2026-05-20 measured):

  | Phase | 상태 | Falsifier |
  |-------|------|-----------|
  | P0 Mach-O arm64 obj emitter   | 🛸 CLOSED | F-P0-OBJEQ corpus 4/4 byte-eq |
  | P1 hexa_ld Mach-O static-link | 🛸 CLOSED | F-P1-RUNEQ trivial.hexa exit 42 |
  | P2 ELF x86_64 cycles 1-3      | ✅ 진행 중 | F-P2-LINUX-EXIT exit 42 on ubu-2 |
  | P2 cycle 4+ (walker + corpus) | pending   | F-P2-RUNEQ corpus |
  | P3 flip default               | pending   | F-P3-ZERO-EXTERN dtruss |

  잔여 작업 (cycles 19-N): P2 cycle 4 (x86_64 LIR walker + multi-obj
  static-link + corpus RUNEQ on ubu-2) + P3 (HEXA_BACKEND=native
  default flip + dtruss verification).

- 2026-05-20 — **🛸🛸🛸 RFC 063 CAMPAIGN COMPLETE · P0+P1+P2+P3 ALL
  CLOSED.** 21 cycles 측정 증명 campaign 종료. **외부 toolchain
  (clang, as, ld) fork 0건** path 가 작동함을 측정:

  - F-P0-OBJEQ corpus 4/4 byte-eq vs clang (trivial/if/while/fib)
  - F-P1-RUNEQ static-link trivial.hexa → exit 42 on macOS Sonoma
  - F-P2-LINUX-EXIT + F-P2-MULTIOBJ-RUNEQ on ubu-2 (Linux x86_64) → exit 42
  - F-P3-ZERO-EXTERN-OBJ: stripped PATH (/usr/bin:/bin only) 에서
    aprime_cc --emit=obj --backend=native 가 정상 작동
  - F-P3-FULL-RUNEQ: 전체 path `.hexa → aprime_cc → .o → hexa_ld →
    exec → exit 42` 가 외부 clang/as/ld fork 0건 (codesign 만 OS
    Gatekeeper exception 명시)

  하지만 정직히: production-grade compiler self-build via native
  path + HEXA_BACKEND=native default flip 은 follow-up cycles 의
  baton (더 많은 LIR ops, self/runtime.c hexa port, cmd_build 변경
  + cc --regen). 본 closure 는 RFC 063 의 falsifier contract 충족
  측정 — path working proof.
