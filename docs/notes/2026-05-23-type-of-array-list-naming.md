# `type_of([])` returns `"array"` (not `"list"`) — naming-intuition footgun

**Reporter:** anima · cycle 6/AD (akida_consumer.hexa development)
**Severity:** low — informational, NOT a bug request. Behavior is
consistent; this is a clarity / dev-intuition note.
**Class:** silent-failure-by-naming-intuition (LLM / dev assumes
`"list"` from `[]`, conditional silently misses)

## Observed `type_of` return tags

Verified `hexa 0.1.0-dispatch` darwin/arm64.

| Literal | `type_of(...)` |
| ------- | -------------- |
| `[]`    | `"array"`      |
| `#{}`   | `"map"`        |
| `"x"`   | `"string"`     |
| `42`    | `"int"`        |
| `3.14`  | `"float"`      |
| `true`  | `"bool"`       |

Two intuition-mismatches: `[]` is `"array"` (not `"list"`); `#{}` is
`"map"` (not `"dict"`).

## How this surfaced

anima `akida_consumer.hexa::_ac_spike_ids_len` first checked only
`tag == "list"` and silently returned zero on every input — no error
raised, just an always-false branch. The defensive fix
`tag == "list" || tag == "array"` masked the real signal; a probe was
needed to confirm only `"array"` is ever returned. Same shape of
footgun as `#{}` vs `{}` for dict literals (precedent in anima
`feedback-hexa-lang-syntax-gotchas.md`).

## Suggested clarity action

Recommend **(a) + (c)** as the low-cost pair:

- **(a)** Document the `type_of` return-string table in the language
  reference or as a docstring on `type_of` so canonical tags are
  discoverable without a repro.
- **(b)** Add `"list"` / `"dict"` as accepted aliases on comparison —
  only if hexa-lang already tolerates type-tag aliasing elsewhere.
  Likely **not** worth the inconsistency cost.
- **(c)** One-line entry in the published syntax-gotchas reference:
  ` type_of([])` is `"array"`, `type_of(#{})` is `"map"`.

No `self/` change requested.

## Repro

```hexa
fn main() {
    let xs = []
    println(type_of(xs))   // array
    let d = #{}
    println(type_of(d))    // map
}
```
