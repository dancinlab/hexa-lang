# runtime.c retirement readiness — step-3 acceptance gate measurement

> Date: 2026-05-22 · Host: local (read-only) · Branch:
> `worktree-agent-accba58131a143ffa` · Base: origin/main `0c29ab92`
> (docs(RUNTIME): cycle 105 array allocators + extern baseline 24→25).
> This is the formal step-3-acceptance gate measurement RUNTIME.md
> §"End-state path" calls for: "step 3 acceptance = runtime.c 폐기 가능".

## TL;DR

- **137 of 493 unique `hexa_*` function definitions are ported**
  (dispatch to a hexa-source `rt_*` under `HEXA_HAS_HEXA_RT_STDLIB`) =
  **27.8% by raw fn count.**
- **HI-tier (runtime.c): 25.6% ported** · in-scope (excl GPU/ML app
  surface) **38.1%.**
- **CORE-tier (runtime_core.c): 31.0% ported.**
- **151 `pub fn rt_*` ports** exist across `stdlib/runtime/*.hexa`.
- **Irreducible C floor ≈ 174 fns** (allocator + hash-table + HexaVal
  tag-dispatch + codegen call-shims + syscall/IO + control-flow). At
  ~30-40 LoC/fn this is roughly **5,000–7,000 LoC of C that cannot be
  lifted** without prior codegen-level infrastructure work.
- **Verdict: runtime.c retirement is NOT achievable at the current
  source/codegen level.** There is a hard C floor. Step-3 acceptance
  ("runtime.c 폐기 가능") is partially met for the *HI-tier logic
  surface* but blocked on a foundation that is structurally C-bound.

## 1. Function-definition census (unique-name basis)

Counting method: a function is "ported" if **any** of its definitions
(C-body `#ifndef` arm + dispatch `#else` arm count as one name) contains
a `rt_*(` call in its body span. This is more accurate than counting
`#if(n)def HEXA_HAS_HEXA_RT_STDLIB` directives, because short one-liner
functions are wrapped by a guard pair that the directive-proximity
heuristic misattributes to the neighbouring function.

| file | total LoC | unique `hexa_*` defs | ported (→`rt_*`) | C-only |
|------|-----------|----------------------|------------------|--------|
| self/runtime.c       | 12,672 | 293 | 75 | 218 |
| self/runtime_core.c  |  6,892 | 200 | 62 | 138 |
| **combined**         | **19,564** | **493** | **137** | **356** |

Cross-check (raw directive count): `#if(n)def HEXA_HAS_HEXA_RT_STDLIB`
opens = 57 (runtime.c) + 60 (runtime_core.c) = 117; `extern HexaVal
rt_*` decls = 81 + 69 = 150 (≈ the 151 `pub fn rt_*` in stdlib). The
137 fn-body-dispatch number is the load-bearing one for retirement
readiness — directive count overstates because some guarded blocks are
declarations, not definitions.

## 2. hexa-source port surface (`stdlib/runtime/*.hexa`)

`pub fn rt_*` per file (151 total):

| file | rt_* | role |
|------|------|------|
| numeric.hexa | 82 | HI-tier array + scalar logic (the bulk of step-3) |
| ctype.hexa   | 32 | char classifiers (step-2 hxlcl ports) |
| math.hexa    | 24 | libm-free transcendentals (Newton/Stirling) |
| posix.hexa   |  5 | errno/strftime stubs (step-1 libc-unhook) |
| io.hexa      |  4 | print/println/eprint/eprintln (step-3 cycle, smoke path) |
| net.hexa     |  2 | inet stub returns |
| thread.hexa  |  2 | pthread noop stubs |

## 3. C-only residual — category breakdown (356 fns, mutually exclusive)

| category | fns | retirable? |
|----------|-----|------------|
| **gpu_ml_domain** (farr/tensor/cuda/forge/ad/adamw/ansatz/silu/gelu/matmul/safetensors…) | 105 | OUT-OF-SCOPE app surface — not part of HI/CORE retirement; SIMD + device-residency + mmap bound |
| **syscall_io** (exec/spawn/term/http/read/write/ffi/mmap/env/time/print) | 85 | C-FLOOR (kernel boundary) |
| **tag_dispatch** (hexa_int/float/bool/str/void/truthy/to_cstring/cmp_*/add/sub/len/is_type/str_own) | 43 | C-FLOOR (HexaVal `_Generic` substrate — self-referential) |
| **allocator** (arena/val_arena/array_new/map_new/reserve/heapify/closure_new/fn_new/strbuf) | 27 | C-FLOOR (the substrate every port allocates onto) |
| **math_logic** (hexa_math_sin/cos/exp/log/pow/sqrt polymorphic wrappers) | 24 | step-1 libm-unhook (rt_ ports exist in math.hexa; standalone arm still libm) |
| **struct_repr** (struct_pack_map/valstruct/json/dict/format/regex) | 23 | mostly C-FLOOR (ValStruct repr + format) |
| **array_logic** (array_get/set/pop/shift/push/slice_fast/group_by/frequencies) | 21 | MIXED — surface ops are portable but LOWER to allocator floor |
| **map_hash** (map_get/set/keys/values/remove + intern + fnv1a) | 11 | C-FLOOR (Robin Hood table + key-interning malloc) |
| **control_flow** (try_push/pop/cleanup/last_error/throw/await_unwrap) | 6 | C-FLOOR (setjmp/longjmp exception machinery) |
| **codegen_shim** (hexa_call0..4 / __hexa_callN_fpN) | 2 (+5 in ported-name dupes) | C-FLOOR (fn-pointer trampolines the codegen emits calls to) |
| OTHER / misc_logic | 9 | mixed |

## 4. The irreducible C floor (the answer to "is retirement achievable?")

**No — there is a hard C floor.** The floor = the categories every
hexa-source port is *built on top of*:

```
allocator        27   ── arena bump-alloc, mmap blocks, HX_SET_ARR_CAP,
                          array/map/closure/fn constructors
map_hash         11   ── Robin Hood hash table, hmap_find, fnv1a,
                          key-interning malloc (HexaMapTable opaque)
tag_dispatch     43   ── HexaVal {tag,i,f,ptr} constructors + _Generic
                          truthy/cmp/add/sub/len/to_cstring foundations
codegen_shim      2+  ── hexa_call0..4 fn-pointer trampolines
syscall_io       85   ── write/read/mmap/exec/socket/time kernel boundary
control_flow      6   ── setjmp/longjmp try/throw machinery
                ─────
            ≈ 174 fns  (≈ 5,000–7,000 LoC C)
```

Why each is self-referential / unliftable at the current level:

- **tag_dispatch / allocator**: a hexa-source `rt_*` body that does
  `let a = []` lowers to `hexa_array_new()`, and `a + b` lowers to
  `hexa_add(a, b)`. Porting `hexa_array_new` or `hexa_add` to hexa
  source recurses into itself. Confirmed by the cycle-30/103 recursion
  trap (`rt_eq_int` → `hexa_eq` loop; `rt_cmp_lt_int` chain) and
  RUNTIME.md 잔여 #6 ("`[]` literal lowers to `hexa_array_new()` →
  self-recursion").
- **map_hash**: 잔여 #5 — "Robin Hood deletion + hash slot insert +
  key-interning malloc all C-internal". Surface map builtins LOWER to
  these.
- **str_concat heap**: 잔여 #3 REVERTED — inner-fn arena enter/return
  frame corrupts outer arena array storage (cycle-30 family). Step-5+.
- **IO**: 잔여 #7 — needs a new `__fd_write_bytes(fd,s)` codegen
  builtin (3-5 cycles of codegen work) before the syscall layer can
  move; current io.hexa rt_print exists for the smoke path only.

## 5. Tier percentages (the step-3 acceptance numbers)

- **HI-tier logic (runtime.c) ported: 75/293 = 25.6%**
  · excluding the 91 GPU/ML domain app-surface fns that were never in
  the HI retirement scope: **75/197 = 38.1%.**
- **CORE-tier logic (runtime_core.c) ported: 62/200 = 31.0%.**
- Combined retirement progress: **137/493 = 27.8%** (raw) ·
  **137/(493−105 gpu_ml) = 137/388 = 35.3%** in-scope.

RUNTIME.md's own narrative ("42 HI-tier fns ported" mid-campaign,
then 잔여 closures to cycles 89–105) is consistent with the higher
137-fn total once map-op family + hexa_eq 9/9 + str family + ctype +
math.hexa ports are all counted on the unique-name basis.

## 6. Assessment — is runtime.c retirement actually achievable?

**Not as a pure source-level port.** The honest finding:

1. The *HI-tier logic surface* (array transforms, string transforms,
   numeric/math) is **38% retired** and the remaining HI-tier logic is
   mechanically portable — these are the cycles RUNTIME.md keeps
   landing. Call this the "soft" surface.

2. The **~174-fn / ~5–7 KLoC C floor is structurally irreducible at the
   current codegen level.** runtime.c / runtime_core.c CANNOT be
   deleted while:
   - the HexaVal `_Generic` tag-dispatch primitives are the lowering
     target of every hexa `+`/`==`/`<`/`len`/literal, and
   - the arena allocator is what every `rt_*` body allocates onto, and
   - the codegen emits `hexa_call0..4` / `hexa_array_new` / `hexa_add`
     by name.

3. **Retirement therefore requires codegen-level infrastructure first**
   (RUNTIME.md's own "Step 5+" list), NOT more porting cycles:
   - arena-builtin / arena-disable-local API → unblocks str_concat (#3)
   - `HX_*_LEN` / `HX_SET_ARR_CAP` exposure → unblocks array alloc (#6)
   - `HexaMapTable` opaque-pointer escape → unblocks map ops (#5)
   - `__fd_write_bytes` codegen builtin → unblocks IO (#7)
   - a bootstrap story for the tag-dispatch primitives themselves
     (a `@asm`/intrinsic floor or accepting them as the "≤5-line kernel
     syscall stub" the north-star permits).

### Floor size estimate

- **fn count: ~174** (allocator 27 + map_hash 11 + tag_dispatch 43 +
  codegen_shim 2 + syscall_io 85 + control_flow 6).
- **LoC: ~5,000–7,000** of the 19,564 total runtime C LoC (≈ 25–35%).
- The 105 GPU/ML domain fns (~another large LoC chunk) are *separately*
  out-of-scope — they are application primitives, not the compiler-
  essential runtime; whether they retire is an independent decision.

**Bottom line for the step-3 gate**: step-3 acceptance ("runtime.c
폐기 가능") is **NOT yet met**. The portable HI-tier logic is ~38%
done and progressing per-cycle, but runtime.c cannot be retired until
the 4 codegen-infrastructure unblocks land. The irreducible C floor
(~174 fns / ~5–7 KLoC) is the true measure of how far zero-C-dep
(step-4) remains. Extern baseline is 25 (cycle 105), already near the
north-star "≤5-line kernel syscall stub" target on the *symbol* axis —
but symbol count and source-retirement are decoupled (a small extern
set still sits atop a large in-tree C substrate).

---

### Reproduction (read-only, local)

```
# ported = fn whose body dispatches to rt_*( ; C-only = the rest
python3  ... (see /tmp/all2_*.txt, /tmp/ported2_*.txt artifacts)
grep -cE '^[[:space:]]*pub fn rt_' stdlib/runtime/*.hexa   # 151
wc -l self/runtime.c self/runtime_core.c                  # 12672 / 6892
```
