Design complete. I verified every claim against the actual files on this worktree (`ef96be5b0` == origin/main, clean — same commit the gate measured). Full family-by-family design follows.

---

# Reference-match design: `rt_str_parse_float_hexinfnan` → glibc strtod (T_mis 176 → 0)

## Verified pipeline context (read, not assumed)

- Dispatch (emitted by `self/runtime_core_emit.hexa:2092-2128`): Clinger → EXACT → **tail** → `hxlcl_atof`. Both finite tiers provably decline anything with trailing junk (Clinger bails on any non-NUL trailing byte, `num_float_core.hexa:207`; EXACT declines at `float_parse_exact.hexa:403`), so **every family-B input like `0x10` does reach the tail** — the fix site is entirely inside `stdlib/runtime/float_parse_hexinfnan.hexa`.
- `hxlcl_atof` is **lenient, not strtod** (`self/runtime_emit_full.hexa:3092-3137`, both arms) — that's why a tail decline shows up as `0.0` for family B. The "C strtod (RETAINED)" comment in the wrapper is stale (matches the flip-gate memory).
- The module is a standalone: only `pub` symbol is `rt_str_parse_float_hexinfnan`; the only consumers are the flag-gated wrapper block and the seed resolver `tool/stage_resolve_runtime_a:706-736` (opt-in `HEXA_RT_STRTOD_TAIL_NATIVE=1`, default-OFF). No `self/` closure import (grep verified). So the entire fix is **1 `.hexa` file + 3 re-baked `.s` seeds**, no emitter or stage-script change.

---

## Family A — underflow flush-to-denorm_min: root cause is an i64 overflow at `ndrop == 63`

**Site:** `hpx_round_shift`, `stdlib/runtime/float_parse_hexinfnan.hexa:137-143`.

The divisor is built as `div = 2^ndrop` by repeated doubling. The comment at line 137 even says *"fits in i64 as long as ndrop <= 62; guard 63"* — **but no guard exists**. At `ndrop == 63`, `div` wraps to i64-min (negative), so `half = div/2` is negative and `r > half` is true for every `r ≥ 0` → **everything rounds up to `qi = 1` = denorm_min**, regardless of the true guard/round/sticky bits.

**Proof this is the whole family:** `ndrop` can only be ≥ 53−`bl` on the normal branch (≤ 10) — 63 is reachable only from the subnormal branch, where `ndrop = −1074 − e2`, i.e. `ndrop == 63 ⟺ e2 == −1137` exactly. I traced every A-family sample and **all of them land at `e2 = −1137`**: `0x1p-1137` (bexp 0), `0x1.8p-1133` (bexp −4), `0x1.5555…5p-1077` (15 absorbed frac digits → bexp −60), `-0xF.90Ea426209P-1097` (10 frac digits → bexp −40), `-0x9B.83D8EC75Adbfb8fDP-1085` (13 absorbed → bexp −52), `0x27.EEaP-1125` (bexp −12), `0x00.cdF1P-1121` (bexp −16), … Inputs with `e2 ≤ −1138` hit the correct `ndrop ≥ 64 → ±0` early-out; `e2 ≥ −1136` uses a non-overflowing divisor. Only `e2 == −1137` is broken — matching the corpus signature perfectly.

**Reference-matched fix** (glibc `stdlib/strtod_l.c` `round_and_return` semantics: round-to-nearest-even with explicit round bit + sticky; bits strictly below the round bit only ever feed sticky — musl `floatscan.c hexfloat` does the same fold): pre-shift the low `(ndrop − 62)` bits into sticky, then run the existing ≤62-bit machinery unchanged:

```hexa
fn hpx_round_shift(sign, m, ndrop, st, ebits_lead) -> float {
    if ndrop >= 64 { return hpx_assemble(sign, 0, 0) }
    // ndrop==63 needs div=2^63 which overflows i64 (div went negative → r>half
    // always true → everything rounded UP to denorm_min). Fold the bits BELOW
    // the round bit into sticky first — RNE is unchanged (glibc round_and_return
    // GRS semantics) — so the divisor stays <= 2^62.
    let mut mm = m
    let mut nd = ndrop
    let mut sticky = st
    while nd > 62 {
        if mm % 2 == 1 { sticky = 1 }
        mm = mm / 2
        nd = nd - 1
    }
    // …existing body verbatim, using mm / nd / sticky…
}
```

**Tie-correctness at the boundary** (checked by hand): true RNE at `ndrop=63` rounds up iff `m > 2^62`, or `m == 2^62` with sticky (q=0 is even, so a clean tie rounds down to ±0). After the pre-shift: `m == 2^62 → mm == 2^61 == half'`, tie resolved by `sticky` → identical; `m == 2^62 + 1 → mm == 2^61` with folded bit 0 → sticky → up → identical; `m < 2^62 → mm < half' →` down. Exact equivalence.

**Byte-identity of correct cases:** the pre-shift loop body executes zero iterations for `ndrop ≤ 62` — every currently-correct rounding path is bit-for-bit untouched. At `ndrop == 63`, inputs that today are *accidentally* right (`m > 2^62`, true answer denorm_min) still produce denorm_min.

---

## Family B — hex without `p` / dangling `p` / stop-at-junk

**Site:** `hpx_hexfloat`, `float_parse_hexinfnan.hexa:222-246` (the "mandatory p" block; also update the stale comments at lines 175-178 and 222).

**Reference:** C11 7.22.1.3 strtod grammar — after `0x`: a nonempty hexdigit sequence optionally containing one period, then an **optional** binary-exponent part (`p`/`P`, optional sign, ≥1 decimal digit), under the longest-valid-initial-subsequence rule. The `p` is mandatory only for C *source literals*, not for strtod. glibc `strtod_l.c` implements the dangling-`p` rollback explicitly (saves the position, and if no exponent digit follows, restores it — "0x1p" parses as "0x1"); musl's `hexfloat()` likewise. The oracle samples pin all of it: `0x10`→16.0, `0x1.8`→1.5, `0x.8`→0.5, `0x1.`→1.0, `0x1p`/`0x1p+`/`0x1pz`→1.0, `0x1.2.3p4`→`0x1.2`=1.125 (verified: 0x3FF2000000000000 = 4607745368753438720).

**Fix — replace lines 222-246 with a peek-parse-with-rollback:**

```hexa
    if anydig == 0 { return __hx_make_val(4, 0) }
    // strtod: the binary-exponent part is OPTIONAL (defaults to p0), and a 'p'
    // not followed by >=1 decimal digit (after optional sign) is NOT consumed —
    // longest valid prefix wins ("0x1p", "0x1p+", "0x1pz" -> "0x1" -> 1.0).
    // Anything after the accepted prefix is trailing junk -> ignored (endptr).
    let mut psign = 1
    let mut pval = 0
    if i < n {
        let pc = s.byte_at(i)
        if pc == 112 || pc == 80 {                    // 'p'/'P' — peek
            let mut j = i + 1
            let mut jsign = 1
            if j < n {
                let pb = s.byte_at(j)
                if pb == 45 { jsign = 0 - 1; j = j + 1 }
                else if pb == 43 { j = j + 1 }
            }
            let mut jval = 0
            let mut jhad = 0
            while j < n {
                let pb = s.byte_at(j)
                if pb >= 48 && pb <= 57 {
                    jval = jval * 10 + (pb - 48)
                    jhad = 1
                    if jval > 100000 { jval = 100000 }
                    j = j + 1
                } else { break }
            }
            if jhad == 1 { psign = jsign; pval = jval; i = j }   // commit
            // else: rollback — exponent part absent
        }
    }
    // …existing sig==0 / e2 / hpx_pack tail verbatim…
```

The second-`.` stop needs no change — the significand loop already sets `go = 0` at a second dot (line 217), and with optional-p that position simply becomes trailing junk.

**Keep `anydig == 0` → decline** (`0x`, `0xz`, `0x.`): strtod parses the leading `"0"` → ±0.0, and the lenient fallback also yields ±0.0 for these — measured green today (they're not in the 176). Changing them buys nothing and risks perturbing a measured-green path.

**Finite-regression argument (F_mis stays 0):** the tail only ever sees inputs both finite tiers declined, and the newly-accepted set is exactly `{0x + ≥1 hexdigit …}` — disjoint from every finite-decimal string (those parse in tier 1/2 and never arrive). Previously-accepted hex inputs (well-formed `p`-exponent, incl. trailing junk after the exponent digits like `-0x8d.d1p-1129z9`) take a byte-identical path — the peek commits at exactly the position the old mandatory parse reached.

**One harness caveat:** the gate's J-lane criterion is "ON==OFF byte-diff empty". If the corpus generator classified any `0x`-prefixed string as J (junk), it now legitimately differs ON vs OFF — those are strtod-valid and must be (re)classified into the T lane. Check the classifier when re-running; this is a corpus-lane bookkeeping fix, not corpus pruning.

**Semantics flag (asked for explicitly):** `to_float("0x10") → 16.0` is *correct by hexa's own contract*, not force-fit: `__hexa_num_parse_float` is documented as "the strtod / hxlcl_atof inverse" (`num_float_core.hexa` header), and the whole three-tier ladder exists to be bit-exact to strtod. Today's `0.0` is the accident (lenient fallback). Note for the record: Python `float()` and Rust `f64::from_str` *reject* hex strings, so if hexa ever wants script-language surface semantics for `to_float`, that's a separate deliberate surface decision — the runtime parse primitive's reference is strtod, and the flip gate's oracle is strtod. No conflict.

---

## Family C — nan(payload): glibc policy is scan / paren-rollback / full-consumption strtoull(base 0) / 51-bit payload / saturation

**Sites:** `hpx_nan_payload` (`float_parse_hexinfnan.hexa:262-285`) and its caller (`:337-347`).

**Reference (glibc `stdlib/strtod_l.c` + `stdlib/strtod_nan_main.c` + `stdlib/strtod_nan_double.h`; every clause below is also pinned by a measured oracle sample):

1. **Scan then paren-check:** after `nan(`, glibc scans the n-char-seq `[0-9A-Za-z_]*`. If the next char is not `)` — including end-of-string — it **rolls back and matches only "nan"** → default quiet NaN `0x7FF8000000000000`. Pins: `nan(123` and `nan(12-3)` → 9221120237041090560.
2. **Full-consumption rule:** the payload value is `strtoull(seq, &endp, 0)`, applied **only if `endp` consumed the entire seq**. `strtoull` stops at `_` (it is *not* a digit separator — the current comment at line 273 is wrong) — so `nan(_1_2_3_)` → payload ignored → default NaN. Pin: 9221120237041090560. Same rule kills `nan(123abc)`-style and `nan(0x)` (strtoull consumes only the `0`).
3. **Base 0:** `0x`/`0X`+hexdigit → hex; **leading `0` → octal**; else decimal. (No octal case in the 176 — the corpus evidently lacks multi-digit leading-zero payloads — but base-0 is the reference behavior and can't regress anything currently green, since `nan(0…)` single-digit octal ≡ decimal.)
4. **Overflow saturates** to `ULLONG_MAX` (ERANGE), consumption continues. Pins: `nan(0x` + 17 f's and `nan(99999999999999999999999)` → 9223372036854775807 (`0x7FFFFFFFFFFFFFFF`). The current code *wraps* in i64 and then applies hexa's sign-of-dividend `%`, producing `frac = 2^51 − 1` compositions like `0x7FF7FFFFFFFFFFFF` — exactly the observed wrong bits.
5. **SET_NAN_PAYLOAD** (dbl-64): `mantissa0` (19 bits) + `mantissa1` (32 bits) = **low 51 bits** of the value OR'd under the quiet bit (bit 51, always set from NAN). `ULLONG_MAX` → all 52 mantissa bits set → `0x7FFFFFFFFFFFFFFF` ✓ pins `nan(18446744073709551615)` / `nan(0xffffffffffffffff)`.

(I could not re-open the glibc source from this sandbox — WebFetch is not permitted here — but every clause above is pinned by the measured aiden-glibc oracle values, which are the binding reference for the gate anyway; the implementer can eyeball `strtod_nan_main.c` in one minute to confirm the quoted structure.)

**Fix — replace `hpx_nan_payload` with a range-bounded, i64-safe strtoull-equivalent** (32-bit limbs so u64 magnitude and exact saturation are representable without i64 wrap):

```hexa
// glibc strtod_nan: payload = strtoull(seq, &endp, 0); applied ONLY if the whole
// n-char-seq was consumed (endp == cp). '_' is NOT a separator — it stops
// strtoull → payload ignored. Overflow saturates to ULLONG_MAX. base 0:
// "0x"+hexdigit → 16, leading '0' → 8 (octal), else 10.
// Returns the low-51 payload bits, or -1 = leave the default quiet-NaN mantissa.
fn hpx_nan_payload(s: string, i0, jend) -> int {
    let mut i = i0
    let mut base = 10
    let mut had0 = 0
    if i < jend && s.byte_at(i) == 48 {
        base = 8
        had0 = 1
        i = i + 1
        if i < jend {
            let x = s.byte_at(i)
            if x == 120 || x == 88 {
                let mut hd = 0
                if i + 1 < jend {
                    let hb = s.byte_at(i + 1)
                    if hb >= 48 && hb <= 57 { hd = 1 }
                    else if hb >= 97 && hb <= 102 { hd = 1 }
                    else if hb >= 65 && hb <= 70 { hd = 1 }
                }
                if hd == 0 { return 0 - 1 }   // "0x" w/o hexdigit: strtoull took "0" only
                base = 16
                i = i + 2
            }
        }
    }
    let mut hi = 0        // value = hi*2^32 + lo, limbs < 2^32 (hi2 <= 16*2^32 — i64-safe)
    let mut lo = 0
    let mut sat = 0
    let mut ndig = 0
    while i < jend {
        let b = s.byte_at(i)
        let mut d = 0 - 1
        if b >= 48 && b <= 57 { d = b - 48 }
        else if b >= 97 && b <= 102 { d = b - 87 }
        else if b >= 65 && b <= 70 { d = b - 55 }
        if d < 0 || d >= base { return 0 - 1 }   // '_' / out-of-base → not fully consumed
        ndig = ndig + 1
        let lo2 = lo * base + d
        let hi2 = hi * base + lo2 / 4294967296
        lo = lo2 % 4294967296
        if hi2 >= 4294967296 { sat = 1 }         // u64 overflow → ULLONG_MAX
        hi = hi2 % 4294967296
        i = i + 1
    }
    if ndig == 0 && had0 == 0 { return 0 - 1 }
    if sat == 1 { return 2251799813685247 }      // ULLONG_MAX low-51 = all ones
    return (hi % 524288) * 4294967296 + lo       // low 51 = (hi mod 2^19)*2^32 + lo
}
```

**Caller** (replace the `pb == 40` block): scan `j` over `[0-9A-Za-z_]` from `i+1`; only if `j < n && s.byte_at(j) == 41` call `hpx_nan_payload(s, i+1, j)` and, when it returns `≥ 0`, `frac = frac + pay` (payload is bits 0..50, quiet bit is 51 — disjoint, `+ == |`). Otherwise **do nothing** — bare `nan` with default mantissa.

**Green-case identity:** `nan` / `nan()` / `nan(0)` → payload −1 or 0 → default mantissa, same bits as today; `nan(123)` → fully consumed decimal 123 → identical to today's `…007b`; `nan(0xff)` identical. I verified the decimal-saturation threshold arithmetic by hand at `18446744073709551615` (accumulates exactly to `hi = 2^32−1` without tripping `sat`; one more digit trips it) — both routes give all-ones low-51, matching the oracle.

**Cross-libc decision point (flagged, not silently forced):** the module header's earlier probe verified basic payloads (`nan(123)`, `nan(0xff)`) bit-identical on Apple libc, but the *exotic* clauses this fix adds — octal base-0, 17-hex-digit saturation, decimal overflow, `_`-rejection, paren-rollback — were characterized against **glibc on aiden**. Apple's strtod is gdtoa-derived and its nan handling is a known divergence risk. Before claiming 3-target T_mis=0, run a 10-line C probe on ghost (darwin): `nan(017)`, `nan(18446744073709551615)`, `nan(0xfffffffffffffffff)`, `nan(999…9)`, `nan(_1_2_3_)`, `nan(123`, `nan(12-3)`, `nan()`, `nan(0x)`. If Apple diverges on any, the honest disposition is: match glibc (the linux gate host), and record a **documented, per-OS residual** for darwin in the gate — not tune the parser per-OS.

---

## Family D (preemptive) — `\v` `\f` leading whitespace

The tail's whitespace skip set at `float_parse_hexinfnan.hexa:296` is `{32, 9, 10, 13}` — missing `11` (`\v`) and `12` (`\f`), which C `isspace`/strtod skips and tier-1 Clinger already skips. `"\v0x1p3"` therefore declines to the lenient fallback → 0.0 vs strtod 8.0. This was mismatch-family ④ predicted in the oracle-design session; the 3-family characterization of the current 176 means the corpus likely doesn't generate `\v`/`\f`, but the fix is two extra comparisons touching only currently-declined inputs — include it: `if b == 32 || b == 9 || b == 10 || b == 11 || b == 12 || b == 13`. (Consider the same two bytes for `float_parse_exact.hexa:347` in a follow-up — same latent gap, but out of scope for this gate since finite `\v`-inputs are served by tier 1.)

---

## Re-bake + re-gate plan

1. **Edit** `stdlib/runtime/float_parse_hexinfnan.hexa` (A+B+C+D above; also fix the now-false header/inline comments: "mandatory p" at :175-178/:222, "'_' digit separator (glibc)" at :273, and the header's nan-trap paragraph to state the full-consumption + saturation + base-0 policy).
2. **Re-bake seeds on aiden** (mini is git/gh-only): `APRIME=build/aprime_cc tool/regen_float_parse_hexinfnan_native_s.sh all` — all 3 targets cross-emit from one host; the script self-gates on the aprime binary existing and asserts the exported symbol per seed. Use direct `ssh + nohup` if `sidecar pool on` times out.
3. **A/B runtime.a**: OFF arm `CC=clang bash tool/stage_resolve_runtime_a` — assert **byte-identical to origin/main's OFF runtime.a** (this *proves* the shipped-default neutrality claim rather than arguing it). ON arm with `HEXA_RT_STRTOD_TAIL_NATIVE=1`. `rm -rf ~/.hexa-cache` between builds; link via `HEXA_PREBUILT_RUNTIME` (pool link-deadlock workaround).
4. **Re-run the tail gate** (the 3-file `strtod_tail_oracle*` harness used for the 176-measurement): targets **T_mis = 0 · F_mis = 0 · oracle_drift = 0 · F/J lanes ON==OFF empty diff**. Reclassify any `0x`-prefixed J-lane entries into T first (§Family B caveat). Then the darwin exotic-nan probe (§Family C) → either 3-target T_mis=0 or a documented darwin-nan residual.
5. **Merge shape:** PR = 1 `.hexa` + 3 `.s`; zero emitter/stage-script edits → preprocessed `runtime.c` byte-identical, seeds dead unless flag-ON, module outside the `self/` closure (grep-verified) → `gen3≡gen4` untouched; standard 3-target PR CI still runs. `CHANGELOG.jsonl` entry in the same change (`.hexa` changelog gate). The default-flip itself stays a separate, later user-go decision after the gate is green.

**Why byte-neutral for the shipped default, precisely:** the flag-OFF build never assembles the seeds (`stage_resolve_runtime_a:707` early-return) and never emits the wrapper block (`#ifdef` dead), and no other code imports the module or its file-private `hpx_*` helpers — the only `pub` symbol has exactly one, flag-gated, caller. The step-3 OFF-arm byte-diff turns this argument into a measurement.