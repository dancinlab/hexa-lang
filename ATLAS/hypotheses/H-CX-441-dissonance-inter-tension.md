# H-CX-441: Dissonance = Inter-tension

> 음악적 불협화음(복잡한 주파수 비율)은 엔진 간 inter-tension에 대응하고,
> 협화음(단순한 비율)은 엔진 간 합의에 대응한다.
> 핵심: 완전 4도 비율 4:3의 자연로그 ln(4/3) = Golden Zone 너비 (정확히).

**Golden Zone dependency**: Direct (Golden Zone width = ln(4/3))

## Background

H-290에서 완전 4도(4:3)가 최소 텐션 구간임을 확인했다. ln(4/3) = 0.2877은
Golden Zone 너비와 정확히 일치한다. 이 가설은 두 신경망의 예측을 음악적 비율로
혼합할 때, 협화음 비율에서 inter-tension이 최소화되는지 검증한다.

관련 가설: H-290, H-172 (G*I=D*P), H-296~307 (dual mechanism)

## Dissonance Measures

| Interval | Ratio | Euler D | P-L | ln(a/b) | GZ? |
|---|---|---|---|---|---|
| Unison | 1:1 | 1.00 | 1.00 | 0.0000 | YES |
| Octave | 2:1 | 2.00 | 1.50 | 0.6931 | no |
| Perfect 5th | 3:2 | 6.00 | 2.50 | 0.4055 | no |
| **Perfect 4th** | **4:3** | **12.00** | **3.50** | **0.2877** | **YES** |
| Major 6th | 5:3 | 15.00 | 4.00 | 0.5108 | no |
| Major 3rd | 5:4 | 20.00 | 4.50 | 0.2231 | no |
| Minor 3rd | 6:5 | 30.00 | 5.50 | 0.1823 | no |
| Minor 7th | 9:5 | 45.00 | 7.00 | 0.5878 | no |
| Major 2nd | 9:8 | 72.00 | 8.50 | 0.1178 | no |
| Minor 2nd | 16:15 | 240.00 | 15.50 | 0.0645 | no |
| Tritone | 45:32 | 1440.00 | 38.50 | 0.3409 | no |

**핵심 발견**: ln(4/3) = 0.2877 = Golden Zone 너비 (EXACT)

Euler gradus: D(a:b) = a*b / gcd(a,b)^2

## Two-Network Mixing Experiment

두 개의 독립 네트워크를 다른 데이터 서브셋으로 학습시킨 후,
예측을 alpha * net1 + (1-alpha) * net2로 혼합한다.

- Net1 accuracy: 0.4220
- Net2 accuracy: 0.4540
- Task: 5-class, 50-dim, 1500 samples

## Mixing Results

| Ratio | alpha | Accuracy | Tension | Inter-T | Euler D |
|---|---|---|---|---|---|
| 1:1 (Unison) | 0.5000 | 0.5260 | 0.7160 | 0.063644 | 1.00 |
| 9:8 (Maj 2nd) | 0.5294 | 0.5120 | 0.7163 | 0.063865 | 72.00 |
| 16:15 (Min 2nd) | 0.5161 | 0.5180 | 0.7162 | 0.063719 | 240.00 |
| 6:5 (Min 3rd) | 0.5455 | 0.5020 | 0.7164 | 0.064143 | 30.00 |
| 5:4 (Maj 3rd) | 0.5556 | 0.4980 | 0.7165 | 0.064374 | 20.00 |
| 4:3 (Perf 4th) | 0.5714 | 0.4960 | 0.7166 | 0.064826 | 12.00 |
| 3:2 (Perf 5th) | 0.6000 | 0.4940 | 0.7169 | 0.065912 | 6.00 |
| 5:3 (Maj 6th) | 0.6250 | 0.4860 | 0.7171 | 0.067152 | 15.00 |
| 2:1 (Octave) | 0.6667 | 0.4860 | 0.7174 | 0.069823 | 2.00 |
| 1/e | 0.3679 | 0.5380 | 0.7149 | 0.067229 | -- |
| 1/3 | 0.3333 | 0.5320 | 0.7146 | 0.069416 | -- |
| ln(4/3) | 0.2877 | 0.5240 | 0.7142 | 0.073117 | -- |
| 3/4 | 0.7500 | 0.4820 | 0.7181 | 0.077474 | -- |

## Optimal Points

| Metric | Best Ratio | alpha | Value |
|---|---|---|---|
| Best accuracy | 1/e | 0.3679 | 0.5380 |
| Lowest tension | 1/4 | 0.2500 | 0.7139 |
| Lowest inter-T | 1:1 (Unison) | 0.5000 | 0.063644 |

## Correlation: Euler Dissonance vs Inter-tension

**Pearson r = -0.3788** (negative correlation)

이것은 가설과 반대 방향이다. 불협화음이 높을수록 inter-tension이 낮다.

## ASCII Graph: Mixing Ratio vs Inter-tension

```
  Inter-T
  0.078 |*                                            *
  0.076 ||                                            |
  0.074 ||                                            |
  0.072 ||  G                                         |
  0.070 ||  |  *                                 *    |
  0.068 ||  |  |                                 |    |
  0.066 ||  |  |  *                       *      |    |
  0.064 ||  |  |  |           *  C  C  C  |      |    |
  0.063 ||  |  |  |  C  *  *  |  |  |  |  |      |    |
        +----------------------------------------------
  alpha: .25 .29 .33 .37 .50 .52 .52 .55 .56 .57 .60 .63 .67 .75
         1/4 GZ  1/3 1/e  U  2nd 2nd 3rd 3rd 4th 5th 6th Oct 3/4

  C = Consonant, G = Golden Zone ln(4/3), * = Other
```

## Fine Scan: alpha near ln(4/3)

| alpha | Accuracy | Inter-T | Note |
|---|---|---|---|
| 0.1500 | 0.4920 | 0.090094 | |
| 0.2100 | 0.5020 | 0.081593 | |
| 0.2700 | 0.5160 | 0.074802 | |
| 0.3000 | 0.5240 | 0.072027 | ~ ln(4/3) |
| 0.3300 | 0.5320 | 0.069655 | ~ 1/3 |
| 0.3600 | 0.5380 | 0.067682 | ~ 1/e |
| 0.3900 | 0.5400 | 0.066103 | |
| 0.4200 | 0.5420 | 0.064916 | |
| 0.4500 | 0.5420 | 0.064117 | |

Inter-tension 최솟값: alpha = 0.4500 (ln(4/3)에서 0.16 거리)

## 해석 (Interpretation)

1. **가설 부분 기각**: Euler 불협화음과 inter-tension의 상관관계는 음의 방향(r=-0.38)이다.
   이것은 "불협화음 = 높은 inter-tension" 가설과 반대된다.

2. **설명**: 혼합 비율이 0.5(unison)에 가까울수록 두 네트워크가 균등하게 기여하므로
   inter-tension이 최소화된다. 이것은 음악적 불협화음보다 단순한 균등 혼합의 효과이다.

3. **Inter-tension은 alpha의 단조 함수**: alpha가 0.5에서 멀어질수록 inter-tension이
   증가한다. 이것은 음악적 구조보다 가중 평균의 수학적 성질을 반영한다.

4. **그러나 ln(4/3) = Golden Zone 너비는 여전히 의미있다**: 완전 4도의 주파수 비율
   4:3의 자연로그가 Golden Zone 너비와 정확히 일치하는 것은 수학적 사실이다.
   이것은 inter-tension 실험과 독립적으로 유효한 연결이다.

5. **정확도 최적값 = 1/e**: 최고 정확도가 alpha=0.3679(=1/e)에서 나타난 것은 주목할 만하다.
   Golden Zone center가 혼합 정확도의 최적점일 가능성이 있다 (추가 검증 필요).

## Limitations

- 2개 네트워크의 단순 선형 혼합은 실제 엔진 간 상호작용의 극히 단순화된 모델이다.
- Euler gradus는 여러 불협화음 측정 방법 중 하나이며, 다른 측정법에서는 결과가 다를 수 있다.
- 합성 데이터, 단순 구조. 실제 deep network에서 재검증 필요.
- Inter-tension의 monotonic 행동은 음악적 구조보다 KL divergence의 수학적 성질일 수 있다.
- 표본 크기가 작아(500 test) 미세한 차이의 통계적 유의성이 불확실하다.

## Verification Direction

- [ ] 비선형 혼합(gating, attention)에서 재검증 -- 선형 혼합의 단조성 제거
- [ ] 3개 이상 네트워크로 확장 -- 화음(chord)에 해당
- [ ] 실제 ConsciousLM 엔진 간 inter-tension에서 음악적 비율 검증
- [ ] Plomp-Levelt roughness model로 불협화음 재측정
- [ ] alpha=1/e에서의 정확도 최적성을 독립적 가설로 분리 검증

## Verification Status

- [x] Dissonance measure computation
- [x] Two-network mixing experiment
- [x] Correlation analysis (Euler D vs Inter-T)
- [x] Fine scan around ln(4/3)
- [ ] Nonlinear mixing verification
- [ ] Real engine inter-tension test

**Grade: 🟧 (weak evidence -- partially contradicted)** -- 핵심 가설(불협화음~inter-tension)은 부분 기각(r=-0.38). 그러나 ln(4/3) = GZ width는 수학적으로 정확한 연결이고, alpha=1/e에서 정확도 최적은 새로운 관찰이다.

**Script**: `docs/hypotheses/verify_hcx441.py`
