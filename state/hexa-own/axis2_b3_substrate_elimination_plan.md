# axis-②③ B3 — own-emit SUBSTRATE ELIMINATION (kill `clang self/runtime.c`) — plan + measured kickoff

**★ SSOT for the longest pole to 3-lane DONE.** Fable-designed (reads the RFC061 attack plan +
stage_resolve_runtime_a); measured round-0 GREEN this session (2026-07-12).

## The honest shape (Fable, measured)

`runtime.c` elimination is a **genuine port** (interpretation (b)), NOT a build-swap: the emitted C TUs
(runtime.c / runtime_core.c, via `runtime_core_emit.hexa` = 10,822 appends) have **no `.hexa` semantics
to route** — ~1,090 fns / ~29–32k live LOC (HexaVal machinery 733 = 67% · syscall wrappers 229 · vendor
glue 72 · C-primitives 56). That is the multi-session mass (Round-3+). The canonical clang sites are
`stage_resolve_runtime_a:3206` (MULTIOBJ runtime.o, ship path) + `:3211` (runtime_core.o) + `:3294`
(single-TU) + `:3274/:3302` (CUDA host).

## But Round-1 (A0) is a build-path change fleetable NOW — MEASURED

The **13 seed families already have `.hexa` origin** (frozen `.s` seeds from `stdlib/runtime/*.hexa`,
assembled by `$CC`, adoption sites stage_resolve_runtime_a:303–1010). Swapping `.s + $CC -c` →
`aprime --emit=obj` direct kills the `$CC`-as-assembler residue + the darwin hand-byte fixtures
(:1598–1700, Route-C-canon-violating).

**round-0 PROBE = GREEN** (summer, the fcvtzs-branch aprime): own-emit `--emit=obj` of the seed
`.hexa` sources succeeds — **10/13 OK · 0 FAIL** (3 "no-src" = path-name only: rt_hi/fs_core/
alloc_syscall live under different filenames). T-sym counts: array_core 8 · map_core 5 · intern_core 2 ·
str_core 5 · num_core 1 · num_float_core 3 · float_parse_exact 17 · float_parse_hexinfnan 6 · regex_rt
82 · valop_core 10. So the shipped-binary-can-own-emit-a-runtime-module gate that Fable made round-0 is
CLEARED → A0 is unblocked.

## Fleet decomposition (Fable)

- **A0 (round-1, NOW · zero new codegen)**: `HEXA_RT_OWNOBJ={0(default)|auto|1}` tri-state lane over the
  13 seed families + per-family `HEXA_RT_OWNOBJ_<FAM>` quarantine (the `HEXA_RT_NATIVE_STRCMP`
  :1964–1972 pattern). Branch inside each family block before `$CC -c`. Single-file contention in
  stage_resolve_runtime_a → per-family enablement+verify inside ONE build, not N parallel edits.
- **A1 (round-2)**: the ~35 one-symbol flip members (strcmp/strtoll/free/calloc/sin/cos/FILE-family…) → own-obj.
- **S1**: FRAG-KILL easy tier, 9 independent units (mount 71 LOC · namespace · wait · proc_fork · fp_init · signal_flock · exec_pipe · exec_argv_sha256 · persistent_pipe).
- **S2**: `HEXA_ZEROC_RT_CORE_*` cluster drain (~17 `#ifdef` clusters in runtime_core_emit.hexa).
- **Round-3+ (the mass)**: HexaVal machinery drain (733 fn) → m3 all-or-nothing TU drops (runtime_core.c → runtime.c → shim + runtime_core_sysheaders.h delete = **② literal DONE**) → m4 emitter retirement gen3≡gen4.

## Blocked-on-extension (named)
- **E1** `__hx_cabi_call` (grep 0 hits) → unblocks S3 vendor tier (net/crypto/thread/term/pty) + ffi_dyn.
- **E2** arm64 AAPCS64 fp C-ABI rung → 3-target fp-member symmetry.
- **E3** `__init_array_*` synth in hexa_ld → TU-drop under own-link.
- **E4** own symbol-demotion (replace binutils `objcopy --keep-global-symbol`) → 1-sym-contract members.
- **E5** own `ar`-writer (hexa_ld reads archives; assembly still forks binutils `ar`).

## Gating (proof gate ≠ byte-identity — own-emit bytes ≠ GNU-as bytes)
(i) default-OFF archive byte-identity (merge gate) · (ii) per-member **nm defined-global set equality**
vs the seed member · (iii) `ld -r` multidef==0 · (iv) **RUN parity** = new `tool/ownobj_member_parity_gate`
(model on ownlink_corpus_parity_gate, both archives, stdout+rc, incl the float corpus) · (v) ship witness
via `tool/release_build` + byteeq 3-target + install smoke. Flip separate PR `:-0`→`:-auto` (strtoll
#4833–35 precedent), hard `1` only at S-e endgame.

## Honest floor at B3-DONE (name in every claim; don't launder)
CUDA `runtime_cuda.c` (opt-in, nvcc) · ffi_dyn IF E1 frozen-unsafe · binutils residue (ar/objcopy/ld-r
= ②-legal, ③-relevant, survives to E4/E5) · darwin members (linux-x86_64-first, keep path to E2+arm64
obj lane which THIS branch's FCVTZS + #4896 complete) · hexa_cc.c (axis-① lane, untouched).

## Resume — next concrete step
Implement the **A0 lane** in `stage_resolve_runtime_a`: add `HEXA_RT_OWNOBJ` tri-state + branch each of
the 10 own-emit-GREEN family blocks (before `$CC -c`) to `aprime --emit=obj` under the flag, default-OFF.
Build `tool/ownobj_member_parity_gate` (nm-defined-global equality + RUN parity vs the `.s` seed member).
Verify on pool (prefer summer; aiden contention-prone) family-by-family, then a `:-0`→`:-auto` flip PR.
delicate file — has convergence guards (stage-resolve-runtime-a-1 · stage-resolve-flag-space-1 ·
axis3-arm64-cross-archive-arch-contamination): preserve trailing-space on flag inserts, fetch-then-
checkout on pool builds.
