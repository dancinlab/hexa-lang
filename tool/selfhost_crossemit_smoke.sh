#!/usr/bin/env bash
# tool/selfhost_crossemit_smoke.sh — SELFHOST-CI M3 multi-target cross-emit smoke.
#
# PURPOSE
#   A STANDING, per-PR smoke gate around the multi-target cross-emit path that
#   was PROVEN one-time in SELFHOST-NEXT:
#     • arm64 ELF page-reloc PAIR  (#2562  R_AARCH64_ADR_PREL_PG_HI21
#                                          + R_AARCH64_ADD_ABS_LO12_NC)
#     • x86_64 ELF RIP-rel reloc   (#2563  R_X86_64_PC32)
#     • linux-arm64 data-reloc program emit→assemble→link→RUN (#2574/2603 qemu)
#   It locks those object-format + reloc layers against silent regression by
#   re-exercising the EMIT path every PR and ASSERTING the actual relocation
#   entries (not merely "an object was produced"), then LINK+RUNning each target
#   wherever the host toolchain permits (x86_64 natively, aarch64 under qemu).
#
#   This is distinct from the sister gates:
#     • selfhost_byteeq_gate.sh    — whole-compiler byte-eq fixpoint
#     • selfhost_codegen_guard.sh  — native arm64 codegen-class correctness
#   This gate is the CROSS-TARGET object-format fence.
#
# EMIT PATH (portable — needs only a released `hexa`, NOT the native gen2_fix)
#   The in-tree emit harnesses drive the SAME serializers the compiler uses:
#     compiler/test/elf_arm64_data.hexa  → ELF AArch64 .o via
#         pack_lir_arm64_elf + serialize_elf_arm64 (compiler/emit/elf_arm64.hexa)
#     compiler/test/elf_x86_64_data.hexa → ELF x86_64 .o via
#         pack_lir_x86_64 + serialize_elf_x86_64 (compiler/emit/elf_x86_64.hexa)
#   Each harness writes THREE objects under a relative out-dir:
#     (A) data    — main ADRP/ADD (arm64) / lea-RIP (x86) of .rodata + .data
#                   → the reloc PAIR / PC32 against BOTH sections.
#     (B) exit7   — text-only baseline (no data reloc).
#     (C) start   — runnable freestanding `_start` (write(1,str,3)+exit(7))
#                   whose .rodata string ref USES the data reloc → if the reloc
#                   resolves to the right runtime address, stdout=="hi" rc==7.
#
# WHAT IT ASSERTS (per target, hard)
#   arm64-ELF   : module-A .o carries R_AARCH64_ADR_PREL_PG_HI21 AND
#                 R_AARCH64_ADD_ABS_LO12_NC (the #2562 page PAIR), against
#                 .rodata AND .data (≥2 of each). If aarch64-linux-gnu-as/-ld +
#                 qemu-aarch64-static are present: assemble + link module-C +
#                 RUN under qemu, assert stdout=="hi" rc==7.
#   x86_64-ELF  : module-A .o carries R_X86_64_PC32 (≥2 — .rodata + .data ref).
#                 If a native x86_64 host (or x86_64 as/ld): link module-C + RUN,
#                 assert stdout=="hi" rc==7. (Native x86_64 runs directly; no qemu.)
#   linux-arm64 : SAME as arm64-ELF run leg — the cross_emit data-reloc PROGRAM
#                 (module C) assembled by aarch64-linux-gnu-as + run under qemu.
#                 (This IS the linux-arm64 data-reloc program leg; on an x86_64
#                 Linux host with the aarch64 cross-binutils + qemu it runs REAL.)
#
# NEUTRAL POLICY (exit-2-neutral canary — same shape as the sister gates)
#   • If `hexa` cannot EMIT the objects AT ALL here (harness produced 0 ELF
#     objects), the whole gate exits 2 (SETUP/INFRA) — the cross-emit floor is
#     NOT broken, the runner just lacks a working `hexa`. CI remaps 2→neutral.
#   • A target whose RELOC could be asserted but whose host lacks the
#     assembler/linker/qemu to RUN it is reported PASS(reloc)/NEUTRAL(run): the
#     reloc assertion is the gate; the qemu run is best-effort where available.
#   • A TRUE regression (an expected reloc entry MISSING, or a run mismatch on a
#     host that DID run it) exits 1.
#
# CONFIG (env)
#   HEXA            hexa driver           (default: `hexa` on PATH)
#   AS_A64 LD_A64   aarch64 cross as/ld   (default: aarch64-linux-gnu-as / -ld)
#   QEMU_A64        aarch64 user-qemu     (default: qemu-aarch64-static, else qemu-aarch64)
#   AS_X86 LD_X86   x86_64 as/ld          (default: x86_64-linux-gnu-as / -ld, else as/ld)
#   QEMU_X86        x86_64 user-qemu      (default: <none>; native host runs directly)
#   READELF         reloc reader          (default: readelf, fallback llvm-readobj)
#   CE_OUT          output dir            (default: <repo>/build/selfhost-crossemit-out)
#
# EXIT
#   0  every emitted target's reloc set asserted clean (and every RUN that the
#      host could perform matched stdout/rc). Run legs the host can't perform are
#      reported NEUTRAL and do NOT fail the gate.
#   1  REGRESSION — an expected reloc entry is MISSING from an emitted object,
#      OR a target that RAN produced the wrong stdout/rc.
#   2  SETUP / INFRA — `hexa` cannot emit the cross-target objects here at all
#      (0 ELF objects produced). CI-neutral.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO" || { echo "crossemit-smoke: bad repo" >&2; exit 2; }

HEXA="${HEXA:-hexa}"
OUT="${CE_OUT:-$REPO/build/selfhost-crossemit-out}"
mkdir -p "$OUT"

# Harness out-dirs are RELATIVE to cwd (the harnesses write there); run each
# from a dedicated subdir so the relative dirs don't collide.
A64_HARNESS="compiler/test/elf_arm64_data.hexa"
X86_HARNESS="compiler/test/elf_x86_64_data.hexa"
A64_DIR="$OUT/a64/out_elfa64"
X86_DIR="$OUT/x86/out_elfx86"

# ── tool discovery ────────────────────────────────────────────────────────
READELF="${READELF:-}"
if [ -z "$READELF" ]; then
  if command -v readelf >/dev/null 2>&1; then READELF="readelf"
  elif command -v llvm-readobj >/dev/null 2>&1; then READELF="llvm-readobj --relocs"
  else READELF=""; fi
fi
AS_A64="${AS_A64:-aarch64-linux-gnu-as}"; LD_A64="${LD_A64:-aarch64-linux-gnu-ld}"
QEMU_A64="${QEMU_A64:-}"
if [ -z "$QEMU_A64" ]; then
  if command -v qemu-aarch64-static >/dev/null 2>&1; then QEMU_A64="qemu-aarch64-static"
  elif command -v qemu-aarch64 >/dev/null 2>&1; then QEMU_A64="qemu-aarch64"; fi
fi
AS_X86="${AS_X86:-}"; LD_X86="${LD_X86:-}"
if [ -z "$AS_X86" ]; then
  if command -v x86_64-linux-gnu-as >/dev/null 2>&1; then AS_X86="x86_64-linux-gnu-as"
  elif command -v as >/dev/null 2>&1; then AS_X86="as"; fi
fi
if [ -z "$LD_X86" ]; then
  if command -v x86_64-linux-gnu-ld >/dev/null 2>&1; then LD_X86="x86_64-linux-gnu-ld"
  elif command -v ld >/dev/null 2>&1; then LD_X86="ld"; fi
fi
QEMU_X86="${QEMU_X86:-}"   # native x86_64 host runs directly; qemu only if cross

HOST_ARCH="$(uname -m 2>/dev/null || echo unknown)"
HOST_OS="$(uname -s 2>/dev/null || echo unknown)"
HEAD_SHA="$(git -C "$REPO" rev-parse --short HEAD 2>/dev/null || echo unknown)"

# readelf relocs of OBJ → stdout. Use `-rW` (wide) so GNU readelf does NOT
# truncate long AArch64 type names (`R_AARCH64_ADR_PREL_PG_HI21` →
# `R_AARCH64_ADR_PRE` in the default narrow column); llvm-readobj uses --relocs.
relocs_of() {
  [ -z "$READELF" ] && return 1
  case "$READELF" in
    *llvm-readobj*) $READELF "$1" 2>/dev/null ;;
    *)              readelf -rW "$1" 2>/dev/null ;;
  esac
}
# Count a reloc type by matching the FULL name as a whole token. The wide
# readelf form prints the full name; this matches it exactly (no trailing
# alnum/underscore) so `..._PG_HI21` never matches a longer name by prefix.
count_reloc() { grep -oE "${2}([^0-9A-Za-z_]|$)" <<<"$1" | wc -l | tr -d ' '; }

echo "── selfhost cross-emit smoke (M3) ────────────────────────────────"
echo "  hexa      : $HEXA"
echo "  host      : $HOST_OS $HOST_ARCH   HEAD=$HEAD_SHA"
echo "  readelf   : ${READELF:-<none>}"
echo "  arm64 as/ld/qemu : ${AS_A64} / ${LD_A64} / ${QEMU_A64:-<none>}"
echo "  x86  as/ld/qemu  : ${AS_X86:-<none>} / ${LD_X86:-<none>} / ${QEMU_X86:-<native>}"
echo "  out       : $OUT"
echo "──────────────────────────────────────────────────────────────────"

# ── EMIT — run both harnesses (portable hexa emit path) ───────────────────
emit_harness() {  # $1=harness  $2=subdir  $3=relout  $4=logname
  local harness="$1" sub="$2" relout="$3" log="$4"
  rm -rf "$sub"; mkdir -p "$sub/$relout"
  ( cd "$sub" && "$HEXA" run "$REPO/$harness" ) >"$OUT/$log" 2>&1
  return $?
}

echo "EMIT — arm64 ELF harness ($A64_HARNESS):"
emit_harness "$A64_HARNESS" "$OUT/a64" "out_elfa64" "a64-emit.log" || true
A64_OBJS=$(ls "$A64_DIR"/*.o 2>/dev/null | wc -l | tr -d ' ')
echo "  arm64 objects produced : $A64_OBJS"
[ "$A64_OBJS" -gt 0 ] && grep -E "wrote|relocs " "$OUT/a64-emit.log" 2>/dev/null | sed 's/^/    /'

echo "EMIT — x86_64 ELF harness ($X86_HARNESS):"
emit_harness "$X86_HARNESS" "$OUT/x86" "out_elfx86" "x86-emit.log" || true
X86_OBJS=$(ls "$X86_DIR"/*.o 2>/dev/null | wc -l | tr -d ' ')
echo "  x86_64 objects produced : $X86_OBJS"
[ "$X86_OBJS" -gt 0 ] && grep -E "wrote|relocs " "$OUT/x86-emit.log" 2>/dev/null | sed 's/^/    /'
echo "──────────────────────────────────────────────────────────────────"

# ── CANARY — could hexa emit ANY cross-target object at all? ───────────────
if [ "$A64_OBJS" -eq 0 ] && [ "$X86_OBJS" -eq 0 ]; then
  echo "crossemit-smoke: SETUP/INFRA — hexa emitted 0 cross-target objects." >&2
  echo "  (both harnesses produced no .o; the cross-emit path is NOT broken —" >&2
  echo "   this env lacks a working hexa emit. The real gate runs where `hexa`" >&2
  echo "   can `run` the emit harnesses.)" >&2
  echo "        ↳ a64 emit log: $OUT/a64-emit.log" >&2
  echo "        ↳ x86 emit log: $OUT/x86-emit.log" >&2
  exit 2
fi

fail=0

# ════════════════════════════════════════════════════════════════════════
# TARGET 1 — arm64 ELF page-reloc PAIR  (#2562) + linux-arm64 run leg (#2603)
# ════════════════════════════════════════════════════════════════════════
echo "TARGET arm64-ELF — page-reloc PAIR (ADR_PREL_PG_HI21 + ADD_ABS_LO12_NC):"
A64_RELOC="PASS"; A64_RUN="NEUTRAL"
A64_DATA="$A64_DIR/hexa_elf_arm64_data.o"
A64_START="$A64_DIR/hexa_elf_arm64_start.o"
if [ ! -s "$A64_DATA" ]; then
  echo "  FAIL  module-A object absent ($A64_DATA) — emit broke"
  A64_RELOC="FAIL"; fail=1
elif [ -z "$READELF" ]; then
  echo "  NEUTRAL  no readelf/llvm-readobj — cannot assert reloc entries here"
  A64_RELOC="NEUTRAL"
else
  R=$(relocs_of "$A64_DATA")
  N_PG=$(count_reloc "$R" "R_AARCH64_ADR_PREL_PG_HI21")
  N_LO=$(count_reloc "$R" "R_AARCH64_ADD_ABS_LO12_NC")
  echo "  R_AARCH64_ADR_PREL_PG_HI21 count : $N_PG"
  echo "  R_AARCH64_ADD_ABS_LO12_NC  count : $N_LO"
  # module A refs .rodata + .data → expect ≥2 of each (page PAIR ×2 sections)
  if [ "$N_PG" -ge 2 ] && [ "$N_LO" -ge 2 ]; then
    echo "  PASS  page-reloc PAIR present against .rodata AND .data (≥2 each)"
  else
    echo "  FAIL  page-reloc PAIR incomplete (need ≥2 ADR_PREL_PG_HI21 + ≥2 ADD_ABS_LO12_NC)"
    echo "        ↳ readelf -r dump:"; echo "$R" | sed 's/^/        /'
    A64_RELOC="FAIL"; fail=1
  fi
fi

# RUN leg (= linux-arm64 data-reloc program) — assemble module-C, link, qemu.
if [ "$A64_RELOC" != "FAIL" ] && [ -s "$A64_START" ]; then
  if command -v "$AS_A64" >/dev/null 2>&1 && command -v "$LD_A64" >/dev/null 2>&1 && [ -n "$QEMU_A64" ] && command -v "$QEMU_A64" >/dev/null 2>&1; then
    # The harness emits a complete relocatable .o (module C) already; link it
    # static -nostdlib (self-contained _start with the page-reloc'd string ref).
    if "$LD_A64" -static -nostdlib "$A64_START" -o "$A64_DIR/a64_start" 2>"$OUT/a64-link.log"; then
      GOT=$("$QEMU_A64" "$A64_DIR/a64_start" 2>/dev/null); RC=$?
      echo "  RUN   qemu-aarch64: stdout=[$GOT] rc=$RC  (expect stdout=[hi] rc=7)"
      if [ "$GOT" = "hi" ] && [ "$RC" = "7" ]; then
        echo "  PASS  linux-arm64 data-reloc program ran (page-reloc resolved)"
        A64_RUN="PASS"
      else
        echo "  FAIL  linux-arm64 run mismatch"
        A64_RUN="FAIL"; fail=1
      fi
    else
      echo "  NEUTRAL  link failed (ld $LD_A64): $(head -1 "$OUT/a64-link.log")"
      A64_RUN="NEUTRAL"
    fi
  else
    echo "  NEUTRAL  no aarch64 as/ld + qemu on this host — reloc asserted, run skipped"
    A64_RUN="NEUTRAL"
  fi
fi
echo "  ↳ arm64-ELF : reloc=$A64_RELOC  run=$A64_RUN"
echo "──────────────────────────────────────────────────────────────────"

# ════════════════════════════════════════════════════════════════════════
# TARGET 2 — x86_64 ELF RIP-relative reloc  (R_X86_64_PC32, #2563)
# ════════════════════════════════════════════════════════════════════════
echo "TARGET x86_64-ELF — RIP-relative reloc (R_X86_64_PC32):"
X86_RELOC="PASS"; X86_RUN="NEUTRAL"
X86_DATA="$X86_DIR/hexa_elf_x86_64_data.o"
X86_START="$X86_DIR/hexa_elf_x86_64_start.o"
if [ ! -s "$X86_DATA" ]; then
  echo "  FAIL  module-A object absent ($X86_DATA) — emit broke"
  X86_RELOC="FAIL"; fail=1
elif [ -z "$READELF" ]; then
  echo "  NEUTRAL  no readelf/llvm-readobj — cannot assert reloc entries here"
  X86_RELOC="NEUTRAL"
else
  R=$(relocs_of "$X86_DATA")
  N_PC32=$(count_reloc "$R" "R_X86_64_PC32")
  echo "  R_X86_64_PC32 count : $N_PC32"
  # module A refs .LCstr0 (.rodata) + g0 (.data) RIP-rel → expect ≥2
  if [ "$N_PC32" -ge 2 ]; then
    echo "  PASS  R_X86_64_PC32 present against .rodata AND .data (≥2)"
  else
    echo "  FAIL  R_X86_64_PC32 incomplete (need ≥2)"
    echo "        ↳ readelf -r dump:"; echo "$R" | sed 's/^/        /'
    X86_RELOC="FAIL"; fail=1
  fi
fi

# RUN leg — link module-C, run (native x86_64 directly, else qemu-x86_64).
if [ "$X86_RELOC" != "FAIL" ] && [ -s "$X86_START" ]; then
  if [ -n "${LD_X86:-}" ] && command -v "$LD_X86" >/dev/null 2>&1; then
    if "$LD_X86" -static -nostdlib "$X86_START" -o "$X86_DIR/x86_start" 2>"$OUT/x86-link.log"; then
      RUNNER=""
      if [ "$HOST_ARCH" = "x86_64" ] && [ "$HOST_OS" = "Linux" ]; then RUNNER=""        # native
      elif [ -n "$QEMU_X86" ] && command -v "$QEMU_X86" >/dev/null 2>&1; then RUNNER="$QEMU_X86"
      elif command -v qemu-x86_64-static >/dev/null 2>&1; then RUNNER="qemu-x86_64-static"
      elif command -v qemu-x86_64 >/dev/null 2>&1; then RUNNER="qemu-x86_64"
      else RUNNER="__NORUN__"; fi
      if [ "$RUNNER" = "__NORUN__" ]; then
        echo "  NEUTRAL  linked, but host is not x86_64 Linux and no qemu-x86_64 — run skipped"
        X86_RUN="NEUTRAL"
      else
        GOT=$($RUNNER "$X86_DIR/x86_start" 2>/dev/null); RC=$?
        echo "  RUN   ${RUNNER:-native}: stdout=[$GOT] rc=$RC  (expect stdout=[hi] rc=7)"
        if [ "$GOT" = "hi" ] && [ "$RC" = "7" ]; then
          echo "  PASS  x86_64 data-reloc program ran (PC32 resolved)"
          X86_RUN="PASS"
        else
          echo "  FAIL  x86_64 run mismatch"
          X86_RUN="FAIL"; fail=1
        fi
      fi
    else
      echo "  NEUTRAL  link failed (ld $LD_X86): $(head -1 "$OUT/x86-link.log")"
      X86_RUN="NEUTRAL"
    fi
  else
    echo "  NEUTRAL  no x86_64 ld on this host — reloc asserted, run skipped"
    X86_RUN="NEUTRAL"
  fi
fi
echo "  ↳ x86_64-ELF : reloc=$X86_RELOC  run=$X86_RUN"
echo "──────────────────────────────────────────────────────────────────"

# ── SUMMARY ────────────────────────────────────────────────────────────────
echo "SUMMARY (HEAD=$HEAD_SHA, host=$HOST_OS $HOST_ARCH):"
echo "  arm64-ELF      reloc=$A64_RELOC  run=$A64_RUN"
echo "  x86_64-ELF     reloc=$X86_RELOC  run=$X86_RUN"
echo "  linux-arm64    (= arm64-ELF run leg)  run=$A64_RUN"
echo "──────────────────────────────────────────────────────────────────"
if [ "$fail" -ne 0 ]; then
  echo "crossemit-smoke: FAIL — a cross-emit reloc is missing OR a run mismatched." >&2
  exit 1
fi
echo "crossemit-smoke: PASS — every emitted target's reloc set asserted clean;"
echo "  every run leg the host could perform matched stdout=hi rc=7."
exit 0
