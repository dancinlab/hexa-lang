# TECS-L — n=6 완전수 수론 발견 엔진 (도메인 SSOT)

@title: 🔬 TECS-L — n=6 수론 발견 엔진 ("완전수 직관")
@goal: archive-TECS-L의 n=6 완전수 수론 발견(σ·τ·φ → 물리상수 · 완전수 정체성 · Golden Zone)을 hexa-native 연산으로 재구현 + `hexa verify` g5로 검증 + atlas 등록 — Python 엔진을 hexa-native로 대체하고, terminal-verdict 발견만 /paper로 승격

> archive-TECS-L (`dancinlab/archive-TECS-L`, Python) 의 수론 발견 코퍼스를
> hexa-lang 의 theorem atlas + `hexa verify` g5 게이트 위로 재근거화하는 도메인
> SSOT. 옛 RFC-080(hexa loop DFS+LLM) 계획서가 이 파일명을 점유하고 있었으나,
> 정본은 `docs/rfc/rfc_drafts_2026_05_22/rfc_080_hexa_loop_dfs.md` 에 보존돼 있어
> 2026-05-25 부터 이 파일을 수론 도메인으로 재배정 (사용자 승인).

---

## 0 · 한 문단 상태 (2026-05-25 도메인 개시)

**M1 CLOSED (2026-05-25)** — n=6 핵심 정체성 σ·φ=n·τ 를 hexa-native `hexa verify` 로
재근거화: n∈{1,6} 성립(🔵) + n=28(2nd 완전수) 닫힌-네거티브(🔴 σφ=672≠nτ=168) 로
"완전수 성질이 아니라 {1,6} 전용"임을 가름. 10 verdict 영속화.

**M3 CLOSED (2026-05-25)** — M1 이 미룬 유일성 잔여를 Dedekind ψ discrepancy
**D(n) = σ(n)·φ(n) − n·τ(n)** 로 재근거화. n=1..100 exhaustive 스윕(hexa-native
compiled 바이너리, load-bearing n 은 `hexa verify --expr` 와 component-wise 교차검증)
→ **zero-count=2, D(n)=0 zeros at {1,6}** (🔵) + 나머지 전부 D(n)≠0 (🔴 CLOSED-negative).
D(28)=504≠0 으로 "완전수도 D=0 아님" 확정. archive `dfs_dedekind_psi_discrepancy.py`
의 D(n)=σφ−nτ 정의와 동일. 16 verdict 영속화. **단, finite 스윕은 전칭(unbounded)
유일성의 증명이 아님** — 전칭 ⟺{1,6} 은 🟡 citation 잔여(아카이브 해석 논증).

archive-TECS-L 의 핵심은 n=6 완전수에서 산술함수
σ(약수합) · τ(약수개수) · φ(오일러 토션트) 만으로 물리상수를 조립하는 "수학 시(詩)"
엔진 (Gemini 평: Ramanujan-level). n=6 핵심 정체성 σ(n)·φ(n)=n·τ(n) 은 이미
hexa-lang `CLAUDE.md` @I + atlas 에 임베드돼 있다. 이 도메인은 그 코퍼스를
hexa-native 연산 + g5 verify 로 한 atom 씩 재근거화한다 — Python 엔진을 대체하고,
아카이브의 자기보고 메트릭을 결정적 판정문으로 승격한다.

## 1 · 출처 코퍼스 (archive-TECS-L · Python)

| 엔진 | 파일 | 역할 |
|------|------|------|
| Perfect Number | `perfect_number_engine.py` | n∈{6,28,496,8128} σ/τ/φ → 물리상수 표현식 |
| Convergence | `convergence_engine.py` | 8 도메인 × ~80 상수 → 수렴점 클러스터 |
| Quantum Formula | `quantum_formula_engine.py` | 양자수 ↔ 수학 타겟 매칭 (depth 2-3 + p-value) |
| Proof | `proof_engine.py` | 발견 수식 → Tier 0-3 등급 (g5 tier 의 선조) |
| DFS / Congruence | `dfs_engine.py` · `congruence_chain_engine.py` | cross-island 매칭 · modular form |
| Discovery loop | `discovery_loop.py` | DFS → Converge → Verify → Grow → Paper 흡수 루프 |

> 아카이브 자기보고 메트릭: 206 n=6 characterizations · 2,711 가설 · 300+ 상수맵 ·
> 49 Zenodo 논문. **본 도메인에서 g5 재검증 통과 전까지 전부 🟡 미검증 인용으로 취급.**

```
 archive-TECS-L (Python)              TECS-L 도메인 (hexa-native)
 ──────────────────────              ──────────────────────────
  σ,τ,φ 산술함수  ─┐                   stdlib 산술함수 모듈 (M2)
  Perfect Number  ─┼─▶ 발견 수식  ─▶  hexa verify (g5)  ─▶  .verdicts/
  Convergence     ─┤                        │
  Proof Tier 0-3  ─┘                        └─▶ atlas 등록  ─▶  /paper (terminal만)
```

## 2 · 마일스톤 (로드맵)

- [x] M1 — n=6 핵심 정체성 σ(n)·φ(n)=n·τ(n): hexa-native 재계산 🔵 (n=6·n=1 HOLDS) + n=28(2nd 완전수) 🔴 CLOSED-negative (σφ=672≠nτ=168 → "완전수 성질" 아님, {1,6} 전용). 10 verdict → `.verdicts/tecs-l-n6-identity/` · `CLAIMS.tape` group=TECS-L. 전칭 ⟺{1,6} 유일성은 🟡 citation 잔여(M3 Dedekind ψ로 이관)
- [ ] M2 — 산술함수 stdlib 모듈 (σ · τ · φ · sopfr) hexa-native — Python `model_utils.py` 대체 + 단위 테스트
- [x] M3 — Dedekind ψ discrepancy D(n)=σφ−n·τ 유일성: n=1..100 exhaustive 스윕 hexa-native → zero-count=2, **D(n)=0 zeros at {1,6}** 🔵 + D(n)≠0 elsewhere 🔴 CLOSED-negative (D(28)=504≠0 → 2nd 완전수도 D≠0). 16 verdict → `.verdicts/tecs-l-dedekind-psi-uniqueness/` · `CLAIMS.tape`. 전칭(unbounded) ⟺{1,6} 유일성은 🟡 citation 잔여 (finite 스윕≠전칭 증명)
- [ ] M4 — 206 n=6 characterizations → 검증 가능 atom triage + `CLAIMS.tape` 인덱스화
- [ ] M5 — 물리상수 조립 (페르미온 질량 avg 1.9% · Koide angle δ=2/9 · 끈이론 차원 σφ=12) → `hexa verify --expr` 🟢 SUPPORTED-NUMERICAL 재계산
- [ ] M6 — 2,711 가설 코퍼스 → g5 tier triage (🔵/🟢 검증 vs 🟡 citation vs 🟠 deferred vs 🔴 falsified) · `.verdicts/` 영속화
- [ ] M7 — Golden Zone (1/e) 자기참조 닫힌형 유도 시도 (아카이브 Level 3→4 #1 EXTREME) — 성공시 🔵, 실패시 🔴 closed-negative (둘 다 publishable)
- [ ] M8 — `discovery_loop.py` → `hexa kick`/`hexa drill` + RFC 065 self-growing atlas 통합 (hexa-native 발견 엔진)
- [ ] M9 — terminal-verdict 발견 → `/paper` 승격 (paper_on_discovery 거버넌스 · pre-registered falsifier 필수)

## 3 · 거버넌스 · 비범위

- **검증 정본**: 모든 정량 주장은 `hexa verify` (g5) → 판정문 verbatim → `.verdicts/<slug>/<id>.txt`. LLM 자기판정 금지 (`CLAUDE.md` @D claim_verify / commons g5).
- **아카이브 자기보고 메트릭은 증거가 아님** — g5 재계산 통과 전까지 🟡 미검증.
- **비범위**: consciousness / EEG / telepathy 모듈 (archive-TECS-L 의 별도 줄기 — hexa-lang scope 외) · Zenodo 재출판 · 외부 peer-review.
- 작업은 격리 worktree → PR (공유 main 트리 race 회피).
