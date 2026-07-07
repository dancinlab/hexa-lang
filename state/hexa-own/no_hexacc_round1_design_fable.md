All claims verified in-tree at e26552002. Everything needed for the round spec is now confirmed — here is the deliverable.

# Axis ① round-1 design (verified on e26552002)

## Confirmed dispatch map (line numbers re-checked, all still exact)

**`hexa build` (cmd_build):**
- `self/main.hexa:3135-3138` — `resolve_or_bootstrap_hexat()` runs **unconditionally, before the backend selector**. Verified: `v2` is next used only at `:3577` (the C-transpile exec), and the native arm returns at `:3533` — so under `HEXA_BACKEND=native` the hexat handle is **dead code, but the resolve/bootstrap still runs**. On a fresh clone that means `HEXA_BACKEND=native` still clang-compiles `hexa_cc.c` (`:2634-2636` → cmd_cc → `:1784/:1789`) for a binary it never invokes. This is a genuine, silent ① dependency on the "native" path.
- `:3264-3265` — the only fork: `HEXA_BACKEND=native`, fail-loud, no fallback. Refuses `--c-only` (`:3272-3276`) and `--target` (`:3277-3281`).
- Native arm stage-1 `:3336-3338` = `aprime_cc --emit=asm`; stage-2 `:3503-3506` = **clang** assembling the `.s` + compiling/linking `runtime.c` as a 2nd TU.
- Default (unset) path: hexat transpile at `:3577-3579` → clang at the Stage B block (`:3624`ff).

**`hexa run` (cmd_run_user_direct):**
- `:4495-4497` — leg-B native cold path **default-ON but host-gated `Linux x86_64` only**; recipe = flatten → `aprime_cc --emit=obj --target=x86_64-linux-gnu` (`:4525`) → binutils `ld` + runtime.a, own-start crt-drop default-ON (`:4551-4552`). Zero hexat, zero clang when it succeeds.
- Every failure and every other host → inner `hexa build` subprocess (`:4590-4596`) → back to hexat.
- Internal `cmd_run` (`:4693`, used by verify/test/atlas verbs) has no native route of its own — it funnels through `hexa build` too.

**Other ① callers:** `cmd_typecheck` (`:6889-6894`) and `cmd_parse` (`:6915-6921`) fork hexat directly; `cmd_cc` (`:2096/:2220`) is the bootstrap itself; the release pipeline pre-builds hexat (`tool/stage_prebuild_hexat`).

## ① vs ②③ disambiguation — don't conflate

- The native arm's clang stage-2 at `:3504` is **③ (clang as assembler/link driver) + ② (runtime.c as second TU)** — hexat is not involved. Killing it is ③-R3/①-R6 in the DAG, **not** this round. "Make HEXA_BACKEND=native cover more of hexa build" is therefore not an ① round.
- The ① residual in `hexa build` is exactly two things: the default C-transpile exec at `:3577` and the unconditional hexat resolve/bootstrap at `:3135`.
- The codegen-gap question is settled in-tree: try/catch, match (basic), multi-fn-alias, closures are **falsified-as-walls** (driven default-ON on leg-B; `state/hexa-own/no_runtime_c_no_cc_verdict.md` §"falsified" — "do not re-run the ladder"). The REAL remaining punts are **HX1102** residual match-pattern shapes (`compiler/lower/hir_to_mir.hexa:4426, 4629`), **HX1103** unknown-HExpr kinds (`:5159`, catalog `:2102-2109`), the **@lazy** niche (loud self-fail → fallback), plus the **13 native-crash-where-clang-works** census (correctness debt the fallback does *not* catch).

## Round-1: `hexa build` leg-B mirror — opt-in native cold path at the choke point

**Why this one.** `hexa build` is the choke point: direct builds, internal `cmd_run` (verify/test/atlas), and `hexa run`'s fallback all funnel through it, and today it forks hexat on 100% of default invocations on every host. `hexa run` already proved the exact recipe (r26 default-ON, 361-corpus, true-silent=0 modulo @lazy). One additive arm in cmd_build reuses that proven recipe, covers all three flows at once (subsumes DAG ①-R5), and — critically — creates the *fallback-rate measurement vehicle on build flows* that every later round (gap-drain ①-R1/R2, default-flip ①-R6) is gated on. The HX1102/HX1103 drain is deliberately NOT round-1: its scope is unbounded until this lever measures which gaps actually fire on real build corpora.

**Lever (env-gated, default-OFF, byte-neutral):** `HEXA_BUILD_NATIVE=1`. In cmd_build, insert a new arm after the `HEXA_BACKEND=native` block (i.e. just before `let stem = basename_stem(out)` at `:3535`), engaged only when: flag==1 ∧ host `uname -sm == "Linux x86_64"` ∧ `shared != "1"` ∧ `c_only != "1"` ∧ `len(target)==0` ∧ `!_same_tu` ∧ `resolve_native_cc()` + `resolve_prebuilt_runtime()` + `ld` all present. Body = the cmd_run recipe (`:4525-4563`) minus the flatten (cmd_build already produced `__actual_src` at `:3153-3200`): `aprime_cc --emit=obj --target=x86_64-linux-gnu` → `ld` + runtime.a with the same `HEXA_ZEROC_OWN_START` crt-drop default-ON logic (`:4551-4552`) → `test -x` → atomic rename to `out`, `return ""`. **Any** emit/link failure falls through to the C path untouched (delegate-fallback intact; trace under the existing `HEXA_RUN_NATIVE_TRACE=1`). Keep it additive — do not refactor cmd_run's inline block into a shared fn this round.

**Required rider (this is what makes the measurement true):** move the `resolve_or_bootstrap_hexat()` call from `:3135-3138` down to just before the C-transpile use at `:3535`. Verified safe: nothing between `:3139-3534` touches `v2`, and the flatten uses the compiled module_loader, not hexat. Without this hoist, a native-served build still resolves — and on a fresh clone **bootstrap-compiles** — hexat at `:3135`, so "zero hexat fork" would be unmeasurable. Side effect: it also fixes the pre-existing dead hexat bootstrap under `HEXA_BACKEND=native`. Default-path behavior is call-order-identical (only stdout line ordering of a bootstrap message vs the flatten lines can shift; artifacts unchanged).

**Measurement (captured, on aiden/summer):**
1. Corpus: the leg-B flatten-faithful corpus (or its smoke subset) + the self CLI tools, each built twice — default vs `HEXA_BUILD_NATIVE=1 HEXA_RUN_NATIVE_TRACE=1`.
2. Prove "used to fork hexat, now doesn't": `strace -f -e trace=execve` (or a PATH-shim counter) — **0 hexat + 0 clang execve** on every native-served build; default run shows the hexat fork as today.
3. Equivalence: run both binaries per corpus item — rc + stdout identical.
4. **The deliverable number: fallback rate + reason histogram** (HX1102 / HX1103 / @lazy / crash) on build flows — this is round-2's input.
5. `hexa verify` / `hexa test` under the flag (env inherits into the inner `hexa build`) as the internal-cmd_run coverage check.

**Gate:** flag-unset byteeq 3-target GREEN (regular PR CI — proves the arm + the hoist are byte-neutral) + shipping smoke + install.sh consumer smoke. No default flip this round.

**Next wall it exposes (named):** the measured fallback tail — expected HX1102 residual pattern shapes + HX1103 unknown-HExpr kinds + @lazy — and, before any default flip can be trusted, the **13-crash census** (native-crash-where-clang-works), because the delegate-fallback catches emit *failures* but not miscompiles. Host gate is the wall after that: darwin-arm64 (wire the CI-proven `hx-selfhost-cli` gen3+hexa_ld path into cmd_build, DAG ①-R4) and arm64-linux (de-hardcode triple/crt).

## Honest reachability of ①

**Steady-state ∅ is reachable — no measured codegen wall blocks it.** The old wall constructs (try/catch, match, multi-fn-alias, closures) are all falsified in-tree; what remains is a finite, named drain list (HX1102 shapes, HX1103 kinds, @lazy, 13-crash census) plus host-coverage engineering, none of it recorded as terminal. The x86_64 HexaVal value-model rearch is a ② wall (runtime port), not an ① blocker. The one permanent floor is **from-nothing bootstrap**: `hexa_cc.c` is definitionally the C detour for cold-starting without a prior `hexa` binary (`self/native/hexa_cc.c.hexanoport`). The honest DONE shape is the Go model — every release builds from the prior release's native binary, and hexa_cc.c is never compiled on any shipped path. If "① done" must include from-nothing-no-prior-binary, that is BOOTSTRAP-FLOOR and it is information-theoretic, not engineering.