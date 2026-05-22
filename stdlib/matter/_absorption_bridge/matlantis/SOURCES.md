# `matlantis/SOURCES.md` — Preferred Networks Matlantis

> Phase G adapter target: `matlantis_call_smoke.py` (offline fixture replay; live API requires commercial Matlantis account)

---

## System

- **Name**: Matlantis (universal NNP service)
- **Maintainer**: Preferred Networks Inc. + ENEOS
- **Web**: https://matlantis.com
- **Underlying model**: PFP — Preferred-network Foundation Potential (universal NNP across periodic table)

## Authoritative citation

- Takamoto, S. et al. "Towards universal neural network potential for material discovery applicable to arbitrary combination of 45 elements." **Nature Communications** 13, 2991 (2022). DOI: 10.1038/s41467-022-30687-9

## API + auth

- **COMMERCIAL service** — Preferred Networks Matlantis is a paid SaaS.
  Account + license required. SDK is NOT on public PyPI; Matlantis tenants
  receive a proprietary Python client.
- The adapter (`matlantis_call_smoke.py`) **SKIPs by default** because the
  SDK is not installable in the standard hexa-matter dev environment.
- Live call from hexa-matter is OUT-OF-SCOPE for v1.x. The adapter only
  documents the call shape and replays a bundled fixture for selftest.

## License + pricing honesty

- **License**: Commercial closed (Preferred Networks proprietary)
- **Pricing**: Subscription-based, per-tenant. **Specific pricing UNVERIFIED**
  at hexa-matter scale — we do not own a quote.
- **Economics claim**: NNP energy/force eval is orders of magnitude cheaper
  than DFT *per call*, but Matlantis subscription cost vs in-house GPU + open
  NNP (MACE, M3GNet, etc.) at hexa-matter throughput is **UNPROVEN**.
  its OWN published error bars (force MAE ~30 meV/Å on their benchmark).

## Cross-link

- `_absorption_bridge/matlantis/matlantis_call_smoke.py` — this phase's adapter
- `_absorption_bridge/universal_ff/` — open-source alternatives (SchNet, MACE,
  M3GNet, ALIGNN, CHGNet) for the same universal-NNP role at $0 license cost
- `LIMIT_BREAKTHROUGH.md` — cost / energy / throughput discipline
