# rfc_drafts_2026_05_12 — INDEX

> 22 RFC drafts (RFC-024 .. RFC-048) collected in this directory.
> Status is the self-declared **\*\*Status\*\*** field on line 1-3 of each
> draft. Index regenerated 2026-05-17 by inbox triage pass.
>
> Sunset: once a draft is promoted to `proposals/rfc_<n>_*.md` or
> integrated into a SSOT (FLAME.tape / FORGE.tape / PARADIGM.md), the
> entry here becomes archival.

## Summary

| status | count | RFCs |
|---|---|---|
| implemented | 10 | 025, 029, 030, 031, 032, 033, 034, 035, 036*, 045 |
| design-draft (active SSOT) | 8 | 040, 041, 042, 043, 044, 046, 047, 048 |
| draft (open) | 4 | 024, 026, 027, 028 |

\* RFC 036 = `implemented-with-named-blocker`.

## implemented — landed in code or marked closed-evidence

- **rfc_025** — safetensors zero-copy load (16× memory reduction). Tier 1 landed 2026-05-12. Severity: CRITICAL (ML inference blocker).
- **rfc_029** — `continue` scope inside nested `if` (interp codegen). FIXED 2026-05-12 in `self/hexa_full.hexa::eval_body`. Severity: BLOCKER.
- **rfc_030** — `bytes_to_str_raw([int]) -> string`. Implemented 2026-05-12. Tracked in [[stdlib-c-ffi-v1.1-out-pointer]] track.
- **rfc_031** — safetensors BF16 → f32 farr reader. Implemented 2026-05-12. Severity: HIGH (pure-hexa BF16 ckpt inference).
- **rfc_032** — `farr_matmul` native packed-double matmul builtin. Implemented 2026-05-12. Severity: HIGH (24-layer forward parity).
- **rfc_033** — `farr_copy` + `farr_add_gaussian_noise` native builtins. Implemented 2026-05-12. Severity: HIGH (serve-time mitosis).
- **rfc_034** — `farr` reverse-mode autograd (CE loss + AdamW step). Implemented 2026-05-16. Severity: HIGH (anima HEXAD training).
- **rfc_035** — `farr` bf16/fp16 mixed-precision training (loss scaling). Implemented 2026-05-16. Severity: MEDIUM.
- **rfc_036** — `phi_rs` Rust FFI byte-equal IIT Φ. `implemented-with-named-blocker` 2026-05-16. Severity: MEDIUM (anima Phase 4).
- **rfc_045** — flame Phase 3 algorithmic byte-eq with anima d_corpus_fire oracle. `closed-evidence` 2026-05-17 — landed across 16 commits on `rfc043-hexa-torch`. Severity: HIGH (F-RFC043-STEP-EQ closure).

## design-draft — active SSOT, no implementation yet

These are tracked as SSOTs in [[FLAME.tape]] / [[FORGE.tape]] / [[PARADIGM.md]] and drive ongoing flame/forge Phase R work.

- **rfc_040** — `farr` GPU/CUDA backend (device-farr + kernel dispatch). Severity: HIGH (real-scale d=768·12L). Subsumed by [[rfc_044]] in part.
- **rfc_041** — real CUDA kernels for RFC 040 Phase B/B2 `farr` ops. Severity: MEDIUM-HIGH. Subsumed by [[rfc_044]] (substrate absorption).
- **rfc_042** — AOT-native trainer control-flow execution (LM-scale ceiling). Severity: HIGH. **SUBSUMED by [[rfc_043]]** per FLAME.tape §0.
- **rfc_043** — `hexa-torch`: compiler-only, farr-native tensor / autograd / NN training stdlib. Severity: HIGH (consolidating north-star). **flame SSOT.**
- **rfc_044** — forge: dual-mechanism × regime-tiered AOT substrate. Severity: HIGH (architectural pivot — paradigm-aware substrate). **forge SSOT (Phase R anchored).**
- **rfc_046** — flame Phase 4: compiler fusion for eager-PyTorch throughput match. Severity: HIGH (perf-domain entry).
- **rfc_047** — flame Phase 4-B: per-block IR pass for compile-time block fusion. Severity: HIGH (Stage 2 block fusion, ~5× wall target).
- **rfc_048** — flame Phase 4-C: fwd+bwd graph fusion at compile time. Severity: HIGHEST IMPACT (RFC 046 dominant single Phase 4 win).

## draft — open, awaiting promotion or absorption

- **rfc_024** — ML-aware default memory cap (768MB → adaptive). Severity: BLOCKER (ML workloads). Partially absorbed by [[codegen-struct-fwddecl-vs-fn-arena]] (HEXA_MEM_CAP_MB env raised to 4096 MB) — full adaptive cap deferred.
- **rfc_026** — cross-host dispatcher env passthrough + project `.hexarc`. Severity: HIGH (cross-host UX).
- **rfc_027** — stdlib internal imports self-resolve (when caller is inside stdlib/). Severity: MEDIUM (resolver UX).
- **rfc_028** — `--local` / `HEXA_NO_REMOTE=1` for explicit non-dispatched execution. Severity: MEDIUM (cross-host transparency).

## Promotion path

Implemented + closed-evidence RFCs can be promoted to `proposals/rfc_NNN_*.md` once the project decides to keep the formal RFC record. design-drafts that are SSOTs (043, 044, 045) already have their canonical home in the flame / forge `.tape` files — promotion to `proposals/` may be redundant.

Drafts (024, 026, 027, 028) should be either promoted or filed at `inbox/patches/` if they become concrete patch proposals.
