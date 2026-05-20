# F-P0-OBJEQ falsifier corpus — Mach-O arm64 object emitter

> RFC 063 § P0 — falsifier `F-P0-OBJEQ`. Test programs the future
> `compiler/emit/macho_arm64.hexa` implementation is checked against.
> The oracle is `clang -c -arch arm64` on the corresponding `.s` that
> `aprime_cc --emit=asm` produces.

## Corpus shape

Each test is one self-contained `.hexa` source — minimal program that
exercises one feature of the LIR -> Mach-O arm64 encoding:

| file | feature exercised | LIR ops it produces |
|------|-------------------|---------------------|
| `trivial.hexa` | function call + exit | `BL`, `MOV imm`, prologue |
| `if.hexa` | conditional branch | `CMP`, `B.cond`, label |
| `while.hexa` | backward branch / loop body | `B`, `CBZ`, condition |
| `fib.hexa` | recursion + arithmetic | recursive `BL`, `ADD`, `SUB` |

Each corpus file is at most ~30 lines so the emitted `.s` is small
enough to byte-diff confidently and the encoding-table coverage it
exercises is precise.

## How the falsifier runs

```
for T in trivial if while fib:
    aprime_cc --emit=asm T.hexa  -> /tmp/T.s              (codegen, S1-S2 verified)
    clang -c -arch arm64 /tmp/T.s -o /tmp/T.ref.o         (oracle: system as)
    aprime_cc --emit=obj T.hexa  -> /tmp/T.ours.o         (P0 implementation under test)
    diff <(strip-nondet /tmp/T.ref.o) <(strip-nondet /tmp/T.ours.o)
    # equal -> this test PASSES F-P0-OBJEQ.
```

`strip-nondet` removes:
- timestamps (`LC_BUILD_VERSION` minos/sdk if absent in our output, etc.)
- file paths embedded by clang (`__debug_info` etc., if any)
- `LC_UUID` (random)
- load-command ordering (Mach-O permits reordering inside the same
  section; we canonicalise both sides to `objdump -macho` output)

A practical implementation: parse both `.o` files with `otool -l` and
diff the parsed structure — same intent, less hand-rolled stripping.

## Status

Corpus committed 2026-05-20. Oracle goldens (the `.ref.o` files) are
NOT committed — they regenerate from `clang -c` on demand and may
vary across clang versions; the byte-eq check is run-time, not
golden-file-based. Goldens at the corpus level (commit `clang -O0 -c`
output as the reference) are an option future cycles can pursue if
non-determinism in clang output becomes an issue.

## Cross-references

- RFC 063 § P0 — the falsifier definition.
- `compiler/emit/macho_arm64.hexa` — the P0 scaffold this corpus
  tests once implementation lands.
- `compiler/emit/asm.hexa` — the existing `.s` text emitter; the
  P0 implementation mirrors its structure, replaces text with bytes.
