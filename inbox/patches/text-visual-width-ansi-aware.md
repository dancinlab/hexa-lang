# patch: text-visual-width-ansi-aware

_status: applied · added: 2026-05-16 · branch: fix/text-visual-width-ansi (off main)_

## Problem

`self/tui/widget/text.hexa::text_visual_width(s)` summed per-codepoint
display width but had **no terminal-escape awareness** — every byte of an
embedded escape sequence (`ESC[38;2;R;G;Bm`, OSC-8 hyperlinks, the wilson
`ESC _wilson:c BEL` cursor marker, …) was counted as **1 display cell**.

This is the long-standing "escape-byte width trap": any downstream caller
that passes an SGR/OSC/APC-styled string into `text_visual_width` for
cursor / soft-wrap / column math gets a width inflated by the (invisible)
escape byte count → the row is treated as wider than it renders → the
terminal auto-wraps mid-line → the caller's cursor-row model desyncs →
frame corruption.

Downstream proof points (wilson, the only consumer — see below):
- `CURSOR_MARKER` (`ESC _wilson:c BEL`, 11 bytes, 0 display cells) — wilson
  had to "wrap the unmarked row first, then inject the marker" as a
  workaround (`@n11`).
- long-input soft-wrap frame corruption — wilson regression test
  `TUI-TEST.tape s57`.
- blocked the planned full-width-background diff renderer (claude-code
  UI/UX parity P3): bg bars require padding to `cols` then SGR-wrapping,
  which is exactly the trap.

## Fix

In-place, `self/tui/widget/text.hexa`:

- new `fn _skip_escape(s, i, n) -> int` — given `s[i] == 0x1B`, returns the
  index just past the escape sequence. Handles CSI (`ESC [` … final byte
  `0x40–0x7E`), OSC/APC/DCS/PM/SOS (`ESC ] | _ | P | ^ | X` … `BEL` or
  `ST = ESC \`), and 2-byte `ESC <c>`.
- `text_visual_width` now skips a sequence (zero width) when
  `char_code(s, i) == 27`; all other paths (valid codepoint width,
  invalid-utf8 = 1 cell) unchanged.
- `text_selftest()` gains assertions 18–21 (CSI / APC-cursor-marker /
  OSC-8 / bare-CJK-unaffected), built with `chr(27)` / `chr(7)` (same
  idiom as sibling `self/tui/render.hexa`).

## Files affected

- `self/tui/widget/text.hexa` — `_skip_escape` + `text_visual_width` +
  `text_selftest` (one file, additive; no signature change).

## Downstream consumers

`grep -rn 'text_visual_width(' self/ stdlib/` → **zero hexa-lang internal
consumers**. The only caller anywhere is **wilson**
(`~/core/wilson/plugins/harness-cli/main.hexa`, ~3 call sites). Therefore
the in-place change has **zero blast radius inside hexa-lang** and wilson
needs **zero call-site edits** — the fix propagates on rebuild. It also
retroactively de-risks wilson's CURSOR_MARKER + soft-wrap workarounds
(they become harmless belt-and-suspenders, not removed here — scope).

## Verification

- `hexa parse self/tui/widget/text.hexa` → clean.
- `text_selftest()` assertions 18–21 (escape-aware width) — `chr`-built
  fixtures; runs under hexa-lang's tui selftest harness.
- wilson rebuilt with `HEXA_LANG=<this worktree>`: `wilson test` 23/23 +
  `wilson test --tape` s41 (Home/End decoder) + s57 (long-input
  soft-wrap) must stay PASS (the exact trap regression tests). tmux smoke
  — no frame corruption.

## g7 cross-ref

Filed per AGENTS.tape g7 (cross-project-handoff-via-inbox): wilson is the
downstream consumer; this is the upstream root-cause fix. Wilson commit
references this patch slug for discoverability. Direct upstream fix done
in the same session (governance #7 — inbox note + surgical fix, not
silent).
