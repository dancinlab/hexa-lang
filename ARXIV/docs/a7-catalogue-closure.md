# A7 — catalogue closure report (5-axis aggregate + verify-density 상관 + A8 paper-gate eval)

> ARXIV 도메인 A7 마일스톤. A1-A6 가 흡수·검증·분배·정산한 **5-axis fan-out 전체**를
> 하나의 closure report 로 집계한다 — 5축 aggregate funnel(~58편), 축별 tier split,
> verify-density 상관표, 13 🔵 verify-native 총계, g65 ledger(`.verdicts/arxiv-closure/ledger.json`),
> g67/g68 NEXUS.tape reuse edge(ARXIV PROVIDES cross-repo paper-provenance), 그리고 A8 paper-gate
> 엄정 평가. **새 verify 산출이 아니라 catalogue closure 집계 + reuse edge + gate eval** 이다.

## 0 · 한 문단 closure

ARXIV catalogue-mirror lane 은 5개 axis(A1 POC + A2 ANIMA + A3 DEMIURGE + A4 PHANES +
A5 HEXA-LANG) 로 **~58편**의 arxiv 논문을 흡수했다. 흡수의 산출은 3-class(verify-able 🔵 /
citation 🟡 / cross-repo handoff)로 분류되고, A6 가 handoff 메커니즘을 정본화하며 3 부채를
정산했다. closure 의 핵심 측정값: **13편의 verify-native 🔵**(5 DEMIURGE 물리상수 + 8 HEXA-LANG
math.NT) — 즉 흡수 논문 중 hexa atom 으로 **DIRECT recompute** 된 것만이 verify-able 이고,
그 수는 **target-repo 의 폐형해(closed-form) 밀도에 정비례**한다(verify-density 상관). ANIMA/PHANES
는 polyfill 0 = consumer 축으로 정직한 0 verify. 이 상관 자체가 A8 paper-gate 평가의 대상이다.

## 1 · 5-axis aggregate funnel (~58 papers)

```
                  ARXIV catalogue-mirror lane — 5-axis fan-out funnel
                  =====================================================

   arxiv query (q-bio.NC · physics.atom-ph · cs.AI · cs.PL · math.NT · cs.LO)
        |
        v
   +-------------------------------------------------------------+
   |  INGEST   ~58 on-topic papers across 5 axes                 |
   |    A1 POC  12  |  A2 ANIMA 11  |  A3 DEMIURGE 12             |
   |    A4 PHANES 10 |  A5 HEXA-LANG 13                           |
   +-------------------------------------------------------------+
        |
        v  3-class triage (per paper; classes overlap = dual)
        |
        +----------------------+----------------------+
        |                      |                      |
        v                      v                      v
   +----------+         +-------------+        +------------------+
   | (a) 🔵   |         | (b) 🟡      |        | (c) handoff      |
   | verify-  |         | citation    |        | cross-repo (g60) |
   | able     |         | atlas-cite  |        | OR in-repo(A5)   |
   +----------+         +-------------+        +------------------+
        |                      |                      |
        v                      v                      v
   13 🔵 VERIFY-NATIVE   ~29 🟡 citation        35 cross-repo handoff
   (DIRECT recompute)    nodes (atlas ref)      + 0 in-repo (A5 null case)
        |                                              |
        | 5 DEMIURGE physics + 8 HEXA-LANG NT          | A6 mechanism + 3-debt clear
        v                                              v
   +-------------------------------+        +---------------------------------+
   | hexa atom recompute LIVE      |        | target-repo INBOX.log.md (g60)  |
   | (+1 🔴 neg ctrl per axis)     |        | anima 6 H · demiurge 12 · phanes 10 |
   +-------------------------------+        +---------------------------------+

   FUNNEL WIDTH:  58 ingest  ->  13 verify-native 🔵  (22.4% verify-density)
                              ->  ~29 citation 🟡
                              ->  35 cross-repo handoff + 1 in-repo null
```

> funnel 폭 해석: 58편 흡수 → **13편만 verify-native**(22.4%). 나머지는 citation(atlas reference)
> 또는 cross-repo handoff(소비자 repo 로 분배). verify-able 13편은 *우연이 아니라* producer 축
> (DEMIURGE/HEXA-LANG)에 100% 집중 — §3 상관표가 그 메커니즘이다.

## 2 · 축별 tier split

| axis | papers | 🔵 verify-native | 🟡 citation | handoff | 성격 |
|---|---|---|---|---|---|
| **A1 POC** (ANIMA seed) | 12 | 0 | 5 | 7 → anima (STUB) | POC — 파이프라인 검증 |
| **A2 ANIMA** | 11 | 0 | 7 | 6 H → anima (filed) | consumer (IIT primitive 부재) |
| **A3 DEMIURGE** | 12 | **5** (+1 🔴) | 7 | 12 → demiurge | **verify-native producer** |
| **A4 PHANES** | 10 | 0 | 5 | 10 → phanes | consumer (OUROBOROS/SaaS) |
| **A5 HEXA-LANG** | 13 | **8** (+1 🔴) | 5 | **0 (IN-REPO)** | **verify-native (self)** |
| **합계** | **~58** | **13 🔵** (+2 🔴) | **~29 🟡** | **35 cross-repo + 0 in-repo** | 2 producer / 3 consumer-or-POC |

비고:
- 🔵 13 = A3(5) + A5(8). 그 외 3축(A1/A2/A4)은 0 verify-native(정직).
- 🟡/handoff 는 dual 이 있어(논문이 citation 이면서 동시에 handoff) 단순 합 ≠ paper 수.
- A1 의 handoff 는 **STUB**(실제 filing 은 A2+ / A6 에서 정산). A5 는 handoff 0 = **self-absorb null case**.
- 🔴 neg ctrl 2종 = A3 `pair_threshold_kinetic 1 5`(FALSIFIED) + A5 `sigma 6 13`(FALSIFIED) = 결정성 대조군.

## 3 · verify-density 상관표 (axis → target 폐형해 밀도 → verify-able count)

A6 §4 에서 정립한 상관을 closure 의 정량 축으로 고정한다:

| axis | target repo | target 폐형해 밀도 | verify-able count | producer/consumer |
|---|---|---|---|---|
| **A3 DEMIURGE** | demiurge | **high** — RFC-045 물리 fn 이 `hexa verify --expr` 에 깔림 | **5 🔵** (+1 🔴) | producer |
| **A5 HEXA-LANG** | hexa-lang (self) | **highest** — σ/τ/φ/μ/nth_prime/catalan/partition TECS-L Tier1 | **8 🔵** (+1 🔴) | producer (in-repo) |
| **A2 ANIMA** | anima | **0** — Φ/EI/PCI 폐형해 atom 없음 | **0** | consumer |
| **A4 PHANES** | phanes | **0** — OUROBOROS 엔진 소비자, SaaS 축 | **0** | consumer |
| **A1 POC** | anima (seed) | **0** — A2 와 동일 도메인(IIT primitive 부재) | **0** | consumer (POC) |

```
   verify-density  ∝  target-repo 의 closed-form atom 밀도

   A5 HEXA-LANG (수론 σ/τ/φ 폐형해, self)      → 8 🔵   ┐ verify-native PRODUCER
   A3 DEMIURGE  (물리 factor/exponent 폐형해)   → 5 🔵   ┘   = 13 🔵 total
   ──────────────────────────────────────────────────────
   A2 ANIMA     (Φ/EI primitive 부재)          → 0      ┐
   A4 PHANES    (OUROBOROS 엔진 소비자)         → 0      ┤ consumer = 0 🔵
   A1 POC       (ANIMA seed, IIT 부재)         → 0      ┘   (honest, not failure)
```

**상관의 메커니즘**(A6 §4 정본): verify-able recompute = "논문이 인용하는 *값*을 hexa atom 으로
재계산". 그 값이 target 도메인의 폐형해 atom 으로 *이미 존재*해야(= verify-native) DIRECT recompute
가 가능. consumer 도메인(밀도 0)은 citation + cross-link 만 남고 verify 수치 = 0. 이것은
**honest negative 가 아니라 구조적 사실** — A2/A4/A1 의 0 은 실패가 아니라 그 축이 소비자라는 측정.

**상관은 시간에 따라 움직인다**: A2 의 4 verify-able-CANDIDATE(exact-EI/neural-complexity/ETC/CTM)
는 V5 IIT 엔진(`stdlib/consciousness/iit4`, NEXUS p_iit4 promote 완료)이 ANIMA 측에 배선되면
ANIMA 폐형해 밀도가 0→양수로 바뀌어 첫 🟢 가 가능해진다. 즉 상관의 **데이터점은 5개**(A1-A5)이고,
producer 2 / consumer 3 의 양극(bimodal) 분포다.

## 4 · 13 🔵 verify-native 총계 (DIRECT recompute, +2 🔴 neg ctrl)

**A3 DEMIURGE — 5 🔵 물리상수** (정수-exact, HEAD #1153, mini arm64, POOL_DISABLE=1):
1. `pair_threshold_kinetic_factor` = 6 — ⓵생성 T_th = 6·m_p_c²
2. `pair_threshold_total_factor` = 7 — ⓵생성 E_beam = 7·m_p_c²
3. `cyclotron_cool_massexponent` = 3 — ⓸냉각 τ_c ∝ m³
4. `cyclotron_cool_bratio_exponent` = 2 — ⓸냉각 (B-ratio exponent)
5. `cyclotron_cool_bexponent` = -2 — ⓸냉각 τ_c ∝ B⁻²
   - 🔴 neg ctrl: `pair_threshold_kinetic 1 5` → FALSIFIED (결정성)

**A5 HEXA-LANG — 8 🔵 math.NT 논문** (논문의 *대상* 이 곧 hexa atom = DIRECT recompute):
1. 1309.0906 Dris (odd-perfect) — `sigma`/`is_perfect`
2. 1011.6160 Shevelev (near-perfect) — `sigma`/`aliquot`
3. 2202.06357 Mersenne-perfect-poly — `is_perfect`/`sigma`
4. 1704.05595 Schmidt (sum-of-divisors) — `divisor_sum`/`sigma_k`
5. 0201265 Moree (Ramanujan partition-τ) — `partition`/`tau`
6. 0210312 Ruiz-Sondow (nth-prime) — `nth_prime`
7. 0502532 Callan (Catalan) — `catalan`
8. 1207.4446 Coleman (totient) — `phi`/`euler_phi`
   - 16종 fn · 30+ recompute 🔵; 🔴 neg ctrl: `sigma 6 13` → FALSIFIED (결정성)

**spot-confirm (A7, 재확인)**: `nth_prime 10 29` 🔵 · `catalan 5 42` 🔵 · `sigma 6 13` 🔴 ·
`pair_threshold_kinetic_factor 1 6` 🔵 · `cyclotron_cool_massexponent 1 3` 🔵 — A1-A6 의 LIVE
측정이 A7 시점에도 유지됨(verify CLI 정상, regression 없음).

> 합계: **13 🔵 verify-native** (5 DEMIURGE + 8 HEXA-LANG) + **2 🔴 neg ctrl**(축당 1). 이것이
> ~58편 흡수 funnel 의 verify-native 종착폭(22.4%).

## 5 · NEXUS.tape reuse edge (g67/g68) — ARXIV PROVIDES cross-repo paper-provenance

closure 의 reuse-edge 산출(g68 star, **additive only**): ARXIV 도메인은 hexa-lang hub 안에서
**cross-repo paper-provenance** 를 생산해 sibling consumer 들(anima/demiurge/phanes)에게 제공한다.

```
   hexa-lang hub
       |  (ARXIV 도메인 = catalogue-mirror lane)
       |     PROVIDES: arxiv paper-provenance (id + 저자 + 제목 + tier + cross-link)
       |
       +--> anima      (A1+A2: 6 H_xxx LIFE cross-link, q-bio.NC ingest)
       +--> demiurge   (A3: 12 ANTIMATTER 7공정 cross-link, physics.atom-ph ingest)
       +--> phanes     (A4: 10 4표면 cross-link, cs.AI ingest)
       +--> hexa-lang  (A5: self-absorb null case — in-repo atlas feed, INBOX hop 없음)
```

NEXUS.tape 에 추가되는 노드(§3 hub→consumer star 와 동형, 신규 PROVIDES):
- `@X p_arxiv` — provides: ARXIV catalogue-mirror paper-provenance(arxiv id + 저자 + 제목 + tier +
  cross-link). consumers: anima(6 H) · demiurge(12 공정) · phanes(10 표면). g68 star.
- `@X e5` — reuse-edge: ARXIV paper-provenance → anima/demiurge/phanes(g60 INBOX handoff 으로
  분배, A6 가 3 debt 정산 commit). A5 self-absorb 는 null/identity 케이스(in-repo atlas feed).

이 edge 는 **additive** — 기존 8-consumer star(n2) 와 충돌하지 않고, ARXIV 가 그 star 위에서
*paper-provenance* 라는 새 substrate 종류를 hub→consumer 방향으로 흘린다(코드 substrate(p_magnet
등) ↔ paper-provenance substrate(p_arxiv) 는 직교).

## 6 · A8 paper-gate eval (STRICT) — verify-density 상관이 방법론적 finding 인가?

CLAUDE.md `@D paper_significance`/`paper_gate` 기준으로 **엄정** 평가:

**후보 finding**: "ARXIV 흡수 축의 verify-ability 는 target-repo 폐형해 밀도에 정비례한다
(verify-density ∝ closed-form atom density; 5 데이터점 = producer 2 / consumer 3, bimodal)."

**paper-gate 4-게이트 점검**:

1. **pre-registered falsifier 가 있는가?** — ❌ **없음**. 상관은 A2→A5 흡수를 *마친 후*
   사후 관찰됐다. "verify-density 가 폐형해 밀도와 무관할 것"이라는 falsifier 를 흡수 *전*에
   등록하지 않았다. `@D paper_significance` = "pre-registered falsifier + real measurement" → FAIL.
2. **real measurement 인가?** — ⚠ 부분. 13 🔵 + 2 🔴 는 실측(hexa verify LIVE)이지만, 그것이
   "상관"을 *측정* 한 게 아니라 흡수의 부산물이다. 상관 자체는 5개 데이터점의 관찰(서술적).
3. **finding = Δ vs baseline OR closed-negative 인가?** — ❌. baseline 대비 Δ 없음(흡수 집계).
   결정적으로 한 축을 ruling-out 하는 closed-negative 도 아님(상관은 양극 분포의 *서술*).
4. **trivial recheck / bookkeeping 인가?** — ⚠ A7 은 본질적으로 catalogue **closure 집계**
   (bookkeeping closure). `@D paper_significance` = "paper for a bookkeeping closure 금지".

**판정: A8 SKIP** (정직). 이유:
- **pre-registered falsifier 부재**(게이트 1 FAIL). verify-density 상관은 흥미로운 구조적 관찰이지만
  사후 패턴이지 falsifiable hypothesis 로 *사전 등록* 되지 않았다.
- finding 이 Δ-vs-baseline 도 closed-negative 도 아닌 **서술적 집계**(게이트 3 FAIL).
- A7 자체가 bookkeeping closure(게이트 4 ⚠) — `@D paper_significance` 가 명시적으로 금지하는
  "paper for a bookkeeping closure".
- `@D paper_gate` STRICT = "no pre-registered falsifier → SKIP honestly"(task 지시와 일치).

**A8 SKIP — 단, 미래 TRIGGER 경로 (정직한 조건부)**: verify-density 상관을 *진짜* finding 으로
승격하려면 **pre-registered falsifier 를 먼저 등록** 해야 한다. 예:
> *falsifier (pre-register)*: "ANIMA 에 V5 IIT 엔진(폐형해 밀도 0→양수)이 배선되면 ARXIV-ANIMA
> 축의 verify-able count 가 0→양수로 *예측대로* 움직인다. 만약 V5 배선 후에도 ANIMA verify count
> 가 0 이면 상관은 FALSIFIED."

이 falsifier 는 (a) 흡수 *전* 등록 가능, (b) V5 배선이라는 real measurement 로 검증 가능,
(c) Δ(0→양수 예측 vs 실측)를 가진다 → 그때 A8 은 4-게이트 통과. **지금은 그 전제(V5 ANIMA 배선)가
미충족**이므로 A8 = SKIP, falsifier 는 미래 trigger 로 ARXIV.md A8 항목에 기록.

## 7 · 거버넌스 · 정직성

- A7 = catalogue closure 집계 + reuse edge + gate eval. **새 verify 산출 아님**(13 🔵 는 A3/A5 측정 재인용; spot-confirm 만 재실행).
- verify 정본 = `hexa verify` g5. LLM 자기판정 금지. neg ctrl(🔴) = 결정성 대조군.
- NEXUS.tape edge = **additive only**(g67/g68) — 기존 star/edge 불변.
- ledger = `.verdicts/arxiv-closure/ledger.json`(g65) — 축별 {papers, verify-able, citation, handoff-target, handoff-commit}.
- A8 = **SKIP**(정직) — pre-registered falsifier 부재 + 서술적 집계(Δ/closed-negative 아님) + bookkeeping closure. 미래 trigger = V5 ANIMA 배선 falsifier.
- naive dump 금지 — 흡수 논문 전부 verify-gate 통과 OR 명시적 cross-link 보유(A1-A6 에서 충족).
