All four censuses are in. Here is the endgame design, synthesized from the actual tree at `11d9cbb51` (verified first; the stale main working dir was never read).

One correction to the request's premise before the plan, because it changes the DAG: **the own backend + hexa_ld chain is proven, but narrower than assumed.** `hexa_ld` links **Mach-O arm64 only** (`tool/hexa_ld.hexa:268` rejects non-ARM64), and the linux `--emit=obj` path auto-selects the native object writer only for arm64-darwin and arm64-linux (`compiler/main.hexa:508-520`) — a bare `--emit=obj --target=x86_64-linux-gnu` (exactly what `hexa run` leg-B invokes at `self/main.hexa:4525`) still forks system `as` (`compiler/main.hexa:1075`), and the final link is binutils `ld` + glibc crt1.o (`self/main.hexa:4542-4552`), not hexa_ld. `--linker=hexa` is an unwired stub that warns and falls back (`compiler/main.hexa:1151-1152`). The genuinely zero-clang/zero-ld path that exists today is the darwin-arm64 gen3+hexa_ld+rt.o promoted slot (`tool/hx-selfhost-cli:120-148`, locked by `selfhost-native-build-gate.yml`).

---

# ① No `hexa_cc.c` — steady-state elimination of the C-transpile delegate

## Current residual

**The dispatch.** Default `hexa build` resolves hexat (the hexa_cc.c-built transpiler) unconditionally before any backend decision (`self/main.hexa:3135-3138`), and the only fork is one opt-in env var — `HEXA_BACKEND=native` at `self/main.hexa:3264-3265`; unset means the C-transpile at `:3577-3579` → clang compile+link at `:3764`. The native branch itself refuses `--target`/`--c-only` (`:3272-3281`) and its stage 2 is **still clang** — it assembles aprime's `.s` and links `runtime.c` as a second TU (`:3504-3506`). `hexa run` is better: leg-B native is **default-ON** (r26 flip) but host-gated to `Linux x86_64` only (`:4495-4496`), with every failure and every other host falling back to an inner `hexa build` subprocess (`:4566-4593`) — i.e. back to hexat. The internal `cmd_run` used by all absorbed subcommands (verify/test/atlas, call sites `:7271-8289`) has **no native route at all** (`:4693`). The release pipeline regenerates and clang-compiles hexa_cc.c by default (`tool/release_build:89` `HEXA_SEED_CONVERGE=1`, `tool/stage_prebuild_hexat`, `tool/stage_build_hexa:220`).

**Actual remaining codegen gaps** (the memory-note "native-run codegen wall" is mostly stale — try/catch, closures, multi-fn-alias, and the x86_64 string-print residual are all verified closed or falsified in-tree, per `state/hexa-own/no_runtime_c_no_cc_verdict.md` §4):
- **HX1102** match-pattern shapes beyond {wildcard, ident, enum_path, literal_int, literal_string, struct_pattern} (`compiler/lower/hir_to_mir.hexa:4317`, catalog `compiler/diag/catalog.hexa:160-165`)
- **HX1103** unknown HExpr kinds (`hir_to_mir.hexa:4847`)
- the **@lazy** niche (loud self-fail → fallback, `self/main.hexa:4479-4484`)
- **13 native-crash-where-clang-works** (the gen3-codegen-SIGSEGV class) — the correctness debt the fallback does *not* catch
- host coverage: the emit hardcodes `--target=x86_64-linux-gnu` (`:4525`)

## Rounds

| # | Lever | Gate | Wall-class |
|---|---|---|---|
| ①-R1 | Drain HX1102/HX1103/@lazy lowering (byte-neutral to C path) | delegate-fallback rate → 0 on flip corpus (`HEXA_RUN_NATIVE_TRACE=1` telemetry) + miscompile-zero-gate | **Under-invested** — every prior gap in this lane (r8–r27) fell |
| ①-R2 | Drain the 13-crash census | census = 0 + selftest + miscompile-zero-gate | Under-invested (correctness debt, and the true trust-gate for any default flip) |
| ①-R3 | arm64-linux run-native: de-hardcode triple/crt at `:4496/:4525/:4542`; triple = `arm64-linux-gnu` (`compiler/main.hexa:147/984`, NOT aarch64-) | arm64 pool smoke + byteeq; loud-fail-to-clang kept | Under-invested — fully scoped in `state/hexa-own/flip7_flipd_arm64_regex_rescope_plans.md` motion 2; real risk = arm64 emitter unproven on real programs |
| ①-R4 | darwin native build/run: promote the `hx-selfhost-cli` gen3+hexa_ld+rt.o surface into `cmd_build`/`cmd_run_user_direct` proper | selfhost-native-build-gate + parity gate + shipping smoke | Under-invested — the zero-clang path is CI-proven; only the wire into main.hexa is missing |
| ①-R5 | Internal `cmd_run` (`:4693`) native route | verify/test corpora green on both routes | Mechanical |
| ①-R6 | `cmd_build` default flip per proven host + kill the native branch's clang stage-2 (`:3504`) → `--emit=obj` + hexa_ld/native link (joint with ③-R3) | byteeq 3-target + shipping smoke + install smoke | Flip round, gated on R1–R4 |
| ①-R7 | Release-pipeline hexat retirement: flip `HEXA_BOOTSTRAP_NATIVE_SEED` (opt-in bypass already exists, `tool/stage_build_hexa:124-216`) to default; remove `HEXA_SEED_CONVERGE` regen from `release_build:89` | release 3/3 + redefined bootstrap gate | Terminal round; needs ② done for the runtime side |

## Honest terminal for ①

**Steady-state ∅ is reachable** — nothing measured blocks it; the walls of record were falsified. The one true floor is **from-nothing bootstrap**: `hexa_cc.c` is definitionally unportable (`self/native/hexa_cc.c.hexanoport` — "it IS the output of porting"). A self-hosting compiler cannot cold-start from pure source without either a prior `hexa` binary or a C detour. The honest DONE shape is the **Go model**: every release builds from the prior release's native binary; the frozen blob `151c52c8` (`tool/restore_frozen_seeds:41,64`) survives only as an archaeological from-nothing escape hatch, never compiled on any shipped path. If your criterion includes "from nothing, no prior binary," that is information-theoretically a wall — name it BOOTSTRAP-FLOOR and accept the prior-binary seed; otherwise ① = ∅.

---

# ② No `runtime.c` — eliminate the emitted-C compile step

## Current residual

The substrate is regenerated hexat-free by awk un-escape of `self/runtime_emit_full.hexa` (16.8k lines of C-text literals; `tool/stage_resolve_runtime_a:83-111`, `tool/restore_frozen_seeds:109-164`) and compiled by `$CC` at `stage_resolve_runtime_a:3064/:3069/:3082` (MULTIOBJ S2–S4) or `:3152` (single-TU), plus the consumer-side cache compile at `self/main.hexa:3730` and install.sh's pre-warm (`install.sh:612-644`). Sibling generated TUs: `runtime_core.c`, `runtime_core_hxlcl_shim.c`, `runtime_ffi_dyn.c`, `_hxlcl_errno_provider.c`, cuda glue (nvcc). Also inside this axis: the `.s` seed floor — ~19 seed families in `self/native/` are assembled by `$CC -c seed.s` (dozens of call sites in stage_resolve_runtime_a).

**Critical reconciliation — two axes hide under "no runtime.c," and the tree already says so** (`state/hexa-own/no_runtime_c_no_cc_verdict.md`): (A) no tracked `.c` = ✅ MET (#4352/#4356); (B) no emitted-C *compile step* = ❌, recorded as "substrate-walled … mark terminal, not chased." **Your criterion is axis B, and I dispute the "terminal" classification** — see the rounds: the SELFEMIT mechanism that dissolves it already runs in CI.

**The nm-UND floor is a different axis and does NOT collide with your criterion.** Current CI floor: 231 total / 54 reducible (honest-libc ~51); the all-levers-ON floor measured exactly the 15-symbol sanctioned WALL set (`state/zeroc-flip-measure-2026-07-03.txt`; ARCHITECTURE.json:428). Sanctioned families (SSOT `state/zeroc-29-floor-to-zero-endgame-ssot-2026-07-03.md:136-155`): net-FFI (~11-15 syms, a DNS resolver you'd have to *write*, not port), CRT (`__libc_start_main` etc.), exec-family, CUDA opt-in. **These are link-time symbol binds, not C-compile steps** — runtime.a can reference `connect`/`execve` as UNDs forever while zero generated `.c` is compiled. Eliminating runtime.c ≠ eliminating libc.

Remaining nm-floor work (housekeeping, not the ② spine): FLIP-7 environ+atexit is **one bit-changing PR from default-ON** — #4652 landed the last byte-neutral prereq (the main.hexa `_start` nm probe); FLIP-6 free/calloc merged-OFF (blockers: resolver no-binary FATAL at `stage_resolve_runtime_a:1904-1906` + x86_64-only Route-C fp-ABI else-arm at `:1930`); strcmp non-shim-caller residual; strtod drop reconverge. (Note: I found no in-tree `#4651` — the strtod-tail flip of record is #4639/#4645/#4646 with default-ON at `stage_resolve_runtime_a:707`.)

## Rounds

| # | Lever | Gate | Wall-class |
|---|---|---|---|
| ②-R0 | FLIP-7 flip-D default-ON (`:-0`→`:-1` at the six gate sites + 2 shell Linux guards + predicate inverts) | faithful + install-smoke; darwin `__aarch64__` guard asymmetry handled | Teed up — in flight |
| ②-R1 | nm-floor mop-up: strcmp caller, strtod drop, FLIP-6 (after resolver hardening) | faithful nm-drop + byteeq 3-target | Under-invested; finishes the reducible-symbol axis |
| ②-R2 | **`.s`-seed → SELFEMIT graduation**: replace each `$CC -c seed.s` member with compiler `--emit=obj` direct `.o` — the mechanism is proven: 72 `emit_hxlcl_*_o.hexa` fixtures exist and **21/55 are already wired as native self-emitted runtime.a members on the darwin ladder** (`nobaseline-gate.yml:516-521`). Per-member default-OFF lever → flip | runtime.a member byte-compare + byteeq 3-target | **Under-invested, not a wall** — this directly falsifies the recorded ".s-assembler floor" |
| ②-R3 | C-fragment → `.hexa` port, **arm64 first**: runtime bodies (array/map/str/HexaVal core from `runtime_core_emit.hexa`) rewritten as `.hexa` compiled by the own backend. arm64 already carries the HexaVal pair via `_hv_load/_hv_store`, so it has no value-model blocker | gen3≡gen4 byteeq + full selftest, per-family | Large engineering, per-family rounds; no measured wall on arm64 |
| ②-R4 | **x86_64 value-model rearch** — `F-RT-NATIVE-X86-CODEGEN-ROOTCAUSE`: the x86_64 backend's raw 1-register int model drops `rdx`/payload on returned HexaVal `{tag,payload}` → SIGSEGV (`compiler/codegen/x86_64_linux.hexa:609-682`); recorded "multi-week value-model rearch, not a targeted patch" | staged: pair-carry on returns → stores → full regalloc; byteeq at each rung | **The critical-path wall of the whole plan** — hard but not irreducible (arm64 is the existence proof) |
| ②-R5 | Remaining fragment TUs (ffi_dyn, hxlcl_shim, errno provider) via Route-C/self-emit; sanctioned UNDs emitted as native extern refs | nm-UND unchanged + byteeq | Mechanical once R2–R4 land |

## Honest terminal for ②

**∅ (no generated .c compiled anywhere) is reachable**, contra the in-tree "substrate-walled/terminal" verdict — that verdict predates weighing SELFEMIT graduation as the escape. But it runs through two named mountains: ②-R4 (the x86_64 pair-carry rearch — the single place your criterion meets a genuinely measured hard wall, `x86_64_linux.hexa:609-682`) and the sheer volume of ②-R3. What is **not** required: porting the sanctioned nm-UND families — net/CRT/exec/CUDA stay as link-time libc binds and never violate "no runtime.c". One re-measure flag: the setjmp Route-C jmp_buf-layout wall (`F-RT-NATIVE-SETJMP-ROUTEC-WALL`, `x86_64_linux.hexa:5254`) was recorded TERMINAL, but codegen now emits a native musl-matched `hxlcl_setjmp` with the all-spill fix (`:5436-5442`, `:593-602`) and `HEXA_SEED_CONVERGE=1` closed the seed mismatch — re-measure before treating it as blocking ②-R3's try/catch runtime port.

---

# ③ No clang — neither to build nor to use `hexa`

## Current residual

Two halves with different depths:

**(a) Consumer half — "use hexa with no C compiler."** Today `hexa build hello.hexa` on a no-cc box is fatal: `host_cc()` (`self/main.hexa:1330-1351`) errors on linux (`:1349`) or blind-defaults to `clang` on darwin (`:1346-1347`), because the C path's compile+link is one clang invocation (`:3764`) and even `HEXA_BACKEND=native` re-enters clang at `:3504`. `install.sh` clang-rebuilds runtime.a (`:562-565`, non-fatal), then **fatally** clang-builds module_loader (`:597-607`) and clang-prewarms the cache (`:612-644`). The only clang-free consumer flow today: `hexa run` on linux-x86_64 with shipped `build/aprime_cc` + `build/runtime.a` + binutils `ld` (measured "zero clang execve", `:4466-4467`) — but it still needs binutils ld + glibc crt1.o, and system `as` inside the emit (no native backend auto-flip for x86_64, `compiler/main.hexa:508-520`).

**(b) Producer half — "build hexa with no C compiler."** Everything bootstraps through clang: hexat (`stage_prebuild_hexat:185`), the `hexa` dispatcher itself (`stage_build_hexa:213-220`), aprime_cc (`build_aprime.sh:806`), gen2/gen3's rt.o (`build_selfhost.sh:199-201`), and **hexa_ld itself is clang-built** (`build_selfhost.sh:245-247`). runtime.a members = `$CC` throughout (axis ②).

**Non-cc external forks that are NOT clang and need explicit sanctioning:** system `as` (dissolves via ③-R1), binutils `ld` (dissolves via ③-R2), darwin `codesign` (`hexa_ld.hexa:2378-2392` — documented as "OS Gatekeeper requirement, not a toolchain dependency"), dyld/libSystem at load (darwin mandatory — the dlopen doc already excludes darwin from the ∅ axis), `zig cc` for `--target` cross (`:3787`), nvcc (CUDA opt-in axis).

## Rounds

| # | Lever | Gate | Wall-class |
|---|---|---|---|
| ③-R1 | x86_64-linux native-backend auto-flip: add the missing `backend_kind = "native"` arm for `x86_64-linux-gnu --emit=obj` (`elf_x86_64.hexa` writer exists, `compiler/main.hexa:1006-1015`) — kills system `as` on leg-B | emitted-.o equivalence vs as-route + leg-B corpus | Under-invested — emitter exists, one dispatch arm missing |
| ③-R2 | **hexa_ld ELF**: extend past the ARM64-Mach-O check (`hexa_ld.hexa:268`) to ELF64 x86_64/aarch64. Static-first (FLIP-7 own-`_start` ⇒ no crt1.o, no ld-linux), dynamic (PLT/GOT + DT_NEEDED libc for sanctioned UNDs) second | linux gen3-chain self-link byteeq + extend selfhost-native-build-gate to linux | New engineering, no recorded wall; reference-match a minimal mold/lld subset |
| ③-R3 | Consumer link swap: `:3764/:3504/:4552` → own-emit + hexa_ld; runtime arrives prebuilt via the existing `HEXA_PREBUILT_RUNTIME` seam (`:1673-1697`) — **note this structurally bypasses ② for the consumer**: shipping per-target runtime.a assets removes the consumer's runtime.c compile without porting anything | byteeq 3-target + install-smoke on a no-cc container (`HEXA_ASSUME_NO_CC=1` forcing hook, `:4401`) | Flip round; joint with ①-R6 |
| ③-R4 | install.sh no-cc: ship per-target runtime.a (already mirrored to `$HX_BIN/build/`), module_loader + prewarm via native path, demote `host_cc()` to optional | install.sh smoke on an image with no clang/CLT | Mechanical after R3 |
| ③-R5 | Producer half: build hexa/gen3/hexa_ld via prior-release native binary (with ①-R7); runtime.a via ② SELFEMIT; retire `zig cc` cross in favor of own per-target emitters + per-target prebuilt runtime.a | release 3/3 + consumer smoke | Terminal; strictly after ②-terminal + ①-R7 |

## Honest terminal for ③

**Reachable**, with an explicitly sanctioned non-cc residue that does not violate the criterion as stated: darwin `codesign` fork and dyld/libSystem (OS interface, not a compiler), glibc `ld-linux` only in dynamic mode (own-static + own-`_start` avoids it), nvcc only inside the opt-in CUDA axis. The consumer half is much closer than it looks — darwin-arm64 is already CI-proven zero-clang/zero-system-ld; linux needs exactly ③-R1 + ③-R2 + FLIP-7.

---

# The cross-axis DAG

```
                ┌──────────────────────── independent, start now ────────────────────────┐
                │                                                                        │
   B: FLIP-7 flip-D (②-R0, teed)     ③-R1 x86 backend auto-flip     ②-R2 SELFEMIT .s→.o (rolling)
                │                             │                                          │
   A: ①-R1/R2 codegen-gap+crash drain     C: ③-R2 hexa_ld ELF        D: ②-R4 x86 value-model rearch
                │                             │                                          │
                └────────────┬────────────────┘                                          │
                             ▼                                                           │
        ③-R3/①-R6  consumer emit+link swap + build/run native default                    │
        (needs A + B + C + ③-R1; darwin leg needs only A + ①-R4 wire)                    │
                             │                                                           │
                             ▼                                                           ▼
        ①-R3/R5 host+internal coverage          ②-R3 runtime .hexa port (arm64 first; x86 after D)
                             │                                                           │
                             └────────────────────────┬──────────────────────────────────┘
                                                      ▼
                     ①-R7 + ③-R5  producer terminal: hexat retired, release builds clang-free
```

**Ordering answers to your specific question:** ② does **not** wholly precede ③ — the consumer half of ③ is unblocked *structurally* by shipping prebuilt runtime.a (the seam exists), so no-clang-to-USE-hexa lands long before runtime.c is gone. Only the **producer** terminal (③-R5, no clang to *build* hexa) requires ② complete. ① and ③-consumer share one spine (native emit + hexa_ld link) and should land as one flip. The two long poles you can start immediately in parallel: **C (hexa_ld ELF)** and **D (x86_64 value-model rearch)** — D is the plan's critical path.

# Where your criterion meets prior measured walls — the exact collision list

1. **① BOOTSTRAP-FLOOR (genuine, permanent):** from-nothing cold start without a prior hexa binary requires hexa_cc.c + a C compiler — same wall as Rust/Go. Resolve by *definition* (prior-release binary seed = Go model), not by engineering. Everything steady-state reaches ∅.
2. **② x86_64 HexaVal pair-carry (`F-RT-NATIVE-X86-CODEGEN-ROOTCAUSE`, `x86_64_linux.hexa:609-682`):** the one measured hard wall on your critical path — recorded multi-week rearch, but arm64 proves it's architecture work, not an irreducible. Do not start ②-R3 on x86_64 before it.
3. **② "substrate-walled" verdict (`no_runtime_c_no_cc_verdict.md` §5):** I recommend overturning it — the SELFEMIT ladder (21/55 members already native-.o in CI) is the escape that verdict didn't weigh. The `.s`-assembler floor is under-invested, not terminal.
4. **Sanctioned nm-UND floor (net/CRT/exec/CUDA):** **no collision.** Your ①②③ criterion is about compile *steps*, not link-time *symbols*; the 15-U floor persists harmlessly as libc binds (dynamic) and shrinks to raw-svc only if you later choose a static-purity campaign — out of scope for DONE.
5. **setjmp Route-C wall (recorded TERMINAL):** likely stale — native musl `hxlcl_setjmp` + all-spill + seed-converge landed since. Re-measure before treating it as a ②-R3 blocker.
6. **Darwin residue (`codesign`, dyld/libSystem):** not a C compiler — sanction it explicitly in the DONE definition, or darwin can never satisfy a literal "no external forks" reading (the dlopen doc already excludes darwin from the ∅ axis for exactly this reason).