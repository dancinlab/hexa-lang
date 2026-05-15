# self/lexer: make `tokenize` pub for downstream consumers

**Filed by:** wilson (downstream consumer of `self/lexer`).
**Date:** 2026-05-13.
**One concept.** Change one keyword.

**STATUS: APPLIED locally 2026-05-13** — wilson is wiring hexa-lang syntax
highlighting into its TUI scrollback (`plugins/harness-cli/main.hexa`,
markdown-fenced ` ```hexa ` blocks). To call `self/lexer.tokenize(source)` from
outside the module, the fn needs `pub`. Applied directly so wilson's build picks
it up; flagged here for upstream review.

## The change (one keyword, line 135 of `self/lexer.hexa`)

```diff
- fn tokenize(source) {
+ pub fn tokenize(source) {
```

That's it. The helpers `is_keyword`, `keyword_kind`, `is_ident_start`, etc. stay
module-private — wilson doesn't need them; it just consumes the Token stream
`tokenize` returns.

## Why wilson needs it

Wilson's harness-cli renders assistant chat output and detects markdown code
fences. For `` ```hexa `` blocks it wants per-token colours (keywords blue,
strings orange, numbers mint, etc., matching the VS Code "Visual Studio Dark
(C/C++)" theme — see `~/core/wilson/docs/THEME.md`). The first thing that
needs to be callable from outside `self/lexer` is the entry point.

## Token-stream observation (wilson-side note, not part of the patch)

The lexer **skips** `// line` and `/* block */` comments — they're consumed by
the pos cursor but never emitted as tokens. That's fine for wilson's purpose:
wilson does its own pre-pass to find `//` on a line and paints from that
column onward in `harness_cli_COMMENT` (`#6A9955`), then lexes the non-comment
prefix for the regular token stream. Block comments are punted to a follow-up
(per-line lex can't see them spanning lines anyway). If upstream wants to
preserve `Comment` tokens later, fine — wilson's pre-pass becomes redundant
but doesn't break.

## Related

- The other lexer scope-name notes are documented downstream in
  `~/core/wilson/docs/THEME.md` (VS Dark colour table) — they're consumer
  policy, not upstream concerns.
