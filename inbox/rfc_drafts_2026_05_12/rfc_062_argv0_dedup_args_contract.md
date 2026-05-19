# RFC 062 — argv[0] dedup + args() contract migration

## 1. Status

- **Status**: **P0 COMPLETE · P1 attempted → WONTFIX recommended (2026-05-19)**.
  The contract-separation half of ROADMAP 65 is DONE (§3). The remaining
  argv[0]-dedup: P0 audit + a P1 implementation attempt established the true
  blast-radius = **60+ files** (§6c) for a change RFC §6 itself calls
  cosmetic (no user-visible bug). Recommendation: WONTFIX / indefinite defer
  — see §6c. P1 attempt code reverted; working tree clean.
- **Date**: 2026-05-19
- **Priority**: P2 — ROADMAP marks 65 "anima 최우선" for the *API* deliverable,
  which shipped; the dedup cleanup is hygiene, not a blocker.
- **Severity**: LOW (no correctness bug — the doubled layout is internally
  consistent today; this is vestigial-cruft removal).
- **Domain**: **compiler / runtime + CLI dispatcher**.

## 2. Problem

`hexa_set_args` (runtime.c:5548) inserts `argv[0]` **twice**:

```
native:   args() = [exec, exec, sub, user1, user2, ...]
                     ^0    ^1    ^2   ^3
```

The duplication existed solely to match the (now-deleted) interpreter's
`["hexa", "script.hexa", user...]` index layout, so the same `.hexa` source
read `args()[2..]` identically under interp and AOT. **R7 deleted the
interpreter** — the rationale is now moot, but the layout is load-bearing:

- `self/main.hexa`'s CLI dispatcher reads `av[2]` = subcommand, `av[3..]` =
  sub-args, `av[4..]` = forwarded argv (documented at main.hexa:2872).
- repo-wide: **191** `.hexa` files call `args()`; **12** sites index
  `args()[N]` with a literal; an unknown subset of the 191 index a cached
  `av`/`argv` for user args.

Removing the duplicate shifts every user-arg index by one. A missed site does
not crash — it **silently** reads the wrong argument. That blast radius is why
the runtime.c author deferred it.

## 3. What is already DONE (ROADMAP 65 part 1)

The canonical, layout-independent API shipped (runtime.c:5571-5591, explicitly
tagged "roadmap 65 / M3"):

- `hexa_script_path()` → the launched script/binary (`_hexa_argv[1]`).
- `hexa_real_args()` → user arguments only, identical across interp/AOT/stage0.

These are additive; `hexa_args()`/`hexa_set_args` were left untouched precisely
because the flip is breaking. **The contract-separation deliverable of 65 is
complete.** This RFC covers only the remaining dedup.

## 4. Proposal — migrate consumers first, flip last

The flip must be the *last* step, after no consumer depends on the doubled
layout. Three phases:

| Phase | Deliverable | Gate |
|-------|-------------|------|
| **062-P0** | Audit ledger — enumerate every `args()` / cached-`av` indexing site across self/ + tool/ + bench/ + stdlib/; classify each index as *driver-slot* or *user-arg*. Audit-only. | ledger reviewed; user-arg site count known |
| **062-P1** | Migrate every *user-arg* reader to `real_args()` / `script_path()`. **Zero layout change** — `args()` still doubled; consumers simply stop indexing it for user args. Each migrated site keeps byte-identical behavior. | per-subcommand CLI arg-parse byte-eq; 23-verb dispatch + batch driver unchanged |
| **062-P2** | Once no user-arg reader indexes `args()[2..]`, remove the duplicate insert in `hexa_set_args` (`args() = [exec, user...]`), reindex `self/main.hexa`'s dispatcher (`av[1]`=sub, `av[2..]`=args). | full CLI corpus byte-eq; self-host fixpoint; atlas 118/118 |

P1 carries all the risk-reduction: it is reversible per-site and changes no
layout. P2 is the one-shot flip, but by then it touches only the dispatcher +
the (already audited) driver-slot sites.

## 5. Falsifier battery (pre-registered)

1. **F1 per-subcommand arg-parse** — for each `hexa <verb> …` form, captured
   argument vector is byte-identical before/after each phase.
2. **F2 23-verb dispatch** — every absorbed-verb subcommand still resolves.
3. **F3 batch driver** — `hexa batch` argv forwarding (`av[4..]`) unchanged.
4. **F4 self-host fixpoint** — `hexa cc --regen` byte-identical after P2.
5. **F5 atlas** — `atlas_verify_smoke` 118/118 after P2.

## 6. Honest caveats (g3)

- The dedup is **cosmetic correctness** — the current doubled layout produces
  correct CLI behavior. This RFC removes vestigial interp-compat cruft; it
  fixes no user-visible bug.
- P2 is genuinely breaking and must not be attempted as a single ad-hoc edit —
  the phased migration (P0 audit → P1 consumer move → P2 flip) is the design.
- Scope is the *toolchain* CLI. Downstream consumers (wilson, anima) that shell
  out to `hexa` are unaffected — the CLI surface (`hexa <verb> <args>`) does
  not change; only the internal `args()` array shape does.

## 6b. Phase 062-P0 — audit ledger (COMPLETE 2026-05-19)

Repo-wide grep of `args()` / cached-`av` indexing across self/ + tool/ +
stdlib/. **Key finding: the layout-dependent surface is 4 files, not 191.**
191 files *call* `args()`, but only 4 index it positionally for the doubled
`[exec, exec, sub, user…]` layout — the rest pass the whole array or read
`args()[0]` only.

**Layout-dependent consumers (the real migration set):**

| File | Sites | Current dependence | Post-dedup target |
|------|-------|--------------------|-------------------|
| `self/main.hexa` | ~30 `av[]` in the CLI dispatcher | `av[0]`=exec, `av[2]`=subcommand, `av[3..]`=sub-args; per-verb loop inits `ai=2 · ri=3 · bi2=3 · bi=4 · i=4(build) · cvi=5 · ti=3` | `av[0]` unchanged; subcommand→`av[1]`; every `av[N≥2]` and loop-init `N≥2` shifts −1 |
| `self/module_loader.hexa` | 3 (`args()[1]`=self path, `[2]`=input, `[3]`=output) | invoked `module_loader <in> <out>` → doubled | `[0]`=self, `[1]`=in, `[2]`=out |
| `self/codegen_c2.hexa` | `args()[2]` = input `.hexa` path (caller-dir hint, 3 ref sites L401/469/7687) | runs inside `hexa_v2 <src> <out>` → doubled | `args()[1]` = src |
| `tool/ssot_mirror.hexa` | `args()[2]`=target, `[3]`=source (L316-320) | explicit "`raw[1..]` … we use `[2..]` under interp" comment | `args()[1..]` |

`real_args()` already used at 5 sites (correct, layout-independent — no change).
`args()[0]` sites (main.hexa:1487/1499/1507, all in `install_dir_from_argv0`)
are exec-path reads — index 0 is **invariant** under dedup, no change.

**Revised P1/P2 sizing:** P1 (migrate user-arg readers to `real_args()`)
touches the 4 files above — `module_loader`, `codegen_c2`, `ssot_mirror` are
small (≤3 sites each); `main.hexa`'s dispatcher is the bulk (~30 sites, all the
uniform `−1` shift). P2 (drop the dup in `hexa_set_args`) is then a 5-line
runtime.c change. The migration is **bounded and mechanical** — materially
smaller than the RFC's initial "40+ sites" estimate once non-positional
`args()` callers are excluded.

**Gate for P1 start:** this ledger reviewed. ✅ P0 COMPLETE.

## 6c. Phase 062-P1 attempt — CORRECTED blast-radius (2026-05-19)

P1 implementation was started (runtime.c `hexa_set_args`/`hexa_real_args`/
`hexa_script_path`/`_hx_fuel` + main.hexa + module_loader + codegen_c2 +
ssot_mirror) and **uncovered that §6b's "4 files" is wrong by ~15×.** The P0
grep matched only literal `args()[<digit>]`. The dominant real pattern is
`args()` aliased — `let _args = args()` / `let argv = args()` / `let cli_args
= args()` — then indexed `_args[2]` or looped from `_ai = 2`. Those alias the
array, so the `args()[N]` regex never saw them.

**Exhaustive re-audit — positional-dependent consumers ≈ 60+ files:**

| Group | n | Pattern |
|-------|---|---------|
| `tool/roadmap_*.hexa` boilerplate | ~25 | `_raw_argv[1]=="run"` · `argv[2]==_script_token` · `_user_start=3` |
| `stdlib/sim_universe/**` | ~25 | `_args[2]` / `[3]` / `[4]` positional |
| `self/` | 5+ | main.hexa · module_loader · codegen_c2 · build_c · edit_cli/attr_cli/fs_fuse_skel (`_ai=2`) · hexa_build |
| `tool/` other | 10+ | flame_phase4* · ai_native_* · jit · emit_esm · ssot_mirror |

`real_args()` consumers (linter +4) and the scan-based `_slice_args()` /
`_resolve_caller_dir` helpers are layout-robust — unaffected.

**Revised verdict.** RFC 062 §6 already states the dedup *fixes no
user-visible bug* — the doubled layout is a harmless convention. A 60+-file,
multi-subsystem migration (roadmap tools + 25 sim-universe experiments + the
self/ bootstrap chain), every binary rebuilt and re-validated, for a purely
cosmetic cleanup, is a **bad trade**. The `runtime.c:5571` author's deferral
was correct; if anything "40+ sites" understated it.

**Recommendation: P2 → WONTFIX (or indefinite defer).** ROADMAP 65's valuable
half — the canonical `script_path()`/`real_args()` accessors — already shipped
(runtime.c:5571-5591) and *is* layout-independent; new code should use those.
The argv[0] de-duplication itself is not worth the migration. The P1 attempt's
code changes were reverted (working tree clean); this measured finding is the
deliverable.

## 7. Non-goals

- No change to the external CLI surface or any subcommand's behavior.
- Not introducing a new args API — `real_args()`/`script_path()` already exist.

## 8. Cross-link

- ROADMAP child **65** — part 1 (API) done; this RFC scopes part 2 (dedup).
- `runtime.c:5571-5591` — the deferral note this RFC discharges.
- AGENTS.tape `@D g_interp_deprecated` — R7 closure is what makes the dedup
  possible (the interp-layout-match rationale is gone).
- Sibling self-host child 69 → RFC 061.

## 9. PLAN integration

Tracked in `compiler/PLAN.md`. On greenlight, 062-P0 (audit ledger) is the
first cycle — cheap, audit-only, and it produces the user-arg site count that
sizes P1.
