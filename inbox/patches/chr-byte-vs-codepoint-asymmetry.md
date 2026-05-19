# `chr(N)` produces UTF-8-encoded codepoint in interp mode but raw byte in compiled mode — asymmetric with `ord()`

**Layer:** stdlib intrinsics — `chr(int) -> string` / `ord(string) -> int`
**File(s):**
  - interp: `self/eval.hexa` (or wherever `chr` is dispatched) — the interp builds the string by encoding `N` as a Unicode codepoint via UTF-8
  - compiled: `self/codegen.hexa` / `self/runtime.c::hexa_chr` — most likely treats `N` as a raw byte and produces a length-1 string

> **VERIFIED-CLOSED 2026-05-19 — DISSOLVED-BY-INTERP-RETIREMENT (superseded, not fixed)**: This patch describes an interp-vs-compiled `chr()` ASYMMETRY. The interpreter is now RETIRED (AGENTS.tape @D g_interp_deprecated, R7 CLOSED 2026-05-19 — `self/hexa_full.hexa` / `self/eval.hexa` interp path deleted). The asymmetry premise no longer exists: compiled raw-byte `chr(N&0xFF)` is now the sole, correct semantics, and the patch's proposed "Option A (make interp's chr symmetric)" is moot — there is no interp to make symmetric. Marked DISSOLVED (superseded by interp retirement), NOT fixed. Reference @D g_interp_deprecated. Close-only marker (no source change).

**Symptom:** A string built as `chr(240) + chr(159) + chr(154) + chr(128)` is

- **interp** (`hexa run`): 8 bytes — `0xC3 0xB0 0xC2 0x9F 0xC2 0x9A 0xC2 0x80`
  (each `chr(N>=128)` UTF-8-encodes `N` as a codepoint: 240→ð=`C3 B0`, 159→`C2 9F`, …)
- **compiled** (`hexa build`): expected 4 bytes — `0xF0 0x9F 0x9A 0x80` (the raw bytes of 🚀)

`ord(substr(s, i, 1))` is byte-level in BOTH modes (verified — see `~/core/wilson/plugins/tool-image/main.hexa:341` which reads PNG magic bytes via that idiom and is exercised by both `wilson test` and `hexa run plugins/tool-image/test_*.hexa`). So the read side is consistent; only the write side diverges.

## Repro (interp mode, 2026-05-17)

```hexa
fn main() -> int {
    let s = chr(240) + chr(159) + chr(154) + chr(128)
    println("bytes len = " + str(len(s)))
    let mut i = 0
    while i < len(s) {
        println("  byte[" + str(i) + "] = " + str(ord(substr(s, i, 1))))
        i = i + 1
    }
    return 0
}
```

```
$ hexa run /tmp/chr_diag.hexa
bytes len = 8
  byte[0] = 195      # 0xC3  ← UTF-8 lead of U+00F0 (ð), not raw 0xF0
  byte[1] = 176      # 0xB0
  byte[2] = 194      # 0xC2  ← UTF-8 lead of U+009F, not raw 0x9F
  byte[3] = 159
  byte[4] = 194
  byte[5] = 154
  byte[6] = 194
  byte[7] = 128
```

Expected (and what compiled mode should produce, per byte-level `ord()` symmetry):

```
bytes len = 4
  byte[0] = 240      # 0xF0
  byte[1] = 159      # 0x9F
  byte[2] = 154      # 0x9A
  byte[3] = 128      # 0x80
```

## Downstream impact

Any code that builds binary byte sequences via `chr()` (URL-decoding, PNG/JPEG header
synthesis, escape-sequence assembly, byte-search prefixes for UTF-8 emoji detection,
checksum/CRC tables…) silently produces wrong bytes when run via `hexa run`. The same
source compiled via `hexa build` works.

Concrete bite from a wilson session 2026-05-17 — `plugins/guard-readme-format/main.hexa`
was using `chr(240) + chr(159)` as a search prefix to count UTF-8 4-byte SMP-emoji starts.
Worked under `hexa build`, silently failed under `hexa run` (selftest used the same
broken construction; only an end-to-end smoke against the real `wilson/README.md`
revealed it). Workaround landed: scan bytes via `ord(substr(s, i, 1)) == 240` instead.

Other repo grep hits using `chr(N>=128)` (potential silent bugs under interp):

- `~/core/wilson/plugins/tool-web/main.hexa:505` — `out = out + chr(b)` in URL-decoder (b parsed from `%XX` hex pairs). Works in compiled mode; under interp the decoded bytes will be misencoded for any `%80..%FF`.
- `~/core/wilson/plugins/pool/main.hexa:262,774` — `chr(10)` is fine (ASCII); other `chr()` sites should be audited.
- `~/core/wilson/plugins/harness-cli/main.hexa:109,206` — `chr(27)` / `chr(7)` ASCII control bytes, unaffected.

## Required fix

**Option A (minimal — preserve current compiled semantics):** make interp's `chr(N)` produce a length-1 string whose single byte is `N & 0xFF`, mirroring compiled behaviour. The `string` representation in interp is already byte-oriented at the `ord()`/`substr()` boundary; making `chr()` symmetric closes the loop.

**Option B (codepoint-centric):** make BOTH modes UTF-8-encode `N` as a codepoint. This breaks the byte-level `ord()/substr()` contract that `tool-image` and others rely on. Not recommended.

**Option C (typed):** introduce a separate `byte(N)` intrinsic for raw-byte construction; keep `chr(N)` codepoint-centric. Cleanest semantically but requires a documented stdlib API addition and per-call review of every existing `chr()` call.

Recommended: **A**. The compiled `chr()` semantic already matches the byte-level `ord()` semantic, and the wilson repo's existing call sites assume that interpretation.

## Why this matters

The interp ↔ compiled gap is a `cost-routing` violation in spirit: `wilson test` runs the compiled binary's 23/23, then the same selftest source under `hexa run` for the not-yet-bundled cases — and the two answers diverge silently. The asymmetry means "passes under `wilson test`" is not a strong enough signal; an interp-mode tape_driver or `hexa run plugins/<id>/test_*.hexa` can fail or false-positive on the same source. For a self-hosting agent that builds its own toolchain, the build/run distinction should be a perf/cache choice, not a semantic one.

## Authority / cross-refs

- Carry source: `~/core/wilson/plugins/guard-readme-format/main.hexa::grf_count_4byte_emoji` — the workaround comment block names the bug + cites this inbox note as the upstream fix.
- Test of the workaround: `~/core/wilson/plugins/guard-readme-format/test_guard_readme_format.hexa` — uses literal UTF-8 emoji in source (no `chr()` for high bytes) so the test passes regardless of which mode runs it.
- Wilson governance #1 (`verification-via-hexa-cli-only`) — verifier code must be hexa-native, but if the same hexa-native code produces different bytes in interp vs compiled, the verifier's self-consistency is at risk; this patch closes that gap.

## Selftest delta (estimated)

`+1` for a new `self/test/test_chr_byte_level.hexa` (or wherever chr/ord round-tripping is exercised) — `chr(240)` then `ord(substr(s,0,1))` round-trip = 240 in both modes.
