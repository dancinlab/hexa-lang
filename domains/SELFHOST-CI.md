@title: 🔒 SELFHOST-CI — lock self-host into standing CI

@goal: Lock the self-host achievement (gen2 byte-eq fixpoint + multi-target cross-emit + promote parity + the hx-selfhost-cli shim) into REQUIRED CI checks, so that any codegen / linker / runtime edit that silently regresses self-host FAILS the PR instead of rotting unnoticed. The byte-eq graduation is the entry GATE for SELFHOST-NEXT; this domain is the standing regression FENCE around it.

# SELFHOST-CI — current state

The self-host byte-eq fixpoint was won on the ghost macOS host: the graduated
`gen2_fix` native compiler re-emits the FULL flattened compiler to a
byte-identical object across generations —
`cmp cc-prc2-fix.o == cc-gen3.o == cc-gen3b.o == cc-gen4.o` all exit 0
(3,224,592 bytes each). That proof is a one-time event; nothing in CI yet
prevents a future codegen/linker edit from quietly breaking it.

This domain turns each leg of the achievement into a standing gate. It is
ADDITIVE only — gate scripts + workflows + verdicts + docs. NO production
codegen edits live here (those belong to RUNTIME / CC-NATIVE / HEXA-CC-ZERO).

Sister gates already on main establish the pattern this domain extends:
`tool/miscompile_zero_gate.sh` (+ `.github/workflows/miscompile-zero-gate.yml`)
and `tool/determinism_gate.sh` (+ `determinism-gate.yml`). Both classify a
build-floor "cannot native-emit here" as exit 2 → CI-neutral (#2547), so a
runner that lacks the graduated `gen2_fix` never false-fails a PR. SELFHOST-CI
follows the exact same exit-2-neutral discipline.

## milestones

- [x] byte-eq fixpoint gate — `tool/selfhost_byteeq_gate.sh`: re-emit gen3 → gen4 from the graduated `gen2_fix`, `cmp` byte-identical (FIRSTDIFF=0), assert ENCODE-MISS=0; + a fast native-codegen regression probe (`0xff`→255 hex-literal + the `c2_stack_locals` STP/[sp] corpus emit clean, 0 ENCODE-MISS). Wired as `.github/workflows/selfhost-byteeq-gate.yml`.
- [x] native-codegen regression guards — `tool/selfhost_codegen_guard.sh` (+ `.github/workflows/selfhost-codegen-guard.yml`): a standalone always-run guard distinct from the heavy byte-eq leg, with THREE hard-assert corpora — (1) full self-emit ENCODE-MISS=0 (required assert, not just report); (2) 0x-literal value-check corpus (`g1_hex_corpus`: 0x0 0x7f 0x80 0xff 0xffff 0xdeadbeef incl. wide MOVZ/MOVK chunk lowering, locks #47421c89c); (3) STP/LDP [sp] value-check corpus (`g2_stp_ldp_corpus`: store/load pairs at varied [sp] offsets, locks #2579). Real ghost run PASS (exit 0): self-emit ENCODE-MISS=0 / 8-8 literals / 73 stp+115 ldp pairs at 35 distinct offsets. Verdict `.verdicts/selfhost-ci/CODEGEN-GUARD.txt`.
- [x] multi-target cross-emit smoke — `tool/selfhost_crossemit_smoke.sh` (+ `.github/workflows/selfhost-crossemit-smoke.yml`): per-PR smoke that re-emits a data-bearing program for each cross target via the in-tree serializers (`compiler/test/elf_{arm64,x86_64}_data.hexa` → pack_lir_*_elf + serialize_elf_*), ASSERTS the actual reloc entries (arm64 page PAIR R_AARCH64_ADR_PREL_PG_HI21 + R_AARCH64_ADD_ABS_LO12_NC #2562 ×2 .rodata+.data; x86_64 R_X86_64_PC32 #2563 ×2), and LINK+RUNs each (x86_64 natively, linux-arm64 under qemu-aarch64-static #2603). Real run PASS (exit 0) on summer (x86_64 Linux + aarch64 cross-binutils + qemu): arm64-ELF reloc+run, x86_64-ELF reloc+run, linux-arm64 run — all stdout=hi rc=7. exit-2-neutral canary verified on macOS (emit passes, host-bound assert/run legs neutral). Verdict `.verdicts/selfhost-ci/CROSSEMIT-SMOKE.txt`.
- [x] promote parity-gate-in-CI — `tool/selfhost_parity_gate.sh` (the HARD precondition baked into `tool/promote_selfhost.sh`) wired as a STANDING per-PR check via `.github/workflows/selfhost-promote-parity.yml`. Proves the self-hosted gen3 ≡ shipped across N=5 representative behaviours (each compiled by gen3 → clang -c → hexa_ld link → RUN, exit code matching the pre-registered `// expect:`): arith=42 (+42-smoke), call=13, branch=7, bitmask=15, recurse=120 — BEHAVIOUR is the load-bearing axis. Real run on ghost (macOS arm64, graduated slot `~/.hx/self/native/selfhost/`): gate exit 0, 5/5 behaviour-match PASS — "promotion AUTHORIZED". Also verified the tier2 `hx-selfhost-cli` shim routes compile→gen3 (exit 42) + delegates subcommands. exit-2-neutral canary on macos-latest (no graduated gen3 → neutral, same #2600/#2605/#2607 shape). Verdict `.verdicts/selfhost-ci/PROMOTE-PARITY.txt`.
- [x] shim integrity — `tool/selfhost_shim_integrity.sh` (+ `.github/workflows/selfhost-shim-integrity.yml`): a STANDING per-PR behaviour-integrity gate for the `tool/hx-selfhost-cli` shim (#2588). FULLY HERMETIC — builds a fake `$HX_HOME` with instrumented STUB gen3 + STUB shipped backup and probes which the shim reached, so it runs REAL on ANY host (incl. hosted CI) with NO graduated-compiler dependency (strengthens over the host-bound sister gates — no neutral run legs). Four hard asserts: ① compile routing (`--emit=obj/asm`, leading/trailing, `-o` → gen3, argv verbatim); ② subcmd delegation (verify run build atlas loop install fmt test --version --help bare kick → shipped, argv verbatim); ③ symlink-loop guard (flipped `hexa.real→shim` + no backup → FATAL rc127 no recursion; WITH `hexa.real.pre-selfhost.<ts>` backup → delegates, name convention honored); ④ syntax (`bash -n` + shellcheck if present). Real run PASS (exit 0) on mini (Darwin arm64, bash 3.2): all four PASS. Verdict `.verdicts/selfhost-ci/SHIM-INTEGRITY.txt`.
- [ ] determinism — keep the existing re-emit + relink byte-eq (`determinism_gate.sh`) wired and required; track its inclusion in the self-host required-check set.

## deferred

- make the byte-eq + determinism + miscompile-zero gates REQUIRED status checks on the `main` branch protection (needs repo-admin; record the check names once green on ghost).
- self-host a cached `gen2_fix` build step IN CI so the heavy byte-eq leg runs hermetically on `macos-latest` instead of only exit-2-neutral there (today it is real only on the ghost host that holds the graduated artifacts).
- publish the byte-eq fixpoint as a CLAIMS.tape verifiable claim cross-linked to `.verdicts/selfhost-ci/BYTEEQ-GATE.txt` (overlaps SELFHOST-NEXT deferred reproducible-build attestation).
