#!/bin/bash
# Regression runner for the QFORGE-BIO interpreter-gap probes (R9~R13).
#
# Each gap was filed as a sidecar handoff; this script re-runs the minimal
# repro for each and asserts the CORRECT (bug-absent) output. A failure here
# means a regression has reintroduced one of the gaps.
#
# Gap map (handoff id -> probe -> status on current main):
#   eb7f3073  gap5 visibility   -> CONTRACT (convention-only; SPEC.md §6.4). Not enforced by design.
#   043569f7  gap4 float-fold   -> FIXED in source (OP-40 hex-float fold). Needs FRESH hexat
#                                  (stale installed binary still truncates to 6 sig-figs).
#   17b823a6  gap2 floor/%      -> RESOLVED: floor() returns int; float % is type-consistent.
#   fcd72679  gap3 struct-slot  -> RESOLVED: cross-module slot-name collisions work (bt74 fix).
#   (no id)   gap1 closure      -> RESOLVED: closures capture local `let`, not just params.
#
# Usage: bash tests/interp_qforge_bio/run.sh
set -u
cd "$(dirname "$0")/../.." || exit 2
HEXA="${HEXA:-hexa}"
pass=0; fail=0
check() {  # check <name> <expected-substring> <file>
    local name="$1" want="$2" file="$3"
    local out; out="$($HEXA run "$file" 2>&1)"
    if printf '%s' "$out" | grep -qF -- "$want"; then
        echo "PASS  $name"; pass=$((pass+1))
    else
        echo "FAIL  $name — wanted '$want', got:"; printf '%s\n' "$out" | tail -4 | sed 's/^/        /'
        fail=$((fail+1))
    fi
}

D=tests/interp_qforge_bio

# gap1 — closure captures local let (106 = 1 + base5 + offset100)
check "gap1 closure-local"   "106"      "$D/gap1_closure.hexa"
check "gap1 closure-derived" "22.0000"  "$D/gap1_closure2.hexa"

# gap2 — floor() is int + float % type-consistent
check "gap2 floor-int"   "int"    "$D/gap2_probe.hexa"
check "gap2 float-mod"   "1.500"  "$D/gap2_floatmod.hexa"

# gap3 — cross-module struct slot-name collision resolves (Node/AbfeConfig share ladder,grad)
check "gap3 struct-slot" "2.50"   "$D/gap3_struct.hexa"

# gap4 — comptime float-fold is bit-exact (OP-40 hex-float serialize).
#   gap4_module_value: the runtime division is full-precision on ANY build.
#   gap4_equal: in-main const-fold == runtime → FOLD_EXACT only on a FRESH
#     hexat. A STALE pre-OP-40 binary prints FOLD_LOSSY (6-sig-fig truncation).
check "gap4 fold-module" "3.150574226831496" "$D/gap4_module_value.hexa"
check "gap4 fold-exact"  "FOLD_EXACT"         "$D/gap4_equal.hexa"

# gap5 — _prefix private fn IS callable cross-module (documented convention).
check "gap5 visibility"  "42"     "$D/gap5_visibility.hexa"

echo "----"
echo "interp-qforge-bio: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
