#!/bin/bash
# inbox/tools/const0_family_histogram.sh — rfc_006 §5 d-N closure diagnostic.
#
# Shell-only alternative to inbox/tools/const0_driver_analysis.hexa for use
# when the hexa diagnostic tool can't be built on the current host
# (e.g. ubu-2's arm64-only runtime.c gate, mini busy with another agent).
#
# Walks a post-ABC mapped BLIF and reports which RTL output ports / latch
# D-inputs are tied to `_const0_` placeholders — i.e. which port bits had
# no driver upstream of ABC. Used to identify the RTL write-site family
# responsible for dangling nets after Yosys synthesis.
#
# USAGE
#   const0_family_histogram.sh <path-to-mapped-blif>
#
# OUTPUT
#   - per-family count (latch.Q stripped of __b<n> bit-suffix)
#   - TOTAL / latch-D-input / other-consumer breakdown
#
# CLEAN-ROOM: pure awk over BLIF text; no upstream code, no Verilog parse.
# @since 2026-05-22
# @stability supporting

set -u
BLIF="${1:-}"
if [ -z "$BLIF" ] || [ ! -r "$BLIF" ]; then
  echo "usage: $0 <mapped.blif>" >&2
  exit 2
fi

awk -v blif="$BLIF" '
  /^\.latch / { latch_d[$2]=1; latch_q[$2]=$3 }
  /^\.gate _const0_ / {
    net=$NF; sub(/.*[xXzZ]=/, "", net); const0_nets[net]=1
  }
  END {
    for (n in const0_nets) {
      total++
      if (n in latch_d) {
        q=latch_q[n]; gsub(/__b[0-9]+$/, "", q); fams[q]++; total_latch++
      } else { other++ }
    }
    printf "_const0_ driver analysis (%s):\n", blif
    printf "  TOTAL _const0_ nets: %d\n", total
    printf "  latch D-input nets:  %d\n", total_latch
    printf "  other consumers:     %d\n", other
    print  ""
    print  "  by family (latch.Q with __bN suffix stripped):"
    for (f in fams) printf "    %6d  %s\n", fams[f], f
  }
' "$BLIF" | awk 'NR<=6 {print; next} {print | "sort -rn"}'
