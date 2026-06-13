# hexa run buildcache transitive imports not keyed

> Materialized from cross-repo handoff `2cd58260` (from demiurge, 1780439892) per demiurge @D d8
> (vast/cloud finding -> hexa-lang/inbox/patches so `hexa cloud` absorbs upstream).

hexa run build-cache keys on the ENTRY file content only, not transitive imports — editing an imported module (e.g. stdlib/demi/handlers.hexa) while the entry (demi_cli.hexa) is unchanged serves a STALE cached binary (~/.hexa-cache/hexa_run.<hash>); workaround = rm ~/.hexa-cache/hexa_run.*. Also a cold-cache race: first run after cache nuke can hit rc=-1 on a nested hexa run, clears on warm re-run. Found during demi-cli hexa-native migration (parity selftest dev).

---
source: sidecar handoff `2cd58260` (demiurge -> hexa-lang) · status: open (awaiting hexa-lang absorb)
