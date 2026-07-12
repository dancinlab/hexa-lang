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

## Fix — Fable Option B (test the staged consumer artifact, not a bare release_build tree)
Option A ("just add a build_aprime step to the census job") = tune-to-green: it fabricates the same
privileged env the sibling gates use, which is exactly the "hand-build/workaround = packaging defect"
anti-pattern. The census's unique job is proving the SHIPPED path guarantees aprime_cc presence.
Only testing the staged artifact does that.

CI job (`nobaseline-gate.yml` `cfallback-zero-census-x86_64`) is now 3 steps:
1. `release_build` (TARGET=linux-x86_64) → `stage_precompile_package` (ships aprime_cc per r27).
2. **HARD packaging gate**: `test -x dist/hexa-linux-x86_64/build/aprime_cc` — separate step so a RED
   here pinpoints PACKAGING (r27 aprime build flaked) vs the CLI ladder.
3. census against the staged `hexa` from a **neutral cwd** with `env -u HEXA_APRIME_CC -u HEXA_LANG`
   → the only surviving native-cc probe is `<install>/build/aprime_cc` = the consumer's real path.

Two fidelity traps handled in `tool/cfallback_zero_census`:
- **Probe leakage** — `resolve_native_cc()` probes `./build/aprime_cc` (cwd) and `$HEXA_LANG`; a
  repo-root cwd could resolve the *repo's* aprime_cc, not the staged one. The script absolutizes
  `--hexa` and `cd`s to a neutral scratch dir; the CI also unsets the two env vars.
- **Positive assertion, not just clang-0** — tier-B is clang-free but uses system ld. PASS requires
  the own-link marker AND no clang/cc child (belt-and-suspenders); delegate (clang-on-.c) and tier-B
  (`(native backend)`) are each distinctly flagged FAIL.

## Honest status (post-finding)
- **axis-③ (own-emit clang-0, #4882 flip):** MERGED-CONDITIONAL, NOT done. The own-link default leg
  is merged and ≡ld GREEN *when aprime_cc is co-located*; absent it, it silently degrades to the
  clang delegate. DONE gates on staged-artifact census GREEN + aprime_cc as a hard packaging
  requirement on linux-x86_64.
- **axis-① (no hexa_cc.c / cfallback-zero on the consumer USE path):** OPEN. Holds today only for
  installs where the best-effort r27 aprime build happened to succeed — an unguaranteed property the
  census correctly refused to certify. DONE when census-B is a required gate AND the packaging
  hard-fail is live. The delegate may then stay in-tree as dead-on-default code.

## Follow-on (separate PR, after census-B soaks green)
`stage_precompile_package:92` ships aprime_cc BEST-EFFORT (`|| echo "... clang-fallback (no
regression)"`). Under axis-① that fallback IS a regression. Harden: **hard-fail when
TARGET=linux-x86_64** (the own-link-default target); keep best-effort on darwin/arm64 where own-link
isn't default. This makes the guarantee hold at release time (release.yml), not just gate time.
Building aprime_cc itself via clang stays sanctioned — that's the BUILD-time axis-③ endgame, out of
scope for the USE-time claim.
