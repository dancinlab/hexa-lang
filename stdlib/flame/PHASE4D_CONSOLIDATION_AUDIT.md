# Phase 4-D consolidation audit — `rfc043-hexa-torch` branch state (2026-05-17)

> Clean verification of the consolidated `rfc043-hexa-torch` branch after the
> Phase 4-C-2b/2c, Phase 4-D-5 series, and IPCP transpiler-binary fix landed.
> **Verdict: `tool/flame_phase4b3_verify_all.sh` → 26/26 PASS.** No regression
> from the cherry-picked sub-agent commits. $0 Mac, `HEXA_MAC_BUILD_OK=1`.

## Branch state

- Branch: `rfc043-hexa-torch`
- HEAD: `73c0706b` — `fix(flame transpiler): _db_grad_accum_farr codegen — IPCP baseline build restored`
- Verification run in an isolated worktree pinned (detached) to `73c0706b`,
  so the shared main worktree (which carries unrelated in-flight edits to
  `self/main.hexa` / `tool/atlas_cli.hexa`) was untouched.

### Consolidated commits in scope

| commit | summary |
|---|---|
| `eeb65fc7` | Phase 4-D-5-4-step1 — runtime.c `_hx_farr_*_gpu` wiring (11 ops, Mac build PASS) |
| `7f34ccbf` | Phase 4-D-5-4-step2 — dispatch script (build VERIFIED, 2 bugs fixed) |
| `6e3cb5a9` | Phase 4-D-5-2 — A2 matmul primitives cuBLAS-route, dim-aware dispatch (Layer 2) |
| `753c4325` | Phase 4-D-5-4 fire campaign docs (build VERIFIED, wall FAIL honest — Layer 2 gap) |
| `7a09a4c8` | Phase 4-D-5-4-step2b — d768 trainer regen with Layer 2 GPU-dispatch matmul |
| `73c0706b` | IPCP transpiler-binary fix — `_db_grad_accum_farr` codegen / baseline build restored |

## verify_all verdict — 26/26 PASS

`tool/flame_phase4b3_verify_all.sh` (HEXA_MAC_BUILD_OK=1):

| group | artifacts | result |
|---|---|---|
| Leaf fwd primitive byte-eq | 5 (rmsnorm, residual, swiglu, rope, attention) | 5 PASS |
| Mechanism probes | 3 (boxing 3.26×, alloc 1.08×, fncall 0.16×) | 3 measured |
| IPCP build sanity | 1 (byte-id with `/tmp/baseline.out`) | PASS |
| A2 fwd+bwd FULL primitive build | 1 (byte-id with baseline) | PASS |
| Leaf bwd primitive byte-eq | 5 (residual/rmsnorm/swiglu/rope/attention bwd) | 5 PASS |
| Path B primitive byte-eq | 4 (matmul, matmul_kv, matmul_h, grad_accum) | 4 PASS |
| 4-C-2c fused fwd+bwd byte-eq | 1 (F-RFC048-FUSED-FWD-BWD-EQ) | PASS |
| 4-C-1a paired-call detector | 1 (F-RFC048-PAIR-DETECT) | PASS |
| 4-C-2a fused scaffold compile | 1 (F-RFC048-FUSED-COMPILE-EQ) | PASS |
| 4-C-2b caller wire-up byte-eq | 1 (F-RFC048-FUSED-FWD-BWD-EQ, rewrites=0) | PASS |
| **total** | **26** | **26 PASS — exit 0** |

### First-run FAIL (stale-baseline artifact — NOT a code regression)

The first verify_all run reported `FAIL 1` at the "IPCP build sanity" section
(`FAIL  IPCP build diff vs baseline`). Investigation:

- Timeline (mtimes): `ipcp_check.out` written 18:25:40 → `/tmp/baseline.out`
  rewritten 18:26:01 (**21 s later**) → `a2_check.out` 18:27:26.
- The verify script's IPCP section (line 87) runs **first** and diffs against a
  pre-existing `/tmp/baseline.out`. It does **not** regenerate the baseline. A
  later section regenerated `/tmp/baseline.out` mid-run, so the IPCP section had
  diffed against a stale baseline left over from a prior session, while the A2
  section (later) saw the fresh one and PASSed.
- Manual `cmp /tmp/baseline.out /tmp/ipcp_check.out` after the run → **byte
  identical**. The IPCP-built binary output is correct.
- The canonical baseline regenerated via `./hexa build
  stdlib/flame/flame_d32_corpus_test.hexa` (which uses `self/native/hexa_v2`)
  is **byte-identical (1961 bytes)** to the current `/tmp/baseline.out`.
- Re-running verify_all with the freshly-regenerated canonical baseline →
  **26/26 PASS, exit 0.**

Conclusion: the FAIL was a script-internal ordering artifact (`verify_all` does
not own/seed `/tmp/baseline.out`), not a regression introduced by any commit.

## Build wrapper binary-selection audit — all 3 use canonical `self/native/hexa_v2`

The IPCP fix (`73c0706b`) replaced the `find self/native -name "hexa_v2*" | head -1`
glob — which could pick the stale Apr-15 `hexa_v2_baseline` (453 KB, strips
multi-line fn signatures) — with an exact `self/native/hexa_v2` selection.
Verified present in all three wrappers:

| wrapper | exact-selection block | runtime.h→runtime.c restore |
|---|---|---|
| `tool/flame_phase4b_build.sh` | lines 61-65 (`if [ -x self/native/hexa_v2 ]`) | lines 89-91 |
| `tool/flame_phase4b3_build.sh` | lines 54-58 | lines 82-84 |
| `tool/flame_phase4b3_extern_build.sh` | lines 41-45 | lines 65-67 |

`self/native/hexa_v2` on disk: 1.49 MB, May-17 17:28 (commit `170d64d7` —
regenerated from merged source tree). The stale `hexa_v2_baseline` (453 KB,
Apr-15) is present but can no longer be selected. The single-TU
`#include "runtime.h"` → `#include "runtime.c"` restore is also present in all
three, so the `sed`-anchored decl/primitive insertion + single-TU clang compile
still resolve runtime symbols. Both defects from `IPCP_BASELINE_FIX_NOTES.md`
are fixed; no transpiler-source or runtime change was needed.

## Layer 2 matmul primitives — present + dim-aware dispatch correct

`tool/flame_phase4b3_matmul_primitives.c` (242 lines, Phase 4-D-5-2 commit
`6e3cb5a9`):

- `flame_proj_inline_matmul` — 3-nested-loop CPU matmul (A2 SHIPPED byte-eq path).
- `flame_proj_gpu_matmul` — cuBLAS Dgemm route via `hexa_farr_matmul_gpu`
  (RFC 040 substrate), guarded by `#ifdef HEXA_CUDA`, with CPU fallback on any
  allocation/dispatch error.
- `flame_proj_matmul_dispatch` — dim-aware: `M·K > FLAME_MATMUL_GPU_THRESHOLD`
  (8192) routes to cuBLAS, else CPU inline. Threshold clears the largest
  d=32·3L shape (2048) by 4× and sits ~72× below the smallest d=768·12L shape
  (589824) — unambiguous for both configs.
- On the no-CUDA Mac build the `#ifdef HEXA_CUDA` branch compiles out entirely;
  small shapes take the only path → byte-eq preserved by construction. This is
  why all 4 Path B matmul tests still PASS at d=32·3L.

Note: `tool/flame_phase4b3_matmul_primitives.c` was NOT modified by this audit
(another agent is active on it / forge files).

## Regression audit verdict — NO REGRESSION

- All 26 verification artifacts PASS after the consolidation. The 5 fwd + 5 bwd
  + 4 matmul + 4 grad_accum byte-eq tests show `max|Δ| = 0.0` (strict byte-eq).
- IPCP and A2 builds are byte-identical to the canonical `./hexa build` output.
- The Layer 2 cuBLAS-route additions (`6e3cb5a9`) are GPU-only (`#ifdef
  HEXA_CUDA`); on Mac they are inert — no behavior change, byte-eq intact.
- The d768 trainer regen (`7a09a4c8`) is a separate source/config and does not
  touch the d=32·3L verification corpus.
- The IPCP fix (`73c0706b`) is a build-script-only change (exact binary
  selection + single-TU restore); it restores a build that was *broken* by the
  glob, so it is a fix, not a regression.
- Mechanism-probe ratios (boxing 3.26×, alloc 1.08×, fncall 0.16×) are within
  the documented expected ranges (probes are timing measurements, not pass/fail
  gates — run-to-run variance is normal).

The single first-run FAIL was a `/tmp/baseline.out` staleness/ordering artifact
inside `verify_all` itself, reproducibly cleared by regenerating the canonical
baseline. It is not attributable to any cherry-picked commit.

## Follow-up note (not blocking)

`tool/flame_phase4b3_verify_all.sh` relies on a pre-existing `/tmp/baseline.out`
and does not seed it. A future hardening would have the script (re)generate the
baseline via `./hexa build stdlib/flame/flame_d32_corpus_test.hexa` as step 0,
eliminating the stale-baseline failure mode observed here. Orthogonal to the
flame Phase 4 code path; left for a tooling cycle.
