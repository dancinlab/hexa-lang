# RFC 070 — `hexa_ld --shared` + runtime `dlopen` (fat .so single-symbol convention)

> **status**: `g7-d-scaffold` (capability-manifest authoring decision LOCKED = `@plugin(capabilities=[...])` in-source attribute; ABI stamp `(runtime_version: u32, nanbox_layout_hash: u64)` section layout LOCKED; `stdlib/dynlink_caps.hexa` skeleton + `compiler/codegen/plugin_attr_scaffold.hexa` skeleton landed · zero behavior change · §4.6 below)
> **opened**: 2026-05-20 (promoted from `archive/patches/g7-hexa-ld-dlopen.md`, opened 2026-05-10)
> **G7-A flag wire**: 2026-05-20 (`self/main.hexa::cmd_build` + dispatch — flag-wiring only, zero falsifier coverage yet)
> **G7-A falsify** : 2026-05-20 (F-A1/F-A2 measured on C path · macOS arm64 dylib + ubu-1 ELF x86_64 .so · §4.5 below)
> **G7-D scaffold** : 2026-05-20 (design choice locked + section layout + skeleton stubs · §4.6 below · zero behavior change · falsifier F-D1/F-D2 unmeasured)
> **owner**: hexa-lang compiler (`compiler/codegen/` · `compiler/link/hexa_ld.hexa` · `self/runtime.{c,h}`)
> **consumer demand**: wilson in-process plugins (hot-path provider/tool/hook/view). Out-of-scope reuse: anima/nexus, generally any consumer that wants "drop a `.so`, no relink".
> **priority**: ★ (have-it-is-nice, blocking-none) — without G7 wilson stays on G8-incremental + busybox-multi-call paths (option (d) of the source patch).

---

## 0. Cross-link

- **source patch** : `archive/patches/g7-hexa-ld-dlopen.md` (opened 2026-05-10, this RFC promotes that spec).
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
| G7-A.native impl.iface ✅ | `compiler/ir/lir.hexa` lifts `pub struct CodegenOptions { shared: i64, target_triple: string }` + `codegen_options_default()` helper + 5 reloc-kind string constants (`RELOC_AARCH64_ADR_GOT_PAGE`, `RELOC_AARCH64_LD64_GOT_LO12_NC`, `RELOC_X86_64_GOTPCREL`, `RELOC_X86_64_PC32`, `RELOC_X86_64_PLT32`). Interface-only — zero emit body change. **LANDED 2026-05-20** (commit `2a579ce8`). | G7-A.native scaffold | — (iface only) |
| G7-A.native impl.signature ✅ | `codegen_arm64_darwin(module, opts: CodegenOptions)` + `codegen_x86_64_linux(module, opts)` entry signatures lifted; 11 caller sites updated to pass `codegen_options_default()`. Emit body byte-identical with `opts.shared == 0`. **LANDED 2026-05-20** (commit `06bc2ea4`). | G7-A.native impl.iface | corpus byte-eq (default opts) |
| G7-A.native impl.emit-body ✅ | `_arm64_op_rm` + `_x86_op_rm` / `_x86_op_resolve` honor `opts.shared`. PIC mode emits: (a) `adrp Xn, sym@GOTPAGE` + `ldr Xn, [Xn, sym@GOTPAGEOFF]` for arm64 global refs (`MACHO_ARM64_RELOC_GOT_LOAD_*` / `R_AARCH64_*_GOT_*`); (b) `mov scratch, [rip+sym@GOTPCREL]` for x86_64 global refs (`R_X86_64_GOTPCREL`). `emit/asm.hexa::_fmt_mem` honors the new `label`-as-offset memory operand shape. Per-instruction reloc-kind tag carried via `LInstr.comment` suffix `[reloc=…]` for the future asm-text emitter dispatch. arm64 = commit `8fdb29e2` (D1 partial). x86_64 = this sub-cycle (D2 — `_x86_op_rm` global+`opts.shared==1` GOT-load branch + `_x86_op_resolve` global→reg fallback). Default `opts.shared == 0` keeps both backends byte-identical with pre-iface output. | G7-A.native impl.signature | corpus byte-eq (default opts), measured F-A1/F-A2 deferred → G7-A.native impl.falsify |
| G7-A.native impl.cli-wire ✅ | `self/main.hexa::cmd_build` native branch — drops the `HEXA_BACKEND=native + --shared → exit(1)` refusal (was L2062-L2068) and threads `--shared` through to aprime_cc invocation (`--shared` flag pass-through) + clang link step (`-fPIC -shared` flags) + existence-check fallback (`test -x` → `test -e` for 0644 .so/.dylib output). `compiler/main.hexa` accepts `--shared` flag (new `shared_flag: bool` + parse branch) + overlays `codegen_options_default()` with `{shared: 1, target_triple: ""}` to gate emit-body GOT-load branches. **LANDED 2026-05-20** (K2 sub-cycle, worktree branch). | G7-A.native impl.emit-body + impl.iface + impl.signature + flag-wire | corpus byte-eq (default — `shared_flag == false` keeps `codegen_options_default()` overlay no-op) |
| G7-A.native impl.visibility | (a) per-function `.hidden` (ELF) / `.private_extern` (Mach-O) directive default; (b) `.globl` only for `<plugin_id>_dispatch`. Sits in the LIR→asm text emitter (currently `compiler/emit/asm.hexa` plus a future per-function visibility hook). Carries the export-set narrowing that flips F-A2 from EXPECTED-FAIL to PASS (today's clang `-shared` exports every public symbol — see G7-A.falsify caveat). | G7-A.native impl.emit-body | F-A2 (native) |
| G7-A.native impl.falsify | Run F-A1 (dlopen + dlsym + call on native-codegen output) + F-A2 (single-`.globl` export set) on the native-emit artifact on both macOS arm64 + ubu-1 x86_64. Pre-cli-wire (`HEXA_BACKEND=native + --shared` gated) deferred — cli-wire LANDED 2026-05-20 (K2), measurement requires K1 deferred #2 (binary promote of `self/native/hexa_v2`). | G7-A.native impl.cli-wire + impl.visibility | F-A1, F-A2 (native) |
| G7-A.falsify ✅ | F-A1 PASS both platforms (dlopen + dlsym(`add`) + call → 5 byte-equally · macOS arm64 dylib + ubu-1 ELF x86_64 .so). F-A2 EXPECTED-FAIL both platforms per §4.3 caveat (Mach-O = 611 exported T/D symbols · ELF = 560 exported T/D symbols · `add` is one of them, not the sole one — clang `-shared` alone exports every public symbol; single-symbol narrowing is G7-A.native impl scope). Measured 2026-05-20, **C path only** (`hexa_v2 → clang -fPIC -shared`, NOT native-codegen). | G7-A.flag-wire | F-A1, F-A2 (measured · F-A2 = expected-fail caveat) |
| G7-B (ELF Part A + Mach-O Part A) ✅ | `compiler/link/hexa_ld.hexa --shared` emits `ET_DYN` (ELF, v1.4 — PT_DYNAMIC + .dynsym/.dynstr/.hash chain + 1-symbol export) and `MH_DYLIB` (Mach-O, v1.7 — LC_DYLD_INFO_ONLY export-trie + LC_DYSYMTAB + LC_ID_DYLIB + __DATA,__got zero-fill). F-B-LOADABLE for ELF MEASURED 2026-05-20. | G7-A | F-B1, F-B2, F-B3 |
| G7-B Mach-O Part B ✅ | Real `BIND_OPCODE_DO_BIND` records (SET_DYLIB_ORDINAL_IMM(1) + SET_SYMBOL_TRAILING_FLAGS_IMM("dyld_stub_binder") + SET_TYPE_IMM(POINTER) + SET_SEGMENT_AND_OFFSET_ULEB(__DATA,0) + DO_BIND + DONE) replace placeholder `BIND_OPCODE_DONE`-only blob. LC_LOAD_DYLIB libSystem added (cmd 0x0C, name="/usr/lib/libSystem.B.dylib", ncmds 9→10). **LANDED 2026-05-20** (worktree commit `54792a3d`, SSOT-only + parse-gate PASS). F-B-LOADABLE Mach-O measure cycle deferred (binary regen + dyld_info + dlopen). | G7-B Part A | F-B-LOADABLE Mach-O (deferred) |
| G7-C  | `self/runtime.{c,h}` adds `hexa_dlopen/dlsym/dlclose/dlerror`; `stdlib/dynlink.hexa` ships | G7-B (or independent if consuming pre-built `.so` only) | F-C1, F-C2 |
| G7-D.scaffold ✅ | Capability-manifest authoring **decision locked = `@plugin(capabilities=[...])` in-source attribute** (sidecar `.hexa.cap.tape` declined per `@D g3` honesty anchor). ABI stamp record layout LOCKED = `(runtime_version: u32, nanbox_layout_hash: u64)` little-endian, 12 B fixed. `stdlib/dynlink_caps.hexa` skeleton (parse + check_compat + check_grant fn shells, no body) + `compiler/codegen/plugin_attr_scaffold.hexa` (header-comment-only scaffold marker for `@plugin` attribute parser hook). **Zero behavior change.** | G7-C (section emit) | none yet — scaffold only |
| G7-D.impl | `compiler/parser` learns `@plugin(capabilities=[...])` attribute (string-array literal); `compiler/codegen` emits `__HEXA,__cap` (Mach-O) / `.hexa.cap` (ELF) section with HXC v2-encoded `CapManifest{ plugin_id, capabilities[], rfc_version }`; emits `__HEXA,__abi` / `.hexa.abi` section with `AbiStamp{ runtime_version, nanbox_layout_hash }`. `stdlib/dynlink_caps.hexa` bodies populated. Host `hexa_dlopen` MUST refuse mismatched ABI + ungranted capabilities. | G7-D.scaffold | F-D1, F-D2 |
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
3. `archive/patches/g7-hexa-ld-dlopen.md` status flipped `spec → rfc-promoted 2026-05-20 (RFC 070)`.
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

**Out of scope (g3-honest)**: no addressing-mode helper added, no `shared` flag plumbed into the native entry points, no `.hidden` directive emission, no GOT reloc kind added to LIR, no falsifier measured. Today's `HEXA_BACKEND=native` + `--shared` still raises `exit(1)` at the gate from 4.3. The scaffold comments are **markers for the G7-A.native impl sub-cycle**, not implementation. `self/native/hexa_v2` is not regenerated. `archive/patches/PATCHES.yaml` is untouched. Cross-target PIC (`--target=<triple>` + `--shared`) remains gated. `self/codegen_c2.hexa` / `self/main.hexa` are not touched this commit.

**files**: `compiler/codegen/arm64_darwin.hexa` (header comment block only · ≈15 lines added) · `compiler/codegen/x86_64_linux.hexa` (header comment block only · ≈15 lines added) · `docs/rfc/rfc_drafts_2026_05_20/rfc_070_hexa_ld_dlopen_shared.md` (§4 table G7-A.native row split into `scaffold ✅` + `impl` + this §4.4) · `compiler/PLAN.md` (single entry).

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

**Real-limit grounding**: F-A1's anchor — "must `dlopen` + `dlsym` correctly, must call without segfault, must produce byte-equal `5`" — is the **operative correctness contract** for any future G7-B/C/D consumer. F-A2's "must export exactly one global" is the **separate ABI-cleanliness contract**. They are decoupled by RFC design (§4.1 lists them as two falsifiers, not one). G7-A.falsify PASS on F-A1 + measured-fail on F-A2 = the C path is **functionally correct, ABI-noisy**. wilson's "drop a `.so`, no relink" consumer flow (the source patch `archive/patches/g7-hexa-ld-dlopen.md` §1 motivation) requires F-A1 only — `dlsym("<plugin_id>_dispatch")` ignores the other 605 exported symbols at the cost of ~50 KiB of dynsym noise per plugin. F-A2 becomes mandatory when capability gating (§3.C) or ABI stamping (§3.D) needs the export set to be a known-finite manifest.

**Falsifier replication**: harness `/tmp/g7a_harness.c` (40 LoC, `dlopen RTLD_NOW|RTLD_LOCAL` + `dlsym("add")` + invoke + `hexa_as_num` byte-check + `dlerror`-gated). Self-links own `self/runtime.c` (RTLD_LOCAL means symbols in the `.dylib` are NOT shared with the host process). Returns rc=0 on PASS, rc=1 on any failure (dlopen/dlsym null, dlerror non-empty, byte-eq mismatch). Cross-platform — same source built on both hosts.

**Out of scope (g3-honest)**: zero SSOT code edit in `compiler/codegen/`, `compiler/link/`, `self/runtime.{c,h}`, `self/codegen_c2.hexa`. No `hexa_v2` regen. No deployed-driver promote (the local `hexa build --shared` invocation today refuses with `source file not found: --shared` because `hexa.real` was built before `66b055c4` — the manual two-step pipeline above mirrors what the regenerated driver will do once `@D g_commit_push_deploy` runs). `compiler/codegen/{arm64_darwin,x86_64_linux}.hexa` untouched (G7-A.native impl sub-cycle's scope). `hexa_ld` untouched (G7-B). `stdlib/dynlink.hexa` not created (G7-C). `.hexa.cap` / `.hexa.abi` sections not emitted (G7-D). wilson `core/loader.hexa` not modified (G7-E, downstream). Mach-O parity for *full* G7-A-D suite deferred to G7-F. Native-codegen F-A1/F-A2 deferred to G7-A.native impl. `archive/patches/PATCHES.yaml` untouched.

**files**: `docs/rfc/rfc_drafts_2026_05_20/rfc_070_hexa_ld_dlopen_shared.md` (status flip, §4 G7-A.falsify row update, this §4.5 ≈60 added lines) · `compiler/PLAN.md` (single entry).

cross-link: §4.1 falsifier battery (F-A1, F-A2, F-B1, F-B3 anchors) · §4.3 G7-A.flag-wire (the `-shared` pass-through this sub-cycle exercises) · `@D g_inbox_processing_loop` Shape A (smallest measurement closure) · `@D g3` real-limits-first (F-A1 anchored on OS page granularity + nanbox byte-eq; F-A2 anchored on ELF/Mach-O symbol-table format spec) · `@D g_commit_push_deploy` (deployed `hexa.real` predates `66b055c4` — manual pipeline measures the SAME `-fPIC -shared` clang invocation that `cmd_build` injects).

### 4.6 G7-D scaffold (2026-05-20, **Shape B — design decision lock + skeleton, zero behavior change**)

G7-D is the **capability manifest + ABI stamp** phase. The promote (§4.2) deferred two design questions to G7-D start; this sub-cycle locks the **first** (authoring tooling) and the **second** (ABI stamp record layout), and lands two **skeleton-only** source files so G7-D.impl has a known target shape.

The phase-D motivation: the §4.5 measurement proved F-A1 PASS (load + invoke works) but F-A2 EXPECTED-FAIL (~605 noise symbols leak). For wilson's "drop a `.so`, no relink" flow F-A1 alone suffices; but the moment the host wants to **gate** which `.so`s are allowed to enter the process — that is, the moment §3.C capability gating becomes a hard requirement — F-A2's "exactly one known global" becomes mandatory, AND we need a way to author + transport + verify the capability set. §3.C / §3.D laid out the section names; §6's first punted decision was the authoring surface.

#### 4.6.1 Design choice — authoring surface (**LOCKED: option A**)

| dim | (A) `@plugin(capabilities=[...])` attribute (in-source) | (B) sidecar `.hexa.cap.tape` declarative file |
|-----|--------------------------------------------------------|-----------------------------------------------|
| SSOT location | same `.hexa` source as `<plugin_id>_dispatch` fn | sibling file, separate edit surface |
| drift hazard | **zero** — attribute lives 0 lines from the dispatch fn body | **non-zero** — author can edit one without the other (silent mismatch) |
| `@D g3` honesty anchor | **PASSES** — source is the truth, capability claim is structurally adjacent to the code that exercises it | **FAILS** — manifest is a claim, can diverge from what the dispatch fn actually calls |
| `@D g6` precedent | **MATCHES** — `@cite`, `@stability`, `@effect` are all in-source attributes | mismatch — would be the only "declarative sibling" pattern in hexa-lang |
| audit-friendliness | `git grep '@plugin' stdlib/` lists every plugin's capability claim in one pass | requires walking sibling files + cross-checking with source |
| decompilability | attribute string survives codegen → ends up in `.hexa.cap` section bytes verbatim → `xxd` of the `.so` shows the claim | identical (both routes write the same HXC v2 payload) |
| parser cost | **non-zero** — `@plugin(...)` needs the attribute-arglist parser path (today `@cite`/`@stability` accept one string; this needs `string[]`) | zero — `.tape` parser already exists in `stdlib/tape/` |
| dynamic capability | impossible (decided at compile time) | impossible *anyway* (HXC is a static blob); declarative file gains nothing here |
| cross-file capability composition | requires multi-import per-fn merge (a `core` lib's `@plugin` capability claim applies only when the lib's dispatch fn is exported, which is forbidden by §3.B fat-`.so` convention — so only the top-level `<plugin_id>` carries `@plugin`) | technically allows a single `.cap.tape` to declare for many plugins, but our fat-`.so` model ships one plugin per `.so`, so this is moot |
| bypass risk | low — author cannot write a capability without the source line being visible in PR review | **higher** — sidecar edits in a separate PR file are easy to miss in code review |

**Verdict**: option **(A)** wins on the two anchors that matter most — `@D g3` honesty (source = truth) and `@D g6` precedent (uniform attribute pattern). The parser cost is real but bounded (a one-shot extension of the existing `@cite`/`@stability` parser to accept `string[]`). Option (B) is **declined** for shipping, but retained as a fallback if a future "no parser changes allowed" constraint surfaces (none today).

Authoring example (illustrative, **NOT yet legal** — parser support is G7-D.impl):

```hexa
// stdlib/wilson_plugins/example/main.hexa
@plugin(capabilities = [
    "net.outbound.https",      // can open outbound HTTPS sockets
    "fs.read.config",          // can read $WILSON_CONFIG_DIR/**
    "compute.gpu.kernel",      // can call hxcuda/hxmetal kernels
])
@cite("RFC 070 §3.C, §4.6")
pub fn example_dispatch(action: HexaVal, payload: HexaVal) -> HexaVal {
    // ... single-symbol fat-.so dispatch entry, ABI = §3.A option (b)
}
```

#### 4.6.2 Design choice — ABI stamp record (**LOCKED**)

`__HEXA,__abi` (Mach-O) / `.hexa.abi` (ELF) is a **fixed 12-byte** record, little-endian:

```
offset  field                    type     meaning
0..4    runtime_version          u32 LE   self/runtime.c semver-packed (major<<16 | minor<<8 | patch)
4..12   nanbox_layout_hash       u64 LE   stable hash of NanBox tag layout + payload sizes (compiler-emitted)
```

- **Why fixed 12 B and not HXC**: ABI mismatch must be detectable by the host **before** invoking the HXC parser (because the HXC parser itself depends on a stable `HexaVal` ABI). Treating ABI stamp as a typed 12-byte read + 2 integer compares is dependency-free and `dlerror`-loud.
- **`runtime_version`** anchor: `self/runtime.c::HEXA_RUNTIME_VERSION` macro (already exists; G7-D.impl wires the codegen-side read). Bump rules = standard semver (major = nanbox layout change, minor = API surface add, patch = body change).
- **`nanbox_layout_hash`** anchor: SHA-256 (first 8 bytes) over the canonical `NanBox` tag enum literal text + each payload's `sizeof`. Compiler computes at build time; host's runtime ships the same hash baked into rodata. Mismatch = silent nanbox corruption risk — refuse load.

Capability manifest section `__HEXA,__cap` / `.hexa.cap` stays HXC v2 per §3.C (the parser dependency is OK once `__abi` has gated ABI compat). Schema:

```
CapManifest {
    plugin_id:       string,        // matches <plugin_id>_dispatch sole exported symbol
    capabilities:    string[],      // verbatim from @plugin attribute (sorted ascending for determinism)
    rfc_version:     u32,           // RFC 070 revision number (this RFC = 1)
    compiler_id:     string,        // "hexa_v2 <build hash>" (audit trail; not gated on)
}
```

Host gate (G7-D.impl pseudocode, **not landed this sub-cycle**):

```hexa
// stdlib/dynlink_caps.hexa (skeleton-only this commit; bodies = G7-D.impl)
pub fn dynlink_check_compat(so_path: string) -> int {
    // 1. read __abi 12 B; if mismatch, hexa_dlerror = "ABI: host vN.M.P vs plugin vN'.M'.P'"
    // 2. read __cap HXC; parse CapManifest
    // 3. for each c in cap.capabilities: if !grant_table.contains(c) -> refuse, hexa_dlerror = "CAP: <c> not granted"
    // 4. return handle id on PASS; 0 on any refusal
    return 0  // skeleton stub
}
```

#### 4.6.3 What this commit lands (Shape B scaffold, **zero behavior change**)

1. **This §4.6** (the section you are reading) + §6 first-punted-decision flipped to RESOLVED + §4 phase table G7-D row split into `G7-D.scaffold ✅` + `G7-D.impl` (mirrors the §4.3 / §4.4 / §4.5 scaffold-row pattern).
2. **`stdlib/dynlink_caps.hexa`** — new file, **skeleton only**. Contains: file header (`// @cite RFC 070 §4.6`), three fn signatures with `return 0` / empty bodies, two struct definitions (`CapManifest`, `AbiStamp`). **No** parser/codegen wiring, **no** import into `stdlib/dynlink.hexa` (which itself doesn't exist yet — G7-C scope), **no** test. Pure shape lock.
3. **`compiler/codegen/plugin_attr_scaffold.hexa`** — new file, **header-comment-only scaffold marker**. ≈40 lines documenting where `@plugin(capabilities=[...])` parser hook + `__HEXA,__cap` / `__HEXA,__abi` section-emit will land in `compiler/codegen/{arm64_darwin,x86_64_linux}.hexa` at G7-D.impl. **No** code, no parser change.
4. **`compiler/PLAN.md`** — 1-line entry pointing to this §4.6.

**Out of scope (`@D g3`-honest)**:
- No `compiler/parser` change. `@plugin(...)` is **still a parse error** today.
- No `compiler/codegen` change. `.so` artifacts still have **zero** `__HEXA,__cap` / `__HEXA,__abi` sections.
- No `self/runtime.c` change. `hexa_dlopen` (which itself doesn't exist yet — G7-C scope) does **not** gate on ABI or capabilities.
- No `stdlib/dynlink.hexa` (G7-C). No `stdlib/dynlink_caps.hexa` body — only the file skeleton. No host gate. No F-D1/F-D2 measurement.
- No `hexa_v2` regen, no binary promote (`@D g_commit_push_deploy` waits for G7-D.impl).
- No `archive/patches/PATCHES.yaml` touch.

#### 4.6.4 Falsifier reaffirmation (real-limit anchored per `@D g3`)

§4.1's F-D1 + F-D2 are **unmeasured**; G7-D.scaffold reaffirms the contract they will gate on:

- **F-D1** (compiler invariant, ABI stamp): `dlopen` of a `.so` whose `.hexa.abi` 12-byte record disagrees with the host's `(runtime_version, nanbox_layout_hash)` MUST refuse with a `dlerror` string matching the regex `^ABI: host v\d+\.\d+\.\d+ vs plugin v\d+\.\d+\.\d+$` OR `^ABI: nanbox_layout_hash mismatch \([0-9a-f]{16} vs [0-9a-f]{16}\)$`. Real-limit anchor = ABI invariant (a stale `.so` MUST NOT execute against a runtime whose `HexaVal` shape it was not compiled against — silent execution = guaranteed memory corruption per nanbox tagging spec).
- **F-D2** (compiler invariant, capability gate): `dlopen` of a `.so` whose `.hexa.cap` `CapManifest.capabilities` list contains a capability NOT in the host's `grant_table` MUST refuse with a `dlerror` string matching `^CAP: <c> not granted$` where `<c>` is the **first** ungranted capability in sort order. Real-limit anchor = least-privilege contract (`@D g4`-flavored honesty: an untrusted plugin getting net.outbound when the host config only granted fs.read.config is a privilege escalation; refusing is the **only** sound response).

Both falsifiers are deterministic and replicable from a 1-fn `.hexa` source + a 2-line host-config grant table. G7-D.impl will land a `tool/g7d_falsify.sh` harness mirroring the `tool/g7a_falsify.sh` pattern from §4.5.

#### 4.6.5 Files this commit touches

- `docs/rfc/rfc_drafts_2026_05_20/rfc_070_hexa_ld_dlopen_shared.md` — status header `g7-a-falsify-measured` → `g7-d-scaffold`; §4 phase table G7-D row split; §4.6 added (this section, ≈120 lines); §6 first punted decision flipped to RESOLVED with cross-link to §4.6.1.
- `stdlib/dynlink_caps.hexa` — new file, ≈45 lines (skeleton fn signatures + struct shapes + `@cite RFC 070 §4.6.2`).
- `compiler/codegen/plugin_attr_scaffold.hexa` — new file, ≈40 lines (header-comment scaffold marker + integration plan).
- `compiler/PLAN.md` — 1-line entry pointing to this §4.6.

cross-link: §3.C capability gate · §3.D ABI version stamp · §4.1 F-D1/F-D2 falsifier anchors · §4.4 G7-A.native scaffold (parallel "scaffold-only marker for impl sub-cycle" pattern) · §6 first punted decision (now RESOLVED) · `@D g3` real-limits-first (F-D1 anchored on nanbox ABI invariant; F-D2 anchored on least-privilege contract) · `@D g5` hexa-native-only (decision **A** stays in-source = hexa-native; **B** would have introduced a sidecar file format dependency) · `@D g6` citation-enforced-strict-lint (in-source attribute pattern mirrors `@cite`) · `@D g_hxc` HXC v2 wire (CapManifest payload only — ABI stamp is fixed 12 B for dependency-free verification) · `@D g_inbox_processing_loop` Shape B (scaffold + design decision lock; impl is a separate measured cycle).

## 5. Open questions (verbatim from source patch §7 + 2026-05-20 status)

1. **libc `dlopen` dependency** — hexa runtime already FFI-calls `dlopen` from multiple modules (§2 audit). G7 widens that; it doesn't introduce. If a future "no libc" mandate lands, option (c) custom loader is the bridge.
2. **nanbox ABI stability** — closed by §3.D ABI stamp. Required, not optional.
3. **Is (d) sufficient?** — wilson MVP decides. RFC 070 is not on the wilson critical path; G7-A is the smallest first step if-and-only-if wilson measures G8 incremental link as too slow.
4. **`hexa_ld` has never emitted dynamic** — true. G7-B is the biggest single piece of work. Phasing keeps it isolated.

## 6. Decision punted

- **Tooling for capability manifest authoring** (Phase D): ~~is it a `@plugin(capabilities=...)` attribute on the dispatch fn, or a sidecar `.hexa.cap.tape` declarative file? Decide at G7-D start.~~ **RESOLVED 2026-05-20 G7-D scaffold (§4.6)** — adopted **(A) `@plugin(capabilities=...)` in-source attribute** on the dispatch fn. Sidecar `.hexa.cap.tape` declined per `@D g3` real-limits-first (source ≠ manifest is a silent-drift hazard; in-source attribute lives in the same SSOT as the dispatch fn body, so an audit grep can prove no capability is claimed without the dispatch fn observing it). See §4.6.1 for the full trade-off matrix.
- **Hot reload semantics**: does `dynlink_close` followed by `dynlink_open` of an updated `.so` require quiescence on outstanding handles? Decide at G7-E.
- **Versioned `dlsym` (a la ELF symbol versioning `@@VER`)**: probably no for the fat-single-symbol model; revisit if (a) full-dynamic is later adopted.

## 7. One-liner

`hexa cc --shared` (PIC, hidden-by-default, only `<plugin_id>_dispatch` exported) + `hexa_ld --shared` (ET_DYN/MH_DYLIB, 1-symbol dynsym) + `self/runtime.{c,h}` `hexa_dlopen/dlsym/dlclose` + `stdlib/dynlink.hexa` + `.so` `.hexa.cap` (HXC v2) and `.hexa.abi` (runtime/nanbox hash) sections with host gate. Phased G7-A..G7-F across ≥3 cycles. **Option (d) "skip G7, use G8 incremental + multi-call" remains valid if wilson measures G7 cost > G8 incremental cost.**

---

## Appendix — original patch preserved

Source: `archive/patches/g7-hexa-ld-dlopen.md` (opened 2026-05-10). All §1-§8 of that patch are absorbed verbatim or near-verbatim into §1, §2, §3, §5, §7 of this RFC. The original markdown stays in `archive/patches/` with status `rfc-promoted 2026-05-20 (RFC 070)`.
