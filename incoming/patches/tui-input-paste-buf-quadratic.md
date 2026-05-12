# self/tui/input.hexa — `_decode_in_paste` byte-by-byte string concat is O(n²)

## Symptom

A wilson user pastes ~3390 lines (~200 KB) into the harness-cli TUI. The terminal
reports the bracketed-paste `ESC [ 200 ~ ... ESC [ 201 ~` envelope correctly, but
the harness freezes for many seconds before any visible response. From the
user's perspective: "the placeholder doesn't appear quickly — it fails."

wilson's side fix (this commit on the wilson tree) routes pastes through a
side-map + `[Pasted text #N +M lines]` placeholder, so once the `paste` event
arrives, the editor doesn't even strip-or-insert the 200KB. But the `paste`
event itself doesn't arrive until `_decode_in_paste` finishes — and that loop
is what stalls.

## Root cause — `self/tui/input.hexa` ~ line 463-515

```hexa
fn _decode_in_paste(first_byte: int) -> array {
    let mut b = first_byte
    while true {
        if b == 27 {
            // ... close-marker probe ...
            _paste_buf = _paste_buf + _byte_to_str(b) + _byte_to_str(b2) + _byte_to_str(b3) + ...
            return ["none"]
        }
        // Regular paste byte
        _paste_buf = _paste_buf + _byte_to_str(b)
        let np = _poll_stdin(0)
        if np <= 0 { return ["none"] }
        let nb = _read_byte()
        if nb < 0 { return ["err", "paste-read-failed"] }
        b = nb
    }
}
```

Every byte does `_paste_buf = _paste_buf + _byte_to_str(b)`. If hexa-lang's
string `+` allocates a new buffer of size `len(a) + len(b)` and memcpy's both
into it (the typical string-immutable cost), this is O(n²) in the paste size.

For N=200_000 bytes that's ≈ 2×10^10 ops — multiple seconds of wall-clock
freeze on first-paste, scaling linearly with paste size (40 KB → still
sub-second; 200 KB → painful; 1 MB → minutes).

The TUI input is the *only* place hexa-lang itself buffers an unbounded
external byte stream into a single string — every other allocator-heavy
hot path is in user code.

## Fix sketches

Pick one (cheapest first):

### (A) Byte-array accumulator + one final `bytes_to_string`

```hexa
let mut _paste_buf_bytes: [int] = []   // module-level, alongside _paste_buf

fn _decode_in_paste(first_byte: int) -> array {
    // ...
    _paste_buf_bytes.push(b)
    // ...

    // on close:
    let payload = bytes_to_utf8_string(_paste_buf_bytes)
    _paste_buf_bytes = []
    return ["paste", payload]
}
```

This converts the per-byte cost from O(n) (string concat) to O(1) amortized
(array push). The whole loop is then O(n).

Requires: a stdlib `bytes_to_utf8_string([int]) -> string` (or `bytes_join`
on a `[u8]`). If none exists, this is a parallel ask.

### (B) Chunked concatenation — append in O(√n) groups

Drain `_poll_stdin` in inner-loops, building a small string buffer of e.g. 1 KB
between heap-string concats. Cuts the multiplicative constant ~1000× but is
still O(n²) asymptotically.

### (C) Amortized-string-concat language change

If hexa-lang's runtime can be taught that `x = x + y` (where `x` is the only
live reference) can mutate in place via doubling, the loop becomes O(n)
without any source change. Probably the largest blast radius.

## Repro

Inside any wilson interactive session on a real tty:

```sh
# generate a ~200 KB payload
yes "lorem ipsum dolor sit amet consectetur" | head -3500 > /tmp/big.txt

# in wilson:
#   paste the file contents (Cmd-V on macOS / middle-click on X11)
# observe: visible freeze before the placeholder lands
```

With wilson's placeholder fix, the *insert* is now O(1) — but the `_decode_in_paste`
loop runs before the placeholder is even visible. This patch closes the last gap.

## Why not fix in wilson

The buffering happens in hexa-lang's own TUI input module — wilson's plugin
code never sees the bytes until the `["paste", payload]` event is returned.
There is no wilson-side seam to insert.

## Related

- wilson commit (harness-cli/main.hexa) introduces a `[Pasted text #N +M lines]`
  placeholder + side-map so the visible editor stays cheap regardless of paste
  size. That fix is necessary (placeholder is the UX) and complementary
  (responsiveness past the input layer) but does not address the input.hexa
  buffering cost itself.
