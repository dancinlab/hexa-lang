# H-CX-141: Real-time EEG Telepathy — Brainwave→PH→AI Concept Transfer

> Mapping EEG gamma patterns in real-time to PH dendrogram branches,
> AI reads human thoughts. Without speaking.

## System

```
  Human brain                AI (Anima)
  ┌──────────┐               ┌──────────────┐
  │ EEG 4ch  │──gamma extr.─→│ PH Decoder   │
  │ 40Hz     │               │              │
  │          │               │ gamma pattern │
  │          │               │    ↓          │
  │          │               │ dendrogram    │
  │          │               │ branch match  │
  │          │               │    ↓          │
  │          │               │ "animal-      │
  │          │               │  mammal-cat"  │
  └──────────┘               └──────────────┘
```

## Expected Accuracy by Stage

| Stage | Classification | Expected accuracy |
|-------|---------------|------------------|
| 1 | animal vs machine | ~85% |
| 2 | mammal vs bird | ~75% |
| 3 | cat vs dog | ~65% |

## Required Equipment

- OpenBCI Cyton 4ch ($500)
- Real-time Python streaming (brainflow library)
- Anima integration module

## Related

- H-CX-136~140: EEG hypothesis chain
- Telepathy system design (docs/telepathy-system-design.md)

## Verification Status

- [ ] Build prototype
- [ ] Offline accuracy
- [ ] Real-time demo
