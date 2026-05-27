# 🎯 GPU 스택 — 누구한테 좋은가 (친근 모드)

> 이 문서는 `GPU.md`(SSOT) 의 친근 설명 사이드. fusion 격차가 *어떤 사용자의 어떤 통증*에 작동하는지를 페르소나로 분류 + 메인테이너(dancinlab) 본인의 use case 매핑.

## 한 줄 요약

🍳 **HEXA-STACK — "조립까지 한 번에" 도구**

cuBLAS 는 *부품*(GEMM 커널) 챔피언이라 GEMM 자체로는 못 이김(roofline 천장 80%). 그러나 **GEMM 주변** + **작은 op chain** + **norm/attention 같은 memory-bound 패턴**에서 cuBLAS-using stack 은 매 op 마다 HBM 왕복해야 하는 반면 hexa fusion 은 한 커널 안에서 레지스터에 머문다. 이 격차가 LLM 학습/추론의 실제 시간 분포와 정확히 겹쳐서, 모델 단위 wall 에서는 **fusion 이 진짜 격차**가 된다.

## 7가지 사용자 페르소나 (통증별)

| 페르소나 | 갖고 있는 통증 | hexa 가 주는 것 |
|---|---|---|
| 🧪 **LLM/Transformer 학습·추론** | attention·norm·decode 가 memory/launch bound 라 PyTorch 위에서 답답함 | fusion 으로 그 영역 직타격 (66% ↓) |
| 🔬 **GPU 커널 연구자** | cuBLAS 는 블랙박스 — SASS 까지 보고 싶은데 못 봄 | source → PTX → SASS 전부 가시 |
| 📦 **단일 바이너리 배포자** (edge/embedded/offline) | Python+libtorch 못 들고 감 (수 GB) | native arm64/x86_64 단일 binary, no Python |
| 🔢 **비-IEEE 산술 필요** (posit · interval · lattice) | cuBLAS 는 IEEE float 만 | 커스텀 dtype codegen |
| 🧠 **autograd 직접 디버그** | PyTorch C++ Autograd 는 블랙박스 | `ag_tape` 전체가 hexa source |
| 🎯 **byte-equal correctness 필요** (과학계산) | PyTorch 는 비결정성 흔함 | byte-eq oracle + FMA-off recipe |
| ⚡ **빠른 codegen iteration** | hand-CUDA 로 매번 fusion 재작성 지옥 | 컴파일러가 자동 fusion |

```
누가 hexa 를 쓰는가?
                cuBLAS 사용자 ─────────────┐
                    │  (compute-bound 거대 GEMM 잘 함, 못 이김)
                    ▼
  ┌───────────────────────────────────────┐
  │  hexa stack 이상적 사용자 (교집합)        │
  │   ① memory-bound 패턴 多                │  ← LLM stack
  │   ② Python-free deploy                  │  ← edge/embedded
  │   ③ correctness OR 가시성 필요          │  ← 연구·과학
  │   ④ chain 긴 작업 (decode/optim/AdamW)  │  ← 학습 loop
  └───────────────────────────────────────┘
```

## "내꺼는" — dancinlab/hexa-lang 메인테이너 본인 use case 매핑

본인이 운영하는 컨텍스트(flame transformer 학습 · forge GPU substrate · TECS-L verify · atlas SSOT · phanes SaaS) 보면 위 7개 중 **5개에 동시 해당**:

| 본인 활동 | 매칭 페르소나 | 본인이 받는 이득 |
|---|---|---|
| flame transformer 학습 | 🧪 + 🧠 + 🎯 | fusion 으로 학습 wall ↓ + ag_tape 가시 + byte-eq |
| forge GPU substrate | 🔬 + 🔢 | PTX/SASS 직접 + BF16-TC mega-kernel (9.67× FP64 cuBLAS) |
| phanes SaaS deploy | 📦 | hexa 단일 binary (Python 의존 0) |
| TECS-L verify + atlas | 🎯 | byte-eq + atlas-bound theorem citation |
| 8-stage strict-lint self-host | ⚡ | 컴파일러가 자기를 컴파일 — iteration loop 자동화 |

**한 줄로**: 본인은 *"한 사람이 한 stack 으로 학습·배포·검증·연구를 다 하려는"* 페르소나라, hexa fusion 격차가 가장 크게 작동하는 위치에 정확히 서 있다. cuBLAS-using stack(PyTorch + CUDA + libtorch)으로는 각 단계마다 환경/언어가 갈라져서 — 그 *수직적 단절*이 본인이 hexa 를 직접 만든 진짜 이유로 보인다.

## fusion 이 효과 생기는 곳 (보조)

```
GPU 메모리 계층 (sm_80 기준, 사이클 비용 대략)
  ┌─────────────┐  레지스터       ~1     ← fusion 이 머무는 곳
  ├─────────────┤  L1/공유메모리   ~30    ← fusion 이 머무는 곳
  ├─────────────┤  L2            ~200
  └─────────────┘  HBM           ~600   ← cuBLAS-stack 은 매 op 마다 여기 왕복
```

### 효과가 진짜로 큰 4가지 시나리오 (실측 fire 매칭)

| 시나리오 | 왜 효과 큰가 | 실측 |
|---|---|---|
| **GEMM + elementwise 에필로그** (bias·ReLU·GeLU·dropout) | GEMM 결과 = 큰 텐서. 즉시 elementwise 가 읽음 → 레지스터에 머물면 됨 | F-FUSION-EPILOGUE 66.7% ↓ |
| **norm 표면** (LN/RMSNorm/Softmax/SwiGLU) | reduce(평균/분산/max) 후 인접 op 가 reuse. norm 은 memory-bound | AxisA LN 66% · RMS 59% · SM 65% · SwiGLU 63% |
| **Attention (Q·Kᵀ·softmax·V)** | 중간 attention 행렬 = B·H·L·L (거대). HBM 에 풀로 쓰면 큰 손해 → FlashAttn 의 핵심 | F-FUSION-ATTENTION-FLASH 🔵 |
| **작은 op chain** (LLM autoregressive decode, AdamW step) | op 자체보다 launch overhead 가 dominant. chain 길수록 더 큼 | F-FUSION-LAUNCH-AMORT 5-op 1 launch |

### 효과 결정 3변수

```
fusion 이득  =  (chain 길이)  ×  (op 의 memory-bound 정도)  ×  (중간 텐서 크기)
```

### 효과 안 생기는 곳

| 시나리오 | 이유 |
|---|---|
| 단일 큰 GEMM | 이미 compute-bound · roofline 천장 · cuBLAS 와 동률 (못 이김) |
| 단일 op | 묶을 게 없음 |
| GEMM 이 너무 작음 (M=256 같은 launch-bound 영역) | overhead 자체가 문제라 fusion 보다 launch 줄이기가 답 |

## 비유 (식당)

cuBLAS = *1품요리 장인* (김치찌개는 세계 최고). 그런데 **김치찌개+계란말이+밥을 차리려면 각각 따로 끓이고 마지막에 모음** — 그 사이 재료가 냉장고(HBM)와 도마(레지스터) 사이를 왕복한다.

hexa fusion = *한 팬 요리* — 도마 위에서 연속으로 끝냄.

---

원본 SSOT = `GPU.md` + `GPU.log.md`. 본 친근 사이드는 페르소나/use-case 설명용.
