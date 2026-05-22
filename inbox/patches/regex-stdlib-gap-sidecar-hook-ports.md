# regex — no string-pattern stdlib; downstream hook/lint ports hand-roll token scans

> **Status:** regex part RESOLVED 2026-05-22 — `stdlib/regex.hexa` landed (restricted engine, position-set NFA simulation — no backtracking blowup; `regex_test` / `regex_find` / `regex_match`; `stdlib/regex_test.hexa` 32/32). XML part still OPEN (see Related).
> Filed 2026-05-22 by sidecar during the `.py` → `.hexa` hook-plugin migration.

**From:** sidecar (downstream consumer)
**Sister files:** sidecar `hooks/{tape-lint,git-guard,hexa-native,pool-route,sidecar-lint}/bin/_*.hexa`

## Problem (one concept)

hexa has no regex / string-pattern matching facility in stdlib. `hexa --help` lists no regex verb; `stdlib/` carries no `regex.hexa`. Text-pattern logic must be hand-written from `substring` / `index_of` / `char_code` primitives.

## Symptom (downstream)

sidecar ported all 5 of its Claude Code hook plugins from Python to hexa. Every one used Python's `re` module for what is the plugin's core logic:

- **git-guard** — 3 force-push patterns (`\bgit\s+push\b[^\n]*\s(-f|--force)\b`, `--force-with-lease`, refspec `+<ref>`).
- **sidecar-lint** — a 7-alternative stale-history regex (`removed in \d+\.\d+` | `replaces …` | `archived 20\d\d-\d\d-\d\d` | …), a hardcoded-path regex `(?:/Users|/home)/[\w.-]+/`, and `git commit` command detection.
- **tape-lint** — `@D` block-header / indented-field / quoted-value extraction.
- **pool-route** — `\b(swift|xcodebuild|xcrun|pod\s+install)\b` and `\b(nvidia-smi|nvcc)\b` word matching.

In the absence of regex each was re-implemented as whitespace tokenizers + char-class predicate functions + manual phrase-then-class scanners — roughly 30–80 extra LOC per hook. The hand-rolls only *approximate* the original regex semantics (`\b` word boundaries, alternation, quantifiers), so behavior fidelity depends on per-case review rather than a shared, tested engine.

Per commons `g11` this is not a workaround-able gap — every downstream consumer that parses text re-implements the same primitives independently.

## Ask

Add a minimal regex (or restricted pattern) facility to hexa stdlib. A non-backtracking engine (RE2-style — literal · char-class · `*` `+` `?` · alternation · anchors · `\b`) fits hexa's native-compiled, no-surprise-blowup posture. Suggested surface:

```
stdlib/regex.hexa  ->  regex_match(pattern: string, text: string) -> bool
                       regex_find(pattern: string, text: string) -> array   // [start, end] or []
                       regex_find_all(pattern: string, text: string) -> array
```

Even the restricted subset would let hook / lint / CLI code stop hand-rolling scanners and converge on one tested implementation.

## Related gaps (same migration)

- `json-parse-uXXXX-raw-passthrough.md` — `json_parse` leaves `\uXXXX` escapes literal (already filed). Not a blocker for Claude Code hook payloads (raw UTF-8), but is for general JSON.
- **XML** — stdlib has no XML parser. This blocks porting sidecar's `skills/research` arxiv / yt scripts (arXiv Atom feed + YouTube caption-track XML). Lower priority than regex; recorded here as a pointer rather than a separate patch.
