# stdlib — folder guide (sub-CLAUDE)

> hexa-lang **governance SSOT is the repo-root `../CLAUDE.md`** (this file is only a guide to that
> subdirectory; on conflict, root wins). The design SSOT is `../ARCHITECTURE.json` (Component map · Data flow).
> History lives in git + `../CHANGELOG.md`. This file is only a map — no accumulating versions/dates.

## What is this directory

`stdlib/` = the `.hexa` standard library. ~2270 `.hexa` files in which **two hemispheres** of differing
character live in one directory — ⓐ the general-purpose spine (core·collections·io·json·net·http·time·path·crypto·…) and
ⓑ the huge **science-numeric hemisphere** (qforge·bio·flame·quantum·chem·signal·matter·physics·kernels·…).
The general-purpose spine is the everyday data-structure·I/O·parsing utilities the compiler/toolchain uses, while the science hemisphere is
domain sims·numeric kernels·ML train/inference stacks consumed mostly via `hexa <verb>` (e.g. `hexa qforge`) runtime
dispatch or as domain libraries.

## Main subtree map

### general-purpose spine (core / general)
```
core/          — base types·arithmetic: string · bytes · math · parse · special · option/result · trait fixtures
collections.hexa · hashset.hexa · record.hexa · smart_ptr.hexa — general data structures
io.hexa · log.hexa · path.hexa · portable_fs.hexa · proc.hexa · sys.hexa — I/O·process·FS
json* · yaml.hexa · csv·parse.hexa · semver.hexa · argparse.hexa · regex/ — parsing·serialization
net/ · http*.hexa · http_sse.hexa · websocket.hexa · channel.hexa · future.hexa · cancel.hexa — networking·concurrency
crypto/ (101) · hash/ · cert/ · qrng/ · cloak/ · keychain.hexa — crypto·hash·credentials
codec/ · regex/ · tokenize/ · time/ · stats/ · linalg/ · matrix/ · tensor/ — encoding·numeric utilities
c_ffi.hexa · python_ffi.hexa · dynlink_caps.hexa · wasm/ · posix/ · hal/ (139) — FFI·platform·HW abstraction
hx/ · build/ · cloud/ (84) · ddp/ · registry_autodiscover.hexa — package/build/cluster glue
```

### science-numeric hemisphere (numeric / ML)
```
qforge/ (365)  — largest science subtree: SCF·DFPT·el-ph·MAE·smearing and other first-principles physics (QE reference-match · `hexa qforge` CLI)
bio/ (247)     — life: PK/PD · protein-fold · gene-edit · rna-therapy · organoid · xeno
flame/ (140)   — ML training stack (decoder·trainer·flame_math) — some byteeq-relevant (see below)
quantum/ (116) · qubit/ — quantum circuit·state sim
chem/ (48)     — MD(langevin·verlet) · kinetics(TST·Arrhenius) · FEP/MBAR · SMILES
signal/ (25)   — DSP: FFT · filters(biquad) · mel filterbank · autocorrelation (native libm trig)
math/          — ode · special(elliptic) · lattice(A₂…Λ₂₄ Gram) · numtheory · rng · quadrature
kernels/ (54)  — low-level numeric/neural kernels (lif_kernel etc.) · mc_integrate/ · optim/
physics/ · matter/ (42) · material/ · sim_universe/ (77) · space/ · nuclear/ — physics·materials·cosmos
nn.hexa · autograd.hexa · optim.hexa · safetensors.hexa — ML core primitives
```

### domain clusters (applied science·engineering)
```
materials/devices: crystal · graphene · perovskite · spintronic · photonic · memristor · neuromorphic · chip · metamaterial · aerogel
energy/chemistry: fusion · energy · co2-capture · green-nh3 · electrocat · photoredox · mlff · mol*.hexa
circuits/HW: vhdl · yosys · firmware · rtsc · booksim · component · memristor · srr · sscb
systems/tools: demi · deck · dojo · loop · lsp · scope · policy · research · discovery · easy · bot · cockpit · cluster
```
(The full module tree·dataflow is `../ARCHITECTURE.json` — no duplication here. The above is a contributor-entry map.)

## byteeq-neutrality convention (IMPORTANT gotcha)

A stdlib module is **"byteeq-neutral" unless the self-host compiler closure (`self/`) imports it**.
Editing a byteeq-neutral module **cannot change** the `gen3≡gen4` byte-identical self-host fixpoint,
so you **fix it directly and verify via PR CI** without the 3-target byteeq gate (most science stdlib is here —
consumed only via runtime dispatch `hexa qforge`/`hexa deck` etc.).

Check:
```sh
grep -rl "<module-path>" self/ | grep -vE 'test_|_test'   # empty = neutral
```
⚠️ A bare grep gets **false-positives from comment·CLI dispatch strings** — e.g. `self/main.hexa`
merely holds `"stdlib/qforge/qforge_cli.hexa"` **as a string** for a runtime verb dispatch path and does
not pull it into the compile closure (still neutral). When in doubt, eyeball the hit line to confirm whether it is
a real `import …`/`from …` statement.

Modules that self/ **actually imports** are **byteeq-RELEVANT** — a change needs the 3-target (x86_64-linux ·
arm64-linux · darwin-arm64) byteeq gate. Known examples:
- `nn.hexa` ← `self/env.hexa`
- `autograd.hexa` ← `self/token.hexa` (plus codegen·parser·attrs paths)
- `path.hexa` · `self/stdlib/*` (array·map·random·tensor_ops) are also inside the closure
For relevant modules, do not merge on mini — merge after pool (aiden·summer·ghost) byteeq actual-measurement.

## malformed-input guard convention

A stdlib function must **guard** malformed/degenerate input — instead of spitting out Inf/NaN/OOB it
returns a documented sentinel (`[]` · `0.0` · `-1.0` etc.).
- `arr[0]`/`arr[i]` reads are guarded with a `len(arr)==0` (or index-range) check.
- `/ divisor` (parameter·length·mass·sample_rate·temperature etc.) is guarded with a `divisor<=0` check.

This class was the subject of a large QA campaign (`../CHANGELOG.md` #3943..#3969 — ~69 byteeq-neutral fixes).
One census (`tool/guard_class_census.py` · re-runnable) measured **~2576 candidate sites/658 files**
→ the class spans all of stdlib so manual round-robin can't deplete it → **converted to a regression gate**:
- `tool/stdlib_guard_lint.hexa` — wired into `.githooks/pre-commit` as **advisory (warn-only · non-blocking)**.
  Flags newly added unguarded sites (G1 unguarded-index · G2 unguarded-divide).
  Heuristic, so warn not hard-fail. (`--selftest`/`--mode=warn`/`--changed`)
- `tool/guard_class_census.py` — for a one-shot full audit.

## native-canonical convention

- math/signal use **native libm trig** (`cos`/`sin`/`tan`/…) — no hand-rolled Taylor series
  (codegen-fragile). General polarity is in lockstep with root `../CLAUDE.md` [native-canonical-default].
- Numeric kernels verify correctness via **reference-match** — QE(qforge el-ph) · scipy/numpy(special·
  lattice·stats) · LAPACK(linalg). Parity is a starting point, not the destination.
- Tests sit beside the module as `*_test.hexa` / `*_selftest.hexa` (e.g. `core/string.hexa` ↔
  `core/cmp_total_order_test.hexa` · `math/ode.hexa` ↔ `math/ode_test.hexa`). Some modules are
  self-contained tests that inline their own answers and may miss shipped-data drift (e.g. in the past
  `lattice_test` passed with an inline Gram and masked a `gram_K12` data error — cross-check the shipped path).

## gotcha

- **huge stdlib · per-module ownership** — at 2270 files there is no single owner. When fixing one module,
  check the neighboring `*_test.hexa`/`*_selftest.hexa` and the reference answers together.
- **formula-bearing functions require an atlas citation** — a formula-bearing function whose build lacks one of
  `@cite(L[id])` · an active `@verify` · `@grace` will refuse binary emit (S8 citation gate · fatal `HX8004`).
- **classify byteeq before editing** — before touching, split neutral/relevant with the grep above. If neutral,
  fix directly on mini and PR CI; if relevant, merge only after pool byteeq 3-target GREEN.
- **build/byteeq/measurement on pool** (aiden·summer·ghost) — `mini` is git/gh/read·write only
  (no heavy build·akida).
- **`.ai.md` sidecar** — the `*.ai.md` next to some modules (io·yaml·semver·channel·cancel·c_ffi etc.) is that
  module's AI-assist note (not the source SSOT · root CLAUDE.md wins).
