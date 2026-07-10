# axis-③ self-emit memory — the 19.87 GB wall: attribution + lever round

> 2026-07-10. Root-cause/design round for the native own-emit self-compile peak RSS
> (`aprime_cc --emit=obj --backend=native --target=x86_64-linux-gnu`, 52-file/68,260-line
> closure → 19.87 GB peak, wall 4:44, valid 6.87 MB ELF `.o`).
> Premise (measured, do not re-measure): `SELFEMIT_PACK_OUT` (R6/R7) is INERT for peak RSS —
> the serialize accumulator caps at ~220 MB fully boxed for a 6.87 MB output. The wall is
> upstream. **Lesson R6/R7 (`codegen-hexa-2`): size the target before building the lever.**
> Note: `SELFEMIT_PACK_OUT` is not even on this branch — it lives in the `self/` gen2
> emitter-lane worktrees, not `compiler/emit/` (part of the original misattribution).

## 0. Verdict model (source-derived, to be confirmed by Round-1 census)

The 19.87 GB is **not one arena and not one leak**. It is the *sum* of five whole-program
IR carriers, each represented as **hash-map-backed boxed structs** that are **never freed**,
all simultaneously resident at serialize time:

```
AST(×2 aliases) + HIR + MIR + LIR + ElfX86Obj + out[Int] + elf_bytes   — all live at write_bytes
```

Three stacked mechanisms:

### M1 — every carrier is process-lifetime (retention)
The pipeline is top-level script code in `compiler/main.hexa`; every carrier is a
module-scope `let` that lives to `exit(0)`:
- `module` (AST, all 52 files flat-spliced) — `main.hexa:631`. **Double-retained**: the
  parser returns `Module { items: p_splice_acc, ... }` (`compiler/parse/parser.hexa:3131`)
  and the module-scope global `p_splice_acc` (`parser.hexa:56`) keeps a second reference
  until the *next* `parse()` call. `tokens` (`main.hexa:628`) and `source` (`:537`) also persist.
- `hmodule` — `main.hexa:742`; `mmodule` — `:806`; `lmodule` — `:919-927`;
  `elf_obj` + `elf_bytes` — `:1001-1002`, both live at `write_bytes` (`:1003`).
- Retention audit (verified this branch): codegen entry is
  `codegen_x86_64_linux(module: MModule, opts)` (`compiler/codegen/x86_64_linux.hexa:6004`)
  — **MModule only**. No HModule, no atlas (empty for obj since `main.hexa:651`), no type
  table (the "type interning table" of `ir/mir.hexa:31` is a pure fixed mapping,
  `hir_to_mir.hexa:181-208` — it has no storage). DWARF spans collapse to one i64
  `def_line` at lowering (`ir/mir.hexa:131`); the native ELF pack reads no spans at all
  (zero `def_line` hits in `compiler/emit/elf_x86_64.hexa`). Check-pass registries
  (`check/types.hexa:968-1151`, `check/bind.hexa:68-72`) are diagnostic-only, unread
  downstream. **So AST+tokens+source+HIR are provably dead during codegen/pack/serialize
  — dead-but-retained.**
- The `phase_reset()` calls (`main.hexa:642,738,762,845,946,1028`) reclaim only bump-arena
  *scratch* via the `__HEXA_ARENA_PHASE_RESET__` side-channel (`self/runtime.c:13058-13064`);
  the carriers are explicitly exempt ("immune to bump-arena rewind", `main.hexa:640`).

### M2 — every struct instance is a hash map (~1 KB floor per node)
The own-emit backend lowers `struct_lit` to `hexa_map_new()` + one `hexa_map_set()` per
field (`x86_64_linux.hexa:3265-3299`, "struct_lit constructor (map-backed)"). Per instance
(`hmap_alloc_ex`, `self/runtime_core.c:3326-3352`, `HMAP_INIT_CAP=16` at `:1175`):
16 B `HexaMap` + table hdr + 16×24 B slots + 16×16 B vals + order arrays + **per-instance
strdup of every field-name key** (`runtime_core.c:3619,3689` — map keys bypass the <64 B
string intern) + a `"__type__"` pair (`:3568-3606`) ≈ **~1.0-1.2 KB per struct before payloads**.
Arrays: 24 B heap `HexaArr` descriptor per array — calloc'd fresh per `[]` construction,
never shared (`runtime_core.c:2510-2526`; `x86_64_linux.hexa:3241`) — + 16 B/element boxed
items. Strings <64 B are interned; longer ones get a 16 B header copy; **strings are
free-never by design** (`runtime_core.c:2152-2155`, "zero free(HX_STR) call sites repo-wide").

Per-node stacking (each nested struct field = its own map):
- AST `Expr` = Expr map + `Span` map + `AtlasRef` map (with its own Span) + 2 array descriptors ≈ **~2.5-3 KB/node**
- HIR `HExpr` = map(8 fields) + Span + `Type` map (+args/ret) + `AtlasBinding` + `DefId` ≈ **~4-5 KB/node** (`ir/hir.hexa:48-62`)
- MIR `Stmt` = map + `dst: Local` map(6 fields) + args array + 1-3 `Operand` maps(6 fields) ≈ **~3-5 KB/stmt** (`ir/mir.hexa:55-73`)
- LIR `LInstr` = map + `[LOperand]` where each LOperand carries **two 5-field `PReg` maps** + label ≈ **~4-6 KB/instr** (`ir/lir.hexa:35-50`)

Closing the arithmetic: a 6.87 MB `.text` ≈ ~1.5-1.8M machine instructions → LIR alone
≈ 7-10 GB; MIR (~1-1.5M stmts) ≈ 4-6 GB; HIR+AST (~0.6-1M exprs ×2 trees) ≈ 4-6 GB.
**Sum ≈ 15-22 GB — the measured 19.87 GB needs no leak to explain. LIR+MIR ≈ ~2/3.**

### M3 — own-emit binaries never reclaim anything (no arena scoping)
The gen2 C backend emits `__hexa_fn_arena_enter/return` on all fn boundaries
(`self/codegen.hexa:2076-2085`); **the native own-emit backends emit neither** — zero
`arena_enter|arena_return` hits in `compiler/codegen/x86_64_linux.hexa` / `arm64_darwin.hexa`.
So in a self-emitted binary `__hexa_val_mark_top` stays 0, the val/array arena paths bail
("Must be inside a live scope mark", `runtime_core.c:2485`; `from_arena=0` at `:3561`),
and **every map table, items buffer, and string is malloc'd with no free** — transient
scratch (per-stmt struct-shell rebuilds like `st = _x86_collect_strs_from_stmt(st, ...)`
per statement, `x86_64_linux.hexa:5745-5762`) accumulates as permanent RSS on top of the
live carriers. `STMT_ARENA_NEW/DROP` are defined (`ir/mir.hexa:92-93`) but never produced
or handled — dead. The only working reclaim from `.hexa` is the `env("__HEXA_ARENA_*")`
side-channel, which needs live marks.

**Corollary — why the closed campaigns don't collide**: this is NOT the runtime value
arena (arena-reclaim TERMINAL, #4703/#4706) and NOT `HEXA_STREAM_RECLAIM` (A5.3
correctness gaps, force-OFF, re-activation forbidden). The M1/M2 levers below touch
neither: they shrink the representation and the carrier count, not the reclaim machinery.

## 1. Round-1 = the census (zero-patch — the instrumentation already exists)

All probes are already wired into the runtime substrate; no code change is needed:
- `-v` → `phase_reset`/`phase_log` fire `__HEXA_PHASE_LOG__<name>` which prints
  `[hexa-runtime/phase] <name> rss=..MB arena_live=..KB arena_total=..KB` at every phase
  boundary (`self/runtime.c:13084-13105`; call sites `main.hexa:559-570,642,738,762,845,946,1028`).
- `HEXA_CG_PROFILE=1` → per-phase wall (`main.hexa:572-622`).
- `HEXA_ALLOC_STATS=1` → atexit dump: `array_new/push/grow/str_concat/map_new/map_set/...`
  + log2 size histogram + arena counters + `rss_peak_mb` (`runtime_core.c:2256-2425`).
- `env("__HEXA_ARENA_RSS_MB__" / "ARENA_LIVE__" / "STATS__")` callable from `.hexa` if
  in-loop marks are ever needed (`runtime.c:13011-13081`).

### Host
Fresh **RunPod CPU pod, ≥48 GB RAM** (19.87 GB peak + census headroom; aiden/summer are
saturated by peer self-emit jobs + earlyoom — proven clean path per `build-aprime-sh-1`).
Same aprime_cc build + closure as the 19.87 GB run.

### Commands (pod)
```bash
cd <harness dir with aprime_cc + compiler closure>
# 1. census run — phase RSS rows + wall + alloc totals, plus a 1 Hz RSS timeline
HEXA_CG_PROFILE=1 HEXA_ALLOC_STATS=1 \
  ./aprime_cc --emit=obj --backend=native --target=x86_64-linux-gnu -v \
  -o /tmp/self_census.o compiler/main.hexa 2> /tmp/census.stderr &
PID=$!
while kill -0 $PID 2>/dev/null; do
  echo "$(date +%s.%N) $(awk '/VmRSS|VmHWM/{printf "%s=%s ", $1, $2}' /proc/$PID/status)"
  sleep 1
done > /tmp/rss_timeline.log
wait $PID; echo "exit=$?"
# 2. extract the attribution table
grep -E 'CG_PROFILE|hexa-runtime/phase|HEXA_ALLOC_STATS' /tmp/census.stderr
# 3. sanity: .o byte-identical to the 19.87GB run's .o (census flags are read-only)
sha256sum /tmp/self_census.o <previous .o>
```

### Step 0 sanity (before trusting rows)
- `[hexa-runtime/phase]` rows present? If absent, the aprime_cc runtime.a predates the
  hook — rebuild runtime.a from the current substrate (canonical `tool/stage_resolve_runtime_a`).
- `[HEXA_ALLOC_STATS] ... arena_alloc=` ≈ 0 and `STATS__ marks=0` confirms the M3
  malloc-only lane (own-emit, no scoping). If arena counters are LIVE, the binary is
  gen2-C-built — the M3 model is wrong for this lane, stop and re-derive.

### Deliverable — the attribution table
| phase (row) | wall | RSS at boundary | ΔRSS | Δ shape (timeline) |
|---|---|---|---|---|
| post_parse | | | ≈ AST(+tokens) | step vs slope |
| post_check | | | ≈ check scratch | |
| post_lower_ast_to_hir | | | ≈ HIR | |
| post_lower_hir_to_mir | | | ≈ MIR | |
| post_codegen | | | ≈ LIR | |
| post_emit/pack/serialize (exit) | | | ≈ ElfObj+out+bytes | |

Plus predicted-vs-measured: `map_new` count × ~1.1 KB + `array_new` × 24 B + boxed-items
bytes vs `rss_peak_mb`. **Match within ~±25% ⇒ M2 representation floor confirmed (no leak).
A phase whose ΔRSS ≫ its carrier arithmetic ⇒ a copy-amplifier bug in that phase — hunt it
(the `st = collect(st, stmt)` per-stmt struct-shell shapes are the prime suspects).**

### Optional round-1b (only if within-phase attribution is needed)
5-line gated patch: per-1000-items `env("__HEXA_ARENA_RSS_MB__")` marks inside the
`lower_hir` loop (`hir_to_mir.hexa:4509`) and codegen loop (`x86_64_linux.hexa:6017`),
behind `HEXA_MEM_CENSUS=1`. Byte-neutral (stderr only, flag-gated).

## 2. Levers, ranked (build order decided by the census go/no-go)

### L1 — struct map-table right-sizing + field-key interning (runtime-only, fastest)
**Mechanism**: (a) intern field-name keys in `hexa_map_set`/`hexa_struct_pack_map` instead
of per-instance strdup (`runtime_core.c:3619,3689`) — keys are immutable and free-never,
sharing is safe; (b) size struct-literal map tables to field count instead of
`HMAP_INIT_CAP=16` (`runtime_core.c:1175`) — a 6-field node needs cap 8, saving
~300 B slots+vals per node. **Files**: runtime substrate only (`self/runtime_core.c`
generator lane). **Est. win**: ~20-35% of total (−4-7 GB) across ALL map-backed structs.
**Byteeq story**: emitted `.o` bytes untouched by construction (allocation strategy is not
codegen output); gate = faithful runtime.a rebuild byteeq-3-target + shipping smoke.
Helps normal `hexa build` and every struct-heavy program, not just self-emit.

### L2 — flat-struct lowering for IR nodes (the 4-5× lever; codegen, default-OFF)
**Mechanism**: lower `struct_lit` to the existing 13-slot flat `HexaValStruct`
(`runtime_core_decls.h:91-105`, `hexa_valstruct_new_v` `runtime_core.c:4574` — today used
only by the interpreter's Val special case, `self/codegen.hexa:9235-9248`) for structs with
≤13 fields; field get/set by index instead of map probe. ~240 B/node vs ~1.1 KB ⇒
carriers shrink ~4×; **dual win**: field reads stop being FNV+strcmp probes, attacking the
125.8 s codegen wall too. **Files**: `x86_64_linux.hexa:3265-3299` (struct_lit) + field
get/set arms (`:3589` area) + `arm64_darwin.hexa` mirror + runtime accessors.
**Byteeq story**: changes emitted code ⇒ default-OFF flag (`HEXA_STRUCT_FLAT=1`),
byte-neutral OFF; flip after byteeq 3-target + nvptx + shipping smoke. This is the
memory-round face of the unboxing convergence (CODEGEN-BOXED-SCALAR-SLOWPATH) but scoped:
representation of struct payload slots stays boxed HexaVal — NOT the full static-typing campaign.

### L3 — dead-carrier release at phase boundaries (cheap only if census shows it pays)
`module`/`p_splice_acc`/`tokens`/`source` after `lower()`, `hmodule` after `lower_hir()`
(MIR is already forced-copy decoupled — F6 P0c, `hir_to_mir.hexa:142-155,4406`; residuals:
`name_hint` alias `:4464-4472`, `_lr_defer_bodies` `:418`). **Wall**: rebinding to empty
frees nothing on the malloc-only lane (no free exists; F6-optC `free_tree` failed —
`.s` drift + HX2001, `PLAN-stage3-footprint-F6-optA.md`). **So L3 is only real as a
process split**: `--phase=front` (parse→MIR, serialize MModule to disk) + `--phase=back`
(MIR→`.o`) — the OS frees the frontend at exec boundary; peak = max(front, back) ≈ half.
Medium effort (MIR serializer), default-OFF flag, verify = byte-identical `.o`.
Build only if the census shows no single phase dominates (i.e. L1/L2 alone can't reach target).

### Non-levers (measured/structural — do not build)
- **Streaming to x86 obj**: INERT without reclaim — `__hexa_fn_arena_return` heapifies
  returns to malloc, no free (`PLAN-stage3-footprint.md` Finding §1); and on the own-emit
  lane there are no fn-boundary scopes at all (M3). Streaming bounds the *logical* live
  set only.
- **`HEXA_STREAM_RECLAIM` / F6-optA `RETURN_REGION_ON__` reheat** (`stream.hexa:66-79`,
  `runtime_core.c:5003`): known SIGSEGV correctness gaps, re-activation forbidden
  (closed arena-reclaim campaign).
- **`[u8]` packing for ELF section arrays / out[Int]** (`elf_x86_64.hexa:851`,
  `hir_to_mir.hexa:200-206` lacks a u8 id): ~200-300 MB total — the R6/R7 trap; skip
  unless the census surprises.

## 3. Go/no-go (what the census decides)
- **Δcodegen+Δlower_hir ≥ ~60%** of peak (expected): round-2 = **L1 immediately**
  (runtime-only, fast), L2 spec'd for round-3 starting at `LOperand`/`PReg`/`LInstr`/`Stmt`.
- **Any phase ΔRSS ≫ its node arithmetic**: round-2 = hunt that phase's copy-amplifier
  first (targeted fix, like R6/R7 but validated).
- **Steps match arithmetic AND spread evenly**: L1 then L3 (process split) — no single-phase
  lever reaches the target.
- **Arena counters live (gen2 lane)**: model wrong — stop, re-derive with arena stats.

## 4. Kill criteria (when 19.87 GB is "irreducible by construction")
The honest floor is **node-count × flat-boxed footprint with all carriers summed**:
- If the census confirms M2 (predicted ≈ measured, no churn slope) then the 19.87 GB is
  the *map-backed* representation, and L1+L2 reduce it to a **~4-6 GB boxed-flat floor**.
  That residual is irreducible within a memory round: going lower means (a) typed/unboxed
  node fields = the static-typing/unbox campaign (own lane, not this round), or
  (b) fewer simultaneous carriers, where per-fn reclaim is measured-walled
  (F6/STREAM_RECLAIM) and the only structural move left is the L3 process split.
- Conversely: any phase where measured ≫ predicted is by definition a solvable
  retention/copy bug — the wall claim is falsified for that phase until it's fixed and
  re-measured.
- Stamp no memory win without the checksum step (§1 cmd 3) + a re-measured peak on the
  same pod class. (R6/R7 rule.)

## 5. Guardrails
- no-LLVM inviolable; all levers are own-runtime/own-codegen.
- L2/L3 land default-OFF byte-neutral → byteeq 3-target GREEN + shipping smoke → flip.
  L1 is output-neutral but gates on faithful-build byteeq + smoke (runtime.a ships).
- Release integrity > self-host progress: none of this touches the shipping path until flipped.
- mini = git/gh only; census + builds on the pod.
