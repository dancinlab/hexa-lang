# RFC 030 — `bytes_to_str_raw([int]) -> string`

> **Status**: draft (stub from anima Phase 4.2)
> **Author**: anima/HEXA_NATIVE_INFERENCE Phase 4.2 byte_tokenizer
> **Filed**: 2026-05-12
> **Class**: runtime primitive (one new builtin)

## Problem

`tool/hexa_native/byte_tokenizer.hexa` ports anima's byte-level tokenizer to
pure hexa. `encode(text) -> [int]` works correctly via the existing
`char_code(s, i) & 0xFF` builtin — UTF-8 byte iteration is sound.

`decode_bytes([int]) -> [int]` (raw byte array) also works correctly.

**Blocker**: assembling the byte array into a usable hexa `string` requires
a primitive that wraps an `[int]` (each ∈ 0..255) as a hexa string whose
underlying UTF-8 bytes are exactly those integers. The currently exposed
builtin `from_char_code(n)`:

- for `n < 0x80` returns a 1-byte ASCII string ✓
- for `n ∈ 0x80..0xFF` returns the 2-byte UTF-8 encoding of codepoint U+n,
  NOT a raw byte ✗

Concatenating `from_char_code(b)` over a UTF-8 byte sequence therefore
re-interprets each high byte as a codepoint, breaking byte-level fidelity
for any non-ASCII original text. anima byte tokenizer outputs UTF-8 byte
streams (Korean / emoji / arbitrary binary), so this path cannot reassemble
"안녕" or "🌌" correctly.

## Proposal

Add a single runtime builtin:

```hexa
// Wrap an int array (each element ∈ 0..255) as a hexa string whose
// underlying char* contents are exactly those bytes. NUL (0x00) is
// permitted mid-sequence only if a length-prefixed string variant
// is available — otherwise undefined behavior past first NUL.
//
// The hexa runtime already stores strings as length-aware char* in
// most paths (HX_STRLEN walks the buffer); the only ambiguity is
// printf/concat surfaces that use strlen. Phase 1 of this RFC is
// the safe subset: byte values 1..255 only, with a 0x00 byte
// raising a runtime error.
pub fn bytes_to_str_raw(bs: [int]) -> string
```

### Inverse already exists

`stdlib/safetensors.hexa::_bytes_to_str` and the new
`tool/hexa_native/byte_tokenizer.hexa::decode_bytes` together provide the
string-to-bytes and bytes-list paths; what's missing is the closing edge
of the diamond.

## Mechanical cost

`runtime.c` already has `hexa_str_new`, `hexa_str_own`, and the arena
allocator path used by `hexa_str_concat`. A direct implementation:

```c
HexaVal hexa_bytes_to_str_raw(HexaVal arr) {
    if (!HX_IS_ARR(arr)) return hexa_str("");
    int64_t n = HX_ARR_LEN(arr);
    char* buf = (char*)malloc(n + 1);
    for (int64_t i = 0; i < n; i++) {
        HexaVal v = HX_ARR_ITEMS(arr)[i];
        int b = HX_IS_INT(v) ? (int)HX_INT(v) : (int)_hexa_f(v);
        if (b < 0 || b > 255) {
            free(buf);
            // raise: byte out of range
            return hexa_str("");  // or hexa_throw — choose policy
        }
        if (b == 0) {
            free(buf);
            return hexa_str("");  // Phase 1: forbid mid-NUL
        }
        buf[i] = (char)b;
    }
    buf[n] = '\0';
    return hexa_str_own(buf);
}
```

~25 lines + dispatch table entry. No new arena type, no new struct, no
ABI change.

## Backward compat

Pure-additive. `from_char_code` semantics untouched.

## Falsifiers

- F-RFC030-EMPTY: `bytes_to_str_raw([]) == ""`
- F-RFC030-ASCII: `bytes_to_str_raw([72, 105]) == "Hi"`
- F-RFC030-UTF8-RT: `bytes_to_str_raw(_str_to_bytes("안녕")) == "안녕"`
- F-RFC030-EMOJI-RT: `bytes_to_str_raw([240, 159, 140, 140]) == "🌌"`
- F-RFC030-RANGE: `bytes_to_str_raw([256])` raises out-of-range (or returns "")
- F-RFC030-NUL: Phase 1 — `bytes_to_str_raw([0])` raises mid-NUL

## Anima-side blocker

Without this primitive, `byte_tokenizer.hexa::decode_to_str(ids)` cannot
exist as a single-line wrapper; `anima_chat.py` parity for any Korean /
emoji / non-ASCII text is blocked at the final output stage. The byte-level
correctness (encode → decode_bytes → re-encode) is preserved, so this is
a **display-only** blocker — model logits and generation work; the user-
facing string can be assembled by `decode_bytes` + an out-of-band C helper
in the interim.

## Cross-reference

- Phase 4.2 artifact: `anima/tool/hexa_native/byte_tokenizer.hexa`
- Phase 5 inference loop will call this primitive (currently uses
  `decode_bytes` + shell-level reassembly fallback)
- Companion: RFC 025 (zero-copy mmap) is the OTHER inference blocker
  Phase 5 cannot proceed without.
