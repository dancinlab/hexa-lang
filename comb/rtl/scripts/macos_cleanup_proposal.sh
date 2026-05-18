#!/usr/bin/env bash
# macos_cleanup_proposal.sh — REVIEW BEFORE RUNNING. Task #18.
#
# Removes the macOS-local OpenROAD source-build leftovers that became
# sunk-cost after the T3 P&R path moved to ubu-2 Docker ORFS:
#   /tmp/OpenROAD           (1.7 GB OpenROAD repo + 400 MB build tree)
#   /tmp/sky130             (sky130_fd_sc_hd lib clone, 100+ MB)
#   /tmp/lemon-1.3.1, /tmp/cudd-src, /tmp/OpenSTA  (source dirs)
#   /tmp/openroad_build*.log, /tmp/lemon.tgz       (logs/tarballs)
#   /opt/homebrew/opt/coin-lemon   (source-built LEMON graph lib)
#   /opt/homebrew/opt/cudd          (source-built CUDD)
#
# brew formulas installed solely for the macOS OpenROAD build (review
# before removing — some may be useful for other work):
#   bison flex spdlog lemon (parser-gen) or-tools yaml-cpp libffi
#   googletest zstd swig sv2v
#
# Patch info (LEMON allocator_traits fix, 3 macOS-arm64 patches) is
# preserved in comb/HANDOFF_TO_HEXA_ARCH.md §1 for hexa-arch's future
# reference. Removal does NOT lose information — handoff has it.
#
# DO NOT just exec this. Review each section, then run individually
# what you want gone. Defaults: tarballs and source builds = safe to
# remove; brew packages = manual confirm.

set -uo pipefail
echo "macOS OpenROAD build artifact cleanup proposal"
echo "(DRY RUN — no actual deletions; uncomment to execute)"
echo

echo "--- /tmp source dirs + tarballs (safe, regeneratable from git) ---"
for d in /tmp/OpenROAD /tmp/sky130 /tmp/lemon-1.3.1 /tmp/cudd-src /tmp/OpenSTA \
         /tmp/lemon.tgz /tmp/cudd.tgz /tmp/openroad_build*.log /tmp/sky130_lib; do
    [ -e "$d" ] && du -sh "$d" 2>/dev/null
done
echo "# to remove: rm -rf /tmp/{OpenROAD,sky130,lemon-1.3.1,cudd-src,OpenSTA,lemon.tgz,cudd.tgz,sky130_lib} /tmp/openroad_build*.log"

echo
echo "--- /opt/homebrew/opt source-built libs (review; reversible) ---"
for p in coin-lemon cudd; do
    [ -d "/opt/homebrew/opt/$p" ] && du -sh "/opt/homebrew/opt/$p" 2>/dev/null
done
echo "# to remove: rm -rf /opt/homebrew/opt/{coin-lemon,cudd}"

echo
echo "--- brew formulas installed for OpenROAD build (REVIEW each) ---"
echo "# These were installed during the macOS OpenROAD attempt."
echo "# Many are general dev tools (yosys, sv2v, bison, flex, swig, googletest);"
echo "# only remove if certain no other use."
echo
echo "candidates (check 'brew uses' to see if anything depends on them):"
for f in yosys sv2v bison flex spdlog or-tools lemon yaml-cpp libffi googletest zstd swig; do
    if brew list "$f" >/dev/null 2>&1; then
        v=$(brew list --versions "$f" 2>/dev/null | head -1)
        u=$(brew uses --installed "$f" 2>/dev/null | tr '\n' ' ')
        printf "  %-15s %-25s  used by: %s\n" "$f" "$v" "${u:-none}"
    fi
done
echo "# to remove e.g.: brew uninstall yosys sv2v   (review 'used by' first)"

echo
echo "Note: 'klayout' (cask) is independently useful — keep unless certain."
echo "Note: cmake/boost/eigen/tcl-tk/libomp are common; do NOT remove."
