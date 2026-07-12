Design complete. I read all four loci on origin/main plus the runtime scaffold. One **premise correction** up front, because it changes the byteeq claim: `runtime.a` **always** carries a real ctor today — `hxlcl_capture_environ` is emitted `__attribute__((constructor(101)))` **unconditionally** (`self/runtime_emit_full.hexa:63-66`, outside the `#ifdef HEXA_ZEROC_OWN_START`). So "zero-ctor" holds only for no-runtime links (unit-test/own-emit-only links); every runtime.a own-link will change bytes once pooling lands. Details in §4.

A second finding: on the **static** own-link path the ctor walk is not merely zero-trip — it is **never executed**: the hand stub calls `main` directly (`compiler/main.hexa:1278` passes `main_name="main"`), bypassing runtime.a's `_start`/`_hx_start_c`. And `_hx_run_init_array` is `static` + called once → clang inlines it into `_hx_start_c` (no callable symbol). So the static fix must route entry through `_hx_start_c`, not call the walk directly.

All edits are in `compiler/emit/elf_x86_64.hexa` (line numbers = origin/main).

---

## E1 — constant (`:37` area, after `ELF_SHT_NOBITS`)

```hexa
let ELF_SHT_INIT_ARRAY    = 14      // ctor fn-pointer array (.init_array / .init_array.NNNNN)
```

## E2 — `ElfX86Obj` gains a per-obj init pool (`:96-98`, after `data:`)

```hexa
    init_array: [u8],    // SHT_INIT_ARRAY pool (slot 6) — 8-byte ctor fn ptrs, link order
```

Update **both** struct literals (all-fields required — the m12 struct_lit-mirror lesson):
- `:3721` (`parse_elf_x86_obj`): add `init_array: [],` after `data: [],`
- `:4966` (`pack_lir_x86_64`, own-emit): add `init_array: [],` — own-emit never produces ctors, pool stays empty.

## E3 — reader Pass A: pool slot 6 (insert at `:3806`, after the NOBITS arm's closing, before `sec_slot.push`)

```hexa
        } else if stype == ELF_SHT_INIT_ARRAY && (flags & ELF_SHF_ALLOC) != 0 {
            // ctor array — pooled (slot 6) so relocs sited here survive Rung 1
            // and the linker can materialize a contiguous output .init_array.
            // Entries are 8-byte fn ptrs; keep the pool 8-aligned across
            // .init_array.NNNNN + plain .init_array members.
            slot = 6
            while (len(obj.init_array) % 8) != 0 { obj.init_array.push(0) }
            pbase = len(obj.init_array)
            let mut k = 0
            while k < ssize { obj.init_array.push(_er_u8(buf, base + soff + k)); k = k + 1 }
        }
```

That's the whole reader fix: Pass B then auto-rebases init-resident syms to `nsec=6` (`:3866`), and Pass C's Rung-1 drop no longer fires (`sec_slot != 0`), so the entries' `R_X86_64_64` relocs are kept with `site_seg=6` (`:3934`). Both plain `.init_array` and priority `.init_array.00101` match (selection is by `sh_type`, not name).

## E4 — pre-scan: init size + `_hx_start_c` presence (extend the env_cell scan, `:1898-1922`)

At `:1898` add alongside `env_cell`:

```hexa
    let mut hxsc_def   = false          // runtime.a OWN_START scaffold present
    let mut init_total = 0              // pooled .init_array byte size (all objs)
    let mut obj_init_base: [Int] = []   // region-relative base per obj (prefix sum)
```

Inside the existing per-obj loop (at its top, before the symbol walk):

```hexa
        obj_init_base.push(init_total)
        init_total = init_total + len(_eco.init_array)
```

and in the symbol-name arm next to the `_hxlcl_environ` check (`:1914`):

```hexa
                if _en == "_hx_start_c" { hxsc_def = true }
```

(Prefix sums are exact because each pool is internally 8-padded and sizes are 8-multiples, so concat preserves them.)

## E5 — static path: alternate entry stub (`:1924-1948`)

Before `if !crt_handoff {` at `:1925`:

```hexa
    // ── init-stub gate: a nonempty pooled .init_array on the STATIC path must
    // run via runtime.a's _hx_start_c (env store + _hx_run_init_array walk +
    // atexit-drain exit). _hx_run_init_array itself is `static` (inlined) — not
    // callable; _hx_start_c is __attribute__((used)) GLOBAL. Zero-ctor links
    // keep the exact old stub (byte-identical). Ctors with no runtime = loud fail.
    let init_stub = init_total > 0 && !crt_handoff
    if init_stub && !hxsc_def {
        eprintln("hexa_ld(elf,ownstart): .init_array ctor(s) present but no _hx_start_c (runtime.a OWN_START scaffold) to run them — refusing (silent ctor-skip)")
        return 3
    }
    if init_stub { env_cell = false }   // _hx_start_c stores hxlcl_environ itself
```

Inside `if !crt_handoff {`, wrap the existing stub in an else and add (byte-for-byte the runtime's asm `_start`, `runtime_emit_full.hexa:103-109`):

```hexa
    if init_stub {
        // xor %rbp,%rbp; mov %rsp,%rdi; and $-16,%rsp; call _hx_start_c; hlt (16 B)
        // rdi = RAW entry rsp (sp[0]=argc contract); _hx_start_c never returns.
        text_bytes.push(0x48); text_bytes.push(0x31); text_bytes.push(0xED)
        text_bytes.push(0x48); text_bytes.push(0x89); text_bytes.push(0xE7)
        text_bytes.push(0x48); text_bytes.push(0x83); text_bytes.push(0xE4); text_bytes.push(0xF0)
        text_bytes.push(0xE8); text_bytes.push(0x00); text_bytes.push(0x00)
        text_bytes.push(0x00); text_bytes.push(0x00)
        text_bytes.push(0xF4)
    } else {
        ...existing 23/35-byte stub unchanged...
    }
```

`:1947-1948`:

```hexa
    let stub_call_field = if init_stub { 11 } else if env_cell { 22 } else { 10 }
    let stub_call_next  = if init_stub { 15 } else if env_cell { 26 } else { 14 }
```

## E6 — call-target: `_hx_start_c` offset (def loop `:2004-2013` + patch `:2060`)

Next to `main_off` (`:1955` area): `let mut hxsc_off = -1`. In the `s.section == 1` arm after the `main_off` capture (`:2011-2013`):

```hexa
                if hxsc_off < 0 && name == "_hx_start_c" { hxsc_off = base + s.value }
```

At the call patch `:2060-2062`:

```hexa
    if !crt_handoff {
        let mut _tgt = main_off
        if init_stub {
            if hxsc_off < 0 { eprintln("hexa_ld(elf,ownstart): _hx_start_c defined but no .text offset resolved"); return 3 }
            _tgt = hxsc_off
        }
        let call_rel = _tgt - stub_call_next
        ...unchanged 4-byte little-endian store...
```

Keep the `:2050` `main_off < 0` check as-is (`_hx_start_c` calls `main` extern; it must still exist).

## E7 — def loop: don't misfile section-6 syms (insert before `:2026` `} else if s.section != 0 {`)

```hexa
            } else if s.section == 6 {
                // .init_array-resident sym (STT_SECTION $sec) — registered AFTER
                // the region is materialized below (init_region_off not yet
                // known). Falling into the data arm would register a WRONG
                // blob offset.
            }
```

This arm is **required**: without it, section-6 syms (which Pass B now emits) land in the generic data arm with a bogus `da_base + s.value` offset.

## E8 — region materialization: replace the start==end synthesis (`:2082-2091`)

```hexa
    // ── output .init_array region — contiguous concat of every obj's pooled
    // SHT_INIT_ARRAY bytes, link order (GNU ld parity; priority-sort across objs
    // is a named follow-up rung — see note). Entries are patched to FINAL ctor
    // vaddrs by the kind-1 site_seg==6 resolve arm below. Zero-ctor links: no
    // pad, empty region, start==end at the same offset as today — bit-identical.
    if init_total > 0 { while (len(data_bytes) & 7) != 0 { data_bytes.push(0) } }
    let init_region_off = len(data_bytes)
    let mut _iri = 0
    while _iri < len(objs) {
        let _iro = objs[_iri]
        let mut _irb = 0
        while _irb < len(_iro.init_array) { data_bytes.push(_iro.init_array[_irb] & 0xff); _irb = _irb + 1 }
        _iri = _iri + 1
    }
    def_names.push("__init_array_start")
    def_seg.push(1)
    def_off.push(init_region_off)
    def_bind.push(ELF_STB_GLOBAL)
    def_obj.push(-1)
    def_names.push("__init_array_end")
    def_seg.push(1)
    def_off.push(len(data_bytes))            // init_region_off + init_total
    def_bind.push(ELF_STB_GLOBAL)
    def_obj.push(-1)
    // deferred section-6 sym registration (E7) — absolute blob offsets now known
    if init_total > 0 {
        let mut _isi = 0
        while _isi < len(objs) {
            let _iso = objs[_isi]
            let mut _iss = 0
            while _iss < len(_iso.symbols) {
                let _isy = _iso.symbols[_iss]
                if _isy.section == 6 {
                    let mut _isn = ""
                    let mut _isk = 0
                    while true {
                        let _isb = _iso.strtab[_isy.name_offset + _isk] & 0xff
                        if _isb == 0 { break }
                        _isn = _isn + from_char_code(_isb)
                        _isk = _isk + 1
                    }
                    def_names.push(_isn)
                    def_seg.push(1)
                    def_off.push(init_region_off + obj_init_base[_isi] + _isy.value)
                    def_bind.push(_isy.bind)
                    def_obj.push(_isi)
                }
                _iss = _iss + 1
            }
            _isi = _isi + 1
        }
    }
```

Placement is load-bearing: this sits **before** the errno cell / COPY cells / GOT / dyn structures, all of which key off `len(data_bytes)` at their own build time, so they shift automatically; and **before** the `ldx` index build (`:2225`), so all new defs get indexed. The boundary syms stay `def_seg=1` → the existing GOT-fill resolves the runtime's REX_GOTPCRELX (kind 42) refs to them with **zero** resolver changes. Because the region rides the RW data blob, `has_data` (`:2495`) flips true whenever ctors exist — the 2seg/dyn serializer is always the one used, never the text-only one.

## E9 — resolve pass: patch entries in place (`:2825-2826` and `:2864-2865`)

Both site-selection heads become (identical edit twice — GOTPCREL-hoist branch and main branch):

```hexa
                    if r.site_seg == 3 || r.site_seg == 4 || r.site_seg == 6 {
                        let blob_off = if r.site_seg == 4 { obj_data_base[ro] + r.offset }
                                       else if r.site_seg == 6 { init_region_off + obj_init_base[ro] + r.offset }
                                       else { obj_rodata_base[ro] + r.offset }
```

No new reloc-kind code: each `.init_array` entry is `R_X86_64_64` (kind 1) against the ctor (or its `.text` STT_SECTION + addend), and the existing kind-1 data-site arm (`:2867-2876`) writes the absolute 8-byte `S+A` — which **is** the final vaddr (ET_EXEC, fixed `0x400000`, `l_addr=0`), so entries are fully link-time resolved. No `R_X86_64_RELATIVE` needed on either path. An entry targeting an UND symbol can't slip through silently: kind 1 is deliberately outside the dyn census, so it hits the H1 hard-error.

## E10 — dyn path: DT tags (insert at `:2711`, immediately before the `DT_NULL` at `:2712`)

```hexa
        if init_total > 0 {
            _ew_u64(data_bytes, 25); _ew_u64(data_bytes, data_vaddr_base + init_region_off)  // DT_INIT_ARRAY
            _ew_u64(data_bytes, 27); _ew_u64(data_bytes, init_total)                          // DT_INIT_ARRAYSZ
        }
```

`dyn_sz = len(data_bytes) - dyn_off` (`:2713`) and PT_DYNAMIC pick up the two extra entries automatically.

---

## Mechanism per path — exactly one runner each

| path | who runs ctors | why no double-run |
|---|---|---|
| static (`n_dyn==0`) | E5 stub → `_hx_start_c` → inlined `_hx_run_init_array` walks `[__init_array_start, __init_array_end)` (now real bounds) | no PT_DYNAMIC exists → no loader mechanism at all |
| dyn (`crt_handoff`) | glibc: entry = crt1 `_start` → `__libc_start_main` consumes the exe's `DT_INIT_ARRAY/SZ` (crt1.o ≥2.34 passes init=NULL; the handoff already hard-requires ≥2.34 crt1 — an older one would UND `__libc_csu_init`, unexported by libc.so.6) | the own stub is suppressed (`crt_handoff` → no stub), so `_hx_start_c` is dead code; the boundary-sym walk never executes |

## byteeq safety — honest breakdown

- **Zero-`SHT_INIT_ARRAY` input** (all no-runtime links: own-emit unit tests, `self/test/ownlink_determinism`): `init_total==0` → no 8-pad (guarded), empty region, boundary defs at the **same** blob offset as today, `init_stub=false` → stub bytes identical, no `site_seg==6` relocs, no DT tags, E7/E8 loops no-op. Output **bit-identical**.
- **runtime.a links**: NOT byte-neutral, by construction — `hxlcl_capture_environ` (constructor(101)) is in `runtime_core`'s emitted TU unconditionally, so every runtime own-link gains an 8-byte region + the 16-byte init stub, and its behavior changes (ctor runs; env store moves from the 35-byte env_cell stub into `_hx_start_c`, which stores `hxlcl_environ = envp` before the walk — the ctor re-store is idempotent; exit now drains the atexit LIFO via `hxlcl_exit` instead of the stub's raw `exit(60)` — this is exactly the system-ld own-start semantics, i.e. a parity **gain**). The own-link **determinism** gate stays green (output is a deterministic function of input; re-run the two-build cmp). If PR-1 compares own-link output against a pre-fix golden, that golden needs re-baselining — flag it in the PR.
- The shipping path (system ld) never enters this file → shipping byteeq 3-target untouched.

## Verify recipe (aiden, linux x86_64)

1. `ctor.c`: `#include <unistd.h>` + `__attribute__((constructor)) static void c(void){ write(1,"CTOR\n",5); }` → `clang -c -O2`. `main.hexa`: `fn main(){ println("MAIN") }` → own-emit obj (`HEXA_BACKEND=native`, `--emit=obj`).
2. **Static leg**: link `[main.o, ctor.o]` + runtime.a through `link_elf_x86_64_ownstart_ar` (harness mirroring `self/test/ownlink_determinism/rt_pull.hexa`). Run: stdout must be `CTOR\nMAIN\n` (ctor first), exit 0. `readelf -lh`: ET_EXEC, no PT_INTERP.
3. **Dyn leg**: add a genuine-resid TU (e.g. a bare `printf` call) so `crt_handoff` fires. Run: `CTOR` before `MAIN`; `readelf -d` shows `INIT_ARRAY` = region vaddr, `INIT_ARRAYSZ` ≥ 8 (region also holds the runtime's capture-ctor entry).
4. **Byte-neutral leg**: rebuild the no-runtime ownlink-determinism binaries pre/post-fix → `cmp` identical. runtime.a link pre/post → expected DIFF (document); post-fix build twice → `cmp` identical (determinism green).
5. **Entry sanity**: `objdump -s` at `__init_array_start`'s vaddr → first 8 bytes == `hxlcl_capture_environ`'s vaddr; env observable: `env()`-reading program still returns correct values on both legs.

## Scoped out (named, per parity request)

- **Priority sort**: GNU ld runs `SORT_BY_INIT_PRIORITY(.init_array.*)` before plain `.init_array` **across** objs; this fix concatenates in (obj, section-header) order. Divergence only when ≥2 distinct priorities span objs — today only 101 exists. Follow-up rung: sort per-obj pools by a parsed `NNNNN` key at E8.
- **`SHT_PREINIT_ARRAY` (16)**: still dropped (sanitizers only). Optional loud tripwire in Pass A; `DT_PREINIT_ARRAY`=32 if ever needed.
- **`.fini_array` (15) / `DT_FINI_ARRAY`=26**: still dropped — `__attribute__((destructor))` won't run on the static path (atexit/`__cxa_atexit`-registered dtors DO run via `hxlcl_exit`'s drain). Symmetric fix later: pool slot 7 + a fini walk in `hxlcl_exit` + `DT_FINI_ARRAY` on dyn.
