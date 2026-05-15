# CSI u (kitty keyboard protocol) decoder only handles Enter — every other modifier-key combo errors

**Layer:** `self/tui/input.hexa` — L2 input decode
**File:** `self/tui/input.hexa:418-436`
**Symptom:** When `ESC[>1u` (kitty kbd protocol flag 1 — "Disambiguate escape codes") is pushed,
modern terminals (Kitty / Ghostty / WezTerm / iTerm2 with proto enabled) send modifier+letter
keystrokes as CSI u sequences (`ESC[<codepoint>;<modifier>u`) instead of raw control bytes.
Wilson's harness-cli enables this protocol for Shift+Enter support, then immediately loses every
other Ctrl/Alt-letter combination because the decoder gives up on everything except Enter.

## Repro

```
wilson                                  # interactive TUI inside iTerm2 / Ghostty / Kitty
type 'hello'                            # any text
press Ctrl-C                            # expected: wilson exits
                                        # actual:   nothing happens — event silently dropped
```

## Bytes on the wire (Ctrl+C, iTerm2 with kitty kbd protocol push)

```
ESC [ 99 ; 5 u
```

- `99` = ASCII 'c'
- `5` = modifier (1 + ctrl=4)

## Current decoder (`self/tui/input.hexa:418-436`)

```hexa
if final_byte == 117 {
    // CSI u — kitty keyboard protocol: ESC[<codepoint>;<modifier>u
    ...
    if _u_cp == 13 { return ["key", -1, _u_ctrl, _u_alt, _u_shift, ""] }   // Enter ONLY
    return ["err", "csi-u-unsupported-cp"]
}
```

Only Enter (codepoint 13) is decoded. Every other codepoint — Ctrl+letter, Alt+letter,
Tab+modifiers, Esc+modifiers, etc — returns `["err", "csi-u-unsupported-cp"]`. Downstream
event loops typically drop `["err", ...]` events, so the keystroke is invisible to the app.

## Required fix

Extend the CSI u decoder to emit ordinary `["key", cp, ctrl, alt, shift, ch]` events for
every reasonable codepoint, mirroring the raw-mode path at `_decode_one` lines 267-281.

Specifically:

```hexa
if final_byte == 117 {
    let _u_parts = _split_semi(params)
    let _u_cp = if len(_u_parts) > 0 { _atoi(to_string(_u_parts[0])) } else { _atoi(params) }
    let _u_mod = if len(_u_parts) >= 2 { _atoi(to_string(_u_parts[1])) } else { 1 }
    let _u_eff = if _u_mod <= 1 { 0 } else { _u_mod - 1 }
    let _u_shift = if (_u_eff & 1) != 0 { 1 } else { 0 }
    let _u_alt   = if (_u_eff & 2) != 0 { 1 } else { 0 }
    let _u_ctrl  = if (_u_eff & 4) != 0 { 1 } else { 0 }
    // Special keys first (codepoints that don't map to a printable ch).
    if _u_cp == 13  { return ["key", -1, _u_ctrl, _u_alt, _u_shift, ""] }   // Enter
    if _u_cp == 9   { return ["key", -2, _u_ctrl, _u_alt, _u_shift, ""] }   // Tab
    if _u_cp == 127 || _u_cp == 8 {
        return ["key", -3, _u_ctrl, _u_alt, _u_shift, ""]                    // Backspace
    }
    if _u_cp == 27  { return ["key", -4, _u_ctrl, _u_alt, _u_shift, ""] }   // Esc
    // Printable letters / digits / punctuation. ch is chr(cp) for narrow
    // ASCII; for wider codepoints, chr() returns the UTF-8 encoding.
    if _u_cp >= 32 && _u_cp < 0x110000 {
        return ["key", _u_cp, _u_ctrl, _u_alt, _u_shift, chr(_u_cp)]
    }
    // C0 control range (1..31, less the handful above) — Ctrl+letter via
    // CSI u. Map to the lowercase letter code with ctrl=1 so downstream
    // matches the raw-mode encoding (`b + 96` mapping at line 274).
    if _u_cp >= 1 && _u_cp <= 26 {
        let letter = _u_cp + 96
        return ["key", letter, 1, _u_alt, _u_shift, ""]
    }
    return ["err", "csi-u-unsupported-cp"]
}
```

## Why this matters

- **Ctrl+C** (cp=99 mod=5) → exit / cancel turn (the most common keystroke in any TUI agent)
- **Ctrl+D** (cp=100 mod=5) → EOF / quit
- **Ctrl+L** (cp=108 mod=5) → clear screen
- **Ctrl+R** (cp=114 mod=5) → reverse search
- **Alt+Backspace** (cp=127 mod=3) → kill word
- **Esc** (cp=27 mod=1) → cancel / dismiss

All of these are broken under the kitty kbd protocol today. The protocol is push-only —
wilson can't selectively "use kitty kbd for Enter but not for Ctrl+C" — so leaving the
decoder stub-only forces downstream to either:

1. Disable kitty kbd entirely (loses Shift+Enter on modern terminals)
2. Try to detect + workaround per-key (fragile, redundant)

Fixing the decoder upstream solves it for every downstream once.

## Wilson-side workaround (until landed)

`plugins/harness-cli/main.hexa::harness_cli_term_modes_on` — comment out the
`ESC[>1u` push. Ctrl+C then arrives as raw byte 3 → mapped via the regular
`b >= 1 && b <= 26 → cp = b + 96, ctrl = 1` path. Shift+Enter degrades to
ESC+CR (still works via the terminalSetup convention in iTerm2 / VS Code).

## Related

- self/tui/input.hexa:267-281 — the raw-byte Ctrl+letter path (the encoding the CSI u
  branch should mirror)
- self/tui/input.hexa:469-477 — the modifyOtherKeys CSI 27 branch already handles
  printable cps; CSI u is the modern equivalent and should match its breadth
