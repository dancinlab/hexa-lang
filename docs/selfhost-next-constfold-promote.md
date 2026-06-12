# SELFHOST-NEXT — const-fold + atof + vsnprintf seed-promote bundle

**Status:** 🟠 DEFERRED — blocked on a frozen-seed re-pin (build-host work, NOT 0-pod).
**Owner axis:** SELFHOST-NEXT / build-host (not HEXA-0POD's $0 local loop).
**Consolidates:** OP-37b · OP-40 · OP-44 (three landed source fixes) + OP-39b (the gate flip) — see
`.verdicts/hexa-0pod/F-OP37B-HOST-ATOF-CORRECT-ROUND.txt`, `F-OP40-COMPTIME-MUL-ULP.txt`,
`F-OP44-VSNPRINTF-CORRECT-ROUND.txt`, `F-OP39B-SEED-PROMOTE-FLIP.txt`, `F-OP39-CONSTFOLD-CI-GATE.txt`.

---

## 0. Why this doc exists (one item, not four scattered DEFERs)

Three independently-verified float-correctness fixes — OP-37b (host atof), OP-40 (const-fold serialize),
OP-44 (runtime float formatter) — are **correct in tracked source / proven-correct as a recipe**, but
**none can be observed by CI** because CI's toolchain is built from an **immutable frozen-seed git anchor**
that pre-dates all three. A fourth item, OP-39b, is the *consequence*: the OP-39 const-fold CI gate is wired
**advisory** (`continue-on-error: true`) precisely because the seed still carries the pre-fix const-folder.

Each verdict separately concluded "needs the frozen-anchor re-pin (build_selfhost.sh ladder + gen3→gen4
byte-eq + `FROZEN_SEED_REF` bump) — out of 0-pod scope." That is **one shared blocker**, so this doc is the
**single runbook** a build-host session follows to land all three fixes + flip the gate in **one coherent
promote bundle**, instead of three scattered re-derivations.

---

## 1. The promote mechanism (what "the seed" actually is)

CI does NOT build from tracked source. It bootstraps from a frozen git blob:

```
tool/restore_frozen_seeds   FROZEN_SEED_REF=151c52c82502e93d01735c58b43b017d102fee63
  → git checkout 151c52c8 -- self/native/hexa_cc.c   (the C-transpiler seed; gitignored in the live tree)
  → git checkout 151c52c8 -- self/runtime.c (+ its ~19 #include fragments)   (the C runtime; gitignored)
tool/stage_prebuild_hexat   clang hexa_cc.c + runtime.a → build/hexat   (CI's ./hexa)
```

- `self/native/hexa_cc.c` is **gitignored** (`.gitignore:286`) and **absent from HEAD** — there is no tracked
  working-tree file to "regenerate and commit". `self/runtime.c` is likewise the gitignored frozen blob
  (`self/runtime.c.hexanoport`: "Cannot be ported to .hexa (it IS the bootstrap runtime)").
- `151c52c8` is the **immutable `.c`-graduation parent** (parent of `7906951c0` / #2065, "tracked .c = 0"),
  deliberately pinned so every platform bootstraps reproducibly. **You cannot edit a past commit.**
- The ONLY way to put a fix into CI's seed is to **re-pin `FROZEN_SEED_REF`** to a NEW graduation-style anchor
  carrying a mutually-coherent fresh snapshot of all bootstrap seeds (regenerated `hexa_cc.c` from current
  `self/codegen.hexa` + a coherent `self/runtime.c` + the ~20 native fragments + `forge_tier_v1.c`).
- `FROZEN_SEED_REF=151c52c8` is hardcoded in ~7 build scripts: `tool/restore_frozen_seeds`,
  `tool/stage_resolve_runtime_a`, `tool/SELFHOST_PROMOTE_RUNBOOK.md`, `tool/clm/build_clmprod_tf32_e2e.sh`
  (grep `151c52c8` before the bump to catch them all).

**Magnitude of the re-pin (measured, OP-39b):** regen of `hexa_cc.c` from current `self/codegen.hexa` =
2,098,186 B / 31,222 lines; frozen seed @151c52c8 = 1,854,825 B / 28,482 lines →
**diff = 27,068 changed lines** of *unrelated* compiler evolution (the const-fold helper family
`_cf_negate_float_text` / `_cf_float_node` does not even exist in the frozen seed). This is why it is a
wholesale anchor refresh, not a surgical cherry-pick — and why it belongs to a build-host session, not the
$0 0-pod loop.

---

## 2. The THREE source fixes that must flow into the seed

All three are **already landed / proven in tracked source**; the seed promote is the only thing that makes
CI and the deployed toolchain observe them. Locations + the golden-value change each causes:

### (a) OP-37b — host atof correct-round (PARSE side)
- **File / site:** `self/codegen.hexa` — `_cf_as_float(lit)` (FloatLit branch).
- **Change:** parse the const-fold operand via `lit.value.parse_float()` (→ `hexa_str_parse_float` → libc
  `strtod`, correctly-rounded) instead of `to_float(lit.value)` (→ `__hx_to_double` → `hxlcl_atof`, the naive
  digit-accumulator at frozen `self/runtime.c:270`, ≤1 ULP/operand). Plus: `abs` float-fold preserves exact
  source text (the one remaining direct `to_float` site in the computed-fold family).
- **Golden change:** computed-fold operands become **byte-exact** (e.g. `0.254829592` → bits
  `4598262221740202622`); residual on `let a = 1.5*0.1`-class folds drops **MAX 3 ULP → MAX 1 ULP**.
- **Runtime edit?** NO — selects the already-present `strtod` path; no `hxlcl_atof` rewrite needed.

### (b) OP-40 — const-fold serialize via bit-exact hex-float (SERIALIZE side)
- **File / site:** `self/codegen.hexa` — `_cf_float_node(f)` now routes through new `_cf_float_hexlit(f)` (+
  `_cf_nib_hex`), +86/−9, no deletions.
- **Change:** serialize the folded double as a **bit-exact C99 hex-float literal** (`0x1.<mant>p<exp>`) built
  from raw IEEE-754 bits with **integer ops only** (no decimal formatting). clang parses a hex-float to the
  EXACT double it names → bypasses the lossy hand-rolled `%.17e` formatter entirely.
- **Golden change:** every computed const-fold byte-matches python's correctly-rounded IEEE double —
  residual **MAX 1 ULP (16/125 cases) → MAX 0 ULP (0/125)**. Folded float consts now read as
  `hexa_float(0x1.28f3dbedf555ep-4)` instead of `hexa_float(7.24…e-02)` (exact, `%a`-decodable). This is the
  golden the OP-39 gate locks (`tool/op39_constfold_gate.sh`, 13 bit-pattern goldens).
- **Runtime edit?** NO — pure codegen serialize change.

### (c) OP-44 — runtime float formatter `hxlcl_vsnprintf` correct-round (DISPLAY side)
- **File / site:** `self/runtime.c` (the **frozen blob** — `hxlcl_vsnprintf` body @ `runtime.c:657`, float
  branch `conv∈{e,f,g,E,F,G}` @ `:722`, `#define snprintf hxlcl_snprintf` mask @ `:2095`). **There is NO
  tracked SSOT emitter** — the codegen.hexa references are comments only. This fix can ONLY land *inside* the
  re-pinned runtime.c successor revision (which is exactly why it's bundled here).
- **Change (the validated recipe):**
  1. Capture the real libc `snprintf` BEFORE the line-2095 mask, e.g.
     `static int (*const hxlcl_real_snprintf)(char*,size_t,const char*,...) = snprintf;` placed above the
     `#define` (where the libc symbol is still visible). libc/libm is already linked (`-lm`, full libc; the
     runtime already makes 36 direct libm calls per the `stdlib_trig_libm` directive).
  2. Replace the `hxlcl_vsnprintf` float branch body with a delegation: rebuild the spec (`%`, optional
     `.<prec>`, conv) and call `hxlcl_real_snprintf(fbuf, sizeof fbuf, spec, dv)`; keep the existing
     width/pad post-format code. (~10 C lines — the symmetric inverse of OP-37b's atof→strtod.)
- **Golden change:** fixes EVERY high-precision runtime float print. Measured defect = **62.6% of doubles
  print a non-round-trip `%.17g` string, `%.17e` drifts up to 5 ULP, 91.3% diverge from libc**; delegation
  closes both to **0/0**. libc's correctly-rounded decimal is unique → identical across glibc/musl/macos, so
  this **preserves cross-platform determinism** (does NOT introduce a platform-dependent decimal).
- **Const-fold interaction:** OP-40 already hex-floats the determinism-sensitive const-fold path, so this fix
  does **NOT** churn any const-fold golden — it only improves display callers (and re-bakes display goldens,
  §3 step 6).

---

## 3. The ONE promote procedure (lands all three at once)

Run on a **build host** (e.g. ghost, macOS arm64) per `tool/SELFHOST_PROMOTE_RUNBOOK.md`. NOT 0-pod, NOT
vast — a self-host-anchor refresh.

1. **Apply OP-44 to the runtime successor.** Restore the frozen runtime
   (`FROZEN_SEED_REF=151c52c8 tool/restore_frozen_seeds`), apply §2(c) to `self/runtime.c` (the libc-snprintf
   delegation). OP-37b/OP-40 are already in tracked `self/codegen.hexa` — nothing to re-apply for those.
2. **Regenerate the seed.** `tool/regen_cc_manual` (HEXA_V2 = a fresh from-source hexat built from current
   `self/codegen.hexa`) → new `hexa_cc.c` carrying the OP-37b strtod parse + OP-40 hex-float serialize.
3. **Force-add a coherent anchor commit.** Stage a same-revision snapshot of ALL bootstrap seeds (the
   regenerated `hexa_cc.c` + the OP-44-patched `runtime.c` + the ~20 native fragments + `forge_tier_v1.c`)
   as a NEW graduation-style anchor commit (the seeds are gitignored in the live tree, so this is a
   deliberate force-add).
4. **Prove the self-host ladder on that anchor.** `tool/build_selfhost.sh` → the terminal byte-eq fixpoint
   **`cc-gen3.o == cc-gen4.o`** (THREE ~68-min native self-emits, ~3.5h) + `tool/selfhost_parity_gate.sh`
   PASS + `ENCODE-MISS = 0` + determinism gates GREEN. (Local de-risk already done: OP-37b/OP-40 proved
   gen-N == gen-N+1 BYTE-IDENTICAL per-module; OP-39b proved the full-regen fixpoint byte-identical.)
5. **Re-pin `FROZEN_SEED_REF`** in `tool/restore_frozen_seeds` (+ the ~6 other scripts that hardcode
   `151c52c8`, §1) to the new anchor SHA.
6. **Re-bake float-printing goldens repo-wide (OP-44 blast radius).** Making `%g/%e/%f` correctly-rounded
   shifts the EXACT decimal text of ~91% of float-printing goldens (toward correctness). Stage this golden
   re-bake **as its own PR / commit** — it is a wide, mechanical diff and must not be slipped silently into
   the anchor bump. (The OP-39 const-fold golden does NOT move — OP-40 hex-floats it.)

---

## 4. Post-promote cleanup (flip the gate advisory → enforcing)

Once the seed carries the fixes, the OP-39 const-fold gate auto-goes-GREEN against CI's `./hexa`
(proven locally by OP-39b: the regen emits the fixed literals and `tool/op39_constfold_gate.sh` passes 13/13
against it). Then:

- **Drop the 3 `continue-on-error: true` lines** in `.github/workflows/nobaseline-gate.yml`
  (`:129` darwin-arm64 · `:193` linux-x86_64 · `:256` linux-arm64) to make the const-fold gate **enforcing**
  on all 3 release platforms. (Per OP-39b, this is correctly coupled to a *successful* promote — flipping
  before the seed carries the fix red-gates main.)

---

## 5. Verification checklist (each fix's oracle/gate goes green post-promote)

| Fix    | Oracle / gate                                                    | Pre-promote (frozen seed) | Post-promote (re-pinned) |
|--------|------------------------------------------------------------------|---------------------------|--------------------------|
| OP-37b | const-fold operand parse byte-exact (in OP-39 gate)              | ≤3 ULP (lossy `%g`)       | byte-exact operands      |
| OP-40  | `tool/op39_constfold_gate.sh` 13 IEEE-754 goldens (3 platforms)  | DRIFT (advisory FAIL)     | PASS 13/13, **enforcing**|
| OP-44  | `%.17g` round-trip 0/N + `%.17e` 0-ULP-vs-libc on the 5521-sweep | 62.6% fail / ≤5 ULP       | 0/0 (libc-delegated)     |
| OP-39b | `nobaseline-gate.yml` const-fold step GREEN, `continue-on-error` dropped | advisory (red if enforced)| GREEN + enforcing |

**Done = ** all four rows show the post-promote column AND `cc-gen3.o == cc-gen4.o` on the new anchor.

---

## 6. Scope boundary (honest)

- This is a **build-host self-host-anchor refresh**, not a $0 local 0-pod task: its risk surface is the entire
  bootstrap and its validation is the ~3.5h `build_selfhost.sh` ladder. A bad seed promote breaks bootstrap on
  every platform — the single highest-blast-radius operation in the repo.
- The three source fixes are PROVEN correct + fixpoint-stable locally ($0); this doc does NOT re-derive them.
  It is the runbook that converts "three correct-but-unobserved source fixes" into "one landed promote bundle".
- Until this lands: const-fold determinism is already safe in source (OP-40 hex-float); the CI gate stays
  advisory (OP-39b); display floats keep the ≤5-ULP hand-rolled formatter (OP-44 — measured, bounded, not a
  silent unknown). No correctness regression is shipped by deferring.
