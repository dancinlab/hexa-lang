# RFC 071 -- source-to-silicon e2e (hexa source -> NVPTX silicon, full build)

**Status:** DRAFT -- Shape-B 1st commit (RFC drafted + P0 scaffold:
`cmd_build --target=nvptx64-*` target-string recognition + informative
deferred-message exit). Multi-cycle phased work (P0 .. P4). Falsifier
battery defined.

**Author session:** 2026-05-20, off `s1-step2-codegen-perf`.

**Successor to:** GPU.md sec 2a (build pipeline gap analysis) +
RFC 055 (`hexa-src -> NVPTX` codegen backend) +
RFC 067 / 068 / 069 / 070 hand-emit + silicon-fire ledger.

**Predecessor lineage:** GPU.md `## 10 -- Closure criteria` ledger item

> `[ ] sec 12 P4+ source-to-silicon e2e -- full .hexa source -> silicon (next layer 2a)`

RFC 071's P4 cycle is the fire that flips that box.

**North-star alignment:** north-star (2) ("self-host -- hexa-lang
compiles itself; interpreter retired") has been measured-proven for the
CPU codegen path (`project_compiler_native_self_host_fixpoint.md`:
gen1.s = gen2.s byte-identical 10,094,662 B md5
`29426b801cb072b2861bd608e884b20b`). The remaining gap is
**self-host on NVPTX** -- compile a `.hexa` source file all the way to
launchable PTX without going through `hexa_v2 -> C -> clang` (which is
the CPU bootstrap path) and without an out-of-band emit-driver shell
script (which is today's working but non-self-host pattern).

**Scope discipline:** Shape-B per `@D g_inbox_processing_loop`. P0
ships RFC + cmd_build target-string scaffold ONLY. P1-P4 are explicit
deferred multi-cycle work. Per `@D g3` the closure of this RFC requires
all four falsifiers (sec 4) measured-PASS; until then this RFC is
"scaffolded, not closed".

---

## sec 1 -- Problem statement

`hexa build src.hexa --target=<triple>` accepts six cross-compile
targets today (`linux-x86_64-musl` / `linux-x86_64-glibc` /
`linux-aarch64-musl` / `linux-aarch64-glibc` / `darwin-arm64` /
`darwin-x86_64`) via the `target_zig_triple()` table in
`self/main.hexa::cmd_build()`. All six targets share one build
pipeline:

```
src.hexa
  -> module_loader (flatten transitive imports)
  -> hexa_v2 transpiler (.hexa -> .c)
  -> clang / zig cc (.c -> ELF / Mach-O)
  -> ad-hoc codesign on Darwin
  -> output binary
```

The NVPTX path needs a categorically different pipeline:

```
src.hexa
  -> module_loader (flatten transitive imports)
  -> in-hexa compiler self-host (compiler/parse/, compiler/check/,
     compiler/lower/, compiler/codegen/nvptx_target.hexa)
  -> MIR
  -> codegen_emit_ptx_sm80(...)
  -> PTX text
  -> ptxas (or driver-JIT cuModuleLoadDataEx)
  -> launchable kernel
```

`hexa_v2` emits C and does not know about NVPTX. The NVPTX codegen
(`compiler/codegen/nvptx_target.hexa`, ~3500 lines) lives only inside
the in-hexa self-host tree and is invoked from
`compiler/codegen/nvptx_lower_test.hexa`-style harnesses, NOT from the
`hexa build` CLI verb.

GPU.md sec 2a (finding posted 2026-05-20) confirmed the substantive gap
is the pipeline, not the arg parser. RFC 071 owns the substantive
work; the arg parser side is the P0 placeholder this RFC's commit
lands.

## sec 2 -- Approach options

### Approach A -- internal emit-driver pattern

`cmd_build` recognises `--target=nvptx64-*` and synthesises a tiny
driver source on-the-fly:

```hexa
use compiler/parse/...
use compiler/check/...
use compiler/lower/...
use compiler/codegen/nvptx_target
fn main() {
    let src = "<user source>"
    let mod = parse(src)
    let mir = check_and_lower(mod)
    let ptx = codegen_emit_ptx_sm80(mir)
    write_file("<out>.ptx", ptx)
}
```

The synthesised driver is then compiled by the existing
`hexa_v2 -> C -> clang` pipeline (CPU host binary) and immediately
executed; the output is PTX text.

**Cost:** medium. Requires (1) exposing the compiler pipeline as a
callable from a single entry-point, (2) the synthesised driver source
to compile cleanly under `hexa_v2`. The synth-then-exec layer is
already proven via cmd_run / aprime_cc / aprime_cc-direct work.

**Tradeoff:** the host stage still goes through C-transpile -- but the
GENERATED ARTIFACT is PTX, not a C-transpiled binary. The C step is in
the build host, not in the target -- `@F f2` allows fallback C
emission for portability; the architectural target is hexa-native.

### Approach B -- compiler self-host on NVPTX

Extend north-star (2) self-host to NVPTX: the in-hexa compiler IS the
build path for `--target=nvptx64-nvidia-cuda-*`. Skip `hexa_v2`
entirely; the in-hexa pipeline (compiler/parse + check + lower +
codegen/nvptx_target) is invoked directly.

**Cost:** high. Requires the in-hexa compiler to run standalone
(without `hexa_v2` bootstrapping). The `compiler-native-codegen`
campaign branch + `project_s3_fixpoint_full_closure_2026_05_20.md` have
proven the CPU side; an NVPTX backend extension is the natural next
step.

**Tradeoff:** long-cycle work; relies on the CPU self-host campaign
being production-ready first (currently fixpoint-proven but not yet
the default `HEXA_BACKEND` -- per
`project_compiler_rfc063_p0p1_closed_p2_started.md` Px closure
ledger).

### Approach C -- out-of-band emit driver (current state)

Keep using shell scripts like the
`inbox/fires/rfc06[7-9]_p4_*/`-pattern (`tool/dispatch_*.sh` /
`tool/r06[7-9]_p4_host.c`): hand-emit PTX, scp to ubu-2, fire via
`hexa gpu fire` (PR #215).

**Cost:** zero new infrastructure.

**Tradeoff:** the kernel author hand-emits PTX. NOT a self-host path.
Today's 8 silicon-fires (per GPU.md sec 13) all landed via this
pattern; the source-to-silicon e2e closure box stays `[ ]`.

### Recommended choice

**A for P1-P2** (internal emit-driver pattern) -- minimum-viable wiring
to flip the closure box, no compiler self-host campaign blocking; the
generated artifact is PTX which is the silicon-targeted unit.

**B for P3+** (self-host on NVPTX) -- once the CPU self-host campaign
default-flips (`HEXA_BACKEND=native`) the NVPTX path naturally rides
the same default-flip mechanism. RFC 071 P3+ tracks this convergence.

**C stays available** as the fast-iteration shell for codegen authors;
deprecation is NOT in RFC 071 scope.

---

## sec 3 -- Phasing (4 cycles MIN; falsifier-driven)

### P0 -- this commit (RFC + cmd_build target-string scaffold)

**This commit's deliverable:**

- this RFC file
- `self/main.hexa::cmd_build` recognises `--target=nvptx64-nvidia-cuda-sm80`
  / `sm90` / `sm120` as known target strings, prints informative
  deferred-message ("RFC 071 P1+ wiring; use hand-emit PTX +
  `hexa gpu fire` for now -- see GPU.md sec 7c"), exit 1.
- GPU.md sec 2a + sec 10 cross-link annotation to this RFC.
- `compiler/PLAN.md ## 진행 로그` one entry.

**Falsifier:** F-RFC071-TARGET-ACCEPT (P0-side measurement:
`hexa parse self/main.hexa` clean + `hexa build foo.hexa --target=nvptx64-nvidia-cuda-sm80`
produces the informative-deferred message with exit 1, while existing
CPU targets remain byte-identical).

**Scope discipline:** P0 is the scaffold. It does NOT compile any
kernel. It does NOT touch the codegen tree. It does NOT regenerate
the `hexa_v2` bootstrap binary (per `@D g_commit_push_deploy` the
narrow rule -- only `self/{lexer,parser,type_checker,codegen_c2}.hexa`
+ `self/main.hexa` regen-when-codegen-affecting -- `self/main.hexa`
driver branch alone does not require bootstrap regen). Parse-gate is
the closure measurement.

### P1 -- cmd_build NVPTX target real dispatch (emit-driver synth)

`cmd_build` synthesises an emit-driver source on the fly + compiles +
exec's it (Approach A). The driver imports
`compiler/codegen/nvptx_target.hexa` + calls
`codegen_emit_ptx_sm80(mir)` for a hard-coded simple kernel (e.g.
RFC 068's f16 vadd shape). Output: `out.ptx` text file.

**Falsifier:** F-RFC071-EMIT-DRIVER-INVOKE (P1):
`hexa build kernel.hexa --target=nvptx64-nvidia-cuda-sm80 -o out.ptx`
produces a PTX file with a valid `.visible .entry` symbol + non-empty
body.

### P2 -- emit-driver hexa module (real compiler pipeline)

The emit-driver code lifts from "synthesised on the fly" to a real
hexa module under `compiler/cli/build_nvptx.hexa` (or similar). The
driver pipes through real `compiler/parse + check + lower +
nvptx_target` -- not the canned MIR from P1. The driver is built once
and reused.

**Falsifier:** F-RFC071-MODULE-LOADER-BRIDGE (P2): for a `.hexa` source
file containing `@gpu_kernel fn f(a: [f32], b: [f32], n: i64) { ... }`,
the build emits PTX whose body reflects the source body (not a canned
fixture). Smoke = byte-eq vs hand-written PTX fixture from RFC 067.

### P3 -- `@gpu_kernel` discovery via module_loader

`module_loader.hexa` learns to surface `@gpu_kernel` annotations to
the driver -- one source file may contain CPU + GPU functions; the
driver selects the kernel(s), the CPU portion routes to the existing
CPU pipeline. The split keeps single-source-file builds working.

**Falsifier:** F-RFC071-MODULE-LOADER-BRIDGE (P3): a mixed
`.hexa` file with one `fn main()` + one `@gpu_kernel fn k(...)` builds
two artifacts -- CPU binary + PTX text -- from a single
`hexa build src.hexa --target=cpu+nvptx64-nvidia-cuda-sm80` invocation
(target syntax TBD in P3 design).

### P4 -- end-to-end source-to-silicon fire

A real `.hexa` source file compiles to PTX, then `hexa gpu fire`
launches it on ubu-2 RTX 5070 (sm_120), and the numeric output is
byte-eq to the CPU reference. The chain is:

```
flame d=8 attention kernel (.hexa)
  -> hexa build --target=nvptx64-nvidia-cuda-sm120
  -> attn.ptx
  -> hexa gpu fire attn.ptx host.c ubu-2
  -> measured numeric output
  -> CPU reference (computed via hexa run on the same source)
  -> max|d| = 0 byte-eq
```

**Falsifier:** F-RFC071-E2E-NUMERIC-EQ (P4): full chain `max|d| = 0`
on at least one kernel + GPU.md sec 10 closure box flips `[x]`.

---

## sec 4 -- Falsifier battery

| ID                                     | claim                                                                     | cycle |
| -------------------------------------- | ------------------------------------------------------------------------- | ----- |
| F-RFC071-TARGET-ACCEPT                 | `cmd_build` recognises 3 NVPTX target strings, prints deferred-message    | P0    |
| F-RFC071-EMIT-DRIVER-INVOKE            | `--target=nvptx64-*` produces a non-empty PTX text artifact               | P1    |
| F-RFC071-MODULE-LOADER-BRIDGE          | source-level `@gpu_kernel` body shows up in emitted PTX                   | P2/P3 |
| F-RFC071-E2E-NUMERIC-EQ                | source -> PTX -> silicon -> max|d| = 0 vs CPU reference                   | P4    |

---

## sec 5 -- Honest scope (g3)

Per `@D g3` (verification-anchor-real-limit) and the
`feedback_instrument_first_methodology` memory:

- **P0 closes nothing beyond the target-string accept gate.** It does
  not change the CPU codegen path (`--target=linux-*` / `darwin-*` /
  empty-string native remain byte-identical). It does not touch
  `compiler/codegen/nvptx_target.hexa`. It does not regenerate the
  bootstrap binary. It does not introduce LLVM (`@F f2`) or any new
  C-transpile path beyond the existing portable artifact.
- **GPU.md sec 10 closure box `[ ] sec 12 P4+ source-to-silicon e2e`
  stays `[ ]`** -- P0 only adds an RFC 071 P0 progress note; the box
  flips when F-RFC071-E2E-NUMERIC-EQ measures PASS at P4.
- **Existing hand-emit silicon-fires (PR #82 / #189 / #190 / #191 /
  #203 / #205-207 / #213 / #222) are not regressed** -- they continue
  to land via the `tool/dispatch_*.sh` + `hexa gpu fire` pattern
  unchanged. RFC 071 introduces a new path, not a replacement.
- **`@F f1` (no LLVM) + `@F f2` (no C-transpile in architecture)
  honored** -- the NVPTX path goes
  `src.hexa -> module_loader -> in-hexa compiler -> PTX text`. The C
  step at P1-P2 (host compile of the synth driver) is bootstrap host
  scaffolding, not the codegen architecture; long-term P3+ replaces it
  with the self-host native path per north-star (2) once the campaign
  default-flips.

## sec 6 -- Cross-references

- GPU.md sec 2a "build pipeline gap analysis" (the finding this RFC
  formalises).
- GPU.md sec 10 closure box `[ ] sec 12 P4+ source-to-silicon e2e`
  (the box this RFC's P4 fire flips).
- GPU.md sec 12 "Cross-references" -- this RFC joins the
  `inbox/rfc_drafts_2026_05_20/rfc_06[7-9]_*.md` Shape-B set.
- AGENTS.tape `@N n1` self-hosted-toolchain (north-star 2 path).
- AGENTS.tape `@F f1` / `@F f2` -- no LLVM, no C-transpile in
  architecture (preserved this RFC).
- AGENTS.tape `@D g_commit_push_deploy` -- bootstrap regen rule;
  P0's `self/main.hexa` edit alone does NOT trigger codegen regen
  (narrow rule wording).
- AGENTS.tape `@D g_atlas_binary_builtin` -- PR-only invariant
  preserved; no direct fold-to-live.
- `project_compiler_native_self_host_fixpoint.md` -- the north-star
  (2) CPU campaign that RFC 071 P3+ extends to NVPTX.
- `project_compiler_rfc063_p0p1_closed_p2_started.md` -- Px campaign
  current closure ledger.
- `reference_gpu_fire_infra.md` -- ubu-2 + PTX driver-JIT context that
  P4's fire consumes.
