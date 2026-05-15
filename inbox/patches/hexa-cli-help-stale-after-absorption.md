# `hexa --help` is stale relative to the absorbed builtins/intrinsics

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
