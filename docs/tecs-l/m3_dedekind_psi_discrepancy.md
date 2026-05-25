# TECS-L M3 — Dedekind ψ discrepancy D(n)=σφ−nτ 유일성 (n=1..100 스윕)

> 도메인 SSOT: `TECS-L.md` (M3) · 로그: `TECS-L.log.md` · claim 인덱스: `CLAIMS.tape`
> (slug=`tecs-l-dedekind-psi-uniqueness` group=TECS-L) · verdict 원문:
> `.verdicts/tecs-l-dedekind-psi-uniqueness/`

## 1 · 정의

Dedekind ψ discrepancy 를 다음과 같이 정의한다 (archive-TECS-L
`math/dfs_dedekind_psi_discrepancy.py` 와 **동일** 정의):

```
D(n) = σ(n)·φ(n) − n·τ(n)
```

- σ(n) — 약수합 (sum of divisors)
- τ(n) — 약수 개수 (number of divisors)
- φ(n) — 오일러 토션트 (Euler totient)

이 도메인 M1 은 정체성 σ(n)·φ(n) = n·τ(n) 이 n∈{1,6} 에서 성립하고 n=28 에서
깨짐을 보였다. M3 은 그 잔여(전칭 유일성)를 discrepancy D(n) 로 재근거화한다 —
σφ = nτ ⟺ D(n) = 0 이므로, "유일성"은 곧 **D(n)=0 의 영점 집합**이 {1,6} 인지의
물음이다.

## 2 · 방법 (g5 — verdict 가 정본)

- σ/φ/τ 각각의 load-bearing 값은 `hexa verify --expr <fn> <n> <v>` 로 정본 재계산
  (각각 🔵 SUPPORTED-FORMAL).
- D(n) 전용 `--expr` 함수는 없다 — D(n) 은 세 검증값 위의 **정확 정수 산술**.
- n=1..100 exhaustive 스윕은 hexa-native 자체구현(`tmp_tecs_m3_sweep.hexa`)을
  `hexa build` 로 compiled 바이너리화하여 실행. load-bearing n(2·3·4·12·28·30)의
  component 는 `hexa verify --expr` 와 **component-wise 교차검증**(15/15 🔵 일치)으로
  자체 스윕이 정본과 일치함을 확인.

## 3 · 결과 — D(n) 스윕 (n=1..30 발췌)

| n | σ(n) | φ(n) | τ(n) | D(n)=σφ−nτ | 비고 |
|--:|----:|----:|----:|-----------:|------|
| 1 | 1 | 1 | 1 | **0** | ✓ {1,6} 멤버 |
| 2 | 3 | 1 | 2 | **−1** | 범위 내 유일한 음수 D |
| 3 | 4 | 2 | 2 | 2 | |
| 4 | 7 | 2 | 3 | 2 | |
| 5 | 6 | 4 | 2 | 14 | |
| 6 | 12 | 2 | 4 | **0** | ✓ {1,6} 멤버 |
| 7 | 8 | 6 | 2 | 34 | |
| 8 | 15 | 4 | 4 | 28 | |
| 12 | 28 | 4 | 6 | 40 | |
| 28 | 56 | 12 | 6 | **504** | 2nd 완전수(is_perfect=1)인데 D≠0 |
| 30 | 72 | 8 | 8 | 336 | |

> 전체 1..100 테이블 + 최종 `zeros at: 1, 6` / `zero-count(1..100)=2` 줄은
> `.verdicts/tecs-l-dedekind-psi-uniqueness/sweep_D_1_100.txt` 에 원문 보존.

## 4 · 결론

- **D(n)=0 의 영점은 n=1..100 범위에서 정확히 {1,6}** — zero-count=2.
  → 🔵 SUPPORTED-FORMAL (zeros at {1,6}) + 🔴 CLOSED-negative (그 외 전부 D(n)≠0).
- D(28)=504≠0 — 2nd 완전수에서도 D≠0 이므로 D=0 은 "완전수 성질"이 아니라
  {1,6} 전용. (M1 의 n=28 closed-negative 와 동일한 판정을 discrepancy 관점에서
  재확인.)

## 5 · 범위 (정직한 한계)

- 본 결과는 **finite exhaustive 스윕 1..100** 의 terminal 판정이다 (🔵/🔴).
- **전칭(unbounded) D(n)=0 ⟺ n∈{1,6}** 은 이 finite 스윕으로 증명되지 않는다.
  전칭 주장은 archive-TECS-L 의 해석 논증을 인용하는 🟡 SUPPORTED-BY-CITATION
  잔여로 두며 `/paper` 게이트에서 제외된다. finite 스윕을 전칭 증명으로
  over-claim 하지 않는다 (`CLAUDE.md` @D paper_significance / claim_verify).
