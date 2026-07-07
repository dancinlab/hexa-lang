HEAD verified at 49ba06b35. Here is the axis-③ round design.

## 0. The VERIFY answer first — your "no `as` fork" inference is FALSIFIED

`aprime_cc --emit=obj --target=x86_64-linux-gnu` **does fork system `as` by default**. The native ELF x86_64 writer exists and is fully wired (`pack_lir_x86_64 + serialize_elf_x86_64`, dispatched at `compiler/main.hexa:1006`), but it only engages when `backend_kind == "native"` — and the default-native auto-flips cover **only** arm64-darwin (`compiler/main.hexa:508-512`) and arm64-linux (`:516-520`). There is no x86_64 flip. Bare x86_64 obj emit falls through to the `.s`-text path: write asm (`:1065`), fork binutils `as` (`:1075-1080`), `cp` the object out (`:1096-1106`). The `.o` you saw on aiden is ELF *because `as` produced it*, not because the native writer ran. Neither leg-B call site passes `--backend` (`self/main.hexa:3550` build, `:4578` run), and nothing in-tree exports `HEXA_BACKEND`. Round-1's baseline strace will confirm this empirically.

## 1. Dependency map per target (at 49ba06b35)

| target | own object emit | `as` fork | own link | external link |
|---|---|---|---|---|
| **arm64-apple-darwin** | ✅ native **default-ON** (`main.hexa:508` flip → `:964`, `emit/macho_arm64.hexa`) | none | ✅ `tool/hexa_ld.hexa` (2473 LOC, Mach-O-arm64-only: `parse_macho_obj:254`, `link_macho_arm64:597`, ad-hoc codesign) — but **script-invoked only**; not reachable from the driver | `--emit=exec` forks `ld64` + `xcrun` SDK probe (`main.hexa:1122-1127`); `--linker=hexa` stub warns + falls back (`:1151-1153`) |
| **x86_64-linux-gnu** | writer EXISTS (`emit/elf_x86_64.hexa`, 1747 LOC, R_X86_64_64/PC32/PLT32, dispatched `:1006`) but **opt-in only** (`--backend=native` / `HEXA_BACKEND`, `:356`) | ✅ **forked by default**, including leg-B | scaffolds only: `link_elf_x86_64` (`elf_x86_64.hexa:736` — static ET_EXEC, text-concat, no rodata/data segments) and `compiler/link/hexa_ld.hexa` v1 (single-obj, .text-only) — neither production | binutils `ld` + glibc `crt1.o` + dynamic-linker (`:1128-1133`); leg-B variant = `ld` with nm-probed crt-drop (#4674) |
| **arm64-linux-gnu** | ✅ native **default-ON** (`:516` flip → `:984`, `emit/elf_arm64.hexa`) | none | none | binutils `ld` + `crt1.o` (`:1134-1145`) |

`clang` itself is never forked by `compiler/main.hexa` on this path — the residual clang lives in axis-① territory (C-transpile fallback, `$CC`-as-linker in `stage_build_hexa:213`). Note `stage_build_hexa:202` (release native-seed) also emits x86_64 with no `--backend` → the release seed object is currently `as`-produced too.

## 2. The single smallest first round: **kill the x86_64 `as` fork**

This is the exact missing sibling of the two flips that already landed, and the lever **already exists end-to-end with zero code**: `HEXA_BACKEND=native` is read at `main.hexa:356` and leg-B's `exec()` inherits the environment. arm64-linux leg-B already skips `as`; x86_64 is the only leg still forking it.

**Round spec:**

- **Lever**: `HEXA_BACKEND=native` (existing, default-OFF). The landable diff, gated on measurement GREEN, is the ~5-line third default-flip block in `compiler/main.hexa` after `:520`, mirroring `:516-520` (`target == "x86_64-linux-gnu" && emit_kind == "obj" → native`); opt-out stays `--backend=system`.
- **Measurement (aiden, hexa built from ≥49ba06b35 — the installed v0.577.0 is stale per your verdict doc)**:
  1. Baseline: `strace -f -qq -e trace=execve -o base.tr env HEXA_BUILD_NATIVE=1 hexa build /tmp/s.hexa` → expect `as` execve ≥ 1.
  2. Lever ON: same + `HEXA_BACKEND=native` → **`as` execve count == 0** (the killed-tool measurement), leg-B still links + binary runs.
  3. Behavior parity: OFF-vs-ON binaries over a corpus, stdout+rc identical (object *bytes* will differ — `as` and the native encoder may pick different instruction forms; the gate is behavior, plus gen3≡gen4 byteeq *within* the new path).
  4. Writer completeness at compiler scale: `bash tool/build_native_linux_x86_64 --self-emit` → **ENCODE-MISS == 0** is a hard gate. This matters: an encode miss emits *silently empty bytes* (the arm64 mirror logs and returns 0 at `macho_arm64.hexa:713`), so MISS>0 means corrupt text, not a warning.
- **Gate for the flip**: byteeq 3-target GREEN (darwin/arm64-linux are bit-identical — untouched branches; x86_64 is the bit-changing leg, which is exactly what the gate suite + shipping smoke exist for) + install.sh consumer smoke. If you want extra caution, land only the measurement harness + verdict this round and flip next round on CI evidence.
- **Failure mode is still a win**: if ENCODE-MISS > 0 on the self-emit census, the round output is the ordered encoder-gap list (which x86 ops miss) — that becomes round-2's worklist, and the flip waits.
- Side benefit: this remeasurement also unblocks the stale-hexa regex ON-build re-run flagged in the axis-① verdict.

## 3. Honest reachability of DONE ③ + ordered remaining tracks

After this round: x86_64-linux = {`ld`}, arm64-linux = {`ld`}, darwin = zero-external in the script path, {`ld64`+`xcrun`} in the driver. **Closest to zero-clang: darwin-arm64** — both pieces exist; they're just not wired together.

Ordered tracks:
1. **This round** — x86_64 `as`-kill (above).
2. **Wire `--linker=hexa` for darwin** — replace the `:1151` stub + `:1122-1127` ld64 fork with the proven `tool/hexa_ld.hexa` path (import or fork-own-binary; forking our own `hexa_ld` is acceptable — it's not an external tool). Medium surface, mostly plumbing.
3. **hexa_ld-ELF (x86_64 first, then arm64-linux)** — multi-round. The tractable route is **static + own `_start`**, which is exactly what axis-② FLIP-7 delivers: with the own-start runtime and a sanctioned-only libc floor, you need no `crt1.o`, no `-lc`, no dynamic-linker — a static ET_EXEC writer with full section layout (text/rodata/data/bss) + the 3 reloc kinds, an honest but bounded job (the `link_elf_x86_64` scaffold at `elf_x86_64.hexa:736` and `compiler/link/hexa_ld.hexa` v1 prove the shape). Track ③ is therefore **coupled to the axis-② floor** — sequencing them together is the efficient DAG.
4. **The wall candidate: dynamic-link leaves.** CUDA (`libcuda.so`), `dlopen`, and networking require dynamic ELF output (PT_INTERP, DT_NEEDED, PLT/GOT, glibc symbol versioning). That is the one genuinely deep substrate track, and it only gates the CUDA/plugin variants — not the base `hexa` binary.

**Verdict: DONE ③ is reachable for the CPU/static toolchain on all 3 targets** (darwin needs only wiring; linux needs the static-ELF linker, unlocked by axis-②'s own-start). The honest terminal risk is the dynamic-link leaf, which mirrors the axis-② sanctioned-floor outcome: the base binary reaches zero-external-tools; the dynamic variants either get a real ELF-dynamic emitter (big, but not proven infeasible) or become the named sanctioned exception. One round at a time — this one kills `as`.