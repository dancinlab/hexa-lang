# RFC — runtime hexa-native rewrite (north-star ② next phase)

Status: DRAFT 2026-05-20 · scope multi-week · cycle 42 entry

## Why now

Campaign s7-p0-cycle1 cycle 22-41 closed S3 fixpoint full closure
(gen1.s ≡ gen2.s, 10.6 MB · md5 `4197fd52560f3acca059a197b000c83c`).

That proves the **compiler** is self-host-fixpoint stable. The
remaining C dependency is the **runtime** that the compiler links
against:

```
self/runtime.c       9,574 LoC
self/runtime_core.c  6,066 LoC
self/runtime.h       1,169 LoC
── total            ~16,809 LoC of C
plus self/native/*.c  45 files (OS shims, GPU, crypto)
```

north-star ②'s closure: "모든 `.hexa` 가 인터프리터 없이 네이티브
컴파일·실행" — currently true ONLY if runtime C counts as
infrastructure. The strict reading wants the runtime ALSO in hexa.

## Scope decomposition (3 tiers)

### Tier-A — Compiler-essential primitives (~30 functions, ~3K LoC)

Functions the compiler / aprime_cc itself calls:

- HexaVal core: `hexa_int`, `hexa_str`, `hexa_bool`, `hexa_array_*`,
  `hexa_map_*`
- String: `hexa_str_substring`, `hexa_str_concat`, `hexa_str_chars`,
  `hexa_str_bytes`, `hexa_char_code`, `hexa_str_eq`
- Arena: `hexa_arena_alloc`, `hexa_val_arena_scope_push/pop`,
  `__hexa_fn_arena_return`
- I/O: `hexa_read_file`, `hexa_write_file`, `hexa_println`,
  `hexa_eprintln`
- Process: `hexa_exec`, `hexa_exec_with_status`, `hexa_exit`
- Hash: `hexa_sha256`, `hexa_sha256_hex`

This is the MINIMAL closure that builds aprime_cc + hexac.

### Tier-B — Stdlib primitives (~50 functions, ~5K LoC)

Math (`sin`, `cos`, `exp`, `log`), regex (`hexa_regex_*`),
JSON (`hexa_json_*`), bytes (`hexa_bytes_*`).

Used by stdlib code (`stdlib/*`) but not by compiler's own source.

### Tier-C — Application primitives (~100+ functions, ~8K LoC)

Crypto (`hexa_chacha20*`, `hexa_x25519*`), networking (`hexa_net_*`),
GPU kernels (`hxblas_*`, `hxcuda_*.cu`), Linux/macOS shims (`mount`,
`pty`, `namespace`).

Used by anima / wilson / qrng / sim_universe consumers, not by
hexa-lang compiler.

## Strategy — three phases

### Phase 1 — Tier-A in hexa with controlled libc escape hatches

- Replace each Tier-A C function with a `pub fn` in `stdlib/runtime/`
- hexa fns use direct syscall via `@asm` blocks for OS interface
  (write, read, mmap, brk, exit syscalls)
- malloc/free replaced with hexa-native bump allocator backed by
  mmap syscall
- libm functions (sin/cos/log) — keep as C externs (libm escape hatch)
  OR adopt a small hexa-native implementation (Taylor / CORDIC)
- Test: aprime_cc rebuilds with Tier-A-replaced runtime → same S3
  fixpoint md5 `4197fd52560f3acca059a197b000c83c`

Estimated 8-12 cycle equivalent work.

### Phase 2 — Tier-B migration

After Phase 1 stable, port stdlib primitives. These are higher-level
algorithms (regex DFA, JSON parser) that translate cleanly to hexa
without inline asm.

Estimated 4-8 cycle equivalent.

### Phase 3 — Tier-C migration (or deferral)

Crypto + network + GPU kernels. Some legitimately want C/CUDA paths
(performance / hardware ABI). Tier-C can stay C **by policy** if the
spec defines "hexa-native" as "compiler + runtime hexa-native; FFI
to vendored C for hardware-bound paths is allowed."

LATTICE_POLICY review needed: is "fork shell to nvcc" OK if the hexa
language itself doesn't need that path for self-host?

Estimated: deferred indefinitely OR 16+ cycle equivalent.

## Cycle 42 immediate scope

This RFC draft is cycle 42 entry. Next actions:

1. Catalog Tier-A symbols via `nm aprime_c41 | grep '^.* T _hexa'`
2. Pick smallest one (e.g. `hexa_int` or `hexa_bool` — simple
   tag-construction) as Phase 1 proof-of-concept
3. Implement in `stdlib/runtime/hexa_int.hexa` with `@asm` if needed
4. Show aprime_cc still builds + S3 fixpoint preserved
5. If green, expand to other Tier-A symbols in subsequent cycles

## Risks

- @asm block support in aprime_cc may be incomplete (cycle 42+ subwork)
- libm replacement (sin/cos) for fixpoint stability: any FP-differ
  breaks S3
- Hexa runtime's malloc must match C malloc's alignment + free semantics
- Arena rewind interaction with hexa-allocated state needs proof

## Acceptance — S4 (post-S3) gate

After Phase 1: `nm aprime_c_phase1 | grep '^.* U _' | wc -l ≤ 5`
(only libm + syscall externs remain).

After Phase 2: `nm aprime_c_phase2 | grep '^.* U _'` lists ONLY
syscalls + libm float ops.

After Phase 3 (if pursued): "zero-C-dep" gate — pure assembly + hexa.

## Cross-refs

- `[[s3-fixpoint-full-closure-2026-05-20]]` (preceding closure)
- `LATTICE_POLICY.md` (north-star ②)
- `HEXA-NATIVE-ONLY.md` (policy spec)
- `compiler/PLAN.md` cycle 22-41 entries (campaign history)
