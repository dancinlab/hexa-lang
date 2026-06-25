#!/usr/bin/env bash
# tool/selfhost_shim_integrity.sh — SELFHOST-CI M5 hx-selfhost-cli shim integrity.
#
# PURPOSE
#   A STANDING, per-PR gate that asserts the CONTRACT of the self-host CLI shim
#   `tool/hx-selfhost-cli` (#2588) — the SAFE delegating launcher that tier2
#   (`tool/promote_selfhost.sh --default`) flips the default `hexa.real` to. The
#   shim's contract is the thing that keeps a flipped-default host's FULL CLI
#   (and the ~60k+ hook/skill `hexa <subcmd>` callers) working:
#
#     ① compile routing      — an invocation carrying `--emit=<x>` routes to the
#                              self-hosted gen3 (the bare-compiler surface).
#     ② subcommand delegation — every NAMED subcommand (verify/run/atlas/loop/
#                              install/fmt/build/--version/--help/…) and anything
#                              WITHOUT `--emit` delegates to the shipped dispatch
#                              binary, argv passed through VERBATIM.
#     ③ symlink-loop guard   — in the flipped-default layout (hexad symlinks
#                              to the shim) the shim must NOT recurse into itself;
#                              the loop guard fires (FATAL 127), honoring the
#                              hexad.pre-selfhost.<ts> backup-name convention.
#     ④ syntax / lint        — `bash -n` clean + (if shellcheck present) lint
#                              clean, so the shim can't ship malformed.
#
#   This is distinct from the sister gates:
#     • selfhost_byteeq_gate.sh    — whole-compiler byte-eq fixpoint
#     • selfhost_codegen_guard.sh  — native arm64 codegen-class correctness
#     • selfhost_crossemit_smoke.sh— cross-target object-format reloc fence
#   This gate is the CLI-WRAPPER integrity fence around the graduated gen.
#
# HERMETIC DESIGN (why this gate runs REAL on ANY host, incl. hosted CI)
#   The shim resolves its install layout from BASH_SOURCE[0] ($HX_HOME/bin/<self>)
#   and routes a `--emit` call to "$SLOT/gen3", everything else to the newest
#   "$BIN_DIR/hexad.pre-selfhost.*" backup. We exploit exactly that: we build
#   a FAKE $HX_HOME under a tmp dir, copy the real shim to bin/hx-selfhost-cli,
#   and plant INSTRUMENTED STUBS:
#     • $SLOT/gen3                     → echoes  GEN3-REACHED <argv...>
#     • bin/hexad.pre-selfhost.<ts>    → echoes  SHIPPED-REACHED <argv...>
#   Then we invoke the shim with various argv and assert WHICH sentinel printed +
#   that argv passed through verbatim. No graduated compiler / native gen2_fix is
#   needed — the stubs ARE the targets — so the gate is hermetic and runs REAL on
#   macOS and Linux alike. That STRENGTHENS over the sister gates (which depend on
#   host toolchain for their run legs); this one has NO host-bound run leg.
#
# NEUTRAL POLICY (exit-2-neutral canary — same shape as #2600/#2605/#2607)
#   The only thing that could make a leg unrunnable here is a host without bash —
#   impossible (we ARE bash). So normally there is NO neutral leg: every
#   assertion runs real on every host. We KEEP the exit-2 path solely for a
#   genuine SETUP/INFRA failure (the shim file is missing, or mktemp fails) so a
#   broken runner remaps to neutral instead of false-failing a PR.
#
# CONFIG (env)
#   SHIM        path to the shim under test (default: <repo>/tool/hx-selfhost-cli)
#   SI_OUT      sandbox root             (default: a fresh mktemp -d)
#
# EXIT
#   0  every assertion PASS (compile→gen3, subcmd→shipped verbatim, loop-guard
#      fires + backup-name honored, bash -n clean, shellcheck clean-or-absent).
#   1  REGRESSION — the shim mis-routed (compile reached shipped, or a subcommand
#      reached gen3), dropped/mangled argv, failed to fire the loop guard, or
#      `bash -n`/shellcheck found a defect.
#   2  SETUP / INFRA — the shim file is absent or the sandbox could not be built.
#      CI remaps 2→neutral.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"

SHIM="${SHIM:-$REPO/tool/hx-selfhost-cli}"
HEAD_SHA="$(git -C "$REPO" rev-parse --short HEAD 2>/dev/null || echo unknown)"
HOST_OS="$(uname -s 2>/dev/null || echo unknown)"
HOST_ARCH="$(uname -m 2>/dev/null || echo unknown)"

echo "── selfhost shim integrity (M5) ──────────────────────────────────"
echo "  shim      : $SHIM"
echo "  host      : $HOST_OS $HOST_ARCH   HEAD=$HEAD_SHA"
echo "  bash      : $(bash --version 2>/dev/null | head -1)"
echo "──────────────────────────────────────────────────────────────────"

# ── SETUP/INFRA canary ──────────────────────────────────────────────────────
if [ ! -f "$SHIM" ]; then
  echo "shim-integrity: SETUP/INFRA — shim not found at $SHIM" >&2
  exit 2
fi

SI_OUT="${SI_OUT:-$(mktemp -d 2>/dev/null || echo "${TMPDIR:-/tmp}/hx-shim-integrity.$$")}"
mkdir -p "$SI_OUT" || { echo "shim-integrity: SETUP/INFRA — cannot mktemp sandbox" >&2; exit 2; }

# ── build the hermetic fake $HX_HOME layout the shim resolves itself from ────
HX_HOME="$SI_OUT/hx"
BIN_DIR="$HX_HOME/bin"
SLOT="$HX_HOME/self/native/selfhost"
mkdir -p "$BIN_DIR" "$SLOT" || { echo "shim-integrity: SETUP/INFRA — cannot build sandbox tree" >&2; exit 2; }

SHIM_INSTALLED="$BIN_DIR/hx-selfhost-cli"
cp "$SHIM" "$SHIM_INSTALLED"; chmod +x "$SHIM_INSTALLED"

# Instrumented stub gen3 — prints a sentinel + verbatim argv it received.
# NOTE the shim prepends `_drv.hexa` as argv1 (the gen3 driver placeholder),
# so the stub echoes argv from $2 onward to compare against the caller's argv.
cat > "$SLOT/gen3" <<'STUB'
#!/usr/bin/env bash
printf 'GEN3-REACHED'
shift   # drop the _drv.hexa driver placeholder the shim prepends
for a in "$@"; do printf ' <%s>' "$a"; done
printf '\n'
exit 0
STUB
chmod +x "$SLOT/gen3"

# Instrumented stub SHIPPED dispatch — backed-up name convention
# hexad.pre-selfhost.<ts>; the shim picks the NEWEST by mtime.
SHIPPED_BK="$BIN_DIR/hexad.pre-selfhost.20240101-000000"
cat > "$SHIPPED_BK" <<'STUB'
#!/usr/bin/env bash
printf 'SHIPPED-REACHED'
for a in "$@"; do printf ' <%s>' "$a"; done
printf '\n'
exit 0
STUB
chmod +x "$SHIPPED_BK"

# Helper: run the installed shim with given argv, capture stdout+rc.
run_shim() { OUT="$("$SHIM_INSTALLED" "$@" 2>/dev/null)"; RC=$?; }

fail=0
A_COMPILE="PASS"; A_SUBCMD="PASS"; A_LOOP="PASS"; A_SYNTAX="PASS"
SUBCMD_DETAIL=""

# ════════════════════════════════════════════════════════════════════════
# ① COMPILE ROUTING — `--emit=<x>` must reach gen3, NOT shipped.
# ════════════════════════════════════════════════════════════════════════
echo "① COMPILE ROUTING (--emit=* → gen3):"
for argv in \
  "foo.hexa --emit=obj" \
  "foo.hexa --emit=asm" \
  "--emit=obj bar.hexa" \
  "src.hexa --emit=obj -o out.o"
do
  # shellcheck disable=SC2086
  run_shim $argv
  if [[ "$OUT" == GEN3-REACHED* ]]; then
    echo "  PASS  [$argv] → $OUT"
  else
    echo "  FAIL  [$argv] expected GEN3-REACHED, got: [$OUT] (rc=$RC)"
    A_COMPILE="FAIL"; fail=1
  fi
  # argv pass-through: every original token must appear verbatim in the sentinel.
  for tok in $argv; do
    case "$OUT" in *"<$tok>"*) ;; *)
      echo "  FAIL  [$argv] argv token '$tok' not passed through verbatim → [$OUT]"
      A_COMPILE="FAIL"; fail=1 ;;
    esac
  done
done
echo "  ↳ compile-routing : $A_COMPILE"
echo "──────────────────────────────────────────────────────────────────"

# ════════════════════════════════════════════════════════════════════════
# ② SUBCOMMAND DELEGATION — every named subcmd (no --emit) → shipped, verbatim.
# ════════════════════════════════════════════════════════════════════════
echo "② SUBCOMMAND DELEGATION (named subcmd → shipped, argv verbatim):"
# Representative set spanning what the shim+shipped support: the compile-ish
# verbs that must NOT route to gen3 (build/run) PLUS the pure dispatch verbs
# (verify/atlas/loop/install/fmt/test/loop --dfs), version/help, and a bare call.
SUBCMDS=(
  "verify foo.hexa"
  "run prog.hexa"
  "build proj"
  "atlas lookup P 1"
  "loop --dfs --llm-cmd x"
  "install hexa-lang"
  "fmt src.hexa"
  "test"
  "--version"
  "--help"
  ""              # bare invocation (no args, no --emit)
  "kick seed"
)
for argv in "${SUBCMDS[@]}"; do
  # shellcheck disable=SC2086
  run_shim $argv
  label="${argv:-<bare>}"
  if [[ "$OUT" == SHIPPED-REACHED* ]]; then
    echo "  PASS  [$label] → $OUT"
    SUBCMD_DETAIL="$SUBCMD_DETAIL ${argv%% *}"
  else
    echo "  FAIL  [$label] expected SHIPPED-REACHED, got: [$OUT] (rc=$RC)"
    A_SUBCMD="FAIL"; fail=1
  fi
  # argv verbatim pass-through.
  for tok in $argv; do
    case "$OUT" in *"<$tok>"*) ;; *)
      echo "  FAIL  [$label] argv token '$tok' not passed through verbatim → [$OUT]"
      A_SUBCMD="FAIL"; fail=1 ;;
    esac
  done
done
echo "  ↳ subcmd-delegation : $A_SUBCMD   (delegated:$SUBCMD_DETAIL)"
echo "──────────────────────────────────────────────────────────────────"

# ════════════════════════════════════════════════════════════════════════
# ③ SYMLINK-LOOP GUARD — flipped-default layout must NOT recurse into itself.
# ════════════════════════════════════════════════════════════════════════
echo "③ SYMLINK-LOOP GUARD (flipped default → no self-recursion):"
# Build the flipped layout in an ISOLATED sandbox so the working delegate above
# is untouched: hexad is a SYMLINK to the shim (as tier2 does), and there is
# NO hexad.pre-selfhost.* backup → pick_delegate's backup branch finds
# nothing AND the hexad fallback is a symlink (to us) → the guard must fire
# (FATAL, rc 127) rather than exec hexad and recurse forever.
LOOP_HOME="$SI_OUT/loop"
LOOP_BIN="$LOOP_HOME/bin"
LOOP_SLOT="$LOOP_HOME/self/native/selfhost"
mkdir -p "$LOOP_BIN" "$LOOP_SLOT"
cp "$SHIM" "$LOOP_BIN/hx-selfhost-cli"; chmod +x "$LOOP_BIN/hx-selfhost-cli"
# tier2 flip: hexad -> the shim (the symlink-loop trap).
ln -sf "$LOOP_BIN/hx-selfhost-cli" "$LOOP_BIN/hexad"

# Invoke THROUGH hexad (the flipped default) with a delegating (non --emit)
# call — this is what every hook does after a flip. With no real backup and
# hexad being a symlink to us, the shim MUST hard-fail loudly, not recurse.
LOOP_OUT="$("$LOOP_BIN/hexad" verify foo.hexa 2>&1)"; LOOP_RC=$?
echo "  invoke (no backup, hexad→shim): rc=$LOOP_RC"
echo "$LOOP_OUT" | sed 's/^/    /'
if [ "$LOOP_RC" = "127" ] && [[ "$LOOP_OUT" == *"no shipped dispatch binary to delegate to"* ]]; then
  echo "  PASS  loop guard fired (rc 127, no self-recursion)"
else
  echo "  FAIL  loop guard did NOT fire as expected (want rc 127 + FATAL message)"
  A_LOOP="FAIL"; fail=1
fi

# Backup-name convention: with a properly-named backup present, the SAME flipped
# layout must now DELEGATE to that backup (proving the guard only fires on a true
# loop, and the hexad.pre-selfhost.<ts> name is what the shim honors).
cat > "$LOOP_BIN/hexad.pre-selfhost.20240101-000000" <<'STUB'
#!/usr/bin/env bash
printf 'SHIPPED-REACHED'
for a in "$@"; do printf ' <%s>' "$a"; done
printf '\n'
exit 0
STUB
chmod +x "$LOOP_BIN/hexad.pre-selfhost.20240101-000000"
LOOP_OUT2="$("$LOOP_BIN/hexad" verify foo.hexa 2>/dev/null)"; LOOP_RC2=$?
echo "  invoke (WITH .pre-selfhost backup): rc=$LOOP_RC2  out=[$LOOP_OUT2]"
if [[ "$LOOP_OUT2" == SHIPPED-REACHED* ]] && [[ "$LOOP_OUT2" == *"<verify>"* ]]; then
  echo "  PASS  backup-name convention honored (delegates to hexad.pre-selfhost.<ts>)"
else
  echo "  FAIL  backup-name convention NOT honored → [$LOOP_OUT2]"
  A_LOOP="FAIL"; fail=1
fi
echo "  ↳ loop-guard : $A_LOOP"
echo "──────────────────────────────────────────────────────────────────"

# ════════════════════════════════════════════════════════════════════════
# ④ SYNTAX / LINT — bash -n clean + shellcheck clean (if present).
# ════════════════════════════════════════════════════════════════════════
echo "④ SYNTAX / LINT (bash -n + shellcheck):"
if bash -n "$SHIM" 2>"$SI_OUT/bashn.log"; then
  echo "  PASS  bash -n clean"
else
  echo "  FAIL  bash -n reported a syntax error:"; sed 's/^/    /' "$SI_OUT/bashn.log"
  A_SYNTAX="FAIL"; fail=1
fi
if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck -S error "$SHIM" >"$SI_OUT/shellcheck.log" 2>&1; then
    echo "  PASS  shellcheck clean (no error-severity findings)"
  else
    echo "  FAIL  shellcheck found error-severity defects:"; sed 's/^/    /' "$SI_OUT/shellcheck.log"
    A_SYNTAX="FAIL"; fail=1
  fi
else
  echo "  NOTE  shellcheck absent — bash -n is the syntax floor here (assertion still PASS)"
fi
echo "  ↳ syntax/lint : $A_SYNTAX"
echo "──────────────────────────────────────────────────────────────────"

# ── SUMMARY ────────────────────────────────────────────────────────────────
echo "SUMMARY (HEAD=$HEAD_SHA, host=$HOST_OS $HOST_ARCH):"
echo "  compile-routing    : $A_COMPILE"
echo "  subcmd-delegation  : $A_SUBCMD   (delegated:$SUBCMD_DETAIL)"
echo "  symlink-loop-guard : $A_LOOP"
echo "  syntax/lint        : $A_SYNTAX"
echo "──────────────────────────────────────────────────────────────────"
if [ "$fail" -ne 0 ]; then
  echo "shim-integrity: FAIL — the hx-selfhost-cli shim violated its routing/guard contract." >&2
  exit 1
fi
echo "shim-integrity: PASS — compile→gen3, every subcmd→shipped verbatim,"
echo "  loop-guard fires + backup-name honored, shim syntax clean."
exit 0
