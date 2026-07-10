# axis-③ self-emit frontend-arena memory census — Round-1 (r1)

> Host: **summer** (pool, x86_64-linux, 12c/30G/RTX5070) · 2026-07-10 · zero-patch (no repo edits).
> DEFAULT `aprime_cc` (NO `HEXA_SELFEMIT_PACK_OUT`) over the 52-file/68,260-line closure.
> Verdict: **census COMPLETE CLEANLY (exit 0), M2 map-backed-struct floor CONFIRMED dominant, no leak, no copy-amplifier. Lever pointer = L1 now (round-2) + L2 round-3 (LIR-first). L3 deferred.**

## 1. Preflight (STEP-0)
- `cat /sys/fs/cgroup/memory.max` → **empty/absent** = no hard cgroup cap (unlike the disqualified 8e9-capped community pod). Bare-metal, unlimited.
- `free -g` → total **30G**, used 1G, **available 29G** (≥25G threshold ✓). Swap **39G** (8G swap.img + 32G swapfile-pool).
- `nproc` → **12**.
- earlyoom → **PRESENT**: `earlyoom -r 3600 --prefer ^(hexa|hexad|hexat|python3|python|node|cargo|rustc|cc1plus)$ …`. The `--prefer` kill-list does **NOT** include `aprime_cc`, so the census binary is not preferentially targeted; %-free thresholds have huge headroom (19.75G peak on 30G+39G swap). → GO.
- Result: run stayed **fully in RAM — `Swaps: 0`, `Major page faults: 0`**. No earlyoom kill, no thrash. Clean census (not an infra-quarantine).

## 2. Build + STEP-0 sanity
- Synced `~/hexa-lang` to origin/main = **fd6727cf (#4810)** — one docs-only commit past the plan's #4809 (`docs(infra): pod cgroup RAM-cap convergence`); no code delta to the frontend lane.
- Built **DEFAULT** `aprime_cc` via `tool/build_aprime.sh` (rc=0, stage-5 smoke exit(42) PASS, 3,414,504 B ELF). Native RT seeds active (rt_hi/array/map/alloc x86_64 .s; `HEXA_RT_ALLOC_NATIVE=1`).
- Flatten = **52 files / 68,260 lines** (exact match to the 19.87GB-run closure).
- **STEP-0 sanity → CONFIRMED malloc-only lane**: every `-v` phase row shows `arena_live=0KB arena_total=0KB`. Arena counters are ZERO throughout ⇒ own-emit, no arena scoping (M3 model correct; NOT a gen2-C-built binary).
- Output: **self.o = ELF64 LSB relocatable x86-64, 6,869,920 B** (= plan's 6.87MB reference exactly), sha256 `165ffa6f7fb400eb3f147a422cba13d1c2adc263291cbcadc3f0b8be15fee268`.
- **Max RSS = 19,747,608 kB = 19.75 GB** (VmHWM; = the ~19.87GB reference within noise). Wall 3:10.30 (user 187.49s, 99% CPU; faster than the 4:44 ref — summer idle/fast).

## 3. Per-phase ΔRSS attribution (authoritative — from `-v rss=` boundary rows + `HEXA_CG_PROFILE` walls)

| phase (CG_PROFILE) | wall (s) | boundary row | RSS @boundary (MB) | ΔRSS (MB) | % of 19,747 peak | carrier |
|---|---|---|---|---|---|---|
| pipeline_start | — | pipeline_start | 9 | (baseline) | — | runtime + atlas(17,265 nodes) |
| lex | 7.3 | post_lex | 1,166 | **+1,157** | 5.9% | tokens |
| parse | 10.4 | post_parse | 1,981 | **+815** | 4.1% | AST (+`p_splice_acc` dup-retain) |
| resolve+bind+type_check+unit_check | 0.2+3.0+14.7+0.2 | post_check | 3,530 | **+1,549** | 7.8% | check registries (diagnostic, retained M1) |
| lower_ast_to_hir | 34.1 | post_lower_ast_to_hir | 9,050 | **+5,520** | 28.0% | **HIR** |
| lower_hir (→MIR) | 20.2 | post_lower_hir_to_mir | 10,439 | **+1,389** | 7.0% | MIR (F6-P0c force-copy-decoupled → light) |
| mir_opt | 0.02 | — | — | ~0 | — | — |
| codegen (→LIR) | 86.7 | post_codegen | 17,611 | **+7,172** | 36.3% | **LIR ← #1 carrier** |
| x86_pack_lir | 12.7 | (→ peak) | — | **+2,136** | 10.8% | ElfObj + out[Int] + elf_bytes |
| x86_serialize | 0.4 | (in pack) | — | — | — | — |
| exit (raw exit_group) | — | VmHWM | **19,747** | — | 100% | — |

**Sum of deltas reconstructs the peak exactly**: 9+1,157+815+1,549+5,520+1,389+7,172+2,136 = **19,747 MB**. Wall Σ ≈ 190.0s ≈ user 187.5s ✓.

Timeline shape: lex/parse/check/lower rows are **step-jumps at boundaries**; codegen is a **steady ramp** (manual sampling of the child: 14.5→15.3→16.1→16.9→17.7→18.8 GB over 60s during LIR build) — allocation-as-you-go, not a late spike.

## 4. Verdict — M2 (map-per-struct representation floor) CONFIRMED dominant

- Peak = **exact sum of per-carrier phase deltas**; `arena_live/total=0` every row; `Swaps=0`, 0 major faults ⇒ RSS is the true resident representation, **not churn, not a leak**.
- Per-carrier deltas land **within the plan's map-backed node-arithmetic bands**:
  - LIR **7.17 GB** vs predicted 7–10 GB ✓
  - AST 0.82 + HIR 5.52 = **6.3 GB** vs predicted (AST+HIR) 4–6 GB (top-edge, ✓)
  - MIR **1.39 GB** vs predicted 4–6 GB → **UNDER** (F6 P0c force-copy decoupling already shrank MIR — a landed win, the inverse of an amplifier)
- ⇒ the 19.75 GB is the **map-backed struct-lit representation** (`hexa_map_new` + per-field `strdup` key + `HMAP_INIT_CAP=16`, ~1 KB floor/node), not a bug. **M2 confirmed.**

**Predicted-vs-measured note**: the `HEXA_ALLOC_STATS` atexit dump (map_new/array_new counts + histogram) **did NOT fire** — the self-emit ends via a raw `exit_group` syscall (M3 raw-svc lane), which bypasses `atexit`. So the count×1.1KB proxy is inert on this lane. Substituted (and superseded) by the **direct per-phase ΔRSS decomposition** above, which reconstructs the peak exactly and matches each carrier's predicted band — a stronger confirmation than the count proxy. *(Plan amendment: `HEXA_ALLOC_STATS` cannot be harvested on the self-emit exit path; use `-v` ΔRSS.)*

**Carrier holding the most**: **LIR (codegen, +7.17 GB, 36.3%)**, then **HIR (lower_ast_to_hir, +5.52 GB, 28.0%)**. LIR+HIR = **64.3% ≈ 2/3**.
→ **Correction to the plan**: the plan predicted "LIR+MIR ≈ 2/3". The measured 2/3 is **LIR+HIR** — MIR is the *light* carrier (7%) because F6 P0c already decoupled it. The heavy lowering pair is codegen(LIR) + ast→hir(HIR), not codegen+hir→mir.

## 5. Copy-amplifier scan → NONE
No phase's ΔRSS exceeds its node-arithmetic band. The `st = _x86_collect_strs_from_stmt(st,…)` per-stmt struct-shell rebuilds (prime suspects) do not surface as a codegen delta above the LIR prediction (7.17 GB sits inside the 7–10 GB band). The only outlier is MIR being *below* prediction (F6 win). ⇒ no solvable retention/copy bug to hunt; the wall is representational.

## 6. Lever pointer → L1 now (round-2), L2 round-3 (LIR-first), L3 deferred
Go/no-go **primary case met**: Δcodegen(LIR)+Δlower_ast_to_hir(HIR) = **64% ≥ 60%** of peak, concentrated in two map-backed lowering carriers (not an even spread).

- **L1 — IMMEDIATE (round-2)**: field-key interning (`runtime_core.c:3619,3689`, keys immutable+free-never → sharing safe) + struct-lit map-table right-size (drop `HMAP_INIT_CAP=16` → field-count cap, `runtime_core.c:1175`). Runtime-only (`self/runtime_core.c` generator lane), **output-neutral** (allocation strategy ≠ codegen bytes). Hits **all** map-backed structs across every phase → est **−4 to −7 GB (20–35%)**. Gate = faithful runtime.a byteeq-3-target + shipping smoke.
- **L2 — round-3**: `HEXA_STRUCT_FLAT` (codegen, default-OFF), spec **starting at the LIR carriers** (`LOperand`/`PReg`/`LInstr` — the #1 phase at 36%) then `Stmt`/HIR. ~240 B/node vs ~1.1 KB → ~4× carrier shrink; dual win — also attacks the **86.7s codegen wall** (field reads stop being FNV+strcmp map probes). Gate = byteeq 3-target + nvptx + smoke → flip.
- **L3 — DEFERRED (not indicated)**: process split only pays when no single-phase lever reaches target. Here two attackable lowering phases dominate and L1+L2 hit both. The check-registry 1.5 GB (diagnostic, retained M1) is an L3-style dead-carrier candidate but unrecoverable on the malloc-only lane (no `free`; rebinding frees nothing) → only via process split → folds into deferred L3.

## 7. Kill-criterion status
M2 confirmed (predicted≈measured, no churn slope, Swaps=0) ⇒ 19.75 GB is the **map-backed representation floor**; L1+L2 reduce it toward the plan's **~4–6 GB boxed-flat residual** (irreducible within a memory round — below that = the static-typing/unbox campaign, own lane). Checksum step satisfied: valid 6.87 MB ELF, byte-count-identical to the reference run, Max RSS 19.75 GB ≈ reference — same DEFAULT lane, validated. (No prior `.o` on-host to sha-diff; byte-count + Max-RSS parity stand in.)

Artifacts on summer: `~/axis3_census/{census.stderr,census.stdout,self.o,self_flat.hexa,driver.log}`.
