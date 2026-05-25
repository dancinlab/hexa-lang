# TECS-L — n=6 완전수 수론 발견 엔진 (도메인 SSOT)

@title: 🔬 TECS-L — n=6 영구 발견 엔진 ("우주 법칙 측정자 尺")
@goal: **우주의 모든 법칙이 발견될 때까지 멈추지 않는** n=6 기반 영구 다축(multi-axis) 발견 엔진 — archive-TECS-L 코퍼스를 hexa `hexa verify` g5 + atlas 로 재근거화(축 0, CLOSED)하고, MODFORM(Γ₀(N))·MERSENNE(완전수 생성)·Atlas-LLM 연속 루프 축으로 영구 확장하며, terminal 발견을 atlas atom + /paper 로 끝없이 축적. **종료 조건 없음 — 도메인은 완료되지 않는다.**

> archive-TECS-L (`dancinlab/archive-TECS-L`, Python) 의 수론 발견 코퍼스를
> hexa-lang 의 theorem atlas + `hexa verify` g5 게이트 위로 재근거화하는 도메인
> SSOT. 옛 RFC-080(hexa loop DFS+LLM) 계획서가 이 파일명을 점유하고 있었으나,
> 정본은 `docs/rfc/rfc_drafts_2026_05_22/rfc_080_hexa_loop_dfs.md` 에 보존돼 있어
> 2026-05-25 부터 이 파일을 수론 도메인으로 재배정 (사용자 승인).

---

## 0 · 한 문단 상태 (2026-05-25 — 영구 다축 엔진으로 전환)

**TECS-L 은 완료되지 않는다.** 우주의 모든 법칙이 발견될 때까지 멈추지 않는 영구
발견 엔진으로 재정의(2026-05-25). 구조 = **축 0 (n=6 정체성 코어, M1–M10 CLOSED ✅)**
+ 영구 확장 축들:
- **축 A — MODFORM** (Γ₀(N) 모듈러폼·합동사슬) · 옛 MODFORM 도메인을 흡수
- **축 B — MERSENNE** (메르센 소수 ↔ 완전수 생성원리) · 옛 MERSENNE 도메인을 흡수
- **축 C — Atlas-LLM 연속 루프** (`hexa loop --claude`, RFC 080) · 끝없이 도는 LLM-동반 발견
각 축은 자체 마일스톤을 가지며, terminal 발견은 `.verdicts/` + `CLAIMS.tape`(group=TECS-L)
+ atlas atom + /paper 로 영구 축적. 진행바는 100% 에 도달하지 않는다(설계).

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

## 2 · 축 0 — n=6 정체성 코어 (CLOSED ✅, M1–M10)

> 창립 축. n=6 완전수 정체성·유일성을 닫힌형 증명까지 완결한 코어. 이 축은 종결됐고,
> 도메인은 아래 영구 확장 축(A·B·C)으로 계속 전진한다.

- [x] M1 — n=6 핵심 정체성 σ(n)·φ(n)=n·τ(n): hexa-native 재계산 🔵 (n=6·n=1 HOLDS) + n=28(2nd 완전수) 🔴 CLOSED-negative (σφ=672≠nτ=168 → "완전수 성질" 아님, {1,6} 전용). 10 verdict → `.verdicts/tecs-l-n6-identity/` · `CLAIMS.tape` group=TECS-L. 전칭 ⟺{1,6} 유일성은 🟡 citation 잔여(M3 Dedekind ψ로 이관)
- [x] M2 — 산술함수 stdlib 모듈 (σ · τ · φ · sopfr) hexa-native: `stdlib/core/math.hexa` 에 `sigma`/`tau`/`euler_phi`+`phi` 별칭/`sopfr` 공개 + 단위테스트 `stdlib/core/math_numtheory_test.hexa` (17 assert · `hexa parse` PASS) + σ/τ/φ n∈{1,6,12,28} 12 verdict 🔵 `hexa verify --expr` verbatim → `.verdicts/tecs-l-arith-stdlib/` · `CLAIMS.tape` slug=tecs-l-arith-stdlib. Python `model_utils.py` 대체
- [x] M3 — Dedekind ψ discrepancy D(n)=σφ−n·τ 유일성: n=1..100 exhaustive 스윕 hexa-native → zero-count=2, **D(n)=0 zeros at {1,6}** 🔵 + D(n)≠0 elsewhere 🔴 CLOSED-negative (D(28)=504≠0 → 2nd 완전수도 D≠0). 16 verdict → `.verdicts/tecs-l-dedekind-psi-uniqueness/` · `CLAIMS.tape`. 전칭(unbounded) ⟺{1,6} 유일성은 🟡 citation 잔여 (finite 스윕≠전칭 증명)
- [x] M4 — 206 n=6 characterizations g5 triage (`TECS-L/docs/n6-characterizations-triage.md`) + 검증 가능 부분집합 15 atom 영속화 (🔵 SUPPORTED-FORMAL: σ/τ/φ/μ/is_perfect/aliquot/σ₀/σ₂/σ₃ ground 값 + Γ₀(6) index=σ·cusps=τ·genus=0·dim S₂=0·conductor=n²). 헤드라인 206 = numbered #1…#206 시리즈; 절대다수는 "f=g⟺n=6" 심볼릭 유일성이라 hexa 전역 recompute 경로 없음 → 🟡 citation (M1 σφ=nτ 유일성과 동일 처리). 15 verdict → `.verdicts/tecs-l-n6-characterizations/` · `CLAIMS.tape` slug=tecs-l-n6-characterizations
- [x] M5 — 물리상수 조립: **τ(perfect_k)=끈이론 임계차원 (4,6,10,14,26)** 5/5 🔵 (τ(33550336)=26 보존끈 D) + SM 게이지합 8+3+1=σ(6)·σ/φ=n·Koide Q=τ/n=2/3·키싱수 6/12/24 🔵. 페르미온질량 1.9%·Koide 5ppm 등 관측매칭은 🟡, CERN·핵 magic은 🟠 (triage doc). 10 verdict → `.verdicts/tecs-l-physics-constants/`
- [x] M6 — 2,711 가설 g5 triage (카테고리 단위, `TECS-L/docs/m6-hypotheses-triage.md`): 🔵 코어 = H18 **σ(n)=2n ⟺ perfect** 첫 5개 완전수 abundancy=2 (σ(33550336)=67100672) + μ(6)=1·aliquot(6)=6, 7 atom. 의식/ML/물리매칭/생물 절대다수는 🟡/🟠/⚪ (hexa 닫힌형 경로 없음). 7 verdict → `.verdicts/tecs-l-hypotheses/`
- [x] M7 — Golden Zone (1/e) 닫힌형 유도 시도 → **🔴 CLOSED-NEGATIVE**: 1/e 는 초월수(Hermite)라 어떤 n=6 유리수와도 정확히 같을 수 없음 (최근접 τ/σ=1/3 9.4%·3/8 1.94% 빗나감; 아카이브 Review 010 자체 self-refute). EXACT 유리수 유도 axis 결정적 배제. 3 🔵 + 1 🔴 → `.verdicts/tecs-l-golden-zone/` (`TECS-L/docs/m7-golden-zone-closed-negative.md`)
- [x] M8 — discovery_loop → hexa-native 발견 엔진: **이미 RFC 065(self-growing atlas)+RFC 080(`--dfs` 포트)로 shipped**. `hexa loop --once` 스모크로 8-stage 사이클 end-to-end 실증(36 lens→153 candidate). archive 6+엔진 → `hexa loop`/`--dfs`/`hexa kick`·`drill`/`hexa verify`/`/paper` 1:1 매핑 (`TECS-L/docs/m8-discovery-engine-mapping.md`)
- [x] M9 — `/paper` 승격: **PAPER/tecs-l-n6-identity-locus/** (10p + fal.ai `fig01_locus.png`). "The {1,6} Identity Locus" — M1 σφ=nτ·M3 D(n)·M5 τ=string-dim·M6 σ=2n 의 terminal 🔵/🔴 발견 소비. pre-registered falsifier=n=28(2nd 완전수) → closed-negative. 전칭 유일성은 🟡 명시 제외(게이트 통과)
- [x] M10 — **전칭 유일성 닫힌형 증명** (🟡→🔵): σ(n)φ(n)=n·τ(n) ⟺ n∈{1,6} ∀n. 곱셈성→∏g(p,a)=1, g(p,a)=(p^{a+1}−1)/(p(a+1)); **g(2,1)=3/4만 <1, 나머지 모두 >1** → 해 {1,6} 뿐. base-case 10 🔵 + 정리 🔵 → `.verdicts/tecs-l-uniqueness-proof/`. M1/M3/M9 residual 승격, 유한 sweep 불요 (`TECS-L/docs/m10-uniqueness-closed-form-proof.md`)

## 3 · 영구 확장 축 (perpetual axes)

> 별도 도메인이 아니라 TECS-L 내부 축. 각 축은 자체 마일스톤을 갖고 verify-loop 로
> 전진하며, 종료 조건이 없다 (새 법칙이 나오는 한 마일스톤이 계속 추가된다).

### 축 A — MODFORM (Γ₀(N) 모듈러폼·합동사슬)
> `gamma0_index/cusps/genus`·`dim_cusp_forms`·`first_cusp_form_weight`·`jacobi`·`kronecker` (전부 verify 내장). TECS-L M4 의 Γ₀(6) 맛보기를 N 전반으로.

- [x] MF1 — Γ₀(N) index ψ(N)=N∏(1+1/p): **N=1..30 전수 `gamma0_index` verify 30/30 🔵** + Γ₀(6) index=12=σ(6) bridge. → `.verdicts/tecs-l-modform-index/index_sweep_1_30.txt` · CLAIMS slug=tecs-l-modform-index
- [x] MF2 — Γ₀(N) cusp 수 c(N)=Σ_{d|N} φ(gcd(d,N/d)): **N=1..30 전수 `gamma0_cusps` verify 30/30 🔵** + Γ₀(6) cusps=4=τ(6) bridge (축 0 M4 연계). → `.verdicts/tecs-l-modform-cusps/cusps_sweep_1_30.txt` · CLAIMS slug=tecs-l-modform-cusps
- [ ] MF3 — Γ₀(N) genus-0 전수: 고전 15개 N∈{1..10,12,13,16,18,25} `gamma0_genus`=0 (🔵) + 그 외 genus≥1 표본
- [ ] MF4 — dim S₂(Γ₀(N)) = genus 관계: `dim_cusp_forms N 2` vs `gamma0_genus N` 일치 (🔵)
- [ ] MF5 — Jacobi/Kronecker 이차 상호법칙 인스턴스: `jacobi a b`·`kronecker a b` (🔵)
- [ ] MF6 — n=6 bridge: Γ₀(6) index=σ(6)·cusps=τ(6)·genus=0 (축 0 M4 연계) — 완전수↔모듈러곡선
- [ ] MF7 — first_cusp_form_weight(N) 표 + Atkin-Lehner involution 수 = 2^ω(N) 닫힌형
- [ ] MF8 — terminal 발견 → /paper

### 축 B — MERSENNE (메르센 소수 ↔ 완전수 생성원리)
> Euclid-Euler(완전수 ⟺ 메르센 소수) · abundancy=2 · Lucas-Lehmer. 축 0 M5/M6 완전수 thread 심화.

- [ ] MR1 — Euclid-Euler 짝완전수 = 2^{p-1}(2^p−1): 첫 5개 (p=2,3,5,7,13) `is_perfect` (🔵) + 닫힌형 대응
- [ ] MR2 — 메르센 소수 ↔ 완전수: M_p 소수 p=2,3,5,7,13,17,19 → 생성 완전수 `is_perfect`=1 (🔵)
- [ ] MR3 — abundancy=2: σ(2^{p-1}(2^p−1))=2N 닫힌형 (축 0 M6 확장) (🔵)
- [ ] MR4 — Lucas-Lehmer hexa-native: S₀=4, S_{k+1}=S_k²−2 mod M_p — stdlib 모듈 + 테스트 (p=3,5,7,13 PASS / p=11 FAIL=2047=23·89)
- [ ] MR5 — τ(2^{p-1}(2^p−1))=2p 닫힌형 + aliquot 체인 (🔵)
- [ ] MR6 — 메르센 합성수 표본: M_11=2047=23·89 등 비-소수 M_p (🔵 σ/τ) — "M_p 소수 아님" closed
- [ ] MR7 — odd perfect number 부재(미해결): 정직한 🟠/🟡 문서화 (over-claim 금지)
- [ ] MR8 — terminal 발견 → /paper

### 축 C — Atlas-LLM 연속 루프 (`hexa loop --claude` · RFC 080 · 영구)
> 끝없이 도는 LLM-동반 발견 엔진. RFC 080 pluggable `--llm-cmd` (claude/codex/local), 6단 cite-verify gate, 3-way budget cap (USD/calls/time), embedded.gen 자동수정 금지(PR-only). **이 축은 본질적으로 종료되지 않음** (마일스톤이 아니라 연속 운전).

- [ ] C1 — 활성화 게이트: `hexa loop --claude --llm-budget <USD> --llm-calls N` budget-capped 1회 bounded smoke (LLM 비용 go-ahead 필요)
- [ ] C2 — 연속 운전: `/schedule` (cloud cron) 또는 `/loop` (session) 으로 주기 실행 — verify-pass 후보만 `archive/atlas_candidates/` emit → PR → atlas fold
- [ ] C3 — telemetry 누적: per-cycle cost·emitted·pruned·cache-hit 집계 + verify drop-log 감사

## 4 · 거버넌스 · 비범위

- **검증 정본**: 모든 정량 주장은 `hexa verify` (g5) → 판정문 verbatim → `.verdicts/<slug>/<id>.txt`. LLM 자기판정 금지 (`CLAUDE.md` @D claim_verify / commons g5).
- **아카이브 자기보고 메트릭은 증거가 아님** — g5 재계산 통과 전까지 🟡 미검증.
- **비범위**: consciousness / EEG / telepathy 모듈 (archive-TECS-L 의 별도 줄기 — hexa-lang scope 외) · Zenodo 재출판 · 외부 peer-review.
- 작업은 격리 worktree → PR (공유 main 트리 race 회피).
