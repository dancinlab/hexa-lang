#!/usr/bin/env bash
# bench/extract/extract_4e4o_hamiltonian.sh
#
# OFFLINE / BUILD-TIME extraction driver for the chem-vqe-bench suite.
#
# AGENTS.md §1: qmirror runtime is pure-hexa (zero subprocess / zero python /
# zero qiskit at run time). This script is the SAME category as the H2 / LiH /
# CMT vendored-constants extraction in CHEMISTRY_VQE_PYSCF_BACKEND_PLAN_2026_05_12.md
# §3 option (c) — a one-shot dev-machine task that produces vendored .hexa
# Hamiltonian modules which are then committed. It is NOT executed by any
# selftest or by the bench harness, and the qmirror runtime never calls into
# Python.
#
# To preserve the "no .py file is committed" invariant the actual extraction
# code is embedded as a heredoc and written to a temp file at run time. The
# temp file is deleted on exit.
#
# Requires (DEV MACHINE ONLY, NOT the qmirror runtime — never installed in CI):
#   pip install pyscf==2.13.0 qiskit-nature==0.7.2 qiskit==1.0 \
#               qiskit-algorithms numpy scipy
#
# Usage:
#   bench/extract/extract_4e4o_hamiltonian.sh --molecule h2o
#   bench/extract/extract_4e4o_hamiltonian.sh --molecule beh2 \
#       --out chemistry_vqe/module/bench_4e4o_beh2.hexa
#   bench/extract/extract_4e4o_hamiltonian.sh --all-pending
#
# Pipeline (per molecule):
#   1. Read geometry + basis from bench/manifest.json molecule entry.
#   2. pyscf RHF → MO coefficients + core 1-RDM.
#   3. qiskit-nature PySCFDriver → ElectronicStructureProblem.
#   4. ActiveSpaceTransformer(num_electrons=4, num_spatial_orbitals=4).
#   5. ParityMapper((nα, nβ)) + 2-qubit reduction → 6-qubit qubit Hamiltonian.
#   6. UCCSDFactory + initial_point=zeros + SLSQP(maxiter=500, ftol=1e-9).
#   7. Capture converged statevector ψ* from UCCSD at theta*.
#   8. CASCI(4,4) reference = NumPyMinimumEigensolver on the AS qubit op.
#   9. Emit bench/module/bench_4e4o_<id>.hexa using the chemistry_vqe_cmt_4e4o_*
#      template (which uses chemistry_vqe_cmt_hamiltonians_4e4o_lib.hexa's
#      verdict driver).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MANIFEST="${REPO_ROOT}/bench/manifest.json"
OUTPUT_DIR="${REPO_ROOT}/bench/module"

if [ ! -f "${MANIFEST}" ]; then
    echo "[extract] missing manifest: ${MANIFEST}" >&2
    exit 2
fi
mkdir -p "${OUTPUT_DIR}"

# Parse args.
MOLECULE=""
ALL_PENDING=0
OUT=""
while [ $# -gt 0 ]; do
    case "$1" in
        --molecule) MOLECULE="$2"; shift 2 ;;
        --all-pending) ALL_PENDING=1; shift ;;
        --out) OUT="$2"; shift 2 ;;
        --help|-h)
            sed -n '2,40p' "$0"
            exit 0
            ;;
        *)
            echo "[extract] unknown flag: $1" >&2
            exit 2
            ;;
    esac
done

if [ -z "${MOLECULE}" ] && [ "${ALL_PENDING}" -eq 0 ]; then
    echo "[extract] specify --molecule <id> or --all-pending" >&2
    exit 2
fi

# Honest C3 (AGENTS.md raw_91 style): refuse to run if pyscf/qiskit-nature
# aren't importable. Don't silently degrade.
PY="${PYTHON:-python3}"
if ! "${PY}" -c "import pyscf, qiskit_nature, qiskit, qiskit_algorithms, numpy" 2>/dev/null; then
    cat >&2 <<EOF
[extract] missing offline-extraction dependencies. Install on the dev machine:
    pip install pyscf==2.13.0 qiskit-nature==0.7.2 qiskit==1.0 \\
                qiskit-algorithms numpy scipy
This script is OFFLINE / BUILD-TIME ONLY — the qmirror runtime stays pure hexa
(AGENTS.md §1).
EOF
    exit 3
fi

# Write the python pipeline to a temp file (kept out of repo per AGENTS.md §1).
WORK="$(mktemp -d -t qmirror-extract-XXXXXX)"
trap 'rm -rf "${WORK}"' EXIT
PYDRIVER="${WORK}/extract.py"

cat > "${PYDRIVER}" <<'PYEOF'
# Embedded extraction pipeline. Same body as the offline scratch used to
# produce chemistry_vqe_cmt_4e4o_lih_validation.hexa and the 5 CMT-4e/4o
# vendored modules.
import json, os, sys, time, argparse
from pathlib import Path

import numpy as np
from pyscf import gto, scf
from qiskit_nature.second_q.drivers import PySCFDriver
from qiskit_nature.units import DistanceUnit
from qiskit_nature.second_q.transformers import ActiveSpaceTransformer
from qiskit_nature.second_q.mappers import ParityMapper
from qiskit_nature.second_q.circuit.library import UCCSD, HartreeFock
from qiskit_algorithms import VQE, NumPyMinimumEigensolver
from qiskit_algorithms.optimizers import SLSQP
from qiskit.primitives import StatevectorEstimator as Estimator
from qiskit.quantum_info import Statevector

HEXA_TEMPLATE = '''#!hexa strict
// qmirror/bench/module/bench_4e4o_{id}.hexa
//
// chem-vqe-bench suite — 4e/4o vendored VQE replay for {name}.
// {formula} at {geometry_str}; basis={basis}; AS=(4,4); 6 qubits.
//
// Vendored data (offline-extracted {extracted_at} via pyscf+qiskit-nature):
//   - Hamiltonian: {n_pauli} Pauli terms on 6 qubits (ParityMapper((2,2)) + 2q reduction)
//   - constant_shift, CASCI(4,4) reference
//   - UCCSD-converged statevector psi-star (64 complex amps, SLSQP from zeros)
//
// CCSD(T) literature reference (sanity-check, NOT the direct comparator):
//   E = {ccsd_t_ref} Ha ({ccsd_t_kind})
//   source: {ccsd_t_source}
//
// @tool(slug="qmirror_bench_4e4o_{id}", desc="chem-vqe-bench 4e/4o vendored VQE replay for {name}.")
// @usage(hexa run qmirror/bench/module/bench_4e4o_{id}.hexa --selftest)
// @sentinel({sentinel} <PASS|FAIL>)

use "../../chemistry_vqe/module/chemistry_vqe_cmt_hamiltonians_4e4o_lib.hexa"

fn {id}_pauli_labels() -> [str] {{
    return [
{pauli_labels_block}
    ]
}}

fn {id}_pauli_coeffs() -> [float] {{
    return [
{pauli_coeffs_block}
    ]
}}

fn {id}_constant_shift() -> float {{ return {const_shift} }}
fn {id}_casci_ref() -> float {{ return {casci_ref} }}

fn {id}_psi_re() -> [float] {{
    return [
{psi_re_block}
    ]
}}

fn {id}_psi_im() -> [float] {{
    return [
{psi_im_block}
    ]
}}


fn main() {{
    println("[qmirror/bench] 4e/4o replay - {name}")
    let v = chemistry_vqe_native_run_named_4e4o(
        "{id}", "{geometry_str}",
        {id}_pauli_labels(), {id}_pauli_coeffs(),
        {id}_constant_shift(), {id}_casci_ref(),
        {id}_psi_re(), {id}_psi_im())
    let tag = if v.verdict == "PASS" {{ "  PASS" }} else {{ "  FAIL" }}
    println(tag + " " + v.molecule + "  " + v.verdict +
            "  n_qubits=" + str(v.n_qubits) + "  n_pauli=" + str(v.n_pauli_terms))
    println("      E_replay=" + str(v.energy_Ha) + " Ha   E_CASCI(4,4)=" + str(v.ref_energy_Ha) + " Ha")
    let abs_d = if v.delta_uHa < 0.0 {{ 0.0 - v.delta_uHa }} else {{ v.delta_uHa }}
    println("      |delta|=" + str(abs_d) + " uHa   wall=" + str(v.wall_seconds) + "s")
    println("      " + v.message)
    if v.verdict == "PASS" {{
        println("{sentinel} PASS")
        return
    }}
    println("{sentinel} FAIL")
}}
'''


def fmt_strs(items, per=6, ind=8):
    pad = " " * ind
    parts = []
    for i in range(0, len(items), per):
        c = items[i:i+per]
        parts.append(pad + ", ".join(f'"{s}"' for s in c))
    return ",\n".join(parts)


def fmt_floats(items, per=4, ind=8):
    pad = " " * ind
    parts = []
    for i in range(0, len(items), per):
        c = items[i:i+per]
        rendered = []
        for f in c:
            if f < 0:
                rendered.append(f"0.0 - {abs(f)!r}")
            else:
                rendered.append(repr(float(f)))
        parts.append(pad + ", ".join(rendered))
    return ",\n".join(parts)


def extract_one(mol, out_path):
    print(f"[extract] {mol['id']} ({mol['name']}) - pyscf/qiskit-nature pipeline ...")
    t0 = time.time()

    driver = PySCFDriver(atom=mol["geometry"], basis=mol["basis"],
                         charge=0, spin=0, unit=DistanceUnit.ANGSTROM)
    problem = driver.run()
    ast = ActiveSpaceTransformer(num_electrons=4, num_spatial_orbitals=4)
    problem_as = ast.transform(problem)

    hamiltonian = problem_as.hamiltonian.second_q_op()
    mapper = ParityMapper(num_particles=(2, 2))
    qubit_op = mapper.map(hamiltonian)
    # Sum ALL constants (nuclear_repulsion + ActiveSpaceTransformer frozen-core
    # electronic energy + any other transformer constants) so that
    # E_total = <ψ|H_qubit|ψ> + constant_shift is the FULL total energy in Ha,
    # not just the active-space contribution.
    constant_shift = float(sum(problem_as.hamiltonian.constants.values()))

    npme = NumPyMinimumEigensolver()
    res_ex = npme.compute_minimum_eigenvalue(qubit_op)
    casci_ref = float(np.real(res_ex.eigenvalue)) + constant_shift

    ansatz = UCCSD(
        problem_as.num_spatial_orbitals,
        problem_as.num_particles,
        mapper,
        initial_state=HartreeFock(
            problem_as.num_spatial_orbitals,
            problem_as.num_particles,
            mapper,
        ),
    )
    n_params = ansatz.num_parameters
    initial = np.zeros(n_params)
    optimizer = SLSQP(maxiter=500, ftol=1e-9)
    estimator = Estimator()
    vqe = VQE(estimator, ansatz, optimizer, initial_point=initial)
    res_v = vqe.compute_minimum_eigenvalue(qubit_op)
    theta_star = np.array(res_v.optimal_point)
    vqe_e = float(np.real(res_v.eigenvalue)) + constant_shift

    bound = ansatz.assign_parameters(theta_star)
    psi = np.asarray(Statevector.from_instruction(bound).data)
    assert psi.shape == (64,), f"expected 64-amp statevector; got {psi.shape}"

    labels, coeffs = [], []
    for p, c in qubit_op.to_list():
        labels.append(p)
        coeffs.append(float(np.real(c)))

    wall = time.time() - t0
    abs_delta_uha = abs(vqe_e - casci_ref) * 1e6
    print(f"[extract] {mol['id']} done in {wall:.1f}s  n_pauli={len(labels)}  "
          f"E_VQE={vqe_e:.9f}  E_CASCI={casci_ref:.9f}  |Δ|={abs_delta_uha:.3f} µHa")

    src = HEXA_TEMPLATE.format(
        id=mol["id"], name=mol["name"], formula=mol["formula"],
        geometry_str=mol["geometry"], basis=mol["basis"],
        n_pauli=len(labels), extracted_at=time.strftime("%Y-%m-%d"),
        ccsd_t_ref=mol["ccsd_t_reference_Ha"],
        ccsd_t_kind=mol["ccsd_t_reference_kind"],
        ccsd_t_source=mol["ccsd_t_source"],
        sentinel=mol["sentinel"],
        pauli_labels_block=fmt_strs(labels),
        pauli_coeffs_block=fmt_floats(coeffs),
        const_shift=(f"0.0 - {abs(constant_shift)!r}" if constant_shift < 0 else repr(constant_shift)),
        casci_ref=(f"0.0 - {abs(casci_ref)!r}" if casci_ref < 0 else repr(casci_ref)),
        psi_re_block=fmt_floats([float(x) for x in psi.real]),
        psi_im_block=fmt_floats([float(x) for x in psi.imag]),
    )
    out_path.write_text(src)
    print(f"[extract] {mol['id']} wrote {out_path}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--manifest", required=True)
    ap.add_argument("--molecule", default="")
    ap.add_argument("--all-pending", action="store_true")
    ap.add_argument("--out", default="")
    ap.add_argument("--output-dir", required=True)
    args = ap.parse_args()

    with open(args.manifest) as f:
        manifest = json.load(f)
    by_id = {m["id"]: m for m in manifest["molecules"]}

    if args.all_pending:
        ids = manifest["summary"]["extraction_pending_ids"]
    else:
        ids = [args.molecule]

    out_dir = Path(args.output_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    for mid in ids:
        if mid not in by_id:
            print(f"[extract] unknown molecule id={mid!r}", file=sys.stderr); sys.exit(2)
        mol = by_id[mid]
        if mol["status"] != "EXTRACTION_PENDING":
            print(f"[extract] {mid} status={mol['status']!r} - skipping")
            continue
        out_path = Path(args.out) if args.out else out_dir / f"bench_4e4o_{mid}.hexa"
        extract_one(mol, out_path)


if __name__ == "__main__":
    main()
PYEOF

# Dispatch.
ARGS=( --manifest "${MANIFEST}" --output-dir "${OUTPUT_DIR}" )
if [ "${ALL_PENDING}" -eq 1 ]; then
    ARGS+=( --all-pending )
elif [ -n "${MOLECULE}" ]; then
    ARGS+=( --molecule "${MOLECULE}" )
fi
if [ -n "${OUT}" ]; then
    ARGS+=( --out "${OUT}" )
fi

"${PY}" "${PYDRIVER}" "${ARGS[@]}"
