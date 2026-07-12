# axis-① cfallback-zero census — staged-artifact fidelity (RED finding + fix)

SSOT for why PR #4885's first census went RED and how it was re-wired. Honest reversal of a
premature DONE claim; the census did its job.

## The RED (real finding, not a flake)
`tool/cfallback_zero_census` v1 built a corpus with the DEFAULT `hexa build` and asserted the
own-link marker. CI (aiden, linux-x86_64): **5/5 corpus programs fell through to the C-transpile
delegate** — `clang -O2 ... build/artifacts/<p>.bin.c build/runtime.a -o ...`. So `hexa build`
did NOT take own-link; it reached the clang delegate.

## Root cause (confirmed)
`self/main.hexa` `hexa build` has two native legs before the C-transpile fall-through:
- own-link default leg `:3587` (#4882 flip) — aprime_cc native-emit + `hexa_ld`, clang-0 + ld-0.
- tier-B native leg `:3612` — aprime `--emit=obj` + system ld (clang-free, NOT ld-free).

Both call `resolve_native_cc()` (`:2680`), which returns the path to a prebuilt **`build/aprime_cc`**
(the native compiler). Probes: `$HEXA_APRIME_CC` → `<install>/build/aprime_cc` → `./build/aprime_cc`
→ `$HEXA_LANG/build/aprime_cc`. If all miss → `""` → **both native legs skip → C-transpile delegate**.

The census job built `./hexa` via `bash tool/release_build` ONLY. `release_build` does NOT build
`aprime_cc`. So `resolve_native_cc()=""` → delegate. That is the entire RED.

## Why the sibling gates were (falsely) green
byteeq / ownlink-corpus-parity (#4881) / ownlink-determinism all have an explicit
`- name: (2) Build aprime_cc` step (`bash tool/build_aprime.sh -o build/aprime_cc`) before they run.
They proved own-link≡ld works *with aprime_cc present*, but NONE exercised the real `hexa build`
CLI ladder as a consumer gets it. The census is the only end-to-end CLI-ladder gate — and it caught
that the #4882 "default-flip DONE" was validated only on hand-privileged envs.

## Consumer reality
The shipped consumer toolchain DOES carry aprime_cc: `tool/stage_precompile_package` r27 (ING #79)
builds `build/aprime_cc` if absent and copies it into `dist/hexa-${TARGET}/build/aprime_cc`. So a
consumer install (via the staged tarball) takes own-link. The census tested a LESS-complete env
(bare `release_build`, no aprime_cc) than any consumer — that was the census's own fidelity defect.

## Deeper layer (MEASURED, aiden) — the staged tarball ALSO false-reds; it must be the INSTALL layout
Testing the raw `dist/hexa-linux-x86_64/` staging tarball still went RED (5/5 clang delegate),
EVEN with aprime_cc present. Ground-truth trace (`HEXA_RUN_NATIVE_TRACE=1`) showed the own-link
leg was NEVER entered (no own-link trace at all) → the leg's inner `if len(_olcc)>0 && len(_olrt)>0`
(:3590) was false. Pinned by explicit-env test: setting `HEXA_APRIME_CC` + `HEXA_PREBUILT_RUNTIME`
→ own-link FIRES (`OK: built ... native own-link`, program prints `43-1`, exit 2 = the pre-existing
void-main code). So the resolvers, not the leg, were the blocker.

Root cause of the resolver miss: `resolve_prebuilt_runtime()` (:1673) falls back to
`resolve_hxroot()/build/runtime.a`, and `resolve_hxroot()` (:1630) keys on the marker
**`self/native/hexa_cc.c`**. The raw tarball has `build/` but NO `self/` → resolve_hxroot returns
"." → `./build/runtime.a` absent → "" → leg skips → clang delegate.

install.sh does NOT ship the raw tarball as-is: it (a) extracts the tarball to `$HX_BIN`, and
(b) symlinks `$HX_BIN/self -> <cloned source>/self` (install.sh:494) so `self/native/hexa_cc.c`
EXISTS → resolve_hxroot returns `$HX_BIN` → runtime.a + aprime_cc both resolve. Replicating that
layout on aiden (copy build/ + symlink self/, ALL env unset incl HEXA_PREBUILT_RUNTIME) → own-link
FIRES clang-0 + ld-0 (`43-1`). **So the real ~/.hx consumer install DOES take own-link** — the RED
was purely the census testing the wrong (raw-tarball) layout.

## Fix — replicate the install.sh layout, census THAT (Fable Option B, made faithful)
Option A ("just add a build_aprime step to the census job") = tune-to-green: it fabricates the same
privileged env the sibling gates use, which is exactly the "hand-build/workaround = packaging defect"
anti-pattern. The census's unique job is proving the SHIPPED path guarantees aprime_cc presence.
Only testing the staged artifact does that.

CI job (`nobaseline-gate.yml` `cfallback-zero-census-x86_64`) is now 4 steps:
1. `release_build` (TARGET=linux-x86_64) → `stage_precompile_package` (ships aprime_cc per r27).
2. **HARD packaging gate**: `test -x dist/hexa-linux-x86_64/build/aprime_cc` — separate step so a RED
   here pinpoints PACKAGING (r27 aprime build flaked) vs the CLI ladder.
3. **Reconstruct the install.sh layout**: copy staged `build/` into `$HX_BIN` + `ln -s <repo>/self
   $HX_BIN/self` (the resolve_hxroot marker `self/native/hexa_cc.c`) — mirrors install.sh:494. Assert
   the marker exists.
4. census against `$HX_BIN/hexa` from a **neutral cwd** with `HEXA_APRIME_CC/HEXA_LANG/
   HEXA_PREBUILT_RUNTIME` ALL unset → own-link must resolve purely from the layout (argv0 + self/
   marker), exactly as a consumer whose shell carries none of these.

Two fidelity traps handled in `tool/cfallback_zero_census`:
- **Probe leakage** — `resolve_native_cc()` probes `./build/aprime_cc` (cwd) and `$HEXA_LANG`; a
  repo-root cwd could resolve the *repo's* aprime_cc, not the install one. The script absolutizes
  `--hexa` and `cd`s to a neutral scratch dir; the CI also unsets the env vars.
- **Positive assertion, not just clang-0** — tier-B is clang-free but uses system ld. PASS requires
  the own-link marker AND no clang/cc child (belt-and-suspenders); delegate (clang-on-.c) and tier-B
  (`(native backend)`) are each distinctly flagged FAIL.

## Honest status (post-finding, corrected by the P1 measurement)
- **axis-③ (own-emit clang-0, #4882 flip):** the own-link default leg is merged and MEASURED
  clang-0 + ld-0 on the real install layout (`43-1`, ALL env unset). NOT the broken/"conditional"
  state my first RED implied — that RED was a census-fidelity defect (raw tarball lacks the self/
  resolve_hxroot marker). Remaining to call it consumer-DONE: the install-layout census GREEN in CI +
  a soak. The runtime.a/aprime_cc auto-resolution depends on the install carrying the self/ marker
  (install.sh:494) — solid today, but see the marker-irony risk below.
- **axis-① (no hexa_cc.c / cfallback-zero on the consumer USE path):** OPEN, closer than thought.
  own-link is the real default on a proper install; DONE when the install-layout census is a required
  gate AND aprime_cc is a hard packaging requirement (below). The delegate may then stay in-tree as
  dead-on-default code.
- **⚠️ marker irony (axis-① prerequisite):** `resolve_hxroot()` keys on `self/native/hexa_cc.c` — the
  exact C-transpile file axis-① aims to DELETE. Removing hexa_cc.c would break the hxroot marker →
  own-link runtime.a resolution → clang-fallback. Decoupling resolve_hxroot from that marker (use a
  neutral root sentinel) is a prerequisite for the axis-① delegate deletion. Tracked as follow-on.

## Follow-on ✅ LANDED (r28)
`stage_precompile_package` shipped aprime_cc BEST-EFFORT (`|| echo "... clang-fallback (no
regression)"`) — under axis-① that fallback IS a regression. HARDENED (r28): on
**TARGET=linux-x86_64** (the own-link-default target) a missing `build/aprime_cc` now HARD-FAILS
the stage (`exit 1`) rather than shipping a silent clang-fallback install; darwin/arm64 stay
best-effort (own-link not their default). The guarantee now holds at release time (release.yml runs
stage_precompile_package), not just gate time. Building aprime_cc itself via clang stays sanctioned —
that's the BUILD-time axis-③ endgame, out of scope for the USE-time claim.

Second follow-on (axis-① delegate-deletion prerequisite): decouple `resolve_hxroot()` (:1630) from
the `self/native/hexa_cc.c` marker — pick a neutral root sentinel (e.g. `build/runtime.a` presence,
or a `.hxroot` stamp) so deleting the C-transpile delegate does not break own-link's runtime.a
resolution. Without this, `hexa build`/`run` would clang-fallback the moment hexa_cc.c is removed.
