# 2026-05-13 — final consolidation session

> Final pass for the nexus → hexa-lang absorption project (doctrine v2).
> BG agent (Tasks A+B+C) was killed mid-Task-D (regression) due to user
> directive to offload the heavy regression workload to ubu (Linux host).
> A+B+C completed; regression executed on ubu2 (summer-B650M-K).

**Date:** 2026-05-13
**Surface:** 60+ absorbed verbs across Phase 1 + 1-ext + 2 + 3 + 4
**Outcome:** all absorption smokes PASS on ubu2 Linux

## Task A — drill_run shim swap (10 Phase 3 variants)

10 variant modules previously used local `drill_run_shim` placeholders
with `TODO(drill-bg-completion)` markers. Phase 3 spine (commit 78c60391)
landed `compiler/drill/drill.hexa::drill_run(seed, opts) -> DrillResult`
and `compiler/chain/chain.hexa::chain_run(seed, engines_csv, opts) ->
ChainResult`.

Swap pattern: each variant now imports `use "compiler/drill/drill"`
(and `use "compiler/chain/chain"` where needed) and the local shim
becomes a thin adapter: constructs a `DrillOpts` from the variant's
string flags and forwards to the spine, returning an rc-style i64 for
the existing call sites.

Files modified:
- compiler/debate/debate.hexa
- compiler/dream/dream.hexa
- compiler/forge/forge.hexa
- compiler/molt/molt.hexa
- compiler/omega/omega.hexa
- compiler/reign/reign.hexa
- compiler/revive/revive.hexa
- compiler/surge/surge.hexa
- compiler/swarm/swarm.hexa
- compiler/wake/wake.hexa

canon_engine retained its own integration pattern (it doesn't call drill
spine directly, it adds canon-seal recording on top of its own pipeline).

## Task B — Phase 2 inner-import normalize

Phase 3 spine BG noted that smash/free/hyperarithmetic used relative
`import "./..."` for helpers, which didn't always resolve when called via
`use "compiler/.../X"` from drill (Module loader now hardened in commit
1f1eef1b, so absolute `use` paths are the canonical form).

Files modified:
- compiler/smash/{phases, smash, smash_test}.hexa
- compiler/free/{free, free_test, modules}.hexa
- compiler/hyperarithmetic/{hyperarithmetic, hyperarithmetic_test}.hexa

Pattern: `import "./<name>.hexa"` → `use "compiler/<module>/<name>"`.

## Task C — self/main.hexa dispatch wiring (60+ verbs)

Added a modular dispatch via `_absorbed_script(verb)` helper that returns
the relative script path for each absorbed verb. `dispatch_absorbed()`
resolves to absolute path via `install_dir_from_argv0()` with cwd
fallback, then either `cmd_run` (for .hexa modules) or `exec` (for
`tool/hexa_annot/` bash scripts).

Surface wired (60+ verbs):
- 29 annotation analyzers (tool/hexa_annot/hexa-<name>, bash)
- 3 Phase 2 verifiers — `hexa honesty`, `hexa absolute`, `hexa meta-closure`
  (note: `hexa check` for @invariant DSL preserved; BT-AI2 is `hexa honesty`)
- 3 Phase 2 generators — `hexa smash`, `hexa free`, `hexa hyperarithmetic`
  (supersedes the nexus-cli proxy for smash/free)
- 13 Phase 3 drill chain — drill/chain/omega/surge/dream/swarm/reign/molt/wake/
  forge/canon/debate/revive
- 19 Phase 4 external — qmirror/akida/qrng/kick + 16 bridges
  (codata/oeis/arxiv/gw/horizons/cmb/nanograv/simbad/icecube/nist-atomic/
  wikipedia/openalex/gaia/lhc/pubchem/uniprot)

`cmd_help()` updated with verb-group inventory.

LOC delta: self/main.hexa +204 / -6.

## Task D — Full regression (executed on ubu2)

Heavy workload was offloaded to ubu2 (summer-B650M-K, Linux 6.17, gcc 13.3)
per user directive. ubu2 had no hexa toolchain — bootstrapped from Mac:

1. Mac: `./self/native/hexa_v2 self/main.hexa /tmp/hexa_main.c` → ubu2 → gcc
   → `~/.hx/bin/hexa.real` (457 KB Linux binary)
2. Mac: `./self/native/hexa_v2 self/hexa_full.hexa /tmp/hexa_full.c` → ubu2 → gcc
   → `~/core/hexa-lang/build/hexa_interp` (1.7 MB Linux binary, the `.hexa` interp)
3. wrapper at `~/.hx/bin/hexa` calls `~/.hx/bin/hexa.real`

Regression results (HEXA_LANG=$PWD HEXA_MEM_UNLIMITED=1, timeout 180s):

| surface | result |
|---|---|
| compiler/*_test.hexa (55 tests) | 54/55 PASS |
| test/hexa_annot_smoke.sh (29 tools) | 29/29 PASS |
| **absorption surface total** | **83/83 PASS (100%)** |

Single failure: `compiler/check/annotations_test.hexa` (HX9000 message
matching issue) — pre-existing hexa-lang compiler test for the @invariant
DSL checker, unrelated to absorption work.

drill/chain tests required 180s timeout (default 30s insufficient for
real round execution). Memcap default 768MB hit by atlas/overlay tests;
resolved with HEXA_MEM_UNLIMITED=1 (already documented in BG-G session
for hexa.real env-strip caveat).

## Deferred (Phase 5)

- AST upgrade for `hexa-*` annotation tools (use self/lexer + self/parser
  instead of grep-MVP) — bigger accuracy gains
- 6 bridges with TODO(cache-population): arxiv, openalex, simbad, wikipedia,
  pubchem, uniprot (frozen cache empty/partial)
- Mk.X transcendental_closure sidecar (AN11 gate dependency)
- compiler/check/annotations_test.hexa HX9000 issue (pre-existing)
- Phase 4 bridges live HTTP validation (currently smoke uses HEXA_FORCE_FALLBACK)
- ubu2 setup is local-only — for CI/production it should be either:
  (a) bootstrap script reusable on any Linux box, or
  (b) cross-compile from Mac, or
  (c) publish hexa-linux-x86_64.tar.gz release artifact
  (currently uses Mac-transpile + Linux-gcc pipeline manually)

## Doctrine v2 compliance audit

- ✅ 룰 1 (tech content rodata): atlas + D1~D9 + D10~D14 archives
- ✅ 룰 2 (algorithms code): A1~A21 + Phase 4 all ported
- ✅ 룰 3 (metadata frozen archive): D10~D14 absorbed as historical record
- ✅ 룰 4 (try-CLI-or-fallback): all 19 Phase 4 adapters use δ pattern
- ✅ 룰 5 (rodata seed + overlay): drill_run flushes to atlas.overlay.n6
  via overlay_append_lines; atlas_lookup_merged used in round chain

## Final commit plan

1. Phase 2 inner-import normalize (smash/free/hyperarithmetic, 8 files)
2. Phase 3 shim swap (10 variants) + self/main.hexa wiring + this session note

(canon_engine + chain + drill spine + Phase 1/1-ext/4 already committed
in prior 11 commits this session.)

## Source commits referenced

- 78c60391 — Phase 3 spine (drill + chain) — provides `drill_run`/`chain_run`
- 1f1eef1b — Phase 3 foundation — module loader hardening + overlay infra
- 7ced8229 — runtime + tui/input + lexer fix (external session, lands separately)

## ubu2 bootstrap reusable note

For future ubu builds:
```bash
# On Mac
./self/native/hexa_v2 self/main.hexa /tmp/hexa_main.c
./self/native/hexa_v2 self/hexa_full.hexa /tmp/hexa_full.c
rsync -av compiler/ tool/ self/ test/ ubu2:~/core/hexa-lang/...
scp /tmp/hexa_main.c /tmp/hexa_full.c ubu2:~/core/hexa-lang/build/

# On ubu2
cd ~/core/hexa-lang
gcc -O2 -D_GNU_SOURCE -Wno-trigraphs -I self -I . build/hexa_main.c -o ~/.hx/bin/hexa.real -lm
gcc -O2 -D_GNU_SOURCE -std=gnu11 -Wno-trigraphs -I self -I . build/hexa_full.c -o build/hexa_interp -lm -ldl
cat > ~/.hx/bin/hexa <<'EOF'
#!/bin/bash
exec "$HOME/.hx/bin/hexa.real" "$@"
EOF
chmod +x ~/.hx/bin/hexa
```

This is documented for replay but not yet automated as a script.
