#!/bin/bash
# escape_stress.sh — OFF vs ON bit-exact stress over all kernels.
# Usage: escape_stress.sh <aprime_cc> <drv.hexa> <runtime.a> <kernels_dir> <workdir>
# Emits a per-kernel table: name | PACKED?(grep on.s) | off_out | on_out | VERDICT
set -u
APRIME="$1"; DRV="$2"; RT="$3"; KDIR="$4"; WORK="$5"
mkdir -p "$WORK"; cd "$WORK" || exit 3
printf "%-18s %-9s %-14s %-14s %-8s\n" KERNEL PACKED OFF_OUT ON_OUT VERDICT
ALLPASS=1
for kf in "$KDIR"/*.hexa; do
  name=$(basename "$kf" .hexa)
  # emit OFF (env unset) and ON (=1)
  env -u HEXA_PACK_ARRAY "$APRIME" "$DRV" --emit=asm --target=x86_64-linux-gnu -o "$name.off.s" "$kf" >"$name.off.emit.log" 2>&1
  HEXA_PACK_ARRAY=1     "$APRIME" "$DRV" --emit=asm --target=x86_64-linux-gnu -o "$name.on.s"  "$kf" >"$name.on.emit.log"  2>&1
  off_emit=$([ -s "$name.off.s" ] && echo ok || echo EMIT_FAIL)
  on_emit=$([ -s "$name.on.s" ] && echo ok || echo EMIT_FAIL)
  if [ "$off_emit" != ok ] || [ "$on_emit" != ok ]; then
    printf "%-18s %-9s %-14s %-14s %-8s\n" "$name" "?" "$off_emit" "$on_emit" "EMIT_ERR"
    ALLPASS=0; continue
  fi
  # PACKED? heuristic: ON asm references the packed runtime ctor/raw helpers
  packed=$(grep -qE "hexa_arr_i64_new|hexa_arr_i64_push|hexa_arr_i64_box|arrpk" "$name.on.s" && echo PACKED || echo boxed)
  gcc -O2 "$name.off.s" "$RT" -o "$name.off.bin" -lm 2>"$name.off.lk"
  gcc -O2 "$name.on.s"  "$RT" -o "$name.on.bin"  -lm 2>"$name.on.lk"
  if [ ! -x "$name.off.bin" ] || [ ! -x "$name.on.bin" ]; then
    printf "%-18s %-9s %-14s %-14s %-8s\n" "$name" "$packed" "LINK_FAIL" "LINK_FAIL" "LINK_ERR"
    ALLPASS=0; continue
  fi
  off_out=$(timeout 30 ./"$name.off.bin" 2>&1; echo "rc=$?")
  on_out=$(timeout 30 ./"$name.on.bin"  2>&1; echo "rc=$?")
  if [ "$off_out" = "$on_out" ]; then v=PASS; else v=DIVERGE; ALLPASS=0; fi
  printf "%-18s %-9s %-14s %-14s %-8s\n" "$name" "$packed" "$(echo "$off_out"|tr '\n' ';')" "$(echo "$on_out"|tr '\n' ';')" "$v"
done
echo "---"
if [ "$ALLPASS" = 1 ]; then echo "ESCAPE_STRESS=ALL_BIT_EXACT"; else echo "ESCAPE_STRESS=DIVERGENCE_FOUND"; fi
