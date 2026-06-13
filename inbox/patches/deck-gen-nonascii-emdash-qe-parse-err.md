# deck gen nonascii emdash qe parse err

> Materialized from cross-repo handoff `299a6d79` (from demiurge, 1780378076) per demiurge @D d8
> (vast/cloud finding -> hexa-lang/inbox/patches so `hexa cloud` absorbs upstream).

deck-gen emitted non-ASCII (em-dash U+2014) into QE input title/comment fields -> QE 6.7 FoX runParser PARSE_ERR -> signal-6 abort (crashed LaH10 gate anchor). Fix: sanitize_ascii() ASCII-sanitizer at deck_push choke point (stdlib/deck/types.hexa), routes every .in through it; metadata-only, physics untouched. PR#2511 merged. QE-robustness lesson: never feed non-ASCII into a FoX-parsed QE input.

---
source: sidecar handoff `299a6d79` (demiurge -> hexa-lang) · status: open (awaiting hexa-lang absorb)
