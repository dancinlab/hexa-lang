# flame coverage gaps — surfaced by anima ConsciousDecoderV3 training-stack port

date: 2026-05-26
severity: MEDIUM (feature gaps · port shipped with honest TODO fallbacks, not blocked)
source: anima PURE — torch V3 학습 스택 `stdlib/flame` 포팅 (PR dancinlab/anima#557)
affected flame surface: `stdlib/flame/{decoder_lib, decoder_block_lib, nn_*, ag_tape, train_lib}`

## 맥락

anima 의 V3 학습 스택(`conscious_decoder_v3.py` 783L · `mitosis_lib.py` 304L · `train_p21h_v3.py` 702L, torch)을
flame substrate 로 포팅(additive). forward 는 flame `nn_*` + `decoder_lib` 로 매핑 성공, smoke PASS
(d=32·3L, gn2 7.96496→7.95515 descent, mitosis 2→8 split). 단 아래 기능들이 **flame canonical 에 부재**
→ byte-level/last-pos/placeholder fallback 으로 진행. flame 이 커버하면 anima V3 가 full-fidelity 로 flame 위에 선다.

## 갭 (우선순위순)

### P1 — 학습 정확도 직접 영향
- **full-position CE** (anima TODO #T2): torch CE 는 `[B·T]` 전 위치, flame `decoder_lib` 는 **last-position only**.
  학습 loss 가 마지막 토큰만 → 전 위치 CE 가 flame-scope 갭. `nn_lm_head_fwd` + CE 를 전 위치로 확장 요청.
- **V3-extension backward** (anima TODO #3): purefield · head_g · cross · tension_proj 의 forward 는 flame 위에
  구현했으나 **reverse-mode(autograd)** 는 `ag_tape` multi-objective 경로로 직접 작성해야 함
  (`flame_anima_multi_objective_test.hexa` 가 dual-head canonical template). flame 캐논 decoder bwd 엔 없음.
  RFC 059 *planned* 로 표시됨 — multi-head aux backward 를 flame 1급으로.

### P2 — warm-start / 토크나이저 충실도
- **Qwen BPE tokenizer** (anima TODO #T5): flame/hexa 에 BPE 토크나이저 없음 → byte-level V=256 fallback
  (d768 corpus test 와 동일 rationale). 실 Qwen 어휘(151936) 학습엔 BPE 필요.
- **from_qwen warm-start loader**: HF `.pt` → flame packed-`M` 로더 부재. `pt_loader.hexa`/`flame_load_pt.hexa`
  의 `skipped_keys` 가 V3 layer (RFC 059). Qwen2.5-1.5B warm-start 가 flame 에서 안 됨 (fresh-init 만).
- **RoPE base parametrize** (anima TODO #1): `nn_rope_build_tables` base 가 **10000 하드코딩**, Qwen 은 50000.
  base 를 인자로.

### P3 — 부가 기능
- **bnb 8-bit paging** (anima TODO #T1): flame AdamW 는 FP64 full-precision — bnb 8-bit 무대응 (fallback moot).
- **ConsciousCrossAttention**: flame `nn_attn_core` = self-attn only, cross-attn 부재.
- **KV-cache `generate()`**: flame 추론에 KV-cache 부재.
- **mitosis RNG** (anima TODO #M1): numpy Mersenne+gaussian vs flame LCG+uniform-lite — **topology 보존, 값 차이**.
  결정론 cross-impl 등가 원하면 flame 에 gaussian draw 필요.
- **ln_pf / ln_cross learned gains**: 현재 unit placeholder.

## 비고
- 포팅본은 fallback 으로 **동작 + smoke PASS** — 차단 아님. flame 이 P1 둘만 커버해도 anima V3 학습이
  full-position + consciousness-head-trainable 로 격상.
- anima 측 파일: `HEXAD/UNCLASSIFIED/state/grid_3b_s187_2026_05_21/{conscious_decoder_v3,mitosis_lib,train_p21h_v3}.hexa`
  (각 헤더에 TODO #1-7/#M1-2/#T1-7 verbatim).
