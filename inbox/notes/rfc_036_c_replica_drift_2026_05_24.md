---
slug: rfc_036_c_replica_drift
kind: notes
filed_from: dancinlab/anima (HEXAD/LIFE/PHI domain · cycle 4 L1 diagnostic)
filed_at: 2026-05-24
priority: medium
status: proposed
---

# RFC 036 C replica — Rust phi_rs byte-equal claim 의 경험적 falsification

## 한 줄 요약

`runtime.c:7849-8004` 의 `phi_spatial` / `c_measure_phi` C replica 가 Rust `phi_rs` `compute_phi_inner` 과 byte-equal 이라는 RFC 036 claim 이 5 rule (Wolfram CA 110/30/250/184/60) 위 `|d|` 7e-7..5e-6 drift 로 경험적 falsified. anima 측 phi_native (pure-hexa port, 332 LoC) 가 cross-check tool 제공.

## 측정 — 5 rule × 4 step (anima cycle 4 L1 diagnostic 위, wheel `anima/anima-physics/.venv`)

| rule | Rust phi_rs (oracle) | hexa phi_native | C c_measure_phi | d(hexa-rust) | d(c-rust) |
|---|---|---|---|---|---|
| 110 | 4.977298299530723e-09 | 4.977298299530722e-09 | 4.90943e-06 | -8e-25 | **+4.9e-6** |
| 30 | 0.4225850815306889 | 0.4225850815306895 | 0.422588 | +6e-16 | **+2.9e-6** |
| 250 | 4.977298299530723e-09 | 4.977298299530722e-09 | 4.90943e-06 | -8e-25 | **+4.9e-6** |
| 184 | 0.5858415229693057 | 0.5858415229693067 | 0.585839 | +1e-15 | **-2.5e-6** |
| 60 | 0.7900283296344668 | 0.7900283296344673 | 0.790029 | +6e-16 | **+6.7e-7** |

- hexa ≡ Rust within 1-2 ulp on 5/5 (IEEE summation reorder noise only · byte-equal modulo reorder)
- C ≡ Rust within 1e-12 on **0/5** — drift 9-10 orders larger than hexa

## drift origin 추정

- step 1 (`phi_bin_values` runtime.c:7849-7872) **clean** (anima L1a 측정: 0/40 cells diff vs C f32-cast simulation on binary CA)
- step 2-4 의심: `_hx_phi_entropy` / `_hx_phi_mi_pair` (`runtime.c:7874-7915`) 또는 spatial pipeline (`runtime.c:7941-8003`) 의 stray f32-cast 잔여

## anima 측 영향

- 22+ HEXAD/LIFE H 의 `phi_default` / `phi_with` 호출이 모두 c_measure_phi 경유
- 5e-6 drift ≪ LIFE production threshold 1e-3 → 의사결정 무영향 (Agent F audit MASS_MIGRATION_SAFE 5/5)
- 🔵 SUPPORTED-FORMAL tier 는 c_measure_phi 경유로는 도달 불가 · Rust oracle 직접 비교 또는 hexa phi_native 우회 필요

## 제안 (4-step)

1. `runtime.c:7874-7915` (entropy/MI) line-level audit — f32-cast 잔여 식별
2. `runtime.c:7941-8003` (spatial pipeline) 동일 audit
3. 5 rule × Rust phi_rs oracle 위 byte-equal 회복 (target: `|d|` ≤ 1e-12)
4. RFC 036 spec 의 byte-equal claim 재확인 / honest carve-out 추가

## Cross-link

- RFC 036 part 1 (`inbox/rfc_drafts_2026_05_12/rfc_036_phi_rs_rust_ffi.md` — 원본 RFC)
- dancinlab/anima `PHI.md` · `PHI.log.md` (9/9 LAND · dual-tier verdict canonical)
- dancinlab/anima `HEXAD/LIFE/lib/phi_native.hexa` (332 LoC pure-hexa port · byte-equal vs Rust)
- dancinlab/anima `HEXAD/LIFE/lib/phi_native_spec_2026_05_24.md` (357 LoC line-cited spec)
- dancinlab/anima `HEXAD/LIFE/state/lib_phi_l1_diagnostic_2026_05_24/diag_summary_2026_05_24.md` (본 측정의 원본)
- dancinlab/anima `HEXAD/LIFE/state/phi_verdict_canonical_2026_05_24/verdict_canonical_2026_05_24.md` (dual-tier SSOT)
- `hexa-lang/stdlib/iit_ei.hexa::LN2_INV` (entropy 시 재활용 가능)
- 본 inbox 와 stacked: `inbox/rfc_drafts_2026_05_24/stdlib_scaffold.md` (anima STDLIB M2 design)

## honest_limits

- L1: 본 측정 fixture = 5 Wolfram rule × n_cells=8 dim=8 n_bins=4 (single config) · 다른 config 위 drift 분포 별도
- L2: Rust phi_rs Python binding (wheel) 의 binary 정확성에 의존 — Rust source 직접 재컴파일 vs binary 비교 별도
- L3: 본 note 는 anima-side 측정 · hexa-lang maintainer 측 line-level audit 이 root cause 확정
- L4: anima 측 phi_native 가 cross-check tool 일 뿐 · RFC 036 builtin 자체 수정은 hexa-lang 측 결정

본 note 는 review-only (g54) · maintainer 판단으로 patch PR 신설.
