# RFC061 R1c — hxlcl_strtoll overflow CONTRACT resolution (reference-matched from source)

**Date:** 2026-07-10 · **Base:** origin/main `25057d1b5` · **Status:** RESOLVED — verdict (B), with a sharper root-cause than either side of the conflict had.

---

## 0. TL;DR verdict

**(B) frozen-floor-faithful WRAP is the contract.** Do **not** add clamp/errno to the native body.

The review's framing ("libc strtoll clamp+ERANGE is the current behavior being silently changed") is **wrong about which lane ships**. Measured from source:

1. The **shipping default runtime** (single-TU `self/runtime.c`) already wraps — its `hxlcl_strtoll` is `static`, accumulates in `unsigned long long` with **no clamp and no errno** (`self/runtime.c:573-601` in the current emitted artifact; emitter SSOT `self/runtime_emit_full.hexa:598-631`), and **every** runtime caller reaches it directly: `hexa_str_parse_int` (`runtime.c:5278`, emitter `:5177`), `hexa_pinned_epoch` (`runtime.c:13538`, emitter `:13400`), JSON `_jp_parse_value` (`runtime.c:14339`, emitter `:14231`), plus the blanket macro `#define strtoll(p,e,b) hxlcl_strtoll(...)` (`runtime.c:2826`, emitter `:2874`). **libc strtoll is not even linked on the default ship path.**
2. The **hexa-rt-stdlib lane** also wraps: `self/rt/string.hexa:474` `rt_str_parse_int` does `acc = acc * base + d` (`:498`) with no clamp.
3. The **native Route C body** wraps bit-identically to the frozen floor (`stdlib/runtime/hxlcl_core.hexa:832-833` `__hx_payload_mul`/`__hx_payload_add`; two's-complement signed wrap ≡ the C body's u64 accumulation + cast, and `__hx_payload_sub(0, n)` ≡ `-(long long)n`, all 64-bit patterns identical).
4. The **only clamping implementation in the entire system** is the shim's libc delegate `long long hxlcl_strtoll(...){ return strtoll(p,e,b); }` (emitter `self/runtime_core_hxlcl_shim_emit.hexa:875`) — and it is reachable **only** on the opt-in Case-B lane (`HEXA_RT_MULTIOBJ=1`, "gated opt-IN · default OFF", `tool/stage_resolve_runtime_a:1438-1467`), because `stage_resolve_runtime_a` never passes `-DHEXA_ZEROC_SHIM_BYTEID_EMIT` (zero grep hits) so the `#ifdef HEXA_ZEROC_SHIM_BYTEID_EMIT` frozen-body branch (`shim_emit:843-874`) compiles out.

So the true picture is inverted from the review: **the shim delegate is the divergent implementation**, a latent Case-B-vs-shipping inconsistency. The `HEXA_RT_NATIVE_STRTOLL` flip does not "silently change libc semantics to wrap" — it **converges the opt-in Case-B lane back to the semantics every other lane (including the shipped product) already has**. It is a divergence *fix*, and the behavior change is sanctioned.

What the review got **right** (and what we fix):
- The harness `tool/routec_strtoll_native_verify.sh:116-137` has zero overflow points → the overflow regime is uncovered; a native-body bug there would merge silently. **Fixed below** (§3).
- The "errno-family mismatch" kill-criterion is unreachable (the [C] harness never reads errno). **Deleted and replaced** (§6) — it is also the *wrong* criterion, since the contract is errno-free.
- DEFECT 2 (live-emit at Stage 0b) is real and is the exact failure mode already root-caused for STRCMP (#4489/#4545). **Convert to frozen-seed-consume before flipping** (§4).
- Bonus defect found while verifying: the harness ends with `exit 0` unconditionally (`routec_strtoll_native_verify.sh:146-148`) — declared MEASURE-ONLY (`:31`), so any flip gate **must key on the printed `VALUE_EXACT*=YES` strings, never the exit code** (§5).

---

## 1. Evidence — what each implementation does on overflow (captured, not derived)

Frozen body compiled verbatim from `self/runtime.c:573` vs host libc (clang -O2, darwin; the arithmetic is target-independent):

```
input                    frozen (=native contract)      libc strtoll
9223372036854775808      -9223372036854775808 @19       9223372036854775807 @19  errno=34
-9223372036854775809      9223372036854775807 @20      -9223372036854775808 @20  errno=34
99999999999999999999      7766279631452241919 @20       9223372036854775807 @20  errno=34
9223372036854775807       9223372036854775807 @19       9223372036854775807 @19  errno=0
```

Two load-bearing observations:
- **endptr offsets are IDENTICAL on overflow** (libc consumes all digits too; only value+errno differ). The harness's endptr comparison vs libc therefore stays valid on every point, including overflow.
- The wrap values are fully deterministic and target-independent (pure i64/u64 two's-complement) → they can be pinned as exact expected constants on all 3 targets.

Caller-impact census (all callers, default ship path — none is clamp-dependent, none reads errno):
- `hexa_str_parse_int` (`runtime.c:5278`): overflow input → wrap value returned as hexa int. `to_int("9223372036854775808")` **already returns −9223372036854775808 in the shipped product today**. No test pins the clamp: repo-wide grep for `9223372036854775808` in test/ hits only `test/native_build/rt_parse_float_exact_byteeq.hexa:44` (float-bits usage, unrelated).
- `hexa_pinned_epoch` (`runtime.c:13538`): guarded by `v >= 0`; a wrapped-negative `SOURCE_DATE_EPOCH` is treated as unset (benign; a clamped `LLONG_MAX` pin would be equally garbage-in).
- JSON `_jp_parse_value` (`runtime.c:14339`): 63-char buf cap; overflow wraps, consistent with the `to_int` family.
- `self/rt/convert.hexa:42`, `self/rt/json.hexa:217` → `rt_str_parse_int` (`self/rt/string.hexa:474`) — wraps by construction.

Conclusion: **hexa's semantics for out-of-range integer parse is wrap**, uniformly, in every hexa-authored implementation. There is no non-errno overflow-signal mechanism to wire, because no caller wants one; adding clamp would *introduce* a shipping behavior change (release-integrity violation) and break the byte-faithfulness anchor (`hxlcl_core.hexa:718` → `runtime.c` frozen floor).

---

## 2. Edit 1 — `stdlib/runtime/hxlcl_core.hexa` (documentation hardening only; ZERO body change)

The body is correct as-is. Replace the soft trailing sentence of the header comment, `hxlcl_core.hexa:721-724`:

```
// '0'=48 '9'=57 'x'=120 'X'=88 'a'=97 'z'=122 // (…existing lines :719-721 unchanged)
-// 'A'=65 'Z'=90. The unsigned-accumulation `n = n*base + d` uses signed
-// __hx_payload_mul/_add: bit-identical to the C body for any non-overflowing
-// value (the real callers parse small env/limit strings), overflow is the same
-// wrap-UB-adjacent territory as the C body and unobserved here.
+// 'A'=65 'Z'=90. OVERFLOW CONTRACT (R1c resolution, state/hexa-own/
+// rfc061-r1c-strtoll-contract-resolution.md): out-of-range input WRAPS mod 2^64
+// (two's-complement) — signed __hx_payload_mul/_add is bit-identical to the C
+// body's `unsigned long long` accumulation + (long long) cast for ALL inputs,
+// including overflow, and __hx_payload_sub(0,n) ≡ -(long long)n. This is the
+// SHIPPING semantics (runtime.c single-TU static body + rt/string.hexa
+// rt_str_parse_int both wrap; libc is not linked on the default path) and is
+// deliberately NOT libc's LLONG_MAX/MIN clamp + ERANGE: no errno, no clamp.
+// endptr on overflow matches libc exactly (all digits consumed). Pinned wrap
+// witnesses (tool/routec_strtoll_native_verify.sh chk_wrap):
+//   "9223372036854775808"  → -9223372036854775808 @19
+//   "-9223372036854775809" →  9223372036854775807 @20
+//   "99999999999999999999" →  7766279631452241919 @20
```

Mirror note (same round or the strtoull rung): `hxlcl_strtoull` (`hxlcl_core.hexa:867`, wrap at `:968-969`) and `hxlcl_atoll` (`:1032`, wrap at `:1077-1078`) carry the same contract (libc strtoull clamps to `ULLONG_MAX`+ERANGE; frozen floor wraps mod 2^64). Apply the same one-paragraph contract note when their rungs land.

**Explicitly rejected (verdict A):** adding clamp+errno. It would (a) diverge from the frozen floor `runtime.c:573` breaking the byte-faithfulness anchor (`hxlcl_core.hexa:718`), (b) change shipped `to_int` behavior for zero demanding callers, (c) require an errno mechanism the Route C leaf class deliberately excludes (`hxlcl_core.hexa:694-696` — not the errno-store extern-data class), and (d) contradict `rt/string.hexa:498`, leaving hexa with two different parse-int semantics.

---

## 3. Edit 2 — `tool/routec_strtoll_native_verify.sh` (close the overflow blind spot)

### 3a. Add a frozen-oracle + pinned-wrap section to the [C] harness (`:102-141`)

In the heredoc `acc.c`:

**(i)** After the `extern` decl (`:105`), embed the frozen body verbatim as a second oracle (copy the 29 lines from `self/runtime.c:573-601`, renamed):

```c
/* frozen 0-libc floor body, verbatim self/runtime.c:573 (emitter runtime_emit_full.hexa:598) */
static long long frozen_strtoll(const char *nptr, char **endptr, int base) { /* …verbatim… */ }
```

**(ii)** Extend `chk()` (`:106-115`) to a 3-way check: `nv` (native) vs `lv` (libc) vs `fv` (frozen). Assert `nv == fv && no == fo` on **every** point (byte-faithfulness, the primary contract), and `nv == lv` only where libc agrees (in-range). Concretely, replace the body of `chk` with:

```c
static int chk(const char *s, int base, int *fail){
    char *ne=0, *le=0, *fe=0;
    long long nv = hxlcl_strtoll(s, &ne, base);
    long long lv = strtoll(s, &le, base);
    long long fv = frozen_strtoll(s, &fe, base);
    long no = ne?(ne-s):-1, lo = le?(le-s):-1, fo = fe?(fe-s):-1;
    if (nv != fv || no != fo){ (*fail)++;
        printf("  MISMATCH-FROZEN strtoll(\"%s\",%d) native=%lld@%ld frozen=%lld@%ld\n", s, base, nv, no, fv, fo); return 1; }
    if (nv != lv || no != lo){ (*fail)++;
        printf("  MISMATCH-LIBC strtoll(\"%s\",%d) native=%lld@%ld libc=%lld@%ld\n", s, base, nv, no, lv, lo); return 1; }
    return 0;
}
```

**(iii)** Add `chk_wrap()` — pinned expected values, frozen-oracle cross-checked, libc compared on **endptr only** (values diverge by design):

```c
static int chk_wrap(const char *s, int base, long long ev, long eo, int *fail){
    char *ne=0, *le=0, *fe=0;
    long long nv = hxlcl_strtoll(s, &ne, base);
    long long fv = frozen_strtoll(s, &fe, base);
    (void)strtoll(s, &le, base);                      /* endptr oracle only */
    long no = ne?(ne-s):-1, lo = le?(le-s):-1, fo = fe?(fe-s):-1;
    if (nv != ev || no != eo || fv != ev || fo != eo || no != lo){ (*fail)++;
        printf("  MISMATCH-WRAP strtoll(\"%s\",%d) native=%lld@%ld frozen=%lld@%ld expect=%lld@%ld libc-endp@%ld\n",
               s, base, nv, no, fv, fo, ev, eo, lo); return 1; }
    return 0;
}
```

**(iv)** In `main()` after `:134` (`chk("z",36,&fail)`), add the boundary + overflow points:

```c
    /* i64 boundary (in-range — libc agrees, errno stays 0) */
    chk("9223372036854775807",10,&fail);  n++;   /* LLONG_MAX exact */
    chk("-9223372036854775808",10,&fail); n++;   /* LLONG_MIN exact */
    /* OVERFLOW — contract = frozen-floor wrap (state/hexa-own/rfc061-r1c-strtoll-contract-resolution.md);
     * libc would clamp+ERANGE here BY DESIGN — value compared to pinned wrap constants,
     * libc consulted for endptr only (identical: all digits consumed). */
    int wfail=0;
    chk_wrap("9223372036854775808", 10, -9223372036854775807LL - 1LL, 19, &wfail); n++;
    chk_wrap("-9223372036854775809",10,  9223372036854775807LL,       20, &wfail); n++;
    chk_wrap("99999999999999999999",10,  7766279631452241919LL,       20, &wfail); n++; /* 20 digits */
    chk_wrap("170141183460469231731687303715884105727",10, -1LL, 39, &wfail); n++;      /* 39-digit (>20): (2^127-1) mod 2^64 = 2^64-1 → -1 */
    chk_wrap("0xFFFFFFFFFFFFFFFFFF",16, -1LL, 20, &wfail); n++;                          /* hex overflow: wraps to 0xFF…FF = -1 */
    fail += wfail;
    printf(wfail?"VALUE_EXACT_WRAP=NO\n":"VALUE_EXACT_WRAP=YES\n");
```

(`-9223372036854775807LL - 1LL` avoids the C `LLONG_MIN`-literal pitfall. The 39-digit and hex-overflow expectations: any string of k≥20 max-digits reduces mod 2^64; `(2^127−1) mod 2^64 = 2^64−1 → −1`; 18 F's = 72 bits → low 64 all-ones → −1. Verify once against `frozen_strtoll` when authoring — the harness itself cross-checks them.)

**(v)** Keep line `:148` `exit 0` (MEASURE-ONLY convention, `:31`), but the flip gate MUST grep the strings (§5). Also update the header comment `:20-26` ([C] section) to state the dual oracle: *"frozen-floor byte-faithfulness on ALL points (primary contract) + libc value-match on in-range points + libc endptr-match on all points; overflow VALUE intentionally diverges from libc (wrap, not clamp+ERANGE) — see state/hexa-own/rfc061-r1c-strtoll-contract-resolution.md"*.

### 3b. Success line for the gate

The harness now prints two verdict strings: `VALUE_EXACT=YES` (existing sweep) and `VALUE_EXACT_WRAP=YES` (new). Both required.

---

## 4. DEFECT 2 — convert STRTOLL (and SIGNAL) from live-emit to frozen-seed-consume: **YES, REQUIRED before the flip**

The STRTOLL block (`tool/stage_resolve_runtime_a:2006-2036`) does a Stage-0b live `--emit=asm` needing `HEXA_SELFEMIT_BIN`/`hexat`. This is *exactly* the structure root-caused as impossible-in-faithful-CI for strcmp — documented in the STRCMP block one screen above it (`stage_resolve_runtime_a:1923-1935`) and in `tool/regen_hxlcl_strstr_native_s.sh:10-24`: `build/aprime_cc` (the only binary honoring the `_drv.hexa --emit=asm … hxlcl_core.hexa` argv) needs runtime.a so it cannot exist at Stage 0b; faithful CI then resolves the emit binary to the CLI `hexa`, whose compat `cmd_run` **ignores** `--emit` → empty `.s` → the `[ -s ]` gate FATALs → **faithful RED on all 3 targets**. STRCMP/FREE/CALLOC/STRSTR/STRCHR/STRNCMP/STRDUP/REALLOC were all converted (8 existing `tool/regen_hxlcl_*_native_s.sh` tools + 3-target seeds in `self/native/`). The SIGNAL block (`stage_resolve_runtime_a:3008-3042`) has the identical defect.

**Recommendation (prereq-(a) of the flip round, mergeable independently and before the flip):**

1. `tool/regen_hxlcl_strtoll_native_s.sh` — copy `tool/regen_hxlcl_strstr_native_s.sh` verbatim, swap symbol `strstr → strtoll` (same `.globl` demotion to a 1-symbol contract, same 3 targets `darwin|x86_64|arm64-linux`, same sanity: cross-assemble + exactly 1 defined-global `hxlcl_strtoll` + no libc `U`, run `tool/isolate_native_seed.py` check). strtoll is integer-C-ABI (no fp-ABI xmm dependence), so cross-target seeds are viable now that the Route C cross-target wall is dissolved (~80 `_is_cabi` symbols wired) — bake all 3; if the arm64 lanes surface an emit gap, land x86_64-linux-seed-only with `auto` fallback on the other targets (still strictly better than live-emit).
2. Bake `self/native/hxlcl_strtoll_{x86_64,arm64-linux,arm64}.s` on the pool (aiden/summer/ghost — mini stays git/gh-only) with `build/aprime_cc`, commit the seeds.
3. Rewrite `stage_resolve_runtime_a:2006-2036` in the STRCMP tri-state shape (`:1944-1993`): `HEXA_RT_NATIVE_STRTOLL ∈ {0, auto, 1}`; seed lookup by `$TARGET`; `.globl` count gate (exactly 1); `_rn_seed_und_gate` (`:1185`) rejects non-carrier UND (the darwin `___errno_location` class); on any seed problem: `auto` → loud WARN + keep libc-shim member (strtoll stays visibly UND in the #4360 nm floor), `1` → FATAL (verify scripts). Default in the prep PR stays `0`; the flip PR moves the default to `auto`. Note: seed-consume also removes the block's build-time `objcopy` dependence (the demotion replaces `--keep-global-symbol`, `:2024-2029`).
4. **SIGNAL**: same conversion (`tool/regen_hxlcl_signal_native_s.sh` + seeds) before *its* flip; one wrinkle — the `@naked` sa_restorer trampoline: the demotion pass must keep only `hxlcl_signal` global while the trampoline label stays local-but-present (intra-.o resolution is fine, single `.s` → single `.o`, same as the strstr note), and `__hx_fn_addr` must not require an external reloc — assert with the seed's `objdump -dr` + `_rn_seed_und_gate`. Not a blocker for the strtoll flip; same defect class, file it in the same round.
5. Update the harness `[B]` section (`routec_strtoll_native_verify.sh:77-98`) in the same prep PR: verify the **seed** path (assemble `self/native/hxlcl_strtoll_$(target).s`, assert 1-symbol contract + `ST_EXT_RELOC=0`), keeping the live-emit lane only as an optional cross-check when `aprime_cc` exists.

---

## 5. The gate — exact sequence (flip = SEPARATE HELD PR)

**PR-1 (prep, default-OFF, byte-neutral — mergeable on normal CI):**
contract comment (§2) + harness overflow/frozen-oracle (§3) + regen tool + baked seeds + seed-consume conversion (§4, default `0`).
Gate: harness `[A]` prints `DEFAULT_SHIM_TEXT_BYTE_IDENTICAL=YES` (release-integrity: default shim.o/archive sha unchanged) + regular PR CI (github-hosted 3-target, required check `selfhost-gates-summary`) GREEN.

**Measurement (pool, captured output, before opening the flip PR):**
On summer (x86_64-linux): `bash tool/routec_strtoll_native_verify.sh` → require ALL of
`DEFAULT_SHIM_TEXT_BYTE_IDENTICAL=YES · SHIM_STRTOLL_MEMBER_DROPPED=YES · NATIVE_STRTOLL_SELF_CONTAINED=YES · VALUE_EXACT=YES · VALUE_EXACT_WRAP=YES`
— **grep the strings; the harness exits 0 unconditionally (`:148`), so its RC is NOT a gate.** Repeat the value sweep on ghost (darwin-arm64) and the arm64-linux lane against their seeds (the [C] value harness is host-runnable per target; the `:41` x86_64-only gate lifts once seeds exist — until then arm64 lanes gate on `auto`-fallback + nm-floor visibility).

**PR-2 (the flip — SEPARATE PR, HELD, auto-merge OFF):**
Open via `gh api` (repo hook auto-squashes `gh pr create` — feedback memory), label it held; content = default `HEXA_RT_NATIVE_STRTOLL: 0 → auto` in the Case-B lane only. Merge requires ALL:
1. **byteeq 3-target GREEN** (darwin-arm64 · linux-x86_64 · linux-arm64) — both flip-OFF (byte-identity vs main) and flip-ON (deterministic archive) lanes;
2. **`tool/release_build` ship-witness GREEN** — the faithful path calls `stage_resolve_runtime_a` WITHOUT `restore_frozen_seeds` (`stage_resolve_runtime_a:118-121`), which is precisely what live-emit broke and seed-consume fixes; the `ld -r` multidef gate (S5) validates exactly one strong `hxlcl_strtoll` def;
3. **install.sh consumer smoke GREEN** (never promote on x86-only green — release-integrity guardrail);
4. **nm-UND floor witness**: the #4360 advisory dump shows `strtoll` UND present on default, dropped on the ON lane (`SHIM_STRTOLL_MEMBER_DROPPED` at archive level);
5. default-lane archive sha unchanged vs main (release integrity — the flip is Case-B-scoped; the single-TU ship path never contained the shim member).

---

## 6. Kill-criterion (replaces the unreachable "errno-family mismatch")

The flip is RED / the native strtoll cannot replace the shim member if ANY of:

1. **Byte-faithfulness break** — `MISMATCH-FROZEN` on any sweep point (native ≠ frozen-floor value or endptr, *including* the overflow/wrap points). This is the primary contract; no waiver.
2. **In-range libc divergence** — `MISMATCH-LIBC` on any in-range point, or any endptr-offset divergence anywhere (overflow included — endptr must match libc exactly, captured §1).
3. **A clamp-dependent caller materializes** — a caller that reads errno after strtoll or asserts `to_int(overflow) == LLONG_MAX`. Census today (§1): **zero** such callers; re-run the census (grep `hxlcl_strtoll` + `__errno_location` co-occurrence, `runtime.c` + `self/rt/`) in the flip PR. If one appears, the fix belongs in *that caller* (hexa-level range check), never as clamp+errno in the leaf — the leaf contract is frozen.
4. **Seed integrity** — seed missing/multi-global/non-carrier-UND on any target with `HEXA_RT_NATIVE_STRTOLL=1` (strict), or `auto`-fallback WARN firing in the faithful release lane (a non-adopted flip must stay visible as `strtoll` in the nm floor, never silent).
5. **Gate mechanics** — any gate keyed on the harness exit code instead of the `VALUE_EXACT*=YES` strings is void (`:148 exit 0`).

Deleted: *"errno-family mismatch → RED"* — unmeasurable as written (harness never read errno) and contract-invalid (the leaf is deliberately errno-free, `hxlcl_core.hexa:694-696`; the frozen floor sets no errno; no caller reads it).

---

## 7. One-paragraph record of the sanctioned behavior delta

With `HEXA_RT_MULTIOBJ=1` **and** `HEXA_RT_NATIVE_STRTOLL=auto/1`, overflow parses on the Case-B lane change from libc clamp(LLONG_MAX/MIN)+ERANGE (shim delegate, `shim_emit:875`) to frozen-floor wrap — e.g. `to_int("9223372036854775808")`: `9223372036854775807 → −9223372036854775808`. This **matches the shipped single-TU product and `rt/string.hexa`**, closing a pre-existing three-way divergence (ship=wrap · rt-stdlib=wrap · Case-B=clamp). No hexa test, spec, or caller depends on the clamp (census §1). The same resolution pre-decides the strtoull/atoll rungs (wrap mod 2^64; libc clamps ULLONG_MAX+ERANGE).
