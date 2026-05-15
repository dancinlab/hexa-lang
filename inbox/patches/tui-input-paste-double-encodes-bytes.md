# self/tui/input.hexa — `_byte_to_str` double-encodes every paste byte ≥ 0x80

## Symptom

When a user pastes any non-ASCII content into a hexa TUI program with
bracketed-paste enabled (DECSET 2004), the `kind == "paste"` event payload
arrives at the application *double-encoded*: every byte ≥ 0x80 becomes a 2-byte
UTF-8 sequence in the payload. The application sees the *codepoint encoding of
each individual paste byte*, not the original bytes.

For a Korean paste like `한글` (UTF-8: `ED 95 9C EA B8 80`):

```
   wire bytes (from terminal)  : ED 95 9C EA B8 80                     ← 6 bytes
   payload bytes (to app)      : C3 AD C2 95 C2 9C C3 AA C2 B8 C2 80   ← 12 bytes
   app displays as Latin-1     : "í  ê¸ "                              ← mojibake
```

The same wreckage applies to every non-ASCII paste — CJK, emoji, accented
European text (`café` → `Café`), box-drawing chars, you name it.

## Root cause

`self/tui/input.hexa` lines 463-515 (`_decode_in_paste`) accumulates each tty
byte through `_byte_to_str(b)`. That helper at line 520-529:

```hexa
fn _byte_to_str(b: int) -> string {
    if b >= 32 && b < 127 {
        return _ascii_table(b)        // ASCII fast path — returns 1-byte string
    }
    return chr(b)                      // ← BUG
}
```

`chr(b)` in hexa-lang is **codepoint → UTF-8 string** (`runtime.c::hexa_from_char_code`).
For `b ≥ 0x80` it does *not* produce a single-byte string — it UTF-8-encodes `b`
as a Unicode codepoint:

- `chr(0x80..0xBF)` → 2 bytes `C2 80..C2 BF`
- `chr(0xC0..0xFF)` → 2 bytes `C3 80..C3 BF`

So the paste accumulator turns every wire byte ≥ 0x80 into the wrong 2-byte
encoding, and downstream UTF-8 multi-byte sequences are scrambled.

## Fix

`bytes_to_str_raw([int]) -> string` already exists in the runtime (RFC 030,
2026-05-12, `runtime.c::hexa_bytes_to_str_raw`) — it wraps an int array as a
raw byte string with **no** codepoint re-encoding. That's exactly the
`_byte_to_str` contract that was always intended.

```hexa
fn _byte_to_str(b: int) -> string {
    if b >= 32 && b < 127 { return _ascii_table(b) }
    return bytes_to_str_raw([b])
}
```

Single-line patch. Inverts the bug for every downstream TUI without API
change.

## Other callers in this file

Line 234, 261, 318, 341, 379 also use `_byte_to_str(b)` — same bug, same fix
applies. Notably line 261 (`return ["key", b, 0, 0, 0, _byte_to_str(b)]` for
bytes 128-255 from CSI / SS3 / alt-modifier branches) would also be
silently double-encoded, though the impact is smaller since most keystrokes
arrive via the UTF-8 multibyte path (line 264-281) which builds the
codepoint correctly via `chr(codepoint)` (codepoint is from real Unicode,
not a wire byte).

## Repro

```sh
# In any Ghostty/iTerm2/Terminal.app session running a hexa TUI app
# (e.g. wilson harness-cli) with bracketed-paste enabled:
# 1. Copy any non-ASCII text to clipboard:
echo -n "한글" | pbcopy

# 2. Paste into the TUI (Cmd-V).
# 3. Submit / inspect the received string in the dispatch callback.
#
# Observed: 12 bytes per Korean syllable instead of 3; bytes are C2 XX / C3 XX
#           pairs that decode as Latin-1 mojibake.
# Expected: 3 bytes per Korean syllable (raw UTF-8).
```

## Wilson-side workaround landed

Until this lands upstream, wilson ships a workaround at
`plugins/harness-cli/main.hexa::harness_cli_paste_unmangle` — walks the
payload looking for `C2 XX` / `C3 XX` pairs and reverses the chr() encoding
via `bytes_to_str_raw`. Applied at the paste-side-map entry point so
every paste consumer (LLM submit, displayed scrollback, image-path detect)
sees the original bytes.

Once the upstream fix lands, the wilson workaround can be removed in a
follow-up commit. The workaround is idempotent on already-raw bytes (since
the pattern requires a continuation byte in 0x80..0xBF after the C2/C3),
so the transition is safe — wilson can drop it any time after upstream
hexa-lang rebuilds.

## Related

- Sibling patch `tui-input-needs-decset-2004-bracketed-paste.md` — without
  that fix, `_decode_in_paste` is never entered (no bracketed-paste markers,
  no paste event); the double-encoding bug surfaced *after* the DECSET 2004
  workaround landed in wilson.
- Sibling patch `tui-input-paste-buf-quadratic.md` — O(n²) string concat in
  the same `_decode_in_paste` accumulator for large pastes.
