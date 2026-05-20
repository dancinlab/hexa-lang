# `stdlib/cloud` + `stdlib/flame` — 3B fire troubleshooting prevention: pre-flight memory estimator + AMP default + cascade retry-with-backoff + ckpt-aware bsz auto-tune

**Severity**: high (anima 3B fire grid 2026-05-21 burned ~$30+ on 3 separate
  OOM cycles + 5 cascade rc=1 failures + 1 SSH_NEVER_READY before reaching
  a stable bsz/dtype combination; the failure modes are all upstream-
  preventable)

**Layer**: stdlib/cloud (dispatch infrastructure) + stdlib/flame
  (trainer-side AMP/checkpointing defaults) + governance/conventions

**Reporter**: anima (`dancinlab/anima`) downstream consumer —
  observed during §187 3B GRID fire attempt (2026-05-21,
  `dancinlab/anima HEXAD/UNCLASSIFIED/state/grid_3b_s187_2026_05_21/`)

**Status**: not_started (filed 2026-05-21 post-incident)

---

## 1. Incident timeline (2026-05-21 §187 3B GRID)

anima fired d=3072 L=28 nh=24 nkv=8 GQA ~3B PyTorch (clone of §184
`conscious_decoder.py` + `train_s184_combined.py`) on H100 80GB SXM
cascade across 3 attempts × 4-8 pods/attempt. Each failure cost
real $$ (pod boot + container pull + corpus build + train-until-OOM).

### Attempt 1 (n_steps=8000 bsz=16 block=512) — 4 pods
- 4/4 pods provisioned (H100 HBM3 × 2 + A100 SXM4 + H100 NVL)
- vD initial cascade FAILED (INTERNAL_SERVER_ERROR + SUPPLY_CONSTRAINT) →
  rc=1 → manual retry succeeded
- killed by user ("5-6h 너무 긴데" — too long wall)
- cost: ~$10 burned (pods ran ~30 min before kill)

### Attempt 2 (n_steps=2000 bsz=32 block=256) — 8 pods (4 cfg × 2 seed)
- 5/8 pods provisioned successfully
- vB_s42 SSH_NEVER_READY in 600s window → FAILURE
- vC + vD cascade failed all 5 GPUs → rc=1 immediate exit
- all 5 alive pods → **CUDA OutOfMemoryError** during training (pure
  fp32 trainer at 3B = ~48GB optimizer state alone, bsz=32 × cycle-
  pair activations pushed over 80GB)
- cost: ~$15 burned

### Attempt 3 (n_steps=2000 bsz=8 block=256) — 8 pods retry
- 5/8 provisioned, 3/8 cascade rc=1 again (retried, eventually all 8 up)
- **all 6 alive pods → OOM again** at bsz=8 (still pure fp32, 48GB
  optimizer + activations + PyTorch fragmentation > 80GB)
- cost: ~$15 burned

**Total**: ~$30-40 burned learning the pre-flight memory model + AMP
necessity. Wall clock: ~2-3 hr of dispatcher chaos before stable.

---

## 2. Root causes (all upstream-preventable)

### RC1 — no pre-flight memory estimator for ckpt cfg vs GPU mem

**Problem**: dispatch script accepts `d_model n_layer n_head n_kv_head
bsz block_size` but has NO calculation of expected GPU memory before
pod provisioning. anima fires d=3072 L=28 in pure fp32 expecting it
fits 80GB; reality is 48 GB optimizer state alone (params ×4 modes:
fp32 master + fp32 grads + fp32 AdamW m + fp32 AdamW v), no headroom
for activations.

**Should be**: dispatch_or_flame_trainer computes:
```python
params = m_total_estimate(d, L, nh, nkv, h, V)              # ~3B
fp32_state = params * 4 * 4  # master + grads + m + v        # 48 GB
activations_bf16 = bsz * block * d * L * 2 * 2  # cycle pair # 8.4 GB
attention_scores = bsz * nh * block * block * 4 * L          # 5.6 GB
overhead = 5_GB                                              # PyTorch frag
total = fp32_state + activations_bf16 + attention_scores + overhead
if total > gpu_mem * 0.85:
    suggest_amp_or_smaller_bsz_or_grad_checkpoint()
    REFUSE_OR_WARN
```

### RC2 — flame trainer template has no AMP/BF16 default

**Problem**: `train_s184_combined.py` (the §184 trainer that anima
cloned for §187) is **pure fp32**. At d=768 L=12 (~280M, the §184
scale), this works on 40GB GPU. At 3B, it does NOT fit 80GB. No
`torch.cuda.amp.autocast(dtype=torch.bfloat16)` wrap, no GradScaler,
no `model.gradient_checkpointing_enable()`, no `--bf16` flag.

**Should be**: anima trainer base template (the §184 pattern) defaults
to BF16 autocast for d >= 1024 OR explicit `--dtype bf16|fp32` flag
that auto-selects based on est mem.

### RC3 — cascade failure not gracefully handled

**Problem**: `dispatch_s187_3b_runpod.sh` GPU_CASCADE tries N=5 GPU
types sequentially. If ALL 5 hit INTERNAL_SERVER_ERROR or
SUPPLY_CONSTRAINT (common for popular GPUs at peak demand), the
script exits rc=1 immediately. User must manually retry → race
condition (parallel pods compete for same supply).

**Should be**: cascade with **exponential backoff retry** — if all 5
GPUs fail once, sleep 60s and retry the cascade up to 3 times. ALSO
randomize GPU order to avoid all parallel dispatchers hammering H100
HBM3 first.

### RC4 — SSH_NEVER_READY 600s window too short for cold-start

**Problem**: SSH_TRIES=60 × 10s = 600s. Some pods take longer to
initialize (especially first-on-machine boot). Hard FATAL after 600s
discards the pod with no retry.

**Should be**: on SSH_NEVER_READY, **first try to terminate-and-recreate**
the pod (sometimes the runpod machine itself is stuck) rather than
immediate FATAL exit. Adds 1-2 retries before giving up.

### RC5 — no per-fire budget head check

**Problem**: dispatch doesn't echo or check expected cost vs configured
ceiling. anima governance says `g_no_cost_scope_limit` but mistakes
like OOM-fail × 3 attempts cost real $$. A pre-flight cost head
("est $13/pod × 8 pods = $104 if all run to completion; current burn
rate $X/hr") would surface scope before commit.

**Should be**: dispatch echoes:
```
[pre-flight] cfg: d=3072 L=28 → ~3.0B params
             mem: est 62 GB on 80 GB H100 = 78% util  ⚠ TIGHT — recommend AMP
             cost: ~$13/pod × N pods × ~5h wall = ~$X total est
             tokens: 2000 × 8 × 256 = 4.1M (sub-Chinchilla 1000×)
```

### RC6 — orphan pod risk under user-kill

**Problem**: When user SIGTERM's the dispatcher mid-flight, `trap
teardown` should terminate the pod. Worked correctly this session but
**not all pods terminated immediately** — some lingered for 30-60s
before API confirmation, costing pennies that add up across many kills.

**Should be**: trap teardown should `wait` for API confirmation before
exit, OR a separate `cleanup_orphan_pods.sh` script that runs
periodically and terminates any pod older than X minutes with no
result.json yet.

---

## 3. Asks

### Ask 1 — `stdlib/cloud/preflight.hexa` memory + cost estimator

Pure-hexa primitive that takes a model cfg (d/L/nh/nkv/h/V/bsz/block) +
GPU type + n_pods + dtype and returns:
```
{
  params_estimate: 3_000_000_000,
  per_pod_mem_gb: 62.4,
  gpu_capacity_gb: 80,
  utilization_pct: 78,
  fits: true,
  warning: "TIGHT (>75%) — recommend AMP/bf16 or grad checkpointing",
  per_pod_cost_per_hr: 3.29,
  total_est_cost_at_5hr: 131.6,
  total_est_tokens: 4_100_000,
  chinchilla_ratio: 0.0007  # 1400× under
}
```

Called by `hexa cloud preflight <cfg.json>` OR auto-called by `hexa
cloud nohup <host> <trainer.hexa>` before pod create.

### Ask 2 — `stdlib/flame/decoder_lib.hexa` AMP-aware init

Add `dtype: int` param (0=fp32, 1=bf16, 2=fp16) to `nn_decoder_init` +
matching auto-routing in fwd/grad/adamw. Default `fp32` for d<=768,
default `bf16` for d>=1024 (gentle nudge toward memory-safe). Document
in flame_d768_12L_corpus_test.hexa as the canonical pattern.

### Ask 3 — `stdlib/cloud/dispatch_lib.hexa` cascade-with-backoff

Wrap the GPU cascade logic in a reusable primitive:
```hexa
fn cascade_create_pod(
    gpu_list: array_str,
    base_cfg: dict,
    max_attempts: int,
    backoff_sec: int
) -> pod_handle
// Round 1: try each GPU once (current behavior)
// Round 2: sleep backoff_sec, try each GPU once (only on supply errors)
// Round 3: sleep 2× backoff_sec, randomize order, try each GPU once
// Final FATAL only after Round 3.
// On INTERNAL_SERVER_ERROR specifically (vs SUPPLY_CONSTRAINT) — different policy:
//   INTERNAL_SERVER_ERROR is transient, retry immediately; SUPPLY is
//   real shortage, retry after backoff.
```

Used by `hexa cloud nohup <host>` when host = "runpod" OR explicit
GPU spec.

### Ask 4 — SSH-ready loop: terminate-and-retry policy

Replace hard FATAL after SSH_TRIES exhaustion with one auto-recreate:
```
if SSH never up in 600s:
    log [WARN] SSH timeout, terminating pod $POD_ID and retrying once
    podTerminate $POD_ID
    POD_ID=$(cascade_create_pod ...)
    repeat SSH loop
    if STILL not up after 2nd 600s window: FATAL
```

### Ask 5 — `hexa cloud preflight` CLI wrapper

```
$ hexa cloud preflight \
    --d 3072 --L 28 --nh 24 --nkv 8 --h 8192 \
    --bsz 32 --block 256 --dtype fp32 \
    --gpu "H100 80GB" --n-pods 8

CONFIG:
  d=3072 L=28 nh=24 nkv=8 → 3,050,431,488 params (~3.05B)
  bsz=32 block=256 → 8,192 tokens/step

MEMORY (per-pod, fp32):
  optimizer state    : 48.8 GB  (params + grads + AdamW m + AdamW v)
  activations + cyc  : 8.4 GB   (cycle-pair backward saved)
  attention scratch  : 5.6 GB
  PyTorch overhead   : 5.0 GB
  ─────────────────────────────
  total              : 67.8 GB / 80 GB H100 = 85% util
  status             : ⛔ TIGHT — likely OOM on fragmentation

RECOMMENDATION:
  → switch --dtype bf16          : drops optimizer to 24.4 GB total
  → OR reduce --bsz to 8         : drops activations to 2.1 GB total
  → OR enable --grad-checkpoint  : drops activations 10×

COST (current cfg):
  H100 HBM3 SXM    : $3.29/hr × 8 pods = $26.32/hr
  est 5h wall      : ~$132 total budget

CHINCHILLA-RATIO:
  total tokens = 2000 × 8 × 256 = 4.1M (1400× under capacity-optimal 60B for 3B)
  → substrate proof + cross-axis only; not competitive LM training
```

---

## 4. Cross-link

- existing inbox patch `cloud-cli-run-hang.md` (Mac copy-from/run path,
  CLOSED 2026-05-21 per anima §186 fire)
- existing inbox patch `cloud-cli-operational-improvements-anima-2026-05-20.md`
  (P1-P11 batch — overlap candidates: P? = preflight, P? = cascade
  retry policy)
- dancinlab/anima `@D g_fire_dispatch_robust` (2026-05-15 — has SSH-gate
  + SAVE_POD + 5-retry pull; missing: pre-flight memory check + cascade
  backoff + dtype auto-select)
- dancinlab/anima `@D g_no_cost_scope_limit` (2026-05-20 — no cap, but
  pre-flight head still useful for visibility)
- dancinlab/anima §187 grid_3b_s187_2026_05_21 — affected fire

---

## 5. Honest C3

1. **anima could solve this side**: anima trainer code edit (add
   `--bf16` autocast) is a 30-line patch, not 1000-line; this inbox
   patch is for UPSTREAM convenience so future downstream consumers
   don't replay the same $30 lesson. anima will land its own bf16
   fix in parallel for the §187 retry.
2. **runpod-specific cascade**: vast.ai may have different supply
   patterns; should the cascade-backoff primitive cover both providers
   or per-provider tuning?
3. **AMP isn't free** — BF16 has reduced numerical range; some recipes
   (multi-objective L_psi/L_phi which use small `(x-0.5)²` quadratics)
   may need fp32 master copy for the loss aggregation. Not universal
   default — needs to be opt-in or per-recipe.
4. **`hexa cloud preflight` UX placement** — auto-call before nohup?
   Then user can't bypass for special cases. Suggest: warn on TIGHT
   (>75% util), refuse on EXCEEDS (>95%), allow override via
   `--force` flag.
