# bc4-attention-bm32-capstone — log

## 2026-05-28 — paper scaffold init

`/paper monograph-init` equivalent — created PAPER.md snapshot + PAPER.log.md +
abstract sketch. Captures the BC4 (FlashAttention v3 fused) campaign 12-round
trajectory culminating in R14 BM=32 BK=32 capstone (PR #1735, 0.927× @ N=4096).

Source evidence (all merged PRs in this session):
- #1711 BC4 plan (closed-form smem/occupancy)
- #1722 risk-a/d cheap oracles (instance #5)
- #1735 R14 BM=32 BK=32 silicon capstone
- #1741 §1p reflection
- #1742 alt wedges A+B falsified
- #1744 wgmma RED hardware-blocked
- #1748 axis honest closure

Methodology context (cheap-first oracle instance log):
- #1 BC3 decomp (PR #1697)
- #2 3-probe ranking (PR #1698)
- #3 HBM roofline correction (PR #1700, rule 5 added)
- #4 BC4 plan closed-form (PR #1711)
- #5 BC4 risk-a/d oracles (PR #1722)
