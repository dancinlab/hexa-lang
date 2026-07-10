# axis-② R1c — spec: default-flip HEXA_RT_NATIVE_SIGNAL + HEXA_RT_NATIVE_STRTOLL (RFC061 §M8, do NOT flip yet)

Base: origin/main (cited 25057d1b5; working tree HEAD 4efa2f89b — anchor by string, verify line numbers on checkout). Repo: hexa-lang. **Spec only — no edit, no commit, no build.**

## What flips (zero new code — wiring already complete)
Both flips are a single-char default change on one line of `tool/stage_resolve_runtime_a`. The ON block, the native body, and the shim `#ifndef` guard already exist and are OFF-neutral today.

| Flip | env | edit site | body | shim guard (emitter) | verify |
|---|---|---|---|---|---|
| PR-A SIGNAL (UND −1) | `HEXA_RT_NATIVE_SIGNAL` | `tool/stage_resolve_runtime_a:2470` `:-0`→`:-1` | `stdlib/runtime/hxlcl_core.hexa:4527-4589` (rt_sigaction + `__hx_fn_addr` sa_restorer @naked trampoline) | `self/runtime_core_hxlcl_shim_emit.hexa:934` `#ifndef HEXA_RT_NATIVE_SIGNAL` (delegate body L935) | `tool/routec_signal_native_verify.sh` (199L) |
| PR-B STRTOLL (UND −2) | `HEXA_RT_NATIVE_STRTOLL` | `tool/stage_resolve_runtime_a:1854` `:-0`→`:-1` | `stdlib/runtime/hxlcl_core.hexa:725+` (pure byte-walk parse leaf, only write `*endptr`) | `self/runtime_core_hxlcl_shim_emit.hexa:549` `#ifndef HEXA_RT_NATIVE_STRTOLL` (closed L584) | `tool/routec_strtoll_native_verify.sh` (148L) |

Note: `self/runtime_core_hxlcl_shim.c` is a **generated** artifact; the guards live in the `_emit.hexa` SSOT. "UND −1/−2" = nm-UND libc-floor drop count, not a literal env value.

## Exact edits (one line each)
```
# PR-A  tool/stage_resolve_runtime_a:2470
-        if [ "${HEXA_RT_NATIVE_SIGNAL:-0}" = "1" ]; then
+        if [ "${HEXA_RT_NATIVE_SIGNAL:-1}" = "1" ]; then
# PR-B  tool/stage_resolve_runtime_a:1854
-        if [ "${HEXA_RT_NATIVE_STRTOLL:-0}" = "1" ]; then
+        if [ "${HEXA_RT_NATIVE_STRTOLL:-1}" = "1" ]; then
```
Each PR also adds a `CHANGELOG.jsonl` entry (flip = behavior event; precedent `19533a46c` #4489 `hxlcl_free` default-ON). Nothing else changes. **Two SEPARATE PRs**, each held until its CI is GREEN.

## Bit-changing → NOT auto-mergeable
- Wiring landed OFF-neutral (guard unset ⇒ `#ifndef` keeps libc body ⇒ shim.o .text byte-identical to origin/main — verify [A]). That is why it was safe to land.
- **This** change moves DEFAULT OFF→ON ⇒ x86_64-linux runtime.a/shim.o change (adds native seed member, drops libc member). Bit-CHANGING by construction ⇒ needs byteeq 3-target GREEN + install smoke + ship-witness before merge.
- **OFF today is the shipping state** ⇒ opening the flip branch is safe ONLY because it is not self-merged pre-byteeq; main default (OFF) keeps shipping until CI green.
- **Target asymmetry**: native seed is x86_64-linux-ONLY (host gate `:2471`/`:1855`). arm64-linux + darwin-arm64 print "…IGNORED…", keep the libc shim member ⇒ their default builds are UNAFFECTED. "3-target GREEN" = {x86_64 gen3≡gen4 holds WITH member} ∧ {arm64+darwin byte-identical to pre-flip}.

## Verify gate (x86_64-linux pool host; mini = git/gh only)
1. `bash tool/routec_signal_native_verify.sh` → DEFAULT_SHIM_TEXT_BYTE_IDENTICAL=YES · SHIM_SIGNAL_MEMBER_DROPPED=YES · WALL_FALSIFY=YES · acc RC=0 (not 139) · BEHAVIORAL_TEST=PASS · OLD_HANDLER_RETURN_CORRECT=YES. (B/C need `build/aprime_cc` or `HEXA_SELFEMIT_BIN`, else SKIP.)
2. `bash tool/routec_strtoll_native_verify.sh` → DEFAULT_SHIM_TEXT_BYTE_IDENTICAL=YES · SHIM_STRTOLL_MEMBER_DROPPED=YES · NATIVE_STRTOLL_SELF_CONTAINED=YES · VALUE_EXACT=YES · acc RC=0.
3. Ship-witness (NOT bare stage — #4759 warm trap): on a BARE pod `TARGET=linux-x86_64 CC=clang LIBS="-lm -ldl" bash tool/release_build` ⇒ working ./hexa with NO "RT-NATIVE-… FATAL: no hexa/hexat binary" abort ⇒ smoke `./hexa --version` + build/run hello + install.sh consumer smoke.
4. byteeq 3-target `selfhost_gates_summary.sh` per target ⇒ required `selfhost-gates-summary` GREEN on all 3.
Merge each PR only after 1∧2(∨equivalent)∧3∧4; then sync pool hosts; `finalize` on 3/3.

## Kill criterion
- Verify RED = **bug to fix, keep PR open**: SIGNAL acc RC=139 (sa_restorer trampoline regression, re-opens 01f13609b wall) / OLD_HANDLER wrong / SIG_ERR; STRTOLL VALUE_EXACT=NO (value or endptr / errno-family mismatch) / not-self-contained; DEFAULT_SHIM byte-diff = broken guard edit.
- **Wrong-vehicle signal**: `release_build` on a bare pod FATALs at step-1 ("no hexa/hexat binary") because stage_resolve_runtime_a (runtime.a, step 1) runs BEFORE stage_prebuild_hexat (hexat, step 2) — default-ON demands a seed compiler the cold pipeline can't yet guarantee. Fixable via ordering / a documented `HEXA_SELFEMIT_BIN` contract, but it falsifies "zero-risk one-line flip." A genuine x86_64 byteeq non-fixpoint (seed codegen non-determinism) routes to a codegen fix, not abandonment.