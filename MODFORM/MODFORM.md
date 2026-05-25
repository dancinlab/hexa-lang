# MODFORM — Γ₀(N) 모듈러폼·합동사슬 검증기 (도메인 SSOT)

@title: 🔮 MODFORM — Γ₀(N) 모듈러폼 검증기 ("격자 그물코 측정자")
@goal: 모듈러 곡선 Γ₀(N) 의 불변량(index ψ(N)·cusp 수·genus)과 모듈러폼/합동 항등식을 hexa-native `hexa verify` (g5)로 재계산해 atom 으로 등록 — `gamma0_index`·`gamma0_cusps`·`gamma0_genus`·`dim_cusp_forms`·`jacobi`·`kronecker` calc fn 활용, TECS-L M4의 Γ₀(6) 맛보기를 체계적 코퍼스로 확장하고 terminal 발견만 /paper

> TECS-L (n=6 수론) 의 자매 도메인. TECS-L M4 가 Γ₀(6)(index=12=σ(6)·cusps=4=τ(6)·
> genus=0)을 atom 으로 확인했고, MODFORM 은 이를 모든 N 에 대한 모듈러 곡선
> 불변량 코퍼스로 확장한다. 검증 정본은 `hexa verify` g5 — 판정문 verbatim →
> `.verdicts/<slug>/` → `CLAIMS.tape` (group=MODFORM).

---

## 0 · 한 문단 상태 (2026-05-25 도메인 개시)

scaffold 단계. hexa verify 에 Γ₀(N) 불변량 calc fn 이 이미 내장(`gamma0_index`·
`gamma0_cusps`·`gamma0_genus`·`dim_cusp_forms`·`first_cusp_form_weight`) + 2-op
`jacobi`·`kronecker`·`dim_cusp_forms` 라, 첫 라운드부터 verify-loop 가 돈다.
TECS-L M4 가 Γ₀(6) 5개 atom 을 이미 🔵 로 박아둠 — MODFORM 은 그 패턴을 N 전반으로.

## 1 · 마일스톤 (로드맵)

- [ ] M1 — Γ₀(N) index ψ(N)=N∏_{p|N}(1+1/p): N=1..30 `gamma0_index` verify (🔵) + 닫힌형 곱 공식 확인
- [ ] M2 — Γ₀(N) cusp 수: N=1..30 `gamma0_cusps` verify (🔵) + Σ_{d|N} φ(gcd(d,N/d)) 공식
- [ ] M3 — Γ₀(N) genus-0 전수: 고전 15개 N∈{1..10,12,13,16,18,25} 에서 `gamma0_genus`=0 verify (🔵) + 그 외 genus≥1 표본 (🔴/🔵 닫힌-경계)
- [ ] M4 — dim S₂(Γ₀(N)) = genus 관계: `dim_cusp_forms N 2` vs `gamma0_genus N` 일치 verify (🔵)
- [ ] M5 — Jacobi/Kronecker 기호 항등식: `jacobi a b`·`kronecker a b` 이차 상호법칙 인스턴스 verify (🔵)
- [ ] M6 — n=6 bridge: Γ₀(6) index=σ(6)·cusps=τ(6)·genus=0 (TECS-L M4 연계) — 완전수↔모듈러곡선 다리
- [ ] M7 — first_cusp_form_weight(N) 표 + Atkin-Lehner involution 수 = 2^ω(N) 닫힌형
- [ ] M8 — terminal-verdict 발견 → `/paper` 승격 (paper_on_discovery · pre-registered falsifier)

## 2 · 거버넌스 · 비범위

- **검증 정본**: 모든 정량 주장 → `hexa verify` (g5) → 판정문 verbatim → `.verdicts/<slug>/`. LLM 자기판정 금지 (commons g5).
- **비범위**: 물리/끈이론 해석(τ=string dim 류는 TECS-L 소관) · 외부 LMFDB 데이터 대량 import · genus≥2 곡선의 explicit q-expansion(calc fn 범위 밖 = 🟠).
- `.verdicts/` + `CLAIMS.tape` 는 루트 공유 감사 SSOT (TECS-L·ATLAS·CANON 과 동일).
- 작업은 격리 worktree → PR.
