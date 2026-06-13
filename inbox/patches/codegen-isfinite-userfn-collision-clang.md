# codegen isfinite userfn collision clang

> Materialized from cross-repo handoff `746977d7` (from demiurge, 1780445564) per demiurge @D d8
> (vast/cloud finding -> hexa-lang/inbox/patches so `hexa cloud` absorbs upstream).

codegen: stdlib/bio/nanobot/module/actuation_simulation.hexa fails clang compile — user-defined fn isfinite(x:float) collides with C <math.h> isfinite() macro (10 errors: 'operand of type HexaVal where arithmetic/pointer required'). Selfhost codegen should namespace/rename user fns that shadow libc math macros (isfinite/isnan/isinf/signbit). Repro: hexa run stdlib/bio/nanobot/module/actuation_simulation.hexa --selftest. Workaround in AGA-RX round5-nanobot: renamed helper is_finite_v. demiurge d8.

---
source: sidecar handoff `746977d7` (demiurge -> hexa-lang) · status: open (awaiting hexa-lang absorb)
