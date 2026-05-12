# self/tui/input.hexa — `input_init` never enables bracketed-paste mode

## Symptom

Every hexa TUI program that uses `self/tui/input` ships with a broken paste
story:

- Without DECSET 2004 (`ESC [ ? 2004 h`), modern terminals (Ghostty, iTerm2,
  Terminal.app, kitty, alacritty) send pasted bytes as raw keystrokes —
  every newline is delivered as Enter.
- Wilson's harness-cli (single-line submit-on-Enter) therefore submits each
  pasted line as its own command. A 3000-line paste = 3000 forced turns,
  one per line, the rest dumped as garbage keystrokes.
- The bracketed-paste decoder (`_decode_in_paste`, `_paste_active`) that
  already exists in `self/tui/input.hexa` lines 209-516 is therefore
  *dead code* on a fresh-out-of-the-box TUI — nothing ever triggers the
  `ESC [ 200 ~` begin sequence because the terminal isn't sending it.
- Bonus: Ghostty's `clipboard-paste-protection = true` (default) shows a
  warning dialog ("Pasting this text may be dangerous") for clipboard
  content with newlines, *because the receiver hasn't opted into
  bracketed paste*. Opt-in → no dialog.

## Fix

`self/tui/input.hexa::input_init` should pair `term_raw_enter` with a DECSET
2004 emit. `input_close` should pair the DECRST.

```hexa
pub fn input_init() -> int {
    if _input_initialized == 1 { return 0 }
    let r = term_raw_enter()
    if r != 0 { return -1 }
    let _bp = term_write_str(chr(27) + "[?2004h")    // bracketed paste ON
    let _sw = term_install_sigwinch()
    let _si = term_install_sigint()
    _input_initialized = 1
    return 0
}

pub fn input_close() -> int {
    if _input_initialized == 0 { return 0 }
    let _bp = term_write_str(chr(27) + "[?2004l")    // bracketed paste OFF
    let r = term_raw_restore()
    _input_initialized = 0
    _paste_active = 0
    _paste_buf = ""
    return r
}
```

This is the right home — every downstream TUI (wilson now, plus future
ones) gets it for free, and `_decode_in_paste` becomes reachable as
originally intended.

## Why not fix in wilson alone (wilson is doing it for now)

Wilson currently emits the DECSET / DECRST itself from
`plugins/harness-cli/main.hexa::harness_cli_tui_draw` and the
`render_leave_alt_screen` paths. That works but:

- It duplicates terminal-control responsibility outside the TUI input
  module.
- Every other hexa TUI (including hexa-lang's own samples) will hit the
  same bug.
- The natural pairing is `term_raw_enter` ↔ DECSET 2004 — both protect the
  *input* contract, both belong to `input_init`.

## Repro

```sh
# build any tiny hexa-tui app that does input_init + a key-event loop,
# without the DECSET 2004 workaround.

# In Ghostty: paste a 3-line block. Each line submits as a separate Enter.
# Bracketed-paste-only kind=="paste" events never fire.

# Apply the patch above to input.hexa, rebuild the toolchain, redo:
# Now the same paste arrives as a single ["paste", "<all 3 lines>"] event.
```

## Related

- Wilson session `docs/sessions/2026-05-12-paste-placeholder.md` —
  documents the wilson-side workaround and the user-visible symptom
  (3390-line paste failing to placeholder-ize).
- Sibling patch `tui-input-paste-buf-quadratic.md` — once DECSET 2004 is
  on, the receiving `_decode_in_paste` loop becomes hot — and its
  byte-by-byte string concat is O(n²) for large pastes.
