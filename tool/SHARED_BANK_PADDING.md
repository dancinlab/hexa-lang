# `@shared` bank-conflict-free padding 가이드

A6 milestone — 32-way bank conflict 패턴과 해결 방법.

## 32-way bank conflict 란

NVIDIA GPU shared memory는 32개 bank로 나뉘어 있음. 한 warp(32 thread)가 동시에 shared memory를 access하면 thread `i` 가 bank `i % 32` 를 쓴다. 만약 **모든 thread가 같은 bank** 를 hit하면 access는 32× 직렬화됨 (32-way conflict).

## 발생 패턴

f64 (8 byte) 기준 `[f64; 32]` 행렬 column-major 접근에서 발생:

```
shared:  sm[ROW][COL]  flat: sm[ROW * 32 + COL]
thread i:  reads sm[i][k] for fixed k
         = sm[i * 32 + k]
         = bank ((i * 32 + k) * 8 / 4) % 32 = bank (2*k) % 32
         → ALL threads same bank → 32× serial
```

## 해결 — pad stride to 33

```
@shared let sm: [f64; 32 * 33] = []   // 32 rows × 33 cols (pad +1)
// access: sm[row * 33 + col]    instead of sm[row * 32 + col]
```

thread `i` reads `sm[i * 33 + k] = bank ((i * 33 + k) * 2) % 32 = bank (2k + 2i) % 32` → 모든 i에 대해 다른 bank → conflict 0.

## hexa-lang 측 권고

현재 RFC 085 Step B/C/D는 `[T; N]` 의 N을 그대로 사용. **사용자가 padding을 명시** (예: `[f64; 33]` for 32-col row pad) 하면 됨. 자동 padding은 향후 cycle.

| 패턴 | 추천 선언 |
|---|---|
| 32 thread block, 8B elem (f64), column-major | `[f64; 33 * 32]` (stride 33) |
| 32 thread block, 4B elem (f32), column-major | `[f32; 33 * 32]` (stride 33) |
| Linear access (`sm[tid] = ...`) | `[T; N]` 그대로 (conflict 없음) |

## 참고

- CUDA C Programming Guide §5.3.2.5 "Shared Memory" bank conflicts
- Tree-reduce 패턴 (PR #1323 sweep_pred) 은 linear access이므로 padding 불필요
- WMMA staging area (RFC 067) 는 16B align + 자동 layout, conflict 없음
