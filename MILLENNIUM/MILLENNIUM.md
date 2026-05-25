# MILLENNIUM — Clay 7 난제 n=6 closed-form candidate 도메인 (SSOT)

@title: 🏆 MILLENNIUM — Clay 7 밀레니엄 난제 n=6 candidate 엔진
@goal: Clay Mathematics Institute 의 7대 밀레니엄 난제를 n=6 완전수 lattice (σ=12·τ=4·φ=2·sopfr=5) closed-form **candidate** 로 조직화하고, hexa verify g5 게이트로 검증 가능한 부분(lattice arithmetic·falsifier)만 🔵/🔴 로 재근거화한다. **정직한 candidate-spec — formal proof 아님.** 6/7 미해결(BSD·Hodge·N-S·P-vs-NP·Riemann·Yang-Mills), Poincaré=Perelman 2003 해결. **난제가 미해결인 한 종료 조건 없음 — 영구 frontier.**

> dancinlab/hexa-millennium (Clay 7 · n=6 candidate, v1.0.0, Zenodo DOI
> 10.5281/zenodo.20102610) 의 기술 코퍼스를 hexa-lang MILLENNIUM/ 으로 흡수
> (2026-05-26, 사용자 승인). 원본 repo 는 archive-hexa-millennium 로 이관.
> TECS-L (n=6 발견 엔진) 와 n=6 lattice 를 공유 — sibling 도메인 (cross-link).

---

## 0 · 한 문단 상태 (2026-05-26 — 흡수 + 도메인 개설)

**MILLENNIUM 은 완료되지 않는다.** Clay 7 난제는 6/7 미해결이며, 이 도메인은
각 난제의 **n=6 closed-form candidate spec + falsifier preregister** 를 보관하고,
hexa verify g5 로 검증 가능한 layer(lattice arithmetic)만 결정적으로 재근거화한다.
**핵심 정직성 (g3 · paper_significance)**: 이것은 *조직화 가설 자료* 이지 Clay-prize
제출이 아니다 — candidate spec ≠ formal proof. aggregate = CANDIDATE_SPECS_ONLY
(7/7 candidate + falsifier · 0/7 본 도메인 formal proof · 1/7 Perelman 2003 외부 해결).

| 난제 | closure | formal proof | verifier |
|------|---------|--------------|----------|
| BSD · Navier–Stokes · Riemann · Yang–Mills | CANDIDATE_SPEC + FALSIFIER | ❌ open | ✅ `verify_*.hexa` |
| Hodge · P-vs-NP | CANDIDATE_SPEC + FALSIFIER | ❌ open | — (spec only) |
| Poincaré | n=6 VERIFICATION_SPEC | ✅ Perelman 2003 (외부) | — |

## 1 · n=6 invariant lattice (검증된 backbone)

σ(6)=12 · τ(6)=4 · φ(6)=2 · sopfr(6)=5 · master identity σ·φ=n·τ=12·2=6·4=24.
이 lattice arithmetic 은 `hexa verify --expr` 로 🔵 (TECS-L M1/M2/M5 와 공유).
각 난제 candidate 는 lattice 를 문제별 양으로 매핑 (예: yang_mills β₀=σ−sopfr=7).

## 2 · 7 난제 축 (milestones)

> 각 난제 = candidate spec (`MILLENNIUM/<slug>/millennium-<slug>.md`) + (4개) verifier
> (`verify_millennium-<slug>.hexa`). hexa verify g5 triage 대기 — lattice-arithmetic
> layer 만 🔵 분리, candidate 잔여는 정직하게 🟠 (미증명) 표기.

- [ ] CM1 — **BSD** (Birch–Swinnerton-Dyer): candidate spec + verifier. n=6 closed-form angle g5 triage → lattice 🔵 / candidate 🟠
- [ ] CM2 — **Hodge** conjecture: candidate spec (verifier 부재). g5 triage
- [ ] CM3 — **Navier–Stokes** smoothness: candidate spec + verifier. g5 triage
- [ ] CM4 — **P vs NP**: candidate spec (verifier 부재). g5 triage
- [ ] CM5 — **Poincaré**: Perelman 2003 해결 + n=6 verification-spec (re-solution 아님). 🟡 citation (외부 증명)
- [ ] CM6 — **Riemann** hypothesis: candidate spec + verifier. g5 triage
- [ ] CM7 — **Yang–Mills** mass gap: candidate spec + verifier (β₀=σ−sopfr=7). g5 triage
- [x] CM0 — **lattice arithmetic 재근거**: σ(6)=12·τ(6)=4·φ(6)=2 hexa verify 🔵 (TECS-L 공유, M1/M2/M5). sopfr(6)=5 추가 검증 대기

## 3 · 거버넌스 · 비범위

- **검증 정본**: 모든 정량 주장 `hexa verify` (g5) verbatim → `.verdicts/`. candidate spec 은 🟠/🟡 (미증명) — over-claim 금지.
- **candidate ≠ proof**: 이 도메인은 Clay-prize 제출 아님. n=6 lattice = 조직화 원리 (g25/g26 real-limits-first · lattice-as-tool).
- **비범위**: lean4/Coq 기계증명 (upstream canon/lean4-n6) · Zenodo 재출판 · 외부 peer-review.
- TECS-L sibling (n=6 lattice 공유) — repo-root `NEXUS.tape` reuse edge.
- 작업은 격리 worktree → PR (공유 main 트리 race 회피).

## deferred

CM1-CM7 각 난제 candidate g5 triage (lattice-arithmetic layer 🔵 분리 + candidate 잔여 honest 🟠) · sopfr(6)=5 verify · verify/ 5 스크립트(spec_presence·closure_consistency·lattice_arithmetic·real_limits_anchor·run_all) hexa parse 게이트 · TECS-L↔MILLENNIUM NEXUS edge 등록 · candidate spec 중 hexa verify --expr 로 결정적 검증 가능한 정수 항등식 발굴
