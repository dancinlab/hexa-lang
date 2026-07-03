<!-- quickref: SSOT = ../../ARCHITECTURE.json (design) + ../../CHANGELOG.md (history).
     plan = ../codegen-unboxing-campaign.md · baseline = ../codegen-quality-probe-verdict.md. -->

# HEXA_UNBOX_INFER R1 — prototype implementation verdict

Status: **IMPLEMENTED (default-OFF) · measurement PENDING-POOL.** Branch
`perf/codegen-unbox-infer-r1` off `origin/main`. Codegen is the highest-risk
substrate — this lands gated, OFF-path byte-identical by construction; default-FLIP
is NOT in scope (requires the full gate set captured on the pool).

## What the plan said vs what R1 actually needs (root-cause refinement)

The plan (`state/codegen-unboxing-campaign.md`) frames Patch B as a single Ident
one-liner: `_is_known_int` blesses the inferred accumulator name. Tracing k1_sum
(`s = (s + i*1009) % M`) against the real codegen showed that is **necessary but
not sufficient**:

- The for-loop counter `i` is ALREADY registered known-int (ungated, `codegen.hexa:3660`),
  and the immutable `let M` registers at emit (`:3101`). So by default `i*1009`
  already emits an inline compound literal.
- BUT `_is_known_int` only certifies LEAF nodes (IntLit · Ident · proven Index) —
  it does **not** recurse into BinOps. So `s + i*1009` has left `s` and right
  `i*1009` (a `*` BinOp): even after marking `s`, the right operand is uncertified,
  so the `+` fast-path (`:5529`) does not fire and `hexa_add` stays.
- AND the existing mut-accumulator proof `_is_accum_int_safe` (`:11049`) rejects
  `%`/`/` outright, so `s` is not admitted even under `HEXA_NATIVE_ARR` — the
  write `(…) % M` voids it. The rejection is for the div-zero THROW, **not** the
  type: hexa `int%int`→int and `int/int`→`hexa_int(…)` (truncating int) per
  `runtime_core_emit.hexa` (`hexa_div`/`__raw_imod`), so the result IS provably int.

So the genuine R1 lever is two gated extensions, both in `self/codegen.hexa`:

1. **Recursive int-closed BinOp certification** in `_is_known_int` (gated): a
   BinOp over `+ - * & | ^ << >>` whose both operands are provably int is itself
   known-int (pure predicate, no emission → no double-eval). This is the
   "widen the set of SUBEXPRESSIONS" the plan's §1 actually intends.
2. **Type-permissive accumulator admission** (`_infer_accum_int_safe` /
   `_infer_accum_writes_all_int`) that admits `%`/`/` for the TYPE proof while
   emit still routes them through boxed `hexa_mod`/`hexa_div` (throw preserved).

With both, k1_sum's `s + i*1009` lowers to one nested inline compound literal
(no `hexa_add`); only `% M` remains a boxed `hexa_mod` — the honest %-bound
residual the plan predicted.

## Implementation (all in `self/codegen.hexa`, gated `HEXA_UNBOX_INFER=1`)

- **Patch A — fn-local inference lattice** (`_build_unbox_facts`, called at
  `gen2_fn_decl` entry `:1983`, reset at fn exit `:2333` + codegen reset `:13864`):
  - memoized env gate `_unbox_infer_enabled()` (mirrors `_native_arr_enabled`).
  - emit-consulted sets `_infer_int_set`/`_infer_float_set` (fn-local → no global
    pollution → may be trusted ahead of the `_is_known_int_name` collision guards).
  - scan-only fact sets (`_infer_scan_int/float`) seeded with range-loop counters
    + immutable typed/literal lets to a bounded fixpoint — used ONLY by the
    accumulator type proof, NEVER consulted at emit (the soundness firewall that
    keeps loop counters from leaking past their lexical scope into the predicate).
  - admits top-level `let mut acc` whose every write provably stays int (init
    int-safe · not a closure boxed-cell · not a fn param).
- **Patch B — predicate hooks** (gated, one branch each):
  - `_is_known_int` Ident: `if _infer_int_member(name) return true` (`:12905`).
  - `_is_known_int` recursive int-closed BinOp branch (`:~12930`).
  - `_is_known_float` Ident: gated forward-wire `_infer_float_member` (`:13151`) —
    R1 leaves `_infer_float_set` empty (float-accum admission = r2), so it is a
    no-op no-risk hook.
- **Patch C — call sites: none.** Consumers at `:5527`/`:8633` already branch on
  `_is_known_int`/`_is_known_float`; they light up for free.

`%`/`/` stay BOXED at emit (fast-path `:5533` excludes them) — div-zero throw kept.

## OFF-path byte-identity argument (gate 1 — must be verified empirically)

Every new path is behind `_unbox_infer_enabled()` (the memoized env gate) which
returns false when `HEXA_UNBOX_INFER` is unset. `_infer_int_member` /
`_infer_float_member` self-gate; `_build_unbox_facts` early-returns (sets stay []);
the recursive BinOp branch is wrapped in `if _unbox_infer_enabled()`. Therefore
with the flag unset `_is_known_int` returns today's exact answer → emitted `.c`/`.o`
byte-for-byte the current build, and the gen3≡gen4 self-host fixpoint is preserved.
**This must be confirmed by capture on the pool, not by argument** (gate 1).

## Soundness firewall (codegen = silent-wrong-answer risk)

- Inference is monotone + conservative: only IntLit, proven-int Ident
  (known-int-set / for-counter / admitted accumulator), proven Index reads, and
  int-closed BinOps over those are certified. No fn return values, map/struct
  fields, conditional merges, or mut rebinds carrying non-int.
- `int/int`→int and `int%int`→int are confirmed in `runtime_core_emit.hexa`, so
  admitting them in the TYPE proof is sound (and emit keeps the throw).
- Sets are FN-LOCAL (reset every fn) → no cross-fn pollution; admission excludes
  fn-param shadows and closure boxed cells.
- Defense of last resort is **gate 4 output-parity** on every kernel, not LLM
  self-judgement.

## Gates (run `state/unbox-infer-r1/measure.sh` on aiden/summer)

| gate | what | status |
|------|------|--------|
| 1 | OFF unset → gen3≡gen4 byteeq + corpus `.o` sha == origin/main | PENDING-POOL (BLOCKING) |
| 2 | k1_sum emitted-C `hexa_add` count OFF→ON drops, `hexa_mod` remains | PENDING-POOL |
| 3 | k1_sum gcc -O2 runtime ratio (taskset median) vs 2.86x baseline | PENDING-POOL |
| 4 | k1_sum output OFF == ON (bit-identical) | PENDING-POOL |
| 5 | `hexa --version` + hello/exit42 under the flag GREEN (3 targets) | PENDING-POOL |

Merge gate = 1+4+5 GREEN for the default-OFF landing. Default-FLIP = separate later
decision needing 2+3 measured AND 3-target byteeq re-confirmed.

## Follow-ons (after R1 lands + measured)

- r2: float-accumulator admission (populate `_infer_float_set`; the predicate hook
  is already wired) + array-element unbox (`k3_arrmap`, 23x).
- r3: compound-assign accumulator unbox under the flag (`:3364` currently gates on
  `_is_known_int_accum_name`; add `_infer_int_member` — one line, was kept out of
  R1 to honor "Patch C = none").
- r4: int `%`/`/` with proven-nonzero divisor (drop the throw, unbox the last
  k1_sum call — M=1000000007 is a nonzero literal).
- r5: native-backend STMT_BINOP (the path the probe actually measured via
  `aprime_cc --emit=obj`) — separate larger campaign in `compiler/codegen/*`.
