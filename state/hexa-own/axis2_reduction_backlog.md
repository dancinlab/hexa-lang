<!-- axis-② runtime.c→0 reduction backlog · census workflow wf_c6aaa3d1 · 2026-07-13 · 67 candidates (34 GO/18 WALL/15 DEFER) -->

# Axis-② `runtime.c → 0` — Prioritized Reduction Backlog

_Perpetual campaign board. Census input = 67 triaged candidates (34 GO / 18 WALL / 15 DEFER). Deployed units excluded: map-query, valop, arr-i64/f64 typed-leaf, format-float. Pending design: `zeros_leaf` (unit #5, spec-ready — NOT in this census, so the units below rank as #6+)._

---

## 1. Top 3 next units

The three unconditional priority-1 constructors — pure template-mirrors of the already-deployed arr-i64/f64 typed-leaf seed, zero ABI wall, single body each.

### ① `hexa_array_new` — priority 1, small
- **Signature:** `HexaVal hexa_array_new(void)`
- **Why easy:** zero-arg → pair-clean by definition; HexaVal return rides `{tag,payload}`; body is a `calloc` libc-floor mint. No float / char* / varargs anywhere.
- **Mirror template:** **arr-i64/f64 typed-leaf** (`HEXA_RT_CORE_ARRAY_I64_LEAF_NATIVE`) — same `calloc → __hx_ptr_store(header) → __hx_make_val/__hx_tag(ARR)` shape. `HX_MAKE_TAG`/`HX_SET_ARR_PTR` macros re-expressed via `__hx` intrinsics; `_hx_stats_array_new` counter **externed or dropped** under the guard.
- **Pre-flip grep:** `grep -n 'hexa_array_new' <emitter>` — confirm exactly one body (:2734) + the prototype (:1122); the prototype line must stay, the body goes behind the extern arm.

### ② `hexa_arr_{i64,f64,f32}_new_esc` — priority 1, small (batch of 3)
- **Signature:** `HexaVal hexa_arr_i64_new_esc(int cap)` (+ `_f64_`, `_f32_` twins)
- **Why easy:** `int cap` rides a GP reg, HexaVal return is pair-clean; each body is a `malloc` + tag-set direct clone of the deployed typed-leaf. Only edit vs the deployed leaf is swapping the `fprintf`-OOM for the `write`/`exit` externs the deployed leaves already use.
- **Mirror template:** **arr-i64/f64 typed-leaf** verbatim — `malloc` extern + `__hx_make_val/__hx_tag` + arr-ptr `__hx_ptr_store` + `write`/`exit`. Batch all three (incl. f64 mirror @L2903) **under one guard**.
- **Pre-flip grep:** `grep -nE 'hexa_arr_(i64|f64|f32)_new_esc' <emitter>` — verify one unconditional def per type (no `#ifndef` twin); the `_esc` variants are the escape-analysis mint, distinct from the deployed non-esc leaves — confirm no name overlap with the shipped guard.

### ③ `hexa_map_new` — priority 2, small (highest-value non-p1 constructor)
- **Signature:** `HexaVal hexa_map_new(void)`
- **Why easy:** zero-arg pair-clean, `calloc` libc-floor, sole unconditional def; the map sibling of ①. Opens the **map-core constructor** front without touching the char*-keyed dispatch WALLs.
- **Mirror template:** **map-query** (`HEXA_RT_CORE_MAP_QUERY_*`) for the HexaMap-ptr tag/store idiom + arr-leaf for the `calloc` mint. `sizeof(HexaMap)` baked as a constant; stats bump optional/droppable.
- **Pre-flip grep:** `grep -n 'hexa_map_new' <emitter>` — confirm sole def; then `grep -n 'HexaMap ' <emitter>` to lock the `sizeof(HexaMap)` constant against the struct layout before baking it.

> **Honorable mentions (p2, but hot-path value > their priority number):** `hexa_valstruct_new_v` — dominant fib-RSS Val constructor; `__hexa_fn_arena_return` — ~23% self-host user-time. Both pair-clean/small; pull them into the next wave right after the p1 trio.

---

## 2. GO backlog (ranked)

34 GO units. Sorted by priority, then effort.

| Pri | Name | Effort | New leaves | One-line |
|----|------|--------|-----------|----------|
| 1 | `hexa_array_new` | small | none | calloc HexaVal mint, arr-leaf mirror |
| 1 | `hexa_arr_i64_new_esc` | small | none | malloc typed-leaf clone (esc mint) |
| 1 | `hexa_arr_{i64,f64,f32}_new_esc` | small | none | 3-type esc mint batch under one guard |
| 2 | `hexa_map_new` | small | none | zero-arg map ctor, map-query mirror |
| 2 | `hexa_valstruct_new_v` | small | none | 12×HexaVal Val ctor, **hot path** |
| 2 | `__hexa_fn_arena_return` | small | none | arena-return, **~23% self-host time** |
| 2 | `hexa_as_num` | small | 1 internal fp→i64 convert | HexaVal→i64, strtoll extern |
| 2 | `hexa_arr_poly_len` | small | none | tag-branch len@8 reader → hexa_len |
| 2 | `hexa_arr_poly_push` | small | none | tag-dispatch to deployed push leaves |
| 2 | `hexa_array_shallow_clone` | small | none | calloc/memcpy clone, arr-leaf mirror |
| 2 | `hexa_val_snapshot_array` | small | none | extern promote_to_heap + header accessors |
| 2 | `hexa_array_push_nostat` | small | none | realloc push, externs 3 runtime helpers |
| 2 | `hexa_str_concat` | small | none | strlen/memcpy join, stats via extern |
| 2 | `hexa_str_substring` | small | none | clamp+copy, strbuf_alloc extern |
| 2 | `hexa_str_char_count` | small | none | UTF-8 lead-byte walk |
| 2 | `hexa_str_char_substring` | small | inline utf8_cp_len (arith) | UTF-8 cp-range copy |
| 2 | `hexa_array_reverse` | small | none | in-place reverse, float fast-path externed |
| 2 | `hexa_pad_right` | small | none | malloc/memset pad, all helpers exist |
| 2 | `hexa_str_count_substr` | small | none | strstr count, char* internal-only |
| 3 | `hexa_arr_poly_get` | small | f32→f64 widen (cvtss2sd) | tag-dispatch get, F32 arm needs widen |
| 3 | `hexa_str_nth_char` | small | str-construct leaf | UTF-8 walk → 1-cp string |
| 3 | `rt_path_exists` | small | none (+256B scratch) | stat rc==0 check, char* internal |
| 3 | `hexa_str_split` | small | strstr byte-scan | guarded #ifndef/#else, no collision |
| 3 | `hexa_str_replace` | small | none | malloc/realloc/strstr, guarded arms |
| 3 | `hexa_args` | small | none | argv global load + hexa_str per elem |
| 3 | `hexa_array_sort_by` | medium | none | ~40-LOC merge-sort, HexaVal* stride |
| 4 | `hexa_fn_new` | small | none | void*+int ctor; extern `_hx_stats_*` |
| 4 | `hexa_real_args` | small | none | argv walk, low call-freq |
| 4 | `hexa_closure_new` | medium | none | calloc clo; drop/extern `_hx_stats_*` block |
| 4 | `hexa_array_reserve` | medium | none | realloc grow, stats+OOM via raw-mem leaves |
| 5 | `hexa_array_slice_fast` | medium | none | malloc/memcpy slice, arena+stats entangled |
| 5 | `hexa_str_join` | medium | generic HX_ARR/HX_STR ptr+len | 2-arm stdlib entangle (rt_str_join_str) |
| 5 | `rt_file_size` | medium | none (+stat scratch) | struct-stat field decode, per-target byteeq |
| 6 | `rt_file_exists` | medium | stat-field/S_ISREG decode leaf | st_mode mask, per-platform raw decode |

---

## 3. WALL / DEFER

### WALL — blocked by an ABI class (18)

**char\* named wall** (const char* param/return can't ride `{tag,payload}` — same class that kept `contains_key` in C). _Unlock mechanism: a HexaVal-boxed char* C-shim wrapper, OR a codegen char*-param marshalling leaf._

| Name | Pri | Unlock candidate |
|------|-----|------------------|
| `hexa_str` | 9 | char*-arg entry shim |
| `hexa_str_own` | 8 | char*-arg entry shim (algo already externable) |
| `hexa_str_as_ptr` | 8 | char*-**return** leaf (low value) |
| `hexa_is_type` | 8 | char*-shim + strcmp/fnv1a access |
| `hexa_valstruct_get_by_key` | 8 | char*→HexaVal shim (algo exists) |
| `hexa_valstruct_set_by_key` | 9 | char*-shim (blocked regardless of leaves) |
| `hexa_map_get` | 8 | probe already ported; char* dispatcher shell only |
| `hexa_map_set_impl` | 9 | update-half already deployed; insert-half = sanctioned C floor |
| `hexa_map_get_ic_slow` | 9 | char* + HexaIC* struct-ptr leaves |
| `hexa_struct_pack_map` | 9 | pointer-array marshalling + deep map internals (large) |
| `hexa_to_cstring` | 9 | triple wall: char*-return + varargs + float-SSE |
| `__raw_cmp3` | 9 | str-ptr/strcmp leaf + port static `_hexa_enum_pair_idx`; emitter enshrines as permanently-inline |

**float-SSE wall** (double param→xmm0 / double return, not in the hxlcl_* fp-ABI whitelist). _Unlock: a bits-int C-shim, OR an SSE fp-ABI seed path / fp-convert intrinsic set._

| Name | Pri | Unlock candidate |
|------|-----|------------------|
| `__hx_to_double` | 8 | double-return bits-reinterpret shim |
| `hexa_arr_f32_push` | 7 | float-narrow store leaf (double→f32→store32) |
| `hexa_arr_poly_set` | 7 | int→double + double→float convert intrinsics |

**varargs / printf-family wall** (hard). _Unlock: fd_write + i64/float formatting leaves, OR a varargs-call emission leaf._

| Name | Pri | Unlock candidate |
|------|-----|------------------|
| `hexa_print_val` | 9 | varargs printf emission + to_string glue |
| `hexa_eprintln` | 8 | i64→decimal + stderr-fd leaves (float leaf exists) |
| `hexa_format_n` | 9 | snprintf/%.*f varargs + float-fmt + spec scanner |

### DEFER — pair-clean but low-value / entangled (15)

| Name | Pri | Why deferred | Future unlock |
|------|-----|-------------|---------------|
| `hexa_type_of` | 6 | static `_cached_str_*` cache shared w/ to_string | de-staticize refactor first |
| `hexa_array_get` | 6 | 5×snprintf/backtrace on error paths | error-shim or varargs leaf |
| `hexa_closure_env` | 8 | trivial 2-line field-read, in-TU only | port w/ closure-dispatch family |
| `hexa_call1_hv` | 7 | needs indirect-call-through-fnptr leaf | new fnptr-call intrinsic |
| `hexa_array_push` | 7 | large static arena/stats surface to extern | batch w/ arena engine |
| `hexa_throw` | 7 | try-stack globals + longjmp control | cross-module global + longjmp leaf (risky per known try/catch defect) |
| `hexa_eprint_val` | 7 | all-fprintf diagnostic, low value | stderr-write + i64-decimal leaves |
| `hexa_val_copy_into_arena` | 7 | recursive deep-copy, 4 hardcoded struct layouts | batch w/ arena engine |
| `hexa_val_heapify` | 8 | ~350-LOC central arena engine | many struct-field leaves (far future) |
| `hexa_str_graphemes` | 8 | UAX-29 char* machine (NAMED WALL) | char*/utf8-decode leaves |
| `hexa_str_grapheme_count` | 8 | wrapper trivial, walk is char* wall | same as above |
| `hexa_array_sort` | 8 | native merge-sort already inline-default (#4489) | ~zero new reduction |
| `rt_write_file` | 8 | varargs snprintf + FILE* + inline-asm syscalls | raw-syscall + stdio leaves |
| `_hexa_to_string_rec` | 9 | float+snprintf; arms already piecemeal-ported | reconcile w/ rt_to_string_* partial port |
| `hexa_pad_left` | 10 | **already ported** (rt_pad_left #else arm) | nothing to reduce |

---

## 4. Campaign readout

**34 GO units queued** (3× p1 · 16× p2 · 7× p3 · 4× p4 · 3× p5 · 1× p6), **18 walls** (12 char* / 3 float-SSE / 3 varargs), **15 defers**. Next after pending `zeros_leaf` (#5) = **`hexa_array_new`** → batch `hexa_arr_*_new_esc` + `hexa_map_new`.

> **Census-honesty flags** — likely under-counted dense regions the triage did not enumerate:
> - **map-core internals** (hmap_alloc_ex, fnv1a, Robin-Hood find/probe helpers) — only the public char*-keyed API surfaced; internal pair-clean helpers behind the char* shells are uncensused.
> - **stdlib str arm** (`rt_str_*` #else fast-paths like rt_str_join_str) — referenced but not individually triaged; each is a candidate once its `hexa_str_*` wrapper flips.
> - **arena engine** (heapify / copy_into_arena / promote_to_heap family) — treated as monolithic DEFERs; a dedicated pass may split extractable pair-clean sub-helpers.
> - **f32 typed-leaf family** — repeatedly named as "needs fp-narrow/widen leaf"; authoring **one** float-convert leaf set would flip `hexa_arr_f32_push`, `hexa_arr_poly_set`, and unblock the F32 arms of already-GO poly units — a high-leverage leaf investment, not a per-unit wall.