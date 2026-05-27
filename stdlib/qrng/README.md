<p align="center">🎲 <strong>stdlib/qrng</strong></p>

<p align="center"><strong>Quantum RNG</strong> — 9-source provider registry · CURBy + ANU + NIST Beacon + hardware + 4 T2 cloud stubs · NIST SP 800-22 tier-1+ audit</p>

<p align="center">
  <img alt="RFC" src="https://img.shields.io/badge/RFC-044-success">
  <img alt="Backends" src="https://img.shields.io/badge/backends-9%20(T0..T3)-informational">
  <img alt="Audit" src="https://img.shields.io/badge/audit-NIST%20SP%20800--22%20tier--1%2B-informational">
  <a href="https://doi.org/10.5281/zenodo.20102966"><img alt="DOI" src="https://zenodo.org/badge/DOI/10.5281/zenodo.20102966.svg"></a>
</p>

<p align="center">quantum · entropy · CURBy · ANU · NIST Beacon · hardware QRNG · NIST SP 800-22 · audit · provider registry</p>

---

`stdlib/qrng` is a **provider-side** registry of quantum random byte sources.
It does **not** itself amplify entropy (no HMAC-DRBG, no NIST SP 800-90A
constructions — those belong to consumer packages per `@D g_qrng_provider_only`).
It returns raw bytes from one of 9 backends with a uniform `QrngBytes` struct
+ provenance message.

**Origin:** RFC 044 absorbed [`dancinlab/qrng`](https://github.com/dancinlab/qrng)
v1.0.0 into hexa-lang's stdlib. The original SSOT is frozen as the
`dancinlab/qrng` GitHub **private** repo (헌법 v2 룰 3). The local
`~/core/archive_qrng/` was retired 2026-05-17 — GitHub private repo is the
preservation SSOT; working-tree state is absorbed here in `stdlib/qrng/`.

> [!NOTE]
> Sister package of [`qmirror`](https://github.com/dancinlab/qmirror) (quantum
> mirror substrate · consumer-side HMAC-DRBG amplifier — RFC 045 follow-up
> absorption), member of the dancinlab HEXA family. Provider/consumer boundary
> deliberate — zero code overlap, struct-shape compatible.

## At a glance

```hexa
use "stdlib/qrng/audit"

let r = qrng_audited_bytes(1024, "tier1+", "anu_legacy")
// r.ok                       : 0/1
// r.bytes_hex                : hex string
// r.audit_pass               : 0/1 (1 iff every non-skipped test passed)
// r.tests_run                : [AuditTestResult] — 5 entries
// r.audit_level_requested    : "tier1+" | "none"
// r.audit_level_delivered    : "tier1+" | "tier1-partial" | "tier1-none" | "none"
// r.tier                     : "T0" | "T1" | "T3" | ...
// r.vendor                   : resolved backend label
// r.alpha                    : 0.01 (NIST default)
// r.message                  : provenance string
```

Nine backends shipped:

| Tier | Name | Vendor | is_quantum | is_local | Cost | Throughput | Status |
|------|------|--------|-----------:|---------:|------|------------|--------|
| T0 | `mock_qrng` | deterministic LCG | 0 | 1 | $0 | 1 GB/s | IMPLEMENTED |
| T1 | `curby` | NIST + CU Boulder (Bell-test) | 1 | 0 | $0 | 8.5 bps | IMPLEMENTED |
| T1 | `anu` | qrng.anu.edu.au | 1 | 0 | $0 | 1 KB/s | IMPLEMENTED |
| T1 | `nist_beacon` | NIST (ECDSA-signed mixed entropy) | 0 | 0 | $0 | 8.5 bps | IMPLEMENTED |
| T2.a | `ibm_quantum` | IBM Heron/Eagle/Falcon | 1 | 0 | $0 (Open Plan) | 1 KB/s | STUB_CREDENTIALED |
| T2.b | `ionq` | IonQ Forte 1 (trapped-ion) | 1 | 0 | PAYG | 100 bps | STUB_CREDENTIALED |
| T2.c | `rigetti` | Rigetti Cepheus/Aspen | 1 | 0 | PAYG | 100 bps | STUB_CREDENTIALED |
| T2.d | `braket` | AWS Braket aggregator | 1 | 0 | PAYG | 100 bps | STUB_CREDENTIALED |
| T3 | `hardware_qrng` | IDQ Quantis PCIe / ESP32 serial | 1 | 1 | $5000/$10 | 240 MB/s | IMPLEMENTED |

> **Honest C3 note** (`@D g_qrng_honest_vendor`): `nist_beacon` is
> `is_quantum=0` because it's vendor-classified as **mixed entropy** (HSM +
> RNGs, possibly QRNG-augmented). `hardware_qrng` is `is_quantum=1` by
> **vendor assertion** (IDQ NIST SP 800-90B health checks + ESP32 ADC noise)
> — independent NIST validation NOT performed by this package.

## Run via hexa CLI

```sh
hexa qrng                                            # selftest aggregate (9-backend table + tier coverage)
hexa qrng status                                     # registry table + tier coverage
hexa qrng collect [--bytes=N] [--seed=S] [--source=NAME]
hexa qrng selftest                                   # full provider sweep sentinels
hexa qrng chain                                      # show resolved router fallback chain
hexa qrng meta --backend=NAME                        # print backend metadata
hexa qrng --help                                     # full usage
```

Programmatic use from another stdlib file:

```hexa
use "stdlib/qrng/source"             // QrngBytes, QrngSourceMeta + helpers
use "stdlib/qrng/backends/anu"       // qrng_source_collect_anu, qrng_anu_*
use "stdlib/qrng/backends/mock_qrng" // qrng_source_collect_mock_qrng
use "stdlib/qrng/registry"           // qrng_registry_collect dispatch
use "stdlib/qrng/router"             // qrng_route_collect fallback chain
use "stdlib/qrng/audit"              // qrng_audited_bytes single-stage
```

## Registered backends

### `curby` — Bell-test verified (NIST + CU Boulder)

Twine-blockchain anchored Bell-inequality-violation pulses (loophole-free
Bell test protocol). Free, no auth, **8.5 bps sustained** (512 bits per
60-second pulse). `twine_anchor` field MUST be non-empty on live pulses
(falsifier `F_CURBY_03`).

```sh
QRNG_LIVE=1 hexa qrng collect --source=curby --bytes=64
```

### `anu` — vacuum-fluctuation photodetector (Australian National University)

Public REST (`https://qrng.anu.edu.au/API/jsonI.php`) sampling quantum
vacuum fluctuations. Free legacy tier 1 req/min; chunks > 1024 bytes
require pacing. Legacy stdlib API `qrng_anu_uint8/_live/_chunked/...`
preserved for anima sister-repo compat.

```sh
QRNG_LIVE=1 hexa qrng collect --source=anu --bytes=128
```

### `nist_beacon` — Beacon 2.0 (ECDSA P-384 signed pulses)

NIST Randomness Beacon 2.0 (`beacon.nist.gov/beacon/2.0/pulse/last`).
Mixed-entropy composite (HSM + RNG, possibly QRNG-augmented — vendor
self-classifies). US sovereignty mirror to ANU. ECDSA signature MUST be
present (`F_NIST_03`).

### `hardware_qrng` — local PCIe/USB-serial

Probes `/dev/quantis*` (IDQ Quantis PCIe/USB SDK), then
`/dev/cu.usbmodem*` / `/dev/cu.usbserial*` (ESP32 / FTDI bridges). Live
path requires `QRNG_HW_LIVE=1`; default is mock-mode.

### `mock_qrng` — deterministic LCG

`s = (1664525 × s + 1013904223) mod 2^32`. Same `--seed` → same bytes
byte-identical across runs. CI default; safety net for the router chain.

### T2 cloud-quantum stubs (`ibm_quantum` / `ionq` / `rigetti` / `braket`)

Meta + secret-chain only. Live extraction deferred to consumer-side
adapters (qiskit-ibm-runtime / qiskit-ionq / pyquil / amazon-braket-sdk).
Each fails fast with the secret name when credentials are missing.

## Integrated audit — `qrng_audited_bytes()`

Single-stage API that **pulls entropy + runs NIST SP 800-22 tier-1+
statistical audit + returns ok/fail in one call** (Boltz-2 paradigm).
Eliminates the "did the caller actually audit?" failure mode.

Five tests (NIST SP 800-22 §2.1, §2.2, §2.3, §2.4, §2.6):

| Test               | Min bits | Notes |
|--------------------|---------:|-------|
| monobit            |      100 | frequency / proportion of ones |
| frequency_block    |     2560 | M=128 N>=20; chi-square upper tail |
| runs               |      100 | gated by monobit pre-check |
| longest_run        |     6272 | M=128 K=5 N=49 |
| dft_spectral       |     1000 | O(n²) DFT, capped at 1024 bits |

Audit downgrade is automatic and labelled: a 64-byte (512-bit) pull with
`audit_level="tier1+"` returns `audit_level_delivered="tier1-partial"` with
`monobit` + `runs` running and the other three tests `skipped`. `audit_pass`
aggregates only the tests that actually ran (alpha=0.01).

```sh
hexa run stdlib/qrng/audit.hexa
QRNG_LIVE=1 hexa run stdlib/qrng/audit.hexa
```

Selftest evidence:
- pathological all-zeros: audit FAIL (monobit p ≈ 0; **distinction proof**)
- mock LCG (n=128 bytes = 1024 bits): audit PASS (3/5 tests run)
- ANU legacy live (n=64 bytes): audit PASS (monobit + runs run)

## Boundary: `stdlib/qrng` (provider) vs `qmirror.qrng` (consumer drop-in)

Dual-home pattern (see `@D g_qrng_provider_only`). **Zero code overlap**, but
struct shapes are compatible by convention.

| Surface | Role |
|---|---|
| `stdlib/qrng/backends/{anu,curby,nist_beacon,mock_qrng,hardware_qrng,cloud/*}` + abstraction `{source,registry,router,qrng_main,audit}` | **Provider registry** — 9 backends + dispatch + router + audit |
| `qmirror/modules/qrng.hexa` (RFC 045 follow-up absorption) | **Consumer drop-in** — HMAC-DRBG amplifier |

Sentinel namespaces disjoint (`__QRNG_*` vs `__QMIRROR_QRNG__`); env namespaces
disjoint (`QRNG_*` / `NEXUS_QRNG_*` vs `QMIRROR_*`). Full rationale in
`dancinlab/qrng` (GitHub private) `docs/dual_home_boundary.md`.

## Architecture — abstraction + 9-backend split

Router default chain `curby → anu → nist_beacon → ibm_quantum → ionq → rigetti
→ braket → hardware_qrng → mock_qrng` is overridable via env:

- `QRNG_SOURCE=<name>` — pin to single backend
- `QRNG_FALLBACK_CHAIN=a,b,c` — comma-sep custom chain

Both legacy (`NEXUS_QRNG_*`) and forward (`QRNG_*`) env namespaces are
honoured; legacy is load-bearing for backward compat.

Router preserves tier/vendor/message in `RouterResult.attempts/reasons` —
silent mock downgrade forbidden by `@F f_qrng_silent_mock_downgrade`.

## Env vars

```
QRNG_LIVE             1 → enable live network paths (default: gated mock)
QRNG_MOCK             1 → force mock LCG fixture (CI-safe)
QRNG_SOURCE           pin to single backend (skips fallback chain)
QRNG_FALLBACK_CHAIN   comma-sep custom fallback chain
QRNG_HW_LIVE          1 → hardware_qrng live serial/PCIe path
QRNG_HW_MOCK          1 → hardware_qrng mock fixture
QRNG_HW_TIMEOUT_S     serial read timeout in seconds (default 5)

T2 cloud-quantum vendor secrets (NEXUS_QRNG_LIVE=1 + secret to enable):
  IBM_QUANTUM_TOKEN / IBMQ_TOKEN          ibm_quantum (T2.a)
  IONQ_API_KEY                            ionq (T2.b)
  QCS_API_KEY / QCS_SETTINGS / ~/.qcs     rigetti (T2.c)
  AWS_ACCESS_KEY_ID + AWS_SECRET_ACCESS_KEY
  or AWS_PROFILE / ~/.aws/credentials     braket (T2.d)

legacy aliases (load-bearing for backward compat):
  NEXUS_QRNG_LIVE / NEXUS_QRNG_MOCK / NEXUS_QRNG_SOURCE
  NEXUS_QRNG_FALLBACK_CHAIN / NEXUS_QRNG_HW_*
  ANIMA_QRNG_MOCK   (anima-side consumer alias)
```

## Layout

```
stdlib/qrng/
├── README.md                          # this file
├── source.hexa                        # struct shapes + helpers (QrngBytes, QrngSourceMeta)
├── audit.hexa                         # NIST SP 800-22 tier-1+ (5 tests)
├── registry.hexa                      # 9-backend metadata dispatch
├── router.hexa                        # env-driven fallback chain
├── qrng_main.hexa                     # aggregator + tier coverage
├── qrng.hexa                          # runnable entrypoint (hexa CLI dispatch target)
├── backends/
│   ├── anu.hexa                       # T1 ANU vacuum-fluctuation (+ legacy qrng_anu_* compat API)
│   ├── curby.hexa                     # T1 NIST + CU Boulder Bell-test
│   ├── nist_beacon.hexa               # T1 NIST Beacon 2.0 ECDSA
│   ├── mock_qrng.hexa                 # T0 deterministic LCG
│   ├── hardware_qrng.hexa             # T3 IDQ Quantis / ESP32 serial
│   └── cloud/
│       ├── ibm_quantum.hexa           # T2.a STUB_CREDENTIALED
│       ├── ionq.hexa                  # T2.b STUB_CREDENTIALED
│       ├── rigetti.hexa               # T2.c STUB_CREDENTIALED
│       └── braket.hexa                # T2.d STUB_CREDENTIALED
└── fixtures/
    ├── curby_pulse_sample.json        # CURBy mock fixture
    └── nist_beacon_pulse_sample.json  # NIST Beacon mock fixture

stdlib/test/
├── test_qrng_source.hexa              # struct shapes
├── test_qrng_mock.hexa                # mock_qrng determinism
├── test_qrng_anu.hexa                 # anu (26 cases — legacy + new API)
├── test_qrng_curby.hexa
├── test_qrng_nist_beacon.hexa
├── test_qrng_hardware.hexa
├── test_qrng_cloud_stubs.hexa         # 4 T2 stubs
├── test_qrng_registry.hexa            # 9-backend dispatch
├── test_qrng_router.hexa              # default chain + fallback
└── test_qrng_audit.hexa               # NIST SP 800-22 (3-4 min DFT wall)

github.com/dancinlab/qrng (private)     # frozen 묘비 (RFC 044)
└── (full v1.0.0 repo verbatim — local ~/core/archive_qrng/ retired 2026-05-17)
```

## Governance

| ID | Rule |
|---|---|
| `@D g_qrng_audit_required` | T1/T3 entropy paths MUST be exercisable through `qrng_audited_bytes()` |
| `@D g_qrng_honest_vendor` | `is_quantum` flag follows vendor self-classification; honest-caveat in meta |
| `@D g_qrng_provider_only` | No HMAC-DRBG / NIST SP 800-90A in stdlib/qrng (amplification is consumer concern) |
| `@F f_qrng_silent_mock_downgrade` | Router must preserve tier/vendor/message; silent fallback to T0 forbidden |
| `@X x_archive_qrng` | `dancinlab/qrng` GitHub private 묘비 (Zenodo DOI 10.5281/zenodo.20102966) |

Full entries in `AGENTS.tape` §0 (`@N qrng_stack`) + §3-5.

## Caveats

1. **Dual-home boundary risk** with `qmirror.qrng` — see Boundary section.
2. **6 external consumers** (anima/anima-physics/anima-eeg) refactor staged; `qrng_anu_*` legacy API preserved for anima compat.
3. **Tests scaffolded fresh** at extraction — coverage tier 1 (sentinel per backend); deeper property-based tests deferred.
4. **ANU rate-limit + ToS evolution** — public REST throttled to 1 req/min on T1.a legacy tier.
5. **License audit deferred** — qrng core is Apache-2.0; per-vendor data-rights for ANU/CURBy/NIST Beacon byte redistribution NOT formally audited. This package returns bytes; does not redistribute.
6. **CLI deferred** — original `cli/qrng.hexa` (580 LoC, subprocess+sentinel pattern) frozen in the `dancinlab/qrng` GitHub private repo at `cli/qrng.hexa`. RFC 044-B follow-up writes a thin library-wrapper CLI replacing subprocess pattern.

## RFC chain

- **RFC 044** (this) — qrng absorption (LANDED 2026-05-16)
- **RFC 044-B** — thin library-wrapper CLI replacing subprocess pattern
- **RFC 045** — qmirror absorption (pending; qmirror upgrade in flight)
- **RFC 046** — sim-universe absorption (scaffold in progress)
