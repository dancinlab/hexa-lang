# `hexa verify --expr` calculator — superconductivity domain fn 7개 누락 (RTSC V2 push 차단)

**Reporter**: demiurge (RTSC 캠페인 V2 🔵 push · 2026-05-24)
**Severity**: medium (RTSC 도메인 V2 closed-form ledger 빈 채로 머무름 — 본 캠페인의 가장 강한 evidence tier blocked)
**Affected**: `tool/verify_cli.hexa::_recompute` (calculator dispatcher), `compiler/atlas/embedded.gen.hexa` (atlas node registry)

## TL;DR

`hexa verify --expr <fn> <n> <v>` 가 RTSC 도메인의 7 핵심 closed-form identities 를 모두 🟠 INSUFFICIENT 로 리턴 — calculator 카탈로그 (BSM / RFC045 / medical) 에 초전도 domain fn 0건. atlas 16083 nodes 의 prefix scan 도 zero match. RTSC V2 milestone (🔵 SUPPORTED-FORMAL push) 가 calculator 본체 확장 없이는 closure 불가.

## 시도된 식 (7개, 모두 🟠 INSUFFICIENT verbatim)

```
hexa verify --expr allen_dynes_tc 25 1100 10     → 🟠 INSUFFICIENT (no calc path)
hexa verify --expr mcmillan_tc 25 1100 10        → 🟠
hexa verify --expr bcs_gap_ratio 1 0             → 🟠
hexa verify --expr lambda_eliashberg 27 0        → 🟠
hexa verify --expr omega_log_moment …            → 🟠 (5-op 한계로 skip)
hexa verify --expr beenet_grid_bins 140 1        → 🟠
hexa verify --expr migdal_ratio 25 10000         → 🟠
```

**최종 분포**: 🔵 0/7 · 🟢 0/7 · 🟠 7/7 · ⚪ 1 fence

## 검증 - 식 자체는 closed-form, libm 으로 정상 재현 (Python sanity)

| identity | input | output | 문헌 ref |
|---|---|---|---|
| Allen-Dynes Tc | h3o λ=2.5, ω_log=1100K, μ*=0.10 | **181.16 K** | RTSC h3o 185K (2% 매치) |
| Allen-Dynes Tc | CaH₆ λ=3.4, ω_log=1200K, μ*=0.13 | **217.10 K** | Ma 2022 측정 215K (2K 정합) |
| BCS gap ratio (weak coupling) | λ→0 | **3.528** | universal |
| BEE-NET grid bins | 140 meV / 1 meV step | **141 bins** | RTSC d7 wall step0 |
| Migdal ratio | ω_max=250 meV, E_F=10 eV | **0.025** | safe (< 0.05) |

→ 식 자체는 단순 closed-form, hexa libm 함수로 충분히 구현 가능. 단지 carlc atalog 에 박혀있지 않음.

## 추가 inherent restriction (확인됨)

- `hexa verify --expr` 는 `to_int` parse 만 지원 → float 입력 (λ=2.5 / μ*=0.10) 직접 안 됨, scaling 우회 필요
- 0-op / 1-op / 2-op / 3-op argv 지원 — 5-op (ω_log moment 같은 다인자) 지원 안 함
- 본 두 제약도 함께 해결되면 RTSC + 다른 multi-arg 도메인 unblock

## Suggested fix

### Fix A — verify_cli.hexa 에 7 fn 추가 (recommended)

`tool/verify_cli.hexa::_recompute` (dispatcher) + 분석원자 모듈에 다음 fn 추가:

```hexa
// _recompute dispatcher 에 case 추가
case "allen_dynes_tc":
    // argv = [lambda_scaled, omega_log_K, mustar_scaled]
    // lambda_scaled = λ × 10 (예: 2.5 → 25), mustar_scaled = μ* × 100 (예: 0.10 → 10)
    let lam = to_float(argv[0]) / 10.0
    let wlog = to_float(argv[1])
    let mus = to_float(argv[2]) / 100.0
    let exp_arg = -1.04 * (1.0 + lam) / (lam - mus * (1.0 + 0.62 * lam))
    let tc = (wlog / 1.2) * exp(exp_arg)
    return tc  // K

case "bcs_gap_ratio":
    return 3.528  // closed-form universal, no input deps in weak-coupling limit

case "lambda_eliashberg":
    // argv = α²F integration result already (precomputed)
    // 또는 trapezoidal integration helper
    ...

case "beenet_grid_bins":
    let omega_max = to_int(argv[0])
    let step = to_int(argv[1])
    return omega_max / step + 1  // 정수 division

case "migdal_ratio":
    let omega = to_float(argv[0])
    let ef = to_float(argv[1])
    return omega / ef
```

7 fn 추가 후 atlas 에 register:

```
hexa atlas register --kind F --id allen_dynes_tc --raw '<spec>'
hexa atlas register --kind F --id mcmillan_tc --raw '<spec>'
...
```

### Fix B — float parsing + N-op argv 도 함께 확장

`verify_cli.hexa::_parse_arg` 가 `to_float` 도 시도하게 (`to_int` 실패시 `to_float` fallback) + dispatcher 가 0-N op variadic 받게. 더 큰 변경이지만 모든 도메인 cross-cutting.

## 우선순위

1. **Fix A** (7 supercon fn 추가) — RTSC V2 unblock, 가장 즉시 가치
2. **Fix B** (float / N-op support) — 인프라 수준 개선, 본 patch 외 다른 도메인 (HERPES `verify_cli.hexa::_recompute exp · pow · hill · poisson_cdf` 등) 도 같이 unblock

## Cross-references

- RTSC 캠페인 V2 milestone closed-form push (본 worktree `RTSC/verify/V2_formal_identities.md` 358 LOC)
- commons @D g5 — 🔵 SUPPORTED-FORMAL closed-form 재현 (현재 RTSC 는 모두 🟠 stuck)
- commons @D d6 — first-principles physics breaks ML wall (V2 가 정합 — closed-form 재현 = first-principles formal layer)
- sibling: HERPES `verify_cli.hexa::_recompute에 exp · pow · hill · poisson_cdf 분석원자 추가` (RTSC.log 의 다른 도메인이 동일 gap 보고)

## Status

- [x] Discovered + verbatim 🟠 7/7 captured (no fake 🔵)
- [ ] Fix A (7 supercon fn 추가) implementation
- [ ] Atlas register (kind F · ids: allen_dynes_tc · mcmillan_tc · bcs_gap_ratio · lambda_eliashberg · omega_log_moment · beenet_grid_bins · migdal_ratio)
- [ ] RTSC V2.1 재시도 후 🔵 7/7 확정
- [ ] Fix B (float + N-op) 별도 PR layer
