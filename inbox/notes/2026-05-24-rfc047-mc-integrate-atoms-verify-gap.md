# RFC 047 mc-integrate atom 등록 BLOCKED — verify 계산기 float-path 부재 (2026-05-24)

## 한 줄 요약
RFC 047 mc-integrate 의 수학 primitive 3종 (Welch-t critical-t table · Welch
indistinguishability gate · Wilson-Hilferty t→z transform) 을 atlas atom 으로
등록하려 했으나, `hexa verify` 계산기 시스템에 **float-valued 통계 변환 recompute
path 가 없어** g5 게이트 (🟢 NUMERICAL 이상) 를 충족 불가 → **등록 보류, finding
note only**.

## dup-race precheck (PASS — 신규)
- `hexa atlas lookup --prefix=mc_integrator` → `# no nodes match`
- `hexa atlas lookup --prefix=wilson` → `# no nodes match`
- `grep mc_integrator|wilson_hilferty|welch` `compiler/atlas/embedded.gen.hexa`
  · `n6/atlas.n6` → 매칭은 전부 **kind `@C` (criterion/falsifier-axis)**
  이며 auto-ingested ω-cycle (`omega_cycle_mc-integrate-compare-*`) 설명 노드.
  수학 primitive 를 담는 kind `@P`/`@X` 닫힌형 atom 은 **0개**.
- 결론: 제안 atom (`mc_integrator_welch_t_table` · `mc_integrator_critical_p` ·
  `wilson_hilferty_transform`) 은 미등록 — dup 아님.

## 추출한 수학 primitive (출처: `stdlib/mc_integrate/engine.hexa`)

### 1. `mc_integrator_welch_t_table` — df-aware critical-t lookup (α=0.05 two-tailed)
- 위치: `engine.hexa::_t_crit_005_two_tailed(df: float) -> float` (L613-640)
- NIST/SEMATECH e-Handbook §1.3.6.7.2 (0.025 upper) verbatim breakpoints:
  - `df=1 → 12.706` · `df=2 → 4.303` · `df=3 → 3.182` · `df=4 → 2.776`
    · `df=5 → 2.571` · `df=10 → 2.228` · `df=20 → 2.086` · `df=30 → 2.042`
    · `df=50 → 2.009` · `df=100 → 1.984` · `df=∞ → 1.960` (= z_{0.975})
  - Welch–Satterthwaite non-integer df → 인접 breakpoint 선형보간; df<1 clamp
    12.706, df≥10000 → 1.960.
  - Cross-check: Bevington & Robinson 3rd ed. Table C.2 (p.254).

### 2. `mc_integrator_critical_p` — Welch-t indistinguishability gate
- 위치: `engine.hexa::_welch_t(a, b) -> map` (L741-832)
- t = (m_a − m_b) / √(se_a²/n_a + se_b²/n_b)
- Welch–Satterthwaite df = (se_a+se_b)² / (se_a²/(n_a−1) + se_b²/(n_b−1))
- 판정: `indistinguishable ⟺ |t| < t_crit_df_aware` (atom #1 의 보간 critical-t).
  flat |t|<2.0 임계 (df=∞ 에서 over-reject, df=2 에서 under-reject) 를 대체.

### 3. `wilson_hilferty_transform` — Welch p-value via t→z + Φ(z)
- 위치: `engine.hexa::_welch_p_value(t, df) -> float` (L711-724) +
  `_norm_cdf(z) -> float` (L671-707)
- Hill-style t→z 보정 (Wilson-Hilferty 계열): z = t·(1 − 1/(4·df)) / √(1 + t²/(2·df))
- p_two = 2·(1 − Φ(|z|)); Φ 는 Abramowitz & Stegun 26.2.17 rational
  approximation (max abs err ~7.5e-8), φ(z) 는 16-term Taylor of exp(−z²/2).
- 정확도 (vs scipy.stats.t.sf): df≥10 |Δp|<5e-4 · df=5 <5e-3 · df=3 <0.02 ·
  df<3 "poor" (flag 만 emit). 신뢰 게이트는 atom #1 의 critical-t table,
  p-value 는 보조.

## 블로커 — g5 게이트 충족 불가 (VERBATIM verify verdict)

`hexa verify --expr <fn> ...` 의 recompute 시스템 (`tool/verify_cli.hexa::_recompute`
· `_recompute2`, 그리고 register-sink 가 mirror 하는 `tool/atlas_cli.hexa::
_recompute_register` · `_recompute2_register`) 은 **정수값 정수론 닫힌형만**
지원한다 (sigma · phi · mu · tau · jacobi · kronecker · gamma0_* · dim_cusp_forms
… 모두 `fn(int) -> int`). float 통계 변환을 표현할 시그니처가 없다.

실측 (VERBATIM):

```
$ hexa verify --expr welch_t_crit 1 12
verify --expr welch_t_crit(1)=12
  tier   = 🟠 INSUFFICIENT
  reason = calculator system has NO path for 'welch_t_crit'
  gap    = extend tool/verify_cli.hexa::_recompute (계산기시스템 개선 후보)

$ hexa verify --expr wilson_hilferty 1 0
verify --expr wilson_hilferty(1)=0
  tier   = 🟠 INSUFFICIENT
  reason = calculator system has NO path for 'wilson_hilferty'
  gap    = extend tool/verify_cli.hexa::_recompute (계산기시스템 개선 후보)
```

- verdict = **🟠 INSUFFICIENT** (≠ 🟢 NUMERICAL · ≠ 🔵 FORMAL).
- `hexa atlas register --from-verify` 경로도 막힘: 어댑터가 `_recompute_register`
  no-path → `🟠 INSUFFICIENT` event 를 생성하고, canonical sink
  `tool/atlas_cli.hexa::register_from_event` 는 `verdict != "🔵 SUPPORTED-FORMAL"`
  인 event 를 **거부** (L829-831). 따라서 등록 자체가 불가.

작업 지시의 제약 — "verify 가 numerical 불가면 finding note 만" — 에 따라 등록을
보류하고 본 note 만 남긴다. (g5: LLM self-judge 금지, verdict 는 위 VERBATIM 인용.)

## 등록을 풀려면 (carry-forward — 별도 사이클)
g5 를 충족하려면 verify 계산기에 float 통계 recompute path 를 추가해야 한다. 후보:

1. **`tool/verify_cli.hexa::_recompute` 의 float 확장** (그리고 `atlas_cli.hexa`
   의 mirror): 정수 `fn(int)->int` 외에 `fn(float...)->float` 닫힌형 dispatch +
   tolerance 비교 → 🟢 SUPPORTED-NUMERICAL verdict 발급. 단 현 `--expr` 인터페이스
   가 정수 인자/값 파싱 (`to_int`) 이라 float 인자 경로 신규 필요.
   - `welch_t_crit(df)` : NIST table 보간값을 알려진 df 에서 recompute
     (예: `welch_t_crit(1) == 12.706` tolerance 0) → table atom 검증.
   - `wilson_hilferty_p(t, df)` : `_welch_p_value` recompute 후 scipy 기준값과
     |Δp| tolerance 비교 (df≥10 5e-4) → transform atom 검증.
2. **공유 dispatcher 추출**: `verify_cli` 와 `atlas_cli` 가 `_recompute` 를 중복
   inline (atlas_cli L470-472 주석이 "extract once a 3rd consumer arrives" 명시).
   float 확장은 이 추출과 묶는 것이 자연스럽다.
3. 그 후 `hexa verify --expr` 가 🟢 NUMERICAL 을 내면 본 3 atom 을 kind `@P`
   (numerical operation/transform) 로 등록 — embedded.gen.hexa 직접 splice +
   PR-only (@D atlas_fold).

## cross-link
- RFC 047 (mc-integrate absorption) · `stdlib/mc_integrate/{engine,mc_integrate}.hexa`
  (1,263 LoC) · README.md
- 기존 ω-cycle criterion 노드: `mc_integrate_compare_critval_table_and_welch_p_F*`
  (`embedded.gen.hexa` L2678-2683 등) — falsifier-axis 설명, 수학 atom 아님.
- gov: project.tape `@D atlas_fold` (embedded.gen.hexa via branch→commit→PR) ·
  commons g5 (verify verdict VERBATIM · LLM self-judge 금지)
