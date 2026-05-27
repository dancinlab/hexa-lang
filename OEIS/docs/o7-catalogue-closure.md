# O7 — 카탈로그-미러 클로저 리포트 (O1–O6 종합 + paper-gate eval)

@slug: oeis-closure · group=OEIS · method=synthesis/closure
@date: 2026-05-26 (UTC)
@scope: docs + verdict + CLAIMS only — atlas(embedded.gen.hexa) 미접촉 (O4 가 소유)

> 한 줄 결론: OEIS 카탈로그-미러 레인은 **374,047 seq → 7 atlas-linked NT-fn provenance**
> 까지 결정론적으로 닫혔다. K=20 coincidence-filter 가 K=10 hit 의 **78%(1334/1707)**
> 를 first-K artifact 로 폭로 — 이 측정이 O1 에 pre-register 된 falsifier
> "K=10 prefix-match ⟹ sequence identity" 를 FALSIFY 하는 **닫힌-부정 finding** 이다.
> → **O8 paper TRIGGER** (단, 범위-한정 솔직 caveat 동반).

---

## §1 · 종합 집계 (funnel)

O1–O6 가 산출한 정수 측정값을 단일 깔때기로 집계한다. 모든 숫자는
`.verdicts/oeis-full-sweep/ledger.json` · `.verdicts/oeis-perhit-verify/tier_ledger.txt`
· `.verdicts/oeis-atlas-fold/fold_ledger.txt` verbatim.

| 단계 | 입력 | 산출 | 출처 |
|------|------|------|------|
| **O1** POC scan | 첫 1000 A-line (899 ≥K=10) × 20 fn | **6** hit (~0.67%; offset 버그 — n²/n!/Fib miss) | oeis-scanner-poc |
| **O2** full sweep | 374,047 seq (≥K=10) × 20 fn · K=10 hash-intersect | **1,707** K=10 hit | oeis-full-sweep |
| **O2** K=20 filter | 1,707 K=10 hit | **336** survive · **1,334** coincidence · **37** na | ledger.json |
| **O3** per-hit verify | 336 K=20 survivor (distinct fn↔id) | **🔵 8 (7 distinct)** / **🟡 41** / **🟠 287** | tier_ledger.txt |
| **O4** atlas fold | 7 distinct 🔵 theorem | **7 atlas-linked** (4 @P present + 1 alias + 3 새 @F) | fold_ledger.txt |
| **O5** TECS-L cross-link | 7 provenance link | TECS-L F11 cite + NEXUS g67 reuse edge | crosslink.txt |
| **O6** DLMF probe | 패턴 이식성 | **🔴 FALSIFIED** (closed-negative; 패턴 DLMF 로 일반화 안 됨) | o6-dlmf-feasibility.md |

### ASCII funnel

```
        OEIS stripped.gz bulk dump (CC-BY-SA)
                      |
                      v
   374,047  swept seq (>=K=10 terms)  x 20 candidate hexa NT/poly fn
   ===============================================================
                      |  K=10 hash-intersect  (O(N), 수 초)
                      v
     1,707  K=10 hit
   --------------------------------------------------------------
                      |  K=20 second-pass coincidence filter
        +-------------+-------------------------------+
        |             |                               |
        v             v                               v
      336           1,334                             37
   K=20 survive   COINCIDENCE (first-K artifact)     na (<20 terms)
                  = 78.1% of all K=10 hits
                  = 79.9% of the 1,670 disprovable
        |
        v   O3 per-hit hexa verify --expr (g5)
   --------------------------------------------------------------
     🔵 8 DIRECT   🟡 41 CITATION   🟠 287 NO-PATH (calculator-gap)
   (7 distinct)    (alias prefix)   (n×190 · prime×67 · poly/trivial)
        |
        v   O4 verified-only atlas fold (dedup vs ~16K nodes)
   --------------------------------------------------------------
     7 atlas-linked NT-fn  =  4 @P present (sigma/tau/phi/mu)
                             + 1 alias (sigma_0 == tau, A000005)
                             + 3 newly-folded @F OEIS-attributed
                               (aliquot A001065 / sigma_2 A001157 /
                                sigma_3 A001158)   net +3 (16134->16137)
        |
        v   O5 cross-link
   TECS-L axis-F F11 (downstream cite) + NEXUS.tape §3b reuse edge (g67)

   [O6 sister-probe]  DLMF as-is reuse -> 🔴 FALSIFIED (closed-negative)
```

선택률(funnel selectivity): 374,047 → 7 = **5.3×10⁻⁵** (1.9만 seq 당 1 검증 fn).
catalogue-mirror 의 의도된 보수성 — naive dump(380K @C 무차별) 대신 verify-gated fold.

---

## §2 · 성과 (closed-positive)

### (1) 7 NT-fn 의 검증된 OEIS↔hexa provenance

O3 hexa `verify --expr` (g5 rubric) sample-PASS → O4 atlas-link 까지 닫힌 7 distinct theorem:

| hexa fn | OEIS id | atlas status | sample-verified | OEIS 정의 |
|---------|---------|--------------|-----------------|-----------|
| sigma   | A000203 | @P present [11*] | n=3(4)·4(7)·6(12)·COMPUTE 7(8) | sum of divisors |
| tau     | A000005 | @P present [11*] | n=6(4)·10(4)            | number of divisors |
| sigma_0 | A000005 | alias of tau     | ≡ tau (same len(divisors)) | = τ |
| phi     | A000010 | @P present [10*] | n=9(6)                 | Euler totient |
| mu      | A008683 | @P present [10*] | n=6(1)                 | Möbius |
| aliquot | A001065 | **@F newly-folded** | n=8(7)              | aliquot sum σ(n)−n |
| sigma_2 | A001157 | **@F newly-folded** | n=9(91)             | sum of squares of divisors |
| sigma_3 | A001158 | **@F newly-folded** | sigma_k(9,3)=757 [2-op] | sum of cubes of divisors |

(8 🔵 pair → 7 distinct theorem: sigma_0/tau 가 A000005 위 동일 hexa fn 으로 collapse.)
3 새 @F node 는 OEIS CC-BY-SA 귀속(source + url) 동반 fold. main tree 누수 0.

### (2) K=20 coincidence-filter 방법 — first-K artifact 의 대량 폭로

핵심 방법론 성과: **K=10 prefix-match 만으로는 sequence identity 를 결정하지 못한다.**
O2 의 2-pass(K=10 hash-intersect → K=20 verbatim 재확인)가 1,707 K=10 hit 중
**1,334(78.1%)** 를 first-K artifact 로 제거. 즉 K=10 매치의 약 4/5 가 우연 prefix.
이 필터가 없었다면 catalogue-mirror 는 1,707 후보를 떠안았을 것이며, 그중 78%
는 noise 였다. K=20 second-pass = 거의-무료(K=10 hit 1,707 건에만 적용) coincidence 거름망.

---

## §3 · 한계 (honest)

### 🟠 287 = recompute-primitive 부재 (calculator-gap), VERIFY-KIT V7 의 mutual-feed

287 🟠 의 100% 가 `hexa verify --expr` 의 `_recompute` 에 경로가 없어서 막혔다 (값
재현 불가가 아니라 **재계산 surface 부재**). 분포:

```
n × 190   (다항/trivial — A000027 외 189 alias)
prime × 67
odd × 12 · triangular × 7 · two_n × 3 · n_squared × 2
catalan/factorial/fibonacci/n_cubed/pronic/two_to_n × 각 1
```

- `n`/`prime`/`odd`/`triangular`/`poly` 류는 OEIS a(n) 를 재현하는 closed-form 이
  존재하지만 verify-CLI 레지스트리에 미등록 → `NOCALC` → 🟠 INSUFFICIENT.
- **VERIFY-KIT V7 (combinatorial/prime fn)** 가 `n`/`prime`/`catalan`/`factorial`/
  `fibonacci`/다항 recompute 를 추가하면 이 287 의 다수가 🔵/🟡 로 재분류 가능 —
  단 대부분 `n`·`prime` 의 trivial-identity alias 라 catalogue-cite(🟡)이지 새 theorem 은 아님.
- **mutual-feed loop**: OEIS sweep 이 "어떤 fn 의 recompute 가 없어 막혔는가" 를 측정
  → VERIFY-KIT 가 그 fn 을 추가 → OEIS 가 재-sweep 으로 🟠→🔵/🟡 전환. O2 의 g59
  INBOX filing(value-less COMPUTE mode)이 이 feed 의 첫 신호였고, V2 COMPUTE 가 O3
  에서 그 gap 을 부분 해소했다 (sigma COMPUTE n=7 PASS).

### O6 DLMF = closed-negative (패턴 비이식성)

OEIS exact-integer hash-intersect 패턴은 DLMF 로 as-is 재사용 불가 — 🔴 FALSIFIED.
2개 독립 FAIL: (P1) bulk 수치 corpus 부재(per-page MathML, API 없음) + (P3) hexa
고전 특수함수 0개. 구조 차이: OEIS `{id→정수 tuple}`(exact-hashable) vs DLMF
`{id→기호 항등식 OR 연속함수 f}`(tuple 해시 불가). 배제된 축 = "패턴 이식성".
상세 = `OEIS/docs/o6-dlmf-feasibility.md`.

### 7 중 5 가 mostly-attribution

O4 의 7 atlas-link 중 5(sigma/tau/phi/mu @P + sigma_0 alias)는 이미 atlas 에 present
한 @P 빌트인이다. O7 의 가치는 node 수가 아니라 **검증된 provenance link** —
순수-신규 fold 는 3(aliquot/sigma_2/sigma_3)뿐. catalogue-mirror 는 hexa 가 이미
가진 NT-fn 을 OEIS canonical-source 에 묶는 reference lane 이지, atlas 확장 엔진이 아니다.

---

## §4 · unique pattern 후보 (paper-gate eval 전 inventory)

| # | 후보 | 측정/근거 | terminal? |
|---|------|-----------|-----------|
| (a) | A000926 Idoneal ↔ `n` 우연 | 첫 10항 `1..10` 일치, term≤20 divergence (k20=no). clean first-K-coincidence exemplar. **단일 anecdote.** | 🟢 (1 데이터점) |
| (b) | **78% coincidence rate** | 374K sweep 1,707 K=10 hit 중 1,334(78.1%) 가 K=20 에서 collapse. O1 에 falsifier pre-registered. | 🔴 closed-negative (axis) |
| (c) | sibling-locus n·φ(n)=σ(n) ⟺ n∈{1,6} (A002618, F3) | hand-sweep **n=1..8 만**, 전칭 ⟺ 닫힌형 **미증명**. M1 σφ=nτ ⟺ {1,6} 의 독립 witness 이나 uniqueness unproven. | 🟡/🟠 (uniqueness 미증명) |

---

## §5 · paper-gate eval (paper_significance · STRICT)

`paper_significance` 게이트 = **pre-registered falsifier + real measurement + finding
(Δ vs baseline OR 닫힌-부정으로 한 축 결정적 배제)**. `paper_gate` = terminal verdict 만
(🔵/🟢/🔴-negative; 🟡/🟠/⚪ 불가). `paper_negative_ok` = closed-negative 도 publishable.

### 후보별 게이트 통과 여부

- **(a) A000926** — real measurement ✓, 그러나 단일 데이터점 illustration. A000926
  전용 pre-registered falsifier 는 없고(O1 의 "11항부터 diverge 예상" 은 (b)의 일부),
  finding=Δ 도 ruled-out-axis 도 아니다. **게이트 미달 — anecdote**.
- **(c) sibling-locus** — uniqueness ⟺ 가 **미증명**(F3 ledger: hand-sweep n=1..8,
  general closed-form 없음). `paper_gate` terminal 요건 위반(🟡/🟠), `claim_verify`
  over-claim 금지. §4 표의 "⟺" 는 F3 가 실제 입증한 것보다 강한 표현 —
  honest 표기는 "n=1..8 finite witness". **게이트 미달 — non-terminal**.
- **(b) 78% coincidence rate** — **게이트 통과 (TRIGGER)**:
  - **pre-registered falsifier (O1)**: scanner POC 가 `n↔A000926` hit 를 등록하며
    명시적으로 *"first 10 terms coincide; 11번째부터 diverge 예상; O3 verify 단계
    falsifier"* 라고 기록. 즉 가설 **H: "K=10 prefix-match ⟹ sequence identity"** 를
    O1 에서 pre-register 했다. (retroactive 가 아니라 O1 ledger 에 실재.)
  - **real measurement (O2)**: 374,047 seq full sweep. 1,707 K=10 hit 중 1,334 가
    K=20 에서 divergence → **78.1% (전 hit 대비)** / **79.9% (≥20항 disprovable 1,670 대비)**.
  - **finding = 닫힌-부정 (axis ruled out)**: H 가 ~78% 비율로 **FALSIFIED**. 배제된
    축 = *"K=10(짧은 prefix) tuple-match 를 sequence-identity 판정자로 쓸 수 있다"*.
    결정적으로 배제됨 — K=10 매치의 약 4/5 가 거짓양성. 이것이 `paper_negative_ok`
    가 명시하는 "한 path 를 결정적으로 ruling out 하는 🔴" 이다.

### 솔직 caveat (over-claim 방지, paper §finding 에 명시 필수)

78% 는 **보편상수가 아니다**. (1) candidate-fn 집합이 20개 simple NT/poly fn 으로
편향 — coincidence 의 대부분이 `n`(190)·`prime`(67)·`odd`·`triangular` 등 저-엔트로피
prefix. 따라서 "이 candidate 집합에 대한 78%" 이지 "전 OEIS prefix-collision 의 78%"
가 아니다. (2) 측정값은 K=10→K=20 한 쌍의 prefix 길이에 대한 것 — K 의존성은 미-sweep.
paper 는 이 둘을 §finding 에서 명시 한정해야 하며, 그러지 않으면 `paper_violation`.

### O8 권고: **TRIGGER**

(b) 가 `paper_significance` 3요건(pre-registered falsifier + real measurement +
closed-negative axis)을 모두 충족 + `paper_negative_ok` 에 부합 + `paper_on_discovery`
("every terminal discovery → its own paper"). modest 하지만 honest 한 publishable
closed-negative.

**O8 paper spec (다음 라운드):**

- **slug**: `oeis-prefix-collision-falsifier` (finding 으로 명명, 고정 도메인 bucket 아님)
- **§statement (pre-registered falsifier)**: H = "K=10 정수-tuple prefix-match ⟹
  OEIS sequence identity". O1 scanner POC 에서 A000926↔n 를 falsifier 후보로 pre-register.
- **§method**: 374K stripped.gz full sweep, K=10 hash-intersect → K=20 verbatim 2-pass.
  20 candidate hexa NT/poly fn (편향 명시).
- **§verification**: `.verdicts/oeis-full-sweep/ledger.json` (1707/336/1334/37) +
  hits.tsv (A000926 row = `n  A000926  1..10  no`).
- **§finding (closed-negative)**: H FALSIFIED — 1,334/1,707 = **78.1%** (혹은
  1,334/1,670 = 79.9% disprovable) 가 first-K artifact. 배제된 축 = short-prefix
  tuple-match-as-identity-test. **caveat**: candidate-set-relative + single (K=10→20) pair.
- **commons g51**: ≥10 page + ≥1 fal.ai figure (funnel diagram + coincidence histogram).

---

## 부록 · 증거 trail

- `.verdicts/oeis-full-sweep/ledger.json` · `hits.tsv` · `sweep_log.txt` (O2, 374K)
- `.verdicts/oeis-perhit-verify/tier_ledger.txt` (O3, 336 tier)
- `.verdicts/oeis-atlas-fold/fold_ledger.txt` (O4, 7 link)
- `.verdicts/oeis-tecs-crosslink/crosslink.txt` (O5, reuse edge)
- `OEIS/docs/o6-dlmf-feasibility.md` (O6, 🔴)
- `.verdicts/oeis-closure/closure_report.txt` (O7, 본 리포트 ASCII summary + paper-gate verdict)
- O1 falsifier pre-registration: `CLAIMS.tape` slug=oeis-scanner-poc + OEIS.log.md (2026-05-25)
