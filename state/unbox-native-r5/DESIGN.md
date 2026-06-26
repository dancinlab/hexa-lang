<!-- quickref: SSOT = ../../ARCHITECTURE.json (design) + ../../CHANGELOG.md (history).
     baseline = ../codegen-quality-probe-verdict.md; campaign = ../codegen-unboxing-campaign.md (slice r5). -->

# r5 — native-backend BinOp unboxing (HEXA_UNBOX_NATIVE) — design + prototype

Status: PROTOTYPE on branch `perf/codegen-unbox-native-r5` (default-OFF). NOT merged.
Target backend: `compiler/codegen/x86_64_linux.hexa` (the aprime `--emit=obj` native path
the probe measured — NOT `self/codegen.hexa`, the gen2 C-transpile path R1 wrongly patched;
memory `project_hexa_codegen_two_backend_path_mismatch`).

## Phase 1 — native backend map (file:line, on origin/main cc02355)

### ⓐ STMT_BINOP lowering — `_emit_x86_64_stmt` (`compiler/codegen/x86_64_linux.hexa`)
- `_STMT_BINOP` constant `:99`; dispatch case opens `:1805` (`if s.kind == _STMT_BINOP`).
- Operands resolved to raw-payload LOperands `:1809-1812` (`_x86_op_rm` + `_x86_op_resolve`,
  `a`/`b` are register/imm payloads).
- **Boxed arith dispatch `:1848-1861`** — `_ar_sym = _x86_hv_arith_sym(s.op)` (`:854`/`:893`,
  `+→hexa_add_slow  -→hexa_sub  *→hexa_mul  /→hexa_div  %→hexa_mod`). UNCONDITIONALLY boxes both
  args (`_x86_hv_box_arg` → rdi:rsi / rdx:rcx) and emits `call hexa_*`, then `return`. **This is
  the boxing the probe disassembled.**
- **Boxed cmp dispatch `:1881-1894`** — `_cmp_sym = _x86_hv_cmp_sym(s.op)` (`:973`,
  `< <= > >= ==`). Same box-both-args + `call hexa_cmp_*` + `return`.
- `!=` `:1896+` (hexa_eq→hexa_truthy→xor 1) — distinct, stays boxed.
- **Native (unboxed) ALU paths that already exist but are shadowed:**
  - cmp setcc `:1937-1958` — `cmp a,b; set<cc> al; movzx dst,al; tag=TAG_BOOL`. Reachable for
    `< <= > >= ==` ONLY if the boxed `_cmp_sym` block above is skipped.
  - `idiv` `:1960+` (we keep `/`,`%` boxed — div-zero throw).
  - shift `<<`/`>>` native.
  - **arith tail `mov dst,a; <add|sub|imul|and|or|xor> dst,b; tag=TAG_INT`** — the
    register-resident raw-i64 path. Reachable for `+ - *` ONLY if the boxed `_ar_sym` block is
    skipped. Wide-imm (>imm32) materialized to reg `:2010+`.

### ⓑ {tag,payload} value model — `:208-242`
- `X86RegMap` `:219` carries `ids/regs/slots/tag_base/id2idx`. PAIR-MODEL: payload in a
  callee-saved reg or payload-spill slot; the HexaVal TAG lives in a PARALLEL per-value 8-byte
  frame tag-slot at `[rbp, _x86_frame_off(tag_base + idx*8)]` (`:631-636` `_x86_tag_off`).
- `_x86_frame_off` `:257`; callee-save block 48B `:252`.
- Every binop result writes its tag via `_x86_store_tag_imm/reg` then `_x86_emit_dst_writeback`.
  The native arith path stores `TAG_INT=0`; the boxed path stores the helper's returned tag (rax).

### ⓒ where scalar op → runtime call
- The unconditional `return` in the `_ar_sym`/`_cmp_sym` blocks (`:1860`/`:1893`) IS the dispatch
  point. There is no register-allocation across ops and no strength-reduction (matches probe).

### ⓓ provably-int type info at this backend
- `mir.hexa` `Local.type_id` (`:31`) — `_type_id_of` (`hir_to_mir.hexa:181`): **1=i64** 3=f64
  5=bool 6=string; arrays 101-104. Set on EVERY fresh local incl. binop dst from `e.typ`
  (`hir_to_mir.hexa:1207-1214`, `_fresh_local:337-356`). This is the static int signal.
- BUT `_emit_x86_64_stmt` does NOT receive `mf`, so operand-source locals' `type_id` is not
  directly reachable. `s.dst` (a full `Local`) carries `s.dst.type_id` in-hand; operand
  `s.args[i]` (an `Operand`) only has `local_id`. → need a id→type_id side table in the RegMap.

reference-match: gcc -O2 lowers `k1_sum` `s=(s+i*1009)%M` to native `imul`+`add`+magic-reciprocal
`idiv`, 0 calls/iter (probe disasm). We close the `imul`+`add` to native; `%` stays a call (r4).

## Phase 2 — prototype (5 patches, all behind `HEXA_UNBOX_NATIVE=1`, default-OFF)

1. `X86RegMap.local_type: [i64]` — new field (single struct, single construction site `:601`).
2. Builder in `_x86_64_assign_regs` — id→type_id array sized `_x86_max_local_id(mf)+1`, filled
   from `mf.locals` + `mf.params`. Runs unconditionally (cheap), READ only behind the gate.
3. `_x86_local_type(rm,id)` — O(1) probe (0 = unclassified bottom).
4. Predicates: `_unbox_native_enabled()` (env gate) · `_x86_operand_provably_int(o,rm)` (const_int/
   const_bool literal, or local with type_id==1; **globals conservatively excluded** — different
   id space, indexing local_type[global_id] would alias) · `_x86_binop_unbox_ok(s,rm)` (gate ON +
   op ∈ {+,-,*,<,<=,>,>=,==} + dst i64 for arith + BOTH operands provably-int).
5. Hook: compute `let _unbox = _x86_binop_unbox_ok(s,rm)` once at binop entry; guard the two boxed
   blocks `if len(_ar_sym)>0 && !_unbox` / `if len(_cmp_sym)>0 && !_unbox`. When `_unbox`, control
   falls through to the EXISTING native ALU/setcc path. `/` `%` never qualify (stay boxed).

### OFF-path byte-identity (by construction)
With `HEXA_UNBOX_NATIVE` unset, `_unbox` is always false → both boxed `if` conditions are
unchanged → identical emit. The new `local_type` field is populated but never read. So OFF .o is
byte-for-byte the baseline. (Gate-1 verifies empirically: patched-OFF .o `cmp` baseline .o.)

### Soundness firewall (the silent-miscompile hazard, flatten_globals class)
- Conservative bottom: type_id 0 (unclassified) / f64 / str / fn-return / map-struct field / global
  → NOT proven → stays boxed. Over-eager = miscompile; conservative = at-worst-no-speedup.
- dst i64 anchor: HIR typed the result i64 ⇒ the runtime helper would have taken its int path ⇒
  the native ALU result is numerically identical (proven by Gate-4 output-parity).
- `/` `%` excluded (runtime div-by-zero throw). `!=` excluded. concat/mixed-bitwise excluded.

### Known limitation (honest)
- The native cmp path does not materialize a wide-imm (>imm32) RHS; an int compare against a huge
  literal would be `as`-rejected (a LOUD build error, not a silent miscompile). k1_sum's bound
  `i < 200000000` fits imm32. Wide-imm cmp materialization = trivial follow-on if measured needed.
- Whether `k1_sum`'s `let mut s` / loop `i` actually carry type_id==1 at MIR depends on S3
  inference; if untyped, k1_sum stays boxed and Gate-2 reports "flag had no effect" — an honest
  negative that points at widening the lattice (r2), not a bug.

## Phase 3 — gates (run on aiden/summer via `state/unbox-native-r5/measure.sh`)
1. OFF byteeq (BLOCKING): patched flag-OFF native .o == origin/main baseline .o (sha). Full
   3-target gen3≡gen4 = PR CI.
2. lever: native asm `call hexa_add_slow`/`hexa_mul` count OFF vs ON (WIN = ON<OFF).
3. ratio: taskset median CPU ON/OFF vs the 2.86× gcc-O2 baseline of record.
4. parity: program output OFF==ON (bit-identical).
5. smoke: `hexa --version` + hello + exit42 under the flag.

Merge gate = 1+4+5 (byteeq+parity+smoke) for default-OFF landing; default-flip needs 2+3 measured
AND 3-target byteeq re-confirmed (separate later decision). Release-integrity is the TOP guardrail.

## MEASURED VERDICT (summer, 2026-06-26 · commits 368992fa→dee8a726)

- **G1 OFF-byteeq = PASS** — patched-OFF k1_sum .o == origin/main baseline .o, **sha 7d9066ea**
  (same-cwd emit). The first run reported FAIL on 18 bytes; root-caused to the embedded DWARF
  `DW_AT_comp_dir` source path (`.../src` vs `.../base`) in `.debug_str` — a HARNESS artifact, the
  `.text` was byte-identical (objcopy --only-section=.text + all section sizes equal). So the
  "struct-shape change shifts .o" hypothesis was FALSIFIED: the `local_type:[i64]` field does NOT
  perturb emit. The codegen patch is byte-neutral on OFF exactly as designed. Harness fixed (r1c)
  to emit both OFF builds from one cwd; codegen unchanged.
- **G2 lever = PROVEN** — ON emits `imul r10,1009` / `add r10,r11` / `cmp r14,r13; setl` where OFF
  emits `call hexa_mul` / `call hexa_add_slow` / `call hexa_cmp_lt`. hexa_add 2→0, mul 1→0, cmp
  1→0; hexa_mod stays 1 (% kept boxed — correct, %-bound).
- **G4 parity = OK** — OFF==ON output 840001701 (unbox preserves the result).
- **G3 ratio = 1.000** — k1_sum is **%-bound** (the still-boxed `% M` dominates), so removing the
  +/*/< calls yields no wall-clock change. Honest negative; real wins are r2 (arrays, 23×, not
  %-bound) and r4 (% magic-reciprocal). See `state/runtime-gap-all-closure-roadmap.md`.
- **G5 smoke = GREEN** (hexa v0.333.0 · hello · exit42).
- **r1b refinement (kept):** the `local_type` builder is gated behind `_unbox_native_enabled()` so
  it does not even run when OFF (cheaper; also byte-neutral). Harmless, retained.

**Conclusion:** mechanism is correct + release-safe (OFF inert + ON parity). Merge-gate (G1+G4+G5)
GREEN for the default-OFF landing. Open PR after 3-target gen3≡gen4 byteeq CI confirms.
