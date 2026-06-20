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

> ⚠️ **HW-귀속 정정 (2026-06-20 · forge cuBLAS 7→0).** 위 W-ladder 수치(W10
> 70.7 TFLOP/s · 6.09× off · "parity 미달성")는 **H100 `sm_90a` `wgmma`** 의
> 것이다 — forge 출하 parity 측정 호스트(**RTX 5070 `sm_120`**)와 **다른 HW** 이고,
> consumer Blackwell `sm_120` 엔 `wgmma` 가 없다. **`sm_120` 실측 결론은 정반대다**:
> forge own-GEMM 이 cuBLAS **PARITY** 에 도달했다 — **FP64 own 1.15~1.24× (전 shape
> 더 빠름 · rel-RMS 0 bit-exact)** — `sm_120` 엔 FP64 텐서코어가 없어 cuBLAS Dgemm 도
> SIMT 폴백이라 own 이 오히려 빠르다. **TF32 own `mma.sync` 는 cuBLAS-TF32 의 roofline 에
> 막힌 parity-band** (2026-06-20 sm_120 square sweep 실측: @768 1.05×·@2048 parity·256/
> 512/1024/4096 은 cuBLAS 가 12~46% 빠름 · opt/pipe 변종 전수 측정도 cuBLAS 미추월),
> vs cuBLAS-TF32 정확도는 rel-RMS ~1e-5 (FP64-ref 게이트 PASS · bit-exact 아님 — bit-exact 인
> 건 FP64 own 뿐). 즉 TF32 own 의 가치는 perf 가 아니라 byte-eq 결정성·cuBLAS 독립이다.
> 따라서 "parity 미달성 · 가치는 ownership 이지
> perf 아님" 은 **stale H100 결론**이고, **forge 는 production GEMM 에서 cuBLAS 호출
> 7→0 으로 독립**했다 (FP64 PR #3718 + TF32 PR #3727 · `self/cuda/runtime_cuda_emit.hexa`
> 의 6 GEMM 호출 전부 own-kernel env 게이트의 OFF 폴백으로 강등). flame 은 이 경로를
> 자동 상속한다(직접 cuBLAS 호출 0건 · 모든 GEMM 이 forge 게이트 런처로 수렴).
>
> **결정적(byte-eq) GPU 학습 — own-kernel 이 이제 기본.** cloud/dojo 잡은 별도 설정 없이
> own-GEMM 으로 돌고(cuBLAS 호출 0), 필요시 아래 env 로 opt-OUT 한다:
> - `HEXA_OWN_GEMM=0` — FP64(기본) GEMM 을 cuBLAS Dgemm 으로 되돌림. default(미설정)는
>   own `_hx_k_gemm`(`[OWN-GEMM-FIRED] … (no cuBLAS)` 마커) — FP64 own==cuBLAS bit-identical
>   이라 default-ON 이 byte-neutral. flame 기본 학습 경로가 이것.
> - `HEXA_TF32_OWN=0` — `HEXA_TF32_FASTMODE` 하위 레인의 own `mma.sync` 를 cublasGemmEx 로
>   되돌림. default 는 own(byte-changing vs cuBLAS — 이미 비결정 fastmode 레인 안).
>
> cloud 는 `cloud_validate_env_passthrough` 가 dispatcher 의 `--env` 전달을 검증할 뿐
> allowlist 차단이 아니므로, 이 두 env 는 별도 배선 없이 그대로 pod 로 전달된다.

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

### forge-CUDA build-trap absorptions (LAYER-A)

These are build/toolchain traps the dojo has already paid for, so a forge-CUDA
build never re-hits them. Each is a [[HEXA-DOJO]] LAYER-A milestone.

- **runtime_cuda.c emit — large-write drop + opt-in-link fork-bomb (DOJO-A1,
  handoff `677b84cd`).** The device runtime C is generated by
  `self/cuda/runtime_cuda_emit.hexa`, not hand-written. Two historical traps:
  (a) the emit assembled the whole ~300 KB of C into **one `exec()` argv string**
  (`cat > out <<EOF … EOF`) → `MAX_ARG_STRLEN` (128 KB) `E2BIG` → the file
  **silently never wrote**; (b) an *opt-in* `HEXA_CUDA_LINK=1` build path ran the
  emit as a nested `hexa run` that **inherited the env** and re-entered the link
  decision → unbounded recursion (**1800+ procs** on a live pod, GPU stays 0 MiB).
  - **Cure (a)** is on main: the emit writes via the `write_file` builtin
    (fopen/fwrite, no `ARG_MAX` limit), byte-identical output (#2630). **Never
    pipe a >128 KB generated file through an `exec`/`sh -c` argv — stream it to a
    fd.**
  - **Cure (b)** for the recursion is the `HEXA_NO_CUDA=1` guard on the nested
    emit (laneg `27535d93d`). On current main the `HEXA_CUDA_LINK` opt-in link
    path is **not present** (`grep HEXA_CUDA_LINK self/main.hexa` → no match), so
    the fork-bomb cannot occur; if that opt-in feature is ever merged, the nested
    emit MUST carry `HEXA_NO_CUDA=1` (it is pure C-string gen — needs no GPU).
  - **Verify the emit step locally** (no GPU): run it and check size + proc count
    — a clean run is a single short process writing the full ~300 KB:
    ```bash
    hexa run self/cuda/runtime_cuda_emit.hexa /tmp/runtime_cuda.c
    # → [runtime_cuda_emit] wrote /tmp/runtime_cuda.c   (≈308 KB; rc 0; 1 proc)
    ```

### forge-CUDA build traps (DOJO-A2 / DOJO-A3 — build the toolchain, don't get SIGKILLed)

Two build-time walls that bite **before any training starts** — when you put
the hexa toolchain itself onto a fresh CUDA pod and transpile a large program.
Both are now reflected as preflight advisories you can run on-pod.

| # | trap | symptom | the fix the dojo advises |
|---|------|---------|--------------------------|
| **A2** | **prebuilt hexa needs `GLIBC_2.38`, but the CUDA `-devel` base ships an older glibc.** `nvidia/cuda:12.4.1-devel-ubuntu22.04` (and the RunPod `…ubuntu22.04` images) ship **glibc 2.35**; Ubuntu **24.04** ships **glibc 2.39**. (handoff `4a7841fe`) | the prebuilt binary fails to load with `` version `GLIBC_2.38' not found `` — looks like a corrupt download | **use an ubuntu24.04 CUDA base** (`nvidia/cuda:12.4.1-devel-ubuntu24.04`, glibc 2.39 ≥ 2.38) **OR build hexa from source** on-pod so it links against the pod's local glibc |
| **A3** | **a large `main_expanded.hexa` SIGKILLs the Stage-1 transpiler on the default 8 MB stack.** Deep recursion overruns `ulimit -s 8192`; the process is killed mid-transpile. (handoff `d751e2c4`) | `stage_build_hexa` dies with no diagnostic (SIGKILL = no traceback), looking like an OOM or a crash | **raise the stack ulimit BEFORE the build:** run `ulimit -s 65536` (64 MB) — or `ulimit -s unlimited` where the shell permits — in the **same shell**, then invoke `tool/stage_build_hexa` |

How the dojo reflects these (the same `tool/dojo_rent_preflight.sh` helper):

- **A2 — `dojo_glibc_advisory`** detects the base glibc two ways: pre-rental
  it infers from the image tag (`…ubuntu22.04` → glibc ≤ 2.35 → WARN + the
  24.04/from-source recommendation), and on-pod it reads the **live** glibc via
  `ldd --version` and **BLOCKS** (returns non-zero) on a real `< GLIBC_2.38`
  mismatch. An ubuntu24.04 base (glibc 2.39) clears the check.
- **A3 — `dojo_stack_advisory`** reads the current `ulimit -s`; at the default
  ~8 MB it WARNs and prints the exact `ulimit -s 65536` raise to run **before**
  `tool/stage_build_hexa`. It is advisory-only (never blocks); it just makes
  sure the stack is raised before the large-main transpile.

```bash
# pre-rental: catch the glibc mismatch before you even spin up the pod
bash -c 'source tool/dojo_rent_preflight.sh
         dojo_glibc_advisory --image runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04'

# on-pod, right before building the toolchain:
source tool/dojo_rent_preflight.sh
dojo_glibc_advisory          # live ldd check → BLOCKS on < GLIBC_2.38
dojo_stack_advisory          # prints the `ulimit -s 65536` raise
ulimit -s 65536              # raise BEFORE the build (same shell)
bash tool/stage_build_hexa   # large main_expanded.hexa transpiles without SIGKILL
```

Both advisories are covered by `bash tool/dojo_rent_preflight.sh --self-test`.

## Training recipe — optimization gotchas (don't repeat these)

The 4474f21b preflight above hardens the **infra** path (renting + launching).
This section hardens the **training-recipe** path: six expensive lessons the
anima 7B `CLMConvMoE` DDP fire paid for, reflected here so a dojo user does not
re-pay them. These are **cited anima lessons** (sidecar handoff `a10891bc`) —
attributed, not re-measured here; the numbers are anima's H200 observations.

When a kata says "optimize the model" or "scale to multi-GPU", consult this
table **first** — the intuitive move is often the slower or the broken one.

> **determinism contract:** before refactoring any flame `CLMConvMoE` step phase,
> read [`flame-determinism-contract.md`](flame-determinism-contract.md) — the
> CPU byte-eq oracle invariants (3 load-bearing exp impls · sequential
> ascending-order reductions) that a "unify/fuse/tree-reduce" refactor silently breaks.

> **deterministic checkpoint/resume:** to STOP a flame run and RESUME it
> bit-for-bit, use [`stdlib/flame/ckpt_lib.hexa`](../stdlib/flame/ckpt_lib.hexa)
> (format `"FCK\x01"` v1) — `ckpt_begin(buf, t, n_params)` then
> `ckpt_save_param(buf, W, m, v, n)` per parameter **in the pinned param order**,
> and `ckpt_load_param(rb, off, W_out, m_out, v_out)` to restore (resume continues
> at `ckpt_step(rb) + 1`). Two gotchas: **(1) you MUST save the AdamW moments `m`,
> `v` AND the applied step `t`, not just weights** — a "weights-only" checkpoint
> resets bias-correction (`t→1`) and silently diverges (MEASURED 0.042; a missing
> `t` is the classic "looks fine, isn't" hole). **(2) NEVER serialize through text
> (`%g`/`to_string`)** — it's not shortest-round-trip and drops low mantissa bits
> (F-OP37 measured `to_string` corrupt fp64 by up to 2.027e-6). `ckpt_lib`
> reinterprets the raw fp64 **little-endian bit pattern**, so it is bit-exact
> (incl. denormals/-0.0/±inf/NaN) AND the bytes are **portable across
> machines/arches** (write on arm64-macos, resume on x86_64-linux → byte-identical).
> Proof: `stdlib/flame/op35_ckpt_resume_eq.hexa` (resume == uninterrupted,
> `max|Δ|=0`, + missing-`t`/fp32-truncation negative controls) +
> `op35_ckpt_xplat_selfcontained.hexa` (cross-platform `cmp`-identical). (F-OP35.)

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

### GPU kernel parity recipes — canonical-atom GEMM · weight-reuse conv · the under-fill/saturated regime law

> This is a **reading lesson, not a kata** (same scope as the track-1 own-GEMM war
> story above) — the levers are `.cu`/codegen-level, **not** source-callable from
> `.hexa` today. **Do not invent source calls for any of it.** Every number below
> is a **cited, byte-exact-gated** measurement from a landed HEXA-FUSION verdict;
> the gate is **correctness FIRST** (a perf number is reported only after the
> byte-exact gate passes). cuBLAS/cuDNN are the **roofline** throughout — the wins
> here are **reach-roofline / boundary-removal**, **not** raw-math superiority.

Three decision-grade recipes came out of this session's GPU-kernel work. The
first two are the two levers that actually move a stuck kernel; the third is the
**regime law** that tells you *which* lever to reach for. Mirrored to **commons
g82** (the cross-project GPU-kernel-recipe directive) so the rule travels.

**Recipe (a) — own-GEMM stuck off cuBLAS? Re-encode the operand in GLOBAL to the
canonical CuTe atom, so the TMA-landed SMEM tile is `wgmma`-ready (no decode band).**

The TF32 own-GEMM was pinned at **70.2 TFLOP/s, ~6.09× off** cuBLAS for five rungs
(OG11–OG15). The wall was a **contradiction**: a hand-rolled `cuTensorMapEncodeTiled`
box landed an **atom-major** `SWIZZLE_128B` SMEM tile that a descriptor-direct
`wgmma` could not read bit-exact, so the kernel needed a **32 KB software decode
band** in the hot loop — and that band ⊥ occupancy (it blew the SMEM budget, so you
could not also hold 2 CTA/SM). A 3200-config sweep of `(LBO, SBO, base_offset,
layout_type)` floored at rel-RMS **1.000** — no HW de-swizzle field combo matches a
hand-rolled box.

The fix (OG16) inverts the question. **Instead of asking a fixed HW de-swizzle to
match your box, pre-lay the operand in GLOBAL in the canonical CuTe
`Layout_K_SW128` / gmma-`INTER` (8×4 core) order and use a NO-swizzle TMA.** Now the
tile the TMA lands in SMEM **IS** the `wgmma`-ready layout the descriptor addresses
(`layout_type_=0`, descriptor-direct) — **no in-kernel decode band at all**. The
one-time global pre-permute amortizes over the K-slab reuse of a real GEMM (and over
batched/persistent weights).

| axis | stuck (OG11–OG15) | canonical-atom (OG16) |
|---|---|---|
| SMEM tile | hand-rolled atom-major box | canonical `Layout_K_SW128` (TMA-landed) |
| in-kernel decode | **32 KB software band** (⊥ occupancy) | **none** (descriptor-direct) |
| single-tile rel-RMS | 1.000 (no field combo matches) | **0.000** (bit-exact) |
| SMEM/CTA | 96 KB | **64 KB** (holds 2 CTA/SM) |
| own-GEMM | 70.2 TFLOP/s | **264.7 TFLOP/s** (3.77×) |
| gap vs cuBLAS-TF32 | 6.09× | **1.37×** (~85–90% of the gap closed) |

Honest: **parity (≤1.3×) is NOT quite reached** (best 1.37×); cuBLAS is the roofline
and no superiority is claimed. The remaining ~5% is a perf-only frontier (OG17:
warp-spec / larger tile / ping-pong, now **un-gated** since the band is gone), **not**
a layout or correctness question. The lever is: *make the landed tile the canonical
atom, don't decode it in the kernel.*

**Recipe (b) — conv / grouped-conv at a SATURATED shape? Recast as an implicit GEMM
and weight-reuse register-tile it — do NOT reach for fusion-fill.**

The d=6208 / H200 production MoE step (~74 s/step — the `f5e18a0f` wall) is **already
GPU-saturated (~92–96% util)**. The earlier `OG-FUSE-OPT` closed-negative proved
fusion-FILL **loses** there: a tiled-fused kernel still runs **3997 ms vs ModuleList's
3734 ms** at d=6208 — no under-fill headroom to recover, and every `(co,ci,k)` weight
is touched exactly once (no reuse), so fusion cannot shrink weight traffic. But that
closed-neg also named the **right** residual — **weight bandwidth** — and the **right**
cure: **weight reuse**.

The PROD-KERNEL fix supplies exactly that reuse. **Recast each expert's Conv1d as an
implicit GEMM** (`Y[t,co] = Σ_k Σ_ci Xshift_k[t,ci]·W_k[ci,co]`) and **register-tile**
it: a CTA owns `BM=64` time-steps × `BN=64` out-channels, stages a weight tile into
SMEM **once**, and **reuses it across all `BM` time-rows**. Each weight HBM byte now
amortizes over `BM=64` time outputs instead of being read once → the weight-bandwidth
roofline the OPT verdict pinned is **lifted**. Accumulation visits `ci` ascending, `k`
inner — the **exact** order of the 30-separate-conv reference, so the gate is byte-exact.

| d | ModuleList-30 | tiled-FUSED (fill) | GEMM-conv (weight-reuse) | speedup vs ModuleList |
|---|---|---|---|---|
| 4096 | 1649 ms | 1829 ms (**loses**) | **250 ms** | **6.60×** |
| 6208 (the wall) | 3734 ms | 3997 ms (**loses**) | **568 ms** | **6.57×** |
| 8192 | 13467 ms | — | **983 ms** | **13.70×** |

Byte-exact gate FIRST: **max|Δ| = 0** vs ModuleList-30 (device-vs-device at every
shape; 2.98e-7 vs a CPU fp32-FMA oracle). Util stays ~92% on **both** paths — so the
6.57× is **NOT** a fill/occupancy effect; it is pure **work-reduction via weight
reuse** (same FLOPs, weight HBM traffic cut ~`BM`-fold). cuBLAS stays ~15× below the
GEMM-conv (no superiority claim — we reach a much better point on the road to the
vendor ceiling, not past it). The lever is: *at saturation, cut weight traffic with a
GEMM recast, not launches with fusion.*

**Recipe (c) — the regime law: pick the lever by regime FIRST.**

Recipes (a) and (b) are not competing tricks — they apply in **different regimes**,
and reaching for the wrong one wastes a GPU session. The unifying law (from the
`OG-FUSE-OPT` / `XOVER` / `RIGHTSIZE` sweeps, #2862/#2865/#2863):

```
                    ┌─────────────────────────────────────────────────────────┐
   regime?          │  measure single-kernel util on the ACTUAL shape FIRST    │
                    └─────────────────────────────────────────────────────────┘
                              │                               │
            UNDER-FILL  ◄─────┘                               └─────►  SATURATED
   (small d · small/right-sized GPU ·                   (big GPU · d ≥ 1024 ·
    SMs idle · launch-count/boundary                     ≥ 98% util · no fill
    overhead dominates)                                  headroom · BW-bound)
                              │                               │
                              ▼                               ▼
   LEVER:  fusion-FILL — one saturating kernel       LEVER:  weight-reuse GEMM recast
           (fuse the op DAG / experts into a                 (implicit GEMM + register-
           single launch; remove launch +                    tile so each SMEM weight
           boundary overhead, fill idle SMs)                 tile is reused over BM rows;
                                                             cut weight HBM traffic ~BM×)
   evidence: RTX4070 (right-sized) won 3/4 fill       evidence: H100/H200 d=6208 saturated
             cases; under-fill d=512 fused 2.68×                — fill LOSES (tiled-D 3997 >
             vs ModuleList                                        ML 3734), GEMM-recast WINS 6.57×

   In BOTH regimes: cuDNN/cuBLAS = ROOFLINE. The win is reach-roofline /
   boundary-removal, NOT raw-math superiority. Byte-exact gate FIRST, always.
```

So the **first** question on any stuck conv/GEMM kernel is *which regime?* — measure
single-kernel util on the **actual** shape. Idle SMs → **fusion-fill**. Already
saturated → **weight-reuse GEMM recast**. Picking fill at saturation is the
`OG-FUSE-OPT` closed-negative; picking GEMM-recast at under-fill is wasted complexity.

> **cite (verbatim verdicts + PRs):**
> - `.verdicts/hexa-fusion/F-FUSION-SM90-WGMMA-OG16.txt` — canonical-atom descriptor-direct
>   own-GEMM (single-tile rel-RMS 0.000, 70.2 → 264.7 TFLOP/s, 6.09× → 1.37×, smem 96 → 64 KB)
>   · **PR #2866** [recipe (a)]
> - `.verdicts/hexa-fusion/F-FUSION-MOE-CONV-PROD-KERNEL.txt` — weight-reuse GEMM-conv MoE
>   (byte-eq max|Δ| = 0, 6.57× vs ModuleList-30 @d=6208, 6.6–13.7× across the sweep) · **PR #2867**
>   [recipe (b)]
> - the regime law sweeps: `OG-FUSE-OPT` (saturated fill closed-neg, **#2862**) · `XOVER`
>   (the under-fill ↔ saturated crossover, **#2865**) · `RIGHTSIZE` (right-sized-GPU fill wins,
>   **#2863**) [recipe (c)]
> - **commons g82** — the cross-project mirror of these three GPU-kernel-recipe rules.

> **honesty:** these are this-session HEXA-FUSION measurements (H100/H200, byte-exact-gated),
> cited verbatim from the verdicts above and attributed to their PRs — the dojo reflects them
> as decision-grade guidance and does **not** re-run the GPU jobs. cuBLAS/cuDNN remain the
> roofline; parity is **not** claimed (OG16 best 1.37×), and the conv win is **work-reduction**,
> not vendor superiority. The preflight `dojo_recipe_advisory` carries the one-line regime hint
> (*saturated → weight-reuse GEMM · under-fill → fusion-fill*) — see [how the dojo enforces this](#how-the-dojo-enforces-this).

### DDP (multi-GPU data-parallel) — the verified recipe (HEXA-DDP M1·M2·M3 🟢)

How to train across 2+ GPUs the hexa-native way (no NCCL). The collective is a
ring all-reduce; you verify it byte-exact FIRST in a hardware-free sim, then swap
only the transport for real GPU-to-GPU copies. **Honest scope (commons g83)**:
collective-GREEN ≠ training-GREEN — M1/M3 prove the *all-reduce*; M4 (#2894) proved end-to-end parallel TRAINING
byte-eq (1-GPU == 2-GPU weights/loss/grad, max|d|=0 on a real flame step); 4-GPU speedup is DDP-M5. N-GPU speedup is ALWAYS < N× (Amdahl + comm).

```
ring all-reduce — transport swapped in stages, schedule FIXED at 2(N-1) steps
 [ M1 sim ] ─ in-process N-rank array-copy ─ byte-eq vs serial sum (NO hardware) 🟢
 [ M3 real ] ─ cudaMemcpyPeer over 2 GPUs ── same byte-eq gate 🟢
 [ M4 ]   ─ 2-GPU flame step ─── 1==2-GPU weights/loss/grad byte-eq max|d|=0 (#2894) 🟢
 [ M5 ]   ─ 4-GPU ring ────── byte-eq N=4 + collective scaling 2(N-1)=6 steps (#2892) 🟢
 [ M5b ]  ─ 4-GPU train ───── 1==4-GPU byte-eq + speedup table (#2897) 🟢
 [ M6 ]   ─ MULTINODE ─────── ring over WAN TCP byte-eq, 2 providers (#2899 vast PL<->UA, #2896 runpod) 🟢
```

- **gate FIRST (g5)**: ring all-reduce result == serial elementwise sum, byte-eq
  max|Δ|=0 (FP64), test N∈{2,4} AND S-not-a-multiple-of-N (boundary) + a large S.
  Verified: M1 sim (`stdlib/ddp/ring_all_reduce.hexa`) + M3 real
  (`stdlib/ddp/m3_p2p/ring_p2p.cu`), both max|Δ|=0.
- **transport**: `cudaMemcpyPeer`. ALWAYS check `cudaDeviceCanAccessPeer(a,b)` BOTH
  directions first. ⚠ GeForce (RTX 3090/4090) on a PHB/PCIe-host-bridge topology
  has direct P2P **driver-disabled** (canAccessPeer=0) → falls back to a staged
  host copy (correct, but NO direct bandwidth). For the direct NVLink path rent a
  **datacenter card** (2× A100_SXM4 ≈ $1.47/hr, NV# bond in `nvidia-smi topo -m`).
- **rent multi-GPU**: `DDP_NUM_GPUS=N` (`tool/ddp_rent_lib.sh`, default 1 = the
  legacy single-GPU path byte-unchanged). `vastai search offers 'num_gpus>=2 ...'`
  — 2-GPU is cheap & plentiful (~$1.20–1.47/hr; a correctness run costs cents).
- **topology probe**: `tool/ddp_topo_probe.sh` runs `nvidia-smi topo -m` on-pod and
  classifies each pair NVLink(NV#) / PCIe(PIX/PXB/PHB) / SYS(cross-NUMA) → tells
  M3 which transport the pair actually supports.
- **N≥3 reduce-scatter is a right-nested tree (FP-assoc, M5b finding)**: the ring sums
  each chunk in a chunk-dependent nesting (e.g. chunk0 = `(3+(2+(1+0)))`), NOT a flat
  left fold. For a true max|Δ|=0 vs a 1-GPU reference, the reference MUST replay the
  ring's exact nesting (a naive left fold leaves a pure-associativity residual ~1e-14,
  not a transport bug). N=2 has one add so is trivially order-invariant; the tree only bites at N≥3.
- **multinode (M6) = swap the per-step transport to host TCP, schedule UNCHANGED**: the
  same 2(N-1) chunk-partition ring runs cross-node by replacing `cudaMemcpyPeer` with a
  TCP `sendall`/`recvall` (parity-ordered even-send/odd-recv = deadlock-free, no threads).
  Proven byte-exact over the PUBLIC INTERNET between two countries (vast PL↔UA) AND across
  2 runpod nodes — byte-eq is latency-INDEPENDENT (TCP reliable+ordered); only WAN
  throughput (M6b, untested) is the open perf question. M6 needs no GPU (host FP64 ring, ~$0.06/hr).
- **multinode networking gotchas**: runpod custom TCP ports gave no public proxy map →
  used an SSH dual-port-forward between public endpoints (still real kernel TCP); `connect()`
  to a tunnel port succeeds even if the far listener is down → add an interleaved SYN/ACK
  handshake that proves the far LISTENER is up (startup-order-independent); `pkill -f` over
  SSH self-matches its own command line → use `pkill -x`.
- **WHY per-step DDP never beats 1-GPU — weight-bound ceiling (M5c, on REAL NVLink)**: A/B
  on identical 4×A100-SXM4 (one NV12-NVLink canAccessPeer=1, one PHB-staged) — NVLink lifts
  efficiency to near-ideal (2-GPU 43→49.5%, 4-GPU 18→24.2%) but 2-GPU asymptotes to 0.99× and
  4-GPU to 0.974× — NEVER crosses 1.0× at any model size. The residual gap is STRUCTURAL not
  comm: pure data-parallel shards only the BATCH; an H→H step is the H² GEMM = weight-bound, so
  sharding 64 rows barely cuts per-rank FLOPs. The 1.0× per-step ceiling holds on any transport.
  DDP's real win is THROUGHPUT (fixed per-GPU batch, global batch ×N → samples/s ~N×), or
  tensor/model parallelism (shard the H² weight) — NOT per-step latency. ⚠ vast SXM4 does NOT
  guarantee NVLink; cudaDeviceCanAccessPeer is the only authoritative check.
- **DDP byte-eq holds at PRODUCTION 7B (M7, real 4×H200 NVLink)**: 7.011 B params @ fp32 and
  5.493 B @ FP64 (FP64@7B = 168 GB/GPU > 143 GB VRAM, named cap) — both 1-GPU==4-GPU max|Δ|=0
  (weights/grad/loss/rank-agreement). grad-of-sum=sum-of-grads is scale-invariant, so the small-MLP
  max|Δ|=0 (M4) + the 7B max|Δ|=0 (M7) BRACKET production with no gap — the invariant is proven, not assumed.
- **WAN ring throughput is RTT-bound, not window-bound (M6b, PL↔California)**: RTT floor ~300 ms;
  throughput FLAT ~30-40 KB/s across 1KB–1MB (a 1 MB all-reduce = 31 s), never bandwidth-bound. A
  32 MB TCP-buffer sweep was indistinguishable from default (clean NEGATIVE) → the limiter is the
  ring's per-phase blocking send-then-recv serializing one full RTT per phase, NOT the TCP window.
  Synchronous cross-country DDP is usable only when compute≫comm, or after re-pipelining the two
  phases to overlap. Commodity-WAN-TCP reality, not RDMA.
- **speedup is honest (M5b, commons g83)**: 4-GPU DDP on a small model + host-staged (no
  NVLink) is SLOWER than 1-GPU (0.61–0.73×) — comm tax > compute saved; efficiency rises
  monotonically with model size (15%→18% as H 64→2048). N-GPU speedup is ALWAYS < N×; the
  crossover where 4-GPU wins needs a bigger model and/or NVLink (measured directions, not asserted).
- **env gotchas (recorded from the M3 fire)**: (1) a stale forward-compat `libcuda`
  on the rented image → `export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu` before the
  CUDA build/run. (2) inline `ssh -o ...` flag mangling → use an SSH **config file**,
  not inline `-o`. (3) git-guard hard-blocks `--force`/`--force-with-lease` here —
  to update a stale branch, rebase onto a fresh branch + new PR, never force-push.

### flame GPU train-speedup — where it comes from (and where it doesn't)

The flame CLMConvMoE train step on H100/H200 — what actually moves the wall, measured end-to-end.

```
flame self-speedup vs batch (H100, D1536/T512, samples/s ÷ B=1)
 B=1 ─▶ B=2 ─▶ B=4 ─▶ B=8 ─▶ B=16 ─▶ B=32 ─▶ (≈3× asymptote, glue cap)
 1.0×  1.50×  2.01×  2.39×  2.74×   2.95×
       ★ ≥1.3× here
```

- **batch>1 SM-fill IS the lever (#2913 🟢)**: at batch=1 the step UNDER-FILLS the GPU (grid ≈528-660
  CTAs vs 132/148 SMs → util 1-2%). Growing the batch fills the SMs and amortizes fixed per-step
  overhead → **≥1.3× at B=2, 2.95× at B=32** self-speedup. Byte-eq: B=1 max|Δ|=0 (exact prior path);
  B>1 window-concat carries a K-1 causal-conv SEAM-only Δ at window boundaries (a true max|Δ|=0 batched
  step needs a per-window-segmented causal conv). Harness: `bench/vs_pytorch/batch_{sweep,byteeq}.sh`.
- **capped at ≈3× by the interpreted per-step glue**: the token-pack t_get/t_set loop + CE/softmax-grad
  host glue + eager ~28-call AdamW tail all grow ∝ B·Tw, so they cap the curve. util MEAN climbs
  10→30% but MEDIAN stays 0% (bimodal {100% in-GEMM, 0% in glue}).
- **what does NOT help (don't re-attempt for speed)**: per-step CUDA-graph capture/replay (#2910) and
  fwd+bwd kernel-fusion (#2911) both = ~1.0× closed-neg — the wall is the interpreted glue, NOT
  kernel-launch/boundary. own-GEMM ≈ cuBLAS (GPU peaks 100% in GEMM bursts), so GEMM isn't the wall either.
- **vs PyTorch (honest, #2912)**: at batch=1 torch eager is ~1656× / torch.compile ~2207× faster — flame's
  interpreted glue dominates. ⚠ **That ~1656× is FP64-vs-TF32 + interpreted-glue, NOT the compute gap**:
  matched-dtype compiled (`F-BENCH-1`) the gap is **single-digit — FP64 flame ties/wins (B=2 0.98×, B=4/8
  flame faster), TF32 torch 3.03×→7.88×**. Quote `F-BENCH-1`, not the 1656× headline (see §fair-bench below). flame's value is byte-exact · device-resident · no-LLVM compile-time-theorem,
  NOT step-rate-vs-torch. interpreter-elimination FALSIFIED this (#2915 🔴): native-AOT-compiling the per-step driver = ~1.0x
  (byte-eq max|d|=0, H100 util 0.43% = same), because the heavy ops are native-C builtins in BOTH arms. The
  ~3x cap is STRUCTURAL: the serial un-fused FP64 op-DAG + per-op launch/sync dispatch. The ONLY uncap levers
  left (both != ~1.3x-of-FP64) = precision-change (TF32/BF16 + dense fusion) OR a right-sized GPU. commons g85.

### flame vs PyTorch — fair-bench parity recipe · commons g86

Benched fairly (compiled step + matched dtype, D=768..4096 × B=1..8 × {FP64,TF32,BF16}, H100), flame
wins-or-ties torch.compile in every cell. FP64 flame wins (torch has no FP64 tensor-core path); TF32/BF16
win-or-tie. Two recipes carry it:

- **the step (flame calls cuBLAS)**: close the GEMM-bound cells with **fused valley (LN+gelu) + single-launch
  AdamW + transpose-elimination** (compute bwd `dW=A^T@dG` via cuBLAS `OP_T`, no separate k_transpose pass).
  Glue-fusion is the lever — graph-capture and cuBLAS-Lt GEMM-autotune do nothing here.
- **the no-LLVM own-GEMM (no library)** = cuBLAS bit-exact **PARITY (1.10x @D=2048)**. The lever is
  **decode-elimination**: build the wgmma GMMA descriptor (swizzle-mode + leading/stride byte-offset) to read
  the TMA-landed swizzled smem IN PLACE, not un-swizzled into a 2nd buffer. Bit-exact route = pre-permute global
  to canonical gmma-INTER + NO-swizzle TMA (a swm=1 descriptor at atom-major SWIZZLE_128B floors at rel-RMS 1.0).
- **the boundary**: the ~1.5x tail-quant residual at D=4096 (1024 tiles / 132 SMs) is closable only by split-K,
  which changes FP32 accumulation order and breaks byte-exactness — so flame refuses it. The residual is the
  identity, not a missing optimization.

### deterministic TF32 fast-mode (precision-uncap)

flame's FP64-default step is `~3×`-capped at batch=1 (serial op-DAG + per-op launch/sync + interpreted glue).
Kernel-fusion, interp-elim, and graph-capture are all closed-neg. The one uncap lever that works without a
right-sized GPU is **precision-change**: run the GEMMs in TF32 instead of FP64. The catch the campaign resolved
is that FP64→TF32 breaks byte-equality *vs FP64*, but a TF32 step is still byte-equal *vs itself* run-to-run —
so flame's reproducibility identity is preserved at a different **precision contract** (W14: rel-RMS ≤ 1e-2 vs
the same dtype, not byte-equality across dtypes). That makes "deterministic TF32 fast-mode" a legitimate flame
product mode, not an identity sacrifice.

**when to use it** — set `HEXA_TF32_FASTMODE=1` to opt the live forge projection-GEMM into TF32 when you want
the `>3×` speedup AND keep run-to-run determinism. With the flag unset the FP64 `cublasDgemm` path is the default
and is byte-identical (the TF32 branch never mutates the FP64 inputs). Use it for training/throughput; keep FP64
when you need byte-equality *across machines/dtypes* (the machine-independent identity is an FP64-path property).

**the determinism guarantee** — the TF32 step is self-byte-eq run-to-run: max|Δ(W′, m, v, loss)| = 0 over a
single step (8/8 cells) and over a whole 100-step trajectory (W and loss max|Δ| = 0 at step N, not just step 1).
On the RTX 5070 / cuBLAS 13.0 the **default** TF32 tensor-op mode is already deterministic (the feared split-K
heuristic nondeterminism did not materialize), but cuBLAS algo selection is shape/version/GPU-dependent — so the
shipped wire **pins `CUBLAS_PEDANTIC_MATH`** as the portable guarantee. Pedantic costs ~0 here (identical bytes,
identical step time) and removes the "happens to be deterministic" dependency for cross-card portability.

**the precision contract (W14)** — TF32-vs-FP64 rel-RMS is **1.13e-6** (single-step post-AdamW weight delta) —
four orders of magnitude inside the W14 1e-2 cap. The raw single-GEMM-output rel-RMS through the live dispatch is
~2.9e-4 (still ~34× inside W14); the LR=1e-3 optimizer update shrinks that to e-6 at the weight level. The TF32
step is training-equivalent to the FP64 step.

**it is a REAL fast-mode, not a 1-step illusion** — over N=100 steps the TF32 loss tracks the FP64 loss to ~1e-7
every step (worst gap 2.5e-5, and that worst gap is at the cold-start step 1 — it does NOT grow), and the weight
rel-RMS stays BOUNDED at ~5e-7 (it shrinks as both lanes converge to the same loss along the same curve). NN
training is chaotic, so the weights are not byte-equal to FP64 and never will be — but the loss-tracking (the
training-equivalent metric) holds, which is what makes TF32 a real training fast-mode.

**the speedup (card-robust)** — the honest, card-robust number is the **B=1 latency-bound 4.2×** (4.19×–4.63× over
FP64), which clears the `~3×` cap on exactly the regime the cap is attributed to. The B=8 ratios (19–21×) are
INFLATED by the consumer 5070's ~1/64-rate FP64 — quote them only with that caveat; a datacenter card (FP64 ~1/2)
shows a smaller ratio.

**the precision Pareto** — BF16 was checked as the next rung and is **Pareto-DOMINATED** by TF32: under the
standard fp32-master-weight contract BF16 lands the SAME accuracy (~1.1e-6, the bf16 GEMM error enters W through
one tiny optimizer step) and the SAME speed (both are 16-bit-input tensor-ops at equal throughput; TF32/BF16 =
1.01×–1.12×, a B=1 dead heat). BF16 buys nothing TF32 doesn't already give on consumer hardware. TF32 is the
terminal precision-uncap **sweet spot**.

```
precision Pareto (RTX 5070, flame fused step DAG)        speed (B=1, vs FP64)
  FP64  exact (reference) ──────────────────────────────  1.0×   byte-eq across machines
  TF32  rel-RMS 1.13e-6 vs FP64 ────────────────────────  4.2×   ◀ SWEET SPOT (self-byte-eq)
  BF16  rel-RMS 1.13e-6 vs FP64 ────────────────────────  4.1×   ✗ DOMINATED (same acc, same speed)
                              │                              │
                          W14 ≤ 1e-2  (1.13e-6 = 4 orders inside)   │
                                                          breaks the ~3× FP64 cap
```

**the live-wire dispatch site** — `HEXA_TF32_FASTMODE` is read in `self/cuda/runtime_cuda_emit.hexa`,
`_hx_cuda_farr_matmul_gpu` (the forge row-major projection GEMM the trainer's `conv*_via_forge` calls). Dispatch
order: `if(HEXA_OWN_GEMM){…} else if(_forge_tf32_fastmode()){tf32} else {cublasDgemm}`. The TF32 branch casts the
FP64 A/B into fp32 scratch (never mutating the FP64 inputs), runs `cublasGemmEx(CUBLAS_COMPUTE_32F_FAST_TF32)` on a
separate `CUBLAS_PEDANTIC_MATH`-pinned handle, and casts the fp32 result back up to the FP64 C buffer. Verified at
the dispatch-unit level on the aiden 5070 (FP64 default byte-identical · TF32 self-byte-eq · W14-tol · `>3×`); the
full-trainer end-to-end wire is the OP-2b-class `clm_prod_gpu`-build follow-up (the GEMM-only ratio dilutes toward
the card-robust ~4.2× once the non-GEMM glue is in the loop).

(verdicts: `.verdicts/hexa-0pod/F-OP20-TF32-FASTMODE.txt` · `…F-OP23-TF32-DRIFT.txt` ·
`…F-OP24-TF32-LIVEWIRE.txt` · `…F-OP25-BF16-FASTMODE.txt`)

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
- sidecar handoff `4a7841fe` (DOJO-A2) — the **`GLIBC_2.38` vs CUDA-`devel` base glibc** build trap, reflected as `dojo_glibc_advisory` + the [forge-CUDA build traps](#forge-cuda-build-traps-dojo-a2--dojo-a3--build-the-toolchain-dont-get-sigkilled) subsection
- sidecar handoff `d751e2c4` (DOJO-A3) — the **Stage-1 transpile SIGKILL on the 8 MB stack** build trap, reflected as `dojo_stack_advisory` + the same forge-CUDA build-traps subsection
- sidecar handoff `a10891bc` — the 6 **training-recipe** lessons reflected in the "Training recipe — optimization gotchas" section
- sidecar handoff `f5e18a0f` — the **decision/algorithm root cause** ("WHY parallel was the wrong path") reflected in the [decision-grade subsection](#why-parallel-was-the-wrong-path--root-cause-decision-grade): the 11× grouped-conv regression · DDP multiplies a pathological op · vectorization crosses the 2³¹ ceiling · the canonical 7B-ENGINE `ModuleList`/H200/~74 s recipe
- `.verdicts/hexa-fusion/F-FUSION-SM90-WGMMA-OG16.txt` · `.verdicts/hexa-fusion/F-FUSION-MOE-CONV-PROD-KERNEL.txt` — the two byte-exact-gated GPU-kernel parity breakthroughs (canonical-atom own-GEMM 6.09× → 1.37× · weight-reuse GEMM-conv 6.57× @d=6208) reflected in the [GPU kernel parity recipes](#gpu-kernel-parity-recipes--canonical-atom-gemm--weight-reuse-conv--the-under-fillsaturated-regime-law) subsection (PRs #2866/#2867); the regime-law sweeps `OG-FUSE-OPT`/`XOVER`/`RIGHTSIZE` (#2862/#2865/#2863)
- **commons g82** — the cross-project mirror of the three GPU-kernel-recipe rules (canonical-atom GEMM · weight-reuse conv · the under-fill/saturated regime law)
