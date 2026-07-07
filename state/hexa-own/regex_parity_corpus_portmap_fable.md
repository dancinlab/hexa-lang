All source reads are complete and every claim below is pinned at `ab79e1f64`. Local probe execution was denied (this session is read-only + git, per the wt-* lockout policy), so the libc claims that need empirical confirmation are packaged as a mandatory step-0 probe in run.sh — each is flagged **[MEASURE]** below.

---

# Regex OFF-vs-ON parity corpus — 1:1 port map @ ab79e1f64

**HEAD confirmed:** `ab79e1f64` (= the requested ref; the regex-relevant files are byte-identical to the 9d1e4d3c7 scope — all its cites re-verified, with the handful of drifts noted inline).

## 1. The 6 surface builtins (deliverable 5)

Builtin recognition gate: `self/codegen.hexa:14155` `_is_builtin_name` → regex entries at `:14337-14342`. Lowering: 2-arg at `self/codegen.hexa:8186-8190`, 3-arg `regex_replace` at `:8246`. 1-arg regex forms are invalid (comment `:7966`). These are the only regex builtins — there is no capture/group surface.

| builtin (.hexa) | lowers to | returns | compile-fail value | non-string arg value |
|---|---|---|---|---|
| `regex_match(pat, s)` | `hexa_regex_match` | `bool` (unanchored **search presence**, `nmatch=0`) | `false` (:13863) | `false` (:13855) |
| `regex_match_full(pat, s)` | `hexa_regex_match_full` | `bool` (`rm_so==0 && rm_eo==strlen`) | `false` (:13882) | `false` (:13875) |
| `regex_search(pat, s)` | `hexa_regex_search` | `[int]` = `[so, eo]` or `[]` | `[]` (:13903) | `[]` (:13896) |
| `regex_findall(pat, s)` | `hexa_regex_findall` | `[[int]]` of `[so, eo]` (absolute) | `[]` (:13929) | `[]` (:13921) |
| `regex_split(pat, s)` | `hexa_regex_split` | `[string]` | `[s]` whole string (:13964-13967) | `[]` (:13957) |
| `regex_replace(pat, s, repl)` | `hexa_regex_replace` | `string` | `s` unchanged (:14007) | `s_v` unchanged (:13998) |

OFF bodies: `self/runtime_emit_full.hexa` :13854 / :13874 / :13895 / :13919 / :13955 / :13997. ON shims: `stdlib/runtime/regex_rt.hexa` `rt_regex_match:188`, `rt_regex_match_full:205`, `rt_regex_search:223`, `rt_regex_findall:243`, `rt_regex_split:275`, `rt_regex_replace:317`. Note `regex_match` is **search-presence**, not anchored (shim comment :185-186 mirrors `regexec(nmatch=0)` at :13864).

## 2. Captures ABI verdict (deliverable 4)

**Confirmed: capture groups are NOT surfaced. `nmatch ≤ 1` everywhere; whole-match spans only. The corpus must not test captures.**

- OFF: `regexec(&re, s, 0, NULL, 0)` (:13864 — match); `regexec(..., 1, &m, ...)` at :13884, :13906, :13934, :13972, :14019 — only `m.rm_so/rm_eo` (group 0) ever read; group spans never cross the ABI.
- ON: return types are `bool / [int] / [[int]] / [string] / string` (regex_rt.hexa :188-356) — no ovector anywhere.
- A capture API **does** exist, but only at the stdlib-library level, reachable via explicit `use "stdlib/regex/thompson"`: `regex_compile_captures:484`, `regex_captures:498`, `regex_cap_count:508`, `regex_cap_span:514`, `regex_cap_text:523` (thompson.hexa), backed by `bt_search_captures` (backtrack.hexa:816). `self/test_regex_captures.hexa` exercises that library surface, not the 6 builtins. Out of corpus scope (matches the skeleton's "sub-group parity = separate engine-internal follow-on").

## 3. `re_prep()` port map (deliverable 1) — with a load-bearing correction

### 3.0 CORRECTION: there are TWO preps, and the C oracle must port the OFF one, not the shim one

The skeleton's oracle comment ("the C oracle must apply FIX-C + FIX-D so golden==OFF-ledger") is **wrong**. The OFF-path libc bodies do **no** FIX-C rewrite and **no** FIX-D reject — their entire pre-transform is `_hexa_re_strip_flags` (:13840-13847) + `regcomp(REG_EXTENDED[|REG_ICASE])` (:13833-13837). Requirement 3a is `golden.txt == off_ledger.txt`; the only way that holds by construction is for the oracle to be a **verbatim port of the OFF bodies and nothing more**. If the oracle added the shim's FIX-D reject, golden would diverge from the OFF-ledger on any libc that *accepts* a backref — and glibc ERE is documented to accept `\1` as a GNU extension **[MEASURE, probe row 1]**. FIX-C in the oracle is semantically redundant at best and masks the very C7 parity question the corpus exists to answer.

So:

### 3.1 `re_prep()` for the C oracle = the OFF-body prep, verbatim

Port of `:13840-13847` + `:13833-13837`, exactly:

```c
/* _hexa_re_strip_flags (runtime_emit_full.hexa:13840-13847), verbatim */
static const char* re_strip_flags(const char* pat, int* icase) {
    *icase = 0;
    if (pat && pat[0] == '(' && pat[1] == '?' && pat[2] == 'i' && pat[3] == ')') {
        *icase = 1;
        return pat + 4;
    }
    return pat;
}
/* _hexa_re_compile (:13833-13837), verbatim */
static int re_compile(const char* pat, regex_t* out, int icase) {
    int flags = REG_EXTENDED;
    if (icase) flags |= REG_ICASE;
    return regcomp(out, pat, flags);
}
```

Rules, stated precisely: strip **exactly one** leading `(?i)` (bytes `( ? i )` at positions 0-3; the C version relies on `&&` short-circuit + NUL termination instead of a length check — the .hexa mirror `_rt_re_strip_iflag:76-82` checks `n >= 4`, same semantics). No other inline flags exist. Nothing else is rewritten. Nothing is rejected — regcomp's own return code is the OFF truth for every construct.

### 3.2 The ON shim prep, spec'd exactly (needed for the allowlist docs and divergence prediction, NOT for oracle code)

Per-op order (identical in all 6 shims, e.g. rt_regex_match :192-198):

1. **FIX-D reject probe on the RAW pattern** (before the `(?i)` strip) — `_rt_re_has_backref_lookaround(pat_raw)` :132-164. Reject (→ return the op's compile-fail value, table §1) iff:
   - `\` followed by byte 49-57 (`\1`..`\9`) **outside a bracket class** (:137-144); escape skips 2 bytes;
   - bracket classes are skipped whole, with `[^`-leading (:147) and literal-`]`-first (:148) handling and 2-byte escape skip inside (:149-151);
   - `(?` followed by `=` (61), `!` (33), or `<` (60) (:155-159). `(?` + anything else (e.g. `(?:`) is NOT rejected — it flows to the engine and compile-fails there (thompson parses `(`+`?` as a bad repeat), which mirrors libc's `REG_BADRPT` on `(?:` — both sides land on the compile-fail value.
   - Deliberately does NOT trigger on `{`+digit (the FIX-A interval route) — :126-130.
2. **`(?i)` strip** — `_rt_re_strip_iflag:76-82`: one leading `(?i)` → `icase=1`.
3. **FIX-C PCRE-literal rewrite** — `_rt_re_pcre_literal:94-121`: scanning byte-wise, `\` + one of `d D w W s S` (bytes 100/68/119/87/115/83) **outside a bracket class** → replaced by the bare second byte (:104-108). Every other 2-byte escape is copied through verbatim (:109-113). A trailing lone `\` at end-of-pattern is copied as-is (falls through to :117). Class tracking here is the **simple** form: `[` opens, first `]` closes (:115-116) — note it does **not** special-case `[^` / leading `]` the way the reject probe does; a pattern like `[]\d]` is handled differently by the two scanners (prep thinks the class closed at the first `]`). Keep such patterns out of the corpus (documented corner, not exercised).
4. **icase fold** — iff icase, `_rt_re_ascii_fold:61-70` maps every byte 65-90 → +32 (index-preserving), applied to the pattern **after** FIX-C (order fixed at `_rt_re_prep_pat:171-177`: strip → pcre_literal → fold) and to the **subject** (per-op, e.g. :197, :213, :231-232, :252-253, :293-294, :330-331). Split/replace match against the folded copy but slice/copy the ORIGINAL subject (:293, :303, :330, :342-347).
5. Compile with `regex_compile` (thompson.hexa:427 → `regex_compile_capped:436`), which routes to the backtrack VM iff `bt_needs_backtrack:105` fires (`{`+digit :140, backref, lookaround), else the Thompson NFA (POSIX leftmost-longest, `_re_longest_from:593`). `!regex_valid(re)` → the op's compile-fail value.

## 4. The 3 from-offset op-loops, 1:1 (deliverable 2)

All previously-cited line numbers hold verbatim at ab79e1f64. The C harvester ports these **exactly** — the key mechanical detail is that libc `rm_so/rm_eo` are **relative to `s + off`** (the shim's `regex_search_from` counterpart returns absolute spans; do not copy the shim's bookkeeping into C).

**findall** (`:13930-13945`):
```c
regmatch_t m; size_t off = 0, L = strlen(s);
while (off <= L) {
    if (regexec(&re, s + off, 1, &m, off > 0 ? REG_NOTBOL : 0) != 0) break;
    if (m.rm_eo == m.rm_so) { off += 1; continue; }          /* zero-width: skip, no emit */
    emit_pair(off + m.rm_so, off + m.rm_eo);                  /* ABSOLUTE spans (:13941-13942) */
    off += m.rm_eo;                                           /* relative advance (:13944) */
}
```

**split** (`:13968-13987`):
```c
regmatch_t m; size_t off = 0, L = strlen(s);
while (off <= L) {
    if (regexec(&re, s + off, 1, &m, off > 0 ? REG_NOTBOL : 0) != 0) break;
    if (m.rm_eo == m.rm_so) { off += 1; continue; }           /* zero-width: NO segment (:13973) */
    emit_segment(s + off, (size_t)m.rm_so);                   /* seg = s[off .. off+rm_so) (:13974-13980) */
    off += m.rm_eo;                                           /* (:13982) */
}
if (off <= L) emit_segment(s + off, L - off);                 /* final tail (:13985-13987) */
/* compile-fail: emit the whole s as the single segment (:13964-13967) */
```

**replace** (`:14017-14051`):
```c
regmatch_t m; size_t off = 0, L = strlen(s);
while (off <= L) {
    if (regexec(&re, s + off, 1, &m, off > 0 ? REG_NOTBOL : 0) != 0) break;
    if (m.rm_eo == m.rm_so) {                                 /* zero-width: copy ONE byte, advance (:14020-14025) */
        append_byte(s[off]); off += 1; continue;
    }
    append_bytes(s + off, (size_t)m.rm_so);                   /* unmatched prefix (:14036-14037) */
    append_bytes(repl, Rlen);                                 /* replacement, no backrefs (:14038-14039) */
    off += m.rm_eo;                                           /* (:14040) */
}
append_bytes(s + off, L - off);                               /* tail (:14043-14050) */
/* compile-fail: result = s unchanged (:14007) */
```
(Use any growing buffer — byte-for-byte output equality is the contract, not the OFF body's cap arithmetic.)

`REG_NOTBOL` equivalence on the ON side is already engineered: thompson `regex_search_from:704-740` handles `notbol` explicitly (`^` = `pos==0`, suppression corner at :727-733); the bt route (`bt_search_from:867`, **no notbol param**) is equivalent because bt's `^` is `si == 0` on the **absolute** index (backtrack.hexa:604-607), which can never fire for `off > 0`. `$` is absolute-end on both sides (bt :608-611 vs libc `$` at end of `s+off` = same absolute end).

### ⚠️ REAL pre-existing OFF-path defect found while porting: replace × zero-width-at-end-of-string crashes

In the OFF `hexa_regex_replace`, a pattern that zero-width-matches the empty tail (e.g. `a*`, `a?`, `$`, `(a|)` — anything nullable, on ANY subject) reaches `off == L`, takes the zero-width branch, copies the NUL (`out_buf[op++] = s[L]`, :14023) and sets `off = L + 1` (:14024). The loop exits and `size_t tail = L - off;` (:14043) **underflows to SIZE_MAX** → `hxlcl_memcpy(out_buf + op, s + off, tail)` (:14049) → segfault. Concretely `regex_replace("$", "abc", "X")` or `regex_replace("a*", "b", "X")` crashes the OFF runtime. The ON shim guards both spots (`if off < L` :341, `if off <= L` :352) and does not crash.

Corpus consequence: **exclude nullable patterns from `replace` rows** (the skeleton's C4 op-set — findall/split/search — already implicitly does this; make it explicit in the class table with this citation). The crash itself is a genuine byte-**changing** fix in the frozen `#else` arm → its own gated follow-on round, NOT this corpus PR. The oracle, being a verbatim port, would crash identically — one more reason the exclusion lives at corpus-generation time.

## 5. D1 disposition — the call (deliverable 3)

### The grounded mechanics

- FIX-A routes `{`+digit to the backtrack VM: `bt_needs_backtrack` — backtrack.hexa:105, interval clause :140 (`c==123 && next byte in 48..57`), rationale comment :133-139 (thompson has no interval parser; a bare `{` non-quantifier stays Thompson = literal, matching glibc).
- The backtrack VM is **by-design leftmost greedy-FIRST (PCRE/Perl), not POSIX leftmost-longest** — the engine's own "honest record" doc, backtrack.hexa:39-41. Execution: REPEAT dispatch `kind==11` :657 → `_bt_run_repeat:755` — mandatory reps first (:757-760), then greedy "one more rep" preference (:761-767, with the zero-width progress guard `more > si` :766), falling back to `rest`. Leftmost across starts: `bt_search:792` scans start 0..n, first success wins; `bt_search_from:867` same from `off`.
- The Thompson route (every non-interval, non-backref/lookaround pattern) is POSIX leftmost-longest: `_re_longest_from:593-624`, `regex_search:655-666` — matching libc regexec's whole-match tie-break, so all C-classes are parity-clean by construction.
- Canonical diverging row: `(a|ab){1,2}` on `"aab"` → native greedy-first `(0,2)` (rep1=`a`, rep2=`a`, alt prefers first branch) vs libc leftmost-longest `(0,3)` (`a`+`ab`) **[MEASURE — glibc's interval+alternation longest behavior has known historical bugs; probe row confirms the expected `(0,3)` per host]**.

### The call: **(a) intentional-divergence allowlist entry — do NOT fix the engine in this round.**

Justification:

1. **The divergence is scoped to order-vs-length disagreement inside the repeated group** — alternation where a shorter branch precedes a viable longer one. Plain literal/class intervals (`a{1,2}`, `[0-9]{2,4}`, `(ab){2}`) are parity-clean and belong in the **C-class** (parity-required), not D1. The divergence family is narrow and never exercised by the self-host closure (0 regex) or the shipped toolchain.
2. **Fixing the backtrack VM to POSIX-longest is the wrong fix**: longest-match backtracking = exhaustive alternative enumeration, which detonates against the REDOS step-budget design (default cap 1e6, thompson.hexa:97; `_BT_MAX_REPEAT=100000`, backtrack.hexa:275; hardened per verdict `F-OP113-REGEX-REDOS-REPEAT-CAP`) and would silently change semantics for the VM's *public* stdlib callers, whose backref/lookaround flavor is PCRE-order by contract (backtrack.hexa:40-41 states greedy-first is "the correct/expected semantics for the … flavor this engine serves").
3. **The honest erasure fix is a different, named round**: teach Thompson intervals by bounded syntactic expansion (`child{n,m}` → `child^n (child?)^(m−n)`, `child{n,}` → `child^n child*`), capped (e.g. `max ≤ 64`; larger stays bt-routed). That keeps linear-time POSIX-longest for the entire D1 family and would **empty** the D1 class — at which point gate 3c ("every allowlisted D must actually diverge") flips RED on D1 and forces the allowlist entry's removal. The gate design is self-ratcheting; the allowlist is a measured waypoint, not a permanent exemption.

### D2 correction — the skeleton's example is FALSIFIED by source

The skeleton allowlist says `(?i)[A-Z]` on `'abc'` → "libc M:1 vs native M:0". **Wrong**: `_rt_re_ascii_fold` folds *every* byte of the pattern **including bracket-class contents** (`[A-Z]` → `[a-z]`) and folds the subject — so `(?i)[A-Z]` on `abc`/`ABC` matches on BOTH sides. The fold-translate strategy is actually equivalent to libc REG_ICASE widening for pure-alpha ranges, mixed literal members, and negated alpha classes. The REAL D2 rows are ranges the endpoint-fold corrupts:

- **Order-inverting endpoints**: `(?i)[X-b]` → folds to `[x-b]` (120 > 98, invalid/empty range) → ON compile-fail (or never-match) vs libc valid + icase-widened match on `a`.
- **Block-crossing ranges**: `(?i)[;-Z]` (59-90) → folds to `[;-z]` (59-122), which wrongly gains `[ \ ] ^ _ `` ` `` (91-96) — diverges on subject `"^"` (libc: no-match; ON: match).
- (Sibling, keep OUT of the corpus, document only: `(?i)\X`-style escaped-uppercase — the fold rewrites the escape identity, e.g. `\N`→`\n`; FIX-C protects only `\d\D\w\W\s\S`.)

The shim header's KNOWN-DIVERGENCE note (regex_rt.hexa:42-45) survives, but its example needs the same correction — worth folding into the PR's :5 stale-header edit.

### C9 split + new D3 (pending probe)

FIX-D bundles two constructs whose libc-side truth likely **differs per libc**:
- **Lookaround `(?= (?! (?<`**: `(` followed by `?` is a bad-repeat in ERE → regcomp fails on both glibc and BSD **[MEASURE]** → shim's reject mirrors both → keep as parity-required **C9**.
- **Backrefs `\1..\9`**: glibc ERE **accepts** them (GNU extension — `grep -E '(a)\1'` matches), darwin/BSD rejects **[MEASURE — decisive]**. If confirmed: on glibc the OFF path *matches with backref semantics* while the shim rejects → real divergence; on darwin both reject → agreement. Backref rows therefore move out of C9 into a per-target **D3** allowlist entry.

### allowlist.txt — exact content

```
# test/native_build/regex_intentional_divergence.txt
# zero-c #29 regex OFF(libc/POSIX)-vs-ON(native NFA) intentional-divergence allowlist.
# Any ON!=OFF diff whose corpus TAG is NOT listed here is a parity FAILURE.
# Gate 3c: every D-class listed here MUST actually appear in the on-vs-off diff
# (on at least one row) — a silently-agreeing D-class is RED (stale allowlist).

D1  {n,m} counted-repeat = leftmost GREEDY-FIRST (PCRE) not leftmost-LONGEST (POSIX).
    ROOT: stdlib/regex/backtrack.hexa:140 (FIX-A routes '{'+digit to the backtrack VM;
    rationale :133-139) -> REPEAT dispatch :657 -> _bt_run_repeat :755 (greedy
    prefer-one-more :761-767). By-design PCRE order: backtrack.hexa:39-41.
    Thompson (all non-interval routes) is POSIX-longest: thompson.hexa:593/:655.
    SCOPE: diverges only when a shorter alternation branch precedes a viable longer
    one inside the repeated group. Plain literal/class intervals are C-class.
    EXAMPLE: (a|ab){1,2} on 'aab' -> native S:0,2 vs libc S:0,3 (ops search/findall/full).
    DISPOSITION: intentional (PCRE-by-design; POSIX-longest backtracking would break
    the REDOS step-budget contract, F-OP113-REGEX-REDOS-REPEAT-CAP). ERASURE ROUND
    (named, separate PR): thompson bounded interval expansion (child^n (child?)^(m-n),
    cap max<=64, larger stays bt-routed) -> empties D1; gate 3c then forces removal.

D2  (?i) + fold-corrupting character-class RANGES.
    ROOT: stdlib/runtime/regex_rt.hexa:61-70 (_rt_re_ascii_fold rewrites class-range
    endpoint bytes: [A-Z]->[a-z]) + :42-45 (KNOWN DIVERGENCE header). Pure-alpha
    ranges/members/negations TRANSLATE correctly (parity-clean, C8); the divergence
    is (i) order-inverting endpoints: (?i)[X-b] -> [x-b] invalid -> ON compile-fail
    vs libc icase match; (ii) block-crossing ranges: (?i)[;-Z] -> [;-z] gains bytes
    91-96 -> ON matches '^' where libc does not.
    EXAMPLE: (?i)[;-Z] on '^' -> libc M:0 vs native M:1.

D3  ERE backreference acceptance is PER-LIBC (glibc GNU-extension ACCEPTS \1..\9;
    darwin/BSD rejects; shim rejects both: regex_rt.hexa:132-164 FIX-D).
    ROOT: runtime_emit_full.hexa:13833-13836 passes the pattern to regcomp verbatim
    (no reject) -> OFF truth = host regcomp. CONFIRM via run.sh step-0 probe; if
    glibc accepts, D3 rows diverge on linux targets and agree on darwin (both are
    ACCOUNTED outcomes; gate 3c applies per-target).
    EXAMPLE: (a)\1 on 'aa' -> glibc OFF M:1 vs native M:0; darwin OFF M:0 == native.
```

## 6. Skeleton corrections (delta vs `state/hexa-own/done_byteneutral_impl_specs.md` round 3)

1. **Oracle prep scope** — §3.0 above: oracle ports the OFF bodies only (strip-flags + regcomp); FIX-C/FIX-D must NOT be in the oracle. This changes the oracle skeleton's `harvest()` comment block.
2. **D2 example falsified** — §5; replace the allowlist entry and the corpus D2 rows with the fold-corrupting ranges.
3. **C9 split** — lookaround stays C-class; backref rows become D3, keyed to the step-0 probe.
4. **run.sh: drop the `regen_regex_rt_native_s.sh` call.** The resolver assembles the frozen git-tracked seed itself (`tool/stage_resolve_runtime_a:764-800`, seed map :773-778, 6-symbol contract check :783-789, assemble at :793, success line :795). regen requires the native emitter and its actual arg convention is `[darwin|x86_64|arm64-linux|all]` (script header), not the skeleton's `uname -m | sed` guess. ON build = ensure `self/native/regex_rt_{arm64,x86_64,arm64-linux}.s` present and grep BOTH seed-presence lines: `:795` ("assembled build/regex_rt_native.o from …") and `:1375` ("HEXA_REGEX_NATIVE=1; ar'ing …"). OFF build = `HEXA_REGEX_NATIVE=0` (resolver exits at :762; the `-D` at :1372-1373 stays off since the env default there is `:-0`).
5. **replace × nullable patterns excluded** (OFF-path crash, §4) — and the crash filed as its own follow-on fix round (byte-changing, gated).
6. **Exclude from the corpus**: empty pattern `""` (glibc accepts zero-width vs BSD `REG_EMPTY` reject → the ON engine would agree with only one of them); `a{,2}` (GNU `{0,2}` interpretation risk); `[]…]`-style leading-`]` classes combined with `\d` (prep-vs-probe class-tracker mismatch, §3.2 rule 3). Include as C-class: literal `a{`, `a{x` (non-digit after `{` stays Thompson-literal per :140 guard, matching glibc's literal-`{`).
7. **Stale line cites refreshed**: everything the scope cited holds verbatim except `regex_compile_capped` is thompson.hexa:**436** (the `bt_needs_backtrack` dispatch is :437) and the stage seed-assembly emit lines are :**793/:795** (old scope said :788/:795/:797).
8. **run.sh step-0 probe (new, mandatory)** — compile a ~25-row `regcomp/regexec` probe on each pool host before the corpus run and assert, per host: `(a)\1` acceptance (decides D3), `(?=a)/(?!a)/(?<=a)` rejection, `\d \w \s \S` literal-second-char behavior (validates FIX-C / C7 — glibc may implement `\w`/`\s` as GNU operators, which would falsify the shim header's claim), `(a|ab){1,2}`→`(0,3)` leftmost-longest (validates D1's diverging row exists), `[;-Z]` icase on `^` and `[X-b]` icase (validates D2 rows), `""` and `a{2,1}` compile results. I attempted this probe locally and via ssh — both denied in this session (mini is read-only+git per policy), so these ship as gate assertions, not assumptions.

**Everything else in the skeleton stands as re-verified**: flag polarity `:-1` at stage:762 / seed short-circuit :763 / `-D` emission :1372-1375; the corpus grammar and driver skeleton (all driver builtins exist as cited); `HEXA_PREBUILT_RUNTIME` + `rm -rf ~/.hexa-cache` seam; the pool 3-target gate; the regex_rt.hexa:5-7 stale "Default-OFF" header edit (extend it with the D2-example correction from §5). With §3-§6 applied, the 4 files have zero stubs left to invent.