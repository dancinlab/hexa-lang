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
- [x] M2 — 산술함수 stdlib 모듈 (σ · τ · φ · sopfr) hexa-native: `stdlib/core/math.hexa` 에 `sigma`/`tau`/`euler_phi`+`phi` 별칭/`sopfr` 공개 + 단위테스트 `stdlib/core/math_numtheory_test.hexa` (17 assert · `hexa parse` PASS) + σ/τ/φ n∈{1,6,12,28} 12 verdict 🔵 `hexa verify --expr` verbatim → `.verdicts/tecs-l-arith-stdlib/` · `CLAIMS.tape` slug=tecs-l-arith-stdlib. Python `model_utils.py` 대체
- [x] M3 — Dedekind ψ discrepancy D(n)=σφ−n·τ 유일성: n=1..100 exhaustive 스윕 hexa-native → zero-count=2, **D(n)=0 zeros at {1,6}** 🔵 + D(n)≠0 elsewhere 🔴 CLOSED-negative (D(28)=504≠0 → 2nd 완전수도 D≠0). 16 verdict → `.verdicts/tecs-l-dedekind-psi-uniqueness/` · `CLAIMS.tape`. 전칭(unbounded) ⟺{1,6} 유일성은 🟡 citation 잔여 (finite 스윕≠전칭 증명)
- [x] M4 — 206 n=6 characterizations g5 triage (`TECS-L/docs/n6-characterizations-triage.md`) + 검증 가능 부분집합 15 atom 영속화 (🔵 SUPPORTED-FORMAL: σ/τ/φ/μ/is_perfect/aliquot/σ₀/σ₂/σ₃ ground 값 + Γ₀(6) index=σ·cusps=τ·genus=0·dim S₂=0·conductor=n²). 헤드라인 206 = numbered #1…#206 시리즈; 절대다수는 "f=g⟺n=6" 심볼릭 유일성이라 hexa 전역 recompute 경로 없음 → 🟡 citation (M1 σφ=nτ 유일성과 동일 처리). 15 verdict → `.verdicts/tecs-l-n6-characterizations/` · `CLAIMS.tape` slug=tecs-l-n6-characterizations
- [x] M5 — 물리상수 조립: **τ(perfect_k)=끈이론 임계차원 (4,6,10,14,26)** 5/5 🔵 (τ(33550336)=26 보존끈 D) + SM 게이지합 8+3+1=σ(6)·σ/φ=n·Koide Q=τ/n=2/3·키싱수 6/12/24 🔵. 페르미온질량 1.9%·Koide 5ppm 등 관측매칭은 🟡, CERN·핵 magic은 🟠 (triage doc). 10 verdict → `.verdicts/tecs-l-physics-constants/`
- [x] M6 — 2,711 가설 g5 triage (카테고리 단위, `TECS-L/docs/m6-hypotheses-triage.md`): 🔵 코어 = H18 **σ(n)=2n ⟺ perfect** 첫 5개 완전수 abundancy=2 (σ(33550336)=67100672) + μ(6)=1·aliquot(6)=6, 7 atom. 의식/ML/물리매칭/생물 절대다수는 🟡/🟠/⚪ (hexa 닫힌형 경로 없음). 7 verdict → `.verdicts/tecs-l-hypotheses/`
- [x] M7 — Golden Zone (1/e) 닫힌형 유도 시도 → **🔴 CLOSED-NEGATIVE**: 1/e 는 초월수(Hermite)라 어떤 n=6 유리수와도 정확히 같을 수 없음 (최근접 τ/σ=1/3 9.4%·3/8 1.94% 빗나감; 아카이브 Review 010 자체 self-refute). EXACT 유리수 유도 axis 결정적 배제. 3 🔵 + 1 🔴 → `.verdicts/tecs-l-golden-zone/` (`TECS-L/docs/m7-golden-zone-closed-negative.md`)
- [x] M8 — discovery_loop → hexa-native 발견 엔진: **이미 RFC 065(self-growing atlas)+RFC 080(`--dfs` 포트)로 shipped**. `hexa loop --once` 스모크로 8-stage 사이클 end-to-end 실증(36 lens→153 candidate). archive 6+엔진 → `hexa loop`/`--dfs`/`hexa kick`·`drill`/`hexa verify`/`/paper` 1:1 매핑 (`TECS-L/docs/m8-discovery-engine-mapping.md`)
- [x] M9 — `/paper` 승격: **PAPER/tecs-l-n6-identity-locus/** (10p + fal.ai `fig01_locus.png`). "The {1,6} Identity Locus" — M1 σφ=nτ·M3 D(n)·M5 τ=string-dim·M6 σ=2n 의 terminal 🔵/🔴 발견 소비. pre-registered falsifier=n=28(2nd 완전수) → closed-negative. 전칭 유일성은 🟡 명시 제외(게이트 통과)

## 3 · 거버넌스 · 비범위

- **검증 정본**: 모든 정량 주장은 `hexa verify` (g5) → 판정문 verbatim → `.verdicts/<slug>/<id>.txt`. LLM 자기판정 금지 (`CLAUDE.md` @D claim_verify / commons g5).
- **아카이브 자기보고 메트릭은 증거가 아님** — g5 재계산 통과 전까지 🟡 미검증.
- **비범위**: consciousness / EEG / telepathy 모듈 (archive-TECS-L 의 별도 줄기 — hexa-lang scope 외) · Zenodo 재출판 · 외부 peer-review.
- 작업은 격리 worktree → PR (공유 main 트리 race 회피).
