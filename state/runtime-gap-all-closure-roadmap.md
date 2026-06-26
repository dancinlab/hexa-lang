<!-- quickref: SSOT = ../ARCHITECTURE.json (design) + ../CHANGELOG.md (history).
     baseline = ./codegen-quality-probe-verdict.md; mechanism design = ./unbox-native-r5/DESIGN.md. -->

# Native-backend unboxing — runtime-gap all-closure roadmap

Goal: close the 2.9–23× hexa-native-emit vs gcc -O2 gap (probe
`state/codegen-quality-probe-verdict.md`) by unboxing the boxed-HexaVal tag-dispatch on the
APRIME native backend (`compiler/codegen/x86_64_linux.hexa` / `arm64_darwin.hexa`), the path the
probe measured. Mechanism = let provably-monomorphic-int BinOps skip the `call hexa_*` dispatch
and use the EXISTING native ALU/setcc path. Gate-OFF byte-identical, gate-ON measured.

## R1 (k1_sum scalar slice) — MECHANISM PROVEN, RELEASE-SAFE — 2026-06-26

Branch `perf/codegen-unbox-native-r5` (commits 368992fa→dee8a726), flag `HEXA_UNBOX_NATIVE=1`
default-OFF. Measured on summer:

| gate | verdict | evidence |
|------|---------|----------|
| G1 OFF-byteeq | **PASS** | patched-OFF .o == baseline .o sha `7d9066ea` (same-cwd). prior FAIL = DWARF comp-dir `src` vs `base` artifact, .text byte-identical |
| G2 lever | **PROVEN** | ON: `imul r10,1009` / `add r10,r11` / `cmp+setl` replace `call hexa_mul` / `hexa_add_slow` / `hexa_cmp_lt`. hexa_add 2→0, hexa_mul 1→0, hexa_cmp 1→0 |
| G4 parity | **OK** | OFF==ON output `840001701` (unboxing does not change result) |
| G3 ratio | **1.000 (no speedup)** | k1_sum is **%-bound**: `% M` → `call hexa_mod` still boxed, dominates the loop. Matches probe (k1_sum "only" 2.86× because even gcc pays a magic-multiply). |
| G5 smoke | **GREEN** | hexa v0.333.0 · hello rc=0 · exit42 rc=42 |

**Verdict:** the unbox mechanism is correct and release-safe (OFF inert + ON parity), but k1_sum
alone shows **no wall-clock win** because its hot op is the still-boxed `%`. The value of R1 is
the **proven release-safe mechanism**, not a k1_sum speedup. Honest negative on ratio, recorded.

## Where the real speedup lives (measured, not speculative)

1. **k1_sum `%` magic-reciprocal (r4 in the campaign plan):** to make k1_sum itself faster, the
   boxed `% M` (constant modulus) must lower to a magic-multiply + shift (gcc's
   `imul $0x89705f31...` strength-reduction, probe disasm). Needs a proven-nonzero divisor fact
   lattice (drop the runtime div-zero throw). Higher risk — the div path is the last residual.
2. **r2 — array element unbox (`k3_arrmap`, 23× — the biggest gap):** NOT %-bound. The inner loop
   is `a[i]` read/write + arith, today 7 boxed calls/element (`hexa_index_get/set` + arith). Unbox
   the int arith (same R1 mechanism) AND the native array read/write (`HexaArrI64->data[i]`). This
   is where the largest real wall-clock win is expected — no `%` to dominate.
3. **r3 — branchy int (`k2_collatz`/`k4_branch`, 12×):** tight modulo/branch loops; partly %-bound
   (needs item 1) but also benefits from comparison + arith unboxing (R1 mechanism, already proven).

## Roadmap

- [x] **R1 scalar BinOp unbox (+ - * < <= > >= ==)** — mechanism PROVEN release-safe (this doc).
      Land default-OFF after 3-target gen3≡gen4 byteeq CI GREEN (PR). NOT a k1_sum speedup (%-bound).
- [ ] **r2 array element unbox (k3, 23×)** — biggest real win, not %-bound. Extend the predicate to
      inference-certified native arrays; reuse the existing `HexaArrI64*->data[i]` read +
      add a native int-array write. Same gate set, same flag.
- [ ] **r4 `%`/`/` magic-reciprocal with proven-nonzero divisor** — makes k1_sum/k2/k4 actually
      faster (removes the last boxed call). Needs nonzero-fact lattice; highest risk, last.
- [ ] **arm64 parity** — push the same type facts into `arm64_darwin.hexa` `_STMT_BINOP`
      (`bl hexa_add_slow` → `add`/`madd`/`mul` on GPRs). x86 first (done), arm64 follow-on.

## Gate discipline (every slice)
Codegen is the highest-risk substrate (silent wrong-answer = flatten_globals class). Every slice:
G1 OFF-byteeq (same-cwd .o sha == baseline + 3-target gen3≡gen4 CI) BLOCKING + G4 output-parity
BLOCKING + G2 lever (disasm call-count) + G3 taskset-median ratio + G5 smoke. Default-OFF until
3-target byteeq GREEN; default-flip is a separate later decision. measure-first; no tune-to-green.
