# R5-R4 — HX3032 mutating-method-behind-shared-ref (HEXA-OWN L5-E8, Rust E0596)

Round5 dual-lane batch, rung R4 (own lane E8). Opt-in borrow checker
(`HEXA_BORROWCK=1`) diagnostic; pure reuse of the E3 loan registry, **zero new
borrow-checker state**. Spec: `state/hexa-own/round5_dual_lane_batch_plan.json`
`.result` §3 R4 / §1.4. Branched off `origin/main` (c92390aa5); Fable anchored
on afd85ea98 — all file:line re-anchored against the current tree before edit.

## Rule
`r.push(x)` (or `pop`/`truncate`/`set`) where `r` is itself a **live shared
(`&`) borrow** → Rust E0596 "cannot borrow `*r` as mutable, as it is behind a
`&` reference". A `&mut` receiver is legal (mutating methods require `&mut
self`), a call on the owner directly is legal, and a non-mutating selector never
reaches the scan.

## Anchors verified (against origin/main c92390aa5)
- emit helper insert point: before `_bck_emit_ret_escape` (was :999) — cloned
  from `_bck_emit_write_through` (:899). Spec said :999 ✓.
- call-arm receiver hook: `if _bck_active && _bk_is_method && _bk_recv_local >= 0`
  block (was :2744-2749); receiver `_bk_recv_name`/`_bk_recv_local` captured
  under `_bck_active` at :2554-2558 — no extra wiring. Spec said :2744-2748 /
  :2556 / :2553-2557 ✓.
- mutation predicate: **`_bck_is_mutating_method`** (:1228 — push/pop/truncate/
  set). §3 R4 pins this explicitly (NOT left open) — no invented mutator list.
- ref registry reused: `_bck_find_ref` (:715), `_bck_ref_origins` (:552),
  `_bck_ref_mut` (:559), `_bck_ref_lines` (:553). `let r = &x` RHS is `unop &`
  (:3269), so it registers ONLY in the E3 registry (not the M3 alias group) →
  `r.push` fires only HX3032, no HX3014 contamination.
- catalog append: after HX3029 block close (:570). Complete DiagSpec block
  incl. own `fix_it_kind: FixItKind::None` + closing `},` (catalog-hexa-1
  lesson — no shared trailing suffix). Parity: `grep -c 'DiagSpec {'` == `grep
  -c 'fix_it_kind:'` == **74** (was 73).

## Implementation delta
1. `compiler/lower/hir_to_mir.hexa`
   - `_bck_emit_mut_method_behind_ref(name, origin, method, borrow_line, sp)` —
     same-site dedup + STRICT Error re-band, args name/origin/method/borrow_line.
   - call-arm hook: inside the existing `if _bck_is_mutating_method(callee_text)`
     block, AFTER the existing `_bck_note_write`, scan `_bck_find_ref(_bk_recv_
     name)`; fire when the row is live (origin != "") AND `!_bck_ref_mut`.
2. `compiler/diag/catalog.hexa` — HX3032 DiagSpec (Warning band, STRICT re-band,
   `_bck_active`-inert byteeq argument, E0596 citation).
3. `compiler/check/borrowck_test.hexa` — `_run_mut_method_probe` (keys HX3032,
   zero-stray hygiene, STRICT Error-band assert) + 4 source probes:
   - hz `let r = &arr; r.push(1)` → ×1 (ON)
   - fp `let r = &mut arr; r.push(1)` → 0
   - fp owner `arr.push(1)` → 0
   - fp `let r = &arr; r.len()` → 0
   OFF sweep → empty stream for all.

## Conservative boundary
Only same-fn local receivers with a captured `_bk_recv_local` count. Methods on
module globals / struct fields / array elements, cross-function loans, and
killed loans (`let r = &x; r = 0; r.push(…)`) are silent (documented FN). No
double-report — no existing rung fires at this call span for a `&`-loan
receiver.

## byteeq neutrality
All new emit is inside `_bck_active` (default false) → structurally unreachable
on the default path → diag stream + emitted bytes byte-identical. Sibling
contract with HX3021~3031. Catalog data add is fixpoint-neutral.

## Merge ordering (per §5)
R1 → R3 → R4 → R2. This branch off origin/main places HX3032 directly after
HX3029; on serial rebase onto R3 the catalog conflict resolves to order
3030 → 3031 → 3032 (both blocks preserved, each complete). The emit-helper
insertion point (before `_bck_emit_ret_escape`) collides with R3's
`_bck_emit_assign_behind_ref` — resolve once at R4 rebase (keep both, R3's
first).

## Verification status
mini = git/gh/read only (pool discipline) — NOT built here. PR body carries the
NON-CI pool 3-mode (OFF/ON/STRICT) instructions; orchestrator gates byteeq
3-target + pool before merge. R3 must merge first (catalog HX3031 ordering).
