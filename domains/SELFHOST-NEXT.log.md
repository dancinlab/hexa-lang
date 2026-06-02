# SELFHOST-NEXT — log

Append-only history sister of `SELFHOST-NEXT.md`. Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.

## 2026-06-02 — multi-target: linux-arm64 cross-emit + assemble + RUN (exit(42), rc 42)

Branch `selfhost-next/linux-arm64-rebased` (cut clean from origin/main; +97 lines, g4-ok).
First working linux-arm64 emit: the arm64 instruction codegen is target-shared with
arm64-apple-darwin — the only deltas are ELF-vs-Mach-O format, bare-vs-`_` symbol prefix,
and the asm-syntax selectors. Wired the (already host-detected but previously unrouted)
`arm64-linux-gnu` triple end to end.

- [x] inventory: `detect_default_target` already returns `arm64-linux-gnu` for Linux
      aarch64 hosts but the codegen dispatch (main.hexa) had NO branch for it → hit the
      unsupported-target error. ELF emitter `compiler/emit/elf_x86_64.hexa` exists
      (defines ELF_EM_AARCH64=0xb7) but is x86-bound; emit/asm.hexa already had a generic
      ELF text path for non-darwin. Runtime is C (`#ifdef __linux__` gated) — portable.
- [x] main.hexa: route `arm64-linux-gnu` → codegen_arm64_darwin with opts.target_triple
      set; ELF aarch64 link recipe (crt1.o + ld-linux-aarch64.so.1); help/error lists.
- [x] arm64_darwin.hexa: thread `cg_target` so LFunc/LModule carry the ELF target string;
      bare `g<id>` global labels on ELF. Default callers keep "arm64-apple-darwin" →
      Mach-O output byte-identical. stream.hexa (darwin-only) passes the Mach-O target.
- [x] emit/asm.hexa: `_is_elf_arm64`/`_is_arm64` so AArch64 `#N` imm + `[base,#off]` mem +
      `.p2align 2` render on ELF instead of x86 Intel fallthrough; suppress `.intel_syntax`
      for ELF arm64; **comment marker `//` not `#`** (on aarch64 GNU as `#` is the imm
      prefix → trailing `# cmt` errors as operands). Caught by the cross-assemble step.
- [x] VERIFY: aprime_cc built from THIS branch on ghost → emit asm (arm64-linux-gnu) →
      cross-assemble on summer (aarch64-linux-gnu-as): `ELF 64-bit LSB relocatable, ARM
      aarch64`, Machine AArch64, Type REL, `R_AARCH64_CALL26` relocs for hexa_exit/
      hexa_set_args → freestanding-stub link (`ld -static -nostdlib`, svc #0 exit) → RUN
      under qemu-aarch64-static: **rc 42**. Verdict: .verdicts/selfhost-next-linux-arm64/.
- [ ] GAP — full linux-arm64 SELF-HOST (compile the compiler for linux-arm64) is the
      remaining milestone: needs (a) ELF arm64 `.o` produced IN-TREE (today the asm→.o
      step uses the host `as`; native `--backend=native` obj path is Mach-O-only — an ELF
      arm64 serializer keyed off elf_x86_64.hexa is the next increment), and (b) the C
      runtime cross-compiled for aarch64-linux + the full compiler-source emit/link there.
- [ ] GAP — no native arm64-linux RUN host in the pool unrestricted (summer/aiden are
      x86_64; pi5-akida is native arm64 but anima-only). Verified via x86_64 cross-binutils
      + qemu-aarch64; native-host bare-metal run is the remaining run-verification axis.

## 2026-06-02 — promote-toolchain: reproducible recipe + parity gate + gated promotion

Scoped + implemented the "promote self-hosted gen to default `hx`/hexa_v2, PARITY-GATED"
milestone. Branch `selfhost-next/promote-toolchain`. Three committed `tool/` deliverables
turn the ad-hoc ghost byte-eq build into a one-command reproducible + safely-promotable path.

- [x] `tool/build_selfhost.sh` — full bootstrap ladder from current main:
      restore_frozen_seeds → hexat → build_aprime.sh (stage0) → hexa_ld (from
      tool/hexa_ld.hexa, __literal8 fix on main) → rt.o → aprime emit→gen2 →
      gen2 emit→gen3 → gen3 emit→gen4 → GATE cmp cc-gen3.o==cc-gen4.o. `-j` fast
      path (stage0 only), `--detached MARK` for the 3×~68min self-emits. NO /tmp.
- [x] `tool/selfhost_parity_gate.sh` — parity precondition: per-program BEHAVIOUR
      parity (compile+link+run gen3, exit==`// expect:`) + 42-smoke + optional asm
      byte-match vs shipped ref (`--strict`). PASS authorizes promotion.
- [x] `tool/promote_selfhost.sh` — gated, reversible promotion. tier1 `install` =
      side-by-side slot + `hx-selfhost` launcher (default UNTOUCHED); tier2
      `--default --i-have-reviewed-parity` = backup hexa.real + symlink flip,
      `--revert`. Parity gate is a HARD precondition for both tiers. NO blind replace.
- [x] `tool/SELFHOST_PROMOTE_RUNBOOK.md` — one-command recipe + the precise
      final-flip checklist + why the default-flip is host-local manual (not a PR-carryable change).
- [ ] HONEST g63: default-flip NOT auto-landed — it mutates an on-disk launcher in
      $HX_HOME outside the repo + needs a host-local green parity + human ack. tier-1
      opt-in delivers the capability now at zero risk; flip is one gated command when ready.
- [ ] heavy ghost build re-verification from a clean main checkout = follow-up (detached).


## 2026-06-03 — byte-eq fixpoint published as first-class verifiable claim (CLAIMS.tape)

Deferred milestone CLOSED: reproducible-build attestation. The graduated self-host
byte-eq fixpoint is now a terminal `@C` claim in root `CLAIMS.tape` with a persisted
`.verdicts/` verdict carrying REAL measured bytes (g63 honest, not asserted).

- **Claim**: `@C selfhost_byteeq_fixpoint` (group=COMPILER · slug=selfhost-byteeq ·
  method=fixpoint). Terminal upgrade of the `compiler_selfhost_fixpoint` STUB (which
  was gen1/gen2 `.s` md5, md-only, NO persisted verdict): this asserts the OBJECT-level
  fixpoint stage3 `cc-gen3.o` == stage4 `cc-gen4.o`, BYTE-IDENTICAL, with a real verdict.
- **Verdict**: `.verdicts/selfhost-byteeq/selfhost_byteeq_fixpoint.txt` — verbatim
  evidence captured from ghost `~/dancinlab/selfhost-work`:
    - `gen4.done`: `EXIT=0 OBJSIZE=3224592 ENCODE_MISS=0 LINK_gen3=0 SMOKE=2 CMP_gen3_vs_gen4=BYTE-EQ-GRADUATION FIRSTDIFF=0`
    - sha256 `32c6db9b5696bd251da62770275d0ba929387198dd750ce3466e7ef11e37fdec` — IDENTICAL
      across cc-gen3.o, cc-gen4.o, AND cc-gen3b.o (full-scale native determinism gen3==gen3b).
    - `cmp cc-gen3.o cc-gen4.o; echo $?` → `0` (byte-identical) · 3224592 B each · ENCODE_MISS=0.
- **Method**: deterministic 3-stage bootstrap via `tool/build_selfhost.sh` → `cmp` GATE;
  artifacts regenerable one-command (verdict notes this honestly). Source fixpoint fixes
  on main: #2479 #2509 #2532. Diagnosis lineage: STAGE3-DIAG.txt predicted the graduation.
- **Schema lint**: self-checked — fields {method,cmd,raw,src,status} present in sibling
  order, slug/group well-formed, `raw` ptr resolves to the verdict file. No dedicated
  CLAIMS lint / `hexa` CLI on ghost; method=fixpoint is empirical (run-stdout = the verify).
