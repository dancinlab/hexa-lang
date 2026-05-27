# RFC 059 — flame V3-extension backward (생성용 설계, INBOX #2 P1②)

- **Status**: design-only (NO autograd 구현). 닫힘 = 미래 에이전트가 구현 가능한 정밀도의 reverse-mode 설계 명세.
- **Date**: 2026-05-27
- **Scope**: `stdlib/flame` (Path-B 일반 autograd tape — `ag_tape.hexa`)
- **Source**: INBOX #2 P1② (anima `inbox/patches/anima-flame-v3-coverage-gaps.md`, 2026-05-26)
- **선행 PR**: #1481/#1482 — P1① full-position CE forward (`nn_lib::nn_lm_head_fwd_allpos` + `nn_ce_loss_allpos`)
- **번호 주의**: 기존 `docs/rfc/rfc_drafts_2026_05_12/rfc_059_flame_path_a_dual_head_multiterm_grad_purefieldffn.md` 는 **Path-A**(fused decoder, `decoder_lib`) 설계다. 본 RFC 는 동일 P1② 갭의 **Path-B**(generic `ag_tape`) backward 설계 — 같은 anima V3 표면을 다른 substrate 로 닫는다. 두 문서는 보완 관계이며, Path-A 의 §3.1/§3.2/§3.3 surface 정의를 본 RFC 가 ag_tape node-kind 로 재표현한다.

---

## 1. 요약

P1① full-position CE building block (`nn_lm_head_fwd_allpos` + `nn_ce_loss_allpos`)
은 PR #1481 로 landed 됐고 tiny-oracle 3/3 PASS 다. 그러나 이는 **검증된 forward
조각일 뿐, `ag_tape` reverse-mode 에 연결되어 있지 않다**. 학습 payoff(grad 흐름)
는 V3-extension backward 가 4 op (purefield · head_g · cross · tension_proj) 을
reverse-mode 로 `ag_tape` multi-objective 에 라우팅해야 발생한다.

본 RFC 는 그 backward 를 **설계**한다 (구현하지 않는다). 산출물은:
1. full-position CE → head backward 의 reverse-mode 명세
2. 4 V3 op 의 gradient (∂L/∂input, ∂L/∂param) + `ag_tape` 노드 표현
3. multi-objective grad 합성 방식 (기존 `ag_seed_grad` 메커니즘 위에)
4. grad-check 방법론 (finite-difference vs analytic, fp-tolerance — **byte-eq 아님**)
5. 구현 단계 P1②-a/b/c + 각 단계 verify gate

닫힘 정의(closure-is-physical-limit): 본 명세가 미래 구현 에이전트에게 충분히
정밀하면 닫힌 것이다. 코드가 아니라 spec 이 닫힘이다.

---

## 2. 현 상태

### 2.1 무엇이 landed 됐나 (P1①, PR #1481)

```
nn_lm_head_fwd_allpos(temb, Z, logits_out, T, V, d)
    logits_out[t·V + k] = Σ_j temb[k·d + j] · Z[t·d + j]      (t∈[0,T), k∈[0,V))
    # 행 t 마다 nn_lm_head_fwd(Z[t·d:]) 와 byte-eq

nn_ce_loss_allpos(logits, targets, T, V) -> float
    (1/T) Σ_t  −ln( softmax(logits[t·V .. t·V+V])[targets[t]] )
    # stable-softmax(row-max) + dt_exp/dt_ln + pt_safe floor (nn_decoder_ce_loss 와 동일)
```

### 2.2 ag_tape 현 구조 (stdlib/flame/ag_tape.hexa, 1508 lines)

테이프는 **단일 farr** (node v3). 헤더 4슬롯 + op 당 22슬롯:

```
TAPE farr 레이아웃
┌──────── header (4) ────────┐
│ [0] op count                │
│ [1] legacy chain-link tid   │
│ [2] reg_tids farr id  ───────────┐  per-tensor grad registry (Decision 3)
│ [3] reg_gids farr id  ───────────┤
└─────────────────────────────┘   │
                                   ▼
op n @ base = 4 + n·22         reg_tids: [0]=count, [1+i]=tensor tid
┌──────────────────────────┐   reg_gids: [1+i]=그 tid 의 누적-grad farr
│ +0      kind (AG_K_*)     │
│ +1..8   8 input/state ids │   reg_grad(tid,len): 첫 touch 시 zero-farr alloc+등록
│ +9..12  4 dims            │   reg_acc(tid,src,len): grad[tid] += src  (누적)
│ +13..18 6 param-grad ids  │
│ +19..21 3 input-grad ids  │
└──────────────────────────┘
(id 는 to_float/to_int round-trip 으로 farr 에 저장)
```

RECORD/REPLAY 흐름:

```
   forward 기록                          reverse 재생 (ag_backward_reg)
   ─────────────                         ─────────────────────────────
   ag_<op>(tape, ...)                    ag_backward_reg(tape, out_tid, seed)
     │ verified nn_lib fwd 호출            │ reg_acc(out_tid, seed)   ← loss seed
     │ bwd state(fwd cache) 저장           │ op = N-1 → 0 (latest→first):
     │ _ag_push → 노드 append              │   og = reg_grad(op.output_tid)
     ▼                                     │   nn_lib <op> bwd(og) → d_in, d_param
   [node N]                               │   reg_acc(input_tid, d_in)
                                          │   reg_acc(param_tid, d_param)
                                          ▼ ag_grad(tape, tid) 로 임의 grad 읽기
```

핵심: vjp math 를 재구현하지 않는다 — `nn_lib` (flame_nn_test 에서 byte-eq 검증)
의 bwd 를 그대로 재사용하고, registry 가 **누적**(fan-out·param-reuse·residual)
을 균일하게 처리한다. 13 op kind 존재: rmsnorm·linear·rope·lmhead·swiglu·embed·
attn·add·rope_mh·slice·silu_gate·rmsnorm_mh·attn_dt.

### 2.3 연결 안 된 것 (P1② 갭)

| 표면 | forward | ag_tape 노드 | reverse |
|------|---------|-------------|---------|
| last-pos lmhead | `nn_lm_head_fwd` ✅ | `ag_k_lmhead` ✅ | `nn_lm_head_bwd` ✅ |
| **full-pos head** | `nn_lm_head_fwd_allpos` ✅ #1481 | ❌ 없음 | ❌ 없음 |
| **full-pos CE** | `nn_ce_loss_allpos` ✅ #1481 | n/a (loss) | ❌ seed 없음 |
| head_g (dual) | 2× `ag_lmhead` (test 내) | `ag_k_lmhead` ✅ | ✅ (이미 동작) |
| cross / L_psi | `_mo_psi_loss_and_grad` (test 내) | ❌ loss-layer 미등록 | host 계산 |
| purefield FFN | ❌ 없음 | ❌ 없음 | ❌ 없음 |
| tension_proj / L_route | ❌ 없음 | ❌ 없음 | ❌ 없음 |

`flame_anima_multi_objective_test.hexa` 는 head_g + cross(L_psi) + L_phi 를
**host-side 로** 계산해 `ag_seed_grad`/`ag_backward_reg` 에 먹인다 — 즉 spine 은
증명됐으나 (1) full-position CE seed 가 tape 에 없고 (2) purefield/tension 은 아예
없다. P1② 는 이 7-row 표의 ❌ 들을 닫는다.

---

## 3. backward 대상 4 op

표기: `z` = post-finalnorm hidden [d] (단일 위치) 또는 `Z` [T·d] (전위치).
`dl` = upstream grad w.r.t. 해당 op output. `⊗` = outer product. `*` = 원소곱.

| op | forward 수식 | ∂L/∂input | ∂L/∂param | ag_tape 노드 표현 |
|----|-------------|-----------|-----------|------------------|
| **head_g** | `logits_g[k] = Σ_j W_g[k·d+j]·z[j]` (두 번째 독립-weight LM head, head_a 와 hidden 공유) | `∂L/∂z[j] = Σ_k dl_g[k]·W_g[k·d+j]` | `∂L/∂W_g[k·d+j] = dl_g[k]·z[j]` (= `dl_g ⊗ z`) | **재사용**: `ag_k_lmhead` + `nn_lm_head_bwd`. 두 번째 `ag_lmhead(tape, W_g, z, V, d)` 호출 = 새 노드. z 로의 grad 가 registry 에서 head_a 의 dz 와 **자동 누적**. 신규 kind 불필요. |
| **cross** (L_psi) | `c = cos(logits_a, logits_g) = dot/(‖a‖‖b‖)`; `L_ψ = c²/4` | `∂L/∂a[i] = (c/2)·(b[i]/(‖a‖‖b‖) − c·a[i]/‖a‖²)`; b 대칭 | (param 없음 — 순수 loss-layer; grad 는 a,b 두 logits 로만) | **신규 loss-layer**: tape 노드 아님. `ag_cross_psi_seed(tape, a_tid, b_tid, V)` 가 두 seed 를 계산해 `ag_seed_grad(a_tid)` + `ag_seed_grad(b_tid)` 로 주입(§5). reverse walk 가 양쪽 lmhead 노드로 전파. |
| **purefield** (PureFieldFFN) | `out = E_A(x) − E_G(x)`, 각 E = `Linear→GELU→Linear`; `tension = mean(out²)` | `∂L/∂x` = E_A·(+1) bwd + E_G·(−1) bwd 합. GELU' `= Φ(g) + g·φ(g)` (Φ=정규CDF, φ=정규pdf) | `∂L/∂{Wa_in,Wa_out,Wg_in,Wg_out}` = 각 Linear 의 dW (matmul vjp) | **신규 kind `ag_k_purefield`**. 노드 ids[x, Wa_in, Wa_out, Wg_in, Wg_out, hA, hG, out] dims[d, h]. bwd = 두 개의 (linear→gelu→linear) vjp 체인, d_out 가 E_A 에 +1·E_G 에 −1 분배. `nn_linear_bwd` 재사용 + 신규 `nn_gelu_bwd`. |
| **tension_proj** (L_route) | `t_l = mean(out_l²)` (per-layer); `L_route = λ_route·Σ_l t_l²` | `∂L_route/∂out_l[i] = λ·2·t_l·(2/N)·out_l[i] = (4·λ·t_l/N)·out_l[i]` (N = out 길이) | (param 없음) | **신규 reduction-seed**: 노드 아님. `ag_tension_route_seed(tape, out_tid_l, lambda, N)` 가 각 purefield 노드의 `out` tid 로 grad 를 `ag_seed_grad` 한다(§5). purefield bwd 가 이를 이어받아 x·param 로 전파. |

설계 결정 요약:
- **head_g**: 신규 노드 종류가 필요 없다. 기존 `ag_lmhead` 를 두 번 부르면 두
  `ag_k_lmhead` 노드가 생기고, registry 누적이 dual-head 를 공짜로 처리한다.
  (현 multi-obj test 가 이미 이렇게 동작 — Path-B 검증 완료 영역.)
- **cross / tension_proj**: tape 노드가 아니라 **loss-layer seed 함수**다. ag_tape
  의 멀티-출력 패턴(`ag_seed_grad`)에 정확히 맞는다 (§5). 신규 op-kind 0개.
- **purefield**: 유일하게 신규 op-kind + 신규 GELU primitive 가 필요한 부분.
  GELU bwd 가 현 nn_lib 에 부재(현재 `_nn_silu`/`_nn_sigmoid` 만 존재) — P1②-b
  에서 `nn_gelu_fwd`/`nn_gelu_bwd` 를 추가하거나, MVP 로 SwiGLU substitution
  (이미 `ag_k_swiglu` 존재)으로 치환 가능. §7 에서 단계 분리.

---

## 4. full-position CE → head backward

P1① 이 닫은 forward 를 reverse-mode 로 잇는다. 단일-위치 `ag_k_lmhead` 의
전-위치 일반화.

### 4.1 gradient 수식

```
loss        = (1/T) Σ_t −ln softmax(logits[t])[targets[t]]
∂L/∂logits[t·V+k]  =  (1/T) · ( softmax(logits[t])[k] − [k == targets[t]] )   ← seed dl[t,k]
∂L/∂Z[t·d+j]       =  Σ_k dl[t,k] · temb[k·d+j]                                ← hidden grad (per row)
∂L/∂temb[k·d+j]    +=  Σ_t dl[t,k] · Z[t·d+j]                                  ← tied-weight 누적 (모든 t)
```

행 `t` 별로 `nn_lm_head_bwd(temb, Z[t·d:], dl[t], dtemb_acc, dZ[t·d:], V, d)` 와
정확히 동일하다 (T=1 이면 기존 last-position 노드로 환원). temb 는 **누적**
(`nn_lm_head_bwd` 가 이미 `dtemb += dl ⊗ zT` 누적 시맨틱).

### 4.2 신규 노드 `ag_k_lmhead_allpos`

```
신규 kind: pub fn ag_k_lmhead_allpos() -> int { return 14 }

레코더:
  pub fn ag_lmhead_allpos(tape, temb, Z, T, V, d) -> logits_tid
    logits = t_zeros(T·V)
    nn_lm_head_fwd_allpos(temb, Z, logits, T, V, d)     # P1① forward 재사용
    _ag_push(kind=14, ids[temb, Z, logits], dims[T, V, d])
    return logits

CE seed 헬퍼 (loss → tape):
  pub fn ag_ce_seed_allpos(tape, logits_tid, targets, T, V) -> float
    # nn_ce_loss_allpos 재사용 + per-row (softmax − onehot)/T 를 dl 에 채움
    # ag_seed_grad(tape, logits_tid, dl)  로 주입 (registry 누적)
    # 합산 loss 반환
```

### 4.3 reverse 디스패치 (ag_backward_reg 에 case 추가)

```
} else if kind == ag_k_lmhead_allpos() {
    temb = ids[1]; Z = ids[2]; logits = ids[3]
    T = dims[9]; V = dims[10]; d = dims[11]
    og  = _ag_reg_grad(tape, logits, T·V)        # seed = (softmax−onehot)/T per row
    dtemb = t_zeros(V·d)                          # 누적 버퍼
    dZ    = t_zeros(T·d)
    t = 0
    while t < T {
        # 한 행씩 nn_lm_head_bwd 로: og[t·V:] → dtemb(누적), dZ[t·d:]
        nn_lm_head_bwd(temb, Z_row_t, og_row_t, dtemb, dZ_row_t, V, d)
        t = t + 1
    }
    _ag_reg_acc(tape, temb, dtemb, V·d)           # tied-weight 누적
    _ag_reg_acc(tape, Z,    dZ,    T·d)           # hidden grad → 다음 op(rmsnorm 등)로 chain
}
```

### 4.4 ASCII dataflow (forward → tape record → reverse replay)

```
 FORWARD                          TAPE RECORD                  REVERSE REPLAY
 ───────                          ───────────                  ──────────────
 Z[T·d] ── ag_lmhead_allpos ──►   node[k=14]                   ┌─ ag_ce_seed_allpos
 temb[V·d] ─┘     │               ids=[temb, Z, logits]        │   dl[t,k]=(softmax−onehot)/T
                  ▼               dims=[T, V, d]                │   ag_seed_grad(logits, dl)
            logits[T·V]                                         ▼
                  │                                       reg[logits] = dl
                  ▼               ag_ce_seed_allpos             │  ag_backward_reg walk:
            nn_ce_loss_allpos ──► loss (scalar)                 │   og=reg_grad(logits)
                                                                │   loop t: nn_lm_head_bwd
                                                                │     → dtemb += dl[t]⊗Z[t]
                                                                │     → dZ[t]  = Σ_k dl[t,k]·temb[k]
                                                                ▼   reg_acc(temb,dtemb)
                                                            reg[temb], reg[Z] 누적
                                                                │  (Z grad → 이전 finalnorm/
                                                                ▼   block 노드로 chain 계속)
```

T=1 일 때 §4.3 루프는 1회 → 기존 `ag_k_lmhead` 경로와 byte-eq (단일-행 oracle).

---

## 5. multi-objective grad 합성

V3 의 composite loss:

```
L = L_ce_full  +  λ_ψ·L_ψ(cross)  +  λ_φ·L_φ(entropy)  +  λ_route·L_route(tension)
```

`ag_tape` 는 이미 multi-objective 누적을 지원한다 — **`ag_seed_grad(tape, tid, seed)`
가 tape 를 walk 하지 않고 registry slot 에 grad 를 미리 누적**하기 때문이다. 여러
출력의 upstream-grad 를 walk 전에 pre-seed 한 뒤 `ag_backward_reg` 를 한 번 부르면,
backward 는 자기 seed 를 먼저 넣고 reverse 순회하며 각 op 의 input tid 로 누적하므로,
walk 시작 시 registry 에 있던 pre-seed 가 올바르게 합산된다 (이미 multi-obj test 가
입증한 패턴).

### 5.1 합성 절차 (caller 측)

```
 forward 기록 (tape 에 모든 op):
   X0 = ag_embed(...) → blocks → temb = finalnorm
   logits_a = ag_lmhead(temb, W_a)        # head_a (tied)
   logits_g = ag_lmhead(temb, W_g)        # head_g (independent)   ← §3 head_g
   # full-pos 시: logits_a = ag_lmhead_allpos(temb, Z)  (§4)

 loss-layer seed 계산 (pure functions of logits/out — tape 노드 아님):
   L_ce = ag_ce_seed_allpos(tape, logits_a, targets, T, V)         # §4: seed logits_a
   L_ψ  = ag_cross_psi_seed(tape, logits_a, logits_g, V, λ_ψ)      # §3 cross: seed BOTH a,g
   L_φ  = ag_phi_entropy_seed(tape, logits_a, V, λ_φ)              # entropy: seed logits_a
   L_rt = 0; for each purefield layer l:
            L_rt += ag_tension_route_seed(tape, out_tid_l, λ_route, N_l)  # §3 tension: seed out_l

 단일 reverse walk:
   ag_backward_reg(tape, logits_a, <zero or 0-len>)   # 모든 seed 는 이미 registry 에
   # (또는 마지막 미-seed 출력으로 walk 시작; 모든 pre-seed 가 합산되어 전파)

 grad 읽기:
   ag_grad(tape, W_a) / W_g / Wa_in / ... / tok_emb → AdamW step (caller-driven)
```

### 5.2 grad 합성 다이어그램

```
   L_ce ──seed──►┐
   L_φ  ──seed──►├─► reg[logits_a]  ──┐
   L_ψ  ──seed──►┘                    │  (head_a lmhead bwd)
   L_ψ  ──seed──► reg[logits_g] ──┐   ├─► reg[temb] 누적 ──► finalnorm bwd
                                  │   │                       ──► block stack bwd
   L_rt ─seed─► reg[out_l] ─┐     │   │                       ──► embed scatter
                            │     │   │
               (head_g bwd) ┴─────┘   │     모든 경로가 registry 에
               (purefield bwd) ───────┘     누적 → 단일 walk 로 합성
```

핵심: λ 가중치는 **seed 함수 안에서** 곱해진다 (caller 가 dl_total 을 손으로 합치는
현 test 패턴 대신, 각 seed 헬퍼가 `λ·∂L_term/∂output` 를 registry 에 += 한다).
backward walk 의 선형성(vjp 는 seed 에 선형)이 합성을 보장한다.

---

## 6. grad-check 방법론

### 6.1 finite-difference vs analytic (byte-eq 아님)

reverse-mode 는 fp 오차를 **누적**한다 (수십 op chain → 마지막 ULP 가 drift).
따라서 정답 대조는 byte-eq 가 **아니라** central finite-difference vs analytic-grad
의 상대오차 비교다.

```
analytic grad:   g_a = ag_grad(tape, θ)[i]                    # reverse-mode 결과
central diff:    g_fd = ( L(θ_i + ε) − L(θ_i − ε) ) / (2ε)    # 2회 forward
판정:            rel = |g_a − g_fd| / max(|g_fd|, atol)  ≤  TOL
```

- `ε` (probe step): `1e-5 ~ 1e-6` (double, central). 너무 작으면 catastrophic
  cancellation, 너무 크면 truncation O(ε²).
- **TOL**: `1e-4 ~ 1e-6` (central-diff 의 O(ε²) truncation + reverse-mode fp 누적의
  현실적 floor). byte-eq(0) 금지 — central-diff 자체가 근사다.
- libm-based central-diff 가 reference (메모리 `reference_codegen_change_verify_recipe`
  + flame `PERF.md` Phase 3-C libm-fd 8-probe, max rel 2.19e-09 의 방법론).

### 6.2 flame 기존 tolerance 컨벤션 (정렬)

| 비교 종류 | tolerance | 출처 |
|-----------|-----------|------|
| fwd cross-impl (matmul reduction-order) | fp-tol, RFC 040 §2.2 TOL_MATMUL class | `FLAME.tape` g3, `PERF.md` #4 |
| pure-scalar bwd (단일 op, 동일 reduction-order) | byte-eq (max\|Δ\|=0) | `flame_ag_tape_test` 13 leaf bars |
| **composed reverse-mode grad-check** (본 RFC) | **central-diff vs analytic, rel ≤ 1e-4~1e-6** | RFC 059 Path-A §5 (1e-7 probe), `flame_full_grad_exact_libm_test` |
| FMA-vs-scalar fp 동등 | ~1e-12 | RFC 040 §2.2 |

본 RFC 의 grad-check 는 **composed reverse-mode** 행이다 — 단일-op byte-eq 가 아니라
chain-누적 grad 이므로 central-diff rel-err 가 정답 게이트다. Path-A draft 가
`1e-7` 을 쓰는 것보다 본 Path-B 는 더 긴 op-chain(embed→blocks→finalnorm→dual-head)
을 통과하므로 `1e-6` 을 권장 floor 로, `1e-4` 를 hard-fail 상한으로 둔다.

### 6.3 tiny-config 검증 계획

```
config:  d=8, h=16, T=2, V=16, NL=1   (Mac smoke, 단일 위치 + 전위치 모두)
probe:   각 grad-bearing param 1~2개 좌표 (tok_emb, W_g, gF, Wa_in/Wa_out)
         + activation (out_l) — central-diff vs ag_grad
gate 매트릭스:
  - 단일 위치 (T=1): ag_lmhead_allpos ≡ ag_lmhead byte-eq (회귀)
  - 전위치 (T=2): full-pos CE seed → temb/Z grad central-diff rel ≤ 1e-6
  - dual-head: head_g grad 가 head_a grad 와 registry 에서 합산 (§5) — 4-probe
  - cross/tension seed: pre-seed 선형성 (L_ψ-only Mg + L_route-only Mg == 합성 Mg)
  - purefield: Wa_in/Wa_out/Wg_in/Wg_out 4-probe central-diff (GELU bwd 정확성)
```

각 게이트는 falsifier ID 를 가진다 (§7 표). over-claim 0 (g3): extension OFF 시
기존 falsifier(`flame_ag_tape_test` 13 leaf, `flame_anima_multi_objective_test`)
가 byte-identical 로 통과해야 한다.

---

## 7. 구현 단계

세 단계, 각각 default-OFF / 기존 byte-eq 보존 / 독립 verify gate.

### P1②-a — head backward 먼저 (full-position CE → head)

- **surface**: `ag_tape.hexa` — 신규 kind `ag_k_lmhead_allpos()=14`, 레코더
  `ag_lmhead_allpos`, seed 헬퍼 `ag_ce_seed_allpos`, `ag_backward_reg` 에 case 추가
  (§4). `nn_lib` 변경 없음 — `nn_lm_head_fwd_allpos`(#1481) + `nn_lm_head_bwd`
  재사용.
- **이유 (먼저)**: 가장 작은 표면 + P1① 위에 직접 얹힘 + 신규 math primitive 0개.
  학습 payoff(전-위치 supervision)의 최단 경로.
- **verify gate**:
  - `F-RFC059B-ALLPOS-T1-BYTEEQ`: T=1 일 때 `ag_lmhead_allpos` reverse ≡
    `ag_lmhead` reverse, max\|Δ\|=0 (단일-행 환원).
  - `F-RFC059B-ALLPOS-GRADCHECK`: T=2, central-diff vs analytic on temb/Z,
    rel ≤ 1e-6.

### P1②-b — 4 op backward (purefield · head_g · cross · tension_proj)

- **surface**:
  - head_g: 신규 코드 0 — `ag_lmhead` 2회 호출 패턴 문서화(이미 동작).
  - cross: 신규 seed 헬퍼 `ag_cross_psi_seed(tape, a, b, V, λ)` (`_mo_psi_loss_and_grad`
    의 grad 식을 `ag_seed_grad` 양쪽 주입으로 래핑).
  - tension_proj: 신규 seed 헬퍼 `ag_tension_route_seed(tape, out_tid, λ, N)`.
  - purefield: 신규 kind `ag_k_purefield()`, `nn_gelu_fwd`/`nn_gelu_bwd`(nn_lib),
    레코더 `ag_purefield`, bwd case. **GELU 부재** — MVP 는 SwiGLU substitution
    (`ag_k_swiglu` 재사용)으로 시작하고 GELU 는 sub-cycle 분리 가능.
- **verify gate**:
  - `F-RFC059B-HEADG-DUAL-GRADCHECK`: dual-head 4-probe central-diff rel ≤ 1e-6.
  - `F-RFC059B-CROSS-PSI-SEED`: L_ψ seed 가 a,b 양쪽으로 전파, 2-probe rel ≤ 1e-6.
  - `F-RFC059B-PUREFIELD-GRADCHECK`: Wa_in/Wa_out/Wg_in/Wg_out 4-probe rel ≤ 1e-6
    (GELU 또는 SwiGLU substitution variant 별도).
  - `F-RFC059B-TENSION-ROUTE-SEED`: tension grad 가 out_l 로 주입 후 FFN bwd 전파,
    1-probe rel ≤ 1e-6.

### P1②-c — multi-objective 합성

- **surface**: §5 의 합성 절차를 `flame_anima_multi_objective_test.hexa` 의
  full-position·dual-head·purefield 변형으로 묶음 (caller-side, seed 헬퍼 조합).
  신규 stdlib 코드 최소 — 기존 `ag_seed_grad` + P1②-a/b 헬퍼 조립.
- **verify gate**:
  - `F-RFC059B-MULTIOBJ-LINEARITY`: (L_ce-only Mg) + (L_ψ-only Mg) +
    (L_route-only Mg) == (합성 Mg), central-diff vs analytic, rel ≤ 1e-6
    (reverse-mode 의 seed-선형성).
  - `F-RFC059B-MULTIOBJ-DESCENT`: tiny-config 5-step composite loss 단조 감소
    (sanity, byte-eq 아님).
  - `F-RFC059B-VANILLA-PRESERVE` (hard): extension OFF 시 `flame_ag_tape_test`
    13 leaf bars + `flame_anima_multi_objective_test` byte-identical.

### 7.1 falsifier 배터리 요약

| ID | 단계 | 측정 |
|----|------|------|
| F-RFC059B-ALLPOS-T1-BYTEEQ | a | T=1 reverse ≡ 기존 lmhead, max\|Δ\|=0 |
| F-RFC059B-ALLPOS-GRADCHECK | a | T=2 central-diff rel ≤ 1e-6 (temb/Z) |
| F-RFC059B-HEADG-DUAL-GRADCHECK | b | dual-head 4-probe rel ≤ 1e-6 |
| F-RFC059B-CROSS-PSI-SEED | b | L_ψ 양방향 seed 2-probe rel ≤ 1e-6 |
| F-RFC059B-PUREFIELD-GRADCHECK | b | 4-weight 4-probe rel ≤ 1e-6 |
| F-RFC059B-TENSION-ROUTE-SEED | b | tension seed 1-probe rel ≤ 1e-6 |
| F-RFC059B-MULTIOBJ-LINEARITY | c | seed-선형 합성 rel ≤ 1e-6 |
| F-RFC059B-MULTIOBJ-DESCENT | c | 5-step composite loss 단조 감소 |
| F-RFC059B-VANILLA-PRESERVE | a/b/c | extension OFF byte-identical |

---

## 8. 참고

- **PR #1481/#1482** — P1① full-position CE forward (`nn_lm_head_fwd_allpos` +
  `nn_ce_loss_allpos`, tiny-oracle 3/3 PASS). 본 RFC 의 출발점.
- **`stdlib/flame/ag_tape.hexa`** — ag_tape 현 구조 (node v3, 13 op kind, registry
  Decision 3, `ag_seed_grad`/`ag_backward_reg`). §2.2 다이어그램의 SSOT.
- **`stdlib/flame/nn_lib.hexa`** — `nn_lm_head_bwd`(L655), `nn_linear_bwd`(L93),
  `nn_swiglu_bwd`(L415) — 재사용할 vjp primitive.
- **`stdlib/flame/flame_anima_multi_objective_test.hexa`** — head_g + L_ψ + L_φ
  multi-objective spine (host-side seed → `ag_seed_grad`). §5 합성의 prior art.
- **RFC 040 §2.2** — fp-tolerance class (TOL_MATMUL fp-tol vs FMA-vs-scalar ~1e-12).
  `FLAME.tape` g3 + `PERF.md` #4 가 인용. §6 grad-check tolerance 의 기준.
- **`docs/rfc/rfc_drafts_2026_05_12/rfc_059_flame_path_a_dual_head_multiterm_grad_purefieldffn.md`**
  — 동일 P1② 갭의 **Path-A**(fused decoder) 설계. 본 RFC 는 Path-B 대응물.
  Path-A §5 의 central-diff 1e-7 grad-check 컨벤션과 정렬.
- **INBOX #2 line 10** — cross-repo handoff 추적 (anima ConsciousDecoderV3 포팅).
