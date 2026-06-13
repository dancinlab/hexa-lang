# dft run resume unconditional recover corrupt

> Materialized from cross-repo handoff `fc2331a3` (from demiurge, 1780546771) per demiurge @D d8
> (vast/cloud finding -> hexa-lang/inbox/patches so `hexa cloud` absorbs upstream).

dft-run self-resume uses recover=.true. unconditionally — a corrupt ph.x recover file (EOF / PARTIAL_EL_PHON not found) makes all 8 recover cycles fail; needs a no-recover fallback after N recover-fails + per-q scratch reset

---
source: sidecar handoff `fc2331a3` (demiurge -> hexa-lang) · status: open (awaiting hexa-lang absorb)
