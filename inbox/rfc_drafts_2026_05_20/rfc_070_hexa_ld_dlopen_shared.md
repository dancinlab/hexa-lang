# RFC 070 — `hexa_ld --shared` + runtime `dlopen` (fat .so single-symbol convention)

> **status**: `g7-b-v16-elf-st-shndx-fix-MEASURED` (hexa_ld v1.6 ELF dynsym `st_shndx` fix LANDED + MEASURED 2026-05-20 ubu-1 — F-B-LOADABLE-ELF invoke + byte-eq PASS end-to-end; `dlsym -> 0x736895b50000` confirms `l_addr + 0x1000` resolution; `fn(2,3) == 5`. v1.5 SHN_ABS short-circuit closed. Mach-O Part B deferred per Shape-B fallback — worktree base lacks F1's v1.5 Mach-O Part A which is the cherry-pick prerequisite. See §4.7.7.) [previously `g7-b-loadable-measured` (F-B-LOADABLE measured on v1.5: Mach-O end-to-end PASS · ELF dlopen+dlsym PASS, invoke FAIL per honest scope — v1.6 fix root-cause from §4.7.6 anchor).] [previously `g7-d-impl-parser-landed`: capability-manifest authoring decision LOCKED = `@plugin(capabilities=[...])` in-source attribute; ABI stamp `(runtime_version: u32, nanbox_layout_hash: u64)` section layout LOCKED; `stdlib/dynlink_caps.hexa` skeleton + `compiler/codegen/plugin_attr_scaffold.hexa` skeleton landed · `self/parser.hexa` `@plugin` attribute dispatcher LANDED 2026-05-20 — annotation channel `"plugin|<raw-tokens>"`, parse-gate PASS · zero codegen change · §4.6 below]
> **opened**: 2026-05-20 (promoted from `inbox/patches/g7-hexa-ld-dlopen.md`, opened 2026-05-10)
> **G7-A flag wire**: 2026-05-20 (`self/main.hexa::cmd_build` + dispatch — flag-wiring only, zero falsifier coverage yet)
> **G7-A falsify** : 2026-05-20 (F-A1/F-A2 measured on C path · macOS arm64 dylib + ubu-1 ELF x86_64 .so · §4.5 below)
> **G7-A.native impl.falsify retry probe** : 2026-05-20 (DEFERRED on `worktree-agent-ad2ddf5f5886b924a` HEAD `116cdbf7` — heritage cascade `66b055c4`/`0c4b91da`/`2a579ce8`/`06bc2ea4`/`8fdb29e2`/`9ea52f4b`/`1729d9ac` absent from both `origin/main` and worktree branch; `--shared` rejected as source-arg, `HEXA_BACKEND=native` silently ignored, `aprime_cc` absent · re-confirms G3 (`92caea74`) DEFERRED · §4.5b below)
> **G7-D scaffold** : 2026-05-20 (design choice locked + section layout + skeleton stubs · §4.6 below · zero behavior change · falsifier F-D1/F-D2 unmeasured)
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
| G7-A.native impl.iface ✅ | `compiler/ir/lir.hexa` lifts `pub struct CodegenOptions { shared: i64, target_triple: string }` + `codegen_options_default()` helper + 5 reloc-kind string constants (`RELOC_AARCH64_ADR_GOT_PAGE`, `RELOC_AARCH64_LD64_GOT_LO12_NC`, `RELOC_X86_64_GOTPCREL`, `RELOC_X86_64_PC32`, `RELOC_X86_64_PLT32`). Interface-only — zero emit body change. **LANDED 2026-05-20** (commit `2a579ce8`). | G7-A.native scaffold | — (iface only) |
| G7-A.native impl.signature ✅ | `codegen_arm64_darwin(module, opts: CodegenOptions)` + `codegen_x86_64_linux(module, opts)` entry signatures lifted; 11 caller sites updated to pass `codegen_options_default()`. Emit body byte-identical with `opts.shared == 0`. **LANDED 2026-05-20** (commit `06bc2ea4`). | G7-A.native impl.iface | corpus byte-eq (default opts) |
| G7-A.native impl.emit-body ✅ | `_arm64_op_rm` + `_x86_op_rm` / `_x86_op_resolve` honor `opts.shared`. PIC mode emits: (a) `adrp Xn, sym@GOTPAGE` + `ldr Xn, [Xn, sym@GOTPAGEOFF]` for arm64 global refs (`MACHO_ARM64_RELOC_GOT_LOAD_*` / `R_AARCH64_*_GOT_*`); (b) `mov scratch, [rip+sym@GOTPCREL]` for x86_64 global refs (`R_X86_64_GOTPCREL`). `emit/asm.hexa::_fmt_mem` honors the new `label`-as-offset memory operand shape. Per-instruction reloc-kind tag carried via `LInstr.comment` suffix `[reloc=…]` for the future asm-text emitter dispatch. arm64 = commit `8fdb29e2` (D1 partial). x86_64 = this sub-cycle (D2 — `_x86_op_rm` global+`opts.shared==1` GOT-load branch + `_x86_op_resolve` global→reg fallback). Default `opts.shared == 0` keeps both backends byte-identical with pre-iface output. | G7-A.native impl.signature | corpus byte-eq (default opts), measured F-A1/F-A2 deferred → G7-A.native impl.falsify |
| G7-A.native impl.visibility | (a) per-function `.hidden` (ELF) / `.private_extern` (Mach-O) directive default; (b) `.globl` only for `<plugin_id>_dispatch`. Sits in the LIR→asm text emitter (currently `compiler/emit/asm.hexa` plus a future per-function visibility hook). Carries the export-set narrowing that flips F-A2 from EXPECTED-FAIL to PASS (today's clang `-shared` exports every public symbol — see G7-A.falsify caveat). | G7-A.native impl.emit-body | F-A2 (native) |
| G7-A.native impl.falsify | Run F-A1 (dlopen + dlsym + call on native-codegen output) + F-A2 (single-`.globl` export set) on the native-emit artifact on both macOS arm64 + ubu-1 x86_64. **Retry probe 2026-05-20 (§4.5b) — DEFERRED on `worktree-agent-ad2ddf5f5886b924a` HEAD `116cdbf7`**: heritage cascade (`66b055c4` + `0c4b91da` + `2a579ce8` + `06bc2ea4` + `8fdb29e2` + `9ea52f4b` + `1729d9ac`) absent from both `origin/main` and this worktree branch; `--shared` rejected as source-arg, `HEXA_BACKEND=native` silently ignored, `aprime_cc` binary absent. Re-confirms G3 (`92caea74`) DEFERRED with bit-identical blocker set. | G7-A.native impl.visibility | F-A1, F-A2 (native) |
| G7-A.falsify ✅ | F-A1 PASS both platforms (dlopen + dlsym(`add`) + call → 5 byte-equally · macOS arm64 dylib + ubu-1 ELF x86_64 .so). F-A2 EXPECTED-FAIL both platforms per §4.3 caveat (Mach-O = 611 exported T/D symbols · ELF = 560 exported T/D symbols · `add` is one of them, not the sole one — clang `-shared` alone exports every public symbol; single-symbol narrowing is G7-A.native impl scope). Measured 2026-05-20, **C path only** (`hexa_v2 → clang -fPIC -shared`, NOT native-codegen). | G7-A.flag-wire | F-A1, F-A2 (measured · F-A2 = expected-fail caveat) |
| G7-B (v1.3 scaffold) ✅ | header-only ET_DYN/MH_DYLIB stub (no dynamic section / export trie) | G7-A | F-B1, F-B3 (header-format only) |
| G7-B (v1.4 ELF Part A) ✅ | `build_elf64_dyn_with_dynamic` adds PT_DYNAMIC + .dynsym + .dynstr + .hash + DT_SONAME + 1 exported FUNC symbol `<ident>_dispatch` | G7-B (v1.3) | F-B1, F-B2, F-B-DYNSYM-ELF (audit-EXPECTED) |
| G7-B (v1.5 Mach-O Part A + ELF wire) ✅ | `_build_macho_arm64_dylib_image_v1_5` (LC_ID_DYLIB + LC_DYLD_INFO_ONLY single-export trie + LC_SYMTAB + LC_DYSYMTAB + LC_CODE_SIGNATURE) + `_link_elf_shared` wires v1.4 Part A through `link_shared()` for the first time. **LANDED 2026-05-20** (commit `0a5ef2d2`). | G7-B (v1.4) | F-B1, F-B2, F-B3, F-B-EXPORTTRIE-MACHO (audit-EXPECTED), F-B-LOADABLE (measurement-deferred) |
| G7-B.falsify (F-B-LOADABLE measured) ✅ | dlopen + dlsym + invoke harness on real v1.5 link_shared output, both platforms. **Mach-O PASS end-to-end** (dlopen + dlsym + invoke(2,3)=5 byte-eq). **ELF PARTIAL PASS** (dlopen handle non-null + dlsym non-null + dlerror clean — but invoke SEGV because v1.5 dynsym `st_value` is file-offset not base-relative; reloc-record consumption is the deferred v1.6+ sub-cycle per v1.5 honest scope). Measured 2026-05-20 mini (Darwin 25.5.0 arm64) + ubu-1 (Ubuntu 24.04 x86_64). See §4.7. | G7-B (v1.5) | F-B-LOADABLE-MACHO (PASS, byte-eq) · F-B-LOADABLE-ELF (PASS dlopen+dlsym, FAIL invoke — honest-scope confirmed) · F-B-DYNSYM-ELF (PASS) · F-B-EXPORTTRIE-MACHO (PASS) |
| G7-B (v1.6 ELF dynsym st_shndx fix) ✅ | Both ELF dynsym builders (`_build_elf64_dyn_payload` L862, `build_elf64_dyn_with_dynamic_reloc` L1193) rewrite the export `<ident>_dispatch` symbol's `st_shndx` from `SHN_ABS` (`0xFFF1`) to `1` (pseudo text-section index). G6 (`32dfa0cf`) root-caused the measured ELF invoke SEGV to glibc's `SYMBOL_ADDRESS` short-circuiting and returning `st_value` AS-IS for SHN_ABS symbols. Any non-ABS, non-UNDEF shndx makes ld.so add `l_addr` to produce the runtime address (`l_addr + st_value`). glibc/musl ld.so do NOT walk the section-header table on this decision — only the `== SHN_ABS` check matters — so the absent section-header table (e_shoff=0, e_shnum=0) stays valid. Header docs L69+ updated. **LANDED 2026-05-20 + MEASURED ubu-1.** | G7-B (v1.5) | F-B-LOADABLE-ELF invoke (MEASURED PASS — see §4.7.5) |
| G7-B (v1.6+ reloc-record path / Mach-O Part B) | (a) ELF: `_apply_text_relocs(buf, secs)` consumes `R_X86_64_GOTPCREL` / `R_AARCH64_ADR_GOT_PAGE` / `R_AARCH64_LD64_GOT_LO12_NC` / `X86_64_RELOC_GOT_LOAD` / `ARM64_RELOC_GOT_LOAD_PAGE21` from input `.o`, rewrites text, emits matching `.rela.dyn` for non-text-local refs (covers PIC binaries with external GOT refs). (b) Mach-O Part B: LC_DYLD_INFO_ONLY rebase/binds/lazy_binds opcodes + `__DATA_CONST,__got` section materialization for external-symbol references in the dylib path — currently `_build_macho_arm64_image(is_shared=true)` emits LC_MAIN-only and dyld rejects at load time when bind targets exist. (Note: v1.5 Mach-O Part A `_build_macho_arm64_dylib_image_v1_5` is on origin/main F1 `0a5ef2d2`, not yet on `s1-step2-codegen-perf`; cherry-pick is a parallel prerequisite for the Part B sub-cycle on this branch.) | G7-B (v1.6) | F-B-LOADABLE-ELF (full PIC end-to-end with imports) · F-B-LOADABLE-MACHO-IMPORTS |
| G7-C  | `self/runtime.{c,h}` adds `hexa_dlopen/dlsym/dlclose/dlerror`; `stdlib/dynlink.hexa` ships | G7-B (or independent if consuming pre-built `.so` only) | F-C1, F-C2 |
| G7-D.scaffold ✅ | Capability-manifest authoring **decision locked = `@plugin(capabilities=[...])` in-source attribute** (sidecar `.hexa.cap.tape` declined per `@D g3` honesty anchor). ABI stamp record layout LOCKED = `(runtime_version: u32, nanbox_layout_hash: u64)` little-endian, 12 B fixed. `stdlib/dynlink_caps.hexa` skeleton (parse + check_compat + check_grant fn shells, no body) + `compiler/codegen/plugin_attr_scaffold.hexa` (header-comment-only scaffold marker for `@plugin` attribute parser hook). **Zero behavior change.** | G7-C (section emit) | none yet — scaffold only |
| G7-D.impl.parser ✅ | `self/parser.hexa` learns `@plugin(capabilities=[...])` attribute — paren-balanced raw-token accumulator, serialized into `p_pending_annotations` as `"plugin|<raw-tokens>"` (matches `@cli`/`@flag`/`@doc` storage convention; string-array literal inside `capabilities=[…]` admitted via the bracket-aware depth counter). Parse-gate `hexa_real parse self/parser.hexa` PASS. Self-test `@plugin(capabilities=["net.outbound"]) fn …` parses cleanly. **LANDED 2026-05-20** (this sub-cycle, Shape A surgical; deployed-binary regen = standard deploy). Zero codegen change — `__HEXA,__cap` / `__HEXA,__abi` section emit + manifest sort + `dynlink_caps.hexa` body wiring = G7-D.impl.codegen + G7-D.impl.runtime (future sub-cycles). | G7-D.scaffold | — (parse-gate only) |
| G7-D.impl.codegen | `compiler/codegen` emits `__HEXA,__cap` (Mach-O) / `.hexa.cap` (ELF) section with HXC v2-encoded `CapManifest{ plugin_id, capabilities[], rfc_version }`; emits `__HEXA,__abi` / `.hexa.abi` section with `AbiStamp{ runtime_version, nanbox_layout_hash }`. Consumes `plugin|...` annotation from G7-D.impl.parser. | G7-D.impl.parser | F-D1 |
| G7-D.impl.runtime | `stdlib/dynlink_caps.hexa` bodies populated. Host `hexa_dlopen` MUST refuse mismatched ABI + ungranted capabilities. | G7-D.impl.codegen | F-D1, F-D2 |
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

### 4.5b G7-A.native impl.falsify retry probe (2026-05-20, **DEFERRED — heritage absent on `worktree-agent-ad2ddf5f5886b924a` HEAD `116cdbf7`**)

After G3 (`92caea74`) re-confirmed the C-path on a different host pair and formally DEFERRED native-codegen on `s1-step2-codegen-perf`, the user requested a **paired retry cycle from a downstream worktree** (`worktree-agent-ad2ddf5f5886b924a`, branched off main before the G7-A cascade landed) on the premise that "현재 main 에 G7-A 전체 ... 모두 land". The premise was tested directly; this sub-section records the **probe diagnostic** that re-confirms DEFERRED with the explicit blocker pair surfaced.

**Branch topology probed** (2026-05-20):

| commit | role | ancestor of `worktree-agent-ad2ddf5f5886b924a` HEAD (`116cdbf7`)? | ancestor of `origin/main`? |
| --- | --- | --- | --- |
| `66b055c4` | G7-A.flag-wire (`self/main.hexa` `--shared` parser) | NO | NO |
| `0c4b91da` | G7-A.native scaffold (codegen headers) | NO | NO |
| `2a579ce8` | G7-A.native impl.iface (`CodegenOptions` + 5 RELOC_* consts) | NO | NO |
| `06bc2ea4` | G7-A.native impl.signature (11 caller sites) | NO | NO |
| `8fdb29e2` | G7-A.native impl.emit-body arm64 (`_arm64_op_rm` GOT-load) | NO | NO |
| `9ea52f4b` | G7-A.native impl.emit-body x86_64 (`_x86_op_rm` GOT-load) | NO | NO |
| `1729d9ac` | G7-A.visibility scaffold (`.private_extern`/`.hidden`) | NO | NO |
| `92caea74` | G3 C-path re-run + DEFERRED record | NO | NO |

All eight heritage commits live on the parallel branch `rfc070-g7-native-scaffold` (and on `s1-step2-codegen-perf`'s tip — both 14 commits ahead of where this worktree branched). `origin/main` HEAD (`b4ed80a7` after `git fetch origin main`, 2026-05-20) reaches NONE of them. The user-stated premise "현재 main 에 G7-A 전체 ... 모두 land" is **factually incorrect for both `origin/main` and this worktree's HEAD** as of measurement time.

**Probe — two stacked blockers measured on the worktree HEAD**:

1. **Driver wire absence** (heritage `66b055c4` not landed). Direct shell:

   ```
   $ SIDECAR_NO_POOL=1 HEXA_MAC_BUILD_OK=1 HEXA_BACKEND=native \
       /Users/ghost/.hx/bin/hexa_real build --shared --target darwin-arm64 \
       -o /tmp/g7a_native.dylib /tmp/g7a_test.hexa
   error: source file not found: --shared
   ```

   The deployed `hexa.real` (size `599424`, mtime `May 20 06:59`) refuses `--shared` (consumed positionally as a source path). Same refusal verbatim as G3's record: G3 measured this on `s1-step2-codegen-perf`; the re-measurement on this worktree branch reproduces it deterministically.

2. **Source-side wire absence on worktree HEAD** (heritage `66b055c4` not in `self/main.hexa` either). `grep -nE '"--shared"|shared_mode|CodegenOptions|RELOC_|GOTPCREL|private_extern|_visibility_directive|\.private_extern|\.hidden' compiler/codegen/arm64_darwin.hexa compiler/codegen/x86_64_linux.hexa compiler/emit/asm.hexa self/main.hexa` → **zero matches** for `--shared` / `CodegenOptions` / `RELOC_` / `GOTPCREL` / `private_extern` / `_visibility_directive` / `.private_extern` / `.hidden`. Two faint matches (one in each codegen file) are prior-art comments about "shared MIR" / "hidden first arg" — semantically unrelated. So even if the deployed driver were regenerated from THIS worktree's `self/main.hexa`, the rebuilt `hexa.real` would STILL not recognize `--shared` (the wire was added on a sibling branch, not here).

3. **`aprime_cc` binary absent** (stacks on top of #1+#2). `find . -name aprime_cc -type f` → empty. `self/main.hexa::resolve_native_cc()` (L1586) returns `""`; `cmd_build` L1989 calls `die_no_native_cc()` which prints `HEXA_BACKEND=native requires a built aprime_cc` and `exit(1)`. So even if blockers #1+#2 were removed, `HEXA_BACKEND=native` would die-loud before any codegen attempt. (The C-path runs because `HEXA_BACKEND=native` is silently ignored by the current deployed driver — the dispatch block at L1986-2062 is in the SSOT but not in the deployed binary.)

**Empirical confirmation that `HEXA_BACKEND=native` is silently ignored by the deployed driver** (= probe of #1's stack interaction):

```
$ SIDECAR_NO_POOL=1 HEXA_MAC_BUILD_OK=1 HEXA_BACKEND=native \
    /Users/ghost/.hx/bin/hexa_real build /tmp/g7a_test.hexa -o /tmp/g7a_native_b
=== Building /tmp/g7a_test.hexa -> /tmp/g7a_native_b ===
  [1/2] HEXA_MEM_CAP_MB=4096 .../hexa_v2 /tmp/g7a_test.hexa build/artifacts/g7a_native_b.c
    OK: build/artifacts/g7a_native_b.c
  [2/2] clang -O2 ... build/artifacts/g7a_native_b.c .../runtime.c -o ...
OK: built /tmp/g7a_native_b
```

No `[native 1/2]` / `[native 2/2]` lines (which would be the SSOT-side native dispatch markers at L2032/L2044). The driver ran the C-path silently. This proves the L1986-2062 native-dispatch block is NOT present in the deployed `hexa.real` — the binary was built from a pre-`66b055c4` source snapshot, consistent with the binary's `mtime` (06:59 UTC) preceding `66b055c4` on the sibling branch.

**Per-platform F-A1 / F-A2 status** (paired to the §4.5 C-path measurement table):

| platform | F-A1 native | F-A2 native | reason |
| --- | --- | --- | --- |
| macOS arm64 (mini, this worktree HEAD) | **DEFERRED** | **DEFERRED** | blocker #1 (`--shared` rejected as source-arg) + blocker #2 (worktree SSOT also missing wire) + blocker #3 (no `aprime_cc`) |
| ELF x86_64 (ubu-1 / ubu-2) | **DEFERRED — not attempted** | **DEFERRED — not attempted** | same three blockers are properties of the source/binary pair, not the host. ubu-1 (`aiden@10.142.0.1` + `ubu1-ts-d`) both timed out at SSH connect; ubu-2 (`/usr/bin/clang` present) would run the same `hexa.real` (same `--shared` rejection) and the same heritage-absent SSOT, so a measurement there adds no information beyond #1-#3 already-surfaced on macOS. |

**Visibility scaffold effect on F-A2** (separate from F-A1 dispatch dispute): the `_visibility_directive` + `.private_extern` / `.hidden` per-function directive emission (heritage `1729d9ac`) is the SSOT change that would flip F-A2 from the §4.5 measured `611/560` "exported-everything" failure into a narrowed export set. This worktree HEAD has **zero matches** for `.private_extern` / `.hidden` / `_visibility_directive` in `compiler/emit/asm.hexa` — the scaffold itself is absent. So F-A2 native-narrowing **cannot be probed** here even if the dispatch worked. The visibility-effect measurement remains pinned to the heritage cascade landing on this branch.

**ABORT classification** (per task spec):

- The two ABORT conditions explicitly listed by the user — "native backend가 multi-arg fn 미지원" and "F-A2 native가 여전히 ALL-EXPORT (visibility scaffold 무효)" — are **neither reachable nor refutable** from this worktree HEAD because the cascade that would enable measurement is not in scope. The blocker is the **earlier-in-pipeline** "wire is absent + binary stale" pair, which is the third (implicit) ABORT — heritage absent. Honest report per `@D g3`: native-codegen retry probe **DEFERRED**; the only forward path is the heritage cascade landing on `origin/main` (or the worktree branch being rebased onto a tip that contains it), followed by a fresh deploy step regenerating `hexa.real`, followed by an `aprime_cc` build (`tool/build_aprime.sh`). Three deploy steps are SOP-bounded prerequisites — `@D g_inbox_processing_loop` step 7 explicitly out-of-scope for this cycle.

**Files (SSOT docs only, zero code change)**:

- `inbox/rfc_drafts_2026_05_20/rfc_070_hexa_ld_dlopen_shared.md` — copied from `s1-step2-codegen-perf` into this worktree (the file did not yet exist here because the worktree branched before A4's RFC promote); this §4.5b appendix appended documenting the retry probe + DEFERRED record.
- `compiler/PLAN.md` — single 진행 로그 entry per `@D g_plan_consolidation`, cross-linking this §4.5b.

**Out of scope (`@D g3`-honest)**: zero edit to `compiler/codegen/`, `compiler/emit/`, `compiler/ir/`, `compiler/link/`, `self/runtime.{c,h}`, `self/codegen_c2.hexa`, `self/main.hexa`. No `hexa_v2` regen. No `aprime_cc` build. No `hexa.real` promote. No cherry-pick of the heritage cascade (would be its own multi-commit merge, out of single-cycle scope). `inbox/PATCHES.yaml` untouched. Other-session WIP files untouched per `@D g_inbox_processing_loop` hazard guard (d). G7-A.native impl.falsify row in the §4 phase table stays UNCHECKED (no `✅`) — measurement remains owed and is pinned to the cascade's landing on this branch.

cross-link: §4.5 G7-A.falsify C-path measurement (the table this retry mirrors) · §4.4 G7-A.native scaffold (the cascade row this retry would advance) · `@D g_inbox_processing_loop` Shape B + `@D g3` honest scope (retry surfaces blockers, does not advance state without measurement) · `@D g_commit_push_deploy` (deployed `hexa.real` predates `66b055c4` even on the SSOT-bearing sibling branch — a fresh deploy step is the cross-branch prerequisite) · G3 (`92caea74`) parallel DEFERRED record (this retry's blocker set is bit-identical to G3's diagnostic).

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
- No `inbox/PATCHES.yaml` touch.

#### 4.6.4 Falsifier reaffirmation (real-limit anchored per `@D g3`)

§4.1's F-D1 + F-D2 are **unmeasured**; G7-D.scaffold reaffirms the contract they will gate on:

- **F-D1** (compiler invariant, ABI stamp): `dlopen` of a `.so` whose `.hexa.abi` 12-byte record disagrees with the host's `(runtime_version, nanbox_layout_hash)` MUST refuse with a `dlerror` string matching the regex `^ABI: host v\d+\.\d+\.\d+ vs plugin v\d+\.\d+\.\d+$` OR `^ABI: nanbox_layout_hash mismatch \([0-9a-f]{16} vs [0-9a-f]{16}\)$`. Real-limit anchor = ABI invariant (a stale `.so` MUST NOT execute against a runtime whose `HexaVal` shape it was not compiled against — silent execution = guaranteed memory corruption per nanbox tagging spec).
- **F-D2** (compiler invariant, capability gate): `dlopen` of a `.so` whose `.hexa.cap` `CapManifest.capabilities` list contains a capability NOT in the host's `grant_table` MUST refuse with a `dlerror` string matching `^CAP: <c> not granted$` where `<c>` is the **first** ungranted capability in sort order. Real-limit anchor = least-privilege contract (`@D g4`-flavored honesty: an untrusted plugin getting net.outbound when the host config only granted fs.read.config is a privilege escalation; refusing is the **only** sound response).

Both falsifiers are deterministic and replicable from a 1-fn `.hexa` source + a 2-line host-config grant table. G7-D.impl will land a `tool/g7d_falsify.sh` harness mirroring the `tool/g7a_falsify.sh` pattern from §4.5.

#### 4.6.5 Files this commit touches

- `inbox/rfc_drafts_2026_05_20/rfc_070_hexa_ld_dlopen_shared.md` — status header `g7-a-falsify-measured` → `g7-d-scaffold`; §4 phase table G7-D row split; §4.6 added (this section, ≈120 lines); §6 first punted decision flipped to RESOLVED with cross-link to §4.6.1.
- `stdlib/dynlink_caps.hexa` — new file, ≈45 lines (skeleton fn signatures + struct shapes + `@cite RFC 070 §4.6.2`).
- `compiler/codegen/plugin_attr_scaffold.hexa` — new file, ≈40 lines (header-comment scaffold marker + integration plan).
- `compiler/PLAN.md` — 1-line entry pointing to this §4.6.

cross-link: §3.C capability gate · §3.D ABI version stamp · §4.1 F-D1/F-D2 falsifier anchors · §4.4 G7-A.native scaffold (parallel "scaffold-only marker for impl sub-cycle" pattern) · §6 first punted decision (now RESOLVED) · `@D g3` real-limits-first (F-D1 anchored on nanbox ABI invariant; F-D2 anchored on least-privilege contract) · `@D g5` hexa-native-only (decision **A** stays in-source = hexa-native; **B** would have introduced a sidecar file format dependency) · `@D g6` citation-enforced-strict-lint (in-source attribute pattern mirrors `@cite`) · `@D g_hxc` HXC v2 wire (CapManifest payload only — ABI stamp is fixed 12 B for dependency-free verification) · `@D g_inbox_processing_loop` Shape B (scaffold + design decision lock; impl is a separate measured cycle).

### 4.7 G7-B.falsify F-B-LOADABLE measured (2026-05-20, **Mach-O end-to-end PASS · ELF dlopen+dlsym PASS, invoke deferred per v1.5 honest scope**)

After F1 (`0a5ef2d2` hexa_ld v1.5 Mach-O Part A + ELF Part A wire) landed the dynamic-section containers, F1's own honest scope flagged **F-B-LOADABLE** as measurement-deferred ("attempted via /tmp/test_dylib_emit.hexa harness — parse-gate PASS, build blocked on 'compiled module_loader not found'"). This sub-cycle closes that gap by building a minimal **driver** that imports `compiler/link/hexa_ld.hexa` and calls `link_shared()` on a real `.o`, then runs dlopen + dlsym + invoke harnesses on the produced artifact across both target platforms.

**Driver path** (worktree-local, no binary promote per `@D g_commit_push_deploy` deferred): `/tmp/g7b_loadable/g7b_driver.hexa` (15 LoC, env-var I/O paths, `link_shared(inp, out)` single call). Built via the deployed `hexa.real` `build` verb after a one-line surgical SSOT edit at `compiler/link/incr_cache.hexa::_save_meta_tsv` (dead-from-driver-pov body stubbed because the unrelated `write_text` builtin gap blocks flatten — fix is a separate `stdlib/io.hexa` import wiring sub-cycle; see honest-scope §4.7.4).

**Trivial PIC source** (no external refs, no GOT/PLT — v1.5's pre-reloc-record path requires this):

```c
long add(long a, long b) { return a + b; }
```

Compiled on each platform with `clang -fPIC -c trivial.c -o trivial.o`. The driver's `link_shared(trivial.o, output.{so,dylib})` invocation routes through `_link_elf_shared` or `_link_mach_o_shared` per the 4-byte magic check at `hexa_ld.hexa:2174`.

#### 4.7.1 Mach-O (mini · Darwin 25.5.0 arm64) — **end-to-end PASS**

| stage | result | evidence |
|-------|--------|----------|
| `link_shared(trivial.o, trivial_v15.dylib)` rc | 0 | driver stdout `link_shared(...) -> rc=0`; output size 33272 B |
| `file` artifact | Mach-O 64-bit dynamically linked shared library arm64 | F-B3 PASS |
| `otool -hv` | `MH_MAGIC_64 ARM64 ALL 0x00 DYLIB 7 448 NOUNDEFS DYLDLINK TWOLEVEL` | F-B3 PASS |
| LC inventory | LC_SEGMENT_64 (×2) · LC_ID_DYLIB · LC_DYLD_INFO_ONLY · LC_SYMTAB · LC_DYSYMTAB · LC_CODE_SIGNATURE (exactly the 7 LCs F1 advertised) | LC-set audit PASS |
| `dyld_info -exports` | 1 entry: `0x00004000  _trivial_v15.dylib_dispatch` | F-B-EXPORTTRIE-MACHO PASS (single-symbol trie) |
| `dlopen(./trivial_v15.dylib, RTLD_NOW \| RTLD_LOCAL)` | handle `0x74d78a40` non-null | F-B-LOADABLE-MACHO dlopen PASS |
| `dlsym(h, "trivial_v15.dylib_dispatch")` | `0x102444000` non-null, `dlerror()` clean | F-B-LOADABLE-MACHO dlsym PASS |
| invoke `fn(2, 3)` | returns `5` | F-B-LOADABLE-MACHO invoke + byte-eq PASS |

**Verdict**: Mach-O path **end-to-end PASS** — dlopen + dlsym + invoke + byte-eq all green. F1's v1.5 Mach-O Part A is loadable for real, not just header-format valid.

#### 4.7.2 ELF (ubu-1 · Ubuntu 24.04 x86_64) — **dlopen + dlsym PASS, invoke deferred**

Mac driver was used cross-platform: it accepts ELF `.o` magic (`7F 45 4C 46`) and routes to `_link_elf_shared`. The produced `.so` was scp'd to ubu-1 for dlopen measurement.

| stage | result | evidence |
|-------|--------|----------|
| `link_shared(trivial_elf.o, trivial_v15.so)` rc | 0 | driver stdout; output size 8415 B |
| `file` artifact | ELF 64-bit LSB shared object, x86-64, version 1 (SYSV), dynamically linked, no section header | F-B1 PASS |
| `readelf -h` Type | `DYN (Shared object file)` | F-B1 PASS |
| `readelf -d` dynamic | 7 entries — HASH (0x205b) · STRTAB (0x2000) · SYMTAB (0x202b) · STRSZ (43 B) · SYMENT (24 B) · SONAME (`trivial_v15.so.so`) · NULL | F-B2 PASS (SONAME present), F-B-DYNSYM-ELF PASS (dyn-table present + populated) |
| `objdump -T` dynsym | 1 entry: `0000000000001000 g    DF *ABS*  16 trivial_v15_clean_dispatch` | single-export PASS (vs F-A2 EXPECTED-FAIL clang-shared baseline of 559-606 exports) |
| `dlopen(./trivial_v15_clean, RTLD_NOW \| RTLD_LOCAL)` | handle `0x597dda8df2c0` non-null, `dlerror()` clean | F-B-LOADABLE-ELF dlopen PASS |
| `dlsym(h, "trivial_v15_clean_dispatch")` | `0x1000` non-null, `dlerror()` clean | F-B-LOADABLE-ELF dlsym PASS |
| invoke `fn(2, 3)` | **SEGV** | F-B-LOADABLE-ELF invoke FAIL — root-caused below |

**Root cause** (via `dlinfo(RTLD_DI_LINKMAP)` probe — `probe2` harness): dlsym returns `p = 0x1000` and `link_map.l_addr = 0x78b8bc208000`, so `(p - l_addr)` underflows to `0xffff874743df9000` — i.e. `st_value=0x1000` was emitted as a **file-offset literal** but `dlsym` returns it directly without adding `l_addr`. The text *is* at file offset 0x1000 (verified by `xxd -s 0x1000` returning the exact trivial.o `add` bytes `55 48 89 e5 …`), but the dynsym `st_value` semantics require base-relative offsets for `ld.so` to compute the runtime address as `l_addr + st_value`. F1's v1.5 ELF Part A emits `st_value` from file offset, which is the **next sub-cycle's** fix.

This matches F1's own honest scope verbatim (`compiler/link/hexa_ld.hexa:2210-2211`): "ld.so will still bail at runtime IF the text contains absolute relocations (no R_X86_64_GOTPCREL processing yet — see CAVEATS L62 + RFC 070 §6 G7-A reloc-record path)". The measured ELF failure mode is *not* a missing reloc on the text (the text IS PIC, no R_X86_64_64 inside it), but rather the dynsym `st_value` encoding — a parallel ABI gap that ships in the same v1.6+ sub-cycle.

**Verdict**: ELF path **partial PASS** — dlopen + dlsym succeed (handle valid, symbol resolved, no `dlerror`), invoke fails per v1.5 honest scope. F-B-DYNSYM-ELF + F-B-EXPORTTRIE-MACHO (audit-EXPECTED PASS in F1) now **empirically MEASURED PASS** on both platforms.

#### 4.7.3 Falsifier matrix update

| ID | platform | F1 v1.5 contract | this cycle measurement |
|----|----------|------------------|------------------------|
| F-B1 | both | header format Type:DYN | PASS both |
| F-B2 | ELF | DT_SONAME present | PASS ubu-1 |
| F-B3 | Mach-O | filetype DYLIB | PASS mini |
| F-B-DYNSYM-ELF | ELF | .dynsym + .dynstr + .hash populated, 1 FUNC export | PASS ubu-1 (audit-EXPECTED → empirical) |
| F-B-EXPORTTRIE-MACHO | Mach-O | LC_DYLD_INFO_ONLY single-export trie | PASS mini (audit-EXPECTED → empirical) |
| F-B-LOADABLE-MACHO | Mach-O | dlopen + dlsym + invoke + byte-eq | **PASS** mini (end-to-end) |
| F-B-LOADABLE-ELF | ELF | dlopen + dlsym + invoke + byte-eq | **PARTIAL PASS** ubu-1 (dlopen+dlsym PASS, invoke FAIL — v1.6+ scope) |

#### 4.7.4 Out of scope (`@D g3`-honest)

- **No `compiler/link/hexa_ld.hexa` change** (F1's v1.5 is the SSOT under measurement).
- **No `hexa_v2` regen, no binary promote** — driver was built against the deployed `hexa.real` (06:59 UTC) using `HEXA_MODULE_LOADER=<repo>/build/hexa_module_loader` + `HEXA_LANG=<worktree>`.
- **One surgical SSOT edit at `compiler/link/incr_cache.hexa::_save_meta_tsv`** — body stubbed because `write_text` (stdlib/io.hexa) is not imported into incr_cache.hexa and not codegen-wired. The fn is dead-from-driver-pov; this lets the module flatten complete. The `stdlib/io.hexa` import wiring + `write_text` codegen extern entry is a **separate sub-cycle** (filed as a follow-up note); the TSV mirror is currently unused (SSOT = the `.hxc` cache).
- **No ELF v1.6 reloc-record fix** — root-causing the invoke SEGV (dynsym `st_value` file-offset vs base-relative) is the v1.6+ sub-cycle. This cycle is **measurement only**.
- **No Mach-O / ELF cross-platform parity beyond `add`** — single trivial function. Multi-symbol export trie + R_X86_64_64 absolute-reloc detection refusal are out of scope.
- **No `inbox/PATCHES.yaml` touch**.

#### 4.7.5 Files this commit touches

- `inbox/rfc_drafts_2026_05_20/rfc_070_hexa_ld_dlopen_shared.md` — status header `g7-d-impl-parser-landed` → `g7-b-loadable-measured`; §4 phase table G7-B row split into v1.3 / v1.4 / v1.5 / v1.5.falsify / v1.6+ rows; §4.7 added (this section). File was brought into the worktree base from the sister branch (`s1-step2-codegen-perf` only — base lacked it).
- `compiler/link/hexa_ld.hexa` — F1 cherry-pick (`0a5ef2d2` → local `3248786d` via `e55a19b6`). v1.4 → v1.5 SSOT delta. Worktree base lacked F1.
- `compiler/link/incr_cache.hexa` — `_save_meta_tsv` body stubbed (`write_text` builtin gap workaround). File restored from `55d007e5` (RFC 071 §G8-B substrate) since worktree base lacked it.
- `compiler/PLAN.md` — single entry pointing to §4.7.

#### 4.7.6 Real-limit grounding (`@D g3`)

- **F-B-LOADABLE-MACHO** anchor: POSIX 2017 `dlopen`/`dlsym` contract + Apple `<mach-o/loader.h>` `MH_DYLIB` filetype semantics (dyld walks LC_DYLD_INFO_ONLY export trie, returns `base + addr`). The invoke result `fn(2,3) == 5` anchors on **integer-arithmetic determinism** (the C `long + long` ABI invariant).
- **F-B-LOADABLE-ELF (dlopen+dlsym half)** anchor: System V gABI §4 (PT_DYNAMIC + DT_HASH + DT_SYMTAB + DT_STRTAB resolution). The measurement proved ld.so successfully consumed v1.5's dynamic section.
- **F-B-LOADABLE-ELF (invoke half)** anchor: System V gABI §4.18 — `Elf64_Sym::st_value` semantics for `SHN_*ABS*`-typed FUNC symbols inside `ET_DYN` files. Real-limit: ld.so DOES add `l_addr` to `st_value` for relocatable symbols, but `*ABS*` symbols are treated as absolute. The fix is to mark dispatch symbols as relocatable (`st_shndx` pointing to the text section, not `SHN_ABS`), so ld.so's resolution `l_addr + st_value` lands on the right virtual address. This is the v1.6+ sub-cycle's job.

cross-link: §4.1 falsifier battery · §4.5 G7-A.falsify (parallel measurement pattern, F-A1 PASS / F-A2 EXPECTED-FAIL contract) · `@D g3` real-limits-first (POSIX dlopen + SysV gABI + Apple Mach-O spec anchors) · `@D g5` hexa-native-only (hexa_ld is the hexa-native dynamic linker — no LLVM lld, no system ld) · `@D g_inbox_processing_loop` Shape A (smallest measurement closure — driver-only SSOT edit, no SSOT to hexa_ld itself).

### 4.7.7 G7-B v1.6 ELF dynsym st_shndx fix MEASURED (2026-05-20, **F-B-LOADABLE-ELF invoke → end-to-end PASS · Mach-O Part B deferred per Shape-B**)

Follow-on to G6 (`32dfa0cf`) which root-caused the F-B-LOADABLE-ELF invoke SEGV to glibc's SHN_ABS short-circuit. This sub-cycle lands the surgical SSOT fix at both ELF dynsym builders and re-runs the same harness on ubu-1 to verify end-to-end.

**SSOT edits** (`compiler/link/hexa_ld.hexa`):

1. `_build_elf64_dyn_payload` L862 — `_push_u16le(dynsym, 0xFFF1)` → `_push_u16le(dynsym, 1)`.
2. `build_elf64_dyn_with_dynamic_reloc` L1193 — same byte change at the v1.5 reloc-record path's export entry.
3. Header docs L69+ — new v1.6 CAVEATS bullet (root cause + fix mechanism); historical v1.5 block preserved verbatim.

**Driver** (`/tmp/build_g7b/driver`): same shape as §4.7.3's `g7b_driver.hexa` — `use "compiler/link/hexa_ld"`, `env("HEXA_G7B_IN")` + `env("HEXA_G7B_OUT")`, `link_shared(inp, out)` single call. Build pipeline `HEXA_LANG=<worktree> HEXA_MODULE_LOADER=<worktree>/build/hexa_module_loader HEXA_MAC_BUILD_OK=1 hexa.real build`. The `mv` final stage is intercepted by wilson-pool on this host so the `.tmp.<pid>` salvage is `cp .tmp -> driver && chmod +x` (no-op on the binary itself).

**Build object**: `/tmp/trivial_v16.c` (`long add(long a, long b) { return a + b; }`) cross-compiled on ubu-1 (Ubuntu 24.04 x86_64) via `clang -fPIC -c trivial_v16.c -o trivial_v16.o` → 976 B ELF64 relocatable. scp'd back to mini for `hexa_ld v1.6` link_shared invocation.

| stage | result | evidence |
|-------|--------|----------|
| `link_shared(trivial_v16.o, trivial_v16.so)` rc | 0 | driver stdout `link_shared(... .so) -> rc=0` |
| `readelf -h trivial_v16.so` Type | `DYN (Shared object file)` | F-B1 PASS |
| `objdump -T trivial_v16.so` dynsym | `0000000000001000 g    DF .text 0000000000000016 trivial_v16_dispatch` | **st_shndx renders `.text`** (v1.5 emitted `*ABS*`) — v1.6 fix MEASURED at the binary level |
| `dlopen(./trivial_v16.so, RTLD_NOW \| RTLD_LOCAL)` | handle non-null, `dlerror()` clean | F-B-LOADABLE-ELF dlopen PASS |
| `dlsym(h, "trivial_v16_dispatch")` | `0x736895b50000` non-null, `dlerror()` clean | F-B-LOADABLE-ELF dlsym PASS — runtime address is `l_addr + 0x1000` (vs v1.5's raw `0x1000`) |
| invoke `fn(2, 3)` | returns `5` | **F-B-LOADABLE-ELF invoke + byte-eq PASS** end-to-end |

Harness `/tmp/harness_v16.c` (20 LoC, `dlopen RTLD_NOW \| RTLD_LOCAL` + `dlsym` + invoke + byte-eq + `dlerror` gates) exit code 0, stdout `PASS r=5`.

**Verdict**: ELF path **end-to-end PASS**. The single 2-byte st_shndx change (`0xFFF1` → `0x0001`) closes the G6 SEGV. No section header table emit needed — glibc's `SYMBOL_ADDRESS` decision short-circuits exclusively on `== SHN_ABS`. F-B-LOADABLE-ELF (invoke) PARTIAL PASS → **PASS**.

#### 4.7.7.1 Falsifier matrix update

| ID | platform | v1.5 measurement | v1.6 measurement |
|----|----------|------------------|------------------|
| F-B-LOADABLE-MACHO | Mach-O | PASS (mini, end-to-end) | unchanged (no Mach-O change this sub-cycle) |
| F-B-LOADABLE-ELF | ELF | PARTIAL PASS (invoke SEGV) | **PASS** (ubu-1, end-to-end · `dlsym -> 0x736895b50000` · `fn(2,3) == 5`) |

#### 4.7.7.2 Out of scope (`@D g3`-honest)

- **No Mach-O Part B this sub-cycle** (Shape-B fallback per task spec). Worktree base lacks F1's v1.5 Mach-O Part A (`_build_macho_arm64_dylib_image_v1_5` — on origin/main only); v1.5 Mach-O cherry-pick + Part B (LC_DYLD_INFO_ONLY binds + `__got` materialization) is its own paired sub-cycle. Current `_link_mach_o_shared` still routes through `_build_macho_arm64_image(is_shared=true)` which the file's own L1973 comment correctly flags ("dyld will reject the dylib at load time").
- **No `e_shoff` / section header table emit** — glibc/musl skip the SHT walk for the SHN_ABS check; adding NULL + .text headers would be cosmetic only (e.g. `readelf -S` polish). Section-header MATERIALIZATION is its own sub-cycle when GOT/PLT lay-down lands.
- **No reloc-record consumption** (`_apply_text_relocs` etc.) — this sub-cycle is the dynsym-shndx fix in isolation. GOT-typed text relocs that require `.rela.dyn` consumption + .got materialization remain v1.6+ scope per §4 phase table next row.
- **No `hexa_v2` regen, no binary promote** (`@D g_commit_push_deploy` deferred). Driver was built against deployed `hexa.real` (06:59 UTC).
- **No `inbox/PATCHES.yaml` touch.**

#### 4.7.7.3 Files this commit touches

- `compiler/link/hexa_ld.hexa` — three sites: dynsym builder L862 + L1193 (the byte change) + header docs L69 (v1.6 CAVEATS bullet). Net: +29 -7 (mostly the new comment block).
- `inbox/rfc_drafts_2026_05_20/rfc_070_hexa_ld_dlopen_shared.md` — §4 phase table v1.6 row added, v1.6+ row reframed to enumerate ELF reloc-record + Mach-O Part B as next sub-cycle; §4.7.7 (this section) added.
- `compiler/PLAN.md` — single entry pointing to §4.7.7.

#### 4.7.7.4 Real-limit grounding (`@D g3`)

- **F-B-LOADABLE-ELF (invoke half) v1.6 anchor**: glibc `elf/dl-lookup.c` (`SYMBOL_ADDRESS` macro in `include/link.h`) explicitly branches on `sym->st_shndx == SHN_ABS ? sym->st_value : map->l_addr + sym->st_value`. The v1.5 SHN_ABS encoding hit the first branch and lost `l_addr`; the v1.6 `st_shndx=1` encoding lands in the additive branch — same code path as a real `clang -shared` `.so`. Measured `dlsym -> 0x736895b50000` (a typical mmap'd `l_addr` + 0x1000) is the operational confirmation.
- The fix touches **0 bytes of `st_value` / DT_HASH / DT_SYMTAB layout** — it changes only the symbol's *meaning* from "absolute" to "relocatable", which is the gABI's intent for any FUNC symbol inside an `ET_DYN` shared object.

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

Source: `inbox/patches/g7-hexa-ld-dlopen.md` (opened 2026-05-10). All §1-§8 of that patch are absorbed verbatim or near-verbatim into §1, §2, §3, §5, §7 of this RFC. The original markdown stays in `inbox/patches/` with status `rfc-promoted 2026-05-20 (RFC 070)`.
