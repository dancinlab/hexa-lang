# vast new instance rejects all ssh keys

> Materialized from cross-repo handoff `e6aa86d1` (from demiurge, 1780895761) per demiurge @D d8
> (vast/cloud finding -> hexa-lang/inbox/patches so `hexa cloud` absorbs upstream).

vast cloud: newly-created instances reject ALL registered SSH keys (Permission denied publickey) on both proxy + direct ports, across 3+ machines (15898/36727/ssh2-host) and both account keys (933096 id_ed25519, 790310 anima). ssh_key=None after successful attach (account-DB vs per-instance projection desync). NOT key corruption (same keys auth fine on pre-existing pod 39922335), NOT machine-specific, NOT onstart-timing, NOT propagation lag (10min+reboot+detach/reattach all fail). Root cause likely: no account key has default:true (vastai show ssh-keys all default=None) so vast injects no key at boot. hexa cloud needs: (1) post-rent SSH reachability gate w/ auto-fallback to runpod, (2) enforce/verify a vast account DEFAULT key before first rent, (3) onstart authorized_keys injection for direct-port path. Blocks all new vast dispatch; forced runpod fallback today.

---
source: sidecar handoff `e6aa86d1` (demiurge -> hexa-lang) · status: open (awaiting hexa-lang absorb)
