# read_f32_at — native ranged f32 reader for 1B+ load-once GENERATION

> anima 1B model-mount finding (anima → hexa-lang/inbox per a_runpod_inbox). ADDED in this PR.
> Builds on PR #3352 (read_file_bytes / read_bytes_at 64-bit).

## Problem

anima reads model weights via `read_bytes_at(path, off, n*4)` → a HexaVal **byte array** →
then parses each f32 with `bytes_to_f32_le`. The byte array boxes every byte as a HexaVal
(~16 B/byte). For a SINGLE forward this is fine (weights freed per layer). But for
**load-once GENERATION** the full 1B weight set must stay resident (~8.6 GB as native farr),
and the per-slice boxed byte buffers churn the allocator:

- Measured: ONE 256 MB on-disk slice read via `read_bytes_at` → **4.25 GB resident
  (17.0× boxing factor)**.
- For the full 4.3 GB `h1167_1b.bin` that is ~73 GB of churn → the OS jetsam kills the
  process with **SIGKILL (exit 137)** even though the live native weight set is only ~8 GB.

Repro: anima `bg_load_ranged` on `/…/state/h1167_mount/h1167_1b.bin` (4,325,902,356 B) → SIGKILL 137.

## Fix — a native ranged f32 reader (no boxed-byte intermediate)

New runtime builtin:

```
read_f32_at(path: string, byte_off: int, n_floats: int) -> farr
```

- Opens the file, seeks to `byte_off` (64-bit, via the SAME shimmed `fseek`/`fread` that
  #3352 fixed — NOT `fseeko`/`_fseeki64`, which SIGSEGV on the `hxlcl_*` handle).
- Allocates a fresh native `farr` (`hexa_farr_zeros`, the `double[]` handle table — `len`
  is already `int64_t`) of `n_floats`.
- Reads in a **bounded reused 8 MB C chunk buffer** (2M floats/chunk), decoding each
  little-endian IEEE-754 f32 DIRECTLY into the farr via `hexa_farr_set` (a single
  `e->buf[i] = x` store, no allocation). **NO intermediate boxed HexaVal byte array.**
- Transient memory is O(chunk)=8 MB, NOT O(slice) — a multi-GB slice streams through.

farr stores **f64**; an f32 is decoded as `memcpy(&f,buf,4)` then exact `(double)f`
widening — **byte-identical** to `bytes_to_f32_le(read_bytes_at(...))`, so anima's 303M /
1B parity stays byte-exact.

## SSOT edits (tracked emitters + header — generated .c are gitignored artifacts)

- `self/runtime_core_emit.hexa` — forward decls (`rt_read_f32_at`, and `hexa_farr_zeros`/
  `hexa_farr_set` which live in the OUTER runtime.c, #included after this fragment) +
  the `rt_read_f32_at` C body (mirrors `rt_read_bytes_at`, reuses the LE-f32 decode).
- `self/codegen.hexa` — register `read_f32_at` → `rt_read_f32_at` at the interpreter
  gen2_expr path, the AOT 3-arg path, and the `is_builtin` predicate.
- `self/runtime.h` — `rt_read_f32_at` prototype (so the transpiled user `.c` is not an
  implicit-declaration).

## Verify (macOS arm64, LP64)

- Clean compile: runtime amalgam (`hexa_cc.c` + regenerated `runtime_core.c` + `runtime.c`)
  → **0 errors**. Canonical regen: `[0-pre] runtime_core.c regen: 1 regenerated from emitter SSOT`.
- Functional: `read_f32_at("…/h1167_1b.bin", 20, 8)` → the 8 weight floats after the 20-byte
  header. End-to-end `.hexa` → C → binary run prints them.
- Equivalence: those 8 floats are **BYTE-IDENTICAL** to
  `bytes_to_f32_le(read_bytes_at(path, 20, 32))` at the same offsets.
- Memory (real 4.3 GB file): read ALL 1,081,475,584 floats in 64M-float ranged slices,
  keeping them resident (load-once emulation) → **peak phys_footprint 8.20 GB** (= the
  native f64 weight set, linear 2→4→6→8 GB, zero churn). The OLD boxed path is **17.0×**
  per slice (256 MB → 4.25 GB) → ~73 GB for the full file → jetsam SIGKILL.

This unblocks engine-measured GENERATION gates (G1 창발 etc.) on 1B+ models: anima can
switch `_bg_rd_farr_at` from `bytes_to_f32_le(read_bytes_at(...))` to `read_f32_at(...)`.
