<p align="center">🪞 <strong>stdlib/quantum</strong></p>

<p align="center"><strong>Quantum Mirror</strong> — laptop-grade ≤30-qubit drop-in substrate · pure-hexa Aer-compatible state-vector kernel · 38 module dirs · 27 algorithm subcommands</p>

<p align="center">
  <img alt="RFC" src="https://img.shields.io/badge/RFC-045-success">
  <img alt="Modules" src="https://img.shields.io/badge/modules-38-informational">
  <img alt="LoC" src="https://img.shields.io/badge/LoC-62402-informational">
  <a href="https://doi.org/10.5281/zenodo.20102964"><img alt="DOI" src="https://zenodo.org/badge/DOI/10.5281/zenodo.20102964.svg"></a>
</p>

<p align="center">CHSH · IIT-4.0-phi-star · Aer-compat state-vector · stabilizer · tomography · 27 algorithms · hexa-strict</p>

---

`stdlib/quantum` is a **laptop-grade drop-in replacement for IBM Cloud / Braket
QPU rental** for the ≤30-qubit, low-noise envelope where statistical
equivalence with a real QPU is achievable on commodity CPUs. The analogy: a
Rolex and a Casio both tell time accurately — qmirror is the Casio. $0/run vs
IBM Cloud's $1.60/job.

**Origin:** RFC 045 absorbed [`dancinlab/qmirror`](https://github.com/dancinlab/qmirror)
v2.0 (62,402 LoC, 38 module directories — private 2026-05-16) into hexa-lang's
stdlib. The original SSOT is frozen at `~/core/archive_qmirror/` (헌법 v2 룰 3).

> [!NOTE]
> Third of the dancinlab quantum-stack absorption series:
> RFC 044 ([`qrng`](../qrng/) ✅) · RFC 045 (this) · RFC 046 ([`sim_universe`](../sim_universe/) ✅).
> `stdlib/quantum/qrng/` here is the **consumer-side HMAC-DRBG amplifier** —
> distinct from `stdlib/qrng/` (the RFC 044 provider registry). Zero code
> overlap; provider/consumer boundary deliberate.

## Run via hexa CLI

```sh
hexa qmirror                              # status (module inventory)
hexa qmirror status                       # module inventory + tier table
hexa qmirror selftest                     # closure verdict sweep
hexa qmirror chsh                         # CHSH Bell test (Tsirelson-class S)
hexa qmirror iit                          # IIT 4.0 phi-star integrated information
hexa qmirror <algorithm>                  # 27 algorithm subcommands (see below)
hexa qmirror --help                       # full subcommand reference
```

## Core

| Module | LoC | Role |
|---|---:|---|
| `engine_aer` | 2,170 | Aer-compatible pure-hexa state-vector kernel + QASM3 lex/parse/oracle + gates |
| `circuit` | — | gate-circuit construction |
| `sampler` | — | Born-rule sampling with provenance |
| `stabilizer` | — | Gottesman-Knill stabilizer formalism |
| `entropy` | — | NIST tier-1+ entropy |
| `qrng` | — | ANU QRNG **consumer-side** HMAC-DRBG amplifier |
| `chsh` | — | CHSH Bell test (Tsirelson-class S statistic) |
| `iit_mip` / `phi` | — | IIT 4.0 phi-star integrated information |
| `tomography` / `process_tomography` | — | state + process tomography |
| `cscs` | — | classical-shadow circuit sampling |
| `selftest` | — | closure verdict sweep |

## Algorithm subcommands (27)

Each algorithm module is `@D`-governed against a published reference:

| Subcommand | Reference |
|---|---|
| `rqaoa` recursive QAOA MaxCut | arXiv:2408.13207 |
| `ctx` contextuality (Peres-Mermin) | arXiv:2505.21243 |
| `dynghz` dynamic-circuit GHZ | arXiv:2308.13065 |
| `vqd` VQD excited closed-shell | arXiv:2502.17932 |
| `stab-ext` stabilizer extent | arXiv:2406.16673 |
| `overlap-vqe` overlap-ADAPT-VQE | arXiv:2301.10196 |
| `sre` magic / stabilizer Renyi entropy | arXiv:2106.12587 |
| `lg` Leggett-Garg superunitary | arXiv:2411.02301 |
| `pseudo-tel` pseudo-telepathy doily | Mermin 1990 + arXiv:2509.18033 |
| `rpe` robust phase-estimation gate calib | arXiv:1502.02677 + 2502.06698 |
| `sym-shadow` symmetry-adjusted shadows | arXiv:2002.08953 + 2310.03071 |
| `hardy` Hardy multipartite nonlocality | Hardy 1993 PRL 71 1665 + arXiv:2505.10170 |
| `page-curve` Page-curve scrambler | Page 1993 PRL 71 1291 + arXiv:2412.15180 |
| `qdrift` qDRIFT Hamiltonian sim | Campbell PRL 123 070503 2019 / arXiv:1811.08017 |
| `cdr` Clifford data regression | Czarnik 2021 Quantum 5 592 / arXiv:2005.10189 |
| `wigner` discrete Wigner negativity | Veitch 2014 NJP 16 013009 + Howard-Campbell 2017 |
| `qfi` QFI spin-motion | arXiv:2411.10117 |
| `shallow` shallow shadows | Bertoni 2024 / arXiv:2209.12924 |
| `gme-steer` GME steering (minimal) | Sarkar 2026 / arXiv:2402.18522 |
| `mabk` MABK-Ardehali inequality | Mermin 1990 + Werner-Wolf 2001 + Abiuso 2025 |
| `mirror-bench` mirror-fidelity benchmark | Proctor 2022 / arXiv:2008.11294 |

Plus `magic-stabilizer-renyi`, `stabilizer-extent`, `contextuality-peres-mermin`,
`leggett-garg-superunitary`, `dynamic-circuit-ghz`, `recursive-qaoa-maxcut` etc.
as standalone module dirs.

## Applications

| Module | LoC | Role |
|---|---:|---|
| `chemistry_vqe` | 29,603 | VQE chemistry suite — per-molecule CMT hamiltonians (4e4o/4e5o/4e6o active spaces), kuPCCGSD ansatz + L-BFGS-B driver, 59 files |
| `bench` | 1,009 | per-molecule 4e4o benchmarks (BeH2, CO, H2O, NH3, CH4, N2) |
| `surface_code_d3` | — | distance-3 surface code |

## Architecture notes

- **Modules are standalone programs** — each has `main()` + `__QMIRROR_*__` sentinel.
  Dispatched via subprocess (`hexa run stdlib/quantum/<feature>/module/<file>.hexa`).
- **Relative imports preserved** — `chemistry_vqe` + `bench` use `./` and
  `../../<feature>/module/` relative imports. The `<feature>/module/` directory
  structure is preserved verbatim under `stdlib/quantum/` so all relative
  imports resolve unchanged (no rewrite needed).
- **Aer-compatible kernel** — `engine_aer` numerically matches Qiskit Aer
  `method='statevector'` on the A5 gate-set `{H,X,Y,Z,S,T,Sdg,Tdg,RX,RY,RZ,CX,CZ,SWAP,U3}`.

## Governance

| ID | Rule |
|---|---|
| `@D g_qmirror_envelope` | qmirror is a ≤30-qubit low-noise statistical-equivalence substrate — NOT a universal QPU replacement. Honest analogy: Casio vs Rolex. |
| `@D g_qmirror_consumer_qrng` | `stdlib/quantum/qrng/` is the consumer-side HMAC-DRBG amplifier; `stdlib/qrng/` (RFC 044) is the provider. Zero code overlap. |
| `@F f_qmirror_real_qpu_claim` | Forbidden — claiming qmirror IS a real QPU or equivalent beyond the ≤30-qubit low-noise envelope. |
| `@X x_archive_qmirror` | `~/core/archive_qmirror/` frozen 묘비 (Zenodo DOI 10.5281/zenodo.20102964) |

Full entries in `AGENTS.tape` §0 (`@N qmirror_stack`) + §3-5.

## Layout

```
stdlib/quantum/
├── README.md                              # this file
├── quantum.hexa                           # CLI dispatcher (hexa qmirror target)
├── engine_aer/module/                     # state-vector kernel + QASM3
├── circuit/module/ · sampler/module/ · stabilizer/module/
├── entropy/module/ · qrng/module/ · selftest/module/
├── chsh/module/ · iit_mip/module/ · phi/module/
├── tomography/module/ · process_tomography/module/ · cscs/module/
├── <27 algorithm dirs>/module/<algorithm>.hexa
├── chemistry_vqe/module/                  # 59 files, 29.6k LoC VQE suite
├── bench/module/                          # per-molecule benchmarks
└── surface_code_d3/module/

~/core/archive_qmirror/                     # frozen 묘비 (RFC 045, read-only)
└── (full v2.0 metadata + cli + 38 module dirs preserved verbatim)
```

## RFC chain

- **RFC 044** — qrng absorption ✅ LANDED 2026-05-16
- **RFC 045** (this) — qmirror absorption ✅ LANDED 2026-05-16
- **RFC 046** — sim-universe absorption ✅ LANDED 2026-05-16

dancinlab quantum-stack absorption series COMPLETE.
