# hexa-lang

Native compiler for the `.hexa` language with an embedded theorem **atlas** and the `hx`
package manager. No LLVM anywhere: source is lowered through the compiler's own IR to native
objects (ELF64 / Mach-O arm64) and linked with `hexa_ld` — a byte-identical self-host fixpoint
(`gen3 ≡ gen4`), default for `--emit`. Two C pieces still remain: a C-transpile fallback
delegate for some full `hexa build`/`run` flows, and the ~5.5k-LOC C runtime substrate (the
libc/syscall bootstrap floor, generated from `.hexa` emitters). The hand-tracked `self/*.c`
floor is being driven to zero — its last direct member became an emitter SSOT (literal
`ls self/*.c == ∅` reached **flip-free**, #4282); the emitted C content is a **fully
reducible** RUNTIME-PORT target (M3 open) — **never an irreducible floor, never a permanence
policy** (the old "irreducible-bootstrap" framing is retired: every wall is research-then-break).
Every formula-bearing function must cite an atlas law (`@cite(L[id])`), carry an active
`@verify`, or declare a `@grace` — otherwise the build refuses to emit a binary (stage S8,
fatal `HX8004`). **Domain tracking is fully retired** (2026-06-20): the per-domain `*.md`
snapshots, `*.log.md`/`*.tape` step-logs, `DOMAINS.tape` roster, **and the ARCHITECTURE.json
`domains` section itself** are gone — domain/milestone status + history live in CHANGELOG + git
only (no domain registry).

> ### ⚡ Performance gold standard — frontier language/framework baseline (top-priority implementation lens · 2026-06-29 owner)
> The hexa-lang implementation prioritizes treating **Go · Rust · PyTorch as the reference-match gold standard** (strengthens commons `reference-match`·`native-canonical-first` · consistent with the existing 'overtake' discipline — first look at how the frontier does it, then match it).
> - **Performance bar = Rust-equal or better (≥ Rust).** Rust is the primary performance baseline — compiler·runtime·generated-code·kernels must equal or exceed Rust. **But no-LLVM(LLVM-free)·byte-exact are *maintained* as non-negotiable core invariants (transcendence axes)** — reach Rust performance while keeping these (not dropping/bypassing). Only "LLVM-free so it's OK to be slow"-style complacency is forbidden (keeping the invariant ≠ justifying slowness) — losing to Rust on performance is incomplete, but **winning by adopting LLVM is not the answer** (win via no-LLVM direct native-emit codegen).
> - **Numeric/ML throughput axis = PyTorch(+cuBLAS)-equal or better.** flame/forge GEMM·training·decode throughput is measured·compared against PyTorch as the gold standard.
> - If the gold standard is open source, **look at its implementation directly and match it** (source file:line → component 1:1 comparison → align the first divergence point); after parity, advance via hexa's own 'transcendence axes' (byte-exact·vendor-free·no-LLVM·device-residency). Performance claims are **proven by measurement** (c2 · measure-or-it-didn't-happen).
> - **Canonicality = not only performance parity but matching the surface/idiom (API·idiom) to the gold standard too.** Follow the reference ecosystem's **primary surface** (runtime APIs like torch `use_deterministic_algorithms()` · cargo/pip/go-mod conventions) as-is, without substituting bespoke env-flag/wrapper/shim. Even at equal performance, *a non-canonical surface* (env-only·hand-rolled bypass) is incomplete. **commons `native-canonical-first` is a primary lens on par with the performance banner** — reference-match both performance and surface.
> - **Demonstration (#4214):** determinism-mode surface = env-only `HEXA_DET` is half the torch canon (env = escape-hatch level) → corrected to native API `set_deterministic(true/false)` primary + env escape-hatch (PR #4214). = first application of the "surface is also the gold standard" principle — eval/verdict/decode entry points can force determinism via an in-process direct `set_deterministic(true)` call (resolves the old `HEXA_DET` setenv-impossible caveat).

> 📍 Structure/design SSOT: [ARCHITECTURE.json](ARCHITECTURE.json) — directory·module tree + dataflow single
> ledger (JSON; human viewer `architecture.html` · `python3 serve.py`) · governance/rule SSOT: the
> work rules below (`harness.config.json` profile `hardcore` · stack `hexa` · vendored
> [dancinlab/harness](https://github.com/dancinlab/harness) `.harness-engine` submodule) · history:
> [CHANGELOG.jsonl](CHANGELOG.jsonl) (append-only). This file = entry pointer only (old `project.tape` ·
> `ARCHITECTURE.md` · per-domain tracking retired).

### Work-rules overview (do / dont)

Release integrity · self-host · atlas · overtake. Every rule is substantive — keep them, don't drop them. The
`## ` sections below are the governance SSOT (each section = slug-keyed do/dont).

### Harness

This repo is governed by the vendored [dancinlab/harness](https://github.com/dancinlab/harness)
engine, pinned as the `.harness-engine` git submodule and wired through `.claude/settings.json`
hooks (guarded: each hook is a no-op when the submodule binary is absent). Config lives in
`harness.config.json` (profile `hardcore`, stack `hexa`). The harness enforces single-document
discipline (architecture SSOT + append-only log + quickref pointers), L0 lockdown reminders,
the changelog gate for `.hexa` changes, and protected branches (`main`, `master`).

```sh
git submodule update --init --recursive          # activate (hooks no-op until present)
.harness-engine/bin/harness <cmd>                 # via wrapper
```

#### Quick reference

| Command | Purpose |
|---------|---------|
| `harness docs check` | single-doc discipline: architecture SSOT + log + quickref pointers |
| `harness lint` | staged-L0 + freshness + convergence gate |
| `harness verify` | run configured verification (`hexa verify`) |
| `harness audit` | 6-axis self-scorecard |
| `harness gc` | broken markdown links in guides |
| `hexa verify` | g5 gate: S6 equational + S8 citation + atlas reverify/auto-fold |
| `hx commit` / `hx push` | SSOT-attested git wrappers (re-run lint gate) |

## Release integrity — absolute top guardrail

- do: self-host work (byteeq `gen3≡gen4` · measure · RT-NATIVE · zero-C) proceeds **only insofar as it doesn't
  break the actually-used release**. If there's regression risk, first guarantee release green then proceed,
  and if risky, defer self-host progress — **release integrity > self-host progress**.
- dont: do not merge **changes that break the user-facing path** — shipping binaries (`hexa`/`hexa.real`) · `hexa build`/`run` · stdlib · C-transpile fallback
  etc. — for the sake of a self-host gate (native arena · `#else` drop · substrate
  byte reduction).
- do: merge codegen/runtime changes only after confirming **byteeq 3-target (x86_64-linux · arm64-linux · darwin-arm64) GREEN +
  shipping smoke pass**. Bit-identical improvements go into the default build without a gate (e.g. gemm-perf
  #3636 ungated 2.4×); isolate only bit-changing·environment-dependent improvements behind opt-in toggles (e.g. gemm-omp #3634
  `HEXA_OMP=1`).
- do: the release channel is **a single `stable`** — consumer default · verified `vX.Y.Z` Latest. The old `edge`·`test`
  rolling prerelease channels are **all fully retired** (`edge` early 2026 · `test` 2026-06-30). `test` retirement
  = remove the release.yml `on.push.branches:[main]` trigger + remove the setup `release_tag=test` branch +
  remove the `test` tag force-move step + remove the install.sh `HEXA_VERSION=test` path + delete the remote `test`
  release·tag. Verification of experimental self-host changes (byteeq · measure · RT-NATIVE · zero-C · static-musl)
  is obtained via **PR CI (Blacksmith 3-target byteeq) + pool builds** — no constantly-flowing prerelease channel.
  static-musl·cuda auxiliary assets are now bundled in every `vX.Y.Z` tag release (install.sh falls back to glibc if absent).
- dont: **do not promote to stable on "only x86 green"** (lesson from the v0.241.0 arm64-asset-unpublished regression — one target
  green is not all-green). Promote to stable only when all 3-target release jobs are GREEN + install.sh consumer
  smoke (`hexa --version` + hello/exit42 run) is GREEN.
- do: trust mechanical enforcement — each platform job in `release.yml` uploads assets as prerelease only and
  does not mark Latest. The `finalize` job (`needs:` all 3 targets) flips the tag to stable
  Latest only on 3/3 success (blocks the v0.241.0/.1 2/3-Latest incident).
- do: immediately after publishing a new release (`vX.Y.Z` tag), sync that release to the pool shared hosts (`aiden` · `summer`) too
  via `install.sh` — `harness pool on <host> 'curl -fsSL .../hexa-lang/<tag>/install.sh | sh'`
  (so the pool's build·byteeq·measure doesn't pick up a stale binary/seed).

## Implementation discipline — implement-to-the-wall · reference-first

- do: push every implementation·improvement·investigation **until it hits the wall (🧱)**. When a round ends, name the honest next
  round (r2 · r3…); stop only when ⓐ goal achieved (🏁) or ⓑ a **measured** closed-negative
  wall (🧱: efficiency roofline · correctness · absence of an honest next step in functionality). Drive the root cause
  **all the way to merge**.
- dont: no "discover/diagnose only, then STOP" midway (no punt). No symptom patches · no shadow guards. Don't fabricate filler
  rounds.
- do: prove the wall with **captured numbers** (roofline % · byte-eq Δ · measured GFLOP/s). Don't claim a wall/gain by LLM
  self-judgment.
- do: when implementing·improving a known algorithm from-scratch, **lay out verified code from other languages·packages
  as the reference (gold standard) and borrow the strategy**. White-box diff: ⓐ read the reference source closely →
  extract algorithm·verification-constants (cite file:line) ⓑ dump reference intermediate-value runs ⓒ compare the same quantities of my implementation
  component-by-component 1:1 → pin down the divergence point numerically ⓓ align **only that point**. Use
  black-box only when you can't see the gold standard (closed · undumpable). After exact replication of the gold standard, don't force-match the residual — honestly record its source (pseudo · grid · precision).
- dont: **no black-box guess sweep** that shakes parameters (tile · unroll · blocking constants · tuning values) chasing target numbers
  (compute waste + tune-to-green risk). reference-mapping demonstrations: GEMM/farr_matmul perf
  → OpenBLAS/BLIS microkernel (BLIS GEBP MR6 NR8 MC72 KC256 NC4080 packing + 3-tier cache blocking = 62~79%
  OpenBLAS roofline · r4 #3652, a counterexample to the ~10–24% ceiling of flag tuning) · LLM decode/weight loading →
  llama.cpp/ggml (mmap+contiguous unboxed tensor) · QFORGE el-ph physics reproduction → Quantum ESPRESSO intermediate-value
  dump comparison · numeric kernels → numpy/scipy/LAPACK.
- do: parity is a starting point, not an endpoint — once reference-borrowing reaches parity,
  explore in the honest next round the direction that **goes beyond-parity via hexa's own strengths the reference lacks**.
  hexa overtake levers: ⓐ byte-eq determinism (gen3≡gen4 fixpoint) ⓑ no-LLVM direct native
  emit (codegen forges kernels directly · fusion/arena specialization · call-boundary elimination) ⓒ device-resident · @cite-verified
  training (flame/forge) ⓓ domain fusion. Prove overtake too **with measured numbers** (roofline % · GFLOP/s · byte-eq Δ).
  demonstration: GEMM+epilogue (bias/residual) fusion = large +20% (max|Δ|=0) · prefill +3.3% · MLP +5.5% (r5
  #3656) · cuBLAS calls 7→0 (FP64 own 1.15~1.24× faster byte-neutral + TF32 mma.sync m16n8k8 parity ·
  default-ON `HEXA_OWN_GEMM`/`HEXA_TF32_OWN` to opt-OUT · #3718/#3727). Next overtake = chained-GEMM
  fusion (`gelu(x@W1)@W2` intermediate activation not materialized to DRAM).
- dont: fusing anything ≠ gain — fuse only memory-bound epilogues (bias/residual). Fusing compute-bound
  epilogues (gelu etc.) is closed-neg (compute cost > round-trip savings). byte-eq determinism is not an overtake lever —
  falsified (OpenBLAS too is thread-independent bit-identical in the same build · r5 measurement).

## HEXA-UNBOX — "unboxing" (runtime-speed campaign · invocation trigger)

- do: when the user says **"unboxing"** (`HEXA-UNBOX`), continue this campaign — strip the native boxed-HexaVal 16B tax per kernel for raw-native direct wiring → **real runtime acceleration** (k1 2.95×·k2/k4 4.48×·k3 9.78×). SSOT=memory `project_hexa_runtime_gap_allclosure`.
- do: measure-first — `tool/measure_codegen_perf.sh` (isolated alternating median-7); in-harness back-to-back ratio = contamination (3 prior cases hid 9.78×→1.000) → re-measure isolated reversed-order; reference-match = gcc magic-reciprocal·V8 PACKED_SMI.
- do: merge lever = default-OFF env opt-in (`HEXA_PACK_ARRAY` etc.·byte-neutral); escape-lattice = alias-set transition void (escape-stress 9 kernels OFF==ON #4121); honest-next = default-ON·other-kernels·array wire-to-prod·f64/f32 packed.
- dont: tune-to-green · enshrining a contaminated ratio as a ceiling · escape per-local void (aliasing miscompile) · merging an unmeasured inert lever · flipping default-ON before regular CI byteeq 3-target+nvptx GREEN (not Blacksmith·#4016 revert).

## QA — continuous verification · verify-done always-on

- do: close every fix·feature·measurement in one loop of **measure → root-cause → build-verify → merge**.
  Verify with **captured output** (no LLM self-judgment) — for codegen/runtime changes, byte-eq measurement across byteeq 3-target + all relevant
  configs (e.g. REF · DEVRESIDENT · DEVFEED); prove measurement claims by reference-match
  (roofline % · cuBLAS · nsys kernel attribution) compared against the gold standard.
- do: QA is a **session-wide continuous loop** — when one fix closes, name and continue the next QA round (adjacent op · edge case · regression).
  Stop only at 🏁 (goal achieved) or a measured wall (🧱). Report falsified/negative results too
  and **honestly leave the self-correction trajectory** (e.g. correcting "launch-bound" → nsys attribution → memory-bandwidth-bound).
- do: when measurement noise is large, **attribute to a more stable lower-level signal** (harness wall-clock noise → nsys
  kernel median). Before claiming absolute numbers, confirm the metric's meaning in code (no layer confusion — SM-util ≠ FLOP-efficiency).
- dont: unverified "done" · merging with only one config/one target green · doing only per-op unit tests and calling it "done" (missing all-config QA · production wiring) · enshrining a measurement artifact as a scientific ceiling · tune-to-green.
- do: enshrine QA outputs (verdict · measurement numbers) to memory/CHANGELOG/state, and relay cross-repo measurements
  via `ing add --to <repo>`. Build/measure on the aiden/summer/vast pool (mini = git/gh only ·
  akida forbidden). Detailed obligations are in lockstep with commons `verify-done` · `break-walls` · `reference-match`.
- do: **always measure forge/flame GPU performance with the "current main hexat"** — the stock release
  hexat installed on the pool (e.g. v0.442.0) may not know main's `forge_dispatch_*` builtins and mis-lower those symbols to `hexa_call3/4`
  value-dispatch → compile failure (type error) or **measurement on a slow CPU fallback** (75331ms-class
  bad-hexat artifact → 2026-06-29 lesson of nearly enshrining a phantom 4750×). After the `test` rolling channel retirement (2026-06-30),
  securing a current hexat = measure with **a hexat built directly from a main checkout on a pool host (aiden/summer)** (`tool/release_build`
  or `./hexa install.hexa`). Before measuring: ⓐ build current main on the pool → ⓑ confirm cuda_available + current version via `hexa gpu`
  → ⓒ confirm `[OWN-GEMM-FIRED] DEVICE path` fires when running the bench. SSOT =
  convergence `bench-hexa-clm-step-hexa-1`.
- dont: measuring·enshrining forge-bench absolute time without confirming pool hexat currency (mistaking the bad-hexat fallback for real perf) ·
  working around missing builtins with per-op `hexa cc --regen` (shared-toolchain contamination = all subsequent measurements void) · cutting a stable
  release for the sake of one bench (release-integrity overreach — building main directly on the pool is the canonical unblock) ·
  depending on the retired `HEXA_VERSION=test` path (no channel).
- do: QA also **audits·corrects native-canonical-default polarity violations** — the default path is always
  hexa-native/own/canonical, and external dependencies (cuBLAS · external BLAS · vendor library · legacy fallback) must
  exist **only via opt-in flags** (in lockstep with the [native-canonical-default] guardrail below). When QA
  finds inverted polarity (hiding native behind a flag and making external-dependency the default · opting native in via `HEXA_NO_<vendor>` · codegen-fragile substitutes like hand-rolled Taylor),
  **close it with a correction PR** — align the flag naming so that turning it on
  means "enabling a constraint/external-dependency" (`HEXA_USE_<vendor>` · `HEXA_<feature>_FALLBACK` ○ /
  `HEXA_NO_<vendor>` ✗). Make the correction byteeq-safe (keep felt-default=native), leaving the fast external-dependency path as explicit
  opt-in.

## native-canonical-default — polarity

- do: the default path is **always hexa-native/own/canonical**. External dependencies (cuBLAS · external BLAS · vendor
  libraries) · experiments · legacy fallback exist **only as a "constraint" opted in via a flag (env/compile macro)**. Correct example — forge GPU GEMM: own kernel is default · cuBLAS is
  `HEXA_USE_CUBLAS` opt-in.
- do: **⚠️ the determinism axis is an explicit exception (owner decision 2026-06-28)** — GPU numeric determinism is exempt from the
  "non-determinism = opt-in" rule above. Following the torch/JAX canon (non-det default + `use_deterministic_algorithms`
  opt-in), **fast non-det is default · det is opt-in (`HEXA_DET`)**. But this exception applies **only to the single
  determinism axis** and **own/vendor polarity is invariant** — even in fast-default the **own-native
  non-deterministic kernels** (atomic split-K own-GEMM · own scatter · own batched) are the canonical default, and
  vendor cuBLAS-TC is still opt-in (`HEXA_USE_CUBLAS`, consistent with the cuBLAS-independence campaign). Detail =
  [flame/forge determinism] below.
- dont: **never invert polarity** — do not hide native behind a flag and make external-dependency the default
  (wrong example = opting native in via `HEXA_NO_CUBLAS` · #3742 correction target). Flag naming must make turning it on
  mean "enabling a constraint/external-dependency" (`HEXA_USE_<vendor>` · `HEXA_<feature>_FALLBACK` ○ /
  `HEXA_NO_<vendor>` ✗).
- do: if native-default causes a perf regression (e.g. consumer-GPU BF16 ~2× slower), **keep the polarity**
  but leave the fast external-dependency path as an opt-in flag so it can be selected (felt-default = native ·
  the fast path is explicit opt-in). Being slower is not being broken, and is compatible with [Release integrity]'s "don't break the user path" above.
- do: **the entire developer-experience (DX) surface must be a native-canonical install path — a *toolchain/packaging-layer* canonicality separate from the polarity (kernel default) above.** Scope = package/library management (`hx install`·dependency resolution·
  lockfile·version pin·registry) · install/update (`hx install`·`hexa self-update`) · build variants (CPU/GPU·target)
  · GPU enablement · environment bootstrap. **Each surface follows the established-ecosystem canon as-is** — `pip`/`cargo`/`npm`/
  `go mod` (install·add·lock·resolve) · `pip install torch` (auto host-matched GPU wheel) · `rustup`/
  autotools (toolchain·feature·`nvcc` detection). **Since the hexa creator may not be familiar with other languages' native conventions,
  the agent *proactively enforces·corrects* that canon via native-canonical-first judgment** (the agent fills in conventions the creator doesn't know — don't bury it). For a new DX surface, first ask "how would this behave if it were cargo/pip/npm"
  and design by that convention.
- do: **GPU enablement = the first concrete instance of the principle above.** The canonical install/update command must **automatically produce** a `cuda_available()=1` runtime on a CUDA host (nvcc+GPU detection) — detection→build/fetch cuda assets→wire `~/.hx/bin/build/runtime.a`
  all in one go, with `hexa gpu` reporting cuda_available 1 at the end (just as `pip install torch` auto-fetches the GPU wheel).
- dont: **do not leave the DX surface non-canonical** — if the user must hand-build/swap/work-around to use it, that's a
  packaging defect. GPU measured defects (found during 2026-06-26 anima clm303 GPU measurement):
  ① `tool/build_cuda_runtime` extracts everything via `ar x` but links only `*_native.o` CORES →
  `undefined reference hexa_array_push/hexa_sub/hexa_str_join` (non-native objects missing) ·
  ② even when `stage_resolve_runtime_a` CUDA-R1 runs on the frozen seed, the linked runtime.a has only 3 cuda syms →
  `cuda_available()=0` persists · ③ the stock release doesn't ship `-cuda` assets + `hx install` has no GPU-detection path.
  → GPU not turning on in one command even on a GPU box (nvcc+GPU confirmed) is a defect, not the user's fault.
  By the same yardstick, correct other DX surfaces (library management·dependencies·install) on the spot when a gap vs. the canon appears.
- do: stdlib signal/math **recommends native libm trig** by default · when self-host (zero-c libm native-emit)·accuracy is needed, **hand-rolled math kernels are allowed** (fdlibm/musl minimax·Taylor · byteeq+reference-match gate).
- dont: guessing-coefficient fudge that ignores the gold standard (fdlibm/musl) · no accuracy claim without reference-match.
- do: **the canon for cross-target libc-floor (`hxlcl_*`) native-emit = codegen per-fn C-ABI
  calling-convention** (Route C). The `_is_cabi(fname)` (`hxlcl_` prefix/whitelist) hook lowers the PAIR-MODEL
  HexaVal `{tag,payload}` to **single-register C-ABI** (SysV `rdi`/`rsi`/… · return `rax` /
  AAPCS64 `x0`/… · return `x0`) across codegen's 3 boundaries (param-ingress · return · call-boundary) × 2 backends (x86_64·arm64) (reusing the existing C-ABI helper `_x86_64_arg_reg_seq`).
  reference-match: GCC `sysv_abi`/`regparm` · rustc `extern "C"` · zig `callconv(.C)` · Go
  `ABI0` — the canon of every major compiler. **One codegen feature cross-target-dissolves all `hxlcl_*` symbols × 3 targets at once**
  (default-OFF whitelist · byteeq-neutral · DEFAULT shim.o sha unchanged).
  SSOT: memory `project_hexa_rfc061_hxlcl_crosstarget_abi_wall`.
- status (RFC061 #29 Route C campaign · **in progress · literal `ls self/*.c == ∅` flip-free reached #4282**):
  syscall/2nd-return-reg/named-data/environ/FILE*/file-local-static family + ELF cross-target
  member-swap mem/str pure-leaf 10/10 (strlen·memcpy·memset·memcmp·strcmp·strncmp·strcpy·strncpy·
  strcat·strchr) + pipe/fork/getenv/setenv/popen + signal (sa_restorer WIRED via @naked trampoline
  + __hx_fn_addr · ∅−7) + setjmp/longjmp (frozen-RESTORE re-baseline · ∅−8 #4272) +
  hxlcl_shim→emitter SSOT (literal ∅ #4282) etc. dissolved (all default-OFF·byteeq-neutral·admin-merge).
  **current frontier (not a terminus · all reducible)**: varargs-ABI (`hxlcl_fprintf`·va_list) · svc-remainder
  (getrusage/time) · emitted C content (runtime.c etc. .hexa emitter products) · recursive `self/**/*.c`
  (`self/native/timegm_native.c` · `self/cuda/*.c` GPU-FFI) · functional libc floor. **The "frozen-uneditable
  🧱"·"measurement-terminus"·"irreducible" framing is retired** — frozen re-baseline is the canonical
  tracked-emitter edit shown by #4272 (awk synthesis·byteeq 3-target reconverge = GCC make compare), not an owner-go permanent wall,
  and every wall is gold-standard research-then-break (demonstrated by setjmp #4272·libm·shim #4282).
- dont: do not extend cross-target via per-symbol·per-target **hand-assembled machine-byte arrays**
  (non-canonical · O(symbols×targets) labor · maintenance explosion — the `test/native_build/emit_hxlcl_*_o.hexa`
  darwin Mach-O hand-assemble was a temporary workaround in the absence of codegen C-ABI mode, superseded by Route C).
  New `@<attr>`/keyword/builtin are **allowed** (everything but no-LLVM is allowed) — if the frozen blob 151c52c8 parser doesn't know it,
  introduce it byteeq-safe with an accompanying frozen re-baseline OR a name-prefix/whitelist hook (avoiding a faithful build-break).

## flame/forge determinism — API primary + env escape-hatch / fast-nondet DEFAULT

- do: flame/forge GPU numerics have **2 paths**, fast non-det DEFAULT (owner 2026-06-28 · torch/JAX canon). (A) DEFAULT = own-native atomic kernels (split-K GEMM/GEMV · atomic-scatter · atomic embed-bwd; + vendor cuBLAS-TC via `HEXA_USE_CUBLAS`). (B) det OPT-IN = fixed-order non-atomic (byte-exact cross-host).
- do: #4214 **det surface = API primary + env escape-hatch** (torch `use_deterministic_algorithms()` ref-match). API = `set_deterministic(true/false)` / `is_deterministic()` (`stdlib/flame/forge_det.hexa`). env = `HEXA_DET=1` (shell/CI escape-hatch). precedence: API > env.
- do: `set_deterministic` implementation = `hexa_forge_set_deterministic(int)` C (`runtime_cuda.c` `_hx_forge_det_mode` process-global; `runtime.h` non-CUDA inline stub). `_forge_det_on()` = API mode first, fallback env.
- do: eval/verdict/decode safety-pin = entry points call `set_deterministic(true)` directly (API primary). Resolves the old HEXA_DET setenv-impossible caveat. CI byteeq/oracle jobs can keep `HEXA_DET=1` env (escape-hatch).
- do: consumer (anima) = training fast non-det default · eval/verdict/decode det (`set_deterministic(true)`). ckpt quality = held-out DESCENT (bit-det not required). own/vendor polarity invariant — own-native canonical, cuBLAS opt-in. The GPU det axis is separate from the selfhost-determinism-gate.
- dont: bypassing the safety-pin (scoring·enshrining without eval/verdict/decode det) · promoting vendor cuBLAS to fast-default · missing CI det enforcement · reverting to det default · promoting HEXA_DET env above the API in precedence.

## Atlas · verification

- do: the human ledger of the discovery engine (number theory · physics · cosmology · life) is **the single SSOT `ATLAS/README.md`** (starting from n=6 axis0
  · macro↔quantum math map · renamed from the old `TECS-L/` 2026-06-18). Draw the map **incrementally** in README.md (not one-shot · keep filling in verified nodes/bridges).
- do: the atlas has 2 layers — **human layer** `atlas/README.md` + `atlas/hypotheses/*.md`, **machine-layer SSOT**
  `compiler/atlas/embedded.gen.hexa` (verdict atom). Loading **always goes to both**. On `🔵`/`🟢`
  `hexa verify` success the atom is **auto-folded** into embedded.gen.hexa (verify = a single canonical surface ·
  no separate `atlas register` ceremony). Atlas node folds go only into `compiler/atlas/embedded.gen.hexa`,
  via the branch → commit → PR path (nowhere else).
- dont: do not update only the human layer and omit the machine layer (embedded.gen.hexa). Do not promote to 🔵 an unread · unverified · lattice-fit ·
  unproven conjecture. **n=6 is not the center of the map but a single node** (lattice-as-tool · don't anchor external
  domains).
- do: run math DFS **via `hexa loop --dfs`** (single external-LLM surface · budget cap + verify
  gate), recording results in the `ATLAS/README.md` chronicle + `ATLAS/CLAUDE.md`. DFS/fleet verification nodes made in a build-incapable environment (mini)
  **PR-fold** a `@F` kind atom (`verified:false` · cite explicitly if classical · 🔵 promotion only via passing `hexa verify`) into embedded.gen.hexa via `state/novel-dfs/*_fold.py`.
- dont: do not call the external LLM outside `hexa loop --dfs` (budget cap + verify gate). No ad-hoc
  scripts.
- dont: do not use retired remnants — the old `atlas/` (lowercase) folder · the `TECS-L/` name · the TECS-L
  multi-doc (`TECS-L.md` · `n6.md` · `millennium/` · `.verdicts/`) · the `.tape` ledger (CLAIMS etc.) · a separate
  `atlas/CLAUDE.md` (atlas governance is the sole SSOT in this root CLAUDE.md).
- do: land domain audits via the `hexa verify --<axis> <domain>` subcommand (one CLI surface · no new
  top-level verb).

## git · L0 · lockstep

- do: before changing a guard file, a subagent diffs (`git diff <baseline>...HEAD` · `.githooks/pre-commit`).
- dont: do not commit a >50-line deletion from `stdlib`/`runtime`/`codegen`/`rt` without a scoped subject or a `WIPE-OK:` trailer.
- do: when editing an L0 lockdown file (`harness.config.json` → `lockdown.files`), update
  `CHANGELOG.jsonl` in the same change.
- do: when updating `hexa` (release/CLI), **lockstep-update** the `hexa --help` · `hexa gpu` output — when new
  GPU capabilities · flags · build variants · dtype parity changes occur, update the `cmd_help()`/
  `cmd_gpu_status()` text in the same change (other repos trust `hexa gpu` as the GPU/flame/forge/cuda status SSOT, so no stale).
- do: keep all HuggingFace uploads/Collections under the `dancinlab` org.

## CI · self-hosted runners

- do: **cloud CI = Blacksmith** — ephemeral·multi-target jobs (e.g. `release.yml`) run on **Blacksmith hosted
  runners**: `blacksmith-6vcpu-macos-15` (darwin) · `blacksmith-4vcpu-ubuntu-2204` (linux-x64) ·
  `blacksmith-4vcpu-ubuntu-2404-arm` (linux-arm64). I.e. **even if the self-hosted pool (ghost/aiden/summer) is down,
  the PR gates (selfhost-byteeq·determinism·codegen-guard·miscompile-zero·nobaseline etc.) run on Blacksmith** → if the local SSH pool is blocked, get release-integrity verification (byteeq 3-target + shipping smoke)
  by **opening a PR for Blacksmith CI** (the canonical path when the local pool SSH is unstable). The self-hosted runners are an auxiliary pool that opt-in to only some heavy faithful/byteeq jobs,
  as below.
- do: heavy faithful/byteeq builds are handled by the **self-hosted runners** — `ghost` (darwin-arm64 ·
  label `selfhost-gen2fix` · darwin byteeq) + `aiden`/`summer` (linux-x64 · label `hexa-build` ·
  12c/30G shared build pool). How a job opts in: `runs-on: [self-hosted, Linux, X64, hexa-build]`
  (linux-x86_64 only · e.g. `nobaseline-gate.yml` faithful-nobaseline linux-x86_64). **Leave jobs that need linux-arm64 ·
  darwin-arm64 · ephemeral environments on the cloud runners** — there's no arm64 self-hosted host
  (honest, don't claim arm64 coverage).
- do: since it's a public repo, **fork-PRs are picked up by self-hosted runners only after maintainer approval** (RCE mitigation ·
  same as the ghost precedent). Move a required job only after measuring green on the runner.
- dont: **do not make the required gate (`selfhost-gates-summary`) depend on an unverified/offline runner** —
  move a required job only after measuring green on the runner.
- do: register the runner as a systemd **service** (`~/actions-runner-hexa` · `sudo ./svc.sh install` · survives reboot
  · single runner per host — don't starve the build pool · our builds are still 1-SSH discipline). If offline,
  re-register: `gh api -X POST repos/dancinlab/hexa-lang/actions/runners/registration-token -q .token`
  →  on the host `cd ~/actions-runner-hexa && ./config.sh --url … --token <tok> --labels
  self-hosted,Linux,X64,<host>,hexa-build --unattended --replace && sudo ./svc.sh start`. Status via
  `gh api repos/dancinlab/hexa-lang/actions/runners`.

## Governance baseline — everything but no-LLVM allowed (user standing 2026-06-29)

- do: **the sole inviolable = no-LLVM** (source→compiler IR→native→`hexa_ld`). Every other implementation technique is allowed — hand-rolled math kernels·new keywords/`@<attr>`/builtin·frozen re-baseline·va_list/setjmp ABI all possible (past "technique forbidden" = a measurement-cost recommendation, not a permanent ban).
- dont: never break no-LLVM (going through an LLVM backend/IR) · and no unverified merge that skips the 4 disciplines (release-integrity·byteeq 3-target verification·reference-match·git-safety) (even allowed techniques must pass the gate).
