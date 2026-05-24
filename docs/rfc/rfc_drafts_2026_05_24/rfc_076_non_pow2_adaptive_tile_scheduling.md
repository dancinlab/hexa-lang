# RFC 076 -- non-2^k shape adaptive tile scheduling (SGEMM M=384 dip)

**Status:** DRAFT -- design only. 구현 아님. 측정 데이터는 RFC 067 N201
9-shape sweep (`archive/fires/rfc067_ptma_swizzle128_2026_05_22/result.json`,
cycle 4 E 산출물) 인용. Falsifier battery 정의. 사용자 결정 (D1) 대기.

**Author session:** 2026-05-24, off origin/main HEAD.

**번호 결정:** 작업 지시는 "RFC 068" 후보였으나 068 은 이미
`docs/rfc/rfc_drafts_2026_05_20/rfc_068_mixed_precision_mir_layer.md` 로 점유됨.
사용 중 번호 = 001-075, 080-088. 첫 빈 슬롯 = **076** (이어서 077/078/079
공백). 이 RFC = **076**.

**Successor to:** RFC 067 N201 (TMA SWIZZLE_128B + mma.sync.m16n8k16 +
Hilbert d2xy). N201 은 9-shape sweep 에서 8/9 shape 가 ratio >= 0.93 이지만
**M=384 만 0.8930 으로 dip**. 본 RFC 는 그 dip 의 design 경로를 문서화한다.

**Predecessor lineage:** RFC 067 honest readout sec "Extended sweep
(9 shape, 2026-05-24)" 의 documented anti-case -- M=384 dip 은 이미 RFC 067
notes.md 에 정직하게 기록됨 (over-claim 아님). 본 RFC 는 그 anti-case 를
설계 옵션 + falsifier 로 전환한다.

**측정 정직성 (`feedback_instrument_first_methodology` · @D g3):** 본 RFC
는 design draft 다. dip 데이터는 cycle 4 E (PR #540) 의 `result.json` 을
verbatim 인용하며, 어떤 설계 옵션도 silicon 측정 전에는 ratio 개선을
주장하지 않는다. 모든 success criterion 은 ubu-1 RTX 5070 측정 가능 형태로
falsifier 화 한다.

---

## sec 1 -- 문제: M=384 ratio dip

RFC 067 N201 의 9-shape sweep (cuBLAS HGEMM vs hexa N201, ubu-1 RTX 5070
sm_120, CUDA 12.9, driver 13000) 결과:

| M=N=K | cuBLAS TFLOPS | hexa N201 TFLOPS | ratio  | hilbert_p | ctas_launched | ctas_real | live% |
|-------|---------------|------------------|--------|-----------|---------------|-----------|-------|
| 256   |  4.559        |  4.481           | 0.9829 | 4         | 16            | 16        | 100%  |
| **384** | **13.254**  | **11.836**       | **0.8930** | **8**   | **64**        | **36**    | **56.3%** |
| 448   | 15.830        | 15.524           | 0.9807 | 8         | 64            | 49        | 76.6% |
| 512   | 23.237        | 23.109           | 0.9945 | 8         | 64            | 64        | 100%  |
| 1024  | 52.245        | 48.806           | 0.9342 | 16        | 256           | 256       | 100%  |
| 2048  | 66.967        | 63.475           | 0.9479 | 32        | 1024          | 1024      | 100%  |
| 4096  | 69.685        | 67.720           | 0.9718 | 64        | 4096          | 4096      | 100%  |
| 6144  | 70.458        | 68.510           | 0.9724 | 128       | 16384         | 9216      | 56.3% |
| 8192  | 70.207        | 68.614           | 0.9773 | 128       | 16384         | 16384     | 100%  |

(전 9-shape **bit-exact**: `maxabs = 0.0`, `maxrel = 0.0`. 출처:
`result.json` shapes 배열.)

**관찰 1 -- M=384 는 sweep 최저 ratio (0.8930).** 다른 8 shape 는 모두
0.93 이상. M=384 만 89.3%.

**관찰 2 -- 2^k side 는 일관되게 ratio >= 0.93.** side 가 2의 거듭제곱인
shape (256/512/1024/2048/4096/8192) 는 모두 >= 0.9342. non-2^k side
(384/448/6144) 만 idle overhead 가 측정됨. 단 448 (ratio 0.9807) 은
회복 -- dip 은 384 에 특이적.

**관찰 3 -- M=6144 도 live% 56.3% 지만 ratio 0.9724.** 동일한 Hilbert
padding 비효율 (9216/16384) 이지만 compute-bound regime (median 6.77 ms)
이라 launch overhead 가 가려진다. M=384 는 median 9.57 us 로 launch +
epilogue 가 wall 의 큰 비중 -> idle CTA 가 직접 노출.

## sec 2 -- 근본 원인 (3복합)

cycle 4 I 진단 + `result.json` / `notes.md` 정합:

### 원인 1 -- Hilbert padding idle CTA

generator `gen_sgemm_tma_swizzle128_ptx.py` 는 CTA-swizzle 에 Hilbert
d2xy 를 쓴다. Hilbert 곡선은 `p x p` (p = 2의 거듭제곱) grid 위에서만
정의되므로:

```
gx = gy = S // 64          # tile grid 한 변
p  = next_pow2(gx)         # Hilbert 정사각 변 (2^k)
```

M=384 -> gx = 384/64 = 6 -> p = next_pow2(6) = **8** -> Hilbert grid
8x8 = 64. 실제 live tile = 6x6 = 36. **idle = 64 - 36 = 28 CTA (43.8%)**.
launch 된 64 CTA 중 28 은 prologue 에서
`@%phlb_oob bra $hilbert_oob_ret` 로 즉시 ret (live% = 36/64 = 56.3%,
`result.json` ctas_real=36 일치).

대조: M=512 -> gx=8 -> p=8 -> grid 8x8=64, live 8x8=64 -> idle 0
(live% 100%, ratio 0.9945). M=448 -> gx=7 -> p=8 -> live 7x7=49 ->
idle 15 (live% 76.6%, ratio 0.9807). idle% 가 클수록 ratio 가 떨어지는
단조 관계가 작은-shape 영역에서 관측됨 (384:43.8%→0.893, 448:23.4%→0.981,
512:0%→0.995).

### 원인 2 -- K_TILES_OUTER non-2^k loop

generator 의 K-loop 은 `K_TILES_OUTER = K // 64` 회 도는 동적 loop
(`$L_kloop` ... `@%p1 bra $L_kloop`). M=384 -> K=384 -> K_TILES_OUTER
= 6 (non-2^k). M=512 -> 8 (2^k). 6-iteration loop 는 8-iteration 대비
unroll/pipeline 정렬이 나쁘다 (ptxas 가 2^k trip count 에 더 공격적
unroll). 이건 secondary -- 측정상 launch dominance 가 primary (sec 1
관찰 3 참조).

### 원인 3 -- 고정 64x64 CTA tile vs cuBLAS adaptive tiling

hexa N201 은 per-CTA **고정 64x64** output tile (4-warp 2x2). 따라서
grid 한 변 = ceil(S/64). cuBLAS 는 shape 에 따라 tile 크기를 적응시킨다
(M=384 에서는 32x32 또는 64x32 등 더 작은 tile 로 384x384 grid 를
나머지 없이 분할 -- RFC 067 notes.md sec "Extended sweep" 의 추정).
384 = 64*6 = 32*12 = 96*4. 64x64 는 6x6 perfect fit 이지만 Hilbert padding
때문에 8x8 로 강제 확장되는 반면, 32x32 는 12x12 perfect fit 이고
12 = next_pow2 패딩 시에도 16x16=256 (idle 비율은 더 큰 grid 에서는
compute 가 가려 무해) 또는 raster scheduling 으로 idle 0.

**핵심 패턴:** 고정 64x64 + Hilbert next_pow2 padding 의 조합이
`6 = side between 2^2=4 and 2^3=8` 인 shape 에서 최악. side 가 정확히 2^k
거나 (256/512/...) compute-bound regime (6144/8192) 면 무해.

## sec 3 -- 설계 옵션

### 옵션 A -- adaptive CTA tile size (32x32 / 64x64 dynamic, cuBLAS-style)

shape 에 따라 per-CTA tile 을 64x64 또는 32x32 로 선택. M=384 에서 32x32 를
쓰면 grid 12x12, Hilbert p=next_pow2(12)=16 -> 16x16=256 CTA, live 144 ->
live% 56.3% (동일!). **단순 tile 축소만으로는 padding 비율이 안 바뀐다**
(12 도 non-2^k). 따라서 옵션 A 는 옵션 B (padding 제거) 와 결합해야
의미. tile 축소의 독립 효과 = grid fit + occupancy (smem 8192->2048 B/tile
-> 더 많은 CTA resident) 이지만 mma chain 재작성 (8 mma -> 2 mma per warp)
필요 -> generator 대수술.

- **장점:** cuBLAS 가 실제로 쓰는 경로. 작은 shape occupancy 개선 여지.
- **단점:** mma chain + ldmatrix swizzle 주소 전면 재유도. 큰 shape
  (>=2048) 에서 64x64 가 이미 0.97+ 이므로 회귀 위험 (32x32 는 K-reuse
  적어 큰 shape 에서 느림). dual-tile generator = 복잡도 2배.
- **회귀 위험:** HIGH (모든 shape 의 mma chain 영향).

### 옵션 B -- Hilbert padding 제거 (non-2^k grid 에 raster/Morton fallback)

`p = next_pow2(gx)` 가 gx 와 다를 때 (= gx 가 non-2^k) Hilbert 대신
raster (row-major) 또는 Morton(Z-order) CTA-swizzle 로 fallback. raster
는 정확히 gx*gy CTA 만 launch -> **idle CTA 0**.

```
if gx == next_pow2(gx):
    # Hilbert (L2 locality, 기존 경로)
else:
    # raster: cta_x = ctaid % gx, cta_y = ctaid / gx, grid = gx*gy 정확
```

M=384 -> grid 6x6=36 CTA launch, idle 0 (현 64 launch / 36 live ->
36 launch / 36 live). launch overhead 28 CTA 만큼 감소.

- **장점:** generator 최소 변경 (prologue swizzle 분기만). mma chain
  무수정. idle CTA 정확히 0. 가장 낮은 복잡도.
- **단점:** raster 는 Hilbert 의 L2 cache locality 손실. 단 작은 shape
  (M=384, 36 tile) 은 L2 working set 이 작아 locality 이득이 미미할 것
  (검증 필요 -- 측정 falsifier F-RFC076-B). Morton 은 locality 유지하며
  non-2^k 도 가능하나 d2xy 보다 주소 계산 단순.
- **회귀 위험:** LOW (2^k shape 는 Hilbert 경로 그대로 -> 회귀 0 by
  construction). non-2^k 만 raster -> locality 손실 측정 필요.

### 옵션 C -- K_TILES_OUTER loop unroll 강제 (non-2^k 도 unroll pragma)

K-loop 에 `.pragma "nounroll"` 제거 + 명시적 unroll 또는 ptxas
`-maxrregcount` 조정으로 non-2^k trip count 도 unroll. 원인 2 만 타겟.

- **장점:** 매우 국소적 변경 (K-loop pragma).
- **단점:** 원인 2 는 secondary (sec 2). M=384 의 dominant 는 원인 1
  (idle CTA). unroll 단독으로는 0.893 -> 0.93 도달 난망 (추정 -- 측정
  falsifier F-RFC076-C). reg pressure 증가로 occupancy 하락 위험.
- **회귀 위험:** MEDIUM (reg pressure -> 모든 shape occupancy).

## sec 4 -- 권장

**권장 = 옵션 B (Hilbert padding 제거 / raster fallback), phase 1.**

근거:
1. **회귀 위험 최저.** 2^k shape (sweep 의 6/9) 는 Hilbert 경로 무변경
   -> by-construction 회귀 0. falsifier 가 이를 직접 검증.
2. **dominant 원인 직격.** sec 2 원인 1 (idle CTA 43.8%) 이 M=384 dip 의
   primary. 옵션 B 가 idle 을 정확히 0 으로 만든다.
3. **최소 복잡도.** prologue swizzle 분기 1개. mma chain / ldmatrix /
   epilogue 무수정.
4. 옵션 A 는 옵션 B 없이는 padding 비율 불변 (sec 3 A 분석) -> B 가
   선행. 옵션 C 는 secondary 원인만 -> B 측정 후 잔여 gap 이 남으면 추가.

**phase 2 후보 (B 측정 후):** raster locality 손실이 측정되면 Morton
(Z-order) 로 교체. 그래도 0.93 미달이면 옵션 C (unroll) 추가, 최후
옵션 A (32x32 dual-tile).

**D1 (사용자 결정 대기):** 옵션 B 단독 진행 vs B+C 동시 vs A 전면.
권고 = **B 단독 → 측정 → 잔여 gap 따라 phase 2**.

## sec 5 -- Falsifiers

모든 falsifier 는 ubu-1 RTX 5070 sm_120 에서 cuBLAS HGEMM 대비 측정.
baseline = RFC 067 N201 result.json (M=384 ratio 0.8930). bit-exact
(`maxabs=0` `maxrel=0`) 는 모든 변형에서 유지 전제.

| ID                          | claim (측정 가능 success criterion)                                          | 옵션 | cycle |
|-----------------------------|-------------------------------------------------------------------------------|------|-------|
| **F-RFC076-B-M384-RATIO**   | 옵션 B 적용 후 M=384 ratio **>= 0.93** (현 0.8930)                            | B    | P1    |
| **F-RFC076-B-NO-REGRESS**   | 옵션 B 적용 후 다른 8 shape ratio **회귀 0** (각 shape ratio >= baseline -0.005) | B    | P1    |
| **F-RFC076-B-BITEXACT**     | 옵션 B 9/9 shape `maxabs=0` `maxrel=0` 유지                                    | B    | P1    |
| **F-RFC076-B-IDLE-ZERO**    | 옵션 B M=384 ctas_launched == ctas_real == 36 (idle 0)                        | B    | P1    |
| F-RFC076-C-UNROLL           | (옵션 C 진행 시) K_TILES_OUTER unroll 후 M=384 ratio 단조 증가                | C    | P2?   |
| F-RFC076-A-DUALTILE         | (옵션 A 진행 시) 32x32 tile M=384 ratio >= 0.93 AND 큰 shape (>=2048) 회귀 0  | A    | P3?   |

**primary success gate = F-RFC076-B-M384-RATIO AND F-RFC076-B-NO-REGRESS
동시 PASS** (작업 지시의 success criterion: "M=384 ratio >= 0.93 달성
하면서 다른 shape 회귀 0"). 둘 중 하나라도 FAIL 이면 옵션 B 는 그
shape 에 대해 falsified -> phase 2 로.

**honest 반증 조건:** 옵션 B 가 M=384 를 0.93 으로 올리되 다른 shape 를
회귀시키면 (예: raster locality 손실로 1024 가 0.934 -> 0.92) F-RFC076-
B-NO-REGRESS FAIL -> 옵션 B 단독은 reject, Morton 또는 conditional
(non-2^k 만 raster) 로 좁힌다. 이건 honest refutation 이지 실패가 아니다.

## sec 6 -- 측정 계획

`feedback_instrument_first_methodology` 4규칙 준수:

1. **cheap-first oracle.** generator 의 raster 분기를 PTX diff
   (`reference_ptx_diff_perf_oracle.md`) 로 먼저 검증 -- M=512 (2^k)
   PTX 는 Hilbert 경로라 baseline 과 byte-identical 이어야 함 (회귀 0
   증명). M=384 PTX 만 raster 분기 -> instruction histogram diff 로
   prologue 변경 국소성 확인. silicon fire 전 $0 게이트.

2. **silicon fire (ubu-1).** `reference_gpu_fire_infra.md` 경로:
   `ssh ubu-1` + `cuModuleLoadDataEx` driver JIT (PTX 순수 ASCII,
   `.target sm_120a + .version 8.7`). `measure.sh` 를 9-shape 로 확장
   (현재 SHAPES 미확장 -- notes.md 기록), N201 baseline 과 동일 harness.
   warmup 20 + measurement 200, median.

3. **faithful 사전 예측.** 옵션 B 적용 시 M=384 launch CTA 64->36
   (43.8% 감소). launch latency 가 wall 의 ~10% 라 가정하면 ratio
   0.893 -> ~0.93 예측 (cheap closed-form, fire 전 기록). 실측이
   예측과 크게 벗어나면 모델 재검토 (over-claim 방지).

4. **통합 스칼라 금지.** ratio 단일 수치가 아니라 shape 별 ratio +
   ctas_launched/real + maxabs/maxrel 전부 result.json 에 기록. 9-shape
   매트릭스로 회귀를 shape-별 검사 (F-RFC076-B-NO-REGRESS).

**산출물 (구현 cycle):** `archive/fires/rfc076_adaptive_tile_*/` 에
generator (raster 분기 추가) + 9-shape PTX + measure.sh + result.json +
notes.md (honest readout). 본 design RFC 는 fire 산출물 아님.

## sec 7 -- Cross-references

- RFC 067 N201 (`archive/fires/rfc067_ptma_swizzle128_2026_05_22/`) --
  baseline kernel + 9-shape sweep + M=384 dip honest readout (notes.md
  sec "Extended sweep").
- `gen_sgemm_tma_swizzle128_ptx.py` -- 현 generator (고정 64x64 CTA,
  Hilbert d2xy prologue `emit_hilbert_prologue`, `next_pow2`).
- `result.json` (cycle 4 E · PR #540) -- 측정 데이터 SSOT.
- `reference_gpu_fire_infra.md` -- ubu-1/ubu-2 RTX 5070 sm_120 driver
  JIT + ASCII-only PTX.
- `reference_ptx_diff_perf_oracle.md` -- hexa-emit vs nvcc PTX
  instruction histogram diff = $0 perf oracle (cheap-first gate).
- `project_gpu_md_mega_cycle_2026_05_21.md` -- GPU fire SSOT 패턴.
- `feedback_instrument_first_methodology.md` -- cost-bearing 측정 4규칙
  + over-claim 0.

## sec 8 -- Honest scope

`@D g3` (verification-anchor-real-limit) 준수:

- 본 RFC 는 **design draft**. 어떤 ratio 개선도 측정 전에는 주장하지
  않는다. sec 6 의 "0.893 -> ~0.93 예측" 은 명시적 closed-form 사전
  예측이며 silicon 측정으로만 확정/반증된다.
- M=384 dip 은 이미 RFC 067 notes.md 에 documented anti-case 로 정직
  하게 기록됨. 본 RFC 는 그 anti-case 를 가린 것이 아니라 설계 경로로
  전환한다.
- 옵션 B 권고는 회귀 위험 + 복잡도 기준 추정이다. 실제 raster vs
  Hilbert locality trade-off 는 F-RFC076-B-NO-REGRESS 측정으로만
  결정된다.
- RFC 067 의 잔여 gap (sec "Honest readout" #5: software pipelining /
  async warp split / 128x128 tile) 은 본 RFC 범위 밖. 본 RFC 는
  M=384-특이 dip 만 다룬다. 큰 shape 의 2-3% 잔여 gap 은 별도 RFC.
- 작업 지시의 success criterion (M=384 ratio >= 0.93 AND 다른 shape
  회귀 0) 을 F-RFC076-B-M384-RATIO + F-RFC076-B-NO-REGRESS 로 그대로
  falsifier 화 했다.
