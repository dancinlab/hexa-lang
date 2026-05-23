# `hexa --help` is stale relative to the absorbed builtins/intrinsics

- **status**: resolved-ssot (2026-05-20) — `cmd_help` now ships an INTRINSIC SURFACE
  section advertising the SPEC §16 absorbed intrinsics with their shell-equivalents
  (`cwd ⇆ pwd`, `list_dir ⇆ ls`, `mkdir_p ⇆ mkdir -p`, `getenv ⇆ $VAR`,
  `path_exists ⇆ test -e`, `path_is_dir ⇆ test -d`, `rm_file ⇆ rm`, `rm_rf ⇆ rm -rf`,
  `host_target ⇆ uname -sm`, `now_ns ⇆ date +%s%N`) plus an SPEC §18 firmware-absorption
  pointer. The stale `HW probes: qmirror akida qrng` row is now `akida` only with a
  pointer to STDLIB CLI for the absorbed qmirror/qrng (RFC 044/045 dispatch).
- **resolved-by**: 3-in-1 inbox cleanup cycle (this commit) — see compiler/PLAN.md.
- **deferred**: a dedicated `hexa intrinsics [list|--help]` subcommand and a generated
  fork-storm lint surfacing on `hexa lint --help` — separate cycle.

**From:** wilson (downstream) — observed 2026-05-12 while writing wilson's governance
operating-principles list (which cites SPEC.md §16 fork-storm prevention / §18 firmware
absorption / §2.2 atlas embed).

**One concept:** the `hexa` CLI's `--help` / subcommand help text doesn't reflect the
intrinsic-surface work. After SPEC §16 (`pwd → cwd()/getcwd()`, `ls → list_dir()`,
`mkdir_p`, `rm_rf`, `rm_file`, `getenv`, `path_exists`, `path_is_dir`, `now_ns`,
`host_target`, … — `compiler/intrinsics/intrinsics.hexa`, absorbed_site_count 638→752) and
SPEC §18 (five firmware repos absorbed into `stdlib/{core,alloc,hal,embedded,mcu}` +
`firmware/boards/*`), a user running `hexa --help` (or `hexa intrinsics --help` / whatever
the surface is) gets no signal that these exist or that shelling out is the wrong move.

**Asks (pick what fits — this is a note, not a spec):**
- `hexa --help` top-level: mention the intrinsic surface + point at where it's enumerated.
- Either a `hexa intrinsics [list|--help]` subcommand, or a generated doc page listing the
  absorbed intrinsics with their shell-equivalents (`cwd` ⇆ `pwd`, `list_dir` ⇆ `ls`, …),
  so a coding agent can discover "use `mkdir_p`, not `exec("mkdir -p")`".
- If there's a fork-storm lint (HX9xxx warning on `exec("pwd")` etc.) planned/landed, surface
  it in `hexa lint --help` too.

**Why it matters here:** wilson's governance principle #2 (`roi-first`) tells the agent to
"call hexa's absorbed intrinsics instead of forking a shell" — but the agent can only do that
reliably if `hexa --help` (the first place it looks) actually advertises the surface.

No wilson-side change needed; filing per the AGENTS.md hexa-lang handoff protocol.
