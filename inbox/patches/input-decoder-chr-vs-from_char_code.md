# Input decoder uses byte-truncating `chr()` in codepoint→UTF-8 paths — Korean/CJK/emoji rendered as ASCII garbage

> **Status:** `resolved-ssot 2026-05-19` — already landed in tree by a parallel
> session/sister-patch: self/tui/input.hexa:304 (raw-UTF8 path) + :491
> (modifyOtherKeys CSI 27 branch) both already emit `from_char_code(codepoint)`
> with RFC-referencing comments (verified by grep — no `chr(cp)` remains at
> these sites; only the byte-synthesis `chr(b)` at L616/L624 which is correct).
> Decoder cluster B confirmed the fix is in-tree; no further edit needed for
> this patch. Parse-gate clean. Binary promote = standard separate deploy step.

**Layer:** `self/tui/input.hexa` — L2 input decode
**Files:** `self/tui/input.hexa:300` (raw UTF-8 path), `:489` (modifyOtherKeys CSI 27 branch)
**Sister patch:** `inbox/patches/modifyotherkeys-non-ascii-decoder-gap.md` (commit `bf943479`,
fixed the ASCII ceiling 127 → 0x110000 but left the deeper `chr` bug).

## Symptom

TUI consumers (wilson) display Korean / CJK / emoji as random ASCII chars after the sister
fix landed:

```
type '안'   (U+C548 = 50504)   →  ❯ H   (50504 & 0xFF = 0x48)
type '녕'   (U+B155 = 45397)   →  ❯ HU  (45397 & 0xFF = 0x55)
type '🌌'  (U+1F30C = 127756)  →  ❯ ... (low-byte garbage)
```

English input unaffected — for codepoints `< 0x80`, `chr(cp)` and `from_char_code(cp)` agree
(1 byte = cp), so the bug stayed hidden across all-ASCII development.

## Root cause

After the sister patch `bf943479` lifted the modifyOtherKeys ASCII ceiling, both the raw-mode
UTF-8 path and the modifyOtherKeys branch emit the `ch` field of the `key` event as
`chr(codepoint)`:

```hexa
return ["key", codepoint, 0, 0, 0, chr(codepoint)]                // raw UTF-8 (L300)
return ["key", _mok_code, _mok_ctrl, _mok_alt, _mok_shift, chr(_mok_code)]   // modifyOtherKeys (L489)
```

But `chr` in hexa-lang is **byte-truncating**, not UTF-8 encoding. Per the RFC
`chr-byte-vs-codepoint-asymmetry` (2026-05-17, `self/codegen_c2.hexa:4302-4308`):

```
// chr lowers to byte-level `hexa_chr_byte` (1 byte N & 0xFF),
// mirroring `ord(substring(s,i,1))` byte read. Previously emitted
// `hexa_from_char_code` (codepoint→UTF-8) which silently broke
// byte-synthesis callers (URL decode, PNG header, emoji prefix).
// `from_char_code` retains codepoint behaviour for JSON \uXXXX.
if name == "chr"            { return "hexa_chr_byte(" + a0 + ")" }
```

Runtime confirmation (`self/runtime.c:8104`):

```c
HexaVal hexa_chr_byte(HexaVal n) {
    int64_t code = HX_IS_INT(n) ? HX_INT(n) : (int64_t)_hexa_f(n);
    char* buf = hexa_strbuf_alloc((size_t)1);
    if (!buf) return hexa_str("");
    buf[0] = (char)(code & 0xFF);       // ← 1 byte, truncated to lower 8 bits
    return (HexaVal){.tag=TAG_STR, .s=buf};
}
```

So `chr(50504)` ('안') → `hexa_chr_byte(50504)` → `(char)(50504 & 0xFF)` = `0x48` = `'H'`.

The decoder's pre-RFC comment ("hexa chr() converts codepoint to UTF-8 encoding") reflected
the old (pre-2026-05-17) semantics; the RFC split kept `from_char_code` for codepoint→UTF-8
and re-purposed `chr` for byte-synthesis. The decoder didn't get the memo.

## Fix

Two single-token swaps in `self/tui/input.hexa`:

```diff
-    return ["key", codepoint, 0, 0, 0, chr(codepoint)]
+    return ["key", codepoint, 0, 0, 0, from_char_code(codepoint)]

-    if _mok_code >= 32 && _mok_code < 1114112 { return ["key", _mok_code, _mok_ctrl, _mok_alt, _mok_shift, chr(_mok_code)] }
+    if _mok_code >= 32 && _mok_code < 1114112 { return ["key", _mok_code, _mok_ctrl, _mok_alt, _mok_shift, from_char_code(_mok_code)] }
```

Plus comment refresh to document the chr / from_char_code distinction (so the next reader
doesn't make the same assumption).

## Why this matters

- Wilson Korean / CJK / emoji input was completely broken on the *post-sister-patch* tree —
  `bf943479` widened the ceiling so non-ASCII codepoints now reach the printable emit, but
  the emit truncates them to a single low byte. Without this follow-up the sister patch
  is observably useless for non-ASCII (worst kind of half-fix — looks like it should work).
- Applies to EVERY TUI consumer of `self/tui/input.hexa` (wilson today, future hexa-native
  TUI apps).
- Verified end-to-end with `tmux send-keys -l '안녕 하세요 🌌'` against a wilson built
  with both patches applied: input row reads `❯ 안녕 하세요 🌌` correctly.

## Related — audit prompt for other `chr(cp)` call sites

Any `chr(<expression that could exceed 127>)` in the codebase is suspect. Quick grep:

```
git grep -nE '\bchr\([^)]*(codepoint|cp|_cp|_mok|_csi|0x[1-9A-F]|[1-9][0-9][0-9])' self/ stdlib/
```

— compare hit-list against "intended a single byte" (URL decode / PNG header / emoji prefix
patterns) vs "intended codepoint→UTF-8" (text rendering / IME / JSON \uXXXX). For the latter,
swap to `from_char_code`.

## Sister patch CSI u (kitty kbd protocol)

`inbox/patches/csi-u-modifier-keys-decoder-gap.md` proposes a CSI u decoder extension that
uses `chr(_u_cp)` for the printable emit. That snippet must be updated to `from_char_code`
before landing, otherwise the same bug re-enters via the kitty kbd protocol channel.
