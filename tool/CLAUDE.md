# tool/ — build · self-host · lint · roadmap tooling (sub-CLAUDE)

> hexa-lang **governance SSOT is the repo-root `../CLAUDE.md`** (this file is just a guide to that
> subfolder; on conflict root wins). Design/module SSOT is `../ARCHITECTURE.json`, history is `../CHANGELOG.md` + git.

## What this directory is

`tool/` = the **operational tooling collection** wrapped around the compiler proper (`../compiler` · `../self`)
and stdlib — release build stages, self-host (byteeq · zero-C) gates, Stage-0 lint, the roadmap engine,
atlas operations, GPU probe/bench all gathered in one place. Most are `.hexa` (proof-carrying · run via
`hexa run tool/<x>.hexa`), heavy build orchestration is `.sh`, one-off measurement/dumps are `.py`. There
are many files, so the guide below is **per-family, not per-file** — the exact inventory is `ls tool/`,
and each script's top comment is the usage SSOT.

## File families

### Build · release stages
- `stage_*` — release pipeline stages (`stage_prebuild_hexat` · `stage_regen_hexa_cc` ·
  `stage_build_hexa` · `stage_resolve_runtime_a` · `stage_precompile_package`). Beware the frozen seed +
  shallow-checkout traps (see `../CHANGELOG` history).
- `build_*` — per-target build drivers (`build_hexa_cli*` · `build_native*` · `build_precompile.hexa`
  · `build_selfhost.sh` · `build_aprime.sh` · `build_hx*_linux.hexa` acceleration libs). Heavy builds
  only on the pool (aiden/summer/ghost) — mini forbidden.
- `cross_*` · `regen_*` — cross-target emit + runtime/codegen `.c`·`.o`·`.s` seed regenerators.
  `regen_*` re-bakes generated artifacts (`runtime_core.c` etc., gitignored) from the emitter SSOT — on a
  stale seed conflict, regenerate here (regen skip → alloc-seed multidef incident precedent).
- `release_*` · `restore_frozen_seeds` · `promote_selfhost.sh` — packaging · frozen seed restore ·
  self-host default flip.

### Self-host gates (byteeq · zero-C)
- `selfhost_*` — `gen3≡gen4` byteeq · parity · shim-integrity · crossemit smoke · codegen guard
  gates. `selfhost_gates_summary.sh` is the bundled summary; 3-target GREEN is the prerequisite for stable promotion.
- `zeroc_*` — zero-C drop/flip measurement · ztrace instrumentation (`zeroc_flip_measure.sh` ·
  `zeroc_drop_runtime_measure.sh` · `zeroc_exec_graduate.sh` etc.). RFC061 ladder measurement tools.
- `fixpoint_*` · `miscompile_zero_gate.sh` · `musl_ctor_abi_gate.sh` — fixpoint comparison/pre-check +
  related integrity gates.

### Stage-0 lint (`*_lint.hexa`)
Proof-carrying text scanners run via `hexa run tool/<name>_lint.hexa`. Most are wired into
`.githooks/pre-commit` — some BLOCK (exit 1), some are ADVISORY (warn-only). When adding a new lint, state
its policy (block vs warn) in the comment at the top.
- Code discipline: `bounded_loop_lint` (RFC-010 bounded-for/decreases-while) ·
  `blocking_timeout_lint` (forces `timeout` on blocking I/O) · `no_hardcode_lint` (magic path/URL/host ·
  `.hardcode-baseline` grandfather) · `total_fn_lint` · `exec_eq_int_lint` ·
  `runaway_pattern_lint` · `resource_lint`.
- Codegen/self-host: `codegen_tau4_lint` (τ=4 emit-slot invariant) · `module_loader_collision_lint` ·
  `private_fn_collision_lint` · `parser_format_stability_lint`.
- **`stdlib_guard_lint`** — Stage-0 ADVISORY (warn, never blocks). Catches **newly** added `arr[0]`
  first-element reads / `/ divisor` divisions added without an empty/zero guard in the same function — regression
  prevention for the "malformed-input guard" bug class fixed in PRs #3943..#3963. Run:
  `hexa run tool/stdlib_guard_lint.hexa --selftest | --mode=warn <files> | --changed`.
  Wired into `.githooks/pre-commit` as ADVISORY (warn only, does not block the commit). The one-off full census is
  `guard_class_census.py` (re-runnable · kept in `tool/` since `state/` is gitignored).
- Hygiene/misc: `backup_file_lint` (no working-tree backup files) · `ext_lint`/`doc_lint`/`poc_lint` ·
  `spawn_lint`/`precommit_spawn_lint`/`swarm_lint`/`telegram_lint`/`runaway_pattern` ·
  `lb_state_lint` · `roadmap_lint`/`roadmap_schema_lint` (+ `test_roadmap_lint`).

### Roadmap engine (`roadmap_*`)
DAG-based work-roadmap parser·scheduler·observability module group (`roadmap_engine` · `roadmap_kahn` ·
`roadmap_critical_path` · `roadmap_dispatch` · `roadmap_status_flip` · `roadmap_to_changelog` etc.).
`roadmap_cli.hexa` is the entry point.

### atlas operations (`atlas_*`)
Human layer (`../ATLAS/`) ↔ machine layer (`../compiler/atlas/embedded.gen.hexa`) operations —
`atlas_cli` · `atlas_verify` · `atlas_embed_gen` · `atlas_bulk_absorb` · `atlas_split_by_kind`.
verdict atom fold goes only through the `hexa verify` g5 PASS path.

### CLI · diagnostics · verification
- `hx.hexa`/`hx_*` — `hx` package-manager helpers (drift/coverage/stage-health scanners).
- `verify_*` · `cross_prover.hexa` · `dod_gate.hexa` · `doctor.hexa` · `hexa_diag.hexa` —
  verification certificates · DoD gate · diagnostics.
- `hexa_ld.hexa` · `hexa_link.hexa` · `hexa_repl.hexa` · `hexa_init.hexa` · `compile.hexa` —
  linker · REPL · project init and other CLI helper surfaces.

### GPU · bench · probe (mostly one-off measurement)
- `probe_*_f64.hexa` · `*_probe.hexa` — kernel precision/oracle probes (libm trig · gemm · rope ·
  softmax …). For reference-match measurement.
- `gpu_*` · `cuda_*` · `*_driver.cu` · `dispatch_*` · `fusion_*` · `decode_*` · `wgmma/` ·
  `hexa-fusion/` — GPU microbench · cuBLAS comparison · fused kernels · remote dispatch scripts.
- **`build_cuda_runtime`** — `cuda_available 0→1` CUDA runtime build + `cuda_gemm_verify` verdict
  + **auto deploy** (swap `~/.hx/bin/build/runtime.a` + reset `~/.hexa-cache/` → `hexa run` immediately takes the GPU path). Run:
  `bash tool/build_cuda_runtime` (CUDA_HOME auto-detect: cuda-13.0 > cuda-12.9 > /usr/local/cuda symlink ·
  needs nvcc ≥12.8 · SM=120 default). Env overrides: `CUDA_HOME=/usr/local/cuda-X.Y SM=120` (explicit) ·
  `DEPLOY_RT=""` (deploy skip). ✅ **old defects FIXED**: (1) 19× multi-def (#4213): resolved after
  restore_frozen_seeds via `_regen_runtime_core_for_cuda()` + reconcile_runtime_c_ssot_dups + RT-NATIVE Z2a.
  convergence `CUDA-BUILD-CORES-EXPLICIT-LINK-MULTIDEF` SSOT. (2) CUDA_HOME default auto-detect (#4216):
  when the old default `/usr/local/cuda-13.0` is absent it fell back to system nvcc (CUDA 12.0, sm_80) → GEMM all-zero
  on RTX 5070 sm_120. Now auto-detects `/usr/local/cuda-12.9` (or the `/usr/local/cuda` symlink).
  summer RTX5070 sm_120 CUDA12.9 measurement — d2048 FAST median 458.64 GFLOP/s · DET 454.14 GFLOP/s ·
  FAST/DET=+0.99% (state/fast-vs-det-gemm-verdict.md). hexa vs PyTorch F64 2048^3: hexa 464.3 vs
  PyTorch 482.9 GFLOP/s → 96% parity (state/hexa-vs-pytorch-gemm-verdict.md). (3) EVP_* undef
  (#4218): removing `-DHEXA_HAS_OPENSSL` from the host compile → the deploy archive's `runtime_cuda_host.o`
  no longer references EVP_*. Cause: `self/main.hexa` CUDA link path (~L1487) doesn't add -lssl before the early-return
  (TODO: follow-up PR to add an SSL probe at self/main.hexa ~L1487). convergence `CUDA-LINK-MISSING-SSL`.
- `unshadow_*_bench.hexa` · `bench_*` · `train_floor_bench.hexa` — codegen/runtime perf benches.

### Subfolders
`bin/` (build entry) · `wrappers/` (CLI wrappers) · `hooks/` · `config/` · `docs/` (stdlib module reference
`.md`) · `bench/` · `jit/` · `pkg/` · `test/` · `clm/` · `training/` · `phi_extractor/` ·
`*_selftest_fixtures/` · `transient_py/` (one-off py, slated for removal) · `r9_walls`/`r14_walls`/`r15_walls`
(measurement wall artifacts).

## Work rules (root governance + folder reinforcement)

- **Build/regen/byteeq on the pool (aiden·summer·ghost) only.** mini = git/gh/read only (heavy build
  crashes). akida build farm forbidden.
- **State the policy when adding/editing a lint** — write whether it's BLOCK or ADVISORY (warn-only) in the
  comment at the top of the script, and update the `.githooks/pre-commit` wiring in the same change. ADVISORY
  lints never block a commit (`stdlib_guard_lint` is the reference example).
- **regen artifacts are not SSOT** — `regen_*` output (`runtime_core.c`·`*.o`·`*.s`) are gitignored
  artifacts regenerated from the emitter. Don't touch them directly; bake them via the emitter + regen scripts.
- **Merge codegen/runtime/stage changes only after a byteeq-safe check** — 3-target GREEN + ship smoke (root
  [release integrity] guardrail). docs-only tooling changes are gate-exempt.
- Detailed history is in `../CHANGELOG.md` + git (this file is update-in-place CURRENT-STATE).
