<p align="center">🔗 <strong>stdlib/mc_integrate</strong></p>

<p align="center"><strong>Monte Carlo numerical integrator</strong> — deterministic LCG core · ANU quantum-RNG seed · Welch-t indistinguishability gate · zero runtime deps</p>

<p align="center">
  <img alt="RFC" src="https://img.shields.io/badge/RFC-047-success">
  <img alt="Constants" src="https://img.shields.io/badge/named%20constants-4-informational">
  <img alt="Gate" src="https://img.shields.io/badge/gate-Welch--t%20df--aware-informational">
  <img alt="License" src="https://img.shields.io/badge/license-Apache--2.0-blue">
</p>

<p align="center">Monte-Carlo · LCG · ANU-QRNG · Welch-t · Catalan · Apéry · Euler–Mascheroni · hexa-only</p>

---

`stdlib/mc_integrate` is the **verification face** of the qrng/qmirror/mc-integrate
triplet: `stdlib/qrng` + the `qmirror` hw-probe **produce** quantum bits;
`stdlib/mc_integrate`'s `compare_rng()` Welch-t gate **decides** whether those
bits are numerically indistinguishable from a classical CSPRNG (`/dev/urandom`)
on a given integrand — i.e. whether the upstream quantum entropy is doing any
real work in your Monte Carlo integral.

Absorbed from `dancinlab/mc-integrate` v1.0.0 per **RFC 047**. The original
standalone repo is frozen at `~/core/archive_mc-integrate/` and the GitHub repo
renamed to `dancinlab/archive_mc-integrate`.

## Layout

```
stdlib/mc_integrate/
├── README.md            this file
├── mc_integrate.hexa    CLI dispatcher — `hexa mc-integrate` entrypoint
└── engine.hexa          computational engine (standalone program, 1,263 LoC)
                         estimate_constant() · compare_rng() · _self_test()
```

The dispatcher subprocess-invokes `engine.hexa` (sim-universe `_run_module`
pattern) so the engine's standalone semantics + `__MC_INTEGRATE__` sentinel
output are preserved verbatim.

## CLI

```sh
hexa mc-integrate                                       # full self-test sweep (default)
hexa mc-integrate estimate --constant catalan -N 100000 --rng urandom
hexa mc-integrate estimate --constant zeta3 -N 1000000 --rng external
hexa mc-integrate compare --compare catalan -N 50000 --trials 6 --rng-a anu --rng-b urandom
hexa mc-integrate self-test                             # F2-F5 + G1-G6 + H1-H3 falsifiers
hexa mc-integrate status                                # offline ANU-tier resolution probe
hexa mc-integrate chain                                 # 3-stage wire-up resolution
hexa mc-integrate probe-anu                             # live ANU tier probe (uses quota)
hexa mc-integrate --help, -h
hexa mc-integrate --version, -v
```

### Named constants

| name           | value                          | note                             |
|----------------|--------------------------------|----------------------------------|
| `catalan`      | Catalan's constant G ≈ 0.91597 | ∫ arctan series                  |
| `zeta3`        | Apéry's constant ζ(3) ≈ 1.20206 | 3-D integral (O(3·n_samples))     |
| `euler_gamma`  | Euler–Mascheroni γ ≈ 0.57722   |                                  |
| `pi5_times_n6` | π⁵×6                           | BT-209 m_p/m_e identity reference |

### RNG selectors (`--rng` / `--rng-a` / `--rng-b`)

| selector     | resolution                                                  |
|--------------|-------------------------------------------------------------|
| `external`   | `stdlib/qrng` collect → engine inline 3-tier ANU → urandom   |
| `wire`       | alias for `external`                                        |
| `anu`        | inline 3-tier: ANU paid → free → legacy → urandom → fixed    |
| `anu_paid`   | `ANU_KEY_PAID` only, then urandom → fixed                   |
| `anu_free`   | `ANU_KEY_FREE` only, then urandom → fixed                   |
| `anu_legacy` | keyless legacy only, then urandom → fixed                   |
| `urandom`    | `/dev/urandom` only, then fixed                             |

Secrets resolve through: `secret` CLI → 1Password (`op`) → macOS Keychain →
AWS Secrets Manager → `printenv` — values are never printed by `status`.

## Gates

- **estimate** — `PASS` if `abs_err < 1e-3`, `NEAR` if `abs_err < 5e-3`, `FAIL` otherwise.
- **compare** — `compare_rng()` Welch-t indistinguishability at α=0.05 two-tailed,
  using a df-aware critical-t lookup table (NIST/SEMATECH §1.3.6.7.2; Bevington &
  Robinson Table C.2; linear interp for non-integer Welch–Satterthwaite df) plus a
  Wilson–Hilferty t→z p-value approximation (~1e-3 absolute error in the p-tail
  for df ≥ 4; degrades for df < 4 — explicitly flagged as approximation, not exact CDF).

## Programmatic use

`engine.hexa` is a standalone program; its public API (verbatim from upstream):

```hexa
fn estimate_constant(name: string, n_samples: int, rng: string) -> map
//   map = {value, abs_err, rel_err, runtime_s, gate, samples, rng_used, name, analytical}

fn compare_rng(name: string, n_samples: int, n_trials: int, rng_a: string, rng_b: string) -> map
//   map = {anu_mean, anu_std, urandom_mean, urandom_std, t_stat, df, t_crit, p_value, indistinguishable}
```

## Honest scope

- `external` mode applies to `estimate` (single seed). `compare` runs N trials each
  with fresh bits, so it bypasses the wire-up and uses the engine's own per-call RNG.
- `probe-anu` hits real ANU servers and counts against your quota; `status` and
  `chain` do not (resolvability + curl/urandom presence only).
- The LCG is Numerical Recipes (`s = 1664525·s + 1013904223 mod 2³¹−1`); the
  `2³¹−1` modulus is a Mersenne prime, keeping the stream period at a prime floor.

RFC 047 · archive: `~/core/archive_mc-integrate/`
