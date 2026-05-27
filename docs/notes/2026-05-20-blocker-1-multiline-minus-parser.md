# Blocker 1 — Multi-line expression with leading `-` parses broken

**Reporter**: Track B (solar_kernel pilot, kappa-65)
**Filed**: 2026-05-20
**Severity**: HIGH — silent wrong numerics. No clang error, no runtime trap.
**Status**: OPEN — parser fix deferred (not safe within this session).

## Symptom

```hexa
fn declination(jd: float) -> float {
    let t1 = jd_to_jc(jd)
    let t2 = t1 * t1
    let t3 = t2 * t1
    let x = 280.46646 / t1
        - 1.914602 / t2          // <-- silently mis-parsed
        + 0.019993 / t3          // <-- this leading-`+` line is fine
    return x
}
```

The leading-`-` continuation lines are accepted by the parser but are
re-interpreted as **statement-level unary-minus expressions** rather
than continuations of the preceding `let x = ...` binary chain. The
visible `x` ends up holding only the first segment (`280.46646 / t1`);
the `- 1.914602 / t2` becomes a discarded `(-1.914602/t2)` expression
statement and the subsequent `+ 0.019993 / t3` resumes the chain on
whatever node the parser last bound.

Compile succeeds. Runtime returns silently-wrong numbers. Found via a
parity-vs-pvlib check that gave ~degree-scale declination error when
the spec ceiling was milli-degree.

## Repro (minimal)

```hexa
fn main() {
    let a = 10.0
    let b = 5.0
    let c = 2.0
    let x = a
        - b
        + c
    print(x)   // EXPECTED: 7.0 (= 10 - 5 + 2)
               // ACTUAL:   10.0 on stock hexa parser
    return 0
}
```

## Workaround (Track B pilot used this)

Place the continuation operator at the **end** of the preceding line,
not the start of the continuation line:

```hexa
let x = a -
        b +
        c
```

Or keep everything on one line.

## Root cause hypothesis (un-verified)

The parser's statement-vs-expression boundary detection treats a line
starting with `-IDENT` as a fresh statement (unary-minus prefix) rather
than as the right operand of a binary `-`. Leading `+` works because
unary `+` is rarely a separate statement form, so the parser falls
through to the binary-operator continuation branch. Likely fix locus:
`self/parser.hexa` — the same lookahead that handles `+`-continuation
needs to apply to `-`.

## Why not fixed in this session

The parser change affects every multi-line numeric expression in the
codebase. Risk of regressing other patterns (`x = a\n-b` where the
user genuinely meant `(-b)` as a sibling statement) is non-zero. A
careful audit of the parser's prefix-vs-infix dispatch + a targeted
test-suite sweep is the right scope, which exceeds this session's
"low-risk fixes only" envelope.

## Suggested fix

Audit `parser.hexa` for the line-continuation lookahead around
`parse_binary_expr` (or equivalent). When the next token after a
newline is `-` followed by a value-token (Ident / IntLit / FloatLit /
LParen), and the previous parse state is mid-expression (just consumed
an operand, not a statement-end), treat the `-` as binary continuation
not unary prefix. Mirror the `+` handling exactly.

Add tests to `test/t_parser_multiline_minus.hexa` covering:
1. `a\n-b\n+c` → expected `a-b+c`
2. `a\n-b` (no `+c` continuation) → still `a-b`
3. Standalone `-x` as expression statement (rare but should still parse)
4. Combination with parentheses and unary minus inside

## References

- Inbox pattern note: `docs/notes/hexa-native-port-pattern-pilot.md`
  (lines 100-115, "Multi-line expression footgun")
- Track B handoff: solar_kernel pilot acceptance report (kappa-65)
