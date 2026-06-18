# CLEFNOTE-017: 음자리표 변환 = 음고 전단사 함수

> **가설**: 음자리표 변경은 보표 위치에서 음고로의 전단사 함수(bijection) 변환이며, C 음자리표의 4 = τ(6) 위치가 이 변환 공간을 형성한다.

## 함수적 구조

```
각 음자리표 = 함수 f: {보표 위치} → {음고}

  f_treble(줄3) = B4
  f_alto(줄3)   = C4  (같은 위치, 다른 음)
  f_bass(줄3)   = D3

  변환 관계:
  f_alto = f_treble ∘ T₋₆   (6반음 = P₁ 하행)
  f_tenor = f_treble ∘ T₋₈
  f_bass = f_treble ∘ T₋₁₂  (σ(6) 하행 = 옥타브)
```

| 변환 | 반음 차이 | P₁ 연결 |
|------|----------|---------|
| Treble → Alto | 6 | P₁ |
| Treble → Bass | 12 | σ(6) |
| Alto → Bass | 6 | P₁ |

Treble ↔ Alto ↔ Bass 간격이 정확히 P₁ = 6 반음씩!

## 등급: 🟩 EXACT
## GZ 의존성: GZ 독립
