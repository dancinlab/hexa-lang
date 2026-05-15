# L2 input decoder: Shift+Enter / Alt+Enter for multi-line input

## Symptom

Wilson's `harness-cli` chat editor uses cp == -1 (Enter) to submit a line.
There was no way to insert a literal newline (`\n`) into the input buffer —
pressing Enter always submitted. Users running wilson in iTerm2 / VS Code /
Cursor with claude-code's terminal-setup keybinding active (Shift+Enter →
`\r`) would see the ESC+CR sequence decoded as bare ESC (`["key", -4,
0, 0, 0, ""]`) instead of as Enter+alt.

## Background

claude-code distinguishes three ways to insert a newline:

1. **Shift+Enter via terminal config** — iTerm2 / VS Code / Cursor / Windsurf
   are configured (one-time `/terminal-setup`) to send ESC+CR (`\r`)
   when the user presses Shift+Enter. The app parses ESC+CR as Alt+Enter
   (meta+return) and inserts a newline.
2. **CSI u kitty keyboard protocol** — terminals with the kitty keyboard
   protocol enabled (ghostty / kitty / WezTerm / recent iTerm2) send
   `ESC[13;2u` for Shift+Enter directly (no terminal-side keybinding needed).
3. **Backslash + Enter** — typing `\` immediately before pressing Enter
   rewrites the trailing `\` as `\n` and treats the keystroke as a newline.
   The portable fallback that works on ANY terminal without config.

The L2 input decoder previously handled only `ESC + printable ASCII` (→
alt-modifier) and `ESC + 0x7F/0x08` (→ alt-backspace). ESC+CR / ESC+LF and
CSI u were not parsed — both fell through to `["key", -4, 0, 0, 0, ""]`
(bare ESC).

## Fix

Two small additions to `self/tui/input.hexa`:

1. After the alt-backspace branch in `_decode_one`, handle `ESC + 0x0D` (CR)
   and `ESC + 0x0A` (LF) → emit `["key", -1, 0, 1, 0, ""]` (Enter with
   alt=1). This covers Shift+Enter via the claude-code terminal-setup
   convention and Alt+Enter on emulators that send ESC-prefixed Enter.

2. In `_csi_final_to_event`, decode final byte `u` (117) as the kitty
   keyboard protocol's CSI u sequence: `ESC[<codepoint>;<modifier>u`. We
   decode cp 13 (Enter) with modifier flags into `["key", -1, ctrl, alt,
   shift, ""]`. Other codepoints fall through as
   `["err", "csi-u-unsupported-cp"]` for now (will expand as needed).

Wilson's `plugins/harness-cli/main.hexa` branches on the alt/shift flag at
the cp == -1 site to insert `\n` instead of submitting, and also supports
the backslash+Enter portable fallback at the editor layer.

## Test

ad-hoc keypress decode:
- ESC+CR (bytes `1B 0D`)         → `["key", -1, 0, 1, 0, ""]`  (was `["key", -4, 0, 0, 0, ""]`)
- ESC+LF (bytes `1B 0A`)         → `["key", -1, 0, 1, 0, ""]`
- `ESC[13;2u` (kitty Shift+Enter) → `["key", -1, 0, 0, 1, ""]`
- `ESC[13;3u` (kitty Alt+Enter)   → `["key", -1, 0, 1, 0, ""]`
- Plain CR (`0D`)                → `["key", -1, 0, 0, 0, ""]` (unchanged)
- Plain LF (`0A`)                → `["key", -1, 0, 0, 0, ""]` (unchanged)

Wilson smoke: `wilson` interactive → type some text, press Shift+Enter
(terminal must be configured per claude-code's terminal-setup, OR be a
kitty-protocol terminal), confirm input buffer gains a `\n` and the editor
expands vertically; press Enter to submit.

## Why land it in `self/tui/input.hexa`

This is L2 input-decoder territory — terminal byte sequences → structured
key events. The same shape as the earlier `Z shift+tab (CBT / BackTab)`
addition (line 407, marked `wilson 2026-05-13`). Wilson is the only
downstream today that needs Shift+Enter for multi-line input, but the
addition is generic enough that any future hexa-native TUI would benefit.
