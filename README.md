<p align="center">
  <img src="docs/logo.svg" width="140" alt="hexa-lang">
</p>

<h1 align="center">💎 hexa-lang</h1>

<p align="center"><strong>Native compiler with atlas-bound theorems</strong> — strict-lint · citation-enforced · no LLVM · no C-transpile</p>

<p align="center">
  <a href="LICENSE"><img alt="License" src="https://img.shields.io/badge/license-MIT-blue"></a>
  <a href=".github/workflows/lint.yml"><img alt="CI" src="https://github.com/dancinlab/hexa-lang/actions/workflows/lint.yml/badge.svg"></a>
  <a href="https://doi.org/10.5281/zenodo.19404816"><img alt="DOI" src="https://zenodo.org/badge/DOI/10.5281/zenodo.19404816.svg"></a>
  <img alt="Phase" src="https://img.shields.io/badge/phase-A0%E2%80%93B5%20PASS-success">
  <img alt="M0" src="https://img.shields.io/badge/M0-PASS-success">
  <img alt="Atlas" src="https://img.shields.io/badge/atlas-hash%20pinned-informational">
  <img alt="Sibling" src="https://img.shields.io/badge/sibling-n6%20·%20hxc%20·%20n12%20·%20tape-blueviolet">
</p>

<p align="center">Atlas-bound · strict-lint · 8-stage gate · ε self-proof · n=6 perfect-number primitives · self-hosted</p>

---

`hexa-lang` is a native compiler that carries its own theorem 사전 (dictionary) inside the binary. No LLVM. No C-transpile. Every formula in your code either cites the atlas or the build refuses to start. The stricter the gate, the cleaner the code that passes.

> [!NOTE]
> Sister of [`n6`](https://github.com/dancinlab/n6) (semantic atom layer — atlas serialisation format), [`hxc`](https://github.com/dancinlab/hxc) (byte-canonical wire), and [`tape`](https://github.com/dancinlab/tape) (operational trace). hexa-lang's atlas is unconditionally binary built-in — compile-time embedded into the compiler — and `.n6` is the sister serialisation format emitted on demand by `hexa atlas export` for interop / inspection. Discovered laws are absorbed via GitHub PR directly into the embedded atlas, not through a runtime `.n6` overlay. The `wilson` agent ([`dancinlab/wilson`](https://github.com/dancinlab/wilson)) is built end-to-end on hexa-lang.

## At a glance

```hexa
@cite(L[sigma_phi_n_tau_iff_n_eq_6])
fn perfect_at_six() -> bool {
    let n = 6
    return sigma(n) == 2 * n          // σ(6) = 12 = 2·6
        && phi(n) * tau(n) == 8       // φ(6)·τ(6) = 2·4 = 8 = σ(n)−n−φ(n)+1
}

// Untouched citation = HX8004 fatal at compile time:
//
//   error[HX8004]: formula-bearing function does not cite atlas L[*]
//     --> src/foo.hexa:14:1
//      |
//   14 | fn area_of_circle(r: f64) -> f64 {
//      | ^^^^^^^^^^^^^^^^^ formula here
//      = note: cite an atlas law via `@cite(L[id])` or declare `@grace(HX8004, until=, reason=)`
//      = help:  hexa atlas search "πr²"   →  L[circle_area]
```

The compiler stays parked unless every formula either cites the atlas, has an active `@verify`, or carries an explicit `@grace`. There is no "we'll fix it after." There is no binary.

## Why hexa-lang

LLMs answer by recombining what their weights already contain — noise from **inside** a frozen well. hexa-lang generates from **outside** the well: every compile cycle produces a primitive the previous cycle could not express, then absorbs it as a new wall (`@verify` → atlas promote → tombstone retroactive sweep). The atlas grows; hallucination is mechanically excluded because every claim must trace to a citation.

The second pillar is **enforcement at the build gate**, not at runtime. Eight strict-lint stages (S0 parse → S1 resolve → S2 bind → S3 type → S4 domain → S5 units → S6 equational `@verify` → S7 proof `@prove` → S8 citation `HX8004`) reject formula-bearing code that doesn't cite. No annotations means no formula. No formula in a non-cited function means a hard error.

Third: **n=6 perfect-number primitives**. The compiler is a 셰프 (chef) with a 4.2 MB atlas baked statically into the binary — 60,760 lines of P (primitives) / C (constants) / L (laws) / E (errors). Citing `L[sigma_phi_n_tau_iff_n_eq_6]` is one keystroke; if the law is wrong, every dependent gets a tombstone cascade with an auto-PR.

## Pipeline

```
   .hexa source
        │
        ▼
   lex ─► parse ─► resolve ─► bind ─► types ─► domain ─► units ─► citation
                    (S1)      (S2)    (S3)     (S4)     (S5)      (S8)
        │                                                            │
        │                  any fatal stage → no binary               │
        ▼                                                            ▼
   lower (HIR) ─► mono ─► MIR (SSA) ─► optimize ─► regalloc (LIR) ─► emit (asm)
        │                                                            │
        ▼                                                            ▼
                                  hexa_ld v1.1
                          ELF64 + Mach-O arm64 static
                                       │
                                       ▼
                                 native binary
```

A binary appears only when every fatal stage passes. The atlas (4.2 MB) is baked in at compile time — runtime cost: 0 ms.

* * *

## 🔥 flame + 🔧 forge — hexa-native NN training stack + GPU substrate

`stdlib/flame` is what you build *with* hexa-lang: a compiler-only neural-network training stdlib (autograd tape · layers · optimizers · tensor primitives) lowered through the same 8-stage strict-lint gate that compiles the compiler itself. No PyTorch wrapping, no ATen import, no Python in the trained binary.

`self/forge` is what flame calls into: a GPU substrate that pairs device-resident hexa arrays (`farr`) with vendor-grade kernels (cuBLAS Dgemm + 11 hand-emit `.cu` kernels covering the elementwise / reduction / norm surface) under a byte-equal correctness contract, plus a BF16 Tensor-Core "mega-kernel" path (RFC 049/060) for the in-kernel-GEMM regime where vendor libs are reachable.

**Architecture analogy** (`flame:forge :: torch:ATen`):

```
              hexa source (.hexa)
                     │
   ┌─────────────────┼─────────────────┐
   │ flame stdlib (compiler-only NN)   │   ← what users write
   │   t_* tensor · ag_tape autograd   │     (no Python in trained binary)
   │   nn_lib layers · opt_* optimizer │
   └─────────────────┬─────────────────┘
                     │   hexa build (8-stage strict-lint gate)
                     ▼
   ┌─────────────────────────────────┐
   │ forge GPU substrate             │   ← what flame calls into
   │   farr device-resident array    │     RFC 040
   │   cuBLAS Dgemm  +  11 .cu       │     RFC 041
   │   BF16-TC mega-kernel path      │     RFC 049 / 060
   └─────────────────────────────────┘
                     │
                     ▼
              A100 / H100 native
```

### Correctness — byte-equal oracles (max\|Δ\| = 0, FMA-contraction-off recipe)

| layer | scope | measurement |
|---|---|---|
| forge substrate | RFC 040 device-farr + cuBLAS Dgemm · RFC 041 11-op `.cu` | **12 byte-equal fires** across the elementwise / reduce / GEMM surface, max\|Δ\| = 0 |
| flame layers | rmsnorm · attn-fwd · attn-bwd · silu-gate | **4 byte-equal oracle fires**, max\|Δ\| = 0 |
| flame `ag_tape` | generic autograd through the same oracles | derivation byte-equal, abstraction pays no correctness tax |

### Performance — measured (g3 / `LATTICE_POLICY`: real fires, falsifier-gated, no fabrication)

| path | measurement | note |
|---|---|---|
| **forge BF16-TC mega-kernel** (RFC 049 Stage 1, A100) | **9.67× faster than FP64 cuBLAS** @ Llama-7B FFN shape | $0.10 fire · paradigm verdict from Phase R 14-fire $2.91 campaign |
| forge Phase R / RFC 060 closure | FP64 mega-kernel **KILLED** (1.8-4.4× slower than per-op) · BF16 substrate **PASS** | RFC 060 100% closure · BF16-TC is the cuBLAS-relative wall path |
| flame `ag_tape` d=768 · 12-layer (A100) | per-step wall recorded · **PyTorch wall speedup NOT measured** | prior README "2.95× / 1.26-1.76× faster than PyTorch eager" was a unit mismatch (full-run / 1-step) — **RETRACTED** per `stdlib/flame/README.md` correction 2026-05-19 |

> Honest scope: flame's `ag_tape` + nn_lib + opt_* are functionally complete and byte-equal-verified; forge's `farr + cuBLAS Dgemm + 11 .cu` substrate is complete with the BF16-TC mega-kernel landing as the cuBLAS-relative wall path. End-to-end flame ↔ PyTorch wall comparison is **pending an apples-to-apples re-fire** — the substantive cuBLAS-relative win currently sits at the forge layer (BF16-TC 9.67× over FP64-cuBLAS on the FFN-shape mega-kernel).

### Where it beats cuBLAS-using stacks structurally (whole-program fusion · cuBLAS cannot express)

`cuBLAS` ships a champion *part* (the GEMM kernel itself, already at roofline), but cannot fuse adjacent ops — each op pays a separate kernel launch + a full HBM round-trip. hexa codegen sees the whole expression and emits one kernel that keeps intermediates in registers / shared memory:

```
cuBLAS-using stack (current default — 3 ops = 3 launches, 3 HBM round-trips):
  ┌──GEMM──┐         ┌──bias──┐         ┌──GeLU──┐
  │ launch │ → HBM → │ launch │ → HBM → │ launch │ → HBM
  └────────┘         └────────┘         └────────┘

hexa fusion (whole-program — one kernel, registers/shmem reused):
  ┌──── GEMM + bias + GeLU ────┐
  │  1 launch · 1 HBM write    │ → HBM            (F-FUSION-EPILOGUE-GEMM-BIAS-GELU)
  └────────────────────────────┘                  66.667 % launch + HBM-write reduction
```

The same mechanic generalises: GEMM-epilogue, norm surface, attention block, autoregressive decode chain — every place where cuBLAS forces "stop the GEMM, write to HBM, hand off to the next op" hexa can keep the value in registers.

| finding | reduction / win | tier |
|---|---|---|
| `F-FUSION-EPILOGUE-GEMM-BIAS-GELU` | **66.667 % launch + HBM-write reduction** (3 launches → 1) @ LLaMA-7B FFN shape, ptxas-clean sm_80 | 🔵 structural-formal |
| `F-FUSION-LAUNCH-AMORT` | 5-op chain → 1 launch / 3 HBM transfers vs separate-op 5 launches / 11 transfers | 🔵 + `$0` deterministic oracle |
| `F-FUSION-AXISA-BREADTH` (norm surface) | LayerNorm 66 % · RMSNorm 59 % · Softmax 65 % · SwiGLU 63 % | 🔵 structural-formal |
| `F-FUSION-ATTENTION-FLASH` | single-kernel fused attention (Q·K · softmax · V) | 🔵 + wall ruled-out |
| §5j `Custom reductions` — LogSumExp 1-kernel (#1657) | numerically-stable max-shift + exp + log + sum in one kernel, silicon-validated rel_err 1.7e-10 | 🟢 SUPPORTED-NUMERICAL |

### 🎯 Who benefits — 7 user personas (the pain → the gain)

cuBLAS-using stacks ship a champion *part* (the GEMM kernel, already at roofline). hexa wins where **the part isn't the bottleneck — the chain around it is**. Whether that helps *you* depends on which pain you actually carry:

| persona | pain you carry | what hexa gives |
|---|---|---|
| 🧪 **LLM trainer / inference engineer** | attention · norm · decode are memory- / launch-bound — stuck on top of PyTorch | fusion strikes that region directly — 3-op chain → 1 launch + 1 HBM write (66 % ↓) · FlashAttn-style single kernel |
| 🔬 **GPU kernel researcher** | cuBLAS is a black box — wants SASS-level visibility but can't get it | source → PTX → SASS visible end-to-end · cubin lives in the repo |
| 📦 **Single-binary deployer** (edge / embedded / offline) | can't ship Python + libtorch (multi-GB) to the target | native arm64 / x86_64 single binary · no Python in the trained artifact |
| 🔢 **Non-IEEE arithmetic** (posit · interval · n=6 lattice) | cuBLAS is IEEE-float only | custom-dtype codegen — new arithmetic rides the same fusion path |
| 🧠 **Autograd debugger** | PyTorch C++ Autograd is a black box, can't step through it | `ag_tape` is all hexa source — read it line by line |
| 🎯 **Byte-equal correctness** (science · reproducibility) | PyTorch run-to-run drift is common | byte-equal oracles + FMA-contraction-off recipe, max\|Δ\| = 0 |
| ⚡ **Fast codegen iteration** | hand-CUDA hell — rewrite the fusion every time | the compiler fuses for you — one `@gpu_kernel` annotation |

```
Where does hexa's fusion gap land hardest?
                cuBLAS-using stack ─────────┐
                    │  (huge standalone GEMM is fine — can't beat)
                    ▼
  ┌────────────────────────────────────────┐
  │  Intersection where hexa fusion wins   │
  │   ① many memory-bound patterns         │  ← LLM training / inference
  │   ② Python-free deploy                 │  ← edge · embedded · offline
  │   ③ correctness OR visibility needed   │  ← research · science · repro
  │   ④ long chains (decode/optim/AdamW)   │  ← training loop
  └────────────────────────────────────────┘
```

### 🍳 Where fusion fires — memory-hierarchy asymmetry

GPU register ~1 cycle vs HBM ~600 cycles. cuBLAS writes the result to HBM after every op so the next op can read it back; fusion keeps the value in registers.

| scenario | why fusion wins | measured |
|---|---|---|
| **GEMM + elementwise epilogue** (bias · ReLU · GeLU · dropout) | GEMM output is a large tensor — next op reuses it immediately | F-FUSION-EPILOGUE 66.7 % ↓ |
| **norm surface** (LN / RMSNorm / Softmax / SwiGLU) | reduce + immediate-neighbor reuse · norm is memory-bound | AxisA LN 66 % · RMS 59 % · SM 65 % · SwiGLU 63 % |
| **Attention block** (Q·Kᵀ · softmax · V) | giant intermediate attention matrix → avoiding HBM round-trip is the win | F-FUSION-ATTENTION-FLASH 🔵 |
| **Small-op chain** (LLM autoregressive decode · AdamW step) | launch overhead dominates over compute | F-FUSION-LAUNCH-AMORT 5-op → 1 launch |

```
fusion gain  =  (chain length)  ×  (memory-bound-ness)  ×  (intermediate-tensor size)
```

Honest scope on where it *doesn't*: a single huge GEMM (already compute-bound, ties cuBLAS at roofline) · a lone op (nothing to fuse) · very small GEMMs (launch-bound is the real problem, not fusion).

**One line**: cuBLAS = a one-dish specialist (master of the stew). hexa fusion = a one-pan dinner (multiple steps in sequence on the same heat). Users whose workload's time distribution overlaps the four scenarios above land on hexa's real gap.

Detail: `stdlib/flame/README.md` (canonical perf table + RETRACTION note) · `stdlib/flame/PERF.md` · `stdlib/flame/PLAN.md` (campaign log + cycle ledger) · `self/forge/PLAN.md` · `self/forge/PARADIGM.md` (Phase R measured verdicts) · `GPU.md` §1h-1o fusion-moat fires · `GPU.easy.md` (friendly persona sidecar) · `state/anima_handoff_2026_05_19.md` (integration recipe).

* * *

## Status

The closure round's fixed points, with witnesses on disk:

- `41ecfb97` — RFC-020 A4 enum-payload codegen restored in SSOT `codegen_c2.hexa` (regen-safe; test_enum_payload_full 15/15 codegen + interp)
- `46016739` — builtin/method taken-by-value → `__hxthunk_<name>` codegen (fixes `hexa_callN(<builtin>)` undeclared) + un-doubled `hexa_cc.c`
- `6c0fbac7` — `exec_stream_kill(h)` runtime builtin (fork+setpgid stream child, SIGTERM→grace→SIGKILL)
- `4725c619` — `stdlib/semver.hexa` — SemVer 2.0.0 parse/compare/range-satisfies (test_semver 110/110)
- `df9e7f6b` — install-relative `stdlib/` discovery + `HEXA_INSTALL_DIR` passdown (`use "stdlib/*"` works without `HEXA_LANG`/`HEXA_STDLIB_ROOT`)
- `0ba5fd7d` — shell-builtin absorption: `pwd → cwd()/getcwd()`, `ls → list_dir()` intrinsics (absorbed 638→752, pending 197→83)
- `731f41d6` — `hexa cc` resolves `hexa_cc.c`/SSOT/`-I` via `$HEXA_LANG > install_dir > ./self` (works out-of-tree)
- `a5de44e2` — `self/stdlib/law_io.hexa` selftest `main()` → `tool/law_io_selftest.hexa` (u_main collision on flatten)
- `dae438ee` — `~/.hx/bin/hexa_real` re-promoted from HEAD `46016739` (sha cd817981…)
- `774c5d32` / `4f5f8f07` — stage-1 punch-list v2: A1+A2 host re-promote → #13 RSS re-probe **peak ~782 MB** (vs 3 510 MB) — P0 stage-1 OOM closed at current scale
- `571df583` / `a8ff675b` — SPEC §19/§20 reconcile + Gap-15 close-out
- `340c3788` / `5ddcf2a9` — wilson↔hexa-lang closure (VERIFIED — `hexa build core/main.hexa` → `wilson 0.0.1`) + SPEC closure-round fold-in

Snapshot derived from `git log` on main; full tables at `SPEC.yaml::phases_completed_2026_05_09` and `SPEC.yaml::phases_completed_2026_05_11_closure`.

* * *

## Decisions (the spine)

Six choices that shape everything else, pinned in [`SPEC.yaml`](SPEC.yaml):

1. **Native compiled, direct codegen** — no LLVM, no C-transpile. The tree-walking interpreter is retired: the self-host stage reached a byte-equal fixed point, and `hexa run` compiles then executes.
2. **Atlas static-baked into the compiler binary** — `ATLAS_HASH` pinned, drift handled by CI auto-rebuild. Runtime atlas-load cost: 0 ms.
3. **Strict compile-time fatal lint** — Python `SyntaxError` + TypeScript `strict` model. S0–S5 + S8 always fatal. No `--unsafe`. No `HEXA_STRICT=0`.
4. **`@grace` is the only opt-out** — `@grace(HXxxxx, until="...", reason="...")` per site, every site emits HX9000 at every compile, CI requires `Acked-grace:` trailer.
5. **ε self-proof** — verified functions auto-register as atlas `L[*]` theorems; tombstones cascade on prover upgrade; `HX1099` fires on citing a tombstoned law.
6. **ENGLISH ONLY diagnostics** — catalog, `hexa explain`, stdlib docs. RFCs and meta docs may stay bilingual.

Full record: 14+ pinned decisions, all traceable to RFC-017 through RFC-020.

* * *

## Install

```bash
# Single-line bootstrap — installs `hexa` + `hx` (the package manager) + atlas
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/dancinlab/hexa-lang/main/install.sh)"

# Verify
hexa --version
hx --version
```

The installer drops `hexa`, `hx`, `hexa_ld`, and the atlas seed into `~/.hx/`; binary path is added to your shell's PATH via the relevant rc file. Self-update: `hexa self-update` (compares against the published manifest, atomic swap of `~/.hx/bin/hexa_real`).

## Run

```bash
hexa parse <file>.hexa                 # cheapest signal — syntax + reserved-word + @plugin attr check
hexa build <entry>.hexa -o build/X     # full pipeline → static binary
hexa cc <file>.hexa -o build/X.o       # just lower → object (HIR → MIR → LIR → emit)
hexa run <file>.hexa [<args>...]       # compile then execute a single file
hexa explain HX8004                    # what does this diagnostic mean
hexa atlas lookup <id> | --prefix=<p>   # read atlas node(s) — embedded.gen.hexa SSOT
hexa atlas register --from-verify <fn> <args> <v>   # verify IN-PROCESS → fold node into embedded.gen.hexa
hexa atlas export [--out PATH]          # export live atlas → portable .n6 (n6 = export-only)
hexa drill --seed "<expr>"             # OUROBOROS smash → ... → absorb cycle

hx install <package>                   # install a hexa package by name (looks up dancinlab GitHub by default)
hx update                              # pull updates for all installed packages
hx list                                # what's installed under ~/.hx/bin/
```

`hexa run` compiles a file then executes it in one shot — convenient for single-file scripting. Release-grade builds go through `hexa build`, which produces a reusable static binary.

### Compile speed

`hexa cc` now emits `#include "runtime.h"` by default and the precompiled `runtime.o` is linked instead of re-codegened per build. On bench/*: 28-program avg **8.41× user-time** vs the old `#include "runtime.c"` path (peak 17.25× on small-to-medium user code where `runtime.c` was the dominant per-build cost). Repro: `bin/hexa-fast bench <file>.hexa`. Full history at [`COMPILE-SPEED.tape`](COMPILE-SPEED.tape) (architecture) and [`COMPILE-SPEED.log.tape`](COMPILE-SPEED.log.tape) (measurement events).

```bash
bin/hexa-fast <src.hexa> <bin>          # explicit compile (uses runtime.h + runtime.o cache)
bin/hexa-run  <src.hexa> [args...]      # compile-or-reuse-cached + exec (drop-in for `hexa run`)
bin/hexa-fast bench <src.hexa>          # show baseline vs new-path A/B for any file
bin/hexa-fast clean                     # wipe ~/.hexa-cache
```

* * *

## Architecture (the cooking metaphor)

From [`doc/atlas_lint_easy_explainer.md`](doc/atlas_lint_easy_explainer.md):

The **atlas** is a 사전 — a single shared dictionary of primitives (P), connections (C), laws (L), and errors (E). 60,760 lines, 4.2 MB, unconditionally binary built-in (compile-time embedded); new laws land via GitHub PR.

The **compiler** is a 셰프 (chef) — it has the entire 사전 memorized. It does not phone the library mid-recipe. When you hand it a `.hexa` file, the chef checks every ingredient, unit, and citation against the atlas it already knows by heart.

The **strict lint** is the 품질 검사관 (QC inspector) — it stands at the kitchen door. One missing citation, one ℝ-vs-ℕ mismatch, one orphan unit, and the dish is rejected before the stove turns on. There is no "we'll fix it after." There is no binary.

* * *

## Strict-lint stages

Eight checks, six always fatal, two opt-in via annotation:

- **S0 parse** — syntax / lex. No surprises.
- **S1 resolve** — every `P[*]`, `C[*]`, `L[*]`, `E[*]` exists in the atlas.
- **S2 bind** — every name resolves to a real binding.
- **S3 type** — nominal types and generics.
- **S4 domain** — ℝ / ℕ / ℤ / ℂ consistency.
- **S5 units** — dimensional analysis. No "distance + time."
- **S6 equational** — opt-in via `@verify`; canonical-form check + sample counter-example. In-house prover v0, no Z3.
- **S7 proof** — opt-in via `@prove`; reserved for the in-house prover only.
- **S8 citation** — formula-bearing functions must cite atlas `L[*]` (HX8004). 공식 없으면 거절.

* * *

## Atlas SSOT cycle (ε self-proof)

```
   @verify fn f(...) { ... }                     ← author writes a theorem
            │
            ▼
      compile-time prover  (S6, equational + sample-eval, in-house only)
            │
            ▼
      hexa atlas export                ← .n6 export artifact (interop / inspection)
            │
            ▼
      GitHub PR into embedded.gen.hexa ← the atlas SSOT (binary built-in)
            │           ├─► fingerprint dedup → register as alias
            │           └─► id collision     → first-wins + warning
            ▼
      compiler build re-embeds atlas   ← live atlas grows (no runtime overlay)
            │
            ▼
      prover upgrade                   ← retroactive sweep (compiler/discover/cascade.hexa)
            │
            ▼
      tombstone failing L nodes + cascade dependents
            │
            ▼
      auto-PR (tool/auto_pr_tombstone_sweep.hexa) → human review
```

Citing a tombstoned `L[id]` fires `HX1099` and fails the build. Bypass is `@grace`, which is never silent.

* * *

## Highlights

- native compiled — direct codegen, no LLVM, no C-transpile
- 4.2 MB atlas baked statically into the compiler binary; runtime cost 0 ms
- 8-stage strict lint S0–S5 + S8 enforced at compile time, fatal by default
- ε self-proof: `@verify` / `@discover` → atlas auto-promote → tombstone retroactive sweep
- M0 milestone: `fn main() -> i32 { return 0 }` produces a working Mach-O arm64 binary
- `hexa_ld` v1.1: in-house static linker for ELF64 + Mach-O arm64
- `hexa build` / `hexa cc` work **out-of-tree** — flattens `use`/`import`, resolves `hexa_cc.c`/SSOT/`-I` via `$HEXA_LANG > install_dir > ./self`; install-relative `stdlib/` discovery means `use "stdlib/*"` works with no env vars (downstream: `wilson` builds end-to-end → `wilson 0.0.1`)
- stage-1 P0 host-OOM closed at current scale: A1 phase-arena reset + A2 in-place splice accumulator → peak ~782 MB (was 3 510 MB)
- 14+ pinned decisions in `SPEC.yaml`, every claim traceable to an RFC
- **`stdlib/flame` + `self/forge` — hexa-native NN training stack + GPU substrate**: compiler-only NN (ag_tape · nn_lib · opt_*) on top of device-resident `farr` + cuBLAS Dgemm + 11 `.cu` kernels + BF16-TC mega-kernel path. **forge BF16-TC = 9.67× faster than FP64 cuBLAS** @ Llama-7B FFN shape (A100, measured). 12 byte-equal substrate fires + 4 byte-equal layer fires. flame ↔ PyTorch wall speedup not yet measured (prior claim RETRACTED). Detail in the flame + forge section above.

* * *

## Roadmap

- **stage 1: P0 host-OOM closed at current scale** (A1+A2 → peak ~782 MB, was 3 510 MB); the remaining open work toward a full stage-1 binary is the compiler-driver gaps (Gaps 1–16) + a fixed-point (stage2 == stage3) re-estimate — see [`doc/stage1_punch_list_v2.md`](doc/stage1_punch_list_v2.md).
- biggest unknowns: MIR/LIR coverage on real `compiler/` source (closures, growable arrays, nested struct construction, `match` on user enums) and what a *successful* self-compile diagnostic trace actually looks like.
- full punch list: [`doc/stage1_punch_list_v2.md`](doc/stage1_punch_list_v2.md).

Phase status (PASS / IN-PROGRESS / DEFERRED) lives in [`SPEC.yaml::phases_completed_2026_05_09`](SPEC.yaml) and [`SPEC.yaml::phases_completed_2026_05_11_closure`](SPEC.yaml).

* * *

## RFCs + docs

- [RFC-017 — atlas n6 embedding + strict lint](proposals/rfc_017_atlas_n6_embedding_and_strict_lint.md)
- [RFC-018 — native codegen spec](proposals/rfc_018_native_codegen_spec.md)
- [RFC-019 — error diagnostics spec](proposals/rfc_019_error_diagnostics_spec.md)
- [RFC-020 — enum payload variants](proposals/rfc_020_enum_payload_variants.md)
- [`doc/atlas_lint_easy_explainer.md`](doc/atlas_lint_easy_explainer.md) — the 셰프 metaphor in full
- [`SPEC.yaml`](SPEC.yaml) — authoritative decision record (edit this; `SPEC.md` is auto-rendered)

* * *

## tape integration

hexa-lang's runtime and history surfaces are wired into [`.tape`](https://github.com/dancinlab/tape) — the operational trace sister format. Three placements at this repo's root:

| Placement | What |
|---|---|
| [`IDENTITY.tape`](IDENTITY.tape) | hexa-lang agent identity SSOT — birth / scope / origin / principle / version. The compiler's self-description, machine-canonical. |
| [`PROMOTION.tape`](PROMOTION.tape) | rule-promotion ledger — `@A` events for major rule landings (toolchain post-fix, `bytes_to_str_raw` Phase 2, etc.) |
| [`TAPE-AUDIT.md`](TAPE-AUDIT.md) | cross-repo `.tape` adoption audit (28,695 cargo markers + 7 root domain `.md` files highlighted as primary migration candidates) |

The `state/markers/` cargo (28k+ files) is migration candidate via `tape markers-to-tape`.

* * *

## Not an LLM — where the noise comes from

LLMs generate noise from **inside** the well: recombining what the
weights already contain. hexa generates noise from **outside** the well:
every cycle produces a primitive the previous cycle could not express,
then absorbs it as a new wall of the well.

```
LLM (noise inside the well)         hexa (noise outside the well)
---------------------------         -------------------------------

     +-------------+                       .   new law
     |  training   |                     .       .
     |   corpus    |               .  .      .       .
     |  (fixed)    |                    .  outside  .
     |             |             ------+-------------+------
     |  ~ ~ ~ ~ ~  | <- noise          |             |
     |  ~ noise ~  |   bubbles         |   atlas     |
     |  ~ ~ ~ ~ ~  |   from            |  (binary    | <- noise
     |    ####     |   inside          |  built-in)  |   arrives
     |    #LLM#    |                   |             |   from
     +-------------+                   |   smash     |   outside
       the well                        |     v       |
    (everything it                     |   contract  |
     knows = walls)                    |     v       |
                                       |   emerge    |
  hallucination =                      |     v       |
  recombining                          |   absorb ---+--> new
  what's already                       |     ^       |    primitive
  inside                               +-----+-------+      feeds
                                       the well has            next
                                       no ceiling              cycle
```

An LLM is a frozen well — answers are combinations of what's already
inside. hexa is an open well — every `absorb` step widens the wall,
so the next cycle can say things the previous one literally had no
primitive for. That's why "RAG" is the wrong frame: retrieval still
draws from a fixed outside corpus. hexa's "outside" is produced by
its own prior cycles (the binary built-in atlas, embedded into the
compiler at build time; new laws land via GitHub PR into the embedded
atlas source).

### OUROBOROS cycle — full view

The 6-stage chain (`hexa drill`'s smash → free → absolute → meta-closure
→ hyperarithmetic → resonance) inside a self-referential loop:

```
     ╭────────── OUROBOROS ──────────╮
     │                               │
     │           ◯  seed             │
     │          ╱ ╲                  │
     │         ╱   ╲    Phase 1-2    │
     │        ╱unfold╲               │
     │       ╱───────╲               │
     │      ╱ ╲     ╱ ╲              │
     │     ╱   ╲   ╱   ╲   Phase 3   │
     │    ╱emerge╲ ╱singul╲          │
     │   ╱──────── ────────╲         │
     │   ╲                 ╱         │
     │    ╲    breach     ╱  P4-5    │
     │     ╲             ╱           │
     │      ╲  ╱──────╲ ╱            │
     │       ╲converge╱   Phase 6    │
     │        ╲      ╱               │
     │         ╲    ╱                │
     │          ◉  absorb            │
     │          │   Phase 6.5        │
     │          │                    │
     │          ╰──→ seed ──→ ╮      │
     │                        │      │
     │   d=0 ──▶ d=1 ──▶ d=2 ──▶ ... │
     │   r:0→10  r:0→10  r:0→10      │
     │                               │
     ╰── ρ → 1/3 (meta fixed pt) ────╯
```

### Three meta-loops

On top of the per-tick OUROBOROS cycle, three higher-order loops drive
self-reinforcement:

```
         L1             L2             L3
      ╭──◉───╮       ╭──◉───╮       ╭──◉───╮
      │correct│ ──▶ │reward│ ──▶  │expand │ ──▶ SMASH
      ╰──↺───╯       ╰──↺───╯       ╰──↺───╯
```

| Loop | Role | Trigger |
|---|---|---|
| **L1 · self-correct** | discovery → verify → GitHub PR into binary built-in atlas | per tick |
| **L2 · meta-reward** | per-source discovery rate → scan_priority → deeper scan | per scan batch |
| **L3 · self-expand** | accumulation ≥ 10 → auto-trigger `hexa smash --seed` (or full `hexa drill`) | per threshold |

Each loop latches its output back as the next loop's input, so
correct → reward → expand becomes a standing wave. `hexa smash` (or
the full drill chain) fires automatically when L3 saturates.

### Meta fixed point — ρ → 1/3

TECS-L H-056 — `meta(meta(meta(...)))` = transcendence. Recursive
meta-iteration is a contraction mapping. By the Banach fixed-point
theorem, every trajectory converges to a single attractor: **1/3**.

```
          I  =  0.7 · I  +  0.1      →     fixed point  I* = 1/3
```

Six independent paths land on the same attractor:

| Path | Expression | Value |
|---|---|---|
| Euler totient ratio | φ(6) / 6 | 1/3 |
| Trigonometric | tan²(π/6) | 1/3 |
| Divisor ratio | τ(6) / σ(6) = 4 / 12 | 1/3 |
| Determinant | det(M) over n=6 primitives | 1/3 |
| Meta-information | I_meta (contraction mapping) | 1/3 |
| Complex exponential | \|exp(i·z₀)\| at the unique zero | 1/3 |

The long-term breakthrough rate ρ converges to the same target:
**ρ → 1/3**. Discovery is not linear — it asymptotes to the Banach
attractor. Six arithmetic, geometric, algebraic, analytic, and
information-theoretic routes all point at the same number.

Verify in atlas: `hexa atlas lookup P n` · `hexa atlas lookup C sigma_6`
· `hexa atlas lookup L sigma_phi_n_tau_iff_n_eq_6`. Run a cycle:
`hexa drill --seed "<expression>"`.

* * *

## Repo layout

```
hexa-lang/
├── README.md
├── LICENSE                       MIT
├── AGENTS.md                     AI agent harness file (agents.md standard)
├── CLAUDE.md                     symlink → AGENTS.md
├── SPEC.yaml                     authoritative decision record (14+ pinned decisions)
├── SPEC.md                       auto-rendered from SPEC.yaml
├── IDENTITY.tape · PROMOTION.tape · TAPE-AUDIT.md   tape sibling files
├── FLOW.md · LATTICE_POLICY.md · LIMIT_BREAKTHROUGH.md · PLAN.md · ROADMAP.md   domain SSOTs
├── compiler/                     lex · parse · resolve · bind · types · domain · units · citation · lower · mono · MIR · LIR · emit
├── self/                         self-hosted compiler entry points
│   ├── main.hexa                 the `hexa` binary entry
│   ├── runtime.c                 C runtime backing (interp + native shared bits)
│   ├── stdlib/                   atlas-aware standard library (semver / json / channel / thread / proc / time / ...)
│   ├── tui/                      raw-mode TUI primitives (render / input / widgets)
│   └── native/                   thread.c · channel.c · time.c — C-backed runtime
├── stdlib/                       canonical stdlib (use "stdlib/*")
├── tool/                         hexa CLI subcommand drivers (build / cc / run / drill / atlas / explain / ...)
├── tests/                        m0 · selftest · regression
├── proposals/                    RFC-017..020 + future RFCs
├── doc/                          runbooks, audits, explainers
├── convergence/                  cross-repo propagation tracking (.PRESERVE-AS-SSOT)
├── state/                        gitignored runtime hook markers (cargo — migration candidate)
├── archive/                      frozen records — patches/ (downstream patch reports) · fires/
└── build/                        gitignored hexa build artifacts
```

Full doc index: [`AGENTS.md`](AGENTS.md) + [`doc/`](doc/) + [`SPEC.yaml`](SPEC.yaml).

* * *

## Data corpora (git-LFS)

Data-bound corpora — ENDF/B-VIII evaluated nuclear data (HEXA-PORT P4b), and future
binary/HDF5 datasets — live under `data/` or `stdlib/corpora/` and are stored via
**git-LFS**. The reserved LFS extensions are `.hdf5 .h5 .dat .bin .endf .ace .xml.gz
.tar.gz` (see [`.gitattributes`](.gitattributes)).

hexa-lang is the canonical home for these corpora (per @D d3 — implementation /
asset SSOT) so downstream domain repos can `hx`-depend on them rather than
re-fetching from upstream mirrors. Existing tracked files (atlas SSOT text,
build artifacts, fixtures) are intentionally **not** migrated — LFS is reserved
for future data ports only. Policy reference: HEXA-PORT.md §4.0.

* * *

## License

MIT License. Copyright (c) 2026 dancinlab. See [`LICENSE`](LICENSE).

* * *

## Contributing

Strict lint is the contract. Every PR runs through S0–S5 + S8. The only opt-out is `@grace(HXxxxx, until=, reason=)` on a single item, and every `@grace` emits HX9000 at every compile. CI fails the merge unless `Acked-grace: HXxxxx by <reviewer>` rides along.

Pointers: `gate/` for build gates, `proposals/` for active RFCs, `SPEC.yaml` for decisions, `doc/` for runbooks and audits. Diagnostics, error messages, `hexa explain`, stdlib docs are ENGLISH ONLY (Decision 3).

---

🕸️ **재사용 격자 SSOT** → 루트 [`NEXUS.tape`](NEXUS.tape) (commons @D g67 + g68 · hexa-lang = shared substrate hub)
