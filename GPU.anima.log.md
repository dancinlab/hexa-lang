# GPU.anima.log — anima 트레이너 GPU 전이 시간순 로그

> `GPU.anima.md` 스냅샷의 append-only 시간순 로그. 마일스톤 진척·발견·정정·외부 PR 링크.

---

## 2026-05-28 — BC-ANIMA 도메인 개설 + 마일스톤 등록

- anima 측에서 M4b longtrain saga 결정적 fire 직후 step-rate 측정값 `STEP_RATE_FINDING` 도출 (anima PR #1318): production 트레이너 ~1 step/s, 병목은 matmul 이 아니라 CPU-side Adam (29.16M params) + zero (29.16M farr_set) + softmax (V=151643). 토이 `dec_undertrain` 예측 "tens × V presentations" = ~9 GPU-days = 실현불가능.
- hexa-lang 정찰: 필요한 GPU kernel 은 `_hx_cuda_farr_{adamw_step,softmax_rows,ce_seed,zero_slice,matmul}_gpu` 로 runtime_cuda.c 에 모두 존재. 하지만 hexa 빌트인 노출은 `farr_zero_slice_gpu` + `farr_matmul` 만 완성, **adamw_step·softmax_rows·ce_seed 는 codegen 등록 미완**.
- BC-ANIMA 5단계 마일스톤(M0~M5) 등록. M0 (anima trainer dMg zero wiring) 은 hexa-lang 손 안 대고 즉시 land 가능. M1~M3 은 hexa-lang codegen 슬롯 + CPU 기준선 + dispatch 추가 (단일 PR <200 LoC 씩 stacked). M4 = anima full wiring, M5 = decisive long-train 재발사.
- 위험 식별: M1 의 12-arg codegen 슬롯 신설은 `hexa_cc.c` bootstrap 재컴 트리거 — byte-eq + 기존 테스트 매트릭스 통과 필수.

진행 전 상태: 모든 마일스톤 ☐ (미시작).

## 2026-05-28 — M0 LANDED ✅

- anima PR #1319 머지 — `train_v3_moe_longtrain.hexa` 의 step-loop 도입부 3 zero 루프(d_logits[V=151643] · dMg[m_size=29.16M] · d_zT_last[d=64])를 `farr_zero_slice_gpu` 빌트인 호출 3 줄로 교체. 6 lines deleted, 6 lines added.
- hexa-lang 손 안 댐 — 빌트인은 이미 노출돼 있었음(runtime.c:12229). 트레이너가 `cudaMemset` (HEXA_CUDA) / `memset` (CPU) 경로를 사용하게 됨.
- 예상 효과: per-step CPU 단일코어 부하 중 ~29M farr_set 호출 제거. 실측 step-rate 변화는 다음 H100 fire 에서 측정 (M4 wiring 완료 후 종합 측정 권장 — 단독 측정은 노이즈 클 수 있음).
- 상태: M0 ☑ · M1~M5 ☐. 다음 = M1 (hexa-lang `farr_adamw_step` 빌트인) — 별도 세션 권장 (codegen 새 arg-slot + bootstrap 재컴 위험).
