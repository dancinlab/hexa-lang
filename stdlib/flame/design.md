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
