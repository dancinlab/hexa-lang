# self/stdlib/term_unicode::_u8_decode — char_code() 1-arg form returns 0 for multi-byte strings, breaking ALL CJK/emoji width tracking

**Severity: HIGH — affects every TUI built on `self/tui/render` rendering wide chars.**
**Reported via wilson harness-cli (2026-05-12, Ghostty / Korean input).**

## Symptom

Every wide-glyph CJK character (Korean Hangul, Chinese, Japanese Kanji, etc.)
and wide emoji render with a stray 1-cell gap after them, even after
`67b99c13` ("track terminal cursor by display width") landed.

User screenshot (wilson, Ghostty, Korean):
```
> efaesf 한 글  ㄴ ㅇ  | dfkmadsfkalsdf wefmklwef  글 ㅇ ㅏ  …
입 력 하 신  메 시 지 가  의 미 를  파 악 하 기  어 렵 습 니 다 …
```
Each `한` / `글` / etc. is followed by an extra blank cell.

## Direct probe (built and run on Mac arm64, today)

```hexa
fn main() -> int {
    let s = "한"  // UTF-8: 0xED 0x95 0x9C  (3 bytes)
    eprintln("char_code(s, 0)             = " + str(char_code(s, 0)))
    eprintln("char_code(s.substring(0,1)) = " + str(char_code(s.substring(0, 1))))
    return 0
}
```

Output:
```
char_code(s, 0)             = 237          ← correct: byte value
char_code(s.substring(0,1)) = 0            ← WRONG: should also be 237
```

The 1-arg form `char_code(string)` returns **0** when the string contains
any byte ≥ 0x80. The 2-arg form `char_code(string, idx)` correctly returns
the byte value. Probable cause: the 1-arg form treats the string as a single
codepoint, attempts UTF-8 decoding, and fails (or sees the high-bit byte as
invalid lead and emits 0). Either way the contract diverges from the 2-arg
form silently.

## Why it breaks rendering

`self/stdlib/term_unicode.hexa::_u8_decode` walks bytes like this (line 58
ff):

```hexa
let b0 = char_code(s.substring(idx, idx + 1))       // 1-arg → always 0 for non-ASCII!
if b0 < 128 { return [b0, 1] }                       // takes this path → wrong
if b0 < 192 { return [-1, -1] }
if b0 < 224 { /* 2-byte UTF-8 */ ... }
if b0 < 240 { /* 3-byte (Korean / CJK) */ ... }
if b0 < 248 { /* 4-byte (emoji) */ ... }
```

Because `b0 == 0` for the high-bit byte, the function returns `[0, 1]` —
i.e., it decodes only ONE byte of a 3-byte UTF-8 sequence and reports cp=0.

`cp_width(0)` returns `-1` (C0 control) at line 166-167. `char_width_at`
propagates that as `[-1, 1]` and `text_width` returns the negative.

`self/tui/render.hexa::render_flush` consumes this:

```hexa
let w = if ch == "" { 1 } else {
    let cw = char_width_at(ch, 0)[0]
    if cw < 1 { 1 } else { cw }
}
```

Negative `cw` → `cw < 1` → `w = 1`. So every wide-glyph cell gets `w = 1`,
the diff loop visits the supposed continuation cell at `x + 1` (instead of
skipping via `x = x + w` = `x + 2`), and the blank cell there is emitted as
a space ANSI write. That's the 1-cell gap on screen.

`67b99c13` already fixed `last_x = x + w - 1` and the loop's `x = x + w`.
But because `w` is itself wrong (`1` instead of `2`), the fix can't take
effect.

`self/tui/widget/text::text_visual_width` uses a *separate* decoder
(`_utf8_step`, in widget/text.hexa) that does NOT call `char_code` 1-arg,
so it correctly reports width 2 for Hangul. That's why
`text_visual_width("한") = 2` works in the same probe binary — but
`char_width_at("한", 0) = [-1, 1]` does not.

## Fix — one line in _u8_decode

Replace every `char_code(s.substring(idx + k, idx + k + 1))` in `_u8_decode`
with the 2-arg `char_code(s, idx + k)`. The 2-arg form reads the byte at
the given byte offset directly (matches runtime.c::hexa_char_code:
`return hexa_int((unsigned char)HX_STR(s)[i])`).

Diff (`self/stdlib/term_unicode.hexa`, lines 55-94):

```diff
 fn _u8_decode(s: string, idx: i64) -> array {
     let n = len(s)
     if idx < 0 || idx >= n { return [-1, -1] }
-    let b0 = char_code(s.substring(idx, idx + 1))
+    let b0 = char_code(s, idx)
     if b0 < 128 {
         return [b0, 1]
     }
     if b0 < 192 {
         return [-1, -1]
     }
     if b0 < 224 {
         if idx + 2 > n { return [-1, -1] }
-        let b1 = char_code(s.substring(idx + 1, idx + 2))
+        let b1 = char_code(s, idx + 1)
         if b1 < 128 || b1 >= 192 { return [-1, -1] }
         let cp = ((b0 - 192) * 64) + (b1 - 128)
         return [cp, 2]
     }
     if b0 < 240 {
         if idx + 3 > n { return [-1, -1] }
-        let b1 = char_code(s.substring(idx + 1, idx + 2))
-        let b2 = char_code(s.substring(idx + 2, idx + 3))
+        let b1 = char_code(s, idx + 1)
+        let b2 = char_code(s, idx + 2)
         if b1 < 128 || b1 >= 192 { return [-1, -1] }
         if b2 < 128 || b2 >= 192 { return [-1, -1] }
         let cp = ((b0 - 224) * 4096) + ((b1 - 128) * 64) + (b2 - 128)
         return [cp, 3]
     }
     if b0 < 248 {
         if idx + 4 > n { return [-1, -1] }
-        let b1 = char_code(s.substring(idx + 1, idx + 2))
-        let b2 = char_code(s.substring(idx + 2, idx + 3))
-        let b3 = char_code(s.substring(idx + 3, idx + 3 + 1))
+        let b1 = char_code(s, idx + 1)
+        let b2 = char_code(s, idx + 2)
+        let b3 = char_code(s, idx + 3)
         if b1 < 128 || b1 >= 192 { return [-1, -1] }
         if b2 < 128 || b2 >= 192 { return [-1, -1] }
         if b3 < 128 || b3 >= 192 { return [-1, -1] }
         let cp = ((b0 - 240) * 262144) + ((b1 - 128) * 4096) + ((b2 - 128) * 64) + (b3 - 128)
         return [cp, 4]
     }
     return [-1, -1]
 }
```

Avoids 4 substring allocations per byte too — small perf win.

## Verify

Build and run on Mac arm64 (the `widetest.hexa` from this trace):

```hexa
use "self/stdlib/term_unicode"
fn main() -> int {
    eprintln(str(char_width_at("한", 0)))         // expect [2, 3]
    eprintln(str(text_width("한국 hello")))        // expect 4 + 1 + 5 = 10
    return 0
}
```

Expected after fix:
```
[2, 3]
10
```

Then rebuild wilson with the updated `~/.hx/bin` toolchain (or
`HEXA_LANG=~/core/hexa-lang`) and verify Korean input renders gap-free.

## Bonus question (separate patch)

The 1-arg vs 2-arg divergence of `char_code` is itself a footgun. Either:
(a) the 1-arg form should be removed (or made an error), or (b) it should
have the SAME semantics as the 2-arg form (read byte 0). The current
behavior — silently returning 0 for non-ASCII — has caused this exact bug
twice (the first time was the original wide-glyph fix in `67b99c13` working
around the symptom rather than the cause). File as a separate `char_code`
API hardening patch.

## Related

- `67b99c13` — first wide-glyph fix (correct in spirit but inert because
  the `w` it consumes was always 1 for wide chars due to this _u8_decode
  bug).
- `inbox/patches/self-tui-render-wide-to-narrow-ghost.md` — filed
  earlier in this session as a SUSPECTED root cause. With this _u8_decode
  fix the ghost-cell scenario MAY also be resolved (since `w_back` will
  now correctly be 2 for wide cells, the diff loop will skip continuation
  cells properly). Worth re-checking after _u8_decode fix lands — if the
  symptom persists, the wide-to-narrow patch may still be needed.
- tcell canonical wide-glyph contract: width is the SOURCE OF TRUTH; if
  the width table is wrong, everything else compounds.
