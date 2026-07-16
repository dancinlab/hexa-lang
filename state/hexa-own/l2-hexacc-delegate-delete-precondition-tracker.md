# L2 — `hexa_cc.c` C-transpile-delegate DELETE-precondition tracker

**axis-① (DONE-criterion ①):** `hexa build`/`run` lowers *every* program through the native
source→own-IR→native path, so the per-program **C-transpile delegate** (`self/native/hexa_cc.c`
+ its `hexat` transpile + `clang` link) is never invoked and can be deleted.

**Status (round-2, 2026-07-16):** **NOT deletable — blocked on 3 preconditions.** round-1 #4971
(SYSLEAF) is orthogonal (axis-②). The delegate is the *safety net under every native leg*, and
the native legs that would replace it are either opt-in (own-link) or fall back to it on any
miss. This doc is the census + falsifier gate; **no code changes, byte-neutral by construction**
(pure `state/hexa-own/` doc — no `.hexa`/`.c`/`.s`/codegen touched → default build byte-identical).

---

## 0. (a) bootstrap-SEED vs (b) per-program DELEGATE — the split L2 acts on

The two consumers of `hexa_cc.c`/`hexat` are **different axes**. L2/axis-① deletes only **(b)**.

| | (a) bootstrap-SEED | (b) per-program C-transpile DELEGATE ← **L2 target** |
|---|---|---|
| purpose | cold-start: compile gen-0 transpiler from a checkout with no prior binary | lower one user `.hexa` → `.c` → binary when native legs miss |
| call sites | `cmd_cc` `self/main.hexa:1775` (clang `hexa_cc.c`→`build/hexat` `:1831`/`:1836`), `cmd_regen_cc` `:2259`, `resolve_or_bootstrap_hexat` `:2676` | `cmd_build` fallthrough `:3772`–`:4005`, `cmd_run_user_direct` clang fallback `:4871`/`:4896`, `cmd_run` inner-build `:5077` |
| deletable by L2? | **NO** — chicken-egg floor (`project_hexa_none_hexa_cc_bootstrap_floor`; Thompson/DDC). Its escape = precondition ② below, tracked separately. | **YES, once ①②③ met** — it is a *fallback*, not a floor. |

`resolve_or_bootstrap_hexat()` is (a): a native-served build/run never reaches it — the axis-①
rider hoists it to its sole use just above the delegate body (`cmd_build:3768`–`:3772`), so a
leg-B build forks **zero** hexat. Deleting (b) means proving that hoisted call is **never reached**.

---

## 1. Delegate call-site census — each site → the gate ladder that must ALL miss to fire it

### `cmd_build(src,out,c_only,target,shared)` — `self/main.hexa:3094`
Delegate body: `resolve_or_bootstrap_hexat()` `:3772` → `hexat` transpile `[1/2]` `:3819` →
`clang` link `compile` `:4005` (native host) / `zig cc` cross `:4028`.
**Reached only when every native leg above misses:**

| # | native leg (gate) | line | polarity | miss ⇒ next |
|---|---|---|---|---|
| 1 | `HEXA_BACKEND=native` codegen | returns `:3611` | opt-in | leg not selected |
| 2 | own-link `HEXA_OWNLINK_DEFAULT=1` | `:3644` | **opt-in (retracted default — precond ①)** | tier-B ld |
| 3 | leg-B `HEXA_BUILD_NATIVE!=0` aprime `--emit=obj`+`ld` | `:3679` | **default-ON, opt-out `=0`** | C fallback `:3740` |
| 4 | cross `HEXA_BUILD_NATIVE_CROSS=1` | `:3752` | opt-in | zig-cc fallback `:3763` |
| 5 | **C-transpile DELEGATE** | `:3772`+ | — | — |

### `cmd_run_user_direct(file,extra_args)` — `self/main.hexa:4653`
| # | leg (gate) | line | polarity | miss ⇒ next |
|---|---|---|---|---|
| 1 | precompile / daemon-autospawn | `:4687` / `:4697` | shipped / opt-in | fork |
| 2 | leg-B run-native, own-link `:4805` | `:4740` | **default-ON, opt-out `HEXA_RUN_CTRANSPILE=1`** | clang fallback |
| 3 | inner `hexa build` **→ re-enters `cmd_build` delegate** | `:4900`+ | — | — |

### `cmd_run(file,extra_args)` — `self/main.hexa:5031`
Subprocess `hexa build … 2>&1` `:5077` → **re-enters `cmd_build` ladder above** (single choke point).

**Choke point:** all three verbs funnel to the `cmd_build` `:3772` delegate. Delete-gate =
"`cmd_build:3772` unreachable on the full shipping corpus, all 3 targets."

---

## 2. Three DELETE-preconditions — as measurable falsifiers

### ① own-link default soak — `HEXA_OWNLINK_DEFAULT` default-ON survives byteeq + shipping smoke
- **Now:** default-flip **RETRACTED** to opt-in — own-link binary SIGSEGVs at STARTUP on
  linux-x86_64 (`cmd_build:3626`–`:3643`; root cause = precond ③). byteeq read GREEN because it
  compares *linker bytes*, not runtime behaviour.
- **Falsifier (MET when FALSE):** with `HEXA_OWNLINK_DEFAULT=1`, run the shipping-smoke corpus on
  all 3 targets; **FAIL if any binary rc ≠ its `HEXA_OWNLINK_DEFAULT=0` rc, OR stdout differs.**
- **Behavioural probe (same tree/commit/binary, only env differs):**
  `own-link default → rc=139 SIGSEGV 0 lines` vs `=0 → rc=1 aggregate RUNS found=94 pass=86`.
- SSOT: `state/hexa-own/axis3-ownlink-default-startup-sigsegv.md`; `project_hexa_axis3_ownlink_default_startup_sigsegv`.

### ② F2 native-object seed default-flip — (a) no longer clang-compiles `hexa_cc.c`
- **Now:** `HEXA_BOOTSTRAP_NATIVE_SEED` opt-in (PR #3865 @`fec55d4e1`, byte-identical to clang-seed
  `./hexa` demonstrated); DEFAULT `tool/stage_build_hexa:48` still `clang hexa_cc.c`.
- **Falsifier (MET when FALSE):** a DEFAULT release/driver build's execve trace **has 0** hits of
  `clang … hexa_cc.c` **AND** `grep -rn 'self/native/hexa_cc.c' tool/ self/` returns only the
  legacy `resolve_hxroot` marker fallback (`main.hexa:1639`), never a compile invocation; byteeq
  3-target GREEN. (Precondition for physically `rm`-ing the file — nothing may compile it.)
- SSOT: `project_hexa_none_hexa_cc_bootstrap_floor` (r4/r5 TERMINAL).

### ③ x86_64 pair-carry miscompile soak — native-emit ABI skew = 0 silent-corruption
- **Now:** own-link/native-emit path has a **pair-ABI/C-ABI register skew** — args from #2 on shift
  one register late (`mmap(NULL,0,0x400000,…)=-1 EBADF`, used unchecked → NULL-store SIGSEGV;
  `cmd_build:3630`–`:3637`). Also `enum_ctor` pair-carry (`project_hexa_x86_paircarry_rootcause_enumctor`).
- **Falsifier (MET when FALSE):** (a) the mmap-arg-shift + `enum_ctor` repro fixtures compile+run
  rc-correct under native-emit; (b) a soak of the full corpus under native-emit shows
  **0 rows where (rc, stdout) ≠ the delegate-off oracle** — i.e. **0 SILENT corruption** (this is
  the class byteeq cannot see; ① fails today *because* ③ is open).

**Ordering:** ③ gates ① (③ is ①'s root cause); ② is independent (the seed axis). Delete (b) needs
**① ∧ ③**; physically `rm hexa_cc.c` additionally needs **②**.

---

## 3. `delegate-fired == 0` CI assertion design

**Load-bearing anchors** (the delegate *always* prints these — grep them, don't infer):
- `cmd_build:3819` `println("  [1/2] " + trans)` — the hexat transpile step (fires iff delegate used).
- clang link `:4005` / zig `:4028` — the `.c`→binary compile.
- trace lines (`HEXA_RUN_NATIVE_TRACE=1`): `→ C fallback` (`:3716`/`:3737`/`:3740`),
  `→ clang fallback` (`:4871`/`:4896`/`:4899`).

**Assertion (per target, over the shipping-smoke + stdlib-selftest corpus):**
```
export HEXA_RUN_NATIVE_TRACE=1
<build+run every corpus program, capture merged stdout+stderr → cap.log>
assert  grep -cE '^  \[1/2\] ' cap.log            == 0     # no hexat transpile
assert  grep -cE '→ C fallback|→ clang fallback'   cap.log  == 0     # no native→C drop
assert  strace -f -e execve … | grep -cE 'clang|cc .*\.c'  == 0     # no clang execve of a .c
assert  <trace> shows 0 `hexat` child fork
```
`delegate-fired = ([1/2] count) + (fallback-trace count)`; **gate = 0 on all 3 targets + install.sh
consumer smoke.**

**Strict-mode lever (already present, reuse — no new code):** `HEXA_OWNLINK_STRICT=1`
(`cmd_build:3665`, `cmd_run_user_direct:4805`) turns the own-link→fallback drop into a hard
`FATAL … return` instead of a silent slide to clang — a corpus run under STRICT yields the *real*
fallback rate as errors instead of a silent zero. **Gap to close before relying on it:** STRICT
covers only the **own-link tier (#2)**, NOT leg-B `HEXA_BUILD_NATIVE` (#3) — the default-ON tier a
program actually rides — so a `HEXA_BUILD_NATIVE`-tier fallback is still silent. Either extend
STRICT to the leg-B tier, or gate purely on the `[1/2]`/trace grep above (which is tier-agnostic).

**⚠ silent-until-CI trap:** the delegate is a *silent* net — own-link `rc=0` yet SIGSEGVs at
runtime, and byteeq compares linker bytes + exit codes of the LINKER, not runtime behaviour. So the
grep assertion (`delegate-fired==0`) can pass while native-emit **silently miscompiles**. It MUST
be paired with the ① / ③ **behavioural (rc+stdout) soak** — grep-green alone is false comfort.

**Today's expected result:** this assertion **FAILS** (delegate fires on any native-emit/own-link
miss). It is the tracker gate that turns GREEN only after ① ∧ ③; ② additionally gates the `rm`.

---

## Refs
- `self/main.hexa` (origin/main @`267fe2633`): `:1775`,`:1831`,`:2676`,`:3094`,`:3611`,`:3644`,`:3665`,`:3679`,`:3752`,`:3772`,`:3819`,`:4005`,`:4653`,`:4740`,`:4805`,`:5031`,`:5077`.
- `tool/stage_build_hexa:48` (a-seed clang). `project_hexa_none_hexa_cc_bootstrap_floor`, `project_hexa_axis3_ownlink_default_startup_sigsegv`, `project_hexa_x86_paircarry_rootcause_enumctor`.
