# flame NEXT_CYCLE.md — implementation onboarding for next user-directed cycle

> Post 49-commit session state (commit `5602833f`). All Phase 3 work
> SHIPPABLE COMPLETE; Phase 4 design layer (RFC 046+047+048) shipped;
> Phase 4-A-bwd partial implementation landed. This file is the
> single-page onboarding for the next user-directed cycle's
> implementation work.

## What's done

- **flame Phase 3** = SHIPPABLE COMPLETE (44 falsifier PASS, regression 0)
- **flame Phase 4-A-bwd** = PARTIAL LANDED (7 outer-product accumulators wired; wall 13.33s 5-run avg, 60% of anima)
- **flame Phase 4 design** = full layer (RFC 046+047+048)
- **Cross-impl analysis** = complete (source #1 dt_ln bias + source #4 reduction-order both quantified; #2, #3 falsified)
- **Documentation** = README + PLAN + FLAME.tape + PERF.md + 6 RFCs all sync'd

## Three honest paths forward

### Path A — RFC 047 Phase 4-B-1 + 4-B-2 IPCP (LANDED 2026-05-17)

**Status**: detect-only scaffold + IPCP prototype both landed.

- `tool/flame_phase4b_scan.hexa` — Phase 4-B-1 scaffold (detect+classify)
- `tool/flame_phase4b_ipcp.hexa` — Phase 4-B-2 IPCP (text rewriter)

See `stdlib/flame/PHASE4B_SCAFFOLD.md` for full findings.

**Phase 4-B-2 IPCP result**: 715 substitutions across 5 target fns, output byte-identical to baseline, **1.28× wall speedup (12.574s → 9.814s, 5-run avg, var 1.7%)**.

**Falsifier matrix**:
- F-RFC047-SCAFFOLD-DETECT: PASS
- F-RFC047-SCAFFOLD-FALLBACK: PASS
- F-RFC047-IPCP-SOURCE-FOUND: PASS
- F-RFC047-IPCP-SUBST-COUNT: PASS (715)
- F-RFC047-IPCP-RESCAN-LITERAL: PASS (0 → 2 literal-tuple sites)
- F-RFC047-IPCP-BYTE-EQ: PASS (stdout byte-identical)
- F-RFC047-BLOCK-WALL-IMPROVED: **PARTIAL** (1.28×, below ≥2× minimum)
- F-RFC047-FALLBACK-PRESERVED: holds vacuously (production cmd_build untouched)

**Next sub-step (Phase 4-B-3 — kernel emission)**: emit specialized C kernel per (T,d,nh,nkv,h) tuple per RFC 047 §69 Emit pattern. IPCP-rewritten source becomes input. Target: collapse 12+ memory passes (current) → 2-3 register-resident passes via clang -O2 specialization on dimensional constants. Expected ≥3× wall improvement over baseline.

**OR** ship IPCP as-is for d=32·3L corpus benchmark (1.28× is real + zero risk) and pivot to Path B (GPU dispatch fire) — at d=768·12L the IPCP-only path may compose with GPU memory bandwidth gains for the eager-PyTorch baseline crossing.

### Path B — Phase 4-D GPU dispatch fire (cost-bearing, immediate)

**Entry**: `inbox/rfc_drafts_2026_05_12/rfc_046_flame_phase4_compiler_fusion.md` §"Phase 4-D"

**Goal**: build flame_d32_corpus_test (or d=768·12L scaled config) for Linux/CUDA host, dispatch to vast.ai or runpod A100, measure wall vs eager-PyTorch baseline (336.85s).

**First action**: dispatch script (cross-link with `anima g_fire_autonomous + g_fire_dispatch_robust` patterns)

**First falsifier**: F-RFC046-EAGER-PYTORCH-MATCH — flame d=768·12L wall ≤ 1.3× of eager-PyTorch 336.85s on A100.

**Cost**: ~$5-20 (vast.ai A100 ~$1/hr × 4-8 hours, including build + smoke + dispatch retries per `g_fire_dispatch_robust`).

**Risk**: mid (cost-bearing; depends on GPU dispatch infrastructure stability).

### Path C — attention_core_bwd evidence attempt (TESTED + REVERTED 2026-05-17)

**Entry**: this README's findings — granularity floor ~32K ops at this scale.

**Attempt**: routed attention_core_bwd's dV accumulator (per-hh P^T·dctx_slice form) through farr_matmul.

**Result**: REVERTED. Phase 3-B/3-C/3-F-3 absorbed the algorithm change (still PASS); Phase 3-F-3 corpus numerics byte-eq preserved (init 7.97113, final 8.87e-7, acc 8/8). BUT Phase 2 F-RFC043-LAYER-EQ-ATTN-BWD strict byte-eq VIOLATED (cross-impl reduction-order drift: wrapper produces 1.66e-16 ulp deviation from inline ref). Wall single-shot 11.46s vs 5-run baseline 13.33s — possible 14% improvement but single-shot is below noise floor.

**Lesson**: helper-wire-in approach (Path C class) preserves higher-level GRAD-EXACT verification but cannot preserve Phase 2 strict cross-impl byte-eq when reduction order changes. Phase 4-B IR-level fusion (RFC 047) must operate on the SHARED-ref path or use FMA-compatible reduction order to preserve Phase 2-tier guarantees.

**Effort**: 2 commits (attempt + revert with evidence).

**Risk**: low (mechanical, contained — revertible).

## Code state pointers

- decoder_block_lib.hexa::`_db_grad_accum_farr` — single-pattern helper for OUTER-PRODUCT bwd accumulators (reach 7/7 wired)
- decoder_block_lib.hexa::`_db_proj_batch_farr` — fwd projection helper (Phase 3-J 7/7 wired)
- decoder_lib.hexa::`nn_decoder_grad` — verified correct at full d=32·3L (libm-fd 8-probe max rel 2.19e-09)
- decoder_lib.hexa::`nn_decoder_ce_loss_libm` — isolation helper (Phase 3-I; production uses dt_ln-based `nn_decoder_ce_loss`)

## Measurement convention (PERF.md)

- ≥5-run averaging for sub-second-per-iter walls
- `flame_perf_breakdown_test` — 5×8-iter per-step breakdown harness
- `flame_d32_corpus_test` — full 80-step corpus benchmark; current 5-run avg 13.33s

## Regression battery (run before each commit)

```bash
for s in flame.hexa flame_nn_test.hexa flame_optim_test.hexa flame_block_test.hexa \
         flame_decoder_test.hexa flame_train_test.hexa flame_math_test.hexa \
         flame_init_byteeq_test.hexa flame_d32_test.hexa flame_d32_corpus_test.hexa; do
    name=$(basename "$s" .hexa)
    HEXA_MAC_BUILD_OK=1 ./hexa build "stdlib/flame/$s" -o "build/$name" 2>&1 | tail -1
    "./build/$name" 2>&1 | grep -E '=== flame Phase|=== RFC' | tail -1
done
```

## Cross-references

- README.md — high-level status + Build & run examples
- PLAN.md — staged roadmap + RFC index + next-step candidates table
- FLAME.tape — SSOT + §X campaign preservation
- PERF.md — measurement ledger + Phase 3-I source analysis findings
- RFC 045 — Phase 3 closure + cross-impl source analysis
- RFC 046 — Phase 4 fusion design framework
- RFC 047 — Phase 4-B IR pass design
- RFC 048 — Phase 4-C fwd+bwd graph fusion design
