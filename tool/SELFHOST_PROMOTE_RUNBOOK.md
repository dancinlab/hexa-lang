# Self-host toolchain promotion runbook

SELFHOST-NEXT milestone: promote the self-hosted native gen compiler to the
default `hx`/`hexa` toolchain, **parity-gated**. This runbook is the one-command
reproducible path + the precise final-flip procedure.

## What graduated

The native self-hosted hexa compiler reached the **byte-eq fixpoint**:
`cc-gen3.o == cc-gen4.o` byte-identical (stage-2 self-emit output == stage-3
self-emit output), all `ENCODE-MISS = 0`, gens deterministic. Proof verdict:
`.verdicts/compiler-selfhost-fixpoint/`. Proven build host: **ghost** (macOS
arm64). All source fixes are on `origin/main` (#2479, #2509, #2532 — the
hex-literal `parse_int` base-16 fix in `compiler/lower/hir_to_mir.hexa` and the
`__literal8` const-merge fix in `tool/hexa_ld.hexa`).

## The bootstrap ladder (what `build_selfhost.sh` does)

```
seeds   tool/restore_frozen_seeds  -> self/runtime.c + self/native/hexa_cc.c  (151c52c8 blob)
hexat   clang hexa_cc.c            -> build/hexat        (C-transpiler bootstrap)
stage0  tool/build_aprime.sh       -> aprime_cc          (hexat-transpiled native compiler)
linker  hexat tool/hexa_ld.hexa    -> hexa_ld            (Mach-O linker, __literal8 fix)
runtime clang self/runtime.c       -> rt.o
stage1  aprime_cc emit cc-flat     -> cc-prc2.o -> gen2  (1st self-emit, ~68min)
stage2  gen2 emit cc-flat          -> cc-gen3.o -> gen3  (2nd self-emit, ~68min)
stage3  gen3 emit cc-flat          -> cc-gen4.o          (3rd self-emit, ~68min)
GATE    cmp cc-gen3.o cc-gen4.o    -> BYTE-EQ FIXPOINT
```

The terminal gate is **gen3-output == gen4-output**, not prc2==gen3: the very
first native self-emit (`cc-prc2.o`) still carries a small C-vs-native residual
that converges out by gen3. See the verdict for the 2-residual analysis.

## Step 1 — reproducible build (run on ghost, DETACHED)

```sh
# fresh main checkout on ghost (main has all fixes)
sidecar pool on ghost 'cd ~/dancinlab/hexa-lang && git fetch origin main && git checkout origin/main'

# full build — THREE ~68min self-emits (~3.5h). Detached + done-marker.
sidecar pool on ghost 'cd ~/dancinlab/hexa-lang && nohup bash tool/build_selfhost.sh \
  -w ~/dancinlab/selfhost-work/promote/build \
  --detached ~/dancinlab/selfhost-work/promote/selfhost.done \
  > ~/dancinlab/selfhost-work/promote/build.out 2>&1 &'

# poll the marker (do not inline-poll a 3.5h job):
sidecar pool on ghost 'cat ~/dancinlab/selfhost-work/promote/selfhost.done'
# success line: EXIT=0 STAGE=fixpoint GATE=BYTE-EQ ...
```

Fast path to validate the recipe wiring without the heavy emits:
`bash tool/build_selfhost.sh -j` (stops after aprime_cc + hexa_ld + rt.o).

## Step 2 — parity gate (the promotion precondition)

```sh
sidecar pool on ghost 'cd ~/dancinlab/hexa-lang && bash tool/selfhost_parity_gate.sh \
  -g ~/dancinlab/selfhost-work/promote/build/gen3 \
  -l ~/dancinlab/selfhost-work/promote/build/hexa_ld \
  -t ~/dancinlab/selfhost-work/promote/build/rt.o'
# RESULT: PARITY PASS — promotion AUTHORIZED   (exit 0)
```

Axes: per-program **behaviour parity** (compile+link+run under gen3, exit code
must match the pre-registered `// expect: N`) + **42-smoke** + optional **asm
byte-match** vs the shipped reference compiler (informational unless `--strict`).
The behaviour axis is load-bearing; asm may differ benignly (reg alloc).

## Step 3 — promotion (gated, reversible, opt-in first)

`tool/promote_selfhost.sh` never blindly replaces the shipped binary. It re-runs
the parity gate as a HARD precondition, then:

```sh
# tier 1 — side-by-side opt-in (default hx/hexa UNTOUCHED):
sidecar pool on ghost 'cd ~/dancinlab/hexa-lang && bash tool/promote_selfhost.sh install \
  -w ~/dancinlab/selfhost-work/promote/build'
#  -> installs $HX_HOME/self/native/selfhost/{gen3,hexa_ld,rt.o}
#  -> drops $HX_HOME/bin/hx-selfhost launcher
#  users opt in: `hx-selfhost <args>`. Nothing else changes.

# status / revert any time:
bash tool/promote_selfhost.sh --status
bash tool/promote_selfhost.sh --revert
```

### The final default-flip (tier 2)

This is the only remaining MANUAL step and is intentionally gated. It backs up
`$HX_HOME/bin/hexa.real -> hexa.real.pre-selfhost.<ts>` and symlinks
`hexa.real -> hx-selfhost`. It REFUSES unless `--i-have-reviewed-parity` is
passed AND the parity gate is green at flip time:

```sh
bash tool/promote_selfhost.sh install --default --i-have-reviewed-parity \
  -w ~/dancinlab/selfhost-work/promote/build
# revert: bash tool/promote_selfhost.sh --revert
```

## Why the default-flip is not auto-landed here

1. It mutates a shipped, on-disk launcher in `$HX_HOME` on the build host —
   outside the repo, not a code change a PR can carry. It must run on each host
   that should adopt the self-hosted default.
2. It should be gated on a green parity run **on that host** at flip time, plus
   a human ack — encoded as `--i-have-reviewed-parity`.
3. The reversible side-by-side tier-1 install delivers the capability today with
   zero risk to the existing default; the flip is a one-liner when ready.

## Final-flip checklist (what the flip needs)

- [ ] `build_selfhost.sh` green on the target host (`GATE=BYTE-EQ`)
- [ ] `selfhost_parity_gate.sh` green on the target host (PARITY PASS)
- [ ] tier-1 `install` done; `hx-selfhost <real workload>` exercised
- [ ] `promote_selfhost.sh install --default --i-have-reviewed-parity`
- [ ] smoke the new default: `hexa --version` / a representative compile
- [ ] keep `hexa.real.pre-selfhost.<ts>` until a soak window passes; `--revert`
      on any regression
