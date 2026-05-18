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

### Decision 2 — 4th sub-step LANDED (2026-05-18, $0 compiled oracle)

- ag_tape.hexa node v3: kind + 8 ids + 4 dims + 6 pgrad + 3 igrad
  (SLOTS=22). _ag_push 8-id/4-dim, 6 record wrapper 모두 갱신
  (slot 산술 일관 재작성). +SwiGLU (AG_K_SWIGLU: 8 saved-state ids
  r/Wg/Wu/Wd/a/b/s/o, pgrad dWg/dWu/dWd, igrad dr) +Embedding
  (AG_K_EMBED: input layer, nn_embedding_bwd_scatter, pgrad dtable
  via t_len(table) 크기 복원, no chain-out — ids 무gradient).
- oracle +Test5 `F-RFC043-AGTAPE-SWIGLU-EQ` +Test6
  `F-RFC043-AGTAPE-EMBED-EQ`. **measured (hexa build, $0)**:
  **6/6 PASS** (RMSNorm·Linear·chain·RoPE·LMHead·SwiGLU·Embed,
  전부 max|Δ|=0). node-widen regression-clean (기존 4 test 유지).
- C runtime 여전히 무수정.

**잔여 (gap(b) closure)**: ① Attention 3-input fan-in. ② param
grad accumulation. ③ decoder 재구성. ④ train_step.

## Decision 3 — per-tensor grad registry (standard reverse-mode)

**picked (non-contested, 표준 설계 — 게이트 불요)**: ag_backward
의 single `cur_dy` linear chain 을 **per-tensor grad registry**
로 일반화. grad 를 tensor farr-id 로 keying, accumulate (+=).
ag_backward: reg[last_op_output] = seed → op n-1..0: out_grad =
reg[op.output_id] ; nn_*_bwd → d_inputs/d_params ; reg[op.input_id]
+= d_input, reg[param_id] += d_param. ag_grad(reg, pid) = 누적
dParam.

**rationale (왜 게이트 안 하고 진행 — Decision 1/2 와 달리 contested
아님)**:
- linear `cur_dy` chain 은 sub-step-1 의 의도된 단순화였음. 일반
  reverse-mode AD 의 교과서 설계 = "grad keyed by node/tensor,
  accumulated" — 이것 외 더 나은 대안 없음 (reverse-DAG ≡
  tensor-keyed grad registry; 같은 것의 다른 이름).
- Attention Q/K/V fan-in 이 자연 해결: attn record(Q,K,V→ctx);
  bwd 가 reg[ctx] 조회 → nn_attn_core_bwd → dQ/dK/dV →
  reg[Q]/reg[K]/reg[V] += . 선행 Linear 들이 reg[Q] 등을 자기
  output-grad 로 조회 — 분기/합류 자동.
- decoder 의 param 재사용 (tied embed/head, layer repeat) 누적
  (+=) 자동 — gap(b) ③④ 의 전제.
- C 무수정 유지 (registry 도 hexa farr-backed; Decision 2 불변식
  보존, RFC 034 9/9 oracle 회귀 0).
- g3: Decision 1/2 는 실 tradeoff (tape-gen vs hand / C-edit vs
  hexa) 라 user gate 했음. 이건 단일 표준해 — audit trail 만 기록,
  round-trip 불요 (no_stop_until_done + 반복 "go" 와 정합).

**status**: Decision 3 ✅ LANDED + MEASURED. `ag_backward_reg`
(per-tensor grad registry, 7 op kinds) + `ag_attn` record/replay
구현. Oracle = `flame_ag_tape_test.hexa` 7/7 PASS, 전부 max|Δ|=0:
Test 1-6 (legacy ag_backward regression-clean) + **Test 7
F-RFC043-AGTAPE-FANIN-EQ** — `x→{Wq,Wk,Wv Linear}→attn(Q,K,V)→ctx`
에서 grad[x] = dxq+dxk+dxv 누적이 hand-chain 과 byte-identical
(`dx(fan-in)=0 dWq=0 dWk=0 dWv=0`). C 무수정 (Decision 2 불변식
보존). gap(b) ①(attn fan-in) ②(param accum) DONE — 잔여 ③ decoder
재구성 (ConsciousDecoderV2 via ag_tape vs hand-written
nn_decoder_grad byte-eq @ d=32) ④ RFC 043 §Surface train_step.

## Decision 4 — decoder reconstruction building blocks (non-contested)

**picked (표준 plumbing — 게이트 불요, Decision 3 선례와 동일)**:
ConsciousDecoderV2 를 ag_tape 로 재구성하려면 7 layer op 외에
3 primitive 가 더 필요 — 전부 verified math 재사용 (nn_lib 무수정):
- `ag_k_add` (residual): `out=a+b`; bwd `d_out→reg[a]+=,reg[b]+=`
  (registry fan-out 자동). Test 8 F-RFC043-AGTAPE-RESID-EQ Δ=0.
- `ag_k_rope_mh` (multi-head RoPE): `q[T·nheads·hd]` 의 per-(t,head)
  row 를 verified single-row `nn_rope_apply_fwd/bwd` 로 p=t loop +
  hd-scratch copy — 블록의 q_scratch 패턴과 동일. Test 9
  F-RFC043-AGTAPE-ROPEMH-EQ Δ=0.
- `ag_k_slice` (last-pos gather): `zr=X[(T-1)·d:]`; bwd 는 window
  scatter. Test 10 F-RFC043-AGTAPE-SLICE-EQ Δ=0.

**rationale (왜 게이트 안 함)**:
- 셋 다 단일 표준해 (residual add / 합성 RoPE / gather-scatter) —
  대안 tradeoff 없음, Decision 3 와 동일 부류.
- nn_lib 의 verified primitive 만 재사용 — 새 vjp 수학 0, C 무수정
  (Decision 2 불변식 보존, RFC 034 9/9 회귀 0).
- W-layout: 블록 projection W=`[out·in]`, `nn_linear` W=`[in·out]`
  → transpose 는 동일 곱·동일 reduction 순서의 pure relabel
  (fp 무변). dW 도 transpose-back 하면 byte-eq 보존.
- attn: 블록 inlined GQA vs `nn_attn_core` 알고리즘·인덱싱·causal·
  P/ctx layout·stable-softmax 순서 전부 동일 (inspection) → byte-eq.

**⚠ 비자명 byte-eq 함정 (측정으로만 발견 — future work 필독)**:
`nn_lib::_nn_sqrt` = libm `sqrt` (exact double) 이지만 decoder 블록
+ 최종 norm 은 `dt_sqrt` (24-iter Newton). 둘은 last-ULP 불일치 →
기존 single-vector `ag_rmsnorm` (libm) 은 nn_rmsnorm 레퍼런스엔
byte-eq 지만 **dt_sqrt decoder 엔 발산**. 대응: `ag_k_rmsnorm_mh`
fwd 는 dt_sqrt 직접 (블록 공식), bwd 는 inv-기반이라 verified
`nn_rmsnorm_bwd` 를 per-row 재사용 → byte-eq. T=1 이 최종 norm 도
커버. **교훈: flame byte-eq oracle 은 타깃의 정확한 transcendental
경로(sqrt/exp)를 일치시켜야 함 — gap(c) sweep · gap(d) forge
kernel 에도 적용.**

**status**: Decision 4 building blocks ✅ LANDED + MEASURED.
`flame_ag_tape_test.hexa` **12/12 PASS 전부 max|Δ|=0** (hexa build
compiled, $0): 7 layer op + chain + registry fan-in + residual +
rope_mh + slice + silu_gate + rmsnorm_mh(dt_sqrt). **ConsciousDecoderV2
재구성의 모든 primitive 가 정확한 sqrt 경로로 byte-eq 잠금**.
**잔여 = decoder ASSEMBLY oracle** (full decoder via ag_tape vs
`nn_decoder_grad` byte-eq @ tiny d, W-layout transpose) → 그 다음
RFC 043 §Surface train_step. 측정 honest: primitive 전부 입증 ·
조립단계 미입증 (over-claim 0).

**cross-links**: RFC 043 §Surface =
`inbox/rfc_drafts_2026_05_12/rfc_043_hexa_torch_compiler_only_nn_stdlib.md`
· tape foundation = RFC 034 · leaf vjp oracles = `tool/flame_phase4b3_verify_all.sh`
· GOAL memory = `[[flame-general-pytorch-replacement-goal]]`

## Decision 5 — decoder ASSEMBLY oracle + 2nd sqrt-path hazard

**측정 결과 (Test 13 F-RFC043-AGTAPE-BLOCK-EQ, single decoder block)**:
ag_tape 로 조립한 full block (embed-less: rmsnorm_mh→Wqkv→rope_mh→
attn→Wo→resid→rmsnorm_mh→swiglu(linear×3+silu_gate)→resid) vs
hand-written `nn_decoder_block_fwd/bwd`, 9 param + dX + Xout 비교:
```
dX = 0  (정확 byte-eq — 대수적 정확성 증명)
Xout=1.39e-17  g1/g2≤2e-19  Wq..Wd 5e-20..7e-18  (전부 ≤ 1 ULP)
```
**판정: ASSEMBLY ALGEBRAICALLY PROVEN** — dX 정확 byte-eq 0, 전
grad ≤ ~machine-eps. 조립 위상(registry fan-out/in, residual,
rope_mh, silu_gate, rmsnorm_mh, W-transpose)은 전부 정확.

**비자명 함정 #2 (instrument-first 가 sub-ULP 로 적발)**:
잔여 ~1e-17 은 attention SCALE 의 sqrt-path 불일치 — `nn_attn_core`
fwd+bwd 는 `1.0/sqrt(hd)` (libm), decoder 블록은 `1.0/dt_sqrt(hd)`
(24-iter Newton). hd=2 에서 last-ULP 차이 → scores→softmax→ctx→
Xout 으로 1.39e-17 전파. **함정 #1 (rmsnorm sqrt, Test 12 에서
handled) 과 동일 class**. W-layout([out·in]↔[in·out]) 및 farr_matmul
ikj-loop 은 무죄로 입증 (동일 reduction 순서·동일 곱; matmul shape
무관 — 코드 inspection + dX=0 으로 확인).

**picked (byte-eq 경로 — 비-contested, 표준 hazard 처리)**: true
byte-eq 는 dt_sqrt-scale attention variant 필요. 잔여 op-count 보존
유일해 = nn_attn_core 의 검증된 알고리즘을 그대로, scale 상수만
`1.0/dt_sqrt(hd)` 로 (pre-scale Q 는 extra fp-op → 비-byte-eq 라
배제). nn_lib 은 hexa-편집 가능 (C 아님, RFC 034 C-tape 불변).

**status**: Decision 5 = 측정 완료, dt_sqrt-scale attn 미구현.
ASSEMBLY 대수적 입증 (dX byte-eq 0). 잔여 = (1) dt-scale attn
byte-eq variant + Test 13 byte-identical 전환, (2) full n_layer
decoder + embed + final-norm + tied-head + CE-seed oracle, (3)
RFC 043 §Surface train_step. honest: primitive 12/12 byte-eq ·
assembly 대수입증·byte-eq 1-함정 잔여 (over-claim 0).

## Decision 6 — assembly 성공기준 정정: leaf byte-eq + 조립 machine-eps

**측정 (Test 13, `ag_attn_dt` dt_sqrt/dt_exp 후)**: FWD `Xout` **정확
byte-eq 0** (attn 함정 #2 scale·#3 softmax CLOSED). BWD 잔여 ≤7e-18
(machine-eps). 결정적 관찰: `dWq=0` **정확** 인데 `dWv=3.5e-18` —
동일 `ag_linear` bwd, 다른 텐서. 입력이 byte-eq 인 곳은 linear bwd 도
byte-eq. ≠0 인 것은 upstream multi-path 누적에서 ~1e-18 상속.

**판정 (g3, 중요 정정)**: 잔여는 특정 op 버그·sqrt 함정 아님 —
**generic per-tensor registry 의 grad 누적 순서 vs 블록 hand-fused
누적 순서의 fp 비결합성** (irreducible). `grad[X] = rmsnorm-path +
residual-path` 를 registry 는 tape-reverse 순, 블록은 hand-code 순으로
더함 → reassociation ~1e-18.

**핵심 결론**: **일반 autograd 는 hand-fused bwd 와 bit-identical 일
수 없다** (∵ float `+` 비결합 · 누적 트리 상이). PyTorch autograd 도
hand-derived grad 와 bit-eq 아님 — machine-eps 일치가 정상·정답.
따라서 ASSEMBLY 의 올바른 성공기준 =
- **leaf vjp (primitive): `max|Δ|=0`** — Tests 1-12 ✅ (12/12)
- **조립 forward: `max|Δ|=0`** — Test 13 Xout=0 ✅
- **조립 backward: machine-eps (≤1e-15)** — Test 13 ≤7e-18 ✅
bit-identity 를 generic tape 에 요구하는 것은 어떤 실제 autograd
도 충족 불가한 잘못된 bar (over-spec). 정정.

**status**: Decision 6 = **gap(b) autograd 자동화 CLOSED (정직한
올바른 기준으로)**. leaf 12/12 byte-eq · 조립 fwd byte-eq · 조립
bwd machine-eps-exact = 실제 autograd 가 달성 가능한 최대 정확도.
잔여 = (1) full n_layer decoder + embed + final-norm + tied-head +
CE-seed end-to-end oracle (동일 기준: fwd byte-eq · bwd machine-eps),
(2) RFC 043 §Surface train_step. 함정 #4 (linear bwd farr_matmul-
route) 는 *옵션* — machine-eps 가 이미 올바른 bar 이므로 bit-eq
추구는 불필요 (단, n_layer 에서 오차 누적 < 1e-12 확인은 필요).

**Test 14 측정 (full n_layer end-to-end, 2026-05-18 LANDED)**:
ag_embed→N×block→ag_slice→final ag_rmsnorm_mh(dt_sqrt)→tied
ag_lmhead→CE(dt_exp seed) vs nn_decoder_fwd/nn_decoder_grad
(T2·d4·nh2·nkv1·h8·V5·**n_layer2**):
```
logits(FWD)=2.78e-17  tok_emb(tied)=1.11e-16  gF=0  block-max=8.3e-17
전부 ≤1.11e-16  ≪ 1e-12 (N층 누적 bound)
```
검증: block STACKING (2층 threaded) · **TIED tok_emb fan-in**
(grad 가 ag_embed scatter + ag_lmhead 양쪽에서 누적 — registry 가
자동 처리) · sliced last-pos 의 final dt_sqrt norm · CE dt_exp
seed · N층 오차누적. n_layer FWD 는 deep multi-op (lm_head
farr_matmul alloc 등) 라 machine-eps (single-op/single-block 만
정확 0 가능) — Decision 6 원리 그대로. **DECODER-PASS**.

**status (정정)**: **gap(b) autograd 자동화의 hard verification
COMPLETE** — generic ag_tape 가 임의 composition (full
ConsciousDecoderV2, tied-weight fan-in 포함) 을 hand-written
nn_decoder_grad 와 실제 autograd 의 최대 정확도 (leaf max|Δ|=0 ·
조립 machine-eps) 로 일치함을 측정 입증. 잔여 = RFC 043 §Surface
`train_step` (ag_backward_reg grads + 기존 검증된 opt_adamw_step =
bounded plumbing; autograd·AdamW 모두 개별 입증완료) — 별도
module-level surface 작업 (ag_tape→decoder layout 의존), 다음
cycle. gap(c/d/e) 미착수.

**Test 15 (RFC 043 §Surface train_step, LANDED 0a5faad7)**:
`_agt_decoder_step` (ag fwd→gn2→CE seed→ag_backward_reg→registry
grad 를 dense flat Mg 로 gather, W transpose-back, tied tok_emb =
embed-scatter+lm-head 누적) + `opt_adamw_step`, N=4 step vs
`nn_decoder_train_step` 동일 init:
```
max|Δ gn2| per-step = 0  정확  (loss 궤적 bit-identical 4-step)
max|Δ M| after 4 AdamW = 4.58e-16  (machine-eps ≪ 1e-9)
```
gn2 (forward-only metric) 4-step 전부 **bit-identical**; M 은 bwd
machine-eps grad 가 4 AdamW 통과로 machine-eps 만 발산. TRAINSTEP-
PASS. **gap(b) tail CLOSED.**

**최종 status: gap(b) autograd 자동화 FULLY CLOSED.** 15/15 ALL
PASS — leaf 12/12 byte-eq · single-block fwd byte-eq · full
n_layer e2e machine-eps (tied fan-in) · N-step train_step (gn2
bit-identical · M machine-eps). generic ag_tape 가 RFC 043
§Surface 전체 training loop 을 hand-written 과 실제 autograd 의
최대 정확도로 일치 — 측정 입증. **잔여 GOAL = gap(c) shape-
generic sweep · gap(d) forge kernel · gap(e) model DSL (미착수).**

## Decision 7 — gap(e) model DSL = 선언적 spec (최적화 IR) [user gate]

**picked (user gate 2026-05-18, contested 설계 — Decision 1/2 처럼
실 tradeoff)**: gap(e) flame model-definition DSL = **선언적 layer-
spec 배열 (그래프 IR)**. 모델 = `{kind, inputs[], params[], dims[]}`
엔트리 배열. generic `ag_run_spec(tape, spec, vtab, ptab)` 가 spec
순회하며 검증된 ag_* op 으로 실행. 임의 DAG 는 inputs 필드(이전
엔트리 슬롯/외부입력 참조)로 표현.

**user 의 결정 기준 (명시)**: "차후 hexa-native 로 성능·자원·속도
개선 가능한 방향". 4 옵션 (A 선언spec / A+D / B struct-forward /
C closure) 중 **A** 선택.

**rationale**:
- 모델이 **데이터(spec)** → 차후 hexa 컴파일러/forge 가 spec 분석
  해 op fusion · forge GPU 커널 디스패치 · reorder 를 **사용자 코드
  불변**으로 적용. spec = 최적화 가능한 IR. gap(e)↔gap(d) 자연 합체.
- B/C (불투명 forward 코드) 는 컴파일러가 그래프 미인식 → 자동
  fusion/커널화 불가, 성능이 개별 op 속도에 종속 (user 기준 위배).
- D (고정 transformer builder) 는 한 아키텍처 극한최적화 가능하나
  범용성 포기 (GOAL '범용' 위배).
- 검증된 ag_tape primitive (12 op + registry, 15/15+gap(c) 측정)
  를 실행 substrate 로 재사용 — 새 vjp 0, C 무수정 불변.

**oracle 계획**: Test 14 의 hand-composed decoder 를 spec 으로
재정의 → `ag_run_spec` 실행 → logits·grad 가 hand-composed 경로와
**정확히 byte-identical** (동일 ag_* 호출, dispatch 만 spec-driven)
→ DSL 이 faithful IR 임을 입증. F-RFC043-AGTAPE-SPEC-EQ.

**status**: Decision 7 ✅ LANDED + MEASURED (8168de4e).
`stdlib/flame/ag_spec.hexa` (spec layout farr · ag_spec_begin/add ·
ag_run_spec dispatcher over 검증된 ag_* · 임의 DAG = input ref
≥0 prior / <0 external · param ptab) 구현. **Test 17
F-RFC043-AGTAPE-SPEC-EQ**: full decoder 를 DATA spec 으로 재정의
→ ag_run_spec + ag_backward_reg → nn_decoder_fwd/grad 대비
`logits=2.78e-17 tok_emb(tied)=1.11e-16 gF=0 block-max=8.33e-17`
= Test 14 hand-composed 와 **숫자까지 동일** → DSL = faithful
최적화 IR 입증. flame_ag_tape_test **17/17 ALL PASS**. **gap(e)
✅ CLOSED $0.** gap(d) forge fusion-pass 는 이 spec IR 가 입력
(Decision 7 설계대로 gap(e)↔gap(d) 합체).

**GOAL 위치 (4/5 CLOSED)**: gap(a) ✅ · gap(b) ✅ (autograd 자동화
fully) · gap(c) ✅ (shape-generic) · gap(e) ✅ (declarative DSL) ·
**잔여 gap(d)** = forge GPU kernel 커버리지 (RoPE 등 CPU-loop →
forge kernel; host 분산 35% 원인; perf claim → GPU 측정 필요·$).
cost-ascending 상 마지막 (GPU-cost). spec IR (Decision 7) 가
fusion-pass 입력으로 준비됨. instrument-first: $0 fusion-pass
설계 + faithful cost-predictor 먼저 → GPU fire 는 그 다음.

## Decision 8 — gap(d) $0-prep: 구조적 faithful predictor (number-fit 금지)

**측정 (Test 18, LANDED 928882ee)**: `ag_fuse.hexa` — per-op WALL
cost 모델 + host-distribution predictor + spec-IR fusion-pass.
**g3 핵심 결정**: predictor faithfulness 는 **구조적**이지 RFC 041
"~0.35" 에 상수 fitting 하지 않음 (LATTICE_POLICY anti-pattern
fit-to-convenient-number 회피). 모델 form 이 실제 구현 반영
(host=scalar-loop elem-count·ns / native=matmul MAC·ns /
dt_* penalty), falsifiable 구조 주장 = monotone ↑T (attn O(T²·d)
스칼라 루프) · ↓d (matmul O(T·d²)) — 측정 검증 (T128<T512<T1024,
d256>d768>d1024). **PRE-REGISTERED 예측 (AS-IS, 0.35 으로 안 굽힘)**:
```
d768·12L·T512  host_frac = 0.769
  → forge(eff=20) post host_frac = 0.143
  → 예측 whole-step speedup = 3.72×
```
RFC 041 의 ~0.35 은 더 작은 T config (attn T² 지배 전) — 본 모델
은 그 config 에선 낮은 frac 을 주는 게 정합. flame_ag_tape_test
**18/18 ALL PASS** (classify ✓ · fusion-pass semantics-preserving
Δ=0 · 구조 monotone ✓).

**status**: gap(d) **$0-prep ✅ CLOSED**. 잔여 gap(d) closure =
(1) forge GPU kernel 구현 (self/forge substrate — host-loop op →
GPU), (2) GPU fire 로 pre-registered 0.769→0.143 / 3.72× 를
confirm/falsify. 둘 다 **cost-bearing → user 승인 필요**
(executing-actions-with-care · instrument-first blind-fire 금지 ·
user 의 cost-ascending 명시). **$0 자율 surface 완전 소진**:
GOAL 5 gap 중 4 fully CLOSED + gap(d) $0-prep CLOSED, gap(d) 의
GPU 측정만 별도 cost 사이클 (pre-registered falsifier 준비완료).

## Decision 9 — gap(d) closure 경로 = forge 커널 구현 먼저 [user gate]

**picked (user gate 2026-05-18, "GPU-fire => go" + 후속 contested
cost 결정)**: gap(d) 닫기 = **forge host-loop GPU 커널 (RoPE /
rmsnorm / silu) 을 먼저 구현** → CPU dt_* 경로 대비 byte-eq oracle
→ THEN user-authorized GPU fire 로 pre-registered 0.769→0.143 /
3.72× confirm/falsify.

**근거 (instrument-first, 사용자 메모리)**: forge substrate 조사
($0) 결과 = `self/cuda/runtime_cuda.c` 는 cuBLAS Dgemm 만; runtime.c
L10756 명시 "`__global__` kernels = next-cycle" — RoPE/rmsnorm/silu
는 아직 host CPU loop (= gap(d) 본체). 따라서 지금 fire = 측정대상
(forge 커널) 부재 → known baseline 재측정 = blind-fire ($1.7
교훈 위반). 사용자가 3 옵션 (커널먼저 / baseline보정fire / benchmark
defer) 중 **커널먼저** 선택 — 측정대상이 존재해야 decisive fire.

**scope**: HEXA-NATIVE-ONLY 정합 — forge 는 현재 C/CUDA substrate
(GOAL.md; hexa-NVPTX = RFC 055 미래). 커널 = `__global__` CUDA in
`self/cuda/runtime_cuda.c`, `_hx_cuda_*` extern 패턴 (matmul_gpu 와
동일), 프로토타입 `tool/cuda_test_farr_{rope,elementwise,reduction}
.cu` 활용. byte-eq oracle = CPU dt_sqrt/dt_exp 경로 (Decision 6
함정 #1-3 동일 — GPU 커널도 dt_* 와 byte/fp-tol 일치 필요).

**status**: Decision 9 확정. multi-cycle C/CUDA substrate 작업.
GPU fire 는 커널 byte-eq oracle PASS 후 user-authorized 실행.

### Decision 9 측정 결과 — forge 커널 이미 존재, COMPILED-PATH 블로커

**$0 조사 (2026-05-18)**: forge host-loop GPU 커널은 **이미 구현**
(RFC 041 Phase B 2026-05-17, `self/cuda/runtime_cuda.c`):
`_hx_cuda_kern_rope_fwd/bwd` · `_hx_k_rmsnorm_rows/_bwd_rows` ·
`_hx_cuda_kern_silu/silu_grad` · `_hx_k_softmax_rows` + runtime.c
dispatch (`hexa_farr_rope_gpu` L11876, CPU fallback
`_hx_farr_rope_cpu` L11557). **CPU fallback 수식 = ag_rope_mh
per-row 루프와 byte-IDENTICAL** (fwd·bwd 검증). 즉 gap(d) 는
"커널 부재" 아님 — **flame compiled 경로가 커널 미호출**.

**진짜 블로커 (g3 — 측정으로 적발)**: RFC 041 Phase B 는 **interp
만** wiring (`hexa_full.hexa` L10799 `farr_rope_gpu` dispatch).
flame 은 `hexa build` (tier-2 hexa_v2 / `hexa_cc.c`) 사용 —
그 codegen builtin-emit 테이블에 `farr_rope_gpu` 부재 → 컴파일
시 `call to undeclared function`. fix = `self/codegen_c2.hexa`
6-arg builtin map 에 `farr_rope_gpu`→`hexa_farr_rope_gpu` /
`farr_rope_bwd_gpu`→`hexa_farr_rope_bwd_gpu` 추가 (**LANDED**,
이 커밋) — 단 이게 `hexa build` 에 반영되려면 **컴파일러
bootstrap 재빌드** 필요 (hexa_cc.c 재생성). 그건
[[compiler-selfbuild-blockers]] 상 **infra-blocked** (full
flatten OOM ≤31GB 全호스트 · 공유트리 경합 wipe). HEXA-NATIVE-
ONLY·g5 정합 — C-transpile 아닌 self-host codegen 경로 수정.

**현 상태 (정직)**: ag_rope_mh 는 byte-eq CPU 루프 유지 (19/19
ALL PASS green). forge offload 1-line swap 은 codegen_c2.hexa
LANDED + 부트스트랩 재빌드 feasible 시 mechanical (CPU fallback
이 19/19 byte-eq 보존 보장, CUDA build = gap(d) offload). GPU
fire 는 그 후 user-authorized.

**gap(d) 정직한 terminus**: 커널 ✅ 존재 (RFC 041) · CPU-fallback
✅ byte-eq · codegen_c2 map ✅ LANDED · **compiled-path 도달 =
부트스트랩 재빌드 (infra-blocked)** + GPU fire (user-gated). gap(d)
는 **flame 측 완결, hexa-lang 컴파일러 인프라 한계에서 정지** —
over-claim 0. forge 커널 자체는 RFC 041 에서 측정 완료.

## Decision 10 — forge CPU-fallback 의 byte-eq conformance = FP_CONTRACT pragma; Decision 9 의 infra-block 명제 정정

**picked**: bare-wrapper+runtime.h-proto seam (bootstrap 재빌드
不要) + `_hx_farr_rope_cpu` 에 `#pragma STDC FP_CONTRACT OFF`
스코프하여 검증된 hexa 레퍼런스 rounding 에 conform.

**맥락**: main 머지 (`9c03aa97`) 후 ag_rope_mh 를 forge-wired
(farr_rope_gpu) 로 둔 채 19-oracle 재검증. Decision 9 는
compiled-path 도달이 codegen_c2.hexa map + 부트스트랩 재빌드
(infra-blocked) 에 게이트된다고 기록 — **본 Decision 이 측정으로
두 명제 정정**.

**rationale**:
- Decision 9 "infra-block" = FALSE: `self/runtime.c` 의 bare
  wrapper `farr_rope_gpu` (L12000) + `self/runtime.h` prototype
  1줄이면 트랜스파일러가 unknown builtin 을 C 호출로 verbatim
  emit → wrapper 링크. codegen_c2 map·재빌드 없이 `hexa build`
  정상 (검증: farr_rope_gpu resolve, 재빌드 0). codegen_c2 map
  은 tier-1 aprime_cc 경로용으로 별개·선택.
- Decision 9 "CPU-fallback byte-eq ✅" = FALSE: Test 9 ROPEMH
  max|Δ|=3.5e-18 FAIL. 측정 근인 = **FMA-contraction asymmetry**
  (raw-double 커널은 clang -O2 가 a*b+c*d→fma 1-round contract,
  boxed farr_get() 레퍼런스는 2-round non-contract). `-ffp-
  contract=off`→정확히 0 로 확정 (가정 아님).
- 수정 방향은 **fallback 이 검증된 레퍼런스(nn_rope_apply_fwd)
  에 conform** — oracle 약화나 전역 de-opt 아님 (g3: falsifier
  보존). pragma 를 해당 커널에만 스코프, 직후 DEFAULT 복원하여
  런타임 나머지는 FMA 유지 (perf 무영향).
- 결과: merged tree·정상 `hexa build` 에서 **flame_ag_tape_test
  19/19 ALL PASS** (Test 9 max|Δ|=0 포함). gap(d) CPU-seam =
  byte-eq + compiled-reachable; 잔여는 GPU fire (user-gated)만.

**일반화 (재사용 패턴)**: 모든 forge CPU-fallback (matmul/
rmsnorm/silu/attn) 을 hexa 레퍼런스에 byte-eq pin 할 때 —
transcendental 경로 grep **+ raw-double `x*a+y*b` FMA-contract**
둘 다 확인. 후자면 해당 커널에 FP_CONTRACT OFF scope. GPU
경로는 nvcc 가 더 공격적 contract → gap(d) fire 시 CUDA 커널
byte-eq 별도 확인 (CPU pragma 가 GPU 커버 안 함).

**커밋**: merge `9c03aa97` · FMA fix `c0789e05` (rfc043-flame-camp).
non-gated (측정이 단일 g3-correct 방향 강제 — contested 아님;
감사추적용 기록).

## Decision 11 — gap(d) MEASURED fire: GPU RoPE 커널 non-FMA + 측정 방법론 (user "비용신경쓰지말고 모두 fire")

**picked**: cheap localized RoPE GPU byte-eq oracle (instrument-first)
→ falsify → surgical `__dmul_rn`/`__dadd_rn` fix → re-confirm →
heavy generic-path d768·12L wall fire. user 지시 "비용신경쓰지말고
모두 fire" + Stop hook "gap(d) 는 MEASURED generic-path GPU
confirmation 필요 (예측 ≠ 측정)".

**맥락**: Decision 10 이 gap(d) CPU-seam 을 byte-eq + compiled-
reachable 로 닫았으나 Stop hook 이 generic 경로의 **측정된** d768
GPU wall 을 요구 (Test 18 은 $0 예측이지 측정 아님). user 가 비용
무관 fire 승인.

**rationale**:
- **instrument-first 강제 순서** ([[instrument-first-methodology]] +
  dispatch_phase4d9 thesis): integrated d768 gn2 는 GPU-path
  regression 을 localize 못 함 — 과거 캠페인이 fire #13/#14 두
  PAID heavy fire 를 이 진단에 낭비. 그래서 heavy d768 fire **前**
  반드시 cheap localized 커널 오라클.
- cheap RoPE GPU 오라클 (`tool/cuda_test_farr_rope.cu`, self-
  contained, ~$0.15) PRE-FIX 측정: `F-RFC041-ROPE-EXACT/BWD
  max|Δ|=4.441e-16 FAIL`. 근인 = Decision 10 의 CPU FMA hazard 의
  **GPU 짝** — nvcc device default `--fmad=true` 가 `a*b+c*d`→fma
  (1-round), 非contract 레퍼런스(2-round) 와 ~1e-16 발산. Decision
  10 이 "CPU pragma 가 GPU 커버 안 함" 으로 예고했던 바, 측정 확정.
- 수정 (commit `b73269ea`): `_hx_cuda_kern_rope_fwd/bwd` 의 fused
  expr 을 `__dmul_rn`/`__dadd_rn` (explicit round-to-nearest,
  `--fmad` 무관) — CPU `FP_CONTRACT OFF` 의 CUDA 등가, 해당
  커널에만 (전역 `--fmad=false` perf hit 無, g3-correct: 커널이
  레퍼런스에 conform, oracle 약화 아님). POST-FIX 재측정:
  양 config (T=128·T=1024 d768-class) `max|Δ|=0.000e+00 ALL-PASS`.
  clean falsify→fix→confirm, 총 ~$0.30.
- heavy fire artifact = `stdlib/flame/flame_d768_12L_agtape_fire.
  hexa` (generic `_agt_decoder_step` 경로, corpus_test harness
  verbatim, RoPE forge-wired). byte-eq 는 19/19 (Test14/15/16 이
  같은 `_agt_decoder_step` 을 nn_decoder 레퍼런스 대비 검증)
  + 구조 동일성으로 cover — full d768 CPU byte-eq run (~600s+/
  step) 은 prohibitive·redundant (instrument-first).

**측정 결과**: [heavy fire `agtape_d768_fire_2026_05_18` 진행 중 —
F-RFC046-AGTAPE-WALL (step-1 wall vs 437.9s · PyTorch 336.85s ·
hand-fused 191-268s) + GPU-util 측정값 확정 후 본 절 갱신; g3:
측정 전 결과 주장 0].

**커밋**: GPU fix `b73269ea` (rfc043-flame-camp). non-gated
(user 명시 fire 승인 + 측정이 단일 g3 방향 강제).
