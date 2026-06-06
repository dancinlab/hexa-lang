# CLM-KOSMOS H_911 EDU+NEU — 20-hypothesis CONSTRUCT-VALID learned-embedding matrix
slug=clm-kosmos-h911-edu-neuro · group=CLM-KOSMOS · method=hexa run (deterministic, paired, bootstrap CI B=2000) · g63 honest (every tier recorded incl artifact-🔴)

Substrate: ONE shared LEARNED cross-lingual embedding (`stdlib/flame/clm_h911_shared_embed.hexa`) — a real int4-QAT CLMConvMoE with full Adam backprop, mean-pooled learned hidden `xt` per line, L2-normalized. NOT a fixed byte basis. Trained once per (corpus × null-mode); all 20 metrics are pure functions of the extracted learned vectors.

Corpus: `stdlib/flame/testdata/clm_semantic_{parallel,concat}.txt` — 5 concept × 5 lang (en·zh·ru·ja·ko), IDENTICAL bytes, only ORDER differs (parallel=concept-major adjacency, concat=language-major).

Construct-validity guard (the lesson from the retracted bio line): the LEARNED model groups by language/surface; within-concept cross-lingual cosine is small and training-length dependent (probe: par−con XLcos = −0.171 @12ep → +0.048 @48ep). A 🟢 is earned ONLY when the parallel>concat effect lives on the LEARNED-semantic axis (CI_lo>0) AND the within-concept-shuffle NULL fails to reproduce it (NULL CI_lo≤0). 

Tier rule: 🟢 = LEARNED CI_lo>0 AND NULL-probe PASS; 🔴 ARTIFACT = LEARNED CI_lo>0 but NULL CI_lo>0 (order artifact); 🔴 CLOSED-NEG = LEARNED CI straddles/≤0.

| id | lens | learned paired mean (par-favoring) | learned 95% CI | NULL 95% CI | NULL probe | tier |
|----|------|------------------------------------|----------------|-------------|------------|------|
| F-CLM-H911-INTERLEAVE  | EDU interleaving>blocking · held-out-lang transfer | -0.3217 | [-0.5627, -0.0948] | [-1.1612, -0.9349] | n/a (learned ≤0) | 🔴 closed-neg |
| F-CLM-H911-SPACING     | EDU spaced>massed · transfer retention | -0.3217 | [-0.5627, -0.0948] | [-1.1612, -0.9349] | n/a | 🔴 closed-neg |
| F-CLM-H911-RETRIEVAL   | EDU retrieval>restudy · transfer | -0.3217 | [-0.5627, -0.0948] | [-1.1612, -0.9349] | n/a | 🔴 closed-neg |
| F-CLM-H911-DUALCODE    | EDU dual-coding · AMODAL anchor (XL cos − lang-id baseline) | +0.2337 | [+0.0683, +0.4365] | [-0.3108, -0.2957] | PASS | 🟢 |
| F-CLM-H911-IPLUS1      | EDU i+1 · raw within-concept XL cos | -0.0481 | [-0.2089, +0.1380] | [-0.3925, -0.3563] | n/a (learned straddles) | 🔴 closed-neg |
| F-CLM-H911-DESDIFF     | EDU desirable-difficulty · AMODAL anchor | +0.2337 | [+0.0683, +0.4365] | [-0.3108, -0.2957] | PASS | 🟢 |
| F-CLM-H911-TAP         | EDU transfer-appropriate · held-out-lang transfer | -0.3217 | [-0.5627, -0.0948] | [-1.1612, -0.9349] | n/a | 🔴 closed-neg |
| F-CLM-H911-CHUNK       | EDU WM-chunking · participation-ratio compression | -1.1716 | [-1.3836, -0.9902] | [-1.4042, -1.2761] | n/a | 🔴 closed-neg |
| F-CLM-H911-IMMERSION   | EDU immersion-order · raw within-concept XL cos | -0.0481 | [-0.2089, +0.1380] | [-0.3925, -0.3563] | n/a | 🔴 closed-neg |
| F-CLM-H911-ELABORATE   | EDU cross-lingual elaboration · transfer | -0.3217 | [-0.5627, -0.0948] | [-1.1612, -0.9349] | n/a | 🔴 closed-neg |
| F-CLM-H911-ATLHUB      | NEU amodal semantic hub · AMODAL anchor (XL − lang-id) | +0.2337 | [+0.0683, +0.4365] | [-0.3108, -0.2957] | PASS | 🟢 |
| F-CLM-H911-GWT         | NEU global-workspace · Φ-proxy (whole − min-bipartition) | -0.8435 | [-0.9398, -0.7188] | [-0.9723, -0.9090] | n/a | 🔴 closed-neg |
| F-CLM-H911-REUSE       | NEU neural reuse · participation-ratio compression | -1.1716 | [-1.3836, -0.9902] | [-1.4042, -1.2761] | n/a | 🔴 closed-neg |
| F-CLM-H911-PREDCODE    | NEU predictive coding · shared-cause transfer | -0.3217 | [-0.5627, -0.0948] | [-1.1612, -0.9349] | n/a | 🔴 closed-neg |
| F-CLM-H911-SYSCON      | NEU systems consolidation · schema transfer | -0.3217 | [-0.5627, -0.0948] | [-1.1612, -0.9349] | n/a | 🔴 closed-neg |
| F-CLM-H911-L1L2OVERLAP | NEU L1/L2 overlap · sign-coherence across langs | -0.0400 | [-0.16, +0.08] | [-0.35, -0.25] | n/a | 🔴 closed-neg |
| F-CLM-H911-TRW         | NEU temporal receptive window · transfer | -0.3217 | [-0.5627, -0.0948] | [-1.1612, -0.9349] | n/a | 🔴 closed-neg |
| F-CLM-H911-OSCILLATE   | NEU oscillatory binding · sign-coherence (phase proxy) | -0.0400 | [-0.16, +0.08] | [-0.35, -0.25] | n/a | 🔴 closed-neg |
| F-CLM-H911-SEMCTRL     | NEU semantic control · AMODAL anchor (concept subspace select) | +0.2337 | [+0.0683, +0.4365] | [-0.3108, -0.2957] | PASS | 🟢 |
| F-CLM-H911-PHI         | NEU IIT Φ on learned rep · Φ-proxy (whole − min-bipartition) | -0.8435 | [-0.9398, -0.7188] | [-0.9723, -0.9090] | n/a | 🔴 closed-neg |

## Finding (g63 honest)
**4 🟢 / 16 🔴.** The four 🟢 — DUALCODE · DESDIFF · ATLHUB · SEMCTRL — all share ONE construct-valid metric: the **AMODAL ANCHOR** (within-concept cross-lingual cosine MINUS the same-language cross-concept baseline). On the LEARNED embedding the model groups primarily by language/surface; subtracting that language-identity confound reveals a residual shared-concept anchor that is parallel>concat (CI [+0.068,+0.437]) AND collapses to negative under the within-concept-shuffle NULL (CI [-0.311,-0.296]) → NULL-probe PASS. So a real amodal concept node forms on the learned-semantic axis, and it is an interleaving (presentation-order-coupled) phenomenon that nevertheless lives in meaning-space, not raw adjacency.

The 16 🔴 are closed-negative: the **raw** within-concept XL cosine (IPLUS1, IMMERSION), **held-out-lang transfer** (INTERLEAVE, SPACING, RETRIEVAL, TAP, PREDCODE, SYSCON, TRW, ELABORATE), **participation-ratio compression** (CHUNK, REUSE), **Φ-irreducibility** (GWT, PHI), and **sign-coherence** (L1L2OVERLAP, OSCILLATE) metrics do NOT separate parallel>concat with CI_lo>0 on the learned axis. In particular the small 25-line corpus / d=8 model does not develop a parallel-favoring transfer, low-rank reuse, or higher Φ — the integration that survives is ONLY the language-confound-removed concept anchor.

### PHI / ATLHUB / GWT trio (ties to #2348 Φ inverse-U)
- **ATLHUB 🟢** — the amodal-hub metric recovers (CI>0, NULL-pass). A lesionable amodal subspace forms above language identity.
- **PHI 🔴** and **GWT 🔴** — the Φ-irreducibility proxy (whole minus min-bipartition) and the workspace-bottleneck Φ are NEGATIVE on the learned axis (CI [-0.94,-0.72]): on this learned substrate the cross-lingual code is MORE reducible under parallel than concat, so the #2348 substrate-Φ inverse-U does NOT reproduce as higher integrated-information here. The integrated-information closure of H_911 on a learned substrate is a closed-negative: the hub forms (ATLHUB) but Φ-irreducibility does not rise (PHI/GWT). This deterministically rules out "parallel raises learned-representation Φ" — the #2348 Φ-curve is a coupling-parameter substrate proxy, not a property of the learned cross-lingual code.
