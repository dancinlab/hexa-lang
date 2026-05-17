#!/usr/bin/env bash
# bench/chem_vqe_diatomic_bench.sh
#
# chem-vqe-bench harness — drives the 10-molecule independent verification
# suite for qmirror chemistry-VQE. Per QMIRROR.md §10 + §18 (top-3
# recommended ramp): cross-checks against published CCSD(T) (cited per
# molecule in bench/manifest.json). Complements the proprietary CMT
# scaffolds (clc1/hd6/mfn2/sar1/gjb1).
#
# Per AGENTS.md §1 — pure-hexa runtime; this harness orchestrates `hexa run`
# invocations and tallies the sentinel lines emitted by each per-molecule
# module. No subprocess fan-out into Python or external services.
#
# Sentinel grammar per-molecule:
#   __QMIRROR_<MOLECULE_TAG>__ PASS                   → success
#   __QMIRROR_<MOLECULE_TAG>__ FAIL                   → chem-acc bound violated
#   __QMIRROR_<MOLECULE_TAG>__ EXTRACTION_PENDING     → vendored Hamiltonian
#                                                       not yet extracted
#                                                       (run extract script
#                                                       on dev machine)
#
# Marker emission (per AGENTS.md §39 convention — state/markers/ is .gitignored
# but is the live signalling channel for selftest harnesses + downstream gates):
#   state/markers/bench_diatomic_<mol>_<as>_<ts>.marker          (PASS)
#   state/markers/bench_diatomic_<mol>_<as>_<ts>_FAILED.marker   (FAIL)
#   state/markers/bench_diatomic_<mol>_<as>_<ts>_PENDING.marker  (EXTRACTION_PENDING)
#
# Usage:
#   bench/chem_vqe_diatomic_bench.sh                   # run all 10 (default)
#   bench/chem_vqe_diatomic_bench.sh --only h2,lih     # subset
#   bench/chem_vqe_diatomic_bench.sh --skip-pending    # only runnable today
#   bench/chem_vqe_diatomic_bench.sh --no-markers      # don't emit marker files

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="${REPO_ROOT}/bench/manifest.json"
MARKER_DIR="${REPO_ROOT}/state/markers"

HEXA="${HEXA:-hexa}"
HEXA_TIMEOUT="${HEXA_TIMEOUT:-300}"   # seconds per molecule

ONLY=""
SKIP_PENDING=0
EMIT_MARKERS=1

while [ $# -gt 0 ]; do
    case "$1" in
        --only) ONLY="$2"; shift 2 ;;
        --skip-pending) SKIP_PENDING=1; shift ;;
        --no-markers) EMIT_MARKERS=0; shift ;;
        --help|-h)
            sed -n '2,35p' "$0"
            exit 0
            ;;
        *)
            echo "[bench] unknown flag: $1" >&2; exit 2 ;;
    esac
done

if [ ! -f "${MANIFEST}" ]; then
    echo "[bench] missing manifest: ${MANIFEST}" >&2; exit 2
fi

mkdir -p "${MARKER_DIR}"

# ── Molecule registry (manually mirrored from manifest.json — keep in sync).
# (id, module-path-relative-to-repo-root, sentinel-tag, as-suffix, status)
# Format: "id|module|sentinel|as|status"
MOLS=(
  "h2|chemistry_vqe/module/chemistry_vqe.hexa|__QMIRROR_CHEMISTRY_VQE__|2e2o|RUNNABLE"
  "lih|chemistry_vqe/module/chemistry_vqe_cmt_4e4o_lih_validation.hexa|__QMIRROR_CHEM_CMT_VQE_4E4O_LIH_VALIDATION__|4e4o|RUNNABLE"
  "lih_4e5o|chemistry_vqe/module/chemistry_vqe_cmt_uccsd_lih_4e5o.hexa|__QMIRROR_CHEM_CMT_UCCSD_LIH_4E5O_INPROC_NM__|4e5o|RUNNABLE"
  "beh2|bench/module/bench_4e4o_beh2.hexa|__QMIRROR_BENCH_CHEM_VQE_BEH2_4E4O__|4e4o|PENDING"
  "h2o|bench/module/bench_4e4o_h2o.hexa|__QMIRROR_BENCH_CHEM_VQE_H2O_4E4O__|4e4o|PENDING"
  "nh3|bench/module/bench_4e4o_nh3.hexa|__QMIRROR_BENCH_CHEM_VQE_NH3_4E4O__|4e4o|PENDING"
  "hf|bench/module/bench_4e4o_hf.hexa|__QMIRROR_BENCH_CHEM_VQE_HF_4E4O__|4e4o|PENDING"
  "n2|bench/module/bench_4e4o_n2.hexa|__QMIRROR_BENCH_CHEM_VQE_N2_4E4O__|4e4o|PENDING"
  "co|bench/module/bench_4e4o_co.hexa|__QMIRROR_BENCH_CHEM_VQE_CO_4E4O__|4e4o|PENDING"
  "f2|bench/module/bench_4e4o_f2.hexa|__QMIRROR_BENCH_CHEM_VQE_F2_4E4O__|4e4o|PENDING"
  "ch4|bench/module/bench_4e4o_ch4.hexa|__QMIRROR_BENCH_CHEM_VQE_CH4_4E4O__|4e4o|PENDING"
)

# Build effective set (filter by --only / --skip-pending).
in_only_set() {
    local id="$1"
    if [ -z "${ONLY}" ]; then return 0; fi
    case ",${ONLY}," in
        *",${id},"*) return 0 ;;
        *) return 1 ;;
    esac
}

# Per-molecule run.
declare -i N_PASS=0 N_FAIL=0 N_PENDING=0 N_ERR=0 N_SKIP=0
TS_RUN="$(date +%s)"
printf '\n=== qmirror chem-vqe-bench (10 molecules; ts=%s) ===\n' "${TS_RUN}"
printf '  manifest: %s\n' "${MANIFEST}"
printf '  marker dir: %s%s\n' "${MARKER_DIR}" "$([ ${EMIT_MARKERS} -eq 0 ] && echo '  (--no-markers)' || echo '')"
printf '  acceptance: |E_VQE - E_CASCI(N,M)| < 1.6 mHa per QMIRROR.md §20\n\n'

ROWS=()  # collected rows for summary table

for entry in "${MOLS[@]}"; do
    IFS='|' read -r MID MPATH MSEN MAS MSTATUS <<<"${entry}"

    if ! in_only_set "${MID}"; then
        N_SKIP=$((N_SKIP + 1))
        continue
    fi
    if [ "${SKIP_PENDING}" -eq 1 ] && [ "${MSTATUS}" = "PENDING" ]; then
        N_SKIP=$((N_SKIP + 1))
        printf '  [SKIP-PENDING] %-12s %s\n' "${MID}" "${MPATH}"
        continue
    fi

    FULLPATH="${REPO_ROOT}/${MPATH}"
    if [ ! -f "${FULLPATH}" ]; then
        N_ERR=$((N_ERR + 1))
        printf '  [ERR-MISSING] %-12s no such file: %s\n' "${MID}" "${MPATH}"
        ROWS+=( "${MID}|${MAS}|MISSING|n/a|0" )
        continue
    fi

    T0="$(date +%s)"
    # `hexa run` invocation. Tee output so we can scan for sentinel + delta.
    LOG="$(mktemp -t qmirror-bench-XXXXXX.log)"
    set +e
    timeout "${HEXA_TIMEOUT}" "${HEXA}" run "${FULLPATH}" --selftest >"${LOG}" 2>&1
    RC=$?
    set -e
    T1="$(date +%s)"
    WALL=$((T1 - T0))

    # Parse sentinel.
    SENTLINE="$(grep -E "^${MSEN}" "${LOG}" 2>/dev/null | tail -n1 || true)"
    VERDICT="UNKNOWN"
    if [ -n "${SENTLINE}" ]; then
        VERDICT="$(echo "${SENTLINE}" | awk '{print $2}')"
    fi

    # Parse |delta| if printed (handles both "|delta|=X uHa" and "|delta| = X uHa").
    DELTA_UHA="$(grep -E '\|delta\|[[:space:]]*=[[:space:]]*[0-9.eE+-]+' "${LOG}" 2>/dev/null | tail -n1 | sed -E 's/.*\|delta\|[[:space:]]*=[[:space:]]*([0-9.eE+-]+).*/\1/' || true)"
    [ -z "${DELTA_UHA}" ] && DELTA_UHA="n/a"

    # Tally.
    case "${VERDICT}" in
        PASS)
            N_PASS=$((N_PASS + 1))
            STATUS_DISPLAY="PASS"
            ;;
        FAIL)
            N_FAIL=$((N_FAIL + 1))
            STATUS_DISPLAY="FAIL"
            ;;
        EXTRACTION_PENDING)
            N_PENDING=$((N_PENDING + 1))
            STATUS_DISPLAY="PENDING"
            ;;
        *)
            N_ERR=$((N_ERR + 1))
            STATUS_DISPLAY="ERR(rc=${RC})"
            ;;
    esac

    printf '  [%-10s] %-12s as=%-5s  wall=%2ss  |Δ|=%-12s  %s\n' \
        "${STATUS_DISPLAY}" "${MID}" "${MAS}" "${WALL}" "${DELTA_UHA}" "${MPATH}"
    ROWS+=( "${MID}|${MAS}|${STATUS_DISPLAY}|${DELTA_UHA}|${WALL}" )

    # Emit marker.
    if [ "${EMIT_MARKERS}" -eq 1 ]; then
        MARKER_SUFFIX=""
        case "${STATUS_DISPLAY}" in
            PASS)    MARKER_SUFFIX="" ;;
            FAIL)    MARKER_SUFFIX="_FAILED" ;;
            PENDING) MARKER_SUFFIX="_PENDING" ;;
            *)       MARKER_SUFFIX="_FAILED" ;;
        esac
        MARKER_PATH="${MARKER_DIR}/bench_diatomic_${MID}_${MAS}_${TS_RUN}${MARKER_SUFFIX}.marker"
        # JSON payload mirroring the existing marker convention.
        printf '{"source":"%s","exit":%s,"verdict":"%s","delta_uHa":"%s","wall_s":%s,"ts":%s}\n' \
            "${MPATH}" "${RC}" "${STATUS_DISPLAY}" "${DELTA_UHA}" "${WALL}" "${TS_RUN}" \
            > "${MARKER_PATH}"
    fi

    rm -f "${LOG}"
done

# Summary table.
N_TOTAL=$((N_PASS + N_FAIL + N_PENDING + N_ERR + N_SKIP))
printf '\n=== SUMMARY ===\n'
printf '  %-12s %-6s %-10s %-14s %s\n' "id" "as" "verdict" "|delta|(uHa)" "wall(s)"
printf '  %-12s %-6s %-10s %-14s %s\n' "------------" "------" "----------" "--------------" "-------"
for row in "${ROWS[@]}"; do
    IFS='|' read -r RID RAS RVER RDELTA RWALL <<<"${row}"
    printf '  %-12s %-6s %-10s %-14s %s\n' "${RID}" "${RAS}" "${RVER}" "${RDELTA}" "${RWALL}"
done
printf '\n  PASS=%d  FAIL=%d  PENDING=%d  ERR=%d  SKIP=%d  total=%d\n' \
    "${N_PASS}" "${N_FAIL}" "${N_PENDING}" "${N_ERR}" "${N_SKIP}" "${N_TOTAL}"

# Sentinel for the overall harness.
if [ "${N_FAIL}" -gt 0 ] || [ "${N_ERR}" -gt 0 ]; then
    printf '__QMIRROR_BENCH_CHEM_VQE_DIATOMIC__ FAIL  pass=%d fail=%d pending=%d err=%d\n' \
        "${N_PASS}" "${N_FAIL}" "${N_PENDING}" "${N_ERR}"
    exit 1
fi

# Pending alone is not FAIL — it's a known offline-extraction gap.
printf '__QMIRROR_BENCH_CHEM_VQE_DIATOMIC__ PASS  pass=%d pending=%d\n' \
    "${N_PASS}" "${N_PENDING}"
