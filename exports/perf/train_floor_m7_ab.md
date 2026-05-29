# HEXA-TRAIN-FLOOR M5 — A/B step-rate ledger

Config: d=768 layers=12 batch=1 seq=512  ·  tag: M7-armH=fp64-armP=hexa-fp32-RTX5070-measured

| backend | step/s | s/step | peak RSS (MB) | GPU-days (prod) |
|---|---|---|---|---|
| hexa-native | 0.165 | n/a | 1024 | 7.014 |
| pytorch | 8.090 | n/a | 1024 | 0.143 |

Δ (pytorch_step/s ÷ hexa_step/s) = 49.030×  (>1 → PyTorch faster · <1 → hexa-native faster)

prod-steps budget = 100000 presentations → GPU-days column above.

baseline reference (HEXA-TRAIN-FLOOR M1, DECODER STEP_RATE_LOG): hexa-native 0.28 step/s (1.99 s/step) · 77~122 GPU-days · GPU util 0~8% · 🔴 INFEASIBLE.