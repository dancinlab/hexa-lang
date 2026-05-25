# MERSENNE — 메르센 소수·완전수 항등식 검증기 (도메인 SSOT)

@title: 🟣 MERSENNE — 메르센 소수·완전수 검증기 ("2의 거듭제곱 −1 사냥꾼")
@goal: 메르센 수 M_p=2^p−1 과 짝완전수 2^{p-1}(2^p−1) 의 항등식·판정(Euclid-Euler·abundancy=2·Lucas-Lehmer)을 hexa-native `hexa verify` (g5)로 재계산해 atom 으로 등록 — `is_perfect`·`sigma`·`tau`·`aliquot` 활용 + Lucas-Lehmer 신규 경로, TECS-L M5/M6 완전수 thread 를 메르센 축으로 심화하고 terminal 발견만 /paper

> TECS-L (n=6 수론) 의 자매 도메인. TECS-L M5 가 τ(완전수)=끈차원, M6 가 σ(완전수)=2n
> (abundancy) 을 atom 으로 박았고, MERSENNE 은 그 완전수 thread 의 생성 원리
> (Euclid-Euler: 완전수 ⟺ 메르센 소수)를 체계화한다. 검증 정본 = `hexa verify` g5.

---

## 0 · 한 문단 상태 (2026-05-25 도메인 개시)

scaffold 단계. 짝완전수는 Euclid-Euler 로 2^{p-1}(2^p−1) (2^p−1 = 메르센 소수)
와 1:1 대응. `is_perfect`·`sigma`·`tau`·`aliquot` 는 hexa verify 내장이라 첫 5개
완전수(6·28·496·8128·33550336)는 즉시 verify-loop. Lucas-Lehmer 판정(S₀=4,
S_{k+1}=S_k²−2 mod M_p)은 신규 stdlib/calc 경로가 필요 (M4).

## 1 · 마일스톤 (로드맵)

- [ ] M1 — Euclid-Euler 짝완전수 = 2^{p-1}(2^p−1): 첫 5개 (p=2,3,5,7,13) `is_perfect` verify (🔵) + 닫힌형 대응
- [ ] M2 — 메르센 소수 ↔ 완전수: M_p 소수인 p=2,3,5,7,13,17,19 → 생성된 완전수 `is_perfect`=1 verify (🔵)
- [ ] M3 — abundancy=2: σ(2^{p-1}(2^p−1))=2·N 닫힌형 (TECS-L M6 확장, 더 큰 완전수까지) (🔵)
- [ ] M4 — Lucas-Lehmer test hexa-native: S₀=4, S_{k+1}=S_k²−2 mod M_p, M_p 소수 ⟺ S_{p-2}≡0 — stdlib 모듈 + 단위테스트 (p=3,5,7,13 PASS / p=11 FAIL=2047=23·89)
- [ ] M5 — τ(2^{p-1}(2^p−1)) = 2p (약수개수 닫힌형) + aliquot 체인 verify (🔵)
- [ ] M6 — 메르센 합성수 인수분해 표본: M_11=2047=23·89·M_23·M_29 등 비-소수 M_p (🔵 σ/τ) — "M_p 소수 아님" closed
- [ ] M7 — odd perfect number 부재: 미해결 (open problem) → 정직한 🟠/🟡 문서화 (g5 경로 없음, over-claim 금지)
- [ ] M8 — terminal-verdict 발견 → `/paper` 승격 (paper_on_discovery · pre-registered falsifier)

## 2 · 거버넌스 · 비범위

- **검증 정본**: 모든 정량 주장 → `hexa verify` (g5) → 판정문 verbatim → `.verdicts/<slug>/`. LLM 자기판정 금지 (commons g5).
- **비범위**: GIMPS 규모 대형 M_p 탐색(외부 compute = 🟠) · odd perfect number 의 존재/부재 증명(미해결 = 🟡/🟠, 절대 over-claim 금지).
- **TECS-L 중복 회피**: 완전수 ground 값(M5/M6 에서 이미 🔵)은 재검증 대신 src 참조; MERSENNE 의 신규 각도 = 생성원리(Euclid-Euler) + Lucas-Lehmer 판정.
- `.verdicts/` + `CLAIMS.tape` 루트 공유 감사 SSOT. 작업은 격리 worktree → PR.
