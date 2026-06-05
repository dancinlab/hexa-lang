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
| `vision` · `rl` · `tabular` | stub | TODO (registered, no emitter yet) |

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

## references

- [`HEXA-CUDA.md`](../HEXA-CUDA.md) — the GPU-native domain home
- [`gpu/SPEC.md`](../gpu/SPEC.md) — the `@gpu` subset SSOT (§5 intrinsics · §6 shared mem · §7 launch ABI)
- [`stdlib/flame/`](../stdlib/flame/) — the flame substrate (`tensor_lib` · `nn_lib` · `optim_lib` · `ag_tape`)
- [`stdlib/dojo/clm.hexa`](../stdlib/dojo/clm.hexa) — the full `CLMConvMoE` cloud trainer the flame-forge ladder bridges toward
- [`stdlib/cloud/preflight.hexa`](../stdlib/cloud/preflight.hexa) — the closed-form GPU mem-budget SSOT (fix #5)
- [`tool/dojo_rent_preflight.sh`](../tool/dojo_rent_preflight.sh) — the shared 6-fix rent/preflight helper
- `.verdicts/hexa-cuda/F-HEXACUDA-DOJO.txt` — the g5 verdict (emit · parse · descent gate · preflight self-test)
