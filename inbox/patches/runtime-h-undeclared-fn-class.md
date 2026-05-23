# runtime.h declaration debt — `defined-but-undeclared` class

**Status:** 🟠 FILED / OPEN (2026-05-23)
**Reporter:** anima session — hexa canonical-deviation audit
**Severity:** high — every entry is a clang hard-error waiting on the
first user program that exercises the feature (ISO C99+ rejects
implicit function declarations).

## The class

Three PRs landed this session fixing **one** instance each of the same
header-declaration-gap pattern:

| PR | runtime fn | feature unblocked |
|---|---|---|
| #348 | `hexa_is_type` | `trait` / `impl` dispatch |
| #350 | `hexa_array_shift` | `.shift()` |
| #356 | `hexa_await_unwrap` | `await <expr>` |

A scripted audit of `runtime_core.c` + `runtime.c` against `runtime.h`
reveals the gap is systemic:

```
defined : 397
declared: 352
gap     : 166   (defined but never forward-declared)
```

Of those 166, **102 are emitted by the codegen** (`self/codegen_c2.hexa`)
— each one is a landmine that detonates the moment a user calls a
feature whose lowering touches it.

## High-impact codegen-called gaps (sample, ~102 total)

```
array iterators (method-call):
  hexa_array_chunk · drop · find · flat_map · for_each · max · mean
  · min · partition · product · push_nostat · rotate · sample · scan
  · take · unique · window · zip · zeros_float · interleave · group_by
  · frequencies · argmax · set · shift

format / math / utility:
  hexa_format · format_float · format_float_sci · clamp · count_poly
  · gelu · hadamard · log · exp · sin · cos · tan · tanh · sqrt
  · fma · round · u_floor · softmax · silu · swiglu_vec · one_hot
  · matmul · matvec · tensor_add · tensor_dot · tensor_mul_scalar
  · tensor_ones · tensor_zeros

map operations:
  hexa_map_all · any · count · entries · filter_keys · from_array
  · invert · map_values · merge · remove_impl · set_impl · to_array
  · values

regex:
  hexa_regex_findall · match · match_full · replace · search · split

callbacks / FFI / streaming:
  hexa_callback_create · free · slot_id
  hexa_host_ffi_call · open · sym · extern_call_typed
  hexa_exec_stream_async · close · kill · poll · open_impl
    · close_impl · close_stdin_impl · kill_impl · poll_impl · write_impl

simulation primitives:
  hexa_farr_apply_single · pauli_exp_inplace · pauli_expectation
  · simplex_centroid · simplex_get · simplex_set · simplex_shrink
  · simplex_sort · transpose_scatter_gpu · uccsd_apply · vec_blend
  · vec_reflect · vertex_copy · pin_device · unpin_device
  hexa_ansatz_pack · ansatz_free · ham_pack · ham_free

terminal / I/O:
  hexa_term_fd_close · poll · read · write · isatty_stdin · isatty_stdout
  · pty_reap · pty_spawn_sh
  hexa_now_monotonic_s · sleep · sleep_ns · sleep_s · script_path
  · real_args · eprintln

JSON / UTC / strings / structs:
  hexa_json_decode · json_encode · utc_iso_format · utc_iso_parse
  hexa_str_concat · str_count_substr · str_eq · str_own · str_own_with_len
  hexa_struct_pack · unpack · point · rect · size_pack · free
  hexa_valstruct_get_by_key · int · set_by_key

arena / VM:
  hexa_arena_rewind · val_arena_heapify_to_parent · val_copy_into_arena
  · val_free_tree · val_heapify · val_snapshot_array

misc:
  hexa_to_bool · is_alpha · is_alphanumeric · is_error · deref
  · ptr_addr · ptr_null · ptr_offset
```

## Resolution path

The 3 sibling PRs (#348 / #350 / #356) prove the per-fn fix is
mechanical (1-line additive header decl matched to the existing
`runtime_core.c` definition). Three concrete options, in order of
preference:

1. **Automate** — `runtime_decls_gen.sh` (or `.hexa`) that greps the
   `^HexaVal hexa_…(` / `^int hexa_…(` definitions in `runtime_core.c`
   + `runtime.c`, diffs against `runtime.h`, and appends missing
   forward decls (with `runtime_core.c:LINE` comments). Run on every
   regen / pre-commit. One-time mass-add of the existing 102+ gaps;
   gate further drift.

2. **Mass-add now** — single PR adding all 102 codegen-called decls in
   one block (deferring the 64 non-codegen-called ones). ~100 lines,
   within the <200 g4 limit. No automation, but immediately unblocks
   every named feature.

3. **Per-feature individually** — keep filing per-PR like #348 / #350 /
   #356 as features get exercised. Slow; each new feature has a
   ~33% chance of being broken (102 / ~300 callable runtime fns).

Recommendation: (1) for the durable fix, with (2) as the next session's
work to clear the existing backlog while the automation lands.

## Cross-refs

- Sibling fix PRs (each closing one instance): #348 · #350 · #356
- Round-3 audit snapshot: `PROBE.md` · `PROBE.log.md`
- Round-4 sibling inbox patches (in this batch): canonical audit round 4
