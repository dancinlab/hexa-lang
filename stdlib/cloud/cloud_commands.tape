# cloud_commands.tape — cloud subcommand registry (SSOT for `hexa cloud` help)
#
# Format: one block per cloud verb —
#   @cmd <name> := "<arg-shape>" :: <group>    # <summary>
#
#   name      the dispatched subcommand token (matches the cloud_cli.hexa
#             `main()` dispatch guard `if t == "rent" || ...` — the SSOT)
#   arg-shape the usage signature printed after `cloud <name>`
#   group     lifecycle | manage | exec | io | plan | meta (render section)
#   summary   one-line description (the ` # ` trailing comment)
#
# `#` lines and the trailing ` # <summary>` are roster-reader comments. Read
# by stdlib/cloud/cloud_cli.hexa::_cloud_help (renders the usage block from
# this file) and bound by the drift guard
# stdlib/cloud/cloud_help_drift_test.hexa (the tape verb set MUST equal the
# dispatch guard's verb set — FAIL on any drift).
#
# Aliases the dispatcher accepts but the help does NOT list as separate rows
# (up→rent · status→list · destroy→down · --help/-h→help · --version/-v→version)
# are noted inline; the drift guard treats them as aliases, not roster verbs.
#
# This is the cloud pilot of the CLI command<->help registry pattern; the
# whole-CLI self/main.hexa migration (a repo-root commands.tape) is a
# documented follow-up, NOT this change.

# ── lifecycle ────────────────────────────────────────────────────────
@cmd rent := "<provider> [--gpu T] [--image IMG] [--disk GiB] [--owner TAG] [--project NAME] [--query Q] [--max-wait-sec N] [--no-register]" :: lifecycle  # provision a GPU pod (vast|runpod), wait ssh-ready, print host:port + id (alias: up)
@cmd list := "[--provider P]" :: lifecycle  # list live pods (vast + runpod, or one via --provider; alias: status)
@cmd pods := "" :: lifecycle  # full work table from cwd's ./pods.json (per-project active pod/job manifest)
@cmd resolve := "<id> [--provider P]" :: lifecycle  # alias of ssh-port — pod-id -> ssh host:port for run/copy-to
@cmd ssh-port := "<id> [--provider P]" :: lifecycle  # print live ssh host:port of a pod (vast|runpod)
@cmd down := "<id> [--provider P] [--force]" :: lifecycle  # (legacy alias of rm) destroy a pod + forget it; refuses a cross-project kill unless --force
@cmd rm := "<id> [--provider P] [--force]" :: lifecycle  # CANONICAL teardown — confirm + destroy + forget (unifies down/destroy/forget); idempotent
@cmd reboot := "<id> [--provider P]" :: lifecycle  # restart a pod container (preserve disk) to recover a DARK pod; vast only

# ── manage ───────────────────────────────────────────────────────────
@cmd adopt := "<pod_id> [--purpose TEXT] [--project NAME]" :: manage  # track an untracked (ORPHAN) pod (stamps project/purpose for the down-guard)
@cmd attribute := "<pod_id> --project NAME [--purpose TEXT]" :: manage  # re-stamp project/purpose on an ALREADY-tracked pod
@cmd forget := "<pod_id|ssh-form|ip|alias>" :: manage  # (legacy — use rm) mark a tracked (GHOST) pod status=closed
@cmd reap := "[--provider P] [--apply]" :: manage  # orphans alive on provider but absent from registry; bare=dry-run, --apply=destroy
@cmd orphans := "[--hours N]" :: manage  # list tracked pods, flag stale (>N h, default 6)
@cmd reconcile := "" :: manage  # cross-ref registry vs provider: ORPHAN/GHOST/OK
@cmd watchdog := "[--threshold-min N] [--util-cap-pct N] [--kill]" :: manage  # idle-pod autokill sweep (DRY-RUN default; --kill enforces)
@cmd preflight := "--params N [--gpu KEY] [opts...]  |  --kind dft-phonon --atoms N --nq M [opts...]" :: manage  # closed-form GPU mem-budget / DFPT walltime check (no pod/ssh)

# ── exec ─────────────────────────────────────────────────────────────
@cmd run := "<host> [conn] [--max-wall S] [--env K=V] [--source P] -- <argv...>" :: exec  # run argv, wait, exit with its code (structured argv — POSIX-quoted)
@cmd exec := "<host> [conn] -- <shell-cmd>" :: exec  # run shell command via ssh (DEFAULT SHELL PARSES IT)
@cmd nohup := "<host> <logfile> [conn] [--env K=V] [--source P] [--early-life-check N] [--register [<jid>]] -- <argv...>" :: exec  # background argv, print remote pid + Monitor handle
@cmd fire := "<host> [--log <path>] [conn] [--env K=V] [--source P] [--early-life-check N] [--register [<jid>]] -- <argv...>" :: exec  # atomic nohup + auto-log + Monitor handle (logfile optional)
@cmd poll := "<host> <pid> [conn]" :: exec  # exit 0 if remote pid alive, else 1 (DEAD flips a matching PENDING ./pods.json row -> FAIL)
@cmd tail := "<host> <logfile> [conn] [--grep RE] [--until RE]" :: exec  # live-stream a remote log (Monitor bridge; 3-tier failure-first verdict)
@cmd watch := "<host> <pid> [conn] [--interval N] [--max-wait S] [--then-down <id> [--provider P]]" :: exec  # loop poll until pid dies / max-wait; optional teardown

# ── io ───────────────────────────────────────────────────────────────
@cmd copy-to := "<host> <local> <remote> [conn] [-r] [--verify-sha]" :: io  # upload file/dir (scp; -r=tree; sha256 check)
@cmd copy-from := "<host> <remote> <local> [conn] [--resume] [--verify-sha]" :: io  # download (scp; --resume=rsync; sha256 check)

# ── plan ─────────────────────────────────────────────────────────────
@cmd dft-run := "<deck-dir> [--go] [--bin-pack] [--query Q] [--walltime-h N] [--identity P] [--image I] [--disk G] [--owner T]" :: plan  # guarded DFT el-ph (QE) dispatch; PREVIEW ($0) unless --go
@cmd parallel-audit := "--physcores N --live-jobs N --ranks-per-job N --queued-decks N" :: plan  # d_parallel_fire violation guard (VIOLATION -> exit1 + split suggestion)
@cmd dispatch := "[tree|active|add|verdict|rm]" :: plan  # manage ./pods.json (update-form); bare = full table
@cmd providers := "" :: plan  # list known GPU providers (vast|runpod) + catalog

# ── meta ─────────────────────────────────────────────────────────────
@cmd help := "" :: meta  # show this help (aliases: --help, -h; bare `cloud` also prints it)
@cmd version := "" :: meta  # print the cloud CLI version (alias: --version, -v)
