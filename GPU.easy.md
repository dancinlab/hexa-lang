# 🔥🔧 PyTorch + cuBLAS 대비 hexa 가 좋은 부분 (친근 모드)

> 이 문서는 `GPU.md` (SSOT) 의 친근 사이드. 기존 표준 (PyTorch + cuBLAS) 대비 hexa (flame + forge) 가 어떤 통증을 어떻게 푸는지를 **본인(메인테이너)** 과 **사용자(타인)** 두 관점으로 정리.

## 비교 구도 한 장

기존 표준은 *2개의 분리된 stack* — PyTorch (학습) + cuBLAS (GPU 커널). hexa = 그 둘을 **하나로 묶은 stack** (flame + forge). 묶인 게 왜 이득인가를 두 관점에서.

```
지금 표준 (남들이 쓰는):                    hexa (flame + forge):
 ┌──────────────┐                            ┌──────────────────────┐
 │   PyTorch    │ Python · C++ · ATen        │      flame           │
 │  (학습 stack) │                            │  (compiler-only NN)  │
 └──────┬───────┘                            │                      │
        │ cudaLaunch                         │  ag_tape · nn_lib    │
        ▼                                    │  opt_* · t_*         │
 ┌──────────────┐                            ├──────────────────────┤
 │    cuBLAS    │ 블랙박스 binary (.so)       │      forge           │
 │  (GPU 커널)   │                            │  (GPU substrate)     │
 └──────────────┘                            │                      │
   ↑ 두 stack 사이 매번 launch+HBM 왕복       │  farr · BF16-TC      │
   ↑ 4 언어/런타임 단절                       │  cuBLAS Dgemm · 11.cu│
                                             └──────────────────────┘
                                              ↑ 한 stack · 한 언어 · fusion 가능
```

## 1️⃣ 본인 (메인테이너) 한테 좋은 점

**통증 = stack 사이의 단절을 매일 4번 건너야 함.**

```
본인 매일 사이클:
 학습      추론       검증         배포
 ───→     ───→      ───→        ───→
 [PyTorch] [CUDA]    [numpy]     [libtorch+Python]   ← 표준 stack
  Python   C++/CUDA   Python      multi-GB
   ↑        ↑           ↑           ↑
   매 단계마다 언어/런타임 갈라짐 — 한 모듈 디버그하려고 4 언어 다 알아야

 vs.

 학습      추론       검증         배포
 ───→     ───→      ───→        ───→
 [flame]   [forge]   [atlas]      [hexa binary]      ← hexa stack
   hexa     hexa      hexa         hexa
   ↑        ↑           ↑           ↑
   모두 한 언어 — 4-cycle 단절이 0
```

| PyTorch+cuBLAS 통증 | hexa 가 본인에게 주는 이득 |
|---|---|
| Python+libtorch 무거워 phanes SaaS deploy 못 함 | 단일 binary, no Python, edge 가능 |
| autograd 미분 디버그 = C++ Autograd 블랙박스 | `ag_tape` 자체가 hexa source — 자기 코드 |
| 학습/검증/배포 각각 언어 갈라짐 | flame+forge+atlas+CLI 모두 hexa — 1 언어 |
| atlas-bound theorem 인용 = PyTorch 에 자리 없음 | 컴파일러 자체가 atlas 인용 검증 |
| iter loop 자기-self-host 8-stage lint 자동 | 컴파일러가 *자기를* 컴파일 |

**한 줄로**: 본인은 *수직 단절* 이 통증 — hexa 가 그 4-단절을 1-stack 으로 합쳐 매일 누적 이득.

## 2️⃣ 사용자 (타인) 한테 좋은 점

**통증 = 자기 부위만 깊게 아픔.** 전체 stack 갈아탈 필요 없이, hexa 의 *그 부분 만* 써도 됨.

| 사용자 페르소나 | PyTorch+cuBLAS 통증 | hexa 가 그 사용자에게 주는 이득 |
|---|---|---|
| 🧪 **LLM 트레이너** | attention / norm / decode 가 launch-bound → PyTorch 위에서 답답 | flame fusion 으로 3-op chain → 1 launch (66.7 % ↓) · FlashAttn-style 한 커널 |
| 🔬 **GPU 커널 연구자** | cuBLAS = 블랙박스 `.so` → SASS 보고 싶어도 못 봄 | forge: source → PTX → SASS 가시 · cubin in-repo |
| 📦 **edge 배포자** | Python + libtorch 수 GB 못 들고 감 | flame: native arm64 / x86_64 단일 binary |
| 🔢 **niche 산술** (posit · interval · lattice) | cuBLAS = IEEE float only | forge custom-dtype codegen — fusion 동일 적용 |
| 🧠 **autograd 디버거** | PyTorch C++ Autograd 못 step | flame `ag_tape` 전체가 hexa source |
| 🎯 **과학 · 재현성** | PyTorch run-to-run drift | flame 4 + forge 12 byte-eq oracle (max\|Δ\| = 0) |
| 🛠 **BF16-TC mega-kernel 작성** | cuBLAS 가 안 묶는 영역 | **forge BF16-TC = 9.67× FP64 cuBLAS** @ Llama-7B FFN |

```
타인은 자기 부위만 골라 들어옴:
  LLM 트레이너   ─→ 🔥 flame (fusion 만 봄)
  커널 연구자    ─→ 🔧 forge (PTX / SASS 만 봄)
  edge 배포자    ─→ 🔥 flame binary (학습은 그대로 PyTorch 유지해도 OK)
  과학자         ─→ 🔥+🔧 byte-eq 만
                                ↑
                  *나머지 stack 은 기존 PyTorch + cuBLAS 그대로 둬도 됨* — gradual adoption
```

**한 줄로**: 타인은 *한 부위 깊이* 가 통증 — hexa 의 해당 도구만 골라 써도 그 통증이 풀림 (전체 마이그레이션 불요).

## 본인 vs 타인 비교 한 표

| 축 | 🧑‍🍳 본인 (메인테이너) | 👥 타인 (일반 사용자) |
|---|---|---|
| PyTorch+cuBLAS 통증 종류 | **수직 단절** (4 stack 사이 갈라짐) | **한 부위** 깊은 통증 |
| hexa 이득 방식 | flame+forge+atlas+CLI 통합 — *매 사이클* 누적 | flame OR forge 부분만 — *그 통증만* 해소 |
| 사용 폭 | stack 전체 (학습 · 추론 · 검증 · 배포 다) | 1-2 도구 (자기 통증 부위만) |
| 진입 비용 | 0 (자기가 만든 도구) | 새 언어 학습 + 일부 마이그레이션 |
| 이득 크기 | 누적 — 4 단절 × 매일 | 집중 — 자기 통증만 강하게 |
| 비유 | 통합 키친 차린 *셰프* | 자기 메뉴만 시키는 *손님* |

## 한 줄 요약

🔥🔧 **PyTorch + cuBLAS vs hexa** = *2개 분리 stack* vs *1개 통합 stack*.

- **본인** 이득 = 통합 자체 (수직 단절 0 → 매일 누적).
- **타인** 이득 = 통합 stack 의 *한 도구만 골라* 자기 통증만 풀기 (gradual adoption).

같은 stack, 두 가치 제안 — 이게 flame + forge 가 PyTorch + cuBLAS 대비 진짜 좋은 부분.

---

원본 SSOT = `GPU.md` + `GPU.log.md`. 본 친근 사이드는 PyTorch+cuBLAS 대비 가치 설명용.

---

# 🏎️ 부록 — MoE 디코더 GPU-ENABLE 작업 (#2017 · #2018, 2026-05-29)

> 위 페르소나 문서와 별개로, 실제로 랜딩한 GPU 작업과 그 다음 ROI를 쉬운 말로 기록.

## 1. 무슨 일을 했나 — "연료펌프 2개 장착"

```
🏎️ GPU-ENABLE — "연료펌프 2개"

- 하는 일: 학습기가 GPU를 실제로 돌리게, 빠져 있던 부품 2개를 추가
- 비유: 엔진(학습기)은 멀쩡한데 연료펌프 2개가 없어 RPM이 안 오르던 차
```

```
before                          after (origin/main)
──────────────                  ──────────────────
adamw: 매 step 233MB 새 할당  →  adamw: 제자리 갱신(0 할당)  #2017
expert 곱셈: CPU 한 칸씩       →  cuBLAS로 GPU 곱셈          #2018
GPU: 0% (놀고 있음)           →  GPU: 점화 🔥
```

- **#2017 in-place AdamW** — 옵티마이저가 매 step 233MB 새 메모리를 만들던 걸
  "제자리"에서 고쳐 쓰게 → 메모리 누수(RSS leak) 제거.
- **#2018 offset-aware cuBLAS gemv** — expert 가중치 곱셈을 CPU 스칼라 루프 대신
  GPU cuBLAS로 → GPU가 실제로 일함.
- 검증: ubu-2 RTX 5070에서 CPU≡GPU 비트 일치(|Δ|=0). 둘 다 머지됨.

## 2. 진짜 병목 — "FLOP가 아니라 대역폭"

```
🚰 MEMORY-BOUND — "빨대로 강물 퍼나르기"

- 하는 일: expert 곱셈은 곱셈 970만 번인데, 그걸 위해 233MB를 읽음
- 비유: 물 한 컵 옮기려고 매번 빨대로 강물을 통째로 빨아들이는 꼴
```

```
expert gemv [V×d]@[d×1]
  = 9.7M 곱셈   ← 작음
  ↕ 233MB 읽기  ← 큼  ← 진짜 비용
산술강도 ≈ 0.08 flop/byte → 뼛속까지 "대역폭 한계"
```

- 속도 천장은 **계산 능력이 아니라 데이터 옮기는 대역폭**(HBM·PCIe).
- 비교: 보통 딥러닝=계산이 병목, 이 디코더=**데이터 이동이 병목**.

## 3. 다음 ROI — 무손실 Top-3

```
🥇 weight 디바이스 상주 (#1)   233MB를 GPU에 한 번 올려두고 매 step 0.5KB만 전송
🥈 토큰 묶음 키우기  (#11)     읽은 가중치를 여러 토큰이 재사용 → 거의 공짜 4~8×
🥉 PTX $0 천장 측정  (#12)     pod 빌리기 전, 비용 0으로 "GPU가 이기나?" 확인
```

```
지금                       목표
빨대(PCIe)로 매 step       강물을 GPU 안에 미리 받아두고
강물 233MB 빨기      →    컵(0.5KB)만 왔다갔다  (#1)
```

- 정직한 경고: d=64·T=4는 **너무 작아 GPU가 오히려 손해**일 수 있음. #12로 천장을
  먼저 재고, #1+#11로 데이터 재사용을 올린 **뒤에야** GPU가 이김. (roofline 기준 판정)

_요약 한 줄: 부품 2개로 점화는 끝. 진짜 속도는 "계산을 빠르게"가 아니라
"데이터를 덜 옮기게"(#1 디바이스 상주 + #11 토큰 묶음)에서 나온다._
