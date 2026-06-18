# Hypothesis H-CX-436: Grammar Recursion Depth = sigma\_-1(6) = 2
**n6 Grade: 🟧 CLOSE** (auto-graded, 4 unique n=6 constants)


## Hypothesis

> The human center-embedding depth limit of approximately 2 corresponds to sigma\_-1(6) = 2 (the sum of reciprocals of divisors of perfect number 6). This cognitive constraint reflects the perfect number structure in information processing.

## Background / Context

Center-embedding is a syntactic construction where a clause is embedded inside another clause: "The dog [the cat [the rat bit] chased] died." Psycholinguistic research consistently shows humans can process depth 1-2 but fail catastrophically at depth 3+. This is one of the most robust universals in cognitive linguistics.

sigma\_-1(6) = 1/1 + 1/2 + 1/3 + 1/6 = 2, which is the defining property of perfect numbers (sigma\_-1(n) = 2 iff n is perfect). If this value constrains recursion depth, it connects number theory to cognitive architecture.

Related hypotheses: H-090 (Master formula = perfect number 6), H-172 (G*I=D*P conservation), H-098 (unique sigma\_-1 property).

Golden Zone dependency: YES (interprets sigma\_-1(6) through the G=D*P/I model).

## Verification Script

`calc/h_cx_436_recursion.py` -- Stack-based bracket matcher + cross-linguistic data + statistical test.

## Literature Survey: Center-Embedding Limits

| Study | Critical Depth | Method |
|---|---|---|
| Gibson 1998 | 2 | Reading time measurement |
| Miller & Isard 1964 | 2 | Comprehension accuracy |
| Karlsson 2007 (written) | 3 | Corpus analysis |
| Karlsson 2007 (spoken) | 2 | Corpus analysis |
| Bach et al 1986 | 2 | Grammaticality judgment |
| **Mean** | **2.2** | |
| **sigma\_-1(6)** | **2.0** | |

## Model Verification: Bracket Matching Accuracy

Stack-based model with finite capacity tested on nested bracket sequences:

| Depth | cap=1 | cap=2 | cap=3 | cap=4 | cap=5 | cap=6 | Random |
|---|---|---|---|---|---|---|---|
| 1 | 50% | 50% | 50% | 50% | 50% | 50% | 50% |
| 2 | 50% | 100% | 100% | 100% | 100% | 100% | 50% |
| 3 | 52% | 51% | 100% | 100% | 100% | 100% | 50% |
| 4 | 51% | 51% | 53% | 100% | 100% | 100% | 50% |
| 5 | 50% | 50% | 51% | 49% | 100% | 100% | 50% |
| 6 | 52% | 49% | 49% | 50% | 49% | 100% | 50% |
| 7 | 51% | 50% | 51% | 51% | 49% | 51% | 50% |

**Pattern**: Model with capacity K achieves 100% at depth <= K, drops to chance at depth > K.
Capacity=2 (=sigma\_-1(6)) processes depth 2 perfectly, fails at depth 3.

## ASCII Graph: Accuracy vs Embedding Depth

```
  Accuracy
  100% |      2  3  4  5  6           cap=K handles depth<=K
       |      |  |  |  |  |
       |      |  |  |  |  |
   75% |------+--+--+--+--+---------- threshold
       |      |  |  |  |  |
   50% |--1---1--1--1--1--1--1------- chance level
       |
   25% |
       |
    0% +--+--+--+--+--+--+--
          1  2  3  4  5  6  7
                Embedding Depth

  Legend: numbers 1-6 = model capacity (stack size)
  At depth D, only models with capacity >= D achieve 100%
  Human limit at depth 2 implies capacity = 2 = sigma_-1(6)
```

## Cross-Linguistic Parse Tree Data

| Language | Mean Depth | Max Common | Embedding Limit |
|---|---|---|---|
| English | 4.2 | 7 | 2 |
| German | 4.5 | 8 | 2 |
| Japanese | 3.8 | 6 | 2 |
| Chinese | 3.5 | 6 | 2 |
| Turkish | 3.3 | 5 | 1 |
| Finnish | 4.0 | 7 | 2 |
| Arabic | 4.1 | 7 | 2 |
| Korean | 3.6 | 6 | 2 |
| **Mean** | **3.88** | | **1.88** |
| **Target** | **tau(6)=4** | | **sigma\_-1(6)=2** |

Mean embedding limit = 1.88, close to sigma\_-1(6) = 2.
Mean tree depth = 3.88, close to tau(6) = 4.

## Working Memory: Miller's 7+/-2

| Formula | Value | = 7? | Ad hoc? |
|---|---|---|---|
| sigma(6) - tau(6) - 1 | 7 | YES | contains -1 |
| sigma(6) / sigma\_-1(6) + 1 | 7 | YES | contains +1 |
| n + 1 | 7 | YES | trivial |
| 2^(sigma\_-1(6)+1) - 1 | 7 | YES | contains -1 |

Miller's 7 = n+1 = 7 is the simplest formula but trivially available for any n.

## Generalization to Perfect Number 28

```
  sigma_-1(28) = 1 + 1/2 + 1/4 + 1/7 + 1/14 + 1/28 = 2.0000
  sigma_-1(6) = 2.0000

  sigma_-1(n) = 2 for ALL perfect numbers (by definition!)
  → "depth = 2 = sigma_-1(perfect number)" is a tautology
  → Generalizes perfectly -- but because perfect numbers are DEFINED this way
```

## Texas Sharpshooter Test

| Claim | Match | Evidence Quality |
|---|---|---|
| Center-embedding limit = 2 | YES | Strong (well-documented) |
| sigma\_-1(6) = 2 | YES | Exact (by definition) |
| Mean tree depth ~ 4 = tau(6) | YES | Weak (approximate) |
| Miller's 7 = n+1 | YES | Trivial (n+1 always available) |

```
  Core non-trivial match: embedding depth 2 = sigma_-1(6) = 2
  p-value: depth could be 1,2,3,4,5 → P(match) = 1/5 = 0.20
  With 5 functions tried: P(at least one) = 1 - (4/5)^5 = 0.672
  → Not statistically significant after correction
```

## 해석 (Interpretation)

중심 매립(center-embedding) 깊이 한계 2는 심리언어학에서 가장 잘 확립된 보편 법칙 중 하나이다. 이 값이 sigma\_-1(6) = 2와 정확히 일치하는 것은 흥미롭다.

**강점**: 일치가 정확하고 (2 = 2), 범언어적 보편 법칙이며, 스택 모델에서 capacity=2가 depth 3에서 실패함을 확인했다. 또한 sigma\_-1(n)=2는 완전수의 정의적 성질이므로, "깊이 = 2"가 모든 완전수에 대해 일반화된다.

**약점**: 그러나 이 일반화는 순환적이다 -- 완전수가 sigma\_-1=2로 정의되기 때문이다. 또한 숫자 2는 이진 분류, 쌍, 좌/우 등 어디에나 나타나므로, 2와의 일치는 통계적으로 놀랍지 않다. Texas Sharpshooter 보정 후 p-value = 0.672로 유의하지 않다.

mean tree depth ~ 4 = tau(6)는 약한 근사 일치이며, Miller의 7 = n+1은 모든 n에 대해 성립하는 사소한 관계이다.

**핵심 질문**: 인간의 재귀 깊이 한계가 왜 정확히 2인가? 이것이 완전수 6의 sigma\_-1과 연결되는 인과적 메커니즘이 있다면, 이 가설은 강력해진다. 그러나 현재로서는 사후적 매칭(post-hoc matching)에 불과하다.

## Limitations

1. sigma\_-1(6)=2는 완전수의 정의이므로 일반화 테스트가 순환적이다
2. 숫자 2는 너무 흔해서 일치가 놀랍지 않다 (p = 0.20 before correction)
3. Texas Sharpshooter 보정 후 유의하지 않다 (p = 0.672)
4. 인과 메커니즘 없음: 왜 완전수가 인지 능력을 결정하는가?
5. 스택 모델은 지나치게 단순하다 -- 실제 파싱은 더 복잡한 메커니즘을 사용한다
6. Turkish의 embedding limit = 1은 보편 법칙의 예외이다

## Verification Direction

1. LLM(GPT, Llama 등)의 center-embedding 정확도를 depth별로 측정
2. fMRI/EEG로 depth 2 vs 3 처리 시 뇌 활동 차이 분석
3. 아동 언어 발달에서 재귀 깊이가 2에 수렴하는 시점 조사
4. 수화(sign language)에서도 동일한 깊이 한계가 존재하는지 확인
5. 음악의 재귀 구조 (harmonics, nested phrases)에서 깊이 한계 측정
6. 프로그래밍 언어 사용자의 중첩 괄호 이해 한계 실험

## Grade

**Grade: Interesting structural match, high post-hoc risk**

depth = 2 = sigma\_-1(6) 일치는 실제적이지만, 2라는 숫자가 너무 흔하고, 완전수 정의와의 연결이 순환적이며, 통계적으로 유의하지 않다. 인과 메커니즘이 제시되기 전까지는 관찰적 일치로 분류한다.
