Design complete. Everything below is grounded in files read this session (this worktree denies writes, so the three harness files are provided in full for you to land on a branch).

---

# strtod-tail flip-gate ORACLE — design

## ⚠️ Two load-bearing corrections to the framing first

**1. The C fallback is NOT strtod — the "RETAINED #3583 strtod" comments are stale.** `__hexa_num_parse_float`'s final fallback `hxlcl_atof` (`self/runtime_emit_full.hexa:3092-3137`) is a *lenient* decimal parse in **both** arms: the `HEXA_HAS_HEXA_RT_STDLIB` arm delegates to `rt_str_parse_float` (`stdlib/runtime/ctype.hexa:243` — its own comment: "Edge cases (subnormals, INF/NaN strings, hex floats) fall short"), and the `#else` is the same lenient C body. Real libc strtod appears nowhere in the `to_float` chain. Consequence: **today (tail OFF), `to_float("0x1.8p1")` returns 0.0, not 3.0** — the flip is a behavior *fix*, so an ON-vs-OFF diff is NOT a strtod oracle for the tail family. The oracle must be real strtod, obtained two independent ways below.

**2. There IS an in-process real-strtod oracle: `parse_float(s)`.** `parse_float(s)` lowers to `hexa_str_parse_float` (`self/codegen.hexa:8064` → `:444`), which in the default runtime.a compile (no `-DHEXA_HAS_HEXA_RT_STDLIB` on the single-TU line, `tool/stage_resolve_runtime_a:3135`) is literally `strtod(HX_STR(s), NULL)` (`self/runtime_emit_full.hexa:5201-5205`). So one `.hexa` binary can bit-compare the shipped tiered path against host strtod directly — guarded by a startup self-check that aborts if that wiring ever degrades.

## 1. Signature + routing (grounded)

- **Hexa-level**: `pub fn rt_str_parse_float_hexinfnan(s: string) -> float` — `stdlib/runtime/float_parse_hexinfnan.hexa:290`. **C-ABI**: `HexaVal rt_str_parse_float_hexinfnan(HexaVal s)` — called with a non-owning borrow box `HX_MAKE_STR((char*)cs)` at `self/runtime_core_emit.hexa:2124-2126`. Returns a `TAG_FLOAT` HexaVal (the double) or the `TAG_VOID` sentinel `__hx_make_val(4,0)` = decline. HexaVal is a **tagged struct, not NaN-boxed** (`HX_MAKE_FLOAT {.tag, .f}`, runtime_core_emit.hexa:1508) — NaN payload bits round-trip exactly through `to_float`/`float_to_bits`.
- **Which inputs reach it**: only strings where tier-1 Clinger (`num_float_core.hexa:71` — bails on trailing junk/no-digit/mantissa>2^53/|e10|>22) **and** tier-2 EXACT (`float_parse_exact.hexa:342` — bails on trailing junk `if i < n`, no-digit) both return `TAG_VOID`. Since EXACT owns the *full* finite-decimal domain, the tail is reached for exactly: **hex-floats (`0x…`), inf/infinity, nan/nan(payload), and malformed strings**. It does **not** own any decimal tail. On its own decline (sentinel), control falls to the lenient `hxlcl_atof` — not strtod.
- **Flip site**: `tool/stage_resolve_runtime_a:707` (`[ "${HEXA_RT_STRTOD_TAIL_NATIVE:-0}" = "1" ] || return 0`); when ON, the frozen seed is assembled to `build/float_parse_hexinfnan_native.o`, ar'd into runtime.a, and `-DHEXA_RT_STRTOD_TAIL_NATIVE=1` enters the runtime.c compile (`:1356-1360`).

## 2. Harness form (3 files)

One deterministic `.hexa` harness run against **two runtime.a builds** (tail ON / tail OFF), plus an independent C re-verifier:

- `test/native_build/strtod_tail_oracle.hexa` — generates the corpus in-process (fixed-seed LCG, no I/O, no imports), and for every input prints `<class> <OK|MISMATCH> <bits(to_float)> <bits(parse_float)> <input>`. `to_float` = the shipped tiered path incl. the frozen `.s` seed (built via `stage_resolve_runtime_a` + `HEXA_PREBUILT_RUNTIME`, i.e. it measures the **shipped seed**, not a recompile of the SSOT); `parse_float` = libc strtod. A literal arg is never const-folded (`to_float` lowers to a runtime call, codegen.hexa:6912-6918).
- `test/native_build/strtod_tail_oracle_ref.c` — reads the harness output and **recomputes strtod per line**, independently verifying both the in-process verdict and the oracle itself (defends against the `rt`-mode / RT_STDLIB degradation case).
- `test/native_build/strtod_tail_oracle_run.sh` — the exact A/B + gate sequence.

Classes: **T** = tail-family, strtod-served (gate: 0 mismatch vs strtod) · **F** = well-formed finite decimal (gate: 0 mismatch vs strtod **and** byte-identical ON-vs-OFF = the finite-regression assert) · **J** = true junk owned by the lenient fallback (gated ON==OFF only; its strtod divergence is pre-existing and unchanged by the flip — asserting strtod equality there would blame the tail for the fallback's leniency).

### `test/native_build/strtod_tail_oracle.hexa`

```hexa
// test/native_build/strtod_tail_oracle.hexa — strtod-tail flip-gate ORACLE corpus
// (zero-c #29, gate for the stage_resolve_runtime_a:707 :off→native default-ON flip).
//
// WHAT IT MEASURES: the SHIPPED composed string→f64 parse — to_float(s) →
// hexa_to_float → __hx_to_double → __hexa_num_parse_float (runtime_core_emit.hexa
// ~2092-2129): fast(Clinger rt_parse_float_native) → EXACT(rt_str_parse_float_exact)
// → TAIL(rt_str_parse_float_hexinfnan, #ifdef HEXA_RT_STRTOD_TAIL_NATIVE, the frozen
// self/native/float_parse_hexinfnan_*.s seed ar'd into runtime.a) → hxlcl_atof
// (LENIENT no-hex/inf/nan fallback — NOT strtod; runtime_emit_full.hexa:3094-3137).
//
// IN-PROCESS ORACLE: parse_float(s) → hexa_str_parse_float → libc strtod(HX_STR(s),
// NULL) in the default (no HEXA_HAS_HEXA_RT_STDLIB) runtime.a compile
// (runtime_emit_full.hexa:5201-5205, codegen.hexa:8064/:444). oracle_selfcheck()
// ABORTS the run if that wiring ever degrades to the lenient rt_str_parse_float.
//
// CLASSES (first output token):
//   T = tail-family, strtod-served (0x-hex / inf / nan surfaces incl. decline-boundary
//       probes). GATE: got == strtod bits, 0 mismatch.
//   F = well-formed finite decimal (finite-regression re-assert of #4200).
//       GATE: got == strtod bits, 0 mismatch, AND byte-identical ON-vs-OFF.
//   J = true junk / lenient-owned trailing-junk decimals. NOT gated vs strtod
//       (pre-existing lenient fallback, unchanged by the flip); gated ON==OFF only.
//
// OUTPUT: one line per case: "<cls> <OK|MISMATCH> <got_bits> <oracle_bits> <input>"
// (signed-i64 bit patterns; input runs to EOL verbatim, may contain spaces/tabs).
// Verdict/meta lines start with '#'. Re-verify independently with
// strtod_tail_oracle_ref.c; full sequence in strtod_tail_oracle_run.sh.
//
// DETERMINISTIC: fixed-seed 31-bit LCG (no Math.random) — byte-identical corpus on
// every run/host, so ON-vs-OFF output diff is meaningful.

let mut RS = 20260706
let mut t_total = 0
let mut t_mis = 0
let mut f_total = 0
let mut f_mis = 0
let mut j_total = 0
let mut j_dif = 0

// 31-bit LCG (glibc constants), high-ish bits used. Wrap-free in i64:
// RS < 2^31 so RS*1103515245 + 12345 < 2^62.
fn rnd(m: int) -> int {
    RS = (RS * 1103515245 + 12345) % 2147483648
    let h = RS / 1024
    return h % m
}

let HEXD = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f", "A", "B", "C", "D", "E", "F"]

fn hexdigits(k: int) -> string {
    let mut s = ""
    let mut i = 0
    while i < k {
        s = s + HEXD[rnd(22)]
        i = i + 1
    }
    return s
}

fn decdigits(k: int) -> string {
    let mut s = ""
    let mut i = 0
    while i < k {
        s = s + to_string(rnd(10))
        i = i + 1
    }
    return s
}

fn rep(s: string, k: int) -> string {
    let mut r = ""
    let mut i = 0
    while i < k {
        r = r + s
        i = i + 1
    }
    return r
}

// one corpus case: shipped path vs in-process strtod oracle, bit-compare, one line.
fn emit(cls: string, inp: string) {
    let got = float_to_bits(to_float(inp))
    let ora = float_to_bits(parse_float(inp))
    let mut tag = "OK"
    if got != ora { tag = "MISMATCH" }
    if cls == "T" {
        t_total = t_total + 1
        if got != ora { t_mis = t_mis + 1 }
    } else if cls == "F" {
        f_total = f_total + 1
        if got != ora { f_mis = f_mis + 1 }
    } else {
        j_total = j_total + 1
        if got != ora { j_dif = j_dif + 1 }
    }
    println(cls + " " + tag + " " + to_string(got) + " " + to_string(ora) + " " + inp)
}

// ABORT-guard: parse_float must be libc strtod (hexa_str_parse_float, default
// no-RT_STDLIB compile). The lenient rt_str_parse_float cannot pass the hex or
// nan-payload probes; a wrong runtime.a/toolchain pairing dies loudly here.
fn oracle_selfcheck() -> int {
    if float_to_bits(parse_float("0x1p+1")) != 4611686018427387904 { return 0 }   // 2.0
    if float_to_bits(parse_float("inf")) != 9218868437227405312 { return 0 }       // +inf
    if float_to_bits(parse_float("nan(123)")) != 9221120237041090683 { return 0 }  // 0x7ff8...007b
    if float_to_bits(parse_float("0x1p-1074")) != 1 { return 0 }                   // min subnormal
    if float_to_bits(parse_float("5e-324")) != 1 { return 0 }
    return 1
}

// randomized hex-float (class T): sign · optional ws · mixed-case 0x · 0..2 int +
// 0..19 frac hex digits (≫ the seed's 59-bit sticky capacity) · p/P exponent from
// 4 bands (uniform normal / subnormal / overflow / clamp-extreme) · rare trailing junk.
fn gen_random_hex() -> string {
    let mut s = ""
    let wr = rnd(10)
    if wr == 0 { s = s + " " }
    if wr == 1 { s = s + "\t" }
    let sr = rnd(4)
    if sr == 1 { s = s + "+" }
    if sr >= 2 { s = s + "-" }
    s = s + "0"
    if rnd(2) == 0 { s = s + "x" } else { s = s + "X" }
    if rnd(8) == 0 { s = s + "00" }
    let di = rnd(3)
    let mut df = rnd(20)
    if di == 0 && df == 0 { df = 1 }
    s = s + hexdigits(di)
    if df > 0 {
        s = s + "." + hexdigits(df)
    } else if rnd(8) == 0 {
        s = s + "."
    }
    if rnd(2) == 0 { s = s + "p" } else { s = s + "P" }
    let band = rnd(10)
    let mut ev = 0
    if band < 6 {
        ev = rnd(161) - 80
    } else if band < 8 {
        ev = 0 - (990 + rnd(151))              // subnormal / underflow band
    } else if band == 8 {
        ev = 990 + rnd(111)                     // overflow band
    } else {
        let pick = rnd(4)
        if pick == 0 { ev = 20000 }
        if pick == 1 { ev = 0 - 20000 }
        if pick == 2 { ev = 100000 + rnd(5) }   // seed pval-clamp region (clamps at 100000)
        if pick == 3 { ev = 0 - (100000 + rnd(5)) }
    }
    if ev >= 0 && rnd(2) == 0 { s = s + "+" }
    s = s + to_string(ev)
    let tj = rnd(16)
    if tj == 0 { s = s + "z9" }                 // trailing junk after a COMPLETE parse
    if tj == 1 { s = s + " " }
    return s
}

// randomized finite decimal (class F): full-valid subject, no trailing junk.
fn gen_random_dec() -> string {
    let mut s = ""
    let wr = rnd(12)
    if wr == 0 { s = s + " " }
    let sr = rnd(3)
    if sr == 1 { s = s + "-" }
    if sr == 2 { s = s + "+" }
    let k1 = 1 + rnd(19)
    let k2 = rnd(8)
    s = s + decdigits(k1)
    if k2 > 0 { s = s + "." + decdigits(k2) }
    let eb = rnd(10)
    if eb < 5 {
        if rnd(2) == 0 { s = s + "e" } else { s = s + "E" }
        let band = rnd(10)
        let mut ev = 0
        if band < 6 { ev = rnd(51) - 25 }
        else if band < 8 { ev = 0 - (280 + rnd(60)) }
        else if band == 8 { ev = 280 + rnd(40) }
        else { ev = 340 + rnd(80); if rnd(2) == 0 { ev = 0 - ev } }
        if ev >= 0 && rnd(2) == 0 { s = s + "+" }
        s = s + to_string(ev)
    }
    return s
}

fn main() {
    if oracle_selfcheck() == 0 {
        println("# ORACLE-DEGRADED — parse_float(s) is NOT libc strtod in this build")
        println("# (hexa_str_parse_float compiled with HEXA_HAS_HEXA_RT_STDLIB, or stale toolchain).")
        println("# The corpus verdict would be meaningless. ABORT.")
        return
    }
    println("# ORACLE-OK parse_float==libc-strtod (probes: 0x1p+1 / inf / nan(123) / 0x1p-1074 / 5e-324)")

    // ── E1 boundary constants (class T) ────────────────────────────────────────
    emit("T", "0x1.fffffffffffffp+1023")            // DBL_MAX
    emit("T", "0x1.fffffffffffff7ffffp+1023")       // just below halfway → DBL_MAX
    emit("T", "0x1.fffffffffffff8p+1023")           // exact halfway → round-even → +inf
    emit("T", "0x1.fffffffffffff800001p+1023")      // above halfway → +inf
    emit("T", "-0x1.fffffffffffff8p+1023")
    emit("T", "0x1p+1024")                          // overflow → +inf
    emit("T", "-0x1p+1024")
    emit("T", "0x1p-1022")                          // DBL_MIN
    emit("T", "0x0.fffffffffffff8p-1022")           // largest-subnormal halfway → DBL_MIN (carry promote)
    emit("T", "0x0.fffffffffffffcp-1022")
    emit("T", "0x0.fffffffffffffp-1022")            // largest subnormal
    emit("T", "0x1p-1074")                          // min subnormal
    emit("T", "0x1p-1075")                          // half min-subnormal, tie → even → +0
    emit("T", "0x1.0000000000000001p-1075")         // tie + sticky → min subnormal
    emit("T", "0x0.fffffffffffffffp-1075")          // below half → +0
    emit("T", "0x0.8p-1074")                        // == 2^-1075 tie → +0
    emit("T", "0x0.800000000000001p-1074")          // tie + sticky → min subnormal
    emit("T", "0x1p-1076")
    emit("T", "-0x1p-1074")
    emit("T", "-0x1p-1075")                         // → -0 (sign must survive underflow)
    emit("T", "0x0p+0")
    emit("T", "-0x0p+0")
    emit("T", "-0x0.000p-10")
    emit("T", "0x0p+100000")
    emit("T", "0x0.0p-100000")
    emit("T", "0x1.fffffffffffffcp0")               // carry-into-exponent canonical (→ 0x4000000000000000)
    emit("T", "0x1p0")
    emit("T", "0x1.8p1")
    emit("T", "0x8p-3")                             // == 1.0, non-normalized significand form
    emit("T", "0x.8p1")                             // == 1.0, no int digit
    emit("T", "0x1.p3")                             // trailing dot, no frac digits

    // ── E2 carry-into-exponent ladder × exponent sweep (class T) ───────────────
    let CARRY_M = ["1.fffffffffffff", "1.fffffffffffff8", "1.fffffffffffffc", "1.ffffffffffffff", "f.ffffffffffffff8", "1.00000000000000800000000001", "1.ffffffffffffffffffffff"]
    let CARRY_E = [-1074, -1073, -1024, -1023, -1022, -1000, -53, -52, -2, -1, 0, 1, 52, 53, 1000, 1020, 1021, 1022, 1023]
    let mut ci = 0
    while ci < 7 {
        let mut cj = 0
        while cj < 19 {
            emit("T", "0x" + CARRY_M[ci] + "p" + to_string(CARRY_E[cj]))
            cj = cj + 1
        }
        ci = ci + 1
    }

    // ── E3 subnormal / gradual-underflow scan (class T) ────────────────────────
    let mut k = 0
    while k < 130 {
        emit("T", "0x1p-" + to_string(1014 + k))                  // normal → subnormal → 0
        emit("T", "0x1.8p-" + to_string(1014 + k))                // tie candidates
        emit("T", "0x1.5555555555555555p-" + to_string(1014 + k)) // sticky-rich significand
        k = k + 1
    }
    let mut k3 = 0
    while k3 < 8 {
        emit("T", "0x3p-" + to_string(1071 + k3))
        emit("T", "0x7p-" + to_string(1072 + k3))
        emit("T", "0x1.0000000000001p-" + to_string(1070 + k3))
        k3 = k3 + 1
    }

    // ── E4 inf / nan surface forms (class T) ───────────────────────────────────
    emit("T", "inf")
    emit("T", "INF")
    emit("T", "Inf")
    emit("T", "iNf")
    emit("T", "+inf")
    emit("T", "-inf")
    emit("T", "infinity")
    emit("T", "INFINITY")
    emit("T", "Infinity")
    emit("T", "InFiNiTy")
    emit("T", "-infinity")
    emit("T", "+INFINITY")
    emit("T", "  inf")
    emit("T", "\tinf")
    emit("T", "infx")                                // strtod: consumes "inf", junk ignored
    emit("T", "INFINITYY")
    emit("T", "nan")
    emit("T", "NAN")
    emit("T", "NaN")
    emit("T", "-nan")
    emit("T", "+nan")
    emit("T", "nanx")                                // strtod: consumes "nan"
    emit("T", "nan (123)")                           // space → payload NOT taken, bare nan
    emit("T", "nan()")
    emit("T", "nan(0)")
    emit("T", "nan(1)")
    emit("T", "nan(123)")
    emit("T", "nan(0x7b)")
    emit("T", "nan(0X7B)")
    emit("T", "nan(0xff)")
    emit("T", "nan(0x7ffffffffffff)")                // all 51 payload bits
    emit("T", "nan(0x8000000000000)")                // bit 51 == quiet bit → masked to 0
    emit("T", "nan(0xfffffffffffff)")                // 52 bits → low-51 kept
    emit("T", "nan(2251799813685247)")               // 2^51-1 decimal
    emit("T", "nan(2251799813685248)")               // 2^51 decimal → masked
    emit("T", "nan(18446744073709551615)")           // u64 max (strtoull wrap semantics)
    emit("T", "nan(0xffffffffffffffff)")
    emit("T", "nan(0xfffffffffffffffff)")            // > u64 → strtoull saturation/wrap probe
    emit("T", "nan(99999999999999999999999)")
    emit("T", "nan(_1_2_3_)")                        // '_' separators (glibc n-char-seq)
    emit("T", "nan(abc)")                            // base-10 strtoull("abc")==0 → bare
    emit("T", "-nan(123)")
    emit("T", "nan(123)z")                           // junk AFTER closed payload

    // ── E5 decline-boundary probes (class T — strtod serves these; the tail must
    //    either match or its sentinel-fallback must still compose to strtod bits.
    //    Source-read predictions: optional-p hex, dangling-p rollback, nan
    //    unterminated-paren rollback are LIKELY mismatches → each names its fix
    //    round; NOT corpus-prunable). ─────────────────────────────────────────
    emit("T", "0x1.8")                               // p-less hex — strtod: 1.5 (p optional)
    emit("T", "0x10")
    emit("T", "0xA")
    emit("T", "0x.8")
    emit("T", "0x1.")
    emit("T", "0x1p")                                // dangling p → strtod rolls back to "0x1"
    emit("T", "0x1p+")
    emit("T", "0x1pz")
    emit("T", "0x1.2.3p4")                           // second dot → strtod subject "0x1.2"
    emit("T", "0x1.8p1junk")
    emit("T", "nan(123")                             // unterminated → strtod: bare nan
    emit("T", "nan(12-3)")                           // non-alnum in seq → strtod: bare nan
    emit("T", "nan(0x)")
    emit("T", "0x")                                  // strtod subject "0" → 0.0
    emit("T", "0X")
    emit("T", "0xg")

    // ── E6 pathological lengths (class T) ──────────────────────────────────────
    emit("T", "0x" + rep("f", 400) + "p+0")          // 1600-bit integer part → +inf
    emit("T", "0x" + rep("f", 400) + "p-3000")       // huge sig, deep-negative exp
    emit("T", "0x0." + rep("0", 400) + "1p+0")       // deep-fraction single bit
    emit("T", "0x0." + rep("0", 400) + "1p+3000")    // deep fraction × huge exp
    emit("T", "0x1p" + rep("9", 30))                 // 30-digit exponent → clamp → +inf
    emit("T", "0x1p-" + rep("9", 30))                // → +0
    emit("T", "0x1p+" + rep("0", 20) + "4")          // leading-zero exponent digits

    // ── E7 finite-regression goldens (class F — the #4200 edge list re-driven
    //    through the COMPOSED shipped path with the tail linked) ────────────────
    emit("F", "0.1")
    emit("F", "3.14")
    emit("F", "-2.5")
    emit("F", "1.7976931348623157e308")
    emit("F", "2.2250738585072014e-308")
    emit("F", "5e-324")
    emit("F", "9007199254740993")
    emit("F", "1.0000000000000002")
    emit("F", "1e23")
    emit("F", "0.0")
    emit("F", "-0.0")
    emit("F", "1e309")
    emit("F", "-1e309")
    emit("F", "1e-400")
    emit("F", "123456789012345678")
    emit("F", "8.98846567431158e307")
    emit("F", "1e22")

    // ── E8 true junk / lenient-owned (class J — gated ON==OFF only) ────────────
    emit("J", "")
    emit("J", " ")
    emit("J", "abc")
    emit("J", "+")
    emit("J", "-")
    emit("J", ".")
    emit("J", "e5")
    emit("J", ".e5")
    emit("J", "xnan")
    emit("J", "in")
    emit("J", "n")
    emit("J", "na")
    emit("J", "- 1")
    emit("J", "++1")
    emit("J", "1.5abc")                              // decimal + junk: lenient-owned decline path
    emit("J", "0.123456789012345678abc")
    emit("J", "1e5e5")

    // ── R1 randomized hex sweep (class T, deterministic LCG) ───────────────────
    let mut r = 0
    while r < 120000 {
        emit("T", gen_random_hex())
        r = r + 1
    }

    // ── R2 randomized finite-decimal sweep (class F) ───────────────────────────
    let mut r2 = 0
    while r2 < 20000 {
        emit("F", gen_random_dec())
        r2 = r2 + 1
    }

    // ── verdict ────────────────────────────────────────────────────────────────
    println("# VERDICT T " + to_string(t_mis) + "/" + to_string(t_total))
    println("# VERDICT F " + to_string(f_mis) + "/" + to_string(f_total))
    println("# VERDICT J(informational, lenient-fallback vs strtod) " + to_string(j_dif) + "/" + to_string(j_total))
    if t_mis == 0 && f_mis == 0 {
        println("# GATE PASS (in-process vs libc strtod; re-verify with strtod_tail_oracle_ref.c)")
    } else {
        println("# GATE BLOCK — name the codegen/rounding round per mismatch family; do NOT prune the corpus")
    }
}
```

### `test/native_build/strtod_tail_oracle_ref.c`

```c
// strtod_tail_oracle_ref.c — independent re-verifier for strtod_tail_oracle.hexa.
// Reads harness lines "<cls> <tag> <got> <ora> <input-to-EOL>" from stdin and
// RECOMPUTES host strtod per input. Verifies (1) ora == strtod bits — proves the
// in-process oracle really was libc strtod; (2) class T/F: got == strtod bits —
// the flip gate, independent of the in-process compare. Full 64-bit compare incl.
// NaN sign+payload. Exit 0 = gate pass.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

int main(void) {
    char line[16384];
    long long n = 0, t_mis = 0, f_mis = 0, ora_drift = 0, shown = 0;
    while (fgets(line, sizeof line, stdin)) {
        if ((line[0] != 'T' && line[0] != 'F' && line[0] != 'J') || line[1] != ' ')
            continue;                                  // skip '#' meta lines
        char cls = line[0];
        long long got = 0, ora = 0;
        if (sscanf(line, "%*c %*s %lld %lld", &got, &ora) != 2) continue;
        char *p = line; int sp = 0;                    // input = after 4th space, verbatim
        while (*p && sp < 4) { if (*p == ' ') sp++; p++; }
        size_t L = strlen(p);
        if (L && p[L-1] == '\n') p[L-1] = 0;           // strip only the newline
        double d = strtod(p, NULL);
        long long ref; memcpy(&ref, &d, 8);
        n++;
        if (ora != ref) {
            ora_drift++;
            if (shown++ < 20) fprintf(stderr, "ORACLE-DRIFT %c ora=%lld ref=%lld [%s]\n", cls, ora, ref, p);
        }
        if ((cls == 'T' || cls == 'F') && got != ref) {
            if (cls == 'T') t_mis++; else f_mis++;
            if (shown++ < 60) fprintf(stderr, "MISMATCH %c got=%lld ref=%lld [%s]\n", cls, got, ref, p);
        }
    }
    printf("REF-VERDICT n=%lld T_mis=%lld F_mis=%lld oracle_drift=%lld\n", n, t_mis, f_mis, ora_drift);
    return (t_mis || f_mis || ora_drift) ? 1 : 0;
}
```

### `test/native_build/strtod_tail_oracle_run.sh`

```bash
#!/usr/bin/env bash
# strtod_tail_oracle_run.sh — strtod-tail flip gate (zeroc #29). Run on aiden (glibc)
# and ghost (Apple libc) from the repo root at the candidate commit.
set -uo pipefail
CC="${CC:-clang}"
HEXA="${HEXA:-hexa}"
OUT="${OUT:-/tmp/strtod_tail_gate}"
mkdir -p "$OUT"

# 1. OFF baseline runtime.a (default lanes: numf-native + EXACT ON, tail OFF)
rm -f build/float_parse_hexinfnan_native.o
CC="$CC" bash tool/stage_resolve_runtime_a >"$OUT/resolve_off.log" 2>&1 || { echo FATAL:resolve-off; exit 1; }
cp build/runtime.a "$OUT/runtime_off.a"

# 2. ON runtime.a — assembles the FROZEN self/native/float_parse_hexinfnan_*.s seed
rm -f build/float_parse_hexinfnan_native.o
CC="$CC" HEXA_RT_STRTOD_TAIL_NATIVE=1 bash tool/stage_resolve_runtime_a >"$OUT/resolve_on.log" 2>&1 || { echo FATAL:resolve-on; exit 1; }
grep -q "RT-NATIVE STRTOD-TAIL: HEXA_RT_STRTOD_TAIL_NATIVE=1" "$OUT/resolve_on.log" || { echo "FATAL: tail seed did not engage"; exit 1; }
cp build/runtime.a "$OUT/runtime_on.a"
nm "$OUT/runtime_on.a" 2>/dev/null | grep -q "T _\?rt_str_parse_float_hexinfnan" || { echo "FATAL: seed symbol missing from runtime_on.a"; exit 1; }

# 3. build the harness against EACH archive (cache cleared — stale-cache gotcha)
rm -rf ~/.hexa-cache
HEXA_PREBUILT_RUNTIME="$OUT/runtime_on.a"  "$HEXA" build test/native_build/strtod_tail_oracle.hexa -o "$OUT/tail_on"  || exit 1
rm -rf ~/.hexa-cache
HEXA_PREBUILT_RUNTIME="$OUT/runtime_off.a" "$HEXA" build test/native_build/strtod_tail_oracle.hexa -o "$OUT/tail_off" || exit 1

# 4. run (deterministic ~140k-case corpus)
"$OUT/tail_on"  > "$OUT/on.tsv"  || { echo FATAL:on-run;  exit 1; }
"$OUT/tail_off" > "$OUT/off.tsv" || { echo FATAL:off-run; exit 1; }
grep -q "^# ORACLE-OK" "$OUT/on.tsv" || { echo "FATAL: in-process oracle degraded"; head -5 "$OUT/on.tsv"; exit 1; }

# 5. independent re-verify vs real strtod (C driver) — THE GATE
"$CC" -O2 -o "$OUT/ref" test/native_build/strtod_tail_oracle_ref.c || exit 1
echo "== GATE (tail ON vs host strtod) =="
"$OUT/ref" < "$OUT/on.tsv"; GATE=$?
echo "== informational: today's OFF path vs strtod (nonzero T mismatches EXPECTED pre-flip) =="
"$OUT/ref" < "$OUT/off.tsv" || true

# 6. finite regression A/B: F+J lines must be byte-identical ON vs OFF
grep -E '^[FJ] ' "$OUT/on.tsv"  > "$OUT/fj_on"
grep -E '^[FJ] ' "$OUT/off.tsv" > "$OUT/fj_off"
if diff -q "$OUT/fj_on" "$OUT/fj_off" >/dev/null; then
    echo "FINITE-REGRESSION OK (F/J byte-identical ON vs OFF)"
else
    echo "FINITE-REGRESSION FAIL"; diff "$OUT/fj_on" "$OUT/fj_off" | head -20; GATE=1
fi
tail -4 "$OUT/on.tsv"
exit $GATE
```

## 3. Corpus recipe (deterministic)

Fixed-seed LCG `RS=20260706; RS=(RS*1103515245+12345) mod 2^31`, high bits drawn — wrap-free in i64, byte-identical corpus every run/host. ~**140,650 cases**:

| Family | Count | What it exercises (seed code path) |
|---|---|---|
| R1 randomized hex | 120,000 | sign/ws/case mix; 0–21 hex digits (≫ the 2^59 capacity → sticky, `hexinfnan.hexa:204-214`); exponent bands 60% uniform ±80, 20% subnormal −990..−1140, 10% overflow +990..1100, 10% clamp ±20000/±100000+ |
| E2 carry ladder | 133 | all-ones mantissas × 19 exponents incl. ±1023 — round-carry renormalize (`:160-163`), subnormal→normal promote (`:169`), halfway→inf |
| E3 subnormal scan | 414 | e2 sweep −1014..−1144 ×3 significands — gradual underflow, `ndrop` boundary (`:97-102`), underflow-to-zero ties |
| E1/E6 boundary + pathological | ~40 | DBL_MAX/MIN, min-subnormal, ±0, 400-digit significands, 30-digit exponents |
| E4 inf/nan surface | 42 | case forms, payload decimal/hex/`_`-seps, quiet-bit collision, u64-max/overflow payloads (`hpx_nan_payload` i64-wrap probe) |
| E5 decline-boundary | 16 | p-less hex, dangling-p, unterminated `nan(`, second dot — strtod longest-prefix rollback semantics |
| R2+E7 finite decimals (F) | 20,017 | 1–26 sig digits, e10 bands ±25 / ±280–330 / over-underflow + the #4200 golden list |
| E8 junk (J) | 17 | lenient-fallback-owned inputs, ON==OFF only |

## 4. Comparison policy + pass/block criterion

- **Bit-exact on the full 64-bit pattern, signed-i64 compare — including NaN sign and payload. No isnan-collapsing.** Justification: HexaVal preserves NaN bits (tagged struct, not nan-boxed), and the seed's own contract is glibc/Apple payload parsing (SSOT header `float_parse_hexinfnan.hexa:26-30` — musl-style payload-ignoring would be a bit-miscompile). The reference is the *linked* host libc per platform: glibc-2.39 on aiden, Apple libc on ghost (header's cross-probe says values are bit-identical across both; errno-only divergence is invisible to hexa).
- **PASS** = on **both** aiden and ghost: `REF-VERDICT … T_mis=0 F_mis=0 oracle_drift=0` (tail-ON run) **and** `FINITE-REGRESSION OK`. Then flip `stage_resolve_runtime_a:707` default-ON as the RECONVERGE-flip PR, gated additionally on 3-target byteeq + install smoke as usual.
- **BLOCK** = any T or F mismatch. Each mismatch family gets a named fix round (seed SSOT edit → `tool/regen_float_parse_hexinfnan_native_s.sh` re-bake → re-run corpus); the corpus is never pruned/tuned to green. `oracle_drift≠0` means the in-process oracle wasn't strtod — fix the harness pairing, not the seed.

## 5. Predicted mismatches (source-read, PLAUSIBLE — the run confirms)

The corpus deliberately probes five families I expect to **fail** against strtod, i.e. the gate should catch real seed defects on its first run:

1. **p-less hex** (`0x1.8` → strtod 1.5): the seed requires `p` (`hexinfnan.hexa:222-227`) citing C99 *literal* grammar, but strtod's hex grammar makes the exponent optional; decline falls to the lenient parse → 0.0.
2. **Dangling p** (`0x1p`, `0x1p+`): strtod rolls back to subject `0x1` → 1.0; seed declines (`:246`) → 0.0. Same family: `0x1.2.3p4`.
3. **nan payload paren-rollback** (`nan(123`, `nan(12-3)`): glibc requires a closing `)` over an alnum/`_` seq, else returns *bare* nan; `hpx_nan_payload` never checks the terminator (`:337-347`) → wrong payload bits.
4. **`\v`/`\f` leading whitespace** on tail-family inputs: the tail's skip set is {32,9,10,13} (`:294-297`) — missing 11/12, while strtod (and tier-1) skip full C-isspace. Not coverable from `.hexa` source (no `\v` escape evidence), so it's flagged for a one-off C-side probe or a seed-side fix; note it's equally broken pre-flip.
5. **Huge nan payloads ≥2^63**: `hpx_nan_payload` accumulates in i64; a wrapped-negative `pay % 2^51` has signed-modulo semantics vs glibc's unsigned strtoull masking.

If confirmed, the fix round is one SSOT edit cluster in `float_parse_hexinfnan.hexa` (optional-p + rollback-position semantics + `)` check + ws set + unsigned-mod payload) → seed re-bake → corpus re-run.

## 6. Exact aiden sequence

```bash
# mini: land the 3 files on a branch and push
git checkout -b oracle/strtod-tail-corpus && git add test/native_build/strtod_tail_oracle.hexa \
  test/native_build/strtod_tail_oracle_ref.c test/native_build/strtod_tail_oracle_run.sh
git commit -m "test(zeroc #29): strtod-tail flip-gate oracle corpus + A/B harness" && git push -u origin oracle/strtod-tail-corpus

# aiden (long-running → direct ssh+nohup per pool-on timeout memory):
ssh aiden
cd ~/hexa-lang-gate 2>/dev/null || git clone https://github.com/dancinlab/hexa-lang ~/hexa-lang-gate && cd ~/hexa-lang-gate
git fetch origin oracle/strtod-tail-corpus && git checkout FETCH_HEAD
nohup bash test/native_build/strtod_tail_oracle_run.sh > /tmp/tail_gate.log 2>&1 &
# later:
tail -20 /tmp/tail_gate.log     # REF-VERDICT n=… T_mis=… F_mis=… oracle_drift=… + FINITE-REGRESSION line
# ghost (Apple libc leg): same three commands with CC=clang on the darwin checkout.
```

Notes baked into the script: the ON archive is verified to actually carry the seed (`nm … T rt_str_parse_float_hexinfnan` + the resolver's engage line — a silent OFF would false-green), `~/.hexa-cache` is cleared between the two builds (stale-cache gotcha), and the harness aborts itself if `parse_float` isn't real strtod. Full artifacts land in `/tmp/strtod_tail_gate/{on,off}.tsv` for mismatch triage — every line carries the input verbatim.