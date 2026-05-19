# xterm modifyOtherKeys decoder drops every non-ASCII codepoint — Hangul / CJK / emoji input lost

**Layer:** `self/tui/input.hexa` — L2 input decode
**File:** `self/tui/input.hexa:467-478` (the `n == 27` modifyOtherKeys branch of `_csi_final_to_event`, `final='~'`)
**Symptom:** When `ESC[>4;2m` (xterm modifyOtherKeys level 2) is pushed, terminals reformat
*every* printable keypress — including non-ASCII — as `CSI 27;<modifier>;<codepoint>~`. The
decoder's modifyOtherKeys branch only decoded codepoints `32..126` (ASCII printable); every
codepoint at or above 127 returned `["err", "csi-modifyotherkeys-unsupported-code"]`, which
downstream event loops drop. Result: Korean (Hangul), CJK and emoji input is silently lost
or rendered as replacement glyphs while ASCII typing still works.

This is the modifyOtherKeys sibling of `csi-u-modifier-keys-decoder-gap.md` — same root
shape (a CSI branch that only covers ASCII), different trigger sequence.

> **VERIFIED-CLOSED 2026-05-19**: SSOT grep cross-verified — `self/tui/input.hexa` carries the `0x110000` / `1114112` codepoint ceiling (grep ×2 [×3 incl. variant]), landed commit `bf943479`. Close-only marker (no source change, no fix re-run; fix already live in SSOT). NOTE: the deeper `chr()` followup is tracked SEPARATELY as `input-decoder-chr-vs-from_char_code` and remains OPEN — it is NOT closed by this marker.

**Status:** Fix applied to `self/tui/input.hexa` on branch
`fix/modifyotherkeys-non-ascii-decoder` — printable ceiling raised `127` → `1114112`
(U+110000). Verified by wilson `decoder_smoke` regression case (`modifyOtherKeys Hangul
'안'`, cp=50504) → `[decoder] keys 12/12 PASS`, `wilson test` 23/23. Wilson also pushes
`ESC[>4;1m` (level 1) as a complementary workaround.

## Repro

```
wilson                                  # interactive TUI; harness-cli pushes ESC[>4;2m
type 'hello'                            # ASCII — works (codes 104/101/108/108/111 ∈ 32..126)
type '안녕'                              # Hangul — input dropped / garbled
```

## Bytes on the wire (Hangul '안' = U+C548, modifyOtherKeys level 2)

```
ESC [ 27 ; 1 ; 50504 ~
```

- `27`    = the modifyOtherKeys literal marker
- `1`     = modifier (1 = no modifier)
- `50504` = the character codepoint (U+C548 '안')

## Decoder before the fix (`self/tui/input.hexa:467-478`)

```hexa
if n == 27 && len(_parts_csi) >= 3 {
    let _mok_mod  = _atoi(to_string(_parts_csi[1]))
    let _mok_code = _atoi(to_string(_parts_csi[2]))
    let _mok_eff  = if _mok_mod <= 1 { 0 } else { _mok_mod - 1 }
    let _mok_shift = if (_mok_eff & 1) != 0 { 1 } else { 0 }
    let _mok_alt   = if (_mok_eff & 2) != 0 { 1 } else { 0 }
    let _mok_ctrl  = if (_mok_eff & 4) != 0 { 1 } else { 0 }
    if _mok_code == 13 { return ["key", -1, _mok_ctrl, _mok_alt, _mok_shift, ""] }
    if _mok_code == 9  { return ["key", -2, _mok_ctrl, _mok_alt, _mok_shift, ""] }
    if _mok_code == 8 || _mok_code == 127 { return ["key", -3, _mok_ctrl, _mok_alt, _mok_shift, ""] }
    if _mok_code >= 32 && _mok_code < 127 { return ["key", _mok_code, _mok_ctrl, _mok_alt, _mok_shift, chr(_mok_code)] }
    return ["err", "csi-modifyotherkeys-unsupported-code"]   // <-- every cp >= 127 dies here
}
```

The `_mok_code >= 32 && _mok_code < 127` guard capped the printable path at ASCII. Any
codepoint at or above 127 — the entire Hangul / CJK / Latin-1-supplement / emoji range —
fell through to the error return.

## Fix applied

Raise the printable ceiling from `127` to the Unicode maximum, mirroring the raw-mode
UTF-8 path (`_decode_one` line 300, which already emits `chr(codepoint)` for multibyte
input). `chr()` returns the UTF-8 encoding for wide codepoints, so the `ch` field stays
correct.

```hexa
    // Printable: ASCII *and* non-ASCII (Hangul / CJK / emoji). chr() emits
    // the UTF-8 encoding for wide codepoints — mirrors the raw-mode path at L300.
    if _mok_code >= 32 && _mok_code < 1114112 {
        return ["key", _mok_code, _mok_ctrl, _mok_alt, _mok_shift, chr(_mok_code)]
    }
    return ["err", "csi-modifyotherkeys-unsupported-code"]
```

`1114112` = `0x110000`, one past the highest valid Unicode scalar (the file uses decimal
literals throughout, so the bound is written in decimal).

## Why this matters

- modifyOtherKeys level 2 is push-only — an app that enables it for Shift+Enter cannot
  ask the terminal to keep non-ASCII as raw UTF-8 while reformatting only modified keys.
- Any non-Latin-script user (Korean / Japanese / Chinese / emoji) cannot type once the
  mode is on. ASCII works, which makes the bug look intermittent / language-specific.
- The raw-mode decoder (`_decode_one`, lines 283-300) already handles the full Unicode
  range correctly; the modifyOtherKeys branch should match its breadth.

## Wilson-side workaround (also applied)

`plugins/harness-cli/main.hexa::harness_cli_term_modes_on` — push `ESC[>4;1m`
(modifyOtherKeys **level 1**) instead of `ESC[>4;2m`. Level 1 reformats only
genuinely-ambiguous modified keys (Shift+Enter etc.) and leaves plain printable +
IME-composed text as raw UTF-8, which the decoder's UTF-8 path handles. This avoids
the broken branch entirely; the upstream fix lets level 2 be used safely again.

## Related

- `self/tui/input.hexa:283-300` — the raw-byte UTF-8 path (the breadth the modifyOtherKeys
  branch mirrors; already emits `chr(codepoint)` for the full range)
- `inbox/patches/csi-u-modifier-keys-decoder-gap.md` — the CSI u sibling of this gap; note
  its "Related" section claims the modifyOtherKeys branch "already handles printable cps" —
  true only for ASCII 32..126, which this fix extends to the full Unicode range
