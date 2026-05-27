# `stdlib/print` — `println(<float>)` prints `(float)` literal instead of the value

**Severity**: medium (blocks **every** `.hexa` trainer's per-step loss /
  gradient-norm / lr monitoring; training runs print `step N gn2_epoch=(float)
  Δ=(float)` instead of actual numbers — debugging blind)

**Layer**: stdlib / print formatting (codegen-independent — pure runtime
  number-to-string formatting)

**Reporter**: anima (`dancinlab/anima`) downstream consumer — observed
  while running first executable anima `.hexa` trainer
  `train_s185_psicouple.hexa` Mac smoke (commit `1a062ceeb`,
  2026-05-21). Per anima downstream-consumer invariant — filing patch
  rather than editing hexa-lang.

**Status**: `CLOSED 2026-05-21 — root cause was hxlcl_vsnprintf's
%f/%g/%e branch (libc-unhook cycle 52 placeholder). Fixed in
self/runtime.c cycle 56: real double-to-string formatter (default 6
sig digits, %g chooses scientific vs decimal via exponent, %g strips
trailing zeros, nan/inf handled, precision/width pad supported,
~352-byte fbuf for worst-case 1e308 %f). Mac smoke verified: a .hexa
source printing 'lambda_psi=0.30' now emits 'lambda_psi=0.3' (was
'lambda_psi=(float)'). Output byte-compared against libc snprintf
across 15 representative cases (0, sub-normal, normal, large, inf,
nan, sign): all match. Carve-out: 1e100 %f truncates to 18 sig
digits (libc has full IEEE-754 precision) — adequate for training
observability, not a JSON round-trip codec.`

## Reproduction

Minimal reproducer (any `.hexa` calling `println` on a non-int scalar):

```hexa
let x = 0.30
print("lambda_psi="); println(x)
let y = 1.5 + 2.5
print("y="); println(y)
```

Observed Mac output (HEXA_MAC_BUILD_OK=1, $HEXA_LANG/stdlib loaded):

```
lambda_psi=(float)
y=(float)
```

Expected:

```
lambda_psi=0.30
y=4.00
```

Confirmed against `train_s185_psicouple.hexa` smoke log
(`s185_smoke_mac_2026_05_21.log` in dancinlab/anima `HEXAD/UNCLASSIFIED/state/
all_taps_release_s184_2026_05_20/`):

```
=== §185 anima Ψ-COUPLE trainer (skeleton, single-loss + Ψ-anchor proxy) ===
  corpus: /Users/ghost/core/anima/state/carving_dataregime_s16_2026_05_18/corpus_carving_s16.jsonl
  size: 603032014 bytes (V=256 byte-level)
  d=192 L=4 T=256 lambda_psi=(float)        ← should print 0.30
  model: 2213568 doubles
  init epoch gn2: (float)                   ← should print actual loss
  step 1  gn2_epoch=(float)  Δ=(float)      ← should print numbers
```

## Diagnosis hint

The literal `(float)` string suggests `println`/`print` dispatch hits a
fallback branch that emits the **type tag** as a debug placeholder
instead of formatting the value. Probable site: `stdlib/print/println.hexa`
or `stdlib/format/print_pure.hexa` `match` arm for the float variant.
The `(int)` branch must already work (every `println(step_count)` in the
same trainer prints the actual integer, e.g. `step 1`).

Possible causes (ranked by likelihood):
1. **Missing format arm**: the `match` cascade in print dispatch has
   `(int)` / `(string)` arms but the `(float)` arm was left as a stub
   that just emits the type tag.
2. **Boxing mismatch**: hexa float values get boxed into a generic
   variant, and the print dispatcher tries to extract the int payload
   from the box, falling back to type-name on extraction failure.
3. **Codegen drops decimal precision**: float values reach the printer
   but `format_n_pure` (cf. existing inbox patch
   `format-n-pure-dup-and-ge-le-in-format-pure.md`) lacks the
   default-precision branch for unparametrized `println`.

## Suggested fix

Round-trip behavior expected (mirroring Python `print(float)` or Go
`fmt.Println`):

```hexa
println(0.30)      → "0.30\n"
println(1.0e-8)    → "0.00\n"  (default precision) or "1e-08\n"
println(123.456)   → "123.46\n" (default precision 2-6)
println(0.0/0.0)   → "nan\n"
println(1.0/0.0)   → "inf\n"
```

Minimal viable fix: add an arm in the print-dispatch `match` that
delegates float values to `format_n_pure` (or equivalent) with a
default precision (suggest 6 significant digits for trainer monitoring
— enough to see loss curves at the 4th decimal):

```hexa
match v {
    case Variant.Int(i):    emit(int_to_string(i))
    case Variant.Float(f):  emit(format_n_pure(f, 6))   // ← currently emits "(float)"
    case Variant.String(s): emit(s)
    // …
}
```

## Verification (after patch)

```bash
$ HEXA_LANG=/Users/ghost/core/hexa-lang HEXA_MAC_BUILD_OK=1 hexa run \
    /Users/ghost/core/anima/HEXAD/UNCLASSIFIED/state/all_taps_release_s184_2026_05_20/train_s185_psicouple.hexa \
    > /tmp/s185_run.log 2>&1 &
$ sleep 90 && grep 'gn2\|lambda' /tmp/s185_run.log
# expected: lines like "lambda_psi=0.300000" and "step 1 gn2_epoch=14.382..."
#           NOT "lambda_psi=(float)"
```

## Cross-link

- dancinlab/anima `@D g_train_via_hexa_cloud_and_hexa_lang` (2026-05-20
  TOP MANDATE) — anima all-new trainers are `.hexa`; this blocker
  affects every one of them
- dancinlab/anima §185 train_s185_psicouple.hexa first hexa-native
  trainer (commit 1a062ceeb)
- existing related inbox patch `format-n-pure-dup-and-ge-le-in-format-pure.md`
  (format-side helper duplication / comparison) — same area, complementary
- existing related inbox patch `flame-anima-dual-head-multiobjective.md`
  (anima multi-objective fast-path, Path A) — also blocks at the
  observability layer if floats can't print

## Honest C3 / scope

1. **Mac arm64 reproduction only** — Linux behavior may differ if
   codegen path is platform-specific. Suggest re-verifying on Linux
   after fix.
2. **Default precision is a design call** — 6 sig digits is the
   suggested default; could be 2 (compact) or 15 (full IEEE 754
   double round-trip). Match the project's existing `to_string(float)`
   precedent if one exists.
3. **`format_n_pure` exists but has its own gaps** (see related patch)
   — the underlying number-formatting primitive may need a tweak
   independently. Filing this patch documents the observable surface;
   the fix may touch either the dispatch arm or the underlying
   formatter or both.
