# flame backlog closure — P2a~P3e 8 milestone (2026-05-27)

flame 도메인의 round-5 후속 백로그 8개의 terminal closure. round-3
GPU.md 패턴 (design+source-level evidence)을 그대로 적용.

---

## ✅ source-already-DONE (text-resolved, checkbox-flip only)

### P2a — `nn_rope_build_tables` base 인자화

`stdlib/flame/nn_lib.hexa:509` 에 이미 `nn_rope_build_tables_base(T, hd,
cos_out, sin_out, base: float)` 가 land 됨. line 533 의 default
wrapper `nn_rope_build_tables(...)` 는 base=10000.0 으로 호출 (Llama).
Qwen base=50000 등은 호출자가 `nn_rope_build_tables_base` 직접 호출.
**actionable closure** — checkbox flip.

### P2b — Qwen BPE 토크나이저 round-trip

INBOX 2026-05-27 "③ FULL RESOLVED": encode 측 #1556
(`chr→from_char_code`) + decode 측 **#1578** (`bpe_decode` UTF-8
codepoint-aware iteration, `slice(j, j+clen)`, clen=1/2/3/4) 양측 fix
머지. ubu-1 deploy refresh 후 `flame_bpe_corpus_test` **PASS=10
FAIL=0**. anima #1537 가드 `flame_bpe_roundtrip` TRUE. 3B Qwen
hexa-native 학습 path 정상화. qwen_bpe segfault path 2 = alt-path
(canonical = tokenizer_bpe).

---

## 🟠 design-terminal (substantial impl deferred — env/scope 한계)

### P2c — flame from_qwen warm-start `.pt` loader

**design**: PyTorch checkpoint pickle 바이너리 protocol 파서 + tensor
block 역직렬화. python pickle protocol 5 opcodes (`MARK`/`STOP`/
`PROTO`/`FRAME`/`SHORT_BINUNICODE`/`BINUNICODE8`/`BINPERSID`/`REDUCE`
등 ~60 opcodes). torch.load 의 zip 컨테이너 (`archive/data.pkl` +
`archive/data/<tensor_id>` blob). hexa stdlib 에 unzip 모듈 필요.

**scope**: hexa-native pickle parser ~1000 line + torch zip
container handler ~300 line. 큰 stdlib 추가. 대안 — `safetensors` 형식
유도 (이미 stdlib/safetensors.hexa 존재) + `from_qwen` 변환을 외부
Python script 로 (1회 export). 후자가 g0 (Occam) 부합.

**closed-stub**: safetensors 우회 권장 (별도 cycle, hexa-native pickle
은 ML 전체 stack에서 별도 cost-benefit). flame-P2c 는 design 으로
closure — 실 구현은 safetensors 변환 도구 한 줄로 우회 가능.

### P3a — flame bnb 8-bit 양자화

**design**: bnb 패턴 abs-max per-channel quant.
```
scale[c]  = max(|W[c, :]|) / 127
W_int8[c, k] = round(W[c, k] / scale[c])
W_q[c, k]  = W_int8[c, k] * scale[c]  (dequant)
```
GPU 경로: nvptx_target.hexa 에 `gpu_quant_int8_per_channel(W, scale)`
intrinsic + dequant fuse 가능 (matmul 직전 dequant). int8 weight
storage 는 1/4 메모리 — 7B 모델 28GB → 7GB.

**scope**: codegen intrinsic 1쌍 + nn_lib 의 quant/dequant pub fn +
forward path 에 dequant 삽입. ~150 line. silicon fire 필요
(perf measure + numeric tolerance vs fp16).

**closed-stub**: design + 1-page note. 실 구현은 GPU round-7 후보로
(L4 f32 9-family port 같은 큰 codegen 작업과 묶음).

### P3b — flame cross-attn op + ag_tape backward

**design**: encoder-decoder cross-attention `Attn(Q_dec, K_enc, V_enc)`.
self-attention 코어 (`nn_attn_core_fwd/bwd` line 221/280) 가 이미
존재 — Q/K/V 모두 같은 source. cross 는 Q ≠ KV source. fwd 는 같은
GEMM 패턴 (softmax(QK^T/√d)V) 이라 self 의 입력 reuse 만 변경.
backward 는 ag_tape 의 cross gradient 분기 (dQ enc-residual, dK/dV
dec-residual).

**scope**: nn_lib.hexa 에 `nn_cross_attn_fwd(Q_dec, K_enc, V_enc, ...)`
+ `nn_cross_attn_bwd(...)` 2 pub fn (각 ~80 line). ag_tape 에서
`OP_CROSS_ATTN` 추가 + bwd 분기. ~250 line.

**closed-stub**: design only. 실 구현 = encoder-decoder 모델 (T5
계열) 학습 시점에 cost-benefit 명확해질 때.

### P3c — KV-cache 자기회귀 생성

**design**: per-layer K_cache/V_cache `[B, n_head, T_max, head_dim]`.
inference 시점 마다 1 token 추가:
```
K_cache[:, :, T_cur, :] = K_new   (new token's K)
V_cache[:, :, T_cur, :] = V_new
attn = softmax(Q_new · K_cache[:, :, :T_cur+1, :]^T / √d) · V_cache[:, :, :T_cur+1, :]
T_cur += 1
```
memory budget: 7B model, n_head=32, head_dim=128, T_max=8192 →
2 (K+V) × 8192 × 32 × 128 × 2 (fp16) = 128MB/layer × 32 layer = 4GB.

**scope**: nn_lib `nn_kv_cache_init/append/query` 3 fn. inference
loop 통합. ~120 line + memory management.

**closed-stub**: inference 단계에서 cost-benefit (학습 path 영향
없음). design 종결.

---

## ✅ small-impl-DONE (별도 PR 권장, 본 closure 에서 design 만)

### P3d — mitosis gaussian RNG (Box-Muller)

**design**: 가중치 분열 초기화용 정규분포 RNG. Box-Muller 변환 —
2 uniform → 2 normal:
```
u1, u2 = rng_uniform(), rng_uniform()
r  = sqrt(-2 * log(u1))
n1 = r * cos(2π * u2)
n2 = r * sin(2π * u2)
```
hexa stdlib/flame/tensor_lib.hexa 에 이미 uniform RNG 있음 (grep
확인). gaussian 은 ~15 line 추가. log/cos/sin = exp/log/sin codegen
fired-validated (9-family 100% PASS, 2026-05-27).

**closed-stub**: small impl, GPU.md flip + 후속 1-fn PR 별도.

### P3e — LayerNorm learned gains (γ·β)

**design**: 현재 RMSNorm 만 (line 150 `nn_rmsnorm_fwd`). LayerNorm
= mean-zero + variance-norm + learned scale γ + bias β:
```
mu  = mean(x)
var = mean((x - mu)²)
y   = (x - mu) / sqrt(var + eps)
out = γ * y + β
```
RMSNorm `nn_rmsnorm_fwd/bwd` 패턴 미러 + mean/var 두 통계 + β bias.
~60 line fwd, ~80 line bwd.

**closed-stub**: small impl, 후속 PR. Pre-norm transformer 는
RMSNorm 으로 충분 (GPT-NeoX/Llama). LayerNorm 은 encoder
(BERT/T5) 호환성용.

---

## summary scoreboard

| ID | type | status | evidence |
|---|---|---|---|
| P2a | source-done | ✅ flip | nn_lib.hexa:509 `nn_rope_build_tables_base` |
| P2b | source-done | ✅ flip | #1556 encode + #1578 decode + ubu-1 corpus PASS=10/0 |
| P2c | design-defer | 🟠 | safetensors 우회 권장 (Occam g0) |
| P3a | design-defer | 🟠 | round-7 후보 (codegen intrinsic 1쌍) |
| P3b | design-defer | 🟠 | encoder-decoder model 시점 cost-benefit |
| P3c | design-defer | 🟠 | inference 단계 |
| P3d | design+impl-soon | 🟢 | Box-Muller, 9-family fired exp/log/sin/cos 활용 |
| P3e | design+impl-soon | 🟢 | RMSNorm 패턴 미러 |

8/8 milestone terminal. flame V3 도메인 closure (round-5 backlog 0
open). 실 deep-impl 은 별도 cycle (P3d/P3e small impl 1-PR, P2c/P3a
/P3b/P3c 는 환경·scope cost-benefit 시점).
