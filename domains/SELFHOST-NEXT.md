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
- [ ] multi-target bootstrap: linux-arm64 self-host (faithful CI already exercises rt_fs guard — extend to full self-emit)
- [ ] multi-target bootstrap: x86_64 codegen path (new backend surface — scope first)

## deferred

- reproducible-build attestation: publish the byte-eq fixpoint as a verifiable claim in CLAIMS.tape + `.verdicts/`
- bootstrap-time regression budget: track aprime→gen2 wall + RSS as a perf gate (strtab O(n) baseline)
- drop the float-dup / no-float runtime_core.c wrinkle once the self-host path owns runtime regen end-to-end
