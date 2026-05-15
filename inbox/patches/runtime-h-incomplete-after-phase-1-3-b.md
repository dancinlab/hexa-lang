# `runtime.h` missing symbols after PHASE 1.3.B → wilson uncompilable

**Layer:** codegen / runtime header (compile-speed track)
**Related:** commit `0813f4e` (`feat(runtime.h): PHASE 1.2.A — grow header to compile-cover hexa_cc.c`) and `codegen_c2.hexa:679` (`PHASE 1.3.B (2026-05-15) — emit #include "runtime.h"`)

## Symptom

After `2026-05-15` codegen change (`#include "runtime.c"` → `#include "runtime.h"`),
wilson's user.c references many runtime symbols not exposed by `runtime.h`. Build
fails with "call to undeclared function" errors across two distinct categories.

## Category A: missing extern decls (easy fix)

These functions ARE defined non-static in `runtime.c` or `native/*.c` but
`runtime.h` lacks a forward declaration. Round-by-round clang-error-driven
discovery (2026-05-15, wilson clean rebuild) found ~30 missing decls. List
below grouped by source file, each with the line number for the SSOT-resync.

### From `self/runtime.c`

| Function                          | Defn line  | Signature                                                       |
|-----------------------------------|------------|-----------------------------------------------------------------|
| `hexa_map_keys`                   | 2430       | `HexaVal hexa_map_keys(HexaVal m)`                              |
| `hexa_map_remove`                 | 2606       | `HexaVal hexa_map_remove(HexaVal m, const char* key)`           |
| `hexa_str_substr`                 | 7495       | `HexaVal hexa_str_substr(HexaVal s, HexaVal start, HexaVal len)`|
| `hexa_input`                      | 7616       | `HexaVal hexa_input(HexaVal prompt)`                            |
| `hexa_read_stdin`                 | 9962       | `HexaVal hexa_read_stdin(void)`                                 |
| `hexa_exec_with_status`           | 4281       | `HexaVal hexa_exec_with_status(HexaVal cmd)`                    |
| `hexa_timestamp`                  | 9877       | `HexaVal hexa_timestamp(void)`                                  |
| `hexa_time_ms`                    | 9889       | `HexaVal hexa_time_ms(void)`                                    |
| `hexa_from_char_code`             | 7668       | `HexaVal hexa_from_char_code(HexaVal n)`                        |
| `hexa_sleep_ms`                   | 10000      | `HexaVal hexa_sleep_ms(HexaVal ms)`                             |
| `hexa_term_raw_enter`             | 11337      | `HexaVal hexa_term_raw_enter(void)`                             |
| `hexa_term_raw_restore`           | 11338      | `HexaVal hexa_term_raw_restore(void)`                           |
| `hexa_term_poll_stdin`            | 11351      | `HexaVal hexa_term_poll_stdin(HexaVal ms)`                      |
| `hexa_term_read_byte`             | 11355      | `HexaVal hexa_term_read_byte(void)`                             |
| `hexa_term_winsize_rows/cols`     | 11340/11345| `HexaVal …(void)`                                               |
| `hexa_term_write_str`             | 11357      | `HexaVal hexa_term_write_str(HexaVal s)`                        |
| `hexa_term_install_sigwinch/int`  | 11366/11368| `HexaVal …(void)`                                               |
| `hexa_term_sigwinch_pending`      | 11367      | `HexaVal hexa_term_sigwinch_pending(void)`                      |
| `hexa_term_sigint_pending`        | 11369      | `HexaVal hexa_term_sigint_pending(void)`                        |
| `hexa_term_getppid`               | 11372      | `HexaVal hexa_term_getppid(void)`                               |
| `hexa_json_parse`                 | 10538      | `HexaVal hexa_json_parse(HexaVal s)`                            |
| `hexa_json_stringify`             | 10639      | `HexaVal hexa_json_stringify(HexaVal v)`                        |
| `hexa_bytes_to_str_raw`           | 7718       | `HexaVal hexa_bytes_to_str_raw(HexaVal arr)`                    |
| `hexa_to_int`                     | 5214       | `HexaVal hexa_to_int(HexaVal v)`                                |
| `hexa_find_poly`                  | 7007       | `HexaVal hexa_find_poly(HexaVal obj, HexaVal arg)`              |
| `hexa_dict_keys`                  | 9948       | `HexaVal hexa_dict_keys(HexaVal m)`                             |
| `hexa_base64_encode`              | 10931      | `HexaVal hexa_base64_encode(HexaVal s)`                         |
| `rt_append_file`                  | 9830       | `HexaVal rt_append_file(HexaVal path, HexaVal content)`         |
| `rt_str_to_lower`                 | 5407       | `HexaVal rt_str_to_lower(HexaVal s)`                            |
| `rt_read_file_bytes`              | 4957       | `HexaVal rt_read_file_bytes(HexaVal path)`                      |
| `hexa_exec_stream_open/write/close_stdin` | 11961-11963 | `HexaVal …(HexaVal …)`                              |

### From `self/native/crypto_sodium.c` (HEXA_HAS_LIBSODIUM)

| Function                          | Defn line  | Signature                                                       |
|-----------------------------------|------------|-----------------------------------------------------------------|
| `hexa_sha512`                     | 81         | `HexaVal hexa_sha512(HexaVal data)`                             |
| `hexa_sha256_bytes`               | 101        | `HexaVal hexa_sha256_bytes(HexaVal data)`                       |
| `hexa_ed25519_sign`               | 135        | `HexaVal hexa_ed25519_sign(HexaVal priv, HexaVal msg)`          |
| `hexa_ed25519_verify`             | 160        | `HexaVal hexa_ed25519_verify(HexaVal pub, HexaVal msg, HexaVal sig)` |
| `hexa_x25519_keypair`             | 181        | `HexaVal hexa_x25519_keypair(void)`                             |
| `hexa_x25519_scalarmult`          | 198        | `HexaVal hexa_x25519_scalarmult(HexaVal scalar, HexaVal point)` |
| `hexa_chacha20_xor`               | 224        | `HexaVal hexa_chacha20_xor(HexaVal key, HexaVal nonce, HexaVal data)` |
| `hexa_poly1305_onetimeauth`       | 252        | `HexaVal hexa_poly1305_onetimeauth(HexaVal key, HexaVal msg)`   |

### From `self/native/crypto_openssl.c` / `crypto_blowfish.c`

| Function                          | File:line                       | Signature                          |
|-----------------------------------|---------------------------------|------------------------------------|
| `hexa_aes256_ctr_xor`             | crypto_openssl.c:20             | `HexaVal …(HexaVal key, HexaVal iv, HexaVal data)` |
| `hexa_bcrypt_pbkdf`               | crypto_blowfish.c:457           | `HexaVal …(HexaVal pass, HexaVal salt, HexaVal rounds, HexaVal keylen)` |

### From `self/native/net.c`

| Function                          | Defn line  | Signature                                                       |
|-----------------------------------|------------|-----------------------------------------------------------------|
| `hexa_net_connect`                | 368        | `HexaVal hexa_net_connect(HexaVal addr)`                        |
| `hexa_net_write_bytes`            | 489        | `HexaVal hexa_net_write_bytes(HexaVal fd, HexaVal arr)`         |
| `hexa_net_read_bytes`             | 530        | `HexaVal hexa_net_read_bytes(HexaVal fd, HexaVal max)`          |
| `hexa_net_close`                  | 168        | `HexaVal hexa_net_close(HexaVal fd)`                            |

**Fix:** add forward declarations to `runtime.h`. Some are already added in
the patched header (~30 added 2026-05-15 round-by-round; see runtime.h diff
at the bottom of this patch). The remaining few can be added the same way.

## Category B: `static` symbols in `runtime_hi_gen.c` (HARD fix)

`runtime.c:5446` does `#include "runtime_hi_gen.c"` — a generated C file
containing **`static`** functions like `rt_str_lines`, `rt_str_split`,
`rt_str_pad_left/right`, etc. (autogen'd from `self/runtime_hi.hexa` and
`self/rt/*.hexa`).

Wilson's generated user.c calls `rt_str_lines(body)` directly (codegen
turns `body.lines()` into `rt_str_lines(body)`). When user.c includes
**runtime.c**, the static defs in `runtime_hi_gen.c` are in the same
translation unit and link cleanly. When user.c includes **runtime.h** only,
those static defs are in a DIFFERENT translation unit (runtime.o once it's
precompiled) and `static` means they're not visible — `static` is a hard
link-level invisibility, not just a header missing decl.

**Affected symbols (from one wilson clean build):** `rt_str_lines`,
`rt_str_to_lower`, `rt_str_trim` (defined in runtime.c, so OK — see Category
A), `rt_str_split`, `rt_str_pad_left`, `rt_str_pad_right`, … and a long
tail of stdlib helpers.

**Fix paths:**

1. **De-static `runtime_hi_gen.c`** — drop `static` from each function in
   the autogen output. Add matching `extern` decls in `runtime.h`. ~50 +
   forward decls; rt/*.hexa-driven so regenerating runtime_hi_gen.c is a
   single make target. *Recommended*: this is the canonical fix that
   completes PHASE 1.3.B.

2. **Compile runtime_hi_gen.c into runtime.o** — make sure runtime.o ships
   the bodies that runtime.h declares. Then `clang user.c runtime.o -o user`
   resolves at link time. (Today no precompiled `runtime.o` is shipped in
   the toolchain dir — wilson and other downstream projects use the legacy
   `#include "runtime.c"` monolithic compile path.)

3. **Codegen env-var escape hatch** — let downstream projects opt out of
   PHASE 1.3.B until the migration is complete:
   ```hexa
   // codegen_c2.hexa:679
   let runtime_inc = if env("HEXA_USE_RUNTIME_C") != "" { "runtime.c" } else { "runtime.h" }
   parts.push("#include \"" + runtime_inc + "\"\n\n")
   ```
   *This patch already applied locally to codegen_c2.hexa.* Effective after
   the next `hexa_v2` rebuild. Wilson can set `HEXA_USE_RUNTIME_C=1` in its
   build env until path (1) lands.

## Recommendation

Land path (3) FIRST as an immediate unblock (one-line codegen change, no
runtime/header churn). Then path (1) over the next few cycles to complete
the migration cleanly. Path (2) is the long-term archive — precompiled
runtime.o shipped with the toolchain — and follows naturally once (1) is
done.

## Reproducer

```sh
cd ~/core/wilson
git checkout main
./build/Darwin-arm64/wilson build                       # fails with the errors above

# Immediate workaround (until codegen env-var lands and hexa_v2 is rebuilt):
sed -i.bak 's|#include "runtime.h"|#include "runtime.c"|' build/artifacts/wilson.c
clang -O2 -DHEXA_HAS_LIBSODIUM -I/opt/homebrew/Cellar/libsodium/1.0.22/include \
      -DHEXA_HAS_OPENSSL -I/opt/homebrew/Cellar/openssl@3/3.6.2/include \
      -Wno-trigraphs -fbracket-depth=4096 \
      -I /Users/ghost/core/hexa-lang/self \
      build/artifacts/wilson.c -o build/Darwin-arm64/wilson \
      -lpthread -lsodium -lssl -lcrypto                  # ← succeeds
```

## Severity

**High — blocks downstream rebuilds.** Anyone tracking `main` who compiles
a project using stdlib/sort or rt/string ops or event-bus folds hits this
on the first build after pulling. The workaround is one `sed` line but
it's load-bearing in CI and dev iteration. Path (3) (env-var escape hatch)
unblocks in one commit.

## Status (2026-05-15 — RESOLVED end-to-end on local hexa-lang)

- **Category A**: ~35 forward decls added to `runtime.h` (round-by-round
  clang-error-driven discovery against wilson's clean build). Includes
  runtime.c (`hexa_map_keys`, `hexa_json_parse`, `hexa_term_*`, `hexa_net_*`,
  `hexa_exec_with_status`, `hexa_timestamp`, `hexa_from_char_code`, …),
  native crypto (`hexa_sha256_bytes`/`hexa_sha512`/`hexa_ed25519_*`/
  `hexa_x25519_*`/`hexa_chacha20_xor`/`hexa_poly1305_*`/`hexa_aes256_ctr_xor`/
  `hexa_bcrypt_pbkdf`), and net (`hexa_net_connect`/`hexa_net_read_bytes`/
  `hexa_net_write_bytes`/`hexa_net_close`). Plus `rt_str_ends_with` (defined
  non-static in runtime.c L3781, just missing from header) and the
  `exec_stream_async`/`exec_stream_poll`/`exec_stream_close` raw-symbol
  variants used by `hexa_call1(…)` _Generic dispatch.

- **Category B**: `rt_str_*` from `runtime_hi_gen.c` — RESOLVED via path 1.
  - `runtime_hi_gen.c`: de-static'd `rt_str_split`/`rt_str_lines`/
    `rt_str_pad_left`/`rt_str_pad_right`/`rt_str_repeat`/`rt_str_center`
    (Step 4 of the extract pipeline used to sed-re-static them; removed)
  - `tool/extract_runtime_hi.sh`: removed the re-static sed step so future
    regenerations preserve external linkage
  - `runtime.h`: forward decls for the six `rt_str_*` functions added in
    a "rt_* high-layer stdlib" block

- **Codegen escape hatch (path 3)**: `codegen_c2.hexa:679` checks
  `HEXA_USE_RUNTIME_C` env var and reverts to `#include "runtime.c"` when
  set. Takes effect after `hexa_v2` is rebuilt from this `codegen_c2.hexa`.
  Kept as a safety net so downstream projects can opt out if a future
  runtime ABI change re-breaks the header.

- **End-to-end verification (2026-05-15, wilson clean build, Darwin-arm64)**:
  - codegen emits `#include "runtime.h"` (PHASE 1.3.B default)
  - clang -c wilson.c → wilson.o (user code only, fast)
  - clang -c runtime.c → runtime.o (precompile-once)
  - clang wilson.o runtime.o -lpthread -lsodium -lssl -lcrypto → wilson
  - `./build/Darwin-arm64/wilson test` → 23/23 PASS, ~3s
  - `./build/Darwin-arm64/wilson test --e2e` → 26/26 PASS, ~73s

  Confirms paths 1+2 of the "Fix paths" section work together. Wilson is now
  a working downstream proof-point for the COMPILE-SPEED PHASE 1.3.B model.

## Open follow-ups

- `hexa build` (the unified codegen+clang command) doesn't yet drive the
  two-step compile (user.o + runtime.o) — it still monolithic-compiles, so
  the speedup from PHASE 1.3.B isn't realized through that entry. Wilson's
  `_cmd_build` can either: (a) wait for `hexa build` to adopt two-step, or
  (b) drive the two-step pipeline itself (codegen → clang -c × 2 → link).
- Static-discovery is clang-error-driven; future codegen changes that
  reference new runtime symbols will re-trip the "undeclared function" path
  until those symbols are added to `runtime.h`. A symbol-extraction pass on
  runtime.c (`grep -E '^(HexaVal|int|void|const char\*) hexa_'`) and
  cross-referencing against the header would catch regressions early.
