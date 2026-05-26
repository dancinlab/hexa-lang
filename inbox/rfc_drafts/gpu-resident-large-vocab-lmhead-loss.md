# RFC draft — GPU-resident large-vocab lm-head loss (GPU CE/seed kernel)

- **kind**: rfc_drafts
- **filed**: 2026-05-26
- **relates**: #1187/#1194/#1198 (forge-GPU-Linux build fixes), forge `farr_softmax_rows_gpu` (Phase B)
- **evidence**: anima forge d768 fire at V=151643 (real Qwen BPE) on runpod A100

## 문제 — matmul 은 GPU, loss 는 host

forge d768 ag_tape fire 를 V=151643 로 발사(빌드 fix 후 link 클린, GPU util 65%)하니
**step-1 wall > 50분(3000s timeout)**. 원인은 GPU 가 아니라 **loss 가 host-resident**:

```
lm-head:  X[T,d] · temb[d,V]  → logits[T,V]    ✅ farr32_matmul = GPU (빠름)
loss   :  gn2/CE over V=151643                  ❌ host:
            ① logits 78M 값을 host 로 materialize (t_get — H2D 역전송)
            ② max-reduce / sum-exp / (p−onehot)² / seed  = 전부 O(78M) FP64 host 루프
          → 78M dt_exp(host) 가 step 을 분 단위로 지배
```

T=256·nsamp=2 (R=512), V=151643 → R·V = 78M logits. matmul 은 ms, host loss 루프가 분.

## 현재 가용 / 결손

- ✅ `farr_softmax_rows_gpu(x, R, C)` (Phase B) — GPU softmax over rows. 존재.
- ❌ **GPU CE / loss / seed-grad 커널 없음**. softmax 만 GPU 로 바꿔도 host materialization +
  `(p−onehot)²` + seed(dlogits) O(V) 루프가 남아 미봉.

## 제안

1. **logits GPU-resident 유지** — `ag_lmhead` 출력 farr 를 host 로 t_get 하지 말고 farr 로 둠
   (78M H2D 전송 제거).
2. **`farr_ce_seed_gpu(logits_id, target_ids_id, R, V, out_loss_id, out_dlogits_id)` 신규 CUDA 커널** —
   row-wise online-softmax(max+sum 1-pass) + CE loss + seed grad `dlogits = softmax − onehot`
   을 한 커널에서. `_hx_cuda_farr_softmax_rows_gpu`(runtime_cuda.c:1108) 와 동일 배선 계약
   (runtime.h proto + `static HexaVal` + `hexa_fn_new` 등록 + codegen.hexa 매핑 — #1187 교훈대로
   FP32/신규 builtin 은 호출매핑+프로토 양쪽 필요).
3. **ag_tape seed 경로 배선** — `ag_seed_grad` 가 GPU dlogits 를 받아 `ag_backward_reg` 로 전파.

## 효과
V=151643 (및 임의 large-vocab) forge 학습 step 을 분→ms 로. 이게 anima DECODER (C) 의
"hexa-native real-BPE GPU 더블바인드" 최종 블로커 — substrate(빌드+matmul)는 이미 증명됨
(fire #5 util 65%), loss-path GPU-화만 남음.

## 비고
- d768 fire 의 gn2 는 SoS(`Σ(softmax−onehot)²`) — 위 커널을 CE 로 일반화하거나 gn2 변형 둘 다 가능.
- bit-identity 비주장(cuBLAS/online-softmax reduce 순서) — forge `_gpu` 관례 따름.
