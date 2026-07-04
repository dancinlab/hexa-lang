# own-lint shipping wiring census — HX3012 → `hexa build`/`run` (gen2) vehicle

2026-07-03 · read-only census @ main (9f1b7a70d, mini) · input: `state/hexa-own/l3_m0_measurement.md` (measured: default ship path emits `[warn] unknown attribute @own`, runs no own-lint; HX3012 lives only in the native frontend behind `HEXA_OWN_LINT=1`)

## TL;DR

- The gen2 ship path **has a check layer but it is opt-in and own-blind**: `self/type_checker.hexa` runs only under `HEXA_TYPECHECK` (set by the existing `hexa typecheck` verb); default `hexa build` runs **parse-time println warns only**, no check pass.
- **`@own` already survives into the gen2 AST** (`LetStmt.op` carries the attr name) — only the walker is missing. The `[warn] unknown attribute` is cosmetic (generic fall-through still records the attr).
- **Releases ship `build/aprime_cc` on all 3 targets**, and `hexa run`'s cold path on linux-x86_64 **already invokes aprime_cc by default** — but swallows its output, so its lints never surface.
- **Top vehicle = (b)**: an `HEXA_OWN_LINT=1`-triggered, advisory-only aprime_cc invocation inside `cmd_build` (~25 lines in `self/main.hexa`, plumbing already exists). Effort S, default output untouched, real lint (no dual implementation). (a) is the long-term convergence port (M), (c) default-flip is measured-infeasible today.

---

## (1) Shipping check path map — what does gen2 actually check?

### `hexa build` pipeline (`self/main.hexa`)

| stage | site | diagnostics produced |
|---|---|---|
| driver entry | `cmd_build` — `self/main.hexa:2961` | file-exists, Darwin refusal — driver errors only |
| flatten | module_loader dispatch `self/main.hexa:3099-3147` | ghost-import FATAL (rc=2) |
| backend select | `HEXA_BACKEND=native` branch `self/main.hexa:3169-3248` | (opt-in native codegen route) |
| **default C path: hexat transpile** | `self/main.hexa:3482` (`let trans = v2_env + v2 + " " + __actual_src + " " + c_file`) | **parse-time println warns only** + "Parse error" string sniffing (`:3486-3497`) |
| clang link | below `:3560` | clang errors |

**Where gen2 diagnostics come from.** hexat is an amalgam of exactly 4 modules + a generated C `main`: `self/main.hexa:2114` (`sections = ["lexer…","parser…","type_checker…","codegen…"]`), SSOT note at `:2161`. Diagnostic sources on the default path:

1. **Parser println warns** — `self/parser.hexa:943` (`[warn] unknown attribute @…`, gated by `_p_is_known_attr` at `:286-345`, which has **no `"own"` entry**) plus attr-conflict warns. These are the ONLY default-path "checks" beyond parse errors.
2. **`self/type_checker.hexa` (2291 lines)** — scope/arity/type-mismatch/immutable-let/match-exhaustiveness, `type_check_and_emit` at `:1877`. **Not run by default**: the emitted hexat `main()` (heredoc at `self/main.hexa:2153`) gates it on `getenv("HEXA_TYPECHECK") != NULL` (default-off because the corpus emits ~1322 warnings). No HX-numbered codes; emits `warn:`/`error:` lines to stderr, and hexat still proceeds to codegen.
3. **No bind/resolve/borrow/own pass exists in gen2 at all.**

Because env inherits through `exec`, `HEXA_TYPECHECK=1 hexa build …` DOES run the gen2 type_check today — but it knows nothing about `@own`.

### `hexa typecheck` verb — exists, routes to **gen2**, not aprime

- Dispatch: `self/main.hexa:7102-7111` → `cmd_typecheck` at `:6760`.
- Implementation `:6770-6783`: runs hexat with `HEXA_TYPECHECK=1` (`:6771`), discards the `.c`, prints the warn stream, **exits 0 on warnings**. Frontend = gen2 hexat. aprime is never consulted.

### `@own` on the gen2 path — the annotation is NOT lost

- Unknown-attr warn at `self/parser.hexa:943`, then the **generic fall-through appends the name to `p_pending_attrs`** (`self/parser.hexa:1329-1334`).
- `parse_let` consumes it into **`LetStmt.op`** (`self/parser.hexa:1739-1742`, comment "Consume pending @attrs into LetStmt.op").
- So a gen2 own-lint needs no parser surgery beyond a 1-line `_p_is_known_attr` entry to silence the warn; the AST already carries `op: "own"` (comma-joined if stacked).

### Dormant gen2 asset

`self/ownership.hexa` — a full use-after-move/borrow/drop analyzer ported from `src/ownership.rs` (owner-state machine, `OwnershipError` w/ line/col). **Not in the hexat 4-section amalgam, no importer on the build path** — dead code today, but a design reference for a port. (`self/env.hexa:119-134,503` ownership fields are retired-interp legacy.)

### Bonus finding — aprime_cc is already ON the ship path (but muted)

- Releases **ship `build/aprime_cc`** in every target asset: `.github/workflows/release.yml:19` ("native compiler — r26 default-ON `hexa run` cold path (ING #79)").
- `hexa run` cold path, linux-x86_64 only, **default-ON**: `self/main.hexa:4396-4426` runs `aprime_cc _drv.hexa --emit=obj --target=x86_64-linux-gnu …` on every cache-miss. Since env inherits, `HEXA_OWN_LINT=1` already activates the lint **inside** that child — but the merged output `_ne` is **swallowed unless `HEXA_CG_PROFILE=1`** (`self/main.hexa:4431`). Warm-cache runs skip compilation entirely. So today: lint runs, nobody sees it, one host class only.

---

## (2) Vehicle options

### (a) PORT the own-lint to gen2's check layer — effort **M** (~1-2 days incl. gates)

Attach points, all evidenced:

| piece | site | change |
|---|---|---|
| silence bogus warn / register attr | `self/parser.hexa:286` `_p_is_known_attr` | +1 line `if name == "own" { return true }` |
| annotation already delivered | `self/parser.hexa:1739` `LetStmt.op` | none |
| walker | `self/type_checker.hexa` (new pass, or new amalgam-included module) | ~200 lines: mirror native registry — `compiler/check/types.hexa:1230-1234` (5 parallel arrays), `_own_lint_register:1255`, `_own_lint_find:1246`; hook sites mirroring native's five `env("HEXA_OWN_LINT")` gates at `types.hexa:2111` (register on let), `:2304` (let-init from ident = move), `:2424` (assign rhs), `:2774` (call args), `:3907` (bare use) |
| entry gate | emitted hexat `main()` heredoc `self/main.hexa:2153` | +2 C lines: `if (getenv("HEXA_OWN_LINT")) { own_lint_and_emit(ast); }` — **separate** from `HEXA_TYPECHECK` so the 1322-warning flood is not co-triggered |
| regen | `regen_one_module(...type_checker.hexa...)` `self/main.hexa:2177` | automatic |

Pros: works on ALL hosts/verbs (`build`/`run`/`typecheck`), no aprime binary dependency, no double compile. Cons: **dual-frontend drift** (two implementations of one lint), gen2's map-AST has **no per-node line/col on LetStmt** (`self/parser.hexa:1741-1747` — no line field), so diags would be name-only or need token-line plumbing; hexat-dialect constraints; heaviest byteeq/faithful surface (hexat itself changes).

### (b) INVOKE the aprime typechecker as an opt-in advisory gate from `cmd_build` — effort **S** (hours) — ★ recommended

The driver **already knows how to find and call aprime_cc**:

- `resolve_native_cc()` — `self/main.hexa:2592-2612` (env > `<install>/build/aprime_cc` > `./build/aprime_cc` > `$HEXA_LANG/build/aprime_cc`); loud-fail helper `die_no_native_cc` `:2615-2626`.
- Proven invocation shape (incl. the `_drv.hexa` placeholder gotcha required by `compiler/main.hexa`'s `_normalize_argv`): `self/main.hexa:3241` — `'<ncc>' _drv.hexa --emit=asm … -o '<out>.s' '<src>'`; run-path variant with `--emit=obj` at `:4426`.
- Release asset ships the binary (release.yml:19) → works on consumer installs, not just dev checkouts.

New code: one ~25-line advisory block in `cmd_build`, inserted **after flatten** (so it sees `__actual_src`, i.e. `:3148`, before the `:3169` backend select — the lint then covers both C and native backends): if `env("HEXA_OWN_LINT") == "1"` → resolve aprime; if absent, print one advisory-unavailable line and continue; else run `aprime_cc _drv.hexa --emit=obj -o /tmp/<pid>.o '<__actual_src>' 2>&1`, print the output, **ignore rc**. `--emit=obj` matters: it takes the `empty_atlas_index()` branch (`compiler/main.hexa:651`), avoiding the measured ~1.85GB full-atlas RSS. `HEXA_OWN_LINT` inherits into the child, activating the real lint sites in `compiler/check/types.hexa`.

Why advisory is mandatory (measured): l3_m0 shows aprime rc=1 on shipping, gen2-valid files (`stdlib/alloc/collections.hexa`, `compiler/check/types_test.hexa`) — hard-gating the build on aprime rc would break valid builds. Cost: one extra full aprime compile, **flag-ON only**.

Cheap companions: (b-run) un-swallow `_ne` at `self/main.hexa:4431` when `HEXA_OWN_LINT=1` (1 line — makes the already-running run-path lint visible on linux-x86_64 cold); (b-typecheck) same advisory block appended to `cmd_typecheck:6760`.

### (c) Promote the aprime frontend to the default check pass (diagnostics only, emission stays gen2)

**Separability: YES, and cheap to expose.** `compiler/main.hexa` is a linear pipeline — lex `:628` → parse `:631` → atlas `:651` → resolve `:679` → bind `:684` → `type_check(module)` `:689` → unit_check `:694` → citations (strict-gated) `:711` → **`_render_all(diags)` `:722` and abort-before-codegen `:724-731`** — all check phases complete and render before `lower` at `:742`. A `--emit=check` that exits 0 after `:731` is a small additive flag (`--emit=` parsed permissively at `:440-442`); `--ignore-errors` (`:171`, `:486`) shows the error/codegen boundary is already a managed contract.

**Default-ON is infeasible NOW** — see §4. The `--emit=check` flag itself is a sensible S-effort enabler *for option (b)* (removes the wasted codegen), but the polarity flip is a separate measured campaign.

---

## (3) Top option (b): scope · byteeq risk · flag design · test plan

### Exact scope

- `self/main.hexa` only:
  1. `cmd_build` advisory block (~25 lines) at the flatten/backend seam (`:3148`).
  2. Optional +1 line at `:4431` (`hexa run` native-path output forward under the flag).
  3. Optional mirror in `cmd_typecheck` (`:6760`) so `HEXA_OWN_LINT=1 hexa typecheck f.hexa` also surfaces HX3012.
- No `compiler/*` change, no hexat amalgam change, no runtime/codegen change, no new runtime symbol (frozen-blob 151c52c8 concern: none).
- CHANGELOG.jsonl entry same change (`.hexa` changelog gate); if the flag is documented in help text, lockstep-update `hexa --help` in the same change (root CLAUDE.md rule).

### Byteeq / release risk

- `self/main.hexa` **is the shipping CLI compiler source** — every edit rides release-integrity gates. But: flag-OFF adds exactly one `env()` comparison and zero new subprocess/output → default build transcript and emitted artifacts byte-identical; byteeq 3-target compares emitted objects — untouched code path. Flag-ON output is stderr/stdout advisory text only; the produced binary is still built by the unchanged gen2+clang path (bit-identical flag-ON vs flag-OFF — worth asserting in the test plan).
- No self-host fixpoint semantic change (driver-level, not codegen); standard PR CI (Blacksmith 3-target byteeq + shipping smoke) suffices. Heavy verification on pool (aiden/summer), not mini.

### Flag design

- **Reuse `HEXA_OWN_LINT=1` as the single trigger** — it double-acts: (1) tells `cmd_build` to spawn the advisory aprime pass, (2) inherits into the child and activates the lint registry inside `compiler/check/types.hexa`. No new flag, no polarity change (native-canonical: the lint is our own frontend; opt-in is the pre-existing contract from L2).
- Advisory contract: **never changes rc, never blocks emission**, missing `aprime_cc` degrades to one loud warn line (do NOT call `die_no_native_cc` for a lint). Default (unset): byte-identical behavior.

### Test plan — end-to-end HX3012 on `hexa build`

Probe = the **measured HX3012-firing shape** — nb. in the types_test letter scheme this is **case (n)** (`compiler/check/types_test.hexa:1093-1113`, builder `:815`); "case (p)" in `next_rounds_plan.md:97` is the static-types r8 HX3003 slot — the task's "case-(p)" label appears to be a slip, flagged here honestly. Probe file:

```
fn main() { @own let x = 5
  let a = x
  let b = x
  print(b) }
```

On aiden/summer (branch-built `hexa`):

1. **Positive**: `HEXA_OWN_LINT=1 hexa build /tmp/own_probe.hexa -o /tmp/own_probe` → transcript contains exactly 1 `HX3012` ("use of moved value 'x'", the `let b = x` site), rc=0, binary runs and prints the same output as flag-OFF.
2. **Flag-OFF control**: `hexa build …` → 0 HX3012; produced binary byte-identical to pre-change `hexa`'s output (and to the flag-ON binary).
3. **Negative control**: same probe without `@own`, flag ON → 0 HX3012.
4. **Degrade**: rename `build/aprime_cc` away → flag-ON build prints one advisory-unavailable line, still rc=0.
5. **Divergence control** (the measured rc=1 file): `HEXA_OWN_LINT=1 hexa build stdlib/alloc/collections.hexa -o /tmp/c` → build still succeeds; aprime's own errors appear as advisory text only.
6. **Run-path symmetry** (if `:4431` companion lands): cold-cache `HEXA_OWN_LINT=1 hexa run /tmp/own_probe.hexa` on linux-x86_64 → HX3012 visible; warm-cache → documented no-lint (cache hit = no compile).
7. Gates: PR CI byteeq 3-target GREEN + shipping smoke + CHANGELOG.jsonl entry; no promotion on partial-target green.

---

## (4) Honest infeasibility / caveats

- **Wiring ≠ coverage.** l3_m0 measured `@own` corpus adoption = 0; after (b) lands, a user must both annotate and set the flag. This vehicle makes the flag honest ("works on `hexa build`"), it does not make the lint observed.
- **(c) default flip is blocked by captured numbers**: aprime rc=1 on gen2-valid shipping files (2/10 in the l3_m0 sample) → default-ON would spam or break valid builds; full-atlas load ~1.85GB RSS (`compiler/main.hexa:647`) unless check-mode reuses the obj empty-atlas branch; plus per-build compile-time cost. Prerequisite campaign: two-frontend parse-parity census → corpus-clean rc → then a default-diagnostics RFC. NOT NOW.
- **(a)'s hidden costs**: gen2 `LetStmt` carries no line/col (`self/parser.hexa:1741-1747`) → ported HX3012 would have weak spans without token-line plumbing; permanent dual-implementation drift against `compiler/check/types.hexa`; and it edits the hexat amalgam = the highest-blast-radius shipping surface. Reasonable only as the eventual convergence step, not the first wire.
- **`hexa run` warm cache** never re-lints under any vehicle that hooks compilation — an always-on lint story eventually needs a cache-key or check-verb answer; out of scope here.
- **(b) cost asymmetry**: flag-ON doubles compile work (aprime runs its full pipeline; no `--emit=check` yet). Acceptable for an opt-in advisory; `--emit=check` in `compiler/main.hexa` (exit-0 after `:731`) is the natural r2 to cut the waste.
- Sandbox note: this census ran on mini (read-only, git/gh/read per pool discipline); all corpus/lint numbers cited are from `l3_m0_measurement.md` (aiden), not re-measured here.
