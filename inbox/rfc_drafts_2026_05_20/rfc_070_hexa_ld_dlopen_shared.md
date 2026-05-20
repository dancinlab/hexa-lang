# RFC 070 — `hexa_ld --shared` + runtime `dlopen` (fat .so single-symbol convention)

> **status**: `drafted` (scaffold + RFC text · no behavior change · multi-cycle phased)
> **opened**: 2026-05-20 (promoted from `inbox/patches/g7-hexa-ld-dlopen.md`, opened 2026-05-10)
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
