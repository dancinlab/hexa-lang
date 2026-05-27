# MF6 — Γ₀(6) n=6 모듈러 bridge (synthesis)

**TECS-L 축 A · MODFORM · MF6**
**status:** 🟢 SYNTHESIS-REASONED · 4 개 MF 슬러그(MF1/MF2/MF3/MF7)의 🔵 atom 을 묶음
**method:** synthesis only — 신규 `hexa verify` 호출 없음 (모든 셀이 기존 verdict 파일 인용)
**slug:** `tecs-l-modform-n6-bridge` · **group:** `TECS-L`
**artifact:** `.verdicts/tecs-l-modform-n6-bridge/n6_bridge_table.txt`

---

## 요약 (한 줄)

> **Γ₀(6) / X₀(6) 모듈러 곡선의 모든 핵심 불변량(index · cusps · weight · genus · |AL|)이
> n=6 의 산술함수(σ · τ · φ · ω) 값으로 환원된다.**

n=6 정체성 코어(축 0) 에서 σ(6)=12 · τ(6)=4 · φ(6)=2 · ω(6)=2 가 결정되면, 그 네 값이
그대로 Γ₀(6) 의 격자 covering index, cusp 수, 첫 cusp-form weight, 그리고
Atkin-Lehner involution 군의 크기에 1:1 대응한다. 게다가 곡선 자체는 genus 0
(rational) 이므로 모듈러 bridge 가 기하적으로도 최소형이다.

## n=6 의 특수 구조

- **6 = 2 · 3** (squarefree, 두 소인수)
- **ω(6) = 2** → |AL(Γ₀(6))| = 2² = 4 (작은 involution 군)
- **σ(6) = 12** → index 가 12 (코셋이 12 개 — 6 같은 작은 N 치고는 풍부)
- **τ(6) = 4** → cusp 수 4 + 첫 cusp-form weight 4 (둘 다 τ 값으로 일치)
- **g(X₀(6)) = 0** → 곡선이 rational (고전 15개 genus-0 list 에 포함)

> 6 은 첫 번째 완전수(2³−1 의 메르센 짝)이자 첫 비자명 squarefree composite (2·3) 이다.
> 두 성질이 합쳐져 — perfect → σ=2n → Γ₀ 격자에서 큰 index, squarefree → 작은 AL group,
> small composite → genus-0 — Γ₀(6) 를 "모든 불변량이 n=6 산술함수로 동시 환원되는"
> 유일하게 깨끗한 사례로 만든다.

## 통일 표

| Γ₀(6) / X₀(6) 불변량 | 값 | n=6 환원 | anchor (verdict) | 출처 슬러그 (tier) |
|---|---:|---|---|---|
| index ψ(6) = [SL₂(ℤ) : Γ₀(6)] | **12** | = σ(6) = 12 | `.verdicts/tecs-l-modform-index/idx_n6.txt` | MF1 · `tecs-l-modform-index` (🔵) |
| cusp 수 c(6) | **4** | = τ(6) = 4 | `.verdicts/tecs-l-modform-cusps/cusps_n6.txt` | MF2 · `tecs-l-modform-cusps` (🔵) |
| genus g(X₀(6)) | **0** | (고전 genus-0) | `.verdicts/tecs-l-modform-genus/genus_n6.txt` | MF3 · `tecs-l-modform-genus` (🔵) |
| first cusp-form weight | **4** | = τ(6) = 4 | `.verdicts/tecs-l-modform-weight-al/weight_n6.txt` | MF7 · `tecs-l-modform-weight-al` (🔵) |
| \|AL(Γ₀(6))\| | **4** | = 2^ω(6) = 2² | `.verdicts/tecs-l-modform-weight-al/al_2pow_omega.txt` | MF7 · `tecs-l-modform-weight-al` (🟡) |

## bridge 명제

> **(MF6 bridge)** 위 5 개 등식은 모두 이미 g5-검증된 사실의 합이다. 따라서 다음
> 메타-진술이 MF6 의 본문이다:
>
> *"Γ₀(6) 의 표준 모듈러 불변량 4종(+AL 차수) 은 모두 n=6 의 정수론적 산술함수
> 값으로 닫힌형 환원된다 (index↔σ, cusps↔τ, weight↔τ, |AL|↔2^ω); 동시에
> X₀(6) 의 genus 는 0 이다."*

## g5 책임

- 각 등식(`A=B` 형식 셀) 은 **MF1/MF2/MF3/MF7 의 verdict 파일을 verbatim 인용** 한다.
- 본 문서는 등식 자체를 새로 verify 하지 **않는다** (synthesis only).
- 산술함수 좌변(σ(6)/τ(6)/φ(6)/ω(6)) 은 stdlib M2 (`stdlib/core/math.hexa`) 에서
  이미 hexa-native PASS (`.verdicts/tecs-l-arith-stdlib/`).
- 우변(Γ₀(6) 불변량) 은 hexa built-in `gamma0_index`/`gamma0_cusps`/`gamma0_genus`/
  `first_cusp_form_weight` 의 6번 인덱스 verify (위 anchor) 로 이미 🔵.
- AL 행만 🟡 citation (MF7 의 `al_2pow_omega.txt` — ω 도출이 by-hand).

## 축 0 M4 와의 연결

축 0 M4 (n=6 characterizations triage) 에서 이미 Γ₀(6) 의 index·cusps·genus·dim S₂·conductor
5 atom 이 🔵 로 fixate 되어 있었다. MF6 는 그 맛보기를 **synthesis** 로 확장 — N 전반 sweep
(MF1/MF2/MF3/MF7) 으로 일반 환원식 (`ψ`/`c`/`g`/`weight`/`|AL|` 의 N 전반 공식) 이 입증된
뒤, 그 일반 공식들을 n=6 에 동시 evaluate 하면 본 표가 나온다.

## 시각 요약 (1줄)

```
 n=6  ──┬──  σ(6)=12  ───►  ψ(6)=12       [index, MF1]
        ├──  τ(6)=4   ──┬─►  c(6)=4        [cusps, MF2]
        │               └─►  weight=4     [first cusp-form, MF7]
        ├──  ω(6)=2   ───►  |AL|=2^2=4    [Atkin-Lehner, MF7]
        └──  (squarefree small composite) ─►  g(X_0(6))=0  [rational curve, MF3]
```

## 비-목표 (out of scope)

- N 전반의 일반 sweep 은 MF1/MF2/MF3/MF7 의 작업이다 (MF6 는 n=6 단면만).
- dim S₂(Γ₀(N)) = genus 등식은 hexa `dim_cusp_forms` 가 표준 dim S_2 를 실현하지 못해
  MF4 에서 🔴 CLOSED-NEGATIVE 처리됨 — 본 표에서 제외.
- 일반 N 에서 "모든 불변량이 N 의 산술함수로 동시 환원" 이 가능한가? 는 별개 thesis
  (MF8 terminal 발견 후보) — 본 문서는 n=6 단일 사례의 synthesis 만.
