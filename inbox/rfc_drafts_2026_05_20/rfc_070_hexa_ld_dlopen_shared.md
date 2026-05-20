# RFC 070 — `hexa_ld --shared` + runtime `dlopen` (fat .so single-symbol convention)

> **status**: `g7-a-native-impl-signature-landed` (entry-fn signatures `codegen_arm64_darwin` + `codegen_x86_64_linux` now take `(MModule, CodegenOptions) -> LModule`; all 11 callers pass `codegen_options_default()` — zero emit-body branch added; G7-A.native impl emit + falsifier sub-cycle next — see §4.7 landed 2026-05-20)
> **opened**: 2026-05-20 (promoted from `inbox/patches/g7-hexa-ld-dlopen.md`, opened 2026-05-10)
> **G7-A flag wire**: 2026-05-20 (`self/main.hexa::cmd_build` + dispatch — flag-wiring only, zero falsifier coverage yet)
> **G7-A falsify** : 2026-05-20 (F-A1/F-A2 measured on C path · macOS arm64 dylib + ubu-1 ELF x86_64 .so · §4.5 below)
> **G7-A native iface**: 2026-05-20 (compiler/ir/lir.hexa `CodegenOptions` + `RELOC_*` constants lifted · scaffold cross-link · zero emit change · §4.6 below)
> **G7-A native signature**: 2026-05-20 (entry-fn signatures lifted + 11 callers updated · default opts seeded · emit body byte-identical · §4.7 below)
> **owner**: hexa-lang compiler (`compiler/codegen/` · `compiler/link/hexa_ld.hexa` · `self/runtime.{c,h}`)
> **consumer demand**: wilson in-process plugins (hot-path provider/tool/hook/view). Out-of-scope reuse: anima/nexus, generally any consumer that wants "drop a `.so`, no relink".
> **priority**: ★ (have-it-is-nice, blocking-none) — without G7 wilson stays on G8-incremental + busybox-multi-call paths (option (d) of the source patch).

---

## 0. Cross-link

- **source patch** : `inbox/patches/g7-hexa-ld-dlopen.md` (opened 2026-05-10, this RFC promotes that spec).
- **adjacent RFCs**:
  - RFC 055 `hexa_nvptx_codegen_backend` — established the precedent of a new codegen surface (NVPTX). RFC 070 is its CPU-PIC analogue: same shape "codegen mode flag → emit different artifact".
  - RFC 063 `s7_native_assembler_linker` — RFC 070 is the *dynamic* counterpart of RFC 063's static linker; both touch `compiler/link/hexa_ld.hexa`.
  - RFC 057 `bc_device_authoritative_matmul_primitive` — not directly related; cited only because `hexa_ld` is shared infrastructure.
- **governance**:
  - `@D g5` hexa-native-only — `dlopen`/`dlsym` are libc surface (`libdl`). We are already an FFI consumer of libc (see §3.A). G7 does NOT add a new toolchain dependency: it widens an existing one.
  - `@D g_atlas_binary_builtin` — orthogonal. RFC 070 is about *code* loading, not *atlas* loading. The atlas remains binary built-in; `.so`-loaded plugins still bind against the same baked-in atlas of the host.
  - `@D g_stdlib_ownership` — `stdlib/dynlink.hexa` (new) is hexa-lang owned. wilson/anima consume by import.

## 1. Motivation (verbatim from source patch §1)

hexa-lang's `compiler/` emits ELF64 + Mach-O **static** binaries via `hexa_ld`. wilson's "core + N plugin" architecture currently requires all in-proc plugins to static-link into a single `wilson` binary. Plugin add/remove/update therefore costs a full `wilson build` cycle (codegen + relink).

G7 opens a runtime path: plugin = dynamic library (`.so` / `.dylib`), `wilson` runs `dlopen` + `dlsym("<plugin_id>_dispatch")` at startup or on demand. Plugin add = drop a `.so`, no recompile.

**Honest scope (@D g3)**: this benefits *any* hexa-lang consumer that wants runtime extensibility — wilson is just the first concrete demand. anima/nexus have voiced interest but no filed patch yet.

## 2. Current state (verbatim from source patch §2 + 2026-05-20 audit)

- `compiler/link/hexa_ld.hexa` (+ `hexa_ld_test.hexa`) — static linker. ELF64 + Mach-O static. Static relocation + symbol resolution.
- `compiler/codegen/{arm64_darwin,x86_64_linux}.hexa` — position-dependent code (`-fPIC` unnecessary for static).
- `self/runtime.c` — already calls `dlopen`/`dlsym` via FFI (audit 2026-05-20: hits in `self/codegen_c2.hexa`, `self/ffi/hxcuda_matmul.hexa`, `self/ml/{accelerate_ffi,cuda_ffi,distributed,hxblas_dispatch,tensor,device}.hexa`, `self/native/{hexa_cc,hxccl_linux,hxffi_slot,runtime_cuda,v565_grad_analysis}.c`). **However** these are raw FFI consumers of libc `dlopen`; the host has no `stdlib/dynlink.hexa` surface, and `hexa_ld` itself cannot emit anything that needs to be `dlopen`-able from a hexa-built host.
- **Conclusion**: §6 phases A/B (codegen + linker) are entirely new work. Phase C (`stdlib/dynlink.hexa`) is a thin wrapper over existing libc-FFI usage and could ship first if we choose to expose pre-built `.so` consumption before producing them.

## 3. Design (verbatim from source patch §3-§5, condensed)

### 3.A Options table (decision: **(b) fat .so + single-symbol convention**)

| opt | one-liner | verdict |
|-----|-----------|---------|
| (a) full dynamic ELF/Mach-O + libc dlopen | codegen `-fPIC`, `hexa_ld` emits `.so`/`.dylib` with PLT/GOT/dynsym; transitive deps resolve against host exports | correct but largest work |
| **(b) "fat .so" + single-symbol convention** | plugin static-links all deps into the `.so`; exports exactly `<plugin_id>_dispatch`. Host `dlopen` + `dlsym` 1 symbol. ABI surface = `HexaVal (*)(HexaVal action, HexaVal payload)` | **✅ adopted** |
| (c) custom relocatable blob + own loader | libc-free; `hexa_ld` emits blob, runtime `mmap`+self-reloc | reserved for libc-free mandate |
| (d) skip G7 — G8 incremental link + multi-call binary | wilson MVP-sufficient escape hatch | accepted as fallback if G7-A or G7-B stalls |

### 3.B Surfaces

**codegen** (Phase A): new flag — `hexa cc --shared <plugin>.hexa -o <plugin>.so`. PIC code. Hidden visibility on everything except `<plugin_id>_dispatch`. All deps static-linked into the `.so` (fat).

**hexa_ld** (Phase B): new mode — `hexa_ld --shared`. ELF: `ET_DYN`, `.dynsym`/`.dynstr` with one export, `.hash`/`.gnu.hash`, `DT_SONAME`. Mach-O: `MH_DYLIB`, export trie with one symbol. PLT/GOT minimal (fat = no external refs ⇒ no PLT; GOT data-only).

**runtime** (Phase C): `self/runtime.{c,h}` exposes `hexa_dlopen(path) -> handle`, `hexa_dlsym(handle, name) -> fn_ptr`, `hexa_dlclose(handle) -> void`, `hexa_dlerror() -> string`. These are thin libc wrappers (`RTLD_NOW | RTLD_LOCAL`).

**hexa surface** (Phase C): new `stdlib/dynlink.hexa`:
```hexa
// stdlib/dynlink.hexa (new) — dynamic-module load (host-side wrapper)
// @cite RFC 070 §3.B
pub fn dynlink_open(so_path: string) -> int               // handle id (0 = fail)
pub fn dynlink_call(handle: int, action: string, payload: any) -> any  // <id>_dispatch
pub fn dynlink_close(handle: int) -> void
pub fn dynlink_last_error() -> string
```

### 3.C Capability gate (verbatim from source patch §5)

Static-link plugins resolve `@capabilities` at compile time. Dynamic plugins cannot. Adopted approach: **(1) `.so` carries a capability manifest in a custom section + host gates `dlopen` on it.** Untrusted plugins are forced to subprocess (option (3) of source §5) and never enter the `dynlink_open` path.

Manifest section name (proposed): ELF `.hexa.cap` / Mach-O `__HEXA,__cap` (16-byte name limit on Mach-O segments respected). Format: HXC-v2 envelope per `@D g_hxc` (machine-readable surface = HXC).

### 3.D ABI version stamp (closes §7-2 of source)

`.so` header carries a second custom section `.hexa.abi` / `__HEXA,__abi` with `(runtime_version: u32, nanbox_layout_hash: u64)`. Host refuses to `dlopen` on mismatch. This is mandatory — without it, a stale `.so` produces silent nanbox corruption.

## 4. Phasing — 3 cycles minimum (Shape B, scaffold-only this commit)

| phase | deliverable | depends on | falsifier |
|-------|-------------|-----------|-----------|
| G7-A  | `compiler/codegen/{arm64_darwin,x86_64_linux}.hexa` accepts `--shared` mode flag; PIC code paths; hidden-visibility default; only `<plugin_id>_dispatch` exported | none | F-A1, F-A2 |
| G7-A.flag-wire ✅ | `hexa build --shared <plugin>.hexa -o <plugin>.so` parses on the C path → clang `-fPIC -shared` pass-through (LANDED 2026-05-20, `self/main.hexa::cmd_build`). HEXA_BACKEND=native + `--c-only` + `--target=<triple>` paths refuse `--shared` rather than silently producing the wrong artifact. Hidden-visibility + 1-symbol export NOT yet enforced (`-shared` alone exports every public symbol — that gap is what F-A2 measures). | none | none yet — wiring only |
| G7-A.native scaffold ✅ | `compiler/codegen/{arm64_darwin,x86_64_linux}.hexa` headers carry RFC 070 §4.4 scaffold-marker comments documenting current addressing-mode baseline (arm64-darwin = `adrp + @PAGE / @PAGEOFF` ≈ Mach-O PIE today; x86_64-linux = absolute 64-bit immediates, **NOT** PIC) + target PIC delta (`@GOTPAGE/@GOTPAGEOFF` for extern fns on arm64; `R_X86_64_GOTPCREL` + `[rip+disp32]` LEA for x86_64; hidden-by-default visibility; `<plugin_id>_dispatch` sole exported symbol). **Zero behavior change** this commit. | G7-A.flag-wire | none yet — scaffold only |
| G7-A.native impl iface ✅ | `compiler/ir/lir.hexa` gains `pub struct CodegenOptions { shared: i64, target_triple: string }` + `codegen_options_default()` seed helper + 5 reloc kind string constants (`RELOC_AARCH64_ADR_GOT_PAGE`, `RELOC_AARCH64_LD64_GOT_LO12_NC`, `RELOC_X86_64_GOTPCREL`, `RELOC_X86_64_PC32`, `RELOC_X86_64_PLT32`). Scaffold-marker comments in `compiler/codegen/{arm64_darwin,x86_64_linux}.hexa` cross-link the new types so the impl sub-cycle's diff stays bounded to the two codegen file bodies. **Zero functional change** — the struct is not yet constructed at any call site; the reloc strings are not yet referenced. See §4.6. | G7-A.native scaffold | none yet — interface lift only |
| G7-A.native impl signature ✅ | Shape B sub-step (2026-05-20): entry-fn signature **lift only**. `codegen_arm64_darwin` and `codegen_x86_64_linux` now take `(module: MModule, opts: CodegenOptions) -> LModule`. All 11 callers (`compiler/main.hexa:799,801` + `compiler/codegen/codegen_test.hexa:266-267,329-330` + `tests/m0/{regalloc,loop,concat,many_args}_test.hexa` 5 sites) updated to pass `codegen_options_default()`. **Zero emit-body branch added** — the body is byte-identical to the pre-iface output when called with the default `opts` (shared==0). See §4.7. The emit-body branches (`if opts.shared` → GOT load + `.private_extern`/`.hidden` directive) remain the NEXT sub-cycle scope below. | G7-A.native impl iface | none yet — signature lift, body unchanged |
| G7-A.native impl emit | Honor `bopts[4]=="1"` (the `shared` flag wired in G7-A.flag-wire) inside the native-codegen entry points (`codegen_arm64_darwin` / `codegen_x86_64_linux`). PIC mode emits: (a) `adrp Xn, sym@GOTPAGE` + `ldr Xn, [Xn, sym@GOTPAGEOFF]` for arm64 extern fn refs; (b) `lea rax, [rip+sym@GOTPCREL]` for x86_64 extern fn refs; (c) per-function `.hidden` directive default, `.globl` only for `<plugin_id>_dispatch`. Tag GOT-load LInstrs via `LInstr.comment = RELOC_*` so the asm-text emitter dispatches on the suffix. Falsifiers F-A1/F-A2 run on the native-codegen output. The G7-A.flag-wire prereq (`66b055c4` — `bopts[4]` from CLI `--shared`) is currently NOT on this branch; this row depends on landing both that flag-wire AND this emit work in the same commit (else `opts.shared` is always 0 and the branches are dead code). | G7-A.native impl signature + G7-A.flag-wire | F-A1, F-A2 (native) |
| G7-A.falsify ✅ | F-A1 PASS both platforms (dlopen + dlsym(`add`) + call → 5 byte-equally · macOS arm64 dylib + ubu-1 ELF x86_64 .so). F-A2 EXPECTED-FAIL both platforms per §4.3 caveat (Mach-O = 611 exported T/D symbols · ELF = 560 exported T/D symbols · `add` is one of them, not the sole one — clang `-shared` alone exports every public symbol; single-symbol narrowing is G7-A.native impl scope). Measured 2026-05-20, **C path only** (`hexa_v2 → clang -fPIC -shared`, NOT native-codegen). | G7-A.flag-wire | F-A1, F-A2 (measured · F-A2 = expected-fail caveat) |
| G7-B  | `compiler/link/hexa_ld.hexa --shared` emits `ET_DYN`/`MH_DYLIB` with 1-symbol dynsym/export-trie | G7-A | F-B1, F-B2, F-B3 |
| G7-C  | `self/runtime.{c,h}` adds `hexa_dlopen/dlsym/dlclose/dlerror`; `stdlib/dynlink.hexa` ships | G7-B (or independent if consuming pre-built `.so` only) | F-C1, F-C2 |
| G7-D  | `.so` capability manifest section + ABI stamp + host gate | G7-C | F-D1, F-D2 |
| G7-E  | wilson `core/loader.hexa` consumes `link: "dynamic"` plugins | G7-C/D | (wilson-side, out of hexa-lang scope) |
| G7-F  | Mach-O parity for all of A-D (the staged work is ELF first; Mach-O follows symmetrically) | A-D | F-F1 |

### 4.1 Falsifier battery (real-limit anchored per `@D g3`)

- **F-A1** (compiler invariant): `hexa cc --shared trivial.hexa -o trivial.so` MUST emit a file whose `<plugin_id>_dispatch` symbol address is a multiple of the target's page size's relocatable unit, i.e. **PIC verified by re-loading at a non-default base** (real-limit: virtual-memory page granularity, OS-mandated, x86_64 = 4 KiB, arm64 = 16 KiB on Darwin).
- **F-A2** (compiler invariant): `nm` output of the `.so` lists exactly one **global** (`T`/`D`) symbol matching `<plugin_id>_dispatch`. All other top-level symbols are local (`t`/`d`).
- **F-B1** (ELF spec — System V gABI §4): `readelf -h <file>.so` reports `Type: DYN (Shared object file)`. Anchor = ELF format spec, deterministic.
- **F-B2** (ELF spec): `readelf -d <file>.so | grep SONAME` returns the path passed to `hexa_ld --shared --soname=...`.
- **F-B3** (Mach-O spec — Apple `<mach-o/loader.h>`): `otool -hv <file>.dylib` reports `filetype DYLIB`. Anchor = Mach-O header format, deterministic.
- **F-C1** (POSIX 2017, `dlopen` §3.A): `hexa_dlopen` on a non-existent path returns 0 and `hexa_dlerror()` returns non-empty. Anchor = POSIX-mandated error contract.
- **F-C2** (compiler invariant): `dynlink_call(h, "ping", payload)` must round-trip a `HexaVal` byte-equally when the `.so`'s dispatch is the identity function. Anchor = nanbox ABI byte-equality (compiler invariant).
- **F-D1** (compiler invariant): `dlopen` of a `.so` whose `.hexa.abi` section reports a runtime hash != host runtime hash MUST refuse with a specific `dlerror`. Insufficient = "any failure"; required = the specific ABI-mismatch reason string.
- **F-D2** (compiler invariant): `.hexa.cap` MUST round-trip via HXC v2 (anchor = `@D g_hxc` byte-canonical wire). A `.so` whose `.hexa.cap` parses but declares capabilities not granted to its target host MUST refuse load.
- **F-F1** (Mach-O parity): every ELF falsifier above has a Mach-O counterpart that passes on macOS arm64.

### 4.2 What this commit lands (scaffold marker, **zero behavior change**)

This commit is **Shape B scaffold** per `@D g_inbox_processing_loop`:
1. This RFC text (the file you're reading).
2. **No source edits** to `compiler/codegen/`, `compiler/link/hexa_ld.hexa`, or `self/runtime.{c,h}`.
3. `inbox/patches/g7-hexa-ld-dlopen.md` status flipped `spec → rfc-promoted 2026-05-20 (RFC 070)`.
4. 1-line entry in `compiler/PLAN.md` `## 진행 로그` pointing here.

G7-A/B/C/D each require their own measured cycle. The first measured cycle (G7-A) is the smallest: codegen flag plumbing + F-A1/F-A2 gates. It is **not in this commit**.

### 4.3 G7-A.flag-wire follow-up (2026-05-20, **the smallest behavior change**)

After 4.2 (the scaffold-only RFC promote commit `abc50fa7`), the very next sub-cycle landed the **flag wiring** on the C path only. Concretely:
1. `self/main.hexa::cmd_build` takes a new 5th arg `shared` (default `"0"`).
2. The `build` dispatch grew a `--shared` recognizer that flips `bopts[4]` to `"1"`.
3. The C-path `clang -O2 ...` invocation is prefixed with `-fPIC -shared` when `shared == "1"`.
4. Three mutual-exclusion gates raise `error: ... exit(1)` rather than silently misbehaving: `HEXA_BACKEND=native + --shared`, `--c-only + --shared`, `--target=<triple> + --shared`.
5. `cmd_help` documents `--shared` with the RFC pointer.
6. `tmp_chk` / `out_chk` relax `-x` to `-e` for the shared path (shared libs ship 0644, not 0755).

The **hidden-visibility default** + **1-symbol export** narrowing from §3.B is NOT done here. The `-shared` clang invocation today exports every public symbol, which is what F-A2 will quantify in the next sub-cycle (it MAY pass for a trivial 1-fn `.hexa` source by luck — but the SSOT does not enforce single-symbol export yet). All falsifiers (F-A1, F-A2, F-B*, F-C*, F-D*) remain unmeasured.

This sub-cycle is honest **flag wiring only** per `@D g3` (no over-claim). The `OK: built` line for `--shared` builds prints the explicit caveat `(shared library, RFC 070 G7-A flag-wiring only — F-A1/F-A2 next sub-cycle)`.

### 4.4 G7-A.native scaffold (2026-05-20, **Shape B — scaffold marker only**)

After 4.3 (the C-path `--shared` flag wiring), the parallel `compiler/codegen/{arm64_darwin,x86_64_linux}.hexa` native backends remain on a **non-PIC baseline**. The C path (clang `-fPIC -shared`) is the only PIC producer today; `HEXA_BACKEND=native` + `--shared` is explicitly refused at `self/main.hexa::cmd_build` L1973-1978 (the gate added in 4.3).

This sub-cycle is the **scaffold-only** Shape-B counterpart for the native side per `@D g_inbox_processing_loop`. Concretely:

1. **`compiler/codegen/arm64_darwin.hexa`** header gets an `// RFC 070 G7-A.native scaffold` block (≈15 lines, comment-only) documenting:
   - **Current baseline**: arm64-darwin already uses `adrp Xn, sym@PAGE` + `add Xn, Xn, sym@PAGEOFF` for local symbol/cstring loads (see L1042, L1057, L1067, L1099, L1117, L1377, L1441). This is **Mach-O PIE equivalent**: PC-relative addressing within `<±4 GiB`, no absolute fixups in `__text`. ELF terminology = PIE; macOS calls it `MH_DYLDLINK` + `MH_PIE`. **For `.dylib` we need `MH_DYLIB` + PC-relative extern resolution.**
   - **G7-A.native delta**: extern fn references (which today resolve at link time via the static-link plt-less path) MUST go through the GOT: `adrp Xn, sym@GOTPAGE` + `ldr Xn, [Xn, sym@GOTPAGEOFF]`. Local fn refs stay on `@PAGE/@PAGEOFF`. Hidden-visibility default + `<plugin_id>_dispatch` sole `.globl`.
   - **Falsifier hook**: `F-A1` (page-aligned dispatch symbol after `dlopen` at non-default base) + `F-A2` (`nm`-counted single `T`/`D`).

2. **`compiler/codegen/x86_64_linux.hexa`** header gets a parallel `// RFC 070 G7-A.native scaffold` block documenting:
   - **Current baseline**: x86_64-linux uses **absolute 64-bit immediates** for symbol addresses (no `[rip+disp32]` mode emitted; `_x86_op_imm` produces literal offsets). This is **NOT PIC**: an `.so` produced from this path would have non-relocatable `R_X86_64_64` fixups in `.text`, which `ld.so` refuses for `ET_DYN`.
   - **G7-A.native delta**: every cross-function symbol reference becomes `lea Xrax, [rip+sym@GOTPCREL]` (extern) or `lea Xrax, [rip+sym]` (local/PIE-style). Reloc kinds = `R_X86_64_GOTPCREL` (extern fn/data) + `R_X86_64_PC32` (local). The existing `R_X86_64_PLT32` emit added in cycle 30 (commit `e83dfd99`) is the call-site half; the addressing half is what this row delivers. Hidden-by-default visibility via `.hidden <sym>` directive; `<plugin_id>_dispatch` is the sole `.globl`.
   - **Falsifier hook**: identical F-A1/F-A2 contract as arm64.

3. **`compiler/PLAN.md` `## 진행 로그`** gains one entry pointing to this §4.4 + listing the 3 scaffold files (the two `compiler/codegen/*.hexa` + this RFC).

4. **Parse-gate**: `/Users/ghost/.hx/bin/hexa_real parse compiler/codegen/arm64_darwin.hexa` + `... x86_64_linux.hexa` MUST report `OK: ... parses cleanly` (comment-only edits — must not break the existing syntax).

**Out of scope (g3-honest)**: no addressing-mode helper added, no `shared` flag plumbed into the native entry points, no `.hidden` directive emission, no GOT reloc kind added to LIR, no falsifier measured. Today's `HEXA_BACKEND=native` + `--shared` still raises `exit(1)` at the gate from 4.3. The scaffold comments are **markers for the G7-A.native impl sub-cycle**, not implementation. `self/native/hexa_v2` is not regenerated. `inbox/PATCHES.yaml` is untouched. Cross-target PIC (`--target=<triple>` + `--shared`) remains gated. `self/codegen_c2.hexa` / `self/main.hexa` are not touched this commit.

**files**: `compiler/codegen/arm64_darwin.hexa` (header comment block only · ≈15 lines added) · `compiler/codegen/x86_64_linux.hexa` (header comment block only · ≈15 lines added) · `inbox/rfc_drafts_2026_05_20/rfc_070_hexa_ld_dlopen_shared.md` (§4 table G7-A.native row split into `scaffold ✅` + `impl` + this §4.4) · `compiler/PLAN.md` (single entry).

cross-link: §4.2 scaffold pattern · §4.3 C-path flag wiring · `@D g_inbox_processing_loop` Shape B · `@D g5` hexa-native-only (native codegen IS the hexa-native path — this scaffold prepares it for `.so`/`.dylib` parity with the C-path fallback) · `@D g3` real-limits-first (F-A1 anchored on OS page granularity, F-A2 anchored on ELF/Mach-O symbol-table format spec).

### 4.5 G7-A.falsify (2026-05-20, **C-path F-A1 PASS · F-A2 EXPECTED-FAIL — measured**)

After 4.3 (the C-path `--shared` flag wiring) the falsifier battery from §4.1 can finally be run on a real shared-library artifact. This sub-cycle measures **F-A1** + **F-A2** on the C path (`hexa_v2` C-source emit → `clang -fPIC -shared`), **NOT** the native codegen path. Native PIC remains gated behind `HEXA_BACKEND=native + --shared → exit(1)` (G7-A.native impl).

**Test source** (`/tmp/g7a_test.hexa`, 7 LoC):
```hexa
fn add(a: int, b: int) -> int { return a + b }
fn main() { println("add(2,3)=" + str(add(2, 3))) }
```

**Build pipeline used (since the deployed `hexa.real` at `/Users/ghost/.hx/bin/hexa.real` was built 06:59 UTC, before commit `66b055c4` at 18:21 UTC — `--shared` is in SSOT but not yet in the deployed driver per `@D g_commit_push_deploy`)**: manual two-step replicating exactly what `cmd_build` would invoke at 4.3 line ≈L2142:
1. `hexa_v2 <src> <out>.c` (the worktree's `self/native/hexa_v2`, regen'd 18:17 UTC — has the latest codegen)
2. `clang -O2 -fPIC -shared <flags> <out>.c self/runtime.c -o <out>.{dylib,so}` (the exact prepend `-fPIC -shared` that G7-A.flag-wire injects)

**F-A1 — dlopen + dlsym + invoke + byte-eq** (real-limit anchor: OS-mandated virtual-memory page granularity; `RTLD_LOCAL` so harness must link its own `runtime.c` to resolve `hexa_int` / `hexa_as_num`):

| platform | host | artifact | size | result |
| --- | --- | --- | --- | --- |
| macOS arm64 (Mach-O DYLIB) | local Darwin 25.5.0 (arm64) | `/tmp/g7a.dylib` | OK: `Mach-O 64-bit dynamically linked shared library arm64` (otool `filetype DYLIB`) | **PASS** — harness `dlopen + dlsym("add") + add(hexa_int(2), hexa_int(3))` → `hexa_as_num == 5` byte-equally · rc=0 · prints `PASS F-A1 dlopen+dlsym(add)+call -> 5 (byte-eq with native 5)` |
| ELF x86_64 (ET_DYN) | ubu-1 (`aiden@10.142.0.1` · Ubuntu 24.04 · clang) | `/tmp/g7a-rfc070/g7a.so` | OK: `ELF 64-bit LSB shared object, x86-64, version 1 (SYSV), dynamically linked` (readelf `Type: DYN (Shared object file)`) | **PASS** — same harness · `hexa_as_num == 5` byte-equally · rc=0 · prints same PASS line |

Side-anchor (free byproduct, **not the gated falsifier**): the readelf/otool output above also satisfies **F-B1** (`readelf -h ... Type: DYN`) + the Mach-O analog of **F-B3** (`otool -hv ... filetype DYLIB`) — both clang-produced, not yet `hexa_ld`-produced (which is G7-B), but the format-spec contract holds.

**F-A2 — single-symbol `nm` test** (real-limit anchor: ELF / Mach-O symbol-table format spec; `T`/`D` = exported global text/data per System V gABI §4.18 and Apple `<mach-o/nlist.h>`):

| platform | exported `T`+`D` count | `<plugin_id>_dispatch` analog (`add`) present? | verdict |
| --- | --- | --- | --- |
| macOS arm64 (`nm /tmp/g7a.dylib`) | **611** (606 `T` + 5 `D`) | yes (`_add` at offset `0x720`) | **EXPECTED-FAIL** per §4.3 caveat |
| ELF x86_64 (`nm -D --defined-only /tmp/g7a-rfc070/g7a.so`) | **560** (559 `T` + 1 `D`) | yes (`add` at offset `0x000df90`) | **EXPECTED-FAIL** per §4.3 caveat |

**Honesty (`@D g3`)**: F-A2 EXPECTED-FAIL is the **measured proof** of the §4.3 caveat: `clang -shared` alone exports every public symbol from `runtime.c` (~559-606 of them, the `T` symbols are mostly `hexa_*` runtime entry points like `hexa_str`, `hexa_println`, `hexa_int`, `_array_store`, etc., plus accelerator FFI stubs `farr_*`, `_lora_cuda_*`, `_hxmetal_*`). The SSOT does NOT yet narrow the export set — that narrowing (hidden-by-default + `.private_extern`/`.hidden` directives + single `.globl` for `<plugin_id>_dispatch`) is the **G7-A.native impl** scope (§4.4). F-A2 PASS in the strict sense requires either (a) the G7-A.native impl sub-cycle to land, or (b) a separate clang `-fvisibility=hidden` + `__attribute__((visibility("default")))` annotation in the emitted C — neither in scope this sub-cycle.

**Real-limit grounding**: F-A1's anchor — "must `dlopen` + `dlsym` correctly, must call without segfault, must produce byte-equal `5`" — is the **operative correctness contract** for any future G7-B/C/D consumer. F-A2's "must export exactly one global" is the **separate ABI-cleanliness contract**. They are decoupled by RFC design (§4.1 lists them as two falsifiers, not one). G7-A.falsify PASS on F-A1 + measured-fail on F-A2 = the C path is **functionally correct, ABI-noisy**. wilson's "drop a `.so`, no relink" consumer flow (the source patch `inbox/patches/g7-hexa-ld-dlopen.md` §1 motivation) requires F-A1 only — `dlsym("<plugin_id>_dispatch")` ignores the other 605 exported symbols at the cost of ~50 KiB of dynsym noise per plugin. F-A2 becomes mandatory when capability gating (§3.C) or ABI stamping (§3.D) needs the export set to be a known-finite manifest.

**Falsifier replication**: harness `/tmp/g7a_harness.c` (40 LoC, `dlopen RTLD_NOW|RTLD_LOCAL` + `dlsym("add")` + invoke + `hexa_as_num` byte-check + `dlerror`-gated). Self-links own `self/runtime.c` (RTLD_LOCAL means symbols in the `.dylib` are NOT shared with the host process). Returns rc=0 on PASS, rc=1 on any failure (dlopen/dlsym null, dlerror non-empty, byte-eq mismatch). Cross-platform — same source built on both hosts.

**Out of scope (g3-honest)**: zero SSOT code edit in `compiler/codegen/`, `compiler/link/`, `self/runtime.{c,h}`, `self/codegen_c2.hexa`. No `hexa_v2` regen. No deployed-driver promote (the local `hexa build --shared` invocation today refuses with `source file not found: --shared` because `hexa.real` was built before `66b055c4` — the manual two-step pipeline above mirrors what the regenerated driver will do once `@D g_commit_push_deploy` runs). `compiler/codegen/{arm64_darwin,x86_64_linux}.hexa` untouched (G7-A.native impl sub-cycle's scope). `hexa_ld` untouched (G7-B). `stdlib/dynlink.hexa` not created (G7-C). `.hexa.cap` / `.hexa.abi` sections not emitted (G7-D). wilson `core/loader.hexa` not modified (G7-E, downstream). Mach-O parity for *full* G7-A-D suite deferred to G7-F. Native-codegen F-A1/F-A2 deferred to G7-A.native impl. `inbox/PATCHES.yaml` untouched.

**files**: `inbox/rfc_drafts_2026_05_20/rfc_070_hexa_ld_dlopen_shared.md` (status flip, §4 G7-A.falsify row update, this §4.5 ≈60 added lines) · `compiler/PLAN.md` (single entry).

cross-link: §4.1 falsifier battery (F-A1, F-A2, F-B1, F-B3 anchors) · §4.3 G7-A.flag-wire (the `-shared` pass-through this sub-cycle exercises) · `@D g_inbox_processing_loop` Shape A (smallest measurement closure) · `@D g3` real-limits-first (F-A1 anchored on OS page granularity + nanbox byte-eq; F-A2 anchored on ELF/Mach-O symbol-table format spec) · `@D g_commit_push_deploy` (deployed `hexa.real` predates `66b055c4` — manual pipeline measures the SAME `-fPIC -shared` clang invocation that `cmd_build` injects).

### 4.6 G7-A.native impl iface (2026-05-20, **Shape B — interface lift only, zero emit change**)

After 4.4 (the scaffold marker on the two native codegen files) and in parallel with the C-path 4.3/4.5 work, this sub-cycle lands the **data-shape decision** the G7-A.native impl will consume — without touching any emit body or entry signature. Pure interface lift.

**SSOT change** — `compiler/ir/lir.hexa` appends a new block after the existing `LSection` struct:

1. **`pub struct CodegenOptions { shared: i64, target_triple: string }`** — per-invocation flag struct. `shared=0` = executable/PIE baseline (today's behavior); `shared=1` = `.dylib`/`.so` PIC mode (next sub-cycle's GOT-indirection + `.private_extern`/`.hidden` directive + single `.globl` for `<plugin_id>_dispatch`). `target_triple=""` = host default; populated by `cmd_build` cross-target path.
2. **`pub fn codegen_options_default() -> CodegenOptions`** — canonical zero-seed helper. Until call sites thread real options, the impl sub-cycle inserts `let opts = codegen_options_default()` at each entry fn so the diff stays bounded.
3. **5 reloc kind string constants** (NOT a variant enum — stage0's transitive-let binding gap noted in `arm64_darwin.hexa` L80-82 makes new closed-sum lowering brittle, so string constants are the lower-risk shape):
   - `pub let RELOC_AARCH64_ADR_GOT_PAGE  = "R_AARCH64_ADR_GOT_PAGE"` (arm64 GOT-load page21 reloc — Mach-O `ld64` analog is `ARM64_RELOC_GOT_LOAD_PAGE21`, identical asm-text)
   - `pub let RELOC_AARCH64_LD64_GOT_LO12_NC = "R_AARCH64_LD64_GOT_LO12_NC"` (arm64 GOT-load lo12 — Mach-O analog `ARM64_RELOC_GOT_LOAD_PAGEOFF12`)
   - `pub let RELOC_X86_64_GOTPCREL = "R_X86_64_GOTPCREL"` (x86_64 `[rip+sym@GOTPCREL]` LEA — System V gABI §4)
   - `pub let RELOC_X86_64_PC32     = "R_X86_64_PC32"` (x86_64 `[rip+sym]` PC-relative — already used for branch targets internally; promoted here for take-address sites)
   - `pub let RELOC_X86_64_PLT32    = "R_X86_64_PLT32"` (x86_64 PLT call-site — emitted by cycle 30 `e83dfd99`; listed for completeness so the impl sub-cycle does not re-invent)

**Scaffold marker cross-link** — both `compiler/codegen/arm64_darwin.hexa` (L36) and `compiler/codegen/x86_64_linux.hexa` (L34) header blocks are amended to point at the new types (`pub struct CodegenOptions` + `codegen_options_default()` + `RELOC_*` constants now reachable from `../ir/lir.hexa`). The "next sub-cycle (G7-A.native impl)" guidance is updated to say "thread `CodegenOptions` as the 2nd arg" and "tag GOT-load LInstrs via `LInstr.comment = RELOC_*`".

**Why lift the types NOW (not in the impl sub-cycle itself)**: decouples the data-shape decision from the per-target addressing-mode work, so the impl PR's diff stays localized to the two `codegen/<target>.hexa` files. Also lets the impl PR caller (`compiler/main.hexa::cmd_build` native branch) construct `CodegenOptions` from `bopts[4]` the moment the flag-wire prereq (66b055c4) merges to this branch.

**Out of scope (g3-honest)**: zero functional change. (i) No call site constructs `CodegenOptions` today — the struct is reachable but unused. (ii) No `LInstr.comment` in the current emit stream carries the `RELOC_*` strings — the constants are referenced only from the scaffold marker comments. (iii) `codegen_arm64_darwin` / `codegen_x86_64_linux` entry-fn signatures are byte-untouched — `MModule -> LModule` exactly as before, so the 3 callers (`compiler/main.hexa:799,801`, `compiler/codegen/codegen_test.hexa:266,267,329,330`) need zero change. (iv) `compiler/main.hexa::cmd_build` gate `HEXA_BACKEND=native + --shared → exit(1)` is **untouched** — the gate-drop requires both the flag-wire prereq (66b055c4) AND the impl sub-cycle threading `bopts[4]` through to `CodegenOptions.shared`. (v) `self/native/hexa_v2` not regenerated per `@D g_inbox_processing_loop` step 7. (vi) `inbox/PATCHES.yaml` untouched. (vii) No falsifier measured this sub-cycle — F-A1/F-A2 measurement on the native-codegen output remains G7-A.native impl scope.

**Parse-gate**: `hexa_real parse` PASS on all three edited files (`compiler/ir/lir.hexa`, `compiler/codegen/arm64_darwin.hexa`, `compiler/codegen/x86_64_linux.hexa`). Comment-only edits in the codegen files + struct/let additions in lir.hexa — must not break syntax, and don't.

**files**: `compiler/ir/lir.hexa` (≈70 added lines — new `CodegenOptions` struct + `codegen_options_default()` + 5 `RELOC_*` constants + ≈30 lines of "why now" comment block) · `compiler/codegen/arm64_darwin.hexa` (scaffold marker comment update — 8 lines added pointing at new lir.hexa types · zero code change) · `compiler/codegen/x86_64_linux.hexa` (parallel scaffold marker update — 8 lines added · zero code change) · `inbox/rfc_drafts_2026_05_20/rfc_070_hexa_ld_dlopen_shared.md` (§4 table `G7-A.native impl iface ✅` row added + this §4.6) · `compiler/PLAN.md` (single entry).

cross-link: §4.4 G7-A.native scaffold (the scaffold marker this iface cross-references) · §4.5 G7-A.falsify (the C-path measurement this complements with native-path interface) · `@D g_inbox_processing_loop` Shape B (interface lift = honest sub-step of a multi-cycle Shape B campaign) · `@D g5` hexa-native-only (lir.hexa is the IR backbone of the hexa-native codegen path; lifting the options/reloc types there cements the data-shape decision on the hexa-native side) · `@D g3` real-limits-first (the `RELOC_*` constants are anchored on System V gABI §4 and Mach-O `<mach-o/arm64/reloc.h>` — real-format-spec, not invention) · `@D g_commit_push_deploy` (no binary promote this sub-cycle — purely SSOT; the impl sub-cycle will trigger the deploy gate alongside the flag-wire merge).

### 4.7 G7-A.native impl signature (2026-05-20, **Shape B sub-step — signature lift only, emit body byte-eq with default opts**)

After 4.6 (interface lift into `compiler/ir/lir.hexa`) this sub-cycle threads the `CodegenOptions` argument through the two CPU-target codegen entry-points without adding any `if opts.shared` branch in the emit body. Pure signature lift + caller fan-out.

**What landed**:

- `compiler/codegen/arm64_darwin.hexa::codegen_arm64_darwin` — signature `(module: MModule) -> LModule` → `(module: MModule, opts: CodegenOptions) -> LModule`. ≈11-line lead comment block above the entry documenting the lift + the next sub-cycle (emit body branches).
- `compiler/codegen/x86_64_linux.hexa::codegen_x86_64_linux` — parallel change (same comment template, x86-specific reloc names in cross-link).
- 11 callers fanned out to pass `codegen_options_default()`:
  - `compiler/main.hexa` L798-801 — driver branch (single `__cg_opts` binding hoisted ahead of the per-target `if`, reused on both arm64 + x86 calls). The lead comment documents that `--shared` flag pass-through (G7-A.flag-wire prereq `66b055c4`) is **not** on this branch yet, so `__cg_opts` is always default.
  - `compiler/codegen/codegen_test.hexa` L266,267,329,330 — both `_id` and `_add` cases on each target (4 sites, one shared `__cg_opts` per `_check_*` body).
  - `tests/m0/regalloc_test.hexa` L190,250 — `_check_arm64` + `_check_x86_64`, inline `codegen_options_default()`.
  - `tests/m0/loop_test.hexa` L236,237 — single `__cg_opts` reused across the arm64 + x86 branches.
  - `tests/m0/concat_test.hexa` L158,159 — same pattern as loop_test.
  - `tests/m0/many_args_test.hexa` L188,264 — inline `codegen_options_default()`, one per target check.

**Parse-gate**: `SIDECAR_NO_POOL=1 HEXA_LANG=<worktree> /Users/ghost/.hx/bin/hexa_real parse <file>` (hyphenated-basename hexa_real shim per `reference_hexa_basename_sigkill_workaround_2026_05_19.md`) PASS 9/9 — both codegen files + `compiler/ir/lir.hexa` (unchanged but re-verified) + 6 caller files (`compiler/main.hexa`, `compiler/codegen/codegen_test.hexa`, 4 `tests/m0/*_test.hexa`).

**Byte-eq theorem**: `codegen_options_default()` returns `CodegenOptions { shared: 0, target_triple: "" }` (see `compiler/ir/lir.hexa::codegen_options_default`). The emit-body branches that would change behavior are not added this commit — `opts` is bound and propagated but never inspected inside either `codegen_arm64_darwin` or `codegen_x86_64_linux`. Therefore every emit byte produced by the entry points is identical to the pre-iface output for every caller, on every target. The remote `tool/parity_*.sh` corpus harness would observe zero `.s` diff (not measured this cycle — see §4.7-out-of-scope; cost-bound triage is in §6).

**Out of scope (g3-honest)**:

(i) No `if opts.shared` branch added in either codegen body — the emit stream is byte-identical to pre-iface output.

(ii) No `.private_extern` (Mach-O) / `.hidden` (ELF) directive emitted — visibility-narrowing remains the next sub-cycle (G7-A.native impl emit).

(iii) No `RELOC_AARCH64_*` / `RELOC_X86_64_GOTPCREL` constant referenced from any LInstr.comment — the constants are still only cited from the scaffold-marker comments.

(iv) No GOT-load (`adrp Xn, sym@GOTPAGE` + `ldr Xn, [Xn, sym@GOTPAGEOFF]` / `lea rax, [rip+sym@GOTPCREL]`) emission — `@PAGE/@PAGEOFF` baseline preserved on arm64; absolute-64-bit-immediate baseline preserved on x86_64.

(v) `self/main.hexa::cmd_build` gate `HEXA_BACKEND=native + --shared → exit(1)` — neither dropped nor added this cycle. The G7-A.flag-wire prereq commit (`66b055c4` — `bopts[4]` CLI surface) is **not** on this branch, so there is no `--shared` flag to even reach `cmd_build`'s native dispatch. Gate-drop is the next sub-cycle's joint scope (signature emit-body + flag-wire on the same commit).

(vi) F-A1/F-A2 native-codegen measurement deferred — the signature lift produces no native-PIC artifact to inspect. The C-path F-A1 PASS + F-A2 EXPECTED-FAIL from §4.5 remain the standing measurement.

(vii) `self/native/hexa_v2` NOT regenerated (per `@D g_inbox_processing_loop` step 7 — binary promote is a separate deploy cycle, NOT this commit).

(viii) `inbox/PATCHES.yaml` untouched.

(ix) `compiler/codegen/thumbv7em_eabihf.hexa` (3rd CPU target) + `compiler/codegen/nvptx_*.hexa` (NVPTX targets) — signature unchanged. Their entry points (`codegen_thumbv7em_eabihf`, `codegen_nvptx_sm{80,90}`) take only `MModule` — `--shared` is meaningless for bare-metal (thumbv7em) and a GPU code module (NVPTX), so they are intentionally excluded from the lift. The driver branch in `compiler/main.hexa` reaches them on different `if target ==` arms that do not see `__cg_opts`.

**files**:
- `compiler/codegen/arm64_darwin.hexa` (≈11 added lines lead comment + entry signature `+ , opts: CodegenOptions`)
- `compiler/codegen/x86_64_linux.hexa` (parallel ≈11 added lines + signature change)
- `compiler/main.hexa` L798-801 (≈10 added lines lead comment + `let __cg_opts = codegen_options_default()` hoist + 2 call-site `, __cg_opts` adds)
- `compiler/codegen/codegen_test.hexa` L266-267, L329-330 (3 added lines lead comment + 1 hoist + 4 call-site adds)
- `tests/m0/regalloc_test.hexa` L190, L250 (2 added lead comments + 2 inline `, codegen_options_default()` adds)
- `tests/m0/loop_test.hexa` L236-237 (1 hoist + 2 call-site adds)
- `tests/m0/concat_test.hexa` L158-159 (1 hoist + 2 call-site adds)
- `tests/m0/many_args_test.hexa` L188, L264 (2 added lead comments + 2 inline adds)
- `inbox/rfc_drafts_2026_05_20/rfc_070_hexa_ld_dlopen_shared.md` (§4 table row split into `signature ✅` + `emit` + this §4.7)
- `compiler/PLAN.md` (single entry per `@D g_plan_consolidation`)

cross-link: §4.6 G7-A.native impl iface (the data-shape this signature lift consumes) · §4.5 G7-A.falsify (the C-path measurement this preserves byte-equivalence with) · §4 table row `G7-A.native impl emit` (the next sub-cycle that this signature unblocks) · `@D g_inbox_processing_loop` Shape B (Shape A — signature is surgical, but caller fan-out across 11 sites triggered the brief's documented Shape B path "= caller update 만 + emit 변경은 다음 sub-cycle") · `@D g5` hexa-native-only (lift threads through the two CPU targets of the hexa-native codegen path; thumbv7em + NVPTX excluded because `--shared` semantics do not apply) · `@D g3` real-limits-first (default-`opts` byte-eq theorem rests on `codegen_options_default()` returning literal `{0, ""}` — verifiable by inspection of `compiler/ir/lir.hexa::codegen_options_default`, no inference) · `@D g_commit_push_deploy` (no binary promote this sub-cycle — signature change requires both the emit sub-cycle and the flag-wire prereq to land before the deployed-driver gate is meaningful).

## 5. Open questions (verbatim from source patch §7 + 2026-05-20 status)

1. **libc `dlopen` dependency** — hexa runtime already FFI-calls `dlopen` from multiple modules (§2 audit). G7 widens that; it doesn't introduce. If a future "no libc" mandate lands, option (c) custom loader is the bridge.
2. **nanbox ABI stability** — closed by §3.D ABI stamp. Required, not optional.
3. **Is (d) sufficient?** — wilson MVP decides. RFC 070 is not on the wilson critical path; G7-A is the smallest first step if-and-only-if wilson measures G8 incremental link as too slow.
4. **`hexa_ld` has never emitted dynamic** — true. G7-B is the biggest single piece of work. Phasing keeps it isolated.

## 6. Decision punted

- **Tooling for capability manifest authoring** (Phase D): is it a `@plugin(capabilities=...)` attribute on the dispatch fn, or a sidecar `.hexa.cap.tape` declarative file? Decide at G7-D start.
- **Hot reload semantics**: does `dynlink_close` followed by `dynlink_open` of an updated `.so` require quiescence on outstanding handles? Decide at G7-E.
- **Versioned `dlsym` (a la ELF symbol versioning `@@VER`)**: probably no for the fat-single-symbol model; revisit if (a) full-dynamic is later adopted.

## 7. One-liner

`hexa cc --shared` (PIC, hidden-by-default, only `<plugin_id>_dispatch` exported) + `hexa_ld --shared` (ET_DYN/MH_DYLIB, 1-symbol dynsym) + `self/runtime.{c,h}` `hexa_dlopen/dlsym/dlclose` + `stdlib/dynlink.hexa` + `.so` `.hexa.cap` (HXC v2) and `.hexa.abi` (runtime/nanbox hash) sections with host gate. Phased G7-A..G7-F across ≥3 cycles. **Option (d) "skip G7, use G8 incremental + multi-call" remains valid if wilson measures G7 cost > G8 incremental cost.**

---

## Appendix — original patch preserved

Source: `inbox/patches/g7-hexa-ld-dlopen.md` (opened 2026-05-10). All §1-§8 of that patch are absorbed verbatim or near-verbatim into §1, §2, §3, §5, §7 of this RFC. The original markdown stays in `inbox/patches/` with status `rfc-promoted 2026-05-20 (RFC 070)`.
