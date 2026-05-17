# flame docs INDEX (2026-05-17)

> Document hierarchy for `stdlib/flame/` — navigation guide for the
> 18 markdown + 1 .tape SSOT after Phase 4-B FULLY SHIPPED + Phase 4-D
> infrastructure ready + Phase 4-C 4-C-1a started.

## Start here (entry points by use case)

| If you want... | Read |
|---|---|
| **What is flame? (1-minute version)** | `README.md` headline + status block |
| **Current state in one page** | `STATUS.md` (seventh iteration) |
| **Phase 4-B SHIPPED closure summary** | `PHASE4B_SHIPPED_SUMMARY.md` |
| **Reproduce Phase 4-B 3.23× wall** | `PHASE4B_SHIPPED_SUMMARY.md` §Reproduce |
| **Run verification battery** | `tool/flame_phase4b3_verify_all.sh` (23+ artifacts) |
| **Roadmap** | `PLAN.md` |
| **Chronological event log** | `FLAME.tape` `## Log` section |
| **Measurement ledger** | `PERF.md` |

## Top-level SSOTs

```
README.md         — flame headline + 18-block status (Phase 4-B SHIPPED ≥3×)
STATUS.md         — single-page consolidated state (7 iterations)
PLAN.md           — staged roadmap (Phase 3 → 4 → 5)
PERF.md           — measurement ledger (baseline tables + mechanism probes)
FLAME.tape        — append-only event history (.tape v1.2)
NEXT_CYCLE.md     — SUPERSEDED marker → STATUS.md (kept for falsifier matrix detail)
INDEX.md          — this file
```

## Phase 4-B design docs (SHIPPED)

```
PHASE4B_SCAFFOLD.md              — Phase 4-B-1 IPCP detect + scaffold findings
PHASE4B_SHIPPED_SUMMARY.md       — 🎯 single-page closure (TL;DR + reproduce)

PHASE4B3_EMISSION_DESIGN.md      — Phase 4-B-3 mechanism design (3 micro-bench probes)
PHASE4B3_LEAF_PRIORITY.md        — leaf primitive ABI + priority (outdated framing,
                                    see PHASE4B3_DESIGN_CORRECTION below)
PHASE4B3_DESIGN_CORRECTION.md    — block_fwd is INLINE not leaf-call (correction
                                    that pivoted leaf-by-leaf → A2 whole-block)
PHASE4B3_BLOCK_FWD_AUDIT.md      — fwd 9-section roadmap
PHASE4B3_BWD_AUDIT.md            — bwd 9-section roadmap (mirror)
PHASE4B3_2_INTEGRATION.md        — Phase 4-B-3-2 build pipeline integration design
PHASE4B3_EXTERN_FN_FINDING.md    — extern fn POC FAIL — Path W1 infeasible per
                                    HexaVal mandate (negative finding documented)
```

## Phase 4-D + 4-C prep docs

```
PHASE4D_GPU_DISPATCH_DESIGN.md   — Phase 4-D scope + 4-5 sub-phase breakdown
PHASE4D_DISPATCH_CLI_GUIDE.md    — runpod/vast.ai install + auth + cost reference
                                    (runpod auth WIRED, $304 balance, A100 SXM ready)
PHASE4C_IMPLEMENTATION_AUDIT.md  — RFC 048 Phase 4-C audit + 4-C-1a smallest-viable
                                    scope (autonomous-able PARTIAL)
```

## Source files (Phase 4-B SHIPPED chain)

```
nn_lib.hexa                       — 7 leaf NN ops (verified Phase 2 byte-eq foundation)
decoder_block_lib.hexa            — block fwd+bwd composition (9 sections)
decoder_lib.hexa                  — full decoder (block stack composition)
train_lib.hexa                    — AdamW + train step
flame_math.hexa                   — dt_sqrt + dt_exp + dt_ln (anima Taylor port)
optim_lib.hexa                    — AdamW thin wrapper
tensor_lib.hexa                   — Tensor wrappers (t_zeros, t_get, etc.)
autograd_lib.hexa                 — ag_* tape wrappers (RFC 034)
flame.hexa                        — Phase 1 entrypoint + selftest

flame_*_test.hexa                 — Phase 2 falsifier harnesses + d=32·3L corpus
flame_d128_2L_smoke_test.hexa     — Phase 4-D-3 smoke (3/3 PASS, scaled config)
flame_d768_12L_corpus_test.hexa   — Phase 4-D-4 GPU target (build PASS local)
```

## Tooling (Phase 4-B + 4-C + 4-D)

```
tool/flame_phase4b_scan.hexa           — Phase 4-B-1 IPCP call site scanner
tool/flame_phase4b_ipcp.hexa           — Phase 4-B-2 IPCP rewriter
tool/flame_phase4b_build.sh            — Phase 4-B-2 IPCP build wrapper
tool/flame_phase4b3_emit_skeleton.hexa — Phase 4-B-3-1 emitter scaffold (skeleton)
tool/flame_phase4b3_emit_trampoline.hexa — Phase 4-B-3-2 trampoline emit
tool/flame_phase4b3_build.sh           — Phase 4-B-3 trampoline + wire-up wrapper
tool/flame_phase4b3_a2_build.sh        — Phase 4-B-3 A2 fwd+bwd + Path B FULL wrapper
tool/flame_phase4b3_extern_build.sh    — extern fn POC build (failed, kept for reference)
tool/flame_phase4b3_verify_all.sh      — 23-artifact self-verifying battery (24 after 4-C-1a)

tool/flame_phase4b3_*_primitive.c      — A2 fwd/bwd + matmul primitives (Phase 4-B-3)
tool/flame_phase4b3_*_bench.c          — 3 mechanism probes (boxing/alloc/fncall)
tool/flame_phase4b3_leaf_*_test.c      — 10 leaf primitive byte-eq tests

tool/flame_phase4d_dispatch.sh         — Phase 4-D-2 GPU dispatch script template
tool/flame_phase4c_pair_detect.hexa    — Phase 4-C-1a paired-call detector
```

## RFC index (cross-link to `inbox/rfc_drafts_2026_05_12/`)

```
RFC 040 — device-farr + cuBLAS Dgemm (LANDED — runtime substrate)
RFC 043 — flame design SSOT (LANDED — Phase 3 SHIPPABLE complete)
RFC 045 — Phase 3 closure (LANDED — algorithm-byte-eq with anima oracle)
RFC 046 — Phase 4 compiler fusion framework
RFC 047 — Phase 4-B IR pass design (🎯 SHIPPED 2026-05-17 — 3.23× cool wall)
RFC 048 — Phase 4-C fwd+bwd graph fusion (4-C-1a STARTED)
```

## Verification battery (single-command gate)

```bash
tool/flame_phase4b3_verify_all.sh
# Currently 23 artifacts (24 after 4-C-1a scaffolding complete)
# Exit 0 if all PASS, 1 if any FAIL
```

## What's NOT in flame scope

- **GPU substrate** — see `self/forge/` (RFC 044 sibling, parallel session)
- **hexa-lang compiler internals** — `self/codegen_c2.hexa` etc.
- **Consumer integration** — wilson / anima / echoes (downstream repos)
- **Production `./hexa build` modifications** — Phase 4-B uses parallel wrappers,
  doesn't modify the production path

## Honest framing (AGENTS.tape g3)

All performance claims in flame/ docs are:
- Measurement-anchored (5-run avg, var disclosed)
- Revision-honest (estimates revised when measurement contradicts)
- Failed hypotheses documented (extern fn POC, Path C dV revert)
- Cool vs thermal-elevated baseline disclosed
- No fabricated multiples — all wall figures from 5-run measurements
- No n=6 lattice perf assertion anywhere

For falsifier definitions + verification methodology, see PERF.md §Measurement convention
+ verify_all.sh + PHASE4B_SHIPPED_SUMMARY.md §Verification.
