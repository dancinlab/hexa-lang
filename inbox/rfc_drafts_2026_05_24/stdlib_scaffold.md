---
slug: stdlib_scaffold
kind: rfc_drafts
filed_from: dancinlab/anima (STDLIB domain · cycle 2 design)
filed_at: 2026-05-24
priority: medium
status: proposed
relates_to: rfc_036_c_replica_drift_2026_05_24, RFC 036
---

# RFC draft: hexa-lang stdlib scaffold — 1st-wave 5 module 신설

## §1 한 줄 요약

anima 측 ~247 dup primitive sprawl 해결을 위한 hexa-lang stdlib 의 첫 module 5 개 신설 + 후속 module 의 evergreen scaffold 제안. 1st-wave 5 fn promote 시 anima 측 `phi_native.hexa` 200→50 LoC (-75%).

## §2 배경 + 측정 결과

- dancinlab/anima `PHI domain` 9/9 LAND · 산출 `HEXAD/LIFE/lib/phi_native.hexa` 332 LoC 중 5 fn (~150 LoC) 가 general primitive (LIFE-specific X)
- `STDLIB survey 2026-05-24` (`HEXAD/STDLIB/survey_2026_05_24.md` 228 LoC) 측정:
  - 10 카테고리 · 47 candidate fn · ~247 dup sites
  - hot dup top: `abs_f`(77) · `pow2_int`(33) · `wolfram_init_row`(32) · `lcg_next`(28) · `sqrt_newton`(17)
- hexa-lang stdlib 부분 존재 확인:
  - `core/math.hexa` (정수만)
  - `core/math/float.hexa` (pi/e/tau/lgamma · transcendentals 부재)
  - `iit_ei.hexa` (EI 만 · entropy/MI 부재 · `LN2_INV = 1.4426950408889634` 보유)
  - `rng.hexa` (LCG 이미 보유 · anima 28 dup 즉시 sweep 가능)
- missing builtin: `log2` · `pow2_int` · `bit_set` — 본 부재가 anima sprawl 의 root cause

## §3 제안 — 1st-wave 5 module

| module | path | fn signature | LoC est | 의존 |
|---|---|---|---|---|
| math/log | `stdlib/math/log.hexa` | `fn log2(x: f64) -> f64` | 6 | `core/math/float::log` + `iit_ei::LN2_INV` |
| math/bitops | `stdlib/math/bitops.hexa` | `fn pow2_int(k: int) -> int`<br>`fn bit_set(mask: int, b: int) -> int` | 12 | none |
| info/entropy | `stdlib/info/entropy.hexa` | `fn shannon_entropy(counts: farr_handle, k: int, total: int) -> f64` | 14 | `math/log::log2` |
| info/binning | `stdlib/info/binning.hexa` | `fn bin_values_minmax(values: farr_handle, n: int, n_bins: int) -> farr_handle` | 33 | `core/math/float::floor` |
| info/mutual_info | `stdlib/info/mutual_info.hexa` | `fn mutual_info_pair(a: farr_handle, b: farr_handle, n: int, n_bins: int) -> f64` | 38 | `info/binning` + `info/entropy` |

## §4 의존 그래프

```
        core/math/float
              │
              ▼
    bitops    log   binning
      │       │       │
      └──┬────┘       │
         │ ── entropy ─┘
                │
                ▼
          mutual_info
```

- 순환 0건 · 외부 의존 0건 (모두 hexa-lang 내부)
- breadth 2: `math/bitops` ⊥ `math/log` 병렬 land 가능
- 1st-wave leaf = `info/mutual_info` (외부 caller 없음)

## §5 2nd-wave 후속 module 후보 (별도 RFC)

- `stdlib/consciousness/phi_spatial.hexa` — `info/*` + `math/*` 합성 wrapper · RFC 036 byte-equal 유지 의무
- `stdlib/wolfram/ca.hexa` — `wolfram_run_ca` (32 dup · LIFE substrate generator)
- `stdlib/stats/correlation.hexa` — `pearson_r` / `spearman_rho` (14 dup 각)
- `stdlib/signal/voss_mccartney.hexa` — H_209 의 1/f^β spectral

## §6 byte-equal 보존 보장

- 1st-wave 5 fn 분해는 anima 측 `phi_native.hexa` 와 `core/math/float` 의 ulp-noise 1-2 까지 보존
- PHI domain dual-tier verdict (🔵 vs Rust phi_rs / 🟢 vs c_measure_phi) 보존 의무
- 분해 후 anima 측 regression: `verify_phi_native.hexa` 재실행 → 5/5 byte_equal flag + 1 determinism 패턴 동일 유지
- regression target: anima `HEXAD/STDLIB/phi_native_predecomp_baseline_2026_05_24.md` (172 LoC freeze)

## §7 migration plan (anima 측)

- **Phase 1**: hexa-lang 측 5 fn module land (본 RFC 승인 후)
- **Phase 2**: anima `phi_native.hexa` 분해 (5 fn 호출로 교체) — 200→50 LoC
- **Phase 3**: anima 측 22+ H 의 inline duplicate sweep (`abs_f` 77 · `pow2_int` 33 · `lcg_next` 28 · `wolfram_run_ca` 32 등 별도 cycle)

## §8 honest_limits

- L1: stdlib naming convention 정립 미정 (`core/*` 와 새 module `math/`/`info/` 의 위치 표기)
- L2: `farr_handle` vs array literal 의 dual signature 문제 (M5 `binning` 의 surface 결정)
- L3: cross-repo land 순서 — anima caller 가 깨지지 않도록 hexa-lang side 먼저
- L4: `log2` 의 builtin 승격 vs wrapper 유지 (hexa runtime 측 결정)
- L5: 본 RFC 의 maintainer 승인 의존 — anima 단독 land 불가
- L6: `iit_ei::LN2_INV` 재배치 (entropy 의 의존 → 위치 이동 가능성)

## §9 next-step

- 본 RFC 의 hexa-lang 측 maintainer 승인 = single bottleneck
- 승인 후 1st-wave fan-out 권장: 5 module 병렬 sub-PR (breadth 2 안에서 ortho: `math/bitops` ⊥ `math/log` 동시 land 가능 → 이후 `info/entropy` → `info/binning` → `info/mutual_info` chain)
- gh-stack 권장 (M3 cycle 은 anima 가 아닌 hexa-lang 측 fan-out)
- anima 측 M4 (byte-equal regression harness) 는 hexa-lang M3 land 가 prerequisite

## §10 Cross-link

- dancinlab/anima `STDLIB.md` · `STDLIB.log.md` (도메인 SSOT · 5/19 LAND)
- dancinlab/anima `PHI.md` · `PHI.log.md` (9/9 LAND · dual-tier verdict)
- dancinlab/anima `HEXAD/STDLIB/survey_2026_05_24.md` (228 LoC · 47 candidate fn 매핑)
- dancinlab/anima `HEXAD/STDLIB/phi_native_predecomp_baseline_2026_05_24.md` (172 LoC · regression target)
- dancinlab/anima `HEXAD/LIFE/lib/phi_native.hexa` (332 LoC · 7 fn pure-hexa port)
- `inbox/notes/rfc_036_c_replica_drift_2026_05_24.md` (관련 byte-equal claim falsification · g59 enforcement)
- `hexa-lang RFC 036` (원본 phi_spatial builtin · 본 stdlib 의 `consciousness/phi_spatial.hexa` 가 reference impl)
- `hexa-lang/stdlib/iit_ei.hexa::LN2_INV` (log2 implementation 시 재활용)

본 RFC 는 design-only · 코드 변경 0 · review-only (g54) · maintainer 직접 승인/merge.
