# app-binary "nondeterminism" — verdict (aiden, ~/hx-w7, 2026-07-04)

## Verdict: NOT REPRODUCED as nondeterminism — determinism HOLDS. Phase2 DIFF = output-name-derived artifact.

`hexa build` is **byte-exact deterministic** for app binaries. The /tmp/w7_ownlint_e2e.md phase2
"OFF-vs-OFF DIFF" compared two binaries built with **different `-o` names** (`/tmp/w7_off2` vs
`/tmp/w7_off3`) — the output basename leaks into the binary, by exactly 1 byte.

## Measurements (all on aiden, ~/hx-w7 toolchain, HEXA_PREBUILT_RUNTIME=build/runtime.a, LIBS="-lm -ldl")

| test | procedure | result |
|---|---|---|
| different `-o` names, cold | purge ~/.hexa-cache; build `-o /tmp/nd1`; purge; build `-o /tmp/nd2`; cmp | **DIFF — exactly 1 byte** (offset 647850: `'1'` vs `'2'`) |
| same `-o` name, cold | purge; build `-o /tmp/ndX`; save; purge; rebuild `-o /tmp/ndX`; cmp | **IDENTICAL** (byte-exact) |
| same `-o` name, warm (no purge) | rebuild `-o /tmp/ndX` warm; cmp vs cold | **IDENTICAL** |
| original phase2 pair | cmp -l /tmp/w7_off2 /tmp/w7_off3 | **exactly 1 byte** (offset 647782: `'2'` vs `'3'`) — same signature |
| emitted C | sha256 of build/artifacts/{nd1,nd2,ndX}.c | **all identical** (e3cf14c0c61dd313, 1295 B) — no tmpnam/pid/time in emitted C |

## First-divergence classification

- The single differing byte sits in **`.strtab`** (ELF symbol string table, offset 647680 + 169,
  SHF_ALLOC=0 — not loaded at runtime). It is the digit inside the **STT_FILE symbol name**
  `nd1.c` vs `nd2.c` (visible in `strings` diff; section headers otherwise identical;
  `.note.gnu.build-id` empirically identical — it does not cover `.strtab`).
- Chain: `hexa build` names the emitted C TU after the output basename —
  **`self/main.hexa:3440-3441`**: `let stem = basename_stem(out); let c_file = "build/artifacts/" + stem + ".c"`
  → clang compiles `build/artifacts/<out-stem>.c` and records the TU basename as the ELF
  STT_FILE symbol → survives the link into `.symtab`/`.strtab`.
- Not a timestamp, not a tmp path (the pid-suffixed link temp `/tmp/ndX.tmp.<pid>` is renamed
  away and does NOT appear in the binary), not link order, not build-id.

## Compiler byteeq gates — unaffected

The byteeq/self-host gates (gen3 ≡ gen4, 3-target byteeq) compare artifacts built at **fixed,
identical path/stem names**, so the STT_FILE symbol is constant across the pair; this leak
cannot flip them. It only shows up when comparing two builds of the same source to **different**
`-o` names.

## Recommendation

Functionally this is a **documented-expectation candidate**: determinism contract = "same source
+ same flags + same output name ⇒ byte-identical binary" — which holds, cold and warm. If
name-independent byte-equality is wanted (so `-o a` and `-o b` differ in 0 bytes), two cheap
fixes, either sufficient:
1. Name the artifact by a content hash of the source (or a fixed stem per source path) instead of
   the `-o` stem at `self/main.hexa:3441`; or
2. Discard local symbols at link (`-Wl,-x`) or strip `.symtab`/`.strtab` post-link (STT_FILE is
   in a non-allocated section; runtime behavior unchanged).

For the w7 ownlint e2e: compare phase pairs at the **same `-o` path** (build, `cp` aside,
rebuild) — the phase2 control DIFF disappears.
