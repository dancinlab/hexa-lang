# mem-lane ② arena RECLAIM — RUNG-2a inter-procedural SUMMARY characterization

**Status:** ✅ landed as a REPORT-ONLY inter-procedural characterization rung.
NO emit, NO codegen change, **byteeq-neutral by construction**. **Decision gate
ANSWERED — go/no-go below.**

Branch `feat/mem-arena-reclaim-rung2a-summaries` (off origin/main @ #4703, includes
#4700/#4703). Built + measured on **aiden** (x86_64-linux, clang-18).
Design SSOT (verdict `RUNG2A-CHARACTERIZE-FIRST`, note = likely
`TERMINAL-NOT-ARENA-PROBLEM`): `scratchpad/arena_rung2_design.md`.

## What RUNG-2a does (report-only, byteeq-neutral)

`self/codegen.hexa`: a new pass `_arena_summary_build(ast)` runs a **bottom-up
monotone may-escape + region-safe worklist fixpoint** over every flattened
`FnDecl` body, wired in BOTH `codegen()` / `codegen_full()` **after** the
name-collection prescan (globals known) and **before** the emit loop (so
`gen2_fn_decl`'s widened C5 gate consumes complete summaries). Gated
`env("HEXA_ARENA_DETECT")=="1" && env("HEXA_ARENA_NO_IP")!="1"` (FIRST `&&`
operand). `HEXA_ARENA_NO_IP=1` = the P0 leaf-only baseline (summaries stay empty).

### Summary lattice (per `FnDecl`, name-keyed parallel arrays, beside `_arena_reclaim_*`)
- `param_escape[j]` — 2-point `NoEscape ⊑ Escape`, one slot/param, init OPTIMISTIC
  NoEscape, **monotone RAISE**. Computed by a summary-aware ARRAY escape scan
  (`_stmt/_expr/_stmts_escape_arr_name_ip`) = exact clones of the base arr-name
  scans (index-read + `len` iteration-local; store / return / index-write /
  reassign / call-arg escape) differing **only** at the Call-arg arm: a bare param
  at arg position j of a RESOLVED direct user-fn callee escapes iff that callee's
  `param_escape[j]==Escape` (or ⊤ / out-of-range).
- `ret_alloc` / `glob_store` — iteration-invariant leak facts (returns a fresh
  container / stores an alloc into a module global), computed once.
- `region_safe` — init OPTIMISTIC true, **monotone LOWER**:
  `region_safe(C) = singly-def & !ret_alloc & !glob_store & (all params NoEscape) &
  (every callee region-safe, transitively)`. A leaf builtin (len/print/…) or leaf
  method (push/append/len/to_string) is region-safe; every **unknown / indirect
  (hexa_call1 / fn-value) / extern / multi-def** callee ⇒ ⊤ ⇒ not region-safe
  (contagious). The worklist handles mutual recursion / SCC conservatively with NO
  explicit Tarjan (proved by the SCC adversary). Non-convergence ⇒ ALL-⊤ fallback.
- Depth-guarded scanners (cap 1400 frames) return the ⊤-conservative answer on a
  too-deep body (native-stack safety) — only ever UNDER-widens (sound). 5 corpus
  files trip it; `depth-tripped=1` reported.

### CONSUMPTION (widened C5 gate + cand-escape arm)
- `_arena_reclaim_expr_leaf` Call arm: a user-fn call is leaf-safe iff
  `_fn_summary_call_region_safe(callee)`; indirect callee kept as `return false` (⊤).
- `_arena_reclaim_expr_escapes` Call arm: a cand passed bare to a resolved callee
  escapes iff that param is Escape (⊤ on any miss).

## ★ Byteeq-NEUTRAL (confirmed empirically, aiden)

Report-only: eprintln fire-rate only, no `chunks.push`, env-gated. Emitted C from
`build/lx8664/cc-flat.hexa` is **4,233,991 B** and **BYTE-IDENTICAL** flag-ON vs
flag-OFF (`cmp` identical), while flag-ON emitted 562 `[arena-*]` stderr lines.
Same 4,233,991 B P0 baseline. Repros + corpus files also byte-identical ON/OFF.
Whole-compiler summary (cc-flat): fns=1696 · region-safe=69 (~4%) · top=0 ·
indirect-bodies=0 · rounds converged · depth-tripped=0.

## ★ Soundness oracle (aiden, `HEXA_ARENA_DETECT=1`) — FP = 0

`.verdicts/d8-arena-pushleak/repros/` — 5 NEW inter-procedural adversaries + 1 NEW
IP positive control (all `ip_*`), plus the pre-existing d8 set:

| repro | callee summary | widened | verdict |
|---|---|---|---|
| ip_global_store_via_callee | stash_it: esc=1/1, region-safe=0 | **0/2** | ✓ REJECTED (param→global) |
| ip_return_arg_escape | wrap: esc=1/1, region-safe=0 | **0/2** | ✓ REJECTED (arg captured+returned) |
| ip_scc_recursive_escape | ping/pong: esc=1/2, region-safe=0 | **0/2** | ✓ REJECTED (SCC — no Tarjan needed) |
| ip_indirect_call_escape | apply_fn: esc=2/2, region-safe=0 | **0/2** | ✓ REJECTED (hexa_call1 / fn-value ⇒ ⊤) |
| ip_transitive_callee_escape | leaf_esc/top_fn: esc=1/1, region-safe=0 | **0/2** | ✓ REJECTED (3-deep transitive) |
| **ip_readonly_callee_safe** (POS ctrl) | peek: esc=0/1, region-safe=1 | **1/2 (IP) · 0/2 (NO_IP)** | ✓ FIRES only via IP (discrimination) |

**Every inter-procedural adversary reads 0 widened.** No loop calling a leaking /
returning / global-storing / indirect / SCC-recursive callee is ever flagged
reclaim-safe. The positive control flips 0→1 widened ONLY with summaries on. The
primary sound backstop is the region-safe C5 gate: a leaking callee is
region-safe=0 ⇒ nonleaf ⇒ loop rejected regardless of the cand-escape tally.

## ★★ THE DECISION MEASUREMENT — real churn corpus (decode + QFORGE)

`self/ml/*decode* + batch_inference + continuous_batching + stdlib/qforge/* +
stdlib/cloud/qforge*` — **594 loop-bearing fns / 1746 loops** (matched file set
both modes; davidson_block_e2e_bench + sternheimer_block_e2e_bench excluded =
pre-existing seed-transpiler SEGV, flag-independent):

| mode | strict | widened | cand | nonleaf | escape | nonstruct | outerwrite |
|---|---|---|---|---|---|---|---|
| **NO_IP** (P0 leaf-only baseline) | 0 | **1** | 96 | **77** | **87** | 0 | 23 |
| **IP-ON** (rung-2a summaries) | 0 | **2** | 96 | **75** | **77** | 0 | 23 |

- **NO_IP EXACTLY reproduces P0's 77/87/1** → the baseline is validated.
- IP widening delta: nonleaf **77→75 (−2)** · escape **87→77 (−10)** · widened
  **1→2 (+1)**.
- **The +1 widened loop is NOT a churn hot loop** (an incidental helper, like P0's
  `_phased_vnl`). **Every real churn hot loop stays 0 widened:**
  `qforge_assemble_h_multi` 0/10, `qforge_elph_g2` 0/17, `dv_run` 0/13,
  `qforge_dvnl_du_block` 0/8, `infer_batch_shared_prefix` 0/4, `jacobi_step` 0/3.
- Their summaries explain WHY IP cannot help: the churn-allocating kernels
  **RETURN their allocations** (`ret_alloc=1`: `qforge_assemble_h_multi` [18 params,
  esc 4], `qforge_elph_g2` [9 params, esc 7]) and/or **escape params + write outer
  accumulators** (`infer_batch_shared_prefix` esc 3/4; the hot loops carry
  `escape≥1` and `outerwrite≥1`). A callee no-escape summary lets the OUTER loop
  reclaim its sub-arena but does **nothing** for allocations the callee itself
  makes and RETURNS or holds device-side.

### Real-churn loop verdict — `batch_inference.hexa:485`
The concrete shared-prefill decode loop `while pos < sys_len { … emb =
load_embedding(model,tok); result = transformer_forward(…); sys_kv_keys =
result[1]; sys_kv_vals = result[2]; … }` does **NOT** cross into reclaim-safe:
1. **No literal-init cand** (`tok`/`emb`/`result` are Call/Index inits, not `[…]`
   literals) → not even a reclaim candidate (cand=0 for the infer* fns).
2. `load_embedding` / `transformer_forward` are **imported (not FnDecls in the AST)
   ⇒ ⊤** here; in a flattened build `transformer_forward` returns a tuple
   (`ret_alloc=1`) ⇒ region-safe=0 ⇒ nonleaf.
3. `sys_kv_keys = result[1]` / `sys_kv_vals = result[2]` reassign **OUTER
   accumulators** — an escape channel summaries **fundamentally cannot fix**.

The 22.7 GB-class churn lives INSIDE `transformer_forward`'s returned tensors
(GEMM/attention), *behind* the call and largely device-resident.

## ★★★ GO / NO-GO = **TERMINAL-NOT-ARENA-PROBLEM**

Inter-procedural callee no-escape summaries — the design's named "real unlock" —
move the real churn corpus by nonleaf −2 / escape −10 / **widened +1 (an incidental
helper, zero churn hot loops)**. The 22.7 GB churn is **not** a hexa-arena-reclaim
problem: the churn-allocating kernels RETURN their allocations (`ret_alloc=1`,
which a no-escape callee summary cannot reclaim) and the decode loops write OUTER
accumulators (which summaries cannot address). This EMPIRICALLY confirms the
design's terminal-risk prediction.

**Do NOT build the RUNG-2b EMIT.** It would ship byteeq-neutral default-OFF and is
mechanically sound, but it reclaims only fn-local synthetic shapes — **no
measurable memory win on the real target.** Declare the arena-reclaim lever a
**measured wall** and **pivot the 22.7 GB campaign to the device/forge-residency
track** (see the devres-decode + bytegpt-decode-leak SSOTs — `_bg_rd_farr_at`
boxed-byte device residency, decode driver in anima).

Never relax the indirect-callee ⊤ guard; never build an explicit SCC/Tarjan (the
monotone worklist suffices — proved by `ip_scc_recursive_escape`).

## Build / measure recipe (aiden)

```
# ~/hexa-arenadetect/build has the #4703 seeds (hexat, runtime.a, lx8664/cc-flat.hexa)
git worktree add ~/arena_rung2a_wt <branch>; cp -a ~/hexa-arenadetect/build/{hexat,runtime.a} ~/arena_rung2a_wt/build/
cd ~/arena_rung2a_wt
HEXA_LANG=$PWD HEXA_V2=$PWD/build/hexat OUT=$PWD/mine_cc.c sh tool/regen_cc_manual
clang -O2 -std=gnu11 -D_GNU_SOURCE -Wno-trigraphs -fbracket-depth=4096 -nostartfiles \
      -I self -I . mine_cc.c build/runtime.a -o hexat_mine -lm -ldl
# decision:   HEXA_ARENA_DETECT=1 [HEXA_ARENA_NO_IP=1] ./hexat_mine <src> /tmp/o.c 2>&1 | grep arena
# byteeq:     cmp <(./hexat_mine cc-flat.hexa …) <(HEXA_ARENA_DETECT=1 ./hexat_mine cc-flat.hexa …)  # IDENTICAL, 4,233,991 B
```

## Note — diagnostic nuance (not a soundness issue)
On a mutually-recursive escaping callee (`ip_scc_recursive_escape`), the loop is
rejected via the region-safe/leaf gate (nonleaf=1) with escape=0 in the cand tally,
and the recursive callee's `esc-params` reads 1 (one param flagged). This is a
tally-attribution nuance of the fixpoint on SCCs; the region-safe verdict (what the
C5 gate consumes) is correctly FALSE, so the loop is soundly rejected and the
adversary reads 0 widened.
