# inbox: LPA IVW MR formula — atlas extension request

**date:** 2026-05-24
**source:** demiurge LPA V2 (`LPA/verify/V2_formal_identities.md`)
**kind:** atlas extension request (biostat calculator gap)

## context

LPA domain V2 (🔵 SUPPORTED-FORMAL push) ran `hexa verify --expr` on 5 biostat
identities targeted for closed-form atlas registration:

| fn | claim | verdict |
|---|---|---|
| `ivw` | Burgess 2018 LPA IVW β=-0.342490 | 🟠 INSUFFICIENT (no calc path) |
| `schoenfeld` | HORIZON D=920 events (HR 0.85, α=0.05, β=0.20) | 🟠 INSUFFICIENT |
| `binary_sample` | HORIZON n=8,323 (Snedecor-Cochran) | 🟠 INSUFFICIENT |
| `nnt` | ARR 0.04 → NNT 25 | 🟠 INSUFFICIENT |
| `arr_to_nnt` | (alias) | 🟠 INSUFFICIENT |

Only number-theory calc fns (`sigma|sigma_0|phi|mu|tau|jacobi|kronecker|dim_cusp_forms`)
are wired in `tool/verify_cli.hexa::_recompute`. Cross-domain demand is high:
LPA, DAPTPGX, NOREFLOW, HERPES all need biostat closed-forms.

## request

Extend `tool/verify_cli.hexa::_recompute` (and mirror in `tool/atlas_cli.hexa::
_recompute_register`) to dispatch the following biostat closed-forms:

### F1 — IVW estimator (Burgess 2018)

```
β_xy = Σ(β_xi · β_yi / σ_yi²) / Σ(β_xi² / σ_yi²)
SE   = 1 / sqrt(Σ(β_xi² / σ_yi²))
HR   = exp(β_xy)
```

Example (Burgess 2018 LPA → CHD, 3 instruments, n=72,869):
β=-0.342490, SE=0.028774, Z=-11.90, HR=0.71 (95% CI 0.67-0.75).

### F2 — Schoenfeld events (1-sided log-rank power)

```
D = (Z_{α/2} + Z_β)² / (ln(HR))² · 4 / (P₁ + P₂)   (balanced arms: ·4)
```

Example (HORIZON Lp4263P): HR=0.85, α=0.05, β=0.20 → D≈920 anticipated.

### F3 — binary sample size (Snedecor-Cochran)

```
n_per_arm = (Z_{α/2} + Z_β)² · [p₁(1-p₁) + p₂(1-p₂)] / (p₁ - p₂)²
```

Example: HORIZON p₁=0.130, p₂=0.110 (=0.85·0.130), α=0.05, β=0.20 → n≈8,717
vs HORIZON 8,323 (4.7% gap, within design rounding).

### F4 — NNT closed-form

```
NNT = ceil(1 / ARR)         (continuous: 1/ARR)
ARR = p_ctrl - p_treat       (or |HR-1|·p_ctrl for proportional)
```

Example: ARR=0.04 → NNT=25.

### F5 — ln(HR) ↔ HR identity

```
HR = exp(ln_HR)              ln_HR = ln(HR)
```

Example: ln(HR)=-0.342490 → HR=0.7099 ≈ 0.71.

## why this matters (cross-domain)

- **LPA** — Burgess MR + HORIZON Schoenfeld + NHIS NNT (3 PRIMARY 🔵 targets)
- **DAPTPGX** — CYP2C19 LoF stroke HR (allele × outcome)
- **NOREFLOW** — TIMI grade ↔ MACE odds ratio
- **HERPES** — recurrence rate / NNT for acyclovir suppression

All four domains currently stuck at 🟢 SUPPORTED-NUMERICAL (calculator system
falls back to libm). 🔵 promotion is blocked by the `_recompute` gap.

## proposed acceptance

- `hexa verify --expr ivw <n_instruments> <expected_beta_e6>` → 🔵 when |delta|≤1e-6
- `hexa verify --expr schoenfeld <hr_pct> <events_expected>` → 🔵
- `hexa verify --expr binary_sample <p1_per_mille> <p2_per_mille> <n_expected>` → 🔵
- `hexa verify --expr nnt <arr_pct> <nnt_expected>` → 🔵
- `hexa atlas append-witness --kind F --id lpa_ivw_burgess` already staged at
  `n6/atlas.append.witness-1779574912000-lpa_ivw_burgess.n6` (this PR seeds 4 such shards)

## witness shards (already staged, separate PR)

```
n6/atlas.append.witness-1779574912000-lpa_ivw_burgess.n6
n6/atlas.append.witness-1779574920000-lpa_schoenfeld.n6
n6/atlas.append.witness-1779574923000-lpa_binary_sample.n6
n6/atlas.append.witness-1779574924000-lpa_nnt.n6
```

(parallel agent also staged `n6/atlas.append.witness-1779574445000-ivw-lpa-burgess2018.n6`
as `@L` law — keep both: this PR `@F` formula; parallel `@L` law-reference.)

— demiurge LPA V2 · 2026-05-24
