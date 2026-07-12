# axis-① prerequisite: decouple resolve_hxroot() from the `self/native/hexa_cc.c` marker

SSOT for the marker-decouple campaign (Fable-designed). Deleting the C-transpile delegate
`self/native/hexa_cc.c` (the axis-① goal) would break `resolve_hxroot()` — which keys on that
exact file as its "is this a hexa root?" marker — silently reverting `hexa build` to clang-fallback.
So this decouple is a HARD PREREQUISITE for the delegate deletion.

## The coupling (measured)
`resolve_hxroot()` (self/main.hexa:1630) probes `env(HEXA_LANG)` → `install_dir_from_argv0()` → `.`,
each gated on `file_exists(<dir>/self/native/hexa_cc.c)`. It has 3 callers (:1689, :1710, :1765) —
one is `resolve_prebuilt_runtime()` (runtime.a fallback). On the real ~/.hx install the marker exists
via install.sh symlinking self/, so own-link fires today (aiden 5/5 clang-0, #4885). The break is
ONLY when hexa_cc.c is later removed. MARKER IRONY: the resolver depends on the file the campaign deletes.

## Design (Fable) — a dedicated `.hxroot` stamp, legacy fallback, 3-PR land order

### Sentinel: a committed/produced `.hxroot` stamp file (content `hexa-root v1`)
Not an existing durable file (build/runtime.a → false-positive risk in a non-root cwd that has build/;
stdlib/ → not guaranteed in every layout). A dedicated stamp is unambiguous and layout-independent.

`resolve_hxroot()` gains an `is_hxroot(d)` helper checking `.hxroot` OR the legacy `hexa_cc.c` marker
(fallback covers binary-only pool syncs whose install predates the stamp, until the deletion PR):
```
fn is_hxroot(d) {
    if file_exists(d + "/.hxroot") { return 1 }
    if file_exists(d + "/self/native/hexa_cc.c") { return 1 }   // legacy marker
    return 0
}
fn resolve_hxroot() {
    let __hxroot = env("HEXA_LANG")
    if len(__hxroot) > 0 && is_hxroot(__hxroot) == 1 { return __hxroot }
    let __i = install_dir_from_argv0()
    if len(__i) > 0 && is_hxroot(__i) == 1 { return __i }
    if is_hxroot(".") == 1 { return "." }
    return "."   // last resort — preserved
}
```

### Land order (deletion must NOT precede these)
- **PR-1 — producers (additive, no compiler change · THIS PR):** commit `.hxroot` at repo root;
  `tool/stage_precompile_package` writes `$stage/.hxroot`; `install.sh` writes `$HX_BIN/.hxroot`
  UNCONDITIONALLY (not via the tarball — covers HEXA_SKIP_SRC + old-tarball/new-installer combos).
  Gates: install.sh consumer smoke GREEN + release packaging GREEN (tarball gains one entry). Byteeq
  trivially unaffected (no self//compiler/ change).
- **PR-2 — resolver swap (self/main.hexa · shipping path):** the is_hxroot/resolve_hxroot body above.
  Gates: byteeq 3-target GREEN + install smoke + re-run the #4885 5/5 own-link clang-0 verification +
  the layout matrix below.
- **Then, before the axis-① deletion PR:** re-run install.sh on pool hosts so their ~/.hx gets the
  stamp (the self/ symlink source clone only advances when install.sh runs, so the moment an install
  loses hexa_cc.c is the same moment it gains .hxroot — coupling safe by construction; legacy arm
  covers binary-only syncs in between). Deletion PR drops the legacy is_hxroot arm.

### Neutrality (PR-2) — 2 enumerable deltas, both FIX a live silent clang-fallback (state, don't hide)
1. HEXA_LANG → a fresh checkout (no regen'd hexa_cc.c): today the env probe is rejected → falls to
   argv0 dir; after PR-2 the committed stamp makes the env probe win (the documented intent of the env
   var finally working). Changes which build/runtime.a is found if both dirs have one.
2. HEXA_SKIP_SRC=1 installs: today argv0 probe fails → "."; after, $HX_BIN is returned and its
   build/runtime.a found — fixes a live silent clang-fallback.
Proof protocol (PR-2, aiden layout-matrix): for {in-tree, ~/.hx, staged dist/, +2 delta cases} build a
smoke prog old-vs-new binary; (a) assert the resolved root is unchanged in the 3 contract layouts,
(b) byte-compare emitted binaries. The regular byteeq 3-target gate runs in-tree with HEXA_LANG=$PWD
(both markers coexist → identical root → identical bytes); the matrix covers what the gate can't see.

## Status
- PR-1 (this): producers landed — `.hxroot` at root + stage_precompile_package + install.sh writers.
- PR-2: resolver swap — NEXT (byteeq 3-target + layout matrix).
- Deletion (self/main.hexa:3677 delegate + `self/native/hexa_cc.c`): gated on PR-1+PR-2 merged + a
  stamped release being the installed reality + the #4885 census soak GREEN.
