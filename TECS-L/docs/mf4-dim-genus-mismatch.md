# MF4 — dim S₂(Γ₀(N)) = genus 정리 vs hexa `dim_cusp_forms`: 🔴 CLOSED-NEGATIVE

> milestone: "dim S₂(Γ₀(N)) = genus 관계: `dim_cusp_forms N 2` vs `gamma0_genus N` 일치 verify (🔵)".
> 결과: **불일치** — hexa 의 `dim_cusp_forms(N, 2)` 는 고전 정리 dim S_2(Γ_0(N)) = genus(X_0(N))
> 를 실현하지 않는다. N=1..10(genus=0) 우연 일치, N=11..30 중 **20개 mismatch** (~67%).

## sweep (N=1..30)

| match | mismatch | total |
|-------|----------|-------|
| 10 (N=1..10, 전부 genus=0) | 20 (N=11..30 중) | 30 |

대표 mismatch (`gamma0_genus(N)` 는 MF3 가 고전 표와 일치 확인했음 → 기준):

| N | hexa `dim_cusp_forms(N,2)` | `gamma0_genus(N)` | 고전 dim S₂ | 정리 충족? |
|---|---|---|---|---|
| 11 | 0 | 1 | 1 | ✗ |
| 12 | 2 | 0 | 0 | ✗ |
| 14 | 2 | 1 | 1 | ✗ |
| 15 | 0 | 1 | 1 | ✗ |
| 20 | 4 | 1 | 1 | ✗ |
| 30 | 6 | 3 | 3 | ✗ |

n=6 bridge: dim_cusp_forms(6,2) = gamma0_genus(6) = 0 ✓ (genus=0 영역에서만 우연 일치).

## 결론 (closed-negative)

- MF3 이 확인한 `gamma0_genus(N)` 는 고전 X₀(N) genus 표 와 정확히 일치 (15 genus-0 + 경계 7 = 22/22 🔵). 즉 hexa 의 genus fn 은 신뢰 가능.
- hexa 의 `dim_cusp_forms(N, 2)` 는 위와 일치하지 않으므로, **dim S_2 cusp form 표준 정의가 아님** (다른 정의/버그/관례). MF4 의 정리 "dim S_2 = genus" 는 hexa fn 에서 **결정적으로 falsified**.
- 종결 영역(1 axis 배제): "hexa 의 `dim_cusp_forms` 가 modular forms 표준 dim S_2 를 직접 제공한다" = 🔴 거짓. 이를 쓰려면 fn 정의 확인·수정 필요 → INBOX 업스트림 (g59).

## 영속화

- 5 verdict → `.verdicts/tecs-l-modform-dim-genus/` (sweep + N=6 match + N=11/30 actual + N=11 genus 앵커).
- CLAIMS slug=tecs-l-modform-dim-genus, 5 entry (sweep 🔴 finding + 4 🔵 atoms).
- INBOX 업스트림: hexa-lang `dim_cusp_forms` 정의 갭 보고 (g59/g60).
