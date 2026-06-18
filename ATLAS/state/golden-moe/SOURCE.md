# golden-moe 코드 박제 (state)

`dancinlab/archive-TECS-L@52e14f3b:engines/golden_moe*.py` 박제 (faithful copy).
골든 MoE = MoE 파라미터를 자연상수 e 로 결정 (억제 I≈1/e, 라우터 온도 T=1/I, Boltzmann gate).

| 파일 | 역할 |
|------|------|
| `golden_moe_cifar.py` | **H-128 재현 진입점** — CIFAR-10 에서 Golden MoE(Boltzmann, T=e, active 0.7) vs Top-K(K=2) 비교 (15 epoch) |
| `golden_moe.py` / `_torch.py` | 코어 구현 |
| `_score.py` / `_recurrent.py` / `_gpu_benchmark.py` | Genius Score · recurrent · GPU 벤치 변형 |

실행: `python golden_moe_cifar.py` (torch+torchvision 필요 · CIFAR 자가 다운로드). 실측 결과는 같은 폴더 `RESULT-*.txt` 로 박제.
관련 가설: `../../hypotheses/{008,019,082,128}-*.md` · 수학검증은 이 세션 CHANGELOG.
