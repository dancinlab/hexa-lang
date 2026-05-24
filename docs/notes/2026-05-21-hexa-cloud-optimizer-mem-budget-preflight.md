---
title: hexa cloud dispatch — pre-flight optimizer-state memory budget check
status: open
filed: 2026-05-21
filed_by: claude-code-tui (anima S187 attempt9→10 OOM saga)
target_ssot: wilson/plugins/pool (cloud dispatcher SSOT)
related:
  - 2026-05-21-hexa-cloud-typed-env-var-passing.md (sibling note, env-var verify gap)
  - feedback_dispatch_vast_template_gotchas (~/.claude memory)
  - feedback_orchestrator_h100_gotchas (~/.claude memory)
  - feedback_active_resource_utilization (cost-bearing fire encouraged)
---

# Gap

When dispatching a training job to a remote GPU, `wilson pool` (or successor cloud
dispatcher) does **not** statically verify that `model + grads + optimizer state +
activations` fit in target GPU memory **before** burn starts. The first
`optimizer.step()` discovers OOM on the remote pod, the python crashes, host watchdog
may or may not catch it, and the pod sits idle-burning until human teardown.

Symptoms:
- ✗ no compile-time check (optimizer state size is a function of optimizer kind ×
  param count × dtype combo — derivable, but bash dispatch has no type for it)
- ✗ no remote pre-flight (no canonical `cuda_mem_estimate()` call before `.train()`)
- ✗ first OOM lands at `optimizer.step()` → loss=nan? no, plain `CUDA out of memory`
  with allocator already at 78–98% — too late to recover, the run is dead
- ✗ cost-bearing: each failed cycle burns ≈ pod-spinup ($0.05) + boot/install
  ($0.50) + first-step-attempt ($0.20) ≈ $0.75/pod, × N pods × M attempts

# Concrete incident (2026-05-21, anima S187 3B grid)

Dispatch script: `HEXAD/UNCLASSIFIED/state/grid_3b_s187_2026_05_21/dispatch_s187_3b_runpod.sh`

Naming: "S187 3B grid" (d=3072 L=28 nh=24 nkv=8 GQA). Real `n_params=8,921,180,216`
(8.92B) — `conscious_decoder` adds `head_a` / `head_g` / `psi` / `route` / `phi` /
`cycle` / `curious` / `replay` heads on top of the transformer body, ~3× expansion
vs vanilla 3B.

| attempt | bsz | n_ca_rules | env-var fix | optimizer | result |
|---|---|---|---|---|---|
| 2/3 | 4 | 8 | — | torch.optim.AdamW (f32 m+v) | OOM |
| 4 | 4 | 8 | — | + dtype try | dtype mismatch |
| 5 | 4 | 8 | — | + alloc_conf string | OOM |
| 6 | 4 | 8 | partial | + alloc_conf string | cascade fail |
| 7 | 4 | 8 | partial | torch.optim.AdamW | OOM 106 GiB pre-fix |
| 8 | 4 | 8 | string-concat | torch.optim.AdamW | OOM at `_foreach_sqrt` |
| 9 | **2** | **2** | `launch_trainer.sh` wrapper ✓ | torch.optim.AdamW | **OOM 78.22 GiB at `_foreach_sqrt`** — 8/8 identical |
| 10 | 2 | 2 | wrapper ✓ | **bnb PagedAdamW8bit** | **58.39 GiB live, 7/8 step 200+ within 5 min** |

attempt9 verified the env-var fix landed (sister note above). attempt10 revealed
the actual binding constraint was **optimizer state sizing**, not env-var
passthrough:

```
torch.optim.AdamW @ f32 m + f32 v + grads (same dtype as params):
  state_mem ≈ 8 × n_params bytes   (m=f32 + v=f32, 4 bytes each, × 2)
  for 8.92B params: 8.92e9 × 8 ≈ 71.4 GiB just for AdamW state
  + 6 GiB bf16 params + 6 GiB bf16 grads + activation + temps = 78.22 GiB → OOM
```

attempt10 swapped `torch.optim.AdamW` → `bitsandbytes.optim.PagedAdamW8bit`:

```
state_mem ≈ 2 × n_params bytes (i8 m + i8 v, ~ block-wise quant state ≈ 1.05×)
  for 8.92B: 8.92e9 × 2 ≈ 17.8 GiB
  total budget: ~58 GiB / 80 GiB H100 → 22 GiB headroom, 7/8 first-step PASS
```

**The 8-pod identical-OOM signature is the smoking gun**: when every variant
crashes at the exact same `_foreach_sqrt` location with bytes-identical error
text, the bug is structural (memory budget), not stochastic (driver glitch /
allocator fragmentation / corpus shape).

# Proposed grammar-level prevention (hexa-native dispatch)

```hexa
let job = CloudJob {
    host: "runpod://h100-80gb",
    cwd:  "/workspace/s187r",

    # ★ typed model spec — not a string blob
    model: ModelSpec {
        n_params: 8_921_180_216,           # exact, not "3B" wishlist
        param_dtype: bf16,
        grad_dtype: bf16,
    },

    # ★ typed optimizer tag — drives state-size formula lookup
    optimizer: OptimizerSpec::PagedAdamW8bit {
        betas: (0.9, 0.95),
        weight_decay: 0.01,
    },

    # ★ typed training config — drives activation-size formula
    batch: BatchSpec {
        bsz: 2,
        seq_len: 128,
        n_layer: 28,
        d_model: 3072,
        n_head: 24,
        n_kv_head: 8,  # GQA → cheaper KV cache
        grad_checkpoint: false,
    },

    # ★ typed GPU target — drives budget assertion
    gpu: GpuSpec {
        kind: "H100-80GB-HBM3",
        mem_bytes: 80 * GB,
        reserved_overhead: 4 * GB,  # CUDA context + driver + temps
    },

    # ★ MANDATORY: refuse to dispatch if budget exceeded
    pre_flight: mem_budget_check(),
}
cloud_dispatch(job)   # raises BudgetExceededError before any pod-spinup
```

Where `mem_budget_check()` evaluates closed-form:

```
params      = n_params × bytes_of(param_dtype)
grads       = n_params × bytes_of(grad_dtype)
opt_state   = n_params × optimizer_state_multiplier(optimizer)
activations = bsz × seq_len × d_model × n_layer × (10 to 25)  # rough envelope
              + sa_attn(bsz, seq_len, n_head, d_model) terms
temps       = overhead_envelope   # 8 GiB conservative
total       = params + grads + opt_state + activations + temps + reserved_overhead

if total > gpu.mem_bytes:
    raise BudgetExceededError(
        actual=total,
        cap=gpu.mem_bytes,
        breakdown={params, grads, opt_state, activations, temps},
        suggest=optimizer_downgrade_path(optimizer)
    )
```

Optimizer state-size table (the lookup driving prevention):

| `OptimizerSpec` variant | state_multiplier (×n_params bytes) | breakdown |
|---|---|---|
| `SGD` | 0 | no buffers |
| `SGDMomentum` | 4 | f32 momentum |
| `AdamW` | 8 | f32 m + f32 v |
| `AdamW @ AMP-fp16` | 12 | + f32 master copy |
| `AdamW8bit` (bnb) | 2.1 | i8 m + i8 v + ~5% block-wise quant state |
| `PagedAdamW8bit` (bnb) | 2.1 | + CPU paging buffer (transient peaks → host) |
| `Lion` | 4 | f32 momentum (no v) |
| `LoRA-frozen + AdamW (rank r)` | 8 × (r/d_model) | r adapter only |
| `ZeRO-2 stage` | 8 / n_gpu | sharded across data-parallel |
| `ZeRO-3 stage` | 8 / n_gpu (also shards params + grads) | full sharding |

Activation-size envelope (closed-form for transformer block):

```
per_layer ≈ bsz × seq_len × d_model × (
    2 (residual stream)
    + 4 (attention Q,K,V,out)
    + 2 (FFN intermediate × 4_expand → /4 for swiglu = ~10/3)
    + 1 (layernorm output)
) × bytes_of(param_dtype)
   ~~ 10× to 25× bsz × seq_len × d_model × bytes for full f32 backward
   ~~ /2 with mixed-precision activation
   ~~ /n_layer with gradient_checkpointing
total ≈ n_layer × per_layer × (recompute_factor)
```

Suggesting downgrades when over budget:

```
optimizer_downgrade_path(AdamW) → [AdamW8bit, PagedAdamW8bit, Lion, ZeRO-2 AdamW]
optimizer_downgrade_path(AdamW8bit) → [PagedAdamW8bit (+CPU page), Lion + gc, ZeRO-2]
optimizer_downgrade_path(PagedAdamW8bit) → [gradient_checkpointing, smaller_bsz, ZeRO-2, ZeRO-3]
```

(saga policy ladder: each step is independently verifiable and adds back observable
training capability — match `step-by-step-decision-gate` principle.)

# Why this matters for the lattice

`feedback_active_resource_utilization` says cost-bearing fire is encouraged — but
`fire then OOM × 8 pods × 9 attempts` saga is the **anti-pattern** the principle
implicitly excludes: fire that produces no signal. attempt9→10 burned ~$2 of pod
boot before discovering attempt9's "fix" was the wrong axis. With the budget
preflight, attempt8's hypothesis (env-var) and attempt10's hypothesis (optimizer
state) would have been **separately falsifiable in <30s on the dispatch host
before any pod-spinup**.

This is also a Principle #2 (hexa-first) lift: today's dispatch is a 200-line bash
script polling SSH; the budget math is buried in human comments ("Budget: state ~24
GB + activations ~4.5 GB ≈ 40 GB" — actual was 78 GiB). Lifting it into a typed
`CloudJob` record makes the math an executable assertion, not a hopeful comment.

# Acceptance for `wilson pool dispatch` (or cloud successor)

P1 — `OptimizerSpec` enum with state-size lookup table (above).
P2 — `BatchSpec` + `ModelSpec` typed records driving activation envelope.
P3 — `mem_budget_check()` raises `BudgetExceededError` with breakdown before pod-spinup.
P4 — `optimizer_downgrade_path()` returns ordered suggestions; CLI emits them
       in the error message for human follow-up.
P5 — `verify_step_1_mem()` post-launch assertion: `nvidia-smi --query-gpu=memory.used`
       must be within ±15% of budget prediction after first step (catches
       hidden state we didn't model — e.g. AMP master copies, autograd graph).

# Honest carve-out

- This is `notes` / RFC-shaped gap. No PR attached. Implementation depends on
  `wilson pool` cloud surface (POOL.md decision #92 = opt-in --with pool, not
  bundle-default).
- Activation envelope formula is approximate ±2×; the real number depends on
  Flash Attention vs vanilla, SDPA vs eager, KV-cache reuse, etc. The budget
  check should treat its estimate as a **lower bound** and require headroom
  (suggested: 15–20% margin under `gpu.mem_bytes - reserved_overhead`).
- `PagedAdamW8bit` paging-to-CPU is a transient-peak insurance, not a steady-state
  budget reducer. Steady-state OOM is the static-budget concern; transient peaks
  during `optimizer.step` are the dynamic-allocator concern (orthogonal — both
  matter, but only steady-state can be statically pre-flighted).
- `n_params` must be **measured**, not declared. Today: `print(sum(p.numel() for p in model.parameters()))`
  before any optimizer construction. Hexa-native equivalent: `model.n_params()` accessor
  on the typed model handle.

# Workaround (until grammar fix lands)

Until `mem_budget_check()` lives in `wilson pool`, dispatch scripts should:

1. Print `n_params` **before** optimizer construction (`train_s187_3b.py:247`
   already does this — confirms model is built, lets human eyeball state size).
2. Hand-compute optimizer state on dispatch.sh header comment using the table
   above; refuse to dispatch if `state_mem + 30% > gpu.mem`.
3. Default to `bnb.optim.PagedAdamW8bit` for any param-count ≥ 1B on single-GPU
   ≤ 80 GB. (saga lesson: at d_model=3072 L=28 + conscious_decoder heads, the
   "3B" naming hides ~3× expansion — assume worst-case multiplier in dispatch.)
4. Verify with `nvidia-smi memory.used` poll at step 5 → step 50 → step 200; if
   any cross > 90% pod cap, OOM is statistically inevitable downstream.

This workaround was applied in S187 attempt10 (`train_s187_3b.py:250-274`
+ `launch_trainer.sh` bnb install bootstrap) — `78.22 GiB → 58.39 GiB`, 7/8
pods PASSed first optimizer.step within 5 min wall, total cost ~$4 vs
$40+ budget cap.
