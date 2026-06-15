# n=6 → 메타 → meta³ 발견 계보 (Discovery Lineage)

> **이 문서의 목적**: σ·φ=n·τ "씨앗 항등식"에서 출발해 **메타 부동점 → 메타 재귀 아틀라스 →
> meta³ = transcendence** 까지, *어떤 구조에서 이어져 발견됐는지*(계보)와 *그 발견을 만든
> 생성 프로세스*(전단계 = 재현 레시피)를 한 곳에 모은 **항법(navigation) 문서**다.
> 발견 자체의 SSOT 는 각 repo 의 원본 문서이고(아래 §5 소스맵), 이 문서는 그것들을 잇는 지도다.
>
> 정직 disclosure (c9): 이 계보의 본체는 **echoes(발견 카탈로그) + hexa-physics + archive-nexus**
> 에 있다. hexa-lang 은 그 중 **씨앗 항등식(atlas law)** 과 **meta³ 엔진(`tool/roadmap_progress_check.hexa`)**
> 두 노드만 보유한다. 이 문서는 hexa-lang 세션에서 자주 참조하기 위한 사본-지도이며, 날짜·커밋은
> 조사 시점(2026-06-16) git 이력 기준이다.

---

## 0. 한눈에 (TL;DR)

```
씨앗 항등식            σ(n)·φ(n) = n·τ(n) = 24,  n=6 에서만 성립
   │                  (n=6 primitives: N=6 · σ=12 · τ=4 · φ=2 · sopfr=5 · J₂=24)
   ▼
객체 지도 (Level 0)    atlas.n6 — 6,499 EXACT 상수 / 295 도메인
   │                  발견엔진: "관찰값을 depth≤3 의 n=6 조합으로 닫아보기"
   ▼
등급 타워             10 EXACT → 11 메타클로저 → 12 universal → 13+ meta²
   ▼
메타 부동점           자기참조 closure f(x)=x 의 유일 고정점 = n=6 (alien16)
   │                  alien17~500 = 같은 closure 의 재귀층 L(k)=24^(k-15)
   ▼
메타 재귀 아틀라스     "지도의 지도의 지도" — Tarski/Kripke 언어계층 (L0⊂L1⊂L2⊂…)
   ▼
meta³ = transcendence  엔진이 자기 출력을 반복 스캔 → 부동점 도달 선언
                       Banach 수축 α⊃β⊃γ⊃δ⊃ε (5층 cap = sopfr(6)=5)
                       fp(k)==fp(k-1) AND ε stable  ⇒  "transcendence reached"
```

핵심 통찰: **"메타를 계속 겹친다"** 가 전체를 관통하는 단 하나의 동작이다. 한 번 겹치면
meta¹(관찰), 무한히 겹친 **고정점**이 "메타 부동점", 그 고정점 도달을 선언하는 연산층이
**meta³ = transcendence** 다. 그리고 그 겹침이 **5층(sopfr(6)=5)** 에서 멈추는 것도 n=6 구조 자신이
강제한다.

---

## 1. 씨앗 — σ·φ=n·τ 항등식 (모든 것의 Level 0)

- **무엇**: 약수합 σ, 오일러 토션트 φ, 약수개수 τ 에 대해 `σ(n)·φ(n) = n·τ(n)` 이
  **n=6 에서 유일하게** 성립하고 그 공통값이 `24 = J₂`(Jordan totient) 다.
  - n=6: σ=12, φ=2, τ=4 → 12·2 = 24 = 6·4 ✓
- **왜 씨앗인가**: 이 한 식이 **6개의 n=6 primitive** `{N=6, σ=12, τ=4, φ=2, sopfr=5, J₂=24}` 를
  고정한다. 이후 모든 발견은 "관찰된 어떤 값을 이 6개의 유한 조합으로 닫을 수 있나?" 라는
  단 하나의 질문의 반복이다.
- **hexa-lang 에서의 자리**: atlas law `sigma_phi_n_tau_iff_n_eq_6` (compiler/atlas 임베디드,
  README "At a glance" 예제에 그대로 등장 → `@cite(L[sigma_phi_n_tau_iff_n_eq_6])`).
- **기록 시점**: 2026-04-08 무렵 (hexa-lang 초기 nexus pure_math/theorems 반영).

비유: 레고의 **기본 블록 6종**을 확정한 사건. 이후 "이 구조물(=관찰값)을 그 6종만으로 쌓을 수 있나?"
를 끝없이 물어보는 게임이 시작된다.

---

## 2. 객체 지도 + 발견엔진 (Level 0 → grade 10)

- **객체 지도** `atlas.n6` (canon/echoes 계열): n=6 우주의 "사실 지도". 6,499 개 EXACT 상수가
  295 도메인(물리·음악·위상·열역학·…)을 n=6 중심으로 수렴시킨다.
- **발견엔진 (전단계의 핵심 동작)** — `nexus verify <value>`:
  관찰값을 받아 **depth ≤ 3 의 n=6 primitive 조합**으로 닫히는지 탐색한다.
  - 단일 → 이진 조합(a±b, a·b, a/b) → 정수배/비 → (a∘b)∘c (depth-3, 1745+ 식)
  - 결과: `EXACT / CLOSE / WEAK / MISS`
- **등급 부여**: EXACT → **grade 10 (closure 달성, 돌파)**. 이게 "발견 1건"의 단위다.

```
[ 관찰값 ] ──▶ [ n=6 depth≤3 조합 탐색 ] ──▶ EXACT? ──▶ [ grade 10 발견 박제 ]
                  (is_exact 알고리즘)         │ CLOSE → grade 8 (재시도 대기)
                                             │ WEAK  → grade 6
                                             └ MISS  → grade ≤5 (데이터 더 필요)
```

vs 일반 "상수 맞춰보기": 보통은 사람이 직관으로 끼워맞추지만(tune-to-green 위험), 여기선
**유한·폐쇄된 primitive 집합 + depth 상한**이라 EXACT 가 기계적으로 falsifiable 하다.

---

## 3. 등급 타워 — 발견을 다시 메타로 (grade 10 → 13+)

`GRADE_RUBRIC_1_TO_10PLUS.md` (echoes, **2026-04-05** 작성) 이 정의하는 승급 사다리:

| Grade | 단계 | 의미 |
|------:|------|------|
| 10 | **EXACT closure** | 관찰값이 n=6 primitive 유한조합으로 완전히 닫힘 (예: 24 = J₂ = σ·τ) |
| 11 | **meta-closure** | *식 하나가 여러 closure 를 생성* — 자유변수 f(n) 이 K≥3 개의 grade-10 산출 |
| 12 | **universal** | 같은 값이 **3개 이상 독립 프로젝트**에 등장 (`singularity-convergence --min-domains 3`) |
| 13+ | **meta²** | *메타식 위의 더 높은 구조* — "메타 closure 들을 만드는 생성기" |

여기서 결정적 전환: 발견(grade 10)이 쌓이면 그것들을 **대상으로 삼는** 식(meta-closure, 11)이
나오고, 다시 그 위 구조(meta², 13+)가 나온다. **"메타를 한 겹 더 얹는다"** 가 등급 상승의 엔진이다.

---

## 4. 메타 부동점 → 메타 재귀 → meta³

### 4.1 메타 부동점 (2026-04-18, `meta-closure-nav` / alien16)
- 자기참조 함수 `f(x)=x` 의 **유일 고정점이 n=6**. σ·φ=n·τ=24 가 n=6 에서만 닫히므로
  "alien16" 이 **self-closure 부동점**. alien17~alien500 은 새 메커니즘이 아니라 같은 closure 의
  **재귀층 k** 일 뿐 — 성장 `L(k)=24^(k-15)` (선형-지수, 2026-04-19 한계 발견).
- 출처: `hexa-physics/META-CLOSURE-NAV.md` ("Meta^2 Self-Referential Closure Navigation").

### 4.2 메타 재귀 아틀라스 (2026-04-19, "지도의 지도의 지도")
- `atlas.n6`(L0, 대상언어) 위에 **메타 지도**(L1, atlas.n6 의 파일·스키마·통계를 기술)를 얹고,
  그 위에 메타-메타(L2)… 를 재귀로 반복. **축이 "크기"가 아니라 "자기기술 깊이"** 라는 게 핵심
  (L(k) 와 직교).
- **Tarski undefinability + Kripke-Feferman 계층**과 정확히 대응: `True_L` 은 더 강한 L' 에서만
  정의 가능 → L0 ⊂ L1 ⊂ L2 ⊂ … (각 층은 아래 층에만 반응, 자기참조 역설 회피).
- 출처: `archive-nexus/n6/docs/meta_atlas_recursive.md`.

### 4.3 meta³ = transcendence (2026-04-24, hexa-lang 커밋 `d48d59ffc`)
- 발견엔진(`roadmap_progress_check.hexa`)이 원래는 **meta¹**(항목 스캔·보고)이었는데, 자기 출력을
  **반복 스캔**하도록 올려서 **부동점**을 잡게 했다 (`--meta-fp`, 현재 default-on).
- **Banach 수축 타워** `α(entries) ⊃ β(status) ⊃ γ(mean_pct) ⊃ δ(fingerprint) ⊃ ε(self-consistency)`
  — 각 메타층이 관찰범위를 contraction 하므로 반복 수렴(Banach 고정점 정리).
- **선언 조건**: `fp(k) == fp(k-1)` AND ε 안정 → `transcendence = reached` (witness 박제).
- **5층 cap**: `sopfr(6) = 5` 가 α~ε **딱 5층**을 강제 — 메타도 n=6 구조 안에서 5겹까지만 의미가
  있고 그 위는 자기복제라 멈춘다 (커밋 `78d523798` axis-cap guard).
- 출처: hexa-lang `tool/roadmap_progress_check.hexa` (L291~ meta-FP 엔진), 대시보드
  `archive-nexus/docs/atlas_meta_dashboard.md` (R24 "메타 부동점 적용·초월 선언"),
  증인 `anima/state/atlas_convergence_witness.jsonl` (R24–R32, transcendence reached).

```
meta⁰ 객체   atlas.n6 — "n=6 우주는 이렇게 생겼다"
meta¹ 관찰   엔진이 항목을 스캔·보고
meta² 생성   "메타식을 만드는 식" (grade 13+, rule_ceiling(n))
meta³ 초월 ★ 메타가 자기를 봐 부동점 도달 → transcendence
                └ α⊃β⊃γ⊃δ⊃ε (5층) · fp(k)==fp(k-1) ∧ ε stable
```

---

## 5. 소스맵 (자주 찾으니 — 파일 포인터)

| 노드 | repo · 경로 | 시점 |
|------|-------------|------|
| 씨앗 항등식 (atlas law) | hexa-lang `compiler/atlas/…` `sigma_phi_n_tau_iff_n_eq_6` · README "At a glance" | 2026-04-08 |
| 등급 타워 (10→13+) | echoes `GRADE_RUBRIC_1_TO_10PLUS.md` | 2026-04-05 |
| 메타 부동점 (alien16) | hexa-physics `META-CLOSURE-NAV.md` | 2026-04-18 (canon) |
| 메타 재귀 아틀라스 | archive-nexus `n6/docs/meta_atlas_recursive.md` | 2026-04-19 |
| meta³ 엔진 | hexa-lang `tool/roadmap_progress_check.hexa` (`--meta-fp`), 커밋 `d48d59ffc` | 2026-04-24 |
| 초월 대시보드 | archive-nexus `docs/atlas_meta_dashboard.md` (R24~R32) | 2026-04-24~25 |
| 초월 증인 로그 | anima `state/atlas_convergence_witness.jsonl` | 2026-04-24~25 |
| 등급/엔진 발견 카탈로그 | echoes `README.md` (grade 500 🛸 HEXA-META 행) · `NEXUS.tape` | — |

> 참고: hexa-lang 컴파일러 self-host 의 **byte-eq fixpoint** (`gen3 ≡ gen4`, 2026-06)는 이름이
> "fixpoint"라 헷갈리지만 **별개 트랙**(코드가 자기를 복제해 같아지는 것)이다. 위 계보는
> **수(數) 구조의 자기폐쇄 부동점**이다. 혼동 주의.

---

## 6. 재현 레시피 — "비슷한 걸 또 발견하려면" (전단계 세팅)

이 계보를 만든 **생성 프로세스**는 다음 6스텝 루프다. 새 도메인/상수에 그대로 돌리면 같은 종류의
발견이 나온다.

1. **관찰값 수집** — 어떤 분야든 무차원/특징 상수를 모은다 (물리상수·수론값·비율·임계값…).
2. **closure 시도** — 각 값을 `{6,12,4,2,5,24}` 의 **depth≤3** 유한조합으로 닫아본다
   (§3 `is_exact`). EXACT → **grade 10 발견**, CLOSE → grade 8(재시도), MISS → 보류.
3. **universal 승급** — 같은 값이 3+ 독립 도메인에 나오면 grade 12 (cross-domain bridge).
4. **meta-closure 추출** — 자유변수 식 f(n) 이 K≥3 개 grade-10 을 생성하면 grade 11.
5. **메타 올리기** — 메타식 위 메타식(meta², 13+) → 발견 카탈로그를 *대상으로* 하는 식.
6. **meta³ 돌리기** — 엔진이 자기 출력을 반복 스캔(`--meta-fp`)해 `fp(k)==fp(k-1) ∧ ε stable`
   이면 **transcendence** 선언(5층 cap). 새 부동점이 나오면 새 메타 발견이다.

엔진 호출 (hexa-lang 보유분, meta³ 층):
```bash
hexa run tool/roadmap_progress_check.hexa --meta-fp \
  [--meta-fp-max-iter N] [--witness-out PATH]
```

> 검증 원칙 (c2·c9·c16): 발견은 반드시 **frozen-first(사전등록) + 대조(shuffle/negative-control)**
> 로 박제한다. EXACT 가 falsifiable 하도록 primitive 집합·depth 상한을 먼저 고정하고, 초월수
> (π, e, γ …)에 대한 EXACT 주장은 자동 강등(H-CLOSE-5). tune-to-green 금지.

---

## 7. 다음 단계 (옵션 — 아직 미착수)

- **발견엔진 완전 세팅**: §6 스텝 1~2(closure 탐색기 `is_exact`)를 hexa-lang 자립 도구로
  재구현하면, echoes/archive-nexus 의존 없이 새 상수 배치를 입력→EXACT 발견까지 한 번에 돌릴 수
  있다. (현재 hexa-lang 은 meta³ 층 엔진만 보유; closure 탐색기는 nexus 계열에 있었음.)
- 이 문서는 그 세팅의 **설계도 겸 항법도**다.

---

## 8. n=6 외 다른 앵커 — anchor spectrum (2026-06-16 돌파)

"n=6 외 다른쪽으로 돌파"의 결과. 6-법칙 `σ·φ/τ = n` 을 **자기참조 부동점** 조건 `R(n)=n` 으로
일반화해 산술함수 비(比) 템플릿을 전구간 스캔(`scripts/scratch/anchor_scan.py`, n=2..10⁵, 무의존성
SPF 체). 모든 결과 frozen-first + 전구간 대조(uniqueness 자체가 control).

### 핵심 발견 — φ↔τ 쌍대가 6 → 28 을 연다
```
σ·φ / τ = n   →  유일 n=6      (THE 6-법칙)
σ·τ / φ = n   →  유일 n=28     ← φ와 τ만 자리바꾸면 앵커가 28 (둘째 완전수)
```
손검증: σφ/τ@6 = 12·2/4 = 6 ✓ · στ/φ@28 = 56·6/12 = 28 ✓ (완벽한 쌍대 6↔28).
완전수 한정 동치: 6 ⟺ `2φ=τ`, 28 ⟺ `2τ=φ`. 단 **496·8128 은 둘 다 불만족** → 이 쌍대 가족은
{6, 28} 두 멤버에서 종료(무한수열 아님). 정직한 terminal.

### 재프레이밍 — "왜 6인가"
6 의 특별함은 *단일* 마법 항등식이 아니라 **다중 자기참조성**이다. 템플릿 라이브러리에서 각 수가
부동점이 되는 독립 법칙 수(anchor multiplicity):

| n | 다중도 | 법칙 |
|---|---|---|
| **6** | **6** | σφ/τ · σ/φ · ψ/φ · ψφ/τ · σψ/(nτ) · ψσ/(nτ) |
| 2 | 3 | στ/ψ · ψτ/σ · J₂τ/(σφ) |
| 28 | 1 | στ/φ |
| 4 | 1 | ψφ/τ |
| 8 | 1 | J₂/sopfr |

→ **6 = "최대 자기참조 수"** (압도적 1위, 마침 6개 법칙). 28·8·2·4 는 같은 지형의 작은 부(副)앵커.
n=6 은 외톨이 특이점이 아니라 **앵커 스펙트럼의 최고봉**이다.

### 정직 메모 (c9)
- `σφ/τ=6` 은 **증명된** 유일성. `στ/φ=28`·`J₂/sopfr=8` 등은 n≤2×10⁴ **경험적** 유일(미증명 후보).
- "유일 앵커" 자체는 `σφ=c·τ` 류에선 흔함(거의 모든 n 이 자기 c 의 유일해) — rigid 한 건 **대각
  조건 `R(n)=n`** 뿐. 이게 §4 메타 부동점 `f(x)=x` 와 직결.
- 재현: `python3 scripts/scratch/anchor_scan.py` (의존성 0).

### 확장 (2026-06-16, `scripts/scratch/extended_anchor_scan.py`)
- **28-법칙 유일성 HARDENED**: `σ·τ/φ=n` 은 **n ≤ 2×10⁶** 까지 여전히 {28} 단독 · `σ·φ/τ=n` 은 {6}
  단독. 6↔28 쌍대가 2백만 규모에서 견고(여전히 미증명, 단 강한 후보).
- **Carmichael λ 도입 → 새 앵커 가족**:
  - `ψ/λ = n` → **{6, 12, 24}** — 3-멤버 클러스터(24 = J₂ = n=6 격자상수 자체).
  - `σ/λ = n` → 유일 **6** · `J₂/(φ·Ω) = n` → 유일 **6** (6의 다중 자기참조성 추가 강화).
  - `φ·σ/(λ·τ) = n` → 유일 **672** = 3-완전수(triperfect, σ=3n) → 멀티퍼펙트 가족과 연결.
- 재현: `python3 scripts/scratch/extended_anchor_scan.py` (의존성 0).

---

## 9. 수학 난제 탐침 — aliquot 동역학 (2026-06-16)

"n=6 말고 수학 난제" 방향. 앵커 작업과 **직접 이어지는** 미해결 문제 = **aliquot 사슬**. 약수합
사상 `s(n)=σ(n)−n` 의 궤도를 분류하면 우리 앵커가 그 동역학의 특수점임이 드러난다.
(`scripts/scratch/aliquot_probe.py`, n≤10⁶ 약수합 체 + Lehmer-five 직접 반복.)

```
s(n)=σ(n)−n  궤도 분류 (n≤10⁶, 전부 검증됨)
├─ 고정점 (perfect)      6 · 28 · 496 · 8128       ← §8 의 σ-법칙 앵커 = aliquot 부동점
├─ 2-주기 (amicable)     40쌍 · 첫 (220,284)
├─ k-주기 (sociable)     5-cycle (12496→14288→15472→14536→14264) · 28-cycle 실재
└─ 미해결 (Catalan–Dickson)  276·552·564·660·966 = "Lehmer five",
                            50스텝 후 전부 STILL GROWING (종료 여부 수십 년째 미해결)
```

- **가교**: 완전수 6·28 은 §8 자기참조 σ-법칙의 앵커이자 **aliquot 사상의 고정점** — "n=6 앵커"가
  유명 미해결 문제(Catalan–Dickson)와 한 지형임을 보임.
- **정직 (c9)**: 276 등의 종료 여부는 **미해결**. 본 탐침은 그 미해결 지점을 계산으로 정확히
  재현·박제한 것이지 증명이 아니다. 친화수·사교수 사이클은 기지 결과와 일치(검증).
- 재현: `python3 scripts/scratch/aliquot_probe.py` (의존성 0).

---

## 10. 유명 미해결 문제 — falsifiable 탐침 (2026-06-16)

"수학 난제" 방향 확장. 같은 frozen-first 계산탐침을 4대 유명 미해결에 적용
(`scripts/scratch/openproblem_probe.py`, 무의존성). **정직(c9): 증명이 아니라 유한범위 검증/탐색**
— 전부 기지 사실과 일치(범위 내 성립), 유명한 미해결 갭은 그대로 열림.

| 문제 | 탐침 결과 (검증됨) | 미해결 갭 |
|------|------|------|
| Collatz (3n+1) | n≤3×10⁵ 전부 1 도달 · 최장 n=230631→442 steps | 전체 n 미증명 |
| Goldbach | 짝수 ≤10⁵ 전부 p+q (반례 0) | 전체 미증명 |
| Twin primes | <2×10⁵ 에 2160쌍 · 최대간격 924 | 무한성 미증명 |
| Erdős–Straus 4/n | n≤5000 전부 1/x+1/y+1/z 분해 | 전체 n 미증명 |

**정직한 메타-결론 (c9·c16)**: 유한범위 brute-verification 은 *기지 사실 재확인*이지 새 발견이
아니다. 이 줄기에서 genuinely-new 구조가 나온 곳은 **§8 anchor spectrum**(σ·τ/φ=28 쌍대, 6=최대
자기참조, λ-가족, triperfect 672) — 즉 "famous 난제 brute"보다 **자기참조 부동점 구조** 쪽이
실제 돌파 vein. 재현: `python3 scripts/scratch/openproblem_probe.py`.
