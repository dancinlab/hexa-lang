# Fused Flash-Attention 차원-분해 스윕 (Round 5) — KV-Split 가설 검증

- **Falsifier**: F-FUSION-ATTN-DECOMP-WALL
- **호스트**: ubu-2 RTX 5070 (sm_120, 48 SM, 12GB) — clean(0% util, 0 compute procs), $0, LOCAL
- **방법**: CUDA-C `nvcuda::wmma` flash-decoding 오라클 (2-커널: partial + LSE-merge), cuEvent 20 warmup + 200 timed median, 수치 게이트 rel_rowscale ≤ 1e-2 vs f64 CPU ref
- **스윕 규모**: 153 config (N×Bq×kv_split×BK) — **전부 numeric PASS**
- **결과**: ⚠ **ORANGE → 닫힌-부정(closed-negative)** — KV-split는 small-N occupancy gap을 *닫지만*, cuBLAS를 못 이김. cuBLAS huge-tile GEMM 벽은 분해로 안 뚫림.

## 차원 분해 매트릭스 (펼침 — 논리축 → 물리 grid)

| 축 | 의미 | 값 | 물리 매핑 |
|----|------|-----|-----------|
| D1 Bq | query-block tile | {16, 32, 64} | gridDim.x = N/Bq, CTA당 Bq/16 서브타일 직렬 (1 warp/CTA) |
| **D2 kv_split** | **KV-split (flash-decoding) — 우선축** | **{1, 2, 4, 8, 16}** | **gridDim.z, partial-O + LSE merge 2-pass** |
| D3 BK | CTA 내 KV tile 폭 | {64, 128, 256} | online-softmax 라운드당 KV 서브타일 수 |
| N | 시퀀스 길이 | {512, 1024, 2048, 4096} | d=64 단일헤드 (round-4 baseline) |

> kv_split=1은 round-4 알고리즘과 **정확히 일치**(max_abs 4.02796e-05 동일). 단 2-pass 구조는 partial-O HBM 왕복 + 2번째 launch 세금이 추가됨(round-4 single-kernel은 회피). 분해 *추세*는 일관된 2-pass 프레임 안에서 격리 측정, 절대 비교는 round-4 single-kernel 대비도 병기.

## 형태별 최적 config + KV-split 효과

| N | cuBLAS-TC ms | 최적 config (Bq·kv·BK) | fused ms | ratio×cuBLAS | occ CTAs | kv=1 baseline(occ) | intra KV-split 가속 | round-4 single-kernel ms (ratio) |
|---|---|---|---|---|---|---|---|---|
| 512  | 0.01661 | Bq16 · **kv4** · BK128 | 0.0576 | **3.47×** | 128 | 0.1458 (32) | **2.53×** | 0.0568 (3.42×) |
| 1024 | 0.03066 | Bq32 · kv4 · BK256 | 0.1804 | 5.88× | 128 | 0.2822 (64) | 1.56× | 0.1155 (3.77×) |
| 2048 | 0.06170 | Bq64 · kv4 · BK256 | 0.6675 | 10.82× | 128 | 0.6699 (128) | 1.00× | 0.2452 (3.97×) |
| 4096 | 0.18867 | Bq16 · kv8 · BK256 | 2.4850 | 13.17× | 2048 | 2.6251 (256) | 1.06× | 0.9572 (5.07×) |

## KV-split의 small-N occupancy gap 폐쇄 (N=512, Bq=16) — 핵심 검증

| kv_split | occ CTAs (vs 48 SM) | fused ms | ratio×cuBLAS |
|---|---|---|---|
| 1  | 32 (under-occupied) | 0.1458 | 8.78× |
| 2  | 64 | 0.0844 | 5.08× |
| **4** | **128** | **0.0576** | **3.47×** |
| 8  | 256 (over-subscribed) | 0.0700 | 회귀 |
| 16 | 512 | 0.0925 | 회귀 |

→ **N=512: 32 → 128 CTA, 0.146 → 0.058 ms (2.53× 가속). 사용자 가설 CONFIRMED.** 2-pass 세금에도 round-4 single-kernel(0.0568)과 동률 도달.

## 패턴 관찰 (g63 honest)

1. **KV-split는 under-occupied(small-N) 전용 레버**다. occ < 48 SM일 때만 이득. ctas_partial ≥ ~48에서 포화(N=512는 kv=4=128 CTA에서 plateau, kv=8/16은 merge + over-subscription으로 회귀).
2. **N≥2048는 N/Bq만으로 이미 grid 포화** → KV-split는 occupancy 이득 없이 partial-O HBM 세금만 추가. decomp-best 0.668ms vs round-4 single-kernel 0.245ms (@N=2048, 2.7× 더 느림). HBM partial 비용은 O(N·split·d)로 증가.
3. **BK=256가 모든 (N,Bq,kv) 고정 내에서 최적** — round-4 발견 재확인 (N=512 kv=1: BK64 0.156 → BK256 0.146, softmax amortize).
4. **Bq>16은 일률적으로 더 느림** — grid 수를 깎아서 small-N이 필요로 하는 것의 정반대. Bq=16이 small-N 지배.
5. **softmax-overhead floor**: 최대 occupancy에서도 per-16×16-tile online-softmax가 fused path를 cuBLAS huge-tile GEMM 대비 ~3.4× 위로 고정. round-4 binding constraint 재확인, 미돌파.

## 갭-폐쇄 궤적

```
round-3  : 9.4 - 15.5x  (1-warp/CTA, 16-key softmax)
round-4  : 3.4 - 5.0x   (wide-KV BK=256 single-kernel, CUDA-C floor 1.3-2.0x)
round-5  : 3.47x @ N=512 (KV-split occupancy 폐쇄로 small-N에서 round-4와 동률,
           단 large-N은 HBM partial 세금으로 회귀; cuBLAS 미돌파)
```

## 판정 (g3 honest)

- **WIN(≥30%, ratio≤0.70)? NO.** best ratio = 3.47× (N=512). 🟢 불성립.
- **🟠 → 닫힌-부정**: *어떤 차원 분해도 hand-PTX flash-attn으로 cuBLAS를 못 이긴다.* KV-split는 occupancy↔HBM-traffic을 맞바꿀 뿐(small-N net-neutral, large-N net-negative). GEMM-tile-efficiency 벽(round-4)이 fundamental임을 분해 축에서 결정적으로 확인.
- section10 box 미변경(flip 없음). codegen 무변경(f1/f2 보존, .cu는 오라클 only).

자세한 per-config 표 + 분석 = `ledger.json`.
