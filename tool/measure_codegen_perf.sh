#!/usr/bin/env bash
# tool/measure_codegen_perf.sh — CANONICAL codegen-perf measurement harness.
#
# Single reusable surface for measuring a native-codegen unbox lever (any
# HEXA_UNBOX_* / HEXA_*_NATIVE runtime env flag that toggles emitted asm). It
# supersedes the per-round state/unbox-native-*/measure_*.sh scratch scripts
# (gitignored, not canonical): the verified kernel/emit/link/median logic is
# lifted from those (measure_r2b.sh, measure_r6.sh) and parameterised here.
#
# ── Two measured root-causes this harness fixes (SSOT: memory
#    project_hexa_runtime_gap_allclosure §infra) ──────────────────────────────
#
#  ⓐ DOUBLE-APRIME BUILD OOM. The old measure scripts built BOTH the patched
#     and the origin/main baseline aprime_cc. On a 30G pool host the 2nd build
#     gets OOM-killed → measurement dies. But the unbox flags are RUNTIME env:
#     ONE patched aprime emits both OFF (flag unset) and ON (flag=1). So Gate2
#     (lever count), Gate3 (ratio) and Gate4 (parity) need ONLY the patched
#     binary. The single byteeq gate that needs a baseline — Gate1 (patched
#     flag-OFF .o == origin/main .o) — is DELEGATED TO CI (3-target). Here it
#     is SKIPPED. → single aprime build, OOM-safe on 30G.
#
#  ⓑ CPU-ONLY runtime.a ABSENT. Pool hosts' ~/.hx/bin/build/runtime.a is a
#     CUDA-tagged GPU build artifact (carries runtime_cuda_dlink.o). A plain
#     `gcc -O2 kernel.o runtime.a -lm` link against it FAILS — undefined
#     reference to __cudaRegisterFatBinary / __cudaUnregisterFatBinary (needs
#     -lcudart/-lcuda). So a CPU-only runtime.a is required for the clean link
#     this harness uses. It is built ONCE via the canonical
#     tool/stage_resolve_runtime_a (HEXA_CUDA unset), `ar t`-verified to carry
#     NO cuda symbols, and cached to $HOME/runtime.a.cpubak for reuse.
#
#  ⓒ (the PRIMARY measured-NA cause — see emit_one) aprime_cc needs a LEADING
#     throwaway positional (`_drv.hexa`) before flags or it emits nothing and
#     prints "missing SOURCE.hexa". The old measure_r2b.sh omitted it, so its
#     empty-emit produced no .o → ratio NA / parity FAIL, which was then
#     MISATTRIBUTED to the CUDA runtime.a. Both ⓑ and ⓒ are real; ⓒ was masking ⓑ.
#
# ── Usage ───────────────────────────────────────────────────────────────────
#   tool/measure_codegen_perf.sh --branch <git-branch> \
#                                --flag <HEXA_UNBOX_X> \
#                                --kernel <path|inline-source|->  \
#                                [--lever-grep <extra-asm-regex>] \
#                                [--target <triple>] [--smoke]
#
#   --branch     git branch holding the patched codegen (built into aprime_cc).
#   --flag       the runtime env flag toggled 0/1 (e.g. HEXA_UNBOX_ARRAY_NATIVE).
#   --kernel     a .hexa file path, OR inline hexa source (must contain "fn "),
#                OR "-" to read source from stdin.
#   --lever-grep extra asm regex for the lever report (e.g. 'imul|shl|lea' for
#                the r2d imul16->shl4 strength-reduction micro-lever).
#   --target     codegen target triple (default x86_64-linux-gnu).
#   --smoke      also run the ship smoke (hexa --version + hello + exit42).
#
#   Env overrides: CANON (repo, default $HOME/hexa-lang) · WORK (scratch) ·
#                  RESULT (out file) · CC (runtime.a compiler, default clang) ·
#                  CPUBAK (cached CPU runtime.a, default $HOME/runtime.a.cpubak).
#
# ── Gates (all patched-only; OOM-safe single build) ─────────────────────────
#   Gate1  SKIP  — OFF-byteeq → delegated to CI 3-target (needs baseline build).
#   Gate2  lever — boxed-op `call hexa_*` counts + extra regex, OFF vs ON asm.
#   Gate3  ratio — gcc -O2 link + ISOLATED ALTERNATING median-7 wall `taskset -c 3`,
#                  off,on per round (root-cause ⓓ: block-sequential timing lets
#                  transient contention skew the ratio — fused k3 read 1.000 in-harness
#                  vs 0.103 isolated; alternation shares transient state equally).
#   Gate4  parity— program output OFF == ON.
#   Gate5  smoke — opt-in (--smoke).
#
# Foreground-blocking (caller sees stdout live); RESULT file written
# incrementally so a dropped SSH can re-harvest. setsid is reserved for the
# build sub-process only (survives a transient hangup). Single-SSH discipline:
# isolated $HOME scratch, NOT /tmp.
set -u

# ── arg parse ───────────────────────────────────────────────────────────────
BR=""; FLAG=""; KERNEL_ARG=""; LEVER_GREP=""; TGT="x86_64-linux-gnu"; DO_SMOKE=0
while [ $# -gt 0 ]; do
    case "$1" in
        --branch)     BR="$2"; shift 2 ;;
        --flag)       FLAG="$2"; shift 2 ;;
        --kernel)     KERNEL_ARG="$2"; shift 2 ;;
        --lever-grep) LEVER_GREP="$2"; shift 2 ;;
        --target)     TGT="$2"; shift 2 ;;
        --smoke)      DO_SMOKE=1; shift ;;
        -h|--help)    sed -n '2,60p' "$0"; exit 0 ;;
        *) echo "measure_codegen_perf: unknown arg '$1'" >&2; exit 2 ;;
    esac
done
[ -n "$BR" ]   || { echo "measure_codegen_perf: --branch required" >&2; exit 2; }
[ -n "$FLAG" ] || { echo "measure_codegen_perf: --flag required"   >&2; exit 2; }
[ -n "$KERNEL_ARG" ] || { echo "measure_codegen_perf: --kernel required" >&2; exit 2; }

CANON="${CANON:-$HOME/hexa-lang}"
SLUG="$(echo "$BR" | tr '/ ' '__')"
WORK="${WORK:-$HOME/codegen_perf_${SLUG}}"
RESULT="${RESULT:-$HOME/codegen_perf_${SLUG}_RESULT.txt}"
CC="${CC:-clang}"
CPUBAK="${CPUBAK:-$HOME/runtime.a.cpubak}"
say() { echo "$@" | tee -a "$RESULT"; }

: > "$RESULT"
say "=== codegen-perf measure — branch=$BR flag=$FLAG — $(date -u +%FT%TZ) — $(hostname) ==="
say "    target=$TGT  CANON=$CANON  WORK=$WORK"

# ── no-starve: wait for load<6 (pool courtesy) ──────────────────────────────
say "--- waiting for load<6 (no-starve) ---"
for w in $(seq 1 120); do
    L=$(awk '{print $1}' /proc/loadavg 2>/dev/null); Li=${L%.*}
    if [ "${Li:-99}" -lt 6 ]; then say "  load=$L OK after ${w} probe(s)"; break; fi
    [ "$w" = 120 ] && say "  load stayed high (last=$L) — proceeding after 60min cap"
    sleep 30
done

rm -rf "$WORK"; mkdir -p "$WORK"
cd "$CANON" || { say "FATAL no canon $CANON"; exit 3; }

build_aprime_at() { local out="$1" src="$2"
    # setsid: the build survives a transient SSH hangup (root-cause: agent
    # detach drops; the build itself must not die mid-link).
    ( cd "$src"; setsid bash tool/build_aprime.sh -o "$out" -r "$src" ) >"$WORK/$(basename "$out").log" 2>&1; return $?; }

prep_seeds() { local src="$1"
    for f in self/runtime.c self/native/hexat self/native/hexa_cc.c; do
        [ -e "$CANON/$f" ] && [ ! -e "$src/$f" ] && { mkdir -p "$src/$(dirname "$f")"; cp -a "$CANON/$f" "$src/$f" 2>/dev/null; }
    done
    [ -d "$CANON/self/native" ] && cp -an "$CANON/self/native/." "$src/self/native/" 2>/dev/null || true
    [ -d "$CANON/build" ] && mkdir -p "$src/build" && cp -an "$CANON/build/hexat" "$src/build/" 2>/dev/null || true; }

# ── single patched worktree (NO baseline worktree → root-cause ⓐ OOM-safe) ──
git -C "$CANON" worktree prune 2>>"$WORK/git.log" || true
git -C "$CANON" fetch -f origin "$BR:refs/remotes/origin/$BR" 2>>"$WORK/git.log" || say "  (fetch BR warn — using local $BR)"
git -C "$CANON" worktree add -f --detach "$WORK/src" "origin/$BR" 2>>"$WORK/git.log" \
    || git -C "$CANON" worktree add -f --detach "$WORK/src" "$BR" 2>>"$WORK/git.log" \
    || git clone -b "$BR" "$CANON" "$WORK/src" 2>>"$WORK/git.log" \
    || { say "FATAL cannot materialise branch $BR"; exit 3; }
SRC="$WORK/src"
say "  SRC=$SRC  sha=$(git -C "$SRC" rev-parse --short HEAD 2>/dev/null)"
prep_seeds "$SRC"

say "--- building patched aprime_cc (single build — OOM-safe) ---"
build_aprime_at "$WORK/aprime_cc" "$SRC" && say "  patched build EXIT=0" \
    || { say "  patched build EXIT=$?"; tail -30 "$WORK/aprime_cc.log" | sed 's/^/    /' | tee -a "$RESULT"; }
AP="$WORK/aprime_cc"
[ -x "$AP" ] || { say "FATAL: patched aprime_cc not built (see log above)"; exit 4; }

# ── root-cause ⓑ: ensure a CPU-only runtime.a (cpubak cache) ────────────────
is_cpu_rt() { # $1=path → 0 if exists and has NO cuda symbols
    [ -f "$1" ] || return 1
    ar t "$1" 2>/dev/null | grep -qi cuda && return 1 || return 0; }

say "--- resolving CPU-only runtime.a (root-cause ⓑ) ---"
RT=""
if is_cpu_rt "$CPUBAK"; then
    RT="$CPUBAK"; say "  reusing cached CPU runtime.a: $CPUBAK ($(stat -c%s "$CPUBAK" 2>/dev/null) bytes)"
else
    say "  no clean cpubak — building CPU-only runtime.a via stage_resolve_runtime_a (HEXA_CUDA unset)"
    ( cd "$SRC"
      env -u HEXA_CUDA \
          CC="$CC" LIBS="${LIBS:--lm}" \
          CFLAGS_COMMON="${CFLAGS_COMMON:--O2 -std=gnu11 -D_GNU_SOURCE -Wno-trigraphs}" \
          bash tool/stage_resolve_runtime_a ) >"$WORK/rt_resolve.log" 2>&1 \
        && say "  stage_resolve_runtime_a EXIT=0" \
        || { say "  stage_resolve_runtime_a EXIT=$?"; tail -25 "$WORK/rt_resolve.log" | sed 's/^/    /' | tee -a "$RESULT"; }
    if is_cpu_rt "$SRC/build/runtime.a"; then
        cp -f "$SRC/build/runtime.a" "$CPUBAK"
        RT="$CPUBAK"
        say "  built CPU runtime.a → cached $CPUBAK ($(stat -c%s "$CPUBAK" 2>/dev/null) bytes)"
        say "  ar-t cuda-symbol check: $(ar t "$CPUBAK" 2>/dev/null | grep -ci cuda) cuda member(s) [want 0]"
    elif [ -f "$SRC/build/runtime.a" ]; then
        say "  ⚠ built runtime.a still CUDA-tagged ($(ar t "$SRC/build/runtime.a"|grep -ci cuda) cuda members) — Gate3 may be NA"
        RT="$SRC/build/runtime.a"
    fi
fi
# last resort: any in-tree/installed runtime.a (Gate3 may NA if CUDA-tagged)
if [ -z "$RT" ]; then
    for cand in "$SRC/build/runtime.a" "$CANON/build/runtime.a" "$HOME/.hx/bin/build/runtime.a"; do
        [ -f "$cand" ] || continue
        is_cpu_rt "$cand" && { RT="$cand"; break; } || { [ -z "$RT" ] && RT="$cand"; }
    done
    say "  fallback runtime.a = ${RT:-NONE}"
fi
say "  runtime.a = ${RT:-NONE}"

# ── materialise kernel ──────────────────────────────────────────────────────
KERN="$WORK/kernel.hexa"
if [ "$KERNEL_ARG" = "-" ]; then
    cat > "$KERN"
elif [ -f "$KERNEL_ARG" ]; then
    cp "$KERNEL_ARG" "$KERN"
elif printf '%s' "$KERNEL_ARG" | grep -q 'fn '; then
    printf '%s\n' "$KERNEL_ARG" > "$KERN"
else
    say "FATAL: --kernel '$KERNEL_ARG' is not a file, not inline hexa (no 'fn '), not '-'"; exit 2
fi
say "--- kernel ($(wc -l < "$KERN") lines) ---"; sed 's/^/    | /' "$KERN" | tee -a "$RESULT"

# ── emit OFF (flag unset) vs ON (flag=1): asm + obj from the ONE aprime ──────
# NOTE the leading `_drv.hexa` positional: aprime_cc (the compiled
# compiler/main.hexa) consumes argv[1] as a throwaway driver/self token
# (mirrors how the `hexa` wrapper invokes `hexa-compiler <self> … SOURCE`) and
# takes the LAST positional as SOURCE. WITHOUT it the binary prints
# "hexa-compiler: missing SOURCE.hexa" and emits NOTHING (rc still 0) — the
# latent bug in the old measure_r2b.sh whose empty-emit got MISATTRIBUTED to a
# CUDA-tagged runtime.a (the real "NA" cause, not the runtime.a). `_drv.hexa`
# need not exist on disk.
emit_one() { # $1=flag(0/1) $2=outbase
    local f="$1" out="$2"
    ( cd "$SRC"
      # OFF = explicit FLAG=0 (NOT unset): after a default-ON polarity flip (e.g.
      # HEXA_PACK_ARRAY / HEXA_UNBOX_* now `env != "0"`, #4163/#4168), UNSET means
      # ON, so `unset` would emit ON-vs-ON → false ratio=NA / "lever did not fire"
      # (caught on aiden during #4163 accel re-measure). FLAG=0 is OFF for BOTH
      # polarities (default-OFF flag: 0==unset; default-ON flag: 0=the opt-OUT).
      if [ "$f" = 1 ]; then export "$FLAG=1"; else export "$FLAG=0"; fi
      "$AP" _drv.hexa --emit=asm --target="$TGT" -o "$out.s" "$KERN" >"$out.s.log" 2>&1 || echo "emit asm rc=$? f=$f"
      "$AP" _drv.hexa --emit=obj --target="$TGT" -o "$out.o" "$KERN" >"$out.o.log" 2>&1 || echo "emit obj rc=$? f=$f" ); }
emit_one 0 "$WORK/off"
emit_one 1 "$WORK/on"

# ── Gate1 — SKIP (delegated to CI) ──────────────────────────────────────────
say "--- Gate1 OFF-byteeq → SKIP (delegated to CI 3-target; needs baseline build, OOM-avoided here) ---"

# ── Gate2 — lever: boxed-op call counts + extra regex, OFF vs ON ─────────────
say "--- Gate2 lever (boxed-op call-count + asm OFF vs ON) ---"
DEFAULT_OPS='hexa_index_get hexa_index_set hexa_mod hexa_div hexa_add hexa_sub hexa_mul hexa_cmp'
for tag in off on; do
    s="$WORK/$tag.s"
    if [ -f "$s" ]; then
        line="  $tag:"
        for op in $DEFAULT_OPS; do
            c=$(grep -cE "\\bcall\\b.*$op" "$s" 2>/dev/null | tr -d '\n'); [ "$c" != 0 ] && line="$line $op=$c"
        done
        sp=$(grep -cE '\[rbp - [0-9]+\]|\[rbp\+' "$s" 2>/dev/null | tr -d '\n'); line="$line spill_refs=$sp"
        if [ -n "$LEVER_GREP" ]; then
            xc=$(grep -cE "$LEVER_GREP" "$s" 2>/dev/null | tr -d '\n'); line="$line [extra:$LEVER_GREP]=$xc"
        fi
        say "$line"
    else say "  $tag: NO .s (emit failed):"; tail -10 "$s.log" 2>/dev/null | sed 's/^/      /' | tee -a "$RESULT"; fi
done
if [ -f "$WORK/off.s" ] && [ -f "$WORK/on.s" ]; then
    if cmp -s "$WORK/off.s" "$WORK/on.s"; then
        say "  ⚠ asm OFF==ON byte-identical — flag had NO codegen effect (lever did not fire)"
    else
        say "  asm OFF!=ON (lever LIVE). diff head:"; diff "$WORK/off.s" "$WORK/on.s" | head -50 | sed 's/^/    /' | tee -a "$RESULT"
    fi
fi

# ── Gate3+4 — runtime ratio + parity (gcc -O2 link, ISOLATED ALTERNATING median-7) ─
# root-cause ⓓ (back-to-back contamination): timing OFF fully then ON fully in two
# sequential BLOCKS lets transient core contention / warm-cache / thermal-turbo skew
# the ratio. Observed 2026-06-27: the element-pack FUSED k3 kernel reported ratio=1.000
# in-harness (OFF=ON≈1.8s) while the TRUE isolated ratio was 0.103 (9.7× faster) — a
# back-to-back artifact that masked a real win and nearly produced a false-negative
# (3rd recurrence; cf r2c in-harness 0.998 vs isolated 2.7×). FIX = ALTERNATE off,on
# per round in separate isolated processes with a cooldown, so any transient system
# state is shared equally between the two → the RATIO stays valid even if absolutes
# drift. Wall-clock (%e) is the metric that gave the clean isolated number.
say "--- Gate3+4 runtime ratio + parity (isolated alternating median-7) ---"
build_bin() { # $1=tag → links $WORK/$tag.bin, echoes the parity output, rc=1 on fail
    local tag="$1" o="$WORK/$tag.o" b="$WORK/$tag.bin"
    [ -f "$o" ] || { say "  $tag: no .o (emit failed)"; return 1; }
    [ -n "$RT" ] || { say "  $tag: no runtime.a → cannot link"; return 1; }
    gcc -O2 "$o" "$RT" -lm -o "$b" 2>"$b.ld.log" || { say "  $tag: gcc link FAIL"; tail -6 "$b.ld.log" | sed 's/^/      /' | tee -a "$RESULT"; return 1; }
    "$b" 2>/dev/null; }                                       # parity output → stdout
time_one() { { /usr/bin/time -f '%e' taskset -c 3 "$1" >/dev/null; } 2>&1 | tail -1; } # wall s
OUT_off=$(build_bin off); ok_off=$?
OUT_on=$(build_bin on);   ok_on=$?
off_vals=(); on_vals=()
if [ "$ok_off" = 0 ] && [ "$ok_on" = 0 ]; then
    for r in 1 2 3 4 5 6 7; do                                # alternate, NOT block-sequential
        off_vals+=("$(time_one "$WORK/off.bin")"); sleep 0.4
        on_vals+=("$(time_one "$WORK/on.bin")");   sleep 0.4
    done
    MED_off=$(printf '%s\n' "${off_vals[@]}" | sort -n | sed -n '4p')  # median of 7
    MED_on=$(printf '%s\n' "${on_vals[@]}"  | sort -n | sed -n '4p')
    say "  off: median_wall_s=$MED_off (samples: ${off_vals[*]})"
    say "  on:  median_wall_s=$MED_on (samples: ${on_vals[*]})"
fi
if [ -n "${OUT_off:-}" ] && [ "${OUT_off:-x}" = "${OUT_on:-y}" ]; then say "  Gate4 PARITY=OK (${OUT_off})"
else say "  Gate4 PARITY=FAIL off=${OUT_off:-?} on=${OUT_on:-?} (SOUNDNESS BLOCK)"; fi
RATIO=$(awk -v a="${MED_on:-0}" -v b="${MED_off:-0}" 'BEGIN{if(b>0)printf "%.3f",a/b; else print "NA"}')
say "  Gate3 ratio ON/OFF (wall, isolated alt) = $RATIO   (<1.0 = speedup)"

# ── Gate5 — opt-in ship smoke ───────────────────────────────────────────────
if [ "$DO_SMOKE" = 1 ]; then
    say "--- Gate5 ship smoke ($FLAG=1) ---"
    HX="$(command -v hexa || echo "$HOME/.hx/bin/hexa")"
    if [ -x "$HX" ]; then
        say "  version: $(env "$FLAG=1" "$HX" --version 2>&1 | head -1)"
        printf 'fn main(){println("hello")}\n' > "$WORK/hello.hexa"; printf 'fn main(){exit(42)}\n' > "$WORK/e42.hexa"
        ( cd "$WORK"; env "$FLAG=1" "$HX" run hello.hexa >h.out 2>h.err; say "  hello rc=$? out=$(cat h.out 2>/dev/null)" )
        ( cd "$WORK"; env "$FLAG=1" "$HX" run e42.hexa >/dev/null 2>e.err; say "  exit42 rc=$?" )
    else say "  hexa not found ($HX)"; fi
fi

# ── machine-readable RESULT footer ──────────────────────────────────────────
say "=== RESULT branch=$BR flag=$FLAG ratio=$RATIO parity=$([ "${OUT_off:-x}" = "${OUT_on:-y}" ] && echo OK || echo FAIL) runtime_a=${RT:-NONE} ==="
say "=== DONE — artifacts under $WORK ==="
