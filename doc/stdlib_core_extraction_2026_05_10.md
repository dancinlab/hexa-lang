# stdlib/core + stdlib/alloc Extraction — F1 Audit (2026-05-10)

> SPEC: `SPEC.yaml firmware_evolution.roadmap.F1` (this commit).
> Predecessor: `doc/firmware_audit_2026_05_10.md` (F0 / Option C
> decision).

## Goal

Implement the Option C split of stdlib into target-agnostic
`stdlib/core/` (no alloc, no syscall, no platform assumption) and
heap-aware `stdlib/alloc/` so `firmware/` can depend on the correct
tier under future `--target=*-none-*` cross-compilation. F1 is an
**additive** move — original locations keep a re-export shim, no
breaking changes to the 100+ consumers.

## Per-module classification table

| Path                          | Tier  | Reason                                               |
|---|---|---|
| stdlib/math.hexa              | core  | Pure integer arithmetic                              |
| stdlib/string.hexa            | core  | String predicates + concat helpers, no syscall       |
| stdlib/parse.hexa             | core  | Pure decimal-tolerant parse, deterministic           |
| stdlib/bytes.hexa             | core  | Pure byte to int + IEEE-754 reinterpret              |
| stdlib/math/float.hexa        | core  | Pure libm wrappers (constants, classifiers)          |
| stdlib/math/permille.hexa     | core  | Pure fixed-point arithmetic (PerMille struct)        |
| stdlib/math/rng.hexa          | core  | Pure LCG + Box-Muller (small fixed-size returns)     |
| stdlib/hash/sha256.hexa       | core  | Pure delegation to runtime hexa_sha256 builtin       |
| stdlib/hash/xxhash.hexa       | core  | Pure xxHash32/64 over caller-supplied byte array     |
| stdlib/collections.hexa       | alloc | Map / array helpers — heap-heavy                     |
| stdlib/path.hexa              | alloc | POSIX path string ops — split/join allocates         |
| stdlib/json.hexa              | alloc | JSON write-side, allocates strings/maps              |
| stdlib/json_object.hexa       | alloc | JSON read-side traversal, allocates maps/arrays      |
| stdlib/argparse.hexa          | alloc | argv parser, builds map+array structures             |
| stdlib/math/eigen.hexa        | alloc | Symmetric Jacobi eigh, builds working matrices       |
| stdlib/math/rng_ctx.hexa      | alloc | RngCtx struct + xxh64 stream-mix                     |

Modules left in **host** stdlib (file I/O / syscall / network / FFI):
io, log, portable_fs, time/iso8601, http, http2, http_sse, websocket,
proc, sys, channel, c_ffi, python_ffi, sqlite, safetensors, qrng_anu,
yaml, regex, tokenize, cancel, resolver, cert, policy, linalg, matrix,
nn, optim, tensor, autograd, iit_ei, consciousness, anima_audio_worker,
registry_autodiscover, hal (already target-gated), ckpt.

## Backward-compat strategy

Each moved module's original path was replaced with a 1-line
`import "stdlib/<core|alloc>/<path>"` re-export shim plus a header
comment describing the move. Verified pattern: `import "..."` in a
hexa module pulls in all `pub fn`s — symbol resolution is transparent
to consumers using either `import "stdlib/X"` or `use "stdlib/X"`.

The only file that needed an in-content edit beyond the shim was
`stdlib/alloc/math/rng_ctx.hexa`: its two relative imports
(`import "rng.hexa"`, `import "../hash/xxhash.hexa"`) were rewritten
to absolute paths into `stdlib/core/math/rng.hexa` and
`stdlib/core/hash/xxhash.hexa` so the moved file resolves
dependencies regardless of its host directory.

## Test pass count

- Baseline (pre-F1): 16/23 stdlib/test/test_*.hexa PASS, 7 pre-existing
  failures (test_bytes timeout, test_golden, test_http, test_io,
  test_resolver, test_safetensors timeout, test_websocket).
- Post-F1: identical 16/23 PASS, 7 same pre-existing failures.
  No regression.
- Direct module tests on relocated paths
  (stdlib/math/{eigen,float,permille,rng_ctx,rng,strict_fp}_test.hexa,
  stdlib/hash/{sha256,xxhash}_test.hexa, stdlib/test/test_parse.hexa,
  stdlib/test/test_bytes_float.hexa): **10/10 PASS**.
- Spot self-test sample
  (self/test_path_module, test_stdlib_string_t4,
  test_module_impl_closure): **3/3 PASS**.
  test_module_import fails for an unrelated pre-existing module-loader
  cycle assertion; not introduced by F1.

## Sunset plan for the shims

1. **F2 (this cycle)**: `firmware/boards/rtsc/` reference port keeps
   shim path active; firmware imports the explicit
   `stdlib/core/<X>` path directly so the new location starts
   accumulating direct callers.
2. **F3 (follow-up)**: `target_gate_check` lands in compiler;
   `--target=*-none-*` rejects host-stdlib imports. Shims are still
   present so existing host code is unaffected.
3. **F4 (follow-up)**: `firmware/boards/{chip,cern,antimatter,space}/`
   absorptions complete. By this point downstream consumers
   (anima/nexus/airgenome/orpheus etc.) have at least one release
   cycle to migrate from `import "stdlib/X"` to
   `import "stdlib/core/X"` for primitives and
   `import "stdlib/alloc/X"` for heap-using helpers.
4. **Post-F4**: shims removed, original paths return 404. A grep sweep
   of sister repos confirms zero residual references before the
   removal commit.

The shim files are intentionally tiny (single import + comment) so
keeping them through F2/F3/F4 has no maintenance cost.
