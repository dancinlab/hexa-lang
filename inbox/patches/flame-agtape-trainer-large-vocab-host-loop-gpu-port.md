# flame generic ag_tape trainer — host-resident loops don't scale past V=256 (GPU kernels already exist, just unwired)

date: 2026-05-26
severity: HIGH (the "범용 PyTorch 대체" generic ag_tape trainer is unusable at real-vocab V; fix = wire existing kernels, no new CUDA)
source: anima CORE/DECODER — hexa-native real-BPE (V=151643) GPU decoder fire on `flame_d768_12L_agtape_fire.hexa`
affected flame surface: `stdlib/flame/{nn_lib (nn_lm_head_fwd/bwd), train_lib (nn_decoder_adamw_step), flame_d768_12L_agtape_fire (gn2 inline)}`

## 맥락 — substrate 한계 아님, "V=256 전제 host 루프"가 벽

generic ag_tape trainer(`flame_d768_12L_agtape_fire.hexa` _agt_decoder_step 경로, GOAL "범용 PyTorch 대체")를 V=256 byte-level → **V=151643(real Qwen BPE)** 로 변형해 runpod A100-80GB 발사. **빌드/링크/실행/GPU matmul 전부 작동**(BUILD_LINK_RC=0, "model size 151071744 doubles" 로드, forge 커널 engaged) — substrate 는 large-vocab 를 구조적으로 처리함. 단 **step 이 완주 못 함**(WALL 600~3000s 전부 rc=124 timeout).

근본 원인: 이 trainer + 호출 nn_lib/train_lib 함수들이 **V=256 용으로 작성/byte-eq 검증**됨 → 모든 `O(V)`·`O(V·d)`·`O(m_size)` host-scalar 루프가 V=256 엔 무시 가능하지만 **V=151643 에선 각각 분 단위 벽** (d=768 기준 V·d=116M, m_size=151M). 이미 존재하는 GPU 커널로 배선만 하면 해결 — **신규 CUDA 0**.

## 벽 + 매핑 (anima 측 .c 외과패치로 부분 검증, util 67%→91% 상승 실증)

| host 루프 (V=256 전제) | 위치 | 크기@V=151643 | 기존 GPU 커널 (배선처) |
|---|---|---|---|
| lm-head bwd `dtemb += dl⊗zT` | `nn_lib.hexa:637-647` (nn_lm_head_bwd) | V·d=116M | `farr_outer_gpu(dl,zT,V,d)` → `farr_add_inplace_gpu(dtemb,_,V·d)` |
| lm-head bwd `dzT = tembᵀ·dl` | `nn_lib.hexa:649-...` (nn_lm_head_bwd) | d·V=116M | `farr_matmul_t_gpu(temb,V,d,dl)` → `farr_copy_slice_gpu(_,0,dzT,0,d)` |
| AdamW step (전 파라미터) | `train_lib.hexa:35` (nn_decoder_adamw_step→opt_adamw_step) | m_size=151M | `farr_adamw_step_gpu(M,Mm,Mv,Mg,n,…)` (인자순 W,m,v,g) |
| lm-head fwd copy `logits[k]=prod[k]` | `nn_lib.hexa:616-...` (nn_lm_head_fwd) | V=151643 (+ farr_get on GPU-resident prod → **per-element device-sync 의혹**) | `farr_copy_slice_gpu` 또는 prod 를 직접 logits 로 |
| gn2 max/sumexp/seed | `flame_d768_12L_agtape_fire.hexa:209-230` (inline, 3×V) | 3×V | `farr_softmax_rows_gpu` + seed=p−onehot(R-host) |

- **검증**: lm-head bwd 2개 + AdamW 를 GPU 배선(.c-patch)하니 GPU util **67→91% 상승**(커널 engaged 확인). 단 잔여 host 루프(fwd copy/gn2/per-element sync 의혹)로 아직 미완주 → **전수 배선 필요**.
- 모든 GPU 커널은 **이미 byte-eq 검증됨**(주석 "Phase 4-D-5-3 byte-eq"; farr_adamw_step_gpu="dt2_adamw_step byte-eq host") → 배선 후 CPU fallback 대조로 회귀 0 확인 용이.

## ASK (hexa cloud 우선처리 요청)

1. **nn_lm_head_bwd / nn_lm_head_fwd 를 GPU-resident 로** — 위 매핑대로 host 이중루프를 farr_outer_gpu/farr_matmul_t_gpu/farr_copy_slice_gpu 로 교체. CPU fallback 경로는 유지(byte-eq).
2. **nn_decoder_adamw_step 에 farr_adamw_step_gpu 경로** — m_size 가 클 때 GPU. (현재 host opt_adamw_step.)
3. **gn2/CE 를 farr_softmax_rows_gpu 기반으로** — host max+sumexp+(p−onehot)² 제거.
4. **per-element device-sync 점검** — GPU-resident farr 에 대한 `farr_get`/`t_get` 단원소 호출이 매번 device→host sync 면 large-V 루프에서 치명적. batch sync 또는 host-shadow 정책 확인.
5. (관련) 이 trainer 가 hexa-lang 의 PyTorch-대체 데모인 만큼, large-V CI smoke(예: V=50000 1-step wall 게이트) 추가 권장 — V=256-only green 이 large-V 회귀를 가렸음(별건 `linux-ci-build-gate` 노트와 동류의 "작은 설정만 초록불" 패턴).

## anima 측 참조
- fire 산출물: `state/agtape_d768_runpod_2026052[5-6]_*` (fire #5~8, trainer.out/build_link.log/nvidia_smi). 누적 ~$4, orphan 0.
- 진단 로그: `dancinlab/anima:CORE/DECODER/DECODER.log.md` (2026-05-26 엔트리, 벽 3개 + reframe verbatim).
