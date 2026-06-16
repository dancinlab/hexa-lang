# BUG: 303M-class ConvMoE `.clm` decode forward — per-step memory blowup (OOM-kill)

**Reported by:** anima H_1392 (G6 IDEATION ★ engine-native FALS re-score), 2026-06-16/17
**Severity:** BLOCKER for engine-native decode of any 303M-class (cout≈5000) ConvMoE `.clm`.
**hexa version:** 0.1.0-dispatch (Mac arm64, CPU forge backend)

## Symptom

`CORE/clm_decode.hexa :: clm_decode_topk_sampled` (and `clm_decode_argmax`) on a **303M-class
ConvMoE-RETRO** `.clm` (block0 `{cout:5008, rest:15024}`, 156 MB, v0.2, decodable=true) shows a
**linear per-step memory accumulation** that OOM-kills any non-trivial generation:

| budget (forward steps) | outcome | maximum RSS | peak footprint |
|------------------------|---------|-------------|----------------|
| GEN=8  (single decode) | ✅ completes (RC=0), emits coherent English ("the auth") | (small) | — |
| GEN=24 (single, K=1)   | ❌ KILLED mid-decode (RC=1, "command terminated abnormally"), NO output | **10.97 GB** | **71.5 GB** |
| GEN=48 (best-of-K=3)   | ❌ SIGTERM ~144 s | **10.05 GB** | **54.9 GB** |
| GEN=110 (6-frame arm)  | ❌ silent death ~2 min | — | — |

≈ **+115 MB resident per decode step / multi-GB footprint per step** that is never freed. The
156 MB model decoding 24 bytes should not approach 11 GB RSS / 71 GB footprint.

## Likely cause (for the hexa team to confirm)

The ConvMoE causal-conv decode in `clm_decode.hexa` (`conv1d_via_forge` / `forge_dispatch_matmul`
path, lines ~124-150) appears to **re-materialize and retain the full activation/im2col buffer
per step** instead of a bounded incremental/cached forward — so memory grows O(steps × seq ×
cout) and is not released between steps. At cout=5008 (303M) the constant is large enough to
exhaust RAM within ~20 steps; at cout=768 (the 7.479M MID) it stays small and completes.

## Repro

```
# any 303M-class ConvMoE .clm (cout≈5000), e.g. dancinlab/anima-convmoe-retro-303m baseline_fast.clm
G6_GEN=24 hexa run <single-decode-probe>.hexa   # gen_clm_ideate(ckpt, frame, 24, 40, 0.7, 7)
# -> OOM-killed; /usr/bin/time -l shows ~11 GB max RSS / ~71 GB peak footprint, no output
```
(probe: `anima:state/g6-retro303m-fals/g6_single_k1.hexa`)

## Impact / ask

Blocks `a_engine_native_learning` + `a_verified_must_wire` for ALL 303M+ ConvMoE engine-native
work (H_1381/H_1390 G6 FALS re-score; any 303M/3B/7B `.clm` decode on the live engine). A
**bounded/streaming conv decode** (free per-step im2col + cap retained activation to the causal
window) would unblock it. Until fixed, 303M+ engine-native decode is OOM-bound on CPU; the
GEN=8 path is the only completable budget.
