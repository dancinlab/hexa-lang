# cloud idle reap consult provider status

> Materialized from cross-repo handoff `d1410e5b` (from demiurge, 1780268341) per demiurge @D d8
> (vast/cloud finding -> hexa-lang/inbox/patches so `hexa cloud` absorbs upstream).

cloud idle-reap: consult provider instance STATUS (vast actual_status / runpod desiredStatus). An 'exited'/'stopped' pod with an ambiguous ssh probe currently fails safe to BUSY-UNMANIFESTED (never reaped) and lingers; status=exited is unambiguous → should classify REAP. Live case: inst 38711598 status=exited, proxy ssh refused → mis-held as BUSY-UNMANIFESTED until manual hexa cloud down. Fix: add provider-status to the classifier (exited/stopped -> REAP regardless of probe).

---
source: sidecar handoff `d1410e5b` (demiurge -> hexa-lang) · status: open (awaiting hexa-lang absorb)
