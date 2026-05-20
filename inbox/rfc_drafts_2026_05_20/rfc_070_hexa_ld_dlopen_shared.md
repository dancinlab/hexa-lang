# RFC 070 — `hexa_ld --shared` + runtime `dlopen` (fat .so single-symbol convention)

> **status**: `g7-a-flag-wire-landed` (`hexa build --shared` parses + clang `-fPIC -shared` pass-through; F-A1/F-A2 falsifiers are the next measured sub-cycle)
> **opened**: 2026-05-20 (promoted from `inbox/patches/g7-hexa-ld-dlopen.md`, opened 2026-05-10)
> **G7-A flag wire**: 2026-05-20 (`self/main.hexa::cmd_build` + dispatch — flag-wiring only, zero falsifier coverage yet)
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
| G7-A.native impl | Honor `bopts[4]=="1"` (the `shared` flag wired in G7-A.flag-wire) inside the native-codegen entry points (`codegen_arm64_darwin` / `codegen_x86_64_linux`). PIC mode emits: (a) `adrp Xn, sym@GOTPAGE` + `ldr Xn, [Xn, sym@GOTPAGEOFF]` for arm64 extern fn refs; (b) `lea rax, [rip+sym@GOTPCREL]` for x86_64 extern fn refs; (c) per-function `.hidden` directive default, `.globl` only for `<plugin_id>_dispatch`. Falsifiers F-A1/F-A2 run on the native-codegen output. | G7-A.native scaffold | F-A1, F-A2 (native) |
| G7-A.falsify | F-A1 (PIC re-load at non-default base) + F-A2 (single-`T`/`D` `<plugin_id>_dispatch` symbol via `nm`) measured on the C-path `.so`/`.dylib` produced by G7-A.flag-wire. | G7-A.flag-wire | F-A1, F-A2 |
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
