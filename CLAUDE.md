# hexa-lang

## Project
Native `.hexa` compiler with an embedded theorem **atlas** + `hx` package manager. **No LLVM anywhere**: source→own-IR→native, linked by `hexa_ld` — byte-identical self-host fixpoint (`gen3 ≡ gen4`).

**⭐ SELF-HOST DONE CRITERION (user standing · the finish line):** self-host is "done" only when the toolchain needs **① no `hexa_cc.c`** (the emitted hexa→C transpile fallback at `self/native/hexa_cc.c` — `hexa build`/`run` lowers every flow through the native source→own-IR→native path, never the C-transpile delegate) · **② no `runtime.c`** (the ~5.5k-LOC emitted-C runtime/libc-syscall substrate — ported to native `.hexa`/`.s`/own-emit so nothing compiles a generated `.c`) · **③ no `clang` (nor any external C compiler) to build OR use `hexa`** (install/`build`/`run` never shell out to clang/gcc — the own object-emit backend + `hexa_ld` do the whole compile+link). All three are **emitted (gitignored) artifacts today**, not hand-written source — the `self/*.c` hand-source floor is already ∅ (`git ls-files self/**/*.c == ∅`, #4356 cuda + #4352 timegm), but **file-∅ of hand-written C is NOT the DONE line**; the DONE line is eliminating all three ①②③. **⚡ ACTIVE GOAL (user standing · 2026-07): drive all three ①②③ to DONE via a perpetual 3-lane fleet** (`selfhost-done-3axis-fleet` — lane1=①`hexa_cc`, lane2=②`runtime_c`, lane3=③`clang-flip`, fire-on-arrival until each crosses; per-axis status SSOT = `ARCHITECTURE.json` `activeGoal` + `convergence.records[]`). Latest: **axis-③'s LINK half is demonstrated** — the own ELF linker links own `.o` + `runtime.a` → static `ET_EXEC` (exit 42, ZERO binutils, data-seg/bss covered, opt-in `--linker=hexa`, #4711–#4718); the COMPILE half (`--backend=native --emit=obj`) already exists, so the axis-③ frontier is the **default-flip**. Guardrail: **release integrity > self-host progress** — every flip opt-in-first → byteeq 3-target GREEN + shipping smoke → default-ON; the sole inviolable = no-LLVM.

Progress toward that line (measured tracks): the emitted-C substrate is a **reducible** RUNTIME-PORT target whose authoritative nm-UND libc floor is exposed per-CI (advisory dump in `nobaseline-gate.yml`, #4360); flips drop libc UNDs one family at a time — strtod-tail native default-ON (#4651, T_mis=0 vs glibc) · own-start default-ON drops atexit/environ/`__libc_start_main` (FLIP-7) · MULTIOBJ print-family native redirect default-ON (`HEXA_RT_STDIO_NATIVE`, #4856) drops `printf`/`fprintf`/`perror`/`snprintf` glibc-stdio UND from the ship runtime.a (own raw `write(2)`, 3-target byteeq + ON-path GREEN; opt-out `=0`). fortify `__*_chk` dropped via `-D_FORTIFY_SOURCE=0` (#4361) · perf-neutral syscall leaves routed to raw-svc (getpid #4358 · setpgid #4364) · compiler-synth `memcpy/memset` — a reference-matched glibc-style overlapping-load-dispatch native body **measures 1.3–2.0× faster than libc for the small-copy (struct) regime + parity at large** (summer, clang-18; the naive-byte-loop "perf-wall" is FALSIFIED), so the `-fno-builtin-memcpy` flip is a measured-viable next round gated on byteeq 3-target + real-workload perf, not a permanent wall. The `clang`-dependency (③) is the native-emit/self-assemble endgame — own object emit + `hexa_ld` replacing the clang compile+link, so a consumer needs only the `hexa` binary. Every formula-bearing fn must cite an atlas law (`@cite`)/`@verify`/`@grace`, else the build refuses to emit (`HX8004`). Domain tracking is retired.

Governed by the vendored `.harness-engine` (`hardcore`) via `.claude/settings.json` hooks (no-op when absent): single-doc discipline, L0 lockdown, `.hexa` changelog gate, protected branches. `hexa verify` = g5 gate.


## Tree
```
hexa-lang/
├─ compiler/ — parser·own-IR·codegen + atlas/embedded.gen.hexa (machine SSOT)
├─ stdlib/   — .hexa stdlib (flame/forge GPU, math/libm)
├─ self/     — self-host seeds + hxlcl_* libc floor (→ ∅)
├─ ATLAS/    — theorem ledger (README.md, hypotheses/)
└─ ARCHITECTURE.json — deep structure SSOT (viewer `python3 serve.py`)
```
Governance → rules below · history → CHANGELOG.jsonl.

## Performance gold standard
- do: **Go · Rust · PyTorch = reference-match gold standard**: perf **≥ Rust**, ML throughput **≥ PyTorch(+cuBLAS)**, by measurement not LLM.
- do: open-source ref → read source, match 1:1 + surface/idiom (no bespoke wrapper/shim); then hexa axes.
- dont: **no-LLVM + byte-exact are non-negotiable** — never adopt LLVM, never ship a non-canonical surface; "LLVM-free so slow is OK" forbidden.

## Release integrity — absolute top guardrail
- do: self-host proceeds **only if it doesn't break the used release**, else defer — **release integrity > self-host progress**.
- do: merge codegen/runtime only after **byteeq 3-target GREEN + shipping smoke**; bit-identical ungated, bit-changing behind opt-in toggles; then sync pool hosts.
- do: one channel = **`stable`** (`edge`·`test` retired), verified via github-hosted PR-CI byteeq + pool builds; `finalize` flips Latest on 3/3.
- dont: never merge changes breaking the user-facing path (shipping binaries·`build`/`run`·stdlib·C-fallback) for a self-host gate.
- dont: **never promote on "only x86 green"** — require all-3-target GREEN + install.sh consumer smoke GREEN.

## Implementation discipline — implement-to-the-wall · reference-first
- do: push every impl/fix **to the wall (🧱)** — name the next round; stop only at 🏁 or a **measured** wall; prove walls with **captured numbers**, not LLM-judgment.
- do: **parity is a start** — beyond-parity via hexa levers (byte-eq determinism · no-LLVM emit · fusion · device-residency), by measurement.
- dont: no diagnose-then-STOP (punt) · symptom patches · shadow guards · filler rounds · **black-box tuning-constant sweeps**.
- dont: fusing ≠ gain (fuse only memory-bound epilogues); byte-eq determinism is not an overtake lever.

## HEXA-UNBOX — "unboxing" (runtime-speed campaign trigger)
- do: on cue **"unboxing"**, strip the boxed-HexaVal 16B/kernel tax; **measure-first** (isolated, not back-to-back).
- do: merge a lever default-OFF (byte-neutral); flip default-ON only after regular-CI byteeq 3-target+nvptx GREEN.
- dont: tune-to-green · enshrine a contaminated ratio as ceiling · aliasing miscompile · merge an unmeasured lever.

## QA — continuous verification · verify-done always-on
- do: close each fix in one loop **measure→root-cause→verify→merge** with **captured output**; codegen/runtime → byte-eq across 3-target, all configs.
- do: continuous QA loop; report falsified/negative results; build/measure on the pool (mini = git/gh).
- dont: unverified "done" · one-config/one-target-green merge · per-op tests alone · enshrine an artifact/forge-bench time as ceiling · tune-to-green.
- dont: a stale-pool-hexat measurement (→ slow CPU fallback) · `hexa cc --regen` workaround · a release cut for one bench · retired `HEXA_VERSION=test`.

## native-canonical-default — polarity
- do: default path is **always hexa-native/own/canonical**; external deps (cuBLAS·vendor·legacy) are **opt-in-flag-only** (`HEXA_USE_CUBLAS`).
- do: if native-default costs perf, **keep polarity** but expose the fast path opt-in; slower ≠ broken.
- do: **⚠️ determinism axis is the sole polarity exception** — fast non-det default, det opt-in (`HEXA_DET`); own/vendor polarity stays invariant.
- do: **the whole DX surface (pkg/lib·install·GPU·env) is a native-canonical install path** per `pip`/`cargo`/`npm` canon (packaging layer, distinct from kernel polarity).
- do: canonical install/update must auto-produce `cuda_available()=1` on a CUDA host (hand-build/workaround = packaging defect).
- do: stdlib math defaults to native libm trig; hand-rolled kernels allowed for self-host/accuracy.
- do: cross-target `hxlcl_*` native-emit = **codegen C-ABI** (Route C, default-OFF), not hand-assembled byte arrays.
- dont: **never invert polarity** (native behind a flag · `HEXA_NO_CUBLAS`) — flag-on = "enable a constraint/external-dep"; **never leave the DX surface non-canonical**.

## flame/forge determinism — API primary + env escape-hatch · fast-nondet DEFAULT
- do: **fast non-det DEFAULT** own-native atomic kernels (cuBLAS-TC via `HEXA_USE_CUBLAS`); det OPT-IN = fixed-order non-atomic, byte-exact.
- do: **det = API primary + env escape-hatch**: `set_deterministic()`/`is_deterministic()` + `HEXA_DET=1`, **API > env**; eval/verdict/decode call it directly.
- do: GPU det axis ≠ the selfhost-determinism-gate.
- dont: bypass the safety-pin · promote cuBLAS to fast-default · miss CI det enforcement · revert to det default · promote env above API precedence.

## Atlas · verification
- do: atlas ledger SSOT = **`ATLAS/README.md`** (incremental); layers = human README + **machine SSOT** `compiler/atlas/embedded.gen.hexa` — loading updates both.
- do: on `🔵`/`🟢` `hexa verify` the atom **auto-folds** into embedded.gen.hexa (branch→PR only).
- do: run math DFS **via `hexa loop --dfs`** only (budget cap + verify gate); land domain audits via `hexa verify --<axis>`.
- dont: update only the human layer (omitting embedded.gen.hexa) · promote an unread/unverified/lattice-fit conjecture to 🔵 · treat **n=6 as the center**.
- dont: never call the external LLM outside `hexa loop --dfs`; never revive retired remnants (lowercase `atlas/` · `TECS-L/` · `.tape` ledgers).

## git · L0 · lockstep
- do: before a guard-file change a subagent diffs vs baseline; an L0-lockdown-file edit updates `CHANGELOG.jsonl` same change.
- do: on a `hexa` release/CLI update, **lockstep-update** `hexa --help`·`hexa gpu` same change (repos trust `hexa gpu` as GPU-status SSOT).
- do: keep HuggingFace uploads under the `dancinlab` org.
- dont: never commit a >50-line deletion from `stdlib`/`runtime`/`codegen`/`rt` without a scoped subject or `WIPE-OK:` trailer.

## CI · self-hosted runners
- do: **cloud CI = github-hosted runners** 3-target run all PR gates (Blacksmith retired for cost, #4015→#4016 revert); if the local SSH pool is down, verify via **a PR**.
- do: heavy faithful/byteeq builds → **self-hosted runners** (`ghost`·`aiden`·`summer`); arm64/darwin/ephemeral stay on cloud (no arm64 self-hosted host).
- do: public-repo fork-PRs run on self-hosted only after maintainer approval (RCE).
- dont: **never let the required gate (`selfhost-gates-summary`) depend on an offline/unverified runner** — promote a job only after measuring it green.

## Governance baseline — everything but no-LLVM allowed (user standing)
- do: **the sole inviolable = no-LLVM** (source→IR→native→`hexa_ld`); every other technique is allowed (hand-rolled kernels · new keywords/builtins · frozen re-baseline · setjmp/va_list ABI).
- dont: never break no-LLVM (via an LLVM backend/IR); no unverified merge skipping the 4 disciplines (release-integrity·byteeq-3-target·reference-match·git-safety).
