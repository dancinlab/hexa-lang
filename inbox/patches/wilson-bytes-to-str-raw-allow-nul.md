# `bytes_to_str_raw([int])` — Phase 2: allow embedded NUL bytes

**Filed by:** wilson (Active gap #3 → multimodal Message)
**Date:** 2026-05-13
**Status:** **applied** — landed in this same commit (self/runtime.c:7589 / `hexa_bytes_to_str_raw`).
**Verified:** wilson `tool-image::image_read` on a synthetic 73-byte PNG (signature + IHDR with three leading NULs) now base64-encodes the full payload via the builtin `base64_encode(bytes_to_str_raw(arr))` one-liner; output matches `python3 -c "base64.b64encode(...)"` byte-for-byte. wilson's pure-hexa fallback (`tool_image_probe_arr` + `tool_image_base64_arr`) kept as a regression guard.
**Severity:** ~~blocker for any binary I/O path~~ resolved.

## Symptom

```hexa
let bytes_arr = read_file_bytes("/path/to/some.png")    // [int] 73 ints, byte 0 = 137, …
let s = bytes_to_str_raw(bytes_arr)                     // -> "" (silent)
len(s)                                                  // 0 — empty string
```

The PNG file's IHDR length field has `00 00 00 0d` — those three leading NUL bytes trip the Phase 1 guard at `runtime.c:7568`:

```c
if (b == 0) {
    // Phase 1: forbid mid-NUL (length-aware paths could handle
    // it but printf/concat surfaces still rely on C strlen).
    return hexa_str("");
}
```

## Why this is wrong for the binary-I/O use case

The same comment block above the guard already notes:

> Uses hexa_strbuf_alloc(n) which prepends a length header so HX_STRLEN is O(1) and reads the cached length; this makes embedded NUL (0x00) bytes safely representable (strlen()-using paths will truncate at the first NUL, but HX_STRLEN-aware paths see the full length).

So the **storage** is fine. Only **caller surfaces** that call `strlen(HX_STR(s))` would truncate. The Phase 1 guard punishes ALL callers, including the length-aware ones — `hexa_base64_encode` for instance reads `HX_STRLEN(s)` and is fully NUL-clean.

## Concrete impact

wilson's `tool-image::image_read` (multimodal vision input) needs the bytes → string → `base64_encode` chain to pass NUL bytes through. Today it has to fall back to a 30-line pure-hexa base64-from-array implementation, which is fine but defeats the purpose of having `read_file_bytes` + `base64_encode` builtins.

Any future tool doing binary I/O (`tool-audio` for OPUS / WAV / FLAC headers, model checkpoint round-trip, encryption primitives) will hit the same wall.

## Proposed Phase 2

Drop the `if (b == 0) return hexa_str("")` guard. The length header is already in place; HX_STRLEN-aware paths (which is most of what wilson and the stdlib use today) Just Work. The remaining strlen-callsite risk is well-bounded and discoverable via grep.

If you want a safety net, keep the guard behind a new `bytes_to_str_strict([int])` variant and let `bytes_to_str_raw` be the NUL-permissive one — but my read of RFC-030 is that "raw" already means "no policy."

## Acceptance

(a) `bytes_to_str_raw([137,80,78,71,13,10,26,10,0,0,0,13,73,72,68,82, ...])` returns a string of length **73**, not "".
(b) `ord(s.substr(8, 1))` returns `0` (the byte at offset 8 — first NUL in PNG IHDR length).
(c) `base64_encode(s)` returns the correct base64 of the 73-byte input.
(d) Test in `self/test_bytes_pure.hexa` updated to assert the above against a small synthetic blob.

## Cross-reference

- runtime.c:7550 — `hexa_bytes_to_str_raw`
- wilson commit (forthcoming) — multimodal Message v1 + pure-hexa base64-from-array workaround
- RFC-030 — `bytes_to_str_raw([int])`

넣었다
