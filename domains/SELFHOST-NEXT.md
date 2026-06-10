@title: 🎓 SELFHOST-NEXT — post-byte-eq toolchain track

@goal: After gen2 byte-eq fixpoint graduation (gen2 ≡ gen3, cmp=0), promote the self-hosted compiler to the default toolchain, land the integration branch on main, and extend the native bootstrap beyond arm64-darwin.

# SELFHOST-NEXT — current state

Pre-created track for everything that comes AFTER self-host byte-eq graduation.
The graduation proof itself (gen2 self-reproduction to a byte-identical fixpoint)
is the ENTRY GATE for this domain, not a milestone of it — it is being driven on
the ghost macOS host (branch `cc-native/selfhost-ghost`, emit in flight).

Prereqs already merged to main: emit fixes #2446 (encoder 9/9) · #2454 (__cstring)
· #2457 (page-reloc + __data/__const) · #2458 (strtab O(n)) · #2464 (SP-encoding
extended-register) · #2479 (ARM64_RELOC_ADDEND kind=10 — gen2 startup fix).

Integration branch `cc-native/selfhost-ghost` carries the not-yet-on-main link
prereqs: arr_alloc codegen map + runtime leaf fns + hexa_ld L1/L2 patches.

## milestones

- [x] ENTRY GATE — native byte-eq fixpoint: consecutive native stages cc-gen3.o == cc-gen4.o (sha d0792379 ghost / ece49087 mini, exit 0). The CORRECT fixpoint is gen3≡gen4 (native↔native), not aprime(C)≡gen2 (one-time C↔native boundary delta). Gate wired as `tool/selfhost_byteeq_gate.sh` on the `selfhost-byteeq-real` CI (ghost-selfhost runner, GREEN). verdict `.verdicts/hexa-cc-native/F-HEXA-CC-NATIVE-N5-FIXPOINT-ACHIEVED.txt`
- [x] land integration fixes — enabling fixes landed to main as stacked PRs #3020 (typeof→type_of builtin alias) + #3024/#3025 (fixpoint gate + verdict). The remaining `cc-native/selfhost-ghost` carries only stale docs (tools already on main); not merged by design (would conflict, no new code).
- [x] promote self-hosted gen to the default toolchain — `tool/promote_selfhost.sh install --default --i-have-reviewed-parity` flips `hexa.real → hx-selfhost-cli` (tier2), parity gate 5/5 PASS on BOTH ghost + mini. Routing: `--emit=<x>` → native gen3 (Mach-O direct, 0 C); `build`/`run`/`verify`/`--version` → C-transpile delegate (safety > coverage). REVERSIBLE via `--revert` (backup `hexa.real.pre-selfhost.*`). Persisted across `hx install` via marker `~/.hx/.selfhost-default` (#3031 — install.sh re-applies the flip on reinstall). Residual (NOT this milestone): full `hexa build` native end-to-end (gen3 owning link + runtime orchestration).
- [x] multi-target bootstrap: linux-arm64 self-host — NATIVE full self-emit byte-eq fixpoint (gen3 == gen4, 0 ENCODE-MISS) on real aarch64-linux hardware (GCP T2A, 8 vCPU Ampere Altra; self-emit 1:17:23, peak RSS 10.88 GiB). Self-hosting NATIVELY, not just cross-emit. verdict `.verdicts/selfhost-next-linux-arm64/NATIVE-SELFEMIT-ARM64-BYTEEQ.txt` (2026-06-03, tag v0.147.1). Pi5 OOMs at codegen (7.76 GiB) — host needs ≥~11 GiB RSS headroom.
- [~] multi-target bootstrap: x86_64 codegen path — PARTIAL. Object-format layer + instruction encoder PROVEN 🟢 on two x86_64 Linux hosts (summer + aiden): `encode_x86_64_insn()` byte-correct (Intel SDM verified), `serialize_elf_exec_x86_64()` emits runnable ET_EXEC, exit42.elf → rc=42, re-emit byte-identical. ELF data relocs (R_X86_64_PC32) also 🟢. Codegen wired in `compiler/main.hexa` (`--target=x86_64-linux-gnu` → `codegen_x86_64_linux()`, ~4.7K L across codegen/x86_64_linux.hexa + emit/elf_x86_64.hexa). OPEN (the milestone proper): full source→x86_64 binary path unproven — native OBJ fast-path gated to arm64-darwin only (main.hexa L900); end-to-end `hexa run compiler/main.hexa -- ret42.hexa --target=x86_64-linux-gnu --emit=asm` hits a bootstrap runtime-extern gap (`__raw_add_f`/`__raw_cmp3` undeclared). verdict `.verdicts/selfhost-next-x86_64-scope/F-P2-X86-EXIT42-SCRATCH.txt` (object-layer ONLY, explicitly NOT a codegen-backend claim).

## deferred

- reproducible-build attestation: publish the byte-eq fixpoint as a verifiable claim in CLAIMS.tape + `.verdicts/`
- bootstrap-time regression budget: track aprime→gen2 wall + RSS as a perf gate (strtab O(n) baseline)
- drop the float-dup / no-float runtime_core.c wrinkle once the self-host path owns runtime regen end-to-end
