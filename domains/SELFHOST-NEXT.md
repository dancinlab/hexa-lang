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

- [ ] ENTRY GATE — gen2 byte-eq fixpoint verdict (cmp cc-prc2.o == cc-gen3.o, exit 0) confirmed on ghost
- [ ] land integration branch `cc-native/selfhost-ghost` (link prereqs: arr_alloc map + leaf fns + hexa_ld L1/L2) to main
- [ ] promote self-hosted gen to the default `hx` / hexa_v2 toolchain (replace the bootstrap compiler), with smoke + verify parity
- [ ] multi-target bootstrap: linux-arm64 self-host (faithful CI already exercises rt_fs guard — extend to full self-emit)
- [ ] multi-target bootstrap: x86_64 codegen path (new backend surface — scope first)

## deferred

- reproducible-build attestation: publish the byte-eq fixpoint as a verifiable claim in CLAIMS.tape + `.verdicts/`
- bootstrap-time regression budget: track aprime→gen2 wall + RSS as a perf gate (strtab O(n) baseline)
- drop the float-dup / no-float runtime_core.c wrinkle once the self-host path owns runtime regen end-to-end
