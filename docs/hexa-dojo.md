# hexa dojo — 학습 빵틀 (training-job + authoring-kata generator)

The **dojo** (`hexa dojo`) is hexa-lang's training-job and authoring-kata
generator — the learning sibling of `hexa deck` (DFT input decks). Where deck
bakes a static `.in` simulation deck, dojo bakes a *runnable learning artifact*:
either a **cloud training job** or a small, self-contained **authoring kata**
you build and read end-to-end.

One generic entry point dispatches by domain string to a per-domain emitter:

```bash
hexa dojo domains                              # list known domains (full | stub)
hexa dojo <domain> <slug> '<spec-json>' [--lang=hexa|py|both]
```

All `.py` / `.sh` payloads are **emitted-string content** written by the hexa
runtime's own `write_text` (never agent `Write`/`Edit`) — the same emit-string
discipline as `deck`'s `run.sh`.

## domains

| domain | kind | emits |
|---|---|---|
| `llm` | cloud training | HF `Trainer` causal-LM fine-tune (`job.hexa` · `train.py` · `run.sh`) |
| `clm` | cloud training | hexa-native `CLMConvMoE` trainer (`job.hexa` · `run.sh` · descent + util gates) |
| **`hexa-cuda`** | authoring kata | `@gpu_kernel` katas — kernel + CPU oracle + host `gpu_launch` shape |
| **`flame-forge`** | authoring kata | flame `.hexa` trainers over `stdlib/flame` — forward + closed backward + descent gate |
| **`vision`** | authoring kata | flame `.hexa` image classifiers — softmax-clf · patch-mlp · softmax-CE descent gate |
| **`rl`** | authoring kata | flame `.hexa` REINFORCE policy-gradient — bandit-pg · gridworld-pg · reward-ascent gate |
| **`tabular`** | authoring kata | flame `.hexa` tabular classifiers — logreg · mlp-tab · softmax-CE descent gate |

All six domains are **`[full]`** (`hexa dojo domains`). The `vision` · `rl` ·
`tabular` arms graduated from stub → full as flame trainers over the same
`stdlib/flame` substrate as `flame-forge` — see **[track 3](#track-3--vision--rl--tabular-supervised--policy-gradient-katas)** below.

## track 1 — `hexa-cuda` (GPU kernel authoring)

The learn-by-doing arm of [HEXA-CUDA](../HEXA-CUDA.md). Each kata is a small,
self-contained `@gpu_kernel` you build and read. The kernels use **only** the
verified `@gpu` intrinsics from [`gpu/SPEC.md`](../gpu/SPEC.md) §5/§6 — every
name is pattern-matched at NVPTX codegen (`compiler/codegen/nvptx_target.hexa`).
No invented intrinsics.

```bash
hexa dojo hexa-cuda vecadd '{"kata":"vec-add","n":1024,"dtype":"f64","sm":"sm_90"}' --lang=both
```

### kata ladder

| rung | kata | intrinsics exercised |
|---|---|---|
| 1 | `vec-add` | `gpu_block_id_x` · `gpu_block_dim_x` · `gpu_thread_id_x` |
| 2 | `reduction` | `@shared let` · `gpu_barrier` · `gpu_atomic_add` |
| 3 | `tiled-gemm` | 2-D thread index (`*_y`) · `@shared` tiles · `gpu_barrier` |
| 4 | `wmma` | `gpu_wmma_load_a` · `gpu_wmma_load_b` · `gpu_wmma_mma` · `gpu_wmma_store_c` |

Each kata emits `kernel.hexa` (the `@gpu_kernel` + a CPU reference oracle + the
host `gpu_launch` call shape), `run.sh` (parse-gate + `hexa build --target=nvptx`),
and a `README.md`. With `--lang=py|both` it also emits a `kernel.cu` + `driver.py`
CUDA C++ contrast showing the 1:1 intrinsic map (`threadIdx.x → gpu_thread_id_x()`,
`__syncthreads() → gpu_barrier()`, `__shared__ → @shared let`, `atomicAdd → gpu_atomic_add`).

> **wmma honesty:** the `gpu_wmma_*` family is a *codegen-level* MIR op set
> (RFC 067), not a source-level expression grammar. The emitted wmma kata
> documents the lowering in comments and keeps a parse-clean f64 stand-in body
> (mirrors `tool/probe_bf16_wmma.hexa`) — it does **not** call `gpu_wmma_*` as
> source functions.

The `kernel.hexa` is **parse-clean today** (`hexa parse kernel.hexa`); the MIR
partition that routes `@gpu_*` to NVPTX codegen + the `gpu_launch` lowering land
via RFC 055-P3 (a CUDA host with `ptxas`). The `run.sh` `$0` gate parse-checks
without a GPU and degrades gracefully when `ptxas` is absent.

### lesson — GPU own-GEMM parity & the persistent megakernel (a war story)

> This is a **reading lesson, not a kata** — there is no parse-clean stand-in,
> because the primitives below (`wgmma`, TMA `cp.async.bulk.tensor`, grid-sync)
> are **codegen / `.cu`-level**, *not* source-callable from `.hexa` today (the
> source-callable `@gpu` set is still §5/§6 — `gpu_thread_id_x` · `@shared let` ·
> `gpu_barrier` · `gpu_atomic_add` · `gpu_warp_shuffle` · `gpu_wmma_*`). The arc
> below was hand-authored in `.cu` at the codegen level and is reflected here so
> the *engineering lessons* survive. **Do not invent source calls for any of it.**

**The frame, stated honestly first.** cuBLAS-TF32 is the **roofline** (~431
TFLOP/s @4096³ on H100). Our own-GEMM is **parity-seeking, and parity is NOT
achieved** — the landed frontier is **W10 ≈ 70.7 TFLOP/s @4096³, ~6.09× off**
cuBLAS, and bit-exact (rel-RMS 0). Every kernel below passes a **bit-exact gate
FIRST** (no perf number is ever reported for a kernel with rel-RMS > 3e-3). The
win here is **ownership and completeness** — a persistent whole-step kernel *can*
call our device GEMM in-line where it can never call cuBLAS — **not** a util or
perf victory over the vendor library.

**The W-ladder (own-GEMM, `wgmma`+TMA on native `sm_90a`).** Each rung is
bit-exact (rel-RMS 0); the lift is occupancy, not precision:

| rung | lever | TFLOP/s | gap vs cuBLAS-TF32 |
|---|---|---|---|
| W6 | async-pipe (`cp.async` warpgroup producer) | 50.7 | 8.39× |
| W8 | **HW TMA producer** (1 elected thread) → occupancy 1→2 CTA/SM | 66.5 | 6.44× |
| W10 | **composed swizzle-decode** (software-composed `SWIZZLE_128B`) | **70.7** | **6.09×** |

**The four named gotchas (the load-bearing facts):**

- **(a) `wgmma` needs the GMMA `INTER` 8×4 TF32 core layout.** Hopper `wgmma`
  reads operands from shared memory in a specific core-matrix tiling — for TF32
  the core matrix is **8×4 elements** (the W2 swizzle solve). Hand the wrong tiling
  and the MMA silently computes garbage; this single constant ended a multi-month
  layout dead-end.
- **(b) `fence.proxy.async.shared::cta` orders the async-proxy shared read.** The
  async proxy (TMA / `cp.async`) and the generic proxy (`wgmma`'s shared read) are
  *separate memory proxies*; without this fence the `wgmma` can read shared before
  the async copy is visible. A plain `__syncthreads()` is **not** sufficient.
- **(c) a single-elected-thread HW TMA producer frees occupancy.** A thread-heavy
  `cp.async` producer warpgroup is register-bound to 1 CTA/SM (the W7 regression).
  Electing **one** thread to issue `cp.async.bulk.tensor` (HW TMA engine does the
  copy, ~0 consumer threads spent) shrinks the CTA 384→256 threads and **doubles**
  resident CTAs/SM (1→2) — the W6→W8 +31% lift. This is the cuBLAS production class.
- **(d) the `SWIZZLE_128B` law is textbook, but must be SOFTWARE-composed.** The
  128-byte swizzle is the canonical `g XOR (r & 7)` (CuTe `Swizzle<3,4,3>`), **but**
  it must be composed *in software* with the 8×4 core packing of (a). The in-place
  *hardware* swizzle descriptor (feeding the TMA-landed tile directly to `wgmma`)
  is a **closed-negative** — the naive HW-swizzle failed bit-exact (rel-RMS 1.392);
  W10 lands the win by composing the two permutations in the cooperative decode.

**The persistent megakernel — two walls, both closed.** A whole-step *persistent*
kernel keeps everything resident across the step instead of re-launching per op.
Two walls blocked it; both are now closed:

1. **The cuBLAS-call wall.** A persistent kernel **cannot** call cuBLAS (it's a host
   API). The own-GEMM above **removes** this wall — the persistent kernel calls our
   device GEMM **in-line**.
2. **The GroupNorm full-y reduction wall.** A full-y reduction needs a cross-block
   barrier. A **grid-sync cooperative** kernel (`cudaLaunchCooperativeKernel` +
   `cooperative_groups::this_grid().sync()`) with a **deterministic fixed-order**
   reduction (**no float atomics**) closes it — **byte-eq, max|Δ| = 0**.

**Honest closing.** util-via-megakernel is a **CLOSED-NEGATIVE** — fusing the whole
step into one persistent kernel does **not** win utilization or wall-time vs the
serial kernel DAG. The value is **ownership/completeness** (we own the full stack,
end-to-end, bit-exact, with no vendor call), not a perf brag.

**Cite (verbatim verdicts + the lit scan):**

- `.verdicts/hexa-fusion/F-FUSION-SM90-WGMMA-W8.txt` — W8 TMA-producer (66.5 TFLOP/s,
  6.44×, occupancy 1→2 CTA/SM, rel-RMS 0) · PR #2841
- `.verdicts/hexa-fusion/F-FUSION-SM90-WGMMA-W10.txt` — W10 composed-swizzle-decode
  (70.7 TFLOP/s, 6.09×, rel-RMS 0) · PR #2847
- `.verdicts/hexa-fusion/F-FUSION-MEGAKERNEL-GN-GRIDSYNC.txt` — grid-sync GroupNorm
  (byte-eq, max|Δ| = 0) · PR #2845
- [`docs/research/sm90-wgmma-parity-litscan.md`](research/sm90-wgmma-parity-litscan.md)
  — the `wgmma`/TMA/swizzle literature scan (#2846) behind gotchas (a)/(d)

## track 2 — `flame-forge` (NN trainer authoring)

The NN-training arm. Each kata is a small, complete flame trainer over the
`stdlib/flame` substrate (`t_*` tensor ops · `t_matmul` forge matmul ·
`t_fill_lcg` deterministic init · `opt_adamw_step` optimizer). Each emits a
**descent gate** (`F-FLAMEFORGE-<KATA> = 1` when loss strictly descends) — the
same discipline as `dojo/clm`'s `clm_prod` loop.

```bash
hexa dojo flame-forge linreg '{"kata":"linreg","d":16,"T":64,"epochs":50,"lr":0.01}'
cd exports/flame-forge/dojo/linreg && bash run.sh    # runs train.hexa + asserts the gate
```

### kata ladder

| rung | kata | model · loss |
|---|---|---|
| 1 | `linreg` | `y = X·w + b` · MSE · closed gradient |
| 2 | `mlp` | `relu(X·W1+b1)·W2+b2` · MSE · 2-stage backprop |
| 3 | `tiny-clm` | byte-vocab embed + linear head · mean CE · softmax backward |

Each kata emits `train.hexa` (the self-contained trainer + descent gate),
`run.sh` (`hexa run train.hexa` + assert the gate), and a `README.md`. With
`--lang=py|both` it also emits a `ref.py` PyTorch reference (the familiar-framework
contrast — **not** what ships). The trainer runs on a CPU host today (the forge
matmul falls back to the CPU `farr` path); a forge-GPU host accelerates the
**same** code unchanged.

## track 3 — `vision` · `rl` · `tabular` (supervised + policy-gradient katas)

Three more authoring arms over the **same** `stdlib/flame` substrate as
`flame-forge` — small, self-contained, **real** `.hexa` trainers you read + run
end-to-end, each emitting a gate. Same emit shape (`train.hexa` + `run.sh` +
`README.md`, plus a `ref.py` torch contrast on `--lang=py|both`).

```bash
hexa dojo vision  clf  '{"kata":"patch-mlp","px":8,"classes":4,"T":64,"epochs":60}'
hexa dojo rl      pg   '{"kata":"bandit-pg","states":4,"actions":4,"T":64,"epochs":80}'
hexa dojo tabular log  '{"kata":"logreg","features":12,"classes":3,"T":96,"epochs":60}'
cd exports/vision/dojo/clf && bash run.sh    # runs train.hexa + asserts the gate
```

### `vision` — image classifier

A flame classifier on synthetic `px×px` grayscale images with a deterministic
class signal, **softmax cross-entropy descent gate** (`F-VISION-<KATA> = 1`).

| rung | kata | model · loss |
|---|---|---|
| 1 | `softmax-clf` | `logits = X·W + b` · softmax CE · closed backward |
| 2 | `patch-mlp` | `relu(X·W1+b1)·W2+b2` · softmax CE · 2-stage backprop |

> **scope honesty:** the `stdlib/flame` substrate has a forge matmul + a **1-D**
> conv (`conv_lib.nn_conv1d_*`) but **not yet a 2-D conv with a wired closed
> backward** for a self-contained trainer. So the hexa `train.hexa` is the
> **patch-MLP floor** of the vision ladder (flatten → MLP → softmax-CE — a real,
> descending classifier, *not* a faked conv trainer). The `ref.py` torch
> reference uses a real `nn.Conv2d` CNN — the target the ladder bridges toward
> once a 2-D conv backward lands in flame.

### `rl` — REINFORCE policy gradient

A flame policy-gradient trainer on a tiny tabular environment: a softmax policy
over a linear score, vanilla REINFORCE with a running-mean baseline,
**deterministic inline-LCG** action sampling (bit-reproducible — no RNG
builtin). The gate is an **ascent** gate (`F-RL-<KATA> = 1` when *mean episode
reward rises*) — the RL dual of the loss-descent gate.

| rung | kata | env · policy · objective |
|---|---|---|
| 1 | `bandit-pg` | contextual bandit · `softmax(W[s])` · REINFORCE + baseline |
| 2 | `gridworld-pg` | feature `φ(s)·W` policy · REINFORCE + baseline |

The REINFORCE update on the logits is the textbook `(π - onehot(a))·(R - b)`
with a running-mean baseline `b`; `opt_adamw_step` descends on that gradient,
which ascends reward — a real (not faked) policy gradient.

### `tabular` — tabular classifier

A flame classifier on a synthetic `T × F` feature matrix with a deterministic
class signal, **softmax cross-entropy descent gate** (`F-TABULAR-<KATA> = 1`).

| rung | kata | model · loss |
|---|---|---|
| 1 | `logreg` | `logits = X·W + b` (multinomial) · softmax CE · closed backward |
| 2 | `mlp-tab` | `relu(X·W1+b1)·W2+b2` · softmax CE · 2-stage backprop |

Each `train.hexa` runs on a CPU host today (forge matmul CPU `farr` fallback); a
forge-GPU host accelerates the **same** code unchanged. With `--lang=py|both`
each arm also emits a `ref.py` torch reference (the familiar-framework contrast
— **not** what ships).

## no-troubleshoot preflight (the "트러블슈팅 안하게" deliverable)

A flame-forge training kata can launch a **multi-GPU DDP** run in the cloud
(`DOJO_CLOUD=1 bash run.sh`). The emitted `run.sh` sources the shared rent +
preflight helper [`tool/dojo_rent_preflight.sh`](../tool/dojo_rent_preflight.sh)
and runs **six fixes BEFORE any cost-bearing rental**, so a kata rents + launches
*without the 2h-of-dead-pods* that the anima 7B DDP fire suffered. Every failure
prints a **CAUSE + FIX** line — never a silent dead pod. (Reflects sidecar
handoff `4474f21b`, anima → hexa-lang.)

| # | fix | what it prevents |
|---|---|---|
| **1** | **image-tag validation** — reject unknown RunPod image tags before deploy; on `desiredStatus=EXITED` + `runtime=null` **fetch the container init log** | `runpod/pytorch:2.4.1-…` does NOT exist (valid `2.4.0`) — an unknown tag deploys then EXITs with `runtime=null`, *indistinguishable from a supply failure* unless validated first |
| **2** | **auto-inject `PUBLIC_KEY`** — `~/.ssh/id_ed25519.pub` → env `PUBLIC_KEY` | without it the image start-script never launches `sshd` → ssh `PORT_CLOSED` forever despite the pod showing `RUNNING` + port-mapped |
| **3** | **supply fallback ladder** — `gpuCount 8→4→2`, `cloudType SECURE→COMMUNITY`, `gpuType H200→H100→A100-SXM` (community), take the first available id | 8-GPU on-demand `SUPPLY_CONSTRAINT` is frequent on secure H100/H200 — one rung failing should not kill the launch |
| **4** | **failure classification** — `SUPPLY_CONSTRAINT` (capacity) vs `id`-then-`EXITED`+`runtime=null`<1 min (image/init) vs `RUNNING`+no-sshd (`PORT_CLOSED`) | the three dead-pod classes look alike from the outside; each gets a **distinct** cause+fix line, and auth errors fail fast (not 18 identical retries) |
| **5** | **preflight per-GPU mem estimate** — closed-form budget from `(n_params, dtype, optimizer, DDP, grad-ckpt)` via [`stdlib/cloud/preflight.hexa`](../stdlib/cloud/preflight.hexa); **warn / BLOCK before OOM** | 7B fp32 (wt 28 + grad 28 + adamw 56 + DDP bucket) = ~134 GiB → **OOMs an 80 GiB H100 at step 0**, **fits a 141 GiB H200** — blocked *before* the pod spins up |
| **6** | **torchrun log harvest** — DDP launcher defaults `--tee 3` + `--redirect 3 --log-dir`, and **harvests per-rank `stderr.log`** on `ChildFailedError` | torchrun hides child errors (shows only `rank N exitcode 1`, `error_file:<N/A>`) — the real traceback is in the per-rank log |

### using the cloud path

```bash
cd exports/flame-forge/dojo/<slug>
# local CPU descent gate (default):
bash run.sh
# cloud multi-GPU DDP launch with the 6-fix preflight (override the spec via env):
DOJO_CLOUD=1 DOJO_PARAMS=7000000000 DOJO_DTYPE=fp32 DOJO_OPT=adamw \
  DOJO_NGPU=8 DOJO_GPU=h200-141gb DOJO_GPU_TYPE='NVIDIA H200' bash run.sh
```

> **dtype aliases (`fp32` / `f32`).** The `DOJO_DTYPE` env above (and the
> emitted `run.sh`) uses the bitsandbytes/torch-world spelling `fp32` / `bf16` /
> `fp16`. The hexa mem-estimate path (`stdlib/cloud/preflight.hexa`) canonically
> uses `f32` / `bf16` / `f16`, and now accepts the fp-prefixed names as
> **aliases** (`fp64=f64` · `fp32=f32` · `fp16=f16`) — so a recipe authored with
> either spelling maps cleanly to the same byte width on **both** the shell
> coarse-mem gate and the hexa preflight. (Before this fix, `DOJO_DTYPE=fp32`
> errored with `unknown --param-dtype fp32` on the hexa path; the shell fallback
> also lacked `fp32`.) The dtype-alias `fp32==f32` equivalence is covered by
> `bash tool/dojo_rent_preflight.sh --self-test`.

If the spec would OOM, the launch is **blocked before renting** with the fix
(drop to `adamw-8bit`, enable `--grad-ckpt`, shard, or move to a bigger tier).
If a supply rung is out of capacity, the ladder walks to the next rung. If the
API key is missing, it fails fast with `export RUNPOD_API_KEY=…`. **No silent
dead pods.**

You can self-test the helper's pure logic with no rental and no network:

```bash
bash tool/dojo_rent_preflight.sh --self-test    # verifies all 6 fixes
```

### app-side lessons (from the anima 7B fire — FYI, not tooling-fixable here)

- DDP + grad-ckpt + bitsandbytes optim-8bit, **all three on**, = silent child
  crash. Each *pair* is fine; use `no-ckpt + optim8bit` **or** `ckpt + fp32`.
- `corpus.done` via `touch` = 0 bytes → `[ -s ]` fails → a 15 GB re-fetch. Write
  real content (`echo`), not an empty file.
- A detached fire over ssh with a bg job holding the stdout fd → ssh hangs
  (exit 255). Wrap: `setsid bash -c '…' </dev/null >/dev/null 2>&1 & disown`.

> The **training-recipe** lessons (bench-before-vectorize, the bf16-weights
> memory recipe, the `optim8bit` element limit, the single-vs-multi-GPU
> decision rule — handoff `a10891bc`) have their own section below:
> **[Training recipe — optimization gotchas](#training-recipe--optimization-gotchas-dont-repeat-these)**.

## Training recipe — optimization gotchas (don't repeat these)

The 4474f21b preflight above hardens the **infra** path (renting + launching).
This section hardens the **training-recipe** path: six expensive lessons the
anima 7B `CLMConvMoE` DDP fire paid for, reflected here so a dojo user does not
re-pay them. These are **cited anima lessons** (sidecar handoff `a10891bc`) —
attributed, not re-measured here; the numbers are anima's H200 observations.

When a kata says "optimize the model" or "scale to multi-GPU", consult this
table **first** — the intuitive move is often the slower or the broken one.

| # | lesson | the dojo rule |
|---|---|---|
| **1** | **bench before you vectorize** — fusing 30 `ConvExpert` modules into one grouped `nn.Conv1d(E·d, E·d, K, groups=30)` (186 240 channels) ran **~14 min/step** on an H200, vs the plain `ModuleList` of 30 small convs at **~74 s/step**. A grouped conv with many groups *defeats* GPU group-parallelism and cuDNN can't pick a fast algo for that shape. | **Fewer kernel launches ≠ faster.** BENCH the grouped/fused form against the loop on **one step** before adopting it. Do **not** auto-vectorize an expert loop. |
| **2** | **DDP + grad-checkpoint + bitsandbytes `AdamW8bit`, all three on = silent child crash.** Each *pair* works; single-GPU works. torchrun *hides* it (only `rank N exitcode 1`). | Use `no-ckpt + optim8bit` **or** `ckpt + fp32` — not all three. If you must debug, launch via the 4474f21b fix #6 `--tee 3` harvest (see the preflight section) to see the real child traceback. |
| **3** | **`optim8bit` has a 2³¹ per-tensor element limit.** A single tensor with >2.1 B elements (e.g. the vectorized fused weight at 3.47 B) breaks bitsandbytes: `Error invalid configuration argument at ops.cu:226`. | If any **single** parameter tensor exceeds ~2.1 B elements, `adamw-8bit` is **out** — keep fp32/bf16 AdamW for that tensor. (This is a *second* reason not to build the giant fused weight in lesson #1.) |
| **4** | **7B memory recipe (H200, 141 GB).** fp32-AdamW = ~112 GB and allocator-thrashes at 96–99 % (step 0 took ~7 min); `optim8bit` is broken by #3; bf16-autocast *alone* doesn't help (weights stay fp32). | **WINNER = `--bf16-weights`** (model + grad + AdamW state all bf16 → ~70 GB) **plus** DDP `gradient_as_bucket_view=True` (−28 GB more). This is the recipe the preflight now *recommends* for ≥~3B-param models. |
| **5** | **`CLM_NO_CUDNN=1` is naive-slow** (minutes/step); cuDNN **on** is needed — but cuDNN still can't rescue the grouped-conv shape from lesson #1. | Leave cuDNN **on**. It is necessary but **not** sufficient; it does not make the wrong model shape fast. |
| **6** | **single-GPU can BEAT multi-GPU.** DDP replicates the *full* model on every GPU (per-GPU memory unchanged), so when the **model** (here, the conv) is the bottleneck — not data throughput — 4×H200 DDP **never** beats a single H200. The single-H200 `ModuleList` run trained M13 fine (CE 5.64→2.38 over step 0→200, ~74 s/step). | **DDP-decision rule:** scale to multi-GPU only when you are **data-throughput-bound**. If you are **model/compute-bound** (a big conv/GEMM per step), more GPUs don't help — fix the per-step model cost first, on **one** GPU. |

### how the dojo enforces this

- The flame-forge **README** for a model-authoring kata carries a
  **"bench-before-vectorize"** note (lesson #1) — the dojo does **not**
  auto-vectorize an expert loop for you.
- `tool/dojo_rent_preflight.sh` (the same fix #5 helper) now also:
  - **recommends `--bf16-weights`** for a model with ≥~3 B params (lesson #4),
  - **warns** that fp32-AdamW thrashes the allocator when the estimate lands
    near the cap (lesson #4),
  - **blocks/warns `optim8bit`** when any single tensor would exceed the 2³¹
    element limit (lesson #3) — pass `--max-tensor-elems N` to declare your
    largest parameter tensor,
  - prints a **"DDP won't help if model-bound"** advisory line (lesson #6 /
    prescription 2 — *don't parallelize a pathological op*), and
  - notes that **vectorizing a fused weight is what crosses the 2³¹ ceiling**
    that breaks `optim8bit` (prescription 3 — the causal link from lesson #1
    to lesson #3).

  Self-test it with no rental: `bash tool/dojo_rent_preflight.sh --self-test`.

### WHY parallel was the wrong path — root cause (decision-grade)

Lessons #1, #3 and #6 above are three faces of **one** wrong decision the anima
7B `CLMConvMoE` (~7.06 B params) campaign made. This subsection states the
root cause as a **decision rule**, not a table row, so a dojo user reaching for
"be a good multi-GPU citizen" sees *why* the obvious move backfired. These are
**cited anima H200 observations** (sidecar handoff `f5e18a0f`, the
decision/algorithm root-cause companion to recipe handoff `a10891bc`) —
attributed, **not** re-measured here.

**The trap (the "obvious" optimization).** The MoE layer ran its 30
`ConvExpert` modules as a `ModuleList`:

```python
# the ModuleList form — 30 small Conv1d launches per step
y = torch.stack([e(x) for e in self.experts])   # 30 × Conv1d(d, d, K), d=6208
```

To "be a good multi-GPU-DDP citizen" and cut **30 launches → 1**, the intuitive
move was to **vectorize** the expert loop into one grouped conv:

```python
# the "optimized" grouped form — ONE launch, E=30 groups
self.experts = nn.Conv1d(E*d, E*d, K, groups=E)   # E·d = 30 × 6208 = 186 240 channels
```

**The measurement (H200, cuDNN on *or* off).** The "optimization" was
**~11× slower**:

| form | per-step wall (H200) |
|---|---|
| `ModuleList` of 30 small convs | **~74 s/step** |
| grouped `Conv1d(E·d, E·d, K, groups=30)` | **~14 min/step** (~11× slower) |

**The root cause — fewer launches ≠ faster.** A grouped conv with `groups=30`
and `E·d = 186 240` channels **defeats GPU group-parallelism**: cuDNN can't pick
an optimized algorithm for that (very wide, many-group) shape and falls back to
a **naive path**. The 30 *separate* small (`d = 6208`) convs each map to a fast
cuDNN kernel and run **concurrently** on the SM scheduler — far better occupancy.
The launch-count intuition is simply **wrong** for wide grouped convs.

**The cascade — why the *parallel* path failed.** This is the decision-grade
part. DDP replicates the **full** model on every GPU, so **each** GPU still runs
the same **11×-inflated** grouped conv per step. You are parallelizing a
per-step cost that is *itself* 11× inflated:

- **4×H200 DDP** on the vectorized model was **slower wall-clock** than **1×H200**
  on the `ModuleList` model — at **4× the cost**.
- `a_wall_first` ("take the faster parallel path regardless of cost") only fires
  when parallel is *actually* faster. The honest measurement showed it was
  **not** — so single-GPU won on **wall time too**, not just on cost.
- DDP multiplies a pathological op; it does **not** fix it.

**The secondary trip-wire (silent).** The fused weight `(E·d, d, K)` is
**3.47 B elements** — past the **bitsandbytes 2³¹ per-tensor element ceiling**.
So vectorizing **also** silently broke `AdamW8bit`: `Error invalid
configuration argument at ops.cu:226`. It surfaced only via
`torchrun --tee 3`. **Vectorization is what crosses the 2³¹ ceiling** (lesson #3
is the *consequence* of the lesson-#1 mistake).

**The working production path (the canonical 7B-ENGINE recipe).** Single
**141 GB H200**, **`ModuleList` experts**, **grad-checkpoint + `AdamW8bit`**,
**~74 s/step**, CE descending cleanly `5.64 → 1.87` over step `0 → 1000`.

**Before → after, as a decision:**

| axis | the trap (chosen first) | the working path |
|---|---|---|
| expert layer | grouped `Conv1d(E·d,…, groups=30)` (1 launch) | `ModuleList` of 30 small convs |
| per-step wall | ~14 min/step (cuDNN naive path) | ~74 s/step (concurrent fast kernels) |
| scaling | 4×H200 DDP, slower than 1×H200 @ 4× cost | 1×H200, won on wall **and** cost |
| 8-bit optimizer | broken (3.47 B-elem fused weight > 2³¹) | works (no oversized tensor) |

**The four prescriptions (the decision rules):**

1. **Keep per-expert conv MoE as a `ModuleList` of small convs** — do **not**
   auto-vectorize into a grouped conv to "reduce launches". For wide
   `E·d ≫ 10⁵`-channel grouped convs cuDNN regresses to a naive path; **bench
   the grouped form against the loop on one step first.** (This *sharpens*
   lesson #1 with the measured root cause + the 11× number.)
2. **Before reaching for multi-GPU DDP, MEASURE single-GPU step time on the
   ACTUAL kernels.** If a step is dominated by a pathological op, DDP just
   **multiplies the pathology** — fix the op first, on one GPU. Parallel is
   "wall-first" only when the per-replica step is **already healthy**. (NEW
   rule — *don't parallelize a pathological op*.)
3. **Gate vectorization on the bitsandbytes 2³¹ per-tensor element ceiling.**
   Any fused param tensor with `numel > 2³¹` silently breaks 8-bit optimizers —
   and **vectorization is exactly what crosses that line** (the causal link to
   lesson #3).
4. **Canonical 7B-ENGINE working recipe:** single **141 GB H200**, `ModuleList`
   experts, **grad-ckpt + `AdamW8bit`**, **~74 s/step**.

> **cross-links.** This decision-grade root cause (handoff `f5e18a0f`)
> *complements* the two already-reflected handoffs: the **infra** preflight
> (handoff `4474f21b` — the "no-troubleshoot preflight" section above) and the
> **recipe** lessons (handoff `a10891bc` — the six-row table above). The
> preflight's `dojo_recipe_advisory` carries the two causal lines from this
> subsection — *DDP won't help a model/compute-bound run* (prescription 2) and
> *vectorization crosses the 2³¹ ceiling* (prescription 3) — see
> [how the dojo enforces this](#how-the-dojo-enforces-this).

> **honesty:** the six table lessons **and** this decision-grade root cause are
> **cited** anima H200 observations (handoffs `a10891bc` + `f5e18a0f`), not
> hexa-lang re-measurements. The dojo reflects them as *guidance + a preflight
> advisory*; it does not re-run the 7B job. The preflight's element-limit and
> bf16 recommendation logic is locally self-tested (pure arithmetic, no GPU);
> the underlying anima timings (the ~11×, ~74 s/step, the 4×H200-vs-1×H200
> comparison) are **not** reproduced here.

## references

- [`HEXA-CUDA.md`](../HEXA-CUDA.md) — the GPU-native domain home
- [`gpu/SPEC.md`](../gpu/SPEC.md) — the `@gpu` subset SSOT (§5 intrinsics · §6 shared mem · §7 launch ABI)
- [`stdlib/flame/`](../stdlib/flame/) — the flame substrate (`tensor_lib` · `nn_lib` · `optim_lib` · `ag_tape`)
- [`stdlib/dojo/flame_forge.hexa`](../stdlib/dojo/flame_forge.hexa) · [`vision.hexa`](../stdlib/dojo/vision.hexa) · [`rl.hexa`](../stdlib/dojo/rl.hexa) · [`tabular.hexa`](../stdlib/dojo/tabular.hexa) — the four flame-trainer authoring arms
- [`stdlib/dojo/clm.hexa`](../stdlib/dojo/clm.hexa) — the full `CLMConvMoE` cloud trainer the flame-forge ladder bridges toward
- [`stdlib/cloud/preflight.hexa`](../stdlib/cloud/preflight.hexa) — the closed-form GPU mem-budget SSOT (fix #5)
- [`tool/dojo_rent_preflight.sh`](../tool/dojo_rent_preflight.sh) — the shared 6-fix rent/preflight helper
- `.verdicts/hexa-cuda/F-HEXACUDA-DOJO.txt` — the g5 verdict (emit · parse · descent gate · preflight self-test · own-GEMM/megakernel reflection)
- `.verdicts/hexa-fusion/F-FUSION-SM90-WGMMA-W8.txt` · `…-W10.txt` · `.verdicts/hexa-fusion/F-FUSION-MEGAKERNEL-GN-GRIDSYNC.txt` — the landed own-GEMM W-ladder + grid-sync GroupNorm verdicts the track-1 "GPU own-GEMM parity & the persistent megakernel" lesson reflects (PRs #2841/#2847/#2845)
- [`docs/research/sm90-wgmma-parity-litscan.md`](research/sm90-wgmma-parity-litscan.md) — the `wgmma`/TMA/`SWIZZLE_128B` literature scan (#2846) behind the lesson's gotchas (a)/(d)
- sidecar handoff `4474f21b` — the 6-fix **infra** preflight (rent + launch) reflected in the "no-troubleshoot preflight" section
- sidecar handoff `a10891bc` — the 6 **training-recipe** lessons reflected in the "Training recipe — optimization gotchas" section
- sidecar handoff `f5e18a0f` — the **decision/algorithm root cause** ("WHY parallel was the wrong path") reflected in the [decision-grade subsection](#why-parallel-was-the-wrong-path--root-cause-decision-grade): the 11× grouped-conv regression · DDP multiplies a pathological op · vectorization crosses the 2³¹ ceiling · the canonical 7B-ENGINE `ModuleList`/H200/~74 s recipe
