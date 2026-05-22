# sidecar `pool-route` — `.hexa` port requirements (wilson-pool `_route.py` restore)

**Status**: HANDOFF — downstream (sidecar) request; not hexa-lang cycle work yet.
**Provenance**: sidecar investigation 2026-05-23 — `pool-route` lost its
auto-router in the concept-separation reset.
**Downstream consumer**: `sidecar` repo, `hooks/pool-route/bin/_pool_route.hexa`
(currently 0.3.0).
**Reference source**: `git show ca62ff4:plugins/wilson-pool/bin/_route.py` in the
`sidecar` repo — wilson-pool 0.10.2, ~250 lines, the last + most complete version.

---

## Why this note exists

sidecar's `pool-route` hook used to **force** heavy build/exec commands onto
remote pool hosts. The mechanism was `wilson-pool`'s `PreToolUse(Bash)` hook
`_route.py`: it rewrote the Bash command through the hook **`updatedInput`**
field into `ssh <host> 'cd <workdir> && <cmd>'` — transparent auto-dispatch,
not a suggestion.

Timeline (sidecar commits):

- `ca62ff4` (2026-05-20) — wilson-pool 0.10.2, last version WITH `_route.py`.
- `2902661` (2026-05-21) — concept-separation reset; the mixed `wilson-pool`
  plugin (routing hook + guard hook + inject hooks + `/pool` command in one)
  was archived. The auto-router went dormant.
- `5122d79` (2026-05-21) — `pool-route` 0.1.0 written fresh as a **non-blocking
  suggestion** (emits `additionalContext` only, never `updatedInput`).
  `_route.py` was never ported.

The owner wants the auto-router restored, ported to `.hexa` (sidecar
hexa-migration line). This note hands the port spec + the hexa-lang surface
gaps it surfaces to hexa-lang upstream.

---

## What the port must reproduce (`_route.py` behavior spec)

`PreToolUse(Bash)` hook. On each Bash call:

1. **Arm check** — read `pool.json` (host roster + global `workdir`). No roster
   host OR no workdir → emit nothing, command runs locally. Never route when
   pool is unconfigured.
2. **Skip guards** — already-routed marker `__SIDECAR_POOL__`, heredoc (`<<`),
   background (`&` suffix), already-`ssh ` commands → pass through untouched.
3. **Heavy classifier** — alternation match:
   `make · cargo · npm · pnpm · yarn · gradle · mvn · bazel · cmake · ctest ·
   tox · pytest · jest · vitest · webpack · xcodebuild · xcrun · swiftc ·
   go test/build · swift build/test · docker build · nvidia-smi · train`.
   Plus a SUDO set (`apt · dpkg · systemctl · …`) that is always routable.
   No match → local.
4. **Capability filter** — `MACOS_RE` (xcodebuild, codesign, `swift build`,
   `Mach-O`, `.dylib`, …) restricts to `platform: macos` hosts; `LINUX_RE`
   (apt, dpkg, systemctl, `.deb`, …) to `platform: linux`; else any host.
   No eligible host → local.
5. **Round-robin** — a `.rr` counter file picks one eligible host (load spread).
6. **Workdir resolve** — per-host `workdir` > global `workdir` > `auto`
   (mirror cwd relative to `$HOME` → remote `~/<rel>`).
7. **Transport** — `tailscale ssh` if a local tailscale daemon answers
   `tailscale status`, else plain `ssh`.
8. **Sync / preflight** — `autosync` → prepend an `rsync` of the project to the
   routed command; else **preflight**: `ssh <host> test -d <workdir>`,
   distinguishing rc 0 (present → route) / rc 1 (absent → local) /
   rc 255 (connection failure → skip once, do NOT cache).
9. **Emit** — `{"hookSpecificOutput": {"hookEventName":"PreToolUse",
   "updatedInput": {…, "command":"ssh host 'cd wd && cmd'"},
   "additionalContext":"<routed note>"}}`.

---

## hexa-lang surface gaps the port hits

Current hexa surface observed in `_pool_route.hexa` 0.3.0: `exec()` (subprocess,
**stdout only** via `to_string`), `json_parse`, `type_of` / `has_key`, string
index / `substring`, `char_code`, arrays, `try` / `catch`, `exit`, `println`.
That covers steps 1–4 partially and step 9. The gaps:

| # | Need | Used by step | Current workaround | Severity |
|---|------|--------------|--------------------|----------|
| G1 | native `read_file` / `write_file` | 1 (read pool.json), 5 (`.rr`), 8 (`.preflight.json` cache) | `exec("cat …")` / heredoc — the `exec-wrap-native` anti-pattern | covered — pool-route is a 2nd consumer of `issues/proposed/stdlib-native-write-file.md` |
| G2 | `getenv(name)` | locate pool.json under `$CLAUDE_PLUGIN_DATA` | `exec("printenv X")` | blocker for a clean port |
| G3 | `exec()` returning **exit code** (+ stderr), not just stdout | 7 (`tailscale status` rc), 8 (preflight `ssh test -d` rc 0/1/255) | none — current `exec()` gives stdout only | blocker |
| G4 | regex, or `contains` + `matches_any_word` helpers | 3 + 4 (≈25-way alternation; MACOS/LINUX substring tokens like `Mach-O`, `.dylib`) | hand-rolled `_has_word` loops (already in `_pool_route.hexa`) | workaround exists — verbose, optional |

**G3 is the hard blocker.** Preflight's whole correctness rests on telling a
missing workdir (rc 1, cacheable) apart from a transient connection failure
(rc 255, must NOT cache, else the host gets silently benched for the session).
With stdout-only `exec()` the port either drops preflight or guesses — both
wrong, and a wrong router silently mis-runs every heavy command.

---

## Recommended hexa-lang issues to cut

- `issues/proposed/exec-return-exit-code.md` — an `exec()` variant returning
  `{rc, stdout, stderr}`. **(G3 — blocker)**
- `issues/proposed/stdlib-getenv.md` — `getenv(name) -> string`. **(G2)**
- add `pool-route` as a downstream consumer on the existing
  `issues/proposed/stdlib-native-write-file.md`. **(G1)**
- G4 needs no issue — hand-rolled word matching is acceptable; a stdlib regex
  would only be nicer.

Once G2 + G3 land, sidecar can port `_route.py` → `.hexa` cleanly and restore
the forced pool toss. Until then `pool-route` stays the non-blocking suggestion
hook (0.3.0).

---

## References

- `_route.py` source — `git show ca62ff4:plugins/wilson-pool/bin/_route.py` (sidecar repo).
- Loss commit — `2902661` (sidecar) — "refactor: reset marketplace · concept-separated layout".
- Current downstream hook — `sidecar` `hooks/pool-route/bin/_pool_route.hexa` (0.3.0).
- Related existing issue — `issues/proposed/stdlib-native-write-file.md` (G1).
