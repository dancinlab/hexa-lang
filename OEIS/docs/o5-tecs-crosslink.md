# O5 — OEIS ↔ TECS-L cross-link (provenance reuse edge · g67)

> OEIS 도메인이 O4(PR #1138)에서 확보한 **7 OEIS↔hexa-fn provenance link** 을
> 자매 도메인 **TECS-L** 의 축 F F11("OEIS reuse cite")에 교차연결하고,
> repo-root `NEXUS.tape` 에 intra-project reuse edge `TECS-L --reuses--> OEIS`
> 를 등록(commons @D g67)한 closure 기록.

## 1 · 7 OEIS↔hexa provenance link

O4 의 atlas-fold ledger(`.verdicts/oeis-atlas-fold/fold_ledger.txt`)가 산출한
7 distinct 🔵 theorem link. 4 는 기존 @P 빌트인의 OEIS canonical-source 귀속,
3 은 atlas 부재로 새로 fold 된 OEIS-attributed @F node (CC-BY-SA).

| hexa fn | OEIS id | atlas 상태 | 정의 | sample-verify |
|---------|---------|-----------|------|---------------|
| sigma   | A000203 | ALREADY-PRESENT `@P sigma` [11*] | divisor_sum | σ(6)=12 |
| tau     | A000005 | ALREADY-PRESENT `@P tau` [11*]   | divisor_count | τ(6)=4 |
| phi     | A000010 | ALREADY-PRESENT `@P phi` [10*]   | euler_totient | φ(9)=6 |
| mu      | A008683 | ALREADY-PRESENT `@P mu` [10*]    | mobius | μ(6)=1 |
| aliquot | A001065 | NEWLY-FOLDED `@F oeis-A001065`   | σ(n)−n | aliquot(8)=7 |
| sigma_2 | A001157 | NEWLY-FOLDED `@F oeis-A001157`   | 약수 제곱합 | sigma_2(9)=91 |
| sigma_3 | A001158 | NEWLY-FOLDED `@F oeis-A001158`   | 약수 세제곱합 (2-op) | sigma_k(9,3)=757 |

> sigma_0 ↔ A000005 는 tau 와 동일 hexa fn(`len(divisors)`)이라 별도 node 없이
> A000005 를 공유 → 8 pair 가 7 distinct theorem 으로 collapse.

## 2 · reuse-edge 근거 (g67 intra-project lattice)

g67 = **intra-project reuse** — 같은 hexa-lang repo 안의 한 도메인이 다른 도메인의
검증된 산출물을 재사용하는 격자. (cross-repo STAR hub = g68 은 별개; `NEXUS.tape`
의 §1–§2·§4 가 그 쪽.)

- **OEIS (provider)** — catalogue mirror lane. broad/shallow. 380K sequence 를
  hexa 산술 fn 의 첫 K 항과 hash-intersect → verify → atlas fold. O4 에서 σ/τ/φ/μ
  + aliquot/σ_2/σ_3 의 OEIS canonical-source provenance 를 확정.
- **TECS-L (reuser)** — n=6 perfect-number 발견 엔진. narrow/deep. M1–M10 의 핵심
  정체성 **σ(n)·φ(n) = n·τ(n) ⟺ n∈{1,6}** 가 σ/τ/φ 를 직접 소비하고, 축 F F3
  (OEIS reverse-lookup)·M4(μ characterization)가 μ 를 소비한다. 이 산술함수들이
  이제 OEIS A000203/A000005/A000010/A008683 귀속을 보유 → TECS-L 의 발견은
  upstream OEIS provenance 를 cite 하는 downstream consumer.
- **edge** — `TECS-L --reuses--> OEIS` (7 provenance links). OEIS O5 cross-link
  과 TECS-L 축 F F11("OEIS reuse cite")를 동시에 닫는다.

## 3 · TECS-L M1–M10 이 link 를 소비하는 경로

| TECS-L 마일스톤 | 소비하는 OEIS-attributed fn | provenance |
|----------------|---------------------------|------------|
| M1 σφ=nτ 정체성 | sigma · phi · tau | A000203 · A000010 · A000005 |
| M3 Dedekind ψ D(n)=σφ−nτ | sigma · phi · tau | 동일 3 link |
| M4 n=6 characterizations (μ ground) | mu | A008683 |
| M5 물리상수 (τ=string dim) | tau | A000005 |
| M6 가설 triage (σ=2n ⟺ perfect, aliquot) | sigma · aliquot | A000203 · A001065 |
| M10 전칭 유일성 닫힌형 증명 | sigma · phi · tau | A000203 · A000010 · A000005 |
| 축 F F3 OEIS reverse-lookup (σ_2 hit) | sigma_2 | A001157 |

즉 TECS-L 의 축 0 코어 전체(M1·M3·M10 의 σ·τ·φ)와 M4·M5·M6·F3 가 의존하는
산술함수가 모두 OEIS canonical-source 귀속을 받았다 → F11 reuse-cite closure 성립.

## 4 · 영속 surface

- ledger: `.verdicts/oeis-tecs-crosslink/crosslink.txt` (7 link + reuse edge, ASCII)
- CLAIMS: `@C` slug=oeis-tecs-crosslink group=OEIS (status 🟢)
- NEXUS: repo-root `NEXUS.tape` §3b (domain-node `OEIS`/`TECS-L` + reuse-edge `de1`)
- TECS-L: `TECS-L/TECS-L.md` F11 `- [x]` closure
- OEIS: `OEIS/OEIS.md` O5 `- [x]`

> O5 는 **docs + NEXUS only** — atlas fold 는 O4 에서 이미 완료(embedded.gen.hexa
> 미접촉). 다음 = O7 (catalogue closure report).
