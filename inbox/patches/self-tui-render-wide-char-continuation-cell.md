# incoming patch: self-tui-render-wide-char-continuation-cell

> **id**: `self-tui-render-wide-char-continuation-cell` · **opened**: 2026-05-12 · **status**: `applied` (2026-05-12, same session — user said "hexa-lang upstream 개선 바로진행", so the fix landed directly in `self/tui/render.hexa` + `self/tui/widget/text.hexa` rather than waiting for an upstream pickup)
> **trees**: `self/tui/render.hexa` (L3 diff renderer) + `self/tui/widget/text.hexa` (L4 widget; current workaround that interacts badly with the bug)
> **why**: any CJK / emoji content in a `self/tui/render`-based TUI displays with a visible 1-cell gap *after every wide glyph* (e.g. Korean `완벽` → `완 벽`, model reply `메시지가` → `메 시 지 가`). Reported from wilson's `harness-cli`; reproducible directly via `self/tui/widget/text::text_draw` on any East-Asian-Wide string.

---

## Observed (2026-05-12, wilson harness-cli on macOS Terminal.app, Apple SF Mono, arm64)

User input: `완벽 dfmkfdsakm m완벽 완벽` (Korean syllables + ASCII)

Visual output (from screenshot):
```
> 완 벽 dfmkfdsakm m완 벽  완 벽 ...
```

Every Hangul Syllable (U+AC00..U+D7A3, EAW=Wide) has a stray space *to its right*. ASCII renders perfectly. Same effect on model scrollback (model writes `메시지가 잘 표시되지 않습니다` → renders as `메 시 지가 잘  이 해지 않습니다` with characters mis-ordered/dropped because each wide glyph cascades a 1-col mis-alignment downstream).

Confirmed not a font/terminal-EAW-mode issue: Apple Terminal + SF Mono renders standalone Korean (e.g. echo'd directly to stdout) at the correct 2-cell width. The mis-render only happens when content goes through `self/tui/render`'s back/front diff loop.

## Root cause (traced)

`self/tui/widget/text::text_draw` correctly recognizes a width-2 glyph and paints **two cells**: the glyph at col N (`render_put(N, y, "완", ...)`), and an empty continuation marker at col N+1 (`render_put(N+1, y, "", ...)`). This matches the "two cells per wide grapheme" convention.

But `self/tui/render::render_flush`'s diff loop tracks `last_x` as the **cell-grid x of the last write**, and uses `x == last_x + 1` to decide "adjacent to last write → skip CSI cursor reposition". This is correct for width-1 glyphs but wrong for width-2:

```hexa
// render.hexa render_flush(), lines ~210-247
while x < _cols {
    let idx = _cell_idx(x, y)
    if !_cell_eq(_front[idx], _back[idx]) {
        if y != last_y || x != last_x + 1 {
            // emit CSI ESC [<y+1>;<x+1>H  (reposition)
        }
        // emit b_cell[0] (or " " if "")
        last_x = x       // <-- BUG: advances by cell-grid step (1),
        last_y = y       //         not by terminal-cursor step (1 or 2)
    }
    x = x + 1
}
```

Trace for `text_draw(0, 0, "> 완벽", ...)` on a freshly-cleared row (front = all blank cells `["", -1, -1, 0]`):

| cell x | back ch  | front ch | diff? | emit                   | terminal cursor after |
|--------|----------|----------|-------|------------------------|-----------------------|
| 0      | `>`      | `""`     | yes   | CSI(0,0), `>`          | col 1                 |
| 1      | ` `      | `""`     | yes   | `" "` (adjacent)       | col 2                 |
| 2      | `완`     | `""`     | yes   | `완` (adjacent)        | **col 4** (wide!)     |
| 3      | `""`     | `""`     | no    | —                      | col 4                 |
| 4      | `벽`     | `""`     | yes   | `벽` (`last_x+1 == 4`) | **col 6** (wide!)     |
| 5      | `""`     | `""`     | no    | —                      | col 6                 |

Wait — that trace would actually work. Let me re-check. The bug is **on the second frame**, when `_front` already holds the wide glyph from the prior frame, and the back buffer paints the same glyph + extends with a new one. The continuation cell at col 3 is `""` in both, so it's not diffed, but the wide glyph at col 4 IS diffed:

| cell x | front ch | back ch  | diff? | emit                                       | terminal cursor               |
|--------|----------|----------|-------|--------------------------------------------|-------------------------------|
| 0..2   | (synced) | (same)   | no    | —                                          | (no writes — last_x=-2)       |
| 3      | `""`     | `""`     | no    | —                                          | —                             |
| 4      | `""`     | `벽`     | yes   | `last_x+1` is `-1` ≠ 4 → CSI(4,0), `벽`    | col 6                         |
| 5      | `""`     | `""`     | no    | —                                          | col 6                         |

OK first-frame and incremental-frame cases both look fine on paper. Where IS the gap coming from?

Let me re-look at `_cell_eq`:

```hexa
// (line ~375) — typically compares all 4 fields
fn _cell_eq(a: array, b: array) -> bool {
    return a[0] == b[0] && a[1] == b[1] && a[2] == b[2] && a[3] == b[3]
}
```

`_blank_cell()` returns `["", -1, -1, 0]`. `text_draw` paints the continuation with `render_put(N+1, y, "", fg, bg, attrs)` — using the **caller's fg/bg/attrs**, not the blank defaults. So after `text_draw(0, 0, "완", 80, -1, -1, 0)` the cell at col 1 has `["", -1, -1, 0]` — same as blank → not diffed. ✓

But `harness_cli_paint_frame` calls `text_draw` with **non-default attrs in places** — e.g. dim (attrs=8) for the streaming row, bold (attrs=1) for the header row. If a wide glyph lands in the header, its continuation cell has `["", -1, -1, 1]` (bold) — **different** from `_blank_cell()` `["", -1, -1, 0]`. Now the continuation cell IS in the diff, and gets emitted as `" "` adjacent to the wide glyph → terminal writes space at col N+2 (wide glyph already advanced cursor there), overwriting the next cell's left half.

Trace for `text_draw(0, 0, "> 완벽", w=80, fg=-1, bg=-1, attrs=1)` on a freshly-cleared row:

| cell x | back                    | front (blank)        | diff? | emit                                                     | term cursor      |
|--------|-------------------------|----------------------|-------|----------------------------------------------------------|------------------|
| 0      | `[">", -1, -1, 1]`      | `["", -1, -1, 0]`    | yes   | CSI(0,0), SGR bold, `>`                                  | col 1            |
| 1      | `[" ", -1, -1, 1]`      | `["", -1, -1, 0]`    | yes   | `" "` (adjacent)                                         | col 2            |
| 2      | `["완", -1, -1, 1]`     | `["", -1, -1, 0]`    | yes   | `완` (adjacent)                                          | **col 4**        |
| 3      | `["", -1, -1, 1]`       | `["", -1, -1, 0]`    | yes   | `" "` (adjacent — `last_x+1 == 3`)                       | **col 5**        |
| 4      | `["벽", -1, -1, 1]`     | `["", -1, -1, 0]`    | yes   | `벽` (adjacent — `last_x+1 == 4`)                        | **col 7**        |
| 5      | `["", -1, -1, 1]`       | `["", -1, -1, 0]`    | yes   | `" "` (adjacent)                                         | col 8            |

Visual at terminal cols: `0:">",  1:" ",  2-3:"완",  4:" ",  5-6:"벽",  7:" "`

→ `> 완 벽 ` — **gap of one space between 완 and 벽**. Exactly the observed bug.

So the bug surfaces whenever **the back cell's `attrs/fg/bg` for the continuation differs from `_blank_cell()`'s defaults**, which happens for any non-default-styled `text_draw` call (bold header row, dim status row, etc.). For attrs=0 + default fg/bg (e.g. wilson's input/scrollback rows) the continuation cell *coincidentally* matches `_blank_cell()` and the bug stays silent — but as soon as the user types into the input row with any styling, the bug surfaces. (Plus first-paint always hits it because front is all `_blank_cell()` but back has the caller's attrs.)

## Canonical fix (tcell's approach)

Per tcell's `tscreen.go::draw()`: in the diff loop, **skip the continuation cell entirely** (`x += width - 1`), and advance the cursor tracker by the **display width** (1 or 2), not by the cell-grid step. The continuation cell is a no-op — never emitted, never diffed.

Concretely for `self/tui/render::render_flush`:

```hexa
// Add at top of file:
use "self/stdlib/term_unicode"   // is_east_asian_wide / cp_width / char_width_at

// In the diff loop:
while x < _cols {
    let idx = _cell_idx(x, y)
    let f_cell = _front[idx]
    let b_cell = _back[idx]
    let ch = b_cell[0]
    let w = if ch == "" { 1 } else {
        let cw = char_width_at(ch, 0)[0]
        if cw < 1 { 1 } else { cw }       // negative width → treat as 1
    }
    if !_cell_eq(f_cell, b_cell) {
        if y != last_y || x != last_x + 1 {
            // CSI reposition
        }
        // SGR update + emit ch (or " " if "")
        // ...
        last_x = x + w - 1                // <- KEY: terminal cursor after this write
        last_y = y                        //         lands `w-1` cells beyond cell-grid x
        changed = changed + 1
    }
    // Continuation cell (cell-grid x+1 for a width-2 glyph) is skipped:
    // text_draw paints it as "" + the caller's attrs, but the terminal already
    // owns that column from the wide-glyph emission. Per tcell's contract:
    // "If a second character is displayed immediately in the cell adjacent
    // to a wide character (offset by one instead of by two), then the
    // results are undefined."
    x = x + w
}
```

And `self/tui/widget/text::text_draw` should stop writing the continuation cell — let it remain at whatever `render_clear` last set it to (`_blank_cell()`). The current contrast — paint continuation with caller's attrs so previous-frame leakage is overwritten — is no longer needed because the diff loop now skips that cell entirely.

```hexa
// text.hexa _utf8_step loop, currently:
if width == 2 && col + 1 < w {
    let r = render_put(x + col, y, glyph, fg, bg, attrs)
    if r == 0 { count = count + 1 }
    let r2 = render_put(x + col + 1, y, "", fg, bg, attrs)   // <- DELETE
    if r2 == 0 { count = count + 1 }                          // <- DELETE
    col = col + 2
}
// becomes:
if width == 2 && col + 1 < w {
    let r = render_put(x + col, y, glyph, fg, bg, attrs)
    if r == 0 { count = count + 1 }
    col = col + 2          // skip continuation; render's diff loop owns it
}
```

(Equivalent fix: keep the continuation `render_put` but normalize its attrs to `_blank_cell()` so it never diffs. The skip-in-flush version is preferred — single source of truth, no implicit coupling between text.hexa attrs choice and render.hexa diff behavior.)

## Selftest to add (verifies the fix)

`self/tui/render.hexa::_selftest` (or a new `self/tui/widget/text::text_selftest` case):

1. `render_init()`, `render_clear()`.
2. `text_draw(0, 0, "ab한글cd", 80, 196, -1, 1)`   // bold + red — non-default attrs (the trigger condition)
3. `render_flush()` — capture the emitted bytes.
4. Assert the emitted byte stream contains:
   - `a` at col 0
   - `b` at col 1
   - `한` at col 2 (no intervening `" "` between `b` and `한`)
   - `글` immediately after `한` (no intervening `" "` between `한` and `글`)
   - `c` immediately after `글`
   - `d` at col 7
5. Assert NO `CSI 1;<n>H` reposition mid-row (the diff loop should run as a single adjacent burst).

## Once fixed — what unblocks (wilson side)

- wilson's `harness-cli` displays Korean / CJK / emoji correctly in the input line AND scrollback / streaming rows AND header — no gaps, no mis-ordering. Closes the `AGENTS.md` "char-boundary cursor" P1 follow-up (visual width axis; the editing axis was already codepoint-aware via `harness_cli_char_boundaries`).
- wilson can drop the cell-based truncate/wrap helpers added in commit `e297e33` ONLY for layout correctness — the fix is at the renderer layer where it belongs (those helpers still make sense for *byte vs cell* slicing logic — they don't go away, they just become harness-side display-width math rather than a workaround for a renderer bug).

## Notes

- `self/stdlib/term_unicode` already ships `is_east_asian_wide(cp)` + `cp_width(cp)` + `char_width_at(s, idx)` — render.hexa needs to import this stdlib module (no cycle: render is L3, term_unicode is stdlib/L1). `text.hexa` already has its own local `_unicode_width` table; consider consolidating to `term_unicode` in the same change to avoid two divergent tables.
- Apple Terminal + SF Mono / Menlo render Hangul Syllables at the correct EAW=2 cells — this bug is **not** a font/terminal issue. Same effect should reproduce on iTerm2, Ghostty, Kitty, Alacritty.
- tcell reference: https://pkg.go.dev/github.com/gdamore/tcell/v2 — "If a second character is displayed immediately in the cell adjacent to a wide character (offset by one instead of by two), then the results are undefined."
- UAX #11 East Asian Width: https://www.unicode.org/reports/tr11/tr11-40.html
