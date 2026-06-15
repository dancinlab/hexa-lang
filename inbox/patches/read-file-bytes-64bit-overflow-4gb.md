# read_file_bytes / read_bytes_at — 32-bit length+offset overflow on ≥4 GB files

> anima 1B model-mount finding (anima → hexa-lang/inbox per a_runpod_inbox). FIXED in this PR.

## Bug

`read_file_bytes(path)` returned a byte buffer whose LENGTH was stored in a 32-bit
field. For a file ≥ 2^32 bytes (4.294 GB) the length WRAPPED modulo 2^32.

Concrete repro: anima's 1B ByteGPT mount binary `h1167_1b.bin` is **4,325,902,356 bytes**.
`read_file_bytes` reported `len(rb) = 30,935,060` (= 4,325,902,356 mod 2^32) and the
buffer was unusable (header u32s read as 0 → downstream `d/n_head = 0/0` → "division by
zero"). Files < 4.29 GB (e.g. the 303M .bin ~1.2 GB) worked. So 1B+ models could not be
mounted/measured on the engine.

Two independent 32-bit choke points:

1. **Length wrap** — `HexaArr.len` / `.cap` were `int`, and `rt_read_file_bytes` cast the
   file size with `(int)len`. 4,325,902,356 → 30,935,060.
2. **Offset overflow** — `bytes_to_f32_le` / `bytes_to_f64_le` used `int len`, and
   `rt_read_bytes_at` (the documented multi-GB path) seeked with the UNSHIMMED `fseeko`
   on the runtime's `hxlcl_fopen` handle (not a real libc FILE*) → `flockfile` SIGSEGV on
   every call.

## Fix (64-bit width end-to-end, no size cap)

- `HexaArr.len` / `.cap` (and `HexaArrI64` / `HexaArrF64`, to preserve the documented
  `(ptr,len,cap)` layout-match invariant) → `int64_t`.
- `runtime.h` `HexaArr` typedef and the `hexa_len` decl → `int64_t` (the codegen-emitted
  user.c includes this header; both struct defs MUST match the runtime ABI).
- `hexa_len()` returns `int64_t` (codegen lowers `len(x)` → `hexa_int(hexa_len(x))`, so
  every caller is safe).
- `rt_read_file_bytes` / `rt_read_bytes_at` use the SHIMMED `fseek`/`ftell`/`fread`
  (`hxlcl_*`, `long` = 64-bit on LP64 over `hxlcl_lseek(off_t)`), drop the `(int)` casts,
  and store/iterate with `int64_t`. NOT `fseeko`/`ftello` — those are unshimmed and crash
  the hxlcl handle.
- OOB-message `%d` → `%lld` for the widened length field.
- `bytes_to_f32_le` / `_f64_le` / `_v` → `int64_t len`.

SSOT edits live in the emitters (`runtime_core_emit.hexa`, `tensor_kernels_emit.hexa`)
and the tracked header (`runtime.h`); `runtime_core.c` / `tensor_kernels.c` are
gitignored generated artifacts.

## Verification (macOS arm64, LP64)

- Standalone C harness on the real 4.3 GB `h1167_1b.bin`:
  OLD `(int)len` = **30935060** (reproduces the bug), NEW `int64_t` = **4325902356** (no
  wrap); first 5 header u32 = **256, 1792, 28, 16, 512**.
- In-engine `read_bytes_at` on the real 4.3 GB file: header u32 = 256/1792/28/16/512;
  ranged reads at offset **2,200,000,000** (past 2^31) and **4,325,902,348** (past 2^32)
  both succeed (no crash) — proves the 64-bit offset seek.
- `read_file_bytes` on a 100 MB file: correct `len` + high-offset index; binary
  write/read round-trip test PASSES; array/string/map regression clean.
- Full runtime recompiles clean (0 errors).

NOTE (anima-side, out of scope here): whole-file `read_file_bytes` on a 4.3 GB model
materializes ~69 GB of boxed HexaVals (16 B/byte) — infeasible on small-RAM hosts. The
memory-safe path for 1B+ mounts is the now-fixed `read_bytes_at` (ranged), or mmap.

---
source: anima 1B engine-mount (h1167) · status: FIXED (this PR)
