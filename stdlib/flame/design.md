# flame — design decisions (범용 PyTorch 대체 GOAL)

> GOAL (user, 2026-05-18): flame + hexa = PyTorch + Python 의 범용 대체.
> 단일형태 (d=768·12L) closure 달성 (F-RFC046-WALL PASS). 이 문서는
> 범용 대체까지의 아키텍처 결정 audit trail (one decision = one gate).

---

## Decision 1 — autograd 자동화 = tape 일반화 (RFC 043 Phase 2)

**picked**: RFC 034 의 검증된 tape (matmul + CE-softmax) 를 RFC 043
§Surface 의 7 nn-layer (linear · rmsnorm · rope · gqa_attention ·
swiglu · embedding · tied_lm_head) 각각의 closed vjp recording 으로
일반화한다. decoder_lib 의 monolithic hand-written `nn_decoder_grad`
(L205-485, ~280 lines, offset-baked composed reverse) 를 per-layer
`ag_*` tape record + replay 로 교체.

**rationale**:
- **closed vjp 는 이미 검증됨, 유도 불필요** — verify_all battery 가
  `rmsnorm_bwd · rope_bwd · swiglu_bwd · residual_bwd · attention_bwd`
  를 각각 `max|Δ| = 0.0 strict byte-eq vs libm reference` PASS 로
  보유 (F-RFC047-LEAF-EMIT-*-BWD). Phase 2 의 일은 vjp 수학을 새로
  유도하는 게 아니라 **이미 byte-eq 검증된 leaf vjp 들을 ag_* tape 에
  wiring** 하는 것 — risk 가 낮고 oracle 이 이미 존재.
- **범용성의 유일한 정석 경로** — hand-written bwd 유지 (대안 2) 는
  아키텍처마다 수동 bwd 작성을 영구히 강제 → PyTorch `.backward()`
  같은 범용 autograd 불가. tape 일반화만이 임의 모델 대응.
- **RFC 043 가 이미 §Surface 에서 API 고정** — ag_tape_begin/end,
  nn_linear/rmsnorm/rope/gqa_attention/swiglu/embedding/tied_lm_head,
  loss_cross_entropy, opt_adamw_step, train_step. signature 불변
  계약 (g_flame_api_fixed) 이라 layer wrapper 추가가 기존 표면 안
  깨뜨림 — 점진 구현 가능.
- **measurement-anchored**: 단일형태 closure 가 wall 경쟁력 입증
  했으므로 (fire #17/18/19b), 일반화가 그 성능을 유지하는지는
  per-layer byte-eq oracle (hand-written grad vs tape-replay grad,
  max|Δ|=0) + 동일 d768 fire 로 측정 가능 — blind 아님.

**rejected**:
- *hand-written bwd 유지 + 일반화만*: shape-generic 은 되지만 범용
  autograd 아님 — GOAL 의 "임의 모델" 미충족. 영구 수동 bwd 부채.
- *수렴 입증만 먼저*: gap (a) 는 fire #22-24 로 병행 측정 중 (직교).
  autograd 설계를 수렴 입증까지 막을 이유 없음 — closed vjp 가 이미
  byte-eq 검증됐으므로 수렴과 독립적으로 진행 가능.

**1st sub-step (cheapest, oracle-gated)**: 단일 leaf layer 의 tape
record + replay 를 hand-written 경로와 byte-eq 검증. 후보 = RMSNorm
(leaf oracle `F-RFC047-LEAF-EMIT-RMSNORM-{FWD,BWD}` 이미 PASS, 가장
isolated). gate = tape-replay dW vs nn_decoder_grad 해당 항 max|Δ|=0.

**status**: 결정 확정 (user gate 2026-05-18). 1st sub-step scoping 완료
→ 작업량 재추정 (아래). gap (a) 수렴 측정 (fire #22, `%.10e` gn2) 병행.

### Decision 1 — scoping 결과 (2026-05-18, 무비용 코드 조사)

**핵심 발견**: `stdlib/flame/nn_lib.hexa` (689 lines) 가 **7 layer
전부의 functional fwd+bwd closed-vjp primitive 이미 완비**:
- `nn_linear_fwd/bwd` · `nn_rmsnorm_fwd/bwd` · `nn_attn_core_fwd/bwd`
  · `nn_swiglu_fwd/bwd` · `nn_rope_build_tables`+`apply_fwd/bwd`
  · `nn_embedding_fwd`+`bwd_scatter` · `nn_lm_head_fwd/bwd`
- 각 bwd 는 closed analytic vjp (anima d_train3/5_lib 참조 알고리즘
  계승), verify_all battery 에서 byte-eq PASS.

**즉, gap (b) 의 작업량 재추정**:
- ❌ "7 layer vjp 유도+구현" (대형) — **이미 완료, 불필요**
- ✅ 실제 잔여 = 두 가지:
  1. **tape-wiring**: functional pair (명시적 fwd/bwd 호출) →
     RFC 043 §Surface 의 tape-recording 형태. `nn_linear(x,w,b)`
     fwd 호출 시 자기 vjp closure 를 ag_* tape 에 push → 사용자는
     `ag_backward(loss_tape)` 만 호출 (수동 bwd 호출 제거). RFC 034
     의 `hexa_ad_*` (self/runtime.c) tape 를 op-type registry +
     closure replay 로 일반화 — **compiled runtime 작업** (C),
     자체 oracle 필요.
  2. **model DSL**: nn.Module-equiv — layer 조합을 선언적으로
     (현 decoder_lib 는 하드코딩 monolith). gap (e) 와 합류.

**1st sub-step (확정, cheapest oracle-gated)**: RMSNorm tape-wiring.
`nn_rmsnorm_fwd` 가 ag_* tape 에 자기 `nn_rmsnorm_bwd` closure 를
record → `ag_backward` 가 그걸 replay. gate = tape-replay dx/dg vs
직접 `nn_rmsnorm_bwd` 호출 결과 max|Δ|=0 (둘 다 같은 closed vjp 라
byte-eq 必). RFC 034 tape 가 generic closure 를 record 못하면
(matmul/CE 만 hardcoded) → self/runtime.c 의 `hexa_ad_*` 에 generic
op-record + replay 추가가 진짜 1st 작업. 이건 다음 sub-decision
(runtime tape registry 설계) 의 gate 대상.

**재추정 결론**: GOAL 의 autograd gap 은 "7 vjp 구현"이 아니라
"검증된 7 vjp 를 generic tape 에 연결 + 모델 DSL". 후자가 본
작업의 핵심 — RFC 034 runtime tape 의 generic-closure 확장이
다음 결정 게이트.

### Decision 2 — scoping: RFC 034 C tape 는 matmul/CE hardcoded

**무비용 코드 조사 (self/runtime.c L10084-10210)**:
- `HexaAdNode` struct = 고정 7 필드 (kind, a_id, b_id, out_id, m,
  k, n). `kind` ∈ {`_HX_AD_OP_MATMUL`=1, `_HX_AD_OP_SMCE`=2} 둘뿐.
- `_hx_ad_record(kind,a,b,out,m,k,n)` — 고정 시그니처. generic
  closure / saved-state bundle / op function-pointer table **없음**.
- `_hx_ad_backward` 는 이 2 kind 만 switch (matmul: dA=dC@Bᵀ /
  dB=Aᵀ@dC ; smce: closed B-D-4 logit Jacobian).
- ∴ 7 nn_lib vjp wiring = **tape 메커니즘 자체 확장 필요** (단순
  record 호출 추가로 안 됨 — node 가 layer 별 saved-state, 예:
  rmsnorm 의 xn/inv, attention 의 P, swiglu 의 a/b/s 를 담을
  구조가 없음).

**Decision 2 옵션 (다음 user gate)** — generic tape 구현 방식:
- **A. C-node 확장**: `HexaAdNode` 에 op-kind 추가 (RMSNORM/ROPE
  /ATTN/SWIGLU/EMBED/LMHEAD) + saved-state farr-id 필드 확장 +
  `_hx_ad_backward` switch 에 각 closed-vjp 분기. C 작업,
  nn_lib bwd 를 C 로 재현 or 호출. fast 하나 layer 마다 C 수정.
- **B. C generic-closure 노드**: node = op-enum + opaque
  saved-farr-id bundle + 등록된 backward fn-ptr table. 임의 미래
  layer 대응 (가장 일반적) 이나 runtime 설계 대형 + fn-ptr ABI.
- **C. hexa-side tape (C 무수정)**: RFC 034 C tape 는 matmul/CE
  fast-path 로 보존. generic tape 를 **hexa stdlib** 에 둠 —
  (op_kind, farr_ids, dims, saved-state) 를 record 하고 replay 시
  이미 hexa 인 nn_lib bwd 호출. `hexa build` compiled 라
  interp 비용 0 (RFC 042/043 directive 충족). C runtime 무수정 =
  risk 최소, nn_lib 재사용 100%. RFC 043 "fat native stdlib +
  thin hexa orchestration" 와 정합.

**예비 권장 = C** (g3 — 측정 전 잠정): C runtime 무수정으로
risk·blast-radius 최소, 검증된 nn_lib bwd 100% 재사용, hexa-native
정합, `hexa build` 라 interp 비용 0. A/B 는 C tape ABI 를 건드려
RFC 034 의 9/9 PASS oracle 회귀 위험. 단 측정 (tape-replay vs
직접 bwd byte-eq + d768 wall) 으로 확정 필요 — 다음 gate.

**picked (user gate 2026-05-18)**: **C 무수정 + hexa-side tape**.
RFC 034 C tape (matmul/CE) 는 fast-path 보존. generic tape 를
`stdlib/flame/` hexa 모듈에 둠 — (op_kind, farr_ids, saved-state,
dims) record → `ag_backward` replay 시 검증된 nn_lib `nn_*_bwd`
hexa 함수 호출. `hexa build` compiled 라 interp 비용 0.

**rationale**:
- C runtime ABI 무변경 → RFC 034 9/9 PASS oracle 회귀 위험 0
  (blast-radius 최소, g3).
- nn_lib 7 layer bwd (이미 byte-eq verified) 100% 재사용 —
  vjp 재구현 0.
- RFC 043 "fat native stdlib + thin hexa orchestration" 정합;
  hexa-native-only 정책 (g5) 와도 정합 (C tape 확장 불요).
- 임의 layer 추가 = hexa 모듈에 op_kind + bwd 분기 1개 추가
  (C 재컴파일·ABI 불요) → 범용성 확장 비용 최소.

**status**: Decision 2 확정. 1st sub-step ✅ **LANDED + PASS**.

### Decision 2 — 1st sub-step LANDED (2026-05-18, $0 compiled oracle)

- `stdlib/flame/ag_tape.hexa` — hexa-side generic tape: farr-backed
  parallel record (slot0=count, op n at 1+n·8 = kind + 6 id-slots +
  dim; ids float-encoded via to_float/to_int idiom). `ag_t_begin` ·
  `ag_rmsnorm` (calls verified nn_rmsnorm_fwd, saves y/xn/inv,
  records node) · `ag_backward_rmsnorm_single` (replays verified
  nn_rmsnorm_bwd with saved state) · `ag_t_free_state` · `ag_t_end`.
- `stdlib/flame/flame_ag_tape_test.hexa` — oracle
  `F-RFC043-AGTAPE-RMSNORM-EQ`: tape record/replay dx/dg/y vs direct
  nn_rmsnorm_fwd+bwd, d=64 deterministic inputs.
- **measured (hexa build compiled, HEXA_MAC_BUILD_OK=1, $0)**:
  `ops=1 · max|Δ y|=0 · max|Δ dx|=0 · max|Δ dg|=0 · PASS`. tape
  plumbing 이 farr id / saved state 를 무손상 운반 입증 (vjp 수학은
  이미 F-RFC043-LAYER-EQ-RMSNORM-BWD verified — 이 oracle 은 plumbing
  isolate).
- C runtime 무수정 확인 (ag_tape.hexa 는 nn_lib + tensor_lib 만
  use, self/runtime.c untouched → RFC 034 9/9 oracle 회귀 0).

### Decision 2 — 2nd sub-step LANDED (2026-05-18, $0 compiled oracle)

- `ag_tape.hexa` 일반화: node 16-slot (kind + 6 ids + 3 dims +
  5 pgrad + 1 igrad), header 2-slot (count + final-input-grad).
  `ag_backward` = generic reverse-walk — ops 를 latest→first 순회,
  각 op 의 input-grad 를 직전(earlier) op 의 upstream-grad 로
  thread (reverse-mode chain). `ag_linear` 추가 (AG_K_LINEAR,
  nn_linear_fwd/bwd 재사용). accessors `ag_param_grad` /
  `ag_input_grad`.
- oracle 확장 `F-RFC043-AGTAPE-CHAIN-EQ`: 2-op chain
  Linear(x0,W,b)→RMSNorm(·,g), tape ag_backward vs 직접 hand-chain
  (same nn_lib calls). **measured (hexa build compiled, $0)**:
  `Test1 RMSNorm single max|Δ y/dx/dg|=0 PASS` +
  `Test2 chain max|Δ y/dW/db/dg/dx0|=0 PASS` → `ALL PASS`.
  multi-op dy-threading plumbing 무손상 입증.
- C runtime 여전히 무수정 (ag_tape.hexa = nn_lib+tensor_lib only).

### Decision 2 — 3rd sub-step LANDED (2026-05-18, $0 compiled oracle)

- ag_tape.hexa +RoPE (AG_K_ROPE, parameterless rotation:
  nn_rope_apply_fwd/bwd, igrad=dq) +LMHead (AG_K_LMHEAD: tied head
  nn_lm_head_fwd/bwd, pgrad=dtemb accumulate-into-zero, igrad=dzT).
  현 6-id 노드에 그대로 fit (구조 변경 0, C 무수정 유지).
- oracle +Test3 `F-RFC043-AGTAPE-ROPE-EQ` +Test4
  `F-RFC043-AGTAPE-LMHEAD-EQ`. **measured (hexa build, $0)**:
  4/4 PASS (RMSNorm·Linear·chain·RoPE·LMHead, 전부 max|Δ|=0).

**다음 sub-step**: ① 잔여 3 layer = SwiGLU (7 saved-state ids
> 현 6-slot → node id-slot 확장 필요) · Attention (Q/K/V 3-input
fan-in = linear-chain 모델 한계, reverse DAG/registry 필요) ·
Embedding (scatter-add into param table, ids 입력은 grad-flow 안 함).
이 3 개는 node-widen + per-param grad registry 와 함께 (다음
sub-step 의 contained change). ② per-param grad registry /
accumulation (같은 param 이 여러 op 에 쓰일 때 += ; AdamW 연결).
③ 전체 ConsciousDecoderV2 ag_tape 재구성 → hand-written
nn_decoder_grad vs tape-replay full byte-eq (d=32 hard gate). ④
RFC 043 §Surface `train_step` = gap(b) closed.

**cross-links**: RFC 043 §Surface =
`inbox/rfc_drafts_2026_05_12/rfc_043_hexa_torch_compiler_only_nn_stdlib.md`
· tape foundation = RFC 034 · leaf vjp oracles = `tool/flame_phase4b3_verify_all.sh`
· GOAL memory = `[[flame-general-pytorch-replacement-goal]]`
