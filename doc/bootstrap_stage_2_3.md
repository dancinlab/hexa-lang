# Bootstrap Stage 2 / Stage 3 Harness

This document describes the stage 2 self-compile and stage 3 fixed-point
checks landed under `tests/bootstrap/`. It pairs with the existing
`doc/stage1_punch_list_v2.md` and SPEC.yaml `bootstrap` section.

## What the stages mean

| Stage | Tool | Source | Output | Check |
| ----- | ---- | ------ | ------ | ----- |
| 0 | `hexa_interp` (interpreter, today) | `compiler/main.hexa` | stage 1 binary | A2 in flight |
| 1 | stage 1 binary | `compiler/main.hexa` | stage 2 binary | `tests/bootstrap/stage_2_smoke.hexa` |
| 2 | stage 2 binary | `compiler/main.hexa` | stage 3 binary | `tests/bootstrap/stage_3_fixed_point.hexa` |
| 3 | stage 3 binary | (assert) sha256(stage 2) == sha256(stage 3) | (none) | byte-equal fixed point |

Stage 0 is the existing `build/hexa_interp.<host>`. Stage 1 is produced by
A2 (in flight) and is the first native compiler binary. Stage 2 is the
first time the native compiler reads its own source. Stage 3 is the
canonical "the compiler is consistent with itself" check.

## Byte-equality requirement

The fixed-point check is **byte-equal SHA256 of the binary file**, not a
behavioral test. If stage 2 and stage 3 disagree by a single byte, the
check fails. This is intentional: byte-equality is the only way to prove
the compiler does not depend on its build host beyond declared inputs.

## Common failure modes

Hash drift between stage 2 and stage 3 almost always traces to one of:

1. **Timestamp embedding.** A `__DATE__`/`__TIME__` analogue, build-id,
   or `time(0)` call leaking into the emitted binary. Fix by removing
   non-deterministic intrinsics from codegen.
2. **Hash-table iteration order.** Iteration over `Map<Pointer, T>` whose
   iteration order tracks pointer values, which differ between runs.
   Fix by sorting before emit, or using insertion-ordered maps.
3. **Directory walk order.** `readdir` is not order-preserving. Always
   sort module file lists before driving the codegen pipeline.
4. **Environment leakage.** `HOME`, `PWD`, `USER` accidentally embedded
   into emitted strings (e.g., a debug path). Fix by canonicalising
   paths to repo-relative before any string survives into output.
5. **Allocator address dependence.** Embedding `&value` (or any pointer-
   derived integer) into output. Address layouts differ run-to-run with
   ASLR.
6. **Concurrent codegen.** Worker scheduling order changing emit order.
   Force a deterministic merge phase before write.

## Retry / debug strategy

When the fixed-point check fails:

1. Run `tests/bootstrap/run_bootstrap.sh` and capture both binaries
   (`/tmp/hexa_stage_2`, `/tmp/hexa_stage_3`).
2. `cmp -l /tmp/hexa_stage_2 /tmp/hexa_stage_3 | head -50` - the first
   differing byte offset usually points at one of the categories above.
3. If the diff is in the symbol table or string table, suspect map
   iteration order. If it is in `.text`, suspect codegen reordering.
   If it is in section headers, suspect linker emit order.
4. Compile with `--emit=asm` for both and `diff` the assembly to localise
   the source-level cause without binary noise.

## Deferred behavior (CI safety)

Both `.hexa` harnesses **exit 0** when their input is missing:

- `stage_2_smoke` exits 0 with "deferred" when no stage 1 binary is found.
- `stage_3_fixed_point` exits 0 with "deferred" when stage 2 is absent.

The `run_bootstrap.sh` driver propagates these as either `DEFERRED` or
`STAGE_2_PASS_ONLY`. Real failures (build attempted but produced no
binary, or hashes differ) return non-zero so CI fails them. This is a
deliberate choice: while A2 is landing, every CI run would otherwise red-X.

## File map

- `tests/bootstrap/stage_2_smoke.hexa` - stage 1 to stage 2 smoke
- `tests/bootstrap/stage_3_fixed_point.hexa` - stage 2 to stage 3 hash check
- `tests/bootstrap/run_bootstrap.sh` - POSIX-sh driver
- `doc/bootstrap_stage_2_3.md` - this document
- `SPEC.yaml` `bootstrap.witness_paths` - pointer references into above
