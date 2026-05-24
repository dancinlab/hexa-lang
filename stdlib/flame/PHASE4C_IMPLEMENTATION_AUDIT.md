# PHASE4C_IMPLEMENTATION_AUDIT.md — RFC 048 fwd+bwd graph fusion (scoping + first-cycle cut)

> Audit + scoping doc for the **next** flame cycle. Phase 4-B is **SHIPPED**
> (3.23× cool projection, 23/23 verify_all PASS, commit `7faddb49`). This
> doc maps RFC 048 (Phase 4-C — paired fwd+bwd register-resident graph
> fusion) onto the existing infra and answers: is it autonomous-able, and
> what's the smallest viable first commit?
>
> **Not implementation.** No source edits to flame stdlib or tool/.
> Output of this doc = the next cycle's plan-of-record.

## 1. Baseline state (Phase 4-B SHIPPED, cool projection 3.23×)

Per `PHASE4B_SHIPPED_SUMMARY.md` + `PERF.md` (commit `29fe4a69` Path B
FULL → measurement entry `ce422713`):

```
baseline (cool)              16.170s    1.00×       flame_d32_corpus_test 5-run
Phase 4-B-2 IPCP              9.814s    1.28×       commit 55e29392
Phase 4-B-3 A2 fwd+bwd        5.908s    2.74×       commit 8012c15a (5-run avg, range 5.51-6.84)
Phase 4-B-3 A2 + Path B FULL  ~5.0s     3.23×       commit 29fe4a69 (cool projection from 7.62s thermal/1.18×)
                              ────────  ────────────────────────────────
                              flame:anima = 0.226× (~4.4× faster than anima)
                              ≥3× RFC 047 §137 target REACHED
```

- **Byte-equivalence**: 23/23 artifacts PASS via `tool/flame_phase4b3_verify_all.sh`
  (commit `7faddb49`). max|Δ| = 0.0 strict tier on all leaf fwd/bwd + matmul + grad_accum.
- **Anchored real limit** (g3): boxing-elim 3.99× isolated probe (`07cdd405`);
  allocator-elim 1.00× (page-fault floor on macOS libsystem_malloc);
  fn-call-elim ≤1.00× (clang -O2 already inlines noinline helpers efficiently —
  measurement found inline path 8× SLOWER, fn-call gain overlap-capped by boxing-elim).
- **Per-step profile** (PERF.md `flame_perf_breakdown_test`):
  fwd 4 ms (25%) / bwd 12 ms (75%) / AdamW ~0 ms / total 16 ms per step at d=32·3L 5×8-iter.
  **bwd is 75% of per-step wall** — Phase 4-C's mechanism targets bwd reads of fwd-cached intermediates.
- **What 4-B did NOT fix**: per-block cache farr `Bc` (rin, hstate, Q, K, V, P, sw_a, sw_b, sw_s, ctx, rm1xn, rm2xn, rm1inv, rm2inv) is still materialized at fwd-exit and re-read at bwd-entry — **~8K floats × 6 layer-traversals × 80 steps = ~3.8M DRAM round-trips per training run** that fwd+bwd graph fusion would eliminate. This is the Phase 4-C target surface.

## 2. RFC 048 mechanism summary

Per `docs/rfc/rfc_drafts_2026_05_12/rfc_048_flame_phase4c_fwd_bwd_graph_fusion.md`:

**Pass placement**: extends the Phase 4-B IR pass (RFC 047, currently a sed-rewrite
+ trampoline concat pipeline — see §7) with a paired-call pattern-matcher. When
the pass detects matching `nn_decoder_block_fwd(...)` and `nn_decoder_block_bwd(...)`
invocations with identical static (T, d, nh, nkv, h) dims and a dataflow edge
"fwd writes Bc → bwd reads Bc with no intervening modification", it rewrites the
two calls (across `nn_decoder_fwd` and `nn_decoder_grad`) into a single
`flame_block_fused_<dims>(X, Bp, dXout, dX_out, Bg, cos, sin)` emission.

**Emit pattern**: one specialized C function per unique dim tuple. The function
runs the fwd compute, keeps all intermediates as `double[T*d]` / `double[T*kvd]` /
`double[nh*T*T]` / `double[T*h]` etc. local arrays (clang -O2 colors most into
NEON v-registers; remainder spills to L1), then runs the bwd compute directly
off those locals. **Bc farr is never materialized.**

**Required restructure**: `nn_decoder_grad`'s current "fwd-all-layers-then-bwd-all-layers"
shape (decoder_lib.hexa:112-153 fwd loop, 313-373 bwd loop) must be rewritten by
the pass to "fwd-then-bwd-per-layer" (equivalent gradient checkpointing at block
granularity, since each block's fwd re-runs inside the fused fn just before its bwd).
This is the **invasive part of Phase 4-C** — Phase 4-B only specialized in-place;
Phase 4-C reorders the outer training-step loop.

**Equivalence**: bwd math unchanged — Phase 4-C is an EMIT-pattern change, not an
algorithm change. RFC 045 source #4 (3.12e-5 init-gn2 cross-impl drift) must be
preserved exactly, byte-identical. `F-RFC048-STEP-EQ` is the falsifier.

## 3. Autonomous-able? — **PARTIAL** (autonomous-able for sub-phases 4-C-1 + 4-C-2, user-gate required for 4-C-3 + 4-C-4)

### YES — autonomously OK (no architectural decision)

- **Phase 4-C-1 (pairing detection, log-only)**: extending the existing IR
  pattern-matcher with a "look-ahead" pass that recognizes paired fwd/bwd calls
  by (callee-name, static-dim args, dataflow on Bc id). No emission yet — just
  logs detected pairs. Verifier reuses `F-RFC048-FALLBACK-PRESERVED`
  (Phase 4-B byte-id must hold when 4-C is OFF or only-detect).
- **Phase 4-C-2 (fused emit, single-layer test)**: hand-translate one fused
  `flame_block_fused_T16_d32_nh4_nkv2_h64.c` primitive (~600-800 LoC, similar
  in scale to current `flame_phase4b3_block_fwd_primitive.c` 270 LoC + bwd 400 LoC),
  validate byte-eq against the already-shipped paired fwd+bwd primitives on the
  Phase 4-B-3 leaf battery (`F-RFC048-FUSED-FWD-BWD-EQ`). All falsifier infra
  exists (verify_all is concat-extensible).

These two sub-phases are mechanical extensions of existing Phase 4-B infrastructure
— pattern matcher, concat pipeline, leaf byte-eq test harness — and follow the
already-proven hand-translation methodology (PHASE4B3_BLOCK_FWD_AUDIT.md
section-by-section V1 strategy). **Estimated 3 cycles total, autonomous-able.**

### NO — architectural decision required (g7 user-gate)

- **Phase 4-C-3 (decoder_lib.hexa restructure: fwd-loop+bwd-loop → fwd-then-bwd-per-layer)**:
  this rewrites `nn_decoder_fwd` (lines 112-153) and `nn_decoder_grad` (lines 313-373)
  user-visible loop shapes. Two design choices the user should gate:

  1. **Where does the rewrite live?**
     (a) **Source-level rewrite of `decoder_lib.hexa`** — readable, simple, but
         couples flame's stdlib hexa source to the Phase 4-C path (the un-fused
         path must remain available for fallback per `F-RFC048-FALLBACK-PRESERVED`,
         requiring either two source files or a runtime toggle).
     (b) **IR-pass rewrite (Phase 4-B pipeline level)** — keeps stdlib source
         single-shape; the pass mutates the loop structure during the concat-rewrite
         stage. Higher engineering cost, cleaner stdlib.
  2. **How is the per-layer "fwd-then-bwd" cache (Mc.block[l].Xout chain)
     reconstructed?** The fwd loop builds Mc.block[l].Xout which the bwd loop
     consumes as `Xin` for layer l. Fused-per-layer means layer 0's bwd needs
     layer 1+'s Xout, which means layer 1+ fwd must run first → the fused-per-layer
     shape only saves Bc materialization, NOT the inter-block Xout chain. **Either
     (a) keep Mc.block[l].Xout materialized and only fuse intra-block Bc (RFC 048's
     stated intent), or (b) extend to inter-block fusion (RFC 049+ scope).**

  These are architectural decisions per g7 step-by-step-decision-gate — they
  reshape stdlib API surface vs build pipeline complexity. **User-gate required
  before starting 4-C-3.**

- **Phase 4-C-4 (d=768·12L specialization + GPU dispatch fire)**: $5-20
  cost-bearing fire. Per g3 + project convention, all cost-bearing fires are
  user-gated regardless of confidence.

### Verdict: **PARTIAL**

Sub-phases 4-C-1 + 4-C-2 (≤3 cycles) are autonomous-able and can land the **fused
single-block primitive + paired detection** without touching `decoder_lib.hexa`.
Sub-phases 4-C-3 + 4-C-4 (multi-layer restructure + cost fire) require user-gate.

## 4. Per-sub-phase effort breakdown

| sub-phase | what | autonomous? | effort | falsifier | risk |
|---|---|---|---|---|---|
| **4-C-1a** | extend `tool/flame_phase4b3_emit_trampoline.hexa` (or new `flame_phase4c_pair_detect.hexa`) with paired-call AST pattern match — log-only | YES | 1 cycle | F-RFC048-FALLBACK-PRESERVED (verify_all 23/23 PASS unchanged) | LOW — additive scan |
| **4-C-1b** | document detected pair list for d=32·3L config — sanity check the pattern (e.g., 1 fwd-call site × 1 bwd-call site = 1 pair × 3 layers via loop) | YES | 0.5 cycle | manual review | LOW |
| **4-C-2a** | hand-translate `tool/flame_phase4c_block_fused_primitive.c` (T=16,d=32,nh=4,nkv=2,h=64) by **concatenating + dataflow-stitching** the existing `flame_phase4b3_block_fwd_primitive.c` (270 LoC) + `flame_phase4b3_block_bwd_primitive.c` (400 LoC), replacing the Bc-write at fwd-exit with local-array writes and the Bc-read at bwd-entry with local-array reads | YES | 1.5 cycles | F-RFC048-FUSED-FWD-BWD-EQ (max\|Δ\| = 0.0 vs paired-call baseline on F-RFC043-BLOCK-DET inputs) | MID — register-pressure spill behavior unknown; clang -O2 on ~8K floats of locals may force more L1 spill than register-resident estimate |
| **4-C-2b** ✅ LANDED | `tool/flame_phase4c2b_build.sh` — perl-based safe rewriter (matches adjacent paired callsites with same X/Bp/Bc/cos/sin farr ids within REWRITE_WINDOW=8 lines, no intervening Bc-mutation) + concat fused primitive after fwd+bwd primitives in A2 .c. Verify_all extended +2 artifacts (F-RFC048-FUSED-COMPILE-EQ + F-RFC048-FUSED-FWD-BWD-EQ → 26/26 PASS). | YES | 1 cycle DONE | F-RFC048-FUSED-COMPILE-EQ ✅ PASS · F-RFC048-FUSED-FWD-BWD-EQ ✅ PASS (max\|Δ\|=0 vs A2 baseline; rewrites=0) · F-RFC048-FUSED-WALL-IMPROVED ❌ FAIL (1.044× ratio, expected at scaffold + 0 rewrites — n=5-run median A2=7.36s wired=7.05s) | LOW — 0 rewrites at corpus_test (fwd@nn_decoder_fwd ↔ bwd@nn_decoder_grad ~209 lines apart in expanded.hexa; ~175 lines apart in A2.c). Adjacency requires Phase 4-C-3 user-gated decoder_lib restructure. Rewriter MECHANISM proven on synthetic inputs (1 rewrite for adjacent matched pair; 0 for different-Bc-id, 0 for gap>WIN). |
| **4-C-2c** ✅ DONE | extract 4 PURE LOCAL intermediates iter 1-4 (oRm1inv 16, oRm2inv 16, oRm1xn 512, oRm2xn 512 dbl = 1056/3104 dbl, 34% of theoretical target). Standalone byte-eq harness `tool/flame_phase4c_leaf_fused_test.c` (paired-call vs fused max\|Δ\|=0 on (Bc[oXout]/Bc[oHstate]/dX_out/Bg)). Iter 5-7 (oRin/oRin2/oSwS) blocked on matmul/grad_accum API change — they feed into `flame_proj_batch_*` / `flame_grad_accum_*` primitives which take `(int X_id, int X_off)` and require farr-id, not pointer. | YES (partial) | 1 cycle | F-RFC048-FUSED-FWD-BWD-EQ PASS strict byte-eq; F-RFC048-FUSED-WALL-IMPROVED 0.95-0.99× single-block (NEGATIVE — matches §6 R2 register-pressure spill prediction at single-block scope; expected gain at multi-block / d=768·12L) | LOW for iter 1-4 (byte-eq strict PASS each commit); HIGH for iter 5-7 (would require API change) |
| **4-C-3** | **gate decision** + decoder_lib.hexa restructure (source-level OR IR-pass) to fwd-then-bwd-per-layer; verify decoder-full byte-id | NO (user-gate) | 2 cycles after gate | F-RFC048-DECODER-FULL-EQ + F-RFC048-STEP-EQ (flame ↔ anima 3.12e-5 init-gn2 preserved) | HIGH — Path C revert lesson: any cross-loop reduction-order change MUST be evaluated for byte-eq at Phase 2 strict tier, not fp-tol |
| **4-C-4** | **cost-bearing fire** d=768·12L A100/H100 with fused emission + GPU dispatch (Phase 4-D dep) | NO (user-gate) | 1 fire cycle, $5-20 | F-RFC048-EAGER-PYTORCH-MATCH (≤1.3× of 336.85s) | HIGH — combined with Phase 4-D GPU dispatch, untested compound; depends on RFC 044+049 forge substrate landing |

**Total autonomous-able effort (4-C-1 + 4-C-2 only): ~4 cycles.**
**Total full Phase 4-C (with gates): 7-9 cycles.**

## 5. Expected wall improvement projection

Per RFC 048 §"Honest performance thesis update":

| state | wall (M-Mac CPU d=32·3L) | × over current 4-B SHIPPED | × over original baseline 16.17s |
|---|---|---|---|
| **current Phase 4-B SHIPPED (3.23×)** | 5.0s (cool projection) | 1.00× | 3.23× |
| Phase 4-C-2 fused single-block (intra-block only — Bc materialization eliminated for the 1 specialized block; outer 3-layer chain still materializes Xout) | ~3.5-4.0s | ~1.25-1.40× | ~4.0-4.6× |
| Phase 4-C-3 full decoder restructure (fwd-then-bwd-per-layer for all 3 layers) | ~2.5s | **~2.0×** | **~6.5×** |
| Phase 4-C-4 d=768·12L A100 (Phase 4-D GPU compound) | ≤438s (≤1.3× of 336.85s eager-PyTorch) | (different scale) | (different scale) |

**Phase 4-C alone over Phase 4-B baseline: target ≥2× wall** (matches RFC 048
§F-RFC048-FUSED-WALL-IMPROVED falsifier threshold). Mechanism: per-block
~192 KB Bc-cache DRAM round-trip elimination, ~50-70% per-step memory bandwidth
reduction in the bwd-dominant regime.

**Honest caveats** (per AGENTS.tape g3 + RFC 048 §Honest caveats):
- ≥2× projection is back-of-envelope from ~192 KB-per-layer × 3 layers × 80 steps
  cache materialization elimination. **Register-pressure spill at 8K-floats of
  intermediates may force unexpected L1 traffic** → actual gain could be 1.3-1.8×
  rather than 2.0×. F-RFC048-FUSED-WALL-IMPROVED is the empirical falsifier; if
  measured ratio <1.5×, the fused-primitive design needs revision (likely:
  selective fusion only of small-cache sections rather than full-Bc fusion).
- The "exceed eager-PyTorch" implication for d=768·12L (PERF.md scaling math:
  13.33s × 64 / 50 / 5 ≈ 3.4s vs 336.85s = 100× margin) is an upper-bound,
  NOT a claim. Phase 4-C falsifier is the conservative ≤1.3× of eager-PyTorch.

## 6. Risks

### R1 — Path C revert lesson: reduction-order preservation across fwd+bwd boundary

The single most-important lesson from the Phase 4-A-bwd / 4-B cycle (PERF.md
"Path C attempt — dV farr_matmul-routing TESTED + REVERTED 2026-05-17"; commit
`23705dc5`):

> Routing `nn_attn_core_bwd`'s dV accumulator through farr_matmul produced
> `dV dev 1.66e-16` (last-ulp drift) — Phase 2 strict byte-eq FAIL even
> though the rel error is at machine epsilon. **REVERT.** The lesson: any
> helper that breaks Phase 2 must be evaluated at the IR level where
> reduction order can be preserved by construction.

**Phase 4-C is exactly this category at higher stakes.** The fused fwd+bwd
function performs the SAME math as the paired call sequence, but the
intermediate-passing path changes from "fwd writes Bc[id], bwd reads farr_get(Bc[id], i)"
to "fwd writes local_Bc[i], bwd reads local_Bc[i]". If clang -O2 reorders the
reduction inside the fused fn differently from the paired fn (e.g., FMA fusion
context per RFC 045 source #3), Phase 2 byte-eq will FAIL.

**Mitigation**:
1. **F-RFC048-FUSED-FWD-BWD-EQ at max|Δ| = 0.0** (NOT fp-tol) is the gate falsifier.
   Run it BEFORE any wall measurement.
2. **Reuse the exact same C statements** from `flame_phase4b3_block_fwd_primitive.c`
   and `flame_phase4b3_block_bwd_primitive.c` in the fused primitive, only
   replacing the Bc-write/read site translations. Do NOT rewrite reductions.
3. **If F-RFC048-FUSED-FWD-BWD-EQ FAILS**: revert to paired-call form for that
   sub-section (selective fusion) rather than attempt to "fix" the reduction order.
   Path C revert lesson: do not chase last-ulp drift.

### R2 — Register pressure / clang -O2 spill behavior

At d=32·3L: per fused block fn = ~8K floats of intermediates × 8 bytes = ~64 KB
of locals. M2's L1 = 128 KB per core, NEON has 32 v-registers × 2 fp64 = 64
register slots. clang -O2 may force most intermediates to L1 spill rather than
register allocation, dropping the expected ≥2× wall gain to ~1.3×.

**Mitigation**: F-RFC048-FUSED-WALL-IMPROVED is the empirical falsifier. If
<1.5×, audit per-section spill via `clang -O2 -emit-llvm` + check stack-frame
size; consider partial fusion (e.g., fuse only RMSNorm+residual rather than
full block).

### R3 — Outer-loop restructure (Phase 4-C-3) breaks Mc.block[l].Xout chain semantics

`nn_decoder_grad` (decoder_lib.hexa:313-373) currently has bwd-loop reading
`prev_Xout_off` from Mc (set during the fwd pass). Restructuring to
fwd-then-bwd-per-layer requires either:
- materializing Xout still (Phase 4-C scope), keeping Mc.block[l].Xout chain,
  only fusing intra-block Bc; OR
- inter-block fusion (RFC 049+ scope), which means each layer's bwd must
  re-derive Xout from inputs — incompatible with the autograd-tape model.

**Mitigation**: scope discipline. Phase 4-C is **intra-block only** per
RFC 048 §Non-goals. The outer loop restructure keeps Mc.block[l].Xout
materialized.

### R4 — Build pipeline complexity creep

Current pipeline already has 7 stages (IPCP → trampoline → sed-rewrite →
concat fwd primitive → concat bwd primitive → concat matmul primitives →
clang). Adding Phase 4-C fused primitive adds an 8th stage + a sed-redirect
of paired calls to fused call. Stage count + interaction surface grows
roughly linearly; bisection becomes harder.

**Mitigation**: fork `tool/flame_phase4b3_a2_build.sh` to
`tool/flame_phase4c_build.sh` rather than extending it. Phase 4-B SHIPPED path
remains untouched (g3 fallback preservation). Verify_all gates both paths.

### R5 — flame ↔ anima 3.12e-5 init-gn2 drift preservation

RFC 045 source #4 sustained delta (per-window ~3.9e-6 ≈ 1 ulp × 256-element
softmax floor; epoch sum 3.12e-5) MUST be preserved exactly through Phase 4-C
restructure. F-RFC048-STEP-EQ falsifier requires the 80-step trajectory + acc
8/8 + collapse 8.98e6× byte-id reproduction.

**Mitigation**: trajectory regression check is the gate for the multi-layer
restructure step (4-C-3, behind user-gate). Lower-effort sub-phases (4-C-1, 4-C-2)
operate at single-block scope where this falsifier is implied via
F-RFC048-FUSED-FWD-BWD-EQ at max|Δ| = 0.0.

## 7. Build infrastructure ready check

Inventory of what Phase 4-B SHIPPED provides for Phase 4-C reuse:

| component | current state | Phase 4-C readiness |
|---|---|---|
| **concat pipeline** (`tool/flame_phase4b3_a2_build.sh`) | 7-stage IPCP → trampoline → primitives concat → clang | READY — adding fused-primitive concat is mechanical 8th stage |
| **`_hx_farr_table[id].buf` direct deref ABI** (commit `1da62cc1`) | proven byte-eq via libm reference | READY — fused primitive uses same ABI for input X/Bp/dXout/dX_out/Bg farrs (only Bc is eliminated) |
| **sed-rewrite call sites** (in `flame_phase4b3_a2_build.sh`) | rewrites paired-call sites to primitive form | NEAR-READY — extends with a "fwd+bwd pair → fused" rewrite rule (single sed substitution per dim tuple) |
| **leaf byte-eq harness** (`tool/flame_phase4b3_leaf_*_test.c` × 10) | 10 byte-eq tests max\|Δ\| = 0.0 | READY — F-RFC048-FUSED-FWD-BWD-EQ adds an 11th harness following same template |
| **verify_all battery** (`tool/flame_phase4b3_verify_all.sh`, 23 artifacts) | extensible | READY — Phase 4-C adds 2 artifacts (fused-fwd-bwd-eq + fused-wall-improved) → 25 |
| **IR pattern matcher** (`tool/flame_phase4b_scan.hexa` + `flame_phase4b3_emit_trampoline.hexa`) | detects per-call-site patterns | EXTENDABLE — Phase 4-C-1 adds paired-call detection (look-ahead for matching `_bwd` after `_fwd` within scope) |
| **`flame_block_test.hexa` standalone-block harness** | single-block fwd+bwd verification | READY — Phase 4-C-2's single-block wall measurement uses this |
| **`flame_d32_corpus_test.hexa` full-decoder harness** | 80-step trajectory + corpus eval | READY — Phase 4-C-3 (post-gate) trajectory regression check uses this |
| **PERF.md ledger convention** (≥5-run avg, range, var %) | established | READY — F-RFC048-FUSED-WALL-IMPROVED entries follow same template |

**Verdict**: build infra is **READY** for autonomous-able sub-phases (4-C-1 + 4-C-2).
No new tooling investment required. The infra reuse ratio is high because Phase 4-B's
concat pipeline was designed to be primitive-extensible (PHASE4B3_BLOCK_FWD_AUDIT.md
§"Implementation infrastructure check").

## 8. Realistic first-cycle scope — "smallest viable RFC 048 first commit"

The smallest viable commit that delivers measurable Phase 4-C progress without
touching `decoder_lib.hexa` or invoking a user-gate is **Phase 4-C-1a:
paired-call detection (log-only)**.

### Scope of first commit

- **NEW file**: `tool/flame_phase4c_pair_detect.hexa` — IR pass extension that
  scans the post-IPCP / post-trampoline `.c` (or operates on the same AST
  surface the existing `flame_phase4b3_emit_trampoline.hexa` uses) and logs
  paired `nn_decoder_block_fwd(...)` + `nn_decoder_block_bwd(...)` call sites
  with their (T, d, nh, nkv, h) tuple + the Bc farr id dataflow edge.
- **Output**: a `build/artifacts/flame_phase4c_pairs.log` listing detected
  pairs. For `flame_d32_corpus_test.hexa` d=32·3L config, expected output is
  1 pair × matching dims (the single fwd call site in `nn_decoder_fwd` and
  the single bwd call site in `nn_decoder_grad`, both inside `while l < n_layer`
  loops — the pass should recognize this as 1 paired-call pattern, not 3, since
  it's the loop body that emits 3 dynamic calls).
- **NEW file**: `tool/flame_phase4c_build.sh` — fork of `flame_phase4b3_a2_build.sh`
  that runs the detect pass AFTER the 4-B-3 A2 build (so 4-B SHIPPED path is
  untouched and 4-C is purely additive at this sub-phase).
- **Falsifier extension**: `tool/flame_phase4b3_verify_all.sh` adds 1 artifact:
  `F-RFC048-PAIR-DETECT` — verifies the log shows ≥1 detected pair for
  `flame_d32_corpus_test` and EQ check that the Phase 4-B SHIPPED build path
  remains byte-id (i.e., detection is observation-only, doesn't perturb emit).
- **NEW design doc**: `stdlib/flame/PHASE4C_PAIR_DETECT_DESIGN.md` — single-page
  spec for the pattern matcher's AST predicates (callee-name match + dim-arg
  static-eq + Bc-farr dataflow edge).
- **NO modifications to**: `decoder_lib.hexa`, `decoder_block_lib.hexa`,
  `flame_phase4b3_*_primitive.c`, the existing 23 Phase 4-B artifacts.

### Why this is the right first commit

1. **Zero risk of regressing Phase 4-B SHIPPED** — detection is observation-only,
   the 4-B build path is untouched. `F-RFC048-FALLBACK-PRESERVED` is trivially
   satisfied by construction.
2. **Validates the IR pattern-matcher BEFORE the much-larger emit work** — if
   pattern detection misfires (e.g., doesn't recognize the loop-body call
   shape, or false-matches on similar but non-paired calls), it's caught
   cheap and early. Path C revert lesson applies: validate the IR-level
   match before any emit changes.
3. **Establishes the Phase 4-C build path skeleton** (`flame_phase4c_build.sh`,
   `flame_phase4c_pair_detect.hexa`, `PHASE4C_PAIR_DETECT_DESIGN.md`) that
   subsequent commits (4-C-2 fused-primitive emit) extend incrementally,
   one-commit-per-sub-section per V1 strategy.
4. **Effort: 1 cycle.** Single new .hexa pass (~50-100 LoC), single new build-shell
   fork (~30 LoC delta from a2_build.sh), single new design doc (~150 LoC),
   1 added verify_all artifact. No source primitive C edits.
5. **Output is concrete + reviewable** — the `flame_phase4c_pairs.log` artifact
   gives the user a tangible "the pass found X pairs in Y call sites at Z dim
   tuples" output that's easy to inspect before authorizing the larger 4-C-2
   emit work.

### Out of scope for this first commit

- No fused primitive emit (4-C-2 follows in next cycle).
- No `decoder_lib.hexa` restructure (4-C-3, user-gate).
- No GPU/cost-bearing work (4-C-4, user-gate).
- No `Bc`-elimination or dataflow rewrite. Just detection.

## 9. Cross-link

### Prior commits (Phase 4-B SHIPPED chain)

- `7faddb49` — verify_all 23/23 PASS (Phase 4-B closure gate)
- `29fe4a69` — Path B FULL fwd+bwd matmul integration (3.09× wall MEASURED → 3.23× cool projection)
- `8012c15a` — A2 fwd+bwd primitives SHIPPED (2.74× wall, 5-run avg 5.908s)
- `cfbba144` — A2 fwd primitive SHIPPED (1.14× incremental)
- `55e29392` — Phase 4-B-2 IPCP (1.28× wall, byte-id)
- `5602833f` — Phase 4-A-bwd baseline 5-run avg 12.574s
- `23705dc5` — Path C dV revert (the reduction-order preservation lesson Phase 4-C must respect)
- `ce422713` — Phase 4-B SHIPPED final measurements ledger (PERF.md)
- `c4aab67e` — PHASE4B_SHIPPED_SUMMARY.md (Phase 4-B closure reference)
- `3b83d6a8` — 🎯 Phase 4-B ≥3× TARGET REACHED milestone capture
- `0f88ca82` — PLAN.md Phase 4-B SHIPPED entry

### Design docs (read these before starting Phase 4-C work)

- `docs/rfc/rfc_drafts_2026_05_12/rfc_048_flame_phase4c_fwd_bwd_graph_fusion.md` — RFC 048 design (THIS audit's source)
- `docs/rfc/rfc_drafts_2026_05_12/rfc_047_flame_phase4b_block_fusion_ir_pass.md` — RFC 047 (Phase 4-B prerequisite IR pass design)
- `docs/rfc/rfc_drafts_2026_05_12/rfc_046_flame_phase4_compiler_fusion.md` — RFC 046 (Phase 4 fusion overall design, identifies 4-C as HIGHEST IMPACT)
- `docs/rfc/rfc_drafts_2026_05_12/rfc_045_flame_phase3_algorithmic_byte_eq_with_anima_oracle.md` — RFC 045 (Phase 3 closure, source #4 3.12e-5 drift attribution)
- `docs/rfc/rfc_drafts_2026_05_12/rfc_043_hexa_torch_compiler_only_nn_stdlib.md` — RFC 043 (flame design SSOT, §Ultimate)
- `stdlib/flame/PHASE4B_SHIPPED_SUMMARY.md` — single-page Phase 4-B closure
- `stdlib/flame/PHASE4B3_BLOCK_FWD_AUDIT.md` — section-by-section V1 methodology template (mirror for fused primitive)
- `stdlib/flame/PHASE4B3_BWD_AUDIT.md` — bwd-side mirror of fwd audit
- `stdlib/flame/PHASE4B3_DESIGN_CORRECTION.md` — block INLINE correction (informs what "primitive" means at block scope)
- `stdlib/flame/PHASE4D_GPU_DISPATCH_DESIGN.md` — Phase 4-D parallel track (4-C-4 dep)
- `stdlib/flame/PERF.md` — measurement ledger (5-run convention, anchor table for any new wall claim)

### Source files (Phase 4-C surface)

- `stdlib/flame/decoder_block_lib.hexa:217-509` — `nn_decoder_block_fwd` body (fused fn's fwd half source)
- `stdlib/flame/decoder_block_lib.hexa:509+` — `nn_decoder_block_bwd` body (fused fn's bwd half source)
- `stdlib/flame/decoder_lib.hexa:112-153` — `nn_decoder_fwd` per-layer fwd loop (4-C-3 restructure target)
- `stdlib/flame/decoder_lib.hexa:313-373` — `nn_decoder_grad` per-layer bwd loop (4-C-3 restructure target)
- `tool/flame_phase4b3_block_fwd_primitive.c` — fwd primitive C source (~270 LoC, reused in fused primitive)
- `tool/flame_phase4b3_block_bwd_primitive.c` — bwd primitive C source (~400 LoC, reused in fused primitive)
- `tool/flame_phase4b3_a2_build.sh` — Phase 4-B build pipeline (fork template for `flame_phase4c_build.sh`)
- `tool/flame_phase4b3_verify_all.sh` — 23-artifact verify battery (extends to 25 for Phase 4-C-1)

### Forge / GPU coordination (Phase 4-C-4 dep, parallel session)

- `self/forge/FORGE.tape` — substrate role (regime-tiered, RFC 044)
- `docs/rfc/rfc_drafts_2026_05_12/rfc_044_forge_regime_tiered_substrate.md` — forge Phase R design
- `docs/rfc/rfc_drafts_2026_05_12/rfc_049_forge_mixed_precision_substrate.md` — BF16 TC + LayerCast (Phase 4-D-adjacent)
- anima eager-PyTorch baseline: `~/core/anima/state/anima_pytorch_d768x12L_fire_2026_05_16/fire.log` (336.85s reference for F-RFC048-EAGER-PYTORCH-MATCH)

---

**Bottom line**: Phase 4-C work is **PARTIAL autonomous-able**. The first cycle
should land **Phase 4-C-1a paired-call detection (log-only)** — 1 new .hexa pass,
1 new build-shell fork, 1 new design doc, 1 added verify_all artifact, **zero
modifications to flame stdlib or Phase 4-B SHIPPED path**. This validates the
IR pattern matcher cheaply before authorizing the larger 4-C-2 fused-primitive
emit (also autonomous-able, 2 cycles) and prepares the ground for the user-gated
4-C-3 (decoder_lib restructure) + 4-C-4 (cost-bearing fire).
