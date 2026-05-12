# self/tui/render: clear ghost cells when wide glyph is replaced by narrower content

**Reported via wilson harness-cli (2026-05-12) — Korean / English alternating input shows 1-cell gaps after Korean syllables, even after `67b99c13` ("track terminal cursor by display width — wide-glyph gap") landed.**

## What `67b99c13` fixed

`67b99c13` correctly handles the **forward direction**: when emitting a wide
glyph, `render_flush` now advances `last_x = x + w - 1` and the loop counter
`x = x + w`, so the diff loop skips the wide glyph's continuation cell and
the adjacency check stays correct for the next emission.

`text_draw` no longer paints the continuation cell with caller attrs — it's
left at `_blank_cell()` default. The terminal's own wide-glyph emission owns
both cells (tcell canonical contract).

That fixed the "stray 1-cell gap" symptom when a wide glyph is ADDED to a
previously narrow / blank row.

## The remaining case — wide → narrow replacement leaves a ghost

When a previously-emitted wide glyph at column X (owning visual cells X and
X+1 in the terminal) is REPLACED in the next frame by something narrower
(another wide glyph at a different column, an ASCII char, or blank), the
terminal's right-half pixel data at cell X+1 is NOT cleared automatically:

- macOS Terminal.app, iTerm2, and several others only clear the cell at the
  position the new glyph is written to. The wide glyph's right-half pixels
  at X+1 remain on screen until something else writes to X+1.
- xterm with the `cjk_width` extension and tcell-based apps clear both
  cells when a narrow glyph overwrites a wide-glyph slot — but this is not
  universal.

`render_flush`'s current logic:

```hexa
let f_cell = _front[idx]
let b_cell = _back[idx]
let ch = b_cell[0]
let w = if ch == "" { 1 } else {
    let cw = char_width_at(ch, 0)[0]
    if cw < 1 { 1 } else { cw }
}
if !_cell_eq(f_cell, b_cell) {
    ... emit ...
    last_x = x + w - 1
}
x = x + w
```

…computes `w` from `_back` only. If `_front[X]` was a wide glyph (`f_w = 2`)
and `_back[X]` is narrow (`b_w = 1`), the loop emits the new content at X,
then advances `x = X + 1` — and at X+1 it visits a cell where `_front[X+1]`
was the old wide-glyph's continuation slot (stored as `_blank_cell()`,
matching whatever's in `_back[X+1]` after `render_clear`). `_cell_eq` returns
true → no emit. The terminal's stale right-half stays visible.

**Reproduction (interactive, in wilson):**
1. Type Korean syllable (e.g. `한`) → wide glyph drawn at col 4-5.
2. Backspace → space written at col 4. Most terminals clear col 4-5 here;
   macOS Terminal.app sometimes leaves col 5 partial.
3. Type ASCII `a` then Korean `한` → `a` at col 4, `한` at col 5-6. Now
   col 5 receives `한`'s left half — but the lingering right-half of the
   prior step's `한` at col 5 may have already corrupted the column.

In wilson's actual screenshot, the pattern shows up as `한 글 잉 력` (with
visible 1-cell gaps) when the user alternates between Korean (IME on) and
English (IME off) — likely because the IME toggle causes back-to-back wide
glyph repositioning that exercises the ghost path repeatedly.

## Proposed fix — track front width, clear ghost cells

In `render_flush`, ALSO compute `f_w` from `_front`. When `f_w > w` (front
was wider than back), emit clearing-space at `x + w .. x + f_w - 1`:

```hexa
let f_cell = _front[idx]
let b_cell = _back[idx]
let b_ch = b_cell[0]
let w = if b_ch == "" { 1 } else {
    let cw = char_width_at(b_ch, 0)[0]
    if cw < 1 { 1 } else { cw }
}
let f_ch = f_cell[0]
let f_w = if f_ch == "" { 1 } else {
    let fcw = char_width_at(f_ch, 0)[0]
    if fcw < 1 { 1 } else { fcw }
}
if !_cell_eq(f_cell, b_cell) {
    ... existing emit ...
    last_x = x + w - 1
}
// NEW: if the front was wider than the back, the terminal still shows
// the trailing cells of the old wide glyph. Clear them explicitly.
if f_w > w {
    let mut gx = x + w
    while gx < x + f_w && gx < _cols {
        // Position + space
        if gx != last_x + 1 || y != last_y {
            parts.push(chr(27))
            parts.push("[")
            parts.push(to_string(y + 1))
            parts.push(";")
            parts.push(to_string(gx + 1))
            parts.push("H")
        }
        parts.push(" ")
        last_x = gx
        last_y = y
        gx = gx + 1
    }
}
x = x + w
```

This is the canonical tcell behavior for wide-glyph deletion. It costs an
extra ~5 bytes of ANSI per ghost cell, only when the diff actually replaces
a wide cell with a narrower one — typically rare per frame.

## Verify

Once the fix lands and `hexa_v2` is rebuilt:

1. wilson interactive: type `한a한a` and the inverse, alternating IME on/off.
   Korean should render flush with no gap.
2. wilson interactive: type long Korean line, backspace until empty, type
   again. No stale right-halves.
3. self/tui golden test: add a `render_test_wide_to_narrow_ghost` case that
   emits a wide glyph, then overwrites with a narrow glyph at the same
   position, and verifies the ANSI output includes a clearing space at the
   continuation cell.

## Related

- `67b99c13` — first wide-glyph fix (forward direction)
- `incoming/patches/self-tui-render-wide-char-continuation-cell.md` —
  (applied) the patch trace for `67b99c13`
- `vadimdemedes/ink#752` — Ink 6's "blank row at bottom" regression has
  similar root-cause flavor (continuation-cell handling)
- tcell `Screen.Draw` docs: "if a wide cell is overwritten with a narrow
  character, the next cell is also cleared"
