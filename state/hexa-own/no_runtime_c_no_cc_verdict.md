Verified live: `git ls-files self/**/*.c` == 0, and none of runtime.c / runtime_core.c / hexa_cc.c / hxlcl_shim.c / runtime_hi_gen.c are tracked. Plan below.

---

# Elimination Plan — "no runtime.c and no hexa_cc.c"

## 1. Honest current status — read this first

**Two axes hide under one target. Keep them separate or you will re-open a solved problem.**

| Axis | State | Authority |
|---|---|---|
| **A. No tracked `.c`** (`git ls-files self/**/*.c == ∅`) | ✅ **MET** (reached 2026-07-02; re-verified this session = 0 rows) | emitter-graduation #4352 (timegm 3→2) + #4356 (cuda 2→0) + hxlcl_shim (`.gitignore:238`); gated by `selfhost-codegen-guard.yml` |
| **B. No emitted-C *compile step* in the build** | ❌ **NOT met — and substrate-walled** | `stage_resolve_runtime_a:2663` (`$CC -c runtime.c → runtime.o` + `ar rcs`), `stage_prebuild_hexat:10-12` (`clang hexa_cc.c → hexat`), `.s` seeds via `$CC -c seed.s` |

**Plain statement:** The *file-tracking* goal is done — `runtime.c`, `runtime_core.c`, `hxlcl_shim.c` are gitignored regen artifacts synthesized byte-for-byte from the tracked `.hexa` C-text emitters (real `.hexa` SSOT via `_unescape_emit_to_c`), and `hexa_cc.c` is an untracked, per-run-regenerated boot image whose SSOT is the 4 `.hexa` compiler modules. This mirrors GCC's `gen*.c → insn-*.c`: the generator is source, the generated `.c` is a build artifact.

But a **real, live C-compile dependency remains**: `build/runtime.a` must be C-compiled from `runtime.c`, `build/hexat` must be C-compiled from `hexa_cc.c`, and `.s` seeds still need `$CC` as assembler. That compiled substrate — the freestanding `runtime.a` that every native-emitted binary links against, plus the CRT `__libc_start_main` bootstrap — is the **irreducible floor** (M8 #3959). Every self-hosted toolchain (Go, Rust) keeps exactly this. It is the honest-keep `c9` substrate, **not** a no-LLVM violation.

**Verdict up front: the meaningful target is already met in spirit. Axis B cannot reach ∅ — it is a measured substrate wall, a valid terminal, not a failure.**

---

## 2. Mechanism-landable-now (byte-neutral · mini authors · CI-verified)

**EMPTY.** No filler.

Axis A is already GREEN and gated. Nothing byte-neutral advances it. Every remaining motion (arm64 native cold-path, standalone-#else ABI redesign) is **bit-changing** and requires pool byteeq — so it belongs in §3, not here. Mini is git/gh/read-only; it cannot author the value-model or triple-derivation work locally with a byte-neutral guarantee.

---

## 3. Pool / CI-gated (bit-changing → dispatch aiden/summer, qemu arm64)

Ordered by leverage. These **shrink** the C surface or **extend** the delegate-off flip; **none eliminates the compiled `runtime.a` floor.**

### 3.1 — arm64-linux native cold-path flip (highest real motion)
Extend the already-landed x86_64-linux r26 delegate-off flip (#3782/#3783) to arm64-linux. Today the native `--emit=obj → ld` block is host-gated to `"Linux x86_64"` only (`self/main.hexa:4423-4424`); every other host falls to the clang / `hexa_cc.c` C-transpile delegate (`self/main.hexa:4487`). The 24-min darwin "wall" (#4483) is **not** irreducible — it is the symptom of an x86_64-hardcoded emit run on the wrong host.

- **Exact first edit:** de-hardcode the triple/crt/dl at `self/main.hexa:4423, 4453, 4463-4464` — derive `target + crt-dir + dynamic-linker` from `uname -sm` (first rung: `aarch64-linux-gnu` + `/usr/lib/aarch64-linux-gnu/crt1.o` + `/lib/ld-linux-aarch64.so.1`).
- **Rebuild** `aprime_cc` on aiden/summer (qemu arm64).
- **Gate:** byteeq 3-target GREEN **+** clang-hidden cold-run corpus (PATH exit-127 shim + `strace -f execve` = 0 `clang/cc/gcc` execve, rc-correct) — the same proof shape that landed r26.
- **What it buys:** 0 clang execve on arm64-linux cold-run; the `hexa_cc.c` delegate then fires only for genuine native-emit-fail programs (closure/@lazy niche), which loudly self-fail. Darwin follows **only after** `tool/hexa_ld.hexa` (Mach-O) is built + wired.

### 3.2 — standalone `#else` ABI redesign (ING #14-16) — C-LOC shrink, not elimination
`stage_resolve_runtime_a:271` compiles `runtime.c`/`runtime_core.c` with **no** `-DHEXA_HAS_HEXA_RT_STDLIB`, so the standalone `#else` C-bodies define 33 `rt_*` symbols into `runtime.a` — **LIVE + PRIMARY**, consumed by every release/byteeq/determinism gate (verdict `F-LEGB-STANDALONE-ELSE-NOGO`, ARCHITECTURE:1031-1091). Deleting the `#else` today bricks the live `./hexa` link.

- **Scope (multi-session, per `F-LEG-B-STANDALONE-SCOPE`):** ① port ~1190 core fns to hexa-native (portability is *proven real* — 155/308 `runtime_core.c` fns call no libc/libm/svc; `hexa_fnv1a` byte-identical `.hexa` port), ② standalone-build ABI redesign so `stage_resolve_runtime_a:271` links hexa-source `rt_*.o` with HexaVal↔float wrappers, then the `#else` bodies can be deleted.
- **Gate:** byteeq 3-target GREEN + shipping smoke.
- **Honest caveat (`c9`, ARCHITECTURE:1265):** this shrinks the substrate's C-LOC. **A compiled `runtime.a` still remains** as the bootstrap floor. Do not sell this as elimination.

---

## 4. Substrate-wall / irreducible / falsified-dead-path — DO NOT CHASE

Honest terminals with cited walls:

- **Compiled `runtime.a` substrate + CRT bootstrap** — `runtime.a` must exist for native binaries to link against; `__libc_start_main` is the irreducible seed. Wall: **M8 #3959** (`project_hexa_m8_irreducible_floor`), verdict `F-LEGB-STANDALONE-ELSE-NOGO`. This is the honest ∅ endgame = sanctioned-floor {net-FFI · CRT-startup · exec} + CUDA-opt-in (`project_hexa_zeroc_floor_goal_state`, #4482), **never literal ∅**.

- **HexaVal x86_64 pair-carry** — x86_64 backend uses a raw 1-register int value-model; a returned HexaVal `{tag,payload}` drops `rdx`/payload at store → SIGSEGV in `hexa_array_push`. Wall: `F-RT-NATIVE-X86-CODEGEN-ROOTCAUSE`, `x86_64_linux.hexa:609-682` — multi-week value-model rearch, **not** a targeted patch. (arm64 already carries the pair via `_hv_load/_hv_store`, Z2a byte-identical.)

- **setjmp/longjmp jmp_buf layout** — inline glibc `call setjmp` 200B save (`x86_64_linux.hexa:5254`) vs `hxlcl_longjmp` restore mismatch. Wall: `F-RT-NATIVE-SETJMP-ROUTEC-WALL` (2026-06-30). Precise irreducible core = NaN-boxing tags + arena + setjmp/longjmp (`F-ZEROC-RUNTIME-PORT-BOUNDARY`).

- **`.s`-assembly floor** — RT-NATIVE `.s` seeds are assembled via `$CC -c seed.s`; even a PATH-cc-removed build cannot reach ∅ here.

- **`hexa_cc.c` un-portability** — it **IS** the transpile output (`self/native/hexa_cc.c.hexanoport`: "Cannot be ported to .hexa (it IS the output of porting)"). "Never emit C for the boot image" is not a reference-matched mechanism — it is the substrate.

**Falsified / already-closed — do NOT re-derive:**
- N5 selfhost fixpoint (cc-gen3≡cc-gen4, sha `ece49087…`) = **already met**; the claimed "x86_64 string-print HexaVal residual" is **falsified-as-broken** by #3420 (`F-X86-RUNG2-VERIFIED`, stdout `[hello x86_64 RUNG2]` exit=7 PASS). Do not re-open.
- `hexa run` native-route #3325 clang-gap = **CLOSED/LANDED**, not a dead path — resolved by leg-B r27 #3783 (ships `aprime_cc`) + #3766 (no-cc auto-engage). The v0.262.0 revert was "aprime_cc not shipped," now fixed.
- native-run codegen wall r8–r27 (try/catch, "match", multi-fn-alias) = **falsified-as-wall**, driven to default-ON (#3782 flip, #3783 consumer-live, ING #79 DONE). Do not re-run the ladder.
- M3 "runtime_core.c irreducible / zero portable surface" = **overclaim falsified** (`F-ZEROC-M3-OVERCLAIM-FALSIFIED`): 50% portability is real — but literal-∅ still hits the §4 substrate walls.

*(Residual native-run correctness risk that the delegate-fallback does NOT catch: the gen3-codegen-SIGSEGV class — 13 native-crash-where-clang-works in the run-clang-gap census. That is a separate correctness axis, not a C-elimination axis, and the real next wall for trusting native-run beyond the flip corpus.)*

---

## 5. Single highest-leverage next action

**Honest verdict: the file-metric target (`git ls-files self/**/*.c == ∅`) is MET and gated; "no compiled-C in the build" is a measured substrate wall (M8 #3959 + HexaVal-x86_64 + setjmp + `.s`-assembly) and is a valid terminal, not a task.**

The one axis with remaining *measurable* motion is **§3.1 — the arm64-linux native cold-path flip**: on aiden/summer (qemu arm64), generalize `self/main.hexa:4423/4453/4463-4464` to derive `triple+crt-dir+dynamic-linker` from `uname -sm`, rebuild `aprime_cc`, and prove the native `--emit=obj`+ld path engages with **0 clang execve** via the clang-hidden cold-run corpus + byteeq-3-target.

**What the user actually gains:** it extends the r26 x86_64-linux delegate-off flip to a second host class, removing the `hexa_cc.c`/clang delegate from the arm64-linux cold path (so the C-transpile delegate fires only on genuine, loud native-emit-fail programs). **What it does NOT do:** eliminate the compiled `runtime.a` — that is the bootstrap floor every self-hosted toolchain keeps. If the user's goal was "no *tracked* C," stop now: it is done. If the goal is "one fewer host running the C delegate," §3.1 is the action. If the goal is "zero compiled C in the build," the honest answer is that it is substrate-walled and should be marked terminal, not chased.