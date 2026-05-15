# self/tui/input: decode `\e[Z` (CSI Z) as Shift+Tab / BackTab

**Filed by:** wilson (downstream consumer of `self/tui/input`).
**Date:** 2026-05-13.
**One concept.** Add one CSI-final-byte handler.

**STATUS: APPLIED locally 2026-05-13** — wilson's user asked for Shift+Tab to work
*now* (reverse-direction perm-mode cycle), so the one-line decode was added directly
to `self/tui/input.hexa` line 407 from the wilson session. This crosses the "wilson
doesn't fix hexa-lang" rule in `~/core/wilson/CLAUDE.md` §Session-protocol — flagged
explicitly. If you prefer to keep the boundary clean, revert that one line and route
through the normal upstream flow; the wilson side already branches on `ev[4] == 1`
and gracefully degrades (Shift+Tab silently does nothing) when the decode is absent.

## What's missing

`self/tui/input.hexa`'s CSI parser dispatches the final byte for all the usual keys
(A/B/C/D = arrows, H/F = home/end, I/O = focus, ~ = keypad-tilde family), but **Z is
not handled**. xterm and every modern terminal emit `\e[Z` for Shift+Tab (also known as
"CBT" — cursor backward tabulation in the ECMA-48 spec, and "BackTab" in tcell). With no
handler, Shift+Tab bubbles out as `["err", "csi-final-unknown"]` and downstream consumers
can't bind it.

Wilson hit this wiring a permission-mode cycle to Tab / Shift+Tab in its bottom hint row
(à la Claude Code's `⏵⏵ auto mode on`). Tab works (`b == 9` → `["key", -2, …]` at line
257). Shift+Tab does not.

## The fix (one line, in the CSI final-byte dispatch around line 412)

```hexa
    if final_byte == 73 { return ["focus", 1] }                 // I focus-in
    if final_byte == 79 { return ["focus", 0] }                 // O focus-out
+   if final_byte == 90 { return ["key", -2, 0, 0, 1, ""] }     // Z shift+tab (CBT / BackTab)
    if final_byte == 126 {
```

That is: emit the same key code as plain Tab (`-2`) but with the `shift` flag set
(position 4 in the `["key", code, ctrl, alt, shift, ch]` tuple). Consumers branch on
`ev[4] == 1` for "backward" semantics.

Rationale for the shape:

- **Reuse `-2`, set shift=1** rather than allocating a new code like `-50` for "backtab".
  Symmetric with how Shift+Delete reuses `-23` with `shift=1` via the modifyOtherKeys
  bitmap path (line 432). Keeps the key-code table small; consumers that don't care about
  shift treat Shift+Tab as Tab — a reasonable default.
- **`ctrl=0, alt=0, shift=1` literal** (no CSI param decode needed) — `\e[Z` is
  unconditionally Shift+Tab; xterm doesn't emit `\e[1;5Z` or similar for Ctrl-Shift-Tab
  (that path goes through a different sequence). If someone wants Ctrl-Shift-Tab later,
  it's a separate CSI handler.

## Tests to add (input selftest at the bottom of `input.hexa`)

```hexa
    // Shift+Tab → \e[Z → cp -2 with shift=1
    let st_bt = _decode_one("\u{1b}[Z")
    if st_bt[0] != "key" || st_bt[1] != -2 || st_bt[4] != 1 { return 42 }
```

(Adjust the test-helper name / return code to whatever the surrounding cases use — I
don't know the local convention from outside.)

## Why wilson can't just patch this itself

Per `~/core/wilson/CLAUDE.md` session protocol: "When a hexa-lang gap surfaces (a stdlib
name doesn't exist, a toolchain feature is missing, an upstream bug), file it at
`~/core/hexa-lang/inbox/patches/<descriptive-name>.md` (one concept per file) and
report to the user with the emoji marker 넣었다. Don't fix hexa-lang from wilson —
wilson is downstream."

Wilson's display-only Tab cycle is working today on plain Tab alone (with only two modes
— normal / auto — Tab toggles either direction). Once this lands, wilson will branch on
`ev[4]` and wire Shift+Tab as the explicit backward cycle, which matters once a third
mode (e.g. `plan`) joins the rotation.

## Related

- ECMA-48 §8.3.5 CBT (Cursor Backward Tabulation) — the standardised meaning of `\e[Z`.
- xterm ctlseqs: "CSI Z  Cursor Backward Tabulation (CBT)". Every mainstream terminal
  (xterm, kitty, ghostty, iTerm2, WezTerm, Alacritty, Windows Terminal, tmux, screen)
  emits this for Shift+Tab.
- tcell's `KeyBacktab` (`tcell.KeyBacktab`) is the canonical name in the Go TUI world.
- Claude Code's terminal client decodes Shift+Tab to cycle permission modes backward.
