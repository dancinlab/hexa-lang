#!/usr/bin/env bash
# test/native_build/elf_ownstart/run.sh
#
# HEXA-OWN axis-③ · in-tree ELF x86_64 own-start linker — link-and-run REAL-verify.
#
# Rounds 1+2 (link_elf_x86_64_ownstart + serialize_elf_exec_x86_64{,_2seg}) passed
# byteeq (the compiler's own bytes are unchanged, since the ELF path is opt-in
# behind --linker=hexa), but byteeq does NOT prove the linker produces a *running*
# binary. This harness does: it compiles each program to a native x86_64 .o via the
# OWN backend, links it via --linker=hexa into a static ET_EXEC, RUNS it, and asserts
# the exit code / stdout AND that ZERO binutils (as/ld/gcc/clang/collect2) were exec'd.
#
# POOL-ONLY (aiden/summer, x86_64-linux) — self-refuses elsewhere (mini = git/gh only,
# cannot run x86_64 ELF). Requires a freshly-built `hexa` >= c62ea8d38 on PATH; a stale
# ~/.hx falls back to system ld and makes the binutils gate RED (the pre-round-1/2
# baseline). Prints a per-gate PASS/FAIL trace + a final TALLY; exit 0 only if all pass.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
DRIVER="${HEXA_DRIVER:-compiler/main.hexa}"   # run from repo root, or set HEXA_DRIVER
TGT="x86_64-linux-gnu"

PASS=0; FAIL=0
ok()   { echo "  [PASS] $1"; PASS=$((PASS+1)); }
bad()  { echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }

# ── Environment gate ──────────────────────────────────────────────
uname_sm="$(uname -sm 2>/dev/null)"
if [ "$uname_sm" != "Linux x86_64" ]; then
    echo "SKIP: elf_ownstart harness is x86_64-linux-only (host: '$uname_sm'). Run on aiden/summer."
    exit 0
fi
for t in hexa readelf file strace nm; do
    command -v "$t" >/dev/null 2>&1 || { echo "SKIP: missing tool '$t'"; exit 0; }
done

# run_case NAME SOURCE EXPECT_RC EXPECT_STDOUT(may be empty)
run_case() {
    local name="$1" src="$2" exp_rc="$3" exp_out="$4"
    echo "── $name ──"
    local obj="$WORK/$name.o" exe="$WORK/$name" slog="$WORK/$name.strace" out="$WORK/$name.out"

    # STEP1 — own-backend native ELF .o
    if hexa run "$DRIVER" --backend=native --emit=obj --target="$TGT" -o "$obj" "$src" >/dev/null 2>"$WORK/$name.o.err"; then
        # readelf is authoritative for machine+type; `file` is informational (its
        # field order is type-before-machine, so we match relocatable AND x86-64
        # without assuming order).
        if readelf -h "$obj" 2>/dev/null | grep -qE 'Type:[[:space:]]+REL' \
           && readelf -h "$obj" 2>/dev/null | grep -qiE 'Machine:.*(X86-64|x86-64|Advanced Micro)'; then
            ok "$name STEP1 own-backend .o is ELF x86-64 ET_REL"
        else bad "$name STEP1 .o not ELF x86-64 ET_REL"; return; fi
    else bad "$name STEP1 own-backend obj emit failed ($(tail -1 "$WORK/$name.o.err"))"; return; fi

    # STEP2 — FALSIFIER: the .o must be self-contained (0 UNDEF externs). A nonzero
    # count means the program pulls a runtime symbol = a multi-object dependency
    # (round-1b), NOT a false failure of rounds 1+2 — STOP this case cleanly.
    local nu; nu="$(nm -u "$obj" 2>/dev/null | grep -cE '^ *U ' || true)"
    if [ "${nu:-0}" -ne 0 ]; then
        echo "  [SKIP] $name has $nu UNDEF extern(s) — needs multi-obj link (round-1b), out of rounds-1+2 scope"; return
    fi
    ok "$name STEP2 .o is self-contained (0 UNDEF)"

    # STEP3 — link to static ET_EXEC via the in-tree linker, under execve trace
    if strace -f -qq -e trace=execve -o "$slog" \
         hexa run "$DRIVER" --backend=native --linker=hexa --emit=exec --target="$TGT" -o "$exe" "$src" >/dev/null 2>"$WORK/$name.exe.err"; then
        ok "$name STEP3 --linker=hexa exec link succeeded"
    else bad "$name STEP3 --linker=hexa exec link failed ($(tail -1 "$WORK/$name.exe.err"))"; return; fi

    # STEP4 — 0 binutils: no execve of as/ld/ld.*/gcc/g++/cc/clang/collect2
    if grep -qE 'execve\("[^"]*/(as|ld|ld\.[A-Za-z0-9]+|gcc|g\+\+|cc|clang|clang\+\+|collect2)"' "$slog"; then
        echo "  offending: $(grep -oE 'execve\("[^"]*/(as|ld|ld\.[A-Za-z0-9]+|gcc|g\+\+|cc|clang|clang\+\+|collect2)"' "$slog" | head -1)"
        bad "$name STEP4 a binutils tool WAS exec'd (stale hexa? not the own linker)"
    else ok "$name STEP4 0 binutils exec'd (own linker did the whole link)"; fi

    # STEP5 — ET_EXEC static (no PT_INTERP, no PT_DYNAMIC)
    if readelf -h "$exe" 2>/dev/null | grep -qE 'Type:[[:space:]]+EXEC' \
       && ! readelf -l "$exe" 2>/dev/null | grep -qE 'INTERP|DYNAMIC'; then
        ok "$name STEP5 static ET_EXEC (no INTERP/DYNAMIC)"
    else bad "$name STEP5 not a static ET_EXEC"; fi

    # STEP6 — run + assert exit code and EXACT stdout (byte-compare via cmp, so a
    # trailing newline is NOT stripped the way $(cat) would).
    "$exe" >"$out" 2>/dev/null; local rc=$?
    if [ "$rc" -eq "$exp_rc" ]; then ok "$name STEP6 exit code = $exp_rc"
    else bad "$name STEP6 exit code = $rc (want $exp_rc)"; fi
    if printf '%s' "$exp_out" | cmp -s - "$out"; then ok "$name STEP6 stdout matches"
    else bad "$name STEP6 stdout mismatch (want $(printf '%q' "$exp_out"), got $(printf '%q' "$(cat "$out")"))"; fi
}

echo "=== ELF own-start link-and-run harness (rounds 1+2) ==="
run_case exit_code "$HERE/exit_code.hexa" 42 ""
run_case hello_str "$HERE/hello_str.hexa" 0 "hello
"

echo ""
echo "TALLY: $PASS passed, $FAIL failed"
if [ "$FAIL" -eq 0 ] && [ "$PASS" -gt 0 ]; then echo "GATE GREEN"; exit 0; else echo "GATE RED"; exit 1; fi
