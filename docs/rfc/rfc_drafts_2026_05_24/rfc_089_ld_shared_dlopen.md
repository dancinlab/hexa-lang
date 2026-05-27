---
slug: rfc_089_ld_shared_dlopen
kind: rfc_draft
filed_from: cycle-2 RFC scan (g7-d-scaffold priority=high promote)
filed_at: 2026-05-24
priority: high
status: proposed
promoted_from: docs/rfc/rfc_drafts_2026_05_20/rfc_070_hexa_ld_dlopen_shared.md (g7-d-scaffold)
unblocks:
  - rfc_070  # hexa_ld --shared + runtime dlopen (fat .so single-symbol convention)
consumer_demand:
  - wilson in-process plugins (provider / tool / hook / view) — "drop a .so, no relink"
  - anima / nexus 동적 모듈 로드 (out-of-scope reuse, no filed patch yet)
external_llm_scope: 없음 (compiler/link + codegen + self/runtime.{c,h} + stdlib 작업)
---

# RFC 089 — `hexa_ld --shared` + runtime `dlopen` (promote RFC 070)

- **Status**: proposed (design-draft · RFC 070 의 정식 번호 promote + 잔여 phase 정리)
- **Date**: 2026-05-24
- **Severity**: HIGH (plugin 아키텍처의 동적 로딩 = wilson "core + N plugin" 의 재컴파일 0 경로)
- **Source**: `docs/rfc/rfc_drafts_2026_05_20/rfc_070_hexa_ld_dlopen_shared.md` (status `g7-d-scaffold`) + `archive/patches/g7-hexa-ld-dlopen.md` (opened 2026-05-10)
- **Implements**: 본 RFC = design + 잔여 phase 정의. 구현은 phase 별 별도 측정 사이클 (G7-C / G7-A.visibility / G7-D.impl).

> **번호 promote 안내**: RFC 070 의 "ld/dlopen" content 는 이미 `g7-d-scaffold` 상태로 substantial
> 하게 진행되어 있다 (§5 audit 참조 — G7-A flag-wire + native emit-body + G7-B ELF/Mach-O Part A·B
> + G7-D scaffold 모두 LANDED). cycle-2 RFC scan 이 priority=high 로 surface 한 것은 patch-file 의
> status string 이며, 실제로는 잔여 phase (G7-C runtime host surface + G7-A visibility 좁히기 +
> G7-D.impl) 만 OPEN 이다. 본 RFC 089 는 그 잔여 work 를 정식 번호로 묶고, `stdlib/c_ffi.hexa` ·
> RFC 084 (phi_rs cdylib) 와의 경계를 명확히 한다.

---

## 1. Motivation

### 1.1 plugin 아키텍처 · fat .so 동적 로딩

hexa-lang 의 `compiler/` 는 `hexa_ld` 자체 링커로 ELF64 + Mach-O **static** 바이너리를 emit 한다.
wilson 의 "core + N plugin" 구조는 현재 모든 in-process plugin (provider / tool / hook / view) 을
하나의 `wilson` 바이너리에 static link 하도록 강제한다. plugin 추가/제거/업데이트 = full
`wilson build` (codegen + relink, 수십초~분).

G7 (RFC 070) 이 여는 경로: plugin = 동적 라이브러리 (`.so` ELF / `.dylib` Mach-O),
`wilson` 이 런타임에 `dlopen` + `dlsym("<plugin_id>_dispatch")` 로 로드. plugin 추가 = `.so`
하나 떨구기, 재컴파일 0.

채택 디자인은 **(b) fat .so + 단일 심볼 컨벤션** (RFC 070 §3.A):

- plugin 의 transitive dep 을 `.so` 안에 전부 static-link (fat) → 외부 참조 0 → PLT 불필요, GOT 자기 데이터만.
- `.so` 는 단 하나의 심볼 `<plugin_id>_dispatch` 만 export.
- host↔plugin ABI surface = `HexaVal (*)(HexaVal action, HexaVal payload)` 함수 1개 (nanbox 표현 공유).

**Honest scope (@D g3)**: 이 경로는 런타임 확장성을 원하는 *모든* hexa-lang consumer 에게 유용
(wilson 이 첫 구체 demand). anima/nexus 도 관심을 표명했으나 filed patch 는 없다. priority=high
이지만 **blocking-none** — 없으면 wilson 은 G8 incremental link + busybox-multi-call (option (d))
로 동작 가능.

### 1.2 `stdlib/c_ffi.hexa` 와의 관계 (경계 명확화)

이 RFC 가 가장 자주 혼동되는 지점이다. 두 surface 는 **방향이 반대**다:

| | `stdlib/c_ffi.hexa` (이미 존재) | RFC 089 (`hexa_ld --shared` + runtime dlopen) |
|---|---|---|
| **로드 대상** | 외부 **libc-ABI** `.so` (libm, libsqlite3, …) — hexa 가 *consume* | hexa-emit `.so` — hexa 가 *produce* + *consume* |
| **누가 만들었나** | C/Rust/타 언어 컴파일러 + 표준 libc ABI | `hexa cc --shared` + `hexa_ld --shared` (이 RFC) |
| **심볼 규약** | 임의 (`sqrt`, `sqlite3_open`, …) — 외부 결정 | 단일 `<plugin_id>_dispatch` (이 RFC 가 강제) |
| **ABI** | C calling convention (int/double/ptr) | nanbox `HexaVal (*)(HexaVal, HexaVal)` |
| **surface** | `c_dlopen` / `c_dlsym` / `c_dlclose` (`stdlib/c_ffi.hexa:219+`) + `@link` extern fn | `dynlink_open` / `dynlink_call` / `dynlink_close` (`stdlib/dynlink.hexa`, 신규 G7-C) |
| **runtime** | `hexa_ffi_dlopen` / `hexa_ffi_dlsym` (`self/runtime.c:1869,1994` — extern-fn FFI shim) | `hexa_dlopen` / `hexa_dlsym` / `hexa_dlclose` / `hexa_dlerror` (신규 G7-C) |

즉 `c_ffi` 는 **이미 libc `dlopen` 의 FFI consumer** 다 (`@D g5` 위반 아님 — libc 표면을 넓히는 게
아니라 이미 쓰는 표면을 hexa-emit `.so` 쪽으로 한 번 더 쓰는 것). RFC 089 가 새로 더하는 것은
(a) hexa_ld 가 `dlopen` 가능한 `.so` 를 *emit* 하는 능력, (b) nanbox-ABI 단일-심볼 dispatch 규약,
(c) 그 규약 위의 host-side `dynlink_*` wrapper + capability/ABI 게이트다. libc `dlopen`/`dlsym`
저수준 호출은 `c_ffi` 의 `hexa_ffi_dlopen` 를 재사용할 수 있다 (구현 디테일 — §2 참조).

## 2. Design

채택 결정은 RFC 070 §3.A 의 **(b) fat .so + 단일 심볼 컨벤션**. 본 §2 는 surface 별로
요약하고, 어디까지 LANDED 인지 / 무엇이 잔여인지 §5 audit 과 cross-link 한다.

### 2.A codegen — `hexa cc --shared` (cdylib/so emit)

```
hexa cc --shared <plugin>.hexa -o <plugin>.so      # ELF (Linux)
hexa cc --shared <plugin>.hexa -o <plugin>.dylib   # Mach-O (Darwin)
```

- PIC 코드. 모든 dep 을 `.so` 안에 static-link (fat).
- arm64-darwin: extern fn 참조가 GOT 경유 — `adrp Xn, sym@GOTPAGE` + `ldr Xn, [Xn, sym@GOTPAGEOFF]`.
  local fn 참조는 `@PAGE/@PAGEOFF` 유지.
- x86_64-linux: `lea Xrax, [rip+sym@GOTPCREL]` (extern) / `lea Xrax, [rip+sym]` (local).
  reloc kind = `R_X86_64_GOTPCREL` + `R_X86_64_PC32`.
- **hidden-visibility default** + `<plugin_id>_dispatch` 만 `.globl` (이게 단일-심볼 규약을 강제).

**상태 (§5 audit)**: emit-body GOT-load 분기 + CLI-wire = LANDED (RFC 070 §4.4 / §4.5).
**visibility 좁히기 (`.hidden`/`.private_extern` 디폴트 + 단일 `.globl`) = 잔여 (G7-A.native impl.visibility).**
오늘의 clang `-shared` 는 모든 public 심볼을 export 한다 (F-A2 EXPECTED-FAIL 의 측정된 원인).

### 2.B linker — `hexa_ld --shared` (ET_DYN / MH_DYLIB)

```
hexa_ld --shared --soname=<name> <obj> -o <out>.so
```

- ELF: `ET_DYN`, `e_entry = 0` (startup routine 없음), `.dynsym`/`.dynstr` 에 export 1개,
  `.hash`/`.gnu.hash`, `PT_DYNAMIC` + `DT_SONAME`.
- Mach-O: `MH_DYLIB`, `LC_DYLD_INFO_ONLY` export-trie 1심볼, `LC_DYSYMTAB`, `LC_ID_DYLIB`,
  `__DATA,__got` zero-fill, 실제 `BIND_OPCODE_DO_BIND` 레코드 (`dyld_stub_binder` ordinal 1).
- fat 라 외부 참조 0 → PLT 불필요, GOT 는 data-only.

**상태 (§5 audit)**: `pub fn link_shared(obj_path, out_path) -> int` 존재 — v1.3 hdr → v1.4 ELF
Part A → v1.5 ELF reloc → Mach-O Part A·B 까지 **LANDED** (`compiler/link/hexa_ld.hexa:2832`).
ELF F-B-LOADABLE 측정 완료. Mach-O F-B-LOADABLE 측정 사이클은 deferred.

### 2.C 단일 심볼 규약 (`<plugin_id>_dispatch`)

ABI surface = 함수 1개:

```hexa
// plugin 측 (single exported symbol)
@plugin(capabilities = ["net.outbound.https", "fs.read.config"])  // G7-D.impl 후 legal
@cite("RFC 089 §2.C")
pub fn example_dispatch(action: HexaVal, payload: HexaVal) -> HexaVal {
    // fat-.so dispatch entry — action 으로 라우팅, payload 는 nanbox 그대로
}
```

host 는 `dlsym("<plugin_id>_dispatch")` 단 1회 → `dynlink_call(handle, action, payload)` 로
nanbox 왕복. action 디스패치 (라우팅 테이블) 은 plugin 내부 책임.

### 2.D runtime dlopen wiring

`self/runtime.{c,h}` 에 host-side dynlink 표면 (G7-C, **잔여**):

```c
void*  hexa_dlopen(const char* path);           // dlopen(path, RTLD_NOW | RTLD_LOCAL)
void*  hexa_dlsym(void* handle, const char* name);
void   hexa_dlclose(void* handle);
const char* hexa_dlerror(void);
```

이들은 thin libc wrapper 다. 기존 `hexa_ffi_dlopen`/`hexa_ffi_dlsym` (`self/runtime.c:1869,1994`,
c_ffi 의 extern-fn shim) 의 형제이며 같은 libc `dlopen`/`dlsym` 을 호출한다 — 차이는 `RTLD_LOCAL`
강제 (plugin 심볼이 host process 와 공유되지 않음 → fat-.so 격리) + nanbox-ABI dispatch 전제.

hexa surface (`stdlib/dynlink.hexa`, **신규 · 잔여 G7-C**):

```hexa
// stdlib/dynlink.hexa (신규) — dynamic-module load (host 측)
// @cite RFC 089 §2.D
pub fn dynlink_open(so_path: string) -> int                          // handle id (0 = fail)
pub fn dynlink_call(handle: int, action: string, payload: any) -> any  // <id>_dispatch 호출
pub fn dynlink_close(handle: int) -> void
pub fn dynlink_last_error() -> string
```

`dynlink_open` 은 `hexa_dlopen` 호출 전에 capability/ABI 게이트 (`stdlib/dynlink_caps.hexa::
dynlink_full_gate`, G7-D scaffold skeleton — body 는 G7-D.impl) 를 통과시킨다.

### 2.E capability + ABI 게이트 (G7-D)

- 동적 plugin 은 capability 를 컴파일타임에 정적 보장 못 함 → `.so` 가 capability manifest 를
  custom section 에 싣고 host 가 `dlopen` 전 게이트.
- 결정 LOCKED (RFC 070 §4.6.1): authoring = **`@plugin(capabilities=[...])` in-source attribute**
  (sidecar `.hexa.cap.tape` 거절 — `@D g3` source≠manifest drift hazard).
- section: ELF `.hexa.cap` / Mach-O `__HEXA,__cap` (HXC v2 envelope) + ELF `.hexa.abi` /
  Mach-O `__HEXA,__abi` (고정 12 B: `runtime_version: u32 LE` + `nanbox_layout_hash: u64 LE`).
- ABI mismatch → host 가 `dlopen` 거부 (stale `.so` 의 silent nanbox 손상 방지). **필수.**

**상태**: `stdlib/dynlink_caps.hexa` skeleton + `compiler/codegen/plugin_attr_scaffold.hexa`
scaffold marker = LANDED (RFC 070 §4.6). parser `@plugin(...)` + section emit + body = **잔여 (G7-D.impl)**.

## 3. Falsifiers (real-limit anchored per `@D g3`)

| id | claim | real-limit anchor | 상태 |
|---|---|---|---|
| **F-089-SHARED-EMIT** | `hexa cc --shared trivial.hexa -o trivial.so` 가 `<plugin_id>_dispatch` 를 non-default base 에 re-load 가능한 PIC 파일로 emit (page granularity: x86_64 = 4 KiB, arm64-darwin = 16 KiB) | OS virtual-memory page granularity (RFC 070 F-A1) | C-path PASS · native-codegen 잔여 |
| **F-089-DLOPEN-LOAD** | `dynlink_open(path)` 가 존재하는 hexa-emit `.so` 를 로드해 0 아닌 handle 반환; 없는 path 는 0 + `dynlink_last_error()` non-empty (POSIX `dlopen` §3.A error contract) | POSIX 2017 `dlopen` 계약 (RFC 070 F-C1) | 잔여 (G7-C — host 표면 미존재) |
| **F-089-SINGLE-SYMBOL-DISPATCH** | `nm` 이 `<plugin_id>_dispatch` 단 1개의 global `T`/`D` 만 나열; 나머지는 local `t`/`d`. + `dynlink_call(h, "ping", payload)` 가 identity dispatch 에서 nanbox byte-eq 왕복 | ELF/Mach-O symbol-table format spec (gABI §4.18 / `<mach-o/nlist.h>`) + nanbox ABI byte-eq (RFC 070 F-A2 + F-C2) | EXPECTED-FAIL (clang `-shared` = 560-611 export) · visibility 좁히기 = 잔여 |
| **F-089-CROSS-PLATFORM** | 위 셋이 macOS arm64 (Mach-O DYLIB) + Linux x86_64 (ELF ET_DYN) **양쪽** PASS. `readelf -h ... Type: DYN` + `otool -hv ... filetype DYLIB` | ELF System V gABI §4 + Apple `<mach-o/loader.h>` (RFC 070 F-B1/F-B3/F-F1) | ELF Part A·B LANDED · Mach-O Part B SSOT-only (load 측정 deferred) |
| **F-089-NO-LLVM** | emit + link 경로 전체가 LLVM/C-transpile 없음 — `hexa_ld --shared` 가 native ET_DYN/MH_DYLIB 를 직접 byte-emit (clang `-fPIC -shared` 는 *fallback C-path* 일 뿐 self-host 경로 아님) | `@D g5` hexa-native-only + `@I` "no LLVM · no C-transpile" identity | native link_shared LANDED · native codegen `--shared` LANDED · clang fallback 은 별도 명시 |

**측정 기준 (`@D g3` honest)**: F-089-SHARED-EMIT / F-089-SINGLE-SYMBOL-DISPATCH 의 **native-codegen**
경로 (clang fallback 아님) 와 F-089-DLOPEN-LOAD 의 host 표면은 잔여 phase 에서 측정한다. C-path
(F-A1) 는 이미 양 플랫폼 PASS (RFC 070 §4.5). F-089-SINGLE-SYMBOL 은 visibility 좁히기 (G7-A.native
impl.visibility) 가 land 해야 EXPECTED-FAIL → PASS 로 flip.

## 4. Cross-link

- **`docs/rfc/rfc_drafts_2026_05_20/rfc_070_hexa_ld_dlopen_shared.md`** — 본 RFC 가 promote 하는 원본
  (status `g7-d-scaffold`). 전체 phase 표 (G7-A..G7-F) · falsifier battery (F-A1..F-F1) · §4.6
  G7-D 결정 lock · appendix 원본 patch 가 모두 그곳에 있다. 본 089 는 잔여 정리 + 번호 promote +
  c_ffi 경계 명확화 layer.
- **`archive/patches/g7-hexa-ld-dlopen.md`** — opened 2026-05-10, status `rfc-promoted 2026-05-20 (RFC 070)`.
  원본 spec.
- **`stdlib/c_ffi.hexa`** — 외부 libc-ABI `.so` 로드 (`c_dlopen`/`c_dlsym`/`c_dlclose`, L219+).
  RFC 089 의 *반대 방향* surface (hexa-emit `.so` produce+consume). §1.2 표 참조. 저수준 libc
  `dlopen` 은 `hexa_ffi_dlopen` (`self/runtime.c:1869`) 를 재사용 가능.
- **`stdlib/dynlink_caps.hexa`** — G7-D scaffold skeleton (capability/ABI 게이트 shell, body 미구현).
- **RFC 084 (`rfc_084_phi_rs_ffi_shim`, `docs/rfc/rfc_drafts_2026_05_23/`)** — phi_rs option A =
  **Rust cdylib + C-ABI export**. RFC 089 와 cdylib emit/load 형태가 인접하지만 *반대 끝*:
  RFC 084 는 외부 Rust crate 가 cdylib 를 만들고 hexa 가 c_ffi 로 consume (c_ffi 패밀리),
  RFC 089 는 hexa 가 자기 `.so` 를 만들고 단일-심볼 nanbox-ABI 로 consume. 둘 다 "cdylib 를
  dlopen" 이지만 ABI 규약 (C-ABI vs nanbox) 과 producer (Rust vs hexa) 가 다르다. 공유 인프라 =
  `hexa_ffi_dlopen` libc 저수준 호출.
- **`[[reference_hexa_module_loader_env_2026_05_20]]`** — `HEXA_MODULE_LOADER` env 미export 시
  `use` 모듈이 extern-only stub 으로 codegen → clang link 실패 (NULL-OBJECT silent fail).
  RFC 089 의 fat-.so 는 compile-time static-link 라 이 module-loader env 와 직교하지만, plugin
  `.hexa` 를 `hexa cc --shared` 로 빌드할 때 동일 4-line setup (PATH · HEXA_LANG · HEXA_MAC_BUILD_OK ·
  HEXA_MODULE_LOADER) 이 필요하다 — plugin source 의 `use` 의존이 fat `.so` 안으로 흡수되려면
  module loader 가 살아있어야 한다.
- **governance**: `@D g5` hexa-native-only (native codegen + native link_shared 가 hexa-native 경로 ·
  clang fallback 은 명시적 caveat) · `@D g_atlas_binary_builtin` (직교 — `.so`-loaded plugin 도
  host 의 baked-in atlas 에 bind) · `@D g3` real-limits-first (모든 falsifier 가 OS page granularity ·
  POSIX dlopen 계약 · ELF/Mach-O format spec · nanbox byte-eq 에 anchor).

## 5. Implementation audit (2026-05-24, main 기준 — 무엇이 LANDED / 잔여인지)

cycle-2 scan 이 본 RFC 를 priority=high 로 surface 했지만, RFC 070 은 stalled 가 아니라
**다중 사이클 진행 중**이다. main grep 기준:

| 표면 | 파일 | 상태 |
|---|---|---|
| codegen `--shared` emit-body (GOT-load) | `compiler/codegen/{arm64_darwin,x86_64_linux}.hexa` | LANDED (RFC 070 §4.4/§4.5) |
| codegen `--shared` CLI wire | `self/main.hexa::cmd_build` · `compiler/main.hexa` | LANDED |
| linker `link_shared` (ET_DYN/MH_DYLIB) | `compiler/link/hexa_ld.hexa:2832` | LANDED (ELF v1.5 + Mach-O Part B) |
| C-path `--shared` (clang `-fPIC -shared` fallback) | `self/main.hexa::cmd_build` | LANDED · F-A1 양 플랫폼 PASS |
| capability/ABI 게이트 skeleton | `stdlib/dynlink_caps.hexa` | LANDED (G7-D scaffold, body 미구현) |
| codegen `@plugin` attr scaffold marker | `compiler/codegen/plugin_attr_scaffold.hexa` | LANDED (header-comment only) |
| **runtime host surface** `hexa_dlopen/dlsym/dlclose/dlerror` | `self/runtime.{c,h}` | **잔여 (G7-C)** — 미존재 |
| **hexa surface** `stdlib/dynlink.hexa` | (신규) | **잔여 (G7-C)** — 미존재 |
| **visibility 좁히기** (단일 `.globl`) | codegen LIR→asm + `.hidden`/`.private_extern` | **잔여 (G7-A.native impl.visibility)** — F-089-SINGLE-SYMBOL flip |
| **`@plugin` parser + section emit** | `compiler/parser` + codegen `__HEXA,__cap`/`__abi` | **잔여 (G7-D.impl)** |
| Mach-O F-B-LOADABLE 측정 | dlopen + dyld_info 사이클 | **잔여 (deferred)** |

**잔여 우선순위 권고**:
1. **G7-C** (runtime host surface + `stdlib/dynlink.hexa`) — F-089-DLOPEN-LOAD 의 유일 blocker.
   기존 `hexa_ffi_dlopen` 재사용으로 작업량 작음 (thin wrapper + RTLD_LOCAL).
2. **G7-A.native impl.visibility** — F-089-SINGLE-SYMBOL EXPECTED-FAIL → PASS flip.
3. **G7-D.impl** — `@plugin` parser + section emit (capability gate 실제 게이팅).

## 6. One-liner

RFC 070 의 `hexa cc --shared` (PIC · hidden-by-default · `<plugin_id>_dispatch` 1심볼 fat `.so`) +
`hexa_ld --shared` (ET_DYN/MH_DYLIB · 1심볼 dynsym) + `self/runtime.{c,h}` host `dlopen` wrapper +
`stdlib/dynlink.hexa` + `.hexa.cap`/`.hexa.abi` capability·ABI 게이트를 정식 RFC 089 로 promote.
codegen + linker + scaffold 는 LANDED, 잔여 = G7-C (runtime host surface) + visibility 좁히기 +
G7-D.impl. `stdlib/c_ffi.hexa` 는 외부 libc-ABI `.so` consume (반대 방향) — RFC 089 는 hexa-emit
`.so` produce+consume + nanbox 단일-심볼 dispatch.
