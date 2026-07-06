All questions answered — I've read the backend, the seed, the regen script, and the register allocator. Here's the full design.

## 1. Exact emit site + current lowering

**`compiler/codegen/x86_64_linux.hexa:4036`** — the raw setcc compare path inside the `_STMT_BINOP` handler:

```hexa
let suf = _x86_setcc_suffix(s.op)
if suf.len > 0 {
    let mut a_real = a
    if s.args[0].kind == "const_int" {           // LHS-imm guard exists (fb09d4bf mirror)
        ... mov a_scratch, a ...
    }
    _x86_buf.push(_x86_instr2("cmp", a_real, b, "binop " + s.op))   // ← line 4036, THE BUG
    _x86_buf.push(_x86_instr1("set" + suf, ...))
```

Routing context: operands resolve at lines 3835–3836 via `_x86_op_resolve`, where `const_int` returns a raw `_x86_op_imm(o.int_val)` with **no magnitude check** (line 3040). This raw path fires because `_unbox = _x86_binop_unbox_ok(s, rm)` is true — `HEXA_UNBOX_NATIVE` is **default-ON** (line 1590, `env(...) != "0"`), and the mantissa/exponent compares in `float_parse_hexinfnan.hexa` are provably-int, so they skip the boxed `hexa_cmp_*` tag-dispatch block (line 3978) and reach the native `cmp reg, imm` with 2⁵²/2⁵³/2⁵⁹ immediates. The LHS-const guard at 4031 exists; the RHS has no guard.

## 2. The minimal fix (exact edit)

Mirror the wide-imm guard that **already exists** in the same function's generic-ALU tail (lines 4102–4110, added for the `0xFC000000` bitmask case) — same predicate, same scratch, same `mov`-materialization idiom:

```hexa
                // x86-64 `cmp r/m64, imm` takes a SIGN-EXTENDED imm32 ONLY — a
                // 64-bit immediate is not encodable (GNU as/clang: "invalid
                // operand"). Materialize a wide RHS const into b_scratch first
                // (`mov r64, imm64` encodes as movabs — the codebase wide-imm
                // idiom, e.g. the magicdiv M load). Mirrors the ALU imm32
                // guard below; small imms keep the direct `cmp reg, imm` →
                // byte-identical emit for every existing program.
                let mut b_real = b
                if s.args[1].kind == "const_int" {
                    let bv = s.args[1].int_val
                    if bv > 2147483647 || bv < -2147483648 {
                        _x86_buf.push(_x86_instr2("mov", _x86_op_reg(b_scratch), b,
                                         "materialize wide cmp imm to reg (cmp imm is imm32)"))
                        b_real = _x86_op_reg(b_scratch)
                    }
                }
                _x86_buf.push(_x86_instr2("cmp", a_real, b_real, "binop " + s.op))
```

i.e. insert the `b_real` block between line 4035 and 4036, and change line 4036's `b` → `b_real`. Emit `mov`, not a literal `movabs` mnemonic — GNU as (Intel syntax) auto-encodes `mov r64, imm64` as movabs, and that's the established idiom in this file (magicdiv comment at ~3890: *"64-bit immediate `mov reg, <imm>` — GNU `as` encodes movabs"*).

**Scratch-register safety (`b_scratch` = r11):** the allocation pool is **rbx/r12–r15 only** (`_x86_pool_init`, lines 320–337 — callee-saved regs); r10/r11 are statement-local scratch, never home a live value. Within this emit:
- r11 carries content only when `args[1]` is a spilled local or a global — but then `_x86_op_resolve` already returned `r11` **as** `b` (kind ≠ `const_int`), so the guard doesn't fire. Whenever the guard fires, r11 is provably dead.
- The LHS can only be a pool reg or r10 (spilled/materialized into `a_scratch`) — never r11. `dst` is a pool reg or r10 (`_x86_dst_reg`, line 3125). The subsequent `set`/`movzx` use al/dst. The writeback spill uses r10. Zero collision. No spill needed.

**Byte-neutrality:** the small-imm branch emits character-identical instructions, and any program that hits the wide branch today produces asm that **fails to assemble** — so no currently-green artifact can contain it. The x86_64 selfhost/byteeq builds are green on main, which is itself proof the corpus has zero raw-path wide-imm compares; gen3≡gen4 stays byte-identical.

## 3. Scope — is cmp the only unguarded site?

Yes. I audited every immediate-consuming emit in the backend:

| Site | Status |
|---|---|
| `cmp` raw setcc path (4036) | **THE BUG** — unguarded RHS |
| Generic ALU `add/sub/imul/and/or/xor` (4111) | already guarded (4102–4110, identical predicate) |
| `idiv` (4046) | always materializes divisor into r11 (4059) |
| Shifts (4079) | count via `mov rcx, b` — `mov r64, imm64` is encodable, safe |
| magicdiv `imul rax, rdx, d` (3915) | gated to d ∈ [2, 2³¹−1] by `_x86_binop_div_const_ok` — imm32 guaranteed; the wide magic constant M already goes through `mov r11, imm64` |
| `!=` (3999) | always routed through boxed `hexa_eq` (no `_unbox` bypass; `_x86_hv_cmp_sym("!=") == ""` keeps it out of `unbox_ok`) — unaffected |
| Other `cmp`/`test` sites (1915–2029, 4166–4213, 4396, 4789, 4845, 5390) | reg/reg or hardcoded small imms (0, 1, 47, 175); `br_cond` materializes non-reg conds |
| `const_float` payload imm64 | only reachable via `mov` paths (boxing / leaf intrinsics) — encodable; can't reach the raw cmp because `_x86_operand_provably_int` rejects it |

So the one-block fix closes the whole class.

## 4. Re-bake + re-gate + PR plan

**PR-1 — the codegen fix alone** (this file, ~12 lines). Yes, it should be its own PR: it's a codegen change, so it takes the mandatory byteeq 3-target gate, and that gate GREEN **is** the machine-checked proof of the byte-neutrality argument above (no need to hand-audit the corpus — a wide-imm compare in the corpus would have made today's x86_64 build RED already). Ships with regular CI: byteeq 3-target + shipping smoke.

**PR-2 — seed re-bake** (after PR-1 merges), on **aiden** (mini = git/gh only):
1. Build a clean `build/aprime_cc` from the merged main.
2. `bash tool/regen_float_parse_hexinfnan_native_s.sh all` — the script itself cross-assembles each seed and asserts `rt_str_parse_float_hexinfnan` is a defined `T` global (lines 71–83); on aiden the x86_64 check runs with the native toolchain, no `-target` shim needed.
3. **Assert `git diff` shows only `self/native/float_parse_hexinfnan_x86_64.s` changed.** The darwin + arm64-linux seeds must come back byte-identical to the shipped #4637 versions (arm64 immediate handling is unaffected) — any drift there means something else moved in aprime_cc; stop and diagnose before proceeding.
4. Sanity on the new x86_64 seed: `grep -E 'cmp .*[0-9]{10,}'` returns nothing; the 2⁵³/2⁵²/2⁵⁹ compares now appear as `mov r11, <imm> / cmp r10, r11`.
5. Re-run the strtod tail-gate on aiden (`HEXA_RT_STRTOD_TAIL_NATIVE` opt-in path through `stage_resolve_runtime_a`, per the flip-gate oracle harness) with captured output.

Do **not** accept a "byteeq reconverge" framing — none is needed. If step 3 holds, PR-2 is a frozen-seed-only change and PR-1 is provably byte-neutral; if step 3 fails, that's a real regression signal, not a reconverge candidate.