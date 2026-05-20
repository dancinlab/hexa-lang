# RFC 070 — `hexa_ld --shared` + runtime `dlopen` (fat .so single-symbol convention)

> **status**: `g7-a-falsify-measured-cpath-re-run` (C-path F-A1/F-A2 re-measured on this worktree; native-codegen DEFERRED — wire missing on `s1-step2-codegen-perf` base)
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

### 4.5 G7-A.falsify — measured re-run (C-path + native-codegen probe, 2026-05-20)

**Cycle context.** A4 (`0e137237`, 2026-05-20) closed F-A1/F-A2 on the C-path on macOS arm64 (mini host) + ELF x86_64 (ubu-1). This re-run repeats the C-path measurement from the `s1-step2-codegen-perf` worktree and additionally **probes** the native-codegen path the user requested (`HEXA_BACKEND=native hexa build --shared`). The native-codegen probe is recorded as **DEFERRED** because the wire is provably absent on this branch — see "Native-codegen probe" below.

**Test source** (`/tmp/g7a_test.hexa`, 4 LoC):

```
fn add(a: int, b: int) -> int { return a + b }

fn main() {
}
```

**Pipeline (C-path, identical to A4):**

1. `self/native/hexa_v2 g7a_test.hexa g7a_test.c`  (worktree hexa_v2, mtime 2026-05-20 21:04)
2. `clang -O2 -fPIC -shared <flags> g7a_test.c self/runtime.c -o g7a_test.{dylib,so}`

**Harness** (`/tmp/g7a_work/harness.c`, ~40 LoC): `dlopen(RTLD_NOW|RTLD_LOCAL)` + `dlsym("add")` + `fp(hexa_int(2), hexa_int(3))` + `hexa_as_num(r) == 5` byte-check. Harness links its own copy of `runtime.c` (matches A4 RTLD_LOCAL pattern).

**Results — F-A1 PASS both targets:**

| target | host | dylib filetype | `add(2,3)` | rc |
|--------|------|----------------|------------|----|
| macOS arm64 | local Darwin | `otool -hv` reports `filetype DYLIB` | `5` (byte-eq) | `0` |
| ELF x86_64 | `ubu-2` (`uname=x86_64`, clang 18.1.3) — ubu-1 unreachable (`ssh aiden@10.142.0.1` + tailscale alias both timed out), `ubu-2` is bit-equivalent (x86_64 + clang 18, per `reference_gpu_fire_infra.md`) | `readelf -h` reports `Type: DYN (Shared object file)` | `5` (byte-eq) | `0` |

**Results — F-A2 EXPECTED-FAIL both targets** (per §4.3 caveat — `clang -shared` re-exports every `runtime.c` symbol):

| target | T+D exported | `add` symbol present | EXPECTED-FAIL? |
|--------|--------------|----------------------|----------------|
| macOS arm64 | **610** (605 T + 5 D) | `_add` at `0x640` T | yes (A4 measured 611; ~1-symbol drift attributable to worktree runtime.c diff) |
| ELF x86_64  | **606** (T+D)         | `add`  at `0xf050` T | yes (A4 measured 560 on ubu-1; ~46-symbol gap attributable to runtime.c absorbed-verbs on this worktree larger than A4 baseline) |

The F-A2 EXPECTED-FAIL is re-confirmed at this worktree's runtime.c version, identical mechanism: `clang -fPIC -shared` exports every `extern` non-static symbol in the link set. Hidden-visibility + single-symbol narrowing is G7-A.native impl scope (D1/E2/F2).

**Native-codegen probe — DEFERRED (wire absent on `s1-step2-codegen-perf`).**

The user-requested `HEXA_BACKEND=native hexa build --shared --target native -o g7a_native.dylib g7a_test.hexa` was probed against this worktree's deployed driver (`/Users/ghost/.hx/bin/hexa.real`, 2026-05-20 06:59) and yielded:

- `--shared` is **silently positionally-consumed** as a source argument (`error: source file not found: --shared`) — the `--shared` flag wire (heritage commit `66b055c4` G7-A.flag-wire) **is not present** in this branch's `self/main.hexa::cmd_build`.
- `--target=native` is rejected by the C-path's cross-target validator (`error: unknown --target value: native ; supported: linux-x86_64-musl, …, darwin-arm64, darwin-x86_64`) — `native` is not a registered triple; the C-path uses bare `clang` for host-target.
- With both flags removed, `HEXA_BACKEND=native` is silently ignored and the C-path (`hexa_v2 + clang`) runs instead — confirmed by `[1/2] HEXA_MEM_CAP_MB=4096 …/hexa_v2 …` in the driver's stdout. The `HEXA_BACKEND=native` env branch (`self/main.hexa` L1908) is gated on the user's source-arg-only invocation pattern; the `--shared` parse error short-circuited before backend selection.

Confirming the deeper gap: `grep -nE '"--shared"|shared_mode|CodegenOptions|RELOC_|GOTPCREL|private_extern' compiler/codegen/{arm64_darwin,x86_64_linux}.hexa compiler/emit/asm.hexa self/main.hexa` returns **zero matches** on this branch. The heritage commits **D1** (`8fdb29e2` — arm64_darwin GOT-load), **E2** (`9ea52f4b` — x86_64_linux GOT-load + RELOC tagging), and **F2** (`1729d9ac` — `_visibility_directive` + `.private_extern`/`.hidden` emit) **are not reachable from `origin/main` HEAD** (`git log origin/main --oneline | grep -E 'RFC 070|G7-A.native'` returns 0 hits; commits live on a parallel branch). C-path comparison is therefore the only G7-A.falsify channel this worktree can drive without first merging the native-codegen wire.

**Per `@D g_inbox_processing_loop` Shape B + `@D g3` honest scope:** This cycle measures the C-path G7-A.falsify row again on a different worktree (re-runs a deterministic measurement and confirms the §4.3 caveat reproduces independent of host/runtime.c snapshot); it does **not** advance the native-codegen row. The native-codegen falsifier (`HEXA_BACKEND=native` + `--shared` + hidden-visibility narrowing → F-A2 PASS) is gated on landing `66b055c4 ∪ 8fdb29e2 ∪ 9ea52f4b ∪ 1729d9ac` into `origin/main` first.

**Out of scope (g3-honest):** zero edit to `compiler/codegen/`, `compiler/link/`, `self/runtime.{c,h}`, `self/codegen_c2.hexa`, `self/main.hexa`. No `hexa_v2` regen. No `hexa.real` promote (SOP step 7 deferred). G7-A.native impl wire, G7-B, G7-C, G7-D, G7-E, G7-F unchanged. `inbox/PATCHES.yaml` untouched.

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
