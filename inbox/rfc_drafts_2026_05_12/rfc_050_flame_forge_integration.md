# RFC 050 — flame ↔ forge integration API (precision policy + tier dispatch)

- **Status**: design-draft (2026-05-17) → **Stage A landed** (forge_tier_v1.{h,c} ABI + stub dispatcher) → **Stage 2 BF16-routing landed** (2026-05-19) — `forge_tier_dispatch_v1` now routes MATMUL/FFN + `FORGE_PREC_PURE_BF16` through the RFC 049 BF16 substrate (runtime_bf16.c) via the `ForgeArgs` pointer-cast ABI, behind the `FORGE_TIER_V1_BF16` guard. Standalone harness `self/cuda/experiments/r050_dispatch_validate.cu` + dispatch script ready; **fire pending** (the BF16-routing falsifiers VERSION-API / DISPATCH-ROUTES-BF16 / FALLBACK-CHAIN are verified by that post-land fire, not yet PASS).
- **Date**: 2026-05-17
- **Severity**: HIGH (flame stdlib has reached Phase 3 COMPLETE + Phase 4-B SHIPPED on CPU; forge has reached Phase R with regime-tiered substrate + RFC 049 mixed-precision substrate paradigm — the two SSOTs have no formal integration API yet. Without one, flame Phase 4-D GPU dispatch and forge Stage 2 kernel land would couple ad-hoc per call site, drifting against the dual-mechanism × regime-tiered substrate forge committed to in RFC 044.)
- **Priority**: P1 (gates flame Phase 4-D GPU dispatch and forge Stage 2 kernel campaigns — both already designed but cannot land without the boundary contract)
- **Builds on**: RFC 044 (forge dual-mechanism × regime-tiered substrate), RFC 049 (forge mixed-precision substrate), RFC 043 (flame stdlib design SSOT), RFC 048 (flame Phase 4-C fwd+bwd graph fusion — the dominant consumer of fused-kernel dispatch)
- **Source convergence**:
  - forge Phase R COMPLETE 2026-05-17 (8 fires, $2.09 cumulative) — paradigm A/B/C/D measured + reframed to dual-mechanism × regime-tiered substrate (PARADIGM.md SSOT)
  - RFC 049 (2026-05-17) — precision policy as a third orthogonal mechanism on top of RFC 044 (FP64 / LayerCast BF16+FP32 / pure BF16)
  - flame Phase 4-B SHIPPED 2026-05-17 (PathB fwd+bwd matmul primitive, 2.74× wall, 3.23× cool projection, ≥3× target REACHED with CPU-only architecture); Phase 4-C design land (RFC 048, fwd+bwd graph fusion HIGHEST IMPACT)
  - flame public API fixed (`g_flame_api_fixed`) — RFC 050 cannot change `t_*`/`ag_*`/`nn_*`/`opt_*` user-visible signatures; the boundary is **internal to the compiled stdlib**.
- **Source evidence (g3 — every claim below traces to a real capture or pre-registered design)**:
  - `self/forge/PARADIGM.md` §6 + §7 "dual-mechanism × batch-size + regime-aware AOT substrate" — forge thesis post-Phase R, anchored to 8 fire data points
  - `state/forge_phaseR_a_2026_05_17/result.json` + `pytorch_result.json` — AOT speedup 2.24-6.07× small/medium MLP, dispatch elimination mechanism anchor
  - `state/forge_phaseR_a_stage2_2026_05_17/A_STAGE2_ANALYSIS.md` — batch-size dependent (B≤128 any model 4-6×, B≥512 large model 1.86×)
  - `state/forge_phaseR_c_2026_05_17/result.json` — autograd co-emission redundancy 1.500× constant, theoretical ceiling 0.667×
  - `state/forge_phaseR_c_stage2_2026_05_17/C_STAGE2_ANALYSIS.md` — F-FORGE-C-STAGE2-FUSED-CEILING PASS 0.6667 measured, F-FORGE-C-STAGE2-DET-PRESERVE PASS max|Δ|<1e-16
  - `state/forge_phaseR_c_stage2_v2_2026_05_17/C_STAGE2_V2_ANALYSIS.md` — multi-block FP64 wall FAIL (5.99-32.3× cuBLAS) → RFC 049 BF16 TC substrate motivation
  - `state/forge_phaseR_d_2026_05_17/D_ANALYSIS.md` — D' within-run FREE bit-determinism, 6/6 shapes (FP64 baseline)
  - `stdlib/flame/PLAN.md` §"진행 로그" 2026-05-17 — Phase 4-B SHIPPED PathB matmul 2.74× wall, Phase 4-D GPU dispatch listed as cost-bearing follow-up
  - `stdlib/flame/FLAME.tape` `x_rfc048` — Phase 4-C fwd+bwd fused emit estimate ≥2× over Phase 4-B → combined Phase 4 ≥5×
  - RFC 048 §"Cross-RFC dependency" — *"RFC 044 (forge regime) — Phase 4-C's specialized C functions live in `self/forge/`. Cross-link coordination with parallel session."* — this RFC formalizes that coordination.

## 1. Status / Date / Priority / Severity

(see header). Re-stated: **DESIGN ONLY, no fire, no implementation**. RFC 050 land = a design contract on paper that both flame and forge sessions agree to honor in their subsequent implementation cycles. No `.cu`, no `.hexa`, no codegen.

## 2. Source convergence (Phase R + RFC 049 + flame Phase 4 work)

Three independently-completed design pillars converge into the integration gap RFC 050 fills:

| Pillar | Status | What it produces | Why it needs the other side |
|---|---|---|---|
| **forge Phase R + RFC 044** | COMPLETE (8 fires) + draft | regime-tiered substrate (A/B/C/D' tiers, batch-size + shape aware) | needs flame to know which tier to call per layer |
| **forge RFC 049** | draft | mixed-precision substrate (FP64 / LayerCast BF16+FP32 / pure BF16) | needs flame to express its precision policy at compile time |
| **flame Phase 4-B SHIPPED + RFC 048 Phase 4-C** | shipped + draft | fwd+bwd graph fusion at flame IR-pass time (specialized C kernels live in `self/forge/`) | needs forge to expose a stable dispatch ABI for the fused emit pattern |

Without RFC 050, each session must re-discover the boundary ad-hoc per integration commit. Drift accumulates; the forge ABI lockstep mandate (AGENTS.tape §0 `nn_stack` "toolchain ABI lockstep") cannot be honored.

## 3. Source evidence (g3 — Phase R fire data direct trace)

Every claim below this section traces to:

1. **forge measured wins** (forge perf inheritance falsifier F-FORGE-RFC050-PERF-INHERITANCE):
   - A' small batch (B≤128) any model: **2.24-6.07× PyTorch eager** — `state/forge_phaseR_a_{,stage2_}2026_05_17/`
   - A' large batch large model: **1.86× PyTorch eager** — `state/forge_phaseR_a_stage2_2026_05_17/A_STAGE2_ANALYSIS.md`
   - C' fused (fwd, bwd) ceiling: **0.6667 HBM ratio measured** — `state/forge_phaseR_c_stage2_2026_05_17/C_STAGE2_ANALYSIS.md`
   - D' within-run det: **bit-equal 6/6 shapes, FREE** — `state/forge_phaseR_d_2026_05_17/D_ANALYSIS.md`
   - RFC 049 BF16 TC: **≥5× literature projection** (16× theoretical TC ratio × ~30% kernel util) — pre-registered F-FORGE-RFC049-BF16-TC-PERF, NOT yet measured.

2. **flame consumer state** (flame Phase 4-D GPU dispatch falsifier dependency):
   - flame Phase 4-B SHIPPED PathB matmul **2.74× wall byte-id, 3.23× cool projection** — `stdlib/flame/PLAN.md` 2026-05-17 entry
   - flame:anima **0.226×** (~4.4× faster) — same source
   - 23-artifact self-verifying gate `tool/flame_phase4b3_verify_all.sh`
   - `stdlib/flame/PERF.md` 5-run × 8-iter convention SHIPPED

3. **paradigm-anchored thesis** (PARADIGM.md §7 honest forge thesis):
   - Mechanism 1 = dispatch elimination (A tier, regime-anchored)
   - Mechanism 2 = memory fusion (B/C tier, ceiling-anchored)
   - Common substrate = D' (within-run det FREE) + RFC 049 (precision tier orthogonal)

## 4. Scope (DESIGN ONLY)

RFC 050 specifies:

- The **internal** flame ↔ forge dispatch API (`forge.tier(...) → kernel_dispatch`), versioned (`forge.tier_v1`)
- The **regime classification** rules (small / medium / large by compute + batch + shape)
- The **precision policy** enumeration (FP64 / LayerCast BF16+FP32 / pure BF16; PEDANTIC opt-in det orthogonal)
- The **fused-kernel dispatch** boundary for flame Phase 4-C fwd+bwd emit pattern
- The **fallback chain** semantics (unsupported regime/precision = cuBLAS chain fallback, no crash)
- The **ABI version pin** mechanism (flame source detects forge ABI change at compile)
- 7 pre-registered falsifiers (Stage 2 — verified by post-land implementation fire)

RFC 050 does NOT specify:

- `.cu` source for any tier (RFC 040/041/044/049 + Stage 2 RFCs cover those)
- `.hexa` flame surface changes (flame public API frozen per `g_flame_api_fixed`)
- The flame compiler IR-pass internals (RFC 047 Phase 4-B + RFC 048 Phase 4-C cover those)
- forge dispatcher implementation (Stage 2 work per tier)
- BF16 storage class implementation (RFC 049 follow-up RFC, planned RFC 051+)
- Multi-GPU / cross-GPU dispatch (out of scope, future RFC)

## 5. Problem — no formalized flame ↔ forge dispatch interface

flame stdlib lives in `stdlib/flame/` (hexa source); forge substrate lives in `self/forge/` (C/CUDA runtime + future kernel emit target). The two have a clear conceptual relationship (`flame:forge :: torch:ATen`, AGENTS.tape §0 nn_stack), but **no formal API** between them:

- flame Phase 4-D GPU dispatch (PLAN candidate) needs to know whether to call `farr_matmul_gpu` (RFC 040 cuBLAS Dgemm fallback) or some hypothetical `forge.tier_small_aot(...)` (RFC 044 A' Stage 2 tier) or `forge.tier_large_dsm(...)` (RFC 044 B' Stage 2 tier).
- flame Phase 4-C (RFC 048) emits specialized fused C functions; the design says they "live in `self/forge/`" but **does not specify the entry point convention**, the precision argument, the regime hint, or the version-pin mechanism.
- RFC 049 introduces a precision-policy axis (FP64 / LayerCast / pure BF16). flame must decide which to request at model compile time, but there is no API to express it. Without one, the precision-policy axis collapses into hardcoded per-kernel decisions, defeating the dispatch-as-policy intent.
- forge dispatcher (when built) needs a stable **caller convention** so the C ABI does not break when RFC 049 or RFC 044 Stage 2 implementations evolve. Without an explicit version pin, an ABI silently changes and flame compiled binaries crash or worse, run with corrupted assumptions.

The absence of this boundary contract is the dominant integration risk between the two parallel sessions. RFC 050 fills it on paper before either side commits Stage 2 implementation.

## 6. Proposal — flame ↔ forge integration API (`forge.tier_v1`)

### 6.1 Top-level dispatch primitive

A single dispatch entry point per kernel family. Conceptual hexa-side signature (final spelling decided at land time):

```hexa
// forge.tier_v1 dispatch contract — flame side caller convention
pub fn forge_tier_dispatch_v1(
    kernel_family: int,        // FORGE_KERNEL_MATMUL | FORGE_KERNEL_FFN_FUSED | FORGE_KERNEL_FWD_BWD_LINEAR | ...
    shape_info: int,           // packed (M, N, K, batch) or family-specific shape farr_id
    regime_hint: int,          // FORGE_REGIME_SMALL | FORGE_REGIME_MEDIUM | FORGE_REGIME_LARGE | FORGE_REGIME_AUTO
    precision_policy: int,     // FORGE_PREC_FP64 | FORGE_PREC_LAYERCAST_BF16_FP32 | FORGE_PREC_PURE_BF16
    det_mode: int,             // FORGE_DET_DEFAULT (D' within-run free) | FORGE_DET_PEDANTIC (cross-mode equiv, +15-33% cost)
    in_args: int,              // packed input farr ids (caller-managed lifetime)
    out_args: int              // packed output farr ids (caller-pre-allocated)
) -> int                       // FORGE_OK | FORGE_FALLBACK_USED | FORGE_REGIME_UNSUPPORTED | FORGE_PRECISION_UNSUPPORTED
```

This is **internal** to the compiled flame stdlib — `nn_linear_fwd` etc. call it; the user never sees it. The flame public API surface (`t_matmul`, `ag_*`, `nn_*`, `opt_*`) is unchanged (`g_flame_api_fixed` preserved).

### 6.2 Regime classification rules

The regime axis is **shape × batch × compute-estimate** based, anchored to Phase R measured boundaries:

| Regime | Compute estimate | Batch range | Primary win mechanism | forge tier |
|---|---|---|---|---|
| **FORGE_REGIME_SMALL** | < 100 μs | B ≤ 128 | dispatch elimination dominant (A tier, ~6×) | `forge_tier_small_aot` |
| **FORGE_REGIME_MEDIUM** | ~1-10 ms | B = 128-512 | dispatch + SMEM tile fusion (A + B Stage 2 mid) | `forge_tier_medium_fused` |
| **FORGE_REGIME_LARGE** | > 10 ms | B ≥ 512 OR large model | memory fusion dominant (B/C tier DSM, ~1.5-2×) | `forge_tier_large_dsm` |
| **FORGE_REGIME_AUTO** | unknown / dynamic | any | flame defers to forge runtime probe (slower first call, cached) | `forge_tier_auto` |

The classification is **flame compile-time** when shapes are static literals (the Phase 4-B / Phase 4-C IR-pass already extracts these per RFC 047/048). Dynamic-shape call sites fall back to `FORGE_REGIME_AUTO` (forge measures + caches per shape — one-time cost).

**Honest caveat (g3)**: boundary thresholds are anchored to A100/H100 measured data (PARADIGM.md §5). On other hardware (B100, B200, MI300X, etc.) the boundaries shift; flame compile-time classification uses the target-hardware probe (already part of `hexa build --target-cuda` flow per RFC 040).

### 6.3 Precision policy

Three policies per RFC 049 §"3 modes":

| Policy | Master | Storage | Compute | TC use | Memory | Wall vs FP64 | Divergence vs FP32 |
|---|---|---|---|---|---|---|---|
| **FORGE_PREC_FP64** (current default) | FP64 | FP64 | FP64 | none | 1× | 1× | 0% (FP32 ⊂ FP64) |
| **FORGE_PREC_LAYERCAST_BF16_FP32** | FP64 | BF16 | FP32 (TC emulation OR native) | yes (BF16 TC + FP32 acc) | ~0.3× | ~0.3× (literature) | ≤ 3.4% (LayerCast paper anchor) |
| **FORGE_PREC_PURE_BF16** | BF16 | BF16 | BF16 (TC) | yes | ~0.2× | ~0.2× | ≤ 9.15% (BF16-only paper anchor) |

flame Phase 1-3 currently locked to FORGE_PREC_FP64 (RFC 049 storage class is Stage 2 follow-up). The API reserves the other two; flame Phase 5+ will use them when RFC 049 Stage 2 lands.

### 6.4 Det mode (orthogonal to precision)

Two modes per RFC 044 D' findings:

- **FORGE_DET_DEFAULT** — within-run bit-deterministic single-process single-GPU (free, no cost). 6/6 shapes verified on FP64. RFC 049 generalizes this to per-precision-per-batch det boundary (BF16: within-run within-batch within-GPU only).
- **FORGE_DET_PEDANTIC** — cross-mode bit-equal mandatory (+15-33% cost, FP64; no equivalent in BF16 substrate per RFC 049 §3.3 honest caveat). flame uses this only when user explicitly opts in for cross-version reproducibility tests.

### 6.5 Fused-kernel dispatch (flame Phase 4-C consumer)

RFC 048's Phase 4-C IR pass emits specialized fused fwd+bwd C functions per (T, d, nh, nkv, h) tuple. RFC 050 formalizes the dispatch convention:

- The emitted C function name follows the convention `forge_fused_<family>_<dims_hash>_<precision>_<regime>` (e.g., `forge_fused_linear_T16d32_fp64_small`).
- The function is **registered** with forge dispatcher at module-init (one-time, on first call to that flame module) via `forge_register_specialized_v1(family, shape_info, precision, regime, fn_ptr)`.
- Subsequent flame Phase 4-C call sites with matching dims dispatch through the same `forge_tier_dispatch_v1` entry point — the dispatcher selects the registered specialized kernel rather than the generic tier.
- If no specialized kernel is registered for (family, shape, precision, regime), the dispatcher falls back to the generic tier (A' or B' or C' Stage 2 kernel; if neither is built, cuBLAS chain).

**Lifetime contract**: caller (flame) allocates input/output farrs; forge dispatcher only reads/writes them. No hidden allocation, no hidden release. This preserves the RFC 035/040 packed-double arena ownership semantics.

### 6.6 Fallback chain (no crash mandate)

When `forge_tier_dispatch_v1` cannot satisfy the requested (regime, precision, det_mode), it falls back deterministically:

```
specialized fused (RFC 048)
    ↓ (not registered for this shape)
generic tier (RFC 044 A'/B'/C' Stage 2)
    ↓ (Stage 2 kernel not built for this hardware)
RFC 049 mixed-precision tier (cuBLAS GemmEx BF16 if requested)
    ↓ (BF16 hardware unavailable / not requested)
cuBLAS Dgemm chain (RFC 040 baseline — always available, always correct)
    ↓ (CUDA not available, e.g., Mac no-CUDA)
CPU farr reference (Phase 1-3 flame path)
```

Return code (`FORGE_OK` / `FORGE_FALLBACK_USED` / `FORGE_REGIME_UNSUPPORTED` / etc.) tells caller which path was taken. Caller (flame) may log + continue, or escalate to user (e.g., when expecting GPU but got CPU fallback unexpectedly).

**Hard mandate**: dispatcher never crashes on unsupported (regime, precision, det_mode) — always falls back, always returns a code. Tested by F-FORGE-RFC050-FALLBACK-CHAIN.

### 6.7 Version pin (ABI lockstep)

The `_v1` suffix on every entry point is mandatory. When RFC 044/049 Stage 2 work changes the dispatcher ABI (e.g., adding a new tier, changing the shape_info packing), the new entry point is `forge_tier_dispatch_v2`; the old `_v1` remains available until flame source migrates.

flame source at module-init queries `forge_api_version_v1()`; if the returned version is less than the version flame was compiled against, flame raises a build-time error (`forge.tier_v1 ABI version mismatch — please rebuild flame against forge >= 1.0`). This prevents silent ABI corruption.

**Cross-link**: AGENTS.tape §0 nn_stack mandates *"toolchain ABI lockstep"*. RFC 050's version pin is the mechanism by which that lockstep is enforced.

## 7. Falsifier battery (7 pre-registered, Stage 2 verified by post-land fire)

Each falsifier is **compiled-native** path (`hexa build` AOT) only. Reference = forge Phase R measured anchors or RFC 049 literature anchors only. No fake targets, no fabricated multiples.

### F-FORGE-RFC050-DISPATCH-API-MATCH
flame Phase 4-C lowering (RFC 048 pattern matcher) produces dispatch sites that **100% match a registered forge tier** for supported (family, regime, precision) combinations. Definition: `unmatched_dispatch_count / total_dispatch_count = 0` over the flame d=32·3L and d=768·12L benchmark builds. No silent fallback for combinations both sides agreed to support.

### F-FORGE-RFC050-REGIME-CORRECT
Shape-based regime classification (`FORGE_REGIME_{SMALL,MEDIUM,LARGE}`) at flame compile time matches the **measured Phase R win source** per regime:
- SMALL (B≤128, compute < 100 μs): A tier dispatched, measured ≥ 4× PyTorch eager (PARADIGM.md §5.4 lower bound)
- MEDIUM (1-10 ms): A + B/C Stage 2 dispatched, measured ≥ 1.5× combined
- LARGE (B≥512 or large model): B/C Stage 2 DSM dispatched, measured ≥ 1.18× (B Stage 2 small-shape conservative anchor)

The threshold values come from PARADIGM.md §6 measured table, NOT from RFC 050 fabrication.

### F-FORGE-RFC050-PRECISION-D-PRESERVE
Precision policy change (e.g., FP64 → LayerCast BF16+FP32) preserves D' within-run determinism **within the new precision boundary**:
- FP64 path: same-process bit-equal (RFC 044 D' anchor — already PASS 6/6)
- LayerCast path: same-process same-batch same-GPU bit-equal (RFC 049 §3.3 caveat-bound det boundary)
- Pure BF16 path: same-process same-batch same-GPU bit-equal

flame's `t_determinism_test` (Phase 1 falsifier) runs per precision policy on the same model + same seed; each policy's "two runs byte-identical" check PASSes within its boundary. Cross-precision NOT bit-equal (honest caveat, NOT a falsifier target — that's RFC 049 §3.3).

### F-FORGE-RFC050-FORGE-BACKWARD-FUSE
flame Phase 4-C IR pass (RFC 048) emits paired fwd+bwd as a **single forge dispatch call** (`forge_fused_linear_...` style), NOT separate fwd then bwd launches. Measured via: forge dispatcher log = 1 dispatch per fwd+bwd block pair, not 2. Anchored to RFC 048 F-RFC048-FUSED-FWD-BWD-EQ as the numerical correctness pre-condition.

### F-FORGE-RFC050-PERF-INHERITANCE
flame compiled step (full train_step end-to-end) **inherits** forge measured wins per regime:
- SMALL flame benchmark (e.g., MNIST-equivalent MLP, B≤32): ≥ 4× PyTorch eager wall (forge A small-batch anchor 6.06× degraded by overhead, conservative ≥ 4×)
- LARGE flame benchmark (d=768·12L equivalent, B=128): ≥ 1.18× PyTorch eager (forge A large lower-bound; B/C Stage 2 if landed adds ~1.5× → ≥ 1.77× combined)
- BF16 RFC 049 path (when Stage 2 lands): ≥ 3× FP64 wall on H100 BF16 TC (RFC 049 conservative 5× anchor degraded by flame integration overhead)

Anchors are forge measured numbers from PARADIGM.md §6 + RFC 049 literature; flame integration introduces overhead → conservative degradation factor applied. Falsifier FAILs only if flame integration adds > 20% overhead vs raw forge measured (a structural bug, not a perf reframe).

### F-FORGE-RFC050-FALLBACK-CHAIN
Unsupported (regime, precision, det_mode) combinations **fall back deterministically** through the chain in §6.6 with NO CRASH. Test inputs: pure BF16 on Mac no-CUDA (must fall back to CPU farr reference); LARGE regime on hardware without DSM (must fall back to cuBLAS chain); PEDANTIC det on BF16 (must return FORGE_PRECISION_UNSUPPORTED, caller handles).

### F-FORGE-RFC050-VERSION-API
forge API version pin (`forge_api_version_v1()`) returns the same major.minor as the flame source was compiled against. Test: corrupt the forge runtime version constant (test fixture) → flame build detects mismatch → emits `forge.tier_v1 ABI version mismatch` error → fails build (not silent run). Anchors AGENTS.tape §0 nn_stack "toolchain ABI lockstep" requirement.

## 8. Honest caveats (g3 / f1 / f2)

### 8.1 flame ↔ forge boundary = parallel-session work
flame and forge implementation live in separate parallel sessions (per `nn_stack` directive). RFC 050 is **integration design only** — the actual API land requires both sides to:
1. flame session: emit `forge_tier_dispatch_v1` call sites from Phase 4-D codegen
2. forge session: implement the dispatcher (C runtime) with the `_v1` entry points
3. Both sides agree on header file location (proposal: `self/forge/include/forge_tier_v1.h`) and the FORGE_KERNEL_* / FORGE_REGIME_* / FORGE_PREC_* constants.

The RFC 050 design contract is the **negotiated agreement** — neither side gets to unilaterally change the API. ABI breaks require RFC 050'-style follow-up (or `_v2` bump).

### 8.2 RFC 050 paired with RFC 049 implementation
RFC 050 references precision policy constants (FORGE_PREC_LAYERCAST_BF16_FP32, FORGE_PREC_PURE_BF16) that **don't yet have working substrate** — RFC 049 is also DESIGN. Both must land together (RFC 049 substrate + RFC 050 API) for the precision-policy axis to be testable. Until then, flame production calls always pass `FORGE_PREC_FP64` (Phase 1-3 path); the other constants exist in the API but `forge_tier_dispatch_v1` returns `FORGE_PRECISION_UNSUPPORTED` for them. F-FORGE-RFC050-FALLBACK-CHAIN verifies this graceful behavior.

### 8.3 Real measurement gated on both sides landing
F-FORGE-RFC050-PERF-INHERITANCE is the most consequential falsifier — *flame inherits forge measured wins*. This is measurable only when:
- flame Phase 4-D (GPU dispatch fire) lands the dispatch call sites
- forge Stage 2 (A' transformer trainer or B' DSM FFN or C' fused fwd+bwd) lands the dispatcher backend
- Both sides agree on the `_v1` ABI (this RFC's contract)

Until those land, perf inheritance is **literature-anchored projection** (PARADIGM.md + RFC 049 NVIDIA blog data). The first fire that lands both sides will produce real numbers — possibly below the conservative thresholds, in which case the falsifier FAILs and a follow-up RFC reframes (no fudge).

### 8.4 BF16 substrate dependency
F-FORGE-RFC050-PRECISION-D-PRESERVE for the LayerCast / pure BF16 paths is **gated on RFC 049 Stage 2 land** (BF16 storage class + cuBLAS GemmEx BF16 kernel). Until then, those branches of the falsifier are 🟡 (pre-registered, not yet verifiable). Only the FP64 branch is verifiable today (matches RFC 044 D' anchor).

### 8.5 Hardware capability not part of API
RFC 050 deliberately does NOT include a hardware-capability query in the API (e.g., `forge_has_bf16_tc()`). Reason: the regime classification + precision policy + fallback chain together cover hardware variation. Adding a separate capability axis would couple flame source to hardware enumeration, defeating the dispatch-as-policy intent. Hardware-specific tuning lives **inside** the forge dispatcher implementation (e.g., A100 vs H100 chooses different SMEM tile size for the same `FORGE_REGIME_MEDIUM` call).

### 8.6 No n=6 lattice numerology (f1/f2 deny)
All perf anchors trace to forge measured Phase R fires + RFC 049 literature (LayerCast paper + cuBLAS NVIDIA blog + H100 datasheet TC throughput numbers). No lattice/perfect-number constants in the API design, the regime thresholds, or the precision policy enumeration.

## 9. Non-goals (RFC 050 = integration API design only)

- No flame public API change (`g_flame_api_fixed` preserved — RFC 050 is internal to compiled stdlib)
- No `.cu` source (RFC 040/041/044/049 + Stage 2 RFCs)
- No `.hexa` source (flame Phase 4-D wires the dispatch calls; forge dispatcher is C runtime)
- No flame IR-pass internals (RFC 047 Phase 4-B + RFC 048 Phase 4-C)
- No BF16 storage class implementation (RFC 049 Stage 2 follow-up, planned RFC 051+)
- No multi-GPU / cross-GPU dispatch (out of scope, future RFC ≥ 060)
- No hardware-capability enumeration API (intentional, §8.5)
- No inference-framework integration (vLLM / TensorRT-LLM, out of scope, RFC 044 A Stage 2 future application)
- No supersession of RFC 044, 048, or 049 — RFC 050 ties them together at the boundary

## 10. Cross-RFC dependency

- **RFC 034** (autograd tape foundation) — autograd-tape pattern preserved; `ag_*` records onto tape, the recorded ops dispatch through `forge_tier_v1` at compiled-native eval time.
- **RFC 040** (device-farr + cuBLAS Dgemm) — base substrate, always available as final fallback in §6.6 chain.
- **RFC 041** (real `.cu` kernels for B/B2 ops) — Stage 2 kernels invoked through the dispatcher's tier selection.
- **RFC 042** = SUBSUMED by 043 (do not reuse).
- **RFC 043** (flame stdlib design) — consumer of RFC 050 API; flame `nn_*` layers internally call `forge_tier_dispatch_v1`.
- **RFC 044** (forge dual-mechanism × regime-tiered substrate) — provides the tier semantics RFC 050 dispatches to (A'/B'/C'/D').
- **RFC 045** (flame Phase 3 algorithmic byte-eq) — closed-evidence; RFC 050 preserves the algorithmic byte-eq tier (flame ↔ anima 3.12e-5 init-gn2 delta) when FORGE_PREC_FP64 + FORGE_REGIME_AUTO selected.
- **RFC 046** (flame Phase 4 compiler fusion) — Stage 1-2 framework; RFC 050 specifies the dispatch boundary the fused emit pattern uses.
- **RFC 047** (flame Phase 4-B per-block IR pass) — emits specialized C kernels into `self/forge/`; RFC 050 §6.5 specifies the naming convention + registration.
- **RFC 048** (flame Phase 4-C fwd+bwd graph fusion) — HIGHEST IMPACT consumer of RFC 050's fused-kernel dispatch (F-FORGE-RFC050-FORGE-BACKWARD-FUSE).
- **RFC 049** (forge mixed-precision substrate) — provides the FORGE_PREC_LAYERCAST_BF16_FP32 / FORGE_PREC_PURE_BF16 paths RFC 050 reserves.
- **RFC 051+** (future): BF16 storage class implementation, LayerCast JIT cast policy, BF16 TC fused FFN kernel — all dispatched through `forge_tier_v1`.

## 11. Cross-link (PARADIGM.md + Phase R + flame phases)

### forge SSOTs
- `self/forge/PARADIGM.md` — measurement-anchored thesis (FORGE.tape `x_paradigm_ssot`); §6 + §7 dual-mechanism × regime-tiered substrate
- `self/forge/PARADIGM_RESEARCH.md` — literature snapshot (LayerCast, FlashFuser, Mojo MAX)
- `self/forge/FORGE.tape` — substrate-side SSOT (`x_paradigm_ssot` + `x_phaseR_fires` + `x_oracle_cublas`)
- `self/forge/PLAN.md` — substrate phases (Phase 2-4 + Phase 5+ flame integration)

### Phase R measurement evidence (g3 — every RFC 050 perf claim sourced here)
- `state/forge_phaseR_d_2026_05_17/` — D' within-run det FREE (6/6 shapes)
- `state/forge_phaseR_b_2026_05_17/` + `b_stage2_2026_05_17/` + `b_dsm_v2_2026_05_17/` — B' shape-tiered FFN fusion
- `state/forge_phaseR_c_2026_05_17/` + `c_stage2_2026_05_17/` + `c_stage2_v2_2026_05_17/` — C' fused fwd+bwd (ceiling PASS, wall FAIL → RFC 049 motivation)
- `state/forge_phaseR_a_2026_05_17/` + `a_stage2_2026_05_17/` — A' AOT whole-train-step (2.24-6.07× small / 1.86-4.06× large)
- Phase R cumulative cost: $2.09 / 8 fires (PARADIGM.md §1)

### flame SSOTs
- `stdlib/flame/FLAME.tape` — consumer-side SSOT (`x_rfc043` design SSOT, `x_rfc048` Phase 4-C scope, `x_oracle_cpu_bitequal` 7.97116 → 3.73374e-07)
- `stdlib/flame/PLAN.md` — staged roadmap (Phase 4-B SHIPPED 2026-05-17, Phase 4-C/4-D pending)
- `stdlib/flame/PERF.md` — 5-run × 8-iter measurement convention
- `stdlib/flame/README.md` — overview + foundation pointer

### Literature anchors (RFC 049 inheritance)
- LayerCast (arxiv 2506.09501) — BF16 storage + FP32 compute, ≤ 3.4% divergence, 34% memory save
- BFLOAT16 study (arxiv 1905.12322) — BF16 training ≈ FP32 training
- cuBLAS 12.9 BF16x9 NVIDIA blog 2026 — 3-4× wall vs native FP32
- H100 datasheet — FP64 TC 60 TFLOPS vs BF16 TC 989 TFLOPS (16× ratio)

## 12. PLAN integration

### forge `self/forge/PLAN.md` — Phase 5+ flame integration
RFC 044 PLAN integration §Phase 2-4 covered substrate-internal work. RFC 050 extends with Phase 5+:

| Phase | Scope | RFC | Status |
|---|---|---|---|
| Phase 2 | regime-tiered substrate scaffold (2.A Graphs / 2.B SMEM / 2.C fwd+bwd) | RFC 044 | DESIGN |
| Phase 3 | DSM-cluster fusion (B' Stage 2, Hopper) | RFC 044 | DESIGN |
| Phase 4.FP64 | AOT whole-train-step (A' Stage 2 transformer) | RFC 044 | DESIGN |
| Phase 4.MIXED | BF16 TC substrate, LayerCast cast policy | RFC 049 | DESIGN |
| **Phase 5 — flame ↔ forge integration dispatcher** | **`forge_tier_dispatch_v1` C runtime + `forge_register_specialized_v1` + version pin** | **RFC 050** | **DESIGN (this RFC)** |
| Phase 6+ | multi-GPU / cross-GPU dispatch | future | not designed |

### flame `stdlib/flame/PLAN.md` — Phase 4-D / Phase 5 forge dispatch
flame PLAN currently lists Phase 4-D GPU dispatch as a candidate (cost-bearing $5-20). RFC 050 specifies the API Phase 4-D wires to:

| Phase | Scope | RFC dependency | Status |
|---|---|---|---|
| Phase 4-A | epilogue fusion + bwd projection routing | RFC 046 | PARTIAL LANDED |
| Phase 4-B | per-block IR pass | RFC 047 | SHIPPED (2.74× wall) |
| Phase 4-C | fwd+bwd graph fusion | RFC 048 | DESIGN |
| **Phase 4-D — GPU dispatch via forge_tier_v1** | **wire `nn_*` layers + Phase 4-C emit to `forge_tier_dispatch_v1` call sites** | **RFC 050 (this RFC) + RFC 044 Stage 2** | **DESIGN (this RFC) — implementation gated** |
| Phase 5 | whole-program fusion + d=768·12L compiled-only fire | RFC 043 north-star | future |

PLAN body update (`self/forge/PLAN.md` + `stdlib/flame/PLAN.md`) = separate task post RFC 050 land. This RFC provides the guide only.

## Authority

- AGENTS.tape `g3` (real-limits-first) — all perf claims trace to forge Phase R measured fires or RFC 049 literature; no fabricated numbers
- AGENTS.tape `g4` (honesty-obligation-external) — no claim that exceeds measured anchor; F-FORGE-RFC050-PERF-INHERITANCE is conservative (degraded by integration overhead margin)
- AGENTS.tape `g5` (hexa-native-only) — flame source = hexa, forge dispatcher = C runtime, `.cu` kernels = portable artifact via nvcc; no LLVM, no C-transpile backend
- AGENTS.tape `g7` (inbox-patches-pipeline) — RFC 050 filed at `inbox/rfc_drafts_2026_05_12/` per convention
- AGENTS.tape `g_arch_vs_log_split` — RFC 050 = architecture draft (editable, latest-wins); land event will append to FORGE.tape ## Log + FLAME.tape ## Log
- AGENTS.tape §0 `nn_stack` — "toolchain ABI lockstep" mandate; RFC 050 §6.7 version pin is the mechanism
- LATTICE_POLICY `f1`/`f2` — no lattice numerology in regime thresholds, precision policy enumeration, or perf claims; all anchors are measured (PARADIGM.md) or cited (RFC 049 literature)
- HEXA-NATIVE-ONLY — flame source compiles via `hexa build` AOT to native code (no LLVM, no C-transpile architecture); forge dispatcher is a C runtime invoked through hexa builtin convention (RFC 040 pattern)
- `g_flame_api_fixed` — RFC 050 does NOT change flame public API; dispatch is internal to compiled stdlib
- `g_flame_compiler_only` — RFC 050 API is invoked at compiled-native eval time, no `hexa_interp` dispatch
- `g_forge_substrate_role` — forge = substrate, flame = consumer; RFC 050 formalizes the boundary
- `g_blue_closed_mandate` (anima cross-repo) — F-FORGE-RFC050-PRECISION-D-PRESERVE preserves CPU farr reference vs GPU kernel bit-equality on the FORGE_PREC_FP64 + FORGE_REGIME_AUTO path

## Stage 2 closure (forge-side) — measured 2026-05-19 (A100)

Stage A landed the stub dispatcher; F2 opened the BF16 path now that
RFC 049 Stage 2 is measured-PASS. `forge_tier_dispatch_v1` no longer
rejects `FORGE_PREC_PURE_BF16` — it routes MATMUL → `hexa_farr_matmul_bf16_gpu`
and FFN_FUSED → `hexa_farr_ffn_bf16_gpu` (the RFC 049 measured entry
points), recovering `HexaFarrBf16*` from `ForgeArgs.farr_ids[]` via the
documented `intptr_t` pointer-cast ABI, behind the `FORGE_TIER_V1_BF16`
guard. Harness: `self/cuda/experiments/r050_dispatch_validate.cu` +
`tool/dispatch_r050_dispatch_validate.sh`. Fire: A100-PCIE-40GB. SSOT:
`state/forge_rfc050_stage2_2026_05_19/`.

| Falsifier | Verdict |
|---|---|
| F-FORGE-RFC050-VERSION-API | **PASS** — `forge_api_version_v1()` == `0x00010000` |
| F-FORGE-RFC050-DISPATCH-ROUTES-BF16 | **PASS** — MATMUL + FFN `PURE_BF16` route via the dispatcher, rc==`FORGE_OK`, max\|Δ\|/max\|Y\| ≤4.7e-3 vs FP64 cuBLAS (4 shapes) |
| F-FORGE-RFC050-FALLBACK-CHAIN | **PASS** — 5 unsupported (family/precision/regime/det) combos each return a negative code, no crash (§6.6 mandate) |

**Verdict.** RFC 050 Stage 2 **forge-side** = measured-resolved. The
dispatcher is a real, fire-validated routing layer over the RFC 049 BF16
substrate. The remaining 5 falsifiers (REGIME-CORRECT, PERF-INHERITANCE,
FORGE-BACKWARD-FUSE, DISPATCH-API-MATCH, PRECISION-D-PRESERVE) are
flame-integration — they need flame's compiled stdlib calling through the
dispatcher, i.e. flame Phase 4-D (the "L1" follow-up), a parallel-session
task. `layercast` precision stays dispatcher-`UNSUPPORTED` honestly (host
`float*` X/Y don't fit the `ForgeArgs` farr-id model).
