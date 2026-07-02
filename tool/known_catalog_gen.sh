#!/bin/sh
# tool/known_catalog_gen.sh — generator for compiler/atlas/known_catalog.gen.hexa
# (OUROBOROS-novel M3 · state/fable-eval-discovery-2026-07-02/NEXUS_novel_design_fable.md).
#
# SSOT of the atlas-identity shard = compiler/atlas/embedded.gen.hexa (the folded
# @F ledger). This extracts the PURE-BASIS product identities A*B=C*D whose four
# tokens are all in the 18-fn af() basis — exactly the sub-space the drill BLOWUP
# enumerator (compiler/drill/grammar.hexa) can reach. Numeric-constant point-value
# @F (e.g. "n*12 = n*sigma") are OUTSIDE the basis-product enumerator and excluded
# by construction. Emits the `kc_af_identity_tuples` flat index array. The classical
# sequence + composition-symbol shard below the marker is hand-authored (SSOT = the
# design doc §2-P3 list) and preserved verbatim across regeneration.
#
# Regenerate:  sh tool/known_catalog_gen.sh > /tmp/kc_tuples.txt   (then splice)
set -e
EMB=compiler/atlas/embedded.gen.hexa

# token -> af() index (identity_engine.hexa af basis 0..17)
map_idx() {
  case "$1" in
    sigma) echo 0;; sig2) echo 1;; sig3) echo 2;; phi) echo 3;; tau) echo 4;;
    n) echo 5;; sopfr) echo 6;; rad) echo 7;; J2) echo 8;; psi) echo 9;;
    Om) echo 10;; om) echo 11;; mu) echo 12;; lam) echo 13;; mu2) echo 14;;
    J3) echo 15;; tw_om) echo 16;; core) echo 17;; *) echo -1;;
  esac
}

grep -oE 'raw: "@F [^"]*' "$EMB" \
  | grep -oE '= [a-zA-Z]+\*[a-zA-Z0-9]+ = [a-zA-Z0-9]+\*[a-zA-Z]+' \
  | sed 's/^= //' \
  | grep -E '^[a-zA-Z][a-zA-Z0-9]*\*[a-zA-Z][a-zA-Z0-9]*  *=  *[a-zA-Z][a-zA-Z0-9]*\*[a-zA-Z][a-zA-Z0-9]*$' \
  | sort -u \
  | while IFS= read -r line; do
      # line = A*B = C*D
      A=$(echo "$line" | sed -E 's/\*.*//')
      B=$(echo "$line" | sed -E 's/^[^*]*\*([^ ]*).*/\1/')
      C=$(echo "$line" | sed -E 's/.*= ([^*]*)\*.*/\1/')
      D=$(echo "$line" | sed -E 's/.*\*//')
      ia=$(map_idx "$A"); ib=$(map_idx "$B"); ic=$(map_idx "$C"); id=$(map_idx "$D")
      # emit only if all four tokens are in-basis
      if [ "$ia" -ge 0 ] && [ "$ib" -ge 0 ] && [ "$ic" -ge 0 ] && [ "$id" -ge 0 ]; then
        printf '    %d, %d, %d, %d,   // %s\n' "$ia" "$ib" "$ic" "$id" "$line"
      fi
    done
